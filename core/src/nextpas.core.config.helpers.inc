function GetSectionSuffix(const AKey, APrefix: string; out ASuffix: string): Boolean;
var
  LPrefixLen: Integer;
  LKeyPrefix: string;
  LAKeyCopy: string;
  LAKeyLower: string;
begin
  ASuffix := '';
  if AKey = '' then
    Exit(False);

  if APrefix = '' then
  begin
    ASuffix := AKey;
    Exit(True);
  end;

  LPrefixLen := Length(APrefix);
  if Length(AKey) <= LPrefixLen then
    Exit(False);
  if AKey[LPrefixLen + 1] <> '.' then
    Exit(False);
  LKeyPrefix := LowerCase(Copy(AKey, 1, LPrefixLen));
  LAKeyLower := LowerCase(APrefix);
  if LKeyPrefix <> LAKeyLower then
    Exit(False);

  LAKeyCopy := Copy(AKey, LPrefixLen + 2, Length(AKey) - LPrefixLen - 1);
  ASuffix := LAKeyCopy;
  Result := ASuffix <> '';
end;

function DirectChildSegment(const ASuffix: string): string;
var
  LDotPos: Integer;
begin
  LDotPos := Pos('.', ASuffix);
  if LDotPos > 0 then
    Result := Copy(ASuffix, 1, LDotPos - 1)
  else
    Result := ASuffix;
end;

function DirectArraySegment(const AKey, APrefix: string; out ASegment: string): Boolean;
var
  LSuffix: string;
begin
  Result := False;
  ASegment := '';
  if not GetSectionSuffix(AKey, APrefix, LSuffix) then
    Exit;
  if Pos('.', LSuffix) > 0 then
    Exit;
  ASegment := LSuffix;
  Result := ASegment <> '';
end;

function GetSectionSuffixCached(const AKey, ALowerKey, APrefix,
  ALowerPrefix: string; out ASuffix: string): Boolean;
var
  LPrefixLen: Integer;
begin
  ASuffix := '';
  if AKey = '' then
    Exit(False);

  if APrefix = '' then
  begin
    ASuffix := AKey;
    Exit(True);
  end;

  LPrefixLen := Length(APrefix);
  if Length(AKey) <= LPrefixLen then
    Exit(False);
  if AKey[LPrefixLen + 1] <> '.' then
    Exit(False);
  if Copy(ALowerKey, 1, LPrefixLen) <> ALowerPrefix then
    Exit(False);

  ASuffix := Copy(AKey, LPrefixLen + 2, Length(AKey) - LPrefixLen - 1);
  Result := ASuffix <> '';
end;

function DirectArraySegmentCached(const AKey, ALowerKey, APrefix,
  ALowerPrefix: string; out ASegment: string): Boolean;
var
  LSuffix: string;
begin
  Result := False;
  ASegment := '';
  if not GetSectionSuffixCached(AKey, ALowerKey, APrefix, ALowerPrefix, LSuffix) then
    Exit;
  if Pos('.', LSuffix) > 0 then
    Exit;
  ASegment := LSuffix;
  Result := ASegment <> '';
end;

function StringArrayContains(const AItems: TStringArray; const ACount: Integer;
  const AValue: string): Boolean;
var
  LI: Integer;
  LLower: string;
  LItemLower: string;
begin
  LLower := LowerCase(AValue);
  for LI := 0 to ACount - 1 do
  begin
    LItemLower := LowerCase(AItems[LI]);
    if LItemLower = LLower then
      Exit(True);
  end;
  Result := False;
end;

procedure RequireConfigKey(const AKey: string);
begin
  if AKey = '' then
    raise EConfigError.Create('config key must not be empty');
end;

procedure RequireConfigPrefix(const APrefix: string);
begin
  if APrefix = '' then
    raise EConfigError.Create('config section prefix must not be empty');
end;

procedure RequireConfigEnvPrefix(const APrefix: string);
begin
  if APrefix = '' then
    raise EConfigError.Create('config env prefix must not be empty');
end;

procedure RequireConfigFilePath(const APath: string);
begin
  if APath = '' then
    raise EConfigError.Create(ConfigFilePathEmptyError);
end;

