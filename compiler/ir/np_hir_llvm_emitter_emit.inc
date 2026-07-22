procedure THIRLlvmEmitter.EmitTerminator(const ATerm: THIRTerminator);
var
  I: LongInt;
  RetTy: string;
  T: THIRTypeRec;
begin
  ClosePendingObjectFreeGuard;
  case ATerm.Kind of
    htkReturn:
      if ATerm.ReturnValue = 0 then
        Emit('  ret void')
      else begin
        T := FModule.Types.GetType(FCurrentReturnTypeId);
        if T.Kind = htkString then
          RetTy := '{ptr, i64}'
        else
          RetTy := TypeToLlvm(FCurrentReturnTypeId);
        Emit('  ret ' + RetTy + ' ' + ValueRef(ATerm.ReturnValue));
      end;
    htkBranch:
      Emit('  br label %bb' + IntToStr(ATerm.TargetBlock));
    htkCondBranch:
      Emit('  br i1 ' + ValueRef(ATerm.Condition) +
        ', label %bb' + IntToStr(ATerm.TrueBlock) +
        ', label %bb' + IntToStr(ATerm.FalseBlock));
    htkSwitch:
    begin
      Emit('  switch i64 ' + ValueRef(ATerm.Condition) +
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
    Emit('declare ' + RetStr + ' @' + AFunc.ExternalName + '(' + ParamStr + ')');
    Exit;
  end;
  ClearGlobalRefs;

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
    Emit('define internal ' + RetStr + ' @' + AFunc.Name +
      '(' + ParamStr + ') #0 {')
  else
    Emit('define ' + RetStr + ' @' + AFunc.Name +
      '(' + ParamStr + ') #0 {');

  if AFunc.Blocks <> nil then
    for I := 0 to LongInt(AFunc.Blocks.Count) - 1 do
    begin
      Emit('bb' + IntToStr(AFunc.Blocks[SizeUInt(I)].Id) + ':');
      if AFunc.Blocks[SizeUInt(I)].Instrs <> nil then
        for J := 0 to LongInt(AFunc.Blocks[SizeUInt(I)].Instrs.Count) - 1 do
          EmitInstr(AFunc.Blocks[SizeUInt(I)].Instrs[SizeUInt(J)]);
      if not BlockEndsWithIntrinsicReturn(AFunc.Blocks[SizeUInt(I)]) then
        EmitTerminator(AFunc.Blocks[SizeUInt(I)].Terminator);
    end;

  Emit('}');
end;

procedure THIRLlvmEmitter.EmitUnitDeclares;
var
  I: LongInt;
  LName: string;
  LNormalizedUnitName: string;
begin
  for I := 0 to FModule.UnitInitOrderCount - 1 do
  begin
    LName := FModule.UnitInitOrderAt(I);
    LNormalizedUnitName := StringReplace(LName, '.', '_', True);
    Emit('define void @np_unit_init_' + LNormalizedUnitName + '() {');
    Emit('entry:');
    Emit('  ret void');
    Emit('}');
    Emit('define void @np_unit_fini_' + LNormalizedUnitName + '() {');
    Emit('entry:');
    Emit('  ret void');
    Emit('}');
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
    LNormalizedUnitName := StringReplace(LName, '.', '_', True);
    Emit('  call void @np_unit_init_' + LNormalizedUnitName + '()');
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
    LNormalizedUnitName := StringReplace(LName, '.', '_', True);
    Emit('  call void @np_unit_fini_' + LNormalizedUnitName + '()');
  end;
end;

