function IsConsumedDirective(const ADir: string): Boolean;
begin
  Result := (ADir = 'macro') or (ADir = 'mode') or (ADir = 'modeswitch') or
    (ADir = 'h') or (ADir = 'r') or (ADir = 'j') or (ADir = 'z') or
    (ADir = 'rangechecks') or (ADir = 'overflowchecks') or
    (ADir = 'iochecks') or (ADir = 'objectchecks') or
    (ADir = 'assertions') or (ADir = 'hints') or (ADir = 'warnings') or
    (ADir = 'notes') or (ADir = 'align') or (ADir = 'packrecords') or
    (ADir = 'optimization') or (ADir = 'inline') or (ADir = 'interfaces') or
    (ADir = 'codepage') or (ADir = 'push') or (ADir = 'pop') or
    (ADir = 'warn') or (ADir = 'scopedenums') or (ADir = 'writeableconst') or
    (ADir = 'typedaddress') or (ADir = 'implicitexceptions') or
    (ADir = 'pointermath') or (ADir = 'goto') or (ADir = 'extendedcompat') or
    (ADir = 'bitpacking') or (ADir = 'calling') or (ADir = 'varpropsetter') or
    (ADir = 'coperators') or (ADir = 'fputype') or (ADir = 'safefpuexceptions') or
    (ADir = 'excessprecision') or (ADir = 'longstrings') or
    (ADir = 'openstrings') or (ADir = 'varstringchecks') or
    (ADir = 'typeinfo') or (ADir = 'minenumsize') or (ADir = 'packenum') or
    (ADir = 'packset') or (ADir = 'codealign') or (ADir = 'maxfpuregisters') or
    (ADir = 'memory') or (ADir = 'setc') or (ADir = 'apptype') or
    (ADir = 'pic') or (ADir = 'asmmode');
end;

constructor TDefineTable.Create;
begin
  inherited Create;
  SetLength(FEntries, 0);
  FCount := 0;
end;

function TDefineTable.IndexOf(const AName: string): LongInt;
var
  I: LongInt;
  Norm: string;
begin
  Norm := UpperCase(AName);
  for I := 0 to FCount - 1 do
    if FEntries[I].Name = Norm then
      Exit(I);
  Result := -1;
end;

procedure TDefineTable.Define(const AName: string);
var
  Idx: LongInt;
begin
  if AName = '' then Exit;
  Idx := IndexOf(AName);
  if Idx >= 0 then
  begin
    FEntries[Idx].Value := '';
    FEntries[Idx].HasValue := False;
    Exit;
  end;
  if FCount >= Length(FEntries) then
    SetLength(FEntries, FCount + 16);
  FEntries[FCount].Name := UpperCase(AName);
  FEntries[FCount].Value := '';
  FEntries[FCount].HasValue := False;
  Inc(FCount);
end;

procedure TDefineTable.DefineValue(const AName, AValue: string);
var
  Idx: LongInt;
begin
  if AName = '' then Exit;
  Idx := IndexOf(AName);
  if Idx >= 0 then
  begin
    FEntries[Idx].Value := AValue;
    FEntries[Idx].HasValue := True;
    Exit;
  end;
  if FCount >= Length(FEntries) then
    SetLength(FEntries, FCount + 16);
  FEntries[FCount].Name := UpperCase(AName);
  FEntries[FCount].Value := AValue;
  FEntries[FCount].HasValue := True;
  Inc(FCount);
end;

procedure TDefineTable.Undef(const AName: string);
var
  Idx, J: LongInt;
begin
  Idx := IndexOf(AName);
  if Idx < 0 then Exit;
  for J := Idx to FCount - 2 do
    FEntries[J] := FEntries[J + 1];
  Dec(FCount);
end;

function TDefineTable.IsDefined(const AName: string): Boolean;
begin
  Result := IndexOf(AName) >= 0;
end;

function TDefineTable.TryGetValue(const AName: string; out AValue: string): Boolean;
var
  Idx: LongInt;
begin
  AValue := '';
  Idx := IndexOf(AName);
  if (Idx < 0) or (not FEntries[Idx].HasValue) then
    Exit(False);
  AValue := FEntries[Idx].Value;
  Result := True;
end;

function TDefineTable.ValueOf(const AName: string): string;
var
  Idx: LongInt;
begin
  Idx := IndexOf(AName);
  if (Idx >= 0) and FEntries[Idx].HasValue then
    Result := FEntries[Idx].Value
  else
    Result := '';
