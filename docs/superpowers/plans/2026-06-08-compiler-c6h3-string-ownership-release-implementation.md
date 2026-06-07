# C6-H3 String Ownership Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the standalone string owned-sidecar release slice so compiler-owned local/top-level string slots release heap buffers produced by concat and `IntToStr`, while literals, aliases, params, fields, and return values remain no-release.

**Architecture:** Keep the visible string ABI as `{ptr,len}` and add compiler-private sidecars only for owned standalone slots: `$owner` and `$alloc_size`. RED contracts first freeze owned/borrowed string distinction, alias no-release paths, owned producer helpers, ordinary cleanup, field path preservation, return ownership deferral, and object-free field-agnostic behavior. The implementation then minimally threads sidecars through sema, HIR builder, LLVM emitter helpers, and focused verify hooks without changing string fields, string return ABI, refcounting, copy-on-write, deep copy, or unwind cleanup.

**Tech Stack:** Free Pascal, compiler sema/HIR builder/LLVM emitter, LLVM IR runtime helpers, `tests/hir`, `build/verify_local.sh`

---

## File Map

- `docs/superpowers/specs/2026-06-08-compiler-c6h3-string-ownership-release-design.md`
  - Design baseline. Do not edit unless implementation discovers a spec/live-truth conflict.
- `docs/superpowers/plans/2026-06-08-compiler-c6h3-string-ownership-release-implementation.md`
  - This plan.
- `compiler/sema/np_semantic_analyzer.pas`
  - Add explicit owned/borrowed standalone string HIR nodes and ordinary-exit cleanup nodes.
  - Keep string fields, return ownership, and call-result ownership deferred.
- `compiler/sema/np_semantic_model.pas`
  - Add node-kind parsing for new C6-H3 HIR node names.
- `compiler/ir/np_hir_builder.pas`
  - Allocate owned sidecars, lower ownership-aware assignments, and emit cleanup intrinsics.
- `compiler/ir/np_hir_model.pas`
  - Add any needed node-kind enum entries if parser/model requires explicit enum support.
- `compiler/ir/np_hir_llvm_emitter.pas`
  - Emit `@np_string_release`, `@np_string_fault`, owned concat, and owned `IntToStr` helper contracts.
- `tests/hir/test_hir_node_kind.pas`
  - Gate new node kinds.
- `tests/hir/test_hir_string_ownership_contract.pas`
  - RED source contracts for owned/borrowed string lifecycle.
- `tests/hir/test_hir_string_ownership_runtime_smoke.pas`
  - RED runtime smokes for concat, repeated assignment, `IntToStr`, alias no-release, borrowed params, and field path preservation.
- `build/verify_local.sh`
  - Minimal hook to run the two C6-H3 focused gates during full local verification.

## Task 1: Commit the implementation plan

**Files:**
- Create: `docs/superpowers/plans/2026-06-08-compiler-c6h3-string-ownership-release-implementation.md`

- [ ] **Step 1: Write this plan**

Create this file and verify that it covers:

- RED source contracts
- RED runtime smokes
- minimal sema/HIR/emitter implementation
- focused gates
- full local verification
- explicit deferred boundaries

- [ ] **Step 2: Run docs diff check**

Run:

```sh
git diff --check
```

Expected: no output and exit 0.

- [ ] **Step 3: Commit the plan**

Run:

```sh
git add docs/superpowers/plans/2026-06-08-compiler-c6h3-string-ownership-release-implementation.md
git commit -m "docs(compiler): plan C6-H3 string ownership release"
```

Expected: one docs-only commit.

## Task 2: Add RED source contracts

**Files:**
- Modify: `tests/hir/test_hir_node_kind.pas`
- Create: `tests/hir/test_hir_string_ownership_contract.pas`

- [ ] **Step 1: Gate new node kinds**

Add these assertions to `tests/hir/test_hir_node_kind.pas`:

