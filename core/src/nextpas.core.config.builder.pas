unit nextpas.core.config.builder;
{**
 * @desc Config builder and owned read-only snapshot implementation.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.config;

function ConfigBuilder: IConfigBuilder;
function ConfigLoad(const APath: string; AFormat: TConfigFormat): IConfig; overload;
function ConfigLoad(const APath: string): IConfig; overload;
function ConfigBorrow(AConfig: TConfig): IConfig;
function ConfigSection(const AConfig: IConfig; const APrefix: string): IConfig; overload;
function ConfigSection(AConfig: TConfig; const APrefix: string): IConfig; overload;

implementation

uses
  nextpas.core.base,
  nextpas.core.config.env,
  nextpas.core.fs,
  nextpas.core.platform.files.base,
  nextpas.core.text.conv;

type
  TConfigSourceKind = (
    cskIni,
    cskJson,
    cskYaml,
    cskToml,
    cskEnv,
    cskFile,
    cskFileAuto, { resolve via extension + content sniff at Build }
    cskKeyValues
  );

  TConfigSource = record
    Kind: TConfigSourceKind;
    Value: string;
    Format: TConfigFormat;
    Entries: TConfigEntryArray;
    EntryCount: Integer;
  end;

  TConfigSourceArray = array of TConfigSource;

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
    function GetDurationNs(const AKey: string; ADefault: Int64 = 0): Int64;
    function GetByteSize(const AKey: string; ADefault: Int64 = 0): Int64;
    function GetStringRequired(const AKey: string): string;
    function GetIntRequired(const AKey: string): Int64;
    function GetBoolRequired(const AKey: string): Boolean;
    function GetFloatRequired(const AKey: string): Double;
    function GetDurationNsRequired(const AKey: string): Int64;
    function GetByteSizeRequired(const AKey: string): Int64;
    procedure Require(const AKeys: array of string);
    function Has(const AKey: string): Boolean;
    function GetKeys: TStringArray;
    function GetSection(const APrefix: string): TStringArray;
    function GetInterpolationMode: TConfigInterpolationMode;
    function ToIni: string;
    function ToJson: string;
    function ToYaml: string;
    function ToToml: string;
  end;

  { Non-owning IConfig; does not Free FConfig. }
  TBorrowedConfig = class(TInterfacedObject, IConfig)
  private
    FConfig: TConfig;
    function GetCount: Integer;
  public
    constructor Create(AConfig: TConfig);
    function GetString(const AKey: string; const ADefault: string = ''): string;
    function GetRawString(const AKey: string; const ADefault: string = ''): string;
    function GetStringArray(const AKey: string): TStringArray;
    function GetRawStringArray(const AKey: string): TStringArray;
    function GetInt(const AKey: string; ADefault: Int64 = 0): Int64;
    function GetBool(const AKey: string; ADefault: Boolean = False): Boolean;
    function GetFloat(const AKey: string; ADefault: Double = 0.0): Double;
    function GetDurationNs(const AKey: string; ADefault: Int64 = 0): Int64;
    function GetByteSize(const AKey: string; ADefault: Int64 = 0): Int64;
    function GetStringRequired(const AKey: string): string;
    function GetIntRequired(const AKey: string): Int64;
    function GetBoolRequired(const AKey: string): Boolean;
    function GetFloatRequired(const AKey: string): Double;
    function GetDurationNsRequired(const AKey: string): Int64;
    function GetByteSizeRequired(const AKey: string): Int64;
    procedure Require(const AKeys: array of string);
    function Has(const AKey: string): Boolean;
    function GetKeys: TStringArray;
    function GetSection(const APrefix: string): TStringArray;
    function GetInterpolationMode: TConfigInterpolationMode;
    function ToIni: string;
    function ToJson: string;
    function ToYaml: string;
    function ToToml: string;
  end;

  { Non-owning prefix view over any IConfig (viper Sub). }
  TSectionConfig = class(TInterfacedObject, IConfig)
  private
    FParent: IConfig;
    FPrefix: string;
    function GetCount: Integer;
    function FullKey(const AKey: string): string;
  public
    constructor Create(const AParent: IConfig; const APrefix: string);
    function GetString(const AKey: string; const ADefault: string = ''): string;
    function GetRawString(const AKey: string; const ADefault: string = ''): string;
    function GetStringArray(const AKey: string): TStringArray;
    function GetRawStringArray(const AKey: string): TStringArray;
    function GetInt(const AKey: string; ADefault: Int64 = 0): Int64;
    function GetBool(const AKey: string; ADefault: Boolean = False): Boolean;
    function GetFloat(const AKey: string; ADefault: Double = 0.0): Double;
    function GetDurationNs(const AKey: string; ADefault: Int64 = 0): Int64;
    function GetByteSize(const AKey: string; ADefault: Int64 = 0): Int64;
    function GetStringRequired(const AKey: string): string;
    function GetIntRequired(const AKey: string): Int64;
    function GetBoolRequired(const AKey: string): Boolean;
    function GetFloatRequired(const AKey: string): Double;
    function GetDurationNsRequired(const AKey: string): Int64;
    function GetByteSizeRequired(const AKey: string): Int64;
    procedure Require(const AKeys: array of string);
    function Has(const AKey: string): Boolean;
    function GetKeys: TStringArray;
    function GetSection(const APrefix: string): TStringArray;
    function GetInterpolationMode: TConfigInterpolationMode;
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
    FInterpolationMode: TConfigInterpolationMode;
    FHasInterpolationMode: Boolean;
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
    constructor Create;
    function AddDefault(const AKey, AValue: string): IConfigBuilder;
    function AddIni(const AContent: string): IConfigBuilder;
    function AddJson(const AContent: string): IConfigBuilder;
    function AddYaml(const AContent: string): IConfigBuilder;
    function AddToml(const AContent: string): IConfigBuilder;
    function AddEnv(const APrefix: string): IConfigBuilder;
    function AddFile(const APath: string; AFormat: TConfigFormat): IConfigBuilder; overload;
    function AddFile(const APath: string): IConfigBuilder; overload;
    function AddKeyValues(const AKeys, AValues: array of string): IConfigBuilder;
    function SetInterpolationMode(AMode: TConfigInterpolationMode): IConfigBuilder;
    function RequireKeys(const AKeys: array of string): IConfigBuilder;
    function Build: IConfig;
    function BuildConfig: TConfig;
    function TryBuild(out AConfig: IConfig; out AError: string): Boolean;
  end;

procedure AddConfigSource(var AItems: TConfigSourceArray; var ACount: Integer;
  const AKind: TConfigSourceKind; const AValue: string; AFormat: TConfigFormat);
begin
  if ACount >= Length(AItems) then
    SetLength(AItems, ACount + 8);
  AItems[ACount].Kind := AKind;
  AItems[ACount].Value := AValue;
  AItems[ACount].Format := AFormat;
  AItems[ACount].Entries := nil;
  AItems[ACount].EntryCount := 0;
  Inc(ACount);
end;

procedure AddKeyValueSource(var AItems: TConfigSourceArray; var ACount: Integer;
  const AEntries: TConfigEntryArray; AEntryCount: Integer);
begin
  if ACount >= Length(AItems) then
    SetLength(AItems, ACount + 8);
  AItems[ACount].Kind := cskKeyValues;
  AItems[ACount].Value := '';
  AItems[ACount].Format := cfIni;
  AItems[ACount].Entries := AEntries;
  AItems[ACount].EntryCount := AEntryCount;
  Inc(ACount);
end;

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

function TOwnedConfig.GetDurationNs(const AKey: string; ADefault: Int64): Int64;
begin
  Result := FConfig.GetDurationNs(AKey, ADefault);
end;

function TOwnedConfig.GetByteSize(const AKey: string; ADefault: Int64): Int64;
begin
  Result := FConfig.GetByteSize(AKey, ADefault);
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

function TOwnedConfig.GetDurationNsRequired(const AKey: string): Int64;
begin
  Result := FConfig.GetDurationNsRequired(AKey);
end;

function TOwnedConfig.GetByteSizeRequired(const AKey: string): Int64;
begin
  Result := FConfig.GetByteSizeRequired(AKey);
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

function TOwnedConfig.GetInterpolationMode: TConfigInterpolationMode;
begin
  Result := FConfig.GetInterpolationMode;
end;

{ TBorrowedConfig }

constructor TBorrowedConfig.Create(AConfig: TConfig);
begin
  inherited Create;
  FConfig := AConfig;
end;

function TBorrowedConfig.GetCount: Integer;
begin
  Result := FConfig.Count;
end;

function TBorrowedConfig.GetString(const AKey: string; const ADefault: string): string;
begin
  Result := FConfig.GetString(AKey, ADefault);
end;

function TBorrowedConfig.GetRawString(const AKey: string; const ADefault: string): string;
begin
  Result := FConfig.GetRawString(AKey, ADefault);
end;

function TBorrowedConfig.GetStringArray(const AKey: string): TStringArray;
begin
  Result := FConfig.GetStringArray(AKey);
end;

function TBorrowedConfig.GetRawStringArray(const AKey: string): TStringArray;
begin
  Result := FConfig.GetRawStringArray(AKey);
end;

function TBorrowedConfig.GetInt(const AKey: string; ADefault: Int64): Int64;
begin
  Result := FConfig.GetInt(AKey, ADefault);
end;

function TBorrowedConfig.GetBool(const AKey: string; ADefault: Boolean): Boolean;
begin
  Result := FConfig.GetBool(AKey, ADefault);
end;

function TBorrowedConfig.GetFloat(const AKey: string; ADefault: Double): Double;
begin
  Result := FConfig.GetFloat(AKey, ADefault);
end;

function TBorrowedConfig.GetDurationNs(const AKey: string; ADefault: Int64): Int64;
begin
  Result := FConfig.GetDurationNs(AKey, ADefault);
end;

function TBorrowedConfig.GetByteSize(const AKey: string; ADefault: Int64): Int64;
begin
  Result := FConfig.GetByteSize(AKey, ADefault);
end;

function TBorrowedConfig.GetStringRequired(const AKey: string): string;
begin
  Result := FConfig.GetStringRequired(AKey);
end;

function TBorrowedConfig.GetIntRequired(const AKey: string): Int64;
begin
  Result := FConfig.GetIntRequired(AKey);
end;

function TBorrowedConfig.GetBoolRequired(const AKey: string): Boolean;
begin
  Result := FConfig.GetBoolRequired(AKey);
end;

function TBorrowedConfig.GetFloatRequired(const AKey: string): Double;
begin
  Result := FConfig.GetFloatRequired(AKey);
end;

function TBorrowedConfig.GetDurationNsRequired(const AKey: string): Int64;
begin
  Result := FConfig.GetDurationNsRequired(AKey);
end;

function TBorrowedConfig.GetByteSizeRequired(const AKey: string): Int64;
begin
  Result := FConfig.GetByteSizeRequired(AKey);
end;

procedure TBorrowedConfig.Require(const AKeys: array of string);
begin
  FConfig.Require(AKeys);
end;

function TBorrowedConfig.Has(const AKey: string): Boolean;
begin
  Result := FConfig.Has(AKey);
end;

function TBorrowedConfig.GetKeys: TStringArray;
begin
  Result := FConfig.GetKeys;
end;

function TBorrowedConfig.GetSection(const APrefix: string): TStringArray;
begin
  Result := FConfig.GetSection(APrefix);
end;

function TBorrowedConfig.GetInterpolationMode: TConfigInterpolationMode;
begin
  Result := FConfig.GetInterpolationMode;
end;

function TBorrowedConfig.ToIni: string;
begin
  Result := FConfig.ToIni;
end;

function TBorrowedConfig.ToJson: string;
begin
  Result := FConfig.ToJson;
end;

function TBorrowedConfig.ToYaml: string;
begin
  Result := FConfig.ToYaml;
end;

function TBorrowedConfig.ToToml: string;
begin
  Result := FConfig.ToToml;
end;

{ TSectionConfig }

function NormalizeSectionPrefix(const APrefix: string): string;
begin
  Result := APrefix;
  while (Length(Result) > 0) and (Result[Length(Result)] = '.') do
    SetLength(Result, Length(Result) - 1);
end;

constructor TSectionConfig.Create(const AParent: IConfig; const APrefix: string);
begin
  inherited Create;
  if AParent = nil then
    raise EConfigError.Create('ConfigSection requires a non-nil parent IConfig');
  FParent := AParent;
  FPrefix := NormalizeSectionPrefix(APrefix);
end;

function TSectionConfig.FullKey(const AKey: string): string;
begin
  if FPrefix = '' then
    Exit(AKey);
  if AKey = '' then
    Exit(FPrefix);
  Result := FPrefix + '.' + AKey;
end;

function TSectionConfig.GetCount: Integer;
var
  LKeys: TStringArray;
begin
  LKeys := GetKeys;
  Result := Length(LKeys);
end;

function TSectionConfig.GetString(const AKey: string; const ADefault: string): string;
begin
  Result := FParent.GetString(FullKey(AKey), ADefault);
end;

function TSectionConfig.GetRawString(const AKey: string; const ADefault: string): string;
begin
  Result := FParent.GetRawString(FullKey(AKey), ADefault);
end;

function TSectionConfig.GetStringArray(const AKey: string): TStringArray;
begin
  Result := FParent.GetStringArray(FullKey(AKey));
end;

function TSectionConfig.GetRawStringArray(const AKey: string): TStringArray;
begin
  Result := FParent.GetRawStringArray(FullKey(AKey));
end;

function TSectionConfig.GetInt(const AKey: string; ADefault: Int64): Int64;
begin
  Result := FParent.GetInt(FullKey(AKey), ADefault);
end;

function TSectionConfig.GetBool(const AKey: string; ADefault: Boolean): Boolean;
begin
  Result := FParent.GetBool(FullKey(AKey), ADefault);
end;

function TSectionConfig.GetFloat(const AKey: string; ADefault: Double): Double;
begin
  Result := FParent.GetFloat(FullKey(AKey), ADefault);
end;

function TSectionConfig.GetDurationNs(const AKey: string; ADefault: Int64): Int64;
begin
  Result := FParent.GetDurationNs(FullKey(AKey), ADefault);
end;

function TSectionConfig.GetByteSize(const AKey: string; ADefault: Int64): Int64;
begin
  Result := FParent.GetByteSize(FullKey(AKey), ADefault);
end;

function TSectionConfig.GetStringRequired(const AKey: string): string;
begin
  Result := FParent.GetStringRequired(FullKey(AKey));
end;

function TSectionConfig.GetIntRequired(const AKey: string): Int64;
begin
  Result := FParent.GetIntRequired(FullKey(AKey));
end;

function TSectionConfig.GetBoolRequired(const AKey: string): Boolean;
begin
  Result := FParent.GetBoolRequired(FullKey(AKey));
end;

function TSectionConfig.GetFloatRequired(const AKey: string): Double;
begin
  Result := FParent.GetFloatRequired(FullKey(AKey));
end;

function TSectionConfig.GetDurationNsRequired(const AKey: string): Int64;
begin
  Result := FParent.GetDurationNsRequired(FullKey(AKey));
end;

function TSectionConfig.GetByteSizeRequired(const AKey: string): Int64;
begin
  Result := FParent.GetByteSizeRequired(FullKey(AKey));
end;

procedure TSectionConfig.Require(const AKeys: array of string);
var
  LI: Integer;
  LFull: array of string;
begin
  SetLength(LFull, Length(AKeys));
  for LI := 0 to High(AKeys) do
    LFull[LI] := FullKey(AKeys[LI]);
  FParent.Require(LFull);
end;

function TSectionConfig.Has(const AKey: string): Boolean;
begin
  Result := FParent.Has(FullKey(AKey));
end;

function SectionKeySuffix(const AKey, APrefix: string; out ASuffix: string): Boolean;
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

function TSectionConfig.GetKeys: TStringArray;
var
  LAll: TStringArray;
  LSuffix: string;
  LCount, LI: Integer;
begin
  LAll := FParent.GetKeys;
  Result := nil;
  LCount := 0;
  for LI := 0 to High(LAll) do
    if SectionKeySuffix(LAll[LI], FPrefix, LSuffix) then
    begin
      if LCount >= Length(Result) then
        SetLength(Result, LCount + 8);
      Result[LCount] := LSuffix;
      Inc(LCount);
    end;
  SetLength(Result, LCount);
end;

function TSectionConfig.GetSection(const APrefix: string): TStringArray;
var
  LJoined: string;
begin
  if FPrefix = '' then
    LJoined := NormalizeSectionPrefix(APrefix)
  else if NormalizeSectionPrefix(APrefix) = '' then
    LJoined := FPrefix
  else
    LJoined := FPrefix + '.' + NormalizeSectionPrefix(APrefix);
  Result := FParent.GetSection(LJoined);
end;

function TSectionConfig.GetInterpolationMode: TConfigInterpolationMode;
begin
  Result := FParent.GetInterpolationMode;
end;

function TSectionConfig.ToIni: string;
begin
  Result := '';
  raise EConfigError.Create('ConfigSection view does not support export');
end;

function TSectionConfig.ToJson: string;
begin
  Result := '';
  raise EConfigError.Create('ConfigSection view does not support export');
end;

function TSectionConfig.ToYaml: string;
begin
  Result := '';
  raise EConfigError.Create('ConfigSection view does not support export');
end;

function TSectionConfig.ToToml: string;
begin
  Result := '';
  raise EConfigError.Create('ConfigSection view does not support export');
end;

function ConfigSection(const AConfig: IConfig; const APrefix: string): IConfig;
begin
  Result := TSectionConfig.Create(AConfig, APrefix);
end;

function ConfigSection(AConfig: TConfig; const APrefix: string): IConfig;
begin
  if AConfig = nil then
    raise EConfigError.Create('ConfigSection requires a non-nil TConfig');
  Result := ConfigSection(ConfigBorrow(AConfig), APrefix);
end;

{ TConfigBuilderImpl }

constructor TConfigBuilderImpl.Create;
begin
  inherited Create;
  FInterpolationMode := cimDefault;
  FHasInterpolationMode := False;
end;

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
  LI: Integer;
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
    cskFileAuto:
      if not ACfg.TryLoadFromFile(ASource.Value, LError) then
        raise EConfigError.Create(LError);
    cskKeyValues:
      for LI := 0 to ASource.EntryCount - 1 do
        ACfg.SetString(ASource.Entries[LI].Key, ASource.Entries[LI].Value);
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
    if FHasInterpolationMode then
      Result.SetInterpolationMode(FInterpolationMode);
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

function TConfigBuilderImpl.AddFile(const APath: string): IConfigBuilder;
begin
  RequireConfigFilePath(APath);
  { Extension detect + content sniff happen at Build (TryLoadFromFile). }
  StoreSource(cskFileAuto, APath, cfIni);
  Result := Self;
end;

function TConfigBuilderImpl.AddKeyValues(const AKeys, AValues: array of string): IConfigBuilder;
var
  LI: Integer;
  LEntries: TConfigEntryArray;
  LCount: Integer;
begin
  if Length(AKeys) <> Length(AValues) then
    raise EConfigError.Create(
      'AddKeyValues requires AKeys and AValues of equal length');
  LCount := Length(AKeys);
  SetLength(LEntries, LCount);
  for LI := 0 to LCount - 1 do
  begin
    RequireConfigKey(AKeys[LI]);
    LEntries[LI].Key := AKeys[LI];
    LEntries[LI].Value := AValues[LI];
  end;
  AddKeyValueSource(FSources, FSourceCount, LEntries, LCount);
  Result := Self;
end;

function TConfigBuilderImpl.SetInterpolationMode(
  AMode: TConfigInterpolationMode): IConfigBuilder;
begin
  FInterpolationMode := AMode;
  FHasInterpolationMode := True;
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

function ConfigLoad(const APath: string): IConfig;
begin
  Result := ConfigBuilder.AddFile(APath).Build;
end;

function ConfigBorrow(AConfig: TConfig): IConfig;
begin
  if AConfig = nil then
    raise EConfigError.Create('ConfigBorrow requires a non-nil TConfig');
  Result := TBorrowedConfig.Create(AConfig);
end;

end.