function KeyMatchesSection(const AKey, APrefix: string): Boolean;
var
  LLowerKey: string;
  LLowerPrefix: string;
  LPrefixLen: Integer;
begin
  LLowerKey := LowerCase(AKey);
  LLowerPrefix := LowerCase(APrefix);
  if LLowerKey = LLowerPrefix then
    Exit(True);

  LPrefixLen := Length(APrefix);
  Result := (Length(AKey) > LPrefixLen) and
    (AKey[LPrefixLen + 1] = '.') and
    (Copy(LLowerKey, 1, LPrefixLen) = LLowerPrefix);
end;

procedure AddUniqueString(var AItems: TStringArray; var ACount: Integer;
  const AValue: string);
begin
  if AValue = '' then
    Exit;
  if StringArrayContains(AItems, ACount, AValue) then
    Exit;
  if ACount >= Length(AItems) then
    SetLength(AItems, ACount + 8);
  AItems[ACount] := AValue;
  Inc(ACount);
end;

procedure AddString(var AItems: TStringArray; var ACount: Integer;
  const AValue: string);
begin
  if ACount >= Length(AItems) then
    SetLength(AItems, ACount + 8);
  AItems[ACount] := AValue;
  Inc(ACount);
end;

function IsSupportedConfigFormat(AFormat: TConfigFormat): Boolean;
begin
  Result := (Ord(AFormat) >= Ord(Low(TConfigFormat))) and
    (Ord(AFormat) <= Ord(High(TConfigFormat)));
end;

function TryParseArrayIndex(const AValue: string; out AIndex: Int64): Boolean;
var
  LI: Integer;
begin
  AIndex := 0;
  if AValue = '' then
    Exit(False);
  if (Length(AValue) > 1) and (AValue[1] = '0') then
    Exit(False);
  for LI := 1 to Length(AValue) do
    if (AValue[LI] < '0') or (AValue[LI] > '9') then
      Exit(False);
  Result := TryStrToInt64(AValue, AIndex) and (AIndex >= 0);
end;

procedure AddIndexedValue(var AItems: TIndexedConfigValueArray; var ACount: Integer;
  const AIndex: Int64; const AValue: string);
begin
  if ACount >= Length(AItems) then
    SetLength(AItems, ACount + 8);
  AItems[ACount].Index := AIndex;
  AItems[ACount].Value := AValue;
  Inc(ACount);
end;

procedure AddStringValue(var AItems: TStringArray; var ACount: Integer;
  const AValue: string);
begin
  if ACount >= Length(AItems) then
    SetLength(AItems, ACount + 8);
  AItems[ACount] := AValue;
  Inc(ACount);
end;

function CopyStringArray(const AValues: TStringArray): TStringArray;
var
  LI: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AValues));
  for LI := 0 to High(AValues) do
    Result[LI] := AValues[LI];
end;

function StringArrayIsLiteralOnly(const AValues: TStringArray): Boolean;
var
  LI: Integer;
begin
  for LI := 0 to High(AValues) do
    if Pos('$', AValues[LI]) > 0 then
      Exit(False);
  Result := True;
end;

function IsConfigSpaceChar(const ACh: Char): Boolean; inline;
begin
  Result := Ord(ACh) <= 32;
end;

function LowerAsciiChar(const ACh: Char): Char; inline;
begin
  if (ACh >= 'A') and (ACh <= 'Z') then
    Result := Chr(Ord(ACh) + 32)
  else
    Result := ACh;
end;

function ConfigValueHasPlaceholder(const AValue: string): Boolean; inline;
begin
  Result := Pos('$', AValue) <> 0;
end;

function IsConfigBlankText(const AText: string): Boolean;
var
  LI: Integer;
begin
  for LI := 1 to Length(AText) do
    if not IsConfigSpaceChar(AText[LI]) then
      Exit(False);
  Result := True;
end;

function TryParseConfigBoolSlice(const AText: string; const AStart,
  AEnd: Integer; out AValue: Boolean): Boolean;
var
  LLen: Integer;
