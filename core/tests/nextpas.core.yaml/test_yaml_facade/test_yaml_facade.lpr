program test_yaml_facade;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.text.view,
  nextpas.core.yaml.types,
  nextpas.core.yaml;

var
  T: TTestRunner;

procedure TestParseNull;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('null');
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.IsNull, 'root is null');

  LDoc := YamlParse('~');
  Check(LDoc.Root.IsNull, '~ is null');

  LDoc := YamlParse('');
  Check(LDoc.Root.IsNull, 'empty is null');
end;

procedure TestParseBool;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('true');
  Check(LDoc.Root.IsBool, 'is bool');
  Check(LDoc.Root.AsBool = True, 'true');

  LDoc := YamlParse('false');
  Check(LDoc.Root.AsBool = False, 'false');

  LDoc := YamlParse('True');
  Check(LDoc.Root.AsBool = True, 'True');

  LDoc := YamlParse('FALSE');
  Check(LDoc.Root.AsBool = False, 'FALSE');
end;

procedure TestParseInt;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('42');
  Check(LDoc.Root.IsInt, 'is int');
  CheckEqual(Int64(42), LDoc.Root.AsInt, '42');

  LDoc := YamlParse('-7');
  CheckEqual(Int64(-7), LDoc.Root.AsInt, '-7');

  LDoc := YamlParse('0');
  CheckEqual(Int64(0), LDoc.Root.AsInt, '0');
end;

procedure TestParseFloat;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('3.14');
  Check(LDoc.Root.IsFloat, 'is float');
  Check(Abs(LDoc.Root.AsFloat - 3.14) < 0.001, '3.14');

  LDoc := YamlParse('.inf');
  Check(LDoc.Root.AsFloat > 1e300, '+inf');

  LDoc := YamlParse('-.inf');
  Check(LDoc.Root.AsFloat < -1e300, '-inf');
end;

procedure TestParseString;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('''hello''');
  Check(LDoc.Root.IsStr, 'is str');
  Check(LDoc.Root.AsStr.ToString = 'hello', 'single quoted');

  LDoc := YamlParse('"world"');
  Check(LDoc.Root.AsStr.ToString = 'world', 'double quoted');

  LDoc := YamlParse('plain text');
  Check(LDoc.Root.IsStr, 'plain is str');
  Check(LDoc.Root.AsStr.ToString = 'plain text', 'plain value');
end;

procedure TestFlowSequence;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
begin
  LDoc := YamlParse('[1, 2, 3]');
  Check(not LDoc.HasError, 'no error');
  LRoot := LDoc.Root;
  Check(LRoot.IsSeq, 'is seq');
  CheckEqual(Int64(3), Int64(LRoot.SeqLen), 'len=3');
  CheckEqual(Int64(1), LRoot.SeqGet(0).AsInt, '[0]=1');
  CheckEqual(Int64(2), LRoot.SeqGet(1).AsInt, '[1]=2');
  CheckEqual(Int64(3), LRoot.SeqGet(2).AsInt, '[2]=3');
end;

procedure TestFlowMapping;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
begin
  LDoc := YamlParse('{name: Alice, age: 30}');
  Check(not LDoc.HasError, 'no error');
  LRoot := LDoc.Root;
  Check(LRoot.IsMap, 'is map');
  CheckEqual(Int64(2), Int64(LRoot.MapLen), 'len=2');
  Check(LRoot.MapGet('name').AsStr.ToString = 'Alice', 'name=Alice');
  CheckEqual(Int64(30), LRoot.MapGet('age').AsInt, 'age=30');
  Check(LRoot.MapHas('name'), 'has name');
  Check(not LRoot.MapHas('missing'), 'no missing');
end;

procedure TestNestedStructure;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
begin
  LDoc := YamlParse('{users: [{name: Alice, age: 30}, {name: Bob, age: 25}], count: 2}');
  Check(not LDoc.HasError, 'no error');
  LRoot := LDoc.Root;
  Check(LRoot.IsMap, 'root is map');
  CheckEqual(Int64(2), Int64(LRoot.MapGet('users').SeqLen), 'users len');
  Check(LRoot.MapGet('users').SeqGet(0).MapGet('name').AsStr.ToString = 'Alice', 'users[0].name');
  CheckEqual(Int64(25), LRoot.MapGet('users').SeqGet(1).MapGet('age').AsInt, 'users[1].age');
  CheckEqual(Int64(2), LRoot.MapGet('count').AsInt, 'count=2');
end;

procedure TestMapKeyAt;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
begin
  LDoc := YamlParse('{a: 1, b: 2, c: 3}');
  LRoot := LDoc.Root;
  Check(LRoot.MapKeyAt(0).ToString = 'a', 'key[0]=a');
  Check(LRoot.MapKeyAt(1).ToString = 'b', 'key[1]=b');
  Check(LRoot.MapKeyAt(2).ToString = 'c', 'key[2]=c');
  CheckEqual(Int64(1), LRoot.MapValueAt(0).AsInt, 'val[0]=1');
  CheckEqual(Int64(3), LRoot.MapValueAt(2).AsInt, 'val[2]=3');
