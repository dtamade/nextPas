#!/usr/bin/env bash
# Source-contract: mem must not use FPC RTL units or System heap/Move primitives.
# Heap owner is nextpas.core.system.heap (NpSystem*).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SRC="$ROOT/core/src"
FAIL=0

# Named FPC RTL units only in uses lines (not prose mentioning Windows).
RTL_UNIT_RE='\b(SysUtils|Classes|BaseUnix|Unix|Windows|ctypes|DynLibs|StrUtils|TypInfo|Variants|Contnrs)\b'
# System heap primitives — forbidden outside system.heap / system.memmanager.
SYSTEM_HEAP_RE='\bSystem\.(GetMem|FreeMem|ReallocMem|AllocMem|Move)\b'
# OS sub-units — mem must use platform.thread/sync/memory/mmap/env/dl only.
OS_FFI_RE='nextpas\.core\.platform\.(posix|windows|linux)\.'

while IFS= read -r -d '' f; do
  base="$(basename "$f")"
  # uses-block scan: from a line matching ^uses to the first ';'
  if awk '
    BEGIN{inuses=0}
    /^[[:space:]]*uses[[:space:]]*$/ || /^[[:space:]]*uses[[:space:]]/ {inuses=1}
    inuses {
      if ($0 ~ /\b(SysUtils|Classes|BaseUnix|Unix|Windows|ctypes|DynLibs|StrUtils|TypInfo|Variants|Contnrs)\b/) {
        print FILENAME":"NR":"$0
        found=1
      }
      if (/;/) inuses=0
    }
    END{exit found?0:1}
  ' "$f" 2>/dev/null; then
    echo "FAIL: $base imports FPC RTL unit name in uses"
    FAIL=1
  fi
  if grep -nE "$SYSTEM_HEAP_RE" "$f" >/dev/null 2>&1; then
    echo "FAIL: $base uses System heap/Move primitive (use nextpas.core.system.heap)"
    grep -nE "$SYSTEM_HEAP_RE" "$f" || true
    FAIL=1
  fi
  if grep -nE "uses|$OS_FFI_RE" "$f" | grep -E "$OS_FFI_RE" >/dev/null 2>&1; then
    if awk '
      BEGIN{inuses=0}
      /^[[:space:]]*uses/ {inuses=1}
      inuses {
        if ($0 ~ /nextpas\.core\.platform\.(posix|windows|linux)\./) { print; found=1 }
        if (/;/) inuses=0
      }
      END{exit found?0:1}
    ' "$f" 2>/dev/null; then
      echo "FAIL: $base uses platform OS sub-unit (use platform.thread/sync/memory/…)"
      FAIL=1
    fi
  fi
done < <(find "$SRC" -maxdepth 1 -name 'nextpas.core.mem*.pas' -print0)

# Forbid resurrected dead units
for dead in pressure registry watermark; do
  if [[ -f "$SRC/nextpas.core.mem.${dead}.pas" ]]; then
    echo "FAIL: dead unit still present: nextpas.core.mem.${dead}.pas"
    FAIL=1
  fi
done

if [[ "$FAIL" -ne 0 ]]; then
  echo "check_mem_rtl_isolation: FAIL"
  exit 1
fi
echo "check_mem_rtl_isolation: OK"
