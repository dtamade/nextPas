program test_toml_property;
{ Property-based + boundary + combination + zero-safety tests.
  Designed to systematically expose bugs that happy-path tests miss.

  Test philosophy: "try to break the code" not "verify it works".

  Covers:
  - P0: Roundtrip property (random TOML → stringify → reparse → compare)
  - P1: Boundary value matrix (0/1/max/max+1 for all numeric params)
  - P1: Feature combination matrix (inline×dotted, array×table, etc.)
  - P2: Zero-value safety (Default(T) on all APIs)
  - P2: Negative variant generation (systematic rejection testing) }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.mem.default,
  nextpas.core.toml.base,
  nextpas.core.toml.parser,
  nextpas.core.toml.value,
  nextpas.core.toml.writer,
  nextpas.core.toml.builder,
  nextpas.core.toml,
  nextpas.core.testing;

var
  T: TTestRunner;
  GSeed: UInt32 = 42;

function Rng: UInt32;
begin
  GSeed := GSeed xor (GSeed shl 13);
  GSeed := GSeed xor (GSeed shr 17);
  GSeed := GSeed xor (GSeed shl 5);
  Result := GSeed;
end;

{ === P0: Roundtrip Property Testing === }

procedure TestRoundTripRandomStrings;
var
  LDoc1, LDoc2: ITomlDocument;
  LInput, LStr: string;
  LI, LJ: Integer;
  LCh: AnsiChar;
begin
  for LI := 1 to 100 do
  begin
    LInput := 'k' + IntToStr(LI) + ' = "';
    for LJ := 1 to (Rng mod 50) + 1 do
    begin
      case Rng mod 10 of
        0..6: LCh := AnsiChar(Ord('a') + Rng mod 26);
        7: LCh := ' ';
        8: LCh := AnsiChar(Ord('0') + Rng mod 10);
        9: LCh := '_';
      end;
      LInput := LInput + LCh;
    end;
    LInput := LInput + '"' + #10;
  end;
  LDoc1 := TomlParse(LInput);
  Check(not LDoc1.HasError, 'random strings parse');
  LStr := LDoc1.Stringify;
  LDoc2 := TomlParse(LStr);
  Check(not LDoc2.HasError, 'random strings roundtrip parse');
  CheckEqual(Int64(LDoc1.Root.TableLen), Int64(LDoc2.Root.TableLen), 'roundtrip key count');
end;

procedure TestRoundTripRandomIntegers;
var
  LDoc1, LDoc2: ITomlDocument;
  LInput, LStr: string;
  LI: Integer;
  LVal: Int64;
begin
  LInput := '';
  for LI := 1 to 50 do
  begin
    LVal := Int64(Rng) * Int64(Rng) - Int64(High(Int32));
    LInput := LInput + 'n' + IntToStr(LI) + ' = ' + IntToStr(LVal) + #10;
  end;
  LDoc1 := TomlParse(LInput);
  Check(not LDoc1.HasError, 'random ints parse');
  LStr := LDoc1.Stringify;
  LDoc2 := TomlParse(LStr);
  Check(not LDoc2.HasError, 'random ints roundtrip');
  for LI := 1 to 50 do
    CheckEqual(LDoc1.Root.Get('n' + IntToStr(LI)).AsInt,
      LDoc2.Root.Get('n' + IntToStr(LI)).AsInt, 'int ' + IntToStr(LI));
end;

procedure TestRoundTripNestedTables;
var
  LDoc1, LDoc2: ITomlDocument;
  LInput, LStr: string;
  LI: Integer;
begin
  LInput := '';
  for LI := 1 to 20 do
    LInput := LInput + '[t' + IntToStr(LI) + ']' + #10 +
      'val = ' + IntToStr(LI * 100) + #10 +
      'name = "section_' + IntToStr(LI) + '"' + #10;
  LDoc1 := TomlParse(LInput);
  Check(not LDoc1.HasError, 'nested tables parse');
  LStr := LDoc1.Stringify;
  LDoc2 := TomlParse(LStr);
  Check(not LDoc2.HasError, 'nested tables roundtrip');
  for LI := 1 to 20 do
    CheckEqual(Int64(LI * 100), LDoc2.Root.Get('t' + IntToStr(LI)).Get('val').AsInt,
      'table ' + IntToStr(LI));
