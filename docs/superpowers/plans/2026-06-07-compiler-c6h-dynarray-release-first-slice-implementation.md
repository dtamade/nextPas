# C6-H1 Dynarray Release First-Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the first dynarray-only runtime lifecycle slice so owned standalone dynarray slots stop leaking across repeated `SetLength` and ordinary exits, while borrowed params remain explicitly non-owning and string/field paths stay untouched.

**Architecture:** Freeze producer, builder, emitter, and runtime-helper contracts in RED before touching implementation. Represent borrowed dynarray params and owned dynarray cleanup as explicit HIR node kinds, then lower owned `SetLength` through `@np_dynarray_resize` and ordinary exits through `@np_dynarray_release`. Keep field dynarray lowering on the current `__field_setlength__` path, keep string lowering byte-for-byte compatible, and defer borrowed resize semantics, field release, string ownership, return ownership, managed element finalization, and unwind cleanup to later slices.

**Tech Stack:** Free Pascal, compiler sema/HIR builder/LLVM emitter, stage0 LLVM smoke flow, `tests/hir`, `build/verify_local.sh`

---

### Task 1: Freeze C6-H1 RED source contracts

**Files:**
- Modify: `tests/hir/test_hir_node_kind.pas`
- Create: `tests/hir/test_hir_dynarray_release_contract.pas`

- [ ] **Step 1: Extend the HIR node-kind contract for the new ownership and cleanup nodes**

Add the new enum coverage first:

```pascal
if ParseHirNodeKind('var-decl-arr-borrowed-runtime') <>
  hnkVarDeclArrBorrowedRuntime then
  Fail('var-decl-arr-borrowed-runtime');
if ParseHirNodeKind('dynarray-cleanup-runtime') <>
  hnkDynArrayCleanupRuntime then
  Fail('dynarray-cleanup-runtime');
```

This is the first RED: the repo does not recognize the new node kinds yet.

- [ ] **Step 2: Scaffold a dynarray contract test that can parse source, inspect HIR, and inspect emitted LLVM**

Create the new test with the same shape already used in source-backed compiler tests:

```pascal
function BuildModel(const ASource: string): TSemanticModel;
function FindFirstNodeByKind(const AModel: TSemanticModel;
  const AKind: string; out ANode: TTypedHirNode): Boolean;
function FindFirstNodeByKindAndDisplayName(const AModel: TSemanticModel;
  const AKind, ADisplayName: string; out ANode: TTypedHirNode): Boolean;
function FindAfter(const ANeedle, AText: string; AStart: LongInt): LongInt;
function EmitLlvm(const AModel: TSemanticModel): string;
```

Import:

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

The test should stay self-contained under `tests/hir/`; do not depend on ad-hoc shell greps.

- [ ] **Step 3: Add producer RED assertions for owned locals, borrowed params, ordinary-exit cleanup, field preservation, and string preservation**

Use three focused fixtures:

```pascal
const
  OwnedAndBorrowedSource =
    'program test;' + LineEnding +
    'procedure Touch(A: array of Integer);' + LineEnding +
    'var Local: array of Integer;' + LineEnding +
    'begin' + LineEnding +
    '  SetLength(Local, 4);' + LineEnding +
    '  if A[0] = 1 then Exit;' + LineEnding +
    '  Halt(0);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';

  FieldSource =
    'program test;' + LineEnding +
    'type TWorker = class' + LineEnding +
    '  FieldArr: array of Integer;' + LineEnding +
    '  procedure Touch;' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Touch;' + LineEnding +
    'begin' + LineEnding +
    '  SetLength(FieldArr, 4);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';

  StringSource =
    'program test;' + LineEnding +
    'var A, B, C: string;' + LineEnding +
    'begin' + LineEnding +
    '  B := A;' + LineEnding +
    '  C := A + B;' + LineEnding +
    'end.';
```

Assert:

