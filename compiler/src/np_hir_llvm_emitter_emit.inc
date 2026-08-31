procedure THIRLlvmEmitter.EmitTerminator(const ATerm: THIRTerminator);
var
  I: LongInt;
  RetTy: string;
  T: THIRTypeRec;
begin
  ClosePendingObjectFreeGuard;
  case ATerm.Kind of
    htkReturn:
      begin
        { Exit-inside-try paths skip the structured hikTryEnd; unwind the
          frames so @__np_exc_stack never keeps dangling buffers. The
          except-handler path needs this too — longjmp consumed nothing. }
        EmitTryFramePops;
        if ATerm.ReturnValue = 0 then
        Emit('  ret void')
      else begin
        T := FModule.Types.GetType(FCurrentReturnTypeId);
        if T.Kind = htkString then
          RetTy := '{ptr, i64}'
        else
          RetTy := TypeToLlvm(FCurrentReturnTypeId);
        if RetTy = '' then
          RetTy := 'i64';
        { Object/class returns are often SSA-typed as ptr while func ABI is i64. }
        Emit('  ret ' + RetTy + ' ' +
          EmitCastValueToLlvmType(ATerm.ReturnValue, RetTy,
            'ret.' + IntToStr(ATerm.ReturnValue),
            ValueLlvmType(ATerm.ReturnValue, '')));
        end;
      end;
    htkBranch:
      Emit('  br label %bb' + IntToStr(ATerm.TargetBlock));
    htkCondBranch:
      Emit('  br i1 ' + ValueRef(ATerm.Condition) +
        ', label %bb' + IntToStr(ATerm.TrueBlock) +
        ', label %bb' + IntToStr(ATerm.FalseBlock));
    htkSwitch:
    begin
      { Selector may be i8/i32 from load of small globals; switch is always i64. }
      Emit('  switch i64 ' + EmitCastValueToLlvmType(ATerm.Condition, 'i64',
        'switch.' + IntToStr(ATerm.Condition),
        ValueLlvmType(ATerm.Condition, '')) +
        ', label %bb' + IntToStr(ATerm.DefaultBlock) + ' [');
      if ATerm.SwitchCases <> nil then
        for I := 0 to LongInt(ATerm.SwitchCases.Count) - 1 do
          Emit('    i64 ' + IntToStr(ATerm.SwitchCases[SizeUInt(I)].Value) +
            ', label %bb' + IntToStr(ATerm.SwitchCases[SizeUInt(I)].TargetBlock));
      Emit('  ]');
    end;
    htkUnreachable:
      Emit('  unreachable');
  end;
end;

procedure THIRLlvmEmitter.EmitTryFramePops;
var
  I: LongInt;
begin
  { Exit-inside-try paths skip the structured hikTryEnd; unwind the frames
    so @__np_exc_stack never keeps dangling buffers (tree-exit139 family). }
  for I := 1 to FTryFrameDepth do
    Emit('  call void @np_try_pop()');
end;

function THIRLlvmEmitter.IsSretFunction(const AName: string): Boolean;
var
  I: LongInt;
  F: THIRFunction;
begin
  for I := 0 to FModule.FunctionCount - 1 do
  begin
    F := FModule.FunctionAt(I);
    if SameText(F.Name, AName) and (F.Params <> nil) and
      (F.Params.Count > 0) and (F.Params[0].Name = 'sret_ptr') then
      Exit(True);
  end;
  Result := False;
end;

function THIRLlvmEmitter.IsTStringSretFunction(const AName: string): Boolean;
var
  I: LongInt;
  F: THIRFunction;
begin
  for I := 0 to FModule.FunctionCount - 1 do
  begin
    F := FModule.FunctionAt(I);
    if SameText(F.Name, AName) and F.IsTStringReturnAbi then
      Exit(True);
  end;
  Result := False;
end;

procedure THIRLlvmEmitter.EmitFunction(const AFunc: THIRFunction);
var
  I, J: LongInt;
  ParamStr, RetStr: string;
  T: THIRTypeRec;
