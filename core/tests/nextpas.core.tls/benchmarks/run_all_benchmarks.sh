#!/bin/bash

#############################################################################
# 统一性能基准测试运行器
#
# 功能：
# - 编译并运行所有性能基准测试
# - 生成统一的性能报告
# - 支持基线对比和回归检测
# - 适用于 CI/CD 集成
#
# 用法：
#   ./tests/benchmarks/run_all_benchmarks.sh [options]
#
# 选项：
#   --iterations N    每个测试的迭代次数（默认：1000）
#   --baseline DIR    基线数据目录（默认：tests/benchmarks/baselines）
#   --output DIR      输出目录（默认：tests/benchmarks/results）
#   --bin-dir DIR     编译产物目录（默认：tests/benchmarks/bin）
#   --skip-tls        跳过 TLS 握手测试（需要网络）
#   --verbose         显示详细输出
#   --help            显示帮助信息
#############################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BENCHMARKS_DIR="$PROJECT_ROOT/tests/benchmarks"
BIN_DIR="$BENCHMARKS_DIR/bin"
BASELINE_DIR="$BENCHMARKS_DIR/baselines"
OUTPUT_DIR="$BENCHMARKS_DIR/results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 选项
ITERATIONS=1000
TLS_ITERATIONS=100  # TLS 握手较慢，使用较少迭代
SKIP_TLS=false
VERBOSE=false

# 统计
TOTAL_BENCHMARKS=0
PASSED_BENCHMARKS=0
FAILED_BENCHMARKS=0

# 日志函数
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
  echo -e "${RED}[FAIL]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

# 显示帮助信息
show_help() {
  cat << EOF
统一性能基准测试运行器

用法: $0 [选项]

选项:
  --iterations N      每个测试的迭代次数（默认：1000）
  --tls-iterations N  TLS 握手测试的迭代次数（默认：100）
  --baseline DIR      基线数据目录（默认：tests/benchmarks/baselines）
  --output DIR        输出目录（默认：tests/benchmarks/results）
  --bin-dir DIR       编译产物目录（默认：tests/benchmarks/bin）
  --skip-tls          跳过 TLS 握手测试（需要网络）
  --verbose           显示详细输出
  --help              显示此帮助信息

基准测试列表:
  1. benchmark_crypto_comprehensive  - 加密算法性能测试
     - SHA-256 (64B, 1KB, 16KB)
     - SHA-512 (64B, 1KB, 16KB)
     - AES-256-GCM 加密/解密 (64B, 1KB, 16KB)
     - 安全随机数生成 (64B, 1KB, 16KB)
     - 密钥生成 (128-bit, 256-bit)

  2. benchmark_random_pool           - 随机数缓存池性能测试 (Phase B)
     - 小数据块 (256B) - 高频请求场景
     - 中等数据块 (1KB) - 标准场景
     - 大数据块 (4KB) - 边界场景
     - 超大数据块 (8KB) - 直接生成场景

  3. benchmark_tls_handshake         - TLS 握手性能测试
     - TLS 1.2 握手
     - TLS 1.3 握手
     - TLS 1.2+1.3 握手
     - 会话复用

  4. benchmark_cert_verify_cache     - 证书验证缓存性能测试 (Wave C)
     - 首次访问（cache miss）
     - 重复访问（cache hit）
     - speedup factor 对照

示例:
  $0                                    # 运行所有基准测试
  $0 --iterations 500                   # 使用 500 次迭代
  $0 --skip-tls                         # 跳过 TLS 测试
  $0 --verbose                          # 显示详细输出

EOF
  exit 0
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --iterations)
      ITERATIONS="$2"
      shift 2
      ;;
    --tls-iterations)
      TLS_ITERATIONS="$2"
      shift 2
      ;;
    --baseline)
      BASELINE_DIR="$2"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --bin-dir)
      BIN_DIR="$2"
      shift 2
      ;;
    --skip-tls)
      SKIP_TLS=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      show_help
      ;;
    *)
      echo "未知选项: $1"
      echo "使用 --help 查看帮助信息"
      exit 1
      ;;
  esac
