unit nextpas.core.simd.dispatchapi.batchparity.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}
{$WARN 6060 OFF}

// Keep parity with the original testcase compilation behavior.
{$R-}{$Q-}

// Mirror the global conditions that make NEON asm compile in the backend unit.
{$IFDEF CPUAARCH64}
  {$IFDEF FPC}
    {$IF FPC_FULLVERSION >= 030301}
      {$IFNDEF SIMD_VECTOR_ASM_DISABLED}
        {$IFDEF NEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM}
          {$IFDEF NEXTPAS_SIMD_ENABLE_NEON_ASM}
            {$IFDEF NEXTPAS_SIMD_NEON_ASM_COMPILER_READY}
              {$DEFINE NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
            {$ENDIF}
          {$ENDIF}
        {$ENDIF}
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}
{$ENDIF}

// Mirror the global conditions that make RISCVV asm compile in the backend unit.
{$IF DEFINED(CPURISCV64) OR DEFINED(CPURISCV32)}
  {$IFDEF FPC}
    {$IFNDEF SIMD_VECTOR_ASM_DISABLED}
      {$IFDEF NEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM}
        {$IFDEF NEXTPAS_SIMD_ENABLE_RISCVV_ASM}
          {$IFDEF NEXTPAS_SIMD_RISCVV_ASM_COMPILER_READY}
            {$IFDEF NEXTPAS_SIMD_RISCVV_ASM_OPCODE_READY}
              {$DEFINE NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
            {$ENDIF}
          {$ENDIF}
        {$ENDIF}
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}
{$ENDIF}

interface

uses
  nextpas.core.base,
  nextpas.core.math,
  nextpas.core.path,
  nextpas.core.fs,
  nextpas.core.text.conv,
  nextpas.core.platform.files,
  nextpas.core.platform.files.base,
  nextpas.core.platform.path,
  nextpas.core.text,
  nextpas.core.test,
  nextpas.core.simd,
  nextpas.core.simd.testcase,
  nextpas.core.simd.base,
  nextpas.core.simd.bench,
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.cpuinfo.base,
  nextpas.core.simd.utils,
  nextpas.core.simd.ops,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.dataplane,
  nextpas.core.simd.backend.priority,
  nextpas.core.simd.public_smoke_support,
  nextpas.core.simd.scalar,
  nextpas.core.simd.dispatchapi.support;

type
  TTestCase_DispatchAPIBatchParity = class(TDispatchAPIStatefulTestCase)
  published
    procedure Test_BatchF32_ArrayDiv_SpecialParity_Matches_Scalar;
    procedure Test_BatchF32_ArrayMulAddScalar_Parity;
    procedure Test_BatchF32_ArrayLerpClamp_Parity;
    procedure Test_BatchF32_ArrayFmaAxpy_Parity;
    procedure Test_BatchF32_ArraySqrtReduceSum_Parity;
    procedure Test_BatchF32_ReduceMinMax_Parity;
    procedure Test_BatchF32_ArrayRcpReduceDot_Parity;
    procedure Test_BatchF32_ArrayRsqrtRcpRefine_Parity;
    procedure Test_BatchF32_ArrayRsqrtRefine_Parity;
    procedure Test_BatchF32_ArrayLinear_Parity;
    procedure Test_BatchF32_ArrayCeilFloorTrunc_Parity;
    procedure Test_BatchF32_ArrayReLUAbsDiff_Parity;
    procedure Test_BatchF64_ArrayCore8_Parity;
    procedure Test_BatchF64_SqrtBroadcastReduce_Parity;
    procedure Test_BatchF64_LinearClampLerpFmaAxpy_Parity;
    procedure Test_BatchF64_CeilFloorTruncReLUAbsDiff_Parity;
    procedure Test_BatchF64_RcpRsqrtRefine_Parity;
    procedure Test_BatchF32_ArraySinExp_NearParity;
    procedure Test_BatchF32_ArrayCosSinCos_NearParity;
    procedure Test_BatchF32_ArrayLogFamily_NearParity;
    procedure Test_BatchF64_ArraySinExp_NearParity;
    procedure Test_BatchF32_ArrayTan_ChunkBoundary_NearParity;
    procedure Test_ArrayTanF32_NoHeapScratch_SourceAudit;
  end;

implementation

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF32_ArrayDiv_SpecialParity_Matches_Scalar;
var
  LSrc1, LSrc2, LDstScalar, LDstDispatch: array[0..15] of Single;
  LCount: SizeUInt;
  i: Integer;
  LDispatch: PSimdDispatchTable;
  LBits: LongWord;
  LPosInf, LNegInf, LQNaN, LNegZero: Single;
  eBits, aBits: LongWord;
  LSavedMask: TFPUExceptionMask;
begin
  { Batch B1 unit test: ArrayDiv specials (+/-0, Inf, NaN, count=0) match scalar bits. }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LBits := $7F800000; LPosInf := PSingle(@LBits)^;
    LBits := $FF800000; LNegInf := PSingle(@LBits)^;
    LBits := $7FC00001; LQNaN := PSingle(@LBits)^;
    LBits := $80000000; LNegZero := PSingle(@LBits)^;

    LDispatch := GetDispatchTable;
    LCount := 8;
    LSrc1[0] := 1.0;  LSrc2[0] := 0.0;
    LSrc1[1] := -2.0; LSrc2[1] := 0.0;
    LSrc1[2] := 0.0;  LSrc2[2] := 0.0;
    LSrc1[3] := 3.0;  LSrc2[3] := 1.0;
    LSrc1[4] := 1.0;  LSrc2[4] := LNegZero;
    LSrc1[5] := LPosInf; LSrc2[5] := 2.0;
    LSrc1[6] := LNegInf; LSrc2[6] := -4.0;
    LSrc1[7] := LQNaN; LSrc2[7] := 5.0;
    for i := 8 to 15 do
    begin
      LSrc1[i] := 0.0;
      LSrc2[i] := 1.0;
    end;

    FillChar(LDstScalar, SizeOf(LDstScalar), 0);
    FillChar(LDstDispatch, SizeOf(LDstDispatch), 0);
    ScalarArrayDivF32(@LSrc1[0], @LSrc2[0], @LDstScalar[0], LCount);
    LDispatch^.BatchF32.ArrayDiv(@LSrc1[0], @LSrc2[0], @LDstDispatch[0], LCount);
    for i := 0 to Integer(LCount) - 1 do
    begin
      eBits := PLongWord(@LDstScalar[i])^;
      aBits := PLongWord(@LDstDispatch[i])^;
      CheckEqual(eBits, aBits, 'ArrayDiv special parity lane ' + IntToStr(i));
    end;

    LDstDispatch[0] := 42.0;
    LDispatch^.BatchF32.ArrayDiv(@LSrc1[0], @LSrc2[0], @LDstDispatch[0], 0);
    CheckTrue(Abs(LDstDispatch[0] - 42.0) < 1e-6, 'ArrayDiv count=0 must leave dst untouched');
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF32_ArrayMulAddScalar_Parity;
var
  LSrc, LDstScalar, LDstDispatch: array[0..64] of Single;
  LCount: SizeUInt;
  LCounts: array[0..5] of SizeUInt = (0, 1, 4, 7, 16, 65);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LScalar: Single;
  LSavedMask: TFPUExceptionMask;
  eBits, aBits: LongWord;
  LBits: LongWord;
  LQNaN: Single;