begin
  if AFunc.IsExternal then
  begin
    { Emit LLVM declare for external functions }
    ParamStr := '';
    if AFunc.Params <> nil then
      for I := 0 to LongInt(AFunc.Params.Count) - 1 do
      begin
        if ParamStr <> '' then
          ParamStr := ParamStr + ', ';
        ParamStr := ParamStr + TypeToLlvm(AFunc.Params[SizeUInt(I)].TypeId);
      end;
    RetStr := TypeToLlvm(AFunc.ReturnTypeId);
    Emit('declare ' + RetStr + ' ' + LlvmGlobalRef(AFunc.ExternalName) +
      '(' + ParamStr + ')');
    Exit;
  end;
  ClearGlobalRefs;
  SetLength(FValueLlvmTypes, 0);

  ParamStr := '';
  if AFunc.Params <> nil then
    for I := 0 to LongInt(AFunc.Params.Count) - 1 do
    begin
      { Skip sret_ptr for IsTStringReturnAbi — emitter generates %agg.result }
      if AFunc.IsTStringReturnAbi and
        (AFunc.Params[SizeUInt(I)].Name = 'sret_ptr') then
        Continue;
      if ParamStr <> '' then
        ParamStr := ParamStr + ', ';
      ParamStr := ParamStr + TypeToLlvm(AFunc.Params[SizeUInt(I)].TypeId) +
        ' ' + ValueRef(AFunc.Params[SizeUInt(I)].ValueId);
      { SSA type of params is known at define-time — required so call sites
        can ptrtoint/inttoptr when residual ABI still says i64. }
      NoteValueLlvmType(AFunc.Params[SizeUInt(I)].ValueId,
        TypeToLlvm(AFunc.Params[SizeUInt(I)].TypeId));
    end;

  T := FModule.Types.GetType(AFunc.ReturnTypeId);
  if AFunc.IsTStringReturnAbi then
  begin
    FNeedsTStringRuntime := True;
    RetStr := 'void';
    if ParamStr <> '' then
      ParamStr := 'ptr sret(%TString) %agg.result, ' + ParamStr
    else
      ParamStr := 'ptr sret(%TString) %agg.result';
  end
  else if (AFunc.Params <> nil) and (AFunc.Params.Count > 0) and
    (AFunc.Params[0].Name = 'sret_ptr') then
    RetStr := 'void'
  else if AFunc.UsesOwnedStringReturnAbi then
    RetStr := '{ptr, i64, ptr, i64}'
  else if T.Kind = htkString then
    RetStr := '{ptr, i64}'
  else
    RetStr := TypeToLlvm(AFunc.ReturnTypeId);

  FCurrentReturnTypeId := AFunc.ReturnTypeId;
  FCurrentFuncIsTStringSret := AFunc.IsTStringReturnAbi;

  { Emit DISubprogram metadata for debug info }
  if FDebugInfoEnabled and (FDICUIndex >= 0) then
  begin
    FCurrentDISubprogram := AddDebugMetadata(
      '!DISubprogram(name: "' + EscapeLlvmStr(AFunc.Name) +
      '", scope: !' + IntToStr(FDIFileIndex) +
      ', file: !' + IntToStr(FDIFileIndex) +
      ', line: 1, type: !DISubroutineType(types: !{null}), ' +
      'scopeLine: 1, spFlags: DISPFlagDefinition, unit: !' +
      IntToStr(FDICUIndex) + ')');
  end
  else
    FCurrentDISubprogram := -1;

  Emit('');
  { alignstack=16: freestanding frames can otherwise leave rsp 8-mod-16;
    llc then emits movaps for bulk zero stores and SIGSEGV on cleanup. }
  if (Pos('np_object_dynarray_cleanup_', AFunc.Name) = 1) or
    (Pos('np_object_string_cleanup_', AFunc.Name) = 1) then
    Emit('define internal ' + RetStr + ' ' + LlvmGlobalRef(AFunc.Name) +
      '(' + ParamStr + ') #0 {')
  else
    Emit('define ' + RetStr + ' ' + LlvmGlobalRef(AFunc.Name) +
      '(' + ParamStr + ') #0 {');
  FTryFrameDepth := 0;

  { Entry-prologue pre-pass: render every hikAlloca of this function so the
    main block walk can skip them (hikAlloca case in EmitInstr is a no-op).
    Exception lowering splits HIR blocks mid-stream at the setjmp branch;
    hoisting all allocas above any split keeps except-block loads dominated. }
  SetLength(FEntryAllocaLines, 0);
  if AFunc.Blocks <> nil then
    for I := 0 to LongInt(AFunc.Blocks.Count) - 1 do
      if AFunc.Blocks[SizeUInt(I)].Instrs <> nil then
        for J := 0 to LongInt(AFunc.Blocks[SizeUInt(I)].Instrs.Count) - 1 do
          if AFunc.Blocks[SizeUInt(I)].Instrs[SizeUInt(J)].Kind = hikAlloca then
          begin
            SetLength(FEntryAllocaLines, Length(FEntryAllocaLines) + 1);
            FEntryAllocaLines[High(FEntryAllocaLines)] :=
              RenderAllocaLine(AFunc.Blocks[SizeUInt(I)].Instrs[SizeUInt(J)]);
          end;

  if AFunc.Blocks <> nil then
    for I := 0 to LongInt(AFunc.Blocks.Count) - 1 do
    begin
      Emit('bb' + IntToStr(AFunc.Blocks[SizeUInt(I)].Id) + ':');
      if I = 0 then
        for J := 0 to High(FEntryAllocaLines) do
          Emit(FEntryAllocaLines[J]);
      if AFunc.Blocks[SizeUInt(I)].Instrs <> nil then
        for J := 0 to LongInt(AFunc.Blocks[SizeUInt(I)].Instrs.Count) - 1 do
          if AFunc.Blocks[SizeUInt(I)].Instrs[SizeUInt(J)].Kind <> hikAlloca then
            EmitInstr(AFunc.Blocks[SizeUInt(I)].Instrs[SizeUInt(J)]);
      if not BlockEndsWithIntrinsicReturn(AFunc.Blocks[SizeUInt(I)]) then
        EmitTerminator(AFunc.Blocks[SizeUInt(I)].Terminator);
    end;

  SetLength(FEntryAllocaLines, 0);
  Emit('}');
