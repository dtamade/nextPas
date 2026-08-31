procedure THIRBuilder.EmitExprInt(var S: TExprStack; const AArg: string);
var
  Instr: THIRInstr;
  IntType: THIRTypeId;
begin
  { Residual stack path is i64-centric (calls, memset len, binops). Narrow
    consts (i8/i32) pollute SSA notes and force broken trunc/sext chains. }
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
  V, TsSlot, LenVal, DataPtr: THIRValueId;
  ConstVal: Int64;
  FloatConstVal: Double;
  BaseName: string;
  LenType: THIRTypeId;
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
      { Must keep i64 type: untyped push lets `Length(S)-2` collapse to i8. }
      S.PushTyped(LenVal, GetIntTypeByWidth(64, True));
      Exit;
    end;
    { Dynarr dual-slot: Name$ptr + Name$len. Never residual-call @Name$len().
      Late RegisterRuntimeArrVar / class-misseed may leave $len missing — create. }
    LenType := GetIntTypeByWidth(32, True);
    if (FindAlloca(BaseName + '$ptr') <> 0) or (FindAlloca(BaseName) <> 0) or
      (FindAlloca(AArg) = 0) then
    begin
      EnsureAlloca(AArg, LenType);
      V := FindAlloca(AArg);
      if V <> 0 then
      begin
        S.PushTyped(EmitLoad(LenType, V), LenType);
        Exit;
      end;
    end;
  end;
  { TString locals/params only register Name$ts. Scalar uses like
    PAnsiChar(APath) encode as `var APath` — never residual-call @APath().
    Surface the payload pointer (matches PChar/PAnsiChar cast of string). }
  if V = 0 then
  begin
    TsSlot := FindAlloca(AArg + '$ts');
    if TsSlot <> 0 then
    begin
      DataPtr := EmitTStringData(TsSlot);
      if DataPtr <> 0 then
      begin
        S.PushTyped(DataPtr, GetPtrType);
        Exit;
      end;
    end;
  end;
  { Open-array formals only register Name$ptr / Name$len. Bare `var Name`
    must not residual-call @Name(); prefer arrvar ABI (ptr then len). }
  if V = 0 then
  begin
    TsSlot := FindAlloca(AArg + '$ptr');
    if TsSlot <> 0 then
    begin
      S.PushTyped(EmitLoad(GetPtrType, TsSlot), GetPtrType);
      LenVal := FindAlloca(AArg + '$len');
      if LenVal <> 0 then
        S.Push(EmitLoad(GetIntTypeByWidth(32, True), LenVal))
      else
        S.PushTyped(EmitConstIntOfType(0, GetIntTypeByWidth(32, True)),
          GetIntTypeByWidth(32, True));
      Exit;
    end;
  end;
  { Nested-in-method bodies reference outer 'self' with no static link.
    Zeroed local alloca (same policy as outer-frame captures) — never
    residual-call @self(). }
  if (V = 0) and (AArg = 'self') then
  begin
    EnsureAlloca(AArg, GetPtrType);
    V := FindAlloca(AArg);
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
      if FindAllocaType(AArg) <> 0 then
        S.PushTyped(EmitLoad(FindAllocaType(AArg), V), FindAllocaType(AArg))
      else
        S.PushTyped(EmitLoad(GetIntType, V), GetIntType);
    end
    else if FindAllocaType(AArg) = GetPtrType then
      S.PushTyped(EmitLoad(GetPtrType, V), GetPtrType)
    else if FindAllocaType(AArg) <> 0 then
      S.PushTyped(EmitLoad(FindAllocaType(AArg), V), FindAllocaType(AArg))
    else
      S.PushTyped(EmitLoad(GetIntType, V), GetIntType);
  end
  else if FSemaModel.LookupConstValue(AArg, ConstVal) then
  begin
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikLoad;
    Instr.TypeId := GetIntType;
    Instr.IntrinsicName := 'const:' + IntToStr(ConstVal);
    EmitInstr(Instr);
    S.PushTyped(Instr.ResultId, GetIntType);
  end
  else if FSemaModel.LookupFloatConstValue(AArg, FloatConstVal) then
  begin
    { Residual stack path is i64-centric (store/cmp/binop). Pushing bare
      double from hikConstFloat yields `store i64 %f` / `icmp ptr, double`
      type errors (opt first after HALF_PI seed). Reinterpret bits as i64 —
      same shape as the old residual @Name() i64 call, without undeclared. }
    Move(FloatConstVal, ConstVal, SizeOf(ConstVal));
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikLoad;
    Instr.TypeId := GetIntType;
    Instr.IntrinsicName := 'const:' + IntToStr(ConstVal);
    EmitInstr(Instr);
    S.PushTyped(Instr.ResultId, GetIntType);
  end
  else
  begin
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikCall;
    Instr.TypeId := GetIntType;
    Instr.CallTarget := AArg;
    EmitInstr(Instr);
    S.PushTyped(Instr.ResultId, GetIntType);
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
  if V = 0 then
    Exit;
  { const/var record formals allocate a ptr slot (points at the real buffer).
    Local record allocas are the buffer itself. Match field-load / field-store:
    only load when the slot is ptr-typed — otherwise sret helpers like
    EnvelopeSelectorName(AState) receive ptr-to-ptr and return garbage strings. }
  if FindAllocaType(AArg) = GetPtrType then
    V := EmitLoad(GetPtrType, V);
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
  { np_tstring_len is i64; stack type must match or str_cmp coerces with bad sext. }
  S.PushTyped(LenVal, GetIntTypeByWidth(64, True));
