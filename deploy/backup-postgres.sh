#!/usr/bin/env bash
set -euo pipefail

output=${1:-}
recipient=${NIDO_AGE_RECIPIENT:-}
compose_file=${NIDO_COMPOSE_FILE:-compose.vps.yml}

if [ -z "$output" ] || [ -z "$recipient" ]; then
  printf '%s\n' "Usage: NIDO_AGE_RECIPIENT=<age-recipient> $0 <backup.dump.age>" >&2
  exit 1
fi
if [ -e "$output" ]; then
  printf '%s\n' "Refusing to overwrite an existing backup" >&2
  exit 1
fi
if ! command -v age >/dev/null 2>&1; then
  printf '%s\n' "The age command is required" >&2
  exit 1
fi

umask 077
completed=false
cleanup() {
  if [[ "$completed" != true ]]; then
    rm -f -- "$output"
  fi
}
trap cleanup EXIT

docker compose -f "$compose_file" exec -T postgres \
  pg_dump --username=nido --dbname=nido --format=custom --no-owner \
  | age --recipient "$recipient" --output "$output"

test -s "$output"
completed=true
printf '%s\n' "Encrypted PostgreSQL backup created: $output"
