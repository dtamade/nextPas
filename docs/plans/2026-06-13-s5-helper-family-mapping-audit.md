# S5.2 Helper-Family Mapping Audit Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Audit and lock HIR intrinsic name → LLVM helper name mappings for interface, halt, and heap contracts, adding source-contract checks and focused tests.

**Architecture:** S5.2 focuses on 4 identified gaps where HIR uses implementation names (`intf_addref`, `intf_release`, `halt`, `arr_alloc`, `class_alloc`) instead of documented `np.system.*` contract names. Strategy: (1) document the current mapping state, (2) add source-contract checks, (3) add focused tests, (4) decide whether to rename intrinsics or accept implementation-name pattern.

**Tech Stack:** Pascal, FPC, shell source-contract script, Makefile-based test harness

---

## Context

From `contract-coverage-table.md`, 4 gaps identified:

| Gap | Current HIR intrinsic | Should map to | LLVM helper |
|-----|----------------------|---------------|-------------|
| interface addref | `intf_addref` | `np.system.interface_addref` | `@np_intf_addref` |
| interface release | `intf_release` | `np.system.interface_release` | `@np_intf_release` |
| halt | `halt` | `np.system.halt` | inline syscall |
| heap alloc | `arr_alloc`, `class_alloc` | `np.system.heap_alloc` | `@np_alloc`, `@np_object_alloc` |

**Decision principle:** HIR intrinsic names are compiler-internal vocabulary. The `np.system.*` contract names are documentation vocabulary. They don't need to match 1:1. What matters is:
1. The mapping is documented
2. Source-contract checks verify the mapping
3. Focused tests exist for each contract family

**Decision:** Keep current HIR intrinsic names (`intf_addref`, `intf_release`, `halt`, `arr_alloc`, `class_alloc`) as implementation names. Add documentation and checks instead of renaming. This is consistent with how `np.system.object_free.destroy/cleanup/release` already use semantic names while other helpers use implementation names.

---

### Task 1: Document Interface Helper Mapping in runtime-contracts.md

**Files:**
- Modify: `core/docs/system/runtime-contracts.md:100-120` (Interface Reference section)

**Step 1: Read current Interface Reference section**

Current state (lines 100-120) already documents:
- Contract names `np.system.interface_addref` / `np.system.interface_release`
- HIR uses `intf_addref` / `intf_release` as internal intrinsic names
- LLVM emitter translates to `@np_intf_addref` / `@np_intf_release`
- Source-contract check `check_system_source_contracts.sh:675-680`

**No change needed** - this was already added in the previous commit. Verify the content is correct.

**Step 2: Verify source-contract check coverage**

Run: `grep -n "intf_addref\|intf_release" core/tests/nextpas.core.system/test_system_source_contracts/check_system_source_contracts.sh | head -10`

Expected: Lines 667-668 list LLVM helpers, lines 671-680 verify HIR builder and emitter.

**Step 3: Commit verification (no code change needed)**

Skip commit - documentation already complete.

---

### Task 2: Document Halt Helper Mapping in lifecycle-contracts.md

**Files:**
- Modify: `core/docs/system/lifecycle-contracts.md:23-44` (Program Termination section)

**Step 1: Read current Program Termination section in runtime-contracts.md**

The `np.system.halt` contract is documented in `runtime-contracts.md:23-44`. Check if HIR intrinsic name `halt` is documented.

**Step 2: Add HIR intrinsic mapping documentation**

If missing, add to `runtime-contracts.md` Program Termination section:

```markdown
- HIR uses `halt` as the internal intrinsic name for program termination.
- LLVM emitter translates `halt` intrinsic to inline syscall (`movq $60, %rax; syscall`).
- No named LLVM helper for halt; backend uses inline assembly.
- Source-contract check verifies HIR builder uses `halt` intrinsic (not `np.system.halt`).
```

**Step 3: Add source-contract check for halt**

