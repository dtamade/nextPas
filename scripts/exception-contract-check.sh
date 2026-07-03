#!/usr/bin/env bash

# exception-contract-check.sh — exception 模块契约完备性门禁
# 用法: scripts/exception-contract-check.sh
# 退出码: 0 = 全通过, 1 = 有违规, 2 = 用法错误

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CONTRACT="$REPO_ROOT/core/docs/exception/CONTRACT.md"
SRC_FILE="$REPO_ROOT/core/src/nextpas.core.exception.pas"
TEST_DIR="$REPO_ROOT/core/tests/nextpas.core.exception"

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

if [ -f "$SRC_FILE" ]; then
  LINES=$(wc -l < "$SRC_FILE")
  ok "源文件: nextpas.core.exception.pas ($LINES 行)"
else
  fail_check "源文件缺失: nextpas.core.exception.pas"
fi

# ── C3: Exception 基类 ──────────────────────────────────

printf "\n${BOLD}C3: Exception 基类${NC}\n"

if grep -q 'Exception = class' "$SRC_FILE"; then
  ok "Exception 基类定义"
else
  fail_check "Exception 基类定义缺失"
fi

for field in "fmessage" "fhelpcontext"; do
  if grep -q "$field" "$SRC_FILE"; then
    ok "FPC 兼容字段: $field"
  else
    fail_check "FPC 兼容字段缺失: $field"
  fi
done

for ctor in "Create" "CreateFmt"; do
  if grep -qP "(procedure|constructor)\s+Exception\.$ctor" "$SRC_FILE" 2>/dev/null || grep -q "constructor.*$ctor" "$SRC_FILE"; then
    ok "Exception.$ctor"
  else
    fail_check "Exception.$ctor 缺失"
  fi
done

# ── C4: ENextPasError ───────────────────────────────────

printf "\n${BOLD}C4: ENextPasError 框架根异常${NC}\n"

if grep -q 'ENextPasError = class' "$SRC_FILE"; then
  ok "ENextPasError 定义"
else
  fail_check "ENextPasError 定义缺失"
fi

for field in "FCategory" "FInner" "FOwnsInner"; do
  if grep -q "$field" "$SRC_FILE"; then
    ok "字段: $field"
  else
    fail_check "字段缺失: $field"
  fi
done

# 7 个构造函数重载
CTOR_COUNT=$(grep -cP 'constructor\s+ENextPasError\.Create' "$SRC_FILE" 2>/dev/null || echo 0)
if [ "$CTOR_COUNT" -ge 7 ]; then
  ok "ENextPasError 构造函数: $CTOR_COUNT 个重载"
else
  fail_check "ENextPasError 构造函数不足: 期望 >=7，实际 $CTOR_COUNT"
fi

if grep -qP 'destructor\s+ENextPasError\.Destroy' "$SRC_FILE"; then
  ok "ENextPasError.Destroy"
else
  fail_check "ENextPasError.Destroy 缺失"
fi

for method in "ResolveCategory" "DefaultCategory"; do
  if grep -q "$method" "$SRC_FILE"; then
    ok "方法: $method"
  else
    fail_check "方法缺失: $method"
  fi
done

# ── C5: TErrorCategory 枚举 ────────────────────────────

printf "\n${BOLD}C5: TErrorCategory 枚举 (18 值)${NC}\n"

for cat in "ecNone" "ecInvalidArgument" "ecNullReference" "ecInvalidOperation" \
           "ecNotImplemented" "ecNotSupported" "ecTimeout" "ecCancelled" \
           "ecInterrupted" "ecWouldBlock" "ecPermission" "ecNotFound" \
           "ecAlreadyExists" "ecResourceExhausted" "ecIO" "ecNetwork" "ecParse" "ecInternal"; do
  if grep -q "\b$cat\b" "$SRC_FILE"; then
    ok "枚举值: $cat"
  else
    fail_check "枚举值缺失: $cat"
  fi
done

# ── C6: 异常子类层次 ────────────────────────────────────

printf "\n${BOLD}C6: 异常子类层次${NC}\n"

for exc in "EArgumentError" "ENullReferenceError" "EInvalidOperationError" \
           "ENotImplementedError" "ENotSupportedError" "ETimeoutError" \
           "ECancelledError" "EInterruptedError" "EWouldBlockError" \
           "EPermissionError" "ENotFoundError" "EAlreadyExistsError" \
           "EResourceExhaustedError" "EIOError" "ENetworkError" \
           "EParseError" "EIndexOutOfRangeError" "EOutOfMemoryError" "EOutOfMemory"; do
  if grep -q "$exc" "$SRC_FILE"; then
    ok "子类: $exc"
  else
    fail_check "子类缺失: $exc"
  fi
done

# EOutOfMemoryError 继承 EResourceExhaustedError
if grep -qP 'EOutOfMemoryError\s*=\s*class\s*\(\s*EResourceExhaustedError\s*\)' "$SRC_FILE"; then
  ok "EOutOfMemoryError → EResourceExhaustedError 继承链"
else
  fail_check "EOutOfMemoryError 应继承 EResourceExhaustedError"
fi

# 兼容类型
for compat in "EConvertError" "EAssertionFailed" "ExceptClass"; do
  if grep -q "$compat" "$SRC_FILE"; then
    ok "兼容类型: $compat"
  else
    fail_check "兼容类型缺失: $compat"
  fi
done

# ── C7: 工具函数 ────────────────────────────────────────

printf "\n${BOLD}C7: 工具函数${NC}\n"

if grep -q "ErrorCategoryToString" "$SRC_FILE"; then
  ok "ErrorCategoryToString"
else
  fail_check "ErrorCategoryToString 缺失"
fi

if grep -q "FormatStr" "$SRC_FILE"; then
  ok "FormatStr（零 SysUtils 依赖）"
else
  fail_check "FormatStr 缺失"
fi

# ── C8: 零 SysUtils 依赖 ────────────────────────────────

printf "\n${BOLD}C8: 零 SysUtils 依赖${NC}\n"

if grep -qP '^\s*uses\b' "$SRC_FILE"; then
  USES_LINE=$(grep -P '^\s*uses\b' "$SRC_FILE")
  if echo "$USES_LINE" | grep -qi "SysUtils"; then
    fail_check "exception 模块不应依赖 SysUtils"
  else
    ok "无 SysUtils 依赖"
  fi
else
  ok "无 uses 子句（纯自足）"
fi

# ── C9: 测试目录完备性 ──────────────────────────────────

printf "\n${BOLD}C9: 测试目录完备性${NC}\n"

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
  ok "无未声明的测试目录"
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
