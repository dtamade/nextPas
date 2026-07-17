# Compiler-System M0 Truth Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This repository session must execute inline because the active collaboration rules prohibit subagent dispatch.

**Goal:** Make `rtl/core/system/System.pas` the single compiler-root source, turn `units/linux-x86_64/System.pas` into a checked projection, and establish a typed, machine-checkable inventory for every current `np.system.*` contract.

**Architecture:** The M0 slice keeps the dependency direction `compiler pre-System kernel -> installed System projection -> semantic/HIR contract -> runtime mapping`. A deterministic repository command copies canonical System bytes to the Linux x86_64 installed layout, while source and compiler-consumer gates reject drift. `nextpas.core.system.contracts` remains the constants-only vocabulary owner; a new compiler IR ledger gives each name typed identity and traceability without yet changing hot-path dispatch.

**Tech Stack:** FreePascal/Object Pascal, Bash, GNU Make, existing nextPas stage0 query and test harness.

---

## Keep the slice bounded

This plan implements the first executable M0 project from the approved bootstrap-spine design. It does not:

- migrate sema/HIR/backend dispatch from strings to the typed ledger;
- add `SystemContractFingerprint` or the immutable semantic snapshot;
- change resolver dependency membership or add platform exclusion;
- touch SIMD, bench, HTTP, math, or platform implementation paths;
- claim that stage A/B/C self-hosting is complete;
- delete compatibility facades or historical documents opportunistically.

The allowed implementation paths are:

```text
Makefile
scripts/system-projection.sh
rtl/core/system/System.pas
units/linux-x86_64/System.pas
compiler/ir/np_system_contracts.pas
core/src/nextpas.core.system.contracts.pas
core/tests/nextpas.core.system/
docs/architecture/runtime-bootstrap-specification.md
core/docs/system/
docs/superpowers/specs/2026-07-10-compiler-system-bootstrap-spine-design.md
```

## Task 1: Make installed System a checked canonical projection

**Files:**

- Create: `scripts/system-projection.sh`
- Create: `core/tests/nextpas.core.system/test_system_source_contracts/check_system_projection.sh`
- Modify: `core/tests/nextpas.core.system/test_system_source_contracts/Makefile`
- Modify: `Makefile`
- Modify: `rtl/core/system/System.pas`
- Regenerate: `units/linux-x86_64/System.pas`

- [ ] **Step 1: Write the failing projection contract**

Create `check_system_projection.sh` with one responsibility: validate the public projection command, invalid-target failure, and byte parity.

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
PROJECTION_SCRIPT="$REPO_ROOT/scripts/system-projection.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[[ -x "$PROJECTION_SCRIPT" ]] || fail "projection command missing or not executable: scripts/system-projection.sh"

invalid_output="$(mktemp)"
trap 'rm -f "$invalid_output"' EXIT
if "$PROJECTION_SCRIPT" check unsupported-target >"$invalid_output" 2>&1; then
  fail "unsupported target unexpectedly accepted"
fi
grep -Fq "unsupported System projection target: unsupported-target" "$invalid_output" ||
  fail "unsupported target diagnostic is not stable"

"$PROJECTION_SCRIPT" check linux-x86_64
cmp -s "$REPO_ROOT/rtl/core/system/System.pas" \
  "$REPO_ROOT/units/linux-x86_64/System.pas" ||
  fail "canonical and installed System units differ after projection check"

printf 'system-projection-contract=pass target=linux-x86_64\n'
```

Split the local Makefile target so projection can be run independently from the known-red legacy source contract:

```make
.PHONY: clean test test-projection test-source-contracts

clean:
	@:

test: test-projection test-source-contracts

test-projection:
	bash check_system_projection.sh

test-source-contracts:
	bash check_system_source_contracts.sh
```

- [ ] **Step 2: Run the projection test and observe RED**

Run:

```bash
make -C core/tests/nextpas.core.system/test_system_source_contracts test-projection
```

Expected: FAIL with `projection command missing or not executable: scripts/system-projection.sh`. The failure must be from the missing behavior, not a shell syntax error.

- [ ] **Step 3: Implement the deterministic projection command**

Create `scripts/system-projection.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CANONICAL_PATH="$REPO_ROOT/rtl/core/system/System.pas"

usage() {
  printf 'Usage: %s <check|sync> <target>\n' "${0##*/}" >&2
}

projection_path() {
  case "$1" in
    linux-x86_64)
      printf '%s\n' "$REPO_ROOT/units/linux-x86_64/System.pas"
      ;;
    *)
      printf '[FAIL] unsupported System projection target: %s\n' "$1" >&2
      return 1
      ;;
  esac
}

