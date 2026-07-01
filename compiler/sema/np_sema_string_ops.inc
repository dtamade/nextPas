procedure TSemanticAnalyzer.RegisterRuntimeVar(const AName: string);
var
  Idx: LongInt;
  NextIndex: SizeInt;
begin
  for Idx := 0 to Length(FRuntimeVarNames) - 1 do
    if SameText(FRuntimeVarNames[Idx], AName) then
      Exit;
  NextIndex := Length(FRuntimeVarNames);
  SetLength(FRuntimeVarNames, NextIndex + 1);
  FRuntimeVarNames[NextIndex] := AName;
end;

function TSemanticAnalyzer.IsRuntimeVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FRuntimeVarNames) - 1 do
    if SameText(FRuntimeVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

procedure TSemanticAnalyzer.RegisterRuntimeStrVar(const AName: string);
var
  Idx: LongInt;
  NextIndex: SizeInt;
begin
  for Idx := 0 to Length(FRuntimeStrVarNames) - 1 do
    if SameText(FRuntimeStrVarNames[Idx], AName) then
      Exit;
  NextIndex := Length(FRuntimeStrVarNames);
  SetLength(FRuntimeStrVarNames, NextIndex + 1);
  FRuntimeStrVarNames[NextIndex] := AName;
end;

procedure TSemanticAnalyzer.RegisterOwnedRuntimeStrVar(const AName: string);
var
  Idx: LongInt;
  NextIndex: SizeInt;
begin
  if AName = '' then
    Exit;
  for Idx := 0 to Length(FOwnedRuntimeStrVarNames) - 1 do
    if SameText(FOwnedRuntimeStrVarNames[Idx], AName) then
      Exit;
  NextIndex := Length(FOwnedRuntimeStrVarNames);
  SetLength(FOwnedRuntimeStrVarNames, NextIndex + 1);
  FOwnedRuntimeStrVarNames[NextIndex] := AName;
end;

procedure TSemanticAnalyzer.RegisterBorrowedRuntimeStrVar(const AName: string);
var
  Idx: LongInt;
  NextIndex: SizeInt;
begin
  if AName = '' then
    Exit;
  for Idx := 0 to Length(FBorrowedRuntimeStrVarNames) - 1 do
    if SameText(FBorrowedRuntimeStrVarNames[Idx], AName) then
      Exit;
  NextIndex := Length(FBorrowedRuntimeStrVarNames);
  SetLength(FBorrowedRuntimeStrVarNames, NextIndex + 1);
  FBorrowedRuntimeStrVarNames[NextIndex] := AName;
end;

procedure TSemanticAnalyzer.RegisterOwnedStringReturnFunc(const AName: string);
var
  Idx: LongInt;
  NextIndex: SizeInt;
begin
  if AName = '' then
    Exit;
  for Idx := 0 to Length(FOwnedStringReturnFuncNames) - 1 do
    if SameText(FOwnedStringReturnFuncNames[Idx], AName) then
      Exit;
  NextIndex := Length(FOwnedStringReturnFuncNames);
  SetLength(FOwnedStringReturnFuncNames, NextIndex + 1);
  FOwnedStringReturnFuncNames[NextIndex] := AName;
end;

function TSemanticAnalyzer.IsRuntimeStrVar(const AName: string): Boolean;
var
  Idx: LongInt;
  SymId: LongInt;
  TypeId: LongInt;
  TypeName: string;
begin
  for Idx := 0 to Length(FRuntimeStrVarNames) - 1 do
    if SameText(FRuntimeStrVarNames[Idx], AName) then
      Exit(True);
  { Also accept any string-typed variable — they hold safe string values }
  SymId := FModel.FindSymbolByName(AName);
  if SymId > 0 then
  begin
    TypeId := FModel.SymbolAt(SymId - 1).TypeId;
    if TypeId > 0 then
    begin
      TypeName := FModel.TypeAt(TypeId - 1).Name;
      if SameText(TypeName, 'String') or SameText(TypeName, 'AnsiString') then
        Exit(True);
    end;
  end;
  Result := False;
end;

function TSemanticAnalyzer.IsOwnedRuntimeStrVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FOwnedRuntimeStrVarNames) - 1 do
    if SameText(FOwnedRuntimeStrVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

function TSemanticAnalyzer.IsBorrowedRuntimeStrVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FBorrowedRuntimeStrVarNames) - 1 do
    if SameText(FBorrowedRuntimeStrVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

function TSemanticAnalyzer.IsOwnedStringReturnFunc(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FOwnedStringReturnFuncNames) - 1 do
    if SameText(FOwnedStringReturnFuncNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

procedure TSemanticAnalyzer.ClearPendingStringTempReleases;
begin
  SetLength(FPendingStringTempNames, 0);
  SetLength(FPendingStringTempSources, 0);
end;

procedure TSemanticAnalyzer.QueuePendingStringTempRelease(
  const ATempName, ASourceName: string);
var
  NextIndex: SizeInt;
begin
  if (ATempName = '') or (ASourceName = '') then
    Exit;
  NextIndex := Length(FPendingStringTempNames);
  SetLength(FPendingStringTempNames, NextIndex + 1);
  SetLength(FPendingStringTempSources, NextIndex + 1);
  FPendingStringTempNames[NextIndex] := ATempName;
  FPendingStringTempSources[NextIndex] := ASourceName;
end;

procedure TSemanticAnalyzer.EmitPendingStringTempReleases;
var
  I: LongInt;
begin
  for I := High(FPendingStringTempNames) downto 0 do
    FModel.AddTypedHirNode('string-temp-release-runtime',
      FPendingStringTempSources[I], 0, 0, FPendingStringTempNames[I]);
  ClearPendingStringTempReleases;
end;

procedure TSemanticAnalyzer.RegisterConcatOwnedStringReturnConsumers(
  const AConcatNode: TGreenNode; var AChanged: Boolean);
var
  I: LongInt;
  FuncName: string;
begin
  if (AConcatNode = nil) or (AConcatNode.NodeKind <> gnkBinaryExpression) or
    (AConcatNode.Text <> '+') then
    Exit;
  for I := 0 to AConcatNode.ChildCount - 1 do
  begin
    if ConcatOperandOwnsStringReturn(AConcatNode.ChildAt(I), FuncName) and
      (not IsOwnedStringReturnFunc(FuncName)) then
    begin
      RegisterOwnedStringReturnFunc(FuncName);
      AChanged := True;
    end;
    RegisterConcatOwnedStringReturnConsumers(AConcatNode.ChildAt(I), AChanged);
  end;
end;

function TSemanticAnalyzer.IsRootOwnedStringReturnCandidate(
  const AEntry: TProcedureBodyEntry; const AIsStrReturn: Boolean): Boolean;
begin
  Result := AIsStrReturn and (AEntry.Body <> nil) and
    (AEntry.Decl <> nil) and (AEntry.Decl.NodeKind = gnkFunctionDecl) and
    (Pos('.', AEntry.Name) = 0) and
    SameText(AEntry.OwnerUnitId, NormalizeUnitIdentity(FUnitGraph.RootName));
end;

function TSemanticAnalyzer.DeclReturnsString(const ADecl: TGreenNode): Boolean;
var
  I: LongInt;
  Child: TGreenNode;
begin
  Result := False;
  if ADecl = nil then
    Exit;
  for I := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(I);
    if (Child <> nil) and (Child.NodeKind = gnkIdentifier) and
      (SameText(Child.Text, 'String') or SameText(Child.Text, 'AnsiString')) then
      Exit(True);
  end;
end;

function TSemanticAnalyzer.DeclaresStringLocal(const ADecl: TGreenNode;
  const AName: string): Boolean;
var
  I, J: LongInt;
  Child, Decl, TypeChild: TGreenNode;
begin
  Result := False;
  if (ADecl = nil) or (AName = '') then
    Exit;
  for I := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(I);
    if (Child = nil) or (Child.NodeKind <> gnkVarSection) then
      Continue;
    for J := 0 to Child.ChildCount - 1 do
    begin
      Decl := Child.ChildAt(J);
      if (Decl = nil) or (Decl.NodeKind <> gnkVarDecl) or
        (not SameText(Decl.Text, AName)) or (Decl.ChildCount = 0) then
        Continue;
      TypeChild := Decl.ChildAt(0);
      if (TypeChild <> nil) and
        (SameText(TypeChild.Text, 'String') or
         SameText(TypeChild.Text, 'AnsiString')) then
        Exit(True);
    end;
  end;
end;

function TSemanticAnalyzer.StringReturnFunctionNameFromNode(
  const ANode: TGreenNode; out AName: string): Boolean;
var
  BodyNode, DeclNode: TGreenNode;
  SymbolId, TypeId: LongInt;
  TypeName: string;
begin
  AName := '';
  Result := False;
  if ANode = nil then
    Exit;
  if ANode.NodeKind = gnkIdentifier then
    AName := ANode.Text
  else if (ANode.NodeKind = gnkFunctionCall) then
    AName := ANode.Text;
  if AName = '' then
    Exit;
  if LookupProcedureBody(AName, BodyNode, DeclNode) and
    DeclReturnsString(DeclNode) then
    Exit(True);
  { Fallback: check semantic model for imported functions }
  SymbolId := FModel.LookupSymbol(AName, FCurrentScopeId);
  if SymbolId <= 0 then
    SymbolId := FModel.FindSymbolByName(AName);
  if SymbolId <= 0 then
    Exit;
  { Only accept actual function/procedure symbols — not parameters,
    variables, constants, or fields. }
  if not SameText(FModel.SymbolAt(SymbolId - 1).Kind, 'function') and
    not SameText(FModel.SymbolAt(SymbolId - 1).Kind, 'procedure') then
    Exit;
  TypeId := FModel.SymbolTypeId(SymbolId);
  if (TypeId > 0) and (TypeId <= FModel.TypeCount) then
  begin
    TypeName := FModel.TypeAt(TypeId - 1).Name;
    Result := SameText(TypeName, 'String') or SameText(TypeName, 'AnsiString') or
      SameText(TypeName, 'ShortString') or SameText(TypeName, 'WideString') or
      SameText(TypeName, 'UnicodeString');
  end;
end;

function TSemanticAnalyzer.FunctionCallReturnsString(
  const ANode: TGreenNode): Boolean;
var
  BodyNode, DeclNode: TGreenNode;
  SymbolId, TypeId: LongInt;
  TypeName: string;
begin
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.Text = '') then
    Exit;
  if LookupProcedureBody(ANode.Text, BodyNode, DeclNode) then
    Exit(DeclReturnsString(DeclNode));
  SymbolId := FModel.LookupSymbol(ANode.Text, FCurrentScopeId);
  if SymbolId <= 0 then
    SymbolId := FModel.FindSymbolByName(ANode.Text);
  if SymbolId <= 0 then
    Exit;
  { Only accept actual function/procedure symbols }
  if not SameText(FModel.SymbolAt(SymbolId - 1).Kind, 'function') and
    not SameText(FModel.SymbolAt(SymbolId - 1).Kind, 'procedure') then
    Exit;
  TypeId := FModel.SymbolTypeId(SymbolId);
  if (TypeId <= 0) or (TypeId > FModel.TypeCount) then
    Exit;
  TypeName := FModel.TypeAt(TypeId - 1).Name;
  Result := SameText(TypeName, 'String') or SameText(TypeName, 'AnsiString');
end;

function TSemanticAnalyzer.MemberCallReturnsString(
  const ANode: TGreenNode): Boolean;
var
  CalleeNode, ReceiverNode, MemberNode: TGreenNode;
  ReceiverTypeName: string;
  ReceiverSymbolId, ReceiverTypeId: LongInt;
begin
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.ChildCount <> 1) then
    Exit;
  CalleeNode := ANode.ChildAt(0);
  if (CalleeNode = nil) or (CalleeNode.NodeKind <> gnkDotAccess) or
    (CalleeNode.ChildCount < 2) then
    Exit;
  ReceiverNode := CalleeNode.ChildAt(0);
  MemberNode := CalleeNode.ChildAt(1);
  if (ReceiverNode = nil) or (MemberNode = nil) or
    (ReceiverNode.NodeKind <> gnkIdentifier) or
    (MemberNode.NodeKind <> gnkIdentifier) then
    Exit;
  if SameText(ReceiverNode.Text, 'Self') and (FCurrentMethodClass <> '') then
    ReceiverTypeName := FCurrentMethodClass
  else
    ReceiverTypeName := LookupClassVar(ReceiverNode.Text);
  if ReceiverTypeName = '' then
  begin
    ReceiverSymbolId := FModel.FindSymbolByName(ReceiverNode.Text);
    if ReceiverSymbolId > 0 then
    begin
      ReceiverTypeId := FModel.SymbolTypeId(ReceiverSymbolId);
      if (ReceiverTypeId > 0) and (ReceiverTypeId <= FModel.TypeCount) then
        ReceiverTypeName := FModel.TypeAt(ReceiverTypeId - 1).Name;
    end;
  end;
  Result := (ReceiverTypeName <> '') and
    TypeMetaRetStr(ReceiverTypeName, MemberNode.Text);
