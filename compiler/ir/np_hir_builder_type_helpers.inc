function THIRBuilder.NormalizeScalarValueToType(const AValueId: THIRValueId;
  const ASourceTypeId, ATargetTypeId: THIRTypeId): THIRValueId;
var
  Kind: THIRInstrKind;
  NoOp: Boolean;
  Instr: THIRInstr;
begin
  Result := AValueId;
  if AValueId = 0 then
    Exit(0);
  if (ASourceTypeId = 0) or (ATargetTypeId = 0) then
    Exit(0);

  if not TryClassifyScalarCast(ASourceTypeId, ATargetTypeId, Kind, NoOp) then
    Exit(0);
  if NoOp then
    Exit;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := Kind;
  Instr.TypeId := ATargetTypeId;
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(AValueId, ASourceTypeId);
  EmitInstr(Instr);
  Result := Instr.ResultId;
end;

function THIRBuilder.NormalizeInt64RuntimeValue(const AValueId: THIRValueId;
  const ATypeId: THIRTypeId): THIRValueId;
begin
  Result := NormalizeScalarValueToType(AValueId, ATypeId, GetIntType);
end;

function THIRBuilder.GetIntType: THIRTypeId;
begin
  if FLegacyIntType = 0 then
    FLegacyIntType := FModule.Types.AddIntType(64, True);
  Result := FLegacyIntType;
end;

function THIRBuilder.GetBoolType: THIRTypeId;
begin
  if FBoolType = 0 then
    FBoolType := FModule.Types.AddType(htkBool, 'bool');
  Result := FBoolType;
end;

function THIRBuilder.GetStringType: THIRTypeId;
begin
  if FStringType = 0 then
    FStringType := FModule.Types.AddStringType(skAnsi);
  Result := FStringType;
end;

function THIRBuilder.GetPtrType: THIRTypeId;
begin
  if FPtrType = 0 then
    FPtrType := FModule.Types.AddPointerType(0);
  Result := FPtrType;
end;

function THIRBuilder.GetIntTypeByWidth(const ABitWidth: LongInt;
  const ASigned: Boolean): THIRTypeId;
var
  WidthIndex, SignedIndex: LongInt;
begin
  case ABitWidth of
    1:
      Exit(GetBoolType);
    8:
      WidthIndex := 0;
    16:
      WidthIndex := 1;
    32:
      WidthIndex := 2;
    64:
      WidthIndex := 3;
  else
    Exit(0);
  end;

  if ASigned then
    SignedIndex := 1
  else
    SignedIndex := 0;
  if FIntTypeCache[WidthIndex, SignedIndex] = 0 then
    FIntTypeCache[WidthIndex, SignedIndex] :=
      FModule.Types.AddIntType(ABitWidth, ASigned);
  Result := FIntTypeCache[WidthIndex, SignedIndex];
end;

function THIRBuilder.GetFloatType: THIRTypeId;
begin
  Result := GetFloatTypeByWidth(64);  { Default to Double }
end;

function THIRBuilder.GetFloatTypeByWidth(
  const ABitWidth: LongInt
): THIRTypeId;
begin
  case ABitWidth of
    32:
      begin
        if FFloat32Type = 0 then
          FFloat32Type := FModule.Types.AddFloatType(fwF32);
        Result := FFloat32Type;
      end;
    64:
      begin
        if FFloat64Type = 0 then
          FFloat64Type := FModule.Types.AddFloatType(fwF64);
        Result := FFloat64Type;
      end;
  else
    Result := 0;
  end;
end;

function THIRBuilder.SemanticTypeIdToHirTypeId(
  const ATypeId: LongInt
): THIRTypeId;
var
  Fact: TSemanticScalarTypeFact;
begin
  if (FSemaModel = nil) or
    (not FSemaModel.GetTypeScalarFact(ATypeId, Fact)) then
    Exit(0);

  case Fact.Kind of
    sskBool:
      Result := GetBoolType;
    sskInt:
      Result := GetIntTypeByWidth(Fact.BitWidth, Fact.Signed);
    sskFloat:
      Result := GetFloatTypeByWidth(Fact.BitWidth);
    sskPointer:
      Result := GetPtrType;
  else
    Result := 0;
  end;
end;

function THIRBuilder.ExprHirTypeId(
  const AExpr: TSemanticHirExpr
): THIRTypeId;
begin
  Result := SemanticTypeIdToHirTypeId(AExpr.TypeId);
end;

