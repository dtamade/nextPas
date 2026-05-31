#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/run_minimal_ci_gate.sh"
MARKER="$ROOT_DIR/tmp/minimal_ci_gate_module_argument_injection_marker"

trap 'rm -f "$MARKER"' EXIT
rm -f "$MARKER"

echo "[TEST] minimal ci gate should not execute shell payloads embedded in --modules"

set +e
output="$(
  cd "$ROOT_DIR"
  bash "$SCRIPT" \
    --fast-local \
    --skip-compile \
    --skip-phase2-dryrun \
    --modules "PKCS7; touch $MARKER #" 2>&1
)"
exit_code=$?
set -e

if [[ -e "$MARKER" ]]; then
  echo "[FAIL] module payload created marker via shell execution"
  printf '%s\n' "$output"
  exit 1
fi

if rg -n --quiet 'eval "\$cmd"|bash -c "\$cmd"' "$SCRIPT"; then
  echo "[FAIL] minimal ci gate should not keep string-based shell execution helpers"
  exit 1
fi

echo "[INFO] gate exit code under injected module payload: $exit_code"
echo "[PASS] minimal ci gate module argument injection contract passed"