[[ $# -eq 2 ]] || {
  usage
  exit 2
}

mode="$1"
target="$2"
installed_path="$(projection_path "$target")"
[[ -s "$CANONICAL_PATH" ]] || {
  printf '[FAIL] canonical System source missing or empty: %s\n' "$CANONICAL_PATH" >&2
  exit 1
}

case "$mode" in
  check)
    if ! cmp -s "$CANONICAL_PATH" "$installed_path"; then
      printf '[FAIL] System projection is stale: target=%s\n' "$target" >&2
      diff -u \
        --label rtl/core/system/System.pas \
        --label "units/$target/System.pas" \
        "$CANONICAL_PATH" "$installed_path" >&2 || true
      exit 1
    fi
    printf 'system-projection-status=ready target=%s\n' "$target"
    ;;
  sync)
    mkdir -p "$(dirname "$installed_path")"
    temporary_path="$(mktemp "${installed_path}.tmp.XXXXXX")"
    trap 'rm -f "${temporary_path:-}"' EXIT
    install -m 0644 "$CANONICAL_PATH" "$temporary_path"
    mv -f "$temporary_path" "$installed_path"
    trap - EXIT
    printf 'system-projection-sync=updated target=%s\n' "$target"
    ;;
  *)
    usage
    printf '[FAIL] unsupported System projection mode: %s\n' "$mode" >&2
    exit 2
    ;;
esac
```

Make it executable and add root build entries:

```make
.PHONY: system-projection-check system-projection-sync

system-projection-check:
	bash scripts/system-projection.sh check linux-x86_64

system-projection-sync:
	bash scripts/system-projection.sh sync linux-x86_64
```

- [ ] **Step 4: Move the union of proven declarations to canonical System**

Use the current installed body as the migration input, not as the continuing owner. Preserve its FPC guard and all currently consumed aliases, types, constants, and methods. Add this ownership notice after `{$mode objfpc}{$H+}`:

```pascal
{ Canonical compiler-root source. Refresh target projections with
  `make system-projection-sync`; do not edit installed copies directly. }
```

Preserve the canonical process lifecycle declarations in the non-FPC interface:

```pascal
procedure np_process_init; cdecl;
procedure np_process_fini; cdecl;
```

Preserve their external mappings in the non-FPC implementation:

```pascal
procedure np_process_init; cdecl; external name 'np_process_init';
procedure np_process_fini; cdecl; external name 'np_process_fini';
```

Do not broaden or correct the existing installed-only stubs in this task. M0 is an ownership migration; semantic repairs require separate failing executable tests.

- [ ] **Step 5: Generate the installed projection and observe GREEN**

Run:

```bash
make system-projection-sync
make -C core/tests/nextpas.core.system/test_system_source_contracts test-projection
make system-projection-check
```

Expected: all three commands exit 0 and report `target=linux-x86_64`. Confirm that `git diff --no-index rtl/core/system/System.pas units/linux-x86_64/System.pas` produces no diff.

- [ ] **Step 6: Commit the projection slice**

```bash
git add Makefile scripts/system-projection.sh \
  rtl/core/system/System.pas units/linux-x86_64/System.pas \
  core/tests/nextpas.core.system/test_system_source_contracts/Makefile \
  core/tests/nextpas.core.system/test_system_source_contracts/check_system_projection.sh
git diff --cached --check
git commit -m "feat(system): make installed System a checked projection"
```

## Task 2: Establish the typed system contract ledger

**Files:**

- Modify: `core/src/nextpas.core.system.contracts.pas`
- Create: `compiler/ir/np_system_contracts.pas`
- Modify: `core/tests/nextpas.core.system/test_system_contracts/Makefile`
- Modify: `core/tests/nextpas.core.system/test_system_contracts/test_system_contracts.lpr`
- Modify: `core/tests/nextpas.core.system/Makefile`

- [ ] **Step 1: Write ledger completeness and lookup tests**

Add `np_system_contracts` to the test's `uses` list and add these procedures:

```pascal
procedure TestLedgerCompleteness;
var
  Kind, OtherKind: TSystemContractKind;
  Definition, OtherDefinition: TSystemContractDefinition;
