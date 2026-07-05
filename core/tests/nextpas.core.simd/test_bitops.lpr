{
  test_bitops.lpr

  Standalone correctness test for nextpas.core.simd.bitops.
  No test framework dependency — pure assertions.
  Exit code 0 = all pass, 1 = failure.
}
{$mode objfpc}{$H+}
program test_bitops;

uses
  nextpas.core.simd.bitops;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; AExpected, AActual: UInt32);
begin
  if AExpected = AActual then
    Inc(GPass)
  else
  begin
    Inc(GFail);
    WriteLn('FAIL: ', AName, ' expected=', AExpected, ' actual=', AActual);
  end;
end;

procedure Check64(const AName: string; AExpected, AActual: UInt32);
begin
  if AExpected = AActual then
    Inc(GPass)
  else
  begin
    Inc(GFail);
    WriteLn('FAIL: ', AName, ' expected=', AExpected, ' actual=', AActual);
  end;
end;

procedure CheckBool(const AName: string; AExpected, AActual: Boolean);
begin
  if AExpected = AActual then
    Inc(GPass)
  else
  begin
    Inc(GFail);
    WriteLn('FAIL: ', AName, ' expected=', AExpected, ' actual=', AActual);
  end;
end;

procedure TestClz;
begin
  Check('Clz32(0)', 32, Clz32(0));
  Check('Clz32(1)', 31, Clz32(1));
  Check('Clz32(2)', 30, Clz32(2));
  Check('Clz32($80000000)', 0, Clz32($80000000));
  Check('Clz32($40000000)', 1, Clz32($40000000));
  Check('Clz32($FFFFFFFF)', 0, Clz32($FFFFFFFF));
  Check('Clz32($00FF0000)', 8, Clz32($00FF0000));
  Check('Clz32($0000FFFF)', 16, Clz32($0000FFFF));

  Check64('Clz64(0)', 64, Clz64(0));
  Check64('Clz64(1)', 63, Clz64(1));
  Check64('Clz64($8000000000000000)', 0, Clz64($8000000000000000));
  Check64('Clz64($00000000FFFFFFFF)', 32, Clz64(UInt64($00000000FFFFFFFF)));
  Check64('Clz64($00FF000000000000)', 8, Clz64(UInt64($00FF000000000000)));
end;

procedure TestCtz;
begin
  Check('Ctz32(0)', 32, Ctz32(0));
  Check('Ctz32(1)', 0, Ctz32(1));
  Check('Ctz32(2)', 1, Ctz32(2));
  Check('Ctz32(4)', 2, Ctz32(4));
  Check('Ctz32($80000000)', 31, Ctz32($80000000));
  Check('Ctz32($FFFFFFFF)', 0, Ctz32($FFFFFFFF));
  Check('Ctz32($FFFF0000)', 16, Ctz32($FFFF0000));

  Check64('Ctz64(0)', 64, Ctz64(0));
  Check64('Ctz64(1)', 0, Ctz64(1));
  Check64('Ctz64($8000000000000000)', 63, Ctz64($8000000000000000));
  Check64('Ctz64($FFFFFFFF00000000)', 32, Ctz64(UInt64($FFFFFFFF00000000)));
end;

procedure TestPopCount;
begin
  Check('PopCount32(0)', 0, PopCount32(0));
  Check('PopCount32(1)', 1, PopCount32(1));
  Check('PopCount32(3)', 2, PopCount32(3));
  Check('PopCount32(7)', 3, PopCount32(7));
  Check('PopCount32($FF)', 8, PopCount32($FF));
  Check('PopCount32($FFFFFFFF)', 32, PopCount32($FFFFFFFF));
  Check('PopCount32($55555555)', 16, PopCount32($55555555));

  Check64('PopCount64(0)', 0, PopCount64(0));
  Check64('PopCount64($FFFFFFFFFFFFFFFF)', 64, PopCount64($FFFFFFFFFFFFFFFF));
  Check64('PopCount64($00000000FFFFFFFF)', 32, PopCount64(UInt64($00000000FFFFFFFF)));
