procedure THIRBuilder.ProcessSetLengthArr(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  ArrName, Blob, ElemSizeStr: string;
  SizeVal, PtrVal, ElemSizeVal, OldPtrVal, OldLenVal: THIRValueId;
  PtrAlloca, LenAlloca: THIRValueId;
  SizeType, ElemSizeType, I32, I64: THIRTypeId;
  SizeI32, SizeI64, OldLenI64, ElemSizeI64: THIRValueId;
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

  SizeVal := ParseIntExprArgTyped(Blob, SizeType);
  if SizeVal = 0 then Exit;

  PtrAlloca := FindAlloca(ArrName + '$ptr');
  LenAlloca := FindAlloca(ArrName + '$len');
  if (PtrAlloca = 0) or (LenAlloca = 0) then
    Exit;

  I32 := GetIntTypeByWidth(32, True);
  I64 := GetIntTypeByWidth(64, True);
  if ElemSizeStr <> '' then
    ElemSizeVal := ParseIntExprArgTyped('int ' + ElemSizeStr + #10, ElemSizeType)
  else
    ElemSizeVal := GetDynArrayElemSizeValue(ArrName, ElemSizeType);
  if ElemSizeVal = 0 then
    Exit;

  OldPtrVal := EmitLoad(GetPtrType, PtrAlloca);
  OldLenVal := EmitLoad(I32, LenAlloca);
  { Runtime ABI is i64 for len/new_len/elem_size; $len slot stays i32. }
  OldLenI64 := NormalizeScalarValueToType(OldLenVal, I32, I64);
  SizeI64 := NormalizeScalarValueToType(SizeVal, SizeType, I64);
  SizeI32 := NormalizeScalarValueToType(SizeVal, SizeType, I32);
  ElemSizeI64 := NormalizeScalarValueToType(ElemSizeVal, ElemSizeType, I64);
  if (OldLenI64 = 0) or (SizeI64 = 0) or (SizeI32 = 0) or (ElemSizeI64 = 0) then
    Exit;

  { Typed dynarray set_length: SystemContractKind authority; CallTarget = runtime map. }
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  AssignSystemContract(Instr, sckDynArraySetLength);
  Instr.CallTarget := SystemContractAt(sckDynArraySetLength).RuntimeMapping;
  SetLength(Instr.Operands, 4);
  Instr.Operands[0] := MakeTypedOperand(OldPtrVal, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(OldLenI64, I64);
  Instr.Operands[2] := MakeTypedOperand(SizeI64, I64);
  Instr.Operands[3] := MakeTypedOperand(ElemSizeI64, I64);
  EmitInstr(Instr);
  PtrVal := Instr.ResultId;

  EmitStore(GetPtrType, PtrVal, PtrAlloca);
  EmitStore(I32, SizeI32, LenAlloca);
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
  NewLenType, ElemSizeType, I32, I64: THIRTypeId;
  NewLenI32, NewLenI64, OldLenI64, ElemSizeI64: THIRValueId;
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

  NewLenVal := ParseIntExprArgTyped(LenBlob, NewLenType);
  if NewLenVal = 0 then Exit;
  I32 := GetIntTypeByWidth(32, True);
  I64 := GetIntTypeByWidth(64, True);
  if ElemSizeStr <> '' then
    ElemSizeVal := ParseIntExprArgTyped('int ' + ElemSizeStr + #10, ElemSizeType)
  else
    ElemSizeVal := GetDynArrayElemSizeValue(ReceiverName + '.' + FieldIdxStr, ElemSizeType);
  if ElemSizeVal = 0 then Exit;

  PtrSlot := FieldSlotPtr(ReceiverPtr, FieldIdx);
  LenSlot := FieldSlotPtr(ReceiverPtr, FieldIdx + 1);
  if (PtrSlot = 0) or (LenSlot = 0) then Exit;

  OldPtrVal := EmitLoad(GetPtrType, PtrSlot);
  OldLenVal := EmitLoad(I32, LenSlot);
  OldLenI64 := NormalizeScalarValueToType(OldLenVal, I32, I64);
  NewLenI64 := NormalizeScalarValueToType(NewLenVal, NewLenType, I64);
  NewLenI32 := NormalizeScalarValueToType(NewLenVal, NewLenType, I32);
  ElemSizeI64 := NormalizeScalarValueToType(ElemSizeVal, ElemSizeType, I64);
  if (OldLenI64 = 0) or (NewLenI64 = 0) or (NewLenI32 = 0) or (ElemSizeI64 = 0) then
    Exit;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  AssignSystemContract(Instr, sckDynArraySetLength);
  Instr.CallTarget := SystemContractAt(sckDynArraySetLength).RuntimeMapping;
  SetLength(Instr.Operands, 4);
  Instr.Operands[0] := MakeTypedOperand(OldPtrVal, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(OldLenI64, I64);
  Instr.Operands[2] := MakeTypedOperand(NewLenI64, I64);
  Instr.Operands[3] := MakeTypedOperand(ElemSizeI64, I64);
  EmitInstr(Instr);
  NewPtrVal := Instr.ResultId;

  EmitStore(GetPtrType, NewPtrVal, PtrSlot);
  EmitStore(I32, NewLenI32, LenSlot);
end;

procedure THIRBuilder.ProcessDynArrayCleanup(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  VarName, ElemSizeBlob: string;
  PtrAlloca, LenAlloca: THIRValueId;
  PtrVal, LenVal, ElemSizeVal: THIRValueId;
  ElemSizeType, I32, I64: THIRTypeId;
  LenI64, ElemSizeI64: THIRValueId;
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

  I32 := GetIntTypeByWidth(32, True);
  I64 := GetIntTypeByWidth(64, True);
  PtrVal := EmitLoad(GetPtrType, PtrAlloca);
  LenVal := EmitLoad(I32, LenAlloca);
  if ElemSizeBlob <> '' then
    ElemSizeVal := ParseIntExprArgTyped(ElemSizeBlob, ElemSizeType)
  else
    ElemSizeVal := GetDynArrayElemSizeValue(VarName, ElemSizeType);
  if ElemSizeVal = 0 then
    Exit;
  LenI64 := NormalizeScalarValueToType(LenVal, I32, I64);
  ElemSizeI64 := NormalizeScalarValueToType(ElemSizeVal, ElemSizeType, I64);
  if (LenI64 = 0) or (ElemSizeI64 = 0) then
    Exit;

  { Typed dynarray fini: SystemContractKind authority; CallTarget = runtime map. }
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  AssignSystemContract(Instr, sckDynArrayFini);
  Instr.CallTarget := SystemContractAt(sckDynArrayFini).RuntimeMapping;
  SetLength(Instr.Operands, 3);
  Instr.Operands[0] := MakeTypedOperand(PtrVal, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(LenI64, I64);
  Instr.Operands[2] := MakeTypedOperand(ElemSizeI64, I64);
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
  ElemSizeType: THIRTypeId;
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

  { Typed authority: managed_record_fini marker (record base ptr).
    Nested field contracts (string/dynarray) perform actual release. }
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  AssignSystemContract(Instr, sckManagedRecordFini);
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(RecPtr, GetPtrType);
  EmitInstr(Instr);

  { Expand each managed field into its typed nested contract. }
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
        ElemSizeVal := GetDynArrayElemSizeValue(TypeName + '.' + FieldName, ElemSizeType);
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikIntrinsic;
        Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
        AssignSystemContract(Instr, sckDynArrayFini);
        Instr.CallTarget := SystemContractAt(sckDynArrayFini).RuntimeMapping;
        SetLength(Instr.Operands, 3);
        Instr.Operands[0] := MakeTypedOperand(EmitLoad(GetPtrType, PtrSlot), GetPtrType);
        Instr.Operands[1] := MakeTypedOperand(
          NormalizeScalarValueToType(
            EmitLoad(GetIntTypeByWidth(32, True), LenSlot),
            GetIntTypeByWidth(32, True),
            GetIntTypeByWidth(64, True)),
          GetIntTypeByWidth(64, True));
        Instr.Operands[2] := MakeTypedOperand(ElemSizeVal, ElemSizeType);
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
      { Runtime ABI is i64 for alloc_size; the $alloc_size slot stays i32
        (same slot convention as $len, see dynarray fini above). }
      Instr.Operands[1] := MakeTypedOperand(
        NormalizeScalarValueToType(
          EmitLoad(GetIntTypeByWidth(32, True), AllocSizeSlot),
          GetIntTypeByWidth(32, True),
          GetIntTypeByWidth(64, True)),
        GetIntTypeByWidth(64, True));
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
  ElemSizeType: THIRTypeId;
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
      LenVal := NormalizeScalarValueToType(LenVal,
        GetIntTypeByWidth(32, True), GetIntTypeByWidth(64, True));
      if LenVal = 0 then
        Continue;
      ElemSizeVal := GetDynArrayElemSizeValue(
        AClassName + '.' + Meta.Fields[SizeUInt(I)].Name, ElemSizeType);
      if ElemSizeVal = 0 then
        Continue;

      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
      AssignSystemContract(Instr, sckDynArrayFini);
      Instr.CallTarget := SystemContractAt(sckDynArrayFini).RuntimeMapping;
      SetLength(Instr.Operands, 3);
      Instr.Operands[0] := MakeTypedOperand(PtrVal, GetPtrType);
      Instr.Operands[1] := MakeTypedOperand(LenVal, GetIntTypeByWidth(64, True));
      Instr.Operands[2] := MakeTypedOperand(ElemSizeVal, ElemSizeType);
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