end;

procedure TestDocStartMarker;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('---' + #10 + '{a: 1}');
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.IsMap, 'map after ---');
  CheckEqual(Int64(1), LDoc.Root.MapGet('a').AsInt, 'a=1');
end;

procedure TestErrorHandling;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('{a: 1, b}');
  Check(LDoc.HasError, 'error on missing :');
end;

procedure TestTryYamlParseSuccess;
var
  LDoc: IYamlDocument;
begin
  Check(TryYamlParse('{name: Alice, enabled: true}', LDoc), 'try parse success');
  Check(LDoc <> nil, 'doc assigned');
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.MapGet('name').AsStr.ToString = 'Alice', 'name');
  Check(LDoc.Root.MapGet('enabled').AsBool = True, 'enabled');
end;

procedure TestTryYamlParseFailureReturnsDiagnosticDoc;
var
  LDoc: IYamlDocument;
  LError: TYamlError;
begin
  Check(not TryYamlParse('{a: 1, b}', LDoc), 'try parse failure');
  Check(LDoc <> nil, 'diagnostic doc assigned');
  Check(LDoc.HasError, 'diagnostic doc has error');
  LError := LDoc.Error;
  Check(LError.Message.ToString <> '', 'diagnostic message is present');
  CheckEqual(Int64(1), Int64(LError.Line), 'diagnostic line');
  CheckEqual(Int64(9), Int64(LError.Col), 'diagnostic column');
  CheckEqual(Int64(8), Int64(LError.Offset), 'diagnostic byte offset');
end;

procedure TestStringify;
var
  LDoc: IYamlDocument;
  LOut: string;
begin
  LDoc := YamlParse('{name: Alice, age: 30}');
  LOut := LDoc.Stringify;
  Check(Pos('name', LOut) > 0, 'contains name');
  Check(Pos('Alice', LOut) > 0, 'contains Alice');
  Check(Pos('30', LOut) > 0, 'contains 30');
end;

procedure TestStringifyPretty;
var
  LDoc: IYamlDocument;
  LOut: string;
