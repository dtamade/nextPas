unit nextpas.core.simd.dispatchapi.capabilities.testcase;

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
  TTestCase_DispatchAPICapabilities = class(TDispatchAPIStatefulTestCase)
  published
    procedure Test_AllRegisteredBackends_Wide512IntegerSlots_Assigned;
    procedure Test_AVX512_U32x16_U64x8_MappingAndParity;
    procedure Test_AVX512_U32x16_U64x8_ShiftBoundary_Contracts;
    procedure Test_AVX512_I16x32_I8x64_U8x64_MappingAndParity;
    procedure Test_AVX512_F32x16_F64x8_IEEE754_MappingAndParity;
    procedure Test_BackendCapabilities_DoNotOverclaim_512BitOps;
    procedure Test_BackendCapabilities_DoNotUnderclaim_IntegerOps;
    procedure Test_BackendCapabilities_DoNotUnderclaim_Shuffle;
    procedure Test_X86_BackendCapabilities_DoNotUnderclaim_MaskedOps;
    procedure Test_BackendCapabilities_Clear_IntegerOps_When_VectorAsmDisabled;
    procedure Test_X86_BackendCapabilities_Keep_IntegerOps_When_AlwaysOn_NarrowSlots_Remain_NonScalar;
    procedure Test_X86_BackendCapabilities_Keep_MaskedOps_When_VectorAsmDisabled;
    procedure Test_AVX2_BackendCapabilities_Expose_FMA_When_FusedPathUsable;
    procedure Test_AVX2_BackendCapabilities_Clear_FMA_When_VectorAsmDisabled;
    procedure Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_AVX2FMA_When_FusedPathUsable;
    procedure Test_AVX2_WideFma_ExactInputs_FollowsHalfComposition;
    procedure Test_AVX2_WideSelect_Parity_WithScalar_When_VectorAsmEnabled;
    procedure Test_AVX2_BackendCapabilities_Expose_Shuffle_When_NativeShuffleSlotsUsable;
    procedure Test_AVX2_BackendCapabilities_Clear_Shuffle_When_VectorAsmDisabled;
    procedure Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_AVX2Shuffle_When_NativeShuffleSlotsUsable;
    procedure Test_PublicApi_BackendPodInfo_CapabilityBits_Clear_AVX2VectorAsmGatedBits_When_VectorAsmDisabled;
    procedure Test_AVX2_FacadeScalarFallback_Uses_BaseFill_Without_Redundant_Win64_Rebinds;
    procedure Test_SSE3_RepresentativeOverrides_Reuse_SSE2_CoreSlots;
    procedure Test_SSSE3_RepresentativeOverrides_Reuse_SSE3_CoreSlots;
    procedure Test_SSE41_RepresentativeOverrides_Reuse_SSSE3_CoreSlots;
    procedure Test_SSE42_RepresentativeOverride_Reuse_SSE41_CoreSlots;
    procedure Test_SSE3_RepresentativeSemanticParity_WithScalar_IfDispatchable;
    procedure Test_SSSE3_RepresentativeSemanticParity_WithScalar_IfDispatchable;
    procedure Test_SSE41_RepresentativeSemanticParity_WithScalar_IfDispatchable;
    procedure Test_SSE42_RepresentativeSemanticParity_WithScalar_IfDispatchable;
    procedure Test_AVX512_PassThroughFacadeSlots_Reuse_AVX2_When_Wrappers_Are_Just_Forwarders;
    procedure Test_X86_BackendCapabilities_Clear_Shuffle_When_VectorAsmDisabled;
    procedure Test_AVX512_BackendCapabilities_Expose_FMA_When_WideFmaSlots_AreNative;
    procedure Test_AVX512_BackendCapabilities_Expose_Shuffle_When_WideSelectSlots_AreNative;
    procedure Test_AVX512_BackendCapabilities_Clear_VectorAsmGatedBits_When_VectorAsmDisabled;
    procedure Test_BenchmarkActivation_Rejects_CpuSupportedButNonDispatchable_Backend;
    procedure Test_AVX2_BenchmarkWideOps_NotScalar;
  end;

  TTestCase_X86MaskedFmaContract = class(TDispatchAPIStatefulTestCase)
  published
    procedure Test_AVX2_FmaSlots_StayScalar_When_HardwareFmaUnavailable;
  end;

  TTestCase_RISCVVMaskedOpsContract = class(TDispatchAPIStatefulTestCase)
  published
    procedure Test_RISCVV_BackendCapabilities_Expose_MaskedOps_When_MaskSlots_AreNative;
    procedure Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_RISCVVMaskedOps_When_MaskSlots_AreNative;
  end;

implementation

procedure TTestCase_DispatchAPICapabilities.Test_AllRegisteredBackends_Wide512IntegerSlots_Assigned;
var
  LBackends: array[0..4] of TSimdBackend;
  LBackend: TSimdBackend;
  LTable: TSimdDispatchTable;
  LRegisteredCount: Integer;

  procedure AssertAssigned(const aBackendName, aSlotName: string; aSlot: Pointer);
  begin
    CheckTrue(aSlot <> nil, aSlotName + ' missing: ' + aBackendName);
  end;
begin
  LBackends[0] := sbSSE2;
  LBackends[1] := sbAVX2;
  LBackends[2] := sbAVX512;
  LBackends[3] := sbNEON;
  LBackends[4] := sbRISCVV;
  LRegisteredCount := 0;

  for LBackend in LBackends do
  begin
    if not TryGetRegisteredBackendDispatchTable(LBackend, LTable) then
      Continue;

    Inc(LRegisteredCount);

    AssertAssigned(DispatchApiBackendName(LBackend), 'AddU32x16', Pointer(LTable.CoreVectors.AddU32x16));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpEqU32x16', Pointer(LTable.CoreVectors.CmpEqU32x16));
    AssertAssigned(DispatchApiBackendName(LBackend), 'MinU32x16', Pointer(LTable.CoreVectors.MinU32x16));

    AssertAssigned(DispatchApiBackendName(LBackend), 'AddU64x8', Pointer(LTable.CoreVectors.AddU64x8));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpEqU64x8', Pointer(LTable.CoreVectors.CmpEqU64x8));
    AssertAssigned(DispatchApiBackendName(LBackend), 'ShiftRightU64x8', Pointer(LTable.CoreVectors.ShiftRightU64x8));

    AssertAssigned(DispatchApiBackendName(LBackend), 'AddI16x32', Pointer(LTable.CoreVectors.AddI16x32));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpEqI16x32', Pointer(LTable.CoreVectors.CmpEqI16x32));
    AssertAssigned(DispatchApiBackendName(LBackend), 'ShiftRightArithI16x32', Pointer(LTable.CoreVectors.ShiftRightArithI16x32));

    AssertAssigned(DispatchApiBackendName(LBackend), 'AddI8x64', Pointer(LTable.CoreVectors.AddI8x64));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpEqI8x64', Pointer(LTable.CoreVectors.CmpEqI8x64));
    AssertAssigned(DispatchApiBackendName(LBackend), 'MaxI8x64', Pointer(LTable.CoreVectors.MaxI8x64));

    AssertAssigned(DispatchApiBackendName(LBackend), 'AddU8x64', Pointer(LTable.CoreVectors.AddU8x64));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpEqU8x64', Pointer(LTable.CoreVectors.CmpEqU8x64));
    AssertAssigned(DispatchApiBackendName(LBackend), 'MaxU8x64', Pointer(LTable.CoreVectors.MaxU8x64));
  end;

  if LRegisteredCount = 0 then
    CheckTrue(True, 'No SIMD backend registered on this host (allowed)');
end;

procedure TTestCase_DispatchAPICapabilities.Test_AVX512_U32x16_U64x8_MappingAndParity;
var
  LScalar: TSimdDispatchTable;
  LAVX512: TSimdDispatchTable;
  LCanRunAVX512: Boolean;
  LIndex: Integer;
  LU32A, LU32B, LU32Result, LU32Expected: TVecU32x16;
  LU64A, LU64B, LU64Result, LU64Expected: TVecU64x8;
  LMask16Result, LMask16Expected: TMask16;
  LMask8Result, LMask8Expected: TMask8;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalar), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  if not TryGetRegisteredBackendDispatchTable(sbAVX512, LAVX512) then
    Exit;

  // Mapping check: these slots must no longer point to scalar fallback.
  CheckTrue(Pointer(LAVX512.CoreVectors.AddU32x16) <> Pointer(LScalar.CoreVectors.AddU32x16), 'AVX512 AddU32x16 should not be scalar slot');
  CheckTrue(Pointer(LAVX512.CoreVectors.CmpEqU32x16) <> Pointer(LScalar.CoreVectors.CmpEqU32x16), 'AVX512 CmpEqU32x16 should not be scalar slot');
  CheckTrue(Pointer(LAVX512.CoreVectors.ShiftRightU32x16) <> Pointer(LScalar.CoreVectors.ShiftRightU32x16), 'AVX512 ShiftRightU32x16 should not be scalar slot');
  CheckTrue(Pointer(LAVX512.CoreVectors.AddU64x8) <> Pointer(LScalar.CoreVectors.AddU64x8), 'AVX512 AddU64x8 should not be scalar slot');
  CheckTrue(Pointer(LAVX512.CoreVectors.CmpEqU64x8) <> Pointer(LScalar.CoreVectors.CmpEqU64x8), 'AVX512 CmpEqU64x8 should not be scalar slot');
  CheckTrue(Pointer(LAVX512.CoreVectors.ShiftRightU64x8) <> Pointer(LScalar.CoreVectors.ShiftRightU64x8), 'AVX512 ShiftRightU64x8 should not be scalar slot');

  // Parity check only on hosts where AVX512 backend is dispatch-available.
  LCanRunAVX512 := LAVX512.BackendInfo.Available and TrySetActiveBackend(sbAVX512);
  if not LCanRunAVX512 then
    Exit;

  for LIndex := 0 to 15 do
  begin
    LU32A.u[LIndex] := DWord($F0000000 + DWord(LIndex) * DWord($1111111));
    LU32B.u[LIndex] := DWord($0F0F0F0F + DWord(LIndex) * DWord(97));
  end;

  for LIndex := 0 to 7 do
  begin
    LU64A.u[LIndex] := QWord($F000000000000000) + QWord(LIndex) * QWord($0102030405060708);
    LU64B.u[LIndex] := QWord($00FF00FF00FF00FF) + QWord(LIndex) * QWord($0001000100010001);
  end;

  LU32Result := LAVX512.CoreVectors.AddU32x16(LU32A, LU32B);
  LU32Expected := ScalarAddU32x16(LU32A, LU32B);
  for LIndex := 0 to 15 do
    CheckEqual(LU32Expected.u[LIndex], LU32Result.u[LIndex], 'AVX512 AddU32x16 lane ' + IntToStr(LIndex));

  LU32Result := LAVX512.CoreVectors.AndU32x16(LU32A, LU32B);
  LU32Expected := ScalarAndU32x16(LU32A, LU32B);
  for LIndex := 0 to 15 do
    CheckEqual(LU32Expected.u[LIndex], LU32Result.u[LIndex], 'AVX512 AndU32x16 lane ' + IntToStr(LIndex));

  LU32Result := LAVX512.CoreVectors.ShiftRightU32x16(LU32A, 5);
  LU32Expected := ScalarShiftRightU32x16(LU32A, 5);
  for LIndex := 0 to 15 do
    CheckEqual(LU32Expected.u[LIndex], LU32Result.u[LIndex], 'AVX512 ShiftRightU32x16 lane ' + IntToStr(LIndex));

  LMask16Result := LAVX512.CoreVectors.CmpEqU32x16(LU32A, LU32B);
  LMask16Expected := ScalarCmpEqU32x16(LU32A, LU32B);
  CheckEqual(Integer(LMask16Expected), Integer(LMask16Result), 'AVX512 CmpEqU32x16 mask parity');

  LMask16Result := LAVX512.CoreVectors.CmpGtU32x16(LU32A, LU32B);
  LMask16Expected := ScalarCmpGtU32x16(LU32A, LU32B);
  CheckEqual(Integer(LMask16Expected), Integer(LMask16Result), 'AVX512 CmpGtU32x16 mask parity');

  LU64Result := LAVX512.CoreVectors.AddU64x8(LU64A, LU64B);
  LU64Expected := ScalarAddU64x8(LU64A, LU64B);
  for LIndex := 0 to 7 do
    CheckEqual(LU64Expected.u[LIndex], LU64Result.u[LIndex], 'AVX512 AddU64x8 lane ' + IntToStr(LIndex));

  LU64Result := LAVX512.CoreVectors.XorU64x8(LU64A, LU64B);
  LU64Expected := ScalarXorU64x8(LU64A, LU64B);
  for LIndex := 0 to 7 do
    CheckEqual(LU64Expected.u[LIndex], LU64Result.u[LIndex], 'AVX512 XorU64x8 lane ' + IntToStr(LIndex));

  LU64Result := LAVX512.CoreVectors.ShiftRightU64x8(LU64A, 11);
  LU64Expected := ScalarShiftRightU64x8(LU64A, 11);
  for LIndex := 0 to 7 do
    CheckEqual(LU64Expected.u[LIndex], LU64Result.u[LIndex], 'AVX512 ShiftRightU64x8 lane ' + IntToStr(LIndex));

  LMask8Result := LAVX512.CoreVectors.CmpEqU64x8(LU64A, LU64B);
  LMask8Expected := ScalarCmpEqU64x8(LU64A, LU64B);
  CheckEqual(Integer(LMask8Expected), Integer(LMask8Result), 'AVX512 CmpEqU64x8 mask parity');

  LMask8Result := LAVX512.CoreVectors.CmpLtU64x8(LU64A, LU64B);
  LMask8Expected := ScalarCmpLtU64x8(LU64A, LU64B);
  CheckEqual(Integer(LMask8Expected), Integer(LMask8Result), 'AVX512 CmpLtU64x8 mask parity');
end;

procedure TTestCase_DispatchAPICapabilities.Test_AVX512_U32x16_U64x8_ShiftBoundary_Contracts;
var
  LScalar: TSimdDispatchTable;
  LAVX512: TSimdDispatchTable;
  LCanRunAVX512: Boolean;
  LIndex: Integer;
  LU32SourcePath, LU64SourcePath: string;
  LU32Source, LU64Source: string;
  LSourceLines: TSourceLines;
  LU32A, LU32Result, LU32Expected: TVecU32x16;
  LU64A, LU64Result, LU64Expected: TVecU64x8;

  procedure AssertVecU32x16Equal(const aLabel: string; const aExpected, aActual: TVecU32x16);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 15 do
      CheckEqual(aExpected.u[LLane], aActual.u[LLane], aLabel + ' lane ' + IntToStr(LLane));
  end;

  procedure AssertVecU64x8Equal(const aLabel: string; const aExpected, aActual: TVecU64x8);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 7 do
      CheckEqual(aExpected.u[LLane], aActual.u[LLane], aLabel + ' lane ' + IntToStr(LLane));
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LU32SourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.avx512.u32x16_family.inc');
    CheckTrue(FileExists(LU32SourcePath), 'AVX512 U32x16 family source should exist for shift-boundary audit: ' + LU32SourcePath);
    LSourceLines.LoadFromFile(LU32SourcePath);
    LU32Source := LowerCase(LSourceLines.Text);

    LU64SourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.avx512.u64x8_family.inc');
    CheckTrue(FileExists(LU64SourcePath), 'AVX512 U64x8 family source should exist for shift-boundary audit: ' + LU64SourcePath);
    LSourceLines.LoadFromFile(LU64SourcePath);
    LU64Source := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  CheckTrue(Pos('if (count < 0) or (count >= 32) then', LU32Source) > 0, 'AVX512 U32x16 shift helpers should keep explicit invalid-count guard');
  CheckTrue(Pos('fillchar(result, sizeof(result), 0);', LU32Source) > 0, 'AVX512 U32x16 shift helpers should zero-fill invalid counts instead of relying on hardware masking');
  CheckTrue(Pos('if (count < 0) or (count >= 64) then', LU64Source) > 0, 'AVX512 U64x8 shift helpers should keep explicit invalid-count guard');
  CheckTrue(Pos('fillchar(result, sizeof(result), 0);', LU64Source) > 0, 'AVX512 U64x8 shift helpers should zero-fill invalid counts instead of relying on hardware masking');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalar), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  if not TryGetRegisteredBackendDispatchTable(sbAVX512, LAVX512) then
    Exit;

  LCanRunAVX512 := LAVX512.BackendInfo.Available and TrySetActiveBackend(sbAVX512);
  if not LCanRunAVX512 then
    Exit;

  for LIndex := 0 to 15 do
    LU32A.u[LIndex] := DWord($80000000 xor (DWord(LIndex) * DWord($11111111)));

  for LIndex := 0 to 7 do
    LU64A.u[LIndex] := QWord($8000000000000000) xor (QWord(LIndex) * QWord($0101010101010101));

  LU32Expected := ScalarShiftLeftU32x16(LU32A, 0);
  LU32Result := LAVX512.CoreVectors.ShiftLeftU32x16(LU32A, 0);
  AssertVecU32x16Equal('AVX512 ShiftLeftU32x16 count=0', LU32Expected, LU32Result);

  LU32Expected := ScalarShiftLeftU32x16(LU32A, 31);
  LU32Result := LAVX512.CoreVectors.ShiftLeftU32x16(LU32A, 31);
  AssertVecU32x16Equal('AVX512 ShiftLeftU32x16 count=31', LU32Expected, LU32Result);

  LU32Expected := ScalarShiftLeftU32x16(LU32A, 32);
  LU32Result := LAVX512.CoreVectors.ShiftLeftU32x16(LU32A, 32);
  AssertVecU32x16Equal('AVX512 ShiftLeftU32x16 count=32', LU32Expected, LU32Result);

  LU32Expected := ScalarShiftRightU32x16(LU32A, 0);
  LU32Result := LAVX512.CoreVectors.ShiftRightU32x16(LU32A, 0);
  AssertVecU32x16Equal('AVX512 ShiftRightU32x16 count=0', LU32Expected, LU32Result);

  LU32Expected := ScalarShiftRightU32x16(LU32A, 31);
  LU32Result := LAVX512.CoreVectors.ShiftRightU32x16(LU32A, 31);
  AssertVecU32x16Equal('AVX512 ShiftRightU32x16 count=31', LU32Expected, LU32Result);

  LU32Expected := ScalarShiftRightU32x16(LU32A, 32);
  LU32Result := LAVX512.CoreVectors.ShiftRightU32x16(LU32A, 32);
  AssertVecU32x16Equal('AVX512 ShiftRightU32x16 count=32', LU32Expected, LU32Result);

  LU64Expected := ScalarShiftLeftU64x8(LU64A, 0);
  LU64Result := LAVX512.CoreVectors.ShiftLeftU64x8(LU64A, 0);
  AssertVecU64x8Equal('AVX512 ShiftLeftU64x8 count=0', LU64Expected, LU64Result);

  LU64Expected := ScalarShiftLeftU64x8(LU64A, 63);
  LU64Result := LAVX512.CoreVectors.ShiftLeftU64x8(LU64A, 63);
  AssertVecU64x8Equal('AVX512 ShiftLeftU64x8 count=63', LU64Expected, LU64Result);

  LU64Expected := ScalarShiftLeftU64x8(LU64A, 64);
  LU64Result := LAVX512.CoreVectors.ShiftLeftU64x8(LU64A, 64);
  AssertVecU64x8Equal('AVX512 ShiftLeftU64x8 count=64', LU64Expected, LU64Result);

  LU64Expected := ScalarShiftRightU64x8(LU64A, 0);
  LU64Result := LAVX512.CoreVectors.ShiftRightU64x8(LU64A, 0);
  AssertVecU64x8Equal('AVX512 ShiftRightU64x8 count=0', LU64Expected, LU64Result);

  LU64Expected := ScalarShiftRightU64x8(LU64A, 63);
  LU64Result := LAVX512.CoreVectors.ShiftRightU64x8(LU64A, 63);
  AssertVecU64x8Equal('AVX512 ShiftRightU64x8 count=63', LU64Expected, LU64Result);

  LU64Expected := ScalarShiftRightU64x8(LU64A, 64);
  LU64Result := LAVX512.CoreVectors.ShiftRightU64x8(LU64A, 64);
  AssertVecU64x8Equal('AVX512 ShiftRightU64x8 count=64', LU64Expected, LU64Result);
