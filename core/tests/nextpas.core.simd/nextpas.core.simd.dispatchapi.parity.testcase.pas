unit nextpas.core.simd.dispatchapi.parity.testcase;

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
  TTestCase_DispatchAPIParity = class(TDispatchAPIStatefulTestCase)
  published
    procedure Test_VecF32x4ReduceFacade_Tracks_CurrentDispatchTable_After_ReRegister;
    procedure Test_VecF64x2ReduceFacade_Tracks_CurrentDispatchTable_After_ReRegister;
    procedure Test_VecF64x2MathFacade_Tracks_CurrentDispatchTable_After_ReRegister;
    procedure Test_VecF32VectorMathFacade_Tracks_CurrentDispatchTable_After_ReRegister;
    procedure Test_VecWideFloatDotFacade_Tracks_CurrentDispatchTable_After_ReRegister;
    procedure Test_VecF32x8ReduceFacade_Tracks_CurrentDispatchTable_After_ReRegister;
    procedure Test_VecF64x4ReduceFacade_Tracks_CurrentDispatchTable_After_ReRegister;
    procedure Test_VecF64x8ReduceFacade_Tracks_CurrentDispatchTable_After_ReRegister;
    procedure Test_VecF32x16ReduceFacade_Tracks_CurrentDispatchTable_After_ReRegister;
    procedure Test_VecI64x2_DispatchAssigned_And_Parity;
    procedure Test_VecU64x2_DispatchAssigned_And_Parity;
    procedure Test_VecU32x8_DispatchAssigned_And_Parity;
    procedure Test_VecF64x4_DispatchAssigned_And_Parity;
    procedure Test_VecI64x4_DispatchAssigned_And_Parity;
    procedure Test_VecU64x4_DispatchAssigned_And_Parity;
    procedure Test_VecI64x8_DispatchAssigned_And_Parity;
    procedure Test_VecF32x16_DispatchAssigned_And_Parity;
    procedure Test_VecF64x8_DispatchAssigned_And_Parity;
    procedure Test_VecU32x16_DispatchAssigned_And_Parity;
    procedure Test_VecU64x8_DispatchAssigned_And_Parity;
    procedure Test_VecI16x32_DispatchAssigned_And_Parity;
    procedure Test_VecI8x64_DispatchAssigned_And_Parity;
    procedure Test_VecU8x64_DispatchAssigned_And_Parity;
    procedure Test_WideFamilies_FacadeScalar_Parity_Completeness;
    procedure Test_CoreFamilies_FacadeScalar_Parity_Completeness_Batch2;
    procedure Test_BacklogParityAndSmoke_Batch3;
    procedure Test_SSE2_I32x4_U32x4_Mul_Use_NonScalar_Impl_And_Keep_Parity;
    procedure Test_SSE2_I64x2_Compare_Use_NonScalar_Impl_And_Keep_Parity;
    procedure Test_SSE2_F32VectorMath_Use_NonScalar_Impl_And_Keep_Parity;
  end;

implementation

function SyntheticReduceAddF64x4CurrentDispatch(const a: TVecF64x4): Double;
begin
  Result := 401.25;
end;

function SyntheticReduceAddF64x2CurrentDispatch(const a: TVecF64x2): Double;
begin
  Result := 77.5;
end;

function SyntheticAbsF64x2CurrentDispatch(const a: TVecF64x2): TVecF64x2;
begin
  Result.d[0] := 17.25;
  Result.d[1] := -23.5;
end;

function SyntheticSqrtF64x2CurrentDispatch(const a: TVecF64x2): TVecF64x2;
begin
  Result.d[0] := 31.75;
  Result.d[1] := 47.125;
end;

function SyntheticMinF64x2CurrentDispatch(const a, b: TVecF64x2): TVecF64x2;
begin
  Result.d[0] := -88.0;
  Result.d[1] := 12.5;
end;

function SyntheticMaxF64x2CurrentDispatch(const a, b: TVecF64x2): TVecF64x2;
begin
  Result.d[0] := 99.875;
  Result.d[1] := -64.25;
end;

function SyntheticReduceMinF64x2CurrentDispatch(const a: TVecF64x2): Double;
begin
  Result := -88.25;
end;

function SyntheticReduceMaxF64x2CurrentDispatch(const a: TVecF64x2): Double;
begin
  Result := 909.5;
end;

function SyntheticReduceMulF64x2CurrentDispatch(const a: TVecF64x2): Double;
begin
  Result := -12.75;
end;

function SyntheticReduceMinF32x4CurrentDispatch(const a: TVecF32x4): Single;
begin
  Result := -314.5;
end;

function SyntheticReduceMaxF32x4CurrentDispatch(const a: TVecF32x4): Single;
begin
  Result := 271.75;
end;

function SyntheticReduceMulF32x4CurrentDispatch(const a: TVecF32x4): Single;
begin
  Result := -9.5;
end;

function SyntheticReduceAddF32x8CurrentDispatch(const a: TVecF32x8): Single;
begin
  Result := 123.5;
end;

function SyntheticReduceMinF32x8CurrentDispatch(const a: TVecF32x8): Single;
begin
  Result := -456.75;
end;

function SyntheticReduceMaxF32x8CurrentDispatch(const a: TVecF32x8): Single;
begin
  Result := 789.125;
end;

function SyntheticReduceMulF32x8CurrentDispatch(const a: TVecF32x8): Single;
begin
  Result := -33.25;
end;

function SyntheticReduceMinF64x4CurrentDispatch(const a: TVecF64x4): Double;
begin
  Result := -222.5;
end;

function SyntheticReduceMaxF64x4CurrentDispatch(const a: TVecF64x4): Double;
begin
  Result := 909.75;
end;

function SyntheticReduceMulF64x4CurrentDispatch(const a: TVecF64x4): Double;
begin
  Result := -17.0;
end;

function SyntheticReduceAddF64x8CurrentDispatch(const a: TVecF64x8): Double;
begin
  Result := 615.875;
end;

function SyntheticReduceMinF64x8CurrentDispatch(const a: TVecF64x8): Double;
begin
  Result := -712.5;
end;

function SyntheticReduceMaxF64x8CurrentDispatch(const a: TVecF64x8): Double;
begin
  Result := 1337.25;
end;

function SyntheticReduceMulF64x8CurrentDispatch(const a: TVecF64x8): Double;
begin
  Result := -91.5;
end;

function SyntheticReduceAddF32x16CurrentDispatch(const a: TVecF32x16): Single;
begin
  Result := 2048.5;
end;

function SyntheticReduceMinF32x16CurrentDispatch(const a: TVecF32x16): Single;
begin
  Result := -1024.25;
end;

function SyntheticReduceMaxF32x16CurrentDispatch(const a: TVecF32x16): Single;
begin
  Result := 4096.75;
end;

function SyntheticReduceMulF32x16CurrentDispatch(const a: TVecF32x16): Single;
begin
  Result := -256.5;
end;

function SyntheticDotF32x4CurrentDispatch(const a, b: TVecF32x4): Single;
begin
  Result := 37.125;
end;

function SyntheticDotF32x3CurrentDispatch(const a, b: TVecF32x4): Single;
begin
  Result := -18.75;
end;

function SyntheticLengthF32x4CurrentDispatch(const a: TVecF32x4): Single;
begin
  Result := 99.5;
end;

function SyntheticLengthF32x3CurrentDispatch(const a: TVecF32x4): Single;
begin
  Result := 55.25;
end;

function SyntheticNormalizeF32x4CurrentDispatch(const a: TVecF32x4): TVecF32x4;
begin
  Result.f[0] := 10.0;
  Result.f[1] := -20.0;
  Result.f[2] := 30.0;
  Result.f[3] := -40.0;
end;

function SyntheticNormalizeF32x3CurrentDispatch(const a: TVecF32x4): TVecF32x4;
begin
  Result.f[0] := -1.0;
  Result.f[1] := 2.0;
  Result.f[2] := -3.0;
  Result.f[3] := 0.0;
end;

function SyntheticDotF32x8CurrentDispatch(const a, b: TVecF32x8): Single;
begin
  Result := 512.25;
end;

function SyntheticDotF64x2CurrentDispatch(const a, b: TVecF64x2): Double;
begin
  Result := -204.5;
end;

function SyntheticDotF64x4CurrentDispatch(const a, b: TVecF64x4): Double;
begin
  Result := 8192.125;
end;

procedure TTestCase_DispatchAPIParity.Test_VecF32x4ReduceFacade_Tracks_CurrentDispatchTable_After_ReRegister;
var
  LBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LModifiedTable: TSimdDispatchTable;
  LInput: TVecF32x4;
