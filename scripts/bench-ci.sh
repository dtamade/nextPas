#!/bin/bash
# nextpas.core.bench CI 脚本
# 用于自动化基准测试回归检测

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BENCH_DIR="$PROJECT_ROOT/core/tests/nextpas.core.bench"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_dependencies() {
    if ! command -v fpc &> /dev/null; then
        log_error "Free Pascal Compiler not found"
        exit 1
    fi

    if ! command -v make &> /dev/null; then
        log_error "make not found"
        exit 1
    fi
}

# 运行基准测试
run_benchmarks() {
    log_info "Running benchmark tests..."
    cd "$BENCH_DIR"

    if make test; then
        log_info "All benchmark tests passed"
    else
        log_error "Benchmark tests failed"
        exit 1
    fi
}

# 生成基线
generate_baseline() {
    local baseline_file="${1:-bench-baseline.json}"
    log_info "Generating baseline: $baseline_file"

    cd "$PROJECT_ROOT"

    # 运行基准测试并保存结果
    fpc -MObjFPC -Fu core/src core/examples/bench/ci_integration.pas -o /tmp/ci_integration
    /tmp/ci_integration --generate-baseline "$baseline_file"

    log_info "Baseline saved to $baseline_file"
}

# 比较基线
compare_baseline() {
    local baseline_file="${1:-bench-baseline.json}"
    local report_file="${2:-bench-ci-report.json}"

    if [ ! -f "$baseline_file" ]; then
        log_warn "Baseline file not found: $baseline_file"
        log_info "Generating new baseline..."
        generate_baseline "$baseline_file"
    fi

    log_info "Comparing with baseline: $baseline_file"

    cd "$PROJECT_ROOT"

    # 运行基准测试并比较
    fpc -MObjFPC -Fu core/src core/examples/bench/ci_integration.pas -o /tmp/ci_integration
    /tmp/ci_integration "$baseline_file" "$report_file"

    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        log_info "No performance regression detected"
    else
        log_error "Performance regression detected!"
        log_error "Check $report_file for details"
    fi

    return $exit_code
}

# 清理构建产物
clean() {
    log_info "Cleaning build artifacts..."
    cd "$BENCH_DIR"
    make clean
    log_info "Clean complete"
}

# 显示帮助
show_help() {
    cat << EOF
nextpas.core.bench CI 脚本

用法: $0 [命令] [选项]

命令:
    test                运行所有基准测试
    baseline [FILE]     生成基线文件 (默认: bench-baseline.json)
    compare [FILE]      与基线比较 (默认: bench-baseline.json)
    clean               清理构建产物
    help                显示帮助

示例:
    $0 test                    # 运行所有测试
    $0 baseline                # 生成基线
    $0 baseline my-baseline.json  # 生成自定义基线
    $0 compare                 # 与默认基线比较
    $0 compare my-baseline.json   # 与自定义基线比较

环境变量:
    BENCH_THRESHOLD     回归检测阈值 (默认: 5%)
    BENCH_MIN_SAMPLES   最小采样数 (默认: 30)
    BENCH_MIN_DURATION  最小持续时间 (默认: 2s)

EOF
}

# 主函数
main() {
    check_dependencies

    case "${1:-help}" in
        test)
            run_benchmarks
            ;;
        baseline)
            generate_baseline "${2:-bench-baseline.json}"
            ;;
        compare)
            compare_baseline "${2:-bench-baseline.json}" "${3:-bench-ci-report.json}"
            ;;
        clean)
            clean
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
