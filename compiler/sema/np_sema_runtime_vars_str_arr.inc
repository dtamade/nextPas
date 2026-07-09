
procedure TSemaRuntimeVarRegistry.RegisterRuntimeStrVar(const AName: string);
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

procedure TSemaRuntimeVarRegistry.RegisterOwnedRuntimeStrVar(const AName: string);
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

procedure TSemaRuntimeVarRegistry.RegisterBorrowedRuntimeStrVar(const AName: string);
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

function TSemaRuntimeVarRegistry.IsRuntimeStrVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FRuntimeStrVarNames) - 1 do
    if SameText(FRuntimeStrVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

function TSemaRuntimeVarRegistry.IsOwnedRuntimeStrVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FOwnedRuntimeStrVarNames) - 1 do
    if SameText(FOwnedRuntimeStrVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

function TSemaRuntimeVarRegistry.IsBorrowedRuntimeStrVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FBorrowedRuntimeStrVarNames) - 1 do
    if SameText(FBorrowedRuntimeStrVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

function TSemaRuntimeVarRegistry.GetOwnedRuntimeStrVarNames: TStringArray;
begin
  Result := FOwnedRuntimeStrVarNames;
end;

function TSemaRuntimeVarRegistry.GetOwnedRuntimeStrVarCount: SizeInt;
begin
  Result := Length(FOwnedRuntimeStrVarNames);
end;

procedure TSemaRuntimeVarRegistry.RegisterOwnedStringReturnFunc(const AName: string);
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

function TSemaRuntimeVarRegistry.IsOwnedStringReturnFunc(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FOwnedStringReturnFuncNames) - 1 do
    if SameText(FOwnedStringReturnFuncNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

procedure TSemaRuntimeVarRegistry.ClearPendingStringTempReleases;
begin
  SetLength(FPendingStringTempNames, 0);
  SetLength(FPendingStringTempSources, 0);
end;

procedure TSemaRuntimeVarRegistry.QueuePendingStringTempRelease(
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

function TSemaRuntimeVarRegistry.GetPendingStringTempNames: TStringArray;
begin
  Result := FPendingStringTempNames;
end;

function TSemaRuntimeVarRegistry.GetPendingStringTempSources: TStringArray;
begin
  Result := FPendingStringTempSources;
end;

function TSemaRuntimeVarRegistry.GetPendingStringTempCount: SizeInt;
begin
  Result := Length(FPendingStringTempNames);
end;

procedure TSemaRuntimeVarRegistry.RegisterRuntimeArrVar(const AName: string);
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

procedure TSemaRuntimeVarRegistry.RegisterBorrowedRuntimeArrVar(const AName: string);
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

function TSemaRuntimeVarRegistry.IsRuntimeArrVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FRuntimeArrVarNames) - 1 do
    if SameText(FRuntimeArrVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

function TSemaRuntimeVarRegistry.IsBorrowedRuntimeArrVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FBorrowedRuntimeArrVarNames) - 1 do
    if SameText(FBorrowedRuntimeArrVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

function TSemaRuntimeVarRegistry.GetRuntimeArrVarNames: TStringArray;
begin
  Result := FRuntimeArrVarNames;
end;

function TSemaRuntimeVarRegistry.GetBorrowedRuntimeArrVarNames: TStringArray;
begin
  Result := FBorrowedRuntimeArrVarNames;