```pascal
if not FindFirstNodeByKindAndDisplayName(Model,
  'var-decl-arr-borrowed-runtime', 'A', Node) then
  Fail('missing-borrowed-dynarray-param-node');
if not FindFirstNodeByKindAndDisplayName(Model,
  'var-decl-arr-runtime', 'Local', Node) then
  Fail('missing-owned-dynarray-local-node');
if FindFirstNodeByKindAndDisplayName(Model,
  'dynarray-cleanup-runtime', 'A', Node) then
  Fail('borrowed-param-must-not-cleanup');
if not FindFirstNodeByKindAndDisplayName(Model,
  'dynarray-cleanup-runtime', 'Local', Node) then
  Fail('missing-owned-local-cleanup-node');
if not FindFirstNodeByKindAndDisplayName(Model,
  'assign-arr-elem-runtime', '__field_setlength__', Node) then
  Fail('missing-field-setlength-preserved-path');
if not FindFirstNodeByKind(Model, 'assign-str-copy-runtime', Node) then
  Fail('missing-string-shallow-copy-node');
if not FindFirstNodeByKind(Model, 'assign-str-concat-runtime', Node) then
  Fail('missing-string-concat-node');
```

Expected RED: at least the borrowed declaration and cleanup-node assertions fail immediately.

- [ ] **Step 4: Add LLVM/source RED assertions for resize/release helpers, cleanup ordering, borrowed no-resize, field preservation, and string untouched**

Emit LLVM from the owned/borrowed fixture and freeze these reviewed properties:

```pascal
ResizeDeclPos := Pos('define internal ptr @np_dynarray_resize(', LlvmText);
ReleaseDeclPos := Pos('define internal void @np_dynarray_release(', LlvmText);
FaultDeclPos := Pos('define internal void @np_dynarray_fault(', LlvmText);
ResizeCallPos := Pos('call ptr @np_dynarray_resize(', LlvmText);
ReleaseCallPos := Pos('call void @np_dynarray_release(', LlvmText);
FreeCallPos := Pos('call void @np_free(ptr ', LlvmText);
MemcpyCallPos := Pos('call void @np_memcpy(ptr ', LlvmText);
RetPos := Pos('ret i64 ', LlvmText);
HaltPos := Pos('call void asm sideeffect "movq $$60, %rax; syscall"', LlvmText);
```

Then assert:

```pascal
if ResizeDeclPos = 0 then Fail('missing-dynarray-resize-helper');
if ReleaseDeclPos = 0 then Fail('missing-dynarray-release-helper');
if FaultDeclPos = 0 then Fail('missing-dynarray-fault-helper');
if ResizeCallPos = 0 then Fail('missing-owned-setlength-resize-call');
if ReleaseCallPos = 0 then Fail('missing-owned-cleanup-release-call');
if Pos('call ptr @np_alloc(i64 %arralloc.', LlvmText) <> 0 then
  Fail('owned-setlength-still-uses-bare-arr-alloc');
if not ((ReleaseCallPos < RetPos) or (ReleaseCallPos < HaltPos)) then
  Fail('owned-cleanup-must-precede-exit-edge');
if Pos('__field_setlength__', FieldLlvmText) = 0 then
  Fail('field-setlength-path-regressed');
if Pos('call ptr @np_str_concat(', StringLlvmText) = 0 then
  Fail('string-concat-path-regressed');
if Pos('store ptr %', StringLlvmText) = 0 then
  Fail('string-shallow-copy-path-regressed');
```

Also build a borrowed-param fixture that mentions `A[0]` but never owned-local `SetLength`, and assert it contains no `@np_dynarray_resize`.

- [ ] **Step 5: Run the focused source contracts and confirm RED**

Run:

```bash
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h1-node-kind-red -FUbuild/.tmp/c6h1-node-kind-red tests/hir/test_hir_node_kind.pas && build/.tmp/c6h1-node-kind-red/test_hir_node_kind
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h1-dynarray-contract-red -FUbuild/.tmp/c6h1-dynarray-contract-red tests/hir/test_hir_dynarray_release_contract.pas && build/.tmp/c6h1-dynarray-contract-red/test_hir_dynarray_release_contract
```

