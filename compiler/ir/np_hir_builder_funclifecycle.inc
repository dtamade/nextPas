procedure THIRBuilder.ProcessFunctionBegin(const ANode: TTypedHirNode);
var
  TabPos, ColonPos, Pos2, Pos3: LongInt;
  FuncName, Rest, ParamCountStr, ParamName: string;
  EntryBlock: THIRBlockId;
  I, ParamCount, SearchFrom: LongInt;
  ParamValueId: THIRValueId;
  Instr: THIRInstr;
begin
  FSavedFuncId := FCurrentFuncId;
  FSavedBlockId := FCurrentBlockId;
  FSavedEntryBlockId := FEntryBlockId;
  FInStartFunc := False;
  SnapshotWorkTables(FSavedAllocas, FSavedBlockNames, FSavedBlockIds);

  TabPos := Pos(#9, ANode.Operand);
  ColonPos := Pos(':', ANode.Operand);

  if TabPos > 0 then
  begin
    FuncName := Copy(ANode.Operand, 1, TabPos - 1);
    Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

    ParamCount := 0;
    if Rest <> '' then
    begin
      Pos2 := Pos(#9, Rest);
      if Pos2 > 0 then
      begin
        Rest := Copy(Rest, Pos2 + 1, Length(Rest));
        Pos3 := Pos(#9, Rest);
        if Pos3 > 0 then
        begin
          ParamCountStr := Copy(Rest, 1, Pos3 - 1);
          ParamCount := StrToIntDef(ParamCountStr, 0);
          Rest := Copy(Rest, Pos3 + 1, Length(Rest));
        end;
      end;
    end;

    FCurrentFuncId := FModule.AddFunction(FuncName, GetIntType);

    for I := 0 to ParamCount - 1 do
    begin
      SearchFrom := Pos(#9, Rest);
      if SearchFrom > 0 then
      begin
        ParamName := Copy(Rest, 1, SearchFrom - 1);
        Rest := Copy(Rest, SearchFrom + 1, Length(Rest));
      end
      else
      begin
        ParamName := Rest;
        Rest := '';
      end;
      FModule.AddFunctionParam(FCurrentFuncId, ParamName, GetIntType, False, False);
    end;

    EntryBlock := FModule.AddBlock(FCurrentFuncId, 'entry');
    FModule.SetEntryBlock(FCurrentFuncId, EntryBlock);
    FCurrentBlockId := EntryBlock;
    FEntryBlockId := EntryBlock;
    FBlockTerminated := False;
    ClearWorkAllocas;
    ClearGlobalRefs;
    ClearWorkBlocks;
    FPendingParamCount := 0;
    FPendingParamLlvmIdx := 0;

    for I := 0 to ParamCount - 1 do
    begin
      ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[I].ValueId;
      ParamName := FModule.FunctionAt(FModule.FunctionCount - 1).Params[I].Name;

      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikAlloca;
      Instr.TypeId := GetIntType;
      EmitInstr(Instr);

      RegisterAllocaEntry(ParamName, Instr.ResultId, GetIntType, False);

      EmitStore(GetIntType, ParamValueId, Instr.ResultId);
    end;
  end
  else
  begin
    FuncName := ANode.DisplayName;
    ParamCount := 0;
    Rest := ANode.Operand;
    if ColonPos > 0 then
    begin
      ParamCount := StrToIntDef(Copy(Rest, 1, ColonPos - 1), 0);
      Rest := Copy(Rest, ColonPos + 1, Length(Rest));
    end
    else
      Rest := '';

    Pos2 := Pos(':', Rest);
    if Pos2 > 0 then
    begin
      ParamName := Copy(Rest, 1, Pos2 - 1);
      Rest := Copy(Rest, Pos2 + 1, Length(Rest));
    end
    else
    begin
      ParamName := Rest;
      Rest := '';
    end;

    if Rest = 'so' then
    begin
      FCurrentFuncId := FModule.AddFunction(FuncName, GetStringType);
      FModule.SetFunctionOwnedStringReturnAbi(FCurrentFuncId, True);
      FModule.SetFunctionTStringReturnAbi(FCurrentFuncId, True);
      FModule.AddFunctionParam(FCurrentFuncId, 'sret_ptr', GetPtrType, False, False);
    end
    else if Rest = 's' then
    begin
      FCurrentFuncId := FModule.AddFunction(FuncName, GetStringType);
      FModule.SetFunctionTStringReturnAbi(FCurrentFuncId, True);
      FModule.AddFunctionParam(FCurrentFuncId, 'sret_ptr', GetPtrType, False, False);
    end
    else if Rest = 'p' then
      FCurrentFuncId := FModule.AddFunction(FuncName, GetPtrType)
    else if Rest = 'a' then
      { Dynarray return: local Result is dual-slot; ABI returns the data ptr half. }
      FCurrentFuncId := FModule.AddFunction(FuncName, GetPtrType)
    else if (Length(Rest) > 1) and (Rest[1] = 'r') then
    begin
      FCurrentFuncId := FModule.AddFunction(FuncName, GetIntType);
      FModule.AddFunctionParam(FCurrentFuncId, 'sret_ptr', GetPtrType, False, False);
    end
    else
      FCurrentFuncId := FModule.AddFunction(FuncName, GetIntType);

    for I := 0 to ParamCount - 1 do
    begin
      if (I < Length(ParamName)) and (ParamName[I + 1] = 's') then
      begin
        FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I) + '_ptr', GetPtrType, False, False);
        FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I) + '_len', GetIntTypeByWidth(32, True), False, False);
      end
      else if (I < Length(ParamName)) and (ParamName[I + 1] = 'a') then
      begin
        FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I) + '_ptr', GetPtrType, False, False);
        FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I) + '_len', GetIntTypeByWidth(32, True), False, False);
      end
      else if (I < Length(ParamName)) and (ParamName[I + 1] = 'v') then
        FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I), GetPtrType, True, False)
      else if (I < Length(ParamName)) and
        ((ParamName[I + 1] = 'p') or (ParamName[I + 1] = 'r')) then
        FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I), GetPtrType, False, False)
      else
        FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I), GetIntType, False, False);
    end;

    EntryBlock := FModule.AddBlock(FCurrentFuncId, 'entry');
    FModule.SetEntryBlock(FCurrentFuncId, EntryBlock);
    FCurrentBlockId := EntryBlock;
    FEntryBlockId := EntryBlock;
    FBlockTerminated := False;
    ClearWorkAllocas;
    ClearGlobalRefs;
    ClearWorkBlocks;
    if ((Length(Rest) > 1) and (Rest[1] = 'r')) or
       (Rest = 'so') or (Rest = 's') then
    begin
      FPendingParamCount := ParamCount;
      FPendingParamLlvmIdx := 1;
      FSretValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[0].ValueId;
    end
    else
    begin
      FPendingParamCount := ParamCount;
      FPendingParamLlvmIdx := 0;
      FSretValueId := 0;
    end;
  end;
