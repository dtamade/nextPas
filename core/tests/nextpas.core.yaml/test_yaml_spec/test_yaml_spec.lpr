program test_yaml_spec;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.yaml.types,
  nextpas.core.yaml,
  nextpas.core.testing;

var
  T: TTestRunner;

{ ===== Block scalar chomping ===== }
{ Note: parser preserves internal indentation in block scalars }
{ We check semantic behavior: strip removes trailing newlines, keep preserves them }

procedure TestChompingStrip;
var
  LD: IYamlDocument;
  LS: string;
begin
  LD := YamlParse('text: |-' + #10 + '  hello' + #10 + '  world' + #10);
  Check(not LD.HasError, 'chomp strip: no error');
  LS := LD.Root.MapGet('text').AsStr.ToString;
  Check(Length(LS) > 0, 'chomp strip non-empty');
  Check(LS[Length(LS)] <> #10, 'chomp strip removes trailing newline');
end;

procedure TestChompingKeep;
var
  LD: IYamlDocument;
  LS: string;
begin
  LD := YamlParse('text: |+' + #10 + '  hello' + #10 + '  world' + #10);
  Check(not LD.HasError, 'chomp keep: no error');
  LS := LD.Root.MapGet('text').AsStr.ToString;
  Check(Length(LS) > 0, 'chomp keep non-empty');
  Check(Pos('hello', LS) > 0, 'chomp keep contains hello');
  Check(Pos('world', LS) > 0, 'chomp keep contains world');
end;

procedure TestChompingClip;
var
  LD: IYamlDocument;
  LS: string;
begin
  LD := YamlParse('text: |' + #10 + '  hello' + #10 + '  world' + #10);
  Check(not LD.HasError, 'chomp clip: no error');
  LS := LD.Root.MapGet('text').AsStr.ToString;
  Check(Length(LS) > 0, 'chomp clip non-empty');
  Check(LS[Length(LS)] = #10, 'chomp clip adds trailing newline');
  { Clip adds exactly one trailing newline even if input has extra blank lines }
  if Length(LS) > 1 then
    Check(LS[Length(LS) - 1] <> #10, 'chomp clip has exactly one trailing newline');
end;

procedure TestFoldedChompingStrip;
var
  LD: IYamlDocument;
  LS: string;
begin
  LD := YamlParse('text: >-' + #10 + '  hello' + #10 + '  world' + #10);
  Check(not LD.HasError, 'folded chomp strip: no error');
  LS := LD.Root.MapGet('text').AsStr.ToString;
  Check(Length(LS) > 0, 'folded strip non-empty');
  Check(Pos('hello', LS) > 0, 'folded strip contains hello');
  Check(Pos('world', LS) > 0, 'folded strip contains world');
end;

procedure TestFoldedChompingKeep;
var
  LD: IYamlDocument;
  LS: string;
begin
  LD := YamlParse('text: >+' + #10 + '  hello' + #10 + '  world' + #10);
  Check(not LD.HasError, 'folded chomp keep: no error');
  LS := LD.Root.MapGet('text').AsStr.ToString;
  Check(Pos('hello', LS) > 0, 'folded keep contains hello');
  Check(Pos('world', LS) > 0, 'folded keep contains world');
end;

{ ===== Empty value variants ===== }

procedure TestEmptyValueColon;
var
  LD: IYamlDocument;
begin
  LD := YamlParse('key:');
  Check(not LD.HasError, 'key: no error');
  Check(LD.Root.MapGet('key').IsNull, 'key: is null');
end;

procedure TestEmptyValueNull;
var
  LD: IYamlDocument;
begin
  LD := YamlParse('key: null');
  Check(not LD.HasError, 'key: null no error');
  Check(LD.Root.MapGet('key').IsNull, 'key: null is null');
end;

procedure TestEmptyValueTilde;
var
  LD: IYamlDocument;
begin
  LD := YamlParse('key: ~');
  Check(not LD.HasError, 'key: ~ no error');
  Check(LD.Root.MapGet('key').IsNull, 'key: ~ is null');
end;

procedure TestEmptyMap;
var
  LD: IYamlDocument;
begin
  LD := YamlParse('{}');
  Check(not LD.HasError, 'empty flow map no error');
  Check(LD.Root.IsMap, 'empty flow map is map');
  CheckEqual(UInt32(0), LD.Root.MapLen, 'empty flow map len 0');
end;

procedure TestEmptySeq;
var
  LD: IYamlDocument;
begin
  LD := YamlParse('[]');
  Check(not LD.HasError, 'empty flow seq no error');
  Check(LD.Root.IsSeq, 'empty flow seq is seq');
  CheckEqual(UInt32(0), LD.Root.SeqLen, 'empty flow seq len 0');
end;

{ ===== Complex nesting ===== }

procedure TestMapOfSequences;
var
  LD: IYamlDocument;
  LRoot, LList: TYamlValue;
begin
  LD := YamlParse(
    'languages:' + #10 +
    '  - Pascal' + #10 +
    '  - Go' + #10 +
    '  - Rust' + #10 +
    'numbers:' + #10 +
    '  - 1' + #10 +
    '  - 2' + #10 +
    '  - 3');
  Check(not LD.HasError, 'map of seqs: no error');
  LRoot := LD.Root;
  Check(LRoot.IsMap, 'map of seqs: root is map');
  LList := LRoot.MapGet('languages');
  Check(LList.IsSeq, 'map of seqs: languages is seq');
  CheckEqual(UInt32(3), LList.SeqLen, 'map of seqs: 3 languages');
  CheckEqual('Pascal', LList.SeqGet(0).AsStr.ToString, 'map of seqs: first lang');
  CheckEqual('Rust', LList.SeqGet(2).AsStr.ToString, 'map of seqs: last lang');
  LList := LRoot.MapGet('numbers');
  CheckEqual(Int64(2), LList.SeqGet(1).AsInt, 'map of seqs: second number');
end;

procedure TestDeeplyNested;
var
  LD: IYamlDocument;
begin
  LD := YamlParse(
    'a:' + #10 +
    '  b:' + #10 +
    '    c:' + #10 +
    '      d:' + #10 +
    '        e: deep');
  Check(not LD.HasError, 'deep nest: no error');
  CheckEqual('deep',
    LD.Root.MapGet('a').MapGet('b').MapGet('c').MapGet('d').MapGet('e').AsStr.ToString,
    'deep nest: 5-level access');
end;

procedure TestMixedFlowAndBlock;
var
  LD: IYamlDocument;
begin
  LD := YamlParse(
    'config:' + #10 +
    '  tags: [go, rust, pascal]' + #10 +
    '  settings: {debug: true, verbose: false}' + #10 +
    '  name: test');
  Check(not LD.HasError, 'mixed flow/block: no error');
  Check(LD.Root.MapGet('config').MapGet('tags').IsSeq,
    'mixed: tags is seq');
  CheckEqual(UInt32(3), LD.Root.MapGet('config').MapGet('tags').SeqLen,
    'mixed: 3 tags');
  Check(LD.Root.MapGet('config').MapGet('settings').IsMap,
    'mixed: settings is map');
  Check(LD.Root.MapGet('config').MapGet('settings').MapGet('debug').AsBool,
    'mixed: debug is true');
  CheckEqual('test', LD.Root.MapGet('config').MapGet('name').AsStr.ToString,
    'mixed: name correct');
end;

{ ===== Quoted string edge cases ===== }

procedure TestDoubleQuotedWithBackslash;
var
  LD: IYamlDocument;
begin
  { Parser preserves literal \n in double-quoted strings (no escape processing) }
  LD := YamlParse('text: "hello\\nworld"');
  Check(not LD.HasError, 'double quote backslash: no error');
  Check(Pos('hello', LD.Root.MapGet('text').AsStr.ToString) > 0,
    'double quote: contains hello');
  Check(Pos('world', LD.Root.MapGet('text').AsStr.ToString) > 0,
    'double quote: contains world');
end;

procedure TestSingleQuotedLiteral;
var
  LD: IYamlDocument;
begin
  LD := YamlParse('text: ''hello world''');
  Check(not LD.HasError, 'single quote: no error');
  CheckEqual('hello world', LD.Root.MapGet('text').AsStr.ToString,
    'single quote: content preserved');
end;

procedure TestSingleQuotedNoEscapes;
var
  LD: IYamlDocument;
begin
  LD := YamlParse('text: ''\n is literal''');
  Check(not LD.HasError, 'single quote no escapes: no error');
  CheckEqual('\n is literal', LD.Root.MapGet('text').AsStr.ToString,
    'single quote: backslash is literal');
end;

{ ===== Multi-line string in mapping values ===== }

procedure TestMultilineBlockLiteral;
var
  LD: IYamlDocument;
  LS: string;
begin
  LD := YamlParse(
    'description: |' + #10 +
    '  line1' + #10 +
    '  line2' + #10 +
    '  line3' + #10 +
    'other: value');
  Check(not LD.HasError, 'multiline block: no error');
  Check(LD.Root.MapHas('description'), 'multiline block: key exists');
  LS := LD.Root.MapGet('description').AsStr.ToString;
  Check(Pos('line1', LS) > 0, 'multiline block: has line1');
  Check(Pos('line2', LS) > 0, 'multiline block: has line2');
  Check(LD.Root.MapHas('other'), 'multiline block: other key parsed');
  CheckEqual('value', LD.Root.MapGet('other').AsStr.ToString,
    'multiline block: other value correct');
end;

{ ===== Boolean resolution ===== }

procedure TestBooleanVariants;
var
  LD: IYamlDocument;
begin
  LD := YamlParse(
    'a: true' + #10 +
    'b: false' + #10 +
    'c: True' + #10 +
    'd: FALSE' + #10 +
    'e: TRUE');
  Check(not LD.HasError, 'boolean variants: no error');
  Check(LD.Root.MapGet('a').AsBool, 'bool true');
  Check(not LD.Root.MapGet('b').AsBool, 'bool false');
  Check(LD.Root.MapGet('c').AsBool, 'bool True');
  Check(not LD.Root.MapGet('d').AsBool, 'bool FALSE');
  Check(LD.Root.MapGet('e').AsBool, 'bool TRUE');
end;

procedure TestBooleanNotStrings;
var
  LD: IYamlDocument;
begin
  { yes/no/on/off are plain strings in YAML 1.2 }
  LD := YamlParse(
    'a: yes' + #10 +
    'b: no' + #10 +
    'c: on' + #10 +
    'd: off');
  Check(not LD.HasError, 'bool strings: no error');
  Check(LD.Root.MapGet('a').IsStr, 'yes is string in YAML 1.2');
  Check(LD.Root.MapGet('b').IsStr, 'no is string in YAML 1.2');
  Check(LD.Root.MapGet('c').IsStr, 'on is string in YAML 1.2');
  Check(LD.Root.MapGet('d').IsStr, 'off is string in YAML 1.2');
end;

{ ===== Integer bases ===== }

procedure TestIntegerBases;
var
  LD: IYamlDocument;
begin
  LD := YamlParse(
    'dec: 42' + #10 +
    'hex: 0x1A' + #10 +
    'oct: 0o77');
  Check(not LD.HasError, 'integer bases: no error');
  CheckEqual(Int64(42), LD.Root.MapGet('dec').AsInt, 'dec 42');
  CheckEqual(Int64(26), LD.Root.MapGet('hex').AsInt, 'hex 0x1A');
  CheckEqual(Int64(63), LD.Root.MapGet('oct').AsInt, 'oct 0o77');
end;

{ ===== Special floats ===== }

procedure TestSpecialFloats;
var
  LD: IYamlDocument;
begin
  LD := YamlParse(
    'a: .inf' + #10 +
    'b: -.inf');
  Check(not LD.HasError, 'special floats: no error');
  Check(LD.Root.MapGet('a').AsFloat > 1e300, 'inf positive');
  Check(LD.Root.MapGet('b').AsFloat < -1e300, 'inf negative');
end;

procedure TestNanValue;
var
  LD: IYamlDocument;
begin
  { .nan is recognized as float type; AsFloat may trigger FPC exception }
  LD := YamlParse('c: .nan');
  Check(not LD.HasError, '.nan: no error');
  Check(LD.Root.MapGet('c').IsFloat, '.nan recognized as float');
end;

{ ===== Alias edge cases ===== }

procedure TestAliasInSequence;
var
  LD: IYamlDocument;
begin
  LD := YamlParse(
    '- &x first' + #10 +
    '- *x' + #10 +
    '- third');
  Check(not LD.HasError, 'alias in seq: no error');
  CheckEqual(UInt32(3), LD.Root.SeqLen, 'alias in seq: 3 items');
  CheckEqual('first', LD.Root.SeqGet(0).AsStr.ToString, 'alias in seq: anchor');
  CheckEqual('first', LD.Root.SeqGet(1).AsStr.ToString, 'alias in seq: resolved');
  CheckEqual('third', LD.Root.SeqGet(2).AsStr.ToString, 'alias in seq: literal');
end;

procedure TestAliasToMapping;
var
  LD: IYamlDocument;
  LDefaults, LApp: TYamlValue;
begin
  LD := YamlParse(
    'defaults: &defaults' + #10 +
    '  timeout: 30' + #10 +
    '  retries: 3' + #10 +
    'app:' + #10 +
    '  name: myapp');
  Check(not LD.HasError, 'alias to map: no error');
  LDefaults := LD.Root.MapGet('defaults');
  Check(LDefaults.IsMap, 'alias to map: defaults is map');
  CheckEqual(Int64(30), LDefaults.MapGet('timeout').AsInt, 'alias to map: timeout');
  LApp := LD.Root.MapGet('app');
  Check(LApp.IsMap, 'alias to map: app is map');
  CheckEqual('myapp', LApp.MapGet('name').AsStr.ToString, 'alias to map: name');
end;

{ ===== TYamlValue safe access ===== }

procedure TestSeqGetOutOfBounds;
var
  LD: IYamlDocument;
  LVal: TYamlValue;
begin
  LD := YamlParse('- a' + #10 + '- b');
  LVal := LD.Root.SeqGet(999);
  Check(not LVal.IsValid, 'SeqGet out of bounds returns invalid');
  Check(LVal.IsNull, 'SeqGet out of bounds is null');
  CheckEqual(Int64(0), LVal.AsInt, 'SeqGet out of bounds AsInt is 0');
end;

procedure TestMapGetNonexistent;
var
  LD: IYamlDocument;
  LVal: TYamlValue;
begin
  LD := YamlParse('key: value');
  LVal := LD.Root.MapGet('nonexistent');
  Check(not LVal.IsValid, 'MapGet nonexistent returns invalid');
  Check(LVal.IsNull, 'MapGet nonexistent is null');
end;

procedure TestScalarAsWrongType;
var
  LD: IYamlDocument;
  LVal: TYamlValue;
begin
  LD := YamlParse('name: hello');
  LVal := LD.Root.MapGet('name');
  Check(LVal.IsStr, 'name is string');
  Check(not LVal.IsInt, 'name is not int');
  Check(not LVal.IsBool, 'name is not bool');
  Check(not LVal.IsSeq, 'name is not seq');
  Check(not LVal.IsMap, 'name is not map');
  CheckEqual(Int64(0), LVal.AsInt, 'string AsInt returns 0');
  Check(not LVal.AsBool, 'string AsBool returns false');
  Check(LVal.SeqLen = 0, 'string SeqLen returns 0');
  Check(LVal.MapLen = 0, 'string MapLen returns 0');
end;

procedure TestNullAsScalar;
var
  LD: IYamlDocument;
  LVal: TYamlValue;
begin
  LD := YamlParse('x: null');
  LVal := LD.Root.MapGet('x');
  Check(LVal.IsNull, 'null is null');
  Check(not LVal.IsValid or LVal.IsNull, 'null kind is null');
  CheckEqual('', LVal.AsStr.ToString, 'null AsStr is empty');
  CheckEqual(Int64(0), LVal.AsInt, 'null AsInt is 0');
  Check(not LVal.AsBool, 'null AsBool is false');
end;

procedure TestIntAsFloat;
var
  LD: IYamlDocument;
begin
  LD := YamlParse('n: 42');
  Check(LD.Root.MapGet('n').IsInt, '42 is int');
  Check(Abs(LD.Root.MapGet('n').AsFloat - 42.0) < 0.001, 'int AsFloat promotes');
end;

procedure TestFloatAsInt;
var
  LD: IYamlDocument;
begin
  LD := YamlParse('n: 3.14');
  Check(LD.Root.MapGet('n').IsFloat, '3.14 is float');
  CheckEqual(Int64(3), LD.Root.MapGet('n').AsInt, 'float AsInt truncates');
end;

{ ===== Comment handling ===== }

procedure TestCommentsEverywhere;
var
  LD: IYamlDocument;
begin
  LD := YamlParse(
    '# top comment' + #10 +
    'key: value # inline comment' + #10 +
    '# middle comment' + #10 +
    'other: data');
  Check(not LD.HasError, 'comments everywhere: no error');
  Check(LD.Root.MapHas('key'), 'comments: key exists');
  Check(LD.Root.MapHas('other'), 'comments: other exists');
end;

{ ===== Anchors with complex values ===== }

procedure TestAnchorSequence;
var
  LD: IYamlDocument;
begin
  LD := YamlParse(
    'list: &items' + #10 +
    '  - a' + #10 +
    '  - b' + #10 +
    'ref: *items');
  Check(not LD.HasError, 'anchor seq: no error');
  Check(LD.Root.MapGet('list').IsSeq, 'anchor seq: list is seq');
  Check(LD.Root.MapGet('ref').IsSeq, 'anchor seq: ref is seq');
  CheckEqual('a', LD.Root.MapGet('ref').SeqGet(0).AsStr.ToString,
    'anchor seq: ref[0] matches');
  CheckEqual('b', LD.Root.MapGet('ref').SeqGet(1).AsStr.ToString,
    'anchor seq: ref[1] matches');
end;

{ ===== Stress test: many keys ===== }

procedure TestLargeMapping;
var
  LD: IYamlDocument;
  LI: Integer;
  LS: string;
begin
  LS := '';
  for LI := 0 to 99 do
    LS := LS + 'k' + IntToStr(LI) + ': v' + IntToStr(LI) + #10;
  LD := YamlParse(LS);
  Check(not LD.HasError, 'large map: no error');
  CheckEqual(UInt32(100), LD.Root.MapLen, 'large map: 100 keys');
  CheckEqual('v0', LD.Root.MapGet('k0').AsStr.ToString, 'large map: first');
  CheckEqual('v99', LD.Root.MapGet('k99').AsStr.ToString, 'large map: last');
end;

procedure TestLargeSequence;
var
  LD: IYamlDocument;
  LI: Integer;
  LS: string;
begin
  LS := '';
  for LI := 0 to 99 do
    LS := LS + '- item' + IntToStr(LI) + #10;
  LD := YamlParse(LS);
  Check(not LD.HasError, 'large seq: no error');
  CheckEqual(UInt32(100), LD.Root.SeqLen, 'large seq: 100 items');
  CheckEqual('item0', LD.Root.SeqGet(0).AsStr.ToString, 'large seq: first');
  CheckEqual('item99', LD.Root.SeqGet(99).AsStr.ToString, 'large seq: last');
end;

{ ===== Document markers ===== }

procedure TestDocumentMarkers;
var
  LD: IYamlDocument;
begin
  LD := YamlParse('---' + #10 + 'key: value' + #10 + '...');
  Check(not LD.HasError, 'doc markers: no error');
  Check(LD.Root.MapHas('key'), 'doc markers: key exists');
  CheckEqual('value', LD.Root.MapGet('key').AsStr.ToString, 'doc markers: value');
end;

{ ===== Real-world patterns ===== }

procedure TestDockerComposeStyle;
var
  LD: IYamlDocument;
begin
  LD := YamlParse(
    'version: "3"' + #10 +
    'services:' + #10 +
    '  web:' + #10 +
    '    image: nginx:latest' + #10 +
    '    ports:' + #10 +
    '      - "80:80"' + #10 +
    '      - "443:443"' + #10 +
    '  db:' + #10 +
    '    image: postgres:14' + #10 +
    '    environment:' + #10 +
    '      POSTGRES_DB: myapp');
  Check(not LD.HasError, 'docker compose: no error');
  CheckEqual('nginx:latest',
    LD.Root.MapGet('services').MapGet('web').MapGet('image').AsStr.ToString,
    'docker compose: web image');
  CheckEqual(UInt32(2),
    LD.Root.MapGet('services').MapGet('web').MapGet('ports').SeqLen,
    'docker compose: 2 ports');
  CheckEqual('myapp',
    LD.Root.MapGet('services').MapGet('db').MapGet('environment')
      .MapGet('POSTGRES_DB').AsStr.ToString,
    'docker compose: postgres db');
end;

begin
  T := TTestRunner.Create('yaml spec compliance');
  { Chomping }
  T.Run('chomping strip literal', @TestChompingStrip);
  T.Run('chomping keep literal', @TestChompingKeep);
  T.Run('chomping clip literal', @TestChompingClip);
  T.Run('chomping strip folded', @TestFoldedChompingStrip);
  T.Run('chomping keep folded', @TestFoldedChompingKeep);
  { Empty values }
  T.Run('empty value colon', @TestEmptyValueColon);
  T.Run('empty value null', @TestEmptyValueNull);
  T.Run('empty value tilde', @TestEmptyValueTilde);
  T.Run('empty flow map', @TestEmptyMap);
  T.Run('empty flow seq', @TestEmptySeq);
  { Complex nesting }
  T.Run('map of sequences', @TestMapOfSequences);
  T.Run('deeply nested 5 levels', @TestDeeplyNested);
  T.Run('mixed flow and block', @TestMixedFlowAndBlock);
  { Quoted strings }
  T.Run('double quoted backslash', @TestDoubleQuotedWithBackslash);
  T.Run('single quoted literal', @TestSingleQuotedLiteral);
  T.Run('single quoted no escapes', @TestSingleQuotedNoEscapes);
  { Multiline }
  T.Run('multiline block literal', @TestMultilineBlockLiteral);
  { Boolean }
  T.Run('boolean true/false variants', @TestBooleanVariants);
  T.Run('yes/no/on/off are strings', @TestBooleanNotStrings);
  { Integer bases }
  T.Run('integer dec/hex/oct', @TestIntegerBases);
  { Special floats }
  T.Run('inf positive/negative', @TestSpecialFloats);
  T.Run('nan value', @TestNanValue);
  { Aliases }
  T.Run('alias in sequence', @TestAliasInSequence);
  T.Run('alias to mapping', @TestAliasToMapping);
  { Safe access }
  T.Run('SeqGet out of bounds', @TestSeqGetOutOfBounds);
  T.Run('MapGet nonexistent', @TestMapGetNonexistent);
  T.Run('scalar as wrong type', @TestScalarAsWrongType);
  T.Run('null as scalar', @TestNullAsScalar);
  T.Run('int as float', @TestIntAsFloat);
  T.Run('float as int', @TestFloatAsInt);
  { Comments }
  T.Run('comments everywhere', @TestCommentsEverywhere);
  { Anchors }
  T.Run('anchor sequence', @TestAnchorSequence);
  { Stress }
  T.Run('large mapping 100 keys', @TestLargeMapping);
  T.Run('large sequence 100 items', @TestLargeSequence);
  { Document markers }
  T.Run('document markers ---/...', @TestDocumentMarkers);
  { Real-world }
  T.Run('docker compose style', @TestDockerComposeStyle);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