end;

function THIRLlvmEmitter.HasEmittedFunction(const AName: string): Boolean;
var
  I: LongInt;
begin
  for I := 0 to FModule.FunctionCount - 1 do
    if SameText(FModule.FunctionAt(I).Name, AName) then
      Exit(True);
  Result := False;
end;

function THIRLlvmEmitter.NormalizeUnitLifecycleName(const AUnitName: string): string;
begin
  { Match SeedUnitLifecycleBodies (UnitId lowercase + dots → underscores). }
  Result := LowerCase(StringReplace(AUnitName, '.', '_', True));
end;

procedure THIRLlvmEmitter.EmitUnitDeclares;
var
  I: LongInt;
  LName: string;
  LNormalizedUnitName: string;
  LInitName: string;
  LFiniName: string;
begin
  { Only emit empty stubs when SeedUnitLifecycleBodies did not produce a real
    body. Re-define after a real body would hide it. Bodies use i64 return ABI
    (function-body-begin default); stubs/calls must match. }
  for I := 0 to FModule.UnitInitOrderCount - 1 do
  begin
    LName := FModule.UnitInitOrderAt(I);
    LNormalizedUnitName := NormalizeUnitLifecycleName(LName);
    LInitName := 'np_unit_init_' + LNormalizedUnitName;
    LFiniName := 'np_unit_fini_' + LNormalizedUnitName;
    if not HasEmittedFunction(LInitName) then
    begin
      Emit('define internal i64 ' + LlvmGlobalRef(LInitName) + '() {');
      Emit('entry:');
      Emit('  ret i64 0');
      Emit('}');
    end;
    if not HasEmittedFunction(LFiniName) then
    begin
      Emit('define internal i64 ' + LlvmGlobalRef(LFiniName) + '() {');
      Emit('entry:');
      Emit('  ret i64 0');
      Emit('}');
    end;
  end;
end;

procedure THIRLlvmEmitter.EmitUnitInitCalls;
var
  I: LongInt;
  LName: string;
  LNormalizedUnitName: string;
begin
  for I := 0 to FModule.UnitInitOrderCount - 1 do
  begin
    LName := FModule.UnitInitOrderAt(I);
    LNormalizedUnitName := NormalizeUnitLifecycleName(LName);
    Emit('  call i64 ' + LlvmGlobalRef('np_unit_init_' + LNormalizedUnitName) + '()');
  end;
end;

procedure THIRLlvmEmitter.EmitUnitFiniCalls;
var
  I: LongInt;
  LName: string;
  LNormalizedUnitName: string;
begin
  // Fini in reverse order of init
  for I := FModule.UnitInitOrderCount - 1 downto 0 do
  begin
    LName := FModule.UnitInitOrderAt(I);
    LNormalizedUnitName := NormalizeUnitLifecycleName(LName);
    Emit('  call i64 ' + LlvmGlobalRef('np_unit_fini_' + LNormalizedUnitName) + '()');
  end;
end;