```pascal
if ParseHirNodeKind('var-decl-str-owned-runtime') = hnkUnknown then
  Fail('var-decl-str-owned-runtime');
if ParseHirNodeKind('var-decl-str-borrowed-runtime') = hnkUnknown then
  Fail('var-decl-str-borrowed-runtime');
if ParseHirNodeKind('string-cleanup-runtime') = hnkUnknown then
  Fail('string-cleanup-runtime');
if ParseHirNodeKind('assign-str-owned-concat-runtime') = hnkUnknown then
  Fail('assign-str-owned-concat-runtime');
if ParseHirNodeKind('int-to-str-owned-runtime') = hnkUnknown then
  Fail('int-to-str-owned-runtime');
```

Expected RED: the node-kind test fails before implementation.

- [ ] **Step 2: Create a source-contract harness**

Create `tests/hir/test_hir_string_ownership_contract.pas` using the same local
compiler harness shape as existing HIR tests:

```pascal
function BuildModel(const ASource: string): TSemanticModel;
function EmitLlvm(const AModel: TSemanticModel): string;
function FindFirstNodeByKind(const AModel: TSemanticModel;
  const AKind: string; out ANode: TTypedHirNode): Boolean;
function FindFirstNodeByKindAndDisplayName(const AModel: TSemanticModel;
  const AKind, ADisplayName: string; out ANode: TTypedHirNode): Boolean;
function ExtractDefinitionSlice(const AText, AHeaderNeedle: string): string;
```

Use the imports from `test_hir_dynarray_release_contract.pas`.

- [ ] **Step 3: Freeze owned standalone and borrowed param distinction**

Use this fixture:

```pascal
const
  OwnedBorrowedSource =
    'program test;' + LineEnding +
    'procedure Touch(P: string);' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := ''left'' + P;' + LineEnding +
    '  if Length(P) = 0 then Exit;' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';
```

Assert:

```pascal
if not FindFirstNodeByKindAndDisplayName(Model,
  'var-decl-str-borrowed-runtime', 'P', Node) then
  Fail('missing-borrowed-param-node');
if not FindFirstNodeByKindAndDisplayName(Model,
  'var-decl-str-owned-runtime', 'S', Node) then
  Fail('missing-owned-local-node');
if FindFirstNodeByKindAndDisplayName(Model, 'string-cleanup-runtime', 'P',
  Node) then
  Fail('borrowed-param-must-not-cleanup');
if not FindFirstNodeByKindAndDisplayName(Model, 'string-cleanup-runtime', 'S',
  Node) then
  Fail('missing-owned-string-cleanup');
```

- [ ] **Step 4: Freeze owned sidecars and owned helper calls in LLVM**

From the same fixture, assert:

```pascal
LlvmText := EmitLlvm(Model);
if Pos('S$owner', LlvmText) = 0 then
  Fail('missing-owned-sidecar-owner');
if Pos('S$alloc_size', LlvmText) = 0 then
  Fail('missing-owned-sidecar-alloc-size');
if Pos('call void @np_string_release(', LlvmText) = 0 then
  Fail('missing-string-release-call');
if Pos('call {ptr, i64, ptr, i64} @np_str_concat_owned(', LlvmText) = 0 then
  Fail('missing-owned-concat-helper-call');
if Pos('define internal void @np_string_release(', LlvmText) = 0 then
  Fail('missing-string-release-helper');
if Pos('define internal void @np_string_fault(', LlvmText) = 0 then
  Fail('missing-string-fault-helper');
```

- [ ] **Step 5: Freeze alias/no-owner paths**

Use this fixture:

```pascal
const
  AliasSource =
    'program test;' + LineEnding +
    'var A, B, C: string;' + LineEnding +
    'begin' + LineEnding +
    '  A := ''abcdef'';' + LineEnding +
    '  B := A;' + LineEnding +
    '  C := Copy(A, 2, 3);' + LineEnding +
    'end.';
```

Assert the source nodes remain alias-shaped:

```pascal
if not FindFirstNodeByKind(Model, 'assign-str-copy-runtime', Node) then
  Fail('missing-shallow-copy-node');
if not FindFirstNodeByKind(Model, 'copy-str-runtime', Node) then
  Fail('missing-copy-alias-node');
```