begin
  LLen := AEnd - AStart + 1;
  case LLen of
    1:
      case AText[AStart] of
        '1':
          begin
            AValue := True;
            Exit(True);
          end;
        '0':
          begin
            AValue := False;
            Exit(True);
          end;
      end;
    2:
      begin
        if (LowerAsciiChar(AText[AStart]) = 'o') and
           (LowerAsciiChar(AText[AStart + 1]) = 'n') then
        begin
          AValue := True;
          Exit(True);
        end;
        if (LowerAsciiChar(AText[AStart]) = 'n') and
           (LowerAsciiChar(AText[AStart + 1]) = 'o') then
        begin
          AValue := False;
          Exit(True);
        end;
      end;
    3:
      begin
        if (LowerAsciiChar(AText[AStart]) = 'y') and
           (LowerAsciiChar(AText[AStart + 1]) = 'e') and
           (LowerAsciiChar(AText[AStart + 2]) = 's') then
        begin
          AValue := True;
          Exit(True);
        end;
        if (LowerAsciiChar(AText[AStart]) = 'o') and
           (LowerAsciiChar(AText[AStart + 1]) = 'f') and
           (LowerAsciiChar(AText[AStart + 2]) = 'f') then
        begin
          AValue := False;
          Exit(True);
        end;
      end;
    4:
      if (LowerAsciiChar(AText[AStart]) = 't') and
         (LowerAsciiChar(AText[AStart + 1]) = 'r') and
         (LowerAsciiChar(AText[AStart + 2]) = 'u') and
         (LowerAsciiChar(AText[AStart + 3]) = 'e') then
      begin
        AValue := True;
        Exit(True);
      end;
    5:
      if (LowerAsciiChar(AText[AStart]) = 'f') and
         (LowerAsciiChar(AText[AStart + 1]) = 'a') and
         (LowerAsciiChar(AText[AStart + 2]) = 'l') and
         (LowerAsciiChar(AText[AStart + 3]) = 's') and
         (LowerAsciiChar(AText[AStart + 4]) = 'e') then
      begin
        AValue := False;
        Exit(True);
      end;
  end;

  Result := False;
end;

function TryParseConfigBoolText(const AText: string; out AValue: Boolean): Boolean;
var
  LLen: Integer;
  LStart: Integer;
  LEnd: Integer;
begin
  LLen := Length(AText);
  if LLen = 0 then
    Exit(False);

  if (not IsConfigSpaceChar(AText[1])) and
     (not IsConfigSpaceChar(AText[LLen])) then
    Exit(TryParseConfigBoolSlice(AText, 1, LLen, AValue));

  LStart := 1;
  LEnd := LLen;
  while (LStart <= LEnd) and IsConfigSpaceChar(AText[LStart]) do
    Inc(LStart);
  while (LEnd >= LStart) and IsConfigSpaceChar(AText[LEnd]) do
    Dec(LEnd);

  if LStart > LEnd then
    Exit(False);

  Result := TryParseConfigBoolSlice(AText, LStart, LEnd, AValue);
end;

function TryParseConfigIntText(const AText: string; out AValue: Int64): Boolean;
var
  LEnd: Integer;
  LLen: Integer;
  LStart: Integer;
  LTrimmed: string;
begin
  LLen := Length(AText);
  if LLen = 0 then
    Exit(False);

  if (not IsConfigSpaceChar(AText[1])) and
     (not IsConfigSpaceChar(AText[LLen])) then
  begin
    Result := ParseInt64(PAnsiChar(AText), SizeUInt(LLen), AValue);
    if not Result then
      Result := TryStrToInt64(AText, AValue);
    Exit;
  end;

  LStart := 1;
  LEnd := LLen;
  while (LStart <= LEnd) and IsConfigSpaceChar(AText[LStart]) do
    Inc(LStart);
  while (LEnd >= LStart) and IsConfigSpaceChar(AText[LEnd]) do
    Dec(LEnd);
  if LStart > LEnd then
    Exit(False);

  Result := ParseInt64(PAnsiChar(AText) + (LStart - 1),
    SizeUInt(LEnd - LStart + 1), AValue);
  if not Result then
  begin
    LTrimmed := Copy(AText, LStart, LEnd - LStart + 1);
    Result := TryStrToInt64(LTrimmed, AValue);
  end;
end;

function TryParseConfigFloatText(const AText: string; out AValue: Double): Boolean;
var
  LEnd: Integer;
  LLen: Integer;
  LStart: Integer;
  LTrimmed: string;
