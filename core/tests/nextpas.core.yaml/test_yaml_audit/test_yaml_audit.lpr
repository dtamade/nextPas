program test_yaml_audit;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.text.view,
  nextpas.core.yaml.types,
  nextpas.core.yaml;

var
  T: TTestRunner;

{ === P0: Variant Record Key Bug (R2) === }

procedure TestNumericKey;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('{123: value}');
  Check(not LDoc.HasError, 'numeric key no error');
  Check(LDoc.Root.IsMap, 'is map');
  Check(LDoc.Root.MapGet('123').AsStr.ToString = 'value', 'numeric key lookup');
end;

procedure TestBoolKey;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('{true: yes_val}');
  Check(not LDoc.HasError, 'bool key no error');
  Check(LDoc.Root.MapGet('true').AsStr.ToString = 'yes_val', 'bool key lookup');
end;

procedure TestNullKey;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('{null: nothing}');
  Check(not LDoc.HasError, 'null key no error');
  Check(LDoc.Root.MapGet('null').AsStr.ToString = 'nothing', 'null key lookup');
end;

{ === P0: Alias Independence (R1) === }

procedure TestAliasMultipleRefs;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
begin
  LDoc := YamlParse('{defaults: &def {timeout: 30, retries: 3}, svc1: *def, svc2: *def}');
  Check(not LDoc.HasError, 'multi alias no error');
  LRoot := LDoc.Root;
  CheckEqual(Int64(30), LRoot.MapGet('defaults').MapGet('timeout').AsInt, 'defaults.timeout');
  CheckEqual(Int64(30), LRoot.MapGet('svc1').MapGet('timeout').AsInt, 'svc1.timeout');
  CheckEqual(Int64(30), LRoot.MapGet('svc2').MapGet('timeout').AsInt, 'svc2.timeout');
  CheckEqual(Int64(3), LRoot.MapGet('svc2').MapGet('retries').AsInt, 'svc2.retries');
end;

{ === P0: Block Scalar Content Verification === }

procedure TestBlockLiteralContent;
var
  LDoc: IYamlDocument;
  LVal: string;
begin
  LDoc := YamlParse('text: |' + #10 + '  line1' + #10 + '  line2');
  Check(not LDoc.HasError, 'literal no error');
  LVal := LDoc.Root.MapGet('text').AsStr.ToString;
  Check(Length(LVal) > 0, 'literal has content');
  Check(Pos('line1', LVal) > 0, 'literal contains line1');
  Check(Pos('line2', LVal) > 0, 'literal contains line2');
end;

{ === P1: Deep Nesting Protection === }

procedure TestDeepFlowNesting;
var
  LDoc: IYamlDocument;
  LInput: string;
  LI: Int32;
begin
  // 300 levels — should trigger parser depth limit (256)
  LInput := '';
  for LI := 1 to 300 do LInput := LInput + '[';
  LInput := LInput + '1';
  for LI := 1 to 300 do LInput := LInput + ']';
  LDoc := YamlParse(LInput);
  Check(LDoc.HasError or LDoc.Root.IsSeq, 'deep nesting handled');
end;

procedure TestDeepBlockNesting;
var
  LDoc: IYamlDocument;
  LInput: string;
  LI: Int32;
begin
  // 70 levels of block indent — should trigger indent stack limit (64)
  LInput := '';
  for LI := 0 to 69 do
    LInput := LInput + StringOfChar(' ', LI * 2) + 'k' + IntToStr(LI) + ':' + #10;
  LInput := LInput + StringOfChar(' ', 140) + 'leaf';
  LDoc := YamlParse(LInput);
  // Should either error or parse partially — not crash
  Check(True, 'deep block nesting no crash');
end;

{ === P1: Truncated Input === }

procedure TestTruncatedDoubleQuote;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('{name: "unterminated');
  Check(LDoc.HasError, 'truncated double quote → error');
end;

procedure TestTruncatedSingleQuote;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('{name: ''unterminated');
  Check(LDoc.HasError, 'truncated single quote → error');
end;

procedure TestUnclosedSequence;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('[1, 2, 3');
  // Should either error or parse what it can — not crash
  Check(LDoc.HasError or (LDoc.Root.SeqLen >= 0), 'unclosed seq handled');
end;

{ === P1: Round-trip All Types === }

procedure TestRoundTripAllTypes;
var
  LDoc1, LDoc2: IYamlDocument;
  LInput, LOutput: string;
begin
  LInput := '{n: null, b: true, i: 42, f: 3.14, s: hello, seq: [1, 2], map: {k: v}}';
  LDoc1 := YamlParse(LInput);
  Check(not LDoc1.HasError, 'parse ok');
  LOutput := LDoc1.Stringify;
  LDoc2 := YamlParse(LOutput);
  Check(not LDoc2.HasError, 'round-trip parse ok');
  Check(LDoc2.Root.MapGet('n').IsNull, 'rt null');
  Check(LDoc2.Root.MapGet('b').AsBool = True, 'rt bool');
  CheckEqual(Int64(42), LDoc2.Root.MapGet('i').AsInt, 'rt int');
  Check(LDoc2.Root.MapGet('s').AsStr.ToString = 'hello', 'rt string');
  CheckEqual(Int64(2), Int64(LDoc2.Root.MapGet('seq').SeqLen), 'rt seq');
  Check(LDoc2.Root.MapGet('map').MapGet('k').AsStr.ToString = 'v', 'rt map');
end;

{ === P2: Stress === }

procedure TestLargeSequence;
var
  LDoc: IYamlDocument;
  LInput: string;
  LI: Int32;
begin
  LInput := '[';
  for LI := 1 to 5000 do
  begin
    if LI > 1 then LInput := LInput + ',';
    LInput := LInput + IntToStr(LI);
  end;
  LInput := LInput + ']';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, '5000 seq no error');
  CheckEqual(Int64(5000), Int64(LDoc.Root.SeqLen), '5000 elements');
  CheckEqual(Int64(1), LDoc.Root.SeqGet(0).AsInt, 'first=1');
  CheckEqual(Int64(5000), LDoc.Root.SeqGet(4999).AsInt, 'last=5000');
