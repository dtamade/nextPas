procedure THIRLlvmEmitter.EmitWriteIntHelper;
begin
  // Phase 4: write_i64_decimal 已移至 nextpas.runtime.strings.ll
  // Batch 29: second arg is fd (1=stdout, 2=stderr).
  Emit('');
  Emit('declare void @write_i64_decimal(i64 %v, i64 %fd)');
end;

function THIRLlvmEmitter.AddStrConstant(const AValue: string): LongInt;
begin
  Result := LongInt(FStrConstants.Count);
  FStrConstants.Push(AValue);
end;

function THIRLlvmEmitter.EscapeLlvmStr(const AValue: string): string;
begin
  Result := nextpas.core.text.conv.EscapeLlvmStr(AValue);
end;

function THIRLlvmEmitter.LlvmGlobalName(const AName: string): string;
var
  I: LongInt;
  C: Char;
  NeedsQuote: Boolean;
begin
  { LLVM bare global: [A-Za-z_.][A-Za-z0-9_$.]* — operators like := need quotes. }
  if AName = '' then
    Exit('""');
  if (Length(AName) >= 2) and (AName[1] = '"') and
    (AName[Length(AName)] = '"') then
    Exit(AName);

  NeedsQuote := False;
  C := AName[1];
  if not (((C >= 'A') and (C <= 'Z')) or ((C >= 'a') and (C <= 'z')) or
    (C = '_') or (C = '.')) then
    NeedsQuote := True
  else
    for I := 2 to Length(AName) do
    begin
      C := AName[I];
      if not (((C >= 'A') and (C <= 'Z')) or ((C >= 'a') and (C <= 'z')) or
        ((C >= '0') and (C <= '9')) or (C = '_') or (C = '.') or (C = '$')) then
      begin
        NeedsQuote := True;
        Break;
      end;
    end;

  if NeedsQuote then
    Result := '"' + EscapeLlvmStr(AName) + '"'
  else
    Result := AName;
end;

function THIRLlvmEmitter.LlvmGlobalRef(const AName: string): string;
begin
  Result := '@' + LlvmGlobalName(AName);
end;

procedure THIRLlvmEmitter.EmitStrConstants;
var
  I: SizeUInt;
  Len: LongInt;
begin
  if FStrConstants.Count = 0 then
    Exit;
  for I := 0 to FStrConstants.Count - 1 do
  begin
    Len := Length(FStrConstants[I]);
    Emit('@.str.' + IntToStr(I) + ' = private constant [' + IntToStr(Len) +
      ' x i8] c"' + EscapeLlvmStr(FStrConstants[I]) + '"');
  end;
end;

// ---------------------------------------------------------------------------
// BOOTSTRAP-TEMPORARY: Inline runtime helpers
//
// The following procedures emit inline LLVM IR for allocator, memory, and
// object lifecycle operations.  This is a BOOTSTRAP TEMPORARY — every
// compiled binary carries its own copy of these ~300 lines of IR.
//
// Gate 4 roadmap (docs/plans/2026-06-18-debt-roadmap.md):
//   Phase 1 (done): mark as bootstrap-temporary
//   Phase 2 (pending): create runtime.allocator Pascal module with C ABI
//   Phase 3 (pending): replace `define internal` with `declare external`
//
// Once Phase 3 is complete, these emit helpers become no-ops and the runtime
// module provides the single canonical implementation.
// ---------------------------------------------------------------------------

procedure THIRLlvmEmitter.EmitAllocHelper;
begin
  // Phase 3: allocator 已移至 libnprt.a runtime 模块，只 emit 外部声明
  Emit('');
  Emit('declare ptr @np_alloc(i64 %size)');
  Emit('declare void @np_free(ptr %raw, i64 %size)');
  Emit('declare ptr @np_realloc(ptr %raw, i64 %old_size, i64 %new_size)');
  Emit('declare void @np_allocator_fault(i64 %code, i64 %arg0, i64 %arg1)');
end;

procedure THIRLlvmEmitter.EmitMemcpyHelper;
begin
  // Phase 3: memops 已移至 libnprt.a runtime 模块
  Emit('');
  Emit('declare void @np_memcpy(ptr %dst, ptr %src, i64 %n)');
  Emit('declare void @np_memmove(ptr %dst, ptr %src, i64 %n)');
  Emit('declare void @np_memset(ptr %dst, i8 %val, i64 %n)');
  Emit('declare void @np_memzero(ptr %dst, i64 %n)');
