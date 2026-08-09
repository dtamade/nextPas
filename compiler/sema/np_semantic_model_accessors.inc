function TSemanticModel.SymbolCount: LongInt;
begin
  Result := LongInt(FSymbols.Count);
end;

function TSemanticModel.SymbolAt(const AIndex: LongInt): TSemanticSymbol;
begin
  if (AIndex < 0) or (AIndex >= LongInt(FSymbols.Count)) then
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
  Result := FSymbols[SizeUInt(AIndex)];
end;

function TSemanticModel.FindTypeByName(const AName: string): LongInt;
begin
  if not FTypeNameIndex.TryGetValue(LowerCase(AName), Result) then
    Result := 0;
end;

function TSemanticModel.FindSymbolByName(const AName: string): LongInt;
begin
  if not FSymbolNameIndex.TryGetValue(LowerCase(AName), Result) then
    Result := 0;
end;

function TSemanticModel.FirstSymbolIdByName(const AName: string): LongInt;
begin
  Result := FindSymbolByName(AName);
end;

function TSemanticModel.NextSymbolIdSameName(const ASymbolId: LongInt): LongInt;
begin
  Result := 0;
  if (ASymbolId <= 0) or (ASymbolId > LongInt(FSymbols.Count)) then
    Exit;
  Result := FSymbols[SizeUInt(ASymbolId - 1)].NextSameNameId;
end;

function TSemanticModel.SymbolTypeId(const ASymbolId: LongInt): LongInt;
var
  Index: LongInt;
begin
  { SymbolId is 1-based push order (see AddSymbol) — O(1), not full scan. }
  Index := ASymbolId - 1;
  if (Index >= 0) and (Index < LongInt(FSymbols.Count)) then
    Exit(FSymbols[SizeUInt(Index)].TypeId);
  Result := 0;
end;

function TSemanticModel.TypeCount: LongInt;
begin
  Result := LongInt(FTypes.Count);
end;

function TSemanticModel.TypeAt(const AIndex: LongInt): TSemanticType;
begin
  if (AIndex >= 0) and (AIndex < LongInt(FTypes.Count)) then
    Result := FTypes[SizeUInt(AIndex)]
  else
  begin
    Result.TypeId := 0;
    Result.Name := '';
    Result.Kind := '';
  end;
end;

function TSemanticModel.TypedHirNodeCount: LongInt;
begin
  Result := LongInt(FTypedHirNodes.Count);
end;

function TSemanticModel.TypedHirNodeAt(const AIndex: LongInt): TTypedHirNode;
begin
  if (AIndex < 0) or (AIndex >= LongInt(FTypedHirNodes.Count)) then
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

  Result := FTypedHirNodes[SizeUInt(AIndex)];
end;

function TSemanticModel.HirExprCount: LongInt;
begin
  Result := LongInt(FHirExprs.Count);
end;

function TSemanticModel.HirExprAt(const AIndex: LongInt): TSemanticHirExpr;
begin
  if (AIndex < 0) or (AIndex >= LongInt(FHirExprs.Count)) then
  begin
    Result.ExprId := 0;
    Result.Kind := shekInvalid;
    Result.TypeId := 0;
    Result.SymbolId := 0;
    Result.Children := nil;
    Result.LiteralInt := 0;
    Result.LiteralStr := '';
    Result.Op := '';
    Result.SourceOffset := 0;
    Result.ValueClass := shvcNone;
    Exit;
  end;

  Result := FHirExprs[SizeUInt(AIndex)];
end;

function TSemanticModel.BindingCount: LongInt;
begin
  Result := LongInt(FBindings.Count);
end;

function TSemanticModel.BindingAt(const AIndex: LongInt): TSemanticBinding;
begin
  if (AIndex < 0) or (AIndex >= LongInt(FBindings.Count)) then
  begin
    Result.BindingId := 0;
    Result.Kind := '';
    Result.Name := '';
    Result.OwnerUnitId := '';
    Result.ByteOffset := 0;
    Result.TargetSymbolId := 0;
    Exit;
  end;

  Result := FBindings[SizeUInt(AIndex)];
end;

function TSemanticModel.RuntimeContractCount: LongInt;
begin
  Result := LongInt(FRuntimeContracts.Count);
end;

