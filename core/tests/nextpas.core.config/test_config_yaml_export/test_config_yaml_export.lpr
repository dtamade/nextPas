program test_config_yaml_export;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.config,
  nextpas.core.errors,
  nextpas.core.fs,
  nextpas.core.testing,
  nextpas.core.yaml;

var
  T: TTestRunner;

function TempYamlPath(const AName: string): string;
begin
  Result := PathJoin([GetTempDir, AName]);
end;

procedure TestToYamlBuildsNestedObjectsAndArrays;
var
  LCfg: TConfig;
  LYaml: string;
  LDoc: IYamlDocument;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('server.host', '127.0.0.1');
    LCfg.SetInt('server.port', 8080);
    LCfg.SetString('service.url', 'http://${server.host}:${server.port}');
    LCfg.SetStringArray('tags', ['api', 'prod']);

    LYaml := LCfg.ToYaml;
    LDoc := YamlParse(LYaml);
    Check(not LDoc.HasError, 'yaml export parses');
    CheckEqual('127.0.0.1',
      LDoc.Root.MapGet('server').MapGet('host').AsStr.ToString,
      'server.host export');
    CheckEqual('8080',
      LDoc.Root.MapGet('server').MapGet('port').AsStr.ToString,
      'server.port stays string');
    CheckEqual('http://${server.host}:${server.port}',
      LDoc.Root.MapGet('service').MapGet('url').AsStr.ToString,
      'service.url raw string export');
    CheckEqual('api', LDoc.Root.MapGet('tags').SeqGet(0).AsStr.ToString,
      'tags[0]');
    CheckEqual('prod', LDoc.Root.MapGet('tags').SeqGet(1).AsStr.ToString,
      'tags[1]');
  finally
    LCfg.Free;
  end;
end;

procedure TestToYamlSupportsTopLevelDenseArray;
var
  LCfg: TConfig;
  LDoc: IYamlDocument;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('0', 'alpha');
    LCfg.SetString('1', 'beta');

    LDoc := YamlParse(LCfg.ToYaml);
    Check(not LDoc.HasError, 'top-level yaml array parses');
    CheckEqual(Int64(2), Int64(LDoc.Root.SeqLen), 'top-level seq len');
    CheckEqual('alpha', LDoc.Root.SeqGet(0).AsStr.ToString, 'seq[0]');
    CheckEqual('beta', LDoc.Root.SeqGet(1).AsStr.ToString, 'seq[1]');
  finally
    LCfg.Free;
  end;
end;

procedure TestToYamlPreservesSparseNumericChildrenAsMap;
var
  LCfg: TConfig;
  LDoc: IYamlDocument;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('tags.1', 'beta');
    LCfg.SetString('tags.3', 'delta');

    LDoc := YamlParse(LCfg.ToYaml);
    Check(not LDoc.HasError, 'sparse yaml export parses');
    Check(LDoc.Root.MapGet('tags').IsMap, 'sparse numeric children stay map');
    CheckEqual('beta', LDoc.Root.MapGet('tags').MapGet('1').AsStr.ToString,
      'map key 1');
    CheckEqual('delta', LDoc.Root.MapGet('tags').MapGet('3').AsStr.ToString,
      'map key 3');
  finally
    LCfg.Free;
  end;
end;

procedure TestIConfigToYamlExportsSnapshot;
var
  LCfg: IConfig;
  LDoc: IYamlDocument;
begin
  LCfg := ConfigBuilder
    .AddDefault('app.name', 'nextpas')
    .AddJson('{"app":{"port":8080}}')
    .Build;

  LDoc := YamlParse(LCfg.ToYaml);
  Check(not LDoc.HasError, 'snapshot yaml parses');
  CheckEqual('nextpas', LDoc.Root.MapGet('app').MapGet('name').AsStr.ToString,
    'snapshot name');
  CheckEqual('8080', LDoc.Root.MapGet('app').MapGet('port').AsStr.ToString,
    'snapshot port stays string');
end;

procedure TestToYamlRoundTripsCanonicalStringValues;
var
  LCfg: TConfig;
  LReloaded: TConfig;
  LYaml: string;
  LRatio: Double;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetBool('feature.enabled', True);
    LCfg.SetInt('server.port', 8080);
    LCfg.SetFloat('feature.ratio', 2.5);
    LCfg.SetString('app.name', 'nextpas');
    LCfg.SetString('service.url', 'http://${app.name}:${server.port}');

    LYaml := LCfg.ToYaml;

    LReloaded := TConfig.Create;
    try
      LReloaded.LoadFromYaml(LYaml);
      CheckEqual('true', LReloaded.GetRawString('feature.enabled'),
        'bool round-trips as canonical string');
      CheckEqual(Int64(8080), LReloaded.GetIntRequired('server.port'),
        'int getter still works after yaml round-trip');
      LRatio := LReloaded.GetFloatRequired('feature.ratio');
      Check((LRatio > 2.4) and (LRatio < 2.6),
        'float getter still works after yaml round-trip');
      CheckEqual('http://${app.name}:${server.port}',
        LReloaded.GetRawString('service.url'),
        'raw placeholder survives yaml round-trip');
      CheckEqual('http://nextpas:8080', LReloaded.GetString('service.url'),
        'interpolation still works after yaml round-trip');
    finally
      LReloaded.Free;
    end;
  finally
    LCfg.Free;
  end;
end;

