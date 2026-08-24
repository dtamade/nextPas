
procedure TSemaRuntimeVarRegistry.RegisterClassVar(const AName, AClassName: string);
var
  Idx: LongInt;
begin
  for Idx := 0 to LongInt(FClassVarNames.Count) - 1 do
    if SameText(FClassVarNames[Idx], AName) then
    begin
      FClassVarTypes[Idx] := AClassName;
      Exit;
    end;
  FClassVarNames.Push(AName);
  FClassVarTypes.Push(AClassName);
end;

function TSemaRuntimeVarRegistry.LookupClassVar(const AName: string): string;
var
  Idx: LongInt;
begin
  for Idx := 0 to LongInt(FClassVarNames.Count) - 1 do
    if SameText(FClassVarNames[Idx], AName) then
      Exit(FClassVarTypes[Idx]);
  Result := '';
end;

function TSemaRuntimeVarRegistry.GetClassVarNames: TStringArray;
begin
  Result := StringVecToArray(FClassVarNames);
end;

procedure TSemaRuntimeVarRegistry.SuppressClassVarCleanup(const AName: string);
begin
  RegisterUniqueName(FNoCleanupClassVarNames, AName);
end;

function TSemaRuntimeVarRegistry.IsClassVarCleanupSuppressed(const AName: string): Boolean;
begin
  Result := ContainsName(FNoCleanupClassVarNames, AName);
end;

function TSemaRuntimeVarRegistry.GetClassVarTypes: TStringArray;
begin
  Result := StringVecToArray(FClassVarTypes);
end;

procedure TSemaRuntimeVarRegistry.RegisterRecordVar(const AName, ATypeName: string);
var
  Idx: LongInt;
begin
  for Idx := 0 to LongInt(FRecordVarNames.Count) - 1 do
    if SameText(FRecordVarNames[Idx], AName) then
    begin
      FRecordVarTypes[Idx] := ATypeName;
      Exit;
    end;
  FRecordVarNames.Push(AName);
  FRecordVarTypes.Push(ATypeName);
end;

function TSemaRuntimeVarRegistry.IsRecordVar(const AName: string): Boolean;
begin
  Result := ContainsName(FRecordVarNames, AName);
end;

function TSemaRuntimeVarRegistry.LookupRecordVar(const AName: string): string;
var
  Idx: LongInt;
begin
  for Idx := 0 to LongInt(FRecordVarNames.Count) - 1 do
    if SameText(FRecordVarNames[Idx], AName) then
      Exit(FRecordVarTypes[Idx]);
  Result := '';
end;

procedure TSemaRuntimeVarRegistry.RegisterManagedRecordVar(
  const AName, ATypeName: string);
var
  Idx: LongInt;
begin
  for Idx := 0 to LongInt(FManagedRecordVarNames.Count) - 1 do
    if SameText(FManagedRecordVarNames[Idx], AName) then
    begin
      FManagedRecordVarTypes[Idx] := ATypeName;
      Exit;
    end;
  FManagedRecordVarNames.Push(AName);
  FManagedRecordVarTypes.Push(ATypeName);
end;

function TSemaRuntimeVarRegistry.GetManagedRecordVarNames: TStringArray;
begin
  Result := StringVecToArray(FManagedRecordVarNames);
end;

function TSemaRuntimeVarRegistry.GetManagedRecordVarTypes: TStringArray;
begin
  Result := StringVecToArray(FManagedRecordVarTypes);
end;

function TSemaRuntimeVarRegistry.GetManagedRecordVarCount: SizeInt;
begin
  Result := FManagedRecordVarNames.Count;
end;

procedure TSemaRuntimeVarRegistry.RegisterPointerVar(const AName,
  APointeeTypeName: string);
var
  Idx: LongInt;
begin
  if (AName = '') or (APointeeTypeName = '') then
    Exit;
  for Idx := 0 to LongInt(FPointerVarNames.Count) - 1 do
    if SameText(FPointerVarNames[Idx], AName) then
    begin
      FPointerVarTypes[Idx] := APointeeTypeName;
      Exit;
    end;
  FPointerVarNames.Push(AName);
  FPointerVarTypes.Push(APointeeTypeName);
end;

function TSemaRuntimeVarRegistry.LookupPointerVar(const AName: string): string;
var
  Idx: LongInt;
begin
  for Idx := 0 to LongInt(FPointerVarNames.Count) - 1 do
    if SameText(FPointerVarNames[Idx], AName) then
      Exit(FPointerVarTypes[Idx]);
  Result := '';
end;

procedure TSemaRuntimeVarRegistry.RegisterVarParam(const AName: string);
begin
  RegisterUniqueName(FVarParamNames, AName);
end;

function TSemaRuntimeVarRegistry.IsVarParam(const AName: string): Boolean;
begin
  Result := ContainsName(FVarParamNames, AName);
end;

procedure TSemaRuntimeVarRegistry.Reset;
begin
  { Per-body trackers only. FOwnedStringReturnFuncNames is a cross-body
    program-global registry seeded by PreRegisterOwnedStringReturnConsumers
    before SeedFunctionBodies; clearing it here made every per-body
    IsOwnedStringReturnFunc lookup miss (b4b-i16 concat-swap root cause). }
  FRuntimeVarNames.Clear;
  FRuntimeStrVarNames.Clear;
  FOwnedRuntimeStrVarNames.Clear;
  FBorrowedRuntimeStrVarNames.Clear;
  ClearPendingStringTempReleases;
  FRuntimeArrVarNames.Clear;
  FBorrowedRuntimeArrVarNames.Clear;
  FClassVarNames.Clear;
  FClassVarTypes.Clear;
  FNoCleanupClassVarNames.Clear;
  FRecordVarNames.Clear;
  FRecordVarTypes.Clear;
  FManagedRecordVarNames.Clear;
  FManagedRecordVarTypes.Clear;
  FPointerVarNames.Clear;
  FPointerVarTypes.Clear;
  FVarParamNames.Clear;
  FPtrReturnFuncs.Clear;
  FPtrReturnTypes.Clear;
end;

function TSemaRuntimeVarRegistry.GetVarParamCount: SizeInt;
begin
  Result := FVarParamNames.Count;
end;

function TSemaRuntimeVarRegistry.GetVarParamAt(AIndex: SizeInt): string;
begin
  if (AIndex >= 0) and (AIndex < FVarParamNames.Count) then
    Result := FVarParamNames[AIndex]
  else
    Result := '';
end;

procedure TSemaRuntimeVarRegistry.RegisterPtrReturnFunc(
  const AName, AClassName: string);
begin
  FPtrReturnFuncs.Push(AName);
  FPtrReturnTypes.Push(AClassName);
end;

function TSemaRuntimeVarRegistry.LookupPtrReturnFunc(const AName: string): string;
var
  Idx: LongInt;
begin
  for Idx := 0 to LongInt(FPtrReturnFuncs.Count) - 1 do
    if SameText(FPtrReturnFuncs[Idx], AName) then
      Exit(FPtrReturnTypes[Idx]);
  Result := '';
end;
