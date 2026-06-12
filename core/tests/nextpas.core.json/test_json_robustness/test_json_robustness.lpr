program test_json_robustness;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.simd.vec,
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

  procedure ExpectOverflow(const AInput, ACase: string);
  begin
    Doc := JsonParse(AInput);
    Check(Doc.HasError, ACase + ' rejected');
    CheckEqual('number overflow', Doc.Error.Message.ToString,
      ACase + ' error message');
  end;

begin
  Doc := JsonParse('9223372036854775807');
  Check(not Doc.HasError, 'max int64 accepted');
  Check(Doc.Root.IsInt, 'max int64 stays integer');
  CheckEqual(High(Int64), Doc.Root.AsInt, 'max int64 value');

  Doc := JsonParse('-9223372036854775808');
  Check(not Doc.HasError, 'min int64 accepted');
  Check(Doc.Root.IsInt, 'min int64 stays integer');
  CheckEqual(Low(Int64), Doc.Root.AsInt, 'min int64 value');

  Doc := JsonParse('1e20');
  Check(not Doc.HasError, 'explicit exponent parsed as float');
  Check(Doc.Root.IsReal, 'explicit exponent stays float');

  Doc := JsonParse('1.0');
  Check(not Doc.HasError, 'explicit decimal parsed as float');
  Check(Doc.Root.IsReal, 'explicit decimal stays float');

  ExpectOverflow('9223372036854775808', 'positive int64 overflow');
  ExpectOverflow('-9223372036854775809', 'negative int64 overflow');
  ExpectOverflow('99999999999999999999', 'large integer overflow');
  ExpectOverflow('-99999999999999999999', 'large negative integer overflow');
  ExpectOverflow('1e1000', 'explicit float overflow');
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
  CheckEqual(Int64(2), V.ObjectGet('a').AsInt, 'last occurrence wins');
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

procedure TestStructuralErrorPositions;
var
  Doc: IJsonDocument;

  procedure ExpectStructuralErrorPosition(const AInput, AExpectedMessage,
    ACase: string; AExpectedOffset, AExpectedLine, AExpectedColumn: Int64);
  begin
    Doc := JsonParse(AInput);
    Check(Doc.HasError, ACase + ' rejected');
    CheckEqual(AExpectedMessage, Doc.Error.Message.ToString,
      ACase + ' error message');
    CheckEqual(AExpectedOffset, Int64(Doc.Error.Offset),
      ACase + ' error offset');
    CheckEqual(AExpectedLine, Int64(Doc.Error.Line),
      ACase + ' error line');
    CheckEqual(AExpectedColumn, Int64(Doc.Error.Column),
      ACase + ' error column');
  end;

begin
  ExpectStructuralErrorPosition('{"a" "b"}',
    'expected :', 'object missing colon before next key', 5, 1, 6);
  ExpectStructuralErrorPosition('{"a":1 "b":2}',
    'expected , or }', 'object missing comma before next key', 7, 1, 8);
  ExpectStructuralErrorPosition('["a" "b"]',
    'expected , or ]', 'array missing comma before next string', 5, 1, 6);
  ExpectStructuralErrorPosition('[true false]',
    'expected , or ]', 'array missing comma before next literal', 6, 1, 7);
  ExpectStructuralErrorPosition('[false null]',
    'expected , or ]', 'array missing comma after false', 7, 1, 8);
  ExpectStructuralErrorPosition('[null true]',
    'expected , or ]', 'array missing comma after null', 6, 1, 7);
  ExpectStructuralErrorPosition('{"a":true "b":false}',
    'expected , or }', 'object missing comma after literal value', 10, 1, 11);
end;

procedure TestLiteralBoundaryRegressions;
var
  Doc: IJsonDocument;

  procedure ExpectInvalidLiteral(const AInput, ACase: string);
  begin
    Doc := JsonParse(AInput);
    Check(Doc.HasError, ACase + ' rejected');
    CheckEqual('invalid literal', Doc.Error.Message.ToString,
      ACase + ' error message');
  end;

begin
  ExpectInvalidLiteral('truex', 'top-level true suffix');
  ExpectInvalidLiteral('falsex', 'top-level false suffix');
  ExpectInvalidLiteral('nullx', 'top-level null suffix');
  ExpectInvalidLiteral('[truex]', 'array true suffix');
  ExpectInvalidLiteral('[false2]', 'array false suffix');
  ExpectInvalidLiteral('[nullfoo]', 'array null suffix');
  ExpectInvalidLiteral('tru e', 'split incomplete true');
  ExpectInvalidLiteral('fals e', 'split incomplete false');
  ExpectInvalidLiteral('nul l', 'split incomplete null');