begin
  LLen := Length(AText);
  if LLen = 0 then
    Exit(False);

  if (not IsConfigSpaceChar(AText[1])) and
     (not IsConfigSpaceChar(AText[LLen])) then
  begin
    Result := ParseDouble(PAnsiChar(AText), SizeUInt(LLen), AValue);
    if not Result then
      Result := TryStrToFloat(AText, AValue);
    Exit;
  end;

  LStart := 1;
  LEnd := LLen;
  while (LStart <= LEnd) and IsConfigSpaceChar(AText[LStart]) do
    Inc(LStart);
  while (LEnd >= LStart) and IsConfigSpaceChar(AText[LEnd]) do
    Dec(LEnd);
  if LStart > LEnd then
    Exit(False);

  Result := ParseDouble(PAnsiChar(AText) + (LStart - 1),
    SizeUInt(LEnd - LStart + 1), AValue);
  if not Result then
  begin
    LTrimmed := Copy(AText, LStart, LEnd - LStart + 1);
    Result := TryStrToFloat(LTrimmed, AValue);
  end;
end;

procedure SortIndexedValues(var AItems: TIndexedConfigValueArray; const ACount: Integer);
var
  LI, LJ: Integer;
  LItem: TIndexedConfigValue;
begin
  for LI := 1 to ACount - 1 do
  begin
    LItem := AItems[LI];
    LJ := LI - 1;
    while (LJ >= 0) and (AItems[LJ].Index > LItem.Index) do
    begin
      AItems[LJ + 1] := AItems[LJ];
      Dec(LJ);
    end;
    AItems[LJ + 1] := LItem;
  end;
end;

procedure CollectStringArrayValues(const AEntries: TConfigEntryArray;
  const ALowerKeys: TStringArray; const ACount: Integer; const APrefix: string;
  out AValues: TStringArray);
var
  LI, LDenseCount, LSparseCount, LJ: Integer;
  LSegment: string;
  LIndex: Int64;
  LLowerPrefix: string;
  LDenseValues: TStringArray;
  LSparseValues: TIndexedConfigValueArray;
  LUseSparse: Boolean;
begin
  LLowerPrefix := LowerCase(APrefix);
  LDenseValues := nil;
  LSparseValues := nil;
  LDenseCount := 0;
  LSparseCount := 0;
  LUseSparse := False;

  for LI := 0 to ACount - 1 do
    if DirectArraySegmentCached(AEntries[LI].Key, ALowerKeys[LI], APrefix,
       LLowerPrefix, LSegment) and TryParseArrayIndex(LSegment, LIndex) then
    begin
      if (not LUseSparse) and (LIndex = LDenseCount) then
        AddStringValue(LDenseValues, LDenseCount, AEntries[LI].Value)
      else
      begin
        if not LUseSparse then
        begin
          for LJ := 0 to LDenseCount - 1 do
            AddIndexedValue(LSparseValues, LSparseCount, LJ, LDenseValues[LJ]);
          LUseSparse := True;
        end;
        AddIndexedValue(LSparseValues, LSparseCount, LIndex, AEntries[LI].Value);
      end;
    end;

  if not LUseSparse then
  begin
    SetLength(LDenseValues, LDenseCount);
    AValues := LDenseValues;
    Exit;
  end;

  SortIndexedValues(LSparseValues, LSparseCount);
  SetLength(AValues, LSparseCount);
  for LI := 0 to LSparseCount - 1 do
    AValues[LI] := LSparseValues[LI].Value;
end;

function FindEntryIndexInSnapshot(const AEntries: TConfigEntryArray;
  const ACount: Integer; const AKey: string): Integer;
var
  LI: Integer;
  LLower: string;
begin
  LLower := LowerCase(AKey);
  for LI := 0 to ACount - 1 do
    if LowerCase(AEntries[LI].Key) = LLower then
      Exit(LI);
  Result := -1;
end;

function FindEntryIndexByLowerKey(const ALowerKeys: TStringArray;
  const ALookupSlots: TLookupSlotArray; const ACount: Integer;
  const ALowerKey: string): Integer; inline;
var
  LI: Integer;
  LIdx: Integer;
  LMask: Integer;
  LSlot: Integer;
  LStored: Integer;
