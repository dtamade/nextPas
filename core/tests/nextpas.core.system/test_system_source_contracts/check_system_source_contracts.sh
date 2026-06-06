#!/usr/bin/env bash
set -euo pipefail

CORE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -s "$CORE_ROOT/$path" ]] || fail "required non-empty file missing: core/$path"
}

require_token() {
  local path="$1"
  local token="$2"
  rg -F --quiet -- "$token" "$CORE_ROOT/$path" || fail "core/$path missing token: $token"
}

require_file "docs/system/README.md"
require_file "docs/system/rtl-mapping.md"
require_file "docs/system/goal-tree.md"
require_file "docs/system/runtime-contracts.md"
require_file "docs/system/lifecycle-contracts.md"

require_token "docs/system/README.md" "RTL root"
require_token "docs/system/README.md" "owner boundary"
require_token "docs/system/README.md" "nextpas.core.base"
require_token "docs/system/README.md" "nextpas.core.exception"
require_token "docs/system/README.md" "nextpas.core.mem"
require_token "docs/system/README.md" "nextpas.core.platform"
require_token "docs/system/README.md" "nextpas.core.text"
require_token "docs/system/README.md" "non-goals"
require_token "docs/system/README.md" "deferred"

for unit_name in System SysUtils TypInfo Classes ObjPas; do
  require_token "docs/system/rtl-mapping.md" "$unit_name"
done

for status in \
  "system-owned" \
  "system facade delegating to owner" \
  "owned by another module, no system facade yet" \
  "future compiler/runtime only" \
  "explicitly out of scope"; do
  require_token "docs/system/rtl-mapping.md" "$status"
done

for phase in S0 S1 S2 S3 S4 S5; do
  require_token "docs/system/goal-tree.md" "$phase"
done

for token in \
  "S4" \
  "deferred" \
  "not a current phase gate" \
  "no public units yet"; do
  require_token "docs/system/goal-tree.md" "$token"
done

for token in \
  "managed string" \
  "dynamic array" \
  "interface reference" \
  "managed record" \
  "heap manager" \
  "nextpas.core.mem" \
  "not public ABI" \
  "leak-sensitive"; do
  require_token "docs/system/runtime-contracts.md" "$token"
done

for helper in \
  "np.system.string_init" \
  "np.system.string_fini" \
  "np.system.string_assign" \
  "np.system.dynarray_init" \
  "np.system.dynarray_fini" \
  "np.system.dynarray_set_length" \
  "np.system.interface_addref" \
  "np.system.interface_release" \
  "np.system.managed_record_init" \
  "np.system.managed_record_fini" \
  "np.system.heap_alloc" \
  "np.system.heap_free"; do
  require_token "docs/system/runtime-contracts.md" "$helper"
done

for token in \
  "exception raise" \
  "unwind" \
  "nextpas.core.exception" \
  "RTTI" \
  "TypeInfo" \
  "compiler-owned" \
  "unit initialization" \
  "unit finalization" \
  "reverse dependency order" \
  "runtime-startup-failed" \
  "unit-initialization-failed" \
  "unit-finalization-failed" \
  "runtime-abort"; do
  require_token "docs/system/lifecycle-contracts.md" "$token"
done

for helper in \
  "np.system.unit_init" \
  "np.system.unit_fini" \
  "np.system.runtime_fault"; do
  require_token "docs/system/lifecycle-contracts.md" "$helper"
done

[[ ! -e "$CORE_ROOT/src/System.pas" ]] || fail "must not create bare FPC-conflicting System.pas"
[[ ! -e "$CORE_ROOT/src/system.pas" ]] || fail "must not create bare FPC-conflicting system.pas"
[[ ! -e "$CORE_ROOT/src/nextpas.core.system.sysutils.pas" ]] || fail "S4 deferred: no live nextpas.core.system.sysutils unit expected yet"
[[ ! -e "$CORE_ROOT/src/nextpas.core.system.typinfo.pas" ]] || fail "S4 deferred: no live nextpas.core.system.typinfo unit expected yet"
[[ ! -e "$CORE_ROOT/src/nextpas.core.system.classes.pas" ]] || fail "S4 deferred: no live nextpas.core.system.classes unit expected yet"

mapfile -t system_units < <(find "$CORE_ROOT/src" -maxdepth 1 -name 'nextpas.core.system*.pas' | sort)
(( ${#system_units[@]} > 0 )) || fail "no nextpas.core.system units found"

tmp_found="$(mktemp)"
trap 'rm -f "$tmp_found"' EXIT

awk '
  function trim(s) {
    gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s)
    return s
  }
  function emit_units(file, line, parts, i, unit) {
    gsub(/\{[^}]*\}/, "", line)
    sub(/\/\/.*/, "", line)
    gsub(/^[ \t]*uses[ \t]*/, "", line)
    split(line, parts, /[,;]/)
    for (i in parts) {
      unit = trim(parts[i])
      if (unit != "" && unit !~ /^\$/) {
        print file "|" unit
      }
    }
  }
  /^[ \t]*uses[ \t]*/ {
    in_uses = 1
    emit_units(FILENAME, $0)
    if ($0 ~ /;/) in_uses = 0
    next
  }
  in_uses {
    emit_units(FILENAME, $0)
    if ($0 ~ /;/) in_uses = 0
  }
' "${system_units[@]}" | sort -u > "$tmp_found"

while IFS='|' read -r file unit_name; do
  case "$unit_name" in
    Windows|BaseUnix|Unix|Dos|Crt)
      fail "system unit bypasses platform owner: ${file#$CORE_ROOT/} uses $unit_name"
      ;;
  esac
done < "$tmp_found"

echo "[PASS] nextpas.core.system source contracts"