end;

procedure THIRLlvmEmitter.EmitMemzeroHelper;
begin
  // Phase 3: memzero 声明已在 EmitMemcpyHelper 中 emit
end;

procedure THIRLlvmEmitter.EmitStrConcatHelper;
begin
  // Phase 4: np_str_concat 已移至 nextpas.runtime.strings.ll
  Emit('');
  Emit('declare {ptr, i64} @np_str_concat(ptr %a_ptr, i64 %a_len, ptr %b_ptr, i64 %b_len)');
end;

procedure THIRLlvmEmitter.EmitStringOwnershipHelpers;
begin
  // Phase 4: 字符串 helper 已移至 nextpas.runtime.strings.ll
  Emit('');
  Emit('declare void @np_string_fault(i64 %code, i64 %arg0, i64 %arg1)');
  Emit('declare void @np_string_release(ptr %owner, i64 %alloc_size)');
end;

procedure THIRLlvmEmitter.EmitTStringHelpers;
begin
  { TString 24B runtime — all functions operate on ptr to 24-byte record }
  Emit('');
  Emit('declare void @np_tstring_init(ptr %s)');
  Emit('declare void @np_tstring_fini(ptr %s)');
  Emit('declare void @np_tstring_assign(ptr %dst, ptr %src)');
  Emit('declare void @np_tstring_move(ptr %dst, ptr %src)');
  Emit('declare i64 @np_tstring_len(ptr %s)');
  Emit('declare ptr @np_tstring_data(ptr %s)');
  Emit('declare i8 @np_tstring_is_sso(ptr %s)');
  Emit('declare void @np_tstring_create(ptr %dst, ptr %data, i64 %len)');
  Emit('declare void @np_tstring_from_literal(ptr %dst, ptr %lit, i64 %len)');
  Emit('declare void @np_tstring_concat(ptr %dst, ptr %a, ptr %b)');
  Emit('declare void @np_tstring_copy(ptr %dst, ptr %src, i64 %start, i64 %count)');
  Emit('declare void @np_tstring_from_int(ptr %dst, i64 %val)');
  Emit('declare i64 @np_tstring_equal(ptr %a, ptr %b)');
  Emit('declare i64 @np_tstring_compare(ptr %a, ptr %b)');
  Emit('declare void @np_tstring_field_assign(ptr %dst, ptr %src)');
  Emit('declare void @np_tstring_field_fini(ptr %s)');
  Emit('declare void @np_tstring_ret_move(ptr %sret_dst, ptr %src)');
  Emit('declare void @np_tstring_ret_copy(ptr %sret_dst, ptr %src)');
end;

procedure THIRLlvmEmitter.EmitDynArrayHelpers;
begin
  // Phase 4: 动态数组 helper 已移至 nextpas.runtime.dynarray.ll
  Emit('');
  Emit('declare void @np_dynarray_fault(i64 %code, i64 %arg0, i64 %arg1)');
  Emit('declare void @np_dynarray_release(ptr %ptr, i64 %len, i64 %elem_size)');
  Emit('declare ptr @np_dynarray_resize(ptr %old_ptr, i64 %old_len, i64 %new_len, i64 %elem_size)');
end;

procedure THIRLlvmEmitter.EmitObjectAllocHelper;
begin
  // Phase 3: object alloc 已移至 libnprt.a runtime 模块
  Emit('');
  Emit('declare ptr @np_object_alloc(i64 %size)');
end;

procedure THIRLlvmEmitter.EmitObjectFreeReleaseHelper;
begin
  // Phase 3: object free 已移至 libnprt.a runtime 模块
  Emit('');
  Emit('declare void @np_object_free_release(ptr %obj)');
end;

procedure THIRLlvmEmitter.EmitObjectReleaseValidHelper;
begin
  // Phase 3: 已移至 libnprt.a runtime 模块（内部函数，不需要外部声明）
end;

procedure THIRLlvmEmitter.EmitFreeHelper;
begin
  // Phase 3: np_free 声明已在 EmitAllocHelper 中 emit
end;

procedure THIRLlvmEmitter.EmitObjectReleaseInvalidHelper;
begin
  // Phase 3: 已移至 libnprt.a runtime 模块（内部函数，不需要外部声明）
end;

