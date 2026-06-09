program test_config_nested;
{**
 * @desc config 模块嵌套/数组展平测试 —— 验证 DOM 递归展平修复。
 *       覆盖：嵌套对象、数组、深层嵌套对象数组、空容器、标量忠实渲染。
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.config,
  nextpas.core.testing;

var
  T: TTestRunner;

{ === JSON 嵌套展平 === }

procedure TestJsonNestedObject;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"server":{"host":"localhost","port":8080}}');
    CheckEqual('localhost', LCfg.GetString('server.host'), 'nested host');
    CheckEqual(Int64(8080), LCfg.GetInt('server.port'), 'nested port');
  finally
    LCfg.Free;
  end;
end;

procedure TestJsonDeepNesting;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"db":{"pool":{"size":32,"timeout":5.5}}}');
    CheckEqual(Int64(32), LCfg.GetInt('db.pool.size'), 'deep size');
    Check(LCfg.GetFloat('db.pool.timeout') > 5.4, 'deep timeout');
  finally
    LCfg.Free;
  end;
end;

procedure TestJsonArray;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"tags":["alpha","beta","gamma"]}');
    CheckEqual('alpha', LCfg.GetString('tags.0'), 'arr 0');
    CheckEqual('beta', LCfg.GetString('tags.1'), 'arr 1');
    CheckEqual('gamma', LCfg.GetString('tags.2'), 'arr 2');
  finally
    LCfg.Free;
  end;
end;

procedure TestJsonArrayOfObjects;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"servers":[{"host":"a","port":1},{"host":"b","port":2}]}');
    CheckEqual('a', LCfg.GetString('servers.0.host'), 'obj arr 0 host');
    CheckEqual(Int64(1), LCfg.GetInt('servers.0.port'), 'obj arr 0 port');
    CheckEqual('b', LCfg.GetString('servers.1.host'), 'obj arr 1 host');
    CheckEqual(Int64(2), LCfg.GetInt('servers.1.port'), 'obj arr 1 port');
  finally
    LCfg.Free;
  end;
end;

procedure TestJsonEmptyContainers;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    { 空对象/空数组不得崩溃（UInt32 下溢防护）}
    LCfg.LoadFromJson('{"empty_obj":{},"empty_arr":[],"keep":"yes"}');
    CheckEqual('yes', LCfg.GetString('keep'), 'after empties');
    CheckEqual(False, LCfg.Has('empty_obj'), 'empty obj no key');
    CheckEqual(False, LCfg.Has('empty_arr'), 'empty arr no key');
  finally
    LCfg.Free;
  end;
end;

procedure TestJsonScalarFidelity;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"i":42,"f":3.14,"b":true,"s":"text","n":null}');
    CheckEqual('42', LCfg.GetString('i'), 'int render');
    CheckEqual(Int64(42), LCfg.GetInt('i'), 'int roundtrip');
    CheckEqual('true', LCfg.GetString('b'), 'bool render');
    CheckEqual(True, LCfg.GetBool('b'), 'bool roundtrip');
    CheckEqual('text', LCfg.GetString('s'), 'str render');
    CheckEqual('', LCfg.GetString('n'), 'null render');
    Check(LCfg.GetFloat('f') > 3.13, 'float roundtrip');
  finally
    LCfg.Free;
  end;
end;

{ === YAML 嵌套展平 === }