end;

function TSemanticAnalyzer.TypeIdIsManagedString(
  const ATypeId: LongInt): Boolean;
var
  TypeName: string;
begin
  Result := False;
  if (ATypeId <= 0) or (ATypeId > FModel.TypeCount) then
    Exit;
  TypeName := FModel.TypeAt(ATypeId - 1).Name;
  Result := SameText(TypeName, 'String') or SameText(TypeName, 'AnsiString');
end;

function TSemanticAnalyzer.IsSupportedOwnedStringReturnIdentifierTarget(
  const ATargetNode: TGreenNode): Boolean;
var
  LookupName, RetName: string;
  Symbol: TSemanticSymbol;
  SymbolId: LongInt;
begin
  Result := False;
  if (ATargetNode = nil) or (ATargetNode.NodeKind <> gnkIdentifier) then
    Exit;

  LookupName := ATargetNode.Text;
  if LookupName = '' then
    Exit;
  if SameText(LookupName, 'Result') and (FCurrentRetVarName <> '') then
    LookupName := FCurrentRetVarName;

  SymbolId := FModel.LookupSymbol(LookupName, FCurrentScopeId);
  if SymbolId <= 0 then
    SymbolId := FModel.FindSymbolByName(LookupName);
  if SymbolId <= 0 then
    Exit;

  Symbol := FModel.SymbolAt(SymbolId - 1);
  if SameText(Symbol.Kind, 'variable') then
    Exit(TypeIdIsManagedString(Symbol.TypeId));

  RetName := FCurrentRetVarName;
  Result := SameText(Symbol.Kind, 'function') and (RetName <> '') and
    SameText(LookupName, RetName) and TypeIdIsManagedString(Symbol.TypeId);
end;

function TSemanticAnalyzer.IsSupportedOwnedStringReturnStoreTarget(
  const ATargetNode: TGreenNode): Boolean;
var
  BaseNode, FieldNode: TGreenNode;
  BaseName, ClassTypeName: string;
  BaseSymbolId, BaseTypeId: LongInt;
  FieldMeta: TFieldMeta;
begin
  Result := False;
  if (ATargetNode = nil) or (ATargetNode.NodeKind <> gnkDotAccess) or
    (ATargetNode.ChildCount < 2) then
    Exit;

  BaseNode := ATargetNode.ChildAt(0);
  FieldNode := ATargetNode.ChildAt(1);
  if (BaseNode = nil) or (FieldNode = nil) or
    (BaseNode.NodeKind <> gnkIdentifier) or
    (FieldNode.NodeKind <> gnkIdentifier) then
    Exit;

  BaseName := BaseNode.Text;
  if BaseName = '' then
    Exit;
  if SameText(BaseName, 'Self') then
  begin
    if FCurrentMethodClass = '' then
      Exit;
    BaseTypeId := FModel.FindTypeByName(FCurrentMethodClass);
  end
  else
  begin
    BaseSymbolId := FModel.LookupSymbol(BaseName, FCurrentScopeId);
    if BaseSymbolId <= 0 then
      BaseSymbolId := FModel.FindSymbolByName(BaseName);
    if BaseSymbolId <= 0 then
      Exit;
    BaseTypeId := FModel.SymbolTypeId(BaseSymbolId);
  end;
  if (BaseTypeId <= 0) or (BaseTypeId > FModel.TypeCount) then
    Exit;

  ClassTypeName := FModel.TypeAt(BaseTypeId - 1).Name;
  if ClassTypeName = '' then
    Exit;
  { Accept both class and record field assignments as safe targets for
    owned string returns. If type metadata is not fully resolved (e.g.
    imported record types), trust the assignment as safe. }
  if TypeMetaIsClass(ClassTypeName) or TypeMetaIsRecord(ClassTypeName) then
  begin
    if FModel.GetFieldMetaByName(BaseTypeId, FieldNode.Text, FieldMeta) then
      Exit(FieldMeta.IsString and TypeIdIsManagedString(FieldMeta.TypeId));
  end;
  { Type exists but metadata not fully resolved — accept as safe.
    This handles imported record types whose field metadata is not yet
    populated during C6-H4 pre-registration.
    TODO: tighten once type metadata is fully populated for all imported
    types during the pre-registration phase. Currently this fallback is
    necessary because imported record field metadata may be incomplete. }
  Result := True;
end;

function TSemanticAnalyzer.IsSupportedOwnedStringReturnConsumerTarget(
  const ATargetNode: TGreenNode): Boolean;
begin
  { Accept any valid assignment target as a safe consumer for owned string
    returns. The key invariant: if the node appears on the left side of an
    assignment, the owned string temporary is transferred to the target,
    which is always safe. }
  Result := (ATargetNode <> nil) and
    (ATargetNode.NodeKind in [gnkIdentifier, gnkDotAccess,
      gnkArrayAccess]);
end;

function TSemanticAnalyzer.AssignmentOwnsStringReturn(const ANode: TGreenNode;
  const AEntry: TProcedureBodyEntry): Boolean;
var
  DestNode, SourceNode: TGreenNode;
  FuncName: string;
begin
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkAssignmentStatement) or
    (ANode.ChildCount < 2) then
    Exit;
  DestNode := ANode.ChildAt(0);
  SourceNode := ANode.ChildAt(1);
  if (DestNode = nil) or
    (not StringReturnFunctionNameFromNode(SourceNode, FuncName)) then
    Exit;
  if HasOverload(FuncName) then
    Exit;
  if IsSupportedOwnedStringReturnStoreTarget(DestNode) then
    Exit(True);
  // Accept local variable assignments in any function context.
  // This is needed for functions like SameText(Boolean) that use
  // LowerCase internally — without this, LowerCase is never registered
  // as an owned string return function, causing C6-H4 false positives
  // when SysUtils is loaded.
  if IsSupportedOwnedStringReturnIdentifierTarget(DestNode) then
    Exit(True);
  if not IsRootOwnedStringReturnCandidate(AEntry, DeclReturnsString(AEntry.Decl)) then
    Exit;
  Result := False;
end;

function TSemanticAnalyzer.AssignmentOwnsTopLevelStringReturn(
  const ANode: TGreenNode): Boolean;
var
  DestNode, SourceNode: TGreenNode;
  FuncName: string;
begin
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkAssignmentStatement) or
    (ANode.ChildCount < 2) then
    Exit;
  DestNode := ANode.ChildAt(0);
  SourceNode := ANode.ChildAt(1);
  if (DestNode = nil) or
    (not StringReturnFunctionNameFromNode(SourceNode, FuncName)) then
    Exit;
  if HasOverload(FuncName) then
    Exit;
  Result := IsSupportedOwnedStringReturnConsumerTarget(DestNode);
end;

function TSemanticAnalyzer.CallArgumentOwnsStringReturn(
  const ACallNode, AArgNode: TGreenNode; AArgPosition: LongInt;
  out AFuncName: string): Boolean;
var
  BodyNode, DeclNode, FuncNode: TGreenNode;
begin
  AFuncName := '';
  Result := False;
  if (ACallNode = nil) or (AArgNode = nil) or
    (ACallNode.NodeKind <> gnkFunctionCall) or
    (AArgNode.NodeKind <> gnkFunctionCall) then
    Exit;
  if (ACallNode.Text = '') or HasOverload(ACallNode.Text) then
    Exit;
  if not LookupProcedureBody(ACallNode.Text, BodyNode, DeclNode) then
    Exit;
  if IsVarParamAtPosition(DeclNode, AArgPosition) then
    Exit;
  if not StringReturnFunctionNameFromNode(AArgNode, AFuncName) then
    Exit;
  if HasOverload(AFuncName) then
    Exit;
  FuncNode := nil;
  if AArgNode.ChildCount > 0 then
    FuncNode := AArgNode.ChildAt(0);
  Result := (FuncNode <> nil) and (FuncNode.NodeKind = gnkIdentifier) and
    SameText(FuncNode.Text, AFuncName);
end;

function TSemanticAnalyzer.DirectOwnedStringReturnAssignmentNode(
  const ANode: TGreenNode): Boolean;
var
  DestNode: TGreenNode;
  SourceName: string;
begin
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkAssignmentStatement) or
    (ANode.ChildCount < 2) then
    Exit;
  DestNode := ANode.ChildAt(0);
  if not StringReturnFunctionNameFromNode(ANode.ChildAt(1), SourceName) then
    Exit;
  Result := (DestNode <> nil) and IsOwnedStringReturnFunc(SourceName) and
    IsSupportedOwnedStringReturnConsumerTarget(DestNode);
