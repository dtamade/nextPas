program test_vec_all;
{$mode objfpc}{$H+}
uses
  nextpas.core.simd.base,
  nextpas.core.simd.vec16,
  nextpas.core.simd.vec32,
  nextpas.core.simd.vec64;

var
  GTestCount: Integer = 0;
  GPassCount: Integer = 0;

function LocalIntToStr(aValue: Integer): string;
begin
  Str(aValue, Result);
end;

function LocalIntToHex(aValue: Integer; aDigits: Integer): string;
const
  HexChars: array[0..15] of Char = '0123456789ABCDEF';
var
  i: Integer;
begin
  SetLength(Result, aDigits);
  for i := aDigits downto 1 do
  begin
    Result[i] := HexChars[aValue and $F];
    aValue := aValue shr 4;
  end;
end;

procedure Check(cond: Boolean; const msg: string);
begin
  Inc(GTestCount);
  if not cond then begin
    WriteLn('FAIL: ', msg);
    Halt(1);
  end;
  Inc(GPassCount);
end;

// ============================================================
// Vec16 Tests (width=16)
// ============================================================

procedure TestVec16CmpEq;
var
  data, allSame: array[0..15] of Byte;
  i: Integer;
  m: TMask16;
begin
  for i := 0 to 15 do data[i] := i;
  m := Vec16CmpEq(@data[0], 0);
  Check(m = TMask16($0001), 'Vec16CmpEq value=0: got $' + LocalIntToHex(m, 4));
  m := Vec16CmpEq(@data[0], 255);
  Check(m = TMask16(0), 'Vec16CmpEq value=255 no match: got $' + LocalIntToHex(m, 4));
  for i := 0 to 15 do allSame[i] := 42;
  m := Vec16CmpEq(@allSame[0], 42);
  Check(m = TMask16($FFFF), 'Vec16CmpEq all same: got $' + LocalIntToHex(m, 4));
  m := Vec16CmpEq(@allSame[0], 99);
  Check(m = TMask16(0), 'Vec16CmpEq no match: got $' + LocalIntToHex(m, 4));
  m := Vec16CmpEq(@data[0], 7);
  Check(m = TMask16($0080), 'Vec16CmpEq value=7: got $' + LocalIntToHex(m, 4));
end;

procedure TestVec16CmpEq2;
var
  a, b, c: array[0..15] of Byte;
  i: Integer;
  m: TMask16;
begin
  for i := 0 to 15 do begin a[i] := i; b[i] := i; end;
  m := Vec16CmpEq2(@a[0], @b[0]);
  Check(m = TMask16($FFFF), 'Vec16CmpEq2 identical: got $' + LocalIntToHex(m, 4));
  for i := 0 to 15 do c[i] := i + 100;
  m := Vec16CmpEq2(@a[0], @c[0]);
  Check(m = TMask16(0), 'Vec16CmpEq2 all different: got $' + LocalIntToHex(m, 4));
  for i := 0 to 15 do begin
    a[i] := i;
    if (i mod 2) = 0 then b[i] := i else b[i] := 200;
  end;
  m := Vec16CmpEq2(@a[0], @b[0]);
  Check(m = TMask16($5555), 'Vec16CmpEq2 partial (even): got $' + LocalIntToHex(m, 4));
end;

procedure TestVec16CmpLtU;
var
  data, allZero, all255: array[0..15] of Byte;
  i: Integer;
  m: TMask16;
begin
  for i := 0 to 15 do data[i] := i;
  FillByte(allZero[0], 16, 0);
  FillByte(all255[0], 16, 255);
  m := Vec16CmpLtU(@data[0], 0);
  Check(m = TMask16(0), 'Vec16CmpLtU threshold=0: got $' + LocalIntToHex(m, 4));
  m := Vec16CmpLtU(@data[0], 1);
  Check(m = TMask16($0001), 'Vec16CmpLtU threshold=1: got $' + LocalIntToHex(m, 4));
  m := Vec16CmpLtU(@data[0], 255);
  Check(m = TMask16($FFFF), 'Vec16CmpLtU threshold=255 sequential: got $' + LocalIntToHex(m, 4));
  m := Vec16CmpLtU(@allZero[0], 255);
  Check(m = TMask16($FFFF), 'Vec16CmpLtU allZero thr=255: got $' + LocalIntToHex(m, 4));
  m := Vec16CmpLtU(@all255[0], 255);
  Check(m = TMask16(0), 'Vec16CmpLtU all255 thr=255: got $' + LocalIntToHex(m, 4));
  m := Vec16CmpLtU(@data[0], 5);
  Check(m = TMask16($001F), 'Vec16CmpLtU threshold=5: got $' + LocalIntToHex(m, 4));
