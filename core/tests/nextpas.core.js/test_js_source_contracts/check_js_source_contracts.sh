#!/usr/bin/env bash
# nextpas.core.js source-contract gate — thin intf + single source AsJson via pure.value
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
FILE="$ROOT/core/src/nextpas.core.js.intf.pas"
PURE="$ROOT/core/src/nextpas.core.js.pure.value.pas"
fail=0
say_fail(){ echo "[js-source-contract] FAIL: $*" >&2; fail=1; }
say_ok(){ echo "[js-source-contract] $*"; }

if [[ ! -f "$FILE" ]]; then say_fail "missing $FILE"; exit 1; fi

# 1) implementation uses must be narrow: only bytes.ops and js.pure.value (plus implicit via interface js.base/json.types)
# Forbid direct text.builder / json.writer / text.escape / text.number seams in js.intf implementation
for token in "nextpas.core.text.builder" "nextpas.core.json.writer" "nextpas.core.text.escape" "nextpas.core.text.number"; do
  if grep -q "$token" "$FILE"; then
    say_fail "js.intf must not directly use $token (narrow via pure.value owner, CONTRACT §1 only json.types); found in $FILE"
  else
    say_ok "no direct $token"
  fi
done

# Ensure bytes.ops single source is allowed and present (via SpanToString)
if grep -q "nextpas.core.bytes.ops" "$FILE"; then
  say_ok "bytes.ops single source present (SpanToString zero-copy)"
else
  say_fail "js.intf should keep bytes.ops single source for SpanToString"
fi

# Ensure pure.value owner is used
if grep -q "nextpas.core.js.pure.value" "$FILE"; then
  say_ok "pure.value owner single source present"
else
  say_fail "js.intf must use pure.value owner for AsJson single source"
fi

# 2) AsJson must be inline thin-forward (red-line 2)
if grep -Eq "function TJsValue\.AsJson: string; inline;" "$FILE"; then
  say_ok "AsJson inline"
else
  say_fail "TJsValue.AsJson must be inline (thin intf red-line 2)"
fi

# 3) AsJson body must delegate to JsPureToJsonString single source, no heavy builder/case duplication
if grep -q "JsPureToJsonString" "$FILE"; then
  say_ok "AsJson delegates to JsPureToJsonString"
else
  say_fail "AsJson must delegate to JsPureToJsonString single source"
fi

# Ensure heavy duplicate logic removed: no JsonNeedsEscapeStr or TStringBuilder in js.intf AsJson body
if grep -q "JsonNeedsEscapeStr" "$FILE"; then
  say_fail "js.intf must not contain JsonNeedsEscapeStr heavy logic (duplicate with pure.value)"
else
  say_ok "no JsonNeedsEscapeStr duplication"
fi
if grep -q "TJsonWriter" "$FILE"; then
  say_fail "js.intf must not contain TJsonWriter heavy logic (owner pure.value)"
else
  say_ok "no TJsonWriter duplication"
fi

# 4) pure.value owner must still contain canonical implementation (single source evidence)
if grep -q "function JsPureToJsonString" "$PURE"; then
  say_ok "pure.value owns JsPureToJsonString"
else
  say_fail "pure.value must own JsPureToJsonString"
fi
if grep -q "JsonNeedsEscapeStr" "$PURE" && grep -q "TJsonWriter" "$PURE"; then
  say_ok "pure.value canonical builder/escape single source intact"
else
  say_fail "pure.value should retain builder/escape single source via bytes.ops"
fi

# 5) L2 layering: intf interface still only js.base + json.types
if grep -q "uses nextpas.core.js.base, nextpas.core.json.types" "$FILE"; then
  say_ok "interface narrow seam json.types"
else
  say_fail "interface uses must be js.base + json.types narrow (CONTRACT §1)"
fi

if [[ $fail -ne 0 ]]; then
  echo "[js-source-contract] FAIL" >&2
  exit 1
fi
echo "[js-source-contract] PASS"
echo "js-source-contract=pass"
