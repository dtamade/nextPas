program test_text_number;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.text.number,
  nextpas.core.text.view,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestIntToBuffer;
var
  Buf: array[0..24] of AnsiChar;
  N: Int32;
begin
  N := IntToBuffer(0, @Buf[0]); Buf[N] := #0;
  CheckEqual('0', string(PAnsiChar(@Buf[0])), '0');

  N := IntToBuffer(42, @Buf[0]); Buf[N] := #0;
  CheckEqual('42', string(PAnsiChar(@Buf[0])), '42');

  N := IntToBuffer(-1, @Buf[0]); Buf[N] := #0;
  CheckEqual('-1', string(PAnsiChar(@Buf[0])), '-1');

  N := IntToBuffer(9223372036854775807, @Buf[0]); Buf[N] := #0;
  CheckEqual('9223372036854775807', string(PAnsiChar(@Buf[0])), 'max int64');

  N := IntToBuffer(-9223372036854775808, @Buf[0]); Buf[N] := #0;
  CheckEqual('-9223372036854775808', string(PAnsiChar(@Buf[0])), 'min int64');

  N := IntToBuffer(100, @Buf[0]); Buf[N] := #0;
  CheckEqual('100', string(PAnsiChar(@Buf[0])), '100');

  N := IntToBuffer(12345678, @Buf[0]); Buf[N] := #0;
  CheckEqual('12345678', string(PAnsiChar(@Buf[0])), '12345678');
end;

procedure TestUIntToBuffer;
var
  Buf: array[0..24] of AnsiChar;
  N: Int32;
begin
  N := UIntToBuffer(0, @Buf[0]); Buf[N] := #0;
  CheckEqual('0', string(PAnsiChar(@Buf[0])), '0');

  N := UIntToBuffer(18446744073709551615, @Buf[0]); Buf[N] := #0;
  CheckEqual('18446744073709551615', string(PAnsiChar(@Buf[0])), 'max uint64');

  N := UIntToBuffer(99, @Buf[0]); Buf[N] := #0;
  CheckEqual('99', string(PAnsiChar(@Buf[0])), '99');
end;

procedure TestHexBuffer;
var
  Buf: array[0..20] of AnsiChar;
  N: Int32;
begin
  N := IntToHexBuffer(0, @Buf[0], 1); Buf[N] := #0;
  CheckEqual('0', string(PAnsiChar(@Buf[0])), '0');

  N := IntToHexBuffer($FF, @Buf[0], 2); Buf[N] := #0;
  CheckEqual('ff', string(PAnsiChar(@Buf[0])), 'ff');

  N := IntToHexBuffer($DEADBEEF, @Buf[0], 8); Buf[N] := #0;
  CheckEqual('deadbeef', string(PAnsiChar(@Buf[0])), 'deadbeef');

  N := IntToHexBuffer($A, @Buf[0], 4); Buf[N] := #0;
  CheckEqual('000a', string(PAnsiChar(@Buf[0])), '000a padded');
end;

procedure TestParseInt64;
var
  V: Int64;
begin
  Check(ParseInt64(PAnsiChar('0'), 1, V), 'parse 0');
  CheckEqual(Int64(0), V, 'val 0');

  Check(ParseInt64(PAnsiChar('42'), 2, V), 'parse 42');
  CheckEqual(Int64(42), V, 'val 42');

  Check(ParseInt64(PAnsiChar('-1'), 2, V), 'parse -1');
  CheckEqual(Int64(-1), V, 'val -1');

  Check(ParseInt64(PAnsiChar('9223372036854775807'), 19, V), 'parse max');
  CheckEqual(Int64(9223372036854775807), V, 'val max');

  Check(ParseInt64(PAnsiChar('-9223372036854775808'), 20, V), 'parse min');
  CheckEqual(Int64(-9223372036854775808), V, 'val min');

  Check(not ParseInt64(PAnsiChar(''), 0, V), 'empty');
  Check(not ParseInt64(PAnsiChar('abc'), 3, V), 'non-digit');
  Check(not ParseInt64(PAnsiChar('9223372036854775808'), 19, V), 'overflow');
end;

procedure TestParseUInt64;
var
  V: UInt64;
begin
  Check(ParseUInt64(PAnsiChar('0'), 1, V), 'parse 0');
  CheckEqual(Int64(0), Int64(V), 'val 0');

  Check(ParseUInt64(PAnsiChar('18446744073709551615'), 20, V), 'parse max');
  Check(V = 18446744073709551615, 'val max');

  Check(not ParseUInt64(PAnsiChar(''), 0, V), 'empty');
  Check(not ParseUInt64(PAnsiChar('x'), 1, V), 'non-digit');
end;