begin
  CheckEqual(Int64(27), Int64(SystemContractCount),
    'ledger should cover every declared system contract');
  for Kind := Low(TSystemContractKind) to High(TSystemContractKind) do
  begin
    Definition := SystemContractAt(Kind);
    CheckEqual(Int64(Ord(Kind)), Int64(Ord(Definition.Kind)),
      'ledger index and contract kind should match');
    CheckStartsWith(Definition.SemanticName, 'np.system.',
      'semantic names should stay in the system namespace');
    CheckTrue(Definition.DeclarationOwner <> '', 'declaration owner is required');
    CheckTrue(Definition.SourceSymbol <> '', 'source symbol or deferred marker is required');
    CheckTrue(Definition.TargetIdentity <> '', 'target identity is required');
    CheckTrue(Definition.OwnershipIntent <> '', 'ownership intent is required');
    CheckTrue(Definition.FailureBehavior <> '', 'failure behavior is required');
    CheckTrue(Definition.HirEvidence <> '', 'HIR evidence or deferred marker is required');
    CheckTrue(Definition.RuntimeMapping <> '', 'runtime mapping or deferred marker is required');
    CheckTrue(Definition.FocusedEvidence <> '', 'focused evidence is required');
    if Kind < High(TSystemContractKind) then
      for OtherKind := Succ(Kind) to High(TSystemContractKind) do
      begin
        OtherDefinition := SystemContractAt(OtherKind);
        CheckNotEqual(Definition.SemanticName, OtherDefinition.SemanticName,
          'semantic names must be unique');
      end;
  end;
end;

procedure TestLedgerLookup;
var
  Definition: TSystemContractDefinition;
begin
  CheckTrue(TryFindSystemContract(NPSYSTEM_OBJECT_FREE, Definition),
    'object-free contract should be discoverable');
  CheckEqual(Int64(Ord(sckObjectFree)), Int64(Ord(Definition.Kind)),
    'lookup should return typed object-free identity');
  CheckFalse(TryFindSystemContract('np.system.not_registered', Definition),
    'unknown contracts must fail closed');
end;
```

Register both tests in the suite. Add the compiler IR search path after `common.mk`:

```make
PROGRAM := test_system_contracts
include ../../common.mk
FPC_FLAGS += -Fu$(CORE_ROOT)/../compiler/ir
```

Add `test-contracts` to the parent system module's default `test` prerequisites so the ledger cannot silently leave the module gate.

- [ ] **Step 2: Run the contract test and observe RED**

Run:

```bash
make -C core/tests/nextpas.core.system/test_system_contracts clean test
```

Expected: compiler failure `Can't find unit np_system_contracts` (or the equivalent missing-unit diagnostic).

- [ ] **Step 3: Complete the constants-only vocabulary**

Add the documented runtime vocabulary that is missing from `nextpas.core.system.contracts`:

```pascal
NPSYSTEM_STRING_INIT = 'np.system.string_init';
NPSYSTEM_STRING_FINI = 'np.system.string_fini';
NPSYSTEM_STRING_ASSIGN = 'np.system.string_assign';
NPSYSTEM_DYNARRAY_INIT = 'np.system.dynarray_init';
NPSYSTEM_DYNARRAY_FINI = 'np.system.dynarray_fini';
NPSYSTEM_DYNARRAY_SET_LENGTH = 'np.system.dynarray_set_length';
NPSYSTEM_INTERFACE_ADDREF = 'np.system.interface_addref';
NPSYSTEM_INTERFACE_RELEASE = 'np.system.interface_release';
NPSYSTEM_MANAGED_RECORD_INIT = 'np.system.managed_record_init';
NPSYSTEM_MANAGED_RECORD_FINI = 'np.system.managed_record_fini';
NPSYSTEM_HEAP_ALLOC = 'np.system.heap_alloc';
NPSYSTEM_HEAP_FREE = 'np.system.heap_free';
```

Extend the stable-name tests with exact assertions for all twelve constants.

- [ ] **Step 4: Implement the compiler IR ledger**

Create `np_system_contracts.pas` with this public surface:

```pascal
unit np_system_contracts;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.system.contracts;

type
  TSystemContractKind = (
    sckProcessInit,
    sckProcessFini,
    sckUnitInit,
    sckUnitFini,
    sckHalt,
    sckStringInit,
    sckStringFini,
    sckStringAssign,
    sckDynArrayInit,
    sckDynArrayFini,
    sckDynArraySetLength,
    sckInterfaceAddRef,
    sckInterfaceRelease,
    sckManagedRecordInit,
    sckManagedRecordFini,
    sckHeapAlloc,
    sckHeapFree,
    sckObjectFree,
    sckObjectFreeDestroy,
    sckObjectFreeCleanup,
    sckObjectFreeRelease,
    sckRuntimeFault,
    sckExceptionTryPush,
    sckExceptionTryPop,
    sckExceptionRaise,
    sckExceptionFinallyEnd,
    sckExceptionExceptEnd
  );

  TSystemContractEvidenceLevel = (
    scelVocabulary,
    scelSemantic,
    scelHir,
    scelBackend,
    scelExecutable
  );

  TSystemContractDefinition = record
    Kind: TSystemContractKind;
    SemanticName: string;
    DeclarationOwner: string;
    SourceSymbol: string;
    TargetIdentity: string;
    OwnershipIntent: string;
    FailureBehavior: string;
    HirEvidence: string;
    RuntimeMapping: string;
    FocusedEvidence: string;
    EvidenceLevel: TSystemContractEvidenceLevel;
  end;

function SystemContractCount: LongInt;
function SystemContractAt(AKind: TSystemContractKind): TSystemContractDefinition;
function TryFindSystemContract(const ASemanticName: string;
  out ADefinition: TSystemContractDefinition): Boolean;

implementation
```