Expected: `test_hir_dynarray_release_contract` fails on the first missing borrowed-node, cleanup-node, or helper-boundary assertion.

- [ ] **Step 6: Commit the RED source-contract slice**

```bash
git add tests/hir/test_hir_node_kind.pas tests/hir/test_hir_dynarray_release_contract.pas
git commit -m "test(compiler): freeze C6-H1 dynarray release contracts"
```

### Task 2: Freeze C6-H1 RED runtime smokes

**Files:**
- Create: `tests/hir/test_hir_dynarray_release_runtime_smoke.pas`
- Modify: `build/verify_local.sh`

- [ ] **Step 1: Create a runtime-smoke harness that can write IR, call `opt`/`llc`/`clang`, and assert exit codes**

Reuse the already accepted pattern from `tests/hir/test_hir_large_alloc_runtime_smoke.pas`:

```pascal
procedure WriteTextFile(const APath, AText: string);
function ToolPath(const AEnvName, ADefaultValue: string): string;
procedure RunCommand(const ALabel, AExecutable: string;
  const AArgs: array of string; AExpectedExit: LongInt);
procedure RunRuntimeSmoke(const AOutputDir, AStem: string);
```

This keeps the smoke repeatable and one-command runnable inside `verify_local`.

- [ ] **Step 2: Add a direct helper smoke for `@np_dynarray_resize` and `@np_dynarray_release`**

Build IR that exercises the helpers directly:

```llvm
define i64 @_start() {
entry:
  %p0 = call ptr @np_dynarray_resize(ptr null, i64 0, i64 4, i64 8)
  store i64 17, ptr %p0
  %tail0 = getelementptr i64, ptr %p0, i64 3
  store i64 29, ptr %tail0
  %p1 = call ptr @np_dynarray_resize(ptr %p0, i64 4, i64 8, i64 8)
  %head1 = load i64, ptr %p1
  %tail1p = getelementptr i64, ptr %p1, i64 3
  %tail1 = load i64, ptr %tail1p
  %head.ok = icmp eq i64 %head1, 17
  %tail.ok = icmp eq i64 %tail1, 29
  call void @np_dynarray_release(ptr %p1, i64 8, i64 8)
  br i1 %head.ok, label %check.tail, label %fail
check.tail:
  br i1 %tail.ok, label %pass, label %fail
pass:
  call void asm sideeffect "movq $$60, %rax; syscall", "{rdi},~{rax},~{rcx},~{r11}"(i64 42)
  unreachable
fail:
  call void asm sideeffect "movq $$60, %rax; syscall", "{rdi},~{rax},~{rcx},~{r11}"(i64 13)
  unreachable
}
```

The helper bodies should be harvested from real emitted LLVM, not hand-maintained duplicates.

- [ ] **Step 3: Add compiler-generated dynarray smokes for repeated `SetLength` and explicit `Exit` cleanup**

Generate LLVM from real Pascal fixtures:

```pascal
const
  ResizeSource =
    'program dynarray_resize;' + LineEnding +
    'var A: array of Integer; I: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  SetLength(A, 4);' + LineEnding +
    '  A[0] := 17;' + LineEnding +
    '  A[3] := 29;' + LineEnding +
    '  SetLength(A, 8);' + LineEnding +
    '  I := A[0] + A[3];' + LineEnding +
    '  Halt(I - 4);' + LineEnding +
    'end.';

  ExitSource =
    'program dynarray_exit;' + LineEnding +
    'procedure Work;' + LineEnding +
    'var A: array of Integer;' + LineEnding +
    'begin' + LineEnding +
    '  SetLength(A, 4);' + LineEnding +
    '  Exit;' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Work;' + LineEnding +
    '  Halt(42);' + LineEnding +
    'end.';
```

Add source-contract checks before running:

```pascal
if Pos('call ptr @np_dynarray_resize(', ResizeLlvm) = 0 then
  Fail('missing-generated-resize-call');
if Pos('call void @np_dynarray_release(', ExitLlvm) = 0 then
  Fail('missing-generated-exit-cleanup-call');
```