procedure TestParseIntegerOverflow;
var
  I: Int64;
  U: UInt64;
begin
  U := 123;
  Check(not ParseUInt64(PAnsiChar('18446744073709551616'), 20, U), 'uint64 max + 1 rejected');
  CheckEqual(Int64(0), Int64(U), 'uint64 failed parse resets output');

  U := 123;
  Check(not ParseUInt64(PAnsiChar('46116860184273879040'), 20, U), 'uint64 wrapped multiply rejected');
  CheckEqual(Int64(0), Int64(U), 'uint64 wrapped parse resets output');

  I := 123;
  Check(not ParseInt64(PAnsiChar('9223372036854775808'), 19, I), 'int64 max + 1 rejected');
  CheckEqual(Int64(0), I, 'positive int64 overflow resets output');

  I := 123;
  Check(not ParseInt64(PAnsiChar('-9223372036854775809'), 20, I), 'int64 min - 1 rejected');
  CheckEqual(Int64(0), I, 'negative int64 overflow resets output');

  I := 123;
  Check(not ParseInt64(PAnsiChar('-46116860184273879040'), 21, I), 'negative wrapped multiply rejected');
  CheckEqual(Int64(0), I, 'negative wrapped parse resets output');
end;

procedure TestViewToInt;
var
  V: TStringView;
  I: Int64;
begin
  V := TStringView.Create(PAnsiChar('-999'), 4);
  Check(ViewToInt64(V, I), 'view parse');
  CheckEqual(Int64(-999), I, 'view val');
end;

procedure TestDigitPairsCorrectness;
var
  Buf: array[0..24] of AnsiChar;
  N, I: Int32;
  S: string;
begin
  for I := 0 to 999 do
  begin
    N := IntToBuffer(Int64(I), @Buf[0]);
    Buf[N] := #0;
    S := SysUtils.IntToStr(I);
    Check(string(PAnsiChar(@Buf[0])) = S, 'mismatch at ' + S);
  end;
end;

procedure TestFloatToBuffer;
var
  Buf: array[0..31] of AnsiChar;
  N: Int32;
  S: string;
begin
  N := FloatToBuffer(0.0, @Buf[0]); Buf[N] := #0;
  CheckEqual('0', string(PAnsiChar(@Buf[0])), '0.0');

  N := FloatToBuffer(1.0, @Buf[0]); Buf[N] := #0;
  CheckEqual('1', string(PAnsiChar(@Buf[0])), '1.0');

  N := FloatToBuffer(-1.0, @Buf[0]); Buf[N] := #0;
  CheckEqual('-1', string(PAnsiChar(@Buf[0])), '-1.0');

  N := FloatToBuffer(1.0/0.0, @Buf[0]); Buf[N] := #0;
  CheckEqual('Infinity', string(PAnsiChar(@Buf[0])), 'inf');

  N := FloatToBuffer(-1.0/0.0, @Buf[0]); Buf[N] := #0;
  CheckEqual('-Infinity', string(PAnsiChar(@Buf[0])), '-inf');

  N := FloatToBuffer(0.0/0.0, @Buf[0]); Buf[N] := #0;
  CheckEqual('NaN', string(PAnsiChar(@Buf[0])), 'nan');
end;

procedure TestParseDouble;
var
  V: Double;
begin
  Check(ParseDouble(PAnsiChar('0'), 1, V), 'parse 0');
  Check(V = 0.0, 'val 0');

  Check(ParseDouble(PAnsiChar('1.5'), 3, V), 'parse 1.5');
  Check(V = 1.5, 'val 1.5');

  Check(ParseDouble(PAnsiChar('-3.14'), 5, V), 'parse -3.14');
  Check(Abs(V - (-3.14)) < 1e-15, 'val -3.14');

  Check(ParseDouble(PAnsiChar('1e10'), 4, V), 'parse 1e10');
  Check(V = 1e10, 'val 1e10');

  Check(ParseDouble(PAnsiChar('1.23e-4'), 7, V), 'parse 1.23e-4');
  Check(Abs(V - 1.23e-4) < 1e-19, 'val 1.23e-4');

  Check(not ParseDouble(PAnsiChar(''), 0, V), 'empty');
  Check(not ParseDouble(PAnsiChar('abc'), 3, V), 'non-number');
  Check(not ParseDouble(PAnsiChar('1e'), 2, V), 'missing exponent digits');
  Check(not ParseDouble(PAnsiChar('1e+'), 3, V), 'missing signed exponent digits');
  Check(not ParseDouble(PAnsiChar('NaNx'), 4, V), 'NaN trailing input');
  Check(not ParseDouble(PAnsiChar('Infinityx'), 9, V), 'Infinity trailing input');
end;

procedure TestParseDoubleRejectsFractionWithoutDigits;
var
  V: Double;
