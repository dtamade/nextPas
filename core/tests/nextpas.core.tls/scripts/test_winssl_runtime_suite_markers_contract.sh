#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_FILE="$ROOT_DIR/tests/run_winssl_tests.ps1"

fail() {
  echo "[FAIL] $1"
  exit 1
}

[[ -f "$SCRIPT_FILE" ]] || fail "missing script: tests/run_winssl_tests.ps1"

require_match() {
  local pattern="$1"
  local message="$2"
  if ! rg -n --fixed-strings --quiet -- "$pattern" "$SCRIPT_FILE"; then
    fail "$message"
  fi
}

require_match 'function Write-EvidenceMarker' \
  'tests/run_winssl_tests.ps1 should define a dedicated runtime evidence marker helper'
require_match '[WINSSL-RUNTIME] ' \
  'tests/run_winssl_tests.ps1 should emit stable [WINSSL-RUNTIME] marker lines'
require_match 'suite_start total=' \
  'tests/run_winssl_tests.ps1 should announce suite_start markers'
require_match 'suite_summary passed=' \
  'tests/run_winssl_tests.ps1 should announce suite_summary markers'
require_match 'suite_end status=PASS' \
  'tests/run_winssl_tests.ps1 should emit a PASS suite_end marker'
require_match 'suite_end status=FAIL' \
  'tests/run_winssl_tests.ps1 should emit a FAIL suite_end marker'

echo "[PASS] winssl runtime suite markers contract passed"