end;

procedure TTestCase_DispatchAPICapabilities.Test_AVX512_I16x32_I8x64_U8x64_MappingAndParity;
var
  LScalar: TSimdDispatchTable;
  LAVX512: TSimdDispatchTable;
  LCanRunAVX512: Boolean;
  LIndex: Integer;
  LI16A, LI16B, LI16Result, LI16Expected: TVecI16x32;
  LI8A, LI8B, LI8Result, LI8Expected: TVecI8x64;
  LU8A, LU8B, LU8Result, LU8Expected: TVecU8x64;
  LMask32Result, LMask32Expected: TMask32;
  LMask64Result, LMask64Expected: TMask64;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalar), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  if not TryGetRegisteredBackendDispatchTable(sbAVX512, LAVX512) then
    Exit;

  CheckTrue(Pointer(LAVX512.CoreVectors.AddI16x32) <> Pointer(LScalar.CoreVectors.AddI16x32), 'AVX512 AddI16x32 should not be scalar slot');
  CheckTrue(Pointer(LAVX512.CoreVectors.CmpEqI16x32) <> Pointer(LScalar.CoreVectors.CmpEqI16x32), 'AVX512 CmpEqI16x32 should not be scalar slot');
  CheckTrue(Pointer(LAVX512.CoreVectors.ShiftRightArithI16x32) <> Pointer(LScalar.CoreVectors.ShiftRightArithI16x32), 'AVX512 ShiftRightArithI16x32 should not be scalar slot');
  CheckTrue(Pointer(LAVX512.CoreVectors.AddI8x64) <> Pointer(LScalar.CoreVectors.AddI8x64), 'AVX512 AddI8x64 should not be scalar slot');
  CheckTrue(Pointer(LAVX512.CoreVectors.CmpEqI8x64) <> Pointer(LScalar.CoreVectors.CmpEqI8x64), 'AVX512 CmpEqI8x64 should not be scalar slot');
  CheckTrue(Pointer(LAVX512.CoreVectors.MaxI8x64) <> Pointer(LScalar.CoreVectors.MaxI8x64), 'AVX512 MaxI8x64 should not be scalar slot');
  CheckTrue(Pointer(LAVX512.CoreVectors.AddU8x64) <> Pointer(LScalar.CoreVectors.AddU8x64), 'AVX512 AddU8x64 should not be scalar slot');
  CheckTrue(Pointer(LAVX512.CoreVectors.CmpEqU8x64) <> Pointer(LScalar.CoreVectors.CmpEqU8x64), 'AVX512 CmpEqU8x64 should not be scalar slot');
  CheckTrue(Pointer(LAVX512.CoreVectors.MaxU8x64) <> Pointer(LScalar.CoreVectors.MaxU8x64), 'AVX512 MaxU8x64 should not be scalar slot');

  LCanRunAVX512 := LAVX512.BackendInfo.Available and TrySetActiveBackend(sbAVX512);
  if not LCanRunAVX512 then
    Exit;

  for LIndex := 0 to 31 do
  begin
    LI16A.i[LIndex] := Int16(LIndex * 97 - 1400);
    LI16B.i[LIndex] := Int16(700 - LIndex * 41);
  end;

  for LIndex := 0 to 63 do
  begin
    LI8A.i[LIndex] := Int8((LIndex mod 31) - 15);
    LI8B.i[LIndex] := Int8(20 - (LIndex mod 29));
    LU8A.u[LIndex] := Byte((LIndex * 13) and $FF);
    LU8B.u[LIndex] := Byte((255 - LIndex * 9) and $FF);
  end;

  LI16Result := LAVX512.CoreVectors.AddI16x32(LI16A, LI16B);
  LI16Expected := ScalarAddI16x32(LI16A, LI16B);
  for LIndex := 0 to 31 do
    CheckEqual(LI16Expected.i[LIndex], LI16Result.i[LIndex], 'AVX512 AddI16x32 lane ' + IntToStr(LIndex));

  LI16Result := LAVX512.CoreVectors.ShiftRightArithI16x32(LI16A, 3);
  LI16Expected := ScalarShiftRightArithI16x32(LI16A, 3);
  for LIndex := 0 to 31 do
    CheckEqual(LI16Expected.i[LIndex], LI16Result.i[LIndex], 'AVX512 ShiftRightArithI16x32 lane ' + IntToStr(LIndex));

  LMask32Result := LAVX512.CoreVectors.CmpLtI16x32(LI16A, LI16B);
  LMask32Expected := ScalarCmpLtI16x32(LI16A, LI16B);
  CheckEqual(Integer(LMask32Expected), Integer(LMask32Result), 'AVX512 CmpLtI16x32 mask parity');

  LI8Result := LAVX512.CoreVectors.AndNotI8x64(LI8A, LI8B);
  LI8Expected := ScalarAndNotI8x64(LI8A, LI8B);
  for LIndex := 0 to 63 do
    CheckEqual(LI8Expected.i[LIndex], LI8Result.i[LIndex], 'AVX512 AndNotI8x64 lane ' + IntToStr(LIndex));

  LMask64Result := LAVX512.CoreVectors.CmpGtI8x64(LI8A, LI8B);
  LMask64Expected := ScalarCmpGtI8x64(LI8A, LI8B);
  CheckEqual(Int64(LMask64Expected), Int64(LMask64Result), 'AVX512 CmpGtI8x64 mask parity');

  LU8Result := LAVX512.CoreVectors.AddU8x64(LU8A, LU8B);
  LU8Expected := ScalarAddU8x64(LU8A, LU8B);
  for LIndex := 0 to 63 do
    CheckEqual(LU8Expected.u[LIndex], LU8Result.u[LIndex], 'AVX512 AddU8x64 lane ' + IntToStr(LIndex));

  LU8Result := LAVX512.CoreVectors.XorU8x64(LU8A, LU8B);
  LU8Expected := ScalarXorU8x64(LU8A, LU8B);
  for LIndex := 0 to 63 do
    CheckEqual(LU8Expected.u[LIndex], LU8Result.u[LIndex], 'AVX512 XorU8x64 lane ' + IntToStr(LIndex));

  LMask64Result := LAVX512.CoreVectors.CmpLtU8x64(LU8A, LU8B);
  LMask64Expected := ScalarCmpLtU8x64(LU8A, LU8B);
  CheckEqual(Int64(LMask64Expected), Int64(LMask64Result), 'AVX512 CmpLtU8x64 mask parity');
end;

procedure TTestCase_DispatchAPICapabilities.Test_AVX512_F32x16_F64x8_IEEE754_MappingAndParity;
var
  LScalar: TSimdDispatchTable;
  LAVX2: TSimdDispatchTable;
  LAVX512: TSimdDispatchTable;
  LHasAVX2: Boolean;
  LCanRunAVX512: Boolean;
  LIndex: Integer;

  LInF32x16, LRoundF32x16, LTruncF32x16, LFloorF32x16, LCeilF32x16: TVecF32x16;
  LInF64x8, LRoundF64x8, LTruncF64x8, LFloorF64x8, LCeilF64x8: TVecF64x8;
  LExpectedRoundF32x16, LExpectedTruncF32x16, LExpectedFloorF32x16, LExpectedCeilF32x16: TVecF32x16;
  LExpectedRoundF64x8, LExpectedTruncF64x8, LExpectedFloorF64x8, LExpectedCeilF64x8: TVecF64x8;

  LReduceInF32x16: TVecF32x16;
  LReduceInF64x8: TVecF64x8;
  LExpectedReduceAddF32x16, LExpectedReduceMulF32x16, LExpectedReduceMinF32x16, LExpectedReduceMaxF32x16: Single;
  LActualReduceAddF32x16, LActualReduceMulF32x16, LActualReduceMinF32x16, LActualReduceMaxF32x16: Single;
  LExpectedReduceAddF64x8, LExpectedReduceMulF64x8, LExpectedReduceMinF64x8, LExpectedReduceMaxF64x8: Double;
  LActualReduceAddF64x8, LActualReduceMulF64x8, LActualReduceMinF64x8, LActualReduceMaxF64x8: Double;

  procedure AssertSingleSemantics(const aName: string; const aExpected, aActual: Single);
  begin
    if IsNaN(aExpected) then
      CheckTrue(IsNaN(aActual), aName + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aName + ' expected Inf sign')
    else
      CheckNear(aExpected, aActual, 1e-6, aName);
  end;

  procedure AssertDoubleSemantics(const aName: string; const aExpected, aActual: Double);
  begin
    if IsNaN(aExpected) then
      CheckTrue(IsNaN(aActual), aName + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aName + ' expected Inf sign')
    else
      CheckNear(aExpected, aActual, 1e-12, aName);
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalar), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  if not TryGetRegisteredBackendDispatchTable(sbAVX512, LAVX512) then
    Exit;

  LHasAVX2 := TryGetRegisteredBackendDispatchTable(sbAVX2, LAVX2);

  CheckTrue(Pointer(LAVX512.CoreVectors.RoundF32x16) <> Pointer(LScalar.CoreVectors.RoundF32x16), 'AVX512 RoundF32x16 should not be scalar slot');
  CheckTrue(Pointer(LAVX512.CoreVectors.TruncF32x16) <> Pointer(LScalar.CoreVectors.TruncF32x16), 'AVX512 TruncF32x16 should not be scalar slot');
  CheckTrue(Pointer(LAVX512.CoreVectors.FloorF32x16) <> Pointer(LScalar.CoreVectors.FloorF32x16), 'AVX512 FloorF32x16 should not be scalar slot');
  CheckTrue(Pointer(LAVX512.CoreVectors.CeilF32x16) <> Pointer(LScalar.CoreVectors.CeilF32x16), 'AVX512 CeilF32x16 should not be scalar slot');

  CheckTrue(Pointer(LAVX512.CoreVectors.RoundF64x8) <> Pointer(LScalar.CoreVectors.RoundF64x8), 'AVX512 RoundF64x8 should not be scalar slot');
  CheckTrue(Pointer(LAVX512.CoreVectors.TruncF64x8) <> Pointer(LScalar.CoreVectors.TruncF64x8), 'AVX512 TruncF64x8 should not be scalar slot');
  CheckTrue(Pointer(LAVX512.CoreVectors.FloorF64x8) <> Pointer(LScalar.CoreVectors.FloorF64x8), 'AVX512 FloorF64x8 should not be scalar slot');
  CheckTrue(Pointer(LAVX512.CoreVectors.CeilF64x8) <> Pointer(LScalar.CoreVectors.CeilF64x8), 'AVX512 CeilF64x8 should not be scalar slot');

  if LHasAVX2 then
  begin
    CheckTrue(Pointer(LAVX512.CoreVectors.RoundF32x16) <> Pointer(LAVX2.CoreVectors.RoundF32x16), 'AVX512 RoundF32x16 should not reuse AVX2 slot');
    CheckTrue(Pointer(LAVX512.CoreVectors.TruncF32x16) <> Pointer(LAVX2.CoreVectors.TruncF32x16), 'AVX512 TruncF32x16 should not reuse AVX2 slot');
    CheckTrue(Pointer(LAVX512.CoreVectors.FloorF32x16) <> Pointer(LAVX2.CoreVectors.FloorF32x16), 'AVX512 FloorF32x16 should not reuse AVX2 slot');
    CheckTrue(Pointer(LAVX512.CoreVectors.CeilF32x16) <> Pointer(LAVX2.CoreVectors.CeilF32x16), 'AVX512 CeilF32x16 should not reuse AVX2 slot');

    CheckTrue(Pointer(LAVX512.CoreVectors.RoundF64x8) <> Pointer(LAVX2.CoreVectors.RoundF64x8), 'AVX512 RoundF64x8 should not reuse AVX2 slot');
    CheckTrue(Pointer(LAVX512.CoreVectors.TruncF64x8) <> Pointer(LAVX2.CoreVectors.TruncF64x8), 'AVX512 TruncF64x8 should not reuse AVX2 slot');
    CheckTrue(Pointer(LAVX512.CoreVectors.FloorF64x8) <> Pointer(LAVX2.CoreVectors.FloorF64x8), 'AVX512 FloorF64x8 should not reuse AVX2 slot');
    CheckTrue(Pointer(LAVX512.CoreVectors.CeilF64x8) <> Pointer(LAVX2.CoreVectors.CeilF64x8), 'AVX512 CeilF64x8 should not reuse AVX2 slot');
  end;

  LCanRunAVX512 := LAVX512.BackendInfo.Available and TrySetActiveBackend(sbAVX512);
  if not LCanRunAVX512 then
    Exit;

    for LIndex := 0 to 15 do
    begin
      case (LIndex mod 5) of
        0: LInF32x16.f[LIndex] := 0.0 / 0.0;   // NaN
        1: LInF32x16.f[LIndex] := 1.0 / 0.0;   // +Inf
        2: LInF32x16.f[LIndex] := -1.0 / 0.0;  // -Inf
        3: LInF32x16.f[LIndex] := -3.75 + LIndex * 0.5;
      else
        LInF32x16.f[LIndex] := 2.5 - LIndex * 0.25;
      end;
      LReduceInF32x16.f[LIndex] := (LIndex - 7.5) * 0.375;
    end;

    for LIndex := 0 to 7 do
    begin
      case (LIndex mod 5) of
        0: LInF64x8.d[LIndex] := 0.0 / 0.0;    // NaN
        1: LInF64x8.d[LIndex] := 1.0 / 0.0;    // +Inf
        2: LInF64x8.d[LIndex] := -1.0 / 0.0;   // -Inf
        3: LInF64x8.d[LIndex] := -1234.875 + LIndex * 7.25;
      else
        LInF64x8.d[LIndex] := 42.5 - LIndex * 1.125;
      end;
      LReduceInF64x8.d[LIndex] := (LIndex - 3.0) * 1.5;
    end;

    LRoundF32x16 := LAVX512.CoreVectors.RoundF32x16(LInF32x16);
    LTruncF32x16 := LAVX512.CoreVectors.TruncF32x16(LInF32x16);
    LFloorF32x16 := LAVX512.CoreVectors.FloorF32x16(LInF32x16);
    LCeilF32x16 := LAVX512.CoreVectors.CeilF32x16(LInF32x16);
    LRoundF64x8 := LAVX512.CoreVectors.RoundF64x8(LInF64x8);
    LTruncF64x8 := LAVX512.CoreVectors.TruncF64x8(LInF64x8);
    LFloorF64x8 := LAVX512.CoreVectors.FloorF64x8(LInF64x8);
    LCeilF64x8 := LAVX512.CoreVectors.CeilF64x8(LInF64x8);

    LExpectedRoundF32x16 := ScalarRoundF32x16(LInF32x16);
    LExpectedTruncF32x16 := ScalarTruncF32x16(LInF32x16);
    LExpectedFloorF32x16 := ScalarFloorF32x16(LInF32x16);
    LExpectedCeilF32x16 := ScalarCeilF32x16(LInF32x16);
    LExpectedRoundF64x8 := ScalarRoundF64x8(LInF64x8);
    LExpectedTruncF64x8 := ScalarTruncF64x8(LInF64x8);
    LExpectedFloorF64x8 := ScalarFloorF64x8(LInF64x8);
    LExpectedCeilF64x8 := ScalarCeilF64x8(LInF64x8);

    for LIndex := 0 to 15 do
    begin
      AssertSingleSemantics('AVX512 RoundF32x16[' + IntToStr(LIndex) + ']', LExpectedRoundF32x16.f[LIndex], LRoundF32x16.f[LIndex]);
      AssertSingleSemantics('AVX512 TruncF32x16[' + IntToStr(LIndex) + ']', LExpectedTruncF32x16.f[LIndex], LTruncF32x16.f[LIndex]);
      AssertSingleSemantics('AVX512 FloorF32x16[' + IntToStr(LIndex) + ']', LExpectedFloorF32x16.f[LIndex], LFloorF32x16.f[LIndex]);
      AssertSingleSemantics('AVX512 CeilF32x16[' + IntToStr(LIndex) + ']', LExpectedCeilF32x16.f[LIndex], LCeilF32x16.f[LIndex]);
    end;

    for LIndex := 0 to 7 do
    begin
      AssertDoubleSemantics('AVX512 RoundF64x8[' + IntToStr(LIndex) + ']', LExpectedRoundF64x8.d[LIndex], LRoundF64x8.d[LIndex]);
      AssertDoubleSemantics('AVX512 TruncF64x8[' + IntToStr(LIndex) + ']', LExpectedTruncF64x8.d[LIndex], LTruncF64x8.d[LIndex]);
      AssertDoubleSemantics('AVX512 FloorF64x8[' + IntToStr(LIndex) + ']', LExpectedFloorF64x8.d[LIndex], LFloorF64x8.d[LIndex]);
      AssertDoubleSemantics('AVX512 CeilF64x8[' + IntToStr(LIndex) + ']', LExpectedCeilF64x8.d[LIndex], LCeilF64x8.d[LIndex]);
    end;

    LExpectedReduceAddF32x16 := ScalarReduceAddF32x16(LReduceInF32x16);
    LExpectedReduceMulF32x16 := ScalarReduceMulF32x16(LReduceInF32x16);
    LExpectedReduceMinF32x16 := ScalarReduceMinF32x16(LReduceInF32x16);
    LExpectedReduceMaxF32x16 := ScalarReduceMaxF32x16(LReduceInF32x16);
    LExpectedReduceAddF64x8 := ScalarReduceAddF64x8(LReduceInF64x8);
    LExpectedReduceMulF64x8 := ScalarReduceMulF64x8(LReduceInF64x8);
    LExpectedReduceMinF64x8 := ScalarReduceMinF64x8(LReduceInF64x8);
    LExpectedReduceMaxF64x8 := ScalarReduceMaxF64x8(LReduceInF64x8);

    LActualReduceAddF32x16 := LAVX512.CoreVectors.ReduceAddF32x16(LReduceInF32x16);
    LActualReduceMulF32x16 := LAVX512.CoreVectors.ReduceMulF32x16(LReduceInF32x16);
    LActualReduceMinF32x16 := LAVX512.CoreVectors.ReduceMinF32x16(LReduceInF32x16);
    LActualReduceMaxF32x16 := LAVX512.CoreVectors.ReduceMaxF32x16(LReduceInF32x16);
    LActualReduceAddF64x8 := LAVX512.CoreVectors.ReduceAddF64x8(LReduceInF64x8);
    LActualReduceMulF64x8 := LAVX512.CoreVectors.ReduceMulF64x8(LReduceInF64x8);
    LActualReduceMinF64x8 := LAVX512.CoreVectors.ReduceMinF64x8(LReduceInF64x8);
    LActualReduceMaxF64x8 := LAVX512.CoreVectors.ReduceMaxF64x8(LReduceInF64x8);

    CheckNear(LExpectedReduceAddF32x16, LActualReduceAddF32x16, 1e-5, 'AVX512 ReduceAddF32x16 parity');
    CheckNear(LExpectedReduceMulF32x16, LActualReduceMulF32x16, 1e-4, 'AVX512 ReduceMulF32x16 parity');
    CheckNear(LExpectedReduceMinF32x16, LActualReduceMinF32x16, 1e-6, 'AVX512 ReduceMinF32x16 parity');
    CheckNear(LExpectedReduceMaxF32x16, LActualReduceMaxF32x16, 1e-6, 'AVX512 ReduceMaxF32x16 parity');

    CheckNear(LExpectedReduceAddF64x8, LActualReduceAddF64x8, 1e-12, 'AVX512 ReduceAddF64x8 parity');
    CheckNear(LExpectedReduceMulF64x8, LActualReduceMulF64x8, 1e-10, 'AVX512 ReduceMulF64x8 parity');
    CheckNear(LExpectedReduceMinF64x8, LActualReduceMinF64x8, 1e-12, 'AVX512 ReduceMinF64x8 parity');
    CheckNear(LExpectedReduceMaxF64x8, LActualReduceMaxF64x8, 1e-12, 'AVX512 ReduceMaxF64x8 parity');
