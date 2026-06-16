program test_config_facade_surface;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.fs,
  nextpas.core.config,
  nextpas.core.testing;

var
  T: TTestRunner;

function FacadeTempPath(const AName, AExt: string): string;
begin
  Result := PathJoin([GetTempDir,
    AName + '_' + IntToStr(GetProcessID) + AExt]);
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

begin
  T := TTestRunner.Create('nextpas.core.config (facade surface)');
  T.Run('facade exposes builder surface', @TestFacadeExposesBuilderSurface);
  T.Run('facade exposes trybuild failure surface',
    @TestFacadeExposesTryBuildFailureSurface);
  T.Run('facade exposes file-source error surface',
    @TestFacadeExposesFileSourceErrorSurface);
  T.Run('facade exposes configload and direct mutable surface',
    @TestFacadeExposesConfigLoadAndDirectMutableSurface);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
