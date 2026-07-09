function TSemanticModel.SymbolCount: LongInt;
begin
  Result := Length(FSymbols);
end;

function TSemanticModel.SymbolAt(const AIndex: LongInt): TSemanticSymbol;
begin
  if (AIndex < 0) or (AIndex >= Length(FSymbols)) then
  begin
    Result.SymbolId := 0;
    Result.Name := '';
    Result.Kind := '';
    Result.OwnerUnitId := '';
    Result.TypeId := 0;
    Result.ParamCount := -1;
    Result.ParamSignature := '';
    Result.ByteOffset := 0;
    Exit;
  end;
  Result := FSymbols[AIndex];
end;

function TSemanticModel.FindTypeByName(const AName: string): LongInt;
begin
  // O(1) lookup via THashMap (case-insensitive)
  if not FTypeNameIndex.TryGetValue(LowerCase(AName), Result) then
    Result := 0;
end;

function TSemanticModel.FindSymbolByName(const AName: string): LongInt;
begin
  // O(1) lookup via THashMap (case-insensitive)
  if not FSymbolNameIndex.TryGetValue(LowerCase(AName), Result) then
    Result := 0;
end;

function TSemanticModel.SymbolTypeId(const ASymbolId: LongInt): LongInt;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FSymbols) - 1 do
    if FSymbols[Index].SymbolId = ASymbolId then
      Exit(FSymbols[Index].TypeId);
  Result := 0;
end;

function TSemanticModel.TypeCount: LongInt;
begin
  Result := Length(FTypes);
end;

function TSemanticModel.TypeAt(const AIndex: LongInt): TSemanticType;
begin
  if (AIndex >= 0) and (AIndex < Length(FTypes)) then
    Result := FTypes[AIndex]
  else
  begin
    Result.TypeId := 0;
    Result.Name := '';
    Result.Kind := '';
  end;
end;

function TSemanticModel.TypedHirNodeCount: LongInt;
begin
  Result := Length(FTypedHirNodes);
end;

function TSemanticModel.TypedHirNodeAt(const AIndex: LongInt): TTypedHirNode;
begin
  if (AIndex < 0) or (AIndex >= Length(FTypedHirNodes)) then
  begin
    Result.HirNodeId := 0;
    Result.Kind := '';
    Result.DisplayName := '';
    Result.SymbolId := 0;
    Result.TypeId := 0;
    Result.Operand := '';
    Result.ExprId := 0;
    Result.TargetExprId := 0;
    Exit;
  end;

  Result := FTypedHirNodes[AIndex];
end;

function TSemanticModel.HirExprCount: LongInt;
begin
  Result := Length(FHirExprs);
end;

function TSemanticModel.HirExprAt(const AIndex: LongInt): TSemanticHirExpr;
begin
  if (AIndex < 0) or (AIndex >= Length(FHirExprs)) then
  begin
    Result.ExprId := 0;
    Result.Kind := shekInvalid;
    Result.TypeId := 0;
    Result.SymbolId := 0;
    SetLength(Result.Children, 0);
    Result.LiteralInt := 0;
    Result.LiteralStr := '';
    Result.Op := '';
    Result.SourceOffset := 0;
    Result.ValueClass := shvcNone;
    Exit;
  end;

  Result := FHirExprs[AIndex];
end;

function TSemanticModel.BindingCount: LongInt;
begin
  Result := Length(FBindings);
end;

function TSemanticModel.BindingAt(const AIndex: LongInt): TSemanticBinding;
begin
  if (AIndex < 0) or (AIndex >= Length(FBindings)) then
  begin
    Result.BindingId := 0;
    Result.Kind := '';
    Result.Name := '';
    Result.OwnerUnitId := '';
    Result.ByteOffset := 0;
    Result.TargetSymbolId := 0;
    Exit;
  end;

  Result := FBindings[AIndex];
end;

function TSemanticModel.RuntimeContractCount: LongInt;
begin
  Result := Length(FRuntimeContracts);
end;

function TSemanticModel.RuntimeContractAt(
  const AIndex: LongInt
): TRuntimeContract;
begin
  if (AIndex < 0) or (AIndex >= Length(FRuntimeContracts)) then
  begin
    Result.ContractId := 0;
    Result.Name := '';
    Exit;
  end;

  Result := FRuntimeContracts[AIndex];
end;

function TSemanticModel.ForeignProcedureBindingCount: LongInt;
begin
  Result := Length(FForeignProcedureBindings);
end;

function TSemanticModel.ForeignProcedureBindingAt(
  const AIndex: LongInt
): TSemanticForeignProcedureBinding;
begin
  if (AIndex < 0) or (AIndex >= Length(FForeignProcedureBindings)) then
  begin
    Result.BindingId := 0;
    Result.PascalName := '';
    Result.CallingConvention := '';
    Result.LibraryId := '';
    Result.ExternalSymbolName := '';
    Result.SymbolId := 0;
    Exit;
  end;

  Result := FForeignProcedureBindings[AIndex];
end;

