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

const
  RecentLookupCacheSize = 4;

threadvar
  GRecentLookupNext: Integer;
  GRecentLookupHotConfig: Pointer;
  GRecentLookupHotIndex: Integer;
  GRecentLookupConfig: array[0..RecentLookupCacheSize - 1] of Pointer;
  GRecentLookupIndex: array[0..RecentLookupCacheSize - 1] of Integer;

type
  TConfig = class;
  TStringArray = array of string;
  TLookupSlotArray = array of Integer;
  TConfigFormat = (cfIni, cfJson, cfYaml, cfToml);

  EConfigError = class(EParseError);

  IConfig = interface
    ['{7F5F1A22-8C52-44C8-9E38-9CF5C3F2C101}']
    function GetCount: Integer;
    function GetString(const AKey: string; const ADefault: string = ''): string;
    function GetRawString(const AKey: string; const ADefault: string = ''): string;
    function GetStringArray(const AKey: string): TStringArray;
    function GetRawStringArray(const AKey: string): TStringArray;
    function GetInt(const AKey: string; ADefault: Int64 = 0): Int64;
    function GetBool(const AKey: string; ADefault: Boolean = False): Boolean;
    function GetFloat(const AKey: string; ADefault: Double = 0.0): Double;
    function GetStringRequired(const AKey: string): string;
    function GetIntRequired(const AKey: string): Int64;
    function GetBoolRequired(const AKey: string): Boolean;
    function GetFloatRequired(const AKey: string): Double;
    procedure Require(const AKeys: array of string);
    function Has(const AKey: string): Boolean;
    function GetKeys: TStringArray;
    function GetSection(const APrefix: string): TStringArray;
    function ToIni: string;
    function ToJson: string;
    function ToYaml: string;
    function ToToml: string;
    property Count: Integer read GetCount;
  end;

  IConfigBuilder = interface
    ['{B1C9DA74-337C-40D7-9703-029BD7D7E201}']
    function AddDefault(const AKey, AValue: string): IConfigBuilder;
    function AddIni(const AContent: string): IConfigBuilder;
    function AddJson(const AContent: string): IConfigBuilder;
    function AddYaml(const AContent: string): IConfigBuilder;
    function AddToml(const AContent: string): IConfigBuilder;
    function AddEnv(const APrefix: string): IConfigBuilder;
    function AddFile(const APath: string; AFormat: TConfigFormat): IConfigBuilder;
    function RequireKeys(const AKeys: array of string): IConfigBuilder;
    function Build: IConfig;
    function BuildConfig: TConfig;
    function TryBuild(out AConfig: IConfig; out AError: string): Boolean;
  end;

  TConfigEntry = record
    Key: string;
    Value: string;
  end;

  TConfig = class
  private
    FLock: IRWLock;
    FEntries: array of TConfigEntry;
    FLowerKeys: TStringArray;
    FLookupSlots: TLookupSlotArray;
    FEntryHasPlaceholder: array of Boolean;
    FArrayCacheLowerKey: string;
    FArrayCacheValues: TStringArray;
    FArrayCacheAllLiteral: Boolean;
    FArrayCacheValid: Boolean;
    FInterpolationCacheValues: TStringArray;
    FInterpolationCacheValid: array of Boolean;
    FCount: Integer;
    procedure BuildArrayCacheLocked(const APrefix, ALowerPrefix: string);
    procedure ClearUnlocked;
    procedure CopyArrayCacheLocked(out AValues: TStringArray;
      out AAllLiteral: Boolean);
    procedure DeleteIndexUnlocked(AIndex: Integer);
    procedure DeleteKeyUnlocked(const AKey: string);
    procedure DeleteSectionUnlocked(const APrefix: string);
    function EnsureLookupCapacity(const AMinCount: Integer): Boolean;
    function FindIndexByLowerKey(const ALowerKey: string): Integer; inline;
    function HasArrayCacheLocked(const ALowerPrefix: string): Boolean;
    procedure InvalidateArrayCacheLocked;
    procedure InvalidateInterpolationCacheLocked;
    procedure InvalidateReadCachesLocked;
    procedure InsertLookupKey(const ALowerKey: string; const AIndex: Integer);
    procedure RebuildLookupIndex;
    procedure SetValue(const AKey, AValue: string);
    procedure SetValueUnlocked(const AKey, AValue: string);
    procedure StoreInterpolationCacheLocked(const AIndex: Integer;
      const AValue: string);
    function TryGetResolvedEntryFastLocked(const AIndex: Integer;
      out AValue: string): Boolean; inline;
    function TryGetRequiredValue(const AKey: string; out AValue: string): Boolean;
    function TryGetValue(const AKey: string; out AValue: string): Boolean;
    function TryGetInterpolationCacheLocked(const AIndex: Integer;
      out AValue: string): Boolean; inline;
    function FindIndexCached(const AKey: string): Integer; inline;
    function FindIndex(const AKey: string): Integer; inline;
    function GetCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure LoadFromIni(const AContent: string);
    procedure LoadFromJson(const AContent: string);
    procedure LoadFromYaml(const AContent: string);
    procedure LoadFromToml(const AContent: string);
    procedure LoadFromFile(const APath: string; AFormat: TConfigFormat);
    function TryLoadFromIni(const AContent: string; out AError: string): Boolean;
    function TryLoadFromJson(const AContent: string; out AError: string): Boolean;
    function TryLoadFromYaml(const AContent: string; out AError: string): Boolean;
    function TryLoadFromToml(const AContent: string; out AError: string): Boolean;
    function TryLoadFromFile(const APath: string; AFormat: TConfigFormat;
      out AError: string): Boolean;
    function TryLoadJson(const AContent: string; out AError: string): Boolean;
    function TryLoadYaml(const AContent: string; out AError: string): Boolean;
    function TryLoadToml(const AContent: string; out AError: string): Boolean;
    procedure LoadFromEnv(const APrefix: string);
    procedure SetString(const AKey, AValue: string);
    procedure SetInt(const AKey: string; AValue: Int64);
    procedure SetBool(const AKey: string; AValue: Boolean);
    procedure SetFloat(const AKey: string; AValue: Double);
    procedure SetStringArray(const AKey: string; const AValues: array of string);
    procedure SetDefault(const AKey, AValue: string);
    procedure DeleteKey(const AKey: string);
    procedure DeleteSection(const APrefix: string);
    procedure Clear;
    function ToIni: string;
    procedure SaveToIni(const APath: string);
    function ToJson: string;
    procedure SaveToJson(const APath: string);
    function ToYaml: string;
    procedure SaveToYaml(const APath: string);
    function ToToml: string;
    procedure SaveToToml(const APath: string);

    function GetString(const AKey: string; const ADefault: string = ''): string;
    function GetRawString(const AKey: string; const ADefault: string = ''): string;
    function GetStringArray(const AKey: string): TStringArray;
    function GetRawStringArray(const AKey: string): TStringArray;
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
  TConfigReloadEvent = procedure(ASender: TConfig) of object;

