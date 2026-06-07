#!/usr/bin/env bash
set -euo pipefail

CORE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
REPO_ROOT="$(cd "$CORE_ROOT/.." && pwd)"

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
require_file "docs/system/compatibility-facades.md"
require_file "docs/system/compatibility-matrix.md"
require_file "docs/system/typinfo-minimal-pressure.md"

require_token "docs/system/README.md" "RTL root"
require_token "docs/system/README.md" "owner boundary"
require_token "docs/system/README.md" "nextpas.core.base"
require_token "docs/system/README.md" "nextpas.core.exception"
require_token "docs/system/README.md" "nextpas.core.mem"
require_token "docs/system/README.md" "nextpas.core.platform"
require_token "docs/system/README.md" "nextpas.core.text"
require_token "docs/system/README.md" "non-goals"
require_token "docs/system/README.md" "deferred"
require_token "docs/system/README.md" "compatibility-facades.md"
require_token "docs/system/README.md" "compatibility-matrix.md"
require_token "docs/system/README.md" "typinfo-minimal-pressure.md"

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
  "no public units yet" \
  "compatibility-facades.md" \
  "compatibility-matrix.md" \
  "typinfo-minimal-pressure.md"; do
  require_token "docs/system/goal-tree.md" "$token"
done

for token in \
  "design-only" \
  "rtl/core/sysutils/np_sysutils.pas" \
  "rtl/core/classes/np_classes.pas" \
  "compiler/tests/test_sysutils_createfmt_contract.pas" \
  "compiler/tests/test_typinfo_contract.pas" \
  "nextpas.core.system.typinfo" \
  "nextpas.core.system.classes" \
  "Needs Review" \
  "migration"; do
  require_token "docs/system/compatibility-facades.md" "$token"
done

require_token "docs/system/compatibility-facades.md" 'No live `nextpas.core.system.sysutils` unit yet'
require_token "docs/system/compatibility-facades.md" "typinfo-minimal-pressure.md"

for token in \
  "compiler/toolchain/np_toolchain_runner.pas" \
  "compiler/frontend/np_workspace_model.pas" \
  "core/src/nextpas.core.collections.element_manager.pas" \
  "core/src/nextpas.core.collections.hashmap.swiss.pas" \
  "TFileStream" \
  "TStringList" \
  "PTypeInfo" \
  "InitializeArray" \
  "CopyArray" \
  "FinalizeArray"; do
  require_token "docs/system/compatibility-matrix.md" "$token"
done

require_token "docs/system/compatibility-matrix.md" "typinfo-minimal-pressure.md"
require_token "docs/system/rtl-mapping.md" "typinfo-minimal-pressure.md"

for token in \
  "S4 TypInfo Minimal Pressure Audit" \
  "Real Consumer Pressure" \
  "Owner Boundary" \
  "ABI Risks" \
  "Minimal Unlock Conditions" \
  "Deferred Reason" \
  "compiler/tests/test_typinfo_contract.pas" \
  "core/src/nextpas.core.collections.element_manager.pas" \
  "core/src/nextpas.core.collections.hashmap.swiss.pas" \
  "core/src/nextpas.core.collections.btree.pas" \
  "core/src/nextpas.core.collections.concurrent.hashmap.pas"; do
  require_token "docs/system/typinfo-minimal-pressure.md" "$token"
done

require_token "docs/system/typinfo-minimal-pressure.md" '`nextpas.core.system.typinfo` remains deferred'

for token in \
  "PTypeInfo" \
  "TTypeKind" \
  "TypeInfo" \
  "GetTypeKind" \
  "InitializeArray" \
  "FinalizeArray" \
  "CopyArray"; do
  require_token "docs/system/typinfo-minimal-pressure.md" "$token"
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

require_repo_file() {
  local path="$1"
  [[ -s "$REPO_ROOT/$path" ]] || fail "required non-empty repo file missing: $path"
}

require_repo_token() {
  local path="$1"
  local token="$2"
  rg -F --quiet -- "$token" "$REPO_ROOT/$path" || fail "$path missing token: $token"
}

require_repo_file "compiler/tests/test_sysutils_createfmt_contract.pas"
require_repo_file "compiler/tests/test_typinfo_contract.pas"
require_repo_file "compiler/toolchain/np_toolchain_runner.pas"
require_repo_file "compiler/frontend/np_workspace_model.pas"
require_repo_file "rtl/core/sysutils/np_sysutils.pas"
require_repo_file "rtl/core/classes/np_classes.pas"
require_repo_file "core/src/nextpas.core.collections.element_manager.pas"
require_repo_file "core/src/nextpas.core.collections.hashmap.swiss.pas"

require_repo_token "compiler/tests/test_sysutils_createfmt_contract.pas" "CreateFmt"
require_repo_token "compiler/tests/test_sysutils_createfmt_contract.pas" "Format("
require_repo_token "compiler/tests/test_typinfo_contract.pas" "InitializeArray"
require_repo_token "compiler/tests/test_typinfo_contract.pas" "CopyArray"
require_repo_token "compiler/tests/test_typinfo_contract.pas" "FinalizeArray"
require_repo_token "compiler/toolchain/np_toolchain_runner.pas" "TFileStream"
require_repo_token "compiler/toolchain/np_toolchain_runner.pas" "ExpandFileName"
require_repo_token "compiler/frontend/np_workspace_model.pas" "ExpandFileName"
require_repo_token "rtl/core/sysutils/np_sysutils.pas" "unit SysUtils;"
require_repo_token "rtl/core/classes/np_classes.pas" "unit Classes;"
require_repo_token "core/src/nextpas.core.collections.element_manager.pas" "InitializeArray"
require_repo_token "core/src/nextpas.core.collections.element_manager.pas" "CopyArray"
require_repo_token "core/src/nextpas.core.collections.hashmap.swiss.pas" "GetTypeKind"

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
