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

  { Getter-time placeholder policy. Cycles always raise. }
  TConfigInterpolationMode = (
    cimDefault,   (* optional: leave ${x}; Required: fail unresolved *)
    cimStrict,    { all resolving getters fail on unresolved }
    cimDisabled   { no expansion; GetString acts like raw for values }
  );

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
    function GetDurationNs(const AKey: string; ADefault: Int64 = 0): Int64;
    function GetByteSize(const AKey: string; ADefault: Int64 = 0): Int64;
    { Typed try-get: True only when key resolves and value parses for the type. }
    function TryGetInt(const AKey: string; out AValue: Int64): Boolean;
    function TryGetBool(const AKey: string; out AValue: Boolean): Boolean;
    function TryGetFloat(const AKey: string; out AValue: Double): Boolean;
    function TryGetDurationNs(const AKey: string; out AValue: Int64): Boolean;
    function TryGetByteSize(const AKey: string; out AValue: Int64): Boolean;
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
    function AddFile(const APath: string; AFormat: TConfigFormat): IConfigBuilder; overload;
    { Detect format from path extension (.ini/.json/.yaml/.yml/.toml). }
    function AddFile(const APath: string): IConfigBuilder; overload;
    { Inline key/value overrides (CLI, maps, ad-hoc). Applied in chain order.
      AKeys and AValues must have the same length; empty keys raise EConfigError. }
    function AddKeyValues(const AKeys, AValues: array of string): IConfigBuilder;
    function SetInterpolationMode(AMode: TConfigInterpolationMode): IConfigBuilder;
    function RequireKeys(const AKeys: array of string): IConfigBuilder;
    function Build: IConfig;
    function BuildConfig: TConfig;
    function TryBuild(out AConfig: IConfig; out AError: string): Boolean;
  end;

  TConfigEntry = record
    Key: string;
    Value: string;
  end;

  TConfigEntryArray = array of TConfigEntry;

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
    FInterpolationMode: TConfigInterpolationMode;
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
    procedure LoadFromFile(const APath: string; AFormat: TConfigFormat); overload;
    { Detect format from path extension (.ini/.json/.yaml/.yml/.toml). }
    procedure LoadFromFile(const APath: string); overload;
    function TryLoadFromIni(const AContent: string; out AError: string): Boolean;
    function TryLoadFromJson(const AContent: string; out AError: string): Boolean;
    function TryLoadFromYaml(const AContent: string; out AError: string): Boolean;
    function TryLoadFromToml(const AContent: string; out AError: string): Boolean;
    function TryLoadFromFile(const APath: string; AFormat: TConfigFormat;
      out AError: string): Boolean; overload;
    function TryLoadFromFile(const APath: string; out AError: string): Boolean;
      overload;
    function TryLoadJson(const AContent: string; out AError: string): Boolean;
    function TryLoadYaml(const AContent: string; out AError: string): Boolean;
    function TryLoadToml(const AContent: string; out AError: string): Boolean;
    { 加载环境变量层：APrefix 前缀（非空）剥去后，双下划线 `__` 映射点路径
      （env-name → 配置 key，见 nextpas.core.config.env）。返回成功映射的
      key 集（未映射/前缀外变量忽略，不崩溃）。 }
    function LoadFromEnv(const APrefix: string): TStringArray;
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
    function GetDurationNs(const AKey: string; ADefault: Int64 = 0): Int64;
    function GetByteSize(const AKey: string; ADefault: Int64 = 0): Int64;
    function TryGetInt(const AKey: string; out AValue: Int64): Boolean;
    function TryGetBool(const AKey: string; out AValue: Boolean): Boolean;
    function TryGetFloat(const AKey: string; out AValue: Double): Boolean;
    function TryGetDurationNs(const AKey: string; out AValue: Int64): Boolean;
    function TryGetByteSize(const AKey: string; out AValue: Int64): Boolean;
    function GetStringRequired(const AKey: string): string;
    function GetIntRequired(const AKey: string): Int64;
    function GetBoolRequired(const AKey: string): Boolean;
    function GetFloatRequired(const AKey: string): Double;
    function GetDurationNsRequired(const AKey: string): Int64;
    function GetByteSizeRequired(const AKey: string): Int64;
    procedure Require(const AKeys: array of string);

    procedure ReplaceFrom(AOther: TConfig);
    { Deep copy of entries + interpolation mode. Caller Free. }
    function Clone: TConfig;
    { Overlay ASource keys onto Self (later wins). Does not free ASource. }
    procedure MergeFrom(ASource: TConfig); overload;
    procedure MergeFrom(const ASource: IConfig); overload;
    { Sorted key=rawValue lines (debug / test diagnostics). }
    function DebugDump: string;
    function Has(const AKey: string): Boolean;
    function GetKeys: TStringArray;
    function GetSection(const APrefix: string): TStringArray;
    procedure SetInterpolationMode(AMode: TConfigInterpolationMode);
    function GetInterpolationMode: TConfigInterpolationMode;
    property Count: Integer read GetCount;
  end;
