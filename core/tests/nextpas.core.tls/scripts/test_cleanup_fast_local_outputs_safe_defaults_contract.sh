#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

SANDBOX_ROOT="tmp/contract_cleanup_fast_local_outputs"

rm -rf "$SANDBOX_ROOT"
mkdir -p "$SANDBOX_ROOT"

mkdir -p "$SANDBOX_ROOT/minimal_ci_gate_compile_units_foo"
mkdir -p "$SANDBOX_ROOT/wave_b_ci_gate_reports_foo"
mkdir -p "$SANDBOX_ROOT/phase2_bench_bin_foo"
mkdir -p "$SANDBOX_ROOT/phase2_bench_results_foo"
mkdir -p "$SANDBOX_ROOT/wave_c_b101_bench_bin_foo"
mkdir -p "$SANDBOX_ROOT/wave_c_b101_module_reports_foo"
mkdir -p "$SANDBOX_ROOT/bin"
mkdir -p "$SANDBOX_ROOT/test-reports"
mkdir -p "$SANDBOX_ROOT/keep_me"

echo "x" > "$SANDBOX_ROOT/minimal_ci_gate_compile_units_foo/sentinel.txt"
echo "x" > "$SANDBOX_ROOT/wave_b_ci_gate_reports_foo/sentinel.txt"
echo "x" > "$SANDBOX_ROOT/phase2_bench_bin_foo/sentinel.txt"
echo "x" > "$SANDBOX_ROOT/phase2_bench_results_foo/sentinel.txt"
echo "x" > "$SANDBOX_ROOT/wave_c_b101_bench_bin_foo/sentinel.txt"
echo "x" > "$SANDBOX_ROOT/wave_c_b101_module_reports_foo/sentinel.txt"
echo "x" > "$SANDBOX_ROOT/bin/fast_local.bin"
echo "x" > "$SANDBOX_ROOT/test-reports/fast_local.log"
echo "x" > "$SANDBOX_ROOT/keep_me/keep.txt"

set +e
output="$(bash scripts/cleanup_fast_local_outputs.sh --tmp-root "$SANDBOX_ROOT" --all 2>&1)"
exit_code=$?
set -e

if [[ "$exit_code" -ne 0 ]]; then
  echo "[FAIL] cleanup_fast_local_outputs dry-run should exit 0 (got: $exit_code)"
  echo "[INFO] output:"
  printf '%s\n' "$output"
  exit 1
fi

if [[ ! -d "$SANDBOX_ROOT/minimal_ci_gate_compile_units_foo" ]]; then
  echo "[FAIL] dry-run must not delete candidate dirs"
  exit 1
fi

if [[ ! -d "$SANDBOX_ROOT/keep_me" ]]; then
  echo "[FAIL] dry-run must not delete non-candidate dirs"
  exit 1
fi

set +e
output_apply="$(bash scripts/cleanup_fast_local_outputs.sh --tmp-root "$SANDBOX_ROOT" --all --apply 2>&1)"
exit_code_apply=$?
set -e

if [[ "$exit_code_apply" -ne 0 ]]; then
  echo "[FAIL] cleanup_fast_local_outputs --apply should exit 0 (got: $exit_code_apply)"
  echo "[INFO] output:"
  printf '%s\n' "$output_apply"
  exit 1
fi

if [[ -d "$SANDBOX_ROOT/minimal_ci_gate_compile_units_foo" || -d "$SANDBOX_ROOT/wave_b_ci_gate_reports_foo" || -d "$SANDBOX_ROOT/phase2_bench_bin_foo" || -d "$SANDBOX_ROOT/phase2_bench_results_foo" || -d "$SANDBOX_ROOT/wave_c_b101_bench_bin_foo" || -d "$SANDBOX_ROOT/wave_c_b101_module_reports_foo" ]]; then
  echo "[FAIL] --apply --all should delete known candidate dirs"
  exit 1
fi

if [[ -e "$SANDBOX_ROOT/bin" || -e "$SANDBOX_ROOT/test-reports" ]]; then
  echo "[FAIL] --apply --all should remove fast-local aggregate dirs"
  exit 1
fi

if [[ ! -d "$SANDBOX_ROOT/keep_me" ]]; then
  echo "[FAIL] --apply must not delete non-candidate dirs"
  exit 1
fi

rm -rf "$SANDBOX_ROOT"

echo "[PASS] cleanup_fast_local_outputs safe defaults contract passed"
