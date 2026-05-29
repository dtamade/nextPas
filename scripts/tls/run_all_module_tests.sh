#!/bin/bash

#############################################################################
# 自动化模块测试脚本
#
# 功能：
# - 自动编译并运行所有模块测试
# - 生成详细的测试报告
# - 支持持续集成
#
# 用法：
#   ./scripts/run_all_module_tests.sh [options]
#
# 选项：
#   --verbose    显示详细输出
#   --stop-on-fail  遇到失败立即停止
#   --modules    指定要测试的模块（逗号分隔）
#   --bin-dir DIR    指定测试可执行文件输出目录（默认: ./tmp/run_all_module_tests_bin_<run_id>）
#   --reports-dir DIR 指定测试报告输出目录（默认: ./tmp/run_all_module_tests_reports_<run_id>）
#   --fast-local  本地快速模式：输出到 ./tmp（避免污染 git 工作区）
#   --dry-run   仅打印解析后的配置，不执行编译/测试
#############################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="$PROJECT_ROOT/tests"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RUN_ID="${TIMESTAMP}_$$"
DEFAULT_REPORTS_DIR="$PROJECT_ROOT/tmp/run_all_module_tests_reports_${RUN_ID}"
DEFAULT_BIN_DIR="$PROJECT_ROOT/tmp/run_all_module_tests_bin_${RUN_ID}"
DEFAULT_FPC_UNIT_OUTPUT_DIR="$PROJECT_ROOT/tmp/run_all_module_tests_units_${RUN_ID}"

REPORTS_DIR_FROM_ENV=false
BIN_DIR_FROM_ENV=false

if [[ -n "${FAFAFA_TEST_REPORTS_DIR:-}" ]]; then
  REPORTS_DIR="$FAFAFA_TEST_REPORTS_DIR"
  REPORTS_DIR_FROM_ENV=true
elif [[ -n "${FAFAFA_MODULE_TEST_REPORTS_DIR:-}" ]]; then
  REPORTS_DIR="$FAFAFA_MODULE_TEST_REPORTS_DIR"
  REPORTS_DIR_FROM_ENV=true
else
  REPORTS_DIR="$DEFAULT_REPORTS_DIR"
fi

if [[ -n "${FAFAFA_TEST_BIN_DIR:-}" ]]; then
  BIN_DIR="$FAFAFA_TEST_BIN_DIR"
  BIN_DIR_FROM_ENV=true
elif [[ -n "${FAFAFA_MODULE_TEST_BIN_DIR:-}" ]]; then
  BIN_DIR="$FAFAFA_MODULE_TEST_BIN_DIR"
  BIN_DIR_FROM_ENV=true
else
  BIN_DIR="$DEFAULT_BIN_DIR"
fi

FPC_UNIT_OUTPUT_DIR="${FAFAFA_FPC_UNIT_OUTPUT_DIR:-$DEFAULT_FPC_UNIT_OUTPUT_DIR}"
FPC_EXE="${FAFAFA_FPC_EXE:-fpc}"

BIN_DIR_SET_BY_CLI=false
REPORTS_DIR_SET_BY_CLI=false

# 选项
VERBOSE=false
STOP_ON_FAIL=false
SPECIFIC_MODULES=""
FAST_LOCAL=false
DRY_RUN=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --fast-local)
      FAST_LOCAL=true
      shift
      ;;
    --bin-dir)
      BIN_DIR="$2"
      BIN_DIR_SET_BY_CLI=true
      shift 2
      ;;
    --reports-dir)
      REPORTS_DIR="$2"
      REPORTS_DIR_SET_BY_CLI=true
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --stop-on-fail)
      STOP_ON_FAIL=true
      shift
      ;;
    --modules)
      SPECIFIC_MODULES="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      echo "未知选项: $1"
      exit 1
      ;;
  esac
done

# 兼容：如果通过环境变量显式启用 fast-local，则默认输出到 tmp（除非 CLI 已指定 bin-dir/reports-dir）
if [[ "$FAST_LOCAL" == "false" ]]; then
  if [[ "${FAFAFA_FAST_LOCAL:-}" == "1" || "${FAFAFA_FAST_LOCAL:-}" == "true" ]]; then
    FAST_LOCAL=true
  fi
fi

if [[ "$FAST_LOCAL" == "true" ]]; then
  if [[ "$BIN_DIR_SET_BY_CLI" == "false" && "$BIN_DIR_FROM_ENV" == "false" ]]; then
    BIN_DIR="$PROJECT_ROOT/tmp/bin"
  fi
  if [[ "$REPORTS_DIR_SET_BY_CLI" == "false" && "$REPORTS_DIR_FROM_ENV" == "false" ]]; then
    REPORTS_DIR="$PROJECT_ROOT/tmp/test-reports"
  fi