end;

function TSemanticAnalyzer.IsSupportedOwnedStringReturnArgument(
  const ACallNode, AArgNode: TGreenNode; AArgPosition: LongInt): Boolean;
var
  SourceName: string;
begin
  Result := CallArgumentOwnsStringReturn(
    ACallNode, AArgNode, AArgPosition, SourceName) and
    IsOwnedStringReturnFunc(SourceName);
end;

function TSemanticAnalyzer.LengthArgumentOwnsStringReturn(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  CalleeNode, ArgNode: TGreenNode;
begin
  AFuncName := '';
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.ChildCount < 2) then
    Exit;
  CalleeNode := ANode.ChildAt(0);
  ArgNode := ANode.ChildAt(1);
  if (CalleeNode = nil) or (ArgNode = nil) or
    (CalleeNode.NodeKind <> gnkIdentifier) or
    (not SameText(CalleeNode.Text, 'Length')) then
    Exit;
  if (ArgNode.NodeKind <> gnkFunctionCall) or
    (ArgNode.ChildCount < 1) or (ArgNode.ChildAt(0) = nil) or
    (ArgNode.ChildAt(0).NodeKind <> gnkIdentifier) then
    Exit;
  if not StringReturnFunctionNameFromNode(ArgNode, AFuncName) then
    Exit;
  Result := not HasOverload(AFuncName);
end;

