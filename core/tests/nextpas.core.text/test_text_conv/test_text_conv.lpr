program test_text_conv;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.text.conv,
  nextpas.core.text.format;

var
  T: TTestRunner;

procedure ExpectInvalidFormat(const AFmt: string; const AArgs: array of const;
  const AMessage: string);
begin
  try
    TextFormat(AFmt, AArgs);
    Fail(AMessage);
  except
    on E: EInvalidArgument do
      ;
  end;
end;

procedure ExpectFormatOverflow(const AFmt: string; const AArgs: array of const;
  const AMessage: string);
begin
  try
    TextFormat(AFmt, AArgs);
    Fail(AMessage);
  except
    on E: EOverflow do
      ;
  end;
end;

procedure ExpectCompatFormatInvalid(const AFmt: string; const AArgs: array of const;
  const AMessage: string);
begin
  try
    nextpas.core.text.conv.Format(AFmt, AArgs);
    Fail(AMessage);
  except
    on E: EInvalidArgument do
      ;
  end;
end;

procedure ExpectIntConvertError(const AValue: string; const AMessage: string);
begin
  try
    StrToInt(AValue);
    Fail(AMessage);
  except
    on E: EConvertError do
      ;
  end;
end;

procedure ExpectFloatConvertError(const AValue: string; const AMessage: string);
begin
  try
    StrToFloat(AValue);
    Fail(AMessage);
  except
    on E: EConvertError do
      ;
  end;
end;

function BytesOf(const AValues: array of Byte): TBytes;
var
  I: SizeInt;
begin
  Result := nil;
  SetLength(Result, Length(AValues));
  for I := 0 to High(AValues) do
    Result[I] := AValues[I];
end;

procedure CheckBytesEqual(const AExpected, AActual: TBytes;
  const AMessage: string = '');
var
  I: SizeInt;
  LPrefix: string;
begin
  if AMessage <> '' then
    LPrefix := AMessage + ': '
  else
    LPrefix := '';
  CheckEqual(Int64(Length(AExpected)), Int64(Length(AActual)), LPrefix + 'length');
  for I := 0 to High(AExpected) do
    CheckEqual(Int64(AExpected[I]), Int64(AActual[I]),
      LPrefix + 'byte[' + IntToStr(I) + ']');
end;

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

procedure TestStringReplace;
begin
  CheckEqual('hXllo', StringReplace('hello', 'e', 'X', False), 'replace first');
  CheckEqual('XbXbX', StringReplace('ababa', 'a', 'X', True), 'replace all');
  CheckEqual('hello', StringReplace('hello', '', 'X', True), 'empty needle');
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
  CheckEqual('00ff', TextFormat('%.4x', [255]));
  CheckEqual('001A', TextFormat('%.4X', [$1A]));
end;

procedure TestFormatWidth;
begin
  CheckEqual('042', TextFormat('%03d', [42]));
  CheckEqual('007', TextFormat('%03d', [7]));
  CheckEqual('1234', TextFormat('%02d', [1234]));
  CheckEqual('0007', TextFormat('%.4d', [7]));
  CheckEqual('-0007', TextFormat('%.4d', [-7]));
  CheckEqual('005', TextFormat('%.3u', [5]));
  CheckEqual('    001A', TextFormat('%8.4X', [$1A]));
  CheckEqual('a   ', TextFormat('%-4s', ['a']));
  CheckEqual('42  ', TextFormat('%-4d', [42]));
  CheckEqual('42  ', TextFormat('%-04d', [42]));
  CheckEqual('-1  ', TextFormat('%-4d', [-1]));
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

procedure TestFormatRejectsMalformedInput;
begin
  ExpectInvalidFormat('%', [], 'dangling percent must raise');
  ExpectInvalidFormat('%5', [], 'width without conversion must raise');
  ExpectInvalidFormat('%.', [], 'precision without conversion must raise');
  ExpectInvalidFormat('%q', [1], 'unsupported conversion must raise');
  ExpectInvalidFormat('%d %d', [1], 'missing argument must raise');
  ExpectInvalidFormat('%d', ['not-int'], 'wrong argument type must raise');
end;

procedure TestFormatRejectsUnboundedWidthAndPrecision;
begin
  ExpectFormatOverflow('%1048577s', ['x'], 'unbounded width must raise');
  ExpectFormatOverflow('%.1025f', [1.0], 'unbounded precision must raise');
end;

procedure TestCompatFormatMatchesTextFormat;
begin
  CheckEqual(TextFormat('%s', ['hello']),
    nextpas.core.text.conv.Format('%s', ['hello']));
  CheckEqual(TextFormat('%03d', [42]),
    nextpas.core.text.conv.Format('%03d', [42]));
  CheckEqual(TextFormat('%.2f', [3.14]),
    nextpas.core.text.conv.Format('%.2f', [3.14]));
end;

procedure TestCompatFormatRejectsMalformedInput;
begin
  ExpectCompatFormatInvalid('%', [], 'compat format dangling percent must raise');
  ExpectCompatFormatInvalid('%5', [], 'compat format missing conversion must raise');
  ExpectCompatFormatInvalid('%q', [1], 'compat format unsupported conversion must raise');
  ExpectCompatFormatInvalid('%d %d', [1], 'compat format missing argument must raise');
  ExpectCompatFormatInvalid('%d', ['not-int'], 'compat format wrong argument type must raise');
end;

