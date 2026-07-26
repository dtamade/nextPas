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

# --- Era I: ReallocMemOf symmetry + owned-string size tables + tui FreeMemOf WAIVE ---
need_file "$SRC/nextpas.core.text.builder.pas"
need_grep "$SRC/nextpas.core.text.builder.pas" 'ReallocMemOf' \
  'text.builder must use ReallocMemOf on inject grow (I1)'

need_file "$SRC/nextpas.core.collections.element_manager.pas"
need_grep "$SRC/nextpas.core.collections.element_manager.pas" 'ReallocMemOf' \
  'element_manager must use ReallocMemOf on SupportsRealloc path (I residual)'

need_file "$SRC/nextpas.core.json.parser.pas"
need_grep "$SRC/nextpas.core.json.parser.pas" 'TJsonOwnedStr' \
  'json.parser must keep TJsonOwnedStr overflow size table (I2)'
need_grep "$SRC/nextpas.core.json.parser.pas" 'FreeMemOf\(FAllocator, FStrOverflow\[' \
  'json.parser overflow elements must FreeMemOf with recorded size (I2)'
if grep -nE 'FAllocator\.FreeMem\(' "$SRC/nextpas.core.json.parser.pas" | grep -qE 'FStrOverflow|Overflow'; then
  die 'json.parser must not FreeMem overflow strings via unsized FAllocator.FreeMem (I2)'
fi

need_file "$SRC/nextpas.core.toml.parser.pas"
need_grep "$SRC/nextpas.core.toml.parser.pas" 'AddOwnedBuf\(ABuf: Pointer; ASize: SizeUInt\)' \
  'toml.parser AddOwnedBuf must take size (I3)'
need_grep "$SRC/nextpas.core.toml.parser.pas" 'TTomlOwnedBuf' \
  'toml.parser must keep TTomlOwnedBuf size table (I3)'
need_grep "$SRC/nextpas.core.toml.parser.pas" 'FreeMemOf\(FAllocator, FOwnedBufs\[' \
  'toml.parser owned elements must FreeMemOf with recorded size (I3)'

# tui inject: must observe Free via IAllocator (permanent FreeMemOf WAIVE)
for f in \
  "$SRC/nextpas.core.tui.buffer.pas" \
  "$SRC/nextpas.core.tui.overlay.pas"
do
  need_file "$f"
  need_grep "$f" 'FAllocator\.FreeMem' \
    "tui inject must keep FAllocator.FreeMem (FreeMemOf WAIVE tracking) ($f)"
done

# --- Era J: mem-owner single-slab backing FreeMemOf ---
need_file "$SRC/nextpas.core.mem.arena.local.pas"
need_grep "$SRC/nextpas.core.mem.arena.local.pas" 'FreeMemOf\(FAllocator, FBacking, FCapacity\)' \
  'LocalArena Destroy must FreeMemOf backing with FCapacity (J1)'
forbid_grep "$SRC/nextpas.core.mem.arena.local.pas" 'FAllocator\.FreeMem\(FBacking\)' \
  'LocalArena must not unsized FreeMem FBacking (J1)'

need_file "$SRC/nextpas.core.mem.blockpool.pas"
need_grep "$SRC/nextpas.core.mem.blockpool.pas" 'FRawAllocSize' \
  'TBlockPool must track FRawAllocSize (J2)'
need_grep "$SRC/nextpas.core.mem.blockpool.pas" 'FreeMemOf\(FAllocator, FRawBuffer, FRawAllocSize\)' \
  'TBlockPool Destroy must FreeMemOf raw with FRawAllocSize (J2)'

need_file "$SRC/nextpas.core.mem.pool.fixed.pas"
need_grep "$SRC/nextpas.core.mem.pool.fixed.pas" 'FRawAllocSize' \
  'TFixedPool must track FRawAllocSize (J3)'
need_grep "$SRC/nextpas.core.mem.pool.fixed.pas" 'FreeMemOf\(FAllocator, FRawBuffer, FRawAllocSize\)' \
  'TFixedPool Destroy must FreeMemOf raw with FRawAllocSize (J3)'

# --- Era K: multi-segment / growable owner FreeMemOf when size already recorded ---
need_file "$SRC/nextpas.core.mem.blockpool.growable.pas"
need_grep "$SRC/nextpas.core.mem.blockpool.growable.pas" 'FreeMemOf\(FAllocator, LRaw, LRawSize\)' \
  'TGrowingBlockPool FreeSegment must FreeMemOf with RawSize (K1)'

