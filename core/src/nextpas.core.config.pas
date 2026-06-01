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

  EConfigError = class(EParseError);

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
    function TryLoadFromIni(const AContent: string; out AError: string): Boolean;
    function TryLoadFromJson(const AContent: string; out AError: string): Boolean;
    function TryLoadFromYaml(const AContent: string; out AError: string): Boolean;
    function TryLoadFromToml(const AContent: string; out AError: string): Boolean;
    function TryLoadJson(const AContent: string; out AError: string): Boolean;
    function TryLoadYaml(const AContent: string; out AError: string): Boolean;
    function TryLoadToml(const AContent: string; out AError: string): Boolean;
    procedure LoadFromEnv(const APrefix: string);
    procedure SetDefault(const AKey, AValue: string);

    function GetString(const AKey: string; const ADefault: string = ''): string;
    function GetStringArray(const AKey: string): TStringArray;
    function GetInt(const AKey: string; ADefault: Int64 = 0): Int64;
    function GetBool(const AKey: string; ADefault: Boolean = False): Boolean;
    function GetFloat(const AKey: string; ADefault: Double = 0.0): Double;
    function GetStringRequired(const AKey: string): string;
    function GetIntRequired(const AKey: string): Int64;
    function GetBoolRequired(const AKey: string): Boolean;
    function GetFloatRequired(const AKey: string): Double;
    procedure Require(const AKeys: array of string);

    procedure ReplaceFrom(AOther: TConfig);
    function Has(const AKey: string): Boolean;
    function GetKeys: TStringArray;
    function GetSection(const APrefix: string): TStringArray;
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
  nextpas.core.platform.files.base,
  nextpas.core.yaml,
  nextpas.core.yaml.value,
  nextpas.core.yaml.types,
  nextpas.core.toml,
  nextpas.core.toml.value,
  nextpas.core.toml.base;

type
  TConfigEntryArray = array of TConfigEntry;

  TIndexedConfigValue = record
    Index: Int64;
    Value: string;
  end;

  TIndexedConfigValueArray = array of TIndexedConfigValue;

{$IFDEF NEXTPAS_UNIX}
var
  environ: PPAnsiChar; cvar; external;
{$ENDIF}

{ DOM 展平 helper —— 把 JSON/YAML/TOML 嵌套结构递归展平成扁平 dot-path。
  嵌套对象/表 → server.host；数组/序列 → tags.0、servers.0.host（.NET IConfiguration 模型）。
  注意（扁平模型固有约束）：
  - 字面含点的键与真实层级会撞 key，例如 dotted a.b 与 nested a/b 都展平成 a.b；后写覆盖先写。
  - 递归深度 = 配置嵌套深度，由底层 DOM 解析器自身的深度上限先行约束。 }

function JoinKey(const APrefix, AKey: string): string;
begin
  if APrefix = '' then
    Result := AKey
  else
    Result := APrefix + '.' + AKey;
end;

function GetSectionSuffix(const AKey, APrefix: string; out ASuffix: string): Boolean;
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
  if LowerCase(Copy(AKey, 1, LPrefixLen)) <> LowerCase(APrefix) then
    Exit(False);

  ASuffix := Copy(AKey, LPrefixLen + 2, Length(AKey) - LPrefixLen - 1);
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

function StringArrayContains(const AItems: TStringArray; const ACount: Integer;
  const AValue: string): Boolean;
var
  LI: Integer;
  LLower: string;
begin
  LLower := LowerCase(AValue);
  for LI := 0 to ACount - 1 do
    if LowerCase(AItems[LI]) = LLower then
      Exit(True);
  Result := False;
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

function TryParseArrayIndex(const AValue: string; out AIndex: Int64): Boolean;
var
  LI: Integer;
begin
  AIndex := 0;
  if AValue = '' then
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

