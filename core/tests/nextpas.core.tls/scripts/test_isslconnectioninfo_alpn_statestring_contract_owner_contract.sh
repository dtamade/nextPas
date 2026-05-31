#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

target="tests/contract/test_backend_contract.pas"

declare -a required_patterns=(
  "LConnInfoAccess.GetSelectedALPNProtocol <> LCoreALPN"
  "Core GetSelectedALPNProtocol mirror drifted from optional owner"
  "ISSLConnection.GetSelectedALPNProtocol does not mirror ISSLConnectionInfo.GetSelectedALPNProtocol"
  "the single ALPN mirror proof while the public core declaration"
  "compiler-deprecated in favor of ISSLConnectionInfo.GetSelectedALPNProtocol."
  "LCoreStateString := LConn.GetStateString;"
  "LConnInfoAccess.GetStateString <> LCoreStateString"
  "Core GetStateString mirror drifted from optional owner"
  "ISSLConnection.GetStateString does not mirror ISSLConnectionInfo.GetStateString"
  "the single state-string mirror proof while the public core declaration"
  "compiler-deprecated in favor of ISSLConnectionInfo.GetStateString."
)

for pattern in "${required_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$target"; then
    echo "[FAIL] backend contract missing ALPN/state-string owner-primacy pattern: $pattern"
    exit 1
  fi
done

declare -a forbidden_patterns=(
  "Optional interface ALPN getter drifted from core getter"
  "ISSLConnectionInfo.GetSelectedALPNProtocol does not match ISSLConnection.GetSelectedALPNProtocol"
  "Optional interface state string drifted from core getter"
  "ISSLConnectionInfo.GetStateString does not match ISSLConnection.GetStateString"
)

for pattern in "${forbidden_patterns[@]}"; do
  if grep -F -q -- "$pattern" "$target"; then
    echo "[FAIL] backend contract still carries legacy dual-owner ALPN/state-string wording: $pattern"
    exit 1
  fi
done

echo "[PASS] backend contract treats ISSLConnectionInfo ALPN/state-string getters as the primary owners"
