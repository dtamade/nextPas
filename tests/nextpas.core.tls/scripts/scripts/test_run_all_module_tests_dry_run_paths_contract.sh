#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[SKIP] not a git worktree"
  exit 0
fi

before_status="$(git status --porcelain)"

set +e
output="$(bash scripts/run_all_module_tests.sh --dry-run --modules PKCS7 2>&1)"
exit_code=$?
set -e

if [[ "$exit_code" -ne 0 ]]; then
  echo "[FAIL] run_all_module_tests --dry-run should exit 0 (got: $exit_code)"
  echo "[INFO] output:"
  printf '%s\n' "$output"
  exit 1
fi

after_status="$(git status --porcelain)"

if [[ "$before_status" != "$after_status" ]]; then
  echo "[FAIL] run_all_module_tests --dry-run changed git status output"
  echo "[INFO] before:"
  printf '%s\n' "$before_status"
  echo "[INFO] after:"
  printf '%s\n' "$after_status"
  exit 1
fi

bin_dir="$(printf '%s\n' "$output" | awk -F': ' '/^Binary output dir: / {print $2; exit}')"
reports_dir="$(printf '%s\n' "$output" | awk -F': ' '/^Reports dir: / {print $2; exit}')"
unit_dir="$(printf '%s\n' "$output" | awk -F': ' '/^FPC unit output dir: / {print $2; exit}')"

if [[ -z "$bin_dir" || -z "$reports_dir" || -z "$unit_dir" ]]; then
  echo "[FAIL] missing config lines in --dry-run output"
  echo "[INFO] output:"
  printf '%s\n' "$output"
  exit 1
fi

if [[ "$bin_dir" != "$PROJECT_ROOT"/tmp/* ]]; then
  echo "[FAIL] default BIN_DIR should live under ./tmp (got: $bin_dir)"
  exit 1
fi

if [[ "$reports_dir" != "$PROJECT_ROOT"/tmp/* ]]; then
  echo "[FAIL] default REPORTS_DIR should live under ./tmp (got: $reports_dir)"
  exit 1
fi

if [[ "$unit_dir" != "$PROJECT_ROOT"/tmp/* ]]; then
  echo "[FAIL] default FPC_UNIT_OUTPUT_DIR should live under ./tmp (got: $unit_dir)"
  exit 1
fi

echo "[PASS] run_all_module_tests --dry-run keeps workspace clean and defaults to tmp paths"
