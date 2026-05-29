#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

test_file="tests/test_optional_backends_pkcs12_capability_truth_contract.pas"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_fixed() {
  local pattern="$1"
  local message="$2"
  if ! rg -F -n --quiet -- "$pattern" "$test_file"; then
    fail "$message"
  fi
}

echo "[TEST] optional backends PKCS12 runtime FreePascal coverage contract"

require_fixed "nextpas.core.tls.freepascal.lib," \
  "PKCS12 runtime contract must keep the FreePascal backend registration unit in uses"
require_fixed "CheckBackendCapability(sslFreePascal, False);" \
  "PKCS12 runtime contract must keep the explicit FreePascal capability check"

echo "[PASS] optional backends PKCS12 runtime FreePascal coverage anchors present"