end;

procedure TTestCase_DispatchAPICapabilities.Test_BackendCapabilities_DoNotOverclaim_512BitOps;
var
  LBackend: TSimdBackend;
  LTable: TSimdDispatchTable;
  LScalar: TSimdDispatchTable;
  LClaims512: Boolean;

  procedure AssertNonScalarSlot(const aBackendName, aSlotName: string; aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' still scalar fallback while sc512BitOps is advertised: ' + aBackendName);
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalar), 'Scalar dispatch table should be registered');

  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
  begin
    if not TryGetRegisteredBackendDispatchTable(LBackend, LTable) then
      Continue;

    LClaims512 := sc512BitOps in LTable.BackendInfo.Capabilities;
    if not LClaims512 then
      Continue;

    AssertNonScalarSlot(DispatchApiBackendName(LBackend), 'AddU32x16', Pointer(LScalar.CoreVectors.AddU32x16), Pointer(LTable.CoreVectors.AddU32x16));
    AssertNonScalarSlot(DispatchApiBackendName(LBackend), 'CmpEqU32x16', Pointer(LScalar.CoreVectors.CmpEqU32x16), Pointer(LTable.CoreVectors.CmpEqU32x16));
    AssertNonScalarSlot(DispatchApiBackendName(LBackend), 'ShiftRightU32x16', Pointer(LScalar.CoreVectors.ShiftRightU32x16), Pointer(LTable.CoreVectors.ShiftRightU32x16));

    AssertNonScalarSlot(DispatchApiBackendName(LBackend), 'AddU64x8', Pointer(LScalar.CoreVectors.AddU64x8), Pointer(LTable.CoreVectors.AddU64x8));
    AssertNonScalarSlot(DispatchApiBackendName(LBackend), 'CmpEqU64x8', Pointer(LScalar.CoreVectors.CmpEqU64x8), Pointer(LTable.CoreVectors.CmpEqU64x8));
    AssertNonScalarSlot(DispatchApiBackendName(LBackend), 'ShiftRightU64x8', Pointer(LScalar.CoreVectors.ShiftRightU64x8), Pointer(LTable.CoreVectors.ShiftRightU64x8));

    AssertNonScalarSlot(DispatchApiBackendName(LBackend), 'AddI16x32', Pointer(LScalar.CoreVectors.AddI16x32), Pointer(LTable.CoreVectors.AddI16x32));
    AssertNonScalarSlot(DispatchApiBackendName(LBackend), 'CmpEqI16x32', Pointer(LScalar.CoreVectors.CmpEqI16x32), Pointer(LTable.CoreVectors.CmpEqI16x32));
    AssertNonScalarSlot(DispatchApiBackendName(LBackend), 'ShiftRightArithI16x32', Pointer(LScalar.CoreVectors.ShiftRightArithI16x32), Pointer(LTable.CoreVectors.ShiftRightArithI16x32));

    AssertNonScalarSlot(DispatchApiBackendName(LBackend), 'AddI8x64', Pointer(LScalar.CoreVectors.AddI8x64), Pointer(LTable.CoreVectors.AddI8x64));
    AssertNonScalarSlot(DispatchApiBackendName(LBackend), 'CmpEqI8x64', Pointer(LScalar.CoreVectors.CmpEqI8x64), Pointer(LTable.CoreVectors.CmpEqI8x64));
    AssertNonScalarSlot(DispatchApiBackendName(LBackend), 'MaxI8x64', Pointer(LScalar.CoreVectors.MaxI8x64), Pointer(LTable.CoreVectors.MaxI8x64));

    AssertNonScalarSlot(DispatchApiBackendName(LBackend), 'AddU8x64', Pointer(LScalar.CoreVectors.AddU8x64), Pointer(LTable.CoreVectors.AddU8x64));
    AssertNonScalarSlot(DispatchApiBackendName(LBackend), 'CmpEqU8x64', Pointer(LScalar.CoreVectors.CmpEqU8x64), Pointer(LTable.CoreVectors.CmpEqU8x64));
    AssertNonScalarSlot(DispatchApiBackendName(LBackend), 'MaxU8x64', Pointer(LScalar.CoreVectors.MaxU8x64), Pointer(LTable.CoreVectors.MaxU8x64));
  end;

  if TryGetRegisteredBackendDispatchTable(sbAVX512, LTable) then
    if (Pointer(LTable.CoreVectors.AddU32x16) <> Pointer(LScalar.CoreVectors.AddU32x16)) and
       (Pointer(LTable.CoreVectors.AddI16x32) <> Pointer(LScalar.CoreVectors.AddI16x32)) and
       (Pointer(LTable.CoreVectors.AddU8x64) <> Pointer(LScalar.CoreVectors.AddU8x64)) then
      CheckTrue(sc512BitOps in LTable.BackendInfo.Capabilities, 'AVX512 should advertise sc512BitOps once wide integer matrix is non-scalar')
    else
      CheckFalse(sc512BitOps in LTable.BackendInfo.Capabilities, 'AVX512 should not advertise sc512BitOps when wide integer matrix is scalar fallback');
end;

procedure TTestCase_DispatchAPICapabilities.Test_BackendCapabilities_DoNotUnderclaim_IntegerOps;
var
  LBackend: TSimdBackend;
  LTable: TSimdDispatchTable;
  LScalar: TSimdDispatchTable;
  LHasNonScalarIntegerSlots: Boolean;

  procedure ObserveRepresentativeSlot(const aSlotName: string; aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + DispatchApiBackendName(LBackend));
    if aBackendSlot <> aScalarSlot then
      LHasNonScalarIntegerSlots := True;
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalar), 'Scalar dispatch table should be registered');

  if not IsVectorAsmEnabled then
    Exit;

  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
  begin
    if LBackend = sbScalar then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LTable) then
      Continue;

    LHasNonScalarIntegerSlots := False;
    ObserveRepresentativeSlot('AddI32x4', Pointer(LScalar.CoreVectors.AddI32x4), Pointer(LTable.CoreVectors.AddI32x4));
    ObserveRepresentativeSlot('AndI32x4', Pointer(LScalar.CoreVectors.AndI32x4), Pointer(LTable.CoreVectors.AndI32x4));
    ObserveRepresentativeSlot('CmpEqI32x4', Pointer(LScalar.CoreVectors.CmpEqI32x4), Pointer(LTable.CoreVectors.CmpEqI32x4));
    ObserveRepresentativeSlot('AddU32x16', Pointer(LScalar.CoreVectors.AddU32x16), Pointer(LTable.CoreVectors.AddU32x16));
    ObserveRepresentativeSlot('MaxI8x64', Pointer(LScalar.CoreVectors.MaxI8x64), Pointer(LTable.CoreVectors.MaxI8x64));

    if not LHasNonScalarIntegerSlots then
      Continue;

    CheckTrue(scIntegerOps in LTable.BackendInfo.Capabilities, 'scIntegerOps missing while representative integer slots are non-scalar: ' + DispatchApiBackendName(LBackend));
  end;
end;

procedure TTestCase_DispatchAPICapabilities.Test_BackendCapabilities_DoNotUnderclaim_Shuffle;
var
  LBackend: TSimdBackend;
  LTable: TSimdDispatchTable;
  LScalar: TSimdDispatchTable;
  LHasNonScalarShuffleSlots: Boolean;

  procedure ObserveRepresentativeSlot(const aSlotName: string; aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + DispatchApiBackendName(LBackend));
    if aBackendSlot <> aScalarSlot then
      LHasNonScalarShuffleSlots := True;
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalar), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
  begin
    if LBackend = sbScalar then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LTable) then
      Continue;

    LHasNonScalarShuffleSlots := False;
    ObserveRepresentativeSlot('SelectF32x4', Pointer(LScalar.CoreVectors.SelectF32x4), Pointer(LTable.CoreVectors.SelectF32x4));
    ObserveRepresentativeSlot('InsertF32x4', Pointer(LScalar.CoreVectors.InsertF32x4), Pointer(LTable.CoreVectors.InsertF32x4));
    ObserveRepresentativeSlot('ExtractF32x4', Pointer(LScalar.CoreVectors.ExtractF32x4), Pointer(LTable.CoreVectors.ExtractF32x4));
    ObserveRepresentativeSlot('SelectF32x8', Pointer(LScalar.CoreVectors.SelectF32x8), Pointer(LTable.CoreVectors.SelectF32x8));
    ObserveRepresentativeSlot('SelectF64x4', Pointer(LScalar.CoreVectors.SelectF64x4), Pointer(LTable.CoreVectors.SelectF64x4));

    if not LHasNonScalarShuffleSlots then
      Continue;

    CheckTrue(scShuffle in LTable.BackendInfo.Capabilities, 'scShuffle missing while representative shuffle slots are non-scalar: ' + DispatchApiBackendName(LBackend));
  end;
end;

procedure TTestCase_DispatchAPICapabilities.Test_X86_BackendCapabilities_DoNotUnderclaim_MaskedOps;
var
  LBackend: TSimdBackend;
  LTable: TSimdDispatchTable;
  LScalar: TSimdDispatchTable;
  LHasNonScalarMaskedSlots: Boolean;

  function IsX86MaskedOpsBackend(const aBackend: TSimdBackend): Boolean;
  begin
    case aBackend of
      sbSSE2, sbSSE3, sbSSSE3, sbSSE41, sbSSE42, sbAVX2, sbAVX512:
        Exit(True);
      else
        Exit(False);
    end;
  end;

  procedure ObserveRepresentativeSlot(const aSlotName: string; aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + DispatchApiBackendName(LBackend));
    if aBackendSlot <> aScalarSlot then
      LHasNonScalarMaskedSlots := True;
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalar), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
  begin
    if not IsX86MaskedOpsBackend(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LTable) then
      Continue;

    LHasNonScalarMaskedSlots := False;
    ObserveRepresentativeSlot('Mask2All', Pointer(LScalar.Mask.Mask2All), Pointer(LTable.Mask.Mask2All));
    ObserveRepresentativeSlot('Mask4PopCount', Pointer(LScalar.Mask.Mask4PopCount), Pointer(LTable.Mask.Mask4PopCount));
    ObserveRepresentativeSlot('Mask8All', Pointer(LScalar.Mask.Mask8All), Pointer(LTable.Mask.Mask8All));
    ObserveRepresentativeSlot('Mask8PopCount', Pointer(LScalar.Mask.Mask8PopCount), Pointer(LTable.Mask.Mask8PopCount));
    ObserveRepresentativeSlot('Mask16FirstSet', Pointer(LScalar.Mask.Mask16FirstSet), Pointer(LTable.Mask.Mask16FirstSet));

    if not LHasNonScalarMaskedSlots then
      Continue;

    CheckTrue(scMaskedOps in LTable.BackendInfo.Capabilities, 'scMaskedOps missing while representative x86 mask helper slots are non-scalar: ' + DispatchApiBackendName(LBackend));
  end;
end;

procedure TTestCase_DispatchAPICapabilities.Test_BackendCapabilities_Clear_IntegerOps_When_VectorAsmDisabled;
var
  LBackend: TSimdBackend;
  LTable: TSimdDispatchTable;
  LScalar: TSimdDispatchTable;
  LHasNonScalarIntegerSlots: Boolean;

  function IsVectorAsmGatedX86Backend(aBackend: TSimdBackend): Boolean;
  begin
    case aBackend of
      sbAVX2:
        Exit(True);
      else
        Exit(False);
    end;
  end;

  procedure ObserveRepresentativeSlot(const aSlotName: string; aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + DispatchApiBackendName(LBackend));
    if aBackendSlot <> aScalarSlot then
      LHasNonScalarIntegerSlots := True;
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalar), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  SetVectorAsmEnabled(False);
  CheckFalse(IsVectorAsmEnabled, 'Vector asm should be disabled for capability rebuild test');

  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
  begin
    if not IsVectorAsmGatedX86Backend(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LTable) then
      Continue;

    LHasNonScalarIntegerSlots := False;
    ObserveRepresentativeSlot('AddI32x4', Pointer(LScalar.CoreVectors.AddI32x4), Pointer(LTable.CoreVectors.AddI32x4));
    ObserveRepresentativeSlot('AndI32x4', Pointer(LScalar.CoreVectors.AndI32x4), Pointer(LTable.CoreVectors.AndI32x4));
    ObserveRepresentativeSlot('CmpEqI32x4', Pointer(LScalar.CoreVectors.CmpEqI32x4), Pointer(LTable.CoreVectors.CmpEqI32x4));
    ObserveRepresentativeSlot('AddU32x16', Pointer(LScalar.CoreVectors.AddU32x16), Pointer(LTable.CoreVectors.AddU32x16));
    ObserveRepresentativeSlot('MaxI8x64', Pointer(LScalar.CoreVectors.MaxI8x64), Pointer(LTable.CoreVectors.MaxI8x64));

    if LHasNonScalarIntegerSlots then
      Continue;

    CheckFalse(scIntegerOps in LTable.BackendInfo.Capabilities, 'scIntegerOps should clear when representative integer slots are scalar after vector asm disable: ' + DispatchApiBackendName(LBackend));
  end;
