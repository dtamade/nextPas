#!/usr/bin/env bash

# base-contract-check.sh — base 模块契约完备性门禁
# 用法: scripts/base-contract-check.sh
# 退出码: 0 = 全通过, 1 = 有违规, 2 = 用法错误

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CONTRACT="$REPO_ROOT/core/docs/base/CONTRACT.md"
SRC_DIR="$REPO_ROOT/core/src"
TEST_DIR="$REPO_ROOT/core/tests/nextpas.core.base"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; NC='\033[0m'
pass=0; fail=0; warn=0
ok() { pass=$((pass + 1)); printf "${GREEN}✓${NC} %s\n" "$1"; }
fail_check() { fail=$((fail + 1)); printf "${RED}✗${NC} %s\n" "$1"; }
warn_check() { warn=$((warn + 1)); printf "${YELLOW}⚠${NC} %s\n" "$1"; }

# ── C1: 契约文件结构 ────────────────────────────────────

printf "\n${BOLD}C1: 契约文件结构${NC}\n"

if [ ! -f "$CONTRACT" ]; then
  fail_check "CONTRACT.md 不存在"; exit 1
fi

for section in "接口契约" "不变量" "错误处理" "线程安全" "内存管理" "测试覆盖"; do
  if grep -q "$section" "$CONTRACT"; then
    ok "章节 '$section'"
  else
    fail_check "章节 '$section' 缺失"
  fi
done

# ── C2: 源文件完备性 ────────────────────────────────────

printf "\n${BOLD}C2: 源文件完备性${NC}\n"

REQUIRED_SRC=("nextpas.core.base.pas" "nextpas.core.base.utils.pas")
for f in "${REQUIRED_SRC[@]}"; do
  if [ -f "$SRC_DIR/$f" ]; then
    ok "核心文件: $f"
  else
    fail_check "核心文件缺失: $f"
  fi
done

# ── C3: 规范类型 ─────────────────────────────────────────

printf "\n${BOLD}C3: 规范类型别名${NC}\n"

BASE_FILE="$SRC_DIR/nextpas.core.base.pas"
for type in "SizeInt" "SizeUInt" "PtrInt" "PtrUInt" "NativeInt" "NativeUInt" "TBytes" "TStringArray" "THashCode"; do
  if grep -q "$type" "$BASE_FILE"; then
    ok "类型: $type"
  else
    fail_check "类型缺失: $type"
  fi
done

# ── C4: 异常类 ───────────────────────────────────────────

printf "\n${BOLD}C4: 异常类${NC}\n"

for exc in "EInvariantViolation" "EArgumentNil" "EEmptyCollection" "EInvalidArgument" \
           "EInvalidResult" "EInvalidState" "EOutOfRange" "ENotSupported" \
           "ENotCompatible" "EInvalidOperation" "EOverflow"; do
  if grep -q "$exc" "$BASE_FILE"; then
    ok "异常: $exc"
  else
    fail_check "异常缺失: $exc"
  fi
done

# ── C5: 泛型类型 ─────────────────────────────────────────

printf "\n${BOLD}C5: 泛型类型${NC}\n"

for gen in "TPair" "TComparer" "TEqualityCheck" "THasher" "TNullable" "TOption" "TResult"; do
  if grep -q "generic $gen" "$BASE_FILE" 2>/dev/null || grep -q "$gen" "$BASE_FILE"; then
    ok "泛型: $gen"
  else
    fail_check "泛型缺失: $gen"
  fi
done

# ── C6: TByteSpan ────────────────────────────────────────

printf "\n${BOLD}C6: TByteSpan${NC}\n"

for method in "Create" "FromBytes" "Empty" "Slice" "GetByte"; do
  if grep -q "function TByteSpan\.$method\|class function TByteSpan\.$method" "$BASE_FILE" 2>/dev/null || grep -q "TByteSpan\.$method" "$BASE_FILE"; then
    ok "TByteSpan.$method"
  else
    fail_check "TByteSpan.$method 缺失"
  fi
