program test_platform_fmt;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.error,
  nextpas.core.platform.fmt,
  nextpas.core.test;

var
  T: TTestSuite;

function BufEq(const A, B: PAnsiChar): Boolean;
var I: Int32;
begin
  I := 0;
  while (A[I] <> #0) and (B[I] <> #0) do
  begin
    if A[I] <> B[I] then Exit(False);
    Inc(I);
  end;
  Result := (A[I] = #0) and (B[I] = #0);
end;

procedure TestIntPositive;
var Buf: array[0..31] of AnsiChar;
begin
  platform_fmt_int(42, @Buf[0], 32);
  Check(BufEq(@Buf[0], '42'), '42');
  platform_fmt_int(0, @Buf[0], 32);
  Check(BufEq(@Buf[0], '0'), '0');
  platform_fmt_int(1000000, @Buf[0], 32);
  Check(BufEq(@Buf[0], '1000000'), '1000000');
end;

procedure TestIntNegative;
var Buf: array[0..31] of AnsiChar;
begin
  platform_fmt_int(-1, @Buf[0], 32);
  Check(BufEq(@Buf[0], '-1'), '-1');
  platform_fmt_int(-999, @Buf[0], 32);
  Check(BufEq(@Buf[0], '-999'), '-999');
end;

procedure TestUintMax;
var Buf: array[0..31] of AnsiChar;
begin
  platform_fmt_uint(High(UInt64), @Buf[0], 32);
  Check(BufEq(@Buf[0], '18446744073709551615'), 'max uint64');
end;

procedure TestHex;
var Buf: array[0..31] of AnsiChar;
begin
  platform_fmt_hex($DEADBEEF, @Buf[0], 32);
  Check(BufEq(@Buf[0], 'DEADBEEF'), 'DEADBEEF');
  platform_fmt_hex(0, @Buf[0], 32);
  Check(BufEq(@Buf[0], '0'), 'hex 0');
  platform_fmt_hex($FF, @Buf[0], 32);
  Check(BufEq(@Buf[0], 'FF'), 'FF');
end;

procedure TestSmallBuffer;
var Buf: array[0..3] of AnsiChar;
begin
  platform_fmt_int(12345, @Buf[0], 4);
  Check(Buf[3] = #0, 'null terminated');
  Check(Buf[0] = '1', 'truncated start');
end;

procedure TestFmtBufBasic;
var Buf: array[0..255] of AnsiChar;
begin
  platform_fmt_buf('line %d col %d', [42, 7], @Buf[0], 256);
  Check(BufEq(@Buf[0], 'line 42 col 7'), 'line 42 col 7');
end;

procedure TestFmtBufString;
var Buf: array[0..255] of AnsiChar;
begin
  platform_fmt_buf('file: %s', [PAnsiChar('test.pas')], @Buf[0], 256);
  Check(BufEq(@Buf[0], 'file: test.pas'), 'file: test.pas');
end;

procedure TestFmtBufHex;
var Buf: array[0..255] of AnsiChar;
begin
  platform_fmt_buf('addr: %x', [$FF], @Buf[0], 256);
  Check(BufEq(@Buf[0], 'addr: FF'), 'addr: FF');
end;

procedure TestFmtBufEmpty;
var Buf: array[0..31] of AnsiChar;
begin
  platform_fmt_buf('', [], @Buf[0], 32);
  Check(BufEq(@Buf[0], ''), 'empty fmt');
end;

procedure TestNilBuffer;
begin
  Check(platform_fmt_int(42, nil, 0) = PLATFORM_ERR_INVALID, 'nil returns PLATFORM_ERR_INVALID');
  Check(platform_fmt_uint(42, nil, 0) = PLATFORM_ERR_INVALID, 'nil uint returns PLATFORM_ERR_INVALID');
  Check(platform_fmt_hex(42, nil, 0) = PLATFORM_ERR_INVALID, 'nil hex returns PLATFORM_ERR_INVALID');
end;

procedure TestParseUint;
var V: UInt64;
begin
  Check(platform_parse_uint('0', 1, V) = 0, 'parse 0');
  Check(V = 0, '0 value');
  Check(platform_parse_uint('12345', 5, V) = 0, 'parse 12345');
  Check(V = 12345, '12345 value');
  Check(platform_parse_uint('18446744073709551615', 20, V) = 0, 'parse max uint64');
  Check(V = High(UInt64), 'max uint64 value');
end;

procedure TestParseInt;
var V: Int64;
begin
  Check(platform_parse_int('42', 2, V) = 0, 'parse 42');
  Check(V = 42, '42 value');
  Check(platform_parse_int('-1', 2, V) = 0, 'parse -1');
  Check(V = -1, '-1 value');
  Check(platform_parse_int('-9223372036854775808', 20, V) = 0, 'parse min int64');
  Check(V = Low(Int64), 'min int64 value');
end;

procedure TestParseHex;
var V: UInt64;
begin
  Check(platform_parse_hex('0', 1, V) = 0, 'parse hex 0');
  Check(V = 0, 'hex 0 value');
  Check(platform_parse_hex('DEADBEEF', 8, V) = 0, 'parse DEADBEEF');
  Check(V = $DEADBEEF, 'DEADBEEF value');
  Check(platform_parse_hex('ff', 2, V) = 0, 'parse ff lowercase');
  Check(V = $FF, 'ff value');
  Check(platform_parse_hex('FFFFFFFFFFFFFFFF', 16, V) = 0, 'parse max hex');
  Check(V = High(UInt64), 'max hex value');
end;

procedure TestParseErrors;
var Vi: Int64; Vu: UInt64;
begin
  Check(platform_parse_uint(nil, 0, Vu) <> 0, 'nil fails');
  Check(platform_parse_uint('abc', 3, Vu) <> 0, 'non-digit fails');
  Check(platform_parse_int('', 0, Vi) <> 0, 'empty fails');
  Check(platform_parse_int('-', 1, Vi) <> 0, 'bare minus fails');
  Check(platform_parse_hex('GG', 2, Vu) <> 0, 'invalid hex fails');
end;

procedure TestStrLower;
var Buf: array[0..63] of AnsiChar;
begin
  platform_str_lower('Hello World', 11, @Buf[0], 64);
  Check(BufEq(@Buf[0], 'hello world'), 'lower basic');
  platform_str_lower('ABC123', 6, @Buf[0], 64);
  Check(BufEq(@Buf[0], 'abc123'), 'lower mixed');
  Check(platform_str_lower('X', 1, @Buf[0], 64) = 1, 'returns length');
end;

procedure TestStrUpper;
var Buf: array[0..63] of AnsiChar;
begin
  platform_str_upper('hello world', 11, @Buf[0], 64);
  Check(BufEq(@Buf[0], 'HELLO WORLD'), 'upper basic');
  platform_str_upper('abc123', 6, @Buf[0], 64);
  Check(BufEq(@Buf[0], 'ABC123'), 'upper mixed');
  Check(platform_str_upper('x', 1, @Buf[0], 64) = 1, 'returns length');
  platform_str_upper('', 0, @Buf[0], 64);
  Check(BufEq(@Buf[0], ''), 'empty string');
end;

procedure TestStrTrim;
var Buf: array[0..63] of AnsiChar;
begin
  platform_str_trim('  hello  ', 9, @Buf[0], 64);
  Check(BufEq(@Buf[0], 'hello'), 'trim both');
  platform_str_trim('no_space', 8, @Buf[0], 64);
  Check(BufEq(@Buf[0], 'no_space'), 'trim none');
  platform_str_trim('   ', 3, @Buf[0], 64);
  Check(BufEq(@Buf[0], ''), 'trim all whitespace');
  Check(platform_str_trim(#9'tab'#10, 5, @Buf[0], 64) = 3, 'trim tab/newline');
  Check(BufEq(@Buf[0], 'tab'), 'trim tab result');
end;

procedure TestStrEqualNocase;
begin
  Check(platform_str_equal_nocase('Hello', 5, 'hello', 5), 'hello eq');
  Check(platform_str_equal_nocase('ABC', 3, 'abc', 3), 'abc eq');
  Check(platform_str_equal_nocase('TObject', 7, 'tobject', 7), 'TObject eq');
  Check(not platform_str_equal_nocase('foo', 3, 'bar', 3), 'foo <> bar');
  Check(not platform_str_equal_nocase('ab', 2, 'abc', 3), 'diff len');
  Check(platform_str_equal_nocase('', 0, '', 0), 'empty eq');
end;

procedure TestStrFind;
begin
  Check(platform_str_find('hello world', 11, 'world', 5) = 6, 'find world');
  Check(platform_str_find('hello world', 11, 'hello', 5) = 0, 'find hello');
  Check(platform_str_find('hello world', 11, 'xyz', 3) = -1, 'not found');
  Check(platform_str_find('aaa', 3, 'aa', 2) = 0, 'overlapping');
  Check(platform_str_find('test', 4, '', 0) = 0, 'empty needle');
end;

procedure TestStrStartsEnds;
begin
  Check(platform_str_starts_with('/usr/bin', 8, '/usr', 4), 'starts /usr');
  Check(not platform_str_starts_with('/usr/bin', 8, '/opt', 4), 'not starts /opt');
  Check(platform_str_ends_with('file.pas', 8, '.pas', 4), 'ends .pas');
  Check(not platform_str_ends_with('file.pas', 8, '.lpr', 4), 'not ends .lpr');
  Check(platform_str_starts_with('x', 1, '', 0), 'empty prefix');
  Check(platform_str_ends_with('x', 1, '', 0), 'empty suffix');
end;

procedure TestFmtFloat;
var Buf: array[0..63] of AnsiChar;
begin
  platform_fmt_float(3.14159, 2, @Buf[0], 64);
  Check(BufEq(@Buf[0], '3.14'), '3.14');
  platform_fmt_float(0.0, 1, @Buf[0], 64);
  Check(BufEq(@Buf[0], '0.0'), '0.0');
  platform_fmt_float(-42.5, 1, @Buf[0], 64);
  Check(BufEq(@Buf[0], '-42.5'), '-42.5');
  platform_fmt_float(1.0, 3, @Buf[0], 64);
  Check(BufEq(@Buf[0], '1.000'), '1.000');
  platform_fmt_float(99.999, 2, @Buf[0], 64);
  Check(BufEq(@Buf[0], '100.00'), '99.999 rounds to 100.00');
  platform_fmt_float(0.1, 0, @Buf[0], 64);
  Check(BufEq(@Buf[0], '0'), '0 decimals');
end;

procedure TestFmtBufFloat;
var Buf: array[0..63] of AnsiChar;
begin
  platform_fmt_buf('time: %f sec', [Double(1.5)], @Buf[0], 64);
  Check(BufEq(@Buf[0], 'time: 1.500000 sec'), 'fmt_buf %f');
end;

procedure TestFmtBufWidth;
var Buf: array[0..63] of AnsiChar;
begin
  platform_fmt_buf('%10d', [42], @Buf[0], 64);
  Check(BufEq(@Buf[0], '        42'), 'right-align int');
  platform_fmt_buf('%-10s|', ['hi'], @Buf[0], 64);
  Check(BufEq(@Buf[0], 'hi        |'), 'left-align str');
  platform_fmt_buf('%08x', [255], @Buf[0], 64);
  Check(BufEq(@Buf[0], '000000FF'), 'zero-pad hex');
  platform_fmt_buf('%5d', [12345], @Buf[0], 64);
  Check(BufEq(@Buf[0], '12345'), 'exact width');
  platform_fmt_buf('%3d', [12345], @Buf[0], 64);
  Check(BufEq(@Buf[0], '12345'), 'overflow no truncate');
end;

procedure TestParseFloat;
var V: Double;
begin
  Check(platform_parse_float('3.14', 4, V) = 0, 'parse 3.14');
  Check((V > 3.139) and (V < 3.141), '3.14 value');
  Check(platform_parse_float('-0.5', 4, V) = 0, 'parse -0.5');
  Check((V > -0.501) and (V < -0.499), '-0.5 value');
  Check(platform_parse_float('1e3', 3, V) = 0, 'parse 1e3');
  Check((V > 999.9) and (V < 1000.1), '1e3 = 1000');
  Check(platform_parse_float('2.5E-1', 6, V) = 0, 'parse 2.5E-1');
  Check((V > 0.249) and (V < 0.251), '2.5E-1 = 0.25');
  Check(platform_parse_float('42', 2, V) = 0, 'parse int as float');
  Check((V > 41.9) and (V < 42.1), '42 value');
  Check(platform_parse_float('abc', 3, V) <> 0, 'invalid');
  Check(platform_parse_float('', 0, V) <> 0, 'empty');
end;

procedure TestStrLowerEmpty;
var
  Buf: array[0..63] of AnsiChar;
  R: Int32;
begin
  R := platform_str_lower('', 0, @Buf[0], 64);
  Check(R = 0, 'empty source returns 0');
  Check(Buf[0] = #0, 'empty result is null terminated');
end;

procedure TestStrUpperEmpty;
var
  Buf: array[0..63] of AnsiChar;
  R: Int32;
begin
  R := platform_str_upper('', 0, @Buf[0], 64);
  Check(R = 0, 'empty source returns 0');
  Check(Buf[0] = #0, 'empty result is null terminated');
end;

procedure TestStrTrimEmpty;
var
  Buf: array[0..63] of AnsiChar;
  R: Int32;
begin
  R := platform_str_trim('', 0, @Buf[0], 64);
  Check(R = 0, 'empty source returns 0');
  Check(Buf[0] = #0, 'empty result is null terminated');
end;

procedure TestFmtIntMaxMin;
var Buf: array[0..31] of AnsiChar;
begin
  platform_fmt_int(High(Int64), @Buf[0], 32);
  Check(BufEq(@Buf[0], '9223372036854775807'), 'max int64');
  platform_fmt_int(Low(Int64), @Buf[0], 32);
  Check(BufEq(@Buf[0], '-9223372036854775808'), 'min int64');
end;

procedure TestParseUintOverflow;
var V: UInt64;
begin
  { 18446744073709551616 = max uint64 + 1 — should fail }
  Check(platform_parse_uint('18446744073709551616', 20, V) <> 0, 'uint64 overflow rejected');
end;

procedure TestFmtHexZeroPad;
var Buf: array[0..31] of AnsiChar;
begin
  platform_fmt_hex($00FF, @Buf[0], 32);
  Check(BufEq(@Buf[0], 'FF'), 'hex no leading zeros');
  platform_fmt_hex(0, @Buf[0], 32);
  Check(BufEq(@Buf[0], '0'), 'hex zero');
end;

procedure TestParseHexLowerAndUpper;
var V: UInt64;
begin
  Check(platform_parse_hex('abcdef', 6, V) = 0, 'parse lowercase hex');
  Check(V = $ABCDEF, 'lowercase hex value');
  Check(platform_parse_hex('ABCDEF', 6, V) = 0, 'parse uppercase hex');
  Check(V = $ABCDEF, 'uppercase hex value');
end;

procedure TestFmtBufPercentEscape;
var Buf: array[0..63] of AnsiChar;
begin
  platform_fmt_buf('100%% done', [], @Buf[0], 64);
  Check(BufEq(@Buf[0], '100% done'), 'percent escape');
end;

procedure TestFmtBufNoArgs;
var Buf: array[0..63] of AnsiChar;
begin
  platform_fmt_buf('no args here', [], @Buf[0], 64);
  Check(BufEq(@Buf[0], 'no args here'), 'no args passthrough');
end;

procedure TestFmtBufNilFormat;
var Buf: array[0..63] of AnsiChar;
  R: Int32;
begin
  R := platform_fmt_buf(nil, [], @Buf[0], 64);
  Check(BufEq(@Buf[0], ''), 'nil format produces empty');
  Check(R = 0, 'nil format returns 0');
end;

procedure TestFmtFloatNegative;
var Buf: array[0..63] of AnsiChar;
begin
  platform_fmt_float(-123.456, 2, @Buf[0], 64);
  Check(BufEq(@Buf[0], '-123.46'), '-123.456 rounds to -123.46');
end;

procedure TestParseFloatScientific;
var V: Double;
begin
  Check(platform_parse_float('1.5e2', 5, V) = 0, 'parse 1.5e2');
  Check((V > 149.9) and (V < 150.1), '1.5e2 = 150');
  Check(platform_parse_float('3E-2', 4, V) = 0, 'parse 3E-2');
  Check((V > 0.029) and (V < 0.031), '3E-2 = 0.03');
end;

procedure TestStrFindNilNeedle;
begin
  Check(platform_str_find('hello', 5, nil, 3) = 0, 'nil needle returns 0 (empty needle match)');
end;

procedure TestStrFindNilHaystack;
begin
  Check(platform_str_find(nil, 5, 'hello', 5) = -1, 'nil haystack returns -1');
end;

procedure TestStrStartsWithNilArgs;
begin
  Check(not platform_str_starts_with(nil, 5, 'hello', 5), 'nil str returns false');
  Check(not platform_str_starts_with('hello', 5, nil, 5), 'nil prefix returns false');
  Check(platform_str_starts_with('hello', 5, nil, 0), 'nil empty prefix returns true');
end;

procedure TestStrEndsWithNilArgs;
begin
  Check(not platform_str_ends_with(nil, 5, 'hello', 5), 'nil str returns false');
  Check(not platform_str_ends_with('hello', 5, nil, 5), 'nil suffix returns false');
  Check(platform_str_ends_with('hello', 5, nil, 0), 'nil empty suffix returns true');
end;

procedure TestStrLowerNilSource;
var Buf: array[0..63] of AnsiChar;
  R: Int32;
begin
  R := platform_str_lower(nil, 5, @Buf[0], 64);
  Check(R = 0, 'nil source returns 0');
  Check(Buf[0] = #0, 'nil source produces empty');
end;

procedure TestStrUpperNilSource;
var Buf: array[0..63] of AnsiChar;
  R: Int32;
begin
  R := platform_str_upper(nil, 5, @Buf[0], 64);
  Check(R = 0, 'nil source returns 0');
  Check(Buf[0] = #0, 'nil source produces empty');
end;

procedure TestStrTrimNilSource;
var Buf: array[0..63] of AnsiChar;
  R: Int32;
begin
  R := platform_str_trim(nil, 5, @Buf[0], 64);
  Check(R = 0, 'nil source returns 0');
  Check(Buf[0] = #0, 'nil source produces empty');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.fmt');
  T.Test('int positive', @TestIntPositive);
  T.Test('int negative', @TestIntNegative);
  T.Test('uint max', @TestUintMax);
  T.Test('hex', @TestHex);
  T.Test('small buffer', @TestSmallBuffer);
  T.Test('fmt_buf basic', @TestFmtBufBasic);
  T.Test('fmt_buf string', @TestFmtBufString);
  T.Test('fmt_buf hex', @TestFmtBufHex);
  T.Test('fmt_buf empty', @TestFmtBufEmpty);
  T.Test('nil buffer', @TestNilBuffer);
  T.Test('parse uint', @TestParseUint);
  T.Test('parse int', @TestParseInt);
  T.Test('parse hex', @TestParseHex);
  T.Test('parse errors', @TestParseErrors);
  T.Test('str_lower', @TestStrLower);
  T.Test('str_upper', @TestStrUpper);
  T.Test('str_trim', @TestStrTrim);
  T.Test('str_equal_nocase', @TestStrEqualNocase);
  T.Test('str_find', @TestStrFind);
  T.Test('str_starts_ends', @TestStrStartsEnds);
  T.Test('fmt_float', @TestFmtFloat);
  T.Test('fmt_buf %f', @TestFmtBufFloat);
  T.Test('fmt_buf width/align', @TestFmtBufWidth);
  T.Test('parse_float', @TestParseFloat);
  T.Test('str_lower empty', @TestStrLowerEmpty);
  T.Test('str_upper empty', @TestStrUpperEmpty);
  T.Test('str_trim empty', @TestStrTrimEmpty);
  T.Test('int max/min', @TestFmtIntMaxMin);
  T.Test('parse uint overflow', @TestParseUintOverflow);
  T.Test('hex zero pad', @TestFmtHexZeroPad);
  T.Test('parse hex case', @TestParseHexLowerAndUpper);
  T.Test('fmt_buf percent escape', @TestFmtBufPercentEscape);
  T.Test('fmt_buf no args', @TestFmtBufNoArgs);
  T.Test('fmt_buf nil format', @TestFmtBufNilFormat);
  T.Test('float negative rounding', @TestFmtFloatNegative);
  T.Test('parse float scientific', @TestParseFloatScientific);
  T.Test('str_find nil needle', @TestStrFindNilNeedle);
  T.Test('str_find nil haystack', @TestStrFindNilHaystack);
  T.Test('str_starts_with nil args', @TestStrStartsWithNilArgs);
  T.Test('str_ends_with nil args', @TestStrEndsWithNilArgs);
  T.Test('str_lower nil source', @TestStrLowerNilSource);
  T.Test('str_upper nil source', @TestStrUpperNilSource);
  T.Test('str_trim nil source', @TestStrTrimNilSource);
  if not T.Run then Halt(1);
end.
