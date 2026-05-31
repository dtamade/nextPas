#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

target="tests/contract/test_backend_contract.pas"

declare -a required_patterns=(
  "LOptionalInfo := LConnInfoAccess.GetConnectionInfo;"
  "LCoreInfo := LConn.GetConnectionInfo;"
  "Core GetConnectionInfo mirror drifted from optional owner protocol version"
  "ISSLConnection.GetConnectionInfo.ProtocolVersion does not mirror ISSLConnectionInfo.GetConnectionInfo"
  "Core GetConnectionInfo mirror drifted from optional owner cipher suite"
  "ISSLConnection.GetConnectionInfo.CipherSuite does not mirror ISSLConnectionInfo.GetConnectionInfo"
  "Core GetConnectionInfo mirror drifted from optional owner ALPN field"
  "ISSLConnection.GetConnectionInfo.ALPNProtocol does not mirror ISSLConnectionInfo.GetConnectionInfo"
)

for pattern in "${required_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$target"; then
    echo "[FAIL] backend contract missing GetConnectionInfo owner-primacy pattern: $pattern"
    exit 1
  fi
done

declare -a forbidden_patterns=(
  "Optional interface protocol version drifted from core getter"
  "ISSLConnectionInfo.GetConnectionInfo.ProtocolVersion does not match ISSLConnection.GetConnectionInfo"
  "Optional interface cipher suite drifted from core getter"
  "ISSLConnectionInfo.GetConnectionInfo.CipherSuite does not match ISSLConnection.GetConnectionInfo"
  "Optional interface ALPN drifted from core getter"
  "ISSLConnectionInfo.GetConnectionInfo.ALPNProtocol does not match ISSLConnection.GetConnectionInfo"
)

for pattern in "${forbidden_patterns[@]}"; do
  if grep -F -q -- "$pattern" "$target"; then
    echo "[FAIL] backend contract still carries legacy dual-owner GetConnectionInfo wording: $pattern"
    exit 1
  fi
done

echo "[PASS] backend contract treats ISSLConnectionInfo.GetConnectionInfo as the primary owner"