end;

procedure TestRoundTripArrayTables;
var
  LDoc1, LDoc2: ITomlDocument;
  LInput, LStr: string;
  LI: Integer;
begin
  LInput := '';
  for LI := 1 to 30 do
    LInput := LInput + '[[entries]]' + #10 + 'id = ' + IntToStr(LI) + #10;
  LDoc1 := TomlParse(LInput);
  Check(not LDoc1.HasError, 'array tables parse');
  LStr := LDoc1.Stringify;
  LDoc2 := TomlParse(LStr);
  Check(not LDoc2.HasError, 'array tables roundtrip');
  CheckEqual(Int64(30), Int64(LDoc2.Root.Get('entries').ArrayLen), 'roundtrip 30 entries');
  CheckEqual(Int64(15), LDoc2.Root.Get('entries').ArrayGet(14).Get('id').AsInt, 'entry 15');
end;

{ === P1: Boundary Value Matrix === }

procedure TestIntegerBoundaries;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('max = 9223372036854775807');
  Check(not LDoc.HasError, 'Int64 max ok');
  CheckEqual(Int64(9223372036854775807), LDoc.Root.Get('max').AsInt, 'max value');

  LDoc := TomlParse('min = -9223372036854775808');
  Check(not LDoc.HasError, 'Int64 min ok');
  CheckEqual(Int64(-9223372036854775808), LDoc.Root.Get('min').AsInt, 'min value');

  LDoc := TomlParse('over = 9223372036854775808');
  Check(LDoc.HasError, 'Int64 max+1 rejected');

  LDoc := TomlParse('hex_max = 0x7FFFFFFFFFFFFFFF');
  Check(not LDoc.HasError, 'hex Int64 max ok');

  LDoc := TomlParse('hex_over = 0x8000000000000000');
  Check(LDoc.HasError, 'hex Int64 max+1 rejected');

  LDoc := TomlParse('oct_max = 0o777777777777777777777');
  Check(not LDoc.HasError, 'oct Int64 max ok');

  LDoc := TomlParse('bin_63 = 0b' + StringOfChar('1', 63));
  Check(not LDoc.HasError, 'bin 63 bits ok');

  LDoc := TomlParse('bin_64 = 0b1' + StringOfChar('0', 63));
  Check(LDoc.HasError, 'bin 64 bits (MSB set) rejected');
end;

procedure TestDepthBoundaries;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
begin
  // Exactly 128 nested arrays
  LInput := 'x = ';
  for LI := 1 to 128 do LInput := LInput + '[';
  LInput := LInput + '1';
  for LI := 1 to 128 do LInput := LInput + ']';
  LDoc := TomlParse(LInput);
  Check(not LDoc.HasError, '128 depth ok');

  // 129 nested arrays
  LInput := 'x = ';
  for LI := 1 to 129 do LInput := LInput + '[';
  LInput := LInput + '1';
  for LI := 1 to 129 do LInput := LInput + ']';
  LDoc := TomlParse(LInput);
  Check(LDoc.HasError, '129 depth rejected');

  // 128 nested inline tables
  LInput := 'x = ';
  for LI := 1 to 128 do LInput := LInput + '{a=';
  LInput := LInput + '1';
  for LI := 1 to 128 do LInput := LInput + '}';
  LDoc := TomlParse(LInput);
  Check(not LDoc.HasError, '128 inline depth ok');
end;

{ === P1: Feature Combination Matrix === }

procedure TestCombinationInlineDotted;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('t = {a.b.c = 1, a.b.d = 2, a.e = 3, f = 4}');
  Check(not LDoc.HasError, 'inline+dotted parse');
  CheckEqual(Int64(2), Int64(LDoc.Root.Get('t').TableLen), 't has 2 direct (a, f)');
  CheckEqual(Int64(2), Int64(LDoc.Root.Get('t').Get('a').Get('b').TableLen), 'a.b has 2 (c, d)');
  CheckEqual(Int64(4), LDoc.Root.Get('t').Get('f').AsInt, 'f = 4');
end;