procedure THIRLlvmEmitter.EmitAllocatorFaultHelper;
begin
  // Phase 3: allocator fault 已移至 libnprt.a runtime 模块
  // np_allocator_fault 声明已在 EmitAllocHelper 中 emit
  // llvm.trap 声明保留（其他 helpers 也需要）
  Emit('');
  Emit('declare void @llvm.trap()');
  { System Bsf*/Bsr* lower to these; declare once with trap helpers. }
  Emit('declare i64 @llvm.cttz.i64(i64, i1)');
  Emit('declare i64 @llvm.ctlz.i64(i64, i1)');
end;

procedure THIRLlvmEmitter.EmitIntfRefCountHelpers;
begin
  // Phase 3: intf refcount 已移至 libnprt.a runtime 模块
  Emit('');
  Emit('declare void @np_intf_addref(ptr %obj)');
  Emit('declare void @np_intf_release(ptr %obj)');
end;

procedure THIRLlvmEmitter.EmitExceptionRuntimeHelpers;
begin
  // Phase 4: 异常 runtime 已移至 nextpas.runtime.exceptions.ll
  // globals 和 helper 函数通过 libnprt.a 外部链接
  Emit('');
  Emit('; --- Exception runtime (external from libnprt.a) ---');
  Emit('@__np_exc_stack = external global ptr');
  Emit('@__np_exc_pending = external global i1');
  Emit('@__np_exc_object = external global ptr');
  Emit('');
  Emit('declare void @np_try_push(ptr %buf)');
  Emit('declare void @np_try_pop()');
  Emit('declare void @np_raise()');
  Emit('declare void @np_finally_end()');
  Emit('declare void @np_except_end()');
  Emit('');

  // setjmp/longjmp 实现必须内联在用户程序中（module-level asm）
  // runtime .ll 通过 declare @longjmp 引用，链接时解析
  Emit('; freestanding setjmp/longjmp via module-level asm');
  Emit('module asm ".globl setjmp"');
  Emit('module asm ".type setjmp, @function"');
  Emit('module asm "setjmp:"');
  Emit('module asm "  movq %rbx, (%rdi)"');
  Emit('module asm "  movq %rbp, 8(%rdi)"');
  Emit('module asm "  movq %r12, 16(%rdi)"');
  Emit('module asm "  movq %r13, 24(%rdi)"');
  Emit('module asm "  movq %r14, 32(%rdi)"');
  Emit('module asm "  movq %r15, 40(%rdi)"');
  Emit('module asm "  leaq 8(%rsp), %rax"');
  Emit('module asm "  movq %rax, 48(%rdi)"');
  Emit('module asm "  movq (%rsp), %rax"');
  Emit('module asm "  movq %rax, 56(%rdi)"');
  Emit('module asm "  xorl %eax, %eax"');
  Emit('module asm "  ret"');
  Emit('module asm ""');
  Emit('module asm ".globl longjmp"');
  Emit('module asm ".type longjmp, @function"');
  Emit('module asm "longjmp:"');
  Emit('module asm "  movq (%rdi), %rbx"');
  Emit('module asm "  movq 8(%rdi), %rbp"');
  Emit('module asm "  movq 16(%rdi), %r12"');
  Emit('module asm "  movq 24(%rdi), %r13"');
  Emit('module asm "  movq 32(%rdi), %r14"');
  Emit('module asm "  movq 40(%rdi), %r15"');
  Emit('module asm "  movq 48(%rdi), %rsp"');
  Emit('module asm "  movl %esi, %eax"');
  Emit('module asm "  testl %eax, %eax"');
  Emit('module asm "  jnz 1f"');
  Emit('module asm "  incl %eax"');
  Emit('module asm "  1: jmpq *56(%rdi)"');
  Emit('');
  Emit('declare i32 @setjmp(ptr) returns_twice nounwind');
  Emit('declare void @longjmp(ptr, i32) noreturn nounwind');
end;

procedure THIRLlvmEmitter.EmitVmtGlobals;
var
  I, J: LongInt;
  Vmt: THIRVmtGlobal;
  Line: string;
  FuncCount: LongInt;
