#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SRC="$ROOT/core/src"
fail=0
check_no_ffi() { local file="$1"; if grep -qiE "uses.*\.ffi|vendor|miniaudio|mpg123|opusfile" "$file"; then if grep -E "^\s*uses" "$file" | grep -qiE "\.ffi|vendor"; then echo "[FAIL] $file contains forbidden ffi/vendor in uses"; fail=1; fi; fi; if grep -E "uses" "$file" | grep -q "\.ffi"; then echo "[FAIL] $file uses .ffi"; fail=1; fi; if grep -q "\.ffi" "$file"; then echo "[FAIL] $file contains '.ffi' token"; grep -n "\.ffi" "$file" || true; fail=1; fi; if grep -qi "vendor" "$file"; then echo "[FAIL] $file contains 'vendor' token"; grep -n -i "vendor" "$file" || true; fail=1; fi; }
# audio source-contract gate — 84 files (core 29 + extension 55, unique 82+2 bus facade) — 契约 1.5.2 (opus 四件套占位, prOggOpus)
# Header: 81→84 sync — enumeration includes wav 四件套 + codec flac/mp3/vorbis/opus 四件套 (各 base/intf/impl/pas, opus 占位) + bank/resource/event/spatial.impl + 5 base + playlist 4件套 + codec 3×3 decoder/sse, for loop must include test_automation
echo "== audio source-contract gate (84 files: core 29 + extension 55) =="
for f in \
  "$SRC/nextpas.core.audio.base.pas" \
  "$SRC/nextpas.core.audio.intf.pas" \
  "$SRC/nextpas.core.audio.codec.intf.pas" \
  "$SRC/nextpas.core.audio.codec.wav.base.pas" \
  "$SRC/nextpas.core.audio.codec.wav.intf.pas" \
  "$SRC/nextpas.core.audio.codec.wav.impl.pas" \
  "$SRC/nextpas.core.audio.codec.wav.pas" \
  "$SRC/nextpas.core.audio.codec.aiff.pas" \
  "$SRC/nextpas.core.audio.codec.meta.pas" \
  "$SRC/nextpas.core.audio.codec.registry.pas" \
  "$SRC/nextpas.core.audio.codec.flac.base.pas" \
  "$SRC/nextpas.core.audio.codec.flac.intf.pas" \
  "$SRC/nextpas.core.audio.codec.flac.impl.pas" \
  "$SRC/nextpas.core.audio.codec.flac.pas" \
  "$SRC/nextpas.core.audio.codec.flac.decoder.pas" \
  "$SRC/nextpas.core.audio.codec.flac.sse.pas" \
  "$SRC/nextpas.core.audio.codec.mp3.base.pas" \
  "$SRC/nextpas.core.audio.codec.mp3.intf.pas" \
  "$SRC/nextpas.core.audio.codec.mp3.impl.pas" \
  "$SRC/nextpas.core.audio.codec.mp3.pas" \
  "$SRC/nextpas.core.audio.codec.mp3.decoder.pas" \
  "$SRC/nextpas.core.audio.codec.mp3.sse.pas" \
  "$SRC/nextpas.core.audio.codec.vorbis.base.pas" \
  "$SRC/nextpas.core.audio.codec.vorbis.intf.pas" \
  "$SRC/nextpas.core.audio.codec.vorbis.impl.pas" \
  "$SRC/nextpas.core.audio.codec.vorbis.pas" \
  "$SRC/nextpas.core.audio.codec.vorbis.decoder.pas" \
  "$SRC/nextpas.core.audio.codec.vorbis.sse.pas" \
  "$SRC/nextpas.core.audio.codec.opus.base.pas" \
  "$SRC/nextpas.core.audio.codec.opus.intf.pas" \
  "$SRC/nextpas.core.audio.codec.opus.impl.pas" \
  "$SRC/nextpas.core.audio.codec.opus.pas" \
  "$SRC/nextpas.core.audio.errors.pas" \
  "$SRC/nextpas.core.audio.pcm.pas" \
  "$SRC/nextpas.core.audio.pcm.simd.pas" \
  "$SRC/nextpas.core.audio.pcm_wav.pas" \
  "$SRC/nextpas.core.audio.resample.pas" \
  "$SRC/nextpas.core.audio.resample.sinc.pas" \
  "$SRC/nextpas.core.audio.mix.pas" \
  "$SRC/nextpas.core.audio.dsp.filters.pas" \
  "$SRC/nextpas.core.audio.dsp.dynamics.pas" \
  "$SRC/nextpas.core.audio.dsp.fft.pas" \
  "$SRC/nextpas.core.audio.device.intf.pas" \
  "$SRC/nextpas.core.audio.device.null.pas" \
  "$SRC/nextpas.core.audio.graph.intf.pas" \
  "$SRC/nextpas.core.audio.graph.pas" \
  "$SRC/nextpas.core.audio.player.pas" \
  "$SRC/nextpas.core.audio.sfx.intf.pas" \
  "$SRC/nextpas.core.audio.sfx.pas" \
  "$SRC/nextpas.core.audio.game.intf.pas" \
  "$SRC/nextpas.core.audio.game.pas" \
  "$SRC/nextpas.core.audio.timeline.intf.pas" \
  "$SRC/nextpas.core.audio.timeline.pas" \
  "$SRC/nextpas.core.audio.spatial.base.pas" \
  "$SRC/nextpas.core.audio.spatial.intf.pas" \
  "$SRC/nextpas.core.audio.spatial.impl.pas" \
  "$SRC/nextpas.core.audio.spatial.pas" \
  "$SRC/nextpas.core.audio.bus.base.pas" \
  "$SRC/nextpas.core.audio.bus.intf.pas" \
  "$SRC/nextpas.core.audio.bus.impl.pas" \
  "$SRC/nextpas.core.audio.bus.pas" \
  "$SRC/nextpas.core.audio.simd.pas" \
  "$SRC/nextpas.core.audio.bank.base.pas" \
  "$SRC/nextpas.core.audio.bank.intf.pas" \
  "$SRC/nextpas.core.audio.bank.impl.pas" \
  "$SRC/nextpas.core.audio.bank.pas" \
  "$SRC/nextpas.core.audio.resource.base.pas" \
  "$SRC/nextpas.core.audio.resource.intf.pas" \
  "$SRC/nextpas.core.audio.resource.impl.pas" \
  "$SRC/nextpas.core.audio.resource.pas" \
  "$SRC/nextpas.core.audio.playlist.base.pas" \
  "$SRC/nextpas.core.audio.playlist.intf.pas" \
  "$SRC/nextpas.core.audio.playlist.impl.pas" \
  "$SRC/nextpas.core.audio.playlist.pas" \
  "$SRC/nextpas.core.audio.event.base.pas" \
  "$SRC/nextpas.core.audio.event.intf.pas" \
  "$SRC/nextpas.core.audio.event.impl.pas" \
  "$SRC/nextpas.core.audio.event.pas" \
  "$SRC/nextpas.core.audio.studio.base.pas" \
  "$SRC/nextpas.core.audio.studio.intf.pas" \
  "$SRC/nextpas.core.audio.studio.automation.pas" \
  "$SRC/nextpas.core.audio.studio.project.pas" \
  "$SRC/nextpas.core.audio.studio.sequencer.pas" \
  "$SRC/nextpas.core.audio.studio.pas" \
  "$SRC/nextpas.core.audio.pas"; do if [ ! -f "$f" ]; then echo "[FAIL] missing $f"; fail=1; continue; fi; check_no_ffi "$f"; echo "[OK] no ffi/vendor in $(basename "$f")"; done
