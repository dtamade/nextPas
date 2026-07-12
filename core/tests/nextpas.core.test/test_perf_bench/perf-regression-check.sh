#!/bin/bash
# perf-regression-check.sh — 性能回归检测
#
# 用法:
#   ./perf-regression-check.sh [threshold_percent]
#
# 参数:
#   threshold_percent — 回归阈值（默认 20%）
#
# 工作流程:
#   1. 运行 test_perf_bench --bench --baseline <file>
#   2. 对比基线，超过阈值则 exit 1
#
# 在 CI 中使用:
#   - 首次运行生成基线: ./perf-regression-check.sh
#   - 后续运行对比: ./perf-regression-check.sh 20

set -euo pipefail

THRESHOLD=${1:-20}
BASELINE_FILE="perf-baseline.json"
BENCH_BIN="./test_perf_bench"

# 检查二进制存在
if [ ! -f "$BENCH_BIN" ]; then
    echo "Building test_perf_bench..."
    make -j$(nproc) 2>/dev/null || {
        echo "ERROR: Failed to build test_perf_bench"
        exit 2
    }
fi

# 运行基准测试
echo "Running benchmarks..."
if [ -f "$BASELINE_FILE" ]; then
    # 对比模式
    $BENCH_BIN --bench --baseline "$BASELINE_FILE" --threshold "$THRESHOLD"
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
        echo ""
        echo "❌ Performance regression detected (threshold: ${THRESHOLD}%)"
        echo "   Compare: $BASELINE_FILE"
        exit 1
    else
        echo ""
        echo "✅ No regression detected"
        exit 0
    fi
else
    # 生成基线模式
    echo "No baseline found. Generating: $BASELINE_FILE"
    $BENCH_BIN --bench --save-baseline "$BASELINE_FILE"
    echo ""
    echo "✅ Baseline generated: $BASELINE_FILE"
    echo "   Commit this file to track regressions."
    exit 0
fi
