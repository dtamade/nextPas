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
  if grep -q 'SC25' "$SCORECARD" && grep -q 'SC26' "$SCORECARD" && grep -q 'SC27' "$SCORECARD" && grep -q 'SC28' "$SCORECARD" && grep -q 'SC29' "$SCORECARD" && grep -q 'SC30' "$SCORECARD"; then
    ok "SCORECARD 含 SC25–SC30"
  else
    fail_check "SCORECARD 缺少 SC25–SC30 条目"
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
  for p in RunSC25 RunSC26 RunSC27 RunSC28 RunSC29 RunSC30; do
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
             test_tui_core_facade_rejects_select test_tui_core_facade_rejects_breadcrumb \
             test_tui_core_facade_rejects_timeline test_tui_core_facade_rejects_kanban \
             test_tui_core_facade_rejects_markdown test_tui_core_facade_rejects_tooltip \
             test_tui_core_facade_rejects_toast test_tui_core_facade_rejects_barchart \
             test_tui_core_facade_rejects_linechart test_tui_core_facade_rejects_calendar \
             test_tui_core_facade_rejects_tree test_tui_core_facade_rejects_file_tree \
             test_tui_core_facade_rejects_diffview test_tui_core_facade_rejects_input_editor \
             test_tui_core_facade_rejects_command_palette test_tui_core_facade_rejects_notification_center \
             test_tui_core_facade_rejects_popover test_tui_core_facade_rejects_menu; do
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

printf "\n${BOLD}C9: Wine pure-path suite 存在${NC}\n"
for wine in test_tui_buffer_wine test_tui_color_wine test_tui_input_wine; do
  if [ -d "$TEST_DIR/$wine" ] && ls "$TEST_DIR/$wine"/*.lpr >/dev/null 2>&1; then
    ok "$wine suite 存在"
  else
    fail_check "缺 wine suite: $wine"
  fi
done

printf "\n${BOLD}C10: examples facade 纪律（新代码优先 ext）${NC}\n"
EX_DIR="$REPO_ROOT/core/examples/nextpas.core.tui"
if [ -d "$EX_DIR" ]; then
  for demo in "$EX_DIR"/demo_*/; do
    [ -d "$demo" ] || continue
    name=$(basename "$demo")
    src=$(ls "$demo"/*.lpr 2>/dev/null | head -1)
    if [ -z "$src" ]; then
      fail_check "demo $name 无 .lpr"
      continue
    fi
    if [ "$name" = "demo_widgets" ]; then
      if grep -q 'nextpas\.core\.tui\.full' "$src"; then
        ok "$name 使用 full（高级 catalog 例外）"
      else
        fail_check "$name 应 uses full"
      fi
    else
      if grep -q 'nextpas\.core\.tui\.ext' "$src" && ! grep -q 'nextpas\.core\.tui\.full' "$src"; then
        ok "$name 使用 ext 且无 full"
      else
        fail_check "$name 须 uses ext 且不得 full"
      fi
    fi
  done
  if grep -qiE 'migration-only|新代码优先|不要默认.*full' "$REPO_ROOT/core/docs/tui/README.md"; then
    ok "README 含 full 迁移纪律"
  else
    fail_check "README 缺少 full migration 纪律表述"
  fi
else
  fail_check "examples 目录缺失"
fi

printf "\n${BOLD}C11: 线程前置契约（链接 tui.task 闭包必须 uses thread.init）${NC}\n"
# tui.task 的传递引用者: ext/full/app/app.screen/loading。链接即拉入 cthreads
# fail-fast 门卫: 缺 thread.init 首位 → 启动 runerror 211（而非随机 segfault）。
TASK_CLOSURE='^[[:space:]]*nextpas\.core\.tui\.(ext|full|app|app\.screen|task|loading)[[:space:]]*[,;]'
c11_missing=0; c11_ok=0
for src in "$EX_DIR"/*/*.lpr \
           "$TEST_DIR"/*/*.lpr \
           "$REPO_ROOT"/core/benchmarks/nextpas.core.tui/*/*.lpr; do
  [ -f "$src" ] || continue
  case "$src" in *rejects_*) continue;; esac   # reject 用例只编译不运行
  if grep -qE "$TASK_CLOSURE" "$src"; then
    # 仅存在不够: 非首位仍启动 211(前面单元的 initialization 已触碰线程 API)
    first_unit=$(awk '
      /^[[:space:]]*uses/ { f=1; line=$0; sub(/^[[:space:]]*uses/,"",line)
        if (line ~ /[A-Za-z]/) { print line; exit }; next }
      f { sub(/\{[^}]*\}/,""); if ($0 ~ /[A-Za-z]/) { print; exit } }' "$src")
    if printf '%s' "$first_unit" | grep -q 'nextpas\.core\.thread\.init'; then
      c11_ok=$((c11_ok + 1))
    elif grep -q 'nextpas\.core\.thread\.init' "$src"; then
      fail_check "$(basename "$src") thread.init 非 uses 首位（实测仍启动 runerror 211）"
      c11_missing=1
    else
      fail_check "$(basename "$src") 链接 tui.task 闭包但缺 nextpas.core.thread.init（启动即 runerror 211）"
      c11_missing=1
    fi
  fi
done
[ "$c11_missing" -eq 0 ] && ok "task 闭包程序 $c11_ok 个全部 uses thread.init"
if grep -q 'nextpas\.core\.thread\.init' "$SRC_DIR/nextpas.core.tui.task.pas"; then
  ok "tui.task 内置 fail-fast 门卫（implementation uses thread.init）"
else
  fail_check "tui.task 缺 fail-fast 门卫"
fi
if grep -q '线程前置契约' "$REPO_ROOT/core/docs/tui/CONTRACT.md"; then
  ok "CONTRACT.md 记载线程前置契约"
else
  fail_check "CONTRACT.md 缺线程前置契约条目"
fi

printf "\n${BOLD}═══════════════════════════════════${NC}\n"
printf "${GREEN}通过: %d${NC}  ${RED}失败: %d${NC}  ${YELLOW}警告: %d${NC}\n" "$pass" "$fail" "$warn"
if [ "$fail" -gt 0 ]; then printf "\n${RED}${BOLD}契约门禁: 失败${NC}\n"; exit 1
elif [ "$warn" -gt 0 ]; then printf "\n${YELLOW}${BOLD}契约门禁: 通过（有警告）${NC}\n"; exit 0
else printf "\n${GREEN}${BOLD}契约门禁: 全通过${NC}\n"; exit 0; fi
