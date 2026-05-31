program test_yaml_builder;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.text.view,
  nextpas.core.yaml.types,
  nextpas.core.yaml.builder,
  nextpas.core.yaml;

var
  T: TTestRunner;

procedure TestBuildScalar;
var
  LB: TYamlBuilder;
  LOut: string;
begin
  LB.Init;
  LB.PutInt(42);
  LOut := LB.Stringify;
  Check(LOut = '42', 'int scalar');
  LB.Done;

  LB.Init;
  LB.PutBool(True);
  LOut := LB.Stringify;
  Check(LOut = 'true', 'bool scalar');
  LB.Done;

  LB.Init;
  LB.PutNull;
  LOut := LB.Stringify;
  Check(LOut = 'null', 'null scalar');
  LB.Done;
end;

procedure TestBuildSequence;
var
  LB: TYamlBuilder;
  LOut: string;
begin
  LB.Init;
  LB.BeginSeq;
  LB.PutInt(1);
  LB.PutInt(2);
  LB.PutInt(3);
  LB.EndSeq;
  LOut := LB.Stringify;
  Check(Pos('[1, 2, 3]', LOut) > 0, 'seq output');
  LB.Done;
end;

procedure TestBuildMapping;
var
  LB: TYamlBuilder;
  LOut: string;
begin
  LB.Init;
  LB.BeginMap;
  LB.PutKey('name');
  LB.PutStr('Alice');
  LB.PutKey('age');
  LB.PutInt(30);
  LB.EndMap;
  LOut := LB.Stringify;
  Check(Pos('name', LOut) > 0, 'has name');
  Check(Pos('Alice', LOut) > 0, 'has Alice');
  Check(Pos('30', LOut) > 0, 'has 30');
  LB.Done;
end;

procedure TestBuildNested;
var
  LB: TYamlBuilder;
  LOut: string;
  LDoc: IYamlDocument;
begin
  LB.Init;
  LB.BeginMap;
  LB.PutKey('users');
  LB.BeginSeq;
  LB.PutStr('Alice');
  LB.PutStr('Bob');
  LB.EndSeq;
  LB.PutKey('count');
  LB.PutInt(2);
  LB.EndMap;
  LOut := LB.Stringify;
  LB.Done;

  // Verify by parsing the output
  LDoc := YamlParse(LOut);
  Check(not LDoc.HasError, 'round-trip no error');
  Check(LDoc.Root.IsMap, 'is map');
  CheckEqual(Int64(2), Int64(LDoc.Root.MapGet('users').SeqLen), 'users len');
  CheckEqual(Int64(2), LDoc.Root.MapGet('count').AsInt, 'count=2');
end;

procedure TestBuildPretty;
var
  LB: TYamlBuilder;
  LOut: string;
begin
  LB.Init;
  LB.BeginMap;
  LB.PutKey('a');
  LB.PutInt(1);
  LB.PutKey('b');
  LB.PutInt(2);
  LB.EndMap;
  LOut := LB.StringifyPretty;
  Check(Pos(#10, LOut) > 0, 'has newlines');
  Check(Pos('a:', LOut) > 0, 'has a:');
  LB.Done;
end;

{ P11: Robustness tests }

procedure TestDeepNesting;
var
  LDoc: IYamlDocument;
  LInput: string;
  LI: Integer;
begin
  // 30 levels of nested flow sequences
  LInput := '';
  for LI := 1 to 30 do LInput := LInput + '[';
  LInput := LInput + '1';
  for LI := 1 to 30 do LInput := LInput + ']';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'deep nesting no error');
  Check(LDoc.Root.IsSeq, 'root is seq');
end;

procedure TestEmptyInput;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('');
  Check(LDoc.Root.IsNull, 'empty → null');

  LDoc := YamlParse('   ');
  Check(LDoc.Root.IsNull, 'whitespace → null');

  LDoc := YamlParse('# just a comment');
  Check(LDoc.Root.IsNull, 'comment only → null');
end;

procedure TestMalformedInput;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('}');
  Check(not LDoc.HasError or LDoc.Root.IsNull, 'lone } handled');

  LDoc := YamlParse(']');
  Check(not LDoc.HasError or LDoc.Root.IsNull, 'lone ] handled');

  LDoc := YamlParse('{{{');
  Check(LDoc.HasError or LDoc.Root.IsMap, 'unclosed { handled');
end;

procedure TestLargeInput;
var
  LDoc: IYamlDocument;
  LInput: string;
  LI: Integer;
begin
  // Build a large flow sequence
  LInput := '[';
  for LI := 1 to 1000 do
  begin
    if LI > 1 then LInput := LInput + ', ';
    LInput := LInput + IntToStr(LI);
  end;
  LInput := LInput + ']';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'large input no error');
  CheckEqual(Int64(1000), Int64(LDoc.Root.SeqLen), '1000 elements');
  CheckEqual(Int64(1), LDoc.Root.SeqGet(0).AsInt, 'first=1');
  CheckEqual(Int64(1000), LDoc.Root.SeqGet(999).AsInt, 'last=1000');
end;

procedure TestInvalidAccessGraceful;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
begin
  LDoc := YamlParse('{a: 1}');
  LRoot := LDoc.Root;
  Check(not LRoot.MapGet('missing').IsValid, 'missing key → invalid');
  Check(LRoot.SeqGet(0).IsNull, 'map as seq → null');
  CheckEqual(Int64(0), Int64(LRoot.SeqLen), 'map seqlen = 0');
  Check(LRoot.MapGet('a').MapGet('x').IsNull, 'int as map → null');
