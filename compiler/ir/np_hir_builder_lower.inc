function THIRBuilder.CanLowerExprKind(const AExpr: TSemanticHirExpr): Boolean;
var
  I: LongInt;
  Kind: THIRInstrKind;
  Symbol: TSemanticSymbol;
  ResultType, LeftType, RightType: THIRTypeId;
  NoOp: Boolean;
begin
  case AExpr.Kind of
    shekIntLiteral:
      Result := ExprHirTypeId(AExpr) <> 0;
    shekSymbolValue:
      begin
        if AExpr.SymbolId <= 0 then
          Exit(False);
        Symbol := FSemaModel.SymbolAt(AExpr.SymbolId - 1);
        Result := (Symbol.Name <> '') and (ExprHirTypeId(AExpr) <> 0);
      end;
    shekSymbolAddress:
      begin
        if AExpr.SymbolId <= 0 then
          Exit(False);
        Symbol := FSemaModel.SymbolAt(AExpr.SymbolId - 1);
        Result := (Symbol.Name <> '') and (AExpr.ValueClass = shvcAddress);
      end;
    shekAddressOf:
      begin
        ResultType := ExprHirTypeId(AExpr);
        Result := (SemanticHirChildCount(AExpr.Children) >= 1) and
          (ResultType <> 0) and
          (FModule.Types.GetType(ResultType).Kind = htkPointer) and
          CanLowerExprAsAddress(AExpr.Children[SizeUInt(0)]);
      end;
    shekDeref:
      begin
        Result := (SemanticHirChildCount(AExpr.Children) >= 1) and
          (AExpr.ValueClass = shvcAddress) and CanLowerExpr(AExpr.Children[SizeUInt(0)]);
        if Result then
        begin
          LeftType := ExprIdHirTypeId(AExpr.Children[SizeUInt(0)]);
          Result := (LeftType <> 0) and
            (FModule.Types.GetType(LeftType).Kind = htkPointer);
        end;
      end;
    shekField:
      Result := (SemanticHirChildCount(AExpr.Children) >= 1) and
        (AExpr.TypeId > 0) and (AExpr.ValueClass in [shvcScalar, shvcAddress]) and
        (AExpr.LiteralInt >= 0) and
        CanLowerExpr(AExpr.Children[SizeUInt(0)]);
    shekArrayElem:
      begin
        Result := (AExpr.TypeId > 0) and
          (AExpr.ValueClass = shvcAddress);
        if not Result then
          Exit(False);
        if AExpr.SymbolId > 0 then
        begin
          Symbol := FSemaModel.SymbolAt(AExpr.SymbolId - 1);
          Result := (Symbol.Name <> '') and (SemanticHirChildCount(AExpr.Children) >= 1) and
            CanLowerExpr(AExpr.Children[SizeUInt(0)]);
          if Result then
          begin
            LeftType := ExprIdHirTypeId(AExpr.Children[SizeUInt(0)]);
            Result := HirTypeIsInt(LeftType);
          end;
          Exit;
        end;
        Result := (AExpr.SymbolId = 0) and (SemanticHirChildCount(AExpr.Children) >= 2) and
          CanLowerExprAsAddress(AExpr.Children[SizeUInt(0)]) and
          CanLowerExpr(AExpr.Children[SizeUInt(1)]);
        if Result then
        begin
          LeftType := ExprIdHirTypeId(AExpr.Children[SizeUInt(1)]);
          Result := HirTypeIsInt(LeftType);
        end;
      end;
    shekCast:
      begin
        Result := (SemanticHirChildCount(AExpr.Children) >= 1) and
          (ExprHirTypeId(AExpr) <> 0) and CanLowerExpr(AExpr.Children[SizeUInt(0)]);
        if Result then
        begin
          LeftType := ExprIdHirTypeId(AExpr.Children[SizeUInt(0)]);
          Result := TryClassifyScalarCast(LeftType, ExprHirTypeId(AExpr),
            Kind, NoOp);
        end;
      end;
    shekUnaryOp:
      begin
        Result := ((AExpr.Op = '-') or SameText(AExpr.Op, 'abs') or
          SameText(AExpr.Op, 'not')) and (SemanticHirChildCount(AExpr.Children) >= 1) and
          (ExprHirTypeId(AExpr) <> 0) and CanLowerExpr(AExpr.Children[SizeUInt(0)]);
        if Result and SameText(AExpr.Op, 'not') then
          Result := HirTypeIsBool(ExprIdHirTypeId(AExpr.Children[SizeUInt(0)])) and
            HirTypeIsBool(ExprHirTypeId(AExpr));
        if Result and ((AExpr.Op = '-') or SameText(AExpr.Op, 'abs')) then
          Result := HirTypeIsInt(ExprHirTypeId(AExpr)) and
            (ExprHirTypeId(AExpr) = ExprIdHirTypeId(AExpr.Children[SizeUInt(0)]));
      end;
    shekBinaryOp:
      begin
        ResultType := ExprHirTypeId(AExpr);
        Result := (SemanticHirChildCount(AExpr.Children) >= 2) and
          (ResultType <> 0) and
          (BinaryKindForOp(AExpr.Op, Kind) or SameText(AExpr.Op, 'and') or
           SameText(AExpr.Op, 'or'));
        if Result then
          for I := 0 to 1 do
            if not CanLowerExpr(AExpr.Children[SizeUInt(I)]) then
              Exit(False);
        if Result and BinaryKindForOp(AExpr.Op, Kind) then
        begin
          LeftType := ExprIdHirTypeId(AExpr.Children[SizeUInt(0)]);
          RightType := ExprIdHirTypeId(AExpr.Children[SizeUInt(1)]);
          Result := HirTypeIsInt(ResultType) and (LeftType = ResultType) and
            (RightType = ResultType);
        end;
        if Result and (SameText(AExpr.Op, 'and') or SameText(AExpr.Op, 'or')) then
        begin
          LeftType := ExprIdHirTypeId(AExpr.Children[SizeUInt(0)]);
          RightType := ExprIdHirTypeId(AExpr.Children[SizeUInt(1)]);
          Result := HirTypeIsBool(ResultType) and HirTypeIsBool(LeftType) and
            HirTypeIsBool(RightType);
        end;
      end;
    shekCompareOp:
      begin
        ResultType := ExprHirTypeId(AExpr);
        Result := (SemanticHirChildCount(AExpr.Children) >= 2) and
          (ResultType <> 0) and HirTypeIsBool(ResultType) and
          CompareKindForOp(AExpr.Op, Kind);
        if Result then
          for I := 0 to 1 do
            if not CanLowerExpr(AExpr.Children[SizeUInt(I)]) then
              Exit(False);
        if Result then
        begin
          LeftType := ExprIdHirTypeId(AExpr.Children[SizeUInt(0)]);
          RightType := ExprIdHirTypeId(AExpr.Children[SizeUInt(1)]);
          Result := (LeftType <> 0) and (LeftType = RightType) and
            (HirTypeIsInt(LeftType) or HirTypeIsBool(LeftType) or
             (FModule.Types.GetType(LeftType).Kind = htkPointer));
        end;
      end;
    shekCall:
      begin
        ResultType := ExprHirTypeId(AExpr);
        Result := (AExpr.ValueClass = shvcScalar) and
          (AExpr.LiteralStr <> '') and
          (SemanticHirChildCount(AExpr.Children) = Length(AExpr.Op)) and
          (HirTypeIsInt(ResultType) or
           (FModule.Types.GetType(ResultType).Kind = htkPointer));
        if not Result then
          Exit(False);
        for I := 0 to (SemanticHirChildCount(AExpr.Children) - 1) do
        begin
          if not (AExpr.Op[I + 1] in ['i', 'p', 'r']) then
            Exit(False);
          if AExpr.Op[I + 1] = 'r' then
          begin
            if not CanLowerExprAsAddress(AExpr.Children[SizeUInt(I)]) then
              Exit(False);
          end
          else if not CanLowerExpr(AExpr.Children[SizeUInt(I)]) then
            Exit(False);
        end;
      end;
    shekVirtualCall, shekInterfaceCall:
      begin
        ResultType := ExprHirTypeId(AExpr);
        Result := (AExpr.ValueClass = shvcScalar) and
          (AExpr.LiteralStr <> '') and
          (AExpr.LiteralInt >= 0) and
          (SemanticHirChildCount(AExpr.Children) = Length(AExpr.Op)) and
          (SemanticHirChildCount(AExpr.Children) >= 1) and
          (AExpr.Op <> '') and (AExpr.Op[1] = 'p') and
          (HirTypeIsInt(ResultType) or
           (FModule.Types.GetType(ResultType).Kind = htkPointer)) and
          CanLowerExprAsAddress(AExpr.Children[SizeUInt(0)]);
        if not Result then
          Exit(False);
        for I := 1 to (SemanticHirChildCount(AExpr.Children) - 1) do
        begin
          if not (AExpr.Op[I + 1] in ['i', 'p', 'r']) then
            Exit(False);
          if AExpr.Op[I + 1] = 'r' then
          begin
            if not CanLowerExprAsAddress(AExpr.Children[SizeUInt(I)]) then
              Exit(False);
          end
          else if not CanLowerExpr(AExpr.Children[SizeUInt(I)]) then
            Exit(False);
        end;
      end;
  else
    Result := False;
  end;
