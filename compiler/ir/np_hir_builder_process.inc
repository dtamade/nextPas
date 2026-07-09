procedure THIRBuilder.EmitExprVcall(var S: TExprStack; AArg: string);
var
  Instr: THIRInstr;
  V, Rhs: THIRValueId;
  VcallArgs: array of THIRValueId;
  VcallArgTypes: array of THIRTypeId;
  RetType: THIRTypeId;
  SlotIdx, ExtraArgCount, VcallI, SpacePos: LongInt;
begin
  RetType := GetIntType;
  if (Length(AArg) > 2) and (AArg[Length(AArg)] = 'p') and
    (AArg[Length(AArg) - 1] = ' ') then
  begin
    RetType := GetPtrType;
    AArg := Copy(AArg, 1, Length(AArg) - 2);
  end;
  SpacePos := Pos(' ', AArg);
  if SpacePos > 0 then
  begin
    SlotIdx := StrToIntDef(Copy(AArg, 1, SpacePos - 1), 0);
    ExtraArgCount := StrToIntDef(Copy(AArg, SpacePos + 1, Length(AArg)), 0);
  end
  else
  begin
    SlotIdx := StrToIntDef(AArg, 0);
    ExtraArgCount := 0;
  end;
  SetLength(VcallArgs, ExtraArgCount);
  SetLength(VcallArgTypes, ExtraArgCount);
  for VcallI := ExtraArgCount - 1 downto 0 do
    VcallArgs[VcallI] := S.PopTyped(VcallArgTypes[VcallI]);
  Rhs := S.Pop;
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
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:' + IntToStr(SlotIdx + 1);
  EmitInstr(Instr);
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(V);
  Instr.Operands[1] := MakeOperand(Instr.ResultId - 1);
  EmitInstr(Instr);
  V := EmitLoad(GetPtrType, Instr.ResultId);
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := RetType;
  Instr.IntrinsicName := 'vcall';
  SetLength(Instr.Operands, 2 + ExtraArgCount);
  Instr.Operands[0] := MakeTypedOperand(V, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(Rhs, GetPtrType);
  for VcallI := 0 to ExtraArgCount - 1 do
  begin
    if VcallArgTypes[VcallI] <> 0 then
      Instr.Operands[2 + VcallI] := MakeTypedOperand(VcallArgs[VcallI], VcallArgTypes[VcallI])
    else
      Instr.Operands[2 + VcallI] := MakeOperand(VcallArgs[VcallI]);
  end;
  EmitInstr(Instr);
  if RetType = GetPtrType then
    S.PushTyped(Instr.ResultId, GetPtrType)
  else
    S.Push(Instr.ResultId);
end;

procedure THIRBuilder.ProcessIntfAdjust(const ANode: TTypedHirNode);
var
  VarName: string;
  SlotIdx, TabPos: LongInt;
  ObjPtr, OffsetVal, SlotPtr, ShadowAlloca: THIRValueId;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  VarName := Copy(ANode.Operand, 1, TabPos - 1);
  SlotIdx := StrToIntDef(Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand)), 0);

  ObjPtr := FindAlloca(VarName);
  if ObjPtr = 0 then Exit;
  ObjPtr := EmitLoad(GetPtrType, ObjPtr);

  ShadowAlloca := FindAlloca(VarName + '$obj');
  if ShadowAlloca = 0 then
    EnsureAlloca(VarName + '$obj', GetPtrType);
  ShadowAlloca := FindAlloca(VarName + '$obj');
  if ShadowAlloca <> 0 then
    EmitStore(GetPtrType, ObjPtr, ShadowAlloca);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:' + IntToStr(SlotIdx);
  EmitInstr(Instr);
  OffsetVal := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(ObjPtr);
  Instr.Operands[1] := MakeOperand(OffsetVal);
  EmitInstr(Instr);
  SlotPtr := Instr.ResultId;

  EmitStore(GetPtrType, SlotPtr, FindAlloca(VarName));
end;

procedure THIRBuilder.ProcessIntfAddRef(const ANode: TTypedHirNode);
var
  VarName: string;
  ObjPtr, OldObjPtr: THIRValueId;
  Instr: THIRInstr;
  I: LongInt;
  Found: Boolean;
begin
  VarName := ANode.Operand;
  ObjPtr := FindAlloca(VarName);
  if ObjPtr = 0 then Exit;
  ObjPtr := EmitLoad(GetPtrType, ObjPtr);

  OldObjPtr := FindAlloca(VarName + '$obj');
  if OldObjPtr <> 0 then
  begin
    OldObjPtr := EmitLoad(GetPtrType, OldObjPtr);
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := 0;
    Instr.IntrinsicName := 'intf_release';
    SetLength(Instr.Operands, 1);
    Instr.Operands[0] := MakeTypedOperand(OldObjPtr, GetPtrType);
    EmitInstr(Instr);
  end;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := 0;
  Instr.IntrinsicName := 'intf_addref';
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(ObjPtr, GetPtrType);
  EmitInstr(Instr);
  Found := False;
  for I := 0 to FIntfVarCount - 1 do
    if SameText(FIntfVarNames[I], VarName) then
    begin
      Found := True;
      Break;
    end;
  if not Found then
  begin
    if FIntfVarCount >= Length(FIntfVarNames) then
      SetLength(FIntfVarNames, FIntfVarCount + 8);
    FIntfVarNames[FIntfVarCount] := VarName;
    Inc(FIntfVarCount);
  end;
end;

procedure THIRBuilder.ProcessIntfRelease(const ANode: TTypedHirNode);
var
  VarName: string;
  ObjPtr: THIRValueId;
  Instr: THIRInstr;
begin
  VarName := ANode.Operand;
  ObjPtr := FindAlloca(VarName);
  if ObjPtr = 0 then Exit;
  ObjPtr := EmitLoad(GetPtrType, ObjPtr);
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := 0;
  Instr.IntrinsicName := 'intf_release';
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(ObjPtr, GetPtrType);
  EmitInstr(Instr);
end;

procedure THIRBuilder.EmitExprIvcall(var S: TExprStack; AArg: string);
var
  Instr: THIRInstr;
  IntfPtr, ImtPtr, FnPtr: THIRValueId;
  VcallArgs: array of THIRValueId;
  VcallArgTypes: array of THIRTypeId;
  SlotIdx, SpacePos, ExtraArgCount, VcallI: LongInt;
begin
  SpacePos := Pos(' ', AArg);
  if SpacePos > 0 then
  begin
    SlotIdx := StrToIntDef(Copy(AArg, 1, SpacePos - 1), 0);
    ExtraArgCount := StrToIntDef(Copy(AArg, SpacePos + 1, Length(AArg)), 0);
  end
  else
  begin
    SlotIdx := StrToIntDef(AArg, 0);
    ExtraArgCount := 0;
  end;

  SetLength(VcallArgs, ExtraArgCount);
  SetLength(VcallArgTypes, ExtraArgCount);
  for VcallI := ExtraArgCount - 1 downto 0 do
    VcallArgs[VcallI] := S.PopTyped(VcallArgTypes[VcallI]);

  IntfPtr := S.Pop;

  ImtPtr := EmitLoad(GetPtrType, IntfPtr);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:' + IntToStr(SlotIdx);
  EmitInstr(Instr);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(ImtPtr);
  Instr.Operands[1] := MakeOperand(Instr.ResultId - 1);
  EmitInstr(Instr);

  FnPtr := EmitLoad(GetPtrType, Instr.ResultId);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'vcall';
  SetLength(Instr.Operands, 2 + ExtraArgCount);
  Instr.Operands[0] := MakeOperand(FnPtr);
  Instr.Operands[1] := MakeTypedOperand(IntfPtr, GetPtrType);
  for VcallI := 0 to ExtraArgCount - 1 do
  begin
    if VcallArgTypes[VcallI] <> 0 then
      Instr.Operands[2 + VcallI] := MakeTypedOperand(VcallArgs[VcallI], VcallArgTypes[VcallI])
    else
      Instr.Operands[2 + VcallI] := MakeOperand(VcallArgs[VcallI]);
  end;
  EmitInstr(Instr);
  S.Push(Instr.ResultId);
end;

function THIRBuilder.ParseIntExprArg(const AExprArg: string): THIRValueId;
var
  TypeId: THIRTypeId;
begin
  Result := ParseIntExprArgTyped(AExprArg, TypeId);
end;

function THIRBuilder.ParseIntExprArgTyped(const AExprArg: string;
  out ATypeId: THIRTypeId): THIRValueId;
var
  S: TExprStack;
  Lines: array of string;
  LineCount, I, SpacePos: LongInt;
  Line, Token, Arg: string;
  V: THIRValueId;
  Instr: THIRInstr;
  ExprId: LongInt;
  ExprResult: THIRExprResult;
  OperandType: THIRTypeId;
begin
  Result := 0;
  ATypeId := 0;
  S.Init;

  SetLength(Lines, 0);
  LineCount := 0;
  Line := '';
  for I := 1 to Length(AExprArg) do
  begin
    if AExprArg[I] = #10 then
    begin
      if Line <> '' then
      begin
        if LineCount >= Length(Lines) then
          SetLength(Lines, LineCount + 16);
        Lines[LineCount] := Line;
        Inc(LineCount);
      end;
      Line := '';
    end
    else
      Line := Line + AExprArg[I];
  end;
  if Line <> '' then
  begin
    if LineCount >= Length(Lines) then
      SetLength(Lines, LineCount + 16);
    Lines[LineCount] := Line;
    Inc(LineCount);
  end;

  for I := 0 to LineCount - 1 do
  begin
    Line := Lines[I];
    
    { 检查是否是结构化表达式 }
    if Copy(Line, 1, 5) = 'expr ' then
    begin
      { 提取 ExprId }
      ExprId := StrToIntDef(Copy(Line, 6, Length(Line)), 0);
      if ExprId > 0 then
      begin
        { 调用 LowerExpr 处理结构化表达式 }
        if LowerExpr(ExprId, ExprResult) then
        begin
          Result := ExprResult.ValueId;
          ATypeId := ExprResult.TypeId;
          Exit;
        end;
      end;
      { 如果 LowerExpr 失败，继续处理下一行 }
      Continue;
    end;

    Line := Lines[I];
    SpacePos := Pos(' ', Line);
    if SpacePos > 0 then
    begin
      Token := Copy(Line, 1, SpacePos - 1);
      Arg := Copy(Line, SpacePos + 1, Length(Line));
    end
    else
    begin
      Token := Line;
      Arg := '';
    end;

    if Token = 'int' then EmitExprInt(S, Arg)
    else if Token = 'null' then EmitExprNull(S)
    else if Token = 'assigned' then
    begin
      V := FindAlloca(Arg);
      if V <> 0 then
      begin
        V := EmitLoad(GetPtrType, V);
        S.Push(EmitCmpOp(hikCmpNe, GetBoolType, V, EmitNullPtrValue,
          GetPtrType, GetPtrType));
      end
      else
        S.Push(EmitConstIntOfType(0, GetBoolType));
    end
    else if Token = 'exc_load' then
    begin
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := GetPtrType;
      Instr.IntrinsicName := 'exc_load';
      EmitInstr(Instr);
      S.PushTyped(Instr.ResultId, GetPtrType);
    end
    else if Token = 'strvar' then EmitExprStrVar(S, Arg)
    else if Token = 'strlit' then EmitExprStrLit(S, Arg)
    else if Token = 'var' then EmitExprVar(S, Arg)
    else if Token = 'varref' then EmitExprVarRef(S, Arg)
    else if Token = 'deref' then
    begin
      V := S.PopTyped(OperandType);
      if OperandType <> 0 then
        S.PushTyped(EmitLoad(OperandType, V), OperandType)
      else
        S.Push(EmitLoad(GetIntType, V));
    end
    else if Token = 'recvar' then EmitExprRecVar(S, Arg)
    else if Token = 'is' then EmitExprIs(S, Arg)
    else if Token = 'arr_load' then EmitExprArrLoad(S)
    else if Token = 'arr_load_ptr' then EmitExprArrLoadPtr(S)
    else if Token = 'arr_elem_ref' then EmitExprArrElemRef(S, Arg)
    else if Token = 'field_ref' then EmitExprFieldRef(S, Arg)
    else if Token = 'rload' then EmitExprRLoad(S, Arg)
    else if Token = 'add' then EmitExprBinOp(S, hikAdd)
    else if Token = 'sub' then EmitExprBinOp(S, hikSub)
    else if Token = 'mul' then EmitExprBinOp(S, hikMul)
    else if Token = 'div' then EmitExprBinOp(S, hikDiv)
    else if Token = 'mod' then EmitExprBinOp(S, hikMod)
    else if Token = 'neg' then EmitExprUnaryOp(S, hikNeg, '')
    else if Token = 'abs' then EmitExprUnaryOp(S, hikIntrinsic, 'abs')
    else if Token = 'cmp' then EmitExprCmp(S, Arg)
    else if Token = 'strcmp' then EmitExprStrCmp(S, Arg)
    else if Token = 'zext' then EmitExprZext(S)
    else if Token = 'call' then EmitExprCall(S, Arg)
    else if Token = 'arrvar' then
    begin
      V := FindAlloca(Arg + '$ptr');
      if V <> 0 then
        S.PushTyped(EmitLoad(GetPtrType, V), GetPtrType)
      else
      begin
        EnsureAlloca(Arg + '$ptr', GetPtrType);
        V := FindAlloca(Arg + '$ptr');
        if V <> 0 then
          S.PushTyped(EmitLoad(GetPtrType, V), GetPtrType);
      end;
      V := FindAlloca(Arg + '$len');
      if V <> 0 then
        S.Push(EmitLoad(GetIntTypeByWidth(32, True), V))
      else
      begin
        EnsureAlloca(Arg + '$len', GetIntTypeByWidth(32, True));
        V := FindAlloca(Arg + '$len');
        if V <> 0 then
          S.Push(EmitLoad(GetIntTypeByWidth(32, True), V));
      end;
    end
    else if Token = 'arrload' then EmitExprArrLoadVar(S, Arg)
    else if Token = 'field' then EmitExprField(S, Arg)
    else if Token = 'vcall' then EmitExprVcall(S, Arg)
    else if Token = 'ivcall' then EmitExprIvcall(S, Arg);
  end;

  if S.Count > 0 then
    Result := S.PopTyped(ATypeId);
end;

