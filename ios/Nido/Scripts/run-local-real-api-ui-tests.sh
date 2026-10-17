#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/harness-shell-support.sh"
DEFAULT_REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
API_ROOT="$DEFAULT_REPO_ROOT"
PROJECT_DIR="$DEFAULT_REPO_ROOT/ios/Nido"
DERIVED_DATA_PATH=""
XCTESTRUN_PATH=""
DEVICE_ID="516B4FA1-D8C4-4389-9836-79095056D5CB"
MODE="prepare-only"
TEST_WITHOUT_BUILDING=0
RESULT_BUNDLE_PATH=""
EVIDENCE_DIR=""
CLONED_SOURCE_PACKAGES_DIR=""
POSTGRES_IMAGE="postgres:17.10-bookworm@sha256:9b18b78397054fce88a9552e9d5a3ad5bb7fd258c5b3cc1c5028e46373d6ea8f"

usage() {
  cat <<'USAGE'
Usage:
  run-local-real-api-ui-tests.sh [--prepare-only | --run-ui-tests]
    [--api-root PATH] [--project-dir PATH] [--derived-data-path PATH]
    [--test-without-building --xctestrun PATH] [--device-id UUID]
    [--cloned-source-packages-dir PATH]
    [--result-bundle PATH] [--evidence-dir PATH]

Default mode prepares and verifies the disposable local backend, then cleans it
up without launching Xcode or a simulator. --run-ui-tests runs only the three
credential-backed UI cases against that same disposable backend.
USAGE
}

while (($#)); do
  case "$1" in
    --prepare-only) MODE="prepare-only"; shift ;;
    --run-ui-tests) MODE="run-ui-tests"; shift ;;
    --api-root) API_ROOT="$(cd "$2" && pwd -P)"; shift 2 ;;
    --project-dir) PROJECT_DIR="$(cd "$2" && pwd -P)"; shift 2 ;;
    --derived-data-path) DERIVED_DATA_PATH="$(normalize_create_directory "$2")"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="$(normalize_create_directory "$2")"; chmod 700 "$EVIDENCE_DIR"; shift 2 ;;
    --test-without-building) TEST_WITHOUT_BUILDING=1; shift ;;
    --xctestrun) XCTESTRUN_PATH="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"; shift 2 ;;
    --device-id) DEVICE_ID="$2"; shift 2 ;;
    --result-bundle) RESULT_BUNDLE_PATH="$2"; shift 2 ;;
    --cloned-source-packages-dir) CLONED_SOURCE_PACKAGES_DIR="$(cd "$2" && pwd -P)"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ "$MODE" == "run-ui-tests" && ! "$DEVICE_ID" =~ ^[[:xdigit:]]{8}(-[[:xdigit:]]{4}){3}-[[:xdigit:]]{12}$ ]]; then
  printf 'Invalid simulator UDID: %s\n' "$DEVICE_ID" >&2
  exit 2
fi

if [[ ! -f "$PROJECT_DIR/Nido.xcodeproj/project.pbxproj" ]]; then
  printf 'Xcode project not found under --project-dir: %s\n' "$PROJECT_DIR" >&2
  exit 2
fi
if [[ ! -x "$API_ROOT/node_modules/.bin/vinext" || ! -f "$API_ROOT/db/migrate.ts" ]]; then
  printf 'API dependencies or migration source are missing under --api-root: %s\n' "$API_ROOT" >&2
  exit 2
fi
if [[ "$TEST_WITHOUT_BUILDING" == 1 && ( -z "$XCTESTRUN_PATH" || ! -f "$XCTESTRUN_PATH" ) ]]; then
  printf '%s\n' '--test-without-building requires an existing --xctestrun file.' >&2
  exit 2
fi
if [[ "$TEST_WITHOUT_BUILDING" == 0 && -n "$XCTESTRUN_PATH" ]]; then
  printf '%s\n' '--xctestrun is only used with --test-without-building.' >&2
  exit 2
