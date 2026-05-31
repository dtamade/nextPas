unit nextpas.core.config;
{**
 * @desc 配置管理模块。支持多源加载（INI/JSON/环境变量），类型安全读取，
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
  nextpas.core.errors;

type
  TStringArray = array of string;

  TConfigEntry = record
    Key: string;
    Value: string;
  end;

  TConfig = class
  private
    FEntries: array of TConfigEntry;
    FCount: Integer;
    procedure SetValue(const AKey, AValue: string);
    function FindIndex(const AKey: string): Integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure LoadFromIni(const AContent: string);
    procedure LoadFromJson(const AContent: string);
    procedure LoadFromEnv(const APrefix: string);
    procedure SetDefault(const AKey, AValue: string);

    function GetString(const AKey: string; const ADefault: string = ''): string;
    function GetInt(const AKey: string; ADefault: Int64 = 0): Int64;
    function GetBool(const AKey: string; ADefault: Boolean = False): Boolean;
    function GetFloat(const AKey: string; ADefault: Double = 0.0): Double;

    function Has(const AKey: string): Boolean;
    function GetKeys: TStringArray;
    property Count: Integer read FCount;
  end;

implementation

{$IFDEF NEXTPAS_UNIX}
var
  environ: PPAnsiChar; cvar; external;
{$ENDIF}

{ TConfig }

constructor TConfig.Create;
begin
  inherited Create;
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
    { Global section (no section header) }
    LKeys := LIni.GetKeys('');
    for LI := 0 to Length(LKeys) - 1 do
    begin
      LValue := LIni.ReadString('', LKeys[LI], '');
      SetValue(LKeys[LI], LValue);
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
        SetValue(LFullKey, LValue);
      end;
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
    SetValue(LKey, LValue);
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
        SetValue(LKey, LValue);
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
          SetValue(LKey, LValue);
        end;
      end;
      while LEnvBlock^ <> #0 do Inc(LEnvBlock);
      Inc(LEnvBlock);
    end;
    FreeEnvironmentStringsA(LEnvBlock);
  end;
  {$ENDIF}
end;

procedure TConfig.SetDefault(const AKey, AValue: string);
begin
  if FindIndex(AKey) < 0 then
    SetValue(AKey, AValue);
end;

function TConfig.GetString(const AKey: string; const ADefault: string): string;
var
  LIdx: Integer;
begin
  LIdx := FindIndex(AKey);
  if LIdx >= 0 then
    Result := FEntries[LIdx].Value
  else
    Result := ADefault;
end;

function TConfig.GetInt(const AKey: string; ADefault: Int64): Int64;
var
  LIdx: Integer;
  LVal: Int64;
begin
  LIdx := FindIndex(AKey);
  if LIdx < 0 then
    Exit(ADefault);
  if TryStrToInt64(FEntries[LIdx].Value, LVal) then
    Result := LVal
  else
    Result := ADefault;
end;

function TConfig.GetBool(const AKey: string; ADefault: Boolean): Boolean;
var
  LIdx: Integer;
  LStr: string;
begin
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
end;

function TConfig.GetFloat(const AKey: string; ADefault: Double): Double;
var
  LIdx: Integer;
  LVal: Double;
begin
  LIdx := FindIndex(AKey);
  if LIdx < 0 then
    Exit(ADefault);
  if TryStrToFloat(FEntries[LIdx].Value, LVal) then
    Result := LVal
  else
    Result := ADefault;
end;

function TConfig.Has(const AKey: string): Boolean;
begin
  Result := FindIndex(AKey) >= 0;
end;

function TConfig.GetKeys: TStringArray;
var
  LI: Integer;
begin
  Result := nil;
  SetLength(Result, FCount);
  for LI := 0 to FCount - 1 do
    Result[LI] := FEntries[LI].Key;
end;

end.