function TSemanticModel.RuntimeContractAt(
  const AIndex: LongInt
): TRuntimeContract;
begin
  if (AIndex < 0) or (AIndex >= LongInt(FRuntimeContracts.Count)) then
  begin
    Result.ContractId := 0;
    Result.Name := '';
    Exit;
  end;

  Result := FRuntimeContracts[SizeUInt(AIndex)];
end;

function TSemanticModel.ForeignProcedureBindingCount: LongInt;
begin
  Result := LongInt(FForeignProcedureBindings.Count);
end;

function TSemanticModel.ForeignProcedureBindingAt(
  const AIndex: LongInt
): TSemanticForeignProcedureBinding;
begin
  if (AIndex < 0) or (AIndex >= LongInt(FForeignProcedureBindings.Count)) then
  begin
    Result.BindingId := 0;
    Result.PascalName := '';
    Result.CallingConvention := '';
    Result.LibraryId := '';
    Result.ExternalSymbolName := '';
    Result.SymbolId := 0;
    Exit;
  end;

  Result := FForeignProcedureBindings[SizeUInt(AIndex)];
end;

function TSemanticModel.LibraryRequestCount: LongInt;
begin
  Result := LongInt(FLibraryRequests.Count);
end;

function TSemanticModel.LibraryRequestAt(
  const AIndex: LongInt
): TSemanticLibraryRequest;
begin
  if (AIndex < 0) or (AIndex >= LongInt(FLibraryRequests.Count)) then
  begin
    Result.RequestId := 0;
    Result.LogicalId := '';
    Result.LinkageKind := '';
    Result.Strength := '';
    Exit;
  end;

  Result := FLibraryRequests[SizeUInt(AIndex)];
end;

procedure TSemanticModel.AddConstValue(const AName: string; const AValue: Int64);
var
  Index: LongInt;
  Entry: TSemanticConstValue;
begin
  for Index := 0 to LongInt(FConstValues.Count) - 1 do
    if SameText(FConstValues[SizeUInt(Index)].Name, AName) then
    begin
      FConstValues.GetPtr(SizeUInt(Index))^.Value := AValue;
      Exit;
    end;
  Entry := Default(TSemanticConstValue);
  Entry.Name := AName;
  Entry.Value := AValue;
  FConstValues.Push(Entry);
  FConstNameIndex.Put(LowerCase(AName), LongInt(FConstValues.Count) - 1);
end;

function TSemanticModel.LookupConstValue(const AName: string;
  out AValue: Int64): Boolean;
var
  Idx: LongInt;
begin
  AValue := 0;
  if FConstNameIndex.TryGetValue(LowerCase(AName), Idx) then
  begin
    AValue := FConstValues[SizeUInt(Idx)].Value;
    Exit(True);
  end;
  Result := False;
end;

function TSemanticModel.ConstValueCount: LongInt;
begin
  Result := LongInt(FConstValues.Count);
end;

function TSemanticModel.ConstValueNameAt(AIndex: LongInt): string;
begin
  if (AIndex >= 0) and (AIndex < LongInt(FConstValues.Count)) then
    Result := FConstValues[SizeUInt(AIndex)].Name
  else
    Result := '';
end;

function TSemanticModel.ConstValueAt(AIndex: LongInt): Int64;
begin
  if (AIndex >= 0) and (AIndex < LongInt(FConstValues.Count)) then
    Result := FConstValues[SizeUInt(AIndex)].Value
  else
    Result := 0;
end;

procedure TSemanticModel.AddVarInitValue(const AName: string; const AValue: Int64);
var
  Index: LongInt;
  Entry: TSemanticVarInitValue;
begin
  for Index := 0 to LongInt(FVarInitValues.Count) - 1 do
    if SameText(FVarInitValues[SizeUInt(Index)].Name, AName) then
    begin
      FVarInitValues.GetPtr(SizeUInt(Index))^.Value := AValue;
      Exit;
    end;
  Entry := Default(TSemanticVarInitValue);
  Entry.Name := AName;
  Entry.Value := AValue;
  FVarInitValues.Push(Entry);
end;

procedure TSemanticModel.RemoveVarInitValue(const AName: string);
var
  Index, Last: LongInt;
begin
  Last := LongInt(FVarInitValues.Count) - 1;
  for Index := 0 to Last do
    if SameText(FVarInitValues[SizeUInt(Index)].Name, AName) then
    begin
      if Index < Last then
        FVarInitValues[SizeUInt(Index)] := FVarInitValues[SizeUInt(Last)];
      FVarInitValues.Resize(SizeUInt(Last));
      Exit;
    end;