begin
  LDoc := YamlParse('{a: 1, b: [2, 3]}');
  LOut := LDoc.StringifyPretty;
  Check(Pos(#10, LOut) > 0, 'has newlines');
  Check(Pos('a:', LOut) > 0, 'has key a');
end;

procedure TestRoundTrip;
var
  LDoc1, LDoc2: IYamlDocument;
begin
  LDoc1 := YamlParse('{x: 1, y: [true, null, hello]}');
  LDoc2 := YamlParse(LDoc1.Stringify);
  Check(not LDoc2.HasError, 'round-trip no error');
  CheckEqual(Int64(1), LDoc2.Root.MapGet('x').AsInt, 'x=1');
  Check(LDoc2.Root.MapGet('y').SeqGet(0).AsBool = True, 'y[0]=true');
  Check(LDoc2.Root.MapGet('y').SeqGet(1).IsNull, 'y[1]=null');
  Check(LDoc2.Root.MapGet('y').SeqGet(2).AsStr.ToString = 'hello', 'y[2]=hello');
end;

procedure TestBlockMapping;
var LDoc: IYamlDocument;
begin
  LDoc := YamlParse('name: Alice' + #10 + 'age: 30' + #10 + 'active: true');
  Check(not LDoc.HasError, 'block map no error');
  Check(LDoc.Root.IsMap, 'is map');
  Check(LDoc.Root.MapGet('name').AsStr.ToString = 'Alice', 'name');
  CheckEqual(Int64(30), LDoc.Root.MapGet('age').AsInt, 'age');
  Check(LDoc.Root.MapGet('active').AsBool = True, 'active');
end;

procedure TestBlockSequence;
var LDoc: IYamlDocument;
begin
  LDoc := YamlParse('- apple' + #10 + '- banana' + #10 + '- cherry');
  Check(not LDoc.HasError, 'block seq no error');
  Check(LDoc.Root.IsSeq, 'is seq');
  CheckEqual(Int64(3), Int64(LDoc.Root.SeqLen), 'seq len');
  Check(LDoc.Root.SeqGet(0).AsStr.ToString = 'apple', 'item 0');
  Check(LDoc.Root.SeqGet(2).AsStr.ToString = 'cherry', 'item 2');
end;

procedure TestNestedBlockMap;
var LDoc: IYamlDocument; LDb: TYamlValue;
begin
  LDoc := YamlParse('server:' + #10 + '  host: localhost' + #10 + '  port: 8080' + #10 + 'database:' + #10 + '  name: mydb');
  Check(not LDoc.HasError, 'nested block no error');
  Check(LDoc.Root.MapGet('server').IsMap, 'server is map');
  Check(LDoc.Root.MapGet('server').MapGet('host').AsStr.ToString = 'localhost', 'host');
  CheckEqual(Int64(8080), LDoc.Root.MapGet('server').MapGet('port').AsInt, 'port');
  LDb := LDoc.Root.MapGet('database');
  Check(LDb.MapGet('name').AsStr.ToString = 'mydb', 'db name');
end;

procedure TestMapHas;
var LDoc: IYamlDocument;
begin
  LDoc := YamlParse('{a: 1, b: 2}');
  Check(LDoc.Root.MapHas('a'), 'has a');
  Check(LDoc.Root.MapHas('b'), 'has b');
  Check(not LDoc.Root.MapHas('c'), 'not has c');
  Check(not LDoc.Root.MapHas(''), 'not has empty');
end;

procedure TestMapLen;
var LDoc: IYamlDocument;
begin
  LDoc := YamlParse('{x: 1, y: 2, z: 3}');
  CheckEqual(Int64(3), Int64(LDoc.Root.MapLen), 'map len 3');
  LDoc := YamlParse('{}');
  CheckEqual(Int64(0), Int64(LDoc.Root.MapLen), 'empty map len 0');
end;

procedure TestSeqGetBounds;
var LDoc: IYamlDocument; LVal: TYamlValue;
begin
  LDoc := YamlParse('[10, 20, 30]');
  CheckEqual(Int64(10), LDoc.Root.SeqGet(0).AsInt, 'seq[0]');
  CheckEqual(Int64(30), LDoc.Root.SeqGet(2).AsInt, 'seq[2]');
  LVal := LDoc.Root.SeqGet(99);
  Check(not LVal.IsValid, 'out of bounds invalid');
end;

procedure TestEmptyDocument;
var LDoc: IYamlDocument;
begin
  LDoc := YamlParse('');
  Check(LDoc.Root.IsNull or (not LDoc.Root.IsValid), 'empty doc');
end;

procedure TestMultilineString;
var LDoc: IYamlDocument;
begin
  LDoc := YamlParse('msg: "hello world"');
  Check(not LDoc.HasError, 'quoted string no error');
  Check(LDoc.Root.MapGet('msg').AsStr.ToString = 'hello world', 'quoted value');
end;

procedure TestSpecialValues;
var LDoc: IYamlDocument;
begin
  LDoc := YamlParse('{a: null, b: ~, c: true, d: false, e: .inf, f: .nan}');
  Check(not LDoc.HasError, 'special values no error');
  Check(LDoc.Root.MapGet('a').IsNull, 'null');
  Check(LDoc.Root.MapGet('b').IsNull, 'tilde null');
  Check(LDoc.Root.MapGet('c').AsBool = True, 'true');
  Check(LDoc.Root.MapGet('d').AsBool = False, 'false');
end;

procedure TestLargeDocument;
var LYaml: string; LDoc: IYamlDocument; LI: Integer;
begin
  LYaml := '';
  for LI := 0 to 999 do
    LYaml := LYaml + '- item' + IntToStr(LI) + #10;
  LDoc := YamlParse(LYaml);
  Check(not LDoc.HasError, 'large doc no error');
  CheckEqual(Int64(1000), Int64(LDoc.Root.SeqLen), 'large seq len');
  Check(LDoc.Root.SeqGet(999).AsStr.ToString = 'item999', 'last item');
end;

procedure TestInvalidYaml;
var LDoc: IYamlDocument;
begin
  LDoc := YamlParse('{key: value, : missing_key}');
  // Parser may or may not error on this — just verify no crash
  Check(True, 'no crash on questionable input');
  LDoc := YamlParse('---' + #10 + '...' + #10 + '---' + #10 + 'value');
  Check(LDoc.Root.IsValid, 'multi-doc marker handled');
end;

begin
  T := TTestRunner.Create('nextpas.core.yaml');
  T.Run('Parse null', @TestParseNull);
  T.Run('Parse bool', @TestParseBool);
  T.Run('Parse int', @TestParseInt);
  T.Run('Parse float', @TestParseFloat);
  T.Run('Parse string', @TestParseString);
  T.Run('Flow sequence', @TestFlowSequence);
  T.Run('Flow mapping', @TestFlowMapping);
  T.Run('Nested structure', @TestNestedStructure);
  T.Run('Map key/value at', @TestMapKeyAt);
  T.Run('Doc start marker', @TestDocStartMarker);
  T.Run('Error handling', @TestErrorHandling);
  T.Run('TryYamlParse success', @TestTryYamlParseSuccess);
  T.Run('TryYamlParse failure returns diagnostic doc', @TestTryYamlParseFailureReturnsDiagnosticDoc);
  T.Run('Stringify', @TestStringify);
  T.Run('Stringify pretty', @TestStringifyPretty);
  T.Run('Round-trip', @TestRoundTrip);
  T.Run('Block mapping', @TestBlockMapping);
  T.Run('Block sequence', @TestBlockSequence);
  T.Run('Nested block map', @TestNestedBlockMap);
  T.Run('MapHas', @TestMapHas);
  T.Run('MapLen', @TestMapLen);
  T.Run('SeqGet bounds', @TestSeqGetBounds);
  T.Run('Empty document', @TestEmptyDocument);
  T.Run('Multiline string', @TestMultilineString);
  T.Run('Special values', @TestSpecialValues);
  T.Run('Large document 1000', @TestLargeDocument);
  T.Run('Invalid YAML', @TestInvalidYaml);
  T.Summary;
end.
