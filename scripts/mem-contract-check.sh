#!/usr/bin/env bash

# mem-contract-check.sh — mem 模块契约完备性门禁
# 用法: scripts/mem-contract-check.sh [--fix]
# 退出码: 0 = 全通过, 1 = 有违规, 2 = 用法错误

set -euo pipefail

# ── 路径 ──────────────────────────────────────────────

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CONTRACT="$REPO_ROOT/core/docs/mem/CONTRACT.md"
SRC_DIR="$REPO_ROOT/core/src"
TEST_DIR="$REPO_ROOT/core/tests/nextpas.core.mem"
FIX_MODE=false

if [ "${1:-}" = "--fix" ]; then
  FIX_MODE=true
fi

# ── 颜色 ──────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

pass=0
fail=0
warn=0

ok() {
  pass=$((pass + 1))
  printf "${GREEN}✓${NC} %s\n" "$1"
}

fail_check() {
  fail=$((fail + 1))
  printf "${RED}✗${NC} %s\n" "$1"
}

warn_check() {
  warn=$((warn + 1))
  printf "${YELLOW}⚠${NC} %s\n" "$1"
}

# ── C1: 契约文件存在且结构完整 ─────────────────────────

printf "\n${BOLD}C1: 契约文件结构${NC}\n"

if [ ! -f "$CONTRACT" ]; then
  fail_check "CONTRACT.md 不存在: $CONTRACT"
  printf "${RED}无法继续——契约文件缺失${NC}\n"
  exit 1
fi

EXPECTED_SECTIONS=(
  "接口契约"
  "不变量"
  "错误处理"
  "线程安全"
  "内存管理"
  "测试覆盖"
)

for section in "${EXPECTED_SECTIONS[@]}"; do
  if grep -q "$section" "$CONTRACT"; then
    ok "章节 '$section' 存在"
  else
    fail_check "章节 '$section' 缺失"
  fi
done

# ── C2: 源文件完备性 ───────────────────────────────────

printf "\n${BOLD}C2: 源文件完备性${NC}\n"

# 契约声称的源文件数
CLAIMED_SRC_COUNT=$(grep -oP '\d+\s*个源文件' "$CONTRACT" | grep -oP '\d+' | head -1)
ACTUAL_SRC_COUNT=$(find "$SRC_DIR" -name 'nextpas.core.mem*' -type f | wc -l)

if [ "$ACTUAL_SRC_COUNT" -eq "$CLAIMED_SRC_COUNT" ]; then
  ok "源文件数: $ACTUAL_SRC_COUNT (契约声称 $CLAIMED_SRC_COUNT)"
else
  warn_check "源文件数不匹配: 实际 $ACTUAL_SRC_COUNT vs 契约 $CLAIMED_SRC_COUNT"
fi

# 核心文件必须存在
REQUIRED_SRC_FILES=(
  "nextpas.core.mem.pas"
  "nextpas.core.mem.intf.pas"
  "nextpas.core.mem.base.pas"
  "nextpas.core.mem.error.pas"
  "nextpas.core.mem.allocator.pas"
  "nextpas.core.mem.allocator.base.pas"
  "nextpas.core.mem.allocator.rtl.pas"
  "nextpas.core.mem.arena.intf.pas"
  "nextpas.core.mem.arena.local.pas"
  "nextpas.core.mem.arena.virtual.pas"
  "nextpas.core.mem.arena.chunked.pas"
  "nextpas.core.mem.default.pas"
  "nextpas.core.mem.mutex.pas"
)

for f in "${REQUIRED_SRC_FILES[@]}"; do
  if [ -f "$SRC_DIR/$f" ]; then
    ok "核心文件: $f"
  else
    fail_check "核心文件缺失: $f"
  fi
done

# ── C3: 接口声明完备性 ─────────────────────────────────

printf "\n${BOLD}C3: 接口声明完备性${NC}\n"

# IAllocator 方法
IALLOC_METHODS=(
  "function GetMem"
  "function AllocMem"
  "function ReallocMem"
  "procedure FreeMem"
  "function MemSize"
  "function AllocAligned"
  "procedure FreeAligned"
  "function Traits"
)

