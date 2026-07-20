function TConfig.GetString(const AKey: string; const ADefault: string): string;
var
  LFound: Boolean;
  LIdx: Integer;
  LStack: TStringArray;
  LFailUnresolved: Boolean;
begin
  RequireConfigKey(AKey);
  LFailUnresolved := FInterpolationMode = cimStrict;
  LFound := False;
  FLock.AcquireRead;
  try
    LIdx := FindIndexCached(AKey);
    if LIdx >= 0 then
    begin
      LFound := True;
      if FInterpolationMode = cimDisabled then
      begin
        Result := FEntries[LIdx].Value;
        Exit;
      end;
      if TryGetResolvedEntryFastLocked(LIdx, Result) then
        Exit;
    end
    else
    begin
      Result := ADefault;
      if (Pos('$', Result) = 0) or (FInterpolationMode = cimDisabled) then
        Exit;
      LStack := nil;
      Result := InterpolateConfigValue(FEntries, FLowerKeys, FLookupSlots,
        FCount, ADefault, LStack, LFailUnresolved, AKey);
      Exit;
    end;
  finally
    FLock.ReleaseRead;
  end;

  if LFound and TryGetValue(AKey, Result) then
    Exit;

  Result := ADefault;
  if (Pos('$', Result) <> 0) and (FInterpolationMode <> cimDisabled) then
  begin
    FLock.AcquireRead;
    try
      LStack := nil;
      Result := InterpolateConfigValue(FEntries, FLowerKeys, FLookupSlots,
        FCount, ADefault, LStack, LFailUnresolved, AKey);
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
  LFailUnresolved: Boolean;
begin
  if AKey <> '' then
    RequireConfigKey(AKey);
  Result := nil;
  LLowerKey := LowerCase(AKey);
  LFailUnresolved := FInterpolationMode = cimStrict;
  FLock.AcquireRead;
  try
    if HasArrayCacheLocked(LLowerKey) then
    begin
      CopyArrayCacheLocked(LValues, LAllLiteral);
      if LAllLiteral or (FInterpolationMode = cimDisabled) then
      begin
        Result := LValues;
        Exit;
      end;

      SetLength(Result, Length(LValues));
      LStack := nil;
      for LI := 0 to Length(LValues) - 1 do
        Result[LI] := InterpolateConfigValue(FEntries, FLowerKeys, FLookupSlots,
          FCount, LValues[LI], LStack, LFailUnresolved, AKey);
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
    if LAllLiteral or (FInterpolationMode = cimDisabled) then
    begin
      Result := LValues;
      Exit;
    end;

    SetLength(Result, Length(LValues));
    LStack := nil;
    for LI := 0 to Length(LValues) - 1 do
      Result[LI] := InterpolateConfigValue(FEntries, FLowerKeys, FLookupSlots,
        FCount, LValues[LI], LStack, LFailUnresolved, AKey);
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
  LMode: TConfigInterpolationMode;
begin
  if AOther = nil then
    raise ENextPasError.Create('TConfig.ReplaceFrom requires a source config');
  if AOther = Self then
    Exit;

  AOther.FLock.AcquireRead;
  try
    LCount := AOther.FCount;
    LMode := AOther.FInterpolationMode;
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
    FInterpolationMode := LMode;
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

procedure TConfig.SetInterpolationMode(AMode: TConfigInterpolationMode);
begin
  FLock.AcquireWrite;
  try
    if FInterpolationMode = AMode then
      Exit;
    FInterpolationMode := AMode;
    InvalidateInterpolationCacheLocked;
  finally
    FLock.ReleaseWrite;
  end;
end;

function TConfig.GetInterpolationMode: TConfigInterpolationMode;
begin
  FLock.AcquireRead;
  try
    Result := FInterpolationMode;
  finally
    FLock.ReleaseRead;
  end;
end;

function TryParseConfigDurationNs(const AText: string; out ANanos: Int64): Boolean;
var
  LText: string;
  LNum: string;
  LI: Integer;
  LVal: Int64;
  LUnit: string;
  LScale: Int64;
begin
  Result := False;
  ANanos := 0;
  LText := Trim(AText);
  if LText = '' then
    Exit;
  LI := 1;
  if (LI <= Length(LText)) and (LText[LI] = '-') then
    Exit; { negative durations not supported }
  while (LI <= Length(LText)) and (LText[LI] >= '0') and (LText[LI] <= '9') do
    Inc(LI);
  if LI = 1 then
    Exit;
  LNum := Copy(LText, 1, LI - 1);
  if not TryStrToInt64(LNum, LVal) then
    Exit;
  LUnit := LowerCase(Copy(LText, LI, Length(LText) - LI + 1));
  if LUnit = '' then
    LUnit := 's';
  if LUnit = 'ns' then
    LScale := 1
  else if (LUnit = 'us') or (LUnit = 'µs') then
    LScale := 1000
  else if LUnit = 'ms' then
    LScale := 1000000
  else if LUnit = 's' then
    LScale := 1000000000
  else if LUnit = 'm' then
    LScale := Int64(60) * 1000000000
  else if LUnit = 'h' then
    LScale := Int64(3600) * 1000000000
  else
    Exit;
  if (LVal > 0) and (LScale > High(Int64) div LVal) then
    Exit;
  ANanos := LVal * LScale;
  Result := True;
end;

function TConfig.GetDurationNs(const AKey: string; ADefault: Int64): Int64;
var
  LRaw: string;
  LNs: Int64;
begin
  LRaw := GetString(AKey, '');
  if LRaw = '' then
    Exit(ADefault);
  if TryParseConfigDurationNs(LRaw, LNs) then
    Result := LNs
  else
    Result := ADefault;
end;

function TConfig.GetDurationNsRequired(const AKey: string): Int64;
var
  LRaw: string;
  LNs: Int64;
begin
  LRaw := GetStringRequired(AKey);
  if not TryParseConfigDurationNs(LRaw, LNs) then
    raise EConfigError.Create('invalid duration for key "' + AKey + '": ' + LRaw);
  Result := LNs;
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

function ConfigLoad(const APath: string): IConfig;
begin
  Result := nextpas.core.config.builder.ConfigLoad(APath);
end;

function ConfigBorrow(AConfig: TConfig): IConfig;
begin
  Result := nextpas.core.config.builder.ConfigBorrow(AConfig);
end;

function ConfigSection(const AConfig: IConfig; const APrefix: string): IConfig;
begin
  Result := nextpas.core.config.builder.ConfigSection(AConfig, APrefix);
end;

function ConfigSection(AConfig: TConfig; const APrefix: string): IConfig;
begin
  Result := nextpas.core.config.builder.ConfigSection(AConfig, APrefix);
end;
