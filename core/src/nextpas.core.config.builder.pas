unit nextpas.core.config.builder;
{**
 * @desc Config builder and owned read-only snapshot implementation.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.config;

function ConfigBuilder: IConfigBuilder;
function ConfigLoad(const APath: string; AFormat: TConfigFormat): IConfig;

implementation

uses
  nextpas.core.base,
  nextpas.core.config.env,
  nextpas.core.fs,
  nextpas.core.platform.files.base;

type
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

end.