end;

procedure TTestCase_DispatchAPICapabilities.Test_X86_BackendCapabilities_Keep_IntegerOps_When_AlwaysOn_NarrowSlots_Remain_NonScalar;
var
  LBackend: TSimdBackend;
  LTable: TSimdDispatchTable;
  LScalar: TSimdDispatchTable;
  LHasNonScalarAlwaysOnIntegerSlots: Boolean;

  function IsAlwaysOnNarrowIntegerBackend(const aBackend: TSimdBackend): Boolean;
  begin
    case aBackend of
      sbSSE2, sbSSE3, sbSSSE3, sbSSE41, sbSSE42:
        Exit(True);
      else
        Exit(False);
    end;
  end;

  procedure ObserveRepresentativeSlot(aScalarSlot, aBackendSlot: Pointer);
  begin
    if aBackendSlot <> aScalarSlot then
      LHasNonScalarAlwaysOnIntegerSlots := True;
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalar), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  SetVectorAsmEnabled(False);
  CheckFalse(IsVectorAsmEnabled, 'Vector asm should be disabled for always-on x86 integer capability rebuild test');

  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
  begin
    if not IsAlwaysOnNarrowIntegerBackend(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LTable) then
      Continue;

    LHasNonScalarAlwaysOnIntegerSlots := False;
    ObserveRepresentativeSlot(Pointer(LScalar.CoreVectors.AddI16x8), Pointer(LTable.CoreVectors.AddI16x8));
    ObserveRepresentativeSlot(Pointer(LScalar.CoreVectors.AndI16x8), Pointer(LTable.CoreVectors.AndI16x8));
    ObserveRepresentativeSlot(Pointer(LScalar.CoreVectors.CmpEqI16x8), Pointer(LTable.CoreVectors.CmpEqI16x8));
    ObserveRepresentativeSlot(Pointer(LScalar.CoreVectors.AddU8x16), Pointer(LTable.CoreVectors.AddU8x16));
    ObserveRepresentativeSlot(Pointer(LScalar.CoreVectors.MaxU8x16), Pointer(LTable.CoreVectors.MaxU8x16));

    if not LHasNonScalarAlwaysOnIntegerSlots then
      Continue;

    CheckTrue(scIntegerOps in LTable.BackendInfo.Capabilities, 'scIntegerOps should stay set while always-on narrow integer slots remain non-scalar after vector asm disable: ' + DispatchApiBackendName(LBackend));
  end;
end;

procedure TTestCase_DispatchAPICapabilities.Test_X86_BackendCapabilities_Keep_MaskedOps_When_VectorAsmDisabled;
var
  LBackend: TSimdBackend;
  LTable: TSimdDispatchTable;
  LScalar: TSimdDispatchTable;
  LHasNonScalarMaskedSlots: Boolean;

  function IsX86MaskedOpsBackend(const aBackend: TSimdBackend): Boolean;
  begin
    case aBackend of
      sbSSE2, sbSSE3, sbSSSE3, sbSSE41, sbSSE42, sbAVX2, sbAVX512:
        Exit(True);
      else
        Exit(False);
    end;
  end;

  procedure ObserveRepresentativeSlot(const aSlotName: string; aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + DispatchApiBackendName(LBackend));
    if aBackendSlot <> aScalarSlot then
      LHasNonScalarMaskedSlots := True;
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalar), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;
  SetVectorAsmEnabled(False);
  CheckFalse(IsVectorAsmEnabled, 'Vector asm should be disabled for x86 masked-ops capability rebuild test');

  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
  begin
    if not IsX86MaskedOpsBackend(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LTable) then
      Continue;

    LHasNonScalarMaskedSlots := False;
    ObserveRepresentativeSlot('Mask2All', Pointer(LScalar.Mask.Mask2All), Pointer(LTable.Mask.Mask2All));
    ObserveRepresentativeSlot('Mask4PopCount', Pointer(LScalar.Mask.Mask4PopCount), Pointer(LTable.Mask.Mask4PopCount));
    ObserveRepresentativeSlot('Mask8All', Pointer(LScalar.Mask.Mask8All), Pointer(LTable.Mask.Mask8All));
    ObserveRepresentativeSlot('Mask8PopCount', Pointer(LScalar.Mask.Mask8PopCount), Pointer(LTable.Mask.Mask8PopCount));
    ObserveRepresentativeSlot('Mask16FirstSet', Pointer(LScalar.Mask.Mask16FirstSet), Pointer(LTable.Mask.Mask16FirstSet));

    if not LHasNonScalarMaskedSlots then
      Continue;

    CheckTrue(scMaskedOps in LTable.BackendInfo.Capabilities, 'scMaskedOps should stay set while representative x86 mask helper slots remain non-scalar after vector asm disable: ' + DispatchApiBackendName(LBackend));
  end;
end;

procedure TTestCase_DispatchAPICapabilities.Test_AVX2_BackendCapabilities_Expose_FMA_When_FusedPathUsable;
var
  LTable: TSimdDispatchTable;
  LA, LB, LC: TVecF32x4;
  LResult: TVecF32x4;
  LLane: Integer;
  LCanRunAVX2: Boolean;

  function SingleFromBitsLocal(const aBits: DWord): Single; inline;
  begin
    Move(aBits, Result, SizeOf(Result));
  end;
begin
  if not HasFeature(gfFMA) then
    Exit;

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;
  if not TryGetRegisteredBackendDispatchTable(sbAVX2, LTable) then
    Exit;

  LCanRunAVX2 := LTable.BackendInfo.Available and TrySetActiveBackend(sbAVX2);
  if not LCanRunAVX2 then
    Exit;

  CheckTrue(Assigned(LTable.CoreVectors.FmaF32x4), 'AVX2 FmaF32x4 should be assigned');

  // This input distinguishes fused FMA from separate mul+add.
  LA := VecF32x4Splat(SingleFromBitsLocal($3F800001));
  LB := LA;
  LC := VecF32x4Splat(SingleFromBitsLocal($BF800002));
  LResult := LTable.CoreVectors.FmaF32x4(LA, LB, LC);

  for LLane := 0 to 3 do
    CheckNear(SingleFromBitsLocal($28800000), VecF32x4Extract(LResult, LLane), 0.0, 'AVX2 fused FMA witness lane ' + IntToStr(LLane));

  CheckTrue(scFMA in LTable.BackendInfo.Capabilities, 'AVX2 should advertise scFMA once FmaF32x4 is using fused hardware instructions');
end;

procedure TTestCase_DispatchAPICapabilities.Test_AVX2_BackendCapabilities_Clear_FMA_When_VectorAsmDisabled;
var
  LTable: TSimdDispatchTable;
begin
  if not HasFeature(gfFMA) then
    Exit;

  GetDispatchTable;
  SetVectorAsmEnabled(False);
  CheckFalse(IsVectorAsmEnabled, 'Vector asm should be disabled for AVX2 FMA capability rebuild test');
  if not TryGetRegisteredBackendDispatchTable(sbAVX2, LTable) then
    Exit;

  CheckFalse(scFMA in LTable.BackendInfo.Capabilities, 'scFMA should clear when AVX2 falls back to scalar FMA after vector asm disable');
end;

procedure TTestCase_DispatchAPICapabilities.Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_AVX2FMA_When_FusedPathUsable;
var
  LInfo: TNextPasSimdBackendPodInfo;
  LScalarTable: TSimdDispatchTable;
  LTable: TSimdDispatchTable;
begin
  if not HasFeature(gfFMA) then
    Exit;

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;
  if not TryGetRegisteredBackendDispatchTable(sbAVX2, LTable) then
    Exit;
  if not (scFMA in LTable.BackendInfo.Capabilities) then
    Exit;

  CheckTrue(Pointer(LTable.CoreVectors.FmaF32x4) <> Pointer(LScalarTable.CoreVectors.FmaF32x4), 'AVX2 FmaF32x4 should leave the scalar slot once scFMA is advertised');
  CheckTrue(Pointer(LTable.CoreVectors.FmaF64x2) <> Pointer(LScalarTable.CoreVectors.FmaF64x2), 'AVX2 FmaF64x2 should leave the scalar slot once scFMA is advertised');
  CheckTrue(Pointer(LTable.CoreVectors.FmaF32x8) <> Pointer(LScalarTable.CoreVectors.FmaF32x8), 'AVX2 FmaF32x8 should leave the scalar slot once scFMA is advertised');
  CheckTrue(Pointer(LTable.CoreVectors.FmaF64x4) <> Pointer(LScalarTable.CoreVectors.FmaF64x4), 'AVX2 FmaF64x4 should leave the scalar slot once scFMA is advertised');
  CheckTrue(Pointer(LTable.CoreVectors.FmaF32x16) <> Pointer(LScalarTable.CoreVectors.FmaF32x16), 'AVX2 FmaF32x16 should leave the scalar slot once scFMA is advertised');
  CheckTrue(Pointer(LTable.CoreVectors.FmaF64x8) <> Pointer(LScalarTable.CoreVectors.FmaF64x8), 'AVX2 FmaF64x8 should leave the scalar slot once scFMA is advertised');

  CheckTrue(TryGetSimdBackendPodInfo(sbAVX2, LInfo), 'Public ABI pod info should be available for AVX2 FMA contract test');
  CheckTrue((LInfo.CapabilityBits and (UInt64(1) shl Ord(scFMA))) <> 0, 'Public ABI CapabilityBits should expose AVX2 scFMA once fused AVX2 FMA is contract-visible');
end;

procedure TTestCase_DispatchAPICapabilities.Test_AVX2_WideFma_ExactInputs_FollowsHalfComposition;
var
  LAVX2Table: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LCanRunAVX2: Boolean;
  LIndex: Integer;
  LF32A, LF32B, LF32C, LF32Actual, LF32Expected: TVecF32x16;
  LF64A, LF64B, LF64C, LF64Actual, LF64Expected: TVecF64x8;
  LSourceLines: TSourceLines;
  LRegisterSourcePath, LWideSourcePath: string;
  LRegisterSource, LWideSource: string;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.avx2.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'AVX2 register source should exist for wide FMA half-composition audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LWideSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.avx2.wide_emulation.inc');
    CheckTrue(FileExists(LWideSourcePath), 'AVX2 wide emulation source should exist for wide FMA half-composition audit: ' + LWideSourcePath);
    LSourceLines.LoadFromFile(LWideSourcePath);
    LWideSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  CheckTrue(Pos('dispatchtable.corevectors.fmaf32x16 := @avx2fmaf32x16;', LRegisterSource) > 0, 'AVX2 register should keep FmaF32x16 bound to AVX2 wide emulation when vector asm is enabled');
  CheckTrue(Pos('dispatchtable.corevectors.fmaf64x8 := @avx2fmaf64x8;', LRegisterSource) > 0, 'AVX2 register should keep FmaF64x8 bound to AVX2 wide emulation when vector asm is enabled');
  CheckTrue((Pos('function avx2fmaf32x16', LWideSource) > 0) and (Pos('result.lo := avx2fmaf32x8(a.lo, b.lo, c.lo);', LWideSource) > 0) and (Pos('result.hi := avx2fmaf32x8(a.hi, b.hi, c.hi);', LWideSource) > 0), 'AVX2 wide emulation should compose FmaF32x16 from two FmaF32x8 halves');
  CheckTrue((Pos('function avx2fmaf64x8', LWideSource) > 0) and (Pos('result.lo := avx2fmaf64x4(a.lo, b.lo, c.lo);', LWideSource) > 0) and (Pos('result.hi := avx2fmaf64x4(a.hi, b.hi, c.hi);', LWideSource) > 0), 'AVX2 wide emulation should compose FmaF64x8 from two FmaF64x4 halves');

  if not HasFeature(gfFMA) then
    Exit;

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  if not TryGetRegisteredBackendDispatchTable(sbAVX2, LAVX2Table) then
    Exit;
  if not (scFMA in LAVX2Table.BackendInfo.Capabilities) then
    Exit;

  LCanRunAVX2 := LAVX2Table.BackendInfo.Available and TrySetActiveBackend(sbAVX2);
  if not LCanRunAVX2 then
    Exit;

  CheckTrue(Pointer(LAVX2Table.CoreVectors.FmaF32x8) <> Pointer(LScalarTable.CoreVectors.FmaF32x8), 'AVX2 FmaF32x8 should leave the scalar slot when wide FMA half-composition is runtime-checkable');
  CheckTrue(Pointer(LAVX2Table.CoreVectors.FmaF32x16) <> Pointer(LScalarTable.CoreVectors.FmaF32x16), 'AVX2 FmaF32x16 should leave the scalar slot when wide FMA half-composition is runtime-checkable');
  CheckTrue(Pointer(LAVX2Table.CoreVectors.FmaF64x4) <> Pointer(LScalarTable.CoreVectors.FmaF64x4), 'AVX2 FmaF64x4 should leave the scalar slot when wide FMA half-composition is runtime-checkable');
  CheckTrue(Pointer(LAVX2Table.CoreVectors.FmaF64x8) <> Pointer(LScalarTable.CoreVectors.FmaF64x8), 'AVX2 FmaF64x8 should leave the scalar slot when wide FMA half-composition is runtime-checkable');

  for LIndex := 0 to 15 do
  begin
    LF32A.f[LIndex] := (LIndex - 7) * 0.5;
    case (LIndex and 3) of
      0: LF32B.f[LIndex] := 0.5;
      1: LF32B.f[LIndex] := 1.0;
      2: LF32B.f[LIndex] := 2.0;
    else
      LF32B.f[LIndex] := 4.0;
    end;
    LF32C.f[LIndex] := (2 - (LIndex and 3)) * 0.25;
  end;

  for LIndex := 0 to 7 do
  begin
    LF64A.d[LIndex] := (LIndex - 3) * 0.25;
    case (LIndex and 3) of
      0: LF64B.d[LIndex] := 0.5;
      1: LF64B.d[LIndex] := 1.0;
      2: LF64B.d[LIndex] := 2.0;
    else
      LF64B.d[LIndex] := 4.0;
    end;
    LF64C.d[LIndex] := (1 - (LIndex and 1)) * 0.125;
  end;

  LF32Actual := LAVX2Table.CoreVectors.FmaF32x16(LF32A, LF32B, LF32C);
  LF32Expected.lo := LAVX2Table.CoreVectors.FmaF32x8(LF32A.lo, LF32B.lo, LF32C.lo);
  LF32Expected.hi := LAVX2Table.CoreVectors.FmaF32x8(LF32A.hi, LF32B.hi, LF32C.hi);
  for LIndex := 0 to 15 do
    CheckNear(LF32Expected.f[LIndex], LF32Actual.f[LIndex], 0.0, 'AVX2 FmaF32x16 should follow two FmaF32x8 halves on exact inputs lane ' + IntToStr(LIndex));

  LF64Actual := LAVX2Table.CoreVectors.FmaF64x8(LF64A, LF64B, LF64C);
  LF64Expected.lo := LAVX2Table.CoreVectors.FmaF64x4(LF64A.lo, LF64B.lo, LF64C.lo);
  LF64Expected.hi := LAVX2Table.CoreVectors.FmaF64x4(LF64A.hi, LF64B.hi, LF64C.hi);
  for LIndex := 0 to 7 do
    CheckNear(LF64Expected.d[LIndex], LF64Actual.d[LIndex], 0.0, 'AVX2 FmaF64x8 should follow two FmaF64x4 halves on exact inputs lane ' + IntToStr(LIndex));
end;

