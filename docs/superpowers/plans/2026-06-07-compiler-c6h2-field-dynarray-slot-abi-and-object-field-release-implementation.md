# C6-H2 Field Dynarray Slot ABI And Object-Field Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the next dynarray-only compiler slice so object-owned dynarray fields use an explicit `{ptr,len}` slot ABI, owner-field `SetLength` becomes size-correct, and object `Free` releases dynarray fields between destroy and heap release, while string ownership and `@np_object_free_release` stay untouched.

**Architecture:** Freeze semantic metadata, HIR producer contracts, builder lowering, and runtime smokes in RED before touching implementation. Represent owner-field resize with a dedicated field-resize HIR node, widen dynarray field layout from one slot to two slots, and synthesize compile-time-class-specific dynarray cleanup helpers in the HIR builder so `BaseRef.Free` remains explicitly compile-time-class-only. Keep standalone C6-H1 dynarray behavior intact, keep field-array element access rooted at the ptr slot, keep string field lowering byte-for-byte compatible, and leave `@np_object_free_release` as an allocator/header-only helper.

**Tech Stack:** Free Pascal, compiler sema/HIR builder/LLVM emitter, `tests/hir`, `build/verify_local.sh`

---

### Task 1: Freeze C6-H2 RED source contracts

**Files:**
- Modify: `tests/hir/test_hir_node_kind.pas`
- Modify: `tests/hir/test_hir_dynarray_release_contract.pas`
- Modify: `tests/hir/test_hir_object_free_contract.pas`
- Create: `tests/hir/test_hir_field_dynarray_contract.pas`

- [ ] **Step 1: Extend the node-kind contract for the dedicated field-resize node**

Add the new mapping first so field resize cannot silently reuse the old `assign-arr-elem-runtime '__field_setlength__'` path:

```pascal
if ParseHirNodeKind('setlength-field-arr-runtime') = hnkUnknown then
  Fail('setlength-field-arr-runtime');
```

Keep the existing C6-H1 node-kind assertions intact.

- [ ] **Step 2: Scaffold a source-backed field-dynarray contract test**

Create `tests/hir/test_hir_field_dynarray_contract.pas` with the same local harness shape already used by the other compiler source-contract tests:

```pascal
function BuildModel(const ASource: string): TSemanticModel;
function EmitLlvm(const AModel: TSemanticModel): string;
function FindFirstNodeByKind(const AModel: TSemanticModel;
  const AKind: string; out ANode: TTypedHirNode): Boolean;
function FindFirstNodeByKindAndDisplayName(const AModel: TSemanticModel;
  const AKind, ADisplayName: string; out ANode: TTypedHirNode): Boolean;
function FindAfter(const ANeedle, AText: string; AStart: LongInt): LongInt;
function ExtractDefinitionSlice(const AText, AHeaderNeedle: string): string;
function RequireConst(const AModel: TSemanticModel;
  const AName: string; AExpected: Int64): Int64;
```

Import the same compiler units already used by `test_hir_dynarray_release_contract.pas`:

```pascal
uses
  SysUtils,
  np_ast_facade,
  np_diagnostics_sink,
  np_green_tree,
  np_hir_builder,
  np_hir_llvm_emitter,
  np_lexer,
  np_semantic_analyzer,
  np_semantic_model,
  np_unit_graph;
```

- [ ] **Step 3: Freeze semantic field-index and inherited-layout propagation in RED**

Use one focused layout fixture:

```pascal
const
  LayoutSource =
    'program test;' + LineEnding +
    'type TBase = class' + LineEnding +
    '  Head: Integer;' + LineEnding +
    '  Items: array of Integer;' + LineEnding +
    '  Tail: Integer;' + LineEnding +
    'end;' + LineEnding +
    'type TDerived = class(TBase)' + LineEnding +
    '  More: array of Integer;' + LineEnding +
    '  After: Integer;' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';
```

Assert the layout shift explicitly:

