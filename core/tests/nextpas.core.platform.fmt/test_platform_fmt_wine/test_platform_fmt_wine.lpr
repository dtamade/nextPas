program test_platform_fmt_wine;

{ Wine runtime evidence for platform.fmt on Windows. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.fmt,
  nextpas.core.test;

var
  T: TTestSuite;

{$IFDEF NEXTPAS_WINDOWS}

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

{ 1. Format positive integer }
procedure TestFmtInt;
var Buf: array[0..31] of AnsiChar;
begin
  platform_fmt_int(42, @Buf[0], 32);
  Check(BufEq(@Buf[0], '42'), 'fmt 42');
end;

{ 2. Format negative integer }
procedure TestFmtIntNeg;
var Buf: array[0..31] of AnsiChar;
begin
  platform_fmt_int(-123, @Buf[0], 32);
  Check(BufEq(@Buf[0], '-123'), 'fmt -123');
end;

{ 3. Format uint64 max }
procedure TestFmtUintMax;
var Buf: array[0..31] of AnsiChar;
begin
  platform_fmt_uint(High(UInt64), @Buf[0], 32);
  Check(BufEq(@Buf[0], '18446744073709551615'), 'max uint64');
end;

{ 4. Format hex }
procedure TestFmtHex;
var Buf: array[0..31] of AnsiChar;
begin
  platform_fmt_hex($DEADBEEF, @Buf[0], 32);
  Check(BufEq(@Buf[0], 'DEADBEEF'), 'DEADBEEF');
end;

{ 5. Format float }
procedure TestFmtFloat;
var Buf: array[0..63] of AnsiChar;
  R: Int32;
begin
  R := platform_fmt_float(3.14, 2, @Buf[0], 64);
  Check(R > 0, 'fmt_float returns > 0');
  Check(BufEq(@Buf[0], '3.14'), '3.14');
end;

{ 6. Parse int }
procedure TestParseInt;
var LVal: Int64;
  R: Int32;
begin
  R := platform_parse_int(PAnsiChar('42'), 2, LVal);
  Check(R = 0, 'parse 42 ok');
  Check(LVal = 42, 'value is 42');
end;

{ 7. Parse negative int }
procedure TestParseIntNeg;
var LVal: Int64;
  R: Int32;
begin
  R := platform_parse_int(PAnsiChar('-7'), 2, LVal);
  Check(R = 0, 'parse -7 ok');
  Check(LVal = -7, 'value is -7');
end;

{ 8. Parse hex }
procedure TestParseHex;
var LVal: UInt64;
  R: Int32;
begin
  R := platform_parse_hex(PAnsiChar('FF'), 2, LVal);
  Check(R = 0, 'parse FF ok');
  Check(LVal = 255, 'value is 255');
end;

{ 9. String lowercase }
procedure TestStrLower;
var LSrc: array[0..7] of AnsiChar;
  LDst: array[0..7] of AnsiChar;
  R: Int32;
begin
  LSrc := 'HeLLo';
  R := platform_str_lower(@LSrc[0], 5, @LDst[0], 8);
  Check(R = 5, 'lower returns 5');
  Check(BufEq(@LDst[0], 'hello'), 'hello');
end;

{ 10. String case-insensitive compare }
procedure TestStrEqualNocase;
begin
  Check(platform_str_equal_nocase(PAnsiChar('Hello'), 5, PAnsiChar('hELLO'), 5), 'nocase equal');
  Check(not platform_str_equal_nocase(PAnsiChar('Hello'), 5, PAnsiChar('World'), 5), 'nocase not equal');
end;

{$ELSE}

procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime evidence on this host');
  Check(True, 'non-Windows skip');
end;

{$ENDIF}

begin
  T := TTestSuite.Create('nextpas.core.platform.fmt.wine_runtime_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  T.Test('format int', @TestFmtInt);
  T.Test('format negative int', @TestFmtIntNeg);
  T.Test('format uint64 max', @TestFmtUintMax);
  T.Test('format hex', @TestFmtHex);
  T.Test('format float', @TestFmtFloat);
  T.Test('parse int', @TestParseInt);
  T.Test('parse negative int', @TestParseIntNeg);
  T.Test('parse hex', @TestParseHex);
  T.Test('string lowercase', @TestStrLower);
  T.Test('string case-insensitive compare', @TestStrEqualNocase);
  {$ELSE}
  T.Test('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  if not T.Run then Halt(1);
end.
