#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a files=(
  "tests/mbedtls/test_mbedtls_server_accept.pas"
  "tests/mbedtls/test_mbedtls_server_accept_simple.pas"
)

pattern='(Context|Ctx|LCtx|LContext)[0-9]*\.SetServerName\('

for file in "${files[@]}"; do
  if rg -n --quiet "$pattern" "$file"; then
    echo "[FAIL] MbedTLS server-accept test still teaches deprecated context-level SNI: $file"
    rg -n "$pattern" "$file" || true
    exit 1
  fi
done

echo "[PASS] selected MbedTLS server-accept tests no longer teach deprecated context-level SNI"