```pascal
RequireConst(Model, 'TBase.Items$arr', 1);
RequireConst(Model, 'TBase.Items$idx', 2);
RequireConst(Model, 'TBase.Tail$idx', 4);
RequireConst(Model, 'TDerived.Items$arr', 1);
RequireConst(Model, 'TDerived.Items$idx', 2);
RequireConst(Model, 'TDerived.More$arr', 1);
RequireConst(Model, 'TDerived.More$idx', 5);
RequireConst(Model, 'TDerived.After$idx', 7);
```

This is the first explicit gate for:

- semantic field index truth
- inherited layout propagation
- accepted dynarray-field class-layout ABI shift

- [ ] **Step 4: Freeze the owner-field resize contract, len-slot read contract, and legacy-path removal**

Use a field-resize fixture that covers both implicit and explicit `self` receivers:

```pascal
const
  FieldResizeSource =
    'program test;' + LineEnding +
    'type TWorker = class' + LineEnding +
    '  FieldArr: array of Integer;' + LineEnding +
    '  More: array of Integer;' + LineEnding +
    '  function Score: Integer;' + LineEnding +
    'end;' + LineEnding +
    'function TWorker.Score: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  SetLength(FieldArr, 4);' + LineEnding +
    '  SetLength(Self.More, 2);' + LineEnding +
    '  Result := Length(FieldArr) + Length(Self.More);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';
```

Freeze the new producer contract:

```pascal
if not FindFirstNodeByKindAndDisplayName(Model,
  'setlength-field-arr-runtime', 'FieldArr', Node) then
  Fail('missing-implicit-self-field-resize-node');
if not FindFirstNodeByKindAndDisplayName(Model,
  'setlength-field-arr-runtime', 'Self.More', Node) then
  Fail('missing-explicit-self-field-resize-node');
if FindFirstNodeByKindAndDisplayName(Model,
  'assign-arr-elem-runtime', '__field_setlength__', Node) then
  Fail('legacy-field-setlength-path-must-disappear');
```

Freeze the emitted len-slot reads at `idx + 1`:

```pascal
LlvmText := EmitLlvm(Model);
if Pos('call ptr @np_dynarray_resize(', LlvmText) = 0 then
  Fail('missing-field-dynarray-resize-call');
if Pos('getelementptr i64, ptr %self, i64 2', LlvmText) = 0 then
  Fail('missing-field-ptr-slot-gep');
if Pos('getelementptr i64, ptr %self, i64 3', LlvmText) = 0 then
  Fail('missing-field-len-slot-gep');
```

This locks:

- dedicated owner-field resize lowering
- `dynarray len idx+1 read contract`
- removal of the old allocate-only overwrite path

- [ ] **Step 5: Freeze field-array ptr-slot addressing, compile-time-class-only cleanup truth, and class-field string non-regression**

Use three more focused fixtures:

```pascal
const
  FieldElemSource =
    'program test;' + LineEnding +
    'type TReader = class' + LineEnding +
    '  FieldArr: array of Integer;' + LineEnding +
    '  function First: Integer;' + LineEnding +
    'end;' + LineEnding +
    'function TReader.First: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  Result := FieldArr[0];' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';

  FreeSource =
    'program test;' + LineEnding +
    'type TBase = class' + LineEnding +
    '  Head: Integer;' + LineEnding +
    '  Items: array of Integer;' + LineEnding +
    'end;' + LineEnding +
    'type TDerived = class(TBase)' + LineEnding +
    '  More: array of Integer;' + LineEnding +
    'end;' + LineEnding +
    'procedure FreeDerived(D: TDerived);' + LineEnding +
    'begin' + LineEnding +
    '  D.Free;' + LineEnding +
    'end;' + LineEnding +
    'procedure FreeBase(B: TBase);' + LineEnding +
    'begin' + LineEnding +
    '  B.Free;' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';

  StringFieldSource =
    'program test;' + LineEnding +
    'type TStringBox = class' + LineEnding +
    '  Text: string;' + LineEnding +
    '  Other: string;' + LineEnding +
    '  procedure Touch;' + LineEnding +
    'end;' + LineEnding +
    'procedure TStringBox.Touch;' + LineEnding +
    'begin' + LineEnding +
    '  Other := Text;' + LineEnding +
    '  Text := Text + Other;' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';
```

