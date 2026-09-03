#!/usr/bin/env bash
# image 888 命名守卫 — 禁 pure 回退，dispatch 6 格式注册不变，门面 888 恒定
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SRC="$ROOT/core/src"
FAIL=0

echo "[guard] check .pure not in graphics/image domain"
# only graphics/image pure is banned; js.*.pure and zlib.pure are whitelisted via design-conventions exceptions
# scan nextpas.core.graphics.* and nextpas.core.image.* for .pure token
if grep -r "\.pure" "$SRC" --include="*.pas" | grep -E "nextpas\.core\.(graphics|image)\." | grep -v "nextpas\.core\.js\." | grep -v "zlib\.pure" >/tmp/pure_hits.txt 2>/dev/null; then
  if [ -s /tmp/pure_hits.txt ]; then
    echo "FAIL: found .pure in graphics/image:"
    cat /tmp/pure_hits.txt
    FAIL=1
  fi
fi
# also forbid image.gif legacy unit
if grep -rq "nextpas\.core\.image\.gif" "$SRC" --include="*.pas"; then
  echo "FAIL: legacy nextpas.core.image.gif found (must be graphics.gif.gif888)"
  grep -rn "nextpas\.core\.image\.gif" "$SRC" --include="*.pas"
  FAIL=1
fi

echo "[guard] check image.pas still graphics.gif/jpeg/webp/qoi.888"
IMG="$SRC/nextpas.core.image.pas"
for U in "nextpas.core.graphics.gif.gif888" "nextpas.core.graphics.jpeg.jpeg888" "nextpas.core.graphics.webp.webp888" "nextpas.core.graphics.qoi.qoi888"; do
  if ! grep -q "$U" "$IMG"; then
    echo "FAIL: $IMG missing $U"
    FAIL=1
  fi
done

echo "[guard] check dispatch 6 formats"
DISP="$SRC/nextpas.core.image.dispatch.pas"
# count ImageRegisterCodec calls in individual format units (png/bmp/jpeg/webp/gif/qoi) — must be 6
CNT=$(grep -r "ImageRegisterCodec(if" "$SRC" --include="*.pas" | wc -l)
if [ "$CNT" -ne 6 ]; then
  echo "FAIL: expected 6 ImageRegisterCodec registrations, got $CNT"
  grep -rn "ImageRegisterCodec(if" "$SRC" --include="*.pas"
  FAIL=1
fi
for FMT in "ifPng" "ifJpeg" "ifWebP" "ifBmp" "ifGif" "ifQoi"; do
  if ! grep -rq "ImageRegisterCodec($FMT" "$SRC" --include="*.pas"; then
    echo "FAIL: missing registration $FMT"
    FAIL=1
  fi
done

echo "[guard] check facade pure re-export + inline zero-copy"
if ! grep -q "inline;" "$IMG"; then
  echo "FAIL: $IMG facade must be inline zero-copy"
  FAIL=1
fi
if grep -q "bytes\.ops" "$IMG"; then
  echo "note: image facade reuses bytes.ops single source via impl units"
fi

echo "[guard] check L0-L3 single direction (graphics L1 not depend on image, canvas→image is L2 same-layer one-way allowed)"
# graphics.base must not uses image
if grep -q "nextpas\.core\.image" "$SRC/nextpas.core.graphics.base.pas"; then
  echo "FAIL: graphics.base must not depend on image (L1→L2)"
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
  echo "[guard] FAIL"
  exit 1
fi
echo "[guard] PASS — image 888 naming locked, dispatch 6 formats intact, no pure fallback"
