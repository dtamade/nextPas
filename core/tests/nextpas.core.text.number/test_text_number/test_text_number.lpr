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

begin
  T := TTestRunner.Create('nextpas.core.text.number');
  T.Run('IntToBuffer', @TestIntToBuffer);
  T.Run('UIntToBuffer', @TestUIntToBuffer);
  T.Run('IntToHexBuffer', @TestHexBuffer);
  T.Run('ParseInt64', @TestParseInt64);
  T.Run('ParseUInt64', @TestParseUInt64);
  T.Run('ViewToInt64', @TestViewToInt);
  T.Run('digit pairs 0-999', @TestDigitPairsCorrectness);
  T.Summary;
end.