Implement one definition per enum value. Every row must use the matching `NPSYSTEM_*` constant and the following exact inventory; `deferred` is an explicit state, never an empty field:

| Kind                     | Semantic constant                | Source symbol                   | Target identity       | Ownership intent                | Failure behavior             | HIR evidence                     | Runtime mapping                            | Focused evidence                          | Level            |
| ------------------------ | -------------------------------- | ------------------------------- | --------------------- | ------------------------------- | ---------------------------- | -------------------------------- | ------------------------------------------ | ----------------------------------------- | ---------------- |
| `sckProcessInit`         | `NPSYSTEM_PROCESS_INIT`          | `System.np_process_init`        | `process`             | `runtime-owned process state`   | `runtime-startup-failed`     | `process-init-runtime`           | `np_process_init`                          | `test_process_lifecycle`                  | `scelHir`        |
| `sckProcessFini`         | `NPSYSTEM_PROCESS_FINI`          | `System.np_process_fini`        | `process`             | `runtime-owned process state`   | `runtime-abort`              | `process-fini-runtime`           | `np_process_fini`                          | `test_process_lifecycle`                  | `scelHir`        |
| `sckUnitInit`            | `NPSYSTEM_UNIT_INIT`             | `System unit initialization`    | `unit`                | `compiler-ordered unit state`   | `unit-initialization-failed` | `unit-init-runtime`              | `unit-specific init entry`                 | `test_semantic_runtime_contract_seed`     | `scelSemantic`   |
| `sckUnitFini`            | `NPSYSTEM_UNIT_FINI`             | `System unit finalization`      | `unit`                | `compiler-ordered unit state`   | `unit-finalization-failed`   | `unit-fini-runtime`              | `unit-specific fini entry`                 | `test_semantic_runtime_contract_seed`     | `scelSemantic`   |
| `sckHalt`                | `NPSYSTEM_HALT`                  | `System.Halt`                   | `exit-code`           | `none`                          | `runtime-abort`              | `halt-call-runtime`              | `backend halt lowering`                    | `test_hir_node_kind`                      | `scelBackend`    |
| `sckStringInit`          | `NPSYSTEM_STRING_INIT`           | `System.AnsiString`             | `managed-string`      | `owned destination`             | `runtime-fault`              | `deferred`                       | `deferred`                                 | `runtime-contracts.md`                    | `scelVocabulary` |
| `sckStringFini`          | `NPSYSTEM_STRING_FINI`           | `System.AnsiString`             | `managed-string`      | `owned value release`           | `runtime-fault`              | `string cleanup nodes`           | `string release helpers`                   | `test_hir_string_ownership_contract`      | `scelHir`        |
| `sckStringAssign`        | `NPSYSTEM_STRING_ASSIGN`         | `System.AnsiString`             | `managed-string`      | `copy or move assignment`       | `runtime-fault`              | `string assignment nodes`        | `string assignment helpers`                | `test_hir_string_ownership_contract`      | `scelHir`        |
| `sckDynArrayInit`        | `NPSYSTEM_DYNARRAY_INIT`         | `System dynamic array`          | `managed-dynarray`    | `owned destination`             | `runtime-fault`              | `deferred`                       | `deferred`                                 | `runtime-contracts.md`                    | `scelVocabulary` |
| `sckDynArrayFini`        | `NPSYSTEM_DYNARRAY_FINI`         | `System dynamic array`          | `managed-dynarray`    | `owned value release`           | `runtime-fault`              | `dynarray-cleanup-runtime`       | `np_dynarray_release`                      | `test_hir_dynarray_release_runtime_smoke` | `scelExecutable` |
| `sckDynArraySetLength`   | `NPSYSTEM_DYNARRAY_SET_LENGTH`   | `System dynamic array`          | `managed-dynarray`    | `owned buffer resize`           | `runtime-fault`              | `setlength-arr-runtime`          | `np_dynarray_resize`                       | `test_hir_dynarray_release_runtime_smoke` | `scelExecutable` |
| `sckInterfaceAddRef`     | `NPSYSTEM_INTERFACE_ADDREF`      | `System interface reference`    | `interface-reference` | `shared reference acquire`      | `runtime-fault`              | `intf_addref`                    | `np_intf_addref`                           | `test_hir_interface_contract`             | `scelBackend`    |
| `sckInterfaceRelease`    | `NPSYSTEM_INTERFACE_RELEASE`     | `System interface reference`    | `interface-reference` | `shared reference release`      | `runtime-fault`              | `intf_release`                   | `np_intf_release`                          | `test_hir_interface_contract`             | `scelBackend`    |
| `sckManagedRecordInit`   | `NPSYSTEM_MANAGED_RECORD_INIT`   | `System managed record`         | `managed-record`      | `owned fields initialize`       | `runtime-fault`              | `deferred`                       | `deferred`                                 | `runtime-contracts.md`                    | `scelVocabulary` |
| `sckManagedRecordFini`   | `NPSYSTEM_MANAGED_RECORD_FINI`   | `System managed record`         | `managed-record`      | `owned fields release`          | `runtime-fault`              | `managed-record-cleanup-runtime` | `deferred`                                 | `test_hir_node_kind`                      | `scelHir`        |
| `sckHeapAlloc`           | `NPSYSTEM_HEAP_ALLOC`            | `System memory manager hook`    | `allocation-size`     | `caller-owned allocation`       | `runtime-fault`              | `arr_alloc and class_alloc`      | `np_alloc and np_object_alloc`             | `test_hir_class_alloc_contract`           | `scelBackend`    |
| `sckHeapFree`            | `NPSYSTEM_HEAP_FREE`             | `System memory manager hook`    | `allocation`          | `owned allocation release`      | `runtime-fault`              | `object and array release nodes` | `np_free`                                  | `test_hir_large_alloc_runtime_smoke`      | `scelExecutable` |
| `sckObjectFree`          | `NPSYSTEM_OBJECT_FREE`           | `System.TObject.Free`           | `class-instance`      | `owned object release`          | `runtime-fault`              | `object-free-runtime`            | `np_object_free_release`                   | `test_hir_object_free_contract`           | `scelBackend`    |
| `sckObjectFreeDestroy`   | `NPSYSTEM_OBJECT_FREE_DESTROY`   | `System.TObject.Destroy`        | `class-instance`      | `object destruction`            | `runtime-fault`              | `np.system.object_free.destroy`  | `virtual Destroy dispatch`                 | `test_hir_object_free_contract`           | `scelHir`        |
| `sckObjectFreeCleanup`   | `NPSYSTEM_OBJECT_FREE_CLEANUP`   | `System.TObject.Free`           | `class-instance`      | `managed field cleanup`         | `runtime-fault`              | `np.system.object_free.cleanup`  | `compiler-planned cleanup`                 | `test_hir_object_free_contract`           | `scelHir`        |
| `sckObjectFreeRelease`   | `NPSYSTEM_OBJECT_FREE_RELEASE`   | `System.TObject.Free`           | `class-instance`      | `object storage release`        | `runtime-fault`              | `np.system.object_free.release`  | `np_object_free_release`                   | `test_hir_object_free_contract`           | `scelBackend`    |
| `sckRuntimeFault`        | `NPSYSTEM_RUNTIME_FAULT`         | `System runtime fault boundary` | `fault-code`          | `none`                          | `runtime-fault`              | `fault-specific nodes`           | `np_allocator_fault and np_dynarray_fault` | `runtime-contracts.md`                    | `scelBackend`    |
| `sckExceptionTryPush`    | `NPSYSTEM_EXCEPTION_TRY_PUSH`    | `System exception boundary`     | `exception-frame`     | `runtime-owned exception frame` | `runtime-abort`              | `try-begin-runtime`              | `np_try_push`                              | `test_hir_exception`                      | `scelBackend`    |
| `sckExceptionTryPop`     | `NPSYSTEM_EXCEPTION_TRY_POP`     | `System exception boundary`     | `exception-frame`     | `runtime-owned exception frame` | `runtime-abort`              | `try-end-runtime`                | `np_try_pop`                               | `test_hir_exception`                      | `scelBackend`    |
| `sckExceptionRaise`      | `NPSYSTEM_EXCEPTION_RAISE`       | `System exception boundary`     | `exception-object`    | `transferred exception object`  | `runtime-abort`              | `raise-runtime`                  | `np_raise`                                 | `test_hir_exception`                      | `scelBackend`    |
| `sckExceptionFinallyEnd` | `NPSYSTEM_EXCEPTION_FINALLY_END` | `System exception boundary`     | `exception-frame`     | `runtime-owned exception frame` | `runtime-abort`              | `finally-end-runtime`            | `np_finally_end`                           | `test_hir_exception`                      | `scelBackend`    |
| `sckExceptionExceptEnd`  | `NPSYSTEM_EXCEPTION_EXCEPT_END`  | `System exception boundary`     | `exception-frame`     | `runtime-owned exception frame` | `runtime-abort`              | `except-end-runtime`             | `np_except_end`                            | `test_hir_exception`                      | `scelBackend`    |

