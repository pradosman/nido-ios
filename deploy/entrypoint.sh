#!/bin/sh
set -eu

mode="${1:-serve}"
password_file="${POSTGRES_PASSWORD_FILE:-/run/secrets/postgres_password}"

database_password="${POSTGRES_PASSWORD:-}"
if [ -z "$database_password" ]; then
  if [ ! -r "$password_file" ]; then
    printf '%s\n' "PostgreSQL password is unavailable" >&2
    exit 1
  fi
  database_password=$(cat "$password_file")
fi
case "$database_password" in
  ""|*[!A-Za-z0-9._~-]*)
    printf '%s\n' "PostgreSQL password must use URL-safe characters" >&2
    exit 1
    ;;
esac

export DATABASE_URL="postgres://${POSTGRES_USER:-nido}:${database_password}@${POSTGRES_HOST:-postgres}:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-nido}"
unset database_password POSTGRES_PASSWORD

if [ "$mode" = "migrate" ]; then
  exec node /app/dist/migrate.mjs
fi

if [ "$mode" != "serve" ]; then
  printf '%s\n' "Unknown entrypoint mode" >&2
  exit 1
fi

auth_secret_file="${NIDO_AUTH_BUCKET_SECRET_FILE:-/run/secrets/auth_bucket_secret}"
auth_secret="${NIDO_AUTH_BUCKET_SECRET:-}"
if [ -z "$auth_secret" ]; then
  if [ ! -r "$auth_secret_file" ]; then
    printf '%s\n' "Authentication secret is unavailable" >&2
    exit 1
  fi
  auth_secret=$(cat "$auth_secret_file")
fi
if [ -z "${NIDO_APPLE_AUDIENCE:-}" ]; then
  printf '%s\n' "NIDO_APPLE_AUDIENCE is required" >&2
  exit 1
fi

export NIDO_AUTH_BUCKET_SECRET="$auth_secret"
unset auth_secret
if [ "${#NIDO_AUTH_BUCKET_SECRET}" -lt 32 ]; then
  printf '%s\n' "Authentication secret must contain at least 32 characters" >&2
  exit 1
fi

export HOST="${HOST:-0.0.0.0}"
export PORT="${PORT:-3000}"
exec node /app/dist/standalone/server.js
