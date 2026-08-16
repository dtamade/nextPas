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

procedure TConfig.LoadFromFile(const APath: string);
var
  LError: string;
begin
  RequireConfigFilePath(APath);
  if not TryLoadFromFile(APath, LError) then
    raise EConfigError.Create(LError);
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
    { 显式格式是调用方契约：解析失败不嗅探降级——热重载撕裂写场景下坏 TOML
      可能被嗅探成合法 INI 而静默替换活配置。容错加载走无格式重载。 }
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

function TConfig.TryLoadFromFile(const APath: string; out AError: string): Boolean;
var
  LContent: string;
  LFormat: TConfigFormat;
  LFirstError: string;
begin
  AError := '';
  if APath = '' then
  begin
    AError := ConfigFilePathEmptyError;
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

  if TryDetectConfigFormat(APath, LFormat) then
  begin
    if TryLoadConfigTextByFormat(Self, LContent, LFormat, AError) then
      Exit(True);
    LFirstError := AError;
    if TrySniffConfigFormat(LContent, LFormat) then
    begin
      { LFormat may equal extension format; retry only after sniff still useful
        when extension load failed for non-format reasons — re-sniff assigns. }
      if TryLoadConfigTextByFormat(Self, LContent, LFormat, AError) then
        Exit(True);
    end;
    AError := FormatConfigFileLoadError(APath, LFirstError);
    Exit(False);
  end;

  if not TrySniffConfigFormat(LContent, LFormat) then
  begin
    AError := FormatConfigFileLoadError(APath,
      'cannot sniff config format from content');
    Exit(False);
  end;
  Result := TryLoadConfigTextByFormat(Self, LContent, LFormat, AError);
  if not Result then
    AError := FormatConfigFileLoadError(APath, AError);
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

function TConfig.LoadFromEnv(const APrefix: string): TStringArray;
var
  LPtr: PPAnsiChar;
  LEnvVars: TStringArray;
  LEnvIndex: Integer;
  LEntry, LName, LValue, LKey: string;
  LEqPos: Integer;
  LKeys: TStringArray;
  LK: Integer;
begin
  Result := nil;
  LK := 0;
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
      begin
        SetValueUnlocked(LKey, LValue);
        SetLength(LKeys, LK + 1);
        LKeys[LK] := LKey;
        Inc(LK);
      end;
    end;
    Inc(LPtr);
  end;
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  LEnvVars := EnvironmentVariables;
  for LEnvIndex := 0 to Length(LEnvVars) - 1 do
  begin
    LEntry := LEnvVars[LEnvIndex];
    LEqPos := Pos('=', LEntry);
    if LEqPos > 0 then
    begin
      LName := Copy(LEntry, 1, LEqPos - 1);
      LValue := Copy(LEntry, LEqPos + 1, Length(LEntry) - LEqPos);
      if TryConfigEnvNameToKey(LName, APrefix, LKey) then
      begin
        SetValueUnlocked(LKey, LValue);
        SetLength(LKeys, LK + 1);
        LKeys[LK] := LKey;
        Inc(LK);
      end;
    end;
  end;
  {$ENDIF}
  finally
    FLock.ReleaseWrite;
  end;
  Result := LKeys;
end;
