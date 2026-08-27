#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SRC="$ROOT/core/src"

fail=0

check_no_ffi() {
  local file="$1"
  if grep -qiE "uses.*\.ffi|vendor|miniaudio|mpg123|opusfile" "$file"; then
    # allow comment lines containing "ffi" word but not uses clause; stricter: grep uses line
    if grep -E "^\s*uses" "$file" | grep -qiE "\.ffi|vendor"; then
      echo "[FAIL] $file contains forbidden ffi/vendor in uses"
      fail=1
    fi
  fi
  # direct check for external ffi pattern in uses
  if grep -E "uses" "$file" | grep -q "\.ffi"; then
    echo "[FAIL] $file uses .ffi"
    fail=1
  fi
  if grep -qi "vendor" "$file" | grep -qi "uses"; then
    true
  fi
  # brute: any occurrence of ".ffi" in file should not be in intf/base
  if grep -q "\.ffi" "$file"; then
    echo "[FAIL] $file contains '.ffi' token (forbidden in base/intf)"
    grep -n "\.ffi" "$file" || true
    fail=1
  fi
  if grep -qi "vendor" "$file"; then
    echo "[FAIL] $file contains 'vendor' token (forbidden in base/intf)"
    grep -n -i "vendor" "$file" || true
    fail=1
  fi
}

echo "== audio source-contract gate =="

for f in \
  "$SRC/nextpas.core.audio.base.pas" \
  "$SRC/nextpas.core.audio.intf.pas" \
  "$SRC/nextpas.core.audio.codec.intf.pas" \
  "$SRC/nextpas.core.audio.errors.pas" \
  "$SRC/nextpas.core.audio.pcm.pas" \
  "$SRC/nextpas.core.audio.codec.aiff.pas" \
  "$SRC/nextpas.core.audio.codec.meta.pas" \
  "$SRC/nextpas.core.audio.codec.registry.pas"
do
  if [ ! -f "$f" ]; then
    echo "[FAIL] missing $f"
    fail=1
    continue
  fi
  # base/intf must not contain ffi/vendor; pcm/errors also should not
  check_no_ffi "$f"
  echo "[OK] no ffi/vendor in $(basename "$f")"
done

# shared plane must contain realtime discipline comment
if ! grep -q "实时路径仅调 FillRealtime" "$SRC/nextpas.core.audio.intf.pas"; then
  echo "[FAIL] nextpas.core.audio.intf.pas missing '实时路径仅调 FillRealtime' comment"
  fail=1
else
  echo "[OK] realtime discipline comment present"
fi

# ensure GUIDs are present in intf units
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000010" "$SRC/nextpas.core.audio.intf.pas"; then
  echo "[FAIL] IAudioSource GUID missing"
  fail=1
fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000011" "$SRC/nextpas.core.audio.intf.pas"; then
  echo "[FAIL] IRealtimeAudioSource GUID missing"
  fail=1
fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000001" "$SRC/nextpas.core.audio.codec.intf.pas"; then
  echo "[FAIL] IAudioDecoder GUID missing"
  fail=1
fi
if ! grep -q "F1A2B3C4-D5E6-7890-ABCD-A00000000002" "$SRC/nextpas.core.audio.codec.intf.pas"; then
  echo "[FAIL] IAudioEncoder GUID missing"
  fail=1
fi
echo "[OK] GUIDs present"

# ensure codec.intf declares TAudioEncodeOptions before IAudioDecoder
# crude: line number of TAudioEncodeOptions < IAudioDecoder
enc_line=$(grep -n "TAudioEncodeOptions" "$SRC/nextpas.core.audio.codec.intf.pas" | head -n1 | cut -d: -f1)
dec_line=$(grep -n "IAudioDecoder" "$SRC/nextpas.core.audio.codec.intf.pas" | head -n1 | cut -d: -f1)
if [ -n "$enc_line" ] && [ -n "$dec_line" ]; then
  if [ "$enc_line" -gt "$dec_line" ]; then
    echo "[FAIL] TAudioEncodeOptions must be declared before IAudioDecoder (lines $enc_line > $dec_line)"
    fail=1
  else
    echo "[OK] TAudioEncodeOptions before IAudioDecoder"
  fi
else
  echo "[FAIL] missing TAudioEncodeOptions or IAudioDecoder"
  fail=1
fi

# ensure no device/graph/timeline intf exists in PR3 (still draft)
if ls "$SRC"/nextpas.core.audio.device.* 1>/dev/null 2>&1; then
  echo "[FAIL] device intf should not exist in PR1"
  fail=1
fi
if ls "$SRC"/nextpas.core.audio.graph.* 1>/dev/null 2>&1; then
  echo "[FAIL] graph intf should not exist in PR1"
  fail=1
fi
if ls "$SRC"/nextpas.core.audio.timeline.* 1>/dev/null 2>&1; then
  echo "[FAIL] timeline intf should not exist in PR1"
  fail=1
fi
echo "[OK] no device/graph/timeline units (PR3 scope)"

if [ "$fail" -ne 0 ]; then
  echo "source-contract gate FAILED"
  exit 1
fi
echo "source-contract gate PASSED"
