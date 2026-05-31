#!/bin/bash
# rebuild-compiler.sh — 完整重编译编译器，避免 stale PPU 问题
set -e

ROOT="/home/dtamade/projects/nextPas"
OUT="$ROOT/.sisyphus/tmp/stage0-bootstrap"

# 清除旧的 PPU 缓存
rm -f "$OUT"/np_*.ppu "$OUT"/np_*.o "$OUT"/nextpas_*.ppu "$OUT"/nextpas_*.o

# 完整重编译（显式指定所有 unit 路径）
fpc "$ROOT/tools/stage0/nextpas.pas" \
  -FE"$OUT" \
  -o"$OUT/nextpas" \
  -Fu"$ROOT/compiler/sema" \
  -Fu"$ROOT/compiler/frontend" \
  -Fu"$ROOT/compiler/ir" \
  -Fu"$ROOT/compiler/backend" \
  -Fu"$ROOT/compiler/diagnostics" \
  -Fu"$ROOT/compiler/syntax" \
  -Fu"$ROOT/compiler/toolchain" \
  -Fu"$ROOT/compiler/targets"

echo "OK: $(wc -l < /dev/stdin 2>/dev/null || echo 'done')"
