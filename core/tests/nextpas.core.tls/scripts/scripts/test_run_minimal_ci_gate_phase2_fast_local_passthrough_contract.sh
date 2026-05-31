#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

set +e
before_status="$(git status --porcelain)"
output="$(bash scripts/run_minimal_ci_gate.sh --fast-local --skip-compile --skip-modules 2>&1)"
exit_code=$?
set -e

if [[ "$exit_code" -ne 0 ]]; then
  echo "[FAIL] run_minimal_ci_gate fast-local phase2 passthrough should exit 0 (got: $exit_code)"
  printf '%s\n' "$output"
  exit 1
fi

after_status="$(git status --porcelain)"
if [[ "$before_status" != "$after_status" ]]; then
  echo "[FAIL] run_minimal_ci_gate fast-local contract changed git status output"
  echo "[INFO] before:"
  printf '%s\n' "$before_status"
  echo "[INFO] after:"
  printf '%s\n' "$after_status"
  exit 1
fi

if ! printf '%s\n' "$output" | rg -F --quiet "scripts/run_phase2_performance_baseline.sh --dry-run --iterations 200 --tls-iterations 50 --fast-local"; then
  echo "[FAIL] minimal gate must pass --fast-local to phase2 baseline dry-run"
  printf '%s\n' "$output"
  exit 1
fi

output_run_id="$(printf '%s\n' "$output" | awk -F': ' 'index($0, "[INFO] run_id: ") == 1 {print $2; exit}')"
bench_out_dir="$(printf '%s\n' "$output" | awk -F': ' 'index($0, "[INFO] bench_output_dir: ") == 1 {print $2; exit}')"
bench_bin_dir="$(printf '%s\n' "$output" | awk -F': ' 'index($0, "[INFO] bench_bin_dir: ") == 1 {print $2; exit}')"
doc_reports_dir="$(printf '%s\n' "$output" | awk -F': ' 'index($0, "[INFO] doc_reports_dir: ") == 1 {print $2; exit}')"

if [[ -z "$output_run_id" || -z "$bench_out_dir" || -z "$bench_bin_dir" || -z "$doc_reports_dir" ]]; then
  echo "[FAIL] missing phase2 dry-run config lines in minimal gate output"
  printf '%s\n' "$output"
  exit 1
fi

if [[ "$bench_out_dir" != "$PROJECT_ROOT/tmp/phase2_bench_results_${output_run_id}" ]]; then
  echo "[FAIL] minimal gate phase2 bench output must stay under tmp"
  echo "[INFO] run_id=$output_run_id"
  echo "[INFO] bench_output_dir=$bench_out_dir"
  exit 1
fi

if [[ "$bench_bin_dir" != "$PROJECT_ROOT/tmp/phase2_bench_bin_${output_run_id}" ]]; then
  echo "[FAIL] minimal gate phase2 bench bin must stay under tmp"
  echo "[INFO] run_id=$output_run_id"
  echo "[INFO] bench_bin_dir=$bench_bin_dir"
  exit 1
fi

if [[ "$doc_reports_dir" != "$PROJECT_ROOT/tmp/test-reports" ]]; then
  echo "[FAIL] minimal gate phase2 doc reports must stay under tmp"
  echo "[INFO] doc_reports_dir=$doc_reports_dir"
  exit 1
fi

echo "[PASS] run_minimal_ci_gate fast-local passes tmp-scoped phase2 dry-run config"
