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
# luxury unified: single builder seam via TJsonWriter (json.writer) + bytes.ops geometric; clean fast-path via JsonNeedsEscapeStr+BytesCopy is perf-allowed (8% short literals) + unified fallback via writer single-pass
if grep -q "TJsonWriter" "$PURE" && grep -q "TStringBuilder" "$PURE"; then
  say_ok "pure.value canonical builder single source unified via TJsonWriter/bytes.ops"
else
  say_fail "pure.value should retain builder single source via bytes.ops (TJsonWriter+TStringBuilder)"
fi

# 4b) pure.value L2→L2 single seam: json.writer+text.builder+text.escape via pure.value single point, cycle-gated
if grep -q "nextpas.core.json.writer" "$PURE" && grep -q "nextpas.core.text.builder" "$PURE" && grep -q "nextpas.core.text.escape" "$PURE"; then
  say_ok "pure.value single seam json.writer+text.builder+text.escape"
else
  say_fail "pure.value must keep single seam json.writer+text.builder+text.escape (L2→L2 single-point via pure.value)"
fi
for token in "nextpas.core.json.writer" "nextpas.core.text.builder" "nextpas.core.text.escape"; do
  LOTHER=$(grep -R --include="nextpas.core.js.*.pas" "$token" "$ROOT/core/src" 2>/dev/null | grep -v "nextpas.core.js.pure.value.pas" | grep -v "unit $token" || true)
  # allow js.quickjs.loader probe building via text.builder as vault-cached single source (luxury, not L2 single-point violation)
  if [[ "$token" == "nextpas.core.text.builder" ]]; then
    LOTHER=$(echo "$LOTHER" | grep -v "nextpas.core.js.quickjs.loader.pas" || true)
  fi
  # text.escape now single-point via pure.value only — js.eval converges via pure.value JsPure*Backslash* thin-forward (no direct eval seam)
  if [[ -n "$LOTHER" ]]; then
    say_fail "only pure.value may use $token (L2→L2 single-point js.* via pure.value, json.* internal excluded, found: $LOTHER)"
  else
    say_ok "only pure.value uses $token"
  fi
done
if grep -R -E -q "nextpas\.core\.js\." "$ROOT/core/src/nextpas.core.json"*.pas 2>/dev/null; then
  say_fail "L2 cycle: json must not use js (reverse forbidden, pure.value single-point)"
else
  say_ok "cycle-gated: json→js reverse 0 via pure.value single-point"
fi

# 5) L2 layering: intf interface still only js.base + json.types
if grep -q "uses nextpas.core.js.base, nextpas.core.json.types" "$FILE"; then
  say_ok "interface narrow seam json.types"
else
  say_fail "interface uses must be js.base + json.types narrow (CONTRACT §1)"
fi

# 6) factory: single slit via registry, zero direct backend uses (显式收敛非掩盖, registry唯一扇出owner, 门面零逻辑门禁)
FACTORY="$ROOT/core/src/nextpas.core.js.factory.pas"
REGISTRY="$ROOT/core/src/nextpas.core.js.registry.pas"
FACADE="$ROOT/core/src/nextpas.core.js.pas"
for token in "nextpas.core.js.fake" "nextpas.core.js.js888" "nextpas.core.js.v8" "nextpas.core.js.chakra" "nextpas.core.js.quickjs"; do
  if grep -q "$token" "$FACTORY"; then
    say_fail "js.factory must not directly use $token (zero direct uses, fan-out via registry single slit, 显式收敛非掩盖)"
  else
    say_ok "factory zero direct $token"
  fi
done
if grep -q "nextpas.core.js.registry" "$FACTORY"; then
  say_ok "factory single slit via registry (L2→L2单缝, registry唯一扇出owner)"
else
  say_fail "js.factory must use js.registry single slit"
fi
# factory interface must be narrow base+intf (no registry in interface, registry only in implementation)
if grep -q "nextpas.core.js.registry" "$FACTORY" && ! grep -q "^uses" "$FACTORY"; then
  say_fail "factory uses malformed"
fi
# factory must keep inline thin-forward (perf evidence inline零拷贝)
if grep -q "function CreateJsRuntime.*inline;" "$FACTORY" && grep -q "function JsBackendAvailable.*inline;" "$FACTORY"; then
  say_ok "factory inline thin-forward perf evidence"
else
  say_fail "js.factory must keep inline thin-forward (perf inline零拷贝)"
fi
# factory must not contain case branching duplication (zero logic门面, 分支下沉registry)
if grep -q "case AKind of" "$FACTORY"; then
  say_fail "js.factory must not contain case AKind branching (branch must sink to registry O(1) vault)"
else
  say_ok "factory zero case branching (branch sunk to registry)"
fi

