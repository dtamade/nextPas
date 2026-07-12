function TSemanticModel.FindTypeScalarFactIndex(
  const ATypeId: LongInt
): LongInt;
var
  I: LongInt;
begin
  for I := 0 to Length(FTypeScalarFacts) - 1 do
    if FTypeScalarFacts[I].TypeId = ATypeId then
      Exit(I);
  Result := -1;
end;

function TSemanticModel.AddSymbol(
  const AName: string;
  const AKind: string;
  const AOwnerUnitId: string;
  const ATypeId: LongInt;
  const AByteOffset: LongInt
): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FSymbols);
  SetLength(FSymbols, NextIndex + 1);
  FSymbols[NextIndex].SymbolId := NextIndex + 1;
  FSymbols[NextIndex].Name := AName;
  FSymbols[NextIndex].Kind := AKind;
  FSymbols[NextIndex].OwnerUnitId := AOwnerUnitId;
  FSymbols[NextIndex].ScopeId := 0;
  FSymbols[NextIndex].TypeId := ATypeId;
  FSymbols[NextIndex].ParamCount := -1;
  FSymbols[NextIndex].ParamSignature := '';
  FSymbols[NextIndex].ByteOffset := AByteOffset;
  Result := FSymbols[NextIndex].SymbolId;
  // Update O(1) lookup index (case-insensitive)
  FSymbolNameIndex.Put(LowerCase(AName), Result);
end;

function TSemanticModel.AddType(
  const AName: string;
  const AKind: string
): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FTypes);
  SetLength(FTypes, NextIndex + 1);
  FTypes[NextIndex].TypeId := NextIndex + 1;
  FTypes[NextIndex].Name := AName;
  FTypes[NextIndex].Kind := AKind;
  FTypes[NextIndex].ParentTypeId := 0;
  Result := FTypes[NextIndex].TypeId;
  // Update O(1) lookup index (case-insensitive)
  FTypeNameIndex.Put(LowerCase(AName), Result);
end;

procedure TSemanticModel.SetTypeKind(const ATypeId: LongInt;
  const AKind: string);
var
  Idx: LongInt;
begin
  Idx := ATypeId - 1;
  if (Idx >= 0) and (Idx < Length(FTypes)) then
    FTypes[Idx].Kind := AKind;
end;

procedure TSemanticModel.SetTypeScalarFact(const ATypeId: LongInt;
  const AKind: TSemanticScalarKind; const ABitWidth: LongInt;
  const ASigned: Boolean);
var
  Idx: LongInt;
begin
  if (ATypeId <= 0) or (ATypeId > Length(FTypes)) then
    Exit;
  if AKind = sskNone then
    Exit;
  if ABitWidth <= 0 then
    Exit;

  Idx := FindTypeScalarFactIndex(ATypeId);
  if Idx < 0 then
  begin
    Idx := Length(FTypeScalarFacts);
    SetLength(FTypeScalarFacts, Idx + 1);
  end;

  FTypeScalarFacts[Idx].TypeId := ATypeId;
  FTypeScalarFacts[Idx].Kind := AKind;
  FTypeScalarFacts[Idx].BitWidth := ABitWidth;
  FTypeScalarFacts[Idx].Signed := ASigned;
end;

function TSemanticModel.GetTypeScalarFact(const ATypeId: LongInt;
  out AFact: TSemanticScalarTypeFact): Boolean;
var
  Idx: LongInt;
begin
  AFact.TypeId := 0;
  AFact.Kind := sskNone;
  AFact.BitWidth := 0;
  AFact.Signed := False;

  Idx := FindTypeScalarFactIndex(ATypeId);
  if Idx < 0 then
    Exit(False);

  AFact := FTypeScalarFacts[Idx];
  Result := True;
end;

function TSemanticModel.TypeHasScalarFact(const ATypeId: LongInt): Boolean;
var
  Fact: TSemanticScalarTypeFact;
begin
  Result := GetTypeScalarFact(ATypeId, Fact);
end;

procedure TSemanticModel.SetTypeOwner(const ATypeId: LongInt;
  const AOwnerUnitId: string);
var
  Idx: LongInt;
begin
  Idx := ATypeId - 1;
  if (Idx >= 0) and (Idx < Length(FTypes)) then
    FTypes[Idx].OwnerUnitId := AOwnerUnitId;
end;

procedure TSemanticModel.SetTypeParent(const ATypeId: LongInt;
  const AParentTypeId: LongInt);
var
  CurrentTypeId: LongInt;
  Depth: LongInt;
  Idx: LongInt;