begin
  ResetToAutomaticBackend;
  LBackend := GetCurrentBackend;

  CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable), 'Current backend should be registered for VecF32x4 reduce facade dispatch test');

  LInput.f[0] := 1.25;
  LInput.f[1] := -2.5;
  LInput.f[2] := 3.75;
  LInput.f[3] := -4.125;

  LModifiedTable := LOriginalTable;
  LModifiedTable.CoreVectors.ReduceAddF32x4 := @SyntheticReduceAddF32x4CurrentDispatch;
  LModifiedTable.CoreVectors.ReduceMinF32x4 := @SyntheticReduceMinF32x4CurrentDispatch;
  LModifiedTable.CoreVectors.ReduceMaxF32x4 := @SyntheticReduceMaxF32x4CurrentDispatch;
  LModifiedTable.CoreVectors.ReduceMulF32x4 := @SyntheticReduceMulF32x4CurrentDispatch;
  RegisterBackend(LBackend, LModifiedTable);
  try
    CheckEqual(Ord(LBackend), Ord(GetCurrentBackend), 'Re-registering the current backend should preserve the active backend id for VecF32x4 reduce facade dispatch test');
    CheckNear(42.25, GetDispatchTable^.CoreVectors.ReduceAddF32x4(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceAddF32x4 after re-register');
    CheckNear(-314.5, GetDispatchTable^.CoreVectors.ReduceMinF32x4(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceMinF32x4 after re-register');
    CheckNear(271.75, GetDispatchTable^.CoreVectors.ReduceMaxF32x4(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceMaxF32x4 after re-register');
    CheckNear(-9.5, GetDispatchTable^.CoreVectors.ReduceMulF32x4(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceMulF32x4 after re-register');

    CheckNear(42.25, VecF32x4ReduceAdd(LInput), 0.0, 'VecF32x4ReduceAdd should track current dispatch table after re-register');
    CheckNear(-314.5, VecF32x4ReduceMin(LInput), 0.0, 'VecF32x4ReduceMin should track current dispatch table after re-register');
    CheckNear(271.75, VecF32x4ReduceMax(LInput), 0.0, 'VecF32x4ReduceMax should track current dispatch table after re-register');
    CheckNear(-9.5, VecF32x4ReduceMul(LInput), 0.0, 'VecF32x4ReduceMul should track current dispatch table after re-register');
  finally
    RegisterBackend(LBackend, LOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIParity.Test_VecF64x2ReduceFacade_Tracks_CurrentDispatchTable_After_ReRegister;
var
  LBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LModifiedTable: TSimdDispatchTable;
  LInput: TVecF64x2;
begin
  ResetToAutomaticBackend;
  LBackend := GetCurrentBackend;

  CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable), 'Current backend should be registered for VecF64x2 reduce facade dispatch test');

  LInput.d[0] := 6.5;
  LInput.d[1] := -1.25;

  LModifiedTable := LOriginalTable;
  LModifiedTable.CoreVectors.ReduceAddF64x2 := @SyntheticReduceAddF64x2CurrentDispatch;
  LModifiedTable.CoreVectors.ReduceMinF64x2 := @SyntheticReduceMinF64x2CurrentDispatch;
  LModifiedTable.CoreVectors.ReduceMaxF64x2 := @SyntheticReduceMaxF64x2CurrentDispatch;
  LModifiedTable.CoreVectors.ReduceMulF64x2 := @SyntheticReduceMulF64x2CurrentDispatch;
  RegisterBackend(LBackend, LModifiedTable);
  try
    CheckEqual(Ord(LBackend), Ord(GetCurrentBackend), 'Re-registering the current backend should preserve the active backend id for VecF64x2 reduce facade dispatch test');
    CheckNear(77.5, GetDispatchTable^.CoreVectors.ReduceAddF64x2(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceAddF64x2 after re-register');
    CheckNear(-88.25, GetDispatchTable^.CoreVectors.ReduceMinF64x2(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceMinF64x2 after re-register');
    CheckNear(909.5, GetDispatchTable^.CoreVectors.ReduceMaxF64x2(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceMaxF64x2 after re-register');
    CheckNear(-12.75, GetDispatchTable^.CoreVectors.ReduceMulF64x2(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceMulF64x2 after re-register');

    CheckNear(77.5, VecF64x2ReduceAdd(LInput), 0.0, 'VecF64x2ReduceAdd should track current dispatch table after re-register');
    CheckNear(-88.25, VecF64x2ReduceMin(LInput), 0.0, 'VecF64x2ReduceMin should track current dispatch table after re-register');
    CheckNear(909.5, VecF64x2ReduceMax(LInput), 0.0, 'VecF64x2ReduceMax should track current dispatch table after re-register');
    CheckNear(-12.75, VecF64x2ReduceMul(LInput), 0.0, 'VecF64x2ReduceMul should track current dispatch table after re-register');
  finally
    RegisterBackend(LBackend, LOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIParity.Test_VecF64x2MathFacade_Tracks_CurrentDispatchTable_After_ReRegister;
var
  LBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LModifiedTable: TSimdDispatchTable;
  LInputA: TVecF64x2;
  LInputB: TVecF64x2;
  LExpected: TVecF64x2;

  procedure AssertVecF64x2Equal(const aOp: string; const aExpected, aActual: TVecF64x2);
  begin
    CheckNear(aExpected.d[0], aActual.d[0], 0.0, aOp + ' lane 0');
    CheckNear(aExpected.d[1], aActual.d[1], 0.0, aOp + ' lane 1');
  end;
begin
  ResetToAutomaticBackend;
  LBackend := GetCurrentBackend;

    CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable), 'Current backend should be registered for VecF64x2 math facade dispatch test');

    LInputA.d[0] := -9.5;
    LInputA.d[1] := 16.0;
    LInputB.d[0] := 4.25;
    LInputB.d[1] := -3.75;

  LModifiedTable := LOriginalTable;
  LModifiedTable.CoreVectors.AbsF64x2 := @SyntheticAbsF64x2CurrentDispatch;
  LModifiedTable.CoreVectors.SqrtF64x2 := @SyntheticSqrtF64x2CurrentDispatch;
  LModifiedTable.CoreVectors.MinF64x2 := @SyntheticMinF64x2CurrentDispatch;
  LModifiedTable.CoreVectors.MaxF64x2 := @SyntheticMaxF64x2CurrentDispatch;
  RegisterBackend(LBackend, LModifiedTable);
  try
    CheckEqual(Ord(LBackend), Ord(GetCurrentBackend), 'Re-registering the current backend should preserve the active backend id for VecF64x2 math facade dispatch test');

    LExpected := GetDispatchTable^.CoreVectors.AbsF64x2(LInputA);
    AssertVecF64x2Equal('Current dispatch table should expose synthetic AbsF64x2 after re-register', SyntheticAbsF64x2CurrentDispatch(LInputA), LExpected);
    AssertVecF64x2Equal('VecF64x2Abs should track current dispatch table after re-register', LExpected, VecF64x2Abs(LInputA));

    LExpected := GetDispatchTable^.CoreVectors.SqrtF64x2(LInputA);
    AssertVecF64x2Equal('Current dispatch table should expose synthetic SqrtF64x2 after re-register', SyntheticSqrtF64x2CurrentDispatch(LInputA), LExpected);
    AssertVecF64x2Equal('VecF64x2Sqrt should track current dispatch table after re-register', LExpected, VecF64x2Sqrt(LInputA));

    LExpected := GetDispatchTable^.CoreVectors.MinF64x2(LInputA, LInputB);
    AssertVecF64x2Equal('Current dispatch table should expose synthetic MinF64x2 after re-register', SyntheticMinF64x2CurrentDispatch(LInputA, LInputB), LExpected);
    AssertVecF64x2Equal('VecF64x2Min should track current dispatch table after re-register', LExpected, VecF64x2Min(LInputA, LInputB));

    LExpected := GetDispatchTable^.CoreVectors.MaxF64x2(LInputA, LInputB);
    AssertVecF64x2Equal('Current dispatch table should expose synthetic MaxF64x2 after re-register', SyntheticMaxF64x2CurrentDispatch(LInputA, LInputB), LExpected);
    AssertVecF64x2Equal('VecF64x2Max should track current dispatch table after re-register', LExpected, VecF64x2Max(LInputA, LInputB));
  finally
    RegisterBackend(LBackend, LOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIParity.Test_VecF32VectorMathFacade_Tracks_CurrentDispatchTable_After_ReRegister;
var
  LBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LModifiedTable: TSimdDispatchTable;
  LInputA: TVecF32x4;
  LInputB: TVecF32x4;
  LExpectedNormalize4: TVecF32x4;
  LExpectedNormalize3: TVecF32x4;
  LActualNormalize4: TVecF32x4;
  LActualNormalize3: TVecF32x4;
  LIndex: Integer;
begin
  ResetToAutomaticBackend;
  LBackend := GetCurrentBackend;

    CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable), 'Current backend should be registered for VecF32 vector math facade dispatch test');

    LInputA.f[0] := 1.5;
    LInputA.f[1] := -2.0;
    LInputA.f[2] := 3.25;
    LInputA.f[3] := -4.5;
    LInputB.f[0] := -5.0;
    LInputB.f[1] := 6.5;
    LInputB.f[2] := -7.75;
    LInputB.f[3] := 8.0;

    LExpectedNormalize4 := SyntheticNormalizeF32x4CurrentDispatch(LInputA);
    LExpectedNormalize3 := SyntheticNormalizeF32x3CurrentDispatch(LInputA);

  LModifiedTable := LOriginalTable;
  LModifiedTable.CoreVectors.DotF32x4 := @SyntheticDotF32x4CurrentDispatch;
  LModifiedTable.CoreVectors.DotF32x3 := @SyntheticDotF32x3CurrentDispatch;
  LModifiedTable.CoreVectors.LengthF32x4 := @SyntheticLengthF32x4CurrentDispatch;
  LModifiedTable.CoreVectors.LengthF32x3 := @SyntheticLengthF32x3CurrentDispatch;
  LModifiedTable.CoreVectors.NormalizeF32x4 := @SyntheticNormalizeF32x4CurrentDispatch;
  LModifiedTable.CoreVectors.NormalizeF32x3 := @SyntheticNormalizeF32x3CurrentDispatch;
  RegisterBackend(LBackend, LModifiedTable);
  try
    CheckEqual(Ord(LBackend), Ord(GetCurrentBackend), 'Re-registering the current backend should preserve the active backend id for VecF32 vector math facade dispatch test');
    CheckNear(37.125, GetDispatchTable^.CoreVectors.DotF32x4(LInputA, LInputB), 0.0, 'Current dispatch table should expose synthetic DotF32x4 after re-register');
    CheckNear(-18.75, GetDispatchTable^.CoreVectors.DotF32x3(LInputA, LInputB), 0.0, 'Current dispatch table should expose synthetic DotF32x3 after re-register');
    CheckNear(99.5, GetDispatchTable^.CoreVectors.LengthF32x4(LInputA), 0.0, 'Current dispatch table should expose synthetic LengthF32x4 after re-register');
    CheckNear(55.25, GetDispatchTable^.CoreVectors.LengthF32x3(LInputA), 0.0, 'Current dispatch table should expose synthetic LengthF32x3 after re-register');

    LActualNormalize4 := GetDispatchTable^.CoreVectors.NormalizeF32x4(LInputA);
    LActualNormalize3 := GetDispatchTable^.CoreVectors.NormalizeF32x3(LInputA);
    for LIndex := 0 to 3 do
    begin
      CheckNear(LExpectedNormalize4.f[LIndex], LActualNormalize4.f[LIndex], 0.0, 'Current dispatch table should expose synthetic NormalizeF32x4 after re-register lane ' + IntToStr(LIndex));
      CheckNear(LExpectedNormalize3.f[LIndex], LActualNormalize3.f[LIndex], 0.0, 'Current dispatch table should expose synthetic NormalizeF32x3 after re-register lane ' + IntToStr(LIndex));
    end;

    CheckNear(37.125, VecF32x4Dot(LInputA, LInputB), 0.0, 'VecF32x4Dot should track current dispatch table after re-register');
    CheckNear(-18.75, VecF32x3Dot(LInputA, LInputB), 0.0, 'VecF32x3Dot should track current dispatch table after re-register');
    CheckNear(99.5, VecF32x4Length(LInputA), 0.0, 'VecF32x4Length should track current dispatch table after re-register');
    CheckNear(55.25, VecF32x3Length(LInputA), 0.0, 'VecF32x3Length should track current dispatch table after re-register');

    LActualNormalize4 := VecF32x4Normalize(LInputA);
    LActualNormalize3 := VecF32x3Normalize(LInputA);
    for LIndex := 0 to 3 do
    begin
      CheckNear(LExpectedNormalize4.f[LIndex], LActualNormalize4.f[LIndex], 0.0, 'VecF32x4Normalize should track current dispatch table after re-register lane ' + IntToStr(LIndex));
      CheckNear(LExpectedNormalize3.f[LIndex], LActualNormalize3.f[LIndex], 0.0, 'VecF32x3Normalize should track current dispatch table after re-register lane ' + IntToStr(LIndex));
    end;
  finally
    RegisterBackend(LBackend, LOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIParity.Test_VecWideFloatDotFacade_Tracks_CurrentDispatchTable_After_ReRegister;
var
  LBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LModifiedTable: TSimdDispatchTable;
  LInputF32x8A: TVecF32x8;
  LInputF32x8B: TVecF32x8;
  LInputF64x2A: TVecF64x2;
  LInputF64x2B: TVecF64x2;
  LInputF64x4A: TVecF64x4;
  LInputF64x4B: TVecF64x4;
begin
  ResetToAutomaticBackend;
  LBackend := GetCurrentBackend;

    CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable), 'Current backend should be registered for wide float dot facade dispatch test');

    LInputF32x8A.f[0] := 1.0;
    LInputF32x8A.f[1] := -2.0;
    LInputF32x8A.f[2] := 3.0;
    LInputF32x8A.f[3] := -4.0;
    LInputF32x8A.f[4] := 5.0;
    LInputF32x8A.f[5] := -6.0;
    LInputF32x8A.f[6] := 7.0;
    LInputF32x8A.f[7] := -8.0;
    LInputF32x8B.f[0] := -1.5;
    LInputF32x8B.f[1] := 2.5;
    LInputF32x8B.f[2] := -3.5;
    LInputF32x8B.f[3] := 4.5;
    LInputF32x8B.f[4] := -5.5;
    LInputF32x8B.f[5] := 6.5;
    LInputF32x8B.f[6] := -7.5;
    LInputF32x8B.f[7] := 8.5;

    LInputF64x2A.d[0] := 10.0;
    LInputF64x2A.d[1] := -20.0;
    LInputF64x2B.d[0] := -30.0;
    LInputF64x2B.d[1] := 40.0;

    LInputF64x4A.d[0] := 1.25;
    LInputF64x4A.d[1] := -2.5;
    LInputF64x4A.d[2] := 3.75;
    LInputF64x4A.d[3] := -4.0;
    LInputF64x4B.d[0] := -5.25;
    LInputF64x4B.d[1] := 6.5;
    LInputF64x4B.d[2] := -7.75;
    LInputF64x4B.d[3] := 8.0;

  LModifiedTable := LOriginalTable;
  LModifiedTable.CoreVectors.DotF32x8 := @SyntheticDotF32x8CurrentDispatch;
  LModifiedTable.CoreVectors.DotF64x2 := @SyntheticDotF64x2CurrentDispatch;
  LModifiedTable.CoreVectors.DotF64x4 := @SyntheticDotF64x4CurrentDispatch;
  RegisterBackend(LBackend, LModifiedTable);
  try
    CheckEqual(Ord(LBackend), Ord(GetCurrentBackend), 'Re-registering the current backend should preserve the active backend id for wide float dot facade dispatch test');
    CheckNear(512.25, GetDispatchTable^.CoreVectors.DotF32x8(LInputF32x8A, LInputF32x8B), 0.0, 'Current dispatch table should expose synthetic DotF32x8 after re-register');
    CheckNear(-204.5, GetDispatchTable^.CoreVectors.DotF64x2(LInputF64x2A, LInputF64x2B), 0.0, 'Current dispatch table should expose synthetic DotF64x2 after re-register');
    CheckNear(8192.125, GetDispatchTable^.CoreVectors.DotF64x4(LInputF64x4A, LInputF64x4B), 0.0, 'Current dispatch table should expose synthetic DotF64x4 after re-register');

    CheckNear(512.25, VecF32x8Dot(LInputF32x8A, LInputF32x8B), 0.0, 'VecF32x8Dot should track current dispatch table after re-register');
    CheckNear(-204.5, VecF64x2Dot(LInputF64x2A, LInputF64x2B), 0.0, 'VecF64x2Dot should track current dispatch table after re-register');
    CheckNear(8192.125, VecF64x4Dot(LInputF64x4A, LInputF64x4B), 0.0, 'VecF64x4Dot should track current dispatch table after re-register');
  finally
    RegisterBackend(LBackend, LOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIParity.Test_VecF64x4ReduceFacade_Tracks_CurrentDispatchTable_After_ReRegister;
var
  LBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LModifiedTable: TSimdDispatchTable;
  LInput: TVecF64x4;
begin
  ResetToAutomaticBackend;
  LBackend := GetCurrentBackend;

    CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable), 'Current backend should be registered for VecF64x4 reduce facade dispatch test');

    LInput.d[0] := 1.5;
    LInput.d[1] := -2.0;
    LInput.d[2] := 3.25;
    LInput.d[3] := -4.75;

  LModifiedTable := LOriginalTable;
  LModifiedTable.CoreVectors.ReduceAddF64x4 := @SyntheticReduceAddF64x4CurrentDispatch;
  LModifiedTable.CoreVectors.ReduceMinF64x4 := @SyntheticReduceMinF64x4CurrentDispatch;
  LModifiedTable.CoreVectors.ReduceMaxF64x4 := @SyntheticReduceMaxF64x4CurrentDispatch;
  LModifiedTable.CoreVectors.ReduceMulF64x4 := @SyntheticReduceMulF64x4CurrentDispatch;
  RegisterBackend(LBackend, LModifiedTable);
  try
    CheckEqual(Ord(LBackend), Ord(GetCurrentBackend), 'Re-registering the current backend should preserve the active backend id for VecF64x4 reduce facade dispatch test');
    CheckNear(401.25, GetDispatchTable^.CoreVectors.ReduceAddF64x4(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceAddF64x4 after re-register');
    CheckNear(-222.5, GetDispatchTable^.CoreVectors.ReduceMinF64x4(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceMinF64x4 after re-register');
    CheckNear(909.75, GetDispatchTable^.CoreVectors.ReduceMaxF64x4(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceMaxF64x4 after re-register');
    CheckNear(-17.0, GetDispatchTable^.CoreVectors.ReduceMulF64x4(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceMulF64x4 after re-register');

    CheckNear(401.25, VecF64x4ReduceAdd(LInput), 0.0, 'VecF64x4ReduceAdd should track current dispatch table after re-register');
    CheckNear(-222.5, VecF64x4ReduceMin(LInput), 0.0, 'VecF64x4ReduceMin should track current dispatch table after re-register');
    CheckNear(909.75, VecF64x4ReduceMax(LInput), 0.0, 'VecF64x4ReduceMax should track current dispatch table after re-register');
    CheckNear(-17.0, VecF64x4ReduceMul(LInput), 0.0, 'VecF64x4ReduceMul should track current dispatch table after re-register');
  finally
    RegisterBackend(LBackend, LOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIParity.Test_VecF32x8ReduceFacade_Tracks_CurrentDispatchTable_After_ReRegister;
var
  LBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LModifiedTable: TSimdDispatchTable;
  LInput: TVecF32x8;
begin
  ResetToAutomaticBackend;
  LBackend := GetCurrentBackend;

    CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable), 'Current backend should be registered for VecF32x8 reduce facade dispatch test');

    LInput.f[0] := 1.25;
    LInput.f[1] := -2.5;
    LInput.f[2] := 3.75;
    LInput.f[3] := -4.125;
    LInput.f[4] := 5.5;
    LInput.f[5] := -6.75;
    LInput.f[6] := 7.875;
    LInput.f[7] := -8.25;

  LModifiedTable := LOriginalTable;
  LModifiedTable.CoreVectors.ReduceAddF32x8 := @SyntheticReduceAddF32x8CurrentDispatch;
  LModifiedTable.CoreVectors.ReduceMinF32x8 := @SyntheticReduceMinF32x8CurrentDispatch;
  LModifiedTable.CoreVectors.ReduceMaxF32x8 := @SyntheticReduceMaxF32x8CurrentDispatch;
  LModifiedTable.CoreVectors.ReduceMulF32x8 := @SyntheticReduceMulF32x8CurrentDispatch;
  RegisterBackend(LBackend, LModifiedTable);
  try
    CheckEqual(Ord(LBackend), Ord(GetCurrentBackend), 'Re-registering the current backend should preserve the active backend id for VecF32x8 reduce facade dispatch test');
    CheckNear(123.5, GetDispatchTable^.CoreVectors.ReduceAddF32x8(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceAddF32x8 after re-register');
    CheckNear(-456.75, GetDispatchTable^.CoreVectors.ReduceMinF32x8(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceMinF32x8 after re-register');
    CheckNear(789.125, GetDispatchTable^.CoreVectors.ReduceMaxF32x8(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceMaxF32x8 after re-register');
    CheckNear(-33.25, GetDispatchTable^.CoreVectors.ReduceMulF32x8(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceMulF32x8 after re-register');

    CheckNear(123.5, VecF32x8ReduceAdd(LInput), 0.0, 'VecF32x8ReduceAdd should track current dispatch table after re-register');
    CheckNear(-456.75, VecF32x8ReduceMin(LInput), 0.0, 'VecF32x8ReduceMin should track current dispatch table after re-register');
    CheckNear(789.125, VecF32x8ReduceMax(LInput), 0.0, 'VecF32x8ReduceMax should track current dispatch table after re-register');
    CheckNear(-33.25, VecF32x8ReduceMul(LInput), 0.0, 'VecF32x8ReduceMul should track current dispatch table after re-register');
  finally
    RegisterBackend(LBackend, LOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIParity.Test_VecF64x8ReduceFacade_Tracks_CurrentDispatchTable_After_ReRegister;
var
  LBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LModifiedTable: TSimdDispatchTable;
  LInput: TVecF64x8;
begin
  ResetToAutomaticBackend;
  LBackend := GetCurrentBackend;

    CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable), 'Current backend should be registered for VecF64x8 reduce facade dispatch test');

    LInput.d[0] := 1.0;
    LInput.d[1] := -2.0;
    LInput.d[2] := 3.0;
    LInput.d[3] := -4.0;
    LInput.d[4] := 5.0;
    LInput.d[5] := -6.0;
    LInput.d[6] := 7.0;
    LInput.d[7] := -8.0;

  LModifiedTable := LOriginalTable;
  LModifiedTable.CoreVectors.ReduceAddF64x8 := @SyntheticReduceAddF64x8CurrentDispatch;
  LModifiedTable.CoreVectors.ReduceMinF64x8 := @SyntheticReduceMinF64x8CurrentDispatch;
  LModifiedTable.CoreVectors.ReduceMaxF64x8 := @SyntheticReduceMaxF64x8CurrentDispatch;
  LModifiedTable.CoreVectors.ReduceMulF64x8 := @SyntheticReduceMulF64x8CurrentDispatch;
  RegisterBackend(LBackend, LModifiedTable);
  try
    CheckEqual(Ord(LBackend), Ord(GetCurrentBackend), 'Re-registering the current backend should preserve the active backend id for VecF64x8 reduce facade dispatch test');
    CheckNear(615.875, GetDispatchTable^.CoreVectors.ReduceAddF64x8(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceAddF64x8 after re-register');
    CheckNear(-712.5, GetDispatchTable^.CoreVectors.ReduceMinF64x8(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceMinF64x8 after re-register');
    CheckNear(1337.25, GetDispatchTable^.CoreVectors.ReduceMaxF64x8(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceMaxF64x8 after re-register');
    CheckNear(-91.5, GetDispatchTable^.CoreVectors.ReduceMulF64x8(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceMulF64x8 after re-register');

    CheckNear(615.875, VecF64x8ReduceAdd(LInput), 0.0, 'VecF64x8ReduceAdd should track current dispatch table after re-register');
    CheckNear(-712.5, VecF64x8ReduceMin(LInput), 0.0, 'VecF64x8ReduceMin should track current dispatch table after re-register');
    CheckNear(1337.25, VecF64x8ReduceMax(LInput), 0.0, 'VecF64x8ReduceMax should track current dispatch table after re-register');
    CheckNear(-91.5, VecF64x8ReduceMul(LInput), 0.0, 'VecF64x8ReduceMul should track current dispatch table after re-register');
  finally
    RegisterBackend(LBackend, LOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIParity.Test_VecF32x16ReduceFacade_Tracks_CurrentDispatchTable_After_ReRegister;
var
  LBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LModifiedTable: TSimdDispatchTable;
  LInput: TVecF32x16;
begin
  ResetToAutomaticBackend;
  LBackend := GetCurrentBackend;

    CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable), 'Current backend should be registered for VecF32x16 reduce facade dispatch test');

    LInput.f[0] := 1.0;
    LInput.f[1] := -2.0;
    LInput.f[2] := 3.0;
    LInput.f[3] := -4.0;
    LInput.f[4] := 5.0;
    LInput.f[5] := -6.0;
    LInput.f[6] := 7.0;
    LInput.f[7] := -8.0;
    LInput.f[8] := 9.0;
    LInput.f[9] := -10.0;
    LInput.f[10] := 11.0;
    LInput.f[11] := -12.0;
    LInput.f[12] := 13.0;
    LInput.f[13] := -14.0;
    LInput.f[14] := 15.0;
    LInput.f[15] := -16.0;

  LModifiedTable := LOriginalTable;
  LModifiedTable.CoreVectors.ReduceAddF32x16 := @SyntheticReduceAddF32x16CurrentDispatch;
  LModifiedTable.CoreVectors.ReduceMinF32x16 := @SyntheticReduceMinF32x16CurrentDispatch;
  LModifiedTable.CoreVectors.ReduceMaxF32x16 := @SyntheticReduceMaxF32x16CurrentDispatch;
  LModifiedTable.CoreVectors.ReduceMulF32x16 := @SyntheticReduceMulF32x16CurrentDispatch;
  RegisterBackend(LBackend, LModifiedTable);
  try
    CheckEqual(Ord(LBackend), Ord(GetCurrentBackend), 'Re-registering the current backend should preserve the active backend id for VecF32x16 reduce facade dispatch test');
    CheckNear(2048.5, GetDispatchTable^.CoreVectors.ReduceAddF32x16(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceAddF32x16 after re-register');
    CheckNear(-1024.25, GetDispatchTable^.CoreVectors.ReduceMinF32x16(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceMinF32x16 after re-register');
    CheckNear(4096.75, GetDispatchTable^.CoreVectors.ReduceMaxF32x16(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceMaxF32x16 after re-register');
    CheckNear(-256.5, GetDispatchTable^.CoreVectors.ReduceMulF32x16(LInput), 0.0, 'Current dispatch table should expose synthetic ReduceMulF32x16 after re-register');

    CheckNear(2048.5, VecF32x16ReduceAdd(LInput), 0.0, 'VecF32x16ReduceAdd should track current dispatch table after re-register');
    CheckNear(-1024.25, VecF32x16ReduceMin(LInput), 0.0, 'VecF32x16ReduceMin should track current dispatch table after re-register');
    CheckNear(4096.75, VecF32x16ReduceMax(LInput), 0.0, 'VecF32x16ReduceMax should track current dispatch table after re-register');
    CheckNear(-256.5, VecF32x16ReduceMul(LInput), 0.0, 'VecF32x16ReduceMul should track current dispatch table after re-register');
  finally
    RegisterBackend(LBackend, LOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIParity.Test_VecI64x2_DispatchAssigned_And_Parity;
var
  LDispatch: PSimdDispatchTable;
  LA, LB: TVecI64x2;
  LVecByDispatch, LVecByFacade: TVecI64x2;
begin
  LDispatch := GetDispatchTable;
  CheckNotNil(LDispatch, 'Dispatch table should be available');

  CheckTrue(Assigned(LDispatch^.CoreVectors.AndNotI64x2), 'Dispatch.CoreVectors.AndNotI64x2 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.ShiftLeftI64x2), 'Dispatch.CoreVectors.ShiftLeftI64x2 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.ShiftRightI64x2), 'Dispatch.CoreVectors.ShiftRightI64x2 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.ShiftRightArithI64x2), 'Dispatch.CoreVectors.ShiftRightArithI64x2 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.MinI64x2), 'Dispatch.CoreVectors.MinI64x2 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.MaxI64x2), 'Dispatch.CoreVectors.MaxI64x2 should be assigned');

  LA.i[0] := $0F0F0F0F0F0F0F0F;
  LA.i[1] := -16;
  LB.i[0] := $00FF00FF00FF00FF;
  LB.i[1] := 7;

  LVecByDispatch := LDispatch^.CoreVectors.AndNotI64x2(LA, LB);
  LVecByFacade := VecI64x2AndNot(LA, LB);
  CheckEqual(LVecByFacade.i[0], LVecByDispatch.i[0], 'Dispatch/Facade AndNotI64x2 lane0 parity');
  CheckEqual(LVecByFacade.i[1], LVecByDispatch.i[1], 'Dispatch/Facade AndNotI64x2 lane1 parity');

  LVecByDispatch := LDispatch^.CoreVectors.ShiftLeftI64x2(LA, 3);
  LVecByFacade := VecI64x2ShiftLeft(LA, 3);
  CheckEqual(LVecByFacade.i[0], LVecByDispatch.i[0], 'Dispatch/Facade ShiftLeftI64x2 lane0 parity');
  CheckEqual(LVecByFacade.i[1], LVecByDispatch.i[1], 'Dispatch/Facade ShiftLeftI64x2 lane1 parity');

  LVecByDispatch := LDispatch^.CoreVectors.ShiftRightI64x2(LA, 4);
  LVecByFacade := VecI64x2ShiftRight(LA, 4);
  CheckEqual(LVecByFacade.i[0], LVecByDispatch.i[0], 'Dispatch/Facade ShiftRightI64x2 lane0 parity');
  CheckEqual(LVecByFacade.i[1], LVecByDispatch.i[1], 'Dispatch/Facade ShiftRightI64x2 lane1 parity');

  LVecByDispatch := LDispatch^.CoreVectors.ShiftRightArithI64x2(LA, 2);
  LVecByFacade := VecI64x2ShiftRightArith(LA, 2);
  CheckEqual(LVecByFacade.i[0], LVecByDispatch.i[0], 'Dispatch/Facade ShiftRightArithI64x2 lane0 parity');
  CheckEqual(LVecByFacade.i[1], LVecByDispatch.i[1], 'Dispatch/Facade ShiftRightArithI64x2 lane1 parity');

  LVecByDispatch := LDispatch^.CoreVectors.MinI64x2(LA, LB);
  LVecByFacade := VecI64x2Min(LA, LB);
  CheckEqual(LVecByFacade.i[0], LVecByDispatch.i[0], 'Dispatch/Facade MinI64x2 lane0 parity');
  CheckEqual(LVecByFacade.i[1], LVecByDispatch.i[1], 'Dispatch/Facade MinI64x2 lane1 parity');

  LVecByDispatch := LDispatch^.CoreVectors.MaxI64x2(LA, LB);
  LVecByFacade := VecI64x2Max(LA, LB);
  CheckEqual(LVecByFacade.i[0], LVecByDispatch.i[0], 'Dispatch/Facade MaxI64x2 lane0 parity');
  CheckEqual(LVecByFacade.i[1], LVecByDispatch.i[1], 'Dispatch/Facade MaxI64x2 lane1 parity');
end;

procedure TTestCase_DispatchAPIParity.Test_VecU64x2_DispatchAssigned_And_Parity;
var
  LDispatch: PSimdDispatchTable;
  LA, LB: TVecU64x2;
  LMaskByDispatch: TMask2;
  LVecByDispatch, LVecByFacade: TVecU64x2;
begin
  LDispatch := GetDispatchTable;
  CheckNotNil(LDispatch, 'Dispatch table should be available');

  CheckTrue(Assigned(LDispatch^.CoreVectors.AddU64x2), 'Dispatch.CoreVectors.AddU64x2 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.SubU64x2), 'Dispatch.CoreVectors.SubU64x2 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.AndU64x2), 'Dispatch.CoreVectors.AndU64x2 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.OrU64x2), 'Dispatch.CoreVectors.OrU64x2 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.XorU64x2), 'Dispatch.CoreVectors.XorU64x2 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.NotU64x2), 'Dispatch.CoreVectors.NotU64x2 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.AndNotU64x2), 'Dispatch.CoreVectors.AndNotU64x2 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpEqU64x2), 'Dispatch.CoreVectors.CmpEqU64x2 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpLtU64x2), 'Dispatch.CoreVectors.CmpLtU64x2 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpGtU64x2), 'Dispatch.CoreVectors.CmpGtU64x2 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.MinU64x2), 'Dispatch.CoreVectors.MinU64x2 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.MaxU64x2), 'Dispatch.CoreVectors.MaxU64x2 should be assigned');

  LA.u[0] := QWord($F0F0F0F0F0F0F0F0);
  LA.u[1] := 20;
  LB.u[0] := $00FF00FF00FF00FF;
  LB.u[1] := 30;

  LVecByDispatch := LDispatch^.CoreVectors.AddU64x2(LA, LB);
  LVecByFacade := VecU64x2Add(LA, LB);
  CheckEqual(LVecByFacade.u[0], LVecByDispatch.u[0], 'Dispatch/Facade AddU64x2 lane0 parity');
  CheckEqual(LVecByFacade.u[1], LVecByDispatch.u[1], 'Dispatch/Facade AddU64x2 lane1 parity');

  LVecByDispatch := LDispatch^.CoreVectors.AndNotU64x2(LA, LB);
  LVecByFacade := VecU64x2AndNot(LA, LB);
  CheckEqual(LVecByFacade.u[0], LVecByDispatch.u[0], 'Dispatch/Facade AndNotU64x2 lane0 parity');
  CheckEqual(LVecByFacade.u[1], LVecByDispatch.u[1], 'Dispatch/Facade AndNotU64x2 lane1 parity');

  CheckEqual(Integer(VecU64x2CmpEq(LA, LB)), Integer(LDispatch^.CoreVectors.CmpEqU64x2(LA, LB)), 'Dispatch/Facade CmpEqU64x2 parity');
  CheckEqual(Integer(VecU64x2CmpLt(LA, LB)), Integer(LDispatch^.CoreVectors.CmpLtU64x2(LA, LB)), 'Dispatch/Facade CmpLtU64x2 parity');
  CheckEqual(Integer(VecU64x2CmpGt(LA, LB)), Integer(LDispatch^.CoreVectors.CmpGtU64x2(LA, LB)), 'Dispatch/Facade CmpGtU64x2 parity');

  LVecByDispatch := LDispatch^.CoreVectors.MinU64x2(LA, LB);
  LVecByFacade := VecU64x2Min(LA, LB);
  CheckEqual(LVecByFacade.u[0], LVecByDispatch.u[0], 'Dispatch/Facade MinU64x2 lane0 parity');
  CheckEqual(LVecByFacade.u[1], LVecByDispatch.u[1], 'Dispatch/Facade MinU64x2 lane1 parity');

  LVecByDispatch := LDispatch^.CoreVectors.MaxU64x2(LA, LB);
  LVecByFacade := VecU64x2Max(LA, LB);
  CheckEqual(LVecByFacade.u[0], LVecByDispatch.u[0], 'Dispatch/Facade MaxU64x2 lane0 parity');
  CheckEqual(LVecByFacade.u[1], LVecByDispatch.u[1], 'Dispatch/Facade MaxU64x2 lane1 parity');

  // 预期值断言：覆盖无符号比较高位边界（防止符号比较误用）
  LA.u[0] := QWord($FFFFFFFFFFFFFFFF);
  LA.u[1] := 1;
  LB.u[0] := 0;
  LB.u[1] := 2;

  LMaskByDispatch := LDispatch^.CoreVectors.CmpLtU64x2(LA, LB);
  CheckEqual(Integer(TMask2(2)), Integer(LMaskByDispatch), 'Dispatch CmpLtU64x2 expected mask');
  LMaskByDispatch := LDispatch^.CoreVectors.CmpGtU64x2(LA, LB);
  CheckEqual(Integer(TMask2(1)), Integer(LMaskByDispatch), 'Dispatch CmpGtU64x2 expected mask');

  CheckEqual(Integer(TMask2(2)), Integer(VecU64x2CmpLt(LA, LB)), 'Facade CmpLtU64x2 expected mask');
  CheckEqual(Integer(TMask2(1)), Integer(VecU64x2CmpGt(LA, LB)), 'Facade CmpGtU64x2 expected mask');

  LVecByDispatch := LDispatch^.CoreVectors.MinU64x2(LA, LB);
  CheckEqual(QWord(0), LVecByDispatch.u[0], 'Dispatch MinU64x2 expected lane0');
  CheckEqual(QWord(1), LVecByDispatch.u[1], 'Dispatch MinU64x2 expected lane1');

  LVecByDispatch := LDispatch^.CoreVectors.MaxU64x2(LA, LB);
  CheckEqual(QWord($FFFFFFFFFFFFFFFF), LVecByDispatch.u[0], 'Dispatch MaxU64x2 expected lane0');
  CheckEqual(QWord(2), LVecByDispatch.u[1], 'Dispatch MaxU64x2 expected lane1');
end;

procedure TTestCase_DispatchAPIParity.Test_VecU32x8_DispatchAssigned_And_Parity;
var
  LDispatch: PSimdDispatchTable;
  LA, LB: TVecU32x8;
  LMaskByDispatch: TMask8;
  LVecByDispatch, LVecByFacade: TVecU32x8;
begin
  LDispatch := GetDispatchTable;
  CheckNotNil(LDispatch, 'Dispatch table should be available');

  CheckTrue(Assigned(LDispatch^.CoreVectors.AddU32x8), 'Dispatch.CoreVectors.AddU32x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.SubU32x8), 'Dispatch.CoreVectors.SubU32x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.MulU32x8), 'Dispatch.CoreVectors.MulU32x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.AndU32x8), 'Dispatch.CoreVectors.AndU32x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.OrU32x8), 'Dispatch.CoreVectors.OrU32x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.XorU32x8), 'Dispatch.CoreVectors.XorU32x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.NotU32x8), 'Dispatch.CoreVectors.NotU32x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.AndNotU32x8), 'Dispatch.CoreVectors.AndNotU32x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.ShiftLeftU32x8), 'Dispatch.CoreVectors.ShiftLeftU32x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.ShiftRightU32x8), 'Dispatch.CoreVectors.ShiftRightU32x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpEqU32x8), 'Dispatch.CoreVectors.CmpEqU32x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpLtU32x8), 'Dispatch.CoreVectors.CmpLtU32x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpGtU32x8), 'Dispatch.CoreVectors.CmpGtU32x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpLeU32x8), 'Dispatch.CoreVectors.CmpLeU32x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpGeU32x8), 'Dispatch.CoreVectors.CmpGeU32x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpNeU32x8), 'Dispatch.CoreVectors.CmpNeU32x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.MinU32x8), 'Dispatch.CoreVectors.MinU32x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.MaxU32x8), 'Dispatch.CoreVectors.MaxU32x8 should be assigned');

  LA.u[0] := 1;          LB.u[0] := 2;
  LA.u[1] := 3;          LB.u[1] := 4;
  LA.u[2] := $FFFFFFFF;  LB.u[2] := 1;
  LA.u[3] := 9;          LB.u[3] := 9;
  LA.u[4] := 0;          LB.u[4] := 7;
  LA.u[5] := 12;         LB.u[5] := 6;
  LA.u[6] := $80000000;  LB.u[6] := $7FFFFFFF;
  LA.u[7] := 42;         LB.u[7] := 43;

  LVecByDispatch := LDispatch^.CoreVectors.AddU32x8(LA, LB);
  LVecByFacade := VecU32x8Add(LA, LB);
  CheckEqual(LVecByFacade.u[0], LVecByDispatch.u[0], 'Dispatch/Facade AddU32x8 lane0 parity');
  CheckEqual(LVecByFacade.u[1], LVecByDispatch.u[1], 'Dispatch/Facade AddU32x8 lane1 parity');
  CheckEqual(LVecByFacade.u[2], LVecByDispatch.u[2], 'Dispatch/Facade AddU32x8 lane2 parity');
  CheckEqual(LVecByFacade.u[3], LVecByDispatch.u[3], 'Dispatch/Facade AddU32x8 lane3 parity');

  LVecByDispatch := LDispatch^.CoreVectors.AndNotU32x8(LA, LB);
  LVecByFacade := VecU32x8AndNot(LA, LB);
  CheckEqual(LVecByFacade.u[0], LVecByDispatch.u[0], 'Dispatch/Facade AndNotU32x8 lane0 parity');
  CheckEqual(LVecByFacade.u[1], LVecByDispatch.u[1], 'Dispatch/Facade AndNotU32x8 lane1 parity');
  CheckEqual(LVecByFacade.u[2], LVecByDispatch.u[2], 'Dispatch/Facade AndNotU32x8 lane2 parity');
  CheckEqual(LVecByFacade.u[3], LVecByDispatch.u[3], 'Dispatch/Facade AndNotU32x8 lane3 parity');

  LMaskByDispatch := LDispatch^.CoreVectors.CmpNeU32x8(LA, LB);
  CheckEqual(Integer(VecU32x8CmpNe(LA, LB)), Integer(LMaskByDispatch), 'Dispatch/Facade CmpNeU32x8 parity');

  LVecByDispatch := LDispatch^.CoreVectors.MinU32x8(LA, LB);
  LVecByFacade := VecU32x8Min(LA, LB);
  CheckEqual(LVecByFacade.u[0], LVecByDispatch.u[0], 'Dispatch/Facade MinU32x8 lane0 parity');
  CheckEqual(LVecByFacade.u[1], LVecByDispatch.u[1], 'Dispatch/Facade MinU32x8 lane1 parity');

  LVecByDispatch := LDispatch^.CoreVectors.MaxU32x8(LA, LB);
  LVecByFacade := VecU32x8Max(LA, LB);
  CheckEqual(LVecByFacade.u[0], LVecByDispatch.u[0], 'Dispatch/Facade MaxU32x8 lane0 parity');
  CheckEqual(LVecByFacade.u[1], LVecByDispatch.u[1], 'Dispatch/Facade MaxU32x8 lane1 parity');
end;

procedure TTestCase_DispatchAPIParity.Test_VecF64x4_DispatchAssigned_And_Parity;
var
  LDispatch: PSimdDispatchTable;
  LA, LB: TVecF64x4;
  LVecByDispatch, LVecByFacade: TVecF64x4;
  LIndex: Integer;
begin
  LDispatch := GetDispatchTable;
  CheckNotNil(LDispatch, 'Dispatch table should be available');

  CheckTrue(Assigned(LDispatch^.CoreVectors.AddF64x4), 'Dispatch.CoreVectors.AddF64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.SubF64x4), 'Dispatch.CoreVectors.SubF64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.MulF64x4), 'Dispatch.CoreVectors.MulF64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.DivF64x4), 'Dispatch.CoreVectors.DivF64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.RcpF64x4), 'Dispatch.CoreVectors.RcpF64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.AbsF64x4), 'Dispatch.CoreVectors.AbsF64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.SqrtF64x4), 'Dispatch.CoreVectors.SqrtF64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.MinF64x4), 'Dispatch.CoreVectors.MinF64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.MaxF64x4), 'Dispatch.CoreVectors.MaxF64x4 should be assigned');

  LA.d[0] := 2.0;   LB.d[0] := 1.0;
  LA.d[1] := -4.0;  LB.d[1] := 2.0;
  LA.d[2] := 0.5;   LB.d[2] := 8.0;
  LA.d[3] := 16.0;  LB.d[3] := 4.0;

  LVecByDispatch := LDispatch^.CoreVectors.AddF64x4(LA, LB);
  LVecByFacade := VecF64x4Add(LA, LB);
  for LIndex := 0 to 3 do
    CheckNear(LVecByFacade.d[LIndex], LVecByDispatch.d[LIndex], 1e-12, 'Dispatch/Facade AddF64x4 lane parity');

  LVecByDispatch := LDispatch^.CoreVectors.RcpF64x4(LB);
  LVecByFacade := VecF64x4Rcp(LB);
  for LIndex := 0 to 3 do
    CheckNear(LVecByFacade.d[LIndex], LVecByDispatch.d[LIndex], 1e-12, 'Dispatch/Facade RcpF64x4 lane parity');

  LVecByDispatch := LDispatch^.CoreVectors.MinF64x4(LA, LB);
  LVecByFacade := VecF64x4Min(LA, LB);
  for LIndex := 0 to 3 do
    CheckNear(LVecByFacade.d[LIndex], LVecByDispatch.d[LIndex], 1e-12, 'Dispatch/Facade MinF64x4 lane parity');
end;

procedure TTestCase_DispatchAPIParity.Test_VecI64x4_DispatchAssigned_And_Parity;
var
  LDispatch: PSimdDispatchTable;
  LA, LB: TVecI64x4;
  LMaskByDispatch: TMask4;
  LVecByDispatch, LVecByFacade: TVecI64x4;
begin
  LDispatch := GetDispatchTable;
  CheckNotNil(LDispatch, 'Dispatch table should be available');

  CheckTrue(Assigned(LDispatch^.CoreVectors.AddI64x4), 'Dispatch.CoreVectors.AddI64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.SubI64x4), 'Dispatch.CoreVectors.SubI64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.AndI64x4), 'Dispatch.CoreVectors.AndI64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.OrI64x4), 'Dispatch.CoreVectors.OrI64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.XorI64x4), 'Dispatch.CoreVectors.XorI64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.NotI64x4), 'Dispatch.CoreVectors.NotI64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.AndNotI64x4), 'Dispatch.CoreVectors.AndNotI64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.ShiftLeftI64x4), 'Dispatch.CoreVectors.ShiftLeftI64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.ShiftRightI64x4), 'Dispatch.CoreVectors.ShiftRightI64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.ShiftRightArithI64x4), 'Dispatch.CoreVectors.ShiftRightArithI64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpEqI64x4), 'Dispatch.CoreVectors.CmpEqI64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpLtI64x4), 'Dispatch.CoreVectors.CmpLtI64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpGtI64x4), 'Dispatch.CoreVectors.CmpGtI64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpLeI64x4), 'Dispatch.CoreVectors.CmpLeI64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpGeI64x4), 'Dispatch.CoreVectors.CmpGeI64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpNeI64x4), 'Dispatch.CoreVectors.CmpNeI64x4 should be assigned');

  LA.i[0] := -1;
  LA.i[1] := 5;
  LA.i[2] := 7;
  LA.i[3] := -8;
  LB.i[0] := 0;
  LB.i[1] := 1;
  LB.i[2] := 7;
  LB.i[3] := 9;

  LVecByDispatch := LDispatch^.CoreVectors.AndNotI64x4(LA, LB);
  LVecByFacade := VecI64x4AndNot(LA, LB);
  CheckEqual(LVecByFacade.i[0], LVecByDispatch.i[0], 'Dispatch/Facade AndNotI64x4 lane0 parity');
  CheckEqual(LVecByFacade.i[1], LVecByDispatch.i[1], 'Dispatch/Facade AndNotI64x4 lane1 parity');
  CheckEqual(LVecByFacade.i[2], LVecByDispatch.i[2], 'Dispatch/Facade AndNotI64x4 lane2 parity');
  CheckEqual(LVecByFacade.i[3], LVecByDispatch.i[3], 'Dispatch/Facade AndNotI64x4 lane3 parity');

  LVecByDispatch := LDispatch^.CoreVectors.ShiftLeftI64x4(LA, 2);
  LVecByFacade := VecI64x4ShiftLeft(LA, 2);
  CheckEqual(LVecByFacade.i[0], LVecByDispatch.i[0], 'Dispatch/Facade ShiftLeftI64x4 lane0 parity');
  CheckEqual(LVecByFacade.i[1], LVecByDispatch.i[1], 'Dispatch/Facade ShiftLeftI64x4 lane1 parity');
  CheckEqual(LVecByFacade.i[2], LVecByDispatch.i[2], 'Dispatch/Facade ShiftLeftI64x4 lane2 parity');
  CheckEqual(LVecByFacade.i[3], LVecByDispatch.i[3], 'Dispatch/Facade ShiftLeftI64x4 lane3 parity');

  LVecByDispatch := LDispatch^.CoreVectors.ShiftRightArithI64x4(LA, 2);
  LVecByFacade := VecI64x4ShiftRightArith(LA, 2);
  CheckEqual(LVecByFacade.i[0], LVecByDispatch.i[0], 'Dispatch/Facade ShiftRightArithI64x4 lane0 parity');
  CheckEqual(LVecByFacade.i[1], LVecByDispatch.i[1], 'Dispatch/Facade ShiftRightArithI64x4 lane1 parity');
  CheckEqual(LVecByFacade.i[2], LVecByDispatch.i[2], 'Dispatch/Facade ShiftRightArithI64x4 lane2 parity');
  CheckEqual(LVecByFacade.i[3], LVecByDispatch.i[3], 'Dispatch/Facade ShiftRightArithI64x4 lane3 parity');

  LMaskByDispatch := LDispatch^.CoreVectors.CmpLtI64x4(LA, LB);
  CheckEqual(Integer(TMask4(9)), Integer(LMaskByDispatch), 'Dispatch CmpLtI64x4 expected mask');
  CheckEqual(Integer(TMask4(9)), Integer(VecI64x4CmpLt(LA, LB)), 'Facade CmpLtI64x4 expected mask');

  LMaskByDispatch := LDispatch^.CoreVectors.CmpGtI64x4(LA, LB);
  CheckEqual(Integer(TMask4(2)), Integer(LMaskByDispatch), 'Dispatch CmpGtI64x4 expected mask');
  CheckEqual(Integer(TMask4(2)), Integer(VecI64x4CmpGt(LA, LB)), 'Facade CmpGtI64x4 expected mask');

  LMaskByDispatch := LDispatch^.CoreVectors.CmpEqI64x4(LA, LB);
  CheckEqual(Integer(TMask4(4)), Integer(LMaskByDispatch), 'Dispatch CmpEqI64x4 expected mask');
  CheckEqual(Integer(TMask4(4)), Integer(VecI64x4CmpEq(LA, LB)), 'Facade CmpEqI64x4 expected mask');
end;

procedure TTestCase_DispatchAPIParity.Test_VecU64x4_DispatchAssigned_And_Parity;
var
  LDispatch: PSimdDispatchTable;
  LA, LB: TVecU64x4;
  LMaskByDispatch: TMask4;
  LVecByDispatch, LVecByFacade: TVecU64x4;
begin
  LDispatch := GetDispatchTable;
  CheckNotNil(LDispatch, 'Dispatch table should be available');

  CheckTrue(Assigned(LDispatch^.CoreVectors.AddU64x4), 'Dispatch.CoreVectors.AddU64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.SubU64x4), 'Dispatch.CoreVectors.SubU64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.AndU64x4), 'Dispatch.CoreVectors.AndU64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.OrU64x4), 'Dispatch.CoreVectors.OrU64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.XorU64x4), 'Dispatch.CoreVectors.XorU64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.NotU64x4), 'Dispatch.CoreVectors.NotU64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.ShiftLeftU64x4), 'Dispatch.CoreVectors.ShiftLeftU64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.ShiftRightU64x4), 'Dispatch.CoreVectors.ShiftRightU64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpEqU64x4), 'Dispatch.CoreVectors.CmpEqU64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpLtU64x4), 'Dispatch.CoreVectors.CmpLtU64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpGtU64x4), 'Dispatch.CoreVectors.CmpGtU64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpLeU64x4), 'Dispatch.CoreVectors.CmpLeU64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpGeU64x4), 'Dispatch.CoreVectors.CmpGeU64x4 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpNeU64x4), 'Dispatch.CoreVectors.CmpNeU64x4 should be assigned');

  LA.u[0] := QWord($FFFFFFFFFFFFFFFF);
  LA.u[1] := 0;
  LA.u[2] := 5;
  LA.u[3] := 9;
  LB.u[0] := 0;
  LB.u[1] := 1;
  LB.u[2] := 5;
  LB.u[3] := 8;

  LVecByDispatch := LDispatch^.CoreVectors.AddU64x4(LA, LB);
  LVecByFacade := VecU64x4Add(LA, LB);
  CheckEqual(LVecByFacade.u[0], LVecByDispatch.u[0], 'Dispatch/Facade AddU64x4 lane0 parity');
  CheckEqual(LVecByFacade.u[1], LVecByDispatch.u[1], 'Dispatch/Facade AddU64x4 lane1 parity');
  CheckEqual(LVecByFacade.u[2], LVecByDispatch.u[2], 'Dispatch/Facade AddU64x4 lane2 parity');
  CheckEqual(LVecByFacade.u[3], LVecByDispatch.u[3], 'Dispatch/Facade AddU64x4 lane3 parity');

  LMaskByDispatch := LDispatch^.CoreVectors.CmpLtU64x4(LA, LB);
  CheckEqual(Integer(TMask4(2)), Integer(LMaskByDispatch), 'Dispatch CmpLtU64x4 expected mask');
  CheckEqual(Integer(TMask4(2)), Integer(VecU64x4CmpLt(LA, LB)), 'Facade CmpLtU64x4 expected mask');

  LMaskByDispatch := LDispatch^.CoreVectors.CmpGtU64x4(LA, LB);
  CheckEqual(Integer(TMask4(9)), Integer(LMaskByDispatch), 'Dispatch CmpGtU64x4 expected mask');
  CheckEqual(Integer(TMask4(9)), Integer(VecU64x4CmpGt(LA, LB)), 'Facade CmpGtU64x4 expected mask');

  LMaskByDispatch := LDispatch^.CoreVectors.CmpEqU64x4(LA, LB);
  CheckEqual(Integer(TMask4(4)), Integer(LMaskByDispatch), 'Dispatch CmpEqU64x4 expected mask');
  CheckEqual(Integer(TMask4(4)), Integer(VecU64x4CmpEq(LA, LB)), 'Facade CmpEqU64x4 expected mask');
end;

procedure TTestCase_DispatchAPIParity.Test_VecI64x8_DispatchAssigned_And_Parity;
var
  LDispatch: PSimdDispatchTable;
  LA, LB: TVecI64x8;
  LVecByDispatch, LVecByScalar: TVecI64x8;
  LMaskByDispatch, LMaskByScalar: TMask8;
  LIndex: Integer;
begin
  LDispatch := GetDispatchTable;
  CheckNotNil(LDispatch, 'Dispatch table should be available');

  CheckTrue(Assigned(LDispatch^.CoreVectors.AddI64x8), 'Dispatch.CoreVectors.AddI64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.SubI64x8), 'Dispatch.CoreVectors.SubI64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.AndI64x8), 'Dispatch.CoreVectors.AndI64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.OrI64x8), 'Dispatch.CoreVectors.OrI64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.XorI64x8), 'Dispatch.CoreVectors.XorI64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.NotI64x8), 'Dispatch.CoreVectors.NotI64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpEqI64x8), 'Dispatch.CoreVectors.CmpEqI64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpLtI64x8), 'Dispatch.CoreVectors.CmpLtI64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpGtI64x8), 'Dispatch.CoreVectors.CmpGtI64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpLeI64x8), 'Dispatch.CoreVectors.CmpLeI64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpGeI64x8), 'Dispatch.CoreVectors.CmpGeI64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpNeI64x8), 'Dispatch.CoreVectors.CmpNeI64x8 should be assigned');

  LA.i[0] := -1;   LB.i[0] := 0;
  LA.i[1] := 5;    LB.i[1] := 1;
  LA.i[2] := 7;    LB.i[2] := 7;
  LA.i[3] := -8;   LB.i[3] := 9;
  LA.i[4] := 12;   LB.i[4] := -3;
  LA.i[5] := 0;    LB.i[5] := 0;
  LA.i[6] := 100;  LB.i[6] := 200;
  LA.i[7] := -50;  LB.i[7] := -60;

  LVecByDispatch := LDispatch^.CoreVectors.AddI64x8(LA, LB);
  LVecByScalar := ScalarAddI64x8(LA, LB);
  for LIndex := 0 to 7 do
    CheckEqual(LVecByScalar.i[LIndex], LVecByDispatch.i[LIndex], 'Dispatch/Scalar AddI64x8 lane' + IntToStr(LIndex));

  LVecByDispatch := LDispatch^.CoreVectors.SubI64x8(LA, LB);
  LVecByScalar := ScalarSubI64x8(LA, LB);
  for LIndex := 0 to 7 do
    CheckEqual(LVecByScalar.i[LIndex], LVecByDispatch.i[LIndex], 'Dispatch/Scalar SubI64x8 lane' + IntToStr(LIndex));

  LVecByDispatch := LDispatch^.CoreVectors.AndI64x8(LA, LB);
  LVecByScalar := ScalarAndI64x8(LA, LB);
  for LIndex := 0 to 7 do
    CheckEqual(LVecByScalar.i[LIndex], LVecByDispatch.i[LIndex], 'Dispatch/Scalar AndI64x8 lane' + IntToStr(LIndex));

  LVecByDispatch := LDispatch^.CoreVectors.OrI64x8(LA, LB);
  LVecByScalar := ScalarOrI64x8(LA, LB);
  for LIndex := 0 to 7 do
    CheckEqual(LVecByScalar.i[LIndex], LVecByDispatch.i[LIndex], 'Dispatch/Scalar OrI64x8 lane' + IntToStr(LIndex));

  LVecByDispatch := LDispatch^.CoreVectors.XorI64x8(LA, LB);
  LVecByScalar := ScalarXorI64x8(LA, LB);
  for LIndex := 0 to 7 do
    CheckEqual(LVecByScalar.i[LIndex], LVecByDispatch.i[LIndex], 'Dispatch/Scalar XorI64x8 lane' + IntToStr(LIndex));

  LVecByDispatch := LDispatch^.CoreVectors.NotI64x8(LA);
  LVecByScalar := ScalarNotI64x8(LA);
  for LIndex := 0 to 7 do
    CheckEqual(LVecByScalar.i[LIndex], LVecByDispatch.i[LIndex], 'Dispatch/Scalar NotI64x8 lane' + IntToStr(LIndex));

  LMaskByDispatch := LDispatch^.CoreVectors.CmpEqI64x8(LA, LB);
  LMaskByScalar := ScalarCmpEqI64x8(LA, LB);
  CheckEqual(Integer(LMaskByScalar), Integer(LMaskByDispatch), 'Dispatch/Scalar CmpEqI64x8 parity');

  LMaskByDispatch := LDispatch^.CoreVectors.CmpLtI64x8(LA, LB);
  LMaskByScalar := ScalarCmpLtI64x8(LA, LB);
  CheckEqual(Integer(LMaskByScalar), Integer(LMaskByDispatch), 'Dispatch/Scalar CmpLtI64x8 parity');

  LMaskByDispatch := LDispatch^.CoreVectors.CmpGtI64x8(LA, LB);
  LMaskByScalar := ScalarCmpGtI64x8(LA, LB);
  CheckEqual(Integer(LMaskByScalar), Integer(LMaskByDispatch), 'Dispatch/Scalar CmpGtI64x8 parity');

  LMaskByDispatch := LDispatch^.CoreVectors.CmpLeI64x8(LA, LB);
  LMaskByScalar := ScalarCmpLeI64x8(LA, LB);
  CheckEqual(Integer(LMaskByScalar), Integer(LMaskByDispatch), 'Dispatch/Scalar CmpLeI64x8 parity');

  LMaskByDispatch := LDispatch^.CoreVectors.CmpGeI64x8(LA, LB);
  LMaskByScalar := ScalarCmpGeI64x8(LA, LB);
  CheckEqual(Integer(LMaskByScalar), Integer(LMaskByDispatch), 'Dispatch/Scalar CmpGeI64x8 parity');

  LMaskByDispatch := LDispatch^.CoreVectors.CmpNeI64x8(LA, LB);
  LMaskByScalar := ScalarCmpNeI64x8(LA, LB);
  CheckEqual(Integer(LMaskByScalar), Integer(LMaskByDispatch), 'Dispatch/Scalar CmpNeI64x8 parity');
end;

procedure TTestCase_DispatchAPIParity.Test_VecF32x16_DispatchAssigned_And_Parity;
var
  LDispatch: PSimdDispatchTable;
  LA, LB, LC: TVecF32x16;
  LMask: TMask16;
  LByDispatch, LByFacade: TVecF32x16;
  LSource, LStoredDispatch, LStoredFacade: array[0..15] of Single;
  LIndex: Integer;
begin
  LDispatch := GetDispatchTable;
  CheckNotNil(LDispatch, 'Dispatch table should be available');

  CheckTrue(Assigned(LDispatch^.CoreVectors.LoadF32x16), 'Dispatch.CoreVectors.LoadF32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.StoreF32x16), 'Dispatch.CoreVectors.StoreF32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.SplatF32x16), 'Dispatch.CoreVectors.SplatF32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.ZeroF32x16), 'Dispatch.CoreVectors.ZeroF32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.SelectF32x16), 'Dispatch.CoreVectors.SelectF32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.ClampF32x16), 'Dispatch.CoreVectors.ClampF32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.FmaF32x16), 'Dispatch.CoreVectors.FmaF32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.FloorF32x16), 'Dispatch.CoreVectors.FloorF32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CeilF32x16), 'Dispatch.CoreVectors.CeilF32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.RoundF32x16), 'Dispatch.CoreVectors.RoundF32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.TruncF32x16), 'Dispatch.CoreVectors.TruncF32x16 should be assigned');

  for LIndex := 0 to 15 do
  begin
    LA.f[LIndex] := LIndex + 0.25;
    LB.f[LIndex] := 2.0;
    LC.f[LIndex] := 1.0;
    LSource[LIndex] := LIndex + 0.5;
  end;

  LByDispatch := LDispatch^.CoreVectors.FmaF32x16(LA, LB, LC);
  LByFacade := VecF32x16Fma(LA, LB, LC);
  for LIndex := 0 to 15 do
    CheckNear(LByDispatch.f[LIndex], LByFacade.f[LIndex], 0.0001, 'Dispatch/Facade FmaF32x16 lane ' + IntToStr(LIndex));

  LByDispatch := LDispatch^.CoreVectors.ClampF32x16(LByDispatch, LDispatch^.CoreVectors.SplatF32x16(3.0), LDispatch^.CoreVectors.SplatF32x16(20.0));
  LByFacade := VecF32x16Clamp(LByFacade, VecF32x16Splat(3.0), VecF32x16Splat(20.0));
  for LIndex := 0 to 15 do
    CheckNear(LByDispatch.f[LIndex], LByFacade.f[LIndex], 0.0001, 'Dispatch/Facade ClampF32x16 lane ' + IntToStr(LIndex));

  LMask := TMask16($5555);
  LByDispatch := LDispatch^.CoreVectors.SelectF32x16(LMask, LA, LB);
  LByFacade := VecF32x16Select(LMask, LA, LB);
  for LIndex := 0 to 15 do
    CheckNear(LByDispatch.f[LIndex], LByFacade.f[LIndex], 0.0001, 'Dispatch/Facade SelectF32x16 lane ' + IntToStr(LIndex));

  LByDispatch := LDispatch^.CoreVectors.LoadF32x16(@LSource[0]);
  LByFacade := VecF32x16Load(@LSource[0]);
  for LIndex := 0 to 15 do
    CheckNear(LByDispatch.f[LIndex], LByFacade.f[LIndex], 0.0001, 'Dispatch/Facade LoadF32x16 lane ' + IntToStr(LIndex));

  LDispatch^.CoreVectors.StoreF32x16(@LStoredDispatch[0], LByDispatch);
  VecF32x16Store(@LStoredFacade[0], LByFacade);
  for LIndex := 0 to 15 do
    CheckNear(LStoredDispatch[LIndex], LStoredFacade[LIndex], 0.0001, 'Dispatch/Facade StoreF32x16 lane ' + IntToStr(LIndex));
end;

procedure TTestCase_DispatchAPIParity.Test_VecF64x8_DispatchAssigned_And_Parity;
var
  LDispatch: PSimdDispatchTable;
  LA, LB, LC: TVecF64x8;
  LMask: TMask8;
  LByDispatch, LByFacade: TVecF64x8;
  LSource, LStoredDispatch, LStoredFacade: array[0..7] of Double;
  LIndex: Integer;
begin
  LDispatch := GetDispatchTable;
  CheckNotNil(LDispatch, 'Dispatch table should be available');

  CheckTrue(Assigned(LDispatch^.CoreVectors.LoadF64x8), 'Dispatch.CoreVectors.LoadF64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.StoreF64x8), 'Dispatch.CoreVectors.StoreF64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.SplatF64x8), 'Dispatch.CoreVectors.SplatF64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.ZeroF64x8), 'Dispatch.CoreVectors.ZeroF64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.SelectF64x8), 'Dispatch.CoreVectors.SelectF64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.ClampF64x8), 'Dispatch.CoreVectors.ClampF64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.FmaF64x8), 'Dispatch.CoreVectors.FmaF64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.FloorF64x8), 'Dispatch.CoreVectors.FloorF64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CeilF64x8), 'Dispatch.CoreVectors.CeilF64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.RoundF64x8), 'Dispatch.CoreVectors.RoundF64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.TruncF64x8), 'Dispatch.CoreVectors.TruncF64x8 should be assigned');

  for LIndex := 0 to 7 do
  begin
    LA.d[LIndex] := LIndex + 0.5;
    LB.d[LIndex] := 3.0;
    LC.d[LIndex] := 2.0;
    LSource[LIndex] := LIndex + 0.125;
  end;

  LByDispatch := LDispatch^.CoreVectors.FmaF64x8(LA, LB, LC);
  LByFacade := VecF64x8Fma(LA, LB, LC);
  for LIndex := 0 to 7 do
    CheckNear(LByDispatch.d[LIndex], LByFacade.d[LIndex], 0.000001, 'Dispatch/Facade FmaF64x8 lane ' + IntToStr(LIndex));

  LByDispatch := LDispatch^.CoreVectors.ClampF64x8(LByDispatch, LDispatch^.CoreVectors.SplatF64x8(4.0), LDispatch^.CoreVectors.SplatF64x8(20.0));
  LByFacade := VecF64x8Clamp(LByFacade, VecF64x8Splat(4.0), VecF64x8Splat(20.0));
  for LIndex := 0 to 7 do
    CheckNear(LByDispatch.d[LIndex], LByFacade.d[LIndex], 0.000001, 'Dispatch/Facade ClampF64x8 lane ' + IntToStr(LIndex));

  LMask := TMask8($55);
  LByDispatch := LDispatch^.CoreVectors.SelectF64x8(LMask, LA, LB);
  LByFacade := VecF64x8Select(LMask, LA, LB);
  for LIndex := 0 to 7 do
    CheckNear(LByDispatch.d[LIndex], LByFacade.d[LIndex], 0.000001, 'Dispatch/Facade SelectF64x8 lane ' + IntToStr(LIndex));

  LByDispatch := LDispatch^.CoreVectors.LoadF64x8(@LSource[0]);
  LByFacade := VecF64x8Load(@LSource[0]);
  for LIndex := 0 to 7 do
    CheckNear(LByDispatch.d[LIndex], LByFacade.d[LIndex], 0.000001, 'Dispatch/Facade LoadF64x8 lane ' + IntToStr(LIndex));

  LDispatch^.CoreVectors.StoreF64x8(@LStoredDispatch[0], LByDispatch);
  VecF64x8Store(@LStoredFacade[0], LByFacade);
  for LIndex := 0 to 7 do
    CheckNear(LStoredDispatch[LIndex], LStoredFacade[LIndex], 0.000001, 'Dispatch/Facade StoreF64x8 lane ' + IntToStr(LIndex));