end;

procedure TDefineTable.Clear;
begin
  FCount := 0;
  SetLength(FEntries, 0);
end;

function TDefineTable.Count: LongInt;
begin
  Result := FCount;
end;

procedure TDefineTable.SeedFPCDefines;
begin
  Define('FPC');
  DefineValue('FPC_VERSION', '3');
  DefineValue('FPC_RELEASE', '3');
  DefineValue('FPC_PATCH', '1');
  DefineValue('FPC_FULLVERSION', '30301');
  Define('VER3');
  Define('VER3_3');
  Define('VER3_3_1');
  {$ifdef CPUX86_64}
  Define('CPUX86_64');
  Define('CPU64');
  Define('CPUAMD64');
  {$endif}
  {$ifdef CPUAARCH64}
  Define('CPUAARCH64');
  Define('CPU64');
  {$endif}
  {$ifdef LINUX}
  Define('LINUX');
  Define('UNIX');
  {$endif}
  {$ifdef DARWIN}
  Define('DARWIN');
  Define('UNIX');
  {$endif}
  {$ifdef MSWINDOWS}
  Define('MSWINDOWS');
  Define('WINDOWS');
  {$endif}
  {$ifdef ENDIAN_LITTLE}
  Define('ENDIAN_LITTLE');
  {$endif}
  {$ifdef ENDIAN_BIG}
  Define('ENDIAN_BIG');
  {$endif}
  Define('FPC_HAS_TYPE_EXTENDED');
  Define('FPC_HAS_FEATURE_CLASSES');
  Define('FPC_HAS_FEATURE_EXCEPTIONS');
  Define('FPC_HAS_FEATURE_DYNARRAYS');
  Define('FPC_HAS_FEATURE_ANSISTRINGS');
  Define('FPC_HAS_FEATURE_WIDESTRINGS');
  Define('FPC_HAS_FEATURE_VARIANTS');
  Define('FPC_HAS_FEATURE_RTTI');
end;

{ TFileIncludeResolver }

constructor TFileIncludeResolver.Create(const ABaseDir: string);
begin
  inherited Create;
  FBaseDir := ABaseDir;
  FSearchCount := 0;
  SetLength(FSearchPaths, 0);
end;

procedure TFileIncludeResolver.AddSearchPath(const APath: string);
begin
  if FSearchCount >= Length(FSearchPaths) then
    SetLength(FSearchPaths, FSearchCount + 8);
  FSearchPaths[FSearchCount] := APath;
  Inc(FSearchCount);
end;

function TFileIncludeResolver.ResolveInclude(const AName: string;
  const AFromFileId: TCoreId;
  out APath: string; out AContent: string): Boolean;
var
  I: LongInt;
  Candidate: string;
  F: Text;
  Line: string;
begin
  APath := '';
  AContent := '';
  Candidate := FBaseDir + DirectorySeparator + AName;
  if FsExists(Candidate) then
  begin
    APath := Candidate;
    Assign(F, APath);
    {$I-} Reset(F); {$I+}
    if IOResult <> 0 then Exit(False);
    while not System.EOF(F) do
    begin
      ReadLn(F, Line);
      AContent := AContent + Line + #10;
    end;
    Close(F);
    Exit(True);
  end;
  for I := 0 to FSearchCount - 1 do
  begin
    Candidate := FSearchPaths[I] + DirectorySeparator + AName;
    if FsExists(Candidate) then
    begin
      APath := Candidate;
      Assign(F, APath);
      {$I-} Reset(F); {$I+}
      if IOResult <> 0 then Exit(False);
      while not System.EOF(F) do
      begin
        ReadLn(F, Line);
        AContent := AContent + Line + #10;
      end;
      Close(F);
      Exit(True);
    end;
  end;
  Result := False;
end;

{ TPreprocessor }

constructor TPreprocessor.Create(ADefines: TDefineTable; AOwnsDefines: Boolean;
  AIncludeResolver: IIncludeResolver);
begin
  inherited Create;
  FDefines := ADefines;
  FOwnsDefines := AOwnsDefines;
  FIncludeResolver := AIncludeResolver;
  FStackCount := 0;
  SetLength(FStack, 0);
  FOutputCount := 0;
  SetLength(FOutputTokens, 0);
  FCurrentFileId := 0;
  FNextFileId := 1000;
end;

destructor TPreprocessor.Destroy;
begin
  if FOwnsDefines then
    FDefines.Free;
  inherited Destroy;
end;

