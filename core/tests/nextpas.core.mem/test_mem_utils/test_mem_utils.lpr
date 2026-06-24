program test_mem_utils;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.testing,
  nextpas.core.mem.utils;

var
  T: TTestRunner;

procedure TestIsOverlapNoOverlap;
var
  LBuf: array[0..15] of Byte;
begin
  // 两个不重叠的块
  Check(not IsOverlap(@LBuf[0], 8, @LBuf[8], 8), 'disjoint blocks should not overlap');
  Check(not IsOverlapUnChecked(@LBuf[0], 8, @LBuf[8], 8), 'unchecked: disjoint');
  WriteLn('PASS: IsOverlap no-overlap');
end;

procedure TestIsOverlapWithOverlap;
var
  LBuf: array[0..15] of Byte;
begin
  // 部分重叠
  Check(IsOverlap(@LBuf[0], 8, @LBuf[4], 8), 'overlapping blocks should overlap');
  Check(IsOverlapUnChecked(@LBuf[0], 8, @LBuf[4], 8), 'unchecked: overlapping');
  // 完全重叠
  Check(IsOverlap(@LBuf[0], 8, @LBuf[0], 8), 'identical blocks overlap');
  WriteLn('PASS: IsOverlap with-overlap');
end;

procedure TestIsOverlapBoundary;
var
  LBuf: array[0..15] of Byte;
begin
  // 恰好相邻但不重叠 (end of first == start of second)
  Check(not IsOverlap(@LBuf[0], 8, @LBuf[8], 8), 'adjacent blocks should not overlap');
  WriteLn('PASS: IsOverlap boundary');
end;

procedure TestIsOverlapSameSize;
var
  LBuf: array[0..15] of Byte;
begin
  // 三参数重载
  Check(IsOverlap(@LBuf[0], @LBuf[4], 8), 'same-size overlap');
  Check(not IsOverlap(@LBuf[0], @LBuf[8], 8), 'same-size no overlap');
  WriteLn('PASS: IsOverlap same-size overload');
end;

procedure TestCopyBasic;
var
  LSrc: array[0..7] of Byte = (1, 2, 3, 4, 5, 6, 7, 8);
  LDst: array[0..7] of Byte;
begin
  FillChar(LDst, SizeOf(LDst), 0);
  Copy(@LSrc[0], @LDst[0], 8);
  Check(Equal(@LSrc[0], @LDst[0], 8), 'copy should produce identical content');
  WriteLn('PASS: Copy basic');
end;

procedure TestCopyOverlapping;
var
  LBuf: array[0..15] of Byte;
  LI: Integer;
begin
  for LI := 0 to 15 do
    LBuf[LI] := Byte(LI);
  // Copy forward overlapping: src=0..7, dst=2..9
  Copy(@LBuf[0], @LBuf[2], 8);
  // LBuf[2] should now be 0, LBuf[3]=1, ..., LBuf[9]=7
  CheckEqual(Int64(0), Int64(LBuf[2]), 'overlap copy forward [2]');
  CheckEqual(Int64(7), Int64(LBuf[9]), 'overlap copy forward [9]');
  WriteLn('PASS: Copy overlapping');
end;

procedure TestCopyUnchecked;
var
  LSrc: array[0..3] of Byte = ($AA, $BB, $CC, $DD);
  LDst: array[0..3] of Byte;
begin
  FillChar(LDst, SizeOf(LDst), 0);
  CopyUnChecked(@LSrc[0], @LDst[0], 4);
  Check(Equal(@LSrc[0], @LDst[0], 4), 'CopyUnChecked should work');
  WriteLn('PASS: CopyUnChecked');
end;

procedure TestCopyNonOverlap;
var
  LSrc: array[0..7] of Byte = ($FF, $EE, $DD, $CC, $BB, $AA, $99, $88);
  LDst: array[0..7] of Byte;
begin
  FillChar(LDst, SizeOf(LDst), 0);
  CopyNonOverlap(@LSrc[0], @LDst[0], 8);
  Check(Equal(@LSrc[0], @LDst[0], 8), 'CopyNonOverlap should work');
  WriteLn('PASS: CopyNonOverlap');
end;

procedure TestCopyZeroSize;
var
  LSrc, LDst: Integer;
begin
  LSrc := $12345678;
  LDst := $7ABCDEF0;
  Copy(@LSrc, @LDst, 0);
  CheckEqual(Int64($7ABCDEF0), Int64(LDst), 'zero-size copy should not modify dst');
  WriteLn('PASS: Copy zero-size');
end;

procedure TestFill;
var
  LBuf: array[0..63] of Byte;
  LI: Integer;
begin
  Fill(@LBuf[0], 64, $AB);
  for LI := 0 to 63 do
    CheckEqual(Int64($AB), Int64(LBuf[LI]), 'Fill byte ' + IntToStr(LI));
  WriteLn('PASS: Fill (8-bit)');
end;

procedure TestFill8SizeInt;
var
  LBuf: array[0..15] of Byte;
  LI: Integer;