end;

function TSemanticModel.LookupVarInitValue(const AName: string;
  out AValue: Int64): Boolean;
var
  Index: LongInt;
begin
  AValue := 0;
  for Index := 0 to LongInt(FVarInitValues.Count) - 1 do
    if SameText(FVarInitValues[SizeUInt(Index)].Name, AName) then
    begin
      AValue := FVarInitValues[SizeUInt(Index)].Value;
      Exit(True);
    end;
  Result := False;
end;

function TSemanticModel.HasVarInitValue(const AName: string): Boolean;
var
  Index: LongInt;
begin
  for Index := 0 to LongInt(FVarInitValues.Count) - 1 do
    if SameText(FVarInitValues[SizeUInt(Index)].Name, AName) then
      Exit(True);
  Result := False;
end;

function TypeMetaFieldsOwnedByModel(
  const AEntries: TTypeMetadataVec;
  const AFields: TSemanticFieldMetaVec
): Boolean;
var
  I: LongInt;
begin
  Result := False;
  if (AEntries = nil) or (AFields = nil) then
    Exit;
  for I := 0 to LongInt(AEntries.Count) - 1 do
    if AEntries.GetPtr(SizeUInt(I))^.Fields = AFields then
      Exit(True);
end;

function CloneTypeMetaFields(
  const ASrc: TSemanticFieldMetaVec
): TSemanticFieldMetaVec;
var
  I: SizeInt;
begin
  if ASrc = nil then
    Exit(nil);
  Result := TSemanticFieldMetaVec.Create(ASrc.Count);
  for I := 0 to SizeInt(ASrc.Count) - 1 do
    Result.Push(ASrc[SizeUInt(I)]);
end;

function AdoptOrCloneTypeMetaFields(
  const AEntries: TTypeMetadataVec;
  const ASrc: TSemanticFieldMetaVec
): TSemanticFieldMetaVec;
begin
  if ASrc = nil then
    Exit(nil);
  { Steal unowned builder vecs; clone when another entry already owns ASrc. }
  if TypeMetaFieldsOwnedByModel(AEntries, ASrc) then
    Result := CloneTypeMetaFields(ASrc)
  else
    Result := ASrc;
end;

function TypeMetaVmtSlotsOwnedByModel(
  const AEntries: TTypeMetadataVec;
  const ASlots: TSemanticVmtSlotVec
): Boolean;
var
  I: LongInt;
begin
  Result := False;
  if (AEntries = nil) or (ASlots = nil) then
    Exit;
  for I := 0 to LongInt(AEntries.Count) - 1 do
    if AEntries.GetPtr(SizeUInt(I))^.VmtSlots = ASlots then
      Exit(True);
end;

function CloneTypeMetaVmtSlots(
  const ASrc: TSemanticVmtSlotVec
): TSemanticVmtSlotVec;
var
  I: SizeInt;
begin
  if ASrc = nil then
    Exit(nil);
  Result := TSemanticVmtSlotVec.Create(ASrc.Count);
  for I := 0 to SizeInt(ASrc.Count) - 1 do
    Result.Push(ASrc[SizeUInt(I)]);
end;

function AdoptOrCloneTypeMetaVmtSlots(
  const AEntries: TTypeMetadataVec;
  const ASrc: TSemanticVmtSlotVec
): TSemanticVmtSlotVec;
begin
  if ASrc = nil then
    Exit(nil);
  if TypeMetaVmtSlotsOwnedByModel(AEntries, ASrc) then
    Result := CloneTypeMetaVmtSlots(ASrc)
  else
    Result := ASrc;
end;

function TypeMetaPropertiesOwnedByModel(
  const AEntries: TTypeMetadataVec;
  const AProps: TSemanticPropertyMetaVec
): Boolean;
var
  I: LongInt;
begin
  Result := False;
  if (AEntries = nil) or (AProps = nil) then
    Exit;
  for I := 0 to LongInt(AEntries.Count) - 1 do
    if AEntries.GetPtr(SizeUInt(I))^.Properties = AProps then
      Exit(True);
end;

function CloneTypeMetaProperties(
  const ASrc: TSemanticPropertyMetaVec
): TSemanticPropertyMetaVec;
var
  I: SizeInt;
