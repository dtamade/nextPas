function TSemanticModel.FindSymbolInScope(const AName: string;
  const AScopeId: LongInt): LongInt;
var
  I: LongInt;
begin
  for I := 0 to Length(FSymbols) - 1 do
    if (FSymbols[I].ScopeId = AScopeId) and
      SameText(FSymbols[I].Name, AName) then
      Exit(FSymbols[I].SymbolId);
  Result := 0;
end;

function TSemanticModel.LookupSymbol(const AName: string;
  const AStartScopeId: LongInt): LongInt;
var
  CurrentScope: LongInt;
  Idx: LongInt;
begin
  CurrentScope := AStartScopeId;
  while CurrentScope > 0 do
  begin
    Result := FindSymbolInScope(AName, CurrentScope);
    if Result > 0 then
      Exit;
    Idx := CurrentScope - 1;
    if (Idx >= 0) and (Idx < Length(FScopes)) then
      CurrentScope := FScopes[Idx].ParentScopeId
    else
      CurrentScope := 0;
  end;
  for Idx := 0 to Length(FSymbols) - 1 do
    if (FSymbols[Idx].ScopeId = 0) and
      SameText(FSymbols[Idx].Name, AName) then
      Exit(FSymbols[Idx].SymbolId);
  Result := 0;
end;

function TSemanticModel.LookupSymbolWithImports(const AName: string;
  const AStartScopeId: LongInt): LongInt;
var
  Idx: LongInt;
begin
  Result := LookupSymbol(AName, AStartScopeId);
  if Result > 0 then
    Exit;
  for Idx := 0 to Length(FScopes) - 1 do
    if (FScopes[Idx].Kind = skUnit) and (FScopes[Idx].ParentScopeId = 1) then
    begin
      Result := FindSymbolInScope(AName, FScopes[Idx].ScopeId);
      if Result > 0 then
        Exit;
    end;
end;

function TSemanticModel.ScopeAt(const AIndex: LongInt): TSemanticScope;
begin
  if (AIndex >= 0) and (AIndex < Length(FScopes)) then
    Result := FScopes[AIndex]
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
  NextIndex: SizeInt;
begin
  NextIndex := Length(FTypedHirNodes);
  SetLength(FTypedHirNodes, NextIndex + 1);
  FTypedHirNodes[NextIndex].HirNodeId := NextIndex + 1;
  FTypedHirNodes[NextIndex].Kind := AKind;
  FTypedHirNodes[NextIndex].NodeKind := ParseHirNodeKind(AKind);
  FTypedHirNodes[NextIndex].DisplayName := ADisplayName;
  FTypedHirNodes[NextIndex].SymbolId := ASymbolId;
  FTypedHirNodes[NextIndex].TypeId := ATypeId;
  FTypedHirNodes[NextIndex].Operand := AOperand;
  FTypedHirNodes[NextIndex].ExprId := 0;
  FTypedHirNodes[NextIndex].TargetExprId := 0;
  FTypedHirNodes[NextIndex].GreenNodeRef := NilGreenNode;
  Result := FTypedHirNodes[NextIndex].HirNodeId;
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
  NextIndex: SizeInt;
  I: LongInt;
begin
  NextIndex := Length(FHirExprs);
  SetLength(FHirExprs, NextIndex + 1);
  FHirExprs[NextIndex].ExprId := NextIndex + 1;
  FHirExprs[NextIndex].Kind := AKind;
  FHirExprs[NextIndex].TypeId := ATypeId;
  FHirExprs[NextIndex].SymbolId := ASymbolId;
  SetLength(FHirExprs[NextIndex].Children, Length(AChildren));
  for I := 0 to High(AChildren) do
    FHirExprs[NextIndex].Children[I] := AChildren[I];
  FHirExprs[NextIndex].LiteralInt := ALiteralInt;
  FHirExprs[NextIndex].LiteralStr := ALiteralStr;
  FHirExprs[NextIndex].Op := AOp;
  FHirExprs[NextIndex].SourceOffset := ASourceOffset;
  FHirExprs[NextIndex].ValueClass := AValueClass;
  Result := FHirExprs[NextIndex].ExprId;
end;

procedure TSemanticModel.SetTypedHirNodeExprId(const AHirNodeId: LongInt;
  const AExprId: LongInt);
var
  Idx: LongInt;
begin
  Idx := AHirNodeId - 1;
  if (Idx < 0) or (Idx >= Length(FTypedHirNodes)) then
    Exit;
  if (AExprId < 0) or (AExprId > Length(FHirExprs)) then
    Exit;
  FTypedHirNodes[Idx].ExprId := AExprId;
