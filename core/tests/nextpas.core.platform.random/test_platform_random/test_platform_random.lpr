program test_platform_random;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.random,
  nextpas.core.platform.error,
  nextpas.core.text.conv,
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

procedure TestFill64Aligned;
var
  Buf: array[0..63] of Byte;
  I: Int32;
  AllZero: Boolean;
begin
  FillChar(Buf, 64, 0);
  Check(platform_random_bytes(@Buf[0], 64) = 0, 'fill 64 bytes');
  AllZero := True;
  for I := 0 to 63 do
    if Buf[I] <> 0 then begin AllZero := False; Break; end;
  Check(not AllZero, '64 bytes not all zero');
end;

procedure TestRepeatedFillsProduceVaryingOutput;
var
  Buf1, Buf2, Buf3: array[0..15] of Byte;
  Diff12, Diff13: Boolean;
  I: Int32;
begin
  platform_random_bytes(@Buf1[0], 16);
  platform_random_bytes(@Buf2[0], 16);
  platform_random_bytes(@Buf3[0], 16);
  Diff12 := False; Diff13 := False;
  for I := 0 to 15 do
  begin
    if Buf1[I] <> Buf2[I] then Diff12 := True;
    if Buf1[I] <> Buf3[I] then Diff13 := True;
  end;
  Check(Diff12, 'buf1 != buf2');
  Check(Diff13, 'buf1 != buf3');
end;

procedure TestFill16;
var
  Buf: array[0..15] of Byte;
begin
  FillChar(Buf, 16, 0);
  Check(platform_random_bytes(@Buf[0], 16) = 0, 'fill 16 bytes');
end;

procedure TestNonNilZeroLen;
var
  Buf: Byte;
begin
  Buf := $42;
  Check(platform_random_bytes(@Buf, 0) = 0, 'non-nil zero len returns 0');
  Check(Buf = $42, 'non-nil zero len does not modify buffer');
end;

procedure TestFillPageAligned;
var
  Buf: array[0..4095] of Byte;
  I: Int32;
  AllZero: Boolean;
begin
  FillChar(Buf, 4096, 0);
  Check(platform_random_bytes(@Buf[0], 4096) = 0, 'fill page-aligned');
  AllZero := True;
  for I := 0 to 4095 do
    if Buf[I] <> 0 then begin AllZero := False; Break; end;
  Check(not AllZero, 'page-aligned fill not all zero');
end;

procedure TestFill8Bytes;
var
  Buf: array[0..7] of Byte;
begin
  FillChar(Buf, 8, 0);
  Check(platform_random_bytes(@Buf[0], 8) = 0, 'fill 8 bytes');
  Check((Buf[0] or Buf[1] or Buf[2] or Buf[3] or Buf[4] or Buf[5] or Buf[6] or Buf[7]) <> 0,
    '8 bytes not all zero');
end;

procedure TestFill128Bytes;
var
  Buf: array[0..127] of Byte;
  I: Int32;
  AllZero: Boolean;
begin
  FillChar(Buf, 128, 0);
  Check(platform_random_bytes(@Buf[0], 128) = 0, 'fill 128 bytes');
  AllZero := True;
  for I := 0 to 127 do
    if Buf[I] <> 0 then begin AllZero := False; Break; end;
  Check(not AllZero, '128 bytes not all zero');
end;

procedure TestFillLargeBuffer;
var
  Buf: array[0..8191] of Byte;
  I: Int32;
  AllZero: Boolean;
begin
  FillChar(Buf, 8192, 0);
  Check(platform_random_bytes(@Buf[0], 8192) = 0, 'fill 8KB');
  AllZero := True;
  for I := 0 to 8191 do
    if Buf[I] <> 0 then begin AllZero := False; Break; end;
  Check(not AllZero, '8KB not all zero');
end;

procedure TestFillBoundarySizes;
var
  Buf: array[0..63] of Byte;
  Sizes: array[0..7] of PtrUInt;
  I, J: Int32;
  AllZero: Boolean;
begin
  Sizes[0] := 2; Sizes[1] := 3; Sizes[2] := 5; Sizes[3] := 7;
  Sizes[4] := 15; Sizes[5] := 17; Sizes[6] := 31; Sizes[7] := 33;
  for I := 0 to 7 do
  begin
    FillChar(Buf, 64, 0);
    Check(platform_random_bytes(@Buf[0], Sizes[I]) = 0, 'fill ' + IntToStr(Sizes[I]) + ' bytes');
    AllZero := True;
    for J := 0 to Int32(Sizes[I]) - 1 do
      if Buf[J] <> 0 then begin AllZero := False; Break; end;
    Check(not AllZero, IntToStr(Sizes[I]) + ' bytes not all zero');
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.random');
  T.Test('fill 32 bytes non-zero', @TestFill32);
  T.Test('two calls differ', @TestTwoCallsDiffer);
  T.Test('fill 1 byte', @TestFill1);
  T.Test('fill 4096 bytes', @TestFill4096);
  T.Test('zero length', @TestZeroLen);
  T.Test('nil nonzero', @TestNilNonZero);
  T.Test('fill 64 bytes aligned', @TestFill64Aligned);
  T.Test('repeated fills produce varying output', @TestRepeatedFillsProduceVaryingOutput);
  T.Test('fill 16 bytes', @TestFill16);
  T.Test('non-nil zero len', @TestNonNilZeroLen);
  T.Test('fill page-aligned (4096)', @TestFillPageAligned);
  T.Test('fill 8 bytes', @TestFill8Bytes);
  T.Test('fill 128 bytes', @TestFill128Bytes);
  T.Test('fill 8KB large buffer', @TestFillLargeBuffer);
  T.Test('fill boundary sizes', @TestFillBoundarySizes);
  if not T.Run then Halt(1);
end.
