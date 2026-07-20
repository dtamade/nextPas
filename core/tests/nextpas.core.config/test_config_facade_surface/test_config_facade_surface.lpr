program test_config_facade_surface;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.time,
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.fs,
  nextpas.core.config,
  nextpas.core.config.watcher,
  nextpas.core.test;

var
  T: TTestSuite;

function FacadeTempPath(const AName, AExt: string): string;
begin
  Result := PathJoin([GetTempDir,
    AName + '_' + IntToStr(PtrUInt(Pointer(@T))) + AExt]);
end;

procedure RemoveIfExists(const APath: string);
begin
  if Exists(APath) then
    Remove(APath);
end;

procedure TestFacadeExposesBuilderSurface;
var
  LBuilder: IConfigBuilder;
  LSnapshot: IConfig;
  LMutable: TConfig;
  LTags: TStringArray;
begin
  LBuilder := ConfigBuilder
    .AddDefault('server.host', 'default-host')
    .AddJson('{"server":{"host":"json-host","port":8080},' +
      '"feature":{"enabled":true},"tags":["alpha","beta"]}');

  LSnapshot := LBuilder.Build;
  Check(LSnapshot <> nil, 'Build returns facade snapshot');
  CheckEqual('json-host', LSnapshot.GetStringRequired('server.host'),
    'Build exposes required string reads');
  CheckEqual(Int64(8080), LSnapshot.GetIntRequired('server.port'),
    'Build exposes required integer reads');
  CheckEqual(True, LSnapshot.GetBoolRequired('feature.enabled'),
    'Build exposes required bool reads');
  LTags := LSnapshot.GetStringArray('tags');
  CheckEqual(Int64(2), Int64(Length(LTags)),
    'Build exposes array reads through facade');
  CheckEqual('alpha', LTags[0], 'Build exposes first array item');
  CheckEqual('beta', LTags[1], 'Build exposes second array item');

  LMutable := LBuilder.BuildConfig;
  try
    LMutable.SetString('server.host', 'mutable-host');
    LMutable.SetInt('server.port', 9090);
    LMutable.SetBool('feature.enabled', False);
    LMutable.SetStringArray('tags', ['gamma', 'delta']);
    CheckEqual('mutable-host', LMutable.GetString('server.host'),
      'BuildConfig exposes mutable string writes');
    CheckEqual(Int64(9090), LMutable.GetInt('server.port'),
      'BuildConfig exposes mutable integer writes');
    CheckEqual(False, LMutable.GetBool('feature.enabled'),
      'BuildConfig exposes mutable bool writes');
    LTags := LMutable.GetStringArray('tags');
    CheckEqual(Int64(2), Int64(Length(LTags)),
      'BuildConfig exposes mutable array writes');
    CheckEqual('gamma', LTags[0], 'BuildConfig exposes updated first array item');
    CheckEqual('delta', LTags[1], 'BuildConfig exposes updated second array item');
  finally
    LMutable.Free;
  end;

  CheckEqual('json-host', LSnapshot.GetString('server.host'),
    'Build snapshot stays independent from later BuildConfig mutations');
end;

procedure TestFacadeExposesTryBuildFailureSurface;
var
  LCfg: IConfig;
  LError: string;
begin
  CheckEqual(False,
    ConfigBuilder
      .AddJson('{"server":{"host":"json-host"}}')
      .RequireKeys(['server.port'])
      .TryBuild(LCfg, LError),
    'TryBuild failure is visible through facade');
  Check(LCfg = nil, 'TryBuild clears output on failure');
  Check(Pos('server.port', LError) > 0,
    'TryBuild exposes missing-key diagnostics');
end;

procedure TestFacadeExposesFileSourceErrorSurface;
var
  LPath: string;
  LCfg: IConfig;
  LError: string;
  LRaised: Boolean;