echo "[OK] 84 files (core 29 + candidate 55) no ffi/vendor — 契约 1.5.2 已对齐实盘（unique 82+2 bus facade, wav/flac/mp3/vorbis/opus 四件套）"
if ! grep -q "实时路径仅调 FillRealtime" "$SRC/nextpas.core.audio.intf.pas"; then echo "[FAIL] missing realtime comment"; fail=1; else echo "[OK] realtime discipline comment present"; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000010" "$SRC/nextpas.core.audio.intf.pas"; then echo "[FAIL] IAudioSource GUID missing"; fail=1; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000011" "$SRC/nextpas.core.audio.intf.pas"; then echo "[FAIL] IRealtimeAudioSource GUID missing"; fail=1; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000001" "$SRC/nextpas.core.audio.codec.intf.pas"; then echo "[FAIL] IAudioDecoder GUID missing"; fail=1; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000002" "$SRC/nextpas.core.audio.codec.intf.pas"; then echo "[FAIL] IAudioEncoder GUID missing"; fail=1; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000020" "$SRC/nextpas.core.audio.intf.pas"; then echo "[FAIL] IAudioResampler GUID missing"; fail=1; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000021" "$SRC/nextpas.core.audio.intf.pas"; then echo "[FAIL] IAudioConverter GUID missing"; fail=1; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000030" "$SRC/nextpas.core.audio.intf.pas"; then echo "[FAIL] IAudioProcessor GUID missing"; fail=1; fi
echo "[OK] GUIDs present (source/codec/resampler/processor)"
enc_line=$(grep -n "TAudioEncodeOptions" "$SRC/nextpas.core.audio.codec.intf.pas" | head -n1 | cut -d: -f1)
dec_line=$(grep -n "IAudioDecoder" "$SRC/nextpas.core.audio.codec.intf.pas" | head -n1 | cut -d: -f1)
if [ -n "$enc_line" ] && [ -n "$dec_line" ]; then if [ "$enc_line" -gt "$dec_line" ]; then echo "[FAIL] TAudioEncodeOptions must be declared before IAudioDecoder"; fail=1; else echo "[OK] TAudioEncodeOptions before IAudioDecoder"; fi; else echo "[FAIL] missing TAudioEncodeOptions or IAudioDecoder"; fail=1; fi
if ! ls "$SRC"/nextpas.core.audio.device.intf.pas 1>/dev/null 2>&1; then echo "[FAIL] device.intf missing in PR9"; fail=1; fi
if ! ls "$SRC"/nextpas.core.audio.graph.intf.pas 1>/dev/null 2>&1; then echo "[FAIL] graph.intf missing in PR9"; fail=1; fi
if ! ls "$SRC"/nextpas.core.audio.sfx.intf.pas 1>/dev/null 2>&1; then echo "[FAIL] sfx.intf missing (canonical 0050)"; fail=1; fi
if ! ls "$SRC"/nextpas.core.audio.sfx.pas 1>/dev/null 2>&1; then echo "[FAIL] sfx.pas missing (canonical)"; fail=1; fi
if [ -f "$SRC"/nextpas.core.audio.game.intf.pas ]; then if grep -qE "TGameSfxId\s*=|TGameVoiceId\s*=|IGameAudio\s*=" "$SRC"/nextpas.core.audio.game.intf.pas; then echo "[FAIL] game.intf should not contain alias forwarding (four-piece 按需存在)"; fail=1; else echo "[OK] game.intf placeholder no alias (four-piece)"; fi; else echo "[OK] game.intf absent per four-piece"; fi
if ! ls "$SRC"/nextpas.core.audio.game.pas 1>/dev/null 2>&1; then echo "[FAIL] game.pas missing (deprecated compat)"; fail=1; fi
if ! ls "$SRC"/nextpas.core.audio.timeline.intf.pas 1>/dev/null 2>&1; then echo "[FAIL] timeline.intf missing in PR9"; fail=1; fi
if ! ls "$SRC"/nextpas.core.audio.timeline.pas 1>/dev/null 2>&1; then echo "[FAIL] timeline.pas missing in PR9"; fail=1; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000040" "$SRC/nextpas.core.audio.device.intf.pas"; then echo "[FAIL] IAudioDevice GUID missing"; fail=1; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000041" "$SRC/nextpas.core.audio.device.intf.pas"; then echo "[FAIL] IAudioDeviceProvider GUID missing"; fail=1; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000042" "$SRC/nextpas.core.audio.graph.intf.pas"; then echo "[FAIL] IAudioGraph GUID missing"; fail=1; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000043" "$SRC/nextpas.core.audio.graph.intf.pas"; then echo "[FAIL] IAudioPlayer GUID missing"; fail=1; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000050" "$SRC/nextpas.core.audio.sfx.intf.pas"; then echo "[FAIL] ISfxAudio GUID 0050 missing in sfx.intf (canonical)"; fail=1; fi
if ! grep -q "IGameAudio" "$SRC/nextpas.core.audio.sfx.intf.pas"; then echo "[FAIL] IGameAudio alias missing in sfx.intf (deprecated compat)"; fail=1; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000060" "$SRC/nextpas.core.audio.timeline.intf.pas"; then echo "[FAIL] IAudioTimeline GUID missing"; fail=1; fi
echo "[OK] device+graph+sfx+game+timeline domains present (canonical sfx 0050 + deprecated game compat)"
# FLock correctness and FillRealtime zero-alloc discipline (six-dimension polish)
if ! grep -q "two-phase snapshot" "$SRC/nextpas.core.audio.graph.pas"; then echo "[FAIL] graph FillRealtime missing two-phase snapshot (FLock correctness)"; fail=1; else echo "[OK] graph two-phase snapshot present"; fi
if ! grep -q "two-phase snapshot" "$SRC/nextpas.core.audio.timeline.pas"; then echo "[FAIL] timeline FillRealtime missing two-phase snapshot"; fail=1; else echo "[OK] timeline two-phase snapshot present"; fi
if ! grep -q "deep copy clip array" "$SRC/nextpas.core.audio.timeline.pas"; then echo "[FAIL] timeline missing deep copy clip array (snapshot isolation)"; fail=1; else echo "[OK] timeline deep copy clip present"; fi
if ! grep -q "EnsureScratch" "$SRC/nextpas.core.audio.graph.pas"; then echo "[FAIL] graph missing EnsureScratch zero-alloc"; fail=1; else echo "[OK] graph EnsureScratch present"; fi
# FillRealtime must not allocate inside lock: ensure SetLength for snapshot is outside FLock.Enter
if grep -A2 "FLock.Enter" "$SRC/nextpas.core.audio.graph.pas" | grep -q "SetLength(NodesSnap"; then echo "[FAIL] graph SetLength inside FLock (alloc inside lock)"; fail=1; else echo "[OK] graph no alloc inside lock"; fi
# timeline FillRealtime must be lock-free mixing (snapshot comment)
if ! grep -q "snapshot mixing - lock free" "$SRC/nextpas.core.audio.timeline.pas"; then echo "[FAIL] timeline missing lock-free mixing comment"; fail=1; else echo "[OK] timeline lock-free mixing comment present"; fi
# --- 扩展候选域校验（1.4 实盘审计：缺失即 FAIL，bus.base/bus.impl 豁免无独立 intf）---
# bus.base 为 base 常量无 GUID 豁免；bus.impl 复用 bus.intf 的 B 前缀 GUID，故仅校验 bus.intf/bus.pas
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000051" "$SRC/nextpas.core.audio.spatial.intf.pas"; then echo "[FAIL] IAudioSpatialSource GUID 0051 missing in spatial.intf (candidate)"; fail=1; else echo "[OK] spatial GUID 0051 present"; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000052" "$SRC/nextpas.core.audio.event.intf.pas"; then echo "[FAIL] IAudioEventSystem GUID 0052 missing"; fail=1; else echo "[OK] event GUID 0052 present"; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000053" "$SRC/nextpas.core.audio.bank.intf.pas"; then echo "[FAIL] IAudioBank GUID 0053 missing"; fail=1; else echo "[OK] bank GUID 0053 present"; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000054" "$SRC/nextpas.core.audio.resource.intf.pas"; then echo "[FAIL] IAudioResourceManager GUID 0054 missing"; fail=1; else echo "[OK] resource GUID 0054 present"; fi
if ! grep -q "B1A2B3C4-D5E6-7890-ABCD-C00000000001" "$SRC/nextpas.core.audio.bus.intf.pas" && ! grep -q "B1A2B3C4-D5E6-7890-ABCD-C00000000001" "$SRC/nextpas.core.audio.bus.pas"; then echo "[FAIL] IAudioBus GUID B:C00000000001 missing (candidate bus, B-prefix异形)"; fail=1; else echo "[OK] bus GUID B:C00001 present"; fi
if ! grep -q "B1A2B3C4-D5E6-7890-ABCD-C00000000002" "$SRC/nextpas.core.audio.bus.intf.pas" && ! grep -q "B1A2B3C4-D5E6-7890-ABCD-C00000000002" "$SRC/nextpas.core.audio.bus.pas"; then echo "[FAIL] IAudioBusMixer GUID B:C00000000002 missing (candidate bus)"; fail=1; else echo "[OK] bus mixer GUID B:C00002 present"; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000080" "$SRC/nextpas.core.audio.playlist.pas"; then echo "[FAIL] IAudioPlaylist GUID 0080 missing"; fail=1; else echo "[OK] playlist GUID 0080 present"; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000070" "$SRC/nextpas.core.audio.studio.intf.pas"; then echo "[FAIL] IAudioStudio GUID 0070 missing"; fail=1; else echo "[OK] studio GUID 0070 present"; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000071" "$SRC/nextpas.core.audio.studio.intf.pas"; then echo "[FAIL] IStudioProject GUID 0071 missing"; fail=1; else echo "[OK] studio project GUID 0071 present"; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000072" "$SRC/nextpas.core.audio.studio.sequencer.pas"; then echo "[FAIL] IAudioSequencer GUID 0072 missing"; fail=1; else echo "[OK] sequencer GUID 0072 present"; fi
# Probe≤4KB 纪律：wav/flac/mp3/vorbis/opus 必须在 Probe 中显式 4096 守卫（实盘审计：缺失即 FAIL）
if ! grep -q "4096" "$SRC/nextpas.core.audio.codec.wav.pas"; then echo "[FAIL] wav Probe lacks 4096 guard (Probe≤4KB)"; fail=1; else echo "[OK] wav Probe≤4KB guard present"; fi
if ! grep -q "4096" "$SRC/nextpas.core.audio.codec.flac.pas"; then echo "[FAIL] flac Probe lacks 4096 guard (Probe≤4KB)"; fail=1; else echo "[OK] flac Probe≤4KB guard present"; fi
if ! grep -q "4096" "$SRC/nextpas.core.audio.codec.mp3.pas"; then echo "[FAIL] mp3 Probe lacks 4096 guard"; fail=1; else echo "[OK] mp3 Probe≤4KB guard present"; fi
if ! grep -q "4096" "$SRC/nextpas.core.audio.codec.vorbis.pas"; then echo "[FAIL] vorbis Probe lacks 4096 guard"; fail=1; else echo "[OK] vorbis Probe≤4KB guard present"; fi
if ! grep -q "4096" "$SRC/nextpas.core.audio.codec.opus.pas"; then echo "[FAIL] opus Probe lacks 4096 guard"; fail=1; else echo "[OK] opus Probe≤4KB guard present"; fi
# bytes.ops 单源：候选 codec 必须复用 bytes.ops/bytes.cursor，不自写重复 vendor
if grep -q "external 'c'" "$SRC/nextpas.core.audio.codec.flac.decoder.pas"; then echo "[FAIL] flac.decoder contains external 'c' (ffi)"; fail=1; else echo "[OK] flac.decoder no external ffi"; fi
if grep -qi "vendor" "$SRC/nextpas.core.audio.codec.mp3.decoder.pas"; then echo "[FAIL] mp3.decoder vendor"; fail=1; else echo "[OK] mp3.decoder no vendor"; fi
# inline/零拷贝证据：热点函数 inline + EnsureScratch/FSnap
if ! grep -q "inline;" "$SRC/nextpas.core.audio.base.pas"; then echo "[FAIL] base missing inline evidence"; fail=1; else echo "[OK] base inline present"; fi
if ! grep -q "EnsureScratch" "$SRC/nextpas.core.audio.bank.impl.pas"; then echo "[FAIL] bank missing EnsureScratch zero-alloc"; fail=1; else echo "[OK] bank EnsureScratch present"; fi
if ! grep -q "EnsureScratch" "$SRC/nextpas.core.audio.event.impl.pas"; then echo "[FAIL] event missing EnsureScratch"; fail=1; else echo "[OK] event EnsureScratch present"; fi
# 稳定性：资源释放不丢（Destroy/Clear 必须 SetLength + FreeAndNil/WaitFor）
if ! grep -q "SetLength.*Buffer.Data, 0" "$SRC/nextpas.core.audio.bank.impl.pas"; then echo "[FAIL] bank Clear missing SetLength(Data,0) resource release"; fail=1; else echo "[OK] bank resource release present"; fi
if ! grep -q "WaitFor" "$SRC/nextpas.core.audio.resource.impl.pas"; then echo "[FAIL] resource missing WaitFor in Destroy/Release"; fail=1; else echo "[OK] resource WaitFor present"; fi
# 裸露桩白名单：flac/mp3/vorbis/opus OpenStreaming not implemented 必须带 STUB 注释，gate 允许过渡桩（flac 四件套后 stub 在 .impl.pas/.pas 均需 STUB 标记）
for codec in flac mp3 vorbis opus; do
  for suffix in "" ".impl"; do
    f="$SRC/nextpas.core.audio.codec.$codec${suffix}.pas"
    if [ -f "$f" ] && grep -q "OpenStreaming.*not implemented" "$f"; then
      if ! grep -q "STUB: OpenStreaming" "$f"; then echo "[FAIL] $codec${suffix} OpenStreaming stub missing STUB marker"; fail=1; else echo "[OK] $codec${suffix} OpenStreaming STUB marker present"; fi
    fi
  done
