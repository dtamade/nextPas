#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BENCH_RUNNER="$PROJECT_ROOT/tests/benchmarks/run_all_benchmarks.sh"
RUN_ID="${FAFAFA_PHASE2_BASELINE_RUN_ID:-$(date +%Y%m%d_%H%M%S)_$$}"
DEFAULT_OUTPUT_DIR="$PROJECT_ROOT/tests/benchmarks/results"
DEFAULT_BENCH_BIN_DIR="$PROJECT_ROOT/tests/benchmarks/bin"
DEFAULT_DOC_REPORT_DIR="$PROJECT_ROOT/docs/test_reports"

OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
BENCH_BIN_DIR="$DEFAULT_BENCH_BIN_DIR"
DOC_REPORT_DIR="$DEFAULT_DOC_REPORT_DIR"

ITERATIONS=500
TLS_ITERATIONS=100
SKIP_TLS=true
VERBOSE=false
DRY_RUN=false
FAST_LOCAL=false

OUTPUT_DIR_SET_BY_CLI=false
BENCH_BIN_DIR_SET_BY_CLI=false
DOC_REPORT_DIR_SET_BY_CLI=false

usage() {
  cat <<'USAGE'
Phase 2 基准采集脚本（草案）

用途：
  - 统一触发 tests/benchmarks/run_all_benchmarks.sh
  - 生成一次带时间戳的 Phase 2 基准草案报告
  - 为后续 B6（首轮基线采集）提供稳定入口

用法：
  scripts/run_phase2_performance_baseline.sh [options]

选项：
  --run-id ID          指定 run_id（默认: 时间戳 + pid）
  --iterations N      加密/随机类基准迭代次数（默认: 500）
  --tls-iterations N  TLS 握手基准迭代次数（默认: 100）
  --output DIR        基准输出目录（默认: tests/benchmarks/results）
  --bin-dir DIR       benchmark 编译产物目录（默认: tests/benchmarks/bin）
  --doc-reports-dir DIR 草案报告输出目录（默认: docs/test_reports）
  --fast-local        本地快速模式：输出到 ./tmp（避免污染 git 工作区）
  --skip-tls          跳过 TLS 基准（默认开启）
  --with-tls          运行 TLS 基准（需要网络/本地 TLS 端点）
  --verbose           输出详细日志
  --dry-run           仅打印将执行的命令，不实际运行
  --help              显示帮助
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="$2"
      shift 2
      ;;
    --iterations)
      ITERATIONS="$2"
      shift 2
      ;;
    --tls-iterations)
      TLS_ITERATIONS="$2"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="$2"
      OUTPUT_DIR_SET_BY_CLI=true
      shift 2
      ;;
    --bin-dir)
      BENCH_BIN_DIR="$2"
      BENCH_BIN_DIR_SET_BY_CLI=true
      shift 2
      ;;
    --doc-reports-dir)
      DOC_REPORT_DIR="$2"
      DOC_REPORT_DIR_SET_BY_CLI=true
      shift 2
      ;;
    --fast-local)
      FAST_LOCAL=true
      shift
      ;;
    --skip-tls)
      SKIP_TLS=true
      shift
      ;;
    --with-tls)
      SKIP_TLS=false
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "$BENCH_RUNNER" ]]; then
  echo "[FAIL] benchmark runner not found: $BENCH_RUNNER" >&2
  exit 1
fi

if [[ "$FAST_LOCAL" == "false" ]]; then
  if [[ "${FAFAFA_FAST_LOCAL:-}" == "1" || "${FAFAFA_FAST_LOCAL:-}" == "true" ]]; then
    FAST_LOCAL=true
  fi
fi

if [[ ! "$RUN_ID" =~ ^[0-9A-Za-z_.-]+$ ]]; then
  echo "[FAIL] invalid --run-id: $RUN_ID (allowed: [0-9A-Za-z_.-])" >&2
  exit 1
fi

