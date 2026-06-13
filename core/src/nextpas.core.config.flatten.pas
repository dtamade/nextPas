unit nextpas.core.config.flatten;
{**
 * @desc Config source flattening and format dispatch helpers.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.config,
  nextpas.core.ini,
  nextpas.core.json,
  nextpas.core.json.value,
  nextpas.core.json.types,
  nextpas.core.yaml,
  nextpas.core.yaml.value,
  nextpas.core.yaml.types,
  nextpas.core.toml,
  nextpas.core.toml.value,
  nextpas.core.toml.base;

function JoinKey(const APrefix, AKey: string): string;
function JoinFlattenedKey(const AFormatName, APrefix, AKey: string): string;
procedure SetFlattenedScalarValue(ACfg: TConfig; const AKey, AValue,
  AFormatName: string);
function RenderJsonScalar(const ANode: TJsonValue): string;
function RenderYamlScalar(const ANode: TYamlValue): string;
function RenderTomlScalar(const ANode: TTomlValue): string;
function TomlDateTimeToStr(const ADT: TTomlDateTime): string;
function PadZero(const AValue: Int64; const AWidth: Integer): string;
procedure FlattenJsonNode(ACfg: TConfig; const APrefix: string; const ANode: TJsonValue);
procedure FlattenYamlNode(ACfg: TConfig; const APrefix: string; const ANode: TYamlValue);
procedure FlattenTomlNode(ACfg: TConfig; const APrefix: string; const ANode: TTomlValue);
procedure MergeFlattenedConfig(ATarget, ASource: TConfig);
procedure LoadConfigFromIniFile(ACfg: TConfig; AIni: TIniFile);
procedure LoadConfigFromJsonDocument(ACfg: TConfig; const ADoc: IJsonDocument);
procedure LoadConfigFromYamlDocument(ACfg: TConfig; const ADoc: IYamlDocument);
procedure LoadConfigFromTomlDocument(ACfg: TConfig; const ADoc: ITomlDocument);
function FormatJsonLoadError(const AContent: string; const AError: TJsonError): string;
function FormatYamlLoadError(const AError: TYamlError): string;
function FormatTomlLoadError(const AError: TTomlError): string;
function FormatIniLoadError(const AError: string): string;
function FormatConfigFileLoadError(const APath, AMessage: string): string;
procedure JsonOffsetToLineColumn(const AContent: string; const AOffset: SizeUInt;
  out ALine, AColumn: UInt32);
procedure LoadConfigTextByFormat(ACfg: TConfig; const AContent: string;
  AFormat: TConfigFormat);
function TryLoadConfigTextByFormat(ACfg: TConfig; const AContent: string;
  AFormat: TConfigFormat; out AError: string): Boolean;
procedure LoadConfigFileByFormat(ACfg: TConfig; const APath: string;
  AFormat: TConfigFormat);

implementation

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.fs,
  nextpas.core.text.conv,
  nextpas.core.text.number;

{ 配置源展平 helper —— 把 JSON/YAML/TOML 嵌套结构以及 INI section/key 展平成扁平 dot-path。
  嵌套对象/表 → server.host；数组/序列 → tags.0、servers.0.host；
  INI [server] host → server.host（.NET IConfiguration 模型）。
  注意（扁平模型固有约束）：
  - 单个来源内，字面含点的键与真实层级若展平成同一 key，例如全局 a.b 与 [a]/b、
    JSON/YAML/TOML 的 dotted a.b 与 nested a/b，必须 fail closed，不允许后写覆盖先写。
  - 不同来源之间仍按调用顺序合并；后来源覆盖先来源的同名 key。
  - JSON/YAML/TOML 递归深度 = 配置嵌套深度，由底层 DOM 解析器自身的深度上限先行约束。 }

function JoinKey(const APrefix, AKey: string): string;
begin
  if APrefix = '' then
    Result := AKey
  else
    Result := APrefix + '.' + AKey;
end;

function JoinFlattenedKey(const AFormatName, APrefix, AKey: string): string;
begin
  if AKey = '' then
    raise EConfigError.Create(
      AFormatName + ' config key must not contain an empty path segment after flattening');
  Result := JoinKey(APrefix, AKey);
end;

procedure SetFlattenedScalarValue(ACfg: TConfig; const AKey, AValue,
  AFormatName: string);
begin
  if AKey = '' then
    raise EConfigError.Create(
      AFormatName + ' config key must not be empty after flattening');
  if ACfg.Has(AKey) then
    raise EConfigError.Create(
      AFormatName + ' config key collision after flattening: ' + AKey);
  ACfg.SetString(AKey, AValue);
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
          FlattenJsonNode(ACfg,
            JoinFlattenedKey('JSON', APrefix, ANode.ObjectKeyAt(LI).ToString),
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
    SetFlattenedScalarValue(ACfg, APrefix, RenderJsonScalar(ANode), 'JSON');
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
      FlattenYamlNode(ACfg,
        JoinFlattenedKey('YAML', APrefix, ANode.MapKeyAt(LI).ToString),
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
    SetFlattenedScalarValue(ACfg, APrefix, RenderYamlScalar(ANode), 'YAML');
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
      FlattenTomlNode(ACfg,
        JoinFlattenedKey('TOML', APrefix, ANode.TableKeyAt(LI).ToString),
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
    SetFlattenedScalarValue(ACfg, APrefix, RenderTomlScalar(ANode), 'TOML');
end;

procedure MergeFlattenedConfig(ATarget, ASource: TConfig);
var
  LKeys: TStringArray;
  LI: Integer;
begin
  LKeys := ASource.GetKeys;
  for LI := 0 to Length(LKeys) - 1 do
    ATarget.SetString(LKeys[LI], ASource.GetRawString(LKeys[LI]));
end;

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
    ', column ' + UIntToStr(AError.Col) + ' (offset ' +
    UIntToStr(AError.Offset) + '): ' + Result;
end;

function FormatTomlLoadError(const AError: TTomlError): string;
begin
  Result := AError.Message.ToString;
  if Result = '' then
    Result := 'parse error';
  Result := 'TOML parse error at line ' + UIntToStr(AError.Line) +
    ', column ' + UIntToStr(AError.Col) + ' (offset ' +
    UIntToStr(AError.Offset) + '): ' + Result;
end;

function FormatIniLoadError(const AError: string): string;
begin
  Result := AError;
  if Result = '' then
    Result := 'parse error';
  Result := 'INI parse error: ' + Result;
end;

function FormatConfigFileLoadError(const APath, AMessage: string): string;
begin
  Result := 'Config file load error: ' + APath;
  if AMessage <> '' then
    Result := Result + ': ' + AMessage;
end;

procedure LoadConfigTextByFormat(ACfg: TConfig; const AContent: string;
  AFormat: TConfigFormat);
begin
  if not IsSupportedConfigFormat(AFormat) then
    raise EConfigError.Create('unsupported config format');
  case AFormat of
    cfIni: ACfg.LoadFromIni(AContent);
    cfJson: ACfg.LoadFromJson(AContent);
    cfYaml: ACfg.LoadFromYaml(AContent);
    cfToml: ACfg.LoadFromToml(AContent);
  end;
end;

function TryLoadConfigTextByFormat(ACfg: TConfig; const AContent: string;
  AFormat: TConfigFormat; out AError: string): Boolean;
begin
  if not IsSupportedConfigFormat(AFormat) then
  begin
    AError := 'unsupported config format';
    Exit(False);
  end;

  case AFormat of
    cfIni: Result := ACfg.TryLoadFromIni(AContent, AError);
    cfJson: Result := ACfg.TryLoadFromJson(AContent, AError);
    cfYaml: Result := ACfg.TryLoadFromYaml(AContent, AError);
    cfToml: Result := ACfg.TryLoadFromToml(AContent, AError);
  end;
end;

procedure LoadConfigFileByFormat(ACfg: TConfig; const APath: string;
  AFormat: TConfigFormat);
var
  LContent: string;
begin
  RequireConfigFilePath(APath);
  if not IsSupportedConfigFormat(AFormat) then
    raise EConfigError.Create(FormatConfigFileLoadError(APath,
      'unsupported config format'));

  try
    LContent := ReadFileText(APath);
    try
      LoadConfigTextByFormat(ACfg, LContent, AFormat);
    except
      on E: Exception do
        raise EConfigError.Create(FormatConfigFileLoadError(APath, E.Message));
    end;
  except
    on E: EConfigError do
      raise;
    on E: Exception do
      raise EConfigError.Create(FormatConfigFileLoadError(APath, E.Message));
  end;
end;

procedure LoadConfigFromIniFile(ACfg: TConfig; AIni: TIniFile);
var
  LSections: nextpas.core.ini.TStringArray;
  LKeys: nextpas.core.ini.TStringArray;
  LI, LJ: Integer;
  LSection, LKey, LFullKey, LValue: string;
  LSource: TConfig;
begin
  LSections := AIni.GetSections;

  LSource := TConfig.Create;
  try
    { Global section (no section header) }
    LKeys := AIni.GetKeys('');
    for LI := 0 to Length(LKeys) - 1 do
    begin
      LValue := AIni.ReadString('', LKeys[LI], '');
      SetFlattenedScalarValue(LSource, LKeys[LI], LValue, 'INI');
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
        SetFlattenedScalarValue(LSource, LFullKey, LValue, 'INI');
      end;
    end;
    MergeFlattenedConfig(ACfg, LSource);
  finally
    LSource.Free;
  end;
end;

procedure LoadConfigFromJsonDocument(ACfg: TConfig; const ADoc: IJsonDocument);
var
  LRoot: TJsonValue;
  LSource: TConfig;
begin
  LRoot := ADoc.Root;

  LSource := TConfig.Create;
  try
    { 顶层容器（object/array）递归展平，顶层键不加前缀（JoinKey('',k)=k）。
      顶层裸标量无键可映射，按 .NET IConfiguration 语义忽略。 }
    if LRoot.IsObject or LRoot.IsArray then
      FlattenJsonNode(LSource, '', LRoot);
    MergeFlattenedConfig(ACfg, LSource);
  finally
    LSource.Free;
  end;
end;

procedure LoadConfigFromYamlDocument(ACfg: TConfig; const ADoc: IYamlDocument);
var
  LRoot: TYamlValue;
  LSource: TConfig;
begin
  LRoot := ADoc.Root;

  LSource := TConfig.Create;
  try
    { 顶层 mapping/sequence 递归展平；顶层裸标量按语义忽略。 }
    if LRoot.IsMap or LRoot.IsSeq then
      FlattenYamlNode(LSource, '', LRoot);
    MergeFlattenedConfig(ACfg, LSource);
  finally
    LSource.Free;
  end;
end;

procedure LoadConfigFromTomlDocument(ACfg: TConfig; const ADoc: ITomlDocument);
var
  LRoot: TTomlValue;
  LSource: TConfig;
begin
  LRoot := ADoc.Root;

  LSource := TConfig.Create;
  try
    { TOML 顶层恒为 table；递归展平嵌套表/数组（含内联表、dotted key、array-of-tables）。 }
    if LRoot.IsTable then
      FlattenTomlNode(LSource, '', LRoot);
    MergeFlattenedConfig(ACfg, LSource);
  finally
    LSource.Free;
  end;
end;

end.
