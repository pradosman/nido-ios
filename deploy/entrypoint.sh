#!/bin/sh
set -eu

data_dir="${NIDO_DATA_DIR:-.wrangler/vps-data}"
port="${NIDO_PORT:-3000}"
mkdir -p "$data_dir"

./node_modules/.bin/wrangler d1 migrations apply DB \
  --local \
  --persist-to "$data_dir" \
  --config wrangler.vps.jsonc

exec ./node_modules/.bin/wrangler dev \
  --local \
  --persist-to "$data_dir" \
  --config wrangler.vps.jsonc \
  --ip 0.0.0.0 \
  --port "$port" \
  --log-level warn
