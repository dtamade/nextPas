#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/archive_ci_artifacts_draft.sh"

WORK_REL="tmp/test_archive_ci_artifacts_output_root_contract"
REL_OUTPUT_ROOT="$WORK_REL/ci_out"
RUN_ID="archive_ci_artifacts_output_root_contract_run"

assert_output_root_is_normalized() {
  local out="$1"
  local expected="output_root: $ROOT_DIR/$REL_OUTPUT_ROOT"

  if ! grep -Fq "$expected" <<<"$out"; then
    echo "[FAIL] expected normalized output_root line"
    echo "[FAIL] expected: $expected"
    echo "[FAIL] got:"
    echo "$out"
    exit 1
  fi
}

mkdir -p "$ROOT_DIR/$WORK_REL"

out_root="$(cd "$ROOT_DIR" && bash "$SCRIPT" \
  --profile pr \
  --run-id "$RUN_ID" \
  --output-root "$REL_OUTPUT_ROOT" \
  --dry-run)"

assert_output_root_is_normalized "$out_root"

out_tmp="$(cd /tmp && bash "$SCRIPT" \
  --profile pr \
  --run-id "$RUN_ID" \
  --output-root "$REL_OUTPUT_ROOT" \
  --dry-run)"

assert_output_root_is_normalized "$out_tmp"

echo "[PASS] output-root path contract passed"

