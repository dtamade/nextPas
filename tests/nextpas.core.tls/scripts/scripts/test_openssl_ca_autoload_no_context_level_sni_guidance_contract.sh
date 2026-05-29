#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

test_file="tests/openssl/test_openssl_ca_autoload.pas"
doc_file="docs/CA_CERTIFICATE_AUTO_LOADING.md"

pattern='(Context|Ctx|LCtx|LContext)\.SetServerName\('

if rg -n --quiet "$pattern" "$test_file"; then
  echo "[FAIL] OpenSSL CA autoload test still uses deprecated context-level SNI"
  rg -n "$pattern" "$test_file" || true
  exit 1
fi

if rg -n --quiet 'SNI hostname properly set on context' "$doc_file"; then
  echo "[FAIL] CA autoload doc still describes SNI as context-level"
  rg -n 'SNI hostname properly set on context' "$doc_file" || true
  exit 1
fi

echo "[PASS] OpenSSL CA autoload test/doc no longer teach context-level SNI"