Assert the emitted LLVM clears ownership sidecars and never calls
`@np_free(ptr, len)`:

```pascal
if Pos('store ptr null, ptr ', LlvmText) = 0 then
  Fail('missing-alias-owner-clear');
if Pos('call void @np_free(ptr %', LlvmText) <> 0 then
  Fail('string-path-must-not-free-visible-ptr');
```

- [ ] **Step 6: Freeze `IntToStr` ownership sidecar behavior**

Use this fixture:

```pascal
const
  IntToStrSource =
    'program test;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := IntToStr(42);' + LineEnding +
    'end.';
```

Assert:

```pascal
if not FindFirstNodeByKindAndDisplayName(Model,
  'int-to-str-owned-runtime', 'S', Node) then
  Fail('missing-owned-int-to-str-node');
if Pos('call {ptr, i64, ptr, i64} @np_int_to_str_owned(', LlvmText) = 0 then
  Fail('missing-owned-int-to-str-helper-call');
```

- [ ] **Step 7: Freeze return/field/object-free boundaries**

Use fixtures that prove:

- a string-return function still emits `ret-str-runtime`
- assigning a call result into a local remains borrowed/unknown, with no owned
  return transfer
- string field load/store still use `assign-str-field-load-runtime` and
  `field-store-str-runtime`
- emitted object free helper slice does not contain `np_object_string_cleanup`

Assert:

```pascal
if Pos('@np_object_string_cleanup_', LlvmText) <> 0 then
  Fail('string-field-cleanup-must-remain-deferred');
if Pos('define internal void @np_object_free_release(ptr %obj)', LlvmText) = 0 then
  Fail('missing-object-free-release-helper');
```

- [ ] **Step 8: Run RED source contracts**

Run:

```sh
fpc -Fucompiler/ir -FEbuild/.tmp/c6h3-red-node -FUbuild/.tmp/c6h3-red-node tests/hir/test_hir_node_kind.pas
build/.tmp/c6h3-red-node/test_hir_node_kind
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h3-red-src -FUbuild/.tmp/c6h3-red-src tests/hir/test_hir_string_ownership_contract.pas
build/.tmp/c6h3-red-src/test_hir_string_ownership_contract
```

Expected RED before implementation:

- node-kind test fails on the first new node kind, or
- string ownership contract fails on missing owned/borrowed distinction,
  sidecars, helper, or cleanup.

- [ ] **Step 9: Commit RED source contracts**

Run:

```sh
git add tests/hir/test_hir_node_kind.pas tests/hir/test_hir_string_ownership_contract.pas
git commit -m "test(compiler): add C6-H3 string ownership RED contracts"
```

Expected: one test-only commit.

## Task 3: Add RED runtime smokes and verify hook

**Files:**
- Create: `tests/hir/test_hir_string_ownership_runtime_smoke.pas`
- Modify: `build/verify_local.sh`

- [ ] **Step 1: Create the runtime smoke test**

Use the helper-extraction and `opt -> llc -> clang -> run` shape from:

- `tests/hir/test_hir_dynarray_release_runtime_smoke.pas`
- `tests/hir/test_hir_field_dynarray_release_runtime_smoke.pas`
- `tests/hir/test_hir_large_alloc_runtime_smoke.pas`

The new program must print:

```text
hir-string-ownership-runtime-smoke-concat-exit=42
hir-string-ownership-runtime-smoke-repeat-exit=42
hir-string-ownership-runtime-smoke-inttostr-exit=42
hir-string-ownership-runtime-smoke-alias-exit=42
hir-string-ownership-runtime-smoke-borrowed-param-exit=42
hir-string-ownership-runtime-smoke-field-preserved-exit=42
hir-string-ownership-runtime-smoke-status=pass
```

- [ ] **Step 2: Freeze generated runtime contract assertions**

Before running LLVM, assert the generated IR contains:

```pascal
if Pos('define internal void @np_string_release(', SourceLlvm) = 0 then
  Fail('missing-string-release-helper');
if Pos('define internal void @np_string_fault(', SourceLlvm) = 0 then
  Fail('missing-string-fault-helper');
if Pos('call {ptr, i64, ptr, i64} @np_str_concat_owned(', SourceLlvm) = 0 then
  Fail('missing-owned-concat-call');
if Pos('call {ptr, i64, ptr, i64} @np_int_to_str_owned(', SourceLlvm) = 0 then
  Fail('missing-owned-inttostr-call');
if Pos('@np_object_string_cleanup_', SourceLlvm) <> 0 then
  Fail('unexpected-string-field-cleanup');
```

- [ ] **Step 3: Add direct helper smokes**

Build direct LLVM snippets that call owned helpers without relying only on
Pascal lowering:

- concat writes first and last byte, releases owner, exits 42
- repeated concat releases old owner then new owner, exits 42
- `IntToStr` checks visible digit bytes and releases owner base with
  `alloc_size = 21`, exits 42
- alias/literal `{null,0}` release is no-op and exits 42

- [ ] **Step 4: Add Pascal end-to-end smokes**

Build Pascal-generated snippets for:

```pascal
S := 'ab' + 'cd';
S := S + 'ef';
S := IntToStr(42);
```

Also include:

```pascal
procedure Touch(P: string);
begin
  if Length(P) = 0 then Halt(1);
end;
```

to prove borrowed string params are not released by the callee.

- [ ] **Step 5: Add field preservation smoke**

Use a class with string fields and `Obj.Free`:

```pascal
type TStringBox = class
  Text: string;
  Other: string;
  procedure Touch;
end;
```

Assert generated IR still contains field string load/store and no
`@np_object_string_cleanup_`.

- [ ] **Step 6: Wire full local verify**

In `build/verify_local.sh`, add:

- build dir variable
- binary variable
- `require_path tests/hir/test_hir_string_ownership_contract.pas`
- `require_path tests/hir/test_hir_string_ownership_runtime_smoke.pas`
- source-contract build/run block
- runtime-smoke build/run block
- required output patterns listed in Step 1

Keep this hook minimal and do not alter unrelated truth.

- [ ] **Step 7: Run RED runtime smoke**

Run:

```sh
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h3-red-runtime -FUbuild/.tmp/c6h3-red-runtime tests/hir/test_hir_string_ownership_runtime_smoke.pas
build/.tmp/c6h3-red-runtime/test_hir_string_ownership_runtime_smoke
```

Expected RED before implementation: fail on missing helpers or missing owned
producer calls.

- [ ] **Step 8: Commit RED runtime smoke**

Run:

```sh
git add tests/hir/test_hir_string_ownership_runtime_smoke.pas build/verify_local.sh
git commit -m "test(compiler): add C6-H3 string ownership runtime smoke"
```

Expected: one test/verify-hook commit.

## Task 4: Implement sema owned/borrowed string contracts

**Files:**
- Modify: `compiler/sema/np_semantic_analyzer.pas`
- Modify: `compiler/sema/np_semantic_model.pas`
- Modify: `compiler/ir/np_hir_model.pas` if enum support requires it

- [ ] **Step 1: Add runtime string ownership registries**

Add arrays and helpers mirroring dynarray borrowed tracking:

```pascal
FOwnedRuntimeStrVarNames: array of string;
FBorrowedRuntimeStrVarNames: array of string;

procedure RegisterOwnedRuntimeStrVar(const AName: string);
procedure RegisterBorrowedRuntimeStrVar(const AName: string);
function IsOwnedRuntimeStrVar(const AName: string): Boolean;
function IsBorrowedRuntimeStrVar(const AName: string): Boolean;
```

Owned slots:

- local string vars
- top-level string vars

Borrowed slots:

- string parameters

Do not mark string return slots as ordinary cleanup-owned.

- [ ] **Step 2: Emit explicit declaration nodes**

Replace standalone local/top-level string declaration emission with:

```pascal
FModel.AddTypedHirNode('var-decl-str-owned-runtime', Name, 0, 0, Name);
```

Replace string parameter emission with:

```pascal
FModel.AddTypedHirNode('var-decl-str-borrowed-runtime', Name, 0, 0, Name);
```

Keep legacy `var-decl-str-runtime` valid for generated temps and deferred
return/field/call paths during transition.

- [ ] **Step 3: Emit cleanup nodes only for owned standalone slots**

Add `EmitOwnedStringCleanupNodes`:

```pascal
for each FOwnedRuntimeStrVarNames:
  add 'string-cleanup-runtime' with display/operand = var name
```

Call it at the same ordinary cleanup points where dynarray cleanup already
runs:

- explicit `Exit`
- implicit function/procedure end
- root program ordinary halt

Do not emit cleanup for:

- borrowed params
- return vars
- generated field-store temps
- string fields

- [ ] **Step 4: Emit owned producer nodes**

When an owned standalone string slot receives:

- concat expression: emit `assign-str-owned-concat-runtime`
- `IntToStr(...)`: emit `int-to-str-owned-runtime`

Keep existing nodes for:

- field strings
- return/call results
- generated temps not tracked as owned standalone slots

- [ ] **Step 5: Keep alias/literal/copy nodes but let builder clear ownership**

Do not turn shallow assignment or `Copy` into deep copies. They remain:

- `assign-str-runtime`
- `assign-str-copy-runtime`
- `copy-str-runtime`
- `assign-str-field-load-runtime`
- `assign-str-call-runtime`

The builder will release old owner and clear sidecars when the destination is
an owned standalone slot with sidecars.

- [ ] **Step 6: Run RED source contracts**

Run the two focused source commands from Task 2. Expected after sema-only work:
some node-kind/source assertions may pass, but LLVM sidecar/helper assertions
still fail until builder/emitter implementation.

## Task 5: Implement HIR builder sidecars and ownership-aware lowering

**Files:**
- Modify: `compiler/ir/np_hir_builder.pas`

- [ ] **Step 1: Allocate owned sidecars**

For `var-decl-str-owned-runtime`, allocate:

- `name$ptr`
- `name$len`
- `name$owner`
- `name$alloc_size`

Initialize sidecars to:

```text
owner = null
alloc_size = 0
```

For `var-decl-str-borrowed-runtime`, allocate/store only visible
`name$ptr/name$len` from incoming params.

Top-level owned string globals must also create `$owner` and `$alloc_size`
globals.

- [ ] **Step 2: Add ownership helpers inside the builder**

Add focused helper methods:

```pascal
function HasStringOwnerSidecars(const AName: string): Boolean;
procedure EmitStringReleaseIfOwned(const AName: string);
procedure EmitStringClearOwner(const AName: string);
procedure EmitStringStoreOwnedResult(const AName: string;
  APtr, ALen, AOwner, AAllocSize: THIRValueId);
```

These helpers must no-op for borrowed/deferred slots without sidecars.

- [ ] **Step 3: Lower cleanup**

`string-cleanup-runtime` lowers to:

```text
load name$owner
load name$alloc_size
call @np_string_release(owner, alloc_size)
store null into name$owner
store 0 into name$alloc_size
```

- [ ] **Step 4: Lower literal/alias overwrite**

Before overwriting a destination with sidecars:

1. release old owner
2. write visible `{ptr,len}`
3. clear sidecars

Apply this to:

- `assign-str-runtime`
- `assign-str-copy-runtime`
- `copy-str-runtime`
- `assign-str-field-load-runtime`
- `assign-str-call-runtime`
- `assign-str-vcall-runtime`
- `assign-str-ivcall-runtime`

Do not change field-store string behavior.

- [ ] **Step 5: Lower owned concat**

For `assign-str-owned-concat-runtime`:

1. load operand visible `{ptr,len}` values
2. call `str_concat_owned`
3. extract `{ptr,len,owner,alloc_size}`
4. release old destination owner
5. store new visible and sidecar values

This order preserves `S := S + X`.