end;

procedure TestBuildFloat;
var LB: TYamlBuilder; LOut: string;
begin
  LB.Init;
  LB.PutFloat(3.14);
  LOut := LB.Stringify;
  Check(Pos('3.14', LOut) > 0, 'float 3.14');
  LB.Done;
end;

procedure TestBuildString;
var LB: TYamlBuilder; LOut: string;
begin
  LB.Init;
  LB.PutStr('hello world');
  LOut := LB.Stringify;
  Check(Pos('hello world', LOut) > 0, 'string value');
  LB.Done;
end;

procedure TestBuildEmptySeq;
var LB: TYamlBuilder; LOut: string;
begin
  LB.Init;
  LB.BeginSeq;
  LB.EndSeq;
  LOut := LB.Stringify;
  Check(Pos('[]', LOut) > 0, 'empty seq');
  LB.Done;
end;

procedure TestBuildEmptyMap;
var LB: TYamlBuilder; LOut: string;
begin
  LB.Init;
  LB.BeginMap;
  LB.EndMap;
  LOut := LB.Stringify;
  Check(Pos('{}', LOut) > 0, 'empty map');
  LB.Done;
end;

procedure TestBuildSeqOfMaps;
var LB: TYamlBuilder; LOut: string; LDoc: IYamlDocument;
begin
  LB.Init;
  LB.BeginSeq;
  LB.BeginMap;
  LB.PutKey('id'); LB.PutInt(1);
  LB.PutKey('name'); LB.PutStr('Alice');
  LB.EndMap;
  LB.BeginMap;
  LB.PutKey('id'); LB.PutInt(2);
  LB.PutKey('name'); LB.PutStr('Bob');
  LB.EndMap;
  LB.EndSeq;
  LOut := LB.Stringify;
  LB.Done;
  LDoc := YamlParse(LOut);
  Check(not LDoc.HasError, 'seq of maps no error');
  CheckEqual(Int64(2), Int64(LDoc.Root.SeqLen), 'seq len 2');
  CheckEqual(Int64(1), LDoc.Root.SeqGet(0).MapGet('id').AsInt, 'first id');
  Check(LDoc.Root.SeqGet(1).MapGet('name').AsStr.ToString = 'Bob', 'second name');
end;

procedure TestBuildMapOfSeqs;
var LB: TYamlBuilder; LOut: string; LDoc: IYamlDocument;
begin
  LB.Init;
  LB.BeginMap;
  LB.PutKey('fruits');
  LB.BeginSeq; LB.PutStr('apple'); LB.PutStr('banana'); LB.EndSeq;
  LB.PutKey('vegs');
  LB.BeginSeq; LB.PutStr('carrot'); LB.EndSeq;
  LB.EndMap;
  LOut := LB.Stringify;
  LB.Done;
  LDoc := YamlParse(LOut);
  Check(not LDoc.HasError, 'map of seqs no error');
  CheckEqual(Int64(2), Int64(LDoc.Root.MapGet('fruits').SeqLen), 'fruits len');
  CheckEqual(Int64(1), Int64(LDoc.Root.MapGet('vegs').SeqLen), 'vegs len');
end;

procedure TestBuildAllTypes;
var LB: TYamlBuilder; LOut: string; LDoc: IYamlDocument;
begin
  LB.Init;
  LB.BeginMap;
  LB.PutKey('null_val'); LB.PutNull;
  LB.PutKey('bool_val'); LB.PutBool(False);
  LB.PutKey('int_val'); LB.PutInt(-99);
  LB.PutKey('float_val'); LB.PutFloat(2.718);
  LB.PutKey('str_val'); LB.PutStr('test');
  LB.EndMap;
  LOut := LB.Stringify;
  LB.Done;
  LDoc := YamlParse(LOut);
  Check(not LDoc.HasError, 'all types no error');
  Check(LDoc.Root.MapGet('null_val').IsNull, 'null');
  Check(LDoc.Root.MapGet('bool_val').AsBool = False, 'bool');
  CheckEqual(Int64(-99), LDoc.Root.MapGet('int_val').AsInt, 'int');
  Check(LDoc.Root.MapGet('str_val').AsStr.ToString = 'test', 'str');
end;

begin
  T := TTestRunner.Create('nextpas.core.yaml.builder');
  T.Run('Build scalar', @TestBuildScalar);
  T.Run('Build sequence', @TestBuildSequence);
  T.Run('Build mapping', @TestBuildMapping);
  T.Run('Build nested', @TestBuildNested);
  T.Run('Build pretty', @TestBuildPretty);
  T.Run('Deep nesting', @TestDeepNesting);
  T.Run('Empty input', @TestEmptyInput);
  T.Run('Malformed input', @TestMalformedInput);
  T.Run('Large input', @TestLargeInput);
  T.Run('Invalid access graceful', @TestInvalidAccessGraceful);
  T.Run('Build float', @TestBuildFloat);
  T.Run('Build string', @TestBuildString);
  T.Run('Build empty seq', @TestBuildEmptySeq);
  T.Run('Build empty map', @TestBuildEmptyMap);
  T.Run('Build seq of maps', @TestBuildSeqOfMaps);
  T.Run('Build map of seqs', @TestBuildMapOfSeqs);
  T.Run('Build all types', @TestBuildAllTypes);
  T.Summary;
end.
