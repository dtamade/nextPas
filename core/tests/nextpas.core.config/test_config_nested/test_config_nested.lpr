program test_config_nested;
{**
 * @desc config 模块嵌套/数组展平测试 —— 验证 DOM 递归展平修复。
 *       覆盖：嵌套对象、数组、深层嵌套对象数组、空容器、标量忠实渲染。
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.time,
  nextpas.core.config,
  nextpas.core.test;

var
  T: TTestSuite;

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

procedure TestYamlSeqOfMapsWithNestedSeq;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromYaml(
      'domain_weights:' + #10 +
      '  - task: latency' + #10 +
      '    items:' + #10 +
      '      - domain: example.com' + #10 +
      '        weight: 2' + #10 +
      '      - domain: foo.com' + #10 +
      '        weight: 1' + #10 +
      '  - task: dns' + #10 +
      '    items:' + #10 +
      '      - domain: bar.com' + #10 +
      '        weight: 3' + #10);
    CheckEqual('latency', LCfg.GetString('domain_weights.0.task'), 'item0 task');
    CheckEqual('example.com',
      LCfg.GetString('domain_weights.0.items.0.domain'), 'item0.items0');
    CheckEqual('foo.com',
      LCfg.GetString('domain_weights.0.items.1.domain'), 'item0.items1');
    CheckEqual('dns', LCfg.GetString('domain_weights.1.task'), 'item1 task');
    CheckEqual('bar.com',
      LCfg.GetString('domain_weights.1.items.0.domain'), 'item1.items0');
    CheckEqual(Int64(3), LCfg.GetInt('domain_weights.1.items.0.weight'),
      'item1.items0.weight');
    CheckEqual(False, LCfg.Has('domain_weights.0.items.2.task'),
      'second outer item is not rolled into first nested seq');
  finally
    LCfg.Free;
  end;
end;

procedure AppendYamlChunk(var ABuf: string; var ALen: Integer; const ASrc: string);
var
  LAdd: Integer;
begin
  LAdd := Length(ASrc);
  if ALen + LAdd > Length(ABuf) then
  begin
    if Length(ABuf) = 0 then
      SetLength(ABuf, 4096)
    else
      SetLength(ABuf, (ALen + LAdd) * 2);
  end;
  if LAdd > 0 then
    Move(ASrc[1], ABuf[ALen + 1], LAdd);
  Inc(ALen, LAdd);
end;

procedure TestYamlLargeObjectArrayLinear;
const
  N = 12000;
  MAX_MS = 2000;
var
  LCfg: TConfig;
  LInput: string;
  LLen, LI: Integer;
  LStart, LElapsed: UInt64;
begin
  LLen := 0;
  SetLength(LInput, 8 + N * 24);
  AppendYamlChunk(LInput, LLen, 'items:' + #10);
  for LI := 0 to N - 1 do
    AppendYamlChunk(LInput, LLen, '  - name: n' + IntToStr(LI) + #10);
  SetLength(LInput, LLen);

  LCfg := TConfig.Create;
  try
    LStart := GetTickCount64;
    LCfg.LoadFromYaml(LInput);
    LElapsed := GetTickCount64 - LStart;
    CheckEqual(Int64(N), Int64(LCfg.Count), 'flattened key count');
    CheckEqual('n0', LCfg.GetString('items.0.name'), 'first item');
    CheckEqual('n' + IntToStr(N - 1),
      LCfg.GetString('items.' + IntToStr(N - 1) + '.name'), 'last item');
    Check(LElapsed < MAX_MS,
      'LoadFromYaml of ' + IntToStr(N) + ' object-array items took ' +
      IntToStr(LElapsed) + 'ms (budget ' + IntToStr(MAX_MS) + 'ms)');
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

procedure TestTomlAmbiguousLiteralKeyVsTableRaises;
var
  LCfg: TConfig;
  LRaised: Boolean;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('a.b', 'old');
    LRaised := False;
    try
      LCfg.LoadFromToml(
        '"a.b" = "literal"' + #10 +
        '[a]' + #10 +
        'b = "nested"' + #10);
      Fail('ambiguous TOML literal key and table path must be rejected');
    except
      on E: EConfigError do
      begin
        LRaised := True;
        Check(Pos('a.b', E.Message) > 0, 'ambiguous toml error names key');
      end;
    end;
    CheckEqual(True, LRaised, 'ambiguous TOML literal key/table raises');
    CheckEqual('old', LCfg.GetString('a.b'), 'failed TOML load preserves old value');
  finally
    LCfg.Free;
  end;
end;

procedure TestTomlAmbiguousLiteralKeyVsDottedKeyRaises;
var
  LCfg: TConfig;
  LRaised: Boolean;
begin
  LCfg := TConfig.Create;
  try
    LRaised := False;
    try
      LCfg.LoadFromToml(
        '"a.b" = "literal"' + #10 +
        'a.b = "nested"' + #10);
      Fail('ambiguous TOML literal key and dotted key must be rejected');
    except
      on E: EConfigError do
      begin
        LRaised := True;
        Check(Pos('a.b', E.Message) > 0, 'ambiguous dotted error names key');
      end;
    end;
    CheckEqual(True, LRaised, 'ambiguous TOML literal key/dotted key raises');
  finally
    LCfg.Free;
  end;
end;

procedure TestTomlTryLoadAmbiguousReturnsFalse;
var
  LCfg: TConfig;
  LError: string;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('a.b', 'old');
    LError := '';
    CheckEqual(False,
      LCfg.TryLoadFromToml(
        '"a.b" = "literal"' + #10 +
        '[a]' + #10 +
        'b = "nested"' + #10,
        LError),
      'TryLoadFromToml rejects ambiguous TOML source');
    Check(Pos('a.b', LError) > 0, 'TryLoadFromToml error names key');
    CheckEqual('old', LCfg.GetString('a.b'), 'failed TryLoadFromToml preserves old value');
  finally
    LCfg.Free;
  end;
end;

procedure TestJsonAmbiguousLiteralKeyVsNestedPathRaises;
var
  LCfg: TConfig;
  LRaised: Boolean;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('keep', 'old');
    LRaised := False;
    try
      LCfg.LoadFromJson(
        '{' + #10 +
        '  "shadow": "new",' + #10 +
        '  "a.b": "literal",' + #10 +
        '  "a": {' + #10 +
        '    "b": "nested"' + #10 +
        '  }' + #10 +
        '}');
      Fail('ambiguous JSON dotted key and nested path must be rejected');
    except
      on E: EConfigError do
      begin
        LRaised := True;
        Check(Pos('a.b', E.Message) > 0, 'ambiguous json error names key');
      end;
    end;
    CheckEqual(True, LRaised, 'ambiguous JSON dotted key/nested path raises');
    CheckEqual('old', LCfg.GetString('keep'), 'failed JSON load preserves old value');
    CheckEqual(False, LCfg.Has('shadow'), 'failed JSON load does not partially apply new keys');
  finally
    LCfg.Free;
  end;
end;

procedure TestJsonTryLoadAmbiguousReturnsFalse;
var
  LCfg: TConfig;
  LError: string;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('keep', 'old');
    LError := '';
    CheckEqual(False,
      LCfg.TryLoadFromJson(
        '{' + #10 +
        '  "shadow": "new",' + #10 +
        '  "a.b": "literal",' + #10 +
        '  "a": {' + #10 +
        '    "b": "nested"' + #10 +
        '  }' + #10 +
        '}',
        LError),
      'TryLoadFromJson rejects ambiguous source');
    Check(Pos('a.b', LError) > 0, 'TryLoadFromJson error names key');
    CheckEqual('old', LCfg.GetString('keep'), 'failed TryLoadFromJson preserves old value');
    CheckEqual(False, LCfg.Has('shadow'), 'failed TryLoadFromJson does not partially apply new keys');
  finally
    LCfg.Free;
  end;
end;

procedure TestYamlAmbiguousLiteralKeyVsNestedPathRaises;
var
  LCfg: TConfig;
  LRaised: Boolean;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('keep', 'old');
    LRaised := False;
    try
      LCfg.LoadFromYaml(
        'shadow: new' + #10 +
        '"a.b": literal' + #10 +
        'a:' + #10 +
        '  b: nested' + #10);
      Fail('ambiguous YAML dotted key and nested path must be rejected');
    except
      on E: EConfigError do
      begin
        LRaised := True;
        Check(Pos('a.b', E.Message) > 0, 'ambiguous yaml error names key');
      end;
    end;
    CheckEqual(True, LRaised, 'ambiguous YAML dotted key/nested path raises');
    CheckEqual('old', LCfg.GetString('keep'), 'failed YAML load preserves old value');
    CheckEqual(False, LCfg.Has('shadow'), 'failed YAML load does not partially apply new keys');
  finally
    LCfg.Free;
  end;
end;

procedure TestYamlTryLoadAmbiguousReturnsFalse;
var
  LCfg: TConfig;
  LError: string;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('keep', 'old');
    LError := '';
    CheckEqual(False,
      LCfg.TryLoadFromYaml(
        'shadow: new' + #10 +
        '"a.b": literal' + #10 +
        'a:' + #10 +
        '  b: nested' + #10,
        LError),
      'TryLoadFromYaml rejects ambiguous source');
    Check(Pos('a.b', LError) > 0, 'TryLoadFromYaml error names key');
    CheckEqual('old', LCfg.GetString('keep'), 'failed TryLoadFromYaml preserves old value');
    CheckEqual(False, LCfg.Has('shadow'), 'failed TryLoadFromYaml does not partially apply new keys');
  finally
    LCfg.Free;
  end;
end;

procedure TestJsonEmptyTopLevelKeyRaises;
var
  LCfg: TConfig;
  LError: string;
  LRaised: Boolean;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('keep', 'old');
    LRaised := False;
    try
      LCfg.LoadFromJson(
        '{' + #10 +
        '  "shadow": "new",' + #10 +
        '  "": "bad"' + #10 +
        '}');
      Fail('JSON empty top-level key must be rejected');
    except
      on E: EConfigError do
      begin
        LRaised := True;
        Check(Pos('JSON', E.Message) > 0, 'empty json key error names format');
        Check(Pos('empty', E.Message) > 0, 'empty json key error names empty key');
      end;
    end;
    CheckEqual(True, LRaised, 'empty JSON key raises');
    CheckEqual('old', LCfg.GetString('keep'), 'failed JSON empty-key load preserves old value');
    CheckEqual(False, LCfg.Has('shadow'), 'failed JSON empty-key load does not partially apply new keys');

    LError := '';
    CheckEqual(False, LCfg.TryLoadFromJson('{"shadow":"new","":"bad"}', LError),
      'TryLoadFromJson rejects empty top-level key');
    Check(Pos('JSON', LError) > 0, 'TryLoadFromJson empty key error names format');
    Check(Pos('empty', LError) > 0, 'TryLoadFromJson empty key error names empty key');
    CheckEqual('old', LCfg.GetString('keep'), 'failed TryLoadFromJson empty-key load preserves old value');
    CheckEqual(False, LCfg.Has('shadow'), 'failed TryLoadFromJson empty-key load does not partially apply new keys');

    LError := '';
    CheckEqual(False,
      LCfg.TryLoadFromJson('{"shadow":"new","":{"nested":"bad"}}', LError),
      'TryLoadFromJson rejects empty top-level container key');
    Check(Pos('empty', LError) > 0, 'TryLoadFromJson empty container key error');
    CheckEqual(False, LCfg.Has('nested'), 'failed empty JSON container does not flatten into root');

    LError := '';
    CheckEqual(False,
      LCfg.TryLoadFromJson('{"server":{"":"bad"}}', LError),
      'TryLoadFromJson rejects nested empty key segment');
    Check(Pos('empty', LError) > 0, 'TryLoadFromJson nested empty key error');
    CheckEqual(False, LCfg.Has('server.'), 'failed nested empty JSON key does not publish trailing-dot key');
  finally
    LCfg.Free;
  end;
end;

procedure TestYamlEmptyTopLevelKeyRaises;
var
  LCfg: TConfig;
  LError: string;
  LRaised: Boolean;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('keep', 'old');
    LRaised := False;
    try
      LCfg.LoadFromYaml(
        'shadow: new' + #10 +
        '"": bad' + #10);
      Fail('YAML empty top-level key must be rejected');
    except
      on E: EConfigError do
      begin
        LRaised := True;
        Check(Pos('YAML', E.Message) > 0, 'empty yaml key error names format');
        Check(Pos('empty', E.Message) > 0, 'empty yaml key error names empty key');
      end;
    end;
    CheckEqual(True, LRaised, 'empty YAML key raises');
    CheckEqual('old', LCfg.GetString('keep'), 'failed YAML empty-key load preserves old value');
    CheckEqual(False, LCfg.Has('shadow'), 'failed YAML empty-key load does not partially apply new keys');

    LError := '';
    CheckEqual(False,
      LCfg.TryLoadFromYaml('shadow: new' + #10 + '"": bad' + #10, LError),
      'TryLoadFromYaml rejects empty top-level key');
    Check(Pos('YAML', LError) > 0, 'TryLoadFromYaml empty key error names format');
    Check(Pos('empty', LError) > 0, 'TryLoadFromYaml empty key error names empty key');
    CheckEqual('old', LCfg.GetString('keep'), 'failed TryLoadFromYaml empty-key load preserves old value');
    CheckEqual(False, LCfg.Has('shadow'), 'failed TryLoadFromYaml empty-key load does not partially apply new keys');

    LError := '';
    CheckEqual(False,
      LCfg.TryLoadFromYaml('shadow: new' + #10 + '"":' + #10 +
        '  nested: bad' + #10, LError),
      'TryLoadFromYaml rejects empty top-level container key');
    Check(Pos('empty', LError) > 0, 'TryLoadFromYaml empty container key error');
    CheckEqual(False, LCfg.Has('nested'), 'failed empty YAML container does not flatten into root');

    LError := '';
    CheckEqual(False,
      LCfg.TryLoadFromYaml('server:' + #10 + '  "": bad' + #10, LError),
      'TryLoadFromYaml rejects nested empty key segment');
    Check(Pos('empty', LError) > 0, 'TryLoadFromYaml nested empty key error');
    CheckEqual(False, LCfg.Has('server.'), 'failed nested empty YAML key does not publish trailing-dot key');
  finally
    LCfg.Free;
  end;
end;

procedure TestTomlEmptyTopLevelKeyRaises;
var
  LCfg: TConfig;
  LError: string;
  LRaised: Boolean;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('keep', 'old');
    LRaised := False;
    try
      LCfg.LoadFromToml(
        'shadow = "new"' + #10 +
        '"" = "bad"' + #10);
      Fail('TOML empty top-level key must be rejected');
    except
      on E: EConfigError do
      begin
        LRaised := True;
        Check(Pos('TOML', E.Message) > 0, 'empty toml key error names format');
        Check(Pos('empty', E.Message) > 0, 'empty toml key error names empty key');
      end;
    end;
    CheckEqual(True, LRaised, 'empty TOML key raises');
    CheckEqual('old', LCfg.GetString('keep'), 'failed TOML empty-key load preserves old value');
    CheckEqual(False, LCfg.Has('shadow'), 'failed TOML empty-key load does not partially apply new keys');

    LError := '';
    CheckEqual(False,
      LCfg.TryLoadFromToml('shadow = "new"' + #10 + '"" = "bad"' + #10, LError),
      'TryLoadFromToml rejects empty top-level key');
    Check(Pos('TOML', LError) > 0, 'TryLoadFromToml empty key error names format');
    Check(Pos('empty', LError) > 0, 'TryLoadFromToml empty key error names empty key');
    CheckEqual('old', LCfg.GetString('keep'), 'failed TryLoadFromToml empty-key load preserves old value');
    CheckEqual(False, LCfg.Has('shadow'), 'failed TryLoadFromToml empty-key load does not partially apply new keys');

    LError := '';
    CheckEqual(False,
      LCfg.TryLoadFromToml('shadow = "new"' + #10 +
        '"" = { nested = "bad" }' + #10, LError),
      'TryLoadFromToml rejects empty top-level container key');
    Check(Pos('empty', LError) > 0, 'TryLoadFromToml empty container key error');
    CheckEqual(False, LCfg.Has('nested'), 'failed empty TOML container does not flatten into root');

    LError := '';
    CheckEqual(False,
      LCfg.TryLoadFromToml('server = { "" = "bad" }' + #10, LError),
      'TryLoadFromToml rejects nested empty key segment');
    Check(Pos('empty', LError) > 0, 'TryLoadFromToml nested empty key error');
    CheckEqual(False, LCfg.Has('server.'), 'failed nested empty TOML key does not publish trailing-dot key');
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

procedure TestCrossSourceFlattenOverrideAfterSameSourceCollisionGuard;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"a.b":"json_literal","keep":"json_keep"}');
    CheckEqual('json_literal', LCfg.GetString('a.b'),
      'json literal dotted key loads');
    CheckEqual('json_keep', LCfg.GetString('keep'),
      'unrelated json key loads');

    LCfg.LoadFromYaml('a:' + #10 + '  b: yaml_nested' + #10);
    CheckEqual('yaml_nested', LCfg.GetString('a.b'),
      'later yaml nested path overrides earlier json literal key');
    CheckEqual('json_keep', LCfg.GetString('keep'),
      'later yaml load preserves unrelated keys');
    CheckEqual(Int64(2), Int64(LCfg.Count),
      'cross-source override keeps overridden and unrelated keys');

    LCfg.LoadFromToml('"a.b" = "toml_literal"' + #10);
    CheckEqual('toml_literal', LCfg.GetString('a.b'),
      'later toml literal key overrides same flattened key');
    CheckEqual('json_keep', LCfg.GetString('keep'),
      'later toml load preserves unrelated keys');
    CheckEqual(Int64(2), Int64(LCfg.Count),
      'toml override keeps overridden and unrelated keys');
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
  LKeys: TStringArray;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetDefault('tags.0', 'zero');
    LCfg.SetDefault('tags.01', 'literal-leading-zero');
    LCfg.SetDefault('tags.2', 'two');

    LItems := LCfg.GetStringArray('tags');
    CheckEqual(Int64(2), Int64(Length(LItems)),
      'leading-zero segment is not an array index');
    CheckEqual('zero', LItems[0], 'index 0 included');
    CheckEqual('two', LItems[1], 'index 2 included');

    LItems := LCfg.GetRawStringArray('tags');
    CheckEqual(Int64(2), Int64(Length(LItems)),
      'raw array ignores leading-zero segment');
    CheckEqual('zero', LItems[0], 'raw index 0 included');
    CheckEqual('two', LItems[1], 'raw index 2 included');

    LKeys := LCfg.GetSection('tags');
    CheckEqual(Int64(3), Int64(Length(LKeys)),
      'leading-zero segment remains a section child');
    CheckEqual('01', LKeys[1], 'section preserves literal leading-zero child');
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

    LItems := LCfg.GetRawStringArray('');
    CheckEqual(Int64(2), Int64(Length(LItems)), 'raw root array count');
    CheckEqual('x', LItems[0], 'raw root array 0');
    CheckEqual('y', LItems[1], 'raw root array 1');

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
        Check(Pos('JSON parse error', E.Message) > 0, 'json error message');
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
        Check(Pos('YAML parse error', E.Message) > 0, 'yaml error message');
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
        Check(Pos('TOML parse error', E.Message) > 0, 'toml error message');
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
  T := TTestSuite.Create('nextpas.core.config.nested');
  T.Test('Json.NestedObject', @TestJsonNestedObject);
  T.Test('Json.DeepNesting', @TestJsonDeepNesting);
  T.Test('Json.Array', @TestJsonArray);
  T.Test('Json.ArrayOfObjects', @TestJsonArrayOfObjects);
  T.Test('Json.EmptyContainers', @TestJsonEmptyContainers);
  T.Test('Json.ScalarFidelity', @TestJsonScalarFidelity);
  T.Test('Yaml.NestedMapping', @TestYamlNestedMapping);
  T.Test('Yaml.Sequence', @TestYamlSequence);
  T.Test('Yaml.DeepNesting', @TestYamlDeepNesting);
  T.Test('Yaml.SeqOfMapsWithNestedSeq', @TestYamlSeqOfMapsWithNestedSeq);
  T.Test('Yaml.LargeObjectArrayLinear', @TestYamlLargeObjectArrayLinear);
  T.Test('Toml.NestedTable', @TestTomlNestedTable);
  T.Test('Toml.Array', @TestTomlArray);
  T.Test('Toml.InlineTable', @TestTomlInlineTable);
  T.Test('Toml.DottedKey', @TestTomlDottedKey);
  T.Test('Toml.AmbiguousLiteralKeyVsTableRaises',
    @TestTomlAmbiguousLiteralKeyVsTableRaises);
  T.Test('Toml.AmbiguousLiteralKeyVsDottedKeyRaises',
    @TestTomlAmbiguousLiteralKeyVsDottedKeyRaises);
  T.Test('Toml.TryLoadAmbiguousReturnsFalse',
    @TestTomlTryLoadAmbiguousReturnsFalse);
  T.Test('Json.AmbiguousLiteralKeyVsNestedPathRaises',
    @TestJsonAmbiguousLiteralKeyVsNestedPathRaises);
  T.Test('Json.TryLoadAmbiguousReturnsFalse',
    @TestJsonTryLoadAmbiguousReturnsFalse);
  T.Test('Yaml.AmbiguousLiteralKeyVsNestedPathRaises',
    @TestYamlAmbiguousLiteralKeyVsNestedPathRaises);
  T.Test('Yaml.TryLoadAmbiguousReturnsFalse',
    @TestYamlTryLoadAmbiguousReturnsFalse);
  T.Test('Json.EmptyTopLevelKeyRaises', @TestJsonEmptyTopLevelKeyRaises);
  T.Test('Yaml.EmptyTopLevelKeyRaises', @TestYamlEmptyTopLevelKeyRaises);
  T.Test('Toml.EmptyTopLevelKeyRaises', @TestTomlEmptyTopLevelKeyRaises);
  T.Test('Toml.ArrayOfTables', @TestTomlArrayOfTables);
  T.Test('CrossFormat.NestedOverride', @TestCrossFormatNestedOverride);
  T.Test('CrossFormat.CrossSourceFlattenOverrideAfterCollisionGuard',
    @TestCrossSourceFlattenOverrideAfterSameSourceCollisionGuard);
  T.Test('Reload.Nested', @TestReloadNested);
  T.Test('Json.TopLevelArray', @TestJsonTopLevelArray);
  T.Test('Json.TopLevelScalar', @TestJsonTopLevelScalar);
  T.Test('Yaml.TopLevelSequence', @TestYamlTopLevelSequence);
  T.Test('GetSection.Root', @TestGetSectionRoot);
  T.Test('GetSection.PrefixDirectChildren', @TestGetSectionPrefixDirectChildren);
  T.Test('GetSection.ArrayIndexes', @TestGetSectionArrayIndexes);
  T.Test('GetSection.MissingAndCaseInsensitive', @TestGetSectionMissingAndCaseInsensitive);
  T.Test('GetStringArray.Basic', @TestGetStringArrayBasic);
  T.Test('GetStringArray.SparseNumericOrder', @TestGetStringArraySortsNumericIndexesAndSkipsHoles);
  T.Test('GetStringArray.IgnoresNonCanonicalNumericSegments',
    @TestGetStringArrayIgnoresNonCanonicalNumericSegments);
  T.Test('GetStringArray.IgnoresObjectArrayItems', @TestGetStringArrayIgnoresObjectArrayItems);
  T.Test('GetStringArray.TopLevelArrayAndMissing', @TestGetStringArrayTopLevelArrayAndMissing);
  T.Test('Malformed.LoadRaisesConfigError', @TestMalformedLoadRaisesConfigError);
  T.Test('Malformed.JsonLineColumn', @TestMalformedJsonErrorIncludesLineAndColumn);
  if not T.Run then Halt(1);
end.
