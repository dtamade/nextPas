program test_toml_roundtrip;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.toml.base,
  nextpas.core.toml.value,
  nextpas.core.toml.writer,
  nextpas.core.toml,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure VerifyRoundTrip(const AInput: string; const ALabel: string);
var
  LDoc1, LDoc2: ITomlDocument;
  LStr: string;
begin
  LDoc1 := TomlParse(AInput);
  if LDoc1.HasError then
    Fail(ALabel + ': initial parse failed: ' + LDoc1.Error.Message.ToString);
  LStr := LDoc1.Stringify;
  LDoc2 := TomlParse(LStr);
  if LDoc2.HasError then
    Fail(ALabel + ': round-trip parse failed: ' + LDoc2.Error.Message.ToString +
      ' | stringified: ' + LStr);
end;

procedure CompareValues(const AV1, AV2: TTomlValue; const APath: string); forward;

procedure CompareTables(const AV1, AV2: TTomlValue; const APath: string);
var
  LI: UInt32;
  LKey: TStringView;
  LChild1, LChild2: TTomlValue;
begin
  CheckEqual(Int64(AV1.TableLen), Int64(AV2.TableLen), APath + ' table len');
  if AV1.TableLen > 0 then
  for LI := 0 to AV1.TableLen - 1 do
  begin
    LKey := AV1.TableKeyAt(LI);
    LChild1 := AV1.TableValueAt(LI);
    LChild2 := AV2.Get(LKey);
    if not LChild2.IsValid then
      Fail(APath + '.' + LKey.ToString + ' missing in round-trip');
    CompareValues(LChild1, LChild2, APath + '.' + LKey.ToString);
  end;
end;

procedure CompareValues(const AV1, AV2: TTomlValue; const APath: string);
var
  LI: UInt32;
begin
  Check(AV1.Kind = AV2.Kind, APath + ' kind mismatch');
  case AV1.Kind of
    tnkString:
      Check(AV1.AsStr.Equals(AV2.AsStr), APath + ' string mismatch');
    tnkInt:
      CheckEqual(AV1.AsInt, AV2.AsInt, APath + ' int');
    tnkFloat:
    begin
      if AV1.AsFloat <> AV1.AsFloat then
        Check(AV2.AsFloat <> AV2.AsFloat, APath + ' both NaN')
      else
        Check(Abs(AV1.AsFloat - AV2.AsFloat) < 1e-10, APath + ' float');
    end;
    tnkBool:
      CheckEqual(AV1.AsBool, AV2.AsBool, APath + ' bool');
    tnkDateTime:
    begin
      CheckEqual(Int64(AV1.AsDateTime.Year), Int64(AV2.AsDateTime.Year), APath + ' dt.year');
      CheckEqual(Int64(AV1.AsDateTime.Month), Int64(AV2.AsDateTime.Month), APath + ' dt.month');
      CheckEqual(Int64(AV1.AsDateTime.Day), Int64(AV2.AsDateTime.Day), APath + ' dt.day');
      CheckEqual(Int64(AV1.AsDateTime.Hour), Int64(AV2.AsDateTime.Hour), APath + ' dt.hour');
      CheckEqual(Int64(AV1.AsDateTime.Minute), Int64(AV2.AsDateTime.Minute), APath + ' dt.min');
      CheckEqual(Int64(AV1.AsDateTime.Second), Int64(AV2.AsDateTime.Second), APath + ' dt.sec');
    end;
    tnkArray:
    begin
      CheckEqual(Int64(AV1.ArrayLen), Int64(AV2.ArrayLen), APath + ' array len');
      if AV1.ArrayLen > 0 then
      for LI := 0 to AV1.ArrayLen - 1 do
        CompareValues(AV1.ArrayGet(LI), AV2.ArrayGet(LI), APath + '[' + IntToStr(LI) + ']');
    end;
    tnkTable:
      CompareTables(AV1, AV2, APath);
  end;
end;

procedure VerifyDeepRoundTrip(const AInput: string; const ALabel: string);
var
  LDoc1, LDoc2: ITomlDocument;
  LStr: string;
begin
  LDoc1 := TomlParse(AInput);
  if LDoc1.HasError then
    Fail(ALabel + ': initial parse failed');
  LStr := LDoc1.Stringify;
  LDoc2 := TomlParse(LStr);
  if LDoc2.HasError then
    Fail(ALabel + ': round-trip parse failed: ' + LDoc2.Error.Message.ToString);
  CompareTables(LDoc1.Root, LDoc2.Root, ALabel);
end;

