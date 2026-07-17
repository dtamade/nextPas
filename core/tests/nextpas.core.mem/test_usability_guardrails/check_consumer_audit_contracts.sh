#!/usr/bin/env bash
# Source-contract: consumer-audit fix slice must not silently regress.
# Read-only scans of production sources; does not rewrite other modules.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
SRC="$ROOT/core/src"
DOCS="$ROOT/core/docs/mem"
FAIL=0

die() {
  echo "consumer-audit-contracts FAIL: $*" >&2
  FAIL=1
}

need_file() {
  local f="$1"
  [[ -f "$f" ]] || die "missing $f"
}

need_grep() {
  local f="$1"
  local pat="$2"
  local msg="$3"
  if ! grep -Eq "$pat" "$f"; then
    die "$msg ($f ~ /$pat/)"
  fi
}

forbid_grep() {
  local f="$1"
  local pat="$2"
  local msg="$3"
  if grep -Eq "$pat" "$f"; then
    die "$msg ($f ~ /$pat/)"
  fi
}

# --- Docs status (mem-owned) ---
need_file "$DOCS/CONSUMER-AUDIT-SUMMARY-2026-07-17.md"
need_file "$DOCS/CONSUMER-AUDIT-FINDINGS-2026-07-17.md"
need_grep "$DOCS/CONSUMER-AUDIT-SUMMARY-2026-07-17.md" 'FIX CLOSED' \
  'consumer-audit summary must remain FIX CLOSED'
need_grep "$DOCS/README.md" 'Consumer audit|CONSUMER-AUDIT' \
  'mem README must link consumer-audit status'
need_grep "$DOCS/CONSUMER-AUDIT-SUMMARY-2026-07-17.md" 'CA-011' \
  'summary must keep CA-011 WAIVED note'

# --- CA-001: swiss must use FreeMemOf + DefaultAllocator; never Allocate/Deallocate ---
SWISS_UNITS=(
  "$SRC/nextpas.core.collections.hashmap.swiss.pas"
  "$SRC/nextpas.core.collections.hashmap.swiss.i32.pas"
  "$SRC/nextpas.core.collections.hashmap.swiss.str.pas"
  "$SRC/nextpas.core.collections.hashmap.swiss.i32i32.pas"
)
for f in "${SWISS_UNITS[@]}"; do
  need_file "$f"
  need_grep "$f" 'FreeMemOf' "swiss unit must use FreeMemOf ($f)"
  need_grep "$f" 'DefaultAllocator' "swiss unit must use DefaultAllocator ($f)"
  forbid_grep "$f" 'FAllocator\.Allocate|FAllocator\.Deallocate' \
    "swiss must not call IAllocator.Allocate/Deallocate ($f)"
done

# --- CA-004 L0: platform must not reverse-depend on mem ---
L0_PLATFORM=(
  "$SRC/nextpas.core.platform.fs.pas"
  "$SRC/nextpas.core.platform.io.pas"
  "$SRC/nextpas.core.platform.pty.pas"
)
for f in "${L0_PLATFORM[@]}"; do
  need_file "$f"
  need_grep "$f" 'must not uses nextpas\.core\.mem' \
    "L0 platform must document no reverse-dep on mem ($f)"
  if grep -Eq '^\s*uses\b' "$f"; then
    if awk '
      BEGIN { in_uses=0 }
      /^[[:space:]]*uses[[:space:]]/ { in_uses=1 }
      in_uses {
        if ($0 ~ /nextpas\.core\.mem([^.]|$)/) { found=1 }
        if ($0 ~ /;/) { in_uses=0 }
      }
      END { exit found ? 0 : 1 }
    ' "$f"; then
      die "L0 platform must not uses nextpas.core.mem ($f)"
    fi
  fi
done

# --- CA-003 samples: known-size FreeMem(ptr,size) remains at key free sites ---
need_grep "$SRC/nextpas.core.platform.fs.pas" 'FreeMem\(LBuf, LBufSize\)' \
  'platform.fs must keep sized FreeMem for buffer path'
need_grep "$SRC/nextpas.core.platform.io.pas" 'FreeMem\([^,]+,[^)]+\)' \
  'platform.io must keep at least one sized FreeMem'
need_grep "$SRC/nextpas.core.platform.pty.pas" 'FreeMem\([^,]+,[^)]+\)' \
  'platform.pty must keep at least one sized FreeMem'

# --- L1 sample adopters keep uses mem (regression pins, not full inventory) ---
L1_MEM_USERS=(
  "$SRC/nextpas.core.lockfree.msqueue.pas"
  "$SRC/nextpas.core.lockfree.ebr.pas"
  "$SRC/nextpas.core.yaml.builder.pas"
)
for f in "${L1_MEM_USERS[@]}"; do
  if [[ -f "$f" ]]; then
    need_grep "$f" 'nextpas\.core\.mem' \
      "L1 adopter must keep nextpas.core.mem reference ($f)"
  fi
done

# --- yaml OOM path uses FormatAllocErrorMsg when present ---
if [[ -f "$SRC/nextpas.core.yaml.builder.pas" ]]; then
  need_grep "$SRC/nextpas.core.yaml.builder.pas" 'FormatAllocErrorMsg' \
    'yaml.builder must keep FormatAllocErrorMsg on OOM path'
fi

if [[ "$FAIL" -ne 0 ]]; then
  echo "consumer-audit-contracts: FAILED" >&2
  exit 1
fi

echo "consumer-audit-contracts: PASS"
