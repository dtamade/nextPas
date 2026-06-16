program test_yaml_facade;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.text.view,
  nextpas.core.errors,
  nextpas.core.yaml.types,
  nextpas.core.yaml;

var
  T: TTestRunner;

function BuildAliasChainDocument(const AAliasDepth: Integer): string;
var
  LI: Integer;
begin
  Result := 'v0: &a0 base' + #10;
  for LI := 1 to AAliasDepth do
    Result := Result +
      'v' + IntToStr(LI) +
      ': &a' + IntToStr(LI) +
      ' *a' + IntToStr(LI - 1) + #10;
end;

function BuildDeepFlowSequenceDocument(const ADepth: Integer): string;
var
  LI: Integer;
begin
  Result := '';
  for LI := 1 to ADepth do
    Result := Result + '[';
  Result := Result + '1';
  for LI := 1 to ADepth do
    Result := Result + ']';
end;

function BuildDeepBlockMappingDocument(const ADepth: Integer): string;
var
  LI: Integer;
begin
  Result := '';
  for LI := 0 to ADepth - 1 do
    Result := Result + StringOfChar(' ', LI * 2) + 'k' + IntToStr(LI) + ':' + #10;
  Result := Result + StringOfChar(' ', ADepth * 2) + 'leaf';
end;

function BuildDeepBlockSequenceDocument(const ADepth: Integer): string;
var
  LI: Integer;
begin
  Result := '';
  for LI := 0 to ADepth - 1 do
    Result := Result + StringOfChar(' ', LI * 2) + '- ' + #10;
  Result := Result + StringOfChar(' ', ADepth * 2) + 'leaf';
end;

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

