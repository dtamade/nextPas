#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/run_minimal_ci_gate.sh"
MARKER="$ROOT_DIR/tmp/minimal_ci_gate_eval_contract_marker"

fail() {
  echo "[FAIL] $1"
  exit 1
}

trap 'rm -f "$MARKER"' EXIT
rm -f "$MARKER"

echo "[TEST] minimal ci gate eval injection contract"

set +e
output="$(
  bash "$SCRIPT" \
    --skip-compile \
    --skip-phase2-dryrun \
    --modules "PKCS7 --dry-run; touch $MARKER" 2>&1
)"
status=$?
set -e

if [[ -e "$MARKER" ]]; then
  printf '%s\n' "$output"
  fail "minimal ci gate executed injected shell content from --modules"
fi

if rg -n --quiet 'eval "\$cmd"' "$SCRIPT"; then
  fail "minimal ci gate should not execute assembled commands with eval"
fi

echo "[INFO] exit_code=$status"
echo "[PASS] minimal ci gate eval injection contract passed"