end;

procedure TTestCase_DispatchAPIParity.Test_VecU32x16_DispatchAssigned_And_Parity;
var
  LDispatch: PSimdDispatchTable;
  LA, LB: TVecU32x16;
  LVecDispatch, LVecFacade, LVecScalar: TVecU32x16;
  LMaskDispatch, LMaskScalar: TMask16;
  LIndex: Integer;
begin
  LDispatch := GetDispatchTable;
  CheckNotNil(LDispatch, 'Dispatch table should be available');

  CheckTrue(Assigned(LDispatch^.CoreVectors.AddU32x16), 'Dispatch.CoreVectors.AddU32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.SubU32x16), 'Dispatch.CoreVectors.SubU32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.MulU32x16), 'Dispatch.CoreVectors.MulU32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.AndU32x16), 'Dispatch.CoreVectors.AndU32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.OrU32x16), 'Dispatch.CoreVectors.OrU32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.XorU32x16), 'Dispatch.CoreVectors.XorU32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.NotU32x16), 'Dispatch.CoreVectors.NotU32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.AndNotU32x16), 'Dispatch.CoreVectors.AndNotU32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.ShiftLeftU32x16), 'Dispatch.CoreVectors.ShiftLeftU32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.ShiftRightU32x16), 'Dispatch.CoreVectors.ShiftRightU32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpEqU32x16), 'Dispatch.CoreVectors.CmpEqU32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpLtU32x16), 'Dispatch.CoreVectors.CmpLtU32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpGtU32x16), 'Dispatch.CoreVectors.CmpGtU32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpLeU32x16), 'Dispatch.CoreVectors.CmpLeU32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpGeU32x16), 'Dispatch.CoreVectors.CmpGeU32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpNeU32x16), 'Dispatch.CoreVectors.CmpNeU32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.MinU32x16), 'Dispatch.CoreVectors.MinU32x16 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.MaxU32x16), 'Dispatch.CoreVectors.MaxU32x16 should be assigned');

  for LIndex := 0 to 15 do
  begin
    LA.u[LIndex] := DWord(LIndex) * 17 + 1;
    LB.u[LIndex] := DWord(300 - LIndex * 7);
  end;

  LVecDispatch := LDispatch^.CoreVectors.AddU32x16(LA, LB);
  LVecFacade := VecU32x16Add(LA, LB);
  LVecScalar := ScalarAddU32x16(LA, LB);
  for LIndex := 0 to 15 do
  begin
    CheckEqual(LVecDispatch.u[LIndex], LVecFacade.u[LIndex], 'Dispatch/Facade AddU32x16 lane ' + IntToStr(LIndex));
    CheckEqual(LVecDispatch.u[LIndex], LVecScalar.u[LIndex], 'Dispatch/Scalar AddU32x16 lane ' + IntToStr(LIndex));
  end;

  LVecDispatch := LDispatch^.CoreVectors.ShiftRightU32x16(LA, 3);
  LVecFacade := VecU32x16ShiftRight(LA, 3);
  for LIndex := 0 to 15 do
    CheckEqual(LVecDispatch.u[LIndex], LVecFacade.u[LIndex], 'Dispatch/Facade ShiftRightU32x16 lane ' + IntToStr(LIndex));

  LMaskDispatch := LDispatch^.CoreVectors.CmpLeU32x16(LA, LB);
  LMaskScalar := ScalarCmpLeU32x16(LA, LB);
  CheckEqual(Integer(LMaskScalar), Integer(LMaskDispatch), 'Dispatch/Scalar CmpLeU32x16 parity');