# 7) registry: L2唯一扇出owner, 5后端聚合显式扇出, 扇出隐蔽性需持续门禁 (fake/js888/v8/chakra/quickjs)
for token in "nextpas.core.js.fake" "nextpas.core.js.js888" "nextpas.core.js.v8" "nextpas.core.js.chakra" "nextpas.core.js.quickjs.loader" "nextpas.core.js.quickjs;"; do
  if grep -q "$token" "$REGISTRY"; then
    say_ok "registry aggregates $token"
  else
    say_fail "js.registry must aggregate $token (L2唯一扇出owner 5后端)"
  fi
done
# registry must keep O(1) vault + inline + bytes.ops single source + try-finally stability
if grep -q "TJsRegistryVault" "$REGISTRY" && grep -q "VaultRef" "$REGISTRY"; then
  say_ok "registry VaultRef single source vault isolation"
else
  say_fail "js.registry must keep VaultRef vault isolation"
fi
if grep -q "inline;" "$REGISTRY" && grep -q "BytesCopy" "$REGISTRY"; then
  say_ok "registry inline+BytesCopy single source perf evidence"
else
  say_ok "registry inline/BytesCopy evidence (optional)"
fi
if grep -q "try" "$REGISTRY" && grep -q "finally" "$REGISTRY"; then
  say_ok "registry try-finally stability (resource不丢)"
else
  say_fail "js.registry must keep try-finally (IMutex Release不丢)"
fi

# 8) registry is the ONLY fan-out point: other js.* must not directly use fake/js888/v8/chakra (fan-out隐蔽性门禁)
for token in "nextpas.core.js.fake" "nextpas.core.js.js888" "nextpas.core.js.v8" "nextpas.core.js.chakra"; do
  LOTHER=$(grep -R --include="nextpas.core.js*.pas" "$token" "$ROOT/core/src" 2>/dev/null | grep -v "unit $token" | grep -v "nextpas.core.js.registry.pas" | grep -v "nextpas.core.js.fake.pas" | grep -v "nextpas.core.js.js888.pas" | grep -v "nextpas.core.js.v8.pas" | grep -v "nextpas.core.js.chakra.pas" || true)
  if [[ -n "$LOTHER" ]]; then
    say_fail "only registry may use $token (fan-out hidden gate), found: $LOTHER"
  else
    say_ok "only registry fans out $token"
  fi
done

# 9) facade zero logic gate (门面零逻辑, 纯re-export inline薄转发, L0-L3, 四件套)
for token in "nextpas.core.js.fake" "nextpas.core.js.js888" "nextpas.core.js.v8" "nextpas.core.js.chakra" "nextpas.core.js.registry" "nextpas.core.js.quickjs"; do
  # facade must not directly use registry/backends beyond factory (factory已收敛)
  if [[ "$token" == "nextpas.core.js.registry" ]]; then
    if grep -q "$token" "$FACADE"; then
      say_fail "js facade must not directly use $token (must via factory, 门面零逻辑)"
    else
      say_ok "facade zero direct $token"
    fi
  else
    if grep -q "$token" "$FACADE"; then
      say_fail "js facade must not directly use $token (门面零逻辑, 禁隐式扇出)"
    else
      say_ok "facade zero direct $token"
    fi
  fi
done
if grep -q "nextpas.core.js.factory" "$FACADE"; then
  say_ok "facade single source via factory"
else
  say_fail "js facade must use factory single source"
fi
if grep -q "function CreateJsRuntime.*inline;" "$FACADE" && grep -q "function JsBackendAvailable.*inline;" "$FACADE"; then
  say_ok "facade inline thin-forward zero logic"
else
  say_fail "js facade must keep inline thin-forward zero logic"
fi
if grep -q "case AKind of" "$FACADE"; then
  say_fail "js facade must not contain case branching (zero logic, branch sunk to registry)"
else
  say_ok "facade zero case branching"
fi

# 10) 2-space luxury: value-semantic predicates must be multiline with 2-space indent (thin intf ten)
if grep -Eq "^function TJsValue\.IsValid: Boolean; inline; begin" "$FILE"; then
  say_fail "predicates must be multiline with 2-space indent (thin intf luxury, 10 predicates squeezed)"
else
  say_ok "predicates 2-space multiline luxury"
fi
if grep -Eq "^  Result :=" "$FILE"; then
  say_ok "predicates 2-space indent evidence"
else
  say_fail "predicates must use 2-space indent inside begin/end"
fi

# 11) module-registry explicit L2→L2 allowlist (single-point js→json via json.types + pure.value, cycle-gated)
REG_DOC="$ROOT/core/docs/core-module-registry.md"
if grep -q "same-layer one-way \`json\`" "$REG_DOC" && grep -q "js.intf.*json.types" "$REG_DOC" && grep -q "pure.value.*json.writer" "$REG_DOC"; then
  say_ok "module-registry allowlist L2→L2 js→json single-point cycle-gated"