- [ ] **Step 4: Wire the new smoke into `build/verify_local.sh`**

Add the new required path and tmp variables:

```sh
require_path tests/hir/test_hir_dynarray_release_runtime_smoke.pas

HIR_DYNARRAY_RUNTIME_BUILD_DIR=$(mktemp -d)
HIR_DYNARRAY_RUNTIME_BINARY="$HIR_DYNARRAY_RUNTIME_BUILD_DIR/test_hir_dynarray_release_runtime_smoke"
HIR_DYNARRAY_RUNTIME_OUTPUT=$(mktemp)
```

Then add a focused section modeled after the existing HIR smokes:

```sh
printf 'hir-dynarray-release-runtime-smoke=running\n'
printf 'hir-dynarray-release-runtime-smoke-command=fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FE%s -FU%s tests/hir/test_hir_dynarray_release_runtime_smoke.pas\n' "$HIR_DYNARRAY_RUNTIME_BUILD_DIR" "$HIR_DYNARRAY_RUNTIME_BUILD_DIR"
if ! fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FE"$HIR_DYNARRAY_RUNTIME_BUILD_DIR" -FU"$HIR_DYNARRAY_RUNTIME_BUILD_DIR" tests/hir/test_hir_dynarray_release_runtime_smoke.pas >/dev/null 2>&1; then
  fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FE"$HIR_DYNARRAY_RUNTIME_BUILD_DIR" -FU"$HIR_DYNARRAY_RUNTIME_BUILD_DIR" tests/hir/test_hir_dynarray_release_runtime_smoke.pas
  fail 'hir-dynarray-release-runtime-smoke-build-failed'
fi
if ! "$HIR_DYNARRAY_RUNTIME_BINARY" >"$HIR_DYNARRAY_RUNTIME_OUTPUT" 2>&1; then
  cat "$HIR_DYNARRAY_RUNTIME_OUTPUT"
  fail 'hir-dynarray-release-runtime-smoke-run-failed'
fi
require_output_pattern '^hir-dynarray-release-runtime-smoke-status=pass$' "$HIR_DYNARRAY_RUNTIME_OUTPUT" 'missing-hir-dynarray-release-runtime-smoke-pass'
printf 'hir-dynarray-release-runtime-smoke=pass\n'
```

- [ ] **Step 5: Run the runtime smoke and confirm RED**

Run:

```bash
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h1-dynarray-runtime-red -FUbuild/.tmp/c6h1-dynarray-runtime-red tests/hir/test_hir_dynarray_release_runtime_smoke.pas && build/.tmp/c6h1-dynarray-runtime-red/test_hir_dynarray_release_runtime_smoke
```

Expected: the smoke fails before implementation because the helper definitions and generated resize/release paths do not exist yet.

- [ ] **Step 6: Commit the RED runtime-smoke slice**

```bash
git add tests/hir/test_hir_dynarray_release_runtime_smoke.pas build/verify_local.sh
git commit -m "test(compiler): add C6-H1 dynarray runtime smokes"
```

### Task 3: Implement the minimal C6-H1 dynarray lifecycle slice

**Files:**
- Modify: `compiler/ir/np_hir_types.pas`
- Modify: `compiler/sema/np_semantic_analyzer.pas`
- Modify: `compiler/ir/np_hir_builder.pas`
- Modify: `compiler/ir/np_hir_llvm_emitter.pas`
- Modify: `tests/hir/test_hir_node_kind.pas`
- Modify: `tests/hir/test_hir_dynarray_release_contract.pas`
- Modify: `tests/hir/test_hir_dynarray_release_runtime_smoke.pas`
- Modify: `build/verify_local.sh`

- [ ] **Step 1: Add the new HIR node kinds and keep the existing parser mapping exhaustive**

Update the enum and parser:

```pascal
// Insert `hnkVarDeclArrBorrowedRuntime` immediately after
// `hnkVarDeclArrRuntime`.
// Insert `hnkDynArrayCleanupRuntime` immediately after
// `hnkSetLengthArrRuntime`.

case AKind of
  'var-decl-arr-runtime': Result := hnkVarDeclArrRuntime;
  'var-decl-arr-borrowed-runtime': Result := hnkVarDeclArrBorrowedRuntime;
  'setlength-arr-runtime': Result := hnkSetLengthArrRuntime;
  'dynarray-cleanup-runtime': Result := hnkDynArrayCleanupRuntime;
```

- [ ] **Step 2: Make sema distinguish owned dynarray slots from borrowed params and emit explicit cleanup nodes on ordinary exits**

Extend the semantic analyzer state with borrowed tracking:

```pascal
FRuntimeBorrowedArrVarNames: array of string;
procedure RegisterBorrowedRuntimeArrVar(const AName: string);
function IsBorrowedRuntimeArrVar(const AName: string): Boolean;
function IsOwnedRuntimeArrVar(const AName: string): Boolean;
```

When seeding callable params, keep array metadata but switch the node kind:

```pascal
ArrayTypeNode := TypeChild;
if ((ArrayTypeNode = nil) or (ArrayTypeNode.NodeKind <> gnkArrayType)) and
  (K + 1 < Child.ChildCount) then
  ArrayTypeNode := Child.ChildAt(K + 1);
RegisterArrayVarMetadata(RetVarName, ArrayTypeNode, ArrOperand);
RegisterBorrowedRuntimeArrVar(RetVarName);
FModel.AddTypedHirNode('var-decl-arr-borrowed-runtime', RetVarName, 0, 0,
  ArrOperand);
```

Gate owned `SetLength` emission:

```pascal
if (RhsNode <> nil) and (RhsNode.NodeKind = gnkIdentifier) and
  IsOwnedRuntimeArrVar(RhsNode.Text) then
  FModel.AddTypedHirNode('setlength-arr-runtime', RhsNode.Text, 0, 0,
    RhsNode.Text + #9 + Operand + #9 + IntToStr(Value));
```

Emit cleanup nodes before every ordinary exit edge:

```pascal
procedure EmitOwnedDynarrayCleanupNodes(const AOwnedNames: array of string);
var
  I: LongInt;
  ElemSize: Int64;
begin
  for I := High(AOwnedNames) downto Low(AOwnedNames) do
    if FModel.LookupConstValue(AOwnedNames[I] + '$arr_elem_size', ElemSize) then
      FModel.AddTypedHirNode('dynarray-cleanup-runtime', AOwnedNames[I], 0, 0,
        AOwnedNames[I] + #9 + IntToStr(ElemSize));
end;
```

Use it before:
- explicit `Exit`
- implicit `ret-runtime` / `ret-str-runtime`
- runtime `Halt`
- synthetic final halt in `SeedHaltCalls`

Do not emit cleanup for borrowed params or field arrays.

- [ ] **Step 3: Teach the HIR builder how to lower borrowed dynarray slots, owned `SetLength`, and cleanup nodes**

Extend the alloca metadata instead of guessing from names:

```pascal
TAllocaEntry = record
  Name: string;
  Value: THIRValueId;
  TypeId: THIRTypeId;
  RecordSlots: LongInt;
  IsVarParam: Boolean;
  IsDynArraySlot: Boolean;
  IsBorrowedDynArray: Boolean;
end;
```

Add an index helper so the new flags can be set without duplicating linear scans:

```pascal
function THIRBuilder.FindAllocaIndex(const AName: string): LongInt;
var
  I: LongInt;
begin
  for I := FAllocaCount - 1 downto 0 do
    if FAllocas[I].Name = AName then
      Exit(I);
  Result := -1;
end;
```

Handle the borrowed declaration kind with the same `%ptr/%len` ABI, but mark the slot:

