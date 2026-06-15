program test_yaml_builder;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.text.view,
  nextpas.core.yaml.types,
  nextpas.core.yaml.builder,
  nextpas.core.yaml;

var
  T: TTestRunner;

const
  YAML_BUILDER_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.yaml.builder.pas';
  YAML_BUILDER_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.yaml.builder.pas';

function ReadSourceFile(const APath: string): string;
var
  LFile: Text;
  LLine: string;
begin
  Result := '';
  Assign(LFile, APath);
  Reset(LFile);
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      Result := Result + LowerCase(LLine) + #10;
    end;
  finally
    Close(LFile);
  end;
end;

function ResolveSourcePath(const APathFromTest: string; const APathFromRoot: string): string;
begin
  if FileExists(APathFromTest) then
    Exit(APathFromTest);
  if FileExists(APathFromRoot) then
    Exit(APathFromRoot);
  Result := APathFromTest;
end;

procedure CheckSourceContains(const ASource, ANeedle, AMessage: string);
begin
  Check(Pos(LowerCase(ANeedle), ASource) > 0, AMessage);
end;

procedure CheckSourceAbsent(const ASource, ANeedle, AMessage: string);
begin
  Check(Pos(LowerCase(ANeedle), ASource) = 0, AMessage);
end;

procedure CheckSourceOrder(const ASource, AFirstNeedle, ASecondNeedle, AMessage: string);
var
  LFirstPos: SizeInt;
  LSecondPos: SizeInt;
begin
  LFirstPos := Pos(LowerCase(AFirstNeedle), ASource);
  LSecondPos := Pos(LowerCase(ASecondNeedle), ASource);
  Check((LFirstPos > 0) and (LSecondPos > 0) and (LFirstPos < LSecondPos), AMessage);
end;

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
  Check(LDoc.HasError, 'lone } reports error');

  LDoc := YamlParse(']');
  Check(LDoc.HasError, 'lone ] reports error');

  LDoc := YamlParse('{{{');
  Check(LDoc.HasError, 'unclosed { reports error');

  LDoc := YamlParse('[[[');
  Check(LDoc.HasError, 'unclosed [ reports error');
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

procedure TestPutStrView;
var LB: TYamlBuilder; LOut: string; LDoc: IYamlDocument;
    LView: TStringView;
begin
  LB.Init;
  LB.BeginMap;
  LB.PutKey('msg');
  LView := TStringView.FromStr('hello from view');
  LB.PutStrView(LView);
  LB.EndMap;
  LOut := LB.Stringify;
  LB.Done;
  LDoc := YamlParse(LOut);
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.MapGet('msg').AsStr.ToString = 'hello from view', 'strview val');
end;

procedure TestStringifyPrettyCustomIndent;
var LB: TYamlBuilder; LOut: string;
begin
  LB.Init;
  LB.BeginMap;
  LB.PutKey('a'); LB.PutInt(1);
  LB.PutKey('b'); LB.PutInt(2);
  LB.EndMap;
  LOut := LB.StringifyPretty(4);
  LB.Done;
  Check(Length(LOut) > 0, 'pretty output not empty');
  Check(Pos('a', LOut) > 0, 'has key a');
  Check(Pos('b', LOut) > 0, 'has key b');
end;

procedure TestStringifyPrettyZeroIndent;
var LB: TYamlBuilder; LOut: string;
begin
  LB.Init;
  LB.BeginSeq;
  LB.PutInt(1); LB.PutInt(2);
  LB.EndSeq;
  LOut := LB.StringifyPretty(0);
  LB.Done;
  Check(Length(LOut) > 0, 'zero indent output not empty');
end;

procedure TestBuildOwnsQuotedSpecialStrings;
var
  LB: TYamlBuilder;
  LOut: string;
  LDoc: IYamlDocument;