File: `core/tests/nextpas.core.system/test_system_source_contracts/check_system_source_contracts.sh`

Add after the interface helper checks (around line 680):

```bash
# Halt intrinsic uses implementation name 'halt', not 'np.system.halt'
require_repo_token "compiler/ir/np_hir_builder.pas" "Instr.IntrinsicName := 'halt';"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "if AInstr.IntrinsicName = 'halt' then"
```

**Step 4: Run source-contract test**

Run: `make -C core/tests/nextpas.core.system/test_system_source_contracts test`

Expected: PASS with halt assertion added.

**Step 5: Commit**

```bash
git add core/docs/system/runtime-contracts.md core/tests/nextpas.core.system/test_system_source_contracts/check_system_source_contracts.sh
git commit -m "docs(core-system): document halt intrinsic mapping, add source-contract halt checks"
```

---

### Task 3: Document Heap Alloc Helper Mapping in runtime-contracts.md

**Files:**
- Modify: `core/docs/system/runtime-contracts.md:180-210` (Heap Manager section)

**Step 1: Read current Heap Manager section**

Current state (from previous commit) documents:
- HIR does not use `np.system.heap_alloc` or `np.system.heap_free` intrinsic names
- LLVM emitter uses `@np_alloc` and `@np_free` directly

**Step 2: Add allocation intrinsic documentation**

The heap section needs to document the allocation intrinsics used by HIR:

```markdown
- HIR uses `arr_alloc` and `arr_alloc_sized` for dynamic array allocation intrinsics.
- HIR uses `class_alloc` for object instance allocation intrinsic.
- These allocation intrinsics are internal compiler vocabulary, not `np.system.*` contract names.
- LLVM emitter translates allocation intrinsics to `@np_alloc` and `@np_object_alloc`.
```

Find exact lines in `np_hir_builder.pas`:
- Line 5032: `Instr.IntrinsicName := 'arr_alloc'`
- Line 5261: `Instr.IntrinsicName := 'class_alloc'`

**Step 3: Add source-contract check for allocation intrinsics**

File: `core/tests/nextpas.core.system/test_system_source_contracts/check_system_source_contracts.sh`

Add after halt checks:

```bash
# Heap allocation intrinsics use implementation names
require_repo_token "compiler/ir/np_hir_builder.pas" "Instr.IntrinsicName := 'arr_alloc';"
require_repo_token "compiler/ir/np_hir_builder.pas" "Instr.IntrinsicName := 'class_alloc';"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "@np_alloc"
require_repo_token "compiler/ir/np_hir_llvm_emitter.pas" "@np_object_alloc"
```

**Step 4: Run source-contract test**

Run: `make -C core/tests/nextpas.core.system/test_system_source_contracts test`

Expected: PASS with allocation assertion added.

**Step 5: Commit**

```bash
git add core/docs/system/runtime-contracts.md core/tests/nextpas.core.system/test_system_source_contracts/check_system_source_contracts.sh
git commit -m "docs(core-system): document arr_alloc/class_alloc intrinsic mapping, add source-contract allocation checks"
```

---

### Task 4: Add Interface Contract Focused Test

**Files:**
- Create: `tests/hir/test_hir_interface_contract.pas`
- Modify: `core/tests/nextpas.core.system/Makefile`

**Step 1: Study existing HIR contract test pattern**

Read: `tests/hir/test_hir_object_free_contract.pas` for test structure pattern.

Pattern:
1. Create semantic model from minimal Pascal source
2. Query HIR for intrinsic nodes matching contract
3. Verify intrinsic name and operands

**Step 2: Write test for interface addref/release**

Create `tests/hir/test_hir_interface_contract.pas`:

```pascal
program test_hir_interface_contract;

{$mode objfpc}{$H+}

uses
  SysUtils,
  np_ast_facade,
  np_diagnostics_sink,
  np_green_tree,
  np_hir_model,
  np_hir_builder,
  np_lexer,
  np_semantic_analyzer,
  np_semantic_model,
  np_unit_graph;

procedure Fail(const AMessage: string);
begin
  WriteLn(StdErr, 'hir-interface-contract-failure=', AMessage);
  Halt(1);
end;

function BuildModelWithInterface(const ASource: string): TSemanticModel;
// ... similar to test_hir_object_free_contract.pas
var
  Analyzer: TSemanticAnalyzer;
  // ...
begin
  // Build semantic model with interface assignment
end;

function CountIntrinsicNodes(const AModel: THIRModule; const AIntrinsicName: string): LongInt;
var
  Index: LongInt;
  Instr: THIRInstr;
begin
  Result := 0;
  for Index := 0 to AModel.InstrCount - 1 do
  begin
    Instr := AModel.InstrAt(Index);
    if (Instr.Kind = hikIntrinsic) and (Instr.IntrinsicName = AIntrinsicName) then
      Inc(Result);
  end;
end;

var
  Model: TSemanticModel;
  HirModule: THIRModule;
  AddrefCount, ReleaseCount: LongInt;
begin
  // Test source with interface assignment
  Model := BuildModelWithInterface(
    'program test;' +
    'type ITest = interface end;' +
    'var A, B: ITest;' +
    'begin' +
    '  B := A;' +  // Should emit intf_addref for B, intf_release for old B
    'end.'
  );
  
  HirModule := Model.HirModule;
  
  AddrefCount := CountIntrinsicNodes(HirModule, 'intf_addref');
  ReleaseCount := CountIntrinsicNodes(HirModule, 'intf_release');
  
  // Interface assignment should emit addref for new value
  if AddrefCount < 1 then
    Fail('missing-intf-addref');
  
  // Interface assignment should emit release for old value (if B was not nil)
  // Note: initial assignment from nil may not emit release
  WriteLn('hir-interface-contract-addref-count=', AddrefCount);
  WriteLn('hir-interface-contract-release-count=', ReleaseCount);
  WriteLn('hir-interface-contract=pass');
end.
```

**Step 3: Add Makefile target**

Modify `core/tests/nextpas.core.system/Makefile`:

Add variables:
```makefile
INTERFACE_CONTRACT_BUILD_DIR := $(ROOT_DIR)/build/.tmp/core-system-interface-contract
INTERFACE_CONTRACT_BINARY := $(INTERFACE_CONTRACT_BUILD_DIR)/test_hir_interface_contract
INTERFACE_CONTRACT_SOURCE := $(ROOT_DIR)/tests/hir/test_hir_interface_contract.pas
INTERFACE_CONTRACT_FPC_FLAGS := -Fu$(ROOT_DIR)/compiler/frontend -Fu$(ROOT_DIR)/compiler/diagnostics -Fu$(ROOT_DIR)/compiler/syntax -Fu$(ROOT_DIR)/compiler/sema -Fu$(ROOT_DIR)/compiler/ir -Fu$(ROOT_DIR)/rtl/core/base -Fu$(ROOT_DIR)/rtl/core/text
```

Add test target:
```makefile
test-interface-contract:
	rm -rf "$(INTERFACE_CONTRACT_BUILD_DIR)"
	mkdir -p "$(INTERFACE_CONTRACT_BUILD_DIR)"
	fpc $(INTERFACE_CONTRACT_FPC_FLAGS) -FE"$(INTERFACE_CONTRACT_BUILD_DIR)" -FU"$(INTERFACE_CONTRACT_BUILD_DIR)" "$(INTERFACE_CONTRACT_SOURCE)"
	"$(INTERFACE_CONTRACT_BINARY)"
```

Add to `test:` target:
```makefile
test: test-source-contracts test-facade test-typinfo-minimal test-sysutils-minimal test-process-runtime-contract-seed test-object-free-runtime-contract test-interface-contract test-field-dynarray-contract ...
```