Use `nextpas.core.system.contracts` as `DeclarationOwner` for every row. Implement lookup as a bounded enum loop with an exact, case-sensitive comparison; unknown names return `False` and a default record.

- [ ] **Step 5: Run the ledger tests and observe GREEN**

Run:

```bash
make -C core/tests/nextpas.core.system/test_system_contracts clean test
```

Expected: five registered contract tests pass, heaptrc reports zero unfreed blocks, and no warning is emitted for the ledger unit.

- [ ] **Step 6: Commit the ledger slice**

```bash
git add core/src/nextpas.core.system.contracts.pas \
  compiler/ir/np_system_contracts.pas \
  core/tests/nextpas.core.system/Makefile \
  core/tests/nextpas.core.system/test_system_contracts/Makefile \
  core/tests/nextpas.core.system/test_system_contracts/test_system_contracts.lpr
git diff --cached --check
git commit -m "feat(compiler-system): add typed system contract ledger"
```

## Task 3: Make source contracts follow logical compiler owners

**Files:**

- Modify: `core/tests/nextpas.core.system/test_system_source_contracts/lib/helpers.sh`
- Modify: `core/tests/nextpas.core.system/test_system_source_contracts/check_system_source_contracts.sh`

- [ ] **Step 1: Re-run and preserve the existing RED**

