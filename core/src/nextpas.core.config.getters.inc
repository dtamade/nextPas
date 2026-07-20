function TConfig.GetString(const AKey: string; const ADefault: string): string;
var
  LFound: Boolean;
  LIdx: Integer;
  LStack: TStringArray;
begin
  RequireConfigKey(AKey);
  LFound := False;
  FLock.AcquireRead;
  try
    LIdx := FindIndexCached(AKey);
    if LIdx >= 0 then
    begin
      LFound := True;
      if TryGetResolvedEntryFastLocked(LIdx, Result) then
        Exit;
    end
    else
    begin
      Result := ADefault;
      if Pos('$', Result) = 0 then
        Exit;
      LStack := nil;
      Result := InterpolateConfigValue(FEntries, FLowerKeys, FLookupSlots,
        FCount, ADefault, LStack, False, '');
      Exit;
    end;
  finally
    FLock.ReleaseRead;
  end;

  if LFound and TryGetValue(AKey, Result) then
    Exit;

  Result := ADefault;
  if Pos('$', Result) <> 0 then
  begin
    FLock.AcquireRead;
    try
      LStack := nil;
      Result := InterpolateConfigValue(FEntries, FLowerKeys, FLookupSlots,
        FCount, ADefault, LStack, False, '');
    finally
      FLock.ReleaseRead;
    end;
  end;
end;

function TConfig.GetRawString(const AKey: string; const ADefault: string): string;
var
  LIdx: Integer;
begin
  RequireConfigKey(AKey);
  FLock.AcquireRead;
  try
    LIdx := FindIndexCached(AKey);
    if LIdx >= 0 then
      Result := FEntries[LIdx].Value
    else
      Result := ADefault;
  finally
    FLock.ReleaseRead;
  end;
end;

function TConfig.GetStringArray(const AKey: string): TStringArray;
var
  LI: Integer;
  LLowerKey: string;
  LValues: TStringArray;
  LStack: TStringArray;
  LAllLiteral: Boolean;
begin
  if AKey <> '' then
    RequireConfigKey(AKey);
  Result := nil;
  LLowerKey := LowerCase(AKey);
  FLock.AcquireRead;
  try
    if HasArrayCacheLocked(LLowerKey) then
    begin
      CopyArrayCacheLocked(LValues, LAllLiteral);
      if LAllLiteral then
      begin
        Result := LValues;
        Exit;
      end;

      SetLength(Result, Length(LValues));
      LStack := nil;
      for LI := 0 to Length(LValues) - 1 do
        Result[LI] := InterpolateConfigValue(FEntries, FLowerKeys, FLookupSlots,
          FCount, LValues[LI], LStack, False, '');
      Exit;
    end;
  finally
    FLock.ReleaseRead;
  end;

  FLock.AcquireWrite;
  try
    if not HasArrayCacheLocked(LLowerKey) then
      BuildArrayCacheLocked(AKey, LLowerKey);
    CopyArrayCacheLocked(LValues, LAllLiteral);
    if LAllLiteral then
    begin
      Result := LValues;
      Exit;
    end;

    SetLength(Result, Length(LValues));
    LStack := nil;
    for LI := 0 to Length(LValues) - 1 do
      Result[LI] := InterpolateConfigValue(FEntries, FLowerKeys, FLookupSlots,
        FCount, LValues[LI], LStack, False, '');
  finally
    FLock.ReleaseWrite;
  end;
end;

function TConfig.GetRawStringArray(const AKey: string): TStringArray;
var
  LLowerKey: string;
  LAllLiteral: Boolean;
begin
  if AKey <> '' then
    RequireConfigKey(AKey);
  Result := nil;
  LLowerKey := LowerCase(AKey);
  FLock.AcquireRead;
  try
    if HasArrayCacheLocked(LLowerKey) then
    begin
      CopyArrayCacheLocked(Result, LAllLiteral);
      Exit;
    end;
  finally
    FLock.ReleaseRead;
  end;

  FLock.AcquireWrite;
  try
    if not HasArrayCacheLocked(LLowerKey) then
      BuildArrayCacheLocked(AKey, LLowerKey);
    CopyArrayCacheLocked(Result, LAllLiteral);
  finally
    FLock.ReleaseWrite;
  end;
end;

function TConfig.GetInt(const AKey: string; ADefault: Int64): Int64;
var
  LIdx: Integer;
  LResolved: Boolean;
  LVal: Int64;
  LText: string;
