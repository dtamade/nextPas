#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

integration_test="tests/integration/test_real_https_connection.pas"
cross_backend_test="tests/integration/test_cross_backend_consistency_contract.pas"

declare -a forbidden_integration_patterns=(
  "Conn.GetSelectedALPNProtocol"
)

for pattern in "${forbidden_integration_patterns[@]}"; do
  if grep -F -q -- "$pattern" "$integration_test"; then
    echo "[FAIL] real HTTPS integration test still uses direct core GetSelectedALPNProtocol: $pattern"
    exit 1
  fi
done

declare -a required_integration_patterns=(
  "function GetConnectionSelectedALPN(AConn: ISSLConnection): string;"
  "Supports(AConn, ISSLConnectionInfo, LConnInfo)"
  "Result := LConnInfo.GetSelectedALPNProtocol"
  "Result := '';"
  "NegotiatedProtocol := GetConnectionSelectedALPN(Conn);"
)

for pattern in "${required_integration_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$integration_test"; then
    echo "[FAIL] real HTTPS integration test missing ISSLConnectionInfo-first ALPN path: $pattern"
    exit 1
  fi
done

declare -a forbidden_cross_backend_patterns=(
  "Conn.GetSelectedALPNProtocol"
)

for pattern in "${forbidden_cross_backend_patterns[@]}"; do
  if grep -F -q -- "$pattern" "$cross_backend_test"; then
    echo "[FAIL] cross-backend consistency contract still uses direct core GetSelectedALPNProtocol: $pattern"
    exit 1
  fi
done

declare -a required_cross_backend_patterns=(
  "function GetNegotiatedALPN(AConn: ISSLConnection): string;"
  "Supports(AConn, ISSLConnectionInfo, LConnInfo)"
  "Result := LConnInfo.GetSelectedALPNProtocol"
  "Result := '';"
  "Alpn := GetNegotiatedALPN(Conn);"
)

for pattern in "${required_cross_backend_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$cross_backend_test"; then
    echo "[FAIL] cross-backend consistency contract missing ISSLConnectionInfo-first ALPN path: $pattern"
    exit 1
  fi
done

echo "[PASS] active integration tests prefer ISSLConnectionInfo.GetSelectedALPNProtocol"