begin
  if ACount <= 0 then
    Exit(-1);

  if Length(ALookupSlots) = 0 then
  begin
    for LI := 0 to ACount - 1 do
      if ALowerKeys[LI] = ALowerKey then
        Exit(LI);
    Exit(-1);
  end;

  LMask := Length(ALookupSlots) - 1;
  LSlot := Integer(Cardinal(WyHashStr32(ALowerKey)) and Cardinal(LMask));
  while True do
  begin
    LStored := ALookupSlots[LSlot];
    if LStored = 0 then
      Exit(-1);

    LIdx := LStored - 1;
    if ALowerKeys[LIdx] = ALowerKey then
      Exit(LIdx);

    LSlot := (LSlot + 1) and LMask;
  end;
end;

function FindEntryIndexInLowerKeys(const ALowerKeys: TStringArray;
  const ALookupSlots: TLookupSlotArray; const ACount: Integer;
  const AKey: string): Integer; inline;
begin
  Result := FindEntryIndexByLowerKey(ALowerKeys, ALookupSlots, ACount, AKey);
  if Result >= 0 then
    Exit;
  Result := FindEntryIndexByLowerKey(ALowerKeys, ALookupSlots, ACount,
    LowerCase(AKey));
end;

function TryFindRecentLookupIndex(AConfig: Pointer;
  const ALowerKeys: TStringArray; const ACount: Integer; const AKey: string;
  out AIndex: Integer): Boolean; inline;
var
  LI: Integer;
  LIdx: Integer;
begin
  LIdx := GRecentLookupHotIndex;
  if (GRecentLookupHotConfig = AConfig) and
     (Cardinal(LIdx) < Cardinal(ACount)) and
     (ALowerKeys[LIdx] = AKey) then
  begin
    AIndex := LIdx;
    Exit(True);
  end;

  for LI := 0 to RecentLookupCacheSize - 1 do
  begin
    if GRecentLookupConfig[LI] <> AConfig then
      Continue;

    LIdx := GRecentLookupIndex[LI];
    if (Cardinal(LIdx) < Cardinal(ACount)) and (ALowerKeys[LIdx] = AKey) then
    begin
      AIndex := LIdx;
      Exit(True);
    end;
  end;

  AIndex := -1;
  Result := False;
end;

procedure StoreRecentLookupIndex(AConfig: Pointer; const AIndex: Integer); inline;
begin
  if AIndex < 0 then
    Exit;

  GRecentLookupHotConfig := AConfig;
  GRecentLookupHotIndex := AIndex;
  GRecentLookupConfig[GRecentLookupNext] := AConfig;
  GRecentLookupIndex[GRecentLookupNext] := AIndex;
  Inc(GRecentLookupNext);
  if GRecentLookupNext >= RecentLookupCacheSize then
    GRecentLookupNext := 0;
end;

procedure SnapshotConfigEntries(ACfg: TConfig; out AEntries: TConfigEntryArray;
  out ACount: Integer);
var
  LI: Integer;
begin
  ACfg.FLock.AcquireRead;
  try
    ACount := ACfg.FCount;
    SetLength(AEntries, ACount);
    for LI := 0 to ACount - 1 do
      AEntries[LI] := ACfg.FEntries[LI];
  finally
    ACfg.FLock.ReleaseRead;
  end;
end;

function NextConfigPathSegment(const AKey: string; var APos: Integer;
  out ASegment: string): Boolean;
var
  LStart: Integer;
begin
  if APos > Length(AKey) then
    Exit(False);

  LStart := APos;
  while (APos <= Length(AKey)) and (AKey[APos] <> '.') do
    Inc(APos);
  ASegment := Copy(AKey, LStart, APos - LStart);
  if APos <= Length(AKey) then
    Inc(APos);
  Result := True;
end;

function DisplayConfigPath(const APath: string): string;
begin
  if APath = '' then
    Result := '(root)'
  else
    Result := APath;
end;

procedure RequireHierarchicalConfigPath(const AKey: string);
begin
  if (AKey = '') or (AKey[1] = '.') or
    (AKey[Length(AKey)] = '.') or (Pos('..', AKey) > 0) then
    raise EConfigError.Create('config key "' + AKey +
      '" cannot be exported as hierarchical config: empty path segment is not representable');
