program test_json_robustness;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.mem.default,
  nextpas.core.json,
  nextpas.core.json.types,
  nextpas.core.json.parser,
  nextpas.core.json.value,
  nextpas.core.json.writer,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestEmptyInput;
var Doc: IJsonDocument;
begin
  Doc := JsonParse('');
  Check(Doc.HasError, 'empty string rejected');

  Doc := JsonParse('   ');
  Check(Doc.HasError, 'whitespace-only rejected');

  Doc := JsonParse(#9#10#13);
  Check(Doc.HasError, 'control-only rejected');
end;

procedure TestDepthBoundary;
var
  Buf: array[0..1099] of AnsiChar;
  I: Int32;
  Doc: IJsonDocument;
  S: string;
begin
  for I := 0 to 511 do Buf[I] := '[';
  for I := 512 to 1023 do Buf[I] := ']';
  SetString(S, @Buf[0], 1024);
  Doc := JsonParse(S);
  Check(not Doc.HasError, 'depth 512 accepted');

  for I := 0 to 512 do Buf[I] := '[';
  for I := 513 to 1025 do Buf[I] := ']';
  SetString(S, @Buf[0], 1026);
  Doc := JsonParse(S);
  Check(Doc.HasError, 'depth 513 rejected');
end;

procedure TestLongString;
var
  B: TStringBuilder;
  W: TJsonWriter;
  Doc: IJsonDocument;
  S: string;
  I: Int32;
begin
  B.Init(4096);
  W.Init(B);
  W.BeginObject;
  W.Key('longkey_' + StringOfChar('x', 500));
  W.Str(StringOfChar('y', 2000));
  W.EndObject;
  S := B.ToString;
  Doc := JsonParse(S);
  Check(not Doc.HasError, 'long key+value accepted');
  Check(Doc.Root.ObjectGet('longkey_' + StringOfChar('x', 500)).AsStr.Len = 2000, 'long value preserved');
  B.Done;
end;

procedure TestNumberOverflow;
var Doc: IJsonDocument;
begin
  Doc := JsonParse('99999999999999999999');
  Check(not Doc.HasError, 'large number parsed as float');
  Check(Doc.Root.IsReal, 'overflow → float');

  Doc := JsonParse('-99999999999999999999');
  Check(not Doc.HasError, 'large neg number parsed');
  Check(Doc.Root.IsReal, 'neg overflow → float');
end;

procedure TestMalformedStructure;
var Doc: IJsonDocument;
begin
  Doc := JsonParse(']');
  Check(Doc.HasError, 'lone ]');

  Doc := JsonParse('}');
  Check(Doc.HasError, 'lone }');

  Doc := JsonParse('[}');
  Check(Doc.HasError, 'mismatched brackets');

  Doc := JsonParse('{"a":1,}');
  Check(Doc.HasError, 'trailing comma in object');

  Doc := JsonParse('[1,]');
  Check(Doc.HasError, 'trailing comma in array');

  Doc := JsonParse('{"a"}');
  Check(Doc.HasError, 'key without colon');
end;

procedure TestDuplicateKeys;
var Doc: IJsonDocument; V: TJsonValue;
begin
  Doc := JsonParse('{"a":1,"a":2}');
  Check(not Doc.HasError, 'duplicate keys accepted');
  V := Doc.Root;
  CheckEqual(Int64(1), V.ObjectGet('a').AsInt, 'first occurrence wins');
end;

procedure TestSpecialStrings;
var Doc: IJsonDocument; S: string;
begin
  Doc := JsonParse('{"empty":"","space":" "}');
  Check(not Doc.HasError, 'special strings');
  CheckEqual('', Doc.Root.ObjectGet('empty').AsStr.ToString, 'empty str');
  CheckEqual(' ', Doc.Root.ObjectGet('space').AsStr.ToString, 'space str');
end;

procedure TestNullByteInString;
var Doc: IJsonDocument;
const
  INPUT = '{"x":"ab"}';
begin
  Doc := JsonParse(INPUT);
  Check(not Doc.HasError, 'normal string ok');
  CheckEqual('ab', Doc.Root.ObjectGet('x').AsStr.ToString, 'value');
end;

procedure TestInvalidValuePositions;
var Doc: IJsonDocument;
begin
  Doc := JsonParse('[true false]');
  Check(Doc.HasError, 'missing comma between values');

  Doc := JsonParse('{"a" "b"}');
  Check(Doc.HasError, 'missing colon');

  Doc := JsonParse('{"a":1 "b":2}');
  Check(Doc.HasError, 'missing comma between pairs');
end;

procedure TestAccessOnWrongType;
var Doc: IJsonDocument; V: TJsonValue;
begin
  Doc := JsonParse('42');
  V := Doc.Root;
  CheckEqual(Int64(0), Int64(V.ArrayLen), 'arraylen on int = 0');
  Check(not V.ObjectGet('x').IsValid, 'objectget on int = invalid');
  CheckEqual(Int64(0), Int64(V.ObjectLen), 'objectlen on int = 0');
  Check(V.ArrayGet(0).IsNull, 'arrayget on int = null');
end;

procedure TestStressLargeArray;
var
  B: TStringBuilder;
  W: TJsonWriter;
  Doc: IJsonDocument;
  I: Int32;
begin
  B.Init(65536);
  W.Init(B);
  W.BeginArray;
  for I := 0 to 999 do
    W.Int(I);
  W.EndArray;
  Doc := JsonParse(B.ToString);
  Check(not Doc.HasError, 'large array parsed');
  CheckEqual(Int64(1000), Int64(Doc.Root.ArrayLen), '1000 elements');
  CheckEqual(Int64(999), Doc.Root.ArrayGet(999).AsInt, 'last element');
  B.Done;
end;

begin
  T := TTestRunner.Create('nextpas.core.json.robustness');
  T.Run('empty input', @TestEmptyInput);
  T.Run('depth boundary', @TestDepthBoundary);
  T.Run('long string', @TestLongString);
  T.Run('number overflow', @TestNumberOverflow);
  T.Run('malformed structure', @TestMalformedStructure);
  T.Run('duplicate keys', @TestDuplicateKeys);
  T.Run('special strings', @TestSpecialStrings);
  T.Run('null byte in string', @TestNullByteInString);
  T.Run('invalid value positions', @TestInvalidValuePositions);
  T.Run('access on wrong type', @TestAccessOnWrongType);
  T.Run('stress large array', @TestStressLargeArray);
  T.Summary;
end.