procedure TestYamlNestedMapping;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromYaml(
      'server:' + #10 +
      '  host: localhost' + #10 +
      '  port: 9090' + #10);
    CheckEqual('localhost', LCfg.GetString('server.host'), 'yaml nested host');
    CheckEqual(Int64(9090), LCfg.GetInt('server.port'), 'yaml nested port');
  finally
    LCfg.Free;
  end;
end;

procedure TestYamlSequence;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromYaml(
      'tags:' + #10 +
      '  - red' + #10 +
      '  - green' + #10 +
      '  - blue' + #10);
    CheckEqual('red', LCfg.GetString('tags.0'), 'yaml seq 0');
    CheckEqual('green', LCfg.GetString('tags.1'), 'yaml seq 1');
    CheckEqual('blue', LCfg.GetString('tags.2'), 'yaml seq 2');
  finally
    LCfg.Free;
  end;
end;

procedure TestYamlDeepNesting;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromYaml(
      'app:' + #10 +
      '  db:' + #10 +
      '    host: dbhost' + #10 +
      '    port: 5432' + #10);
    CheckEqual('dbhost', LCfg.GetString('app.db.host'), 'yaml deep host');
    CheckEqual(Int64(5432), LCfg.GetInt('app.db.port'), 'yaml deep port');
  finally
    LCfg.Free;
  end;
end;

{ === TOML 嵌套展平 === }

procedure TestTomlNestedTable;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromToml(
      '[server]' + #10 +
      'host = "localhost"' + #10 +
      'port = 8080' + #10 +
      '[server.tls]' + #10 +
      'enabled = true' + #10);
    CheckEqual('localhost', LCfg.GetString('server.host'), 'toml host');
    CheckEqual(Int64(8080), LCfg.GetInt('server.port'), 'toml port');
    CheckEqual(True, LCfg.GetBool('server.tls.enabled'), 'toml nested table');
  finally
    LCfg.Free;
  end;
end;

procedure TestTomlArray;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromToml('ports = [80, 443, 8080]' + #10);
    CheckEqual(Int64(80), LCfg.GetInt('ports.0'), 'toml arr 0');
    CheckEqual(Int64(443), LCfg.GetInt('ports.1'), 'toml arr 1');
    CheckEqual(Int64(8080), LCfg.GetInt('ports.2'), 'toml arr 2');
  finally
    LCfg.Free;
  end;
end;

procedure TestTomlInlineTable;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromToml('point = { x = 1, y = 2 }' + #10);
    CheckEqual(Int64(1), LCfg.GetInt('point.x'), 'inline x');
    CheckEqual(Int64(2), LCfg.GetInt('point.y'), 'inline y');
  finally
    LCfg.Free;
  end;
end;

procedure TestTomlDottedKey;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromToml('a.b.c = "deep"' + #10);
    CheckEqual('deep', LCfg.GetString('a.b.c'), 'dotted key');
  finally
    LCfg.Free;
  end;
end;

procedure TestTomlArrayOfTables;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromToml(
      '[[products]]' + #10 +
      'name = "hammer"' + #10 +
      'sku = 738' + #10 +
      '[[products]]' + #10 +
      'name = "nail"' + #10 +
      'sku = 284' + #10);
    CheckEqual('hammer', LCfg.GetString('products.0.name'), 'aot 0 name');
    CheckEqual(Int64(738), LCfg.GetInt('products.0.sku'), 'aot 0 sku');
    CheckEqual('nail', LCfg.GetString('products.1.name'), 'aot 1 name');
    CheckEqual(Int64(284), LCfg.GetInt('products.1.sku'), 'aot 1 sku');
  finally
    LCfg.Free;
  end;
end;

{ === 跨格式一致性 === }

procedure TestCrossFormatNestedOverride;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"server":{"host":"json_host"}}');
    CheckEqual('json_host', LCfg.GetString('server.host'), 'json nested');
    LCfg.LoadFromYaml('server:' + #10 + '  host: yaml_host' + #10);
    CheckEqual('yaml_host', LCfg.GetString('server.host'), 'yaml overrides nested');
    LCfg.LoadFromToml('[server]' + #10 + 'host = "toml_host"' + #10);
    CheckEqual('toml_host', LCfg.GetString('server.host'), 'toml overrides nested');
  finally
    LCfg.Free;
  end;
end;

{ === 重复加载（reuse）正确性 === }

procedure TestReloadNested;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"a":{"b":1}}');
    CheckEqual(Int64(1), LCfg.GetInt('a.b'), 'first load');
    LCfg.LoadFromJson('{"a":{"b":2}}');
    CheckEqual(Int64(2), LCfg.GetInt('a.b'), 'reload overrides');
    CheckEqual(Int64(1), Int64(LCfg.Count), 'no duplicate key');
  finally
    LCfg.Free;
  end;
end;

{ === 顶层非对象边界 === }

procedure TestJsonTopLevelArray;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('["x","y","z"]');
    CheckEqual('x', LCfg.GetString('0'), 'top arr 0');
    CheckEqual('y', LCfg.GetString('1'), 'top arr 1');
    CheckEqual('z', LCfg.GetString('2'), 'top arr 2');
  finally
    LCfg.Free;
  end;
end;

procedure TestJsonTopLevelScalar;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    { 裸标量无键可映射，按 .NET 语义忽略，不得崩溃 }
    LCfg.LoadFromJson('42');
    CheckEqual(Int64(0), Int64(LCfg.Count), 'top scalar ignored');
  finally
    LCfg.Free;
  end;
end;

procedure TestYamlTopLevelSequence;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromYaml('- one' + #10 + '- two' + #10);
    CheckEqual('one', LCfg.GetString('0'), 'top seq 0');
    CheckEqual('two', LCfg.GetString('1'), 'top seq 1');
  finally
    LCfg.Free;
  end;
end;

{ === Section / Array 读取 API === }

procedure TestGetSectionRoot;
var
  LCfg: TConfig;
  LKeys: TStringArray;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"server":{"host":"localhost","port":8080},"tags":["a"],"name":"app"}');
    LKeys := LCfg.GetSection('');
    CheckEqual(Int64(3), Int64(Length(LKeys)), 'root count');
    CheckEqual('server', LKeys[0], 'root server');
    CheckEqual('tags', LKeys[1], 'root tags');
    CheckEqual('name', LKeys[2], 'root scalar');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetSectionPrefixDirectChildren;
var
  LCfg: TConfig;
  LKeys: TStringArray;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"server":{"host":"localhost","port":8080,"tls":{"enabled":true}}}');
    LKeys := LCfg.GetSection('server');
    CheckEqual(Int64(3), Int64(Length(LKeys)), 'server section count');
    CheckEqual('host', LKeys[0], 'server host child');
    CheckEqual('port', LKeys[1], 'server port child');
    CheckEqual('tls', LKeys[2], 'server tls child');

    LKeys := LCfg.GetSection('server.tls');
    CheckEqual(Int64(1), Int64(Length(LKeys)), 'tls section count');
    CheckEqual('enabled', LKeys[0], 'tls enabled child');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetSectionArrayIndexes;
var
  LCfg: TConfig;
  LKeys: TStringArray;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"servers":[{"host":"a","port":1},{"host":"b","port":2}]}');
    LKeys := LCfg.GetSection('servers');
    CheckEqual(Int64(2), Int64(Length(LKeys)), 'servers section count');
    CheckEqual('0', LKeys[0], 'server index 0');
    CheckEqual('1', LKeys[1], 'server index 1');

    LKeys := LCfg.GetSection('servers.0');
    CheckEqual(Int64(2), Int64(Length(LKeys)), 'server 0 section count');
    CheckEqual('host', LKeys[0], 'server 0 host');
    CheckEqual('port', LKeys[1], 'server 0 port');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetSectionMissingAndCaseInsensitive;
var
  LCfg: TConfig;
  LKeys: TStringArray;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[Server]' + #10 + 'Host=localhost' + #10 + 'Port=8080' + #10);
    LKeys := LCfg.GetSection('server');
    CheckEqual(Int64(2), Int64(Length(LKeys)), 'case-insensitive section count');
    CheckEqual('Host', LKeys[0], 'preserves child case host');
    CheckEqual('Port', LKeys[1], 'preserves child case port');

    LKeys := LCfg.GetSection('missing');
    CheckEqual(Int64(0), Int64(Length(LKeys)), 'missing section empty');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetStringArrayBasic;
var
  LCfg: TConfig;
  LItems: TStringArray;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"tags":["alpha","beta","gamma"]}');
    LItems := LCfg.GetStringArray('tags');
    CheckEqual(Int64(3), Int64(Length(LItems)), 'tags count');
    CheckEqual('alpha', LItems[0], 'tag 0');
    CheckEqual('beta', LItems[1], 'tag 1');
    CheckEqual('gamma', LItems[2], 'tag 2');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetStringArraySortsNumericIndexesAndSkipsHoles;
var
  LCfg: TConfig;
  LItems: TStringArray;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetDefault('tags.2', 'two');
    LCfg.SetDefault('tags.10', 'ten');
    LCfg.SetDefault('tags.0', 'zero');
    LItems := LCfg.GetStringArray('tags');
    CheckEqual(Int64(3), Int64(Length(LItems)), 'sparse tags count');
    CheckEqual('zero', LItems[0], 'index 0 first');
    CheckEqual('two', LItems[1], 'index 2 second');
    CheckEqual('ten', LItems[2], 'index 10 third');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetStringArrayIgnoresNonCanonicalNumericSegments;
var
  LCfg: TConfig;
  LItems: TStringArray;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetDefault('tags.0', 'zero');
    LCfg.SetDefault('tags.01', 'leading-zero');
    LCfg.SetDefault('tags.2', 'two');

    LItems := LCfg.GetStringArray('tags');
    CheckEqual(Int64(2), Int64(Length(LItems)),
      'leading-zero segment is not an array index');
    CheckEqual('zero', LItems[0], 'index 0 first');
    CheckEqual('two', LItems[1], 'index 2 second');

    LItems := LCfg.GetSection('tags');
    CheckEqual(Int64(3), Int64(Length(LItems)),
      'non-canonical segment remains a section child');
    CheckEqual('0', LItems[0], 'canonical child 0');
    CheckEqual('01', LItems[1], 'leading-zero child preserved');
    CheckEqual('2', LItems[2], 'canonical child 2');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetStringArrayIgnoresObjectArrayItems;
var
  LCfg: TConfig;
  LItems: TStringArray;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"servers":[{"host":"a"},{"host":"b"}],"tags":["x"]}');
    LItems := LCfg.GetStringArray('servers');
    CheckEqual(Int64(0), Int64(Length(LItems)), 'object array has no direct string items');

    LItems := LCfg.GetStringArray('tags');
    CheckEqual(Int64(1), Int64(Length(LItems)), 'tags still readable');
    CheckEqual('x', LItems[0], 'tag x');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetStringArrayTopLevelArrayAndMissing;
var
  LCfg: TConfig;
  LItems: TStringArray;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('["x","y"]');
    LItems := LCfg.GetStringArray('');
    CheckEqual(Int64(2), Int64(Length(LItems)), 'root array count');
    CheckEqual('x', LItems[0], 'root array 0');
    CheckEqual('y', LItems[1], 'root array 1');

    LItems := LCfg.GetStringArray('missing');
    CheckEqual(Int64(0), Int64(Length(LItems)), 'missing array empty');
  finally
    LCfg.Free;
  end;
end;

procedure TestMalformedLoadRaisesConfigError;
var
  LCfg: TConfig;
  LRaised: Boolean;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"good":"value"}');

    LRaised := False;
    try
      LCfg.LoadFromJson('{not valid json');
    except
      on E: EConfigError do
      begin
        LRaised := True;
        Check(Pos('config json parse error', E.Message) > 0, 'json error category');
      end;
    end;
    CheckEqual(True, LRaised, 'bad json raises');
    CheckEqual('value', LCfg.GetString('good'), 'kept after bad json');

    LRaised := False;
    try
      LCfg.LoadFromYaml('{a: *missing}');
    except
      on E: EConfigError do
      begin
        LRaised := True;
        Check(Pos('config yaml parse error', E.Message) > 0, 'yaml error category');
      end;
    end;
    CheckEqual(True, LRaised, 'bad yaml raises');
    CheckEqual('value', LCfg.GetString('good'), 'kept after bad yaml');

    LRaised := False;
    try
      LCfg.LoadFromToml('key = ');
    except
      on E: EConfigError do
      begin
        LRaised := True;
        Check(Pos('config toml parse error', E.Message) > 0, 'toml error category');
        Check(Pos('line 1', E.Message) > 0, 'toml error line');
        Check(Pos('column', E.Message) > 0, 'toml error column');
      end;
    end;
    CheckEqual(True, LRaised, 'bad toml raises');
    CheckEqual('value', LCfg.GetString('good'), 'kept after bad toml');
  finally
    LCfg.Free;
  end;
end;

procedure TestMalformedJsonErrorIncludesLineAndColumn;
var
  LCfg: TConfig;
  LRaised: Boolean;
begin
  LCfg := TConfig.Create;
  try
    LRaised := False;
    try
      LCfg.LoadFromJson('{' + #10 +
        '  "server": ' + #10 +
        '}');
    except
      on E: EConfigError do
      begin
        LRaised := True;
        Check(Pos('config json parse error', E.Message) > 0, 'json error category');
        Check(Pos('line 2', E.Message) > 0, 'json error line');
        Check(Pos('column', E.Message) > 0, 'json error column');
      end;
    end;
    CheckEqual(True, LRaised, 'bad multiline json raises');
  finally
    LCfg.Free;
  end;
end;

{ === Main === }

begin
  T := TTestRunner.Create('nextpas.core.config.nested');
  T.Run('Json.NestedObject', @TestJsonNestedObject);
  T.Run('Json.DeepNesting', @TestJsonDeepNesting);
  T.Run('Json.Array', @TestJsonArray);
  T.Run('Json.ArrayOfObjects', @TestJsonArrayOfObjects);
  T.Run('Json.EmptyContainers', @TestJsonEmptyContainers);
  T.Run('Json.ScalarFidelity', @TestJsonScalarFidelity);
  T.Run('Yaml.NestedMapping', @TestYamlNestedMapping);
  T.Run('Yaml.Sequence', @TestYamlSequence);
  T.Run('Yaml.DeepNesting', @TestYamlDeepNesting);
  T.Run('Toml.NestedTable', @TestTomlNestedTable);
  T.Run('Toml.Array', @TestTomlArray);
  T.Run('Toml.InlineTable', @TestTomlInlineTable);
  T.Run('Toml.DottedKey', @TestTomlDottedKey);
  T.Run('Toml.ArrayOfTables', @TestTomlArrayOfTables);
  T.Run('CrossFormat.NestedOverride', @TestCrossFormatNestedOverride);
  T.Run('Reload.Nested', @TestReloadNested);
  T.Run('Json.TopLevelArray', @TestJsonTopLevelArray);
  T.Run('Json.TopLevelScalar', @TestJsonTopLevelScalar);
  T.Run('Yaml.TopLevelSequence', @TestYamlTopLevelSequence);
  T.Run('GetSection.Root', @TestGetSectionRoot);
  T.Run('GetSection.PrefixDirectChildren', @TestGetSectionPrefixDirectChildren);
  T.Run('GetSection.ArrayIndexes', @TestGetSectionArrayIndexes);
  T.Run('GetSection.MissingAndCaseInsensitive', @TestGetSectionMissingAndCaseInsensitive);
  T.Run('GetStringArray.Basic', @TestGetStringArrayBasic);
  T.Run('GetStringArray.SparseNumericOrder', @TestGetStringArraySortsNumericIndexesAndSkipsHoles);
  T.Run('GetStringArray.IgnoresNonCanonicalNumericSegments',
    @TestGetStringArrayIgnoresNonCanonicalNumericSegments);
  T.Run('GetStringArray.IgnoresObjectArrayItems', @TestGetStringArrayIgnoresObjectArrayItems);
  T.Run('GetStringArray.TopLevelArrayAndMissing', @TestGetStringArrayTopLevelArrayAndMissing);
  T.Run('Malformed.LoadRaisesConfigError', @TestMalformedLoadRaisesConfigError);
  T.Run('Malformed.JsonLineColumn', @TestMalformedJsonErrorIncludesLineAndColumn);
  T.Summary;
end.
