program test_config_toml_export;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.config,
  nextpas.core.fs,
  nextpas.core.testing,
  nextpas.core.toml;

var
  T: TTestRunner;

function TempTomlPath(const AName: string): string;
begin
  Result := PathJoin([GetTempDir, AName]);
end;

procedure TestToTomlExportsLiteralFlatKeys;
var
  LCfg: TConfig;
  LToml: string;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('server.host', '127.0.0.1');
    LCfg.SetInt('server.port', 8080);
    LCfg.SetString('service.url', 'http://${server.host}:${server.port}');
    LCfg.SetStringArray('tags', ['api', 'prod']);

    LToml := LCfg.ToToml;
    CheckEqual('"server.host" = "127.0.0.1"' + #10 +
      '"server.port" = "8080"' + #10 +
      '"service.url" = "http://${server.host}:${server.port}"' + #10 +
      '"tags.0" = "api"' + #10 +
      '"tags.1" = "prod"' + #10,
      LToml, 'toml export uses literal flat keys');
  finally
    LCfg.Free;
  end;
end;

procedure TestToTomlSupportsTopLevelDenseArrayKeys;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('0', 'alpha');
    LCfg.SetString('1', 'beta');

    CheckEqual('0 = "alpha"' + #10 + '1 = "beta"' + #10,
      LCfg.ToToml, 'top-level numeric keys export as literal keys');
  finally
    LCfg.Free;
  end;
end;

procedure TestIConfigToTomlExportsSnapshot;
var
  LCfg: IConfig;
begin
  LCfg := ConfigBuilder
    .AddDefault('app.name', 'nextpas')
    .AddJson('{"app":{"port":8080}}')
    .Build;

  CheckEqual('"app.name" = "nextpas"' + #10 +
    '"app.port" = "8080"' + #10,
    LCfg.ToToml, 'IConfig snapshot toml export');
end;

procedure TestToTomlRoundTripsCanonicalStringValues;
var
  LCfg: TConfig;
  LReloaded: TConfig;
  LToml: string;
  LRatio: Double;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetBool('feature.enabled', True);
    LCfg.SetInt('server.port', 8080);
    LCfg.SetFloat('feature.ratio', 2.5);
    LCfg.SetString('app.name', 'nextpas');
    LCfg.SetString('service.url', 'http://${app.name}:${server.port}');

    LToml := LCfg.ToToml;

    LReloaded := TConfig.Create;
    try
      LReloaded.LoadFromToml(LToml);
      CheckEqual('true', LReloaded.GetRawString('feature.enabled'),
        'bool round-trips as canonical string');
      CheckEqual(Int64(8080), LReloaded.GetIntRequired('server.port'),
        'int getter still works after toml round-trip');
      LRatio := LReloaded.GetFloatRequired('feature.ratio');
      Check((LRatio > 2.4) and (LRatio < 2.6),
        'float getter still works after toml round-trip');
      CheckEqual('http://${app.name}:${server.port}',
        LReloaded.GetRawString('service.url'),
        'raw placeholder survives toml round-trip');
      CheckEqual('http://nextpas:8080', LReloaded.GetString('service.url'),
        'interpolation still works after toml round-trip');
    finally
      LReloaded.Free;
    end;
  finally
    LCfg.Free;
  end;
end;

procedure TestToTomlPreservesScalarSubtreeConflict;
var
  LCfg: TConfig;
  LReloaded: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('db', 'root');
    LCfg.SetString('db.host', 'localhost');

    LReloaded := TConfig.Create;
    try
      LReloaded.LoadFromToml(LCfg.ToToml);
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

procedure TestToTomlPreservesEscapedStrings;
var
  LCfg: TConfig;
  LDoc: ITomlDocument;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('special.leading', '  two spaces');
    LCfg.SetString('special.multiline', 'line1' + #10 + 'line2');

    LDoc := TomlParse(LCfg.ToToml);
    Check(not LDoc.HasError, 'escaped-string toml parses');
    CheckEqual('  two spaces', LDoc.Root.Get('special.leading').AsStr.ToString,
      'leading spaces survive');
    CheckEqual('line1' + #10 + 'line2',
      LDoc.Root.Get('special.multiline').AsStr.ToString,
      'multiline string survives');
  finally
    LCfg.Free;
  end;
end;

procedure TestSaveToTomlWritesFile;
var
  LCfg: TConfig;
  LPath: string;
  LLoaded: IConfig;
begin
  LPath := TempTomlPath('nextpas_config_toml_export_test.toml');
  Remove(LPath);

  LCfg := TConfig.Create;
  try
    LCfg.SetString('app.name', 'nextpas');
    LCfg.SetInt('app.port', 8080);
    LCfg.SaveToToml(LPath);

    LLoaded := ConfigLoad(LPath, cfToml);
    CheckEqual('nextpas', LLoaded.GetString('app.name'), 'saved toml reloads');
    CheckEqual('"app.name" = "nextpas"' + #10 +
      '"app.port" = "8080"' + #10,
      LLoaded.ToToml, 'saved toml reload keeps canonical export');
  finally
    LCfg.Free;
    Remove(LPath);
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.config.toml_export');
  T.Run('TomlExport.ToTomlExportsLiteralFlatKeys',
    @TestToTomlExportsLiteralFlatKeys);
  T.Run('TomlExport.ToTomlSupportsTopLevelDenseArrayKeys',
    @TestToTomlSupportsTopLevelDenseArrayKeys);
  T.Run('TomlExport.IConfigToTomlExportsSnapshot',
    @TestIConfigToTomlExportsSnapshot);
  T.Run('TomlExport.ToTomlRoundTripsCanonicalStringValues',
    @TestToTomlRoundTripsCanonicalStringValues);
  T.Run('TomlExport.ToTomlPreservesScalarSubtreeConflict',
    @TestToTomlPreservesScalarSubtreeConflict);
  T.Run('TomlExport.ToTomlPreservesEscapedStrings',
    @TestToTomlPreservesEscapedStrings);
  T.Run('TomlExport.SaveToTomlWritesFile',
    @TestSaveToTomlWritesFile);
  T.Summary;
end.
