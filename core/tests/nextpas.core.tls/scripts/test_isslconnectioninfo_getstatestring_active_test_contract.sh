#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

basic_test="tests/connection/test_connection_basic.pas"
integration_test="tests/integration/test_real_https_connection.pas"

declare -a forbidden_basic_patterns=(
  "LConnection.GetStateString"
)

for pattern in "${forbidden_basic_patterns[@]}"; do
  if grep -F -q -- "$pattern" "$basic_test"; then
    echo "[FAIL] basic connection test still uses direct core GetStateString: $pattern"
    exit 1
  fi
done

declare -a required_basic_patterns=(
  "LConnInfo: ISSLConnectionInfo;"
  "Supports(LConnection, ISSLConnectionInfo, LConnInfo)"
  "LConnInfo.GetStateString"
)

for pattern in "${required_basic_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$basic_test"; then
    echo "[FAIL] basic connection test missing ISSLConnectionInfo-first GetStateString usage: $pattern"
    exit 1
  fi
done

declare -a forbidden_integration_patterns=(
  "Conn.GetStateString"
)

for pattern in "${forbidden_integration_patterns[@]}"; do
  if grep -F -q -- "$pattern" "$integration_test"; then
    echo "[FAIL] real HTTPS integration test still uses direct core GetStateString: $pattern"
    exit 1
  fi
done

declare -a required_integration_patterns=(
  "function GetConnectionStateString(AConn: ISSLConnection): string;"
  "Supports(AConn, ISSLConnectionInfo, LConnInfo)"
  "LConnInfo.GetStateString"
  "Result := '[ISSLConnectionInfo unavailable]';"
)

for pattern in "${required_integration_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$integration_test"; then
    echo "[FAIL] real HTTPS integration test missing ISSLConnectionInfo-first state helper: $pattern"
    exit 1
  fi
done

echo "[PASS] active generic/integration tests prefer ISSLConnectionInfo.GetStateString"
