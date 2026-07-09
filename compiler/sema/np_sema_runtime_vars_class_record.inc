
procedure TSemaRuntimeVarRegistry.RegisterClassVar(const AName, AClassName: string);
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FClassVarNames) - 1 do
    if SameText(FClassVarNames[Idx], AName) then
    begin
      FClassVarTypes[Idx] := AClassName;
      Exit;
    end;
  Idx := Length(FClassVarNames);
  SetLength(FClassVarNames, Idx + 1);
  SetLength(FClassVarTypes, Idx + 1);
  FClassVarNames[Idx] := AName;
  FClassVarTypes[Idx] := AClassName;
end;

function TSemaRuntimeVarRegistry.LookupClassVar(const AName: string): string;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FClassVarNames) - 1 do
    if SameText(FClassVarNames[Idx], AName) then
      Exit(FClassVarTypes[Idx]);
  Result := '';
end;

function TSemaRuntimeVarRegistry.GetClassVarNames: TStringArray;
begin
  Result := FClassVarNames;
end;

function TSemaRuntimeVarRegistry.GetClassVarTypes: TStringArray;
begin
  Result := FClassVarTypes;
end;

procedure TSemaRuntimeVarRegistry.RegisterRecordVar(const AName, ATypeName: string);
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

function TSemaRuntimeVarRegistry.IsRecordVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FRecordVarNames) - 1 do
    if SameText(FRecordVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

function TSemaRuntimeVarRegistry.LookupRecordVar(const AName: string): string;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FRecordVarNames) - 1 do
    if SameText(FRecordVarNames[Idx], AName) then
      Exit(FRecordVarTypes[Idx]);
  Result := '';
end;

procedure TSemaRuntimeVarRegistry.RegisterManagedRecordVar(
  const AName, ATypeName: string);
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FManagedRecordVarNames) - 1 do
    if SameText(FManagedRecordVarNames[Idx], AName) then
    begin
      FManagedRecordVarTypes[Idx] := ATypeName;
      Exit;
    end;
  Idx := Length(FManagedRecordVarNames);
  SetLength(FManagedRecordVarNames, Idx + 1);
  SetLength(FManagedRecordVarTypes, Idx + 1);
  FManagedRecordVarNames[Idx] := AName;
  FManagedRecordVarTypes[Idx] := ATypeName;
end;

function TSemaRuntimeVarRegistry.GetManagedRecordVarNames: TStringArray;
begin
  Result := FManagedRecordVarNames;
end;

function TSemaRuntimeVarRegistry.GetManagedRecordVarTypes: TStringArray;
begin
  Result := FManagedRecordVarTypes;
end;

function TSemaRuntimeVarRegistry.GetManagedRecordVarCount: SizeInt;
begin
  Result := Length(FManagedRecordVarNames);
end;

procedure TSemaRuntimeVarRegistry.RegisterPointerVar(const AName,
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

function TSemaRuntimeVarRegistry.LookupPointerVar(const AName: string): string;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FPointerVarNames) - 1 do
    if SameText(FPointerVarNames[Idx], AName) then
      Exit(FPointerVarTypes[Idx]);
  Result := '';
end;

procedure TSemaRuntimeVarRegistry.RegisterVarParam(const AName: string);
var
  Idx: LongInt;
begin
  for Idx := 0 to FVarParamNames.Count - 1 do
    if SameText(FVarParamNames[Idx], AName) then
      Exit;
  FVarParamNames.Push(AName);
end;

function TSemaRuntimeVarRegistry.IsVarParam(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to FVarParamNames.Count - 1 do
    if SameText(FVarParamNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

procedure TSemaRuntimeVarRegistry.Reset;
begin
  SetLength(FRuntimeVarNames, 0);
  SetLength(FRuntimeStrVarNames, 0);
  SetLength(FOwnedRuntimeStrVarNames, 0);
  SetLength(FBorrowedRuntimeStrVarNames, 0);
  SetLength(FOwnedStringReturnFuncNames, 0);
  ClearPendingStringTempReleases;
  SetLength(FRuntimeArrVarNames, 0);
  SetLength(FBorrowedRuntimeArrVarNames, 0);
  SetLength(FClassVarNames, 0);
  SetLength(FClassVarTypes, 0);
  SetLength(FRecordVarNames, 0);
  SetLength(FRecordVarTypes, 0);
  SetLength(FManagedRecordVarNames, 0);
  SetLength(FManagedRecordVarTypes, 0);
  SetLength(FPointerVarNames, 0);
  SetLength(FPointerVarTypes, 0);
  FVarParamNames.Clear;
  SetLength(FPtrReturnFuncs, 0);
  SetLength(FPtrReturnTypes, 0);
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
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FPtrReturnFuncs);
  SetLength(FPtrReturnFuncs, NextIndex + 1);
  SetLength(FPtrReturnTypes, NextIndex + 1);
  FPtrReturnFuncs[NextIndex] := AName;
  FPtrReturnTypes[NextIndex] := AClassName;
end;

function TSemaRuntimeVarRegistry.LookupPtrReturnFunc(const AName: string): string;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FPtrReturnFuncs) - 1 do
    if SameText(FPtrReturnFuncs[Idx], AName) then
      Exit(FPtrReturnTypes[Idx]);
  Result := '';
