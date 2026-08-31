function TSemanticModel.FindSymbolInScope(const AName: string;
  const AScopeId: LongInt): LongInt;
var
  SymbolId: LongInt;
begin
  { Name-chain O(overloads), not O(all symbols). Chain is newest→oldest;
    overwrite so final hit matches old ascending-index first-match (oldest). }
  Result := 0;
  if AName = '' then
    Exit;
  SymbolId := FirstSymbolIdByName(AName);
  while SymbolId > 0 do
  begin
    if FSymbols[SizeUInt(SymbolId - 1)].ScopeId = AScopeId then
      Result := SymbolId;
    SymbolId := NextSymbolIdSameName(SymbolId);
  end;
end;

function TSemanticModel.LookupSymbol(const AName: string;
  const AStartScopeId: LongInt): LongInt;
var
  CurrentScope: LongInt;
  Idx: LongInt;
  SymbolId: LongInt;
begin
  CurrentScope := AStartScopeId;
  while CurrentScope > 0 do
  begin
    Result := FindSymbolInScope(AName, CurrentScope);
    if Result > 0 then
      Exit;
    Idx := CurrentScope - 1;
    if (Idx >= 0) and (Idx < LongInt(FScopes.Count)) then
      CurrentScope := FScopes[SizeUInt(Idx)].ParentScopeId
    else
      CurrentScope := 0;
  end;
  { ScopeId=0 fallback: same name-chain, oldest-wins. }
  Result := 0;
  if AName = '' then
    Exit;
  SymbolId := FirstSymbolIdByName(AName);
  while SymbolId > 0 do
  begin
    if FSymbols[SizeUInt(SymbolId - 1)].ScopeId = 0 then
      Result := SymbolId;
    SymbolId := NextSymbolIdSameName(SymbolId);
  end;
end;

function TSemanticModel.LookupSymbolWithImports(const AName: string;
  const AStartScopeId: LongInt): LongInt;
var
  Idx: LongInt;
begin
  Result := LookupSymbol(AName, AStartScopeId);
  if Result > 0 then
    Exit;
  for Idx := 0 to LongInt(FScopes.Count) - 1 do
    if (FScopes[SizeUInt(Idx)].Kind = skUnit) and
      (FScopes[SizeUInt(Idx)].ParentScopeId = 1) then
    begin
      Result := FindSymbolInScope(AName, FScopes[SizeUInt(Idx)].ScopeId);
      if Result > 0 then
        Exit;
    end;
end;

function TSemanticModel.ScopeAt(const AIndex: LongInt): TSemanticScope;
begin
  if (AIndex >= 0) and (AIndex < LongInt(FScopes.Count)) then
    Result := FScopes[SizeUInt(AIndex)]
  else
  begin
    Result.ScopeId := 0;
    Result.Kind := skCompilation;
    Result.Name := '';
    Result.ParentScopeId := 0;
  end;
end;

function TSemanticModel.AddTypedHirNode(
  const AKind: string;
  const ADisplayName: string;
  const ASymbolId: LongInt;
  const ATypeId: LongInt;
  const AOperand: string
): LongInt;
var
  Entry: TTypedHirNode;
begin
  Entry := Default(TTypedHirNode);
  Entry.HirNodeId := LongInt(FTypedHirNodes.Count) + 1;
  Entry.Kind := AKind;
  Entry.NodeKind := ParseHirNodeKind(AKind);
  Entry.DisplayName := ADisplayName;
  Entry.SymbolId := ASymbolId;
  Entry.TypeId := ATypeId;
  Entry.Operand := AOperand;
  Entry.ExprId := 0;
  Entry.TargetExprId := 0;
  Entry.GreenNodeRef := NilGreenNode;
  FTypedHirNodes.Push(Entry);
  Result := Entry.HirNodeId;
end;

function TSemanticModel.AddHirExpr(
  const AKind: TSemanticHirExprKind;
  const ATypeId: LongInt;
  const ASymbolId: LongInt;
  const AChildren: array of LongInt;
  const ALiteralInt: Int64;
  const ALiteralFloat: Double;
  const ALiteralStr: string;
  const AOp: string;
  const ASourceOffset: LongInt;
  const AValueClass: TSemanticHirValueClass
): LongInt;
var
  Entry: TSemanticHirExpr;
  I: LongInt;
begin
  Entry := Default(TSemanticHirExpr);
  Entry.ExprId := LongInt(FHirExprs.Count) + 1;
  Entry.Kind := AKind;
  Entry.TypeId := ATypeId;
  Entry.SymbolId := ASymbolId;
  Entry.Children := nil;
  if Length(AChildren) > 0 then
  begin
    Entry.Children := TSemanticHirChildVec.Create(SizeUInt(Length(AChildren)));
    for I := 0 to High(AChildren) do
      Entry.Children.Push(AChildren[I]);
  end;
  Entry.LiteralInt := ALiteralInt;
  Entry.LiteralStr := ALiteralStr;
  Entry.Op := AOp;
  Entry.SourceOffset := ASourceOffset;
  Entry.ValueClass := AValueClass;
  FHirExprs.Push(Entry);
  Result := Entry.ExprId;