function TSemanticAnalyzer.IsSupportedOwnedStringReturnLengthArgument(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
begin
  Result := LengthArgumentOwnsStringReturn(ANode, AFuncName) and
    IsOwnedStringReturnFunc(AFuncName);
end;

function TSemanticAnalyzer.EmitOwnedStringLengthTemp(const ANode: TGreenNode;
  out ABlob: string): Boolean;
var
  SourceName, TempName: string;
begin
  ABlob := '';
  Result := False;
  if not IsSupportedOwnedStringReturnLengthArgument(ANode, SourceName) then
    Exit;
  Inc(FBlockLabelCounter);
  TempName := '$str_len_tmp_' + IntToStr(FBlockLabelCounter);
  RegisterRuntimeVar(TempName);
  RegisterRuntimeStrVar(TempName);
  FModel.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0,
    TempName);
  FModel.AddTypedHirNode('string-temp-owned-runtime', SourceName, 0, 0,
    TempName + #9 + 'callee ' + SourceName + #9 +
    'ptr len owner alloc_size');
  FModel.AddTypedHirNode('string-temp-length-runtime', SourceName, 0, 0,
    'strvar ' + TempName + #10);
  FModel.AddTypedHirNode('string-temp-release-runtime', SourceName, 0, 0,
    TempName);
  ABlob := 'var ' + TempName + '$len' + #10;
  Result := True;
end;

function TSemanticAnalyzer.EmitOwnedStringConcatLengthTemp(
  const ANode: TGreenNode; out ABlob: string): Boolean;
var
  ConcatNode: TGreenNode;
  LeftName, RightName, TempName: string;
begin
  ABlob := '';
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.ChildCount < 2) or (ANode.ChildAt(0) = nil) or
    (not SameText(ANode.ChildAt(0).Text, 'Length')) then
    Exit;
  ConcatNode := ANode.ChildAt(1);
  if (ConcatNode = nil) or (ConcatNode.NodeKind <> gnkBinaryExpression) or
    (ConcatNode.Text <> '+') or (ConcatNode.ChildCount < 2) or
    (not ConcatTreeHasSupportedOwnedStringReturn(ConcatNode)) or
    (not CanEmitStrConcatOperand(ConcatNode)) then
    Exit;
  LeftName := EmitStrConcatOperand(ConcatNode.ChildAt(0), '');
  RightName := EmitStrConcatOperand(ConcatNode.ChildAt(1), '');
  if (LeftName = '') or (RightName = '') then
    Exit;
  Inc(FBlockLabelCounter);
  TempName := '$str_len_cat_tmp_' + IntToStr(FBlockLabelCounter);
  RegisterRuntimeVar(TempName);
  RegisterRuntimeStrVar(TempName);
  FModel.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0,
    TempName);
  FModel.AddTypedHirNode('assign-tstring-concat-runtime', TempName, 0, 0,
    LeftName + #9 + RightName);
  FModel.AddTypedHirNode('string-temp-length-runtime', TempName, 0, 0,
    'strvar ' + TempName + #10);
  QueuePendingStringTempRelease(TempName, TempName);
  EmitPendingStringTempReleases;
  ABlob := 'var ' + TempName + '$len' + #10;
  Result := True;
end;

function TSemanticAnalyzer.CopyArgumentOwnsStringReturn(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  CalleeNode, ArgNode, FuncNode: TGreenNode;
begin
  AFuncName := '';
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.ChildCount < 4) then
    Exit;
  CalleeNode := ANode.ChildAt(0);
  ArgNode := ANode.ChildAt(1);
  if (CalleeNode = nil) or (ArgNode = nil) or
    (CalleeNode.NodeKind <> gnkIdentifier) or
    (not SameText(CalleeNode.Text, 'Copy')) then
    Exit;
  if (ArgNode.NodeKind <> gnkFunctionCall) or
    (ArgNode.ChildCount < 1) then
    Exit;
  FuncNode := ArgNode.ChildAt(0);
  if (FuncNode = nil) or (FuncNode.NodeKind <> gnkIdentifier) then
    Exit;
  if not StringReturnFunctionNameFromNode(ArgNode, AFuncName) then
    Exit;
  Result := SameText(FuncNode.Text, AFuncName) and
    (not HasOverload(AFuncName));
end;

function TSemanticAnalyzer.IsSupportedOwnedStringReturnCopyArgument(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
begin
  Result := CopyArgumentOwnsStringReturn(ANode, AFuncName) and
    IsOwnedStringReturnFunc(AFuncName);
end;

function TSemanticAnalyzer.EmitOwnedStringCopyTemp(const ACopyNode: TGreenNode;
  const ADestName: string; out ATempName: string): Boolean;
var
  SourceName, StartBlob, LenBlob: string;
begin
  ATempName := '';
  Result := False;
  if (ADestName = '') or
    (not IsSupportedOwnedStringReturnCopyArgument(ACopyNode, SourceName)) then
    Exit;
  if (not EncodeRuntimeIntExprFold(ACopyNode.ChildAt(2), StartBlob)) or
    (not EncodeRuntimeIntExprFold(ACopyNode.ChildAt(3), LenBlob)) then
    Exit;
  Inc(FBlockLabelCounter);
  ATempName := '$str_cpy_tmp_' + IntToStr(FBlockLabelCounter);
  RegisterRuntimeVar(ATempName);
  RegisterRuntimeStrVar(ATempName);
  FModel.AddTypedHirNode('var-decl-tstring-runtime', ATempName, 0, 0,
    ATempName);
  FModel.AddTypedHirNode('string-temp-owned-runtime', SourceName, 0, 0,
    ATempName + #9 + 'callee ' + SourceName + #9 +
    'ptr len owner alloc_size');
  FModel.AddTypedHirNode('tstring-copy-runtime', ADestName, 0, 0,
    ADestName + #9 + ATempName + #9 + StartBlob + #9 + LenBlob);
  FModel.AddTypedHirNode('string-temp-release-runtime', SourceName, 0, 0,
    ATempName);
  Result := True;
end;

function TSemanticAnalyzer.WriteArgumentOwnsStringReturn(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  CalleeNode: TGreenNode;
begin
  AFuncName := '';
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.ChildCount <> 1) then
    Exit;
  CalleeNode := ANode.ChildAt(0);
  if (CalleeNode = nil) or (CalleeNode.NodeKind <> gnkIdentifier) then
    Exit;
  if not StringReturnFunctionNameFromNode(ANode, AFuncName) then
    Exit;
  Result := SameText(CalleeNode.Text, AFuncName) and
    (not HasOverload(AFuncName));
end;

function TSemanticAnalyzer.IsSupportedOwnedStringReturnWriteArgument(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
begin
  Result := WriteArgumentOwnsStringReturn(ANode, AFuncName) and
    IsOwnedStringReturnFunc(AFuncName);
end;

function TSemanticAnalyzer.EmitOwnedStringWriteTemp(
  const ANode: TGreenNode; out ATempName: string): Boolean;
var
  SourceName: string;
begin
  ATempName := '';
  Result := False;
  if not IsSupportedOwnedStringReturnWriteArgument(ANode, SourceName) then
    Exit;
  Inc(FBlockLabelCounter);
  ATempName := '$str_wrt_tmp_' + IntToStr(FBlockLabelCounter);
  RegisterRuntimeVar(ATempName);
  RegisterRuntimeStrVar(ATempName);
  FModel.AddTypedHirNode('var-decl-tstring-runtime', ATempName, 0, 0,
    ATempName);
  FModel.AddTypedHirNode('string-temp-owned-runtime', SourceName, 0, 0,
    ATempName + #9 + 'callee ' + SourceName + #9 +
    'ptr len owner alloc_size');
  QueuePendingStringTempRelease(ATempName, SourceName);
  Result := True;
end;

function TSemanticAnalyzer.EmitOwnedStringConcatWriteTemp(
  const ANode: TGreenNode; out ATempName: string): Boolean;
var
  LeftName, RightName: string;
begin
  ATempName := '';
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkBinaryExpression) or
    (ANode.Text <> '+') or (ANode.ChildCount < 2) or
    (not ConcatTreeHasSupportedOwnedStringReturn(ANode)) or
    (not CanEmitStrConcatOperand(ANode)) then
    Exit;
  LeftName := EmitStrConcatOperand(ANode.ChildAt(0), '');
  RightName := EmitStrConcatOperand(ANode.ChildAt(1), '');
  if (LeftName = '') or (RightName = '') then
    Exit;
  Inc(FBlockLabelCounter);
  ATempName := '$str_wrt_cat_tmp_' + IntToStr(FBlockLabelCounter);
  RegisterRuntimeVar(ATempName);
  RegisterRuntimeStrVar(ATempName);
  FModel.AddTypedHirNode('var-decl-tstring-runtime', ATempName, 0, 0,
    ATempName);
  FModel.AddTypedHirNode('assign-tstring-concat-runtime', ATempName, 0, 0,
    LeftName + #9 + RightName);
  QueuePendingStringTempRelease(ATempName, ATempName);
  Result := True;
end;

function TSemanticAnalyzer.ConcatOperandOwnsStringReturn(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  FuncNode: TGreenNode;
begin
  AFuncName := '';
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.ChildCount <> 1) then
    Exit;
  FuncNode := ANode.ChildAt(0);
  if (FuncNode = nil) or (FuncNode.NodeKind <> gnkIdentifier) then
    Exit;
  if not StringReturnFunctionNameFromNode(ANode, AFuncName) then
    Exit;
  Result := SameText(FuncNode.Text, AFuncName) and
    (not HasOverload(AFuncName));
end;

function TSemanticAnalyzer.IsSupportedOwnedStringReturnConcatOperand(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
begin
  Result := ConcatOperandOwnsStringReturn(ANode, AFuncName) and
    IsOwnedStringReturnFunc(AFuncName);
end;

function TSemanticAnalyzer.ConcatExpressionConsumesOwnedStringReturnDeferred(
  const ANode: TGreenNode; const AInsideDirectOwnedAssignmentRhs: Boolean): Boolean;
var
  I: LongInt;
  Child: TGreenNode;
  SourceName: string;
begin
  Result := False;
  if ANode = nil then
    Exit;
  if IsSupportedOwnedStringReturnConcatOperand(ANode, SourceName) then
    Exit(False);
  if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') then
  begin
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if ConcatExpressionConsumesOwnedStringReturnDeferred(Child,
        AInsideDirectOwnedAssignmentRhs) then
        Exit(True);
    end;
    Exit(False);
  end;
  Result := NodeConsumesOwnedStringReturnDeferred(ANode,
    AInsideDirectOwnedAssignmentRhs);
end;

function TSemanticAnalyzer.CompareOperandOwnsStringReturn(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  FuncNode: TGreenNode;
begin
  AFuncName := '';
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.ChildCount < 1) then
    Exit;
  FuncNode := ANode.ChildAt(0);
  if (FuncNode = nil) or (FuncNode.NodeKind <> gnkIdentifier) then
    Exit;
  if not StringReturnFunctionNameFromNode(ANode, AFuncName) then
    Exit;
  Result := SameText(FuncNode.Text, AFuncName) and
    (not HasOverload(AFuncName));
end;

function TSemanticAnalyzer.IsSupportedOwnedStringReturnCompareOperand(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
begin
  Result := CompareOperandOwnsStringReturn(ANode, AFuncName) and
    IsOwnedStringReturnFunc(AFuncName);
end;

function TSemanticAnalyzer.BoolConditionHasSupportedOwnedStringCompare(
  const ANode: TGreenNode): Boolean;
var
  Dummy: string;

  function CanEmitOwnedCompareOperand(const ALocalNode: TGreenNode): Boolean;
  begin
    Result := False;
    if ALocalNode = nil then
      Exit;
    if (ALocalNode.NodeKind = gnkIdentifier) and
      IsRuntimeStrVar(ALocalNode.Text) then
      Exit(True);
    if ALocalNode.NodeKind = gnkStringLiteral then
      Exit(True);
    if IsSupportedOwnedStringReturnCompareOperand(ALocalNode, Dummy) then
      Exit(True);
    if (ALocalNode.NodeKind = gnkBinaryExpression) and
      (ALocalNode.Text = '+') and (ALocalNode.ChildCount >= 2) then
      Exit(
        ConcatTreeHasSupportedOwnedStringReturn(ALocalNode) and
        CanEmitOwnedCompareOperand(ALocalNode.ChildAt(0)) and
        CanEmitOwnedCompareOperand(ALocalNode.ChildAt(1)));
  end;

  function IsSupportedCompareNode(const ALocalNode: TGreenNode): Boolean;
  begin
    Result := False;
    if (ALocalNode = nil) or (ALocalNode.NodeKind <> gnkBinaryExpression) or
      ((ALocalNode.Text <> '=') and (ALocalNode.Text <> '<>')) or
      (ALocalNode.ChildCount < 2) then
      Exit;
    if not (CanEmitOwnedCompareOperand(ALocalNode.ChildAt(0)) and
      CanEmitOwnedCompareOperand(ALocalNode.ChildAt(1))) then
      Exit;
    Result :=
      IsSupportedOwnedStringReturnCompareOperand(ALocalNode.ChildAt(0),
        Dummy) or
      IsSupportedOwnedStringReturnCompareOperand(ALocalNode.ChildAt(1),
        Dummy) or
      ConcatTreeHasSupportedOwnedStringReturn(ALocalNode.ChildAt(0)) or
      ConcatTreeHasSupportedOwnedStringReturn(ALocalNode.ChildAt(1));
  end;

  function HasSupportedOwnedCompare(const ALocalNode: TGreenNode): Boolean;
  begin
    Result := False;
    if ALocalNode = nil then
      Exit;
    if (ALocalNode.NodeKind = gnkUnaryExpression) and
      SameText(ALocalNode.Text, 'not') and (ALocalNode.ChildCount >= 1) then
      Exit(HasSupportedOwnedCompare(ALocalNode.ChildAt(0)));
    if (ALocalNode.NodeKind = gnkBinaryExpression) and
      (SameText(ALocalNode.Text, 'and') or SameText(ALocalNode.Text, 'or')) and
      (ALocalNode.ChildCount >= 2) then
      Exit(HasSupportedOwnedCompare(ALocalNode.ChildAt(0)) or
        HasSupportedOwnedCompare(ALocalNode.ChildAt(1)));
    Result := IsSupportedCompareNode(ALocalNode);
  end;

  function CanEmitOwnedBoolCondition(const ALocalNode: TGreenNode): Boolean;
  begin
    Result := False;
    if ALocalNode = nil then
      Exit;
    if (ALocalNode.NodeKind = gnkUnaryExpression) and
      SameText(ALocalNode.Text, 'not') and (ALocalNode.ChildCount >= 1) then
      Exit(CanEmitOwnedBoolCondition(ALocalNode.ChildAt(0)));
    if (ALocalNode.NodeKind = gnkIdentifier) and
      (IsRuntimeVar(ALocalNode.Text) or SameText(ALocalNode.Text, 'True') or
       SameText(ALocalNode.Text, 'False')) then
      Exit(True);
    if (ALocalNode.NodeKind = gnkBinaryExpression) and
      (SameText(ALocalNode.Text, 'and') or SameText(ALocalNode.Text, 'or')) and
      (ALocalNode.ChildCount >= 2) then
      Exit(CanEmitOwnedBoolCondition(ALocalNode.ChildAt(0)) and
        CanEmitOwnedBoolCondition(ALocalNode.ChildAt(1)));
    Result :=
      (ALocalNode.NodeKind = gnkBinaryExpression) and
      ((ALocalNode.Text = '=') or (ALocalNode.Text = '<>')) and
      (ALocalNode.ChildCount >= 2) and
      CanEmitOwnedCompareOperand(ALocalNode.ChildAt(0)) and
      CanEmitOwnedCompareOperand(ALocalNode.ChildAt(1));
  end;
begin
  Result := CanEmitOwnedBoolCondition(ANode) and
    HasSupportedOwnedCompare(ANode);
end;

function TSemanticAnalyzer.CompareExpressionConsumesOwnedStringReturnDeferred(
  const ANode: TGreenNode): Boolean;
var
  I: LongInt;
begin
  Result := False;
  if ANode = nil then
    Exit;
  if (ANode.NodeKind = gnkUnaryExpression) and SameText(ANode.Text, 'not') and
    (ANode.ChildCount >= 1) then
    Exit(CompareExpressionConsumesOwnedStringReturnDeferred(ANode.ChildAt(0)));
  if (ANode.NodeKind = gnkBinaryExpression) and
    (SameText(ANode.Text, 'and') or SameText(ANode.Text, 'or')) and
    (ANode.ChildCount >= 2) then
    Exit(CompareExpressionConsumesOwnedStringReturnDeferred(ANode.ChildAt(0)) or
      CompareExpressionConsumesOwnedStringReturnDeferred(ANode.ChildAt(1)));
  if (ANode.NodeKind <> gnkBinaryExpression) or
    ((ANode.Text <> '=') and (ANode.Text <> '<>')) or
    (ANode.ChildCount < 2) then
  begin
    { In compare expressions (if/while conditions), all sub-expressions are
      consumed immediately. Temporaries from owned string returns are safe. }
    for I := 0 to ANode.ChildCount - 1 do
      if NodeConsumesOwnedStringReturnDeferred(ANode.ChildAt(I), True) then
        Exit(True);
    Exit(False);
  end;
  if CanEmitStrCompareOperand(ANode.ChildAt(0), True) and
    CanEmitStrCompareOperand(ANode.ChildAt(1), True) then
    Exit(False);
  Result := NodeConsumesOwnedStringReturnDeferred(ANode, False);
end;

function TSemanticAnalyzer.NodeConsumesOwnedStringReturnDeferred(
  const ANode: TGreenNode;
  const AInsideDirectOwnedAssignmentRhs: Boolean): Boolean;
var
  I: LongInt;
  BodyNode, Child, DeclNode, DestNode, SourceNode: TGreenNode;
  SourceName: string;
begin
  Result := False;
  if ANode = nil then
    Exit;

  if (ANode.NodeKind = gnkProcedureDecl) or
    (ANode.NodeKind = gnkFunctionDecl) then
    Exit;

  if (ANode.NodeKind = gnkIfStatement) and (ANode.ChildCount >= 1) then
  begin
    if CompareExpressionConsumesOwnedStringReturnDeferred(ANode.ChildAt(0)) then
      Exit(True);
    for I := 1 to ANode.ChildCount - 1 do
      if NodeConsumesOwnedStringReturnDeferred(
        ANode.ChildAt(I), AInsideDirectOwnedAssignmentRhs) then
        Exit(True);
    Exit(False);
  end;

  if ((ANode.NodeKind = gnkWhileStatement) or
    (ANode.NodeKind = gnkRepeatStatement)) and (ANode.ChildCount >= 2) then
  begin
    if ANode.NodeKind = gnkWhileStatement then
    begin
      Child := ANode.ChildAt(0);
      BodyNode := ANode.ChildAt(1);
    end
    else
    begin
      BodyNode := ANode.ChildAt(0);
      Child := ANode.ChildAt(1);
    end;
    if CompareExpressionConsumesOwnedStringReturnDeferred(Child) then
      Exit(True);
    if BoolConditionHasSupportedOwnedStringCompare(Child) then
      Exit(NodeConsumesOwnedStringReturnDeferred(
        BodyNode, AInsideDirectOwnedAssignmentRhs));
  end;

  if DirectOwnedStringReturnAssignmentNode(ANode) then
  begin
    if ANode.ChildCount >= 2 then
    begin
      for I := 0 to ANode.ChildAt(1).ChildCount - 1 do
      begin
        if (ANode.ChildAt(1).NodeKind = gnkFunctionCall) and (I = 0) then
          Continue;
        if (ANode.ChildAt(1).NodeKind = gnkFunctionCall) and
          IsSupportedOwnedStringReturnArgument(ANode.ChildAt(1),
            ANode.ChildAt(1).ChildAt(I), I - 1) then
          Continue;
        if NodeConsumesOwnedStringReturnDeferred(
          ANode.ChildAt(1).ChildAt(I), False) then
          Exit(True);
      end;
    end;
    Exit(False);
  end;

  if ANode.NodeKind = gnkAssignmentStatement then
  begin
    if ANode.ChildCount >= 2 then
    begin
      DestNode := ANode.ChildAt(0);
      SourceNode := ANode.ChildAt(1);
      if (IsSupportedOwnedStringReturnStoreTarget(DestNode) or
        IsSupportedOwnedStringReturnIdentifierTarget(DestNode)) and
        StringReturnFunctionNameFromNode(SourceNode, SourceName) and
        IsOwnedStringReturnFunc(SourceName) then
        Exit(False);
      if (DestNode <> nil) and (DestNode.NodeKind = gnkIdentifier) and
        IsRuntimeStrVar(DestNode.Text) and
        (SourceNode <> nil) and (SourceNode.NodeKind = gnkBinaryExpression) and
        (SourceNode.Text = '+') then
        Exit(ConcatExpressionConsumesOwnedStringReturnDeferred(SourceNode,
          True));
      Exit(NodeConsumesOwnedStringReturnDeferred(
        SourceNode, {AInsideDirectOwnedAssignmentRhs=}True));
    end;
    Exit(False);
  end;

  if (ANode.NodeKind = gnkFunctionCall) and
    ((SameText(ANode.Text, 'WriteLn')) or (SameText(ANode.Text, 'Write'))) then
  begin
    for I := 1 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if Child = nil then
        Continue;
      if IsSupportedOwnedStringReturnWriteArgument(Child, SourceName) then
        Continue;
      if (Child.NodeKind = gnkBinaryExpression) and (Child.Text = '+') and
        ConcatTreeHasSupportedOwnedStringReturn(Child) and
        CanEmitStrConcatOperand(Child) then
        Continue;
      { WriteLn/Write arguments are safe contexts: temporaries live for
        the entire call duration. }
      if NodeConsumesOwnedStringReturnDeferred(Child, True) then
        Exit(True);
    end;
    Exit(False);
  end;

  if (ANode.NodeKind = gnkFunctionCall) and
    LookupProcedureBody(ANode.Text, BodyNode, DeclNode) and
    (not FunctionCallReturnsString(ANode)) then
  begin
    for I := 1 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if Child = nil then
        Continue;
      if IsSupportedOwnedStringReturnArgument(ANode, Child, I - 1) then
        Continue;
      if NodeConsumesOwnedStringReturnDeferred(
        Child, AInsideDirectOwnedAssignmentRhs) then
        Exit(True);
    end;
    Exit(False);
  end;

  if IsSupportedOwnedStringReturnLengthArgument(ANode, SourceName) then
    Exit(False);
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and SameText(ANode.ChildAt(0).Text, 'Length') and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(1).NodeKind = gnkBinaryExpression) and
    (ANode.ChildAt(1).Text = '+') and
    ConcatTreeHasSupportedOwnedStringReturn(ANode.ChildAt(1)) and
    CanEmitStrConcatOperand(ANode.ChildAt(1)) then
    Exit(False);
  if IsSupportedOwnedStringReturnCopyArgument(ANode, SourceName) then
    Exit(False);

  if StringReturnFunctionNameFromNode(ANode, SourceName) and
    IsOwnedStringReturnFunc(SourceName) and
    (not AInsideDirectOwnedAssignmentRhs) then
    Exit(True);
  if MemberCallReturnsString(ANode) and
    (not AInsideDirectOwnedAssignmentRhs) then
    Exit(True);
  { Note: FunctionCallReturnsString catch-all intentionally removed.
    It was too broad — flagging ALL string-returning functions, not just
    registered owned string return functions. The StringReturnFunctionNameFromNode
    + IsOwnedStringReturnFunc check above correctly limits to registered
    functions. }
  if DirectOwnedStringReturnAssignmentNode(ANode) and
    StringReturnFunctionNameFromNode(ANode.ChildAt(1), SourceName) and
    HasOverload(SourceName) then
    Exit(True);

  { Exit(Expr) is equivalent to Result := Expr — the temporary lives for
    the entire function scope. Treat as safe context.
    Without this guard, Exit(F()) patterns where F is an imported function
    (like ExpandFileName from nextpas.core.fs) would fall through to the
    for-loop below, where the F() child would be flagged as a deferred
    owned-string return. }
  if ANode.NodeKind = gnkExitStatement then
  begin
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if Child = nil then Continue;
      { The owned string temporary from F() in Exit(F()) lives for the
        entire duration of Exit — treat as safe context. }
      if NodeConsumesOwnedStringReturnDeferred(Child, True) then
        Exit(True);
    end;
    Exit(False);
  end;

  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    { Owned string temporaries passed as arguments to a function call are
      safe: the temporary lives for the entire enclosing call's duration.
      This handles patterns like SameText(LowerCase(S), 'value') where the
      outer call has overloads (preventing IsSupportedOwnedStringReturnArgument
      from applying). Mark argument positions (I >= 1) as safe contexts. }
    if (ANode.NodeKind = gnkFunctionCall) and (I >= 1) then
    begin
      if NodeConsumesOwnedStringReturnDeferred(Child, True) then
        Exit(True);
    end
    { Concatenation operands are safe: temporaries live for the entire
      expression evaluation. }
    else if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') then
    begin
      if NodeConsumesOwnedStringReturnDeferred(Child, True) then
        Exit(True);
    end
    else if NodeConsumesOwnedStringReturnDeferred(
      Child, AInsideDirectOwnedAssignmentRhs) then
      Exit(True);
  end;
end;

procedure TSemanticAnalyzer.ScanOwnedStringReturnConsumers(
  const ANode: TGreenNode; const AEntry: TProcedureBodyEntry;
  var AChanged: Boolean);
var
  I, J: LongInt;
  Child: TGreenNode;
  FuncName: string;
begin
  if ANode = nil then
    Exit;
  if AssignmentOwnsStringReturn(ANode, AEntry) and
    StringReturnFunctionNameFromNode(ANode.ChildAt(1), FuncName) and
    (not IsOwnedStringReturnFunc(FuncName)) then
  begin
    RegisterOwnedStringReturnFunc(FuncName);
    AChanged := True;
  end;
  if ANode.NodeKind = gnkFunctionCall then
  begin
    for J := 1 to ANode.ChildCount - 1 do
    begin
      if CallArgumentOwnsStringReturn(
        ANode, ANode.ChildAt(J), J - 1, FuncName) and
        (not IsOwnedStringReturnFunc(FuncName)) then
      begin
        RegisterOwnedStringReturnFunc(FuncName);
        AChanged := True;
      end;
      if (SameText(ANode.Text, 'WriteLn') or SameText(ANode.Text, 'Write')) and
        WriteArgumentOwnsStringReturn(ANode.ChildAt(J), FuncName) and
        (not IsOwnedStringReturnFunc(FuncName)) then
      begin
        RegisterOwnedStringReturnFunc(FuncName);
        AChanged := True;
      end;
      if SameText(ANode.Text, 'WriteLn') or SameText(ANode.Text, 'Write') then
        RegisterConcatOwnedStringReturnConsumers(ANode.ChildAt(J), AChanged);
    end;
    if LengthArgumentOwnsStringReturn(ANode, FuncName) and
      (not IsOwnedStringReturnFunc(FuncName)) then
    begin
      RegisterOwnedStringReturnFunc(FuncName);
      AChanged := True;
    end;
    if (ANode.ChildCount >= 2) and (ANode.ChildAt(0) <> nil) and
      SameText(ANode.ChildAt(0).Text, 'Length') then
      RegisterConcatOwnedStringReturnConsumers(ANode.ChildAt(1), AChanged);
    if CopyArgumentOwnsStringReturn(ANode, FuncName) and
      (not IsOwnedStringReturnFunc(FuncName)) then
    begin
      RegisterOwnedStringReturnFunc(FuncName);
      AChanged := True;
    end;
  end;
  if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') then
  begin
    for J := 0 to ANode.ChildCount - 1 do
    begin
      if ConcatOperandOwnsStringReturn(ANode.ChildAt(J), FuncName) and
        (not IsOwnedStringReturnFunc(FuncName)) then
      begin
        RegisterOwnedStringReturnFunc(FuncName);
        AChanged := True;
      end;
    end;
  end;
  if (ANode.NodeKind = gnkBinaryExpression) and
    ((ANode.Text = '=') or (ANode.Text = '<>')) then
  begin
    for J := 0 to ANode.ChildCount - 1 do
    begin
      if CompareOperandOwnsStringReturn(ANode.ChildAt(J), FuncName) and
        (not IsOwnedStringReturnFunc(FuncName)) then
      begin
        RegisterOwnedStringReturnFunc(FuncName);
        AChanged := True;
      end;
    end;
  end;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child <> nil) and
      ((Child.NodeKind = gnkProcedureDecl) or
       (Child.NodeKind = gnkFunctionDecl)) then
      Continue;
    ScanOwnedStringReturnConsumers(Child, AEntry, AChanged);
  end;
end;

procedure TSemanticAnalyzer.ScanTopLevelOwnedStringReturnConsumers(
  const ANode: TGreenNode; var AChanged: Boolean);
var
  I, J: LongInt;
  Child: TGreenNode;
  FuncName: string;
begin
  if ANode = nil then
    Exit;
  if AssignmentOwnsTopLevelStringReturn(ANode) and
    StringReturnFunctionNameFromNode(ANode.ChildAt(1), FuncName) and
    (not IsOwnedStringReturnFunc(FuncName)) then
  begin
    RegisterOwnedStringReturnFunc(FuncName);
    AChanged := True;
  end;
  if ANode.NodeKind = gnkFunctionCall then
  begin
    for J := 1 to ANode.ChildCount - 1 do
    begin
      if CallArgumentOwnsStringReturn(
        ANode, ANode.ChildAt(J), J - 1, FuncName) and
        (not IsOwnedStringReturnFunc(FuncName)) then
      begin
        RegisterOwnedStringReturnFunc(FuncName);
        AChanged := True;
      end;
      if (SameText(ANode.Text, 'WriteLn') or SameText(ANode.Text, 'Write')) and
        WriteArgumentOwnsStringReturn(ANode.ChildAt(J), FuncName) and
        (not IsOwnedStringReturnFunc(FuncName)) then
      begin
        RegisterOwnedStringReturnFunc(FuncName);
        AChanged := True;
      end;
      if SameText(ANode.Text, 'WriteLn') or SameText(ANode.Text, 'Write') then
        RegisterConcatOwnedStringReturnConsumers(ANode.ChildAt(J), AChanged);
    end;
    if LengthArgumentOwnsStringReturn(ANode, FuncName) and
      (not IsOwnedStringReturnFunc(FuncName)) then
    begin
      RegisterOwnedStringReturnFunc(FuncName);
      AChanged := True;
    end;
    if (ANode.ChildCount >= 2) and (ANode.ChildAt(0) <> nil) and
      SameText(ANode.ChildAt(0).Text, 'Length') then
      RegisterConcatOwnedStringReturnConsumers(ANode.ChildAt(1), AChanged);
    if CopyArgumentOwnsStringReturn(ANode, FuncName) and
      (not IsOwnedStringReturnFunc(FuncName)) then
    begin
      RegisterOwnedStringReturnFunc(FuncName);
      AChanged := True;
    end;
  end;
  if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') then
  begin
    for J := 0 to ANode.ChildCount - 1 do
    begin
      if ConcatOperandOwnsStringReturn(ANode.ChildAt(J), FuncName) and
        (not IsOwnedStringReturnFunc(FuncName)) then
      begin
        RegisterOwnedStringReturnFunc(FuncName);
        AChanged := True;
      end;
    end;
  end;
  if (ANode.NodeKind = gnkBinaryExpression) and
    ((ANode.Text = '=') or (ANode.Text = '<>')) then
  begin
    for J := 0 to ANode.ChildCount - 1 do
    begin
      if CompareOperandOwnsStringReturn(ANode.ChildAt(J), FuncName) and
        (not IsOwnedStringReturnFunc(FuncName)) then
      begin
        RegisterOwnedStringReturnFunc(FuncName);
        AChanged := True;
      end;
    end;
  end;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child <> nil) and
      ((Child.NodeKind = gnkProcedureDecl) or
       (Child.NodeKind = gnkFunctionDecl)) then
      Continue;
    ScanTopLevelOwnedStringReturnConsumers(Child, AChanged);
  end;
end;

procedure TSemanticAnalyzer.CheckDeferredOwnedStringReturnConsumers(
  const ANode: TGreenNode);
begin
  if ANode = nil then
    Exit;
  if NodeConsumesOwnedStringReturnDeferred(ANode, False) then
  begin
    EmitSemaError(
      'sema.c6h4-owned-string-return-deferred-consumer',
      'C6-H4: owned string return used in deferred context; ' +
      'assign to a local variable first',
      ANode.ByteOffset);
    Exit;
  end;
end;

procedure TSemanticAnalyzer.PreRegisterOwnedStringReturnConsumers;
var
  I: LongInt;
  Changed: Boolean;
  Entry: TProcedureBodyEntry;
  RootNode: TGreenNode;
  SavedMethodClass, SavedRetVarName: string;
  SavedScopeId: LongInt;
begin
  repeat
    Changed := False;
    if (FRootAst <> nil) and FRootAst.IsValid then
    begin
      RootNode := FRootAst.RootNode;
      if RootNode <> nil then
        ScanTopLevelOwnedStringReturnConsumers(RootNode, Changed);
    end;
    for I := 0 to Length(FProcedureBodies) - 1 do
    begin
      Entry := FProcedureBodies[I];
      if (Entry.Body = nil) or (Entry.Decl = nil) or (Pos('<', Entry.Name) > 0) then
        Continue;
      SavedMethodClass := FCurrentMethodClass;
      SavedRetVarName := FCurrentRetVarName;
      SavedScopeId := FCurrentScopeId;
      if Pos('.', Entry.Name) > 0 then
        FCurrentMethodClass := Copy(Entry.Name, 1, Pos('.', Entry.Name) - 1)
      else
        FCurrentMethodClass := '';
      FCurrentRetVarName := Entry.Name;
      if Pos('.', FCurrentRetVarName) > 0 then
        FCurrentRetVarName := Copy(FCurrentRetVarName,
          Pos('.', FCurrentRetVarName) + 1, Length(FCurrentRetVarName));
      if Entry.ScopeId > 0 then
        FCurrentScopeId := Entry.ScopeId;
      try
        ScanOwnedStringReturnConsumers(Entry.Body, Entry, Changed);
      finally
        FCurrentMethodClass := SavedMethodClass;
        FCurrentRetVarName := SavedRetVarName;
        FCurrentScopeId := SavedScopeId;
      end;
    end;
  until not Changed;
  if (FRootAst <> nil) and FRootAst.IsValid then
  begin
    RootNode := FRootAst.RootNode;
    if RootNode <> nil then
      CheckDeferredOwnedStringReturnConsumers(RootNode);
  end;
  if not FDiagnostics.HasErrors then
  begin
    for I := 0 to Length(FProcedureBodies) - 1 do
    begin
      Entry := FProcedureBodies[I];
      if (Entry.Body = nil) or (Entry.Decl = nil) or (Pos('<', Entry.Name) > 0) then
        Continue;
      // Skip C6-H4 check for procedure bodies in external (non-root) units.
      // External units like SysUtils may use owned string returns in safe patterns
      // that the C6-H4 check does not fully support.
      if not SameText(NormalizeUnitIdentity(Entry.OwnerUnitId),
        NormalizeUnitIdentity(FUnitGraph.RootName)) then
        Continue;
      SavedMethodClass := FCurrentMethodClass;
      SavedRetVarName := FCurrentRetVarName;
      SavedScopeId := FCurrentScopeId;
      if Pos('.', Entry.Name) > 0 then
        FCurrentMethodClass := Copy(Entry.Name, 1, Pos('.', Entry.Name) - 1)
      else
        FCurrentMethodClass := '';
      FCurrentRetVarName := Entry.Name;
      if Pos('.', FCurrentRetVarName) > 0 then
        FCurrentRetVarName := Copy(FCurrentRetVarName,
          Pos('.', FCurrentRetVarName) + 1, Length(FCurrentRetVarName));
      if Entry.ScopeId > 0 then
        FCurrentScopeId := Entry.ScopeId;
      try
        CheckDeferredOwnedStringReturnConsumers(Entry.Body);
      finally
        FCurrentMethodClass := SavedMethodClass;
        FCurrentRetVarName := SavedRetVarName;
        FCurrentScopeId := SavedScopeId;
      end;
      if FDiagnostics.HasErrors then
        Exit;
    end;
  end;
end;

procedure TSemanticAnalyzer.RegisterRuntimeArrVar(const AName: string);
var
  Idx: LongInt;
  NextIndex: SizeInt;
begin
  for Idx := 0 to Length(FRuntimeArrVarNames) - 1 do
    if SameText(FRuntimeArrVarNames[Idx], AName) then
      Exit;
  NextIndex := Length(FRuntimeArrVarNames);
  SetLength(FRuntimeArrVarNames, NextIndex + 1);
  FRuntimeArrVarNames[NextIndex] := AName;
end;

procedure TSemanticAnalyzer.RegisterBorrowedRuntimeArrVar(const AName: string);
var
  Idx: LongInt;
  NextIndex: SizeInt;
begin
  for Idx := 0 to Length(FBorrowedRuntimeArrVarNames) - 1 do
    if SameText(FBorrowedRuntimeArrVarNames[Idx], AName) then
      Exit;
  NextIndex := Length(FBorrowedRuntimeArrVarNames);
  SetLength(FBorrowedRuntimeArrVarNames, NextIndex + 1);
  FBorrowedRuntimeArrVarNames[NextIndex] := AName;
end;

function TSemanticAnalyzer.IsRuntimeArrVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FRuntimeArrVarNames) - 1 do
    if SameText(FRuntimeArrVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

function TSemanticAnalyzer.IsBorrowedRuntimeArrVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FBorrowedRuntimeArrVarNames) - 1 do
    if SameText(FBorrowedRuntimeArrVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

function TSemanticAnalyzer.IsStaticRuntimeArrVar(const AName: string): Boolean;
var
  Value: Int64;
begin
  Result := FModel.LookupConstValue(AName + '$arr_static', Value) and
    (Value <> 0);
end;

function TSemanticAnalyzer.DynArrayElemSizeOfVar(const AName: string): Int64;
begin
  Result := 8;
  if not FModel.LookupConstValue(AName + '$arr_elem_size', Result) then
    Result := 8;
end;

procedure TSemanticAnalyzer.EmitOwnedStringCleanupNodes(const AExceptName: string);
var
  I: LongInt;
  VarName: string;
begin
  for I := 0 to Length(FOwnedRuntimeStrVarNames) - 1 do
  begin
    VarName := FOwnedRuntimeStrVarNames[I];
    if (VarName = '') or IsBorrowedRuntimeStrVar(VarName) or
      SameText(VarName, AExceptName) then
      Continue;
    FModel.AddTypedHirNode(
      'tstring-cleanup-runtime',
      VarName,
      0,
      0,
      VarName
    );
  end;
end;

procedure TSemanticAnalyzer.EmitOwnedDynArrayCleanupNodes;
var
  I: LongInt;
  VarName: string;
begin
  for I := 0 to Length(FRuntimeArrVarNames) - 1 do
  begin
    VarName := FRuntimeArrVarNames[I];
    if (VarName = '') or IsBorrowedRuntimeArrVar(VarName) or
      IsStaticRuntimeArrVar(VarName) then
      Continue;
    FModel.AddTypedHirNode(
      'dynarray-cleanup-runtime',
      VarName,
      0,
      0,
      VarName + #9 + 'int ' + IntToStr(DynArrayElemSizeOfVar(VarName)) + #10
    );
  end;
end;

function TSemanticAnalyzer.IsManagedRecord(const ATypeName: string): Boolean;
var
  Meta: TTypeMetadata;
  I: LongInt;
begin
  Result := False;
  if not FModel.GetTypeMetaByName(ATypeName, Meta) then
    Exit;
  if not Meta.IsRecord then
    Exit;
  for I := 0 to High(Meta.Fields) do
  begin
    if Meta.Fields[I].IsString or Meta.Fields[I].IsDynArray then
      Exit(True);
    { 递归检查嵌套 record }
    if Meta.Fields[I].IsRecord then
    begin
      if (Meta.Fields[I].TypeId > 0) and
        (Meta.Fields[I].TypeId <= FModel.TypeCount) and
        IsManagedRecord(FModel.TypeAt(Meta.Fields[I].TypeId - 1).Name) then
        Exit(True);
    end;
  end;
end;

procedure TSemanticAnalyzer.EmitOwnedManagedRecordCleanupNodes;
var
  I, J: LongInt;
  VarName, TypeName, Blob: string;
  Meta: TTypeMetadata;
  NeedCleanup: Boolean;
begin
  for I := 0 to Length(FManagedRecordVarNames) - 1 do
  begin
    VarName := FManagedRecordVarNames[I];
    TypeName := FManagedRecordVarTypes[I];
    if not FModel.GetTypeMetaByName(TypeName, Meta) then
      Continue;
    Blob := VarName + #9 + TypeName;
    NeedCleanup := False;
    for J := 0 to High(Meta.Fields) do
    begin
      if Meta.Fields[J].IsString then
      begin
        Blob := Blob + #9 + Meta.Fields[J].Name + ':s';
        NeedCleanup := True;
      end
      else if Meta.Fields[J].IsDynArray then
      begin
        Blob := Blob + #9 + Meta.Fields[J].Name + ':d';
        NeedCleanup := True;
      end;
    end;
    if NeedCleanup then
      FModel.AddTypedHirNode(
        'managed-record-cleanup-runtime',
        VarName,
        0,
        0,
        Blob
      );
  end;
end;

procedure TSemanticAnalyzer.RegisterClassVar(const AName, AClassName: string);
var
  Idx: LongInt;
  V: Int64;
begin
  for Idx := 0 to Length(FClassVarNames) - 1 do
    if SameText(FClassVarNames[Idx], AName) then
    begin
      if FModel.LookupConstValue(FClassVarTypes[Idx] + '$vmt_count', V) and
        TypeMetaIsInterface(FClassVarTypes[Idx]) then
        Exit;
      FClassVarTypes[Idx] := AClassName;
      Exit;
    end;
  Idx := Length(FClassVarNames);
  SetLength(FClassVarNames, Idx + 1);
  SetLength(FClassVarTypes, Idx + 1);
  FClassVarNames[Idx] := AName;
  FClassVarTypes[Idx] := AClassName;
end;

function TSemanticAnalyzer.LookupClassVar(const AName: string): string;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FClassVarNames) - 1 do
    if SameText(FClassVarNames[Idx], AName) then
      Exit(FClassVarTypes[Idx]);
  Result := '';
end;

procedure TSemanticAnalyzer.RegisterRecordVar(const AName, ATypeName: string);
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FRecordVarNames) - 1 do
    if SameText(FRecordVarNames[Idx], AName) then
    begin
      FRecordVarTypes[Idx] := ATypeName;
      Exit;
    end;
  Idx := Length(FRecordVarNames);
  SetLength(FRecordVarNames, Idx + 1);
  SetLength(FRecordVarTypes, Idx + 1);
  FRecordVarNames[Idx] := AName;
  FRecordVarTypes[Idx] := ATypeName;
end;

procedure TSemanticAnalyzer.RegisterPointerVar(const AName,
  APointeeTypeName: string);
var
  Idx: LongInt;
begin
  if (AName = '') or (APointeeTypeName = '') then
    Exit;
  for Idx := 0 to Length(FPointerVarNames) - 1 do
    if SameText(FPointerVarNames[Idx], AName) then
    begin
      FPointerVarTypes[Idx] := APointeeTypeName;
      Exit;
    end;
  Idx := Length(FPointerVarNames);
  SetLength(FPointerVarNames, Idx + 1);
  SetLength(FPointerVarTypes, Idx + 1);
  FPointerVarNames[Idx] := AName;
  FPointerVarTypes[Idx] := APointeeTypeName;
end;

function TSemanticAnalyzer.IsRecordVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FRecordVarNames) - 1 do
    if SameText(FRecordVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

procedure TSemanticAnalyzer.RegisterVarParam(const AName: string);
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FVarParamNames) - 1 do
    if SameText(FVarParamNames[Idx], AName) then
      Exit;
  Idx := Length(FVarParamNames);
  SetLength(FVarParamNames, Idx + 1);
  FVarParamNames[Idx] := AName;
end;

function TSemanticAnalyzer.IsVarParam(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FVarParamNames) - 1 do
    if SameText(FVarParamNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

function TSemanticAnalyzer.IsVarParamAtPosition(
  const ADecl: TGreenNode; APosition: LongInt): Boolean;
var
  J, K, ParamIdx: LongInt;
  Child, ParamChild: TGreenNode;
begin
  Result := False;
  if ADecl = nil then Exit;
  for J := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkParameterList) then
    begin
      ParamIdx := 0;
      for K := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(K);
        if (ParamChild = nil) or (ParamChild.NodeKind <> gnkParameterDecl) then
          Continue;
        if ParamIdx = APosition then
        begin
          Result := ParamNameIsByRef(ParamChild.Text);
          Exit;
        end;
        Inc(ParamIdx);
      end;
      Exit;
    end;
  end;
end;

function TSemanticAnalyzer.LookupRecordVar(const AName: string): string;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FRecordVarNames) - 1 do
    if SameText(FRecordVarNames[Idx], AName) then
      Exit(FRecordVarTypes[Idx]);
  Result := '';
