#!/bin/bash
# perf-regression-check.sh — 性能回归检测（可选 CI）
#
# 对标 benchstat 意图，不是硬多 OS 性能 SLA。
#
# 用法:
#   ./perf-regression-check.sh [threshold_percent]
#
# 环境变量:
#   PERF_BASELINE   — baseline 文件路径（默认 perf-baseline.json）
#   PERF_HOST_TAG   — 若设且默认文件不存在，尝试 perf-baseline.<tag>.json
#                     例: PERF_HOST_TAG=linux-x64
#   PERF_SKIP=1     — 直接 skip（exit 0），用于非主门禁 host / wine / 跨机
#
# 参数:
#   threshold_percent — 回归阈值（默认 30%，宽松防 flaky）
#
# 策略（v8.13）:
#   - linux-x64 本机：可对比入库 baseline（可选 commit）
#   - macOS / wine / 其它 host：默认 skip 或使用本机私有 baseline，
#     **禁止** 把跨 OS 数字当作默认 CI fail 门禁
#
# CI:
#   - 首次生成: ./perf-regression-check.sh
#   - 后续对比: ./perf-regression-check.sh 30
#   - make -C core/tests/nextpas.core.test/test_perf_bench regression

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [[ "${PERF_SKIP:-0}" == "1" ]]; then
  echo "SKIP: PERF_SKIP=1 (optional perf gate disabled for this host/job)"
  exit 0
fi

THRESHOLD=${1:-30}
BASELINE_FILE="${PERF_BASELINE:-perf-baseline.json}"

# Optional host-tagged fallback when default missing
if [[ ! -f "$BASELINE_FILE" && -n "${PERF_HOST_TAG:-}" ]]; then
  HOST_FILE="perf-baseline.${PERF_HOST_TAG}.json"
  if [[ -f "$HOST_FILE" ]]; then
    BASELINE_FILE="$HOST_FILE"
    echo "Using host baseline: $BASELINE_FILE"
  fi
fi

BENCH_BIN="./test_perf_bench"
if [ ! -f "$BENCH_BIN" ] && [ -f "../../../build/projects/nextpas.core.test/test_perf_bench/test_perf_bench" ]; then
  BENCH_BIN="../../../build/projects/nextpas.core.test/test_perf_bench/test_perf_bench"
fi

if [ ! -f "$BENCH_BIN" ]; then
    echo "Building test_perf_bench..."
    make -j$(nproc) 2>/dev/null || {
        echo "ERROR: Failed to build test_perf_bench"
        exit 2
    }
fi

if [ ! -x "$BENCH_BIN" ]; then
  BENCH_BIN="../../../build/projects/nextpas.core.test/test_perf_bench/test_perf_bench"
fi

echo "Running benchmarks (threshold=${THRESHOLD}%, baseline=${BASELINE_FILE})..."
if [ -f "$BASELINE_FILE" ]; then
    "$BENCH_BIN" --baseline "$BASELINE_FILE" --threshold "$THRESHOLD"
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
        echo ""
        echo "FAIL: Performance regression detected (threshold: ${THRESHOLD}%)"
        echo "   Compare: $BASELINE_FILE"
        exit 1
    else
        echo ""
        echo "OK: No regression detected"
        exit 0
    fi
else
    echo "No baseline found. Generating: $BASELINE_FILE"
    "$BENCH_BIN" --save-baseline "$BASELINE_FILE"
    echo ""
    echo "OK: Baseline generated: $BASELINE_FILE"
    echo "   Optional: commit for same-host regression tracking."
    echo "   Cross-OS / wine: do not treat this number as default CI fail."
    exit 0
fi
