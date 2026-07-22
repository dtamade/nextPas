procedure THIRBuilder.EmitExprInt(var S: TExprStack; const AArg: string);
var
  Instr: THIRInstr;
  Value: Int64;
  Code: LongInt;
  IntType: THIRTypeId;
begin
  Val(AArg, Value, Code);
  if Code <> 0 then
    IntType := GetIntType
  else if (Value >= -128) and (Value <= 127) then
    IntType := GetIntTypeByWidth(8, True)
  else if (Value >= -32768) and (Value <= 32767) then
    IntType := GetIntTypeByWidth(16, True)
  else if (Value >= -2147483648) and (Value <= 2147483647) then
    IntType := GetIntTypeByWidth(32, True)
  else
    IntType := GetIntType;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := IntType;
  Instr.IntrinsicName := 'const:' + AArg;
  EmitInstr(Instr);
  S.PushTyped(Instr.ResultId, IntType);
end;

procedure THIRBuilder.EmitExprNull(var S: TExprStack);
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'null';
  EmitInstr(Instr);
  S.PushTyped(Instr.ResultId, GetPtrType);
end;

procedure THIRBuilder.EmitExprVar(var S: TExprStack; const AArg: string);
var
  Instr: THIRInstr;
  V, TsSlot, LenVal: THIRValueId;
  ConstVal: Int64;
  BaseName: string;
begin
  V := FindAlloca(AArg);

  { Handle $len for TString vars: only $ts alloca exists, compute tstring_len on the fly }
  if (V = 0) and (Length(AArg) > 4) and
    (Copy(AArg, Length(AArg) - 3, 4) = '$len') then
  begin
    BaseName := Copy(AArg, 1, Length(AArg) - 4);
    TsSlot := FindAlloca(BaseName + '$ts');
    if TsSlot <> 0 then
    begin
      LenVal := EmitTStringLen(TsSlot);
      S.Push(LenVal);
      Exit;
    end;
  end;
  if (V = 0) and (Pos('.', AArg) > 0) then
  begin
    EnsureAlloca(AArg, GetIntType);
    V := FindAlloca(AArg);
  end;
  if V <> 0 then
  begin
    if IsVarParamAlloca(AArg) then
    begin
      V := EmitLoad(GetPtrType, V);
      S.Push(EmitLoad(FindAllocaType(AArg), V));
    end
    else if FindAllocaType(AArg) = GetPtrType then
      S.PushTyped(EmitLoad(GetPtrType, V), GetPtrType)
    else
      S.Push(EmitLoad(FindAllocaType(AArg), V));
  end
  else if FSemaModel.LookupConstValue(AArg, ConstVal) then
  begin
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikLoad;
    Instr.TypeId := GetIntType;
    Instr.IntrinsicName := 'const:' + IntToStr(ConstVal);
    EmitInstr(Instr);
    S.Push(Instr.ResultId);
  end
  else
  begin
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikCall;
    Instr.TypeId := GetIntType;
    Instr.CallTarget := AArg;
    EmitInstr(Instr);
    S.Push(Instr.ResultId);
  end;
end;

procedure THIRBuilder.EmitExprVarRef(var S: TExprStack; const AArg: string);
var
  V: THIRValueId;
  I: LongInt;
  Instr: THIRInstr;
begin
  V := FindAlloca(AArg);
  if V <> 0 then
  begin
    if IsVarParamAlloca(AArg) then
      S.PushTyped(EmitLoad(GetPtrType, V), GetPtrType)
    else
      S.PushTyped(V, GetPtrType);
  end
  else
  begin
    if FGlobalNames.Count > 0 then
      for I := 0 to LongInt(FGlobalNames.Count) - 1 do
      if SameText(FGlobalNames[I], AArg) then
      begin
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikIntrinsic;
        Instr.TypeId := GetPtrType;
        Instr.IntrinsicName := 'global_ref';
        Instr.CallTarget := AArg;
        EmitInstr(Instr);
        S.PushTyped(Instr.ResultId, GetPtrType);
        Exit;
      end;
  end;