Run:

```bash
make -C core/tests/nextpas.core.system/test_system_source_contracts test-source-contracts
```

Expected: FAIL because the gate requires `intf_addref` in `compiler/ir/np_hir_builder.pas` even though the producer lives in `np_hir_builder_vcall.inc`.

- [ ] **Step 2: Add a fail-closed logical-owner helper**

Add to `lib/helpers.sh`:

```bash
require_repo_owner_family_token() {
  local relative_root="$1"
  local owner_base="$2"
  local token="$3"
  if ! rg -F --quiet \
    --glob "${owner_base}.pas" \
    --glob "${owner_base}_*.inc" \
    -- "$token" "$REPO_ROOT/$relative_root"; then
    fail "$relative_root/$owner_base owner family missing token: $token"
  fi
}
```

Replace every physical-file assertion for these sanctioned split owners:

```text
compiler/sema/np_semantic_analyzer.pas
compiler/ir/np_hir_builder.pas
compiler/ir/np_hir_llvm_emitter.pas
```

with logical-owner calls using roots `compiler/sema` or `compiler/ir` and owner bases `np_semantic_analyzer`, `np_hir_builder`, or `np_hir_llvm_emitter`. Keep assertions for unsplit owners unchanged.

Add ledger source checks:

```bash
require_repo_file "compiler/ir/np_system_contracts.pas"

contract_constants="$(mktemp)"
ledger_constants="$(mktemp)"
trap 'rm -f "$contract_constants" "$ledger_constants"' EXIT
rg -o 'NPSYSTEM_[A-Z0-9_]+' \
  "$CORE_ROOT/src/nextpas.core.system.contracts.pas" | sort -u >"$contract_constants"
rg -o 'NPSYSTEM_[A-Z0-9_]+' \
  "$REPO_ROOT/compiler/ir/np_system_contracts.pas" | sort -u >"$ledger_constants"
if ! diff -u "$contract_constants" "$ledger_constants"; then
  fail "system contract constants and typed ledger are not one-to-one"
fi
rm -f "$contract_constants" "$ledger_constants"
trap - EXIT
```

- [ ] **Step 3: Run the source contract and observe GREEN**

Run:

```bash
make -C core/tests/nextpas.core.system/test_system_source_contracts test
```

Expected: projection check and source contract both pass. If a later assertion exposes another sanctioned split owner, convert only that logical owner; do not weaken token requirements or scan the whole repository.

- [ ] **Step 4: Commit the logical-owner gate**