begin
  Check(not ParseDouble(PAnsiChar('1.'), 2, V), 'fraction requires digit after dot');
  Check(not ParseDouble(PAnsiChar('1.e2'), 4, V), 'exponent after dot still requires fraction digit');
end;

procedure TestParseDoubleRejectsOverflowFallback;
var
  V: Double;
  S: AnsiString;
  I: Integer;
begin
  V := 123.0;
  Check(not ParseDouble(PAnsiChar('1e999'), 5, V), 'overflow exponent is rejected');
  Check(V = 0.0, 'overflow exponent resets output');

  V := 123.0;
  Check(not ParseDouble(PAnsiChar('9e308'), 5, V), 'overflow finite exponent is rejected');
  Check(V = 0.0, 'overflow finite exponent resets output');

  SetLength(S, 1100);
  for I := 1 to Length(S) do
    S[I] := '9';

  V := 123.0;
  Check(not ParseDouble(PAnsiChar(S), Length(S), V), 'very long decimal is rejected');
  Check(V = 0.0, 'very long decimal resets output');
end;

procedure TestFloatRoundTrip;
var
  Buf: array[0..31] of AnsiChar;
  N: Int32;
  Original, Parsed: Double;
  I: Int32;
const
  VALS: array[0..9] of Double = (
    0.1, 0.2, 0.3, 1.23456789, -9.87654321,
    1.7976931348623157e308, 2.2250738585072014e-308,
    5e-324, 123456789.0, -0.001
  );
begin
  for I := 0 to High(VALS) do
  begin
    Original := VALS[I];
    N := FloatToBuffer(Original, @Buf[0]);
    Buf[N] := #0;
    Check(ParseDouble(@Buf[0], N, Parsed), 'roundtrip parse ' + string(PAnsiChar(@Buf[0])));
    Check(PUInt64(@Original)^ = PUInt64(@Parsed)^,
      'roundtrip exact ' + string(PAnsiChar(@Buf[0])));
  end;
end;

procedure TestFloatToJsonBuffer;
var
  Buf: array[0..31] of AnsiChar;
  N: Int32;
begin
  N := FloatToJsonBuffer(1.5, @Buf[0]); Buf[N] := #0;
  CheckEqual('1.5', string(PAnsiChar(@Buf[0])), '1.5 normal');

  N := FloatToJsonBuffer(0.0/0.0, @Buf[0]); Buf[N] := #0;
  CheckEqual('null', string(PAnsiChar(@Buf[0])), 'NaN -> null');

  N := FloatToJsonBuffer(1.0/0.0, @Buf[0]); Buf[N] := #0;
  CheckEqual('null', string(PAnsiChar(@Buf[0])), 'Inf -> null');

  N := FloatToJsonBuffer(-1.0/0.0, @Buf[0]); Buf[N] := #0;
  CheckEqual('null', string(PAnsiChar(@Buf[0])), '-Inf -> null');
end;

procedure TestViewToDouble;
var
  V: TStringView;
  D: Double;
begin
  V := TStringView.Create(PAnsiChar('3.14'), 4);
  Check(ViewToDouble(V, D), 'view parse');
  Check(Abs(D - 3.14) < 1e-15, 'view val');

  V := TStringView.Create(PAnsiChar('-1e10'), 5);
  Check(ViewToDouble(V, D), 'view neg exp');
  Check(D = -1e10, 'view neg exp val');

  V := TStringView.Empty;
  Check(not ViewToDouble(V, D), 'empty fails');
end;

begin
  T := TTestRunner.Create('nextpas.core.text.number');
  T.Run('IntToBuffer', @TestIntToBuffer);
  T.Run('UIntToBuffer', @TestUIntToBuffer);
  T.Run('IntToHexBuffer', @TestHexBuffer);
  T.Run('ParseInt64', @TestParseInt64);
  T.Run('ParseUInt64', @TestParseUInt64);
  T.Run('Parse integer overflow', @TestParseIntegerOverflow);
  T.Run('ViewToInt64', @TestViewToInt);
  T.Run('digit pairs 0-999', @TestDigitPairsCorrectness);
  T.Run('FloatToBuffer', @TestFloatToBuffer);
  T.Run('FloatToJsonBuffer', @TestFloatToJsonBuffer);
  T.Run('ParseDouble', @TestParseDouble);
  T.Run('ParseDouble rejects empty fraction', @TestParseDoubleRejectsFractionWithoutDigits);
  T.Run('ParseDouble rejects overflow fallback', @TestParseDoubleRejectsOverflowFallback);
  T.Run('ViewToDouble', @TestViewToDouble);
  T.Run('float round-trip', @TestFloatRoundTrip);
  T.Summary;
end.