end;

procedure THIRBuilder.EmitExprRecVar(var S: TExprStack; const AArg: string);
var
  V: THIRValueId;
begin
  V := FindAlloca(AArg);
  if V <> 0 then
    S.PushTyped(V, GetPtrType);
end;

procedure THIRBuilder.EmitExprStrVar(var S: TExprStack; const AArg: string);
var
  TsSlot, DataPtr, LenVal: THIRValueId;
begin
  TsSlot := FindAlloca(AArg + '$ts');
  if TsSlot = 0 then
    Exit;

  DataPtr := EmitTStringData(TsSlot);
  LenVal := EmitTStringLen(TsSlot);
  if (DataPtr = 0) or (LenVal = 0) then
    Exit;

  S.PushTyped(DataPtr, GetPtrType);
  S.PushTyped(LenVal, GetIntTypeByWidth(32, True));
end;

procedure THIRBuilder.EmitExprStrLit(var S: TExprStack; const AArg: string);
var
  Instr: THIRInstr;
  LenVal: THIRValueId;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'str_const';
  Instr.CallTarget := AArg;
  EmitInstr(Instr);
  S.PushTyped(Instr.ResultId, GetPtrType);

  LenVal := EmitConstIntOfType(Length(AArg) - 2, GetIntTypeByWidth(32, True));
  if LenVal <> 0 then
    S.PushTyped(LenVal, GetIntTypeByWidth(32, True));
end;

procedure THIRBuilder.EmitExprIs(var S: TExprStack; const AArg: string);
var
  Instr: THIRInstr;
  V, Rhs: THIRValueId;
begin
  Rhs := S.Pop;
  EnsureVmtForClass(AArg);
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:0';
  EmitInstr(Instr);
  V := Instr.ResultId;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(Rhs);
  Instr.Operands[1] := MakeOperand(V);
  EmitInstr(Instr);
  V := EmitLoad(GetPtrType, Instr.ResultId);
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'is_instance';
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(V, GetPtrType);
  Instr.CallTarget := AArg;
  EmitInstr(Instr);
  S.Push(Instr.ResultId);
end;

procedure THIRBuilder.EmitExprArrLoad(var S: TExprStack);
var
  Instr: THIRInstr;
  V, Rhs: THIRValueId;
begin
  Rhs := S.Pop;
  V := S.Pop;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(V);
  Instr.Operands[1] := MakeOperand(Rhs);
  EmitInstr(Instr);
  S.Push(EmitLoad(GetIntType, Instr.ResultId));
end;

procedure THIRBuilder.EmitExprArrLoadPtr(var S: TExprStack);
var
  Instr: THIRInstr;
  V, Rhs: THIRValueId;
begin
  Rhs := S.Pop;
  V := S.Pop;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(V);
  Instr.Operands[1] := MakeOperand(Rhs);
  EmitInstr(Instr);
  S.PushTyped(EmitLoad(GetPtrType, Instr.ResultId), GetPtrType);
end;

procedure THIRBuilder.EmitExprArrElemRef(var S: TExprStack; const AArg: string);
var
  Instr: THIRInstr;
  BaseAlloca, BasePtr, IndexVal: THIRValueId;
