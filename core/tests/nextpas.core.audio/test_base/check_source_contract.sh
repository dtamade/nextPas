#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SRC="$ROOT/core/src"
fail=0
check_no_ffi() { local file="$1"; if grep -qiE "uses.*\.ffi|vendor|miniaudio|mpg123|opusfile" "$file"; then if grep -E "^\s*uses" "$file" | grep -qiE "\.ffi|vendor"; then echo "[FAIL] $file contains forbidden ffi/vendor in uses"; fail=1; fi; fi; if grep -E "uses" "$file" | grep -q "\.ffi"; then echo "[FAIL] $file uses .ffi"; fail=1; fi; if grep -q "\.ffi" "$file"; then echo "[FAIL] $file contains '.ffi' token"; grep -n "\.ffi" "$file" || true; fail=1; fi; if grep -qi "vendor" "$file"; then echo "[FAIL] $file contains 'vendor' token"; grep -n -i "vendor" "$file" || true; fail=1; fi; }
echo "== audio source-contract gate =="
for f in \
  "$SRC/nextpas.core.audio.base.pas" \
  "$SRC/nextpas.core.audio.intf.pas" \
  "$SRC/nextpas.core.audio.codec.intf.pas" \
  "$SRC/nextpas.core.audio.codec.wav.pas" \
  "$SRC/nextpas.core.audio.errors.pas" \
  "$SRC/nextpas.core.audio.pcm.pas" \
  "$SRC/nextpas.core.audio.pcm_wav.pas" \
  "$SRC/nextpas.core.audio.codec.aiff.pas" \
  "$SRC/nextpas.core.audio.codec.meta.pas" \
  "$SRC/nextpas.core.audio.codec.registry.pas" \
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
  "$SRC/nextpas.core.audio.pas"; do if [ ! -f "$f" ]; then echo "[FAIL] missing $f"; fail=1; continue; fi; check_no_ffi "$f"; echo "[OK] no ffi/vendor in $(basename "$f")"; done
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
if ! ls "$SRC"/nextpas.core.audio.game.intf.pas 1>/dev/null 2>&1; then echo "[FAIL] game.intf missing (deprecated compat)"; fail=1; fi
if ! ls "$SRC"/nextpas.core.audio.game.pas 1>/dev/null 2>&1; then echo "[FAIL] game.pas missing (deprecated compat)"; fail=1; fi
if ! ls "$SRC"/nextpas.core.audio.timeline.intf.pas 1>/dev/null 2>&1; then echo "[FAIL] timeline.intf missing in PR9"; fail=1; fi
if ! ls "$SRC"/nextpas.core.audio.timeline.pas 1>/dev/null 2>&1; then echo "[FAIL] timeline.pas missing in PR9"; fail=1; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000040" "$SRC/nextpas.core.audio.device.intf.pas"; then echo "[FAIL] IAudioDevice GUID missing"; fail=1; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000041" "$SRC/nextpas.core.audio.device.intf.pas"; then echo "[FAIL] IAudioDeviceProvider GUID missing"; fail=1; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000042" "$SRC/nextpas.core.audio.graph.intf.pas"; then echo "[FAIL] IAudioGraph GUID missing"; fail=1; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000043" "$SRC/nextpas.core.audio.graph.intf.pas"; then echo "[FAIL] IAudioPlayer GUID missing"; fail=1; fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000050" "$SRC/nextpas.core.audio.sfx.intf.pas"; then echo "[FAIL] ISfxAudio GUID 0050 missing in sfx.intf (canonical)"; fail=1; fi
if ! grep -q "IGameAudio" "$SRC/nextpas.core.audio.game.intf.pas"; then echo "[FAIL] IGameAudio alias missing in game.intf (deprecated compat)"; fail=1; fi
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
if [ "$fail" -ne 0 ]; then echo "source-contract gate FAILED"; exit 1; fi
echo "source-contract gate PASSED"
