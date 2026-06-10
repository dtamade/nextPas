program test_config_phase3;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.os.env,
  nextpas.core.errors,
  nextpas.core.config,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestBuildReturnsReadableIConfig;
var
  LCfg: IConfig;
  LTags: TStringArray;
  LSection: TStringArray;
  LRatio: Double;
begin
  LCfg := ConfigBuilder
    .AddJson('{"server":{"host":"localhost","port":8080},' +
      '"tags":["alpha","beta"],"feature":{"enabled":true},"ratio":2.5}')
    .RequireKeys(['server.host', 'server.port'])
    .Build;

  Check(LCfg <> nil, 'build returns config interface');
  CheckEqual('localhost', LCfg.GetStringRequired('server.host'), 'host');
  CheckEqual(Int64(8080), LCfg.GetIntRequired('server.port'), 'port');
  CheckEqual(True, LCfg.GetBoolRequired('feature.enabled'), 'enabled');
  LRatio := LCfg.GetFloatRequired('ratio');
  Check((LRatio > 2.4) and (LRatio < 2.6), 'ratio');

  LTags := LCfg.GetStringArray('tags');
  CheckEqual(Int64(2), Int64(Length(LTags)), 'tag count');
  CheckEqual('alpha', LTags[0], 'tag 0');
  CheckEqual('beta', LTags[1], 'tag 1');

  LSection := LCfg.GetSection('server');
  CheckEqual(Int64(2), Int64(Length(LSection)), 'section count');
  CheckEqual(True, LCfg.Has('server.host'), 'host exists');
  CheckEqual(Int64(6), Int64(LCfg.Count), 'leaf count');
  LCfg.Require(['server.host', 'server.port']);
end;

procedure TestBuildOwnsResultAfterBuilderRelease;
var
  LBuilder: IConfigBuilder;
  LCfg: IConfig;
begin
  LBuilder := ConfigBuilder.AddJson('{"name":"owned"}');
  LCfg := LBuilder.Build;
  LBuilder := nil;

  Check(LCfg <> nil, 'config survives builder release');
  CheckEqual('owned', LCfg.GetString('name'), 'owned config remains readable');
end;

procedure TestBuildRawReadMethods;
var
  LCfg: IConfig;
  LTags: TStringArray;
begin
  SetEnv('NEXTPAS_CFG_PHASE3_RAW', 'env-raw');
  try
    LCfg := ConfigBuilder
      .AddJson('{"source":{"name":"blue"},' +
        '"value":"${source.name}","tags":["${source.name}","$${source.name}",' +
        '"${NEXTPAS_CFG_PHASE3_RAW}"]}')
      .Build;

    CheckEqual('${source.name}', LCfg.GetRawString('value'), 'raw string');
    CheckEqual('${fallback}', LCfg.GetRawString('missing', '${fallback}'),
      'raw default');
    CheckEqual('blue', LCfg.GetString('value'), 'interpolated string');

    LTags := LCfg.GetRawStringArray('tags');
    CheckEqual(Int64(3), Int64(Length(LTags)), 'raw array count');
    CheckEqual('${source.name}', LTags[0], 'raw array placeholder');
    CheckEqual('$${source.name}', LTags[1], 'raw array escaped placeholder');
    CheckEqual('${NEXTPAS_CFG_PHASE3_RAW}', LTags[2], 'raw array env placeholder');
  finally
    UnsetEnv('NEXTPAS_CFG_PHASE3_RAW');
  end;
end;

procedure TestDefaultsStayLowestPriority;
var
  LCfg: IConfig;
begin
  LCfg := ConfigBuilder
    .AddJson('{"server":{"host":"json-host"}}')
    .AddDefault('server.host', 'default-host')
    .Build;
  CheckEqual('json-host', LCfg.GetString('server.host'),
    'explicit source overrides later default');

  LCfg := ConfigBuilder
    .AddDefault('server.host', 'first')
    .AddDefault('server.host', 'second')
    .Build;
  CheckEqual('second', LCfg.GetString('server.host'), 'last default wins');
end;

procedure TestExplicitSourceOrderAndEnvPriority;
var
  LCfg: IConfig;