if [[ "$FAST_LOCAL" == "true" ]]; then
  if [[ "$OUTPUT_DIR_SET_BY_CLI" == "false" ]]; then
    OUTPUT_DIR="$PROJECT_ROOT/tmp/phase2_bench_results_${RUN_ID}"
  fi
  if [[ "$BENCH_BIN_DIR_SET_BY_CLI" == "false" ]]; then
    BENCH_BIN_DIR="$PROJECT_ROOT/tmp/phase2_bench_bin_${RUN_ID}"
  fi
  if [[ "$DOC_REPORT_DIR_SET_BY_CLI" == "false" ]]; then
    DOC_REPORT_DIR="$PROJECT_ROOT/tmp/test-reports"
  fi
fi

resolve_under_project_root() {
  local path="$1"
  if [[ "$path" != /* ]]; then
    path="$PROJECT_ROOT/$path"
  fi
  if [[ "$path" != "$PROJECT_ROOT"/* ]]; then
    echo "[FAIL] refusing to write outside project root: $path" >&2
    exit 1
  fi
  echo "$path"
}

OUTPUT_DIR="$(resolve_under_project_root "$OUTPUT_DIR")"
BENCH_BIN_DIR="$(resolve_under_project_root "$BENCH_BIN_DIR")"
DOC_REPORT_DIR="$(resolve_under_project_root "$DOC_REPORT_DIR")"

CMD=(bash "$BENCH_RUNNER" --iterations "$ITERATIONS" --tls-iterations "$TLS_ITERATIONS" --output "$OUTPUT_DIR" --bin-dir "$BENCH_BIN_DIR")
if [[ "$SKIP_TLS" == "true" ]]; then
  CMD+=(--skip-tls)
fi
if [[ "$VERBOSE" == "true" ]]; then
  CMD+=(--verbose)
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[INFO] run_id: $RUN_ID"
  echo "[INFO] bench_runner: $BENCH_RUNNER"
  echo "[INFO] bench_output_dir: $OUTPUT_DIR"
  echo "[INFO] bench_bin_dir: $BENCH_BIN_DIR"
  echo "[INFO] doc_reports_dir: $DOC_REPORT_DIR"
  echo "[INFO] phase2_baseline_command: ${CMD[*]}"
  echo "[INFO] dry-run enabled, command not executed"
  exit 0
fi

mkdir -p "$OUTPUT_DIR" "$DOC_REPORT_DIR"

(cd "$OUTPUT_DIR" && "${CMD[@]}")

LATEST_SUMMARY=$(ls -t "$OUTPUT_DIR"/benchmark_summary_*.txt 2>/dev/null | head -1 || true)
if [[ -z "$LATEST_SUMMARY" ]]; then
  echo "[FAIL] benchmark summary not found in $OUTPUT_DIR" >&2
  exit 1
fi

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
REPORT_FILE="$DOC_REPORT_DIR/PHASE2_BASELINE_DRAFT_${TIMESTAMP}.md"

OS_INFO="$(uname -srvmo 2>/dev/null || echo unknown)"
FPC_INFO="$(fpc -iV 2>/dev/null || echo unknown)"
OPENSSL_INFO="$(openssl version 2>/dev/null || echo unknown)"

cat > "$REPORT_FILE" <<EOF_REPORT
# Phase 2 性能基线草案报告（自动生成）

- 生成时间：$(date '+%Y-%m-%d %H:%M:%S %z')
- 系统：$OS_INFO
- FPC：$FPC_INFO
- OpenSSL：$OPENSSL_INFO

## 执行命令

\`\`\`bash
${CMD[*]}
\`\`\`

## 输出文件

- 汇总报告：\`$LATEST_SUMMARY\`
- 指标模板：\`docs/test_reports/PHASE2_PERFORMANCE_METRICS_TEMPLATE.md\`

## 汇总尾部（最近 80 行）

\`\`\`text
$(tail -n 80 "$LATEST_SUMMARY")
\`\`\`

## 下一步（B6）

1. 按模板填写关键指标（吞吐、延迟、回归阈值）。
2. 固化本次结果为基线，并补充对比说明。
3. 将结果同步到 docs/plans/ 与 task_plan.md。
EOF_REPORT

echo "[PASS] Phase 2 baseline draft report generated: $REPORT_FILE"