fi
if [[ "$MODE" == "prepare-only" && ( "$TEST_WITHOUT_BUILDING" == 1 || -n "$DERIVED_DATA_PATH" || -n "$RESULT_BUNDLE_PATH" ) ]]; then
  printf '%s\n' 'Xcode build options are only valid with --run-ui-tests.' >&2
  exit 2
fi

for command_name in docker curl node npm xcodebuild openssl; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Required command is unavailable: %s\n' "$command_name" >&2
    exit 2
  fi
done

WORK_DIR="$(mktemp -d /tmp/nido-local-real-api-ui.XXXXXX)"
WORK_ID="${WORK_DIR##*.}"
CONTAINER_NAME="nido-local-api-ui-${WORK_ID}"
CONTAINER_LABEL_KEY="com.momentumia.nido.local-api-ui-harness"
CONTAINER_LABEL_VALUE="$WORK_ID"
CONTAINER_CREATED=0
SERVER_PID=""
RUN_ID="$(node -e 'process.stdout.write(require("node:crypto").randomUUID())')"
DB_PASSWORD="$(openssl rand -hex 24)"
AUTH_BUCKET_SECRET="$(openssl rand -hex 32)"
PG_PORT=""
API_PORT=""
ENV_FILE="$WORK_DIR/runner.env"
SERVER_LOG="$WORK_DIR/api.log"
SECRET_VALUES_FILE="$WORK_DIR/redaction-values"
umask 077
printf '%s\n%s\n' "$DB_PASSWORD" "$AUTH_BUCKET_SECRET" > "$SECRET_VALUES_FILE"
chmod 600 "$SECRET_VALUES_FILE"

cleanup() {
  local exit_code=$?
  local cleanup_failed=0
  set +e
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill -TERM "$SERVER_PID" 2>/dev/null
    wait "$SERVER_PID" 2>/dev/null
  fi
  if [[ -n "$EVIDENCE_DIR" ]]; then
    if [[ "$CONTAINER_CREATED" == 1 ]] && verify_owned_container; then
      docker logs "$CONTAINER_NAME" > "$WORK_DIR/postgres.log" 2>&1
    fi
    for evidence_name in api.log postgres.log xcodebuild.log runner.env; do
      if [[ -s "$WORK_DIR/$evidence_name" ]]; then
        node "$SCRIPT_DIR/sanitize-ui-test-log.mjs" "$WORK_DIR/$evidence_name" "$EVIDENCE_DIR/$evidence_name" "$SECRET_VALUES_FILE" "$ENV_FILE" || cleanup_failed=1
        chmod 600 "$EVIDENCE_DIR/$evidence_name" 2>/dev/null || cleanup_failed=1
      fi
    done
    if [[ -f "$API_ROOT/source-manifest.sha256" ]]; then
      cp "$API_ROOT/source-manifest.sha256" "$EVIDENCE_DIR/source-manifest.sha256" || cleanup_failed=1
      chmod 600 "$EVIDENCE_DIR/source-manifest.sha256" 2>/dev/null || cleanup_failed=1
    fi
    printf 'Harness exit status: %s\n' "$exit_code" > "$EVIDENCE_DIR/run-status.txt" || cleanup_failed=1
    chmod 600 "$EVIDENCE_DIR/run-status.txt" 2>/dev/null || cleanup_failed=1
  fi
  if [[ "$CONTAINER_CREATED" == 1 ]]; then
    remove_owned_container || cleanup_failed=1
  fi
  rm -rf "$WORK_DIR" || cleanup_failed=1
  if [[ "$cleanup_failed" == 1 && "$exit_code" == 0 ]]; then exit_code=1; fi
  return "$exit_code"
}

