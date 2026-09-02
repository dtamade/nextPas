
procedure TSemaRuntimeVarRegistry.RegisterRuntimeStrVar(const AName: string);
begin
  RegisterUniqueName(FRuntimeStrVarNames, AName);
end;

procedure TSemaRuntimeVarRegistry.RegisterOwnedRuntimeStrVar(const AName: string);
begin
  if AName = '' then
    Exit;
  RegisterUniqueName(FOwnedRuntimeStrVarNames, AName);
end;

procedure TSemaRuntimeVarRegistry.RegisterBorrowedRuntimeStrVar(const AName: string);
begin
  if AName = '' then
    Exit;
  RegisterUniqueName(FBorrowedRuntimeStrVarNames, AName);
end;

function TSemaRuntimeVarRegistry.IsRuntimeStrVar(const AName: string): Boolean;
begin
  Result := ContainsName(FRuntimeStrVarNames, AName);
end;

function TSemaRuntimeVarRegistry.IsOwnedRuntimeStrVar(const AName: string): Boolean;
begin
  Result := ContainsName(FOwnedRuntimeStrVarNames, AName);
end;

function TSemaRuntimeVarRegistry.IsBorrowedRuntimeStrVar(const AName: string): Boolean;
begin
  Result := ContainsName(FBorrowedRuntimeStrVarNames, AName);
end;

function TSemaRuntimeVarRegistry.GetOwnedRuntimeStrVarNames: TStringArray;
begin
  Result := StringVecToArray(FOwnedRuntimeStrVarNames);
end;

function TSemaRuntimeVarRegistry.GetOwnedRuntimeStrVarCount: SizeInt;
begin
  Result := FOwnedRuntimeStrVarNames.Count;
end;

procedure TSemaRuntimeVarRegistry.RegisterOwnedStringReturnFunc(const AName: string);
begin
  if AName = '' then
    Exit;
  RegisterUniqueName(FOwnedStringReturnFuncNames, AName);
end;

function TSemaRuntimeVarRegistry.IsOwnedStringReturnFunc(const AName: string): Boolean;
begin
  Result := ContainsName(FOwnedStringReturnFuncNames, AName);
end;

procedure TSemaRuntimeVarRegistry.ClearPendingStringTempReleases;
begin
  FPendingStringTempNames.Clear;
  FPendingStringTempSources.Clear;
end;

procedure TSemaRuntimeVarRegistry.QueuePendingStringTempRelease(
  const ATempName, ASourceName: string);
begin
  if (ATempName = '') or (ASourceName = '') then
    Exit;
  FPendingStringTempNames.Push(ATempName);
  FPendingStringTempSources.Push(ASourceName);
end;

function TSemaRuntimeVarRegistry.GetPendingStringTempNames: TStringArray;
begin
  Result := StringVecToArray(FPendingStringTempNames);
end;

function TSemaRuntimeVarRegistry.GetPendingStringTempSources: TStringArray;
begin
  Result := StringVecToArray(FPendingStringTempSources);
end;

function TSemaRuntimeVarRegistry.GetPendingStringTempCount: SizeInt;
begin
  Result := FPendingStringTempNames.Count;
end;

procedure TSemaRuntimeVarRegistry.RegisterRuntimeArrVar(const AName: string);
begin
  RegisterUniqueName(FRuntimeArrVarNames, AName);
end;

procedure TSemaRuntimeVarRegistry.RegisterBorrowedRuntimeArrVar(const AName: string);
begin
  RegisterUniqueName(FBorrowedRuntimeArrVarNames, AName);
end;

function TSemaRuntimeVarRegistry.IsRuntimeArrVar(const AName: string): Boolean;
begin
  Result := ContainsName(FRuntimeArrVarNames, AName);
end;

function TSemaRuntimeVarRegistry.IsBorrowedRuntimeArrVar(const AName: string): Boolean;
begin
  Result := ContainsName(FBorrowedRuntimeArrVarNames, AName);
end;

function TSemaRuntimeVarRegistry.GetRuntimeArrVarNames: TStringArray;
begin
  Result := StringVecToArray(FRuntimeArrVarNames);
end;

function TSemaRuntimeVarRegistry.GetBorrowedRuntimeArrVarNames: TStringArray;
begin
  Result := StringVecToArray(FBorrowedRuntimeArrVarNames);
end;