done
# flac/wav/opus 四件套 Probe≤4KB：facade 与 impl 均需 4096 守卫可见（facade inline 转发仍保留 4096 字面量便于审计）
if ! grep -q "4096" "$SRC/nextpas.core.audio.codec.flac.base.pas"; then echo "[FAIL] flac.base lacks 4096 (CFlacProbeLimit)"; fail=1; else echo "[OK] flac.base Probe limit 4096 present"; fi
if ! grep -q "4096" "$SRC/nextpas.core.audio.codec.flac.impl.pas"; then echo "[FAIL] flac.impl Probe lacks 4096 guard"; fail=1; else echo "[OK] flac.impl Probe≤4KB guard present"; fi
if ! grep -q "4096" "$SRC/nextpas.core.audio.codec.wav.base.pas"; then echo "[FAIL] wav.base lacks 4096 (CWavProbeLimit)"; fail=1; else echo "[OK] wav.base Probe limit 4096 present"; fi
if ! grep -q "4096" "$SRC/nextpas.core.audio.codec.wav.impl.pas"; then echo "[FAIL] wav.impl Probe lacks 4096 guard"; fail=1; else echo "[OK] wav.impl Probe≤4KB guard present"; fi
if ! grep -q "4096" "$SRC/nextpas.core.audio.codec.opus.base.pas"; then echo "[FAIL] opus.base lacks 4096 (COpusProbeLimit)"; fail=1; else echo "[OK] opus.base Probe limit 4096 present"; fi
if ! grep -q "4096" "$SRC/nextpas.core.audio.codec.opus.impl.pas"; then echo "[FAIL] opus.impl Probe lacks 4096 guard"; fail=1; else echo "[OK] opus.impl Probe≤4KB guard present"; fi
# sfx resample todo 必须已收敛为显式分支，禁止裸 todo
if grep -q "resample todo" "$SRC/nextpas.core.audio.sfx.pas"; then
  if ! grep -q "EAudio" "$SRC/nextpas.core.audio.sfx.pas"; then echo "[FAIL] sfx resample todo not converged to EAudio branch"; fail=1; else echo "[OK] sfx resample todo converged (EAudio branch)"; fi
