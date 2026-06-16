#!/bin/bash
# compile_winssl_cross.sh - 用 FPC 交叉编译 winssl 模块 (Linux → Windows)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRC_DIR="$PROJECT_DIR/core/src"
OUTPUT_DIR="$PROJECT_DIR/build/tls-winssl-units"

mkdir -p "$OUTPUT_DIR"

# FPC 路径
FPC="/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc"

# Windows 单元路径
WIN_UNITS="/opt/fpcupdeluxe/fpc/units/x86_64-win64"

# 项目单元路径
PROJECT_UNITS="$SRC_DIR"

# winssl 源文件列表
WINSSL_MODULES=(
    "nextpas.core.tls.winssl.api"
    "nextpas.core.tls.winssl.base"
    "nextpas.core.tls.winssl.certificate"
    "nextpas.core.tls.winssl.certstore"
    "nextpas.core.tls.winssl.connection"
    "nextpas.core.tls.winssl.context"
    "nextpas.core.tls.winssl.enterprise"
    "nextpas.core.tls.winssl.errors"
    "nextpas.core.tls.winssl.lib"
    "nextpas.core.tls.winssl.native_handle"
    "nextpas.core.tls.winssl.session"
    "nextpas.core.tls.winssl.utils"
)

# 编译标志
FPC_FLAGS="-Px86_64 -Twin64"
FPC_FLAGS="$FPC_FLAGS -Mobjfpc -Scgi -O2 -g -gl -vewnhi"
FPC_FLAGS="$FPC_FLAGS -dNEXTPAS_FORCE_HOST_WINDOWS"
FPC_FLAGS="$FPC_FLAGS -Fu$PROJECT_UNITS"
FPC_FLAGS="$FPC_FLAGS -Fu$OUTPUT_DIR"
FPC_FLAGS="$FPC_FLAGS -Fu$WIN_UNITS"
FPC_FLAGS="$FPC_FLAGS -Fu$WIN_UNITS/rtl"
FPC_FLAGS="$FPC_FLAGS -Fu$WIN_UNITS/rtl-objpas"
FPC_FLAGS="$FPC_FLAGS -Fu$WIN_UNITS/rtl-win"
FPC_FLAGS="$FPC_FLAGS -Fu$WIN_UNITS/fcl-base"
FPC_FLAGS="$FPC_FLAGS -Fu$WIN_UNITS/fcl-json"
FPC_FLAGS="$FPC_FLAGS -FE$OUTPUT_DIR"
FPC_FLAGS="$FPC_FLAGS -FU$OUTPUT_DIR"

echo "=== 编译 winssl 模块 (Linux → Windows 交叉编译) ==="
echo "FPC: $FPC"
echo "源码目录: $SRC_DIR"
echo "输出目录: $OUTPUT_DIR"
echo "Windows 单元: $WIN_UNITS"
echo ""

PASS=0
FAIL=0
FAIL_LIST=()

for module in "${WINSSL_MODULES[@]}"; do
    echo -n "编译 ${module}.pas ... "
    PAS_FILE="$SRC_DIR/${module}.pas"

    if [ ! -f "$PAS_FILE" ]; then
        echo "SKIP (文件不存在)"
        continue
    fi

    if $FPC $FPC_FLAGS "$PAS_FILE" > "$OUTPUT_DIR/${module}.log" 2>&1; then
        echo "PASS"
        PASS=$((PASS + 1))
    else
        echo "FAIL (日志: $OUTPUT_DIR/${module}.log)"
        FAIL=$((FAIL + 1))
        FAIL_LIST+=("$module")
    fi
done

echo ""
echo "=== 编译结果 ==="
echo "通过: $PASS"
echo "失败: $FAIL"

if [ ${#FAIL_LIST[@]} -gt 0 ]; then
    echo ""
    echo "失败模块:"
    for module in "${FAIL_LIST[@]}"; do
        echo "  - $module"
        # 显示最后 5 行错误
        echo "    错误信息:"
        tail -5 "$OUTPUT_DIR/${module}.log" | sed 's/^/    /'
    done
fi

exit $FAIL
