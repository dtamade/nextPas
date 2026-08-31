constructor TConfig.Create;
begin
  inherited Create;
  FLock := RWLock;
  FCount := 0;
  SetLength(FEntries, 0);
  SetLength(FLowerKeys, 0);
  SetLength(FLookupSlots, 0);
  SetLength(FEntryHasPlaceholder, 0);
  FArrayCacheLowerKey := '';
  SetLength(FArrayCacheValues, 0);
  FArrayCacheAllLiteral := True;
  FArrayCacheValid := False;
  SetLength(FInterpolationCacheValues, 0);
  SetLength(FInterpolationCacheValid, 0);
  FInterpolationMode := cimDefault;
end;

destructor TConfig.Destroy;
begin
  FArrayCacheValues := nil;
  FInterpolationCacheValues := nil;
  FInterpolationCacheValid := nil;
  FEntries := nil;
  FLowerKeys := nil;
  FLookupSlots := nil;
  FEntryHasPlaceholder := nil;
  inherited Destroy;
end;

function LookupSlotCapacityForCount(const ACount: Integer): Integer;
begin
  if ACount <= 0 then
    Exit(0);

  Result := 16;
  while Result < (ACount * 2) do
    Result := Result shl 1;
end;

function TConfig.EnsureLookupCapacity(const AMinCount: Integer): Boolean;
var
  LRequired: Integer;
begin
  LRequired := LookupSlotCapacityForCount(AMinCount);
  if Length(FLookupSlots) >= LRequired then
    Exit(False);

  SetLength(FLookupSlots, LRequired);
  RebuildLookupIndex;
  Result := True;
end;

function TConfig.FindIndexByLowerKey(const ALowerKey: string): Integer; inline;
begin
  Result := FindEntryIndexByLowerKey(FLowerKeys, FLookupSlots, FCount, ALowerKey);
end;

function TConfig.FindIndexCached(const AKey: string): Integer; inline;
begin
  if TryFindRecentLookupIndex(Pointer(Self), FLowerKeys, FCount, AKey, Result) then
    Exit;

  Result := FindIndexByLowerKey(AKey);
  if Result >= 0 then
  begin
    StoreRecentLookupIndex(Pointer(Self), Result);
    Exit;
  end;

  Result := FindIndexByLowerKey(LowerCase(AKey));
  if Result >= 0 then
    StoreRecentLookupIndex(Pointer(Self), Result);
end;

function TConfig.FindIndex(const AKey: string): Integer; inline;
begin
  Result := FindIndexByLowerKey(AKey);
  if Result >= 0 then
    Exit;
  Result := FindIndexByLowerKey(LowerCase(AKey));
end;

procedure TConfig.InvalidateArrayCacheLocked;
begin
  FArrayCacheLowerKey := '';
  FArrayCacheValues := nil;
  FArrayCacheAllLiteral := True;
  FArrayCacheValid := False;
end;

procedure TConfig.InvalidateInterpolationCacheLocked;
begin
  FInterpolationCacheValues := nil;
  FInterpolationCacheValid := nil;
end;

procedure TConfig.InvalidateReadCachesLocked;
begin
  InvalidateArrayCacheLocked;
  InvalidateInterpolationCacheLocked;
end;

function TConfig.HasArrayCacheLocked(const ALowerPrefix: string): Boolean;
begin
  Result := FArrayCacheValid and (FArrayCacheLowerKey = ALowerPrefix);
end;

procedure TConfig.BuildArrayCacheLocked(const APrefix, ALowerPrefix: string);
begin
  CollectStringArrayValues(FEntries, FLowerKeys, FCount, APrefix, FArrayCacheValues);
  FArrayCacheLowerKey := ALowerPrefix;
  FArrayCacheAllLiteral := StringArrayIsLiteralOnly(FArrayCacheValues);
  FArrayCacheValid := True;
end;

procedure TConfig.CopyArrayCacheLocked(out AValues: TStringArray;
  out AAllLiteral: Boolean);
begin
  AValues := CopyStringArray(FArrayCacheValues);
  AAllLiteral := FArrayCacheAllLiteral;
end;

function TConfig.TryGetInterpolationCacheLocked(const AIndex: Integer;
  out AValue: string): Boolean; inline;
begin
  Result := (AIndex >= 0) and
    (AIndex < Length(FInterpolationCacheValid)) and
    (AIndex < Length(FInterpolationCacheValues)) and
    FInterpolationCacheValid[AIndex];
  if Result then
    AValue := FInterpolationCacheValues[AIndex]
  else
    AValue := '';
end;

procedure TConfig.StoreInterpolationCacheLocked(const AIndex: Integer;
  const AValue: string);
var
  LRequired: Integer;