begin
  Idx := ATypeId - 1;
  if (Idx < 0) or (Idx >= Length(FTypes)) then
    Exit;

  CurrentTypeId := AParentTypeId;
  Depth := 0;
  while CurrentTypeId <> 0 do
  begin
    if (CurrentTypeId < 1) or (CurrentTypeId > Length(FTypes)) then
      Exit;
    if CurrentTypeId = ATypeId then
      Exit;
    if Depth >= Length(FTypes) then
      Exit;
    CurrentTypeId := FTypes[CurrentTypeId - 1].ParentTypeId;
    Inc(Depth);
  end;

  FTypes[Idx].ParentTypeId := AParentTypeId;
end;

procedure TSemanticModel.SetTypeAliasTarget(const ATypeId: LongInt;
  const ATargetTypeId: LongInt);
var
  I: LongInt;
begin
  for I := 0 to Length(FTypeMetadataEntries) - 1 do
    if FTypeMetadataEntries[I].TypeId = ATypeId then
    begin
      FTypeMetadataEntries[I].AliasTargetTypeId := ATargetTypeId;
      Exit;
    end;
  SetLength(FTypeMetadataEntries, Length(FTypeMetadataEntries) + 1);
  FTypeMetadataEntries[High(FTypeMetadataEntries)].TypeId := ATypeId;
  FTypeMetadataEntries[High(FTypeMetadataEntries)].AliasTargetTypeId := ATargetTypeId;
end;

procedure TSemanticModel.SetTypeGenericParent(const ATypeId: LongInt;
  const ATemplateTypeId: LongInt; const AArgIndices: array of LongInt);
var
  Idx, I: LongInt;
begin
  Idx := ATypeId - 1;
  if (Idx >= 0) and (Idx < Length(FTypes)) then
  begin
    FTypes[Idx].GenericParent.TemplateTypeId := ATemplateTypeId;
    SetLength(FTypes[Idx].GenericParent.ArgIndices, Length(AArgIndices));
    for I := 0 to High(AArgIndices) do
      FTypes[Idx].GenericParent.ArgIndices[I] := AArgIndices[I];
  end;
end;

procedure TSemanticModel.SetTypeParams(const ATypeId: LongInt;
  const AParamListNode: TGreenNode);
var
  Idx, I, ColonPos: LongInt;
  Params, Constraints, ParamText, ParamName, Constraint: string;
begin
  Idx := ATypeId - 1;
  if (Idx < 0) or (Idx >= Length(FTypes)) then
    Exit;
  if AParamListNode = nil then
    Exit;
  Params := '';
  Constraints := '';
  for I := 0 to AParamListNode.ChildCount - 1 do
  begin
    if (AParamListNode.ChildAt(I) <> nil) and
      (AParamListNode.ChildAt(I).NodeKind = gnkIdentifier) then
    begin
      ParamText := AParamListNode.ChildAt(I).Text;
      ColonPos := Pos(':', ParamText);
      if ColonPos > 0 then
      begin
        ParamName := Copy(ParamText, 1, ColonPos - 1);
        Constraint := Copy(ParamText, ColonPos + 1, MaxInt);
      end
      else
      begin
        ParamName := ParamText;
        Constraint := '';
      end;
      if Params <> '' then
      begin
        Params := Params + ',';
        Constraints := Constraints + ',';
      end;
      Params := Params + ParamName;
      Constraints := Constraints + Constraint;
    end;
  end;
  FTypes[Idx].TypeParams := Params;
  FTypes[Idx].TypeConstraints := Constraints;
end;

procedure TSemanticModel.SetTypeInstantiatedFrom(const ATypeId: LongInt;
  const AFromTypeId: LongInt);
var
  Idx: LongInt;
begin
  Idx := ATypeId - 1;
  if (Idx >= 0) and (Idx < Length(FTypes)) then
    FTypes[Idx].InstantiatedFrom := AFromTypeId;
end;

procedure TSemanticModel.AppendTypeConstraint(const ATypeId: LongInt;
  const AParamName: string; const AConstraint: string);
var
  Idx, ParamIdx, CommaCount: LongInt;
  Params: string;
  Parts: TStringVec;
  I, J: LongInt;