Add to `clean:` target:
```makefile
clean:
	...
	rm -rf "$(INTERFACE_CONTRACT_BUILD_DIR)"
```

**Step 4: Run test**

Run: `make -C core/tests/nextpas.core.system clean test-interface-contract`

Expected: PASS with `hir-interface-contract=pass`.

**Step 5: Commit**

```bash
git add tests/hir/test_hir_interface_contract.pas core/tests/nextpas.core.system/Makefile
git commit -m "test(core-system): add interface contract HIR intrinsic focused test"
```

---

### Task 5: Update Contract Coverage Table with Mapping Evidence

**Files:**
- Modify: `core/docs/system/contract-coverage-table.md`

**Step 1: Update interface rows**

Update rows 18-19 to reflect the decision that HIR uses implementation names intentionally:

```markdown
| `np.system.interface_addref` | HIR uses `intf_addref` as implementation intrinsic (intentional) | `@np_intf_addref` (line 750) | `test_hir_interface_contract` | **Contract name in docs, impl name in HIR** |
| `np.system.interface_release` | HIR uses `intf_release` as implementation intrinsic (intentional) | `@np_intf_release` (line 756) | `test_hir_interface_contract` | **Contract name in docs, impl name in HIR** |
```

**Step 2: Update halt row**

Update row 20:

```markdown
| `np.system.halt` | HIR uses `halt` as implementation intrinsic (intentional) | inline syscall (`movq $60, %rax; syscall`) | No focused test | **Contract name in docs, impl name in HIR** |
```

**Step 3: Add allocation intrinsic rows**

After heap_alloc/heap_free rows, add:

```markdown
| `np.system.heap_alloc` (internal) | HIR uses `arr_alloc`, `class_alloc` as implementation intrinsics | `@np_alloc` (line 686, 698, 1153, 1275), `@np_object_alloc` (line 734) | emitter integration tests | **Contract name in docs, impl names in HIR** |
```

**Step 4: Commit**

```bash
git add core/docs/system/contract-coverage-table.md
git commit -m "docs(core-system): update contract coverage table with HIR impl name decision evidence"
```

---

### Task 6: Update Goal-Tree S5.2 Status

**Files:**
- Modify: `core/docs/system/goal-tree.md`

**Step 1: Mark S5.2 items complete**

Update S5.2 section:

```markdown
### S5.2 Helper-Family Mapping Audit

- [x] Audit and document all HIR intrinsic name → LLVM helper name mappings.
- [x] Document `intf_addref` / `intf_release` as implementation names mapping to `np.system.interface_addref` / `np.system.interface_release` contracts.
- [x] Document `halt` as implementation name mapping to `np.system.halt` contract.
- [x] Document `arr_alloc` / `class_alloc` as implementation names mapping to `np.system.heap_alloc` contract.
- [x] Add source-contract check: HIR intrinsic name existence and LLVM helper mapping.
- [x] Add focused test for interface contract (`test_hir_interface_contract`).

Decision: Keep implementation names in HIR, document mapping in contract-coverage-table. This is consistent with existing pattern where `np.system.object_free.destroy/cleanup/release` use semantic names but other helpers use implementation names.
```

**Step 2: Commit**

```bash
git add core/docs/system/goal-tree.md
git commit -m "docs(core-system): mark S5.2 helper-family mapping audit complete"
```

---

## Verification Summary

After all tasks, run:

```bash
make -C core/tests/nextpas.core.system clean test
make hygiene
git diff --check
```

Expected: All tests PASS, hygiene PASS.

---

## Total Commits

1. `docs(core-system): document halt intrinsic mapping, add source-contract halt checks`
2. `docs(core-system): document arr_alloc/class_alloc intrinsic mapping, add source-contract allocation checks`
3. `test(core-system): add interface contract HIR intrinsic focused test`
4. `docs(core-system): update contract coverage table with HIR impl name decision evidence`
5. `docs(core-system): mark S5.2 helper-family mapping audit complete`