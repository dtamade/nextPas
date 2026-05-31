#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

test_file="tests/contract/test_error_mapping_contract.pas"

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

require_absent() {
  local pattern="$1"
  local message="$2"
  if rg -F -n --quiet -- "$pattern" "$test_file"; then
    fail "$message"
  fi
}

echo "[TEST] error mapping contract enum/registration guard"

require_fixed "fafafa.ssl," \
  "error-mapping contract must keep the facade registration path in uses"
require_fixed "SSLErrorToString(sslErrNone)" \
  "error-mapping contract must use the current no-error enum truth"
require_fixed "SSLErrorToString(sslErrNotInitialized)" \
  "error-mapping contract must keep the not-initialized mapping check"
require_fixed "SSLErrorToString(sslErrLoadFailed)" \
  "error-mapping contract must keep the load-failed mapping check"
require_absent "sslErrOK" \
  "error-mapping contract must not regress to the removed sslErrOK symbol"

echo "[PASS] error mapping contract enum/registration anchors present"