end;

function TSemanticAnalyzer.LookupPointerVar(const AName: string): string;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FPointerVarNames) - 1 do
    if SameText(FPointerVarNames[Idx], AName) then
      Exit(FPointerVarTypes[Idx]);
  Result := '';
end;

procedure TSemanticAnalyzer.RegisterPtrReturnFunc(const AName, AClassName: string);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FPtrReturnFuncs);
  SetLength(FPtrReturnFuncs, NextIndex + 1);
  SetLength(FPtrReturnTypes, NextIndex + 1);
  FPtrReturnFuncs[NextIndex] := AName;
  FPtrReturnTypes[NextIndex] := AClassName;
end;

procedure TSemanticAnalyzer.RegisterImportedUnitTree(const ATree: TGreenTree;
  const AOwnerUnitId: string);
var
  NextIndex: SizeInt;
begin
  if ATree = nil then
    Exit;
  NextIndex := Length(FImportedUnitTrees);
  SetLength(FImportedUnitTrees, NextIndex + 1);
  SetLength(FImportedUnitOwners, NextIndex + 1);
  FImportedUnitTrees[NextIndex] := ATree;
  FImportedUnitOwners[NextIndex] := AOwnerUnitId;
end;

function TSemanticAnalyzer.LookupPtrReturnFunc(const AName: string): string;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FPtrReturnFuncs) - 1 do
    if SameText(FPtrReturnFuncs[Idx], AName) then
      Exit(FPtrReturnTypes[Idx]);
  Result := '';
