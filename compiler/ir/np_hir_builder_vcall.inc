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
    { Typed interface_release: SystemContractKind authority. }
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
    AssignSystemContract(Instr, sckInterfaceRelease);
    Instr.CallTarget := SystemContractAt(sckInterfaceRelease).RuntimeMapping;
    SetLength(Instr.Operands, 1);
    Instr.Operands[0] := MakeTypedOperand(OldObjPtr, GetPtrType);
    EmitInstr(Instr);
  end;

  { Typed interface_addref: SystemContractKind authority. }
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  AssignSystemContract(Instr, sckInterfaceAddRef);
  Instr.CallTarget := SystemContractAt(sckInterfaceAddRef).RuntimeMapping;
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(ObjPtr, GetPtrType);
  EmitInstr(Instr);
  Found := False;
  if FIntfVarNames.Count > 0 then
    for I := 0 to LongInt(FIntfVarNames.Count) - 1 do
      if SameText(FIntfVarNames[I], VarName) then
      begin
        Found := True;
        Break;
      end;
  if not Found then
    FIntfVarNames.Push(VarName);
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
  { Typed interface_release: SystemContractKind authority. }
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  AssignSystemContract(Instr, sckInterfaceRelease);
  Instr.CallTarget := SystemContractAt(sckInterfaceRelease).RuntimeMapping;
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
  RetType: THIRTypeId;
  SlotIdx, SpacePos, ExtraArgCount, VcallI: LongInt;
begin
  { Same ' p' ret-ptr flag as EmitExprVcall — interface methods returning
    ILockGuard/objects must be call ptr, not call i64 (Guard$f store mismatch). }
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
  Instr.TypeId := RetType;
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
  if RetType = GetPtrType then
    S.PushTyped(Instr.ResultId, GetPtrType)
  else
    S.Push(Instr.ResultId);
end;
