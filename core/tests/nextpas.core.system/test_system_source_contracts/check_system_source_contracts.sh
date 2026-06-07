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

reject_token() {
  local path="$1"
  local token="$2"
  if rg -F --quiet -- "$token" "$CORE_ROOT/$path"; then
    fail "core/$path must not contain token: $token"
  fi
}

require_repo_reject_token() {
  local path="$1"
  local token="$2"
  if rg -F --quiet -- "$token" "$REPO_ROOT/$path"; then
    fail "$path must not contain token: $token"
  fi
}

require_repo_reject_regex() {
  local path="$1"
  local regex="$2"
  if rg --quiet -- "$regex" "$REPO_ROOT/$path"; then
    fail "$path must not match regex: $regex"
  fi
}

list_pascal_uses_units() {
  awk '
    function trim(s) {
      gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s)
      return s
    }
    function emit_units(line, parts, i, unit) {
      gsub(/\{[^}]*\}/, "", line)
      sub(/\/\/.*/, "", line)
      gsub(/^[ \t]*uses[ \t]*/, "", line)
      split(line, parts, /[,;]/)
      for (i in parts) {
        unit = trim(parts[i])
        if (unit != "" && unit !~ /^\$/) {
          print unit
        }
      }
    }
    /^[ \t]*uses[ \t]*/ {
      in_uses = 1
      emit_units($0)
      if ($0 ~ /;/) in_uses = 0
      next
    }
    in_uses {
      emit_units($0)
      if ($0 ~ /;/) in_uses = 0
    }
  ' "$1"
}

require_repo_not_uses_unit() {
  local path="$1"
  local forbidden_unit="$2"
  if list_pascal_uses_units "$REPO_ROOT/$path" | grep -Fx --quiet "$forbidden_unit"; then
    fail "$path must not directly use unit: $forbidden_unit"
  fi
}

reject_repo_uses_unit_under() {
  local root="$1"
  local forbidden_unit="$2"
  while IFS= read -r file_path; do
    if list_pascal_uses_units "$file_path" | grep -Fxi --quiet "$forbidden_unit"; then
      fail "${file_path#$REPO_ROOT/} must not directly use deferred unit: $forbidden_unit"
    fi
  done < <(find "$root" -type f \( -name '*.pas' -o -name '*.lpr' \))
}

require_file "docs/system/README.md"
require_file "docs/system/rtl-mapping.md"
require_file "docs/system/goal-tree.md"
require_file "docs/system/runtime-contracts.md"
require_file "docs/system/lifecycle-contracts.md"
require_file "docs/system/compatibility-facades.md"
require_file "docs/system/compatibility-matrix.md"
require_file "docs/system/typinfo-minimal-pressure.md"
require_file "docs/plans/2026-06-07-system-typinfo-minimal-unlock-review.md"
require_file "src/nextpas.core.system.typinfo.pas"
require_file "src/nextpas.core.system.sysutils.pas"

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
require_token "docs/system/README.md" "2026-06-07-system-typinfo-minimal-unlock-review.md"
require_token "docs/system/README.md" "nextpas.core.system.typinfo"
require_token "docs/system/README.md" "nextpas.core.system.sysutils"
require_token "docs/system/README.md" "minimal live unit"
require_token "docs/system/README.md" "Classes remain deferred"

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
  "TypInfo minimal live unit is unlocked" \
  'no public unit yet should exist for `nextpas.core.system.classes`' \
  "compatibility-facades.md" \
  "compatibility-matrix.md" \
  "typinfo-minimal-pressure.md"; do
  require_token "docs/system/goal-tree.md" "$token"
done

for token in \
  "rtl/core/sysutils/np_sysutils.pas" \
  "rtl/core/classes/np_classes.pas" \
  "compiler/tests/test_sysutils_createfmt_contract.pas" \
  "compiler/tests/test_typinfo_contract.pas" \
  "nextpas.core.system.sysutils" \
  "nextpas.core.system.typinfo" \
  "nextpas.core.system.classes" \
  "minimal live unit" \
  "compile-truth" \
  "migration"; do
  require_token "docs/system/compatibility-facades.md" "$token"
