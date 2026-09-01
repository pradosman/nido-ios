#!/usr/bin/env bash
set -euo pipefail

archive=${1:-}
identity=${NIDO_AGE_IDENTITY:-}
compose_file=${NIDO_COMPOSE_FILE:-compose.vps.yml}

if [ "${NIDO_RESTORE_CONFIRMED:-}" != "restore-nido" ]; then
  printf '%s\n' "Set NIDO_RESTORE_CONFIRMED=restore-nido to replace the current database" >&2
  exit 1
fi
if [ ! -r "$archive" ] || [ ! -r "$identity" ]; then
  printf '%s\n' "Usage: NIDO_AGE_IDENTITY=<identity-file> NIDO_RESTORE_CONFIRMED=restore-nido $0 <backup.dump.age>" >&2
  exit 1
fi

# Verify that the encrypted input contains a readable PostgreSQL archive before changing data.
age --decrypt --identity "$identity" "$archive" \
  | docker compose -f "$compose_file" exec -T postgres pg_restore --list >/dev/null

docker compose -f "$compose_file" stop nido
docker compose -f "$compose_file" exec -T postgres \
  psql --username=nido --dbname=postgres --set=ON_ERROR_STOP=1 \
  --command='DROP DATABASE IF EXISTS nido WITH (FORCE)' \
  --command='CREATE DATABASE nido OWNER nido'
age --decrypt --identity "$identity" "$archive" \
  | docker compose -f "$compose_file" exec -T postgres \
      pg_restore --username=nido --dbname=nido --exit-on-error --no-owner
docker compose -f "$compose_file" run --rm migrate
docker compose -f "$compose_file" start nido

printf '%s\n' "PostgreSQL restore completed"