Freeze ptr-slot element addressing with LLVM-level evidence:

```pascal
FieldElemLlvm := EmitLlvm(FieldElemModel);
if Pos('getelementptr i64, ptr %self, i64 1', FieldElemLlvm) = 0 then
  Fail('missing-field-array-ptr-slot-index');
if Pos('load ptr, ptr %', FieldElemLlvm) = 0 then
  Fail('missing-field-array-ptr-slot-load');
```

Freeze compile-time-class-only cleanup with class-specific helper calls:

```pascal
FreeLlvm := EmitLlvm(FreeModel);
DerivedFreeLlvm := ExtractDefinitionSlice(FreeLlvm, '@FreeDerived(');
BaseFreeLlvm := ExtractDefinitionSlice(FreeLlvm, '@FreeBase(');
if Pos('call void @np_object_dynarray_cleanup_TDerived(ptr ', DerivedFreeLlvm) = 0 then
  Fail('missing-derived-cleanup-helper-call');
if Pos('call void @np_object_dynarray_cleanup_TBase(ptr ', BaseFreeLlvm) = 0 then
  Fail('missing-base-cleanup-helper-call');
if Pos('@np_object_dynarray_cleanup_TDerived', BaseFreeLlvm) <> 0 then
  Fail('base-free-must-stay-compile-time-class-only');
```

Freeze class-field string paths as untouched:

```pascal
StringFieldLlvm := EmitLlvm(StringFieldModel);
if not FindFirstNodeByKind(StringFieldModel, 'assign-str-field-load-runtime', Node) then
  Fail('missing-string-field-load-node');
if not FindFirstNodeByKind(StringFieldModel, 'field-store-str-runtime', Node) then
  Fail('missing-string-field-store-node');
if Pos('call {ptr, i64} @np_str_concat(', StringFieldLlvm) = 0 then
  Fail('missing-string-field-concat-helper-call');
```

This is the explicit gate for:

- `field-array ptr-slot addressing` still using the ptr slot
- `BaseRef.Free compile-time-class-only truth`
- `string field paths untouched`

- [ ] **Step 6: Keep the landed C6-H1 standalone contracts narrow and keep `@np_object_free_release` field-agnostic**

Update `tests/hir/test_hir_dynarray_release_contract.pas` so it keeps covering only:

- owned standalone dynarray locals
- borrowed params
- string lowering untouched

Drop the old `AssertFieldPathPreserved` section and replace it with a brief comment in the test body:

```pascal
{ C6-H2 moves field dynarray contracts into test_hir_field_dynarray_contract. }
```

Then extend `tests/hir/test_hir_object_free_contract.pas` with one helper-slice assertion:

```pascal
ReleaseHelperSlice := ExtractDefinitionSlice(LlvmText,
  'define internal void @np_object_free_release(ptr %obj)');
if ReleaseHelperSlice = '' then
  Fail('missing-object-free-release-helper');
if Pos('call void @np_dynarray_release(', ReleaseHelperSlice) <> 0 then
  Fail('object-free-release-helper-must-stay-field-agnostic');
if Pos('@np_object_dynarray_cleanup_', ReleaseHelperSlice) <> 0 then
  Fail('object-free-release-helper-must-not-walk-fields');
```

This locks:

- `@np_object_free_release remains field-agnostic`

- [ ] **Step 7: Run the focused source contracts and confirm RED**

Run:

```bash
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h2-node-kind-red -FUbuild/.tmp/c6h2-node-kind-red tests/hir/test_hir_node_kind.pas && build/.tmp/c6h2-node-kind-red/test_hir_node_kind
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h2-standalone-contract-red -FUbuild/.tmp/c6h2-standalone-contract-red tests/hir/test_hir_dynarray_release_contract.pas && build/.tmp/c6h2-standalone-contract-red/test_hir_dynarray_release_contract
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h2-field-contract-red -FUbuild/.tmp/c6h2-field-contract-red tests/hir/test_hir_field_dynarray_contract.pas && build/.tmp/c6h2-field-contract-red/test_hir_field_dynarray_contract
fpc -Fucompiler/sema -Fucompiler/syntax -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h2-object-free-contract-red -FUbuild/.tmp/c6h2-object-free-contract-red tests/hir/test_hir_object_free_contract.pas && build/.tmp/c6h2-object-free-contract-red/test_hir_object_free_contract
```