procedure TestCombinationArrayTableNested;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse(
    '[[a.b]]' + #10 + 'x = 1' + #10 +
    '[[a.b]]' + #10 + 'x = 2' + #10 +
    '[a]' + #10 + 'c = 3');
  Check(not LDoc.HasError, 'array-table nested + parent');
  CheckEqual(Int64(2), Int64(LDoc.Root.Get('a').Get('b').ArrayLen), 'a.b has 2');
  CheckEqual(Int64(3), LDoc.Root.Get('a').Get('c').AsInt, 'a.c = 3');
end;

procedure TestCombinationEscapedKeyRoundTrip;
var LDoc1, LDoc2: ITomlDocument;
begin
  LDoc1 := TomlParse('"key\twith\ttabs" = "value"');
  Check(not LDoc1.HasError, 'escaped key parse');
  LDoc2 := TomlParse(LDoc1.Stringify);
  Check(not LDoc2.HasError, 'escaped key roundtrip');
end;

procedure TestCombinationMixedArrayTypes;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('a = [1, "two", 3.0, true, 2024-01-01]');
  Check(not LDoc.HasError, 'mixed array accepted (v1.1)');
  CheckEqual(Int64(5), Int64(LDoc.Root.Get('a').ArrayLen), '5 elements');
end;

{ === P2: Zero-Value Safety === }

procedure TestZeroValueTTomlValue;
var
  LVal: TTomlValue;
begin
  FillChar(LVal, SizeOf(LVal), 0);
  Check(not LVal.IsValid, 'zero TTomlValue not valid');
  CheckEqual(Int64(0), LVal.AsInt, 'zero AsInt = 0');
  Check(not LVal.AsBool, 'zero AsBool = false');
  CheckEqual(Int64(0), Int64(LVal.TableLen), 'zero TableLen = 0');
  CheckEqual(Int64(0), Int64(LVal.ArrayLen), 'zero ArrayLen = 0');
  Check(LVal.AsStr.IsEmpty, 'zero AsStr empty');
  Check(not LVal.Has('x'), 'zero Has = false');
  Check(LVal.Key.IsEmpty, 'zero Key empty');
  CheckEqual('', LVal.AsString, 'zero AsString empty');
end;

{ === P2: Systematic Rejection Variants === }

procedure TestRejectionVariantsNumber;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = 00'); Check(LDoc.HasError, '00');
  LDoc := TomlParse('x = 01'); Check(LDoc.HasError, '01');
  LDoc := TomlParse('x = +01'); Check(LDoc.HasError, '+01');
  LDoc := TomlParse('x = -01'); Check(LDoc.HasError, '-01');
  LDoc := TomlParse('x = 00.0'); Check(LDoc.HasError, '00.0');
  LDoc := TomlParse('x = 03.14'); Check(LDoc.HasError, '03.14');
  LDoc := TomlParse('x = 1__2'); Check(LDoc.HasError, '1__2');
  LDoc := TomlParse('x = _1'); Check(LDoc.HasError, '_1');
  LDoc := TomlParse('x = 1_'); Check(LDoc.HasError, '1_');
  LDoc := TomlParse('x = 1.'); Check(LDoc.HasError, '1.');
  LDoc := TomlParse('x = .1'); Check(LDoc.HasError, '.1');
  LDoc := TomlParse('x = 1e'); Check(LDoc.HasError, '1e');
  LDoc := TomlParse('x = 1e+'); Check(LDoc.HasError, '1e+');
  LDoc := TomlParse('x = +0x1'); Check(LDoc.HasError, '+0x1');
  LDoc := TomlParse('x = -0b1'); Check(LDoc.HasError, '-0b1');
  LDoc := TomlParse('x = 0X1'); Check(LDoc.HasError, '0X1');
  LDoc := TomlParse('x = 0B1'); Check(LDoc.HasError, '0B1');
  LDoc := TomlParse('x = 0O1'); Check(LDoc.HasError, '0O1');
  LDoc := TomlParse('x = Inf'); Check(LDoc.HasError, 'Inf');
  LDoc := TomlParse('x = NaN'); Check(LDoc.HasError, 'NaN');
end;

procedure TestRejectionVariantsDateTime;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = 2024-13-01T00:00:00Z'); Check(LDoc.HasError, 'month 13');
  LDoc := TomlParse('x = 2024-00-01T00:00:00Z'); Check(LDoc.HasError, 'month 0');
  LDoc := TomlParse('x = 2024-01-32T00:00:00Z'); Check(LDoc.HasError, 'day 32');
  LDoc := TomlParse('x = 2024-01-00T00:00:00Z'); Check(LDoc.HasError, 'day 0');
  LDoc := TomlParse('x = 2024-02-30T00:00:00Z'); Check(LDoc.HasError, 'Feb 30');
  LDoc := TomlParse('x = 2023-02-29T00:00:00Z'); Check(LDoc.HasError, 'non-leap Feb 29');
  LDoc := TomlParse('x = 2024-04-31T00:00:00Z'); Check(LDoc.HasError, 'Apr 31');
  LDoc := TomlParse('x = 2024-01-01T24:00:00Z'); Check(LDoc.HasError, 'hour 24');
  LDoc := TomlParse('x = 2024-01-01T00:60:00Z'); Check(LDoc.HasError, 'minute 60');
  LDoc := TomlParse('x = 2024-01-01T00:00:61Z'); Check(LDoc.HasError, 'second 61');
  LDoc := TomlParse('x = 07:32:00Z'); Check(LDoc.HasError, 'time-only offset');
  LDoc := TomlParse('x = 2024-01-01T00:00:00.Z'); Check(LDoc.HasError, 'fraction no digits');
end;

procedure TestRejectionVariantsTable;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('[a]' + #10 + 'x = 1' + #10 + '[a]' + #10 + 'y = 2');
  Check(LDoc.HasError, 'duplicate [a]');
  LDoc := TomlParse('a.b = 1' + #10 + '[a]' + #10 + 'c = 2');
  Check(LDoc.HasError, 'dotted then [a]');
  LDoc := TomlParse('a = {x = 1}' + #10 + 'a.y = 2');
  Check(LDoc.HasError, 'inline extend');
  LDoc := TomlParse('a = {x = 1}' + #10 + '[a]' + #10 + 'y = 2');
  Check(LDoc.HasError, 'inline reopen');
  LDoc := TomlParse('a = [1]' + #10 + '[[a]]' + #10 + 'x = 1');
  Check(LDoc.HasError, 'value array then [[]]');
  LDoc := TomlParse('[[a]]' + #10 + 'x = 1' + #10 + '[a]' + #10 + 'y = 2');
  Check(LDoc.HasError, '[[a]] then [a]');
  LDoc := TomlParse('a = 1' + #10 + 'a = 2');
  Check(LDoc.HasError, 'duplicate key');
  LDoc := TomlParse('a = {b = 1, b = 2}');
  Check(LDoc.HasError, 'inline dup key');
end;

begin
  T := TTestRunner.Create('nextpas.core.toml property');
  { P0: Roundtrip }
  T.Run('roundtrip random strings', @TestRoundTripRandomStrings);
  T.Run('roundtrip random integers', @TestRoundTripRandomIntegers);
  T.Run('roundtrip nested tables', @TestRoundTripNestedTables);
  T.Run('roundtrip array tables', @TestRoundTripArrayTables);
  { P1: Boundaries }
  T.Run('integer boundaries', @TestIntegerBoundaries);
  T.Run('depth boundaries', @TestDepthBoundaries);
  { P1: Combinations }
  T.Run('combination inline+dotted', @TestCombinationInlineDotted);
  T.Run('combination array-table nested', @TestCombinationArrayTableNested);
  T.Run('combination escaped key roundtrip', @TestCombinationEscapedKeyRoundTrip);
  T.Run('combination mixed array', @TestCombinationMixedArrayTypes);
  { P2: Zero Safety }
  T.Run('zero-value TTomlValue', @TestZeroValueTTomlValue);
  { P2: Rejection Variants }
  T.Run('rejection variants number', @TestRejectionVariantsNumber);
  T.Run('rejection variants datetime', @TestRejectionVariantsDateTime);
  T.Run('rejection variants table', @TestRejectionVariantsTable);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