begin
  Idx := ATypeId - 1;
  if (Idx < 0) or (Idx >= Length(FTypes)) then
    Exit;
  Params := FTypes[Idx].TypeParams;
  ParamIdx := -1;
  CommaCount := 0;
  I := 1;
  while I <= Length(Params) do
  begin
    J := I;
    while (J <= Length(Params)) and (Params[J] <> ',') do
      Inc(J);
    if SameText(Trim(Copy(Params, I, J - I)), AParamName) then
    begin
      ParamIdx := CommaCount;
      Break;
    end;
    Inc(CommaCount);
    I := J + 1;
  end;
  if ParamIdx < 0 then
    Exit;
  Parts := TStringVec.Create;
  I := 1;
  while I <= Length(FTypes[Idx].TypeConstraints) do
  begin
    J := I;
    while (J <= Length(FTypes[Idx].TypeConstraints)) and
      (FTypes[Idx].TypeConstraints[J] <> ',') do
      Inc(J);
    Parts.Push(Copy(FTypes[Idx].TypeConstraints, I, J - I));
    I := J + 1;
  end;
  while Parts.Count <= ParamIdx do
    Parts.Push('');
  Parts[ParamIdx] := AConstraint;
  FTypes[Idx].TypeConstraints := '';
  for I := 0 to Parts.Count - 1 do
  begin
    if I > 0 then
      FTypes[Idx].TypeConstraints := FTypes[Idx].TypeConstraints + ',';
    FTypes[Idx].TypeConstraints := FTypes[Idx].TypeConstraints + Parts[I];
  end;
  Parts.Free;
end;

function TSemanticModel.IsTypeDescendantOf(const ATypeId: LongInt;
  const AAncestorTypeId: LongInt): Boolean;
var
  Current, Idx: LongInt;
  Depth: LongInt;
begin
  if ATypeId = AAncestorTypeId then
    Exit(True);
  Current := ATypeId;
  Depth := 0;
  while (Current > 0) and (Depth < 32) do
  begin
    Idx := Current - 1;
    if (Idx < 0) or (Idx >= Length(FTypes)) then
      Exit(False);
    Current := FTypes[Idx].ParentTypeId;
    if Current = AAncestorTypeId then
      Exit(True);
    Inc(Depth);
  end;
  Result := False;
end;

function TSemanticModel.AddScope(const AKind: TScopeKind;
  const AName: string; const AParentScopeId: LongInt): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FScopes);
  SetLength(FScopes, NextIndex + 1);
  FScopes[NextIndex].ScopeId := NextIndex + 1;
  FScopes[NextIndex].Kind := AKind;
  FScopes[NextIndex].Name := AName;
  FScopes[NextIndex].ParentScopeId := AParentScopeId;
  Result := FScopes[NextIndex].ScopeId;
end;

function TSemanticModel.ScopeCount: LongInt;
begin
  Result := Length(FScopes);
end;

procedure TSemanticModel.SetSymbolScope(const ASymbolId: LongInt;
  const AScopeId: LongInt);
var
  Idx: LongInt;
begin
  Idx := ASymbolId - 1;
  if (Idx >= 0) and (Idx < Length(FSymbols)) then
    FSymbols[Idx].ScopeId := AScopeId;
end;

procedure TSemanticModel.SetSymbolTypeId(const ASymbolId: LongInt;
  const ATypeId: LongInt);
var
  Idx: LongInt;
begin
  Idx := ASymbolId - 1;
  if (Idx >= 0) and (Idx < Length(FSymbols)) then
    FSymbols[Idx].TypeId := ATypeId;
end;

procedure TSemanticModel.SetSymbolParamCount(const ASymbolId: LongInt;
  const ACount: LongInt);
var
  Idx: LongInt;
begin
  Idx := ASymbolId - 1;
  if (Idx >= 0) and (Idx < Length(FSymbols)) then
    FSymbols[Idx].ParamCount := ACount;
end;

procedure TSemanticModel.SetSymbolMinParamCount(const ASymbolId: LongInt;
  const ACount: LongInt);
var
  Idx: LongInt;
begin
  Idx := ASymbolId - 1;
  if (Idx >= 0) and (Idx < Length(FSymbols)) then
    FSymbols[Idx].MinParamCount := ACount;
end;

procedure TSemanticModel.SetSymbolVisibility(const ASymbolId: LongInt;
  const AVisibility: string);
var
  Idx: LongInt;
begin
  Idx := ASymbolId - 1;
  if (Idx >= 0) and (Idx < Length(FSymbols)) then
    FSymbols[Idx].Visibility := AVisibility;
end;

procedure TSemanticModel.SetSymbolParamSignature(const ASymbolId: LongInt;
  const ASignature: string);
var
  Idx: LongInt;
begin
  Idx := ASymbolId - 1;
  if (Idx >= 0) and (Idx < Length(FSymbols)) then
    FSymbols[Idx].ParamSignature := ASignature;
end;

procedure TSemanticModel.SetSymbolReturnTypeId(const ASymbolId: LongInt;
  const AReturnTypeId: LongInt);
var
  Idx: LongInt;
begin
  Idx := ASymbolId - 1;
  if (Idx >= 0) and (Idx < Length(FSymbols)) then
    FSymbols[Idx].ReturnTypeId := AReturnTypeId;
end;
