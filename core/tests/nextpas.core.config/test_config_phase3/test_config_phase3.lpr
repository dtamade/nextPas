program test_config_phase3;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.os.env,
  nextpas.core.errors,
  nextpas.core.config,
  nextpas.core.config.env,
  nextpas.core.test;

var
  T: TTestSuite;

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

  { 嵌套 key：env 变量名用双下划线映射点路径，覆盖 YAML 嵌套值。 }
  SetEnv('NEXTPAS_CFG_SERVER__API_PORT', '7777');
  try
    LCfg := ConfigBuilder
      .AddYaml('server:' + #10 + '  api_port: 9000' + #10)
      .AddEnv('NEXTPAS_CFG_')
      .Build;
    CheckEqual('7777', LCfg.GetString('server.api_port'),
      'env double underscore overrides nested yaml key');
  finally
    UnsetEnv('NEXTPAS_CFG_SERVER__API_PORT');
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

procedure TestBuildConfigRaisesOnRequiredKeyFailure;
var
  LBuilder: IConfigBuilder;
  LMutable: TConfig;
  LRaised: Boolean;
begin
  LBuilder := ConfigBuilder
    .AddJson('{"name":"app"}')
    .RequireKeys(['missing']);

  LMutable := nil;
  LRaised := False;
  try
    LMutable := LBuilder.BuildConfig;
  except
    on E: EConfigError do
    begin
      LRaised := True;
      Check(Pos('missing', E.Message) > 0,
        'BuildConfig missing-key error names required key');
    end;
  end;
  CheckEqual(True, LRaised, 'BuildConfig raises on missing required key');
  Check(LMutable = nil, 'BuildConfig does not return mutable config on failure');
end;

procedure TestBuildConfigRaisesOnMalformedFile;
var
  LBadJsonPath: string;
  LMutable: TConfig;
  LRaised: Boolean;
begin
  LBadJsonPath := '/tmp/test_nextpas_config_phase3_buildconfig_bad.json';
  Remove(LBadJsonPath);
  WriteFileText(LBadJsonPath, '{"server":');
  try
    LMutable := nil;
    LRaised := False;
    try
      LMutable := ConfigBuilder.AddFile(LBadJsonPath, cfJson).BuildConfig;
    except
      on E: EConfigError do
      begin
        LRaised := True;
        Check(Pos(LBadJsonPath, E.Message) > 0,
          'BuildConfig malformed-file error includes path');
      end;
    end;
    CheckEqual(True, LRaised, 'BuildConfig raises on malformed file');
    Check(LMutable = nil, 'BuildConfig does not return mutable config for bad file');
  finally
    Remove(LBadJsonPath);
  end;
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

procedure TestTryBuildInterpolationFailure;
var
  LBuilder: IConfigBuilder;
  LCfg: IConfig;
  LError: string;
  LRaised: Boolean;
begin
  LBuilder := ConfigBuilder
    .AddJson('{"service":{"url":"https://${missing}"}}')
    .RequireKeys(['service.url']);

  LRaised := False;
  try
    LBuilder.Build;
  except
    on E: EConfigError do
    begin
      LRaised := True;
      Check(Pos('service.url', E.Message) > 0, 'Build error names required key');
    end;
  end;
  CheckEqual(True, LRaised, 'Build raises on unresolved placeholder');

  LCfg := nil;
  LError := 'stale';
  CheckEqual(False, LBuilder.TryBuild(LCfg, LError),
    'TryBuild fails on unresolved placeholder');
  Check(LCfg = nil, 'TryBuild returns nil config on interpolation failure');
  Check(Pos('service.url', LError) > 0,
    'TryBuild interpolation error names required key');
end;

procedure TestTryBuildClearsPreexistingConfigOnFailure;
var
  LExisting: IConfig;
  LCfg: IConfig;
  LError: string;
begin
  LExisting := ConfigBuilder
    .AddJson('{"name":"existing"}')
    .Build;
  LCfg := LExisting;

  LError := 'stale';
  CheckEqual(False,
    ConfigBuilder
      .AddJson('{"name":"broken"}')
      .RequireKeys(['missing'])
      .TryBuild(LCfg, LError),
    'TryBuild fails with existing output config');
  Check(LCfg = nil, 'TryBuild clears preexisting output config');
  Check(Pos('missing', LError) > 0, 'TryBuild failure reports missing key');
  CheckEqual('existing', LExisting.GetString('name'),
    'separate existing reference stays valid');
end;

procedure TestBuilderRejectsEmptyKeys;
var
  LBuilder: IConfigBuilder;
  LRaised: Boolean;
begin
  LBuilder := ConfigBuilder;
  LRaised := False;
  try
    LBuilder.AddDefault('', 'value');
  except
    on E: EConfigError do
      LRaised := True;
  end;
  CheckEqual(True, LRaised, 'AddDefault rejects empty key');

  LBuilder := ConfigBuilder.AddJson('{"name":"app"}');
  LRaised := False;
  try
    LBuilder.RequireKeys(['']);
  except
    on E: EConfigError do
      LRaised := True;
  end;
  CheckEqual(True, LRaised, 'RequireKeys rejects empty key');
end;

procedure TestBuilderRejectsEmptyEnvPrefix;
var
  LBuilder: IConfigBuilder;
  LRaised: Boolean;
  LMessage: string;
begin
  LBuilder := nil;
  LRaised := False;
  LMessage := '';
  try
    LBuilder := ConfigBuilder.AddEnv('');
  except
    on E: EConfigError do
    begin
      LRaised := True;
      LMessage := E.Message;
    end;
  end;
  CheckEqual(True, LRaised, 'AddEnv rejects empty prefix');
  CheckEqual('config env prefix must not be empty', LMessage,
    'AddEnv empty prefix error');
  Check(LBuilder = nil, 'AddEnv empty prefix leaves builder unset');
end;

procedure TestFileSourceRejectsEmptyPath;
var
  LBuilder: IConfigBuilder;
  LCfg: IConfig;
  LRaised: Boolean;
  LMessage: string;
begin
  LBuilder := nil;
  LCfg := nil;
  LRaised := False;
  LMessage := '';
  try
    LBuilder := ConfigBuilder.AddFile('', cfJson);
  except
    on E: EConfigError do
    begin
      LRaised := True;
      LMessage := E.Message;
    end;
  end;
  CheckEqual(True, LRaised, 'AddFile rejects empty file path');
  Check(LBuilder = nil, 'AddFile empty path leaves builder unset');
  Check(LCfg = nil, 'AddFile empty path does not publish config');
  CheckEqual('config file path must not be empty', LMessage,
    'AddFile empty path error message');

  LCfg := nil;
  LRaised := False;
  LMessage := '';
  try
    LCfg := ConfigLoad('', cfJson);
  except
    on E: EConfigError do
    begin
      LRaised := True;
      LMessage := E.Message;
    end;
  end;
  CheckEqual(True, LRaised, 'ConfigLoad rejects empty file path');
  Check(LCfg = nil, 'ConfigLoad empty path does not publish config');
  CheckEqual('config file path must not be empty', LMessage,
    'ConfigLoad empty path error message');
end;

procedure TestConfigEnvNameMapping;
var
  LKey: string;
begin
  LKey := '';
  CheckEqual(True,
    TryConfigEnvNameToKey('APP_HOST', 'APP_', LKey),
    'matching prefix maps');
  CheckEqual('host', LKey, 'prefix stripped and lowercased');

  LKey := 'stale';
  CheckEqual(False,
    TryConfigEnvNameToKey('APP_', 'APP_', LKey),
    'prefix without suffix rejected');
  CheckEqual('', LKey, 'empty suffix clears key');

  LKey := 'stale';
  CheckEqual(False,
    TryConfigEnvNameToKey('OTHER_HOST', 'APP_', LKey),
    'non matching prefix rejected');
  CheckEqual('', LKey, 'non match clears key');

  { 双下划线 → 点：支持嵌套 key（server_api_port → server.api_port）。 }
  LKey := '';
  CheckEqual(True,
    TryConfigEnvNameToKey('APP_SERVER__API_PORT', 'APP_', LKey),
    'nested key: double underscore maps');
  CheckEqual('server.api_port', LKey, 'double underscore becomes dot');

  LKey := '';
  CheckEqual(True,
    TryConfigEnvNameToKey('APP_DB__PATH', 'APP_', LKey),
    'nested key second case maps');
  CheckEqual('db.path', LKey, 'multi-level underscore maps to dot path');

  { 单下划线保留（不误判为分隔符）：SERVER_PORT 仍是扁平 key。 }
  LKey := '';
  CheckEqual(True,
    TryConfigEnvNameToKey('APP_SERVER_PORT', 'APP_', LKey),
    'single underscore stays literal');
  CheckEqual('server_port', LKey, 'single underscore not converted');
end;

procedure TestWindowsEnvBlockEnumeration;
var
  LBlock: AnsiString;
  LCursor: PAnsiChar;
  LEntry: string;
begin
  LBlock := 'APP_HOST=envhost' + #0 + 'APP_PORT=4000' + #0 + #0;
  LCursor := PAnsiChar(LBlock);

  CheckEqual(True,
    NextConfigWindowsEnvBlockEntry(LCursor, LEntry),
    'first entry available');
  CheckEqual('APP_HOST=envhost', LEntry, 'first entry text');

  CheckEqual(True,
    NextConfigWindowsEnvBlockEntry(LCursor, LEntry),
    'second entry available');
  CheckEqual('APP_PORT=4000', LEntry, 'second entry text');

  CheckEqual(False,
    NextConfigWindowsEnvBlockEntry(LCursor, LEntry),
    'double-null terminator ends enumeration');
  CheckEqual('', LEntry, 'no trailing garbage entry');
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

procedure TestFileSourcePriorityRules;
var
  LIniPath: string;
  LJsonPath: string;
  LCfg: IConfig;
begin
  LIniPath := '/tmp/test_nextpas_config_phase3_priority.ini';
  LJsonPath := '/tmp/test_nextpas_config_phase3_priority.json';

  Remove(LIniPath);
  Remove(LJsonPath);
  WriteFileText(LIniPath, 'host=ini-host' + #10);
  WriteFileText(LJsonPath, '{"host":"json-host"}');
  SetEnv('NEXTPAS_CFG_PHASE3_FILE_HOST', 'env-host');
  try
    LCfg := ConfigBuilder
      .AddFile(LIniPath, cfIni)
      .AddFile(LJsonPath, cfJson)
      .AddDefault('host', 'default-host')
      .Build;
    CheckEqual('json-host', LCfg.GetString('host'),
      'later file overrides earlier file and later default stays lower');

    LCfg := ConfigBuilder
      .AddFile(LJsonPath, cfJson)
      .AddEnv('NEXTPAS_CFG_PHASE3_FILE_')
      .Build;
    CheckEqual('env-host', LCfg.GetString('host'),
      'env wins when added after file');

    LCfg := ConfigBuilder
      .AddEnv('NEXTPAS_CFG_PHASE3_FILE_')
      .AddFile(LIniPath, cfIni)
      .Build;
    CheckEqual('ini-host', LCfg.GetString('host'),
      'file wins when added after env');
  finally
    UnsetEnv('NEXTPAS_CFG_PHASE3_FILE_HOST');
    Remove(LIniPath);
    Remove(LJsonPath);
  end;
end;

procedure AssertLaterFileSourceFailsClosed(
  const AGoodJsonPath: string;
  const AFailingJsonPath: string;
  AFormat: TConfigFormat;
  const AScenarioName: string);
var
  LExisting: IConfig;
  LCfg: IConfig;
  LMutable: TConfig;
  LError: string;
  LRaised: Boolean;

  function NewBuilder: IConfigBuilder;
  begin
    Result := ConfigBuilder
      .AddFile(AGoodJsonPath, AFormat)
      .AddFile(AFailingJsonPath, AFormat);
  end;

  procedure CheckErrorIncludesPath(const AErrorMessage: string; const AContext: string);
  begin
    Check(Pos(AFailingJsonPath, AErrorMessage) > 0, AContext + ' path included');
  end;
begin
  LRaised := False;
  try
    NewBuilder.Build;
  except
    on E: EConfigError do
    begin
      LRaised := True;
      CheckErrorIncludesPath(E.Message, 'Build ' + AScenarioName);
    end;
  end;
  CheckEqual(True, LRaised, 'Build raises when ' + AScenarioName);

  LMutable := nil;
  LRaised := False;
  try
    LMutable := NewBuilder.BuildConfig;
  except
    on E: EConfigError do
    begin
      LRaised := True;
      CheckErrorIncludesPath(E.Message, 'BuildConfig ' + AScenarioName);
    end;
  end;
  CheckEqual(True, LRaised, 'BuildConfig raises when ' + AScenarioName);
  Check(LMutable = nil,
    'BuildConfig does not return earlier valid snapshot on ' + AScenarioName + ' failure');

  LExisting := ConfigBuilder
    .AddJson('{"name":"existing"}')
    .Build;
  LCfg := LExisting;
  LError := 'stale';
  CheckEqual(False, NewBuilder.TryBuild(LCfg, LError),
    'TryBuild fails when ' + AScenarioName);
  Check(LCfg = nil, 'TryBuild clears preexisting output on ' + AScenarioName + ' failure');
  CheckErrorIncludesPath(LError, 'TryBuild ' + AScenarioName);
  CheckEqual('existing', LExisting.GetString('name'),
    'separate existing reference stays valid after ' + AScenarioName + ' failure');
end;

procedure TestLaterMalformedFileSourceFailsClosed;
var
  LGoodJsonPath: string;
  LBadJsonPath: string;
begin
  LGoodJsonPath := '/tmp/test_nextpas_config_phase3_fails_closed_good.json';
  LBadJsonPath := '/tmp/test_nextpas_config_phase3_fails_closed_bad.json';

  Remove(LGoodJsonPath);
  Remove(LBadJsonPath);
  WriteFileText(LGoodJsonPath, '{"host":"good-host"}');
  WriteFileText(LBadJsonPath, '{"host":');
  try
    AssertLaterFileSourceFailsClosed(
      LGoodJsonPath,
      LBadJsonPath,
      cfJson,
      'later malformed source');
  finally
    Remove(LGoodJsonPath);
    Remove(LBadJsonPath);
  end;
end;

procedure TestLaterMissingFileSourceFailsClosed;
var
  LGoodJsonPath: string;
  LMissingJsonPath: string;
begin
  LGoodJsonPath := '/tmp/test_nextpas_config_phase3_fails_closed_load_good.json';
  LMissingJsonPath := '/tmp/test_nextpas_config_phase3_fails_closed_load_missing.json';

  Remove(LGoodJsonPath);
  Remove(LMissingJsonPath);
  WriteFileText(LGoodJsonPath, '{"host":"good-host"}');
  try
    AssertLaterFileSourceFailsClosed(
      LGoodJsonPath,
      LMissingJsonPath,
      cfJson,
      'later missing source');
  finally
    Remove(LGoodJsonPath);
    Remove(LMissingJsonPath);
  end;
end;

procedure TestFileSourceErrorsIncludePathAndParserDetail;
var
  LMissingPath: string;
  LBadJsonPath: string;
  LBadIniPath: string;
  LAmbiguousJsonPath: string;
  LAmbiguousYamlPath: string;
  LAmbiguousTomlPath: string;
  LCfg: IConfig;
  LError: string;
  LInvalidFormat: TConfigFormat;
  LRaised: Boolean;
begin
  LMissingPath := '/tmp/test_nextpas_config_phase3_missing.json';
  LBadJsonPath := '/tmp/test_nextpas_config_phase3_bad.json';
  LBadIniPath := '/tmp/test_nextpas_config_phase3_bad.ini';
  LAmbiguousJsonPath := '/tmp/test_nextpas_config_phase3_ambiguous.json';
  LAmbiguousYamlPath := '/tmp/test_nextpas_config_phase3_ambiguous.yaml';
  LAmbiguousTomlPath := '/tmp/test_nextpas_config_phase3_ambiguous.toml';

  Remove(LMissingPath);
  Remove(LBadJsonPath);
  Remove(LBadIniPath);
  Remove(LAmbiguousJsonPath);
  Remove(LAmbiguousYamlPath);
  Remove(LAmbiguousTomlPath);
  WriteFileText(LBadJsonPath, '{"server":');
  WriteFileText(LBadIniPath, 'root=1' + #13#10 + '  [broken' + #10);
  WriteFileText(LAmbiguousJsonPath,
    '{' + #10 +
    '  "a.b": "literal",' + #10 +
    '  "a": {' + #10 +
    '    "b": "nested"' + #10 +
    '  }' + #10 +
    '}');
  WriteFileText(LAmbiguousYamlPath,
    '"a.b": literal' + #10 +
    'a:' + #10 +
    '  b: nested' + #10);
  WriteFileText(LAmbiguousTomlPath,
    '"a.b" = "literal"' + #10 +
    '[a]' + #10 +
    'b = "nested"' + #10);
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
    CheckEqual('Config file load error: ' + LBadJsonPath +
      ': JSON parse error at line 1, column 11 (offset 10): unexpected end of input',
      LError, 'malformed json file reports full positioned diagnostic');

    LCfg := nil;
    LError := '';
    CheckEqual(False,
      ConfigBuilder.AddFile(LBadIniPath, cfIni).TryBuild(LCfg, LError),
      'TryBuild fails for malformed ini file');
    Check(LCfg = nil, 'TryBuild returns nil config for malformed ini file');
    Check(Pos(LBadIniPath, LError) > 0, 'malformed ini file path included');
    Check(Pos('INI parse error: line 2, column 1: missing closing ]', LError) > 0,
      'ini parser detail included');

    LCfg := nil;
    LError := '';
    CheckEqual(False,
      ConfigBuilder.AddFile(LAmbiguousJsonPath, cfJson).TryBuild(LCfg, LError),
      'TryBuild fails for ambiguous json file');
    Check(LCfg = nil, 'TryBuild returns nil config for ambiguous json file');
    Check(Pos(LAmbiguousJsonPath, LError) > 0, 'ambiguous json file path included');
    Check(Pos('a.b', LError) > 0, 'ambiguous json key included');

    LRaised := False;
    try
      ConfigLoad(LAmbiguousJsonPath, cfJson);
    except
      on E: EConfigError do
      begin
        LRaised := True;
        Check(Pos(LAmbiguousJsonPath, E.Message) > 0,
          'ConfigLoad ambiguous json path included');
        Check(Pos('a.b', E.Message) > 0, 'ConfigLoad ambiguous json key included');
      end;
    end;
    CheckEqual(True, LRaised, 'ConfigLoad raises on ambiguous json file');

    LCfg := nil;
    LError := '';
    CheckEqual(False,
      ConfigBuilder.AddFile(LAmbiguousYamlPath, cfYaml).TryBuild(LCfg, LError),
      'TryBuild fails for ambiguous yaml file');
    Check(LCfg = nil, 'TryBuild returns nil config for ambiguous yaml file');
    Check(Pos(LAmbiguousYamlPath, LError) > 0, 'ambiguous yaml file path included');
    Check(Pos('a.b', LError) > 0, 'ambiguous yaml key included');

    LRaised := False;
    try
      ConfigLoad(LAmbiguousYamlPath, cfYaml);
    except
      on E: EConfigError do
      begin
        LRaised := True;
        Check(Pos(LAmbiguousYamlPath, E.Message) > 0,
          'ConfigLoad ambiguous yaml path included');
        Check(Pos('a.b', E.Message) > 0, 'ConfigLoad ambiguous yaml key included');
      end;
    end;
    CheckEqual(True, LRaised, 'ConfigLoad raises on ambiguous yaml file');

    LCfg := nil;
    LError := '';
    CheckEqual(False,
      ConfigBuilder.AddFile(LAmbiguousTomlPath, cfToml).TryBuild(LCfg, LError),
      'TryBuild fails for ambiguous toml file');
    Check(LCfg = nil, 'TryBuild returns nil config for ambiguous toml file');
    Check(Pos(LAmbiguousTomlPath, LError) > 0, 'ambiguous toml file path included');
    Check(Pos('a.b', LError) > 0, 'ambiguous toml key included');

    LRaised := False;
    try
      ConfigLoad(LAmbiguousTomlPath, cfToml);
    except
      on E: EConfigError do
      begin
        LRaised := True;
        Check(Pos(LAmbiguousTomlPath, E.Message) > 0,
          'ConfigLoad ambiguous toml path included');
        Check(Pos('a.b', E.Message) > 0, 'ConfigLoad ambiguous toml key included');
      end;
    end;
    CheckEqual(True, LRaised, 'ConfigLoad raises on ambiguous toml file');

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
    Remove(LBadIniPath);
    Remove(LAmbiguousJsonPath);
    Remove(LAmbiguousYamlPath);
    Remove(LAmbiguousTomlPath);
  end;
end;

procedure AssertEmptyKeyFileSourceFailsClosed(const APath, AContent,
  AFormatName: string; AFormat: TConfigFormat);
var
  LCfg: IConfig;
  LError: string;
  LRaised: Boolean;
begin
  Remove(APath);
  WriteFileText(APath, AContent);
  try
    LCfg := nil;
    LError := '';
    CheckEqual(False,
      ConfigBuilder.AddFile(APath, AFormat).TryBuild(LCfg, LError),
      AFormatName + ' empty-key file TryBuild fails');
    Check(LCfg = nil, AFormatName + ' empty-key file TryBuild returns nil config');
    Check(Pos(APath, LError) > 0,
      AFormatName + ' empty-key file TryBuild includes path');
    Check(Pos(AFormatName, LError) > 0,
      AFormatName + ' empty-key file TryBuild names format');
    Check(Pos('empty', LError) > 0,
      AFormatName + ' empty-key file TryBuild names empty key');

    LRaised := False;
    try
      ConfigLoad(APath, AFormat);
    except
      on E: EConfigError do
      begin
        LRaised := True;
        Check(Pos(APath, E.Message) > 0,
          AFormatName + ' empty-key ConfigLoad includes path');
        Check(Pos('empty', E.Message) > 0,
          AFormatName + ' empty-key ConfigLoad names empty key');
      end;
    end;
    CheckEqual(True, LRaised, AFormatName + ' empty-key ConfigLoad raises');
  finally
    Remove(APath);
  end;
end;

procedure TestFileSourceEmptyKeysFailClosed;
begin
  AssertEmptyKeyFileSourceFailsClosed(
    '/tmp/test_nextpas_config_phase3_empty_key.json',
    '{"shadow":"new","":"bad"}',
    'JSON',
    cfJson);
  AssertEmptyKeyFileSourceFailsClosed(
    '/tmp/test_nextpas_config_phase3_empty_key.yaml',
    'shadow: new' + #10 + '"": bad' + #10,
    'YAML',
    cfYaml);
  AssertEmptyKeyFileSourceFailsClosed(
    '/tmp/test_nextpas_config_phase3_empty_key.toml',
    'shadow = "new"' + #10 + '"" = "bad"' + #10,
    'TOML',
    cfToml);
end;

procedure TestTomlContentSourceErrors;
var
  LCfg: IConfig;
  LError: string;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    ConfigBuilder
      .AddToml(
        '"a.b" = "literal"' + #10 +
        '[a]' + #10 +
        'b = "nested"' + #10)
      .Build;
  except
    on E: EConfigError do
    begin
      LRaised := True;
      Check(Pos('a.b', E.Message) > 0, 'AddToml Build error names key');
    end;
  end;
  CheckEqual(True, LRaised, 'AddToml Build raises on ambiguous source');

  LCfg := nil;
  LError := '';
  CheckEqual(False,
    ConfigBuilder
      .AddToml(
        '"a.b" = "literal"' + #10 +
        '[a]' + #10 +
        'b = "nested"' + #10)
      .TryBuild(LCfg, LError),
    'AddToml TryBuild rejects ambiguous source');
  Check(LCfg = nil, 'AddToml TryBuild returns nil config');
  Check(Pos('a.b', LError) > 0, 'AddToml TryBuild error names key');
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
      Check(Pos('INI parse error', E.Message) > 0,
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
  Check(Pos('INI parse error', LError) > 0,
    'AddIni TryBuild error names INI parser context');
  Check(Pos('line 1', LError) > 0,
    'AddIni TryBuild error includes INI line context');
  CheckEqual('existing-host', LExisting.GetString('host'),
    'separate existing reference stays valid after AddIni failure');
end;

procedure TestJsonAndYamlContentSourceErrors;
var
  LCfg: IConfig;
  LError: string;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    ConfigBuilder
      .AddJson(
        '{' + #10 +
        '  "a.b": "literal",' + #10 +
        '  "a": {' + #10 +
        '    "b": "nested"' + #10 +
        '  }' + #10 +
        '}')
      .Build;
  except
    on E: EConfigError do
    begin
      LRaised := True;
      Check(Pos('a.b', E.Message) > 0, 'AddJson Build error names key');
    end;
  end;
  CheckEqual(True, LRaised, 'AddJson Build raises on ambiguous source');

  LCfg := nil;
  LError := '';
  CheckEqual(False,
    ConfigBuilder
      .AddJson(
        '{' + #10 +
        '  "a.b": "literal",' + #10 +
        '  "a": {' + #10 +
        '    "b": "nested"' + #10 +
        '  }' + #10 +
        '}')
      .TryBuild(LCfg, LError),
    'AddJson TryBuild rejects ambiguous source');
  Check(LCfg = nil, 'AddJson TryBuild returns nil config');
  Check(Pos('a.b', LError) > 0, 'AddJson TryBuild error names key');

  LRaised := False;
  try
    ConfigBuilder
      .AddYaml(
        '"a.b": literal' + #10 +
        'a:' + #10 +
        '  b: nested' + #10)
      .Build;
  except
    on E: EConfigError do
    begin
      LRaised := True;
      Check(Pos('a.b', E.Message) > 0, 'AddYaml Build error names key');
    end;
  end;
  CheckEqual(True, LRaised, 'AddYaml Build raises on ambiguous source');

  LCfg := nil;
  LError := '';
  CheckEqual(False,
    ConfigBuilder
      .AddYaml(
        '"a.b": literal' + #10 +
        'a:' + #10 +
        '  b: nested' + #10)
      .TryBuild(LCfg, LError),
    'AddYaml TryBuild rejects ambiguous source');
  Check(LCfg = nil, 'AddYaml TryBuild returns nil config');
  Check(Pos('a.b', LError) > 0, 'AddYaml TryBuild error names key');
end;

procedure TestEmptyKeyContentSourceErrors;
var
  LCfg: IConfig;
  LError: string;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    ConfigBuilder
      .AddJson('{"name":"valid"}')
      .AddJson('{"shadow":"new","":"bad"}')
      .Build;
  except
    on E: EConfigError do
    begin
      LRaised := True;
      Check(Pos('JSON', E.Message) > 0, 'AddJson empty key Build error names format');
      Check(Pos('empty', E.Message) > 0, 'AddJson empty key Build error names empty key');
    end;
  end;
  CheckEqual(True, LRaised, 'AddJson Build raises on empty top-level key');

  LCfg := ConfigBuilder.AddJson('{"name":"existing"}').Build;
  LError := 'stale';
  CheckEqual(False,
    ConfigBuilder
      .AddJson('{"name":"valid"}')
      .AddJson('{"shadow":"new","":"bad"}')
      .TryBuild(LCfg, LError),
    'AddJson TryBuild rejects empty top-level key');
  Check(LCfg = nil, 'AddJson empty key TryBuild clears output config');
  Check(Pos('JSON', LError) > 0, 'AddJson empty key TryBuild error names format');
  Check(Pos('empty', LError) > 0, 'AddJson empty key TryBuild error names empty key');

  LCfg := nil;
  LError := '';
  CheckEqual(False,
    ConfigBuilder
      .AddYaml('name: valid' + #10)
      .AddYaml('shadow: new' + #10 + '"": bad' + #10)
      .TryBuild(LCfg, LError),
    'AddYaml TryBuild rejects empty top-level key');
  Check(LCfg = nil, 'AddYaml empty key TryBuild returns nil config');
  Check(Pos('YAML', LError) > 0, 'AddYaml empty key TryBuild error names format');
  Check(Pos('empty', LError) > 0, 'AddYaml empty key TryBuild error names empty key');

  LCfg := nil;
  LError := '';
  CheckEqual(False,
    ConfigBuilder
      .AddToml('name = "valid"' + #10)
      .AddToml('shadow = "new"' + #10 + '"" = "bad"' + #10)
      .TryBuild(LCfg, LError),
    'AddToml TryBuild rejects empty top-level key');
  Check(LCfg = nil, 'AddToml empty key TryBuild returns nil config');
  Check(Pos('TOML', LError) > 0, 'AddToml empty key TryBuild error names format');
  Check(Pos('empty', LError) > 0, 'AddToml empty key TryBuild error names empty key');
end;

procedure TestKeyValuesOverrideOrder;
var
  LCfg: IConfig;
begin
  { Key/value overrides are ordinary sources: later wins; defaults stay lowest. }
  LCfg := ConfigBuilder
    .AddDefault('server.host', 'default-host')
    .AddDefault('server.port', '1')
    .AddJson('{"server":{"host":"json-host","port":8080}}')
    .AddKeyValues(['server.host', 'server.port'], ['kv-host', '9090'])
    .Build;

  CheckEqual('kv-host', LCfg.GetString('server.host'),
    'key values override earlier JSON source');
  CheckEqual(Int64(9090), LCfg.GetInt('server.port'),
    'key values override port as string parsed by GetInt');

  LCfg := ConfigBuilder
    .AddKeyValues(['server.host'], ['early-kv'])
    .AddJson('{"server":{"host":"later-json"}}')
    .Build;
  CheckEqual('later-json', LCfg.GetString('server.host'),
    'later JSON still overrides earlier key values');
end;

procedure TestKeyValuesRejectsLengthMismatch;
var
  LRaised: Boolean;
begin
  { Length check is eager (at AddKeyValues), same as empty env prefix validation. }
  LRaised := False;
  try
    ConfigBuilder.AddKeyValues(['only-key'], ['a', 'b']);
  except
    on E: EConfigError do
    begin
      LRaised := True;
      Check(Pos('equal length', E.Message) > 0,
        'length mismatch names equal length');
    end;
  end;
  CheckEqual(True, LRaised, 'AddKeyValues raises on length mismatch');
end;

procedure TestKeyValuesRejectsEmptyKey;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    ConfigBuilder.AddKeyValues([''], ['value']);
  except
    on E: EConfigError do
      LRaised := True;
  end;
  CheckEqual(True, LRaised, 'AddKeyValues rejects empty key');

  LRaised := False;
  try
    ConfigBuilder.AddKeyValues(['good', ''], ['1', '2']);
  except
    on E: EConfigError do
      LRaised := True;
  end;
  CheckEqual(True, LRaised, 'AddKeyValues rejects empty key in pair list');
end;

begin
  T := TTestSuite.Create('nextpas.core.config.phase3');
  T.Test('Build.ReadSurface', @TestBuildReturnsReadableIConfig);
  T.Test('Build.OwnsResult', @TestBuildOwnsResultAfterBuilderRelease);
  T.Test('Build.RawReadMethods', @TestBuildRawReadMethods);
  T.Test('Builder.DefaultPriority', @TestDefaultsStayLowestPriority);
  T.Test('Builder.SourceOrderAndEnvPriority', @TestExplicitSourceOrderAndEnvPriority);
  T.Test('Builder.BuildConfigIndependent', @TestBuildConfigReturnsIndependentMutableConfigs);
  T.Test('Builder.BuildConfigRequiredKeyFailure',
    @TestBuildConfigRaisesOnRequiredKeyFailure);
  T.Test('Builder.BuildConfigMalformedFile',
    @TestBuildConfigRaisesOnMalformedFile);
  T.Test('Builder.RequireAndTryBuild', @TestRequireKeysAndTryBuildFailure);
  T.Test('Builder.TryBuildInterpolationFailure', @TestTryBuildInterpolationFailure);
  T.Test('Builder.TryBuildClearsPreexistingConfig',
    @TestTryBuildClearsPreexistingConfigOnFailure);
  T.Test('Builder.RejectsEmptyKeys', @TestBuilderRejectsEmptyKeys);
  T.Test('Builder.RejectsEmptyEnvPrefix', @TestBuilderRejectsEmptyEnvPrefix);
  T.Test('Builder.RejectsEmptyFilePath', @TestFileSourceRejectsEmptyPath);
  T.Test('EnvHelpers.NameMapping', @TestConfigEnvNameMapping);
  T.Test('EnvHelpers.WindowsBlockEnumeration', @TestWindowsEnvBlockEnumeration);
  T.Test('FileSources.AndConfigLoad', @TestFileSourcesAndConfigLoad);
  T.Test('FileSources.PriorityRules', @TestFileSourcePriorityRules);
  T.Test('FileSources.LaterMalformedFailsClosed',
    @TestLaterMalformedFileSourceFailsClosed);
  T.Test('FileSources.LaterMissingFailsClosed',
    @TestLaterMissingFileSourceFailsClosed);
  T.Test('FileSources.Errors', @TestFileSourceErrorsIncludePathAndParserDetail);
  T.Test('FileSources.EmptyKeyFailsClosed', @TestFileSourceEmptyKeysFailClosed);
  T.Test('JsonAndYamlContentSource.Errors', @TestJsonAndYamlContentSourceErrors);
  T.Test('TomlContentSource.Errors', @TestTomlContentSourceErrors);
  T.Test('IniContentSource.Errors', @TestIniContentSourceErrors);
  T.Test('ContentSource.EmptyKeyErrors', @TestEmptyKeyContentSourceErrors);
  T.Test('Builder.KeyValuesOverrideOrder', @TestKeyValuesOverrideOrder);
  T.Test('Builder.KeyValuesRejectsLengthMismatch',
    @TestKeyValuesRejectsLengthMismatch);
  T.Test('Builder.KeyValuesRejectsEmptyKey', @TestKeyValuesRejectsEmptyKey);
  if not T.Run then Halt(1);
end.
