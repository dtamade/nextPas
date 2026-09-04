#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
REPO_ROOT="$(cd "$CORE_ROOT/.." && pwd)"

# shellcheck source=lib/helpers.sh
source "$SCRIPT_DIR/lib/helpers.sh"

# ============================================================================
# SECTION: Pascal interface surface parser
# ============================================================================

list_unit_facade_surface() {
  local unit_path="$1"
  awk '
    function trim(s) {
      gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s)
      return s
    }
    function strip_pascal_line(s,   i, j) {
      # Drop block comments ({...}) that span multiple lines: the previous
      # parser only removed single-line pairs, so the middle lines of a
      # multi-line comment were misread as interface declarations.
      if (in_block_comment) {
        i = index(s, "}")
        if (i == 0) {
          return ""
        }
        in_block_comment = 0
        s = substr(s, i + 1)
      }
      while ((i = index(s, "{")) > 0) {
        j = index(s, "}")
        if (j == 0) {
          in_block_comment = 1
          s = substr(s, 1, i - 1)
          break
        }
        s = substr(s, 1, i - 1) substr(s, j + 1)
      }
      sub(/\/\/.*/, "", s)
      return trim(s)
    }
    function note_unknown(s) {
      print "[FAIL] unrecognized public interface declaration in " FILENAME ": " s > "/dev/stderr"
      unknown = 1
    }
    BEGIN {
      in_interface = 0
      in_block_comment = 0
      pending_decl = 0
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
      if (pending_decl) {
        # Continuation of a multi-line function/procedure signature (the
        # parameter list did not close on the declaring line).
        if (line ~ /\)/) {
          pending_decl = 0
        }
        next
      }
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
        if ((line ~ /\(/) && (line !~ /\)/)) {
          pending_decl = 1
        }
        next
      }
      if (match(line, /^generic[ \t]+function[ \t]+([A-Za-z_][A-Za-z0-9_]*)/, parts)) {
        section = ""
        print "function " parts[1]
        if ((line ~ /\(/) && (line !~ /\)/)) {
          pending_decl = 1
        }
        next
      }
      if (match(line, /^procedure[ \t]+([A-Za-z_][A-Za-z0-9_]*)/, parts)) {
        section = ""
        print "procedure " parts[1]
        if ((line ~ /\(/) && (line !~ /\)/)) {
          pending_decl = 1
        }
        next
      }
      if (match(line, /^function[ \t]+([A-Za-z_][A-Za-z0-9_]*)/, parts)) {
        section = ""
        print "function " parts[1]
        if ((line ~ /\(/) && (line !~ /\)/)) {
          pending_decl = 1
        }
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
  list_inc_facade_surface "$CORE_ROOT/src/nextpas.core.system.fpc.inc"
}

list_inc_facade_surface() {
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
    BEGIN {
      section = ""
      type_depth = 0
    }
    {
      line = strip_pascal_line($0)
      if (line == "") {
        next
      }
      lower_line = tolower(line)
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
      if (section == "type" && match(line, /^([A-Za-z_][A-Za-z0-9_]*)[ \t=]/, parts)) {
        print "type " parts[1]
        next
      }
      if (section == "const" && match(line, /^([A-Za-z_][A-Za-z0-9_]*)[ \t=]/, parts)) {
        print "const " parts[1]
        next
      }
    }
  ' "$unit_path"
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
type TBytes
type TByteSpan
type THashCode
type Exception
type ExceptClass
type EConvertError
type EAssertionFailed
type EAbort
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
type EInterruptedError
type EWouldBlockError
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
function HTonN
function HTonN
function NToHs
function NToHs
function VarType
function VarIsNull
function VarIsEmpty
function VarIsClear
type TObject
type TClass
type TTypeKind
type SizeInt
type SizeUInt
type PtrInt
type PtrUInt
type NativeInt
type NativeUInt
type PByte
type PWord
type PLongInt
type PLongWord
type PInt64
type PQWord
type PPointer
type PSizeInt
type PSizeUInt
type ShortString
type AnsiString
type WideString
type UnicodeString
type Char
type AnsiChar
type WideChar
type IUnknown
type IInterface
type TGUID
type PGUID
type PVmt
type TVmt
type PInterfaceEntry
type TInterfaceEntry
type TInterfaceEntryType
type PInterfaceTable
type TInterfaceTable
type TMethod
type TVarType
type TVarData
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
type TBytes
type TStringArray
function Format
function CompareStr
function SameText
function IntToStr
function Int64ToStr
function IntToHex
function StrToInt
function StrToInt64
function TryStrToInt
function TryStrToInt64
function StrToIntDef
function StrToInt64Def
function StrToFloat
function FloatToStr
function CurrToStr
function BoolToStr
function BytesOf
function StringOf
function CompareMem
function Supports
function Supports
function HexStr
function HexStr
function Trim
function TrimLeft
function TrimRight
function UpperCase
function LowerCase
function Pos
function ExceptAddr
function ExceptFrameCount
function ExceptFrameAt
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
type PTypeData
type TTypeData
type PPropInfo
type PPropList
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
function GetPropInfo
function GetPropInfo
function GetPropList
function GetPropList
function GetEnumName
function GetEnumValue
EOF
)"
  require_facade_surface_allowlist "typinfo facade" "$actual" "$expected"
}

require_errors_facade_surface_allowlist() {
  local actual expected
  actual="$(list_unit_facade_surface "$CORE_ROOT/src/nextpas.core.system.errors.pas")"
  expected="$(cat <<'EOF'
type Exception
type ExceptClass
type EConvertError
type EAssertionFailed
type EAbort
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
type EInterruptedError
type EWouldBlockError
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
EOF
)"
  require_facade_surface_allowlist "errors facade" "$actual" "$expected"
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

# ============================================================================
# SECTION: Documentation existence and token checks
# ============================================================================