end;

procedure TTestCase_DispatchAPIParity.Test_VecU64x8_DispatchAssigned_And_Parity;
var
  LDispatch: PSimdDispatchTable;
  LA, LB: TVecU64x8;
  LVecDispatch, LVecFacade, LVecScalar: TVecU64x8;
  LMaskDispatch, LMaskScalar: TMask8;
  LIndex: Integer;
begin
  LDispatch := GetDispatchTable;
  CheckNotNil(LDispatch, 'Dispatch table should be available');

  CheckTrue(Assigned(LDispatch^.CoreVectors.AddU64x8), 'Dispatch.CoreVectors.AddU64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.SubU64x8), 'Dispatch.CoreVectors.SubU64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.AndU64x8), 'Dispatch.CoreVectors.AndU64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.OrU64x8), 'Dispatch.CoreVectors.OrU64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.XorU64x8), 'Dispatch.CoreVectors.XorU64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.NotU64x8), 'Dispatch.CoreVectors.NotU64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.ShiftLeftU64x8), 'Dispatch.CoreVectors.ShiftLeftU64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.ShiftRightU64x8), 'Dispatch.CoreVectors.ShiftRightU64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpEqU64x8), 'Dispatch.CoreVectors.CmpEqU64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpLtU64x8), 'Dispatch.CoreVectors.CmpLtU64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpGtU64x8), 'Dispatch.CoreVectors.CmpGtU64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpLeU64x8), 'Dispatch.CoreVectors.CmpLeU64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpGeU64x8), 'Dispatch.CoreVectors.CmpGeU64x8 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpNeU64x8), 'Dispatch.CoreVectors.CmpNeU64x8 should be assigned');

  for LIndex := 0 to 7 do
  begin
    LA.u[LIndex] := QWord($FFFFFFFF00000000) + QWord(LIndex);
    LB.u[LIndex] := QWord(LIndex) * 33;
  end;

  LVecDispatch := LDispatch^.CoreVectors.XorU64x8(LA, LB);
  LVecFacade := VecU64x8Xor(LA, LB);
  LVecScalar := ScalarXorU64x8(LA, LB);
  for LIndex := 0 to 7 do
  begin
    CheckEqual(LVecDispatch.u[LIndex], LVecFacade.u[LIndex], 'Dispatch/Facade XorU64x8 lane ' + IntToStr(LIndex));
    CheckEqual(LVecDispatch.u[LIndex], LVecScalar.u[LIndex], 'Dispatch/Scalar XorU64x8 lane ' + IntToStr(LIndex));
  end;

  LMaskDispatch := LDispatch^.CoreVectors.CmpGtU64x8(LA, LB);
  LMaskScalar := ScalarCmpGtU64x8(LA, LB);
  CheckEqual(Integer(LMaskScalar), Integer(LMaskDispatch), 'Dispatch/Scalar CmpGtU64x8 parity');
end;

procedure TTestCase_DispatchAPIParity.Test_VecI16x32_DispatchAssigned_And_Parity;
var
  LDispatch: PSimdDispatchTable;
  LA, LB: TVecI16x32;
  LVecDispatch, LVecFacade, LVecScalar: TVecI16x32;
  LMaskDispatch, LMaskScalar: TMask32;
  LIndex: Integer;
begin
  LDispatch := GetDispatchTable;
  CheckNotNil(LDispatch, 'Dispatch table should be available');

  CheckTrue(Assigned(LDispatch^.CoreVectors.AddI16x32), 'Dispatch.CoreVectors.AddI16x32 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.SubI16x32), 'Dispatch.CoreVectors.SubI16x32 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.AndI16x32), 'Dispatch.CoreVectors.AndI16x32 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.OrI16x32), 'Dispatch.CoreVectors.OrI16x32 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.XorI16x32), 'Dispatch.CoreVectors.XorI16x32 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.NotI16x32), 'Dispatch.CoreVectors.NotI16x32 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.AndNotI16x32), 'Dispatch.CoreVectors.AndNotI16x32 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.ShiftLeftI16x32), 'Dispatch.CoreVectors.ShiftLeftI16x32 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.ShiftRightI16x32), 'Dispatch.CoreVectors.ShiftRightI16x32 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.ShiftRightArithI16x32), 'Dispatch.CoreVectors.ShiftRightArithI16x32 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpEqI16x32), 'Dispatch.CoreVectors.CmpEqI16x32 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpLtI16x32), 'Dispatch.CoreVectors.CmpLtI16x32 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpGtI16x32), 'Dispatch.CoreVectors.CmpGtI16x32 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.MinI16x32), 'Dispatch.CoreVectors.MinI16x32 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.MaxI16x32), 'Dispatch.CoreVectors.MaxI16x32 should be assigned');

  for LIndex := 0 to 31 do
  begin
    LA.i[LIndex] := SmallInt(LIndex - 16);
    LB.i[LIndex] := SmallInt(8 - LIndex);
  end;

  LVecDispatch := LDispatch^.CoreVectors.SubI16x32(LA, LB);
  LVecFacade := VecI16x32Sub(LA, LB);
  LVecScalar := ScalarSubI16x32(LA, LB);
  for LIndex := 0 to 31 do
  begin
    CheckEqual(LVecDispatch.i[LIndex], LVecFacade.i[LIndex], 'Dispatch/Facade SubI16x32 lane ' + IntToStr(LIndex));
    CheckEqual(LVecDispatch.i[LIndex], LVecScalar.i[LIndex], 'Dispatch/Scalar SubI16x32 lane ' + IntToStr(LIndex));
  end;

  LMaskDispatch := LDispatch^.CoreVectors.CmpLtI16x32(LA, LB);
  LMaskScalar := ScalarCmpLtI16x32(LA, LB);
  CheckEqual(LongInt(LMaskScalar), LongInt(LMaskDispatch), 'Dispatch/Scalar CmpLtI16x32 parity');
end;

procedure TTestCase_DispatchAPIParity.Test_VecI8x64_DispatchAssigned_And_Parity;
var
  LDispatch: PSimdDispatchTable;
  LA, LB: TVecI8x64;
  LVecDispatch, LVecFacade, LVecScalar: TVecI8x64;
  LMaskDispatch, LMaskScalar: TMask64;
  LIndex: Integer;
begin
  LDispatch := GetDispatchTable;
  CheckNotNil(LDispatch, 'Dispatch table should be available');

  CheckTrue(Assigned(LDispatch^.CoreVectors.AddI8x64), 'Dispatch.CoreVectors.AddI8x64 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.SubI8x64), 'Dispatch.CoreVectors.SubI8x64 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.AndI8x64), 'Dispatch.CoreVectors.AndI8x64 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.OrI8x64), 'Dispatch.CoreVectors.OrI8x64 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.XorI8x64), 'Dispatch.CoreVectors.XorI8x64 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.NotI8x64), 'Dispatch.CoreVectors.NotI8x64 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.AndNotI8x64), 'Dispatch.CoreVectors.AndNotI8x64 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpEqI8x64), 'Dispatch.CoreVectors.CmpEqI8x64 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpLtI8x64), 'Dispatch.CoreVectors.CmpLtI8x64 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpGtI8x64), 'Dispatch.CoreVectors.CmpGtI8x64 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.MinI8x64), 'Dispatch.CoreVectors.MinI8x64 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.MaxI8x64), 'Dispatch.CoreVectors.MaxI8x64 should be assigned');

  for LIndex := 0 to 63 do
  begin
    LA.i[LIndex] := ShortInt((LIndex mod 40) - 20);
    LB.i[LIndex] := ShortInt((20 - LIndex) mod 37);
  end;

  LVecDispatch := LDispatch^.CoreVectors.AndNotI8x64(LA, LB);
  LVecFacade := VecI8x64AndNot(LA, LB);
  LVecScalar := ScalarAndNotI8x64(LA, LB);
  for LIndex := 0 to 63 do
  begin
    CheckEqual(LVecDispatch.i[LIndex], LVecFacade.i[LIndex], 'Dispatch/Facade AndNotI8x64 lane ' + IntToStr(LIndex));
    CheckEqual(LVecDispatch.i[LIndex], LVecScalar.i[LIndex], 'Dispatch/Scalar AndNotI8x64 lane ' + IntToStr(LIndex));
  end;

  LMaskDispatch := LDispatch^.CoreVectors.CmpEqI8x64(LA, LB);
  LMaskScalar := ScalarCmpEqI8x64(LA, LB);
  CheckEqual(QWord(LMaskScalar), QWord(LMaskDispatch), 'Dispatch/Scalar CmpEqI8x64 parity');
end;

procedure TTestCase_DispatchAPIParity.Test_VecU8x64_DispatchAssigned_And_Parity;
var
  LDispatch: PSimdDispatchTable;
  LA, LB: TVecU8x64;
  LVecDispatch, LVecFacade, LVecScalar: TVecU8x64;
  LMaskDispatch, LMaskScalar: TMask64;
  LIndex: Integer;
begin
  LDispatch := GetDispatchTable;
  CheckNotNil(LDispatch, 'Dispatch table should be available');

  CheckTrue(Assigned(LDispatch^.CoreVectors.AddU8x64), 'Dispatch.CoreVectors.AddU8x64 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.SubU8x64), 'Dispatch.CoreVectors.SubU8x64 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.AndU8x64), 'Dispatch.CoreVectors.AndU8x64 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.OrU8x64), 'Dispatch.CoreVectors.OrU8x64 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.XorU8x64), 'Dispatch.CoreVectors.XorU8x64 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.NotU8x64), 'Dispatch.CoreVectors.NotU8x64 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpEqU8x64), 'Dispatch.CoreVectors.CmpEqU8x64 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpLtU8x64), 'Dispatch.CoreVectors.CmpLtU8x64 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpGtU8x64), 'Dispatch.CoreVectors.CmpGtU8x64 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.MinU8x64), 'Dispatch.CoreVectors.MinU8x64 should be assigned');
  CheckTrue(Assigned(LDispatch^.CoreVectors.MaxU8x64), 'Dispatch.CoreVectors.MaxU8x64 should be assigned');

  for LIndex := 0 to 63 do
  begin
    LA.u[LIndex] := Byte((LIndex * 3) and $FF);
    LB.u[LIndex] := Byte((255 - LIndex * 2) and $FF);
  end;

  LVecDispatch := LDispatch^.CoreVectors.MaxU8x64(LA, LB);
  LVecFacade := VecU8x64Max(LA, LB);
  LVecScalar := ScalarMaxU8x64(LA, LB);
  for LIndex := 0 to 63 do
  begin
    CheckEqual(LVecDispatch.u[LIndex], LVecFacade.u[LIndex], 'Dispatch/Facade MaxU8x64 lane ' + IntToStr(LIndex));
    CheckEqual(LVecDispatch.u[LIndex], LVecScalar.u[LIndex], 'Dispatch/Scalar MaxU8x64 lane ' + IntToStr(LIndex));
  end;

  LMaskDispatch := LDispatch^.CoreVectors.CmpGtU8x64(LA, LB);
  LMaskScalar := ScalarCmpGtU8x64(LA, LB);
  CheckEqual(QWord(LMaskScalar), QWord(LMaskDispatch), 'Dispatch/Scalar CmpGtU8x64 parity');
end;