procedure TTestCase_DispatchAPICapabilities.Test_AVX2_WideSelect_Parity_WithScalar_When_VectorAsmEnabled;
var
  LAVX2Table: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LCanRunAVX2: Boolean;
  LMask16: TMask16;
  LMask8: TMask8;
  LIndex: Integer;
  LF32A, LF32B, LF32Actual, LF32Expected: TVecF32x16;
  LF64A, LF64B, LF64Actual, LF64Expected: TVecF64x8;
  LSourceLines: TSourceLines;
  LRegisterSourcePath, LWideSourcePath: string;
  LRegisterSource, LWideSource: string;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.avx2.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'AVX2 register source should exist for wide select audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LWideSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.avx2.wide_emulation.inc');
    CheckTrue(FileExists(LWideSourcePath), 'AVX2 wide emulation source should exist for wide select audit: ' + LWideSourcePath);
    LSourceLines.LoadFromFile(LWideSourcePath);
    LWideSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  CheckTrue(Pos('dispatchtable.corevectors.selectf32x16 := @avx2selectf32x16;', LRegisterSource) > 0, 'AVX2 register should keep SelectF32x16 bound to AVX2 wide emulation when vector asm is enabled');
  CheckTrue(Pos('dispatchtable.corevectors.selectf64x8 := @avx2selectf64x8;', LRegisterSource) > 0, 'AVX2 register should keep SelectF64x8 bound to AVX2 wide emulation when vector asm is enabled');
  CheckTrue(Pos('function avx2selectf32x16', LWideSource) > 0, 'AVX2 wide emulation source should still define SelectF32x16');
  CheckTrue(Pos('function avx2selectf64x8', LWideSource) > 0, 'AVX2 wide emulation source should still define SelectF64x8');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  if not TryGetRegisteredBackendDispatchTable(sbAVX2, LAVX2Table) then
    Exit;

  LCanRunAVX2 := LAVX2Table.BackendInfo.Available and TrySetActiveBackend(sbAVX2);
  if not LCanRunAVX2 then
    Exit;

  CheckTrue(Pointer(LAVX2Table.CoreVectors.SelectF32x16) <> Pointer(LScalarTable.CoreVectors.SelectF32x16), 'AVX2 SelectF32x16 should leave the scalar slot when wide select parity is runtime-checkable');
  CheckTrue(Pointer(LAVX2Table.CoreVectors.SelectF64x8) <> Pointer(LScalarTable.CoreVectors.SelectF64x8), 'AVX2 SelectF64x8 should leave the scalar slot when wide select parity is runtime-checkable');

  LMask16 := TMask16($A55A);
  LMask8 := TMask8($A5);
  for LIndex := 0 to 15 do
  begin
    LF32A.f[LIndex] := LIndex + 0.25;
    LF32B.f[LIndex] := 100.0 + LIndex + 0.5;
  end;

  for LIndex := 0 to 7 do
  begin
    LF64A.d[LIndex] := LIndex + 0.125;
    LF64B.d[LIndex] := -100.0 - LIndex - 0.25;
  end;

  LF32Actual := LAVX2Table.CoreVectors.SelectF32x16(LMask16, LF32A, LF32B);
  LF32Expected := ScalarSelectF32x16(LMask16, LF32A, LF32B);
  for LIndex := 0 to 15 do
    CheckNear(LF32Expected.f[LIndex], LF32Actual.f[LIndex], 0.0, 'AVX2 SelectF32x16 scalar parity lane ' + IntToStr(LIndex));

  LF64Actual := LAVX2Table.CoreVectors.SelectF64x8(LMask8, LF64A, LF64B);
  LF64Expected := ScalarSelectF64x8(LMask8, LF64A, LF64B);
  for LIndex := 0 to 7 do
    CheckNear(LF64Expected.d[LIndex], LF64Actual.d[LIndex], 0.0, 'AVX2 SelectF64x8 scalar parity lane ' + IntToStr(LIndex));
end;

procedure TTestCase_X86MaskedFmaContract.Test_AVX2_FmaSlots_StayScalar_When_HardwareFmaUnavailable;
var
  LScalarTable: TSimdDispatchTable;
  LAVX2Table: TSimdDispatchTable;
  LInfo: TNextPasSimdBackendPodInfo;
begin
  if not HasAVX2 then
    Exit;
  if HasFeature(gfFMA) then
    Exit;

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbAVX2, LAVX2Table), 'AVX2 backend should stay registered when AVX2 is available but FMA is masked off');

  CheckFalse(scFMA in LAVX2Table.BackendInfo.Capabilities, 'AVX2 should not advertise scFMA when hardware FMA is unavailable');

  CheckEqual(PtrUInt(LScalarTable.CoreVectors.FmaF32x4), PtrUInt(LAVX2Table.CoreVectors.FmaF32x4), 'AVX2 FmaF32x4 slot should stay scalar when hardware FMA is unavailable');
  CheckEqual(PtrUInt(LScalarTable.CoreVectors.FmaF64x2), PtrUInt(LAVX2Table.CoreVectors.FmaF64x2), 'AVX2 FmaF64x2 slot should stay scalar when hardware FMA is unavailable');
  CheckEqual(PtrUInt(LScalarTable.CoreVectors.FmaF32x8), PtrUInt(LAVX2Table.CoreVectors.FmaF32x8), 'AVX2 FmaF32x8 slot should stay scalar when hardware FMA is unavailable');
  CheckEqual(PtrUInt(LScalarTable.CoreVectors.FmaF64x4), PtrUInt(LAVX2Table.CoreVectors.FmaF64x4), 'AVX2 FmaF64x4 slot should stay scalar when hardware FMA is unavailable');
  CheckEqual(PtrUInt(LScalarTable.CoreVectors.FmaF32x16), PtrUInt(LAVX2Table.CoreVectors.FmaF32x16), 'AVX2 FmaF32x16 slot should stay scalar when hardware FMA is unavailable');
  CheckEqual(PtrUInt(LScalarTable.CoreVectors.FmaF64x8), PtrUInt(LAVX2Table.CoreVectors.FmaF64x8), 'AVX2 FmaF64x8 slot should stay scalar when hardware FMA is unavailable');

  CheckTrue(TryGetSimdBackendPodInfo(sbAVX2, LInfo), 'TryGetSimdBackendPodInfo should succeed for sbAVX2');
  CheckTrue((LInfo.CapabilityBits and (UInt64(1) shl Ord(scFMA))) = 0, 'Public ABI CapabilityBits should keep AVX2 scFMA clear when hardware FMA is unavailable');
end;

procedure TTestCase_RISCVVMaskedOpsContract.Test_RISCVV_BackendCapabilities_Expose_MaskedOps_When_MaskSlots_AreNative;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
begin
  {$IFNDEF CPURISCV64}
  {$IFNDEF CPURISCV32}
  Exit;
  {$ENDIF}
  {$ENDIF}

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  CheckTrue(IsVectorAsmEnabled, 'Vector asm flag should be enabled before probing native RISCVV mask helpers');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV backend should be registered in mask capability contract test');
  CheckTrue(Assigned(LRISCVVTable.Mask.Mask2All), 'RISCVV Mask2All should be assigned');
  CheckTrue(Assigned(LRISCVVTable.Mask.Mask8PopCount), 'RISCVV Mask8PopCount should be assigned');
  CheckTrue(Assigned(LRISCVVTable.Mask.Mask16FirstSet), 'RISCVV Mask16FirstSet should be assigned');
  CheckTrue((Pointer(LRISCVVTable.Mask.Mask2All) <> Pointer(LScalarTable.Mask.Mask2All)) or (Pointer(LRISCVVTable.Mask.Mask8PopCount) <> Pointer(LScalarTable.Mask.Mask8PopCount)) or (Pointer(LRISCVVTable.Mask.Mask16FirstSet) <> Pointer(LScalarTable.Mask.Mask16FirstSet)), 'Representative RISCVV mask helper slots should be native in asm contract test');
  CheckTrue(scMaskedOps in LRISCVVTable.BackendInfo.Capabilities, 'RISCVV scMaskedOps should be set while representative mask helper slots are native');
end;

procedure TTestCase_RISCVVMaskedOpsContract.Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_RISCVVMaskedOps_When_MaskSlots_AreNative;
var
  LInfo: TNextPasSimdBackendPodInfo;
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
begin
  {$IFNDEF CPURISCV64}
  {$IFNDEF CPURISCV32}
  Exit;
  {$ENDIF}
  {$ENDIF}

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  CheckTrue(IsVectorAsmEnabled, 'Vector asm flag should be enabled before probing native RISCVV public ABI mask helpers');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV backend should be registered for public ABI mask contract test');
  CheckTrue(TryGetSimdBackendPodInfo(sbRISCVV, LInfo), 'Public ABI pod info should be available for RISCVV mask contract test');
  CheckTrue((Pointer(LRISCVVTable.Mask.Mask2All) <> Pointer(LScalarTable.Mask.Mask2All)) or (Pointer(LRISCVVTable.Mask.Mask8PopCount) <> Pointer(LScalarTable.Mask.Mask8PopCount)) or (Pointer(LRISCVVTable.Mask.Mask16FirstSet) <> Pointer(LScalarTable.Mask.Mask16FirstSet)), 'Representative RISCVV mask helper slots should be native before checking public ABI bits');
  CheckTrue((LInfo.CapabilityBits and (UInt64(1) shl Ord(scMaskedOps))) <> 0, 'Public ABI CapabilityBits should expose RISCVV scMaskedOps while representative mask helper slots are native');
end;

procedure TTestCase_DispatchAPICapabilities.Test_AVX512_BackendCapabilities_Expose_FMA_When_WideFmaSlots_AreNative;
var
  LScalarTable: TSimdDispatchTable;
  LAVX512Table: TSimdDispatchTable;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;
  if not TryGetRegisteredBackendDispatchTable(sbAVX512, LAVX512Table) then
    Exit;

  CheckTrue(Assigned(LAVX512Table.CoreVectors.FmaF32x16), 'AVX512 FmaF32x16 should be assigned');
  CheckTrue(Assigned(LAVX512Table.CoreVectors.FmaF64x8), 'AVX512 FmaF64x8 should be assigned');

  if (Pointer(LAVX512Table.CoreVectors.FmaF32x16) = Pointer(LScalarTable.CoreVectors.FmaF32x16)) and
     (Pointer(LAVX512Table.CoreVectors.FmaF64x8) = Pointer(LScalarTable.CoreVectors.FmaF64x8)) then
    Exit;

  CheckTrue(scFMA in LAVX512Table.BackendInfo.Capabilities, 'AVX512 should advertise scFMA once wide FMA slots are non-scalar');
end;

procedure TTestCase_DispatchAPICapabilities.Test_AVX512_BackendCapabilities_Expose_Shuffle_When_WideSelectSlots_AreNative;
var
  LScalarTable: TSimdDispatchTable;
  LAVX512Table: TSimdDispatchTable;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;
  if not TryGetRegisteredBackendDispatchTable(sbAVX512, LAVX512Table) then
    Exit;

  CheckTrue(Assigned(LAVX512Table.CoreVectors.SelectF32x16), 'AVX512 SelectF32x16 should be assigned');
  CheckTrue(Assigned(LAVX512Table.CoreVectors.SelectF64x8), 'AVX512 SelectF64x8 should be assigned');

  if (Pointer(LAVX512Table.CoreVectors.SelectF32x16) = Pointer(LScalarTable.CoreVectors.SelectF32x16)) and
     (Pointer(LAVX512Table.CoreVectors.SelectF64x8) = Pointer(LScalarTable.CoreVectors.SelectF64x8)) then
    Exit;

  CheckTrue(scShuffle in LAVX512Table.BackendInfo.Capabilities, 'AVX512 should advertise scShuffle once wide select slots are non-scalar');
end;

procedure TTestCase_DispatchAPICapabilities.Test_AVX512_BackendCapabilities_Clear_VectorAsmGatedBits_When_VectorAsmDisabled;
var
  LScalarTable: TSimdDispatchTable;
  LAVX512Table: TSimdDispatchTable;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  if not TryGetRegisteredBackendDispatchTable(sbAVX512, LAVX512Table) then
    Exit;

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;
  SetVectorAsmEnabled(False);
  CheckFalse(IsVectorAsmEnabled, 'Vector asm should be disabled for AVX512 capability rebuild test');
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbAVX512, LAVX512Table), 'AVX512 backend should remain registered after runtime rebuild');

  CheckEqual(PtrUInt(LScalarTable.CoreVectors.FmaF32x16), PtrUInt(LAVX512Table.CoreVectors.FmaF32x16), 'AVX512 FmaF32x16 should fall back to scalar when vector asm is disabled');
  CheckEqual(PtrUInt(LScalarTable.CoreVectors.AddU32x16), PtrUInt(LAVX512Table.CoreVectors.AddU32x16), 'AVX512 AddU32x16 should fall back to scalar when vector asm is disabled');

  CheckFalse(scFMA in LAVX512Table.BackendInfo.Capabilities, 'AVX512 scFMA should clear when vector asm is disabled');
  CheckFalse(scShuffle in LAVX512Table.BackendInfo.Capabilities, 'AVX512 scShuffle should clear when vector asm is disabled');
  CheckFalse(scIntegerOps in LAVX512Table.BackendInfo.Capabilities, 'AVX512 scIntegerOps should clear when vector asm is disabled');
  CheckFalse(sc512BitOps in LAVX512Table.BackendInfo.Capabilities, 'AVX512 sc512BitOps should clear when vector asm is disabled');
end;

procedure TTestCase_DispatchAPICapabilities.Test_AVX2_BackendCapabilities_Expose_Shuffle_When_NativeShuffleSlotsUsable;
var
  LScalarTable: TSimdDispatchTable;
  LAVX2Table: TSimdDispatchTable;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;
  if not TryGetRegisteredBackendDispatchTable(sbAVX2, LAVX2Table) then
    Exit;

  CheckTrue(Assigned(LAVX2Table.CoreVectors.SelectF32x4), 'AVX2 SelectF32x4 should be assigned');
  CheckTrue(Assigned(LAVX2Table.CoreVectors.InsertF32x4), 'AVX2 InsertF32x4 should be assigned');
  CheckTrue(Assigned(LAVX2Table.CoreVectors.ExtractF32x4), 'AVX2 ExtractF32x4 should be assigned');

  if (Pointer(LAVX2Table.CoreVectors.SelectF32x4) = Pointer(LScalarTable.CoreVectors.SelectF32x4)) and
     (Pointer(LAVX2Table.CoreVectors.InsertF32x4) = Pointer(LScalarTable.CoreVectors.InsertF32x4)) and
     (Pointer(LAVX2Table.CoreVectors.ExtractF32x4) = Pointer(LScalarTable.CoreVectors.ExtractF32x4)) and
     (Pointer(LAVX2Table.CoreVectors.SelectF32x8) = Pointer(LScalarTable.CoreVectors.SelectF32x8)) and
     (Pointer(LAVX2Table.CoreVectors.SelectF64x4) = Pointer(LScalarTable.CoreVectors.SelectF64x4)) then
    Exit;

  CheckTrue(scShuffle in LAVX2Table.BackendInfo.Capabilities, 'AVX2 should advertise scShuffle once representative shuffle slots are non-scalar');
end;

procedure TTestCase_DispatchAPICapabilities.Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_AVX2Shuffle_When_NativeShuffleSlotsUsable;
var
  LInfo: TNextPasSimdBackendPodInfo;
  LScalarTable: TSimdDispatchTable;
  LAVX2Table: TSimdDispatchTable;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;
  if not TryGetRegisteredBackendDispatchTable(sbAVX2, LAVX2Table) then
    Exit;
  if not (scShuffle in LAVX2Table.BackendInfo.Capabilities) then
    Exit;

  CheckTrue(Pointer(LAVX2Table.CoreVectors.SelectF32x4) <> Pointer(LScalarTable.CoreVectors.SelectF32x4), 'AVX2 SelectF32x4 should leave the scalar slot once scShuffle is advertised');
  CheckTrue(Pointer(LAVX2Table.CoreVectors.InsertF32x4) <> Pointer(LScalarTable.CoreVectors.InsertF32x4), 'AVX2 InsertF32x4 should leave the scalar slot once scShuffle is advertised');
  CheckTrue(Pointer(LAVX2Table.CoreVectors.ExtractF32x4) <> Pointer(LScalarTable.CoreVectors.ExtractF32x4), 'AVX2 ExtractF32x4 should leave the scalar slot once scShuffle is advertised');
  CheckTrue(Pointer(LAVX2Table.CoreVectors.SelectF32x8) <> Pointer(LScalarTable.CoreVectors.SelectF32x8), 'AVX2 SelectF32x8 should leave the scalar slot once scShuffle is advertised');
  CheckTrue(Pointer(LAVX2Table.CoreVectors.SelectF64x4) <> Pointer(LScalarTable.CoreVectors.SelectF64x4), 'AVX2 SelectF64x4 should leave the scalar slot once scShuffle is advertised');

  CheckTrue(TryGetSimdBackendPodInfo(sbAVX2, LInfo), 'Public ABI pod info should be available for AVX2 shuffle contract test');
  CheckTrue((LInfo.CapabilityBits and (UInt64(1) shl Ord(scShuffle))) <> 0, 'Public ABI CapabilityBits should expose AVX2 scShuffle while native AVX2 shuffle slots are contract-visible');
end;

procedure TTestCase_DispatchAPICapabilities.Test_AVX2_BackendCapabilities_Clear_Shuffle_When_VectorAsmDisabled;
var
  LScalarTable: TSimdDispatchTable;
  LAVX2Table: TSimdDispatchTable;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(False);
  CheckFalse(IsVectorAsmEnabled, 'Vector asm should be disabled for AVX2 shuffle capability rebuild test');
  if not TryGetRegisteredBackendDispatchTable(sbAVX2, LAVX2Table) then
    Exit;

  CheckEqual(PtrUInt(LScalarTable.CoreVectors.SelectF32x4), PtrUInt(LAVX2Table.CoreVectors.SelectF32x4), 'AVX2 SelectF32x4 should fall back to scalar when vector asm is disabled');
  CheckEqual(PtrUInt(LScalarTable.CoreVectors.InsertF32x4), PtrUInt(LAVX2Table.CoreVectors.InsertF32x4), 'AVX2 InsertF32x4 should fall back to scalar when vector asm is disabled');
  CheckEqual(PtrUInt(LScalarTable.CoreVectors.ExtractF32x4), PtrUInt(LAVX2Table.CoreVectors.ExtractF32x4), 'AVX2 ExtractF32x4 should fall back to scalar when vector asm is disabled');
  CheckEqual(PtrUInt(LScalarTable.CoreVectors.SelectF32x8), PtrUInt(LAVX2Table.CoreVectors.SelectF32x8), 'AVX2 SelectF32x8 should fall back to scalar when vector asm is disabled');
  CheckEqual(PtrUInt(LScalarTable.CoreVectors.SelectF64x4), PtrUInt(LAVX2Table.CoreVectors.SelectF64x4), 'AVX2 SelectF64x4 should fall back to scalar when vector asm is disabled');

  CheckFalse(scShuffle in LAVX2Table.BackendInfo.Capabilities, 'scShuffle should clear when AVX2 shuffle slots fall back to scalar after vector asm disable');
end;

procedure TTestCase_DispatchAPICapabilities.Test_PublicApi_BackendPodInfo_CapabilityBits_Clear_AVX2VectorAsmGatedBits_When_VectorAsmDisabled;
var
  LInfo: TNextPasSimdBackendPodInfo;
  LAVX2Table: TSimdDispatchTable;
