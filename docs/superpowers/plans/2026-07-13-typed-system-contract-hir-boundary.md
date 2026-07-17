# Typed System Contract HIR Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> Execution status: Tasks 1-4, Task 5 verification, and the receiver/target review correction are complete; final review and landing are pending.

**Goal:** Make the object-free compiler/System contract family use typed HIR identities for LLVM dispatch while preserving canonical semantic names as compatibility projections.

**Architecture:** `THIRInstr` carries an explicit presence bit and `TSystemContractKind`. A single helper assigns the typed identity and projects the ledger name. The HIR builder assigns object-free kinds, and the LLVM emitter dispatches those kinds before legacy intrinsic strings and rejects unsupported typed contracts. Verifier and emitter sequence state bind every continuation to the root receiver and keep the root destroy target authoritative.

**Tech Stack:** FreePascal/Object Pascal, the existing typed System contract ledger, HIR builder and LLVM emitter, Bash-driven compiler verification.

---

## Keep the file boundary narrow

**Production files:**

- `compiler/ir/np_hir_model.pas`: typed identity storage and construction helpers.
- `compiler/ir/np_hir_verifier.pas`: structural validation for typed contracts.
- `compiler/ir/np_hir_builder.pas`: ledger dependency instead of direct string vocabulary.
- `compiler/ir/np_hir_builder_runtime.inc`: guard, destroy, and release identity assignment.
- `compiler/ir/np_hir_builder_cleanup.inc`: cleanup identity assignment.
- `compiler/ir/np_hir_llvm_emitter.pas`: typed dispatch helper declarations.
- `compiler/ir/np_hir_llvm_emitter_instr_helpers.inc`: typed object-free dispatch implementation.
- `compiler/ir/np_hir_llvm_emitter_instr.inc`: typed dispatch entry and removal of object-free string branches.

**Test and documentation files:**

- `tests/hir/test_hir_object_free_contract.pas`: executable typed-boundary regression.
- `core/tests/nextpas.core.system/Makefile`: hermetic object-free consumer target.
- `core/tests/nextpas.core.system/test_system_source_contracts/check_system_source_contracts.sh`: typed source-contract and raw-string regression guard.
- `docs/architecture/runtime-bootstrap-specification.md`: stable HIR contract ownership fact.
- `docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md`: current M0 evidence and M1 progress.
- `docs/plans/goal-tree.md`: current milestone state.

Temporary `task_plan.md`, `findings.md`, and `progress.md` are never committed.

## Task 1: Prove the current string authority is wrong

**Files:**

- Modify: `tests/hir/test_hir_object_free_contract.pas`

- [x] **Step 1: Add typed assertions before production changes**

Import `np_system_contracts`, change the object-free typed HIR fixture display
name from `np.system.object_free` to `untrusted-object-free-label`, and locate
the three HIR instructions with typed checks:

```pascal
if (Instr.Kind = hikIntrinsic) and
  IsSystemContract(Instr, sckObjectFree) then
begin
  FoundContract := True;
  if Instr.IntrinsicName <>
    SystemContractAt(sckObjectFree).SemanticName then
    Fail('object-free-semantic-name-projection-mismatch');
end;
```

Repeat the exact typed check and canonical projection assertion for
`sckObjectFreeDestroy` and `sckObjectFreeRelease`. Keep all existing operand,
LLVM ordering, and runtime declaration assertions.

- [x] **Step 2: Run the focused test and confirm RED**

Run:

```bash
build_dir="$(mktemp -d)"
fpc -Fucompiler/frontend -Fucompiler/sema -Fucompiler/syntax -Fucompiler/ir \
  -Furtl/core/base -Furtl/core/text -Fucore/src -Ficore/src \
  -FE"$build_dir" -FU"$build_dir" \
  tests/hir/test_hir_object_free_contract.pas
```

Expected: compilation fails because `IsSystemContract` does not exist. If the
test is temporarily written without the helper, runtime must fail with
`missing-object-free-hir-intrinsic` because the builder copied the untrusted
display string.

## Task 2: Add typed identity to HIR instructions

**Files:**

- Modify: `compiler/ir/np_hir_model.pas`
- Test: `tests/hir/test_hir_object_free_contract.pas`

- [x] **Step 1: Add the representation and helper API**

Add `np_system_contracts` to the interface uses and extend `THIRInstr`:

```pascal
HasSystemContract: Boolean;
SystemContractKind: TSystemContractKind;
```

Declare:

