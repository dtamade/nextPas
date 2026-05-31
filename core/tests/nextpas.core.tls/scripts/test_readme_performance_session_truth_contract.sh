#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

readme="README.md"

require_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if ! rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_absent() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_fixed '- **能力矩阵缓存**: 具体性能收益请以 fresh benchmark 为准；当前 benchmark/baseline 入口见 `docs/guides/PERFORMANCE_GUIDE.md`、`scripts/run_phase2_performance_baseline.sh` 与 `tests/benchmarks/run_all_benchmarks.sh`。' \
  "$readme" \
  "README must route capability-matrix performance claims back to fresh benchmark truth"

require_fixed '- **会话复用 / Session Ticket**: 属于 backend-specific truth；尤其 WinSSL 当前仍按 experimental public surface 理解，不应在首页直接承诺固定握手收益。' \
  "$readme" \
  "README must demote fixed session-resumption claims to backend-specific truth"

require_absent '- **极致性能**: 能力矩阵缓存，10,000x+ 性能提升（>10M ops/s）' \
  "$readme" \
  "README must stop presenting fixed capability-matrix speedup as current truth"

require_absent '- **会话复用**: 70-90% 握手性能提升' \
  "$readme" \
  "README must stop presenting fixed handshake gains as current truth"

echo "[PASS] README high-entry performance/session truth is aligned"