procedure TestDocEndMarker;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('---' + #10 + '{a: 1}' + #10 + '...');
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.IsMap, 'map before ...');
  CheckEqual(Int64(1), LDoc.Root.MapGet('a').AsInt, 'a=1');

  LDoc := YamlParse('{a: 1}' + #10 + '...');
  Check(not LDoc.HasError, 'plain doc end marker has no error');
  Check(LDoc.Root.IsMap, 'plain map before ...');
  CheckEqual(Int64(1), LDoc.Root.MapGet('a').AsInt, 'plain a=1');
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

procedure TestTryYamlParseRejectsStrayFlowClosers;
var
  LDoc: IYamlDocument;
  LError: TYamlError;
begin
  Check(not TryYamlParse('}', LDoc), 'TryYamlParse rejects stray }');
  Check(LDoc <> nil, 'stray } diagnostic doc assigned');
  Check(LDoc.HasError, 'stray } diagnostic doc has error');
  LError := LDoc.Error;
  Check(Pos('unexpected', LError.Message.ToString) > 0,
    'stray } diagnostic names unexpected token');
  CheckEqual(Int64(1), Int64(LError.Line), 'stray } line');
  CheckEqual(Int64(1), Int64(LError.Col), 'stray } column');
  CheckEqual(Int64(0), Int64(LError.Offset), 'stray } offset');

  Check(not TryYamlParse(']', LDoc), 'TryYamlParse rejects stray ]');
  Check(LDoc <> nil, 'stray ] diagnostic doc assigned');
  Check(LDoc.HasError, 'stray ] diagnostic doc has error');
  LError := LDoc.Error;
  Check(Pos('unexpected', LError.Message.ToString) > 0,
    'stray ] diagnostic names unexpected token');
  CheckEqual(Int64(1), Int64(LError.Line), 'stray ] line');
  CheckEqual(Int64(1), Int64(LError.Col), 'stray ] column');
  CheckEqual(Int64(0), Int64(LError.Offset), 'stray ] offset');
end;

procedure TestTryYamlParseRejectsTrailingDocumentContent;
var
  LDoc: IYamlDocument;
  LError: TYamlError;
begin
  Check(not TryYamlParse('{a: 1} trailing', LDoc),
    'TryYamlParse rejects trailing content after flow document');
  Check(LDoc <> nil, 'trailing-content diagnostic doc assigned');
  Check(LDoc.HasError, 'trailing-content diagnostic doc has error');
  LError := LDoc.Error;
  Check(Pos('unexpected content after YAML document', LError.Message.ToString) > 0,
    'trailing-content diagnostic names unexpected tail');
  CheckEqual(Int64(1), Int64(LError.Line), 'trailing-content error line');
  CheckEqual(Int64(8), Int64(LError.Col), 'trailing-content error column');
  CheckEqual(Int64(7), Int64(LError.Offset), 'trailing-content byte offset');
end;

procedure TestTryYamlParseRejectsMissingValueSeparator;
var
  LDoc: IYamlDocument;
  LError: TYamlError;
begin
  Check(not TryYamlParse('{a 1}', LDoc),
    'TryYamlParse rejects flow mapping without value separator');
  Check(LDoc <> nil, 'missing-colon diagnostic doc assigned');
  Check(LDoc.HasError, 'missing-colon diagnostic doc has error');
  LError := LDoc.Error;
  Check(Pos('expected ":"', LError.Message.ToString) > 0,
    'missing-colon diagnostic names expected separator');
  CheckEqual(Int64(1), Int64(LError.Line), 'missing-colon error line');
  CheckEqual(Int64(5), Int64(LError.Col), 'missing-colon error column');
  CheckEqual(Int64(4), Int64(LError.Offset), 'missing-colon byte offset');
end;

procedure TestTryYamlParseRejectsMissingMappingKey;
var
  LDoc: IYamlDocument;
  LError: TYamlError;
begin
  Check(not TryYamlParse('{a: 1, : 2}', LDoc),
    'TryYamlParse rejects flow mapping without a key');
  Check(LDoc <> nil, 'missing-key diagnostic doc assigned');
  Check(LDoc.HasError, 'missing-key diagnostic doc has error');
  LError := LDoc.Error;
  Check(Pos('expected mapping key', LError.Message.ToString) > 0,
    'missing-key diagnostic names expected key');
  CheckEqual(Int64(1), Int64(LError.Line), 'missing-key error line');
  CheckEqual(Int64(8), Int64(LError.Col), 'missing-key error column');
  CheckEqual(Int64(7), Int64(LError.Offset), 'missing-key byte offset');
end;

procedure TestTryYamlParseRejectsBlockMappingEntryWithoutKey;
var
  LDoc: IYamlDocument;
  LError: TYamlError;
begin
  Check(not TryYamlParse(': 2', LDoc),
    'TryYamlParse rejects top-level block mapping entry without a key');
  Check(LDoc <> nil, 'top-level block missing-key diagnostic doc assigned');
  Check(LDoc.HasError, 'top-level block missing-key diagnostic doc has error');
  LError := LDoc.Error;
  Check(Pos('expected mapping key', LError.Message.ToString) > 0,
    'top-level block missing-key diagnostic names expected key');
  CheckEqual(Int64(1), Int64(LError.Line), 'top-level block missing-key error line');
  CheckEqual(Int64(1), Int64(LError.Col), 'top-level block missing-key error column');
  CheckEqual(Int64(0), Int64(LError.Offset), 'top-level block missing-key byte offset');

  Check(not TryYamlParse('a: 1' + #10 + ': 2', LDoc),
    'TryYamlParse rejects continued block mapping entry without a key');
  Check(LDoc <> nil, 'continued block missing-key diagnostic doc assigned');
  Check(LDoc.HasError, 'continued block missing-key diagnostic doc has error');
  LError := LDoc.Error;
  Check(Pos('expected mapping key', LError.Message.ToString) > 0,
    'continued block missing-key diagnostic names expected key');
  CheckEqual(Int64(2), Int64(LError.Line), 'continued block missing-key error line');
  CheckEqual(Int64(1), Int64(LError.Col), 'continued block missing-key error column');
  CheckEqual(Int64(5), Int64(LError.Offset), 'continued block missing-key byte offset');
end;

procedure TestTryYamlParseRejectsUnsupportedExplicitMappingKeys;
var
  LDoc: IYamlDocument;
  LError: TYamlError;
begin
  Check(not TryYamlParse('{? a: 1}', LDoc),
    'TryYamlParse rejects flow explicit mapping key');
  Check(LDoc <> nil, 'flow explicit-key diagnostic doc assigned');
  Check(LDoc.HasError, 'flow explicit-key diagnostic doc has error');
  LError := LDoc.Error;
  Check(Pos('explicit mapping keys', LError.Message.ToString) > 0,
    'flow explicit-key diagnostic names unsupported explicit keys');
  CheckEqual(Int64(1), Int64(LError.Line), 'flow explicit-key error line');
  CheckEqual(Int64(2), Int64(LError.Col), 'flow explicit-key error column');
  CheckEqual(Int64(1), Int64(LError.Offset), 'flow explicit-key byte offset');

  Check(not TryYamlParse('? a' + #10 + ': 1', LDoc),
    'TryYamlParse rejects top-level explicit mapping key');
  Check(LDoc <> nil, 'top-level explicit-key diagnostic doc assigned');
  Check(LDoc.HasError, 'top-level explicit-key diagnostic doc has error');
  LError := LDoc.Error;
  Check(Pos('explicit mapping keys', LError.Message.ToString) > 0,
    'top-level explicit-key diagnostic names unsupported explicit keys');
  CheckEqual(Int64(1), Int64(LError.Line), 'top-level explicit-key error line');
  CheckEqual(Int64(1), Int64(LError.Col), 'top-level explicit-key error column');
  CheckEqual(Int64(0), Int64(LError.Offset), 'top-level explicit-key byte offset');

  Check(not TryYamlParse('root:' + #10 + '  ? a' + #10 + '  : 1', LDoc),
    'TryYamlParse rejects nested explicit mapping key');
  Check(LDoc <> nil, 'nested explicit-key diagnostic doc assigned');
  Check(LDoc.HasError, 'nested explicit-key diagnostic doc has error');
  LError := LDoc.Error;
  Check(Pos('explicit mapping keys', LError.Message.ToString) > 0,
    'nested explicit-key diagnostic names unsupported explicit keys');
  CheckEqual(Int64(2), Int64(LError.Line), 'nested explicit-key error line');
  CheckEqual(Int64(3), Int64(LError.Col), 'nested explicit-key error column');
  CheckEqual(Int64(8), Int64(LError.Offset), 'nested explicit-key byte offset');
end;

procedure TestAliasResolutionDepthBoundary;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse(BuildAliasChainDocument(64));
  Check(not LDoc.HasError, '64-level alias chain stays valid');
  CheckEqual('base', LDoc.Root.MapGet('v64').AsStr.ToString,
    '64-level alias chain still resolves');
end;

procedure TestTryYamlParseRejectsAliasChainBeyondDepthLimit;
var
  LDoc: IYamlDocument;
  LError: TYamlError;
begin
  Check(not TryYamlParse(BuildAliasChainDocument(65), LDoc),
    'TryYamlParse rejects alias chain beyond depth limit');
  Check(LDoc <> nil, 'deep alias diagnostic doc assigned');
  Check(LDoc.HasError, 'deep alias diagnostic doc has error');
  LError := LDoc.Error;
  Check(Pos('alias resolution depth', LError.Message.ToString) > 0,
    'deep alias diagnostic names depth limit');
  CheckEqual(Int64(66), Int64(LError.Line), 'deep alias error line');
  Check(LError.Col > 1, 'deep alias error column');
  Check(LError.Offset > 0, 'deep alias byte offset');
end;

procedure TestTryYamlParseRejectsUndefinedAlias;
var
  LDoc: IYamlDocument;
  LError: TYamlError;
begin
  Check(not TryYamlParse('*missing', LDoc), 'TryYamlParse rejects undefined alias');
  Check(LDoc <> nil, 'undefined alias diagnostic doc assigned');
  Check(LDoc.HasError, 'undefined alias diagnostic doc has error');
  LError := LDoc.Error;
  Check(Pos('undefined alias', LError.Message.ToString) > 0,
    'undefined alias diagnostic names missing anchor');
  CheckEqual(Int64(1), Int64(LError.Line), 'undefined alias error line');
  CheckEqual(Int64(1), Int64(LError.Col), 'undefined alias error column');
  CheckEqual(Int64(0), Int64(LError.Offset), 'undefined alias byte offset');
end;

procedure TestTryYamlParseRejectsEmptyAnchorAliasNames;
var
  LDoc: IYamlDocument;
  LError: TYamlError;
begin
  Check(not TryYamlParse('& value', LDoc), 'TryYamlParse rejects empty anchor name');
  Check(LDoc <> nil, 'empty anchor diagnostic doc assigned');
  Check(LDoc.HasError, 'empty anchor diagnostic doc has error');
  LError := LDoc.Error;
  Check(Pos('empty anchor/alias name', LError.Message.ToString) > 0,
    'empty anchor diagnostic names malformed anchor');
  CheckEqual(Int64(1), Int64(LError.Line), 'empty anchor error line');
  CheckEqual(Int64(2), Int64(LError.Col), 'empty anchor error column');
  CheckEqual(Int64(1), Int64(LError.Offset), 'empty anchor byte offset');

  Check(not TryYamlParse('* ', LDoc), 'TryYamlParse rejects empty alias name');
  Check(LDoc <> nil, 'empty alias diagnostic doc assigned');
  Check(LDoc.HasError, 'empty alias diagnostic doc has error');
  LError := LDoc.Error;
  Check(Pos('empty anchor/alias name', LError.Message.ToString) > 0,
    'empty alias diagnostic names malformed alias');
  CheckEqual(Int64(1), Int64(LError.Line), 'empty alias error line');
  CheckEqual(Int64(2), Int64(LError.Col), 'empty alias error column');
  CheckEqual(Int64(1), Int64(LError.Offset), 'empty alias byte offset');
end;

procedure TestTryYamlParseRejectsDeepFlowNesting;
var
  LDoc: IYamlDocument;
  LError: TYamlError;
begin
  Check(not TryYamlParse(BuildDeepFlowSequenceDocument(300), LDoc),
    'TryYamlParse rejects flow nesting beyond parser depth limit');
  Check(LDoc <> nil, 'deep flow diagnostic doc assigned');
  Check(LDoc.HasError, 'deep flow diagnostic doc has error');
  LError := LDoc.Error;
  Check(Pos('nesting too deep', LError.Message.ToString) > 0,
    'deep flow diagnostic names nesting limit');
  Check(LError.Line > 0, 'deep flow error line');
  Check(LError.Col > 0, 'deep flow error column');
  Check(LError.Offset > 0, 'deep flow byte offset');
end;

procedure TestTryYamlParseRejectsDeepBlockMappingNesting;
var
  LDoc: IYamlDocument;
  LError: TYamlError;
begin
  Check(not TryYamlParse(BuildDeepBlockMappingDocument(300), LDoc),
    'TryYamlParse rejects block mapping nesting beyond parser depth limit');
  Check(LDoc <> nil, 'deep block mapping diagnostic doc assigned');
  Check(LDoc.HasError, 'deep block mapping diagnostic doc has error');
  LError := LDoc.Error;
  Check(Pos('nesting too deep', LError.Message.ToString) > 0,
    'deep block mapping diagnostic names nesting limit');
  Check(LError.Line > 0, 'deep block mapping error line');
  Check(LError.Col > 0, 'deep block mapping error column');
  Check(LError.Offset > 0, 'deep block mapping byte offset');
end;

procedure TestTryYamlParseRejectsDeepBlockSequenceNesting;
var
  LDoc: IYamlDocument;
  LError: TYamlError;
begin
  Check(not TryYamlParse(BuildDeepBlockSequenceDocument(70), LDoc),
    'TryYamlParse rejects block sequence nesting beyond scanner indent limit');
  Check(LDoc <> nil, 'deep block sequence diagnostic doc assigned');
  Check(LDoc.HasError, 'deep block sequence diagnostic doc has error');
  LError := LDoc.Error;
  Check(Pos('nesting too deep', LError.Message.ToString) > 0,
    'deep block sequence diagnostic names nesting limit');
  Check(LError.Line > 0, 'deep block sequence error line');
  Check(LError.Col > 0, 'deep block sequence error column');
  Check(LError.Offset > 0, 'deep block sequence byte offset');
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

procedure TestDiagnosticDocumentRejectsStringify;
var
  LDoc: IYamlDocument;
  LRaised: Boolean;
begin
  Check(not TryYamlParse('{a: 1, b}', LDoc), 'diagnostic doc produced');
  Check(LDoc <> nil, 'diagnostic doc assigned');
  Check(LDoc.HasError, 'diagnostic doc has error');

  LRaised := False;
  try
    LDoc.Stringify;
  except
    on E: EInvalidOperationError do
    begin
      LRaised := True;
      Check(Pos('diagnostic document', E.Message) > 0,
        'diagnostic stringify message identifies diagnostic document');
    end;
  end;
  Check(LRaised, 'diagnostic stringify rejected');

  LRaised := False;
  try
    LDoc.StringifyPretty(2);
  except
    on E: EInvalidOperationError do
    begin
      LRaised := True;
      Check(Pos('diagnostic document', E.Message) > 0,
        'diagnostic pretty stringify message identifies diagnostic document');
    end;
  end;
  Check(LRaised, 'diagnostic pretty stringify rejected');
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

  LDoc := YamlParse('"ok \n escape"');
  Check(not LDoc.HasError, 'valid double-quoted escape accepted');
  Check(LDoc.Root.AsStr.ToString = 'ok \n escape',
    'valid double-quoted escape remains raw text');
end;

procedure TestTryYamlParseRejectsInvalidDoubleQuotedEscape;
var
  LDoc: IYamlDocument;
  LError: TYamlError;
begin
  Check(not TryYamlParse('"bad \q escape"', LDoc),
    'TryYamlParse rejects invalid double-quoted escape');
  Check(LDoc <> nil, 'invalid escape diagnostic doc assigned');
  Check(LDoc.HasError, 'invalid escape diagnostic doc has error');
  LError := LDoc.Error;
  Check(Pos('invalid escape', LError.Message.ToString) > 0,
    'invalid escape diagnostic');
  CheckEqual(Int64(1), Int64(LError.Line), 'invalid escape line');
  CheckEqual(Int64(6), Int64(LError.Col), 'invalid escape column');
  CheckEqual(Int64(5), Int64(LError.Offset), 'invalid escape offset');
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
  LDoc := YamlParse('{key: value');
  Check(LDoc.HasError, 'unclosed flow map is invalid');
  LDoc := YamlParse('[1, 2');
  Check(LDoc.HasError, 'unclosed flow sequence is invalid');
end;

procedure TestRejectsMultipleDocuments;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('---' + #10 + 'a: 1' + #10 + '---' + #10 + 'b: 2');
  Check(LDoc.HasError, 'multiple documents are rejected');
  Check(Pos('multiple YAML documents', LDoc.Error.Message.ToString) > 0,
    'multiple document parse has diagnostic');

  Check(not TryYamlParse('---' + #10 + 'a: 1' + #10 + '---' + #10 + 'b: 2', LDoc),
    'try parse rejects multiple documents');
  Check(LDoc <> nil, 'diagnostic doc assigned');
  Check(LDoc.HasError, 'diagnostic doc has error');
  Check(Pos('multiple YAML documents', LDoc.Error.Message.ToString) > 0,
    'try parse diagnostic keeps multiple document message');
end;

procedure TestRejectsUnsupportedDirectives;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('%YAML 1.2' + #10 + 'name: Alice');
  Check(LDoc.HasError, 'yaml directive is rejected');
  Check(Pos('directives', LDoc.Error.Message.ToString) > 0,
    'yaml directive diagnostic');

  Check(not TryYamlParse('%TAG !e! tag:example.com,2024:' + #10 + 'name: Alice', LDoc),
    'tag directive is rejected');
  Check(LDoc <> nil, 'directive diagnostic doc assigned');
  Check(LDoc.HasError, 'directive diagnostic doc has error');
  Check(Pos('directives', LDoc.Error.Message.ToString) > 0,
    'tag directive diagnostic');
end;

procedure TestRejectsUnsupportedTags;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('!str hello');
  Check(LDoc.HasError, 'root tag is rejected');
  Check(Pos('tags', LDoc.Error.Message.ToString) > 0,
    'root tag diagnostic');

  Check(not TryYamlParse('name: !str hello', LDoc), 'map tag is rejected');
  Check(LDoc <> nil, 'tag diagnostic doc assigned');
  Check(LDoc.HasError, 'tag diagnostic doc has error');
  Check(Pos('tags', LDoc.Error.Message.ToString) > 0,
    'map tag diagnostic');
end;

procedure TestQuotedBangStringsRemainStrings;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('''!str hello''');
  Check(not LDoc.HasError, 'single quoted bang string is accepted');
  Check(LDoc.Root.IsStr, 'single quoted bang root is string');
  Check(LDoc.Root.AsStr.ToString = '!str hello', 'single quoted bang value');

  LDoc := YamlParse('"!str hello"');
  Check(not LDoc.HasError, 'double quoted bang string is accepted');
  Check(LDoc.Root.IsStr, 'double quoted bang root is string');
  Check(LDoc.Root.AsStr.ToString = '!str hello', 'double quoted bang value');
end;

procedure TestRejectsUnsupportedMergeKeys;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('{defaults: &def {a: 1}, merged: {<<: *def, b: 2}}');
  Check(LDoc.HasError, 'flow merge key is rejected');
  Check(Pos('merge keys', LDoc.Error.Message.ToString) > 0,
    'flow merge key diagnostic');

  Check(not TryYamlParse(
    'defaults: &def' + #10 +
    '  a: 1' + #10 +
    'merged:' + #10 +
    '  <<: *def' + #10 +
    '  b: 2', LDoc), 'block merge key is rejected');
  Check(LDoc <> nil, 'merge diagnostic doc assigned');
  Check(LDoc.HasError, 'merge diagnostic doc has error');
  Check(Pos('merge keys', LDoc.Error.Message.ToString) > 0,
    'block merge key diagnostic');
end;

procedure TestQuotedMergeKeyRemainsDataKey;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('{defaults: &def {a: 1}, merged: {"<<": *def, b: 2}}');
  Check(not LDoc.HasError, 'quoted merge key stays valid');
  Check(LDoc.Root.MapGet('merged').IsMap, 'merged is map');
  Check(LDoc.Root.MapGet('merged').MapHas('<<'), 'quoted merge key present');
  Check(LDoc.Root.MapGet('merged').MapGet('<<').IsMap, 'quoted merge value is map');
  CheckEqual(Int64(1), LDoc.Root.MapGet('merged').MapGet('<<').MapGet('a').AsInt,
    'quoted merge key retains alias value');
end;

procedure TestRejectsDuplicateKeys;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('{a: 1, a: 2}');
  Check(LDoc.HasError, 'flow duplicate key is rejected');
  Check(Pos('duplicate mapping key', LDoc.Error.Message.ToString) > 0,
    'flow duplicate diagnostic');

  Check(not TryYamlParse('a: 1' + #10 + 'a: 2', LDoc),
    'block duplicate key is rejected');
  Check(LDoc <> nil, 'duplicate diagnostic doc assigned');
  Check(LDoc.HasError, 'duplicate diagnostic doc has error');
  Check(Pos('duplicate mapping key', LDoc.Error.Message.ToString) > 0,
    'block duplicate diagnostic');
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
  T.Run('Doc end marker', @TestDocEndMarker);
  T.Run('Error handling', @TestErrorHandling);
  T.Run('TryYamlParse success', @TestTryYamlParseSuccess);
  T.Run('TryYamlParse failure returns diagnostic doc', @TestTryYamlParseFailureReturnsDiagnosticDoc);
  T.Run('TryYamlParse rejects stray flow closers',
    @TestTryYamlParseRejectsStrayFlowClosers);
  T.Run('TryYamlParse rejects trailing document content',
    @TestTryYamlParseRejectsTrailingDocumentContent);
  T.Run('TryYamlParse rejects missing value separator',
    @TestTryYamlParseRejectsMissingValueSeparator);
  T.Run('TryYamlParse rejects missing mapping key',
    @TestTryYamlParseRejectsMissingMappingKey);
  T.Run('TryYamlParse rejects block mapping entry without key',
    @TestTryYamlParseRejectsBlockMappingEntryWithoutKey);
  T.Run('TryYamlParse rejects unsupported explicit mapping keys',
    @TestTryYamlParseRejectsUnsupportedExplicitMappingKeys);
  T.Run('Alias resolution depth boundary', @TestAliasResolutionDepthBoundary);
  T.Run('TryYamlParse rejects alias chain beyond depth limit',
    @TestTryYamlParseRejectsAliasChainBeyondDepthLimit);
  T.Run('TryYamlParse rejects undefined alias',
    @TestTryYamlParseRejectsUndefinedAlias);
  T.Run('TryYamlParse rejects empty anchor/alias names',
    @TestTryYamlParseRejectsEmptyAnchorAliasNames);
  T.Run('TryYamlParse rejects deep flow nesting',
    @TestTryYamlParseRejectsDeepFlowNesting);
  T.Run('TryYamlParse rejects deep block mapping nesting',
    @TestTryYamlParseRejectsDeepBlockMappingNesting);
  T.Run('TryYamlParse rejects deep block sequence nesting',
    @TestTryYamlParseRejectsDeepBlockSequenceNesting);
  T.Run('Stringify', @TestStringify);
  T.Run('Stringify pretty', @TestStringifyPretty);
  T.Run('Diagnostic document rejects stringify',
    @TestDiagnosticDocumentRejectsStringify);
  T.Run('Round-trip', @TestRoundTrip);
  T.Run('Block mapping', @TestBlockMapping);
  T.Run('Block sequence', @TestBlockSequence);
  T.Run('Nested block map', @TestNestedBlockMap);
  T.Run('MapHas', @TestMapHas);
  T.Run('MapLen', @TestMapLen);
  T.Run('SeqGet bounds', @TestSeqGetBounds);
  T.Run('Empty document', @TestEmptyDocument);
  T.Run('Multiline string', @TestMultilineString);
  T.Run('TryYamlParse rejects invalid double-quoted escape',
    @TestTryYamlParseRejectsInvalidDoubleQuotedEscape);
  T.Run('Special values', @TestSpecialValues);
  T.Run('Large document 1000', @TestLargeDocument);
  T.Run('Invalid YAML', @TestInvalidYaml);
  T.Run('Rejects multiple documents', @TestRejectsMultipleDocuments);
  T.Run('Rejects unsupported directives', @TestRejectsUnsupportedDirectives);
  T.Run('Rejects unsupported tags', @TestRejectsUnsupportedTags);
  T.Run('Quoted bang strings remain strings', @TestQuotedBangStringsRemainStrings);
  T.Run('Rejects unsupported merge keys', @TestRejectsUnsupportedMergeKeys);
  T.Run('Quoted merge key remains data key', @TestQuotedMergeKeyRemainsDataKey);
  T.Run('Rejects duplicate keys', @TestRejectsDuplicateKeys);
  T.Summary;
end.