procedure TestBoolToStr;
begin
  CheckEqual('True', BoolToStr(True));
  CheckEqual('False', BoolToStr(False));
  CheckEqual('yes', BoolToStr(True, 'yes', 'no'));
  CheckEqual('no', BoolToStr(False, 'yes', 'no'));
end;

procedure TestStrToIntDef;
begin
  CheckEqual(Int64(42), StrToIntDef('42', -1));
  CheckEqual(Int64(-17), StrToIntDef('-17', 0));
  CheckEqual(Int64(123), StrToIntDef('not-a-number', 123));
  CheckEqual(High(Int64), StrToIntDef('9223372036854775807', 0));
  CheckEqual(Low(Int64), StrToIntDef('-9223372036854775808', 0));
  CheckEqual(Int64(77), StrToIntDef('9223372036854775808', 77), 'overflow uses default');
end;

procedure TestStrToInt64Def;
begin
  CheckEqual(Int64(64), StrToInt64Def('64', -1));
  CheckEqual(Int64(-2048), StrToInt64Def('-2048', 0));
  CheckEqual(Int64(456), StrToInt64Def('invalid', 456));
  CheckEqual(High(Int64), StrToInt64Def('9223372036854775807', 0));
  CheckEqual(Low(Int64), StrToInt64Def('-9223372036854775808', 0));
  CheckEqual(Int64(-9), StrToInt64Def('-9223372036854775809', -9), 'underflow uses default');
end;

procedure TestStrToIntRaisesConvertError;
begin
  CheckEqual(Int64(42), StrToInt('42'));
  ExpectIntConvertError('not-a-number', 'StrToInt invalid text must raise');
  ExpectIntConvertError('9223372036854775808', 'StrToInt overflow must raise');
end;

procedure TestStrToFloatDef;
begin
  CheckEqual('3.14', FloatToStr(StrToFloatDef('3.14', 0.5)));
  CheckEqual('-0.25', FloatToStr(StrToFloatDef('-0.25', 1.0)));
  CheckEqual('1.5', FloatToStr(StrToFloatDef('not-a-number', 1.5)));
end;

procedure TestStrToFloatRaisesConvertError;
begin
  CheckEqual('3.14', FloatToStr(StrToFloat('3.14')));
  ExpectFloatConvertError('not-a-number', 'StrToFloat invalid text must raise');
  ExpectFloatConvertError('1.2.3', 'StrToFloat malformed text must raise');
end;

procedure TestLowerCase;
begin
  CheckEqual('hello', LowerCase('HELLO'));
  CheckEqual('abc', LowerCase('abc'));
  CheckEqual('', LowerCase(''));
  CheckEqual('hello 123!', LowerCase('HeLLo 123!'));
end;

procedure TestUpperCase;
begin
  CheckEqual('HELLO', UpperCase('hello'));
  CheckEqual('ABC', UpperCase('ABC'));
  CheckEqual('', UpperCase(''));
  CheckEqual('HELLO 123!', UpperCase('HeLLo 123!'));
end;

procedure TestUTF8RoundTrip;
var
  LExpected: TBytes;
  LActual: TBytes;
  LText: string;
begin
  LExpected := BytesOf([$E4, $B8, $AD, $E6, $96, $87, $F0, $9F, $98, $80]);
  LText := UTF8BytesToString(LExpected);
  Check(LText <> '', 'decoded UTF-8 text should not be empty');
  LActual := StringToUTF8Bytes(LText);
  CheckBytesEqual(LExpected, LActual, 'utf8 round-trip');
end;

procedure TestASCIIBytesRoundTrip;
var
  LText: string;
begin
  LText := 'ASCII only 123!?';
  CheckEqual(LText, ASCIIBytesToString(StringToASCIIBytes(LText)));
end;

procedure TestBigEndianUnicode;
begin
  CheckEqual('Hi', BigEndianUnicodeBytesToString(BytesOf([$00, $48, $00, $69])));
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
  T.Run('StringReplace', @TestStringReplace);

  T.Run('Format basic', @TestFormatBasic);
  T.Run('Format hex', @TestFormatHex);
  T.Run('Format width', @TestFormatWidth);
  T.Run('Format float', @TestFormatFloat);
  T.Run('Format multi-arg', @TestFormatMultiArg);
  T.Run('Format rejects malformed input', @TestFormatRejectsMalformedInput);
  T.Run('Format rejects unbounded width and precision', @TestFormatRejectsUnboundedWidthAndPrecision);
  T.Run('Compat format matches TextFormat', @TestCompatFormatMatchesTextFormat);
  T.Run('Compat format rejects malformed input', @TestCompatFormatRejectsMalformedInput);
  T.Run('BoolToStr', @TestBoolToStr);
  T.Run('StrToInt raises convert error', @TestStrToIntRaisesConvertError);
  T.Run('StrToIntDef', @TestStrToIntDef);
  T.Run('StrToInt64Def', @TestStrToInt64Def);
  T.Run('StrToFloat raises convert error', @TestStrToFloatRaisesConvertError);
  T.Run('StrToFloatDef', @TestStrToFloatDef);
  T.Run('LowerCase', @TestLowerCase);
  T.Run('UpperCase', @TestUpperCase);
  T.Run('UTF8 round-trip', @TestUTF8RoundTrip);
  T.Run('ASCII bytes round-trip', @TestASCIIBytesRoundTrip);
  T.Run('Big-endian Unicode', @TestBigEndianUnicode);

  T.Summary;
end.