```pascal
else if ANode.NodeKind = hnkVarDeclArrBorrowedRuntime then
begin
  EnsureAlloca(ArrName + '$ptr', GetPtrType);
  EnsureAlloca(ArrName + '$len', GetIntType);
  PtrIndex := FindAllocaIndex(ArrName + '$ptr');
  LenIndex := FindAllocaIndex(ArrName + '$len');
  if PtrIndex >= 0 then
  begin
    FAllocas[PtrIndex].IsDynArraySlot := True;
    FAllocas[PtrIndex].IsBorrowedDynArray := True;
  end;
  if LenIndex >= 0 then
  begin
    FAllocas[LenIndex].IsDynArraySlot := True;
    FAllocas[LenIndex].IsBorrowedDynArray := True;
  end;
end;
```

Lower owned `SetLength` through old `%ptr/%len` loads and one resize helper call:

```pascal
OldPtr := EmitLoad(GetPtrType, FindAlloca(ArrName + '$ptr'));
OldLen := EmitLoad(GetIntType, FindAlloca(ArrName + '$len'));
EmitStore(GetIntType, SizeVal, FindAlloca(ArrName + '$len'));

FillChar(Instr, SizeOf(Instr), 0);
Instr.ResultId := FModule.NewValue;
Instr.Kind := hikIntrinsic;
Instr.TypeId := GetPtrType;
Instr.IntrinsicName := 'dynarray_resize';
SetLength(Instr.Operands, 4);
Instr.Operands[0] := MakeTypedOperand(OldPtr, GetPtrType);
Instr.Operands[1] := MakeTypedOperand(OldLen, GetIntType);
Instr.Operands[2] := MakeTypedOperand(SizeVal, GetIntType);
Instr.Operands[3] := MakeTypedOperand(ElemSizeVal, GetIntType);
EmitInstr(Instr);
EmitStore(GetPtrType, Instr.ResultId, FindAlloca(ArrName + '$ptr'));
```

Add cleanup lowering:

```pascal
procedure THIRBuilder.ProcessDynArrayCleanup(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
  NullPtr, ZeroInt: THIRValueId;
begin
  PtrVal := EmitLoad(GetPtrType, FindAlloca(VarName + '$ptr'));
  LenVal := EmitLoad(GetIntType, FindAlloca(VarName + '$len'));
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'dynarray_release';
  SetLength(Instr.Operands, 3);
  Instr.Operands[0] := MakeTypedOperand(PtrVal, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(LenVal, GetIntType);
  Instr.Operands[2] := MakeTypedOperand(ElemSizeVal, GetIntType);
  EmitInstr(Instr);
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'null';
  EmitInstr(Instr);
  NullPtr := Instr.ResultId;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:0';
  EmitInstr(Instr);
  ZeroInt := Instr.ResultId;
  EmitStore(GetPtrType, NullPtr, FindAlloca(VarName + '$ptr'));
  EmitStore(GetIntType, ZeroInt, FindAlloca(VarName + '$len'));
end;
```

Keep `__field_setlength__` on the current `arr_alloc` path.

- [ ] **Step 4: Teach the LLVM emitter to emit dynarray resize/release/fault helpers and the new helper calls**

Add new emitter flags:

```pascal
FNeedsMemcpy: Boolean;
FNeedsDynArrayResize: Boolean;
FNeedsDynArrayRelease: Boolean;
```

Emit `@np_memcpy` from its own dependency bit, not by piggybacking on string
concat. The updated helper-emission rule should be:

```pascal
if FNeedsMemcpy then
  EmitMemcpyHelper;
if FNeedsStrConcat or FNeedsIntToStr then
  EmitStrConcatHelper;
```

Map the new intrinsics:

```pascal
else if AInstr.IntrinsicName = 'dynarray_resize' then
begin
  FNeedsAlloc := True;
  FNeedsMemcpy := True;
  FNeedsDynArrayResize := True;
  Emit('  ' + ValueRef(AInstr.ResultId) +
    ' = call ptr @np_dynarray_resize(ptr ' + ValueRef(AInstr.Operands[0].ValueId) +
    ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) +
    ', i64 ' + ValueRef(AInstr.Operands[2].ValueId) +
    ', i64 ' + ValueRef(AInstr.Operands[3].ValueId) + ')');
end
else if AInstr.IntrinsicName = 'dynarray_release' then
begin
  FNeedsDynArrayRelease := True;
  Emit('  call void @np_dynarray_release(ptr ' + ValueRef(AInstr.Operands[0].ValueId) +
    ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) +
    ', i64 ' + ValueRef(AInstr.Operands[2].ValueId) + ')');
end;
```

