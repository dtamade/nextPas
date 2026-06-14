#!/usr/bin/env bash
# platform-wine-runtime-smoke.sh
# Run all Wine runtime smoke tests for platform modules.
# Usage: ./scripts/platform-wine-runtime-smoke.sh [--verbose]
#
# Evidence tier: wine-runtime-smoke (NOT real Windows runtime evidence)
#
# Each test is cross-compiled to Win64 via fpc -Twin64 -Px86_64 and executed
# under Wine. Tests that fail to compile or run are recorded but do not block
# subsequent tests.

set -euo pipefail

VERBOSE=0
if [[ "${1:-}" == "--verbose" ]]; then
  VERBOSE=1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_ROOT="$(cd "$SCRIPT_DIR/../core" && pwd)"
WINE="${WINE:-wine}"

# Check Wine availability
if ! command -v "$WINE" >/dev/null 2>&1; then
  echo "ERROR: Wine not found. Set WINE env var or install wine."
  echo "truth=wine-runtime-smoke; skipped; wine missing"
  exit 2
fi

echo "truth=wine-runtime-smoke; NOT real Windows runtime evidence"
echo "Wine: $WINE"
echo "Core root: $CORE_ROOT"
echo ""

WINE_TESTS=(
  $(find "$CORE_ROOT/tests" -name Makefile -path '*_wine/*' \
    | sed "s|$CORE_ROOT/||; s|/Makefile$||" | sort)
)

TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0
FAIL_LIST=""

for test_dir in "${WINE_TESTS[@]}"; do
  TOTAL=$((TOTAL + 1))
  name="$(basename "$test_dir")"
  dir="$CORE_ROOT/$test_dir"

  if [[ ! -d "$dir" ]]; then
    echo "SKIP: $name (directory not found)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  echo "--- $name ---"
  if [[ "$VERBOSE" -eq 1 ]]; then
    if make -C "$dir" wine-runtime-smoke 2>&1; then
      echo "  RESULT: PASS"
      PASSED=$((PASSED + 1))
    else
      echo "  RESULT: FAIL"
      FAILED=$((FAILED + 1))
      FAIL_LIST="$FAIL_LIST $name"
    fi
  else
    output="$(make -C "$dir" wine-runtime-smoke 2>&1)" || true
    # Extract the summary line and heaptrc line
    summary="$(echo "$output" | grep -E '^---.*: [0-9]+ total' | tail -1)" || true
    heap="$(echo "$output" | grep -E '^\d+ memory blocks freed' | tail -1)" || true
    if [[ -n "$summary" ]]; then
      echo "  $summary"
    fi
    if [[ -n "$heap" ]]; then
      echo "  $heap"
    fi
    if echo "$summary" | grep -q '0 failed'; then
      echo "  RESULT: PASS"
      PASSED=$((PASSED + 1))
    else
      echo "  RESULT: FAIL"
      FAILED=$((FAILED + 1))
      FAIL_LIST="$FAIL_LIST $name"
      # Print full output on failure
      echo "$output" | tail -20
    fi
  fi
  echo ""
done

echo "========================================"
echo "TOTAL: $TOTAL  PASSED: $PASSED  FAILED: $FAILED  SKIPPED: $SKIPPED"
if [[ -n "$FAIL_LIST" ]]; then
  echo "FAILED:$FAIL_LIST"
fi
echo "========================================"
echo "truth=wine-runtime-smoke; not real Windows runtime ready"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