function THIRBuilder.ExprIdHirTypeId(const AExprId: LongInt): THIRTypeId;
var
  Expr: TSemanticHirExpr;
begin
  if (FSemaModel = nil) or (AExprId <= 0) or
    (AExprId > FSemaModel.HirExprCount) then
    Exit(0);
  Expr := FSemaModel.HirExprAt(AExprId - 1);
  Result := ExprHirTypeId(Expr);
end;

function THIRBuilder.HirTypeIsInt(const ATypeId: THIRTypeId): Boolean;
begin
  Result := (ATypeId <> 0) and
    (FModule.Types.GetType(ATypeId).Kind = htkInt);
end;

function THIRBuilder.HirTypeIsBool(const ATypeId: THIRTypeId): Boolean;
begin
  Result := (ATypeId <> 0) and
    (FModule.Types.GetType(ATypeId).Kind = htkBool);
end;

function THIRBuilder.TryClassifyScalarCast(const ASourceTypeId,
  ATargetTypeId: THIRTypeId; out AKind: THIRInstrKind;
  out ANoOp: Boolean): Boolean;
var
  SourceType, TargetType: THIRTypeRec;
begin
  AKind := hikZext;
  ANoOp := False;
  if (ASourceTypeId = 0) or (ATargetTypeId = 0) then
    Exit(False);
  if ASourceTypeId = ATargetTypeId then
  begin
    ANoOp := True;
    Exit(True);
  end;

  SourceType := FModule.Types.GetType(ASourceTypeId);
  TargetType := FModule.Types.GetType(ATargetTypeId);

  if SourceType.Kind = htkBool then
  begin
    if TargetType.Kind = htkBool then
    begin
      ANoOp := True;
      Exit(True);
    end;
    if TargetType.Kind <> htkInt then
      Exit(False);
    AKind := hikZext;
    Exit(TargetType.BitWidth > 1);
  end;

  if (SourceType.Kind <> htkInt) or (TargetType.Kind <> htkInt) then
    Exit(False);

  if SourceType.BitWidth = TargetType.BitWidth then
  begin
    ANoOp := True;
    Exit(True);
  end;

  if SourceType.BitWidth < TargetType.BitWidth then
  begin
    if SourceType.Signed then
      AKind := hikSext
    else
      AKind := hikZext;
    Exit(True);
  end;

  AKind := hikTrunc;
  Result := True;
end;

procedure THIRBuilder.EnsureAlloca(const AName: string; AType: THIRTypeId);
var
  Instr: THIRInstr;
begin
  if FindAlloca(AName) <> 0 then Exit;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikAlloca;
  Instr.TypeId := AType;
  if (Pos('$owner', AName) > 0) or (Pos('$alloc_size', AName) > 0) then
    Instr.CallTarget := AName;
  if (FCurrentFuncId <> 0) and (FEntryBlockId <> 0) then
    FModule.AddInstr(FCurrentFuncId, FEntryBlockId, Instr)
  else
    EmitInstr(Instr);

  RegisterAllocaEntry(AName, Instr.ResultId, AType, False);
end;

procedure THIRBuilder.RegisterAllocaEntry(const AName: string;
  AValue: THIRValueId; AType: THIRTypeId; AIsVarParam: Boolean);
var
  Entry: TAllocaEntry;
begin
  Entry.Name := AName;
  Entry.Value := AValue;
  Entry.TypeId := AType;
  Entry.RecordSlots := 0;
  Entry.IsVarParam := AIsVarParam;
  FAllocas.Push(Entry);
end;

function THIRBuilder.FindLocalAlloca(const AName: string): THIRValueId;
var
  I: SizeUInt;
begin
  if FAllocas.Count > 0 then
    for I := 0 to FAllocas.Count - 1 do
      if SameText(FAllocas[I].Name, AName) then
        Exit(FAllocas[I].Value);
  Result := 0;
end;

function THIRBuilder.FindAlloca(const AName: string): THIRValueId;
var
  I: LongInt;
  Instr: THIRInstr;
begin
  if FAllocas.Count > 0 then
    for I := LongInt(FAllocas.Count) - 1 downto 0 do
      if SameText(FAllocas[I].Name, AName) then
        Exit(FAllocas[I].Value);
  if FGlobalRefCache.Count > 0 then
    for I := 0 to LongInt(FGlobalRefCache.Count) - 1 do
      if SameText(FGlobalRefCache[I], AName) then
        Exit(FGlobalRefValues[I]);
  if FGlobalNames.Count > 0 then
    for I := 0 to LongInt(FGlobalNames.Count) - 1 do
      if SameText(FGlobalNames[I], AName) then
      begin
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikIntrinsic;
        Instr.TypeId := GetPtrType;
        Instr.IntrinsicName := 'global_ref';
        Instr.CallTarget := AName;
        EmitInstr(Instr);
        FGlobalRefCache.Push(AName);
        FGlobalRefValues.Push(Instr.ResultId);
        Exit(Instr.ResultId);
      end;
  Result := 0;
