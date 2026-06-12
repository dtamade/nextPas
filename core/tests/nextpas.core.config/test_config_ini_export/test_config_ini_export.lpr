program test_config_ini_export;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.config,
  nextpas.core.errors,
  nextpas.core.fs,
  nextpas.core.ini,
  nextpas.core.testing;

var
  T: TTestRunner;

function TempIniPath(const AName: string): string;
begin
  Result := PathJoin([GetTempDir, AName]);
end;

procedure TestToIniBuildsSectionsAndGlobals;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('mode', 'prod');
    LCfg.SetString('server.host', '127.0.0.1');
    LCfg.SetInt('server.port', 8080);
    LCfg.SetStringArray('tags', ['api', 'prod']);

    CheckEqual('mode=prod' + #10 + #10 +
      '[server]' + #10 +
      'host=127.0.0.1' + #10 +
      'port=8080' + #10 + #10 +
      '[tags]' + #10 +
      '0=api' + #10 +
      '1=prod' + #10,
      LCfg.ToIni, 'ini export builds globals and sections');
  finally
    LCfg.Free;
  end;
end;

procedure TestToIniUsesDeepestRepresentableSection;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('server.tls.cert', '/tmp/cert.pem');

    CheckEqual('[server.tls]' + #10 +
      'cert=/tmp/cert.pem' + #10,
      LCfg.ToIni, 'ini export uses deepest representable section');
  finally
    LCfg.Free;
  end;
end;

procedure TestToIniFallsBackToGlobalKeyWhenSplitWouldLoseMeaning;
var
  LCfg: TConfig;
  LIni: TIniFile;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('.hidden', 'secret');
    LCfg.SetString('name.', 'tail');

    CheckEqual('.hidden=secret' + #10 +
      'name.=tail' + #10,
      LCfg.ToIni, 'ini export falls back to global key');

    LIni := TIniFile.Create;
    try
      LIni.LoadFromString(LCfg.ToIni);
      CheckEqual('secret', LIni.ReadString('', '.hidden', ''), 'leading dot key');
      CheckEqual('tail', LIni.ReadString('', 'name.', ''), 'trailing dot key');
    finally
      LIni.Free;
    end;
  finally
    LCfg.Free;
  end;
end;

procedure TestIConfigToIniExportsSnapshot;
var
  LCfg: IConfig;
begin
  LCfg := ConfigBuilder
    .AddDefault('app.name', 'nextpas')
    .AddJson('{"app":{"port":8080}}')
    .Build;

  CheckEqual('[app]' + #10 +
    'name=nextpas' + #10 +
    'port=8080' + #10,
    LCfg.ToIni, 'IConfig snapshot ini export');
end;

procedure TestToIniRoundTripsCanonicalStringValues;
var
  LCfg: TConfig;
  LReloaded: TConfig;
  LIni: string;
  LRatio: Double;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetBool('feature.enabled', True);
    LCfg.SetInt('server.port', 8080);
    LCfg.SetFloat('feature.ratio', 2.5);
    LCfg.SetString('app.name', 'nextpas');
    LCfg.SetString('service.url', 'http://${app.name}:${server.port}');

    LIni := LCfg.ToIni;

    LReloaded := TConfig.Create;
    try
      LReloaded.LoadFromIni(LIni);
      CheckEqual('true', LReloaded.GetRawString('feature.enabled'),
        'bool round-trips as canonical string');
      CheckEqual(Int64(8080), LReloaded.GetIntRequired('server.port'),
        'int getter still works after ini round-trip');
      LRatio := LReloaded.GetFloatRequired('feature.ratio');
      Check((LRatio > 2.4) and (LRatio < 2.6),
        'float getter still works after ini round-trip');
      CheckEqual('http://${app.name}:${server.port}',
        LReloaded.GetRawString('service.url'),
        'raw placeholder survives ini round-trip');
      CheckEqual('http://nextpas:8080', LReloaded.GetString('service.url'),
        'interpolation still works after ini round-trip');
    finally
      LReloaded.Free;
    end;
  finally
    LCfg.Free;
  end;
end;

procedure TestToIniPreservesTrailingWhitespaceValue;
var
  LCfg: TConfig;
  LReloaded: TConfig;
  LIni: string;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('special.trailing', 'two spaces  ');

    LIni := LCfg.ToIni;
    CheckEqual('[special]' + #10 +
      'trailing=two spaces  ' + #10,
      LIni, 'ini export preserves trailing whitespace');

    LReloaded := TConfig.Create;
    try
      LReloaded.LoadFromIni(LIni);
      CheckEqual('two spaces  ', LReloaded.GetRawString('special.trailing'),
        'trailing whitespace survives ini round-trip');
    finally
      LReloaded.Free;
    end;
  finally
    LCfg.Free;
  end;