function ConfigBuilder: IConfigBuilder;
function ConfigLoad(const APath: string; AFormat: TConfigFormat): IConfig;

type
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
  nextpas.core.base,
  nextpas.core.config.env,
  nextpas.core.fs,
  nextpas.core.hash.wyhash,
  nextpas.core.json.writer,
  nextpas.core.platform.files,
  nextpas.core.platform.files.base,
  nextpas.core.text.builder,
  nextpas.core.text.number,
  nextpas.core.yaml.builder,
  nextpas.core.yaml,
  nextpas.core.yaml.value,
  nextpas.core.yaml.types,
  nextpas.core.toml,
  nextpas.core.toml.writer,
  nextpas.core.toml.value,
  nextpas.core.toml.base;

type
  TConfigEntryArray = array of TConfigEntry;
  TConfigSourceKind = (
    cskIni,
    cskJson,
    cskYaml,
    cskToml,
    cskEnv,
    cskFile
  );

  TConfigSource = record
    Kind: TConfigSourceKind;
    Value: string;
    Format: TConfigFormat;
  end;

  TConfigSourceArray = array of TConfigSource;

  TIndexedConfigValue = record
    Index: Int64;
    Value: string;
  end;

  TIndexedConfigValueArray = array of TIndexedConfigValue;

  TConfigExportNode = class;

  TConfigJsonChild = record
    Name: string;
    Node: TConfigExportNode;
  end;

  TConfigExportNode = class
  private
    FHasScalar: Boolean;
    FScalarValue: string;
    FChildren: array of TConfigJsonChild;
    FChildCount: Integer;
    function FindChildIndex(const AName: string): Integer;
    function RequireChild(const AName: string): TConfigExportNode;
    function IsDenseArray(out ACount: Integer): Boolean;
  public
    destructor Destroy; override;
    procedure SetScalar(const AValue: string);
    procedure AddPath(const AKey, AValue: string);
    procedure WriteJson(var AWriter: TJsonWriter; const APath: string);
    procedure BuildYaml(var ABuilder: TYamlBuilder; const APath: string);
  end;

  TOwnedConfig = class(TInterfacedObject, IConfig)
  private
    FConfig: TConfig;
    function GetCount: Integer;
  public
    constructor Create(AConfig: TConfig);
    destructor Destroy; override;
    function GetString(const AKey: string; const ADefault: string = ''): string;
    function GetRawString(const AKey: string; const ADefault: string = ''): string;
    function GetStringArray(const AKey: string): TStringArray;
    function GetRawStringArray(const AKey: string): TStringArray;
    function GetInt(const AKey: string; ADefault: Int64 = 0): Int64;
    function GetBool(const AKey: string; ADefault: Boolean = False): Boolean;
    function GetFloat(const AKey: string; ADefault: Double = 0.0): Double;
    function GetStringRequired(const AKey: string): string;
    function GetIntRequired(const AKey: string): Int64;
    function GetBoolRequired(const AKey: string): Boolean;
    function GetFloatRequired(const AKey: string): Double;
    procedure Require(const AKeys: array of string);
    function Has(const AKey: string): Boolean;
    function GetKeys: TStringArray;
    function GetSection(const APrefix: string): TStringArray;
    function ToIni: string;
    function ToJson: string;
    function ToYaml: string;
    function ToToml: string;
  end;

  TConfigBuilderImpl = class(TInterfacedObject, IConfigBuilder)
  private
    FDefaults: TConfigEntryArray;
    FDefaultCount: Integer;
    FSources: TConfigSourceArray;
    FSourceCount: Integer;
    FRequiredKeys: TStringArray;
    FRequiredCount: Integer;
    function DefaultIndexOf(const AKey: string): Integer;
    procedure StoreDefault(const AKey, AValue: string);
    procedure StoreSource(const AKind: TConfigSourceKind; const AValue: string;
      AFormat: TConfigFormat);
    procedure StoreRequiredKey(const AKey: string);
    procedure ApplyDefaults(ACfg: TConfig);
    procedure ApplySource(ACfg: TConfig; const ASource: TConfigSource);
    procedure ApplyRequiredKeys(ACfg: TConfig);
    function BuildFreshConfig: TConfig;
  public
    function AddDefault(const AKey, AValue: string): IConfigBuilder;
    function AddIni(const AContent: string): IConfigBuilder;
    function AddJson(const AContent: string): IConfigBuilder;
    function AddYaml(const AContent: string): IConfigBuilder;
    function AddToml(const AContent: string): IConfigBuilder;
    function AddEnv(const APrefix: string): IConfigBuilder;
    function AddFile(const APath: string; AFormat: TConfigFormat): IConfigBuilder;
    function RequireKeys(const AKeys: array of string): IConfigBuilder;
    function Build: IConfig;
    function BuildConfig: TConfig;
    function TryBuild(out AConfig: IConfig; out AError: string): Boolean;
  end;