```bash
git add core/tests/nextpas.core.system/test_system_source_contracts/lib/helpers.sh \
  core/tests/nextpas.core.system/test_system_source_contracts/check_system_source_contracts.sh
git diff --cached --check
git commit -m "test(compiler-system): follow logical compiler owner families"
```

## Task 4: Reconcile authoritative bootstrap status

**Files:**

- Modify: `docs/superpowers/specs/2026-07-10-compiler-system-bootstrap-spine-design.md`
- Modify: `docs/architecture/runtime-bootstrap-specification.md`
- Modify: `core/docs/system/README.md`
- Modify: `core/docs/system/goal-tree.md`
- Modify: `core/docs/system/self-hosting-readiness.md`
- Modify: `core/docs/system/contract-coverage-table.md`
- Modify: `core/tests/nextpas.core.system/test_system_source_contracts/check_system_source_contracts.sh`

- [ ] **Step 1: Add RED assertions for the new authority boundary**

Require these exact tokens in the relevant documents before editing them:

```bash
require_repo_token "docs/architecture/runtime-bootstrap-specification.md" "canonical compiler-root source"
require_repo_token "docs/architecture/runtime-bootstrap-specification.md" "system-projection-check"
require_token "docs/system/README.md" "M0 truth convergence"
require_token "docs/system/README.md" "not self-host ready"
require_token "docs/system/goal-tree.md" "canonical projection parity"
require_token "docs/system/self-hosting-readiness.md" "A -> B -> C has not executed"
require_token "docs/system/contract-coverage-table.md" "typed ledger is authoritative"
```

Run `test-source-contracts` and confirm it fails first on the missing new authority token.

- [ ] **Step 2: Promote the approved source/projection facts into architecture docs**

Change the design status to `approved; M0 implementation in progress` and add a runtime-bootstrap section with this exact ownership table:

| Surface                               | Owner role                                                  | Mutation rule                                            |
| ------------------------------------- | ----------------------------------------------------------- | -------------------------------------------------------- |
| `rtl/core/system/System.pas`          | canonical compiler-root source                              | edited by compiler-system owner                          |
| `units/linux-x86_64/System.pas`       | target-installed projection consumed by compiler resolution | changed only by `make system-projection-sync`            |
| `core/src/nextpas.core.system*`       | namespaced facade and constants-only contract vocabulary    | must not redefine compiler-root truth                    |
| `compiler/ir/np_system_contracts.pas` | typed contract inventory                                    | consumes vocabulary; does not implement runtime behavior |
| `rtl/runtime/` and backend helpers    | executable implementation                                   | must map from registered contracts                       |

Document `make system-projection-check` as a required source-truth gate and state that ordinary compiler invocations never write the projection.

- [ ] **Step 3: Make core system docs describe current truth, not phase mythology**

At the start of `README.md`, replace the unconditional S8-complete claim with:

```markdown
## Current authority and status

The compiler and L0 System are one bootstrap spine. M0 truth convergence is in progress:
`rtl/core/system/System.pas` is the canonical compiler-root source,
`units/linux-x86_64/System.pas` is its checked Linux x86_64 projection, and
`nextpas.core.system*` is a facade/contract family rather than another root implementation.

The repository is not self-host ready. Stage0 compiler fixtures and several runtime contracts work,
but a complete executable A -> B -> C rebuild has not executed. Historical S0-S12 sections below
are capability inventories and proposals; they are not current readiness authority.
```

Remove or rewrite claims that all S4-S8 work, ABI stability, 126 tests, full FPC System coverage, or production readiness is complete when no fresh gate proves them. Keep live facade inventory, owner boundaries, and non-goals.

Add an M0 section to `goal-tree.md` with checked items only for facts completed by Tasks 1-3 and unchecked items for typed-dispatch integration, fingerprint, semantic snapshot, and A/B/C bootstrap. Mark the older S-stage tree as historical capability inventory.

Add a prominent status boundary to `self-hosting-readiness.md`: current focused fixtures are partial evidence, `A -> B -> C has not executed`, and old `PHASE 0 COMPLETE` labels are archived assessments rather than present readiness claims.

- [ ] **Step 4: Rebuild the coverage table from the typed ledger**

Replace physical line-number references with logical owner/evidence names. The primary table must contain exactly one row for each of the 27 semantic names in Task 2, in enum order, and state:

```markdown
The typed ledger is authoritative for contract identity and traceability. This table is its human-readable projection; source-contract tests reject missing or extra names.
```

