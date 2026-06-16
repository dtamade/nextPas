program test_fft_simd;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

uses
  nextpas.core.text.conv, Math,
  nextpas.core.simd,
  nextpas.core.simd.alloc,
  nextpas.core.simd.mathutil,
  nextpas.core.simd.signal;

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

procedure TestImpulse;
var
  LData: array[0..7] of TSimdComplexF32;
  LI: Integer;
begin
  for LI := 0 to 7 do begin LData[LI].Re := 0; LData[LI].Im := 0; end;
  LData[0].Re := 1;
  FftRadix2F32(@LData[0], 8, sfdForward);
  for LI := 0 to 7 do
  begin
    Check('Impulse_Re[' + IntToStr(LI) + ']', LData[LI].Re, 1.0);
    Check('Impulse_Im[' + IntToStr(LI) + ']', LData[LI].Im, 0.0);
  end;
  FftRadix2F32(@LData[0], 8, sfdInverse);
  Check('IFFT[0]', LData[0].Re, 1.0);
  for LI := 1 to 7 do
    Check('IFFT[' + IntToStr(LI) + ']', LData[LI].Re, 0.0);
end;

procedure TestDC;
var
  LData: array[0..15] of TSimdComplexF32;
  LI: Integer;
begin
  for LI := 0 to 15 do begin LData[LI].Re := 1.0; LData[LI].Im := 0; end;
  FftRadix2F32(@LData[0], 16, sfdForward);
  Check('DC_Re[0]', LData[0].Re, 16.0);
  for LI := 1 to 15 do
  begin
    Check('DC_Re[' + IntToStr(LI) + ']', LData[LI].Re, 0.0);
    Check('DC_Im[' + IntToStr(LI) + ']', LData[LI].Im, 0.0);
  end;
end;

procedure TestParseval;
var
  LData: PSimdComplexF32;
  LN, LI: SizeUInt;
  LTimeEnergy, LFreqEnergy: Double;
begin
  LN := 1024;
  LData := PSimdComplexF32(SimdAlloc(LN * SizeOf(TSimdComplexF32)));
  for LI := 0 to LN - 1 do
  begin
    LData[LI].Re := Sin(2 * Pi * 7 * LI / LN) + 0.5 * Cos(2 * Pi * 23 * LI / LN);
    LData[LI].Im := 0;
  end;

  LTimeEnergy := 0;
  for LI := 0 to LN - 1 do
    LTimeEnergy := LTimeEnergy + LData[LI].Re * LData[LI].Re;

  FftRadix2F32(LData, LN, sfdForward);

  LFreqEnergy := 0;
  for LI := 0 to LN - 1 do
    LFreqEnergy := LFreqEnergy + LData[LI].Re * LData[LI].Re + LData[LI].Im * LData[LI].Im;
  LFreqEnergy := LFreqEnergy / LN;

  Check('Parseval_1024', Single(LFreqEnergy), Single(LTimeEnergy), 1e-3);
  SimdFree(LData);
end;

procedure TestRoundTrip;
var
  LData, LRef: PSimdComplexF32;
  LN, LI: SizeUInt;
begin
  LN := 256;
  LData := PSimdComplexF32(SimdAlloc(LN * SizeOf(TSimdComplexF32)));
  LRef := PSimdComplexF32(SimdAlloc(LN * SizeOf(TSimdComplexF32)));
  for LI := 0 to LN - 1 do
  begin
    LData[LI].Re := (LI mod 13) * 0.1 - 0.6;
    LData[LI].Im := (LI mod 7) * 0.1 - 0.3;
    LRef[LI] := LData[LI];
  end;

  FftRadix2F32(LData, LN, sfdForward);
  FftRadix2F32(LData, LN, sfdInverse);

  for LI := 0 to LN - 1 do
  begin
    Check('RT_Re[' + IntToStr(LI) + ']', LData[LI].Re, LRef[LI].Re, 1e-4);
    Check('RT_Im[' + IntToStr(LI) + ']', LData[LI].Im, LRef[LI].Im, 1e-4);
  end;

  SimdFree(LRef);
  SimdFree(LData);
end;

procedure TestRadix4Impulse;
var
  LData: array[0..15] of TSimdComplexF32;
  LI: Integer;
begin
  for LI := 0 to 15 do begin LData[LI].Re := 0; LData[LI].Im := 0; end;
  LData[0].Re := 1;
  FftF32(@LData[0], 16, sfdForward);
  for LI := 0 to 15 do
  begin
    Check('R4_Impulse_Re[' + IntToStr(LI) + ']', LData[LI].Re, 1.0);
    Check('R4_Impulse_Im[' + IntToStr(LI) + ']', LData[LI].Im, 0.0);
  end;
