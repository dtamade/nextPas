#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/run_minimal_ci_gate.sh"

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "[TEST] minimal ci gate fpc host passthrough contract"

OUT="$(
  cd /tmp
  FAFAFA_FPC_EXE="contract-fpc" \
  bash "$SCRIPT" --dry-run --modules PKCS7 --skip-phase2-dryrun 2>&1
)"

if [[ "$OUT" != *"python3 scripts/compile_all_modules.py --unit-output-dir"*"--fpc-exe 'contract-fpc'"* ]]; then
  echo "$OUT"
  fail "compile step should passthrough --fpc-exe override"
fi

if [[ "$OUT" != *"FAFAFA_FPC_EXE='contract-fpc'"* ]]; then
  echo "$OUT"
  fail "module step should passthrough FAFAFA_FPC_EXE"
fi

echo "[PASS] minimal ci gate fpc host passthrough contract passed"