begin
  { Batch B2 unit test: MulScalar/AddScalar match scalar for lengths + specials. }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LDispatch := GetDispatchTable;
    for i := 0 to 64 do
      LSrc[i] := Single(i) * 0.25 - 4.0;

    for ci := 0 to High(LCounts) do
    begin
      LCount := LCounts[ci];
      if LCount > 65 then
        LCount := 65;
      LScalar := 2.5;
      FillChar(LDstScalar, SizeOf(LDstScalar), 0);
      FillChar(LDstDispatch, SizeOf(LDstDispatch), 0);
      ScalarArrayMulScalarF32(@LSrc[0], @LDstScalar[0], LCount, LScalar);
      LDispatch^.BatchF32.ArrayMulScalar(@LSrc[0], @LDstDispatch[0], LCount, LScalar);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PLongWord(@LDstScalar[i])^;
        aBits := PLongWord(@LDstDispatch[i])^;
        CheckEqual(eBits, aBits, 'MulScalar parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      LScalar := -1.5;
      FillChar(LDstScalar, SizeOf(LDstScalar), 0);
      FillChar(LDstDispatch, SizeOf(LDstDispatch), 0);
      ScalarArrayAddScalarF32(@LSrc[0], @LDstScalar[0], LCount, LScalar);
      LDispatch^.BatchF32.ArrayAddScalar(@LSrc[0], @LDstDispatch[0], LCount, LScalar);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PLongWord(@LDstScalar[i])^;
        aBits := PLongWord(@LDstDispatch[i])^;
        CheckEqual(eBits, aBits, 'AddScalar parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;
    end;

    { count=0 no-op }
    LDstDispatch[0] := 99.0;
    LDispatch^.BatchF32.ArrayMulScalar(@LSrc[0], @LDstDispatch[0], 0, 3.0);
    CheckTrue(Abs(LDstDispatch[0] - 99.0) < 1e-6, 'MulScalar count=0 leaves dst');
    LDispatch^.BatchF32.ArrayAddScalar(@LSrc[0], @LDstDispatch[0], 0, 3.0);
    CheckTrue(Abs(LDstDispatch[0] - 99.0) < 1e-6, 'AddScalar count=0 leaves dst');

    { NaN * scale and NaN + offset }
    LBits := $7FC00001; LQNaN := PSingle(@LBits)^;
    LSrc[0] := LQNaN;
    ScalarArrayMulScalarF32(@LSrc[0], @LDstScalar[0], 1, 2.0);
    LDispatch^.BatchF32.ArrayMulScalar(@LSrc[0], @LDstDispatch[0], 1, 2.0);
    eBits := PLongWord(@LDstScalar[0])^;
    aBits := PLongWord(@LDstDispatch[0])^;
    CheckEqual(eBits, aBits, 'MulScalar NaN parity');
    ScalarArrayAddScalarF32(@LSrc[0], @LDstScalar[0], 1, 2.0);
    LDispatch^.BatchF32.ArrayAddScalar(@LSrc[0], @LDstDispatch[0], 1, 2.0);
    eBits := PLongWord(@LDstScalar[0])^;
    aBits := PLongWord(@LDstDispatch[0])^;
    CheckEqual(eBits, aBits, 'AddScalar NaN parity');
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF32_ArrayLerpClamp_Parity;
var
  LSrc, LStart, LEnd, LDstS, LDstD: array[0..64] of Single;
  LCount: SizeUInt;
  LCounts: array[0..5] of SizeUInt = (0, 1, 4, 7, 16, 65);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LSavedMask: TFPUExceptionMask;
  eBits, aBits: LongWord;
  LMin, LMax, LT: Single;
begin
  { Batch B3: Clamp/Lerp match scalar for length matrix, endpoints, count=0. }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LDispatch := GetDispatchTable;
    for i := 0 to 64 do
    begin
      LSrc[i] := Single(i) - 10.0;
      LStart[i] := Single(i) * 0.1;
      LEnd[i] := Single(i) * 0.1 + 5.0;
    end;

    for ci := 0 to High(LCounts) do
    begin
      LCount := LCounts[ci];
      if LCount > 65 then
        LCount := 65;
      LMin := -2.0;
      LMax := 8.0;
      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayClampF32(@LSrc[0], @LDstS[0], LCount, LMin, LMax);
      LDispatch^.BatchF32.ArrayClamp(@LSrc[0], @LDstD[0], LCount, LMin, LMax);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PLongWord(@LDstS[i])^;
        aBits := PLongWord(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'Clamp parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      LT := 0.0;
      ScalarArrayLerpF32(@LStart[0], @LEnd[0], @LDstS[0], LCount, LT);
      LDispatch^.BatchF32.ArrayLerp(@LStart[0], @LEnd[0], @LDstD[0], LCount, LT);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PLongWord(@LDstS[i])^;
        aBits := PLongWord(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'Lerp t=0 count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      LT := 1.0;
      ScalarArrayLerpF32(@LStart[0], @LEnd[0], @LDstS[0], LCount, LT);
      LDispatch^.BatchF32.ArrayLerp(@LStart[0], @LEnd[0], @LDstD[0], LCount, LT);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PLongWord(@LDstS[i])^;
        aBits := PLongWord(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'Lerp t=1 count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      LT := 0.5;
      ScalarArrayLerpF32(@LStart[0], @LEnd[0], @LDstS[0], LCount, LT);
      LDispatch^.BatchF32.ArrayLerp(@LStart[0], @LEnd[0], @LDstD[0], LCount, LT);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PLongWord(@LDstS[i])^;
        aBits := PLongWord(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'Lerp t=0.5 count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;
    end;

    LDstD[0] := 77.0;
    LDispatch^.BatchF32.ArrayClamp(@LSrc[0], @LDstD[0], 0, -1.0, 1.0);
    CheckTrue(Abs(LDstD[0] - 77.0) < 1e-6, 'Clamp count=0 leaves dst');
    LDispatch^.BatchF32.ArrayLerp(@LStart[0], @LEnd[0], @LDstD[0], 0, 0.5);
    CheckTrue(Abs(LDstD[0] - 77.0) < 1e-6, 'Lerp count=0 leaves dst');
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF32_ArrayFmaAxpy_Parity;
var
  LA, LB, LC, LX, LY, LDstS, LDstD: array[0..64] of Single;
  LCount: SizeUInt;
  LCounts: array[0..5] of SizeUInt = (0, 1, 4, 7, 16, 65);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LSavedMask: TFPUExceptionMask;
  eBits, aBits: LongWord;
  LAlpha: Single;
  LAlphas: array[0..2] of Single = (0.0, 1.0, 2.5);
  ai: Integer;
begin
  { Batch B4: Fma/Axpy match scalar for length matrix and alpha set. }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LDispatch := GetDispatchTable;
    for i := 0 to 64 do
    begin
      LA[i] := Single(i) * 0.1;
      LB[i] := Single(i) * 0.2 + 1.0;
      LC[i] := Single(i) * 0.05 - 0.5;
      LX[i] := Single(i) - 5.0;
      LY[i] := Single(i) * 0.25;
    end;

    for ci := 0 to High(LCounts) do
    begin
      LCount := LCounts[ci];
      if LCount > 65 then
        LCount := 65;
      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayFmaF32(@LA[0], @LB[0], @LC[0], @LDstS[0], LCount);
      LDispatch^.BatchF32.ArrayFma(@LA[0], @LB[0], @LC[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PLongWord(@LDstS[i])^;
        aBits := PLongWord(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'Fma parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      for ai := 0 to High(LAlphas) do
      begin
        LAlpha := LAlphas[ai];
        FillChar(LDstS, SizeOf(LDstS), 0);
        FillChar(LDstD, SizeOf(LDstD), 0);
        ScalarArrayAxpyF32(LAlpha, @LX[0], @LY[0], @LDstS[0], LCount);
        LDispatch^.BatchF32.ArrayAxpy(LAlpha, @LX[0], @LY[0], @LDstD[0], LCount);
        for i := 0 to Integer(LCount) - 1 do
        begin
          eBits := PLongWord(@LDstS[i])^;
          aBits := PLongWord(@LDstD[i])^;
          CheckEqual(eBits, aBits, 'Axpy parity alpha=' + IntToStr(ai) + ' count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
        end;
      end;
    end;

    LDstD[0] := 55.0;
    LDispatch^.BatchF32.ArrayFma(@LA[0], @LB[0], @LC[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 55.0) < 1e-6, 'Fma count=0 leaves dst');
    LDispatch^.BatchF32.ArrayAxpy(2.0, @LX[0], @LY[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 55.0) < 1e-6, 'Axpy count=0 leaves dst');
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF32_ArraySqrtReduceSum_Parity;
var
  LSrc, LDstS, LDstD: array[0..64] of Single;
  LCount: SizeUInt;
  LCounts: array[0..5] of SizeUInt = (0, 1, 4, 7, 16, 65);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LSavedMask: TFPUExceptionMask;
  eBits, aBits: LongWord;
  LSumS, LSumD: Single;
  LAbsDiff, LScale: Single;
begin
  { Batch B5: Sqrt bit-parity on non-neg; ReduceSum near-parity (assoc). }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LDispatch := GetDispatchTable;
    for i := 0 to 64 do
      LSrc[i] := Single(i) * 0.25 + 0.01; { non-negative for sqrt }

    for ci := 0 to High(LCounts) do
    begin
      LCount := LCounts[ci];
      if LCount > 65 then
        LCount := 65;
      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArraySqrtF32(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF32.ArraySqrt(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PLongWord(@LDstS[i])^;
        aBits := PLongWord(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'Sqrt parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      LSumS := ScalarReduceSumF32(@LSrc[0], LCount);
      LSumD := LDispatch^.BatchF32.ReduceSum(@LSrc[0], LCount);
      if LCount <= 1 then
      begin
        eBits := PLongWord(@LSumS)^;
        aBits := PLongWord(@LSumD)^;
        CheckEqual(eBits, aBits, 'ReduceSum bit parity count=' + IntToStr(LCount));
      end
      else
      begin
        LAbsDiff := Abs(LSumS - LSumD);
        LScale := Abs(LSumS);
        if LScale < 1.0 then
          LScale := 1.0;
        CheckTrue(LAbsDiff <= 1e-4 * LScale + 1e-5,
          'ReduceSum near parity count=' + IntToStr(LCount));
      end;
    end;

    LDstD[0] := 33.0;
    LDispatch^.BatchF32.ArraySqrt(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 33.0) < 1e-6, 'Sqrt count=0 leaves dst');
    CheckTrue(Abs(LDispatch^.BatchF32.ReduceSum(@LSrc[0], 0)) < 1e-6, 'ReduceSum count=0 is 0');
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF32_ReduceMinMax_Parity;
var
  LSrc: array[0..64] of Single;
  LCount: SizeUInt;
  LCounts: array[0..5] of SizeUInt = (0, 1, 4, 7, 16, 65);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LSavedMask: TFPUExceptionMask;
  eBits, aBits: LongWord;
  LMinS, LMinD, LMaxS, LMaxD: Single;
begin
  { Batch B6: ReduceMin/Max match scalar (count=0 → 0). }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LDispatch := GetDispatchTable;
    for i := 0 to 64 do
      LSrc[i] := Single((i * 7) mod 31) - 10.0;

    for ci := 0 to High(LCounts) do
    begin
      LCount := LCounts[ci];
      if LCount > 65 then
        LCount := 65;
      LMinS := ScalarReduceMinF32(@LSrc[0], LCount);
      LMinD := LDispatch^.BatchF32.ReduceMin(@LSrc[0], LCount);
      LMaxS := ScalarReduceMaxF32(@LSrc[0], LCount);
      LMaxD := LDispatch^.BatchF32.ReduceMax(@LSrc[0], LCount);
      eBits := PLongWord(@LMinS)^;
      aBits := PLongWord(@LMinD)^;
      CheckEqual(eBits, aBits, 'ReduceMin parity count=' + IntToStr(LCount));
      eBits := PLongWord(@LMaxS)^;
      aBits := PLongWord(@LMaxD)^;
      CheckEqual(eBits, aBits, 'ReduceMax parity count=' + IntToStr(LCount));
    end;
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF32_ArrayRcpReduceDot_Parity;
var
  LSrc, LSrc2, LDstS, LDstD: array[0..64] of Single;
  LCount: SizeUInt;
  LCounts: array[0..5] of SizeUInt = (0, 1, 4, 7, 16, 65);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LSavedMask: TFPUExceptionMask;
  eBits, aBits: LongWord;
  LDotS, LDotD, LAbsDiff, LScale: Single;
begin
  { Batch B7: Rcp exact 1/x; ReduceDot near-parity for long counts. }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LDispatch := GetDispatchTable;
    for i := 0 to 64 do
    begin
      LSrc[i] := Single(i) * 0.15 + 0.5; { non-zero for rcp }
      LSrc2[i] := Single(i) * 0.1 - 2.0;
    end;

    for ci := 0 to High(LCounts) do
    begin
      LCount := LCounts[ci];
      if LCount > 65 then
        LCount := 65;
      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayRcpF32(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF32.ArrayRcp(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PLongWord(@LDstS[i])^;
        aBits := PLongWord(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'Rcp parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      LDotS := ScalarReduceDotF32(@LSrc[0], @LSrc2[0], LCount);
      LDotD := LDispatch^.BatchF32.ReduceDot(@LSrc[0], @LSrc2[0], LCount);
      if LCount <= 1 then
      begin
        eBits := PLongWord(@LDotS)^;
        aBits := PLongWord(@LDotD)^;
        CheckEqual(eBits, aBits, 'ReduceDot bit parity count=' + IntToStr(LCount));
      end
      else
      begin
        LAbsDiff := Abs(LDotS - LDotD);
        LScale := Abs(LDotS);
        if LScale < 1.0 then
          LScale := 1.0;
        CheckTrue(LAbsDiff <= 1e-4 * LScale + 1e-5,
          'ReduceDot near parity count=' + IntToStr(LCount));
      end;
    end;

    LDstD[0] := 11.0;
    LDispatch^.BatchF32.ArrayRcp(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 11.0) < 1e-6, 'Rcp count=0 leaves dst');
    CheckTrue(Abs(LDispatch^.BatchF32.ReduceDot(@LSrc[0], @LSrc2[0], 0)) < 1e-6, 'ReduceDot count=0 is 0');
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF32_ArrayRsqrtRcpRefine_Parity;
var
  LSrc, LDstS, LDstD: array[0..64] of Single;
  LCount: SizeUInt;
  LCounts: array[0..5] of SizeUInt = (0, 1, 4, 7, 16, 65);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LSavedMask: TFPUExceptionMask;
  eBits, aBits: LongWord;
begin
  { Batch B8: Rsqrt=1/sqrt, RcpRefine=1/x exact vs scalar. }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LDispatch := GetDispatchTable;
    for i := 0 to 64 do
      LSrc[i] := Single(i) * 0.2 + 0.25; { positive }

    for ci := 0 to High(LCounts) do
    begin
      LCount := LCounts[ci];
      if LCount > 65 then
        LCount := 65;
      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayRsqrtF32(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF32.ArrayRsqrt(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PLongWord(@LDstS[i])^;
        aBits := PLongWord(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'Rsqrt parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayRcpRefineF32(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF32.ArrayRcpRefine(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PLongWord(@LDstS[i])^;
        aBits := PLongWord(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'RcpRefine parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;
    end;

    LDstD[0] := 9.0;
    LDispatch^.BatchF32.ArrayRsqrt(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 9.0) < 1e-6, 'Rsqrt count=0 leaves dst');
    LDispatch^.BatchF32.ArrayRcpRefine(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 9.0) < 1e-6, 'RcpRefine count=0 leaves dst');
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF32_ArrayRsqrtRefine_Parity;
var
  LSrc, LDstS, LDstD: array[0..64] of Single;
  LCount: SizeUInt;
  LCounts: array[0..5] of SizeUInt = (0, 1, 4, 7, 16, 65);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LSavedMask: TFPUExceptionMask;
  eBits, aBits: LongWord;
begin
  { Batch B9: RsqrtRefine = 1/sqrt exact vs scalar. }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LDispatch := GetDispatchTable;
    for i := 0 to 64 do
      LSrc[i] := Single(i) * 0.2 + 0.25;

    for ci := 0 to High(LCounts) do
    begin
      LCount := LCounts[ci];
      if LCount > 65 then
        LCount := 65;
      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayRsqrtRefineF32(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF32.ArrayRsqrtRefine(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PLongWord(@LDstS[i])^;
        aBits := PLongWord(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'RsqrtRefine parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;
    end;

    LDstD[0] := 8.0;
    LDispatch^.BatchF32.ArrayRsqrtRefine(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 8.0) < 1e-6, 'RsqrtRefine count=0 leaves dst');
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF32_ArrayLinear_Parity;
var
  LSrc, LDstS, LDstD: array[0..64] of Single;
  LCount: SizeUInt;
  LCounts: array[0..5] of SizeUInt = (0, 1, 4, 7, 16, 65);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LSavedMask: TFPUExceptionMask;
  eBits, aBits: LongWord;
  LScale, LBias: Single;
begin
  { Wave C1: ArrayLinear dst = scale*src + bias vs scalar. }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LDispatch := GetDispatchTable;
    for i := 0 to 64 do
      LSrc[i] := Single(i) * 0.25 - 3.0;
    LScale := 1.5;
    LBias := -0.75;

    for ci := 0 to High(LCounts) do
    begin
      LCount := LCounts[ci];
      if LCount > 65 then
        LCount := 65;
      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayLinearF32(@LSrc[0], @LDstS[0], LCount, LScale, LBias);
      LDispatch^.BatchF32.ArrayLinear(@LSrc[0], @LDstD[0], LCount, LScale, LBias);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PLongWord(@LDstS[i])^;
        aBits := PLongWord(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'Linear parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;
    end;

    { scale=0 → all bias }
    FillChar(LDstS, SizeOf(LDstS), 0);
    FillChar(LDstD, SizeOf(LDstD), 0);
    ScalarArrayLinearF32(@LSrc[0], @LDstS[0], 8, 0.0, 2.5);
    LDispatch^.BatchF32.ArrayLinear(@LSrc[0], @LDstD[0], 8, 0.0, 2.5);
    for i := 0 to 7 do
    begin
      eBits := PLongWord(@LDstS[i])^;
      aBits := PLongWord(@LDstD[i])^;
      CheckEqual(eBits, aBits, 'Linear scale=0 i=' + IntToStr(i));
    end;

    LDstD[0] := 6.0;
    LDispatch^.BatchF32.ArrayLinear(@LSrc[0], @LDstD[0], 0, LScale, LBias);
    CheckTrue(Abs(LDstD[0] - 6.0) < 1e-6, 'Linear count=0 leaves dst');
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF32_ArrayCeilFloorTrunc_Parity;
var
  LSrc, LDstS, LDstD: array[0..64] of Single;
  LCount: SizeUInt;
  LCounts: array[0..5] of SizeUInt = (0, 1, 4, 7, 16, 65);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LSavedMask: TFPUExceptionMask;
  eBits, aBits: LongWord;
begin
  { Wave C2: Ceil/Floor/Trunc bit-match scalar (incl. negatives). }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LDispatch := GetDispatchTable;
    for i := 0 to 64 do
      LSrc[i] := Single(i) * 0.37 - 8.5; { mix of signs / fractions }

    for ci := 0 to High(LCounts) do
    begin
      LCount := LCounts[ci];
      if LCount > 65 then
        LCount := 65;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayCeilF32(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF32.ArrayCeil(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PLongWord(@LDstS[i])^;
        aBits := PLongWord(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'Ceil parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayFloorF32(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF32.ArrayFloor(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PLongWord(@LDstS[i])^;
        aBits := PLongWord(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'Floor parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayTruncF32(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF32.ArrayTrunc(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PLongWord(@LDstS[i])^;
        aBits := PLongWord(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'Trunc parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;
    end;

    LDstD[0] := 4.0;
    LDispatch^.BatchF32.ArrayCeil(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 4.0) < 1e-6, 'Ceil count=0 leaves dst');
    LDispatch^.BatchF32.ArrayFloor(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 4.0) < 1e-6, 'Floor count=0 leaves dst');
    LDispatch^.BatchF32.ArrayTrunc(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 4.0) < 1e-6, 'Trunc count=0 leaves dst');
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF32_ArrayReLUAbsDiff_Parity;
var
  LSrc, LSrc2, LDstS, LDstD: array[0..64] of Single;
  LCount: SizeUInt;
  LCounts: array[0..5] of SizeUInt = (0, 1, 4, 7, 16, 65);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LSavedMask: TFPUExceptionMask;
  eBits, aBits: LongWord;
begin
  { Wave C3: ReLU max(x,0); AbsDiff abs(a-b). }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LDispatch := GetDispatchTable;
    for i := 0 to 64 do
    begin
      LSrc[i] := Single(i) * 0.5 - 8.0;
      LSrc2[i] := Single(i) * 0.3 - 2.0;
    end;

    for ci := 0 to High(LCounts) do
    begin
      LCount := LCounts[ci];
      if LCount > 65 then
        LCount := 65;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayReLUF32(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF32.ArrayReLU(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PLongWord(@LDstS[i])^;
        aBits := PLongWord(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'ReLU parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayAbsDiffF32(@LSrc[0], @LSrc2[0], @LDstS[0], LCount);
      LDispatch^.BatchF32.ArrayAbsDiff(@LSrc[0], @LSrc2[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PLongWord(@LDstS[i])^;
        aBits := PLongWord(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'AbsDiff parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;
    end;

    LDstD[0] := 3.0;
    LDispatch^.BatchF32.ArrayReLU(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 3.0) < 1e-6, 'ReLU count=0 leaves dst');
    LDispatch^.BatchF32.ArrayAbsDiff(@LSrc[0], @LSrc2[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 3.0) < 1e-6, 'AbsDiff count=0 leaves dst');
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF64_ArrayCore8_Parity;
var
  LSrc1, LSrc2, LDstS, LDstD: array[0..64] of Double;
  LCount: SizeUInt;
  LCounts: array[0..5] of SizeUInt = (0, 1, 2, 3, 8, 33);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LSavedMask: TFPUExceptionMask;
  eBits, aBits: UInt64;
begin
  { Wave C4a: F64 Add/Sub/Mul/Div/Min/Max/Abs/Neg vs scalar bit parity. }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LDispatch := GetDispatchTable;
    for i := 0 to 64 do
    begin
      LSrc1[i] := Double(i) * 0.17 - 4.0;
      LSrc2[i] := Double(i) * 0.11 + 0.5; { non-zero for Div }
    end;

    for ci := 0 to High(LCounts) do
    begin
      LCount := LCounts[ci];
      if LCount > 65 then
        LCount := 65;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayAddF64(@LSrc1[0], @LSrc2[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArrayAdd(@LSrc1[0], @LSrc2[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 Add parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArraySubF64(@LSrc1[0], @LSrc2[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArraySub(@LSrc1[0], @LSrc2[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 Sub parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayMulF64(@LSrc1[0], @LSrc2[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArrayMul(@LSrc1[0], @LSrc2[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 Mul parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayDivF64(@LSrc1[0], @LSrc2[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArrayDiv(@LSrc1[0], @LSrc2[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 Div parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayMinF64(@LSrc1[0], @LSrc2[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArrayMin(@LSrc1[0], @LSrc2[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 Min parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayMaxF64(@LSrc1[0], @LSrc2[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArrayMax(@LSrc1[0], @LSrc2[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 Max parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayAbsF64(@LSrc1[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArrayAbs(@LSrc1[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 Abs parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayNegF64(@LSrc1[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArrayNeg(@LSrc1[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 Neg parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;
    end;

    LDstD[0] := 9.0;
    LDispatch^.BatchF64.ArrayAdd(@LSrc1[0], @LSrc2[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 9.0) < 1e-15, 'F64 Add count=0 leaves dst');
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF64_SqrtBroadcastReduce_Parity;
var
  LSrc, LSrc2, LDstS, LDstD: array[0..64] of Double;
  LCount: SizeUInt;
  LCounts: array[0..5] of SizeUInt = (0, 1, 2, 3, 8, 33);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LSavedMask: TFPUExceptionMask;
  eBits, aBits: UInt64;
  LScalar: Double;
  LSumS, LSumD, LDotS, LDotD, LMinS, LMinD, LMaxS, LMaxD: Double;
  LAbsDiff, LScale: Double;
begin
  { Wave C4b: Sqrt/MulScalar/AddScalar bit-parity; Reduce* near/bit as F32. }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LDispatch := GetDispatchTable;
    LScalar := 2.5;
    for i := 0 to 64 do
    begin
      LSrc[i] := Double(i) * 0.25 + 0.01; { non-negative for sqrt }
      LSrc2[i] := Double(i) * 0.13 - 1.5;
    end;

    for ci := 0 to High(LCounts) do
    begin
      LCount := LCounts[ci];
      if LCount > 65 then
        LCount := 65;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArraySqrtF64(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArraySqrt(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 Sqrt parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayMulScalarF64(@LSrc2[0], @LDstS[0], LCount, LScalar);
      LDispatch^.BatchF64.ArrayMulScalar(@LSrc2[0], @LDstD[0], LCount, LScalar);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 MulScalar parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayAddScalarF64(@LSrc2[0], @LDstS[0], LCount, LScalar);
      LDispatch^.BatchF64.ArrayAddScalar(@LSrc2[0], @LDstD[0], LCount, LScalar);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 AddScalar parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      LSumS := ScalarReduceSumF64(@LSrc2[0], LCount);
      LSumD := LDispatch^.BatchF64.ReduceSum(@LSrc2[0], LCount);
      if LCount <= 1 then
      begin
        eBits := PUInt64(@LSumS)^;
        aBits := PUInt64(@LSumD)^;
        CheckEqual(eBits, aBits, 'F64 ReduceSum bit parity count=' + IntToStr(LCount));
      end
      else
      begin
        LAbsDiff := Abs(LSumS - LSumD);
        LScale := Abs(LSumS);
        if LScale < 1.0 then
          LScale := 1.0;
        CheckTrue(LAbsDiff <= 1e-12 * LScale + 1e-14,
          'F64 ReduceSum near parity count=' + IntToStr(LCount));
      end;

      LDotS := ScalarReduceDotF64(@LSrc[0], @LSrc2[0], LCount);
      LDotD := LDispatch^.BatchF64.ReduceDot(@LSrc[0], @LSrc2[0], LCount);
      if LCount <= 1 then
      begin
        eBits := PUInt64(@LDotS)^;
        aBits := PUInt64(@LDotD)^;
        CheckEqual(eBits, aBits, 'F64 ReduceDot bit parity count=' + IntToStr(LCount));
      end
      else
      begin
        LAbsDiff := Abs(LDotS - LDotD);
        LScale := Abs(LDotS);
        if LScale < 1.0 then
          LScale := 1.0;
        CheckTrue(LAbsDiff <= 1e-12 * LScale + 1e-14,
          'F64 ReduceDot near parity count=' + IntToStr(LCount));
      end;

      LMinS := ScalarReduceMinF64(@LSrc2[0], LCount);
      LMinD := LDispatch^.BatchF64.ReduceMin(@LSrc2[0], LCount);
      eBits := PUInt64(@LMinS)^;
      aBits := PUInt64(@LMinD)^;
      CheckEqual(eBits, aBits, 'F64 ReduceMin parity count=' + IntToStr(LCount));

      LMaxS := ScalarReduceMaxF64(@LSrc2[0], LCount);
      LMaxD := LDispatch^.BatchF64.ReduceMax(@LSrc2[0], LCount);
      eBits := PUInt64(@LMaxS)^;
      aBits := PUInt64(@LMaxD)^;
      CheckEqual(eBits, aBits, 'F64 ReduceMax parity count=' + IntToStr(LCount));
    end;

    LDstD[0] := 11.0;
    LDispatch^.BatchF64.ArraySqrt(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 11.0) < 1e-15, 'F64 Sqrt count=0 leaves dst');
    LDispatch^.BatchF64.ArrayMulScalar(@LSrc[0], @LDstD[0], 0, LScalar);
    CheckTrue(Abs(LDstD[0] - 11.0) < 1e-15, 'F64 MulScalar count=0 leaves dst');
    CheckTrue(Abs(LDispatch^.BatchF64.ReduceSum(@LSrc[0], 0)) < 1e-15, 'F64 ReduceSum count=0 is 0');
    CheckTrue(Abs(LDispatch^.BatchF64.ReduceDot(@LSrc[0], @LSrc2[0], 0)) < 1e-15, 'F64 ReduceDot count=0 is 0');
    CheckTrue(Abs(LDispatch^.BatchF64.ReduceMin(@LSrc[0], 0)) < 1e-15, 'F64 ReduceMin count=0 is 0');
    CheckTrue(Abs(LDispatch^.BatchF64.ReduceMax(@LSrc[0], 0)) < 1e-15, 'F64 ReduceMax count=0 is 0');
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF64_LinearClampLerpFmaAxpy_Parity;
var
  LSrc, LStart, LEnd, LA, LB, LC, LDstS, LDstD: array[0..64] of Double;
  LCount: SizeUInt;
  LCounts: array[0..5] of SizeUInt = (0, 1, 2, 3, 8, 33);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LSavedMask: TFPUExceptionMask;
  eBits, aBits: UInt64;
  LScale, LBias, LMin, LMax, LT, LAlpha: Double;
begin
  { Wave C4c: Linear/Clamp/Lerp/Fma/Axpy vs scalar bit parity. }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LDispatch := GetDispatchTable;
    LScale := 1.5;
    LBias := -0.25;
    LMin := -2.0;
    LMax := 3.0;
    LT := 0.5;
    LAlpha := 2.0;
    for i := 0 to 64 do
    begin
      LSrc[i] := Double(i) * 0.31 - 4.0;
      LStart[i] := Double(i) * 0.1;
      LEnd[i] := Double(i) * 0.1 + 5.0;
      LA[i] := Double(i) * 0.07 - 1.0;
      LB[i] := Double(i) * 0.03 + 0.5;
      LC[i] := Double(i) * 0.02 - 0.25;
    end;

    for ci := 0 to High(LCounts) do
    begin
      LCount := LCounts[ci];
      if LCount > 65 then
        LCount := 65;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayLinearF64(@LSrc[0], @LDstS[0], LCount, LScale, LBias);
      LDispatch^.BatchF64.ArrayLinear(@LSrc[0], @LDstD[0], LCount, LScale, LBias);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 Linear parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayClampF64(@LSrc[0], @LDstS[0], LCount, LMin, LMax);
      LDispatch^.BatchF64.ArrayClamp(@LSrc[0], @LDstD[0], LCount, LMin, LMax);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 Clamp parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayLerpF64(@LStart[0], @LEnd[0], @LDstS[0], LCount, LT);
      LDispatch^.BatchF64.ArrayLerp(@LStart[0], @LEnd[0], @LDstD[0], LCount, LT);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 Lerp parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayFmaF64(@LA[0], @LB[0], @LC[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArrayFma(@LA[0], @LB[0], @LC[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 Fma parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayAxpyF64(LAlpha, @LA[0], @LB[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArrayAxpy(LAlpha, @LA[0], @LB[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 Axpy parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;
    end;

    LDstD[0] := 13.0;
    LDispatch^.BatchF64.ArrayLinear(@LSrc[0], @LDstD[0], 0, LScale, LBias);
    CheckTrue(Abs(LDstD[0] - 13.0) < 1e-15, 'F64 Linear count=0 leaves dst');
    LDispatch^.BatchF64.ArrayClamp(@LSrc[0], @LDstD[0], 0, LMin, LMax);
    CheckTrue(Abs(LDstD[0] - 13.0) < 1e-15, 'F64 Clamp count=0 leaves dst');
    LDispatch^.BatchF64.ArrayLerp(@LStart[0], @LEnd[0], @LDstD[0], 0, LT);
    CheckTrue(Abs(LDstD[0] - 13.0) < 1e-15, 'F64 Lerp count=0 leaves dst');
    LDispatch^.BatchF64.ArrayFma(@LA[0], @LB[0], @LC[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 13.0) < 1e-15, 'F64 Fma count=0 leaves dst');
    LDispatch^.BatchF64.ArrayAxpy(LAlpha, @LA[0], @LB[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 13.0) < 1e-15, 'F64 Axpy count=0 leaves dst');
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF64_CeilFloorTruncReLUAbsDiff_Parity;
var
  LSrc, LSrc2, LDstS, LDstD: array[0..64] of Double;
  LCount: SizeUInt;
  LCounts: array[0..5] of SizeUInt = (0, 1, 2, 3, 8, 33);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LSavedMask: TFPUExceptionMask;
  eBits, aBits: UInt64;
begin
  { Wave C4d: Ceil/Floor/Trunc/ReLU/AbsDiff vs scalar bit parity. }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LDispatch := GetDispatchTable;
    for i := 0 to 64 do
    begin
      LSrc[i] := Double(i) * 0.37 - 5.5; { negatives + halves for rounding }
      LSrc2[i] := Double(i) * 0.19 - 2.25;
    end;

    for ci := 0 to High(LCounts) do
    begin
      LCount := LCounts[ci];
      if LCount > 65 then
        LCount := 65;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayCeilF64(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArrayCeil(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 Ceil parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayFloorF64(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArrayFloor(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 Floor parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayTruncF64(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArrayTrunc(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 Trunc parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayReLUF64(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArrayReLU(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 ReLU parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayAbsDiffF64(@LSrc[0], @LSrc2[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArrayAbsDiff(@LSrc[0], @LSrc2[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 AbsDiff parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;
    end;

    LDstD[0] := 17.0;
    LDispatch^.BatchF64.ArrayCeil(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 17.0) < 1e-15, 'F64 Ceil count=0 leaves dst');
    LDispatch^.BatchF64.ArrayFloor(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 17.0) < 1e-15, 'F64 Floor count=0 leaves dst');
    LDispatch^.BatchF64.ArrayTrunc(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 17.0) < 1e-15, 'F64 Trunc count=0 leaves dst');
    LDispatch^.BatchF64.ArrayReLU(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 17.0) < 1e-15, 'F64 ReLU count=0 leaves dst');
    LDispatch^.BatchF64.ArrayAbsDiff(@LSrc[0], @LSrc2[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 17.0) < 1e-15, 'F64 AbsDiff count=0 leaves dst');
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF64_RcpRsqrtRefine_Parity;
var
  LSrc, LDstS, LDstD: array[0..64] of Double;
  LCount: SizeUInt;
  LCounts: array[0..5] of SizeUInt = (0, 1, 2, 3, 8, 33);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LSavedMask: TFPUExceptionMask;
  eBits, aBits: UInt64;
begin
  { Wave C4e: Rcp/Rsqrt/RcpRefine/RsqrtRefine exact fdiv/fsqrt vs scalar bit parity. }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LDispatch := GetDispatchTable;
    for i := 0 to 64 do
      LSrc[i] := Double(i) * 0.25 + 0.05; { positive non-zero for rcp/rsqrt }

    for ci := 0 to High(LCounts) do
    begin
      LCount := LCounts[ci];
      if LCount > 65 then
        LCount := 65;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayRcpF64(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArrayRcp(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 Rcp parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayRsqrtF64(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArrayRsqrt(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 Rsqrt parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayRcpRefineF64(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArrayRcpRefine(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 RcpRefine parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayRsqrtRefineF64(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArrayRsqrtRefine(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        eBits := PUInt64(@LDstS[i])^;
        aBits := PUInt64(@LDstD[i])^;
        CheckEqual(eBits, aBits, 'F64 RsqrtRefine parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;
    end;

    LDstD[0] := 19.0;
    LDispatch^.BatchF64.ArrayRcp(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 19.0) < 1e-15, 'F64 Rcp count=0 leaves dst');
    LDispatch^.BatchF64.ArrayRsqrt(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 19.0) < 1e-15, 'F64 Rsqrt count=0 leaves dst');
    LDispatch^.BatchF64.ArrayRcpRefine(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 19.0) < 1e-15, 'F64 RcpRefine count=0 leaves dst');
    LDispatch^.BatchF64.ArrayRsqrtRefine(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 19.0) < 1e-15, 'F64 RsqrtRefine count=0 leaves dst');
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF32_ArraySinExp_NearParity;
var
  LSrc, LExpSrc, LDstS, LDstD: array[0..64] of Single;
  LCount: SizeUInt;
  LCounts: array[0..5] of SizeUInt = (0, 1, 4, 7, 16, 33);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LSavedMask: TFPUExceptionMask;
  LAbsDiff, LScale, LTol: Single;
begin
  { Wave C5: Sin/Exp near-parity vs scalar (Cody-Waite poly; not bit-equal). }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LDispatch := GetDispatchTable;
    for i := 0 to 64 do
    begin
      LSrc[i] := Single(i) * 0.35 - 8.0; { multi-quadrant sin }
      LExpSrc[i] := Single(i) * 0.5 - 12.0; { moderate exp domain }
      if LExpSrc[i] > 20.0 then
        LExpSrc[i] := 20.0
      else if LExpSrc[i] < -20.0 then
        LExpSrc[i] := -20.0;
    end;

    for ci := 0 to High(LCounts) do
    begin
      LCount := LCounts[ci];
      if LCount > 65 then
        LCount := 65;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArraySinF32(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF32.ArraySin(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        LAbsDiff := Abs(LDstS[i] - LDstD[i]);
        LScale := Abs(LDstS[i]);
        if LScale < 1.0 then
          LScale := 1.0;
        LTol := 1e-5 * LScale + 1e-6;
        if LTol < 8.0 * 1.2e-7 * LScale then
          LTol := 8.0 * 1.2e-7 * LScale + 1e-6;
        CheckTrue(LAbsDiff <= LTol,
          'F32 Sin near parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayExpF32(@LExpSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF32.ArrayExp(@LExpSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        LAbsDiff := Abs(LDstS[i] - LDstD[i]);
        LScale := Abs(LDstS[i]);
        if LScale < 1.0 then
          LScale := 1.0;
        LTol := 1e-4 * LScale + 1e-5;
        CheckTrue(LAbsDiff <= LTol,
          'F32 Exp near parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;
    end;

    LDstD[0] := 21.0;
    LDispatch^.BatchF32.ArraySin(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 21.0) < 1e-6, 'F32 Sin count=0 leaves dst');
    LDispatch^.BatchF32.ArrayExp(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 21.0) < 1e-6, 'F32 Exp count=0 leaves dst');
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF32_ArrayTan_ChunkBoundary_NearParity;
const
  CMaxCount = 1027;
var
  LSrc, LDstS, LDstD: array[0..CMaxCount - 1] of Single;
  LCounts: array[0..7] of SizeUInt = (0, 1, 7, 8, 511, 512, 513, 1027);
  LBackends: array[0..1] of TSimdBackend = (sbSSE2, sbAVX2);
  LCount: SizeUInt;
  bi, ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LSavedMask: TFPUExceptionMask;
  LAbsDiff, LScale, LTol: Single;
  LForcedAny: Boolean;

  procedure CheckTanParity(const aLabel: string; aCount: SizeUInt);
  var
    j: Integer;
  begin
    FillChar(LDstS, SizeOf(LDstS), 0);
    FillChar(LDstD, SizeOf(LDstD), 0);
    ScalarArrayTanF32(@LSrc[0], @LDstS[0], aCount);
    LDispatch^.BatchF32.ArrayTan(@LSrc[0], @LDstD[0], aCount);
    for j := 0 to Integer(aCount) - 1 do
    begin
      LAbsDiff := Abs(LDstS[j] - LDstD[j]);
      LScale := Abs(LDstS[j]);
      if LScale < 1.0 then
        LScale := 1.0;
      LTol := 1e-4 * LScale + 1e-5;
      CheckTrue(LAbsDiff <= LTol,
        'Tan chunk parity ' + aLabel + ' count=' + IntToStr(aCount) + ' i=' + IntToStr(j));
    end;
  end;
begin
  { M3.1: Tan leaves use fixed 512-element stack scratch; verify element parity
    vs scalar across the chunk boundary. Domain avoids tan poles so the
    near-parity tolerance stays bounded. }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    for i := 0 to CMaxCount - 1 do
      LSrc[i] := ((i mod 101) - 50) * 0.025; { [-1.25, 1.25]; |tan| <= ~3.1 }

    LForcedAny := False;
    for bi := 0 to High(LBackends) do
    begin
      if not TrySetActiveBackend(LBackends[bi]) then
        Continue;
      LForcedAny := True;
      LDispatch := GetDispatchTable;

      for ci := 0 to High(LCounts) do
        CheckTanParity(DispatchApiBackendName(LBackends[bi]), LCounts[ci]);

      LDstD[0] := 21.0;
      LDispatch^.BatchF32.ArrayTan(@LSrc[0], @LDstD[0], 0);
      CheckTrue(Abs(LDstD[0] - 21.0) < 1e-6,
        'Tan count=0 leaves dst backend=' + DispatchApiBackendName(LBackends[bi]));
    end;

    if not LForcedAny then
    begin
      { Hosts without SSE2/AVX2 (e.g. AArch64): still exercise the active
        backend across the chunk boundary. }
      LDispatch := GetDispatchTable;
      for ci := 0 to High(LCounts) do
        CheckTanParity('active', LCounts[ci]);
    end;
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_ArrayTanF32_NoHeapScratch_SourceAudit;
var
  LSourceLines: TSourceLines;

  function ExtractProcedureSource(const aPath, aName: string): string;
  var
    LLine: string;
    LIndexLocal: Integer;
    LFound: Boolean;
  begin
    Result := '';
    LFound := False;
    LSourceLines.LoadFromFile(aPath);
    for LIndexLocal := 0 to LSourceLines.Count - 1 do
    begin
      LLine := TrimLeft(LSourceLines[LIndexLocal]);
      if not LFound then
      begin
        if Pos('procedure ' + aName + '(', LLine) = 1 then
          LFound := True
        else
          Continue;
      end
      else if (Pos('procedure ', LLine) = 1) or (Pos('function ', LLine) = 1) then
        Break;

      if Result <> '' then
        Result := Result + LineEnding;
      Result := Result + LSourceLines[LIndexLocal];
    end;

    CheckTrue(LFound, 'Unable to locate procedure source for ' + aName);
    CheckTrue(Pos('begin', LowerCase(Result)) > 0, 'Unable to locate implementation body for ' + aName);
  end;

  procedure CheckHeapFree(const aRelPath, aName: string);
  var
    LPath, LBody: string;
  begin
    LPath := ExpandSimdRepoPath(aRelPath);
    CheckTrue(FileExists(LPath), 'Tan source file should exist for heap-scratch audit: ' + LPath);
    LBody := LowerCase(ExtractProcedureSource(LPath, aName));
    CheckTrue(Pos('getmem', LBody) = 0, aName + ' must not allocate heap scratch (F-003: fixed stack chunking)');
    CheckTrue(Pos('freemem', LBody) = 0, aName + ' must not free heap scratch (F-003: fixed stack chunking)');
    CheckTrue(Pos('ctanscratchelems', LBody) > 0, aName + ' should use the named fixed stack scratch constant');
  end;
begin
  { M3.1 source contract: Tan leaves stay heap-free (chunked stack scratch). }
  LSourceLines := TSourceLines.Create;
  try
    CheckHeapFree('src/nextpas.core.simd.avx2.batch.inc', 'AVX2ArrayTanF32');
    CheckHeapFree('src/nextpas.core.simd.sse2.batch.inc', 'SSE2ArrayTanF32');
  finally
    LSourceLines.Free;
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF32_ArrayCosSinCos_NearParity;
var
  LSrc, LDstS, LDstD, LSinS, LSinD, LCosS, LCosD: array[0..64] of Single;
  LCount: SizeUInt;
  LCounts: array[0..5] of SizeUInt = (0, 1, 4, 7, 16, 33);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LSavedMask: TFPUExceptionMask;
  LAbsDiff, LScale, LTol: Single;
begin
  { Wave C5b: Cos / SinCos near-parity vs scalar. }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LDispatch := GetDispatchTable;
    for i := 0 to 64 do
      LSrc[i] := Single(i) * 0.41 - 9.0;

    for ci := 0 to High(LCounts) do
    begin
      LCount := LCounts[ci];
      if LCount > 65 then
        LCount := 65;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayCosF32(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF32.ArrayCos(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        LAbsDiff := Abs(LDstS[i] - LDstD[i]);
        LScale := Abs(LDstS[i]);
        if LScale < 1.0 then
          LScale := 1.0;
        LTol := 1e-5 * LScale + 1e-6;
        CheckTrue(LAbsDiff <= LTol,
          'F32 Cos near parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LSinS, SizeOf(LSinS), 0);
      FillChar(LCosS, SizeOf(LCosS), 0);
      FillChar(LSinD, SizeOf(LSinD), 0);
      FillChar(LCosD, SizeOf(LCosD), 0);
      ScalarArraySinCosF32(@LSrc[0], @LSinS[0], @LCosS[0], LCount);
      LDispatch^.BatchF32.ArraySinCos(@LSrc[0], @LSinD[0], @LCosD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        LAbsDiff := Abs(LSinS[i] - LSinD[i]);
        LScale := Abs(LSinS[i]);
        if LScale < 1.0 then
          LScale := 1.0;
        LTol := 1e-5 * LScale + 1e-6;
        CheckTrue(LAbsDiff <= LTol,
          'F32 SinCos.sin near parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
        LAbsDiff := Abs(LCosS[i] - LCosD[i]);
        LScale := Abs(LCosS[i]);
        if LScale < 1.0 then
          LScale := 1.0;
        LTol := 1e-5 * LScale + 1e-6;
        CheckTrue(LAbsDiff <= LTol,
          'F32 SinCos.cos near parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;
    end;

    LDstD[0] := 23.0;
    LSinD[0] := 24.0;
    LCosD[0] := 25.0;
    LDispatch^.BatchF32.ArrayCos(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 23.0) < 1e-6, 'F32 Cos count=0 leaves dst');
    LDispatch^.BatchF32.ArraySinCos(@LSrc[0], @LSinD[0], @LCosD[0], 0);
    CheckTrue(Abs(LSinD[0] - 24.0) < 1e-6, 'F32 SinCos count=0 leaves sin dst');
    CheckTrue(Abs(LCosD[0] - 25.0) < 1e-6, 'F32 SinCos count=0 leaves cos dst');
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF32_ArrayLogFamily_NearParity;
var
  LSrc, LDstS, LDstD: array[0..64] of Single;
  LCount: SizeUInt;
  LCounts: array[0..5] of SizeUInt = (0, 1, 4, 7, 16, 33);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LSavedMask: TFPUExceptionMask;
  LAbsDiff, LScale, LTol: Single;
begin
  { Wave C5c: Log/Log2/Log10 near-parity vs scalar; positive inputs only. }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LDispatch := GetDispatchTable;
    for i := 0 to 64 do
      LSrc[i] := Single(i) * 0.37 + 0.05; { (0.05 .. ~24) all positive }

    for ci := 0 to High(LCounts) do
    begin
      LCount := LCounts[ci];
      if LCount > 65 then
        LCount := 65;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayLogF32(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF32.ArrayLog(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        LAbsDiff := Abs(LDstS[i] - LDstD[i]);
        LScale := Abs(LDstS[i]);
        if LScale < 1.0 then
          LScale := 1.0;
        LTol := 1e-5 * LScale + 1e-6;
        CheckTrue(LAbsDiff <= LTol,
          'F32 Log near parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayLog2F32(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF32.ArrayLog2(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        LAbsDiff := Abs(LDstS[i] - LDstD[i]);
        LScale := Abs(LDstS[i]);
        if LScale < 1.0 then
          LScale := 1.0;
        LTol := 1e-4 * LScale + 1e-5;
        CheckTrue(LAbsDiff <= LTol,
          'F32 Log2 near parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayLog10F32(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF32.ArrayLog10(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        LAbsDiff := Abs(LDstS[i] - LDstD[i]);
        LScale := Abs(LDstS[i]);
        if LScale < 1.0 then
          LScale := 1.0;
        LTol := 1e-4 * LScale + 1e-5;
        CheckTrue(LAbsDiff <= LTol,
          'F32 Log10 near parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;
    end;

    LDstD[0] := 27.0;
    LDispatch^.BatchF32.ArrayLog(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 27.0) < 1e-6, 'F32 Log count=0 leaves dst');
    LDispatch^.BatchF32.ArrayLog2(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 27.0) < 1e-6, 'F32 Log2 count=0 leaves dst');
    LDispatch^.BatchF32.ArrayLog10(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 27.0) < 1e-6, 'F32 Log10 count=0 leaves dst');
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

procedure TTestCase_DispatchAPIBatchParity.Test_BatchF64_ArraySinExp_NearParity;
var
  LSrc, LExpSrc, LDstS, LDstD: array[0..64] of Double;
  LCount: SizeUInt;
  LCounts: array[0..5] of SizeUInt = (0, 1, 2, 3, 8, 33);
  ci, i: Integer;
  LDispatch: PSimdDispatchTable;
  LSavedMask: TFPUExceptionMask;
  LAbsDiff, LScale, LTol: Double;
begin
  { Wave C5d: F64 Sin/Exp near-parity vs scalar. }
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LDispatch := GetDispatchTable;
    for i := 0 to 64 do
    begin
      LSrc[i] := Double(i) * 0.35 - 8.0;
      LExpSrc[i] := Double(i) * 0.4 - 10.0;
      if LExpSrc[i] > 20.0 then
        LExpSrc[i] := 20.0
      else if LExpSrc[i] < -20.0 then
        LExpSrc[i] := -20.0;
    end;

    for ci := 0 to High(LCounts) do
    begin
      LCount := LCounts[ci];
      if LCount > 65 then
        LCount := 65;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArraySinF64(@LSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArraySin(@LSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        LAbsDiff := Abs(LDstS[i] - LDstD[i]);
        LScale := Abs(LDstS[i]);
        if LScale < 1.0 then
          LScale := 1.0;
        LTol := 1e-10 * LScale + 1e-12;
        CheckTrue(LAbsDiff <= LTol,
          'F64 Sin near parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;

      FillChar(LDstS, SizeOf(LDstS), 0);
      FillChar(LDstD, SizeOf(LDstD), 0);
      ScalarArrayExpF64(@LExpSrc[0], @LDstS[0], LCount);
      LDispatch^.BatchF64.ArrayExp(@LExpSrc[0], @LDstD[0], LCount);
      for i := 0 to Integer(LCount) - 1 do
      begin
        LAbsDiff := Abs(LDstS[i] - LDstD[i]);
        LScale := Abs(LDstS[i]);
        if LScale < 1.0 then
          LScale := 1.0;
        LTol := 1e-9 * LScale + 1e-12;
        CheckTrue(LAbsDiff <= LTol,
          'F64 Exp near parity count=' + IntToStr(LCount) + ' i=' + IntToStr(i));
      end;
    end;

    LDstD[0] := 29.0;
    LDispatch^.BatchF64.ArraySin(@LSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 29.0) < 1e-15, 'F64 Sin count=0 leaves dst');
    LDispatch^.BatchF64.ArrayExp(@LExpSrc[0], @LDstD[0], 0);
    CheckTrue(Abs(LDstD[0] - 29.0) < 1e-15, 'F64 Exp count=0 leaves dst');
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

end.