function TSemanticModel.LibraryRequestCount: LongInt;
begin
  Result := Length(FLibraryRequests);
end;

function TSemanticModel.LibraryRequestAt(
  const AIndex: LongInt
): TSemanticLibraryRequest;
begin
  if (AIndex < 0) or (AIndex >= Length(FLibraryRequests)) then
  begin
    Result.RequestId := 0;
    Result.LogicalId := '';
    Result.LinkageKind := '';
    Result.Strength := '';
    Exit;
  end;

  Result := FLibraryRequests[AIndex];
end;

procedure TSemanticModel.AddConstValue(const AName: string; const AValue: Int64);
var
  Index: LongInt;
  NextIndex: SizeInt;
begin
  for Index := 0 to Length(FConstValues) - 1 do
    if SameText(FConstValues[Index].Name, AName) then
    begin
      FConstValues[Index].Value := AValue;
      Exit;
    end;
  NextIndex := Length(FConstValues);
  SetLength(FConstValues, NextIndex + 1);
  FConstValues[NextIndex].Name := AName;
  FConstValues[NextIndex].Value := AValue;
  // Update O(1) lookup index (case-insensitive)
  FConstNameIndex.Put(LowerCase(AName), NextIndex);
end;

function TSemanticModel.LookupConstValue(const AName: string;
  out AValue: Int64): Boolean;
var
  Idx: LongInt;
begin
  AValue := 0;
  // O(1) lookup via THashMap (case-insensitive)
  if FConstNameIndex.TryGetValue(LowerCase(AName), Idx) then
  begin
    AValue := FConstValues[Idx].Value;
    Exit(True);
  end;
  Result := False;
end;

function TSemanticModel.ConstValueCount: LongInt;
begin
  Result := Length(FConstValues);
end;

function TSemanticModel.ConstValueNameAt(AIndex: LongInt): string;
begin
  if (AIndex >= 0) and (AIndex < Length(FConstValues)) then
    Result := FConstValues[AIndex].Name
  else
    Result := '';
end;

function TSemanticModel.ConstValueAt(AIndex: LongInt): Int64;
begin
  if (AIndex >= 0) and (AIndex < Length(FConstValues)) then
    Result := FConstValues[AIndex].Value
  else
    Result := 0;
end;

procedure TSemanticModel.AddVarInitValue(const AName: string; const AValue: Int64);
var
  Index: LongInt;
  NextIndex: SizeInt;
begin
  for Index := 0 to Length(FVarInitValues) - 1 do
    if SameText(FVarInitValues[Index].Name, AName) then
    begin
      FVarInitValues[Index].Value := AValue;
      Exit;
    end;
  NextIndex := Length(FVarInitValues);
  SetLength(FVarInitValues, NextIndex + 1);
  FVarInitValues[NextIndex].Name := AName;
  FVarInitValues[NextIndex].Value := AValue;
end;

procedure TSemanticModel.RemoveVarInitValue(const AName: string);
var
  Index, Last: LongInt;
begin
  Last := Length(FVarInitValues) - 1;
  for Index := 0 to Last do
    if SameText(FVarInitValues[Index].Name, AName) then
    begin
      if Index < Last then
        FVarInitValues[Index] := FVarInitValues[Last];
      SetLength(FVarInitValues, Last);
      Exit;
    end;
end;

function TSemanticModel.LookupVarInitValue(const AName: string;
  out AValue: Int64): Boolean;
var
  Index: LongInt;
begin
  AValue := 0;
  for Index := 0 to Length(FVarInitValues) - 1 do
    if SameText(FVarInitValues[Index].Name, AName) then
    begin
      AValue := FVarInitValues[Index].Value;
      Exit(True);
    end;
  Result := False;
end;

function TSemanticModel.HasVarInitValue(const AName: string): Boolean;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FVarInitValues) - 1 do
    if SameText(FVarInitValues[Index].Name, AName) then
      Exit(True);
  Result := False;
end;

procedure TSemanticModel.SetTypeMeta(const ATypeId: LongInt;
  const AMeta: TTypeMetadata);
var
  I: LongInt;
  TypeName: string;
begin
  for I := 0 to Length(FTypeMetadataEntries) - 1 do
    if FTypeMetadataEntries[I].TypeId = ATypeId then
    begin
      FTypeMetadataEntries[I] := AMeta;
      FTypeMetadataEntries[I].TypeId := ATypeId;
      // Update O(1) lookup index
      if (ATypeId > 0) and (ATypeId <= Length(FTypes)) then
        FTypeMetaNameIndex.Put(LowerCase(FTypes[ATypeId - 1].Name), I);
      Exit;
    end;
  I := Length(FTypeMetadataEntries);
  SetLength(FTypeMetadataEntries, I + 1);
  FTypeMetadataEntries[I] := AMeta;
  FTypeMetadataEntries[I].TypeId := ATypeId;
  // Update O(1) lookup index
  if (ATypeId > 0) and (ATypeId <= Length(FTypes)) then
    FTypeMetaNameIndex.Put(LowerCase(FTypes[ATypeId - 1].Name), I);