begin
  RequireConfigKey(AKey);
  LResolved := False;
  FLock.AcquireRead;
  try
    LIdx := FindIndex(AKey);
    if LIdx < 0 then
      Exit(ADefault);

    LResolved := TryGetResolvedEntryFastLocked(LIdx, LText);
  finally
    FLock.ReleaseRead;
  end;

  if (not LResolved) and (not TryGetValue(AKey, LText)) then
    Exit(ADefault);

  if TryParseConfigIntText(LText, LVal) then
    Result := LVal
  else
    Result := ADefault;
end;

function TConfig.GetBool(const AKey: string; ADefault: Boolean): Boolean;
var
  LIdx: Integer;
  LResolved: Boolean;
  LText: string;
begin
  RequireConfigKey(AKey);
  LResolved := False;
  FLock.AcquireRead;
  try
    LIdx := FindIndex(AKey);
    if LIdx < 0 then
      Exit(ADefault);

    LResolved := TryGetResolvedEntryFastLocked(LIdx, LText);
  finally
    FLock.ReleaseRead;
  end;

  if (not LResolved) and (not TryGetValue(AKey, LText)) then
    Exit(ADefault);

  if TryParseConfigBoolText(LText, Result) then
    Exit;

  Result := ADefault;
end;

function TConfig.GetFloat(const AKey: string; ADefault: Double): Double;
var
  LIdx: Integer;
  LResolved: Boolean;
  LVal: Double;
  LText: string;
begin
  RequireConfigKey(AKey);
  LResolved := False;
  FLock.AcquireRead;
  try
    LIdx := FindIndex(AKey);
    if LIdx < 0 then
      Exit(ADefault);

    LResolved := TryGetResolvedEntryFastLocked(LIdx, LText);
  finally
    FLock.ReleaseRead;
  end;

  if (not LResolved) and (not TryGetValue(AKey, LText)) then
    Exit(ADefault);

  if TryParseConfigFloatText(LText, LVal) then
    Result := LVal
  else
    Result := ADefault;
end;

function TConfig.GetStringRequired(const AKey: string): string;
var
  LIdx: Integer;
  LResolved: Boolean;
begin
  RequireConfigKey(AKey);
  LResolved := False;
  FLock.AcquireRead;
  try
    LIdx := FindIndexCached(AKey);
    if LIdx < 0 then
      raise EConfigError.Create('Required config key "' + AKey + '" is missing');

    LResolved := TryGetResolvedEntryFastLocked(LIdx, Result);
  finally
    FLock.ReleaseRead;
  end;

  if (not LResolved) and (not TryGetRequiredValue(AKey, Result)) then
    raise EConfigError.Create('Required config key "' + AKey + '" is missing');
  if IsConfigBlankText(Result) then
    raise EConfigError.Create('Required config key "' + AKey + '" is empty');
end;

function TConfig.GetIntRequired(const AKey: string): Int64;
var
  LIdx: Integer;
  LResolved: Boolean;
  LText: string;
begin
  RequireConfigKey(AKey);
  LResolved := False;
  FLock.AcquireRead;
  try
    LIdx := FindIndex(AKey);
    if LIdx < 0 then
      raise EConfigError.Create('Required config key "' + AKey + '" is missing');

    LResolved := TryGetResolvedEntryFastLocked(LIdx, LText);
  finally
    FLock.ReleaseRead;
  end;

  if (not LResolved) and (not TryGetRequiredValue(AKey, LText)) then
    raise EConfigError.Create('Required config key "' + AKey + '" is missing');
  if IsConfigBlankText(LText) then
    raise EConfigError.Create('Required config key "' + AKey + '" is empty');

  if not TryParseConfigIntText(LText, Result) then
    raise EConfigError.Create('Required config key "' + AKey + '" is not an integer');
end;

function TConfig.GetBoolRequired(const AKey: string): Boolean;
var
  LIdx: Integer;
  LResolved: Boolean;
  LText: string;
begin
  RequireConfigKey(AKey);
  LResolved := False;
  FLock.AcquireRead;
  try
    LIdx := FindIndex(AKey);
    if LIdx < 0 then
      raise EConfigError.Create('Required config key "' + AKey + '" is missing');

    LResolved := TryGetResolvedEntryFastLocked(LIdx, LText);
  finally
    FLock.ReleaseRead;
  end;

  if (not LResolved) and (not TryGetRequiredValue(AKey, LText)) then
    raise EConfigError.Create('Required config key "' + AKey + '" is missing');
  if IsConfigBlankText(LText) then
    raise EConfigError.Create('Required config key "' + AKey + '" is empty');

  if not TryParseConfigBoolText(LText, Result) then
    raise EConfigError.Create('Required config key "' + AKey + '" is not a boolean');