begin
  if AIndex < 0 then
    Exit;

  LRequired := Length(FEntries);
  if Length(FInterpolationCacheValues) < LRequired then
    SetLength(FInterpolationCacheValues, LRequired);
  if Length(FInterpolationCacheValid) < LRequired then
    SetLength(FInterpolationCacheValid, LRequired);

  FInterpolationCacheValues[AIndex] := AValue;
  FInterpolationCacheValid[AIndex] := True;
end;

function TConfig.TryGetResolvedEntryFastLocked(const AIndex: Integer;
  out AValue: string): Boolean; inline;
begin
  if (AIndex < 0) or (AIndex >= FCount) then
  begin
    AValue := '';
    Exit(False);
  end;

  AValue := FEntries[AIndex].Value;
  if not FEntryHasPlaceholder[AIndex] then
    Exit(True);

  Result := TryGetInterpolationCacheLocked(AIndex, AValue);
end;

function TConfig.TryGetValue(const AKey: string; out AValue: string): Boolean;
var
  LIdx: Integer;
  LStack: TStringArray;
  LCacheable: Boolean;
  LFailUnresolved: Boolean;
begin
  FLock.AcquireRead;
  try
    LIdx := FindIndexCached(AKey);
    Result := LIdx >= 0;
    if not Result then
    begin
      AValue := '';
      Exit;
    end;

    if FInterpolationMode = cimDisabled then
    begin
      AValue := FEntries[LIdx].Value;
      Exit;
    end;

    if TryGetResolvedEntryFastLocked(LIdx, AValue) then
      Exit;
  finally
    FLock.ReleaseRead;
  end;

  FLock.AcquireWrite;
  try
    LIdx := FindIndexCached(AKey);
    Result := LIdx >= 0;
    if not Result then
    begin
      AValue := '';
      Exit;
    end;

    if FInterpolationMode = cimDisabled then
    begin
      AValue := FEntries[LIdx].Value;
      Exit;
    end;

    if TryGetResolvedEntryFastLocked(LIdx, AValue) then
      Exit;

    LFailUnresolved := FInterpolationMode = cimStrict;
    LStack := nil;
    AValue := ResolveConfigEntryByIndexTracked(FEntries, FLowerKeys,
      FLookupSlots, FCount, LIdx, LStack, LFailUnresolved, AKey, LCacheable);
    if LCacheable then
      StoreInterpolationCacheLocked(LIdx, AValue);
  finally
    FLock.ReleaseWrite;
  end;
end;

function TConfig.TryGetRequiredValue(const AKey: string; out AValue: string): Boolean;
var
  LIdx: Integer;
  LStack: TStringArray;
  LCacheable: Boolean;
begin
  FLock.AcquireRead;
  try
    LIdx := FindIndexCached(AKey);
    Result := LIdx >= 0;
    if not Result then
    begin
      AValue := '';
      Exit;
    end;

    if FInterpolationMode = cimDisabled then
    begin
      AValue := FEntries[LIdx].Value;
      Exit;
    end;

    if TryGetResolvedEntryFastLocked(LIdx, AValue) then
      Exit;
  finally
    FLock.ReleaseRead;
  end;

  FLock.AcquireWrite;
  try
    LIdx := FindIndexCached(AKey);
    Result := LIdx >= 0;
    if not Result then
    begin
      AValue := '';
      Exit;
    end;

    if FInterpolationMode = cimDisabled then
    begin
      AValue := FEntries[LIdx].Value;
      Exit;
    end;

    if TryGetResolvedEntryFastLocked(LIdx, AValue) then
      Exit;

    LStack := nil;
    AValue := ResolveConfigEntryByIndexTracked(FEntries, FLowerKeys,
      FLookupSlots, FCount, LIdx, LStack, True, AKey, LCacheable);
    if LCacheable then
      StoreInterpolationCacheLocked(LIdx, AValue);
  finally
    FLock.ReleaseWrite;
  end;
end;

procedure TConfig.InsertLookupKey(const ALowerKey: string; const AIndex: Integer);
var
  LMask: Integer;
  LSlot: Integer;
begin
  if Length(FLookupSlots) = 0 then
    Exit;

  LMask := Length(FLookupSlots) - 1;
  LSlot := Integer(Cardinal(WyHashStr32(ALowerKey)) and Cardinal(LMask));
  while FLookupSlots[LSlot] <> 0 do
    LSlot := (LSlot + 1) and LMask;
  FLookupSlots[LSlot] := AIndex + 1;
end;

procedure TConfig.RebuildLookupIndex;
var
  LI: Integer;
  LRequired: Integer;
