procedure TConfig.LoadFromIni(const AContent: string);
var
  LIni: TIniFile;
begin
  LIni := TIniFile.Create;
  try
    LIni.LoadFromString(AContent);
    LoadConfigFromIniFile(Self, LIni);
  finally
    LIni.Free;
  end;
end;

procedure TConfig.LoadFromJson(const AContent: string);
var
  LDoc: IJsonDocument;
begin
  LDoc := JsonParse(AContent);
  if LDoc.HasError then
    raise EConfigError.Create(FormatJsonLoadError(AContent, LDoc.Error));
  LoadConfigFromJsonDocument(Self, LDoc);
end;

procedure TConfig.LoadFromYaml(const AContent: string);
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse(AContent);
  if LDoc.HasError then
    raise EConfigError.Create(FormatYamlLoadError(LDoc.Error));
  LoadConfigFromYamlDocument(Self, LDoc);
end;

procedure TConfig.LoadFromToml(const AContent: string);
var
  LDoc: ITomlDocument;
begin
  LDoc := TomlParse(AContent);
  if LDoc.HasError then
    raise EConfigError.Create(FormatTomlLoadError(LDoc.Error));
  LoadConfigFromTomlDocument(Self, LDoc);
end;

procedure TConfig.LoadFromFile(const APath: string; AFormat: TConfigFormat);
begin
  LoadConfigFileByFormat(Self, APath, AFormat);
end;

function TConfig.TryLoadFromIni(const AContent: string; out AError: string): Boolean;
var
  LIni: TIniFile;
begin
  AError := '';
  LIni := TIniFile.Create;
  try
    try
      if not LIni.TryLoadFromString(AContent, AError) then
      begin
        AError := FormatIniLoadError(AError);
        Exit(False);
      end;
      LoadConfigFromIniFile(Self, LIni);
      AError := '';
      Result := True;
    except
      on E: Exception do
      begin
        AError := E.Message;
        Result := False;
      end;
    end;
  finally
    LIni.Free;
  end;
end;

function TConfig.TryLoadFromJson(const AContent: string; out AError: string): Boolean;
var
  LDoc: IJsonDocument;
begin
  AError := '';
  try
    LDoc := JsonParse(AContent);
    if LDoc.HasError then
    begin
      AError := FormatJsonLoadError(AContent, LDoc.Error);
      Exit(False);
    end;
    LoadConfigFromJsonDocument(Self, LDoc);
    Result := True;
  except
    on E: Exception do
    begin
      AError := E.Message;
      Result := False;
    end;
  end;
end;

function TConfig.TryLoadFromYaml(const AContent: string; out AError: string): Boolean;
var
  LDoc: IYamlDocument;
begin
  AError := '';
  try
    LDoc := YamlParse(AContent);
    if LDoc.HasError then
    begin
      AError := FormatYamlLoadError(LDoc.Error);
      Exit(False);
    end;
    LoadConfigFromYamlDocument(Self, LDoc);
    Result := True;
  except
    on E: Exception do
    begin
      AError := E.Message;
      Result := False;
    end;
  end;
end;

function TConfig.TryLoadFromToml(const AContent: string; out AError: string): Boolean;
var
  LDoc: ITomlDocument;
begin
  AError := '';
  try
    LDoc := TomlParse(AContent);
    if LDoc.HasError then
    begin
      AError := FormatTomlLoadError(LDoc.Error);
      Exit(False);
    end;
    LoadConfigFromTomlDocument(Self, LDoc);
    Result := True;
  except
    on E: Exception do
    begin
      AError := E.Message;
      Result := False;
    end;
  end;
end;

function TConfig.TryLoadFromFile(const APath: string; AFormat: TConfigFormat;
  out AError: string): Boolean;
var
  LContent: string;
begin
  AError := '';
  if APath = '' then
  begin
    AError := ConfigFilePathEmptyError;
    Exit(False);
  end;
  if not IsSupportedConfigFormat(AFormat) then
  begin
    AError := FormatConfigFileLoadError(APath, 'unsupported config format');
    Exit(False);
  end;

  try
    LContent := ReadFileText(APath);
  except
    on E: Exception do
    begin
      AError := FormatConfigFileLoadError(APath, E.Message);
      Exit(False);
    end;
  end;

  try
    Result := TryLoadConfigTextByFormat(Self, LContent, AFormat, AError);
    if not Result then
      AError := FormatConfigFileLoadError(APath, AError);
  except
    on E: Exception do
    begin
      AError := FormatConfigFileLoadError(APath, E.Message);
      Result := False;
    end;
  end;
end;

function TConfig.TryLoadJson(const AContent: string; out AError: string): Boolean;
begin
  Result := TryLoadFromJson(AContent, AError);
end;

function TConfig.TryLoadYaml(const AContent: string; out AError: string): Boolean;
begin
  Result := TryLoadFromYaml(AContent, AError);
end;

function TConfig.TryLoadToml(const AContent: string; out AError: string): Boolean;
begin
  Result := TryLoadFromToml(AContent, AError);
end;

procedure TConfig.LoadFromEnv(const APrefix: string);
var
  LPtr: PPAnsiChar;
  LEnvBase: PAnsiChar;
  LEnvCursor: PAnsiChar;
  LEntry, LName, LValue, LKey: string;
  LEqPos: Integer;
begin
  RequireConfigEnvPrefix(APrefix);
  FLock.AcquireWrite;
  try
  {$IFDEF NEXTPAS_UNIX}
  LPtr := environ;
  if LPtr = nil then Exit;
  while LPtr^ <> nil do
  begin
    LEntry := string(LPtr^);
    LEqPos := Pos('=', LEntry);
    if LEqPos > 0 then
    begin
      LName := Copy(LEntry, 1, LEqPos - 1);
      LValue := Copy(LEntry, LEqPos + 1, Length(LEntry) - LEqPos);
      if TryConfigEnvNameToKey(LName, APrefix, LKey) then
        SetValueUnlocked(LKey, LValue);
    end;
    Inc(LPtr);
  end;
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  LEnvBase := GetEnvironmentStringsA;
  if LEnvBase <> nil then
  begin
    LEnvCursor := LEnvBase;
    while NextConfigWindowsEnvBlockEntry(LEnvCursor, LEntry) do
    begin
      LEqPos := Pos('=', LEntry);
      if LEqPos > 0 then
      begin
        LName := Copy(LEntry, 1, LEqPos - 1);
        LValue := Copy(LEntry, LEqPos + 1, Length(LEntry) - LEqPos);
        if TryConfigEnvNameToKey(LName, APrefix, LKey) then
          SetValueUnlocked(LKey, LValue);
      end;
    end;
    FreeEnvironmentStringsA(LEnvBase);
  end;
  {$ENDIF}
  finally
    FLock.ReleaseWrite;
  end;
end;
