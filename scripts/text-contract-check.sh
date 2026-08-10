#!/usr/bin/env bash

# text-contract-check.sh — text 模块契约完备性门禁
# 用法: scripts/text-contract-check.sh
# 退出码: 0 = 全通过, 1 = 有违规, 2 = 用法错误

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CONTRACT="$REPO_ROOT/core/docs/text/CONTRACT.md"
SRC_DIR="$REPO_ROOT/core/src"
TEST_DIR="$REPO_ROOT/core/tests/nextpas.core.text"

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

printf "\n${BOLD}C2: 核心源文件${NC}\n"

CORE_FILES=("nextpas.core.text.pas" "nextpas.core.text.base.pas" "nextpas.core.text.view.pas"
            "nextpas.core.text.builder.pas" "nextpas.core.text.conv.pas" "nextpas.core.text.format.pas"
            "nextpas.core.text.utf8.pas" "nextpas.core.text.tstring.pas" "nextpas.core.text.unicode.pas")
for f in "${CORE_FILES[@]}"; do
  if [ -f "$SRC_DIR/$f" ]; then
    ok "核心文件: $f"
  else
    fail_check "核心文件缺失: $f"
  fi
done

# ── C3: 核心类型 ────────────────────────────────────────

printf "\n${BOLD}C3: 核心类型${NC}\n"

VIEW_FILE="$SRC_DIR/nextpas.core.text.view.pas"
BUILDER_FILE="$SRC_DIR/nextpas.core.text.builder.pas"
TSTRING_FILE="$SRC_DIR/nextpas.core.text.tstring.pas"

# TStringView
if [ -f "$VIEW_FILE" ] && grep -q "TStringView" "$VIEW_FILE"; then
  ok "TStringView 定义"
else
  fail_check "TStringView 缺失"
fi

# IStringBuilder
if [ -f "$BUILDER_FILE" ] && grep -q "IStringBuilder" "$BUILDER_FILE"; then
  ok "IStringBuilder 接口"
else
  fail_check "IStringBuilder 缺失"
fi

# TString
if [ -f "$TSTRING_FILE" ] && grep -q "TString" "$TSTRING_FILE"; then
  ok "TString 类型"
else
  fail_check "TString 缺失"
fi

# ── C4: 转换函数 ────────────────────────────────────────

printf "\n${BOLD}C4: 文本转换函数${NC}\n"

CONV_FILE="$SRC_DIR/nextpas.core.text.conv.pas"
for fn in "IntToStr" "StrToInt" "TryStrToInt" "BoolToStr" "FloatToStr" "Format"; do
  if [ -f "$CONV_FILE" ] && grep -q "\b$fn\b" "$CONV_FILE"; then
    ok "转换: $fn"
  else
    fail_check "转换函数缺失: $fn"
  fi
done

# ── C5: Unicode 子系统 ──────────────────────────────────

printf "\n${BOLD}C5: Unicode 子系统${NC}\n"

for submod in "nextpas.core.text.unicode.pas" "nextpas.core.text.unicode.base.pas" \
              "nextpas.core.text.unicode.casefold.pas" "nextpas.core.text.unicode.normalize.pas" \
              "nextpas.core.text.unicode.props.pas" "nextpas.core.text.unicode.utils.pas"; do
  if [ -f "$SRC_DIR/$submod" ]; then
    ok "Unicode 子模块: $submod"
  else
    fail_check "Unicode 子模块缺失: $submod"
  fi
done

# ── C6: 文本宽度 ────────────────────────────────────────

printf "\n${BOLD}C6: 文本宽度子系统${NC}\n"

WIDTH_FILE="$SRC_DIR/nextpas.core.text.width.pas"
if [ -f "$WIDTH_FILE" ] && grep -q "StringDisplayWidth\|CodepointWidth\|CharWidth" "$WIDTH_FILE"; then
  ok "StringDisplayWidth/CodepointWidth 函数"
else
  fail_check "TextWidth 函数缺失"
fi

if [ -f "$SRC_DIR/nextpas.core.text.width.codepoint.pas" ]; then
  ok "width.codepoint 子模块"
else
  warn_check "width.codepoint 子模块缺失"
fi

# ── C7: IStringBuilder 方法 ─────────────────────────────

printf "\n${BOLD}C7: IStringBuilder 接口方法${NC}\n"

if [ -f "$BUILDER_FILE" ]; then
  for method in "AppendChar" "AppendStr" "ToString" "Clear" "Length"; do
    if grep -q "\b$method\b" "$BUILDER_FILE"; then
      ok "IStringBuilder.$method"
    else
      fail_check "IStringBuilder.$method 缺失"
    fi
  done
else
  fail_check "builder 文件缺失，无法检查接口方法"
fi

# ── C8: IAllocator 集成 ─────────────────────────────────

printf "\n${BOLD}C8: IAllocator 集成${NC}\n"

if grep -rl "IAllocator\|ResolveAllocator" "$SRC_DIR"/nextpas.core.text*.pas 2>/dev/null | head -1 | grep -q .; then
  ok "text 模块使用 IAllocator"
else
  warn_check "未发现 IAllocator 集成"
fi

# ── C9: 测试目录完备性 ──────────────────────────────────

printf "\n${BOLD}C9: 测试目录完备性${NC}\n"

CONTRACT_TESTS=$(grep -oP 'test_[a-z0-9_]+' "$CONTRACT" | sort -u)
# 测试分散在门面与各子模块目录树（text / text.builder / text.unicode / …），全量扫描
ACTUAL_TESTS=$(find "$REPO_ROOT/core/tests"/nextpas.core.text* -mindepth 1 -maxdepth 1 -type d -name 'test_*' -exec basename {} \; | sort -u)

MISSING_TESTS=""
for t in $CONTRACT_TESTS; do
  if [[ "$t" == *_ ]]; then
    # 契约允许尾缀通配（如 test_conformance_*）：按前缀匹配
    if ! echo "$ACTUAL_TESTS" | grep -q "^${t}"; then
      MISSING_TESTS="$MISSING_TESTS $t"
    fi
  elif ! echo "$ACTUAL_TESTS" | grep -qx "$t"; then
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