end;

function THIRBuilder.CanLowerExpr(const AExprId: LongInt): Boolean;
var
  Expr: TSemanticHirExpr;
begin
  if (FSemaModel = nil) or (AExprId <= 0) then
    Exit(False);
  if AExprId > FSemaModel.HirExprCount then
    Exit(False);
  Expr := FSemaModel.HirExprAt(AExprId - 1);
  Result := CanLowerExprKind(Expr);
end;

function THIRBuilder.CanLowerExprAsAddress(const AExprId: LongInt): Boolean;
var
  Expr: TSemanticHirExpr;
begin
  if (FSemaModel = nil) or (AExprId <= 0) then
    Exit(False);
  if AExprId > FSemaModel.HirExprCount then
    Exit(False);
  if not CanLowerExpr(AExprId) then
    Exit(False);
  Expr := FSemaModel.HirExprAt(AExprId - 1);
  Result := Expr.ValueClass = shvcAddress;
end;

function THIRBuilder.EmitConstFloat(const AValue: Double): THIRValueId;
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikConstFloat;
  Instr.TypeId := GetFloatType;
  Instr.FloatValue := AValue;
  EmitInstr(Instr);
  Result := Instr.ResultId;
end;

function THIRBuilder.EmitConstInt(const AValue: Int64): THIRValueId;
begin
  Result := EmitConstIntOfType(AValue, GetIntType);
end;

{ 根据值范围推断类型的整数常量 }
function THIRBuilder.EmitConstIntSmart(const AValue: Int64): THIRValueId;
var
  IntType: THIRTypeId;
begin
  if (AValue >= -128) and (AValue <= 127) then
    IntType := GetIntTypeByWidth(8, True)
  else if (AValue >= -32768) and (AValue <= 32767) then
    IntType := GetIntTypeByWidth(16, True)
  else if (AValue >= -2147483648) and (AValue <= 2147483647) then
    IntType := GetIntTypeByWidth(32, True)
  else
    IntType := GetIntType;
  Result := EmitConstIntOfType(AValue, IntType);
end;

function THIRBuilder.EmitConstIntOfType(const AValue: Int64;
  const ATypeId: THIRTypeId): THIRValueId;
var
  Instr: THIRInstr;
begin
  if ATypeId = 0 then
    Exit(0);
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := ATypeId;
  Instr.IntrinsicName := 'const:' + IntToStr(AValue);
  EmitInstr(Instr);
  Result := Instr.ResultId;
end;

function THIRBuilder.EmitNullPtrValue: THIRValueId;
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'null';
  EmitInstr(Instr);
  Result := Instr.ResultId;
end;

function THIRBuilder.ParseArrayDeclOperand(const AOperand: string;
  out AName: string; out AIsStatic: Boolean; out ALow, AHigh,
  ALength: Int64): Boolean;
