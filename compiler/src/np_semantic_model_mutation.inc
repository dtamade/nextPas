function TSemanticModel.FindTypeScalarFactIndex(
  const ATypeId: LongInt
): LongInt;
var
  I: LongInt;
begin
  for I := 0 to LongInt(FTypeScalarFacts.Count) - 1 do
    if FTypeScalarFacts[SizeUInt(I)].TypeId = ATypeId then
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
  Entry: TSemanticSymbol;
  Key: string;
  PrevHead: LongInt;
begin
  Entry := Default(TSemanticSymbol);
  Entry.SymbolId := LongInt(FSymbols.Count) + 1;
  Entry.Name := AName;
  Entry.Kind := AKind;
  Entry.OwnerUnitId := AOwnerUnitId;
  Entry.ScopeId := 0;
  Entry.TypeId := ATypeId;
  Entry.ParamCount := -1;
  Entry.ParamSignature := '';
  Entry.ByteOffset := AByteOffset;
  Entry.NextSameNameId := 0;
  Key := LowerCase(AName);
  if FSymbolNameIndex.TryGetValue(Key, PrevHead) then
    Entry.NextSameNameId := PrevHead;
  FSymbols.Push(Entry);
  Result := Entry.SymbolId;
  { Newest head — FindSymbolByName keeps last-wins semantics. }
  FSymbolNameIndex.Put(Key, Result);
end;

function TSemanticModel.AddType(
  const AName: string;
  const AKind: string
): LongInt;
var
  Entry: TSemanticType;
  PrevId: LongInt;
  Fact: TSemanticScalarTypeFact;
  PrevMeta, NewMeta: TTypeMetadata;
begin
  { Last-wins name index: unit redefines (PtrUInt=UInt64 etc.) must not drop
    builtin scalar/layout facts used by SizeOf/High/Low fold. }
  PrevId := 0;
  if not FTypeNameIndex.TryGetValue(LowerCase(AName), PrevId) then
    PrevId := 0;
  Entry := Default(TSemanticType);
  Entry.TypeId := LongInt(FTypes.Count) + 1;
  Entry.Name := AName;
  Entry.Kind := AKind;
  Entry.ParentTypeId := 0;
  if (PrevId > 0) and (PrevId <= LongInt(FTypes.Count)) then
    Entry.ParentTypeId := FTypes.GetPtr(SizeUInt(PrevId - 1))^.ParentTypeId;
  FTypes.Push(Entry);
  Result := Entry.TypeId;
  FTypeNameIndex.Put(LowerCase(AName), Result);
  if (PrevId > 0) and GetTypeScalarFact(PrevId, Fact) then
    SetTypeScalarFact(Result, Fact.Kind, Fact.BitWidth, Fact.Signed);
  if (PrevId > 0) and GetTypeMeta(PrevId, PrevMeta) and (PrevMeta.Size > 0) then
  begin
    if not GetTypeMeta(Result, NewMeta) then
    begin
      FillChar(NewMeta, SizeOf(NewMeta), 0);
      NewMeta.TypeId := Result;
    end;
    if NewMeta.Size <= 0 then
      NewMeta.Size := PrevMeta.Size;
    if NewMeta.AliasTargetTypeId <= 0 then
      NewMeta.AliasTargetTypeId := PrevMeta.AliasTargetTypeId;
    if (not NewMeta.IsRecord) and PrevMeta.IsRecord then
      NewMeta.IsRecord := True;
    SetTypeMeta(Result, NewMeta);
  end;
end;

procedure TSemanticModel.SetTypeKind(const ATypeId: LongInt;
  const AKind: string);
var
  Idx: LongInt;
begin
  Idx := ATypeId - 1;
  if (Idx >= 0) and (Idx < LongInt(FTypes.Count)) then
    FTypes.GetPtr(SizeUInt(Idx))^.Kind := AKind;
end;

procedure TSemanticModel.SetTypeScalarFact(const ATypeId: LongInt;
  const AKind: TSemanticScalarKind; const ABitWidth: LongInt;
  const ASigned: Boolean);
var
  Idx: LongInt;
  Fact: TSemanticScalarTypeFact;
  P: PSemanticScalarTypeFact;