end;

procedure TSemanticModel.SetTypedHirNodeTargetExprId(
  const AHirNodeId: LongInt; const AExprId: LongInt);
var
  Idx: LongInt;
begin
  Idx := AHirNodeId - 1;
  if (Idx < 0) or (Idx >= Length(FTypedHirNodes)) then
    Exit;
  if (AExprId < 0) or (AExprId > Length(FHirExprs)) then
    Exit;
  FTypedHirNodes[Idx].TargetExprId := AExprId;
end;

procedure TSemanticModel.SetTypedHirNodeGreenRef(
  const AHirNodeId: LongInt; const AGreenNode: TGreenNode);
var
  Idx: LongInt;
begin
  Idx := AHirNodeId - 1;
  if (Idx < 0) or (Idx >= Length(FTypedHirNodes)) then
    Exit;
  FTypedHirNodes[Idx].GreenNodeRef := AGreenNode;
end;

procedure TSemanticModel.SetTypedHirNodeIsThreadVar(
  const AHirNodeId: LongInt; const AIsThreadVar: Boolean);
var
  Idx: LongInt;
begin
  Idx := AHirNodeId - 1;
  if (Idx < 0) or (Idx >= Length(FTypedHirNodes)) then
    Exit;
  FTypedHirNodes[Idx].IsThreadVar := AIsThreadVar;
end;

function TSemanticModel.AddBinding(
  const AKind: string;
  const AName: string;
  const AOwnerUnitId: string;
  const AByteOffset: LongInt;
  const ATargetSymbolId: LongInt
): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FBindings);
  SetLength(FBindings, NextIndex + 1);
  FBindings[NextIndex].BindingId := NextIndex + 1;
  FBindings[NextIndex].Kind := AKind;
  FBindings[NextIndex].Name := AName;
  FBindings[NextIndex].OwnerUnitId := AOwnerUnitId;
  FBindings[NextIndex].ByteOffset := AByteOffset;
  FBindings[NextIndex].TargetSymbolId := ATargetSymbolId;
  Result := FBindings[NextIndex].BindingId;
end;

function TSemanticModel.AddRuntimeContract(const AName: string): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FRuntimeContracts);
  SetLength(FRuntimeContracts, NextIndex + 1);
  FRuntimeContracts[NextIndex].ContractId := NextIndex + 1;
  FRuntimeContracts[NextIndex].Name := AName;
  Result := FRuntimeContracts[NextIndex].ContractId;
end;

function TSemanticModel.AddForeignProcedureBinding(
  const APascalName: string;
  const ACallingConvention: string;
  const ALibraryId: string;
  const AExternalSymbolName: string;
  const ASymbolId: LongInt
): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FForeignProcedureBindings);
  SetLength(FForeignProcedureBindings, NextIndex + 1);
  FForeignProcedureBindings[NextIndex].BindingId := NextIndex + 1;
  FForeignProcedureBindings[NextIndex].PascalName := APascalName;
  FForeignProcedureBindings[NextIndex].CallingConvention := ACallingConvention;
  FForeignProcedureBindings[NextIndex].LibraryId := ALibraryId;
  FForeignProcedureBindings[NextIndex].ExternalSymbolName := AExternalSymbolName;
  FForeignProcedureBindings[NextIndex].SymbolId := ASymbolId;
  Result := FForeignProcedureBindings[NextIndex].BindingId;
end;

function TSemanticModel.AddLibraryRequest(
  const ALogicalId: string;
  const ALinkageKind: string;
  const AStrength: string
): LongInt;
var
  Index: LongInt;
  NextIndex: SizeInt;
begin
  for Index := 0 to Length(FLibraryRequests) - 1 do
    if SameText(FLibraryRequests[Index].LogicalId, ALogicalId) and
      SameText(FLibraryRequests[Index].LinkageKind, ALinkageKind) and
      SameText(FLibraryRequests[Index].Strength, AStrength) then
      Exit(FLibraryRequests[Index].RequestId);

  NextIndex := Length(FLibraryRequests);
  SetLength(FLibraryRequests, NextIndex + 1);
  FLibraryRequests[NextIndex].RequestId := NextIndex + 1;
  FLibraryRequests[NextIndex].LogicalId := ALogicalId;
  FLibraryRequests[NextIndex].LinkageKind := ALinkageKind;
  FLibraryRequests[NextIndex].Strength := AStrength;
  Result := FLibraryRequests[NextIndex].RequestId;
end;

