program fafafa_core_simd_array_f32_ieee754;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  nextpas.core.text.conv, Math,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.scalar,
  nextpas.core.simd.dispatch;

const
  N = 9;

var
  g_TotalChecks: Integer = 0;
  g_Failures: Integer = 0;

procedure Fail(const aMsg: string);
begin
  WriteLn('[FAIL] ', aMsg);
  Inc(g_Failures);
end;

procedure CheckBitsEqual(const aCtx: string; aExpected, aActual: Single);
var
  eBits, aBits: LongWord;
begin
  Inc(g_TotalChecks);
  eBits := PLongWord(@aExpected)^;
  aBits := PLongWord(@aActual)^;
  if eBits <> aBits then
    Fail(Format('%s: expected bits=$%08X got bits=$%08X', [aCtx, eBits, aBits]));
end;

procedure CheckIsNaN(const aCtx: string; aValue: Single);
begin
  Inc(g_TotalChecks);
  if not IsNan(aValue) then
    Fail(Format('%s: expected NaN got %.8g (bits=$%08X)',
      [aCtx, aValue, PLongWord(@aValue)^]));
end;

procedure CheckIsInf(const aCtx: string; aValue: Single; aPositive: Boolean);
begin
  Inc(g_TotalChecks);
  if not IsInfinite(aValue) then
    Fail(Format('%s: expected Inf got %.8g', [aCtx, aValue]))
  else if aPositive and (aValue < 0) then
    Fail(Format('%s: expected +Inf got -Inf', [aCtx]))
  else if (not aPositive) and (aValue > 0) then
    Fail(Format('%s: expected -Inf got +Inf', [aCtx]));
end;

// PLACEHOLDER_MORE_TESTS

var
  PosInf, NegInf, QNaN, NegZero: Single;
  Denormal: Single;

procedure InitSpecialValues;
var
  bits: LongWord;
begin
  bits := $7F800000; PosInf := PSingle(@bits)^;
  bits := $FF800000; NegInf := PSingle(@bits)^;
  bits := $7FC00001; QNaN := PSingle(@bits)^;
  bits := $80000000; NegZero := PSingle(@bits)^;
  bits := $00000001; Denormal := PSingle(@bits)^;
end;

procedure TestNaNPropagation;
var
  LSrc1, LSrc2, LDst: array[0..N-1] of Single;
  LDispatch: PSimdDispatchTable;
  i: Integer;
begin
  LDispatch := GetDispatchTable;
  for i := 0 to N-1 do begin LSrc1[i] := QNaN; LSrc2[i] := 1.0 + i; end;

  LDispatch^.ArrayAddF32(@LSrc1[0], @LSrc2[0], @LDst[0], N);
  for i := 0 to N-1 do
    CheckIsNaN(Format('Add(NaN,x)[%d]', [i]), LDst[i]);

  LDispatch^.ArraySubF32(@LSrc1[0], @LSrc2[0], @LDst[0], N);
  for i := 0 to N-1 do
    CheckIsNaN(Format('Sub(NaN,x)[%d]', [i]), LDst[i]);

  LDispatch^.ArrayMulF32(@LSrc1[0], @LSrc2[0], @LDst[0], N);
  for i := 0 to N-1 do
    CheckIsNaN(Format('Mul(NaN,x)[%d]', [i]), LDst[i]);

  LDispatch^.ArrayDivF32(@LSrc1[0], @LSrc2[0], @LDst[0], N);
  for i := 0 to N-1 do
    CheckIsNaN(Format('Div(NaN,x)[%d]', [i]), LDst[i]);

  LDispatch^.ArraySqrtF32(@LSrc1[0], @LDst[0], N);
  for i := 0 to N-1 do
    CheckIsNaN(Format('Sqrt(NaN)[%d]', [i]), LDst[i]);

  WriteLn('  NaN propagation: checked');
end;

procedure TestInfArithmetic;
var
  LSrc1, LSrc2, LDst: array[0..N-1] of Single;
  LDispatch: PSimdDispatchTable;
  i: Integer;
begin
  LDispatch := GetDispatchTable;
  for i := 0 to N-1 do begin LSrc1[i] := PosInf; LSrc2[i] := 2.0; end;

  LDispatch^.ArrayAddF32(@LSrc1[0], @LSrc2[0], @LDst[0], N);
  for i := 0 to N-1 do
    CheckIsInf('Add(+Inf,2)', LDst[i], True);

  LDispatch^.ArrayMulF32(@LSrc1[0], @LSrc2[0], @LDst[0], N);
  for i := 0 to N-1 do
    CheckIsInf('Mul(+Inf,2)', LDst[i], True);

  for i := 0 to N-1 do LSrc2[i] := -3.0;
  LDispatch^.ArrayMulF32(@LSrc1[0], @LSrc2[0], @LDst[0], N);
  for i := 0 to N-1 do
    CheckIsInf('Mul(+Inf,-3)', LDst[i], False);

  LDispatch^.ArraySqrtF32(@LSrc1[0], @LDst[0], N);
  for i := 0 to N-1 do
    CheckIsInf('Sqrt(+Inf)', LDst[i], True);

  WriteLn('  Inf arithmetic: checked');
