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

require_repo_file() {
  local path="$1"
  [[ -s "$REPO_ROOT/$path" ]] || fail "required non-empty repo file missing: $path"
}

require_repo_token() {
  local path="$1"
  local token="$2"
  rg -F --quiet -- "$token" "$REPO_ROOT/$path" || fail "$path missing token: $token"
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
  if list_pascal_uses_units "$REPO_ROOT/$path" | grep -Fxi --quiet "$forbidden_unit"; then
    fail "$path must not directly use unit: $forbidden_unit"
  fi
}

list_unit_facade_surface() {
  local unit_path="$1"
  awk '
    function trim(s) {
      gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s)
      return s
    }
    function strip_pascal_line(s) {
      gsub(/\{[^}]*\}/, "", s)
      sub(/\/\/.*/, "", s)
      return trim(s)
    }
    function note_unknown(s) {
      print "[FAIL] unrecognized public interface declaration in " FILENAME ": " s > "/dev/stderr"
      unknown = 1
    }
    BEGIN {
      in_interface = 0
      section = ""
      type_depth = 0
      unknown = 0
    }
    END {
      if (unknown) {
        exit 2
      }
    }
    /^[ \t]*interface[ \t]*$/ {
      in_interface = 1
      next
    }
    /^[ \t]*implementation[ \t]*$/ {
      exit
    }
    !in_interface {
      next
    }
    {
      line = strip_pascal_line($0)
      if (line == "") {
        next
      }
      lower_line = tolower(line)
      if (lower_line ~ /^uses([ \t]|$)/) {
        section = "uses"
        if (line ~ /;/) {
          section = ""
        }
        next
      }
      if (section == "uses") {
        if (line ~ /;/) {
          section = ""
        }
        next
      }
      if (type_depth > 0) {
        if (lower_line ~ /^end[.;]?$/) {
          type_depth--
          if (type_depth < 0) {
            type_depth = 0
          }
        }
        next
      }
      if (lower_line == "const") {
        section = "const"
        next
      }
      if (lower_line == "type") {
        section = "type"
        next
      }
      if (lower_line == "var") {
        section = "var"
        next
      }
      if (lower_line == "threadvar") {
        section = "threadvar"
        next
      }
      if (lower_line == "resourcestring") {
        section = "resourcestring"
        next
      }
      if (match(line, /^generic[ \t]+procedure[ \t]+([A-Za-z_][A-Za-z0-9_]*)/, parts)) {
        section = ""
        print "procedure " parts[1]
        next
      }
      if (match(line, /^generic[ \t]+function[ \t]+([A-Za-z_][A-Za-z0-9_]*)/, parts)) {
        section = ""
        print "function " parts[1]
        next
      }
      if (match(line, /^procedure[ \t]+([A-Za-z_][A-Za-z0-9_]*)/, parts)) {
        section = ""
        print "procedure " parts[1]
        next
      }
      if (match(line, /^function[ \t]+([A-Za-z_][A-Za-z0-9_]*)/, parts)) {
        section = ""
        print "function " parts[1]
        next
      }
      if (match(line, /^operator[ \t]*([^ \t(]+)/, parts)) {
        section = ""
        print "operator " parts[1]
        next
      }
      if (section == "const" && match(line, /^([A-Za-z_][A-Za-z0-9_]*)[ \t=]/, parts)) {
        print "const " parts[1]
        next
      }
      if (section == "type" && match(line, /^generic[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t<]/, parts)) {
        print "type " parts[1]
        if (lower_line ~ /=[ \t]*(packed[ \t]+)?(class|record|object|interface)([ \t(;]|$)/) {
          type_depth = 1
        }
        next
      }
      if (section == "type" && match(line, /^([A-Za-z_][A-Za-z0-9_]*)[ \t=]/, parts)) {
        print "type " parts[1]
        if (lower_line ~ /=[ \t]*(packed[ \t]+)?(class|record|object|interface)([ \t(;]|$)/) {
          type_depth = 1
        }
        next
      }
      if (section == "var" && match(line, /^([A-Za-z_][A-Za-z0-9_]*)[ \t,:]/, parts)) {
        print "var " parts[1]
        next
      }
      if (section == "threadvar" && match(line, /^([A-Za-z_][A-Za-z0-9_]*)[ \t,:]/, parts)) {
        print "threadvar " parts[1]
        next
      }
      if (section == "resourcestring" && match(line, /^([A-Za-z_][A-Za-z0-9_]*)[ \t=]/, parts)) {
        print "resourcestring " parts[1]
        next
      }
      note_unknown(line)
    }
  ' "$unit_path"
}

list_root_facade_surface() {
  list_unit_facade_surface "$CORE_ROOT/src/nextpas.core.system.pas"
}

require_facade_surface_allowlist() {
  local label="$1"
  local actual="$2"
  local expected="$3"
  if [[ "$actual" != "$expected" ]]; then
    printf '[FAIL] %s public surface drifted\n' "$label" >&2
    printf '%s\n' '--- expected' >&2
    printf '%s\n' "$expected" >&2
    printf '%s\n' '--- actual' >&2
    printf '%s\n' "$actual" >&2
    exit 1
  fi
}

require_root_facade_surface_allowlist() {
  local actual expected
  actual="$(list_root_facade_surface)"
  expected="$(cat <<'EOF'
const NEXTPAS_SYSTEM_NAME
const MAX_SIZE_INT
const MAX_SIZE_UINT
const MIN_SIZE_INT
const SIZE_PTR
const SIZE_8
const SIZE_16
const SIZE_32
const SIZE_64
type SizeInt
type SizeUInt
type PtrInt
type PtrUInt
type NativeInt
type NativeUInt
type TBytes
type TByteSpan
type THashCode
type Exception
type ExceptClass
type EConvertError
type EAssertionFailed
type TErrorCategory
type ENextPasError
type ECore
type EInvariantViolation
type EArgumentNil
type EEmptyCollection
type EInvalidArgument
type EInvalidResult
type EInvalidState
type EOutOfRange
type ENotSupported
type ENotCompatible
type EInvalidOperation
type EOverflow
type EArgumentError
type ENullReferenceError
type EInvalidOperationError
type ENotImplementedError
type ENotSupportedError
type ETimeoutError
type ECancelledError
type EPermissionError
type ENotFoundError
type EAlreadyExistsError
type EResourceExhaustedError
type EIOError
type ENetworkError
type EParseError
type EIndexOutOfRangeError
type EOutOfMemoryError
type EOutOfMemory
const ecNone
const ecInvalidArgument
const ecNullReference
const ecInvalidOperation
const ecNotImplemented
const ecNotSupported
const ecTimeout
const ecCancelled
const ecInterrupted
const ecWouldBlock
const ecPermission
const ecNotFound
const ecAlreadyExists
const ecResourceExhausted
const ecIO
const ecNetwork
const ecParse
const ecInternal
procedure FreeAndNil
procedure SafeFree
procedure ZeroMem
procedure FillMem
procedure CopyMem
function CompareMem
function Supports
function Supports
EOF
)"
  require_facade_surface_allowlist "root facade" "$actual" "$expected"
}

require_sysutils_facade_surface_allowlist() {
  local actual expected
  actual="$(list_unit_facade_surface "$CORE_ROOT/src/nextpas.core.system.sysutils.pas")"
  expected="$(cat <<'EOF'
type Exception
type ExceptClass
type EConvertError
type EAssertionFailed
function Format
EOF
)"
  require_facade_surface_allowlist "sysutils facade" "$actual" "$expected"
}