{$IFDEF NEXTPAS_UNIX}
var
  environ: PPAnsiChar; cvar; external;
{$ENDIF}

const
  ConfigFilePathEmptyError = 'config file path must not be empty';

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
  if ACfg.FindIndex(AKey) >= 0 then
    raise EConfigError.Create(
      AFormatName + ' config key collision after flattening: ' + AKey);
  ACfg.SetValueUnlocked(AKey, AValue);
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
begin
  LLower := LowerCase(AValue);
  for LI := 0 to ACount - 1 do
    if LowerCase(AItems[LI]) = LLower then
      Exit(True);
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

procedure AddConfigSource(var AItems: TConfigSourceArray; var ACount: Integer;
  const AKind: TConfigSourceKind; const AValue: string; AFormat: TConfigFormat);
begin
  if ACount >= Length(AItems) then
    SetLength(AItems, ACount + 8);
  AItems[ACount].Kind := AKind;
  AItems[ACount].Value := AValue;
  AItems[ACount].Format := AFormat;
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

{ TConfigExportNode }

destructor TConfigExportNode.Destroy;
var
  LI: Integer;
begin
  for LI := 0 to FChildCount - 1 do
    FChildren[LI].Node.Free;
  FChildren := nil;
  inherited Destroy;
end;

function TConfigExportNode.FindChildIndex(const AName: string): Integer;
var
  LI: Integer;
  LLower: string;
begin
  LLower := LowerCase(AName);
  for LI := 0 to FChildCount - 1 do
    if LowerCase(FChildren[LI].Name) = LLower then
      Exit(LI);
  Result := -1;
end;

function TConfigExportNode.RequireChild(const AName: string): TConfigExportNode;
var
  LIdx: Integer;
begin
  LIdx := FindChildIndex(AName);
  if LIdx >= 0 then
    Exit(FChildren[LIdx].Node);

  if FChildCount >= Length(FChildren) then
    SetLength(FChildren, FChildCount + 8);

  FChildren[FChildCount].Name := AName;
  FChildren[FChildCount].Node := TConfigExportNode.Create;
  Result := FChildren[FChildCount].Node;
  Inc(FChildCount);
end;

function TConfigExportNode.IsDenseArray(out ACount: Integer): Boolean;
var
  LI: Integer;
  LIdx: Int64;
  LMax: Int64;