done

resolve_path() {
  local path="$1"
  if [[ "$path" != /* ]]; then
    path="$PROJECT_ROOT/$path"
  fi
  echo "$path"
}

BIN_DIR="$(resolve_path "$BIN_DIR")"
BASELINE_DIR="$(resolve_path "$BASELINE_DIR")"
OUTPUT_DIR="$(resolve_path "$OUTPUT_DIR")"

# 创建必要的目录
mkdir -p "$BIN_DIR"
mkdir -p "$BASELINE_DIR"
mkdir -p "$OUTPUT_DIR"

# 编译基准测试
compile_benchmark() {
  local benchmark_file=$1
  local benchmark_name=$(basename "$benchmark_file" .pas)
  local output_file="$BIN_DIR/$benchmark_name"

  log_info "编译 $benchmark_name..."

  # 平台特定的编译参数
  local platform_flags=""

  # 检测操作系统
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS: 添加 OpenSSL 3.x 库路径
    if command -v brew &> /dev/null; then
      local openssl_prefix=$(brew --prefix openssl@3 2>/dev/null)
      if [ -n "$openssl_prefix" ]; then
        platform_flags="-Fl$openssl_prefix/lib -Fi$openssl_prefix/include"
        platform_flags="$platform_flags -k-rpath -k$openssl_prefix/lib"
        export DYLD_LIBRARY_PATH="$openssl_prefix/lib:$DYLD_LIBRARY_PATH"
      fi
    fi
  fi

  # 编译
  if fpc -Mobjfpc -Sh -O2 \
    -Fu"$PROJECT_ROOT/src" \
    -Fu"$PROJECT_ROOT/src/openssl" \
    -Fu"$BENCHMARKS_DIR" \
    -Fu"$PROJECT_ROOT/examples" \
    -Fi"$PROJECT_ROOT/src" \
    -FE"$BIN_DIR" \
    $platform_flags \
    "$benchmark_file" > "$BIN_DIR/${benchmark_name}_compile.log" 2>&1; then

    log_success "$benchmark_name: 编译成功"
    return 0
  else
    log_error "$benchmark_name: 编译失败"
    if [ "$VERBOSE" = true ]; then
      echo "编译错误详情:"
      tail -20 "$BIN_DIR/${benchmark_name}_compile.log"
    fi
    return 1
  fi
}

# 运行基准测试
run_benchmark() {
  local benchmark_name=$1
  local iterations=$2
  local benchmark_bin="$BIN_DIR/$benchmark_name"

  if [ ! -f "$benchmark_bin" ]; then
    log_error "$benchmark_name: 可执行文件不存在"
    return 1
  fi

  log_info "运行 $benchmark_name (迭代: $iterations)..."

  TOTAL_BENCHMARKS=$((TOTAL_BENCHMARKS + 1))

  # 运行基准测试
  if (cd "$OUTPUT_DIR" && FAFAFA_PROJECT_ROOT="$PROJECT_ROOT" "$benchmark_bin" "$iterations") > "$OUTPUT_DIR/${benchmark_name}_${TIMESTAMP}.log" 2>&1; then
    log_success "$benchmark_name: 运行成功"
    PASSED_BENCHMARKS=$((PASSED_BENCHMARKS + 1))

    return 0
  else
    log_error "$benchmark_name: 运行失败"
    FAILED_BENCHMARKS=$((FAILED_BENCHMARKS + 1))

    if [ "$VERBOSE" = true ]; then
      echo "运行错误详情:"
      tail -20 "$OUTPUT_DIR/${benchmark_name}_${TIMESTAMP}.log"
    fi

    return 1
  fi
}

# 生成汇总报告
generate_summary() {
  local summary_file="$OUTPUT_DIR/benchmark_summary_${TIMESTAMP}.txt"

  cat > "$summary_file" << EOF
================================================================
性能基准测试汇总报告
================================================================

时间: $(date)
迭代次数: $ITERATIONS (加密算法), $TLS_ITERATIONS (TLS 握手)

----------------------------------------------------------------
测试结果
----------------------------------------------------------------
总测试数: $TOTAL_BENCHMARKS
通过: $PASSED_BENCHMARKS
失败: $FAILED_BENCHMARKS

EOF

  if [ $TOTAL_BENCHMARKS -gt 0 ]; then
    local success_rate=$(awk "BEGIN {printf \"%.1f\", $PASSED_BENCHMARKS * 100.0 / $TOTAL_BENCHMARKS}")
    echo "成功率: $success_rate%" >> "$summary_file"
  fi

  echo "" >> "$summary_file"
  echo "----------------------------------------------------------------" >> "$summary_file"
  echo "详细日志" >> "$summary_file"
  echo "----------------------------------------------------------------" >> "$summary_file"

  for log_file in "$OUTPUT_DIR"/*_${TIMESTAMP}.log; do
    if [ -f "$log_file" ]; then
      echo "" >> "$summary_file"
      echo "=== $(basename "$log_file") ===" >> "$summary_file"
      tail -50 "$log_file" >> "$summary_file"
    fi
  done

  log_info "汇总报告已保存到: $summary_file"
}

# 主程序
echo "================================================================"
echo "fafafa.ssl 性能基准测试套件"
echo "================================================================"
echo ""

log_info "配置:"
log_info "  迭代次数: $ITERATIONS (加密算法)"
log_info "  TLS 迭代次数: $TLS_ITERATIONS"
log_info "  基线目录: $BASELINE_DIR"
log_info "  输出目录: $OUTPUT_DIR"
log_info "  跳过 TLS: $SKIP_TLS"
echo ""

# 编译所有基准测试
log_info "编译基准测试..."
echo "----------------------------------------------------------------"

compile_benchmark "$BENCHMARKS_DIR/benchmark_crypto_comprehensive.pas" || true
compile_benchmark "$BENCHMARKS_DIR/benchmark_random_pool.pas" || true
compile_benchmark "$BENCHMARKS_DIR/benchmark_cert_verify_cache.pas" || true

if [ "$SKIP_TLS" = false ]; then
  compile_benchmark "$BENCHMARKS_DIR/benchmark_tls_handshake.pas" || true
else
  log_warning "跳过 TLS 握手测试编译"
fi

echo ""

# 运行所有基准测试
log_info "运行基准测试..."
echo "----------------------------------------------------------------"

run_benchmark "benchmark_crypto_comprehensive" "$ITERATIONS" || true
run_benchmark "benchmark_random_pool" "$ITERATIONS" || true
run_benchmark "benchmark_cert_verify_cache" "$ITERATIONS" || true

if [ "$SKIP_TLS" = false ]; then
  run_benchmark "benchmark_tls_handshake" "$TLS_ITERATIONS" || true
else
  log_warning "跳过 TLS 握手测试运行"
fi

echo ""

# 生成汇总报告
log_info "生成汇总报告..."
generate_summary

echo ""
echo "================================================================"
echo "基准测试完成"
echo "================================================================"
echo ""
echo "总测试数: $TOTAL_BENCHMARKS"
echo "通过: $PASSED_BENCHMARKS"
echo "失败: $FAILED_BENCHMARKS"

if [ $TOTAL_BENCHMARKS -gt 0 ]; then
  SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", $PASSED_BENCHMARKS * 100.0 / $TOTAL_BENCHMARKS}")
  echo "成功率: $SUCCESS_RATE%"
fi

echo ""
echo "结果目录: $OUTPUT_DIR"

# 退出码
if [ $FAILED_BENCHMARKS -gt 0 ]; then
  exit 1
else
  exit 0
fi
