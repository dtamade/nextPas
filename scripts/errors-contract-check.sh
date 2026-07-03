#!/usr/bin/env bash

# errors-contract-check.sh — errors 模块契约完备性门禁
# 用法: scripts/errors-contract-check.sh
# 退出码: 0 = 全通过, 1 = 有违规, 2 = 用法错误

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CONTRACT="$REPO_ROOT/core/docs/errors/CONTRACT.md"
SRC_FILE="$REPO_ROOT/core/src/nextpas.core.errors.pas"
EXCEPTION_FILE="$REPO_ROOT/core/src/nextpas.core.exception.pas"
TEST_DIR="$REPO_ROOT/core/tests/nextpas.core.errors"

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
  ok "源文件: nextpas.core.errors.pas"
else
  fail_check "源文件缺失: nextpas.core.errors.pas"
fi

# ── C3: re-export 1:1 对应 ──────────────────────────────

printf "\n${BOLD}C3: re-export 符号与 exception 源码 1:1 对应${NC}\n"

# errors 应 re-export exception 中的所有公开类型
for type in "Exception" "ExceptClass" "EConvertError" "EAssertionFailed" "TErrorCategory" \
            "ENextPasError" "EArgumentError" "ENullReferenceError" "EInvalidOperationError" \
            "ENotImplementedError" "ENotSupportedError" "ETimeoutError" "ECancelledError" \
            "EInterruptedError" "EWouldBlockError" "EPermissionError" "ENotFoundError" \
            "EAlreadyExistsError" "EResourceExhaustedError" "EIOError" "ENetworkError" \
            "EParseError" "EIndexOutOfRangeError" "EOutOfMemoryError" "EOutOfMemory"; do
  if grep -q "\b$type\b" "$SRC_FILE"; then
    ok "re-export 类型: $type"
  else
    fail_check "re-export 类型缺失: $type"
  fi
done

# ── C4: 错误分类常量 ────────────────────────────────────

printf "\n${BOLD}C4: TErrorCategory 常量${NC}\n"

for const in "ecNone" "ecInvalidArgument" "ecNullReference" "ecInvalidOperation" \
             "ecNotImplemented" "ecNotSupported" "ecTimeout" "ecCancelled" \
             "ecInterrupted" "ecWouldBlock" "ecPermission" "ecNotFound" \
             "ecAlreadyExists" "ecResourceExhausted" "ecIO" "ecNetwork" "ecParse" "ecInternal"; do
  if grep -q "\b$const\b" "$SRC_FILE"; then
    ok "常量: $const"
  else
    fail_check "常量缺失: $const"
  fi
done

# ── C5: ErrorCategoryToString ────────────────────────────

printf "\n${BOLD}C5: 工具函数${NC}\n"

if grep -q "ErrorCategoryToString" "$SRC_FILE"; then
  ok "ErrorCategoryToString"
else
  fail_check "ErrorCategoryToString 缺失"
fi

# ── C6: 不添加自有逻辑 ──────────────────────────────────

printf "\n${BOLD}C6: 门面纯度（不添加自有类型/逻辑）${NC}\n"

# errors 单元不应有 class/record/exception 定义（除了 type 别名）
if grep -qP '^\s*(type|class|record)\b' "$SRC_FILE" 2>/dev/null; then
  # 排除 type alias 声明
  OWN_TYPES=$(grep -cP '^\s*\w+\s*=\s*(class|record)' "$SRC_FILE" 2>/dev/null || true)
  OWN_TYPES=${OWN_TYPES:-0}
  if [ "$OWN_TYPES" -gt 0 ]; then
    fail_check "errors 模块不应定义自有 class/record（发现 $OWN_TYPES 个）"
  else
    ok "无自有类型定义"
  fi
else
  ok "无自有类型定义"
fi

# 不应有独立的 procedure/function 实现（除了 inline forwarding）
IMPL_PROCS=$(grep -cP '^\s*(procedure|function)\s+\w+\.' "$SRC_FILE" 2>/dev/null || true)
IMPL_PROCS=${IMPL_PROCS:-0}
if [ "$IMPL_PROCS" -gt 0 ]; then
  fail_check "errors 模块不应有独立过程实现（发现 $IMPL_PROCS 个）"
else
  ok "无独立过程实现"
fi

# ── C7: 测试目录完备性 ──────────────────────────────────

printf "\n${BOLD}C7: 测试目录完备性${NC}\n"

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