Expected RED:

- `test_hir_field_dynarray_contract` fails first on missing `$arr` metadata, missing field-index shift, missing field-resize node, or missing cleanup-helper call
- `test_hir_dynarray_release_contract` fails only if C6-H2 accidentally regresses the landed C6-H1 standalone/string behavior

- [ ] **Step 8: Commit the RED source-contract slice**

```bash
git add tests/hir/test_hir_node_kind.pas tests/hir/test_hir_dynarray_release_contract.pas tests/hir/test_hir_field_dynarray_contract.pas tests/hir/test_hir_object_free_contract.pas
git commit -m "test(compiler): freeze C6-H2 field dynarray contracts"
```

### Task 2: Freeze C6-H2 RED runtime smokes

**Files:**
- Create: `tests/hir/test_hir_field_dynarray_release_runtime_smoke.pas`
- Modify: `build/verify_local.sh`

- [ ] **Step 1: Create a dedicated runtime-smoke harness for field dynarrays**

Reuse the accepted C6-H1 smoke pattern:

```pascal
procedure WriteTextFile(const APath, AText: string);
function ToolPath(const AEnvName, ADefaultValue: string): string;
procedure RunCommand(const ALabel, AExecutable: string;
  const AArgs: array of string; AExpectedExit: LongInt);
function BuildModel(const ASource: string): TSemanticModel;
function EmitLlvmFromSource(const ASource: string): string;
procedure RunRuntimeSmoke(const AOutputDir, AStem: string);
```

Keep the smoke self-contained: it must write `.ll`, run `opt`, `llc`, `clang`, then execute the produced binary and assert exit `42`.

- [ ] **Step 2: Add a generated Pascal smoke for owner-field resize, ptr-slot addressing, and len-slot reads**

Use one end-to-end field fixture:

```pascal
const
  FieldResizeSource =
    'program field_resize;' + LineEnding +
    'type TBox = class' + LineEnding +
    '  Items: array of Integer;' + LineEnding +
    '  procedure Grow;' + LineEnding +
    '  function Score: Integer;' + LineEnding +
    'end;' + LineEnding +
    'procedure TBox.Grow;' + LineEnding +
    'begin' + LineEnding +
    '  SetLength(Items, 4);' + LineEnding +
    '  Items[0] := 17;' + LineEnding +
    '  Items[3] := 21;' + LineEnding +
    '  SetLength(Self.Items, 8);' + LineEnding +
    'end;' + LineEnding +
    'function TBox.Score: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  Result := Items[0] + Items[3] + Length(Items);' + LineEnding +
    'end;' + LineEnding +
    'var B: TBox;' + LineEnding +
    'begin' + LineEnding +
    '  B := TBox.Create;' + LineEnding +
    '  B.Grow;' + LineEnding +
    '  Halt(B.Score - 4);' + LineEnding +
    'end.';
```

This single smoke must prove:

- repeated owner-field `SetLength` preserves previous values
- field-array element access still reads through the ptr slot
- `Length(Items)` reads the len slot

- [ ] **Step 3: Add a direct inherited-cleanup-helper smoke**

Generate LLVM from a class hierarchy that forces both base and derived dynarray fields into one cleanup helper:

```pascal
const
  CleanupHelperSource =
    'program field_cleanup;' + LineEnding +
    'type TBase = class' + LineEnding +
    '  Head: Integer;' + LineEnding +
    '  Items: array of Integer;' + LineEnding +
    'end;' + LineEnding +
    'type TDerived = class(TBase)' + LineEnding +
    '  More: array of Integer;' + LineEnding +
    'end;' + LineEnding +
    'procedure FreeDerived(D: TDerived);' + LineEnding +
    'begin' + LineEnding +
    '  D.Free;' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';
```

