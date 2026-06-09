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
  if list_pascal_uses_units "$REPO_ROOT/$path" | grep -Fx --quiet "$forbidden_unit"; then
    fail "$path must not directly use unit: $forbidden_unit"
  fi
}

require_repo_uses_allowlist() {
  local path="$1"
  shift
  local actual expected
  actual="$(list_pascal_uses_units "$REPO_ROOT/$path" | tr '[:upper:]' '[:lower:]' | sort -u)"
  expected="$(printf '%s\n' "$@" | tr '[:upper:]' '[:lower:]' | sort -u)"
  if [[ "$actual" != "$expected" ]]; then
    printf '[FAIL] %s uses dependency drifted\n' "$path" >&2
    printf '%s\n' '--- expected' >&2
    printf '%s\n' "$expected" >&2
    printf '%s\n' '--- actual' >&2
    printf '%s\n' "$actual" >&2
    exit 1
  fi
}

list_root_facade_surface() {
  awk '
    function trim(s) {
      gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s)
      return s
    }
    BEGIN {
      in_interface = 0
      section = ""
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
      line = $0
      gsub(/\{[^}]*\}/, "", line)
      sub(/\/\/.*/, "", line)
      line = trim(line)
      if (line == "") {
        next
      }
      lower_line = tolower(line)
      if (lower_line == "uses") {
        section = "uses"
        next
      }
      if (section == "uses") {
        if (line ~ /;/) {
          section = ""
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
      if (section == "const" && match(line, /^([A-Za-z_][A-Za-z0-9_]*)[ \t=]/, parts)) {
        print "const " parts[1]
        next
      }
      if (section == "type" && match(line, /^([A-Za-z_][A-Za-z0-9_]*)[ \t=]/, parts)) {
        print "type " parts[1]
        next
      }
    }
  ' "$CORE_ROOT/src/nextpas.core.system.pas"
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
procedure CopyMem
function CompareMem
function Supports
function Supports
EOF
)"
  if [[ "$actual" != "$expected" ]]; then
    printf '[FAIL] root facade public surface drifted\n' >&2
    printf '%s\n' '--- expected' >&2
    printf '%s\n' "$expected" >&2
    printf '%s\n' '--- actual' >&2
    printf '%s\n' "$actual" >&2
    exit 1
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

canonical_fpc_broad_unit() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    sysutils) printf '%s\n' "SysUtils" ;;
    classes) printf '%s\n' "Classes" ;;
    typinfo) printf '%s\n' "TypInfo" ;;
    dateutils) printf '%s\n' "DateUtils" ;;
    baseunix) printf '%s\n' "BaseUnix" ;;
    unix) printf '%s\n' "Unix" ;;
    windows) printf '%s\n' "Windows" ;;
    *) return 1 ;;
  esac
}