function FindPlaceholderEnd(const AValue: string; const AStart: Integer): Integer;
begin
  Result := AStart;
  while (Result <= Length(AValue)) and (AValue[Result] <> '}') do
    Inc(Result);
  if Result > Length(AValue) then
    Result := 0;
end;

function ConfigKeyStackContains(const AStack: TStringArray; const AKey: string): Boolean;
var
  LI: Integer;
  LLower: string;
begin
  LLower := LowerCase(AKey);
  for LI := 0 to Length(AStack) - 1 do
    if LowerCase(AStack[LI]) = LLower then
      Exit(True);
  Result := False;
end;

procedure PushConfigKey(var AStack: TStringArray; const AKey: string);
var
  LLen: Integer;
begin
  LLen := Length(AStack);
  SetLength(AStack, LLen + 1);
  AStack[LLen] := AKey;
end;

procedure PopConfigKey(var AStack: TStringArray);
begin
  if Length(AStack) > 0 then
    SetLength(AStack, Length(AStack) - 1);
end;

function InterpolateConfigValue(const AEntries: TConfigEntryArray;
  const ACount: Integer; const AValue: string; var AStack: TStringArray;
  const AFailOnUnresolved: Boolean; const ARequiredKey: string): string; forward;

function ResolveConfigEntryByIndex(const AEntries: TConfigEntryArray;
  const ACount: Integer; const AIndex: Integer; var AStack: TStringArray;
  const AFailOnUnresolved: Boolean; const ARequiredKey: string): string;
var
  LKey: string;
begin
  LKey := AEntries[AIndex].Key;
  if ConfigKeyStackContains(AStack, LKey) then
    raise EConfigError.Create('Config interpolation cycle at key "' + LKey + '"');

  PushConfigKey(AStack, LKey);
  try
    Result := InterpolateConfigValue(AEntries, ACount, AEntries[AIndex].Value, AStack,
      AFailOnUnresolved, ARequiredKey);
  finally
    PopConfigKey(AStack);
  end;
end;

function ResolveConfigKeyInSnapshot(const AEntries: TConfigEntryArray;
  const ACount: Integer; const AKey: string; out AValue: string;
  var AStack: TStringArray; const AFailOnUnresolved: Boolean;
  const ARequiredKey: string): Boolean;
var
  LIdx: Integer;
begin
  LIdx := FindEntryIndexInSnapshot(AEntries, ACount, AKey);
  Result := LIdx >= 0;
  if Result then
    AValue := ResolveConfigEntryByIndex(AEntries, ACount, LIdx, AStack,
      AFailOnUnresolved, ARequiredKey)
  else
    AValue := '';
end;

function ResolvePlaceholder(const AEntries: TConfigEntryArray; const ACount: Integer;
  const AName: string; var AStack: TStringArray; out AValue: string;
  const AFailOnUnresolved: Boolean; const ARequiredKey: string): Boolean;
begin
  if AName = '' then
  begin
    AValue := '';
    Exit(False);
  end;

  if ResolveConfigKeyInSnapshot(AEntries, ACount, AName, AValue, AStack,
    AFailOnUnresolved, ARequiredKey) then
    Exit(True);

  if nextpas.core.os.env.HasEnv(AName) then
  begin
    AValue := nextpas.core.os.env.GetEnv(AName);
    Exit(True);
  end;

  AValue := '';
  Result := False;
end;

function InterpolateConfigValue(const AEntries: TConfigEntryArray;
  const ACount: Integer; const AValue: string; var AStack: TStringArray;
  const AFailOnUnresolved: Boolean; const ARequiredKey: string): string;
var
  LI: Integer;
  LEnd: Integer;
  LName: string;
  LResolved: string;
begin
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
        if ResolvePlaceholder(AEntries, ACount, LName, AStack, LResolved,
          AFailOnUnresolved, ARequiredKey) then
          Result := Result + LResolved
        else if AFailOnUnresolved then
          raise EConfigError.Create('Required config key "' + ARequiredKey +
            '" has unresolved placeholder')
        else
          Result := Result + '${' + LName + '}';
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

