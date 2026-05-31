#!/bin/bash
# verify_examples_compile.sh
# B70: 示例编译验证脚本
# 验证 examples/ 目录下所有 .pas 文件能否通过编译

# 不使用 set -e，因为编译失败是预期的情况

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXAMPLES_DIR="$PROJECT_ROOT/examples"
SRC_DIR="$PROJECT_ROOT/src"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 参数
VERBOSE=false
STOP_ON_ERROR=false
OUTPUT_FORMAT="text"
REPORT_FILE=""
MACHINE_STDOUT_MODE=false

# 帮助信息
show_help() {
    cat << 'EOF_HELP'
用法: verify_examples_compile.sh [选项]

选项:
  -v, --verbose         显示详细编译输出
  -s, --stop-on-error   遇到第一个错误时停止
  -f, --format FORMAT   输出格式: text (默认), json, markdown
  -o, --output FILE     输出报告到文件
  -h, --help            显示此帮助信息

示例:
  ./verify_examples_compile.sh              # 编译所有示例
  ./verify_examples_compile.sh -v           # 详细模式
  ./verify_examples_compile.sh -f markdown  # Markdown 格式输出
EOF_HELP
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose) VERBOSE=true; shift ;;
        -s|--stop-on-error) STOP_ON_ERROR=true; shift ;;
        -f|--format) OUTPUT_FORMAT="$2"; shift 2 ;;
        -o|--output) REPORT_FILE="$2"; shift 2 ;;
        -h|--help) show_help; exit 0 ;;
        *) echo -e "${RED}错误: 未知选项 $1${NC}"; exit 2 ;;
    esac
done

case "$OUTPUT_FORMAT" in
    text|json|markdown) ;;
    *)
        echo -e "${RED}错误: 不支持的输出格式: $OUTPUT_FORMAT (允许: text, json, markdown)${NC}" >&2
        exit 2
        ;;
esac

if [[ -z "$REPORT_FILE" && "$OUTPUT_FORMAT" != "text" ]]; then
    MACHINE_STDOUT_MODE=true
fi

emit_runtime_line() {
    if $MACHINE_STDOUT_MODE; then
        printf '%b\n' "$1" >&2
    else
        printf '%b\n' "$1"
    fi
}

# 检查 FPC
if ! command -v fpc &> /dev/null; then
    echo -e "${RED}错误: 未找到 fpc 编译器${NC}"
    exit 2
fi

FPC_VERSION=$(fpc -iV 2>/dev/null || echo "unknown")
emit_runtime_line "FPC 版本: $FPC_VERSION"
emit_runtime_line "项目根目录: $PROJECT_ROOT"
emit_runtime_line ""

# 统计
TOTAL=0
TESTED=0
PASSED=0
FAILED=0
SKIPPED=0
REMAINING=0
STOPPED_EARLY=false
declare -a EXAMPLE_FILES
declare -a FAILED_FILES
declare -a SKIPPED_FILES

# 检查是否跳过（WinSSL 示例在非 Windows 下跳过）
should_skip() {
    local basename
    basename=$(basename "$1")
    case "$basename" in
        winssl_*|*_winssl_*|09_winssl_fips.pas)
            [[ "$(uname)" != MINGW* && "$(uname)" != CYGWIN* ]]
            return $?
            ;;
    esac
    return 1
}

# 编译单个文件
compile_file() {
    local file="$1"
    local temp_dir
    local basename

    temp_dir=$(mktemp -d)
    basename=$(basename "$file" .pas)

    if $VERBOSE; then
        fpc -Mobjfpc -Sh -Fu"$SRC_DIR" -Fu"$EXAMPLES_DIR" -FE"$temp_dir" -o"$temp_dir/$basename" "$file" 2>&1
        local result=$?
    else
        fpc -Mobjfpc -Sh -Fu"$SRC_DIR" -Fu"$EXAMPLES_DIR" -FE"$temp_dir" -o"$temp_dir/$basename" "$file" > /dev/null 2>&1
        local result=$?
    fi

    rm -rf "$temp_dir"
    return $result
}

emit_runtime_line "开始编译验证..."
emit_runtime_line "========================================"

if [[ ! -d "$EXAMPLES_DIR" ]]; then
    echo -e "${RED}错误: examples 目录不存在或不可访问: $EXAMPLES_DIR${NC}" >&2
    exit 2
fi

# 预扫描全量示例文件，避免 stop-on-error 时把半程结果误写成全量统计
SCAN_FILE=$(mktemp)
if ! find "$EXAMPLES_DIR" -name "*.pas" -type f -print > "$SCAN_FILE"; then
    rm -f "$SCAN_FILE"
    echo -e "${RED}错误: 无法扫描 examples 目录: $EXAMPLES_DIR${NC}" >&2
    exit 2
