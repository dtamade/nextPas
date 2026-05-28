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
  T.Summary;
end.
