#!/bin/bash
# rebuild-compiler.sh — 完整重编译编译器，避免 stale PPU 问题
#
# 关键教训（2026-06-01）：
# 1. FPC 的 PPU 缓存会让源码改动不生效。必须先删所有 .ppu/.o 再编译。
# 2. 散落在 rtl/units 目录的 .ppu 也会污染编译。一并清理。
# 3. np_base_types/np_text_primitives 在 rtl/core/ 下，unit 路径必须包含它们，
#    否则要么编译失败，要么用到 stale ppu。
# 4. 在独立 worktree 里也必须解析到当前 checkout，并且不能让 pipeline 吞掉编译失败。
set -euo pipefail

case "$0" in
  */*)
    SCRIPT_PATH="$0"
    ;;
  *)
    SCRIPT_PATH="./$0"
    ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "${SCRIPT_PATH%/*}" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
OUT="$ROOT/build/stage0-bootstrap"
mkdir -p "$OUT"

# 清除所有 PPU 缓存（stage0 输出目录 + rtl 源码目录的散落产物）
rm -f "$OUT"/*.ppu "$OUT"/*.o
rm -f "$ROOT"/rtl/core/base/*.ppu "$ROOT"/rtl/core/base/*.o
rm -f "$ROOT"/rtl/core/text/*.ppu "$ROOT"/rtl/core/text/*.o

# 完整重编译（显式指定所有 unit 路径，含 rtl/core）
fpc "$ROOT/tools/stage0/nextpas.pas" \
  -FE"$OUT" \
  -FU"$OUT" \
  -o"$OUT/nextpas" \
  -Fu"$ROOT/compiler/sema" \
  -Fu"$ROOT/compiler/frontend" \
  -Fu"$ROOT/compiler/ir" \
  -Fu"$ROOT/compiler/backend" \
  -Fu"$ROOT/compiler/diagnostics" \
  -Fu"$ROOT/compiler/syntax" \
  -Fu"$ROOT/compiler/toolchain" \
  -Fu"$ROOT/compiler/targets" \
  -Fu"$ROOT/rtl/core/base" \
  -Fu"$ROOT/rtl/core/text" \
  2>&1 | grep -E "compiled|Error|Fatal" | tail -3

echo "rebuild done — 确认上面是 'NNNNN lines compiled'（应 40000+），不是 '481 lines'"
