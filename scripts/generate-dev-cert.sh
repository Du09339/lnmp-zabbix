#!/bin/sh
set -eu
umask 077
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
mkdir -p "$ROOT/nginx/certs"
if [ -e "$ROOT/nginx/certs/cert.pem" ] || [ -e "$ROOT/nginx/certs/key.pem" ]; then
    echo "A certificate file already exists. Back it up or remove it deliberately before generating a replacement." >&2
    exit 1
fi
docker run --rm -v "$ROOT/nginx/certs:/out" alpine/openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /out/key.pem -out /out/cert.pem -subj '/CN=localhost'
cp "$ROOT/nginx/conf.d/https.conf.example" "$ROOT/nginx/conf.d/https.conf"