Use evidence levels `vocabulary`, `semantic`, `HIR`, `backend`, and `executable`. Do not describe vocabulary-only entries as implemented. Preserve the backend-private helper warning and current open-risk discussion after correcting unit-lifecycle and physical-file claims.

Extend the source contract to parse the first-column `np.system.*` rows between explicit `ledger-table:start` and `ledger-table:end` comments, compare them with string values from `nextpas.core.system.contracts.pas`, and fail on missing or extra names.

- [ ] **Step 5: Format and run the documentation RED-to-GREEN gate**

Run:

```bash
npx prettier --write \
  docs/superpowers/specs/2026-07-10-compiler-system-bootstrap-spine-design.md \
  docs/architecture/runtime-bootstrap-specification.md \
  core/docs/system/README.md \
  core/docs/system/goal-tree.md \
  core/docs/system/self-hosting-readiness.md \
  core/docs/system/contract-coverage-table.md
make -C core/tests/nextpas.core.system/test_system_source_contracts test
```

Expected: Prettier reports all six files, projection parity remains green, the ledger/document comparison is exact, and the source-contract target passes.

- [ ] **Step 6: Commit the truth-documentation slice**

```bash
git add docs/superpowers/specs/2026-07-10-compiler-system-bootstrap-spine-design.md \
  docs/architecture/runtime-bootstrap-specification.md \
  core/docs/system/README.md core/docs/system/goal-tree.md \
  core/docs/system/self-hosting-readiness.md \
  core/docs/system/contract-coverage-table.md \
  core/tests/nextpas.core.system/test_system_source_contracts/check_system_source_contracts.sh
git diff --cached --check
git commit -m "docs(compiler-system): reconcile M0 bootstrap truth"
```

## Task 5: Verify both sides of the bootstrap spine

**Files:**

- No intended production edits; only repair a failure if a fresh focused command proves it belongs to this slice.

- [ ] **Step 1: Verify source truth and typed inventory**

Run:

```bash
make system-projection-check
make focused FOCUS=core/tests/nextpas.core.system/test_system_source_contracts
make -C core/tests/nextpas.core.system/test_system_contracts clean test
```

Expected: projection ready, source contract pass, five contract tests pass, and zero heaptrc leaks.

- [ ] **Step 2: Verify explicit and implicit compiler consumers**

Run:

```bash
make -C core/tests/nextpas.core.system test-stage0-system-object-free-query
./tests/run_all_tests.sh --filter compiler-pass
./tests/run_all_tests.sh --filter compiler-fail
```

Expected:

- explicit and implicit query pass markers are printed;
- definitions resolve to the installed/canonical System source family;
- compiler-pass reports all fixtures passed;
- compiler-fail reports all snapshots stable.

- [ ] **Step 3: Run repository hygiene and review the exact scope**

Run:

```bash
make hygiene
git diff --check HEAD~4..HEAD
git status --short --branch
git diff --stat "$(git merge-base HEAD main)"..HEAD
git diff --name-only "$(git merge-base HEAD main)"..HEAD
```

Review requirements:

- no bench/SIMD/HTTP/platform/math path appears;
- ignored `task_plan.md`, `findings.md`, and `progress.md` are absent;
- installed System is byte-identical to canonical System;
- each commit is independently understandable and reversible;
- no document claims self-host, production, ABI, or runtime evidence beyond the fresh commands.

- [ ] **Step 4: Prepare a current-main landing candidate**

After all commands above pass, use the repository worktree helper to create a temporary `landing/compiler-system-m0-20260711` candidate from the then-current `main`. Cherry-pick the two approved bootstrap-spine design commits, the M0 plan, and the implementation commits in dependency order; do not raw-merge `codex/compiler-system`.

Run on the candidate:

```bash
make landing-check \
  BASE_REF=main \
  ALLOW_PATHS="Makefile scripts/system-projection.sh rtl/core/system units/linux-x86_64 compiler/ir/np_system_contracts.pas core/src/nextpas.core.system.contracts.pas core/tests/nextpas.core.system docs/architecture/runtime-bootstrap-specification.md core/docs/system docs/superpowers/specs docs/superpowers/plans" \
  FOCUS=core/tests/nextpas.core.system/test_system_source_contracts
make -C core/tests/nextpas.core.system/test_system_contracts clean test
make -C core/tests/nextpas.core.system test-stage0-system-object-free-query
./tests/run_all_tests.sh --filter compiler-pass
./tests/run_all_tests.sh --filter compiler-fail
```

Only after fresh candidate evidence passes may `main` move by `git merge --ff-only`. Preserve the long-lived `.worktrees/compiler-system` lane; remove only the clean, fully absorbed temporary landing worktree and branch.