begin
  LB.Init;
  LB.BeginMap;
  LB.PutKey('special');
  LB.BeginMap;
  LB.PutKey('value');
  LB.PutStr('a,b]}');
  LB.PutKey('empty');
  LB.PutStr('');
  LB.PutKey('trailing');
  LB.PutStr('two spaces  ');
  LB.PutKey('question');
  LB.PutStr('? value');
  LB.PutKey('dash');
  LB.PutStr('- value');
  LB.PutKey('backslash');
  LB.PutStr('path\name');
  LB.EndMap;
  LB.EndMap;
  LOut := LB.Stringify;
  LB.Done;

  LDoc := YamlParse(LOut);
  Check(Pos('"? value"', LOut) > 0, 'question-indicator scalar quoted');
  Check(Pos('"- value"', LOut) > 0, 'dash-indicator scalar quoted');
  Check(not LDoc.HasError, 'quoted specials stringify to valid yaml');
  CheckEqual('a,b]}', LDoc.Root.MapGet('special').MapGet('value').AsStr.ToString,
    'flow-special scalar survives');
  CheckEqual('', LDoc.Root.MapGet('special').MapGet('empty').AsStr.ToString,
    'empty scalar survives');
  CheckEqual('two spaces  ',
    LDoc.Root.MapGet('special').MapGet('trailing').AsStr.ToString,
    'trailing-space scalar survives');
  CheckEqual('? value',
    LDoc.Root.MapGet('special').MapGet('question').AsStr.ToString,
    'question-indicator scalar survives');
  CheckEqual('- value',
    LDoc.Root.MapGet('special').MapGet('dash').AsStr.ToString,
    'dash-indicator scalar survives');
  CheckEqual('path\name',
    LDoc.Root.MapGet('special').MapGet('backslash').AsStr.ToString,
    'plain-safe backslash scalar survives');
end;

procedure TestBuilderFailsFastWhenContainerStackIsFull;
var
  LB: TYamlBuilder;
  LDoc: IYamlDocument;
  LOut: string;
  LValue: TYamlValue;
  LI: Integer;
  LRaised: Boolean;
begin
  LB.Init;
  try
    for LI := 1 to 32 do
      LB.BeginSeq;

    LRaised := False;
    try
      LB.BeginSeq;
    except
      on E: EInvalidOperationError do
        LRaised := Pos('YAML builder nesting too deep', E.Message) > 0;
    end;
    Check(LRaised, '33rd nested container raises before mutation');

    LB.PutInt(7);
    for LI := 1 to 32 do
      LB.EndSeq;

    LOut := LB.Stringify;
  finally
    LB.Done;
  end;

  LDoc := YamlParse(LOut);
  Check(not LDoc.HasError, 'builder output remains valid after rejected overflow');
  LValue := LDoc.Root;
  for LI := 1 to 32 do
  begin
    Check(LValue.IsSeq, 'allowed depth stays nested sequence');
    CheckEqual(Int64(1), Int64(LValue.SeqLen), 'allowed depth keeps one child');
    LValue := LValue.SeqGet(0);
  end;
  CheckEqual(Int64(7), LValue.AsInt, 'deep value remains in current container');
end;

procedure TestBuilderEndContainerFailsClosed;
var
  LB: TYamlBuilder;
  LDoc: IYamlDocument;
  LOut: string;
  LRaised: Boolean;
begin
  LB.Init;
  try
    LRaised := False;
    try
      LB.EndSeq;
    except
      on E: EInvalidOperationError do
        LRaised := Pos('YAML builder sequence is not open', E.Message) > 0;
    end;
    Check(LRaised, 'empty EndSeq raises');

    LRaised := False;
    try
      LB.EndMap;
    except
      on E: EInvalidOperationError do
        LRaised := Pos('YAML builder mapping is not open', E.Message) > 0;
    end;
    Check(LRaised, 'empty EndMap raises');
  finally
    LB.Done;
  end;

  LB.Init;
  try
    LB.BeginMap;
    LB.PutKey('name');
    LB.PutStr('Alice');
    LRaised := False;
    try
      LB.EndSeq;
    except
      on E: EInvalidOperationError do
        LRaised := Pos('YAML builder sequence is not open', E.Message) > 0;
    end;
    Check(LRaised, 'EndSeq on map raises');
    LB.PutKey('age');
    LB.PutInt(30);
    LB.EndMap;
    LOut := LB.Stringify;
  finally
    LB.Done;
  end;

  LDoc := YamlParse(LOut);
  Check(not LDoc.HasError, 'map output remains valid after rejected EndSeq');
  CheckEqual('Alice', LDoc.Root.MapGet('name').AsStr.ToString,
    'map value before rejected EndSeq remains');
  CheckEqual(Int64(30), LDoc.Root.MapGet('age').AsInt,
    'map accepts value after rejected EndSeq');

  LB.Init;
  try
    LB.BeginSeq;
    LB.PutInt(1);
    LRaised := False;
    try
      LB.EndMap;
    except
      on E: EInvalidOperationError do
        LRaised := Pos('YAML builder mapping is not open', E.Message) > 0;
    end;
    Check(LRaised, 'EndMap on sequence raises');
    LB.PutInt(2);
    LB.EndSeq;
    LOut := LB.Stringify;
  finally
    LB.Done;
  end;

  LDoc := YamlParse(LOut);
  Check(not LDoc.HasError, 'sequence output remains valid after rejected EndMap');
  CheckEqual(Int64(2), Int64(LDoc.Root.SeqLen),
    'sequence accepts value after rejected EndMap');
  CheckEqual(Int64(1), LDoc.Root.SeqGet(0).AsInt,
    'sequence first value remains');
  CheckEqual(Int64(2), LDoc.Root.SeqGet(1).AsInt,
    'sequence second value remains');