Emit helper bodies with explicit overflow/fault checks:

```llvm
define internal ptr @np_dynarray_resize(ptr %old_ptr, i64 %old_len, i64 %new_len, i64 %elem_size) {
entry:
  %old.bytes = mul i64 %old_len, %elem_size
  %old.bytes.div = udiv i64 %old.bytes, %elem_size
  %old.bytes.ok = icmp eq i64 %old.bytes.div, %old_len
  br i1 %old.bytes.ok, label %resize.new.bytes, label %fault.old.bytes
fault.old.bytes:
  call void @np_dynarray_fault(i64 1, i64 %old_len, i64 %elem_size)
  unreachable
resize.new.bytes:
  %new.bytes = mul i64 %new_len, %elem_size
  %new.bytes.div = udiv i64 %new.bytes, %elem_size
  %new.bytes.ok = icmp eq i64 %new.bytes.div, %new_len
  br i1 %new.bytes.ok, label %resize.dispatch, label %fault.new.bytes
fault.new.bytes:
  call void @np_dynarray_fault(i64 2, i64 %new_len, i64 %elem_size)
  unreachable
resize.dispatch:
  %new.zero = icmp eq i64 %new_len, 0
  %old.zero = icmp eq i64 %old_len, 0
  br i1 %new.zero, label %resize.free-old, label %resize.alloc-or-copy
resize.free-old:
  call void @np_dynarray_release(ptr %old_ptr, i64 %old_len, i64 %elem_size)
  ret ptr null
resize.alloc-or-copy:
  %new.ptr = call ptr @np_alloc(i64 %new.bytes)
  br i1 %old.zero, label %resize.done.alloc, label %resize.copy
resize.copy:
  %old.le.new = icmp ule i64 %old_len, %new_len
  %copy.len = select i1 %old.le.new, i64 %old_len, i64 %new_len
  %copy.bytes = mul i64 %copy.len, %elem_size
  %copy.bytes.div = udiv i64 %copy.bytes, %elem_size
  %copy.bytes.ok = icmp eq i64 %copy.bytes.div, %copy.len
  br i1 %copy.bytes.ok, label %resize.alloc, label %fault.copy.bytes
fault.copy.bytes:
  call void @np_dynarray_fault(i64 3, i64 %copy.len, i64 %elem_size)
  unreachable
resize.alloc:
  call void @np_memcpy(ptr %new.ptr, ptr %old_ptr, i64 %copy.bytes)
  call void @np_free(ptr %old_ptr, i64 %old.bytes)
resize.done.alloc:
  ret ptr %new.ptr
}

define internal void @np_dynarray_release(ptr %ptr, i64 %len, i64 %elem_size) {
entry:
  %is.null = icmp eq ptr %ptr, null
  %is.zero = icmp eq i64 %len, 0
  %null.xor.zero = xor i1 %is.null, %is.zero
  br i1 %null.xor.zero, label %fault.invalid.state, label %release.dispatch
fault.invalid.state:
  call void @np_dynarray_fault(i64 4, i64 %len, i64 %elem_size)
  unreachable
release.dispatch:
  br i1 %is.zero, label %done, label %release.bytes
release.bytes:
  %bytes = mul i64 %len, %elem_size
  %bytes.div = udiv i64 %bytes, %elem_size
  %bytes.ok = icmp eq i64 %bytes.div, %len
  br i1 %bytes.ok, label %release.free, label %fault.release.bytes
fault.release.bytes:
  call void @np_dynarray_fault(i64 2, i64 %len, i64 %elem_size)
  unreachable
release.free:
  call void @np_free(ptr %ptr, i64 %bytes)
done:
  ret void
}

define internal void @np_dynarray_fault(i64 %code, i64 %arg0, i64 %arg1) {
entry:
  call void @llvm.trap()
  unreachable
}
```

