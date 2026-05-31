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

RUN_ID="contract_phase2_fast_local_$(date +%s)_$$"

set +e
output="$(bash scripts/run_phase2_performance_baseline.sh --dry-run --fast-local --run-id "$RUN_ID" --iterations 10 --tls-iterations 1 2>&1)"
exit_code=$?
set -e

if [[ "$exit_code" -ne 0 ]]; then
  echo "[FAIL] run_phase2_performance_baseline --dry-run should exit 0 (got: $exit_code)"
  echo "[INFO] output:"
  printf '%s\n' "$output"
  exit 1
fi

after_status="$(git status --porcelain)"

if [[ "$before_status" != "$after_status" ]]; then
  echo "[FAIL] run_phase2_performance_baseline --dry-run changed git status output"
  echo "[INFO] before:"
  printf '%s\n' "$before_status"
  echo "[INFO] after:"
  printf '%s\n' "$after_status"
  exit 1
fi

bench_out_dir="$(printf '%s\n' "$output" | awk -F': ' 'index($0, "[INFO] bench_output_dir: ") == 1 {print $2; exit}')"
bench_bin_dir="$(printf '%s\n' "$output" | awk -F': ' 'index($0, "[INFO] bench_bin_dir: ") == 1 {print $2; exit}')"
doc_reports_dir="$(printf '%s\n' "$output" | awk -F': ' 'index($0, "[INFO] doc_reports_dir: ") == 1 {print $2; exit}')"

if [[ -z "$bench_out_dir" || -z "$bench_bin_dir" || -z "$doc_reports_dir" ]]; then
  echo "[FAIL] missing bench_output_dir/bench_bin_dir/doc_reports_dir lines in output"
  echo "[INFO] output:"
  printf '%s\n' "$output"
  exit 1
fi

if [[ "$bench_out_dir" != "$PROJECT_ROOT/tmp/phase2_bench_results_${RUN_ID}" ]]; then
  echo "[FAIL] fast-local bench_output_dir mismatch (expected: $PROJECT_ROOT/tmp/phase2_bench_results_${RUN_ID}, got: $bench_out_dir)"
  exit 1
fi

if [[ "$bench_bin_dir" != "$PROJECT_ROOT/tmp/phase2_bench_bin_${RUN_ID}" ]]; then
  echo "[FAIL] fast-local bench_bin_dir mismatch (expected: $PROJECT_ROOT/tmp/phase2_bench_bin_${RUN_ID}, got: $bench_bin_dir)"
  exit 1
fi

if [[ "$doc_reports_dir" != "$PROJECT_ROOT/tmp/test-reports" ]]; then
  echo "[FAIL] fast-local doc_reports_dir mismatch (expected: $PROJECT_ROOT/tmp/test-reports, got: $doc_reports_dir)"
  exit 1
fi

echo "[PASS] run_phase2_performance_baseline --dry-run fast-local keeps workspace clean and uses tmp paths"