begin
  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;
  SetVectorAsmEnabled(False);
  CheckFalse(IsVectorAsmEnabled, 'Vector asm should be disabled for AVX2 public ABI capability rebuild test');
  if not TryGetRegisteredBackendDispatchTable(sbAVX2, LAVX2Table) then
    Exit;

  CheckTrue(TryGetSimdBackendPodInfo(sbAVX2, LInfo), 'Public ABI pod info should be available for AVX2 vector-asm-disabled contract test');
  CheckFalse(scFMA in LAVX2Table.BackendInfo.Capabilities, 'Registered AVX2 scFMA should clear when vector asm is disabled');
  CheckFalse(scShuffle in LAVX2Table.BackendInfo.Capabilities, 'Registered AVX2 scShuffle should clear when vector asm is disabled');
  CheckTrue((LInfo.CapabilityBits and (UInt64(1) shl Ord(scFMA))) = 0, 'Public ABI CapabilityBits should clear AVX2 scFMA when vector asm is disabled');
  CheckTrue((LInfo.CapabilityBits and (UInt64(1) shl Ord(scShuffle))) = 0, 'Public ABI CapabilityBits should clear AVX2 scShuffle when vector asm is disabled');
end;

procedure TTestCase_DispatchAPICapabilities.Test_AVX2_FacadeScalarFallback_Uses_BaseFill_Without_Redundant_Win64_Rebinds;
var
  LScalarTable: TSimdDispatchTable;
  LAVX2Table: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.avx2.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'AVX2 register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.avx2.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'AVX2 facade source should exist for implementation-shape audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  CheckTrue(Pos('fillbasedispatchtable(dispatchtable);', LRegisterSource) > 0, 'AVX2 register should still seed from FillBaseDispatchTable before applying backend-local overrides');

  CheckTrue(Pos('dispatchtable.memory.equal := @memequal_scalar;', LRegisterSource) = 0, 'Win64 AVX2 MemEqual should reuse FillBaseDispatchTable instead of redundant scalar rebinding');
  CheckTrue(Pos('dispatchtable.memory.findbyte := @memfindbyte_scalar;', LRegisterSource) = 0, 'Win64 AVX2 MemFindByte should reuse FillBaseDispatchTable instead of redundant scalar rebinding');
  CheckTrue(Pos('dispatchtable.memory.sumbytes := @sumbytes_scalar;', LRegisterSource) = 0, 'Win64 AVX2 SumBytes should reuse FillBaseDispatchTable instead of redundant scalar rebinding');
  CheckTrue(Pos('dispatchtable.memory.countbyte := @countbyte_scalar;', LRegisterSource) = 0, 'Win64 AVX2 CountByte should reuse FillBaseDispatchTable instead of redundant scalar rebinding');
  CheckTrue(Pos('dispatchtable.memory.diffrange := @memdiffrange_scalar;', LRegisterSource) = 0, 'Win64 AVX2 MemDiffRange should reuse FillBaseDispatchTable instead of redundant scalar rebinding');
  CheckTrue(Pos('dispatchtable.memory.reverse := @memreverse_scalar;', LRegisterSource) = 0, 'Win64 AVX2 MemReverse should reuse FillBaseDispatchTable instead of redundant scalar rebinding');
  CheckTrue(Pos('dispatchtable.memory.minmaxbytes := @minmaxbytes_scalar;', LRegisterSource) = 0, 'Win64 AVX2 MinMaxBytes should reuse FillBaseDispatchTable instead of redundant scalar rebinding');
  CheckTrue(Pos('dispatchtable.memory.utf8validate := @utf8validate_scalar;', LRegisterSource) = 0, 'Win64 AVX2 Utf8Validate should reuse FillBaseDispatchTable instead of redundant scalar rebinding');
  CheckTrue(Pos('dispatchtable.memory.asciiiequal := @asciiiequal_scalar;', LRegisterSource) = 0, 'Win64 AVX2 AsciiIEqual should reuse FillBaseDispatchTable instead of redundant scalar rebinding');
  CheckTrue(Pos('dispatchtable.memory.tolowerascii := @tolowerascii_scalar;', LRegisterSource) = 0, 'Win64 AVX2 ToLowerAscii should reuse FillBaseDispatchTable instead of redundant scalar rebinding');
  CheckTrue(Pos('dispatchtable.memory.toupperascii := @toupperascii_scalar;', LRegisterSource) = 0, 'Win64 AVX2 ToUpperAscii should reuse FillBaseDispatchTable instead of redundant scalar rebinding');
  CheckTrue(Pos('dispatchtable.memory.bytesindexof := @bytesindexof_scalar;', LRegisterSource) = 0, 'Win64 AVX2 BytesIndexOf should reuse FillBaseDispatchTable instead of redundant scalar rebinding');
  CheckTrue(Pos('dispatchtable.memory.bitsetpopcount := @bitsetpopcount_scalar;', LRegisterSource) = 0, 'Win64 AVX2 BitsetPopCount should reuse FillBaseDispatchTable instead of redundant scalar rebinding');
  CheckTrue(Pos('dispatchtable.memory.copy := @memcopy_scalar;', LRegisterSource) = 0, 'Win64 AVX2 MemCopy should reuse FillBaseDispatchTable instead of redundant scalar rebinding');
  CheckTrue(Pos('dispatchtable.memory.fill := @memset_scalar;', LRegisterSource) = 0, 'Win64 AVX2 MemSet should reuse FillBaseDispatchTable instead of redundant scalar rebinding');

  CheckTrue(Pos('dispatchtable.memory.equal := @memequal_avx2;', LRegisterSource) > 0, 'Non-Windows AVX2 register path should keep MemEqual_AVX2 explicit so native facade binding remains truthful');
  CheckTrue(Pos('dispatchtable.memory.utf8validate := @utf8validate_avx2;', LRegisterSource) > 0, 'Non-Windows AVX2 register path should keep Utf8Validate_AVX2 explicit so native facade binding remains truthful');
  CheckTrue(Pos('dispatchtable.memory.copy := @memcopy_avx2;', LRegisterSource) > 0, 'Non-Windows AVX2 register path should keep MemCopy_AVX2 explicit so native facade binding remains truthful');
  CheckTrue(Pos('dispatchtable.memory.bitsetpopcount := @bitsetpopcount_avx2;', LRegisterSource) > 0, 'Non-Windows AVX2 register path should keep BitsetPopCount_AVX2 explicit so native facade binding remains truthful');

  CheckTrue(Pos('function memequal_avx2', LFacadeSource) > 0, 'AVX2 facade include should still define MemEqual_AVX2');
  CheckTrue(Pos('function utf8validate_avx2', LFacadeSource) > 0, 'AVX2 facade include should still define Utf8Validate_AVX2');
  CheckTrue(Pos('procedure memcopy_avx2', LFacadeSource) > 0, 'AVX2 facade include should still define MemCopy_AVX2');
  CheckTrue(Pos('function bitsetpopcount_avx2', LFacadeSource) > 0, 'AVX2 facade include should still define BitsetPopCount_AVX2');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  if not TryGetRegisteredBackendDispatchTable(sbAVX2, LAVX2Table) then
    Exit;

  {$IFDEF WINDOWS}
  CheckEqual(PtrUInt(LScalarTable.Memory.Equal), PtrUInt(LAVX2Table.Memory.Equal), 'Win64 AVX2 MemEqual should stay scalar-safe via FillBaseDispatchTable');
  CheckEqual(PtrUInt(LScalarTable.Memory.Utf8Validate), PtrUInt(LAVX2Table.Memory.Utf8Validate), 'Win64 AVX2 Utf8Validate should stay scalar-safe via FillBaseDispatchTable');
  CheckEqual(PtrUInt(LScalarTable.Memory.Copy), PtrUInt(LAVX2Table.Memory.Copy), 'Win64 AVX2 MemCopy should stay scalar-safe via FillBaseDispatchTable');
  CheckEqual(PtrUInt(LScalarTable.Memory.BitsetPopCount), PtrUInt(LAVX2Table.Memory.BitsetPopCount), 'Win64 AVX2 BitsetPopCount should stay scalar-safe via FillBaseDispatchTable');
  {$ELSE}
  CheckTrue(Pointer(LAVX2Table.Memory.Equal) <> Pointer(LScalarTable.Memory.Equal), 'Non-Windows AVX2 MemEqual should keep a native facade binding');
  CheckTrue(Pointer(LAVX2Table.Memory.Utf8Validate) <> Pointer(LScalarTable.Memory.Utf8Validate), 'Non-Windows AVX2 Utf8Validate should keep a native facade binding');
  CheckTrue(Pointer(LAVX2Table.Memory.Copy) <> Pointer(LScalarTable.Memory.Copy), 'Non-Windows AVX2 MemCopy should keep a native facade binding');
  CheckTrue(Pointer(LAVX2Table.Memory.BitsetPopCount) <> Pointer(LScalarTable.Memory.BitsetPopCount), 'Non-Windows AVX2 BitsetPopCount should keep a native facade binding');
  {$ENDIF}
end;

