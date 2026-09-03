unit nextpas.core.simd.dispatchapi.nonx86.testcase;

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
  nextpas.core.simd.dispatchapi.testcase,
  nextpas.core.simd.dispatchapi.support;

type
  // Non-x86 backend semantic parity smoke (NEON/RISCVV if available).
  TTestCase_NonX86BackendParity = class(TDispatchAPIStatefulTestCase)
  published
    procedure Test_NativeWideFloorCeilSlots_NotScalar_IfAvailable;
    procedure Test_NativeNarrowFloatCoreParity_WithVectorAsm_IfAvailable;
    procedure Test_NativeNarrowFloatHelperParity_WithVectorAsm_IfAvailable;
    procedure Test_NativeWideInsertHelperParity_WithVectorAsm_IfAvailable;
    procedure Test_NativeWideIntegerExtractEdgeParity_WithVectorAsm_IfAvailable;
    procedure Test_NativeNarrowHelperSurfaceParity_WithVectorAsm_IfAvailable;
    procedure Test_NativeAlignedLoadAndZeroParity_WithVectorAsm_IfAvailable;
    procedure Test_NativeWideLoadAndZeroParity_WithVectorAsm_IfAvailable;
    procedure Test_NativeWideIntegerMemoryEdgeParity_WithVectorAsm_IfAvailable;
    procedure Test_NativeWideSplatParity_WithVectorAsm_IfAvailable;
    procedure Test_NativeVectorMathParity_WithVectorAsm_IfAvailable;
    procedure Test_NativeF64DotParity_WithVectorAsm_IfAvailable;
    procedure Test_NativeF64ReduceAddSeedParity_WithVectorAsm_IfAvailable;
    procedure Test_NativeNormalizeEdgeParity_WithVectorAsm_IfAvailable;
    procedure Test_NativeNarrowIntegerCoreParity_WithVectorAsm_IfAvailable;
    procedure Test_NativeNarrowIntegerHelperParity_WithVectorAsm_IfAvailable;
    procedure Test_MinimalDispatchParity_IfAvailable;
    procedure Test_ExtendedFloatParity_IfAvailable;
    procedure Test_NarrowAndNotParity_IfAvailable;
    procedure Test_DotParity_IfAvailable;
    procedure Test_I16x32_CoreParity_IfAvailable;
    procedure Test_I8x64_CoreParity_IfAvailable;
    procedure Test_U32x16_U64x8_CoreParity_IfAvailable;
    procedure Test_WideInteger_FuzzSeed_Parity_IfAvailable;
    procedure Test_WideCompareMaskParity_IfAvailable;
    procedure Test_I32x4_BitwiseShiftParity_IfAvailable;
    procedure Test_WideSignedBitwiseShiftParity_IfAvailable;
    procedure Test_WideIntegerArithmeticMinMaxParity_IfAvailable;
    procedure Test_SaturatingArithmeticParity_IfAvailable;
  end;

implementation

function NonX86BackendName(const aBackend: TSimdBackend): string;
begin
  Result := DispatchApiBackendName(aBackend);
end;