end;

procedure TestNegativeZero;
var
  LSrc, LDst: array[0..N-1] of Single;
  LDispatch: PSimdDispatchTable;
  i: Integer;
  bits: LongWord;
begin
  LDispatch := GetDispatchTable;
  for i := 0 to N-1 do LSrc[i] := NegZero;

  LDispatch^.ArrayAbsF32(@LSrc[0], @LDst[0], N);
  for i := 0 to N-1 do
  begin
    bits := PLongWord(@LDst[i])^;
    Inc(g_TotalChecks);
    if bits <> $00000000 then
      Fail(Format('Abs(-0)[%d]: expected +0 (bits=$00000000) got bits=$%08X', [i, bits]));
  end;

  LDispatch^.ArrayNegF32(@LSrc[0], @LDst[0], N);
  for i := 0 to N-1 do
  begin
    bits := PLongWord(@LDst[i])^;
    Inc(g_TotalChecks);
    if bits <> $00000000 then
      Fail(Format('Neg(-0)[%d]: expected +0 (bits=$00000000) got bits=$%08X', [i, bits]));
  end;

  for i := 0 to N-1 do LSrc[i] := 0.0;
  LDispatch^.ArrayNegF32(@LSrc[0], @LDst[0], N);
  for i := 0 to N-1 do
  begin
    bits := PLongWord(@LDst[i])^;
    Inc(g_TotalChecks);
    if bits <> $80000000 then
      Fail(Format('Neg(+0)[%d]: expected -0 (bits=$80000000) got bits=$%08X', [i, bits]));
  end;

  WriteLn('  Negative zero: checked');
end;

procedure TestDenormals;
var
  LSrc1, LSrc2, LDst: array[0..N-1] of Single;
  LDstScalar: array[0..N-1] of Single;
  LDispatch: PSimdDispatchTable;
  i: Integer;
begin
  LDispatch := GetDispatchTable;
  for i := 0 to N-1 do begin LSrc1[i] := Denormal; LSrc2[i] := 2.0; end;

  ScalarArrayMulF32(@LSrc1[0], @LSrc2[0], @LDstScalar[0], N);
  LDispatch^.ArrayMulF32(@LSrc1[0], @LSrc2[0], @LDst[0], N);
  for i := 0 to N-1 do
    CheckBitsEqual(Format('Mul(denormal,2)[%d]', [i]), LDstScalar[i], LDst[i]);

  ScalarArrayAddF32(@LSrc1[0], @LSrc1[0], @LDstScalar[0], N);
  LDispatch^.ArrayAddF32(@LSrc1[0], @LSrc1[0], @LDst[0], N);
  for i := 0 to N-1 do
    CheckBitsEqual(Format('Add(denormal,denormal)[%d]', [i]), LDstScalar[i], LDst[i]);

  WriteLn('  Denormals: checked');
end;

procedure TestReduceWithSpecials;
var
  LSrc: array[0..N-1] of Single;
  LDispatch: PSimdDispatchTable;
  LResult: Single;
  i: Integer;
begin
  LDispatch := GetDispatchTable;

  for i := 0 to N-1 do LSrc[i] := 1.0;
  LSrc[3] := QNaN;
  LResult := LDispatch^.ReduceSumF32(@LSrc[0], N);
  CheckIsNaN('ReduceSum with NaN', LResult);

  for i := 0 to N-1 do LSrc[i] := i * 1.0;
  LSrc[5] := NegInf;
  LResult := LDispatch^.ReduceMinF32(@LSrc[0], N);
  CheckIsInf('ReduceMin with -Inf', LResult, False);

  for i := 0 to N-1 do LSrc[i] := i * 1.0;
  LSrc[5] := PosInf;
  LResult := LDispatch^.ReduceMaxF32(@LSrc[0], N);
  CheckIsInf('ReduceMax with +Inf', LResult, True);

  WriteLn('  Reduce with specials: checked');
end;

procedure RunAllIEEETests;
begin
  TestNaNPropagation;
  TestInfArithmetic;
  TestNegativeZero;
  TestDenormals;
  TestReduceWithSpecials;
end;

begin
  InitSpecialValues;
  WriteLn('[ArrayF32 IEEE 754 Edge Cases]');
  WriteLn('');

  WriteLn('=== Pass 1: Default backend (', GetBackendInfo(GetActiveBackend).Name, ') ===');
  RunAllIEEETests;

  if TrySetActiveBackend(sbSSE2) then
  begin
    WriteLn('');
    WriteLn('=== Pass 2: Forced SSE2 ===');
    RunAllIEEETests;
  end;

  ResetToAutomaticBackend;

  WriteLn('');
  WriteLn(Format('[SUMMARY] checks=%d failures=%d', [g_TotalChecks, g_Failures]));
  if g_Failures > 0 then
  begin
    WriteLn('[RESULT] FAIL');
    Halt(1);
  end;
  WriteLn('[RESULT] PASS');
end.
