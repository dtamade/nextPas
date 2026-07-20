#!/usr/bin/env bash
# Source-contract: mem *alloc-domain* raises must use FormatAllocErrorMsg.
# Scopes: EAllocError, EOutOfMemory, EDoubleFree, EInvalidPointer, EStackOverflow,
# and historical pool subclasses (EMemFixed*, EStackPool*, ESlabPool*, EGrowingFixed*, ERingBuffer*).
# Does NOT require FormatAllocErrorMsg for EArgumentNil / EInvalidArgument / utils noise.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SRC="$ROOT/core/src"
FAIL=0
RAISE_RE='raise[[:space:]]+E(AllocError|OutOfMemory|DoubleFree|InvalidPointer|InvalidLayout|StackOverflow|MemFixed[A-Za-z0-9_]*|StackPool[A-Za-z0-9_]*|SlabPool[A-Za-z0-9_]*|GrowingFixed[A-Za-z0-9_]*|RingBuffer[A-Za-z0-9_]*)\.Create'

while IFS= read -r -d '' f; do
  base="$(basename "$f")"
  if [[ "$base" == "nextpas.core.mem.error.pas" ]]; then
    continue
  fi
  if grep -nE "$RAISE_RE" "$f" >/dev/null 2>&1; then
    mapfile -t lines < <(grep -nE "$RAISE_RE" "$f" || true)
    for entry in "${lines[@]}"; do
      ln="${entry%%:*}"
      window="$(sed -n "${ln},$((ln + 5))p" "$f")"
      if ! grep -q 'FormatAllocErrorMsg' <<<"$window"; then
        echo "FAIL: $base:$ln alloc-domain raise without FormatAllocErrorMsg"
        echo "$window"
        FAIL=1
      fi
    done
  fi
done < <(find "$SRC" -maxdepth 1 -name 'nextpas.core.mem*.pas' -print0)

while IFS= read -r -d '' f; do
  base="$(basename "$f")"
  if grep -nE "FormatAllocErrorMsg\('allocator_|FormatAllocErrorMsg\('[^']+', 'Raise'," "$f" >/dev/null 2>&1; then
    echo "FAIL: $base low-quality FormatAllocErrorMsg stem"
    grep -nE "FormatAllocErrorMsg\('allocator_|FormatAllocErrorMsg\('[^']+', 'Raise'," "$f" || true
    FAIL=1
  fi
done < <(find "$SRC" -maxdepth 1 -name 'nextpas.core.mem*.pas' -print0)

while IFS= read -r -d '' f; do
  if awk '
    BEGIN{inuses=0}
    /^uses/{inuses=1}
    inuses{
      if ($0 ~ /\bSysUtils\b/ || $0 ~ /\bClasses\b/) { print FILENAME":"NR":"$0; found=1 }
      if (/;/) inuses=0
    }
    END{exit found?0:1}
  ' "$f" 2>/dev/null; then
    echo "FAIL: FPC RTL unit in mem test uses: $f"
    FAIL=1
  fi
done < <(find "$ROOT/core/tests/nextpas.core.mem" \( -name '*.lpr' -o -name '*.pas' \) -print0 2>/dev/null)

if [[ "$FAIL" -ne 0 ]]; then
  echo "check_alloc_error_raises: FAIL"
  exit 1
fi
echo "check_alloc_error_raises: OK"
