program test_platform_random;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.random,
  nextpas.core.platform.error,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestFill32;
var
  Buf: array[0..31] of Byte;
  I: Int32;
  AllZero: Boolean;
begin
  FillChar(Buf, 32, 0);
  Check(platform_random_bytes(@Buf[0], 32) = 0, 'fill 32 bytes');
  AllZero := True;
  for I := 0 to 31 do
    if Buf[I] <> 0 then
    begin
      AllZero := False;
      Break;
    end;
  Check(not AllZero, 'not all zero');
end;

procedure TestTwoCallsDiffer;
var
  A, B: array[0..31] of Byte;
  I: Int32;
  Same: Boolean;
begin
  platform_random_bytes(@A[0], 32);
  platform_random_bytes(@B[0], 32);
  Same := True;
  for I := 0 to 31 do
    if A[I] <> B[I] then
    begin
      Same := False;
      Break;
    end;
  Check(not Same, 'two calls differ');
end;

procedure TestFill1;
var
  Buf: Byte;
begin
  Buf := 0;
  Check(platform_random_bytes(@Buf, 1) = 0, 'fill 1 byte');
end;

procedure TestFill4096;
var
  Buf: array[0..4095] of Byte;
begin
  Check(platform_random_bytes(@Buf[0], 4096) = 0, 'fill 4096 bytes');
end;

procedure TestZeroLen;
begin
  Check(platform_random_bytes(nil, 0) = 0, 'len=0 returns 0');
end;

procedure TestNilNonZero;
begin
  CheckEqual(Int64(PLATFORM_ERR_INVALID), Int64(platform_random_bytes(nil, 1)), 'nil nonzero returns PLATFORM_ERR_INVALID');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.random');
  T.Test('fill 32 bytes non-zero', @TestFill32);
  T.Test('two calls differ', @TestTwoCallsDiffer);
  T.Test('fill 1 byte', @TestFill1);
  T.Test('fill 4096 bytes', @TestFill4096);
  T.Test('zero length', @TestZeroLen);
  T.Test('nil nonzero', @TestNilNonZero);
  if not T.Run then Halt(1);
end.