procedure THIRBuilder.ProcessVarDecl(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
  ParamIdx: LongInt;
  ParamValueId: THIRValueId;
  Arg: string;
  TabPos, Code: LongInt;
  DeclType: THIRTypeId;
  ArrName: string;
  IsStaticArray: Boolean;
  ArrLow, ArrHigh, ArrLength: Int64;
begin
  if ANode.NodeKind = hnkVarDeclRuntime then
  begin
    DeclType := SemanticTypeIdToHirTypeId(ANode.TypeId);
    if DeclType = 0 then
      DeclType := GetIntType;
    if FPendingParamCount > 0 then
    begin
      ParamIdx := FPendingParamLlvmIdx;
      ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[ParamIdx].ValueId;

      if FModule.FunctionAt(FModule.FunctionCount - 1).Params[ParamIdx].TypeId = GetPtrType then
      begin
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikAlloca;
        Instr.TypeId := GetPtrType;
        EmitInstr(Instr);

        RegisterAllocaEntry(ANode.Operand, Instr.ResultId, GetPtrType, False);

        EmitStore(GetPtrType, ParamValueId, Instr.ResultId);
      end
      else
      begin
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikAlloca;
        Instr.TypeId := DeclType;
        EmitInstr(Instr);

        RegisterAllocaEntry(ANode.Operand, Instr.ResultId, DeclType, False);

        EmitStore(DeclType, ParamValueId, Instr.ResultId);
      end;
      Dec(FPendingParamCount);
      Inc(FPendingParamLlvmIdx);
    end
    else if FInStartFunc then
    begin
      if FGlobalCount >= Length(FGlobalNames) then
      begin
        SetLength(FGlobalNames, FGlobalCount + 32);
        SetLength(FGlobalTypes, FGlobalCount + 32);
      end;
      FGlobalNames[FGlobalCount] := ANode.Operand;
      FGlobalTypes[FGlobalCount] := DeclType;
      Inc(FGlobalCount);
      FModule.AddGlobal(ANode.Operand, DeclType, ANode.IsThreadVar);
    end
    else
      EnsureAlloca(ANode.Operand, DeclType);
  end
  else if (ANode.NodeKind = hnkVarDeclArrRuntime) or
    (ANode.NodeKind = hnkVarDeclArrBorrowedRuntime) then
  begin
    if not ParseArrayDeclOperand(ANode.Operand, ArrName, IsStaticArray,
      ArrLow, ArrHigh, ArrLength) then
      ArrName := ANode.Operand;
    if FInStartFunc then
    begin
      if FGlobalCount >= Length(FGlobalNames) then
      begin
        SetLength(FGlobalNames, FGlobalCount + 32);
        SetLength(FGlobalTypes, FGlobalCount + 32);
      end;
      FGlobalNames[FGlobalCount] := ArrName + '$ptr';
      FGlobalTypes[FGlobalCount] := GetPtrType;
      Inc(FGlobalCount);
      FModule.AddGlobal(ArrName + '$ptr', GetPtrType);
      if FGlobalCount >= Length(FGlobalNames) then
      begin
        SetLength(FGlobalNames, FGlobalCount + 32);
        SetLength(FGlobalTypes, FGlobalCount + 32);
      end;
      FGlobalNames[FGlobalCount] := ArrName + '$len';
      FGlobalTypes[FGlobalCount] := GetIntTypeByWidth(32, True);
      Inc(FGlobalCount);
      FModule.AddGlobal(ArrName + '$len', GetIntTypeByWidth(32, True));
      if IsStaticArray then
        EmitStaticArrayBacking(ArrName, ArrLength);
    end
    else
    begin
      if FPendingParamCount > 0 then
      begin
        ParamIdx := FPendingParamLlvmIdx;
        ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[ParamIdx].ValueId;
        EnsureAlloca(ArrName + '$ptr', GetPtrType);
        EmitStore(GetPtrType, ParamValueId, FindAlloca(ArrName + '$ptr'));
        Inc(FPendingParamLlvmIdx);
        ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[FPendingParamLlvmIdx].ValueId;
        EnsureAlloca(ArrName + '$len', GetIntTypeByWidth(32, True));
        EmitStore(GetIntTypeByWidth(32, True), ParamValueId, FindAlloca(ArrName + '$len'));
        Dec(FPendingParamCount);
        Inc(FPendingParamLlvmIdx);
      end
      else
      begin
        EnsureAlloca(ArrName + '$ptr', GetPtrType);
        EnsureAlloca(ArrName + '$len', GetIntTypeByWidth(32, True));
        if IsStaticArray then
          EmitStaticArrayBacking(ArrName, ArrLength);
        if (ANode.NodeKind = hnkVarDeclArrRuntime) and (not IsStaticArray) then
          InitializeDynArraySlots(ArrName);
      end;
    end;
  end
  else if ANode.NodeKind = hnkVarDeclPtrRuntime then
  begin
    if FPendingParamCount > 0 then
    begin
      ParamIdx := FPendingParamLlvmIdx;
      ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[ParamIdx].ValueId;

      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikAlloca;
      Instr.TypeId := GetPtrType;
      EmitInstr(Instr);

      RegisterAllocaEntry(ANode.Operand, Instr.ResultId, GetPtrType, False);

      EmitStore(GetPtrType, ParamValueId, Instr.ResultId);
      Dec(FPendingParamCount);
      Inc(FPendingParamLlvmIdx);
    end
    else if FSretValueId <> 0 then
    begin
      RegisterAllocaEntry(ANode.Operand, FSretValueId, GetIntType, False);
      FSretValueId := 0;
    end
    else
      EnsureAlloca(ANode.Operand, GetPtrType);
  end
  else if ANode.NodeKind = hnkVarDeclVarrefRuntime then
  begin
    if FPendingParamCount > 0 then
    begin
      ParamIdx := FPendingParamLlvmIdx;
      ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[ParamIdx].ValueId;

      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikAlloca;
      Instr.TypeId := GetPtrType;
      EmitInstr(Instr);

      RegisterAllocaEntry(ANode.Operand, Instr.ResultId, GetPtrType, True);

      EmitStore(GetPtrType, ParamValueId, Instr.ResultId);
      Dec(FPendingParamCount);
      Inc(FPendingParamLlvmIdx);
    end
    else
      EnsureAlloca(ANode.Operand, GetPtrType);
  end
  else if ANode.NodeKind = hnkVarDeclRecordRuntime then
  begin
    TabPos := Pos(#9, ANode.Operand);
    if TabPos > 0 then
    begin
      Arg := Copy(ANode.Operand, 1, TabPos - 1);
      Val(Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand)), ParamIdx, Code);
      if Code = 0 then
      begin
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikAlloca;
        Instr.TypeId := GetIntType;
        Instr.IntrinsicName := 'record:' + IntToStr(ParamIdx);
        EmitInstr(Instr);

        RegisterAllocaEntry(Arg, Instr.ResultId, GetIntType, False);
        FAllocas[FAllocaCount - 1].RecordSlots := ParamIdx;
      end;
    end;
  end;
end;