require_typinfo_facade_surface_allowlist() {
  local actual expected
  actual="$(list_unit_facade_surface "$CORE_ROOT/src/nextpas.core.system.typinfo.pas")"
  expected="$(cat <<'EOF'
type PTypeInfo
type TTypeKind
const tkInteger
const tkChar
const tkWChar
const tkBool
const tkEnumeration
const tkInt64
const tkQWord
const tkFloat
const tkSet
const tkClass
const tkMethod
const tkSString
const tkAString
const tkLString
const tkUString
const tkWString
const tkVariant
const tkArray
const tkRecord
const tkInterface
const tkClassRef
const tkPointer
const tkDynArray
const tkProcVar
procedure InitializeArray
procedure FinalizeArray
procedure CopyArray
EOF
)"
  require_facade_surface_allowlist "typinfo facade" "$actual" "$expected"
}

require_facade_surface_parser_regression() {
  local fixture actual expected
  fixture="$(mktemp)"
  cat > "$fixture" <<'EOF'
unit parser_fixture;

interface

type
  TLeaked = class
  public
    procedure PublicMethod;
  end;
  generic TBox<T> = record
  end;

var
  LeakedVar: LongInt;
threadvar
  LeakedThreadVar: Pointer;
resourcestring
  LeakedResource = 'x';

operator +(const A, B: LongInt): LongInt;
generic function LeakedGeneric<T>(const AValue: T): T;

implementation

end.
EOF
  actual="$(list_unit_facade_surface "$fixture")"
  rm -f "$fixture"
  expected="$(cat <<'EOF'
type TLeaked
type TBox
var LeakedVar
threadvar LeakedThreadVar
resourcestring LeakedResource
operator +
function LeakedGeneric
EOF
)"
  require_facade_surface_allowlist "facade parser regression fixture" "$actual" "$expected"
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
require_token "docs/system/README.md" "Root facade live surface"
require_token "docs/system/README.md" "delegating to owner"
require_token "docs/system/README.md" "compiler/System compile-truth"
require_token "docs/system/README.md" "not unit-owned wrapper functions"
require_token "docs/system/README.md" "FillMem"
require_token "docs/system/README.md" "compiler/HIR contract live; no callable public facade"
require_token "docs/system/README.md" '| `np.system.process_init` | process-level runtime startup | compiler semantic contract live; runtime execution deferred |'
require_token "docs/system/README.md" '| `np.system.process_fini` | process-level runtime shutdown | compiler semantic contract live; runtime execution deferred |'
require_token "docs/system/README.md" '| `np.system.unit_init` | run a unit initialization entry | future compiler/runtime only |'
require_token "docs/system/README.md" '| `np.system.unit_fini` | run a unit finalization entry | future compiler/runtime only |'
require_token "docs/system/README.md" 'program, library and package roots project exact `runtime-contract` entries'
require_token "docs/system/README.md" "source-backed System truth"
require_token "docs/system/README.md" '`rtl/core/system/System.pas`'
require_token "docs/system/README.md" '`TObject.Free`'
require_token "docs/system/README.md" '`test-stage0-system-object-free-query`'
require_token "docs/system/README.md" "stage0 query evidence"
require_token "docs/system/rtl-mapping.md" "compiler/HIR contract live; no public facade"
require_token "docs/system/rtl-mapping.md" 'Program startup and shutdown | `compiler semantic contract live; runtime execution deferred`'
require_token "docs/system/rtl-mapping.md" "np.system.object_free"
require_token "docs/system/rtl-mapping.md" "source-backed System truth"
require_token "docs/system/rtl-mapping.md" '`rtl/core/system/System.pas`'
require_token "docs/system/rtl-mapping.md" '`TObject.Free`'
require_token "docs/system/rtl-mapping.md" '`test-stage0-system-object-free-query`'

for unit_name in System SysUtils TypInfo Classes ObjPas; do
  require_token "docs/system/rtl-mapping.md" "$unit_name"
done

for status in \
  "system-owned" \
  "system facade delegating to owner" \
  "compiler semantic contract live; runtime execution deferred" \
  "owned by another module, no system facade yet" \
  "future compiler/runtime only" \
  "explicitly out of scope"; do
  require_token "docs/system/rtl-mapping.md" "$status"
done

for phase in S0 S1 S2 S3 S4 S5; do
  require_token "docs/system/goal-tree.md" "$phase"
done
require_token "docs/system/goal-tree.md" "TypeInfo and GetTypeKind are compiler/System compile-truth imports"
require_token "docs/system/goal-tree.md" "not unit-owned wrapper functions"
require_token "docs/system/goal-tree.md" "process-level startup/shutdown semantic seed"
require_token "docs/system/goal-tree.md" "without upgrading runtime execution or unit lifecycle"
require_token "docs/system/goal-tree.md" "source-backed System truth"
require_token "docs/system/goal-tree.md" '`test-stage0-system-object-free-query`'
require_token "docs/system/goal-tree.md" "stage0 query evidence"

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
require_token "docs/system/compatibility-facades.md" "premature broad facade or host TypInfo mirror"
reject_token "docs/system/compatibility-facades.md" "a premature facade would freeze semantics"

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
require_token "docs/system/compatibility-matrix.md" "TTypeKind collections and structured kind coverage"

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
require_token "docs/system/typinfo-minimal-pressure.md" "system names only the minimal facade bridge"
reject_token "docs/system/typinfo-minimal-pressure.md" "system may later name the facade"

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
for helper in \
  "@np_intf_addref" \
  "@np_intf_release"; do
  require_token "docs/system/runtime-contracts.md" "$helper"
done
require_token "docs/system/runtime-contracts.md" "backend-private interface helpers"
require_token "docs/system/runtime-contracts.md" "not Pascal facade symbols"
require_token "docs/system/runtime-contracts.md" "not object-free completion"
require_token "docs/system/runtime-contracts.md" "not finalized reference-counting strategy"
require_repo_token "compiler/ir/np_hir_builder.pas" "Instr.IntrinsicName := 'intf_addref';"
require_repo_token "compiler/ir/np_hir_builder.pas" "Instr.IntrinsicName := 'intf_release';"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "call void @np_intf_addref"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "call void @np_intf_release"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "define internal void @np_intf_addref"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "define internal void @np_intf_release"
for helper in \
  "@np_alloc" \
  "@np_free" \
  "@np_object_alloc" \
  "@np_allocator_fault"; do
  require_token "docs/system/runtime-contracts.md" "$helper"
