# Try/Except/Finally Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable nextPas to compile programs with exception handling (try/except/finally/raise).

**Architecture:** Sema generates new HIR node kinds (try-begin, try-end, except-handler, finally-block, raise) via `LowerRuntimeTryExceptStatement` and `LowerRuntimeTryFinallyStatement`. HIR Builder converts these to LLVM `invoke`/`landingpad`/`resume` instructions. For Phase 1, we use setjmp/longjmp-based exception handling (simpler than LLVM personality functions, matches FPC's approach).

**Tech Stack:** Pascal (compiler), LLVM IR (output), setjmp/longjmp (runtime)

---

## Phase 1: try/finally (simpler — no exception type matching)

### Task 1: Add HIR Node Kinds for Exception Handling

**Files:**
- Modify: `compiler/ir/np_hir_types.pas:34-76` (THirNodeKind enum)
- Modify: `compiler/ir/np_hir_types.pas:147` (ParseHirNodeKind)

**Step 1: Add new enum values before hnkUnknown**

```pascal
hnkTryBeginRuntime,
hnkTryEndRuntime,
hnkFinallyBeginRuntime,
hnkFinallyEndRuntime,
hnkExceptBeginRuntime,
hnkExceptEndRuntime,
hnkRaiseRuntime,
hnkUnknown
```

**Step 2: Add ParseHirNodeKind cases**

```pascal
'try-begin-runtime': Result := hnkTryBeginRuntime;
'try-end-runtime': Result := hnkTryEndRuntime;
'finally-begin-runtime': Result := hnkFinallyBeginRuntime;
'finally-end-runtime': Result := hnkFinallyEndRuntime;
'except-begin-runtime': Result := hnkExceptBeginRuntime;
'except-end-runtime': Result := hnkExceptEndRuntime;
'raise-runtime': Result := hnkRaiseRuntime;
```

**Step 3: Compile**

Run: `fpc -Fucompiler/syntax -Fucompiler/diagnostics -Fucompiler/frontend -Furtl/core/base -Furtl/core/text compiler/ir/np_hir_types.pas`
Expected: compiles clean

**Step 4: Commit**

```bash
git add compiler/ir/np_hir_types.pas
git commit -m "feat(hir): add exception handling node kinds"
```

---

### Task 2: Sema — LowerRuntimeTryFinallyStatement

**Files:**
- Modify: `compiler/sema/np_semantic_analyzer.pas` (add procedure declaration + implementation)

**Step 1: Add procedure declaration (after LowerRuntimeCaseStatement)**

```pascal
procedure LowerRuntimeTryFinallyStatement(const ANode: TGreenNode);
```

**Step 2: Add dispatch in WalkHaltCalls**

In `WalkHaltCalls`, before the default recursive handling, add:

```pascal
if Child.NodeKind = gnkTryFinallyStatement then
begin
  LowerRuntimeTryFinallyStatement(Child);
  Continue;
end;
```

**Step 3: Implement LowerRuntimeTryFinallyStatement**

The AST structure for `try...finally...end` is:
- Child[0]: statement-list (try body)
- Child[1]: statement-list (finally body)

Generate HIR:
```pascal
procedure TSemanticAnalyzer.LowerRuntimeTryFinallyStatement(const ANode: TGreenNode);
var
  TryBody, FinallyBody: TGreenNode;
  FinallyLabel, EndLabel: string;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then Exit;
  TryBody := ANode.ChildAt(0);
  FinallyBody := ANode.ChildAt(1);
  FinallyLabel := NewBlockLabel('finally');
  EndLabel := NewBlockLabel('endtry');

  FModel.AddTypedHirNode('try-begin-runtime', 'finally', 0, 0,
    FinallyLabel + #10);
  WalkHaltCalls(TryBody);
  FModel.AddTypedHirNode('try-end-runtime', 'finally', 0, 0, '');

  EmitBlockLabel(FinallyLabel);
  FModel.AddTypedHirNode('finally-begin-runtime', '', 0, 0, '');
  WalkHaltCalls(FinallyBody);
  FModel.AddTypedHirNode('finally-end-runtime', '', 0, 0, '');

  EmitBlockLabel(EndLabel);
end;
```

**Step 4: Compile and run pipeline**

Run: `fpc ... tests/hir/*.pas && run all`
Expected: 29/29 PASS (new nodes are generated but not yet consumed by HIR builder)

**Step 5: Commit**

```bash
git add compiler/sema/np_semantic_analyzer.pas
git commit -m "feat(sema): lower try/finally to HIR nodes"
```

---

### Task 3: Sema — LowerRuntimeTryExceptStatement

**Files:**
- Modify: `compiler/sema/np_semantic_analyzer.pas`

**Step 1: Add procedure declaration**

```pascal
procedure LowerRuntimeTryExceptStatement(const ANode: TGreenNode);
```

**Step 2: Add dispatch in WalkHaltCalls**

```pascal
if Child.NodeKind = gnkTryExceptStatement then
begin
  LowerRuntimeTryExceptStatement(Child);
  Continue;
end;
```

**Step 3: Implement**

AST structure for `try...except...end`:
- Child[0]: statement-list (try body)
- Child[1..N]: except handlers (on E: Type do ...) or default handler

```pascal
procedure TSemanticAnalyzer.LowerRuntimeTryExceptStatement(const ANode: TGreenNode);
var
  TryBody, HandlerBody: TGreenNode;
  ExceptLabel, EndLabel: string;
  I: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then Exit;
  TryBody := ANode.ChildAt(0);
  ExceptLabel := NewBlockLabel('except');
  EndLabel := NewBlockLabel('endtry');

  FModel.AddTypedHirNode('try-begin-runtime', 'except', 0, 0,
    ExceptLabel + #10);
  WalkHaltCalls(TryBody);
  FModel.AddTypedHirNode('try-end-runtime', 'except', 0, 0, '');
  EmitGotoLabel(EndLabel);

  EmitBlockLabel(ExceptLabel);
  FModel.AddTypedHirNode('except-begin-runtime', '', 0, 0, '');
  for I := 1 to ANode.ChildCount - 1 do
  begin
    HandlerBody := ANode.ChildAt(I);
    if HandlerBody <> nil then
      WalkHaltCalls(HandlerBody);
  end;
  FModel.AddTypedHirNode('except-end-runtime', '', 0, 0, '');

  EmitBlockLabel(EndLabel);
end;
```

**Step 4: Compile and run pipeline**

Expected: 29/29 PASS

**Step 5: Commit**

```bash
git add compiler/sema/np_semantic_analyzer.pas
git commit -m "feat(sema): lower try/except to HIR nodes"
```

---

### Task 4: HIR Builder — Process Exception Nodes

**Files:**
- Modify: `compiler/ir/np_hir_builder.pas` (ProcessNode dispatch + new handlers)

**Step 1: Add ProcessNode dispatch cases**

In `ProcessNode`'s case statement, add:

```pascal
hnkTryBeginRuntime: ProcessTryBegin(ANode);
hnkTryEndRuntime: ProcessTryEnd(ANode);
hnkFinallyBeginRuntime: ProcessFinallyBegin(ANode);
hnkFinallyEndRuntime: ProcessFinallyEnd(ANode);
hnkExceptBeginRuntime: ProcessExceptBegin(ANode);
hnkExceptEndRuntime: ProcessExceptEnd(ANode);
```

**Step 2: Implement handlers (Phase 1 — setjmp/longjmp)**

For Phase 1, try/finally generates:
- `try-begin`: call `@np_try_push` (pushes jmp_buf onto exception stack)
- `try-end`: call `@np_try_pop` (pops jmp_buf, normal exit)
- `finally-begin`: entry point for finally block (reached via longjmp or normal flow)
- `finally-end`: call `@np_finally_end` (re-raises if exception pending)

```pascal
procedure THIRBuilder.ProcessTryBegin(const ANode: TTypedHirNode);
begin
  // For now, emit as a marker — LLVM emitter will handle
  EmitInstr(MakeInstr(hnkTryBeginRuntime, ANode.Operand));
end;
```

**Step 3: Compile and run pipeline**

Expected: 29/29 PASS

**Step 4: Commit**

```bash
git add compiler/ir/np_hir_builder.pas
git commit -m "feat(hir-builder): dispatch exception HIR nodes"
```

---

### Task 5: LLVM Emitter — setjmp/longjmp Exception Runtime

**Files:**
- Modify: `compiler/ir/np_hir_llvm_emitter.pas`

**Step 1: Add runtime function declarations**

```llvm
declare i32 @setjmp(ptr)
declare void @longjmp(ptr, i32)
@np_exception_stack = external global ptr
```

**Step 2: Emit try-begin as setjmp**

```llvm
; try-begin
%jmpbuf = alloca [64 x i8]
%setjmp_result = call i32 @setjmp(ptr %jmpbuf)
%is_exception = icmp ne i32 %setjmp_result, 0
br i1 %is_exception, label %except_or_finally, label %try_body
```

**Step 3: Emit try-end as normal flow to finally/end**

**Step 4: Emit finally-begin/end**

**Step 5: Write end-to-end test**

Create `examples/smoke/llvm_try_finally.pas`:
```pascal
program llvm_try_finally;
begin
  try
    WriteLn('try');
  finally
    WriteLn('finally');
  end;
  WriteLn('done');
end.
```

Expected output: `try\nfinally\ndone`

**Step 6: Commit**

```bash
git add compiler/ir/np_hir_llvm_emitter.pas examples/smoke/llvm_try_finally.pas
git commit -m "feat(llvm): try/finally via setjmp/longjmp"
```

---

### Task 6: End-to-End Test — try/except

**Files:**
- Create: `examples/smoke/llvm_try_except.pas`

```pascal
program llvm_try_except;
begin
  try
    WriteLn('before raise');
    raise Exception.Create('oops');
    WriteLn('unreachable');
  except
    WriteLn('caught');
  end;
  WriteLn('after');
end.
```

Expected output: `before raise\ncaught\nafter`

---

## Phase 2 (future): Typed exception handlers, re-raise, nested try

- `on E: ESpecific do` — type-based dispatch
- `raise` without argument (re-raise)
- Nested try/except/finally
- Exception object lifetime (Create/Free)

---

## Key Design Decisions

1. **setjmp/longjmp over LLVM personality functions** — simpler, matches FPC's approach, portable. Can upgrade to personality functions later for better optimization.

2. **Runtime library functions** — `np_try_push`, `np_try_pop`, `np_raise`, `np_finally_end` will be implemented as LLVM IR helpers emitted by the emitter (like `np_alloc`).

3. **Exception stack** — thread-local linked list of jmp_buf frames. Each `try` pushes, each `end` pops.