end;

function TConfig.GetFloatRequired(const AKey: string): Double;
var
  LIdx: Integer;
  LResolved: Boolean;
  LText: string;
begin
  RequireConfigKey(AKey);
  LResolved := False;
  FLock.AcquireRead;
  try
    LIdx := FindIndex(AKey);
    if LIdx < 0 then
      raise EConfigError.Create('Required config key "' + AKey + '" is missing');

    LResolved := TryGetResolvedEntryFastLocked(LIdx, LText);
  finally
    FLock.ReleaseRead;
  end;

  if (not LResolved) and (not TryGetRequiredValue(AKey, LText)) then
    raise EConfigError.Create('Required config key "' + AKey + '" is missing');
  if IsConfigBlankText(LText) then
    raise EConfigError.Create('Required config key "' + AKey + '" is empty');

  if not TryParseConfigFloatText(LText, Result) then
    raise EConfigError.Create('Required config key "' + AKey + '" is not a float');
end;

procedure TConfig.Require(const AKeys: array of string);
var
  LI: Integer;
begin
  for LI := 0 to Length(AKeys) - 1 do
    GetStringRequired(AKeys[LI]);
end;

procedure TConfig.ReplaceFrom(AOther: TConfig);
var
  LEntries: array of TConfigEntry;
  LLowerKeys: TStringArray;
  LEntryHasPlaceholder: array of Boolean;
  LCount: Integer;
  LI: Integer;
begin
  if AOther = nil then
    raise ENextPasError.Create('TConfig.ReplaceFrom requires a source config');
  if AOther = Self then
    Exit;

  AOther.FLock.AcquireRead;
  try
    LCount := AOther.FCount;
    SetLength(LEntries, LCount);
    SetLength(LLowerKeys, LCount);
    SetLength(LEntryHasPlaceholder, LCount);
    for LI := 0 to LCount - 1 do
    begin
      LEntries[LI] := AOther.FEntries[LI];
      LLowerKeys[LI] := AOther.FLowerKeys[LI];
      LEntryHasPlaceholder[LI] := AOther.FEntryHasPlaceholder[LI];
    end;
  finally
    AOther.FLock.ReleaseRead;
  end;

  FLock.AcquireWrite;
  try
    FEntries := LEntries;
    FLowerKeys := LLowerKeys;
    FEntryHasPlaceholder := LEntryHasPlaceholder;
    FCount := LCount;
    InvalidateReadCachesLocked;
    RebuildLookupIndex;
  finally
    FLock.ReleaseWrite;
  end;
end;

function TConfig.Has(const AKey: string): Boolean;
begin
  RequireConfigKey(AKey);
  FLock.AcquireRead;
  try
    Result := FindIndexCached(AKey) >= 0;
  finally
    FLock.ReleaseRead;
  end;
end;

function TConfig.GetKeys: TStringArray;
var
  LI: Integer;
begin
  FLock.AcquireRead;
  try
    Result := nil;
    SetLength(Result, FCount);
    for LI := 0 to FCount - 1 do
      Result[LI] := FEntries[LI].Key;
  finally
    FLock.ReleaseRead;
  end;
end;

function TConfig.GetSection(const APrefix: string): TStringArray;
var
  LI, LCount: Integer;
  LSuffix, LChild: string;
begin
  FLock.AcquireRead;
  try
    Result := nil;
    LCount := 0;
    for LI := 0 to FCount - 1 do
      if GetSectionSuffix(FEntries[LI].Key, APrefix, LSuffix) then
      begin
        LChild := DirectChildSegment(LSuffix);
        AddUniqueString(Result, LCount, LChild);
      end;
    SetLength(Result, LCount);
  finally
    FLock.ReleaseRead;
  end;
end;

function TConfig.GetCount: Integer;
begin
  FLock.AcquireRead;
  try
    Result := FCount;
  finally
    FLock.ReleaseRead;
  end;
end;

{ Config facade factories }

function ConfigBuilder: IConfigBuilder;
begin
  Result := nextpas.core.config.builder.ConfigBuilder;
end;

function ConfigLoad(const APath: string; AFormat: TConfigFormat): IConfig;
begin
  Result := nextpas.core.config.builder.ConfigLoad(APath, AFormat);
end;

