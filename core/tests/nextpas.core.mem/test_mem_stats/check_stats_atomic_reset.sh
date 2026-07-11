#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="$SCRIPT_DIR/../../../src/nextpas.core.mem.stats.pas"

fail() {
  echo "stats-atomic-reset-contract=fail: $1" >&2
  exit 1
}

RESET_BODY="$({
  awk '
    /^procedure TAllocStatsAllocator\.ResetStats;/ { in_reset = 1 }
    in_reset { print }
    in_reset && /^end;$/ { exit }
  ' "$SOURCE_FILE"
})"

[[ -n "$RESET_BODY" ]] || fail "ResetStats implementation not found"

require_reset_call() {
  local counter="$1"
  grep -Fq "InterlockedExchange64($counter, 0);" <<<"$RESET_BODY" ||
    fail "$counter is not reset atomically"
}

require_reset_call "FTotalAllocs"
require_reset_call "FTotalFrees"
require_reset_call "FTotalBytesAllocated"
require_reset_call "FPeakAllocs"
require_reset_call "FHistogram.Buckets[LIndex]"
require_reset_call "FHistogram.TotalBytes"
require_reset_call "FHistogram.TotalCount"

COMPACT_BODY="$(tr -d '[:space:]' <<<"$RESET_BODY")"
ACTIVE_LOAD_COUNT="$(grep -oF \
  'InterlockedCompareExchange64(FActiveAllocs,0,0)' <<<"$COMPACT_BODY" |
  wc -l || true)"

[[ "$ACTIVE_LOAD_COUNT" -ge 2 ]] ||
  fail "active allocation gauge must be loaded atomically before and after peak reset"
grep -Fq 'UpdatePeak(FPeakAllocs,' <<<"$RESET_BODY" ||
  fail "peak counter is not reconciled after reset"
if grep -Fq 'FActiveAllocs :=' <<<"$RESET_BODY"; then
  fail "ResetStats must not overwrite the active allocation gauge"
fi
if grep -Fq 'FillChar(FHistogram' <<<"$RESET_BODY"; then
  fail "histogram reset races with atomic updates"
fi

echo "stats-atomic-reset-contract=pass"