procedure TestSimpleKV;
begin
  VerifyDeepRoundTrip('name = "Alice"' + #10 + 'age = 30' + #10 + 'active = true', 'simple kv');
end;

procedure TestNestedTables;
begin
  VerifyDeepRoundTrip(
    '[server]' + #10 + 'host = "localhost"' + #10 + 'port = 8080' + #10 +
    '[database]' + #10 + 'url = "postgres://localhost"' + #10 + 'pool = 20',
    'nested tables');
end;

procedure TestArrays;
begin
  VerifyDeepRoundTrip(
    'nums = [1, 2, 3]' + #10 + 'tags = ["a", "b", "c"]',
    'arrays');
end;

procedure TestInlineTable;
begin
  VerifyRoundTrip('point = {x = 1, y = 2}', 'inline table');
end;

procedure TestDateTime;
begin
  VerifyDeepRoundTrip(
    'dt1 = 2024-01-15T10:30:00Z' + #10 +
    'dt2 = 2024-06-15T14:00:00+09:00' + #10 +
    'd = 2024-01-15' + #10 +
    't = 07:32:00',
    'datetime');
end;

procedure TestFloats;
begin
  VerifyDeepRoundTrip(
    'pi = 3.14159' + #10 + 'neg = -0.5' + #10 + 'sci = 1.5e10',
    'floats');
end;

procedure TestEscapedStrings;
begin
  VerifyDeepRoundTrip(
    'msg = "hello\nworld"' + #10 + 'tab = "col1\tcol2"',
    'escaped strings');
end;

procedure TestDottedKeys;
begin
  VerifyRoundTrip('a.b.c = "deep"', 'dotted keys');
end;

procedure TestArrayTable;
begin
  VerifyRoundTrip(
    '[[products]]' + #10 + 'name = "Hammer"' + #10 +
    '[[products]]' + #10 + 'name = "Nail"',
    'array table');
end;

procedure TestComplexConfig;
const
  CONFIG =
    '[package]' + #10 +
    'name = "my-app"' + #10 +
    'version = "1.0.0"' + #10 +
    'authors = ["Alice", "Bob"]' + #10 + #10 +
    '[server]' + #10 +
    'host = "0.0.0.0"' + #10 +
    'port = 443' + #10 +
    'tls = true' + #10 + #10 +
    '[database]' + #10 +
    'url = "postgres://localhost:5432/db"' + #10 +
    'pool_size = 20' + #10;
begin
  VerifyDeepRoundTrip(CONFIG, 'complex config');
end;

procedure TestSpecialCharsInStrings;
begin
  VerifyDeepRoundTrip(
    'tab = "a\tb"' + #10 +
    'newline = "line1\nline2"' + #10 +
    'quote = "she said \"hi\""' + #10 +
    'backslash = "C:\\path"',
    'special chars');
end;

procedure TestEmptyValues;
begin
  VerifyDeepRoundTrip(
    'empty_str = ""' + #10 +
    'empty_arr = []' + #10 +
    'empty_tbl = {}',
    'empty values');
end;

procedure TestNegativeNumbers;
begin
  VerifyDeepRoundTrip(
    'neg_int = -42' + #10 +
    'neg_float = -3.14' + #10 +
    'zero = 0',
    'negative numbers');
end;

procedure TestLargeIntegers;
begin
  VerifyDeepRoundTrip(
    'big = 9223372036854775807' + #10 +
    'small = -9223372036854775808',
    'large integers');
end;

procedure TestNestedArrays;
begin
  VerifyDeepRoundTrip(
    'matrix = [[1, 2], [3, 4], [5, 6]]',
    'nested arrays');
end;

procedure TestMixedTable;
begin
  VerifyDeepRoundTrip(
    'name = "root"' + #10 +
    'count = 5' + #10 +
    '[sub]' + #10 +
    'x = 1' + #10 +
    'y = 2',
    'mixed table');
end;

begin
  T := TTestRunner.Create('nextpas.core.toml roundtrip');
  T.Run('simple key-value', @TestSimpleKV);
  T.Run('nested tables', @TestNestedTables);
  T.Run('arrays', @TestArrays);
  T.Run('inline table', @TestInlineTable);
  T.Run('datetime', @TestDateTime);
  T.Run('floats', @TestFloats);
  T.Run('escaped strings', @TestEscapedStrings);
  T.Run('dotted keys', @TestDottedKeys);
  T.Run('array table', @TestArrayTable);
  T.Run('complex config', @TestComplexConfig);
  T.Run('special chars in strings', @TestSpecialCharsInStrings);
  T.Run('empty values', @TestEmptyValues);
  T.Run('negative numbers', @TestNegativeNumbers);
  T.Run('large integers', @TestLargeIntegers);
  T.Run('nested arrays', @TestNestedArrays);
  T.Run('mixed table', @TestMixedTable);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
