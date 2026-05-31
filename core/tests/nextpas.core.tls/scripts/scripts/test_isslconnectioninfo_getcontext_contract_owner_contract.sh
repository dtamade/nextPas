#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

target="tests/contract/test_backend_contract.pas"

declare -a required_patterns=(
  "LOptionalCtx := LConnInfoAccess.GetContext;"
  "ISSLConnectionInfo.GetContext returned nil"
  "ISSLConnectionInfo.GetContext.GetContextType does not match the creation context type"
  "LCoreCtx := LConn.GetContext;"
  "ISSLConnection.GetContext mirror returned nil"
  "ISSLConnection.GetContext does not mirror ISSLConnectionInfo.GetContext"
)

for pattern in "${required_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$target"; then
    echo "[FAIL] backend contract missing GetContext owner-primacy pattern: $pattern"
    exit 1
  fi
done

declare -a forbidden_patterns=(
  "ISSLConnectionInfo.GetContext or ISSLConnection.GetContext returned nil"
  "ISSLConnectionInfo.GetContext.GetContextType does not match ISSLConnection.GetContext"
)

for pattern in "${forbidden_patterns[@]}"; do
  if grep -F -q -- "$pattern" "$target"; then
    echo "[FAIL] backend contract still carries legacy dual-owner GetContext wording: $pattern"
    exit 1
  fi
done

echo "[PASS] backend contract treats ISSLConnectionInfo.GetContext as the primary owner"