end;

function FindPlaceholderEnd(const AValue: string; const AStart: Integer): Integer;
begin
  Result := AStart;
  while (Result <= Length(AValue)) and (AValue[Result] <> '}') do
    Inc(Result);
  if Result > Length(AValue) then
    Result := 0;
end;

function ConfigKeyStackContains(const AStack: TStringArray; const ALowerKey: string): Boolean;
var
  LI: Integer;
begin
  for LI := 0 to Length(AStack) - 1 do
    if AStack[LI] = ALowerKey then
      Exit(True);
  Result := False;
end;

procedure PushConfigKey(var AStack: TStringArray; const ALowerKey: string);
var
  LLen: Integer;
begin
  LLen := Length(AStack);
  SetLength(AStack, LLen + 1);
  AStack[LLen] := ALowerKey;
end;

procedure PopConfigKey(var AStack: TStringArray);
begin
  if Length(AStack) > 0 then
    SetLength(AStack, Length(AStack) - 1);
end;

function InterpolateConfigValueTracked(const AEntries: TConfigEntryArray;
  const ALowerKeys: TStringArray; const ALookupSlots: TLookupSlotArray;
  const ACount: Integer; const AValue: string; var AStack: TStringArray;
  const AFailOnUnresolved: Boolean; const ARequiredKey: string;
  out ACacheable: Boolean): string; forward;

function InterpolateConfigValue(const AEntries: TConfigEntryArray;
  const ALowerKeys: TStringArray; const ALookupSlots: TLookupSlotArray;
  const ACount: Integer; const AValue: string; var AStack: TStringArray;
  const AFailOnUnresolved: Boolean; const ARequiredKey: string): string;
var
  LCacheable: Boolean;
begin
  Result := InterpolateConfigValueTracked(AEntries, ALowerKeys, ALookupSlots,
    ACount, AValue, AStack, AFailOnUnresolved, ARequiredKey, LCacheable);
end;

function ResolveConfigEntryByIndexTracked(const AEntries: TConfigEntryArray;
  const ALowerKeys: TStringArray; const ALookupSlots: TLookupSlotArray;
  const ACount: Integer; const AIndex: Integer; var AStack: TStringArray;
  const AFailOnUnresolved: Boolean; const ARequiredKey: string;
  out ACacheable: Boolean): string;
var
  LKey: string;
  LLowerKey: string;
  LValue: string;
begin
  LKey := AEntries[AIndex].Key;
  LLowerKey := ALowerKeys[AIndex];
  LValue := AEntries[AIndex].Value;
  if Pos('$', LValue) = 0 then
  begin
    ACacheable := True;
    Exit(LValue);
  end;

  if ConfigKeyStackContains(AStack, LLowerKey) then
    raise EConfigError.Create('Config interpolation cycle at key "' + LKey + '"');

  PushConfigKey(AStack, LLowerKey);
  try
    Result := InterpolateConfigValueTracked(AEntries, ALowerKeys, ALookupSlots,
      ACount, LValue, AStack, AFailOnUnresolved, ARequiredKey, ACacheable);
  finally
    PopConfigKey(AStack);
  end;
end;

function ResolveConfigEntryByIndex(const AEntries: TConfigEntryArray;
  const ALowerKeys: TStringArray; const ALookupSlots: TLookupSlotArray;
  const ACount: Integer; const AIndex: Integer; var AStack: TStringArray;
  const AFailOnUnresolved: Boolean; const ARequiredKey: string): string;
var
  LCacheable: Boolean;
begin
  Result := ResolveConfigEntryByIndexTracked(AEntries, ALowerKeys, ALookupSlots,
    ACount, AIndex, AStack, AFailOnUnresolved, ARequiredKey, LCacheable);
end;

function ResolveConfigKeyInEntriesTracked(const AEntries: TConfigEntryArray;
  const ALowerKeys: TStringArray; const ALookupSlots: TLookupSlotArray;
  const ACount: Integer; const AKey: string; out AValue: string;
  var AStack: TStringArray; const AFailOnUnresolved: Boolean;
  const ARequiredKey: string; out ACacheable: Boolean): Boolean;
var
  LIdx: Integer;
