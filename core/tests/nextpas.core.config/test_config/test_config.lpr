program test_config;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.os.env,
  nextpas.core.time,
  nextpas.core.config,
  nextpas.core.testing;

var
  T: TTestRunner;

type
  TConfigReloadProbe = class
  private
    FReloaded: Boolean;
    FCallCount: Integer;
    FLastSender: TConfig;
    FObservedHost: string;
    FObservedPort: Int64;
    FObservedHasStale: Boolean;
    FObservedHasFeatureEnabled: Boolean;
    FObservedFeatureEnabled: Boolean;
  public
    procedure MarkReloaded(ASender: TConfig);
    property Reloaded: Boolean read FReloaded;
    property CallCount: Integer read FCallCount;
    property LastSender: TConfig read FLastSender;
    property ObservedHost: string read FObservedHost;
    property ObservedPort: Int64 read FObservedPort;
    property ObservedHasStale: Boolean read FObservedHasStale;
    property ObservedHasFeatureEnabled: Boolean read FObservedHasFeatureEnabled;
    property ObservedFeatureEnabled: Boolean read FObservedFeatureEnabled;
  end;

procedure TConfigReloadProbe.MarkReloaded(ASender: TConfig);
begin
  FReloaded := ASender <> nil;
  Inc(FCallCount);
  FLastSender := ASender;
  FObservedHost := '';
  FObservedPort := 0;
  FObservedHasStale := False;
  FObservedHasFeatureEnabled := False;
  FObservedFeatureEnabled := False;
  if ASender <> nil then
  begin
    FObservedHost := ASender.GetString('server.host');
    FObservedPort := ASender.GetInt('server.port');
    FObservedHasStale := ASender.Has('stale.value');
    FObservedHasFeatureEnabled := ASender.Has('feature.enabled');
    if FObservedHasFeatureEnabled then
      FObservedFeatureEnabled := ASender.GetBool('feature.enabled');
  end;
end;

{ === GetString Tests === }

procedure TestGetStringBasic;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[app]' + #10 + 'host=localhost' + #10 + 'port=8080' + #10);
    CheckEqual('localhost', LCfg.GetString('app.host'), 'host');
    CheckEqual('8080', LCfg.GetString('app.port'), 'port');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetStringDefault;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    CheckEqual('fallback', LCfg.GetString('missing', 'fallback'), 'default');
    CheckEqual('', LCfg.GetString('missing'), 'empty default');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetStringCaseInsensitive;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[DB]' + #10 + 'Host=myhost' + #10);
    CheckEqual('myhost', LCfg.GetString('db.host'), 'lower lookup');
    CheckEqual('myhost', LCfg.GetString('DB.HOST'), 'upper lookup');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetRawStringPreservesPlaceholders;
var
  LCfg: TConfig;