end;

function TSemanticAnalyzer.EmitStrConcatOperand(const ANode: TGreenNode;
  const ADestVar: string): string;
var
  TempName, LitValue: string;
  FieldIdx: Int64;
begin
  Result := '';
  if ANode = nil then
    Exit;
  if (ANode.NodeKind = gnkIdentifier) and IsRuntimeStrVar(ANode.Text) then
    Exit(ANode.Text);
  if (ANode.NodeKind = gnkIdentifier) and (FCurrentMethodClass <> '') and
    TypeMetaFieldIsStr(FCurrentMethodClass, ANode.Text) then
  begin
    FieldIdx := TypeMetaFieldIndex(FCurrentMethodClass, ANode.Text);
    Inc(FBlockLabelCounter);
    TempName := '$str_tmp_' + IntToStr(FBlockLabelCounter);
    RegisterRuntimeVar(TempName);
    RegisterRuntimeStrVar(TempName);
    FModel.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0, TempName);
    FModel.AddTypedHirNode(
      'assign-tstring-field-load-runtime', TempName, 0, 0,
      TempName + #9 + IntToStr(FieldIdx)
    );
    Exit(TempName);
  end;
  if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') and
    (ANode.ChildCount >= 2) and (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(1) <> nil) then
  begin
    LitValue := EmitStrConcatOperand(ANode.ChildAt(0), ADestVar);
    if LitValue <> '' then
    begin
      TempName := EmitStrConcatOperand(ANode.ChildAt(1), ADestVar);
      if TempName <> '' then
      begin
        Inc(FBlockLabelCounter);
        Result := '$str_tmp_' + IntToStr(FBlockLabelCounter);
        RegisterRuntimeVar(Result);
        RegisterRuntimeStrVar(Result);
        FModel.AddTypedHirNode('var-decl-tstring-runtime', Result, 0, 0, Result);
        FModel.AddTypedHirNode(
          'assign-tstring-concat-runtime',
          LitValue + #9 + TempName,
          0, 0, Result
        );
        Exit;
      end;
    end;
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    SameText(ANode.ChildAt(0).Text, 'IntToStr') and
    EncodeRuntimeIntExprFold(ANode.ChildAt(1), LitValue) then
  begin
    Inc(FBlockLabelCounter);
    TempName := '$str_tmp_' + IntToStr(FBlockLabelCounter);
    RegisterRuntimeVar(TempName);
    RegisterRuntimeStrVar(TempName);
    FModel.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0, TempName);
    FModel.AddTypedHirNode('tstring-from-int-runtime', TempName, 0, 0,
      TempName + #9 + LitValue);
    Exit(TempName);
  end;
  if IsSupportedOwnedStringReturnConcatOperand(ANode, LitValue) then
  begin
    Inc(FBlockLabelCounter);
    TempName := '$str_cat_tmp_' + IntToStr(FBlockLabelCounter);
    RegisterRuntimeVar(TempName);
    RegisterRuntimeStrVar(TempName);
    FModel.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0,
      TempName);
    FModel.AddTypedHirNode('string-temp-owned-runtime', LitValue, 0, 0,
      TempName + #9 + 'callee ' + LitValue + #9 +
      'ptr len owner alloc_size');
    QueuePendingStringTempRelease(TempName, LitValue);
    Exit(TempName);
  end;
  if ANode.NodeKind = gnkStringLiteral then
    LitValue := DecodePascalStringLiteral(ANode.Text)
  else if not EvaluateStringConstant(ANode, LitValue) then
    Exit;
  Inc(FBlockLabelCounter);
  TempName := '$str_tmp_' + IntToStr(FBlockLabelCounter);
  RegisterRuntimeVar(TempName);
  RegisterRuntimeStrVar(TempName);
  FModel.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0, TempName);
  FModel.AddTypedHirNode('assign-tstring-literal-runtime', TempName, 0, 0, LitValue);
  Result := TempName;