begin
  ACount := 0;
  if FChildCount = 0 then
    Exit(False);

  LMax := -1;
  for LI := 0 to FChildCount - 1 do
  begin
    if not TryParseArrayIndex(FChildren[LI].Name, LIdx) then
      Exit(False);
    if LIdx > LMax then
      LMax := LIdx;
  end;

  if LMax <> FChildCount - 1 then
    Exit(False);

  for LI := 0 to FChildCount - 1 do
    if FindChildIndex(IntToStr(LI)) < 0 then
      Exit(False);

  ACount := FChildCount;
  Result := True;
end;

procedure TConfigExportNode.SetScalar(const AValue: string);
begin
  FHasScalar := True;
  FScalarValue := AValue;
end;

procedure TConfigExportNode.AddPath(const AKey, AValue: string);
var
  LNode: TConfigExportNode;
  LPos: Integer;
  LSegment: string;
begin
  RequireHierarchicalConfigPath(AKey);

  LNode := Self;
  LPos := 1;
  while NextConfigPathSegment(AKey, LPos, LSegment) do
  begin
    if LPos > Length(AKey) then
    begin
      LNode.RequireChild(LSegment).SetScalar(AValue);
      Exit;
    end;
    LNode := LNode.RequireChild(LSegment);
  end;
end;

procedure TConfigExportNode.WriteJson(var AWriter: TJsonWriter; const APath: string);
var
  LI: Integer;
  LCount: Integer;
  LChildPath: string;
begin
  if FHasScalar then
  begin
    if FChildCount > 0 then
      raise EConfigError.Create('config export conflict at "' +
        DisplayConfigPath(APath) + '": scalar and subtree cannot both be represented as a hierarchical config');
    AWriter.Str(FScalarValue);
    Exit;
  end;

  if IsDenseArray(LCount) then
  begin
    AWriter.BeginArray;
    for LI := 0 to LCount - 1 do
      FChildren[FindChildIndex(IntToStr(LI))].Node.WriteJson(AWriter,
        JoinKey(APath, IntToStr(LI)));
    AWriter.EndArray;
    Exit;
  end;

  AWriter.BeginObject;
  for LI := 0 to FChildCount - 1 do
  begin
    AWriter.Key(FChildren[LI].Name);
    LChildPath := JoinKey(APath, FChildren[LI].Name);
    FChildren[LI].Node.WriteJson(AWriter, LChildPath);
  end;
  AWriter.EndObject;
end;

procedure TConfigExportNode.BuildYaml(var ABuilder: TYamlBuilder; const APath: string);
var
  LI: Integer;
  LCount: Integer;
begin
  if FHasScalar then
  begin
    if FChildCount > 0 then
      raise EConfigError.Create('config export conflict at "' +
        DisplayConfigPath(APath) + '": scalar and subtree cannot both be represented as a hierarchical config');
    ABuilder.PutStr(FScalarValue);
    Exit;
  end;

  if IsDenseArray(LCount) then
  begin
    ABuilder.BeginSeq;
    for LI := 0 to LCount - 1 do
      FChildren[FindChildIndex(IntToStr(LI))].Node.BuildYaml(ABuilder,
        JoinKey(APath, IntToStr(LI)));
    ABuilder.EndSeq;
    Exit;
  end;

  ABuilder.BeginMap;
  for LI := 0 to FChildCount - 1 do
  begin
    ABuilder.PutKey(FChildren[LI].Name);
    FChildren[LI].Node.BuildYaml(ABuilder, JoinKey(APath, FChildren[LI].Name));
  end;
  ABuilder.EndMap;
end;

function ConfigEntriesToJson(const AEntries: TConfigEntryArray;
  const ACount: Integer): string;
var
  LRoot: TConfigExportNode;
  LBuilder: TStringBuilder;
  LWriter: TJsonWriter;
  LI: Integer;
begin
  LRoot := TConfigExportNode.Create;
  try
    for LI := 0 to ACount - 1 do
      LRoot.AddPath(AEntries[LI].Key, AEntries[LI].Value);

    LBuilder.Init(ACount * 32 + 2);
    try
      LWriter.Init(LBuilder);
      LRoot.WriteJson(LWriter, '');
      Result := LBuilder.ToString;
    finally
      LBuilder.Done;
    end;
  finally
    LRoot.Free;
  end;
end;

function ConfigEntriesToYaml(const AEntries: TConfigEntryArray;
  const ACount: Integer): string;
var
  LRoot: TConfigExportNode;
  LBuilder: TYamlBuilder;
  LI: Integer;
begin
  LRoot := TConfigExportNode.Create;
  try
    for LI := 0 to ACount - 1 do
      LRoot.AddPath(AEntries[LI].Key, AEntries[LI].Value);

    LBuilder.Init;
    try
      LRoot.BuildYaml(LBuilder, '');
      Result := LBuilder.Stringify;
    finally
      LBuilder.Done;
    end;
  finally
    LRoot.Free;
  end;
end;

function ConfigEntriesToToml(const AEntries: TConfigEntryArray;
  const ACount: Integer): string;
