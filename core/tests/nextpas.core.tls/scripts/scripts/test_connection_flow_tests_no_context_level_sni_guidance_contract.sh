#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -a files=(
  "tests/mbedtls/test_mbedtls_connection.pas"
  "tests/mbedtls/test_mbedtls_simple_connection.pas"
  "tests/integration/test_e2e_scenarios.pas"
  "tests/integration/test_real_https_connection.pas"
)

pattern='(Context|Ctx|LCtx|LContext)\.SetServerName\('

for file in "${files[@]}"; do
  if rg -n --quiet "$pattern" "$file"; then
    echo "[FAIL] connection-flow test still teaches deprecated context-level SNI: $file"
    rg -n "$pattern" "$file" || true
    exit 1
  fi
done

echo "[PASS] selected connection-flow tests no longer teach deprecated context-level SNI"