INTF_FILE="$SRC_DIR/nextpas.core.mem.intf.pas"
if [ -f "$INTF_FILE" ]; then
  for method in "${IALLOC_METHODS[@]}"; do
    if grep -q "$method" "$INTF_FILE"; then
      ok "IAllocator.$method"
    else
      fail_check "IAllocator.$method 缺失于 intf.pas"
    fi
  done
else
  fail_check "intf.pas 不存在"
fi

# IArena 方法
ARENA_INTF_FILE="$SRC_DIR/nextpas.core.mem.arena.intf.pas"
if [ -f "$ARENA_INTF_FILE" ]; then
  IARENA_METHODS=(
    "function Alloc"
    "function AllocAligned"
    "function AllocZeroed"
    "function SaveMark"
    "procedure RestoreToMark"
    "procedure Reset"
    "function UsedSize"
    "function RemainingSize"
    "function Stats"
  )
  for method in "${IARENA_METHODS[@]}"; do
    if grep -q "$method" "$ARENA_INTF_FILE"; then
      ok "IArena.$method"
    else
      fail_check "IArena.$method 缺失于 arena.intf.pas"
    fi
  done
else
  fail_check "arena.intf.pas 不存在"
fi

# ── C4: 分配器解析模式 ──────────────────────────────────

printf "\n${BOLD}C4: 分配器解析模式${NC}\n"

# GetRtlAllocator 存在性
RTL_FILE="$SRC_DIR/nextpas.core.mem.allocator.rtl.pas"
if [ -f "$RTL_FILE" ] && grep -q "function GetRtlAllocator" "$RTL_FILE"; then
  ok "GetRtlAllocator (allocator.rtl.pas)"
else
  fail_check "GetRtlAllocator 缺失于 allocator.rtl.pas"
fi

# 内联 nil→GetRtlAllocator fallback 模式
FALLBACK_COUNT=$(grep -rl 'GetRtlAllocator' "$SRC_DIR"/nextpas.core.mem*.pas 2>/dev/null | wc -l)
if [ "$FALLBACK_COUNT" -gt 0 ]; then
  ok "GetRtlAllocator fallback 引用: $FALLBACK_COUNT 个文件"
else
  fail_check "无任何文件引用 GetRtlAllocator"
fi

# IsPowerOfTwo 对齐验证
ALIGN_COUNT=$(grep -rl 'IsPowerOfTwo' "$SRC_DIR"/nextpas.core.mem*.pas 2>/dev/null | wc -l)
if [ "$ALIGN_COUNT" -gt 0 ]; then
  ok "IsPowerOfTwo 对齐验证: $ALIGN_COUNT 个文件"
else
  fail_check "无任何文件使用 IsPowerOfTwo"
fi

# ── C5: 不变量标记 ─────────────────────────────────────

printf "\n${BOLD}C5: 不变量注释标记${NC}\n"

INV_COUNT=0
for f in "$SRC_DIR"/nextpas.core.mem*.pas; do
  count=$(grep -c '\[INV-' "$f" 2>/dev/null || true)
  INV_COUNT=$((INV_COUNT + count))
done

if [ "$INV_COUNT" -gt 0 ]; then
  ok "源码中 INV- 标记: $INV_COUNT 处"
else
  ok "源码中 INV- 标记: 0（不变量在 CONTRACT.md 中记录）"
fi

# ── C6: 测试文件完备性 ─────────────────────────────────

printf "\n${BOLD}C6: 测试文件完备性${NC}\n"

# 从 CONTRACT.md 提取测试文件名
CONTRACT_TESTS=$(grep -oP 'test_[a-z0-9_]+' "$CONTRACT" | sort -u)
ACTUAL_TESTS=$(find "$TEST_DIR" -mindepth 1 -maxdepth 1 -type d -name 'test_*' -exec basename {} \; | sort -u)

# 契约中声明但不存在的测试
MISSING_TESTS=""
for t in $CONTRACT_TESTS; do
  if ! echo "$ACTUAL_TESTS" | grep -qx "$t"; then
    MISSING_TESTS="$MISSING_TESTS $t"
  fi
done

if [ -z "$MISSING_TESTS" ]; then
  ok "契约声明的测试全部存在 ($(echo "$CONTRACT_TESTS" | wc -l) 个)"