begin
  LRequired := LookupSlotCapacityForCount(FCount);
  if LRequired = 0 then
  begin
    SetLength(FLookupSlots, 0);
    Exit;
  end;

  if Length(FLookupSlots) <> LRequired then
    SetLength(FLookupSlots, LRequired);

  for LI := 0 to Length(FLookupSlots) - 1 do
    FLookupSlots[LI] := 0;

  for LI := 0 to FCount - 1 do
    InsertLookupKey(FLowerKeys[LI], LI);
end;

procedure TConfig.ClearUnlocked;
begin
  InvalidateReadCachesLocked;
  SetLength(FEntries, 0);
  SetLength(FLowerKeys, 0);
  SetLength(FLookupSlots, 0);
  SetLength(FEntryHasPlaceholder, 0);
  FCount := 0;
end;

procedure TConfig.DeleteIndexUnlocked(AIndex: Integer);
var
  LI: Integer;
begin
  if (AIndex < 0) or (AIndex >= FCount) then
    Exit;

  InvalidateReadCachesLocked;
  for LI := AIndex to FCount - 2 do
  begin
    FEntries[LI] := FEntries[LI + 1];
    FLowerKeys[LI] := FLowerKeys[LI + 1];
    FEntryHasPlaceholder[LI] := FEntryHasPlaceholder[LI + 1];
  end;

  Dec(FCount);
  FEntries[FCount].Key := '';
  FEntries[FCount].Value := '';
  FLowerKeys[FCount] := '';
  FEntryHasPlaceholder[FCount] := False;
end;

procedure TConfig.DeleteKeyUnlocked(const AKey: string);
var
  LIdx: Integer;
begin
  LIdx := FindIndex(AKey);
  if LIdx >= 0 then
  begin
    DeleteIndexUnlocked(LIdx);
    RebuildLookupIndex;
  end;
end;

procedure TConfig.DeleteSectionUnlocked(const APrefix: string);
var
  LI: Integer;
  LChanged: Boolean;
begin
  LChanged := False;
  for LI := FCount - 1 downto 0 do
    if KeyMatchesSection(FEntries[LI].Key, APrefix) then
    begin
      DeleteIndexUnlocked(LI);
      LChanged := True;
    end;

  if LChanged then
    RebuildLookupIndex;
end;

procedure TConfig.SetValue(const AKey, AValue: string);
begin
  FLock.AcquireWrite;
  try
    SetValueUnlocked(AKey, AValue);
  finally
    FLock.ReleaseWrite;
  end;
end;

procedure TConfig.SetValueUnlocked(const AKey, AValue: string);
var
  LIdx: Integer;
  LLowerKey: string;
  LCap: Integer;
begin
  InvalidateReadCachesLocked;
  LLowerKey := LowerCase(AKey);
  LIdx := FindIndexByLowerKey(LLowerKey);
  if LIdx >= 0 then
  begin
    FEntries[LIdx].Value := AValue;
    FEntryHasPlaceholder[LIdx] := ConfigValueHasPlaceholder(AValue);
  end
  else
  begin
    if FCount >= Length(FEntries) then
    begin
      LCap := Length(FEntries);
      if LCap < 16 then
        LCap := 16
      else
        LCap := LCap * 2;
      SetLength(FEntries, LCap);
      SetLength(FLowerKeys, LCap);
      SetLength(FEntryHasPlaceholder, LCap);
    end;
    FEntries[FCount].Key := AKey;
    FEntries[FCount].Value := AValue;
    FLowerKeys[FCount] := LLowerKey;
    FEntryHasPlaceholder[FCount] := ConfigValueHasPlaceholder(AValue);
    Inc(FCount);
    if not EnsureLookupCapacity(FCount) then
      InsertLookupKey(LLowerKey, FCount - 1);
  end;
end;

procedure TConfig.SetString(const AKey, AValue: string);
begin
  RequireConfigKey(AKey);
  SetValue(AKey, AValue);
end;

procedure TConfig.SetInt(const AKey: string; AValue: Int64);
begin
  SetString(AKey, IntToStr(AValue));
end;

procedure TConfig.SetBool(const AKey: string; AValue: Boolean);
begin
  { Canonical config text form is lowercase true/false for format parity. }
  if AValue then
    SetString(AKey, 'true')
  else
    SetString(AKey, 'false');
end;

procedure TConfig.SetFloat(const AKey: string; AValue: Double);
begin
  SetString(AKey, FloatToStr(AValue));
end;

procedure TConfig.SetStringArray(const AKey: string; const AValues: array of string);
var
  LI: Integer;
begin
  RequireConfigKey(AKey);
  FLock.AcquireWrite;
  try
    DeleteSectionUnlocked(AKey);
    for LI := Low(AValues) to High(AValues) do
      SetValueUnlocked(AKey + '.' + IntToStr(LI), AValues[LI]);
  finally
    FLock.ReleaseWrite;
  end;
end;
