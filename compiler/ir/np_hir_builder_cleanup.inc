procedure THIRBuilder.ProcessSetLengthArr(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  ArrName, Blob, ElemSizeStr: string;
  SizeVal, PtrVal, ElemSizeVal, OldPtrVal, OldLenVal: THIRValueId;
  PtrAlloca, LenAlloca: THIRValueId;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  ArrName := Copy(ANode.Operand, 1, TabPos - 1);
  Blob := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  TabPos := Pos(#9, Blob);
  if TabPos > 0 then
  begin
    ElemSizeStr := Copy(Blob, TabPos + 1, Length(Blob));
    Blob := Copy(Blob, 1, TabPos - 1);
  end
  else
    ElemSizeStr := '';

  SizeVal := ParseIntExprArg(Blob);
  if SizeVal = 0 then Exit;

  PtrAlloca := FindAlloca(ArrName + '$ptr');
  LenAlloca := FindAlloca(ArrName + '$len');
  if (PtrAlloca = 0) or (LenAlloca = 0) then
    Exit;

  if ElemSizeStr <> '' then
    ElemSizeVal := ParseIntExprArg('int ' + ElemSizeStr + #10)
  else
    ElemSizeVal := EmitConstIntOfType(8, GetIntTypeByWidth(64, True));
  if ElemSizeVal = 0 then
    Exit;

  OldPtrVal := EmitLoad(GetPtrType, PtrAlloca);
  OldLenVal := EmitLoad(GetIntTypeByWidth(32, True), LenAlloca);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'dynarray_resize';
  SetLength(Instr.Operands, 4);
  Instr.Operands[0] := MakeTypedOperand(OldPtrVal, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(OldLenVal, GetIntTypeByWidth(32, True));
  Instr.Operands[2] := MakeTypedOperand(SizeVal, GetIntTypeByWidth(32, True));
  Instr.Operands[3] := MakeTypedOperand(ElemSizeVal, GetIntTypeByWidth(64, True));
  EmitInstr(Instr);
  PtrVal := Instr.ResultId;

  EmitStore(GetPtrType, PtrVal, PtrAlloca);
  EmitStore(GetIntTypeByWidth(32, True), SizeVal, LenAlloca);
end;

function THIRBuilder.FieldSlotPtr(AObjectPtr: THIRValueId;
  const ASlotIndex: LongInt): THIRValueId;
var
  Instr: THIRInstr;
  SlotVal: THIRValueId;
begin
  Result := 0;
  if (AObjectPtr = 0) or (ASlotIndex < 0) then
    Exit;
  SlotVal := EmitConstIntOfType(ASlotIndex, GetIntType);
  if SlotVal = 0 then
    Exit;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeTypedOperand(AObjectPtr, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(SlotVal, GetIntType);
  EmitInstr(Instr);
  Result := Instr.ResultId;
end;

procedure THIRBuilder.ProcessSetLengthFieldArr(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  ReceiverName, Rest, FieldIdxStr, LenBlob, ElemSizeStr: string;
  ReceiverSlot, ReceiverPtr, PtrSlot, LenSlot: THIRValueId;
  FieldIdx: LongInt;
  NewLenVal, ElemSizeVal, OldPtrVal, OldLenVal, NewPtrVal: THIRValueId;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  ReceiverName := Copy(ANode.Operand, 1, TabPos - 1);
  Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  TabPos := Pos(#9, Rest);
  if TabPos = 0 then Exit;
  FieldIdxStr := Copy(Rest, 1, TabPos - 1);
  Rest := Copy(Rest, TabPos + 1, Length(Rest));

  TabPos := Pos(#9, Rest);
  if TabPos > 0 then
  begin
    LenBlob := Copy(Rest, 1, TabPos - 1);
    ElemSizeStr := Copy(Rest, TabPos + 1, Length(Rest));
  end
  else
  begin
    LenBlob := Rest;
    ElemSizeStr := '';
  end;

  FieldIdx := StrToIntDef(FieldIdxStr, -1);
  if FieldIdx < 0 then Exit;

  ReceiverSlot := FindAlloca(ReceiverName);
  if ReceiverSlot = 0 then Exit;
  if IsVarParamAlloca(ReceiverName) then
    ReceiverPtr := EmitLoad(GetPtrType, EmitLoad(GetPtrType, ReceiverSlot))
  else
    ReceiverPtr := EmitLoad(GetPtrType, ReceiverSlot);
  if ReceiverPtr = 0 then Exit;

  NewLenVal := ParseIntExprArg(LenBlob);
  if NewLenVal = 0 then Exit;
  if ElemSizeStr <> '' then
    ElemSizeVal := ParseIntExprArg('int ' + ElemSizeStr + #10)
  else
    ElemSizeVal := EmitConstIntOfType(8, GetIntTypeByWidth(64, True));
  if ElemSizeVal = 0 then Exit;

  PtrSlot := FieldSlotPtr(ReceiverPtr, FieldIdx);
  LenSlot := FieldSlotPtr(ReceiverPtr, FieldIdx + 1);
  if (PtrSlot = 0) or (LenSlot = 0) then Exit;

  OldPtrVal := EmitLoad(GetPtrType, PtrSlot);
  OldLenVal := EmitLoad(GetIntTypeByWidth(32, True), LenSlot);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'dynarray_resize';
  SetLength(Instr.Operands, 4);
  Instr.Operands[0] := MakeTypedOperand(OldPtrVal, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(OldLenVal, GetIntTypeByWidth(32, True));
  Instr.Operands[2] := MakeTypedOperand(NewLenVal, GetIntTypeByWidth(32, True));
  Instr.Operands[3] := MakeTypedOperand(ElemSizeVal, GetIntTypeByWidth(64, True));
  EmitInstr(Instr);
  NewPtrVal := Instr.ResultId;

  EmitStore(GetPtrType, NewPtrVal, PtrSlot);
  EmitStore(GetIntTypeByWidth(32, True), NewLenVal, LenSlot);
end;

procedure THIRBuilder.ProcessDynArrayCleanup(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  VarName, ElemSizeBlob: string;
  PtrAlloca, LenAlloca: THIRValueId;
  PtrVal, LenVal, ElemSizeVal: THIRValueId;
  Instr: THIRInstr;
begin
  VarName := ANode.Operand;
  ElemSizeBlob := '';
  TabPos := Pos(#9, ANode.Operand);
  if TabPos > 0 then
  begin
    VarName := Copy(ANode.Operand, 1, TabPos - 1);
    ElemSizeBlob := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));
  end;
  if VarName = '' then
    VarName := ANode.DisplayName;
  if VarName = '' then
    Exit;

  PtrAlloca := FindAlloca(VarName + '$ptr');
  LenAlloca := FindAlloca(VarName + '$len');
  if (PtrAlloca = 0) or (LenAlloca = 0) then
    Exit;

  PtrVal := EmitLoad(GetPtrType, PtrAlloca);
  LenVal := EmitLoad(GetIntTypeByWidth(32, True), LenAlloca);
  if ElemSizeBlob <> '' then
    ElemSizeVal := ParseIntExprArg(ElemSizeBlob)
  else
    ElemSizeVal := EmitConstIntOfType(8, GetIntTypeByWidth(64, True));
  if ElemSizeVal = 0 then
    Exit;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'dynarray_release';
  SetLength(Instr.Operands, 3);
  Instr.Operands[0] := MakeTypedOperand(PtrVal, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(LenVal, GetIntTypeByWidth(32, True));
  Instr.Operands[2] := MakeTypedOperand(ElemSizeVal, GetIntTypeByWidth(64, True));
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessManagedRecordCleanup(const ANode: TTypedHirNode);
var
  Blob, VarName, TypeName, FieldSpec, FieldName, FieldKind: string;
  TabPos, ColonPos: LongInt;
  RecAlloca, RecPtr: THIRValueId;
  FieldIdx: Int64;
  FieldPtr, PtrSlot, LenSlot: THIRValueId;
  ZeroVal, ElemSizeVal: THIRValueId;
  Offset: LongInt;
  SlotPtr: THIRValueId;
  Instr: THIRInstr;
begin
  Blob := ANode.Operand;
  { 解析: VarName#9TypeName#9field1:s#9field2:d#9... }
  TabPos := Pos(#9, Blob);
  if TabPos = 0 then Exit;
  VarName := Copy(Blob, 1, TabPos - 1);
  Blob := Copy(Blob, TabPos + 1, Length(Blob));

  TabPos := Pos(#9, Blob);
  if TabPos > 0 then
  begin
    TypeName := Copy(Blob, 1, TabPos - 1);
    Blob := Copy(Blob, TabPos + 1, Length(Blob));
  end
  else
    TypeName := Blob;

  RecAlloca := FindAlloca(VarName);
  if RecAlloca = 0 then Exit;
  RecPtr := RecAlloca;
  if FindAllocaType(VarName) = GetPtrType then
    RecPtr := EmitLoad(GetPtrType, RecAlloca);

  { 遍历每个需要清理的字段 }
  while Blob <> '' do
  begin
    TabPos := Pos(#9, Blob);
    if TabPos > 0 then
    begin
      FieldSpec := Copy(Blob, 1, TabPos - 1);
      Blob := Copy(Blob, TabPos + 1, Length(Blob));
    end
    else
    begin
      FieldSpec := Blob;
      Blob := '';
    end;

    ColonPos := Pos(':', FieldSpec);
    if ColonPos = 0 then Continue;
    FieldName := Copy(FieldSpec, 1, ColonPos - 1);
    FieldKind := Copy(FieldSpec, ColonPos + 1, Length(FieldSpec));

    { 查找字段索引: TypeName.FieldName$idx }
    if not FSemaModel.LookupConstValue(TypeName + '.' + FieldName + '$idx', FieldIdx) then
      Continue;

    if FieldKind = 's' then
    begin
      { TString 24B: 调用 tstring_fini 然后清零 24 字节 (3 slots) }
      FieldPtr := FieldSlotPtr(RecPtr, FieldIdx);
      if FieldPtr <> 0 then
        EmitTStringFini(FieldPtr);

      ZeroVal := EmitConstIntOfType(0, GetIntType);
      if ZeroVal <> 0 then
      begin
        for Offset := 0 to 2 do
        begin
          SlotPtr := FieldSlotPtr(RecPtr, FieldIdx + Offset);
          if SlotPtr <> 0 then
            EmitStore(GetIntType, ZeroVal, SlotPtr);
        end;
      end;
    end
    else if FieldKind = 'd' then
    begin
      { dynarray field: 2 slot layout (ptr, len) }
      PtrSlot := FieldSlotPtr(RecPtr, FieldIdx);
      LenSlot := FieldSlotPtr(RecPtr, FieldIdx + 1);
      if (PtrSlot <> 0) and (LenSlot <> 0) then
      begin
        ElemSizeVal := EmitConstIntOfType(8, GetIntTypeByWidth(64, True));
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikIntrinsic;
        Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
        Instr.IntrinsicName := 'dynarray_release';
        SetLength(Instr.Operands, 3);
        Instr.Operands[0] := MakeTypedOperand(EmitLoad(GetPtrType, PtrSlot), GetPtrType);
        Instr.Operands[1] := MakeTypedOperand(EmitLoad(GetIntTypeByWidth(32, True), LenSlot), GetIntTypeByWidth(32, True));
        Instr.Operands[2] := MakeTypedOperand(ElemSizeVal, GetIntType);
        EmitInstr(Instr);
      end;
    end;
  end;
end;

procedure THIRBuilder.EmitObjectStringCleanupCall(const AClassName: string;
  const AReceiverPtr: THIRValueId);
var
  Instr: THIRInstr;
begin
  if (AClassName = '') or (AReceiverPtr = 0) then
    Exit;
  EnsureObjectStringCleanupHelper(AClassName);
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  AssignSystemContract(Instr, sckObjectFreeCleanup);
  Instr.CallTarget := 'np_object_string_cleanup_' + AClassName;
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(AReceiverPtr, GetPtrType);
  EmitInstr(Instr);
end;

procedure THIRBuilder.EmitObjectDynArrayCleanupCall(const AClassName: string;
  const AReceiverPtr: THIRValueId);
var
  Instr: THIRInstr;
begin
  if (AClassName = '') or (AReceiverPtr = 0) then
    Exit;
  EnsureObjectDynArrayCleanupHelper(AClassName);
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  AssignSystemContract(Instr, sckObjectFreeCleanup);
  Instr.CallTarget := 'np_object_dynarray_cleanup_' + AClassName;
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(AReceiverPtr, GetPtrType);
  EmitInstr(Instr);
end;

procedure THIRBuilder.EnsureObjectStringCleanupHelper(const AClassName: string);
var
  I: LongInt;
  Meta: TTypeMetadata;
  FuncId: THIRFuncId;
  EntryBlock: THIRBlockId;
  ParamValueId, ObjSlot: THIRValueId;
  PtrSlot, LenSlot, OwnerSlot, AllocSizeSlot: THIRValueId;
  NullVal, ZeroVal: THIRValueId;
  Instr: THIRInstr;
  Term: THIRTerminator;
  SavedFuncId: THIRFuncId;
  SavedBlockId: THIRBlockId;
  SavedEntryBlockId: THIRBlockId;
  SavedBlockTerminated: Boolean;
  SavedAllocas: THirAllocaVec;
  SavedBlockNames: THirNameVec;
  SavedBlockIds: THirBlockIdVec;
begin
  if AClassName = '' then
    Exit;
  if FModule.FindFunctionReturnType(
    'np_object_string_cleanup_' + AClassName) <> 0 then
    Exit;
  if not FSemaModel.GetTypeMetaByName(AClassName, Meta) then
    Exit;

  SavedFuncId := FCurrentFuncId;
  SavedBlockId := FCurrentBlockId;
  SavedEntryBlockId := FEntryBlockId;
  SavedBlockTerminated := FBlockTerminated;
  SavedAllocas := CreateAllocaVec;
  SavedBlockNames := CreateNameVec;
  SavedBlockIds := CreateBlockIdVec;
  try
    SnapshotWorkTables(SavedAllocas, SavedBlockNames, SavedBlockIds);

    FuncId := FModule.AddFunction(
      'np_object_string_cleanup_' + AClassName,
      FModule.Types.AddType(htkVoid, 'void'));
    FModule.AddFunctionParam(FuncId, 'obj', GetPtrType, False, False);
    EntryBlock := FModule.AddBlock(FuncId, 'entry');
    FModule.SetEntryBlock(FuncId, EntryBlock);

    FCurrentFuncId := FuncId;
    FCurrentBlockId := EntryBlock;
    FEntryBlockId := EntryBlock;
    FBlockTerminated := False;
    ClearWorkAllocas;
    ClearWorkBlocks;

    ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[0].ValueId;
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikAlloca;
    Instr.TypeId := GetPtrType;
    EmitInstr(Instr);
    ObjSlot := Instr.ResultId;
    RegisterAllocaEntry('obj', ObjSlot, GetPtrType, False);
    EmitStore(GetPtrType, ParamValueId, ObjSlot);

    if Meta.Fields <> nil then
    for I := LongInt(Meta.Fields.Count) - 1 downto 0 do
    begin
      if not Meta.Fields[SizeUInt(I)].IsString then
        Continue;

      PtrSlot := FieldSlotPtr(ParamValueId, Meta.Fields[SizeUInt(I)].Index);
      LenSlot := FieldSlotPtr(ParamValueId, Meta.Fields[SizeUInt(I)].Index + 1);
      OwnerSlot := FieldSlotPtr(ParamValueId, Meta.Fields[SizeUInt(I)].Index + 2);
      AllocSizeSlot := FieldSlotPtr(ParamValueId, Meta.Fields[SizeUInt(I)].Index + 3);
      if (PtrSlot = 0) or (LenSlot = 0) or (OwnerSlot = 0) or
        (AllocSizeSlot = 0) then
        Continue;

      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
      Instr.IntrinsicName := 'string_release';
      SetLength(Instr.Operands, 2);
      Instr.Operands[0] := MakeTypedOperand(EmitLoad(GetPtrType, OwnerSlot), GetPtrType);
      Instr.Operands[1] := MakeTypedOperand(EmitLoad(GetIntTypeByWidth(32, True), AllocSizeSlot), GetIntTypeByWidth(32, True));
      EmitInstr(Instr);

      NullVal := EmitNullPtrValue;
      ZeroVal := EmitConstIntSmart(0);
      if (NullVal <> 0) and (ZeroVal <> 0) then
      begin
        EmitStore(GetPtrType, NullVal, PtrSlot);
        EmitStore(GetIntTypeByWidth(32, True), ZeroVal, LenSlot);
        EmitStore(GetPtrType, NullVal, OwnerSlot);
        EmitStore(GetIntTypeByWidth(32, True), ZeroVal, AllocSizeSlot);
      end;
    end;

    FillChar(Term, SizeOf(Term), 0);
    Term.Kind := htkReturn;
    Term.ReturnValue := 0;
    FModule.SetTerminator(FuncId, EntryBlock, Term);

    FCurrentFuncId := SavedFuncId;
    FCurrentBlockId := SavedBlockId;
    FEntryBlockId := SavedEntryBlockId;
    FBlockTerminated := SavedBlockTerminated;
    RestoreWorkAllocas(SavedAllocas);
    RestoreWorkBlocks(SavedBlockNames, SavedBlockIds);
  finally
    SavedBlockIds.Free;
    SavedBlockNames.Free;
    SavedAllocas.Free;
  end;
end;

procedure THIRBuilder.EnsureObjectDynArrayCleanupHelper(const AClassName: string);
var
  I: LongInt;
  Meta: TTypeMetadata;
  FuncId: THIRFuncId;
  EntryBlock: THIRBlockId;
  ParamValueId, ObjSlot, PtrSlot, LenSlot: THIRValueId;
  PtrVal, LenVal, ElemSizeVal, NullVal, ZeroVal: THIRValueId;
  Instr: THIRInstr;
  Term: THIRTerminator;
  SavedFuncId: THIRFuncId;
  SavedBlockId: THIRBlockId;
  SavedEntryBlockId: THIRBlockId;
  SavedBlockTerminated: Boolean;
  ElemSize: Int64;
  SavedAllocas: THirAllocaVec;
  SavedBlockNames: THirNameVec;
  SavedBlockIds: THirBlockIdVec;
begin
  if AClassName = '' then
    Exit;
  if FModule.FindFunctionReturnType(
    'np_object_dynarray_cleanup_' + AClassName) <> 0 then
    Exit;
  if not FSemaModel.GetTypeMetaByName(AClassName, Meta) then
    Exit;

  SavedFuncId := FCurrentFuncId;
  SavedBlockId := FCurrentBlockId;
  SavedEntryBlockId := FEntryBlockId;
  SavedBlockTerminated := FBlockTerminated;
  SavedAllocas := CreateAllocaVec;
  SavedBlockNames := CreateNameVec;
  SavedBlockIds := CreateBlockIdVec;
  try
    SnapshotWorkTables(SavedAllocas, SavedBlockNames, SavedBlockIds);

    FuncId := FModule.AddFunction(
      'np_object_dynarray_cleanup_' + AClassName,
      FModule.Types.AddType(htkVoid, 'void'));
    FModule.AddFunctionParam(FuncId, 'obj', GetPtrType, False, False);
    EntryBlock := FModule.AddBlock(FuncId, 'entry');
    FModule.SetEntryBlock(FuncId, EntryBlock);

    FCurrentFuncId := FuncId;
    FCurrentBlockId := EntryBlock;
    FEntryBlockId := EntryBlock;
    FBlockTerminated := False;
    ClearWorkAllocas;
    ClearWorkBlocks;

    ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[0].ValueId;
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikAlloca;
    Instr.TypeId := GetPtrType;
    EmitInstr(Instr);
    ObjSlot := Instr.ResultId;
    RegisterAllocaEntry('obj', ObjSlot, GetPtrType, False);
    EmitStore(GetPtrType, ParamValueId, ObjSlot);

    if Meta.Fields <> nil then
    for I := LongInt(Meta.Fields.Count) - 1 downto 0 do
    begin
      if not Meta.Fields[SizeUInt(I)].IsDynArray then
        Continue;

      PtrSlot := FieldSlotPtr(ParamValueId, Meta.Fields[SizeUInt(I)].Index);
      LenSlot := FieldSlotPtr(ParamValueId, Meta.Fields[SizeUInt(I)].Index + 1);
      if (PtrSlot = 0) or (LenSlot = 0) then
        Continue;

      PtrVal := EmitLoad(GetPtrType, PtrSlot);
      LenVal := EmitLoad(GetIntTypeByWidth(32, True), LenSlot);
      if not FSemaModel.LookupConstValue(
        AClassName + '.' + Meta.Fields[SizeUInt(I)].Name + '$arr_elem_size',
        ElemSize) then
        ElemSizeVal := EmitConstIntOfType(8, GetIntTypeByWidth(64, True))
      else
        ElemSizeVal := EmitConstIntOfType(ElemSize, GetIntTypeByWidth(64, True));
      if ElemSizeVal = 0 then
        Continue;

      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
      Instr.IntrinsicName := 'dynarray_release';
      SetLength(Instr.Operands, 3);
      Instr.Operands[0] := MakeTypedOperand(PtrVal, GetPtrType);
      Instr.Operands[1] := MakeTypedOperand(LenVal, GetIntTypeByWidth(32, True));
      Instr.Operands[2] := MakeTypedOperand(ElemSizeVal, GetIntTypeByWidth(64, True));
      EmitInstr(Instr);

      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikLoad;
      Instr.TypeId := GetPtrType;
      Instr.IntrinsicName := 'null';
      EmitInstr(Instr);
      NullVal := Instr.ResultId;
      ZeroVal := EmitConstIntSmart(0);
      EmitStore(GetPtrType, NullVal, PtrSlot);
      EmitStore(GetIntTypeByWidth(32, True), ZeroVal, LenSlot);
    end;

    FillChar(Term, SizeOf(Term), 0);
    Term.Kind := htkReturn;
    Term.ReturnValue := 0;
    FModule.SetTerminator(FuncId, EntryBlock, Term);

    FCurrentFuncId := SavedFuncId;
    FCurrentBlockId := SavedBlockId;
    FEntryBlockId := SavedEntryBlockId;
    FBlockTerminated := SavedBlockTerminated;
    RestoreWorkAllocas(SavedAllocas);
    RestoreWorkBlocks(SavedBlockNames, SavedBlockIds);
  finally
    SavedBlockIds.Free;
    SavedBlockNames.Free;
    SavedAllocas.Free;
  end;
end;