done

require_token "docs/system/compatibility-facades.md" 'A minimal live `nextpas.core.system.sysutils` unit exists'
require_token "docs/system/compatibility-facades.md" 'Format'
require_token "docs/system/compatibility-facades.md" 'Exception.CreateFmt'
require_token "docs/system/compatibility-facades.md" "typinfo-minimal-pressure.md"
require_token "docs/system/compatibility-facades.md" "2026-06-07-system-typinfo-minimal-unlock-review.md"

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
require_token "docs/system/compatibility-matrix.md" "minimal live unit"
require_token "docs/system/compatibility-matrix.md" "minimal live compile-truth contract"
require_token "docs/system/compatibility-matrix.md" "minimal live exception-formatting facade"
require_token "docs/system/compatibility-matrix.md" "TTypeKind collections coverage"

for token in \
  "S4 TypInfo Minimal Pressure Audit" \
  "Review Judgment" \
  "Real Consumer Pressure" \
  "Owner Boundary" \
  "ABI Risks" \
  "Minimal Unlock Conditions" \
  "Deferred Boundary" \
  "minimal live unlock" \
  "compiler/tests/test_typinfo_contract.pas" \
  "core/src/nextpas.core.collections.element_manager.pas" \
  "core/src/nextpas.core.collections.hashmap.swiss.pas" \
  "core/src/nextpas.core.collections.btree.pas" \
  "core/src/nextpas.core.collections.concurrent.hashmap.pas"; do
  require_token "docs/system/typinfo-minimal-pressure.md" "$token"
done

require_token "docs/system/typinfo-minimal-pressure.md" '`nextpas.core.system.typinfo` is live'
require_token "docs/system/typinfo-minimal-pressure.md" "2026-06-07-system-typinfo-minimal-unlock-review.md"
require_token "docs/system/typinfo-minimal-pressure.md" "compile-truth"

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
  "Implemented minimal live unlock" \
  "Exact public symbol list" \
  "Exact owner boundary" \
  "Remaining blockers before expansion" \
  "Exact minimal file set for this unlock slice" \
  "Focused verification plan" \
  "Explicit non-goals" \
  "compiler/tests/test_typinfo_contract.pas" \
  "core/src/nextpas.core.collections.element_manager.pas" \
  "core/src/nextpas.core.collections.hashmap.swiss.pas" \
  "core/src/nextpas.core.collections.btree.pas" \
  "core/src/nextpas.core.collections.concurrent.hashmap.pas" \
  "core/src/nextpas.core.system.typinfo.pas"; do
  require_token "docs/plans/2026-06-07-system-typinfo-minimal-unlock-review.md" "$token"
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
[[ ! -e "$CORE_ROOT/src/nextpas.core.system.classes.pas" ]] || fail "S4 deferred: no live nextpas.core.system.classes unit expected yet"
reject_repo_uses_unit_under "$REPO_ROOT/compiler" "nextpas.core.system.classes"
reject_repo_uses_unit_under "$CORE_ROOT/src" "nextpas.core.system.classes"
reject_repo_uses_unit_under "$CORE_ROOT/tests" "nextpas.core.system.classes"

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
require_repo_token "compiler/tests/test_typinfo_contract.pas" "nextpas.core.system.typinfo"
require_repo_token "compiler/tests/test_typinfo_contract.pas" "InitializeArray"
require_repo_token "compiler/tests/test_typinfo_contract.pas" "CopyArray"
require_repo_token "compiler/tests/test_typinfo_contract.pas" "FinalizeArray"
require_repo_reject_regex "compiler/tests/test_typinfo_contract.pas" '^[[:space:]]*TypInfo[,;]'
require_repo_not_uses_unit "compiler/tests/test_typinfo_contract.pas" "TypInfo"
require_repo_token "compiler/toolchain/np_toolchain_runner.pas" "TFileStream"
require_repo_token "compiler/toolchain/np_toolchain_runner.pas" "ExpandFileName"
require_repo_token "compiler/frontend/np_workspace_model.pas" "ExpandFileName"
require_repo_token "rtl/core/sysutils/np_sysutils.pas" "unit SysUtils;"
require_repo_token "rtl/core/classes/np_classes.pas" "unit Classes;"
require_repo_token "core/src/nextpas.core.collections.element_manager.pas" "InitializeArray"
require_repo_token "core/src/nextpas.core.collections.element_manager.pas" "CopyArray"
require_repo_token "core/src/nextpas.core.collections.hashmap.swiss.pas" "GetTypeKind"