end;

procedure THIRBuilder.ProcessFunctionEnd(const ANode: TTypedHirNode);
begin
  FPendingParamCount := 0;
  FPendingParamLlvmIdx := 0;
  FSretValueId := 0;
  FCurrentFuncId := FSavedFuncId;
  FCurrentBlockId := FSavedBlockId;
  FEntryBlockId := FSavedEntryBlockId;
  RestoreWorkAllocas(FSavedAllocas);
  RestoreWorkBlocks(FSavedBlockNames, FSavedBlockIds);
end;

procedure THIRBuilder.ProcessExternalDecl(const ANode: TTypedHirNode);
var
  I, LBindingIdx: LongInt;
  LBinding: TSemanticForeignProcedureBinding;
  LFuncId: THIRFuncId;
  LSymbol: TSemanticSymbol;
  LReturnTypeId: THIRTypeId;
  LParamCount: LongInt;
begin
  { Check if this declaration has a corresponding foreign procedure binding }
  LBindingIdx := -1;
  for I := 0 to FSemaModel.ForeignProcedureBindingCount - 1 do
  begin
    LBinding := FSemaModel.ForeignProcedureBindingAt(I);
    if SameText(LBinding.PascalName, ANode.DisplayName) then
    begin
      LBindingIdx := I;
      Break;
    end;
  end;
  if LBindingIdx < 0 then
    Exit; { Not an external function — ignore }

  LBinding := FSemaModel.ForeignProcedureBindingAt(LBindingIdx);

  { Determine return type and parameters from symbol }
  LReturnTypeId := GetIntType;
  LParamCount := 0;
  LSymbol.SymbolId := 0; { mark as invalid }
  if (LBinding.SymbolId > 0) and (LBinding.SymbolId <= FSemaModel.SymbolCount) then
  begin
    LSymbol := FSemaModel.SymbolAt(LBinding.SymbolId - 1);
    if LSymbol.TypeId > 0 then
      LReturnTypeId := SemanticTypeIdToHirTypeId(LSymbol.TypeId);
    LParamCount := LSymbol.ParamCount;
  end;

  { LLVM symbol is ExternalSymbolName (e.g. getenv); PascalName is lookup key.
    Prefer ptr return for C string APIs (PChar/PAnsiChar). }
  if (LSymbol.SymbolId > 0) and (LSymbol.TypeId > 0) then
  begin
    { already mapped }
  end
  else if SameText(LBinding.ExternalSymbolName, 'getenv') or
    SameText(LBinding.PascalName, 'getenv') or
    SameText(LBinding.ExternalSymbolName, 'getcwd') then
    LReturnTypeId := GetPtrType;

  if (LBinding.ExternalSymbolName <> '') then
    LFuncId := FModule.AddFunction(LBinding.ExternalSymbolName, LReturnTypeId)
  else
    LFuncId := FModule.AddFunction(LBinding.PascalName, LReturnTypeId);
  FModule.SetFunctionExternal(LFuncId, True, LBinding.LibraryId,
    LBinding.ExternalSymbolName);

  { Add parameters — use ParamSignature to infer types where possible.
    'p'→ptr, 's'→string, 'b'→bool, 'r'/'f'/'c'→ptr, 'i'→i64 fallback.
    Missing signature: libc-style externals default to ptr args. }
  if LParamCount <= 0 then
  begin
    { getenv(name), getcwd(buf, size): at least one ptr formal }
    if SameText(LBinding.ExternalSymbolName, 'getenv') or
      SameText(LBinding.PascalName, 'getenv') then
      LParamCount := 1
    else if SameText(LBinding.ExternalSymbolName, 'getcwd') or
      SameText(LBinding.PascalName, 'getcwd') then
      LParamCount := 2;
  end;
  for I := 0 to LParamCount - 1 do
  begin
    if (LSymbol.SymbolId > 0) and (I < Length(LSymbol.ParamSignature)) then
      case LSymbol.ParamSignature[I + 1] of
        'p': FModule.AddFunctionParam(LFuncId, 'arg' + IntToStr(I), GetPtrType, False, False);
        's': FModule.AddFunctionParam(LFuncId, 'arg' + IntToStr(I), GetPtrType, False, False);
        'b': FModule.AddFunctionParam(LFuncId, 'arg' + IntToStr(I), GetBoolType, False, False);
        'r': FModule.AddFunctionParam(LFuncId, 'arg' + IntToStr(I), GetPtrType, False, False);
        'f': FModule.AddFunctionParam(LFuncId, 'arg' + IntToStr(I), GetPtrType, False, False);
        'c': FModule.AddFunctionParam(LFuncId, 'arg' + IntToStr(I), GetPtrType, False, False);
      else
        FModule.AddFunctionParam(LFuncId, 'arg' + IntToStr(I), GetIntType, False, False);
      end
    else
      FModule.AddFunctionParam(LFuncId, 'arg' + IntToStr(I), GetPtrType, False, False);
  end;
end;