- [ ] **Step 6: Lower owned `IntToStr`**

For `int-to-str-owned-runtime`:

1. call `int_to_str_owned`
2. extract `{ptr,len,owner,alloc_size}`
3. release old destination owner
4. store new visible and sidecar values

- [ ] **Step 7: Run focused source contracts**

Run:

```sh
fpc -Fucompiler/ir -FEbuild/.tmp/c6h3-node -FUbuild/.tmp/c6h3-node tests/hir/test_hir_node_kind.pas
build/.tmp/c6h3-node/test_hir_node_kind
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h3-src -FUbuild/.tmp/c6h3-src tests/hir/test_hir_string_ownership_contract.pas
build/.tmp/c6h3-src/test_hir_string_ownership_contract
```

Expected: source contracts pass only after emitter helpers are complete.

## Task 6: Implement LLVM string helpers

**Files:**
- Modify: `compiler/ir/np_hir_llvm_emitter.pas`

- [ ] **Step 1: Add helper flags and emit order**

Add flags:

```pascal
FNeedsStringRuntime: Boolean;
FNeedsStrConcatOwned: Boolean;
FNeedsIntToStrOwned: Boolean;
```

Owned string helpers depend on:

- allocator helpers
- memcpy for concat

Do not route helper dependencies through unrelated string concat flags.

- [ ] **Step 2: Emit `@np_string_fault`**

Emit:

```llvm
define internal void @np_string_fault(i64 %code, i64 %arg0, i64 %arg1) {
entry:
  call void @llvm.trap()
  unreachable
}
```

- [ ] **Step 3: Emit `@np_string_release`**

Emit release state validation:

```llvm
%owner.null = icmp eq ptr %owner, null
%size.zero = icmp eq i64 %alloc_size, 0
```

Rules:

- both null/zero -> return
- null/nonzero -> fault code 1
- nonnull/zero -> fault code 1
- nonnull/nonzero -> `call void @np_free(ptr %owner, i64 %alloc_size)`

- [ ] **Step 4: Emit `@np_str_concat_owned`**

Emit:

- overflow-safe `total = a_len + b_len`
- zero-length result returns `{null,0,null,0}`
- allocate exact `total`
- copy lhs then rhs with `@np_memcpy`
- return `{buf,total,buf,total}`

- [ ] **Step 5: Emit `@np_int_to_str_owned`**

Keep the current 21-byte allocation model, but return owner metadata:

- owner = base `%buf`
- alloc_size = `21`
- visible ptr = current interior `%result_ptr`
- visible len = `%result_len`

- [ ] **Step 6: Keep legacy helper behavior for deferred paths**

Do not remove:

- `@np_str_concat`
- `@np_int_to_str`
- string field store/load lowering
- string return `{ptr,i64}` lowering

- [ ] **Step 7: Run source and runtime smoke**

Run the C6-H3 source and runtime gates. Expected: C6-H3 tests pass after this
task unless sema/builder gaps remain.

- [ ] **Step 8: Commit implementation**

Run:

```sh
git add compiler/sema/np_semantic_analyzer.pas compiler/sema/np_semantic_model.pas compiler/ir/np_hir_model.pas compiler/ir/np_hir_builder.pas compiler/ir/np_hir_llvm_emitter.pas
git commit -m "feat(compiler): implement C6-H3 string ownership release"
```

Expected: one production implementation commit.

## Task 7: Focused GREEN and regression gates

**Files:**
- No new files unless a focused gate needs a minimal test hook fix.

- [ ] **Step 1: Run C6-H3 source contract**

Run:

```sh
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h3-src -FUbuild/.tmp/c6h3-src tests/hir/test_hir_string_ownership_contract.pas
build/.tmp/c6h3-src/test_hir_string_ownership_contract
```

Expected:

```text
hir-string-ownership-contract-status=pass
```

- [ ] **Step 2: Run C6-H3 runtime smoke**

Run:

```sh
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h3-runtime -FUbuild/.tmp/c6h3-runtime tests/hir/test_hir_string_ownership_runtime_smoke.pas
build/.tmp/c6h3-runtime/test_hir_string_ownership_runtime_smoke
```

Expected: all six `...exit=42` lines and `hir-string-ownership-runtime-smoke-status=pass`.

- [ ] **Step 3: Run existing C6-G/H1/H2 gates**

Run:

```sh
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6g-large -FUbuild/.tmp/c6g-large tests/hir/test_hir_large_alloc_runtime_smoke.pas
build/.tmp/c6g-large/test_hir_large_alloc_runtime_smoke
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h1-src -FUbuild/.tmp/c6h1-src tests/hir/test_hir_dynarray_release_contract.pas
build/.tmp/c6h1-src/test_hir_dynarray_release_contract
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h1-runtime -FUbuild/.tmp/c6h1-runtime tests/hir/test_hir_dynarray_release_runtime_smoke.pas
build/.tmp/c6h1-runtime/test_hir_dynarray_release_runtime_smoke
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h2-src -FUbuild/.tmp/c6h2-src tests/hir/test_hir_field_dynarray_contract.pas
build/.tmp/c6h2-src/test_hir_field_dynarray_contract
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h2-runtime -FUbuild/.tmp/c6h2-runtime tests/hir/test_hir_field_dynarray_release_runtime_smoke.pas
build/.tmp/c6h2-runtime/test_hir_field_dynarray_release_runtime_smoke
```

Expected: all pass markers from C6-G/H1/H2 remain present.

- [ ] **Step 4: Run HIR node kind gate**

Run:

```sh
fpc -Fucompiler/ir -FEbuild/.tmp/hir-node-kind -FUbuild/.tmp/hir-node-kind tests/hir/test_hir_node_kind.pas
build/.tmp/hir-node-kind/test_hir_node_kind
```

Expected:

```text
hir-node-kind-status=pass
```

## Task 8: Full closeout and package review

**Files:**
- Review only unless a gate exposes a C6-H3-scoped fix.

- [ ] **Step 1: Run diff check**

Run:

```sh
git diff --check
```

Expected: no output and exit 0.

- [ ] **Step 2: Run hygiene**

Run:

```sh
make hygiene
```

Expected:

```text
build-hygiene=pass
```

- [ ] **Step 3: Run full local verify**

Run:

```sh
./build/verify_local.sh
```

Expected:

```text
verify-local=pass
```

- [ ] **Step 4: Package audit**

Run:

```sh
git status --short --branch
git diff --name-status origin/main...HEAD
git cherry -v origin/main HEAD
```

Expected retained paths are limited to C6-H3:

- `docs/superpowers/specs/2026-06-08-compiler-c6h3-string-ownership-release-design.md`
- `docs/superpowers/plans/2026-06-08-compiler-c6h3-string-ownership-release-implementation.md`
- `compiler/sema/np_semantic_analyzer.pas`
- `compiler/sema/np_semantic_model.pas`
- `compiler/ir/np_hir_model.pas` only if needed for node-kind enum support
- `compiler/ir/np_hir_builder.pas`
- `compiler/ir/np_hir_llvm_emitter.pas`
- `tests/hir/test_hir_node_kind.pas`
- `tests/hir/test_hir_string_ownership_contract.pas`
- `tests/hir/test_hir_string_ownership_runtime_smoke.pas`
- `build/verify_local.sh`

Excluded paths:

- `build/.tmp/**`
- `.nextpas/**`
- `.sisyphus/**`
- old `codex/compiler` branch-only docs/history
- C6-H2 landing-candidate history
- string field release implementation
- return ownership implementation
- refcount/COW/deep-copy/unwind changes

- [ ] **Step 5: Report Ready landing candidate**

Report only after all gates above pass. Include:

- branch/worktree/HEAD
- retained files
- excluded files
- focused verification
- `git diff --check`
- `make hygiene`
- `./build/verify_local.sh`
- landing recommendation: clean landing worktree replay/cherry-pick of C6-H3 commits only, no raw merge of long-running lanes