end;

procedure TestVec16CmpGtU;
var
  data, allZero, all255: array[0..15] of Byte;
  i: Integer;
  m: TMask16;
begin
  for i := 0 to 15 do data[i] := i;
  FillByte(allZero[0], 16, 0);
  FillByte(all255[0], 16, 255);
  m := Vec16CmpGtU(@data[0], 0);
  Check(m = TMask16($FFFE), 'Vec16CmpGtU threshold=0: got $' + LocalIntToHex(m, 4));
  m := Vec16CmpGtU(@data[0], 14);
  Check(m = TMask16($8000), 'Vec16CmpGtU threshold=14: got $' + LocalIntToHex(m, 4));
  m := Vec16CmpGtU(@data[0], 255);
  Check(m = TMask16(0), 'Vec16CmpGtU threshold=255: got $' + LocalIntToHex(m, 4));
  m := Vec16CmpGtU(@allZero[0], 0);
  Check(m = TMask16(0), 'Vec16CmpGtU allZero thr=0: got $' + LocalIntToHex(m, 4));
  m := Vec16CmpGtU(@all255[0], 254);
  Check(m = TMask16($FFFF), 'Vec16CmpGtU all255 thr=254: got $' + LocalIntToHex(m, 4));
  m := Vec16CmpGtU(@all255[0], 255);
  Check(m = TMask16(0), 'Vec16CmpGtU all255 thr=255: got $' + LocalIntToHex(m, 4));
end;

procedure TestVec16CmpRange;
var
  data: array[0..15] of Byte;
  i: Integer;
  m: TMask16;
begin
  for i := 0 to 15 do data[i] := i;
  m := Vec16CmpRange(@data[0], 0, 255);
  Check(m = TMask16($FFFF), 'Vec16CmpRange 0..255: got $' + LocalIntToHex(m, 4));
  m := Vec16CmpRange(@data[0], 7, 7);
  Check(m = TMask16($0080), 'Vec16CmpRange 7..7: got $' + LocalIntToHex(m, 4));
  m := Vec16CmpRange(@data[0], 10, 5);
  Check(m = TMask16(0), 'Vec16CmpRange 10..5 (inverted): got $' + LocalIntToHex(m, 4));
  m := Vec16CmpRange(@data[0], 3, 7);
  Check(m = TMask16($00F8), 'Vec16CmpRange 3..7: got $' + LocalIntToHex(m, 4));
end;

procedure TestVec16Ctz;
var
  r: Int32;
begin
  r := Vec16Ctz(TMask16(0));
  Check(r = -1, 'Vec16Ctz(0)=-1: got ' + LocalIntToStr(r));
  r := Vec16Ctz(TMask16(1));
  Check(r = 0, 'Vec16Ctz(1)=0: got ' + LocalIntToStr(r));
  r := Vec16Ctz(TMask16($8000));
  Check(r = 15, 'Vec16Ctz(highest)=15: got ' + LocalIntToStr(r));
  r := Vec16Ctz(TMask16($FFFF));
  Check(r = 0, 'Vec16Ctz(all1)=0: got ' + LocalIntToStr(r));
  r := Vec16Ctz(TMask16($0080));
  Check(r = 7, 'Vec16Ctz($0080)=7: got ' + LocalIntToStr(r));
end;

procedure TestVec16Popcnt;
var
  r: Int32;