function PadZero(const AValue: Int64; const AWidth: Integer): string;
begin
  Result := IntToStr(AValue);
  while Length(Result) < AWidth do
    Result := '0' + Result;
end;

{ TOML datetime → ISO 8601 文本（忠实渲染，供类型 getter 还原）}
function TomlDateTimeToStr(const ADT: TTomlDateTime): string;
var
  LAbs, LH, LM: Integer;
  LFrac: string;
  LLen: Integer;
begin
  Result := '';
  if ADT.HasDate then
    Result := PadZero(ADT.Year, 4) + '-' + PadZero(ADT.Month, 2) + '-' + PadZero(ADT.Day, 2);
  if ADT.HasTime then
  begin
    if Result <> '' then
      Result := Result + 'T';
    Result := Result + PadZero(ADT.Hour, 2) + ':' + PadZero(ADT.Minute, 2) + ':' +
      PadZero(ADT.Second, 2);
    if ADT.Nanosecond > 0 then
    begin
      LFrac := PadZero(ADT.Nanosecond, 9);
      LLen := Length(LFrac);
      while (LLen > 1) and (LFrac[LLen] = '0') do
        Dec(LLen);
      Result := Result + '.' + Copy(LFrac, 1, LLen);
    end;
  end;
  if ADT.HasOffset then
  begin
    if ADT.OffsetMinutes = 0 then
      Result := Result + 'Z'
    else
    begin
      LAbs := Abs(Integer(ADT.OffsetMinutes));
      LH := LAbs div 60;
      LM := LAbs mod 60;
      if ADT.OffsetMinutes >= 0 then
        Result := Result + '+'
      else
        Result := Result + '-';
      Result := Result + PadZero(LH, 2) + ':' + PadZero(LM, 2);
    end;
  end;
end;

{ 标量忠实渲染 —— int/float/bool/null 转成可被类型 getter 还原的文本 }

function RenderJsonScalar(const ANode: TJsonValue): string;
begin
  case ANode.Kind of
    jnkString: Result := ANode.AsStr.ToString;
    jnkInt:    Result := IntToStr(ANode.AsInt);
    jnkReal:   Result := FloatToStr(ANode.AsFloat);
    jnkBool:   if ANode.AsBool then Result := 'true' else Result := 'false';
  else
    Result := '';  { jnkNull / 其它 }
  end;
end;

function RenderYamlScalar(const ANode: TYamlValue): string;
begin
  case ANode.Kind of
    ynkString: Result := ANode.AsStr.ToString;
    ynkInt:    Result := IntToStr(ANode.AsInt);
    ynkFloat:  Result := FloatToStr(ANode.AsFloat);
    ynkBool:   if ANode.AsBool then Result := 'true' else Result := 'false';
  else
    Result := '';  { ynkNull / ynkAlias / 其它 }
  end;
end;

function RenderTomlScalar(const ANode: TTomlValue): string;
begin
  case ANode.Kind of
    tnkString:   Result := ANode.AsStr.ToString;
    tnkInt:      Result := IntToStr(ANode.AsInt);
    tnkFloat:    Result := FloatToStr(ANode.AsFloat);
    tnkBool:     if ANode.AsBool then Result := 'true' else Result := 'false';
    tnkDateTime: Result := TomlDateTimeToStr(ANode.AsDateTime);
  else
    Result := '';
  end;
end;

{ 递归展平 —— while + UInt32 计数，空容器零下溢 }

procedure FlattenJsonNode(ACfg: TConfig; const APrefix: string; const ANode: TJsonValue);
var
  LI, LCount: UInt32;
