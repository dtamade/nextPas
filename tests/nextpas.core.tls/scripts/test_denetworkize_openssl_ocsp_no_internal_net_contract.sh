#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

target="src/nextpas.core.tls.openssl.api.ocsp.pas"
if [[ ! -f "$target" ]]; then
  echo "[FAIL] missing $target"
  exit 1
fi

patterns=(
  "\\bBIO_new_connect\\b"
  "\\bBIO_new_ssl_connect\\b"
  "\\bBIO_set_conn_hostname\\b"
  "\\bBIO_do_connect\\b"
)

for pat in "${patterns[@]}"; do
  if rg -n -S "$pat" "$target" >/dev/null 2>&1; then
    echo "[FAIL] $target must not implement internal network transport (matched: $pat)"
    rg -n -S "$pat" "$target" || true
    exit 1
  fi
done

echo "[PASS] $target has no internal OpenSSL BIO connect transport"