begin
  r := Vec16Popcnt(TMask16(0));
  Check(r = 0, 'Vec16Popcnt(0)=0: got ' + LocalIntToStr(r));
  r := Vec16Popcnt(TMask16($FFFF));
  Check(r = 16, 'Vec16Popcnt(all1)=16: got ' + LocalIntToStr(r));
  r := Vec16Popcnt(TMask16($5555));
  Check(r = 8, 'Vec16Popcnt($5555)=8: got ' + LocalIntToStr(r));
  r := Vec16Popcnt(TMask16($AAAA));
  Check(r = 8, 'Vec16Popcnt($AAAA)=8: got ' + LocalIntToStr(r));
  r := Vec16Popcnt(TMask16($0080));
  Check(r = 1, 'Vec16Popcnt($0080)=1: got ' + LocalIntToStr(r));
end;

procedure TestVec16AddWhere;
var
  data, backup: array[0..15] of Byte;
  i: Integer;
  m: TMask16;
begin
  for i := 0 to 15 do data[i] := i;
  m := TMask16($FFFF);
  Vec16AddWhere(@data[0], m, 10);
  for i := 0 to 15 do
    Check(data[i] = Byte(i + 10), 'Vec16AddWhere +10 idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));

  FillByte(data[0], 16, 255);
  Vec16AddWhere(@data[0], m, 1);
  for i := 0 to 15 do
    Check(data[i] = 0, 'Vec16AddWhere overflow idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));

  for i := 0 to 15 do data[i] := i;
  Vec16AddWhere(@data[0], TMask16(0), 50);
  for i := 0 to 15 do
    Check(data[i] = i, 'Vec16AddWhere mask=0 idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));

  for i := 0 to 15 do data[i] := i;
  Vec16AddWhere(@data[0], m, 0);
  for i := 0 to 15 do
    Check(data[i] = i, 'Vec16AddWhere delta=0 idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));
end;

procedure TestVec16SubWhere;
var
  data: array[0..15] of Byte;
  i: Integer;
  m: TMask16;
begin
  for i := 0 to 15 do data[i] := i + 20;
  m := TMask16($FFFF);
  Vec16SubWhere(@data[0], m, 10);
  for i := 0 to 15 do
    Check(data[i] = Byte(i + 10), 'Vec16SubWhere -10 idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));

  FillByte(data[0], 16, 0);
  Vec16SubWhere(@data[0], m, 1);
  for i := 0 to 15 do
    Check(data[i] = 255, 'Vec16SubWhere underflow idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));

  for i := 0 to 15 do data[i] := i;
  Vec16SubWhere(@data[0], TMask16(0), 50);
  for i := 0 to 15 do
    Check(data[i] = i, 'Vec16SubWhere mask=0 idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));

  for i := 0 to 15 do data[i] := i;
  Vec16SubWhere(@data[0], m, 0);
  for i := 0 to 15 do
    Check(data[i] = i, 'Vec16SubWhere delta=0 idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));
end;

// ============================================================
// Vec32 Tests (width=32)
// ============================================================

procedure TestVec32CmpEq;
var
  data, allSame: array[0..31] of Byte;
  i: Integer;
  m: TMask32;
begin
  for i := 0 to 31 do data[i] := i;
  m := Vec32CmpEq(@data[0], 0);
  Check(m = TMask32($00000001), 'Vec32CmpEq value=0: got $' + LocalIntToHex(m, 8));
  m := Vec32CmpEq(@data[0], 255);
  Check(m = TMask32(0), 'Vec32CmpEq value=255 no match: got $' + LocalIntToHex(m, 8));
  for i := 0 to 31 do allSame[i] := 42;
  m := Vec32CmpEq(@allSame[0], 42);
  Check(m = TMask32($FFFFFFFF), 'Vec32CmpEq all same: got $' + LocalIntToHex(m, 8));
  m := Vec32CmpEq(@allSame[0], 99);
  Check(m = TMask32(0), 'Vec32CmpEq no match: got $' + LocalIntToHex(m, 8));
  m := Vec32CmpEq(@data[0], 7);
  Check(m = TMask32($00000080), 'Vec32CmpEq value=7: got $' + LocalIntToHex(m, 8));
end;

procedure TestVec32CmpEq2;
var
  a, b, c: array[0..31] of Byte;
  i: Integer;
  m: TMask32;
begin
  for i := 0 to 31 do begin a[i] := i; b[i] := i; end;
  m := Vec32CmpEq2(@a[0], @b[0]);
  Check(m = TMask32($FFFFFFFF), 'Vec32CmpEq2 identical: got $' + LocalIntToHex(m, 8));
  for i := 0 to 31 do c[i] := i + 100;
  m := Vec32CmpEq2(@a[0], @c[0]);
  Check(m = TMask32(0), 'Vec32CmpEq2 all different: got $' + LocalIntToHex(m, 8));
  for i := 0 to 31 do begin
    a[i] := i;
    if (i mod 2) = 0 then b[i] := i else b[i] := 200;
  end;
  m := Vec32CmpEq2(@a[0], @b[0]);
  Check(m = TMask32($55555555), 'Vec32CmpEq2 partial (even): got $' + LocalIntToHex(m, 8));
end;

procedure TestVec32CmpLtU;
var
  data, allZero, all255: array[0..31] of Byte;
  i: Integer;
  m: TMask32;
begin
  for i := 0 to 31 do data[i] := i;
  FillByte(allZero[0], 32, 0);
  FillByte(all255[0], 32, 255);
  m := Vec32CmpLtU(@data[0], 0);
  Check(m = TMask32(0), 'Vec32CmpLtU threshold=0: got $' + LocalIntToHex(m, 8));
  m := Vec32CmpLtU(@data[0], 1);
  Check(m = TMask32($00000001), 'Vec32CmpLtU threshold=1: got $' + LocalIntToHex(m, 8));
  m := Vec32CmpLtU(@data[0], 255);
  Check(m = TMask32($FFFFFFFF), 'Vec32CmpLtU threshold=255 sequential: got $' + LocalIntToHex(m, 8));
  m := Vec32CmpLtU(@allZero[0], 255);
  Check(m = TMask32($FFFFFFFF), 'Vec32CmpLtU allZero thr=255: got $' + LocalIntToHex(m, 8));
  m := Vec32CmpLtU(@all255[0], 255);
  Check(m = TMask32(0), 'Vec32CmpLtU all255 thr=255: got $' + LocalIntToHex(m, 8));
  m := Vec32CmpLtU(@data[0], 5);
  Check(m = TMask32($0000001F), 'Vec32CmpLtU threshold=5: got $' + LocalIntToHex(m, 8));
end;

procedure TestVec32CmpGtU;
var
  data, allZero, all255: array[0..31] of Byte;
  i: Integer;
  m: TMask32;
begin
  for i := 0 to 31 do data[i] := i;
  FillByte(allZero[0], 32, 0);
  FillByte(all255[0], 32, 255);
  m := Vec32CmpGtU(@data[0], 0);
  Check(m = TMask32($FFFFFFFE), 'Vec32CmpGtU threshold=0: got $' + LocalIntToHex(m, 8));
  m := Vec32CmpGtU(@data[0], 30);
  Check(m = TMask32($80000000), 'Vec32CmpGtU threshold=30: got $' + LocalIntToHex(m, 8));
  m := Vec32CmpGtU(@data[0], 255);
  Check(m = TMask32(0), 'Vec32CmpGtU threshold=255: got $' + LocalIntToHex(m, 8));
  m := Vec32CmpGtU(@allZero[0], 0);
  Check(m = TMask32(0), 'Vec32CmpGtU allZero thr=0: got $' + LocalIntToHex(m, 8));
  m := Vec32CmpGtU(@all255[0], 254);
  Check(m = TMask32($FFFFFFFF), 'Vec32CmpGtU all255 thr=254: got $' + LocalIntToHex(m, 8));
  m := Vec32CmpGtU(@all255[0], 255);
  Check(m = TMask32(0), 'Vec32CmpGtU all255 thr=255: got $' + LocalIntToHex(m, 8));
end;

procedure TestVec32CmpRange;
var
  data: array[0..31] of Byte;
  i: Integer;
  m: TMask32;
begin
  for i := 0 to 31 do data[i] := i;
  m := Vec32CmpRange(@data[0], 0, 255);
  Check(m = TMask32($FFFFFFFF), 'Vec32CmpRange 0..255: got $' + LocalIntToHex(m, 8));
  m := Vec32CmpRange(@data[0], 7, 7);
  Check(m = TMask32($00000080), 'Vec32CmpRange 7..7: got $' + LocalIntToHex(m, 8));
  m := Vec32CmpRange(@data[0], 10, 5);
  Check(m = TMask32(0), 'Vec32CmpRange 10..5 (inverted): got $' + LocalIntToHex(m, 8));
  m := Vec32CmpRange(@data[0], 3, 7);
  Check(m = TMask32($000000F8), 'Vec32CmpRange 3..7: got $' + LocalIntToHex(m, 8));
end;

procedure TestVec32Ctz;
var
  r: Int32;
begin
  r := Vec32Ctz(TMask32(0));
  Check(r = -1, 'Vec32Ctz(0)=-1: got ' + LocalIntToStr(r));
  r := Vec32Ctz(TMask32(1));
  Check(r = 0, 'Vec32Ctz(1)=0: got ' + LocalIntToStr(r));
  r := Vec32Ctz(TMask32($80000000));
  Check(r = 31, 'Vec32Ctz(highest)=31: got ' + LocalIntToStr(r));
  r := Vec32Ctz(TMask32($FFFFFFFF));
  Check(r = 0, 'Vec32Ctz(all1)=0: got ' + LocalIntToStr(r));
  r := Vec32Ctz(TMask32($0080));
  Check(r = 7, 'Vec32Ctz($0080)=7: got ' + LocalIntToStr(r));
end;

procedure TestVec32Popcnt;
var
  r: Int32;
begin
  r := Vec32Popcnt(TMask32(0));
  Check(r = 0, 'Vec32Popcnt(0)=0: got ' + LocalIntToStr(r));
  r := Vec32Popcnt(TMask32($FFFFFFFF));
  Check(r = 32, 'Vec32Popcnt(all1)=32: got ' + LocalIntToStr(r));
  r := Vec32Popcnt(TMask32($55555555));
  Check(r = 16, 'Vec32Popcnt($5555...)=16: got ' + LocalIntToStr(r));
  r := Vec32Popcnt(TMask32($AAAAAAAA));
  Check(r = 16, 'Vec32Popcnt($AAAA...)=16: got ' + LocalIntToStr(r));
  r := Vec32Popcnt(TMask32($0080));
  Check(r = 1, 'Vec32Popcnt($0080)=1: got ' + LocalIntToStr(r));
end;

procedure TestVec32AddWhere;
var
  data, backup: array[0..31] of Byte;
  i: Integer;
  m: TMask32;
begin
  for i := 0 to 31 do data[i] := i;
  m := TMask32($FFFFFFFF);
  Vec32AddWhere(@data[0], m, 10);
  for i := 0 to 31 do
    Check(data[i] = Byte(i + 10), 'Vec32AddWhere +10 idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));

  FillByte(data[0], 32, 255);
  Vec32AddWhere(@data[0], m, 1);
  for i := 0 to 31 do
    Check(data[i] = 0, 'Vec32AddWhere overflow idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));

  for i := 0 to 31 do data[i] := i;
  Vec32AddWhere(@data[0], TMask32(0), 50);
  for i := 0 to 31 do
    Check(data[i] = i, 'Vec32AddWhere mask=0 idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));

  for i := 0 to 31 do data[i] := i;
  Vec32AddWhere(@data[0], m, 0);
  for i := 0 to 31 do
    Check(data[i] = i, 'Vec32AddWhere delta=0 idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));
end;

procedure TestVec32SubWhere;
var
  data: array[0..31] of Byte;
  i: Integer;
  m: TMask32;
begin
  for i := 0 to 31 do data[i] := i + 20;
  m := TMask32($FFFFFFFF);
  Vec32SubWhere(@data[0], m, 10);
  for i := 0 to 31 do
    Check(data[i] = Byte(i + 10), 'Vec32SubWhere -10 idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));

  FillByte(data[0], 32, 0);
  Vec32SubWhere(@data[0], m, 1);
  for i := 0 to 31 do
    Check(data[i] = 255, 'Vec32SubWhere underflow idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));

  for i := 0 to 31 do data[i] := i;
  Vec32SubWhere(@data[0], TMask32(0), 50);
  for i := 0 to 31 do
    Check(data[i] = i, 'Vec32SubWhere mask=0 idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));

  for i := 0 to 31 do data[i] := i;
  Vec32SubWhere(@data[0], m, 0);
  for i := 0 to 31 do
    Check(data[i] = i, 'Vec32SubWhere delta=0 idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));
end;

// ============================================================
// Vec64 Tests (width=64)
// ============================================================

procedure TestVec64CmpEq;
var
  data, allSame: array[0..63] of Byte;
  i: Integer;
  m: TMask64;
begin
  for i := 0 to 63 do data[i] := i;
  m := Vec64CmpEq(@data[0], 0);
  Check(m = TMask64(QWord($0000000000000001)), 'Vec64CmpEq value=0: got $' + LocalIntToHex(m, 16));
  m := Vec64CmpEq(@data[0], 255);
  Check(m = TMask64(0), 'Vec64CmpEq value=255 no match: got $' + LocalIntToHex(m, 16));
  for i := 0 to 63 do allSame[i] := 42;
  m := Vec64CmpEq(@allSame[0], 42);
  Check(m = TMask64(QWord($FFFFFFFFFFFFFFFF)), 'Vec64CmpEq all same: got $' + LocalIntToHex(m, 16));
  m := Vec64CmpEq(@allSame[0], 99);
  Check(m = TMask64(0), 'Vec64CmpEq no match: got $' + LocalIntToHex(m, 16));
  m := Vec64CmpEq(@data[0], 7);
  Check(m = TMask64(QWord($0000000000000080)), 'Vec64CmpEq value=7: got $' + LocalIntToHex(m, 16));
end;

procedure TestVec64CmpEq2;
var
  a, b, c: array[0..63] of Byte;
  i: Integer;
  m: TMask64;
begin
  for i := 0 to 63 do begin a[i] := i; b[i] := i; end;
  m := Vec64CmpEq2(@a[0], @b[0]);
  Check(m = TMask64(QWord($FFFFFFFFFFFFFFFF)), 'Vec64CmpEq2 identical: got $' + LocalIntToHex(m, 16));
  for i := 0 to 63 do c[i] := i + 100;
  m := Vec64CmpEq2(@a[0], @c[0]);
  Check(m = TMask64(0), 'Vec64CmpEq2 all different: got $' + LocalIntToHex(m, 16));
  for i := 0 to 63 do begin
    a[i] := i;
    if (i mod 2) = 0 then b[i] := i else b[i] := 200;
  end;
  m := Vec64CmpEq2(@a[0], @b[0]);
  Check(m = TMask64(QWord($5555555555555555)), 'Vec64CmpEq2 partial (even): got $' + LocalIntToHex(m, 16));
end;

procedure TestVec64CmpLtU;
var
  data, allZero, all255: array[0..63] of Byte;
  i: Integer;
  m: TMask64;
begin
  for i := 0 to 63 do data[i] := i;
  FillByte(allZero[0], 64, 0);
  FillByte(all255[0], 64, 255);
  m := Vec64CmpLtU(@data[0], 0);
  Check(m = TMask64(0), 'Vec64CmpLtU threshold=0: got $' + LocalIntToHex(m, 16));
  m := Vec64CmpLtU(@data[0], 1);
  Check(m = TMask64(QWord($0000000000000001)), 'Vec64CmpLtU threshold=1: got $' + LocalIntToHex(m, 16));
  m := Vec64CmpLtU(@data[0], 255);
  Check(m = TMask64(QWord($FFFFFFFFFFFFFFFF)), 'Vec64CmpLtU threshold=255 sequential: got $' + LocalIntToHex(m, 16));
  m := Vec64CmpLtU(@allZero[0], 255);
  Check(m = TMask64(QWord($FFFFFFFFFFFFFFFF)), 'Vec64CmpLtU allZero thr=255: got $' + LocalIntToHex(m, 16));
  m := Vec64CmpLtU(@all255[0], 255);
  Check(m = TMask64(0), 'Vec64CmpLtU all255 thr=255: got $' + LocalIntToHex(m, 16));
  m := Vec64CmpLtU(@data[0], 5);
  Check(m = TMask64(QWord($000000000000001F)), 'Vec64CmpLtU threshold=5: got $' + LocalIntToHex(m, 16));
end;

procedure TestVec64CmpGtU;
var
  data, allZero, all255: array[0..63] of Byte;
  i: Integer;
  m: TMask64;
begin
  for i := 0 to 63 do data[i] := i;
  FillByte(allZero[0], 64, 0);
  FillByte(all255[0], 64, 255);
  m := Vec64CmpGtU(@data[0], 0);
  Check(m = TMask64(QWord($FFFFFFFFFFFFFFFE)), 'Vec64CmpGtU threshold=0: got $' + LocalIntToHex(m, 16));
  m := Vec64CmpGtU(@data[0], 62);
  Check(m = TMask64(QWord($8000000000000000)), 'Vec64CmpGtU threshold=62: got $' + LocalIntToHex(m, 16));
  m := Vec64CmpGtU(@data[0], 255);
  Check(m = TMask64(0), 'Vec64CmpGtU threshold=255: got $' + LocalIntToHex(m, 16));
  m := Vec64CmpGtU(@allZero[0], 0);
  Check(m = TMask64(0), 'Vec64CmpGtU allZero thr=0: got $' + LocalIntToHex(m, 16));
  m := Vec64CmpGtU(@all255[0], 254);
  Check(m = TMask64(QWord($FFFFFFFFFFFFFFFF)), 'Vec64CmpGtU all255 thr=254: got $' + LocalIntToHex(m, 16));
  m := Vec64CmpGtU(@all255[0], 255);
  Check(m = TMask64(0), 'Vec64CmpGtU all255 thr=255: got $' + LocalIntToHex(m, 16));
end;

procedure TestVec64CmpRange;
var
  data: array[0..63] of Byte;
  i: Integer;
  m: TMask64;
begin
  for i := 0 to 63 do data[i] := i;
  m := Vec64CmpRange(@data[0], 0, 255);
  Check(m = TMask64(QWord($FFFFFFFFFFFFFFFF)), 'Vec64CmpRange 0..255: got $' + LocalIntToHex(m, 16));
  m := Vec64CmpRange(@data[0], 7, 7);
  Check(m = TMask64(QWord($0000000000000080)), 'Vec64CmpRange 7..7: got $' + LocalIntToHex(m, 16));
  m := Vec64CmpRange(@data[0], 10, 5);
  Check(m = TMask64(0), 'Vec64CmpRange 10..5 (inverted): got $' + LocalIntToHex(m, 16));
  m := Vec64CmpRange(@data[0], 3, 7);
  Check(m = TMask64(QWord($00000000000000F8)), 'Vec64CmpRange 3..7: got $' + LocalIntToHex(m, 16));
end;

procedure TestVec64Ctz;
var
  r: Int32;
begin
  r := Vec64Ctz(TMask64(0));
  Check(r = -1, 'Vec64Ctz(0)=-1: got ' + LocalIntToStr(r));
  r := Vec64Ctz(TMask64(1));
  Check(r = 0, 'Vec64Ctz(1)=0: got ' + LocalIntToStr(r));
  r := Vec64Ctz(TMask64(QWord($8000000000000000)));
  Check(r = 63, 'Vec64Ctz(highest)=63: got ' + LocalIntToStr(r));
  r := Vec64Ctz(TMask64(QWord($FFFFFFFFFFFFFFFF)));
  Check(r = 0, 'Vec64Ctz(all1)=0: got ' + LocalIntToStr(r));
  r := Vec64Ctz(TMask64($0080));
  Check(r = 7, 'Vec64Ctz($0080)=7: got ' + LocalIntToStr(r));
end;

procedure TestVec64Popcnt;
var
  r: Int32;
begin
  r := Vec64Popcnt(TMask64(0));
  Check(r = 0, 'Vec64Popcnt(0)=0: got ' + LocalIntToStr(r));
  r := Vec64Popcnt(TMask64(QWord($FFFFFFFFFFFFFFFF)));
  Check(r = 64, 'Vec64Popcnt(all1)=64: got ' + LocalIntToStr(r));
  r := Vec64Popcnt(TMask64(QWord($5555555555555555)));
  Check(r = 32, 'Vec64Popcnt($5555...)=32: got ' + LocalIntToStr(r));
  r := Vec64Popcnt(TMask64(QWord($AAAAAAAAAAAAAAAA)));
  Check(r = 32, 'Vec64Popcnt($AAAA...)=32: got ' + LocalIntToStr(r));
  r := Vec64Popcnt(TMask64($0080));
  Check(r = 1, 'Vec64Popcnt($0080)=1: got ' + LocalIntToStr(r));
end;

procedure TestVec64AddWhere;
var
  data, backup: array[0..63] of Byte;
  i: Integer;
  m: TMask64;
begin
  for i := 0 to 63 do data[i] := i;
  m := TMask64(QWord($FFFFFFFFFFFFFFFF));
  Vec64AddWhere(@data[0], m, 10);
  for i := 0 to 63 do
    Check(data[i] = Byte(i + 10), 'Vec64AddWhere +10 idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));

  FillByte(data[0], 64, 255);
  Vec64AddWhere(@data[0], m, 1);
  for i := 0 to 63 do
    Check(data[i] = 0, 'Vec64AddWhere overflow idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));

  for i := 0 to 63 do data[i] := i;
  Vec64AddWhere(@data[0], TMask64(0), 50);
  for i := 0 to 63 do
    Check(data[i] = i, 'Vec64AddWhere mask=0 idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));

  for i := 0 to 63 do data[i] := i;
  Vec64AddWhere(@data[0], m, 0);
  for i := 0 to 63 do
    Check(data[i] = i, 'Vec64AddWhere delta=0 idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));
end;

procedure TestVec64SubWhere;
var
  data: array[0..63] of Byte;
  i: Integer;
  m: TMask64;
begin
  for i := 0 to 63 do data[i] := i + 20;
  m := TMask64(QWord($FFFFFFFFFFFFFFFF));
  Vec64SubWhere(@data[0], m, 10);
  for i := 0 to 63 do
    Check(data[i] = Byte(i + 10), 'Vec64SubWhere -10 idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));

  FillByte(data[0], 64, 0);
  Vec64SubWhere(@data[0], m, 1);
  for i := 0 to 63 do
    Check(data[i] = 255, 'Vec64SubWhere underflow idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));

  for i := 0 to 63 do data[i] := i;
  Vec64SubWhere(@data[0], TMask64(0), 50);
  for i := 0 to 63 do
    Check(data[i] = i, 'Vec64SubWhere mask=0 idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));

  for i := 0 to 63 do data[i] := i;
  Vec64SubWhere(@data[0], m, 0);
  for i := 0 to 63 do
    Check(data[i] = i, 'Vec64SubWhere delta=0 idx=' + LocalIntToStr(i) + ': got ' + LocalIntToStr(data[i]));
end;

begin
  WriteLn('=== Vec16/32/64 Complete Test Suite ===');
  WriteLn;

  WriteLn('--- Vec16 ---');
  TestVec16CmpEq;
  TestVec16CmpEq2;
  TestVec16CmpLtU;
  TestVec16CmpGtU;
  TestVec16CmpRange;
  TestVec16Ctz;
  TestVec16Popcnt;
  TestVec16AddWhere;
  TestVec16SubWhere;
  WriteLn('  Vec16: OK');
  WriteLn;

  WriteLn('--- Vec32 ---');
  TestVec32CmpEq;
  TestVec32CmpEq2;
  TestVec32CmpLtU;
  TestVec32CmpGtU;
  TestVec32CmpRange;
  TestVec32Ctz;
  TestVec32Popcnt;
  TestVec32AddWhere;
  TestVec32SubWhere;
  WriteLn('  Vec32: OK');
  WriteLn;

  WriteLn('--- Vec64 ---');
  TestVec64CmpEq;
  TestVec64CmpEq2;
  TestVec64CmpLtU;
  TestVec64CmpGtU;
  TestVec64CmpRange;
  TestVec64Ctz;
  TestVec64Popcnt;
  TestVec64AddWhere;
  TestVec64SubWhere;
  WriteLn('  Vec64: OK');
  WriteLn;

  WriteLn('--- ', LocalIntToStr(GTestCount), ' tests, ', LocalIntToStr(GPassCount), ' passed, 0 failed ---');
end.