begin
  case ANode.Kind of
    jnkObject:
      begin
        LCount := ANode.ObjectLen;
        LI := 0;
        while LI < LCount do
        begin
          FlattenJsonNode(ACfg, JoinKey(APrefix, ANode.ObjectKeyAt(LI).ToString),
            ANode.ObjectValueAt(LI));
          Inc(LI);
        end;
      end;
    jnkArray:
      begin
        LCount := ANode.ArrayLen;
        LI := 0;
        while LI < LCount do
        begin
          FlattenJsonNode(ACfg, JoinKey(APrefix, UIntToStr(LI)), ANode.ArrayGet(LI));
          Inc(LI);
        end;
      end;
  else
    ACfg.SetValueUnlocked(APrefix, RenderJsonScalar(ANode));
  end;
end;

procedure FlattenYamlNode(ACfg: TConfig; const APrefix: string; const ANode: TYamlValue);
var
  LI, LCount: UInt32;
begin
  if ANode.IsMap then
  begin
    LCount := ANode.MapLen;
    LI := 0;
    while LI < LCount do
    begin
      FlattenYamlNode(ACfg, JoinKey(APrefix, ANode.MapKeyAt(LI).ToString),
        ANode.MapValueAt(LI));
      Inc(LI);
    end;
  end
  else if ANode.IsSeq then
  begin
    LCount := ANode.SeqLen;
    LI := 0;
    while LI < LCount do
    begin
      FlattenYamlNode(ACfg, JoinKey(APrefix, UIntToStr(LI)), ANode.SeqGet(LI));
      Inc(LI);
    end;
  end
  else
    ACfg.SetValueUnlocked(APrefix, RenderYamlScalar(ANode));
end;

procedure FlattenTomlNode(ACfg: TConfig; const APrefix: string; const ANode: TTomlValue);
var
  LI, LCount: UInt32;
begin
  if ANode.IsTable then
  begin
    LCount := ANode.TableLen;
    LI := 0;
    while LI < LCount do
    begin
      FlattenTomlNode(ACfg, JoinKey(APrefix, ANode.TableKeyAt(LI).ToString),
        ANode.TableValueAt(LI));
      Inc(LI);
    end;
  end
  else if ANode.IsArray then
  begin
    LCount := ANode.ArrayLen;
    LI := 0;
    while LI < LCount do
    begin
      FlattenTomlNode(ACfg, JoinKey(APrefix, UIntToStr(LI)), ANode.ArrayGet(LI));
      Inc(LI);
    end;
  end
  else
    ACfg.SetValueUnlocked(APrefix, RenderTomlScalar(ANode));
end;

{ TConfig }

procedure JsonOffsetToLineColumn(const AContent: string; const AOffset: SizeUInt;
  out ALine, AColumn: UInt32);
var
  LI: Integer;
  LMax: Integer;
begin
  ALine := 1;
  AColumn := 1;
  LMax := Length(AContent);
  LI := 1;
  while (LI <= LMax) and (SizeUInt(LI - 1) < AOffset) do
  begin
    if AContent[LI] = #10 then
    begin
      Inc(ALine);
      AColumn := 1;
    end
    else
      Inc(AColumn);
    Inc(LI);
  end;
end;

function FormatJsonLoadError(const AContent: string; const AError: TJsonError): string;
var
  LLine: UInt32;
  LColumn: UInt32;
begin
  Result := AError.Message.ToString;
  if Result = '' then
    Result := 'parse error';
  JsonOffsetToLineColumn(AContent, AError.Offset, LLine, LColumn);
  Result := 'JSON parse error at line ' + UIntToStr(LLine) + ', column ' +
    UIntToStr(LColumn) + ' (offset ' + UIntToStr(AError.Offset) + '): ' + Result;
end;

function FormatYamlLoadError(const AError: TYamlError): string;
begin
  Result := AError.Message.ToString;
  if Result = '' then
    Result := 'parse error';
  Result := 'YAML parse error at line ' + UIntToStr(AError.Line) +
    ', column ' + UIntToStr(AError.Col) + ': ' + Result;
end;

