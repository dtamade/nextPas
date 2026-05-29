program test_vec_all;
{$mode objfpc}{$H+}
uses
  SysUtils,
  nextpas.core.simd.base,
  nextpas.core.simd.vec16,
  nextpas.core.simd.vec32,
  nextpas.core.simd.vec64;

var
  data16: array[0..15] of Byte;
  data32: array[0..31] of Byte;
  data64: array[0..63] of Byte;
  i: Integer;
  m16: TMask16;
  m32: TMask32;
  m64: TMask64;

procedure Check(cond: Boolean; const msg: string);
begin
  if not cond then begin WriteLn('FAIL: ', msg); Halt(1); end;
end;

begin
  WriteLn('=== Vec16/32/64 Test Suite ===');

  // Setup
  for i := 0 to 15 do data16[i] := i;
  for i := 0 to 31 do data32[i] := i;
  for i := 0 to 63 do data64[i] := i;

  // --- Vec16 ---
  m16 := Vec16CmpEq(@data16[0], 7);
  Check(m16 = $0080, 'Vec16CmpEq(7)=$' + IntToHex(m16, 4));
  m16 := Vec16CmpRange(@data16[0], 3, 7);
  Check(m16 = $00F8, 'Vec16CmpRange(3,7)=$' + IntToHex(m16, 4));
  m16 := Vec16CmpLtU(@data16[0], 5);
  Check(m16 = $001F, 'Vec16CmpLtU(5)=$' + IntToHex(m16, 4));
  Check(Vec16Ctz($0080) = 7, 'Vec16Ctz');
  Check(Vec16Popcnt($F0F0) = 8, 'Vec16Popcnt');
  WriteLn('  Vec16: OK');

  // --- Vec32 ---
  m32 := Vec32CmpEq(@data32[0], 7);
  Check(m32 = $00000080, 'Vec32CmpEq(7)=$' + IntToHex(m32, 8));
  m32 := Vec32CmpEq(@data32[0], 31);
  Check(m32 = $80000000, 'Vec32CmpEq(31)=$' + IntToHex(m32, 8));
  m32 := Vec32CmpRange(@data32[0], 10, 20);
  Check(m32 = $001FFC00, 'Vec32CmpRange(10,20)=$' + IntToHex(m32, 8));
  m32 := Vec32CmpLtU(@data32[0], 5);
  Check(m32 = $0000001F, 'Vec32CmpLtU(5)=$' + IntToHex(m32, 8));
  m32 := Vec32CmpGtU(@data32[0], 28);
  Check(m32 = $E0000000, 'Vec32CmpGtU(28)=$' + IntToHex(m32, 8));
  Check(Vec32Ctz($00000080) = 7, 'Vec32Ctz');
  Check(Vec32Ctz(0) = -1, 'Vec32Ctz(0)');
  Check(Vec32Popcnt($F0F0F0F0) = 16, 'Vec32Popcnt');
  WriteLn('  Vec32: OK');

  // --- Vec64 ---
  m64 := Vec64CmpEq(@data64[0], 7);
  Check(m64 = $0000000000000080, 'Vec64CmpEq(7)');
  m64 := Vec64CmpEq(@data64[0], 63);
  Check(m64 = QWord($8000000000000000), 'Vec64CmpEq(63)');
  m64 := Vec64CmpRange(@data64[0], 60, 63);
  Check(m64 = QWord($F000000000000000), 'Vec64CmpRange(60,63)');
  m64 := Vec64CmpLtU(@data64[0], 3);
  Check(m64 = $0000000000000007, 'Vec64CmpLtU(3)');
  Check(Vec64Ctz(QWord($8000000000000000)) = 63, 'Vec64Ctz(63)');
  Check(Vec64Ctz(0) = -1, 'Vec64Ctz(0)');
  Check(Vec64Popcnt(QWord($FF00FF00FF00FF00)) = 32, 'Vec64Popcnt');
  WriteLn('  Vec64: OK');

  WriteLn;
  WriteLn('ALL PASS');
end.
