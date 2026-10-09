#!/usr/bin/env bash
set -eu
set -o pipefail
umask 077
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
mkdir -p "$ROOT/backups"
stamp="$(date +%F-%H%M%S)"
temporary="$(mktemp "$ROOT/backups/.mysql-${stamp}.XXXXXX")"
trap 'rm -f "$temporary"' EXIT
docker compose --env-file "$ROOT/.env" -f "$ROOT/compose.yaml" exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysqldump -uroot --single-transaction --routines --events "$MYSQL_DATABASE"' | gzip > "$temporary"
mv "$temporary" "$ROOT/backups/mysql-${stamp}.sql.gz"
trap - EXIT
find "$ROOT/backups" -name 'mysql-*.sql.gz' -mtime +7 -delete