done
require_token "docs/system/runtime-contracts.md" "backend-private allocator helpers"
require_token "docs/system/runtime-contracts.md" "not allocator owner transfer"
for helper in \
  "@np_memcpy" \
  "@np_memzero"; do
  require_token "docs/system/runtime-contracts.md" "$helper"
done
require_token "docs/system/runtime-contracts.md" "backend-private memory helpers"
require_token "docs/system/runtime-contracts.md" 'not aliases for public `CopyMem` / `ZeroMem`'
require_token "docs/system/runtime-contracts.md" "not raw memory facade expansion"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "define internal void @np_memcpy"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "define internal void @np_memzero"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "call void @np_memcpy"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "call void @np_memzero"
require_repo_token "tests/hir/test_hir_class_alloc_contract.pas" "define internal void @np_memzero"
require_repo_token "tests/hir/test_hir_dynarray_release_contract.pas" "call {ptr, i64} @np_str_concat("
for helper in \
  "np.system.object_free" \
  "np.system.object_free.destroy" \
  "np.system.object_free.cleanup" \
  "np.system.object_free.release"; do
  require_token "docs/system/runtime-contracts.md" "$helper"
done
require_token "docs/system/runtime-contracts.md" "object-free-runtime"
require_token "docs/system/runtime-contracts.md" "cleanup-class"
require_token "docs/system/runtime-contracts.md" "nil-guard true"
require_token "docs/system/runtime-contracts.md" "heap-release true"
require_token "docs/system/runtime-contracts.md" "@np_object_free_release"
require_token "docs/system/runtime-contracts.md" "backend-private helper"
require_token "docs/system/runtime-contracts.md" "must not walk object fields"
for token in \
  "np.system.halt" \
  "halt-call-runtime" \
  "explicit program termination" \
  'HIR intrinsic `halt`' \
  "backend-private termination lowering" \
  "syscall inline assembly"; do
  require_token "docs/system/runtime-contracts.md" "$token"
done
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "halt-call-runtime"
require_repo_token "compiler/ir/np_hir_builder.pas" "Instr.IntrinsicName := 'halt';"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" 'movq $$60, %rax; syscall'
require_repo_token "compiler/ir/np_hir_types.pas" "hnkHaltCallRuntime"
require_repo_token "compiler/tests/test_semantic_hir_expr_producer.pas" "TestHaltRuntimeExprProducer"
require_repo_token "tests/hir/test_hir_node_kind.pas" "halt-call-runtime"
require_token "docs/system/runtime-contracts.md" "compiler-planned cleanup"
require_token "docs/system/runtime-contracts.md" "field-agnostic"
require_token "docs/system/runtime-contracts.md" "Compiler HIR may project"
require_token "docs/system/runtime-contracts.md" "source-backed System truth"
require_token "docs/system/runtime-contracts.md" '`rtl/core/system/System.pas`'
require_token "docs/system/runtime-contracts.md" '`TObject.Free`'
require_token "docs/system/runtime-contracts.md" "@np_object_release_valid"
require_token "docs/system/runtime-contracts.md" "@np_object_release_invalid"
require_token "docs/system/runtime-contracts.md" "not allocator free completion"
require_token "docs/system/runtime-contracts.md" "array of interface"
require_token "docs/system/runtime-contracts.md" "@np_dynarray_resize"
require_token "docs/system/runtime-contracts.md" "@np_dynarray_release"
require_token "docs/system/runtime-contracts.md" "@np_dynarray_fault"
require_token "docs/system/runtime-contracts.md" "dynamic-array fault helper"
require_token "docs/system/runtime-contracts.md" "not public ABI"
require_token "docs/system/runtime-contracts.md" "semantic contract projection only"
require_token "docs/system/runtime-contracts.md" "Borrowed dynamic-array parameters"
require_token "docs/system/README.md" "managed dynamic-array operations"
require_token "docs/system/goal-tree.md" "managed dynamic-array compiler contract projection"

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
  "@np_try_push" \
  "@np_try_pop" \
  "@np_finally_end" \
  "@np_except_end" \
  "@np_raise"; do
  require_token "docs/system/lifecycle-contracts.md" "$helper"
done
require_token "docs/system/lifecycle-contracts.md" "backend-private exception helpers"
require_token "docs/system/lifecycle-contracts.md" "not public Pascal facade"
require_token "docs/system/lifecycle-contracts.md" "not final unwind ABI"
require_token "docs/system/lifecycle-contracts.md" "not exception taxonomy"
require_repo_file "tests/hir/test_hir_exception.pas"
require_repo_token "tests/hir/test_hir_exception.pas" "hir-exception-status=pass"
require_repo_token "tests/hir/test_hir_exception.pas" "np_try_push"
require_repo_token "tests/hir/test_hir_exception.pas" "np_finally_end"
require_repo_token "tests/hir/test_hir_exception.pas" "np_try_pop"
require_repo_token "tests/hir/test_hir_exception.pas" "np_except_end"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "call void @np_try_push"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "call void @np_try_pop"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "call void @np_finally_end"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "call void @np_except_end"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "call void @np_raise"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "define internal void @np_try_push"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "define internal void @np_try_pop"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "define internal void @np_finally_end"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "define internal void @np_except_end"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "define internal void @np_raise"

for token in \
  "Process Lifecycle" \
  "compiler" \
  "semantic seed truth" \
  "runtime-contract" \
  "np.system.process_init" \
  "np.system.process_fini" \
  "program, library or package" \
  "Runtime execution of process startup/shutdown remains deferred" \
  'No callable `nextpas.core.system` facade' \
  "Unit initialization and finalization are not upgraded"; do
  require_token "docs/system/lifecycle-contracts.md" "$token"
done

reject_token "docs/system/lifecycle-contracts.md" 'No `nextpas.core.system.typinfo` unit is created in this slice.'
require_token "docs/system/lifecycle-contracts.md" "minimal TypInfo facade is live, but S3 still does not freeze RTTI metadata layout"
require_token "docs/system/lifecycle-contracts.md" "contract vocabulary only, not public Pascal facade"
require_token "docs/system/runtime-contracts.md" "contract vocabulary only, not public Pascal facade"

for helper in \
  "np.system.unit_init" \
  "np.system.unit_fini" \
  "np.system.runtime_fault"; do
  require_token "docs/system/lifecycle-contracts.md" "$helper"
done

