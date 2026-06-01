unit nextpas.core.config;
{**
 * @desc 配置管理模块。支持多源加载（INI/JSON/YAML/TOML/环境变量），类型安全读取，
 *       分层覆盖（后加载覆盖先加载）。零 SysUtils 依赖，属于 L3。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.conv,
  nextpas.core.ini,
  nextpas.core.json,
  nextpas.core.json.value,
  nextpas.core.json.types,
  nextpas.core.os.env,
  nextpas.core.platform.watch,
  nextpas.core.sync,
  nextpas.core.errors;

type
  TStringArray = array of string;

  TConfigEntry = record
    Key: string;
    Value: string;
  end;

  TConfig = class
  private
    FLock: IRWLock;
    FEntries: array of TConfigEntry;
    FCount: Integer;
    procedure SetValue(const AKey, AValue: string);
    procedure SetValueUnlocked(const AKey, AValue: string);
    function FindIndex(const AKey: string): Integer;
    function GetCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure LoadFromIni(const AContent: string);
    procedure LoadFromJson(const AContent: string);
    procedure LoadFromYaml(const AContent: string);
    procedure LoadFromToml(const AContent: string);
    procedure LoadFromEnv(const APrefix: string);
    procedure SetDefault(const AKey, AValue: string);

    function GetString(const AKey: string; const ADefault: string = ''): string;
    function GetInt(const AKey: string; ADefault: Int64 = 0): Int64;
    function GetBool(const AKey: string; ADefault: Boolean = False): Boolean;
    function GetFloat(const AKey: string; ADefault: Double = 0.0): Double;

    procedure ReplaceFrom(AOther: TConfig);
    function Has(const AKey: string): Boolean;
    function GetKeys: TStringArray;
    property Count: Integer read GetCount;
  end;

  TConfigFormat = (cfIni, cfJson, cfYaml, cfToml);
  TConfigReloadEvent = procedure(ASender: TConfig) of object;

  TConfigWatcher = class
  private
    FConfig: TConfig;
    FFilePath: string;
    FFormat: TConfigFormat;
    FWatcher: TPlatformWatcher;
    FLastMtime: Int64;
    FLastSize: Int64;
    FOnReload: TConfigReloadEvent;
    FActive: Boolean;
    function GetFileMtime: Int64;
    function GetFileStat(out AMtime, ASize: Int64): Boolean;
    procedure DoReload;
  public
    constructor Create(AConfig: TConfig; const AFilePath: string; AFormat: TConfigFormat);
    destructor Destroy; override;
    function CheckReload: Boolean;
    property OnReload: TConfigReloadEvent read FOnReload write FOnReload;
  end;

implementation

uses
  nextpas.core.fs,
  nextpas.core.platform.files,
  nextpas.core.platform.files.base;

{$IFDEF NEXTPAS_UNIX}
var
  environ: PPAnsiChar; cvar; external;
{$ENDIF}

{ TConfig }

constructor TConfig.Create;
begin
  inherited Create;
  FLock := RWLock;
  FCount := 0;
  SetLength(FEntries, 0);
end;

destructor TConfig.Destroy;
begin
  FEntries := nil;
  inherited Destroy;
end;

function TConfig.FindIndex(const AKey: string): Integer;
var
  LI: Integer;
  LLower: string;
begin
  LLower := LowerCase(AKey);
  for LI := 0 to FCount - 1 do
    if LowerCase(FEntries[LI].Key) = LLower then
      Exit(LI);
  Result := -1;
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
begin
  LIdx := FindIndex(AKey);
  if LIdx >= 0 then
    FEntries[LIdx].Value := AValue
  else
  begin
    if FCount >= Length(FEntries) then
      SetLength(FEntries, FCount + 16);
    FEntries[FCount].Key := AKey;
    FEntries[FCount].Value := AValue;
    Inc(FCount);
  end;
end;

procedure TConfig.LoadFromIni(const AContent: string);
var
  LIni: TIniFile;
  LSections: nextpas.core.ini.TStringArray;
  LKeys: nextpas.core.ini.TStringArray;
  LI, LJ: Integer;
  LSection, LKey, LFullKey, LValue: string;
begin
  LIni := TIniFile.Create;
  try
    LIni.LoadFromString(AContent);
    LSections := LIni.GetSections;

    FLock.AcquireWrite;
    try
      { Global section (no section header) }
      LKeys := LIni.GetKeys('');
      for LI := 0 to Length(LKeys) - 1 do
      begin
        LValue := LIni.ReadString('', LKeys[LI], '');
        SetValueUnlocked(LKeys[LI], LValue);
      end;
      { Named sections: section.key }
      for LI := 0 to Length(LSections) - 1 do
      begin
        LSection := LSections[LI];
        LKeys := LIni.GetKeys(LSection);
        for LJ := 0 to Length(LKeys) - 1 do
        begin
          LKey := LKeys[LJ];
          LFullKey := LSection + '.' + LKey;
          LValue := LIni.ReadString(LSection, LKey, '');
          SetValueUnlocked(LFullKey, LValue);
        end;
      end;
    finally
      FLock.ReleaseWrite;
    end;
  finally
    LIni.Free;
  end;
end;

procedure TConfig.LoadFromJson(const AContent: string);
var
  LDoc: IJsonDocument;
  LRoot: TJsonValue;
  LI: UInt32;
  LKey, LValue: string;
  LValNode: TJsonValue;
begin
  LDoc := JsonParse(AContent);
  if LDoc.HasError then
    Exit;
  LRoot := LDoc.Root;
  if not LRoot.IsObject then
    Exit;

  FLock.AcquireWrite;
  try
    for LI := 0 to LRoot.ObjectLen - 1 do
    begin
      LKey := LRoot.ObjectKeyAt(LI).ToString;
      LValNode := LRoot.ObjectValueAt(LI);
      case LValNode.Kind of
        jnkString: LValue := LValNode.AsStr.ToString;
        jnkInt: LValue := IntToStr(LValNode.AsInt);
        jnkReal: LValue := FloatToStr(LValNode.AsFloat);
        jnkBool:
          if LValNode.AsBool then LValue := 'true'
          else LValue := 'false';
        jnkNull: LValue := '';
      else
        LValue := '';
      end;
      SetValueUnlocked(LKey, LValue);
    end;
  finally
    FLock.ReleaseWrite;
  end;
end;

procedure TConfig.LoadFromYaml(const AContent: string);
var
  LPos, LLen, LLineStart, LLineEnd: Integer;
  LLine, LKey, LValue: string;
  LColonPos: Integer;
begin
  LLen := Length(AContent);
  LPos := 1;

  FLock.AcquireWrite;
  try
    while LPos <= LLen do
    begin
      { Find line boundaries }
      LLineStart := LPos;
      while (LPos <= LLen) and (AContent[LPos] <> #10) and (AContent[LPos] <> #13) do
        Inc(LPos);
      LLineEnd := LPos - 1;
      { Skip line ending }
      if (LPos <= LLen) and (AContent[LPos] = #13) then
        Inc(LPos);
      if (LPos <= LLen) and (AContent[LPos] = #10) then
        Inc(LPos);

      LLine := Trim(Copy(AContent, LLineStart, LLineEnd - LLineStart + 1));
      { Skip empty lines and comments }
      if (LLine = '') or (LLine[1] = '#') then
        Continue;

      { Find colon separator }
      LColonPos := Pos(':', LLine);
      if LColonPos < 2 then
        Continue;

      LKey := Trim(Copy(LLine, 1, LColonPos - 1));
      LValue := Trim(Copy(LLine, LColonPos + 1, Length(LLine) - LColonPos));
      { Strip surrounding quotes }
      if (Length(LValue) >= 2) and (LValue[1] = '"') and (LValue[Length(LValue)] = '"') then
        LValue := Copy(LValue, 2, Length(LValue) - 2)
      else if (Length(LValue) >= 2) and (LValue[1] = '''') and (LValue[Length(LValue)] = '''') then
        LValue := Copy(LValue, 2, Length(LValue) - 2);

      SetValueUnlocked(LKey, LValue);
    end;
  finally
    FLock.ReleaseWrite;
  end;
end;

procedure TConfig.LoadFromToml(const AContent: string);
var
  LPos, LLen, LLineStart, LLineEnd: Integer;
  LLine, LSection, LKey, LValue, LFullKey: string;
  LEqPos: Integer;
begin
  LLen := Length(AContent);
  LPos := 1;
  LSection := '';

  FLock.AcquireWrite;
  try
    while LPos <= LLen do
    begin
      { Find line boundaries }
      LLineStart := LPos;
      while (LPos <= LLen) and (AContent[LPos] <> #10) and (AContent[LPos] <> #13) do
        Inc(LPos);
      LLineEnd := LPos - 1;
      { Skip line ending }
      if (LPos <= LLen) and (AContent[LPos] = #13) then
        Inc(LPos);
      if (LPos <= LLen) and (AContent[LPos] = #10) then
        Inc(LPos);

      LLine := Trim(Copy(AContent, LLineStart, LLineEnd - LLineStart + 1));
      { Skip empty lines and comments }
      if (LLine = '') or (LLine[1] = '#') then
        Continue;

      { Section header [name] }
      if (LLine[1] = '[') and (LLine[Length(LLine)] = ']') then
      begin
        LSection := Trim(Copy(LLine, 2, Length(LLine) - 2));
        Continue;
      end;

      { key = value }
      LEqPos := Pos('=', LLine);
      if LEqPos < 2 then
        Continue;

      LKey := Trim(Copy(LLine, 1, LEqPos - 1));
      LValue := Trim(Copy(LLine, LEqPos + 1, Length(LLine) - LEqPos));
      { Strip surrounding quotes }
      if (Length(LValue) >= 2) and (LValue[1] = '"') and (LValue[Length(LValue)] = '"') then
        LValue := Copy(LValue, 2, Length(LValue) - 2)
      else if (Length(LValue) >= 2) and (LValue[1] = '''') and (LValue[Length(LValue)] = '''') then
        LValue := Copy(LValue, 2, Length(LValue) - 2);

      if LSection <> '' then
        LFullKey := LSection + '.' + LKey
      else
        LFullKey := LKey;
      SetValueUnlocked(LFullKey, LValue);
    end;
  finally
    FLock.ReleaseWrite;
  end;
end;

procedure TConfig.LoadFromEnv(const APrefix: string);
var
  LPtr: PPAnsiChar;
  LEntry, LName, LValue, LKey: string;
  LEqPos: Integer;
  LPrefixLen: Integer;
begin
  LPrefixLen := Length(APrefix);
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
      if (LPrefixLen = 0) or
         ((Length(LName) > LPrefixLen) and
          (Copy(LName, 1, LPrefixLen) = APrefix)) then
      begin
        if LPrefixLen > 0 then
          LKey := LowerCase(Copy(LName, LPrefixLen + 1, Length(LName) - LPrefixLen))
        else
          LKey := LowerCase(LName);
        SetValueUnlocked(LKey, LValue);
      end;
    end;
    Inc(LPtr);
  end;
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  { Windows: use GetEnvironmentStrings API — simplified: iterate known prefix }
  { For now, use envp from RTL }
  var LEnvBlock: PAnsiChar;
  LEnvBlock := GetEnvironmentStringsA;
  if LEnvBlock <> nil then
  begin
    LPtr := PPAnsiChar(@LEnvBlock);
    while LEnvBlock^ <> #0 do
    begin
      LEntry := string(LEnvBlock);
      LEqPos := Pos('=', LEntry);
      if LEqPos > 1 then
      begin
        LName := Copy(LEntry, 1, LEqPos - 1);
        LValue := Copy(LEntry, LEqPos + 1, Length(LEntry) - LEqPos);
        if (LPrefixLen = 0) or
           ((Length(LName) > LPrefixLen) and
            (Copy(LName, 1, LPrefixLen) = APrefix)) then
        begin
          if LPrefixLen > 0 then
            LKey := LowerCase(Copy(LName, LPrefixLen + 1, Length(LName) - LPrefixLen))
          else
            LKey := LowerCase(LName);
          SetValueUnlocked(LKey, LValue);
        end;
      end;
      while LEnvBlock^ <> #0 do Inc(LEnvBlock);
      Inc(LEnvBlock);
    end;
    FreeEnvironmentStringsA(LEnvBlock);
  end;
  {$ENDIF}
  finally
    FLock.ReleaseWrite;
  end;
end;

procedure TConfig.SetDefault(const AKey, AValue: string);
begin
  FLock.AcquireWrite;
  try
    if FindIndex(AKey) < 0 then
      SetValueUnlocked(AKey, AValue);
  finally
    FLock.ReleaseWrite;
  end;
end;

function TConfig.GetString(const AKey: string; const ADefault: string): string;
var
  LIdx: Integer;
begin
  FLock.AcquireRead;
  try
    LIdx := FindIndex(AKey);
    if LIdx >= 0 then
      Result := FEntries[LIdx].Value
    else
      Result := ADefault;
  finally
    FLock.ReleaseRead;
  end;
end;

function TConfig.GetInt(const AKey: string; ADefault: Int64): Int64;
var
  LIdx: Integer;
  LVal: Int64;
begin
  FLock.AcquireRead;
  try
    LIdx := FindIndex(AKey);
    if LIdx < 0 then
      Exit(ADefault);
    if TryStrToInt64(FEntries[LIdx].Value, LVal) then
      Result := LVal
    else
      Result := ADefault;
  finally
    FLock.ReleaseRead;
  end;
end;

function TConfig.GetBool(const AKey: string; ADefault: Boolean): Boolean;
var
  LIdx: Integer;
  LStr: string;
begin
  FLock.AcquireRead;
  try
    LIdx := FindIndex(AKey);
    if LIdx < 0 then
      Exit(ADefault);
    LStr := LowerCase(Trim(FEntries[LIdx].Value));
    if (LStr = 'true') or (LStr = '1') or (LStr = 'yes') or (LStr = 'on') then
      Result := True
    else if (LStr = 'false') or (LStr = '0') or (LStr = 'no') or (LStr = 'off') then
      Result := False
    else
      Result := ADefault;
  finally
    FLock.ReleaseRead;
  end;
end;

function TConfig.GetFloat(const AKey: string; ADefault: Double): Double;
var
  LIdx: Integer;
  LVal: Double;
begin
  FLock.AcquireRead;
  try
    LIdx := FindIndex(AKey);
    if LIdx < 0 then
      Exit(ADefault);
    if TryStrToFloat(FEntries[LIdx].Value, LVal) then
      Result := LVal
    else
      Result := ADefault;
  finally
    FLock.ReleaseRead;
  end;
end;

procedure TConfig.ReplaceFrom(AOther: TConfig);
var
  LEntries: array of TConfigEntry;
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
    for LI := 0 to LCount - 1 do
      LEntries[LI] := AOther.FEntries[LI];
  finally
    AOther.FLock.ReleaseRead;
  end;

  FLock.AcquireWrite;
  try
    FEntries := LEntries;
    FCount := LCount;
  finally
    FLock.ReleaseWrite;
  end;
end;

function TConfig.Has(const AKey: string): Boolean;
begin
  FLock.AcquireRead;
  try
    Result := FindIndex(AKey) >= 0;
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

function TConfig.GetCount: Integer;
begin
  FLock.AcquireRead;
  try
    Result := FCount;
  finally
    FLock.ReleaseRead;
  end;
end;

{ TConfigWatcher }

constructor TConfigWatcher.Create(AConfig: TConfig; const AFilePath: string;
  AFormat: TConfigFormat);
var
  LCanStat: Boolean;
begin
  inherited Create;
  if AConfig = nil then
    raise ENextPasError.Create('TConfigWatcher requires a config instance');
  if AFilePath = '' then
    raise ENextPasError.Create('TConfigWatcher requires a file path');

  FConfig := AConfig;
  FFilePath := AFilePath;
  FFormat := AFormat;
  FLastMtime := -1;
  FLastSize := -1;
  FillChar(FWatcher, SizeOf(FWatcher), 0);

  LCanStat := GetFileStat(FLastMtime, FLastSize);
  FActive := LCanStat and (platform_watch_create(FWatcher) = 0);
  if FActive then
  begin
    FActive := platform_watch_add(FWatcher, PAnsiChar(FFilePath)) >= 0;
    if not FActive then
      platform_watch_close(FWatcher);
  end;
end;

destructor TConfigWatcher.Destroy;
begin
  if FActive then
    platform_watch_close(FWatcher);
  inherited Destroy;
end;

function TConfigWatcher.GetFileMtime: Int64;
var
  LSize: Int64;
begin
  if not GetFileStat(Result, LSize) then
    Result := -1;
end;

function TConfigWatcher.GetFileStat(out AMtime, ASize: Int64): Boolean;
var
  LStat: TPlatformFileStat;
begin
  Result := platform_file_stat(PAnsiChar(FFilePath), LStat) = 0;
  if Result then
  begin
    AMtime := LStat.ModTime;
    ASize := LStat.Size;
  end
  else
  begin
    AMtime := -1;
    ASize := -1;
  end;
end;

procedure TConfigWatcher.DoReload;
var
  LContent: string;
  LConfig: TConfig;
begin
  LContent := ReadFileText(FFilePath);
  LConfig := TConfig.Create;
  try
    case FFormat of
      cfIni: LConfig.LoadFromIni(LContent);
      cfJson: LConfig.LoadFromJson(LContent);
      cfYaml: LConfig.LoadFromYaml(LContent);
      cfToml: LConfig.LoadFromToml(LContent);
    end;
    FConfig.ReplaceFrom(LConfig);
  finally
    LConfig.Free;
  end;
end;

function TConfigWatcher.CheckReload: Boolean;
var
  LEvent: TPlatformWatchEvent;
  LMtime: Int64;
  LSize: Int64;
begin
  Result := False;
  if FActive then
    platform_watch_poll(FWatcher, LEvent, 0);

  if not GetFileStat(LMtime, LSize) then
    Exit;
  if (LMtime = FLastMtime) and (LSize = FLastSize) then
    Exit;

  DoReload;
  FLastMtime := LMtime;
  FLastSize := LSize;
  if Assigned(FOnReload) then
    FOnReload(FConfig);
  Result := True;
end;

end.
