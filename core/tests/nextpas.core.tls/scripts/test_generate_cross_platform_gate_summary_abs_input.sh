#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/generate_cross_platform_gate_summary_draft.sh"
ABS_INPUT="$ROOT_DIR/docs/test_reports/GATE_ARCHIVE_EVIDENCE_SAMPLE_B16.md"
REL_OUTPUT="tmp/test_generate_cross_platform_gate_summary_abs/out.md"

require_line() {
  local file="$1"
  local expected="$2"
  if ! rg -F --quiet "$expected" "$file"; then
    echo "[FAIL] missing expected line: $expected"
    echo "[INFO] top of output:"
    sed -n '1,120p' "$file"
    exit 1
  fi
}

run_main_contract() {
  local out="$ROOT_DIR/$REL_OUTPUT"
  rm -f "$out"
  mkdir -p "$(dirname "$out")"

  (cd "$ROOT_DIR" && bash "$SCRIPT" \
    --run-id tdd_cross_platform_abs_root \
    --input "$ABS_INPUT" \
    --output "$REL_OUTPUT" >/dev/null 2>/dev/null)

  if [[ ! -f "$out" ]]; then
    echo "[FAIL] output missing for root-dir execution"
    exit 1
  fi

  require_line "$out" "| linux | nightly | b16_sample_20260207_0456 | L2 |"

  rm -f "$out"
  (cd /tmp && bash "$SCRIPT" \
    --run-id tdd_cross_platform_abs_tmp \
    --input "$ABS_INPUT" \
    --output "$REL_OUTPUT" >/dev/null 2>/dev/null)

  if [[ ! -f "$out" ]]; then
    echo "[FAIL] output should be resolved under project root for relative --output"
    exit 1
  fi

  require_line "$out" "| linux | nightly | b16_sample_20260207_0456 | L2 |"
  echo "[PASS] absolute input contract passed"
}

run_main_contract