for path in \
  "core/src/nextpas.core.collections.arr.pas" \
  "core/src/nextpas.core.collections.base.pas" \
  "core/src/nextpas.core.collections.btree.pas" \
  "core/src/nextpas.core.collections.concurrent.hashmap.pas" \
  "core/src/nextpas.core.collections.element_manager.intf.pas" \
  "core/src/nextpas.core.collections.element_manager.pas" \
  "core/src/nextpas.core.collections.forward_list.pas" \
  "core/src/nextpas.core.collections.hashmap.pas" \
  "core/src/nextpas.core.collections.hashmap.swiss.adapter.pas" \
  "core/src/nextpas.core.collections.hashmap.swiss.pas" \
  "core/src/nextpas.core.collections.intf.pas" \
  "core/src/nextpas.core.collections.list.pas" \
  "core/src/nextpas.core.collections.node.pas" \
  "core/src/nextpas.core.collections.priorityqueue.pas"; do
  require_repo_token "$path" "nextpas.core.system.typinfo"
  require_repo_reject_regex "$path" '^[[:space:]]*TypInfo[,;]'
  require_repo_reject_regex "$path" '^[[:space:]]*typinfo[,;]'
  require_repo_not_uses_unit "$path" "TypInfo"
  require_repo_not_uses_unit "$path" "typinfo"
done

require_token "src/nextpas.core.system.typinfo.pas" "unit nextpas.core.system.typinfo;"
require_token "src/nextpas.core.system.typinfo.pas" "PTypeInfo = TypInfo.PTypeInfo;"
require_token "src/nextpas.core.system.typinfo.pas" "TTypeKind = TypInfo.TTypeKind;"
require_token "src/nextpas.core.system.typinfo.pas" "tkInteger"
require_token "src/nextpas.core.system.typinfo.pas" "tkChar"
require_token "src/nextpas.core.system.typinfo.pas" "tkWChar"
require_token "src/nextpas.core.system.typinfo.pas" "tkBool"
require_token "src/nextpas.core.system.typinfo.pas" "tkEnumeration"
require_token "src/nextpas.core.system.typinfo.pas" "tkInt64"
require_token "src/nextpas.core.system.typinfo.pas" "tkQWord"
require_token "src/nextpas.core.system.typinfo.pas" "tkFloat"
require_token "src/nextpas.core.system.typinfo.pas" "tkSString"
require_token "src/nextpas.core.system.typinfo.pas" "tkAString"
require_token "src/nextpas.core.system.typinfo.pas" "tkLString"
require_token "src/nextpas.core.system.typinfo.pas" "tkUString"
require_token "src/nextpas.core.system.typinfo.pas" "tkWString"
require_token "src/nextpas.core.system.typinfo.pas" "tkVariant"
require_token "src/nextpas.core.system.typinfo.pas" "tkMethod"
require_token "src/nextpas.core.system.typinfo.pas" "tkPointer"
require_token "src/nextpas.core.system.typinfo.pas" "tkDynArray"
require_token "src/nextpas.core.system.typinfo.pas" "InitializeArray"
require_token "src/nextpas.core.system.typinfo.pas" "FinalizeArray"
require_token "src/nextpas.core.system.typinfo.pas" "CopyArray"
require_token "src/nextpas.core.system.typinfo.pas" "System.InitializeArray"
require_token "src/nextpas.core.system.typinfo.pas" "System.FinalizeArray"
require_token "src/nextpas.core.system.typinfo.pas" "System.CopyArray"
reject_token "src/nextpas.core.system.typinfo.pas" "GetEnumName"
reject_token "src/nextpas.core.system.typinfo.pas" "GetPropInfo"
reject_token "src/nextpas.core.system.typinfo.pas" "GetTypeData"
reject_token "src/nextpas.core.system.typinfo.pas" "TPropInfo"
reject_token "src/nextpas.core.system.typinfo.pas" "TTypeData"
reject_token "src/nextpas.core.system.typinfo.pas" "function TypeInfo"
reject_token "src/nextpas.core.system.typinfo.pas" "function GetTypeKind"