procedure TestToYamlPreservesFlowSpecialStrings;
var
  LCfg: TConfig;
  LDoc: IYamlDocument;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('special.value', 'a,b]}');
    LCfg.SetString('special.empty', '');
    LCfg.SetString('special.trailing', 'two spaces  ');

    LDoc := YamlParse(LCfg.ToYaml);
    Check(not LDoc.HasError, 'special-string yaml parses');
    CheckEqual('a,b]}', LDoc.Root.MapGet('special').MapGet('value').AsStr.ToString,
      'flow special characters survive');
    CheckEqual('', LDoc.Root.MapGet('special').MapGet('empty').AsStr.ToString,
      'empty string survives');
    CheckEqual('two spaces  ',
      LDoc.Root.MapGet('special').MapGet('trailing').AsStr.ToString,
      'trailing spaces survive');
  finally
    LCfg.Free;
  end;
end;

procedure TestToYamlRejectsScalarSubtreeConflict;
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
      LCfg.ToYaml;
    except
      on E: EConfigError do
        LRaised := Pos('db', E.Message) > 0;
    end;
    CheckEqual(True, LRaised, 'yaml scalar/subtree conflict raises EConfigError');
  finally
    LCfg.Free;
  end;
end;

procedure CheckToYamlRejectsEmptyPathSegment(const AKey: string);
var
  LCfg: TConfig;
  LRaised: Boolean;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString(AKey, 'secret');

    LRaised := False;
    try
      LCfg.ToYaml;
    except
      on E: EConfigError do
        LRaised := Pos(AKey, E.Message) > 0;
    end;
    CheckEqual(True, LRaised,
      'yaml empty path segment raises EConfigError for ' + AKey);
  finally
    LCfg.Free;
  end;
end;

procedure TestToYamlRejectsEmptyPathSegments;
begin
  CheckToYamlRejectsEmptyPathSegment('.hidden');
  CheckToYamlRejectsEmptyPathSegment('name.');
  CheckToYamlRejectsEmptyPathSegment('a..b');
end;

procedure TestSaveToYamlWritesFile;
var
  LCfg: TConfig;
  LPath: string;
  LLoaded: IConfig;
  LDoc: IYamlDocument;
begin
  LPath := TempYamlPath('nextpas_config_yaml_export_test.yaml');
  Remove(LPath);

  LCfg := TConfig.Create;
  try
    LCfg.SetString('app.name', 'nextpas');
    LCfg.SetInt('app.port', 8080);
    LCfg.SaveToYaml(LPath);

    LDoc := YamlParse(ReadFileText(LPath));
    Check(not LDoc.HasError, 'saved yaml parses');
    CheckEqual('nextpas', LDoc.Root.MapGet('app').MapGet('name').AsStr.ToString,
      'saved yaml name');
    CheckEqual('8080', LDoc.Root.MapGet('app').MapGet('port').AsStr.ToString,
      'saved yaml port stays string');

    LLoaded := ConfigLoad(LPath, cfYaml);
    CheckEqual('nextpas', LLoaded.GetString('app.name'), 'saved yaml reloads');
    CheckEqual('8080', LLoaded.GetRawString('app.port'),
      'saved yaml reload preserves raw string');
  finally
    LCfg.Free;
    Remove(LPath);
  end;
end;

procedure TestSaveToYamlPreservesExistingFileOnExportFailure;
var
  LCfg: TConfig;
  LPath: string;
  LRaised: Boolean;
begin
  LPath := TempYamlPath('nextpas_config_yaml_export_fail_closed.yaml');
  Remove(LPath);
  WriteFileText(LPath, 'keep: old' + #10);

  LCfg := TConfig.Create;
  try
    LCfg.SetString('db', 'root');
    LCfg.SetString('db.host', 'localhost');

    LRaised := False;
    try
      LCfg.SaveToYaml(LPath);
    except
      on E: EConfigError do
      begin
        LRaised := True;
        Check(Pos('db', E.Message) > 0,
          'yaml save failure names conflicting key');
      end;
    end;
    CheckEqual(True, LRaised, 'yaml save raises on export conflict');
    CheckEqual('keep: old' + #10, ReadFileText(LPath),
      'yaml save failure preserves existing file');
  finally
    LCfg.Free;
    Remove(LPath);
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.config.yaml_export');
  T.Run('YamlExport.ToYamlBuildsNestedObjectsAndArrays',
    @TestToYamlBuildsNestedObjectsAndArrays);
  T.Run('YamlExport.ToYamlSupportsTopLevelDenseArray',
    @TestToYamlSupportsTopLevelDenseArray);
  T.Run('YamlExport.ToYamlPreservesSparseNumericChildrenAsMap',
    @TestToYamlPreservesSparseNumericChildrenAsMap);
  T.Run('YamlExport.IConfigToYamlExportsSnapshot',
    @TestIConfigToYamlExportsSnapshot);
  T.Run('YamlExport.ToYamlRoundTripsCanonicalStringValues',
    @TestToYamlRoundTripsCanonicalStringValues);
  T.Run('YamlExport.ToYamlPreservesFlowSpecialStrings',
    @TestToYamlPreservesFlowSpecialStrings);
  T.Run('YamlExport.ToYamlRejectsScalarSubtreeConflict',
    @TestToYamlRejectsScalarSubtreeConflict);
  T.Run('YamlExport.ToYamlRejectsEmptyPathSegments',
    @TestToYamlRejectsEmptyPathSegments);
  T.Run('YamlExport.SaveToYamlWritesFile',
    @TestSaveToYamlWritesFile);
  T.Run('YamlExport.SaveToYamlPreservesExistingFileOnExportFailure',
    @TestSaveToYamlPreservesExistingFileOnExportFailure);
  T.Summary;
end.