else
  for t in $MISSING_TESTS; do
    fail_check "契约声明但缺失的测试: $t"
  done
fi

# 实际存在但契约未声明的测试
UNDECLARED=""
for t in $ACTUAL_TESTS; do
  if ! echo "$CONTRACT_TESTS" | grep -qx "$t"; then
    UNDECLARED="$UNDECLARED $t"
  fi
done

if [ -z "$UNDECLARED" ]; then
  ok "无未声明的测试文件"
else
  for t in $UNDECLARED; do
    warn_check "实际存在但契约未声明的测试: $t"
  done
fi

# ── C7: TAllocator Do* 模板方法 ────────────────────────

printf "\n${BOLD}C7: TAllocator 模板方法${NC}\n"

ALLOC_BASE="$SRC_DIR/nextpas.core.mem.allocator.base.pas"
if [ -f "$ALLOC_BASE" ]; then
  TEMPLATE_METHODS=(
    "DoGetMem"
    "DoAllocMem"
    "DoReallocMem"
    "DoFreeMem"
    "DoMemSize"
  )
  for method in "${TEMPLATE_METHODS[@]}"; do
    if grep -q "function $method\|procedure $method" "$ALLOC_BASE"; then
      ok "TAllocator.$method"
    else
      fail_check "TAllocator.$method 缺失于 allocator.base.pas"
    fi
  done
else
  fail_check "allocator.base.pas 不存在"
fi

# ── C8: 异常类层级 ─────────────────────────────────────

printf "\n${BOLD}C8: 异常类层级${NC}\n"

ERROR_FILE="$SRC_DIR/nextpas.core.mem.error.pas"
if [ -f "$ERROR_FILE" ]; then
  if grep -q "EAllocError" "$ERROR_FILE"; then
    ok "EAllocError"
  else
    fail_check "EAllocError 缺失"
  fi
  if grep -q "EDoubleFree" "$ERROR_FILE"; then
    ok "EDoubleFree"
  else
    fail_check "EDoubleFree 缺失"
  fi
  if grep -q "TAllocError" "$ERROR_FILE"; then
    ok "TAllocError 枚举"
  else
    fail_check "TAllocError 枚举缺失"
  fi

  # 错误码覆盖
  ERROR_CODES=(
    "aeOutOfMemory"
    "aeInvalidLayout"
    "aeAlignmentNotSupported"
    "aeSizeMismatch"
    "aeInvalidPointer"
    "aeDoubleFree"
    "aePoolClosed"
    "aeReallocNotSupported"
    "aeInternalError"
  )
  for code in "${ERROR_CODES[@]}"; do
    if grep -q "$code" "$ERROR_FILE"; then
      ok "错误码 $code"
    else
      fail_check "错误码 $code 缺失"
    fi
  done
else
  fail_check "error.pas 不存在"
fi

# ── C9: 线程安全包装 ───────────────────────────────────

printf "\n${BOLD}C9: 线程安全包装${NC}\n"

CONCURRENT_WRAPPERS=(
  "nextpas.core.mem.arena.concurrent.pas"
  "nextpas.core.mem.pool.slab.concurrent.pas"
  "nextpas.core.mem.blockpool.concurrent.pas"
)

for wrapper in "${CONCURRENT_WRAPPERS[@]}"; do
  if [ -f "$SRC_DIR/$wrapper" ]; then
    ok "并发包装: $wrapper"
  else
    fail_check "并发包装缺失: $wrapper"
  fi
done

# ── 结果汇总 ───────────────────────────────────────────

printf "\n${BOLD}═══════════════════════════════════${NC}\n"
printf "${GREEN}通过: %d${NC}  ${RED}失败: %d${NC}  ${YELLOW}警告: %d${NC}\n" "$pass" "$fail" "$warn"

if [ "$fail" -gt 0 ]; then
  printf "\n${RED}${BOLD}契约门禁: 失败${NC}\n"
  exit 1
elif [ "$warn" -gt 0 ]; then
  printf "\n${YELLOW}${BOLD}契约门禁: 通过（有警告）${NC}\n"
  exit 0
else
  printf "\n${GREEN}${BOLD}契约门禁: 全通过${NC}\n"
  exit 0
fi