end;

procedure TestToIniPreservesScalarSubtreeConflict;
var
  LCfg: TConfig;
  LReloaded: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('db', 'root');
    LCfg.SetString('db.host', 'localhost');

    CheckEqual('db=root' + #10 + #10 +
      '[db]' + #10 +
      'host=localhost' + #10,
      LCfg.ToIni, 'scalar/subtree export shape');

    LReloaded := TConfig.Create;
    try
      LReloaded.LoadFromIni(LCfg.ToIni);
      CheckEqual('root', LReloaded.GetRawString('db'),
        'scalar key survives');
      CheckEqual('localhost', LReloaded.GetRawString('db.host'),
        'subtree key survives');
    finally
      LReloaded.Free;
    end;
  finally
    LCfg.Free;
  end;
end;

procedure TestToIniRejectsNonRepresentableValue;
var
  LCfg: TConfig;
  LRaised: Boolean;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('special.leading', '  two spaces');

    LRaised := False;
    try
      LCfg.ToIni;
    except
      on E: EConfigError do
        LRaised := Pos('special.leading', E.Message) > 0;
    end;
    CheckEqual(True, LRaised, 'ini export rejects leading-space value');
  finally
    LCfg.Free;
  end;
end;

procedure TestSaveToIniWritesFile;
var
  LCfg: TConfig;
  LPath: string;
  LLoaded: IConfig;
begin
  LPath := TempIniPath('nextpas_config_ini_export_test.ini');
  Remove(LPath);

  LCfg := TConfig.Create;
  try
    LCfg.SetString('app.name', 'nextpas');
    LCfg.SetInt('app.port', 8080);
    LCfg.SaveToIni(LPath);

    LLoaded := ConfigLoad(LPath, cfIni);
    CheckEqual('nextpas', LLoaded.GetString('app.name'), 'saved ini reloads');
    CheckEqual('[app]' + #10 +
      'name=nextpas' + #10 +
      'port=8080' + #10,
      LLoaded.ToIni, 'saved ini reload keeps canonical export');
  finally
    LCfg.Free;
    Remove(LPath);
  end;
end;

procedure TestSaveToIniPreservesExistingFileOnExportFailure;
var
  LCfg: TConfig;
  LPath: string;
  LRaised: Boolean;
begin
  LPath := TempIniPath('nextpas_config_ini_export_fail_closed.ini');
  Remove(LPath);
  WriteFileText(LPath, 'keep=old' + #10);

  LCfg := TConfig.Create;
  try
    LCfg.SetString('special.leading', '  two spaces');

    LRaised := False;
    try
      LCfg.SaveToIni(LPath);
    except
      on E: EConfigError do
      begin
        LRaised := True;
        Check(Pos('special.leading', E.Message) > 0,
          'ini save failure names non-representable key');
      end;
    end;
    CheckEqual(True, LRaised, 'ini save raises on non-representable value');
    CheckEqual('keep=old' + #10, ReadFileText(LPath),
      'ini save failure preserves existing file');
  finally
    LCfg.Free;
    Remove(LPath);
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.config.ini_export');
  T.Run('IniExport.ToIniBuildsSectionsAndGlobals',
    @TestToIniBuildsSectionsAndGlobals);
  T.Run('IniExport.ToIniUsesDeepestRepresentableSection',
    @TestToIniUsesDeepestRepresentableSection);
  T.Run('IniExport.ToIniFallsBackToGlobalKeyWhenSplitWouldLoseMeaning',
    @TestToIniFallsBackToGlobalKeyWhenSplitWouldLoseMeaning);
  T.Run('IniExport.IConfigToIniExportsSnapshot',
    @TestIConfigToIniExportsSnapshot);
  T.Run('IniExport.ToIniRoundTripsCanonicalStringValues',
    @TestToIniRoundTripsCanonicalStringValues);
  T.Run('IniExport.ToIniPreservesTrailingWhitespaceValue',
    @TestToIniPreservesTrailingWhitespaceValue);
  T.Run('IniExport.ToIniPreservesScalarSubtreeConflict',
    @TestToIniPreservesScalarSubtreeConflict);
  T.Run('IniExport.ToIniRejectsNonRepresentableValue',
    @TestToIniRejectsNonRepresentableValue);
  T.Run('IniExport.SaveToIniWritesFile',
    @TestSaveToIniWritesFile);
  T.Run('IniExport.SaveToIniPreservesExistingFileOnExportFailure',
    @TestSaveToIniPreservesExistingFileOnExportFailure);
  T.Summary;
end.
