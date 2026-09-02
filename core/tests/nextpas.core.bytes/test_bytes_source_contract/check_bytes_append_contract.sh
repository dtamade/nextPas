#!/usr/bin/env bash
set -euo pipefail
CORE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SRC="$CORE_ROOT/src/nextpas.core.bytes.ops.pas"

fail() { echo "[bytes-append-contract] FAIL: $*" >&2; exit 1; }

# 1. BytesAppend* must be deprecated with hint to IBytesBuilder/ConcatMany
for sym in "BytesAppend(var ADest: TBytes; const ASrc: TBytes)" "BytesAppend(var ADest: TBytes; const ASrc: PByte" "BytesAppendByte" "BytesAppendUInt16BE" "BytesAppendUInt16LE" "BytesAppendUInt24BE" "BytesAppendUInt32BE" "BytesAppendUInt32LE" "BytesAppendUInt64BE" "BytesAppendUInt64LE"; do
  if ! grep -F -- "$sym" "$SRC" | grep -q "deprecated"; then
    fail "missing deprecated gate for $sym (require IBytesBuilder/ConcatMany hint)"
  fi
done

# hint must mention IBytesBuilder and ConcatMany
if ! grep -q "IBytesBuilder" "$SRC"; then fail "BytesAppend hint must mention IBytesBuilder"; fi
if ! grep -q "BytesConcatMany" "$SRC"; then fail "BytesAppend hint must mention BytesConcatMany"; fi
if ! grep -q "SpanConcatMany" "$SRC"; then fail "BytesAppend hint must mention SpanConcatMany"; fi

# 2. Performance evidence: inline + zero-copy Move must remain
if ! grep -q "procedure BytesAppend(var ADest: TBytes; const ASrc: TBytes); inline;" "$SRC"; then
  fail "BytesAppend must remain inline (performance)"
fi
# overload variant may have inline; overload; deprecated — accept any order containing inline
if ! grep -q "BytesAppend.*inline" "$SRC"; then
  fail "BytesAppend* must remain inline for single-use zero-copy"
fi
if ! grep -q "Move(ASrc\[0\], ADest" "$SRC"; then
  fail "BytesAppend must keep single Move zero-copy evidence"
fi

# 3. Loop detection: warn if BytesAppend appears inside for/while loops in hot paths (advisory, not fail)
# Count occurrences of BytesAppend inside loops via simple heuristic: look for while/for blocks containing BytesAppend
LOOPED=$(grep -R -n "BytesAppend" "$CORE_ROOT/src" --include="*.pas" | grep -E "for |while |repeat" || true)
if echo "$LOOPED" | grep -q "BytesAppend"; then
  echo "[bytes-append-contract] WARN: BytesAppend near loop keywords (advisory, prefer IBytesBuilder):" >&2
  echo "$LOOPED" >&2
fi

echo "bytes-append-contract=pass"