begin
  for I := 0 to FModule.VmtGlobalCount - 1 do
  begin
    Vmt := FModule.VmtGlobalAt(I);
    if (Vmt.Funcs = nil) or (Vmt.Funcs.Count = 0) then Continue;
    FuncCount := LongInt(Vmt.Funcs.Count);
    { Generic template class names carry '<T>' — must go through the same
      quoting as reference sites or opt rejects the bare global (M2 B6.5). }
    Line := LlvmGlobalRef(Vmt.ClassName + '.vmt') + ' = internal constant [' +
      IntToStr(FuncCount) + ' x ptr] [';
    for J := 0 to FuncCount - 1 do
    begin
      if J > 0 then Line := Line + ', ';
      if Vmt.Funcs[SizeUInt(J)] = '' then
        Line := Line + 'ptr null'
      else
        Line := Line + 'ptr ' + LlvmGlobalRef(Vmt.Funcs[SizeUInt(J)]);
    end;
    Line := Line + ']';
    Emit('');
    Emit(Line);
  end;
end;

procedure THIRLlvmEmitter.EmitImtGlobals;
var
  I, J, K: LongInt;
  Imt: THIRImtGlobal;
  Line, RealFunc, ThunkName, ParamStr, CallArgs: string;
  OffsetBytes, ParamCount, ThunkCount: LongInt;
  UnderscorePos: LongInt;
begin
  for I := 0 to FModule.ImtGlobalCount - 1 do
  begin
    Imt := FModule.ImtGlobalAt(I);
    if (Imt.ThunkNames = nil) or (Imt.ThunkNames.Count = 0) then Continue;
    ThunkCount := LongInt(Imt.ThunkNames.Count);

    Line := LlvmGlobalRef(Imt.ClassName + '.imt.' + Imt.InterfaceName) +
      ' = internal constant [' + IntToStr(ThunkCount) + ' x ptr] [';
    for J := 0 to ThunkCount - 1 do
    begin
      if J > 0 then Line := Line + ', ';
      if Imt.ThunkNames[SizeUInt(J)] = '' then
        Line := Line + 'ptr null'
      else
        Line := Line + 'ptr ' + LlvmGlobalRef(Imt.ThunkNames[SizeUInt(J)]);
    end;
    Line := Line + ']';
    Emit('');
    Emit(Line);

    OffsetBytes := Imt.SlotOffset * 8;
    for J := 0 to ThunkCount - 1 do
    begin
      ThunkName := Imt.ThunkNames[SizeUInt(J)];
      if ThunkName = '' then Continue;
      UnderscorePos := Pos('._intf_thunk_', ThunkName);
      if UnderscorePos > 0 then
        RealFunc := Copy(ThunkName, 1, UnderscorePos - 1) + '.' +
          Copy(ThunkName, Pos('_' + Imt.InterfaceName + '_', ThunkName) +
            Length(Imt.InterfaceName) + 2, MaxInt)
      else
        RealFunc := ThunkName;
      ParamCount := 0;
      if (Imt.ThunkParamCounts <> nil) and
        (J < LongInt(Imt.ThunkParamCounts.Count)) then
        ParamCount := Imt.ThunkParamCounts[SizeUInt(J)];
      ParamStr := 'ptr %intf_self';
      CallArgs := 'ptr %obj';
      for K := 0 to ParamCount - 1 do
      begin
        ParamStr := ParamStr + ', i64 %a' + IntToStr(K);
        CallArgs := CallArgs + ', i64 %a' + IntToStr(K);
      end;
      Emit('');
      Emit('define internal i64 ' + LlvmGlobalRef(ThunkName) + '(' + ParamStr + ') {');
      Emit('entry:');
      Emit('  %obj = getelementptr i8, ptr %intf_self, i64 -' + IntToStr(OffsetBytes));
      Emit('  %r = tail call i64 ' + LlvmGlobalRef(RealFunc) + '(' + CallArgs + ')');
      Emit('  ret i64 %r');
      Emit('}');
    end;
  end;
end;

function THIRLlvmEmitter.AsText: string;
var
  I: SizeUInt;
begin
  Result := '';
  if FLines.Count > 0 then
    for I := 0 to FLines.Count - 1 do
      Result := Result + FLines[I] + LineEnding;
end;

procedure THIRLlvmEmitter.SaveToFile(const APath: string);
var
  F: TextFile;
  I: SizeUInt;
begin
  AssignFile(F, APath);
  Rewrite(F);
  if FLines.Count > 0 then
    for I := 0 to FLines.Count - 1 do
      WriteLn(F, FLines[I]);
  CloseFile(F);
end;