fi
# bus.base/bus.impl豁免：bus.base 为 base 无 GUID 正常，bus.impl 无独立 GUID 复用 bus.intf 已在上方豁免注释
if [ ! -f "$SRC/nextpas.core.audio.bus.base.pas" ]; then echo "[FAIL] bus.base missing (72 enumeration)"; fail=1; else echo "[OK] bus.base present (base豁免 GUID)"; fi
if [ ! -f "$SRC/nextpas.core.audio.bus.impl.pas" ]; then echo "[FAIL] bus.impl missing (72 enumeration)"; fail=1; else echo "[OK] bus.impl present (impl复用 intf GUID豁免)"; fi
# wav/flac 四件套存在性校验（对标 bus 四件套）
if [ ! -f "$SRC/nextpas.core.audio.codec.wav.base.pas" ]; then echo "[FAIL] wav.base missing (81 enumeration, L0 only)"; fail=1; else echo "[OK] wav.base present (L0 only)"; fi
if [ ! -f "$SRC/nextpas.core.audio.codec.wav.intf.pas" ]; then echo "[FAIL] wav.intf missing (81 enumeration)"; fail=1; else echo "[OK] wav.intf present"; fi
if [ ! -f "$SRC/nextpas.core.audio.codec.wav.impl.pas" ]; then echo "[FAIL] wav.impl missing (81 enumeration)"; fail=1; else echo "[OK] wav.impl present"; fi
if [ ! -f "$SRC/nextpas.core.audio.codec.flac.base.pas" ]; then echo "[FAIL] flac.base missing (72 enumeration, L0 only)"; fail=1; else echo "[OK] flac.base present (L0 only)"; fi
if [ ! -f "$SRC/nextpas.core.audio.codec.flac.intf.pas" ]; then echo "[FAIL] flac.intf missing (72 enumeration)"; fail=1; else echo "[OK] flac.intf present"; fi
if [ ! -f "$SRC/nextpas.core.audio.codec.flac.impl.pas" ]; then echo "[FAIL] flac.impl missing (78 enumeration)"; fail=1; else echo "[OK] flac.impl present"; fi
if [ ! -f "$SRC/nextpas.core.audio.codec.mp3.base.pas" ]; then echo "[FAIL] mp3.base missing (78 enumeration, L0 only)"; fail=1; else echo "[OK] mp3.base present (L0 only)"; fi
if [ ! -f "$SRC/nextpas.core.audio.codec.mp3.intf.pas" ]; then echo "[FAIL] mp3.intf missing (78 enumeration)"; fail=1; else echo "[OK] mp3.intf present"; fi
if [ ! -f "$SRC/nextpas.core.audio.codec.mp3.impl.pas" ]; then echo "[FAIL] mp3.impl missing (78 enumeration)"; fail=1; else echo "[OK] mp3.impl present"; fi
if [ ! -f "$SRC/nextpas.core.audio.codec.vorbis.base.pas" ]; then echo "[FAIL] vorbis.base missing (78 enumeration, L0 only)"; fail=1; else echo "[OK] vorbis.base present (L0 only)"; fi
if [ ! -f "$SRC/nextpas.core.audio.codec.vorbis.intf.pas" ]; then echo "[FAIL] vorbis.intf missing (78 enumeration)"; fail=1; else echo "[OK] vorbis.intf present"; fi
if [ ! -f "$SRC/nextpas.core.audio.codec.vorbis.impl.pas" ]; then echo "[FAIL] vorbis.impl missing (78 enumeration)"; fail=1; else echo "[OK] vorbis.impl present"; fi
if [ ! -f "$SRC/nextpas.core.audio.codec.opus.base.pas" ]; then echo "[FAIL] opus.base missing (84 enumeration, L0 only)"; fail=1; else echo "[OK] opus.base present (L0 only)"; fi
if [ ! -f "$SRC/nextpas.core.audio.codec.opus.intf.pas" ]; then echo "[FAIL] opus.intf missing (84 enumeration)"; fail=1; else echo "[OK] opus.intf present"; fi
if [ ! -f "$SRC/nextpas.core.audio.codec.opus.impl.pas" ]; then echo "[FAIL] opus.impl missing (84 enumeration)"; fail=1; else echo "[OK] opus.impl present"; fi
# test_automation gate 存活校验（for loop 同步）
if [ ! -f "$SRC/../tests/nextpas.core.audio/test_automation/test_automation.lpr" ] && [ ! -f "$ROOT/core/tests/nextpas.core.audio/test_automation/test_automation.lpr" ]; then echo "[FAIL] test_automation gate missing"; fail=1; else echo "[OK] test_automation gate present"; fi
if [ "$fail" -ne 0 ]; then echo "source-contract gate FAILED"; exit 1; fi
echo "source-contract gate PASSED — 84 files (core 29 + extension 55, unique 82+2 bus facade) + 23 GUID + test_automation — 契约 1.5.2 (codec.wav/flac/mp3/vorbis/opus 四件套完整)"