function FormatTomlLoadError(const AError: TTomlError): string;
begin
  Result := AError.Message.ToString;
  if Result = '' then
    Result := 'parse error';
  Result := 'TOML parse error at line ' + UIntToStr(AError.Line) +
    ', column ' + UIntToStr(AError.Col) + ': ' + Result;
end;

procedure LoadConfigFromIniFile(ACfg: TConfig; AIni: TIniFile);
var
  LSections: nextpas.core.ini.TStringArray;
  LKeys: nextpas.core.ini.TStringArray;
  LI, LJ: Integer;
  LSection, LKey, LFullKey, LValue: string;
begin
  LSections := AIni.GetSections;

  ACfg.FLock.AcquireWrite;
  try
    { Global section (no section header) }
    LKeys := AIni.GetKeys('');
    for LI := 0 to Length(LKeys) - 1 do
    begin
      LValue := AIni.ReadString('', LKeys[LI], '');
      ACfg.SetValueUnlocked(LKeys[LI], LValue);
    end;
    { Named sections: section.key }
    for LI := 0 to Length(LSections) - 1 do
    begin
      LSection := LSections[LI];
      LKeys := AIni.GetKeys(LSection);
      for LJ := 0 to Length(LKeys) - 1 do
      begin
        LKey := LKeys[LJ];
        LFullKey := LSection + '.' + LKey;
        LValue := AIni.ReadString(LSection, LKey, '');
        ACfg.SetValueUnlocked(LFullKey, LValue);
      end;
    end;
  finally
    ACfg.FLock.ReleaseWrite;
  end;
end;

procedure LoadConfigFromJsonDocument(ACfg: TConfig; const ADoc: IJsonDocument);
var
  LRoot: TJsonValue;
begin
  LRoot := ADoc.Root;

  ACfg.FLock.AcquireWrite;
  try
    { 顶层容器（object/array）递归展平，顶层键不加前缀（JoinKey('',k)=k）。
      顶层裸标量无键可映射，按 .NET IConfiguration 语义忽略。 }
    if LRoot.IsObject or LRoot.IsArray then
      FlattenJsonNode(ACfg, '', LRoot);
  finally
    ACfg.FLock.ReleaseWrite;
  end;
end;

procedure LoadConfigFromYamlDocument(ACfg: TConfig; const ADoc: IYamlDocument);
var
  LRoot: TYamlValue;
begin
  LRoot := ADoc.Root;

  ACfg.FLock.AcquireWrite;
  try
    { 顶层 mapping/sequence 递归展平；顶层裸标量按语义忽略。 }
    if LRoot.IsMap or LRoot.IsSeq then
      FlattenYamlNode(ACfg, '', LRoot);
  finally
    ACfg.FLock.ReleaseWrite;
  end;
end;

procedure LoadConfigFromTomlDocument(ACfg: TConfig; const ADoc: ITomlDocument);
var
  LRoot: TTomlValue;
begin
  LRoot := ADoc.Root;

  ACfg.FLock.AcquireWrite;
  try
    { TOML 顶层恒为 table；递归展平嵌套表/数组（含内联表、dotted key、array-of-tables）。 }
    if LRoot.IsTable then
      FlattenTomlNode(ACfg, '', LRoot);
  finally
    ACfg.FLock.ReleaseWrite;
  end;
end;

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

function TConfig.TryLoadFromIni(const AContent: string; out AError: string): Boolean;
var
  LIni: TIniFile;
begin
  AError := '';
  LIni := TIniFile.Create;
  try
    try
      if not LIni.TryLoadFromString(AContent, AError) then
        Exit(False);
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
  LEntries: TConfigEntryArray;
  LCount: Integer;
  LIdx: Integer;
  LStack: TStringArray;
begin
  SnapshotConfigEntries(Self, LEntries, LCount);
  LIdx := FindEntryIndexInSnapshot(LEntries, LCount, AKey);
  LStack := nil;
  if LIdx >= 0 then
    Result := ResolveConfigEntryByIndex(LEntries, LCount, LIdx, LStack, False, '')
  else
    Result := InterpolateConfigValue(LEntries, LCount, ADefault, LStack, False, '');