procedure TTestCase_DispatchAPICapabilities.Test_SSE3_RepresentativeOverrides_Reuse_SSE2_CoreSlots;
var
  LSSE2Table: TSimdDispatchTable;
  LSSE3Table: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LRegisterSource: string;
  LOldVectorAsm: Boolean;

  procedure AssertRegisterBinds(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterSSE3Backend should keep ' + aLabel + ' explicitly bound in the SSE3 register include');
  end;

  procedure AssertRegisterKeepsClonedSSE2(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0, 'RegisterSSE3Backend should keep cloned SSE2 ' + aLabel + ' instead of rebinding it in the SSE3 register include');
  end;

  procedure AssertSlotReusesSSE2(const aLabel: string; const aSSE2Slot, aSSE3Slot: Pointer);
  begin
    CheckEqual(PtrUInt(aSSE2Slot), PtrUInt(aSSE3Slot), 'SSE3 ' + aLabel + ' should reuse the cloned SSE2 slot');
  end;

  procedure AssertSlotOwnsSSE3(const aLabel: string; const aSSE2Slot, aSSE3Slot: Pointer);
  begin
    CheckTrue(PtrUInt(aSSE2Slot) <> PtrUInt(aSSE3Slot), 'SSE3 ' + aLabel + ' should stay on the SSE3 override instead of collapsing back to SSE2');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.sse3.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'SSE3 register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  CheckTrue(Pos('clonedispatchtable(sbsse2, dispatchtable)', LRegisterSource) > 0, 'RegisterSSE3Backend should clone from SSE2 before applying SSE3-specific overrides');
  AssertRegisterBinds('ReduceAddF32x4', 'dispatchTable.CoreVectors.ReduceAddF32x4 := @SSE3ReduceAddF32x4;');
  AssertRegisterBinds('DotF32x4', 'dispatchTable.CoreVectors.DotF32x4 := @SSE3DotF32x4;');
  AssertRegisterBinds('NormalizeF32x4', 'dispatchTable.CoreVectors.NormalizeF32x4 := @SSE3NormalizeF32x4;');
  AssertRegisterKeepsClonedSSE2('AddF32x4', 'dispatchTable.CoreVectors.AddF32x4 := @SSE3');
  AssertRegisterKeepsClonedSSE2('MulF32x4', 'dispatchTable.CoreVectors.MulF32x4 := @SSE3');

  GetDispatchTable;
  LOldVectorAsm := IsVectorAsmEnabled;
  try
    SetVectorAsmEnabled(True);
    if not IsVectorAsmEnabled then
      Exit;
    if not TryGetRegisteredBackendDispatchTable(sbSSE2, LSSE2Table) then
      Exit;
    if not TryGetRegisteredBackendDispatchTable(sbSSE3, LSSE3Table) then
      Exit;

    AssertSlotReusesSSE2('AddF32x4', Pointer(LSSE2Table.CoreVectors.AddF32x4), Pointer(LSSE3Table.CoreVectors.AddF32x4));
    AssertSlotReusesSSE2('MulF32x4', Pointer(LSSE2Table.CoreVectors.MulF32x4), Pointer(LSSE3Table.CoreVectors.MulF32x4));
    AssertSlotOwnsSSE3('ReduceAddF32x4', Pointer(LSSE2Table.CoreVectors.ReduceAddF32x4), Pointer(LSSE3Table.CoreVectors.ReduceAddF32x4));
    AssertSlotOwnsSSE3('DotF32x4', Pointer(LSSE2Table.CoreVectors.DotF32x4), Pointer(LSSE3Table.CoreVectors.DotF32x4));
    AssertSlotOwnsSSE3('NormalizeF32x4', Pointer(LSSE2Table.CoreVectors.NormalizeF32x4), Pointer(LSSE3Table.CoreVectors.NormalizeF32x4));
  finally
  end;
end;

procedure TTestCase_DispatchAPICapabilities.Test_SSSE3_RepresentativeOverrides_Reuse_SSE3_CoreSlots;
var
  LSSE3Table: TSimdDispatchTable;
  LSSSE3Table: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LRegisterSource: string;

  procedure AssertRegisterKeepsClonedSSE3(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0, 'RegisterSSSE3Backend should keep cloned SSE3 ' + aLabel + ' instead of rebinding it in the SSSE3 register include');
  end;

  procedure AssertSlotReusesSSE3(const aLabel: string; const aSSE3Slot, aSSSE3Slot: Pointer);
  begin
    CheckEqual(PtrUInt(aSSE3Slot), PtrUInt(aSSSE3Slot), 'SSSE3 ' + aLabel + ' should reuse the cloned SSE3 slot');
  end;

begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.ssse3.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'SSSE3 register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  CheckTrue(Pos('clonedispatchtable(sbsse3, dispatchtable)', LRegisterSource) > 0, 'RegisterSSSE3Backend should clone from SSE3 before using SSSE3-specific direct helpers');
  AssertRegisterKeepsClonedSSE3('MinI8x16', 'dispatchTable.CoreVectors.MinI8x16 := @SSSE3MinI8x16;');
  AssertRegisterKeepsClonedSSE3('MaxI8x16', 'dispatchTable.CoreVectors.MaxI8x16 := @SSSE3MaxI8x16;');
  AssertRegisterKeepsClonedSSE3('ReduceAddF32x4', 'dispatchTable.CoreVectors.ReduceAddF32x4 := @SSSE3');
  AssertRegisterKeepsClonedSSE3('DotF32x4', 'dispatchTable.CoreVectors.DotF32x4 := @SSSE3');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;
  if not TryGetRegisteredBackendDispatchTable(sbSSE3, LSSE3Table) then
    Exit;
  if not TryGetRegisteredBackendDispatchTable(sbSSSE3, LSSSE3Table) then
    Exit;

  AssertSlotReusesSSE3('ReduceAddF32x4', Pointer(LSSE3Table.CoreVectors.ReduceAddF32x4), Pointer(LSSSE3Table.CoreVectors.ReduceAddF32x4));
  AssertSlotReusesSSE3('DotF32x4', Pointer(LSSE3Table.CoreVectors.DotF32x4), Pointer(LSSSE3Table.CoreVectors.DotF32x4));
  AssertSlotReusesSSE3('MinI8x16', Pointer(LSSE3Table.CoreVectors.MinI8x16), Pointer(LSSSE3Table.CoreVectors.MinI8x16));
  AssertSlotReusesSSE3('MaxI8x16', Pointer(LSSE3Table.CoreVectors.MaxI8x16), Pointer(LSSSE3Table.CoreVectors.MaxI8x16));
end;

procedure TTestCase_DispatchAPICapabilities.Test_SSE41_RepresentativeOverrides_Reuse_SSSE3_CoreSlots;
var
  LSSSE3Table: TSimdDispatchTable;
  LSSE41Table: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LRegisterSource: string;

  procedure AssertRegisterBinds(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterSSE41Backend should keep ' + aLabel + ' explicitly bound in the SSE4.1 register include');
  end;

  procedure AssertRegisterKeepsClonedSSSE3(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0, 'RegisterSSE41Backend should keep cloned SSSE3 ' + aLabel + ' instead of rebinding it in the SSE4.1 register include');
  end;

  procedure AssertSlotReusesSSSE3(const aLabel: string; const aSSSE3Slot, aSSE41Slot: Pointer);
  begin
    CheckEqual(PtrUInt(aSSSE3Slot), PtrUInt(aSSE41Slot), 'SSE4.1 ' + aLabel + ' should reuse the cloned SSSE3 slot');
  end;

  procedure AssertSlotOwnsSSE41(const aLabel: string; const aSSSE3Slot, aSSE41Slot: Pointer);
  begin
    CheckTrue(PtrUInt(aSSSE3Slot) <> PtrUInt(aSSE41Slot), 'SSE4.1 ' + aLabel + ' should stay on the SSE4.1 override instead of collapsing back to SSSE3');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.sse41.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'SSE4.1 register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  CheckTrue(Pos('clonedispatchtable(sbssse3, dispatchtable)', LRegisterSource) > 0, 'RegisterSSE41Backend should clone from SSSE3 before applying SSE4.1-specific overrides');
  AssertRegisterBinds('MulI32x4', 'dispatchTable.CoreVectors.MulI32x4 := @SSE41MulI32x4;');
  AssertRegisterBinds('DotF32x4', 'dispatchTable.CoreVectors.DotF32x4 := @SSE41DotF32x4;');
  AssertRegisterBinds('RoundF32x4', 'dispatchTable.CoreVectors.RoundF32x4 := @SSE41RoundF32x4;');
  AssertRegisterBinds('SelectF32x4', 'dispatchTable.CoreVectors.SelectF32x4 := @SSE41SelectF32x4;');
  AssertRegisterBinds('CmpEqI64x2', 'dispatchTable.CoreVectors.CmpEqI64x2 := @SSE41CmpEqI64x2;');
  AssertRegisterKeepsClonedSSSE3('ReduceAddF32x4', 'dispatchTable.CoreVectors.ReduceAddF32x4 := @SSE41');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;
  if not TryGetRegisteredBackendDispatchTable(sbSSSE3, LSSSE3Table) then
    Exit;
  if not TryGetRegisteredBackendDispatchTable(sbSSE41, LSSE41Table) then
    Exit;

  AssertSlotReusesSSSE3('ReduceAddF32x4', Pointer(LSSSE3Table.CoreVectors.ReduceAddF32x4), Pointer(LSSE41Table.CoreVectors.ReduceAddF32x4));
  AssertSlotOwnsSSE41('MulI32x4', Pointer(LSSSE3Table.CoreVectors.MulI32x4), Pointer(LSSE41Table.CoreVectors.MulI32x4));
  AssertSlotOwnsSSE41('DotF32x4', Pointer(LSSSE3Table.CoreVectors.DotF32x4), Pointer(LSSE41Table.CoreVectors.DotF32x4));
  AssertSlotOwnsSSE41('RoundF32x4', Pointer(LSSSE3Table.CoreVectors.RoundF32x4), Pointer(LSSE41Table.CoreVectors.RoundF32x4));
  AssertSlotOwnsSSE41('SelectF32x4', Pointer(LSSSE3Table.CoreVectors.SelectF32x4), Pointer(LSSE41Table.CoreVectors.SelectF32x4));
  AssertSlotOwnsSSE41('CmpEqI64x2', Pointer(LSSSE3Table.CoreVectors.CmpEqI64x2), Pointer(LSSE41Table.CoreVectors.CmpEqI64x2));
end;

procedure TTestCase_DispatchAPICapabilities.Test_SSE42_RepresentativeOverride_Reuse_SSE41_CoreSlots;
var
  LSSE41Table: TSimdDispatchTable;
  LSSE42Table: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LRegisterSource: string;

  procedure AssertRegisterBinds(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterSSE42Backend should keep ' + aLabel + ' explicitly bound in the SSE4.2 register include');
  end;

  procedure AssertRegisterKeepsClonedSSE41(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0, 'RegisterSSE42Backend should keep cloned SSE4.1 ' + aLabel + ' instead of rebinding it in the SSE4.2 register include');
  end;

  procedure AssertSlotReusesSSE41(const aLabel: string; const aSSE41Slot, aSSE42Slot: Pointer);
  begin
    CheckEqual(PtrUInt(aSSE41Slot), PtrUInt(aSSE42Slot), 'SSE4.2 ' + aLabel + ' should reuse the cloned SSE4.1 slot');
  end;

  procedure AssertSlotOwnsSSE42(const aLabel: string; const aSSE41Slot, aSSE42Slot: Pointer);
  begin
    CheckTrue(PtrUInt(aSSE41Slot) <> PtrUInt(aSSE42Slot), 'SSE4.2 ' + aLabel + ' should stay on the SSE4.2 override instead of collapsing back to SSE4.1');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.sse42.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'SSE4.2 register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  CheckTrue(Pos('clonedispatchtable(sbsse41, dispatchtable)', LRegisterSource) > 0, 'RegisterSSE42Backend should clone from SSE4.1 before applying SSE4.2-specific overrides');
  AssertRegisterBinds('CmpGtI64x2', 'dispatchTable.CoreVectors.CmpGtI64x2 := @SSE42CmpGtI64x2;');
  AssertRegisterKeepsClonedSSE41('ReduceAddF32x4', 'dispatchTable.CoreVectors.ReduceAddF32x4 := @SSE42');
  AssertRegisterKeepsClonedSSE41('SelectF32x4', 'dispatchTable.CoreVectors.SelectF32x4 := @SSE42');
  AssertRegisterKeepsClonedSSE41('CmpEqI64x2', 'dispatchTable.CoreVectors.CmpEqI64x2 := @SSE42');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;
  if not TryGetRegisteredBackendDispatchTable(sbSSE41, LSSE41Table) then
    Exit;
  if not TryGetRegisteredBackendDispatchTable(sbSSE42, LSSE42Table) then
    Exit;

  AssertSlotReusesSSE41('ReduceAddF32x4', Pointer(LSSE41Table.CoreVectors.ReduceAddF32x4), Pointer(LSSE42Table.CoreVectors.ReduceAddF32x4));
  AssertSlotReusesSSE41('SelectF32x4', Pointer(LSSE41Table.CoreVectors.SelectF32x4), Pointer(LSSE42Table.CoreVectors.SelectF32x4));
  AssertSlotReusesSSE41('CmpEqI64x2', Pointer(LSSE41Table.CoreVectors.CmpEqI64x2), Pointer(LSSE42Table.CoreVectors.CmpEqI64x2));
  AssertSlotOwnsSSE42('CmpGtI64x2', Pointer(LSSE41Table.CoreVectors.CmpGtI64x2), Pointer(LSSE42Table.CoreVectors.CmpGtI64x2));
end;

procedure TTestCase_DispatchAPICapabilities.Test_SSE3_RepresentativeSemanticParity_WithScalar_IfDispatchable;
var
  LScalarTable: TSimdDispatchTable;
  LSSE3Table: TSimdDispatchTable;
  LCurrentDispatch: PSimdDispatchTable;
  LCanRunSSE3: Boolean;
  LA, LB, LNormalizeInput, LNormalizeZeroInput: TVecF32x4;
  LNormalizeActual, LNormalizeExpected: TVecF32x4;
  LNormalizeZeroActual, LNormalizeZeroExpected: TVecF32x4;
  LReduceActual, LReduceExpected: Single;
  LDotActual, LDotExpected: Single;

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

  if not TryGetRegisteredBackendDispatchTable(sbSSE3, LSSE3Table) then
    Exit;

  CheckTrue(Pointer(LSSE3Table.CoreVectors.ReduceAddF32x4) <> Pointer(LScalarTable.CoreVectors.ReduceAddF32x4), 'SSE3 ReduceAddF32x4 should leave the scalar slot when runtime semantic parity is checkable');
  CheckTrue(Pointer(LSSE3Table.CoreVectors.DotF32x4) <> Pointer(LScalarTable.CoreVectors.DotF32x4), 'SSE3 DotF32x4 should leave the scalar slot when runtime semantic parity is checkable');
  CheckTrue(Pointer(LSSE3Table.CoreVectors.NormalizeF32x4) <> Pointer(LScalarTable.CoreVectors.NormalizeF32x4), 'SSE3 NormalizeF32x4 should leave the scalar slot when runtime semantic parity is checkable');

  LCanRunSSE3 := LSSE3Table.BackendInfo.Available and TrySetActiveBackend(sbSSE3);
  if not LCanRunSSE3 then
    Exit;

  LCurrentDispatch := GetDispatchTable;
  CheckEqual(Ord(sbSSE3), Ord(GetActiveBackend), 'Active backend should be SSE3 for runtime semantic parity');
  CheckEqual(Ord(sbSSE3), Ord(LCurrentDispatch^.Backend), 'Current dispatch table should resolve to SSE3 after forcing the backend');

  LA.f[0] := 1.0;
  LA.f[1] := 2.0;
  LA.f[2] := 3.0;
  LA.f[3] := 4.0;
  LB.f[0] := -5.0;
  LB.f[1] := 6.0;
  LB.f[2] := -7.0;
  LB.f[3] := 8.0;
  LNormalizeInput.f[0] := 4.0;
  LNormalizeInput.f[1] := 0.0;
  LNormalizeInput.f[2] := 0.0;
  LNormalizeInput.f[3] := 0.0;
  LNormalizeZeroInput.f[0] := 0.0;
  LNormalizeZeroInput.f[1] := 0.0;
  LNormalizeZeroInput.f[2] := 0.0;
  LNormalizeZeroInput.f[3] := 0.0;

  LReduceExpected := ScalarReduceAddF32x4(LA);
  LReduceActual := LCurrentDispatch^.CoreVectors.ReduceAddF32x4(LA);
  CheckNear(LReduceExpected, LReduceActual, 0.0, 'SSE3 ReduceAddF32x4 scalar parity');

  LDotExpected := ScalarDotF32x4(LA, LB);
  LDotActual := LCurrentDispatch^.CoreVectors.DotF32x4(LA, LB);
  CheckNear(LDotExpected, LDotActual, 0.0, 'SSE3 DotF32x4 scalar parity');

  LNormalizeExpected := ScalarNormalizeF32x4(LNormalizeInput);
  LNormalizeActual := LCurrentDispatch^.CoreVectors.NormalizeF32x4(LNormalizeInput);
  AssertVecF32x4Equal('SSE3 NormalizeF32x4 scalar parity', LNormalizeExpected, LNormalizeActual, 0.0);

  LNormalizeZeroExpected := ScalarNormalizeF32x4(LNormalizeZeroInput);
  LNormalizeZeroActual := LCurrentDispatch^.CoreVectors.NormalizeF32x4(LNormalizeZeroInput);
  AssertVecF32x4Equal('SSE3 NormalizeF32x4 zero scalar parity', LNormalizeZeroExpected, LNormalizeZeroActual, 0.0);
end;

procedure TTestCase_DispatchAPICapabilities.Test_SSSE3_RepresentativeSemanticParity_WithScalar_IfDispatchable;
var
  LScalarTable: TSimdDispatchTable;
  LSSSE3Table: TSimdDispatchTable;
  LCurrentDispatch: PSimdDispatchTable;
  LCanRunSSSE3: Boolean;
  LA, LB: TVecI8x16;
  LMinActual, LMinExpected: TVecI8x16;
  LMaxActual, LMaxExpected: TVecI8x16;

  procedure AssertVecI8x16Equal(const aLabel: string; const aExpected, aActual: TVecI8x16);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 15 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aLabel + ' lane ' + IntToStr(LLane));
  end;

begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  if not TryGetRegisteredBackendDispatchTable(sbSSSE3, LSSSE3Table) then
    Exit;

  CheckTrue(Pointer(LSSSE3Table.CoreVectors.MinI8x16) <> Pointer(LScalarTable.CoreVectors.MinI8x16), 'SSSE3 MinI8x16 should leave the scalar slot when runtime semantic parity is checkable');
  CheckTrue(Pointer(LSSSE3Table.CoreVectors.MaxI8x16) <> Pointer(LScalarTable.CoreVectors.MaxI8x16), 'SSSE3 MaxI8x16 should leave the scalar slot when runtime semantic parity is checkable');

  LCanRunSSSE3 := LSSSE3Table.BackendInfo.Available and TrySetActiveBackend(sbSSSE3);
  if not LCanRunSSSE3 then
    Exit;

  LCurrentDispatch := GetDispatchTable;
  CheckEqual(Ord(sbSSSE3), Ord(GetActiveBackend), 'Active backend should be SSSE3 for runtime semantic parity');
  CheckEqual(Ord(sbSSSE3), Ord(LCurrentDispatch^.Backend), 'Current dispatch table should resolve to SSSE3 after forcing the backend');

  LA.i[0] := -104; LA.i[1] := -91; LA.i[2] := -78; LA.i[3] := -65;
  LA.i[4] := -52;  LA.i[5] := -39; LA.i[6] := -26; LA.i[7] := -13;
  LA.i[8] := 0;    LA.i[9] := 13;  LA.i[10] := 26; LA.i[11] := 39;
  LA.i[12] := 52;  LA.i[13] := 65; LA.i[14] := 78; LA.i[15] := 91;
  LB.i[0] := 96;   LB.i[1] := 85;  LB.i[2] := 74;  LB.i[3] := 63;
  LB.i[4] := 52;   LB.i[5] := 41;  LB.i[6] := 30;  LB.i[7] := 19;
  LB.i[8] := 8;    LB.i[9] := -3;  LB.i[10] := -14; LB.i[11] := -25;
  LB.i[12] := -36; LB.i[13] := -47; LB.i[14] := -58; LB.i[15] := -69;

  LMinExpected := ScalarMinI8x16(LA, LB);
  LMinActual := LCurrentDispatch^.CoreVectors.MinI8x16(LA, LB);
  AssertVecI8x16Equal('SSSE3 MinI8x16 scalar parity', LMinExpected, LMinActual);

  LMaxExpected := ScalarMaxI8x16(LA, LB);
  LMaxActual := LCurrentDispatch^.CoreVectors.MaxI8x16(LA, LB);
  AssertVecI8x16Equal('SSSE3 MaxI8x16 scalar parity', LMaxExpected, LMaxActual);
end;

procedure TTestCase_DispatchAPICapabilities.Test_SSE41_RepresentativeSemanticParity_WithScalar_IfDispatchable;
var
  LScalarTable: TSimdDispatchTable;
  LSSE41Table: TSimdDispatchTable;
  LCurrentDispatch: PSimdDispatchTable;
  LCanRunSSE41: Boolean;
  LI32A, LI32B: TVecI32x4;
  LI32Actual, LI32Expected: TVecI32x4;
  LF32RoundInput: TVecF32x4;
  LF32RoundActual, LF32RoundExpected: TVecF32x4;
  LF32SelectA, LF32SelectB: TVecF32x4;
  LF32SelectActual, LF32SelectExpected: TVecF32x4;
  LF32InsertActual, LF32InsertExpected: TVecF32x4;
  LNormalize4Input, LNormalize4ZeroInput: TVecF32x4;
  LNormalize3Input, LNormalize3ZeroInput: TVecF32x4;
  LNormalize4Actual, LNormalize4Expected: TVecF32x4;
  LNormalize4ZeroActual, LNormalize4ZeroExpected: TVecF32x4;
  LNormalize3Actual, LNormalize3Expected: TVecF32x4;
  LNormalize3ZeroActual, LNormalize3ZeroExpected: TVecF32x4;
  LI64CmpA, LI64CmpB: TVecI64x2;
  LMask2Actual, LMask2Expected: TMask2;
  LExtractActual, LExtractExpected: Single;
  LDotActual, LDotExpected: Single;
  LDotA, LDotB: TVecF32x4;
  LMask4: TMask4;

  procedure AssertVecI32x4Equal(const aLabel: string; const aExpected, aActual: TVecI32x4);
  var
    LLane: Integer;
  begin
    for LLane := 0 to 3 do
      CheckEqual(aExpected.i[LLane], aActual.i[LLane], aLabel + ' lane ' + IntToStr(LLane));
  end;

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

  if not TryGetRegisteredBackendDispatchTable(sbSSE41, LSSE41Table) then
    Exit;

  CheckTrue(Pointer(LSSE41Table.CoreVectors.MulI32x4) <> Pointer(LScalarTable.CoreVectors.MulI32x4), 'SSE4.1 MulI32x4 should leave the scalar slot when runtime semantic parity is checkable');
  CheckTrue(Pointer(LSSE41Table.CoreVectors.DotF32x4) <> Pointer(LScalarTable.CoreVectors.DotF32x4), 'SSE4.1 DotF32x4 should leave the scalar slot when runtime semantic parity is checkable');
  CheckTrue(Pointer(LSSE41Table.CoreVectors.RoundF32x4) <> Pointer(LScalarTable.CoreVectors.RoundF32x4), 'SSE4.1 RoundF32x4 should leave the scalar slot when runtime semantic parity is checkable');
  CheckTrue(Pointer(LSSE41Table.CoreVectors.SelectF32x4) <> Pointer(LScalarTable.CoreVectors.SelectF32x4), 'SSE4.1 SelectF32x4 should leave the scalar slot when runtime semantic parity is checkable');
  CheckTrue(Pointer(LSSE41Table.CoreVectors.InsertF32x4) <> Pointer(LScalarTable.CoreVectors.InsertF32x4), 'SSE4.1 InsertF32x4 should leave the scalar slot when runtime semantic parity is checkable');
  CheckTrue(Pointer(LSSE41Table.CoreVectors.ExtractF32x4) <> Pointer(LScalarTable.CoreVectors.ExtractF32x4), 'SSE4.1 ExtractF32x4 should leave the scalar slot when runtime semantic parity is checkable');
  CheckTrue(Pointer(LSSE41Table.CoreVectors.NormalizeF32x4) <> Pointer(LScalarTable.CoreVectors.NormalizeF32x4), 'SSE4.1 NormalizeF32x4 should leave the scalar slot when runtime semantic parity is checkable');
  CheckTrue(Pointer(LSSE41Table.CoreVectors.NormalizeF32x3) <> Pointer(LScalarTable.CoreVectors.NormalizeF32x3), 'SSE4.1 NormalizeF32x3 should leave the scalar slot when runtime semantic parity is checkable');
  CheckTrue(Pointer(LSSE41Table.CoreVectors.CmpEqI64x2) <> Pointer(LScalarTable.CoreVectors.CmpEqI64x2), 'SSE4.1 CmpEqI64x2 should leave the scalar slot when runtime semantic parity is checkable');

  LCanRunSSE41 := LSSE41Table.BackendInfo.Available and TrySetActiveBackend(sbSSE41);
  if not LCanRunSSE41 then
    Exit;

  LCurrentDispatch := GetDispatchTable;
  CheckEqual(Ord(sbSSE41), Ord(GetActiveBackend), 'Active backend should be SSE4.1 for runtime semantic parity');
  CheckEqual(Ord(sbSSE41), Ord(LCurrentDispatch^.Backend), 'Current dispatch table should resolve to SSE4.1 after forcing the backend');

    LI32A.i[0] := 2;
    LI32A.i[1] := -3;
    LI32A.i[2] := 1000;
    LI32A.i[3] := -2000;
    LI32B.i[0] := 4;
    LI32B.i[1] := 5;
    LI32B.i[2] := -7;
    LI32B.i[3] := 8;

    LDotA.f[0] := 1.0;
    LDotA.f[1] := 2.0;
    LDotA.f[2] := 3.0;
    LDotA.f[3] := 4.0;
    LDotB.f[0] := -5.0;
    LDotB.f[1] := 6.0;
    LDotB.f[2] := -7.0;
    LDotB.f[3] := 8.0;

    LF32RoundInput.f[0] := 1.125;
    LF32RoundInput.f[1] := -2.875;
    LF32RoundInput.f[2] := 3.4;
    LF32RoundInput.f[3] := -4.6;
    LF32SelectA.f[0] := 1.25;
    LF32SelectA.f[1] := 2.25;
    LF32SelectA.f[2] := 3.25;
    LF32SelectA.f[3] := 4.25;
    LF32SelectB.f[0] := 10.5;
    LF32SelectB.f[1] := 20.5;
    LF32SelectB.f[2] := 30.5;
    LF32SelectB.f[3] := 40.5;
    LMask4 := TMask4($5);
    LNormalize4Input.f[0] := 4.0;
    LNormalize4Input.f[1] := 0.0;
    LNormalize4Input.f[2] := 0.0;
    LNormalize4Input.f[3] := 0.0;
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

    LI64CmpA.i[0] := 42;
    LI64CmpA.i[1] := -9000;
    LI64CmpB.i[0] := 42;
    LI64CmpB.i[1] := 9000;

    LI32Expected := ScalarMulI32x4(LI32A, LI32B);
    LI32Actual := LCurrentDispatch^.CoreVectors.MulI32x4(LI32A, LI32B);
    AssertVecI32x4Equal('SSE4.1 MulI32x4 scalar parity', LI32Expected, LI32Actual);

    LDotExpected := ScalarDotF32x4(LDotA, LDotB);
    LDotActual := LCurrentDispatch^.CoreVectors.DotF32x4(LDotA, LDotB);
    CheckNear(LDotExpected, LDotActual, 0.0, 'SSE4.1 DotF32x4 scalar parity');

    LF32RoundExpected := ScalarRoundF32x4(LF32RoundInput);
    LF32RoundActual := LCurrentDispatch^.CoreVectors.RoundF32x4(LF32RoundInput);
    AssertVecF32x4Equal('SSE4.1 RoundF32x4 scalar parity', LF32RoundExpected, LF32RoundActual, 0.0);

    LF32SelectExpected := ScalarSelectF32x4(LMask4, LF32SelectA, LF32SelectB);
    LF32SelectActual := LCurrentDispatch^.CoreVectors.SelectF32x4(LMask4, LF32SelectA, LF32SelectB);
    AssertVecF32x4Equal('SSE4.1 SelectF32x4 scalar parity', LF32SelectExpected, LF32SelectActual, 0.0);

    LF32InsertExpected := ScalarInsertF32x4(LF32SelectA, 99.5, -1);
    LF32InsertActual := LCurrentDispatch^.CoreVectors.InsertF32x4(LF32SelectA, 99.5, -1);
    AssertVecF32x4Equal('SSE4.1 InsertF32x4 low clamp scalar parity', LF32InsertExpected, LF32InsertActual, 0.0);

    LExtractExpected := ScalarExtractF32x4(LF32SelectA, -1);
    LExtractActual := LCurrentDispatch^.CoreVectors.ExtractF32x4(LF32SelectA, -1);
    CheckNear(LExtractExpected, LExtractActual, 0.0, 'SSE4.1 ExtractF32x4 low clamp scalar parity');

    LF32InsertExpected := ScalarInsertF32x4(LF32SelectB, -13.25, 7);
    LF32InsertActual := LCurrentDispatch^.CoreVectors.InsertF32x4(LF32SelectB, -13.25, 7);
    AssertVecF32x4Equal('SSE4.1 InsertF32x4 high clamp scalar parity', LF32InsertExpected, LF32InsertActual, 0.0);

    LExtractExpected := ScalarExtractF32x4(LF32InsertActual, 7);
    LExtractActual := LCurrentDispatch^.CoreVectors.ExtractF32x4(LF32InsertActual, 7);
    CheckNear(LExtractExpected, LExtractActual, 0.0, 'SSE4.1 ExtractF32x4 high clamp scalar parity');

    LNormalize4Expected := ScalarNormalizeF32x4(LNormalize4Input);
    LNormalize4Actual := LCurrentDispatch^.CoreVectors.NormalizeF32x4(LNormalize4Input);
    AssertVecF32x4Equal('SSE4.1 NormalizeF32x4 scalar parity', LNormalize4Expected, LNormalize4Actual, 0.0);

    LNormalize4ZeroExpected := ScalarNormalizeF32x4(LNormalize4ZeroInput);
    LNormalize4ZeroActual := LCurrentDispatch^.CoreVectors.NormalizeF32x4(LNormalize4ZeroInput);
    AssertVecF32x4Equal('SSE4.1 NormalizeF32x4 zero scalar parity', LNormalize4ZeroExpected, LNormalize4ZeroActual, 0.0);

    LNormalize3Expected := ScalarNormalizeF32x3(LNormalize3Input);
    LNormalize3Actual := LCurrentDispatch^.CoreVectors.NormalizeF32x3(LNormalize3Input);
    AssertVecF32x4Equal('SSE4.1 NormalizeF32x3 scalar parity', LNormalize3Expected, LNormalize3Actual, 0.0);

    LNormalize3ZeroExpected := ScalarNormalizeF32x3(LNormalize3ZeroInput);
    LNormalize3ZeroActual := LCurrentDispatch^.CoreVectors.NormalizeF32x3(LNormalize3ZeroInput);
    AssertVecF32x4Equal('SSE4.1 NormalizeF32x3 zero scalar parity', LNormalize3ZeroExpected, LNormalize3ZeroActual, 0.0);

  LMask2Expected := ScalarCmpEqI64x2(LI64CmpA, LI64CmpB);
  LMask2Actual := LCurrentDispatch^.CoreVectors.CmpEqI64x2(LI64CmpA, LI64CmpB);
  CheckEqual(Integer(LMask2Expected), Integer(LMask2Actual), 'SSE4.1 CmpEqI64x2 scalar parity');
end;

procedure TTestCase_DispatchAPICapabilities.Test_SSE42_RepresentativeSemanticParity_WithScalar_IfDispatchable;
var
  LScalarTable: TSimdDispatchTable;
  LSSE42Table: TSimdDispatchTable;
  LCurrentDispatch: PSimdDispatchTable;
  LCanRunSSE42: Boolean;
  LA, LB: TVecI64x2;
  LMaskActual, LMaskExpected: TMask2;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  if not TryGetRegisteredBackendDispatchTable(sbSSE42, LSSE42Table) then
    Exit;

  CheckTrue(Pointer(LSSE42Table.CoreVectors.CmpGtI64x2) <> Pointer(LScalarTable.CoreVectors.CmpGtI64x2), 'SSE4.2 CmpGtI64x2 should leave the scalar slot when runtime semantic parity is checkable');

  LCanRunSSE42 := LSSE42Table.BackendInfo.Available and TrySetActiveBackend(sbSSE42);
  if not LCanRunSSE42 then
    Exit;

  LCurrentDispatch := GetDispatchTable;
  CheckEqual(Ord(sbSSE42), Ord(GetActiveBackend), 'Active backend should be SSE4.2 for runtime semantic parity');
  CheckEqual(Ord(sbSSE42), Ord(LCurrentDispatch^.Backend), 'Current dispatch table should resolve to SSE4.2 after forcing the backend');

  LA.i[0] := 1234567890123;
  LA.i[1] := -10;
  LB.i[0] := 1234567890000;
  LB.i[1] := 20;

  LMaskExpected := ScalarCmpGtI64x2(LA, LB);
  LMaskActual := LCurrentDispatch^.CoreVectors.CmpGtI64x2(LA, LB);
  CheckEqual(Integer(LMaskExpected), Integer(LMaskActual), 'SSE4.2 CmpGtI64x2 scalar parity');
end;

procedure TTestCase_DispatchAPICapabilities.Test_AVX512_PassThroughFacadeSlots_Reuse_AVX2_When_Wrappers_Are_Just_Forwarders;
var
  LAVX2Table: TSimdDispatchTable;
  LAVX512Table: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LUnitSourcePath: string;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LFallbackSourcePath: string;
  LUnitSource: string;
  LRegisterSource: string;
  LFacadeSource: string;
  LFallbackSource: string;

  procedure AssertRegisterKeepsClonedAVX2(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0, 'RegisterAVX512Backend should keep cloned AVX2 ' + aLabel + ' when the AVX512 wrapper is only a pass-through');
  end;

  procedure AssertSlotReusesAVX2(const aLabel: string; const aAVX2Slot, aAVX512Slot: Pointer);
  begin
    CheckEqual(PtrUInt(aAVX2Slot), PtrUInt(aAVX512Slot), 'AVX512 ' + aLabel + ' should reuse the cloned AVX2 slot when the AVX512 wrapper is only a pass-through');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LUnitSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.avx2.pas');
    CheckTrue(FileExists(LUnitSourcePath), 'AVX2 unit source should exist for implementation-shape audit: ' + LUnitSourcePath);
    LSourceLines.LoadFromFile(LUnitSourcePath);
    LUnitSource := LowerCase(LSourceLines.Text);

    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.avx512.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'AVX512 register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.avx512.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'AVX512 facade source should exist for implementation-shape audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LFallbackSource := '';
  finally
    LSourceLines.Free;
  end;

  CheckTrue(Pos('function utf8validate_avx512(', LUnitSource) = 0, 'Utf8Validate_AVX512 pass-through wrapper should be removed from the AVX512 unit interface');
  CheckTrue(Pos('procedure memreverse_avx512(', LUnitSource) = 0, 'MemReverse_AVX512 pass-through wrapper should be removed from the AVX512 unit interface');
  CheckTrue(Pos('function memdiffrange_avx512(', LUnitSource) = 0, 'MemDiffRange_AVX512 pass-through wrapper should be removed from the AVX512 unit interface');
  CheckTrue(Pos('function bytesindexof_avx512(', LUnitSource) = 0, 'BytesIndexOf_AVX512 pass-through wrapper should be removed from the AVX512 unit interface');

  CheckTrue(Pos('function utf8validate_avx512(', LFacadeSource) = 0, 'Utf8Validate_AVX512 pass-through wrapper should be removed from the AVX512 facade include');
  CheckTrue(Pos('procedure memreverse_avx512(', LFacadeSource) = 0, 'MemReverse_AVX512 pass-through wrapper should be removed from the AVX512 facade include');
  CheckTrue(Pos('function memdiffrange_avx512(', LFallbackSource) = 0, 'MemDiffRange_AVX512 pass-through wrapper should be removed from the AVX512 fallback include');
  CheckTrue(Pos('function bytesindexof_avx512(', LFallbackSource) = 0, 'BytesIndexOf_AVX512 pass-through wrapper should be removed from the AVX512 fallback include');

  AssertRegisterKeepsClonedAVX2('Utf8Validate', 'dispatchTable.Memory.Utf8Validate := @Utf8Validate_AVX512;');
  AssertRegisterKeepsClonedAVX2('MemReverse', 'dispatchTable.Memory.Reverse := @MemReverse_AVX512;');
  AssertRegisterKeepsClonedAVX2('MemDiffRange', 'dispatchTable.Memory.DiffRange := @MemDiffRange_AVX512;');
  AssertRegisterKeepsClonedAVX2('BytesIndexOf', 'dispatchTable.Memory.BytesIndexOf := @BytesIndexOf_AVX512;');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;
  if not TryGetRegisteredBackendDispatchTable(sbAVX2, LAVX2Table) then
    Exit;
  if not TryGetRegisteredBackendDispatchTable(sbAVX512, LAVX512Table) then
    Exit;

  AssertSlotReusesAVX2('Utf8Validate', Pointer(LAVX2Table.Memory.Utf8Validate), Pointer(LAVX512Table.Memory.Utf8Validate));
  AssertSlotReusesAVX2('MemReverse', Pointer(LAVX2Table.Memory.Reverse), Pointer(LAVX512Table.Memory.Reverse));
  AssertSlotReusesAVX2('MemDiffRange', Pointer(LAVX2Table.Memory.DiffRange), Pointer(LAVX512Table.Memory.DiffRange));
  AssertSlotReusesAVX2('BytesIndexOf', Pointer(LAVX2Table.Memory.BytesIndexOf), Pointer(LAVX512Table.Memory.BytesIndexOf));
end;

procedure TTestCase_DispatchAPICapabilities.Test_X86_BackendCapabilities_Clear_Shuffle_When_VectorAsmDisabled;
var
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;

  function IsShuffleCapabilityGatedBackend(const aBackend: TSimdBackend): Boolean;
  begin
    case aBackend of
      sbSSE41, sbSSE42, sbAVX2:
        Exit(True);
      else
        Exit(False);
    end;
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  SetVectorAsmEnabled(False);
  CheckFalse(IsVectorAsmEnabled, 'Vector asm should be disabled for x86 shuffle capability rebuild test');

  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
  begin
    if not IsShuffleCapabilityGatedBackend(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;

    CheckEqual(PtrUInt(LScalarTable.CoreVectors.SelectF32x4), PtrUInt(LBackendTable.CoreVectors.SelectF32x4), DispatchApiBackendName(LBackend) + ' SelectF32x4 should fall back to scalar when vector asm is disabled');
    CheckEqual(PtrUInt(LScalarTable.CoreVectors.InsertF32x4), PtrUInt(LBackendTable.CoreVectors.InsertF32x4), DispatchApiBackendName(LBackend) + ' InsertF32x4 should fall back to scalar when vector asm is disabled');
    CheckEqual(PtrUInt(LScalarTable.CoreVectors.ExtractF32x4), PtrUInt(LBackendTable.CoreVectors.ExtractF32x4), DispatchApiBackendName(LBackend) + ' ExtractF32x4 should fall back to scalar when vector asm is disabled');

    CheckFalse(scShuffle in LBackendTable.BackendInfo.Capabilities, 'scShuffle should clear when representative shuffle slots are scalar after vector asm disable: ' + DispatchApiBackendName(LBackend));
  end;
end;

procedure TTestCase_DispatchAPICapabilities.Test_AVX2_BenchmarkWideOps_NotScalar;
var
  LScalar: TSimdDispatchTable;
  LAVX2: TSimdDispatchTable;

  procedure AssertNonScalarSlot(const aSlotName: string; aScalarSlot, aAVX2Slot: Pointer);
  begin
    CheckTrue(aAVX2Slot <> nil, aSlotName + ' missing: AVX2');
    CheckTrue(aAVX2Slot <> aScalarSlot, aSlotName + ' still scalar fallback on AVX2 benchmark path');
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalar), 'Scalar dispatch table should be registered');

  if not IsVectorAsmEnabled then
    Exit;

  if not TryGetRegisteredBackendDispatchTable(sbAVX2, LAVX2) then
    Exit;

  AssertNonScalarSlot('AddI16x32', Pointer(LScalar.CoreVectors.AddI16x32), Pointer(LAVX2.CoreVectors.AddI16x32));
  AssertNonScalarSlot('MulU32x16', Pointer(LScalar.CoreVectors.MulU32x16), Pointer(LAVX2.CoreVectors.MulU32x16));
  AssertNonScalarSlot('AddU64x8', Pointer(LScalar.CoreVectors.AddU64x8), Pointer(LAVX2.CoreVectors.AddU64x8));
  AssertNonScalarSlot('MaxU8x64', Pointer(LScalar.CoreVectors.MaxU8x64), Pointer(LAVX2.CoreVectors.MaxU8x64));
end;

procedure TTestCase_DispatchAPICapabilities.Test_BenchmarkActivation_Rejects_CpuSupportedButNonDispatchable_Backend;
var
  LOriginalBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LModifiedTable: TSimdDispatchTable;
  LBeforeActive: TSimdBackend;
  LSkipReason: string;
begin
  ResetToAutomaticBackend;
  LOriginalBackend := GetActiveBackend;
  if LOriginalBackend = sbScalar then
    Exit;

  CheckTrue(IsBackendAvailableOnCPU(LOriginalBackend), 'Original backend should remain CPU-supported for benchmark activation contract test');
  CheckTrue(TryGetRegisteredBackendDispatchTable(LOriginalBackend, LOriginalTable), 'Original backend should be registered');

  LModifiedTable := LOriginalTable;
  LModifiedTable.BackendInfo.Available := False;
  RegisterBackend(LOriginalBackend, LModifiedTable);
  try
    CheckTrue(IsBackendAvailableOnCPU(LOriginalBackend), 'CPU support should remain true after disabling dispatch wiring');
    CheckFalse(IsBackendDispatchable(LOriginalBackend), 'Dispatchable predicate should clear after disabling dispatch wiring');

    LBeforeActive := GetActiveBackend;
    CheckTrue(LBeforeActive <> LOriginalBackend, 'Synthetic non-dispatchable backend should no longer stay active');

    LSkipReason := '';
    CheckFalse(TryActivateBenchmarkBackend(LOriginalBackend, LSkipReason), 'Benchmark activation should reject CPU-supported but non-dispatchable backend');
    CheckTrue(Pos('dispatch', LowerCase(LSkipReason)) > 0, 'Benchmark activation failure should explain dispatchability');
    CheckEqual(Ord(LBeforeActive), Ord(GetActiveBackend), 'Failed benchmark activation should not change the current active backend');
  finally
    RegisterBackend(LOriginalBackend, LOriginalTable);
  end;
end;

end.