Harvest the emitted helper body and build a direct `_start` IR module around it:

```llvm
define i64 @_start() {
entry:
  %obj = alloca [8 x i64], align 8
  %obj.base = getelementptr [8 x i64], ptr %obj, i64 0, i64 0
  %base.ptr = call ptr @np_dynarray_resize(ptr null, i64 0, i64 2, i64 8)
  %base.len.slot = getelementptr i64, ptr %obj.base, i64 3
  %base.ptr.slot = getelementptr i64, ptr %obj.base, i64 2
  store ptr %base.ptr, ptr %base.ptr.slot
  store i64 2, ptr %base.len.slot
  %derived.ptr = call ptr @np_dynarray_resize(ptr null, i64 0, i64 3, i64 8)
  %derived.ptr.slot = getelementptr i64, ptr %obj.base, i64 4
  %derived.len.slot = getelementptr i64, ptr %obj.base, i64 5
  store ptr %derived.ptr, ptr %derived.ptr.slot
  store i64 3, ptr %derived.len.slot
  call void @np_object_dynarray_cleanup_TDerived(ptr %obj.base)
  %base.ptr.after = load ptr, ptr %base.ptr.slot
  %base.len.after = load i64, ptr %base.len.slot
  %derived.ptr.after = load ptr, ptr %derived.ptr.slot
  %derived.len.after = load i64, ptr %derived.len.slot
  %base.ptr.clear = icmp eq ptr %base.ptr.after, null
  %base.len.clear = icmp eq i64 %base.len.after, 0
  %derived.ptr.clear = icmp eq ptr %derived.ptr.after, null
  %derived.len.clear = icmp eq i64 %derived.len.after, 0
  %base.ok = and i1 %base.ptr.clear, %base.len.clear
  %derived.ok = and i1 %derived.ptr.clear, %derived.len.clear
  %all.ok = and i1 %base.ok, %derived.ok
  br i1 %all.ok, label %pass, label %fail
pass:
  call void asm sideeffect "movq $$60, %rax; syscall", "{rdi},~{rax},~{rcx},~{r11}"(i64 42)
  unreachable
fail:
  call void asm sideeffect "movq $$60, %rax; syscall", "{rdi},~{rax},~{rcx},~{r11}"(i64 13)
  unreachable
}
```

The pass condition is:

- base field slots cleared back to `{null, 0}`
- derived field slots cleared back to `{null, 0}`

This is the runtime gate for inherited cleanup, not just source-level text matching.

- [ ] **Step 4: Add a generated Pascal `Free` smoke**

Use one real object-free fixture:

```pascal
const
  ObjectFreeSource =
    'program object_free;' + LineEnding +
    'type TBase = class' + LineEnding +
    '  Head: Integer;' + LineEnding +
    '  Items: array of Integer;' + LineEnding +
    'end;' + LineEnding +
    'type TDerived = class(TBase)' + LineEnding +
    '  More: array of Integer;' + LineEnding +
    '  procedure Prepare;' + LineEnding +
    'end;' + LineEnding +
    'procedure TDerived.Prepare;' + LineEnding +
    'begin' + LineEnding +
    '  SetLength(Items, 2);' + LineEnding +
    '  SetLength(More, 3);' + LineEnding +
    '  Items[0] := 11;' + LineEnding +
    '  More[2] := 31;' + LineEnding +
    'end;' + LineEnding +
    'var D: TDerived;' + LineEnding +
    'begin' + LineEnding +
    '  D := TDerived.Create;' + LineEnding +
    '  D.Prepare;' + LineEnding +
    '  D.Free;' + LineEnding +
    '  Halt(42);' + LineEnding +
    'end.';
```

This smoke is the repeatable proof that the real `Destroy -> field cleanup -> heap release` path compiles, links, runs, and exits `42`.

- [ ] **Step 5: Wire the runtime smoke into `build/verify_local.sh`**