require_file "docs/system/README.md"
require_file "docs/system/rtl-mapping.md"
require_file "docs/system/goal-tree.md"
require_file "docs/system/runtime-contracts.md"
require_file "docs/system/lifecycle-contracts.md"
require_file "docs/system/compatibility-facades.md"
require_file "docs/system/compatibility-matrix.md"
require_file "docs/system/typinfo-minimal-pressure.md"
require_file "docs/plans/2026-06-07-system-typinfo-minimal-unlock-review.md"
require_file "docs/system/self-hosting-readiness.md"
require_file "docs/system/contract-coverage-table.md"
require_file "src/nextpas.core.system.typinfo.pas"
require_file "src/nextpas.core.system.sysutils.pas"
require_file "src/nextpas.core.system.errors.pas"
require_repo_file "docs/architecture/runtime-bootstrap-specification.md"

require_repo_token "docs/architecture/runtime-bootstrap-specification.md" "canonical compiler-root source"
require_repo_token "docs/architecture/runtime-bootstrap-specification.md" "system-projection-check"
require_token "docs/system/README.md" "M0 truth convergence"
require_token "docs/system/README.md" "not self-host ready"
require_token "docs/system/goal-tree.md" "canonical projection parity"
require_token "docs/system/self-hosting-readiness.md" "A -> B -> C has not executed"
require_token "docs/system/contract-coverage-table.md" "typed ledger is authoritative"

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
require_token "docs/system/README.md" "nextpas.core.system.errors"
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
  "Classes compatibility shim" \
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

# ============================================================================
# SECTION: Runtime contract name and helper mapping checks
# ============================================================================

require_repo_file "compiler/src/nextpas.compiler.ir.system_contracts.pas"

contract_ledger_tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$contract_ledger_tmp_dir"' EXIT
contract_constants="$contract_ledger_tmp_dir/contract-constants"
ledger_constants="$contract_ledger_tmp_dir/ledger-constants"
contract_values="$contract_ledger_tmp_dir/contract-values"
coverage_values="$contract_ledger_tmp_dir/coverage-values"
awk '
  match($0, /^[ \t]*(NPSYSTEM_[A-Z0-9_]+)[ \t]*=/, parts) {
    print parts[1]
  }
' "$CORE_ROOT/src/nextpas.core.system.contracts.pas" | sort >"$contract_constants"
awk '
  match($0, /^[ \t]*SemanticName:[ \t]*(NPSYSTEM_[A-Z0-9_]+)[ \t]*;/, parts) {
    print parts[1]
  }
' "$REPO_ROOT/compiler/src/nextpas.compiler.ir.system_contracts.pas" | sort >"$ledger_constants"
[[ -s "$contract_constants" ]] || fail "system contract declarations are empty"
[[ -s "$ledger_constants" ]] || fail "typed ledger semantic-name rows are empty"
if ! diff -u "$contract_constants" "$ledger_constants"; then
  fail "system contract constants and typed ledger are not one-to-one"
fi
awk -F "'" '
  /^[ \t]*NPSYSTEM_[A-Z0-9_]+[ \t]*=/ && $2 ~ /^np\.system\./ {
    print $2
  }