end;

function TSemanticModel.GetTypeMeta(const ATypeId: LongInt;
  out AMeta: TTypeMetadata): Boolean;
var
  I: LongInt;
begin
  Result := False;
  for I := 0 to Length(FTypeMetadataEntries) - 1 do
    if FTypeMetadataEntries[I].TypeId = ATypeId then
    begin
      AMeta := FTypeMetadataEntries[I];
      Exit(True);
    end;
end;

function TSemanticModel.GetTypeMetaByName(const ATypeName: string;
  out AMeta: TTypeMetadata): Boolean;
var
  Idx: LongInt;
begin
  Result := False;
  // O(1) lookup via THashMap (case-insensitive)
  if FTypeMetaNameIndex.TryGetValue(LowerCase(ATypeName), Idx) then
  begin
    AMeta := FTypeMetadataEntries[Idx];
    Exit(True);
  end;
end;

function TSemanticModel.GetFieldMetaByName(const ATypeId: LongInt;
  const AFieldName: string; out AField: TFieldMeta): Boolean;
var
  I, J: LongInt;
begin
  Result := False;
  for I := 0 to Length(FTypeMetadataEntries) - 1 do
    if FTypeMetadataEntries[I].TypeId = ATypeId then
    begin
      for J := 0 to Length(FTypeMetadataEntries[I].Fields) - 1 do
        if SameText(FTypeMetadataEntries[I].Fields[J].Name, AFieldName) then
        begin
          AField := FTypeMetadataEntries[I].Fields[J];
          Exit(True);
        end;
      Exit;
    end;
end;

function TSemanticModel.GetVmtSlotByName(const ATypeId: LongInt;
  const AMethodName: string; out ASlot: TVmtSlot): Boolean;
var
  I, J: LongInt;
begin
  Result := False;
  for I := 0 to Length(FTypeMetadataEntries) - 1 do
    if FTypeMetadataEntries[I].TypeId = ATypeId then
    begin
      for J := 0 to Length(FTypeMetadataEntries[I].VmtSlots) - 1 do
        if SameText(FTypeMetadataEntries[I].VmtSlots[J].MethodName, AMethodName) then
        begin
          ASlot := FTypeMetadataEntries[I].VmtSlots[J];
          Exit(True);
        end;
      Exit;
    end;
end;

procedure TSemanticModel.AddFloatConstValue(const AName: string; const AValue: Double);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FFloatConstValues);
  SetLength(FFloatConstValues, NextIndex + 1);
  FFloatConstValues[NextIndex].Name := AName;
  FFloatConstValues[NextIndex].Value := AValue;
end;

function TSemanticModel.LookupFloatConstValue(const AName: string; out AValue: Double): Boolean;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FFloatConstValues) - 1 do
    if SameText(FFloatConstValues[Index].Name, AName) then
    begin
      AValue := FFloatConstValues[Index].Value;
      Exit(True);
    end;
  Result := False;
end;

procedure TSemanticModel.AddStringConstValue(const AName: string; const AValue: string);
var
  Index: LongInt;
  NextIndex: SizeInt;
begin
  for Index := 0 to Length(FStringConstValues) - 1 do
    if SameText(FStringConstValues[Index].Name, AName) then
    begin
      FStringConstValues[Index].Value := AValue;
      Exit;
    end;
  NextIndex := Length(FStringConstValues);
  SetLength(FStringConstValues, NextIndex + 1);
  FStringConstValues[NextIndex].Name := AName;
  FStringConstValues[NextIndex].Value := AValue;
end;

function TSemanticModel.LookupStringConstValue(const AName: string;
  out AValue: string): Boolean;
var
  Index: LongInt;
begin
  AValue := '';
  for Index := 0 to Length(FStringConstValues) - 1 do
    if SameText(FStringConstValues[Index].Name, AName) then
    begin
      AValue := FStringConstValues[Index].Value;
      Exit(True);
    end;
  Result := False;
end;

procedure TSemanticModel.SetRootName(const AName: string);
begin
  FRootName := AName;
end;

function TSemanticModel.RootName: string;
begin
  Result := FRootName;
end;

procedure TSemanticModel.SetUnitInitOrder(const AOrder: array of string);
var
  I: LongInt;
begin
  SetLength(FUnitInitOrder, Length(AOrder));
  for I := 0 to High(AOrder) do
    FUnitInitOrder[I] := AOrder[I];
end;

function TSemanticModel.UnitInitOrderCount: LongInt;
begin
  Result := Length(FUnitInitOrder);
end;

function TSemanticModel.UnitInitOrderAt(const AIndex: LongInt): string;
begin
  if (AIndex < 0) or (AIndex >= Length(FUnitInitOrder)) then
    Exit('');
  Result := FUnitInitOrder[AIndex];
end;

procedure TSemanticModel.MarkReady;
begin
  FStatus := 'ready';
end;

procedure TSemanticModel.MarkFailure;
begin
  FStatus := 'failure';
end;

function TSemanticModel.Status: string;
begin
  Result := FStatus;
end;

