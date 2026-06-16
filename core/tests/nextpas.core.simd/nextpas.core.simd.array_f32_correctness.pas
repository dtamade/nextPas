program nextpas.core.simd.array_f32_correctness;

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
  MAX_COUNT = 65;
  TOLERANCE = 1e-5;

var
  g_TotalChecks: Integer = 0;
  g_Failures: Integer = 0;

procedure Fail(const aMsg: string);
begin
  WriteLn('[FAIL] ', aMsg);
  Inc(g_Failures);
end;

procedure CheckNear(const aCtx: string; aExpected, aActual: Single);
begin
  Inc(g_TotalChecks);
  if Abs(aExpected - aActual) > TOLERANCE then
    Fail(Format('%s: expected %.8g got %.8g (diff=%.8g)',
      [aCtx, aExpected, aActual, aActual - aExpected]));
end;

procedure CheckNearRelative(const aCtx: string; aExpected, aActual: Single; aRelTol: Single);
var
  LScale: Single;
begin
  Inc(g_TotalChecks);
  LScale := Max(Abs(aExpected), 1.0);
  if Abs(aExpected - aActual) > aRelTol * LScale then
    Fail(Format('%s: expected %.8g got %.8g (diff=%.8g, rel=%.8g)',
      [aCtx, aExpected, aActual, aActual - aExpected,
       Abs(aActual - aExpected) / LScale]));
end;

procedure FillTestData(aBuf: PSingle; aCount: SizeUInt);
var
  i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
    aBuf[i] := Sin(i * 0.7) * 100.0 - 50.0;
end;

procedure TestArrayAddF32;
var
  LSrc1, LSrc2, LDstScalar, LDstDispatch: array[0..MAX_COUNT-1] of Single;
  LCount: SizeUInt;
  LCounts: array[0..17] of SizeUInt = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 13, 15, 16, 17, 31, 32, 33, 65);
  ci, i: Integer;
begin
  FillTestData(@LSrc1[0], MAX_COUNT);
  FillTestData(@LSrc2[0], MAX_COUNT);
  for i := 0 to MAX_COUNT - 1 do
    LSrc2[i] := LSrc2[i] * (-0.3) + 7.5;

  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];
    FillChar(LDstScalar, SizeOf(LDstScalar), 0);
    FillChar(LDstDispatch, SizeOf(LDstDispatch), 0);

    ScalarArrayAddF32(@LSrc1[0], @LSrc2[0], @LDstScalar[0], LCount);
    ArrayAddF32(@LSrc1[0], @LSrc2[0], @LDstDispatch[0], LCount);

    for i := 0 to Integer(LCount) - 1 do
      CheckNear(Format('ArrayAddF32[count=%d,i=%d]', [LCount, i]),
        LDstScalar[i], LDstDispatch[i]);
  end;
  WriteLn('  ArrayAddF32: checked');
end;

procedure TestArrayMulF32;
var
  LSrc1, LSrc2, LDstScalar, LDstDispatch: array[0..MAX_COUNT-1] of Single;
  LCount: SizeUInt;
  LCounts: array[0..17] of SizeUInt = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 13, 15, 16, 17, 31, 32, 33, 65);
  ci, i: Integer;
begin
  FillTestData(@LSrc1[0], MAX_COUNT);
  FillTestData(@LSrc2[0], MAX_COUNT);
  for i := 0 to MAX_COUNT - 1 do
    LSrc2[i] := Cos(i * 1.3) * 2.0;

  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];
    FillChar(LDstScalar, SizeOf(LDstScalar), 0);
    FillChar(LDstDispatch, SizeOf(LDstDispatch), 0);

    ScalarArrayMulF32(@LSrc1[0], @LSrc2[0], @LDstScalar[0], LCount);
    ArrayMulF32(@LSrc1[0], @LSrc2[0], @LDstDispatch[0], LCount);

    for i := 0 to Integer(LCount) - 1 do
      CheckNear(Format('ArrayMulF32[count=%d,i=%d]', [LCount, i]),
        LDstScalar[i], LDstDispatch[i]);
  end;
  WriteLn('  ArrayMulF32: checked');