begin
  LPath := FacadeTempPath('test_nextpas_config_facade_missing', '.ini');
  RemoveIfExists(LPath);

  LRaised := False;
  try
    ConfigLoad(LPath, cfIni);
  except
    on E: EConfigError do
    begin
      LRaised := True;
      Check(Pos(LPath, E.Message) > 0,
        'ConfigLoad missing-file error includes path');
    end;
  end;
  Check(LRaised, 'ConfigLoad missing file raises EConfigError');

  LRaised := False;
  try
    ConfigBuilder.AddFile(LPath, cfIni).Build;
  except
    on E: EConfigError do
    begin
      LRaised := True;
      Check(Pos(LPath, E.Message) > 0,
        'builder Build missing-file error includes path');
    end;
  end;
  Check(LRaised, 'builder Build missing file raises EConfigError');

  LCfg := ConfigBuilder.AddIni('ok=1').Build;
  LError := '';
  CheckEqual(False,
    ConfigBuilder.AddFile(LPath, cfIni).TryBuild(LCfg, LError),
    'TryBuild reports missing-file source failure');
  Check(LCfg = nil, 'TryBuild clears prior output on missing-file failure');
  Check(Pos(LPath, LError) > 0,
    'TryBuild missing-file error includes path');
end;

procedure TestFacadeExposesKeyValuesSurface;
var
  LCfg: IConfig;
begin
  LCfg := ConfigBuilder
    .AddDefault('server.host', 'default')
    .AddJson('{"server":{"host":"json-host","port":1}}')
    .AddKeyValues(['server.host', 'server.port'], ['cli-host', '8443'])
    .RequireKeys(['server.host', 'server.port'])
    .Build;
  CheckEqual('cli-host', LCfg.GetStringRequired('server.host'),
    'AddKeyValues is part of the public builder facade');
  CheckEqual(Int64(8443), LCfg.GetIntRequired('server.port'),
    'AddKeyValues values are readable as typed getters');
end;

procedure TestFacadeExposesConfigLoadAndDirectMutableSurface;
var
  LPath: string;
  LSnapshot: IConfig;
  LMutable: TConfig;
