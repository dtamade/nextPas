procedure THIRBuilder.ProcessWriteInt(const ANode: TTypedHirNode);
var
  V: THIRValueId;
  ValueType: THIRTypeId;
  Instr: THIRInstr;
  Fd: Int64;
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
    { Batch 29: DisplayName WriteErr → fd 2 (ErrOutput/StdErr). }
    if SameText(ANode.DisplayName, 'WriteErr') then
      Fd := 2
    else
      Fd := 1;
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
    Instr.IntrinsicName := 'write_int';
    SetLength(Instr.Operands, 2);
    Instr.Operands[0] := MakeTypedOperand(V, GetIntType);
    Instr.Operands[1] := MakeTypedOperand(EmitConstInt(Fd), GetIntType);
    EmitInstr(Instr);
  end;
end;

procedure THIRBuilder.ProcessWriteStr(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
  Fd: Int64;
begin
  { Batch 27: DisplayName WriteErr → fd 2 (ErrOutput/StdErr). }
  if SameText(ANode.DisplayName, 'WriteErr') then
    Fd := 2
  else
    Fd := 1;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'write_str';
  Instr.CallTarget := ANode.Operand;
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(EmitConstInt(Fd), GetIntType);
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
  Fd: Int64;
begin
  TsSlot := FindAlloca(ANode.Operand + '$ts');
  if TsSlot = 0 then
    Exit;

  DataPtr := EmitTStringData(TsSlot);
  LenVal := EmitTStringLen(TsSlot);
  if (DataPtr = 0) or (LenVal = 0) then
    Exit;

  { Batch 27: DisplayName WriteErr → fd 2 (ErrOutput/StdErr). }
  if SameText(ANode.DisplayName, 'WriteErr') then
    Fd := 2
  else
    Fd := 1;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'write_str_var';
  SetLength(Instr.Operands, 3);
  Instr.Operands[0] := MakeTypedOperand(DataPtr, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(LenVal, GetIntTypeByWidth(32, True));
  Instr.Operands[2] := MakeTypedOperand(EmitConstInt(Fd), GetIntType);
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
  { np_tstring_copy ABI is i64 start/count. }
  Instr.Operands[2] := MakeTypedOperand(StartVal, GetIntTypeByWidth(64, True));
  Instr.Operands[3] := MakeTypedOperand(LenVal, GetIntTypeByWidth(64, True));
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessStringTempOwnedRuntime(
  const ANode: TTypedHirNode);
begin
  { Same operand shape as assign-tstring-call-runtime:
      TempName #9 'callee ' FuncName #9 arg0 #9 arg1 ...
    Earlier path only passed the sret slot (no formals), so
    Length(GetS(R)) dropped the const record arg and broke sret ABI. }
  ProcessAssignTStringCall(ANode);
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
    { np_tstring_len is i64; keep $len as i64 so store/load match without
      requiring tip-only store.cast ValueLlvmType machinery. }
    LenSlot := EmitTStringLen(TsSlot);
    EnsureAlloca(TempName + '$len', GetIntTypeByWidth(64, True));
    EmitStore(GetIntTypeByWidth(64, True), LenSlot, FindAlloca(TempName + '$len'));
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