need_file "$SRC/nextpas.core.mem.arena.chunked.pas"
need_grep "$SRC/nextpas.core.mem.arena.chunked.pas" 'FreeMemOf\(FAllocator, LRaw, LRawSize\)' \
  'TChunkedArena FreeSegment must FreeMemOf with RawSize (K2)'

need_file "$SRC/nextpas.core.mem.stack_pool.pas"
need_grep "$SRC/nextpas.core.mem.stack_pool.pas" 'FreeMemOf\(FBaseAllocator, FBuffer, FSize\)' \
  'TStackPool Destroy must FreeMemOf buffer with FSize (K3)'

need_file "$SRC/nextpas.core.mem.ring_buffer.pas"
need_grep "$SRC/nextpas.core.mem.ring_buffer.pas" 'FreeMemOf\(FBaseAllocator, FBuffer, FCapacity \* FElementSize\)' \
  'TRingBuffer Destroy must FreeMemOf capacity*elem (K4)'

# K5 (pool.fixed.growable) retired 2026-07-26: unit pruned (zero consumers, unclassified surface).

# --- Era L: LocalBlockPool + FixedSlab raw + SlabPool fallback ---
need_file "$SRC/nextpas.core.mem.pool.pas"
need_grep "$SRC/nextpas.core.mem.pool.pas" 'FBackingSize' \
  'TLocalBlockPool must track FBackingSize (L1)'
need_grep "$SRC/nextpas.core.mem.pool.pas" 'FreeMemOf\(FAllocator, FBacking, FBackingSize\)' \
  'TLocalBlockPool Destroy must FreeMemOf FBacking (L1)'

need_file "$SRC/nextpas.core.mem.pool.fixed_slab.pas"
need_grep "$SRC/nextpas.core.mem.pool.fixed_slab.pas" 'FRawAllocSize' \
  'TFixedSlabPool must track FRawAllocSize (L2)'
need_grep "$SRC/nextpas.core.mem.pool.fixed_slab.pas" 'FreeMemOf\(FAllocator, FRaw, FRawAllocSize\)' \
  'TFixedSlabPool Destroy must FreeMemOf FRaw (L2)'

need_file "$SRC/nextpas.core.mem.pool.slab.pas"
need_grep "$SRC/nextpas.core.mem.pool.slab.pas" 'FallbackRawAllocSize' \
  'TSlabPool must use FallbackRawAllocSize for fallback free (L5)'
need_grep "$SRC/nextpas.core.mem.pool.slab.pas" 'FreeMemOf\(FAllocator, LAlloc\.RawPtr' \
  'TSlabPool FreeMem fallback must FreeMemOf RawPtr (L5)'

# --- Era M: FixedSlab AlignedFallback size + sharded TLS node sized free ---
need_file "$SRC/nextpas.core.mem.pool.fixed_slab.pas"
need_grep "$SRC/nextpas.core.mem.pool.fixed_slab.pas" 'FAlignedFallbackRawSizes' \
  'TFixedSlabPool must track AlignedFallback raw sizes (M1)'
need_grep "$SRC/nextpas.core.mem.pool.fixed_slab.pas" 'TrackAlignedFallback\(Result, LRaw, LNeeded\)' \
  'AllocAligned must TrackAlignedFallback with LNeeded (M1)'
need_grep "$SRC/nextpas.core.mem.pool.fixed_slab.pas" 'FreeMemOf\(FAllocator, FAlignedFallbackRawPtrs' \
  'FreeActiveAlignedFallbacks must FreeMemOf with sizes (M2)'

need_file "$SRC/nextpas.core.mem.blockpool.sharded.pas"
need_grep "$SRC/nextpas.core.mem.blockpool.sharded.pas" 'AllocSize: SizeUInt' \
  'TThreadCacheNode must record AllocSize (M3)'
need_grep "$SRC/nextpas.core.mem.blockpool.sharded.pas" 'NpSystemFreeMem\(LNode, LNode\^\.AllocSize\)' \
  'ThreadExitCleanup must sized NpSystemFreeMem TLS node (M3)'

if [[ "$FAIL" -ne 0 ]]; then
  echo "consumer-audit-contracts: FAILED" >&2
  exit 1
fi

echo "consumer-audit-contracts: PASS"
