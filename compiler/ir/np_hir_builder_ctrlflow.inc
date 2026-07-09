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