procedure TTestCase_DispatchAPIParity.Test_WideFamilies_FacadeScalar_Parity_Completeness;
var
  LIndex: Integer;

  LU32A, LU32B: TVecU32x16;
  LU32ByFacade, LU32ByScalar: TVecU32x16;
  LMask16Facade, LMask16Scalar: TMask16;

  LU64A, LU64B: TVecU64x8;
  LU64ByFacade, LU64ByScalar: TVecU64x8;
  LMask8Facade, LMask8Scalar: TMask8;

  LI16A, LI16B: TVecI16x32;
  LI16ByFacade, LI16ByScalar: TVecI16x32;
  LMask32Facade, LMask32Scalar: TMask32;

  LI8A, LI8B: TVecI8x64;
  LI8ByFacade, LI8ByScalar: TVecI8x64;
  LMask64Facade, LMask64Scalar: TMask64;

  LU8A, LU8B: TVecU8x64;
  LU8ByFacade, LU8ByScalar: TVecU8x64;

  procedure AssertVecU32x16Equal(const aOp: string; const aExpected, aActual: TVecU32x16);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 15 do
      CheckEqual(aExpected.u[LLane], aActual.u[LLane], aOp + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecU64x8Equal(const aOp: string; const aExpected, aActual: TVecU64x8);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 7 do
      CheckEqual(aExpected.u[LLane], aActual.u[LLane], aOp + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecI16x32Equal(const aOp: string; const aExpected, aActual: TVecI16x32);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 31 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aOp + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecI8x64Equal(const aOp: string; const aExpected, aActual: TVecI8x64);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 63 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aOp + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecU8x64Equal(const aOp: string; const aExpected, aActual: TVecU8x64);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 63 do
      CheckEqual(aExpected.u[LLane], aActual.u[LLane], aOp + ' lane ' + IntToStr(LLane));
  end;
begin
  for LIndex := 0 to 15 do
  begin
    LU32A.u[LIndex] := DWord($10000000 + LIndex * 12345);
    LU32B.u[LIndex] := DWord((15 - LIndex) * 54321 + 7);
  end;

  LU32ByFacade := VecU32x16Add(LU32A, LU32B);
  LU32ByScalar := ScalarAddU32x16(LU32A, LU32B);
  AssertVecU32x16Equal('VecU32x16Add', LU32ByScalar, LU32ByFacade);

  LU32ByFacade := VecU32x16Sub(LU32A, LU32B);
  LU32ByScalar := ScalarSubU32x16(LU32A, LU32B);
  AssertVecU32x16Equal('VecU32x16Sub', LU32ByScalar, LU32ByFacade);

  LU32ByFacade := VecU32x16Mul(LU32A, LU32B);
  LU32ByScalar := ScalarMulU32x16(LU32A, LU32B);
  AssertVecU32x16Equal('VecU32x16Mul', LU32ByScalar, LU32ByFacade);

  LU32ByFacade := VecU32x16And(LU32A, LU32B);
  LU32ByScalar := ScalarAndU32x16(LU32A, LU32B);
  AssertVecU32x16Equal('VecU32x16And', LU32ByScalar, LU32ByFacade);

  LU32ByFacade := VecU32x16Or(LU32A, LU32B);
  LU32ByScalar := ScalarOrU32x16(LU32A, LU32B);
  AssertVecU32x16Equal('VecU32x16Or', LU32ByScalar, LU32ByFacade);

  LU32ByFacade := VecU32x16Xor(LU32A, LU32B);
  LU32ByScalar := ScalarXorU32x16(LU32A, LU32B);
  AssertVecU32x16Equal('VecU32x16Xor', LU32ByScalar, LU32ByFacade);

  LU32ByFacade := VecU32x16Not(LU32A);
  LU32ByScalar := ScalarNotU32x16(LU32A);
  AssertVecU32x16Equal('VecU32x16Not', LU32ByScalar, LU32ByFacade);

  LU32ByFacade := VecU32x16AndNot(LU32A, LU32B);
  LU32ByScalar := ScalarAndNotU32x16(LU32A, LU32B);
  AssertVecU32x16Equal('VecU32x16AndNot', LU32ByScalar, LU32ByFacade);

  LU32ByFacade := VecU32x16ShiftLeft(LU32A, 5);
  LU32ByScalar := ScalarShiftLeftU32x16(LU32A, 5);
  AssertVecU32x16Equal('VecU32x16ShiftLeft', LU32ByScalar, LU32ByFacade);

  LU32ByFacade := VecU32x16ShiftRight(LU32A, 3);
  LU32ByScalar := ScalarShiftRightU32x16(LU32A, 3);
  AssertVecU32x16Equal('VecU32x16ShiftRight', LU32ByScalar, LU32ByFacade);

  LMask16Facade := VecU32x16CmpEq(LU32A, LU32B);
  LMask16Scalar := ScalarCmpEqU32x16(LU32A, LU32B);
  CheckEqual(Integer(LMask16Scalar), Integer(LMask16Facade), 'VecU32x16CmpEq');

  LMask16Facade := VecU32x16CmpLt(LU32A, LU32B);
  LMask16Scalar := ScalarCmpLtU32x16(LU32A, LU32B);
  CheckEqual(Integer(LMask16Scalar), Integer(LMask16Facade), 'VecU32x16CmpLt');

  LMask16Facade := VecU32x16CmpGt(LU32A, LU32B);
  LMask16Scalar := ScalarCmpGtU32x16(LU32A, LU32B);
  CheckEqual(Integer(LMask16Scalar), Integer(LMask16Facade), 'VecU32x16CmpGt');

  LMask16Facade := VecU32x16CmpLe(LU32A, LU32B);
  LMask16Scalar := ScalarCmpLeU32x16(LU32A, LU32B);
  CheckEqual(Integer(LMask16Scalar), Integer(LMask16Facade), 'VecU32x16CmpLe');

  LMask16Facade := VecU32x16CmpGe(LU32A, LU32B);
  LMask16Scalar := ScalarCmpGeU32x16(LU32A, LU32B);
  CheckEqual(Integer(LMask16Scalar), Integer(LMask16Facade), 'VecU32x16CmpGe');

  LMask16Facade := VecU32x16CmpNe(LU32A, LU32B);
  LMask16Scalar := ScalarCmpNeU32x16(LU32A, LU32B);
  CheckEqual(Integer(LMask16Scalar), Integer(LMask16Facade), 'VecU32x16CmpNe');

  LU32ByFacade := VecU32x16Min(LU32A, LU32B);
  LU32ByScalar := ScalarMinU32x16(LU32A, LU32B);
  AssertVecU32x16Equal('VecU32x16Min', LU32ByScalar, LU32ByFacade);

  LU32ByFacade := VecU32x16Max(LU32A, LU32B);
  LU32ByScalar := ScalarMaxU32x16(LU32A, LU32B);
  AssertVecU32x16Equal('VecU32x16Max', LU32ByScalar, LU32ByFacade);

  for LIndex := 0 to 7 do
  begin
    LU64A.u[LIndex] := QWord($F000000000000000) or (QWord(LIndex + 1) * QWord($0102030405060708));
    LU64B.u[LIndex] := QWord(17 + LIndex * 1234567);
  end;

  LU64ByFacade := VecU64x8Add(LU64A, LU64B);
  LU64ByScalar := ScalarAddU64x8(LU64A, LU64B);
  AssertVecU64x8Equal('VecU64x8Add', LU64ByScalar, LU64ByFacade);

  LU64ByFacade := VecU64x8Sub(LU64A, LU64B);
  LU64ByScalar := ScalarSubU64x8(LU64A, LU64B);
  AssertVecU64x8Equal('VecU64x8Sub', LU64ByScalar, LU64ByFacade);

  LU64ByFacade := VecU64x8And(LU64A, LU64B);
  LU64ByScalar := ScalarAndU64x8(LU64A, LU64B);
  AssertVecU64x8Equal('VecU64x8And', LU64ByScalar, LU64ByFacade);

  LU64ByFacade := VecU64x8Or(LU64A, LU64B);
  LU64ByScalar := ScalarOrU64x8(LU64A, LU64B);
  AssertVecU64x8Equal('VecU64x8Or', LU64ByScalar, LU64ByFacade);

  LU64ByFacade := VecU64x8Xor(LU64A, LU64B);
  LU64ByScalar := ScalarXorU64x8(LU64A, LU64B);
  AssertVecU64x8Equal('VecU64x8Xor', LU64ByScalar, LU64ByFacade);

  LU64ByFacade := VecU64x8Not(LU64A);
  LU64ByScalar := ScalarNotU64x8(LU64A);
  AssertVecU64x8Equal('VecU64x8Not', LU64ByScalar, LU64ByFacade);

  LU64ByFacade := VecU64x8ShiftLeft(LU64A, 7);
  LU64ByScalar := ScalarShiftLeftU64x8(LU64A, 7);
  AssertVecU64x8Equal('VecU64x8ShiftLeft', LU64ByScalar, LU64ByFacade);

  LU64ByFacade := VecU64x8ShiftRight(LU64A, 9);
  LU64ByScalar := ScalarShiftRightU64x8(LU64A, 9);
  AssertVecU64x8Equal('VecU64x8ShiftRight', LU64ByScalar, LU64ByFacade);

  LMask8Facade := VecU64x8CmpEq(LU64A, LU64B);
  LMask8Scalar := ScalarCmpEqU64x8(LU64A, LU64B);
  CheckEqual(Integer(LMask8Scalar), Integer(LMask8Facade), 'VecU64x8CmpEq');

  LMask8Facade := VecU64x8CmpLt(LU64A, LU64B);
  LMask8Scalar := ScalarCmpLtU64x8(LU64A, LU64B);
  CheckEqual(Integer(LMask8Scalar), Integer(LMask8Facade), 'VecU64x8CmpLt');

  LMask8Facade := VecU64x8CmpGt(LU64A, LU64B);
  LMask8Scalar := ScalarCmpGtU64x8(LU64A, LU64B);
  CheckEqual(Integer(LMask8Scalar), Integer(LMask8Facade), 'VecU64x8CmpGt');

  LMask8Facade := VecU64x8CmpLe(LU64A, LU64B);
  LMask8Scalar := ScalarCmpLeU64x8(LU64A, LU64B);
  CheckEqual(Integer(LMask8Scalar), Integer(LMask8Facade), 'VecU64x8CmpLe');

  LMask8Facade := VecU64x8CmpGe(LU64A, LU64B);
  LMask8Scalar := ScalarCmpGeU64x8(LU64A, LU64B);
  CheckEqual(Integer(LMask8Scalar), Integer(LMask8Facade), 'VecU64x8CmpGe');

  LMask8Facade := VecU64x8CmpNe(LU64A, LU64B);
  LMask8Scalar := ScalarCmpNeU64x8(LU64A, LU64B);
  CheckEqual(Integer(LMask8Scalar), Integer(LMask8Facade), 'VecU64x8CmpNe');

  for LIndex := 0 to 31 do
  begin
    LI16A.i[LIndex] := SmallInt(LIndex * 5 - 70);
    LI16B.i[LIndex] := SmallInt(90 - LIndex * 3);
  end;

  LI16ByFacade := VecI16x32Add(LI16A, LI16B);
  LI16ByScalar := ScalarAddI16x32(LI16A, LI16B);
  AssertVecI16x32Equal('VecI16x32Add', LI16ByScalar, LI16ByFacade);

  LI16ByFacade := VecI16x32Sub(LI16A, LI16B);
  LI16ByScalar := ScalarSubI16x32(LI16A, LI16B);
  AssertVecI16x32Equal('VecI16x32Sub', LI16ByScalar, LI16ByFacade);

  LI16ByFacade := VecI16x32And(LI16A, LI16B);
  LI16ByScalar := ScalarAndI16x32(LI16A, LI16B);
  AssertVecI16x32Equal('VecI16x32And', LI16ByScalar, LI16ByFacade);

  LI16ByFacade := VecI16x32Or(LI16A, LI16B);
  LI16ByScalar := ScalarOrI16x32(LI16A, LI16B);
  AssertVecI16x32Equal('VecI16x32Or', LI16ByScalar, LI16ByFacade);

  LI16ByFacade := VecI16x32Xor(LI16A, LI16B);
  LI16ByScalar := ScalarXorI16x32(LI16A, LI16B);
  AssertVecI16x32Equal('VecI16x32Xor', LI16ByScalar, LI16ByFacade);

  LI16ByFacade := VecI16x32Not(LI16A);
  LI16ByScalar := ScalarNotI16x32(LI16A);
  AssertVecI16x32Equal('VecI16x32Not', LI16ByScalar, LI16ByFacade);

  LI16ByFacade := VecI16x32AndNot(LI16A, LI16B);
  LI16ByScalar := ScalarAndNotI16x32(LI16A, LI16B);
  AssertVecI16x32Equal('VecI16x32AndNot', LI16ByScalar, LI16ByFacade);

  LI16ByFacade := VecI16x32ShiftLeft(LI16A, 3);
  LI16ByScalar := ScalarShiftLeftI16x32(LI16A, 3);
  AssertVecI16x32Equal('VecI16x32ShiftLeft', LI16ByScalar, LI16ByFacade);

  LI16ByFacade := VecI16x32ShiftRight(LI16A, 2);
  LI16ByScalar := ScalarShiftRightI16x32(LI16A, 2);
  AssertVecI16x32Equal('VecI16x32ShiftRight', LI16ByScalar, LI16ByFacade);

  LI16ByFacade := VecI16x32ShiftRightArith(LI16A, 2);
  LI16ByScalar := ScalarShiftRightArithI16x32(LI16A, 2);
  AssertVecI16x32Equal('VecI16x32ShiftRightArith', LI16ByScalar, LI16ByFacade);

  LMask32Facade := VecI16x32CmpEq(LI16A, LI16B);
  LMask32Scalar := ScalarCmpEqI16x32(LI16A, LI16B);
  CheckEqual(LongInt(LMask32Scalar), LongInt(LMask32Facade), 'VecI16x32CmpEq');

  LMask32Facade := VecI16x32CmpLt(LI16A, LI16B);
  LMask32Scalar := ScalarCmpLtI16x32(LI16A, LI16B);
  CheckEqual(LongInt(LMask32Scalar), LongInt(LMask32Facade), 'VecI16x32CmpLt');

  LMask32Facade := VecI16x32CmpGt(LI16A, LI16B);
  LMask32Scalar := ScalarCmpGtI16x32(LI16A, LI16B);
  CheckEqual(LongInt(LMask32Scalar), LongInt(LMask32Facade), 'VecI16x32CmpGt');

  LI16ByFacade := VecI16x32Min(LI16A, LI16B);
  LI16ByScalar := ScalarMinI16x32(LI16A, LI16B);
  AssertVecI16x32Equal('VecI16x32Min', LI16ByScalar, LI16ByFacade);

  LI16ByFacade := VecI16x32Max(LI16A, LI16B);
  LI16ByScalar := ScalarMaxI16x32(LI16A, LI16B);
  AssertVecI16x32Equal('VecI16x32Max', LI16ByScalar, LI16ByFacade);

  for LIndex := 0 to 63 do
  begin
    LI8A.i[LIndex] := ShortInt((LIndex mod 41) - 20);
    LI8B.i[LIndex] := ShortInt(15 - (LIndex mod 31));
    LU8A.u[LIndex] := Byte((LIndex * 11 + 3) and $FF);
    LU8B.u[LIndex] := Byte((255 - LIndex * 7) and $FF);
  end;

  LI8ByFacade := VecI8x64Add(LI8A, LI8B);
  LI8ByScalar := ScalarAddI8x64(LI8A, LI8B);
  AssertVecI8x64Equal('VecI8x64Add', LI8ByScalar, LI8ByFacade);

  LI8ByFacade := VecI8x64Sub(LI8A, LI8B);
  LI8ByScalar := ScalarSubI8x64(LI8A, LI8B);
  AssertVecI8x64Equal('VecI8x64Sub', LI8ByScalar, LI8ByFacade);

  LI8ByFacade := VecI8x64And(LI8A, LI8B);
  LI8ByScalar := ScalarAndI8x64(LI8A, LI8B);
  AssertVecI8x64Equal('VecI8x64And', LI8ByScalar, LI8ByFacade);

  LI8ByFacade := VecI8x64Or(LI8A, LI8B);
  LI8ByScalar := ScalarOrI8x64(LI8A, LI8B);
  AssertVecI8x64Equal('VecI8x64Or', LI8ByScalar, LI8ByFacade);

  LI8ByFacade := VecI8x64Xor(LI8A, LI8B);
  LI8ByScalar := ScalarXorI8x64(LI8A, LI8B);
  AssertVecI8x64Equal('VecI8x64Xor', LI8ByScalar, LI8ByFacade);

  LI8ByFacade := VecI8x64Not(LI8A);
  LI8ByScalar := ScalarNotI8x64(LI8A);
  AssertVecI8x64Equal('VecI8x64Not', LI8ByScalar, LI8ByFacade);

  LI8ByFacade := VecI8x64AndNot(LI8A, LI8B);
  LI8ByScalar := ScalarAndNotI8x64(LI8A, LI8B);
  AssertVecI8x64Equal('VecI8x64AndNot', LI8ByScalar, LI8ByFacade);

  LMask64Facade := VecI8x64CmpEq(LI8A, LI8B);
  LMask64Scalar := ScalarCmpEqI8x64(LI8A, LI8B);
  CheckEqual(QWord(LMask64Scalar), QWord(LMask64Facade), 'VecI8x64CmpEq');

  LMask64Facade := VecI8x64CmpLt(LI8A, LI8B);
  LMask64Scalar := ScalarCmpLtI8x64(LI8A, LI8B);
  CheckEqual(QWord(LMask64Scalar), QWord(LMask64Facade), 'VecI8x64CmpLt');

  LMask64Facade := VecI8x64CmpGt(LI8A, LI8B);
  LMask64Scalar := ScalarCmpGtI8x64(LI8A, LI8B);
  CheckEqual(QWord(LMask64Scalar), QWord(LMask64Facade), 'VecI8x64CmpGt');

  LI8ByFacade := VecI8x64Min(LI8A, LI8B);
  LI8ByScalar := ScalarMinI8x64(LI8A, LI8B);
  AssertVecI8x64Equal('VecI8x64Min', LI8ByScalar, LI8ByFacade);

  LI8ByFacade := VecI8x64Max(LI8A, LI8B);
  LI8ByScalar := ScalarMaxI8x64(LI8A, LI8B);
  AssertVecI8x64Equal('VecI8x64Max', LI8ByScalar, LI8ByFacade);

  LU8ByFacade := VecU8x64Add(LU8A, LU8B);
  LU8ByScalar := ScalarAddU8x64(LU8A, LU8B);
  AssertVecU8x64Equal('VecU8x64Add', LU8ByScalar, LU8ByFacade);

  LU8ByFacade := VecU8x64Sub(LU8A, LU8B);
  LU8ByScalar := ScalarSubU8x64(LU8A, LU8B);
  AssertVecU8x64Equal('VecU8x64Sub', LU8ByScalar, LU8ByFacade);

  LU8ByFacade := VecU8x64And(LU8A, LU8B);
  LU8ByScalar := ScalarAndU8x64(LU8A, LU8B);
  AssertVecU8x64Equal('VecU8x64And', LU8ByScalar, LU8ByFacade);

  LU8ByFacade := VecU8x64Or(LU8A, LU8B);
  LU8ByScalar := ScalarOrU8x64(LU8A, LU8B);
  AssertVecU8x64Equal('VecU8x64Or', LU8ByScalar, LU8ByFacade);

  LU8ByFacade := VecU8x64Xor(LU8A, LU8B);
  LU8ByScalar := ScalarXorU8x64(LU8A, LU8B);
  AssertVecU8x64Equal('VecU8x64Xor', LU8ByScalar, LU8ByFacade);

  LU8ByFacade := VecU8x64Not(LU8A);
  LU8ByScalar := ScalarNotU8x64(LU8A);
  AssertVecU8x64Equal('VecU8x64Not', LU8ByScalar, LU8ByFacade);

  LMask64Facade := VecU8x64CmpEq(LU8A, LU8B);
  LMask64Scalar := ScalarCmpEqU8x64(LU8A, LU8B);
  CheckEqual(QWord(LMask64Scalar), QWord(LMask64Facade), 'VecU8x64CmpEq');

  LMask64Facade := VecU8x64CmpLt(LU8A, LU8B);
  LMask64Scalar := ScalarCmpLtU8x64(LU8A, LU8B);
  CheckEqual(QWord(LMask64Scalar), QWord(LMask64Facade), 'VecU8x64CmpLt');

  LMask64Facade := VecU8x64CmpGt(LU8A, LU8B);
  LMask64Scalar := ScalarCmpGtU8x64(LU8A, LU8B);
  CheckEqual(QWord(LMask64Scalar), QWord(LMask64Facade), 'VecU8x64CmpGt');

  LU8ByFacade := VecU8x64Min(LU8A, LU8B);
  LU8ByScalar := ScalarMinU8x64(LU8A, LU8B);
  AssertVecU8x64Equal('VecU8x64Min', LU8ByScalar, LU8ByFacade);

  LU8ByFacade := VecU8x64Max(LU8A, LU8B);
  LU8ByScalar := ScalarMaxU8x64(LU8A, LU8B);
  AssertVecU8x64Equal('VecU8x64Max', LU8ByScalar, LU8ByFacade);
end;

procedure TTestCase_DispatchAPIParity.Test_CoreFamilies_FacadeScalar_Parity_Completeness_Batch2;
var
  LIndex: Integer;

  LI32x16A, LI32x16B, LI32x16Facade, LI32x16Scalar, LI32x16Inserted: TVecI32x16;
  LI32x4A, LI32x4B, LI32x4Facade, LI32x4Scalar, LI32x4Mask: TVecI32x4;
  LI64x4A, LI64x4B, LI64x4Facade, LI64x4Scalar, LI64x4Inserted: TVecI64x4;
  LI64x2A, LI64x2B, LI64x2Facade, LI64x2Scalar, LI64x2Inserted: TVecI64x2;
  LF64x2A, LF64x2B, LF64x2Facade, LF64x2Scalar, LF64x2Inserted: TVecF64x2;

  LMask16Facade, LMask16Scalar: TMask16;
  LMask4Facade, LMask4Scalar: TMask4;
  LMask2Facade, LMask2Scalar: TMask2;

  LF64ReduceFacade, LF64ReduceScalar: Double;
  LF64DotFacade, LF64DotScalar: Double;

  LLoadF64: array[0..1] of Double;
  LStoreF64Facade: array[0..1] of Double;
  LStoreF64Scalar: array[0..1] of Double;
  LLoadI64x4: array[0..3] of Int64;
  LStoreI64x4Facade: array[0..3] of Int64;
  LStoreI64x4Scalar: array[0..3] of Int64;

  procedure AssertVecI32x16Equal(const aOp: string; const aExpected, aActual: TVecI32x16);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 15 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aOp + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecI32x4Equal(const aOp: string; const aExpected, aActual: TVecI32x4);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aOp + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecI64x4Equal(const aOp: string; const aExpected, aActual: TVecI64x4);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aOp + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecI64x2Equal(const aOp: string; const aExpected, aActual: TVecI64x2);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 1 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aOp + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecF64x2Equal(const aOp: string; const aExpected, aActual: TVecF64x2);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 1 do
      CheckNear(aExpected.d[LLane], aActual.d[LLane], 1.0e-12, aOp + ' lane ' + IntToStr(LLane));
  end;
begin
  for LIndex := 0 to 15 do
  begin
    LI32x16A.i[LIndex] := LIndex * 23 - 100;
    LI32x16B.i[LIndex] := 700 - LIndex * 19;
  end;

  CheckEqual(LI32x16A.i[5], VecI32x16Extract(LI32x16A, 5), 'VecI32x16Extract lane5');
  LI32x16Inserted := VecI32x16Insert(LI32x16A, 123456, 6);
  CheckEqual(123456, LI32x16Inserted.i[6], 'VecI32x16Insert lane6');
  CheckEqual(LI32x16A.i[5], LI32x16Inserted.i[5], 'VecI32x16Insert keep lane5');

  LI32x16Facade := VecI32x16Add(LI32x16A, LI32x16B);
  LI32x16Scalar := ScalarAddI32x16(LI32x16A, LI32x16B);
  AssertVecI32x16Equal('VecI32x16Add', LI32x16Scalar, LI32x16Facade);

  LI32x16Facade := VecI32x16Sub(LI32x16A, LI32x16B);
  LI32x16Scalar := ScalarSubI32x16(LI32x16A, LI32x16B);
  AssertVecI32x16Equal('VecI32x16Sub', LI32x16Scalar, LI32x16Facade);

  LI32x16Facade := VecI32x16Mul(LI32x16A, LI32x16B);
  LI32x16Scalar := ScalarMulI32x16(LI32x16A, LI32x16B);
  AssertVecI32x16Equal('VecI32x16Mul', LI32x16Scalar, LI32x16Facade);

  LI32x16Facade := VecI32x16And(LI32x16A, LI32x16B);
  LI32x16Scalar := ScalarAndI32x16(LI32x16A, LI32x16B);
  AssertVecI32x16Equal('VecI32x16And', LI32x16Scalar, LI32x16Facade);

  LI32x16Facade := VecI32x16Or(LI32x16A, LI32x16B);
  LI32x16Scalar := ScalarOrI32x16(LI32x16A, LI32x16B);
  AssertVecI32x16Equal('VecI32x16Or', LI32x16Scalar, LI32x16Facade);

  LI32x16Facade := VecI32x16Xor(LI32x16A, LI32x16B);
  LI32x16Scalar := ScalarXorI32x16(LI32x16A, LI32x16B);
  AssertVecI32x16Equal('VecI32x16Xor', LI32x16Scalar, LI32x16Facade);

  LI32x16Facade := VecI32x16Not(LI32x16A);
  LI32x16Scalar := ScalarNotI32x16(LI32x16A);
  AssertVecI32x16Equal('VecI32x16Not', LI32x16Scalar, LI32x16Facade);

  LI32x16Facade := VecI32x16AndNot(LI32x16A, LI32x16B);
  LI32x16Scalar := ScalarAndNotI32x16(LI32x16A, LI32x16B);
  AssertVecI32x16Equal('VecI32x16AndNot', LI32x16Scalar, LI32x16Facade);

  LI32x16Facade := VecI32x16ShiftLeft(LI32x16A, 4);
  LI32x16Scalar := ScalarShiftLeftI32x16(LI32x16A, 4);
  AssertVecI32x16Equal('VecI32x16ShiftLeft', LI32x16Scalar, LI32x16Facade);

  LI32x16Facade := VecI32x16ShiftRight(LI32x16A, 3);
  LI32x16Scalar := ScalarShiftRightI32x16(LI32x16A, 3);
  AssertVecI32x16Equal('VecI32x16ShiftRight', LI32x16Scalar, LI32x16Facade);

  LI32x16Facade := VecI32x16ShiftRightArith(LI32x16A, 3);
  LI32x16Scalar := ScalarShiftRightArithI32x16(LI32x16A, 3);
  AssertVecI32x16Equal('VecI32x16ShiftRightArith', LI32x16Scalar, LI32x16Facade);

  LMask16Facade := nextpas.core.simd.VecI32x16CmpEq(LI32x16A, LI32x16B);
  LMask16Scalar := ScalarCmpEqI32x16(LI32x16A, LI32x16B);
  CheckEqual(LongInt(LMask16Scalar), LongInt(LMask16Facade), 'VecI32x16CmpEq');

  LMask16Facade := nextpas.core.simd.VecI32x16CmpLt(LI32x16A, LI32x16B);
  LMask16Scalar := ScalarCmpLtI32x16(LI32x16A, LI32x16B);
  CheckEqual(LongInt(LMask16Scalar), LongInt(LMask16Facade), 'VecI32x16CmpLt');

  LMask16Facade := nextpas.core.simd.VecI32x16CmpGt(LI32x16A, LI32x16B);
  LMask16Scalar := ScalarCmpGtI32x16(LI32x16A, LI32x16B);
  CheckEqual(LongInt(LMask16Scalar), LongInt(LMask16Facade), 'VecI32x16CmpGt');

  LMask16Facade := nextpas.core.simd.VecI32x16CmpLe(LI32x16A, LI32x16B);
  LMask16Scalar := ScalarCmpLeI32x16(LI32x16A, LI32x16B);
  CheckEqual(LongInt(LMask16Scalar), LongInt(LMask16Facade), 'VecI32x16CmpLe');

  LMask16Facade := nextpas.core.simd.VecI32x16CmpGe(LI32x16A, LI32x16B);
  LMask16Scalar := ScalarCmpGeI32x16(LI32x16A, LI32x16B);
  CheckEqual(LongInt(LMask16Scalar), LongInt(LMask16Facade), 'VecI32x16CmpGe');

  LMask16Facade := nextpas.core.simd.VecI32x16CmpNe(LI32x16A, LI32x16B);
  LMask16Scalar := ScalarCmpNeI32x16(LI32x16A, LI32x16B);
  CheckEqual(LongInt(LMask16Scalar), LongInt(LMask16Facade), 'VecI32x16CmpNe');

  LI32x16Facade := VecI32x16Min(LI32x16A, LI32x16B);
  LI32x16Scalar := ScalarMinI32x16(LI32x16A, LI32x16B);
  AssertVecI32x16Equal('VecI32x16Min', LI32x16Scalar, LI32x16Facade);

  LI32x16Facade := VecI32x16Max(LI32x16A, LI32x16B);
  LI32x16Scalar := ScalarMaxI32x16(LI32x16A, LI32x16B);
  AssertVecI32x16Equal('VecI32x16Max', LI32x16Scalar, LI32x16Facade);

  LF64x2A.d[0] := -3.25;
  LF64x2A.d[1] := 8.5;
  LF64x2B.d[0] := 2.75;
  LF64x2B.d[1] := -4.0;

  CheckNear(LF64x2A.d[0], VecF64x2Extract(LF64x2A, 0), 1.0e-12, 'VecF64x2Extract lane0');
  LF64x2Inserted := VecF64x2Insert(LF64x2A, 42.125, 1);
  CheckNear(42.125, LF64x2Inserted.d[1], 1.0e-12, 'VecF64x2Insert lane1');
  CheckNear(LF64x2A.d[0], LF64x2Inserted.d[0], 1.0e-12, 'VecF64x2Insert keep lane0');

  LF64x2Facade := VecF64x2Add(LF64x2A, LF64x2B);
  LF64x2Scalar := ScalarAddF64x2(LF64x2A, LF64x2B);
  AssertVecF64x2Equal('VecF64x2Add', LF64x2Scalar, LF64x2Facade);

  LF64x2Facade := VecF64x2Sub(LF64x2A, LF64x2B);
  LF64x2Scalar := ScalarSubF64x2(LF64x2A, LF64x2B);
  AssertVecF64x2Equal('VecF64x2Sub', LF64x2Scalar, LF64x2Facade);

  LF64x2Facade := VecF64x2Div(LF64x2A, LF64x2B);
  LF64x2Scalar := ScalarDivF64x2(LF64x2A, LF64x2B);
  AssertVecF64x2Equal('VecF64x2Div', LF64x2Scalar, LF64x2Facade);

  LF64x2Facade := VecF64x2Abs(LF64x2A);
  LF64x2Scalar := ScalarAbsF64x2(LF64x2A);
  AssertVecF64x2Equal('VecF64x2Abs', LF64x2Scalar, LF64x2Facade);

  LF64x2Facade := VecF64x2Sqrt(VecF64x2Splat(9.0));
  LF64x2Scalar := ScalarSqrtF64x2(ScalarSplatF64x2(9.0));
  AssertVecF64x2Equal('VecF64x2Sqrt', LF64x2Scalar, LF64x2Facade);

  LF64x2Facade := VecF64x2Min(LF64x2A, LF64x2B);
  LF64x2Scalar := ScalarMinF64x2(LF64x2A, LF64x2B);
  AssertVecF64x2Equal('VecF64x2Min', LF64x2Scalar, LF64x2Facade);

  LF64x2Facade := VecF64x2Max(LF64x2A, LF64x2B);
  LF64x2Scalar := ScalarMaxF64x2(LF64x2A, LF64x2B);
  AssertVecF64x2Equal('VecF64x2Max', LF64x2Scalar, LF64x2Facade);

  LF64ReduceFacade := VecF64x2ReduceAdd(LF64x2A);
  LF64ReduceScalar := ScalarReduceAddF64x2(LF64x2A);
  CheckNear(LF64ReduceScalar, LF64ReduceFacade, 1.0e-12, 'VecF64x2ReduceAdd');

  LF64ReduceFacade := VecF64x2ReduceMin(LF64x2A);
  LF64ReduceScalar := ScalarReduceMinF64x2(LF64x2A);
  CheckNear(LF64ReduceScalar, LF64ReduceFacade, 1.0e-12, 'VecF64x2ReduceMin');

  LF64ReduceFacade := VecF64x2ReduceMax(LF64x2A);
  LF64ReduceScalar := ScalarReduceMaxF64x2(LF64x2A);
  CheckNear(LF64ReduceScalar, LF64ReduceFacade, 1.0e-12, 'VecF64x2ReduceMax');

  LF64ReduceFacade := VecF64x2ReduceMul(LF64x2A);
  LF64ReduceScalar := ScalarReduceMulF64x2(LF64x2A);
  CheckNear(LF64ReduceScalar, LF64ReduceFacade, 1.0e-12, 'VecF64x2ReduceMul');

  LLoadF64[0] := 1.25;
  LLoadF64[1] := -9.5;
  LF64x2Facade := VecF64x2Load(@LLoadF64[0]);
  LF64x2Scalar := ScalarLoadF64x2(@LLoadF64[0]);
  AssertVecF64x2Equal('VecF64x2Load', LF64x2Scalar, LF64x2Facade);

  VecF64x2Store(@LStoreF64Facade[0], LF64x2Facade);
  ScalarStoreF64x2(@LStoreF64Scalar[0], LF64x2Scalar);
  CheckNear(LStoreF64Scalar[0], LStoreF64Facade[0], 1.0e-12, 'VecF64x2Store lane0');
  CheckNear(LStoreF64Scalar[1], LStoreF64Facade[1], 1.0e-12, 'VecF64x2Store lane1');

  LF64x2Facade := VecF64x2Zero;
  LF64x2Scalar := ScalarZeroF64x2;
  AssertVecF64x2Equal('VecF64x2Zero', LF64x2Scalar, LF64x2Facade);

  LMask2Facade := TMask2(1);
  LF64x2Facade := VecF64x2Select(LMask2Facade, LF64x2A, LF64x2B);
  LF64x2Scalar := ScalarSelectF64x2(LMask2Facade, LF64x2A, LF64x2B);
  AssertVecF64x2Equal('VecF64x2Select', LF64x2Scalar, LF64x2Facade);

  LF64DotFacade := VecF64x2Dot(LF64x2A, LF64x2B);
  LF64DotScalar := ScalarDotF64x2(LF64x2A, LF64x2B);
  CheckNear(LF64DotScalar, LF64DotFacade, 1.0e-12, 'VecF64x2Dot');

  for LIndex := 0 to 3 do
  begin
    LI32x4A.i[LIndex] := 50 - LIndex * 17;
    LI32x4B.i[LIndex] := LIndex * 11 - 30;
  end;
  LI32x4Mask.i[0] := -1;
  LI32x4Mask.i[1] := 0;
  LI32x4Mask.i[2] := -1;
  LI32x4Mask.i[3] := 0;

  LI32x4Facade := VecI32x4Select(LI32x4Mask, LI32x4A, LI32x4B);
  LI32x4Scalar := ScalarSelectI32x4(LI32x4Mask, LI32x4A, LI32x4B);
  AssertVecI32x4Equal('VecI32x4Select', LI32x4Scalar, LI32x4Facade);

  LI32x4Facade := VecI32x4Sub(LI32x4A, LI32x4B);
  LI32x4Scalar := ScalarSubI32x4(LI32x4A, LI32x4B);
  AssertVecI32x4Equal('VecI32x4Sub', LI32x4Scalar, LI32x4Facade);

  LI32x4Facade := VecI32x4Mul(LI32x4A, LI32x4B);
  LI32x4Scalar := ScalarMulI32x4(LI32x4A, LI32x4B);
  AssertVecI32x4Equal('VecI32x4Mul', LI32x4Scalar, LI32x4Facade);

  LI32x4Facade := VecI32x4And(LI32x4A, LI32x4B);
  LI32x4Scalar := ScalarAndI32x4(LI32x4A, LI32x4B);
  AssertVecI32x4Equal('VecI32x4And', LI32x4Scalar, LI32x4Facade);

  LI32x4Facade := VecI32x4Or(LI32x4A, LI32x4B);
  LI32x4Scalar := ScalarOrI32x4(LI32x4A, LI32x4B);
  AssertVecI32x4Equal('VecI32x4Or', LI32x4Scalar, LI32x4Facade);

  LI32x4Facade := VecI32x4Xor(LI32x4A, LI32x4B);
  LI32x4Scalar := ScalarXorI32x4(LI32x4A, LI32x4B);
  AssertVecI32x4Equal('VecI32x4Xor', LI32x4Scalar, LI32x4Facade);

  LI32x4Facade := VecI32x4Not(LI32x4A);
  LI32x4Scalar := ScalarNotI32x4(LI32x4A);
  AssertVecI32x4Equal('VecI32x4Not', LI32x4Scalar, LI32x4Facade);

  LI32x4Facade := VecI32x4AndNot(LI32x4A, LI32x4B);
  LI32x4Scalar := ScalarAndNotI32x4(LI32x4A, LI32x4B);
  AssertVecI32x4Equal('VecI32x4AndNot', LI32x4Scalar, LI32x4Facade);

  LI32x4Facade := VecI32x4ShiftLeft(LI32x4A, 2);
  LI32x4Scalar := ScalarShiftLeftI32x4(LI32x4A, 2);
  AssertVecI32x4Equal('VecI32x4ShiftLeft', LI32x4Scalar, LI32x4Facade);

  LI32x4Facade := VecI32x4ShiftRight(LI32x4A, 2);
  LI32x4Scalar := ScalarShiftRightI32x4(LI32x4A, 2);
  AssertVecI32x4Equal('VecI32x4ShiftRight', LI32x4Scalar, LI32x4Facade);

  LI32x4Facade := VecI32x4ShiftRightArith(LI32x4A, 2);
  LI32x4Scalar := ScalarShiftRightArithI32x4(LI32x4A, 2);
  AssertVecI32x4Equal('VecI32x4ShiftRightArith', LI32x4Scalar, LI32x4Facade);

  LMask4Facade := VecI32x4CmpLt(LI32x4A, LI32x4B);
  LMask4Scalar := ScalarCmpLtI32x4(LI32x4A, LI32x4B);
  CheckEqual(Integer(LMask4Scalar), Integer(LMask4Facade), 'VecI32x4CmpLt');

  LMask4Facade := VecI32x4CmpGt(LI32x4A, LI32x4B);
  LMask4Scalar := ScalarCmpGtI32x4(LI32x4A, LI32x4B);
  CheckEqual(Integer(LMask4Scalar), Integer(LMask4Facade), 'VecI32x4CmpGt');

  LMask4Facade := VecI32x4CmpLe(LI32x4A, LI32x4B);
  LMask4Scalar := ScalarCmpLeI32x4(LI32x4A, LI32x4B);
  CheckEqual(Integer(LMask4Scalar), Integer(LMask4Facade), 'VecI32x4CmpLe');

  LMask4Facade := VecI32x4CmpGe(LI32x4A, LI32x4B);
  LMask4Scalar := ScalarCmpGeI32x4(LI32x4A, LI32x4B);
  CheckEqual(Integer(LMask4Scalar), Integer(LMask4Facade), 'VecI32x4CmpGe');

  LMask4Facade := VecI32x4CmpNe(LI32x4A, LI32x4B);
  LMask4Scalar := ScalarCmpNeI32x4(LI32x4A, LI32x4B);
  CheckEqual(Integer(LMask4Scalar), Integer(LMask4Facade), 'VecI32x4CmpNe');

  LI32x4Facade := VecI32x4Min(LI32x4A, LI32x4B);
  LI32x4Scalar := ScalarMinI32x4(LI32x4A, LI32x4B);
  AssertVecI32x4Equal('VecI32x4Min', LI32x4Scalar, LI32x4Facade);

  LI32x4Facade := VecI32x4Max(LI32x4A, LI32x4B);
  LI32x4Scalar := ScalarMaxI32x4(LI32x4A, LI32x4B);
  AssertVecI32x4Equal('VecI32x4Max', LI32x4Scalar, LI32x4Facade);

  LI64x4A.i[0] := Int64(-1000);
  LI64x4A.i[1] := Int64(7777777);
  LI64x4A.i[2] := Int64(-1234567890123);
  LI64x4A.i[3] := Int64(42);
  LI64x4B.i[0] := Int64(13);
  LI64x4B.i[1] := Int64(-9);
  LI64x4B.i[2] := Int64(3000);
  LI64x4B.i[3] := Int64(-500);

  CheckEqual(LI64x4A.i[2], VecI64x4Extract(LI64x4A, 2), 'VecI64x4Extract lane2');
  LI64x4Inserted := VecI64x4Insert(LI64x4A, Int64(88888888), 1);
  CheckEqual(Int64(88888888), LI64x4Inserted.i[1], 'VecI64x4Insert lane1');
  CheckEqual(LI64x4A.i[2], LI64x4Inserted.i[2], 'VecI64x4Insert keep lane2');

  LI64x4Facade := VecI64x4Add(LI64x4A, LI64x4B);
  LI64x4Scalar := ScalarAddI64x4(LI64x4A, LI64x4B);
  AssertVecI64x4Equal('VecI64x4Add', LI64x4Scalar, LI64x4Facade);

  LI64x4Facade := VecI64x4Sub(LI64x4A, LI64x4B);
  LI64x4Scalar := ScalarSubI64x4(LI64x4A, LI64x4B);
  AssertVecI64x4Equal('VecI64x4Sub', LI64x4Scalar, LI64x4Facade);

  LI64x4Facade := VecI64x4And(LI64x4A, LI64x4B);
  LI64x4Scalar := ScalarAndI64x4(LI64x4A, LI64x4B);
  AssertVecI64x4Equal('VecI64x4And', LI64x4Scalar, LI64x4Facade);

  LI64x4Facade := VecI64x4Or(LI64x4A, LI64x4B);
  LI64x4Scalar := ScalarOrI64x4(LI64x4A, LI64x4B);
  AssertVecI64x4Equal('VecI64x4Or', LI64x4Scalar, LI64x4Facade);

  LI64x4Facade := VecI64x4Xor(LI64x4A, LI64x4B);
  LI64x4Scalar := ScalarXorI64x4(LI64x4A, LI64x4B);
  AssertVecI64x4Equal('VecI64x4Xor', LI64x4Scalar, LI64x4Facade);

  LI64x4Facade := VecI64x4Not(LI64x4A);
  LI64x4Scalar := ScalarNotI64x4(LI64x4A);
  AssertVecI64x4Equal('VecI64x4Not', LI64x4Scalar, LI64x4Facade);

  LI64x4Facade := VecI64x4ShiftRight(LI64x4A, 3);
  LI64x4Scalar := ScalarShiftRightI64x4(LI64x4A, 3);
  AssertVecI64x4Equal('VecI64x4ShiftRight', LI64x4Scalar, LI64x4Facade);

  LI64x4Facade := VecI64x4ShiftRightArith(LI64x4A, 3);
  LI64x4Scalar := ScalarShiftRightArithI64x4(LI64x4A, 3);
  AssertVecI64x4Equal('VecI64x4ShiftRightArith', LI64x4Scalar, LI64x4Facade);

  LMask4Facade := VecI64x4CmpLe(LI64x4A, LI64x4B);
  LMask4Scalar := ScalarCmpLeI64x4(LI64x4A, LI64x4B);
  CheckEqual(Integer(LMask4Scalar), Integer(LMask4Facade), 'VecI64x4CmpLe');

  LMask4Facade := VecI64x4CmpGe(LI64x4A, LI64x4B);
  LMask4Scalar := ScalarCmpGeI64x4(LI64x4A, LI64x4B);
  CheckEqual(Integer(LMask4Scalar), Integer(LMask4Facade), 'VecI64x4CmpGe');

  LMask4Facade := VecI64x4CmpNe(LI64x4A, LI64x4B);
  LMask4Scalar := ScalarCmpNeI64x4(LI64x4A, LI64x4B);
  CheckEqual(Integer(LMask4Scalar), Integer(LMask4Facade), 'VecI64x4CmpNe');

  LLoadI64x4[0] := Int64(11);
  LLoadI64x4[1] := Int64(-22);
  LLoadI64x4[2] := Int64(33);
  LLoadI64x4[3] := Int64(-44);
  LI64x4Facade := VecI64x4Load(@LLoadI64x4[0]);
  LI64x4Scalar := ScalarLoadI64x4(@LLoadI64x4[0]);
  AssertVecI64x4Equal('VecI64x4Load', LI64x4Scalar, LI64x4Facade);

  VecI64x4Store(@LStoreI64x4Facade[0], LI64x4Facade);
  ScalarStoreI64x4(@LStoreI64x4Scalar[0], LI64x4Scalar);
  for LIndex := 0 to 3 do
    CheckEqual(LStoreI64x4Scalar[LIndex], LStoreI64x4Facade[LIndex], 'VecI64x4Store lane ' + IntToStr(LIndex));

  LI64x4Facade := VecI64x4Splat(Int64(-12345));
  LI64x4Scalar := ScalarSplatI64x4(Int64(-12345));
  AssertVecI64x4Equal('VecI64x4Splat', LI64x4Scalar, LI64x4Facade);

  LI64x4Facade := VecI64x4Zero;
  LI64x4Scalar := ScalarZeroI64x4;
  AssertVecI64x4Equal('VecI64x4Zero', LI64x4Scalar, LI64x4Facade);

  LI64x2A.i[0] := Int64(-4567890);
  LI64x2A.i[1] := Int64(1234567);
  LI64x2B.i[0] := Int64(9999);
  LI64x2B.i[1] := Int64(-8888);

  CheckEqual(LI64x2A.i[1], VecI64x2Extract(LI64x2A, 1), 'VecI64x2Extract lane1');
  LI64x2Inserted := VecI64x2Insert(LI64x2A, Int64(55555), 0);
  CheckEqual(Int64(55555), LI64x2Inserted.i[0], 'VecI64x2Insert lane0');
  CheckEqual(LI64x2A.i[1], LI64x2Inserted.i[1], 'VecI64x2Insert keep lane1');

  LI64x2Facade := VecI64x2Add(LI64x2A, LI64x2B);
  LI64x2Scalar := ScalarAddI64x2(LI64x2A, LI64x2B);
  AssertVecI64x2Equal('VecI64x2Add', LI64x2Scalar, LI64x2Facade);

  LI64x2Facade := VecI64x2Sub(LI64x2A, LI64x2B);
  LI64x2Scalar := ScalarSubI64x2(LI64x2A, LI64x2B);
  AssertVecI64x2Equal('VecI64x2Sub', LI64x2Scalar, LI64x2Facade);

  LI64x2Facade := VecI64x2And(LI64x2A, LI64x2B);
  LI64x2Scalar := ScalarAndI64x2(LI64x2A, LI64x2B);
  AssertVecI64x2Equal('VecI64x2And', LI64x2Scalar, LI64x2Facade);

  LI64x2Facade := VecI64x2Or(LI64x2A, LI64x2B);
  LI64x2Scalar := ScalarOrI64x2(LI64x2A, LI64x2B);
  AssertVecI64x2Equal('VecI64x2Or', LI64x2Scalar, LI64x2Facade);

  LI64x2Facade := VecI64x2Xor(LI64x2A, LI64x2B);
  LI64x2Scalar := ScalarXorI64x2(LI64x2A, LI64x2B);
  AssertVecI64x2Equal('VecI64x2Xor', LI64x2Scalar, LI64x2Facade);

  LI64x2Facade := VecI64x2Not(LI64x2A);
  LI64x2Scalar := ScalarNotI64x2(LI64x2A);
  AssertVecI64x2Equal('VecI64x2Not', LI64x2Scalar, LI64x2Facade);

  LMask2Facade := VecI64x2CmpEq(LI64x2A, LI64x2B);
  LMask2Scalar := ScalarCmpEqI64x2(LI64x2A, LI64x2B);
  CheckEqual(Integer(LMask2Scalar), Integer(LMask2Facade), 'VecI64x2CmpEq');

  LMask2Facade := VecI64x2CmpLt(LI64x2A, LI64x2B);
  LMask2Scalar := ScalarCmpLtI64x2(LI64x2A, LI64x2B);
  CheckEqual(Integer(LMask2Scalar), Integer(LMask2Facade), 'VecI64x2CmpLt');

  LMask2Facade := VecI64x2CmpGt(LI64x2A, LI64x2B);
  LMask2Scalar := ScalarCmpGtI64x2(LI64x2A, LI64x2B);
  CheckEqual(Integer(LMask2Scalar), Integer(LMask2Facade), 'VecI64x2CmpGt');

  LMask2Facade := VecI64x2CmpLe(LI64x2A, LI64x2B);
  LMask2Scalar := ScalarCmpLeI64x2(LI64x2A, LI64x2B);
  CheckEqual(Integer(LMask2Scalar), Integer(LMask2Facade), 'VecI64x2CmpLe');

  LMask2Facade := VecI64x2CmpGe(LI64x2A, LI64x2B);
  LMask2Scalar := ScalarCmpGeI64x2(LI64x2A, LI64x2B);
  CheckEqual(Integer(LMask2Scalar), Integer(LMask2Facade), 'VecI64x2CmpGe');

  LMask2Facade := VecI64x2CmpNe(LI64x2A, LI64x2B);
  LMask2Scalar := ScalarCmpNeI64x2(LI64x2A, LI64x2B);
  CheckEqual(Integer(LMask2Scalar), Integer(LMask2Facade), 'VecI64x2CmpNe');
end;

procedure TTestCase_DispatchAPIParity.Test_SSE2_I32x4_U32x4_Mul_Use_NonScalar_Impl_And_Keep_Parity;
var
  LSSE2Table: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LI32A, LI32B: TVecI32x4;
  LI32Actual, LI32Expected: TVecI32x4;
  LU32A, LU32B: TVecU32x4;
  LU32Actual, LU32Expected: TVecU32x4;
  LSourcePath: string;
  LI386SourcePath: string;
  LMulI32Source: string;
  LMulU32Source: string;
  LMulI32I386Source: string;
  LSourceLines: TSourceLines;
  LIndex: Integer;

  procedure AssertVecI32x4Equal(const aOp: string; const aExpected, aActual: TVecI32x4);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aOp + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecU32x4Equal(const aOp: string; const aExpected, aActual: TVecU32x4);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckEqual(QWord(aExpected.u[LLane]), QWord(aActual.u[LLane]), aOp + ' lane ' + IntToStr(LLane));
  end;

  function ExtractFunctionSource(aLines: TSourceLines; const aName: string): string;
  var
    LLine: string;
    LIndexLocal: Integer;
    LFound: Boolean;
    LHasBody: Boolean;
  begin
    Result := '';
    LFound := False;
    LHasBody := False;
    for LIndexLocal := 0 to aLines.Count - 1 do
    begin
      LLine := TrimLeft(aLines[LIndexLocal]);
      if not LFound then
      begin
        if Pos('function ' + aName + '(', LLine) = 1 then
          LFound := True
        else
          Continue;
      end
      else if (Pos('function ', LLine) = 1) or (Pos('procedure ', LLine) = 1) then
      begin
        LHasBody := Pos('begin', LowerCase(Result)) > 0;
        if LHasBody then
          Break;

        Result := '';
        if Pos('function ' + aName + '(', LLine) = 1 then
        begin
          Result := aLines[LIndexLocal];
          Continue;
        end;
        LFound := False;
        Continue;
      end;

      if Result <> '' then
        Result := Result + LineEnding;
      Result := Result + aLines[LIndexLocal];
    end;

    CheckTrue(LFound, 'Unable to locate function source for ' + aName);
    CheckTrue(Pos('begin', LowerCase(Result)) > 0, 'Unable to locate implementation body for ' + aName);
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  LSourceLines := TSourceLines.Create;
  try
    LSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.sse2.pas');
    CheckTrue(FileExists(LSourcePath), 'SSE2 source file should exist for implementation-shape audit: ' + LSourcePath);
    LSourceLines.LoadFromFile(LSourcePath);
    LMulI32Source := LowerCase(ExtractFunctionSource(LSourceLines, 'SSE2MulI32x4'));
    LMulU32Source := LowerCase(ExtractFunctionSource(LSourceLines, 'SSE2MulU32x4'));

    LI386SourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.sse2.i386.pas');
    CheckTrue(FileExists(LI386SourcePath), 'SSE2 i386 source file should exist for implementation-shape audit: ' + LI386SourcePath);
    LSourceLines.LoadFromFile(LI386SourcePath);
    LMulI32I386Source := LowerCase(ExtractFunctionSource(LSourceLines, 'SSE2MulI32x4_i386'));
  finally
    LSourceLines.Free;
  end;

  CheckTrue(Pos('pmuludq', LMulI32Source) > 0, 'SSE2MulI32x4 should use pmuludq-based decomposition instead of a scalar loop');
  CheckTrue(Pos('for i := 0 to 3 do', LMulI32Source) = 0, 'SSE2MulI32x4 should not keep the scalar loop fallback body');
  CheckTrue(Pos('pmuludq', LMulU32Source) > 0, 'SSE2MulU32x4 should keep pmuludq-based decomposition');
  CheckTrue(Pos('顺序检查', LMulU32Source) = 0, 'SSE2MulU32x4 should not keep unresolved lane-order audit comments');
  CheckTrue(Pos('scalar fallback', LMulU32Source) = 0, 'SSE2MulU32x4 should not advertise scalar fallback in the implementation body');
  CheckTrue(Pos('pmuludq', LMulI32I386Source) > 0, 'SSE2MulI32x4_i386 should use pmuludq-based decomposition instead of a scalar loop');
  CheckTrue(Pos('for j := 0 to 3 do', LMulI32I386Source) = 0, 'SSE2MulI32x4_i386 should not keep the scalar loop fallback body');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  if not TryGetRegisteredBackendDispatchTable(sbSSE2, LSSE2Table) then
    Exit;

  CheckTrue(Assigned(LSSE2Table.CoreVectors.MulI32x4), 'SSE2 MulI32x4 should be assigned');
  CheckTrue(Assigned(LSSE2Table.CoreVectors.MulU32x4), 'SSE2 MulU32x4 should be assigned');
  CheckTrue(Pointer(LSSE2Table.CoreVectors.MulI32x4) <> Pointer(LScalarTable.CoreVectors.MulI32x4), 'SSE2 MulI32x4 should not remain scalar fallback when vector asm is enabled');
  CheckTrue(Pointer(LSSE2Table.CoreVectors.MulU32x4) <> Pointer(LScalarTable.CoreVectors.MulU32x4), 'SSE2 MulU32x4 should not remain scalar fallback when vector asm is enabled');

  LI32A.i[0] := -1;
  LI32A.i[1] := 12345;
  LI32A.i[2] := -123456789;
  LI32A.i[3] := High(Integer);
  LI32B.i[0] := 2;
  LI32B.i[1] := -6789;
  LI32B.i[2] := 17;
  LI32B.i[3] := -3;

  LU32A.u[0] := DWord($FFFFFFFF);
  LU32A.u[1] := DWord($80000000);
  LU32A.u[2] := DWord($01020304);
  LU32A.u[3] := DWord($13579BDF);
  LU32B.u[0] := 2;
  LU32B.u[1] := 3;
  LU32B.u[2] := DWord($10203040);
  LU32B.u[3] := DWord($02468ACE);

  LI32Expected := ScalarMulI32x4(LI32A, LI32B);
  LI32Actual := LSSE2Table.CoreVectors.MulI32x4(LI32A, LI32B);
  AssertVecI32x4Equal('SSE2 MulI32x4 parity', LI32Expected, LI32Actual);

  LU32Expected := ScalarMulU32x4(LU32A, LU32B);
  LU32Actual := LSSE2Table.CoreVectors.MulU32x4(LU32A, LU32B);
  AssertVecU32x4Equal('SSE2 MulU32x4 parity', LU32Expected, LU32Actual);

  for LIndex := 0 to 3 do
    CheckEqual(QWord(LU32Expected.u[LIndex]), QWord(LU32Actual.u[LIndex]), 'SSE2 MulU32x4 should keep lane order ' + IntToStr(LIndex));
end;

procedure TTestCase_DispatchAPIParity.Test_SSE2_I64x2_Compare_Use_NonScalar_Impl_And_Keep_Parity;
var
  LSSE2Table: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LCurrentDispatch: PSimdDispatchTable;
  LCanRunSSE2: Boolean;
  LEqA, LEqB: TVecI64x2;
  LGtMask1A, LGtMask1B: TVecI64x2;
  LGtMask2A, LGtMask2B: TVecI64x2;
  LMaskExpected, LMaskActual: TMask2;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  if not TryGetRegisteredBackendDispatchTable(sbSSE2, LSSE2Table) then
    Exit;

  CheckTrue(Assigned(LSSE2Table.CoreVectors.CmpEqI64x2), 'SSE2 CmpEqI64x2 should be assigned');
  CheckTrue(Assigned(LSSE2Table.CoreVectors.CmpGtI64x2), 'SSE2 CmpGtI64x2 should be assigned');
  CheckTrue(Pointer(LSSE2Table.CoreVectors.CmpEqI64x2) <> Pointer(LScalarTable.CoreVectors.CmpEqI64x2), 'SSE2 CmpEqI64x2 should not remain scalar fallback when vector asm is enabled');
  CheckTrue(Pointer(LSSE2Table.CoreVectors.CmpGtI64x2) <> Pointer(LScalarTable.CoreVectors.CmpGtI64x2), 'SSE2 CmpGtI64x2 should not remain scalar fallback when vector asm is enabled');

  LCanRunSSE2 := LSSE2Table.BackendInfo.Available and TrySetActiveBackend(sbSSE2);
  if not LCanRunSSE2 then
    Exit;

  LCurrentDispatch := GetDispatchTable;
  CheckEqual(Ord(sbSSE2), Ord(GetActiveBackend), 'Active backend should be SSE2 for compare parity');
  CheckEqual(Ord(sbSSE2), Ord(LCurrentDispatch^.Backend), 'Current dispatch table should resolve to SSE2 after forcing the backend');

  LEqA.i[0] := (Int64(1) shl 32) or Int64($80000000);
  LEqA.i[1] := -2147483648;
  LEqB.i[0] := (Int64(1) shl 32) or Int64($80000000);
  LEqB.i[1] := -2147483647;

  LGtMask1A.i[0] := (Int64(1) shl 32) or Int64($80000000);
  LGtMask1A.i[1] := -2147483648;
  LGtMask1B.i[0] := (Int64(1) shl 32) or Int64($7FFFFFFF);
  LGtMask1B.i[1] := -2147483647;

  LGtMask2A.i[0] := (Int64(1) shl 32) or Int64($7FFFFFFF);
  LGtMask2A.i[1] := -2147483647;
  LGtMask2B.i[0] := (Int64(1) shl 32) or Int64($80000000);
  LGtMask2B.i[1] := -2147483648;

  LMaskExpected := ScalarCmpEqI64x2(LEqA, LEqB);
  LMaskActual := LCurrentDispatch^.CoreVectors.CmpEqI64x2(LEqA, LEqB);
  CheckEqual(Integer(LMaskExpected), Integer(LMaskActual), 'SSE2 CmpEqI64x2 scalar parity');

  LMaskExpected := ScalarCmpGtI64x2(LGtMask1A, LGtMask1B);
  LMaskActual := LCurrentDispatch^.CoreVectors.CmpGtI64x2(LGtMask1A, LGtMask1B);
  CheckEqual(Integer(LMaskExpected), Integer(LMaskActual), 'SSE2 CmpGtI64x2 scalar parity mask1');

  LMaskExpected := ScalarCmpGtI64x2(LGtMask2A, LGtMask2B);
  LMaskActual := LCurrentDispatch^.CoreVectors.CmpGtI64x2(LGtMask2A, LGtMask2B);
  CheckEqual(Integer(LMaskExpected), Integer(LMaskActual), 'SSE2 CmpGtI64x2 scalar parity mask2');
end;

procedure TTestCase_DispatchAPIParity.Test_SSE2_F32VectorMath_Use_NonScalar_Impl_And_Keep_Parity;
var
  LSSE2Table: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LCurrentDispatch: PSimdDispatchTable;
  LCanRunSSE2: Boolean;
  LRoundInput: TVecF32x4;
  LRoundExpected, LRoundActual: TVecF32x4;
  LLengthInput: TVecF32x4;
  LLength4Expected, LLength4Actual: Single;
  LLength3Expected, LLength3Actual: Single;
  LNormalize4Input, LNormalize4ZeroInput: TVecF32x4;
  LNormalize4Expected, LNormalize4Actual: TVecF32x4;
  LNormalize4ZeroExpected, LNormalize4ZeroActual: TVecF32x4;
  LNormalize3Input, LNormalize3ZeroInput: TVecF32x4;
  LNormalize3Expected, LNormalize3Actual: TVecF32x4;
  LNormalize3ZeroExpected, LNormalize3ZeroActual: TVecF32x4;
  LDotA, LDotB: TVecF32x4;
  LDotExpected, LDotActual: Single;
  LCrossA, LCrossB: TVecF32x4;
  LCrossExpected, LCrossActual: TVecF32x4;

  procedure AssertVecF32x4Equal(const aLabel: string; const aExpected, aActual: TVecF32x4; const aEps: Single);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckNear(aExpected.f[LLane], aActual.f[LLane], aEps, aLabel + ' lane ' + IntToStr(LLane));
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  if not TryGetRegisteredBackendDispatchTable(sbSSE2, LSSE2Table) then
    Exit;

  CheckTrue(Assigned(LSSE2Table.CoreVectors.RoundF32x4), 'SSE2 RoundF32x4 should be assigned');
  CheckTrue(Assigned(LSSE2Table.CoreVectors.LengthF32x4), 'SSE2 LengthF32x4 should be assigned');
  CheckTrue(Assigned(LSSE2Table.CoreVectors.LengthF32x3), 'SSE2 LengthF32x3 should be assigned');
  CheckTrue(Assigned(LSSE2Table.CoreVectors.NormalizeF32x4), 'SSE2 NormalizeF32x4 should be assigned');
  CheckTrue(Assigned(LSSE2Table.CoreVectors.NormalizeF32x3), 'SSE2 NormalizeF32x3 should be assigned');
  CheckTrue(Assigned(LSSE2Table.CoreVectors.DotF32x3), 'SSE2 DotF32x3 should be assigned');
  CheckTrue(Assigned(LSSE2Table.CoreVectors.CrossF32x3), 'SSE2 CrossF32x3 should be assigned');
  CheckTrue(Pointer(LSSE2Table.CoreVectors.RoundF32x4) <> Pointer(LScalarTable.CoreVectors.RoundF32x4), 'SSE2 RoundF32x4 should not remain scalar fallback when vector asm is enabled');
  CheckTrue(Pointer(LSSE2Table.CoreVectors.LengthF32x4) <> Pointer(LScalarTable.CoreVectors.LengthF32x4), 'SSE2 LengthF32x4 should not remain scalar fallback when vector asm is enabled');
  CheckTrue(Pointer(LSSE2Table.CoreVectors.LengthF32x3) <> Pointer(LScalarTable.CoreVectors.LengthF32x3), 'SSE2 LengthF32x3 should not remain scalar fallback when vector asm is enabled');
  CheckTrue(Pointer(LSSE2Table.CoreVectors.NormalizeF32x4) <> Pointer(LScalarTable.CoreVectors.NormalizeF32x4), 'SSE2 NormalizeF32x4 should not remain scalar fallback when vector asm is enabled');
  CheckTrue(Pointer(LSSE2Table.CoreVectors.NormalizeF32x3) <> Pointer(LScalarTable.CoreVectors.NormalizeF32x3), 'SSE2 NormalizeF32x3 should not remain scalar fallback when vector asm is enabled');
  CheckTrue(Pointer(LSSE2Table.CoreVectors.DotF32x3) <> Pointer(LScalarTable.CoreVectors.DotF32x3), 'SSE2 DotF32x3 should not remain scalar fallback when vector asm is enabled');
  CheckTrue(Pointer(LSSE2Table.CoreVectors.CrossF32x3) <> Pointer(LScalarTable.CoreVectors.CrossF32x3), 'SSE2 CrossF32x3 should not remain scalar fallback when vector asm is enabled');

  LCanRunSSE2 := LSSE2Table.BackendInfo.Available and TrySetActiveBackend(sbSSE2);
  if not LCanRunSSE2 then
    Exit;

  LCurrentDispatch := GetDispatchTable;
  CheckEqual(Ord(sbSSE2), Ord(GetActiveBackend), 'Active backend should be SSE2 for vector-math parity');
  CheckEqual(Ord(sbSSE2), Ord(LCurrentDispatch^.Backend), 'Current dispatch table should resolve to SSE2 after forcing the backend');

  LRoundInput.f[0] := 2.5;
  LRoundInput.f[1] := 3.5;
  LRoundInput.f[2] := -2.5;
  LRoundInput.f[3] := -3.5;

  LLengthInput.f[0] := 0.0;
  LLengthInput.f[1] := 4.0;
  LLengthInput.f[2] := 0.0;
  LLengthInput.f[3] := 99.0;

  LNormalize4Input.f[0] := 0.0;
  LNormalize4Input.f[1] := 0.0;
  LNormalize4Input.f[2] := 0.0;
  LNormalize4Input.f[3] := 5.0;
  LNormalize4ZeroInput.f[0] := 0.0;
  LNormalize4ZeroInput.f[1] := 0.0;
  LNormalize4ZeroInput.f[2] := 0.0;
  LNormalize4ZeroInput.f[3] := 0.0;

  LNormalize3Input.f[0] := 0.0;
  LNormalize3Input.f[1] := 4.0;
  LNormalize3Input.f[2] := 0.0;
  LNormalize3Input.f[3] := 99.0;
  LNormalize3ZeroInput.f[0] := 0.0;
  LNormalize3ZeroInput.f[1] := 0.0;
  LNormalize3ZeroInput.f[2] := 0.0;
  LNormalize3ZeroInput.f[3] := 17.0;

  LDotA.f[0] := 1.5;
  LDotA.f[1] := -2.0;
  LDotA.f[2] := 3.25;
  LDotA.f[3] := 99.0;
  LDotB.f[0] := -4.0;
  LDotB.f[1] := 5.5;
  LDotB.f[2] := -6.0;
  LDotB.f[3] := 777.0;

  LCrossA.f[0] := 2.0;
  LCrossA.f[1] := 3.0;
  LCrossA.f[2] := 5.0;
  LCrossA.f[3] := 99.0;
  LCrossB.f[0] := 7.0;
  LCrossB.f[1] := 11.0;
  LCrossB.f[2] := 13.0;
  LCrossB.f[3] := 123.0;

  LRoundExpected := ScalarRoundF32x4(LRoundInput);
  LRoundActual := LCurrentDispatch^.CoreVectors.RoundF32x4(LRoundInput);
  AssertVecF32x4Equal('SSE2 RoundF32x4 scalar parity', LRoundExpected, LRoundActual, 0.0);

  LLength4Expected := ScalarLengthF32x4(LLengthInput);
  LLength4Actual := LCurrentDispatch^.CoreVectors.LengthF32x4(LLengthInput);
  CheckNear(LLength4Expected, LLength4Actual, 1e-5, 'SSE2 LengthF32x4 scalar parity');

  LLength3Expected := ScalarLengthF32x3(LLengthInput);
  LLength3Actual := LCurrentDispatch^.CoreVectors.LengthF32x3(LLengthInput);
  CheckNear(LLength3Expected, LLength3Actual, 1e-5, 'SSE2 LengthF32x3 scalar parity');

  LDotExpected := ScalarDotF32x3(LDotA, LDotB);
  LDotActual := LCurrentDispatch^.CoreVectors.DotF32x3(LDotA, LDotB);
  CheckNear(LDotExpected, LDotActual, 0.0, 'SSE2 DotF32x3 scalar parity');

  LCrossExpected := ScalarCrossF32x3(LCrossA, LCrossB);
  LCrossActual := LCurrentDispatch^.CoreVectors.CrossF32x3(LCrossA, LCrossB);
  AssertVecF32x4Equal('SSE2 CrossF32x3 scalar parity', LCrossExpected, LCrossActual, 0.0);

  LNormalize4Expected := ScalarNormalizeF32x4(LNormalize4Input);
  LNormalize4Actual := LCurrentDispatch^.CoreVectors.NormalizeF32x4(LNormalize4Input);
  AssertVecF32x4Equal('SSE2 NormalizeF32x4 scalar parity', LNormalize4Expected, LNormalize4Actual, 0.0);

  LNormalize4ZeroExpected := ScalarNormalizeF32x4(LNormalize4ZeroInput);
  LNormalize4ZeroActual := LCurrentDispatch^.CoreVectors.NormalizeF32x4(LNormalize4ZeroInput);
  AssertVecF32x4Equal('SSE2 NormalizeF32x4 zero scalar parity', LNormalize4ZeroExpected, LNormalize4ZeroActual, 0.0);

  LNormalize3Expected := ScalarNormalizeF32x3(LNormalize3Input);
  LNormalize3Actual := LCurrentDispatch^.CoreVectors.NormalizeF32x3(LNormalize3Input);
  AssertVecF32x4Equal('SSE2 NormalizeF32x3 scalar parity', LNormalize3Expected, LNormalize3Actual, 0.0);

  LNormalize3ZeroExpected := ScalarNormalizeF32x3(LNormalize3ZeroInput);
  LNormalize3ZeroActual := LCurrentDispatch^.CoreVectors.NormalizeF32x3(LNormalize3ZeroInput);
  AssertVecF32x4Equal('SSE2 NormalizeF32x3 zero scalar parity', LNormalize3ZeroExpected, LNormalize3ZeroActual, 0.0);
end;

procedure TTestCase_DispatchAPIParity.Test_BacklogParityAndSmoke_Batch3;
var
  LIndex: Integer;
  LDotF32x8Facade, LDotF32x8Scalar: Single;
  LDotF64x4Facade, LDotF64x4Scalar: Double;

  LF32x4A, LF32x4B, LF32x4Loaded, LF32x4Selected: TVecF32x4;
  LF32x8A, LF32x8B, LF32x8Facade, LF32x8Scalar, LF32x8Inserted: TVecF32x8;
  LF64x4A, LF64x4B, LF64x4Facade, LF64x4Scalar, LF64x4Inserted: TVecF64x4;
  LI32x8A, LI32x8Inserted: TVecI32x8;
  LF32x16A, LF32x16B, LF32x16Facade, LF32x16Scalar, LF32x16Inserted: TVecF32x16;

  LU64x2A, LU64x2B, LU64x2Facade, LU64x2Scalar: TVecU64x2;
  LU32x4A, LU32x4B, LU32x4Facade, LU32x4Scalar: TVecU32x4;
  LU64x4A, LU64x4B, LU64x4Facade, LU64x4Scalar: TVecU64x4;
  LU16x8A, LU16x8B, LU16x8Facade, LU16x8Scalar: TVecU16x8;
  LF64x8A, LF64x8B, LF64x8Facade, LF64x8Scalar: TVecF64x8;
  LI64x8A, LI64x8B, LI64x8Facade, LI64x8Scalar: TVecI64x8;

  LMask4: TMask4;
  LMask4Facade, LMask4Scalar: TMask4;
  LMaskF32x8: TVecU32x8;
  LMaskF64x4: TVecU64x4;

  LAligned: Pointer;
  LMisaligned: Pointer;
  LAlignedF32: PSingle;

  LBackendInfo: TSimdBackendInfo;
  LAvailableBackends: TSimdBackendArray;

  procedure AssertVecF32x8Equal(const aOp: string; const aExpected, aActual: TVecF32x8);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 7 do
      CheckNear(aExpected.f[LLane], aActual.f[LLane], 1.0e-6, aOp + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecF64x4Equal(const aOp: string; const aExpected, aActual: TVecF64x4);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckNear(aExpected.d[LLane], aActual.d[LLane], 1.0e-12, aOp + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecF32x16Equal(const aOp: string; const aExpected, aActual: TVecF32x16);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 15 do
      CheckNear(aExpected.f[LLane], aActual.f[LLane], 1.0e-5, aOp + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecU64x2Equal(const aOp: string; const aExpected, aActual: TVecU64x2);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 1 do
      CheckEqual(aExpected.u[LLane], aActual.u[LLane], aOp + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecU64x4Equal(const aOp: string; const aExpected, aActual: TVecU64x4);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckEqual(aExpected.u[LLane], aActual.u[LLane], aOp + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecU16x8Equal(const aOp: string; const aExpected, aActual: TVecU16x8);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 7 do
      CheckEqual(aExpected.u[LLane], aActual.u[LLane], aOp + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecF64x8Equal(const aOp: string; const aExpected, aActual: TVecF64x8);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 7 do
      CheckNear(aExpected.d[LLane], aActual.d[LLane], 1.0e-12, aOp + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecI64x8Equal(const aOp: string; const aExpected, aActual: TVecI64x8);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 7 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aOp + ' lane ' + IntToStr(LLane));
  end;
begin
  for LIndex := 0 to 7 do
  begin
    LF32x8A.f[LIndex] := (LIndex + 1) * 1.25;
    LF32x8B.f[LIndex] := (8 - LIndex) * 0.75;
    LMaskF32x8.u[LIndex] := DWord((LIndex mod 2) * $FFFFFFFF);
  end;

  LDotF32x8Facade := nextpas.core.simd.VecF32x8Dot(LF32x8A, LF32x8B);
  LDotF32x8Scalar := ScalarDotF32x8(LF32x8A, LF32x8B);
  CheckNear(LDotF32x8Scalar, LDotF32x8Facade, 1.0e-6, 'VecF32x8Dot');

  CheckNear(LF32x8A.f[3], nextpas.core.simd.VecF32x8Extract(LF32x8A, 3), 1.0e-6, 'VecF32x8Extract lane3');
  LF32x8Inserted := nextpas.core.simd.VecF32x8Insert(LF32x8A, 123.5, 4);
  CheckNear(123.5, LF32x8Inserted.f[4], 1.0e-6, 'VecF32x8Insert lane4');
  CheckNear(LF32x8A.f[3], LF32x8Inserted.f[3], 1.0e-6, 'VecF32x8Insert keep lane3');

  LF32x8Facade := nextpas.core.simd.VecF32x8Select(LMaskF32x8, LF32x8A, LF32x8B);
  LF32x8Scalar := ScalarSelectF32x8(LMaskF32x8, LF32x8A, LF32x8B);
  AssertVecF32x8Equal('VecF32x8Select', LF32x8Scalar, LF32x8Facade);

  for LIndex := 0 to 3 do
  begin
    LF64x4A.d[LIndex] := (LIndex + 1) * 2.0;
    LF64x4B.d[LIndex] := (LIndex - 2) * 3.5;
    if (LIndex and 1) <> 0 then
      LMaskF64x4.u[LIndex] := High(QWord)
    else
      LMaskF64x4.u[LIndex] := 0;
  end;

  LDotF64x4Facade := nextpas.core.simd.VecF64x4Dot(LF64x4A, LF64x4B);
  LDotF64x4Scalar := ScalarDotF64x4(LF64x4A, LF64x4B);
  CheckNear(LDotF64x4Scalar, LDotF64x4Facade, 1.0e-12, 'VecF64x4Dot');

  CheckNear(LF64x4A.d[2], nextpas.core.simd.VecF64x4Extract(LF64x4A, 2), 1.0e-12, 'VecF64x4Extract lane2');
  LF64x4Inserted := nextpas.core.simd.VecF64x4Insert(LF64x4A, 777.25, 1);
  CheckNear(777.25, LF64x4Inserted.d[1], 1.0e-12, 'VecF64x4Insert lane1');
  CheckNear(LF64x4A.d[2], LF64x4Inserted.d[2], 1.0e-12, 'VecF64x4Insert keep lane2');

  LF64x4Facade := nextpas.core.simd.VecF64x4Select(LMaskF64x4, LF64x4A, LF64x4B);
  LF64x4Scalar := ScalarSelectF64x4(LMaskF64x4, LF64x4A, LF64x4B);
  AssertVecF64x4Equal('VecF64x4Select', LF64x4Scalar, LF64x4Facade);

  for LIndex := 0 to 7 do
    LI32x8A.i[LIndex] := LIndex * 10 - 30;
  CheckEqual(LI32x8A.i[6], nextpas.core.simd.VecI32x8Extract(LI32x8A, 6), 'VecI32x8Extract lane6');
  LI32x8Inserted := nextpas.core.simd.VecI32x8Insert(LI32x8A, 2026, 5);
  CheckEqual(2026, LI32x8Inserted.i[5], 'VecI32x8Insert lane5');
  CheckEqual(LI32x8A.i[4], LI32x8Inserted.i[4], 'VecI32x8Insert keep lane4');

  for LIndex := 0 to 15 do
  begin
    LF32x16A.f[LIndex] := (LIndex - 8) * 1.25;
    LF32x16B.f[LIndex] := (LIndex + 1) * 0.75 + 1.0;
  end;

  CheckNear(LF32x16A.f[10], nextpas.core.simd.VecF32x16Extract(LF32x16A, 10), 1.0e-5, 'VecF32x16Extract lane10');
  LF32x16Inserted := nextpas.core.simd.VecF32x16Insert(LF32x16A, 9.75, 11);
  CheckNear(9.75, LF32x16Inserted.f[11], 1.0e-5, 'VecF32x16Insert lane11');
  CheckNear(LF32x16A.f[10], LF32x16Inserted.f[10], 1.0e-5, 'VecF32x16Insert keep lane10');

  LF32x16Facade := nextpas.core.simd.VecF32x16Abs(LF32x16A);
  LF32x16Scalar := ScalarAbsF32x16(LF32x16A);
  AssertVecF32x16Equal('VecF32x16Abs', LF32x16Scalar, LF32x16Facade);

  LF32x16Facade := nextpas.core.simd.VecF32x16Sqrt(LF32x16B);
  LF32x16Scalar := ScalarSqrtF32x16(LF32x16B);
  AssertVecF32x16Equal('VecF32x16Sqrt', LF32x16Scalar, LF32x16Facade);

  LF32x16Facade := nextpas.core.simd.VecF32x16Min(LF32x16A, LF32x16B);
  LF32x16Scalar := ScalarMinF32x16(LF32x16A, LF32x16B);
  AssertVecF32x16Equal('VecF32x16Min', LF32x16Scalar, LF32x16Facade);

  LF32x16Facade := nextpas.core.simd.VecF32x16Max(LF32x16A, LF32x16B);
  LF32x16Scalar := ScalarMaxF32x16(LF32x16A, LF32x16B);
  AssertVecF32x16Equal('VecF32x16Max', LF32x16Scalar, LF32x16Facade);

  LU64x2A.u[0] := QWord($0102030405060708);
  LU64x2A.u[1] := QWord($F0F1F2F3F4F5F6F7);
  LU64x2B.u[0] := QWord($0001000100010001);
  LU64x2B.u[1] := QWord($00FF00FF00FF00FF);

  LU64x2Facade := nextpas.core.simd.VecU64x2Sub(LU64x2A, LU64x2B);
  LU64x2Scalar := ScalarSubU64x2(LU64x2A, LU64x2B);
  AssertVecU64x2Equal('VecU64x2Sub', LU64x2Scalar, LU64x2Facade);

  LU64x2Facade := nextpas.core.simd.VecU64x2And(LU64x2A, LU64x2B);
  LU64x2Scalar := ScalarAndU64x2(LU64x2A, LU64x2B);
  AssertVecU64x2Equal('VecU64x2And', LU64x2Scalar, LU64x2Facade);

  LU64x2Facade := nextpas.core.simd.VecU64x2Or(LU64x2A, LU64x2B);
  LU64x2Scalar := ScalarOrU64x2(LU64x2A, LU64x2B);
  AssertVecU64x2Equal('VecU64x2Or', LU64x2Scalar, LU64x2Facade);

  LU64x2Facade := nextpas.core.simd.VecU64x2Xor(LU64x2A, LU64x2B);
  LU64x2Scalar := ScalarXorU64x2(LU64x2A, LU64x2B);
  AssertVecU64x2Equal('VecU64x2Xor', LU64x2Scalar, LU64x2Facade);

  LU64x2Facade := nextpas.core.simd.VecU64x2Not(LU64x2A);
  LU64x2Scalar := ScalarNotU64x2(LU64x2A);
  AssertVecU64x2Equal('VecU64x2Not', LU64x2Scalar, LU64x2Facade);

  for LIndex := 0 to 3 do
  begin
    LU32x4A.u[LIndex] := DWord($FFFFFFFF - LIndex * 1000);
    LU32x4B.u[LIndex] := DWord(LIndex * 900 + 123);
  end;

  LU32x4Facade := nextpas.core.simd.VecU32x4AndNot(LU32x4A, LU32x4B);
  LU32x4Scalar := ScalarAndNotU32x4(LU32x4A, LU32x4B);
  for LIndex := 0 to 3 do
    CheckEqual(LU32x4Scalar.u[LIndex], LU32x4Facade.u[LIndex], 'VecU32x4AndNot lane ' + IntToStr(LIndex));

  LMask4Facade := nextpas.core.simd.VecU32x4CmpLe(LU32x4A, LU32x4B);
  LMask4Scalar := ScalarCmpLeU32x4(LU32x4A, LU32x4B);
  CheckEqual(Integer(LMask4Scalar), Integer(LMask4Facade), 'VecU32x4CmpLe');

  LMask4Facade := nextpas.core.simd.VecU32x4CmpGe(LU32x4A, LU32x4B);
  LMask4Scalar := ScalarCmpGeU32x4(LU32x4A, LU32x4B);
  CheckEqual(Integer(LMask4Scalar), Integer(LMask4Facade), 'VecU32x4CmpGe');

  for LIndex := 0 to 3 do
  begin
    LU64x4A.u[LIndex] := QWord($1000000000000000) + QWord(LIndex) * QWord($0101010101010101);
    LU64x4B.u[LIndex] := QWord(LIndex + 1) * QWord($1111111111111111);
  end;

  LU64x4Facade := nextpas.core.simd.VecU64x4Sub(LU64x4A, LU64x4B);
  LU64x4Scalar := ScalarSubU64x4(LU64x4A, LU64x4B);
  AssertVecU64x4Equal('VecU64x4Sub', LU64x4Scalar, LU64x4Facade);

  LU64x4Facade := nextpas.core.simd.VecU64x4And(LU64x4A, LU64x4B);
  LU64x4Scalar := ScalarAndU64x4(LU64x4A, LU64x4B);
  AssertVecU64x4Equal('VecU64x4And', LU64x4Scalar, LU64x4Facade);

  LU64x4Facade := nextpas.core.simd.VecU64x4Or(LU64x4A, LU64x4B);
  LU64x4Scalar := ScalarOrU64x4(LU64x4A, LU64x4B);
  AssertVecU64x4Equal('VecU64x4Or', LU64x4Scalar, LU64x4Facade);

  LU64x4Facade := nextpas.core.simd.VecU64x4Xor(LU64x4A, LU64x4B);
  LU64x4Scalar := ScalarXorU64x4(LU64x4A, LU64x4B);
  AssertVecU64x4Equal('VecU64x4Xor', LU64x4Scalar, LU64x4Facade);

  LU64x4Facade := nextpas.core.simd.VecU64x4Not(LU64x4A);
  LU64x4Scalar := ScalarNotU64x4(LU64x4A);
  AssertVecU64x4Equal('VecU64x4Not', LU64x4Scalar, LU64x4Facade);

  LU64x4Facade := nextpas.core.simd.VecU64x4ShiftLeft(LU64x4A, 5);
  LU64x4Scalar := ScalarShiftLeftU64x4(LU64x4A, 5);
  AssertVecU64x4Equal('VecU64x4ShiftLeft', LU64x4Scalar, LU64x4Facade);

  LU64x4Facade := nextpas.core.simd.VecU64x4ShiftRight(LU64x4A, 7);
  LU64x4Scalar := ScalarShiftRightU64x4(LU64x4A, 7);
  AssertVecU64x4Equal('VecU64x4ShiftRight', LU64x4Scalar, LU64x4Facade);

  LU64x4Facade := nextpas.core.simd.VecU64x4Splat(QWord($ABCDEF0123456789));
  for LIndex := 0 to 3 do
    CheckEqual(QWord($ABCDEF0123456789), LU64x4Facade.u[LIndex], 'VecU64x4Splat lane ' + IntToStr(LIndex));

  LU64x4Facade := nextpas.core.simd.VecU64x4Splat(QWord(42));
  for LIndex := 0 to 3 do
    CheckEqual(QWord(42), LU64x4Facade.u[LIndex], 'VecU64x4Splat alt lane ' + IntToStr(LIndex));

  LU64x4Facade := nextpas.core.simd.VecU64x4Zero;
  for LIndex := 0 to 3 do
    CheckEqual(QWord(0), LU64x4Facade.u[LIndex], 'VecU64x4Zero lane ' + IntToStr(LIndex));

  for LIndex := 0 to 3 do
    LU64x4A.u[LIndex] := High(QWord) - QWord(LIndex);
  LU64x4Facade := nextpas.core.simd.VecU64x4Zero;
  for LIndex := 0 to 3 do
    CheckEqual(QWord(0), LU64x4Facade.u[LIndex], 'VecU64x4Zero alt lane ' + IntToStr(LIndex));

  for LIndex := 0 to 7 do
  begin
    LU16x8A.u[LIndex] := Word(LIndex * 37 + 1);
    LU16x8B.u[LIndex] := Word(LIndex * 11 + 3);
  end;
  LU16x8Facade := nextpas.core.simd.VecU16x8Mul(LU16x8A, LU16x8B);
  LU16x8Scalar := ScalarMulU16x8(LU16x8A, LU16x8B);
  AssertVecU16x8Equal('VecU16x8Mul', LU16x8Scalar, LU16x8Facade);

  for LIndex := 0 to 7 do
  begin
    LU16x8A.u[LIndex] := Word($FFF0 - LIndex);
    LU16x8B.u[LIndex] := Word(LIndex + 2);
  end;
  LU16x8Facade := nextpas.core.simd.VecU16x8Mul(LU16x8A, LU16x8B);
  LU16x8Scalar := ScalarMulU16x8(LU16x8A, LU16x8B);
  AssertVecU16x8Equal('VecU16x8Mul alt', LU16x8Scalar, LU16x8Facade);

  for LIndex := 0 to 7 do
  begin
    LF64x8A.d[LIndex] := (LIndex - 4) * 2.5;
    LF64x8B.d[LIndex] := (LIndex + 1) * 1.75 + 1.0;
    LI64x8A.i[LIndex] := Int64(LIndex * 1000 - 3000);
    LI64x8B.i[LIndex] := Int64(500 - LIndex * 77);
  end;

  LF64x8Facade := nextpas.core.simd.VecF64x8Abs(LF64x8A);
  LF64x8Scalar := ScalarAbsF64x8(LF64x8A);
  AssertVecF64x8Equal('VecF64x8Abs', LF64x8Scalar, LF64x8Facade);

  LF64x8Facade := nextpas.core.simd.VecF64x8Sqrt(LF64x8B);
  LF64x8Scalar := ScalarSqrtF64x8(LF64x8B);
  AssertVecF64x8Equal('VecF64x8Sqrt', LF64x8Scalar, LF64x8Facade);

  LF64x8Facade := nextpas.core.simd.VecF64x8Min(LF64x8A, LF64x8B);
  LF64x8Scalar := ScalarMinF64x8(LF64x8A, LF64x8B);
  AssertVecF64x8Equal('VecF64x8Min', LF64x8Scalar, LF64x8Facade);

  LF64x8Facade := nextpas.core.simd.VecF64x8Max(LF64x8A, LF64x8B);
  LF64x8Scalar := ScalarMaxF64x8(LF64x8A, LF64x8B);
  AssertVecF64x8Equal('VecF64x8Max', LF64x8Scalar, LF64x8Facade);

  LI64x8Facade := nextpas.core.simd.VecI64x8Sub(LI64x8A, LI64x8B);
  LI64x8Scalar := ScalarSubI64x8(LI64x8A, LI64x8B);
  AssertVecI64x8Equal('VecI64x8Sub', LI64x8Scalar, LI64x8Facade);

  LI64x8Facade := nextpas.core.simd.VecI64x8And(LI64x8A, LI64x8B);
  LI64x8Scalar := ScalarAndI64x8(LI64x8A, LI64x8B);
  AssertVecI64x8Equal('VecI64x8And', LI64x8Scalar, LI64x8Facade);

  LI64x8Facade := nextpas.core.simd.VecI64x8Or(LI64x8A, LI64x8B);
  LI64x8Scalar := ScalarOrI64x8(LI64x8A, LI64x8B);
  AssertVecI64x8Equal('VecI64x8Or', LI64x8Scalar, LI64x8Facade);

  LI64x8Facade := nextpas.core.simd.VecI64x8Xor(LI64x8A, LI64x8B);
  LI64x8Scalar := ScalarXorI64x8(LI64x8A, LI64x8B);
  AssertVecI64x8Equal('VecI64x8Xor', LI64x8Scalar, LI64x8Facade);

  LI64x8Facade := nextpas.core.simd.VecI64x8Not(LI64x8A);
  LI64x8Scalar := ScalarNotI64x8(LI64x8A);
  AssertVecI64x8Equal('VecI64x8Not', LI64x8Scalar, LI64x8Facade);

  LAligned := nextpas.core.simd.AllocateAligned(SizeOf(Single) * 8, 32);
  CheckTrue(LAligned <> nil, 'AllocateAligned should return non-nil');
  try
    CheckTrue(nextpas.core.simd.IsPointerAligned(LAligned, 32), 'IsPointerAligned(32) should be true for AllocateAligned');
    LMisaligned := Pointer(PByte(LAligned) + 1);
    CheckFalse(nextpas.core.simd.IsPointerAligned(LMisaligned, 32), 'IsPointerAligned should be false for +1 offset');

    LAlignedF32 := PSingle(LAligned);
    LAlignedF32[0] := 10.0;
    LAlignedF32[1] := 20.0;
    LAlignedF32[2] := 30.0;
    LAlignedF32[3] := 40.0;

    LF32x4Loaded := nextpas.core.simd.VecF32x4LoadAligned(LAlignedF32);
    CheckNear(10.0, LF32x4Loaded.f[0], 1.0e-6, 'VecF32x4LoadAligned lane0');
    CheckNear(40.0, LF32x4Loaded.f[3], 1.0e-6, 'VecF32x4LoadAligned lane3');

    LF32x4A := nextpas.core.simd.VecF32x4Splat(1.0);
    LF32x4B := nextpas.core.simd.VecF32x4Splat(9.0);
    LMask4 := TMask4($5); // lane0/2 -> a, lane1/3 -> b
    LF32x4Selected := nextpas.core.simd.VecF32x4Select(LMask4, LF32x4A, LF32x4B);
    CheckNear(1.0, LF32x4Selected.f[0], 1.0e-6, 'VecF32x4Select lane0');
    CheckNear(9.0, LF32x4Selected.f[1], 1.0e-6, 'VecF32x4Select lane1');
    CheckNear(1.0, LF32x4Selected.f[2], 1.0e-6, 'VecF32x4Select lane2');
    CheckNear(9.0, LF32x4Selected.f[3], 1.0e-6, 'VecF32x4Select lane3');

    nextpas.core.simd.VecF32x4StoreAligned(LAlignedF32, LF32x4Selected);
    CheckNear(1.0, LAlignedF32[0], 1.0e-6, 'VecF32x4StoreAligned lane0');
    CheckNear(9.0, LAlignedF32[1], 1.0e-6, 'VecF32x4StoreAligned lane1');
    CheckNear(1.0, LAlignedF32[2], 1.0e-6, 'VecF32x4StoreAligned lane2');
    CheckNear(9.0, LAlignedF32[3], 1.0e-6, 'VecF32x4StoreAligned lane3');
  finally
    nextpas.core.simd.FreeAligned(LAligned);
  end;

  LBackendInfo := nextpas.core.simd.GetCurrentBackendInfo;
  CheckEqual(Ord(nextpas.core.simd.GetCurrentBackend), Ord(LBackendInfo.Backend), 'GetCurrentBackendInfo.Backend should match GetCurrentBackend');
  LAvailableBackends := nextpas.core.simd.GetAvailableBackendList;
  CheckTrue(Length(LAvailableBackends) > 0, 'GetAvailableBackendList should return at least one backend');
end;

end.
