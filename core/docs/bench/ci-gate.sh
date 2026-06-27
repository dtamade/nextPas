#!/bin/bash
# nextpas bench CI integration template
# Usage: bench-ci-gate.sh [--threshold 1.10] [--baseline-dir .benchbaselines]
#
# Runs benchmarks, compares against saved baseline, gates on regression.
# Exit codes:
#   0 = pass (no regression or no baseline to compare)
#   1 = regression detected (ratio > threshold)
#   2 = benchmark execution failed
#
# Environment variables:
#   BENCH_THRESHOLD  — regression threshold (default: 1.10 = 10%)
#   BENCH_BASELINE_DIR — directory for baseline files (default: .benchbaselines)
#   BENCH_FILTER     — benchmark name filter (optional)
#   BENCH_SAVE       — set to "1" to save current results as new baseline

set -euo pipefail

THRESHOLD="${BENCH_THRESHOLD:-1.10}"
BASELINE_DIR="${BENCH_BASELINE_DIR:-.benchbaselines}"
FILTER="${BENCH_FILTER:-}"
SAVE="${BENCH_SAVE:-0}"

# Parse CLI args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --baseline-dir) BASELINE_DIR="$2"; shift 2 ;;
    --filter) FILTER="$2"; shift 2 ;;
    --save) SAVE=1; shift ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

mkdir -p "$BASELINE_DIR"

BASELINE_FILE="$BASELINE_DIR/current.json"
TIMELINE_FILE="$BASELINE_DIR/timeline.jsonl"
REPORT_FILE="$BASELINE_DIR/report.html"
MATRIX_FILE="$BASELINE_DIR/matrix.html"

echo "=== nextpas bench CI ==="
echo "Threshold: $THRESHOLD"
echo "Baseline dir: $BASELINE_DIR"
echo ""

# Step 1: Run benchmarks with raw samples + JSON output
echo "[1/4] Running benchmarks..."
BENCH_ARGS="--collect-raw-samples --json $BASELINE_DIR/results.json"
if [[ -n "$FILTER" ]]; then
  BENCH_ARGS="$BENCH_ARGS --filter $FILTER"
fi

if ! your-benchmark-binary $BENCH_ARGS; then
  echo "ERROR: Benchmark execution failed"
  exit 2
fi

# Step 2: Save baseline if requested
if [[ "$SAVE" == "1" ]]; then
  echo "[2/4] Saving baseline..."
  # your-benchmark-binary --save-baseline "$BASELINE_FILE" --git-hash "$(git rev-parse HEAD)"
  echo "Baseline saved to $BASELINE_FILE"
else
  echo "[2/4] Skipping baseline save (use --save to enable)"
fi

# Step 3: Compare with existing baseline
echo "[3/4] Comparing with baseline..."
if [[ -f "$BASELINE_FILE" ]]; then
  # your-benchmark-binary --compare "$BASELINE_FILE" --threshold "$THRESHOLD"
  RESULT=$?
  if [[ $RESULT -ne 0 ]]; then
    echo ""
    echo "REGRESSION DETECTED (threshold: $THRESHOLD)"
    echo "Run with --save to accept new baseline after review."
    exit 1
  fi
  echo "No regression detected."
else
  echo "No baseline found at $BASELINE_FILE — skipping comparison."
  echo "Run with --save to create initial baseline."
fi

# Step 4: Append to timeline
echo "[4/4] Updating timeline..."
# your-benchmark-binary --append-timeline "$TIMELINE_FILE"
echo "Timeline updated: $TIMELINE_FILE"

echo ""
echo "=== CI PASS ==="