Add a dedicated build/output section near the other HIR smoke binaries:

```bash
HIR_FIELD_DYNARRAY_RUNTIME_BUILD_DIR=$(mktemp -d)
HIR_FIELD_DYNARRAY_RUNTIME_BINARY="$HIR_FIELD_DYNARRAY_RUNTIME_BUILD_DIR/test_hir_field_dynarray_release_runtime_smoke"
HIR_FIELD_DYNARRAY_RUNTIME_OUTPUT=$(mktemp)
```

Then add a runnable gate after `hir-object-free-contract`:

```bash
printf 'hir-field-dynarray-runtime-smoke=running\n'
printf 'hir-field-dynarray-runtime-smoke-command=fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FE%s -FU%s tests/hir/test_hir_field_dynarray_release_runtime_smoke.pas\n' "$HIR_FIELD_DYNARRAY_RUNTIME_BUILD_DIR" "$HIR_FIELD_DYNARRAY_RUNTIME_BUILD_DIR"
if ! fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FE"$HIR_FIELD_DYNARRAY_RUNTIME_BUILD_DIR" -FU"$HIR_FIELD_DYNARRAY_RUNTIME_BUILD_DIR" tests/hir/test_hir_field_dynarray_release_runtime_smoke.pas >/dev/null 2>&1; then
  fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FE"$HIR_FIELD_DYNARRAY_RUNTIME_BUILD_DIR" -FU"$HIR_FIELD_DYNARRAY_RUNTIME_BUILD_DIR" tests/hir/test_hir_field_dynarray_release_runtime_smoke.pas
  fail 'hir-field-dynarray-runtime-smoke-build-failed'
fi
if ! "$HIR_FIELD_DYNARRAY_RUNTIME_BINARY" >"$HIR_FIELD_DYNARRAY_RUNTIME_OUTPUT" 2>&1; then
  cat "$HIR_FIELD_DYNARRAY_RUNTIME_OUTPUT"
  fail 'hir-field-dynarray-runtime-smoke-run-failed'
fi
cat "$HIR_FIELD_DYNARRAY_RUNTIME_OUTPUT"
require_output_pattern '^hir-field-dynarray-runtime-smoke-resize-exit=42$' "$HIR_FIELD_DYNARRAY_RUNTIME_OUTPUT" 'missing-field-resize-smoke-pass'
require_output_pattern '^hir-field-dynarray-runtime-smoke-cleanup-helper-exit=42$' "$HIR_FIELD_DYNARRAY_RUNTIME_OUTPUT" 'missing-cleanup-helper-smoke-pass'
require_output_pattern '^hir-field-dynarray-runtime-smoke-object-free-exit=42$' "$HIR_FIELD_DYNARRAY_RUNTIME_OUTPUT" 'missing-object-free-smoke-pass'
require_output_pattern '^hir-field-dynarray-runtime-smoke-status=pass$' "$HIR_FIELD_DYNARRAY_RUNTIME_OUTPUT" 'missing-field-runtime-smoke-pass'
printf 'hir-field-dynarray-runtime-smoke=pass\n'
```

- [ ] **Step 6: Run the focused runtime smokes and confirm RED**

Run:

```bash
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h2-field-runtime-red -FUbuild/.tmp/c6h2-field-runtime-red tests/hir/test_hir_field_dynarray_release_runtime_smoke.pas && build/.tmp/c6h2-field-runtime-red/test_hir_field_dynarray_release_runtime_smoke build/.tmp/c6h2-field-runtime-red
```

Expected RED:

- missing class-specific cleanup helper
- missing field-resize helper call
- missing slot clearing or wrong cleanup order

- [ ] **Step 7: Commit the RED runtime-smoke slice**

```bash
git add tests/hir/test_hir_field_dynarray_release_runtime_smoke.pas build/verify_local.sh
git commit -m "test(compiler): add C6-H2 field dynarray runtime smokes"
```

### Task 3: Implement the minimal C6-H2 slice