begin
  SetEnv('NEXTPAS_CFG_RAW_PORT', '8080');
  try
    LCfg := TConfig.Create;
    try
      LCfg.LoadFromIni('host=localhost' + #10 +
        'url=http://${host}:${NEXTPAS_CFG_RAW_PORT}' + #10);
      CheckEqual('http://${host}:${NEXTPAS_CFG_RAW_PORT}',
        LCfg.GetRawString('url'), 'raw stored value');
      CheckEqual('http://${host}',
        LCfg.GetRawString('missing', 'http://${host}'),
        'raw default value');
      CheckEqual('http://localhost:8080',
        LCfg.GetString('url'), 'normal getter still interpolates');
    finally
      LCfg.Free;
    end;
  finally
    UnsetEnv('NEXTPAS_CFG_RAW_PORT');
  end;
end;

procedure TestGetRawStringCaseInsensitive;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[DB]' + #10 + 'Host=myhost' + #10);
    CheckEqual('myhost', LCfg.GetRawString('db.host'), 'lower lookup');
    CheckEqual('myhost', LCfg.GetRawString('DB.HOST'), 'upper lookup');
  finally
    LCfg.Free;
  end;
end;

{ === Interpolation Tests === }

procedure TestInterpolationConfigKeys;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[server]' + #10 +
      'host=localhost' + #10 +
      'port=8080' + #10 +
      '[service]' + #10 +
      'url=https://${server.host}:${server.port}' + #10);
    CheckEqual('https://localhost:8080', LCfg.GetString('service.url'),
      'config key placeholders');
  finally
    LCfg.Free;
  end;
end;

procedure TestInterpolationExactPlaceholderChain;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[app]' + #10 +
      'name=nextpas' + #10 +
      'message=${app.name}' + #10 +
      'chain=${app.message}' + #10);
    CheckEqual('nextpas', LCfg.GetString('app.message'),
      'exact placeholder resolves direct config key');
    CheckEqual('nextpas', LCfg.GetString('app.chain'),
      'exact placeholder chain resolves transitively');
  finally
    LCfg.Free;
  end;
end;

procedure TestInterpolationCacheInvalidatesOnConfigWrite;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[app]' + #10 +
      'name=nextpas' + #10 +
      'message=${app.name}' + #10);
    CheckEqual('nextpas', LCfg.GetString('app.message'),
      'initial interpolated value');

    LCfg.SetString('app.name', 'updated');
    CheckEqual('updated', LCfg.GetString('app.message'),
      'config write invalidates cached interpolation');
  finally
    LCfg.Free;
  end;
end;

procedure TestInterpolationEnvFallbackIsNotCached;
var
  LCfg: TConfig;
begin
  SetEnv('NEXTPAS_CFG_INTERP_ENV_DYNAMIC', 'ap-east');
  try
    LCfg := TConfig.Create;
    try
      LCfg.LoadFromIni('region=${NEXTPAS_CFG_INTERP_ENV_DYNAMIC}' + #10);
      CheckEqual('ap-east', LCfg.GetString('region'),
        'initial env interpolation');

      SetEnv('NEXTPAS_CFG_INTERP_ENV_DYNAMIC', 'ap-south');
      CheckEqual('ap-south', LCfg.GetString('region'),
        'env-backed interpolation stays dynamic');
    finally
      LCfg.Free;
    end;
  finally
    UnsetEnv('NEXTPAS_CFG_INTERP_ENV_DYNAMIC');
  end;
end;

procedure TestInterpolationReplaceFromInvalidatesCache;
var
  LTarget: TConfig;
  LSource: TConfig;
begin
  LTarget := TConfig.Create;
  LSource := TConfig.Create;
  try
    LTarget.LoadFromIni('[app]' + #10 +
      'name=nextpas' + #10 +
      'message=${app.name}' + #10);
    LSource.LoadFromIni('[app]' + #10 +
      'name=replaced' + #10 +
      'message=${app.name}' + #10);

    CheckEqual('nextpas', LTarget.GetString('app.message'),
      'initial target interpolation');

    LTarget.ReplaceFrom(LSource);
    CheckEqual('replaced', LTarget.GetString('app.message'),
      'ReplaceFrom invalidates cached interpolation');
  finally
    LSource.Free;
    LTarget.Free;
  end;
end;

procedure TestInterpolationEnvFallback;
var
  LCfg: TConfig;
begin
  SetEnv('NEXTPAS_CFG_REGION', 'ap-east');
  try
    LCfg := TConfig.Create;
    try
      LCfg.LoadFromIni('region=${NEXTPAS_CFG_REGION}' + #10);
      CheckEqual('ap-east', LCfg.GetString('region'), 'env fallback placeholder');
    finally
      LCfg.Free;
    end;
  finally
    UnsetEnv('NEXTPAS_CFG_REGION');
  end;
end;

procedure TestInterpolationDefaultValue;
var
  LCfg: TConfig;
begin
  SetEnv('NEXTPAS_CFG_DEFAULT_REGION', 'ap-south');
  try
    LCfg := TConfig.Create;
    try
      LCfg.LoadFromIni('host=localhost' + #10);
      CheckEqual('http://localhost',
        LCfg.GetString('missing.url', 'http://${host}'),
        'default config interpolation');
      CheckEqual('ap-south',
        LCfg.GetString('missing.region', '${NEXTPAS_CFG_DEFAULT_REGION}'),
        'default env interpolation');
    finally
      LCfg.Free;
    end;
  finally
    UnsetEnv('NEXTPAS_CFG_DEFAULT_REGION');
  end;
end;

procedure TestInterpolationConfigWinsOverEnv;
var
  LCfg: TConfig;
begin
  SetEnv('NEXTPAS_CFG_NAME', 'env_name');
  try
    LCfg := TConfig.Create;
    try
      LCfg.LoadFromIni('NEXTPAS_CFG_NAME=config_name' + #10 +
        'display=${NEXTPAS_CFG_NAME}' + #10);
      CheckEqual('config_name', LCfg.GetString('display'),
        'config placeholder wins over env');
    finally
      LCfg.Free;
    end;
  finally
    UnsetEnv('NEXTPAS_CFG_NAME');
  end;
end;

procedure TestInterpolationEscapeAndUnresolved;
var
  LCfg: TConfig;
begin
  UnsetEnv('NEXTPAS_CFG_MISSING_INTERPOLATION');
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[server]' + #10 +
      'host=localhost' + #10 +
      '[values]' + #10 +
      'literal=$${server.host}' + #10 +
      'missing=${NEXTPAS_CFG_MISSING_INTERPOLATION}' + #10);
    CheckEqual('${server.host}', LCfg.GetString('values.literal'),
      'escaped placeholder');
    CheckEqual('${NEXTPAS_CFG_MISSING_INTERPOLATION}',
      LCfg.GetString('values.missing'), 'unresolved placeholder preserved');
  finally
    LCfg.Free;
  end;
end;

procedure TestInterpolationTypedGetters;
var
  LCfg: TConfig;
  LVal: Double;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[source]' + #10 +
      'port=8080' + #10 +
      'enabled=true' + #10 +
      'ratio=2.5' + #10 +
      '[derived]' + #10 +
      'port=${source.port}' + #10 +
      'enabled=${source.enabled}' + #10 +
      'ratio=${source.ratio}' + #10);
    CheckEqual(Int64(8080), LCfg.GetInt('derived.port'), 'interpolated int');
    CheckEqual(True, LCfg.GetBool('derived.enabled'), 'interpolated bool');
    LVal := LCfg.GetFloat('derived.ratio');
    Check((LVal > 2.4) and (LVal < 2.6), 'interpolated float');
  finally
    LCfg.Free;
  end;
end;

procedure TestInterpolationStringArray;
var
  LCfg: TConfig;
  LTags: TStringArray;
begin
  SetEnv('NEXTPAS_CFG_TAG', 'env_tag');
  try
    LCfg := TConfig.Create;
    try
      LCfg.LoadFromJson('{"tag_source":"blue","tags":["${tag_source}",' +
        '"$${tag_source}","${NEXTPAS_CFG_TAG}"]}');
      LTags := LCfg.GetStringArray('tags');
      CheckEqual(Int64(3), Int64(Length(LTags)), 'tag count');
      CheckEqual('blue', LTags[0], 'array config interpolation');
      CheckEqual('${tag_source}', LTags[1], 'array escaped interpolation');
      CheckEqual('env_tag', LTags[2], 'array env interpolation');
    finally
      LCfg.Free;
    end;
  finally
    UnsetEnv('NEXTPAS_CFG_TAG');
  end;
end;

procedure TestGetRawStringArrayPreservesPlaceholders;
var
  LCfg: TConfig;
  LTags: TStringArray;
begin
  SetEnv('NEXTPAS_CFG_RAW_TAG', 'env_tag');
  try
    LCfg := TConfig.Create;
    try
      LCfg.LoadFromJson('{"tag_source":"blue","tags":["${tag_source}",' +
        '"$${tag_source}","${NEXTPAS_CFG_RAW_TAG}"]}');
      LTags := LCfg.GetRawStringArray('tags');
      CheckEqual(Int64(3), Int64(Length(LTags)), 'raw tag count');
      CheckEqual('${tag_source}', LTags[0], 'raw placeholder');
      CheckEqual('$${tag_source}', LTags[1], 'raw escaped placeholder');
      CheckEqual('${NEXTPAS_CFG_RAW_TAG}', LTags[2], 'raw env placeholder');

      LTags := LCfg.GetStringArray('tags');
      CheckEqual('blue', LTags[0], 'interpolated placeholder');
      CheckEqual('${tag_source}', LTags[1], 'interpolated escaped placeholder');
      CheckEqual('env_tag', LTags[2], 'interpolated env placeholder');
    finally
      LCfg.Free;
    end;
  finally
    UnsetEnv('NEXTPAS_CFG_RAW_TAG');
  end;
end;

procedure TestInterpolationCycleRaises;
var
  LCfg: TConfig;
  LRaised: Boolean;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('a=${b}' + #10 + 'b=${a}' + #10 + 'self=${self}' + #10);

    LRaised := False;
    try
      LCfg.GetString('a');
    except
      on E: EConfigError do
        LRaised := True;
    end;
    CheckEqual(True, LRaised, 'cross-key cycle raises');

    LRaised := False;
    try
      LCfg.GetString('self');
    except
      on E: EConfigError do
        LRaised := True;
    end;
    CheckEqual(True, LRaised, 'self cycle raises');
  finally
    LCfg.Free;
  end;
end;

{ === Required Value Tests === }

procedure TestRequiredStringAndRequire;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[server]' + #10 +
      'host=localhost' + #10 +
      'port=8080' + #10 +
      '[service]' + #10 +
      'url=https://${server.host}:${server.port}' + #10);

    CheckEqual('https://localhost:8080', LCfg.GetStringRequired('service.url'),
      'required string interpolates');
    LCfg.Require(['server.host', 'server.port', 'service.url']);
  finally
    LCfg.Free;
  end;
end;

procedure TestRequiredMissingRaises;
var
  LCfg: TConfig;
  LRaised: Boolean;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[server]' + #10 + 'host=localhost' + #10);

    LRaised := False;
    try
      LCfg.GetStringRequired('server.port');
    except
      on E: EConfigError do
        LRaised := True;
    end;
    CheckEqual(True, LRaised, 'missing string required raises');

    LRaised := False;
    try
      LCfg.GetIntRequired('server.port');
    except
      on E: EConfigError do
        LRaised := True;
    end;
    CheckEqual(True, LRaised, 'missing int required raises');

    LRaised := False;
    try
      LCfg.Require(['server.host', 'server.port']);
    except
      on E: EConfigError do
        LRaised := True;
    end;
    CheckEqual(True, LRaised, 'Require raises for missing key');
  finally
    LCfg.Free;
  end;
end;

procedure TestRequiredEmptyRaises;
var
  LCfg: TConfig;
  LRaised: Boolean;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('empty=' + #10);

    LRaised := False;
    try
      LCfg.GetStringRequired('empty');
    except
      on E: EConfigError do
        LRaised := True;
    end;
    CheckEqual(True, LRaised, 'empty required string raises');

    LRaised := False;
    try
      LCfg.Require(['empty']);
    except
      on E: EConfigError do
        LRaised := True;
    end;
    CheckEqual(True, LRaised, 'Require raises for empty key');
  finally
    LCfg.Free;
  end;
end;

procedure TestRequiredTypedValues;
var
  LCfg: TConfig;
  LVal: Double;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[source]' + #10 +
      'port=8080' + #10 +
      'enabled=yes' + #10 +
      'ratio=2.5' + #10 +
      '[derived]' + #10 +
      'port=${source.port}' + #10 +
      'enabled=${source.enabled}' + #10 +
      'ratio=${source.ratio}' + #10);

    CheckEqual(Int64(8080), LCfg.GetIntRequired('derived.port'),
      'required int interpolates');
    CheckEqual(True, LCfg.GetBoolRequired('derived.enabled'),
      'required bool interpolates');
    LVal := LCfg.GetFloatRequired('derived.ratio');
    Check((LVal > 2.4) and (LVal < 2.6), 'required float interpolates');
  finally
    LCfg.Free;
  end;
end;

procedure TestRequiredTypedWhitespaceAndSign;
var
  LCfg: TConfig;
  LVal: Double;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('required.port', ' 8080 ');
    LCfg.SetString('required.ratio', ' -2.5 ');
    CheckEqual(Int64(8080), LCfg.GetIntRequired('required.port'),
      'required int keeps whitespace support');
    LVal := LCfg.GetFloatRequired('required.ratio');
    Check((LVal < -2.4) and (LVal > -2.6),
      'required float keeps whitespace support');
  finally
    LCfg.Free;
  end;
end;

procedure TestRequiredTypedInvalidRaises;
var
  LCfg: TConfig;
  LRaised: Boolean;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[bad]' + #10 +
      'port=abc' + #10 +
      'enabled=maybe' + #10 +
      'ratio=hello' + #10);

    LRaised := False;
    try
      LCfg.GetIntRequired('bad.port');
    except
      on E: EConfigError do
        LRaised := True;
    end;
    CheckEqual(True, LRaised, 'invalid required int raises');

    LRaised := False;
    try
      LCfg.GetBoolRequired('bad.enabled');
    except
      on E: EConfigError do
        LRaised := True;
    end;
    CheckEqual(True, LRaised, 'invalid required bool raises');

    LRaised := False;
    try
      LCfg.GetFloatRequired('bad.ratio');
    except
      on E: EConfigError do
        LRaised := True;
    end;
    CheckEqual(True, LRaised, 'invalid required float raises');
  finally
    LCfg.Free;
  end;
end;

procedure TestRequiredBoolWhitespaceAndCase;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[flags]' + #10 + 'enabled=  TrUe  ' + #10);
    CheckEqual(True, LCfg.GetBoolRequired('flags.enabled'),
      'required bool trims and ignores case');
  finally
    LCfg.Free;
  end;
end;

procedure TestRequiredUnresolvedPlaceholderRaises;
var
  LCfg: TConfig;
  LRaised: Boolean;
begin
  UnsetEnv('NEXTPAS_CFG_REQUIRED_SECRET');
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('secret=${NEXTPAS_CFG_REQUIRED_SECRET}' + #10);

    LRaised := False;
    try
      LCfg.GetStringRequired('secret');
    except
      on E: EConfigError do
        LRaised := True;
    end;
    CheckEqual(True, LRaised, 'unresolved required placeholder raises');

    LRaised := False;
    try
      LCfg.Require(['secret']);
    except
      on E: EConfigError do
        LRaised := True;
    end;
    CheckEqual(True, LRaised, 'Require raises for unresolved placeholder');
  finally
    LCfg.Free;
  end;
end;

procedure TestRequiredWhitespaceRaises;
var
  LCfg: TConfig;
  LRaised: Boolean;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('blank=   ' + #10);

    LRaised := False;
    try
      LCfg.GetStringRequired('blank');
    except
      on E: EConfigError do
        LRaised := True;
    end;
    CheckEqual(True, LRaised, 'whitespace required string raises');

    LRaised := False;
    try
      LCfg.Require(['blank']);
    except
      on E: EConfigError do
        LRaised := True;
    end;
    CheckEqual(True, LRaised, 'Require raises for whitespace key');
  finally
    LCfg.Free;
  end;
end;

procedure TestReadSurfaceRejectsEmptyKeys;
var
  LCfg: TConfig;
  LRaised: Boolean;
  LMessage: string;
begin
  LCfg := TConfig.Create;
  try
    LRaised := False;
    LMessage := '';
    try
      LCfg.Has('');
    except
      on E: EConfigError do
      begin
        LRaised := True;
        LMessage := E.Message;
      end;
    end;
    CheckEqual(True, LRaised, 'Has rejects empty key');
    CheckEqual('config key must not be empty', LMessage, 'Has empty key error');

    LRaised := False;
    LMessage := '';
    try
      LCfg.GetString('', 'fallback');
    except
      on E: EConfigError do
      begin
        LRaised := True;
        LMessage := E.Message;
      end;
    end;
    CheckEqual(True, LRaised, 'GetString rejects empty key');
    CheckEqual('config key must not be empty', LMessage, 'GetString empty key error');

    LRaised := False;
    LMessage := '';
    try
      LCfg.GetRawString('', 'fallback');
    except
      on E: EConfigError do
      begin
        LRaised := True;
        LMessage := E.Message;
      end;
    end;
    CheckEqual(True, LRaised, 'GetRawString rejects empty key');
    CheckEqual('config key must not be empty', LMessage, 'GetRawString empty key error');

    LRaised := False;
    LMessage := '';
    try
      LCfg.GetInt('', 42);
    except
      on E: EConfigError do
      begin
        LRaised := True;
        LMessage := E.Message;
      end;
    end;
    CheckEqual(True, LRaised, 'GetInt rejects empty key');
    CheckEqual('config key must not be empty', LMessage, 'GetInt empty key error');

    LRaised := False;
    LMessage := '';
    try
      LCfg.GetBool('', True);
    except
      on E: EConfigError do
      begin
        LRaised := True;
        LMessage := E.Message;
      end;
    end;
    CheckEqual(True, LRaised, 'GetBool rejects empty key');
    CheckEqual('config key must not be empty', LMessage, 'GetBool empty key error');

    LRaised := False;
    LMessage := '';
    try
      LCfg.GetFloat('', 1.5);
    except
      on E: EConfigError do
      begin
        LRaised := True;
        LMessage := E.Message;
      end;
    end;
    CheckEqual(True, LRaised, 'GetFloat rejects empty key');
    CheckEqual('config key must not be empty', LMessage, 'GetFloat empty key error');

    LRaised := False;
    LMessage := '';
    try
      LCfg.GetStringRequired('');
    except
      on E: EConfigError do
      begin
        LRaised := True;
        LMessage := E.Message;
      end;
    end;
    CheckEqual(True, LRaised, 'GetStringRequired rejects empty key');
    CheckEqual('config key must not be empty', LMessage, 'GetStringRequired empty key error');

    LRaised := False;
    LMessage := '';
    try
      LCfg.GetIntRequired('');
    except
      on E: EConfigError do
      begin
        LRaised := True;
        LMessage := E.Message;
      end;
    end;
    CheckEqual(True, LRaised, 'GetIntRequired rejects empty key');
    CheckEqual('config key must not be empty', LMessage, 'GetIntRequired empty key error');

    LRaised := False;
    LMessage := '';
    try
      LCfg.GetBoolRequired('');
    except
      on E: EConfigError do
      begin
        LRaised := True;
        LMessage := E.Message;
      end;
    end;
    CheckEqual(True, LRaised, 'GetBoolRequired rejects empty key');
    CheckEqual('config key must not be empty', LMessage, 'GetBoolRequired empty key error');

    LRaised := False;
    LMessage := '';
    try
      LCfg.GetFloatRequired('');
    except
      on E: EConfigError do
      begin
        LRaised := True;
        LMessage := E.Message;
      end;
    end;
    CheckEqual(True, LRaised, 'GetFloatRequired rejects empty key');
    CheckEqual('config key must not be empty', LMessage, 'GetFloatRequired empty key error');

    LRaised := False;
    LMessage := '';
    try
      LCfg.Require(['']);
    except
      on E: EConfigError do
      begin
        LRaised := True;
        LMessage := E.Message;
      end;
    end;
    CheckEqual(True, LRaised, 'Require rejects empty key');
    CheckEqual('config key must not be empty', LMessage, 'Require empty key error');
  finally
    LCfg.Free;
  end;
end;

{ === GetInt Tests === }

procedure TestGetIntBasic;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[server]' + #10 + 'port=9090' + #10 + 'timeout=30' + #10);
    CheckEqual(Int64(9090), LCfg.GetInt('server.port'), 'port');
    CheckEqual(Int64(30), LCfg.GetInt('server.timeout'), 'timeout');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetIntDefault;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    CheckEqual(Int64(42), LCfg.GetInt('missing', 42), 'default');
    CheckEqual(Int64(0), LCfg.GetInt('missing'), 'zero default');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetIntInvalid;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[x]' + #10 + 'bad=abc' + #10 + 'float=3.14' + #10);
    CheckEqual(Int64(-1), LCfg.GetInt('x.bad', -1), 'non-numeric');
    CheckEqual(Int64(99), LCfg.GetInt('x.float', 99), 'float as int');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetIntWhitespaceAndSign;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('num.spaced', ' 42 ');
    LCfg.SetString('num.plus', '+17');
    LCfg.SetString('num.neg', ' -5 ');
    CheckEqual(Int64(42), LCfg.GetInt('num.spaced'), 'spaced int');
    CheckEqual(Int64(17), LCfg.GetInt('num.plus'), 'plus int');
    CheckEqual(Int64(-5), LCfg.GetInt('num.neg'), 'negative int');
  finally
    LCfg.Free;
  end;
end;

{ === GetBool Tests === }

procedure TestGetBoolBasic;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[flags]' + #10 +
      'a=true' + #10 + 'b=false' + #10 +
      'c=1' + #10 + 'd=0' + #10 +
      'e=yes' + #10 + 'f=no' + #10 +
      'g=on' + #10 + 'h=off' + #10);
    CheckEqual(True, LCfg.GetBool('flags.a'), 'true');
    CheckEqual(False, LCfg.GetBool('flags.b'), 'false');
    CheckEqual(True, LCfg.GetBool('flags.c'), '1');
    CheckEqual(False, LCfg.GetBool('flags.d'), '0');
    CheckEqual(True, LCfg.GetBool('flags.e'), 'yes');
    CheckEqual(False, LCfg.GetBool('flags.f'), 'no');
    CheckEqual(True, LCfg.GetBool('flags.g'), 'on');
    CheckEqual(False, LCfg.GetBool('flags.h'), 'off');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetBoolDefault;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    CheckEqual(True, LCfg.GetBool('missing', True), 'default true');
    CheckEqual(False, LCfg.GetBool('missing', False), 'default false');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetBoolWhitespaceAndCase;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[flags]' + #10 +
      'spaced_true=  YeS  ' + #10 +
      'spaced_false=  Off  ' + #10);
    CheckEqual(True, LCfg.GetBool('flags.spaced_true'), 'trimmed mixed-case true');
    CheckEqual(False, LCfg.GetBool('flags.spaced_false', True), 'trimmed mixed-case false');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetBoolShortTokenWhitespaceAndCase;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[flags]' + #10 +
      'spaced_on=  On  ' + #10 +
      'spaced_no=  nO  ' + #10);
    CheckEqual(True, LCfg.GetBool('flags.spaced_on'), 'trimmed mixed-case on');
    CheckEqual(False, LCfg.GetBool('flags.spaced_no', True), 'trimmed mixed-case no');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetBoolInvalid;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[x]' + #10 + 'bad=maybe' + #10);
    CheckEqual(True, LCfg.GetBool('x.bad', True), 'invalid returns default');
  finally
    LCfg.Free;
  end;
end;

{ === GetFloat Tests === }

procedure TestGetFloatBasic;
var
  LCfg: TConfig;
  LVal: Double;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[math]' + #10 + 'pi=3.14159' + #10 + 'neg=-2.5' + #10);
    LVal := LCfg.GetFloat('math.pi');
    Check((LVal > 3.14) and (LVal < 3.15), 'pi');
    LVal := LCfg.GetFloat('math.neg');
    Check((LVal > -2.6) and (LVal < -2.4), 'neg');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetFloatDefault;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    Check(LCfg.GetFloat('missing', 1.5) > 1.4, 'default');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetFloatInvalid;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[x]' + #10 + 'bad=hello' + #10);
    Check(LCfg.GetFloat('x.bad', 7.7) > 7.6, 'invalid returns default');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetFloatWhitespaceAndSign;
var
  LCfg: TConfig;
  LVal: Double;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('num.spaced', ' 3.5 ');
    LCfg.SetString('num.plus', '+2.25');
    LCfg.SetString('num.neg', ' -0.5 ');

    LVal := LCfg.GetFloat('num.spaced');
    Check((LVal > 3.4) and (LVal < 3.6), 'spaced float');
    LVal := LCfg.GetFloat('num.plus');
    Check((LVal > 2.2) and (LVal < 2.3), 'plus float');
    LVal := LCfg.GetFloat('num.neg');
    Check((LVal < -0.4) and (LVal > -0.6), 'negative float');
  finally
    LCfg.Free;
  end;
end;

{ === SetDefault Tests === }

procedure TestSetDefault;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetDefault('key1', 'default_val');
    CheckEqual('default_val', LCfg.GetString('key1'), 'set default');
    { LoadFromIni should override }
    LCfg.LoadFromIni('[section]' + #10 + 'key1=override' + #10);
    { SetDefault should NOT override existing }
    LCfg.SetDefault('section.key1', 'ignored');
    CheckEqual('override', LCfg.GetString('section.key1'), 'not overridden');
  finally
    LCfg.Free;
  end;
end;

{ === LoadFromIni Tests === }

procedure TestLoadFromIniSections;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni(
      '[database]' + #10 +
      'host=db.example.com' + #10 +
      'port=5432' + #10 +
      '[cache]' + #10 +
      'ttl=300' + #10);
    CheckEqual('db.example.com', LCfg.GetString('database.host'), 'db host');
    CheckEqual(Int64(5432), LCfg.GetInt('database.port'), 'db port');
    CheckEqual(Int64(300), LCfg.GetInt('cache.ttl'), 'cache ttl');
  finally
    LCfg.Free;
  end;
end;

procedure TestLoadFromIniGlobalKeys;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('name=myapp' + #10 + 'version=1.0' + #10);
    CheckEqual('myapp', LCfg.GetString('name'), 'global name');
    CheckEqual('1.0', LCfg.GetString('version'), 'global version');
  finally
    LCfg.Free;
  end;
end;

{ === LoadFromJson Tests === }

procedure TestLoadFromJsonBasic;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"host":"localhost","port":3000,"debug":true}');
    CheckEqual('localhost', LCfg.GetString('host'), 'json host');
    CheckEqual(Int64(3000), LCfg.GetInt('port'), 'json port');
    CheckEqual(True, LCfg.GetBool('debug'), 'json debug');
  finally
    LCfg.Free;
  end;
end;

procedure TestLoadFromJsonTypes;
var
  LCfg: TConfig;
  LVal: Double;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"str":"hello","num":42,"flt":2.718,"flag":false,"nil_val":null}');
    CheckEqual('hello', LCfg.GetString('str'), 'string');
    CheckEqual(Int64(42), LCfg.GetInt('num'), 'int');
    LVal := LCfg.GetFloat('flt');
    Check((LVal > 2.71) and (LVal < 2.72), 'float');
    CheckEqual(False, LCfg.GetBool('flag'), 'bool');
    CheckEqual('', LCfg.GetString('nil_val'), 'null');
  finally
    LCfg.Free;
  end;
end;

procedure TestTryLoadFromIniValid;
var
  LCfg: TConfig;
  LError: string;
begin
  LCfg := TConfig.Create;
  try
    CheckEqual(True, LCfg.TryLoadFromIni('[app]' + #10 + 'name=nextpas' + #10, LError),
      'TryLoadFromIni valid');
    CheckEqual('', LError, 'valid ini clears error');
    CheckEqual('nextpas', LCfg.GetString('app.name'), 'valid ini loads key');
  finally
    LCfg.Free;
  end;
end;

procedure TestTryLoadFromIniInvalidReportsPosition;
var
  LCfg: TConfig;
  LError: string;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('keep', 'value');
    CheckEqual(False, LCfg.TryLoadFromIni('root=1' + #13#10 + '  [broken' + #10, LError),
      'TryLoadFromIni invalid section');
    CheckEqual('INI parse error at line 2, column 3 (offset 10): ' +
      'Line 2: missing closing ] in section header', LError,
      'TryLoadFromIni returns positioned parse error');
    CheckEqual('value', LCfg.GetString('keep'), 'TryLoadFromIni preserves existing');
  finally
    LCfg.Free;
  end;
end;

procedure TestTryLoadFromIniRejectsFlattenedKeyCollision;
var
  LCfg: TConfig;
  LError: string;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('a.b', 'old');
    CheckEqual(False, LCfg.TryLoadFromIni(
      'shadow=new' + #10 +
      'a.b=literal' + #10 +
      '[a]' + #10 +
      'b=nested' + #10, LError), 'TryLoadFromIni rejects flattened collision');
    Check(Pos('INI', LError) > 0, 'collision error mentions INI');
    Check(Pos('a.b', LError) > 0, 'collision error mentions flattened key');
    CheckEqual(False, LCfg.Has('shadow'), 'rejected ini does not write earlier keys');
    CheckEqual('old', LCfg.GetString('a.b'),
      'rejected ini does not overwrite existing key');

    CheckEqual(True, LCfg.TryLoadFromIni('db=literal' + #10 +
      '[db]' + #10 +
      'host=localhost' + #10, LError),
      'TryLoadFromIni allows prefix coexistence');
    CheckEqual('', LError, 'prefix coexistence clears error');
    CheckEqual('literal', LCfg.GetString('db'), 'prefix scalar remains available');
    CheckEqual('localhost', LCfg.GetString('db.host'),
      'prefixed nested key remains available');
  finally
    LCfg.Free;
  end;
end;

procedure TestTryLoadFromJsonValid;
var
  LCfg: TConfig;
  LError: string;
begin
  LCfg := TConfig.Create;
  try
    CheckEqual(True, LCfg.TryLoadFromJson('{"host":"localhost","port":8080}', LError),
      'TryLoadFromJson valid');
    CheckEqual('', LError, 'valid json clears error');
    CheckEqual('localhost', LCfg.GetString('host'), 'valid json loads host');
  finally
    LCfg.Free;
  end;
end;

procedure TestTryLoadFromJsonInvalid;
var
  LCfg: TConfig;
  LError: string;
begin
  LCfg := TConfig.Create;
  try
    CheckEqual(False, LCfg.TryLoadFromJson('{not valid json', LError),
      'TryLoadFromJson invalid');
    Check(LError <> '', 'invalid json returns error');
  finally
    LCfg.Free;
  end;
end;

procedure TestTryLoadFromJsonInvalidReportsPositionCRLF;
var
  LCfg: TConfig;
  LError: string;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('keep', 'value');
    CheckEqual(False,
      LCfg.TryLoadFromJson('{"ok":true}' + #13#10 + 'oops', LError),
      'TryLoadFromJson invalid trailing content after CRLF');
    CheckEqual('JSON parse error at line 2, column 1 (offset 13): trailing content',
      LError, 'TryLoadFromJson returns CRLF-aware positioned parse error');
    CheckEqual('value', LCfg.GetString('keep'),
      'TryLoadFromJson CRLF failure preserves existing');
  finally
    LCfg.Free;
  end;
end;

procedure TestTryLoadFromYamlAndTomlInvalidReportOffset;
var
  LCfg: TConfig;
  LError: string;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('keep', 'value');

    CheckEqual(False, LCfg.TryLoadYaml('{key: value', LError),
      'TryLoadYaml invalid');
    Check(Pos('YAML parse error at line 1, column 12 (offset 11)', LError) > 0,
      'TryLoadYaml returns positioned parse error with offset');
    CheckEqual('value', LCfg.GetString('keep'), 'TryLoadYaml preserves existing');

    CheckEqual(False, LCfg.TryLoadToml('key = ', LError),
      'TryLoadToml invalid');
    Check(Pos('TOML parse error at line 1, column 7 (offset 6)', LError) > 0,
      'TryLoadToml returns positioned parse error with offset');
    CheckEqual('value', LCfg.GetString('keep'), 'TryLoadToml preserves existing');
  finally
    LCfg.Free;
  end;
end;

procedure TestTryLoadShortVariantsInvalid;
var
  LCfg: TConfig;
  LError: string;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"keep":"value"}');

    CheckEqual(False, LCfg.TryLoadJson('{not valid json', LError),
      'TryLoadJson invalid');
    Check(LError <> '', 'TryLoadJson returns error');
    CheckEqual('value', LCfg.GetString('keep'), 'TryLoadJson preserves existing');

    CheckEqual(False, LCfg.TryLoadYaml('{a: *missing}', LError),
      'TryLoadYaml invalid');
    Check(LError <> '', 'TryLoadYaml returns error');
    CheckEqual('value', LCfg.GetString('keep'), 'TryLoadYaml preserves existing');

    CheckEqual(False, LCfg.TryLoadToml('key = ', LError),
      'TryLoadToml invalid');
    Check(LError <> '', 'TryLoadToml returns error');
    CheckEqual('value', LCfg.GetString('keep'), 'TryLoadToml preserves existing');
  finally
    LCfg.Free;
  end;
end;

procedure TestTryLoadShortVariantsValid;
var
  LCfg: TConfig;
  LError: string;
begin
  LCfg := TConfig.Create;
  try
    CheckEqual(True, LCfg.TryLoadJson('{"json":"ok"}', LError), 'TryLoadJson valid');
    CheckEqual('', LError, 'TryLoadJson clears error');
    CheckEqual('ok', LCfg.GetString('json'), 'TryLoadJson loads key');

    CheckEqual(True, LCfg.TryLoadYaml('yaml: ok' + #10, LError), 'TryLoadYaml valid');
    CheckEqual('', LError, 'TryLoadYaml clears error');
    CheckEqual('ok', LCfg.GetString('yaml'), 'TryLoadYaml loads key');

    CheckEqual(True, LCfg.TryLoadToml('toml = "ok"' + #10, LError), 'TryLoadToml valid');
    CheckEqual('', LError, 'TryLoadToml clears error');
    CheckEqual('ok', LCfg.GetString('toml'), 'TryLoadToml loads key');
  finally
    LCfg.Free;
  end;
end;

{ === LoadFromEnv Tests === }

procedure TestLoadFromEnvBasic;
var
  LCfg: TConfig;
begin
  SetEnv('TESTCFG_HOST', 'envhost');
  SetEnv('TESTCFG_PORT', '4000');
  try
    LCfg := TConfig.Create;
    try
      LCfg.LoadFromEnv('TESTCFG_');
      CheckEqual('envhost', LCfg.GetString('host'), 'env host');
      CheckEqual(Int64(4000), LCfg.GetInt('port'), 'env port');
    finally
      LCfg.Free;
    end;
  finally
    UnsetEnv('TESTCFG_HOST');
    UnsetEnv('TESTCFG_PORT');
  end;
end;

procedure TestLoadFromEnvOverride;
var
  LCfg: TConfig;
begin
  SetEnv('MYAPP_DB_HOST', 'envdb');
  try
    LCfg := TConfig.Create;
    try
      LCfg.LoadFromIni('[x]' + #10 + 'db_host=inidb' + #10);
      { Env loaded after INI overrides }
      LCfg.LoadFromEnv('MYAPP_');
      CheckEqual('envdb', LCfg.GetString('db_host'), 'env overrides ini');
    finally
      LCfg.Free;
    end;
  finally
    UnsetEnv('MYAPP_DB_HOST');
  end;
end;

procedure TestLoadFromEnvRejectsEmptyPrefix;
var
  LCfg: TConfig;
  LRaised: Boolean;
  LMessage: string;
begin
  LCfg := TConfig.Create;
  try
    LRaised := False;
    LMessage := '';
    try
      LCfg.LoadFromEnv('');
    except
      on E: EConfigError do
      begin
        LRaised := True;
        LMessage := E.Message;
      end;
    end;
    CheckEqual(True, LRaised, 'LoadFromEnv rejects empty prefix');
    CheckEqual('config env prefix must not be empty', LMessage,
      'LoadFromEnv empty prefix error');
  finally
    LCfg.Free;
  end;
end;

{ === Has / GetKeys Tests === }

procedure TestHas;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[s]' + #10 + 'key=val' + #10);
    CheckEqual(True, LCfg.Has('s.key'), 'exists');
    CheckEqual(False, LCfg.Has('s.missing'), 'not exists');
  finally
    LCfg.Free;
  end;
end;

procedure TestHasCaseInsensitive;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[S]' + #10 + 'Key=val' + #10);
    CheckEqual(True, LCfg.Has('s.key'), 'lower lookup');
    CheckEqual(True, LCfg.Has('S.KEY'), 'upper lookup');
    CheckEqual(False, LCfg.Has('S.MISSING'), 'upper missing');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetKeys;
var
  LCfg: TConfig;
  LKeys: TStringArray;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"a":"1","b":"2","c":"3"}');
    LKeys := LCfg.GetKeys;
    CheckEqual(Int64(3), Int64(Length(LKeys)), 'key count');
  finally
    LCfg.Free;
  end;
end;

{ === Empty Config Tests === }

procedure TestEmptyConfig;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    CheckEqual(Int64(0), Int64(LCfg.Count), 'empty count');
    CheckEqual(False, LCfg.Has('anything'), 'empty has');
    CheckEqual('def', LCfg.GetString('x', 'def'), 'empty get');
  finally
    LCfg.Free;
  end;
end;

{ === Override Priority Tests === }

procedure TestOverridePriority;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    { SetDefault first }
    LCfg.SetDefault('server.host', 'default_host');
    { INI overrides default }
    LCfg.LoadFromIni('[server]' + #10 + 'host=ini_host' + #10);
    CheckEqual('ini_host', LCfg.GetString('server.host'), 'ini over default');
    { JSON overrides INI }
    LCfg.LoadFromJson('{"server.host":"json_host"}');
    CheckEqual('json_host', LCfg.GetString('server.host'), 'json over ini');
  finally
    LCfg.Free;
  end;
end;

procedure TestOverrideEnvHighest;
var
  LCfg: TConfig;
begin
  SetEnv('APP_NAME', 'env_app');
  try
    LCfg := TConfig.Create;
    try
      LCfg.SetDefault('name', 'default_app');
      LCfg.LoadFromIni('name=ini_app' + #10);
      LCfg.LoadFromJson('{"name":"json_app"}');
      LCfg.LoadFromEnv('APP_');
      CheckEqual('env_app', LCfg.GetString('name'), 'env highest priority');
    finally
      LCfg.Free;
    end;
  finally
    UnsetEnv('APP_NAME');
  end;
end;

{ === Count Tests === }

procedure TestCount;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    CheckEqual(Int64(0), Int64(LCfg.Count), 'initial');
    LCfg.LoadFromJson('{"a":"1","b":"2"}');
    CheckEqual(Int64(2), Int64(LCfg.Count), 'after json');
    LCfg.LoadFromIni('[s]' + #10 + 'c=3' + #10);
    CheckEqual(Int64(3), Int64(LCfg.Count), 'after ini');
  finally
    LCfg.Free;
  end;
end;


{ === Additional GetFloat/Has/GetKeys/Count Boundary Tests === }

procedure TestGetFloatZero;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[x]' + #10 + 'val=0.0' + #10);
    Check(LCfg.GetFloat('x.val') < 0.001, 'zero float');
    Check(LCfg.GetFloat('x.val') > -0.001, 'zero float neg');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetFloatNegative;
var
  LCfg: TConfig;
  LVal: Double;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[x]' + #10 + 'val=-99.5' + #10);
    LVal := LCfg.GetFloat('x.val');
    Check((LVal > -99.6) and (LVal < -99.4), 'negative float');
  finally
    LCfg.Free;
  end;
end;

procedure TestHasAfterMultipleLoads;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[a]' + #10 + 'x=1' + #10);
    LCfg.LoadFromJson('{"b.y":"2"}');
    CheckEqual(True, LCfg.Has('a.x'), 'has ini key');
    CheckEqual(True, LCfg.Has('b.y'), 'has json key');
    CheckEqual(False, LCfg.Has('c.z'), 'missing key');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetKeysOrder;
var
  LCfg: TConfig;
  LKeys: TStringArray;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[s]' + #10 + 'alpha=1' + #10 + 'beta=2' + #10 + 'gamma=3' + #10);
    LKeys := LCfg.GetKeys;
    CheckEqual(Int64(3), Int64(Length(LKeys)), 'key count');
    { Keys should contain all three }
    Check((LKeys[0] = 's.alpha') or (LKeys[1] = 's.alpha') or (LKeys[2] = 's.alpha'), 'has alpha');
    Check((LKeys[0] = 's.beta') or (LKeys[1] = 's.beta') or (LKeys[2] = 's.beta'), 'has beta');
    Check((LKeys[0] = 's.gamma') or (LKeys[1] = 's.gamma') or (LKeys[2] = 's.gamma'), 'has gamma');
  finally
    LCfg.Free;
  end;
end;

procedure TestCountAfterOverride;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"k1":"a","k2":"b"}');
    CheckEqual(Int64(2), Int64(LCfg.Count), 'initial 2');
    { Override existing key should not increase count }
    LCfg.LoadFromJson('{"k1":"override"}');
    CheckEqual(Int64(2), Int64(LCfg.Count), 'override no increase');
    { Add new key }
    LCfg.LoadFromJson('{"k3":"c"}');
    CheckEqual(Int64(3), Int64(LCfg.Count), 'new key increases');
  finally
    LCfg.Free;
  end;
end;

{ === LoadFromYaml Tests === }

procedure TestLoadFromYamlBasic;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromYaml('name: Alice' + #10 + 'port: 8080' + #10 + 'debug: true' + #10);
    CheckEqual('Alice', LCfg.GetString('name'), 'yaml name');
    CheckEqual(Int64(8080), LCfg.GetInt('port'), 'yaml port');
    CheckEqual(True, LCfg.GetBool('debug'), 'yaml debug');
  finally
    LCfg.Free;
  end;
end;

{ === LoadFromToml Tests === }

procedure TestLoadFromTomlSection;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromToml('[server]' + #10 + 'host = "localhost"' + #10 + 'port = 8080' + #10);
    CheckEqual('localhost', LCfg.GetString('server.host'), 'toml host');
    CheckEqual(Int64(8080), LCfg.GetInt('server.port'), 'toml port');
  finally
    LCfg.Free;
  end;
end;

{ === Multi-source Override Tests === }

procedure TestMultiSourceOverride;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    { YAML first }
    LCfg.LoadFromYaml('host: yaml_host' + #10 + 'port: 3000' + #10);
    CheckEqual('yaml_host', LCfg.GetString('host'), 'yaml loaded');
    { TOML overrides }
    LCfg.LoadFromToml('host = "toml_host"' + #10);
    CheckEqual('toml_host', LCfg.GetString('host'), 'toml overrides yaml');
    { JSON overrides all }
    LCfg.LoadFromJson('{"host":"json_host"}');
    CheckEqual('json_host', LCfg.GetString('host'), 'json overrides toml');
  finally
    LCfg.Free;
  end;
end;

procedure TestReplaceFrom;
var
  LTarget: TConfig;
  LSource: TConfig;
  LTags: TStringArray;
begin
  LTarget := TConfig.Create;
  LSource := TConfig.Create;
  try
    LTarget.LoadFromIni('[server]' + #10 + 'host=old' + #10 + 'port=1000' + #10);
    LTarget.SetStringArray('tags', ['stale']);
    LTags := LTarget.GetStringArray('tags');
    CheckEqual(Int64(1), Int64(Length(LTags)), 'pre-replace cached array count');
    CheckEqual('stale', LTags[0], 'pre-replace cached array item');
    LSource.LoadFromIni('[server]' + #10 + 'host=new' + #10 + 'debug=true' + #10);
    LSource.SetString('Server.Name', 'nextpas');
    LSource.SetStringArray('Tags', ['alpha', 'beta']);

    LTarget.ReplaceFrom(LSource);

    CheckEqual('new', LTarget.GetString('server.host'), 'replaced value');
    CheckEqual('nextpas', LTarget.GetString('SERVER.NAME'),
      'mixed-case key remains readable after replace');
    CheckEqual(False, LTarget.Has('server.port'), 'old key removed');
    CheckEqual(True, LTarget.GetBool('server.debug'), 'new key copied');
    LTags := LTarget.GetStringArray('tags');
    CheckEqual(Int64(2), Int64(Length(LTags)), 'replaced array count');
    CheckEqual('alpha', LTags[0], 'replaced array item 0');
    CheckEqual('beta', LTags[1], 'replaced array item 1');
    LTags := LTarget.GetRawStringArray('tags');
    CheckEqual(Int64(2), Int64(Length(LTags)), 'replaced raw array count');
    CheckEqual('alpha', LTags[0], 'replaced raw array item 0');
    CheckEqual('beta', LTags[1], 'replaced raw array item 1');
    CheckEqual(Int64(5), Int64(LTarget.Count), 'replacement count');
  finally
    LSource.Free;
    LTarget.Free;
  end;
end;

procedure TestLoadFromFileBasic;
var
  LCfg: TConfig;
  LPath: string;
begin
  LPath := '/tmp/test_nextpas_config_load_from_file.json';
  Remove(LPath);
  WriteFileText(LPath, '{"server":{"host":"file-host","port":8080},"debug":true}');
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromFile(LPath, cfJson);
    CheckEqual('file-host', LCfg.GetString('server.host'), 'file host');
    CheckEqual(Int64(8080), LCfg.GetInt('server.port'), 'file port');
    CheckEqual(True, LCfg.GetBool('debug'), 'file bool');
  finally
    LCfg.Free;
    Remove(LPath);
  end;
end;

procedure TestLoadFromFileRejectsEmptyPath;
var
  LCfg: TConfig;
  LError: string;
  LRaised: Boolean;
  LMessage: string;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('keep=value' + #10);

    LRaised := False;
    LMessage := '';
    try
      LCfg.LoadFromFile('', cfJson);
    except
      on E: EConfigError do
      begin
        LRaised := True;
        LMessage := E.Message;
      end;
    end;
    CheckEqual(True, LRaised, 'LoadFromFile rejects empty file path');
    CheckEqual('config file path must not be empty', LMessage,
      'LoadFromFile empty path error message');
    CheckEqual('value', LCfg.GetString('keep'),
      'LoadFromFile empty path preserves existing value');

    LError := 'stale';
    CheckEqual(False, LCfg.TryLoadFromFile('', cfJson, LError),
      'TryLoadFromFile rejects empty file path');
    CheckEqual('config file path must not be empty', LError,
      'TryLoadFromFile empty path error message');
    CheckEqual('value', LCfg.GetString('keep'),
      'TryLoadFromFile empty path preserves existing value');
  finally
    LCfg.Free;
  end;
end;

procedure TestTryLoadFromFileSuccessAndErrorsPreserveExisting;
var
  LCfg: TConfig;
  LError: string;
  LBadJsonPath: string;
  LValidPath: string;
  LMissingPath: string;
  LBadPath: string;
  LBadIniPath: string;
begin
  LBadJsonPath := '/tmp/test_nextpas_config_try_load_bad.json';
  LValidPath := '/tmp/test_nextpas_config_try_load_valid.toml';
  LMissingPath := '/tmp/test_nextpas_config_try_load_missing.toml';
  LBadPath := '/tmp/test_nextpas_config_try_load_bad.toml';
  LBadIniPath := '/tmp/test_nextpas_config_try_load_bad.ini';
  Remove(LBadJsonPath);
  Remove(LValidPath);
  Remove(LMissingPath);
  Remove(LBadPath);
  Remove(LBadIniPath);
  WriteFileText(LBadJsonPath, '{"ok":true}' + #13#10 + 'oops');
  WriteFileText(LValidPath, '[server]' + #10 + 'host = "valid-host"' + #10);
  WriteFileText(LBadPath, 'server = ');
  WriteFileText(LBadIniPath, 'root=1' + #13#10 + '  [broken' + #10);
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('keep=value' + #10);

    LError := 'stale';
    CheckEqual(True, LCfg.TryLoadFromFile(LValidPath, cfToml, LError),
      'valid file returns true');
    CheckEqual('', LError, 'valid file clears error');
    CheckEqual('valid-host', LCfg.GetString('server.host'), 'valid file loads host');

    LError := 'stale';
    CheckEqual(False, LCfg.TryLoadFromFile(LMissingPath, cfToml, LError),
      'missing file returns false');
    Check(Pos(LMissingPath, LError) > 0, 'missing file path included');
    CheckEqual('value', LCfg.GetString('keep'), 'missing file preserves keep');
    CheckEqual('valid-host', LCfg.GetString('server.host'),
      'missing file preserves loaded host');

    LError := '';
    CheckEqual(False, LCfg.TryLoadFromFile(LBadJsonPath, cfJson, LError),
      'bad json file returns false');
    CheckEqual('Config file load error: ' + LBadJsonPath +
      ': JSON parse error at line 2, column 1 (offset 13): trailing content',
      LError, 'bad json file reports path and CRLF-aware position');
    CheckEqual('value', LCfg.GetString('keep'), 'bad json file preserves keep');
    CheckEqual('valid-host', LCfg.GetString('server.host'),
      'bad json file preserves loaded host');

    LError := '';
    CheckEqual(False, LCfg.TryLoadFromFile(LBadPath, cfToml, LError),
      'bad file returns false');
    Check(Pos(LBadPath, LError) > 0, 'bad file path included');
    CheckEqual('value', LCfg.GetString('keep'), 'bad file preserves keep');
    CheckEqual('valid-host', LCfg.GetString('server.host'),
      'bad file preserves loaded host');

    LError := '';
    CheckEqual(False, LCfg.TryLoadFromFile(LBadIniPath, cfIni, LError),
      'bad ini file returns false');
    CheckEqual('Config file load error: ' + LBadIniPath +
      ': INI parse error at line 2, column 3 (offset 10): ' +
      'Line 2: missing closing ] in section header', LError,
      'bad ini file reports path and position');
    CheckEqual('value', LCfg.GetString('keep'), 'bad ini file preserves keep');
    CheckEqual('valid-host', LCfg.GetString('server.host'),
      'bad ini file preserves loaded host');
  finally
    LCfg.Free;
    Remove(LBadJsonPath);
    Remove(LValidPath);
    Remove(LBadPath);
    Remove(LBadIniPath);
  end;
end;

{ === Hot Reload Tests === }

procedure TestConfigWatcherHotReloadIni;
var
  LCfg: TConfig;
  LWatcher: TConfigWatcher;
  LProbe: TConfigReloadProbe;
  LPath: string;
  LReloaded: Boolean;
  LAttempt: Integer;
begin
  LPath := '/tmp/test_hotreload_nextpas_config.ini';
  Remove(LPath);
  WriteFileText(LPath, '[server]' + #10 + 'host=initial' + #10 + 'port=1000' + #10);
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni(ReadFileText(LPath));
    LProbe := TConfigReloadProbe.Create;
    LWatcher := TConfigWatcher.Create(LCfg, LPath, cfIni);
    try
      LWatcher.OnReload := @LProbe.MarkReloaded;

      CheckEqual(False, LWatcher.CheckReload, 'unchanged file should not reload');

      LReloaded := False;
      for LAttempt := 0 to 20 do
      begin
        TSleep.ForDuration(TDuration.FromMilliseconds(20));
        WriteFileText(LPath, '[server]' + #10 + 'host=updated' + #10 +
          'port=2000' + #10 + 'extra=changed-size' + #10);
        LReloaded := LWatcher.CheckReload;
        if LReloaded then
          Break;
      end;

      CheckEqual(True, LReloaded, 'modified file should reload');
      CheckEqual('updated', LCfg.GetString('server.host'), 'reloaded host');
      CheckEqual(Int64(2000), LCfg.GetInt('server.port'), 'reloaded port');
      CheckEqual(True, LProbe.Reloaded, 'reload callback');
      CheckEqual(False, LWatcher.CheckReload, 'stable file should not reload twice');
    finally
      LWatcher.Free;
      LProbe.Free;
    end;
  finally
    LCfg.Free;
    Remove(LPath);
  end;
end;

function ConfigWatcherSuccessFormatName(AFormat: TConfigFormat): string;
begin
  case AFormat of
    cfJson: Result := 'json';
    cfYaml: Result := 'yaml';
    cfToml: Result := 'toml';
  else
    Result := 'ini';
  end;
end;

function ConfigWatcherSuccessPath(AFormat: TConfigFormat): string;
var
  LFile: IFile;
  LName: string;
  LSeedPath: string;
begin
  LName := ConfigWatcherSuccessFormatName(AFormat);
  LFile := TempFile('', 'test_hotreload_nextpas_config_success_' + LName);
  LSeedPath := LFile.Name;
  LFile.Close;
  Result := LSeedPath + '.' + LName;
  Remove(Result);
  if not Rename(LSeedPath, Result) then
  begin
    Remove(LSeedPath);
    Result := LSeedPath;
  end;
end;

function ConfigWatcherSuccessInitialContent(AFormat: TConfigFormat): string;
var
  LName: string;
begin
  LName := ConfigWatcherSuccessFormatName(AFormat);
  case AFormat of
    cfJson:
      Result := '{"server":{"host":"initial-' + LName + '","port":1000},' +
        '"stale":{"value":"old-' + LName + '"}}';
    cfYaml:
      Result := 'server:' + #10 +
        '  host: initial-' + LName + #10 +
        '  port: 1000' + #10 +
        'stale:' + #10 +
        '  value: old-' + LName + #10;
    cfToml:
      Result := '[server]' + #10 +
        'host = "initial-' + LName + '"' + #10 +
        'port = 1000' + #10 +
        '[stale]' + #10 +
        'value = "old-' + LName + '"' + #10;
  else
    Result := '';
  end;
end;

function ConfigWatcherSuccessUpdatedContent(AFormat: TConfigFormat): string;
var
  LName: string;
begin
  LName := ConfigWatcherSuccessFormatName(AFormat);
  case AFormat of
    cfJson:
      Result := '{"server":{"host":"updated-' + LName + '","port":2000},' +
        '"feature":{"enabled":true},"padding":"changed-size-' + LName + '"}';
    cfYaml:
      Result := 'server:' + #10 +
        '  host: updated-' + LName + #10 +
        '  port: 2000' + #10 +
        'feature:' + #10 +
        '  enabled: true' + #10 +
        'padding: changed-size-' + LName + #10;
    cfToml:
      Result := '[server]' + #10 +
        'host = "updated-' + LName + '"' + #10 +
        'port = 2000' + #10 +
        '[feature]' + #10 +
        'enabled = true' + #10 +
        'padding = "changed-size-' + LName + '"' + #10;
  else
    Result := '';
  end;
end;

function PollConfigWatcherReload(AWatcher: TConfigWatcher; const APath: string;
  const AContent: string): Boolean;
var
  LAttempt: Integer;
begin
  WriteFileText(APath, AContent);
  Result := False;
  for LAttempt := 0 to 20 do
  begin
    Result := AWatcher.CheckReload;
    if Result then
      Break;
    TSleep.ForDuration(TDuration.FromMilliseconds(20));
  end;
end;

procedure AssertConfigWatcherHotReloadSuccess(AFormat: TConfigFormat);
var
  LCfg: TConfig;
  LWatcher: TConfigWatcher;
  LProbe: TConfigReloadProbe;
  LPath: string;
  LName: string;
  LInitialContent: string;
  LReloaded: Boolean;
  LUpdatedContent: string;
begin
  LName := ConfigWatcherSuccessFormatName(AFormat);
  LPath := ConfigWatcherSuccessPath(AFormat);
  LInitialContent := ConfigWatcherSuccessInitialContent(AFormat);
  LUpdatedContent := ConfigWatcherSuccessUpdatedContent(AFormat);
  Check(Length(LInitialContent) <> Length(LUpdatedContent),
    LName + ' success fixture must change file size');
  WriteFileText(LPath, LInitialContent);
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromFile(LPath, AFormat);
    CheckEqual('initial-' + LName, LCfg.GetString('server.host'),
      LName + ' initial host');
    CheckEqual(Int64(1000), LCfg.GetInt('server.port'),
      LName + ' initial port');
    CheckEqual(True, LCfg.Has('stale.value'), LName + ' initial stale key');

    LProbe := TConfigReloadProbe.Create;
    LWatcher := TConfigWatcher.Create(LCfg, LPath, AFormat);
    try
      LWatcher.OnReload := @LProbe.MarkReloaded;

      CheckEqual(False, LWatcher.CheckReload,
        LName + ' unchanged file should not reload');
      CheckEqual(Int64(0), Int64(LProbe.CallCount),
        LName + ' unchanged file does not fire callback');

      LReloaded := PollConfigWatcherReload(LWatcher, LPath, LUpdatedContent);

      CheckEqual(True, LReloaded, LName + ' modified file should reload');
      CheckEqual('updated-' + LName, LCfg.GetString('server.host'),
        LName + ' reloaded host');
      CheckEqual(Int64(2000), LCfg.GetInt('server.port'),
        LName + ' reloaded port');
      CheckEqual(True, LCfg.GetBool('feature.enabled'),
        LName + ' reloaded feature');
      CheckEqual(False, LCfg.Has('stale.value'),
        LName + ' stale key removed by ReplaceFrom');
      CheckEqual(Int64(4), Int64(LCfg.Count),
        LName + ' live table replaced');

      CheckEqual(True, LProbe.Reloaded, LName + ' reload callback fired');
      CheckEqual(Int64(1), Int64(LProbe.CallCount),
        LName + ' reload callback fires once');
      CheckEqual(True, LProbe.LastSender = LCfg,
        LName + ' reload callback receives live config');
      CheckEqual('updated-' + LName, LProbe.ObservedHost,
        LName + ' callback observes replaced host');
      CheckEqual(Int64(2000), LProbe.ObservedPort,
        LName + ' callback observes replaced port');
      CheckEqual(False, LProbe.ObservedHasStale,
        LName + ' callback observes stale key removed');
      CheckEqual(True, LProbe.ObservedHasFeatureEnabled,
        LName + ' callback observes feature key');
      CheckEqual(True, LProbe.ObservedFeatureEnabled,
        LName + ' callback observes feature value');

      CheckEqual(False, LWatcher.CheckReload,
        LName + ' stable file should not reload twice');
      CheckEqual(Int64(1), Int64(LProbe.CallCount),
        LName + ' stable file does not fire another callback');
    finally
      LWatcher.Free;
      LProbe.Free;
    end;
  finally
    LCfg.Free;
    Remove(LPath);
  end;
end;

procedure TestConfigWatcherHotReloadJson;
begin
  AssertConfigWatcherHotReloadSuccess(cfJson);
end;

procedure TestConfigWatcherHotReloadYaml;
begin
  AssertConfigWatcherHotReloadSuccess(cfYaml);
end;

procedure TestConfigWatcherHotReloadToml;
begin
  AssertConfigWatcherHotReloadSuccess(cfToml);
end;

procedure TestConfigWatcherBadJsonRaisesAndPreservesOldConfig;
var
  LCfg: TConfig;
  LWatcher: TConfigWatcher;
  LPath: string;
  LRaised: Boolean;
begin
  LPath := '/tmp/test_hotreload_nextpas_config_bad_json.json';
  Remove(LPath);
  WriteFileText(LPath, '{"server":{"host":"initial","port":1000}}');
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson(ReadFileText(LPath));
    LWatcher := TConfigWatcher.Create(LCfg, LPath, cfJson);
    try
      TSleep.ForDuration(TDuration.FromMilliseconds(20));
      WriteFileText(LPath, '{"server":{"host":');

      LRaised := False;
      try
        LWatcher.CheckReload;
      except
        on E: EConfigError do
          LRaised := True;
      end;

      CheckEqual(True, LRaised, 'bad watcher reload raises EConfigError');
      CheckEqual('initial', LCfg.GetString('server.host'), 'old host preserved');
      CheckEqual(Int64(1000), LCfg.GetInt('server.port'), 'old port preserved');
    finally
      LWatcher.Free;
    end;
  finally
    LCfg.Free;
    Remove(LPath);
  end;
end;

procedure TestConfigWatcherFailedReloadDoesNotFireCallback;
var
  LCfg: TConfig;
  LWatcher: TConfigWatcher;
  LProbe: TConfigReloadProbe;
  LPath: string;
  LRaised: Boolean;
begin
  LPath := '/tmp/test_hotreload_nextpas_config_callback_guard.json';
  Remove(LPath);
  WriteFileText(LPath, '{"server":{"host":"initial","port":1000}}');
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson(ReadFileText(LPath));
    LProbe := TConfigReloadProbe.Create;
    LWatcher := TConfigWatcher.Create(LCfg, LPath, cfJson);
    try
      LWatcher.OnReload := @LProbe.MarkReloaded;
      TSleep.ForDuration(TDuration.FromMilliseconds(20));
      WriteFileText(LPath, '{"server":{"host":');

      LRaised := False;
      try
        LWatcher.CheckReload;
      except
        on E: EConfigError do
          LRaised := True;
      end;

      CheckEqual(True, LRaised, 'failed reload raises EConfigError');
      CheckEqual(False, LProbe.Reloaded,
        'failed reload does not fire callback');
      CheckEqual('initial', LCfg.GetString('server.host'),
        'failed reload keeps old host');
      CheckEqual(Int64(1000), LCfg.GetInt('server.port'),
        'failed reload keeps old port');
    finally
      LWatcher.Free;
      LProbe.Free;
    end;
  finally
    LCfg.Free;
    Remove(LPath);
  end;
end;

procedure TestConfigWatcherBadYamlRaisesAndPreservesOldConfig;
var
  LCfg: TConfig;
  LWatcher: TConfigWatcher;
  LPath: string;
  LRaised: Boolean;
begin
  LPath := '/tmp/test_hotreload_nextpas_config_bad_yaml.yaml';
  Remove(LPath);
  WriteFileText(LPath, 'server:' + #10 + '  host: initial' + #10 + '  port: 1000' + #10);
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromYaml(ReadFileText(LPath));
    LWatcher := TConfigWatcher.Create(LCfg, LPath, cfYaml);
    try
      TSleep.ForDuration(TDuration.FromMilliseconds(20));
      WriteFileText(LPath, '{a: *missing}');

      LRaised := False;
      try
        LWatcher.CheckReload;
      except
        on E: EConfigError do
          LRaised := True;
      end;

      CheckEqual(True, LRaised, 'bad yaml watcher reload raises EConfigError');
      CheckEqual('initial', LCfg.GetString('server.host'), 'old yaml host preserved');
      CheckEqual(Int64(1000), LCfg.GetInt('server.port'), 'old yaml port preserved');
    finally
      LWatcher.Free;
    end;
  finally
    LCfg.Free;
    Remove(LPath);
  end;
end;

procedure TestConfigWatcherBadTomlRaisesAndPreservesOldConfig;
var
  LCfg: TConfig;
  LWatcher: TConfigWatcher;
  LPath: string;
  LRaised: Boolean;
begin
  LPath := '/tmp/test_hotreload_nextpas_config_bad_toml.toml';
  Remove(LPath);
  WriteFileText(LPath, '[server]' + #10 + 'host = "initial"' + #10 + 'port = 1000' + #10);
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromToml(ReadFileText(LPath));
    LWatcher := TConfigWatcher.Create(LCfg, LPath, cfToml);
    try
      TSleep.ForDuration(TDuration.FromMilliseconds(20));
      WriteFileText(LPath, 'key = ');

      LRaised := False;
      try
        LWatcher.CheckReload;
      except
        on E: EConfigError do
          LRaised := True;
      end;

      CheckEqual(True, LRaised, 'bad toml watcher reload raises EConfigError');
      CheckEqual('initial', LCfg.GetString('server.host'), 'old toml host preserved');
      CheckEqual(Int64(1000), LCfg.GetInt('server.port'), 'old toml port preserved');
    finally
      LWatcher.Free;
    end;
  finally
    LCfg.Free;
    Remove(LPath);
  end;
end;

procedure TestConfigWatcherAmbiguousJsonRaisesAndPreservesOldConfig;
var
  LCfg: TConfig;
  LWatcher: TConfigWatcher;
  LPath: string;
  LRaised: Boolean;
begin
  LPath := '/tmp/test_hotreload_nextpas_config_ambiguous_json.json';
  Remove(LPath);
  WriteFileText(LPath, '{"server":{"host":"initial","port":1000}}');
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson(ReadFileText(LPath));
    LWatcher := TConfigWatcher.Create(LCfg, LPath, cfJson);
    try
      TSleep.ForDuration(TDuration.FromMilliseconds(20));
      WriteFileText(LPath,
        '{' + #10 +
        '  "server.host": "literal",' + #10 +
        '  "server": {' + #10 +
        '    "host": "nested"' + #10 +
        '  }' + #10 +
        '}');

      LRaised := False;
      try
        LWatcher.CheckReload;
      except
        on E: EConfigError do
        begin
          LRaised := True;
          Check(Pos('server.host', E.Message) > 0,
            'ambiguous json watcher error names key');
        end;
      end;

      CheckEqual(True, LRaised, 'ambiguous json watcher reload raises EConfigError');
      CheckEqual('initial', LCfg.GetString('server.host'), 'old ambiguous json host preserved');
      CheckEqual(Int64(1000), LCfg.GetInt('server.port'), 'old ambiguous json port preserved');
    finally
      LWatcher.Free;
    end;
  finally
    LCfg.Free;
    Remove(LPath);
  end;
end;

procedure TestConfigWatcherAmbiguousYamlRaisesAndPreservesOldConfig;
var
  LCfg: TConfig;
  LWatcher: TConfigWatcher;
  LPath: string;
  LRaised: Boolean;
begin
  LPath := '/tmp/test_hotreload_nextpas_config_ambiguous_yaml.yaml';
  Remove(LPath);
  WriteFileText(LPath, 'server:' + #10 + '  host: initial' + #10 + '  port: 1000' + #10);
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromYaml(ReadFileText(LPath));
    LWatcher := TConfigWatcher.Create(LCfg, LPath, cfYaml);
    try
      TSleep.ForDuration(TDuration.FromMilliseconds(20));
      WriteFileText(LPath,
        '"server.host": literal' + #10 +
        'server:' + #10 +
        '  host: nested' + #10);

      LRaised := False;
      try
        LWatcher.CheckReload;
      except
        on E: EConfigError do
        begin
          LRaised := True;
          Check(Pos('server.host', E.Message) > 0,
            'ambiguous yaml watcher error names key');
        end;
      end;

      CheckEqual(True, LRaised, 'ambiguous yaml watcher reload raises EConfigError');
      CheckEqual('initial', LCfg.GetString('server.host'), 'old ambiguous yaml host preserved');
      CheckEqual(Int64(1000), LCfg.GetInt('server.port'), 'old ambiguous yaml port preserved');
    finally
      LWatcher.Free;
    end;
  finally
    LCfg.Free;
    Remove(LPath);
  end;
end;

procedure TestConfigWatcherAmbiguousTomlRaisesAndPreservesOldConfig;
var
  LCfg: TConfig;
  LWatcher: TConfigWatcher;
  LPath: string;
  LRaised: Boolean;
begin
  LPath := '/tmp/test_hotreload_nextpas_config_ambiguous_toml.toml';
  Remove(LPath);
  WriteFileText(LPath, '[server]' + #10 + 'host = "initial"' + #10 + 'port = 1000' + #10);
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromToml(ReadFileText(LPath));
    LWatcher := TConfigWatcher.Create(LCfg, LPath, cfToml);
    try
      TSleep.ForDuration(TDuration.FromMilliseconds(20));
      WriteFileText(LPath,
        '"server.host" = "literal"' + #10 +
        '[server]' + #10 +
        'host = "nested"' + #10);

      LRaised := False;
      try
        LWatcher.CheckReload;
      except
        on E: EConfigError do
        begin
          LRaised := True;
          Check(Pos('server.host', E.Message) > 0,
            'ambiguous toml watcher error names key');
        end;
      end;

      CheckEqual(True, LRaised, 'ambiguous toml watcher reload raises EConfigError');
      CheckEqual('initial', LCfg.GetString('server.host'), 'old ambiguous toml host preserved');
      CheckEqual(Int64(1000), LCfg.GetInt('server.port'), 'old ambiguous toml port preserved');
    finally
      LWatcher.Free;
    end;
  finally
    LCfg.Free;
    Remove(LPath);
  end;
end;

procedure TestConfigWatcherBadIniRaisesAndPreservesOldConfig;
var
  LCfg: TConfig;
  LWatcher: TConfigWatcher;
  LPath: string;
  LRaised: Boolean;
begin
  LPath := '/tmp/test_hotreload_nextpas_config_bad_ini.ini';
  Remove(LPath);
  WriteFileText(LPath, '[server]' + #10 + 'host=initial' + #10 + 'port=1000' + #10);
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni(ReadFileText(LPath));
    LWatcher := TConfigWatcher.Create(LCfg, LPath, cfIni);
    try
      TSleep.ForDuration(TDuration.FromMilliseconds(20));
      WriteFileText(LPath, 'root=1' + #13#10 + '  [broken' + #10);

      LRaised := False;
      try
        LWatcher.CheckReload;
      except
        on E: EConfigError do
          LRaised := True;
      end;

      CheckEqual(True, LRaised, 'bad ini watcher reload raises EConfigError');
      CheckEqual('initial', LCfg.GetString('server.host'), 'old ini host preserved');
      CheckEqual(Int64(1000), LCfg.GetInt('server.port'), 'old ini port preserved');
    finally
      LWatcher.Free;
    end;
  finally
    LCfg.Free;
    Remove(LPath);
  end;
end;

procedure TestConfigWatcherMissingFileRaisesAndPreservesOldConfig;
var
  LCfg: TConfig;
  LWatcher: TConfigWatcher;
  LPath: string;
  LRaised: Boolean;
begin
  LPath := '/tmp/test_hotreload_nextpas_config_missing.toml';
  Remove(LPath);
  WriteFileText(LPath, '[server]' + #10 + 'host = "initial"' + #10 +
    'port = 1000' + #10);
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromToml(ReadFileText(LPath));
    LWatcher := TConfigWatcher.Create(LCfg, LPath, cfToml);
    try
      TSleep.ForDuration(TDuration.FromMilliseconds(20));
      Remove(LPath);

      LRaised := False;
      try
        LWatcher.CheckReload;
      except
        on E: EConfigError do
          LRaised := True;
      end;

      CheckEqual(True, LRaised, 'missing file watcher reload raises EConfigError');
      CheckEqual('initial', LCfg.GetString('server.host'), 'old missing-file host preserved');
      CheckEqual(Int64(1000), LCfg.GetInt('server.port'), 'old missing-file port preserved');
    finally
      LWatcher.Free;
    end;
  finally
    LCfg.Free;
    Remove(LPath);
  end;
end;

{ === Main === }

begin
  T := TTestRunner.Create('nextpas.core.config');
  T.Run('GetString.Basic', @TestGetStringBasic);
  T.Run('GetString.Default', @TestGetStringDefault);
  T.Run('GetString.CaseInsensitive', @TestGetStringCaseInsensitive);
  T.Run('GetRawString.PreservesPlaceholders', @TestGetRawStringPreservesPlaceholders);
  T.Run('GetRawString.CaseInsensitive', @TestGetRawStringCaseInsensitive);
  T.Run('Interpolation.ConfigKeys', @TestInterpolationConfigKeys);
  T.Run('Interpolation.ExactPlaceholderChain', @TestInterpolationExactPlaceholderChain);
  T.Run('Interpolation.CacheInvalidatesOnConfigWrite', @TestInterpolationCacheInvalidatesOnConfigWrite);
  T.Run('Interpolation.EnvFallbackIsNotCached', @TestInterpolationEnvFallbackIsNotCached);
  T.Run('Interpolation.ReplaceFromInvalidatesCache', @TestInterpolationReplaceFromInvalidatesCache);
  T.Run('Interpolation.EnvFallback', @TestInterpolationEnvFallback);
  T.Run('Interpolation.DefaultValue', @TestInterpolationDefaultValue);
  T.Run('Interpolation.ConfigWinsOverEnv', @TestInterpolationConfigWinsOverEnv);
  T.Run('Interpolation.EscapeAndUnresolved', @TestInterpolationEscapeAndUnresolved);
  T.Run('Interpolation.TypedGetters', @TestInterpolationTypedGetters);
  T.Run('Interpolation.StringArray', @TestInterpolationStringArray);
  T.Run('GetRawStringArray.PreservesPlaceholders', @TestGetRawStringArrayPreservesPlaceholders);
  T.Run('Interpolation.CycleRaises', @TestInterpolationCycleRaises);
  T.Run('Required.StringAndRequire', @TestRequiredStringAndRequire);
  T.Run('Required.MissingRaises', @TestRequiredMissingRaises);
  T.Run('Required.EmptyRaises', @TestRequiredEmptyRaises);
  T.Run('Required.TypedValues', @TestRequiredTypedValues);
  T.Run('Required.TypedWhitespaceAndSign', @TestRequiredTypedWhitespaceAndSign);
  T.Run('Required.TypedInvalidRaises', @TestRequiredTypedInvalidRaises);
  T.Run('Required.BoolWhitespaceAndCase', @TestRequiredBoolWhitespaceAndCase);
  T.Run('Required.UnresolvedPlaceholderRaises', @TestRequiredUnresolvedPlaceholderRaises);
  T.Run('Required.WhitespaceRaises', @TestRequiredWhitespaceRaises);
  T.Run('ReadSurface.RejectsEmptyKeys', @TestReadSurfaceRejectsEmptyKeys);
  T.Run('GetInt.Basic', @TestGetIntBasic);
  T.Run('GetInt.Default', @TestGetIntDefault);
  T.Run('GetInt.Invalid', @TestGetIntInvalid);
  T.Run('GetInt.WhitespaceAndSign', @TestGetIntWhitespaceAndSign);
  T.Run('GetBool.Basic', @TestGetBoolBasic);
  T.Run('GetBool.Default', @TestGetBoolDefault);
  T.Run('GetBool.WhitespaceAndCase', @TestGetBoolWhitespaceAndCase);
  T.Run('GetBool.ShortTokenWhitespaceAndCase', @TestGetBoolShortTokenWhitespaceAndCase);
  T.Run('GetBool.Invalid', @TestGetBoolInvalid);
  T.Run('GetFloat.Basic', @TestGetFloatBasic);
  T.Run('GetFloat.Default', @TestGetFloatDefault);
  T.Run('GetFloat.Invalid', @TestGetFloatInvalid);
  T.Run('GetFloat.WhitespaceAndSign', @TestGetFloatWhitespaceAndSign);
  T.Run('SetDefault', @TestSetDefault);
  T.Run('LoadFromIni.Sections', @TestLoadFromIniSections);
  T.Run('LoadFromIni.GlobalKeys', @TestLoadFromIniGlobalKeys);
  T.Run('LoadFromJson.Basic', @TestLoadFromJsonBasic);
  T.Run('LoadFromJson.Types', @TestLoadFromJsonTypes);
  T.Run('TryLoadFromIni.Valid', @TestTryLoadFromIniValid);
  T.Run('TryLoadFromIni.InvalidReportsPosition', @TestTryLoadFromIniInvalidReportsPosition);
  T.Run('TryLoadFromIni.FlattenedKeyCollision',
    @TestTryLoadFromIniRejectsFlattenedKeyCollision);
  T.Run('TryLoadFromJson.Valid', @TestTryLoadFromJsonValid);
  T.Run('TryLoadFromJson.Invalid', @TestTryLoadFromJsonInvalid);
  T.Run('TryLoadFromJson.InvalidReportsPositionCRLF',
    @TestTryLoadFromJsonInvalidReportsPositionCRLF);
  T.Run('TryLoadFromYamlAndToml.InvalidReportsOffset',
    @TestTryLoadFromYamlAndTomlInvalidReportOffset);
  T.Run('TryLoad.ShortVariantsInvalid', @TestTryLoadShortVariantsInvalid);
  T.Run('TryLoad.ShortVariantsValid', @TestTryLoadShortVariantsValid);
  T.Run('LoadFromEnv.Basic', @TestLoadFromEnvBasic);
  T.Run('LoadFromEnv.Override', @TestLoadFromEnvOverride);
  T.Run('LoadFromEnv.RejectsEmptyPrefix', @TestLoadFromEnvRejectsEmptyPrefix);
  T.Run('Has', @TestHas);
  T.Run('Has.CaseInsensitive', @TestHasCaseInsensitive);
  T.Run('GetKeys', @TestGetKeys);
  T.Run('EmptyConfig', @TestEmptyConfig);
  T.Run('Override.Priority', @TestOverridePriority);
  T.Run('Override.EnvHighest', @TestOverrideEnvHighest);
  T.Run('Count', @TestCount);
  T.Run('GetFloat.Zero', @TestGetFloatZero);
  T.Run('GetFloat.Negative', @TestGetFloatNegative);
  T.Run('Has.AfterMultipleLoads', @TestHasAfterMultipleLoads);
  T.Run('GetKeys.Order', @TestGetKeysOrder);
  T.Run('Count.AfterOverride', @TestCountAfterOverride);
  T.Run('LoadFromYaml.Basic', @TestLoadFromYamlBasic);
  T.Run('LoadFromToml.Section', @TestLoadFromTomlSection);
  T.Run('MultiSource.Override', @TestMultiSourceOverride);
  T.Run('ReplaceFrom', @TestReplaceFrom);
  T.Run('LoadFromFile.Basic', @TestLoadFromFileBasic);
  T.Run('LoadFromFile.RejectsEmptyPath', @TestLoadFromFileRejectsEmptyPath);
  T.Run('TryLoadFromFile.SuccessAndErrorsPreserveExisting',
    @TestTryLoadFromFileSuccessAndErrorsPreserveExisting);
  T.Run('ConfigWatcher.HotReloadIni', @TestConfigWatcherHotReloadIni);
  T.Run('ConfigWatcher.HotReloadJson', @TestConfigWatcherHotReloadJson);
  T.Run('ConfigWatcher.HotReloadYaml', @TestConfigWatcherHotReloadYaml);
  T.Run('ConfigWatcher.HotReloadToml', @TestConfigWatcherHotReloadToml);
  T.Run('ConfigWatcher.BadJsonRaises', @TestConfigWatcherBadJsonRaisesAndPreservesOldConfig);
  T.Run('ConfigWatcher.FailedReloadDoesNotFireCallback',
    @TestConfigWatcherFailedReloadDoesNotFireCallback);
  T.Run('ConfigWatcher.BadYamlRaises', @TestConfigWatcherBadYamlRaisesAndPreservesOldConfig);
  T.Run('ConfigWatcher.BadTomlRaises', @TestConfigWatcherBadTomlRaisesAndPreservesOldConfig);
  T.Run('ConfigWatcher.AmbiguousJsonRaises',
    @TestConfigWatcherAmbiguousJsonRaisesAndPreservesOldConfig);
  T.Run('ConfigWatcher.AmbiguousYamlRaises',
    @TestConfigWatcherAmbiguousYamlRaisesAndPreservesOldConfig);
  T.Run('ConfigWatcher.AmbiguousTomlRaises',
    @TestConfigWatcherAmbiguousTomlRaisesAndPreservesOldConfig);
  T.Run('ConfigWatcher.BadIniRaises', @TestConfigWatcherBadIniRaisesAndPreservesOldConfig);
  T.Run('ConfigWatcher.MissingFileRaises',
    @TestConfigWatcherMissingFileRaisesAndPreservesOldConfig);
  T.Summary;
end.