fi
sort -o "$SCAN_FILE" "$SCAN_FILE"
EXAMPLE_FILES=()
while IFS= read -r file; do
    EXAMPLE_FILES+=("$file")
done < "$SCAN_FILE"
rm -f "$SCAN_FILE"
TOTAL=${#EXAMPLE_FILES[@]}

for file in "${EXAMPLE_FILES[@]}"; do
    relative_path="${file#$PROJECT_ROOT/}"
    if should_skip "$file"; then
        ((SKIPPED++))
        SKIPPED_FILES+=("$relative_path")
    fi
done

# 遍历所有示例文件
for file in "${EXAMPLE_FILES[@]}"; do
    relative_path="${file#$PROJECT_ROOT/}"

    if should_skip "$file"; then
        $VERBOSE && emit_runtime_line "${YELLOW}[SKIP]${NC} $relative_path"
        continue
    fi

    if compile_file "$file"; then
        ((PASSED++))
        emit_runtime_line "${GREEN}[PASS]${NC} $relative_path"
    else
        ((FAILED++))
        FAILED_FILES+=("$relative_path")
        emit_runtime_line "${RED}[FAIL]${NC} $relative_path"
        if $STOP_ON_ERROR; then
            STOPPED_EARLY=true
            break
        fi
    fi
done

emit_runtime_line "========================================"
emit_runtime_line ""

# 计算通过率
TESTED=$((PASSED + FAILED))
REMAINING=$((TOTAL - SKIPPED - TESTED))
if [ $REMAINING -lt 0 ]; then
    REMAINING=0
fi
if [ $TESTED -gt 0 ]; then
    PASS_RATE=$(awk "BEGIN {printf \"%.1f\", $PASSED * 100 / $TESTED}")
else
    PASS_RATE="0"
fi

# 输出摘要
output_summary() {
    case $OUTPUT_FORMAT in
        json)
            local failed_json
            if [ ${#FAILED_FILES[@]} -gt 0 ]; then
                failed_json=$(printf '"%s",' "${FAILED_FILES[@]}" | sed 's/,$//')
            else
                failed_json=""
            fi
            cat << EOF_JSON
{
  "timestamp": "$(date -Iseconds)",
  "fpc_version": "$FPC_VERSION",
  "summary": {
    "total": $TOTAL,
    "tested": $TESTED,
    "passed": $PASSED,
    "failed": $FAILED,
    "skipped": $SKIPPED,
    "remaining": $REMAINING,
    "stopped_early": $STOPPED_EARLY,
    "pass_rate": $PASS_RATE
  },
  "failed_files": [${failed_json}]
}
EOF_JSON
            ;;
        markdown)
            cat << EOF_MD
# 示例编译验证报告

> 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
> FPC 版本: $FPC_VERSION

## 摘要

| 指标 | 数值 |
|------|------|
| 总计 | $TOTAL |
| 已测试 | $TESTED |
| 通过 | $PASSED |
| 失败 | $FAILED |
| 跳过 | $SKIPPED |
| 未处理 | $REMAINING |
| 提前终止 | $STOPPED_EARLY |
| 通过率 | ${PASS_RATE}% |

EOF_MD
            if [ ${#FAILED_FILES[@]} -gt 0 ]; then
                echo "## 失败文件"
                for f in "${FAILED_FILES[@]}"; do echo "- \`$f\`"; done
            fi
            ;;
        *)
            echo "编译验证摘要"
            echo "============"
            echo "总计: $TOTAL"
            echo "已测试: $TESTED"
            echo "通过: $PASSED"
            echo "失败: $FAILED"
            echo "跳过: $SKIPPED"
            echo "未处理: $REMAINING"
            echo "提前终止: $STOPPED_EARLY"
            echo "通过率: ${PASS_RATE}%"
            if [ ${#FAILED_FILES[@]} -gt 0 ]; then
                echo ""
                echo "失败文件:"
                for f in "${FAILED_FILES[@]}"; do echo "  - $f"; done
            fi
            ;;
    esac
}

if [ -n "$REPORT_FILE" ]; then
    if ! output_summary > "$REPORT_FILE"; then
        echo -e "${RED}错误: 无法写入报告文件: $REPORT_FILE${NC}" >&2
        exit 2
    fi
    emit_runtime_line "报告已保存到: $REPORT_FILE"
else
    output_summary
fi

# 退出码
[ $FAILED -gt 0 ] && exit 1 || exit 0