require_repo_token "compiler/sema/np_semantic_analyzer.pas" "SeedRuntimeContracts"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "np.system.process_init"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "np.system.process_fini"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "FModel.AddRuntimeContract(RuntimeContracts[Index])"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "FModel.AddTypedHirNode('runtime-contract', RuntimeContracts[Index], 0, 0, '')"
require_repo_token "compiler/sema/np_semantic_model.pas" "function RuntimeContractAt(const AIndex: LongInt): TRuntimeContract;"
require_repo_file "tests/semantic/test_semantic_runtime_contract_seed.pas"
require_repo_token "tests/semantic/test_semantic_runtime_contract_seed.pas" "semantic-runtime-contract-seed-status=pass"
require_repo_token "tests/semantic/test_semantic_runtime_contract_seed.pas" "AssertRuntimeContractAt(Model, 0, 'np.system.process_init')"
require_repo_token "tests/semantic/test_semantic_runtime_contract_seed.pas" "AssertRuntimeContractAt(Model, 1, 'np.system.process_fini')"
require_repo_token "tests/semantic/test_semantic_runtime_contract_seed.pas" "program-must-not-seed-unit-init"
require_repo_token "tests/semantic/test_semantic_runtime_contract_seed.pas" "unit-must-not-seed-process-init"