end;

procedure TestArrayMulScalarF32;
var
  LSrc, LDstScalar, LDstDispatch: array[0..MAX_COUNT-1] of Single;
  LCount: SizeUInt;
  LCounts: array[0..17] of SizeUInt = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 13, 15, 16, 17, 31, 32, 33, 65);
  LScalars: array[0..4] of Single = (-2.5, 0.0, 1.0, 0.001, -100.0);
  ci, si, i: Integer;
begin
  FillTestData(@LSrc[0], MAX_COUNT);

  for ci := 0 to High(LCounts) do
    for si := 0 to High(LScalars) do
    begin
      LCount := LCounts[ci];
      FillChar(LDstScalar, SizeOf(LDstScalar), 0);
      FillChar(LDstDispatch, SizeOf(LDstDispatch), 0);

      ScalarArrayMulScalarF32(@LSrc[0], @LDstScalar[0], LCount, LScalars[si]);
      ArrayMulScalarF32(@LSrc[0], @LDstDispatch[0], LCount, LScalars[si]);

      for i := 0 to Integer(LCount) - 1 do
        CheckNear(Format('ArrayMulScalarF32[count=%d,scalar=%.2g,i=%d]',
          [LCount, Double(LScalars[si]), i]),
          LDstScalar[i], LDstDispatch[i]);
    end;
  WriteLn('  ArrayMulScalarF32: checked');
end;

procedure TestArrayAxpyF32;
var
  LX, LY, LDstScalar, LDstDispatch: array[0..MAX_COUNT-1] of Single;
  LCount: SizeUInt;
  LCounts: array[0..17] of SizeUInt = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 13, 15, 16, 17, 31, 32, 33, 65);
  LAlphas: array[0..3] of Single = (-1.5, 0.0, 1.0, 3.14);
  ci, ai, i: Integer;
begin
  FillTestData(@LX[0], MAX_COUNT);
  for i := 0 to MAX_COUNT - 1 do
    LY[i] := Cos(i * 0.9) * 30.0 + 5.0;

  for ci := 0 to High(LCounts) do
    for ai := 0 to High(LAlphas) do
    begin
      LCount := LCounts[ci];
      FillChar(LDstScalar, SizeOf(LDstScalar), 0);
      FillChar(LDstDispatch, SizeOf(LDstDispatch), 0);

      ScalarArrayAxpyF32(LAlphas[ai], @LX[0], @LY[0], @LDstScalar[0], LCount);
      ArrayAxpyF32(LAlphas[ai], @LX[0], @LY[0], @LDstDispatch[0], LCount);

      for i := 0 to Integer(LCount) - 1 do
        CheckNear(Format('ArrayAxpyF32[count=%d,alpha=%.2g,i=%d]',
          [LCount, Double(LAlphas[ai]), i]),
          LDstScalar[i], LDstDispatch[i]);
    end;
  WriteLn('  ArrayAxpyF32: checked');
end;

procedure TestInPlace;
var
  LBuf, LRef: array[0..15] of Single;
  i: Integer;
begin
  for i := 0 to 15 do LBuf[i] := i * 1.5 - 3.0;
  Move(LBuf, LRef, SizeOf(LBuf));

  ArrayAddF32(@LBuf[0], @LBuf[0], @LBuf[0], 16);
  for i := 0 to 15 do
    CheckNear(Format('InPlace-Add[%d]', [i]), LRef[i] + LRef[i], LBuf[i]);

  for i := 0 to 15 do LBuf[i] := i * 1.5 - 3.0;
  ArrayMulScalarF32(@LBuf[0], @LBuf[0], 16, 2.0);
  for i := 0 to 15 do
    CheckNear(Format('InPlace-MulScalar[%d]', [i]), LRef[i] * 2.0, LBuf[i]);

  WriteLn('  InPlace: checked');