end;

procedure TestBuilderMappingPendingKeyFailsClosed;
var
  LB: TYamlBuilder;
  LDoc: IYamlDocument;
  LOut: string;
  LRaised: Boolean;
begin
  LB.Init;
  try
    LB.BeginMap;
    LB.PutKey('dangling');
    LRaised := False;
    try
      LB.EndMap;
    except
      on E: EInvalidOperationError do
        LRaised := Pos('YAML builder mapping key has no value', E.Message) > 0;
    end;
    Check(LRaised, 'EndMap rejects pending mapping key');
    LB.PutStr('value');
    LB.EndMap;
    LOut := LB.Stringify;
  finally
    LB.Done;
  end;

  LDoc := YamlParse(LOut);
  Check(not LDoc.HasError, 'map output remains valid after rejected pending EndMap');
  CheckEqual('value', LDoc.Root.MapGet('dangling').AsStr.ToString,
    'pending key accepts value after rejected EndMap');

  LB.Init;
  try
    LB.BeginMap;
    LB.PutKey('first');
    LRaised := False;
    try
      LB.PutKey('second');
    except
      on E: EInvalidOperationError do
        LRaised := Pos('YAML builder mapping key has no value', E.Message) > 0;
    end;
    Check(LRaised, 'PutKey rejects previous pending mapping key');
    LB.PutInt(1);
    LB.EndMap;
    LOut := LB.Stringify;
  finally
    LB.Done;
  end;

  LDoc := YamlParse(LOut);
  Check(not LDoc.HasError, 'map output remains valid after rejected second key');
  CheckEqual(Int64(1), LDoc.Root.MapGet('first').AsInt,
    'first key accepts value after rejected second key');
  Check(not LDoc.Root.MapGet('second').IsValid,
    'rejected second key is not published');

  LB.Init;
  try
    LB.BeginMap;
    LRaised := False;
    try
      LB.PutInt(9);
    except
      on E: EInvalidOperationError do
        LRaised := Pos('YAML builder mapping value has no key', E.Message) > 0;
    end;
    Check(LRaised, 'mapping value without key raises');
    LB.PutKey('value');
    LB.PutInt(9);
    LB.EndMap;
    LOut := LB.Stringify;
  finally
    LB.Done;
  end;

  LDoc := YamlParse(LOut);
  Check(not LDoc.HasError, 'map output remains valid after rejected keyless value');
  CheckEqual(Int64(9), LDoc.Root.MapGet('value').AsInt,
    'map accepts keyed value after rejected keyless value');

  LB.Init;
  try
    LB.BeginMap;
    LB.PutKey('dangling');
    LRaised := False;
    try
      LOut := LB.Stringify;
    except
      on E: EInvalidOperationError do
        LRaised := Pos('YAML builder mapping key has no value', E.Message) > 0;
    end;
    Check(LRaised, 'Stringify rejects pending mapping key');
    LB.PutBool(True);
    LB.EndMap;
    LOut := LB.Stringify;
  finally
    LB.Done;
  end;

  LDoc := YamlParse(LOut);
  Check(not LDoc.HasError, 'map output remains valid after rejected pending Stringify');
  Check(LDoc.Root.MapGet('dangling').AsBool,
    'pending key accepts value after rejected Stringify');

  LB.Init;
  try
    LRaised := False;
    try
      LB.PutKey('outside');
    except
      on E: EInvalidOperationError do
        LRaised := Pos('YAML builder mapping is not open', E.Message) > 0;
    end;
    Check(LRaised, 'PutKey outside map raises');
    LB.BeginSeq;
    LB.PutInt(1);
    LRaised := False;
    try
      LB.PutKey('inside-seq');
    except
      on E: EInvalidOperationError do
        LRaised := Pos('YAML builder mapping is not open', E.Message) > 0;
    end;
    Check(LRaised, 'PutKey inside sequence raises');
    LB.PutInt(2);
    LB.EndSeq;
    LOut := LB.Stringify;
  finally
    LB.Done;
  end;

  LDoc := YamlParse(LOut);
  Check(not LDoc.HasError, 'sequence output remains valid after rejected PutKey');
  CheckEqual(Int64(2), Int64(LDoc.Root.SeqLen),
    'sequence accepts values around rejected PutKey');