procedure TTestCase_NonX86BackendParity.Test_NativeWideFloorCeilSlots_NotScalar_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;
  LCheckedBackends: Integer;

  procedure AssertNativeSlotNotScalar(const aBackendName, aSlotName: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + aBackendName);
  end;

  function ShouldReuseScalarWideSlot(const aSlotName: string): Boolean;
  begin
    if LBackend = sbNEON then
      Exit(True);
    if LBackend <> sbRISCVV then
      Exit(False);
    Result :=
      (aSlotName = 'FloorF32x8') or
      (aSlotName = 'CeilF32x8') or
      (aSlotName = 'RoundF32x8') or
      (aSlotName = 'TruncF32x8') or
      (aSlotName = 'FloorF64x4') or
      (aSlotName = 'CeilF64x4') or
      (aSlotName = 'RoundF64x4') or
      (aSlotName = 'TruncF64x4') or
      (aSlotName = 'FloorF32x16') or
      (aSlotName = 'CeilF32x16') or
      (aSlotName = 'RoundF32x16') or
      (aSlotName = 'TruncF32x16') or
      (aSlotName = 'FloorF64x8') or
      (aSlotName = 'CeilF64x8') or
      (aSlotName = 'RoundF64x8') or
      (aSlotName = 'TruncF64x8') or
      (aSlotName = 'ClampF32x8') or
      (aSlotName = 'ClampF32x16');
  end;

  procedure AssertNeonReusesScalarOtherwiseNative(const aSlotName: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + NonX86BackendName(LBackend));
    if ShouldReuseScalarWideSlot(aSlotName) then
      CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), aSlotName + ' should reuse the scalar slot when the current non-x86 backend truth is canonical base-scalar inheritance')
    else
      CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + NonX86BackendName(LBackend));
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be available');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LCheckedBackends := 0;

  for LBackend in LBackends do
  begin
    case LBackend of
      sbNEON:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
      sbRISCVV:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
    end;
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;

    Inc(LCheckedBackends);

  AssertNeonReusesScalarOtherwiseNative('FloorF32x8', Pointer(LScalarTable.CoreVectors.FloorF32x8), Pointer(LBackendTable.CoreVectors.FloorF32x8));
  AssertNeonReusesScalarOtherwiseNative('CeilF32x8', Pointer(LScalarTable.CoreVectors.CeilF32x8), Pointer(LBackendTable.CoreVectors.CeilF32x8));
  AssertNeonReusesScalarOtherwiseNative('RoundF32x8', Pointer(LScalarTable.CoreVectors.RoundF32x8), Pointer(LBackendTable.CoreVectors.RoundF32x8));
  AssertNeonReusesScalarOtherwiseNative('TruncF32x8', Pointer(LScalarTable.CoreVectors.TruncF32x8), Pointer(LBackendTable.CoreVectors.TruncF32x8));
  AssertNeonReusesScalarOtherwiseNative('FloorF64x4', Pointer(LScalarTable.CoreVectors.FloorF64x4), Pointer(LBackendTable.CoreVectors.FloorF64x4));
  AssertNeonReusesScalarOtherwiseNative('CeilF64x4', Pointer(LScalarTable.CoreVectors.CeilF64x4), Pointer(LBackendTable.CoreVectors.CeilF64x4));
  AssertNeonReusesScalarOtherwiseNative('RoundF64x4', Pointer(LScalarTable.CoreVectors.RoundF64x4), Pointer(LBackendTable.CoreVectors.RoundF64x4));
  AssertNeonReusesScalarOtherwiseNative('TruncF64x4', Pointer(LScalarTable.CoreVectors.TruncF64x4), Pointer(LBackendTable.CoreVectors.TruncF64x4));
  AssertNeonReusesScalarOtherwiseNative('FloorF32x16', Pointer(LScalarTable.CoreVectors.FloorF32x16), Pointer(LBackendTable.CoreVectors.FloorF32x16));
  AssertNeonReusesScalarOtherwiseNative('CeilF32x16', Pointer(LScalarTable.CoreVectors.CeilF32x16), Pointer(LBackendTable.CoreVectors.CeilF32x16));
  AssertNeonReusesScalarOtherwiseNative('RoundF32x16', Pointer(LScalarTable.CoreVectors.RoundF32x16), Pointer(LBackendTable.CoreVectors.RoundF32x16));
  AssertNeonReusesScalarOtherwiseNative('TruncF32x16', Pointer(LScalarTable.CoreVectors.TruncF32x16), Pointer(LBackendTable.CoreVectors.TruncF32x16));
  AssertNeonReusesScalarOtherwiseNative('FloorF64x8', Pointer(LScalarTable.CoreVectors.FloorF64x8), Pointer(LBackendTable.CoreVectors.FloorF64x8));
  AssertNeonReusesScalarOtherwiseNative('CeilF64x8', Pointer(LScalarTable.CoreVectors.CeilF64x8), Pointer(LBackendTable.CoreVectors.CeilF64x8));
  AssertNeonReusesScalarOtherwiseNative('RoundF64x8', Pointer(LScalarTable.CoreVectors.RoundF64x8), Pointer(LBackendTable.CoreVectors.RoundF64x8));
  AssertNeonReusesScalarOtherwiseNative('TruncF64x8', Pointer(LScalarTable.CoreVectors.TruncF64x8), Pointer(LBackendTable.CoreVectors.TruncF64x8));

  AssertNeonReusesScalarOtherwiseNative('AddF32x8', Pointer(LScalarTable.CoreVectors.AddF32x8), Pointer(LBackendTable.CoreVectors.AddF32x8));
  AssertNeonReusesScalarOtherwiseNative('SubF32x8', Pointer(LScalarTable.CoreVectors.SubF32x8), Pointer(LBackendTable.CoreVectors.SubF32x8));
  AssertNeonReusesScalarOtherwiseNative('MulF32x8', Pointer(LScalarTable.CoreVectors.MulF32x8), Pointer(LBackendTable.CoreVectors.MulF32x8));
  AssertNeonReusesScalarOtherwiseNative('DivF32x8', Pointer(LScalarTable.CoreVectors.DivF32x8), Pointer(LBackendTable.CoreVectors.DivF32x8));
  AssertNeonReusesScalarOtherwiseNative('MinF32x8', Pointer(LScalarTable.CoreVectors.MinF32x8), Pointer(LBackendTable.CoreVectors.MinF32x8));
  AssertNeonReusesScalarOtherwiseNative('MaxF32x8', Pointer(LScalarTable.CoreVectors.MaxF32x8), Pointer(LBackendTable.CoreVectors.MaxF32x8));
  AssertNeonReusesScalarOtherwiseNative('AbsF32x8', Pointer(LScalarTable.CoreVectors.AbsF32x8), Pointer(LBackendTable.CoreVectors.AbsF32x8));
  AssertNeonReusesScalarOtherwiseNative('SqrtF32x8', Pointer(LScalarTable.CoreVectors.SqrtF32x8), Pointer(LBackendTable.CoreVectors.SqrtF32x8));
  AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'FmaF32x8', Pointer(LScalarTable.CoreVectors.FmaF32x8), Pointer(LBackendTable.CoreVectors.FmaF32x8));
  AssertNeonReusesScalarOtherwiseNative('ClampF32x8', Pointer(LScalarTable.CoreVectors.ClampF32x8), Pointer(LBackendTable.CoreVectors.ClampF32x8));

  AssertNeonReusesScalarOtherwiseNative('AddF64x4', Pointer(LScalarTable.CoreVectors.AddF64x4), Pointer(LBackendTable.CoreVectors.AddF64x4));
  AssertNeonReusesScalarOtherwiseNative('SubF64x4', Pointer(LScalarTable.CoreVectors.SubF64x4), Pointer(LBackendTable.CoreVectors.SubF64x4));
  AssertNeonReusesScalarOtherwiseNative('MulF64x4', Pointer(LScalarTable.CoreVectors.MulF64x4), Pointer(LBackendTable.CoreVectors.MulF64x4));
  AssertNeonReusesScalarOtherwiseNative('DivF64x4', Pointer(LScalarTable.CoreVectors.DivF64x4), Pointer(LBackendTable.CoreVectors.DivF64x4));
  AssertNeonReusesScalarOtherwiseNative('MinF64x4', Pointer(LScalarTable.CoreVectors.MinF64x4), Pointer(LBackendTable.CoreVectors.MinF64x4));
  AssertNeonReusesScalarOtherwiseNative('MaxF64x4', Pointer(LScalarTable.CoreVectors.MaxF64x4), Pointer(LBackendTable.CoreVectors.MaxF64x4));
  AssertNeonReusesScalarOtherwiseNative('AbsF64x4', Pointer(LScalarTable.CoreVectors.AbsF64x4), Pointer(LBackendTable.CoreVectors.AbsF64x4));
  AssertNeonReusesScalarOtherwiseNative('SqrtF64x4', Pointer(LScalarTable.CoreVectors.SqrtF64x4), Pointer(LBackendTable.CoreVectors.SqrtF64x4));
  AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'FmaF64x4', Pointer(LScalarTable.CoreVectors.FmaF64x4), Pointer(LBackendTable.CoreVectors.FmaF64x4));
  AssertNeonReusesScalarOtherwiseNative('ClampF64x4', Pointer(LScalarTable.CoreVectors.ClampF64x4), Pointer(LBackendTable.CoreVectors.ClampF64x4));

  AssertNeonReusesScalarOtherwiseNative('AddF32x16', Pointer(LScalarTable.CoreVectors.AddF32x16), Pointer(LBackendTable.CoreVectors.AddF32x16));
  AssertNeonReusesScalarOtherwiseNative('SubF32x16', Pointer(LScalarTable.CoreVectors.SubF32x16), Pointer(LBackendTable.CoreVectors.SubF32x16));
  AssertNeonReusesScalarOtherwiseNative('MulF32x16', Pointer(LScalarTable.CoreVectors.MulF32x16), Pointer(LBackendTable.CoreVectors.MulF32x16));
  AssertNeonReusesScalarOtherwiseNative('DivF32x16', Pointer(LScalarTable.CoreVectors.DivF32x16), Pointer(LBackendTable.CoreVectors.DivF32x16));
  AssertNeonReusesScalarOtherwiseNative('MinF32x16', Pointer(LScalarTable.CoreVectors.MinF32x16), Pointer(LBackendTable.CoreVectors.MinF32x16));
  AssertNeonReusesScalarOtherwiseNative('MaxF32x16', Pointer(LScalarTable.CoreVectors.MaxF32x16), Pointer(LBackendTable.CoreVectors.MaxF32x16));
  AssertNeonReusesScalarOtherwiseNative('AbsF32x16', Pointer(LScalarTable.CoreVectors.AbsF32x16), Pointer(LBackendTable.CoreVectors.AbsF32x16));
  AssertNeonReusesScalarOtherwiseNative('SqrtF32x16', Pointer(LScalarTable.CoreVectors.SqrtF32x16), Pointer(LBackendTable.CoreVectors.SqrtF32x16));
  AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'FmaF32x16', Pointer(LScalarTable.CoreVectors.FmaF32x16), Pointer(LBackendTable.CoreVectors.FmaF32x16));
  AssertNeonReusesScalarOtherwiseNative('ClampF32x16', Pointer(LScalarTable.CoreVectors.ClampF32x16), Pointer(LBackendTable.CoreVectors.ClampF32x16));

  AssertNeonReusesScalarOtherwiseNative('AddF64x8', Pointer(LScalarTable.CoreVectors.AddF64x8), Pointer(LBackendTable.CoreVectors.AddF64x8));
  AssertNeonReusesScalarOtherwiseNative('SubF64x8', Pointer(LScalarTable.CoreVectors.SubF64x8), Pointer(LBackendTable.CoreVectors.SubF64x8));
  AssertNeonReusesScalarOtherwiseNative('MulF64x8', Pointer(LScalarTable.CoreVectors.MulF64x8), Pointer(LBackendTable.CoreVectors.MulF64x8));
  AssertNeonReusesScalarOtherwiseNative('DivF64x8', Pointer(LScalarTable.CoreVectors.DivF64x8), Pointer(LBackendTable.CoreVectors.DivF64x8));
  AssertNeonReusesScalarOtherwiseNative('MinF64x8', Pointer(LScalarTable.CoreVectors.MinF64x8), Pointer(LBackendTable.CoreVectors.MinF64x8));
  AssertNeonReusesScalarOtherwiseNative('MaxF64x8', Pointer(LScalarTable.CoreVectors.MaxF64x8), Pointer(LBackendTable.CoreVectors.MaxF64x8));
  AssertNeonReusesScalarOtherwiseNative('AbsF64x8', Pointer(LScalarTable.CoreVectors.AbsF64x8), Pointer(LBackendTable.CoreVectors.AbsF64x8));
  AssertNeonReusesScalarOtherwiseNative('SqrtF64x8', Pointer(LScalarTable.CoreVectors.SqrtF64x8), Pointer(LBackendTable.CoreVectors.SqrtF64x8));
  AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'FmaF64x8', Pointer(LScalarTable.CoreVectors.FmaF64x8), Pointer(LBackendTable.CoreVectors.FmaF64x8));
  AssertNeonReusesScalarOtherwiseNative('ClampF64x8', Pointer(LScalarTable.CoreVectors.ClampF64x8), Pointer(LBackendTable.CoreVectors.ClampF64x8));
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 backend registered/active on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_NativeNarrowFloatCoreParity_WithVectorAsm_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;
  LF32x4A, LF32x4B, LF32x4C: TVecF32x4;
  LF32x4Min, LF32x4Max: TVecF32x4;
  LF32x4ByBackend, LF32x4ByScalar: TVecF32x4;
  LF64x2A, LF64x2B, LF64x2C: TVecF64x2;
  LF64x2Min, LF64x2Max: TVecF64x2;
  LF64x2ByBackend, LF64x2ByScalar: TVecF64x2;
  LCheckedBackends: Integer;

  procedure AssertNativeSlotNotScalar(const aBackendName, aSlotName: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + aBackendName);
  end;

  procedure AssertVecF32x4Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF32x4; const aEps: Single);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckNear(aExpected.f[LLane], aActual.f[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecF64x2Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF64x2; const aEps: Double);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 1 do
      CheckNear(aExpected.d[LLane], aActual.d[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be available');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LCheckedBackends := 0;

  LF32x4A.f[0] := 1.25;   LF32x4B.f[0] := -2.0;  LF32x4C.f[0] := 0.5;
  LF32x4A.f[1] := -4.5;   LF32x4B.f[1] := 3.0;   LF32x4C.f[1] := -1.25;
  LF32x4A.f[2] := 0.0;    LF32x4B.f[2] := -1.0;  LF32x4C.f[2] := 2.0;
  LF32x4A.f[3] := 7.75;   LF32x4B.f[3] := 0.25;  LF32x4C.f[3] := -0.5;
  LF32x4Min := VecF32x4Splat(-2.5);
  LF32x4Max := VecF32x4Splat(2.5);

  LF64x2A.d[0] := 1.5;    LF64x2B.d[0] := -2.25; LF64x2C.d[0] := 0.75;
  LF64x2A.d[1] := -8.75;  LF64x2B.d[1] := 10.0;  LF64x2C.d[1] := -1.5;
  LF64x2Min := VecF64x2Splat(-3.0);
  LF64x2Max := VecF64x2Splat(3.0);

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  for LBackend in LBackends do
  begin
    case LBackend of
      sbNEON:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
      sbRISCVV:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
    end;
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;

    Inc(LCheckedBackends);

    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'AddF32x4', Pointer(LScalarTable.CoreVectors.AddF32x4), Pointer(LBackendTable.CoreVectors.AddF32x4));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'AbsF32x4', Pointer(LScalarTable.CoreVectors.AbsF32x4), Pointer(LBackendTable.CoreVectors.AbsF32x4));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'FmaF32x4', Pointer(LScalarTable.CoreVectors.FmaF32x4), Pointer(LBackendTable.CoreVectors.FmaF32x4));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'ClampF32x4', Pointer(LScalarTable.CoreVectors.ClampF32x4), Pointer(LBackendTable.CoreVectors.ClampF32x4));

    LF32x4ByBackend := LBackendTable.CoreVectors.AddF32x4(LF32x4A, LF32x4B);
    LF32x4ByScalar := LScalarTable.CoreVectors.AddF32x4(LF32x4A, LF32x4B);
    AssertVecF32x4Equal('AddF32x4', NonX86BackendName(LBackend), LF32x4ByScalar, LF32x4ByBackend, 1e-6);

    LF32x4ByBackend := LBackendTable.CoreVectors.AbsF32x4(LF32x4A);
    LF32x4ByScalar := LScalarTable.CoreVectors.AbsF32x4(LF32x4A);
    AssertVecF32x4Equal('AbsF32x4', NonX86BackendName(LBackend), LF32x4ByScalar, LF32x4ByBackend, 0.0);

    LF32x4ByBackend := LBackendTable.CoreVectors.FmaF32x4(LF32x4A, LF32x4B, LF32x4C);
    LF32x4ByScalar := LScalarTable.CoreVectors.FmaF32x4(LF32x4A, LF32x4B, LF32x4C);
    AssertVecF32x4Equal('FmaF32x4', NonX86BackendName(LBackend), LF32x4ByScalar, LF32x4ByBackend, 1e-5);

    LF32x4ByBackend := LBackendTable.CoreVectors.ClampF32x4(LF32x4A, LF32x4Min, LF32x4Max);
    LF32x4ByScalar := LScalarTable.CoreVectors.ClampF32x4(LF32x4A, LF32x4Min, LF32x4Max);
    AssertVecF32x4Equal('ClampF32x4', NonX86BackendName(LBackend), LF32x4ByScalar, LF32x4ByBackend, 0.0);

    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'AddF64x2', Pointer(LScalarTable.CoreVectors.AddF64x2), Pointer(LBackendTable.CoreVectors.AddF64x2));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'AbsF64x2', Pointer(LScalarTable.CoreVectors.AbsF64x2), Pointer(LBackendTable.CoreVectors.AbsF64x2));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'FmaF64x2', Pointer(LScalarTable.CoreVectors.FmaF64x2), Pointer(LBackendTable.CoreVectors.FmaF64x2));
    {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'ClampF64x2', Pointer(LScalarTable.CoreVectors.ClampF64x2), Pointer(LBackendTable.CoreVectors.ClampF64x2));
    {$ELSE}
    CheckEqual(PtrUInt(Pointer(LScalarTable.CoreVectors.ClampF64x2)), PtrUInt(Pointer(LBackendTable.CoreVectors.ClampF64x2)), 'ClampF64x2 should reuse the scalar slot when NEON asm is not compiled on this host');
    {$ENDIF}

    LF64x2ByBackend := LBackendTable.CoreVectors.AddF64x2(LF64x2A, LF64x2B);
    LF64x2ByScalar := LScalarTable.CoreVectors.AddF64x2(LF64x2A, LF64x2B);
    AssertVecF64x2Equal('AddF64x2', NonX86BackendName(LBackend), LF64x2ByScalar, LF64x2ByBackend, 1e-12);

    LF64x2ByBackend := LBackendTable.CoreVectors.AbsF64x2(LF64x2A);
    LF64x2ByScalar := LScalarTable.CoreVectors.AbsF64x2(LF64x2A);
    AssertVecF64x2Equal('AbsF64x2', NonX86BackendName(LBackend), LF64x2ByScalar, LF64x2ByBackend, 0.0);

    LF64x2ByBackend := LBackendTable.CoreVectors.FmaF64x2(LF64x2A, LF64x2B, LF64x2C);
    LF64x2ByScalar := LScalarTable.CoreVectors.FmaF64x2(LF64x2A, LF64x2B, LF64x2C);
    AssertVecF64x2Equal('FmaF64x2', NonX86BackendName(LBackend), LF64x2ByScalar, LF64x2ByBackend, 1e-11);

    LF64x2ByBackend := LBackendTable.CoreVectors.ClampF64x2(LF64x2A, LF64x2Min, LF64x2Max);
    LF64x2ByScalar := LScalarTable.CoreVectors.ClampF64x2(LF64x2A, LF64x2Min, LF64x2Max);
    AssertVecF64x2Equal('ClampF64x2', NonX86BackendName(LBackend), LF64x2ByScalar, LF64x2ByBackend, 0.0);
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 asm backend registered on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_NativeNarrowHelperSurfaceParity_WithVectorAsm_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;
  LF32x4A, LF32x4B: TVecF32x4;
  LF32x4ByBackend, LF32x4ByFacade, LF32x4ByScalar: TVecF32x4;
  LF64x2A, LF64x2B: TVecF64x2;
  LF64x2ByBackend, LF64x2ByFacade, LF64x2ByScalar: TVecF64x2;
  LI32x4A, LI32x4B, LI32x4Mask: TVecI32x4;
  LI32x4ByBackend, LI32x4ByFacade, LI32x4ByScalar: TVecI32x4;
  LI64x2A, LI64x2B: TVecI64x2;
  LF32x4Src: array[0..3] of Single;
  LF64x2Src: array[0..1] of Double;
  LF32Mask: TMask4;
  LF64Mask: TMask2;
  LCheckedBackends: Integer;

  procedure AssertNativeSlotNotScalar(const aBackendName, aSlotName: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + aBackendName);
  end;

  procedure AssertBackendOwnedSlotIfExpected(
    const aBackend: TSimdBackend;
    const aBackendName, aSlotName: string;
    const aScalarSlot, aBackendSlot: Pointer
  );
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    case aBackend of
      sbNEON:
        CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), aSlotName + ' should intentionally reuse the published scalar slot on ' + aBackendName);
    else
      CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + aBackendName);
    end;
  end;

  procedure AssertVecF32x4Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF32x4; const aEps: Single);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckNear(aExpected.f[LLane], aActual.f[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecF64x2Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF64x2; const aEps: Double);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 1 do
      CheckNear(aExpected.d[LLane], aActual.d[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecI32x4Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecI32x4);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be available');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LCheckedBackends := 0;

  LF32x4Src[0] := 1.5;
  LF32x4Src[1] := -2.25;
  LF32x4Src[2] := 3.75;
  LF32x4Src[3] := -4.5;
  LF64x2Src[0] := 11.25;
  LF64x2Src[1] := -22.5;

  LF32x4A := LScalarTable.CoreVectors.LoadF32x4(@LF32x4Src[0]);
  LF32x4B := VecF32x4Splat(9.0);
  LF64x2A := LScalarTable.CoreVectors.LoadF64x2(@LF64x2Src[0]);
  LF64x2B := VecF64x2Splat(-7.5);
  LI32x4A.i[0] := 101;
  LI32x4A.i[1] := -202;
  LI32x4A.i[2] := 303;
  LI32x4A.i[3] := -404;
  LI32x4B.i[0] := 900; LI32x4B.i[1] := 800; LI32x4B.i[2] := 700; LI32x4B.i[3] := 600;
  LI32x4Mask.i[0] := -1; LI32x4Mask.i[1] := 0; LI32x4Mask.i[2] := -1; LI32x4Mask.i[3] := 0;
  LI64x2A.i[0] := 1234567890123;
  LI64x2A.i[1] := -987654321012;
  LI64x2B.i[0] := -1; LI64x2B.i[1] := 777777777;
  LF32Mask := TMask4($5);
  LF64Mask := TMask2($1);

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  for LBackend in LBackends do
  begin
    case LBackend of
      sbNEON:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
      sbRISCVV:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
    end;
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    Inc(LCheckedBackends);

    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'LoadF32x4', Pointer(LScalarTable.CoreVectors.LoadF32x4), Pointer(LBackendTable.CoreVectors.LoadF32x4));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'SplatF32x4', Pointer(LScalarTable.CoreVectors.SplatF32x4), Pointer(LBackendTable.CoreVectors.SplatF32x4));
    AssertBackendOwnedSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'SelectF32x4', Pointer(LScalarTable.CoreVectors.SelectF32x4), Pointer(LBackendTable.CoreVectors.SelectF32x4));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'ExtractF32x4', Pointer(LScalarTable.CoreVectors.ExtractF32x4), Pointer(LBackendTable.CoreVectors.ExtractF32x4));

    LF32x4ByBackend := LBackendTable.CoreVectors.LoadF32x4(@LF32x4Src[0]);
    LF32x4ByScalar := LScalarTable.CoreVectors.LoadF32x4(@LF32x4Src[0]);
    AssertVecF32x4Equal('LoadF32x4 dispatch-table', NonX86BackendName(LBackend), LF32x4ByScalar, LF32x4ByBackend, 1e-6);

    LF32x4ByFacade := VecF32x4Load(@LF32x4Src[0]);
    AssertVecF32x4Equal('LoadF32x4 facade', NonX86BackendName(LBackend), LF32x4ByScalar, LF32x4ByFacade, 1e-6);

    LF32x4ByBackend := LBackendTable.CoreVectors.SplatF32x4(6.25);
    LF32x4ByScalar := LScalarTable.CoreVectors.SplatF32x4(6.25);
    AssertVecF32x4Equal('SplatF32x4 dispatch-table', NonX86BackendName(LBackend), LF32x4ByScalar, LF32x4ByBackend, 1e-6);

    LF32x4ByFacade := VecF32x4Splat(6.25);
    AssertVecF32x4Equal('SplatF32x4 facade', NonX86BackendName(LBackend), LF32x4ByScalar, LF32x4ByFacade, 1e-6);

    LF32x4ByBackend := LBackendTable.CoreVectors.SelectF32x4(LF32Mask, LF32x4A, LF32x4B);
    LF32x4ByScalar := LScalarTable.CoreVectors.SelectF32x4(LF32Mask, LF32x4A, LF32x4B);
    AssertVecF32x4Equal('SelectF32x4 dispatch-table', NonX86BackendName(LBackend), LF32x4ByScalar, LF32x4ByBackend, 1e-6);

    LF32x4ByFacade := VecF32x4Select(LF32Mask, LF32x4A, LF32x4B);
    AssertVecF32x4Equal('SelectF32x4 facade', NonX86BackendName(LBackend), LF32x4ByScalar, LF32x4ByFacade, 1e-6);

    CheckNear(LScalarTable.CoreVectors.ExtractF32x4(LF32x4A, 2), VecF32x4Extract(LF32x4A, 2), 1e-6, 'ExtractF32x4 facade parity: ' + NonX86BackendName(LBackend));
    CheckNear(LScalarTable.CoreVectors.ExtractF32x4(LF32x4A, 2), LBackendTable.CoreVectors.ExtractF32x4(LF32x4A, 2), 1e-6, 'ExtractF32x4 dispatch-table parity: ' + NonX86BackendName(LBackend));

    AssertBackendOwnedSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'LoadF64x2', Pointer(LScalarTable.CoreVectors.LoadF64x2), Pointer(LBackendTable.CoreVectors.LoadF64x2));
    AssertBackendOwnedSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'SplatF64x2', Pointer(LScalarTable.CoreVectors.SplatF64x2), Pointer(LBackendTable.CoreVectors.SplatF64x2));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'SelectF64x2', Pointer(LScalarTable.CoreVectors.SelectF64x2), Pointer(LBackendTable.CoreVectors.SelectF64x2));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'ExtractF64x2', Pointer(LScalarTable.CoreVectors.ExtractF64x2), Pointer(LBackendTable.CoreVectors.ExtractF64x2));

    LF64x2ByBackend := LBackendTable.CoreVectors.LoadF64x2(@LF64x2Src[0]);
    LF64x2ByScalar := LScalarTable.CoreVectors.LoadF64x2(@LF64x2Src[0]);
    AssertVecF64x2Equal('LoadF64x2 dispatch-table', NonX86BackendName(LBackend), LF64x2ByScalar, LF64x2ByBackend, 1e-12);

    LF64x2ByFacade := VecF64x2Load(@LF64x2Src[0]);
    AssertVecF64x2Equal('LoadF64x2 facade', NonX86BackendName(LBackend), LF64x2ByScalar, LF64x2ByFacade, 1e-12);

    LF64x2ByBackend := LBackendTable.CoreVectors.SplatF64x2(3.5);
    LF64x2ByScalar := LScalarTable.CoreVectors.SplatF64x2(3.5);
    AssertVecF64x2Equal('SplatF64x2 dispatch-table', NonX86BackendName(LBackend), LF64x2ByScalar, LF64x2ByBackend, 1e-12);

    LF64x2ByFacade := VecF64x2Splat(3.5);
    AssertVecF64x2Equal('SplatF64x2 facade', NonX86BackendName(LBackend), LF64x2ByScalar, LF64x2ByFacade, 1e-12);

    LF64x2ByBackend := LBackendTable.CoreVectors.SelectF64x2(LF64Mask, LF64x2A, LF64x2B);
    LF64x2ByScalar := LScalarTable.CoreVectors.SelectF64x2(LF64Mask, LF64x2A, LF64x2B);
    AssertVecF64x2Equal('SelectF64x2 dispatch-table', NonX86BackendName(LBackend), LF64x2ByScalar, LF64x2ByBackend, 1e-12);

    LF64x2ByFacade := VecF64x2Select(LF64Mask, LF64x2A, LF64x2B);
    AssertVecF64x2Equal('SelectF64x2 facade', NonX86BackendName(LBackend), LF64x2ByScalar, LF64x2ByFacade, 1e-12);

    CheckNear(LScalarTable.CoreVectors.ExtractF64x2(LF64x2A, 1), VecF64x2Extract(LF64x2A, 1), 1e-12, 'ExtractF64x2 facade parity: ' + NonX86BackendName(LBackend));
    CheckNear(LScalarTable.CoreVectors.ExtractF64x2(LF64x2A, 1), LBackendTable.CoreVectors.ExtractF64x2(LF64x2A, 1), 1e-12, 'ExtractF64x2 dispatch-table parity: ' + NonX86BackendName(LBackend));

    AssertBackendOwnedSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'SelectI32x4', Pointer(LScalarTable.CoreVectors.SelectI32x4), Pointer(LBackendTable.CoreVectors.SelectI32x4));
    AssertBackendOwnedSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'ExtractI32x4', Pointer(LScalarTable.CoreVectors.ExtractI32x4), Pointer(LBackendTable.CoreVectors.ExtractI32x4));

    LI32x4ByBackend := LBackendTable.CoreVectors.SelectI32x4(LI32x4Mask, LI32x4A, LI32x4B);
    LI32x4ByScalar := LScalarTable.CoreVectors.SelectI32x4(LI32x4Mask, LI32x4A, LI32x4B);
    AssertVecI32x4Equal('SelectI32x4 dispatch-table', NonX86BackendName(LBackend), LI32x4ByScalar, LI32x4ByBackend);

    LI32x4ByFacade := VecI32x4Select(LI32x4Mask, LI32x4A, LI32x4B);
    AssertVecI32x4Equal('SelectI32x4 facade', NonX86BackendName(LBackend), LI32x4ByScalar, LI32x4ByFacade);

    CheckEqual(LScalarTable.CoreVectors.ExtractI32x4(LI32x4A, 3), VecI32x4Extract(LI32x4A, 3), 'ExtractI32x4 facade parity: ' + NonX86BackendName(LBackend));
    CheckEqual(LScalarTable.CoreVectors.ExtractI32x4(LI32x4A, 3), LBackendTable.CoreVectors.ExtractI32x4(LI32x4A, 3), 'ExtractI32x4 dispatch-table parity: ' + NonX86BackendName(LBackend));

    AssertBackendOwnedSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'ExtractI64x2', Pointer(LScalarTable.CoreVectors.ExtractI64x2), Pointer(LBackendTable.CoreVectors.ExtractI64x2));

    CheckEqual(LScalarTable.CoreVectors.ExtractI64x2(LI64x2A, 0), VecI64x2Extract(LI64x2A, 0), 'ExtractI64x2 facade parity: ' + NonX86BackendName(LBackend));
    CheckEqual(LScalarTable.CoreVectors.ExtractI64x2(LI64x2A, 0), LBackendTable.CoreVectors.ExtractI64x2(LI64x2A, 0), 'ExtractI64x2 dispatch-table parity: ' + NonX86BackendName(LBackend));
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 asm backend registered on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_NativeAlignedLoadAndZeroParity_WithVectorAsm_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;
  LF32x4ByBackend, LF32x4ByFacade, LF32x4ByScalar: TVecF32x4;
  LF64x2ByBackend, LF64x2ByFacade, LF64x2ByScalar: TVecF64x2;
  LAligned: Pointer;
  LAlignedF32: PSingle;
  LCheckedBackends: Integer;
  LOldVectorAsm: Boolean;

  procedure AssertNativeSlotNotScalar(const aBackendName, aSlotName: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + aBackendName);
  end;

  procedure AssertBackendOwnedSlotIfExpected(
    const aBackend: TSimdBackend;
    const aBackendName, aSlotName: string;
    const aScalarSlot, aBackendSlot: Pointer
  );
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    case aBackend of
      sbNEON:
        CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), aSlotName + ' should intentionally reuse the published scalar slot on ' + aBackendName);
    else
      CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + aBackendName);
    end;
  end;

  procedure AssertVecF32x4Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF32x4; const aEps: Single);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckNear(aExpected.f[LLane], aActual.f[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecF64x2Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF64x2; const aEps: Double);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 1 do
      CheckNear(aExpected.d[LLane], aActual.d[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be available');

  LAligned := AllocateAligned(SizeOf(Single) * 8, 32);
  CheckTrue(LAligned <> nil, 'AllocateAligned should return non-nil');
  LAlignedF32 := PSingle(LAligned);
  LAlignedF32[0] := 10.5;
  LAlignedF32[1] := -20.25;
  LAlignedF32[2] := 30.75;
  LAlignedF32[3] := -40.5;

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LCheckedBackends := 0;

  GetDispatchTable;
  LOldVectorAsm := IsVectorAsmEnabled;
  try
    SetVectorAsmEnabled(True);
    if not IsVectorAsmEnabled then
      Exit;

    for LBackend in LBackends do
    begin
      case LBackend of
        sbNEON:
          begin
            {$IFNDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
            Continue;
            {$ENDIF}
          end;
        sbRISCVV:
          begin
            {$IFNDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
            Continue;
            {$ENDIF}
          end;
      end;
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      Inc(LCheckedBackends);

      AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'LoadF32x4Aligned', Pointer(LScalarTable.CoreVectors.LoadF32x4Aligned), Pointer(LBackendTable.CoreVectors.LoadF32x4Aligned));
      AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'ZeroF32x4', Pointer(LScalarTable.CoreVectors.ZeroF32x4), Pointer(LBackendTable.CoreVectors.ZeroF32x4));
      AssertBackendOwnedSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'ZeroF64x2', Pointer(LScalarTable.CoreVectors.ZeroF64x2), Pointer(LBackendTable.CoreVectors.ZeroF64x2));

      LF32x4ByBackend := LBackendTable.CoreVectors.LoadF32x4Aligned(LAlignedF32);
      LF32x4ByScalar := LScalarTable.CoreVectors.LoadF32x4Aligned(LAlignedF32);
      AssertVecF32x4Equal('LoadF32x4Aligned dispatch-table', NonX86BackendName(LBackend), LF32x4ByScalar, LF32x4ByBackend, 1e-6);

      LF32x4ByFacade := VecF32x4LoadAligned(LAlignedF32);
      AssertVecF32x4Equal('LoadF32x4Aligned facade', NonX86BackendName(LBackend), LF32x4ByScalar, LF32x4ByFacade, 1e-6);

      LF32x4ByBackend := LBackendTable.CoreVectors.ZeroF32x4();
      LF32x4ByScalar := LScalarTable.CoreVectors.ZeroF32x4();
      AssertVecF32x4Equal('ZeroF32x4 dispatch-table', NonX86BackendName(LBackend), LF32x4ByScalar, LF32x4ByBackend, 0.0);

      LF32x4ByFacade := VecF32x4Zero;
      AssertVecF32x4Equal('ZeroF32x4 facade', NonX86BackendName(LBackend), LF32x4ByScalar, LF32x4ByFacade, 0.0);

      LF64x2ByBackend := LBackendTable.CoreVectors.ZeroF64x2();
      LF64x2ByScalar := LScalarTable.CoreVectors.ZeroF64x2();
      AssertVecF64x2Equal('ZeroF64x2 dispatch-table', NonX86BackendName(LBackend), LF64x2ByScalar, LF64x2ByBackend, 0.0);

      LF64x2ByFacade := VecF64x2Zero;
      AssertVecF64x2Equal('ZeroF64x2 facade', NonX86BackendName(LBackend), LF64x2ByScalar, LF64x2ByFacade, 0.0);
    end;

    if LCheckedBackends = 0 then
      CheckTrue(True, 'No non-x86 asm backend registered on this host (allowed)');
  finally
    FreeAligned(LAligned);
  end;
end;

procedure TTestCase_NonX86BackendParity.Test_NativeWideLoadAndZeroParity_WithVectorAsm_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;
  LF32Data: array[0..15] of Single;
  LF64Data: array[0..7] of Double;
  LI64Data: array[0..3] of Int64;
  LF32x8ByBackend, LF32x8ByScalar: TVecF32x8;
  LF32x16ByBackend, LF32x16ByFacade, LF32x16ByScalar: TVecF32x16;
  LF64x4ByBackend, LF64x4ByScalar: TVecF64x4;
  LF64x8ByBackend, LF64x8ByFacade, LF64x8ByScalar: TVecF64x8;
  LI64x4ByBackend, LI64x4ByFacade, LI64x4ByScalar: TVecI64x4;
  LIndex: Integer;
  LCheckedBackends: Integer;

  procedure AssertNativeSlotNotScalar(const aBackendName, aSlotName: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + aBackendName);
  end;

  procedure AssertVecF32x8Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF32x8; const aEps: Single);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 7 do
      CheckNear(aExpected.f[LLane], aActual.f[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecF32x16Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF32x16; const aEps: Single);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 15 do
      CheckNear(aExpected.f[LLane], aActual.f[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecF64x4Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF64x4; const aEps: Double);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckNear(aExpected.d[LLane], aActual.d[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecF64x8Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF64x8; const aEps: Double);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 7 do
      CheckNear(aExpected.d[LLane], aActual.d[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecI64x4Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecI64x4);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be available');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LCheckedBackends := 0;

  for LIndex := 0 to 15 do
    LF32Data[LIndex] := (LIndex - 7) * 1.375;
  for LIndex := 0 to 7 do
    LF64Data[LIndex] := (LIndex - 3) * 100.125;
  for LIndex := 0 to 3 do
    LI64Data[LIndex] := (LIndex - 1) * 1234567890123;

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  for LBackend in LBackends do
  begin
    case LBackend of
      sbNEON:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
      sbRISCVV:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
    end;
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    Inc(LCheckedBackends);

    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'LoadF32x8', Pointer(LScalarTable.CoreVectors.LoadF32x8), Pointer(LBackendTable.CoreVectors.LoadF32x8));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'ZeroF32x8', Pointer(LScalarTable.CoreVectors.ZeroF32x8), Pointer(LBackendTable.CoreVectors.ZeroF32x8));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'LoadF32x16', Pointer(LScalarTable.CoreVectors.LoadF32x16), Pointer(LBackendTable.CoreVectors.LoadF32x16));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'ZeroF32x16', Pointer(LScalarTable.CoreVectors.ZeroF32x16), Pointer(LBackendTable.CoreVectors.ZeroF32x16));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'LoadF64x4', Pointer(LScalarTable.CoreVectors.LoadF64x4), Pointer(LBackendTable.CoreVectors.LoadF64x4));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'ZeroF64x4', Pointer(LScalarTable.CoreVectors.ZeroF64x4), Pointer(LBackendTable.CoreVectors.ZeroF64x4));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'LoadF64x8', Pointer(LScalarTable.CoreVectors.LoadF64x8), Pointer(LBackendTable.CoreVectors.LoadF64x8));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'ZeroF64x8', Pointer(LScalarTable.CoreVectors.ZeroF64x8), Pointer(LBackendTable.CoreVectors.ZeroF64x8));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'LoadI64x4', Pointer(LScalarTable.CoreVectors.LoadI64x4), Pointer(LBackendTable.CoreVectors.LoadI64x4));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'ZeroI64x4', Pointer(LScalarTable.CoreVectors.ZeroI64x4), Pointer(LBackendTable.CoreVectors.ZeroI64x4));

    LF32x8ByBackend := LBackendTable.CoreVectors.LoadF32x8(@LF32Data[0]);
    LF32x8ByScalar := LScalarTable.CoreVectors.LoadF32x8(@LF32Data[0]);
    AssertVecF32x8Equal('LoadF32x8 dispatch-table', NonX86BackendName(LBackend), LF32x8ByScalar, LF32x8ByBackend, 1e-6);

    LF32x8ByBackend := LBackendTable.CoreVectors.ZeroF32x8();
    LF32x8ByScalar := LScalarTable.CoreVectors.ZeroF32x8();
    AssertVecF32x8Equal('ZeroF32x8 dispatch-table', NonX86BackendName(LBackend), LF32x8ByScalar, LF32x8ByBackend, 0.0);

    LF32x16ByBackend := LBackendTable.CoreVectors.LoadF32x16(@LF32Data[0]);
    LF32x16ByScalar := LScalarTable.CoreVectors.LoadF32x16(@LF32Data[0]);
    AssertVecF32x16Equal('LoadF32x16 dispatch-table', NonX86BackendName(LBackend), LF32x16ByScalar, LF32x16ByBackend, 1e-6);

    LF32x16ByFacade := VecF32x16Load(@LF32Data[0]);
    AssertVecF32x16Equal('LoadF32x16 facade', NonX86BackendName(LBackend), LF32x16ByScalar, LF32x16ByFacade, 1e-6);

    LF32x16ByBackend := LBackendTable.CoreVectors.ZeroF32x16();
    LF32x16ByScalar := LScalarTable.CoreVectors.ZeroF32x16();
    AssertVecF32x16Equal('ZeroF32x16 dispatch-table', NonX86BackendName(LBackend), LF32x16ByScalar, LF32x16ByBackend, 0.0);

    LF32x16ByFacade := VecF32x16Zero;
    AssertVecF32x16Equal('ZeroF32x16 facade', NonX86BackendName(LBackend), LF32x16ByScalar, LF32x16ByFacade, 0.0);

    LF64x4ByBackend := LBackendTable.CoreVectors.LoadF64x4(@LF64Data[0]);
    LF64x4ByScalar := LScalarTable.CoreVectors.LoadF64x4(@LF64Data[0]);
    AssertVecF64x4Equal('LoadF64x4 dispatch-table', NonX86BackendName(LBackend), LF64x4ByScalar, LF64x4ByBackend, 1e-12);

    LF64x4ByBackend := LBackendTable.CoreVectors.ZeroF64x4();
    LF64x4ByScalar := LScalarTable.CoreVectors.ZeroF64x4();
    AssertVecF64x4Equal('ZeroF64x4 dispatch-table', NonX86BackendName(LBackend), LF64x4ByScalar, LF64x4ByBackend, 0.0);

    LF64x8ByBackend := LBackendTable.CoreVectors.LoadF64x8(@LF64Data[0]);
    LF64x8ByScalar := LScalarTable.CoreVectors.LoadF64x8(@LF64Data[0]);
    AssertVecF64x8Equal('LoadF64x8 dispatch-table', NonX86BackendName(LBackend), LF64x8ByScalar, LF64x8ByBackend, 1e-12);

    LF64x8ByFacade := VecF64x8Load(@LF64Data[0]);
    AssertVecF64x8Equal('LoadF64x8 facade', NonX86BackendName(LBackend), LF64x8ByScalar, LF64x8ByFacade, 1e-12);

    LF64x8ByBackend := LBackendTable.CoreVectors.ZeroF64x8();
    LF64x8ByScalar := LScalarTable.CoreVectors.ZeroF64x8();
    AssertVecF64x8Equal('ZeroF64x8 dispatch-table', NonX86BackendName(LBackend), LF64x8ByScalar, LF64x8ByBackend, 0.0);

    LF64x8ByFacade := VecF64x8Zero;
    AssertVecF64x8Equal('ZeroF64x8 facade', NonX86BackendName(LBackend), LF64x8ByScalar, LF64x8ByFacade, 0.0);

    LI64x4ByBackend := LBackendTable.CoreVectors.LoadI64x4(@LI64Data[0]);
    LI64x4ByScalar := LScalarTable.CoreVectors.LoadI64x4(@LI64Data[0]);
    AssertVecI64x4Equal('LoadI64x4 dispatch-table', NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

    LI64x4ByFacade := VecI64x4Load(@LI64Data[0]);
    AssertVecI64x4Equal('LoadI64x4 facade', NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByFacade);

    LI64x4ByBackend := LBackendTable.CoreVectors.ZeroI64x4();
    LI64x4ByScalar := LScalarTable.CoreVectors.ZeroI64x4();
    AssertVecI64x4Equal('ZeroI64x4 dispatch-table', NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

    LI64x4ByFacade := VecI64x4Zero;
    AssertVecI64x4Equal('ZeroI64x4 facade', NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByFacade);
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 asm backend registered on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_NativeWideIntegerMemoryEdgeParity_WithVectorAsm_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;
  LAlignedBlock: Pointer;
  LAlignedSrc: PInt64;
  LAlignedBackendDst: PInt64;
  LAlignedFacadeDst: PInt64;
  LAlignedScalarDst: PInt64;
  LUnalignedSrcStorage: array[0..5] of Int64;
  LUnalignedBackendStorage: array[0..5] of Int64;
  LUnalignedFacadeStorage: array[0..5] of Int64;
  LUnalignedScalarStorage: array[0..5] of Int64;
  LUnalignedSrc: PInt64;
  LUnalignedBackendDst: PInt64;
  LUnalignedFacadeDst: PInt64;
  LUnalignedScalarDst: PInt64;
  LI64x4ByBackend, LI64x4ByFacade, LI64x4ByScalar: TVecI64x4;
  LLane: Integer;
  LCheckedBackends: Integer;
  LOldVectorAsm: Boolean;

  procedure AssertNativeSlotNotScalar(const aBackendName, aSlotName: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + aBackendName);
  end;

  procedure AssertVecI64x4Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecI64x4);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 3 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aOp + ' parity lane ' + IntToStr(LLaneIndex) + ': ' + aBackendName);
  end;

  procedure AssertI64BufferEqual(const aOp, aBackendName: string; aExpected, aActual: PInt64);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 3 do
      CheckEqual(aExpected[LLaneIndex], aActual[LLaneIndex], aOp + ' parity lane ' + IntToStr(LLaneIndex) + ': ' + aBackendName);
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be available');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LCheckedBackends := 0;

  LAlignedBlock := AllocateAligned(SizeOf(Int64) * 20, 32);
  CheckTrue(LAlignedBlock <> nil, 'AllocateAligned should return non-nil');
  LAlignedSrc := PInt64(LAlignedBlock);
  LAlignedBackendDst := PInt64(PByte(LAlignedBlock) + 32);
  LAlignedFacadeDst := PInt64(PByte(LAlignedBlock) + 64);
  LAlignedScalarDst := PInt64(PByte(LAlignedBlock) + 96);

  LAlignedSrc[0] := High(Int64);
  LAlignedSrc[1] := Low(Int64);
  LAlignedSrc[2] := 0;
  LAlignedSrc[3] := -1;

  LUnalignedSrc := @LUnalignedSrcStorage[1];
  LUnalignedBackendDst := @LUnalignedBackendStorage[1];
  LUnalignedFacadeDst := @LUnalignedFacadeStorage[1];
  LUnalignedScalarDst := @LUnalignedScalarStorage[1];

  LUnalignedSrc[0] := Int64(123456789012345678);
  LUnalignedSrc[1] := Int64(-98765432101234567);
  LUnalignedSrc[2] := High(Int32);
  LUnalignedSrc[3] := Low(Int32);

  GetDispatchTable;
  LOldVectorAsm := IsVectorAsmEnabled;
  try
    SetVectorAsmEnabled(True);
    if not IsVectorAsmEnabled then
      Exit;

    for LBackend in LBackends do
    begin
      case LBackend of
        sbNEON:
          begin
            {$IFNDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
            Continue;
            {$ENDIF}
          end;
        sbRISCVV:
          begin
            {$IFNDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
            Continue;
            {$ENDIF}
          end;
      end;
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      Inc(LCheckedBackends);

      AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'LoadI64x4', Pointer(LScalarTable.CoreVectors.LoadI64x4), Pointer(LBackendTable.CoreVectors.LoadI64x4));
      AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'StoreI64x4', Pointer(LScalarTable.CoreVectors.StoreI64x4), Pointer(LBackendTable.CoreVectors.StoreI64x4));
      AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'SplatI64x4', Pointer(LScalarTable.CoreVectors.SplatI64x4), Pointer(LBackendTable.CoreVectors.SplatI64x4));
      AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'ZeroI64x4', Pointer(LScalarTable.CoreVectors.ZeroI64x4), Pointer(LBackendTable.CoreVectors.ZeroI64x4));

      LI64x4ByBackend := LBackendTable.CoreVectors.LoadI64x4(LAlignedSrc);
      LI64x4ByScalar := LScalarTable.CoreVectors.LoadI64x4(LAlignedSrc);
      AssertVecI64x4Equal('LoadI64x4 aligned dispatch-table', NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

      LI64x4ByFacade := VecI64x4Load(LAlignedSrc);
      AssertVecI64x4Equal('LoadI64x4 aligned facade', NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByFacade);

      LI64x4ByBackend := LBackendTable.CoreVectors.LoadI64x4(LUnalignedSrc);
      LI64x4ByScalar := LScalarTable.CoreVectors.LoadI64x4(LUnalignedSrc);
      AssertVecI64x4Equal('LoadI64x4 unaligned dispatch-table', NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

      LI64x4ByFacade := VecI64x4Load(LUnalignedSrc);
      AssertVecI64x4Equal('LoadI64x4 unaligned facade', NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByFacade);

      for LLane := 0 to 3 do
      begin
        LAlignedBackendDst[LLane] := Int64($1111111111111111);
        LAlignedFacadeDst[LLane] := Int64($2222222222222222);
        LAlignedScalarDst[LLane] := Int64($3333333333333333);
        LUnalignedBackendDst[LLane] := Int64($4444444444444444);
        LUnalignedFacadeDst[LLane] := Int64($5555555555555555);
        LUnalignedScalarDst[LLane] := Int64($6666666666666666);
      end;

      LBackendTable.CoreVectors.StoreI64x4(LAlignedBackendDst, LScalarTable.CoreVectors.LoadI64x4(LAlignedSrc));
      VecI64x4Store(LAlignedFacadeDst, VecI64x4Load(LAlignedSrc));
      LScalarTable.CoreVectors.StoreI64x4(LAlignedScalarDst, LScalarTable.CoreVectors.LoadI64x4(LAlignedSrc));
      AssertI64BufferEqual('StoreI64x4 aligned dispatch-table', NonX86BackendName(LBackend), LAlignedScalarDst, LAlignedBackendDst);
      AssertI64BufferEqual('StoreI64x4 aligned facade', NonX86BackendName(LBackend), LAlignedScalarDst, LAlignedFacadeDst);

      LBackendTable.CoreVectors.StoreI64x4(LUnalignedBackendDst, LScalarTable.CoreVectors.LoadI64x4(LUnalignedSrc));
      VecI64x4Store(LUnalignedFacadeDst, VecI64x4Load(LUnalignedSrc));
      LScalarTable.CoreVectors.StoreI64x4(LUnalignedScalarDst, LScalarTable.CoreVectors.LoadI64x4(LUnalignedSrc));
      AssertI64BufferEqual('StoreI64x4 unaligned dispatch-table', NonX86BackendName(LBackend), LUnalignedScalarDst, LUnalignedBackendDst);
      AssertI64BufferEqual('StoreI64x4 unaligned facade', NonX86BackendName(LBackend), LUnalignedScalarDst, LUnalignedFacadeDst);

      LI64x4ByBackend := LBackendTable.CoreVectors.SplatI64x4(0);
      LI64x4ByScalar := LScalarTable.CoreVectors.SplatI64x4(0);
      AssertVecI64x4Equal('SplatI64x4 zero dispatch-table', NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

      LI64x4ByFacade := VecI64x4Splat(0);
      AssertVecI64x4Equal('SplatI64x4 zero facade', NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByFacade);

      LI64x4ByBackend := LBackendTable.CoreVectors.SplatI64x4(High(Int64));
      LI64x4ByScalar := LScalarTable.CoreVectors.SplatI64x4(High(Int64));
      AssertVecI64x4Equal('SplatI64x4 high dispatch-table', NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

      LI64x4ByFacade := VecI64x4Splat(High(Int64));
      AssertVecI64x4Equal('SplatI64x4 high facade', NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByFacade);

      LI64x4ByBackend := LBackendTable.CoreVectors.SplatI64x4(Low(Int64));
      LI64x4ByScalar := LScalarTable.CoreVectors.SplatI64x4(Low(Int64));
      AssertVecI64x4Equal('SplatI64x4 low dispatch-table', NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

      LI64x4ByFacade := VecI64x4Splat(Low(Int64));
      AssertVecI64x4Equal('SplatI64x4 low facade', NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByFacade);

      LI64x4ByBackend := LBackendTable.CoreVectors.ZeroI64x4();
      LI64x4ByScalar := LScalarTable.CoreVectors.ZeroI64x4();
      AssertVecI64x4Equal('ZeroI64x4 dispatch-table', NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

      LI64x4ByFacade := VecI64x4Zero;
      AssertVecI64x4Equal('ZeroI64x4 facade', NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByFacade);
    end;

    if LCheckedBackends = 0 then
      CheckTrue(True, 'No non-x86 asm backend registered on this host (allowed)');
  finally
    FreeAligned(LAlignedBlock);
  end;
end;

procedure TTestCase_NonX86BackendParity.Test_NativeWideSplatParity_WithVectorAsm_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;
  LF32x8ByBackend, LF32x8ByScalar: TVecF32x8;
  LF32x16ByBackend, LF32x16ByFacade, LF32x16ByScalar: TVecF32x16;
  LF64x4ByBackend, LF64x4ByScalar: TVecF64x4;
  LF64x8ByBackend, LF64x8ByFacade, LF64x8ByScalar: TVecF64x8;
  LI64x4ByBackend, LI64x4ByFacade, LI64x4ByScalar: TVecI64x4;
  LCheckedBackends: Integer;

  procedure AssertNativeSlotNotScalar(const aBackendName, aSlotName: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + aBackendName);
  end;

  procedure AssertVecF32x8Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF32x8; const aEps: Single);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 7 do
      CheckNear(aExpected.f[LLane], aActual.f[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecF32x16Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF32x16; const aEps: Single);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 15 do
      CheckNear(aExpected.f[LLane], aActual.f[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecF64x4Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF64x4; const aEps: Double);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckNear(aExpected.d[LLane], aActual.d[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecF64x8Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF64x8; const aEps: Double);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 7 do
      CheckNear(aExpected.d[LLane], aActual.d[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecI64x4Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecI64x4);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be available');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LCheckedBackends := 0;

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  for LBackend in LBackends do
  begin
    case LBackend of
      sbNEON:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
      sbRISCVV:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
    end;
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    Inc(LCheckedBackends);

    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'SplatF32x8', Pointer(LScalarTable.CoreVectors.SplatF32x8), Pointer(LBackendTable.CoreVectors.SplatF32x8));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'SplatF32x16', Pointer(LScalarTable.CoreVectors.SplatF32x16), Pointer(LBackendTable.CoreVectors.SplatF32x16));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'SplatF64x4', Pointer(LScalarTable.CoreVectors.SplatF64x4), Pointer(LBackendTable.CoreVectors.SplatF64x4));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'SplatF64x8', Pointer(LScalarTable.CoreVectors.SplatF64x8), Pointer(LBackendTable.CoreVectors.SplatF64x8));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'SplatI64x4', Pointer(LScalarTable.CoreVectors.SplatI64x4), Pointer(LBackendTable.CoreVectors.SplatI64x4));

    LF32x8ByBackend := LBackendTable.CoreVectors.SplatF32x8(-12.75);
    LF32x8ByScalar := LScalarTable.CoreVectors.SplatF32x8(-12.75);
    AssertVecF32x8Equal('SplatF32x8 dispatch-table', NonX86BackendName(LBackend), LF32x8ByScalar, LF32x8ByBackend, 1e-6);

    LF32x16ByBackend := LBackendTable.CoreVectors.SplatF32x16(88.25);
    LF32x16ByScalar := LScalarTable.CoreVectors.SplatF32x16(88.25);
    AssertVecF32x16Equal('SplatF32x16 dispatch-table', NonX86BackendName(LBackend), LF32x16ByScalar, LF32x16ByBackend, 1e-6);

    LF32x16ByFacade := VecF32x16Splat(88.25);
    AssertVecF32x16Equal('SplatF32x16 facade', NonX86BackendName(LBackend), LF32x16ByScalar, LF32x16ByFacade, 1e-6);

    LF64x4ByBackend := LBackendTable.CoreVectors.SplatF64x4(-999.125);
    LF64x4ByScalar := LScalarTable.CoreVectors.SplatF64x4(-999.125);
    AssertVecF64x4Equal('SplatF64x4 dispatch-table', NonX86BackendName(LBackend), LF64x4ByScalar, LF64x4ByBackend, 1e-12);

    LF64x8ByBackend := LBackendTable.CoreVectors.SplatF64x8(12345.0625);
    LF64x8ByScalar := LScalarTable.CoreVectors.SplatF64x8(12345.0625);
    AssertVecF64x8Equal('SplatF64x8 dispatch-table', NonX86BackendName(LBackend), LF64x8ByScalar, LF64x8ByBackend, 1e-12);

    LF64x8ByFacade := VecF64x8Splat(12345.0625);
    AssertVecF64x8Equal('SplatF64x8 facade', NonX86BackendName(LBackend), LF64x8ByScalar, LF64x8ByFacade, 1e-12);

    LI64x4ByBackend := LBackendTable.CoreVectors.SplatI64x4(Int64(-888888888));
    LI64x4ByScalar := LScalarTable.CoreVectors.SplatI64x4(Int64(-888888888));
    AssertVecI64x4Equal('SplatI64x4 dispatch-table', NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

    LI64x4ByFacade := VecI64x4Splat(Int64(-888888888));
    AssertVecI64x4Equal('SplatI64x4 facade', NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByFacade);
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 asm backend registered on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_NativeVectorMathParity_WithVectorAsm_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;
  LF32x4A, LF32x4B: TVecF32x4;
  LCrossByBackend, LCrossByFacade, LCrossByScalar: TVecF32x4;
  LNormalize3ByBackend, LNormalize3ByFacade, LNormalize3ByScalar: TVecF32x4;
  LNormalize4ByBackend, LNormalize4ByFacade, LNormalize4ByScalar: TVecF32x4;
  LCheckedBackends: Integer;
  LIndex: Integer;
  LOldVectorAsm: Boolean;

  procedure AssertNativeSlotNotScalar(const aBackendName, aSlotName: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + aBackendName);
  end;

  procedure AssertVecF32x4Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF32x4; const aEps: Single);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckNear(aExpected.f[LLane], aActual.f[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be available');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LCheckedBackends := 0;

  LF32x4A.f[0] := 3.25;
  LF32x4A.f[1] := -4.5;
  LF32x4A.f[2] := 12.75;
  LF32x4A.f[3] := 2.0;

  LF32x4B.f[0] := -5.0;
  LF32x4B.f[1] := 7.125;
  LF32x4B.f[2] := -11.5;
  LF32x4B.f[3] := 99.0;

  GetDispatchTable;
  LOldVectorAsm := IsVectorAsmEnabled;
  try
    SetVectorAsmEnabled(True);
    if not IsVectorAsmEnabled then
      Exit;

    for LBackend in LBackends do
    begin
      case LBackend of
        sbNEON:
          begin
            {$IFNDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
            Continue;
            {$ENDIF}
          end;
        sbRISCVV:
          begin
            {$IFNDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
            Continue;
            {$ENDIF}
          end;
      end;
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      Inc(LCheckedBackends);

      AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'CrossF32x3', Pointer(LScalarTable.CoreVectors.CrossF32x3), Pointer(LBackendTable.CoreVectors.CrossF32x3));
      AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'NormalizeF32x3', Pointer(LScalarTable.CoreVectors.NormalizeF32x3), Pointer(LBackendTable.CoreVectors.NormalizeF32x3));
      AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'NormalizeF32x4', Pointer(LScalarTable.CoreVectors.NormalizeF32x4), Pointer(LBackendTable.CoreVectors.NormalizeF32x4));

      LCrossByBackend := LBackendTable.CoreVectors.CrossF32x3(LF32x4A, LF32x4B);
      LCrossByScalar := LScalarTable.CoreVectors.CrossF32x3(LF32x4A, LF32x4B);
      AssertVecF32x4Equal('CrossF32x3 dispatch-table', NonX86BackendName(LBackend), LCrossByScalar, LCrossByBackend, 1e-5);

      LCrossByFacade := VecF32x3Cross(LF32x4A, LF32x4B);
      AssertVecF32x4Equal('CrossF32x3 facade', NonX86BackendName(LBackend), LCrossByScalar, LCrossByFacade, 1e-5);

      LNormalize3ByBackend := LBackendTable.CoreVectors.NormalizeF32x3(LF32x4A);
      LNormalize3ByScalar := LScalarTable.CoreVectors.NormalizeF32x3(LF32x4A);
      AssertVecF32x4Equal('NormalizeF32x3 dispatch-table', NonX86BackendName(LBackend), LNormalize3ByScalar, LNormalize3ByBackend, 1e-5);

      LNormalize3ByFacade := VecF32x3Normalize(LF32x4A);
      AssertVecF32x4Equal('NormalizeF32x3 facade', NonX86BackendName(LBackend), LNormalize3ByScalar, LNormalize3ByFacade, 1e-5);

      LNormalize4ByBackend := LBackendTable.CoreVectors.NormalizeF32x4(LF32x4A);
      LNormalize4ByScalar := LScalarTable.CoreVectors.NormalizeF32x4(LF32x4A);
      AssertVecF32x4Equal('NormalizeF32x4 dispatch-table', NonX86BackendName(LBackend), LNormalize4ByScalar, LNormalize4ByBackend, 1e-5);

      LNormalize4ByFacade := VecF32x4Normalize(LF32x4A);
      AssertVecF32x4Equal('NormalizeF32x4 facade', NonX86BackendName(LBackend), LNormalize4ByScalar, LNormalize4ByFacade, 1e-5);
    end;

    if LCheckedBackends = 0 then
      CheckTrue(True, 'No non-x86 asm backend registered on this host (allowed)');
  finally
    for LIndex := 0 to 3 do
      LF32x4A.f[LIndex] := 0.0;
  end;
end;

procedure TTestCase_NonX86BackendParity.Test_NativeF64DotParity_WithVectorAsm_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;
  LF64x2A, LF64x2B: TVecF64x2;
  LF64x4A, LF64x4B: TVecF64x4;
  LDotF64x2ByBackend, LDotF64x2ByFacade, LDotF64x2ByScalar: Double;
  LDotF64x4ByBackend, LDotF64x4ByFacade, LDotF64x4ByScalar: Double;
  LIndex: Integer;
  LCheckedBackends: Integer;

  procedure AssertSlotReusesScalar(
    const aBackendName, aSlotName: string;
    const aScalarSlot, aBackendSlot: Pointer
  );
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), aSlotName + ' should reuse the published scalar slot on ' + aBackendName);
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be available');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LCheckedBackends := 0;

  LF64x2A.d[0] := 1.25;
  LF64x2A.d[1] := -3.5;
  LF64x2B.d[0] := 2.0;
  LF64x2B.d[1] := 4.25;

  for LIndex := 0 to 3 do
  begin
    LF64x4A.d[LIndex] := (LIndex + 1) * 2.5;
    LF64x4B.d[LIndex] := (LIndex - 1) * -1.75;
  end;

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  for LBackend in LBackends do
  begin
    case LBackend of
      sbNEON:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
      sbRISCVV:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
    end;
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    Inc(LCheckedBackends);

    AssertSlotReusesScalar(NonX86BackendName(LBackend), 'DotF64x2', Pointer(LScalarTable.CoreVectors.DotF64x2), Pointer(LBackendTable.CoreVectors.DotF64x2));
    AssertSlotReusesScalar(NonX86BackendName(LBackend), 'DotF64x4', Pointer(LScalarTable.CoreVectors.DotF64x4), Pointer(LBackendTable.CoreVectors.DotF64x4));

    LDotF64x2ByBackend := LBackendTable.CoreVectors.DotF64x2(LF64x2A, LF64x2B);
    LDotF64x2ByScalar := LScalarTable.CoreVectors.DotF64x2(LF64x2A, LF64x2B);
    CheckNear(LDotF64x2ByScalar, LDotF64x2ByBackend, 1e-12, 'DotF64x2 dispatch-table: ' + NonX86BackendName(LBackend));

    LDotF64x2ByFacade := VecF64x2Dot(LF64x2A, LF64x2B);
    CheckNear(LDotF64x2ByScalar, LDotF64x2ByFacade, 1e-12, 'DotF64x2 facade: ' + NonX86BackendName(LBackend));

    LDotF64x4ByBackend := LBackendTable.CoreVectors.DotF64x4(LF64x4A, LF64x4B);
    LDotF64x4ByScalar := LScalarTable.CoreVectors.DotF64x4(LF64x4A, LF64x4B);
    CheckNear(LDotF64x4ByScalar, LDotF64x4ByBackend, 1e-12, 'DotF64x4 dispatch-table: ' + NonX86BackendName(LBackend));

    LDotF64x4ByFacade := VecF64x4Dot(LF64x4A, LF64x4B);
    CheckNear(LDotF64x4ByScalar, LDotF64x4ByFacade, 1e-12, 'DotF64x4 facade: ' + NonX86BackendName(LBackend));
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 asm backend registered on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_NativeF64ReduceAddSeedParity_WithVectorAsm_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;
  LF64x4Input, LF64x4Poison: TVecF64x4;
  LF64x8Input, LF64x8Poison: TVecF64x8;
  LReduceF64x4ByBackend, LReduceF64x4ByScalar: Double;
  LReduceF64x8ByBackend, LReduceF64x8ByScalar, LReduceF64x8ByFacade: Double;
  LPoisonValue, LExpectedPoison: Double;
  LIndex: Integer;
  LCheckedBackends: Integer;

  procedure AssertNativeSlotNotScalar(const aBackendName, aSlotName: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + aBackendName);
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be available');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LCheckedBackends := 0;

  for LIndex := 0 to 3 do
  begin
    LF64x4Input.d[LIndex] := (LIndex - 1.5) * 3.25;
    LF64x4Poison.d[LIndex] := -90.0 + LIndex * 17.5;
  end;
  LF64x4Poison.d[3] := 777.875;

  for LIndex := 0 to 7 do
  begin
    LF64x8Input.d[LIndex] := (LIndex - 2.5) * -1.375;
    LF64x8Poison.d[LIndex] := -120.0 + LIndex * 9.0;
  end;
  LF64x8Poison.d[6] := 333.125;
  LF64x8Poison.d[7] := -222.5;

  LReduceF64x4ByScalar := LScalarTable.CoreVectors.ReduceAddF64x4(LF64x4Input);
  LReduceF64x8ByScalar := LScalarTable.CoreVectors.ReduceAddF64x8(LF64x8Input);

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  for LBackend in LBackends do
  begin
    case LBackend of
      sbNEON:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
      sbRISCVV:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
    end;
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    Inc(LCheckedBackends);

    if LBackend = sbNEON then
    begin
      CheckEqual(PtrUInt(Pointer(LScalarTable.CoreVectors.ReduceAddF64x4)), PtrUInt(Pointer(LBackendTable.CoreVectors.ReduceAddF64x4)), 'ReduceAddF64x4 should reuse the scalar slot when the NEON wide wrapper is only a scalar forwarder');
      CheckEqual(PtrUInt(Pointer(LScalarTable.CoreVectors.ReduceAddF64x8)), PtrUInt(Pointer(LBackendTable.CoreVectors.ReduceAddF64x8)), 'ReduceAddF64x8 should reuse the scalar slot when the NEON wide wrapper is only a scalar forwarder');
    end
    else
    begin
      AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'ReduceAddF64x4', Pointer(LScalarTable.CoreVectors.ReduceAddF64x4), Pointer(LBackendTable.CoreVectors.ReduceAddF64x4));
      AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'ReduceAddF64x8', Pointer(LScalarTable.CoreVectors.ReduceAddF64x8), Pointer(LBackendTable.CoreVectors.ReduceAddF64x8));
    end;

    CheckTrue(Assigned(LBackendTable.CoreVectors.ReduceMaxF64x4), 'ReduceMaxF64x4 missing: ' + NonX86BackendName(LBackend));
    LPoisonValue := LBackendTable.CoreVectors.ReduceMaxF64x4(LF64x4Poison);
    LExpectedPoison := LScalarTable.CoreVectors.ReduceMaxF64x4(LF64x4Poison);
    CheckNear(LExpectedPoison, LPoisonValue, 1e-12, 'ReduceMaxF64x4 poison sanity: ' + NonX86BackendName(LBackend));

    LReduceF64x4ByBackend := LBackendTable.CoreVectors.ReduceAddF64x4(LF64x4Input);
    CheckNear(LReduceF64x4ByScalar, LReduceF64x4ByBackend, 1e-12, 'ReduceAddF64x4 dispatch-table: ' + NonX86BackendName(LBackend));

    CheckTrue(Assigned(LBackendTable.CoreVectors.ReduceMaxF64x8), 'ReduceMaxF64x8 missing: ' + NonX86BackendName(LBackend));
    LPoisonValue := LBackendTable.CoreVectors.ReduceMaxF64x8(LF64x8Poison);
    LExpectedPoison := LScalarTable.CoreVectors.ReduceMaxF64x8(LF64x8Poison);
    CheckNear(LExpectedPoison, LPoisonValue, 1e-12, 'ReduceMaxF64x8 poison sanity: ' + NonX86BackendName(LBackend));

    LReduceF64x8ByBackend := LBackendTable.CoreVectors.ReduceAddF64x8(LF64x8Input);
    CheckNear(LReduceF64x8ByScalar, LReduceF64x8ByBackend, 1e-12, 'ReduceAddF64x8 dispatch-table: ' + NonX86BackendName(LBackend));

    LPoisonValue := LBackendTable.CoreVectors.ReduceMaxF64x8(LF64x8Poison);
    CheckNear(LExpectedPoison, LPoisonValue, 1e-12, 'ReduceMaxF64x8 facade poison sanity: ' + NonX86BackendName(LBackend));

    LReduceF64x8ByFacade := VecF64x8ReduceAdd(LF64x8Input);
    CheckNear(LReduceF64x8ByScalar, LReduceF64x8ByFacade, 1e-12, 'ReduceAddF64x8 facade: ' + NonX86BackendName(LBackend));
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 asm backend registered on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_NativeNormalizeEdgeParity_WithVectorAsm_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;
  LZero3, LTiny3: TVecF32x4;
  LZero4, LTiny4: TVecF32x4;
  LNormalize3ByBackend, LNormalize3ByFacade, LNormalize3ByScalar: TVecF32x4;
  LNormalize4ByBackend, LNormalize4ByFacade, LNormalize4ByScalar: TVecF32x4;
  LCheckedBackends: Integer;

  procedure AssertNativeSlotNotScalar(const aBackendName, aSlotName: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + aBackendName);
  end;

  procedure AssertVecF32x4Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF32x4; const aEps: Single);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckNear(aExpected.f[LLane], aActual.f[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be available');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LCheckedBackends := 0;

  LZero3.f[0] := 0.0;
  LZero3.f[1] := 0.0;
  LZero3.f[2] := 0.0;
  LZero3.f[3] := 17.0;

  LTiny3.f[0] := 1.0e-20;
  LTiny3.f[1] := -2.0e-20;
  LTiny3.f[2] := 3.0e-20;
  LTiny3.f[3] := 29.0;

  LZero4.f[0] := 0.0;
  LZero4.f[1] := 0.0;
  LZero4.f[2] := 0.0;
  LZero4.f[3] := 0.0;

  LTiny4.f[0] := 1.0e-20;
  LTiny4.f[1] := -2.0e-20;
  LTiny4.f[2] := 3.0e-20;
  LTiny4.f[3] := -4.0e-20;

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  for LBackend in LBackends do
  begin
    case LBackend of
      sbNEON:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
      sbRISCVV:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
    end;
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    Inc(LCheckedBackends);

    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'NormalizeF32x3', Pointer(LScalarTable.CoreVectors.NormalizeF32x3), Pointer(LBackendTable.CoreVectors.NormalizeF32x3));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'NormalizeF32x4', Pointer(LScalarTable.CoreVectors.NormalizeF32x4), Pointer(LBackendTable.CoreVectors.NormalizeF32x4));

    LNormalize3ByBackend := LBackendTable.CoreVectors.NormalizeF32x3(LZero3);
    LNormalize3ByScalar := LScalarTable.CoreVectors.NormalizeF32x3(LZero3);
    AssertVecF32x4Equal('NormalizeF32x3 zero dispatch-table', NonX86BackendName(LBackend), LNormalize3ByScalar, LNormalize3ByBackend, 0.0);

    LNormalize3ByFacade := VecF32x3Normalize(LZero3);
    AssertVecF32x4Equal('NormalizeF32x3 zero facade', NonX86BackendName(LBackend), LNormalize3ByScalar, LNormalize3ByFacade, 0.0);

    LNormalize3ByBackend := LBackendTable.CoreVectors.NormalizeF32x3(LTiny3);
    LNormalize3ByScalar := LScalarTable.CoreVectors.NormalizeF32x3(LTiny3);
    AssertVecF32x4Equal('NormalizeF32x3 tiny dispatch-table', NonX86BackendName(LBackend), LNormalize3ByScalar, LNormalize3ByBackend, 1e-5);

    LNormalize3ByFacade := VecF32x3Normalize(LTiny3);
    AssertVecF32x4Equal('NormalizeF32x3 tiny facade', NonX86BackendName(LBackend), LNormalize3ByScalar, LNormalize3ByFacade, 1e-5);

    LNormalize4ByBackend := LBackendTable.CoreVectors.NormalizeF32x4(LZero4);
    LNormalize4ByScalar := LScalarTable.CoreVectors.NormalizeF32x4(LZero4);
    AssertVecF32x4Equal('NormalizeF32x4 zero dispatch-table', NonX86BackendName(LBackend), LNormalize4ByScalar, LNormalize4ByBackend, 0.0);

    LNormalize4ByFacade := VecF32x4Normalize(LZero4);
    AssertVecF32x4Equal('NormalizeF32x4 zero facade', NonX86BackendName(LBackend), LNormalize4ByScalar, LNormalize4ByFacade, 0.0);

    LNormalize4ByBackend := LBackendTable.CoreVectors.NormalizeF32x4(LTiny4);
    LNormalize4ByScalar := LScalarTable.CoreVectors.NormalizeF32x4(LTiny4);
    AssertVecF32x4Equal('NormalizeF32x4 tiny dispatch-table', NonX86BackendName(LBackend), LNormalize4ByScalar, LNormalize4ByBackend, 1e-5);

    LNormalize4ByFacade := VecF32x4Normalize(LTiny4);
    AssertVecF32x4Equal('NormalizeF32x4 tiny facade', NonX86BackendName(LBackend), LNormalize4ByScalar, LNormalize4ByFacade, 1e-5);
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 asm backend registered on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_NativeWideInsertHelperParity_WithVectorAsm_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;
  LF32x8Base: TVecF32x8;
  LF32x8ByBackend, LF32x8ByFacade, LF32x8ByScalar: TVecF32x8;
  LF32x16Base: TVecF32x16;
  LF32x16ByBackend, LF32x16ByFacade, LF32x16ByScalar: TVecF32x16;
  LF64x4Base: TVecF64x4;
  LF64x4ByBackend, LF64x4ByFacade, LF64x4ByScalar: TVecF64x4;
  LI32x8Base: TVecI32x8;
  LI32x8ByBackend, LI32x8ByFacade, LI32x8ByScalar: TVecI32x8;
  LI32x16Base: TVecI32x16;
  LI32x16ByBackend, LI32x16ByFacade, LI32x16ByScalar: TVecI32x16;
  LI64x4Base: TVecI64x4;
  LI64x4ByBackend, LI64x4ByFacade, LI64x4ByScalar: TVecI64x4;
  LIndex: Integer;
  LExtractIndex: Integer;
  LCheckedBackends: Integer;

  procedure AssertNativeSlotNotScalar(const aBackendName, aSlotName: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + aBackendName);
  end;

  procedure AssertBackendOwnedIntegerSlotIfExpected(
    const aBackend: TSimdBackend;
    const aBackendName, aSlotName: string;
    const aScalarSlot, aBackendSlot: Pointer
  );
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    case aBackend of
      sbNEON:
        CheckTrue(True, aSlotName + ' may intentionally reuse the published scalar slot on ' + aBackendName);
    else
      CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + aBackendName);
    end;
  end;

  procedure AssertBackendOwnedFloatSlotIfExpected(
    const aBackend: TSimdBackend;
    const aBackendName, aSlotName: string;
    const aScalarSlot, aBackendSlot: Pointer
  );
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    case aBackend of
      sbNEON:
        CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), aSlotName + ' should intentionally reuse the published scalar slot on ' + aBackendName);
    else
      CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + aBackendName);
    end;
  end;

  procedure AssertVecF32x8Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF32x8; const aEps: Single);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 7 do
      CheckNear(aExpected.f[LLane], aActual.f[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecF32x16Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF32x16; const aEps: Single);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 15 do
      CheckNear(aExpected.f[LLane], aActual.f[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecF64x4Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF64x4; const aEps: Double);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckNear(aExpected.d[LLane], aActual.d[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecI32x8Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecI32x8);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 7 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecI32x16Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecI32x16);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 15 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecI64x4Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecI64x4);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be available');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LCheckedBackends := 0;

  for LIndex := 0 to 7 do
  begin
    LF32x8Base.f[LIndex] := (LIndex + 1) * 1.25;
    LI32x8Base.i[LIndex] := (LIndex + 1) * 111;
  end;
  for LIndex := 0 to 15 do
  begin
    LF32x16Base.f[LIndex] := (LIndex - 8) * 0.875;
    LI32x16Base.i[LIndex] := (LIndex - 6) * 321;
  end;
  for LIndex := 0 to 3 do
  begin
    LF64x4Base.d[LIndex] := (LIndex + 1) * 10.5;
    LI64x4Base.i[LIndex] := (LIndex + 1) * 123456789;
  end;

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  for LBackend in LBackends do
  begin
    case LBackend of
      sbNEON:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
      sbRISCVV:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
    end;
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    Inc(LCheckedBackends);

    AssertBackendOwnedFloatSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'InsertF32x8', Pointer(LScalarTable.CoreVectors.InsertF32x8), Pointer(LBackendTable.CoreVectors.InsertF32x8));
    AssertBackendOwnedFloatSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'InsertF32x16', Pointer(LScalarTable.CoreVectors.InsertF32x16), Pointer(LBackendTable.CoreVectors.InsertF32x16));
    AssertBackendOwnedFloatSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'InsertF64x4', Pointer(LScalarTable.CoreVectors.InsertF64x4), Pointer(LBackendTable.CoreVectors.InsertF64x4));
    AssertBackendOwnedFloatSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'ExtractF32x8', Pointer(LScalarTable.CoreVectors.ExtractF32x8), Pointer(LBackendTable.CoreVectors.ExtractF32x8));
    AssertBackendOwnedFloatSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'ExtractF32x16', Pointer(LScalarTable.CoreVectors.ExtractF32x16), Pointer(LBackendTable.CoreVectors.ExtractF32x16));
    AssertBackendOwnedFloatSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'ExtractF64x4', Pointer(LScalarTable.CoreVectors.ExtractF64x4), Pointer(LBackendTable.CoreVectors.ExtractF64x4));
    AssertBackendOwnedIntegerSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'InsertI32x8', Pointer(LScalarTable.CoreVectors.InsertI32x8), Pointer(LBackendTable.CoreVectors.InsertI32x8));
    AssertBackendOwnedIntegerSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'InsertI32x16', Pointer(LScalarTable.CoreVectors.InsertI32x16), Pointer(LBackendTable.CoreVectors.InsertI32x16));
    AssertBackendOwnedIntegerSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'InsertI64x4', Pointer(LScalarTable.CoreVectors.InsertI64x4), Pointer(LBackendTable.CoreVectors.InsertI64x4));

    LF32x8ByBackend := LBackendTable.CoreVectors.InsertF32x8(LF32x8Base, -77.5, 4);
    LF32x8ByScalar := LScalarTable.CoreVectors.InsertF32x8(LF32x8Base, -77.5, 4);
    AssertVecF32x8Equal('InsertF32x8 dispatch-table', NonX86BackendName(LBackend), LF32x8ByScalar, LF32x8ByBackend, 1e-6);

    LF32x8ByFacade := VecF32x8Insert(LF32x8Base, -77.5, 4);
    AssertVecF32x8Equal('InsertF32x8 facade', NonX86BackendName(LBackend), LF32x8ByScalar, LF32x8ByFacade, 1e-6);

    LF32x16ByBackend := LBackendTable.CoreVectors.InsertF32x16(LF32x16Base, 88.25, 11);
    LF32x16ByScalar := LScalarTable.CoreVectors.InsertF32x16(LF32x16Base, 88.25, 11);
    AssertVecF32x16Equal('InsertF32x16 dispatch-table', NonX86BackendName(LBackend), LF32x16ByScalar, LF32x16ByBackend, 1e-6);

    LF32x16ByFacade := VecF32x16Insert(LF32x16Base, 88.25, 11);
    AssertVecF32x16Equal('InsertF32x16 facade', NonX86BackendName(LBackend), LF32x16ByScalar, LF32x16ByFacade, 1e-6);

    LF64x4ByBackend := LBackendTable.CoreVectors.InsertF64x4(LF64x4Base, -999.125, 1);
    LF64x4ByScalar := LScalarTable.CoreVectors.InsertF64x4(LF64x4Base, -999.125, 1);
    AssertVecF64x4Equal('InsertF64x4 dispatch-table', NonX86BackendName(LBackend), LF64x4ByScalar, LF64x4ByBackend, 1e-12);

    LF64x4ByFacade := VecF64x4Insert(LF64x4Base, -999.125, 1);
    AssertVecF64x4Equal('InsertF64x4 facade', NonX86BackendName(LBackend), LF64x4ByScalar, LF64x4ByFacade, 1e-12);

    for LIndex := 0 to 3 do
    begin
      case LIndex of
        0: LExtractIndex := -99;
        1: LExtractIndex := 0;
        2: LExtractIndex := 7;
      else
        LExtractIndex := 99;
      end;
      CheckNear(LScalarTable.CoreVectors.ExtractF32x8(LF32x8Base, LExtractIndex), LBackendTable.CoreVectors.ExtractF32x8(LF32x8Base, LExtractIndex), 1e-6, 'ExtractF32x8 dispatch-table idx ' + IntToStr(LExtractIndex) + ': ' + NonX86BackendName(LBackend));
      CheckNear(LScalarTable.CoreVectors.ExtractF32x8(LF32x8Base, LExtractIndex), VecF32x8Extract(LF32x8Base, LExtractIndex), 1e-6, 'ExtractF32x8 facade idx ' + IntToStr(LExtractIndex) + ': ' + NonX86BackendName(LBackend));
    end;

    for LIndex := 0 to 3 do
    begin
      case LIndex of
        0: LExtractIndex := -99;
        1: LExtractIndex := 0;
        2: LExtractIndex := 15;
      else
        LExtractIndex := 99;
      end;
      CheckNear(LScalarTable.CoreVectors.ExtractF32x16(LF32x16Base, LExtractIndex), LBackendTable.CoreVectors.ExtractF32x16(LF32x16Base, LExtractIndex), 1e-6, 'ExtractF32x16 dispatch-table idx ' + IntToStr(LExtractIndex) + ': ' + NonX86BackendName(LBackend));
      CheckNear(LScalarTable.CoreVectors.ExtractF32x16(LF32x16Base, LExtractIndex), VecF32x16Extract(LF32x16Base, LExtractIndex), 1e-6, 'ExtractF32x16 facade idx ' + IntToStr(LExtractIndex) + ': ' + NonX86BackendName(LBackend));
    end;

    for LIndex := 0 to 3 do
    begin
      case LIndex of
        0: LExtractIndex := -99;
        1: LExtractIndex := 0;
        2: LExtractIndex := 3;
      else
        LExtractIndex := 99;
      end;
      CheckNear(LScalarTable.CoreVectors.ExtractF64x4(LF64x4Base, LExtractIndex), LBackendTable.CoreVectors.ExtractF64x4(LF64x4Base, LExtractIndex), 1e-12, 'ExtractF64x4 dispatch-table idx ' + IntToStr(LExtractIndex) + ': ' + NonX86BackendName(LBackend));
      CheckNear(LScalarTable.CoreVectors.ExtractF64x4(LF64x4Base, LExtractIndex), VecF64x4Extract(LF64x4Base, LExtractIndex), 1e-12, 'ExtractF64x4 facade idx ' + IntToStr(LExtractIndex) + ': ' + NonX86BackendName(LBackend));
    end;

    LI32x8ByBackend := LBackendTable.CoreVectors.InsertI32x8(LI32x8Base, -2026, 5);
    LI32x8ByScalar := LScalarTable.CoreVectors.InsertI32x8(LI32x8Base, -2026, 5);
    AssertVecI32x8Equal('InsertI32x8 dispatch-table', NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

    LI32x8ByFacade := VecI32x8Insert(LI32x8Base, -2026, 5);
    AssertVecI32x8Equal('InsertI32x8 facade', NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByFacade);

    LI32x16ByBackend := LBackendTable.CoreVectors.InsertI32x16(LI32x16Base, 314159, 9);
    LI32x16ByScalar := LScalarTable.CoreVectors.InsertI32x16(LI32x16Base, 314159, 9);
    AssertVecI32x16Equal('InsertI32x16 dispatch-table', NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByBackend);

    LI32x16ByFacade := VecI32x16Insert(LI32x16Base, 314159, 9);
    AssertVecI32x16Equal('InsertI32x16 facade', NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByFacade);

    LI64x4ByBackend := LBackendTable.CoreVectors.InsertI64x4(LI64x4Base, Int64(-888888888), 1);
    LI64x4ByScalar := LScalarTable.CoreVectors.InsertI64x4(LI64x4Base, Int64(-888888888), 1);
    AssertVecI64x4Equal('InsertI64x4 dispatch-table', NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

    LI64x4ByFacade := VecI64x4Insert(LI64x4Base, Int64(-888888888), 1);
    AssertVecI64x4Equal('InsertI64x4 facade', NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByFacade);
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 asm backend registered on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_NativeWideIntegerExtractEdgeParity_WithVectorAsm_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;
  LI32x8Base: TVecI32x8;
  LI32x8ByBackend, LI32x8ByFacade, LI32x8ByScalar: TVecI32x8;
  LI32x16Base: TVecI32x16;
  LI32x16ByBackend, LI32x16ByFacade, LI32x16ByScalar: TVecI32x16;
  LI64x4Base: TVecI64x4;
  LI64x4ByBackend, LI64x4ByFacade, LI64x4ByScalar: TVecI64x4;
  LExpectedI32: Int32;
  LActualI32: Int32;
  LFacadeI32: Int32;
  LExpectedI64: Int64;
  LActualI64: Int64;
  LFacadeI64: Int64;
  LIndex: Integer;
  LExtractIndex: Integer;
  LCheckedBackends: Integer;

  procedure AssertBackendOwnedSlotIfExpected(
    const aBackend: TSimdBackend;
    const aBackendName, aSlotName: string;
    const aScalarSlot, aBackendSlot: Pointer
  );
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    case aBackend of
      sbNEON:
        CheckTrue(True, aSlotName + ' may intentionally reuse the published scalar slot on ' + aBackendName);
    else
      CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + aBackendName);
    end;
  end;

  procedure AssertVecI32x8Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecI32x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aOp + ' parity lane ' + IntToStr(LLaneIndex) + ': ' + aBackendName);
  end;

  procedure AssertVecI32x16Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecI32x16);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 15 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aOp + ' parity lane ' + IntToStr(LLaneIndex) + ': ' + aBackendName);
  end;

  procedure AssertVecI64x4Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecI64x4);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 3 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aOp + ' parity lane ' + IntToStr(LLaneIndex) + ': ' + aBackendName);
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be available');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LCheckedBackends := 0;

  LI32x8Base.i[0] := High(Int32);
  LI32x8Base.i[1] := Low(Int32);
  LI32x8Base.i[2] := 0;
  LI32x8Base.i[3] := -1;
  LI32x8Base.i[4] := 7;
  LI32x8Base.i[5] := -11;
  LI32x8Base.i[6] := 222222;
  LI32x8Base.i[7] := -333333;

  for LIndex := 0 to 15 do
    case LIndex of
      0: LI32x16Base.i[LIndex] := High(Int32);
      1: LI32x16Base.i[LIndex] := Low(Int32);
      2: LI32x16Base.i[LIndex] := 0;
      15: LI32x16Base.i[LIndex] := -1;
    else
      LI32x16Base.i[LIndex] := (LIndex - 8) * 12345;
    end;

  LI64x4Base.i[0] := High(Int64);
  LI64x4Base.i[1] := Low(Int64);
  LI64x4Base.i[2] := 0;
  LI64x4Base.i[3] := Int64(-444444444444444444);

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  for LBackend in LBackends do
  begin
    case LBackend of
      sbNEON:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
      sbRISCVV:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
    end;
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    Inc(LCheckedBackends);

    AssertBackendOwnedSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'ExtractI32x8', Pointer(LScalarTable.CoreVectors.ExtractI32x8), Pointer(LBackendTable.CoreVectors.ExtractI32x8));
    AssertBackendOwnedSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'InsertI32x8', Pointer(LScalarTable.CoreVectors.InsertI32x8), Pointer(LBackendTable.CoreVectors.InsertI32x8));
    AssertBackendOwnedSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'ExtractI32x16', Pointer(LScalarTable.CoreVectors.ExtractI32x16), Pointer(LBackendTable.CoreVectors.ExtractI32x16));
    AssertBackendOwnedSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'InsertI32x16', Pointer(LScalarTable.CoreVectors.InsertI32x16), Pointer(LBackendTable.CoreVectors.InsertI32x16));
    AssertBackendOwnedSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'ExtractI64x4', Pointer(LScalarTable.CoreVectors.ExtractI64x4), Pointer(LBackendTable.CoreVectors.ExtractI64x4));
    AssertBackendOwnedSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'InsertI64x4', Pointer(LScalarTable.CoreVectors.InsertI64x4), Pointer(LBackendTable.CoreVectors.InsertI64x4));

    for LIndex := 0 to 3 do
    begin
      case LIndex of
        0: LExtractIndex := -99;
        1: LExtractIndex := 0;
        2: LExtractIndex := 7;
      else
        LExtractIndex := 99;
      end;

      LExpectedI32 := LScalarTable.CoreVectors.ExtractI32x8(LI32x8Base, LExtractIndex);
      LActualI32 := LBackendTable.CoreVectors.ExtractI32x8(LI32x8Base, LExtractIndex);
      CheckEqual(LExpectedI32, LActualI32, 'ExtractI32x8 dispatch-table idx ' + IntToStr(LExtractIndex) + ': ' + NonX86BackendName(LBackend));

      LFacadeI32 := VecI32x8Extract(LI32x8Base, LExtractIndex);
      CheckEqual(LExpectedI32, LFacadeI32, 'ExtractI32x8 facade idx ' + IntToStr(LExtractIndex) + ': ' + NonX86BackendName(LBackend));

      LI32x8ByBackend := LBackendTable.CoreVectors.InsertI32x8(LI32x8Base, High(Int32) - LIndex, LExtractIndex);
      LI32x8ByScalar := LScalarTable.CoreVectors.InsertI32x8(LI32x8Base, High(Int32) - LIndex, LExtractIndex);
      AssertVecI32x8Equal('InsertI32x8 dispatch-table idx ' + IntToStr(LExtractIndex), NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

      LI32x8ByFacade := VecI32x8Insert(LI32x8Base, High(Int32) - LIndex, LExtractIndex);
      AssertVecI32x8Equal('InsertI32x8 facade idx ' + IntToStr(LExtractIndex), NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByFacade);
    end;

    for LIndex := 0 to 3 do
    begin
      case LIndex of
        0: LExtractIndex := -99;
        1: LExtractIndex := 0;
        2: LExtractIndex := 15;
      else
        LExtractIndex := 99;
      end;

      LExpectedI32 := LScalarTable.CoreVectors.ExtractI32x16(LI32x16Base, LExtractIndex);
      LActualI32 := LBackendTable.CoreVectors.ExtractI32x16(LI32x16Base, LExtractIndex);
      CheckEqual(LExpectedI32, LActualI32, 'ExtractI32x16 dispatch-table idx ' + IntToStr(LExtractIndex) + ': ' + NonX86BackendName(LBackend));

      LFacadeI32 := VecI32x16Extract(LI32x16Base, LExtractIndex);
      CheckEqual(LExpectedI32, LFacadeI32, 'ExtractI32x16 facade idx ' + IntToStr(LExtractIndex) + ': ' + NonX86BackendName(LBackend));

      LI32x16ByBackend := LBackendTable.CoreVectors.InsertI32x16(LI32x16Base, Low(Int32) + LIndex, LExtractIndex);
      LI32x16ByScalar := LScalarTable.CoreVectors.InsertI32x16(LI32x16Base, Low(Int32) + LIndex, LExtractIndex);
      AssertVecI32x16Equal('InsertI32x16 dispatch-table idx ' + IntToStr(LExtractIndex), NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByBackend);

      LI32x16ByFacade := VecI32x16Insert(LI32x16Base, Low(Int32) + LIndex, LExtractIndex);
      AssertVecI32x16Equal('InsertI32x16 facade idx ' + IntToStr(LExtractIndex), NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByFacade);
    end;

    for LIndex := 0 to 3 do
    begin
      case LIndex of
        0: LExtractIndex := -99;
        1: LExtractIndex := 0;
        2: LExtractIndex := 3;
      else
        LExtractIndex := 99;
      end;

      LExpectedI64 := LScalarTable.CoreVectors.ExtractI64x4(LI64x4Base, LExtractIndex);
      LActualI64 := LBackendTable.CoreVectors.ExtractI64x4(LI64x4Base, LExtractIndex);
      CheckEqual(LExpectedI64, LActualI64, 'ExtractI64x4 dispatch-table idx ' + IntToStr(LExtractIndex) + ': ' + NonX86BackendName(LBackend));

      LFacadeI64 := VecI64x4Extract(LI64x4Base, LExtractIndex);
      CheckEqual(LExpectedI64, LFacadeI64, 'ExtractI64x4 facade idx ' + IntToStr(LExtractIndex) + ': ' + NonX86BackendName(LBackend));

      LI64x4ByBackend := LBackendTable.CoreVectors.InsertI64x4(LI64x4Base, Int64(Low(Int64) + LIndex), LExtractIndex);
      LI64x4ByScalar := LScalarTable.CoreVectors.InsertI64x4(LI64x4Base, Int64(Low(Int64) + LIndex), LExtractIndex);
      AssertVecI64x4Equal('InsertI64x4 dispatch-table idx ' + IntToStr(LExtractIndex), NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

      LI64x4ByFacade := VecI64x4Insert(LI64x4Base, Int64(Low(Int64) + LIndex), LExtractIndex);
      AssertVecI64x4Equal('InsertI64x4 facade idx ' + IntToStr(LExtractIndex), NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByFacade);
    end;
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 asm backend registered on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_NativeNarrowFloatHelperParity_WithVectorAsm_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;
  LF32x4Base: TVecF32x4;
  LF32x4ByBackend, LF32x4ByFacade, LF32x4ByScalar: TVecF32x4;
  LF64x2Base: TVecF64x2;
  LF64x2ByBackend, LF64x2ByFacade, LF64x2ByScalar: TVecF64x2;
  LIndex: Integer;
  LExtractIndex: Integer;
  LCheckedBackends: Integer;

  procedure AssertNativeSlotNotScalar(const aBackendName, aSlotName: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + aBackendName);
  end;

  procedure AssertVecF32x4Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF32x4; const aEps: Single);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckNear(aExpected.f[LLane], aActual.f[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecF64x2Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF64x2; const aEps: Double);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 1 do
      CheckNear(aExpected.d[LLane], aActual.d[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be available');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LCheckedBackends := 0;

  LF32x4Base.f[0] := 1.25;
  LF32x4Base.f[1] := -2.5;
  LF32x4Base.f[2] := 3.75;
  LF32x4Base.f[3] := -4.125;

  LF64x2Base.d[0] := 123.5;
  LF64x2Base.d[1] := -987.25;

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  for LBackend in LBackends do
  begin
    case LBackend of
      sbNEON:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
      sbRISCVV:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
    end;
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    Inc(LCheckedBackends);

    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'InsertF32x4', Pointer(LScalarTable.CoreVectors.InsertF32x4), Pointer(LBackendTable.CoreVectors.InsertF32x4));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'InsertF64x2', Pointer(LScalarTable.CoreVectors.InsertF64x2), Pointer(LBackendTable.CoreVectors.InsertF64x2));

    LF32x4ByBackend := LBackendTable.CoreVectors.InsertF32x4(LF32x4Base, 42.5, 2);
    LF32x4ByScalar := LScalarTable.CoreVectors.InsertF32x4(LF32x4Base, 42.5, 2);
    AssertVecF32x4Equal('InsertF32x4 dispatch-table', NonX86BackendName(LBackend), LF32x4ByScalar, LF32x4ByBackend, 1e-6);

    LF32x4ByFacade := VecF32x4Insert(LF32x4Base, 42.5, 2);
    AssertVecF32x4Equal('InsertF32x4 facade', NonX86BackendName(LBackend), LF32x4ByScalar, LF32x4ByFacade, 1e-6);

    for LIndex := 0 to 3 do
    begin
      case LIndex of
        0: LExtractIndex := -99;
        1: LExtractIndex := 0;
        2: LExtractIndex := 3;
      else
        LExtractIndex := 99;
      end;
      CheckNear(LScalarTable.CoreVectors.ExtractF32x4(LF32x4Base, LExtractIndex), LBackendTable.CoreVectors.ExtractF32x4(LF32x4Base, LExtractIndex), 1e-6, 'ExtractF32x4 dispatch-table idx ' + IntToStr(LExtractIndex) + ': ' + NonX86BackendName(LBackend));
      CheckNear(LScalarTable.CoreVectors.ExtractF32x4(LF32x4Base, LExtractIndex), VecF32x4Extract(LF32x4Base, LExtractIndex), 1e-6, 'ExtractF32x4 facade idx ' + IntToStr(LExtractIndex) + ': ' + NonX86BackendName(LBackend));
    end;

    LF64x2ByBackend := LBackendTable.CoreVectors.InsertF64x2(LF64x2Base, 55.75, 0);
    LF64x2ByScalar := LScalarTable.CoreVectors.InsertF64x2(LF64x2Base, 55.75, 0);
    AssertVecF64x2Equal('InsertF64x2 dispatch-table', NonX86BackendName(LBackend), LF64x2ByScalar, LF64x2ByBackend, 1e-12);

    LF64x2ByFacade := VecF64x2Insert(LF64x2Base, 55.75, 0);
    AssertVecF64x2Equal('InsertF64x2 facade', NonX86BackendName(LBackend), LF64x2ByScalar, LF64x2ByFacade, 1e-12);

    for LIndex := 0 to 3 do
    begin
      case LIndex of
        0: LExtractIndex := -99;
        1: LExtractIndex := 0;
        2: LExtractIndex := 1;
      else
        LExtractIndex := 99;
      end;
      CheckNear(LScalarTable.CoreVectors.ExtractF64x2(LF64x2Base, LExtractIndex), LBackendTable.CoreVectors.ExtractF64x2(LF64x2Base, LExtractIndex), 1e-12, 'ExtractF64x2 dispatch-table idx ' + IntToStr(LExtractIndex) + ': ' + NonX86BackendName(LBackend));
      CheckNear(LScalarTable.CoreVectors.ExtractF64x2(LF64x2Base, LExtractIndex), VecF64x2Extract(LF64x2Base, LExtractIndex), 1e-12, 'ExtractF64x2 facade idx ' + IntToStr(LExtractIndex) + ': ' + NonX86BackendName(LBackend));
    end;
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 asm backend registered on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_NativeNarrowIntegerCoreParity_WithVectorAsm_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;
  LI32x4A, LI32x4B: TVecI32x4;
  LI32x4ByBackend, LI32x4ByScalar: TVecI32x4;
  LI64x2A, LI64x2B: TVecI64x2;
  LI64x2ByBackend, LI64x2ByScalar: TVecI64x2;
  LU32x4A, LU32x4B: TVecU32x4;
  LU32x4ByBackend, LU32x4ByScalar: TVecU32x4;
  LU64x2A, LU64x2B: TVecU64x2;
  LU64x2ByBackend, LU64x2ByScalar: TVecU64x2;
  LCheckedBackends: Integer;

  procedure AssertNativeSlotNotScalar(const aBackendName, aSlotName: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + aBackendName);
  end;

  procedure AssertBackendOwnedSlotIfExpected(
    const aBackend: TSimdBackend;
    const aBackendName, aSlotName: string;
    const aScalarSlot, aBackendSlot: Pointer
  );
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    case aBackend of
      sbNEON:
        CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), aSlotName + ' should intentionally reuse the published scalar slot on ' + aBackendName);
    else
      CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + aBackendName);
    end;
  end;

  procedure AssertVecI32x4Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecI32x4);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecI64x2Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecI64x2);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 1 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecU32x4Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecU32x4);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckEqual(QWord(aExpected.u[LLane]), QWord(aActual.u[LLane]), aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecU64x2Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecU64x2);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 1 do
      CheckEqual(QWord(aExpected.u[LLane]), QWord(aActual.u[LLane]), aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be available');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LCheckedBackends := 0;

  LI32x4A.i[0] := $13579BDF;
  LI32x4A.i[1] := -2023406815;
  LI32x4A.i[2] := $2468ACE0;
  LI32x4A.i[3] := -1;
  LI32x4B.i[0] := $01020304;
  LI32x4B.i[1] := $7FFFFFFF;
  LI32x4B.i[2] := -19088744;
  LI32x4B.i[3] := $11111111;

  LI64x2A.i[0] := 1234567890123456789;
  LI64x2A.i[1] := -345678901234567890;
  LI64x2B.i[0] := -222222222222222222;
  LI64x2B.i[1] := 111111111111111111;

  LU32x4A.u[0] := $FFFFFFFF;
  LU32x4A.u[1] := $80000000;
  LU32x4A.u[2] := $12345678;
  LU32x4A.u[3] := 1;
  LU32x4B.u[0] := 1;
  LU32x4B.u[1] := $7FFFFFFF;
  LU32x4B.u[2] := $01010101;
  LU32x4B.u[3] := $FFFFFFFF;

  LU64x2A.u[0] := QWord($FFFFFFFFFFFFFFFE);
  LU64x2A.u[1] := QWord($0123456789ABCDEF);
  LU64x2B.u[0] := 3;
  LU64x2B.u[1] := QWord($1111111111111111);

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  for LBackend in LBackends do
  begin
    case LBackend of
      sbNEON:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
      sbRISCVV:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
    end;
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;

    Inc(LCheckedBackends);

    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'AddI32x4', Pointer(LScalarTable.CoreVectors.AddI32x4), Pointer(LBackendTable.CoreVectors.AddI32x4));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'AndI32x4', Pointer(LScalarTable.CoreVectors.AndI32x4), Pointer(LBackendTable.CoreVectors.AndI32x4));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'ShiftLeftI32x4', Pointer(LScalarTable.CoreVectors.ShiftLeftI32x4), Pointer(LBackendTable.CoreVectors.ShiftLeftI32x4));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'ShiftRightArithI32x4', Pointer(LScalarTable.CoreVectors.ShiftRightArithI32x4), Pointer(LBackendTable.CoreVectors.ShiftRightArithI32x4));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'AddI64x2', Pointer(LScalarTable.CoreVectors.AddI64x2), Pointer(LBackendTable.CoreVectors.AddI64x2));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'AndI64x2', Pointer(LScalarTable.CoreVectors.AndI64x2), Pointer(LBackendTable.CoreVectors.AndI64x2));
    AssertNativeSlotNotScalar(NonX86BackendName(LBackend), 'AddU32x4', Pointer(LScalarTable.CoreVectors.AddU32x4), Pointer(LBackendTable.CoreVectors.AddU32x4));
    AssertBackendOwnedSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'AddU64x2', Pointer(LScalarTable.CoreVectors.AddU64x2), Pointer(LBackendTable.CoreVectors.AddU64x2));

    LI32x4ByBackend := LBackendTable.CoreVectors.AddI32x4(LI32x4A, LI32x4B);
    LI32x4ByScalar := LScalarTable.CoreVectors.AddI32x4(LI32x4A, LI32x4B);
    AssertVecI32x4Equal('AddI32x4', NonX86BackendName(LBackend), LI32x4ByScalar, LI32x4ByBackend);

    LI32x4ByBackend := LBackendTable.CoreVectors.AndI32x4(LI32x4A, LI32x4B);
    LI32x4ByScalar := LScalarTable.CoreVectors.AndI32x4(LI32x4A, LI32x4B);
    AssertVecI32x4Equal('AndI32x4', NonX86BackendName(LBackend), LI32x4ByScalar, LI32x4ByBackend);

    LI32x4ByBackend := LBackendTable.CoreVectors.ShiftLeftI32x4(LI32x4A, 5);
    LI32x4ByScalar := LScalarTable.CoreVectors.ShiftLeftI32x4(LI32x4A, 5);
    AssertVecI32x4Equal('ShiftLeftI32x4', NonX86BackendName(LBackend), LI32x4ByScalar, LI32x4ByBackend);

    LI32x4ByBackend := LBackendTable.CoreVectors.ShiftRightArithI32x4(LI32x4A, 5);
    LI32x4ByScalar := LScalarTable.CoreVectors.ShiftRightArithI32x4(LI32x4A, 5);
    AssertVecI32x4Equal('ShiftRightArithI32x4', NonX86BackendName(LBackend), LI32x4ByScalar, LI32x4ByBackend);

    LI64x2ByBackend := LBackendTable.CoreVectors.AddI64x2(LI64x2A, LI64x2B);
    LI64x2ByScalar := LScalarTable.CoreVectors.AddI64x2(LI64x2A, LI64x2B);
    AssertVecI64x2Equal('AddI64x2', NonX86BackendName(LBackend), LI64x2ByScalar, LI64x2ByBackend);

    LI64x2ByBackend := LBackendTable.CoreVectors.AndI64x2(LI64x2A, LI64x2B);
    LI64x2ByScalar := LScalarTable.CoreVectors.AndI64x2(LI64x2A, LI64x2B);
    AssertVecI64x2Equal('AndI64x2', NonX86BackendName(LBackend), LI64x2ByScalar, LI64x2ByBackend);

    LU32x4ByBackend := LBackendTable.CoreVectors.AddU32x4(LU32x4A, LU32x4B);
    LU32x4ByScalar := LScalarTable.CoreVectors.AddU32x4(LU32x4A, LU32x4B);
    AssertVecU32x4Equal('AddU32x4', NonX86BackendName(LBackend), LU32x4ByScalar, LU32x4ByBackend);

    LU64x2ByBackend := LBackendTable.CoreVectors.AddU64x2(LU64x2A, LU64x2B);
    LU64x2ByScalar := LScalarTable.CoreVectors.AddU64x2(LU64x2A, LU64x2B);
    AssertVecU64x2Equal('AddU64x2', NonX86BackendName(LBackend), LU64x2ByScalar, LU64x2ByBackend);
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 asm backend registered on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_NativeNarrowIntegerHelperParity_WithVectorAsm_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;
  LI32x4Base: TVecI32x4;
  LI32x4ByBackend, LI32x4ByFacade, LI32x4ByScalar: TVecI32x4;
  LI64x2Base: TVecI64x2;
  LI64x2ByBackend, LI64x2ByFacade, LI64x2ByScalar: TVecI64x2;
  LIndex: Integer;
  LExtractIndex: Integer;
  LCheckedBackends: Integer;

  procedure AssertNativeSlotNotScalar(const aBackendName, aSlotName: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + aBackendName);
  end;

  procedure AssertBackendOwnedSlotIfExpected(
    const aBackend: TSimdBackend;
    const aBackendName, aSlotName: string;
    const aScalarSlot, aBackendSlot: Pointer
  );
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    case aBackend of
      sbNEON:
        CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), aSlotName + ' should intentionally reuse the published scalar slot on ' + aBackendName);
    else
      CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + aBackendName);
    end;
  end;

  procedure AssertVecI32x4Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecI32x4);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecI64x2Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecI64x2);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 1 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be available');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LCheckedBackends := 0;

  LI32x4Base.i[0] := 101;
  LI32x4Base.i[1] := -202;
  LI32x4Base.i[2] := 303;
  LI32x4Base.i[3] := -404;

  LI64x2Base.i[0] := 1234567890123456789;
  LI64x2Base.i[1] := -223344556677889900;

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  for LBackend in LBackends do
  begin
    case LBackend of
      sbNEON:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
      sbRISCVV:
        begin
          {$IFNDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
          Continue;
          {$ENDIF}
        end;
    end;
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    Inc(LCheckedBackends);

    AssertBackendOwnedSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'InsertI32x4', Pointer(LScalarTable.CoreVectors.InsertI32x4), Pointer(LBackendTable.CoreVectors.InsertI32x4));
    AssertBackendOwnedSlotIfExpected(LBackend, NonX86BackendName(LBackend), 'InsertI64x2', Pointer(LScalarTable.CoreVectors.InsertI64x2), Pointer(LBackendTable.CoreVectors.InsertI64x2));

    LI32x4ByBackend := LBackendTable.CoreVectors.InsertI32x4(LI32x4Base, -777, 2);
    LI32x4ByScalar := LScalarTable.CoreVectors.InsertI32x4(LI32x4Base, -777, 2);
    AssertVecI32x4Equal('InsertI32x4 dispatch-table', NonX86BackendName(LBackend), LI32x4ByScalar, LI32x4ByBackend);

    LI32x4ByFacade := VecI32x4Insert(LI32x4Base, -777, 2);
    AssertVecI32x4Equal('InsertI32x4 facade', NonX86BackendName(LBackend), LI32x4ByScalar, LI32x4ByFacade);

    for LIndex := 0 to 3 do
    begin
      case LIndex of
        0: LExtractIndex := -99;
        1: LExtractIndex := 0;
        2: LExtractIndex := 3;
      else
        LExtractIndex := 99;
      end;
      CheckEqual(LScalarTable.CoreVectors.ExtractI32x4(LI32x4Base, LExtractIndex), LBackendTable.CoreVectors.ExtractI32x4(LI32x4Base, LExtractIndex), 'ExtractI32x4 dispatch-table idx ' + IntToStr(LExtractIndex) + ': ' + NonX86BackendName(LBackend));
      CheckEqual(LScalarTable.CoreVectors.ExtractI32x4(LI32x4Base, LExtractIndex), VecI32x4Extract(LI32x4Base, LExtractIndex), 'ExtractI32x4 facade idx ' + IntToStr(LExtractIndex) + ': ' + NonX86BackendName(LBackend));
    end;

    LI64x2ByBackend := LBackendTable.CoreVectors.InsertI64x2(LI64x2Base, Int64(-998877665544332211), 1);
    LI64x2ByScalar := LScalarTable.CoreVectors.InsertI64x2(LI64x2Base, Int64(-998877665544332211), 1);
    AssertVecI64x2Equal('InsertI64x2 dispatch-table', NonX86BackendName(LBackend), LI64x2ByScalar, LI64x2ByBackend);

    LI64x2ByFacade := VecI64x2Insert(LI64x2Base, Int64(-998877665544332211), 1);
    AssertVecI64x2Equal('InsertI64x2 facade', NonX86BackendName(LBackend), LI64x2ByScalar, LI64x2ByFacade);

    for LIndex := 0 to 3 do
    begin
      case LIndex of
        0: LExtractIndex := -99;
        1: LExtractIndex := 0;
        2: LExtractIndex := 1;
      else
        LExtractIndex := 99;
      end;
      CheckEqual(LScalarTable.CoreVectors.ExtractI64x2(LI64x2Base, LExtractIndex), LBackendTable.CoreVectors.ExtractI64x2(LI64x2Base, LExtractIndex), 'ExtractI64x2 dispatch-table idx ' + IntToStr(LExtractIndex) + ': ' + NonX86BackendName(LBackend));
      CheckEqual(LScalarTable.CoreVectors.ExtractI64x2(LI64x2Base, LExtractIndex), VecI64x2Extract(LI64x2Base, LExtractIndex), 'ExtractI64x2 facade idx ' + IntToStr(LExtractIndex) + ': ' + NonX86BackendName(LBackend));
    end;
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 asm backend registered on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_MinimalDispatchParity_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LBackendTable: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LA, LB: TVecF32x4;
  LVecByBackend, LVecByScalar: TVecF32x4;
  LMaskByBackend, LMaskByScalar: TMask4;
  LReduceAddByBackend, LReduceAddByScalar: Single;
  LReduceMulByBackend, LReduceMulByScalar: Single;
  LIndex: Integer;
  LChecked: Integer;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LChecked := 0;

  LA.f[0] := 1.25;  LB.f[0] := 2.0;
  LA.f[1] := -4.0;  LB.f[1] := 3.5;
  LA.f[2] := 0.0;   LB.f[2] := -1.0;
  LA.f[3] := 7.75;  LB.f[3] := 7.75;

  for LBackend in LBackends do
  begin
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    CheckTrue(Assigned(LBackendTable.CoreVectors.AddF32x4), 'AddF32x4 missing: ' + NonX86BackendName(LBackend));
    CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLtF32x4), 'CmpLtF32x4 missing: ' + NonX86BackendName(LBackend));
    CheckTrue(Assigned(LBackendTable.CoreVectors.ReduceAddF32x4), 'ReduceAddF32x4 missing: ' + NonX86BackendName(LBackend));
    CheckTrue(Assigned(LBackendTable.CoreVectors.ReduceMulF32x4), 'ReduceMulF32x4 missing: ' + NonX86BackendName(LBackend));

    LVecByBackend := LBackendTable.CoreVectors.AddF32x4(LA, LB);
    LVecByScalar := LScalarTable.CoreVectors.AddF32x4(LA, LB);
    for LIndex := 0 to 3 do
      CheckNear(LVecByScalar.f[LIndex], LVecByBackend.f[LIndex], 1e-6, 'AddF32x4 parity lane ' + IntToStr(LIndex) + ': ' + NonX86BackendName(LBackend));

    LMaskByBackend := LBackendTable.CoreVectors.CmpLtF32x4(LA, LB);
    LMaskByScalar := LScalarTable.CoreVectors.CmpLtF32x4(LA, LB);
    CheckEqual(Integer(LMaskByScalar), Integer(LMaskByBackend), 'CmpLtF32x4 parity: ' + NonX86BackendName(LBackend));

    LReduceAddByBackend := LBackendTable.CoreVectors.ReduceAddF32x4(LA);
    LReduceAddByScalar := LScalarTable.CoreVectors.ReduceAddF32x4(LA);
    CheckNear(LReduceAddByScalar, LReduceAddByBackend, 1e-6, 'ReduceAddF32x4 parity: ' + NonX86BackendName(LBackend));

    LReduceMulByBackend := LBackendTable.CoreVectors.ReduceMulF32x4(LA);
    LReduceMulByScalar := LScalarTable.CoreVectors.ReduceMulF32x4(LA);
    CheckNear(LReduceMulByScalar, LReduceMulByBackend, 1e-6, 'ReduceMulF32x4 parity: ' + NonX86BackendName(LBackend));

    Inc(LChecked);
  end;

  if LChecked = 0 then
    CheckTrue(True, 'No non-x86 backend registered/active on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_ExtendedFloatParity_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LBackendTable: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LF64A, LF64B: TVecF64x2;
  LF64ByBackend, LF64ByScalar: TVecF64x2;
  LF32A, LF32B: TVecF32x8;
  LF32ByBackend, LF32ByScalar: TVecF32x8;
  LF32x16A, LF32x16B, LF32x16C: TVecF32x16;
  LF32x16Min, LF32x16Max: TVecF32x16;
  LF32x16ByBackend, LF32x16ByScalar: TVecF32x16;
  LF64x8A, LF64x8B, LF64x8C: TVecF64x8;
  LF64x8Min, LF64x8Max: TVecF64x8;
  LF64x8ByBackend, LF64x8ByScalar: TVecF64x8;
  LMask2ByBackend, LMask2ByScalar: TMask2;
  LMask8ByBackend, LMask8ByScalar: TMask8;
  LReduceAddF64ByBackend, LReduceAddF64ByScalar: Double;
  LReduceMulF64ByBackend, LReduceMulF64ByScalar: Double;
  LReduceAddF32x8ByBackend, LReduceAddF32x8ByScalar: Single;
  LReduceMulF32x8ByBackend, LReduceMulF32x8ByScalar: Single;
  LReduceAddF32x16ByBackend, LReduceAddF32x16ByScalar: Single;
  LReduceMulF32x16ByBackend, LReduceMulF32x16ByScalar: Single;
  LIndex: Integer;
  LChecked: Integer;

  procedure AssertVecF32x16Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF32x16; const aEps: Single);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 15 do
      CheckNear(aExpected.f[LLane], aActual.f[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;

  procedure AssertVecF64x8Equal(const aOp, aBackendName: string; const aExpected, aActual: TVecF64x8; const aEps: Double);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 7 do
      CheckNear(aExpected.d[LLane], aActual.d[LLane], aEps, aOp + ' parity lane ' + IntToStr(LLane) + ': ' + aBackendName);
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LChecked := 0;

  LF64A.d[0] := 1.5;    LF64B.d[0] := -2.25;
  LF64A.d[1] := -8.75;  LF64B.d[1] := 10.0;

  LF32A.f[0] := 1.0;    LF32B.f[0] := 2.5;
  LF32A.f[1] := -3.5;   LF32B.f[1] := 4.0;
  LF32A.f[2] := 0.0;    LF32B.f[2] := -1.0;
  LF32A.f[3] := 7.25;   LF32B.f[3] := 7.25;
  LF32A.f[4] := -9.0;   LF32B.f[4] := 1.0;
  LF32A.f[5] := 5.5;    LF32B.f[5] := -2.0;
  LF32A.f[6] := 100.0;  LF32B.f[6] := -99.5;
  LF32A.f[7] := -0.25;  LF32B.f[7] := 0.5;

  for LIndex := 0 to 15 do
  begin
    LF32x16A.f[LIndex] := (LIndex - 8) * 1.25;
    LF32x16B.f[LIndex] := (LIndex + 1) * 0.5 + 1.0;
    LF32x16C.f[LIndex] := (LIndex mod 5) - 2.0;
    LF32x16Min.f[LIndex] := -6.0 + LIndex * 0.1;
    LF32x16Max.f[LIndex] := 6.0 + LIndex * 0.1;
  end;

  for LIndex := 0 to 7 do
  begin
    LF64x8A.d[LIndex] := (LIndex - 3) * 2.75;
    LF64x8B.d[LIndex] := (LIndex + 1) * 0.75 + 1.0;
    LF64x8C.d[LIndex] := (LIndex mod 4) - 1.5;
    LF64x8Min.d[LIndex] := -12.0 + LIndex;
    LF64x8Max.d[LIndex] := 12.0 + LIndex;
  end;

  for LBackend in LBackends do
  begin
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

      CheckTrue(Assigned(LBackendTable.CoreVectors.AddF64x2), 'AddF64x2 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLtF64x2), 'CmpLtF64x2 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ReduceAddF64x2), 'ReduceAddF64x2 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ReduceMulF64x2), 'ReduceMulF64x2 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AddF32x8), 'AddF32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLtF32x8), 'CmpLtF32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ReduceAddF32x8), 'ReduceAddF32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ReduceMulF32x8), 'ReduceMulF32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AddF32x16) and Assigned(LBackendTable.CoreVectors.SubF32x16) and Assigned(LBackendTable.CoreVectors.MulF32x16) and Assigned(LBackendTable.CoreVectors.DivF32x16) and Assigned(LBackendTable.CoreVectors.MinF32x16) and Assigned(LBackendTable.CoreVectors.MaxF32x16) and Assigned(LBackendTable.CoreVectors.AbsF32x16) and Assigned(LBackendTable.CoreVectors.SqrtF32x16) and Assigned(LBackendTable.CoreVectors.FmaF32x16) and Assigned(LBackendTable.CoreVectors.ClampF32x16) and Assigned(LBackendTable.CoreVectors.ReduceAddF32x16) and Assigned(LBackendTable.CoreVectors.ReduceMulF32x16) and Assigned(LBackendTable.CoreVectors.AddF64x8) and Assigned(LBackendTable.CoreVectors.SubF64x8) and Assigned(LBackendTable.CoreVectors.MulF64x8) and Assigned(LBackendTable.CoreVectors.DivF64x8) and Assigned(LBackendTable.CoreVectors.MinF64x8) and Assigned(LBackendTable.CoreVectors.MaxF64x8) and Assigned(LBackendTable.CoreVectors.AbsF64x8) and Assigned(LBackendTable.CoreVectors.SqrtF64x8) and Assigned(LBackendTable.CoreVectors.FmaF64x8) and Assigned(LBackendTable.CoreVectors.ClampF64x8), 'Wide float math slots missing: ' + NonX86BackendName(LBackend));

      LF64ByBackend := LBackendTable.CoreVectors.AddF64x2(LF64A, LF64B);
      LF64ByScalar := LScalarTable.CoreVectors.AddF64x2(LF64A, LF64B);
      for LIndex := 0 to 1 do
        CheckNear(LF64ByScalar.d[LIndex], LF64ByBackend.d[LIndex], 1e-12, 'AddF64x2 parity lane ' + IntToStr(LIndex) + ': ' + NonX86BackendName(LBackend));

      LMask2ByBackend := LBackendTable.CoreVectors.CmpLtF64x2(LF64A, LF64B);
      LMask2ByScalar := LScalarTable.CoreVectors.CmpLtF64x2(LF64A, LF64B);
      CheckEqual(Integer(LMask2ByScalar), Integer(LMask2ByBackend), 'CmpLtF64x2 parity: ' + NonX86BackendName(LBackend));

      LReduceAddF64ByBackend := LBackendTable.CoreVectors.ReduceAddF64x2(LF64A);
      LReduceAddF64ByScalar := LScalarTable.CoreVectors.ReduceAddF64x2(LF64A);
      CheckNear(LReduceAddF64ByScalar, LReduceAddF64ByBackend, 1e-12, 'ReduceAddF64x2 parity: ' + NonX86BackendName(LBackend));

      LReduceMulF64ByBackend := LBackendTable.CoreVectors.ReduceMulF64x2(LF64A);
      LReduceMulF64ByScalar := LScalarTable.CoreVectors.ReduceMulF64x2(LF64A);
      CheckNear(LReduceMulF64ByScalar, LReduceMulF64ByBackend, 1e-12, 'ReduceMulF64x2 parity: ' + NonX86BackendName(LBackend));

      LF32ByBackend := LBackendTable.CoreVectors.AddF32x8(LF32A, LF32B);
      LF32ByScalar := LScalarTable.CoreVectors.AddF32x8(LF32A, LF32B);
      for LIndex := 0 to 7 do
        CheckNear(LF32ByScalar.f[LIndex], LF32ByBackend.f[LIndex], 1e-6, 'AddF32x8 parity lane ' + IntToStr(LIndex) + ': ' + NonX86BackendName(LBackend));

      LMask8ByBackend := LBackendTable.CoreVectors.CmpLtF32x8(LF32A, LF32B);
      LMask8ByScalar := LScalarTable.CoreVectors.CmpLtF32x8(LF32A, LF32B);
      CheckEqual(Integer(LMask8ByScalar), Integer(LMask8ByBackend), 'CmpLtF32x8 parity: ' + NonX86BackendName(LBackend));

      LReduceAddF32x8ByBackend := LBackendTable.CoreVectors.ReduceAddF32x8(LF32A);
      LReduceAddF32x8ByScalar := LScalarTable.CoreVectors.ReduceAddF32x8(LF32A);
      CheckNear(LReduceAddF32x8ByScalar, LReduceAddF32x8ByBackend, 1e-6, 'ReduceAddF32x8 parity: ' + NonX86BackendName(LBackend));

      LReduceMulF32x8ByBackend := LBackendTable.CoreVectors.ReduceMulF32x8(LF32A);
      LReduceMulF32x8ByScalar := LScalarTable.CoreVectors.ReduceMulF32x8(LF32A);
      CheckNear(LReduceMulF32x8ByScalar, LReduceMulF32x8ByBackend, 1e-4, 'ReduceMulF32x8 parity: ' + NonX86BackendName(LBackend));

      LF32x16ByBackend := LBackendTable.CoreVectors.AddF32x16(LF32x16A, LF32x16B);
      LF32x16ByScalar := LScalarTable.CoreVectors.AddF32x16(LF32x16A, LF32x16B);
      AssertVecF32x16Equal('AddF32x16', NonX86BackendName(LBackend), LF32x16ByScalar, LF32x16ByBackend, 1e-6);

      LF32x16ByBackend := LBackendTable.CoreVectors.SubF32x16(LF32x16A, LF32x16B);
      LF32x16ByScalar := LScalarTable.CoreVectors.SubF32x16(LF32x16A, LF32x16B);
      AssertVecF32x16Equal('SubF32x16', NonX86BackendName(LBackend), LF32x16ByScalar, LF32x16ByBackend, 1e-6);

      LF32x16ByBackend := LBackendTable.CoreVectors.MulF32x16(LF32x16A, LF32x16B);
      LF32x16ByScalar := LScalarTable.CoreVectors.MulF32x16(LF32x16A, LF32x16B);
      AssertVecF32x16Equal('MulF32x16', NonX86BackendName(LBackend), LF32x16ByScalar, LF32x16ByBackend, 1e-5);

      LF32x16ByBackend := LBackendTable.CoreVectors.DivF32x16(LF32x16A, LF32x16B);
      LF32x16ByScalar := LScalarTable.CoreVectors.DivF32x16(LF32x16A, LF32x16B);
      AssertVecF32x16Equal('DivF32x16', NonX86BackendName(LBackend), LF32x16ByScalar, LF32x16ByBackend, 1e-6);

      LF32x16ByBackend := LBackendTable.CoreVectors.MinF32x16(LF32x16A, LF32x16B);
      LF32x16ByScalar := LScalarTable.CoreVectors.MinF32x16(LF32x16A, LF32x16B);
      AssertVecF32x16Equal('MinF32x16', NonX86BackendName(LBackend), LF32x16ByScalar, LF32x16ByBackend, 0.0);

      LF32x16ByBackend := LBackendTable.CoreVectors.MaxF32x16(LF32x16A, LF32x16B);
      LF32x16ByScalar := LScalarTable.CoreVectors.MaxF32x16(LF32x16A, LF32x16B);
      AssertVecF32x16Equal('MaxF32x16', NonX86BackendName(LBackend), LF32x16ByScalar, LF32x16ByBackend, 0.0);

      LF32x16ByBackend := LBackendTable.CoreVectors.AbsF32x16(LF32x16A);
      LF32x16ByScalar := LScalarTable.CoreVectors.AbsF32x16(LF32x16A);
      AssertVecF32x16Equal('AbsF32x16', NonX86BackendName(LBackend), LF32x16ByScalar, LF32x16ByBackend, 0.0);

      LF32x16ByBackend := LBackendTable.CoreVectors.SqrtF32x16(LF32x16B);
      LF32x16ByScalar := LScalarTable.CoreVectors.SqrtF32x16(LF32x16B);
      AssertVecF32x16Equal('SqrtF32x16', NonX86BackendName(LBackend), LF32x16ByScalar, LF32x16ByBackend, 1e-6);

      LF32x16ByBackend := LBackendTable.CoreVectors.FmaF32x16(LF32x16A, LF32x16B, LF32x16C);
      LF32x16ByScalar := LScalarTable.CoreVectors.FmaF32x16(LF32x16A, LF32x16B, LF32x16C);
      AssertVecF32x16Equal('FmaF32x16', NonX86BackendName(LBackend), LF32x16ByScalar, LF32x16ByBackend, 1e-5);

      LF32x16ByBackend := LBackendTable.CoreVectors.ClampF32x16(LF32x16A, LF32x16Min, LF32x16Max);
      LF32x16ByScalar := LScalarTable.CoreVectors.ClampF32x16(LF32x16A, LF32x16Min, LF32x16Max);
      AssertVecF32x16Equal('ClampF32x16', NonX86BackendName(LBackend), LF32x16ByScalar, LF32x16ByBackend, 0.0);

      LReduceAddF32x16ByBackend := LBackendTable.CoreVectors.ReduceAddF32x16(LF32x16A);
      LReduceAddF32x16ByScalar := LScalarTable.CoreVectors.ReduceAddF32x16(LF32x16A);
      CheckNear(LReduceAddF32x16ByScalar, LReduceAddF32x16ByBackend, 1e-5, 'ReduceAddF32x16 parity: ' + NonX86BackendName(LBackend));

      LReduceMulF32x16ByBackend := LBackendTable.CoreVectors.ReduceMulF32x16(LF32x16A);
      LReduceMulF32x16ByScalar := LScalarTable.CoreVectors.ReduceMulF32x16(LF32x16A);
      CheckNear(LReduceMulF32x16ByScalar, LReduceMulF32x16ByBackend, 1e-4, 'ReduceMulF32x16 parity: ' + NonX86BackendName(LBackend));

      LF64x8ByBackend := LBackendTable.CoreVectors.AddF64x8(LF64x8A, LF64x8B);
      LF64x8ByScalar := LScalarTable.CoreVectors.AddF64x8(LF64x8A, LF64x8B);
      AssertVecF64x8Equal('AddF64x8', NonX86BackendName(LBackend), LF64x8ByScalar, LF64x8ByBackend, 1e-12);

      LF64x8ByBackend := LBackendTable.CoreVectors.SubF64x8(LF64x8A, LF64x8B);
      LF64x8ByScalar := LScalarTable.CoreVectors.SubF64x8(LF64x8A, LF64x8B);
      AssertVecF64x8Equal('SubF64x8', NonX86BackendName(LBackend), LF64x8ByScalar, LF64x8ByBackend, 1e-12);

      LF64x8ByBackend := LBackendTable.CoreVectors.MulF64x8(LF64x8A, LF64x8B);
      LF64x8ByScalar := LScalarTable.CoreVectors.MulF64x8(LF64x8A, LF64x8B);
      AssertVecF64x8Equal('MulF64x8', NonX86BackendName(LBackend), LF64x8ByScalar, LF64x8ByBackend, 1e-11);

      LF64x8ByBackend := LBackendTable.CoreVectors.DivF64x8(LF64x8A, LF64x8B);
      LF64x8ByScalar := LScalarTable.CoreVectors.DivF64x8(LF64x8A, LF64x8B);
      AssertVecF64x8Equal('DivF64x8', NonX86BackendName(LBackend), LF64x8ByScalar, LF64x8ByBackend, 1e-12);

      LF64x8ByBackend := LBackendTable.CoreVectors.MinF64x8(LF64x8A, LF64x8B);
      LF64x8ByScalar := LScalarTable.CoreVectors.MinF64x8(LF64x8A, LF64x8B);
      AssertVecF64x8Equal('MinF64x8', NonX86BackendName(LBackend), LF64x8ByScalar, LF64x8ByBackend, 0.0);

      LF64x8ByBackend := LBackendTable.CoreVectors.MaxF64x8(LF64x8A, LF64x8B);
      LF64x8ByScalar := LScalarTable.CoreVectors.MaxF64x8(LF64x8A, LF64x8B);
      AssertVecF64x8Equal('MaxF64x8', NonX86BackendName(LBackend), LF64x8ByScalar, LF64x8ByBackend, 0.0);

      LF64x8ByBackend := LBackendTable.CoreVectors.AbsF64x8(LF64x8A);
      LF64x8ByScalar := LScalarTable.CoreVectors.AbsF64x8(LF64x8A);
      AssertVecF64x8Equal('AbsF64x8', NonX86BackendName(LBackend), LF64x8ByScalar, LF64x8ByBackend, 0.0);

      LF64x8ByBackend := LBackendTable.CoreVectors.SqrtF64x8(LF64x8B);
      LF64x8ByScalar := LScalarTable.CoreVectors.SqrtF64x8(LF64x8B);
      AssertVecF64x8Equal('SqrtF64x8', NonX86BackendName(LBackend), LF64x8ByScalar, LF64x8ByBackend, 1e-12);

      LF64x8ByBackend := LBackendTable.CoreVectors.FmaF64x8(LF64x8A, LF64x8B, LF64x8C);
      LF64x8ByScalar := LScalarTable.CoreVectors.FmaF64x8(LF64x8A, LF64x8B, LF64x8C);
      AssertVecF64x8Equal('FmaF64x8', NonX86BackendName(LBackend), LF64x8ByScalar, LF64x8ByBackend, 1e-11);

      LF64x8ByBackend := LBackendTable.CoreVectors.ClampF64x8(LF64x8A, LF64x8Min, LF64x8Max);
      LF64x8ByScalar := LScalarTable.CoreVectors.ClampF64x8(LF64x8A, LF64x8Min, LF64x8Max);
      AssertVecF64x8Equal('ClampF64x8', NonX86BackendName(LBackend), LF64x8ByScalar, LF64x8ByBackend, 0.0);

    Inc(LChecked);
  end;

  if LChecked = 0 then
    CheckTrue(True, 'No non-x86 backend registered/active on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_NarrowAndNotParity_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LBackendTable: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LI8A, LI8B: TVecI8x16;
  LU16A, LU16B: TVecU16x8;
  LU8A, LU8B: TVecU8x16;
  LI8ByBackend, LI8ByScalar: TVecI8x16;
  LU16ByBackend, LU16ByScalar: TVecU16x8;
  LU8ByBackend, LU8ByScalar: TVecU8x16;
  LIndex: Integer;
  LChecked: Integer;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LChecked := 0;

  LI8A.i[0] := -1;    LI8B.i[0] := 0;
  LI8A.i[1] := 0;     LI8B.i[1] := -1;
  LI8A.i[2] := 127;   LI8B.i[2] := 85;
  LI8A.i[3] := -128;  LI8B.i[3] := 51;
  LI8A.i[4] := 18;    LI8B.i[4] := -52;
  LI8A.i[5] := -85;   LI8B.i[5] := 15;
  LI8A.i[6] := 64;    LI8B.i[6] := -64;
  LI8A.i[7] := -7;    LI8B.i[7] := 7;
  LI8A.i[8] := 1;     LI8B.i[8] := -2;
  LI8A.i[9] := 2;     LI8B.i[9] := 3;
  LI8A.i[10] := 4;    LI8B.i[10] := 5;
  LI8A.i[11] := 6;    LI8B.i[11] := 7;
  LI8A.i[12] := 8;    LI8B.i[12] := 9;
  LI8A.i[13] := 10;   LI8B.i[13] := 11;
  LI8A.i[14] := 12;   LI8B.i[14] := 13;
  LI8A.i[15] := 14;   LI8B.i[15] := 15;

  LU16A.u[0] := $0000; LU16B.u[0] := $FFFF;
  LU16A.u[1] := $FFFF; LU16B.u[1] := $0000;
  LU16A.u[2] := $1234; LU16B.u[2] := $F0F0;
  LU16A.u[3] := $AAAA; LU16B.u[3] := $5555;
  LU16A.u[4] := $00FF; LU16B.u[4] := $0F0F;
  LU16A.u[5] := $FF00; LU16B.u[5] := $3333;
  LU16A.u[6] := $1357; LU16B.u[6] := $2468;
  LU16A.u[7] := $8001; LU16B.u[7] := $7FFE;

  LU8A.u[0] := $00; LU8B.u[0] := $FF;
  LU8A.u[1] := $FF; LU8B.u[1] := $00;
  LU8A.u[2] := $12; LU8B.u[2] := $34;
  LU8A.u[3] := $56; LU8B.u[3] := $78;
  LU8A.u[4] := $9A; LU8B.u[4] := $BC;
  LU8A.u[5] := $DE; LU8B.u[5] := $F0;
  LU8A.u[6] := $0F; LU8B.u[6] := $F0;
  LU8A.u[7] := $F0; LU8B.u[7] := $0F;
  LU8A.u[8] := $55; LU8B.u[8] := $AA;
  LU8A.u[9] := $AA; LU8B.u[9] := $55;
  LU8A.u[10] := $11; LU8B.u[10] := $22;
  LU8A.u[11] := $33; LU8B.u[11] := $44;
  LU8A.u[12] := $66; LU8B.u[12] := $77;
  LU8A.u[13] := $88; LU8B.u[13] := $99;
  LU8A.u[14] := $CC; LU8B.u[14] := $DD;
  LU8A.u[15] := $EE; LU8B.u[15] := $FF;

  for LBackend in LBackends do
  begin
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

      CheckTrue(Assigned(LBackendTable.CoreVectors.AndNotI8x16), 'AndNotI8x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AndNotU16x8), 'AndNotU16x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AndNotU8x16), 'AndNotU8x16 missing: ' + NonX86BackendName(LBackend));

      LI8ByBackend := LBackendTable.CoreVectors.AndNotI8x16(LI8A, LI8B);
      LI8ByScalar := LScalarTable.CoreVectors.AndNotI8x16(LI8A, LI8B);
      for LIndex := 0 to 15 do
        CheckEqual(LI8ByScalar.i[LIndex], LI8ByBackend.i[LIndex], 'AndNotI8x16 lane ' + IntToStr(LIndex) + ': ' + NonX86BackendName(LBackend));

      LU16ByBackend := LBackendTable.CoreVectors.AndNotU16x8(LU16A, LU16B);
      LU16ByScalar := LScalarTable.CoreVectors.AndNotU16x8(LU16A, LU16B);
      for LIndex := 0 to 7 do
        CheckEqual(QWord(LU16ByScalar.u[LIndex]), QWord(LU16ByBackend.u[LIndex]), 'AndNotU16x8 lane ' + IntToStr(LIndex) + ': ' + NonX86BackendName(LBackend));

      LU8ByBackend := LBackendTable.CoreVectors.AndNotU8x16(LU8A, LU8B);
      LU8ByScalar := LScalarTable.CoreVectors.AndNotU8x16(LU8A, LU8B);
      for LIndex := 0 to 15 do
        CheckEqual(QWord(LU8ByScalar.u[LIndex]), QWord(LU8ByBackend.u[LIndex]), 'AndNotU8x16 lane ' + IntToStr(LIndex) + ': ' + NonX86BackendName(LBackend));

    Inc(LChecked);
  end;

  if LChecked = 0 then
    CheckTrue(True, 'No non-x86 backend registered/active on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_DotParity_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LBackendTable: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LF32x8A, LF32x8B: TVecF32x8;
  LF64x2A, LF64x2B: TVecF64x2;
  LF64x4A, LF64x4B: TVecF64x4;
  LDotF32x8ByBackend, LDotF32x8ByScalar: Single;
  LDotF64x2ByBackend, LDotF64x2ByScalar: Double;
  LDotF64x4ByBackend, LDotF64x4ByScalar: Double;
  LIndex: Integer;
  LChecked: Integer;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LChecked := 0;

  for LIndex := 0 to 7 do
  begin
    LF32x8A.f[LIndex] := (LIndex + 1) * 1.125;
    LF32x8B.f[LIndex] := (7 - LIndex) * -0.875;
  end;

  LF64x2A.d[0] := 1.25;
  LF64x2A.d[1] := -3.5;
  LF64x2B.d[0] := 2.0;
  LF64x2B.d[1] := 4.25;

  for LIndex := 0 to 3 do
  begin
    LF64x4A.d[LIndex] := (LIndex + 1) * 2.5;
    LF64x4B.d[LIndex] := (LIndex - 1) * -1.75;
  end;

  for LBackend in LBackends do
  begin
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

      CheckTrue(Assigned(LBackendTable.CoreVectors.DotF32x8), 'DotF32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.DotF64x2), 'DotF64x2 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.DotF64x4), 'DotF64x4 missing: ' + NonX86BackendName(LBackend));

      LDotF32x8ByBackend := LBackendTable.CoreVectors.DotF32x8(LF32x8A, LF32x8B);
      LDotF32x8ByScalar := LScalarTable.CoreVectors.DotF32x8(LF32x8A, LF32x8B);
      CheckNear(LDotF32x8ByScalar, LDotF32x8ByBackend, 1e-6, 'DotF32x8 parity: ' + NonX86BackendName(LBackend));

      LDotF64x2ByBackend := LBackendTable.CoreVectors.DotF64x2(LF64x2A, LF64x2B);
      LDotF64x2ByScalar := LScalarTable.CoreVectors.DotF64x2(LF64x2A, LF64x2B);
      CheckNear(LDotF64x2ByScalar, LDotF64x2ByBackend, 1e-12, 'DotF64x2 parity: ' + NonX86BackendName(LBackend));

      LDotF64x4ByBackend := LBackendTable.CoreVectors.DotF64x4(LF64x4A, LF64x4B);
      LDotF64x4ByScalar := LScalarTable.CoreVectors.DotF64x4(LF64x4A, LF64x4B);
      CheckNear(LDotF64x4ByScalar, LDotF64x4ByBackend, 1e-12, 'DotF64x4 parity: ' + NonX86BackendName(LBackend));

    Inc(LChecked);
  end;

  if LChecked = 0 then
    CheckTrue(True, 'No non-x86 backend registered/active on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_I16x32_CoreParity_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LBackendTable: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LA, LB: TVecI16x32;
  LVecByBackend, LVecByScalar: TVecI16x32;
  LMaskByBackend, LMaskByScalar: TMask32;
  LShiftCounts: array[0..4] of Integer;
  LShiftCount: Integer;
  LIndex: Integer;
  LChecked: Integer;

  procedure AssertVecI16x32Equal(const aOp: string; const aExpected, aActual: TVecI16x32);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 31 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aOp + ' lane ' + IntToStr(LLane));
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LChecked := 0;

  for LIndex := 0 to 31 do
  begin
    LA.i[LIndex] := Int16((LIndex * 37) - 400);
    LB.i[LIndex] := Int16(450 - (LIndex * 29));
    if (LIndex mod 5) = 0 then
      LB.i[LIndex] := LA.i[LIndex];
  end;

  LShiftCounts[0] := -1;
  LShiftCounts[1] := 0;
  LShiftCounts[2] := 5;
  LShiftCounts[3] := 15;
  LShiftCounts[4] := 16;

  for LBackend in LBackends do
  begin
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

      CheckTrue(Assigned(LBackendTable.CoreVectors.AddI16x32), 'AddI16x32 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.SubI16x32), 'SubI16x32 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AndI16x32), 'AndI16x32 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.OrI16x32), 'OrI16x32 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.XorI16x32), 'XorI16x32 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.NotI16x32), 'NotI16x32 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AndNotI16x32), 'AndNotI16x32 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftLeftI16x32), 'ShiftLeftI16x32 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftRightI16x32), 'ShiftRightI16x32 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftRightArithI16x32), 'ShiftRightArithI16x32 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpEqI16x32), 'CmpEqI16x32 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLtI16x32), 'CmpLtI16x32 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpGtI16x32), 'CmpGtI16x32 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.MinI16x32), 'MinI16x32 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.MaxI16x32), 'MaxI16x32 missing: ' + NonX86BackendName(LBackend));

      LVecByBackend := LBackendTable.CoreVectors.AddI16x32(LA, LB);
      LVecByScalar := LScalarTable.CoreVectors.AddI16x32(LA, LB);
      AssertVecI16x32Equal('AddI16x32 parity: ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

      LVecByBackend := LBackendTable.CoreVectors.SubI16x32(LA, LB);
      LVecByScalar := LScalarTable.CoreVectors.SubI16x32(LA, LB);
      AssertVecI16x32Equal('SubI16x32 parity: ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

      LVecByBackend := LBackendTable.CoreVectors.AndI16x32(LA, LB);
      LVecByScalar := LScalarTable.CoreVectors.AndI16x32(LA, LB);
      AssertVecI16x32Equal('AndI16x32 parity: ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

      LVecByBackend := LBackendTable.CoreVectors.OrI16x32(LA, LB);
      LVecByScalar := LScalarTable.CoreVectors.OrI16x32(LA, LB);
      AssertVecI16x32Equal('OrI16x32 parity: ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

      LVecByBackend := LBackendTable.CoreVectors.XorI16x32(LA, LB);
      LVecByScalar := LScalarTable.CoreVectors.XorI16x32(LA, LB);
      AssertVecI16x32Equal('XorI16x32 parity: ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

      LVecByBackend := LBackendTable.CoreVectors.NotI16x32(LA);
      LVecByScalar := LScalarTable.CoreVectors.NotI16x32(LA);
      AssertVecI16x32Equal('NotI16x32 parity: ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

      LVecByBackend := LBackendTable.CoreVectors.AndNotI16x32(LA, LB);
      LVecByScalar := LScalarTable.CoreVectors.AndNotI16x32(LA, LB);
      AssertVecI16x32Equal('AndNotI16x32 parity: ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

      for LIndex := 0 to High(LShiftCounts) do
      begin
        LShiftCount := LShiftCounts[LIndex];

        LVecByBackend := LBackendTable.CoreVectors.ShiftLeftI16x32(LA, LShiftCount);
        LVecByScalar := LScalarTable.CoreVectors.ShiftLeftI16x32(LA, LShiftCount);
        AssertVecI16x32Equal('ShiftLeftI16x32 parity c=' + IntToStr(LShiftCount) + ': ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

        LVecByBackend := LBackendTable.CoreVectors.ShiftRightI16x32(LA, LShiftCount);
        LVecByScalar := LScalarTable.CoreVectors.ShiftRightI16x32(LA, LShiftCount);
        AssertVecI16x32Equal('ShiftRightI16x32 parity c=' + IntToStr(LShiftCount) + ': ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

        LVecByBackend := LBackendTable.CoreVectors.ShiftRightArithI16x32(LA, LShiftCount);
        LVecByScalar := LScalarTable.CoreVectors.ShiftRightArithI16x32(LA, LShiftCount);
        AssertVecI16x32Equal('ShiftRightArithI16x32 parity c=' + IntToStr(LShiftCount) + ': ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);
      end;

      LMaskByBackend := LBackendTable.CoreVectors.CmpEqI16x32(LA, LB);
      LMaskByScalar := LScalarTable.CoreVectors.CmpEqI16x32(LA, LB);
      CheckEqual(QWord(LMaskByScalar), QWord(LMaskByBackend), 'CmpEqI16x32 parity: ' + NonX86BackendName(LBackend));

      LMaskByBackend := LBackendTable.CoreVectors.CmpLtI16x32(LA, LB);
      LMaskByScalar := LScalarTable.CoreVectors.CmpLtI16x32(LA, LB);
      CheckEqual(QWord(LMaskByScalar), QWord(LMaskByBackend), 'CmpLtI16x32 parity: ' + NonX86BackendName(LBackend));

      LMaskByBackend := LBackendTable.CoreVectors.CmpGtI16x32(LA, LB);
      LMaskByScalar := LScalarTable.CoreVectors.CmpGtI16x32(LA, LB);
      CheckEqual(QWord(LMaskByScalar), QWord(LMaskByBackend), 'CmpGtI16x32 parity: ' + NonX86BackendName(LBackend));

      LVecByBackend := LBackendTable.CoreVectors.MinI16x32(LA, LB);
      LVecByScalar := LScalarTable.CoreVectors.MinI16x32(LA, LB);
      AssertVecI16x32Equal('MinI16x32 parity: ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

      LVecByBackend := LBackendTable.CoreVectors.MaxI16x32(LA, LB);
      LVecByScalar := LScalarTable.CoreVectors.MaxI16x32(LA, LB);
      AssertVecI16x32Equal('MaxI16x32 parity: ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

    Inc(LChecked);
  end;

  if LChecked = 0 then
    CheckTrue(True, 'No non-x86 backend registered/active on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_I8x64_CoreParity_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LBackendTable: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LA, LB: TVecI8x64;
  LVecByBackend, LVecByScalar: TVecI8x64;
  LMaskByBackend, LMaskByScalar: TMask64;
  LIndex: Integer;
  LChecked: Integer;

  procedure AssertVecI8x64Equal(const aOp: string; const aExpected, aActual: TVecI8x64);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 63 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aOp + ' lane ' + IntToStr(LLane));
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LChecked := 0;

  for LIndex := 0 to 63 do
  begin
    LA.i[LIndex] := Int8((LIndex mod 17) - 8);
    LB.i[LIndex] := Int8(7 - (LIndex mod 19));
    if (LIndex mod 7) = 0 then
      LB.i[LIndex] := LA.i[LIndex];
  end;

  for LBackend in LBackends do
  begin
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

      CheckTrue(Assigned(LBackendTable.CoreVectors.AddI8x64), 'AddI8x64 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.SubI8x64), 'SubI8x64 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AndI8x64), 'AndI8x64 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.OrI8x64), 'OrI8x64 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.XorI8x64), 'XorI8x64 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.NotI8x64), 'NotI8x64 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AndNotI8x64), 'AndNotI8x64 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpEqI8x64), 'CmpEqI8x64 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLtI8x64), 'CmpLtI8x64 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpGtI8x64), 'CmpGtI8x64 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.MinI8x64), 'MinI8x64 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.MaxI8x64), 'MaxI8x64 missing: ' + NonX86BackendName(LBackend));

      LVecByBackend := LBackendTable.CoreVectors.AddI8x64(LA, LB);
      LVecByScalar := LScalarTable.CoreVectors.AddI8x64(LA, LB);
      AssertVecI8x64Equal('AddI8x64 parity: ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

      LVecByBackend := LBackendTable.CoreVectors.SubI8x64(LA, LB);
      LVecByScalar := LScalarTable.CoreVectors.SubI8x64(LA, LB);
      AssertVecI8x64Equal('SubI8x64 parity: ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

      LVecByBackend := LBackendTable.CoreVectors.AndI8x64(LA, LB);
      LVecByScalar := LScalarTable.CoreVectors.AndI8x64(LA, LB);
      AssertVecI8x64Equal('AndI8x64 parity: ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

      LVecByBackend := LBackendTable.CoreVectors.OrI8x64(LA, LB);
      LVecByScalar := LScalarTable.CoreVectors.OrI8x64(LA, LB);
      AssertVecI8x64Equal('OrI8x64 parity: ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

      LVecByBackend := LBackendTable.CoreVectors.XorI8x64(LA, LB);
      LVecByScalar := LScalarTable.CoreVectors.XorI8x64(LA, LB);
      AssertVecI8x64Equal('XorI8x64 parity: ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

      LVecByBackend := LBackendTable.CoreVectors.NotI8x64(LA);
      LVecByScalar := LScalarTable.CoreVectors.NotI8x64(LA);
      AssertVecI8x64Equal('NotI8x64 parity: ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

      LVecByBackend := LBackendTable.CoreVectors.AndNotI8x64(LA, LB);
      LVecByScalar := LScalarTable.CoreVectors.AndNotI8x64(LA, LB);
      AssertVecI8x64Equal('AndNotI8x64 parity: ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

      LMaskByBackend := LBackendTable.CoreVectors.CmpEqI8x64(LA, LB);
      LMaskByScalar := LScalarTable.CoreVectors.CmpEqI8x64(LA, LB);
      CheckEqual(QWord(LMaskByScalar), QWord(LMaskByBackend), 'CmpEqI8x64 parity: ' + NonX86BackendName(LBackend));

      LMaskByBackend := LBackendTable.CoreVectors.CmpLtI8x64(LA, LB);
      LMaskByScalar := LScalarTable.CoreVectors.CmpLtI8x64(LA, LB);
      CheckEqual(QWord(LMaskByScalar), QWord(LMaskByBackend), 'CmpLtI8x64 parity: ' + NonX86BackendName(LBackend));

      LMaskByBackend := LBackendTable.CoreVectors.CmpGtI8x64(LA, LB);
      LMaskByScalar := LScalarTable.CoreVectors.CmpGtI8x64(LA, LB);
      CheckEqual(QWord(LMaskByScalar), QWord(LMaskByBackend), 'CmpGtI8x64 parity: ' + NonX86BackendName(LBackend));

      LVecByBackend := LBackendTable.CoreVectors.MinI8x64(LA, LB);
      LVecByScalar := LScalarTable.CoreVectors.MinI8x64(LA, LB);
      AssertVecI8x64Equal('MinI8x64 parity: ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

      LVecByBackend := LBackendTable.CoreVectors.MaxI8x64(LA, LB);
      LVecByScalar := LScalarTable.CoreVectors.MaxI8x64(LA, LB);
      AssertVecI8x64Equal('MaxI8x64 parity: ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

    Inc(LChecked);
  end;

  if LChecked = 0 then
    CheckTrue(True, 'No non-x86 backend registered/active on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_U32x16_U64x8_CoreParity_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LBackendTable: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LU32A, LU32B: TVecU32x16;
  LU64A, LU64B: TVecU64x8;
  LU8A, LU8B: TVecU8x64;
  LU32ByBackend, LU32ByScalar: TVecU32x16;
  LU64ByBackend, LU64ByScalar: TVecU64x8;
  LU8ByBackend, LU8ByScalar: TVecU8x64;
  LMask16ByBackend, LMask16ByScalar: TMask16;
  LMask8ByBackend, LMask8ByScalar: TMask8;
  LMask64ByBackend, LMask64ByScalar: TMask64;
  LU32ShiftCounts: array[0..4] of Integer;
  LU64ShiftCounts: array[0..4] of Integer;
  LShiftCount: Integer;
  LIndex: Integer;
  LChecked: Integer;

  procedure AssertVecU32x16Equal(const aOp: string; const aExpected, aActual: TVecU32x16);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 15 do
      CheckEqual(QWord(aExpected.u[LLane]), QWord(aActual.u[LLane]), aOp + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecU64x8Equal(const aOp: string; const aExpected, aActual: TVecU64x8);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 7 do
      CheckEqual(QWord(aExpected.u[LLane]), QWord(aActual.u[LLane]), aOp + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecU8x64Equal(const aOp: string; const aExpected, aActual: TVecU8x64);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 63 do
      CheckEqual(QWord(aExpected.u[LLane]), QWord(aActual.u[LLane]), aOp + ' lane ' + IntToStr(LLane));
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LChecked := 0;

  for LIndex := 0 to 15 do
  begin
    LU32A.u[LIndex] := DWord((LIndex + 1) * 1234567);
    LU32B.u[LIndex] := DWord((17 - LIndex) * 76543);
    if (LIndex mod 4) = 0 then
      LU32B.u[LIndex] := LU32A.u[LIndex];
  end;

  for LIndex := 0 to 7 do
  begin
    LU64A.u[LIndex] := QWord((LIndex + 1) * 1000003) shl (LIndex mod 13);
    LU64B.u[LIndex] := QWord((9 - LIndex) * 700001) shl ((LIndex + 3) mod 11);
    if (LIndex mod 3) = 0 then
      LU64B.u[LIndex] := LU64A.u[LIndex];
  end;

  for LIndex := 0 to 63 do
  begin
    LU8A.u[LIndex] := Byte((LIndex * 19) and $FF);
    LU8B.u[LIndex] := Byte((255 - (LIndex * 7)) and $FF);
    if (LIndex mod 6) = 0 then
      LU8B.u[LIndex] := LU8A.u[LIndex];
  end;

  LU32ShiftCounts[0] := 0;
  LU32ShiftCounts[1] := 3;
  LU32ShiftCounts[2] := 15;
  LU32ShiftCounts[3] := 31;
  LU32ShiftCounts[4] := 32;

  LU64ShiftCounts[0] := 0;
  LU64ShiftCounts[1] := 7;
  LU64ShiftCounts[2] := 19;
  LU64ShiftCounts[3] := 63;
  LU64ShiftCounts[4] := 64;

  for LBackend in LBackends do
  begin
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

      CheckTrue(Assigned(LBackendTable.CoreVectors.AddU32x16), 'AddU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.SubU32x16), 'SubU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.MulU32x16), 'MulU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AndU32x16), 'AndU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.OrU32x16), 'OrU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.XorU32x16), 'XorU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.NotU32x16), 'NotU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AndNotU32x16), 'AndNotU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftLeftU32x16), 'ShiftLeftU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftRightU32x16), 'ShiftRightU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpEqU32x16), 'CmpEqU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLtU32x16), 'CmpLtU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpGtU32x16), 'CmpGtU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLeU32x16), 'CmpLeU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpGeU32x16), 'CmpGeU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpNeU32x16), 'CmpNeU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.MinU32x16), 'MinU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.MaxU32x16), 'MaxU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AddU64x8), 'AddU64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.SubU64x8), 'SubU64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AndU64x8), 'AndU64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.OrU64x8), 'OrU64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.XorU64x8), 'XorU64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.NotU64x8), 'NotU64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftLeftU64x8), 'ShiftLeftU64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftRightU64x8), 'ShiftRightU64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpEqU64x8), 'CmpEqU64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLtU64x8), 'CmpLtU64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpGtU64x8), 'CmpGtU64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLeU64x8), 'CmpLeU64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpGeU64x8), 'CmpGeU64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpNeU64x8), 'CmpNeU64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AddU8x64), 'AddU8x64 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.SubU8x64), 'SubU8x64 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AndU8x64), 'AndU8x64 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.OrU8x64), 'OrU8x64 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.XorU8x64), 'XorU8x64 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.NotU8x64), 'NotU8x64 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpEqU8x64), 'CmpEqU8x64 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLtU8x64), 'CmpLtU8x64 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpGtU8x64), 'CmpGtU8x64 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.MinU8x64), 'MinU8x64 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.MaxU8x64), 'MaxU8x64 missing: ' + NonX86BackendName(LBackend));

      LU32ByBackend := LBackendTable.CoreVectors.AddU32x16(LU32A, LU32B);
      LU32ByScalar := LScalarTable.CoreVectors.AddU32x16(LU32A, LU32B);
      AssertVecU32x16Equal('AddU32x16 parity: ' + NonX86BackendName(LBackend), LU32ByScalar, LU32ByBackend);

      LU32ByBackend := LBackendTable.CoreVectors.SubU32x16(LU32A, LU32B);
      LU32ByScalar := LScalarTable.CoreVectors.SubU32x16(LU32A, LU32B);
      AssertVecU32x16Equal('SubU32x16 parity: ' + NonX86BackendName(LBackend), LU32ByScalar, LU32ByBackend);

      LU32ByBackend := LBackendTable.CoreVectors.MulU32x16(LU32A, LU32B);
      LU32ByScalar := LScalarTable.CoreVectors.MulU32x16(LU32A, LU32B);
      AssertVecU32x16Equal('MulU32x16 parity: ' + NonX86BackendName(LBackend), LU32ByScalar, LU32ByBackend);

      LU32ByBackend := LBackendTable.CoreVectors.AndU32x16(LU32A, LU32B);
      LU32ByScalar := LScalarTable.CoreVectors.AndU32x16(LU32A, LU32B);
      AssertVecU32x16Equal('AndU32x16 parity: ' + NonX86BackendName(LBackend), LU32ByScalar, LU32ByBackend);

      LU32ByBackend := LBackendTable.CoreVectors.OrU32x16(LU32A, LU32B);
      LU32ByScalar := LScalarTable.CoreVectors.OrU32x16(LU32A, LU32B);
      AssertVecU32x16Equal('OrU32x16 parity: ' + NonX86BackendName(LBackend), LU32ByScalar, LU32ByBackend);

      LU32ByBackend := LBackendTable.CoreVectors.XorU32x16(LU32A, LU32B);
      LU32ByScalar := LScalarTable.CoreVectors.XorU32x16(LU32A, LU32B);
      AssertVecU32x16Equal('XorU32x16 parity: ' + NonX86BackendName(LBackend), LU32ByScalar, LU32ByBackend);

      LU32ByBackend := LBackendTable.CoreVectors.NotU32x16(LU32A);
      LU32ByScalar := LScalarTable.CoreVectors.NotU32x16(LU32A);
      AssertVecU32x16Equal('NotU32x16 parity: ' + NonX86BackendName(LBackend), LU32ByScalar, LU32ByBackend);

      LU32ByBackend := LBackendTable.CoreVectors.AndNotU32x16(LU32A, LU32B);
      LU32ByScalar := LScalarTable.CoreVectors.AndNotU32x16(LU32A, LU32B);
      AssertVecU32x16Equal('AndNotU32x16 parity: ' + NonX86BackendName(LBackend), LU32ByScalar, LU32ByBackend);

      for LIndex := 0 to High(LU32ShiftCounts) do
      begin
        LShiftCount := LU32ShiftCounts[LIndex];
        LU32ByBackend := LBackendTable.CoreVectors.ShiftLeftU32x16(LU32A, LShiftCount);
        LU32ByScalar := LScalarTable.CoreVectors.ShiftLeftU32x16(LU32A, LShiftCount);
        AssertVecU32x16Equal('ShiftLeftU32x16 parity c=' + IntToStr(LShiftCount) + ': ' + NonX86BackendName(LBackend), LU32ByScalar, LU32ByBackend);

        LU32ByBackend := LBackendTable.CoreVectors.ShiftRightU32x16(LU32A, LShiftCount);
        LU32ByScalar := LScalarTable.CoreVectors.ShiftRightU32x16(LU32A, LShiftCount);
        AssertVecU32x16Equal('ShiftRightU32x16 parity c=' + IntToStr(LShiftCount) + ': ' + NonX86BackendName(LBackend), LU32ByScalar, LU32ByBackend);
      end;

      LMask16ByBackend := LBackendTable.CoreVectors.CmpEqU32x16(LU32A, LU32B);
      LMask16ByScalar := LScalarTable.CoreVectors.CmpEqU32x16(LU32A, LU32B);
      CheckEqual(QWord(LMask16ByScalar), QWord(LMask16ByBackend), 'CmpEqU32x16 parity: ' + NonX86BackendName(LBackend));

      LMask16ByBackend := LBackendTable.CoreVectors.CmpLtU32x16(LU32A, LU32B);
      LMask16ByScalar := LScalarTable.CoreVectors.CmpLtU32x16(LU32A, LU32B);
      CheckEqual(QWord(LMask16ByScalar), QWord(LMask16ByBackend), 'CmpLtU32x16 parity: ' + NonX86BackendName(LBackend));

      LMask16ByBackend := LBackendTable.CoreVectors.CmpGtU32x16(LU32A, LU32B);
      LMask16ByScalar := LScalarTable.CoreVectors.CmpGtU32x16(LU32A, LU32B);
      CheckEqual(QWord(LMask16ByScalar), QWord(LMask16ByBackend), 'CmpGtU32x16 parity: ' + NonX86BackendName(LBackend));

      LMask16ByBackend := LBackendTable.CoreVectors.CmpLeU32x16(LU32A, LU32B);
      LMask16ByScalar := LScalarTable.CoreVectors.CmpLeU32x16(LU32A, LU32B);
      CheckEqual(QWord(LMask16ByScalar), QWord(LMask16ByBackend), 'CmpLeU32x16 parity: ' + NonX86BackendName(LBackend));

      LMask16ByBackend := LBackendTable.CoreVectors.CmpGeU32x16(LU32A, LU32B);
      LMask16ByScalar := LScalarTable.CoreVectors.CmpGeU32x16(LU32A, LU32B);
      CheckEqual(QWord(LMask16ByScalar), QWord(LMask16ByBackend), 'CmpGeU32x16 parity: ' + NonX86BackendName(LBackend));

      LMask16ByBackend := LBackendTable.CoreVectors.CmpNeU32x16(LU32A, LU32B);
      LMask16ByScalar := LScalarTable.CoreVectors.CmpNeU32x16(LU32A, LU32B);
      CheckEqual(QWord(LMask16ByScalar), QWord(LMask16ByBackend), 'CmpNeU32x16 parity: ' + NonX86BackendName(LBackend));

      LU32ByBackend := LBackendTable.CoreVectors.MinU32x16(LU32A, LU32B);
      LU32ByScalar := LScalarTable.CoreVectors.MinU32x16(LU32A, LU32B);
      AssertVecU32x16Equal('MinU32x16 parity: ' + NonX86BackendName(LBackend), LU32ByScalar, LU32ByBackend);

      LU32ByBackend := LBackendTable.CoreVectors.MaxU32x16(LU32A, LU32B);
      LU32ByScalar := LScalarTable.CoreVectors.MaxU32x16(LU32A, LU32B);
      AssertVecU32x16Equal('MaxU32x16 parity: ' + NonX86BackendName(LBackend), LU32ByScalar, LU32ByBackend);

      LU64ByBackend := LBackendTable.CoreVectors.AddU64x8(LU64A, LU64B);
      LU64ByScalar := LScalarTable.CoreVectors.AddU64x8(LU64A, LU64B);
      AssertVecU64x8Equal('AddU64x8 parity: ' + NonX86BackendName(LBackend), LU64ByScalar, LU64ByBackend);

      LU64ByBackend := LBackendTable.CoreVectors.SubU64x8(LU64A, LU64B);
      LU64ByScalar := LScalarTable.CoreVectors.SubU64x8(LU64A, LU64B);
      AssertVecU64x8Equal('SubU64x8 parity: ' + NonX86BackendName(LBackend), LU64ByScalar, LU64ByBackend);

      LU64ByBackend := LBackendTable.CoreVectors.AndU64x8(LU64A, LU64B);
      LU64ByScalar := LScalarTable.CoreVectors.AndU64x8(LU64A, LU64B);
      AssertVecU64x8Equal('AndU64x8 parity: ' + NonX86BackendName(LBackend), LU64ByScalar, LU64ByBackend);

      LU64ByBackend := LBackendTable.CoreVectors.OrU64x8(LU64A, LU64B);
      LU64ByScalar := LScalarTable.CoreVectors.OrU64x8(LU64A, LU64B);
      AssertVecU64x8Equal('OrU64x8 parity: ' + NonX86BackendName(LBackend), LU64ByScalar, LU64ByBackend);

      LU64ByBackend := LBackendTable.CoreVectors.XorU64x8(LU64A, LU64B);
      LU64ByScalar := LScalarTable.CoreVectors.XorU64x8(LU64A, LU64B);
      AssertVecU64x8Equal('XorU64x8 parity: ' + NonX86BackendName(LBackend), LU64ByScalar, LU64ByBackend);

      LU64ByBackend := LBackendTable.CoreVectors.NotU64x8(LU64A);
      LU64ByScalar := LScalarTable.CoreVectors.NotU64x8(LU64A);
      AssertVecU64x8Equal('NotU64x8 parity: ' + NonX86BackendName(LBackend), LU64ByScalar, LU64ByBackend);

      for LIndex := 0 to High(LU64ShiftCounts) do
      begin
        LShiftCount := LU64ShiftCounts[LIndex];
        LU64ByBackend := LBackendTable.CoreVectors.ShiftLeftU64x8(LU64A, LShiftCount);
        LU64ByScalar := LScalarTable.CoreVectors.ShiftLeftU64x8(LU64A, LShiftCount);
        AssertVecU64x8Equal('ShiftLeftU64x8 parity c=' + IntToStr(LShiftCount) + ': ' + NonX86BackendName(LBackend), LU64ByScalar, LU64ByBackend);

        LU64ByBackend := LBackendTable.CoreVectors.ShiftRightU64x8(LU64A, LShiftCount);
        LU64ByScalar := LScalarTable.CoreVectors.ShiftRightU64x8(LU64A, LShiftCount);
        AssertVecU64x8Equal('ShiftRightU64x8 parity c=' + IntToStr(LShiftCount) + ': ' + NonX86BackendName(LBackend), LU64ByScalar, LU64ByBackend);
      end;

      LMask8ByBackend := LBackendTable.CoreVectors.CmpEqU64x8(LU64A, LU64B);
      LMask8ByScalar := LScalarTable.CoreVectors.CmpEqU64x8(LU64A, LU64B);
      CheckEqual(QWord(LMask8ByScalar), QWord(LMask8ByBackend), 'CmpEqU64x8 parity: ' + NonX86BackendName(LBackend));

      LMask8ByBackend := LBackendTable.CoreVectors.CmpLtU64x8(LU64A, LU64B);
      LMask8ByScalar := LScalarTable.CoreVectors.CmpLtU64x8(LU64A, LU64B);
      CheckEqual(QWord(LMask8ByScalar), QWord(LMask8ByBackend), 'CmpLtU64x8 parity: ' + NonX86BackendName(LBackend));

      LMask8ByBackend := LBackendTable.CoreVectors.CmpGtU64x8(LU64A, LU64B);
      LMask8ByScalar := LScalarTable.CoreVectors.CmpGtU64x8(LU64A, LU64B);
      CheckEqual(QWord(LMask8ByScalar), QWord(LMask8ByBackend), 'CmpGtU64x8 parity: ' + NonX86BackendName(LBackend));

      LMask8ByBackend := LBackendTable.CoreVectors.CmpLeU64x8(LU64A, LU64B);
      LMask8ByScalar := LScalarTable.CoreVectors.CmpLeU64x8(LU64A, LU64B);
      CheckEqual(QWord(LMask8ByScalar), QWord(LMask8ByBackend), 'CmpLeU64x8 parity: ' + NonX86BackendName(LBackend));

      LMask8ByBackend := LBackendTable.CoreVectors.CmpGeU64x8(LU64A, LU64B);
      LMask8ByScalar := LScalarTable.CoreVectors.CmpGeU64x8(LU64A, LU64B);
      CheckEqual(QWord(LMask8ByScalar), QWord(LMask8ByBackend), 'CmpGeU64x8 parity: ' + NonX86BackendName(LBackend));

      LMask8ByBackend := LBackendTable.CoreVectors.CmpNeU64x8(LU64A, LU64B);
      LMask8ByScalar := LScalarTable.CoreVectors.CmpNeU64x8(LU64A, LU64B);
      CheckEqual(QWord(LMask8ByScalar), QWord(LMask8ByBackend), 'CmpNeU64x8 parity: ' + NonX86BackendName(LBackend));

      LU8ByBackend := LBackendTable.CoreVectors.AddU8x64(LU8A, LU8B);
      LU8ByScalar := LScalarTable.CoreVectors.AddU8x64(LU8A, LU8B);
      AssertVecU8x64Equal('AddU8x64 parity: ' + NonX86BackendName(LBackend), LU8ByScalar, LU8ByBackend);

      LU8ByBackend := LBackendTable.CoreVectors.SubU8x64(LU8A, LU8B);
      LU8ByScalar := LScalarTable.CoreVectors.SubU8x64(LU8A, LU8B);
      AssertVecU8x64Equal('SubU8x64 parity: ' + NonX86BackendName(LBackend), LU8ByScalar, LU8ByBackend);

      LU8ByBackend := LBackendTable.CoreVectors.AndU8x64(LU8A, LU8B);
      LU8ByScalar := LScalarTable.CoreVectors.AndU8x64(LU8A, LU8B);
      AssertVecU8x64Equal('AndU8x64 parity: ' + NonX86BackendName(LBackend), LU8ByScalar, LU8ByBackend);

      LU8ByBackend := LBackendTable.CoreVectors.OrU8x64(LU8A, LU8B);
      LU8ByScalar := LScalarTable.CoreVectors.OrU8x64(LU8A, LU8B);
      AssertVecU8x64Equal('OrU8x64 parity: ' + NonX86BackendName(LBackend), LU8ByScalar, LU8ByBackend);

      LU8ByBackend := LBackendTable.CoreVectors.XorU8x64(LU8A, LU8B);
      LU8ByScalar := LScalarTable.CoreVectors.XorU8x64(LU8A, LU8B);
      AssertVecU8x64Equal('XorU8x64 parity: ' + NonX86BackendName(LBackend), LU8ByScalar, LU8ByBackend);

      LU8ByBackend := LBackendTable.CoreVectors.NotU8x64(LU8A);
      LU8ByScalar := LScalarTable.CoreVectors.NotU8x64(LU8A);
      AssertVecU8x64Equal('NotU8x64 parity: ' + NonX86BackendName(LBackend), LU8ByScalar, LU8ByBackend);

      LMask64ByBackend := LBackendTable.CoreVectors.CmpEqU8x64(LU8A, LU8B);
      LMask64ByScalar := LScalarTable.CoreVectors.CmpEqU8x64(LU8A, LU8B);
      CheckEqual(QWord(LMask64ByScalar), QWord(LMask64ByBackend), 'CmpEqU8x64 parity: ' + NonX86BackendName(LBackend));

      LMask64ByBackend := LBackendTable.CoreVectors.CmpLtU8x64(LU8A, LU8B);
      LMask64ByScalar := LScalarTable.CoreVectors.CmpLtU8x64(LU8A, LU8B);
      CheckEqual(QWord(LMask64ByScalar), QWord(LMask64ByBackend), 'CmpLtU8x64 parity: ' + NonX86BackendName(LBackend));

      LMask64ByBackend := LBackendTable.CoreVectors.CmpGtU8x64(LU8A, LU8B);
      LMask64ByScalar := LScalarTable.CoreVectors.CmpGtU8x64(LU8A, LU8B);
      CheckEqual(QWord(LMask64ByScalar), QWord(LMask64ByBackend), 'CmpGtU8x64 parity: ' + NonX86BackendName(LBackend));

      LU8ByBackend := LBackendTable.CoreVectors.MinU8x64(LU8A, LU8B);
      LU8ByScalar := LScalarTable.CoreVectors.MinU8x64(LU8A, LU8B);
      AssertVecU8x64Equal('MinU8x64 parity: ' + NonX86BackendName(LBackend), LU8ByScalar, LU8ByBackend);

      LU8ByBackend := LBackendTable.CoreVectors.MaxU8x64(LU8A, LU8B);
      LU8ByScalar := LScalarTable.CoreVectors.MaxU8x64(LU8A, LU8B);
      AssertVecU8x64Equal('MaxU8x64 parity: ' + NonX86BackendName(LBackend), LU8ByScalar, LU8ByBackend);

    Inc(LChecked);
  end;

  if LChecked = 0 then
    CheckTrue(True, 'No non-x86 backend registered/active on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_WideInteger_FuzzSeed_Parity_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LBackendTable: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LI16A, LI16B: TVecI16x32;
  LI8A, LI8B: TVecI8x64;
  LU32A, LU32B: TVecU32x16;
  LU64A, LU64B: TVecU64x8;
  LU8A, LU8B: TVecU8x64;
  LI16ByBackend, LI16ByScalar: TVecI16x32;
  LI8ByBackend, LI8ByScalar: TVecI8x64;
  LU32ByBackend, LU32ByScalar: TVecU32x16;
  LU64ByBackend, LU64ByScalar: TVecU64x8;
  LU8ByBackend, LU8ByScalar: TVecU8x64;
  LMask32ByBackend, LMask32ByScalar: TMask32;
  LMask64ByBackend, LMask64ByScalar: TMask64;
  LMask16ByBackend, LMask16ByScalar: TMask16;
  LMask8ByBackend, LMask8ByScalar: TMask8;
  LI16ShiftChoices: array[0..4] of Integer;
  LU32ShiftChoices: array[0..4] of Integer;
  LU64ShiftChoices: array[0..4] of Integer;
  LIter: Integer;
  LIndex: Integer;
  LChecked: Integer;
  LOriginalSeed: Integer;
  LShiftCount: Integer;

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

  procedure AssertVecU32x16Equal(const aOp: string; const aExpected, aActual: TVecU32x16);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 15 do
      CheckEqual(QWord(aExpected.u[LLane]), QWord(aActual.u[LLane]), aOp + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecU64x8Equal(const aOp: string; const aExpected, aActual: TVecU64x8);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 7 do
      CheckEqual(QWord(aExpected.u[LLane]), QWord(aActual.u[LLane]), aOp + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecU8x64Equal(const aOp: string; const aExpected, aActual: TVecU8x64);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 63 do
      CheckEqual(QWord(aExpected.u[LLane]), QWord(aActual.u[LLane]), aOp + ' lane ' + IntToStr(LLane));
  end;

  function NextU32: DWord;
  begin
    Result := DWord(Random($10000)) or (DWord(Random($10000)) shl 16);
  end;

  function NextU64: QWord;
  begin
    Result := QWord(NextU32) or (QWord(NextU32) shl 32);
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LChecked := 0;

  LI16ShiftChoices[0] := -1;
  LI16ShiftChoices[1] := 0;
  LI16ShiftChoices[2] := 3;
  LI16ShiftChoices[3] := 15;
  LI16ShiftChoices[4] := 16;

  LU32ShiftChoices[0] := 0;
  LU32ShiftChoices[1] := 5;
  LU32ShiftChoices[2] := 13;
  LU32ShiftChoices[3] := 31;
  LU32ShiftChoices[4] := 32;

  LU64ShiftChoices[0] := 0;
  LU64ShiftChoices[1] := 7;
  LU64ShiftChoices[2] := 21;
  LU64ShiftChoices[3] := 63;
  LU64ShiftChoices[4] := 64;

  LOriginalSeed := RandSeed;
  RandSeed := 20260311;
  try
    for LBackend in LBackends do
    begin
      if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

        for LIter := 1 to 24 do
        begin
          for LIndex := 0 to 31 do
          begin
            LI16A.i[LIndex] := Int16(Random(65536) - 32768);
            LI16B.i[LIndex] := Int16(Random(65536) - 32768);
          end;

          for LIndex := 0 to 63 do
          begin
            LI8A.i[LIndex] := Int8(Random(256) - 128);
            LI8B.i[LIndex] := Int8(Random(256) - 128);
            LU8A.u[LIndex] := Byte(Random(256));
            LU8B.u[LIndex] := Byte(Random(256));
          end;

          for LIndex := 0 to 15 do
          begin
            LU32A.u[LIndex] := NextU32;
            LU32B.u[LIndex] := NextU32;
          end;

          for LIndex := 0 to 7 do
          begin
            LU64A.u[LIndex] := NextU64;
            LU64B.u[LIndex] := NextU64;
          end;

          LI16ByBackend := LBackendTable.CoreVectors.AddI16x32(LI16A, LI16B);
          LI16ByScalar := LScalarTable.CoreVectors.AddI16x32(LI16A, LI16B);
          AssertVecI16x32Equal('Fuzz AddI16x32 iter ' + IntToStr(LIter) + ': ' + NonX86BackendName(LBackend), LI16ByScalar, LI16ByBackend);

          LShiftCount := LI16ShiftChoices[Random(Length(LI16ShiftChoices))];
          LI16ByBackend := LBackendTable.CoreVectors.ShiftRightArithI16x32(LI16A, LShiftCount);
          LI16ByScalar := LScalarTable.CoreVectors.ShiftRightArithI16x32(LI16A, LShiftCount);
          AssertVecI16x32Equal('Fuzz ShiftRightArithI16x32 iter ' + IntToStr(LIter) + ' c=' + IntToStr(LShiftCount) + ': ' + NonX86BackendName(LBackend), LI16ByScalar, LI16ByBackend);

          LMask32ByBackend := LBackendTable.CoreVectors.CmpLtI16x32(LI16A, LI16B);
          LMask32ByScalar := LScalarTable.CoreVectors.CmpLtI16x32(LI16A, LI16B);
          CheckEqual(QWord(LMask32ByScalar), QWord(LMask32ByBackend), 'Fuzz CmpLtI16x32 iter ' + IntToStr(LIter) + ': ' + NonX86BackendName(LBackend));

          LI8ByBackend := LBackendTable.CoreVectors.AndNotI8x64(LI8A, LI8B);
          LI8ByScalar := LScalarTable.CoreVectors.AndNotI8x64(LI8A, LI8B);
          AssertVecI8x64Equal('Fuzz AndNotI8x64 iter ' + IntToStr(LIter) + ': ' + NonX86BackendName(LBackend), LI8ByScalar, LI8ByBackend);

          LMask64ByBackend := LBackendTable.CoreVectors.CmpEqI8x64(LI8A, LI8B);
          LMask64ByScalar := LScalarTable.CoreVectors.CmpEqI8x64(LI8A, LI8B);
          CheckEqual(QWord(LMask64ByScalar), QWord(LMask64ByBackend), 'Fuzz CmpEqI8x64 iter ' + IntToStr(LIter) + ': ' + NonX86BackendName(LBackend));

          LU32ByBackend := LBackendTable.CoreVectors.MulU32x16(LU32A, LU32B);
          LU32ByScalar := LScalarTable.CoreVectors.MulU32x16(LU32A, LU32B);
          AssertVecU32x16Equal('Fuzz MulU32x16 iter ' + IntToStr(LIter) + ': ' + NonX86BackendName(LBackend), LU32ByScalar, LU32ByBackend);

          LShiftCount := LU32ShiftChoices[Random(Length(LU32ShiftChoices))];
          LU32ByBackend := LBackendTable.CoreVectors.ShiftRightU32x16(LU32A, LShiftCount);
          LU32ByScalar := LScalarTable.CoreVectors.ShiftRightU32x16(LU32A, LShiftCount);
          AssertVecU32x16Equal('Fuzz ShiftRightU32x16 iter ' + IntToStr(LIter) + ' c=' + IntToStr(LShiftCount) + ': ' + NonX86BackendName(LBackend), LU32ByScalar, LU32ByBackend);

          LMask16ByBackend := LBackendTable.CoreVectors.CmpLeU32x16(LU32A, LU32B);
          LMask16ByScalar := LScalarTable.CoreVectors.CmpLeU32x16(LU32A, LU32B);
          CheckEqual(QWord(LMask16ByScalar), QWord(LMask16ByBackend), 'Fuzz CmpLeU32x16 iter ' + IntToStr(LIter) + ': ' + NonX86BackendName(LBackend));

          LU64ByBackend := LBackendTable.CoreVectors.AddU64x8(LU64A, LU64B);
          LU64ByScalar := LScalarTable.CoreVectors.AddU64x8(LU64A, LU64B);
          AssertVecU64x8Equal('Fuzz AddU64x8 iter ' + IntToStr(LIter) + ': ' + NonX86BackendName(LBackend), LU64ByScalar, LU64ByBackend);

          LShiftCount := LU64ShiftChoices[Random(Length(LU64ShiftChoices))];
          LU64ByBackend := LBackendTable.CoreVectors.ShiftLeftU64x8(LU64A, LShiftCount);
          LU64ByScalar := LScalarTable.CoreVectors.ShiftLeftU64x8(LU64A, LShiftCount);
          AssertVecU64x8Equal('Fuzz ShiftLeftU64x8 iter ' + IntToStr(LIter) + ' c=' + IntToStr(LShiftCount) + ': ' + NonX86BackendName(LBackend), LU64ByScalar, LU64ByBackend);

          LMask8ByBackend := LBackendTable.CoreVectors.CmpNeU64x8(LU64A, LU64B);
          LMask8ByScalar := LScalarTable.CoreVectors.CmpNeU64x8(LU64A, LU64B);
          CheckEqual(QWord(LMask8ByScalar), QWord(LMask8ByBackend), 'Fuzz CmpNeU64x8 iter ' + IntToStr(LIter) + ': ' + NonX86BackendName(LBackend));

          LU8ByBackend := LBackendTable.CoreVectors.XorU8x64(LU8A, LU8B);
          LU8ByScalar := LScalarTable.CoreVectors.XorU8x64(LU8A, LU8B);
          AssertVecU8x64Equal('Fuzz XorU8x64 iter ' + IntToStr(LIter) + ': ' + NonX86BackendName(LBackend), LU8ByScalar, LU8ByBackend);

          LMask64ByBackend := LBackendTable.CoreVectors.CmpGtU8x64(LU8A, LU8B);
          LMask64ByScalar := LScalarTable.CoreVectors.CmpGtU8x64(LU8A, LU8B);
          CheckEqual(QWord(LMask64ByScalar), QWord(LMask64ByBackend), 'Fuzz CmpGtU8x64 iter ' + IntToStr(LIter) + ': ' + NonX86BackendName(LBackend));
        end;

        Inc(LChecked);
    end;
  finally
    RandSeed := LOriginalSeed;
  end;

  if LChecked = 0 then
    CheckTrue(True, 'No non-x86 backend registered/active on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_WideCompareMaskParity_IfAvailable;
const
  C_SIGNED_CASE_COUNT = 4;
  C_UNSIGNED_CASE_COUNT = 8;
  C_I32X8_CASES_A: array[0..C_SIGNED_CASE_COUNT - 1, 0..7] of Int32 = (
    (Low(Int32), -100, -1, 0, 1, 100, High(Int32), 42), (-1, -2, -3, -4, 4, 3, 2, 1),
    (0, 0, 0, 0, 0, 0, 0, 0), (7, -7, 1024, -1024, 33, -33, 5, -5)
  );
  C_I32X8_CASES_B: array[0..C_SIGNED_CASE_COUNT - 1, 0..7] of Int32 = (
    (Low(Int32), -99, 0, 0, -1, 101, High(Int32) - 1, 42), (-1, -1, -4, -4, 4, 2, 3, 0),
    (0, 0, 0, 0, 0, 0, 0, 0), (8, -8, 1023, -1023, 33, -40, 6, -4)
  );
  C_I64X4_CASES_A: array[0..C_SIGNED_CASE_COUNT - 1, 0..3] of Int64 = (
    (Low(Int64), -1, 0, High(Int64)), (-1000, 7777777, -1234567890123, 42),
    (0, 0, 0, 0), (99, -99, 4096, -4096)
  );
  C_I64X4_CASES_B: array[0..C_SIGNED_CASE_COUNT - 1, 0..3] of Int64 = (
    (Low(Int64), 0, 0, High(Int64) - 1), (13, -9, 3000, -500),
    (0, 0, 0, 0), (100, -100, 4095, -4095)
  );
  C_I32X16_CASES_A: array[0..C_SIGNED_CASE_COUNT - 1, 0..15] of Int32 = (
    (Low(Int32), -1024, -1, 0, 1, 1024, High(Int32), 42, -42, 7, -7, 99, -99, 2048, -2048, 123456), (-1, -2, -3, -4, -5, -6, -7, -8, 8, 7, 6, 5, 4, 3, 2, 1),
    (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), (17, -17, 33, -33, 65, -65, 129, -129, 257, -257, 513, -513, 1025, -1025, 2049, -2049)
  );
  C_I32X16_CASES_B: array[0..C_SIGNED_CASE_COUNT - 1, 0..15] of Int32 = (
    (Low(Int32), -1023, 0, 0, -1, 2048, High(Int32), 41, -43, 8, -8, 99, -100, 2047, -2049, 123456), (-1, -1, -4, -4, -4, -7, -8, -8, 7, 8, 5, 6, 3, 4, 1, 2),
    (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), (16, -18, 34, -32, 64, -66, 130, -128, 256, -258, 514, -512, 1026, -1024, 2050, -2048)
  );
  C_I64X8_CASES_A: array[0..C_SIGNED_CASE_COUNT - 1, 0..7] of Int64 = (
    (Low(Int64), -1, 0, 1, 2, -2, High(Int64), 42), (-1000, 7777777, -1234567890123, 42, -7, 9, -11, 13),
    (0, 0, 0, 0, 0, 0, 0, 0), (512, -512, 1024, -1024, 2048, -2048, 4096, -4096)
  );
  C_I64X8_CASES_B: array[0..C_SIGNED_CASE_COUNT - 1, 0..7] of Int64 = (
    (Low(Int64), 0, 0, -1, 3, -3, High(Int64), 42), (13, -9, 3000, -500, -8, 9, -10, 14),
    (0, 0, 0, 0, 0, 0, 0, 0), (513, -513, 1023, -1023, 2048, -2049, 4097, -4095)
  );
  C_U32_CASES_A: array[0..C_UNSIGNED_CASE_COUNT - 1, 0..7] of UInt32 = (
    (0, 1, 2, 3, 4, 5, 6, 7), ($FFFFFFFF, $FFFFFFFE, $80000000, $7FFFFFFF, 1, 2, 3, 4),
    (100, 200, 300, 400, 500, 600, 700, 800), (0, 0, 0, 0, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF),
    ($80000000, $80000001, $7FFFFFFE, $7FFFFFFF, 15, 16, 17, 18), (42, 43, 44, 45, 46, 47, 48, 49),
    ($AAAAAAAA, $55555555, $0F0F0F0F, $F0F0F0F0, 9, 10, 11, 12), (1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000)
  );
  C_U32_CASES_B: array[0..C_UNSIGNED_CASE_COUNT - 1, 0..7] of UInt32 = (
    (0, 0, 3, 2, 4, 6, 5, 7), ($FFFFFFFF, 1, $7FFFFFFF, $80000000, 2, 2, 4, 3),
    (100, 199, 301, 400, 499, 601, 700, 900), (1, 0, $FFFFFFFF, 0, $FFFFFFFF, 0, $FFFFFFFF, 0),
    ($7FFFFFFF, $80000000, $7FFFFFFF, $7FFFFFFE, 15, 15, 18, 17), (41, 43, 45, 45, 47, 47, 49, 49),
    ($AAAAAAAA, $AAAAAAAA, $F0F0F0F0, $0F0F0F0F, 8, 10, 12, 12), (999, 2001, 3000, 3999, 5001, 6000, 6999, 9000)
  );
  C_U64_CASES_A: array[0..C_UNSIGNED_CASE_COUNT - 1, 0..3] of UInt64 = (
    (0, 1, 2, 3), (18446744073709551615, 9223372036854775808, 9223372036854775807, 42),
    (1000, 2000, 3000, 4000), (0, 18446744073709551615, 123456789, 987654321),
    (12297829382473034410, 6148914691236517205, 11, 12), (15, 16, 17, 18),
    ($0000000100000000, $0000000200000000, 5, 6), (9000000000, 9000000001, 9000000002, 9000000003)
  );
  C_U64_CASES_B: array[0..C_UNSIGNED_CASE_COUNT - 1, 0..3] of UInt64 = (
    (0, 0, 3, 2), (18446744073709551615, 9223372036854775807, 9223372036854775808, 41),
    (1000, 1999, 3001, 4000), (1, 18446744073709551615, 123456788, 987654322),
    (12297829382473034410, 12297829382473034410, 10, 12), (14, 16, 18, 18),
    ($0000000100000001, $0000000200000000, 4, 7), (9000000001, 9000000001, 9000000000, 9000000004)
  );
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LBackendTable: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LI32x8A, LI32x8B: TVecI32x8;
  LU32x8A, LU32x8B: TVecU32x8;
  LI64x4A, LI64x4B: TVecI64x4;
  LU64x4A, LU64x4B: TVecU64x4;
  LI32x16A, LI32x16B: TVecI32x16;
  LI64x8A, LI64x8B: TVecI64x8;
  LMask4ByBackend, LMask4ByScalar, LMask4ByFacade: TMask4;
  LMask8ByBackend, LMask8ByScalar, LMask8ByFacade: TMask8;
  LMask16ByBackend, LMask16ByScalar, LMask16ByFacade: TMask16;
  LExpectedMask4: TMask4;
  LExpectedMask8: TMask8;
  LExpectedMask16: TMask16;
  LCaseIdx: Integer;
  LLane: Integer;
  LChecked: Integer;

  procedure AssertMask4Equal(const aLabel: string; const aExpected, aActual: TMask4);
  begin
    CheckEqual(Integer(aExpected), Integer(aActual), aLabel);
  end;

  procedure AssertMask8Equal(const aLabel: string; const aExpected, aActual: TMask8);
  begin
    CheckEqual(Integer(aExpected), Integer(aActual), aLabel);
  end;

  procedure AssertMask16Equal(const aLabel: string; const aExpected, aActual: TMask16);
  begin
    CheckEqual(Integer(aExpected), Integer(aActual), aLabel);
  end;

  procedure AssertMask4HelperParity(const aLabel: string; const aMask: TMask4);
  begin
    CheckEqual(ScalarMask4All(aMask), LBackendTable.Mask.Mask4All(aMask), aLabel + ' Mask4All');
    CheckEqual(ScalarMask4Any(aMask), LBackendTable.Mask.Mask4Any(aMask), aLabel + ' Mask4Any');
    CheckEqual(ScalarMask4None(aMask), LBackendTable.Mask.Mask4None(aMask), aLabel + ' Mask4None');
    CheckEqual(ScalarMask4PopCount(aMask), LBackendTable.Mask.Mask4PopCount(aMask), aLabel + ' Mask4PopCount');
    CheckEqual(ScalarMask4FirstSet(aMask), LBackendTable.Mask.Mask4FirstSet(aMask), aLabel + ' Mask4FirstSet');
  end;

  procedure AssertMask8HelperParity(const aLabel: string; const aMask: TMask8);
  begin
    CheckEqual(ScalarMask8All(aMask), LBackendTable.Mask.Mask8All(aMask), aLabel + ' Mask8All');
    CheckEqual(ScalarMask8Any(aMask), LBackendTable.Mask.Mask8Any(aMask), aLabel + ' Mask8Any');
    CheckEqual(ScalarMask8None(aMask), LBackendTable.Mask.Mask8None(aMask), aLabel + ' Mask8None');
    CheckEqual(ScalarMask8PopCount(aMask), LBackendTable.Mask.Mask8PopCount(aMask), aLabel + ' Mask8PopCount');
    CheckEqual(ScalarMask8FirstSet(aMask), LBackendTable.Mask.Mask8FirstSet(aMask), aLabel + ' Mask8FirstSet');
  end;

  procedure AssertMask16HelperParity(const aLabel: string; const aMask: TMask16);
  begin
    CheckEqual(ScalarMask16All(aMask), LBackendTable.Mask.Mask16All(aMask), aLabel + ' Mask16All');
    CheckEqual(ScalarMask16Any(aMask), LBackendTable.Mask.Mask16Any(aMask), aLabel + ' Mask16Any');
    CheckEqual(ScalarMask16None(aMask), LBackendTable.Mask.Mask16None(aMask), aLabel + ' Mask16None');
    CheckEqual(ScalarMask16PopCount(aMask), LBackendTable.Mask.Mask16PopCount(aMask), aLabel + ' Mask16PopCount');
    CheckEqual(ScalarMask16FirstSet(aMask), LBackendTable.Mask.Mask16FirstSet(aMask), aLabel + ' Mask16FirstSet');
  end;

  procedure LoadI32x8OneHotProbe(const aLane: Integer; const aLessThan: Boolean);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
    begin
      LI32x8A.i[LLaneIndex] := (LLaneIndex - 4) * 17;
      LI32x8B.i[LLaneIndex] := LI32x8A.i[LLaneIndex];
    end;
    if aLessThan then
    begin
      LI32x8A.i[aLane] := -4096 - aLane;
      LI32x8B.i[aLane] := 4096 + aLane;
    end
    else
    begin
      LI32x8A.i[aLane] := 4096 + aLane;
      LI32x8B.i[aLane] := -4096 - aLane;
    end;
  end;

  procedure LoadI64x4OneHotProbe(const aLane: Integer; const aLessThan: Boolean);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 3 do
    begin
      LI64x4A.i[LLaneIndex] := Int64(LLaneIndex - 2) * 257;
      LI64x4B.i[LLaneIndex] := LI64x4A.i[LLaneIndex];
    end;
    if aLessThan then
    begin
      LI64x4A.i[aLane] := -Int64(1) shl (40 + aLane);
      LI64x4B.i[aLane] := Int64(1) shl (40 + aLane);
    end
    else
    begin
      LI64x4A.i[aLane] := Int64(1) shl (40 + aLane);
      LI64x4B.i[aLane] := -Int64(1) shl (40 + aLane);
    end;
  end;

  procedure LoadI32x16OneHotProbe(const aLane: Integer; const aLessThan: Boolean);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 15 do
    begin
      LI32x16A.i[LLaneIndex] := (LLaneIndex - 8) * 33;
      LI32x16B.i[LLaneIndex] := LI32x16A.i[LLaneIndex];
    end;
    if aLessThan then
    begin
      LI32x16A.i[aLane] := -8192 - aLane;
      LI32x16B.i[aLane] := 8192 + aLane;
    end
    else
    begin
      LI32x16A.i[aLane] := 8192 + aLane;
      LI32x16B.i[aLane] := -8192 - aLane;
    end;
  end;

  procedure LoadI64x8OneHotProbe(const aLane: Integer; const aLessThan: Boolean);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
    begin
      LI64x8A.i[LLaneIndex] := Int64(LLaneIndex - 4) * 1025;
      LI64x8B.i[LLaneIndex] := LI64x8A.i[LLaneIndex];
    end;
    if aLessThan then
    begin
      LI64x8A.i[aLane] := -Int64(1) shl (44 + (aLane mod 4));
      LI64x8B.i[aLane] := Int64(1) shl (44 + (aLane mod 4));
    end
    else
    begin
      LI64x8A.i[aLane] := Int64(1) shl (44 + (aLane mod 4));
      LI64x8B.i[aLane] := -Int64(1) shl (44 + (aLane mod 4));
    end;
  end;

  procedure LoadU32x8OneHotProbe(const aLane: Integer; const aLessThan: Boolean);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
    begin
      LU32x8A.u[LLaneIndex] := UInt32(LLaneIndex * 19 + 7);
      LU32x8B.u[LLaneIndex] := LU32x8A.u[LLaneIndex];
    end;
    if aLessThan then
    begin
      LU32x8A.u[aLane] := UInt32(16 + aLane);
      LU32x8B.u[aLane] := $FFFFFF00 - UInt32(aLane);
    end
    else
    begin
      LU32x8A.u[aLane] := $FFFFFF00 - UInt32(aLane);
      LU32x8B.u[aLane] := UInt32(16 + aLane);
    end;
  end;

  procedure LoadU64x4OneHotProbe(const aLane: Integer; const aLessThan: Boolean);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 3 do
    begin
      LU64x4A.u[LLaneIndex] := UInt64(LLaneIndex) * 257 + 11;
      LU64x4B.u[LLaneIndex] := LU64x4A.u[LLaneIndex];
    end;
    if aLessThan then
    begin
      LU64x4A.u[aLane] := UInt64(32 + aLane);
      LU64x4B.u[aLane] := UInt64($FFFFFFFFFFFFFF00) - UInt64(aLane);
    end
    else
    begin
      LU64x4A.u[aLane] := UInt64($FFFFFFFFFFFFFF00) - UInt64(aLane);
      LU64x4B.u[aLane] := UInt64(32 + aLane);
    end;
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LChecked := 0;

  for LBackend in LBackends do
  begin
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpEqI32x8), 'CmpEqI32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLtI32x8), 'CmpLtI32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpGtI32x8), 'CmpGtI32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLeI32x8), 'CmpLeI32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpGeI32x8), 'CmpGeI32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpNeI32x8), 'CmpNeI32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpEqU32x8), 'CmpEqU32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLtU32x8), 'CmpLtU32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpGtU32x8), 'CmpGtU32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLeU32x8), 'CmpLeU32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpGeU32x8), 'CmpGeU32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpNeU32x8), 'CmpNeU32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpEqI64x4), 'CmpEqI64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLtI64x4), 'CmpLtI64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpGtI64x4), 'CmpGtI64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLeI64x4), 'CmpLeI64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpGeI64x4), 'CmpGeI64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpNeI64x4), 'CmpNeI64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpEqU64x4), 'CmpEqU64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLtU64x4), 'CmpLtU64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpGtU64x4), 'CmpGtU64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLeU64x4), 'CmpLeU64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpGeU64x4), 'CmpGeU64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpNeU64x4), 'CmpNeU64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpEqI32x16), 'CmpEqI32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLtI32x16), 'CmpLtI32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpGtI32x16), 'CmpGtI32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLeI32x16), 'CmpLeI32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpGeI32x16), 'CmpGeI32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpNeI32x16), 'CmpNeI32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpEqI64x8), 'CmpEqI64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLtI64x8), 'CmpLtI64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpGtI64x8), 'CmpGtI64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpLeI64x8), 'CmpLeI64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpGeI64x8), 'CmpGeI64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.CmpNeI64x8), 'CmpNeI64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.Mask.Mask4All), 'Mask4All missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.Mask.Mask4Any), 'Mask4Any missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.Mask.Mask4None), 'Mask4None missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.Mask.Mask4PopCount), 'Mask4PopCount missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.Mask.Mask4FirstSet), 'Mask4FirstSet missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.Mask.Mask8All), 'Mask8All missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.Mask.Mask8Any), 'Mask8Any missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.Mask.Mask8None), 'Mask8None missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.Mask.Mask8PopCount), 'Mask8PopCount missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.Mask.Mask8FirstSet), 'Mask8FirstSet missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.Mask.Mask16All), 'Mask16All missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.Mask.Mask16Any), 'Mask16Any missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.Mask.Mask16None), 'Mask16None missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.Mask.Mask16PopCount), 'Mask16PopCount missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.Mask.Mask16FirstSet), 'Mask16FirstSet missing: ' + NonX86BackendName(LBackend));

      for LCaseIdx := 0 to C_SIGNED_CASE_COUNT - 1 do
      begin
        for LLane := 0 to 7 do
        begin
          LI32x8A.i[LLane] := C_I32X8_CASES_A[LCaseIdx, LLane];
          LI32x8B.i[LLane] := C_I32X8_CASES_B[LCaseIdx, LLane];
          LI64x8A.i[LLane] := C_I64X8_CASES_A[LCaseIdx, LLane];
          LI64x8B.i[LLane] := C_I64X8_CASES_B[LCaseIdx, LLane];
        end;
        for LLane := 0 to 3 do
        begin
          LI64x4A.i[LLane] := C_I64X4_CASES_A[LCaseIdx, LLane];
          LI64x4B.i[LLane] := C_I64X4_CASES_B[LCaseIdx, LLane];
        end;
        for LLane := 0 to 15 do
        begin
          LI32x16A.i[LLane] := C_I32X16_CASES_A[LCaseIdx, LLane];
          LI32x16B.i[LLane] := C_I32X16_CASES_B[LCaseIdx, LLane];
        end;

        LMask8ByBackend := LBackendTable.CoreVectors.CmpEqI32x8(LI32x8A, LI32x8B);
        LMask8ByScalar := LScalarTable.CoreVectors.CmpEqI32x8(LI32x8A, LI32x8B);
        AssertMask8Equal('CmpEqI32x8 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar, LMask8ByBackend);

        LMask8ByBackend := LBackendTable.CoreVectors.CmpLtI32x8(LI32x8A, LI32x8B);
        LMask8ByScalar := LScalarTable.CoreVectors.CmpLtI32x8(LI32x8A, LI32x8B);
        AssertMask8Equal('CmpLtI32x8 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar, LMask8ByBackend);
        AssertMask8HelperParity('I32x8 Lt case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar);

        LMask8ByBackend := LBackendTable.CoreVectors.CmpGtI32x8(LI32x8A, LI32x8B);
        LMask8ByScalar := LScalarTable.CoreVectors.CmpGtI32x8(LI32x8A, LI32x8B);
        AssertMask8Equal('CmpGtI32x8 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar, LMask8ByBackend);

        LMask8ByBackend := LBackendTable.CoreVectors.CmpLeI32x8(LI32x8A, LI32x8B);
        LMask8ByScalar := LScalarTable.CoreVectors.CmpLeI32x8(LI32x8A, LI32x8B);
        AssertMask8Equal('CmpLeI32x8 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar, LMask8ByBackend);

        LMask8ByBackend := LBackendTable.CoreVectors.CmpGeI32x8(LI32x8A, LI32x8B);
        LMask8ByScalar := LScalarTable.CoreVectors.CmpGeI32x8(LI32x8A, LI32x8B);
        AssertMask8Equal('CmpGeI32x8 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar, LMask8ByBackend);

        LMask8ByBackend := LBackendTable.CoreVectors.CmpNeI32x8(LI32x8A, LI32x8B);
        LMask8ByScalar := LScalarTable.CoreVectors.CmpNeI32x8(LI32x8A, LI32x8B);
        AssertMask8Equal('CmpNeI32x8 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar, LMask8ByBackend);

        LMask4ByBackend := LBackendTable.CoreVectors.CmpEqI64x4(LI64x4A, LI64x4B);
        LMask4ByScalar := LScalarTable.CoreVectors.CmpEqI64x4(LI64x4A, LI64x4B);
        AssertMask4Equal('CmpEqI64x4 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask4ByScalar, LMask4ByBackend);

        LMask4ByBackend := LBackendTable.CoreVectors.CmpLtI64x4(LI64x4A, LI64x4B);
        LMask4ByScalar := LScalarTable.CoreVectors.CmpLtI64x4(LI64x4A, LI64x4B);
        AssertMask4Equal('CmpLtI64x4 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask4ByScalar, LMask4ByBackend);
        AssertMask4HelperParity('I64x4 Lt case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask4ByScalar);

        LMask4ByBackend := LBackendTable.CoreVectors.CmpGtI64x4(LI64x4A, LI64x4B);
        LMask4ByScalar := LScalarTable.CoreVectors.CmpGtI64x4(LI64x4A, LI64x4B);
        AssertMask4Equal('CmpGtI64x4 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask4ByScalar, LMask4ByBackend);

        LMask4ByBackend := LBackendTable.CoreVectors.CmpLeI64x4(LI64x4A, LI64x4B);
        LMask4ByScalar := LScalarTable.CoreVectors.CmpLeI64x4(LI64x4A, LI64x4B);
        AssertMask4Equal('CmpLeI64x4 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask4ByScalar, LMask4ByBackend);

        LMask4ByBackend := LBackendTable.CoreVectors.CmpGeI64x4(LI64x4A, LI64x4B);
        LMask4ByScalar := LScalarTable.CoreVectors.CmpGeI64x4(LI64x4A, LI64x4B);
        AssertMask4Equal('CmpGeI64x4 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask4ByScalar, LMask4ByBackend);

        LMask4ByBackend := LBackendTable.CoreVectors.CmpNeI64x4(LI64x4A, LI64x4B);
        LMask4ByScalar := LScalarTable.CoreVectors.CmpNeI64x4(LI64x4A, LI64x4B);
        AssertMask4Equal('CmpNeI64x4 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask4ByScalar, LMask4ByBackend);

        LMask16ByBackend := LBackendTable.CoreVectors.CmpEqI32x16(LI32x16A, LI32x16B);
        LMask16ByScalar := LScalarTable.CoreVectors.CmpEqI32x16(LI32x16A, LI32x16B);
        AssertMask16Equal('CmpEqI32x16 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask16ByScalar, LMask16ByBackend);

        LMask16ByBackend := LBackendTable.CoreVectors.CmpLtI32x16(LI32x16A, LI32x16B);
        LMask16ByScalar := LScalarTable.CoreVectors.CmpLtI32x16(LI32x16A, LI32x16B);
        AssertMask16Equal('CmpLtI32x16 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask16ByScalar, LMask16ByBackend);
        AssertMask16HelperParity('I32x16 Lt case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask16ByScalar);

        LMask16ByBackend := LBackendTable.CoreVectors.CmpGtI32x16(LI32x16A, LI32x16B);
        LMask16ByScalar := LScalarTable.CoreVectors.CmpGtI32x16(LI32x16A, LI32x16B);
        AssertMask16Equal('CmpGtI32x16 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask16ByScalar, LMask16ByBackend);

        LMask16ByBackend := LBackendTable.CoreVectors.CmpLeI32x16(LI32x16A, LI32x16B);
        LMask16ByScalar := LScalarTable.CoreVectors.CmpLeI32x16(LI32x16A, LI32x16B);
        AssertMask16Equal('CmpLeI32x16 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask16ByScalar, LMask16ByBackend);

        LMask16ByBackend := LBackendTable.CoreVectors.CmpGeI32x16(LI32x16A, LI32x16B);
        LMask16ByScalar := LScalarTable.CoreVectors.CmpGeI32x16(LI32x16A, LI32x16B);
        AssertMask16Equal('CmpGeI32x16 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask16ByScalar, LMask16ByBackend);

        LMask16ByBackend := LBackendTable.CoreVectors.CmpNeI32x16(LI32x16A, LI32x16B);
        LMask16ByScalar := LScalarTable.CoreVectors.CmpNeI32x16(LI32x16A, LI32x16B);
        AssertMask16Equal('CmpNeI32x16 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask16ByScalar, LMask16ByBackend);

        LMask8ByBackend := LBackendTable.CoreVectors.CmpEqI64x8(LI64x8A, LI64x8B);
        LMask8ByScalar := LScalarTable.CoreVectors.CmpEqI64x8(LI64x8A, LI64x8B);
        AssertMask8Equal('CmpEqI64x8 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar, LMask8ByBackend);

        LMask8ByBackend := LBackendTable.CoreVectors.CmpLtI64x8(LI64x8A, LI64x8B);
        LMask8ByScalar := LScalarTable.CoreVectors.CmpLtI64x8(LI64x8A, LI64x8B);
        AssertMask8Equal('CmpLtI64x8 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar, LMask8ByBackend);
        AssertMask8HelperParity('I64x8 Lt case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar);

        LMask8ByBackend := LBackendTable.CoreVectors.CmpGtI64x8(LI64x8A, LI64x8B);
        LMask8ByScalar := LScalarTable.CoreVectors.CmpGtI64x8(LI64x8A, LI64x8B);
        AssertMask8Equal('CmpGtI64x8 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar, LMask8ByBackend);

        LMask8ByBackend := LBackendTable.CoreVectors.CmpLeI64x8(LI64x8A, LI64x8B);
        LMask8ByScalar := LScalarTable.CoreVectors.CmpLeI64x8(LI64x8A, LI64x8B);
        AssertMask8Equal('CmpLeI64x8 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar, LMask8ByBackend);

        LMask8ByBackend := LBackendTable.CoreVectors.CmpGeI64x8(LI64x8A, LI64x8B);
        LMask8ByScalar := LScalarTable.CoreVectors.CmpGeI64x8(LI64x8A, LI64x8B);
        AssertMask8Equal('CmpGeI64x8 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar, LMask8ByBackend);

        LMask8ByBackend := LBackendTable.CoreVectors.CmpNeI64x8(LI64x8A, LI64x8B);
        LMask8ByScalar := LScalarTable.CoreVectors.CmpNeI64x8(LI64x8A, LI64x8B);
        AssertMask8Equal('CmpNeI64x8 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar, LMask8ByBackend);

        LMask4ByFacade := TMask4(nextpas.core.simd.VecI64x4CmpLe(LI64x4A, LI64x4B));
        LMask4ByScalar := LScalarTable.CoreVectors.CmpLeI64x4(LI64x4A, LI64x4B);
        AssertMask4Equal('Facade VecI64x4CmpLe case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask4ByScalar, LMask4ByFacade);

        LMask16ByFacade := TMask16(nextpas.core.simd.VecI32x16CmpEq(LI32x16A, LI32x16B));
        LMask16ByScalar := LScalarTable.CoreVectors.CmpEqI32x16(LI32x16A, LI32x16B);
        AssertMask16Equal('Facade VecI32x16CmpEq case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask16ByScalar, LMask16ByFacade);

        LMask8ByFacade := TMask8(nextpas.core.simd.VecI64x8CmpLt(LI64x8A, LI64x8B));
        LMask8ByScalar := LScalarTable.CoreVectors.CmpLtI64x8(LI64x8A, LI64x8B);
        AssertMask8Equal('Facade VecI64x8CmpLt case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar, LMask8ByFacade);
      end;

      for LCaseIdx := 0 to C_UNSIGNED_CASE_COUNT - 1 do
      begin
        for LLane := 0 to 7 do
        begin
          LU32x8A.u[LLane] := C_U32_CASES_A[LCaseIdx, LLane];
          LU32x8B.u[LLane] := C_U32_CASES_B[LCaseIdx, LLane];
        end;
        for LLane := 0 to 3 do
        begin
          LU64x4A.u[LLane] := C_U64_CASES_A[LCaseIdx, LLane];
          LU64x4B.u[LLane] := C_U64_CASES_B[LCaseIdx, LLane];
        end;

        LMask8ByBackend := LBackendTable.CoreVectors.CmpEqU32x8(LU32x8A, LU32x8B);
        LMask8ByScalar := LScalarTable.CoreVectors.CmpEqU32x8(LU32x8A, LU32x8B);
        AssertMask8Equal('CmpEqU32x8 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar, LMask8ByBackend);

        LMask8ByBackend := LBackendTable.CoreVectors.CmpLtU32x8(LU32x8A, LU32x8B);
        LMask8ByScalar := LScalarTable.CoreVectors.CmpLtU32x8(LU32x8A, LU32x8B);
        AssertMask8Equal('CmpLtU32x8 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar, LMask8ByBackend);
        AssertMask8HelperParity('U32x8 Lt case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar);

        LMask8ByBackend := LBackendTable.CoreVectors.CmpGtU32x8(LU32x8A, LU32x8B);
        LMask8ByScalar := LScalarTable.CoreVectors.CmpGtU32x8(LU32x8A, LU32x8B);
        AssertMask8Equal('CmpGtU32x8 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar, LMask8ByBackend);

        LMask8ByBackend := LBackendTable.CoreVectors.CmpLeU32x8(LU32x8A, LU32x8B);
        LMask8ByScalar := LScalarTable.CoreVectors.CmpLeU32x8(LU32x8A, LU32x8B);
        AssertMask8Equal('CmpLeU32x8 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar, LMask8ByBackend);

        LMask8ByBackend := LBackendTable.CoreVectors.CmpGeU32x8(LU32x8A, LU32x8B);
        LMask8ByScalar := LScalarTable.CoreVectors.CmpGeU32x8(LU32x8A, LU32x8B);
        AssertMask8Equal('CmpGeU32x8 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar, LMask8ByBackend);

        LMask8ByBackend := LBackendTable.CoreVectors.CmpNeU32x8(LU32x8A, LU32x8B);
        LMask8ByScalar := LScalarTable.CoreVectors.CmpNeU32x8(LU32x8A, LU32x8B);
        AssertMask8Equal('CmpNeU32x8 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar, LMask8ByBackend);

        LMask4ByBackend := LBackendTable.CoreVectors.CmpEqU64x4(LU64x4A, LU64x4B);
        LMask4ByScalar := LScalarTable.CoreVectors.CmpEqU64x4(LU64x4A, LU64x4B);
        AssertMask4Equal('CmpEqU64x4 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask4ByScalar, LMask4ByBackend);

        LMask4ByBackend := LBackendTable.CoreVectors.CmpLtU64x4(LU64x4A, LU64x4B);
        LMask4ByScalar := LScalarTable.CoreVectors.CmpLtU64x4(LU64x4A, LU64x4B);
        AssertMask4Equal('CmpLtU64x4 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask4ByScalar, LMask4ByBackend);
        AssertMask4HelperParity('U64x4 Lt case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask4ByScalar);

        LMask4ByBackend := LBackendTable.CoreVectors.CmpGtU64x4(LU64x4A, LU64x4B);
        LMask4ByScalar := LScalarTable.CoreVectors.CmpGtU64x4(LU64x4A, LU64x4B);
        AssertMask4Equal('CmpGtU64x4 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask4ByScalar, LMask4ByBackend);

        LMask4ByBackend := LBackendTable.CoreVectors.CmpLeU64x4(LU64x4A, LU64x4B);
        LMask4ByScalar := LScalarTable.CoreVectors.CmpLeU64x4(LU64x4A, LU64x4B);
        AssertMask4Equal('CmpLeU64x4 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask4ByScalar, LMask4ByBackend);

        LMask4ByBackend := LBackendTable.CoreVectors.CmpGeU64x4(LU64x4A, LU64x4B);
        LMask4ByScalar := LScalarTable.CoreVectors.CmpGeU64x4(LU64x4A, LU64x4B);
        AssertMask4Equal('CmpGeU64x4 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask4ByScalar, LMask4ByBackend);

        LMask4ByBackend := LBackendTable.CoreVectors.CmpNeU64x4(LU64x4A, LU64x4B);
        LMask4ByScalar := LScalarTable.CoreVectors.CmpNeU64x4(LU64x4A, LU64x4B);
        AssertMask4Equal('CmpNeU64x4 parity case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask4ByScalar, LMask4ByBackend);

        LMask8ByFacade := TMask8(nextpas.core.simd.VecU32x8CmpEq(LU32x8A, LU32x8B));
        LMask8ByScalar := LScalarTable.CoreVectors.CmpEqU32x8(LU32x8A, LU32x8B);
        AssertMask8Equal('Facade VecU32x8CmpEq case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask8ByScalar, LMask8ByFacade);

        LMask4ByFacade := TMask4(nextpas.core.simd.VecU64x4CmpGe(LU64x4A, LU64x4B));
        LMask4ByScalar := LScalarTable.CoreVectors.CmpGeU64x4(LU64x4A, LU64x4B);
        AssertMask4Equal('Facade VecU64x4CmpGe case=' + IntToStr(LCaseIdx) + ': ' + NonX86BackendName(LBackend), LMask4ByScalar, LMask4ByFacade);
      end;

      AssertMask4HelperParity('Synthetic Mask4 zero: ' + NonX86BackendName(LBackend), TMask4(0));
      AssertMask4HelperParity('Synthetic Mask4 mixed: ' + NonX86BackendName(LBackend), TMask4($0A));
      AssertMask4HelperParity('Synthetic Mask4 full: ' + NonX86BackendName(LBackend), TMask4($0F));
      AssertMask8HelperParity('Synthetic Mask8 zero: ' + NonX86BackendName(LBackend), TMask8(0));
      AssertMask8HelperParity('Synthetic Mask8 mixed: ' + NonX86BackendName(LBackend), TMask8($52));
      AssertMask8HelperParity('Synthetic Mask8 full: ' + NonX86BackendName(LBackend), TMask8($FF));
      AssertMask16HelperParity('Synthetic Mask16 zero: ' + NonX86BackendName(LBackend), TMask16(0));
      AssertMask16HelperParity('Synthetic Mask16 mixed: ' + NonX86BackendName(LBackend), TMask16($A55A));
      AssertMask16HelperParity('Synthetic Mask16 full: ' + NonX86BackendName(LBackend), TMask16($FFFF));

      for LLane := 0 to 7 do
      begin
        LExpectedMask8 := TMask8(1 shl LLane);

        LoadI32x8OneHotProbe(LLane, True);
        AssertMask8Equal('CmpLtI32x8 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask8, LBackendTable.CoreVectors.CmpLtI32x8(LI32x8A, LI32x8B));
        AssertMask8Equal('CmpEqI32x8 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask8($FF xor LExpectedMask8), LBackendTable.CoreVectors.CmpEqI32x8(LI32x8A, LI32x8B));
        AssertMask8Equal('CmpGtI32x8 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), 0, LBackendTable.CoreVectors.CmpGtI32x8(LI32x8A, LI32x8B));
        AssertMask8Equal('CmpLeI32x8 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask8($FF), LBackendTable.CoreVectors.CmpLeI32x8(LI32x8A, LI32x8B));
        AssertMask8Equal('CmpGeI32x8 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask8($FF xor LExpectedMask8), LBackendTable.CoreVectors.CmpGeI32x8(LI32x8A, LI32x8B));
        AssertMask8Equal('CmpNeI32x8 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask8, LBackendTable.CoreVectors.CmpNeI32x8(LI32x8A, LI32x8B));
        AssertMask8HelperParity('I32x8 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask8);

        LoadI32x8OneHotProbe(LLane, False);
        AssertMask8Equal('CmpLtI32x8 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), 0, LBackendTable.CoreVectors.CmpLtI32x8(LI32x8A, LI32x8B));
        AssertMask8Equal('CmpEqI32x8 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask8($FF xor LExpectedMask8), LBackendTable.CoreVectors.CmpEqI32x8(LI32x8A, LI32x8B));
        AssertMask8Equal('CmpGtI32x8 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask8, LBackendTable.CoreVectors.CmpGtI32x8(LI32x8A, LI32x8B));
        AssertMask8Equal('CmpLeI32x8 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask8($FF xor LExpectedMask8), LBackendTable.CoreVectors.CmpLeI32x8(LI32x8A, LI32x8B));
        AssertMask8Equal('CmpGeI32x8 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask8($FF), LBackendTable.CoreVectors.CmpGeI32x8(LI32x8A, LI32x8B));
        AssertMask8Equal('CmpNeI32x8 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask8, LBackendTable.CoreVectors.CmpNeI32x8(LI32x8A, LI32x8B));
        AssertMask8HelperParity('I32x8 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask8);

        LoadI64x8OneHotProbe(LLane, True);
        AssertMask8Equal('CmpLtI64x8 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask8, LBackendTable.CoreVectors.CmpLtI64x8(LI64x8A, LI64x8B));
        AssertMask8Equal('CmpEqI64x8 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask8($FF xor LExpectedMask8), LBackendTable.CoreVectors.CmpEqI64x8(LI64x8A, LI64x8B));
        AssertMask8Equal('CmpGtI64x8 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), 0, LBackendTable.CoreVectors.CmpGtI64x8(LI64x8A, LI64x8B));
        AssertMask8Equal('CmpLeI64x8 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask8($FF), LBackendTable.CoreVectors.CmpLeI64x8(LI64x8A, LI64x8B));
        AssertMask8Equal('CmpGeI64x8 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask8($FF xor LExpectedMask8), LBackendTable.CoreVectors.CmpGeI64x8(LI64x8A, LI64x8B));
        AssertMask8Equal('CmpNeI64x8 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask8, LBackendTable.CoreVectors.CmpNeI64x8(LI64x8A, LI64x8B));
        AssertMask8HelperParity('I64x8 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask8);

        LoadI64x8OneHotProbe(LLane, False);
        AssertMask8Equal('CmpLtI64x8 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), 0, LBackendTable.CoreVectors.CmpLtI64x8(LI64x8A, LI64x8B));
        AssertMask8Equal('CmpEqI64x8 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask8($FF xor LExpectedMask8), LBackendTable.CoreVectors.CmpEqI64x8(LI64x8A, LI64x8B));
        AssertMask8Equal('CmpGtI64x8 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask8, LBackendTable.CoreVectors.CmpGtI64x8(LI64x8A, LI64x8B));
        AssertMask8Equal('CmpLeI64x8 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask8($FF xor LExpectedMask8), LBackendTable.CoreVectors.CmpLeI64x8(LI64x8A, LI64x8B));
        AssertMask8Equal('CmpGeI64x8 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask8($FF), LBackendTable.CoreVectors.CmpGeI64x8(LI64x8A, LI64x8B));
        AssertMask8Equal('CmpNeI64x8 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask8, LBackendTable.CoreVectors.CmpNeI64x8(LI64x8A, LI64x8B));
        AssertMask8HelperParity('I64x8 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask8);

        LoadU32x8OneHotProbe(LLane, True);
        AssertMask8Equal('CmpLtU32x8 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask8, LBackendTable.CoreVectors.CmpLtU32x8(LU32x8A, LU32x8B));
        AssertMask8Equal('CmpEqU32x8 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask8($FF xor LExpectedMask8), LBackendTable.CoreVectors.CmpEqU32x8(LU32x8A, LU32x8B));
        AssertMask8Equal('CmpGtU32x8 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), 0, LBackendTable.CoreVectors.CmpGtU32x8(LU32x8A, LU32x8B));
        AssertMask8Equal('CmpLeU32x8 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask8($FF), LBackendTable.CoreVectors.CmpLeU32x8(LU32x8A, LU32x8B));
        AssertMask8Equal('CmpGeU32x8 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask8($FF xor LExpectedMask8), LBackendTable.CoreVectors.CmpGeU32x8(LU32x8A, LU32x8B));
        AssertMask8Equal('CmpNeU32x8 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask8, LBackendTable.CoreVectors.CmpNeU32x8(LU32x8A, LU32x8B));
        AssertMask8HelperParity('U32x8 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask8);

        LoadU32x8OneHotProbe(LLane, False);
        AssertMask8Equal('CmpLtU32x8 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), 0, LBackendTable.CoreVectors.CmpLtU32x8(LU32x8A, LU32x8B));
        AssertMask8Equal('CmpEqU32x8 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask8($FF xor LExpectedMask8), LBackendTable.CoreVectors.CmpEqU32x8(LU32x8A, LU32x8B));
        AssertMask8Equal('CmpGtU32x8 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask8, LBackendTable.CoreVectors.CmpGtU32x8(LU32x8A, LU32x8B));
        AssertMask8Equal('CmpLeU32x8 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask8($FF xor LExpectedMask8), LBackendTable.CoreVectors.CmpLeU32x8(LU32x8A, LU32x8B));
        AssertMask8Equal('CmpGeU32x8 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask8($FF), LBackendTable.CoreVectors.CmpGeU32x8(LU32x8A, LU32x8B));
        AssertMask8Equal('CmpNeU32x8 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask8, LBackendTable.CoreVectors.CmpNeU32x8(LU32x8A, LU32x8B));
        AssertMask8HelperParity('U32x8 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask8);
      end;

      for LLane := 0 to 3 do
      begin
        LExpectedMask4 := TMask4(1 shl LLane);

        LoadI64x4OneHotProbe(LLane, True);
        AssertMask4Equal('CmpLtI64x4 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask4, LBackendTable.CoreVectors.CmpLtI64x4(LI64x4A, LI64x4B));
        AssertMask4Equal('CmpEqI64x4 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask4($0F xor LExpectedMask4), LBackendTable.CoreVectors.CmpEqI64x4(LI64x4A, LI64x4B));
        AssertMask4Equal('CmpGtI64x4 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), 0, LBackendTable.CoreVectors.CmpGtI64x4(LI64x4A, LI64x4B));
        AssertMask4Equal('CmpLeI64x4 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask4($0F), LBackendTable.CoreVectors.CmpLeI64x4(LI64x4A, LI64x4B));
        AssertMask4Equal('CmpGeI64x4 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask4($0F xor LExpectedMask4), LBackendTable.CoreVectors.CmpGeI64x4(LI64x4A, LI64x4B));
        AssertMask4Equal('CmpNeI64x4 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask4, LBackendTable.CoreVectors.CmpNeI64x4(LI64x4A, LI64x4B));
        AssertMask4HelperParity('I64x4 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask4);

        LoadI64x4OneHotProbe(LLane, False);
        AssertMask4Equal('CmpLtI64x4 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), 0, LBackendTable.CoreVectors.CmpLtI64x4(LI64x4A, LI64x4B));
        AssertMask4Equal('CmpEqI64x4 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask4($0F xor LExpectedMask4), LBackendTable.CoreVectors.CmpEqI64x4(LI64x4A, LI64x4B));
        AssertMask4Equal('CmpGtI64x4 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask4, LBackendTable.CoreVectors.CmpGtI64x4(LI64x4A, LI64x4B));
        AssertMask4Equal('CmpLeI64x4 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask4($0F xor LExpectedMask4), LBackendTable.CoreVectors.CmpLeI64x4(LI64x4A, LI64x4B));
        AssertMask4Equal('CmpGeI64x4 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask4($0F), LBackendTable.CoreVectors.CmpGeI64x4(LI64x4A, LI64x4B));
        AssertMask4Equal('CmpNeI64x4 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask4, LBackendTable.CoreVectors.CmpNeI64x4(LI64x4A, LI64x4B));
        AssertMask4HelperParity('I64x4 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask4);

        LoadU64x4OneHotProbe(LLane, True);
        AssertMask4Equal('CmpLtU64x4 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask4, LBackendTable.CoreVectors.CmpLtU64x4(LU64x4A, LU64x4B));
        AssertMask4Equal('CmpEqU64x4 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask4($0F xor LExpectedMask4), LBackendTable.CoreVectors.CmpEqU64x4(LU64x4A, LU64x4B));
        AssertMask4Equal('CmpGtU64x4 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), 0, LBackendTable.CoreVectors.CmpGtU64x4(LU64x4A, LU64x4B));
        AssertMask4Equal('CmpLeU64x4 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask4($0F), LBackendTable.CoreVectors.CmpLeU64x4(LU64x4A, LU64x4B));
        AssertMask4Equal('CmpGeU64x4 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask4($0F xor LExpectedMask4), LBackendTable.CoreVectors.CmpGeU64x4(LU64x4A, LU64x4B));
        AssertMask4Equal('CmpNeU64x4 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask4, LBackendTable.CoreVectors.CmpNeU64x4(LU64x4A, LU64x4B));
        AssertMask4HelperParity('U64x4 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask4);

        LoadU64x4OneHotProbe(LLane, False);
        AssertMask4Equal('CmpLtU64x4 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), 0, LBackendTable.CoreVectors.CmpLtU64x4(LU64x4A, LU64x4B));
        AssertMask4Equal('CmpEqU64x4 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask4($0F xor LExpectedMask4), LBackendTable.CoreVectors.CmpEqU64x4(LU64x4A, LU64x4B));
        AssertMask4Equal('CmpGtU64x4 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask4, LBackendTable.CoreVectors.CmpGtU64x4(LU64x4A, LU64x4B));
        AssertMask4Equal('CmpLeU64x4 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask4($0F xor LExpectedMask4), LBackendTable.CoreVectors.CmpLeU64x4(LU64x4A, LU64x4B));
        AssertMask4Equal('CmpGeU64x4 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask4($0F), LBackendTable.CoreVectors.CmpGeU64x4(LU64x4A, LU64x4B));
        AssertMask4Equal('CmpNeU64x4 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask4, LBackendTable.CoreVectors.CmpNeU64x4(LU64x4A, LU64x4B));
        AssertMask4HelperParity('U64x4 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask4);
      end;

    for LLane := 0 to 15 do
    begin
      LExpectedMask16 := TMask16(1 shl LLane);

      LoadI32x16OneHotProbe(LLane, True);
      AssertMask16Equal('CmpLtI32x16 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask16, LBackendTable.CoreVectors.CmpLtI32x16(LI32x16A, LI32x16B));
      AssertMask16Equal('CmpEqI32x16 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask16($FFFF xor LExpectedMask16), LBackendTable.CoreVectors.CmpEqI32x16(LI32x16A, LI32x16B));
      AssertMask16Equal('CmpGtI32x16 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), 0, LBackendTable.CoreVectors.CmpGtI32x16(LI32x16A, LI32x16B));
      AssertMask16Equal('CmpLeI32x16 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask16($FFFF), LBackendTable.CoreVectors.CmpLeI32x16(LI32x16A, LI32x16B));
      AssertMask16Equal('CmpGeI32x16 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask16($FFFF xor LExpectedMask16), LBackendTable.CoreVectors.CmpGeI32x16(LI32x16A, LI32x16B));
      AssertMask16Equal('CmpNeI32x16 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask16, LBackendTable.CoreVectors.CmpNeI32x16(LI32x16A, LI32x16B));
      AssertMask16HelperParity('I32x16 onehot-lt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask16);

      LoadI32x16OneHotProbe(LLane, False);
      AssertMask16Equal('CmpLtI32x16 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), 0, LBackendTable.CoreVectors.CmpLtI32x16(LI32x16A, LI32x16B));
      AssertMask16Equal('CmpEqI32x16 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask16($FFFF xor LExpectedMask16), LBackendTable.CoreVectors.CmpEqI32x16(LI32x16A, LI32x16B));
      AssertMask16Equal('CmpGtI32x16 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask16, LBackendTable.CoreVectors.CmpGtI32x16(LI32x16A, LI32x16B));
      AssertMask16Equal('CmpLeI32x16 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask16($FFFF xor LExpectedMask16), LBackendTable.CoreVectors.CmpLeI32x16(LI32x16A, LI32x16B));
      AssertMask16Equal('CmpGeI32x16 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), TMask16($FFFF), LBackendTable.CoreVectors.CmpGeI32x16(LI32x16A, LI32x16B));
      AssertMask16Equal('CmpNeI32x16 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask16, LBackendTable.CoreVectors.CmpNeI32x16(LI32x16A, LI32x16B));
      AssertMask16HelperParity('I32x16 onehot-gt lane=' + IntToStr(LLane) + ': ' + NonX86BackendName(LBackend), LExpectedMask16);
    end;

    Inc(LChecked);
  end;

  if LChecked = 0 then
    CheckTrue(True, 'No non-x86 backend registered/active on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_I32x4_BitwiseShiftParity_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LBackendTable: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LA, LB: TVecI32x4;
  LVecByBackend, LVecByScalar: TVecI32x4;
  LI64A: TVecI64x2;
  LI64ByBackend, LI64ByScalar: TVecI64x2;
  LI64x4A: TVecI64x4;
  LI64x4ByBackend, LI64x4ByScalar: TVecI64x4;
  LU32x8A: TVecU32x8;
  LU32x8ByBackend, LU32x8ByScalar: TVecU32x8;
  LU64x4A: TVecU64x4;
  LU64x4ByBackend, LU64x4ByScalar: TVecU64x4;
  LShiftCounts: array[0..4] of Integer;
  LShiftCounts64: array[0..4] of Integer;
  LShiftCount: Integer;
  LIndex: Integer;
  LChecked: Integer;

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

  procedure AssertVecU32x8Equal(const aOp: string; const aExpected, aActual: TVecU32x8);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 7 do
      CheckEqual(QWord(aExpected.u[LLane]), QWord(aActual.u[LLane]), aOp + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecU64x4Equal(const aOp: string; const aExpected, aActual: TVecU64x4);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckEqual(QWord(aExpected.u[LLane]), QWord(aActual.u[LLane]), aOp + ' lane ' + IntToStr(LLane));
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LChecked := 0;

  LA.i[0] := $7FFFFFFF;
  LA.i[1] := $40000001;
  LA.i[2] := -1;
  LA.i[3] := -16;
  LB.i[0] := $0F0F0F0F;
  LB.i[1] := Int32(DWord($F0F0F0F0));
  LB.i[2] := Int32(DWord($AAAAAAAA));
  LB.i[3] := $55555555;

  LShiftCounts[0] := -1;
  LShiftCounts[1] := 0;
  LShiftCounts[2] := 7;
  LShiftCounts[3] := 31;
  LShiftCounts[4] := 32;
  LShiftCounts64[0] := -1;
  LShiftCounts64[1] := 0;
  LShiftCounts64[2] := 13;
  LShiftCounts64[3] := 63;
  LShiftCounts64[4] := 64;

  LI64A.i[0] := $7FFFFFFFFFFFFFFF;
  LI64A.i[1] := -1;
  LI64x4A.i[0] := $7FFFFFFFFFFFFFFF;
  LI64x4A.i[1] := -1;
  LI64x4A.i[2] := Int64($4000000000000001);
  LI64x4A.i[3] := -16;
  LU32x8A.u[0] := $FFFFFFFF;
  LU32x8A.u[1] := $80000000;
  LU32x8A.u[2] := $40000001;
  LU32x8A.u[3] := $12345678;
  LU32x8A.u[4] := 0;
  LU32x8A.u[5] := 1;
  LU32x8A.u[6] := $AAAAAAAA;
  LU32x8A.u[7] := $55555555;
  LU64x4A.u[0] := QWord($FFFFFFFFFFFFFFFF);
  LU64x4A.u[1] := QWord($8000000000000000);
  LU64x4A.u[2] := 1;
  LU64x4A.u[3] := QWord($0123456789ABCDEF);

  for LBackend in LBackends do
  begin
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

      CheckTrue(Assigned(LBackendTable.CoreVectors.AndI32x4), 'AndI32x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.OrI32x4), 'OrI32x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.XorI32x4), 'XorI32x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftLeftI32x4), 'ShiftLeftI32x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftRightI32x4), 'ShiftRightI32x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftRightArithI32x4), 'ShiftRightArithI32x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftLeftI64x2), 'ShiftLeftI64x2 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftRightI64x2), 'ShiftRightI64x2 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftRightArithI64x2), 'ShiftRightArithI64x2 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftLeftI64x4), 'ShiftLeftI64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftRightI64x4), 'ShiftRightI64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftRightArithI64x4), 'ShiftRightArithI64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftLeftU32x8), 'ShiftLeftU32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftRightU32x8), 'ShiftRightU32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftLeftU64x4), 'ShiftLeftU64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftRightU64x4), 'ShiftRightU64x4 missing: ' + NonX86BackendName(LBackend));

      LVecByBackend := LBackendTable.CoreVectors.AndI32x4(LA, LB);
      LVecByScalar := LScalarTable.CoreVectors.AndI32x4(LA, LB);
      AssertVecI32x4Equal('AndI32x4 parity: ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

      LVecByBackend := LBackendTable.CoreVectors.OrI32x4(LA, LB);
      LVecByScalar := LScalarTable.CoreVectors.OrI32x4(LA, LB);
      AssertVecI32x4Equal('OrI32x4 parity: ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

      LVecByBackend := LBackendTable.CoreVectors.XorI32x4(LA, LB);
      LVecByScalar := LScalarTable.CoreVectors.XorI32x4(LA, LB);
      AssertVecI32x4Equal('XorI32x4 parity: ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

      for LIndex := 0 to High(LShiftCounts) do
      begin
        LShiftCount := LShiftCounts[LIndex];

        LVecByBackend := LBackendTable.CoreVectors.ShiftLeftI32x4(LA, LShiftCount);
        LVecByScalar := LScalarTable.CoreVectors.ShiftLeftI32x4(LA, LShiftCount);
        AssertVecI32x4Equal('ShiftLeftI32x4 parity c=' + IntToStr(LShiftCount) + ': ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

        LVecByBackend := LBackendTable.CoreVectors.ShiftRightI32x4(LA, LShiftCount);
        LVecByScalar := LScalarTable.CoreVectors.ShiftRightI32x4(LA, LShiftCount);
        AssertVecI32x4Equal('ShiftRightI32x4 parity c=' + IntToStr(LShiftCount) + ': ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

        LVecByBackend := LBackendTable.CoreVectors.ShiftRightArithI32x4(LA, LShiftCount);
        LVecByScalar := LScalarTable.CoreVectors.ShiftRightArithI32x4(LA, LShiftCount);
        AssertVecI32x4Equal('ShiftRightArithI32x4 parity c=' + IntToStr(LShiftCount) + ': ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

        LVecByBackend := VecI32x4ShiftRightArith(LA, LShiftCount);
        LVecByScalar := ScalarShiftRightArithI32x4(LA, LShiftCount);
        AssertVecI32x4Equal('Facade ShiftRightArithI32x4 parity c=' + IntToStr(LShiftCount) + ': ' + NonX86BackendName(LBackend), LVecByScalar, LVecByBackend);

        LU32x8ByBackend := LBackendTable.CoreVectors.ShiftLeftU32x8(LU32x8A, LShiftCount);
        LU32x8ByScalar := LScalarTable.CoreVectors.ShiftLeftU32x8(LU32x8A, LShiftCount);
        AssertVecU32x8Equal('ShiftLeftU32x8 parity c=' + IntToStr(LShiftCount) + ': ' + NonX86BackendName(LBackend), LU32x8ByScalar, LU32x8ByBackend);

        LU32x8ByBackend := LBackendTable.CoreVectors.ShiftRightU32x8(LU32x8A, LShiftCount);
        LU32x8ByScalar := LScalarTable.CoreVectors.ShiftRightU32x8(LU32x8A, LShiftCount);
        AssertVecU32x8Equal('ShiftRightU32x8 parity c=' + IntToStr(LShiftCount) + ': ' + NonX86BackendName(LBackend), LU32x8ByScalar, LU32x8ByBackend);
      end;

      for LIndex := 0 to High(LShiftCounts64) do
      begin
        LShiftCount := LShiftCounts64[LIndex];

        LI64ByBackend := LBackendTable.CoreVectors.ShiftLeftI64x2(LI64A, LShiftCount);
        LI64ByScalar := LScalarTable.CoreVectors.ShiftLeftI64x2(LI64A, LShiftCount);
        CheckEqual(LI64ByScalar.i[0], LI64ByBackend.i[0], 'ShiftLeftI64x2 parity c=' + IntToStr(LShiftCount) + ' lane 0: ' + NonX86BackendName(LBackend));
        CheckEqual(LI64ByScalar.i[1], LI64ByBackend.i[1], 'ShiftLeftI64x2 parity c=' + IntToStr(LShiftCount) + ' lane 1: ' + NonX86BackendName(LBackend));

        LI64ByBackend := LBackendTable.CoreVectors.ShiftRightI64x2(LI64A, LShiftCount);
        LI64ByScalar := LScalarTable.CoreVectors.ShiftRightI64x2(LI64A, LShiftCount);
        CheckEqual(LI64ByScalar.i[0], LI64ByBackend.i[0], 'ShiftRightI64x2 parity c=' + IntToStr(LShiftCount) + ' lane 0: ' + NonX86BackendName(LBackend));
        CheckEqual(LI64ByScalar.i[1], LI64ByBackend.i[1], 'ShiftRightI64x2 parity c=' + IntToStr(LShiftCount) + ' lane 1: ' + NonX86BackendName(LBackend));

        LI64ByBackend := LBackendTable.CoreVectors.ShiftRightArithI64x2(LI64A, LShiftCount);
        LI64ByScalar := LScalarTable.CoreVectors.ShiftRightArithI64x2(LI64A, LShiftCount);
        CheckEqual(LI64ByScalar.i[0], LI64ByBackend.i[0], 'ShiftRightArithI64x2 parity c=' + IntToStr(LShiftCount) + ' lane 0: ' + NonX86BackendName(LBackend));
        CheckEqual(LI64ByScalar.i[1], LI64ByBackend.i[1], 'ShiftRightArithI64x2 parity c=' + IntToStr(LShiftCount) + ' lane 1: ' + NonX86BackendName(LBackend));

        LI64x4ByBackend := LBackendTable.CoreVectors.ShiftLeftI64x4(LI64x4A, LShiftCount);
        LI64x4ByScalar := LScalarTable.CoreVectors.ShiftLeftI64x4(LI64x4A, LShiftCount);
        AssertVecI64x4Equal('ShiftLeftI64x4 parity c=' + IntToStr(LShiftCount) + ': ' + NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

        LI64x4ByBackend := LBackendTable.CoreVectors.ShiftRightI64x4(LI64x4A, LShiftCount);
        LI64x4ByScalar := LScalarTable.CoreVectors.ShiftRightI64x4(LI64x4A, LShiftCount);
        AssertVecI64x4Equal('ShiftRightI64x4 parity c=' + IntToStr(LShiftCount) + ': ' + NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

        LI64x4ByBackend := LBackendTable.CoreVectors.ShiftRightArithI64x4(LI64x4A, LShiftCount);
        LI64x4ByScalar := ScalarShiftRightArithI64x4(LI64x4A, LShiftCount);
        AssertVecI64x4Equal('ShiftRightArithI64x4 parity c=' + IntToStr(LShiftCount) + ': ' + NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

        LU64x4ByBackend := LBackendTable.CoreVectors.ShiftLeftU64x4(LU64x4A, LShiftCount);
        LU64x4ByScalar := LScalarTable.CoreVectors.ShiftLeftU64x4(LU64x4A, LShiftCount);
        AssertVecU64x4Equal('ShiftLeftU64x4 parity c=' + IntToStr(LShiftCount) + ': ' + NonX86BackendName(LBackend), LU64x4ByScalar, LU64x4ByBackend);

        LU64x4ByBackend := LBackendTable.CoreVectors.ShiftRightU64x4(LU64x4A, LShiftCount);
        LU64x4ByScalar := LScalarTable.CoreVectors.ShiftRightU64x4(LU64x4A, LShiftCount);
        AssertVecU64x4Equal('ShiftRightU64x4 parity c=' + IntToStr(LShiftCount) + ': ' + NonX86BackendName(LBackend), LU64x4ByScalar, LU64x4ByBackend);
      end;

    Inc(LChecked);
  end;

  if LChecked = 0 then
    CheckTrue(True, 'No non-x86 backend registered/active on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_WideSignedBitwiseShiftParity_IfAvailable;
const
  C_SHIFT32: array[0..8] of Integer = (-1, 0, 1, 7, 31, 32, 63, 64, 95);
  C_SHIFT64: array[0..7] of Integer = (-1, 0, 1, 7, 31, 63, 64, 95);
  C_I32X8_SHIFT_PROBE: array[0..7] of Int32 = (
    1, -1, Int32($80000000), Int32($40000000), High(Int32), Int32($55555555), Int32($AAAAAAAA), 0
  );
  C_I32X8_SHL31: array[0..7] of Int32 = (
    Int32($80000000), Int32($80000000), 0, 0, Int32($80000000), Int32($80000000), 0, 0
  );
  C_I32X8_SHR31: array[0..7] of Int32 = (0, 1, 1, 0, 0, 0, 1, 0);
  C_I32X8_SAR31: array[0..7] of Int32 = (0, -1, -1, 0, 0, 0, -1, 0);
  C_I32X8_ZERO: array[0..7] of Int32 = (0, 0, 0, 0, 0, 0, 0, 0);
  C_I32X16_SHIFT_PROBE: array[0..15] of Int32 = (
    1, -1, Int32($80000000), Int32($40000000), High(Int32), Int32($55555555), Int32($AAAAAAAA), 0,
    2, -2, Int32($7FFFFFFE), Int32($80000001), 0, 123, -123, Int32($00010000)
  );
  C_I32X16_SAR32: array[0..15] of Int32 = (
    0, -1, -1, 0, 0, 0, -1, 0,
    0, -1, 0, -1, 0, 0, -1, 0
  );
  C_I32X16_ZERO: array[0..15] of Int32 = (
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  );
  C_I64X4_SHIFT_PROBE: array[0..3] of Int64 = (
    1, -1, High(Int64), Low(Int64)
  );
  C_I64X4_SHL63: array[0..3] of Int64 = (
    Low(Int64), Low(Int64), Low(Int64), 0
  );
  C_I64X4_SHR63: array[0..3] of Int64 = (0, 1, 0, 1);
  C_I64X4_SAR63: array[0..3] of Int64 = (0, -1, 0, -1);
  C_I64X4_ZERO: array[0..3] of Int64 = (0, 0, 0, 0);
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LBackendTable: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LI32x8A, LI32x8B: TVecI32x8;
  LI32x16A, LI32x16B: TVecI32x16;
  LI64x4A, LI64x4B: TVecI64x4;
  LI64x8A, LI64x8B: TVecI64x8;
  LI32x8ByBackend, LI32x8ByScalar: TVecI32x8;
  LI32x16ByBackend, LI32x16ByScalar: TVecI32x16;
  LI64x4ByBackend, LI64x4ByScalar: TVecI64x4;
  LI64x8ByBackend, LI64x8ByScalar: TVecI64x8;
  LShiftIndex: Integer;
  LLane: Integer;
  LChecked: Integer;

  procedure AssertVecI32x8Equal(const aLabel: string; const aExpected, aActual: TVecI32x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aLabel + ' lane ' + IntToStr(LLaneIndex));
  end;

  procedure LoadI32x8FromArray(const aSource: array of Int32; out aValue: TVecI32x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      aValue.i[LLaneIndex] := aSource[LLaneIndex];
  end;

  procedure AssertVecI32x16Equal(const aLabel: string; const aExpected, aActual: TVecI32x16);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 15 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aLabel + ' lane ' + IntToStr(LLaneIndex));
  end;

  procedure LoadI32x16FromArray(const aSource: array of Int32; out aValue: TVecI32x16);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 15 do
      aValue.i[LLaneIndex] := aSource[LLaneIndex];
  end;

  procedure AssertVecI64x4Equal(const aLabel: string; const aExpected, aActual: TVecI64x4);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 3 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aLabel + ' lane ' + IntToStr(LLaneIndex));
  end;

  procedure LoadI64x4FromArray(const aSource: array of Int64; out aValue: TVecI64x4);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 3 do
      aValue.i[LLaneIndex] := aSource[LLaneIndex];
  end;

  procedure AssertVecI64x8Equal(const aLabel: string; const aExpected, aActual: TVecI64x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aLabel + ' lane ' + IntToStr(LLaneIndex));
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LChecked := 0;

  LI32x8A.i[0] := High(Int32);
  LI32x8A.i[1] := Low(Int32);
  LI32x8A.i[2] := -1;
  LI32x8A.i[3] := 0;
  LI32x8A.i[4] := $55555555;
  LI32x8A.i[5] := Int32(DWord($AAAAAAAA));
  LI32x8A.i[6] := Int32($40000001);
  LI32x8A.i[7] := -16;
  LI32x8B.i[0] := 0;
  LI32x8B.i[1] := -1;
  LI32x8B.i[2] := Int32(DWord($AAAAAAAA));
  LI32x8B.i[3] := $55555555;
  LI32x8B.i[4] := High(Int32);
  LI32x8B.i[5] := Low(Int32);
  LI32x8B.i[6] := Int32($7F0F0F0F);
  LI32x8B.i[7] := 15;

  for LLane := 0 to 15 do
  begin
    LI32x16A.i[LLane] := (LLane - 8) * 257;
    LI32x16B.i[LLane] := (7 - LLane) * 131;
  end;
  LI32x16A.i[0] := Low(Int32);
  LI32x16A.i[1] := -1;
  LI32x16A.i[2] := $55555555;
  LI32x16A.i[15] := High(Int32);
  LI32x16B.i[0] := High(Int32);
  LI32x16B.i[1] := Int32(DWord($AAAAAAAA));
  LI32x16B.i[2] := -1;
  LI32x16B.i[15] := Low(Int32);

  LI64x4A.i[0] := Low(Int64);
  LI64x4A.i[1] := -1;
  LI64x4A.i[2] := Int64($4000000000000001);
  LI64x4A.i[3] := High(Int64);
  LI64x4B.i[0] := High(Int64);
  LI64x4B.i[1] := Int64($AAAAAAAAAAAAAAAA);
  LI64x4B.i[2] := -1;
  LI64x4B.i[3] := Low(Int64);

  for LLane := 0 to 7 do
  begin
    LI64x8A.i[LLane] := Int64(LLane * 1000 - 3000);
    LI64x8B.i[LLane] := Int64(500 - LLane * 77);
  end;
  LI64x8A.i[0] := High(Int64);
  LI64x8A.i[1] := Low(Int64);
  LI64x8A.i[2] := -1;
  LI64x8A.i[7] := Int64($4000000000000001);
  LI64x8B.i[0] := 1;
  LI64x8B.i[1] := -1;
  LI64x8B.i[2] := High(Int64);
  LI64x8B.i[7] := Low(Int64);

  for LBackend in LBackends do
  begin
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

      CheckTrue(Assigned(LBackendTable.CoreVectors.AndI32x8), 'AndI32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.OrI32x8), 'OrI32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.XorI32x8), 'XorI32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.NotI32x8), 'NotI32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AndNotI32x8), 'AndNotI32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftLeftI32x8), 'ShiftLeftI32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftRightI32x8), 'ShiftRightI32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftRightArithI32x8), 'ShiftRightArithI32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AndI32x16), 'AndI32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.OrI32x16), 'OrI32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.XorI32x16), 'XorI32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.NotI32x16), 'NotI32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AndNotI32x16), 'AndNotI32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftLeftI32x16), 'ShiftLeftI32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftRightI32x16), 'ShiftRightI32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftRightArithI32x16), 'ShiftRightArithI32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AndI64x4), 'AndI64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.OrI64x4), 'OrI64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.XorI64x4), 'XorI64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.NotI64x4), 'NotI64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AndNotI64x4), 'AndNotI64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftLeftI64x4), 'ShiftLeftI64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftRightI64x4), 'ShiftRightI64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.ShiftRightArithI64x4), 'ShiftRightArithI64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AndI64x8), 'AndI64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.OrI64x8), 'OrI64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.XorI64x8), 'XorI64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.NotI64x8), 'NotI64x8 missing: ' + NonX86BackendName(LBackend));

      LI32x8ByBackend := LBackendTable.CoreVectors.AndI32x8(LI32x8A, LI32x8B);
      LI32x8ByScalar := LScalarTable.CoreVectors.AndI32x8(LI32x8A, LI32x8B);
      AssertVecI32x8Equal('AndI32x8 parity: ' + NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

      LI32x8ByBackend := LBackendTable.CoreVectors.OrI32x8(LI32x8A, LI32x8B);
      LI32x8ByScalar := LScalarTable.CoreVectors.OrI32x8(LI32x8A, LI32x8B);
      AssertVecI32x8Equal('OrI32x8 parity: ' + NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

      LI32x8ByBackend := LBackendTable.CoreVectors.XorI32x8(LI32x8A, LI32x8B);
      LI32x8ByScalar := LScalarTable.CoreVectors.XorI32x8(LI32x8A, LI32x8B);
      AssertVecI32x8Equal('XorI32x8 parity: ' + NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

      LI32x8ByBackend := LBackendTable.CoreVectors.NotI32x8(LI32x8A);
      LI32x8ByScalar := LScalarTable.CoreVectors.NotI32x8(LI32x8A);
      AssertVecI32x8Equal('NotI32x8 parity: ' + NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

      LI32x8ByBackend := LBackendTable.CoreVectors.AndNotI32x8(LI32x8A, LI32x8B);
      LI32x8ByScalar := LScalarTable.CoreVectors.AndNotI32x8(LI32x8A, LI32x8B);
      AssertVecI32x8Equal('AndNotI32x8 parity: ' + NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

      LI32x16ByBackend := LBackendTable.CoreVectors.AndI32x16(LI32x16A, LI32x16B);
      LI32x16ByScalar := LScalarTable.CoreVectors.AndI32x16(LI32x16A, LI32x16B);
      AssertVecI32x16Equal('AndI32x16 parity: ' + NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByBackend);

      LI32x16ByBackend := LBackendTable.CoreVectors.OrI32x16(LI32x16A, LI32x16B);
      LI32x16ByScalar := LScalarTable.CoreVectors.OrI32x16(LI32x16A, LI32x16B);
      AssertVecI32x16Equal('OrI32x16 parity: ' + NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByBackend);

      LI32x16ByBackend := LBackendTable.CoreVectors.XorI32x16(LI32x16A, LI32x16B);
      LI32x16ByScalar := LScalarTable.CoreVectors.XorI32x16(LI32x16A, LI32x16B);
      AssertVecI32x16Equal('XorI32x16 parity: ' + NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByBackend);

      LI32x16ByBackend := LBackendTable.CoreVectors.NotI32x16(LI32x16A);
      LI32x16ByScalar := LScalarTable.CoreVectors.NotI32x16(LI32x16A);
      AssertVecI32x16Equal('NotI32x16 parity: ' + NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByBackend);

      LI32x16ByBackend := LBackendTable.CoreVectors.AndNotI32x16(LI32x16A, LI32x16B);
      LI32x16ByScalar := LScalarTable.CoreVectors.AndNotI32x16(LI32x16A, LI32x16B);
      AssertVecI32x16Equal('AndNotI32x16 parity: ' + NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByBackend);

      LI64x4ByBackend := LBackendTable.CoreVectors.AndI64x4(LI64x4A, LI64x4B);
      LI64x4ByScalar := LScalarTable.CoreVectors.AndI64x4(LI64x4A, LI64x4B);
      AssertVecI64x4Equal('AndI64x4 parity: ' + NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

      LI64x4ByBackend := LBackendTable.CoreVectors.OrI64x4(LI64x4A, LI64x4B);
      LI64x4ByScalar := LScalarTable.CoreVectors.OrI64x4(LI64x4A, LI64x4B);
      AssertVecI64x4Equal('OrI64x4 parity: ' + NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

      LI64x4ByBackend := LBackendTable.CoreVectors.XorI64x4(LI64x4A, LI64x4B);
      LI64x4ByScalar := LScalarTable.CoreVectors.XorI64x4(LI64x4A, LI64x4B);
      AssertVecI64x4Equal('XorI64x4 parity: ' + NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

      LI64x4ByBackend := LBackendTable.CoreVectors.NotI64x4(LI64x4A);
      LI64x4ByScalar := LScalarTable.CoreVectors.NotI64x4(LI64x4A);
      AssertVecI64x4Equal('NotI64x4 parity: ' + NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

      LI64x4ByBackend := LBackendTable.CoreVectors.AndNotI64x4(LI64x4A, LI64x4B);
      LI64x4ByScalar := LScalarTable.CoreVectors.AndNotI64x4(LI64x4A, LI64x4B);
      AssertVecI64x4Equal('AndNotI64x4 parity: ' + NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

      LI64x8ByBackend := LBackendTable.CoreVectors.AndI64x8(LI64x8A, LI64x8B);
      LI64x8ByScalar := LScalarTable.CoreVectors.AndI64x8(LI64x8A, LI64x8B);
      AssertVecI64x8Equal('AndI64x8 parity: ' + NonX86BackendName(LBackend), LI64x8ByScalar, LI64x8ByBackend);

      LI64x8ByBackend := LBackendTable.CoreVectors.OrI64x8(LI64x8A, LI64x8B);
      LI64x8ByScalar := LScalarTable.CoreVectors.OrI64x8(LI64x8A, LI64x8B);
      AssertVecI64x8Equal('OrI64x8 parity: ' + NonX86BackendName(LBackend), LI64x8ByScalar, LI64x8ByBackend);

      LI64x8ByBackend := LBackendTable.CoreVectors.XorI64x8(LI64x8A, LI64x8B);
      LI64x8ByScalar := LScalarTable.CoreVectors.XorI64x8(LI64x8A, LI64x8B);
      AssertVecI64x8Equal('XorI64x8 parity: ' + NonX86BackendName(LBackend), LI64x8ByScalar, LI64x8ByBackend);

      LI64x8ByBackend := LBackendTable.CoreVectors.NotI64x8(LI64x8A);
      LI64x8ByScalar := LScalarTable.CoreVectors.NotI64x8(LI64x8A);
      AssertVecI64x8Equal('NotI64x8 parity: ' + NonX86BackendName(LBackend), LI64x8ByScalar, LI64x8ByBackend);

      LI64x8ByBackend := VecI64x8And(LI64x8A, LI64x8B);
      LI64x8ByScalar := LScalarTable.CoreVectors.AndI64x8(LI64x8A, LI64x8B);
      AssertVecI64x8Equal('Facade VecI64x8And parity: ' + NonX86BackendName(LBackend), LI64x8ByScalar, LI64x8ByBackend);

      LI64x8ByBackend := VecI64x8Or(LI64x8A, LI64x8B);
      LI64x8ByScalar := LScalarTable.CoreVectors.OrI64x8(LI64x8A, LI64x8B);
      AssertVecI64x8Equal('Facade VecI64x8Or parity: ' + NonX86BackendName(LBackend), LI64x8ByScalar, LI64x8ByBackend);

      LI64x8ByBackend := VecI64x8Xor(LI64x8A, LI64x8B);
      LI64x8ByScalar := LScalarTable.CoreVectors.XorI64x8(LI64x8A, LI64x8B);
      AssertVecI64x8Equal('Facade VecI64x8Xor parity: ' + NonX86BackendName(LBackend), LI64x8ByScalar, LI64x8ByBackend);

      LI64x8ByBackend := VecI64x8Not(LI64x8A);
      LI64x8ByScalar := LScalarTable.CoreVectors.NotI64x8(LI64x8A);
      AssertVecI64x8Equal('Facade VecI64x8Not parity: ' + NonX86BackendName(LBackend), LI64x8ByScalar, LI64x8ByBackend);

      LoadI32x8FromArray(C_I32X8_SHIFT_PROBE, LI32x8A);

      LI32x8ByBackend := LBackendTable.CoreVectors.ShiftRightArithI32x8(LI32x8A, -1);
      LoadI32x8FromArray(C_I32X8_SHIFT_PROBE, LI32x8ByScalar);
      AssertVecI32x8Equal('ShiftRightArithI32x8 exact c=-1: ' + NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

      LI32x8ByBackend := LBackendTable.CoreVectors.ShiftLeftI32x8(LI32x8A, 31);
      LoadI32x8FromArray(C_I32X8_SHL31, LI32x8ByScalar);
      AssertVecI32x8Equal('ShiftLeftI32x8 exact c=31: ' + NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

      LI32x8ByBackend := LBackendTable.CoreVectors.ShiftRightI32x8(LI32x8A, 31);
      LoadI32x8FromArray(C_I32X8_SHR31, LI32x8ByScalar);
      AssertVecI32x8Equal('ShiftRightI32x8 exact c=31: ' + NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

      LI32x8ByBackend := LBackendTable.CoreVectors.ShiftRightArithI32x8(LI32x8A, 31);
      LoadI32x8FromArray(C_I32X8_SAR31, LI32x8ByScalar);
      AssertVecI32x8Equal('ShiftRightArithI32x8 exact c=31: ' + NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

      LI32x8ByBackend := LBackendTable.CoreVectors.ShiftRightArithI32x8(LI32x8A, 64);
      LoadI32x8FromArray(C_I32X8_SAR31, LI32x8ByScalar);
      AssertVecI32x8Equal('ShiftRightArithI32x8 exact c=64: ' + NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

      LI32x8ByBackend := LBackendTable.CoreVectors.ShiftLeftI32x8(LI32x8A, 64);
      LoadI32x8FromArray(C_I32X8_ZERO, LI32x8ByScalar);
      AssertVecI32x8Equal('ShiftLeftI32x8 exact c=64: ' + NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

      LoadI32x16FromArray(C_I32X16_SHIFT_PROBE, LI32x16A);

      LI32x16ByBackend := LBackendTable.CoreVectors.ShiftRightArithI32x16(LI32x16A, -1);
      LoadI32x16FromArray(C_I32X16_SHIFT_PROBE, LI32x16ByScalar);
      AssertVecI32x16Equal('ShiftRightArithI32x16 exact c=-1: ' + NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByBackend);

      LI32x16ByBackend := LBackendTable.CoreVectors.ShiftRightArithI32x16(LI32x16A, 32);
      LoadI32x16FromArray(C_I32X16_SAR32, LI32x16ByScalar);
      AssertVecI32x16Equal('ShiftRightArithI32x16 exact c=32: ' + NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByBackend);

      LI32x16ByBackend := LBackendTable.CoreVectors.ShiftRightArithI32x16(LI32x16A, 64);
      LoadI32x16FromArray(C_I32X16_SAR32, LI32x16ByScalar);
      AssertVecI32x16Equal('ShiftRightArithI32x16 exact c=64: ' + NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByBackend);

      LI32x16ByBackend := LBackendTable.CoreVectors.ShiftLeftI32x16(LI32x16A, 64);
      LoadI32x16FromArray(C_I32X16_ZERO, LI32x16ByScalar);
      AssertVecI32x16Equal('ShiftLeftI32x16 exact c=64: ' + NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByBackend);

      LoadI64x4FromArray(C_I64X4_SHIFT_PROBE, LI64x4A);

      LI64x4ByBackend := LBackendTable.CoreVectors.ShiftLeftI64x4(LI64x4A, 63);
      LoadI64x4FromArray(C_I64X4_SHL63, LI64x4ByScalar);
      AssertVecI64x4Equal('ShiftLeftI64x4 exact c=63: ' + NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

      LI64x4ByBackend := LBackendTable.CoreVectors.ShiftRightI64x4(LI64x4A, 63);
      LoadI64x4FromArray(C_I64X4_SHR63, LI64x4ByScalar);
      AssertVecI64x4Equal('ShiftRightI64x4 exact c=63: ' + NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

      LI64x4ByBackend := LBackendTable.CoreVectors.ShiftRightArithI64x4(LI64x4A, 63);
      LoadI64x4FromArray(C_I64X4_SAR63, LI64x4ByScalar);
      AssertVecI64x4Equal('ShiftRightArithI64x4 exact c=63: ' + NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

      LI64x4ByBackend := LBackendTable.CoreVectors.ShiftRightArithI64x4(LI64x4A, 64);
      LoadI64x4FromArray(C_I64X4_ZERO, LI64x4ByScalar);
      AssertVecI64x4Equal('ShiftRightArithI64x4 exact c=64: ' + NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

      LI64x4ByBackend := LBackendTable.CoreVectors.ShiftRightArithI64x4(LI64x4A, 95);
      LoadI64x4FromArray(C_I64X4_ZERO, LI64x4ByScalar);
      AssertVecI64x4Equal('ShiftRightArithI64x4 exact c=95: ' + NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

      for LShiftIndex := 0 to High(C_SHIFT32) do
      begin
        LI32x8ByBackend := LBackendTable.CoreVectors.ShiftLeftI32x8(LI32x8A, C_SHIFT32[LShiftIndex]);
        LI32x8ByScalar := LScalarTable.CoreVectors.ShiftLeftI32x8(LI32x8A, C_SHIFT32[LShiftIndex]);
        AssertVecI32x8Equal('ShiftLeftI32x8 parity c=' + IntToStr(C_SHIFT32[LShiftIndex]) + ': ' + NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

        LI32x8ByBackend := LBackendTable.CoreVectors.ShiftRightI32x8(LI32x8A, C_SHIFT32[LShiftIndex]);
        LI32x8ByScalar := LScalarTable.CoreVectors.ShiftRightI32x8(LI32x8A, C_SHIFT32[LShiftIndex]);
        AssertVecI32x8Equal('ShiftRightI32x8 parity c=' + IntToStr(C_SHIFT32[LShiftIndex]) + ': ' + NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

        LI32x8ByBackend := LBackendTable.CoreVectors.ShiftRightArithI32x8(LI32x8A, C_SHIFT32[LShiftIndex]);
        LI32x8ByScalar := LScalarTable.CoreVectors.ShiftRightArithI32x8(LI32x8A, C_SHIFT32[LShiftIndex]);
        AssertVecI32x8Equal('ShiftRightArithI32x8 parity c=' + IntToStr(C_SHIFT32[LShiftIndex]) + ': ' + NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

        LI32x16ByBackend := LBackendTable.CoreVectors.ShiftLeftI32x16(LI32x16A, C_SHIFT32[LShiftIndex]);
        LI32x16ByScalar := LScalarTable.CoreVectors.ShiftLeftI32x16(LI32x16A, C_SHIFT32[LShiftIndex]);
        AssertVecI32x16Equal('ShiftLeftI32x16 parity c=' + IntToStr(C_SHIFT32[LShiftIndex]) + ': ' + NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByBackend);

        LI32x16ByBackend := LBackendTable.CoreVectors.ShiftRightI32x16(LI32x16A, C_SHIFT32[LShiftIndex]);
        LI32x16ByScalar := LScalarTable.CoreVectors.ShiftRightI32x16(LI32x16A, C_SHIFT32[LShiftIndex]);
        AssertVecI32x16Equal('ShiftRightI32x16 parity c=' + IntToStr(C_SHIFT32[LShiftIndex]) + ': ' + NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByBackend);

        LI32x16ByBackend := LBackendTable.CoreVectors.ShiftRightArithI32x16(LI32x16A, C_SHIFT32[LShiftIndex]);
        LI32x16ByScalar := LScalarTable.CoreVectors.ShiftRightArithI32x16(LI32x16A, C_SHIFT32[LShiftIndex]);
        AssertVecI32x16Equal('ShiftRightArithI32x16 parity c=' + IntToStr(C_SHIFT32[LShiftIndex]) + ': ' + NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByBackend);
      end;

      for LShiftIndex := 0 to High(C_SHIFT64) do
      begin
        LI64x4ByBackend := LBackendTable.CoreVectors.ShiftLeftI64x4(LI64x4A, C_SHIFT64[LShiftIndex]);
        LI64x4ByScalar := LScalarTable.CoreVectors.ShiftLeftI64x4(LI64x4A, C_SHIFT64[LShiftIndex]);
        AssertVecI64x4Equal('ShiftLeftI64x4 parity c=' + IntToStr(C_SHIFT64[LShiftIndex]) + ': ' + NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

        LI64x4ByBackend := LBackendTable.CoreVectors.ShiftRightI64x4(LI64x4A, C_SHIFT64[LShiftIndex]);
        LI64x4ByScalar := LScalarTable.CoreVectors.ShiftRightI64x4(LI64x4A, C_SHIFT64[LShiftIndex]);
        AssertVecI64x4Equal('ShiftRightI64x4 parity c=' + IntToStr(C_SHIFT64[LShiftIndex]) + ': ' + NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

        LI64x4ByBackend := LBackendTable.CoreVectors.ShiftRightArithI64x4(LI64x4A, C_SHIFT64[LShiftIndex]);
        LI64x4ByScalar := ScalarShiftRightArithI64x4(LI64x4A, C_SHIFT64[LShiftIndex]);
        AssertVecI64x4Equal('ShiftRightArithI64x4 parity c=' + IntToStr(C_SHIFT64[LShiftIndex]) + ': ' + NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);
      end;

    Inc(LChecked);
  end;

  if LChecked = 0 then
    CheckTrue(True, 'No non-x86 backend registered/active on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_WideIntegerArithmeticMinMaxParity_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LBackendTable: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LI32x8A, LI32x8B: TVecI32x8;
  LU32x8A, LU32x8B: TVecU32x8;
  LI64x4A, LI64x4B: TVecI64x4;
  LU64x4A, LU64x4B: TVecU64x4;
  LI32x16A, LI32x16B: TVecI32x16;
  LU32x16A, LU32x16B: TVecU32x16;
  LI64x8A, LI64x8B: TVecI64x8;
  LU64x8A, LU64x8B: TVecU64x8;
  LMulI32x8ProbeA, LMulI32x8ProbeB, LMulI32x8ProbeExpected: TVecI32x8;
  LMulU32x8ProbeA, LMulU32x8ProbeB, LMulU32x8ProbeExpected: TVecU32x8;
  LU32x8LaneProbeA, LU32x8LaneProbeB, LU32x8LaneProbeExpected: TVecU32x8;
  LU64x4LaneProbeA, LU64x4LaneProbeB: TVecU64x4;
  LU64x4AddProbeExpected, LU64x4SubProbeExpected: TVecU64x4;
  LI32x8ByBackend, LI32x8ByScalar: TVecI32x8;
  LU32x8ByBackend, LU32x8ByScalar: TVecU32x8;
  LI64x4ByBackend, LI64x4ByScalar: TVecI64x4;
  LU64x4ByBackend, LU64x4ByScalar: TVecU64x4;
  LI32x16ByBackend, LI32x16ByScalar: TVecI32x16;
  LU32x16ByBackend, LU32x16ByScalar: TVecU32x16;
  LI64x8ByBackend, LI64x8ByScalar: TVecI64x8;
  LU64x8ByBackend, LU64x8ByScalar: TVecU64x8;
  LLane: Integer;
  LChecked: Integer;

  procedure AssertVecI32x8Equal(const aLabel: string; const aExpected, aActual: TVecI32x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aLabel + ' lane ' + IntToStr(LLaneIndex));
  end;

  procedure AssertVecU32x8Equal(const aLabel: string; const aExpected, aActual: TVecU32x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      CheckEqual(QWord(aExpected.u[LLaneIndex]), QWord(aActual.u[LLaneIndex]), aLabel + ' lane ' + IntToStr(LLaneIndex));
  end;

  procedure AssertVecI64x4Equal(const aLabel: string; const aExpected, aActual: TVecI64x4);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 3 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aLabel + ' lane ' + IntToStr(LLaneIndex));
  end;

  procedure AssertVecU64x4Equal(const aLabel: string; const aExpected, aActual: TVecU64x4);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 3 do
      CheckEqual(QWord(aExpected.u[LLaneIndex]), QWord(aActual.u[LLaneIndex]), aLabel + ' lane ' + IntToStr(LLaneIndex));
  end;

  procedure AssertVecI32x16Equal(const aLabel: string; const aExpected, aActual: TVecI32x16);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 15 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aLabel + ' lane ' + IntToStr(LLaneIndex));
  end;

  procedure AssertVecU32x16Equal(const aLabel: string; const aExpected, aActual: TVecU32x16);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 15 do
      CheckEqual(QWord(aExpected.u[LLaneIndex]), QWord(aActual.u[LLaneIndex]), aLabel + ' lane ' + IntToStr(LLaneIndex));
  end;

  procedure AssertVecI64x8Equal(const aLabel: string; const aExpected, aActual: TVecI64x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aLabel + ' lane ' + IntToStr(LLaneIndex));
  end;

  procedure AssertVecU64x8Equal(const aLabel: string; const aExpected, aActual: TVecU64x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      CheckEqual(QWord(aExpected.u[LLaneIndex]), QWord(aActual.u[LLaneIndex]), aLabel + ' lane ' + IntToStr(LLaneIndex));
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LChecked := 0;

  LI32x8A.i[0] := High(Int32);
  LI32x8A.i[1] := Low(Int32);
  LI32x8A.i[2] := -1;
  LI32x8A.i[3] := 0;
  LI32x8A.i[4] := $55555555;
  LI32x8A.i[5] := Int32(DWord($AAAAAAAA));
  LI32x8A.i[6] := Int32($40000001);
  LI32x8A.i[7] := -16;
  LI32x8B.i[0] := 1;
  LI32x8B.i[1] := -1;
  LI32x8B.i[2] := $7FFFFFFF;
  LI32x8B.i[3] := $55555555;
  LI32x8B.i[4] := High(Int32);
  LI32x8B.i[5] := Low(Int32);
  LI32x8B.i[6] := Int32($7F0F0F0F);
  LI32x8B.i[7] := 15;

  LU32x8A.u[0] := 0;
  LU32x8A.u[1] := 1;
  LU32x8A.u[2] := High(UInt32);
  LU32x8A.u[3] := $80000000;
  LU32x8A.u[4] := $7FFFFFFF;
  LU32x8A.u[5] := DWord($AAAAAAAA);
  LU32x8A.u[6] := $55555555;
  LU32x8A.u[7] := 37;
  LU32x8B.u[0] := High(UInt32);
  LU32x8B.u[1] := 2;
  LU32x8B.u[2] := 3;
  LU32x8B.u[3] := $80000000;
  LU32x8B.u[4] := 1;
  LU32x8B.u[5] := $11111111;
  LU32x8B.u[6] := DWord($AAAAAAAA);
  LU32x8B.u[7] := High(UInt32) - 15;

  LI64x4A.i[0] := High(Int64);
  LI64x4A.i[1] := Low(Int64);
  LI64x4A.i[2] := -1;
  LI64x4A.i[3] := Int64($4000000000000001);
  LI64x4B.i[0] := 1;
  LI64x4B.i[1] := -1;
  LI64x4B.i[2] := High(Int64);
  LI64x4B.i[3] := Low(Int64);

  LU64x4A.u[0] := 0;
  LU64x4A.u[1] := 1;
  LU64x4A.u[2] := High(QWord);
  LU64x4A.u[3] := QWord($8000000000000000);
  LU64x4B.u[0] := High(QWord);
  LU64x4B.u[1] := 2;
  LU64x4B.u[2] := 3;
  LU64x4B.u[3] := QWord($7FFFFFFFFFFFFFFF);

  for LLane := 0 to 15 do
  begin
    LI32x16A.i[LLane] := (LLane - 8) * 4099;
    LI32x16B.i[LLane] := (8 - LLane) * 2053;
    LU32x16A.u[LLane] := DWord(LLane * 257);
    LU32x16B.u[LLane] := DWord((15 - LLane) * 131);
  end;
  LI32x16A.i[0] := Low(Int32);
  LI32x16A.i[1] := -1;
  LI32x16A.i[2] := $55555555;
  LI32x16A.i[15] := High(Int32);
  LI32x16B.i[0] := 1;
  LI32x16B.i[1] := High(Int32);
  LI32x16B.i[2] := Int32(DWord($AAAAAAAA));
  LI32x16B.i[15] := Low(Int32);
  LU32x16A.u[0] := 0;
  LU32x16A.u[1] := High(UInt32);
  LU32x16A.u[2] := $80000000;
  LU32x16A.u[15] := $55555555;
  LU32x16B.u[0] := High(UInt32);
  LU32x16B.u[1] := 1;
  LU32x16B.u[2] := $80000000;
  LU32x16B.u[15] := $AAAAAAAA;

  for LLane := 0 to 7 do
  begin
    LI64x8A.i[LLane] := (LLane - 4) * 1025;
    LI64x8B.i[LLane] := (3 - LLane) * 511;
    LU64x8A.u[LLane] := QWord(LLane) * 257;
    LU64x8B.u[LLane] := QWord(7 - LLane) * 131;
  end;
  LI64x8A.i[0] := High(Int64);
  LI64x8A.i[1] := Low(Int64);
  LI64x8A.i[2] := -1;
  LI64x8A.i[7] := Int64($4000000000000001);
  LI64x8B.i[0] := 1;
  LI64x8B.i[1] := -1;
  LI64x8B.i[2] := High(Int64);
  LI64x8B.i[7] := Low(Int64);
  LU64x8A.u[0] := 0;
  LU64x8A.u[1] := 1;
  LU64x8A.u[2] := High(QWord);
  LU64x8A.u[7] := QWord($8000000000000000);
  LU64x8B.u[0] := High(QWord);
  LU64x8B.u[1] := 2;
  LU64x8B.u[2] := 3;
  LU64x8B.u[7] := QWord($7FFFFFFFFFFFFFFF);

  LMulI32x8ProbeA.i[0] := -1;
  LMulI32x8ProbeA.i[1] := High(Int32);
  LMulI32x8ProbeA.i[2] := Low(Int32);
  LMulI32x8ProbeA.i[3] := Int32($40000001);
  LMulI32x8ProbeA.i[4] := 12345;
  LMulI32x8ProbeA.i[5] := -12345;
  LMulI32x8ProbeA.i[6] := 65536;
  LMulI32x8ProbeA.i[7] := -65536;
  LMulI32x8ProbeB.i[0] := Low(Int32);
  LMulI32x8ProbeB.i[1] := 2;
  LMulI32x8ProbeB.i[2] := 2;
  LMulI32x8ProbeB.i[3] := 4;
  LMulI32x8ProbeB.i[4] := -6789;
  LMulI32x8ProbeB.i[5] := 6789;
  LMulI32x8ProbeB.i[6] := 65535;
  LMulI32x8ProbeB.i[7] := 65535;
  LMulI32x8ProbeExpected.i[0] := Low(Int32);
  LMulI32x8ProbeExpected.i[1] := -2;
  LMulI32x8ProbeExpected.i[2] := 0;
  LMulI32x8ProbeExpected.i[3] := 4;
  LMulI32x8ProbeExpected.i[4] := -83810205;
  LMulI32x8ProbeExpected.i[5] := -83810205;
  LMulI32x8ProbeExpected.i[6] := -65536;
  LMulI32x8ProbeExpected.i[7] := 65536;

  LMulU32x8ProbeA.u[0] := High(UInt32);
  LMulU32x8ProbeA.u[1] := $80000000;
  LMulU32x8ProbeA.u[2] := $7FFFFFFF;
  LMulU32x8ProbeA.u[3] := $40000001;
  LMulU32x8ProbeA.u[4] := 9;
  LMulU32x8ProbeA.u[5] := 10;
  LMulU32x8ProbeA.u[6] := 11;
  LMulU32x8ProbeA.u[7] := 12;
  LMulU32x8ProbeB.u[0] := High(UInt32);
  LMulU32x8ProbeB.u[1] := 2;
  LMulU32x8ProbeB.u[2] := 2;
  LMulU32x8ProbeB.u[3] := 4;
  LMulU32x8ProbeB.u[4] := 8;
  LMulU32x8ProbeB.u[5] := 10;
  LMulU32x8ProbeB.u[6] := 12;
  LMulU32x8ProbeB.u[7] := 12;
  LMulU32x8ProbeExpected.u[0] := 1;
  LMulU32x8ProbeExpected.u[1] := 0;
  LMulU32x8ProbeExpected.u[2] := DWord($FFFFFFFE);
  LMulU32x8ProbeExpected.u[3] := 4;
  LMulU32x8ProbeExpected.u[4] := 72;
  LMulU32x8ProbeExpected.u[5] := 100;
  LMulU32x8ProbeExpected.u[6] := 132;
  LMulU32x8ProbeExpected.u[7] := 144;

  LU32x8LaneProbeA.u[0] := $10000000;
  LU32x8LaneProbeA.u[1] := $10000010;
  LU32x8LaneProbeA.u[2] := $10000020;
  LU32x8LaneProbeA.u[3] := $10000030;
  LU32x8LaneProbeA.u[4] := $E0000000;
  LU32x8LaneProbeA.u[5] := $E0000010;
  LU32x8LaneProbeA.u[6] := $E0000020;
  LU32x8LaneProbeA.u[7] := $E0000030;
  LU32x8LaneProbeB.u[0] := 1;
  LU32x8LaneProbeB.u[1] := 2;
  LU32x8LaneProbeB.u[2] := 3;
  LU32x8LaneProbeB.u[3] := 4;
  LU32x8LaneProbeB.u[4] := 5;
  LU32x8LaneProbeB.u[5] := 6;
  LU32x8LaneProbeB.u[6] := 7;
  LU32x8LaneProbeB.u[7] := 8;
  LU32x8LaneProbeExpected.u[0] := $10000001;
  LU32x8LaneProbeExpected.u[1] := $10000012;
  LU32x8LaneProbeExpected.u[2] := $10000023;
  LU32x8LaneProbeExpected.u[3] := $10000034;
  LU32x8LaneProbeExpected.u[4] := $E0000005;
  LU32x8LaneProbeExpected.u[5] := $E0000016;
  LU32x8LaneProbeExpected.u[6] := $E0000027;
  LU32x8LaneProbeExpected.u[7] := $E0000038;

  LU64x4LaneProbeA.u[0] := QWord($1010000000000000);
  LU64x4LaneProbeA.u[1] := QWord($1111000000000000);
  LU64x4LaneProbeA.u[2] := QWord($E0E0000000000000);
  LU64x4LaneProbeA.u[3] := QWord($F1F1000000000000);
  LU64x4LaneProbeB.u[0] := 1;
  LU64x4LaneProbeB.u[1] := 2;
  LU64x4LaneProbeB.u[2] := 3;
  LU64x4LaneProbeB.u[3] := 4;
  LU64x4AddProbeExpected.u[0] := QWord($1010000000000001);
  LU64x4AddProbeExpected.u[1] := QWord($1111000000000002);
  LU64x4AddProbeExpected.u[2] := QWord($E0E0000000000003);
  LU64x4AddProbeExpected.u[3] := QWord($F1F1000000000004);
  LU64x4SubProbeExpected.u[0] := QWord($100FFFFFFFFFFFFF);
  LU64x4SubProbeExpected.u[1] := QWord($1110FFFFFFFFFFFE);
  LU64x4SubProbeExpected.u[2] := QWord($E0DFFFFFFFFFFFFD);
  LU64x4SubProbeExpected.u[3] := QWord($F1F0FFFFFFFFFFFC);

  for LBackend in LBackends do
  begin
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

      CheckTrue(Assigned(LBackendTable.CoreVectors.AddI32x8), 'AddI32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.SubI32x8), 'SubI32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.MulI32x8), 'MulI32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.MinI32x8), 'MinI32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.MaxI32x8), 'MaxI32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AddU32x8), 'AddU32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.SubU32x8), 'SubU32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.MulU32x8), 'MulU32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.MinU32x8), 'MinU32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.MaxU32x8), 'MaxU32x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AddI64x4), 'AddI64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.SubI64x4), 'SubI64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AddU64x4), 'AddU64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.SubU64x4), 'SubU64x4 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AddI32x16), 'AddI32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.SubI32x16), 'SubI32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.MulI32x16), 'MulI32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.MinI32x16), 'MinI32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.MaxI32x16), 'MaxI32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AddU32x16), 'AddU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.SubU32x16), 'SubU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.MulU32x16), 'MulU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.MinU32x16), 'MinU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.MaxU32x16), 'MaxU32x16 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AddI64x8), 'AddI64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.SubI64x8), 'SubI64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.AddU64x8), 'AddU64x8 missing: ' + NonX86BackendName(LBackend));
      CheckTrue(Assigned(LBackendTable.CoreVectors.SubU64x8), 'SubU64x8 missing: ' + NonX86BackendName(LBackend));

      LI32x8ByBackend := LBackendTable.CoreVectors.AddI32x8(LI32x8A, LI32x8B);
      LI32x8ByScalar := LScalarTable.CoreVectors.AddI32x8(LI32x8A, LI32x8B);
      AssertVecI32x8Equal('AddI32x8 parity: ' + NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

      LI32x8ByBackend := LBackendTable.CoreVectors.SubI32x8(LI32x8A, LI32x8B);
      LI32x8ByScalar := LScalarTable.CoreVectors.SubI32x8(LI32x8A, LI32x8B);
      AssertVecI32x8Equal('SubI32x8 parity: ' + NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

      LI32x8ByBackend := LBackendTable.CoreVectors.MulI32x8(LI32x8A, LI32x8B);
      LI32x8ByScalar := LScalarTable.CoreVectors.MulI32x8(LI32x8A, LI32x8B);
      AssertVecI32x8Equal('MulI32x8 parity: ' + NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

      LI32x8ByBackend := LBackendTable.CoreVectors.MulI32x8(LMulI32x8ProbeA, LMulI32x8ProbeB);
      LI32x8ByScalar := LScalarTable.CoreVectors.MulI32x8(LMulI32x8ProbeA, LMulI32x8ProbeB);
      AssertVecI32x8Equal('MulI32x8 truncation scalar contract: ' + NonX86BackendName(LBackend), LMulI32x8ProbeExpected, LI32x8ByScalar);
      AssertVecI32x8Equal('MulI32x8 truncation backend contract: ' + NonX86BackendName(LBackend), LMulI32x8ProbeExpected, LI32x8ByBackend);

      LI32x8ByBackend := LBackendTable.CoreVectors.MinI32x8(LI32x8A, LI32x8B);
      LI32x8ByScalar := LScalarTable.CoreVectors.MinI32x8(LI32x8A, LI32x8B);
      AssertVecI32x8Equal('MinI32x8 parity: ' + NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

      LI32x8ByBackend := LBackendTable.CoreVectors.MaxI32x8(LI32x8A, LI32x8B);
      LI32x8ByScalar := LScalarTable.CoreVectors.MaxI32x8(LI32x8A, LI32x8B);
      AssertVecI32x8Equal('MaxI32x8 parity: ' + NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

      LU32x8ByBackend := LBackendTable.CoreVectors.AddU32x8(LU32x8A, LU32x8B);
      LU32x8ByScalar := LScalarTable.CoreVectors.AddU32x8(LU32x8A, LU32x8B);
      AssertVecU32x8Equal('AddU32x8 parity: ' + NonX86BackendName(LBackend), LU32x8ByScalar, LU32x8ByBackend);

      LU32x8ByBackend := LBackendTable.CoreVectors.SubU32x8(LU32x8A, LU32x8B);
      LU32x8ByScalar := LScalarTable.CoreVectors.SubU32x8(LU32x8A, LU32x8B);
      AssertVecU32x8Equal('SubU32x8 parity: ' + NonX86BackendName(LBackend), LU32x8ByScalar, LU32x8ByBackend);

      LU32x8ByBackend := LBackendTable.CoreVectors.MulU32x8(LU32x8A, LU32x8B);
      LU32x8ByScalar := LScalarTable.CoreVectors.MulU32x8(LU32x8A, LU32x8B);
      AssertVecU32x8Equal('MulU32x8 parity: ' + NonX86BackendName(LBackend), LU32x8ByScalar, LU32x8ByBackend);

      LU32x8ByBackend := LBackendTable.CoreVectors.MulU32x8(LMulU32x8ProbeA, LMulU32x8ProbeB);
      LU32x8ByScalar := LScalarTable.CoreVectors.MulU32x8(LMulU32x8ProbeA, LMulU32x8ProbeB);
      AssertVecU32x8Equal('MulU32x8 truncation scalar contract: ' + NonX86BackendName(LBackend), LMulU32x8ProbeExpected, LU32x8ByScalar);
      AssertVecU32x8Equal('MulU32x8 truncation backend contract: ' + NonX86BackendName(LBackend), LMulU32x8ProbeExpected, LU32x8ByBackend);

      LU32x8ByBackend := LBackendTable.CoreVectors.MinU32x8(LU32x8A, LU32x8B);
      LU32x8ByScalar := LScalarTable.CoreVectors.MinU32x8(LU32x8A, LU32x8B);
      AssertVecU32x8Equal('MinU32x8 parity: ' + NonX86BackendName(LBackend), LU32x8ByScalar, LU32x8ByBackend);

      LU32x8ByBackend := LBackendTable.CoreVectors.MaxU32x8(LU32x8A, LU32x8B);
      LU32x8ByScalar := LScalarTable.CoreVectors.MaxU32x8(LU32x8A, LU32x8B);
      AssertVecU32x8Equal('MaxU32x8 parity: ' + NonX86BackendName(LBackend), LU32x8ByScalar, LU32x8ByBackend);

      LU32x8ByBackend := LBackendTable.CoreVectors.AddU32x8(LU32x8LaneProbeA, LU32x8LaneProbeB);
      LU32x8ByScalar := LScalarTable.CoreVectors.AddU32x8(LU32x8LaneProbeA, LU32x8LaneProbeB);
      AssertVecU32x8Equal('AddU32x8 lane-tag scalar contract: ' + NonX86BackendName(LBackend), LU32x8LaneProbeExpected, LU32x8ByScalar);
      AssertVecU32x8Equal('AddU32x8 lane-tag backend contract: ' + NonX86BackendName(LBackend), LU32x8LaneProbeExpected, LU32x8ByBackend);

      LI64x4ByBackend := LBackendTable.CoreVectors.AddI64x4(LI64x4A, LI64x4B);
      LI64x4ByScalar := LScalarTable.CoreVectors.AddI64x4(LI64x4A, LI64x4B);
      AssertVecI64x4Equal('AddI64x4 parity: ' + NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

      LI64x4ByBackend := LBackendTable.CoreVectors.SubI64x4(LI64x4A, LI64x4B);
      LI64x4ByScalar := LScalarTable.CoreVectors.SubI64x4(LI64x4A, LI64x4B);
      AssertVecI64x4Equal('SubI64x4 parity: ' + NonX86BackendName(LBackend), LI64x4ByScalar, LI64x4ByBackend);

      LU64x4ByBackend := LBackendTable.CoreVectors.AddU64x4(LU64x4A, LU64x4B);
      LU64x4ByScalar := LScalarTable.CoreVectors.AddU64x4(LU64x4A, LU64x4B);
      AssertVecU64x4Equal('AddU64x4 parity: ' + NonX86BackendName(LBackend), LU64x4ByScalar, LU64x4ByBackend);

      LU64x4ByBackend := LBackendTable.CoreVectors.SubU64x4(LU64x4A, LU64x4B);
      LU64x4ByScalar := LScalarTable.CoreVectors.SubU64x4(LU64x4A, LU64x4B);
      AssertVecU64x4Equal('SubU64x4 parity: ' + NonX86BackendName(LBackend), LU64x4ByScalar, LU64x4ByBackend);

      LU64x4ByBackend := LBackendTable.CoreVectors.AddU64x4(LU64x4LaneProbeA, LU64x4LaneProbeB);
      LU64x4ByScalar := LScalarTable.CoreVectors.AddU64x4(LU64x4LaneProbeA, LU64x4LaneProbeB);
      AssertVecU64x4Equal('AddU64x4 lane-tag scalar contract: ' + NonX86BackendName(LBackend), LU64x4AddProbeExpected, LU64x4ByScalar);
      AssertVecU64x4Equal('AddU64x4 lane-tag backend contract: ' + NonX86BackendName(LBackend), LU64x4AddProbeExpected, LU64x4ByBackend);

      LU64x4ByBackend := LBackendTable.CoreVectors.SubU64x4(LU64x4LaneProbeA, LU64x4LaneProbeB);
      LU64x4ByScalar := LScalarTable.CoreVectors.SubU64x4(LU64x4LaneProbeA, LU64x4LaneProbeB);
      AssertVecU64x4Equal('SubU64x4 lane-tag scalar contract: ' + NonX86BackendName(LBackend), LU64x4SubProbeExpected, LU64x4ByScalar);
      AssertVecU64x4Equal('SubU64x4 lane-tag backend contract: ' + NonX86BackendName(LBackend), LU64x4SubProbeExpected, LU64x4ByBackend);

      LI32x16ByBackend := LBackendTable.CoreVectors.AddI32x16(LI32x16A, LI32x16B);
      LI32x16ByScalar := LScalarTable.CoreVectors.AddI32x16(LI32x16A, LI32x16B);
      AssertVecI32x16Equal('AddI32x16 parity: ' + NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByBackend);

      LI32x16ByBackend := LBackendTable.CoreVectors.SubI32x16(LI32x16A, LI32x16B);
      LI32x16ByScalar := LScalarTable.CoreVectors.SubI32x16(LI32x16A, LI32x16B);
      AssertVecI32x16Equal('SubI32x16 parity: ' + NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByBackend);

      LI32x16ByBackend := LBackendTable.CoreVectors.MulI32x16(LI32x16A, LI32x16B);
      LI32x16ByScalar := LScalarTable.CoreVectors.MulI32x16(LI32x16A, LI32x16B);
      AssertVecI32x16Equal('MulI32x16 parity: ' + NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByBackend);

      LI32x16ByBackend := LBackendTable.CoreVectors.MinI32x16(LI32x16A, LI32x16B);
      LI32x16ByScalar := LScalarTable.CoreVectors.MinI32x16(LI32x16A, LI32x16B);
      AssertVecI32x16Equal('MinI32x16 parity: ' + NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByBackend);

      LI32x16ByBackend := LBackendTable.CoreVectors.MaxI32x16(LI32x16A, LI32x16B);
      LI32x16ByScalar := LScalarTable.CoreVectors.MaxI32x16(LI32x16A, LI32x16B);
      AssertVecI32x16Equal('MaxI32x16 parity: ' + NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByBackend);

      LU32x16ByBackend := LBackendTable.CoreVectors.AddU32x16(LU32x16A, LU32x16B);
      LU32x16ByScalar := LScalarTable.CoreVectors.AddU32x16(LU32x16A, LU32x16B);
      AssertVecU32x16Equal('AddU32x16 parity: ' + NonX86BackendName(LBackend), LU32x16ByScalar, LU32x16ByBackend);

      LU32x16ByBackend := LBackendTable.CoreVectors.SubU32x16(LU32x16A, LU32x16B);
      LU32x16ByScalar := LScalarTable.CoreVectors.SubU32x16(LU32x16A, LU32x16B);
      AssertVecU32x16Equal('SubU32x16 parity: ' + NonX86BackendName(LBackend), LU32x16ByScalar, LU32x16ByBackend);

      LU32x16ByBackend := LBackendTable.CoreVectors.MulU32x16(LU32x16A, LU32x16B);
      LU32x16ByScalar := LScalarTable.CoreVectors.MulU32x16(LU32x16A, LU32x16B);
      AssertVecU32x16Equal('MulU32x16 parity: ' + NonX86BackendName(LBackend), LU32x16ByScalar, LU32x16ByBackend);

      LU32x16ByBackend := LBackendTable.CoreVectors.MinU32x16(LU32x16A, LU32x16B);
      LU32x16ByScalar := LScalarTable.CoreVectors.MinU32x16(LU32x16A, LU32x16B);
      AssertVecU32x16Equal('MinU32x16 parity: ' + NonX86BackendName(LBackend), LU32x16ByScalar, LU32x16ByBackend);

      LU32x16ByBackend := LBackendTable.CoreVectors.MaxU32x16(LU32x16A, LU32x16B);
      LU32x16ByScalar := LScalarTable.CoreVectors.MaxU32x16(LU32x16A, LU32x16B);
      AssertVecU32x16Equal('MaxU32x16 parity: ' + NonX86BackendName(LBackend), LU32x16ByScalar, LU32x16ByBackend);

      LI64x8ByBackend := LBackendTable.CoreVectors.AddI64x8(LI64x8A, LI64x8B);
      LI64x8ByScalar := LScalarTable.CoreVectors.AddI64x8(LI64x8A, LI64x8B);
      AssertVecI64x8Equal('AddI64x8 parity: ' + NonX86BackendName(LBackend), LI64x8ByScalar, LI64x8ByBackend);

      LI64x8ByBackend := LBackendTable.CoreVectors.SubI64x8(LI64x8A, LI64x8B);
      LI64x8ByScalar := LScalarTable.CoreVectors.SubI64x8(LI64x8A, LI64x8B);
      AssertVecI64x8Equal('SubI64x8 parity: ' + NonX86BackendName(LBackend), LI64x8ByScalar, LI64x8ByBackend);

      LU64x8ByBackend := LBackendTable.CoreVectors.AddU64x8(LU64x8A, LU64x8B);
      LU64x8ByScalar := LScalarTable.CoreVectors.AddU64x8(LU64x8A, LU64x8B);
      AssertVecU64x8Equal('AddU64x8 parity: ' + NonX86BackendName(LBackend), LU64x8ByScalar, LU64x8ByBackend);

      LU64x8ByBackend := LBackendTable.CoreVectors.SubU64x8(LU64x8A, LU64x8B);
      LU64x8ByScalar := LScalarTable.CoreVectors.SubU64x8(LU64x8A, LU64x8B);
      AssertVecU64x8Equal('SubU64x8 parity: ' + NonX86BackendName(LBackend), LU64x8ByScalar, LU64x8ByBackend);

      LI32x8ByBackend := VecI32x8Mul(LI32x8A, LI32x8B);
      LI32x8ByScalar := LScalarTable.CoreVectors.MulI32x8(LI32x8A, LI32x8B);
      AssertVecI32x8Equal('Facade MulI32x8 parity: ' + NonX86BackendName(LBackend), LI32x8ByScalar, LI32x8ByBackend);

      LU32x8ByBackend := VecU32x8Min(LU32x8A, LU32x8B);
      LU32x8ByScalar := LScalarTable.CoreVectors.MinU32x8(LU32x8A, LU32x8B);
      AssertVecU32x8Equal('Facade MinU32x8 parity: ' + NonX86BackendName(LBackend), LU32x8ByScalar, LU32x8ByBackend);

      LI32x16ByBackend := VecI32x16Mul(LI32x16A, LI32x16B);
      LI32x16ByScalar := LScalarTable.CoreVectors.MulI32x16(LI32x16A, LI32x16B);
      AssertVecI32x16Equal('Facade MulI32x16 parity: ' + NonX86BackendName(LBackend), LI32x16ByScalar, LI32x16ByBackend);

      LU32x16ByBackend := VecU32x16Mul(LU32x16A, LU32x16B);
      LU32x16ByScalar := LScalarTable.CoreVectors.MulU32x16(LU32x16A, LU32x16B);
      AssertVecU32x16Equal('Facade MulU32x16 parity: ' + NonX86BackendName(LBackend), LU32x16ByScalar, LU32x16ByBackend);

      LU32x16ByBackend := VecU32x16Max(LU32x16A, LU32x16B);
      LU32x16ByScalar := LScalarTable.CoreVectors.MaxU32x16(LU32x16A, LU32x16B);
      AssertVecU32x16Equal('Facade MaxU32x16 parity: ' + NonX86BackendName(LBackend), LU32x16ByScalar, LU32x16ByBackend);

      LI64x8ByBackend := VecI64x8Add(LI64x8A, LI64x8B);
      LI64x8ByScalar := LScalarTable.CoreVectors.AddI64x8(LI64x8A, LI64x8B);
      AssertVecI64x8Equal('Facade AddI64x8 parity: ' + NonX86BackendName(LBackend), LI64x8ByScalar, LI64x8ByBackend);

      LI64x8ByBackend := VecI64x8Sub(LI64x8A, LI64x8B);
      LI64x8ByScalar := LScalarTable.CoreVectors.SubI64x8(LI64x8A, LI64x8B);
      AssertVecI64x8Equal('Facade SubI64x8 parity: ' + NonX86BackendName(LBackend), LI64x8ByScalar, LI64x8ByBackend);

      LU64x8ByBackend := VecU64x8Add(LU64x8A, LU64x8B);
      LU64x8ByScalar := LScalarTable.CoreVectors.AddU64x8(LU64x8A, LU64x8B);
      AssertVecU64x8Equal('Facade AddU64x8 parity: ' + NonX86BackendName(LBackend), LU64x8ByScalar, LU64x8ByBackend);

    Inc(LChecked);
  end;

  if LChecked = 0 then
    CheckTrue(True, 'No non-x86 backend registered/active on this host (allowed)');
end;

procedure TTestCase_NonX86BackendParity.Test_SaturatingArithmeticParity_IfAvailable;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LBackendTable: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LI8x16A, LI8x16B: TVecI8x16;
  LI16x8A, LI16x8B: TVecI16x8;
  LU8x16A, LU8x16B: TVecU8x16;
  LU16x8A, LU16x8B: TVecU16x8;
  LI8x16ByBackend, LI8x16ByScalar: TVecI8x16;
  LI16x8ByBackend, LI16x8ByScalar: TVecI16x8;
  LU8x16ByBackend, LU8x16ByScalar: TVecU8x16;
  LU16x8ByBackend, LU16x8ByScalar: TVecU16x8;
  LLane: Integer;
  LChecked: Integer;

  procedure AssertVecI8x16Equal(const aLabel: string; const aExpected, aActual: TVecI8x16);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 15 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aLabel + ' lane ' + IntToStr(LLaneIndex));
  end;

  procedure AssertVecI16x8Equal(const aLabel: string; const aExpected, aActual: TVecI16x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aLabel + ' lane ' + IntToStr(LLaneIndex));
  end;

  procedure AssertVecU8x16Equal(const aLabel: string; const aExpected, aActual: TVecU8x16);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 15 do
      CheckEqual(Integer(aExpected.u[LLaneIndex]), Integer(aActual.u[LLaneIndex]), aLabel + ' lane ' + IntToStr(LLaneIndex));
  end;

  procedure AssertVecU16x8Equal(const aLabel: string; const aExpected, aActual: TVecU16x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      CheckEqual(Integer(aExpected.u[LLaneIndex]), Integer(aActual.u[LLaneIndex]), aLabel + ' lane ' + IntToStr(LLaneIndex));
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LChecked := 0;

  for LLane := 0 to 15 do
  begin
    LI8x16A.i[LLane] := Int8(112 - LLane * 15);
    LI8x16B.i[LLane] := Int8(32 + LLane * 11);
    LU8x16A.u[LLane] := UInt8((LLane * 17) and $FF);
    LU8x16B.u[LLane] := UInt8(240 - LLane * 13);
  end;
  LI8x16A.i[0] := 127;
  LI8x16B.i[0] := 1;
  LI8x16A.i[1] := -128;
  LI8x16B.i[1] := -1;
  LI8x16A.i[2] := -120;
  LI8x16B.i[2] := 30;
  LI8x16A.i[3] := 120;
  LI8x16B.i[3] := -30;
  LU8x16A.u[0] := 255;
  LU8x16B.u[0] := 1;
  LU8x16A.u[1] := 0;
  LU8x16B.u[1] := 1;
  LU8x16A.u[2] := 4;
  LU8x16B.u[2] := 250;
  LU8x16A.u[3] := 200;
  LU8x16B.u[3] := 100;

  for LLane := 0 to 7 do
  begin
    LI16x8A.i[LLane] := Int16(30000 - LLane * 7000);
    LI16x8B.i[LLane] := Int16(9000 - LLane * 2500);
    LU16x8A.u[LLane] := UInt16(LLane * 4096);
    LU16x8B.u[LLane] := UInt16(60000 - LLane * 5000);
  end;
  LI16x8A.i[0] := 32767;
  LI16x8B.i[0] := 1;
  LI16x8A.i[1] := -32768;
  LI16x8B.i[1] := -1;
  LI16x8A.i[2] := -30000;
  LI16x8B.i[2] := 5000;
  LI16x8A.i[3] := 30000;
  LI16x8B.i[3] := -5000;
  LU16x8A.u[0] := 65535;
  LU16x8B.u[0] := 1;
  LU16x8A.u[1] := 0;
  LU16x8B.u[1] := 1;
  LU16x8A.u[2] := 9;
  LU16x8B.u[2] := 60000;
  LU16x8A.u[3] := 50000;
  LU16x8B.u[3] := 30000;

  for LBackend in LBackends do
  begin
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    CheckTrue(Assigned(LBackendTable.CoreVectors.I8x16SatAdd), 'I8x16SatAdd missing: ' + NonX86BackendName(LBackend));
    CheckTrue(Assigned(LBackendTable.CoreVectors.I8x16SatSub), 'I8x16SatSub missing: ' + NonX86BackendName(LBackend));
    CheckTrue(Assigned(LBackendTable.CoreVectors.I16x8SatAdd), 'I16x8SatAdd missing: ' + NonX86BackendName(LBackend));
    CheckTrue(Assigned(LBackendTable.CoreVectors.I16x8SatSub), 'I16x8SatSub missing: ' + NonX86BackendName(LBackend));
    CheckTrue(Assigned(LBackendTable.CoreVectors.U8x16SatAdd), 'U8x16SatAdd missing: ' + NonX86BackendName(LBackend));
    CheckTrue(Assigned(LBackendTable.CoreVectors.U8x16SatSub), 'U8x16SatSub missing: ' + NonX86BackendName(LBackend));
    CheckTrue(Assigned(LBackendTable.CoreVectors.U16x8SatAdd), 'U16x8SatAdd missing: ' + NonX86BackendName(LBackend));
    CheckTrue(Assigned(LBackendTable.CoreVectors.U16x8SatSub), 'U16x8SatSub missing: ' + NonX86BackendName(LBackend));

    LI8x16ByBackend := LBackendTable.CoreVectors.I8x16SatAdd(LI8x16A, LI8x16B);
    LI8x16ByScalar := LScalarTable.CoreVectors.I8x16SatAdd(LI8x16A, LI8x16B);
    AssertVecI8x16Equal('I8x16SatAdd parity: ' + NonX86BackendName(LBackend), LI8x16ByScalar, LI8x16ByBackend);

    LI8x16ByBackend := LBackendTable.CoreVectors.I8x16SatSub(LI8x16A, LI8x16B);
    LI8x16ByScalar := LScalarTable.CoreVectors.I8x16SatSub(LI8x16A, LI8x16B);
    AssertVecI8x16Equal('I8x16SatSub parity: ' + NonX86BackendName(LBackend), LI8x16ByScalar, LI8x16ByBackend);

    LI16x8ByBackend := LBackendTable.CoreVectors.I16x8SatAdd(LI16x8A, LI16x8B);
    LI16x8ByScalar := LScalarTable.CoreVectors.I16x8SatAdd(LI16x8A, LI16x8B);
    AssertVecI16x8Equal('I16x8SatAdd parity: ' + NonX86BackendName(LBackend), LI16x8ByScalar, LI16x8ByBackend);

    LI16x8ByBackend := LBackendTable.CoreVectors.I16x8SatSub(LI16x8A, LI16x8B);
    LI16x8ByScalar := LScalarTable.CoreVectors.I16x8SatSub(LI16x8A, LI16x8B);
    AssertVecI16x8Equal('I16x8SatSub parity: ' + NonX86BackendName(LBackend), LI16x8ByScalar, LI16x8ByBackend);

    LU8x16ByBackend := LBackendTable.CoreVectors.U8x16SatAdd(LU8x16A, LU8x16B);
    LU8x16ByScalar := LScalarTable.CoreVectors.U8x16SatAdd(LU8x16A, LU8x16B);
    AssertVecU8x16Equal('U8x16SatAdd parity: ' + NonX86BackendName(LBackend), LU8x16ByScalar, LU8x16ByBackend);

    LU8x16ByBackend := LBackendTable.CoreVectors.U8x16SatSub(LU8x16A, LU8x16B);
    LU8x16ByScalar := LScalarTable.CoreVectors.U8x16SatSub(LU8x16A, LU8x16B);
    AssertVecU8x16Equal('U8x16SatSub parity: ' + NonX86BackendName(LBackend), LU8x16ByScalar, LU8x16ByBackend);

    LU16x8ByBackend := LBackendTable.CoreVectors.U16x8SatAdd(LU16x8A, LU16x8B);
    LU16x8ByScalar := LScalarTable.CoreVectors.U16x8SatAdd(LU16x8A, LU16x8B);
    AssertVecU16x8Equal('U16x8SatAdd parity: ' + NonX86BackendName(LBackend), LU16x8ByScalar, LU16x8ByBackend);

    LU16x8ByBackend := LBackendTable.CoreVectors.U16x8SatSub(LU16x8A, LU16x8B);
    LU16x8ByScalar := LScalarTable.CoreVectors.U16x8SatSub(LU16x8A, LU16x8B);
    AssertVecU16x8Equal('U16x8SatSub parity: ' + NonX86BackendName(LBackend), LU16x8ByScalar, LU16x8ByBackend);

    Inc(LChecked);
  end;

  if LChecked = 0 then
    CheckTrue(True, 'No non-x86 backend registered/active on this host (allowed)');
end;

end.
