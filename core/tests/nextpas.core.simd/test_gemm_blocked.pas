program test_gemm_blocked;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

uses
  SysUtils,
  nextpas.core.simd,
  nextpas.core.simd.alloc,
  nextpas.core.simd.arrays.typed,
  nextpas.core.simd.linalg,
  nextpas.core.simd.linalg.gemm;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; AGot, AExpect: Single; ATol: Single = 1e-4);
var
  LDiff, LScale: Single;
begin
  LDiff := System.Abs(AGot - AExpect);
  LScale := System.Abs(AExpect);
  if LScale < 1.0 then LScale := 1.0;
  if LDiff <= ATol * LScale then
    Inc(GPass)
  else
  begin
    WriteLn('  FAIL ', AName, ': got=', AGot:0:6, ' expect=', AExpect:0:6);
    Inc(GFail);
  end;
end;

procedure NaiveGemm(AA, AB, AC: PSingle; AM, AN, AK: SizeUInt);
var
  LI, LJ, LP: SizeUInt;
  LSum: Single;
begin
  for LI := 0 to AM - 1 do
    for LJ := 0 to AN - 1 do
    begin
      LSum := 0;
      for LP := 0 to AK - 1 do
        LSum := LSum + AA[LI * AK + LP] * AB[LP * AN + LJ];
      AC[LI * AN + LJ] := LSum;
    end;
end;

procedure NaiveGemmTransB(AA, AB, AC: PSingle; AM, AN, AK: SizeUInt);
var
  LI, LJ, LP: SizeUInt;
  LSum: Single;
begin
  for LI := 0 to AM - 1 do
    for LJ := 0 to AN - 1 do
    begin
      LSum := 0;
      for LP := 0 to AK - 1 do
        LSum := LSum + AA[LI * AK + LP] * AB[LJ * AK + LP];
      AC[LI * AN + LJ] := LSum;
    end;
end;

procedure TestSize(AM, AN, AK: SizeUInt; const ALabel: string);
var
  LA, LB, LC, LRef: PSingle;
  LI: SizeUInt;
  LTotal: SizeUInt;
begin
  LA := PSingle(SimdAlloc(AM * AK * SizeOf(Single)));
  LB := PSingle(SimdAlloc(AK * AN * SizeOf(Single)));
  LC := PSingle(SimdAlloc(AM * AN * SizeOf(Single)));
  LRef := PSingle(SimdAlloc(AM * AN * SizeOf(Single)));

  for LI := 0 to AM * AK - 1 do
    LA[LI] := (LI mod 7) * 0.1 - 0.3;
  for LI := 0 to AK * AN - 1 do
    LB[LI] := (LI mod 11) * 0.1 - 0.5;

  NaiveGemm(LA, LB, LRef, AM, AN, AK);

  FillChar(LC^, AM * AN * SizeOf(Single), 0);
  GemmBlockedF32(LA, LB, LC, AM, AN, AK, AK, AN, AN);

  LTotal := AM * AN;
  for LI := 0 to LTotal - 1 do
    Check(ALabel + '[' + IntToStr(LI) + ']', LC[LI], LRef[LI]);

  SimdFree(LRef);
  SimdFree(LC);
  SimdFree(LB);
  SimdFree(LA);
end;

procedure TestTransBSize(AM, AN, AK: SizeUInt; const ALabel: string);
var
  LA, LB, LC, LRef: PSingle;
  LI: SizeUInt;
  LTotal: SizeUInt;
begin
  LA := PSingle(SimdAlloc(AM * AK * SizeOf(Single)));
  LB := PSingle(SimdAlloc(AN * AK * SizeOf(Single)));
  LC := PSingle(SimdAlloc(AM * AN * SizeOf(Single)));
  LRef := PSingle(SimdAlloc(AM * AN * SizeOf(Single)));

  for LI := 0 to AM * AK - 1 do
    LA[LI] := (LI mod 7) * 0.1 - 0.3;
  for LI := 0 to AN * AK - 1 do
    LB[LI] := (LI mod 11) * 0.1 - 0.5;

  NaiveGemmTransB(LA, LB, LRef, AM, AN, AK);

  FillChar(LC^, AM * AN * SizeOf(Single), 0);
  GemmBlockedTransBF32(LA, LB, LC, AM, AN, AK, AK, AK, AN);

  LTotal := AM * AN;
  for LI := 0 to LTotal - 1 do
    Check(ALabel + '[' + IntToStr(LI) + ']', LC[LI], LRef[LI]);

  SimdFree(LRef);
  SimdFree(LC);
  SimdFree(LB);
  SimdFree(LA);
end;

procedure TestGemmF32ViaMatrix;
var
  LA, LB, LC: TSimdF32Matrix;
  LRef: PSingle;
  LI: SizeUInt;
begin
  LA := TSimdF32Matrix.Create(24, 64);
  LB := TSimdF32Matrix.Create(64, 32);
  for LI := 0 to 24 * 64 - 1 do
    LA.Data[LI] := (LI mod 13) * 0.1 - 0.6;
  for LI := 0 to 64 * 32 - 1 do
    LB.Data[LI] := (LI mod 9) * 0.1 - 0.4;

  LC := TSimdF32Matrix.Zeros(24, 32);
  GemmF32(1.0, LA, LB, 0.0, LC);

  LRef := PSingle(SimdAlloc(24 * 32 * SizeOf(Single)));
  NaiveGemm(LA.Data, LB.Data, LRef, 24, 32, 64);

  for LI := 0 to 24 * 32 - 1 do
    Check('MatrixGemm[' + IntToStr(LI) + ']', LC.Data[LI], LRef[LI]);

  SimdFree(LRef);
  LC.Free;
  LB.Free;
  LA.Free;
end;

var
  LI: SizeUInt;
begin
  GPass := 0;
  GFail := 0;

  WriteLn('=== GemmBlockedF32 Tests ===');
  TestSize(6, 16, 8, 'Exact_6x16x8');
  TestSize(12, 32, 16, 'Exact_12x32x16');
  TestSize(7, 17, 9, 'Remainder_7x17x9');
  TestSize(24, 48, 64, 'Medium_24x48x64');
  TestSize(72, 96, 256, 'Large_72x96x256');
  TestSize(100, 100, 100, 'Square_100');
  TestSize(1, 1, 1, 'Tiny_1x1x1');
  TestSize(5, 15, 4, 'Small_5x15x4');

  WriteLn('=== GemmBlockedTransBF32 Tests ===');
  TestTransBSize(6, 16, 8, 'TransB_6x16x8');
  TestTransBSize(12, 32, 16, 'TransB_12x32x16');
  TestTransBSize(7, 17, 9, 'TransB_7x17x9');
  TestTransBSize(24, 48, 64, 'TransB_24x48x64');
  TestTransBSize(100, 100, 100, 'TransB_100');

  WriteLn('=== GemmF32 Matrix API ===');
  TestGemmF32ViaMatrix;

  WriteLn;
  WriteLn('Results: ', GPass, ' passed, ', GFail, ' failed');
  if GFail > 0 then
    Halt(1);
end.