```pascal
procedure AssignSystemContract(var AInstr: THIRInstr;
  AKind: TSystemContractKind);
function IsSystemContract(const AInstr: THIRInstr;
  AKind: TSystemContractKind): Boolean;
function ValidateSystemContractInstr(const AInstr: THIRInstr;
  ATypes: THIRTypeTable; out AError: string): Boolean;
```

Implement the helpers with the ledger as the only name source:

```pascal
procedure AssignSystemContract(var AInstr: THIRInstr;
  AKind: TSystemContractKind);
var
  Definition: TSystemContractDefinition;
begin
  Definition := SystemContractAt(AKind);
  if Definition.SemanticName = '' then
    raise ERangeError.Create('invalid System contract kind');
  AInstr.HasSystemContract := True;
  AInstr.SystemContractKind := AKind;
  AInstr.IntrinsicName := Definition.SemanticName;
end;

function IsSystemContract(const AInstr: THIRInstr;
  AKind: TSystemContractKind): Boolean;
begin
  Result := AInstr.HasSystemContract and
    (AInstr.SystemContractKind = AKind);
end;
```

Add `SysUtils` to implementation uses for `ERangeError`.

The validator must reject typed instructions that are not `hikIntrinsic`, use
an unmigrated kind, have a non-canonical text projection, do not have exactly
one pointer operand, or omit a required target. Root, destroy, and cleanup
require a target; release does not.

- [x] **Step 2: Compile the test and keep it RED for missing builder behavior**

Run the Task 1 compile command, then run the binary if compilation succeeds.
Expected runtime failure: `missing-object-free-hir-intrinsic`.

## Task 3: Make builder and emitter dispatch typed contracts

**Files:**

- Modify: `compiler/ir/np_hir_builder.pas`
- Modify: `compiler/ir/np_hir_builder_runtime.inc`
- Modify: `compiler/ir/np_hir_builder_cleanup.inc`
- Modify: `compiler/ir/np_hir_llvm_emitter.pas`
- Modify: `compiler/ir/np_hir_llvm_emitter_instr_helpers.inc`
- Modify: `compiler/ir/np_hir_llvm_emitter_instr.inc`
- Modify: `compiler/ir/np_hir_verifier.pas`
- Test: `tests/hir/test_hir_object_free_contract.pas`

- [x] **Step 1: Assign typed identities in the HIR builder**

Replace the implementation import of `nextpas.core.system.contracts` with
`np_system_contracts`. Replace each direct object-free name assignment:

```pascal
AssignSystemContract(Instr, sckObjectFree);
AssignSystemContract(Instr, sckObjectFreeDestroy);
AssignSystemContract(Instr, sckObjectFreeCleanup);
AssignSystemContract(Instr, sckObjectFreeRelease);
```

`ProcessObjectFreeRuntime` must not copy `ANode.DisplayName` into
`IntrinsicName`.

- [x] **Step 2: Add one typed emitter dispatch helper**

Declare `IsObjectFreeGuardContinuation` and `EmitSystemContractInstr` on
`THIRLlvmEmitter`. The continuation predicate must accept only
`sckObjectFreeDestroy`, `sckObjectFreeCleanup`, and `sckObjectFreeRelease`.
It must not accept `sckObjectFree`, because a new root closes any previously
pending guard before starting its own sequence.

Implement `EmitSystemContractInstr` so it returns `False` only when
`HasSystemContract=False`. Dispatch `sckObjectFree`,
`sckObjectFreeDestroy`, `sckObjectFreeCleanup`, and `sckObjectFreeRelease` to
the existing emitter helpers. For any other typed kind, raise `Exception` with
the numeric kind so new typed contracts cannot disappear silently.

Before the emitter's general instruction-kind `case`, detect every instruction
whose `HasSystemContract` is set, call `ValidateSystemContractInstr`, dispatch
the typed contract, and exit. This placement prevents a malformed typed
`hikCall` from bypassing validation through ordinary call lowering. Raise with
the stable validation error when malformed HIR reaches codegen.
`THIRVerifier.VerifyTypes` must call the same helper and add the returned error
for every typed instruction.

Add a separate block-local sequence pass to `THIRVerifier`. A root activates
the sequence, destroy/cleanup require it, release requires and closes it, and a
non-typed instruction closes it. Report
`system-contract-sequence-root-missing:<kind>` for standalone continuations.
Track the root receiver and destroy target while the sequence is active. Reject
a continuation that changes receiver with
`system-contract-sequence-receiver-mismatch`, and reject a destroy target that
differs from the root with `system-contract-sequence-destroy-target-mismatch`.
Do not require release at block end during this slice.