[[ ! -e "$CORE_ROOT/src/System.pas" ]] || fail "must not create bare FPC-conflicting System.pas"
[[ ! -e "$CORE_ROOT/src/system.pas" ]] || fail "must not create bare FPC-conflicting system.pas"
[[ ! -e "$CORE_ROOT/src/nextpas.core.system.classes.pas" ]] || fail "S4 deferred: no live nextpas.core.system.classes unit expected yet"
reject_repo_uses_unit_prefix_under() {
  local root="$1"
  local forbidden_prefix match
  local -a pascal_files
  forbidden_prefix="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
  mapfile -d '' pascal_files < <(find "$root" -type f \( -name '*.pas' -o -name '*.lpr' \) -print0)
  (( ${#pascal_files[@]} == 0 )) && return 0
  match="$(
    awk -v prefix="$forbidden_prefix" -v repo="$REPO_ROOT/" '
      function trim(s) {
        gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s)
        return s
      }
      function lower(s) {
        return tolower(s)
      }
      function emit_units(line, parts, i, unit, lower_unit, display_file) {
        gsub(/\{[^}]*\}/, "", line)
        sub(/\/\/.*/, "", line)
        gsub(/^[ \t]*uses[ \t]*/, "", line)
        split(line, parts, /[,;]/)
        for (i in parts) {
          unit = trim(parts[i])
          lower_unit = lower(unit)
          if (unit != "" && unit !~ /^\$/ && (lower_unit == prefix || index(lower_unit, prefix ".") == 1)) {
            display_file = FILENAME
            sub(repo, "", display_file)
            print display_file
            exit 0
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
    ' "${pascal_files[@]}"
  )"
  [[ -z "$match" ]] || fail "$match must not directly use deferred unit prefix: $2"
}

require_system_unit_filename_allowlist() {
  local file_path filename
  while IFS= read -r file_path; do
    filename="$(basename "$file_path")"
    case "$filename" in
      nextpas.core.system.pas|nextpas.core.system.sysutils.pas|nextpas.core.system.typinfo.pas)
        ;;
      nextpas.core.system*.pas)
        fail "unreviewed system unit filename: src/$filename"
        ;;
    esac
  done < <(find "$CORE_ROOT/src" -maxdepth 1 -name 'nextpas.core.system*.pas' | sort)
}

require_system_unit_filename_allowlist
reject_repo_uses_unit_prefix_under "$REPO_ROOT/compiler" "nextpas.core.system.classes"
reject_repo_uses_unit_prefix_under "$CORE_ROOT/src" "nextpas.core.system.classes"
reject_repo_uses_unit_prefix_under "$CORE_ROOT/tests" "nextpas.core.system.classes"

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
require_repo_token "compiler/tests/test_typinfo_contract.pas" "compiler TypInfo interface reference lifecycle contract"
require_repo_token "compiler/tests/test_typinfo_contract.pas" "CopyArray(InterfaceDestValues, InterfaceSourceValues, TypeInfo(ISystemTypInfoContractProbe)"
require_repo_token "compiler/tests/test_typinfo_contract.pas" "FinalizeArray(InterfaceSourceValues, TypeInfo(ISystemTypInfoContractProbe)"
require_repo_token "compiler/tests/test_typinfo_contract.pas" "GetTypeKind(ISystemTypInfoContractProbe) <> tkInterface"
require_repo_token "compiler/tests/test_typinfo_contract.pas" "GetTypeKind(TSystemTypInfoContractProbeClass) <> tkClassRef"
require_repo_token "compiler/tests/test_typinfo_contract.pas" "GetTypeKind(TSystemTypInfoProcVar) <> tkProcVar"
require_repo_token "compiler/tests/test_typinfo_contract.pas" "GetTypeKind(TSystemTypInfoRecord) <> tkRecord"
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
require_repo_token "core/tests/nextpas.core.collections/test_managed_types/test_managed_types.lpr" "TArray string managed TypeInfo consumer contract"
require_repo_token "core/tests/nextpas.core.collections/test_managed_types/test_managed_types.lpr" "LA.Copy(0, 1, 4)"
require_repo_token "core/tests/nextpas.core.collections/test_managed_types/test_managed_types.lpr" "LA.Read(0, LReadBack, 6)"
require_repo_token "tests/hir/test_hir_dynarray_release_contract.pas" "ManagedStringDynArraySource"
require_repo_token "tests/hir/test_hir_dynarray_release_contract.pas" "ManagedInterfaceDynArraySource"
require_repo_token "tests/hir/test_hir_dynarray_release_contract.pas" "BorrowedManagedStringDynArraySource"
require_repo_token "tests/hir/test_hir_dynarray_release_contract.pas" "BorrowedManagedInterfaceDynArraySource"
require_repo_token "tests/hir/test_hir_dynarray_release_contract.pas" "AssertNoManagedDynArrayRuntimeContracts"
require_repo_token "tests/hir/test_hir_dynarray_release_contract.pas" "np.system.dynarray_set_length"
require_repo_token "tests/hir/test_hir_dynarray_release_contract.pas" "np.system.dynarray_fini"
require_repo_token "tests/hir/test_hir_dynarray_release_contract.pas" "np.system.string_fini"
require_repo_token "tests/hir/test_hir_dynarray_release_contract.pas" "np.system.interface_release"
require_repo_token "tests/hir/test_hir_dynarray_release_contract.pas" "define internal ptr @np_dynarray_resize("
require_repo_token "tests/hir/test_hir_dynarray_release_contract.pas" "define internal void @np_dynarray_release("
require_repo_token "tests/hir/test_hir_dynarray_release_contract.pas" "define internal void @np_dynarray_fault("
require_repo_token "tests/hir/test_hir_dynarray_release_runtime_smoke.pas" "define internal ptr @np_dynarray_resize("
require_repo_token "tests/hir/test_hir_dynarray_release_runtime_smoke.pas" "define internal void @np_dynarray_release("
require_repo_token "tests/hir/test_hir_dynarray_release_runtime_smoke.pas" "define internal void @np_dynarray_fault("
require_repo_token "tests/hir/test_hir_dynarray_release_runtime_smoke.pas" "hir-dynarray-release-runtime-smoke-status=pass"
require_repo_reject_regex "tests/hir/test_hir_dynarray_release_contract.pas" "missing-managed-string-dynarray-resize-call"
require_repo_reject_regex "tests/hir/test_hir_dynarray_release_contract.pas" "missing-managed-interface-dynarray-resize-call"
require_repo_reject_regex "tests/hir/test_hir_dynarray_release_contract.pas" "managed-string-dynarray-still-bare-arr-alloc"
require_repo_reject_regex "tests/hir/test_hir_dynarray_release_contract.pas" "managed-interface-dynarray-still-bare-arr-alloc"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "MarkDynArraySetLengthContract"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "MarkDynArrayFiniContract"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "DynArrayElemTypeNeedsManagedContract"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "DynArrayElemTypeIsManagedInterface"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "np.system.dynarray_set_length"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "np.system.dynarray_fini"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "np.system.string_fini"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "np.system.interface_release"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "define internal ptr @np_dynarray_resize"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "define internal void @np_dynarray_release"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "define internal void @np_dynarray_fault"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "call void @np_dynarray_fault"
require_repo_file "tests/hir/test_hir_object_free_contract.pas"
require_repo_file "tests/semantic/test_semantic_call_bindings.pas"
require_repo_token "tests/hir/test_hir_object_free_contract.pas" "object-free-runtime"
require_repo_token "tests/hir/test_hir_object_free_contract.pas" "np.system.object_free"
require_repo_token "tests/hir/test_hir_object_free_contract.pas" "np.system.object_free.destroy"
require_repo_token "tests/hir/test_hir_object_free_contract.pas" "np.system.object_free.release"
require_repo_token "tests/hir/test_hir_object_free_contract.pas" "@np_object_free_release"
require_repo_token "tests/hir/test_hir_object_free_contract.pas" "@np_object_release_valid"
require_repo_token "tests/hir/test_hir_object_free_contract.pas" "@np_object_release_invalid"
require_repo_token "tests/hir/test_hir_object_free_contract.pas" "object-free-release-helper-must-not-walk-fields"
require_repo_file "tests/hir/test_hir_field_dynarray_contract.pas"
require_repo_file "tests/hir/test_hir_field_dynarray_release_runtime_smoke.pas"
require_repo_token "tests/hir/test_hir_field_dynarray_contract.pas" "setlength-field-arr-runtime"
require_repo_token "tests/hir/test_hir_field_dynarray_contract.pas" "np_object_dynarray_cleanup_TDerived"
require_repo_token "tests/hir/test_hir_field_dynarray_contract.pas" "np_object_dynarray_cleanup_TBase"
require_repo_token "tests/hir/test_hir_field_dynarray_contract.pas" "hir-field-dynarray-contract-status=pass"
require_repo_token "tests/hir/test_hir_field_dynarray_release_runtime_smoke.pas" "define internal void @np_object_dynarray_cleanup_TWorker(ptr "
require_repo_token "tests/hir/test_hir_field_dynarray_release_runtime_smoke.pas" "define internal void @np_object_dynarray_cleanup_TBase(ptr "
require_repo_token "tests/hir/test_hir_field_dynarray_release_runtime_smoke.pas" "free-worker-destroy-cleanup-release-order"
require_repo_token "tests/hir/test_hir_field_dynarray_release_runtime_smoke.pas" "hir-field-dynarray-release-runtime-smoke-status=pass"
require_repo_file "tests/hir/test_hir_large_alloc_runtime_smoke.pas"
require_repo_token "tests/hir/test_hir_large_alloc_runtime_smoke.pas" "call ptr @np_alloc(i64 65536)"
require_repo_token "tests/hir/test_hir_large_alloc_runtime_smoke.pas" "call void @np_free(ptr %payload, i64 65536)"
require_repo_token "tests/hir/test_hir_large_alloc_runtime_smoke.pas" "call ptr @np_object_alloc(i64 70001)"
require_repo_token "tests/hir/test_hir_large_alloc_runtime_smoke.pas" "call void @np_object_free_release(ptr %obj)"
require_repo_token "tests/hir/test_hir_large_alloc_runtime_smoke.pas" "hir-large-alloc-runtime-smoke-status=pass"
require_repo_file "rtl/core/system/System.pas"
require_repo_token "rtl/core/system/System.pas" "unit System;"
require_repo_token "rtl/core/system/System.pas" "TObject = class"
require_repo_token "rtl/core/system/System.pas" "constructor Create;"
require_repo_token "rtl/core/system/System.pas" "destructor Destroy; virtual;"
require_repo_token "rtl/core/system/System.pas" "procedure Free;"
require_repo_token "docs/architecture/runtime-bootstrap-specification.md" 'source-backed `System` truth'
require_repo_token "docs/architecture/runtime-bootstrap-specification.md" '`rtl/core/system/System.pas`'
require_repo_token "docs/architecture/runtime-bootstrap-specification.md" '`TObject.Free`'
require_repo_token "tests/semantic/test_semantic_call_bindings.pas" "np.system.object_free"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "object-free-runtime"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "cleanup-class "
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "nil-guard true"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "heap-release true"
require_repo_token "compiler/ir/np_hir_builder.pas" "np.system.object_free.destroy"
require_repo_token "compiler/ir/np_hir_builder.pas" "np.system.object_free.cleanup"
require_repo_token "compiler/ir/np_hir_builder.pas" "np.system.object_free.release"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "np.system.object_free"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "define internal void @np_object_free_release"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "define internal void @np_object_release_valid"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "define internal void @np_object_release_invalid"

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
require_token "src/nextpas.core.system.typinfo.pas" "tkSet"
require_token "src/nextpas.core.system.typinfo.pas" "tkClass"
require_token "src/nextpas.core.system.typinfo.pas" "tkMethod"
require_token "src/nextpas.core.system.typinfo.pas" "tkSString"
require_token "src/nextpas.core.system.typinfo.pas" "tkAString"
require_token "src/nextpas.core.system.typinfo.pas" "tkLString"
require_token "src/nextpas.core.system.typinfo.pas" "tkUString"
require_token "src/nextpas.core.system.typinfo.pas" "tkWString"
require_token "src/nextpas.core.system.typinfo.pas" "tkVariant"
require_token "src/nextpas.core.system.typinfo.pas" "tkArray"
require_token "src/nextpas.core.system.typinfo.pas" "tkRecord"
require_token "src/nextpas.core.system.typinfo.pas" "tkInterface"
require_token "src/nextpas.core.system.typinfo.pas" "tkClassRef"
require_token "src/nextpas.core.system.typinfo.pas" "tkPointer"
require_token "src/nextpas.core.system.typinfo.pas" "tkDynArray"
require_token "src/nextpas.core.system.typinfo.pas" "tkProcVar"
require_token "src/nextpas.core.system.typinfo.pas" "InitializeArray"
require_token "src/nextpas.core.system.typinfo.pas" "FinalizeArray"
require_token "src/nextpas.core.system.typinfo.pas" "CopyArray"
require_token "src/nextpas.core.system.typinfo.pas" "System.InitializeArray"
require_token "src/nextpas.core.system.typinfo.pas" "System.FinalizeArray"
require_token "src/nextpas.core.system.typinfo.pas" "System.CopyArray"
require_typinfo_facade_surface_allowlist
reject_token "src/nextpas.core.system.typinfo.pas" "GetEnumName"
reject_token "src/nextpas.core.system.typinfo.pas" "GetEnumValue"
reject_token "src/nextpas.core.system.typinfo.pas" "GetPropInfo"
reject_token "src/nextpas.core.system.typinfo.pas" "GetPropList"
reject_token "src/nextpas.core.system.typinfo.pas" "GetTypeData"
reject_token "src/nextpas.core.system.typinfo.pas" "IsPublishedProp"
reject_token "src/nextpas.core.system.typinfo.pas" "SetPropValue"
reject_token "src/nextpas.core.system.typinfo.pas" "PropCount"
reject_token "src/nextpas.core.system.typinfo.pas" "TPropInfo"
reject_token "src/nextpas.core.system.typinfo.pas" "TTypeData"
reject_token "src/nextpas.core.system.typinfo.pas" "function TypeInfo"
reject_token "src/nextpas.core.system.typinfo.pas" "function GetTypeKind"
require_token "tests/nextpas.core.system/test_system_typinfo_minimal/test_system_typinfo_minimal.lpr" "integer PTypeInfo identity compile-truth"
require_token "tests/nextpas.core.system/test_system_typinfo_minimal/test_system_typinfo_minimal.lpr" "PTypeInfo kind consistency compile-truth"
require_token "tests/nextpas.core.system/test_system_typinfo_minimal/test_system_typinfo_minimal.lpr" "structured kind aliases compile-truth"
require_token "tests/nextpas.core.system/test_system_typinfo_minimal/test_system_typinfo_minimal.lpr" "tkInterface"
require_token "tests/nextpas.core.system/test_system_typinfo_minimal/test_system_typinfo_minimal.lpr" "tkClassRef"
require_token "tests/nextpas.core.system/test_system_typinfo_minimal/test_system_typinfo_minimal.lpr" "tkProcVar"
require_token "tests/nextpas.core.system/test_system_typinfo_minimal/test_system_typinfo_minimal.lpr" "tkRecord"
require_token "tests/nextpas.core.system/test_system_typinfo_minimal/test_system_typinfo_minimal.lpr" "managed array lifecycle helpers"
require_token "tests/nextpas.core.system/test_system_typinfo_minimal/test_system_typinfo_minimal.lpr" "InitializeArray(LSource"
require_token "tests/nextpas.core.system/test_system_typinfo_minimal/test_system_typinfo_minimal.lpr" "CopyArray(LDest"
require_token "tests/nextpas.core.system/test_system_typinfo_minimal/test_system_typinfo_minimal.lpr" "FinalizeArray(LDest"
require_token "tests/nextpas.core.system/test_system_typinfo_minimal/test_system_typinfo_minimal.lpr" "interface reference array lifecycle helpers"
require_token "tests/nextpas.core.system/test_system_typinfo_minimal/test_system_typinfo_minimal.lpr" "CopyArray(LDest, LSource, TypeInfo(ISystemTypInfoProbe)"
require_token "tests/nextpas.core.system/test_system_typinfo_minimal/test_system_typinfo_minimal.lpr" "FinalizeArray(LSource, TypeInfo(ISystemTypInfoProbe)"
require_token "tests/nextpas.core.system/Makefile" "test-typinfo-minimal"
require_token "tests/nextpas.core.system/test_system_typinfo_minimal/Makefile" "test: run compiler-contract"
require_token "tests/nextpas.core.system/Makefile" "test-object-free-runtime-contract"
require_token "tests/nextpas.core.system/Makefile" "OBJECT_FREE_RUNTIME_CONTRACT_SOURCE"
require_token "tests/nextpas.core.system/Makefile" "test_hir_object_free_contract.pas"
require_token "tests/nextpas.core.system/Makefile" "OBJECT_FREE_RUNTIME_CONTRACT_FPC_FLAGS"
require_token "tests/nextpas.core.system/Makefile" "OBJECT_FREE_RUNTIME_CONTRACT_BINARY"
require_token "tests/nextpas.core.system/Makefile" "test-field-dynarray-contract"
require_token "tests/nextpas.core.system/Makefile" "FIELD_DYNARRAY_CONTRACT_SOURCE"
require_token "tests/nextpas.core.system/Makefile" "test_hir_field_dynarray_contract.pas"
require_token "tests/nextpas.core.system/Makefile" "FIELD_DYNARRAY_CONTRACT_FPC_FLAGS"
require_token "tests/nextpas.core.system/Makefile" "FIELD_DYNARRAY_CONTRACT_BINARY"
require_token "tests/nextpas.core.system/Makefile" "test-field-dynarray-runtime-smoke"
require_token "tests/nextpas.core.system/Makefile" "FIELD_DYNARRAY_RUNTIME_SOURCE"
require_token "tests/nextpas.core.system/Makefile" "test_hir_field_dynarray_release_runtime_smoke.pas"
require_token "tests/nextpas.core.system/Makefile" "FIELD_DYNARRAY_RUNTIME_FPC_FLAGS"
require_token "tests/nextpas.core.system/Makefile" "FIELD_DYNARRAY_RUNTIME_BINARY"
require_token "tests/nextpas.core.system/Makefile" "test-large-alloc-runtime-smoke"
require_token "tests/nextpas.core.system/Makefile" "LARGE_ALLOC_RUNTIME_SOURCE"
require_token "tests/nextpas.core.system/Makefile" "test_hir_large_alloc_runtime_smoke.pas"
require_token "tests/nextpas.core.system/Makefile" "LARGE_ALLOC_RUNTIME_FPC_FLAGS"
require_token "tests/nextpas.core.system/Makefile" "LARGE_ALLOC_RUNTIME_BINARY"
require_repo_file "tests/fixtures/system_object_free/system_object_free_binding.pas"
require_repo_file "tests/fixtures/system_object_free/system_object_free_implicit_binding.pas"
require_repo_token "tests/fixtures/system_object_free/system_object_free_binding.pas" "Worker.Free"
require_repo_token "tests/fixtures/system_object_free/system_object_free_implicit_binding.pas" "Worker.Free"
require_token "tests/nextpas.core.system/Makefile" "test-stage0-system-object-free-query"
require_token "tests/nextpas.core.system/Makefile" "STAGE0_SYSTEM_OBJECT_FREE_QUERY_BUILD_DIR"
require_token "tests/nextpas.core.system/Makefile" "STAGE0_SYSTEM_OBJECT_FREE_QUERY_BINARY"
require_token "tests/nextpas.core.system/Makefile" "STAGE0_SYSTEM_OBJECT_FREE_QUERY_OUTPUT"
require_token "tests/nextpas.core.system/Makefile" "STAGE0_SYSTEM_OBJECT_FREE_QUERY_SOURCE"
require_token "tests/nextpas.core.system/Makefile" "STAGE0_SYSTEM_OBJECT_FREE_IMPLICIT_QUERY_SOURCE"
require_token "tests/nextpas.core.system/Makefile" "system_object_free_binding.pas"
require_token "tests/nextpas.core.system/Makefile" "system_object_free_implicit_binding.pas"
require_token "tests/nextpas.core.system/Makefile" "query symbols"
require_token "tests/nextpas.core.system/Makefile" "TObject.Free"
require_token "tests/nextpas.core.system/Makefile" "stage0-query-system-object-free-check=pass"
require_token "tests/nextpas.core.system/Makefile" "stage0-query-system-object-free-implicit-check=pass"

require_token "src/nextpas.core.system.pas" "NEXTPAS_SYSTEM_NAME = 'nextpas.core.system';"
require_token "src/nextpas.core.system.pas" "MAX_SIZE_INT = nextpas.core.base.MAX_SIZE_INT;"
require_token "src/nextpas.core.system.pas" "MAX_SIZE_UINT = nextpas.core.base.MAX_SIZE_UINT;"
require_token "src/nextpas.core.system.pas" "MIN_SIZE_INT = nextpas.core.base.MIN_SIZE_INT;"
require_token "src/nextpas.core.system.pas" "SIZE_PTR = nextpas.core.base.SIZE_PTR;"
require_token "src/nextpas.core.system.pas" "SIZE_8 = nextpas.core.base.SIZE_8;"
require_token "src/nextpas.core.system.pas" "SIZE_16 = nextpas.core.base.SIZE_16;"
require_token "src/nextpas.core.system.pas" "SIZE_32 = nextpas.core.base.SIZE_32;"
require_token "src/nextpas.core.system.pas" "SIZE_64 = nextpas.core.base.SIZE_64;"
require_token "src/nextpas.core.system.pas" "SizeInt = System.SizeInt;"
require_token "src/nextpas.core.system.pas" "SizeUInt = System.SizeUInt;"
require_token "src/nextpas.core.system.pas" "PtrInt = System.PtrInt;"
require_token "src/nextpas.core.system.pas" "PtrUInt = System.PtrUInt;"
require_token "src/nextpas.core.system.pas" "NativeInt = System.NativeInt;"
require_token "src/nextpas.core.system.pas" "NativeUInt = System.NativeUInt;"
require_token "src/nextpas.core.system.pas" "TBytes = nextpas.core.base.TBytes;"
require_token "src/nextpas.core.system.pas" "TByteSpan = nextpas.core.base.TByteSpan;"
require_token "src/nextpas.core.system.pas" "THashCode = nextpas.core.base.THashCode;"
require_token "src/nextpas.core.system.pas" "procedure FreeAndNil"
require_token "src/nextpas.core.system.pas" "procedure SafeFree"
require_token "src/nextpas.core.system.pas" "procedure ZeroMem"
require_token "src/nextpas.core.system.pas" "procedure FillMem"
require_token "src/nextpas.core.system.pas" "procedure CopyMem"
require_token "src/nextpas.core.system.pas" "function CompareMem"
require_token "src/nextpas.core.system.pas" "function Supports"
require_token "src/nextpas.core.system.pas" "nextpas.core.base.utils.FreeAndNil"
require_token "src/nextpas.core.system.pas" "nextpas.core.base.utils.SafeFree"
require_token "src/nextpas.core.system.pas" "nextpas.core.base.utils.ZeroMem"
require_token "src/nextpas.core.system.pas" "nextpas.core.base.utils.FillMem"
require_token "src/nextpas.core.system.pas" "nextpas.core.base.utils.CopyMem"
require_token "src/nextpas.core.system.pas" "nextpas.core.base.utils.CompareMem"
require_token "src/nextpas.core.system.pas" "nextpas.core.base.utils.Supports"
require_token "src/nextpas.core.system.pas" "Exception = nextpas.core.exception.Exception;"
require_token "src/nextpas.core.system.pas" "ExceptClass = nextpas.core.exception.ExceptClass;"
require_token "src/nextpas.core.system.pas" "TErrorCategory = nextpas.core.exception.TErrorCategory;"
require_token "src/nextpas.core.system.pas" "ENextPasError = nextpas.core.exception.ENextPasError;"
require_token "src/nextpas.core.system.pas" "ECore = nextpas.core.base.ECore;"
require_token "src/nextpas.core.system.pas" "EInvariantViolation = nextpas.core.base.EInvariantViolation;"
require_token "src/nextpas.core.system.pas" "EArgumentNil = nextpas.core.base.EArgumentNil;"
require_token "src/nextpas.core.system.pas" "EEmptyCollection = nextpas.core.base.EEmptyCollection;"
require_token "src/nextpas.core.system.pas" "EInvalidArgument = nextpas.core.base.EInvalidArgument;"
require_token "src/nextpas.core.system.pas" "EInvalidResult = nextpas.core.base.EInvalidResult;"
require_token "src/nextpas.core.system.pas" "EInvalidState = nextpas.core.base.EInvalidState;"
require_token "src/nextpas.core.system.pas" "EOutOfRange = nextpas.core.base.EOutOfRange;"
require_token "src/nextpas.core.system.pas" "ENotSupported = nextpas.core.base.ENotSupported;"
require_token "src/nextpas.core.system.pas" "ENotCompatible = nextpas.core.base.ENotCompatible;"
require_token "src/nextpas.core.system.pas" "EInvalidOperation = nextpas.core.base.EInvalidOperation;"
require_token "src/nextpas.core.system.pas" "EOverflow = nextpas.core.base.EOverflow;"
require_token "src/nextpas.core.system.pas" "EArgumentError = nextpas.core.errors.EArgumentError;"
require_token "src/nextpas.core.system.pas" "ENullReferenceError = nextpas.core.errors.ENullReferenceError;"
require_token "src/nextpas.core.system.pas" "EInvalidOperationError = nextpas.core.errors.EInvalidOperationError;"
require_token "src/nextpas.core.system.pas" "ENotImplementedError = nextpas.core.errors.ENotImplementedError;"
require_token "src/nextpas.core.system.pas" "ENotSupportedError = nextpas.core.errors.ENotSupportedError;"
require_token "src/nextpas.core.system.pas" "ETimeoutError = nextpas.core.errors.ETimeoutError;"
require_token "src/nextpas.core.system.pas" "ECancelledError = nextpas.core.errors.ECancelledError;"
require_token "src/nextpas.core.system.pas" "EPermissionError = nextpas.core.errors.EPermissionError;"
require_token "src/nextpas.core.system.pas" "ENotFoundError = nextpas.core.errors.ENotFoundError;"
require_token "src/nextpas.core.system.pas" "EAlreadyExistsError = nextpas.core.errors.EAlreadyExistsError;"
require_token "src/nextpas.core.system.pas" "EResourceExhaustedError = nextpas.core.errors.EResourceExhaustedError;"
require_token "src/nextpas.core.system.pas" "EIOError = nextpas.core.errors.EIOError;"
require_token "src/nextpas.core.system.pas" "ENetworkError = nextpas.core.errors.ENetworkError;"
require_token "src/nextpas.core.system.pas" "EParseError = nextpas.core.errors.EParseError;"
require_token "src/nextpas.core.system.pas" "EIndexOutOfRangeError = nextpas.core.errors.EIndexOutOfRangeError;"
require_token "src/nextpas.core.system.pas" "EOutOfMemoryError = nextpas.core.errors.EOutOfMemoryError;"
require_token "src/nextpas.core.system.pas" "EOutOfMemory = nextpas.core.errors.EOutOfMemory;"
require_token "src/nextpas.core.system.pas" "EConvertError = nextpas.core.exception.EConvertError;"
require_token "src/nextpas.core.system.pas" "EAssertionFailed = nextpas.core.exception.EAssertionFailed;"
require_token "src/nextpas.core.system.pas" "ecNone = nextpas.core.errors.ecNone;"
require_token "src/nextpas.core.system.pas" "ecInvalidArgument = nextpas.core.errors.ecInvalidArgument;"
require_token "src/nextpas.core.system.pas" "ecNullReference = nextpas.core.errors.ecNullReference;"
require_token "src/nextpas.core.system.pas" "ecInvalidOperation = nextpas.core.errors.ecInvalidOperation;"
require_token "src/nextpas.core.system.pas" "ecNotImplemented = nextpas.core.errors.ecNotImplemented;"
require_token "src/nextpas.core.system.pas" "ecNotSupported = nextpas.core.errors.ecNotSupported;"
require_token "src/nextpas.core.system.pas" "ecTimeout = nextpas.core.errors.ecTimeout;"
require_token "src/nextpas.core.system.pas" "ecCancelled = nextpas.core.errors.ecCancelled;"
require_token "src/nextpas.core.system.pas" "ecInterrupted = nextpas.core.errors.ecInterrupted;"
require_token "src/nextpas.core.system.pas" "ecWouldBlock = nextpas.core.errors.ecWouldBlock;"
require_token "src/nextpas.core.system.pas" "ecPermission = nextpas.core.errors.ecPermission;"
require_token "src/nextpas.core.system.pas" "ecNotFound = nextpas.core.errors.ecNotFound;"
require_token "src/nextpas.core.system.pas" "ecAlreadyExists = nextpas.core.errors.ecAlreadyExists;"
require_token "src/nextpas.core.system.pas" "ecResourceExhausted = nextpas.core.errors.ecResourceExhausted;"
require_token "src/nextpas.core.system.pas" "ecIO = nextpas.core.errors.ecIO;"
require_token "src/nextpas.core.system.pas" "ecNetwork = nextpas.core.errors.ecNetwork;"
require_token "src/nextpas.core.system.pas" "ecParse = nextpas.core.errors.ecParse;"
require_token "src/nextpas.core.system.pas" "ecInternal = nextpas.core.errors.ecInternal;"
require_token "tests/nextpas.core.system/test_system_facade/test_system_facade.lpr" "system constants mirror base compile-truth"
require_token "tests/nextpas.core.system/test_system_facade/test_system_facade.lpr" "system base carrier aliases mirror base compile-truth"
require_token "tests/nextpas.core.system/test_system_facade/test_system_facade.lpr" "system memory facade delegates full base utils contract"
require_token "tests/nextpas.core.system/test_system_facade/test_system_facade.lpr" "system FillMem delegates to base utils"
require_token "tests/nextpas.core.system/test_system_facade/test_system_facade.lpr" "system base error aliases mirror base compile-truth"
require_token "tests/nextpas.core.system/test_system_facade/test_system_facade.lpr" "system error taxonomy aliases mirror canonical owners"
require_repo_token "core/tests/nextpas.core.base/test_base/test_base.lpr" "CompareMem(nil, nil, 1)"
require_repo_token "core/tests/nextpas.core.base/test_base/test_base.lpr" "CompareMem(nil, @LA[0], 1)"
require_repo_token "core/tests/nextpas.core.base/test_base/test_base.lpr" "CompareMem(@LA[0], nil, 1)"
require_repo_token "core/tests/nextpas.core.base/test_base/test_base.lpr" "base FreeAndNil should nil before destructor execution"
require_repo_token "core/tests/nextpas.core.base/test_base/test_base.lpr" "base SafeFree should accept nil references"
require_repo_token "core/tests/nextpas.core.base/test_base/test_base.lpr" "base Supports(TObject) should query supported interfaces"
require_repo_token "core/tests/nextpas.core.base/test_base/test_base.lpr" "base Supports(IInterface) should query supported interfaces"
require_repo_token "core/tests/nextpas.core.base/test_base/test_base.lpr" "base Supports(TObject) should return false for nil object references"
require_repo_token "core/tests/nextpas.core.base/test_base/test_base.lpr" "base Supports(IInterface) should return false for nil interface references"
require_repo_token "core/tests/nextpas.core.base/test_base/test_base.lpr" "base Supports(TObject) should clear stale interfaces on unsupported queries"
require_repo_token "core/tests/nextpas.core.base/test_base/test_base.lpr" "base Supports(IInterface) should clear stale interfaces on unsupported queries"
require_facade_surface_parser_regression
require_root_facade_surface_allowlist
reject_token "src/nextpas.core.system.pas" "SysUtils"
reject_token "src/nextpas.core.system.pas" "TypInfo"
reject_token "src/nextpas.core.system.pas" "Classes"
reject_token "src/nextpas.core.system.pas" "DynArraySetLength"
reject_token "src/nextpas.core.system.pas" "DynArrayResize"
reject_token "src/nextpas.core.system.pas" "DynArrayRelease"
reject_token "src/nextpas.core.system.typinfo.pas" "DynArraySetLength"
reject_token "src/nextpas.core.system.typinfo.pas" "DynArrayResize"
reject_token "src/nextpas.core.system.typinfo.pas" "DynArrayRelease"

require_token "src/nextpas.core.system.sysutils.pas" "unit nextpas.core.system.sysutils;"
require_token "src/nextpas.core.system.sysutils.pas" "nextpas.core.exception"
require_token "src/nextpas.core.system.sysutils.pas" "nextpas.core.text.conv"
require_token "src/nextpas.core.system.sysutils.pas" "Exception = nextpas.core.exception.Exception;"
require_token "src/nextpas.core.system.sysutils.pas" "ExceptClass = nextpas.core.exception.ExceptClass;"
require_token "src/nextpas.core.system.sysutils.pas" "EConvertError = nextpas.core.exception.EConvertError;"
require_token "src/nextpas.core.system.sysutils.pas" "EAssertionFailed = nextpas.core.exception.EAssertionFailed;"
require_token "src/nextpas.core.system.sysutils.pas" "function Format"
require_token "src/nextpas.core.system.sysutils.pas" "nextpas.core.text.conv.Format"
require_sysutils_facade_surface_allowlist
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
