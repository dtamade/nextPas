program nextpas.core.simd.nr_refine;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  nextpas.core.text.conv, Math,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch;

const
  N = 1024;
  APPROX_TOL = 2e-3;
  REFINE_TOL = 1e-6;

var
  g_TotalChecks: Integer = 0;
  g_Failures: Integer = 0;
  g_MaxRelErrApprox: Double = 0;
  g_MaxRelErrRefine: Double = 0;

procedure Fail(const aMsg: string);
begin
  WriteLn('[FAIL] ', aMsg);
  Inc(g_Failures);
end;

procedure TestRcpRefine;
var
  LSrc, LApprox, LRefine: array[0..N-1] of Single;
  i: Integer;
  LExact, LRelErr: Double;
begin
  for i := 0 to N - 1 do
    LSrc[i] := 0.1 + i * 0.1;

  ArrayRcpF32(@LSrc[0], @LApprox[0], N);
  ArrayRcpRefineF32(@LSrc[0], @LRefine[0], N);

  g_MaxRelErrApprox := 0;
  g_MaxRelErrRefine := 0;

  for i := 0 to N - 1 do
  begin
    Inc(g_TotalChecks);
    LExact := 1.0 / LSrc[i];

    LRelErr := Abs(Double(LApprox[i]) - LExact) / Abs(LExact);
    if LRelErr > g_MaxRelErrApprox then
      g_MaxRelErrApprox := LRelErr;

    LRelErr := Abs(Double(LRefine[i]) - LExact) / Abs(LExact);
    if LRelErr > g_MaxRelErrRefine then
      g_MaxRelErrRefine := LRelErr;

    if LRelErr > REFINE_TOL then
      Fail(Format('RcpRefine[%d]: x=%.4g exact=%.8g got=%.8g relErr=%.2e',
        [i, Double(LSrc[i]), LExact, Double(LRefine[i]), LRelErr]));
  end;

  WriteLn(Format('  Rcp approx max rel err: %.2e (~%d bits)',
    [g_MaxRelErrApprox, Round(-Log2(g_MaxRelErrApprox))]));
  WriteLn(Format('  Rcp refine max rel err: %.2e (~%d bits)',
    [g_MaxRelErrRefine, Round(-Log2(g_MaxRelErrRefine))]));
end;

procedure TestRsqrtRefine;
var
  LSrc, LApprox, LRefine: array[0..N-1] of Single;
  i: Integer;
  LExact, LRelErr: Double;
begin
  for i := 0 to N - 1 do
    LSrc[i] := 0.1 + i * 0.5;

  ArrayRsqrtF32(@LSrc[0], @LApprox[0], N);
  ArrayRsqrtRefineF32(@LSrc[0], @LRefine[0], N);

  g_MaxRelErrApprox := 0;
  g_MaxRelErrRefine := 0;

  for i := 0 to N - 1 do
  begin
    Inc(g_TotalChecks);
    LExact := 1.0 / Sqrt(LSrc[i]);

    LRelErr := Abs(Double(LApprox[i]) - LExact) / Abs(LExact);
    if LRelErr > g_MaxRelErrApprox then
      g_MaxRelErrApprox := LRelErr;

    LRelErr := Abs(Double(LRefine[i]) - LExact) / Abs(LExact);
    if LRelErr > g_MaxRelErrRefine then
      g_MaxRelErrRefine := LRelErr;

    if LRelErr > REFINE_TOL then
      Fail(Format('RsqrtRefine[%d]: x=%.4g exact=%.8g got=%.8g relErr=%.2e',
        [i, Double(LSrc[i]), LExact, Double(LRefine[i]), LRelErr]));
  end;

  WriteLn(Format('  Rsqrt approx max rel err: %.2e (~%d bits)',
    [g_MaxRelErrApprox, Round(-Log2(g_MaxRelErrApprox))]));
  WriteLn(Format('  Rsqrt refine max rel err: %.2e (~%d bits)',
    [g_MaxRelErrRefine, Round(-Log2(g_MaxRelErrRefine))]));
end;

begin
  WriteLn('[Newton-Raphson Refinement Precision Test]');
  WriteLn('Backend: ', GetBackendInfo(GetActiveBackend).Name);
  WriteLn('');

  TestRcpRefine;
  WriteLn('');
  TestRsqrtRefine;

  WriteLn('');
  WriteLn(Format('[SUMMARY] checks=%d failures=%d', [g_TotalChecks, g_Failures]));
  if g_Failures > 0 then
  begin
    WriteLn('[RESULT] FAIL');
    Halt(1);
  end;
  WriteLn('[RESULT] PASS');
end.