The emitter must run structural validation before closing or opening any guard.
Destroy, cleanup, and release must also require
`FPendingObjectFreeActive=True`; otherwise they raise the same stable sequence
error before emitting output. The pending emitter state must retain the same
root receiver and destroy target as the verifier, validate them before output,
and clear them whenever the guard closes.

- [x] **Step 3: Remove object-free string control flow**

Use `IsObjectFreeGuardContinuation` in the pending-guard check. At the start
of the `hikIntrinsic` branch, call `EmitSystemContractInstr` and exit when it handled
the instruction. Delete the four `SameText(IntrinsicName,
NPSYSTEM_OBJECT_FREE...)` branches.

- [x] **Step 4: Run the focused test and confirm GREEN**

Before GREEN, extend the test with manually constructed malformed typed
instructions. Require verifier failures for a non-intrinsic kind, unsupported
typed kind, missing operand, non-pointer operand, and missing required target.
Directly send the malformed non-intrinsic instruction to the emitter and require
the same `system-contract-kind-must-be-intrinsic` failure.
Add structurally valid standalone destroy, cleanup, and release instructions,
and require both verifier and emitter to reject each one with
`system-contract-sequence-root-missing`. Add root-plus-continuation cases that
change the receiver for all three continuation kinds and one destroy case that
changes the target; require the stable sequence mismatch errors from both
consumers. Also cover `sckObjectFreeCleanup` identity and placement when a
cleanup class is present.

Run the Task 1 compile command and then:

```bash
"$build_dir/test_hir_object_free_contract"
```

Expected:

```text
hir-object-free-contract-status=pass
```

- [x] **Step 5: Commit the executable architecture slice**

Stage only the eight production files and the HIR test. Review
`git diff --cached`, then commit:

```text
feat(compiler-system): type object-free HIR contracts
```

## Task 4: Reconcile stable docs and the active roadmap

**Files:**

- Modify: `docs/architecture/runtime-bootstrap-specification.md`
- Modify: `docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md`
- Modify: `docs/plans/goal-tree.md`

- [x] **Step 1: Record the stable typed-boundary rule**

Document that `THIRInstr.SystemContractKind` is authoritative for migrated
families and `IntrinsicName` is a non-authoritative text projection. State that
unmigrated families remain explicit roadmap debt.

- [x] **Step 2: Replace stale M0 status with current evidence**

Update the M0 baseline and exit-gate text to reflect the current main history:
NPC V2 framing, fail-closed incremental gate, canonical System projection,
query option initialization, source-backed System binding, 53/53 fresh command
invocation plus 53/53 immediate repeat, 16/16 compiler-fail, and successful
compiler rebuild. Keep explicit cache-root isolation and a controlled cold/warm
full-suite pair open; do not relabel the repeat run as cache-warm evidence. Do
not use old lane commit IDs as current evidence.

Mark M1 typed migration as in progress and name object-free as the first
production family. Do not mark M1 complete.

- [x] **Step 3: Validate documentation and commit**

Run:

```bash
rg -n "51/53|framing is inconsistent|e670d082f|56a701add" \
  docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md
git diff --check
make test-tooling
make hygiene
```

The stale-pattern search must return no active status claims. Stage only the
three documentation files and commit:

```text
docs(compiler): reconcile M0 evidence and M1 progress
```

## Task 5: Verify the complete slice before landing

- [x] **Step 1: Run affected compiler and System gates**

Run:

```bash
make test-compiler-system-intrinsics
make focused FOCUS=core/tests/nextpas.core.system/test_system_source_contracts
make focused FOCUS=core/tests/nextpas.core.system/test_system_contracts
make -C core/tests/nextpas.core.system test-object-free-runtime-contract
make test-compiler-incremental-cache
make test-incremental-gate
# Fresh command invocation.
make test TEST_FILTER=compiler-pass
# Immediate repeat.
make test TEST_FILTER=compiler-pass
make test TEST_FILTER=compiler-fail
make rebuild-compiler
make test-tooling
git diff --check main...HEAD
make hygiene
```

Every command must exit zero on the final HEAD. Record exact pass counts and
the final branch status in `progress.md`, then remove all three temporary
planning files before preparing the landing candidate.

- [ ] **Step 2: Request independent reviews**

Run one spec-compliance review against the approved design and this plan, then
one code-quality review over `main...HEAD`. Resolve every critical or important
finding and re-run the affected gate.

- [ ] **Step 3: Prepare a latest-main landing candidate**

Create the candidate with the repository worktree helper, replay only the
reviewed commits, run `make landing-check` with the exact touched-path allowlist,
and fast-forward `main` only after the candidate is clean and all focused gates
pass.