begin
  IndexVal := S.Pop;
  IndexVal := NormalizeArrayIndexValue(AArg, IndexVal);
  BaseAlloca := FindAlloca(AArg + '$ptr');
  if BaseAlloca = 0 then
    Exit;
  BasePtr := EmitLoad(GetPtrType, BaseAlloca);
  if BasePtr = 0 then
    Exit;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeTypedOperand(BasePtr, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(IndexVal, GetIntType);
  EmitInstr(Instr);
  S.PushTyped(Instr.ResultId, GetPtrType);
end;

procedure THIRBuilder.EmitExprFieldRef(var S: TExprStack; const AArg: string);
var
  Instr: THIRInstr;
  BasePtr, FieldIndexValue: THIRValueId;
  BaseType: THIRTypeId;
  FieldIndex: LongInt;
begin
  BasePtr := S.PopTyped(BaseType);
  if BasePtr = 0 then
    Exit;
  if (BaseType <> 0) and
    (FModule.Types.GetType(BaseType).Kind <> htkPointer) then
    Exit;
  FieldIndex := StrToIntDef(AArg, -1);
  if FieldIndex < 0 then
    Exit;

  FieldIndexValue := EmitConstIntOfType(FieldIndex, GetIntType);
  if FieldIndexValue = 0 then
    Exit;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeTypedOperand(BasePtr, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(FieldIndexValue, GetIntType);
  EmitInstr(Instr);
  S.PushTyped(Instr.ResultId, GetPtrType);
end;

procedure THIRBuilder.EmitExprRLoad(var S: TExprStack; const AArg: string);
var
  Instr: THIRInstr;
  V, IdxVal: THIRValueId;
  RecName: string;
  FieldIdx, ValCode, SpacePos: LongInt;
begin
  SpacePos := Pos(' ', AArg);
  if SpacePos = 0 then Exit;
  RecName := Copy(AArg, 1, SpacePos - 1);
  Val(Copy(AArg, SpacePos + 1, Length(AArg)), FieldIdx, ValCode);
  if ValCode <> 0 then Exit;
  V := FindAlloca(RecName);
  if V = 0 then Exit;
  if FindAllocaType(RecName) = GetPtrType then
    V := EmitLoad(GetPtrType, V);
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:' + IntToStr(FieldIdx);
  EmitInstr(Instr);
  IdxVal := Instr.ResultId;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(V);
  Instr.Operands[1] := MakeOperand(IdxVal);
  EmitInstr(Instr);
  S.Push(EmitLoad(GetIntType, Instr.ResultId));
end;

procedure THIRBuilder.EmitExprFieldStrLen(var S: TExprStack; const AArg: string);
var
  Instr: THIRInstr;
  V, Rhs, LenVal: THIRValueId;
  Target, Rest: string;
  FieldIdx, SpacePos: LongInt;
begin
  { Length(Self.FName) / Length(R.S): GEP to inline TString field, then
    np_tstring_len(field_ptr). Arg format: "<base> <fieldIdx>".
    Class/var-param slots hold a pointer; local record allocas/globals are the
    buffer itself (same rule as ProcessAssignTStringFieldLoad). }
  SpacePos := Pos(' ', AArg);
  if SpacePos > 0 then
  begin
    Target := Copy(AArg, 1, SpacePos - 1);
    Rest := Copy(AArg, SpacePos + 1, Length(AArg));
    FieldIdx := StrToIntDef(Rest, 0);
  end
  else
  begin
    Target := AArg;
    FieldIdx := 0;
  end;
  V := FindAlloca(Target);
  if V = 0 then
    Exit;
  if FindAllocaType(Target) = GetPtrType then
    V := EmitLoad(GetPtrType, V);
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:' + IntToStr(FieldIdx);
  EmitInstr(Instr);
  Rhs := Instr.ResultId;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(V);
  Instr.Operands[1] := MakeOperand(Rhs);
  EmitInstr(Instr);
  LenVal := EmitTStringLen(Instr.ResultId);
  if LenVal <> 0 then
    S.PushTyped(LenVal, GetIntTypeByWidth(64, True));
end;

procedure THIRBuilder.EmitExprUnaryOp(var S: TExprStack; AKind: THIRInstrKind;
  const AIntrinsic: string);
var
  Instr: THIRInstr;
  OperandType: THIRTypeId;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := AKind;
  Instr.Operands[0] := MakeTypedOperand(S.Pop, OperandType);
  if OperandType <> 0 then
    Instr.TypeId := OperandType
  else
    Instr.TypeId := GetIntType;
  if AIntrinsic <> '' then
    Instr.IntrinsicName := AIntrinsic;
  SetLength(Instr.Operands, 1);
  EmitInstr(Instr);
  S.PushTyped(Instr.ResultId, Instr.TypeId);
end;

procedure THIRBuilder.EmitExprBinOp(var S: TExprStack; AKind: THIRInstrKind);
var
  Lhs, Rhs: THIRValueId;
  LhsType, RhsType, ResultType: THIRTypeId;
begin
  Rhs := S.PopTyped(RhsType);
  Lhs := S.PopTyped(LhsType);
  { 使用操作数类型，优先选择更宽的类型 }
  if (LhsType <> 0) and (RhsType <> 0) then
  begin
    if FModule.Types.GetType(LhsType).BitWidth >= FModule.Types.GetType(RhsType).BitWidth then
      ResultType := LhsType
    else
      ResultType := RhsType;
  end
  else if LhsType <> 0 then
    ResultType := LhsType
  else if RhsType <> 0 then
    ResultType := RhsType
  else
    ResultType := GetIntType;
  S.PushTyped(EmitBinOp(AKind, ResultType, Lhs, Rhs), ResultType);
end;

procedure THIRBuilder.EmitExprCmp(var S: TExprStack; const AArg: string);
var
  Lhs, Rhs: THIRValueId;
  LhsType, RhsType: THIRTypeId;
  Kind: THIRInstrKind;
begin
  Rhs := S.PopTyped(RhsType);
  Lhs := S.PopTyped(LhsType);
  if AArg = 'eq' then Kind := hikCmpEq
  else if AArg = 'ne' then Kind := hikCmpNe
  else if AArg = 'slt' then Kind := hikCmpLt
  else if AArg = 'sle' then Kind := hikCmpLe
  else if AArg = 'sgt' then Kind := hikCmpGt
  else if AArg = 'sge' then Kind := hikCmpGe
  else Exit;
  S.Push(EmitCmpOp(Kind, GetBoolType, Lhs, Rhs, LhsType, RhsType));
end;

procedure THIRBuilder.EmitExprStrCmp(var S: TExprStack; const AArg: string);
var
  APtr, ALen, BPtr, BLen, ResultVal, OneVal: THIRValueId;
  PtrType, LenType: THIRTypeId;
  Instr: THIRInstr;
begin
  BLen := S.PopTyped(LenType);
  BPtr := S.PopTyped(PtrType);
  ALen := S.PopTyped(LenType);
  APtr := S.PopTyped(PtrType);
  if (APtr = 0) or (ALen = 0) or (BPtr = 0) or (BLen = 0) then
    Exit;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetIntTypeByWidth(32, True);
  Instr.IntrinsicName := 'str_cmp';
  Instr.CallTarget := AArg;
  SetLength(Instr.Operands, 4);
  Instr.Operands[0] := MakeTypedOperand(APtr, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(ALen, GetIntTypeByWidth(32, True));
  Instr.Operands[2] := MakeTypedOperand(BPtr, GetPtrType);
  Instr.Operands[3] := MakeTypedOperand(BLen, GetIntTypeByWidth(32, True));
  EmitInstr(Instr);
  ResultVal := Instr.ResultId;

  if SameText(AArg, 'ne') then
  begin
    OneVal := EmitConstIntSmart(1);
    if OneVal = 0 then
      Exit;
    ResultVal := EmitBinOp(hikSub, GetIntTypeByWidth(32, True), OneVal, ResultVal);
  end;

  S.PushTyped(ResultVal, GetIntTypeByWidth(32, True));
end;

procedure THIRBuilder.EmitExprZext(var S: TExprStack);
begin
  EmitExprUnaryOp(S, hikZext, '');
end;

procedure THIRBuilder.EmitExprCall(var S: TExprStack; const AArg: string);
var
  Instr: THIRInstr;
  CallArgs: array of THIRValueId;
  CallArgTypes: array of THIRTypeId;
  Target, Rest: string;
  ArgCount, J, SpacePos: LongInt;
begin
  SpacePos := Pos(' ', AArg);
  if SpacePos > 0 then
  begin
    Target := Copy(AArg, 1, SpacePos - 1);
    Rest := Copy(AArg, SpacePos + 1, Length(AArg));
    ArgCount := StrToIntDef(Rest, 0);
  end
  else
  begin
    Target := AArg;
    ArgCount := 0;
  end;
  SetLength(CallArgs, ArgCount);
  SetLength(CallArgTypes, ArgCount);
  for J := ArgCount - 1 downto 0 do
    CallArgs[J] := S.PopTyped(CallArgTypes[J]);
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikCall;
  Instr.TypeId := FModule.FindFunctionReturnType(Target);
  if Instr.TypeId = 0 then
  begin
    Instr.TypeId := GetIntType;
    if FFwdFuncNames.Count > 0 then
      for J := 0 to LongInt(FFwdFuncNames.Count) - 1 do
        if FFwdFuncNames[J] = Target then
        begin
          Instr.TypeId := FFwdFuncRetTypes[J];
          Break;
        end;
  end;
  Instr.CallTarget := Target;
  SetLength(Instr.Operands, ArgCount);
  for J := 0 to ArgCount - 1 do
  begin
    if CallArgTypes[J] <> 0 then
      Instr.Operands[J] := MakeTypedOperand(CallArgs[J], CallArgTypes[J])
    else
      Instr.Operands[J] := MakeOperand(CallArgs[J]);
  end;
  EmitInstr(Instr);
  if FModule.Types.GetType(Instr.TypeId).Kind = htkPointer then
    S.PushTyped(Instr.ResultId, Instr.TypeId)
  else
    S.Push(Instr.ResultId);
end;

procedure THIRBuilder.EmitExprArrLoadVar(var S: TExprStack; const AArg: string);
var
  Instr: THIRInstr;
  V, Rhs: THIRValueId;
  VarName: string;
  IsPtr: Boolean;
begin
  IsPtr := (Length(AArg) > 2) and (Copy(AArg, Length(AArg) - 1, 2) = ' p');
  if IsPtr then
    VarName := Copy(AArg, 1, Length(AArg) - 2)
  else
    VarName := AArg;
  Rhs := S.Pop;
  Rhs := NormalizeArrayIndexValue(VarName, Rhs);
  V := FindAlloca(VarName + '$ptr');
  if V = 0 then
  begin
    S.Push(Rhs);
    Exit;
  end;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetPtrType;
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeOperand(V);
  EmitInstr(Instr);
  V := Instr.ResultId;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(V);
  Instr.Operands[1] := MakeOperand(Rhs);
  EmitInstr(Instr);
  if IsPtr then
    S.PushTyped(EmitLoad(GetPtrType, Instr.ResultId), GetPtrType)
  else
    S.Push(EmitLoad(GetIntType, Instr.ResultId));
end;

procedure THIRBuilder.EmitExprField(var S: TExprStack; const AArg: string);
var
  Instr: THIRInstr;
  V, Rhs: THIRValueId;
  Target, Rest: string;
  FieldIdx, SpacePos: LongInt;
begin
  SpacePos := Pos(' ', AArg);
  if SpacePos > 0 then
  begin
    Target := Copy(AArg, 1, SpacePos - 1);
    Rest := Copy(AArg, SpacePos + 1, Length(AArg));
    SpacePos := Pos(' ', Rest);
    if SpacePos > 0 then
      FieldIdx := StrToIntDef(Copy(Rest, 1, SpacePos - 1), 0)
    else
      FieldIdx := StrToIntDef(Rest, 0);
  end
  else
  begin
    Target := AArg;
    Rest := '';
    FieldIdx := 0;
  end;
  V := FindAlloca(Target);
  if V = 0 then Exit;
  V := EmitLoad(GetPtrType, V);
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:' + IntToStr(FieldIdx);
  EmitInstr(Instr);
  Rhs := Instr.ResultId;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(V);
  Instr.Operands[1] := MakeOperand(Rhs);
  EmitInstr(Instr);
  if Pos(' p', Rest) > 0 then
    S.PushTyped(EmitLoad(GetPtrType, Instr.ResultId), GetPtrType)
  else
    S.Push(EmitLoad(GetIntType, Instr.ResultId));
end;