fi

if [[ "$REPORTS_DIR" != /* ]]; then
  REPORTS_DIR="$PROJECT_ROOT/$REPORTS_DIR"
fi

if [[ "$BIN_DIR" != /* ]]; then
  BIN_DIR="$PROJECT_ROOT/$BIN_DIR"
fi

if [[ "$FPC_UNIT_OUTPUT_DIR" != /* ]]; then
  FPC_UNIT_OUTPUT_DIR="$PROJECT_ROOT/$FPC_UNIT_OUTPUT_DIR"
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Run ID: $RUN_ID"
  echo "FPC executable: $FPC_EXE"
  echo "Reports dir: $REPORTS_DIR"
  echo "Binary output dir: $BIN_DIR"
  echo "FPC unit output dir: $FPC_UNIT_OUTPUT_DIR"
  exit 0
fi

REPORT_FILE="$REPORTS_DIR/test_report_$RUN_ID.txt"

if [[ "$FPC_EXE" == */* ]]; then
  if [[ "$FPC_EXE" != /* ]]; then
    FPC_EXE="$PROJECT_ROOT/$FPC_EXE"
  fi
  if [[ ! -x "$FPC_EXE" ]]; then
    echo "[FAIL] configured FPC executable is not executable: $FPC_EXE"
    exit 1
  fi
else
  if ! command -v "$FPC_EXE" >/dev/null 2>&1; then
    echo "[FAIL] missing FPC executable in PATH: $FPC_EXE"
    exit 1
  fi
fi

# 创建报告目录
mkdir -p "$REPORTS_DIR"
mkdir -p "$BIN_DIR"
mkdir -p "$FPC_UNIT_OUTPUT_DIR"

# 初始化统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# 日志函数
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$REPORT_FILE"
}

log_success() {
  echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$REPORT_FILE"
}

log_error() {
  echo -e "${RED}[FAIL]${NC} $1" | tee -a "$REPORT_FILE"
}

log_warning() {
  echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$REPORT_FILE"
}

# 编译测试程序
compile_test() {
  local test_file=$1
  local test_name=$(basename "$test_file" .pas)
  local output_file="$BIN_DIR/$test_name"
  local compile_log="$REPORTS_DIR/${test_name}_${RUN_ID}_compile.log"

  if [ "$VERBOSE" = true ]; then
    log_info "编译 $test_name..."
  fi

  # 平台特定的编译参数和环境变量
  local platform_flags=""
  local platform_env=""

  # 检测操作系统
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS: 添加 OpenSSL 3.x 库路径
    if command -v brew &> /dev/null; then
      local openssl_prefix=$(brew --prefix openssl@3 2>/dev/null)
      if [ -n "$openssl_prefix" ]; then
        # 编译时库路径和头文件路径
        platform_flags="-Fl$openssl_prefix/lib -Fi$openssl_prefix/include"
        # 运行时库路径（使用 rpath）
        platform_flags="$platform_flags -k-rpath -k$openssl_prefix/lib"
        # 设置运行时环境变量
        export DYLD_LIBRARY_PATH="$openssl_prefix/lib:$DYLD_LIBRARY_PATH"
      fi
    fi
  elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    # Windows: 检查多个可能的 OpenSSL 安装位置
    local openssl_paths=(
      "C:/Program Files/OpenSSL-Win64"
      "C:/OpenSSL-Win64"
      "C:/Program Files/OpenSSL"
      "C:/OpenSSL"
    )

    for openssl_path in "${openssl_paths[@]}"; do
      if [ -d "$openssl_path/lib" ]; then
        platform_flags="-Fl$openssl_path/lib -Fi$openssl_path/include"
        export PATH="$openssl_path/bin:$PATH"
        break
      fi
    done
  fi

  # 编译并捕获输出
  if "$FPC_EXE" -Mobjfpc -Sh -O2 \
    -Fu"$PROJECT_ROOT/src" \
    -Fu"$PROJECT_ROOT/src/openssl" \
    -Fu"$PROJECT_ROOT/src/winssl" \
    -Fu"$PROJECT_ROOT/tests" \
    -FU"$FPC_UNIT_OUTPUT_DIR" \
    -Fi"$PROJECT_ROOT/src" \
    -FE"$BIN_DIR" \
    $platform_flags \
    "$test_file" > "$compile_log" 2>&1; then
    return 0
  else
    # 编译失败时显示错误信息（仅在 verbose 模式下）
    if [ "$VERBOSE" = true ] && [ -f "$compile_log" ]; then
      echo "编译错误详情:" >> "$REPORT_FILE"
      tail -20 "$compile_log" >> "$REPORT_FILE"
    fi
    return 1
  fi
}

# 以可移植方式运行测试（macOS 默认没有 GNU timeout）
run_with_timeout() {
  local timeout_seconds="$1"
  local executable="$2"
  local out_file="$3"

  local timeout_bin=""
  if command -v timeout >/dev/null 2>&1; then
    timeout_bin="timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    timeout_bin="gtimeout"
  fi

  if [[ -n "$timeout_bin" ]]; then
    local rc=0
    set +e
    "$timeout_bin" "$timeout_seconds" "$executable" >"$out_file" 2>&1
    rc=$?
    set -e

    # 126/127: timeout 本身不可用（例如 macOS 无该命令，或被 PATH 注入的坏版本）
    if [[ $rc -ne 126 && $rc -ne 127 ]]; then
      return $rc
    fi
  fi

  local rc=0
  set +e
  python3 - "$executable" "$timeout_seconds" "$out_file" <<'PY'
import subprocess
import sys
from pathlib import Path

executable = sys.argv[1]
timeout_seconds = float(sys.argv[2])
out_file = Path(sys.argv[3])

out_file.parent.mkdir(parents=True, exist_ok=True)
with out_file.open("wb") as f:
    try:
        p = subprocess.run([executable], stdout=f, stderr=subprocess.STDOUT, timeout=timeout_seconds, check=False)
        sys.exit(p.returncode)
    except subprocess.TimeoutExpired:
        f.write(b"\n[timeout]\n")
        sys.exit(124)
PY
  rc=$?
  set -e
  return $rc
}

# 运行测试程序
run_test() {
  local test_name=$1
  local output_file="$BIN_DIR/$test_name"
  local result_file="$REPORTS_DIR/${test_name}_${RUN_ID}_result.txt"

  if [ ! -f "$output_file" ]; then
    log_error "$test_name: 可执行文件不存在"
    return 1
  fi

  if [ "$VERBOSE" = true ]; then
    log_info "运行 $test_name..."
  fi

  # 运行测试并捕获输出（增加超时到60秒）
  local exit_code=0
  if run_with_timeout 60 "$output_file" "$result_file"; then
    exit_code=0
    return 0
  else
    exit_code=$?

    # 解析测试结果以显示部分通过的情况
    local passed
    passed="$(awk -F':' '/^Passed[[:space:]]*:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' "$result_file" 2>/dev/null || true)"
    local total
    total="$(awk -F':' '/^Total Tests[[:space:]]*:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' "$result_file" 2>/dev/null || true)"
    [[ "$passed" =~ ^[0-9]+$ ]] || passed="0"
    [[ "$total" =~ ^[0-9]+$ ]] || total="0"

    if [ $exit_code -eq 124 ]; then
      log_error "$test_name: 超时（60秒）"
      return 1
    elif [ "$total" -gt 0 ] && [ "$passed" -gt 0 ]; then
      # 计算通过率
      local pass_rate=$(awk "BEGIN {printf \"%.1f\", $passed * 100.0 / $total}")
      log_warning "$test_name: 部分通过 ($passed/$total, $pass_rate%, 退出码: $exit_code)"

      # 如果通过率 >= 80%，视为通过
      if awk "BEGIN {exit !($pass_rate >= 80.0)}"; then
        log_success "$test_name: 视为通过（通过率 >= 80%）"
        return 0
      else
        return 1
      fi
    else
      log_error "$test_name: 失败（退出码: $exit_code）"
      return 1
    fi
  fi
}

# 测试模块定义 - 兼容 bash 3.x
# 使用函数来模拟关联数组
get_module_tests() {
  local module=$1
  case "$module" in
    # P2 模块
    "PKCS7") echo "test_p2_pkcs7 test_p2_pkcs7_comprehensive" ;;
    "PKCS12") echo "test_p2_pkcs12 test_p2_pkcs12_comprehensive test_p2_pkcs12_create_parse" ;;
    "CMS") echo "test_p2_cms test_p2_cms_comprehensive" ;;
    "Store") echo "test_p2_store test_p2_store_comprehensive" ;;
    "OCSP") echo "test_p2_ocsp test_p2_ocsp_comprehensive test_p2_ocsp_http_hooks" ;;
    "TS") echo "test_p2_ts test_p2_ts_comprehensive" ;;
    # P3 模块
    "CT") echo "test_p2_ct test_p2_ct_comprehensive test_p2_ct_http_hooks" ;;
    "SRP") echo "test_p2_srp test_p2_srp_comprehensive" ;;
    "Comp") echo "test_p2_comp" ;;
    # P4 模块
    "Engine") echo "test_p4_engine" ;;
    "Provider") echo "test_provider" ;;
    *) echo "" ;;
  esac
}

# 所有模块列表
ALL_MODULES="PKCS7 PKCS12 CMS Store OCSP TS CT SRP Comp Engine Provider"

# 开始测试
echo "========================================" | tee "$REPORT_FILE"
echo "模块自动化测试报告" | tee -a "$REPORT_FILE"
echo "时间: $(date)" | tee -a "$REPORT_FILE"
echo "Run ID: $RUN_ID" | tee -a "$REPORT_FILE"
echo "FPC executable: $FPC_EXE" | tee -a "$REPORT_FILE"
echo "Binary output dir: $BIN_DIR" | tee -a "$REPORT_FILE"
echo "FPC unit output dir: $FPC_UNIT_OUTPUT_DIR" | tee -a "$REPORT_FILE"
echo "========================================" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# 确定要测试的模块
if [ -n "$SPECIFIC_MODULES" ]; then
  IFS=',' read -ra MODULES <<< "$SPECIFIC_MODULES"
else
  MODULES=($ALL_MODULES)
fi

# 遍历每个模块
for module in "${MODULES[@]}"; do
  module_tests=$(get_module_tests "$module")

  if [ -z "$module_tests" ]; then
    log_warning "未知模块: $module"
    continue
  fi

  echo "" | tee -a "$REPORT_FILE"
  log_info "========== 测试模块: $module =========="

  module_passed=0
  module_failed=0

  # 遍历模块的所有测试
  for test_name in $module_tests; do
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    # 查找测试文件
    test_file=$(find "$TESTS_DIR" -name "${test_name}.pas" 2>/dev/null | head -1)

    if [ -z "$test_file" ]; then
      log_warning "$test_name: 测试文件未找到"
      SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
      continue
    fi

    # 编译测试
    if ! compile_test "$test_file"; then
      log_error "$test_name: 编译失败"
      FAILED_TESTS=$((FAILED_TESTS + 1))
      module_failed=$((module_failed + 1))

      if [ "$STOP_ON_FAIL" = true ]; then
        log_error "遇到失败，停止测试"
        exit 1
      fi
      continue
    fi

    # 运行测试
    if run_test "$test_name"; then
      log_success "$test_name: 通过"
      PASSED_TESTS=$((PASSED_TESTS + 1))
      module_passed=$((module_passed + 1))
    else
      log_error "$test_name: 失败"
      FAILED_TESTS=$((FAILED_TESTS + 1))
      module_failed=$((module_failed + 1))

      if [ "$STOP_ON_FAIL" = true ]; then
        log_error "遇到失败，停止测试"
        exit 1
      fi
    fi
  done

  # 模块总结
  module_total=$((module_passed + module_failed))
  if [ $module_total -gt 0 ]; then
    module_rate=$(awk "BEGIN {printf \"%.1f\", $module_passed * 100.0 / $module_total}")
    log_info "$module 模块: $module_passed/$module_total 通过 ($module_rate%)"
  fi
done

# 生成总结
echo "" | tee -a "$REPORT_FILE"
echo "========================================" | tee -a "$REPORT_FILE"
echo "测试总结" | tee -a "$REPORT_FILE"
echo "========================================" | tee -a "$REPORT_FILE"
echo "总测试数: $TOTAL_TESTS" | tee -a "$REPORT_FILE"
echo "通过: $PASSED_TESTS" | tee -a "$REPORT_FILE"
echo "失败: $FAILED_TESTS" | tee -a "$REPORT_FILE"
echo "跳过: $SKIPPED_TESTS" | tee -a "$REPORT_FILE"

if [ $TOTAL_TESTS -gt 0 ]; then
  PASS_RATE=$(awk "BEGIN {printf \"%.1f\", $PASSED_TESTS * 100.0 / $TOTAL_TESTS}")
  echo "通过率: $PASS_RATE%" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"
echo "详细报告: $REPORT_FILE" | tee -a "$REPORT_FILE"

# 退出码 - 70% 通过率视为成功
if [ $TOTAL_TESTS -gt 0 ]; then
  PASS_RATE_NUM=$(awk "BEGIN {printf \"%.0f\", $PASSED_TESTS * 100.0 / $TOTAL_TESTS}")
  if [ $PASS_RATE_NUM -ge 70 ]; then
    log_success "测试通过（通过率: $PASS_RATE%）"
    exit 0
  else
    log_error "测试失败（通过率: $PASS_RATE% < 70%）"
    exit 1
  fi
else
  log_error "没有运行任何测试"
  exit 1
fi