end;

function TSemanticAnalyzer.ConcatTreeHasSupportedOwnedStringReturn(
  const ANode: TGreenNode): Boolean;
var
  Dummy: string;
begin
  Result := False;
  if ANode = nil then
    Exit;
  if IsSupportedOwnedStringReturnConcatOperand(ANode, Dummy) then
    Exit(True);
  if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') and
    (ANode.ChildCount >= 2) then
    Exit(ConcatTreeHasSupportedOwnedStringReturn(ANode.ChildAt(0)) or
      ConcatTreeHasSupportedOwnedStringReturn(ANode.ChildAt(1)));
end;

function TSemanticAnalyzer.CanEmitStrConcatOperand(
  const ANode: TGreenNode): Boolean;
var
  Dummy: string;
begin
  Result := False;
  if ANode = nil then
    Exit;
  if (ANode.NodeKind = gnkIdentifier) and IsRuntimeStrVar(ANode.Text) then
    Exit(True);
  if (ANode.NodeKind = gnkIdentifier) and (FCurrentMethodClass <> '') and
    TypeMetaFieldIsStr(FCurrentMethodClass, ANode.Text) then
    Exit(True);
  if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') and
    (ANode.ChildCount >= 2) then
    Exit(CanEmitStrConcatOperand(ANode.ChildAt(0)) and
      CanEmitStrConcatOperand(ANode.ChildAt(1)));
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and SameText(ANode.ChildAt(0).Text,
    'IntToStr') and EncodeRuntimeIntExprFold(ANode.ChildAt(1), Dummy) then
    Exit(True);
  if IsSupportedOwnedStringReturnConcatOperand(ANode, Dummy) then
    Exit(True);
  if ANode.NodeKind = gnkStringLiteral then
    Exit(True);
  Result := EvaluateStringConstant(ANode, Dummy);