end;

function TConfig.GetStringArray(const AKey: string): TStringArray;
var
  LI, LCount: Integer;
  LEntryCount: Integer;
  LEntries: TConfigEntryArray;
  LSegment: string;
  LIndex: Int64;
  LItems: TIndexedConfigValueArray;
  LStack: TStringArray;
begin
  Result := nil;
  SnapshotConfigEntries(Self, LEntries, LEntryCount);
  LItems := nil;
  LCount := 0;
  for LI := 0 to LEntryCount - 1 do
    if DirectArraySegment(LEntries[LI].Key, AKey, LSegment) and
       TryParseArrayIndex(LSegment, LIndex) then
      AddIndexedValue(LItems, LCount, LIndex, LEntries[LI].Value);

  SortIndexedValues(LItems, LCount);
  SetLength(Result, LCount);
  LStack := nil;
  for LI := 0 to LCount - 1 do
    Result[LI] := InterpolateConfigValue(LEntries, LEntryCount, LItems[LI].Value,
      LStack, False, '');
end;

function TConfig.GetInt(const AKey: string; ADefault: Int64): Int64;
var
  LVal: Int64;
  LText: string;
begin
  LText := GetString(AKey, '');
  if (LText <> '') and TryStrToInt64(LText, LVal) then
    Result := LVal
  else
    Result := ADefault;
end;

function TConfig.GetBool(const AKey: string; ADefault: Boolean): Boolean;
var
  LStr: string;
begin
  LStr := LowerCase(Trim(GetString(AKey, '')));
  if (LStr = 'true') or (LStr = '1') or (LStr = 'yes') or (LStr = 'on') then
    Result := True
  else if (LStr = 'false') or (LStr = '0') or (LStr = 'no') or (LStr = 'off') then
    Result := False
  else
    Result := ADefault;
end;

function TConfig.GetFloat(const AKey: string; ADefault: Double): Double;
var
  LVal: Double;
  LText: string;
begin
  LText := GetString(AKey, '');
  if (LText <> '') and TryStrToFloat(LText, LVal) then
    Result := LVal
  else
    Result := ADefault;
end;

function TConfig.GetStringRequired(const AKey: string): string;
var
  LEntries: TConfigEntryArray;
  LCount: Integer;
  LIdx: Integer;
  LStack: TStringArray;
begin
  SnapshotConfigEntries(Self, LEntries, LCount);
  LIdx := FindEntryIndexInSnapshot(LEntries, LCount, AKey);
  if LIdx < 0 then
    raise EConfigError.Create('Required config key "' + AKey + '" is missing');

  LStack := nil;
  Result := ResolveConfigEntryByIndex(LEntries, LCount, LIdx, LStack, True, AKey);
  if Trim(Result) = '' then
    raise EConfigError.Create('Required config key "' + AKey + '" is empty');
end;

function TConfig.GetIntRequired(const AKey: string): Int64;
var
  LText: string;
begin
  LText := GetStringRequired(AKey);
  if not TryStrToInt64(LText, Result) then
    raise EConfigError.Create('Required config key "' + AKey + '" is not an integer');
end;

function TConfig.GetBoolRequired(const AKey: string): Boolean;
var
  LText: string;
begin
  LText := LowerCase(Trim(GetStringRequired(AKey)));
  if (LText = 'true') or (LText = '1') or (LText = 'yes') or (LText = 'on') then
    Result := True
  else if (LText = 'false') or (LText = '0') or (LText = 'no') or (LText = 'off') then
    Result := False
  else
    raise EConfigError.Create('Required config key "' + AKey + '" is not a boolean');
end;

function TConfig.GetFloatRequired(const AKey: string): Double;
var
  LText: string;
begin
  LText := GetStringRequired(AKey);
  if not TryStrToFloat(LText, Result) then
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