end;

procedure TSemanticModel.SetTypedHirNodeExprId(const AHirNodeId: LongInt;
  const AExprId: LongInt);
var
  Idx: LongInt;
begin
  Idx := AHirNodeId - 1;
  if (Idx < 0) or (Idx >= LongInt(FTypedHirNodes.Count)) then
    Exit;
  if (AExprId < 0) or (AExprId > LongInt(FHirExprs.Count)) then
    Exit;
  FTypedHirNodes.GetPtr(SizeUInt(Idx))^.ExprId := AExprId;
end;

procedure TSemanticModel.SetTypedHirNodeTargetExprId(
  const AHirNodeId: LongInt; const AExprId: LongInt);
var
  Idx: LongInt;
begin
  Idx := AHirNodeId - 1;
  if (Idx < 0) or (Idx >= LongInt(FTypedHirNodes.Count)) then
    Exit;
  if (AExprId < 0) or (AExprId > LongInt(FHirExprs.Count)) then
    Exit;
  FTypedHirNodes.GetPtr(SizeUInt(Idx))^.TargetExprId := AExprId;
end;

procedure TSemanticModel.SetTypedHirNodeGreenRef(
  const AHirNodeId: LongInt; const AGreenNode: TGreenNode);
var
  Idx: LongInt;
begin
  Idx := AHirNodeId - 1;
  if (Idx < 0) or (Idx >= LongInt(FTypedHirNodes.Count)) then
    Exit;
  FTypedHirNodes.GetPtr(SizeUInt(Idx))^.GreenNodeRef := AGreenNode;
end;

procedure TSemanticModel.SetTypedHirNodeIsThreadVar(
  const AHirNodeId: LongInt; const AIsThreadVar: Boolean);
var
  Idx: LongInt;
begin
  Idx := AHirNodeId - 1;
  if (Idx < 0) or (Idx >= LongInt(FTypedHirNodes.Count)) then
    Exit;
  FTypedHirNodes.GetPtr(SizeUInt(Idx))^.IsThreadVar := AIsThreadVar;
end;

function TSemanticModel.AddBinding(
  const AKind: string;
  const AName: string;
  const AOwnerUnitId: string;
  const AByteOffset: LongInt;
  const ATargetSymbolId: LongInt
): LongInt;
var
  Entry: TSemanticBinding;
begin
  Entry := Default(TSemanticBinding);
  Entry.BindingId := LongInt(FBindings.Count) + 1;
  Entry.Kind := AKind;
  Entry.Name := AName;
  Entry.OwnerUnitId := AOwnerUnitId;
  Entry.ByteOffset := AByteOffset;
  Entry.TargetSymbolId := ATargetSymbolId;
  FBindings.Push(Entry);
  Result := Entry.BindingId;
end;

function TSemanticModel.AddRuntimeContract(const AName: string): LongInt;
var
  Entry: TRuntimeContract;
begin
  Entry := Default(TRuntimeContract);
  Entry.ContractId := LongInt(FRuntimeContracts.Count) + 1;
  Entry.Name := AName;
  FRuntimeContracts.Push(Entry);
  Result := Entry.ContractId;
end;

function TSemanticModel.AddForeignProcedureBinding(
  const APascalName: string;
  const ACallingConvention: string;
  const ALibraryId: string;
  const AExternalSymbolName: string;
  const ASymbolId: LongInt
): LongInt;
var
  Entry: TSemanticForeignProcedureBinding;
begin
  Entry := Default(TSemanticForeignProcedureBinding);
  Entry.BindingId := LongInt(FForeignProcedureBindings.Count) + 1;
  Entry.PascalName := APascalName;
  Entry.CallingConvention := ACallingConvention;
  Entry.LibraryId := ALibraryId;
  Entry.ExternalSymbolName := AExternalSymbolName;
  Entry.SymbolId := ASymbolId;
  FForeignProcedureBindings.Push(Entry);
  Result := Entry.BindingId;
end;

function TSemanticModel.AddLibraryRequest(
  const ALogicalId: string;
  const ALinkageKind: string;
  const AStrength: string
): LongInt;
var
  Index: LongInt;
  Entry: TSemanticLibraryRequest;
begin
  for Index := 0 to LongInt(FLibraryRequests.Count) - 1 do
    if SameText(FLibraryRequests[SizeUInt(Index)].LogicalId, ALogicalId) and
      SameText(FLibraryRequests[SizeUInt(Index)].LinkageKind, ALinkageKind) and
      SameText(FLibraryRequests[SizeUInt(Index)].Strength, AStrength) then
      Exit(FLibraryRequests[SizeUInt(Index)].RequestId);

  Entry := Default(TSemanticLibraryRequest);
  Entry.RequestId := LongInt(FLibraryRequests.Count) + 1;
  Entry.LogicalId := ALogicalId;
  Entry.LinkageKind := ALinkageKind;
  Entry.Strength := AStrength;
  FLibraryRequests.Push(Entry);
  Result := Entry.RequestId;
end;
