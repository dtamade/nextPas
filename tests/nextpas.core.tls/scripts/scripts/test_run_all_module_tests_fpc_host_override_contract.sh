#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/run_all_module_tests.sh"

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "[TEST] run_all_module_tests fpc host override contract"

if ! rg -F --quiet -- 'FPC_EXE="${FAFAFA_FPC_EXE:-fpc}"' "$SCRIPT"; then
  fail "script should expose FAFAFA_FPC_EXE override with default fpc"
fi

if ! rg -F --quiet -- 'if [[ "$FPC_EXE" == */* ]]; then' "$SCRIPT"; then
  fail "script should support absolute-path executable resolution branch"
fi

if ! rg -F --quiet -- 'if ! command -v "$FPC_EXE" >/dev/null 2>&1; then' "$SCRIPT"; then
  fail "script should verify named FPC executable availability"
fi

if ! rg -F --quiet -- 'if "$FPC_EXE" -Mobjfpc -Sh -O2 \' "$SCRIPT"; then
  fail "compile step should invoke resolved FPC executable"
fi

echo "[PASS] run_all_module_tests fpc host override contract passed"