end;

procedure TestBuilderSecondRootFailsClosed;
var
  LB: TYamlBuilder;
  LDoc: IYamlDocument;
  LOut: string;
  LRaised: Boolean;
begin
  LB.Init;
  try
    LB.PutInt(1);
    LRaised := False;
    try
      LB.PutInt(2);
    except
      on E: EInvalidOperationError do
        LRaised := Pos('YAML builder root value is already set', E.Message) > 0;
    end;
    Check(LRaised, 'second scalar root raises');
    LOut := LB.Stringify;
  finally
    LB.Done;
  end;

  LDoc := YamlParse(LOut);
  Check(not LDoc.HasError, 'root output remains valid after rejected scalar root');
  CheckEqual(Int64(1), LDoc.Root.AsInt,
    'rejected scalar root does not overwrite first root');

  LB.Init;
  try
    LB.PutStr('first');
    LRaised := False;
    try
      LB.BeginSeq;
    except
      on E: EInvalidOperationError do
        LRaised := Pos('YAML builder root value is already set', E.Message) > 0;
    end;
    Check(LRaised, 'second container root raises');
    LOut := LB.Stringify;
  finally
    LB.Done;
  end;

  LDoc := YamlParse(LOut);
  Check(not LDoc.HasError, 'root output remains valid after rejected container root');
  CheckEqual('first', LDoc.Root.AsStr.ToString,
    'rejected container root does not overwrite first root');
end;

procedure TestBuilderOwnedStringsUseAllocatorStorage;
var
  LSource: string;
begin
  LSource := ReadSourceFile(ResolveSourcePath(
    YAML_BUILDER_SOURCE_PATH_FROM_TEST,
    YAML_BUILDER_SOURCE_PATH_FROM_ROOT));
  CheckSourceContains(LSource, 'fownedstrings: pstring;',
    'builder owned strings must use raw pointer slots');
  CheckSourceContains(LSource, 'fownedcap: sizeuint;',
    'builder owned strings must track explicit capacity');
  CheckSourceAbsent(LSource, 'fownedstrings: array of string;',
    'builder owned strings must not use rtl dynamic arrays');
  CheckSourceAbsent(LSource, 'setlength(fownedstrings',
    'builder owned strings must not use setlength');
  CheckSourceContains(LSource, 'fdoc.fallocator.allocate(',
    'builder init must allocate owned string slots through document allocator');
  CheckSourceContains(LSource, 'fillchar(fownedstrings^, fownedcap * sizeof(string), 0);',
    'builder init must zero owned string slots');
  CheckSourceContains(LSource, 'fdoc.fallocator.reallocate(pointer(fownedstrings),',
    'builder growth must reallocate owned string slots through document allocator');
  CheckSourceContains(LSource,
    'fillchar(fownedstrings[loldcap], (fownedcap - loldcap) * sizeof(string), 0);',
    'builder growth must zero new owned string slots');
  CheckSourceContains(LSource, 'if fownedcount > 0 then',
    'builder done must guard zero-count finalization');
  CheckSourceContains(LSource, 'fownedstrings[li] := '''';',
    'builder done must finalize retained strings before release');
  CheckSourceContains(LSource, 'fdoc.fallocator.deallocate(pointer(fownedstrings));',
    'builder done must free owned string slots through document allocator');
  CheckSourceOrder(LSource, 'fownedstrings[li] := '''';',
    'fdoc.fallocator.deallocate(pointer(fownedstrings));',
    'builder done must finalize strings before freeing owned slots');
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
  T.Run('PutStrView', @TestPutStrView);
  T.Run('StringifyPretty custom indent', @TestStringifyPrettyCustomIndent);
  T.Run('StringifyPretty zero indent', @TestStringifyPrettyZeroIndent);
  T.Run('Build owns quoted special strings', @TestBuildOwnsQuotedSpecialStrings);
  T.Run('Builder fails fast when container stack is full',
    @TestBuilderFailsFastWhenContainerStackIsFull);
  T.Run('Builder end container fails closed',
    @TestBuilderEndContainerFailsClosed);
  T.Run('Builder mapping pending key fails closed',
    @TestBuilderMappingPendingKeyFailsClosed);
  T.Run('Builder second root fails closed',
    @TestBuilderSecondRootFailsClosed);
  T.Run('Builder owned strings use allocator storage',
    @TestBuilderOwnedStringsUseAllocatorStorage);
  T.Summary;
end.
