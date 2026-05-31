#!/bin/bash
#
# lazbuild_all.sh - Compile all test .lpi files using lazbuild
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LAZBUILD="/home/dtamade/freePascal/lazarus/lazbuild"

if [ ! -x "$LAZBUILD" ]; then
    echo "错误: lazbuild 未找到: $LAZBUILD"
    exit 1
fi

# Detect current platform
case "$(uname -s)" in
    Linux*)   PLATFORM="linux";;
    Darwin*)  PLATFORM="darwin";;
    MINGW*|MSYS*|CYGWIN*) PLATFORM="windows";;
    *)        PLATFORM="unknown";;
esac

echo "使用 lazbuild: $LAZBUILD"
echo "当前平台: $PLATFORM"
echo ""

COMPILED=0
FAILED=0
SKIPPED=0
FAILED_LIST=""
SKIPPED_LIST=""

# Check if test should be skipped based on platform
should_skip() {
    local name="$1"

    # Windows-only tests (winssl, windows)
    if [[ "$PLATFORM" != "windows" ]]; then
        if [[ "$name" == *"winssl"* ]] || [[ "$name" == *"_windows"* ]]; then
            return 0  # Skip
        fi
    fi

    # Linux-only tests
    if [[ "$PLATFORM" != "linux" ]]; then
        if [[ "$name" == *"_linux"* ]]; then
            return 0  # Skip
        fi
    fi

    # macOS-only tests
    if [[ "$PLATFORM" != "darwin" ]]; then
        if [[ "$name" == *"_darwin"* ]] || [[ "$name" == *"_macos"* ]]; then
            return 0  # Skip
        fi
    fi

    return 1  # Don't skip
}

compile_lpi() {
    local lpi="$1"
    local name=$(basename "$lpi")
    local name_lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')

    # Check platform compatibility
    if should_skip "$name_lower"; then
        echo -n "  跳过 $name... "
        echo "(平台不兼容)"
        ((SKIPPED++))
        SKIPPED_LIST="$SKIPPED_LIST\n  - $name"
        return
    fi

    echo -n "  编译 $name... "
    if $LAZBUILD "$lpi" > /dev/null 2>&1; then
        echo "成功"
        ((COMPILED++))
    else
        echo "失败"
        ((FAILED++))
        FAILED_LIST="$FAILED_LIST\n  - $name"
    fi
}

# Compile tests/*.lpi
echo "=== 编译 tests/*.lpi ==="
for lpi in "$PROJECT_DIR"/tests/*.lpi; do
    [ -f "$lpi" ] && compile_lpi "$lpi"
done

# Compile tests/integration/*.lpi
echo ""
echo "=== 编译 tests/integration/*.lpi ==="
for lpi in "$PROJECT_DIR"/tests/integration/*.lpi; do
    [ -f "$lpi" ] && compile_lpi "$lpi"
done

# Compile tests/security/*.lpi
echo ""
echo "=== 编译 tests/security/*.lpi ==="
for lpi in "$PROJECT_DIR"/tests/security/*.lpi; do
    [ -f "$lpi" ] && compile_lpi "$lpi"
done

# Compile tests/http/*.lpi
echo ""
echo "=== 编译 tests/http/*.lpi ==="
for lpi in "$PROJECT_DIR"/tests/http/*.lpi; do
    [ -f "$lpi" ] && compile_lpi "$lpi"
done

# Summary
echo ""
echo "==========================================="
echo "编译摘要"
echo "==========================================="
echo "成功: $COMPILED"
echo "失败: $FAILED"
echo "跳过: $SKIPPED (平台不兼容)"

if [ $SKIPPED -gt 0 ]; then
    echo ""
    echo "跳过的文件:"
    echo -e "$SKIPPED_LIST"
fi

if [ $FAILED -gt 0 ]; then
    echo ""
    echo "失败的文件:"
    echo -e "$FAILED_LIST"
    exit 1
fi

echo ""
echo "所有适用测试编译成功!"