var
  TabPos, Code: LongInt;
  Rest, Field: string;

  function TakeField(var AText: string; out AField: string): Boolean;
  var
    PosTab: LongInt;
  begin
    PosTab := Pos(#9, AText);
    if PosTab = 0 then
    begin
      AField := AText;
      AText := '';
    end
    else
    begin
      AField := Copy(AText, 1, PosTab - 1);
      AText := Copy(AText, PosTab + 1, Length(AText));
    end;
    Result := AField <> '';
  end;

begin
  AName := AOperand;
  AIsStatic := False;
  ALow := 0;
  AHigh := -1;
  ALength := 0;
  if AOperand = '' then
    Exit(False);

  TabPos := Pos(#9, AOperand);
  if TabPos = 0 then
    Exit(True);

  AName := Copy(AOperand, 1, TabPos - 1);
  Rest := Copy(AOperand, TabPos + 1, Length(AOperand));
  if not TakeField(Rest, Field) then
    Exit(True);
  if not SameText(Field, 'static') then
    Exit(True);
  if not TakeField(Rest, Field) then
    Exit(True);
  Val(Field, ALow, Code);
  if Code <> 0 then
    Exit(True);
  if not TakeField(Rest, Field) then
    Exit(True);
  Val(Field, AHigh, Code);
  if Code <> 0 then
    Exit(True);
  if not TakeField(Rest, Field) then
    Exit(True);
  Val(Field, ALength, Code);
  if Code <> 0 then
    Exit(True);
  AIsStatic := ALength > 0;
  Result := True;
end;

procedure THIRBuilder.EmitStaticArrayBacking(const AName: string;
  const ALength: Int64);
var
  Instr: THIRInstr;
  PtrSlot, LenSlot, LenValue: THIRValueId;
begin
  if (AName = '') or (ALength <= 0) then
    Exit;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikAlloca;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'record:' + IntToStr(ALength);
  EmitInstr(Instr);

  RegisterAllocaEntry(AName + '$storage', Instr.ResultId, GetIntType, False);
  if FAllocas.Count > 0 then
    FAllocas.GetPtr(FAllocas.Count - 1)^.RecordSlots := ALength;

  PtrSlot := FindAlloca(AName + '$ptr');
  LenSlot := FindAlloca(AName + '$len');
  if PtrSlot <> 0 then
    EmitStore(GetPtrType, Instr.ResultId, PtrSlot);
  if LenSlot <> 0 then
  begin
    LenValue := EmitConstIntOfType(ALength, GetIntTypeByWidth(32, True));
    if LenValue <> 0 then
      EmitStore(GetIntTypeByWidth(32, True), LenValue, LenSlot);
  end;
end;

procedure THIRBuilder.InitializeDynArraySlots(const AName: string);
var
  PtrSlot, LenSlot, NullPtr, ZeroLen: THIRValueId;
begin
  if AName = '' then
    Exit;
  PtrSlot := FindAlloca(AName + '$ptr');
  LenSlot := FindAlloca(AName + '$len');
  if (PtrSlot = 0) or (LenSlot = 0) then
    Exit;
  NullPtr := EmitNullPtrValue;
  ZeroLen := EmitConstIntSmart(0);
  if (NullPtr = 0) or (ZeroLen = 0) then
    Exit;
  EmitStore(GetPtrType, NullPtr, PtrSlot);
  EmitStore(GetIntTypeByWidth(32, True), ZeroLen, LenSlot);
end;

function THIRBuilder.NormalizeArrayIndexValue(const AArrayName: string;
  const AIndexValue: THIRValueId): THIRValueId;
var
  LowBound: Int64;
  LowValue: THIRValueId;
  Instr: THIRInstr;
begin
  Result := AIndexValue;
  if (AArrayName = '') or (AIndexValue = 0) then
    Exit;
  if (FSemaModel = nil) or
    (not FSemaModel.LookupConstValue(AArrayName + '$arr_low', LowBound)) then
    Exit;
  if LowBound = 0 then
    Exit;

  LowValue := EmitConstIntOfType(LowBound, GetIntType);
  if LowValue = 0 then
    Exit;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikSub;
  Instr.TypeId := GetIntType;
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeTypedOperand(AIndexValue, GetIntType);
  Instr.Operands[1] := MakeTypedOperand(LowValue, GetIntType);
  EmitInstr(Instr);
  Result := Instr.ResultId;
end;

function THIRBuilder.BinaryKindForOp(const AOp: string;
  out AKind: THIRInstrKind): Boolean;
begin
  if AOp = '+' then AKind := hikAdd
  else if AOp = '-' then AKind := hikSub
  else if AOp = '*' then AKind := hikMul
  else if SameText(AOp, 'div') or (AOp = '/') then AKind := hikDiv
  else if SameText(AOp, 'mod') then AKind := hikMod
  else
    Exit(False);
  Result := True;
end;

function THIRBuilder.CompareKindForOp(const AOp: string;
  out AKind: THIRInstrKind): Boolean;
begin
  if (AOp = '=') or SameText(AOp, 'eq') then AKind := hikCmpEq
  else if (AOp = '<>') or SameText(AOp, 'ne') then AKind := hikCmpNe
  else if (AOp = '<') or SameText(AOp, 'slt') then AKind := hikCmpLt
  else if (AOp = '<=') or SameText(AOp, 'sle') then AKind := hikCmpLe
  else if (AOp = '>') or SameText(AOp, 'sgt') then AKind := hikCmpGt
  else if (AOp = '>=') or SameText(AOp, 'sge') then AKind := hikCmpGe
  else
    Exit(False);
  Result := True;
end;

function THIRBuilder.EmitStructuredSymbolValue(const AExpr: TSemanticHirExpr;
  out AResult: THIRExprResult): Boolean;
var
  Symbol: TSemanticSymbol;
  V: THIRValueId;
  Instr: THIRInstr;
  ConstVal: Int64;
  FloatConstVal: Double;
  HirType, StorageType: THIRTypeId;
begin
  InitExprResult(AResult);
  if AExpr.SymbolId <= 0 then
    Exit(False);
  Symbol := FSemaModel.SymbolAt(AExpr.SymbolId - 1);
  if Symbol.Name = '' then
    Exit(False);

  HirType := ExprHirTypeId(AExpr);
  if HirType = 0 then
    HirType := SemanticTypeIdToHirTypeId(Symbol.TypeId);
  if HirType = 0 then
    Exit(False);

  V := FindAlloca(Symbol.Name);
  if (V = 0) and (Pos('.', Symbol.Name) > 0) then
  begin
    EnsureAlloca(Symbol.Name, HirType);
    V := FindAlloca(Symbol.Name);
  end;
  if V <> 0 then
  begin
    StorageType := FindAllocaType(Symbol.Name);
    if IsVarParamAlloca(Symbol.Name) then
    begin
      V := EmitLoad(GetPtrType, V);
      SetExprValue(AResult, EmitLoad(HirType, V), HirType, shvcScalar);
    end
    else if StorageType = GetPtrType then
      SetExprValue(AResult, EmitLoad(GetPtrType, V), GetPtrType, shvcScalar)
    else if StorageType <> 0 then
    begin
      { Prefer storage type (local alloca or unit global) so load width matches
        declared @g_* / alloca; then cast to expression HirType if needed. }
      V := EmitLoad(StorageType, V);
      if StorageType <> HirType then
      begin
        V := NormalizeScalarValueToType(V, StorageType, HirType);
        if V = 0 then
          Exit(False);
      end;
      SetExprValue(AResult, V, HirType, shvcScalar);
    end
    else
      SetExprValue(AResult, EmitLoad(HirType, V), HirType, shvcScalar);
    Exit(AResult.ValueId <> 0);
  end;

  if FSemaModel.LookupConstValue(Symbol.Name, ConstVal) then
  begin
    SetExprValue(AResult, EmitConstIntOfType(ConstVal, HirType), HirType,
      shvcScalar);
    Exit(True);
  end;

  if FSemaModel.LookupFloatConstValue(Symbol.Name, FloatConstVal) then
  begin
    SetExprValue(AResult, EmitConstFloat(FloatConstVal), GetFloatType,
      shvcScalar);
    Exit(True);
  end;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikCall;
  Instr.TypeId := HirType;
  Instr.CallTarget := Symbol.Name;
  EmitInstr(Instr);
  SetExprValue(AResult, Instr.ResultId, HirType, shvcScalar);
  Result := True;
end;

function THIRBuilder.LowerSymbolAddressExpr(const AExpr: TSemanticHirExpr;
  out AResult: THIRExprResult): Boolean;
var
  Symbol: TSemanticSymbol;
  V: THIRValueId;
  HirType: THIRTypeId;
begin
  InitExprResult(AResult);
  if AExpr.SymbolId <= 0 then
    Exit(False);
  Symbol := FSemaModel.SymbolAt(AExpr.SymbolId - 1);
  if Symbol.Name = '' then
    Exit(False);

  HirType := ExprHirTypeId(AExpr);
  if HirType = 0 then
    HirType := SemanticTypeIdToHirTypeId(Symbol.TypeId);

  V := FindAlloca(Symbol.Name);
  if (V = 0) and (Pos('.', Symbol.Name) > 0) then
  begin
    if HirType <> 0 then
      EnsureAlloca(Symbol.Name, HirType);
    V := FindAlloca(Symbol.Name);
  end;
  if V = 0 then
    Exit(False);
  if IsVarParamAlloca(Symbol.Name) then
    V := EmitLoad(GetPtrType, V);
  SetExprAddress(AResult, V, HirType);
  Result := AResult.AddressValueId <> 0;
end;

function THIRBuilder.LowerAddressOfExpr(const AExpr: TSemanticHirExpr;
  out AResult: THIRExprResult): Boolean;
var
  Child: THIRExprResult;
  PointerType: THIRTypeId;
begin
  InitExprResult(AResult);
  if SemanticHirChildCount(AExpr.Children) < 1 then
    Exit(False);
  if not LowerExprAddress(AExpr.Children[SizeUInt(0)], Child) then
    Exit(False);
  PointerType := ExprHirTypeId(AExpr);
  if PointerType = 0 then
    Exit(False);
  if FModule.Types.GetType(PointerType).Kind <> htkPointer then
    Exit(False);
  SetExprValue(AResult, Child.AddressValueId, PointerType, shvcScalar);
  Result := AResult.ValueId <> 0;
end;

function THIRBuilder.LowerDerefExpr(const AExpr: TSemanticHirExpr;
  out AResult: THIRExprResult): Boolean;
var
  Child: THIRExprResult;
  HirType: THIRTypeId;
begin
  InitExprResult(AResult);
  if SemanticHirChildCount(AExpr.Children) < 1 then
    Exit(False);
  if not LowerExprValue(AExpr.Children[SizeUInt(0)], Child) then
    Exit(False);
  HirType := ExprHirTypeId(AExpr);
  if (Child.ValueId = 0) or (Child.TypeId = 0) then
    Exit(False);
  if FModule.Types.GetType(Child.TypeId).Kind <> htkPointer then
    Exit(False);
  SetExprAddress(AResult, Child.ValueId, HirType);
  Result := AResult.AddressValueId <> 0;
end;

function THIRBuilder.LowerFieldExpr(const AExpr: TSemanticHirExpr;
  out AResult: THIRExprResult): Boolean;
var
  Base: THIRExprResult;
  BaseExpr: TSemanticHirExpr;
  SemType: TSemanticType;
  FieldPtr, FieldIndexValue, BaseValue: THIRValueId;
  HirType, BaseHirType: THIRTypeId;
  Instr: THIRInstr;
  StructName: string;
begin
  InitExprResult(AResult);
  if (SemanticHirChildCount(AExpr.Children) < 1) or (AExpr.LiteralInt < 0) then
    Exit(False);

  HirType := ExprHirTypeId(AExpr);
  FieldIndexValue := EmitConstIntOfType(AExpr.LiteralInt, GetIntType);
  if FieldIndexValue = 0 then
    Exit(False);

  // Lower base expression first to determine value class
  if not LowerExpr(AExpr.Children[SizeUInt(0)], Base) then
    Exit(False);

  // Detect if base is a value-type record → use extractvalue instead of GEP
  BaseExpr := FSemaModel.HirExprAt(AExpr.Children[SizeUInt(0)] - 1);
  if (BaseExpr.TypeId > 0) and (BaseExpr.TypeId <= FSemaModel.TypeCount) then
  begin
    SemType := FSemaModel.TypeAt(BaseExpr.TypeId - 1);
    if SameText(SemType.Kind, 'record') then
      StructName := SemType.Name;
  end;

  if (StructName <> '') and (Base.ValueClass = shvcAddress) then
  begin
    // Value-type record via address: load the whole struct first, then extractvalue
    if Base.AddressValueId = 0 then
      Exit(False);
    BaseHirType := FModule.Types.FindByName(StructName);
    // Fall back to GEP if the struct type hasn't been registered in HIR type table yet
    if BaseHirType <> 0 then
    begin
      BaseValue := EmitLoad(BaseHirType, Base.AddressValueId);

      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikExtractField;
      Instr.TypeId := HirType;
      Instr.FieldIndex := AExpr.LiteralInt;
      Instr.StructTypeName := StructName;
      SetLength(Instr.Operands, 1);
      Instr.Operands[0] := MakeTypedOperand(BaseValue, BaseHirType);
      EmitInstr(Instr);
      SetExprValue(AResult, Instr.ResultId, HirType, shvcScalar);
      Result := AResult.ValueId <> 0;
      Exit;
    end
    else
      StructName := '';
  end;

  if (StructName <> '') then
  begin
    // Struct type found but not registered in HIR type table, or value path not taken:
    // fall through to GEP
  end;

  if (StructName = '') then
  begin
    // Pointer path: GEP (class field access, or record fallback)
    if Base.AddressValueId = 0 then
      Exit(False);
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetPtrType;
    Instr.IntrinsicName := 'gep_i64';
    SetLength(Instr.Operands, 2);
    Instr.Operands[0] := MakeTypedOperand(Base.AddressValueId, GetPtrType);
    Instr.Operands[1] := MakeTypedOperand(FieldIndexValue, GetIntType);
    EmitInstr(Instr);
    FieldPtr := Instr.ResultId;
    SetExprAddress(AResult, FieldPtr, HirType);
    Result := AResult.AddressValueId <> 0;
  end;
end;

function THIRBuilder.LowerArrayElemExpr(const AExpr: TSemanticHirExpr;
  out AResult: THIRExprResult): Boolean;
var
  Symbol: TSemanticSymbol;
  BaseResult, IndexResult: THIRExprResult;
  BaseAlloca, BasePtr, ElemPtr, IndexValue: THIRValueId;
  HirType: THIRTypeId;
  ElemBytes: LongInt;
  Instr: THIRInstr;
begin
  InitExprResult(AResult);
  if ((AExpr.SymbolId > 0) and (SemanticHirChildCount(AExpr.Children) < 1)) or
    ((AExpr.SymbolId = 0) and (SemanticHirChildCount(AExpr.Children) < 2)) then
    Exit(False);

  if AExpr.SymbolId > 0 then
  begin
    Symbol := FSemaModel.SymbolAt(AExpr.SymbolId - 1);
    if Symbol.Name = '' then
      Exit(False);
    if not LowerExprValue(AExpr.Children[SizeUInt(0)], IndexResult) then
      Exit(False);
  end
  else
  begin
    if not LowerExprAddress(AExpr.Children[SizeUInt(0)], BaseResult) then
      Exit(False);
    if BaseResult.AddressValueId = 0 then
      Exit(False);
    if not LowerExprValue(AExpr.Children[SizeUInt(1)], IndexResult) then
      Exit(False);
  end;

  if (IndexResult.ValueId = 0) or (not HirTypeIsInt(IndexResult.TypeId)) then
    Exit(False);

  IndexValue := NormalizeScalarValueToType(IndexResult.ValueId,
    IndexResult.TypeId, GetIntType);
  if IndexValue = 0 then
    Exit(False);
  if AExpr.SymbolId > 0 then
  begin
    BaseAlloca := FindAlloca(Symbol.Name + '$ptr');
    if BaseAlloca = 0 then
    begin
      { Pointer param (PInt32 aSrc — bare-name alloca, no $ptr dual slot):
        address = base + idx*elemsize. The old fallback dropped the base and
        left a dangling SSA (opt: use of undefined value %v…). }
      BaseAlloca := FindAlloca(Symbol.Name);
      if BaseAlloca = 0 then
        Exit(False);
      BasePtr := EmitLoad(GetPtrType, BaseAlloca);
      if BasePtr = 0 then
        Exit(False);
      IndexValue := NormalizeArrayIndexValue(Symbol.Name, IndexValue);
      if IndexValue = 0 then
        Exit(False);
      HirType := ExprHirTypeId(AExpr);
      ElemBytes := 1;
      if HirType <> 0 then
        ElemBytes := FModule.Types.GetType(HirType).BitWidth div 8;
      if ElemBytes < 1 then
        ElemBytes := 1;
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := GetPtrType;
      case ElemBytes of
        2: Instr.IntrinsicName := 'gep_i16';
        4: Instr.IntrinsicName := 'gep_i32';
        8: Instr.IntrinsicName := 'gep_i64';
      else Instr.IntrinsicName := 'gep_i8';
      end;
      SetLength(Instr.Operands, 2);
      Instr.Operands[0] := MakeTypedOperand(BasePtr, GetPtrType);
      Instr.Operands[1] := MakeTypedOperand(IndexValue, GetIntType);
      EmitInstr(Instr);
      ElemPtr := Instr.ResultId;
      SetExprAddress(AResult, ElemPtr, HirType);
      Result := AResult.AddressValueId <> 0;
      Exit;
    end;
    BasePtr := EmitLoad(GetPtrType, BaseAlloca);
    if BasePtr = 0 then
      Exit(False);
    IndexValue := NormalizeArrayIndexValue(Symbol.Name, IndexValue);
    if IndexValue = 0 then
      Exit(False);
  end
  else
  begin
    BasePtr := EmitLoad(GetPtrType, BaseResult.AddressValueId);
    if BasePtr = 0 then
      Exit(False);
  end;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeTypedOperand(BasePtr, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(IndexValue, GetIntType);
  EmitInstr(Instr);
  ElemPtr := Instr.ResultId;

  HirType := ExprHirTypeId(AExpr);
  SetExprAddress(AResult, ElemPtr, HirType);
  Result := AResult.AddressValueId <> 0;
end;

function THIRBuilder.LowerCompareExpr(const AExpr: TSemanticHirExpr;
  out AResult: THIRExprResult): Boolean;
var
  Lhs, Rhs: THIRExprResult;
  Kind: THIRInstrKind;
  ValueId: THIRValueId;
begin
  InitExprResult(AResult);
  if SemanticHirChildCount(AExpr.Children) < 2 then
    Exit(False);
  if not CompareKindForOp(AExpr.Op, Kind) then
    Exit(False);
  if not LowerExprValue(AExpr.Children[SizeUInt(0)], Lhs) then
    Exit(False);
  if not LowerExprValue(AExpr.Children[SizeUInt(1)], Rhs) then
    Exit(False);
  if (Lhs.TypeId = 0) or (Lhs.TypeId <> Rhs.TypeId) then
    Exit(False);
  ValueId := EmitCmpOp(Kind, GetBoolType, Lhs.ValueId, Rhs.ValueId,
    Lhs.TypeId, Rhs.TypeId);
  SetExprValue(AResult, ValueId, GetBoolType, shvcScalar);
  Result := True;
end;

function THIRBuilder.LowerCastExpr(const AExpr: TSemanticHirExpr;
  out AResult: THIRExprResult): Boolean;
var
  Child: THIRExprResult;
  TargetType: THIRTypeId;
  Kind: THIRInstrKind;
  NoOp: Boolean;
  Instr: THIRInstr;
begin
  InitExprResult(AResult);
  if SemanticHirChildCount(AExpr.Children) < 1 then
    Exit(False);
  if not LowerExprValue(AExpr.Children[SizeUInt(0)], Child) then
    Exit(False);
  TargetType := ExprHirTypeId(AExpr);
  if TargetType = 0 then
    Exit(False);
  if not TryClassifyScalarCast(Child.TypeId, TargetType, Kind, NoOp) then
    Exit(False);
  if NoOp then
  begin
    SetExprValue(AResult, Child.ValueId, TargetType, shvcScalar);
    Exit(True);
  end;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := Kind;
  Instr.TypeId := TargetType;
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(Child.ValueId, Child.TypeId);
  EmitInstr(Instr);
  SetExprValue(AResult, Instr.ResultId, TargetType, shvcScalar);
  Result := True;
end;

function THIRBuilder.LowerUnaryExpr(const AExpr: TSemanticHirExpr;
  out AResult: THIRExprResult): Boolean;
var
  Child: THIRExprResult;
  OneValue, ZextValue, SubValue, ZeroValue, CmpValue: THIRValueId;
  Instr: THIRInstr;
  ResultType, BoolIntType: THIRTypeId;
begin
  InitExprResult(AResult);
  if SemanticHirChildCount(AExpr.Children) < 1 then
    Exit(False);
  if not LowerExprValue(AExpr.Children[SizeUInt(0)], Child) then
    Exit(False);
  ResultType := ExprHirTypeId(AExpr);
  if ResultType = 0 then
    Exit(False);

  if AExpr.Op = '-' then
  begin
    if Child.TypeId <> ResultType then
      Exit(False);
    SetExprValue(AResult, EmitBinOp(hikSub, ResultType,
      EmitConstIntOfType(0, ResultType), Child.ValueId), ResultType,
      shvcScalar);
    Exit(True);
  end;

  if SameText(AExpr.Op, 'abs') then
  begin
    if Child.TypeId <> ResultType then
      Exit(False);
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := ResultType;
    Instr.IntrinsicName := 'abs';
    SetLength(Instr.Operands, 1);
    Instr.Operands[0] := MakeTypedOperand(Child.ValueId, Child.TypeId);
    EmitInstr(Instr);
    SetExprValue(AResult, Instr.ResultId, ResultType, shvcScalar);
    Exit(True);
  end;

  if SameText(AExpr.Op, 'not') then
  begin
    if (not HirTypeIsBool(Child.TypeId)) or
      (not HirTypeIsBool(ResultType)) then
      Exit(False);
    BoolIntType := GetIntTypeByWidth(32, True);
    OneValue := EmitConstIntOfType(1, BoolIntType);
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikZext;
    Instr.TypeId := BoolIntType;
    SetLength(Instr.Operands, 1);
    Instr.Operands[0] := MakeTypedOperand(Child.ValueId, Child.TypeId);
    EmitInstr(Instr);
    ZextValue := Instr.ResultId;
    SubValue := EmitBinOp(hikSub, BoolIntType, OneValue, ZextValue);
    ZeroValue := EmitConstIntOfType(0, BoolIntType);
    CmpValue := EmitCmpOp(hikCmpNe, GetBoolType, SubValue, ZeroValue,
      BoolIntType, BoolIntType);
    SetExprValue(AResult, CmpValue, GetBoolType, shvcScalar);
    Exit(True);
  end;

  Result := False;
end;

function THIRBuilder.LowerBinaryExpr(const AExpr: TSemanticHirExpr;
  out AResult: THIRExprResult): Boolean;
var
  Lhs, Rhs: THIRExprResult;
  Kind: THIRInstrKind;
  ValueId, LhsInt, RhsInt, ZeroValue: THIRValueId;
  Instr: THIRInstr;
  ResultType, BoolIntType: THIRTypeId;
begin
  InitExprResult(AResult);
  if SemanticHirChildCount(AExpr.Children) < 2 then
    Exit(False);
  if not LowerExprValue(AExpr.Children[SizeUInt(0)], Lhs) then
    Exit(False);
  if not LowerExprValue(AExpr.Children[SizeUInt(1)], Rhs) then
    Exit(False);
  ResultType := ExprHirTypeId(AExpr);
  if ResultType = 0 then
    Exit(False);

  if BinaryKindForOp(AExpr.Op, Kind) then
  begin
    if (Lhs.TypeId <> ResultType) or (Rhs.TypeId <> ResultType) then
      Exit(False);
    ValueId := EmitBinOp(Kind, ResultType, Lhs.ValueId, Rhs.ValueId);
    SetExprValue(AResult, ValueId, ResultType, shvcScalar);
    Exit(True);
  end;

  if SameText(AExpr.Op, 'and') or SameText(AExpr.Op, 'or') then
  begin
    if (not HirTypeIsBool(ResultType)) or (not HirTypeIsBool(Lhs.TypeId)) or
      (not HirTypeIsBool(Rhs.TypeId)) then
      Exit(False);
    BoolIntType := GetIntTypeByWidth(32, True);
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikZext;
    Instr.TypeId := BoolIntType;
    SetLength(Instr.Operands, 1);
    Instr.Operands[0] := MakeTypedOperand(Lhs.ValueId, Lhs.TypeId);
    EmitInstr(Instr);
    LhsInt := Instr.ResultId;

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikZext;
    Instr.TypeId := BoolIntType;
    SetLength(Instr.Operands, 1);
    Instr.Operands[0] := MakeTypedOperand(Rhs.ValueId, Rhs.TypeId);
    EmitInstr(Instr);
    RhsInt := Instr.ResultId;

    if SameText(AExpr.Op, 'and') then
      ValueId := EmitBinOp(hikMul, BoolIntType, LhsInt, RhsInt)
    else
      ValueId := EmitBinOp(hikAdd, BoolIntType, LhsInt, RhsInt);
    ZeroValue := EmitConstIntOfType(0, BoolIntType);
    ValueId := EmitCmpOp(hikCmpNe, GetBoolType, ValueId, ZeroValue,
      BoolIntType, BoolIntType);
    SetExprValue(AResult, ValueId, GetBoolType, shvcScalar);
    Exit(True);
  end;

  Result := False;
end;

function THIRBuilder.LowerExprKind(const AExpr: TSemanticHirExpr;
  out AResult: THIRExprResult): Boolean;
var
  ValueId: THIRValueId;
  HirType: THIRTypeId;
begin
  InitExprResult(AResult);
  case AExpr.Kind of
    shekIntLiteral:
      begin
        HirType := ExprHirTypeId(AExpr);
        if HirType = 0 then
          Exit(False);
        ValueId := EmitConstIntOfType(AExpr.LiteralInt, HirType);
        SetExprValue(AResult, ValueId, HirType, shvcScalar);
        Result := True;
      end;
    shekNilLiteral:
      begin
        SetExprValue(AResult, EmitNullPtrValue, GetPtrType, shvcScalar);
        Result := True;
      end;
    shekSymbolValue:
      Result := EmitStructuredSymbolValue(AExpr, AResult);
    shekSymbolAddress:
      Result := LowerSymbolAddressExpr(AExpr, AResult);
    shekAddressOf:
      Result := LowerAddressOfExpr(AExpr, AResult);
    shekDeref:
      Result := LowerDerefExpr(AExpr, AResult);
    shekField:
      Result := LowerFieldExpr(AExpr, AResult);
    shekArrayElem:
      Result := LowerArrayElemExpr(AExpr, AResult);
    shekCast:
      Result := LowerCastExpr(AExpr, AResult);
    shekUnaryOp:
      Result := LowerUnaryExpr(AExpr, AResult);
    shekBinaryOp:
      Result := LowerBinaryExpr(AExpr, AResult);
    shekCompareOp:
      Result := LowerCompareExpr(AExpr, AResult);
    shekCall:
      Result := LowerCallExpr(AExpr, AResult);
    shekVirtualCall, shekInterfaceCall:
      Result := LowerDispatchedCallExpr(AExpr, AResult);
  else
    Result := False;
  end;
end;

function THIRBuilder.LowerCallExpr(const AExpr: TSemanticHirExpr;
  out AResult: THIRExprResult): Boolean;
var
  Instr: THIRInstr;
  ChildResult, AddressResult: THIRExprResult;
  AbiResultType, ExpectedType, ResultType, SourceType: THIRTypeId;
  ArgValueId, CallValueId: THIRValueId;
  I: LongInt;
begin
  InitExprResult(AResult);
  ResultType := ExprHirTypeId(AExpr);
  if (AExpr.LiteralStr = '') or
    (SemanticHirChildCount(AExpr.Children) <> Length(AExpr.Op)) or
    (ResultType = 0) then
    Exit(False);
  if HirTypeIsInt(ResultType) then
    AbiResultType := GetIntType
  else if FModule.Types.GetType(ResultType).Kind = htkPointer then
    AbiResultType := GetPtrType
  else
    Exit(False);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikCall;
  Instr.TypeId := AbiResultType;
  Instr.CallTarget := AExpr.LiteralStr;
  SetLength(Instr.Operands, SemanticHirChildCount(AExpr.Children));
  for I := 0 to (SemanticHirChildCount(AExpr.Children) - 1) do
  begin
    case AExpr.Op[I + 1] of
      'i':
        begin
          if not LowerExprValue(AExpr.Children[SizeUInt(I)], ChildResult) then
            Exit(False);
          ExpectedType := GetIntType;
        end;
      'p':
        begin
          ExpectedType := GetPtrType;
          if not LowerExprValue(AExpr.Children[SizeUInt(I)], ChildResult) then
          begin
            if not LowerExprAddress(AExpr.Children[SizeUInt(I)], AddressResult) then
              Exit(False);
            if AddressResult.AddressValueId = 0 then
              Exit(False);
            Instr.Operands[I] := MakeTypedOperand(AddressResult.AddressValueId,
              ExpectedType);
            Continue;
          end;
        end;
      'r':
        begin
          if not LowerExprAddress(AExpr.Children[SizeUInt(I)], AddressResult) then
            Exit(False);
          if AddressResult.AddressValueId = 0 then
            Exit(False);
          Instr.Operands[I] := MakeTypedOperand(AddressResult.AddressValueId,
            GetPtrType);
          Continue;
        end;
    else
      Exit(False);
    end;
    SourceType := ChildResult.TypeId;
    if (ChildResult.ValueId = 0) or (SourceType = 0) then
      Exit(False);
    ArgValueId := NormalizeScalarValueToType(ChildResult.ValueId, SourceType,
      ExpectedType);
    if ArgValueId = 0 then
      Exit(False);
    Instr.Operands[I] := MakeTypedOperand(ArgValueId, ExpectedType);
  end;
  EmitInstr(Instr);
  CallValueId := Instr.ResultId;
  if AbiResultType <> ResultType then
  begin
    CallValueId := NormalizeScalarValueToType(CallValueId, AbiResultType,
      ResultType);
    if CallValueId = 0 then
      Exit(False);
  end;
  SetExprValue(AResult, CallValueId, ResultType, shvcScalar);
  Result := True;
end;

function THIRBuilder.LowerDispatchedCallExpr(const AExpr: TSemanticHirExpr;
  out AResult: THIRExprResult): Boolean;
var
  FnPtr, ReceiverPtr, SlotValue, TablePtr, TableSlotPtr: THIRValueId;
  Instr: THIRInstr;
  ChildResult, ReceiverResult, AddressResult: THIRExprResult;
  AbiResultType, ExpectedType, ResultType, SourceType: THIRTypeId;
  ArgValueId, CallValueId: THIRValueId;
  I: LongInt;
begin
  InitExprResult(AResult);
  ResultType := ExprHirTypeId(AExpr);
  if (AExpr.LiteralStr = '') or (AExpr.LiteralInt < 0) or
    (SemanticHirChildCount(AExpr.Children) <> Length(AExpr.Op)) or
    (SemanticHirChildCount(AExpr.Children) < 1) or (ResultType = 0) or
    (AExpr.Op = '') or (AExpr.Op[1] <> 'p') then
    Exit(False);

  if HirTypeIsInt(ResultType) then
    AbiResultType := GetIntType
  else if FModule.Types.GetType(ResultType).Kind = htkPointer then
    AbiResultType := GetPtrType
  else
    Exit(False);

  if not LowerExprAddress(AExpr.Children[SizeUInt(0)], ReceiverResult) then
    Exit(False);
  ReceiverPtr := ReceiverResult.AddressValueId;
  if ReceiverPtr = 0 then
    Exit(False);

  if AExpr.Kind = shekVirtualCall then
  begin
    SlotValue := EmitConstIntSmart(0);
    if SlotValue = 0 then
      Exit(False);

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetPtrType;
    Instr.IntrinsicName := 'gep_i64';
    SetLength(Instr.Operands, 2);
    Instr.Operands[0] := MakeTypedOperand(ReceiverPtr, GetPtrType);
    Instr.Operands[1] := MakeTypedOperand(SlotValue, GetIntType);
    EmitInstr(Instr);
    TablePtr := EmitLoad(GetPtrType, Instr.ResultId);

    SlotValue := EmitConstIntOfType(AExpr.LiteralInt + 1, GetIntType);
    if SlotValue = 0 then
      Exit(False);
  end
  else
  begin
    TablePtr := EmitLoad(GetPtrType, ReceiverPtr);
    SlotValue := EmitConstIntOfType(AExpr.LiteralInt, GetIntType);
    if (TablePtr = 0) or (SlotValue = 0) then
      Exit(False);
  end;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeTypedOperand(TablePtr, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(SlotValue, GetIntType);
  EmitInstr(Instr);
  TableSlotPtr := Instr.ResultId;
  FnPtr := EmitLoad(GetPtrType, TableSlotPtr);
  if FnPtr = 0 then
    Exit(False);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := AbiResultType;
  Instr.IntrinsicName := 'vcall';
  SetLength(Instr.Operands, SemanticHirChildCount(AExpr.Children) + 1);
  Instr.Operands[0] := MakeTypedOperand(FnPtr, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(ReceiverPtr, GetPtrType);
  for I := 1 to (SemanticHirChildCount(AExpr.Children) - 1) do
  begin
    case AExpr.Op[I + 1] of
      'i':
        begin
          if not LowerExprValue(AExpr.Children[SizeUInt(I)], ChildResult) then
            Exit(False);
          ExpectedType := GetIntType;
        end;
      'p':
        begin
          if not LowerExprValue(AExpr.Children[SizeUInt(I)], ChildResult) then
            Exit(False);
          ExpectedType := GetPtrType;
        end;
      'r':
        begin
          if not LowerExprAddress(AExpr.Children[SizeUInt(I)], AddressResult) then
            Exit(False);
          if AddressResult.AddressValueId = 0 then
            Exit(False);
          Instr.Operands[I + 1] := MakeTypedOperand(
            AddressResult.AddressValueId, GetPtrType);
          Continue;
        end;
    else
      Exit(False);
    end;
    SourceType := ChildResult.TypeId;
    if (ChildResult.ValueId = 0) or (SourceType = 0) then
      Exit(False);
    ArgValueId := NormalizeScalarValueToType(ChildResult.ValueId, SourceType,
      ExpectedType);
    if ArgValueId = 0 then
      Exit(False);
    Instr.Operands[I + 1] := MakeTypedOperand(ArgValueId, ExpectedType);
  end;
  EmitInstr(Instr);
  CallValueId := Instr.ResultId;
  if AbiResultType <> ResultType then
  begin
    CallValueId := NormalizeScalarValueToType(CallValueId, AbiResultType,
      ResultType);
    if CallValueId = 0 then
      Exit(False);
  end;
  SetExprValue(AResult, CallValueId, ResultType, shvcScalar);
  Result := True;
end;

function THIRBuilder.LowerExprValue(const AExprId: LongInt;
  out AResult: THIRExprResult): Boolean;
var
  AddressValueId: THIRValueId;
  TypeId: THIRTypeId;
begin
  Result := LowerExpr(AExprId, AResult);
  if not Result then
    Exit(False);
  if AResult.ValueClass = shvcScalar then
    Exit(AResult.ValueId <> 0);
  if AResult.ValueClass = shvcAddress then
  begin
    if (AResult.AddressValueId = 0) or (AResult.TypeId = 0) then
      Exit(False);
    AddressValueId := AResult.AddressValueId;
    TypeId := AResult.TypeId;
    SetExprValue(AResult, EmitLoad(TypeId, AddressValueId), TypeId,
      shvcScalar);
    Exit(AResult.ValueId <> 0);
  end;
  Result := False;
end;

function THIRBuilder.LowerExprAddress(const AExprId: LongInt;
  out AResult: THIRExprResult): Boolean;
begin
  Result := LowerExpr(AExprId, AResult);
  if not Result then
    Exit(False);
  Result := (AResult.ValueClass = shvcAddress) and
    (AResult.AddressValueId <> 0);
end;

function THIRBuilder.LowerExpr(const AExprId: LongInt;
  out AResult: THIRExprResult): Boolean;
var
  Expr: TSemanticHirExpr;
begin
  InitExprResult(AResult);
  if (FSemaModel = nil) or (AExprId <= 0) then
    Exit(False);
  if AExprId > FSemaModel.HirExprCount then
    Exit(False);
  if not CanLowerExpr(AExprId) then
    Exit(False);
  Expr := FSemaModel.HirExprAt(AExprId - 1);
  Result := LowerExprKind(Expr, AResult);
end;

function THIRBuilder.LowerNodeExprOrBlob(const ANode: TTypedHirNode;
  const AExprArg: string): THIRValueId;
var
  TypeId: THIRTypeId;
begin
  Result := LowerNodeExprOrBlobTyped(ANode, AExprArg, TypeId);
end;

function THIRBuilder.LowerNodeExprOrBlobTyped(const ANode: TTypedHirNode;
  const AExprArg: string; out ATypeId: THIRTypeId): THIRValueId;
var
  ExprResult: THIRExprResult;
begin
  ATypeId := 0;
  if (ANode.ExprId > 0) and LowerExprValue(ANode.ExprId, ExprResult) then
  begin
    ATypeId := ExprResult.TypeId;
    Exit(ExprResult.ValueId);
  end;
  Result := ParseIntExprArgTyped(AExprArg, ATypeId);
end;

function THIRBuilder.LowerNodeTargetExprAddress(const ANode: TTypedHirNode;
  out AResult: THIRExprResult): Boolean;
begin
  InitExprResult(AResult);
  if ANode.TargetExprId <= 0 then
    Exit(False);
  Result := LowerExprAddress(ANode.TargetExprId, AResult);
end;