end;

function THIRBuilder.FindAllocaType(const AName: string): THIRTypeId;
var
  I: SizeUInt;
begin
  if FAllocas.Count > 0 then
    for I := 0 to FAllocas.Count - 1 do
      if SameText(FAllocas[I].Name, AName) then
        Exit(FAllocas[I].TypeId);
  Result := 0;
end;

function THIRBuilder.IsVarParamAlloca(const AName: string): Boolean;
var
  I: SizeUInt;
begin
  if FAllocas.Count > 0 then
    for I := 0 to FAllocas.Count - 1 do
      if SameText(FAllocas[I].Name, AName) then
        Exit(FAllocas[I].IsVarParam);
  Result := False;
end;

procedure THIRBuilder.SetCurrentSourcePosFromSymbol(ASymbolId: LongInt);
var
  LSymbol: TSemanticSymbol;
  LLineCol: TLineCol;
begin
  if (ASymbolId <= 0) or (FSemaModel = nil) then
    Exit;
  LSymbol := FSemaModel.SymbolAt(ASymbolId);
  if (LSymbol.SymbolId <= 0) or (LSymbol.ByteOffset <= 0) then
    Exit;
  if (FSourceDatabase <> nil) and (FCurrentSourceFileId > 0) then
  begin
    LLineCol := FSourceDatabase.ByteOffsetToLineCol(
      FCurrentSourceFileId, LSymbol.ByteOffset);
    FCurrentSourceLine := LLineCol.Line;
    FCurrentSourceCol := LLineCol.Column;
  end;
end;

procedure THIRBuilder.EmitInstr(const AInstr: THIRInstr);
var
  LInstr: THIRInstr;
begin
  if (FCurrentFuncId <> 0) and (FCurrentBlockId <> 0) then
  begin
    LInstr := AInstr;
    { Apply current source position to instruction for debug info }
    if (FCurrentSourceLine > 0) and (LInstr.SourceLine = 0) then
    begin
      LInstr.SourceLine := FCurrentSourceLine;
      LInstr.SourceCol := FCurrentSourceCol;
    end;
    FModule.AddInstr(FCurrentFuncId, FCurrentBlockId, LInstr);
  end;
end;

function THIRBuilder.EmitBinOp(AKind: THIRInstrKind; AType: THIRTypeId;
  ALhs, ARhs: THIRValueId): THIRValueId;
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := AKind;
  Instr.TypeId := AType;
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeTypedOperand(ALhs, AType);
  Instr.Operands[1] := MakeTypedOperand(ARhs, AType);
  EmitInstr(Instr);
  Result := Instr.ResultId;
end;

function THIRBuilder.EmitCmpOp(AKind: THIRInstrKind; AType: THIRTypeId;
  ALhs, ARhs: THIRValueId; ALhsType, ARhsType: THIRTypeId): THIRValueId;
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := AKind;
  Instr.TypeId := AType;
  SetLength(Instr.Operands, 2);
  if ALhsType <> 0 then
    Instr.Operands[0] := MakeTypedOperand(ALhs, ALhsType)
  else
    Instr.Operands[0] := MakeOperand(ALhs);
  if ARhsType <> 0 then
    Instr.Operands[1] := MakeTypedOperand(ARhs, ARhsType)
  else
    Instr.Operands[1] := MakeOperand(ARhs);
  EmitInstr(Instr);
  Result := Instr.ResultId;
end;

function THIRBuilder.EmitLoad(AType: THIRTypeId;
  AAddr: THIRValueId): THIRValueId;
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := AType;
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(AAddr, GetPtrType);
  EmitInstr(Instr);
  Result := Instr.ResultId;
end;

procedure THIRBuilder.EmitStore(AType: THIRTypeId;
  AVal, AAddr: THIRValueId);
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikStore;
  Instr.TypeId := AType;
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeTypedOperand(AVal, AType);
  Instr.Operands[1] := MakeTypedOperand(AAddr, GetPtrType);
  EmitInstr(Instr);
end;