begin
  LIdx := FindEntryIndexInLowerKeys(ALowerKeys, ALookupSlots, ACount, AKey);
  Result := LIdx >= 0;
  if Result then
    AValue := ResolveConfigEntryByIndexTracked(AEntries, ALowerKeys,
      ALookupSlots, ACount, LIdx, AStack, AFailOnUnresolved, ARequiredKey,
      ACacheable)
  else
  begin
    AValue := '';
    ACacheable := False;
  end;
end;

function ResolvePlaceholderTracked(const AEntries: TConfigEntryArray;
  const ALowerKeys: TStringArray; const ALookupSlots: TLookupSlotArray;
  const ACount: Integer; const AName: string; var AStack: TStringArray;
  out AValue: string;
  const AFailOnUnresolved: Boolean; const ARequiredKey: string;
  out ACacheable: Boolean): Boolean;
begin
  if AName = '' then
  begin
    AValue := '';
    ACacheable := False;
    Exit(False);
  end;

  if ResolveConfigKeyInEntriesTracked(AEntries, ALowerKeys, ALookupSlots,
    ACount, AName, AValue, AStack, AFailOnUnresolved, ARequiredKey,
    ACacheable) then
    Exit(True);

  if nextpas.core.os.env.HasEnv(AName) then
  begin
    AValue := nextpas.core.os.env.GetEnv(AName);
    ACacheable := False;
    Exit(True);
  end;

  AValue := '';
  ACacheable := False;
  Result := False;
end;

function ResolvePlaceholder(const AEntries: TConfigEntryArray;
  const ALowerKeys: TStringArray; const ALookupSlots: TLookupSlotArray;
  const ACount: Integer; const AName: string; var AStack: TStringArray;
  out AValue: string;
  const AFailOnUnresolved: Boolean; const ARequiredKey: string): Boolean;
var
  LCacheable: Boolean;
begin
  Result := ResolvePlaceholderTracked(AEntries, ALowerKeys, ALookupSlots,
    ACount, AName, AStack, AValue, AFailOnUnresolved, ARequiredKey,
    LCacheable);
end;

function InterpolateConfigValueTracked(const AEntries: TConfigEntryArray;
  const ALowerKeys: TStringArray; const ALookupSlots: TLookupSlotArray;
  const ACount: Integer; const AValue: string; var AStack: TStringArray;
  const AFailOnUnresolved: Boolean; const ARequiredKey: string;
  out ACacheable: Boolean): string;
var
  LI: Integer;
  LEnd: Integer;
  LName: string;
  LResolved: string;
  LPartCacheable: Boolean;
begin
  if Pos('$', AValue) = 0 then
  begin
    ACacheable := True;
    Exit(AValue);
  end;

  ACacheable := True;
  Result := '';
  LI := 1;
  while LI <= Length(AValue) do
  begin
    if (AValue[LI] = '$') and (LI < Length(AValue)) and (AValue[LI + 1] = '$') and
       (LI + 2 <= Length(AValue)) and (AValue[LI + 2] = '{') then
    begin
      Result := Result + '${';
      Inc(LI, 3);
    end
    else if (AValue[LI] = '$') and (LI < Length(AValue)) and (AValue[LI + 1] = '{') then
    begin
      LEnd := FindPlaceholderEnd(AValue, LI + 2);
      if LEnd = 0 then
      begin
        Result := Result + AValue[LI];
        Inc(LI);
      end
      else
      begin
        LName := Copy(AValue, LI + 2, LEnd - LI - 2);
        if ResolvePlaceholderTracked(AEntries, ALowerKeys, ALookupSlots,
          ACount, LName, AStack, LResolved, AFailOnUnresolved, ARequiredKey,
          LPartCacheable) then
        begin
          Result := Result + LResolved;
          if not LPartCacheable then
            ACacheable := False;
        end
        else if AFailOnUnresolved then
        begin
          ACacheable := False;
          raise EConfigError.Create('Required config key "' + ARequiredKey +
            '" has unresolved placeholder');
        end
        else
        begin
          Result := Result + '${' + LName + '}';
          ACacheable := False;
        end;
        LI := LEnd + 1;
      end;
    end
    else
    begin
      Result := Result + AValue[LI];
      Inc(LI);
    end;
  end;
end;