**Files:**
- Modify: `compiler/sema/np_semantic_model.pas`
- Modify: `compiler/sema/np_semantic_analyzer.pas`
- Modify: `compiler/ir/np_hir_types.pas`
- Modify: `compiler/ir/np_hir_builder.pas`

- [ ] **Step 1: Add explicit dynarray-field metadata**

Extend `TFieldMeta` in `compiler/sema/np_semantic_model.pas`:

```pascal
TFieldMeta = record
  Name: string;
  Index: LongInt;
  IsString: Boolean;
  IsPointer: Boolean;
  IsDynArray: Boolean;
  TypeId: LongInt;
end;
```

Do not reuse `IsPointer` as a dynarray marker. The implementation must be able to distinguish:

- raw pointer field
- string field
- dynarray field
- record field

- [ ] **Step 2: Make semantic metadata and inherited class layout tell the truth**

In `compiler/sema/np_semantic_analyzer.pas`:

- clone parent `IsDynArray` metadata alongside `IsString` and `IsPointer`
- clone parent `$arr` constants during inherited metadata copy
- when the declared field type node is `gnkArrayType`, add:

```pascal
FModel.AddConstValue(ClsName + '.' + Child.Text + '$arr', 1);
Meta.Fields[High(Meta.Fields)].IsDynArray := True;
Inc(FieldIndex, 2);
```

- leave the ptr slot at `$idx`
- leave the len slot implicitly at `$idx + 1`
- keep later fields shifted by `+1` slot after every dynarray field

The class-layout ABI shift is intentional; do not try to preserve the old one-slot layout.

- [ ] **Step 3: Lower `Length` and owner-field `SetLength` through the new field contract**

In `compiler/sema/np_semantic_analyzer.pas`:

- add `TypeMetaFieldIsDynArray`
- lower `Length(FieldArr)` and `Length(Self.FieldArr)` to `field self <idx + 1>`
- produce `setlength-field-arr-runtime` for:
  - `SetLength(FieldArr, n)`
  - `SetLength(Self.FieldArr, n)`
- encode the operand as:

```text
self<TAB>field_idx<TAB>new_len_blob<TAB>elem_size
```

- keep `SetLength(Other.FieldArr, n)` out of scope
- do not revive `assign-arr-elem-runtime '__field_setlength__'` for dynarray fields

- [ ] **Step 4: Add builder lowering for field resize**

In `compiler/ir/np_hir_types.pas` add the new enum item and string mapping:

```pascal
hnkSetLengthFieldArrRuntime
```

In `compiler/ir/np_hir_builder.pas`:

- route the new node kind to a dedicated `ProcessSetLengthFieldArr`
- compute:
  - ptr slot at `idx + 0`
  - len slot at `idx + 1`
- load old ptr and old len
- emit the existing intrinsic:

```pascal
Instr.IntrinsicName := 'dynarray_resize';
```

- store the returned ptr back to the ptr slot
- store `%new_len` back to the len slot

This keeps field resize on the same allocator/runtime boundary as C6-H1 without touching string paths.

- [ ] **Step 5: Synthesize compile-time-class-specific cleanup helpers and call them before heap release**

Still in `compiler/ir/np_hir_builder.pas`:

- extend the `object-free-runtime` operand parsing to carry:

```text
cleanup-class <StaticClassName>
```

- add a helper synthesizer:

```pascal
procedure EnsureObjectDynArrayCleanupHelper(const AClassName: string);
```

The generated internal HIR function must:

- accept `ptr %obj`
- walk the compile-time class's dynarray fields
- visit most-derived fields first, then inherited fields
- load ptr from `idx`
- load len from `idx + 1`
- emit `dynarray_release`
- clear the field back to `{null, 0}`

At the `Free` call site, the lowering order must be:

```text
destroy call
call @np_object_dynarray_cleanup_<StaticClassName>
call @np_object_free_release
```

This is where `BaseRef.Free` stays compile-time-class-only:

- `FreeDerived(D: TDerived)` calls `@np_object_dynarray_cleanup_TDerived`
- `FreeBase(B: TBase)` calls `@np_object_dynarray_cleanup_TBase`