begin
  if (ATypeId <= 0) or (ATypeId > LongInt(FTypes.Count)) then
    Exit;
  if AKind = sskNone then
    Exit;
  if ABitWidth <= 0 then
    Exit;

  Idx := FindTypeScalarFactIndex(ATypeId);
  if Idx < 0 then
  begin
    Fact := Default(TSemanticScalarTypeFact);
    FTypeScalarFacts.Push(Fact);
    Idx := LongInt(FTypeScalarFacts.Count) - 1;
  end;

  P := FTypeScalarFacts.GetPtr(SizeUInt(Idx));
  P^.TypeId := ATypeId;
  P^.Kind := AKind;
  P^.BitWidth := ABitWidth;
  P^.Signed := ASigned;
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

  AFact := FTypeScalarFacts[SizeUInt(Idx)];
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
  if (Idx >= 0) and (Idx < LongInt(FTypes.Count)) then
    FTypes.GetPtr(SizeUInt(Idx))^.OwnerUnitId := AOwnerUnitId;
end;

procedure TSemanticModel.SetTypeParent(const ATypeId: LongInt;
  const AParentTypeId: LongInt);
var
  CurrentTypeId: LongInt;
  Depth: LongInt;
  Idx: LongInt;
begin
  Idx := ATypeId - 1;
  if (Idx < 0) or (Idx >= LongInt(FTypes.Count)) then
    Exit;

  CurrentTypeId := AParentTypeId;
  Depth := 0;
  while CurrentTypeId <> 0 do
  begin
    if (CurrentTypeId < 1) or (CurrentTypeId > LongInt(FTypes.Count)) then
      Exit;
    if CurrentTypeId = ATypeId then
      Exit;
    if Depth >= LongInt(FTypes.Count) then
      Exit;
    CurrentTypeId := FTypes[SizeUInt(CurrentTypeId - 1)].ParentTypeId;
    Inc(Depth);
  end;

  FTypes.GetPtr(SizeUInt(Idx))^.ParentTypeId := AParentTypeId;
end;

procedure TSemanticModel.SetTypeAliasTarget(const ATypeId: LongInt;
  const ATargetTypeId: LongInt);
var
  I: LongInt;
  Entry: TTypeMetadata;
begin
  for I := 0 to LongInt(FTypeMetadataEntries.Count) - 1 do
    if FTypeMetadataEntries[SizeUInt(I)].TypeId = ATypeId then
    begin
      FTypeMetadataEntries.GetPtr(SizeUInt(I))^.AliasTargetTypeId := ATargetTypeId;
      Exit;
    end;
  Entry := Default(TTypeMetadata);
  Entry.TypeId := ATypeId;
  Entry.AliasTargetTypeId := ATargetTypeId;
  FTypeMetadataEntries.Push(Entry);
end;

procedure TSemanticModel.SetTypeGenericParent(const ATypeId: LongInt;
  const ATemplateTypeId: LongInt; const AArgIndices: array of LongInt);
var
  Idx, I: LongInt;
  Ty: PSemanticType;
begin
  Idx := ATypeId - 1;
  if (Idx >= 0) and (Idx < LongInt(FTypes.Count)) then
  begin
    Ty := FTypes.GetPtr(SizeUInt(Idx));
    Ty^.GenericParent.TemplateTypeId := ATemplateTypeId;
    SetLength(Ty^.GenericParent.ArgIndices, Length(AArgIndices));
    for I := 0 to High(AArgIndices) do
      Ty^.GenericParent.ArgIndices[I] := AArgIndices[I];
  end;
end;

procedure TSemanticModel.SetTypeParams(const ATypeId: LongInt;
  const AParamListNode: TGreenNode);
var
  Idx, I, ColonPos: LongInt;
  Params, Constraints, ParamText, ParamName, Constraint: string;
  Ty: PSemanticType;
begin
  Idx := ATypeId - 1;
  if (Idx < 0) or (Idx >= LongInt(FTypes.Count)) then
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
  Ty := FTypes.GetPtr(SizeUInt(Idx));
  Ty^.TypeParams := Params;
  Ty^.TypeConstraints := Constraints;
end;

procedure TSemanticModel.SetTypeInstantiatedFrom(const ATypeId: LongInt;
  const AFromTypeId: LongInt);
var
  Idx: LongInt;
begin
  Idx := ATypeId - 1;
  if (Idx >= 0) and (Idx < LongInt(FTypes.Count)) then
    FTypes.GetPtr(SizeUInt(Idx))^.InstantiatedFrom := AFromTypeId;
end;

procedure TSemanticModel.AppendTypeConstraint(const ATypeId: LongInt;
  const AParamName: string; const AConstraint: string);
var
  Idx, ParamIdx, CommaCount: LongInt;
  Params: string;
  Parts: TStringVec;
  I, J: LongInt;
  Ty: PSemanticType;