end;

procedure TestRadix4RoundTrip;
var
  LData, LRef: PSimdComplexF32;
  LN, LI: SizeUInt;
begin
  LN := 256;
  LData := PSimdComplexF32(SimdAlloc(LN * SizeOf(TSimdComplexF32)));
  LRef := PSimdComplexF32(SimdAlloc(LN * SizeOf(TSimdComplexF32)));
  for LI := 0 to LN - 1 do
  begin
    LData[LI].Re := (LI mod 13) * 0.1 - 0.6;
    LData[LI].Im := (LI mod 7) * 0.1 - 0.3;
    LRef[LI] := LData[LI];
  end;

  FftF32(LData, LN, sfdForward);
  FftF32(LData, LN, sfdInverse);

  for LI := 0 to LN - 1 do
  begin
    Check('R4_RT_Re[' + IntToStr(LI) + ']', LData[LI].Re, LRef[LI].Re, 1e-4);
    Check('R4_RT_Im[' + IntToStr(LI) + ']', LData[LI].Im, LRef[LI].Im, 1e-4);
  end;

  SimdFree(LRef);
  SimdFree(LData);
end;

procedure TestRadix4Parseval;
var
  LData: PSimdComplexF32;
  LN, LI: SizeUInt;
  LTimeEnergy, LFreqEnergy: Double;
begin
  LN := 1024;
  LData := PSimdComplexF32(SimdAlloc(LN * SizeOf(TSimdComplexF32)));
  for LI := 0 to LN - 1 do
  begin
    LData[LI].Re := SimdSinF32(SIMD_TWO_PI * 7 * LI / LN) +
                    0.5 * SimdCosF32(SIMD_TWO_PI * 23 * LI / LN);
    LData[LI].Im := 0;
  end;

  LTimeEnergy := 0;
  for LI := 0 to LN - 1 do
    LTimeEnergy := LTimeEnergy + LData[LI].Re * LData[LI].Re;

  FftF32(LData, LN, sfdForward);

  LFreqEnergy := 0;
  for LI := 0 to LN - 1 do
    LFreqEnergy := LFreqEnergy + LData[LI].Re * LData[LI].Re + LData[LI].Im * LData[LI].Im;
  LFreqEnergy := LFreqEnergy / LN;

  Check('R4_Parseval_1024', Single(LFreqEnergy), Single(LTimeEnergy), 1e-3);
  SimdFree(LData);
end;

procedure TestPlanRoundTrip;
var
  LData, LRef: PSimdComplexF32;
  LPlan: TSimdFftPlanF32;
  LN, LI: SizeUInt;
begin
  LN := 256;
  LData := PSimdComplexF32(SimdAlloc(LN * SizeOf(TSimdComplexF32)));
  LRef := PSimdComplexF32(SimdAlloc(LN * SizeOf(TSimdComplexF32)));
  for LI := 0 to LN - 1 do
  begin
    LData[LI].Re := (LI mod 13) * 0.1 - 0.6;
    LData[LI].Im := (LI mod 7) * 0.1 - 0.3;
    LRef[LI] := LData[LI];
  end;

  LPlan := TSimdFftPlanF32.Create(LN);
  LPlan.Execute(LData, sfdForward);
  LPlan.Execute(LData, sfdInverse);

  for LI := 0 to LN - 1 do
  begin
    Check('Plan_RT_Re[' + IntToStr(LI) + ']', LData[LI].Re, LRef[LI].Re, 1e-4);
    Check('Plan_RT_Im[' + IntToStr(LI) + ']', LData[LI].Im, LRef[LI].Im, 1e-4);
  end;

  LPlan.Free;
  SimdFree(LRef);
  SimdFree(LData);
end;

begin
  GPass := 0;
  GFail := 0;

  WriteLn('=== FFT Radix-2 Tests ===');
  TestImpulse;
  TestDC;
  TestParseval;
  TestRoundTrip;

  WriteLn('=== FFT Radix-4 Tests ===');
  TestRadix4Impulse;
  TestRadix4RoundTrip;
  TestRadix4Parseval;

  WriteLn('=== FFT Plan Tests ===');
  TestPlanRoundTrip;

  WriteLn;
  WriteLn('Results: ', GPass, ' passed, ', GFail, ' failed');
  if GFail > 0 then Halt(1);
end.
