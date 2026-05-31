#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a files=(
  "tests/mbedtls/test_mbedtls_cert_chain.pas"
  "tests/mbedtls/test_mbedtls_cert_verify_flags.pas"
  "tests/mbedtls/test_mbedtls_cert_errors.pas"
  "tests/mbedtls/test_mbedtls_ocsp_capability.pas"
)

pattern='(Context|Ctx|LCtx|LContext)\.SetServerName\('

for file in "${files[@]}"; do
  if rg -n --quiet "$pattern" "$file"; then
    echo "[FAIL] MbedTLS online verification test still teaches deprecated context-level SNI: $file"
    rg -n "$pattern" "$file" || true
    exit 1
  fi
done

echo "[PASS] selected MbedTLS online verification tests no longer teach deprecated context-level SNI"