print_sanitized_tail() {
  local source_path="$1"
  local line_count="$2"
  local safe_path="$WORK_DIR/safe-tail.log"
  if node "$SCRIPT_DIR/sanitize-ui-test-log.mjs" "$source_path" "$safe_path" "$SECRET_VALUES_FILE" "$ENV_FILE"; then
    tail -n "$line_count" "$safe_path" >&2
    rm -f "$safe_path"
  else
    printf '%s\n' 'Could not safely display diagnostic log; use --evidence-dir for sanitized logs.' >&2
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if ! docker info >/dev/null 2>&1; then
  printf '%s\n' 'Docker daemon is unavailable.' >&2
  exit 2
fi

printf 'Starting disposable PostgreSQL container %s.\n' "$CONTAINER_NAME"
docker run --detach \
  --name "$CONTAINER_NAME" \
  --label "$CONTAINER_LABEL_KEY=$CONTAINER_LABEL_VALUE" \
  --tmpfs /var/lib/postgresql/data:rw,nosuid,nodev,size=512m \
  --env POSTGRES_USER=nido \
  --env "POSTGRES_PASSWORD=$DB_PASSWORD" \
  --env POSTGRES_DB=nido \
  --publish 127.0.0.1::5432 \
  "$POSTGRES_IMAGE" >/dev/null
CONTAINER_CREATED=1
PG_PORT="$(docker port "$CONTAINER_NAME" 5432/tcp | awk -F: 'NR == 1 { print $NF }')"
if [[ ! "$PG_PORT" =~ ^[0-9]+$ ]]; then
  printf '%s\n' 'Could not determine the isolated PostgreSQL loopback port.' >&2
  exit 1
fi

for attempt in $(seq 1 60); do
  if docker exec "$CONTAINER_NAME" pg_isready -U nido -d nido >/dev/null 2>&1; then break; fi
  if [[ "$attempt" == 60 ]]; then
    printf '%s\n' 'The disposable PostgreSQL container did not become ready.' >&2
    exit 1
  fi
  sleep 1
done

API_PORT="$(node -e 'const net=require("node:net"); const s=net.createServer(); s.listen(0,"127.0.0.1",()=>{process.stdout.write(String(s.address().port));s.close();});')"
DATABASE_URL="postgres://nido:${DB_PASSWORD}@127.0.0.1:${PG_PORT}/nido"
API_BASE_URL="http://127.0.0.1:${API_PORT}"
export DATABASE_URL

run_with_timeout() {
  local timeout_ms="$1"
  shift
  node "$SCRIPT_DIR/run-command-with-timeout.mjs" "$timeout_ms" "$@"
}

printf '%s\n' 'Applying PostgreSQL migrations to the disposable database (180s limit).'
(cd "$API_ROOT" && run_with_timeout 180000 npm run db:migrate)

printf '%s\n' 'Starting the local API bound to loopback.'
(
  cd "$API_ROOT"
  export NODE_ENV=development
  export DATABASE_URL="$DATABASE_URL"
  export NIDO_APPLE_AUDIENCE=com.momentumia.nido
  export NIDO_AUTH_BUCKET_SECRET="$AUTH_BUCKET_SECRET"
  export HOST=127.0.0.1
  export PORT="$API_PORT"
  exec "$API_ROOT/node_modules/.bin/vinext" dev --hostname 127.0.0.1 --port "$API_PORT"
) >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!

API_READY=0
for attempt in $(seq 1 90); do
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    printf '%s\n' 'The local API exited before becoming healthy.' >&2
    print_sanitized_tail "$SERVER_LOG" 80 || true
    exit 1
  fi
  HTTP_STATUS="$(curl --silent --output "$WORK_DIR/status.json" --max-time 2 --write-out '%{http_code}' "$API_BASE_URL/api/nido/status" || true)"
  if [[ "$HTTP_STATUS" == 200 ]]; then API_READY=1; break; fi
  sleep 1
done
if [[ "$API_READY" != 1 ]]; then
  printf '%s\n' 'The local API health check failed.' >&2
  print_sanitized_tail "$SERVER_LOG" 80 || true
  exit 1
fi

printf '%s\n' 'Seeding and validating five synthetic bearer sessions over local HTTP.'
(
  cd "$API_ROOT"
  DATABASE_URL="$DATABASE_URL" \
    NIDO_UI_TEST_API_BASE_URL="$API_BASE_URL" \
    NIDO_UI_TEST_RUN_ID="$RUN_ID" \
    NIDO_LOCAL_API_UI_ENV_FILE="$ENV_FILE" \
    node "$API_ROOT/ios/Nido/Scripts/local-real-api-ui-sessions.mjs" --write-runner-environment
)
if [[ ! -s "$ENV_FILE" ]]; then
  printf '%s\n' 'The session seeder did not create its protected runner environment file.' >&2
  exit 1
fi
set -a
# Generated by the fixture utility with random base64url tokens and a loopback URL only.
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

if [[ "$MODE" == "prepare-only" ]]; then
  printf '%s\n' 'Preparation passed. API, sessions, and disposable database will now be cleaned up; XCUITest was not run.'
  exit 0
fi

if [[ -z "$RESULT_BUNDLE_PATH" ]]; then
  RESULT_BUNDLE_PATH="/tmp/nido-local-real-api-ui-$(date +%Y%m%d-%H%M%S).xcresult"
fi
if [[ -e "$RESULT_BUNDLE_PATH" ]]; then
  printf 'Refusing to overwrite existing result bundle: %s\n' "$RESULT_BUNDLE_PATH" >&2
  exit 2
fi

XCODEBUILD_ARGS=()
if [[ "$TEST_WITHOUT_BUILDING" == 1 ]]; then
  XCODEBUILD_ARGS+=(test-without-building -xctestrun "$XCTESTRUN_PATH")
else
  XCODEBUILD_ARGS+=(test -project "$PROJECT_DIR/Nido.xcodeproj" -scheme Nido)
fi
if [[ -n "$DERIVED_DATA_PATH" ]]; then
  XCODEBUILD_ARGS+=(-derivedDataPath "$DERIVED_DATA_PATH")
fi
if [[ -n "$CLONED_SOURCE_PACKAGES_DIR" ]]; then
  XCODEBUILD_ARGS+=(-clonedSourcePackagesDirPath "$CLONED_SOURCE_PACKAGES_DIR" -disableAutomaticPackageResolution -skipPackageUpdates)
fi
XCODEBUILD_ARGS+=(
  -destination "platform=iOS Simulator,id=$DEVICE_ID"
  -parallel-testing-enabled NO
  -maximum-concurrent-test-simulator-destinations 1
  -resultBundlePath "$RESULT_BUNDLE_PATH"
  -only-testing:NidoUITests/NidoUITests/testFreshInstallationCreatesAnIndependentHouseholdAndOnlySeesItsOwnBaby
  -only-testing:NidoUITests/NidoUITests/testRealBackendCaregiverPermissionsAndRevocation
  -only-testing:NidoUITests/NidoUITests/testRealBackendHistoryLoadsAndDisplaysAnEntryBeyondTheFirstFiveHundred
)

printf 'Running the three local-backend UI tests on iPhone 16 Pro (%s).\n' "$DEVICE_ID"
if xcodebuild "${XCODEBUILD_ARGS[@]}" >"$WORK_DIR/xcodebuild.log" 2>&1; then
  rg 'Test Case .* (passed|failed)|Executed [0-9]+ tests|\*\* TEST SUCCEEDED \*\*' "$WORK_DIR/xcodebuild.log" || true
  printf 'Result bundle: %s\n' "$RESULT_BUNDLE_PATH"
else
  print_sanitized_tail "$WORK_DIR/xcodebuild.log" 100 || true
  printf 'XCUITest failed. Result bundle: %s\n' "$RESULT_BUNDLE_PATH" >&2
  exit 1
fi