function ConfigBuilder: IConfigBuilder;
function ConfigLoad(const APath: string; AFormat: TConfigFormat): IConfig; overload;
{ Detect format from path extension (.ini/.json/.yaml/.yml/.toml). }
function ConfigLoad(const APath: string): IConfig; overload;
{ Non-owning IConfig view. Keep AConfig alive while the interface is used. }
function ConfigBorrow(AConfig: TConfig): IConfig;
{ Non-owning prefix view (viper Sub). parent lifetime must outlive the view. }
function ConfigSection(const AConfig: IConfig; const APrefix: string): IConfig; overload;
function ConfigSection(AConfig: TConfig; const APrefix: string): IConfig; overload;
{ Sorted key=rawValue dump for any IConfig. }
function ConfigDebugDump(const AConfig: IConfig): string;
{ Parse duration suffixes: ns/us/ms/s/m/h; bare integer = seconds. }
function TryParseConfigDurationNs(const AText: string; out ANanos: Int64): Boolean;
{ Parse byte size: b/kb/kib/mb/mib/gb/gib (1024-based); bare integer = bytes. }
function TryParseConfigByteSize(const AText: string; out ABytes: Int64): Boolean;

function IsSupportedConfigFormat(AFormat: TConfigFormat): Boolean;
{ Map path extension to TConfigFormat. False if unknown/empty extension. }
function TryDetectConfigFormat(const APath: string; out AFormat: TConfigFormat): Boolean;
{ Content sniff (no disk I/O). Try-parse order: JSON → TOML → YAML → INI. }
function TrySniffConfigFormat(const AContent: string; out AFormat: TConfigFormat): Boolean;
procedure AddString(var AItems: TStringArray; var ACount: Integer;
  const AValue: string);
function FindEntryIndexInSnapshot(const AEntries: TConfigEntryArray;
  const ACount: Integer; const AKey: string): Integer;
procedure RequireConfigKey(const AKey: string);
procedure RequireConfigEnvPrefix(const APrefix: string);
procedure RequireConfigFilePath(const APath: string);
function TryParseArrayIndex(const AValue: string; out AIndex: Int64): Boolean;
function NextConfigPathSegment(const AKey: string; var APos: Integer;
  out ASegment: string): Boolean;
function DisplayConfigPath(const APath: string): string;
procedure RequireHierarchicalConfigPath(const AKey: string);

implementation

uses
  nextpas.core.base,
  nextpas.core.config.builder,
  nextpas.core.config.env,
  nextpas.core.config.export,
  nextpas.core.config.flatten,
  nextpas.core.config.watcher,
  nextpas.core.fs,
  nextpas.core.hash.wyhash,
  nextpas.core.text.number,
  nextpas.core.yaml,
  nextpas.core.toml;

type
  TIndexedConfigValue = record
    Index: Int64;
    Value: string;
  end;

  TIndexedConfigValueArray = array of TIndexedConfigValue;

{$IFDEF NEXTPAS_UNIX}
var
  environ: PPAnsiChar; cvar; external;
{$ENDIF}

const
  ConfigFilePathEmptyError = 'config file path must not be empty';

{$I nextpas.core.config.helpers.inc}
{$I nextpas.core.config.storage.inc}
{$I nextpas.core.config.load_impl.inc}
{$I nextpas.core.config.mutate.inc}
{$I nextpas.core.config.export_impl.inc}
{$I nextpas.core.config.getters.inc}

end.
