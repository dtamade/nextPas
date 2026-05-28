program test_platform_fmt;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.fmt,
  nextpas.core.testing;

var
  T: TTestRunner;

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
  Check(platform_fmt_int(42, nil, 0) = -1, 'nil returns -1');
  Check(platform_fmt_uint(42, nil, 0) = -1, 'nil uint returns -1');
  Check(platform_fmt_hex(42, nil, 0) = -1, 'nil hex returns -1');
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

begin
  T := TTestRunner.Create('nextpas.core.platform.fmt');
  T.Run('int positive', @TestIntPositive);
  T.Run('int negative', @TestIntNegative);
  T.Run('uint max', @TestUintMax);
  T.Run('hex', @TestHex);
  T.Run('small buffer', @TestSmallBuffer);
  T.Run('fmt_buf basic', @TestFmtBufBasic);
  T.Run('fmt_buf string', @TestFmtBufString);
  T.Run('fmt_buf hex', @TestFmtBufHex);
  T.Run('fmt_buf empty', @TestFmtBufEmpty);
  T.Run('nil buffer', @TestNilBuffer);
  T.Run('parse uint', @TestParseUint);
  T.Run('parse int', @TestParseInt);
  T.Run('parse hex', @TestParseHex);
  T.Run('parse errors', @TestParseErrors);
  T.Run('str_lower', @TestStrLower);
  T.Run('str_trim', @TestStrTrim);
  T.Summary;
end.