begin
  if ASrc = nil then
    Exit(nil);
  Result := TSemanticPropertyMetaVec.Create(ASrc.Count);
  for I := 0 to SizeInt(ASrc.Count) - 1 do
    Result.Push(ASrc[SizeUInt(I)]);
end;

function AdoptOrCloneTypeMetaProperties(
  const AEntries: TTypeMetadataVec;
  const ASrc: TSemanticPropertyMetaVec
): TSemanticPropertyMetaVec;
begin
  if ASrc = nil then
    Exit(nil);
  if TypeMetaPropertiesOwnedByModel(AEntries, ASrc) then
    Result := CloneTypeMetaProperties(ASrc)
  else
    Result := ASrc;
end;

function TypeMetaRetPtrMethodsOwnedByModel(
  const AEntries: TTypeMetadataVec;
  const AMethods: TSemanticStringVec
): Boolean;
var
  I: LongInt;
begin
  Result := False;
  if (AEntries = nil) or (AMethods = nil) then
    Exit;
  for I := 0 to LongInt(AEntries.Count) - 1 do
    if AEntries.GetPtr(SizeUInt(I))^.RetPtrMethods = AMethods then
      Exit(True);
end;

function CloneTypeMetaRetPtrMethods(
  const ASrc: TSemanticStringVec
): TSemanticStringVec;
var
  I: SizeInt;
begin
  if ASrc = nil then
    Exit(nil);
  Result := TSemanticStringVec.Create(ASrc.Count);
  for I := 0 to SizeInt(ASrc.Count) - 1 do
    Result.Push(ASrc[SizeUInt(I)]);
end;

function AdoptOrCloneTypeMetaRetPtrMethods(
  const AEntries: TTypeMetadataVec;
  const ASrc: TSemanticStringVec
): TSemanticStringVec;
begin
  if ASrc = nil then
    Exit(nil);
  if TypeMetaRetPtrMethodsOwnedByModel(AEntries, ASrc) then
    Result := CloneTypeMetaRetPtrMethods(ASrc)
  else
    Result := ASrc;
end;

function TypeMetaInterfaceSlotsOwnedByModel(
  const AEntries: TTypeMetadataVec;
  const ASlots: TSemanticInterfaceSlotMetaVec
): Boolean;
var
  I: LongInt;
begin
  Result := False;
  if (AEntries = nil) or (ASlots = nil) then
    Exit;
  for I := 0 to LongInt(AEntries.Count) - 1 do
    if AEntries.GetPtr(SizeUInt(I))^.InterfaceSlots = ASlots then
      Exit(True);
end;

function CloneTypeMetaInterfaceSlots(
  const ASrc: TSemanticInterfaceSlotMetaVec
): TSemanticInterfaceSlotMetaVec;
var
  I: SizeInt;
begin
  if ASrc = nil then
    Exit(nil);
  Result := TSemanticInterfaceSlotMetaVec.Create(ASrc.Count);
  for I := 0 to SizeInt(ASrc.Count) - 1 do
    Result.Push(ASrc[SizeUInt(I)]);
end;

function AdoptOrCloneTypeMetaInterfaceSlots(
  const AEntries: TTypeMetadataVec;
  const ASrc: TSemanticInterfaceSlotMetaVec
): TSemanticInterfaceSlotMetaVec;
begin
  if ASrc = nil then
    Exit(nil);
  if TypeMetaInterfaceSlotsOwnedByModel(AEntries, ASrc) then
    Result := CloneTypeMetaInterfaceSlots(ASrc)
  else
    Result := ASrc;
end;

procedure TSemanticModel.SetTypeMeta(const ATypeId: LongInt;
  const AMeta: TTypeMetadata);
var
  I: LongInt;
  Entry: TTypeMetadata;
  P: PTypeMetadata;
  NewFields: TSemanticFieldMetaVec;
  NewVmtSlots: TSemanticVmtSlotVec;
  NewRetPtrMethods: TSemanticStringVec;
  NewProperties: TSemanticPropertyMetaVec;
  NewInterfaceSlots: TSemanticInterfaceSlotMetaVec;