end;

procedure TestArraySubF32;
var
  LSrc1, LSrc2, LDstScalar, LDstDispatch: array[0..MAX_COUNT-1] of Single;
  LCount: SizeUInt;
  LCounts: array[0..7] of SizeUInt = (0, 1, 4, 7, 8, 16, 32, 65);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
begin
  FillTestData(@LSrc1[0], MAX_COUNT);
  FillTestData(@LSrc2[0], MAX_COUNT);
  LDispatch := GetDispatchTable;
  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];
    FillChar(LDstScalar, SizeOf(LDstScalar), 0);
    FillChar(LDstDispatch, SizeOf(LDstDispatch), 0);
    ScalarArraySubF32(@LSrc1[0], @LSrc2[0], @LDstScalar[0], LCount);
    LDispatch^.ArraySubF32(@LSrc1[0], @LSrc2[0], @LDstDispatch[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
      CheckNear(Format('ArraySubF32[count=%d,i=%d]', [LCount, i]),
        LDstScalar[i], LDstDispatch[i]);
  end;
  WriteLn('  ArraySubF32: checked');
end;

procedure TestArrayDivF32;
var
  LSrc1, LSrc2, LDstScalar, LDstDispatch: array[0..MAX_COUNT-1] of Single;
  LCount: SizeUInt;
  LCounts: array[0..7] of SizeUInt = (0, 1, 4, 7, 8, 16, 32, 65);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
begin
  FillTestData(@LSrc1[0], MAX_COUNT);
  for i := 0 to MAX_COUNT - 1 do
    LSrc2[i] := 1.0 + Abs(Sin(i * 0.9));
  LDispatch := GetDispatchTable;
  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];
    FillChar(LDstScalar, SizeOf(LDstScalar), 0);
    FillChar(LDstDispatch, SizeOf(LDstDispatch), 0);
    ScalarArrayDivF32(@LSrc1[0], @LSrc2[0], @LDstScalar[0], LCount);
    LDispatch^.ArrayDivF32(@LSrc1[0], @LSrc2[0], @LDstDispatch[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
      CheckNear(Format('ArrayDivF32[count=%d,i=%d]', [LCount, i]),
        LDstScalar[i], LDstDispatch[i]);
  end;
  WriteLn('  ArrayDivF32: checked');
end;

procedure TestArrayAbsNegSqrtF32;
var
  LSrc, LDstScalar, LDstDispatch: array[0..MAX_COUNT-1] of Single;
  LCount: SizeUInt;
  LCounts: array[0..7] of SizeUInt = (0, 1, 4, 7, 8, 16, 32, 65);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
begin
  FillTestData(@LSrc[0], MAX_COUNT);
  LDispatch := GetDispatchTable;

  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];
    FillChar(LDstScalar, SizeOf(LDstScalar), 0);
    FillChar(LDstDispatch, SizeOf(LDstDispatch), 0);
    ScalarArrayAbsF32(@LSrc[0], @LDstScalar[0], LCount);
    LDispatch^.ArrayAbsF32(@LSrc[0], @LDstDispatch[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
      CheckNear(Format('ArrayAbsF32[count=%d,i=%d]', [LCount, i]),
        LDstScalar[i], LDstDispatch[i]);

    FillChar(LDstScalar, SizeOf(LDstScalar), 0);
    FillChar(LDstDispatch, SizeOf(LDstDispatch), 0);
    ScalarArrayNegF32(@LSrc[0], @LDstScalar[0], LCount);
    LDispatch^.ArrayNegF32(@LSrc[0], @LDstDispatch[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
      CheckNear(Format('ArrayNegF32[count=%d,i=%d]', [LCount, i]),
        LDstScalar[i], LDstDispatch[i]);
  end;

  for i := 0 to MAX_COUNT - 1 do
    LSrc[i] := Abs(LSrc[i]);
  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];
    FillChar(LDstScalar, SizeOf(LDstScalar), 0);
    FillChar(LDstDispatch, SizeOf(LDstDispatch), 0);
    ScalarArraySqrtF32(@LSrc[0], @LDstScalar[0], LCount);
    LDispatch^.ArraySqrtF32(@LSrc[0], @LDstDispatch[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
      CheckNear(Format('ArraySqrtF32[count=%d,i=%d]', [LCount, i]),
        LDstScalar[i], LDstDispatch[i]);
  end;
  WriteLn('  ArrayAbs/Neg/SqrtF32: checked');
end;

procedure TestArrayClampF32;
var
  LSrc, LDstScalar, LDstDispatch: array[0..MAX_COUNT-1] of Single;
  LCount: SizeUInt;
  LCounts: array[0..7] of SizeUInt = (0, 1, 4, 7, 8, 16, 32, 65);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
begin
  FillTestData(@LSrc[0], MAX_COUNT);
  LDispatch := GetDispatchTable;
  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];
    FillChar(LDstScalar, SizeOf(LDstScalar), 0);
    FillChar(LDstDispatch, SizeOf(LDstDispatch), 0);
    ScalarArrayClampF32(@LSrc[0], @LDstScalar[0], LCount, -10.0, 25.0);
    LDispatch^.ArrayClampF32(@LSrc[0], @LDstDispatch[0], LCount, -10.0, 25.0);
    for i := 0 to Integer(LCount) - 1 do
      CheckNear(Format('ArrayClampF32[count=%d,i=%d]', [LCount, i]),
        LDstScalar[i], LDstDispatch[i]);
  end;
  WriteLn('  ArrayClampF32: checked');
end;

procedure TestArrayFmaF32;
var
  LA, LB, LC, LDstScalar, LDstDispatch: array[0..MAX_COUNT-1] of Single;
  LCount: SizeUInt;
  LCounts: array[0..7] of SizeUInt = (0, 1, 4, 7, 8, 16, 32, 65);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
begin
  FillTestData(@LA[0], MAX_COUNT);
  for i := 0 to MAX_COUNT - 1 do
  begin
    LB[i] := Cos(i * 1.1) * 2.0;
    LC[i] := Sin(i * 0.3) * 10.0;
  end;
  LDispatch := GetDispatchTable;
  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];
    FillChar(LDstScalar, SizeOf(LDstScalar), 0);
    FillChar(LDstDispatch, SizeOf(LDstDispatch), 0);
    ScalarArrayFmaF32(@LA[0], @LB[0], @LC[0], @LDstScalar[0], LCount);
    LDispatch^.ArrayFmaF32(@LA[0], @LB[0], @LC[0], @LDstDispatch[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
      CheckNearRelative(Format('ArrayFmaF32[count=%d,i=%d]', [LCount, i]),
        LDstScalar[i], LDstDispatch[i], 1e-6);
  end;
  WriteLn('  ArrayFmaF32: checked');
end;

procedure TestArrayRcpRsqrtF32;
const
  RCP_REL_TOL = 2e-3;
var
  LSrc, LDst: array[0..MAX_COUNT-1] of Single;
  LCount: SizeUInt;
  LCounts: array[0..5] of SizeUInt = (1, 4, 8, 16, 32, 65);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LExpected: Single;
begin
  for i := 0 to MAX_COUNT - 1 do
    LSrc[i] := 1.0 + Abs(Sin(i * 0.7)) * 99.0;
  LDispatch := GetDispatchTable;

  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];
    FillChar(LDst, SizeOf(LDst), 0);
    LDispatch^.ArrayRcpF32(@LSrc[0], @LDst[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
    begin
      LExpected := 1.0 / LSrc[i];
      CheckNearRelative(Format('ArrayRcpF32[count=%d,i=%d]', [LCount, i]),
        LExpected, LDst[i], RCP_REL_TOL);
    end;

    FillChar(LDst, SizeOf(LDst), 0);
    LDispatch^.ArrayRsqrtF32(@LSrc[0], @LDst[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
    begin
      LExpected := 1.0 / Sqrt(LSrc[i]);
      CheckNearRelative(Format('ArrayRsqrtF32[count=%d,i=%d]', [LCount, i]),
        LExpected, LDst[i], RCP_REL_TOL);
    end;
  end;
  WriteLn('  ArrayRcp/RsqrtF32: checked (approx ~12-bit)');
end;

procedure TestReduceOps;
const
  REDUCE_REL_TOL = 1e-5;
var
  LSrc1, LSrc2: array[0..MAX_COUNT-1] of Single;
  LCount: SizeUInt;
  LCounts: array[0..7] of SizeUInt = (1, 4, 7, 8, 16, 32, 33, 65);
  ci: Integer;
  LDispatch: PSimdDispatchTable;
  LScalar, LDisp: Single;
begin
  FillTestData(@LSrc1[0], MAX_COUNT);
  FillTestData(@LSrc2[0], MAX_COUNT);
  for ci := 0 to MAX_COUNT - 1 do
    LSrc2[ci] := Cos(ci * 0.5) * 3.0;
  LDispatch := GetDispatchTable;

  for ci := 0 to High(LCounts) do
  begin
    LCount := LCounts[ci];
    LScalar := ScalarReduceSumF32(@LSrc1[0], LCount);
    LDisp := LDispatch^.ReduceSumF32(@LSrc1[0], LCount);
    CheckNearRelative(Format('ReduceSumF32[count=%d]', [LCount]), LScalar, LDisp, REDUCE_REL_TOL);

    LScalar := ScalarReduceMinF32(@LSrc1[0], LCount);
    LDisp := LDispatch^.ReduceMinF32(@LSrc1[0], LCount);
    CheckNear(Format('ReduceMinF32[count=%d]', [LCount]), LScalar, LDisp);

    LScalar := ScalarReduceMaxF32(@LSrc1[0], LCount);
    LDisp := LDispatch^.ReduceMaxF32(@LSrc1[0], LCount);
    CheckNear(Format('ReduceMaxF32[count=%d]', [LCount]), LScalar, LDisp);

    LScalar := ScalarReduceDotF32(@LSrc1[0], @LSrc2[0], LCount);
    LDisp := LDispatch^.ReduceDotF32(@LSrc1[0], @LSrc2[0], LCount);
    CheckNearRelative(Format('ReduceDotF32[count=%d]', [LCount]), LScalar, LDisp, REDUCE_REL_TOL);
  end;
  WriteLn('  ReduceSum/Min/Max/DotF32: checked');
end;

var
  LDispatch: PSimdDispatchTable;

procedure RunAllTests;
begin
  TestArrayAddF32;
  TestArrayMulF32;
  TestArrayMulScalarF32;
  TestArrayAxpyF32;
  TestArraySubF32;
  TestArrayDivF32;
  TestArrayAbsNegSqrtF32;
  TestArrayClampF32;
  TestArrayFmaF32;
  TestArrayRcpRsqrtF32;
  TestReduceOps;
  TestInPlace;
end;

begin
  LDispatch := GetDispatchTable;
  WriteLn('[ArrayF32 Backend Correctness]');
  WriteLn('');

  WriteLn('=== Pass 1: Default backend (', GetBackendInfo(GetActiveBackend).Name, ') ===');
  RunAllTests;

  if TrySetActiveBackend(sbSSE2) then
  begin
    WriteLn('');
    WriteLn('=== Pass 2: Forced SSE2 ===');
    RunAllTests;
  end
  else
    WriteLn('  (SSE2 backend not available, skipping)');

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