end;

procedure THIRBuilder.EmitExprTsData(var S: TExprStack; const AArg: string);
var
  TsSlot, DataPtr: THIRValueId;
begin
  { Char-buffer address of a TString (untyped-const formals like
    CompareByte's buf params). Slot is the bare 24B alloca for locals/params;
    const-formal materializations use Name$ts (b4b-i8). }
  TsSlot := FindAlloca(AArg);
  if TsSlot = 0 then
    TsSlot := FindAlloca(AArg + '$ts');
  if TsSlot = 0 then
    Exit;
  DataPtr := EmitTStringData(TsSlot);
  if DataPtr <> 0 then
    S.PushTyped(DataPtr, GetPtrType);
end;

procedure THIRBuilder.EmitExprStrLit(var S: TExprStack; const AArg: string);
var
  Instr: THIRInstr;
  LenVal: THIRValueId;
  LitLen: Int64;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'str_const';
  Instr.CallTarget := AArg;
  EmitInstr(Instr);
  S.PushTyped(Instr.ResultId, GetPtrType);

  { np_str_cmp / tstring_from_literal use i64 lengths. Quoted form '' is
    length 2 with payload 0 — keep i64 so empty strlit compares type-check. }
  LitLen := Length(AArg);
  if LitLen >= 2 then
    Dec(LitLen, 2)
  else
    LitLen := 0;
  LenVal := EmitConstIntOfType(LitLen, GetIntTypeByWidth(64, True));
  if LenVal <> 0 then
    S.PushTyped(LenVal, GetIntTypeByWidth(64, True));
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

procedure THIRBuilder.EmitExprStrChr(var S: TExprStack; const AArg: string);
var
  Instr: THIRInstr;
  IdxVal, Slot, Data, ChrPtr, Ch8: THIRValueId;
begin
  { Pascal strings are 1-based: byte address = data + (idx-1). Stack on
    entry holds [idx]; push the constant then let BinOp pop Rhs,Lhs. }
  S.Push(EmitConstInt(1));
  EmitExprBinOp(S, hikSub);
  IdxVal := S.Pop;
  Slot := FindAlloca(AArg + '$ts');
  if (Slot = 0) or (IdxVal = 0) then
    Exit;
  Data := EmitTStringData(Slot);
  if Data = 0 then
    Exit;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  { Byte-scaled GEP — gep_i64 would multiply the char index by 8. }
  Instr.IntrinsicName := 'gep_i8';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(Data);
  Instr.Operands[1] := MakeOperand(IdxVal);
  EmitInstr(Instr);
  ChrPtr := Instr.ResultId;
  { Byte load then widen — the blob language is i64-domained. }
  Ch8 := EmitLoad(GetIntTypeByWidth(8, False), ChrPtr);
  S.PushTyped(Ch8, GetIntTypeByWidth(8, False));
  EmitExprZext(S);
end;

procedure THIRBuilder.EmitExprArrElemRef(var S: TExprStack; const AArg: string);
var
  Instr: THIRInstr;
  BaseAlloca, BasePtr, IndexVal: THIRValueId;
  IsBarePtr: Boolean;
begin
  IndexVal := S.Pop;
  IndexVal := NormalizeArrayIndexValue(AArg, IndexVal);
  BaseAlloca := FindAlloca(AArg + '$ptr');
  IsBarePtr := False;
  if BaseAlloca = 0 then
  begin
    { Pointer params (PAnsiChar/PChar) register only the bare name alloca
      (ptr-typed slot); index into it directly instead of dropping the base. }
    BaseAlloca := FindAlloca(AArg);
    IsBarePtr := True;
  end;
  if BaseAlloca = 0 then
    Exit;
  BasePtr := EmitLoad(GetPtrType, BaseAlloca);
  if BasePtr = 0 then
    Exit;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  { Bare pointer params have 1-byte elements (Char); $ptr arrays scale by
    elem size in i64 units via gep_i64. }
  if IsBarePtr then
    Instr.IntrinsicName := 'gep_i8'
  else
    Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeTypedOperand(BasePtr, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(IndexVal, GetIntType);
  EmitInstr(Instr);
  S.PushTyped(Instr.ResultId, GetPtrType);
end;

procedure THIRBuilder.EmitExprPtrElemLoad(var S: TExprStack; const AArg: string);
var
  Instr: THIRInstr;
  SpacePos, ElemBytes, LoadBits: LongInt;
  Name: string;
  BaseAlloca, BasePtr, IndexVal, ElemAddr: THIRValueId;
  LoadType: THIRTypeId;
begin
  { AArg = "<ptrname> <elembytes>", index already on stack. Numeric pointee
    (PInt32) element value: gep scaled by pointee size + load width. }
  SpacePos := Pos(' ', AArg);
  if SpacePos <= 0 then
    Exit;
  Name := Copy(AArg, 1, SpacePos - 1);
  ElemBytes := StrToIntDef(Copy(AArg, SpacePos + 1, Length(AArg)), 1);
  IndexVal := S.Pop;
  BaseAlloca := FindAlloca(Name);
  if (BaseAlloca = 0) or (IndexVal = 0) then
    Exit;
  BasePtr := EmitLoad(GetPtrType, BaseAlloca);
  if BasePtr = 0 then
    Exit;
  IndexVal := NormalizeArrayIndexValue(Name, IndexVal);
  if IndexVal = 0 then
    Exit;

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
  Instr.Operands[1] := MakeTypedOperand(IndexVal, GetIntType);
  EmitInstr(Instr);
  ElemAddr := Instr.ResultId;

  LoadBits := ElemBytes * 8;
  LoadType := GetIntTypeByWidth(LoadBits, True);
  S.PushTyped(EmitLoad(LoadType, ElemAddr), LoadType);
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
  S.PushTyped(EmitLoad(GetIntType, Instr.ResultId), GetIntType);
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
  OperandVal: THIRValueId;
begin
  { Must PopTyped + SetLength before Operands[0] write — empty dynarray AV. }
  OperandVal := S.PopTyped(OperandType);
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := AKind;
  if AKind = hikZext then
    Instr.TypeId := GetIntType
  else if OperandType <> 0 then
    Instr.TypeId := OperandType
  else
    Instr.TypeId := GetIntType;
  if AIntrinsic <> '' then
    Instr.IntrinsicName := AIntrinsic;
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(OperandVal, OperandType);
  EmitInstr(Instr);
  S.PushTyped(Instr.ResultId, Instr.TypeId);
end;

procedure THIRBuilder.EmitExprBinOp(var S: TExprStack; AKind: THIRInstrKind);
var
  Lhs, Rhs: THIRValueId;
  LhsType, RhsType, ResultType: THIRTypeId;
  LhsW, RhsW: LongInt;
begin
  Rhs := S.PopTyped(RhsType);
  Lhs := S.PopTyped(LhsType);
  { Prefer wider typed operand. Untyped side often hides i64 (Length/call);
    never let a lone i8/i16 const force the whole op narrow. }
  if (LhsType <> 0) and (RhsType <> 0) then
  begin
    LhsW := FModule.Types.GetType(LhsType).BitWidth;
    RhsW := FModule.Types.GetType(RhsType).BitWidth;
    if LhsW >= RhsW then
      ResultType := LhsType
    else
      ResultType := RhsType;
  end
  else if LhsType <> 0 then
  begin
    if FModule.Types.GetType(LhsType).BitWidth >= 32 then
      ResultType := LhsType
    else
      ResultType := GetIntType;
  end
  else if RhsType <> 0 then
  begin
    if FModule.Types.GetType(RhsType).BitWidth >= 32 then
      ResultType := RhsType
    else
      ResultType := GetIntType;
  end
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
  APtr, ALen, BPtr, BLen, ResultVal: THIRValueId;
  PtrType, ALenType, BLenType, Len64: THIRTypeId;
  Instr: THIRInstr;
begin
  Len64 := GetIntTypeByWidth(64, True);
  BLen := S.PopTyped(BLenType);
  BPtr := S.PopTyped(PtrType);
  ALen := S.PopTyped(ALenType);
  APtr := S.PopTyped(PtrType);
  if (APtr = 0) or (ALen = 0) or (BPtr = 0) or (BLen = 0) then
    Exit;

  { Coerce by bit-width, not TypeId identity — multiple i64 TypeIds exist. }
  if (ALenType = 0) or (FModule.Types.GetType(ALenType).BitWidth <> 64) then
  begin
    ALen := NormalizeScalarValueToType(ALen, ALenType, Len64);
    if ALen = 0 then
      Exit;
  end;
  if (BLenType = 0) or (FModule.Types.GetType(BLenType).BitWidth <> 64) then
  begin
    BLen := NormalizeScalarValueToType(BLen, BLenType, Len64);
    if BLen = 0 then
      Exit;
  end;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := Len64;
  Instr.IntrinsicName := 'str_cmp';
  Instr.CallTarget := AArg;
  SetLength(Instr.Operands, 4);
  Instr.Operands[0] := MakeTypedOperand(APtr, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(ALen, Len64);
  Instr.Operands[2] := MakeTypedOperand(BPtr, GetPtrType);
  Instr.Operands[3] := MakeTypedOperand(BLen, Len64);
  EmitInstr(Instr);
  ResultVal := Instr.ResultId;

  { Emitter already xors for CallTarget='ne'; do not double-invert here. }
  S.PushTyped(ResultVal, Len64);
end;

procedure THIRBuilder.EmitExprStrPos(var S: TExprStack);
var
  NeedlePtr, NeedleLen, HayPtr, HayLen: THIRValueId;
  PtrType, NeedleLenType, HayLenType, Len64: THIRTypeId;
  Instr: THIRInstr;
begin
  { Residual order: needle (ptr,len) then haystack (ptr,len).
    np_str_pos(sub_ptr, sub_len, s_ptr, s_len) → 1-based index or 0. }
  Len64 := GetIntTypeByWidth(64, True);
  HayLen := S.PopTyped(HayLenType);
  HayPtr := S.PopTyped(PtrType);
  NeedleLen := S.PopTyped(NeedleLenType);
  NeedlePtr := S.PopTyped(PtrType);
  if (NeedlePtr = 0) or (NeedleLen = 0) or (HayPtr = 0) or (HayLen = 0) then
    Exit;

  if (NeedleLenType = 0) or (FModule.Types.GetType(NeedleLenType).BitWidth <> 64) then
  begin
    NeedleLen := NormalizeScalarValueToType(NeedleLen, NeedleLenType, Len64);
    if NeedleLen = 0 then
      Exit;
  end;
  if (HayLenType = 0) or (FModule.Types.GetType(HayLenType).BitWidth <> 64) then
  begin
    HayLen := NormalizeScalarValueToType(HayLen, HayLenType, Len64);
    if HayLen = 0 then
      Exit;
  end;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := Len64;
  Instr.IntrinsicName := 'str_pos';
  SetLength(Instr.Operands, 4);
  Instr.Operands[0] := MakeTypedOperand(NeedlePtr, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(NeedleLen, Len64);
  Instr.Operands[2] := MakeTypedOperand(HayPtr, GetPtrType);
  Instr.Operands[3] := MakeTypedOperand(HayLen, Len64);
  EmitInstr(Instr);
  S.PushTyped(Instr.ResultId, Len64);
end;

procedure THIRBuilder.EmitExprZext(var S: TExprStack);
begin
  EmitExprUnaryOp(S, hikZext, '');
end;

procedure THIRBuilder.EmitExprInterlocked(var S: TExprStack; const AArg: string);
var
  Instr: THIRInstr;
  TargetPtr, NewVal, CmpVal: THIRValueId;
  TargetType, NewType, CmpType: THIRTypeId;
  IsCas: Boolean;

  { atomicrmw/cmpxchg operate on i64; pointer-swap call sites hand us ptr
    values — ptrtoint them (same policy as ProcessInterlockedOp). }
  function ToInt(const AValueId: THIRValueId;
    const ASourceTypeId: THIRTypeId): THIRValueId;
  begin
    Result := AValueId;
    if (AValueId = 0) or (ASourceTypeId = 0) or
      (ASourceTypeId = GetIntType) then
      Exit;
    Result := NormalizeScalarValueToType(AValueId, ASourceTypeId, GetIntType);
    if Result = 0 then
      Result := AValueId;
  end;

begin
  { Stack (push order): target-addr, new-value[, compare-value]. }
  IsCas := (AArg = 'cas') or (AArg = 'cas64');
  CmpVal := 0;
  if IsCas then
  begin
    CmpVal := S.PopTyped(CmpType);
    CmpVal := ToInt(CmpVal, CmpType);
  end;
  NewVal := S.PopTyped(NewType);
  NewVal := ToInt(NewVal, NewType);
  TargetPtr := S.PopTyped(TargetType);
  if (TargetPtr = 0) or (NewVal = 0) or (IsCas and (CmpVal = 0)) then
    Exit;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetIntType;
  if AArg = 'cas' then
    Instr.IntrinsicName := 'interlocked-cas'
  else if AArg = 'cas64' then
    Instr.IntrinsicName := 'interlocked-cas64'
  else if AArg = 'add' then
    Instr.IntrinsicName := 'interlocked-fetch-add'
  else if AArg = 'add64' then
    Instr.IntrinsicName := 'interlocked-fetch-add64'
  else
    Instr.IntrinsicName := 'interlocked-xchg';
  if IsCas then
  begin
    SetLength(Instr.Operands, 3);
    Instr.Operands[0] := MakeTypedOperand(TargetPtr, GetPtrType);
    Instr.Operands[1] := MakeTypedOperand(NewVal, GetIntType);
    Instr.Operands[2] := MakeTypedOperand(CmpVal, GetIntType);
  end
  else
  begin
    SetLength(Instr.Operands, 2);
    Instr.Operands[0] := MakeTypedOperand(TargetPtr, GetPtrType);
    Instr.Operands[1] := MakeTypedOperand(NewVal, GetIntType);
  end;
  EmitInstr(Instr);
  S.PushTyped(Instr.ResultId, GetIntType);
end;

procedure THIRBuilder.EmitExprCall(var S: TExprStack; const AArg: string);
var
  Instr: THIRInstr;
  CallArgs: array of THIRValueId;
  CallArgTypes: array of THIRTypeId;
  Target, Rest: string;
  ArgCount, J, SpacePos: LongInt;
  SemaTypeId: LongInt;
  TargetHirType, SourceHirType: THIRTypeId;
  Casted, CalleeSlot, CalleeVal: THIRValueId;
  Fact: TSemanticScalarTypeFact;
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

  { Type-name "call" is a cast: PUInt64(x) / Pointer(x) / Byte(x). Never emit
    call @TypeName — lower via scalar/pointer cast classification. }
  if (ArgCount = 1) and (FSemaModel <> nil) and (Target <> '') then
  begin
    SemaTypeId := FSemaModel.FindTypeByName(Target);
    if (SemaTypeId > 0) and FSemaModel.GetTypeScalarFact(SemaTypeId, Fact) and
      (Fact.Kind in [sskBool, sskInt, sskFloat, sskPointer]) then
    begin
      TargetHirType := SemanticTypeIdToHirTypeId(SemaTypeId);
      SourceHirType := CallArgTypes[0];
      if SourceHirType = 0 then
      begin
        if Fact.Kind = sskPointer then
          SourceHirType := GetIntType
        else
          SourceHirType := GetIntType;
      end;
      if TargetHirType <> 0 then
      begin
        Casted := NormalizeScalarValueToType(CallArgs[0], SourceHirType,
          TargetHirType);
        if Casted <> 0 then
        begin
          S.PushTyped(Casted, TargetHirType);
          Exit;
        end;
      end;
    end;
  end;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
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

  { Procedural formal: call through local/param slot, not residual @Name. }
  CalleeSlot := FindAlloca(Target);
  if CalleeSlot <> 0 then
  begin
    Instr.Kind := hikIndirectCall;
    Instr.CallTarget := Target;
    if FindAllocaType(Target) = GetPtrType then
      CalleeVal := EmitLoad(GetPtrType, CalleeSlot)
    else if IsVarParamAlloca(Target) then
      CalleeVal := EmitLoad(GetPtrType, EmitLoad(GetPtrType, CalleeSlot))
    else
      CalleeVal := EmitLoad(GetIntType, CalleeSlot);
    SetLength(Instr.Operands, ArgCount + 1);
    if FindAllocaType(Target) = GetPtrType then
      Instr.Operands[0] := MakeTypedOperand(CalleeVal, GetPtrType)
    else if IsVarParamAlloca(Target) then
      Instr.Operands[0] := MakeTypedOperand(CalleeVal, GetPtrType)
    else
      Instr.Operands[0] := MakeTypedOperand(CalleeVal, GetIntType);
    for J := 0 to ArgCount - 1 do
    begin
      if CallArgTypes[J] <> 0 then
        Instr.Operands[J + 1] := MakeTypedOperand(CallArgs[J], CallArgTypes[J])
      else
        Instr.Operands[J + 1] := MakeOperand(CallArgs[J]);
    end;
    EmitInstr(Instr);
    if Instr.TypeId <> 0 then
      S.PushTyped(Instr.ResultId, Instr.TypeId)
    else
      S.PushTyped(Instr.ResultId, GetIntType);
    Exit;
  end;

  Instr.Kind := hikCall;
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
  if Instr.TypeId <> 0 then
    S.PushTyped(Instr.ResultId, Instr.TypeId)
  else
    S.PushTyped(Instr.ResultId, GetIntType);
end;

procedure THIRBuilder.EmitExprICall(var S: TExprStack; const AArg: string);
var
  Instr: THIRInstr;
  CallArgs: array of THIRValueId;
  CallArgTypes: array of THIRTypeId;
  ArgCount, J: LongInt;
  Callee: THIRValueId;
  CalleeType: THIRTypeId;
begin
  { Stack order: args pushed first, then callee; pop callee then args. }
  ArgCount := StrToIntDef(AArg, 0);
  Callee := S.PopTyped(CalleeType);
  SetLength(CallArgs, ArgCount);
  SetLength(CallArgTypes, ArgCount);
  for J := ArgCount - 1 downto 0 do
    CallArgs[J] := S.PopTyped(CallArgTypes[J]);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIndirectCall;
  Instr.TypeId := GetIntType;
  Instr.CallTarget := '';
  SetLength(Instr.Operands, ArgCount + 1);
  if (CalleeType <> 0) and (CalleeType = GetPtrType) then
    Instr.Operands[0] := MakeTypedOperand(Callee, GetPtrType)
  else
    Instr.Operands[0] := MakeTypedOperand(Callee, GetIntType);
  for J := 0 to ArgCount - 1 do
  begin
    if CallArgTypes[J] <> 0 then
      Instr.Operands[J + 1] := MakeTypedOperand(CallArgs[J], CallArgTypes[J])
    else
      Instr.Operands[J + 1] := MakeOperand(CallArgs[J]);
  end;
  EmitInstr(Instr);
  S.PushTyped(Instr.ResultId, GetIntType);
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

procedure THIRBuilder.EmitExprTsLoad(var S: TExprStack; const AArg: string);
var
  Instr: THIRInstr;
  BasePtr, IndexVal, Scale, ByteOff, DataPtr, LenVal: THIRValueId;
begin
  { String-array element as (data,len): pop index (and base when no arg),
    scale by the 24-byte TString stride, then read through the runtime
    accessors so SSO/heap variants both work. With AArg the base comes from
    the <name>$ptr slot (open-array/local dynarray); without it the base ptr
    must already be on the stack (field arrays via 'field ... p'). }
  IndexVal := S.Pop;
  if AArg <> '' then
  begin
    BasePtr := FindAlloca(AArg + '$ptr');
    if BasePtr = 0 then
      Exit;
    IndexVal := NormalizeArrayIndexValue(AArg, IndexVal);
    BasePtr := EmitLoad(GetPtrType, BasePtr);
  end
  else
    BasePtr := S.Pop;
  if (BasePtr = 0) or (IndexVal = 0) then
    Exit;

  Scale := EmitConstIntOfType(24, GetIntType);
  if Scale = 0 then
    Exit;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikMul;
  Instr.TypeId := GetIntType;
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeTypedOperand(IndexVal, GetIntType);
  Instr.Operands[1] := MakeTypedOperand(Scale, GetIntType);
  EmitInstr(Instr);
  ByteOff := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i8';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeTypedOperand(BasePtr, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(ByteOff, GetIntType);
  EmitInstr(Instr);

  DataPtr := EmitTStringData(Instr.ResultId);
  LenVal := EmitTStringLen(Instr.ResultId);
  if (DataPtr = 0) or (LenVal = 0) then
    Exit;
  S.PushTyped(DataPtr, GetPtrType);
  S.PushTyped(LenVal, GetIntTypeByWidth(64, True));
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