fpc_broad_route_category() {
  local path="$1"
  case "$path" in
    compiler/*) printf '%s\n' "compiler-production" ;;
    core/src/nextpas.core.system*) printf '%s\n' "system-kernel-route" ;;
    core/src/nextpas.core.platform*|core/src/nextpas.core.fs*|core/src/nextpas.core.io*) printf '%s\n' "platform-fs-io-host-debt" ;;
    core/src/nextpas.core.mem*) printf '%s\n' "mem-host-debt" ;;
    core/src/nextpas.core.tls*) printf '%s\n' "tls-legacy-host-debt" ;;
    core/src/nextpas.core.tui*) printf '%s\n' "tui-legacy-host-debt" ;;
    core/src/nextpas.core.http*|core/src/nextpas.core.net*) printf '%s\n' "net-http-legacy-host-debt" ;;
    core/src/nextpas.core.git*) printf '%s\n' "git-legacy-host-debt" ;;
    core/src/nextpas.core.collections*) printf '%s\n' "collections-typinfo-debt" ;;
    core/src/nextpas.core.base*|core/src/nextpas.core.exception*|core/src/nextpas.core.crypto*|core/src/nextpas.core.bench*) printf '%s\n' "core-foundation-legacy-debt" ;;
    core/src/nextpas.core.simd*) printf '%s\n' "simd-host-probe-debt" ;;
    *) printf '%s\n' "unclassified-core-debt" ;;
  esac
}

list_repo_fpc_broad_rtl_route_counts() {
  local file_path rel_path unit_name canonical category
  while IFS= read -r file_path; do
    rel_path="${file_path#$REPO_ROOT/}"
    while IFS= read -r unit_name; do
      if canonical="$(canonical_fpc_broad_unit "$unit_name")"; then
        category="$(fpc_broad_route_category "$rel_path")"
        printf '%s|%s\n' "$category" "$canonical"
      fi
    done < <(list_pascal_uses_units "$file_path")
  done < <(
    {
      find "$CORE_ROOT/src" -type f -name '*.pas'
      find "$REPO_ROOT/compiler" -type f -name '*.pas' ! -path "$REPO_ROOT/compiler/tests/*"
    } | sort
  ) | sort | uniq -c | awk '{ print $2 "|" $1 }'
}

list_fpc_broad_rtl_allowlist() {
  local allowlist="$CORE_ROOT/tests/nextpas.core.system/test_system_source_contracts/fpc_broad_rtl_allowlist.txt"
  [[ -f "$allowlist" ]] || fail "missing FPC broad RTL allowlist: $allowlist"
  sed -E 's/[[:space:]]+$//' "$allowlist" |
    sed -E '/^[[:space:]]*($|#)/d' |
    sort -u
}

require_fpc_broad_rtl_allowlist_stable() {
  local actual expected
  actual="$(list_repo_fpc_broad_rtl_route_counts | sort -u)"
  expected="$(list_fpc_broad_rtl_allowlist)"
  if [[ "$actual" != "$expected" ]]; then
    printf '[FAIL] direct FPC broad RTL route debt baseline drifted\n' >&2
    printf '%s\n' '--- registered category debt' >&2
    printf '%s\n' "$expected" >&2
    printf '%s\n' '--- current category debt' >&2
    printf '%s\n' "$actual" >&2
    exit 1
  fi
  if printf '%s\n' "$actual" | grep -F --quiet 'unclassified-core-debt|'; then
    fail "direct FPC broad RTL route debt has unclassified owner category"
  fi
}

reject_compiler_production_uses_unit() {
  local forbidden_unit="$1"
  while IFS= read -r file_path; do
    if list_pascal_uses_units "$file_path" | grep -Fxi --quiet "$forbidden_unit"; then
      fail "${file_path#$REPO_ROOT/} must not directly use runtime owner unit: $forbidden_unit"
    fi
  done < <(find "$REPO_ROOT/compiler" -type f -name '*.pas' \
    ! -path "$REPO_ROOT/compiler/tests/*" \
    ! -path "$REPO_ROOT/compiler/docs/*")
}

reject_compiler_production_unitpath_token() {
  local token="$1"
  if rg --glob '*.pas' --glob '!tests/**' --glob '!docs/**' --quiet -- "$token" "$REPO_ROOT/compiler"; then
    fail "compiler production sources must not use unitpath token: $token"
  fi
}

require_file "docs/system/README.md"
require_file "docs/system/rtl-mapping.md"
require_file "docs/system/goal-tree.md"
require_file "docs/system/fpc-rtl-route-boundary.md"
require_file "docs/system/runtime-contracts.md"
require_file "docs/system/lifecycle-contracts.md"
require_file "docs/system/bootstrap-dual-surface-adapter.md"
require_file "docs/system/compiler-integration-contract.md"
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
require_token "docs/system/README.md" "bootstrap-dual-surface-adapter.md"
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
require_token "docs/system/README.md" "S5 compiler integration contract"
require_token "docs/system/README.md" "source-backed System truth"
require_token "docs/system/README.md" "backend-private magic strings"
require_token "docs/system/README.md" "compiler/HIR contract live; no callable public facade"
require_token "docs/system/README.md" '| `np.system.process_init` | process-level runtime startup | compiler semantic contract live; runtime execution deferred |'
require_token "docs/system/README.md" '| `np.system.process_fini` | process-level runtime shutdown | compiler semantic contract live; runtime execution deferred |'
require_token "docs/system/README.md" '| `np.system.unit_init` | run a unit initialization entry | future compiler/runtime only |'
require_token "docs/system/README.md" '| `np.system.unit_fini` | run a unit finalization entry | future compiler/runtime only |'
require_token "docs/system/README.md" 'program, library and package roots project exact `runtime-contract` entries'

require_token "docs/system/fpc-rtl-route-boundary.md" "root kernel boundary"
require_token "docs/system/fpc-rtl-route-boundary.md" "FPC-routed stage0"
require_token "docs/system/fpc-rtl-route-boundary.md" "not a broad FPC compatibility library"
require_token "docs/system/fpc-rtl-route-boundary.md" "debt baseline"
require_token "docs/system/fpc-rtl-route-boundary.md" "fpc_broad_rtl_allowlist.txt"
require_token "docs/system/fpc-rtl-route-boundary.md" "New direct uses outside the allowlist fail"
require_token "docs/system/fpc-rtl-route-boundary.md" "Each future migration removes allowlist entries"

for token in \
  "FPC-compatible source" \
  "not semantic authority" \
  "not nextPas target ABI" \
  "stage0 host adapter" \
  "nextPas contract path" \
  "public facade" \
  "bootstrap RTL units" \
  "np.system.*" \
  "do not freeze host FPC metadata layout" \
  "TObject.Free" \
  "InitializeArray" \
  "FinalizeArray" \
  "CopyArray" \
  "TFileStream" \
  "TStringList" \
  "Needs Review" \
  "fpc-compatible-source-is-stage0-build-vehicle" \
  "fpc-compatibility-is-not-semantic-authority" \
  "np-system-contracts-own-semantic-authority" \
  "dual-surface-adapter-one-semantic-authority" \
  "fpc-adapter-must-not-define-runtime-semantics" \
  "compat-facade-must-not-own-system-semantics" \
  "typeinfo-facade-does-not-freeze-metadata-abi" \
  "lifecycle-contracts-match-live-typinfo-status" \
  "compiler-consumes-nextpas-core-system-contract" \
  "fpc-host-path-is-implementation-not-authority"; do
  require_token "docs/system/bootstrap-dual-surface-adapter.md" "$token"
done

for token in \
  "S5 Compiler Integration Contract" \
  "nextpas.core.system is the root kernel module" \
  "compiler must consume nextpas.core.system through nextpas.core" \
  "FPC path is host-backed implementation" \
  "nextPas path uses nextPas-owned kernel implementation" \
  "compiler must not depend on a parallel System implementation" \
  "source-backed System truth" \
  "backend-private magic strings" \
  "TObject" \
  "Free" \
  "destructor" \
  "np.system.object_free" \
  "np.system.object_free.destroy" \
  "np.system.object_free.release" \
  "np.system.unit_init" \
  "np.system.unit_fini" \
  "PTypeInfo" \
  "TTypeKind" \
  "InitializeArray" \
  "FinalizeArray" \
  "CopyArray" \
  "no broad FPC SysUtils" \
  "no live nextpas.core.system.classes" \
  "consumer-pressure evidence" \
  "compile-truth evidence"; do
  require_token "docs/system/compiler-integration-contract.md" "$token"
done

require_token "docs/system/runtime-contracts.md" "FPC-compatible source"
require_token "docs/system/runtime-contracts.md" "stage0 host fallback"
require_token "docs/system/runtime-contracts.md" "semantic authority"
require_token "docs/system/lifecycle-contracts.md" "FPC-compatible source"
require_token "docs/system/lifecycle-contracts.md" "stage0 host fallback"
require_token "docs/system/lifecycle-contracts.md" "compiler/runtime metadata"
require_token "docs/system/lifecycle-contracts.md" "seven-symbol bridge"
require_token "docs/system/lifecycle-contracts.md" "does not freeze metadata ABI"
require_token "docs/system/rtl-mapping.md" "compiler/HIR contract live; no public facade"
require_token "docs/system/rtl-mapping.md" 'Program startup and shutdown | `compiler semantic contract live; runtime execution deferred`'
require_token "docs/system/rtl-mapping.md" "np.system.object_free"

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
require_token "docs/system/goal-tree.md" "S5 compiler integration contract"
require_token "docs/system/goal-tree.md" "readiness-only"
require_token "docs/system/goal-tree.md" "compiler must not depend on a parallel System implementation"
require_token "docs/system/goal-tree.md" "process-level startup/shutdown semantic seed"
require_token "docs/system/goal-tree.md" "without upgrading runtime execution or unit lifecycle"

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
require_token "docs/system/compatibility-facades.md" 'IntToStr'
require_token "docs/system/compatibility-facades.md" '`CompareText` | no focused consumer pressure in this lane'
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
require_token "docs/system/compatibility-matrix.md" '`IntToStr`'
require_token "docs/system/compatibility-matrix.md" '`CompareText` | no focused consumer pressure in this lane'

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

for helper in \
  "np.system.unit_init" \
  "np.system.unit_fini" \
  "np.system.runtime_fault"; do
  require_token "docs/system/lifecycle-contracts.md" "$helper"
done

require_file "src/nextpas.core.system.contracts.pas"
require_token "src/nextpas.core.system.contracts.pas" "unit nextpas.core.system.contracts;"
require_token "src/nextpas.core.system.contracts.pas" "NPSYSTEM_PROCESS_INIT = 'np.system.process_init'"
require_token "src/nextpas.core.system.contracts.pas" "NPSYSTEM_PROCESS_FINI = 'np.system.process_fini'"
require_token "src/nextpas.core.system.contracts.pas" "NPSYSTEM_UNIT_INIT = 'np.system.unit_init'"
require_token "src/nextpas.core.system.contracts.pas" "NPSYSTEM_UNIT_FINI = 'np.system.unit_fini'"
require_token "src/nextpas.core.system.contracts.pas" "NPSYSTEM_HALT = 'np.system.halt'"
require_token "src/nextpas.core.system.contracts.pas" "NPSYSTEM_OBJECT_FREE = 'np.system.object_free'"
require_token "src/nextpas.core.system.contracts.pas" "NPSYSTEM_OBJECT_FREE_DESTROY = 'np.system.object_free.destroy'"
require_token "src/nextpas.core.system.contracts.pas" "NPSYSTEM_OBJECT_FREE_CLEANUP = 'np.system.object_free.cleanup'"
require_token "src/nextpas.core.system.contracts.pas" "NPSYSTEM_OBJECT_FREE_RELEASE = 'np.system.object_free.release'"
require_token "src/nextpas.core.system.contracts.pas" "NPSYSTEM_RUNTIME_FAULT = 'np.system.runtime_fault'"
require_token "docs/system/README.md" "nextpas.core.system.contracts"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "nextpas.core.system.contracts"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "NPSYSTEM_PROCESS_INIT"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "NPSYSTEM_PROCESS_FINI"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "NPSYSTEM_OBJECT_FREE"
require_repo_reject_token "compiler/sema/np_semantic_analyzer.pas" "'np.system.process_init'"
require_repo_reject_token "compiler/sema/np_semantic_analyzer.pas" "'np.system.process_fini'"
require_repo_reject_token "compiler/sema/np_semantic_analyzer.pas" "'np.system.object_free'"
require_repo_token "compiler/ir/np_hir_builder.pas" "nextpas.core.system.contracts"
require_repo_token "compiler/ir/np_hir_builder.pas" "NPSYSTEM_OBJECT_FREE_DESTROY"
require_repo_token "compiler/ir/np_hir_builder.pas" "NPSYSTEM_OBJECT_FREE_CLEANUP"
require_repo_token "compiler/ir/np_hir_builder.pas" "NPSYSTEM_OBJECT_FREE_RELEASE"
require_repo_reject_token "compiler/ir/np_hir_builder.pas" "'np.system.object_free.destroy'"
require_repo_reject_token "compiler/ir/np_hir_builder.pas" "'np.system.object_free.cleanup'"
require_repo_reject_token "compiler/ir/np_hir_builder.pas" "'np.system.object_free.release'"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "nextpas.core.system.contracts"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "NPSYSTEM_OBJECT_FREE"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "NPSYSTEM_OBJECT_FREE_DESTROY"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "NPSYSTEM_OBJECT_FREE_CLEANUP"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "NPSYSTEM_OBJECT_FREE_RELEASE"
require_repo_reject_token "compiler/ir/np_hir_llvm_emitter.pas" "'np.system.object_free'"
require_repo_reject_token "compiler/ir/np_hir_llvm_emitter.pas" "'np.system.object_free.destroy'"
require_repo_reject_token "compiler/ir/np_hir_llvm_emitter.pas" "'np.system.object_free.cleanup'"
require_repo_reject_token "compiler/ir/np_hir_llvm_emitter.pas" "'np.system.object_free.release'"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "SeedRuntimeContracts"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "AddRuntimeContract(NPSYSTEM_PROCESS_INIT)"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "AddRuntimeContract(NPSYSTEM_PROCESS_FINI)"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "FModel.AddRuntimeContract(AContractName)"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "FModel.AddTypedHirNode('runtime-contract', AContractName, 0, 0, '')"
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
reject_repo_uses_unit_under "$REPO_ROOT/compiler" "nextpas.core.system.classes"
reject_repo_uses_unit_under "$CORE_ROOT/src" "nextpas.core.system.classes"
reject_repo_uses_unit_under "$CORE_ROOT/tests" "nextpas.core.system.classes"

require_repo_file "compiler/tests/test_sysutils_createfmt_contract.pas"
require_repo_file "compiler/tests/test_typinfo_contract.pas"
require_repo_file "units/linux-x86_64/System.pas"
require_repo_file "tests/semantic/test_semantic_call_bindings.pas"
require_repo_file "tests/hir/test_hir_object_free_contract.pas"
require_repo_file "compiler/toolchain/np_toolchain_runner.pas"
require_repo_file "compiler/frontend/np_workspace_model.pas"
require_repo_file "rtl/core/sysutils/np_sysutils.pas"
require_repo_file "rtl/core/classes/np_classes.pas"
require_repo_file "core/src/nextpas.core.collections.element_manager.pas"
require_repo_file "core/src/nextpas.core.collections.hashmap.swiss.pas"

require_repo_token "compiler/tests/test_sysutils_createfmt_contract.pas" "CreateFmt"
require_repo_token "compiler/tests/test_sysutils_createfmt_contract.pas" "Format("
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "IntToStr"
require_repo_token "compiler/tests/test_typinfo_contract.pas" "nextpas.core.system.typinfo"
require_repo_token "compiler/tests/test_typinfo_contract.pas" "InitializeArray"
require_repo_token "compiler/tests/test_typinfo_contract.pas" "CopyArray"
require_repo_token "compiler/tests/test_typinfo_contract.pas" "FinalizeArray"
require_repo_reject_regex "compiler/tests/test_typinfo_contract.pas" '^[[:space:]]*TypInfo[,;]'
require_repo_not_uses_unit "compiler/tests/test_typinfo_contract.pas" "TypInfo"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "TObject"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "destructor"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "object-free-runtime"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "NPSYSTEM_OBJECT_FREE"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "nil-guard true"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "heap-release true"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "NPSYSTEM_PROCESS_INIT"
require_repo_token "compiler/sema/np_semantic_analyzer.pas" "NPSYSTEM_PROCESS_FINI"
require_repo_token "compiler/ir/np_hir_builder.pas" "NPSYSTEM_OBJECT_FREE_DESTROY"
require_repo_token "compiler/ir/np_hir_builder.pas" "NPSYSTEM_OBJECT_FREE_CLEANUP"
require_repo_token "compiler/ir/np_hir_builder.pas" "NPSYSTEM_OBJECT_FREE_RELEASE"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "NPSYSTEM_OBJECT_FREE"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "call void @np_object_free_release(ptr "
require_repo_token "compiler/frontend/np_unit_resolver.pas" "ruoImplicitRuntime"
require_repo_token "compiler/frontend/np_unit_resolver.pas" "System.pas"
require_repo_token "units/linux-x86_64/System.pas" "unit System;"
require_repo_token "units/linux-x86_64/System.pas" "TObject = class"
require_repo_token "units/linux-x86_64/System.pas" "destructor Destroy; virtual;"
require_repo_token "units/linux-x86_64/System.pas" "procedure Free;"
require_repo_token "tests/semantic/test_semantic_call_bindings.pas" "object-free-runtime"
require_repo_token "tests/semantic/test_semantic_call_bindings.pas" "np.system.object_free"
require_repo_token "tests/semantic/test_semantic_call_bindings.pas" "nil-guard true"
require_repo_token "tests/semantic/test_semantic_call_bindings.pas" "heap-release true"
require_repo_token "tests/hir/test_hir_object_free_contract.pas" "np.system.object_free.destroy"
require_repo_token "tests/hir/test_hir_object_free_contract.pas" "np.system.object_free.release"
require_repo_token "tests/hir/test_hir_object_free_contract.pas" "call void @np_object_free_release(ptr "
require_repo_token "docs/architecture/runtime-bootstrap-specification.md" "np.system.unit_init"
require_repo_token "docs/architecture/runtime-bootstrap-specification.md" "np.system.unit_fini"
reject_compiler_production_uses_unit "System"
reject_compiler_production_unitpath_token "rtl/core/system"
require_repo_token "compiler/toolchain/np_toolchain_runner.pas" "TFileStream"
require_repo_token "compiler/toolchain/np_toolchain_runner.pas" "ExpandFileName"
require_repo_token "compiler/frontend/np_workspace_model.pas" "ExpandFileName"
require_repo_token "rtl/core/sysutils/np_sysutils.pas" "unit SysUtils;"
require_repo_token "rtl/core/classes/np_classes.pas" "unit Classes;"

require_repo_token "docs/architecture/bootstrap-roadmap.md" "FPC-compatible source"
require_repo_token "docs/architecture/bootstrap-roadmap.md" "nextPas-owned semantic authority"
require_repo_token "docs/architecture/bootstrap-roadmap.md" "FPC compatibility is a build vehicle"
require_repo_token "docs/architecture/rtl-specification.md" "FPC-compatible source"
require_repo_token "docs/architecture/rtl-specification.md" "semantic authority"
require_repo_token "docs/architecture/rtl-specification.md" "stage0 host adapter"
require_repo_token "docs/architecture/runtime-bootstrap-specification.md" "dual-surface model"
require_repo_token "docs/architecture/runtime-bootstrap-specification.md" "nextPas contract path"
require_token "docs/system/README.md" "FPC-compatible source"
require_token "docs/system/README.md" "nextPas-owned semantic authority"
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
require_token "tests/nextpas.core.system/test_system_typinfo_minimal/test_system_typinfo_minimal.lpr" "managed array lifecycle helpers"
require_token "tests/nextpas.core.system/test_system_typinfo_minimal/test_system_typinfo_minimal.lpr" "InitializeArray(LSource"
require_token "tests/nextpas.core.system/test_system_typinfo_minimal/test_system_typinfo_minimal.lpr" "CopyArray(LDest"
require_token "tests/nextpas.core.system/test_system_typinfo_minimal/test_system_typinfo_minimal.lpr" "FinalizeArray(LDest"
require_token "tests/nextpas.core.system/Makefile" "test-typinfo-minimal"
require_token "tests/nextpas.core.system/test_system_typinfo_minimal/Makefile" "test: run compiler-contract"

require_token "src/nextpas.core.system.pas" "NEXTPAS_SYSTEM_NAME = 'nextpas.core.system';"
require_token "src/nextpas.core.system.pas" "MAX_SIZE_INT = nextpas.core.base.MAX_SIZE_INT;"
require_token "src/nextpas.core.system.pas" "MAX_SIZE_UINT = nextpas.core.base.MAX_SIZE_UINT;"
require_token "src/nextpas.core.system.pas" "MIN_SIZE_INT = nextpas.core.base.MIN_SIZE_INT;"
require_token "src/nextpas.core.system.pas" "SIZE_PTR = nextpas.core.base.SIZE_PTR;"
require_token "src/nextpas.core.system.pas" "SIZE_8 = nextpas.core.base.SIZE_8;"
require_token "src/nextpas.core.system.pas" "SIZE_16 = nextpas.core.base.SIZE_16;"
require_token "src/nextpas.core.system.pas" "SIZE_32 = nextpas.core.base.SIZE_32;"
require_token "src/nextpas.core.system.pas" "SIZE_64 = nextpas.core.base.SIZE_64;"
require_token "src/nextpas.core.system.pas" "TBytes = nextpas.core.base.TBytes;"
require_token "src/nextpas.core.system.pas" "TByteSpan = nextpas.core.base.TByteSpan;"
require_token "src/nextpas.core.system.pas" "THashCode = nextpas.core.base.THashCode;"
require_token "src/nextpas.core.system.pas" "procedure FreeAndNil"
require_token "src/nextpas.core.system.pas" "procedure SafeFree"
require_token "src/nextpas.core.system.pas" "procedure ZeroMem"
require_token "src/nextpas.core.system.pas" "procedure CopyMem"
require_token "src/nextpas.core.system.pas" "function CompareMem"
require_token "src/nextpas.core.system.pas" "function Supports"
require_token "src/nextpas.core.system.pas" "nextpas.core.base.utils.FreeAndNil"
require_token "src/nextpas.core.system.pas" "nextpas.core.base.utils.SafeFree"
require_token "src/nextpas.core.system.pas" "nextpas.core.base.utils.ZeroMem"
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
require_token "tests/nextpas.core.system/test_system_facade/test_system_facade.lpr" "system base error aliases mirror base compile-truth"
require_token "tests/nextpas.core.system/test_system_facade/test_system_facade.lpr" "system error taxonomy aliases mirror canonical owners"
require_root_facade_surface_allowlist
reject_token "src/nextpas.core.system.pas" "SysUtils"
reject_token "src/nextpas.core.system.pas" "TypInfo"
reject_token "src/nextpas.core.system.pas" "Classes"

require_token "src/nextpas.core.system.sysutils.pas" "unit nextpas.core.system.sysutils;"
require_token "src/nextpas.core.system.sysutils.pas" "nextpas.core.exception"
require_token "src/nextpas.core.system.sysutils.pas" "nextpas.core.text.compare"
require_token "src/nextpas.core.system.sysutils.pas" "nextpas.core.text.conv"
require_token "src/nextpas.core.system.sysutils.pas" "Exception = nextpas.core.exception.Exception;"
require_token "src/nextpas.core.system.sysutils.pas" "ExceptClass = nextpas.core.exception.ExceptClass;"
require_token "src/nextpas.core.system.sysutils.pas" "EConvertError = nextpas.core.exception.EConvertError;"
require_token "src/nextpas.core.system.sysutils.pas" "EAssertionFailed = nextpas.core.exception.EAssertionFailed;"
require_token "src/nextpas.core.system.sysutils.pas" "function Format"
require_token "src/nextpas.core.system.sysutils.pas" "nextpas.core.text.conv.Format"
require_token "src/nextpas.core.system.sysutils.pas" "function SameText"
require_token "src/nextpas.core.system.sysutils.pas" "nextpas.core.text.compare.TextEqualI"
require_token "src/nextpas.core.system.sysutils.pas" "function IntToStr"
require_token "src/nextpas.core.system.sysutils.pas" "nextpas.core.text.conv.IntToStr"
require_repo_uses_allowlist \
  "core/src/nextpas.core.system.sysutils.pas" \
  "nextpas.core.exception" \
  "nextpas.core.text.compare" \
  "nextpas.core.text.conv"
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
reject_token "src/nextpas.core.system.sysutils.pas" "CompareText"
reject_token "src/nextpas.core.system.sysutils.pas" "LowerCase"
reject_token "src/nextpas.core.system.sysutils.pas" "UpperCase"
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

require_fpc_broad_rtl_allowlist_stable

echo "[PASS] nextpas.core.system source contracts"
