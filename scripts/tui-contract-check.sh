#!/usr/bin/env bash

# tui-contract-check.sh — tui 模块契约完备性门禁
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CONTRACT="$REPO_ROOT/core/docs/tui/CONTRACT.md"
SRC_DIR="$REPO_ROOT/core/src"
TEST_DIR="$REPO_ROOT/core/tests/nextpas.core.tui"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; NC='\033[0m'
pass=0; fail=0; warn=0
ok() { pass=$((pass + 1)); printf "${GREEN}✓${NC} %s\n" "$1"; }
fail_check() { fail=$((fail + 1)); printf "${RED}✗${NC} %s\n" "$1"; }
warn_check() { warn=$((warn + 1)); printf "${YELLOW}⚠${NC} %s\n" "$1"; }

printf "\n${BOLD}C1: 契约文件结构${NC}\n"
if [ ! -f "$CONTRACT" ]; then fail_check "CONTRACT.md 不存在"; exit 1; fi
for section in "接口契约" "不变量" "概要" "变更记录"; do
  if grep -q "$section" "$CONTRACT"; then ok "章节 '$section'"; else fail_check "章节 '$section' 缺失"; fi
done

printf "\n${BOLD}C2: 源文件规模${NC}\n"
PAS_COUNT=$(find "$SRC_DIR" -name 'nextpas.core.tui*.pas' | wc -l)
ok "源文件: $PAS_COUNT 个"

printf "\n${BOLD}C3: 核心子系统${NC}\n"
for sub in "tui.base" "tui.buffer" "tui.cell" "tui.color" "tui.event" "tui.layout" "tui.style" "tui.terminal"; do
  if [ -f "$SRC_DIR/nextpas.core.$sub.pas" ]; then ok "子系统: $sub"; else warn_check "子系统缺失: $sub"; fi
done

printf "\n${BOLD}C4: Widget 体系${NC}\n"
WIDGET_COUNT=$(find "$SRC_DIR" -name 'nextpas.core.tui.widget*.pas' | wc -l)
if [ "$WIDGET_COUNT" -gt 0 ]; then ok "Widget: $WIDGET_COUNT 文件"; else warn_check "Widget 子系统缺失"; fi

# Core widget interfaces
for w in "IWidget" "IBlock" "IParagraph"; do
  if grep -rql "\b$w\b" "$SRC_DIR"/nextpas.core.tui*.pas 2>/dev/null; then ok "Widget 基础: $w"; else warn_check "Widget 基础未发现: $w"; fi
done

printf "\n${BOLD}C5: 门面单元${NC}\n"
FACADE="$SRC_DIR/nextpas.core.tui.pas"
if [ -f "$FACADE" ]; then ok "门面文件存在"; else fail_check "tui.pas 门面缺失"; fi

printf "\n${BOLD}C6: 测试完备性${NC}\n"
TEST_COUNT=$(find "$TEST_DIR" -mindepth 1 -maxdepth 1 -type d -name 'test_*' -exec basename {} \; 2>/dev/null | wc -l)
if [ "$TEST_COUNT" -gt 0 ]; then ok "测试目录: $TEST_COUNT 个"; else warn_check "无 test_* 目录"; fi

printf "\n${BOLD}C7: Scorecard / CONTRACT 对齐${NC}\n"
SCORECARD="$REPO_ROOT/core/docs/tui/SCORECARD.md"
PARITY="$REPO_ROOT/core/docs/tui/PARITY-GO-RUST.md"
SC_LPR="$TEST_DIR/scorecard/scorecard.lpr"
if [ -f "$SCORECARD" ]; then
  if grep -q 'SC25' "$SCORECARD" && grep -q 'SC26' "$SCORECARD" && grep -q 'SC27' "$SCORECARD"; then
    ok "SCORECARD 含 SC25/SC26/SC27"
  else
    fail_check "SCORECARD 缺少 SC25/SC26/SC27 条目"
  fi
else
  fail_check "SCORECARD.md 不存在"
fi
if [ -f "$CONTRACT" ]; then
  if grep -qE 'SC1[–-]SC' "$CONTRACT" && grep -qE '\*\*版本\*\*：1\.(1[7-9]|[2-9][0-9])' "$CONTRACT"; then
    ok "CONTRACT 含 SC 范围与版本 ≥1.17"
  else
    fail_check "CONTRACT 缺少 SC1–SC 范围或版本过旧"
  fi
fi
if [ -f "$SC_LPR" ]; then
  for p in RunSC25 RunSC26 RunSC27; do
    if grep -q "procedure $p" "$SC_LPR"; then ok "scorecard.lpr $p"; else fail_check "scorecard.lpr 缺 $p"; fi
  done
else
  fail_check "scorecard.lpr 不存在"
fi
if [ -f "$PARITY" ] && grep -q '质量维度' "$PARITY"; then
  ok "PARITY 含质量维度矩阵"
else
  fail_check "PARITY 缺少质量维度"
fi
if [ -f "$PARITY" ] && grep -qi 'Maintenance' "$PARITY"; then
  ok "PARITY 标记 Maintenance"
else
  fail_check "PARITY 未进入 Maintenance 状态"
fi

printf "\n${BOLD}C8: core facade reject 编译失败${NC}\n"
FPC_BIN="${FPC:-/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc}"
REJECT_DIR="$TEST_DIR/test_tui_core_facade"
REJECT_BUILD="$REPO_ROOT/core/build/projects/nextpas.core.tui/reject_c8"
if [ ! -x "$FPC_BIN" ] && ! command -v "$FPC_BIN" >/dev/null 2>&1; then
  if command -v fpc >/dev/null 2>&1; then
    FPC_BIN=$(command -v fpc)
  else
    fail_check "找不到 fpc（设 FPC= 或安装）"
    FPC_BIN=""
  fi
fi
if [ -n "$FPC_BIN" ]; then
  mkdir -p "$REJECT_BUILD"
  for rej in test_tui_core_facade_rejects_scrollview test_tui_core_facade_rejects_modal \
             test_tui_core_facade_rejects_dialog test_tui_core_facade_rejects_split_pane \
             test_tui_core_facade_rejects_select; do
    src="$REJECT_DIR/${rej}.lpr"
    if [ ! -f "$src" ]; then
      fail_check "缺 reject 源: $rej.lpr"
      continue
    fi
    # Expect identifier not found / compile fail when using core facade only.
    if "$FPC_BIN" -MObjFPC -Sh -Sg -O1 \
        -FU"$REJECT_BUILD" -FE"$REJECT_BUILD" \
        -Fu"$REPO_ROOT/core/src" -Fi"$REPO_ROOT/core/src" \
        "$src" >/dev/null 2>&1; then
      fail_check "$rej 应编译失败却成功（core 泄漏？）"
    else
      ok "$rej 编译失败（预期）"
    fi
  done
fi

printf "\n${BOLD}═══════════════════════════════════${NC}\n"
printf "${GREEN}通过: %d${NC}  ${RED}失败: %d${NC}  ${YELLOW}警告: %d${NC}\n" "$pass" "$fail" "$warn"
if [ "$fail" -gt 0 ]; then printf "\n${RED}${BOLD}契约门禁: 失败${NC}\n"; exit 1
elif [ "$warn" -gt 0 ]; then printf "\n${YELLOW}${BOLD}契约门禁: 通过（有警告）${NC}\n"; exit 0
else printf "\n${GREEN}${BOLD}契约门禁: 全通过${NC}\n"; exit 0; fi
