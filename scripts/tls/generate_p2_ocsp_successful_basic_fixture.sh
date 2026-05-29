#!/usr/bin/env bash
set -euo pipefail

OUTPUT_PATH="${1:-tests/fixtures/p2/ocsp/ocsp_response_successful_basic_v1.der}"
WORKDIR="$(mktemp -d -t ocsp_fixture_gen_XXXXXX)"
cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERROR] Missing required command: $cmd" >&2
    exit 1
  fi
}

require_cmd openssl
require_cmd date

mkdir -p "$(dirname "$OUTPUT_PATH")"

pushd "$WORKDIR" >/dev/null

openssl genrsa -out ca.key 2048 >/dev/null 2>&1
openssl req -x509 -new -key ca.key -sha256 -days 365 \
  -subj "/CN=Fixture CA" -out ca.crt >/dev/null 2>&1

openssl genrsa -out leaf.key 2048 >/dev/null 2>&1
openssl req -new -key leaf.key -subj "/CN=fixture-leaf.local" -out leaf.csr >/dev/null 2>&1
openssl x509 -req -in leaf.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -days 365 -sha256 -out leaf.crt >/dev/null 2>&1

SERIAL_HEX="$(openssl x509 -in leaf.crt -noout -serial | cut -d= -f2)"
EXPIRY_RAW="$(openssl x509 -in leaf.crt -noout -enddate | cut -d= -f2)"
EXPIRY_FMT="$(date -u -d "$EXPIRY_RAW" +"%y%m%d%H%M%SZ")"
SUBJECT_DN="$(openssl x509 -in leaf.crt -noout -subject -nameopt RFC2253 | sed 's/^subject=//')"
printf 'V\t%s\t\t%s\tunknown\t%s\n' "$EXPIRY_FMT" "$SERIAL_HEX" "$SUBJECT_DN" > index.txt

openssl ocsp \
  -index index.txt \
  -CA ca.crt \
  -rsigner ca.crt \
  -rkey ca.key \
  -issuer ca.crt \
  -cert leaf.crt \
  -respout resp.der \
  -ndays 1 >/dev/null 2>&1

popd >/dev/null

cp "$WORKDIR/resp.der" "$OUTPUT_PATH"

echo "[OK] Generated OCSP successful/basic fixture: $OUTPUT_PATH"