end;

procedure TestStringErrorPositions;
var
  Doc: IJsonDocument;

  procedure ExpectStringErrorPosition(const AInput, ACase: string;
    AExpectedOffset, AExpectedLine, AExpectedColumn: Int64);
  begin
    Doc := JsonParse(AInput);
    Check(Doc.HasError, ACase + ' rejected');
    CheckEqual('invalid escape sequence', Doc.Error.Message.ToString,
      ACase + ' error message');
    CheckEqual(AExpectedOffset, Int64(Doc.Error.Offset),
      ACase + ' error offset');
    CheckEqual(AExpectedLine, Int64(Doc.Error.Line),
      ACase + ' error line');
    CheckEqual(AExpectedColumn, Int64(Doc.Error.Column),
      ACase + ' error column');
  end;

begin
  ExpectStringErrorPosition(
    '{' + #10 +
    '  "x": "ok\q"' + #10 +
    '}',
    'invalid escape',
    12, 2, 11);
  ExpectStringErrorPosition(
    '{"x":"\uD800x"}',
    'unpaired high surrogate',
    6, 1, 7);
  ExpectStringErrorPosition(
    '"\uDC00"',
    'unpaired low surrogate',
    1, 1, 2);

  Doc := JsonParse('["a' + #10 + 'b"]');
  Check(Doc.HasError, 'bare newline in string rejected');
  CheckEqual('control char in string', Doc.Error.Message.ToString,
    'bare newline error message');
  CheckEqual(Int64(3), Int64(Doc.Error.Offset),
    'bare newline error offset');
  CheckEqual(Int64(1), Int64(Doc.Error.Line),
    'bare newline error line');
  CheckEqual(Int64(4), Int64(Doc.Error.Column),
    'bare newline error column');
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

procedure TestConsecutiveBackslashes;
var
  Buf: array[0..1099] of AnsiChar;
  I, PrefixLen: Int32;
  Doc: IJsonDocument;
  S: string;
  Decoded: string;
begin
  Buf[0] := '"';
  for I := 1 to 100 do Buf[I] := '\';
  Buf[101] := '"';
  SetString(S, @Buf[0], 102);
  Doc := JsonParse(S);
  Check(not Doc.HasError, '100 consecutive backslashes parsed');
  CheckEqual(Int64(50), Int64(Doc.Root.AsStr.Len), '100 bs = 50 decoded');
  CheckEqual(StringOfChar('\', 50), Doc.Root.AsStr.ToString,
    '100 bs decoded content');

  Buf[0] := '"';
  for I := 1 to 99 do Buf[I] := '\';
  Buf[100] := '"';
  Buf[101] := '"';
  SetString(S, @Buf[0], 102);
  Doc := JsonParse(S);
  Check(not Doc.HasError, '99 consecutive backslashes plus escaped quote parsed');
  CheckEqual(Int64(50), Int64(Doc.Root.AsStr.Len),
    '99 bs plus quote decoded length');
  Decoded := Doc.Root.AsStr.ToString;
  CheckEqual(StringOfChar('\', 49) + '"', Decoded,
    '99 bs plus quote decoded content');

  Buf[0] := '"';
  PrefixLen := VecWidth - 1;
  for I := 1 to PrefixLen do Buf[I] := 'a';
  for I := PrefixLen + 1 to PrefixLen + 3 do Buf[I] := '\';
  Buf[PrefixLen + 4] := '"';
  Buf[PrefixLen + 5] := '"';
  SetString(S, @Buf[0], PrefixLen + 6);
  Doc := JsonParse(S);
  Check(not Doc.HasError, 'cross-chunk odd backslash carry parsed');
  CheckEqual(StringOfChar('a', PrefixLen) + '\"', Doc.Root.AsStr.ToString,
    'cross-chunk odd backslash carry content');

  Buf[0] := '"';
  for I := 1 to VecWidth - 2 do Buf[I] := 'a';
  for I := VecWidth - 1 to VecWidth + 1 do Buf[I] := '\';
  Buf[VecWidth + 2] := '"';
  Buf[VecWidth + 3] := 'b';
  Buf[VecWidth + 4] := '"';
  for I := VecWidth + 5 to (2 * VecWidth) - 1 do Buf[I] := ' ';
  SetString(S, @Buf[0], 2 * VecWidth);
  Doc := JsonParse(S);
  Check(not Doc.HasError, 'simd chunk boundary odd backslash carry parsed');
  CheckEqual(StringOfChar('a', VecWidth - 2) + '\"b',
    Doc.Root.AsStr.ToString, 'simd chunk boundary odd backslash carry content');
end;

procedure TestUnicodeInKey;
var Doc: IJsonDocument;
const
  INPUT = '{"'#195#169'":1}';
begin
  Doc := JsonParse(INPUT);
  Check(not Doc.HasError, 'utf8 key accepted');
end;

procedure TestVeryLongNumber;
var Doc: IJsonDocument;
const
  INPUT = '1234567890123456789012345678901234567890';
begin
  Doc := JsonParse(INPUT);
  Check(Doc.HasError, 'very long bare integer rejected');
  CheckEqual('number overflow', Doc.Error.Message.ToString,
    'very long bare integer error message');
end;

procedure TestNestedNumberErrorPositions;
var
  Doc: IJsonDocument;

  procedure ExpectNumberErrorPosition(const AInput, AExpectedMessage,
    ACase: string; AExpectedOffset, AExpectedLine, AExpectedColumn: Int64);
  begin
    Doc := JsonParse(AInput);
    Check(Doc.HasError, ACase + ' rejected');
    CheckEqual(AExpectedMessage, Doc.Error.Message.ToString,
      ACase + ' error message');
    CheckEqual(AExpectedOffset, Int64(Doc.Error.Offset),
      ACase + ' error offset');
    CheckEqual(AExpectedLine, Int64(Doc.Error.Line),
      ACase + ' error line');
    CheckEqual(AExpectedColumn, Int64(Doc.Error.Column),
      ACase + ' error column');
  end;

begin
  ExpectNumberErrorPosition('{"n":9223372036854775808}',
    'number overflow', 'object int64 overflow', 5, 1, 6);
  ExpectNumberErrorPosition('[0, 1e1000]',
    'number overflow', 'array float overflow', 4, 1, 5);
  ExpectNumberErrorPosition('{' + #13#10 + '  "n": 01' + #10 + '}',
    'invalid number', 'object invalid number after CRLF', 10, 2, 8);
  ExpectNumberErrorPosition('{' + #13#10 + '  "n": 1e+}' + #10 + '}',
    'invalid number', 'object exponent without digits after CRLF',
    13, 2, 11);
end;

procedure TestNestedObjects;
var
  B: TStringBuilder;
  W: TJsonWriter;
  Doc: IJsonDocument;
  I: Int32;
begin
  B.Init(4096);
  W.Init(B);
  for I := 1 to 50 do
  begin
    W.BeginObject;
    W.Key('n');
  end;
  W.Int(42);
  for I := 1 to 50 do
    W.EndObject;
  Doc := JsonParse(B.ToString);
  Check(not Doc.HasError, '50-deep nested objects');
  B.Done;
end;

procedure TestEmptyStringKey;
var Doc: IJsonDocument;
begin
  Doc := JsonParse('{"":1}');
  Check(not Doc.HasError, 'empty key accepted');
  CheckEqual(Int64(1), Doc.Root.ObjectGet('').AsInt, 'empty key lookup');
end;

procedure TestRepeatedParse;
var Doc: IJsonDocument; I: Int32;
begin
  for I := 1 to 100 do
  begin
    Doc := JsonParse('{"i":' + IntToStr(I) + '}');
    Check(not Doc.HasError, 'parse ' + IntToStr(I));
    CheckEqual(Int64(I), Doc.Root.ObjectGet('i').AsInt, 'val ' + IntToStr(I));
  end;
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
  T.Run('structural error positions', @TestStructuralErrorPositions);
  T.Run('literal boundary regressions', @TestLiteralBoundaryRegressions);
  T.Run('string error positions', @TestStringErrorPositions);
  T.Run('access on wrong type', @TestAccessOnWrongType);
  T.Run('stress large array', @TestStressLargeArray);
  T.Run('consecutive backslashes', @TestConsecutiveBackslashes);
  T.Run('unicode in key', @TestUnicodeInKey);
  T.Run('very long number', @TestVeryLongNumber);
  T.Run('nested number error positions', @TestNestedNumberErrorPositions);
  T.Run('nested objects', @TestNestedObjects);
  T.Run('empty string key', @TestEmptyStringKey);
  T.Run('repeated parse', @TestRepeatedParse);
  T.Summary;
end.
