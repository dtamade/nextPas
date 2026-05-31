#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

before_status="$(git status --porcelain)"

RUN_ID="contract_run_all_benchmarks_$(date +%s)_$$"
SANDBOX_ROOT="tmp/$RUN_ID"
OUTPUT_DIR="$SANDBOX_ROOT/results"
BIN_DIR="$SANDBOX_ROOT/bin"

rm -rf "$SANDBOX_ROOT"
mkdir -p "$OUTPUT_DIR" "$BIN_DIR"

set +e
bash tests/benchmarks/run_all_benchmarks.sh \
  --iterations 1 \
  --skip-tls \
  --output "$OUTPUT_DIR" \
  --bin-dir "$BIN_DIR" \
  > "$SANDBOX_ROOT/runner_stdout.log" 2>&1
exit_code=$?
set -e

if [[ "$exit_code" -ne 0 ]]; then
  echo "[FAIL] run_all_benchmarks should pass for cert verify cache contract (got: $exit_code)"
  sed -n '1,220p' "$SANDBOX_ROOT/runner_stdout.log" || true
  exit 1
fi

summary_file="$(find "$OUTPUT_DIR" -maxdepth 1 -type f -name 'benchmark_summary_*.txt' | head -1)"
if [[ -z "$summary_file" ]]; then
  echo "[FAIL] missing benchmark summary output"
  exit 1
fi

cache_log="$(find "$OUTPUT_DIR" -maxdepth 1 -type f -name 'benchmark_cert_verify_cache_*.log' | head -1)"
if [[ -z "$cache_log" ]]; then
  echo "[FAIL] missing benchmark_cert_verify_cache log output"
  ls -la "$OUTPUT_DIR" || true
  exit 1
fi

if ! rg -q 'benchmark_cert_verify_cache' "$summary_file"; then
  echo "[FAIL] summary should include benchmark_cert_verify_cache section"
  sed -n '1,220p' "$summary_file" || true
  exit 1
fi

if ! rg -q 'Iterations: 1' "$cache_log"; then
  echo "[FAIL] cert verify cache benchmark should honor requested iterations"
  sed -n '1,220p' "$cache_log" || true
  exit 1
fi

if ! rg -q 'Speedup Factor:' "$cache_log"; then
  echo "[FAIL] cert verify cache benchmark log missing speedup output"
  sed -n '1,220p' "$cache_log" || true
  exit 1
fi

rm -rf "$SANDBOX_ROOT"

after_status="$(git status --porcelain)"
if [[ "$before_status" != "$after_status" ]]; then
  echo "[FAIL] run_all_benchmarks cert verify cache contract changed git status output"
  echo "[INFO] before:"
  printf '%s\n' "$before_status"
  echo "[INFO] after:"
  printf '%s\n' "$after_status"
  exit 1
fi

echo "[PASS] run_all_benchmarks integrates cert verify cache benchmark with isolated outputs"
