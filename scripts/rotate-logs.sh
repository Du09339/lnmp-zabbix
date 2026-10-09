#!/bin/sh
set -eu
umask 077
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
mkdir -p "$ROOT/logs"
temporary="$(mktemp "$ROOT/logs/.compose-$(date +%F).XXXXXX")"
trap 'rm -f "$temporary"' EXIT
docker compose --env-file "$ROOT/.env" -f "$ROOT/compose.yaml" logs --no-color --timestamps > "$temporary"
mv "$temporary" "$ROOT/logs/compose-$(date +%F).log"
trap - EXIT
find "$ROOT/logs" -name 'compose-*.log' -mtime +14 -delete