var
  LBuilder: TStringBuilder;
  LWriter: TTomlWriter;
  LI: Integer;
begin
  LBuilder.Init(256);
  try
    LWriter.Init(LBuilder);
    for LI := 0 to ACount - 1 do
    begin
      LWriter.Key(AEntries[LI].Key);
      LWriter.Str(AEntries[LI].Value);
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

function ContainsIniLineBreak(const AValue: string): Boolean;
var
  LI: Integer;
begin
  for LI := 1 to Length(AValue) do
    if (AValue[LI] = #10) or (AValue[LI] = #13) then
      Exit(True);
  Result := False;
end;

function HasIniTrimmedEdgeWhitespace(const AValue: string): Boolean;
begin
  Result := (AValue <> '') and
    (((AValue[1] = ' ') or (AValue[1] = #9)) or
     ((AValue[Length(AValue)] = ' ') or (AValue[Length(AValue)] = #9)));
end;

function IsIniSectionNameRepresentable(const ASection: string): Boolean;
begin
  Result := (ASection <> '') and
    (not ContainsIniLineBreak(ASection)) and
    (not HasIniTrimmedEdgeWhitespace(ASection)) and
    (Pos(']', ASection) = 0);
end;

function IsIniKeyNameRepresentable(const AKey: string): Boolean;
begin
  Result := (AKey <> '') and
    (not ContainsIniLineBreak(AKey)) and
    (not HasIniTrimmedEdgeWhitespace(AKey)) and
    (Pos('=', AKey) = 0) and
    (AKey[1] <> '[') and
    (AKey[1] <> ';') and
    (AKey[1] <> '#');
end;

function TryMapConfigKeyToIniPath(const AConfigKey: string; out ASection,
  AKey: string): Boolean;
var
  LDotPos: Integer;
  LSection: string;
  LKey: string;
begin
  for LDotPos := Length(AConfigKey) downto 1 do
    if AConfigKey[LDotPos] = '.' then
    begin
      LSection := Copy(AConfigKey, 1, LDotPos - 1);
      LKey := Copy(AConfigKey, LDotPos + 1,
        Length(AConfigKey) - LDotPos);
      if IsIniSectionNameRepresentable(LSection) and
         IsIniKeyNameRepresentable(LKey) then
      begin
        ASection := LSection;
        AKey := LKey;
        Exit(True);
      end;
    end;

  if IsIniKeyNameRepresentable(AConfigKey) then
  begin
    ASection := '';
    AKey := AConfigKey;
    Exit(True);
  end;

  ASection := '';
  AKey := '';
  Result := False;
end;

function ConfigEntriesToIni(const AEntries: TConfigEntryArray;
  const ACount: Integer): string;
var
  LIni: TIniFile;
  LI: Integer;
  LSection: string;
  LKey: string;
begin
  LIni := TIniFile.Create;
  try
    for LI := 0 to ACount - 1 do
    begin
      if ContainsIniLineBreak(AEntries[LI].Value) then
        raise EConfigError.Create('config key "' + AEntries[LI].Key +
          '" cannot be exported to ini: value contains line breaks');
      if (AEntries[LI].Value <> '') and
         ((AEntries[LI].Value[1] = ' ') or (AEntries[LI].Value[1] = #9)) then
        raise EConfigError.Create('config key "' + AEntries[LI].Key +
          '" cannot be exported to ini: value has leading whitespace');
      if not TryMapConfigKeyToIniPath(AEntries[LI].Key, LSection, LKey) then
        raise EConfigError.Create('config key "' + AEntries[LI].Key +
          '" cannot be exported to ini: key is not representable');
      LIni.WriteString(LSection, LKey, AEntries[LI].Value);
    end;
    Result := LIni.ToString;
  finally
    LIni.Free;
  end;
end;

procedure ConfigWriteAtomicText(const APath, AText: string);
var
  LData: TBytes;
begin
  if Length(AText) > 0 then
  begin
    SetLength(LData, Length(AText));
    Move(PAnsiChar(AText)^, LData[0], Length(AText));
    WriteAtomic(APath, LData);
  end
  else
    WriteAtomic(APath, nil);
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
  LI: Integer;
begin
  ATarget.FLock.AcquireWrite;
  try
    for LI := 0 to ASource.FCount - 1 do
      ATarget.SetValueUnlocked(ASource.FEntries[LI].Key, ASource.FEntries[LI].Value);
  finally
    ATarget.FLock.ReleaseWrite;
  end;
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

function FormatIniLoadError(const AError: TIniError): string;
begin
  Result := AError.Message;
  if Result = '' then
    Result := 'parse error';
  if (AError.Line > 0) and (AError.Column > 0) then
    Result := 'INI parse error at line ' + UIntToStr(AError.Line) +
      ', column ' + UIntToStr(AError.Column) + ' (offset ' +
      UIntToStr(AError.Offset) + '): ' + Result
  else
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

    if TryGetResolvedEntryFastLocked(LIdx, AValue) then
      Exit;

    LStack := nil;
    AValue := ResolveConfigEntryByIndexTracked(FEntries, FLowerKeys,
      FLookupSlots, FCount, LIdx, LStack, False, '', LCacheable);
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
      SetLength(FEntries, FCount + 16);
      SetLength(FLowerKeys, FCount + 16);
      SetLength(FEntryHasPlaceholder, FCount + 16);
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
  SetString(AKey, BoolToStr(AValue));
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
        AError := FormatIniLoadError(LIni.Error);
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

procedure TConfig.SetDefault(const AKey, AValue: string);
begin
  RequireConfigKey(AKey);
  FLock.AcquireWrite;
  try
    if FindIndex(AKey) < 0 then
      SetValueUnlocked(AKey, AValue);
  finally
    FLock.ReleaseWrite;
  end;
end;

procedure TConfig.DeleteKey(const AKey: string);
begin
  RequireConfigKey(AKey);
  FLock.AcquireWrite;
  try
    DeleteKeyUnlocked(AKey);
  finally
    FLock.ReleaseWrite;
  end;
end;

procedure TConfig.DeleteSection(const APrefix: string);
begin
  RequireConfigPrefix(APrefix);
  FLock.AcquireWrite;
  try
    DeleteSectionUnlocked(APrefix);
  finally
    FLock.ReleaseWrite;
  end;
end;

procedure TConfig.Clear;
begin
  FLock.AcquireWrite;
  try
    ClearUnlocked;
  finally
    FLock.ReleaseWrite;
  end;
end;

function TConfig.ToJson: string;
var
  LEntries: TConfigEntryArray;
  LCount: Integer;
begin
  SnapshotConfigEntries(Self, LEntries, LCount);
  Result := ConfigEntriesToJson(LEntries, LCount);
end;

function TConfig.ToIni: string;
var
  LEntries: TConfigEntryArray;
  LCount: Integer;
begin
  SnapshotConfigEntries(Self, LEntries, LCount);
  Result := ConfigEntriesToIni(LEntries, LCount);
end;

procedure TConfig.SaveToIni(const APath: string);
begin
  ConfigWriteAtomicText(APath, ToIni);
end;

procedure TConfig.SaveToJson(const APath: string);
begin
  ConfigWriteAtomicText(APath, ToJson);
end;

function TConfig.ToYaml: string;
var
  LEntries: TConfigEntryArray;
  LCount: Integer;
begin
  SnapshotConfigEntries(Self, LEntries, LCount);
  Result := ConfigEntriesToYaml(LEntries, LCount);
end;

procedure TConfig.SaveToYaml(const APath: string);
begin
  ConfigWriteAtomicText(APath, ToYaml);
end;

function TConfig.ToToml: string;
var
  LEntries: TConfigEntryArray;
  LCount: Integer;
begin
  SnapshotConfigEntries(Self, LEntries, LCount);
  Result := ConfigEntriesToToml(LEntries, LCount);
end;

procedure TConfig.SaveToToml(const APath: string);
begin
  ConfigWriteAtomicText(APath, ToToml);
end;

function TConfig.GetString(const AKey: string; const ADefault: string): string;
var
  LFound: Boolean;
  LIdx: Integer;
  LStack: TStringArray;
begin
  RequireConfigKey(AKey);
  LFound := False;
  FLock.AcquireRead;
  try
    LIdx := FindIndexCached(AKey);
    if LIdx >= 0 then
    begin
      LFound := True;
      if TryGetResolvedEntryFastLocked(LIdx, Result) then
        Exit;
    end
    else
    begin
      Result := ADefault;
      if Pos('$', Result) = 0 then
        Exit;
      LStack := nil;
      Result := InterpolateConfigValue(FEntries, FLowerKeys, FLookupSlots,
        FCount, ADefault, LStack, False, '');
      Exit;
    end;
  finally
    FLock.ReleaseRead;
  end;

  if LFound and TryGetValue(AKey, Result) then
    Exit;

  Result := ADefault;
  if Pos('$', Result) <> 0 then
  begin
    FLock.AcquireRead;
    try
      LStack := nil;
      Result := InterpolateConfigValue(FEntries, FLowerKeys, FLookupSlots,
        FCount, ADefault, LStack, False, '');
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
begin
  if AKey <> '' then
    RequireConfigKey(AKey);
  Result := nil;
  LLowerKey := LowerCase(AKey);
  FLock.AcquireRead;
  try
    if HasArrayCacheLocked(LLowerKey) then
    begin
      CopyArrayCacheLocked(LValues, LAllLiteral);
      if LAllLiteral then
      begin
        Result := LValues;
        Exit;
      end;

      SetLength(Result, Length(LValues));
      LStack := nil;
      for LI := 0 to Length(LValues) - 1 do
        Result[LI] := InterpolateConfigValue(FEntries, FLowerKeys, FLookupSlots,
          FCount, LValues[LI], LStack, False, '');
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
    if LAllLiteral then
    begin
      Result := LValues;
      Exit;
    end;

    SetLength(Result, Length(LValues));
    LStack := nil;
    for LI := 0 to Length(LValues) - 1 do
      Result[LI] := InterpolateConfigValue(FEntries, FLowerKeys, FLookupSlots,
        FCount, LValues[LI], LStack, False, '');
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
begin
  if AOther = nil then
    raise ENextPasError.Create('TConfig.ReplaceFrom requires a source config');
  if AOther = Self then
    Exit;

  AOther.FLock.AcquireRead;
  try
    LCount := AOther.FCount;
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

{ TOwnedConfig }

constructor TOwnedConfig.Create(AConfig: TConfig);
begin
  inherited Create;
  FConfig := AConfig;
end;

destructor TOwnedConfig.Destroy;
begin
  if FConfig <> nil then
    FConfig.Free;
  inherited Destroy;
end;

function TOwnedConfig.GetCount: Integer;
begin
  Result := FConfig.Count;
end;

function TOwnedConfig.GetString(const AKey: string; const ADefault: string): string;
begin
  Result := FConfig.GetString(AKey, ADefault);
end;

function TOwnedConfig.GetRawString(const AKey: string; const ADefault: string): string;
begin
  Result := FConfig.GetRawString(AKey, ADefault);
end;

function TOwnedConfig.GetStringArray(const AKey: string): TStringArray;
begin
  Result := FConfig.GetStringArray(AKey);
end;

function TOwnedConfig.GetRawStringArray(const AKey: string): TStringArray;
begin
  Result := FConfig.GetRawStringArray(AKey);
end;

function TOwnedConfig.GetInt(const AKey: string; ADefault: Int64): Int64;
begin
  Result := FConfig.GetInt(AKey, ADefault);
end;

function TOwnedConfig.GetBool(const AKey: string; ADefault: Boolean): Boolean;
begin
  Result := FConfig.GetBool(AKey, ADefault);
end;

function TOwnedConfig.GetFloat(const AKey: string; ADefault: Double): Double;
begin
  Result := FConfig.GetFloat(AKey, ADefault);
end;

function TOwnedConfig.GetStringRequired(const AKey: string): string;
begin
  Result := FConfig.GetStringRequired(AKey);
end;

function TOwnedConfig.GetIntRequired(const AKey: string): Int64;
begin
  Result := FConfig.GetIntRequired(AKey);
end;

function TOwnedConfig.GetBoolRequired(const AKey: string): Boolean;
begin
  Result := FConfig.GetBoolRequired(AKey);
end;

function TOwnedConfig.GetFloatRequired(const AKey: string): Double;
begin
  Result := FConfig.GetFloatRequired(AKey);
end;

procedure TOwnedConfig.Require(const AKeys: array of string);
begin
  FConfig.Require(AKeys);
end;

function TOwnedConfig.Has(const AKey: string): Boolean;
begin
  Result := FConfig.Has(AKey);
end;

function TOwnedConfig.GetKeys: TStringArray;
begin
  Result := FConfig.GetKeys;
end;

function TOwnedConfig.GetSection(const APrefix: string): TStringArray;
begin
  Result := FConfig.GetSection(APrefix);
end;

function TOwnedConfig.ToJson: string;
begin
  Result := FConfig.ToJson;
end;

function TOwnedConfig.ToIni: string;
begin
  Result := FConfig.ToIni;
end;

function TOwnedConfig.ToYaml: string;
begin
  Result := FConfig.ToYaml;
end;

function TOwnedConfig.ToToml: string;
begin
  Result := FConfig.ToToml;
end;

{ TConfigBuilderImpl }

function TConfigBuilderImpl.DefaultIndexOf(const AKey: string): Integer;
begin
  Result := FindEntryIndexInSnapshot(FDefaults, FDefaultCount, AKey);
end;

procedure TConfigBuilderImpl.StoreDefault(const AKey, AValue: string);
var
  LIndex: Integer;
begin
  RequireConfigKey(AKey);
  LIndex := DefaultIndexOf(AKey);
  if LIndex >= 0 then
    FDefaults[LIndex].Value := AValue
  else
  begin
    if FDefaultCount >= Length(FDefaults) then
      SetLength(FDefaults, FDefaultCount + 8);
    FDefaults[FDefaultCount].Key := AKey;
    FDefaults[FDefaultCount].Value := AValue;
    Inc(FDefaultCount);
  end;
end;

procedure TConfigBuilderImpl.StoreSource(const AKind: TConfigSourceKind;
  const AValue: string; AFormat: TConfigFormat);
begin
  AddConfigSource(FSources, FSourceCount, AKind, AValue, AFormat);
end;

procedure TConfigBuilderImpl.StoreRequiredKey(const AKey: string);
begin
  RequireConfigKey(AKey);
  AddString(FRequiredKeys, FRequiredCount, AKey);
end;

procedure TConfigBuilderImpl.ApplyDefaults(ACfg: TConfig);
var
  LI: Integer;
begin
  for LI := 0 to FDefaultCount - 1 do
    ACfg.SetDefault(FDefaults[LI].Key, FDefaults[LI].Value);
end;

procedure TConfigBuilderImpl.ApplySource(ACfg: TConfig; const ASource: TConfigSource);
var
  LError: string;
begin
  case ASource.Kind of
    cskIni:
      if not ACfg.TryLoadFromIni(ASource.Value, LError) then
        raise EConfigError.Create(LError);
    cskJson:
      ACfg.LoadFromJson(ASource.Value);
    cskYaml:
      ACfg.LoadFromYaml(ASource.Value);
    cskToml:
      ACfg.LoadFromToml(ASource.Value);
    cskEnv:
      ACfg.LoadFromEnv(ASource.Value);
    cskFile:
      if not ACfg.TryLoadFromFile(ASource.Value, ASource.Format, LError) then
        raise EConfigError.Create(LError);
  end;
end;

procedure TConfigBuilderImpl.ApplyRequiredKeys(ACfg: TConfig);
var
  LI: Integer;
begin
  for LI := 0 to FRequiredCount - 1 do
    ACfg.GetStringRequired(FRequiredKeys[LI]);
end;

function TConfigBuilderImpl.BuildFreshConfig: TConfig;
var
  LI: Integer;
begin
  Result := TConfig.Create;
  try
    ApplyDefaults(Result);
    for LI := 0 to FSourceCount - 1 do
      ApplySource(Result, FSources[LI]);
    ApplyRequiredKeys(Result);
  except
    Result.Free;
    raise;
  end;
end;

function TConfigBuilderImpl.AddDefault(const AKey, AValue: string): IConfigBuilder;
begin
  StoreDefault(AKey, AValue);
  Result := Self;
end;

function TConfigBuilderImpl.AddIni(const AContent: string): IConfigBuilder;
begin
  StoreSource(cskIni, AContent, cfIni);
  Result := Self;
end;

function TConfigBuilderImpl.AddJson(const AContent: string): IConfigBuilder;
begin
  StoreSource(cskJson, AContent, cfJson);
  Result := Self;
end;

function TConfigBuilderImpl.AddYaml(const AContent: string): IConfigBuilder;
begin
  StoreSource(cskYaml, AContent, cfYaml);
  Result := Self;
end;

function TConfigBuilderImpl.AddToml(const AContent: string): IConfigBuilder;
begin
  StoreSource(cskToml, AContent, cfToml);
  Result := Self;
end;

function TConfigBuilderImpl.AddEnv(const APrefix: string): IConfigBuilder;
begin
  RequireConfigEnvPrefix(APrefix);
  StoreSource(cskEnv, APrefix, cfIni);
  Result := Self;
end;

function TConfigBuilderImpl.AddFile(const APath: string;
  AFormat: TConfigFormat): IConfigBuilder;
begin
  RequireConfigFilePath(APath);
  StoreSource(cskFile, APath, AFormat);
  Result := Self;
end;

function TConfigBuilderImpl.RequireKeys(const AKeys: array of string): IConfigBuilder;
var
  LI: Integer;
begin
  for LI := 0 to Length(AKeys) - 1 do
    StoreRequiredKey(AKeys[LI]);
  Result := Self;
end;

function TConfigBuilderImpl.Build: IConfig;
begin
  Result := TOwnedConfig.Create(BuildFreshConfig);
end;

function TConfigBuilderImpl.BuildConfig: TConfig;
begin
  Result := BuildFreshConfig;
end;

function TConfigBuilderImpl.TryBuild(out AConfig: IConfig; out AError: string): Boolean;
begin
  AConfig := nil;
  AError := '';
  try
    AConfig := Build;
    Result := True;
  except
    on E: EConfigError do
    begin
      AConfig := nil;
      AError := E.Message;
      Result := False;
    end;
  end;
end;

function ConfigBuilder: IConfigBuilder;
begin
  Result := TConfigBuilderImpl.Create;
end;

function ConfigLoad(const APath: string; AFormat: TConfigFormat): IConfig;
begin
  Result := ConfigBuilder.AddFile(APath, AFormat).Build;
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
  LConfig: TConfig;
  LError: string;
begin
  LConfig := TConfig.Create;
  try
    if not LConfig.TryLoadFromFile(FFilePath, FFormat, LError) then
      raise EConfigError.Create(LError);
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
  begin
    if (FLastMtime >= 0) or (FLastSize >= 0) then
      DoReload;
    Exit;
  end;
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
