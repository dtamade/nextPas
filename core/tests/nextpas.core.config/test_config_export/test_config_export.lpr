program test_config_export;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.config,
  nextpas.core.errors,
  nextpas.core.fs,
  nextpas.core.testing;

var
  T: TTestRunner;

function TempJsonPath(const AName: string): string;
begin
  Result := PathJoin([GetTempDir, AName]);
end;

procedure TestToJsonBuildsNestedObjectsAndArrays;
var
  LCfg: TConfig;
  LJson: string;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('server.host', '127.0.0.1');
    LCfg.SetInt('server.port', 8080);
    LCfg.SetString('service.url', 'http://${server.host}:${server.port}');
    LCfg.SetStringArray('tags', ['api', 'prod']);

    LJson := LCfg.ToJson;
    CheckEqual('{"server":{"host":"127.0.0.1","port":"8080"},' +
      '"service":{"url":"http://${server.host}:${server.port}"},"tags":["api","prod"]}',
      LJson, 'nested object + array export');
  finally
    LCfg.Free;
  end;
end;

procedure TestToJsonSupportsTopLevelDenseArray;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('0', 'alpha');
    LCfg.SetString('1', 'beta');

    CheckEqual('["alpha","beta"]', LCfg.ToJson, 'top-level dense array export');
  finally
    LCfg.Free;
  end;
end;

procedure TestToJsonPreservesSparseNumericChildrenAsObject;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('tags.1', 'beta');
    LCfg.SetString('tags.3', 'delta');

    CheckEqual('{"tags":{"1":"beta","3":"delta"}}', LCfg.ToJson,
      'sparse numeric children stay object-shaped');
  finally
    LCfg.Free;
  end;
end;

procedure TestIConfigToJsonExportsSnapshot;
var
  LCfg: IConfig;
begin
  LCfg := ConfigBuilder
    .AddDefault('app.name', 'nextpas')
    .AddJson('{"app":{"port":8080}}')
    .Build;

  CheckEqual('{"app":{"name":"nextpas","port":"8080"}}', LCfg.ToJson,
    'IConfig snapshot export');
end;

procedure TestToJsonRoundTripsCanonicalStringValues;
var
  LCfg: TConfig;
  LReloaded: TConfig;
  LJson: string;
  LRatio: Double;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetBool('feature.enabled', True);
    LCfg.SetInt('server.port', 8080);
    LCfg.SetFloat('feature.ratio', 2.5);
    LCfg.SetString('app.name', 'nextpas');
    LCfg.SetString('service.url', 'http://${app.name}:${server.port}');

    LJson := LCfg.ToJson;

    LReloaded := TConfig.Create;
    try
      LReloaded.LoadFromJson(LJson);
      CheckEqual('true', LReloaded.GetRawString('feature.enabled'),
        'bool round-trips as canonical string');
      CheckEqual(Int64(8080), LReloaded.GetIntRequired('server.port'),
        'int getter still works after round-trip');
      LRatio := LReloaded.GetFloatRequired('feature.ratio');
      Check((LRatio > 2.4) and (LRatio < 2.6),
        'float getter still works after round-trip');
      CheckEqual('http://${app.name}:${server.port}',
        LReloaded.GetRawString('service.url'),
        'raw placeholder survives round-trip');
      CheckEqual('http://nextpas:8080', LReloaded.GetString('service.url'),
        'interpolation still works after round-trip');
    finally
      LReloaded.Free;
    end;
  finally
    LCfg.Free;
  end;
end;

procedure TestToJsonRejectsScalarSubtreeConflict;
var
  LCfg: TConfig;
  LRaised: Boolean;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('db', 'root');
    LCfg.SetString('db.host', 'localhost');

    LRaised := False;
    try
      LCfg.ToJson;
    except
      on E: EConfigError do
        LRaised := Pos('db', E.Message) > 0;
    end;
    CheckEqual(True, LRaised, 'scalar/subtree conflict raises EConfigError');
  finally
    LCfg.Free;
  end;
end;

procedure TestSaveToJsonWritesFile;
var
  LCfg: TConfig;
  LPath: string;
  LLoaded: IConfig;
begin
  LPath := TempJsonPath('nextpas_config_export_test.json');
  Remove(LPath);

  LCfg := TConfig.Create;
  try
    LCfg.SetString('app.name', 'nextpas');
    LCfg.SetInt('app.port', 8080);
    LCfg.SaveToJson(LPath);

    CheckEqual('{"app":{"name":"nextpas","port":"8080"}}', ReadFileText(LPath),
      'saved file content');

    LLoaded := ConfigLoad(LPath, cfJson);
    CheckEqual('nextpas', LLoaded.GetString('app.name'), 'saved json reloads');
    CheckEqual('{"app":{"name":"nextpas","port":"8080"}}', LLoaded.ToJson,
      'saved json reload keeps canonical export');
  finally
    LCfg.Free;
    Remove(LPath);
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.config.export');
  T.Run('Export.ToJsonBuildsNestedObjectsAndArrays',
    @TestToJsonBuildsNestedObjectsAndArrays);
  T.Run('Export.ToJsonSupportsTopLevelDenseArray',
    @TestToJsonSupportsTopLevelDenseArray);
  T.Run('Export.ToJsonPreservesSparseNumericChildrenAsObject',
    @TestToJsonPreservesSparseNumericChildrenAsObject);
  T.Run('Export.IConfigToJsonExportsSnapshot',
    @TestIConfigToJsonExportsSnapshot);
  T.Run('Export.ToJsonRoundTripsCanonicalStringValues',
    @TestToJsonRoundTripsCanonicalStringValues);
  T.Run('Export.ToJsonRejectsScalarSubtreeConflict',
    @TestToJsonRejectsScalarSubtreeConflict);
  T.Run('Export.SaveToJsonWritesFile',
    @TestSaveToJsonWritesFile);
  T.Summary;
end.
