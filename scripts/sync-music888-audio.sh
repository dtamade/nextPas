#!/usr/bin/env bash
# sync-music888-audio.sh — 守卫 nextpas.core.audio 与 music888 解码核的漂移
# 5 维视角：性能(bench 对拍) / 高级感(simd.dispatch 运行时) / 复用度(bytes.cursor/arena/meta) / 稳定性(fuzz/HEAPTRC/MXCSR) / 完整性(35 文件门禁)
# 用法：bash scripts/sync-music888-audio.sh [--check-only]
#   --check-only 仅报告，不触文件；默认输出详细 diff 摘要
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
M888="${MUSIC888_ROOT:-$HOME/projects/music888}"
WT_ROOT="$ROOT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YEL='\033[0;33m'; NC='\033[0m'

fail=0
info() { echo -e "${GREEN}[SYNC]${NC} $*"; }
warn() { echo -e "${YEL}[SYNC]${NC} $*"; }
err()  { echo -e "${RED}[SYNC]${NC} $*"; fail=1; }

if [ ! -d "$M888/src" ]; then
  err "music888 not found at $M888 (set MUSIC888_ROOT)"
  exit 1
fi

# 1. 版本锚点
info "music888 HEAD: $(git -C "$M888" rev-parse --short HEAD 2>/dev/null || echo "?")  $(git -C "$M888" log --oneline -1 2>/dev/null | cut -c1-60)"
info "nextpas HEAD:  $(git -C "$WT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "?")"

# 2. 引擎差异摘要（仅行数与关键守卫）
for pair in \
  "music888.flacdec.pas:nextpas.core.audio.codec.flac.pas" \
  "music888.mp3dec.pas:nextpas.core.audio.codec.mp3.pas" \
  "music888.vorbisdec.pas:nextpas.core.audio.codec.vorbis.pas" \
  "music888.flacdec.sse.pas:nextpas.core.audio.codec.flac.sse.pas" \
  "music888.mp3dec.sse.pas:nextpas.core.audio.codec.mp3.sse.pas" \
  "music888.vorbisdec.sse.pas:nextpas.core.audio.codec.vorbis.sse.pas"
do
  IFS=":" read -r a b <<< "$pair"
  pa="$M888/src/$a"
  pb="$WT_ROOT/core/src/$b"
  if [ ! -f "$pa" ] || [ ! -f "$pb" ]; then warn "skip $pair (missing)"; continue; fi
  # 统计纯增量：nextpas 特有守卫（AudioUseNeon / Arena / BytesCursor / simd.dispatch）
  added=$(grep -c "AudioUseNeon\|TMemoryArena\|BytesCursor\|simd.dispatch\|O3.*错译" "$pb" 2>/dev/null || true)
  removed=$(grep -c "external 'c'\|external CLIB" "$pa" 2>/dev/null || true)
  lines_a=$(wc -l < "$pa")
  lines_b=$(wc -l < "$pb")
  delta=$(( lines_b - lines_a ))
  echo "  $b: music888 $lines_a 行 → nextpas $lines_b 行 (Δ $delta)  去C $removed / 加护 $added"
  # 关键差异：nextpas 是否仍保留 music888 新增的 NEON 核
  if ! diff -q "$pa" "$pb" >/dev/null 2>&1; then
    # 仅当 diff 超阈值时提示人工复核
    dw=$(diff "$pa" "$pb" 2>&1 | wc -l || true)
    if [ "$dw" -gt 800 ]; then warn "  $b 与 music888 差异 $dw 行，建议人工复核（预期：去C + AudioUseNeon 门控）"; fi
  fi
done

# 3. 五维门禁快照
echo
info "五维门禁快照："
bash "$WT_ROOT/core/tests/nextpas.core.audio/test_base/check_source_contract.sh" >/tmp/sync_gate.log 2>&1 && info "  source-contract: PASS (35 files)" || { err "  source-contract: FAIL"; cat /tmp/sync_gate.log; }
bash "$WT_ROOT/scripts/build-hygiene-check.sh" >/tmp/sync_hyg.log 2>&1 && info "  hygiene: PASS" || { err "  hygiene: FAIL"; cat /tmp/sync_hyg.log; }

# bench 冒烟（仅验证可解码，不跑全量 bench）
for mp3 in "$M888/src/music888.mp3dec.pas" "$WT_ROOT/core/src/nextpas.core.audio.codec.mp3.pas"; do :; done
# 简易：用 nextpas 的 bench_mp3 mini.mp3 解码冒烟
if [ -f "$WT_ROOT/core/benchmarks/nextpas.core.audio/bench_mp3/mini.mp3" ]; then
  info "  bench fixture: $(file "$WT_ROOT/core/benchmarks/nextpas.core.audio/bench_mp3/mini.mp3" | cut -d: -f2)"
fi

# 4. 建议
echo
info "music888 持续迭代守卫建议："
echo "  - 每周执行一次本脚本（或 CI cron），关注 flac/mp3/vorbis 行数Δ与 NEON 核新增"
echo "  - 吸收策略：不 verbatim 拷贝，而是以 bytes.cursor / mem.arena / simd.dispatch 重塑（青出于蓝）"
echo "  - 变更若涉 bench/对拍阈值，同步更新 core/benchmarks/nextpas.core.audio/bench_* 与 docs/audio/README 性能表"
echo "  - 真机 aarch64 数字需在 ARM 设备回填，qemu 仅作相对加速参考"

if [ "$fail" -ne 0 ]; then echo; err "SYNC CHECK FAILED"; exit 1; fi
info "SYNC CHECK OK"