begin
  FillChar(LBuf, SizeOf(LBuf), 0);
  Fill8(@LBuf[0], SizeInt(16), $CD);
  for LI := 0 to 15 do
    CheckEqual(Int64($CD), Int64(LBuf[LI]), 'Fill8 SizeInt ' + IntToStr(LI));
  WriteLn('PASS: Fill8 (SizeInt)');
end;

procedure TestFill16;
var
  LWords: array[0..3] of UInt16;
  LI: Integer;
begin
  Fill16(@LWords[0], 4, $BEEF);
  for LI := 0 to 3 do
    CheckEqual(Int64($BEEF), Int64(LWords[LI]), 'Fill16 word ' + IntToStr(LI));
  WriteLn('PASS: Fill16');
end;

procedure TestFill32;
var
  LDwords: array[0..3] of UInt32;
  LI: Integer;
begin
  Fill32(@LDwords[0], 4, UInt32($DEADBEEF));
  for LI := 0 to 3 do
    CheckEqual(Int64(UInt32($DEADBEEF)), Int64(LDwords[LI]), 'Fill32 dword ' + IntToStr(LI));
  WriteLn('PASS: Fill32');
end;

procedure TestFill64;
var
  LQwords: array[0..3] of UInt64;
  LVal: UInt64;
  LI: Integer;
begin
  LVal := UInt64($DEADBEEF) shl 32 + UInt64($CAFEBABE);
  Fill64(@LQwords[0], 4, LVal);
  for LI := 0 to 3 do
    Check(LVal = LQwords[LI], 'Fill64 qword ' + IntToStr(LI));
  WriteLn('PASS: Fill64');
end;

procedure TestZero;
var
  LBuf: array[0..31] of Byte;
  LI: Integer;
begin
  FillChar(LBuf, SizeOf(LBuf), $FF);
  Zero(@LBuf[0], 32);
  for LI := 0 to 31 do
    CheckEqual(Int64(0), Int64(LBuf[LI]), 'Zero byte ' + IntToStr(LI));
  WriteLn('PASS: Zero');
end;

procedure TestCompareEqual;
var
  LA, LB: array[0..7] of Byte;
begin
  LA[0] := 1; LA[1] := 2; LA[2] := 3; LA[3] := 4;
  LA[4] := 5; LA[5] := 6; LA[6] := 7; LA[7] := 8;
  LB := LA;
  CheckEqual(Int64(0), Int64(Compare(@LA[0], @LB[0], 8)), 'Compare equal');
  CheckEqual(Int64(0), Int64(Compare8(@LA[0], @LB[0], SizeInt(8))), 'Compare8 equal');
  WriteLn('PASS: Compare equal');
end;

procedure TestCompareNotEqual;
var
  LA: array[0..3] of Byte = (1, 2, 3, 4);
  LB: array[0..3] of Byte = (1, 2, 3, 5);
begin
  Check(Compare(@LA[0], @LB[0], 4) < 0, 'a < b');
  Check(Compare(@LB[0], @LA[0], 4) > 0, 'b > a');
  WriteLn('PASS: Compare not-equal');
end;

procedure TestCompare16;
var
  LA: array[0..3] of UInt16 = ($1111, $2222, $3333, $4444);
  LB: array[0..3] of UInt16 = ($1111, $2222, $3333, $4444);
  LC: array[0..3] of UInt16 = ($1111, $2222, $3333, $5555);
begin
  CheckEqual(Int64(0), Int64(Compare16(@LA[0], @LB[0], 4)), 'Compare16 equal');
  Check(Compare16(@LA[0], @LC[0], 4) <> 0, 'Compare16 not equal');
  WriteLn('PASS: Compare16');
end;

procedure TestCompare32;
var
  LA: array[0..3] of UInt32 = ($11111111, $22222222, $33333333, $44444444);
  LB: array[0..3] of UInt32 = ($11111111, $22222222, $33333333, $44444444);
begin
  CheckEqual(Int64(0), Int64(Compare32(@LA[0], @LB[0], 4)), 'Compare32 equal');
  WriteLn('PASS: Compare32');
end;

procedure TestEqual;
var
  LA: array[0..7] of Byte = ($AA, $BB, $CC, $DD, $EE, $FF, $00, $11);
  LB: array[0..7] of Byte = ($AA, $BB, $CC, $DD, $EE, $FF, $00, $11);
  LC: array[0..7] of Byte = ($AA, $BB, $CC, $DD, $EE, $FF, $00, $12);
begin
  Check(Equal(@LA[0], @LB[0], 8), 'Equal should be true');
  Check(not Equal(@LA[0], @LC[0], 8), 'Equal should be false');
  WriteLn('PASS: Equal');
end;

procedure TestEqualZeroSize;
var
  LA, LB: Integer;
begin
  LA := 12345;
  LB := 99999;
  Check(Equal(@LA, @LB, 0), 'Equal with zero size should return true');
  WriteLn('PASS: Equal zero-size');