else
  say_fail "module-registry must explicitly allowlist L2→L2 js→json single-point (js.intf→json.types + pure.value→json.writer via bytes.ops, cycle-gated, no reverse)"
fi

# 12) cycle gate: json must not depend on js (no reverse edge), impl narrow only bytes.ops + pure.value
if grep -R -E -q "nextpas\.core\.js\." "$ROOT/core/src/nextpas.core.json"*.pas 2>/dev/null; then
  say_fail "L2 cycle: json must not use js (reverse edge forbidden)"
else
  say_ok "cycle-gated: json→js reverse 0"
fi
IMPL_SECT=$(sed -n '/^implementation/,/^end\./p' "$FILE")
IMPL_UNITS=$(echo "$IMPL_SECT" | grep -o "nextpas.core\.[a-z0-9._]*" | sort -u || true)
for u in $IMPL_UNITS; do
  case "$u" in
    nextpas.core.bytes.ops|nextpas.core.js.pure.value|nextpas.core.js.pure.base|nextpas.core.js.lifecycle) say_ok "impl narrow allow $u" ;;
    *) say_fail "js.intf implementation must only use bytes.ops + js.pure.value/pure.base/lifecycle narrow (found $u)" ;;
  esac
done
# base zero dependency gate: pure.base must not use same-module js.* (lifecycle/host/value/eval via owner single source, base zero dependency)
if grep -q "nextpas.core.js.lifecycle" "$ROOT/core/src/nextpas.core.js.pure.base.pas" && grep -q "uses" "$ROOT/core/src/nextpas.core.js.pure.base.pas"; then
  say_fail "js.pure.base must be zero-dependency base (no same-module uses, lifecycle via owner js.lifecycle single source, base zero dependency)"
else
  say_ok "pure.base zero dependency (no same-module uses, base←owner single source via js.lifecycle/pure.host/value/js.eval)"
fi
# sentinel single source: JS_PURE_EVAL_* must only live in js.eval (owner), not duplicated in pure.base
if grep -q "JS_PURE_EVAL_WHILE_TRUE" "$ROOT/core/src/nextpas.core.js.pure.base.pas"; then
  say_fail "js.pure.base must not define JS_PURE_EVAL_* (sentinels single source via js.eval, pure.hash for threshold, no duplication)"
else
  say_ok "sentinels single source via js.eval (pure.base zero duplication, pure.hash for threshold)"
fi
if grep -q "JS_PURE_EVAL_WHILE_TRUE" "$ROOT/core/src/nextpas.core.js.eval.pas" && grep -q "JS_PURE_HASH_THRESHOLD" "$ROOT/core/src/nextpas.core.js.pure.hash.pas"; then
  say_ok "single source owners present: eval owns sentinels, pure.hash owns threshold"
else
  say_fail "single source owners missing: eval must own JS_PURE_EVAL_* and pure.hash must own JS_PURE_HASH_THRESHOLD"
fi

# 13) volume hygiene: single threshold 800, wc -l <800 anchored in Makefile (防漂移, 历史 550/650 已收敛)
THRESHOLD=800
# hygiene sampling anchored: wc -l core/src/nextpas.core.js.*.pas, threshold 800, see CONTRACT §1 and Makefile (json.* excluded)
for f in "$ROOT"/core/src/nextpas.core.js.*.pas; do
  if [[ ! -f "$f" ]]; then continue; fi
  lines=$(wc -l < "$f")
  base=$(basename "$f")
  if [[ "$lines" -gt "$THRESHOLD" ]]; then
    say_fail "volume $base wc -l $lines >$THRESHOLD (single threshold 800, split required, see CONTRACT §1)"
  else
    say_ok "volume $base wc -l $lines <800 (阈值800)"
  fi
done
# pure family explicit samples (CONTRACT §1: pure.base ~360 <800, pure.host/value etc)
for suffix in "pure.base" "pure.host" "pure.value" "pure.impl" "lifecycle" "registry" "factory" "value.store" "quickjs.value"; do
  pf="$ROOT/core/src/nextpas.core.js.$suffix.pas"
  if [[ -f "$pf" ]]; then
    lines=$(wc -l < "$pf")
    if [[ "$lines" -gt "$THRESHOLD" ]]; then
      say_fail "volume js.$suffix wc -l $lines >$THRESHOLD"
    else
      say_ok "volume js.$suffix wc -l $lines <800 (threshold 800, zero-copy bytes.ops inline)"
    fi
  fi
done

if [[ $fail -ne 0 ]]; then
  echo "[js-source-contract] FAIL" >&2
  exit 1
fi
echo "[js-source-contract] PASS"
echo "js-source-contract=pass"
