program test_vec_unified;
{$mode objfpc}{$H+}
{$Q-}{$R-}
uses
  SysUtils,
  nextpas.core.simd.base,
  nextpas.core.simd.vec;

var
  data: array[0..63] of Byte;
  i: Integer;
  mask: TVecMask;
  GPass, GFail: Integer;

procedure Check(cond: Boolean; const msg: string);
begin
  Inc(GPass);
  if not cond then begin WriteLn('FAIL: ', msg); Inc(GFail); Halt(1); end;
end;

begin
  GPass := 0; GFail := 0;
  WriteLn('=== Vec Unified Test (VecWidth=', VecWidth, ') ===');

  for i := 0 to 63 do data[i] := Byte(i);

  // CmpEq
  mask := VecCmpEq(@data[0], 7);
  Check(VecCtz(mask) = 7, 'CmpEq(7) first set = 7');
  Check(VecFirstSet(mask) = 7, 'FirstSet(7) = 7');

  // CmpEq no match
  mask := VecCmpEq(@data[0], 200);
  Check(mask = 0, 'CmpEq(200) = 0 (no match in 0..VecWidth-1)');

  // CmpLtU
  mask := VecCmpLtU(@data[0], 5);
  Check(VecPopcnt(mask) = 5, 'CmpLtU(5) popcount = 5');

  // CmpGtU
  mask := VecCmpGtU(@data[0], VecWidth - 4);
  Check(VecPopcnt(mask) = 3, 'CmpGtU(VecWidth-4) popcount = 3');

  // CmpRange
  mask := VecCmpRange(@data[0], 3, 7);
  Check(VecPopcnt(mask) = 5, 'CmpRange(3,7) popcount = 5');
  Check(VecCtz(mask) = 3, 'CmpRange(3,7) first = 3');

  // CmpEq2
  mask := VecCmpEq2(@data[0], @data[0]);
  Check(mask = TVecMask(not TVecMask(0)), 'CmpEq2(self) = all ones');

  // Ctz edge cases
  Check(VecCtz(TVecMask(0)) = -1, 'Ctz(0) = -1');
  Check(VecCtz(TVecMask(1)) = 0, 'Ctz(1) = 0');

  // Popcnt
  Check(VecPopcnt(TVecMask(0)) = 0, 'Popcnt(0) = 0');

  WriteLn(Format('--- %d tests passed, %d failed ---', [GPass, GFail]));
  if GFail = 0 then WriteLn('ALL PASS');
end.