' "$CORE_ROOT/src/nextpas.core.system.contracts.pas" >"$contract_values"
if ! awk '
  $0 == "<!-- ledger-table:start -->" {
    if (in_table || saw_start) {
      exit 2
    }
    in_table = 1
    saw_start = 1
    next
  }
  $0 == "<!-- ledger-table:end -->" {
    if (!in_table || saw_end) {
      exit 2
    }
    in_table = 0
    saw_end = 1
    next
  }
  in_table && match($0, /^\| `([^`]+)` \|/, parts) {
    print parts[1]
  }
  END {
    if (!saw_start || !saw_end || in_table) {
      exit 2
    }
  }
' "$CORE_ROOT/docs/system/contract-coverage-table.md" >"$coverage_values"; then
  fail "contract coverage ledger table markers are missing or malformed"
fi
[[ -s "$contract_values" ]] || fail "system contract string values are empty"
[[ -s "$coverage_values" ]] || fail "contract coverage ledger rows are empty"
if ! diff -u "$contract_values" "$coverage_values"; then
  fail "contract coverage table must match system contract values in declaration order"
fi
rm -rf -- "$contract_ledger_tmp_dir"
trap - EXIT

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
  "np.system.heap_free" \
  "np.system.object_alloc"; do
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
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.builder" "AssignSystemContract(Instr, sckInterfaceAddRef)"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.builder" "AssignSystemContract(Instr, sckInterfaceRelease)"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "sckInterfaceAddRef:"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "sckInterfaceRelease:"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "declare void @np_intf_addref"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "declare void @np_intf_release"
# Halt is production typed HIR (sckHalt); IntrinsicName is semantic np.system.halt
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.builder" "AssignSystemContract(Instr, sckHalt)"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "sckHalt:"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.model" "sckHalt"
require_repo_file "tests/hir/test_hir_halt_contract.pas"
require_repo_token "tests/hir/test_hir_halt_contract.pas" "IsSystemContract(Instr, sckHalt)"
require_repo_token "tests/hir/test_hir_halt_contract.pas" "hir-halt-contract=pass"
require_repo_reject_regex "compiler/src" "Instr[.]IntrinsicName[[:space:]]*:=[[:space:]]*'halt'"
require_repo_reject_regex "compiler/src" "IntrinsicName[[:space:]]*=[[:space:]]*'halt'"
# GetMem/FreeMem + field arr path are production typed HIR (sckHeapAlloc/sckHeapFree)
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.builder" "AssignSystemContract(Instr, sckHeapAlloc)"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.builder" "AssignSystemContract(Instr, sckHeapFree)"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "sckHeapAlloc:"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "sckHeapFree:"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.model" "sckHeapAlloc"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.model" "sckHeapFree"
require_repo_file "tests/hir/test_hir_heap_contract.pas"
require_repo_token "tests/hir/test_hir_heap_contract.pas" "IsSystemContract(Instr, sckHeapAlloc)"
require_repo_token "tests/hir/test_hir_heap_contract.pas" "IsSystemContract(Instr, sckHeapFree)"
require_repo_token "tests/hir/test_hir_heap_contract.pas" "hir-heap-contract=pass"
require_repo_reject_regex "compiler/src" "Instr[.]IntrinsicName[[:space:]]*:=[[:space:]]*'getmem'"
require_repo_reject_regex "compiler/src" "Instr[.]IntrinsicName[[:space:]]*:=[[:space:]]*'freemem'"
require_repo_reject_regex "compiler/src" "IntrinsicName[[:space:]]*=[[:space:]]*'getmem'"
require_repo_reject_regex "compiler/src" "IntrinsicName[[:space:]]*=[[:space:]]*'freemem'"
# Production builder must not assign bare arr_alloc / class_alloc IntrinsicName
require_repo_reject_regex "compiler/src" "Instr[.]IntrinsicName[[:space:]]*:=[[:space:]]*'arr_alloc'"
require_repo_reject_regex "compiler/src" "Instr[.]IntrinsicName[[:space:]]*:=[[:space:]]*'class_alloc'"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "@np_alloc"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "@np_object_alloc"
# object_alloc typed HIR (class-new → sckObjectAlloc)
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.builder" "AssignSystemContract(Instr, sckObjectAlloc)"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "sckObjectAlloc:"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.model" "sckObjectAlloc"
require_repo_file "tests/hir/test_hir_object_alloc_contract.pas"
require_repo_token "tests/hir/test_hir_object_alloc_contract.pas" "IsSystemContract(Instr, sckObjectAlloc)"
require_repo_token "tests/hir/test_hir_object_alloc_contract.pas" "sckObjectAlloc"
require_repo_token "tests/hir/test_hir_object_alloc_contract.pas" "hir-object-alloc-contract=pass"
require_token "tests/nextpas.core.system/Makefile" "test_hir_object_alloc_contract.pas"
require_token "tests/nextpas.core.system/Makefile" "test-object-alloc-contract"
# managed_record_fini typed HIR (managed-record-cleanup → sckManagedRecordFini)
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.builder" "AssignSystemContract(Instr, sckManagedRecordFini)"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "sckManagedRecordFini:"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.model" "sckManagedRecordFini"
require_repo_file "tests/hir/test_hir_managed_record_contract.pas"
require_repo_token "tests/hir/test_hir_managed_record_contract.pas" "IsSystemContract(Instr, sckManagedRecordFini)"
require_repo_token "tests/hir/test_hir_managed_record_contract.pas" "sckManagedRecordFini"
require_repo_token "tests/hir/test_hir_managed_record_contract.pas" "hir-managed-record-contract=pass"
require_token "tests/nextpas.core.system/Makefile" "test_hir_managed_record_contract.pas"
require_token "tests/nextpas.core.system/Makefile" "test-managed-record-contract"
# Halt, heap, object_alloc mapping documented in runtime-contracts
require_token "docs/system/runtime-contracts.md" "typed \`sckHalt\`"
require_token "docs/system/runtime-contracts.md" "typed HIR \`sckHeapAlloc\`"
require_token "docs/system/runtime-contracts.md" "sckObjectAlloc"
require_token "docs/system/runtime-contracts.md" "sckManagedRecordFini"
require_token "docs/system/runtime-contracts.md" "arr_alloc"
require_token "docs/system/runtime-contracts.md" "class_alloc"
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
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "declare void @np_memcpy"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "declare void @np_memzero"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "call void @np_memset"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "call void @np_memmove"
require_repo_token "tests/hir/test_hir_dynarray_release_contract.pas" "call void @np_tstring_concat("
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
  "typed \`sckHalt\`" \
  "backend-private termination lowering" \
  "syscall inline assembly"; do
  require_token "docs/system/runtime-contracts.md" "$token"
done
require_repo_owner_family_token "compiler/src" "nextpas.compiler.sema.analyzer" "halt-call-runtime"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.builder" "AssignSystemContract(Instr, sckHalt)"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" 'movq $$60, %rax; syscall'
require_repo_token "compiler/src/nextpas.compiler.ir.hir.types.pas" "hnkHaltCallRuntime"
require_repo_token "compiler/tests/test_semantic_hir_expr_producer.pas" "TestHaltRuntimeExprProducer"
require_repo_token "tests/hir/test_hir_node_kind.pas" "halt-call-runtime"
require_token "tests/nextpas.core.system/Makefile" "test_hir_halt_contract.pas"
require_token "tests/nextpas.core.system/Makefile" "test-halt-contract"
require_token "tests/nextpas.core.system/Makefile" "test_hir_heap_contract.pas"
require_token "tests/nextpas.core.system/Makefile" "test-heap-contract"
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
# Typed exception boundary family (sckException*)
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.builder" "AssignSystemContract(Instr, sckExceptionTryPush)"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.builder" "AssignSystemContract(Instr, sckExceptionTryPop)"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.builder" "AssignSystemContract(Instr, sckExceptionRaise)"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.builder" "AssignSystemContract(Instr, sckExceptionFinallyEnd)"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.builder" "AssignSystemContract(Instr, sckExceptionExceptEnd)"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "sckExceptionTryPush:"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "sckExceptionTryPop:"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "sckExceptionRaise:"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "sckExceptionFinallyEnd:"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "sckExceptionExceptEnd:"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.model" "sckExceptionTryPush"
require_repo_file "tests/hir/test_hir_exception_contract.pas"
require_repo_token "tests/hir/test_hir_exception_contract.pas" "IsSystemContract"
require_repo_token "tests/hir/test_hir_exception_contract.pas" "sckExceptionTryPush"
require_repo_token "tests/hir/test_hir_exception_contract.pas" "sckExceptionRaise"
require_repo_token "tests/hir/test_hir_exception_contract.pas" "hir-exception-contract=pass"
require_token "tests/nextpas.core.system/Makefile" "test_hir_exception_contract.pas"
require_token "tests/nextpas.core.system/Makefile" "test-exception-contract"
# Exception helper existence in LLVM emitter
for helper in \
  "@np_try_push" \
  "@np_try_pop" \
  "@np_raise" \
  "@np_finally_end" \
  "@np_except_end"; do
  require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "$helper"
done
# Exception contract names documented in lifecycle-contracts.md
for contract in \
  "np.system.exception_try_push" \
  "np.system.exception_try_pop" \
  "np.system.exception_raise" \
  "np.system.exception_finally_end" \
  "np.system.exception_except_end"; do
  require_token "docs/system/lifecycle-contracts.md" "$contract"
done
# Exception contract-to-helper mapping documented
require_token "docs/system/lifecycle-contracts.md" "HIR intrinsic"
require_token "docs/system/lifecycle-contracts.md" "LLVM helper"
require_token "docs/system/lifecycle-contracts.md" "Exception helper contracts map"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "call void @np_try_push"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "call void @np_try_pop"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "call void @np_finally_end"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "call void @np_except_end"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "call void @np_raise"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "declare void @np_try_push"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "declare void @np_try_pop"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "declare void @np_finally_end"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "declare void @np_except_end"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "declare void @np_raise"

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

require_repo_owner_family_token "compiler/src" "nextpas.compiler.sema.analyzer" "SeedRuntimeContracts"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.sema.analyzer" "NPSYSTEM_PROCESS_INIT"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.sema.analyzer" "NPSYSTEM_PROCESS_FINI"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.sema.analyzer" "FModel.AddRuntimeContract(AContractName)"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.sema.analyzer" "AddRuntimeContract(NPSYSTEM_PROCESS_INIT, 'process-init-runtime')"
require_repo_token "compiler/src/nextpas.compiler.sema.semantic_model.pas" "function RuntimeContractAt(const AIndex: LongInt): TRuntimeContract;"
require_repo_file "tests/semantic/test_semantic_runtime_contract_seed.pas"
require_repo_token "tests/semantic/test_semantic_runtime_contract_seed.pas" "semantic-runtime-contract-seed-status=pass"
require_repo_token "tests/semantic/test_semantic_runtime_contract_seed.pas" "AssertRuntimeContractAt(Model, 0, 'np.system.process_init')"
require_repo_token "tests/semantic/test_semantic_runtime_contract_seed.pas" "AssertRuntimeContractAt(Model, 1, 'np.system.process_fini')"
require_repo_token "tests/semantic/test_semantic_runtime_contract_seed.pas" "program-must-not-seed-unit-init"
require_repo_token "tests/semantic/test_semantic_runtime_contract_seed.pas" "unit-must-not-seed-process-init"

[[ ! -e "$CORE_ROOT/src/System.pas" ]] || fail "must not create bare FPC-conflicting System.pas"
[[ ! -e "$CORE_ROOT/src/system.pas" ]] || fail "must not create bare FPC-conflicting system.pas"
# S4: nextpas.core.system.classes is now a minimal re-export facade (TStream etc.)
# It must only re-export from Classes, not introduce new implementations
if [[ -e "$CORE_ROOT/src/nextpas.core.system.classes.pas" ]]; then
  if grep -qE '(implementation|procedure|function|var |const )' "$CORE_ROOT/src/nextpas.core.system.classes.pas" 2>/dev/null | head -5; then
    # Allow type aliases but reject non-trivial implementations
    impl_count=$(grep -cE '^(procedure|function|var |const )' "$CORE_ROOT/src/nextpas.core.system.classes.pas" 2>/dev/null || true)
    if (( impl_count > 0 )); then
      fail "nextpas.core.system.classes must be a pure re-export facade, not an implementation"
    fi
  fi
fi
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
      nextpas.core.system.pas|nextpas.core.system.sysutils.pas|nextpas.core.system.typinfo.pas|nextpas.core.system.contracts.pas|nextpas.core.system.classes.pas|nextpas.core.system.classes.impl.pas|nextpas.core.system.memmanager.pas|nextpas.core.system.errors.pas|nextpas.core.system.heap.pas)
        ;;
      nextpas.core.system*.pas)
        fail "unreviewed system unit filename: src/$filename"
        ;;
    esac
  done < <(find "$CORE_ROOT/src" -maxdepth 1 -name 'nextpas.core.system*.pas' | sort)
}

require_system_unit_filename_allowlist
# nextpas.core.system.classes is now a live minimal re-export facade
# No longer rejecting usage - it re-exports Classes.TStream etc.
# reject_repo_uses_unit_prefix_under "$REPO_ROOT/compiler" "nextpas.core.system.classes"
# reject_repo_uses_unit_prefix_under "$CORE_ROOT/src" "nextpas.core.system.classes"
# reject_repo_uses_unit_prefix_under "$CORE_ROOT/tests" "nextpas.core.system.classes"

require_repo_file "compiler/tests/test_sysutils_createfmt_contract.pas"
require_repo_file "compiler/tests/test_typinfo_contract.pas"
require_repo_file "compiler/src/nextpas.compiler.toolchain.runner.pas"
require_repo_file "compiler/src/nextpas.compiler.frontend.workspace_model.pas"
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
require_repo_token "compiler/src/nextpas.compiler.toolchain.runner.pas" "ExpandFileName"
require_repo_token "compiler/src/nextpas.compiler.frontend.workspace_model.pas" "ExpandFileName"
require_repo_token "rtl/core/sysutils/np_sysutils.pas" "unit SysUtils;"
require_repo_token "rtl/core/classes/np_classes.pas" "unit Classes;"
require_repo_token "core/src/nextpas.core.collections.element_manager.pas" "InitializeArray"
require_repo_token "core/src/nextpas.core.collections.element_manager.pas" "CopyArray"
require_repo_token "core/src/nextpas.core.collections.hashmap.swiss.pas" "GetTypeKind"
require_repo_token "core/tests/nextpas.core.collections/test_managed_types/test_managed_types.lpr" "TArray string managed TypeInfo consumer contract"
require_repo_token "core/tests/nextpas.core.collections/test_managed_types/test_managed_types.lpr" "LA.Copy(0, 1, 4)"
require_repo_token "core/tests/nextpas.core.collections/test_managed_types/test_managed_types.lpr" "LA.Read(0, LReadBack, 6)"
require_repo_token "tests/hir/test_hir_dynarray_release_contract.pas" "OwnedBorrowedSource"
require_repo_token "tests/hir/test_hir_dynarray_release_contract.pas" "BorrowedResizeSource"
require_repo_token "tests/hir/test_hir_dynarray_release_contract.pas" "StringSource"
require_repo_token "tests/hir/test_hir_dynarray_release_contract.pas" "declare void @np_dynarray_release("
require_repo_token "tests/hir/test_hir_dynarray_release_contract.pas" "declare void @np_dynarray_fault("
require_repo_token "tests/hir/test_hir_dynarray_release_runtime_smoke.pas" "declare ptr @np_dynarray_resize("
require_repo_token "tests/hir/test_hir_dynarray_release_runtime_smoke.pas" "declare void @np_dynarray_release("
require_repo_token "tests/hir/test_hir_dynarray_release_runtime_smoke.pas" "declare void @np_dynarray_fault("
require_repo_token "tests/hir/test_hir_dynarray_release_runtime_smoke.pas" "hir-dynarray-release-runtime-smoke-status=pass"
require_repo_reject_regex "tests/hir/test_hir_dynarray_release_contract.pas" "missing-managed-string-dynarray-resize-call"
require_repo_reject_regex "tests/hir/test_hir_dynarray_release_contract.pas" "missing-managed-interface-dynarray-resize-call"
require_repo_reject_regex "tests/hir/test_hir_dynarray_release_contract.pas" "managed-string-dynarray-still-bare-arr-alloc"
require_repo_reject_regex "tests/hir/test_hir_dynarray_release_contract.pas" "managed-interface-dynarray-still-bare-arr-alloc"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.sema.analyzer" "NPSYSTEM_UNIT_INIT"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.sema.analyzer" "NPSYSTEM_UNIT_FINI"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.sema.analyzer" "NPSYSTEM_PROCESS_INIT"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.sema.analyzer" "NPSYSTEM_PROCESS_FINI"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "declare ptr @np_dynarray_resize"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "declare void @np_dynarray_release"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "declare void @np_dynarray_fault"
require_repo_file "tests/hir/test_hir_object_free_contract.pas"
require_repo_file "tests/semantic/test_semantic_call_bindings.pas"
require_repo_token "tests/hir/test_hir_object_free_contract.pas" "object-free-runtime"
require_repo_token "tests/hir/test_hir_object_free_contract.pas" "nextpas.compiler.ir.system_contracts"
require_repo_token "tests/hir/test_hir_object_free_contract.pas" "IsSystemContract(Instr, sckObjectFree)"
require_repo_token "tests/hir/test_hir_object_free_contract.pas" "IsSystemContract(Instr, sckObjectFreeDestroy)"
require_repo_token "tests/hir/test_hir_object_free_contract.pas" "IsSystemContract(Instr, sckObjectFreeCleanup)"
require_repo_token "tests/hir/test_hir_object_free_contract.pas" "IsSystemContract(Instr, sckObjectFreeRelease)"
require_repo_token "tests/hir/test_hir_object_free_contract.pas" "SystemContractAt(sckObjectFree).SemanticName"
require_repo_token "tests/hir/test_hir_object_free_contract.pas" "untrusted-object-free-label"
require_repo_reject_regex "tests/hir/test_hir_object_free_contract.pas" 'np[.]system[.]object_free'
require_repo_reject_regex "tests/hir/test_hir_object_free_contract.pas" 'NPSYSTEM_OBJECT_FREE'
require_repo_reject_regex "tests/hir/test_hir_object_free_contract.pas" 'SameText[[:space:]]*\([[:space:]]*Instr[.]IntrinsicName'
require_repo_token "tests/hir/test_hir_object_free_contract.pas" "@np_object_free_release"
require_repo_token "tests/hir/test_hir_object_free_contract.pas" "missing-object-free-release-helper-decl"
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
require_repo_owner_family_token "compiler/src" "nextpas.compiler.sema.analyzer" "class-new-runtime"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.builder" "sckObjectAlloc"
require_repo_owner_family_token "compiler/src" "nextpas.compiler.ir.hir.llvm_emitter" "declare void @np_object_free_release"

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
reject_token "src/nextpas.core.system.typinfo.pas" "GetTypeData"
reject_token "src/nextpas.core.system.typinfo.pas" "IsPublishedProp"
reject_token "src/nextpas.core.system.typinfo.pas" "SetPropValue"
reject_token "src/nextpas.core.system.typinfo.pas" "PropCount"
reject_token "src/nextpas.core.system.typinfo.pas" "TPropInfo"
reject_token "src/nextpas.core.system.typinfo.pas" "function TypeInfo"
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
require_token "tests/nextpas.core.system/Makefile" "test-object-free-runtime-contract"
require_token "tests/nextpas.core.system/Makefile" "OBJECT_FREE_RUNTIME_CONTRACT_SOURCE"
require_token "tests/nextpas.core.system/Makefile" "test_hir_object_free_contract.pas"
require_token "tests/nextpas.core.system/Makefile" 'OBJECT_FREE_RUNTIME_CONTRACT_FPC_FLAGS := -Fu$(ROOT_DIR)/compiler/frontend'
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

# ============================================================================
# SECTION: Root facade forwarding chain checks
# ============================================================================

require_token "src/nextpas.core.system.pas" "NEXTPAS_SYSTEM_NAME = 'nextpas.core.system';"
require_token "src/nextpas.core.system.pas" "MAX_SIZE_INT = nextpas.core.base.MAX_SIZE_INT;"
require_token "src/nextpas.core.system.pas" "MAX_SIZE_UINT = nextpas.core.base.MAX_SIZE_UINT;"
require_token "src/nextpas.core.system.pas" "MIN_SIZE_INT = nextpas.core.base.MIN_SIZE_INT;"
require_token "src/nextpas.core.system.pas" "SIZE_PTR = nextpas.core.base.SIZE_PTR;"
require_token "src/nextpas.core.system.pas" "SIZE_8 = nextpas.core.base.SIZE_8;"
require_token "src/nextpas.core.system.pas" "SIZE_16 = nextpas.core.base.SIZE_16;"
require_token "src/nextpas.core.system.pas" "SIZE_32 = nextpas.core.base.SIZE_32;"
require_token "src/nextpas.core.system.pas" "SIZE_64 = nextpas.core.base.SIZE_64;"
require_token "src/nextpas.core.system.fpc.inc" "SizeInt = System.SizeInt;"
require_token "src/nextpas.core.system.fpc.inc" "SizeUInt = System.SizeUInt;"
require_token "src/nextpas.core.system.fpc.inc" "PtrInt = System.PtrInt;"
require_token "src/nextpas.core.system.fpc.inc" "PtrUInt = System.PtrUInt;"
require_token "src/nextpas.core.system.fpc.inc" "NativeInt = System.NativeInt;"
require_token "src/nextpas.core.system.fpc.inc" "NativeUInt = System.NativeUInt;"
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
require_token "src/nextpas.core.system.pas" "Exception = nextpas.core.system.errors.Exception;"
require_token "src/nextpas.core.system.pas" "ExceptClass = nextpas.core.system.errors.ExceptClass;"
require_token "src/nextpas.core.system.pas" "TErrorCategory = nextpas.core.system.errors.TErrorCategory;"
require_token "src/nextpas.core.system.pas" "ENextPasError = nextpas.core.system.errors.ENextPasError;"
require_token "src/nextpas.core.system.pas" "ECore = nextpas.core.system.errors.ECore;"
require_token "src/nextpas.core.system.pas" "EInvariantViolation = nextpas.core.system.errors.EInvariantViolation;"
require_token "src/nextpas.core.system.pas" "EArgumentNil = nextpas.core.system.errors.EArgumentNil;"
require_token "src/nextpas.core.system.pas" "EEmptyCollection = nextpas.core.system.errors.EEmptyCollection;"
require_token "src/nextpas.core.system.pas" "EInvalidArgument = nextpas.core.system.errors.EInvalidArgument;"
require_token "src/nextpas.core.system.pas" "EInvalidResult = nextpas.core.system.errors.EInvalidResult;"
require_token "src/nextpas.core.system.pas" "EInvalidState = nextpas.core.system.errors.EInvalidState;"
require_token "src/nextpas.core.system.pas" "EOutOfRange = nextpas.core.system.errors.EOutOfRange;"
require_token "src/nextpas.core.system.pas" "ENotSupported = nextpas.core.system.errors.ENotSupported;"
require_token "src/nextpas.core.system.pas" "ENotCompatible = nextpas.core.system.errors.ENotCompatible;"
require_token "src/nextpas.core.system.pas" "EInvalidOperation = nextpas.core.system.errors.EInvalidOperation;"
require_token "src/nextpas.core.system.pas" "EOverflow = nextpas.core.system.errors.EOverflow;"
require_token "src/nextpas.core.system.pas" "EArgumentError = nextpas.core.system.errors.EArgumentError;"
require_token "src/nextpas.core.system.pas" "ENullReferenceError = nextpas.core.system.errors.ENullReferenceError;"
require_token "src/nextpas.core.system.pas" "EInvalidOperationError = nextpas.core.system.errors.EInvalidOperationError;"
require_token "src/nextpas.core.system.pas" "ENotImplementedError = nextpas.core.system.errors.ENotImplementedError;"
require_token "src/nextpas.core.system.pas" "ENotSupportedError = nextpas.core.system.errors.ENotSupportedError;"
require_token "src/nextpas.core.system.pas" "ETimeoutError = nextpas.core.system.errors.ETimeoutError;"
require_token "src/nextpas.core.system.pas" "ECancelledError = nextpas.core.system.errors.ECancelledError;"
require_token "src/nextpas.core.system.pas" "EPermissionError = nextpas.core.system.errors.EPermissionError;"
require_token "src/nextpas.core.system.pas" "ENotFoundError = nextpas.core.system.errors.ENotFoundError;"
require_token "src/nextpas.core.system.pas" "EAlreadyExistsError = nextpas.core.system.errors.EAlreadyExistsError;"
require_token "src/nextpas.core.system.pas" "EResourceExhaustedError = nextpas.core.system.errors.EResourceExhaustedError;"
require_token "src/nextpas.core.system.pas" "EIOError = nextpas.core.system.errors.EIOError;"
require_token "src/nextpas.core.system.pas" "ENetworkError = nextpas.core.system.errors.ENetworkError;"
require_token "src/nextpas.core.system.pas" "EParseError = nextpas.core.system.errors.EParseError;"
require_token "src/nextpas.core.system.pas" "EIndexOutOfRangeError = nextpas.core.system.errors.EIndexOutOfRangeError;"
require_token "src/nextpas.core.system.pas" "EOutOfMemoryError = nextpas.core.system.errors.EOutOfMemoryError;"
require_token "src/nextpas.core.system.pas" "EOutOfMemory = nextpas.core.system.errors.EOutOfMemory;"
require_token "src/nextpas.core.system.pas" "EInterruptedError = nextpas.core.system.errors.EInterruptedError;"
require_token "src/nextpas.core.system.pas" "EWouldBlockError = nextpas.core.system.errors.EWouldBlockError;"
require_token "src/nextpas.core.system.pas" "EConvertError = nextpas.core.system.errors.EConvertError;"
require_token "src/nextpas.core.system.pas" "EAssertionFailed = nextpas.core.system.errors.EAssertionFailed;"
require_token "src/nextpas.core.system.pas" "ecNone = nextpas.core.system.errors.ecNone;"
require_token "src/nextpas.core.system.pas" "ecInvalidArgument = nextpas.core.system.errors.ecInvalidArgument;"
require_token "src/nextpas.core.system.pas" "ecNullReference = nextpas.core.system.errors.ecNullReference;"
require_token "src/nextpas.core.system.pas" "ecInvalidOperation = nextpas.core.system.errors.ecInvalidOperation;"
require_token "src/nextpas.core.system.pas" "ecNotImplemented = nextpas.core.system.errors.ecNotImplemented;"
require_token "src/nextpas.core.system.pas" "ecNotSupported = nextpas.core.system.errors.ecNotSupported;"
require_token "src/nextpas.core.system.pas" "ecTimeout = nextpas.core.system.errors.ecTimeout;"
require_token "src/nextpas.core.system.pas" "ecCancelled = nextpas.core.system.errors.ecCancelled;"
require_token "src/nextpas.core.system.pas" "ecInterrupted = nextpas.core.system.errors.ecInterrupted;"
require_token "src/nextpas.core.system.pas" "ecWouldBlock = nextpas.core.system.errors.ecWouldBlock;"
require_token "src/nextpas.core.system.pas" "ecPermission = nextpas.core.system.errors.ecPermission;"
require_token "src/nextpas.core.system.pas" "ecNotFound = nextpas.core.system.errors.ecNotFound;"
require_token "src/nextpas.core.system.pas" "ecAlreadyExists = nextpas.core.system.errors.ecAlreadyExists;"
require_token "src/nextpas.core.system.pas" "ecResourceExhausted = nextpas.core.system.errors.ecResourceExhausted;"
require_token "src/nextpas.core.system.pas" "ecIO = nextpas.core.system.errors.ecIO;"
require_token "src/nextpas.core.system.pas" "ecNetwork = nextpas.core.system.errors.ecNetwork;"
require_token "src/nextpas.core.system.pas" "ecParse = nextpas.core.system.errors.ecParse;"
require_token "src/nextpas.core.system.pas" "ecInternal = nextpas.core.system.errors.ecInternal;"
require_token "tests/nextpas.core.system/test_system_facade/test_system_facade.lpr" "system constants mirror base compile-truth"
require_token "tests/nextpas.core.system/test_system_facade/test_system_facade.lpr" "system base carrier aliases mirror base compile-truth"
require_token "tests/nextpas.core.system/test_system_facade/test_system_facade.lpr" "system memory facade delegates full base utils contract"
require_token "tests/nextpas.core.system/test_system_facade/test_system_facade.lpr" "system FillMem delegates to base utils"
require_token "tests/nextpas.core.system/test_system_facade/test_system_facade.lpr" "system base error aliases mirror base compile-truth"
require_token "tests/nextpas.core.system/test_system_facade/test_system_facade.lpr" "system error taxonomy aliases mirror canonical owners"
require_repo_token "core/tests/nextpas.core.base/test_base/test_base.lpr" "CompareMem(nil, nil, 0)"
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

# ============================================================================
# SECTION: Sub-unit facade checks (sysutils, typinfo, errors, classes)
# ============================================================================

require_token "src/nextpas.core.system.sysutils.pas" "unit nextpas.core.system.sysutils;"
require_token "src/nextpas.core.system.sysutils.pas" "nextpas.core.exception"
require_token "src/nextpas.core.system.sysutils.pas" "nextpas.core.text.conv"
require_token "src/nextpas.core.system.sysutils.pas" "Exception = nextpas.core.exception.Exception;"
require_token "src/nextpas.core.system.sysutils.pas" "ExceptClass = nextpas.core.exception.ExceptClass;"
require_token "src/nextpas.core.system.sysutils.pas" "EConvertError = nextpas.core.exception.EConvertError;"
require_token "src/nextpas.core.system.sysutils.pas" "EAssertionFailed = nextpas.core.exception.EAssertionFailed;"
require_token "src/nextpas.core.system.sysutils.pas" "function Format"
require_token "src/nextpas.core.system.sysutils.pas" "nextpas.core.text.format.TextFormat"
require_sysutils_facade_surface_allowlist

require_file "src/nextpas.core.system.errors.pas"
require_token "src/nextpas.core.system.errors.pas" "unit nextpas.core.system.errors;"
require_token "src/nextpas.core.system.errors.pas" "nextpas.core.exception"
require_token "src/nextpas.core.system.errors.pas" "nextpas.core.base"
require_token "src/nextpas.core.system.errors.pas" "nextpas.core.errors"
require_token "src/nextpas.core.system.errors.pas" "Exception = nextpas.core.exception.Exception;"
require_token "src/nextpas.core.system.errors.pas" "ExceptClass = nextpas.core.exception.ExceptClass;"
require_token "src/nextpas.core.system.errors.pas" "EAbort = nextpas.core.exception.EAbort;"
require_token "src/nextpas.core.system.errors.pas" "ENextPasError = nextpas.core.exception.ENextPasError;"
require_token "src/nextpas.core.system.errors.pas" "ECore = nextpas.core.base.ECore;"
require_token "src/nextpas.core.system.errors.pas" "EArgumentError = nextpas.core.errors.EArgumentError;"
require_token "src/nextpas.core.system.errors.pas" "ecNone = nextpas.core.errors.ecNone;"
require_errors_facade_surface_allowlist
reject_token "src/nextpas.core.system.errors.pas" "SysUtils"
reject_token "src/nextpas.core.system.errors.pas" "TypInfo"
reject_token "src/nextpas.core.system.errors.pas" "Classes"

# ============================================================================
# SECTION: FPC RTL isolation enforcement
# ============================================================================

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


# === FPC broad RTL file-level enforcement gate ===
require_no_new_fpc_rtl_debt() {
  local allowlist="$CORE_ROOT/tests/nextpas.core.system/test_system_source_contracts/fpc_rtl_file_allowlist.txt"
  local fail_count=0
  local file unit_name

  # Scan ALL nextpas.core.*.pas files for monitored units
  local all_found
  all_found="$(mktemp)"

  awk '
    function trim(s) { gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s); return s }
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
  ' "$CORE_ROOT"/src/nextpas.core.*.pas 2>/dev/null | sort -u > "$all_found"

  while IFS='|' read -r file unit_name; do
    case "$unit_name" in
      SysUtils|Classes|TypInfo|DateUtils|BaseUnix|Unix|Windows|Dos|Crt|Sockets|sockets|ssockets|WinSock2|winsock2|NetDB|Math|Variants|StrUtils|SyncObjs|Process|DynLibs|dynlibs|ctypes|Contnrs|fgl|fpjson|jsonparser|Registry|registry|zlib|cthreads|CThreads)
        local basename="${file##*/}"
        if ! grep -qF "$unit_name|$basename" "$allowlist" 2>/dev/null; then
          local rel="${file#$CORE_ROOT/src/}"
          echo "[FAIL] FPC RTL debt: $rel uses $unit_name but not in fpc_rtl_file_allowlist.txt" >&2
          echo "  To allow: add [$unit_name|$basename] to the allowlist with a comment" >&2
          fail_count=$((fail_count + 1))
        fi
        ;;
    esac
  done < "$all_found"

  rm -f "$all_found"

  if [ "$fail_count" -gt 0 ]; then
    fail "FPC broad RTL file-level enforcement gate rejected $fail_count new debt entries"
  fi
}

require_no_new_fpc_rtl_debt

# === FPC RTL tests-scope enforcement gate (ratchet: no NEW debt) ===
# heaptrc is exempt in tests (memory-trace harness). Allowlist format:
# <lowercase-unit>|<repo-relative-path>, seeded 2026-09-04 post rtlfree-purge.
require_no_new_fpc_rtl_debt_tests() {
  local allowlist="$CORE_ROOT/tests/nextpas.core.system/test_system_source_contracts/fpc_rtl_tests_allowlist.txt"
  local fail_count=0
  local file unit_name unit_lc rel

  local file_list
  file_list="$(mktemp)"
  find "$REPO_ROOT" \
    \( -path "$REPO_ROOT/core/src" -o -path "$REPO_ROOT/units" -o -path "$REPO_ROOT/rtl" \
       -o -path "$REPO_ROOT/.worktrees" -o -path "$REPO_ROOT/build" -o -path "$REPO_ROOT/.nextpas" \) -prune \
    -o \( -name '*.pas' -o -name '*.lpr' \) -print 2>/dev/null | sort -u > "$file_list"

  local all_found
  all_found="$(mktemp)"
  # shellcheck disable=SC2016
  awk '
    function trim(s) { gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s); return s }
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
  ' $(cat "$file_list") 2>/dev/null | sort -u > "$all_found"
  rm -f "$file_list"

  while IFS='|' read -r file unit_name; do
    [[ -n "$unit_name" ]] || continue
    unit_lc="$(printf '%s' "$unit_name" | tr '[:upper:]' '[:lower:]')"
    case "$unit_lc" in
      heaptrc) continue ;;
      sysutils|classes|typinfo|dateutils|baseunix|unix|windows|dos|crt|sockets|ssockets|winsock2|netdb|math|variants|strutils|syncobjs|process|dynlibs|ctypes|contnrs|fgl|fpjson|jsonparser|generics.collections|system|syscall|registry|zlib|cthreads|objects|sharemem)
        rel="${file#$REPO_ROOT/}"
        if ! grep -qF "$unit_lc|$rel" "$allowlist" 2>/dev/null; then
          echo "[FAIL] FPC RTL tests debt: $rel uses $unit_name but not in fpc_rtl_tests_allowlist.txt" >&2
          fail_count=$((fail_count + 1))
        fi
        ;;
    esac
  done < "$all_found"

  rm -f "$all_found"

  if [ "$fail_count" -gt 0 ]; then
    fail "FPC RTL tests-scope gate rejected $fail_count new debt entries"
  fi
}

require_no_new_fpc_rtl_debt_tests

# ============================================================================
# SECTION: TTypeKind drift detection (S11.1)
# ============================================================================

check_ttypekind_consistency() {
  local kernel_rtti="$CORE_ROOT/src/nextpas.core.system.rtti.inc"

  if [ ! -f "$kernel_rtti" ]; then
    echo "[SKIP] kernel rtti.inc not found"
    return
  fi

  # Extract kernel TTypeKind enum values (between {$compiler_type_kind} and the closing paren)
  local kernel_values
  kernel_values=$(awk '/\{\$compiler_type_kind\}/,/\);/' "$kernel_rtti" \
    | grep -oP 'tk\w+' | sort -u)

  # FPC TTypeKind values (canonical order from rtl/inc/rttih.inc)
  local fpc_values="tkUnknown
tkInteger
tkChar
tkEnumeration
tkFloat
tkSet
tkMethod
tkSString
tkLString
tkAString
tkWString
tkVariant
tkArray
tkRecord
tkInterface
tkClass
tkObject
tkWChar
tkBool
tkInt64
tkQWord
tkDynArray
tkInterfaceRaw
tkProcVar
tkUString
tkUChar
tkHelper
tkFile
tkClassRef
tkPointer"

  local fpc_sorted
  fpc_sorted=$(echo "$fpc_values" | sort -u)

  # Compare
  local diff_result
  diff_result=$(diff <(echo "$kernel_values") <(echo "$fpc_sorted") 2>&1 || true)

  if [ -n "$diff_result" ]; then
    echo "[FAIL] TTypeKind drift detected between kernel and FPC:"
    echo "$diff_result"
    fail "TTypeKind drift — kernel rtti.inc must match FPC rttih.inc"
  else
    echo "[PASS] TTypeKind consistency: kernel matches FPC ($(echo "$kernel_values" | wc -l) values)"
  fi
}

check_ttypekind_consistency

echo "[PASS] nextpas.core.system source contracts"