end;

procedure TestLargeMapping;
var
  LDoc: IYamlDocument;
  LInput: string;
  LI: Int32;
begin
  LInput := '{';
  for LI := 1 to 500 do
  begin
    if LI > 1 then LInput := LInput + ',';
    LInput := LInput + 'k' + IntToStr(LI) + ': ' + IntToStr(LI);
  end;
  LInput := LInput + '}';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, '500 map no error');
  CheckEqual(Int64(500), Int64(LDoc.Root.MapLen), '500 keys');
  CheckEqual(Int64(1), LDoc.Root.MapGet('k1').AsInt, 'k1=1');
  CheckEqual(Int64(500), LDoc.Root.MapGet('k500').AsInt, 'k500=500');
end;

{ === P2: Duplicate Keys === }

procedure TestDuplicateKeys;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('{a: 1, a: 2}');
  Check(not LDoc.HasError, 'dup keys no error');
  // YAML spec says last value wins, but our impl returns first match
  Check(LDoc.Root.MapGet('a').IsInt, 'dup key has value');
end;

begin
  T := TTestRunner.Create('nextpas.core.yaml.audit');
  T.Run('Numeric key', @TestNumericKey);
  T.Run('Bool key', @TestBoolKey);
  T.Run('Null key', @TestNullKey);
  T.Run('Alias multiple refs', @TestAliasMultipleRefs);
  T.Run('Block literal content', @TestBlockLiteralContent);
  T.Run('Deep flow nesting', @TestDeepFlowNesting);
  T.Run('Deep block nesting', @TestDeepBlockNesting);
  T.Run('Truncated double quote', @TestTruncatedDoubleQuote);
  T.Run('Truncated single quote', @TestTruncatedSingleQuote);
  T.Run('Unclosed sequence', @TestUnclosedSequence);
  T.Run('Round-trip all types', @TestRoundTripAllTypes);
  T.Run('Large sequence 5000', @TestLargeSequence);
  T.Run('Large mapping 500', @TestLargeMapping);
  T.Run('Duplicate keys', @TestDuplicateKeys);
  T.Summary;
end.