begin
  SetEnv('NEXTPAS_CFG_HOST', 'env-host');
  try
    LCfg := ConfigBuilder
      .AddIni('host=ini-host' + #10)
      .AddYaml('host: yaml-host' + #10)
      .AddToml('host = "toml-host"' + #10)
      .AddJson('{"host":"json-host"}')
      .Build;
    CheckEqual('json-host', LCfg.GetString('host'), 'later explicit source wins');

    LCfg := ConfigBuilder
      .AddJson('{"host":"json-host"}')
      .AddEnv('NEXTPAS_CFG_')
      .Build;
    CheckEqual('env-host', LCfg.GetString('host'), 'env wins when added last');

    LCfg := ConfigBuilder
      .AddEnv('NEXTPAS_CFG_')
      .AddJson('{"host":"json-host"}')
      .Build;
    CheckEqual('json-host', LCfg.GetString('host'), 'env is not implicitly highest');
  finally
    UnsetEnv('NEXTPAS_CFG_HOST');
  end;
end;

procedure TestBuildConfigReturnsIndependentMutableConfigs;
var
  LBuilder: IConfigBuilder;
  LMutable: TConfig;
  LReadonly: IConfig;
begin
  LBuilder := ConfigBuilder.AddJson('{"name":"base"}');

  LMutable := LBuilder.BuildConfig;
  try
    LMutable.LoadFromJson('{"name":"mutated"}');
    CheckEqual('mutated', LMutable.GetString('name'), 'mutable config can change');
  finally
    LMutable.Free;
  end;

  LReadonly := LBuilder.Build;
  CheckEqual('base', LReadonly.GetString('name'),
    'later build returns fresh independent config');
end;

procedure TestRequireKeysAndTryBuildFailure;
var
  LBuilder: IConfigBuilder;
  LCfg: IConfig;
  LError: string;
  LRaised: Boolean;
begin
  LBuilder := ConfigBuilder
    .AddJson('{"name":"app"}')
    .RequireKeys(['name'])
    .RequireKeys(['missing']);

  LRaised := False;
  try
    LBuilder.Build;
  except
    on E: EConfigError do
      LRaised := True;
  end;
  CheckEqual(True, LRaised, 'Build raises on missing required key');

  LError := 'stale';
  LCfg := nil;
  CheckEqual(False, LBuilder.TryBuild(LCfg, LError), 'TryBuild fails on missing key');
  Check(LError <> '', 'TryBuild returns error');
  Check(LCfg = nil, 'TryBuild returns nil config on failure');
end;

procedure TestFileSourcesAndConfigLoad;
var
  LIniPath: string;
  LJsonPath: string;
  LYamlPath: string;
  LTomlPath: string;
  LCfg: IConfig;
begin
  LIniPath := '/tmp/test_nextpas_config_phase3.ini';
  LJsonPath := '/tmp/test_nextpas_config_phase3.json';
  LYamlPath := '/tmp/test_nextpas_config_phase3.yaml';
  LTomlPath := '/tmp/test_nextpas_config_phase3.toml';

  Remove(LIniPath);
  Remove(LJsonPath);
  Remove(LYamlPath);
  Remove(LTomlPath);
  WriteFileText(LIniPath, '[app]' + #10 + 'name=ini-app' + #10);
  WriteFileText(LJsonPath, '{"app":{"name":"json-app","port":8080}}');
  WriteFileText(LYamlPath, 'app:' + #10 + '  enabled: true' + #10);
  WriteFileText(LTomlPath, '[app]' + #10 + 'ratio = 1.5' + #10);

  try
    LCfg := ConfigBuilder
      .AddFile(LIniPath, cfIni)
      .AddFile(LYamlPath, cfYaml)
      .AddFile(LTomlPath, cfToml)
      .Build;
    CheckEqual('ini-app', LCfg.GetString('app.name'), 'ini file source');
    CheckEqual(True, LCfg.GetBool('app.enabled'), 'yaml file source');
    Check(LCfg.GetFloat('app.ratio') > 1.4, 'toml file source');

    LCfg := ConfigLoad(LJsonPath, cfJson);
    CheckEqual('json-app', LCfg.GetString('app.name'), 'ConfigLoad json file');
    CheckEqual(Int64(8080), LCfg.GetInt('app.port'), 'ConfigLoad json port');
  finally
    Remove(LIniPath);
    Remove(LJsonPath);
    Remove(LYamlPath);
    Remove(LTomlPath);
  end;
end;

procedure TestFileSourceErrorsIncludePathAndParserDetail;
var
  LMissingPath: string;
  LBadJsonPath: string;
  LCfg: IConfig;
  LError: string;
  LInvalidFormat: TConfigFormat;
  LRaised: Boolean;
begin
  LMissingPath := '/tmp/test_nextpas_config_phase3_missing.json';
  LBadJsonPath := '/tmp/test_nextpas_config_phase3_bad.json';

  Remove(LMissingPath);
  Remove(LBadJsonPath);
  WriteFileText(LBadJsonPath, '{"server":');
  try
    LRaised := False;
    try
      ConfigBuilder.AddFile(LMissingPath, cfJson).Build;
    except
      on E: EConfigError do
      begin
        LRaised := True;
        Check(Pos(LMissingPath, E.Message) > 0, 'missing file path included');
      end;
    end;
    CheckEqual(True, LRaised, 'Build raises on missing file');

    LCfg := nil;
    LError := '';
    CheckEqual(False,
      ConfigBuilder.AddFile(LBadJsonPath, cfJson).TryBuild(LCfg, LError),
      'TryBuild fails for malformed file');
    Check(LCfg = nil, 'TryBuild returns nil config for malformed file');
    Check(Pos(LBadJsonPath, LError) > 0, 'malformed file path included');
    Check(Pos('config json parse error', LError) > 0, 'parser detail included');

    LRaised := False;
    FillChar(LInvalidFormat, SizeOf(LInvalidFormat), $FF);
    try
      ConfigBuilder.AddFile(LBadJsonPath, LInvalidFormat).Build;
    except
      on E: EConfigError do
      begin
        LRaised := True;
        Check(Pos(LBadJsonPath, E.Message) > 0, 'invalid format path included');
      end;
    end;
    CheckEqual(True, LRaised, 'Build raises on invalid format');
  finally
    Remove(LBadJsonPath);
  end;
end;

procedure TestIniContentSourceErrors;
var
  LExisting: IConfig;
  LCfg: IConfig;
  LError: string;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    ConfigBuilder
      .AddIni('host=valid-host' + #10)
      .AddIni('  [broken' + #10)
      .Build;
  except
    on E: EConfigError do
    begin
      LRaised := True;
      Check(Pos('config ini parse error', E.Message) > 0,
        'AddIni Build error names INI parser context');
      Check(Pos('line 1', E.Message) > 0,
        'AddIni Build error includes INI line context');
    end;
  end;
  CheckEqual(True, LRaised, 'AddIni Build raises on malformed content source');

  LExisting := ConfigBuilder.AddJson('{"host":"existing-host"}').Build;
  LCfg := LExisting;
  LError := 'stale';
  CheckEqual(False,
    ConfigBuilder
      .AddIni('host=valid-host' + #10)
      .AddIni('  [broken' + #10)
      .TryBuild(LCfg, LError),
    'AddIni TryBuild rejects malformed content source');
  Check(LCfg = nil, 'AddIni TryBuild clears preexisting output config');
  Check(Pos('config ini parse error', LError) > 0,
    'AddIni TryBuild error names INI parser context');
  Check(Pos('line 1', LError) > 0,
    'AddIni TryBuild error includes INI line context');
  CheckEqual('existing-host', LExisting.GetString('host'),
    'separate existing reference stays valid after AddIni failure');
end;

begin
  T := TTestRunner.Create('nextpas.core.config.phase3');
  T.Run('Build.ReadSurface', @TestBuildReturnsReadableIConfig);
  T.Run('Build.OwnsResult', @TestBuildOwnsResultAfterBuilderRelease);
  T.Run('Build.RawReadMethods', @TestBuildRawReadMethods);
  T.Run('Builder.DefaultPriority', @TestDefaultsStayLowestPriority);
  T.Run('Builder.SourceOrderAndEnvPriority', @TestExplicitSourceOrderAndEnvPriority);
  T.Run('Builder.BuildConfigIndependent', @TestBuildConfigReturnsIndependentMutableConfigs);
  T.Run('Builder.RequireAndTryBuild', @TestRequireKeysAndTryBuildFailure);
  T.Run('FileSources.AndConfigLoad', @TestFileSourcesAndConfigLoad);
  T.Run('FileSources.Errors', @TestFileSourceErrorsIncludePathAndParserDetail);
  T.Run('IniContentSource.Errors', @TestIniContentSourceErrors);
  T.Summary;
end.