done

# ── C7: 契约断言 ─────────────────────────────────────────

printf "\n${BOLD}C7: 契约断言${NC}\n"

for proc in "Require" "Ensure" "CheckState" "Unreachable"; do
  if grep -q "procedure $proc" "$BASE_FILE"; then
    ok "断言: $proc"
  else
    fail_check "断言缺失: $proc"
  fi
done

# ── C8: 哈希函数 ─────────────────────────────────────────

printf "\n${BOLD}C8: 哈希函数${NC}\n"

for fn in "HashBytes" "HashString" "HashInteger" "HashPointer"; do
  if grep -q "function $fn" "$BASE_FILE"; then
    ok "哈希: $fn"
  else
    fail_check "哈希缺失: $fn"
  fi
done

# ── C9: 内存工具 ─────────────────────────────────────────

printf "\n${BOLD}C9: 内存工具 (base.utils)${NC}\n"

UTILS_FILE="$SRC_DIR/nextpas.core.base.utils.pas"
for fn in "FreeAndNil" "SafeFree" "ZeroMem" "FillMem" "CopyMem" "CompareMem"; do
  if [ -f "$UTILS_FILE" ] && grep -q "procedure $fn\|function $fn" "$UTILS_FILE"; then
    ok "工具: $fn"
  else
    fail_check "工具缺失: $fn"
  fi
done

# ── C10: 安全算术 ────────────────────────────────────────

printf "\n${BOLD}C10: SizeUInt 安全算术${NC}\n"

for fn in "TryAddSizeUInt" "CheckedAddSizeUInt" "TryMulSizeUInt" "CheckedMulSizeUInt" "CheckSizeRange"; do
  if [ -f "$UTILS_FILE" ] && grep -q "function $fn\|procedure $fn" "$UTILS_FILE"; then
    ok "算术: $fn"
  else
    fail_check "算术缺失: $fn"
  fi
done

# ── C11: Supports 接口查询 ───────────────────────────────

printf "\n${BOLD}C11: Supports 接口查询${NC}\n"

if [ -f "$UTILS_FILE" ] && grep -q "function Supports" "$UTILS_FILE"; then
  ok "Supports 函数"
else
  fail_check "Supports 函数缺失"
fi

# ── C12: 测试目录完备性 ──────────────────────────────────

printf "\n${BOLD}C12: 测试目录完备性${NC}\n"

CONTRACT_TESTS=$(grep -oP 'test_[a-z0-9_]+' "$CONTRACT" | sort -u)
ACTUAL_TESTS=$(find "$TEST_DIR" -mindepth 1 -maxdepth 1 -type d -name 'test_*' -exec basename {} \; | sort -u)

MISSING_TESTS=""
for t in $CONTRACT_TESTS; do
  if ! echo "$ACTUAL_TESTS" | grep -qx "$t"; then
    MISSING_TESTS="$MISSING_TESTS $t"
  fi
done

if [ -z "$MISSING_TESTS" ]; then
  ok "契约声明的测试全部存在"
else
  for t in $MISSING_TESTS; do
    fail_check "契约声明但缺失的测试: $t"
  done
fi

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

# ── 结果汇总 ─────────────────────────────────────────────

printf "\n${BOLD}═══════════════════════════════════${NC}\n"
printf "${GREEN}通过: %d${NC}  ${RED}失败: %d${NC}  ${YELLOW}警告: %d${NC}\n" "$pass" "$fail" "$warn"

if [ "$fail" -gt 0 ]; then
  printf "\n${RED}${BOLD}契约门禁: 失败${NC}\n"; exit 1
elif [ "$warn" -gt 0 ]; then
  printf "\n${YELLOW}${BOLD}契约门禁: 通过（有警告）${NC}\n"; exit 0
else
  printf "\n${GREEN}${BOLD}契约门禁: 全通过${NC}\n"; exit 0
fi
