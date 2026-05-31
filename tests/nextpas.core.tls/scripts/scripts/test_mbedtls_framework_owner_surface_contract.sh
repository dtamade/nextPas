#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

mkdir -p tmp/test_mbedtls_framework_owner_surface_contract

log_file="tmp/test_mbedtls_framework_owner_surface_contract/build.log"
binary="tmp/test_mbedtls_framework_owner_surface_contract/test_mbedtls_framework"

fpc -B -Fu./src -Fu./tests -Fu./tests/framework \
  -FUtmp/test_mbedtls_framework_owner_surface_contract \
  -FEtmp/test_mbedtls_framework_owner_surface_contract \
  -o"$binary" \
  tests/test_mbedtls_framework.pas >"$log_file" 2>&1

declare -a forbidden_patterns=(
  'test_mbedtls_framework\.pas\([0-9]+,[0-9]+\) Warning: Symbol "ISSLContext\.SetServerName" is deprecated'
  'test_mbedtls_framework\.pas\([0-9]+,[0-9]+\) Warning: Symbol "ISSLContext\.GetServerName" is deprecated'
  'test_mbedtls_framework\.pas\([0-9]+,[0-9]+\) Warning: Symbol "ISSLConnection\.GetVerifyResult" is deprecated'
  'test_mbedtls_framework\.pas\([0-9]+,[0-9]+\) Warning: Symbol "ISSLConnection\.GetVerifyResultString" is deprecated'
)

for pattern in "${forbidden_patterns[@]}"; do
  if rg -n --pcre2 --quiet "$pattern" "$log_file"; then
    echo "[FAIL] test_mbedtls_framework.pas reintroduced deprecated owner-surface warnings"
    rg -n --pcre2 "$pattern" "$log_file" || true
    exit 1
  fi
done

"$binary" >/dev/null

echo "[PASS] test_mbedtls_framework.pas stays on owner-path SNI and verify-result surfaces"
