#!/bin/bash
# perf-regression-check.sh — 性能回归检测
#
# 用法:
#   ./perf-regression-check.sh [threshold_percent]
#
# 参数:
#   threshold_percent — 回归阈值（默认 30%，宽松防 flaky；对标 benchstat 式门禁）
#
# 工作流程:
#   1. 运行 test_perf_bench --bench --baseline <file>
#   2. 对比基线，超过阈值则 exit 1
#
# 在 CI 中使用:
#   - 首次运行生成基线: ./perf-regression-check.sh
#   - 后续运行对比: ./perf-regression-check.sh 30
#   - make -C core/tests/nextpas.core.test/test_perf_bench regression

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

THRESHOLD=${1:-30}
BASELINE_FILE="perf-baseline.json"
BENCH_BIN="./test_perf_bench"
if [ ! -f "$BENCH_BIN" ] && [ -f "../../../build/projects/nextpas.core.test/test_perf_bench/test_perf_bench" ]; then
  BENCH_BIN="../../../build/projects/nextpas.core.test/test_perf_bench/test_perf_bench"
fi

# 检查二进制存在
if [ ! -f "$BENCH_BIN" ]; then
    echo "Building test_perf_bench..."
    make -j$(nproc) 2>/dev/null || {
        echo "ERROR: Failed to build test_perf_bench"
        exit 2
    }
fi

# Resolve binary after build
if [ ! -x "$BENCH_BIN" ]; then
  BENCH_BIN="../../../build/projects/nextpas.core.test/test_perf_bench/test_perf_bench"
fi

echo "Running benchmarks (threshold=${THRESHOLD}%)..."
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
    echo "   Commit this file to track regressions (optional)."
    exit 0
fi