- [ ] **Step 6: Leave string lowering and `@np_object_free_release` alone**

Do not edit:

- string field slot ABI
- `assign-str-field-load-runtime`
- string concat/copy lowering
- `EmitObjectFreeReleaseHelper`
- `EmitObjectReleaseValidHelper`

If a change seems to require those files, stop and re-check scope. C6-H2 must keep:

- `string field paths untouched`
- `@np_object_free_release remains field-agnostic`

- [ ] **Step 7: Run the focused GREEN gates**

Run:

```bash
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h2-node-kind-green -FUbuild/.tmp/c6h2-node-kind-green tests/hir/test_hir_node_kind.pas && build/.tmp/c6h2-node-kind-green/test_hir_node_kind
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h2-standalone-contract-green -FUbuild/.tmp/c6h2-standalone-contract-green tests/hir/test_hir_dynarray_release_contract.pas && build/.tmp/c6h2-standalone-contract-green/test_hir_dynarray_release_contract
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h2-field-contract-green -FUbuild/.tmp/c6h2-field-contract-green tests/hir/test_hir_field_dynarray_contract.pas && build/.tmp/c6h2-field-contract-green/test_hir_field_dynarray_contract
fpc -Fucompiler/sema -Fucompiler/syntax -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h2-object-free-contract-green -FUbuild/.tmp/c6h2-object-free-contract-green tests/hir/test_hir_object_free_contract.pas && build/.tmp/c6h2-object-free-contract-green/test_hir_object_free_contract
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h2-field-runtime-green -FUbuild/.tmp/c6h2-field-runtime-green tests/hir/test_hir_field_dynarray_release_runtime_smoke.pas && build/.tmp/c6h2-field-runtime-green/test_hir_field_dynarray_release_runtime_smoke build/.tmp/c6h2-field-runtime-green
```

All five must pass before any closeout claim.

- [ ] **Step 8: Commit the implementation slice**

```bash
git add compiler/sema/np_semantic_model.pas compiler/sema/np_semantic_analyzer.pas compiler/ir/np_hir_types.pas compiler/ir/np_hir_builder.pas
git commit -m "feat(compiler): implement C6-H2 field dynarray release"
```

### Task 4: Run the full verification envelope

**Files:**
- No additional file changes expected

- [ ] **Step 1: Re-run the focused source and runtime gates on the final tree**

Run the same five focused commands from Task 3 Step 7 on the final post-implementation tree.

- [ ] **Step 2: Run `git diff --check`**

Run:

```bash
git diff --check
```

Expected: no whitespace or merge-marker failures.

- [ ] **Step 3: Run `make hygiene`**

Run:

```bash
make hygiene
```

Expected: hygiene/build-artifact checks pass with no stray outputs committed.

- [ ] **Step 4: Run the full local compiler verification**

Run:

```bash
./build/verify_local.sh
```

Required truth:

- the existing compiler/toolchain envelope still passes
- the new `hir-field-dynarray-runtime-smoke` gate passes inside the same run

- [ ] **Step 5: Commit any final verify-only glue**

If the only remaining changes are the intended `build/verify_local.sh` hook or test updates that were not committed in earlier steps, commit them separately:

```bash
git add build/verify_local.sh tests/hir/test_hir_field_dynarray_release_runtime_smoke.pas tests/hir/test_hir_field_dynarray_contract.pas tests/hir/test_hir_dynarray_release_contract.pas tests/hir/test_hir_object_free_contract.pas tests/hir/test_hir_node_kind.pas
git commit -m "test(compiler): wire C6-H2 field dynarray verification"
```

Do not squash this into unrelated docs or implementation commits.

- [ ] **Step 6: Prepare the review package**

Before reporting `Ready`, confirm:

- focused HIR/source contracts pass
- field dynarray runtime smoke passes
- `git diff --check` passes
- `make hygiene` passes
- `./build/verify_local.sh` passes
- only C6-H2 paths are included in the review package

At that point the lane may move from `Needs Review` to the next review node.
