program nextpas.core.simd.transcendental_f32;

{$mode objfpc}{$H+}
{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils, Math,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch;

const
  MAX_COUNT = 65;
  REL_TOL = 1e-5;
  LOG_REL_TOL = 1e-5;  // SIMD log now uses atanh transform (~23-bit precision)
  POW_REL_TOL = 1e-5;  // Pow = Exp(y*Log(x)), improved with atanh Log

var
  g_TotalChecks: Integer = 0;
  g_Failures: Integer = 0;

procedure Fail(const aMsg: string);
begin
  WriteLn('[FAIL] ', aMsg);
  Inc(g_Failures);
end;

procedure CheckNearRelative(const aCtx: string; aExpected, aActual: Single; aRelTol: Single);
var
  LScale: Single;
begin
  Inc(g_TotalChecks);
  LScale := Max(Abs(aExpected), 1e-7);
  if Abs(aExpected - aActual) > aRelTol * LScale then
    Fail(Format('%s: expected %.8g got %.8g (diff=%.8g)',
      [aCtx, aExpected, aActual, aActual - aExpected]));
end;

procedure CheckExact(const aCtx: string; aExpected, aActual: Single);
begin
  Inc(g_TotalChecks);
  if IsNan(aExpected) then
  begin
    if not IsNan(aActual) then
      Fail(Format('%s: expected NaN got %.8g', [aCtx, aActual]));
  end
  else if IsInfinite(aExpected) then
  begin
    if aActual <> aExpected then
      Fail(Format('%s: expected %.8g got %.8g', [aCtx, aExpected, aActual]));
  end
  else
    CheckNearRelative(aCtx, aExpected, aActual, REL_TOL);
end;

procedure TestArrayExpF32;
var
  LSrc, LDst: array[0..MAX_COUNT-1] of Single;
  LCounts: array[0..7] of SizeUInt = (0, 1, 4, 7, 8, 16, 32, 65);
  ci, i: Integer;
  LCount: SizeUInt;
  LExpected: Single;
begin
  for i := 0 to MAX_COUNT - 1 do
    LSrc[i] := (i - 32) * 0.1;

  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];
    FillChar(LDst, SizeOf(LDst), 0);
    ArrayExpF32(@LSrc[0], @LDst[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
    begin
      LExpected := Single(System.Exp(LSrc[i]));
      CheckNearRelative(Format('Exp[count=%d,i=%d,x=%.3g]', [LCount, i, Double(LSrc[i])]),
        LExpected, LDst[i], REL_TOL);
    end;
  end;
  WriteLn('  ArrayExpF32: checked');
end;

procedure TestArrayLogF32;
var
  LSrc, LDst: array[0..MAX_COUNT-1] of Single;
  LCounts: array[0..7] of SizeUInt = (0, 1, 4, 7, 8, 16, 32, 65);
  ci, i: Integer;
  LCount: SizeUInt;
  LExpected: Single;
begin
  for i := 0 to MAX_COUNT - 1 do
    LSrc[i] := 0.01 + i * 1.5;

  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];
    FillChar(LDst, SizeOf(LDst), 0);
    ArrayLogF32(@LSrc[0], @LDst[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
    begin
      LExpected := Single(System.Ln(LSrc[i]));
      CheckNearRelative(Format('Log[count=%d,i=%d,x=%.3g]', [LCount, i, Double(LSrc[i])]),
        LExpected, LDst[i], LOG_REL_TOL);
    end;
  end;
  WriteLn('  ArrayLogF32: checked');
end;

procedure TestArrayPowF32;
var
  LSrc, LDst: array[0..MAX_COUNT-1] of Single;
  LCounts: array[0..5] of SizeUInt = (1, 4, 8, 16, 32, 65);
  LExponents: array[0..3] of Single = (0.5, 2.0, 3.0, -1.0);
  ci, ei, i: Integer;
  LCount: SizeUInt;
  LExpected: Single;
begin
  for i := 0 to MAX_COUNT - 1 do
    LSrc[i] := 0.1 + i * 0.5;

  for ci := 0 to High(LCounts) do
    for ei := 0 to High(LExponents) do
    begin
      LCount := LCounts[ci];
      FillChar(LDst, SizeOf(LDst), 0);
      ArrayPowF32(@LSrc[0], @LDst[0], LCount, LExponents[ei]);
      for i := 0 to Integer(LCount) - 1 do
      begin
        LExpected := Single(Math.Power(LSrc[i], LExponents[ei]));
        CheckNearRelative(Format('Pow[count=%d,exp=%.2g,i=%d]',
          [LCount, Double(LExponents[ei]), i]),
          LExpected, LDst[i], POW_REL_TOL);
      end;
    end;
  WriteLn('  ArrayPowF32: checked');
end;

procedure TestArraySinCosF32;
var
  LSrc, LDstSin, LDstCos: array[0..MAX_COUNT-1] of Single;
  LCounts: array[0..7] of SizeUInt = (0, 1, 4, 7, 8, 16, 32, 65);
  ci, i: Integer;
  LCount: SizeUInt;
  LExpSin, LExpCos: Single;
begin
  for i := 0 to MAX_COUNT - 1 do
    LSrc[i] := (i - 32) * 0.2;

  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];
    FillChar(LDstSin, SizeOf(LDstSin), 0);
    FillChar(LDstCos, SizeOf(LDstCos), 0);
    ArraySinF32(@LSrc[0], @LDstSin[0], LCount);
    ArrayCosF32(@LSrc[0], @LDstCos[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
    begin
      LExpSin := Single(System.Sin(LSrc[i]));
      LExpCos := Single(System.Cos(LSrc[i]));
      CheckNearRelative(Format('Sin[count=%d,i=%d]', [LCount, i]),
        LExpSin, LDstSin[i], REL_TOL);
      CheckNearRelative(Format('Cos[count=%d,i=%d]', [LCount, i]),
        LExpCos, LDstCos[i], REL_TOL);
    end;
  end;
  WriteLn('  ArraySin/CosF32: checked');
end;

procedure TestEdgeCases;
var
  LSrc, LDst: array[0..7] of Single;
  LExpected: Single;
begin
  LSrc[0] := 0.0;
  LSrc[1] := 1.0;
  LSrc[2] := -1.0;
  LSrc[3] := 88.0;
  LSrc[4] := -88.0;

  ArrayExpF32(@LSrc[0], @LDst[0], 5);
  CheckExact('Exp(0)=1', 1.0, LDst[0]);
  CheckNearRelative('Exp(1)=e', Single(System.Exp(1.0)), LDst[1], REL_TOL);
  CheckNearRelative('Exp(-1)=1/e', Single(System.Exp(-1.0)), LDst[2], REL_TOL);

  LSrc[0] := 1.0;
  LSrc[1] := Single(System.Exp(1.0));
  LSrc[2] := 10.0;
  ArrayLogF32(@LSrc[0], @LDst[0], 3);
  CheckExact('Log(1)=0', 0.0, LDst[0]);
  CheckNearRelative('Log(e)=1', 1.0, LDst[1], LOG_REL_TOL);
  CheckNearRelative('Log(10)', Single(System.Ln(10.0)), LDst[2], LOG_REL_TOL);

  LSrc[0] := 0.0;
  LSrc[1] := Single(Pi / 2);
  LSrc[2] := Single(Pi);
  ArraySinF32(@LSrc[0], @LDst[0], 3);
  CheckNearRelative('Sin(0)=0', 0.0, LDst[0], REL_TOL);
  CheckNearRelative('Sin(pi/2)=1', 1.0, LDst[1], REL_TOL);
  CheckNearRelative('Sin(pi)~0', Single(System.Sin(Single(Pi))), LDst[2], REL_TOL);

  ArrayCosF32(@LSrc[0], @LDst[0], 3);
  CheckNearRelative('Cos(0)=1', 1.0, LDst[0], REL_TOL);
  CheckNearRelative('Cos(pi/2)~0', Single(System.Cos(Single(Pi/2))), LDst[1], REL_TOL);
  CheckNearRelative('Cos(pi)=-1', -1.0, LDst[2], REL_TOL);

  WriteLn('  EdgeCases: checked');
end;

begin
  WriteLn('[Transcendental F32 Correctness]');
  WriteLn('Backend: ', GetBackendInfo(GetActiveBackend).Name);
  WriteLn('');

  TestArrayExpF32;
  TestArrayLogF32;
  TestArrayPowF32;
  TestArraySinCosF32;
  TestEdgeCases;

  WriteLn('');
  WriteLn(Format('[SUMMARY] checks=%d failures=%d', [g_TotalChecks, g_Failures]));
  if g_Failures > 0 then
  begin
    WriteLn('[RESULT] FAIL');
    Halt(1);
  end;
  WriteLn('[RESULT] PASS');
end.
