unit nextpas.core.simd.api_coverage.support;

{$mode objfpc}{$H+}
{$Q-}{$R-}

interface

uses
  nextpas.core.text.conv,
  Math,
  nextpas.core.simd.base;

procedure StartApiCoverageSuite(const aTitle: string);
procedure Check(aCondition: Boolean; const aMessage: string);
procedure CheckFloat(aActual, aExpected: Single; const aMessage: string; aEpsilon: Single = 1e-5);
procedure CheckDouble(aActual, aExpected: Double; const aMessage: string; aEpsilon: Double = 1e-9);
procedure PrintApiCoverageSummary;

function MakeI16x8(
  a0, a1, a2, a3, a4, a5, a6, a7: Int16
): TVecI16x8;
function MakeI8x16(
  a0, a1, a2, a3, a4, a5, a6, a7,
  a8, a9, a10, a11, a12, a13, a14, a15: Int8
): TVecI8x16;
function MakeU16x8(
  a0, a1, a2, a3, a4, a5, a6, a7: UInt16
): TVecU16x8;
function MakeU32x4(a0, a1, a2, a3: UInt32): TVecU32x4;
function MakeU8x16(
  a0, a1, a2, a3, a4, a5, a6, a7,
  a8, a9, a10, a11, a12, a13, a14, a15: UInt8
): TVecU8x16;

implementation

var
  GPass: Integer;
  GFail: Integer;

procedure ResetApiCoverageState;
begin
  GPass := 0;
  GFail := 0;
end;

procedure StartApiCoverageSuite(const aTitle: string);
begin
  ResetApiCoverageState;
  WriteLn('=== ', aTitle, ' ===');
end;

procedure Check(aCondition: Boolean; const aMessage: string);
begin
  Inc(GPass);
  if not aCondition then
  begin
    Inc(GFail);
    WriteLn('FAIL: ', aMessage);
    Halt(1);
  end;
end;

procedure CheckFloat(aActual, aExpected: Single; const aMessage: string; aEpsilon: Single = 1e-5);
begin
  Check(
    Abs(aActual - aExpected) < aEpsilon,
    aMessage + Format(' (got %g, exp %g)', [aActual, aExpected])
  );
end;

procedure CheckDouble(aActual, aExpected: Double; const aMessage: string; aEpsilon: Double = 1e-9);
begin
  Check(
    Abs(aActual - aExpected) < aEpsilon,
    aMessage + Format(' (got %g, exp %g)', [aActual, aExpected])
  );
end;

procedure PrintApiCoverageSummary;
begin
  WriteLn(Format('--- %d tests passed, %d failed ---', [GPass, GFail]));
  if GFail = 0 then
    WriteLn('ALL PASS');
end;

function MakeI16x8(
  a0, a1, a2, a3, a4, a5, a6, a7: Int16
): TVecI16x8;
begin
  Result.i[0] := a0; Result.i[1] := a1; Result.i[2] := a2; Result.i[3] := a3;
  Result.i[4] := a4; Result.i[5] := a5; Result.i[6] := a6; Result.i[7] := a7;
end;

function MakeI8x16(
  a0, a1, a2, a3, a4, a5, a6, a7,
  a8, a9, a10, a11, a12, a13, a14, a15: Int8
): TVecI8x16;
begin
  Result.i[0] := a0; Result.i[1] := a1; Result.i[2] := a2; Result.i[3] := a3;
  Result.i[4] := a4; Result.i[5] := a5; Result.i[6] := a6; Result.i[7] := a7;
  Result.i[8] := a8; Result.i[9] := a9; Result.i[10] := a10; Result.i[11] := a11;
  Result.i[12] := a12; Result.i[13] := a13; Result.i[14] := a14; Result.i[15] := a15;
end;

function MakeU16x8(
  a0, a1, a2, a3, a4, a5, a6, a7: UInt16
): TVecU16x8;
begin
  Result.u[0] := a0; Result.u[1] := a1; Result.u[2] := a2; Result.u[3] := a3;
  Result.u[4] := a4; Result.u[5] := a5; Result.u[6] := a6; Result.u[7] := a7;
end;

function MakeU32x4(a0, a1, a2, a3: UInt32): TVecU32x4;
begin
  Result.u[0] := a0; Result.u[1] := a1; Result.u[2] := a2; Result.u[3] := a3;
end;

function MakeU8x16(
  a0, a1, a2, a3, a4, a5, a6, a7,
  a8, a9, a10, a11, a12, a13, a14, a15: UInt8
): TVecU8x16;
begin
  Result.u[0] := a0; Result.u[1] := a1; Result.u[2] := a2; Result.u[3] := a3;
  Result.u[4] := a4; Result.u[5] := a5; Result.u[6] := a6; Result.u[7] := a7;
  Result.u[8] := a8; Result.u[9] := a9; Result.u[10] := a10; Result.u[11] := a11;
  Result.u[12] := a12; Result.u[13] := a13; Result.u[14] := a14; Result.u[15] := a15;
end;

end.