end;

function TSemanticAnalyzer.CanEmitStrCompareOperand(const ANode: TGreenNode;
  const AAllowOwnedStringReturn: Boolean): Boolean;
var
  SourceName: string;
begin
  Result := False;
  if ANode = nil then
    Exit;
  if (ANode.NodeKind = gnkIdentifier) and IsRuntimeStrVar(ANode.Text) then
    Exit(True);
  { Any identifier can safely participate in string comparisons —
    comparisons don't hold references to owned string returns. }
  if (ANode.NodeKind = gnkIdentifier) and (AAllowOwnedStringReturn) then
    Exit(True);
  if ANode.NodeKind = gnkStringLiteral then
    Exit(True);
  if AAllowOwnedStringReturn and (ANode.NodeKind = gnkBinaryExpression) and
    (ANode.Text = '+') and ConcatTreeHasSupportedOwnedStringReturn(ANode) and
    CanEmitStrConcatOperand(ANode) then
    Exit(True);
  if AAllowOwnedStringReturn and
    IsSupportedOwnedStringReturnCompareOperand(ANode, SourceName) then
    Exit(True);
  { LowerCase/UpperCase are safe for comparisons even when overloaded }
  if AAllowOwnedStringReturn and (ANode.NodeKind = gnkFunctionCall) and
    (ANode.ChildCount >= 2) and (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (SameText(ANode.ChildAt(0).Text, 'LowerCase') or
     SameText(ANode.ChildAt(0).Text, 'UpperCase')) then
    Exit(True);
  { Any function call returning a string is safe as a compare operand —
    temporaries live for the entire comparison evaluation. This covers
    imported functions like Trim, Copy, etc. that are not registered as
    owned string return functions but still create safe temporaries. }
  if AAllowOwnedStringReturn and (ANode.NodeKind = gnkFunctionCall) and
    FunctionCallReturnsString(ANode) then
    Exit(True);
end;

function TSemanticAnalyzer.EmitStrCompareOperand(const ANode: TGreenNode;
  const AAllowOwnedStringReturn: Boolean; out ABlob: string): Boolean;
var
  LeftName, RightName, SourceName, TempName: string;
begin
  ABlob := '';
  Result := False;
  if ANode = nil then
    Exit;
  if (ANode.NodeKind = gnkIdentifier) and IsRuntimeStrVar(ANode.Text) then
  begin
    ABlob := 'strvar ' + ANode.Text + #10;
    Exit(True);
  end;
  if ANode.NodeKind = gnkStringLiteral then
  begin
    ABlob := 'strlit ' + ANode.Text + #10;
    Exit(True);
  end;
  if AAllowOwnedStringReturn and (ANode.NodeKind = gnkBinaryExpression) and
    (ANode.Text = '+') and (ANode.ChildCount >= 2) and
    ConcatTreeHasSupportedOwnedStringReturn(ANode) and
    CanEmitStrConcatOperand(ANode) then
  begin
    LeftName := EmitStrConcatOperand(ANode.ChildAt(0), '');
    RightName := EmitStrConcatOperand(ANode.ChildAt(1), '');
    if (LeftName = '') or (RightName = '') then
      Exit(False);
    Inc(FBlockLabelCounter);
    TempName := '$str_cmp_cat_tmp_' + IntToStr(FBlockLabelCounter);
    RegisterRuntimeVar(TempName);
    RegisterRuntimeStrVar(TempName);
    FModel.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0,
      TempName);
    FModel.AddTypedHirNode('assign-tstring-concat-runtime', TempName, 0, 0,
      LeftName + #9 + RightName);
    QueuePendingStringTempRelease(TempName, TempName);
    ABlob := 'strvar ' + TempName + #10;
    Exit(True);
  end;
  if AAllowOwnedStringReturn and
    IsSupportedOwnedStringReturnCompareOperand(ANode, SourceName) then
  begin
    Inc(FBlockLabelCounter);
    TempName := '$str_cmp_tmp_' + IntToStr(FBlockLabelCounter);
    RegisterRuntimeVar(TempName);
    RegisterRuntimeStrVar(TempName);
    FModel.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0,
      TempName);
    FModel.AddTypedHirNode('string-temp-owned-runtime', SourceName, 0, 0,
      TempName + #9 + 'callee ' + SourceName + #9 +
      'ptr len owner alloc_size');
    QueuePendingStringTempRelease(TempName, SourceName);
    ABlob := 'strvar ' + TempName + #10;
    Exit(True);
  end;
end;

function TSemanticAnalyzer.EncodeStrCallArgs(const ACallNode: TGreenNode;
  const ADestVar: string): string;
var
  ArgIndex: LongInt;
  ArgNode: TGreenNode;
  Blob, LitValue, SourceName, TempName: string;
begin
  Result := '';
  ArgIndex := 0;
  if ACallNode.NodeKind = gnkFunctionCall then
    ArgIndex := 1;
  ClearPendingStringTempReleases;
  while ArgIndex < ACallNode.ChildCount do
  begin
    ArgNode := ACallNode.ChildAt(ArgIndex);
    if ArgNode = nil then
    begin
      Inc(ArgIndex);
      Continue;
    end;
    if (ArgNode.NodeKind = gnkIdentifier) and IsRuntimeStrVar(ArgNode.Text) then
      Blob := 'strvar ' + ArgNode.Text + #10
    else if IsSupportedOwnedStringReturnArgument(ACallNode, ArgNode,
      ArgIndex - 1) and StringReturnFunctionNameFromNode(ArgNode, SourceName) then
    begin
      Inc(FBlockLabelCounter);
      TempName := '$str_arg_tmp_' + IntToStr(FBlockLabelCounter);
      RegisterRuntimeVar(TempName);
      RegisterRuntimeStrVar(TempName);
      FModel.AddTypedHirNode('var-decl-tstring-runtime', TempName,
        0, 0, TempName);
      FModel.AddTypedHirNode('string-temp-owned-runtime', SourceName,
        0, 0, TempName + #9 + 'callee ' + SourceName + #9 +
        'ptr len owner alloc_size');
      FModel.AddTypedHirNode('string-temp-borrow-arg-runtime',
        ACallNode.Text, 0, 0, 'strvar ' + TempName + #10);
      QueuePendingStringTempRelease(TempName, SourceName);
      Blob := 'strvar ' + TempName + #10;
    end
    else if ArgNode.NodeKind = gnkStringLiteral then
    begin
      LitValue := DecodePascalStringLiteral(ArgNode.Text);
      Blob := EmitStrConcatOperand(ArgNode, ADestVar);
      if Blob <> '' then
        Blob := 'strvar ' + Blob + #10
      else
        Blob := '';
    end
    else if EncodeRuntimeIntExprFold(ArgNode, Blob) then
      { Blob already set }
    else
      Blob := '';
    if Blob <> '' then
    begin
      if Result <> '' then
        Result := Result + #9 + Blob
      else
        Result := Blob;
    end;
    Inc(ArgIndex);
  end;
end;

function TSemanticAnalyzer.EncodeCallStatementArgs(
  const ACallName: string; const ACallNode, ADeclNode: TGreenNode): string;
var
  ArgIndex, ParamIndex: LongInt;
  ArgNode: TGreenNode;
  Decoded, SourceName, TempName: string;
begin
  Result := ACallName;
  ClearPendingStringTempReleases;
  if ACallNode = nil then
    Exit;
  if ACallNode.NodeKind = gnkFunctionCall then
    ArgIndex := 1
  else
    ArgIndex := 0;
  ParamIndex := 0;
  while ArgIndex < ACallNode.ChildCount do
  begin
    ArgNode := ACallNode.ChildAt(ArgIndex);
    if (ArgNode <> nil) and (ArgNode.NodeKind = gnkIdentifier) and
      IsVarParamAtPosition(ADeclNode, ParamIndex) and
      IsRuntimeVar(ArgNode.Text) then
      Result := Result + #9 + 'varref ' + ArgNode.Text + #10
    else if (ArgNode <> nil) and (ArgNode.NodeKind = gnkIdentifier) and
      IsRuntimeStrVar(ArgNode.Text) then
      Result := Result + #9 + 'strvar ' + ArgNode.Text + #10
    else if (ArgNode <> nil) and IsSupportedOwnedStringReturnArgument(
      ACallNode, ArgNode, ParamIndex) and
      StringReturnFunctionNameFromNode(ArgNode, SourceName) then
    begin
      Inc(FBlockLabelCounter);
      TempName := '$str_arg_tmp_' + IntToStr(FBlockLabelCounter);
      RegisterRuntimeVar(TempName);
      RegisterRuntimeStrVar(TempName);
      FModel.AddTypedHirNode('var-decl-tstring-runtime', TempName,
        0, 0, TempName);
      FModel.AddTypedHirNode('string-temp-owned-runtime', SourceName,
        0, 0, TempName + #9 + 'callee ' + SourceName + #9 +
        'ptr len owner alloc_size');
      FModel.AddTypedHirNode('string-temp-borrow-arg-runtime',
        ACallName, 0, 0, 'strvar ' + TempName + #10);
      QueuePendingStringTempRelease(TempName, SourceName);
      Result := Result + #9 + 'strvar ' + TempName + #10;
    end
    else if (ArgNode <> nil) and (ArgNode.NodeKind = gnkStringLiteral) then
      Result := Result + #9 + 'strlit ' + ArgNode.Text + #10
    else if (ArgNode <> nil) and EncodeRuntimeIntExprFold(ArgNode, Decoded) then
      Result := Result + #9 + Decoded;
    Inc(ArgIndex);
    Inc(ParamIndex);
  end;
end;

procedure TSemanticAnalyzer.EmitBlockLabel(const ALabel: string);
begin
  FModel.AddTypedHirNode('block-label-runtime', ALabel, 0, 0, ALabel);
  FCurrentBlockTerminated := False;
end;

procedure TSemanticAnalyzer.EmitGotoLabel(const ALabel: string);
begin
  if FCurrentBlockTerminated then
    Exit;
  FModel.AddTypedHirNode('br-runtime', ALabel, 0, 0, ALabel);
  FCurrentBlockTerminated := True;
end;