begin
  for I := 0 to LongInt(FTypeMetadataEntries.Count) - 1 do
    if FTypeMetadataEntries[SizeUInt(I)].TypeId = ATypeId then
    begin
      P := FTypeMetadataEntries.GetPtr(SizeUInt(I));
      NewFields := AMeta.Fields;
      if P^.Fields <> NewFields then
      begin
        P^.Fields.Free;
        P^.Fields := nil;
        NewFields := AdoptOrCloneTypeMetaFields(FTypeMetadataEntries, NewFields);
      end;
      NewVmtSlots := AMeta.VmtSlots;
      if P^.VmtSlots <> NewVmtSlots then
      begin
        P^.VmtSlots.Free;
        P^.VmtSlots := nil;
        NewVmtSlots := AdoptOrCloneTypeMetaVmtSlots(FTypeMetadataEntries, NewVmtSlots);
      end;
      NewRetPtrMethods := AMeta.RetPtrMethods;
      if P^.RetPtrMethods <> NewRetPtrMethods then
      begin
        P^.RetPtrMethods.Free;
        P^.RetPtrMethods := nil;
        NewRetPtrMethods := AdoptOrCloneTypeMetaRetPtrMethods(
          FTypeMetadataEntries, NewRetPtrMethods);
      end;
      NewProperties := AMeta.Properties;
      if P^.Properties <> NewProperties then
      begin
        P^.Properties.Free;
        P^.Properties := nil;
        NewProperties := AdoptOrCloneTypeMetaProperties(
          FTypeMetadataEntries, NewProperties);
      end;
      NewInterfaceSlots := AMeta.InterfaceSlots;
      if P^.InterfaceSlots <> NewInterfaceSlots then
      begin
        P^.InterfaceSlots.Free;
        P^.InterfaceSlots := nil;
        NewInterfaceSlots := AdoptOrCloneTypeMetaInterfaceSlots(
          FTypeMetadataEntries, NewInterfaceSlots);
      end;
      P^ := AMeta;
      P^.Fields := NewFields;
      P^.VmtSlots := NewVmtSlots;
      P^.RetPtrMethods := NewRetPtrMethods;
      P^.Properties := NewProperties;
      P^.InterfaceSlots := NewInterfaceSlots;
      P^.TypeId := ATypeId;
      if (ATypeId > 0) and (ATypeId <= LongInt(FTypes.Count)) then
        FTypeMetaNameIndex.Put(LowerCase(FTypes[SizeUInt(ATypeId - 1)].Name), I);
      Exit;
    end;
  Entry := AMeta;
  Entry.TypeId := ATypeId;
  Entry.Fields := AdoptOrCloneTypeMetaFields(FTypeMetadataEntries, AMeta.Fields);
  Entry.VmtSlots := AdoptOrCloneTypeMetaVmtSlots(FTypeMetadataEntries, AMeta.VmtSlots);
  Entry.RetPtrMethods := AdoptOrCloneTypeMetaRetPtrMethods(
    FTypeMetadataEntries, AMeta.RetPtrMethods);
  Entry.Properties := AdoptOrCloneTypeMetaProperties(
    FTypeMetadataEntries, AMeta.Properties);
  Entry.InterfaceSlots := AdoptOrCloneTypeMetaInterfaceSlots(
    FTypeMetadataEntries, AMeta.InterfaceSlots);
  FTypeMetadataEntries.Push(Entry);
  I := LongInt(FTypeMetadataEntries.Count) - 1;
  if (ATypeId > 0) and (ATypeId <= LongInt(FTypes.Count)) then
    FTypeMetaNameIndex.Put(LowerCase(FTypes[SizeUInt(ATypeId - 1)].Name), I);
end;

function TSemanticModel.GetTypeMeta(const ATypeId: LongInt;
  out AMeta: TTypeMetadata): Boolean;
var
  I: LongInt;
begin
  Result := False;
  for I := 0 to LongInt(FTypeMetadataEntries.Count) - 1 do
    if FTypeMetadataEntries[SizeUInt(I)].TypeId = ATypeId then
    begin
      AMeta := FTypeMetadataEntries[SizeUInt(I)];
      Exit(True);
    end;
end;

function TSemanticModel.GetTypeMetaByName(const ATypeName: string;
  out AMeta: TTypeMetadata): Boolean;
var
  Idx: LongInt;
begin
  Result := False;
  if FTypeMetaNameIndex.TryGetValue(LowerCase(ATypeName), Idx) then
  begin
    AMeta := FTypeMetadataEntries[SizeUInt(Idx)];
    Exit(True);
  end;