procedure THIRBuilder.ProcessAssign(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  VarName, Blob, RealName: string;
  V, Addr, PtrVal: THIRValueId;
  StoreType, ValueType: THIRTypeId;
  LSymId: LongInt;
  LTypeId: THIRTypeId;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  VarName := Copy(ANode.Operand, 1, TabPos - 1);
  Blob := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  V := LowerNodeExprOrBlobTyped(ANode, Blob, ValueType);

  if (Length(VarName) > 1) and (VarName[1] = '*') then
  begin
    RealName := Copy(VarName, 2, Length(VarName));
    Addr := FindAlloca(RealName);
    if (V <> 0) and (Addr <> 0) then
    begin
      PtrVal := EmitLoad(GetPtrType, Addr);
      if ValueType = 0 then
        ValueType := GetIntType;
      EmitStore(ValueType, V, PtrVal);
    end;
    Exit;
  end;

  Addr := FindAlloca(VarName);
  if Addr = 0 then
  begin
    { 尝试从语义模型获取变量类型 }
    LSymId := FSemaModel.FindSymbolByName(VarName);
    if LSymId > 0 then
    begin
      LTypeId := SemanticTypeIdToHirTypeId(FSemaModel.SymbolAt(LSymId - 1).TypeId);
      if LTypeId <> 0 then
        EnsureAlloca(VarName, LTypeId)
      else
        EnsureAlloca(VarName, GetIntType);
    end
    else
      EnsureAlloca(VarName, GetIntType);
    Addr := FindAlloca(VarName);
  end;
  if (V <> 0) and (Addr <> 0) then
  begin
    if IsVarParamAlloca(VarName) then
    begin
      Addr := EmitLoad(GetPtrType, Addr);
      if ValueType = 0 then
        ValueType := GetIntType;
      EmitStore(ValueType, V, Addr);
    end
    else
    begin
      StoreType := FindAllocaType(VarName);
      if StoreType = 0 then
        StoreType := GetIntType;
      if ValueType <> 0 then
      begin
        V := NormalizeScalarValueToType(V, ValueType, StoreType);
        if V = 0 then
          V := ParseIntExprArg(Blob);
      end;
      if V <> 0 then
        EmitStore(StoreType, V, Addr);
    end;
  end;
end;

procedure THIRBuilder.ProcessHaltCall(const ANode: TTypedHirNode);
var
  V: THIRValueId;
  ValueType: THIRTypeId;
  Instr: THIRInstr;
begin
  V := LowerNodeExprOrBlobTyped(ANode, ANode.Operand, ValueType);
  if (V <> 0) and (ValueType <> 0) then
  begin
    V := NormalizeInt64RuntimeValue(V, ValueType);
    if V = 0 then
      V := ParseIntExprArg(ANode.Operand);
  end;
  if SameText(ANode.DisplayName, '__discard__') then
    Exit;
  if V <> 0 then
  begin
    FlushPendingCleanupNodes;
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
    Instr.IntrinsicName := 'halt';
    SetLength(Instr.Operands, 1);
    Instr.Operands[0] := MakeTypedOperand(V, GetIntType);
    EmitInstr(Instr);
    FBlockTerminated := True;
  end;
end;

procedure THIRBuilder.ProcessHaltCallConst(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
begin
  FlushPendingCleanupNodes;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'halt';
  Instr.CallTarget := ANode.Operand;
  EmitInstr(Instr);
  FBlockTerminated := True;
end;

procedure THIRBuilder.ProcessCondBr(const ANode: TTypedHirNode);
var
  Term: THIRTerminator;
  V: THIRValueId;
  Blob, LabelPart, ThenLabel, ElseLabel: string;
  TabPos, NlPos: LongInt;
begin
  Blob := ANode.Operand;
  NlPos := Pos('labels ', Blob);
  if NlPos = 0 then Exit;

  LabelPart := Copy(Blob, NlPos + 7, Length(Blob));
  TabPos := Pos(#9, LabelPart);
  if TabPos > 0 then
  begin
    ThenLabel := Copy(LabelPart, 1, TabPos - 1);
    ElseLabel := Copy(LabelPart, TabPos + 1, Length(LabelPart));
    if (Length(ElseLabel) > 0) and (ElseLabel[Length(ElseLabel)] = #10) then
      ElseLabel := Copy(ElseLabel, 1, Length(ElseLabel) - 1);
  end
  else
    Exit;

  V := LowerNodeExprOrBlob(ANode, Copy(Blob, 1, NlPos - 1));

  FillChar(Term, SizeOf(Term), 0);
  Term.Kind := htkCondBranch;
  Term.Condition := V;
  Term.TrueBlock := EnsureBlock(ThenLabel);
  Term.FalseBlock := EnsureBlock(ElseLabel);
  if (FCurrentFuncId <> 0) and (FCurrentBlockId <> 0) then
  begin
    FModule.SetTerminator(FCurrentFuncId, FCurrentBlockId, Term);
    FBlockTerminated := True;
  end;
end;

procedure THIRBuilder.ProcessSwitch(const ANode: TTypedHirNode);
var
  Term: THIRTerminator;
  V: THIRValueId;
  Blob, Line, Rest, ValStr, LabelStr: string;
  SwitchPos, NlPos, TabPos, CaseCount, I: LongInt;
begin
  Blob := ANode.Operand;
  SwitchPos := Pos('switch ', Blob);
  if SwitchPos = 0 then Exit;

  V := LowerNodeExprOrBlob(ANode, Copy(Blob, 1, SwitchPos - 1));
  Rest := Copy(Blob, SwitchPos + 7, Length(Blob));

  NlPos := Pos(#10, Rest);
  if NlPos = 0 then Exit;
  CaseCount := StrToIntDef(Copy(Rest, 1, NlPos - 1), 0);
  Rest := Copy(Rest, NlPos + 1, Length(Rest));

  FillChar(Term, SizeOf(Term), 0);
  Term.Kind := htkSwitch;
  Term.Condition := V;
  SetLength(Term.SwitchCases, CaseCount);

  for I := 0 to CaseCount - 1 do
  begin
    NlPos := Pos(#10, Rest);
    if NlPos = 0 then
      Line := Rest
    else
      Line := Copy(Rest, 1, NlPos - 1);
    Rest := Copy(Rest, NlPos + 1, Length(Rest));

    TabPos := Pos(#9, Line);
    if TabPos = 0 then Continue;
    ValStr := Copy(Line, 1, TabPos - 1);
    LabelStr := Copy(Line, TabPos + 1, Length(Line));
    Term.SwitchCases[I].Value := StrToInt64Def(ValStr, 0);
    Term.SwitchCases[I].TargetBlock := EnsureBlock(LabelStr);
  end;

  NlPos := Pos(#10, Rest);
  if NlPos = 0 then
    Line := Rest
  else
    Line := Copy(Rest, 1, NlPos - 1);
  TabPos := Pos(#9, Line);
  if TabPos > 0 then
    LabelStr := Copy(Line, TabPos + 1, Length(Line))
  else
    LabelStr := Line;
  Term.DefaultBlock := EnsureBlock(LabelStr);

  if (FCurrentFuncId <> 0) and (FCurrentBlockId <> 0) then
  begin
    FModule.SetTerminator(FCurrentFuncId, FCurrentBlockId, Term);
    FBlockTerminated := True;
  end;
end;

procedure THIRBuilder.ProcessBr(const ANode: TTypedHirNode);
var
  Term: THIRTerminator;
  Target: string;
begin
  Target := ANode.Operand;
  if (Length(Target) > 0) and (Target[Length(Target)] = #10) then
    Target := Copy(Target, 1, Length(Target) - 1);

  FillChar(Term, SizeOf(Term), 0);
  Term.Kind := htkBranch;
  Term.TargetBlock := EnsureBlock(Target);
  if (FCurrentFuncId <> 0) and (FCurrentBlockId <> 0) then
  begin
    FModule.SetTerminator(FCurrentFuncId, FCurrentBlockId, Term);
    FBlockTerminated := True;
  end;
end;

procedure THIRBuilder.ProcessBlockLabel(const ANode: TTypedHirNode);
var
  NewBlock: THIRBlockId;
  Term: THIRTerminator;
begin
  if FCurrentFuncId = 0 then Exit;
  NewBlock := EnsureBlock(ANode.Operand);

  if (FCurrentBlockId <> 0) and (not FBlockTerminated) then
  begin
    FillChar(Term, SizeOf(Term), 0);
    Term.Kind := htkBranch;
    Term.TargetBlock := NewBlock;
    FModule.SetTerminator(FCurrentFuncId, FCurrentBlockId, Term);
  end;

  FCurrentBlockId := NewBlock;
  FBlockTerminated := False;
end;

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
  FSavedAllocaCount := FAllocaCount;
  FInStartFunc := False;
  SetLength(FSavedAllocas, FAllocaCount);
  for I := 0 to FAllocaCount - 1 do
    FSavedAllocas[I] := FAllocas[I];
  FSavedBlockCount := FBlockCount;
  SetLength(FSavedBlockNames, FBlockCount);
  SetLength(FSavedBlockIds, FBlockCount);
  for I := 0 to FBlockCount - 1 do
  begin
    FSavedBlockNames[I] := FBlockNames[I];
    FSavedBlockIds[I] := FBlockIds[I];
  end;

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
    FAllocaCount := 0;
    FGlobalRefCount := 0;
    FBlockCount := 0;
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
    FAllocaCount := 0;
    FGlobalRefCount := 0;
    FBlockCount := 0;
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
var
  I: LongInt;
begin
  FCurrentFuncId := FSavedFuncId;
  FCurrentBlockId := FSavedBlockId;
  FEntryBlockId := FSavedEntryBlockId;
  FAllocaCount := FSavedAllocaCount;
  if FAllocaCount > Length(FAllocas) then
    SetLength(FAllocas, FAllocaCount + 32);
  for I := 0 to FSavedAllocaCount - 1 do
    FAllocas[I] := FSavedAllocas[I];
  FBlockCount := FSavedBlockCount;
  for I := 0 to FSavedBlockCount - 1 do
  begin
    FBlockNames[I] := FSavedBlockNames[I];
    FBlockIds[I] := FSavedBlockIds[I];
  end;
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

  LFuncId := FModule.AddFunction(LBinding.PascalName, LReturnTypeId);
  FModule.SetFunctionExternal(LFuncId, True, LBinding.LibraryId,
    LBinding.ExternalSymbolName);

  { Add parameters — use ParamSignature to infer types where possible.
    'p'→ptr, 's'→string, 'b'→bool, 'r'/'f'/'c'→ptr, 'i'→i64 fallback. }
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
      FModule.AddFunctionParam(LFuncId, 'arg' + IntToStr(I), GetIntType, False, False);
  end;
end;

procedure THIRBuilder.ProcessRetRuntime(const ANode: TTypedHirNode);
var
  V, ObjPtr: THIRValueId;
  Term: THIRTerminator;
  Func: THIRFunction;
  Instr: THIRInstr;
  I: LongInt;
begin
  for I := 0 to FIntfVarCount - 1 do
  begin
    ObjPtr := FindAlloca(FIntfVarNames[I] + '$obj');
    if ObjPtr <> 0 then
    begin
      ObjPtr := EmitLoad(GetPtrType, ObjPtr);
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := 0;
      Instr.IntrinsicName := 'intf_release';
      SetLength(Instr.Operands, 1);
      Instr.Operands[0] := MakeTypedOperand(ObjPtr, GetPtrType);
      EmitInstr(Instr);
    end;
  end;
  Func := FModule.FunctionAt(FModule.FunctionCount - 1);
  if (Length(Func.Params) > 0) and (Func.Params[0].Name = 'sret_ptr') then
  begin
    FlushPendingCleanupNodes;
    FillChar(Term, SizeOf(Term), 0);
    Term.Kind := htkReturn;
    Term.ReturnValue := 0;
    if (FCurrentFuncId <> 0) and (FCurrentBlockId <> 0) then
    begin
      FModule.SetTerminator(FCurrentFuncId, FCurrentBlockId, Term);
      FBlockTerminated := True;
    end;
  end
  else
  begin
    V := LowerNodeExprOrBlob(ANode, ANode.Operand);
    FlushPendingCleanupNodes;
    FillChar(Term, SizeOf(Term), 0);
    Term.Kind := htkReturn;
    Term.ReturnValue := V;
    if (FCurrentFuncId <> 0) and (FCurrentBlockId <> 0) then
    begin
      FModule.SetTerminator(FCurrentFuncId, FCurrentBlockId, Term);
      FBlockTerminated := True;
    end;
  end;
end;

procedure THIRBuilder.ProcessCallRuntime(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
  TabPos: LongInt;
  FuncName, Rest, ArgBlob, StrVarName: string;
  FirstArgBlob, FirstArgName: string;
  ArgValue, PtrVal, LenVal, ObjectFreeReceiverValue: THIRValueId;
  ArgOps: array of THIROperand;
  ArgCount: LongInt;
  OwnsObjectFreeDestroy, OwnsObjectFreeHeapRelease: Boolean;
  ObjectFreeCleanupClass: string;
  ExprResult: THIRExprResult;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos > 0 then
  begin
    FuncName := Copy(ANode.Operand, 1, TabPos - 1);
    Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));
  end
  else
  begin
    FuncName := ANode.Operand;
    Rest := '';
  end;

  FirstArgBlob := '';
  if Rest <> '' then
  begin
    TabPos := Pos(#9, Rest);
    if TabPos > 0 then
      FirstArgBlob := Copy(Rest, 1, TabPos - 1)
    else
      FirstArgBlob := Rest;
  end;
  FirstArgName := ExtractVarOperandName(FirstArgBlob);
  OwnsObjectFreeDestroy := (FPendingObjectFreeDestroyName <> '') and
    (FPendingObjectFreeReceiverValue <> 0) and
    SameText(FuncName, FPendingObjectFreeDestroyName) and
    SameText(FirstArgName, FPendingObjectFreeReceiverName);
  ObjectFreeReceiverValue := FPendingObjectFreeReceiverValue;
  ObjectFreeCleanupClass := FPendingObjectFreeCleanupClass;
  OwnsObjectFreeHeapRelease := OwnsObjectFreeDestroy and
    FPendingObjectFreeHeapRelease;
  if FPendingObjectFreeDestroyName <> '' then
  begin
    FPendingObjectFreeDestroyName := '';
    FPendingObjectFreeReceiverName := '';
    FPendingObjectFreeReceiverValue := 0;
    FPendingObjectFreeCleanupClass := '';
    FPendingObjectFreeHeapRelease := False;
  end;

  if (ANode.ExprId > 0) and (not OwnsObjectFreeDestroy) and
    LowerExprValue(ANode.ExprId, ExprResult) then
    Exit;

  ArgCount := 0;
  SetLength(ArgOps, 0);
  while Rest <> '' do
  begin
    TabPos := Pos(#9, Rest);
    if TabPos > 0 then
    begin
      ArgBlob := Copy(Rest, 1, TabPos - 1);
      Rest := Copy(Rest, TabPos + 1, Length(Rest));
    end
    else
    begin
      ArgBlob := Rest;
      Rest := '';
    end;
    if OwnsObjectFreeDestroy and (ArgCount = 0) then
    begin
      SetLength(ArgOps, ArgCount + 1);
      ArgOps[ArgCount] := MakeTypedOperand(ObjectFreeReceiverValue, GetPtrType);
      Inc(ArgCount);
    end
    else if (Length(ArgBlob) > 7) and (Copy(ArgBlob, 1, 7) = 'strvar ') then
    begin
      StrVarName := Copy(ArgBlob, 8, Length(ArgBlob));
      if (Length(StrVarName) > 0) and (StrVarName[Length(StrVarName)] = #10) then
        StrVarName := Copy(StrVarName, 1, Length(StrVarName) - 1);
      PtrVal := FindAlloca(StrVarName + '$ts');
      if PtrVal <> 0 then
      begin
        PtrVal := EmitTStringData(PtrVal);
        LenVal := EmitTStringLen(FindAlloca(StrVarName + '$ts'));
        if (PtrVal <> 0) and (LenVal <> 0) then
        begin
          SetLength(ArgOps, ArgCount + 2);
          ArgOps[ArgCount] := MakeTypedOperand(PtrVal, GetPtrType);
          ArgOps[ArgCount + 1] := MakeTypedOperand(LenVal, GetIntTypeByWidth(32, True));
          Inc(ArgCount, 2);
        end;
      end;
    end
    else if (Length(ArgBlob) > 7) and (Copy(ArgBlob, 1, 7) = 'strlit ') then
    begin
      StrVarName := Copy(ArgBlob, 8, Length(ArgBlob));
      if (Length(StrVarName) > 0) and (StrVarName[Length(StrVarName)] = #10) then
        StrVarName := Copy(StrVarName, 1, Length(StrVarName) - 1);
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := GetPtrType;
      Instr.IntrinsicName := 'str_const';
      Instr.CallTarget := StrVarName;
      EmitInstr(Instr);
      PtrVal := Instr.ResultId;
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikLoad;
      Instr.TypeId := GetIntTypeByWidth(32, True);
      Instr.IntrinsicName := 'const:' + IntToStr(Length(StrVarName) - 2);
      EmitInstr(Instr);
      LenVal := Instr.ResultId;
      SetLength(ArgOps, ArgCount + 2);
      ArgOps[ArgCount] := MakeTypedOperand(PtrVal, GetPtrType);
      ArgOps[ArgCount + 1] := MakeTypedOperand(LenVal, GetIntTypeByWidth(32, True));
      Inc(ArgCount, 2);
    end
    else
    begin
      ArgValue := ParseIntExprArg(ArgBlob);
      if ArgValue <> 0 then
      begin
        SetLength(ArgOps, ArgCount + 1);
        if (Length(ArgBlob) > 4) and (Copy(ArgBlob, 1, 4) = 'var ') then
        begin
          StrVarName := Copy(ArgBlob, 5, Length(ArgBlob));
          if (Length(StrVarName) > 0) and (StrVarName[Length(StrVarName)] = #10) then
            StrVarName := Copy(StrVarName, 1, Length(StrVarName) - 1);
          if (not IsVarParamAlloca(StrVarName)) and
            (FindAllocaType(StrVarName) = GetPtrType) then
            ArgOps[ArgCount] := MakeTypedOperand(ArgValue, GetPtrType)
          else
            ArgOps[ArgCount] := MakeOperand(ArgValue);
        end
        else if (Pos(' p' + #10, ArgBlob) > 0) or
          (Copy(ArgBlob, 1, 4) = 'null') or
          (Copy(ArgBlob, 1, 7) = 'recvar ') or
          (Copy(ArgBlob, 1, 7) = 'varref ') then
          ArgOps[ArgCount] := MakeTypedOperand(ArgValue, GetPtrType)
        else
          ArgOps[ArgCount] := MakeOperand(ArgValue);
        Inc(ArgCount);
      end;
    end;
  end;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  if OwnsObjectFreeDestroy then
  begin
    Instr.Kind := hikIntrinsic;
    Instr.IntrinsicName := NPSYSTEM_OBJECT_FREE_DESTROY;
  end
  else
    Instr.Kind := hikCall;
  Instr.TypeId := GetIntType;
  Instr.CallTarget := FuncName;
  Instr.Operands := ArgOps;
  EmitInstr(Instr);

  if OwnsObjectFreeHeapRelease then
  begin
    if ObjectFreeCleanupClass <> '' then
      EmitObjectStringCleanupCall(
        ObjectFreeCleanupClass, ObjectFreeReceiverValue);
    if ObjectFreeCleanupClass <> '' then
      EmitObjectDynArrayCleanupCall(
        ObjectFreeCleanupClass, ObjectFreeReceiverValue);
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
    Instr.IntrinsicName := NPSYSTEM_OBJECT_FREE_RELEASE;
    SetLength(Instr.Operands, 1);
    Instr.Operands[0] := MakeTypedOperand(ObjectFreeReceiverValue, GetPtrType);
    EmitInstr(Instr);
  end;
end;

procedure THIRBuilder.ProcessObjectFreeRuntime(const ANode: TTypedHirNode);
var
  CleanupClassName, DestroyName, Line, Rest, ReceiverName: string;
  Instr: THIRInstr;
  LineEnd: LongInt;
  ReceiverPtr, ReceiverSlot: THIRValueId;
  HeapRelease: Boolean;
begin
  DestroyName := '';
  CleanupClassName := '';
  ReceiverName := '';
  HeapRelease := False;
  FPendingObjectFreeDestroyName := '';
  FPendingObjectFreeReceiverName := '';
  FPendingObjectFreeReceiverValue := 0;
  FPendingObjectFreeCleanupClass := '';
  FPendingObjectFreeHeapRelease := False;
  Rest := ANode.Operand;
  while Rest <> '' do
  begin
    LineEnd := Pos(#10, Rest);
    if LineEnd > 0 then
    begin
      Line := Copy(Rest, 1, LineEnd - 1);
      Rest := Copy(Rest, LineEnd + 1, Length(Rest));
    end
    else
    begin
      Line := Rest;
      Rest := '';
    end;
    Line := Trim(Line);
    if (Length(Line) > 4) and SameText(Copy(Line, 1, 4), 'var ') then
      ReceiverName := Trim(Copy(Line, 5, Length(Line)))
    else if (Length(Line) > 8) and SameText(Copy(Line, 1, 8), 'destroy ') then
      DestroyName := Trim(Copy(Line, 9, Length(Line)))
    else if (Length(Line) > 14) and
      SameText(Copy(Line, 1, 14), 'cleanup-class ') then
      CleanupClassName := Trim(Copy(Line, 15, Length(Line)))
    else if SameText(Line, 'heap-release true') then
      HeapRelease := True;
  end;

  if ReceiverName = '' then
    Exit;
  ReceiverSlot := FindAlloca(ReceiverName);
  if ReceiverSlot = 0 then
  begin
    EnsureAlloca(ReceiverName, GetPtrType);
    ReceiverSlot := FindAlloca(ReceiverName);
  end;
  if ReceiverSlot = 0 then
    Exit;

  if IsVarParamAlloca(ReceiverName) then
    ReceiverPtr := EmitLoad(GetPtrType, EmitLoad(GetPtrType, ReceiverSlot))
  else
    ReceiverPtr := EmitLoad(GetPtrType, ReceiverSlot);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := ANode.DisplayName;
  Instr.CallTarget := DestroyName;
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(ReceiverPtr, GetPtrType);
  EmitInstr(Instr);

  if DestroyName <> '' then
  begin
    FPendingObjectFreeDestroyName := DestroyName;
    FPendingObjectFreeReceiverName := ReceiverName;
    FPendingObjectFreeReceiverValue := ReceiverPtr;
    FPendingObjectFreeCleanupClass := CleanupClassName;
    FPendingObjectFreeHeapRelease := HeapRelease;
  end;
end;

procedure THIRBuilder.ProcessFillCharRuntime(const ANode: TTypedHirNode);
var
  TabPos1, TabPos2: LongInt;
  VarName, CountStr, ValueStr, Rest: string;
  DestAlloca, CountV, ValueV: THIRValueId;
  Instr: THIRInstr;
begin
  Rest := ANode.Operand;
  TabPos1 := Pos(#9, Rest);
  if TabPos1 = 0 then Exit;
  VarName := Trim(Copy(Rest, 1, TabPos1 - 1));
  Rest := Copy(Rest, TabPos1 + 1, Length(Rest));
  TabPos2 := Pos(#9, Rest);
  if TabPos2 = 0 then Exit;
  CountStr := Trim(Copy(Rest, 1, TabPos2 - 1));
  ValueStr := Trim(Copy(Rest, TabPos2 + 1, Length(Rest)));
  DestAlloca := FindAlloca(VarName);
  if DestAlloca = 0 then Exit;
  CountV := ParseIntExprArg(CountStr);
  if CountV = 0 then Exit;
  ValueV := ParseIntExprArg(ValueStr);
  if ValueV = 0 then Exit;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'fillchar';
  SetLength(Instr.Operands, 3);
  Instr.Operands[0] := MakeTypedOperand(DestAlloca, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(CountV, GetIntType);
  Instr.Operands[2] := MakeTypedOperand(ValueV, GetIntType);
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessMoveRuntime(const ANode: TTypedHirNode);
var
  TabPos1, TabPos2: LongInt;
  SrcVar, DstVar, CountStr, Rest: string;
  SrcAlloca, DstAlloca, CountV: THIRValueId;
  Instr: THIRInstr;
begin
  Rest := ANode.Operand;
  TabPos1 := Pos(#9, Rest);
  if TabPos1 = 0 then Exit;
  SrcVar := Trim(Copy(Rest, 1, TabPos1 - 1));
  Rest := Copy(Rest, TabPos1 + 1, Length(Rest));
  TabPos2 := Pos(#9, Rest);
  if TabPos2 = 0 then Exit;
  DstVar := Trim(Copy(Rest, 1, TabPos2 - 1));
  CountStr := Trim(Copy(Rest, TabPos2 + 1, Length(Rest)));
  SrcAlloca := FindAlloca(SrcVar);
  if SrcAlloca = 0 then Exit;
  DstAlloca := FindAlloca(DstVar);
  if DstAlloca = 0 then Exit;
  CountV := ParseIntExprArg(CountStr);
  if CountV = 0 then Exit;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'move';
  SetLength(Instr.Operands, 3);
  Instr.Operands[0] := MakeTypedOperand(SrcAlloca, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(DstAlloca, GetPtrType);
  Instr.Operands[2] := MakeTypedOperand(CountV, GetIntType);
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessGetMemRuntime(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  VarName, SizeStr, Rest: string;
  SizeV: THIRValueId;
  Instr: THIRInstr;
begin
  Rest := ANode.Operand;
  TabPos := Pos(#9, Rest);
  if TabPos = 0 then Exit;
  VarName := Trim(Copy(Rest, 1, TabPos - 1));
  SizeStr := Trim(Copy(Rest, TabPos + 1, Length(Rest)));
  SizeV := ParseIntExprArg(SizeStr);
  if SizeV = 0 then Exit;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'getmem';
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(SizeV, GetIntType);
  EmitInstr(Instr);
  EmitStore(GetPtrType, Instr.ResultId, FindAlloca(VarName));
end;

procedure THIRBuilder.ProcessFreeMemRuntime(const ANode: TTypedHirNode);
var
  VarName: string;
  PtrAlloca, PtrVal: THIRValueId;
  Instr: THIRInstr;
begin
  VarName := Trim(ANode.Operand);
  if VarName = '' then Exit;
  PtrAlloca := FindAlloca(VarName);
  if PtrAlloca = 0 then Exit;
  PtrVal := EmitLoad(GetPtrType, PtrAlloca);
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'freemem';
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(PtrVal, GetPtrType);
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessAssignedRuntime(const ANode: TTypedHirNode);
var
  VarName: string;
  PtrAlloca, PtrVal: THIRValueId;
begin
  VarName := Trim(ANode.Operand);
  if VarName = '' then Exit;
  PtrAlloca := FindAlloca(VarName);
  if PtrAlloca = 0 then Exit;
  PtrVal := EmitLoad(GetPtrType, PtrAlloca);
  EmitCmpOp(hikCmpNe, GetBoolType,
    PtrVal, EmitNullPtrValue, GetPtrType, GetPtrType);
end;

procedure THIRBuilder.ProcessInterlockedOp(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  TargetName, ArgBlob, NewValBlob, CmpValBlob, Rest: string;
  TargetAlloca, TargetPtr, NewVal, CmpVal, Addend, FetchAddResult, OneVal: THIRValueId;
  Instr: THIRInstr;
  IntrinsicOpName: string;
  IsCas: Boolean;
begin
  Rest := ANode.Operand;
  TabPos := Pos(#9, Rest);
  if TabPos = 0 then Exit;
  TargetName := Trim(Copy(Rest, 1, TabPos - 1));
  Rest := Copy(Rest, TabPos + 1, Length(Rest));

  TargetAlloca := FindAlloca(TargetName);
  if TargetAlloca = 0 then Exit;
  TargetPtr := EmitLoad(GetPtrType, TargetAlloca);
  if TargetPtr = 0 then Exit;

  IsCas := (ANode.NodeKind = hnkInterlockedCasRuntime) or
           (ANode.NodeKind = hnkInterlockedCas64Runtime);

  if IsCas then
  begin
    { CAS: Target #9 NewValue #9 CompareValue }
    TabPos := Pos(#9, Rest);
    if TabPos = 0 then Exit;
    NewValBlob := Trim(Copy(Rest, 1, TabPos - 1));
    CmpValBlob := Trim(Copy(Rest, TabPos + 1, Length(Rest)));

    NewVal := LowerNodeExprOrBlob(ANode, NewValBlob);
    CmpVal := LowerNodeExprOrBlob(ANode, CmpValBlob);
    if (NewVal = 0) or (CmpVal = 0) then Exit;

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetIntType;
    if ANode.NodeKind = hnkInterlockedCas64Runtime then
      Instr.IntrinsicName := 'interlocked-cas64'
    else
      Instr.IntrinsicName := 'interlocked-cas';
    SetLength(Instr.Operands, 3);
    Instr.Operands[0] := MakeTypedOperand(TargetPtr, GetPtrType);
    Instr.Operands[1] := MakeTypedOperand(NewVal, GetIntType);
    Instr.Operands[2] := MakeTypedOperand(CmpVal, GetIntType);
    EmitInstr(Instr);
  end
  else
  begin
    { Exchange / FetchAdd: Target #9 Value }
    ArgBlob := Trim(Rest);
    Addend := LowerNodeExprOrBlob(ANode, ArgBlob);
    if Addend = 0 then Exit;

    if ANode.NodeKind = hnkInterlockedXchgRuntime then
      IntrinsicOpName := 'interlocked-xchg'
    else if ANode.NodeKind = hnkInterlockedFetchAdd64Runtime then
      IntrinsicOpName := 'interlocked-fetch-add64'
    else
      IntrinsicOpName := 'interlocked-fetch-add';

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetIntType;
    Instr.IntrinsicName := IntrinsicOpName;
    SetLength(Instr.Operands, 2);
    Instr.Operands[0] := MakeTypedOperand(TargetPtr, GetPtrType);
    Instr.Operands[1] := MakeTypedOperand(Addend, GetIntType);
    EmitInstr(Instr);
    FetchAddResult := Instr.ResultId;

    { InterlockedIncrement/Decrement return new value (old+1 / old-1), not old value }
    if (ANode.NodeKind = hnkInterlockedFetchAddRuntime) then
    begin
      { The blob for Increment is 'int 1' + #10, for Decrement is 'int -1' + #10
        For ExchangeAdd, the blob is a runtime expression. Only adjust for constants +/-1 }
      if (Length(ArgBlob) >= 7) and
         ((Copy(ArgBlob, 1, 7) = 'int 1' + #10) or
          (Copy(ArgBlob, 1, 8) = 'int -1' + #10)) then
      begin
        { This is Increment or Decrement: adjust result }
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        if Copy(ArgBlob, 1, 6) = 'int -1' then
          Instr.Kind := hikSub
        else
          Instr.Kind := hikAdd;
        Instr.TypeId := GetIntType;
        SetLength(Instr.Operands, 2);
        Instr.Operands[0] := MakeTypedOperand(FetchAddResult, GetIntType);
        OneVal := EmitConstIntSmart(1);
        Instr.Operands[1] := MakeTypedOperand(OneVal, GetIntType);
        EmitInstr(Instr);
      end;
    end;
  end;
end;

procedure THIRBuilder.ProcessWriteInt(const ANode: TTypedHirNode);
var
  V: THIRValueId;
  ValueType: THIRTypeId;
  Instr: THIRInstr;
begin
  V := LowerNodeExprOrBlobTyped(ANode, ANode.Operand, ValueType);
  if (V <> 0) and (ValueType <> 0) then
  begin
    V := NormalizeInt64RuntimeValue(V, ValueType);
    if V = 0 then
      V := ParseIntExprArg(ANode.Operand);
  end;
  if V <> 0 then
  begin
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
    Instr.IntrinsicName := 'write_int';
    SetLength(Instr.Operands, 1);
    Instr.Operands[0] := MakeTypedOperand(V, GetIntType);
    EmitInstr(Instr);
  end;
end;

procedure THIRBuilder.ProcessWriteStr(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'write_str';
  Instr.CallTarget := ANode.Operand;
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessWriteString(const ANode: TTypedHirNode);
begin
  ProcessWriteStr(ANode);
end;

procedure THIRBuilder.ProcessWriteCall(const ANode: TTypedHirNode);
begin
  ProcessWriteStr(ANode);
end;

procedure THIRBuilder.ProcessWriteStrVar(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
  TsSlot, DataPtr, LenVal: THIRValueId;
begin
  TsSlot := FindAlloca(ANode.Operand + '$ts');
  if TsSlot = 0 then
    Exit;

  DataPtr := EmitTStringData(TsSlot);
  LenVal := EmitTStringLen(TsSlot);
  if (DataPtr = 0) or (LenVal = 0) then
    Exit;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'write_str_var';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeTypedOperand(DataPtr, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(LenVal, GetIntTypeByWidth(32, True));
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessIntToStr(const ANode: TTypedHirNode);
var
  TempName, Blob: string;
  TabPos: LongInt;
  TsSlot, IntValue: THIRValueId;
  Instr: THIRInstr;
begin
  Blob := ANode.Operand;
  TabPos := Pos(#9, Blob);
  if TabPos = 0 then
    Exit;

  TempName := Copy(Blob, 1, TabPos - 1);
  Blob := Copy(Blob, TabPos + 1, Length(Blob));
  TsSlot := FindAlloca(TempName + '$ts');
  if TsSlot = 0 then
    Exit;

  IntValue := LowerNodeExprOrBlob(ANode, Blob);
  if IntValue = 0 then
    Exit;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'tstring_from_int';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeTypedOperand(TsSlot, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(IntValue, GetIntType);
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessCopyStr(const ANode: TTypedHirNode);
var
  Blob, DstName, SrcName, StartBlob, LenBlob: string;
  TabPos: LongInt;
  DstTs, SrcTs, StartVal, LenVal: THIRValueId;
  Instr: THIRInstr;
begin
  Blob := ANode.Operand;

  TabPos := Pos(#9, Blob);
  if TabPos = 0 then
    Exit;
  DstName := Copy(Blob, 1, TabPos - 1);
  Blob := Copy(Blob, TabPos + 1, Length(Blob));

  TabPos := Pos(#9, Blob);
  if TabPos = 0 then
    Exit;
  SrcName := Copy(Blob, 1, TabPos - 1);
  Blob := Copy(Blob, TabPos + 1, Length(Blob));

  TabPos := Pos(#9, Blob);
  if TabPos = 0 then
    Exit;
  StartBlob := Copy(Blob, 1, TabPos - 1);
  LenBlob := Copy(Blob, TabPos + 1, Length(Blob));

  DstTs := FindAlloca(DstName + '$ts');
  SrcTs := FindAlloca(SrcName + '$ts');
  if (DstTs = 0) or (SrcTs = 0) then
    Exit;

  StartVal := ParseIntExprArg(StartBlob);
  LenVal := ParseIntExprArg(LenBlob);
  if (StartVal = 0) or (LenVal = 0) then
    Exit;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'tstring_copy';
  SetLength(Instr.Operands, 4);
  Instr.Operands[0] := MakeTypedOperand(DstTs, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(SrcTs, GetPtrType);
  Instr.Operands[2] := MakeTypedOperand(StartVal, GetIntTypeByWidth(32, True));
  Instr.Operands[3] := MakeTypedOperand(LenVal, GetIntTypeByWidth(32, True));
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessStringTempOwnedRuntime(
  const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
  FuncName, TempName: string;
  TabPos: LongInt;
  TsSlot: THIRValueId;
begin
  TempName := ANode.Operand;
  TabPos := Pos(#9, TempName);
  if TabPos > 0 then
    TempName := Copy(TempName, 1, TabPos - 1);
  FuncName := ANode.DisplayName;

  TsSlot := FindAlloca(TempName + '$ts');
  if TsSlot <> 0 then
  begin
    { TString path: call function, result stored via tstring_assign or sret }
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikCall;
    Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
    Instr.CallTarget := FuncName;
    SetLength(Instr.Operands, 1);
    Instr.Operands[0].ValueId := TsSlot;
    Instr.Operands[0].TypeId := GetPtrType;
    EmitInstr(Instr);
  end;
end;

procedure THIRBuilder.ProcessStringTempBorrowArgRuntime(
  const ANode: TTypedHirNode);
begin
  { Source-contract marker only; call-runtime lowers the borrowed ptr,len. }
end;

procedure THIRBuilder.ProcessStringTempLengthRuntime(
  const ANode: TTypedHirNode);
var
  TempName: string;
  TsSlot, LenSlot: THIRValueId;
begin
  TempName := ANode.Operand;
  if Copy(TempName, 1, 7) = 'strvar ' then
  begin
    TempName := Copy(TempName, 8, Length(TempName) - 7);
    if (Length(TempName) > 0) and (TempName[Length(TempName)] = #10) then
      TempName := Copy(TempName, 1, Length(TempName) - 1);
  end;
  if TempName = '' then
    Exit;
  TsSlot := FindAlloca(TempName + '$ts');
  if TsSlot <> 0 then
  begin
    LenSlot := EmitTStringLen(TsSlot);
    EnsureAlloca(TempName + '$len', GetIntTypeByWidth(32, True));
    EmitStore(GetIntTypeByWidth(32, True), LenSlot, FindAlloca(TempName + '$len'));
  end;
end;

procedure THIRBuilder.ProcessStringTempReleaseRuntime(
  const ANode: TTypedHirNode);
var
  TsSlot: THIRValueId;
begin
  TsSlot := FindAlloca(ANode.Operand + '$ts');
  if TsSlot <> 0 then
    EmitTStringFini(TsSlot);
end;

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

      ZeroVal := EmitConstIntSmart(0);
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
  Instr.IntrinsicName := NPSYSTEM_OBJECT_FREE_CLEANUP;
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
  Instr.IntrinsicName := NPSYSTEM_OBJECT_FREE_CLEANUP;
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
  SavedAllocaCount, SavedBlockCount: LongInt;
  SavedAllocas: array of TAllocaEntry;
  SavedBlockNames: array of string;
  SavedBlockIds: array of THIRBlockId;
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
  SavedAllocaCount := FAllocaCount;
  SetLength(SavedAllocas, FAllocaCount);
  for I := 0 to FAllocaCount - 1 do
    SavedAllocas[I] := FAllocas[I];
  SavedBlockCount := FBlockCount;
  SetLength(SavedBlockNames, FBlockCount);
  SetLength(SavedBlockIds, FBlockCount);
  for I := 0 to FBlockCount - 1 do
  begin
    SavedBlockNames[I] := FBlockNames[I];
    SavedBlockIds[I] := FBlockIds[I];
  end;

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
  FAllocaCount := 0;
  FBlockCount := 0;

  ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[0].ValueId;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikAlloca;
  Instr.TypeId := GetPtrType;
  EmitInstr(Instr);
  ObjSlot := Instr.ResultId;
  RegisterAllocaEntry('obj', ObjSlot, GetPtrType, False);
  EmitStore(GetPtrType, ParamValueId, ObjSlot);

  for I := High(Meta.Fields) downto 0 do
  begin
    if not Meta.Fields[I].IsString then
      Continue;

    PtrSlot := FieldSlotPtr(ParamValueId, Meta.Fields[I].Index);
    LenSlot := FieldSlotPtr(ParamValueId, Meta.Fields[I].Index + 1);
    OwnerSlot := FieldSlotPtr(ParamValueId, Meta.Fields[I].Index + 2);
    AllocSizeSlot := FieldSlotPtr(ParamValueId, Meta.Fields[I].Index + 3);
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
  FAllocaCount := SavedAllocaCount;
  SetLength(FAllocas, Length(SavedAllocas));
  for I := 0 to High(SavedAllocas) do
    FAllocas[I] := SavedAllocas[I];
  FBlockCount := SavedBlockCount;
  SetLength(FBlockNames, Length(SavedBlockNames));
  SetLength(FBlockIds, Length(SavedBlockIds));
  for I := 0 to High(SavedBlockNames) do
  begin
    FBlockNames[I] := SavedBlockNames[I];
    FBlockIds[I] := SavedBlockIds[I];
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
  SavedAllocaCount, SavedBlockCount: LongInt;
  SavedAllocas: array of TAllocaEntry;
  SavedBlockNames: array of string;
  SavedBlockIds: array of THIRBlockId;
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
  SavedAllocaCount := FAllocaCount;
  SetLength(SavedAllocas, FAllocaCount);
  for I := 0 to FAllocaCount - 1 do
    SavedAllocas[I] := FAllocas[I];
  SavedBlockCount := FBlockCount;
  SetLength(SavedBlockNames, FBlockCount);
  SetLength(SavedBlockIds, FBlockCount);
  for I := 0 to FBlockCount - 1 do
  begin
    SavedBlockNames[I] := FBlockNames[I];
    SavedBlockIds[I] := FBlockIds[I];
  end;

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
  FAllocaCount := 0;
  FBlockCount := 0;

  ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[0].ValueId;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikAlloca;
  Instr.TypeId := GetPtrType;
  EmitInstr(Instr);
  ObjSlot := Instr.ResultId;
  RegisterAllocaEntry('obj', ObjSlot, GetPtrType, False);
  EmitStore(GetPtrType, ParamValueId, ObjSlot);

  for I := High(Meta.Fields) downto 0 do
  begin
    if not Meta.Fields[I].IsDynArray then
      Continue;

    PtrSlot := FieldSlotPtr(ParamValueId, Meta.Fields[I].Index);
    LenSlot := FieldSlotPtr(ParamValueId, Meta.Fields[I].Index + 1);
    if (PtrSlot = 0) or (LenSlot = 0) then
      Continue;

    PtrVal := EmitLoad(GetPtrType, PtrSlot);
    LenVal := EmitLoad(GetIntTypeByWidth(32, True), LenSlot);
    if not FSemaModel.LookupConstValue(
      AClassName + '.' + Meta.Fields[I].Name + '$arr_elem_size',
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
  FAllocaCount := SavedAllocaCount;
  SetLength(FAllocas, Length(SavedAllocas));
  for I := 0 to High(SavedAllocas) do
    FAllocas[I] := SavedAllocas[I];
  FBlockCount := SavedBlockCount;
  SetLength(FBlockNames, Length(SavedBlockNames));
  SetLength(FBlockIds, Length(SavedBlockIds));
  for I := 0 to High(SavedBlockNames) do
  begin
    FBlockNames[I] := SavedBlockNames[I];
    FBlockIds[I] := SavedBlockIds[I];
  end;
end;

procedure THIRBuilder.ProcessAssignArrElem(const ANode: TTypedHirNode);
var
  TabPos, TabPos2, TabPos3: LongInt;
  ArrName, Rest, IdxBlob, ValBlob, FieldIdxStr, PlainVarName: string;
  IdxVal, ValVal, BasePtr, ElemPtr, ObjPtr, FieldIdx: THIRValueId;
  StoreType, ValueType: THIRTypeId;
  TargetResult: THIRExprResult;
  Token: string;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  ArrName := Copy(ANode.Operand, 1, TabPos - 1);
  Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  if ArrName = 'self' then
  begin
    TabPos2 := Pos(#9, Rest);
    if TabPos2 = 0 then Exit;
    FieldIdxStr := Copy(Rest, 1, TabPos2 - 1);
    Rest := Copy(Rest, TabPos2 + 1, Length(Rest));

    if ANode.DisplayName <> '__field_setlength__' then
    begin
      TabPos3 := Pos(#9, Rest);
      if TabPos3 = 0 then Exit;
      IdxBlob := Copy(Rest, 1, TabPos3 - 1);
      ValBlob := Copy(Rest, TabPos3 + 1, Length(Rest));

      if LowerNodeTargetExprAddress(ANode, TargetResult) then
      begin
        ElemPtr := TargetResult.AddressValueId;
        if ElemPtr = 0 then
          Exit;

        ValVal := LowerNodeExprOrBlobTyped(ANode, ValBlob, ValueType);
        if ValVal = 0 then
          Exit;

        if ValueType <> 0 then
        begin
          if FModule.Types.GetType(ValueType).Kind = htkPointer then
            StoreType := GetPtrType
          else
            StoreType := GetIntType;
          if StoreType <> ValueType then
          begin
            ValVal := NormalizeScalarValueToType(ValVal, ValueType, StoreType);
            if ValVal = 0 then
              ValVal := ParseIntExprArg(ValBlob);
          end;
          if ValVal <> 0 then
            EmitStore(StoreType, ValVal, ElemPtr);
        end
        else
        begin
          Token := ExtractVarOperandName(ValBlob);
          if (Pos(' p' + #10, ValBlob) > 0) or
            ((Token <> '') and (FindAllocaType(Token) = GetPtrType)) then
            EmitStore(GetPtrType, ValVal, ElemPtr)
          else
            EmitStore(GetIntType, ValVal, ElemPtr);
        end;
        Exit;
      end;
    end;

    ObjPtr := FindAlloca('self');
    if ObjPtr = 0 then Exit;
    ObjPtr := EmitLoad(GetPtrType, ObjPtr);

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikLoad;
    Instr.TypeId := GetIntType;
    Instr.IntrinsicName := 'const:' + FieldIdxStr;
    EmitInstr(Instr);
    FieldIdx := Instr.ResultId;

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetPtrType;
    Instr.IntrinsicName := 'gep_i64';
    SetLength(Instr.Operands, 2);
    Instr.Operands[0] := MakeOperand(ObjPtr);
    Instr.Operands[1] := MakeOperand(FieldIdx);
    EmitInstr(Instr);
    ElemPtr := Instr.ResultId;

    if ANode.DisplayName = '__field_setlength__' then
    begin
      IdxVal := ParseIntExprArg(Rest);
      if IdxVal = 0 then Exit;
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := GetPtrType;
      Instr.IntrinsicName := 'arr_alloc';
      SetLength(Instr.Operands, 1);
      Instr.Operands[0] := MakeOperand(IdxVal);
      EmitInstr(Instr);
      EmitStore(GetPtrType, Instr.ResultId, ElemPtr);
    end
    else
    begin
      IdxVal := ParseIntExprArg(IdxBlob);
      ValVal := ParseIntExprArg(ValBlob);
      if (IdxVal = 0) or (ValVal = 0) then Exit;

      BasePtr := EmitLoad(GetPtrType, ElemPtr);

      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := GetPtrType;
      Instr.IntrinsicName := 'gep_i64';
      SetLength(Instr.Operands, 2);
      Instr.Operands[0] := MakeOperand(BasePtr);
      Instr.Operands[1] := MakeOperand(IdxVal);
      EmitInstr(Instr);
      ElemPtr := Instr.ResultId;

      EmitStore(GetIntType, ValVal, ElemPtr);
    end;
    Exit;
  end;

  TabPos2 := Pos(#9, Rest);
  if TabPos2 = 0 then Exit;
  IdxBlob := Copy(Rest, 1, TabPos2 - 1);
  ValBlob := Copy(Rest, TabPos2 + 1, Length(Rest));

  if LowerNodeTargetExprAddress(ANode, TargetResult) then
  begin
    ElemPtr := TargetResult.AddressValueId;
    if ElemPtr = 0 then
      Exit;

    ValVal := LowerNodeExprOrBlobTyped(ANode, ValBlob, ValueType);
    if ValVal = 0 then
      Exit;

    if ValueType <> 0 then
    begin
      if FModule.Types.GetType(ValueType).Kind = htkPointer then
        StoreType := GetPtrType
      else
        StoreType := GetIntType;
      if StoreType <> ValueType then
      begin
        ValVal := NormalizeScalarValueToType(ValVal, ValueType, StoreType);
        if ValVal = 0 then
          ValVal := ParseIntExprArg(ValBlob);
      end;
      if ValVal <> 0 then
        EmitStore(StoreType, ValVal, ElemPtr);
    end
    else
    begin
      Token := ExtractVarOperandName(ValBlob);
      if (Pos(' p' + #10, ValBlob) > 0) or
        ((Token <> '') and (FindAllocaType(Token) = GetPtrType)) then
        EmitStore(GetPtrType, ValVal, ElemPtr)
      else
        EmitStore(GetIntType, ValVal, ElemPtr);
    end;
    Exit;
  end;

  IdxVal := ParseIntExprArg(IdxBlob);
  ValVal := ParseIntExprArg(ValBlob);
  if (IdxVal = 0) or (ValVal = 0) then Exit;
  IdxVal := NormalizeArrayIndexValue(ArrName, IdxVal);
  if IdxVal = 0 then Exit;

  BasePtr := EmitLoad(GetPtrType, FindAlloca(ArrName + '$ptr'));

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(BasePtr);
  Instr.Operands[1] := MakeOperand(IdxVal);
  EmitInstr(Instr);
  ElemPtr := Instr.ResultId;

  PlainVarName := ExtractPlainVarOperandName(ValBlob);
  if (Pos(' p' + #10, ValBlob) > 0) or
    ((PlainVarName <> '') and (FindAllocaType(PlainVarName) = GetPtrType)) then
    EmitStore(GetPtrType, ValVal, ElemPtr)
  else
    EmitStore(GetIntType, ValVal, ElemPtr);
end;

procedure THIRBuilder.ProcessMethodBegin(const ANode: TTypedHirNode);
var
  I, ColonPos, ParamCount, Pos2: LongInt;
  FuncName, Rest, ParamTypes, RetSuffix: string;
  EntryBlock: THIRBlockId;
  ParamValueId: THIRValueId;
  Instr: THIRInstr;
  RetType: THIRTypeId;
begin
  FSavedFuncId := FCurrentFuncId;
  FSavedBlockId := FCurrentBlockId;
  FSavedEntryBlockId := FEntryBlockId;
  FSavedAllocaCount := FAllocaCount;
  FInStartFunc := False;
  SetLength(FSavedAllocas, FAllocaCount);
  for I := 0 to FAllocaCount - 1 do
    FSavedAllocas[I] := FAllocas[I];
  FSavedBlockCount := FBlockCount;
  SetLength(FSavedBlockNames, FBlockCount);
  SetLength(FSavedBlockIds, FBlockCount);
  for I := 0 to FBlockCount - 1 do
  begin
    FSavedBlockNames[I] := FBlockNames[I];
    FSavedBlockIds[I] := FBlockIds[I];
  end;

  FuncName := ANode.DisplayName;
  Rest := ANode.Operand;
  ColonPos := Pos(':', Rest);
  ParamCount := 0;
  ParamTypes := '';
  RetSuffix := '';
  if ColonPos > 0 then
  begin
    ParamCount := StrToIntDef(Copy(Rest, 1, ColonPos - 1), 0);
    ParamTypes := Copy(Rest, ColonPos + 1, Length(Rest));
    Pos2 := Pos(':', ParamTypes);
    if Pos2 > 0 then
    begin
      RetSuffix := Copy(ParamTypes, Pos2 + 1, Length(ParamTypes));
      ParamTypes := Copy(ParamTypes, 1, Pos2 - 1);
    end;
  end;

  if RetSuffix = 's' then
  begin
    RetType := GetStringType;
  end
  else if RetSuffix = 'p' then
    RetType := GetPtrType
  else
    RetType := GetIntType;

  FCurrentFuncId := FModule.AddFunction(FuncName, RetType);
  if RetSuffix = 's' then
  begin
    FModule.SetFunctionTStringReturnAbi(FCurrentFuncId, True);
    FModule.AddFunctionParam(FCurrentFuncId, 'sret_ptr', GetPtrType, False, False);
  end;
  FModule.AddFunctionParam(FCurrentFuncId, 'self', GetPtrType, False, False);
  for I := 1 to ParamCount - 1 do
  begin
    if (I < Length(ParamTypes)) and (ParamTypes[I + 1] = 's') then
    begin
      FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I - 1) + '_ptr', GetPtrType, False, False);
      FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I - 1) + '_len', GetIntTypeByWidth(32, True), False, False);
    end
    else if (I < Length(ParamTypes)) and (ParamTypes[I + 1] = 'v') then
      FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I - 1), GetPtrType, True, False)
    else if (I < Length(ParamTypes)) and
      ((ParamTypes[I + 1] = 'p') or (ParamTypes[I + 1] = 'r')) then
      FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I - 1), GetPtrType, False, False)
    else
      FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I - 1), GetIntType, False, False);
  end;

  EntryBlock := FModule.AddBlock(FCurrentFuncId, 'entry');
  FModule.SetEntryBlock(FCurrentFuncId, EntryBlock);
  FCurrentBlockId := EntryBlock;
  FEntryBlockId := EntryBlock;
  FBlockTerminated := False;
  FAllocaCount := 0;
  FGlobalRefCount := 0;
  FBlockCount := 0;

  if RetSuffix = 's' then
  begin
    FSretValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[0].ValueId;
    ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[1].ValueId;
  end
  else
  begin
    FSretValueId := 0;
    ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[0].ValueId;
  end;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikAlloca;
  Instr.TypeId := GetPtrType;
  EmitInstr(Instr);
  RegisterAllocaEntry('self', Instr.ResultId, GetPtrType, False);
  EmitStore(GetPtrType, ParamValueId, Instr.ResultId);

  FPendingParamCount := ParamCount - 1;
  if RetSuffix = 's' then
    FPendingParamLlvmIdx := 2
  else
    FPendingParamLlvmIdx := 1;
end;

procedure THIRBuilder.ProcessClassNew(const ANode: TTypedHirNode);
var
  I, TabPos: LongInt;
  VarName, Rest, CtorName, ArgBlob: string;
  SizeVal, PtrVal, ArgValue, V, LenVal: THIRValueId;
  ArgType: THIRTypeId;
  Instr: THIRInstr;
  ArgOps: array of THIROperand;
  ArgCount: LongInt;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  VarName := Copy(ANode.Operand, 1, TabPos - 1);
  Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  TabPos := Pos(#9, Rest);
  if TabPos > 0 then
  begin
    CtorName := Copy(Rest, 1, TabPos - 1);
    Rest := Copy(Rest, TabPos + 1, Length(Rest));
  end
  else
  begin
    CtorName := Rest;
    Rest := '';
  end;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntTypeByWidth(64, True);
  Instr.IntrinsicName := 'const:' + ANode.DisplayName;
  EmitInstr(Instr);
  SizeVal := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'class_alloc';
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeOperand(SizeVal);
  EmitInstr(Instr);
  PtrVal := Instr.ResultId;

  V := FindAlloca(VarName);
  if V = 0 then
    EnsureAlloca(VarName, GetPtrType)
  else if not IsVarParamAlloca(VarName) then
  begin
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikAlloca;
    Instr.TypeId := GetPtrType;
    EmitInstr(Instr);
    for I := 0 to FAllocaCount - 1 do
      if SameText(FAllocas[I].Name, VarName) then
      begin
        FAllocas[I].Value := Instr.ResultId;
        FAllocas[I].TypeId := GetPtrType;
        Break;
      end;
  end;
  V := FindAlloca(VarName);
  if IsVarParamAlloca(VarName) then
    EmitStore(GetPtrType, PtrVal, EmitLoad(GetPtrType, V))
  else
    EmitStore(GetPtrType, PtrVal, V);

  ArgCount := 1;
  SetLength(ArgOps, 1);
  ArgOps[0] := MakeTypedOperand(PtrVal, GetPtrType);
  while Rest <> '' do
  begin
    TabPos := Pos(#9, Rest);
    if TabPos > 0 then
    begin
      ArgBlob := Copy(Rest, 1, TabPos - 1);
      Rest := Copy(Rest, TabPos + 1, Length(Rest));
    end
    else
    begin
      ArgBlob := Rest;
      Rest := '';
    end;
    if (Length(ArgBlob) > 7) and (Copy(ArgBlob, 1, 7) = 'strvar ') then
    begin
      VarName := Copy(ArgBlob, 8, Length(ArgBlob));
      if (Length(VarName) > 0) and (VarName[Length(VarName)] = #10) then
        VarName := Copy(VarName, 1, Length(VarName) - 1);
      ArgValue := FindAlloca(VarName + '$ts');
      if ArgValue <> 0 then
      begin
        PtrVal := EmitTStringData(ArgValue);
        LenVal := EmitTStringLen(ArgValue);
        if (PtrVal <> 0) and (LenVal <> 0) then
        begin
          SetLength(ArgOps, ArgCount + 2);
          ArgOps[ArgCount] := MakeTypedOperand(PtrVal, GetPtrType);
          ArgOps[ArgCount + 1] := MakeTypedOperand(LenVal, GetIntTypeByWidth(32, True));
          Inc(ArgCount, 2);
        end;
      end;
    end
    else
    begin
      ArgValue := ParseIntExprArgTyped(ArgBlob, ArgType);
      if ArgValue <> 0 then
      begin
        SetLength(ArgOps, ArgCount + 1);
        if ArgType <> 0 then
          ArgOps[ArgCount] := MakeTypedOperand(ArgValue, ArgType)
        else
          ArgOps[ArgCount] := MakeOperand(ArgValue);
        Inc(ArgCount);
      end;
    end;
  end;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikCall;
  Instr.TypeId := GetIntType;
  Instr.CallTarget := CtorName;
  Instr.Operands := ArgOps;
  EmitInstr(Instr);
end;

procedure THIRBuilder.EnsureVmtForClass(const AClassName: string);
var
  VmtCount: Int64;
  I, J: LongInt;
  Funcs: array of string;
  FuncName, ParentClass: string;
  Meta: TTypeMetadata;
begin
  for J := 0 to FModule.VmtGlobalCount - 1 do
    if FModule.VmtGlobalAt(J).ClassName = AClassName then
      Exit;
  if FSemaModel.GetTypeMetaByName(AClassName, Meta) then
  begin
    VmtCount := Meta.VmtCount;
    ParentClass := Meta.ParentClassName;
  end
  else
  begin
    if not FSemaModel.LookupConstValue(AClassName + '$vmt_count', VmtCount) then
      VmtCount := 0;
    if not FSemaModel.LookupStringConstValue(AClassName + '$parent_class', ParentClass) then
      ParentClass := '';
  end;
  SetLength(Funcs, VmtCount + 1);
  if ParentClass <> '' then
  begin
    Funcs[0] := ParentClass + '.vmt';
    EnsureVmtForClass(ParentClass);
  end
  else
    Funcs[0] := '';
  for I := 0 to VmtCount - 1 do
  begin
    if FSemaModel.GetTypeMetaByName(AClassName, Meta) and
      (I < Length(Meta.VmtSlots)) then
      FuncName := Meta.VmtSlots[I].FuncQualName
    else if not FSemaModel.LookupStringConstValue(
      AClassName + '$vmt_func_' + IntToStr(I), FuncName) then
      FuncName := '';
    Funcs[I + 1] := FuncName;
  end;
  FModule.AddVmtGlobal(AClassName, Funcs);
end;

procedure THIRBuilder.ProcessVmtStore(const ANode: TTypedHirNode);
var
  ClsName, FuncName, VarName, ParentClass, AbstractCheck: string;
  VmtCount: Int64;
  I, TabPos: LongInt;
  Funcs: array of string;
  ObjPtr, ZeroVal, SlotPtr: THIRValueId;
  Instr: THIRInstr;
  Meta: TTypeMetadata;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos > 0 then
  begin
    VarName := Copy(ANode.Operand, 1, TabPos - 1);
    ClsName := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));
  end
  else
  begin
    VarName := 'self';
    ClsName := ANode.Operand;
  end;

  if FSemaModel.GetTypeMetaByName(ClsName, Meta) then
  begin
    VmtCount := Meta.VmtCount;
    ParentClass := Meta.ParentClassName;
  end
  else
  begin
    if not FSemaModel.LookupConstValue(ClsName + '$vmt_count', VmtCount) then
      VmtCount := 0;
    if not FSemaModel.LookupStringConstValue(ClsName + '$parent_class', ParentClass) then
      ParentClass := '';
  end;

  SetLength(Funcs, VmtCount + 1);
  if ParentClass <> '' then
    Funcs[0] := ParentClass + '.vmt'
  else
    Funcs[0] := '';
  for I := 0 to VmtCount - 1 do
  begin
    if FSemaModel.GetTypeMetaByName(ClsName, Meta) and
      (I < Length(Meta.VmtSlots)) then
      FuncName := Meta.VmtSlots[I].FuncQualName
    else if not FSemaModel.LookupStringConstValue(
      ClsName + '$vmt_func_' + IntToStr(I), FuncName) then
      FuncName := '';
    if (FuncName <> '') and
      FSemaModel.LookupStringConstValue(
        Copy(FuncName, 1, Pos('.', FuncName) - 1) + '$abstract_' +
        Copy(FuncName, Pos('.', FuncName) + 1, Length(FuncName)), AbstractCheck) then
      FuncName := '';
    Funcs[I + 1] := FuncName;
  end;
  FModule.AddVmtGlobal(ClsName, Funcs);

  while ParentClass <> '' do
  begin
    if FSemaModel.GetTypeMetaByName(ParentClass, Meta) then
    begin
      VmtCount := Meta.VmtCount;
      SetLength(Funcs, VmtCount + 1);
      if Meta.ParentClassName <> '' then
        Funcs[0] := Meta.ParentClassName + '.vmt'
      else
        Funcs[0] := '';
      for I := 0 to VmtCount - 1 do
      begin
        if I < Length(Meta.VmtSlots) then
          FuncName := Meta.VmtSlots[I].FuncQualName
        else
          FuncName := '';
        if (FuncName <> '') and (Pos('.', FuncName) > 0) and
          FSemaModel.LookupStringConstValue(
            Copy(FuncName, 1, Pos('.', FuncName) - 1) + '$abstract_' +
            Copy(FuncName, Pos('.', FuncName) + 1, Length(FuncName)), AbstractCheck) then
          FuncName := '';
        Funcs[I + 1] := FuncName;
      end;
      FModule.AddVmtGlobal(ParentClass, Funcs);
      ParentClass := Meta.ParentClassName;
    end
    else if FSemaModel.LookupConstValue(ParentClass + '$vmt_count', VmtCount) then
    begin
      SetLength(Funcs, VmtCount + 1);
      if FSemaModel.LookupStringConstValue(ParentClass + '$parent_class', FuncName) and
        (FuncName <> '') then
        Funcs[0] := FuncName + '.vmt'
      else
        Funcs[0] := '';
      for I := 0 to VmtCount - 1 do
      begin
        if not FSemaModel.LookupStringConstValue(
          ParentClass + '$vmt_func_' + IntToStr(I), FuncName) then
          FuncName := '';
        if (FuncName <> '') and (Pos('.', FuncName) > 0) and
          FSemaModel.LookupStringConstValue(
            Copy(FuncName, 1, Pos('.', FuncName) - 1) + '$abstract_' +
            Copy(FuncName, Pos('.', FuncName) + 1, Length(FuncName)), AbstractCheck) then
          FuncName := '';
        Funcs[I + 1] := FuncName;
      end;
      FModule.AddVmtGlobal(ParentClass, Funcs);
      if not FSemaModel.LookupStringConstValue(ParentClass + '$parent_class', ParentClass) then
        ParentClass := '';
    end
    else
    begin
      SetLength(Funcs, 1);
      Funcs[0] := '';
      FModule.AddVmtGlobal(ParentClass, Funcs);
      ParentClass := '';
    end;
  end;

  ObjPtr := FindAlloca(VarName);
  if ObjPtr = 0 then Exit;
  ObjPtr := EmitLoad(GetPtrType, ObjPtr);
  if IsVarParamAlloca(VarName) then
    ObjPtr := EmitLoad(GetPtrType, ObjPtr);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:0';
  EmitInstr(Instr);
  ZeroVal := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(ObjPtr);
  Instr.Operands[1] := MakeOperand(ZeroVal);
  EmitInstr(Instr);
  SlotPtr := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'vmt_store';
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(SlotPtr, GetPtrType);
  Instr.CallTarget := ClsName;
  EmitInstr(Instr);

  if FSemaModel.GetTypeMetaByName(ClsName, Meta) and
    (Length(Meta.InterfaceSlots) > 0) then
  begin
    for I := 0 to High(Meta.InterfaceSlots) do
    begin
      EmitInterfaceSlotStore(ObjPtr, ClsName, Meta.InterfaceSlots[I]);
    end;
  end;
end;

procedure THIRBuilder.EmitInterfaceSlotStore(AObjPtr: THIRValueId;
  const AClassName: string; const ASlot: TInterfaceSlotMeta);
var
  Instr: THIRInstr;
  OffsetVal, SlotPtr: THIRValueId;
  IntfMeta: TTypeMetadata;
  ThunkNames: array of string;
  ParamCounts: array of LongInt;
  I: LongInt;
  SymId: LongInt;
  IntfName: string;
begin
  IntfName := ASlot.InterfaceName;
  if not FSemaModel.GetTypeMetaByName(IntfName, IntfMeta) then
    Exit;
  SetLength(ThunkNames, IntfMeta.VmtCount);
  SetLength(ParamCounts, IntfMeta.VmtCount);
  for I := 0 to IntfMeta.VmtCount - 1 do
  begin
    if I < Length(IntfMeta.VmtSlots) then
    begin
      ThunkNames[I] := AClassName + '._intf_thunk_' + IntfName + '_' +
        IntfMeta.VmtSlots[I].MethodName;
      SymId := FSemaModel.FindSymbolByName(
        IntfName + '.' + IntfMeta.VmtSlots[I].MethodName);
      if SymId > 0 then
        ParamCounts[I] := FSemaModel.SymbolAt(SymId - 1).ParamCount
      else
        ParamCounts[I] := 0;
    end
    else
    begin
      ThunkNames[I] := '';
      ParamCounts[I] := 0;
    end;
  end;
  FModule.AddImtGlobal(AClassName, IntfName, ThunkNames, ParamCounts, ASlot.SlotOffset);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:' + IntToStr(ASlot.SlotOffset);
  EmitInstr(Instr);
  OffsetVal := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(AObjPtr);
  Instr.Operands[1] := MakeOperand(OffsetVal);
  EmitInstr(Instr);
  SlotPtr := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'imt_store';
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(SlotPtr, GetPtrType);
  Instr.CallTarget := AClassName + '.imt.' + IntfName;
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessExceptionNode(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
  LabelName: string;
  BlockId: THIRBlockId;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  case ANode.NodeKind of
    hnkTryBeginRuntime:     Instr.Kind := hikTryBegin;
    hnkTryEndRuntime:       Instr.Kind := hikTryEnd;
    hnkFinallyBeginRuntime: Instr.Kind := hikFinallyBegin;
    hnkFinallyEndRuntime:   Instr.Kind := hikFinallyEnd;
    hnkExceptBeginRuntime:  Instr.Kind := hikExceptBegin;
    hnkExceptEndRuntime:    Instr.Kind := hikExceptEnd;
    hnkRaiseRuntime:
    begin
      if ANode.Operand <> '' then
      begin
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikIntrinsic;
        Instr.TypeId := 0;
        Instr.IntrinsicName := 'exc_store';
        SetLength(Instr.Operands, 1);
        Instr.Operands[0] := MakeTypedOperand(ParseIntExprArg(ANode.Operand), GetPtrType);
        EmitInstr(Instr);
      end;
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.Kind := hikRaise;
      EmitInstr(Instr);
      Exit;
    end;
  else
    Exit;
  end;
  if (ANode.NodeKind = hnkTryBeginRuntime) and (ANode.Operand <> '') then
  begin
    LabelName := ANode.Operand;
    if (Length(LabelName) > 0) and (LabelName[Length(LabelName)] = #10) then
      LabelName := Copy(LabelName, 1, Length(LabelName) - 1);
    BlockId := EnsureBlock(LabelName);
    Instr.IntrinsicName := 'bb' + IntToStr(BlockId);
  end
  else
    Instr.IntrinsicName := ANode.Operand;
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessFieldStore(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  VarName, Rest, IdxStr, ValBlob, Token: string;
  ObjPtr, IdxVal, ValVal, FieldPtr: THIRValueId;
  StoreType, ValueType: THIRTypeId;
  TargetResult: THIRExprResult;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  VarName := Copy(ANode.Operand, 1, TabPos - 1);
  Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  TabPos := Pos(#9, Rest);
  if TabPos = 0 then Exit;
  IdxStr := Copy(Rest, 1, TabPos - 1);
  ValBlob := Copy(Rest, TabPos + 1, Length(Rest));

  if LowerNodeTargetExprAddress(ANode, TargetResult) then
    FieldPtr := TargetResult.AddressValueId
  else
  begin
    ObjPtr := FindAlloca(VarName);
    if ObjPtr = 0 then Exit;
    ObjPtr := EmitLoad(GetPtrType, ObjPtr);

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikLoad;
    Instr.TypeId := GetIntType;
    Instr.IntrinsicName := 'const:' + IdxStr;
    EmitInstr(Instr);
    IdxVal := Instr.ResultId;

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetPtrType;
    Instr.IntrinsicName := 'gep_i64';
    SetLength(Instr.Operands, 2);
    Instr.Operands[0] := MakeOperand(ObjPtr);
    Instr.Operands[1] := MakeOperand(IdxVal);
    EmitInstr(Instr);
    FieldPtr := Instr.ResultId;
  end;
  if FieldPtr = 0 then Exit;

  ValVal := LowerNodeExprOrBlobTyped(ANode, ValBlob, ValueType);
  if ValVal <> 0 then
  begin
    if ValueType <> 0 then
    begin
      if FModule.Types.GetType(ValueType).Kind = htkPointer then
        StoreType := GetPtrType
      else
        StoreType := GetIntType;
      if StoreType <> ValueType then
      begin
        ValVal := NormalizeScalarValueToType(ValVal, ValueType, StoreType);
        if ValVal = 0 then
          ValVal := ParseIntExprArg(ValBlob);
      end;
      if ValVal <> 0 then
        EmitStore(StoreType, ValVal, FieldPtr);
    end
    else if (Length(ValBlob) > 4) and (Copy(ValBlob, 1, 4) = 'var ') then
    begin
      Token := Copy(ValBlob, 5, Length(ValBlob));
      if (Length(Token) > 0) and (Token[Length(Token)] = #10) then
        Token := Copy(Token, 1, Length(Token) - 1);
      if FindAllocaType(Token) = GetPtrType then
        EmitStore(GetPtrType, ValVal, FieldPtr)
      else
        EmitStore(GetIntType, ValVal, FieldPtr);
    end
    else if (Pos(' p' + #10, ValBlob) > 0) or
      (Copy(ValBlob, 1, 4) = 'null') then
      EmitStore(GetPtrType, ValVal, FieldPtr)
    else
      EmitStore(GetIntType, ValVal, FieldPtr);
  end;
end;

procedure THIRBuilder.ProcessRecordFieldStore(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  VarName, Rest, IdxStr, ValBlob: string;
  RecPtr, IdxVal, ValVal, FieldPtr: THIRValueId;
  ValueType: THIRTypeId;
  TargetResult: THIRExprResult;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  VarName := Copy(ANode.Operand, 1, TabPos - 1);
  Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  TabPos := Pos(#9, Rest);
  if TabPos = 0 then Exit;
  IdxStr := Copy(Rest, 1, TabPos - 1);
  ValBlob := Copy(Rest, TabPos + 1, Length(Rest));

  if LowerNodeTargetExprAddress(ANode, TargetResult) then
    FieldPtr := TargetResult.AddressValueId
  else
  begin
    RecPtr := FindAlloca(VarName);
    if RecPtr = 0 then Exit;

    if FindAllocaType(VarName) = GetPtrType then
      RecPtr := EmitLoad(GetPtrType, RecPtr);

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikLoad;
    Instr.TypeId := GetIntType;
    Instr.IntrinsicName := 'const:' + IdxStr;
    EmitInstr(Instr);
    IdxVal := Instr.ResultId;

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetPtrType;
    Instr.IntrinsicName := 'gep_i64';
    SetLength(Instr.Operands, 2);
    Instr.Operands[0] := MakeOperand(RecPtr);
    Instr.Operands[1] := MakeOperand(IdxVal);
    EmitInstr(Instr);
    FieldPtr := Instr.ResultId;
  end;
  if FieldPtr = 0 then Exit;

  ValVal := LowerNodeExprOrBlobTyped(ANode, ValBlob, ValueType);
  if ValVal <> 0 then
  begin
    if ValueType <> 0 then
    begin
      ValVal := NormalizeScalarValueToType(ValVal, ValueType, GetIntType);
      if ValVal = 0 then
        ValVal := ParseIntExprArg(ValBlob);
    end;
    if ValVal <> 0 then
      EmitStore(GetIntType, ValVal, FieldPtr);
  end;
end;

procedure THIRBuilder.ProcessRecordCopy(const ANode: TTypedHirNode);
var
  TabPos, I, FieldCount, Code: LongInt;
  DstName, Rest, SrcName, CountStr: string;
  DstPtr, SrcPtr, IdxVal, SrcField, DstField, LoadedVal: THIRValueId;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  DstName := Copy(ANode.Operand, 1, TabPos - 1);
  Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  TabPos := Pos(#9, Rest);
  if TabPos = 0 then Exit;
  SrcName := Copy(Rest, 1, TabPos - 1);
  CountStr := Copy(Rest, TabPos + 1, Length(Rest));
  Val(CountStr, FieldCount, Code);
  if Code <> 0 then Exit;

  DstPtr := FindAlloca(DstName);
  SrcPtr := FindAlloca(SrcName);
  if (DstPtr = 0) or (SrcPtr = 0) then Exit;

  for I := 0 to FieldCount - 1 do
  begin
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikLoad;
    Instr.TypeId := GetIntType;
    Instr.IntrinsicName := 'const:' + IntToStr(I);
    EmitInstr(Instr);
    IdxVal := Instr.ResultId;

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetPtrType;
    Instr.IntrinsicName := 'gep_i64';
    SetLength(Instr.Operands, 2);
    Instr.Operands[0] := MakeOperand(SrcPtr);
    Instr.Operands[1] := MakeOperand(IdxVal);
    EmitInstr(Instr);
    SrcField := Instr.ResultId;

    LoadedVal := EmitLoad(GetIntType, SrcField);

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikLoad;
    Instr.TypeId := GetIntType;
    Instr.IntrinsicName := 'const:' + IntToStr(I);
    EmitInstr(Instr);
    IdxVal := Instr.ResultId;

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetPtrType;
    Instr.IntrinsicName := 'gep_i64';
    SetLength(Instr.Operands, 2);
    Instr.Operands[0] := MakeOperand(DstPtr);
    Instr.Operands[1] := MakeOperand(IdxVal);
    EmitInstr(Instr);
    DstField := Instr.ResultId;

    EmitStore(GetIntType, LoadedVal, DstField);
  end;
end;

procedure THIRBuilder.ProcessNode(const ANode: TTypedHirNode);
begin
  if (FPendingObjectFreeDestroyName <> '') and
    (ANode.NodeKind <> hnkCallRuntime) and
    (ANode.NodeKind <> hnkObjectFreeRuntime) then
  begin
    FPendingObjectFreeDestroyName := '';
    FPendingObjectFreeReceiverName := '';
    FPendingObjectFreeReceiverValue := 0;
    FPendingObjectFreeCleanupClass := '';
    FPendingObjectFreeHeapRelease := False;
  end;

  if (FPendingCleanupCount > 0) and
    (ANode.NodeKind <> hnkDynArrayCleanupRuntime) and
    (ANode.NodeKind <> hnkTStringCleanupRuntime) and
    (ANode.NodeKind <> hnkHaltCallRuntime) and
    (ANode.NodeKind <> hnkHaltCall) and
    (ANode.NodeKind <> hnkRetRuntime) and
    (ANode.NodeKind <> hnkRetTStringRuntime) then
    FlushPendingCleanupNodes;

  { Set current source position from node's symbol for debug info }
  SetCurrentSourcePosFromSymbol(ANode.SymbolId);

  case ANode.NodeKind of
    hnkVarDeclRuntime, hnkVarDeclArrRuntime,
    hnkVarDeclArrBorrowedRuntime, hnkVarDeclPtrRuntime,
    hnkVarDeclVarrefRuntime, hnkVarDeclRecordRuntime:
      ProcessVarDecl(ANode);
    hnkVarDeclTStringRuntime:
      ProcessVarDeclTString(ANode);
    hnkAssignTStringLiteralRuntime:
      ProcessAssignTStringLiteral(ANode);
    hnkAssignTStringCopyRuntime:
      ProcessAssignTStringCopy(ANode);
    hnkAssignTStringCallRuntime:
      ProcessAssignTStringCall(ANode);
    hnkAssignTStringConcatRuntime:
      ProcessAssignTStringConcat(ANode);
    hnkAssignTStringFieldLoadRuntime:
      ProcessAssignTStringFieldLoad(ANode);
    hnkFieldStoreTStringRuntime:
      ProcessFieldStoreTString(ANode);
    hnkAssignRuntime:
      ProcessAssign(ANode);
    hnkHaltCallRuntime:
      ProcessHaltCall(ANode);
    hnkHaltCall:
      ProcessHaltCallConst(ANode);
    hnkCondBrRuntime:
      ProcessCondBr(ANode);
    hnkSwitchRuntime:
      ProcessSwitch(ANode);
    hnkBrRuntime:
      ProcessBr(ANode);
    hnkBlockLabelRuntime:
      ProcessBlockLabel(ANode);
    hnkFunctionBodyBegin:
      ProcessFunctionBegin(ANode);
    hnkFunctionBodyEnd:
      ProcessFunctionEnd(ANode);
    hnkProcedureDecl, hnkFunctionDecl:
      ProcessExternalDecl(ANode);
    hnkRetRuntime:
      ProcessRetRuntime(ANode);
    hnkRetTStringRuntime:
      ProcessRetTString(ANode);
    hnkCallRuntime:
      ProcessCallRuntime(ANode);
    hnkStringTempOwnedRuntime:
      ProcessStringTempOwnedRuntime(ANode);
    hnkStringTempBorrowArgRuntime:
      ProcessStringTempBorrowArgRuntime(ANode);
    hnkStringTempLengthRuntime:
      ProcessStringTempLengthRuntime(ANode);
    hnkStringTempReleaseRuntime:
      ProcessStringTempReleaseRuntime(ANode);
    hnkObjectFreeRuntime:
      ProcessObjectFreeRuntime(ANode);
    hnkTStringFromIntRuntime:
      ProcessIntToStr(ANode);
    hnkTStringCopyRuntime:
      ProcessCopyStr(ANode);
    hnkWriteIntRuntime:
      ProcessWriteInt(ANode);
    hnkWriteStringRuntime:
      ProcessWriteString(ANode);
    hnkWriteCall:
      ProcessWriteCall(ANode);
    hnkWriteStrVarRuntime:
      ProcessWriteStrVar(ANode);
    hnkSetLengthArrRuntime:
      ProcessSetLengthArr(ANode);
    hnkSetLengthFieldArrRuntime:
      ProcessSetLengthFieldArr(ANode);
    hnkDynArrayCleanupRuntime:
      QueueCleanupNode(ANode);
    hnkTStringCleanupRuntime:
      QueueCleanupNode(ANode);
    hnkManagedRecordCleanupRuntime:
      QueueCleanupNode(ANode);
    hnkAssignArrElemRuntime:
      ProcessAssignArrElem(ANode);
    hnkMethodBodyBegin:
      ProcessMethodBegin(ANode);
    hnkClassNewRuntime:
      ProcessClassNew(ANode);
    hnkFieldStoreRuntime:
      ProcessFieldStore(ANode);
    hnkRecordFieldStoreRuntime:
      ProcessRecordFieldStore(ANode);
    hnkRecordCopyRuntime:
      ProcessRecordCopy(ANode);
    hnkVmtStoreRuntime:
      ProcessVmtStore(ANode);
    hnkIntfAdjustRuntime:
      ProcessIntfAdjust(ANode);
    hnkIntfAddRefRuntime:
      ProcessIntfAddRef(ANode);
    hnkIntfReleaseRuntime:
      ProcessIntfRelease(ANode);
    hnkTryBeginRuntime, hnkTryEndRuntime,
    hnkFinallyBeginRuntime, hnkFinallyEndRuntime,
    hnkExceptBeginRuntime, hnkExceptEndRuntime,
    hnkRaiseRuntime:
      ProcessExceptionNode(ANode);
    hnkProcessInitRuntime:
      EmitProcessInit;
    hnkProcessFiniRuntime:
      EmitProcessFini;
    hnkUnitInitRuntime:
      ;  // handled by SeedUnitLifecycleBodies → function-body-begin
    hnkUnitFiniRuntime:
      ;  // handled by SeedUnitLifecycleBodies → function-body-begin
    hnkFillCharRuntime:
      ProcessFillCharRuntime(ANode);
    hnkMoveRuntime:
      ProcessMoveRuntime(ANode);
    hnkInterlockedCasRuntime, hnkInterlockedXchgRuntime,
    hnkInterlockedFetchAddRuntime, hnkInterlockedCas64Runtime,
    hnkInterlockedFetchAdd64Runtime:
      ProcessInterlockedOp(ANode);
    hnkGetMemRuntime:
      ProcessGetMemRuntime(ANode);
    hnkFreeMemRuntime:
      ProcessFreeMemRuntime(ANode);
    hnkAssignedRuntime:
      ProcessAssignedRuntime(ANode);
    hnkUnknown:
      ;
  end;
end;

procedure THIRBuilder.QueueCleanupNode(const ANode: TTypedHirNode);
begin
  if FPendingCleanupCount >= Length(FPendingCleanupNodes) then
    SetLength(FPendingCleanupNodes, FPendingCleanupCount + 8);
  FPendingCleanupNodes[FPendingCleanupCount] := ANode;
  Inc(FPendingCleanupCount);
end;

procedure THIRBuilder.FlushPendingCleanupNodes;
var
  I: LongInt;
  Node: TTypedHirNode;
begin
  for I := 0 to FPendingCleanupCount - 1 do
  begin
    Node := FPendingCleanupNodes[I];
    case Node.NodeKind of
      hnkDynArrayCleanupRuntime:
        ProcessDynArrayCleanup(Node);
      hnkTStringCleanupRuntime:
        EmitTStringFini(FindAlloca(Node.Operand + '$ts'));
      hnkManagedRecordCleanupRuntime:
        ProcessManagedRecordCleanup(Node);
    end;
  end;
  FPendingCleanupCount := 0;
end;

procedure THIRBuilder.EmitProcessInit;
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikCall;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.CallTarget := 'np_process_init';
  EmitInstr(Instr);
end;

procedure THIRBuilder.EmitProcessFini;
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikCall;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.CallTarget := 'np_process_fini';
  EmitInstr(Instr);
end;

procedure THIRBuilder.Build;
var
  I: LongInt;
  Node: TTypedHirNode;
  EntryBlock: THIRBlockId;
  Instr: THIRInstr;
  FwdName, FwdRest: string;
  FwdColon, FwdColon2: LongInt;
  LOrder: array of string;
begin
  FFwdFuncCount := 0;
  for I := 0 to FSemaModel.TypedHirNodeCount - 1 do
  begin
    Node := FSemaModel.TypedHirNodeAt(I);
    if (Node.Kind = 'function-body-begin') or
       (Node.Kind = 'method-body-begin') then
    begin
      FwdName := Node.DisplayName;
      FwdRest := '';
      FwdColon := Pos(':', Node.Operand);
      if FwdColon > 0 then
      begin
        FwdRest := Copy(Node.Operand, FwdColon + 1, Length(Node.Operand));
        FwdColon2 := Pos(':', FwdRest);
        if FwdColon2 > 0 then
          FwdRest := Copy(FwdRest, FwdColon2 + 1, Length(FwdRest))
        else
          FwdRest := '';
      end;
      if FFwdFuncCount >= Length(FFwdFuncNames) then
      begin
        SetLength(FFwdFuncNames, FFwdFuncCount + 32);
        SetLength(FFwdFuncRetTypes, FFwdFuncCount + 32);
      end;
      FFwdFuncNames[FFwdFuncCount] := FwdName;
      if FwdRest = 'p' then
        FFwdFuncRetTypes[FFwdFuncCount] := GetPtrType
      else if (FwdRest = 's') or (FwdRest = 'so') then
        FFwdFuncRetTypes[FFwdFuncCount] := GetStringType
      else
        FFwdFuncRetTypes[FFwdFuncCount] := GetIntType;
      Inc(FFwdFuncCount);
    end;
  end;

  FCurrentFuncId := FModule.AddFunction('_start', GetIntType);
  EntryBlock := FModule.AddBlock(FCurrentFuncId, 'entry');
  FModule.SetEntryBlock(FCurrentFuncId, EntryBlock);
  FCurrentBlockId := EntryBlock;
  FEntryBlockId := EntryBlock;
  FBlockTerminated := False;

  for I := 0 to FSemaModel.TypedHirNodeCount - 1 do
  begin
    Node := FSemaModel.TypedHirNodeAt(I);
    ProcessNode(Node);
  end;

  if not FBlockTerminated then
  begin
    FlushPendingCleanupNodes;
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
    Instr.IntrinsicName := 'halt';
    Instr.CallTarget := '0';
    EmitInstr(Instr);
  end;

  // Transfer unit init order from semantic model to HIR module
  if FSemaModel.UnitInitOrderCount > 0 then
  begin
    SetLength(LOrder, FSemaModel.UnitInitOrderCount);
    for I := 0 to FSemaModel.UnitInitOrderCount - 1 do
      LOrder[I] := FSemaModel.UnitInitOrderAt(I);
    FModule.SetUnitInitOrder(LOrder);
  end;
end;

{ TString 24B runtime }

procedure THIRBuilder.ProcessVarDeclTString(const ANode: TTypedHirNode);
var
  ParamIdx: LongInt;
  ParamValueId: THIRValueId;
begin
  if FPendingParamCount > 0 then
  begin
    { Function parameter: store incoming sret/value into alloca }
    ParamIdx := FPendingParamLlvmIdx;
    ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[ParamIdx].ValueId;
    EnsureAlloca(ANode.Operand + '$ts', GetPtrType);
    EmitStore(GetPtrType, ParamValueId, FindAlloca(ANode.Operand + '$ts'));
    Dec(FPendingParamCount);
    Inc(FPendingParamLlvmIdx);
  end
  else if FInStartFunc then
  begin
    { Global variable: register as global }
    if FGlobalCount >= Length(FGlobalNames) then
    begin
      SetLength(FGlobalNames, FGlobalCount + 32);
      SetLength(FGlobalTypes, FGlobalCount + 32);
    end;
    FGlobalNames[FGlobalCount] := ANode.Operand + '$ts';
    FGlobalTypes[FGlobalCount] := GetPtrType;
    Inc(FGlobalCount);
    FModule.AddGlobal(ANode.Operand + '$ts', GetPtrType);
  end
  else
  begin
    { Local variable: single 24B alloca + tstring_init }
    EmitTStringInit(ANode.Operand);
  end;
end;

procedure THIRBuilder.EmitTStringInit(const AName: string);
var
  Instr: THIRInstr;
begin
  if FindAlloca(AName + '$ts') <> 0 then Exit;
  { alloca [24 x i8] — uses tstring IntrinsicName for emitter dispatch }
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikAlloca;
  Instr.TypeId := GetIntType; { placeholder — emitter overrides via IntrinsicName }
  Instr.IntrinsicName := 'tstring';
  Instr.CallTarget := AName;
  if (FCurrentFuncId <> 0) and (FEntryBlockId <> 0) then
    FModule.AddInstr(FCurrentFuncId, FEntryBlockId, Instr)
  else
    EmitInstr(Instr);
  RegisterAllocaEntry(AName + '$ts', Instr.ResultId, GetPtrType, False);
  { call tstring_init to zero-fill 24B }
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.Kind := hikIntrinsic;
  Instr.IntrinsicName := 'tstring_init';
  SetLength(Instr.Operands, 1);
  Instr.Operands[0].ValueId := FindAlloca(AName + '$ts');
  Instr.Operands[0].TypeId := GetPtrType;
  EmitInstr(Instr);
end;

procedure THIRBuilder.EmitTStringFini(AValue: THIRValueId);
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.Kind := hikIntrinsic;
  Instr.IntrinsicName := 'tstring_fini';
  SetLength(Instr.Operands, 1);
  Instr.Operands[0].ValueId := AValue;
  Instr.Operands[0].TypeId := GetPtrType;
  EmitInstr(Instr);
end;

procedure THIRBuilder.EmitTStringAssign(ADst, ASrc: THIRValueId);
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.Kind := hikIntrinsic;
  Instr.IntrinsicName := 'tstring_assign';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0].ValueId := ADst;
  Instr.Operands[0].TypeId := GetPtrType;
  Instr.Operands[1].ValueId := ASrc;
  Instr.Operands[1].TypeId := GetPtrType;
  EmitInstr(Instr);
end;

function THIRBuilder.EmitTStringLen(AValue: THIRValueId): THIRValueId;
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetIntTypeByWidth(32, True);
  Instr.IntrinsicName := 'tstring_len';
  SetLength(Instr.Operands, 1);
  Instr.Operands[0].ValueId := AValue;
  Instr.Operands[0].TypeId := GetPtrType;
  EmitInstr(Instr);
  Result := Instr.ResultId;
end;

function THIRBuilder.EmitTStringData(AValue: THIRValueId): THIRValueId;
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'tstring_data';
  SetLength(Instr.Operands, 1);
  Instr.Operands[0].ValueId := AValue;
  Instr.Operands[0].TypeId := GetPtrType;
  EmitInstr(Instr);
  Result := Instr.ResultId;
end;

{ Phase 4b: TString assignment operations }

procedure THIRBuilder.ProcessAssignTStringLiteral(const ANode: TTypedHirNode);
var
  DstName, LitValue: string;
  DstPtr, LitPtr, LenConst: THIRValueId;
  Instr: THIRInstr;
begin
  DstName := ANode.DisplayName;
  LitValue := ANode.Operand;
  DstPtr := FindAlloca(DstName + '$ts');
  if DstPtr = 0 then Exit;
  { Step 1: get literal data pointer via str_const }
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'str_const';
  Instr.CallTarget := LitValue;
  EmitInstr(Instr);
  LitPtr := Instr.ResultId;
  { Step 2: emit literal length as i32 constant }
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntTypeByWidth(32, True);
  Instr.IntrinsicName := 'const:' + IntToStr(Length(LitValue));
  EmitInstr(Instr);
  LenConst := Instr.ResultId;
  { Step 3: call tstring_from_literal(dst, lit, len) }
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.Kind := hikIntrinsic;
  Instr.IntrinsicName := 'tstring_from_literal';
  SetLength(Instr.Operands, 3);
  Instr.Operands[0].ValueId := DstPtr;
  Instr.Operands[0].TypeId := GetPtrType;
  Instr.Operands[1].ValueId := LitPtr;
  Instr.Operands[1].TypeId := GetPtrType;
  Instr.Operands[2].ValueId := LenConst;
  Instr.Operands[2].TypeId := GetIntTypeByWidth(32, True);
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessAssignTStringCopy(const ANode: TTypedHirNode);
var
  SrcName, DstName: string;
  SrcPtr, DstPtr: THIRValueId;
begin
  SrcName := ANode.DisplayName;
  DstName := ANode.Operand;
  if SameText(SrcName, DstName) then Exit;
  SrcPtr := FindAlloca(SrcName + '$ts');
  DstPtr := FindAlloca(DstName + '$ts');
  if (SrcPtr = 0) or (DstPtr = 0) then Exit;
  EmitTStringAssign(DstPtr, SrcPtr);
end;

procedure THIRBuilder.ProcessAssignTStringConcat(const ANode: TTypedHirNode);
var
  DstName, LhsOp, RhsOp: string;
  DstPtr, LhsPtr, RhsPtr: THIRValueId;
  TabPos: LongInt;
  Instr: THIRInstr;
begin
  DstName := ANode.DisplayName;
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  LhsOp := Copy(ANode.Operand, 1, TabPos - 1);
  RhsOp := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));
  DstPtr := FindAlloca(DstName + '$ts');
  LhsPtr := FindAlloca(LhsOp + '$ts');
  RhsPtr := FindAlloca(RhsOp + '$ts');
  if (DstPtr = 0) or (LhsPtr = 0) or (RhsPtr = 0) then Exit;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.Kind := hikIntrinsic;
  Instr.IntrinsicName := 'tstring_concat';
  SetLength(Instr.Operands, 3);
  Instr.Operands[0].ValueId := DstPtr;
  Instr.Operands[0].TypeId := GetPtrType;
  Instr.Operands[1].ValueId := LhsPtr;
  Instr.Operands[1].TypeId := GetPtrType;
  Instr.Operands[2].ValueId := RhsPtr;
  Instr.Operands[2].TypeId := GetPtrType;
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessAssignTStringCall(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
  FuncName, ArgBlob, DstName, PartBlob, ObjName, SlotText: string;
  DstPtr, V, DataPtr, LenVal, ObjSlot, SelfPtr, TablePtr, FnPtr,
    SlotVal: THIRValueId;
  TabPos, I, ArgPartCount, ArgCount, SlotIdx: LongInt;
  ArgParts: array of string;
  ArgValues: array of THIRValueId;
  ArgTypes: array of THIRTypeId;
  IsDynamicDispatch, IsInterfaceDispatch: Boolean;
begin
  FuncName := ANode.DisplayName;
  ArgBlob := ANode.Operand;
  TabPos := Pos(#9, ArgBlob);
  if TabPos > 0 then
  begin
    DstName := Copy(ArgBlob, 1, TabPos - 1);
    ArgBlob := Copy(ArgBlob, TabPos + 1, Length(ArgBlob));
  end
  else
  begin
    DstName := ArgBlob;
    ArgBlob := '';
  end;

  DstPtr := FindAlloca(DstName + '$ts');
  if DstPtr = 0 then
    Exit;

  IsDynamicDispatch := False;
  IsInterfaceDispatch := False;
  ObjName := '';
  if Copy(ArgBlob, 1, 7) = 'callee ' then
  begin
    FuncName := Copy(ArgBlob, 8, Length(ArgBlob) - 7);
    TabPos := Pos(#9, FuncName);
    if TabPos > 0 then
    begin
      ArgBlob := Copy(FuncName, TabPos + 1, Length(FuncName));
      FuncName := Copy(FuncName, 1, TabPos - 1);
    end
    else
      ArgBlob := '';
  end
  else if ArgBlob <> '' then
  begin
    TabPos := Pos(#9, ArgBlob);
    if TabPos > 0 then
    begin
      ObjName := Copy(ArgBlob, 1, TabPos - 1);
      SlotText := Copy(ArgBlob, TabPos + 1, Length(ArgBlob));
      TabPos := Pos(#9, SlotText);
      if TabPos > 0 then
      begin
        ArgBlob := Copy(SlotText, TabPos + 1, Length(SlotText));
        SlotText := Copy(SlotText, 1, TabPos - 1);
      end
      else
        ArgBlob := '';
      SlotIdx := StrToIntDef(SlotText, -1);
      if (ObjName <> '') and (SlotIdx >= 0) then
      begin
        IsDynamicDispatch := True;
        IsInterfaceDispatch := FindAlloca(ObjName + '$obj') <> 0;
      end
      else
        ArgBlob := ANode.Operand;
    end;
  end;

  ArgCount := 0;
  SetLength(ArgValues, 0);
  SetLength(ArgTypes, 0);
  if ArgBlob <> '' then
  begin
    SetLength(ArgParts, 0);
    ArgPartCount := 0;
    PartBlob := '';
    for I := 1 to Length(ArgBlob) do
    begin
      if ArgBlob[I] = #9 then
      begin
        if PartBlob <> '' then
        begin
          if ArgPartCount >= Length(ArgParts) then
            SetLength(ArgParts, ArgPartCount + 8);
          ArgParts[ArgPartCount] := PartBlob;
          Inc(ArgPartCount);
          PartBlob := '';
        end;
      end
      else
        PartBlob := PartBlob + ArgBlob[I];
    end;
    if PartBlob <> '' then
    begin
      if ArgPartCount >= Length(ArgParts) then
        SetLength(ArgParts, ArgPartCount + 8);
      ArgParts[ArgPartCount] := PartBlob;
      Inc(ArgPartCount);
    end;

    for I := 0 to ArgPartCount - 1 do
    begin
      if Copy(ArgParts[I], 1, 7) = 'strvar ' then
      begin
        PartBlob := Copy(ArgParts[I], 8, Length(ArgParts[I]) - 7);
        if (Length(PartBlob) > 0) and
          (PartBlob[Length(PartBlob)] = #10) then
          PartBlob := Copy(PartBlob, 1, Length(PartBlob) - 1);
        V := FindAlloca(PartBlob + '$ts');
        if V <> 0 then
        begin
          DataPtr := EmitTStringData(V);
          LenVal := EmitTStringLen(V);
          if (DataPtr <> 0) and (LenVal <> 0) then
          begin
            if (ArgCount + 1) >= Length(ArgValues) then
            begin
              SetLength(ArgValues, ArgCount + 8);
              SetLength(ArgTypes, ArgCount + 8);
            end;
            ArgValues[ArgCount] := DataPtr;
            ArgTypes[ArgCount] := GetPtrType;
            Inc(ArgCount);
            ArgValues[ArgCount] := LenVal;
            ArgTypes[ArgCount] := GetIntType;
            Inc(ArgCount);
          end;
        end;
      end
      else if Copy(ArgParts[I], 1, 7) = 'strlit ' then
      begin
        PartBlob := Copy(ArgParts[I], 8, Length(ArgParts[I]) - 7);
        if (Length(PartBlob) > 0) and
          (PartBlob[Length(PartBlob)] = #10) then
          PartBlob := Copy(PartBlob, 1, Length(PartBlob) - 1);
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikIntrinsic;
        Instr.TypeId := GetPtrType;
        Instr.IntrinsicName := 'str_const';
        Instr.CallTarget := PartBlob;
        EmitInstr(Instr);
        DataPtr := Instr.ResultId;
        LenVal := EmitConstIntOfType(Length(PartBlob) - 2, GetIntTypeByWidth(32, True));
        if (DataPtr <> 0) and (LenVal <> 0) then
        begin
          if (ArgCount + 1) >= Length(ArgValues) then
          begin
            SetLength(ArgValues, ArgCount + 8);
            SetLength(ArgTypes, ArgCount + 8);
          end;
          ArgValues[ArgCount] := DataPtr;
          ArgTypes[ArgCount] := GetPtrType;
          Inc(ArgCount);
          ArgValues[ArgCount] := LenVal;
          ArgTypes[ArgCount] := GetIntTypeByWidth(32, True);
          Inc(ArgCount);
        end;
      end
      else
      begin
        V := ParseIntExprArg(ArgParts[I]);
        if V <> 0 then
        begin
          if ArgCount >= Length(ArgValues) then
          begin
            SetLength(ArgValues, ArgCount + 8);
            SetLength(ArgTypes, ArgCount + 8);
          end;
          ArgValues[ArgCount] := V;
          ArgTypes[ArgCount] := GetIntType;
          Inc(ArgCount);
        end;
      end;
    end;
  end;

  if IsDynamicDispatch then
  begin
    ObjSlot := FindAlloca(ObjName);
    if ObjSlot = 0 then
      Exit;
    SelfPtr := EmitLoad(GetPtrType, ObjSlot);
    if SelfPtr = 0 then
      Exit;

    if IsInterfaceDispatch then
    begin
      TablePtr := EmitLoad(GetPtrType, SelfPtr);
      SlotVal := EmitConstIntOfType(SlotIdx, GetIntType);
    end
    else
    begin
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikLoad;
      Instr.TypeId := GetIntType;
      Instr.IntrinsicName := 'const:0';
      EmitInstr(Instr);

      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := GetPtrType;
      Instr.IntrinsicName := 'gep_i64';
      SetLength(Instr.Operands, 2);
      Instr.Operands[0] := MakeTypedOperand(SelfPtr, GetPtrType);
      Instr.Operands[1] := MakeTypedOperand(Instr.ResultId - 1, GetIntType);
      EmitInstr(Instr);
      TablePtr := EmitLoad(GetPtrType, Instr.ResultId);
      SlotVal := EmitConstIntOfType(SlotIdx + 1, GetIntType);
    end;
    if (TablePtr = 0) or (SlotVal = 0) then
      Exit;

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetPtrType;
    Instr.IntrinsicName := 'gep_i64';
    SetLength(Instr.Operands, 2);
    Instr.Operands[0] := MakeTypedOperand(TablePtr, GetPtrType);
    Instr.Operands[1] := MakeTypedOperand(SlotVal, GetIntType);
    EmitInstr(Instr);
    FnPtr := EmitLoad(GetPtrType, Instr.ResultId);
    if FnPtr = 0 then
      Exit;

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
    Instr.IntrinsicName := 'vcall';
    SetLength(Instr.Operands, ArgCount + 3);
    Instr.Operands[0] := MakeTypedOperand(FnPtr, GetPtrType);
    Instr.Operands[1] := MakeTypedOperand(DstPtr, GetPtrType);
    Instr.Operands[2] := MakeTypedOperand(SelfPtr, GetPtrType);
    for I := 0 to ArgCount - 1 do
      Instr.Operands[I + 3] := MakeTypedOperand(ArgValues[I], ArgTypes[I]);
  end
  else
  begin
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikCall;
    Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
    Instr.CallTarget := FuncName;
    SetLength(Instr.Operands, ArgCount + 1);
    Instr.Operands[0] := MakeTypedOperand(DstPtr, GetPtrType);
    for I := 0 to ArgCount - 1 do
      Instr.Operands[I + 1] := MakeTypedOperand(ArgValues[I], ArgTypes[I]);
  end;
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessAssignTStringFieldLoad(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  VarName, IdxStr: string;
  ObjPtr, DstPtr, IdxVal, FieldPtr: THIRValueId;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  VarName := Copy(ANode.Operand, 1, TabPos - 1);
  IdxStr := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));
  DstPtr := FindAlloca(ANode.DisplayName + '$ts');
  if DstPtr = 0 then Exit;
  ObjPtr := FindAlloca(VarName);
  if ObjPtr = 0 then Exit;
  ObjPtr := EmitLoad(GetPtrType, ObjPtr);
  { GEP to field offset }
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:' + IdxStr;
  EmitInstr(Instr);
  IdxVal := Instr.ResultId;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(ObjPtr);
  Instr.Operands[1] := MakeOperand(IdxVal);
  EmitInstr(Instr);
  FieldPtr := Instr.ResultId;
  { tstring_field_assign(dst, field_ptr) }
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.Kind := hikIntrinsic;
  Instr.IntrinsicName := 'tstring_field_assign';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0].ValueId := DstPtr;
  Instr.Operands[0].TypeId := GetPtrType;
  Instr.Operands[1].ValueId := FieldPtr;
  Instr.Operands[1].TypeId := GetPtrType;
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessFieldStoreTString(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  VarName, Rest, IdxStr, SrcSpec, SrcName: string;
  ObjPtr, IdxVal, FieldPtr, SrcPtr, TsTmp, LenConst: THIRValueId;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  VarName := Copy(ANode.Operand, 1, TabPos - 1);
  Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));
  TabPos := Pos(#9, Rest);
  if TabPos = 0 then Exit;
  IdxStr := Copy(Rest, 1, TabPos - 1);
  SrcSpec := Copy(Rest, TabPos + 1, Length(Rest));

  ObjPtr := FindAlloca(VarName);
  if ObjPtr = 0 then Exit;
  ObjPtr := EmitLoad(GetPtrType, ObjPtr);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:' + IdxStr;
  EmitInstr(Instr);
  IdxVal := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(ObjPtr);
  Instr.Operands[1] := MakeOperand(IdxVal);
  EmitInstr(Instr);
  FieldPtr := Instr.ResultId;

  { Resolve source: 'lit ...' → from_literal, 'var ...' → tstring_assign, raw name → tstring_assign }
  if (Length(SrcSpec) > 4) and (Copy(SrcSpec, 1, 4) = 'lit ') then
  begin
    { Literal source: tstring_from_literal(field_ptr, lit_data, lit_len) }
    SrcName := Copy(SrcSpec, 5, Length(SrcSpec));
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetPtrType;
    Instr.IntrinsicName := 'str_const';
    Instr.CallTarget := SrcName;
    EmitInstr(Instr);
    SrcPtr := Instr.ResultId;
    { Create TString from literal into a temp, then field_assign }
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikAlloca;
    Instr.TypeId := GetIntType;
    Instr.IntrinsicName := 'tstring';
    EmitInstr(Instr);
    TsTmp := Instr.ResultId;
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.Kind := hikIntrinsic;
    Instr.IntrinsicName := 'tstring_init';
    SetLength(Instr.Operands, 1);
    Instr.Operands[0].ValueId := TsTmp;
    Instr.Operands[0].TypeId := GetPtrType;
    EmitInstr(Instr);
    { literal length constant }
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikLoad;
    Instr.TypeId := GetIntTypeByWidth(32, True);
    Instr.IntrinsicName := 'const:' + IntToStr(Length(SrcName));
    EmitInstr(Instr);
    LenConst := Instr.ResultId;
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.Kind := hikIntrinsic;
    Instr.IntrinsicName := 'tstring_from_literal';
    SetLength(Instr.Operands, 3);
    Instr.Operands[0].ValueId := TsTmp;
    Instr.Operands[0].TypeId := GetPtrType;
    Instr.Operands[1].ValueId := SrcPtr;
    Instr.Operands[1].TypeId := GetPtrType;
    Instr.Operands[2].ValueId := LenConst;
    Instr.Operands[2].TypeId := GetIntTypeByWidth(32, True);
    EmitInstr(Instr);
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.Kind := hikIntrinsic;
    Instr.IntrinsicName := 'tstring_field_assign';
    SetLength(Instr.Operands, 2);
    Instr.Operands[0].ValueId := FieldPtr;
    Instr.Operands[0].TypeId := GetPtrType;
    Instr.Operands[1].ValueId := TsTmp;
    Instr.Operands[1].TypeId := GetPtrType;
    EmitInstr(Instr);
  end
  else if (Length(SrcSpec) > 4) and (Copy(SrcSpec, 1, 4) = 'var ') then
  begin
    SrcName := Copy(SrcSpec, 5, Length(SrcSpec));
    SrcPtr := FindAlloca(SrcName + '$ts');
    if SrcPtr <> 0 then
    begin
      { tstring_field_assign(field_ptr, src_ts) }
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.Kind := hikIntrinsic;
      Instr.IntrinsicName := 'tstring_field_assign';
      SetLength(Instr.Operands, 2);
      Instr.Operands[0].ValueId := FieldPtr;
      Instr.Operands[0].TypeId := GetPtrType;
      Instr.Operands[1].ValueId := SrcPtr;
      Instr.Operands[1].TypeId := GetPtrType;
      EmitInstr(Instr);
    end;
  end
  else
  begin
    { Raw variable name }
    SrcPtr := FindAlloca(SrcSpec + '$ts');
    if SrcPtr <> 0 then
    begin
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.Kind := hikIntrinsic;
      Instr.IntrinsicName := 'tstring_field_assign';
      SetLength(Instr.Operands, 2);
      Instr.Operands[0].ValueId := FieldPtr;
      Instr.Operands[0].TypeId := GetPtrType;
      Instr.Operands[1].ValueId := SrcPtr;
      Instr.Operands[1].TypeId := GetPtrType;
      EmitInstr(Instr);
    end;
  end;
end;

procedure THIRBuilder.ProcessRetTString(const ANode: TTypedHirNode);
var
  SrcName: string;
  SrcPtr: THIRValueId;
  Instr: THIRInstr;
  Term: THIRTerminator;
begin
  { Flush cleanup before return }
  if FPendingCleanupCount > 0 then
    FlushPendingCleanupNodes;
  { Find source TString variable }
  SrcName := ANode.Operand;
  SrcPtr := FindAlloca(SrcName + '$ts');
  if SrcPtr = 0 then Exit;
  { tstring_ret_move(agg.result, src) }
  if FSretValueId <> 0 then
  begin
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.Kind := hikIntrinsic;
    Instr.IntrinsicName := 'tstring_ret_move';
    SetLength(Instr.Operands, 2);
    Instr.Operands[0].ValueId := FSretValueId;
    Instr.Operands[0].TypeId := GetPtrType;
    Instr.Operands[1].ValueId := SrcPtr;
    Instr.Operands[1].TypeId := GetPtrType;
    EmitInstr(Instr);
  end;
  { Emit return void (sret function) }
  FillChar(Term, SizeOf(Term), 0);
  Term.Kind := htkReturn;
  FModule.SetTerminator(FCurrentFuncId, FCurrentBlockId, Term);
  FBlockTerminated := True;
end;

end.