end;

procedure TestIsAligned;
begin
  Check(IsAligned(Pointer($1000), 8), '$1000 aligned to 8');
  Check(IsAligned(Pointer($1000), 16), '$1000 aligned to 16');
  Check(not IsAligned(Pointer($1001), 8), '$1001 not aligned to 8');
  Check(IsAligned(Pointer(0), 8), 'nil aligned to anything');
  Check(IsAligned(Pointer($1000), SizeOf(Pointer)), 'default alignment');
  WriteLn('PASS: IsAligned');
end;

procedure TestAlignUp;
var
  LPtr: Pointer;
begin
  LPtr := AlignUp(Pointer($1001), 16);
  CheckEqual(Int64($1010), Int64(PtrUInt(LPtr)), 'AlignUp $1001 to 16');
  LPtr := AlignUp(Pointer($1000), 16);
  CheckEqual(Int64($1000), Int64(PtrUInt(LPtr)), 'AlignUp $1000 to 16 (already aligned)');
  LPtr := AlignUp(Pointer($1003), 4);
  CheckEqual(Int64($1004), Int64(PtrUInt(LPtr)), 'AlignUp $1003 to 4');
  WriteLn('PASS: AlignUp');
end;

procedure TestAlignUpUnChecked;
var
  LPtr: Pointer;
begin
  LPtr := AlignUpUnChecked(Pointer($2005), 8);
  CheckEqual(Int64($2008), Int64(PtrUInt(LPtr)), 'AlignUpUnChecked $2005 to 8');
  WriteLn('PASS: AlignUpUnChecked');
end;

procedure TestIsPowerOfTwo;
begin
  Check(not IsPowerOfTwo(0), '0 is not power of 2');
  Check(IsPowerOfTwo(1), '1 is power of 2');
  Check(IsPowerOfTwo(2), '2 is power of 2');
  Check(not IsPowerOfTwo(3), '3 is not power of 2');
  Check(IsPowerOfTwo(4), '4 is power of 2');
  Check(not IsPowerOfTwo(5), '5 is not power of 2');
  Check(not IsPowerOfTwo(6), '6 is not power of 2');
  Check(not IsPowerOfTwo(7), '7 is not power of 2');
  Check(IsPowerOfTwo(8), '8 is power of 2');
  Check(IsPowerOfTwo(1024), '1024 is power of 2');
  Check(IsPowerOfTwo(SizeUInt(1) shl 62), '2^62 is power of 2');
  Check(not IsPowerOfTwo((SizeUInt(1) shl 63) - 1), '2^63-1 is not power of 2');
  // 2^63 only testable if SizeUInt is 64-bit
  if SizeOf(SizeUInt) = 8 then
    Check(IsPowerOfTwo(SizeUInt(1) shl 63), '2^63 is power of 2');
  WriteLn('PASS: IsPowerOfTwo');
end;

procedure TestFillZeroCount;
var
  LBuf: array[0..7] of Byte;
begin
  FillChar(LBuf, SizeOf(LBuf), $42);
  Fill(@LBuf[0], 0, $FF);
  CheckEqual(Int64($42), Int64(LBuf[0]), 'Fill with count=0 should be no-op');
  WriteLn('PASS: Fill zero-count');
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.utils');
  T.Run('IsOverlap no-overlap', @TestIsOverlapNoOverlap);
  T.Run('IsOverlap with-overlap', @TestIsOverlapWithOverlap);
  T.Run('IsOverlap boundary', @TestIsOverlapBoundary);
  T.Run('IsOverlap same-size overload', @TestIsOverlapSameSize);
  T.Run('Copy basic', @TestCopyBasic);
  T.Run('Copy overlapping', @TestCopyOverlapping);
  T.Run('CopyUnChecked', @TestCopyUnchecked);
  T.Run('CopyNonOverlap', @TestCopyNonOverlap);
  T.Run('Copy zero-size', @TestCopyZeroSize);
  T.Run('Fill', @TestFill);
  T.Run('Fill8 SizeInt', @TestFill8SizeInt);
  T.Run('Fill16', @TestFill16);
  T.Run('Fill32', @TestFill32);
  T.Run('Fill64', @TestFill64);
  T.Run('Zero', @TestZero);
  T.Run('Compare equal', @TestCompareEqual);
  T.Run('Compare not-equal', @TestCompareNotEqual);
  T.Run('Compare16', @TestCompare16);
  T.Run('Compare32', @TestCompare32);
  T.Run('Equal', @TestEqual);
  T.Run('Equal zero-size', @TestEqualZeroSize);
  T.Run('IsAligned', @TestIsAligned);
  T.Run('AlignUp', @TestAlignUp);
  T.Run('AlignUpUnChecked', @TestAlignUpUnChecked);
  T.Run('IsPowerOfTwo', @TestIsPowerOfTwo);
  T.Run('Fill zero-count', @TestFillZeroCount);
  T.Summary;
end.