end;

function TSemanticModel.GetFieldMetaByName(const ATypeId: LongInt;
  const AFieldName: string; out AField: TFieldMeta): Boolean;
var
  I, J: LongInt;
begin
  Result := False;
  for I := 0 to LongInt(FTypeMetadataEntries.Count) - 1 do
    if FTypeMetadataEntries[SizeUInt(I)].TypeId = ATypeId then
    begin
      if FTypeMetadataEntries.GetPtr(SizeUInt(I))^.Fields <> nil then
        for J := 0 to LongInt(FTypeMetadataEntries.GetPtr(SizeUInt(I))^.Fields.Count) - 1 do
          if SameText(FTypeMetadataEntries.GetPtr(SizeUInt(I))^.Fields[SizeUInt(J)].Name,
            AFieldName) then
          begin
            AField := FTypeMetadataEntries.GetPtr(SizeUInt(I))^.Fields[SizeUInt(J)];
            Exit(True);
          end;
      Exit;
    end;
end;

function TSemanticModel.GetVmtSlotByName(const ATypeId: LongInt;
  const AMethodName: string; out ASlot: TVmtSlot): Boolean;
var
  I, J: LongInt;
  Slots: TSemanticVmtSlotVec;
begin
  Result := False;
  for I := 0 to LongInt(FTypeMetadataEntries.Count) - 1 do
    if FTypeMetadataEntries[SizeUInt(I)].TypeId = ATypeId then
    begin
      Slots := FTypeMetadataEntries.GetPtr(SizeUInt(I))^.VmtSlots;
      if Slots <> nil then
        for J := 0 to LongInt(Slots.Count) - 1 do
          if SameText(Slots[SizeUInt(J)].MethodName, AMethodName) then
          begin
            ASlot := Slots[SizeUInt(J)];
            Exit(True);
          end;
      Exit;
    end;
end;

procedure TSemanticModel.AddFloatConstValue(const AName: string; const AValue: Double);
var
  Entry: TSemanticFloatConstValue;
begin
  Entry := Default(TSemanticFloatConstValue);
  Entry.Name := AName;
  Entry.Value := AValue;
  FFloatConstValues.Push(Entry);
end;

function TSemanticModel.LookupFloatConstValue(const AName: string; out AValue: Double): Boolean;
var
  Index: LongInt;
begin
  for Index := 0 to LongInt(FFloatConstValues.Count) - 1 do
    if SameText(FFloatConstValues[SizeUInt(Index)].Name, AName) then
    begin
      AValue := FFloatConstValues[SizeUInt(Index)].Value;
      Exit(True);
    end;
  Result := False;
end;

procedure TSemanticModel.AddStringConstValue(const AName: string; const AValue: string);
var
  Index: LongInt;
  Entry: TSemanticStringConstValue;
begin
  for Index := 0 to LongInt(FStringConstValues.Count) - 1 do
    if SameText(FStringConstValues[SizeUInt(Index)].Name, AName) then
    begin
      FStringConstValues.GetPtr(SizeUInt(Index))^.Value := AValue;
      Exit;
    end;
  Entry := Default(TSemanticStringConstValue);
  Entry.Name := AName;
  Entry.Value := AValue;
  FStringConstValues.Push(Entry);
end;

function TSemanticModel.LookupStringConstValue(const AName: string;
  out AValue: string): Boolean;
var
  Index: LongInt;
begin
  AValue := '';
  for Index := 0 to LongInt(FStringConstValues.Count) - 1 do
    if SameText(FStringConstValues[SizeUInt(Index)].Name, AName) then
    begin
      AValue := FStringConstValues[SizeUInt(Index)].Value;
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
  FUnitInitOrder.Clear;
  for I := 0 to High(AOrder) do
    FUnitInitOrder.Push(AOrder[I]);
end;

function TSemanticModel.UnitInitOrderCount: LongInt;
begin
  Result := LongInt(FUnitInitOrder.Count);
end;

function TSemanticModel.UnitInitOrderAt(const AIndex: LongInt): string;
begin
  if (AIndex < 0) or (AIndex >= LongInt(FUnitInitOrder.Count)) then
    Exit('');
  Result := FUnitInitOrder[SizeUInt(AIndex)];
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