end;

procedure TestBsfBsr;
begin
  Check('Bsf32(1)', 0, Bsf32(1));
  Check('Bsf32(8)', 3, Bsf32(8));
  Check('Bsf32($80000000)', 31, Bsf32($80000000));
  Check('Bsr32(1)', 0, Bsr32(1));
  Check('Bsr32(8)', 3, Bsr32(8));
  Check('Bsr32($80000000)', 31, Bsr32($80000000));
  Check('Bsr32($FFFFFFFF)', 31, Bsr32($FFFFFFFF));

  Check64('Bsf64(1)', 0, Bsf64(1));
  Check64('Bsr64($8000000000000000)', 63, Bsr64($8000000000000000));
end;

procedure TestLog2;
begin
  Check('Log2Floor32(0)', 0, Log2Floor32(0));
  Check('Log2Floor32(1)', 0, Log2Floor32(1));
  Check('Log2Floor32(2)', 1, Log2Floor32(2));
  Check('Log2Floor32(3)', 1, Log2Floor32(3));
  Check('Log2Floor32(4)', 2, Log2Floor32(4));
  Check('Log2Floor32(255)', 7, Log2Floor32(255));
  Check('Log2Floor32(256)', 8, Log2Floor32(256));
  Check('Log2Floor32(1024)', 10, Log2Floor32(1024));
  Check('Log2Floor32($80000000)', 31, Log2Floor32($80000000));

  Check('Log2Ceil32(0)', 0, Log2Ceil32(0));
  Check('Log2Ceil32(1)', 0, Log2Ceil32(1));
  Check('Log2Ceil32(2)', 1, Log2Ceil32(2));
  Check('Log2Ceil32(3)', 2, Log2Ceil32(3));
  Check('Log2Ceil32(4)', 2, Log2Ceil32(4));
  Check('Log2Ceil32(5)', 3, Log2Ceil32(5));
  Check('Log2Ceil32(256)', 8, Log2Ceil32(256));
  Check('Log2Ceil32(257)', 9, Log2Ceil32(257));

  Check64('Log2Floor64(0)', 0, Log2Floor64(0));
  Check64('Log2Floor64(1024)', 10, Log2Floor64(1024));
end;

procedure TestNextPow2;
begin
  Check('NextPow2_32(0)', 0, NextPow2_32(0));
  Check('NextPow2_32(1)', 1, NextPow2_32(1));
  Check('NextPow2_32(2)', 2, NextPow2_32(2));
  Check('NextPow2_32(3)', 4, NextPow2_32(3));
  Check('NextPow2_32(5)', 8, NextPow2_32(5));
  Check('NextPow2_32(1023)', 1024, NextPow2_32(1023));
  Check('NextPow2_32(1024)', 1024, NextPow2_32(1024));
end;

procedure TestIsPow2;
begin
  CheckBool('IsPow2_32(0)', False, IsPow2_32(0));
  CheckBool('IsPow2_32(1)', True, IsPow2_32(1));
  CheckBool('IsPow2_32(2)', True, IsPow2_32(2));
  CheckBool('IsPow2_32(3)', False, IsPow2_32(3));
  CheckBool('IsPow2_32(1024)', True, IsPow2_32(1024));
  CheckBool('IsPow2_32(1025)', False, IsPow2_32(1025));
  CheckBool('IsPow2_64(0)', False, IsPow2_64(0));
  CheckBool('IsPow2_64($8000000000000000)', True, IsPow2_64($8000000000000000));
end;

begin
  GPass := 0;
  GFail := 0;

  TestClz;
  TestCtz;
  TestPopCount;
  TestBsfBsr;
  TestLog2;
  TestNextPow2;
  TestIsPow2;

  WriteLn;
  WriteLn('bitops: ', GPass, ' passed, ', GFail, ' failed');

  if GFail > 0 then
    Halt(1);
end.