Keep `@np_alloc`, `@np_free`, `@np_object_alloc`, `@np_object_free_release`, and `@np_str_concat` behavior unchanged except for the new dynarray helper callers.
`@np_memcpy` becomes a shared low-level helper with an explicit emitter
dependency bit; it is not part of the string-ownership surface.

- [ ] **Step 5: Run the focused contracts and runtime smokes until GREEN**

Run:

```bash
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h1-node-kind-green -FUbuild/.tmp/c6h1-node-kind-green tests/hir/test_hir_node_kind.pas && build/.tmp/c6h1-node-kind-green/test_hir_node_kind
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h1-dynarray-contract-green -FUbuild/.tmp/c6h1-dynarray-contract-green tests/hir/test_hir_dynarray_release_contract.pas && build/.tmp/c6h1-dynarray-contract-green/test_hir_dynarray_release_contract
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h1-dynarray-runtime-green -FUbuild/.tmp/c6h1-dynarray-runtime-green tests/hir/test_hir_dynarray_release_runtime_smoke.pas && build/.tmp/c6h1-dynarray-runtime-green/test_hir_dynarray_release_runtime_smoke
```

Do not move on until all three pass with fresh rebuilds.

- [ ] **Step 6: Commit the implementation slice**

```bash
git add compiler/ir/np_hir_types.pas compiler/sema/np_semantic_analyzer.pas compiler/ir/np_hir_builder.pas compiler/ir/np_hir_llvm_emitter.pas tests/hir/test_hir_node_kind.pas tests/hir/test_hir_dynarray_release_contract.pas tests/hir/test_hir_dynarray_release_runtime_smoke.pas build/verify_local.sh
git commit -m "fix(compiler): implement C6-H1 dynarray release slice"
```

### Task 4: Close out C6-H1

**Files:**
- Modify: `docs/superpowers/specs/2026-06-07-compiler-c6h-dynarray-release-first-slice-design.md` (only if verification forces a spec correction)
- Modify: `docs/superpowers/plans/2026-06-07-compiler-c6h-dynarray-release-first-slice-implementation.md` (checkbox status only if this plan is used as the execution ledger)

- [ ] **Step 1: Run the full verification envelope**

Run:

```bash
git diff --check
make hygiene
./build/verify_local.sh
```

The runtime semantics changed. `./build/verify_local.sh` is mandatory before reporting Ready.

- [ ] **Step 2: Re-check scope, dirty state, and package boundaries**

Run:

```bash
git status --short --branch
git log --oneline --decorate -n 3
```

Expected touched files should stay limited to:
- `compiler/ir/np_hir_types.pas`
- `compiler/sema/np_semantic_analyzer.pas`
- `compiler/ir/np_hir_builder.pas`
- `compiler/ir/np_hir_llvm_emitter.pas`
- `tests/hir/test_hir_node_kind.pas`
- `tests/hir/test_hir_dynarray_release_contract.pas`
- `tests/hir/test_hir_dynarray_release_runtime_smoke.pas`
- `build/verify_local.sh`
- the already-approved spec/plan docs if they were updated intentionally

- [ ] **Step 3: Prepare the Ready report only after every focused/runtime/full gate passes**

The report must include:
- branch/worktree/HEAD
- current roadmap position: `C6 -> C6-H1 dynarray release first slice`
- preserved/non-goals confirmation:
  - string lowering untouched
  - field dynarray path preserved
  - borrowed params remain non-owning
  - no unwind cleanup
- focused test evidence
- runtime smoke evidence
- `git diff --check`, `make hygiene`, `./build/verify_local.sh` evidence

- [ ] **Step 4: Do not start C6-H2 or C6-H3 in this execution batch**

Stop after C6-H1 Ready. Field dynarray release, string ownership, array return ownership, and unwind cleanup require a new approved spec.