begin
  LPath := FacadeTempPath('test_nextpas_config_facade_surface', '.json');
  RemoveIfExists(LPath);
  WriteFileText(LPath,
    '{"server":{"host":"file-host","port":8081},"debug":true}');
  try
    LSnapshot := ConfigLoad(LPath, cfJson);
    CheckEqual('file-host', LSnapshot.GetString('server.host'),
      'ConfigLoad is visible through facade');
    CheckEqual(Int64(8081), LSnapshot.GetInt('server.port'),
      'ConfigLoad exposes integer reads');
    CheckEqual(True, LSnapshot.GetBool('debug'),
      'ConfigLoad exposes bool reads');

    LMutable := TConfig.Create;
    try
      LMutable.LoadFromIni('[app]' + #10 + 'name=nextpas' + #10);
      LMutable.LoadFromFile(LPath, cfJson);
      CheckEqual('nextpas', LMutable.GetString('app.name'),
        'TConfig direct loader remains visible');
      CheckEqual('file-host', LMutable.GetString('server.host'),
        'TConfig.LoadFromFile remains visible');
      Check(Pos('"server"', LMutable.ToJson) > 0,
        'TConfig export surface remains visible');
    finally
      LMutable.Free;
    end;
  finally
    RemoveIfExists(LPath);
  end;
end;

procedure TestFacadeExposesAutoDetectFormat;
var
  LJsonPath, LIniPath, LUnknownPath: string;
  LSnapshot: IConfig;
  LMutable: TConfig;
  LFormat: TConfigFormat;
  LError: string;
begin
  CheckEqual(True, TryDetectConfigFormat('app.json', LFormat),
    'detect .json');
  CheckEqual(Ord(cfJson), Ord(LFormat), 'detect maps json');
  CheckEqual(True, TryDetectConfigFormat('app.YAML', LFormat),
    'detect .YAML case-insensitive');
  CheckEqual(Ord(cfYaml), Ord(LFormat), 'detect maps yaml');
  CheckEqual(True, TryDetectConfigFormat('cfg.yml', LFormat),
    'detect .yml');
  CheckEqual(Ord(cfYaml), Ord(LFormat), 'detect maps yml to yaml');
  CheckEqual(True, TryDetectConfigFormat('a.toml', LFormat),
    'detect .toml');
  CheckEqual(Ord(cfToml), Ord(LFormat), 'detect maps toml');
  CheckEqual(True, TryDetectConfigFormat('a.ini', LFormat),
    'detect .ini');
  CheckEqual(Ord(cfIni), Ord(LFormat), 'detect maps ini');
  CheckEqual(False, TryDetectConfigFormat('a.txt', LFormat),
    'unknown extension rejected by extension detect');
  CheckEqual(False, TryDetectConfigFormat('noext', LFormat),
    'missing extension rejected by extension detect');

  LJsonPath := FacadeTempPath('test_nextpas_config_autodetect', '.json');
  LIniPath := FacadeTempPath('test_nextpas_config_autodetect', '.ini');
  LUnknownPath := FacadeTempPath('test_nextpas_config_autodetect', '.txt');
  RemoveIfExists(LJsonPath);
  RemoveIfExists(LIniPath);
  RemoveIfExists(LUnknownPath);
  WriteFileText(LJsonPath, '{"server":{"host":"auto-json"}}');
  WriteFileText(LIniPath, '[server]' + #10 + 'host=auto-ini' + #10);
  WriteFileText(LUnknownPath, 'not a config at all !!!');
  try
    LSnapshot := ConfigLoad(LJsonPath);
    CheckEqual('auto-json', LSnapshot.GetString('server.host'),
      'ConfigLoad auto-detects json extension');

    LSnapshot := ConfigBuilder.AddFile(LIniPath).Build;
    CheckEqual('auto-ini', LSnapshot.GetString('server.host'),
      'AddFile auto-detects ini extension');

    LMutable := TConfig.Create;
    try
      LMutable.LoadFromFile(LJsonPath);
      CheckEqual('auto-json', LMutable.GetString('server.host'),
        'TConfig.LoadFromFile auto-detects extension');
      CheckEqual(True, LMutable.TryLoadFromFile(LIniPath, LError),
        'TryLoadFromFile auto-detect succeeds');
      CheckEqual('auto-ini', LMutable.GetString('server.host'),
        'TryLoadFromFile auto-detect loads ini');
      CheckEqual(False, LMutable.TryLoadFromFile(LUnknownPath, LError),
        'TryLoadFromFile rejects unsniffable content');
      Check((Pos('sniff', LError) > 0) or (Pos('parse', LError) > 0) or
        (Pos('error', LError) > 0),
        'unsniffable content has diagnostic error');
    finally
      LMutable.Free;
    end;
  finally
    RemoveIfExists(LJsonPath);
    RemoveIfExists(LIniPath);
    RemoveIfExists(LUnknownPath);
  end;
end;

procedure TestFacadeExposesContentSniff;
var
  LNoExt, LCfgExt, LWrongExt, LNoise: string;
  LSnapshot: IConfig;
  LFormat: TConfigFormat;
  LError: string;
  LMutable: TConfig;
begin
  CheckEqual(True, TrySniffConfigFormat('{"a":1}', LFormat), 'sniff json');
  CheckEqual(Ord(cfJson), Ord(LFormat), 'sniff maps json');
  CheckEqual(True, TrySniffConfigFormat('a = 1' + #10, LFormat), 'sniff toml');
  CheckEqual(Ord(cfToml), Ord(LFormat), 'sniff maps toml');
  CheckEqual(True, TrySniffConfigFormat('host: localhost' + #10, LFormat),
    'sniff yaml');
  CheckEqual(Ord(cfYaml), Ord(LFormat), 'sniff maps yaml');
  { key=value without spaces is INI, not TOML }
  CheckEqual(True, TrySniffConfigFormat('host=localhost' + #10, LFormat),
    'sniff ini-style assignment');
  CheckEqual(Ord(cfIni), Ord(LFormat), 'sniff maps ini');
  CheckEqual(False, TrySniffConfigFormat('!!!not-config!!!', LFormat),
    'sniff rejects noise');
  CheckEqual(False, TrySniffConfigFormat('', LFormat), 'sniff rejects empty');

  LNoExt := FacadeTempPath('test_nextpas_config_sniff_noext', '');
  LCfgExt := FacadeTempPath('test_nextpas_config_sniff', '.cfg');
  LWrongExt := FacadeTempPath('test_nextpas_config_sniff_wrong', '.json');
  LNoise := FacadeTempPath('test_nextpas_config_sniff_noise', '');
  RemoveIfExists(LNoExt);
  RemoveIfExists(LCfgExt);
  RemoveIfExists(LWrongExt);
  RemoveIfExists(LNoise);
  WriteFileText(LNoExt, '{"server":{"host":"sniff-json"}}');
  WriteFileText(LCfgExt, 'server.host = "sniff-toml"' + #10);
  WriteFileText(LWrongExt, 'server:' + #10 + '  host: sniff-yaml' + #10);
  WriteFileText(LNoise, '???garbage???');
  try
    LSnapshot := ConfigLoad(LNoExt);
    CheckEqual('sniff-json', LSnapshot.GetString('server.host'),
      'extensionless file sniffs json');

    LSnapshot := ConfigBuilder.AddFile(LCfgExt).Build;
    CheckEqual('sniff-toml', LSnapshot.GetString('server.host'),
      'unknown .cfg extension sniffs toml');

    LSnapshot := ConfigLoad(LWrongExt);
    CheckEqual('sniff-yaml', LSnapshot.GetString('server.host'),
      'wrong .json extension recovers via yaml sniff');

    LMutable := TConfig.Create;
    try
      CheckEqual(False, LMutable.TryLoadFromFile(LNoise, LError),
        'noise content fails sniff load');
      Check(Pos('sniff', LError) > 0,
        'noise error mentions sniff');
    finally
      LMutable.Free;
    end;
  finally
    RemoveIfExists(LNoExt);
    RemoveIfExists(LCfgExt);
    RemoveIfExists(LWrongExt);
    RemoveIfExists(LNoise);
  end;
end;

procedure TestFacadeExposesSectionAndDuration;
var
  LCfg: IConfig;
  LSec, LTls: IConfig;
  LKeys: TStringArray;
  LRaised: Boolean;
  LNs: Int64;
begin
  LCfg := ConfigBuilder
    .AddJson('{"server":{"host":"h1","port":8080,"tls":{"enabled":true}},' +
      '"timeout":"300ms","idle":"2s"}')
    .Build;

  LSec := ConfigSection(LCfg, 'server');
  CheckEqual('h1', LSec.GetString('host'), 'section GetString');
  CheckEqual(Int64(8080), LSec.GetInt('port'), 'section GetInt');
  Check(LSec.Has('host'), 'section Has');
  CheckEqual(False, LSec.Has('missing'), 'section missing');
  LKeys := LSec.GetKeys;
  Check(Length(LKeys) >= 2, 'section keys include host/port');

  LTls := ConfigSection(LSec, 'tls');
  CheckEqual(True, LTls.GetBool('enabled'), 'nested section bool');

  LRaised := False;
  try
    LSec.ToJson;
  except
    on E: EConfigError do
      LRaised := True;
  end;
  Check(LRaised, 'section export rejected');

  CheckEqual(True, TryParseConfigDurationNs('300ms', LNs), 'parse 300ms');
  CheckEqual(Int64(300) * 1000000, LNs, '300ms nanos');
  CheckEqual(True, TryParseConfigDurationNs('2s', LNs), 'parse 2s');
  CheckEqual(Int64(2) * 1000000000, LNs, '2s nanos');
  CheckEqual(True, TryParseConfigDurationNs('150', LNs), 'bare int = seconds');
  CheckEqual(Int64(150) * 1000000000, LNs, '150s nanos');
  CheckEqual(False, TryParseConfigDurationNs('nope', LNs), 'invalid duration');

  CheckEqual(Int64(300) * 1000000, LCfg.GetDurationNs('timeout'),
    'GetDurationNs timeout');
  CheckEqual(Int64(2) * 1000000000, LCfg.GetDurationNsRequired('idle'),
    'GetDurationNsRequired idle');
  CheckEqual(Int64(99), LCfg.GetDurationNs('missing', 99),
    'GetDurationNs default');
end;

procedure TestFacadeExposesByteSizeAndWatcherAuto;
var
  LCfg: IConfig;
  LMutable: TConfig;
  LBytes: Int64;
  LPath: string;
  LWatcher: TConfigWatcher;
  LReloaded: Boolean;
  LAttempt: Integer;
begin
  CheckEqual(True, TryParseConfigByteSize('1KB', LBytes), 'parse 1KB');
  CheckEqual(Int64(1024), LBytes, '1KB = 1024');
  CheckEqual(True, TryParseConfigByteSize('2MiB', LBytes), 'parse 2MiB');
  CheckEqual(Int64(2) * 1024 * 1024, LBytes, '2MiB');
  CheckEqual(True, TryParseConfigByteSize('512', LBytes), 'bare bytes');
  CheckEqual(Int64(512), LBytes, '512 bytes');
  CheckEqual(False, TryParseConfigByteSize('xx', LBytes), 'invalid size');

  LCfg := ConfigBuilder
    .AddJson('{"max_body":"4MB","limit":"100"}')
    .Build;
  CheckEqual(Int64(4) * 1024 * 1024, LCfg.GetByteSize('max_body'),
    'GetByteSize 4MB');
  CheckEqual(Int64(100), LCfg.GetByteSizeRequired('limit'),
    'GetByteSize bare');
  CheckEqual(Int64(7), LCfg.GetByteSize('missing', 7),
    'GetByteSize default');

  LPath := FacadeTempPath('test_nextpas_config_watcher_auto', '.json');
  RemoveIfExists(LPath);
  WriteFileText(LPath, '{"server":{"host":"initial"}}');
  LMutable := TConfig.Create;
  try
    LMutable.LoadFromFile(LPath);
    LWatcher := TConfigWatcher.Create(LMutable, LPath);
    try
      CheckEqual(False, LWatcher.CheckReload, 'auto watcher stable');
      LReloaded := False;
      for LAttempt := 0 to 20 do
      begin
        TSleep.ForDuration(TDuration.FromMilliseconds(20));
        WriteFileText(LPath, '{"server":{"host":"reloaded"},"x":1}');
        LReloaded := LWatcher.CheckReload;
        if LReloaded then
          Break;
      end;
      CheckEqual(True, LReloaded, 'auto watcher reloads');
      CheckEqual('reloaded', LMutable.GetString('server.host'),
        'auto watcher content');
    finally
      LWatcher.Free;
    end;
  finally
    LMutable.Free;
    RemoveIfExists(LPath);
  end;
end;

procedure TestFacadeExposesCloneAndMerge;
var
  LBase, LClone, LOverlay: TConfig;
  LSnap: IConfig;
begin
  LBase := TConfig.Create;
  try
    LBase.SetString('a', '1');
    LBase.SetString('b', '2');
    LBase.SetInterpolationMode(cimStrict);
    LClone := LBase.Clone;
    try
      CheckEqual('1', LClone.GetString('a'), 'clone a');
      CheckEqual(Ord(cimStrict), Ord(LClone.GetInterpolationMode),
        'clone mode');
      LClone.SetString('a', 'cloned');
      CheckEqual('1', LBase.GetString('a'), 'clone independent');
    finally
      LClone.Free;
    end;

    LOverlay := TConfig.Create;
    try
      LOverlay.SetString('b', 'merged');
      LOverlay.SetString('c', '3');
      LBase.MergeFrom(LOverlay);
      CheckEqual('1', LBase.GetString('a'), 'merge keeps a');
      CheckEqual('merged', LBase.GetString('b'), 'merge overwrites b');
      CheckEqual('3', LBase.GetString('c'), 'merge adds c');
    finally
      LOverlay.Free;
    end;

    LSnap := ConfigBuilder.AddJson('{"a":"from-iface","d":"4"}').Build;
    LBase.MergeFrom(LSnap);
    CheckEqual('from-iface', LBase.GetString('a'), 'merge IConfig');
    CheckEqual('4', LBase.GetString('d'), 'merge IConfig new key');
    CheckEqual('a=from-iface' + #10 + 'b=merged' + #10 + 'c=3' + #10 + 'd=4',
      LBase.DebugDump, 'DebugDump sorted');
    CheckEqual(LBase.DebugDump, ConfigDebugDump(ConfigBorrow(LBase)),
      'ConfigDebugDump matches');
  finally
    LBase.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.config (facade surface)');
  T.Test('facade exposes builder surface', @TestFacadeExposesBuilderSurface);
  T.Test('facade exposes trybuild failure surface',
    @TestFacadeExposesTryBuildFailureSurface);
  T.Test('facade exposes file-source error surface',
    @TestFacadeExposesFileSourceErrorSurface);
  T.Test('facade exposes keyvalues surface',
    @TestFacadeExposesKeyValuesSurface);
  T.Test('facade exposes configload and direct mutable surface',
    @TestFacadeExposesConfigLoadAndDirectMutableSurface);
  T.Test('facade exposes auto-detect format',
    @TestFacadeExposesAutoDetectFormat);
  T.Test('facade exposes content sniff',
    @TestFacadeExposesContentSniff);
  T.Test('facade exposes section and duration',
    @TestFacadeExposesSectionAndDuration);
  T.Test('facade exposes byte size and watcher auto',
    @TestFacadeExposesByteSizeAndWatcherAuto);
  T.Test('facade exposes clone and merge',
    @TestFacadeExposesCloneAndMerge);
  if not T.Run then Halt(1);
end.