require_token "src/nextpas.core.system.pas" "procedure FreeAndNil"
require_token "src/nextpas.core.system.pas" "procedure SafeFree"
require_token "src/nextpas.core.system.pas" "function Supports"
require_token "src/nextpas.core.system.pas" "nextpas.core.base.utils.FreeAndNil"
require_token "src/nextpas.core.system.pas" "nextpas.core.base.utils.SafeFree"
require_token "src/nextpas.core.system.pas" "nextpas.core.base.utils.Supports"
require_token "src/nextpas.core.system.pas" "EConvertError = nextpas.core.exception.EConvertError;"
require_token "src/nextpas.core.system.pas" "EAssertionFailed = nextpas.core.exception.EAssertionFailed;"
reject_token "src/nextpas.core.system.pas" "SysUtils"
reject_token "src/nextpas.core.system.pas" "TypInfo"
reject_token "src/nextpas.core.system.pas" "Classes"

require_token "src/nextpas.core.system.sysutils.pas" "unit nextpas.core.system.sysutils;"
require_token "src/nextpas.core.system.sysutils.pas" "nextpas.core.exception"
require_token "src/nextpas.core.system.sysutils.pas" "nextpas.core.text.conv"
require_token "src/nextpas.core.system.sysutils.pas" "Exception = nextpas.core.exception.Exception;"
require_token "src/nextpas.core.system.sysutils.pas" "ExceptClass = nextpas.core.exception.ExceptClass;"
require_token "src/nextpas.core.system.sysutils.pas" "EConvertError = nextpas.core.exception.EConvertError;"
require_token "src/nextpas.core.system.sysutils.pas" "EAssertionFailed = nextpas.core.exception.EAssertionFailed;"
require_token "src/nextpas.core.system.sysutils.pas" "function Format"
require_token "src/nextpas.core.system.sysutils.pas" "nextpas.core.text.conv.Format"
reject_token "src/nextpas.core.system.sysutils.pas" "FileExists"
reject_token "src/nextpas.core.system.sysutils.pas" "DirectoryExists"
reject_token "src/nextpas.core.system.sysutils.pas" "ForceDirectories"
reject_token "src/nextpas.core.system.sysutils.pas" "FileSearch"
reject_token "src/nextpas.core.system.sysutils.pas" "ExpandFileName"
reject_token "src/nextpas.core.system.sysutils.pas" "ExtractFileDir"
reject_token "src/nextpas.core.system.sysutils.pas" "ExtractFileName"
reject_token "src/nextpas.core.system.sysutils.pas" "IncludeTrailingPathDelimiter"
reject_token "src/nextpas.core.system.sysutils.pas" "ExcludeTrailingPathDelimiter"
reject_token "src/nextpas.core.system.sysutils.pas" "GetEnvironmentVariable"
reject_token "src/nextpas.core.system.sysutils.pas" "Trim"
reject_token "src/nextpas.core.system.sysutils.pas" "SameText"
reject_token "src/nextpas.core.system.sysutils.pas" "LowerCase"
reject_token "src/nextpas.core.system.sysutils.pas" "UpperCase"
reject_token "src/nextpas.core.system.sysutils.pas" "IntToStr"
reject_token "src/nextpas.core.system.sysutils.pas" "StrToInt"
reject_token "src/nextpas.core.system.sysutils.pas" "Now"
reject_token "src/nextpas.core.system.sysutils.pas" "FormatDateTime"
reject_token "src/nextpas.core.system.sysutils.pas" "TFileStream"
reject_token "src/nextpas.core.system.sysutils.pas" "TStringList"

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
