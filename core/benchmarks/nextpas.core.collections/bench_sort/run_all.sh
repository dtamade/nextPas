#!/bin/bash
# Run all sort benchmarks and produce comparison table
# Usage: ./run_all.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.." || exit 1

echo "================================================================"
echo "  Sort Benchmark Comparison (N=10000, sort int32 array)"
echo "  Machine: $(uname -m) $(cat /proc/cpuinfo 2>/dev/null | grep 'model name' | head -1 | cut -d: -f2 | xargs)"
echo "  Date: $(date +%Y-%m-%d)"
echo "================================================================"
echo

echo "--- nextPas Vec.Sort (introsort + 3-way partition) ---"
timeout 30 "$SCRIPT_DIR/bench_sort" 2>/dev/null || echo "  (binary not found, compile first)"
echo

echo "--- FPC Baseline (plain quicksort, no introsort) ---"
timeout 15 "$SCRIPT_DIR/compare_fpcrtl/bench_sort_fpcrtl" 2>/dev/null || echo "  (binary not found)"
echo

echo "--- Go sort.Ints (pdqsort) ---"
timeout 30 "$SCRIPT_DIR/compare_go/bench_sort_go" 2>/dev/null || echo "  (binary not found)"
echo

echo "--- Rust sort_unstable (pdqsort) ---"
timeout 30 "$SCRIPT_DIR/compare_rust/target/release/bench_sort" 2>/dev/null || echo "  (binary not found)"
echo

echo "================================================================"
echo "  NOTES:"
echo "  - nextPas uses TCompareProxyMethod (indirect call), adding overhead"
echo "  - Go/Rust use monomorphized inline comparisons"
echo "  - FPC baseline uses direct integer comparison (best-case for FPC)"
echo "  - 'all-same' tests 3-way partition effectiveness"
echo "  - Plain quicksort CANNOT handle all-same (O(n^2) degradation)"
echo "================================================================"
