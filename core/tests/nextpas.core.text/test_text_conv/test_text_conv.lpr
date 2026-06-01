program test_text_conv;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.text.conv,
  nextpas.core.text.format;

var
  T: TTestRunner;

{ conv tests }

procedure TestIntToStr;
begin
  CheckEqual('0', IntToStr(0));
  CheckEqual('1', IntToStr(1));
  CheckEqual('-1', IntToStr(-1));
  CheckEqual('123456789', IntToStr(123456789));
  CheckEqual('-9223372036854775808', IntToStr(Low(Int64)));
  CheckEqual('9223372036854775807', IntToStr(High(Int64)));
end;

procedure TestUIntToStr;
begin
  CheckEqual('0', UIntToStr(0));
  CheckEqual('18446744073709551615', UIntToStr(High(UInt64)));
end;

procedure TestIntToHex;
begin
  CheckEqual('0', IntToHex(0, 1));
  CheckEqual('FF', IntToHex($FF, 2));
  CheckEqual('00FF', IntToHex($FF, 4));
  CheckEqual('DEADBEEF', IntToHex($DEADBEEF, 8));
end;

procedure TestTryStrToInt;
var
  LVal: Int64;
begin
  Check(TryStrToInt('42', LVal), '42');
  CheckEqual(Int64(42), LVal);
  Check(TryStrToInt('-100', LVal), '-100');
  CheckEqual(Int64(-100), LVal);
  Check(TryStrToInt('  123  ', LVal), 'whitespace');
  CheckEqual(Int64(123), LVal);
  Check(TryStrToInt('+7', LVal), 'plus sign');
  CheckEqual(Int64(7), LVal);
  Check(not TryStrToInt('', LVal), 'empty');
  Check(not TryStrToInt('abc', LVal), 'non-numeric');
  Check(not TryStrToInt('12x', LVal), 'trailing garbage');
  Check(TryStrToInt('9223372036854775807', LVal), 'max int64');
  CheckEqual(High(Int64), LVal);
  Check(not TryStrToInt('9223372036854775808', LVal), 'overflow');
  Check(TryStrToInt('-9223372036854775808', LVal), 'min int64');
  CheckEqual(Low(Int64), LVal);
end;

procedure TestTryStrToInt32;
var
  LVal: Integer;
begin
  Check(TryStrToInt32('2147483647', LVal), 'max');
  CheckEqual(High(Integer), LVal);
  Check(not TryStrToInt32('2147483648', LVal), 'overflow');
  Check(TryStrToInt32('-2147483648', LVal), 'min');
  CheckEqual(Low(Integer), LVal);
end;

procedure TestTryStrToUInt64;
var
  LVal: UInt64;
begin
  Check(TryStrToUInt64('0', LVal), 'zero');
  CheckEqual(UInt64(0), LVal);
  Check(TryStrToUInt64('18446744073709551615', LVal), 'max');
  Check(LVal = High(UInt64), 'max value');
  Check(not TryStrToUInt64('-1', LVal), 'negative');
  Check(not TryStrToUInt64('18446744073709551616', LVal), 'overflow');
end;

procedure TestFloatToStr;
var
  LS: string;
begin
  CheckEqual('0', FloatToStr(0.0));
  LS := FloatToStr(3.14);
  Check(Length(LS) > 0, 'non-empty');
  Check(Pos('.', LS) > 0, 'has decimal');
end;

procedure TestTryStrToFloat;
var
  LVal: Double;
begin
  Check(TryStrToFloat('3.14', LVal), '3.14');
  Check((LVal > 3.13) and (LVal < 3.15), 'approx');
  Check(TryStrToFloat('-0.5', LVal), 'negative');
  Check((LVal > -0.51) and (LVal < -0.49), 'approx neg');
  Check(TryStrToFloat('  42  ', LVal), 'whitespace');
  Check(not TryStrToFloat('abc', LVal), 'non-numeric');
  Check(not TryStrToFloat('1.2.3', LVal), 'double dot');
end;

procedure TestTextOfChar;
begin
  CheckEqual('', TextOfChar('x', 0));
  CheckEqual('xxx', TextOfChar('x', 3));
  CheckEqual('00000', TextOfChar('0', 5));
end;

{ format tests }

procedure TestFormatBasic;
begin
  CheckEqual('hello', TextFormat('%s', ['hello']));
  CheckEqual('42', TextFormat('%d', [42]));
  CheckEqual('-1', TextFormat('%d', [-1]));
  CheckEqual('100%', TextFormat('%d%%', [100]));
end;

procedure TestFormatHex;
begin
  CheckEqual('ff', TextFormat('%x', [255]));
  CheckEqual('FF', TextFormat('%X', [255]));
  CheckEqual('deadbeef', TextFormat('%x', [Int64($DEADBEEF)]));
end;

procedure TestFormatWidth;
begin
  CheckEqual('042', TextFormat('%03d', [42]));
  CheckEqual('007', TextFormat('%03d', [7]));
  CheckEqual('1234', TextFormat('%02d', [1234]));
end;

procedure TestFormatFloat;
begin
  CheckEqual('3.140000', TextFormat('%f', [3.14]));
  CheckEqual('3.14', TextFormat('%.2f', [3.14]));
  CheckEqual('0.500', TextFormat('%.3f', [0.5]));
end;

procedure TestFormatMultiArg;
begin
  CheckEqual('a=1 b=2', TextFormat('a=%d b=%d', [1, 2]));
  CheckEqual('hello world 42', TextFormat('%s %s %d', ['hello', 'world', 42]));
end;

begin
  T := TTestRunner.Create('nextpas.core.text.conv+format');

  T.Run('IntToStr', @TestIntToStr);
  T.Run('UIntToStr', @TestUIntToStr);
  T.Run('IntToHex', @TestIntToHex);
  T.Run('TryStrToInt', @TestTryStrToInt);
  T.Run('TryStrToInt32', @TestTryStrToInt32);
  T.Run('TryStrToUInt64', @TestTryStrToUInt64);
  T.Run('FloatToStr', @TestFloatToStr);
  T.Run('TryStrToFloat', @TestTryStrToFloat);
  T.Run('TextOfChar', @TestTextOfChar);

  T.Run('Format basic', @TestFormatBasic);
  T.Run('Format hex', @TestFormatHex);
  T.Run('Format width', @TestFormatWidth);
  T.Run('Format float', @TestFormatFloat);
  T.Run('Format multi-arg', @TestFormatMultiArg);

  T.Summary;
end.