begin
  Idx := ATypeId - 1;
  if (Idx < 0) or (Idx >= LongInt(FTypes.Count)) then
    Exit;
  Ty := FTypes.GetPtr(SizeUInt(Idx));
  Params := Ty^.TypeParams;
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
  while I <= Length(Ty^.TypeConstraints) do
  begin
    J := I;
    while (J <= Length(Ty^.TypeConstraints)) and
      (Ty^.TypeConstraints[J] <> ',') do
      Inc(J);
    Parts.Push(Copy(Ty^.TypeConstraints, I, J - I));
    I := J + 1;
  end;
  while Parts.Count <= ParamIdx do
    Parts.Push('');
  Parts[ParamIdx] := AConstraint;
  Ty^.TypeConstraints := '';
  for I := 0 to Parts.Count - 1 do
  begin
    if I > 0 then
      Ty^.TypeConstraints := Ty^.TypeConstraints + ',';
    Ty^.TypeConstraints := Ty^.TypeConstraints + Parts[I];
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
    if (Idx < 0) or (Idx >= LongInt(FTypes.Count)) then
      Exit(False);
    Current := FTypes[SizeUInt(Idx)].ParentTypeId;
    if Current = AAncestorTypeId then
      Exit(True);
    Inc(Depth);
  end;
  Result := False;
end;

function TSemanticModel.AddScope(const AKind: TScopeKind;
  const AName: string; const AParentScopeId: LongInt): LongInt;
var
  Entry: TSemanticScope;
begin
  Entry := Default(TSemanticScope);
  Entry.ScopeId := LongInt(FScopes.Count) + 1;
  Entry.Kind := AKind;
  Entry.Name := AName;
  Entry.ParentScopeId := AParentScopeId;
  FScopes.Push(Entry);
  Result := Entry.ScopeId;
end;

function TSemanticModel.ScopeCount: LongInt;
begin
  Result := LongInt(FScopes.Count);
end;

procedure TSemanticModel.SetSymbolScope(const ASymbolId: LongInt;
  const AScopeId: LongInt);
var
  Idx: LongInt;
begin
  Idx := ASymbolId - 1;
  if (Idx >= 0) and (Idx < LongInt(FSymbols.Count)) then
    FSymbols.GetPtr(SizeUInt(Idx))^.ScopeId := AScopeId;
end;

procedure TSemanticModel.SetSymbolTypeId(const ASymbolId: LongInt;
  const ATypeId: LongInt);
var
  Idx: LongInt;
begin
  Idx := ASymbolId - 1;
  if (Idx >= 0) and (Idx < LongInt(FSymbols.Count)) then
    FSymbols.GetPtr(SizeUInt(Idx))^.TypeId := ATypeId;
end;

procedure TSemanticModel.SetSymbolParamCount(const ASymbolId: LongInt;
  const ACount: LongInt);
var
  Idx: LongInt;
begin
  Idx := ASymbolId - 1;
  if (Idx >= 0) and (Idx < LongInt(FSymbols.Count)) then
    FSymbols.GetPtr(SizeUInt(Idx))^.ParamCount := ACount;
end;

procedure TSemanticModel.SetSymbolMinParamCount(const ASymbolId: LongInt;
  const ACount: LongInt);
var
  Idx: LongInt;
begin
  Idx := ASymbolId - 1;
  if (Idx >= 0) and (Idx < LongInt(FSymbols.Count)) then
    FSymbols.GetPtr(SizeUInt(Idx))^.MinParamCount := ACount;
end;

procedure TSemanticModel.SetSymbolVisibility(const ASymbolId: LongInt;
  const AVisibility: string);
var
  Idx: LongInt;
begin
  Idx := ASymbolId - 1;
  if (Idx >= 0) and (Idx < LongInt(FSymbols.Count)) then
    FSymbols.GetPtr(SizeUInt(Idx))^.Visibility := AVisibility;
end;

procedure TSemanticModel.SetSymbolParamSignature(const ASymbolId: LongInt;
  const ASignature: string);
var
  Idx: LongInt;
begin
  Idx := ASymbolId - 1;
  if (Idx >= 0) and (Idx < LongInt(FSymbols.Count)) then
    FSymbols.GetPtr(SizeUInt(Idx))^.ParamSignature := ASignature;
end;

procedure TSemanticModel.SetSymbolReturnTypeId(const ASymbolId: LongInt;
  const AReturnTypeId: LongInt);
var
  Idx: LongInt;
begin
  Idx := ASymbolId - 1;
  if (Idx >= 0) and (Idx < LongInt(FSymbols.Count)) then
    FSymbols.GetPtr(SizeUInt(Idx))^.ReturnTypeId := AReturnTypeId;
end;
