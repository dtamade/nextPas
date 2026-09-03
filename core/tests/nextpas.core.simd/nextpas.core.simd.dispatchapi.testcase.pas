unit nextpas.core.simd.dispatchapi.testcase;

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
  // Dispatch public API contract tests (script-coupled NEON/RISCVV + wiring core;
  // themed siblings live in dispatchapi.{controlplane,parity,batchparity,capabilities}.testcase)
  TTestCase_DispatchAPI = class(TDispatchAPIStatefulTestCase)
  published
    procedure Test_NEON_PlatformFacadeSlots_Reuse_BaseScalar_When_AlwaysScalarByDesign;
    procedure Test_NEON_FacadeFastSlots_OnlyBind_When_NEONAsm_Is_Compiled;
    procedure Test_NEON_WideFloatMemoryUtilitySlots_Bind_AsmHelpers_When_Available;
    procedure Test_NEON_DotFallbackSlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
    procedure Test_NEON_WideFallbackOnlySlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
    procedure Test_NEON_NoAsmFloatCompareSlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
    procedure Test_NEON_WideRcpAndReductionSlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
    procedure Test_NEON_ExtractInsertSelectSlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
    procedure Test_NEON_NoAsmFMASlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
    procedure Test_NEON_NoAsmNarrowReciprocalSlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
    procedure Test_NEON_NoAsmNarrowI16U16ShiftSlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
    procedure Test_NEON_NoAsmNarrowF64MemorySlots_Reuse_BaseScalar_When_Wrappers_Have_No_Live_SourceConsumers;
    procedure Test_NEON_NoAsmWideF32x8ArithmeticSlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
    procedure Test_NEON_NoAsmWideLeafFloatArithmeticSlots_Keep_SourceCompanions_But_Reuse_BaseScalar;
    procedure Test_NEON_NoAsmWideMinMaxSlots_Keep_Necessary_Wrappers_But_Reuse_BaseScalar;
    procedure Test_NEON_NoAsmNarrowF64MinMaxSlots_Keep_SourceCompanion_But_Reuse_BaseScalar;
    procedure Test_NEON_NoAsmNarrowF64SqrtSlots_Reuse_BaseScalar_When_Wrappers_Are_Dead;
    procedure Test_NEON_NoAsmNarrowF64ExtremaReductionSlots_Reuse_BaseScalar_When_Wrappers_Have_No_SourceConsumers;
    procedure Test_NEON_NoAsmNarrowF64RoundFamilySlots_Reuse_BaseScalar_When_Wrappers_Are_Dead;
    procedure Test_NEON_NoAsmWideSqrtSlots_Reuse_BaseScalar_When_Wrappers_Are_Dead;
    procedure Test_NEON_NoAsmWideRoundTruncSlots_Reuse_BaseScalar_When_Wrappers_Are_Dead;
    procedure Test_NEON_NoAsmNarrowF64CompareAndSimpleReductionSlots_Reuse_BaseScalar_When_Wrappers_Have_No_SourceConsumers;
    procedure Test_NEON_NoAsmWideClampSlots_Reuse_BaseScalar_For_F32_And_F64_When_NoAsm;
    procedure Test_NEON_NoAsmAbsAndWideFloorCeilSlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
    procedure Test_NEON_MaskHelperSlots_Bind_SharedMask_Without_DeadNEONWrappers;
    procedure Test_NEON_BackendCapabilities_Expose_MaskedOps_When_MaskSlots_AreShared;
    procedure Test_NEON_NoAsmWideIntegerCompareSlots_Keep_SourceCompanions_But_Reuse_BaseScalar;
    procedure Test_NEON_NoAsmIntegerFallbackSlots_Reuse_BaseScalar_When_Wrappers_Are_Not_BackendOwned;
    procedure Test_NEON_SelectF32x4_Keep_LocalSourceCompanion_But_Reuse_BaseScalar_RuntimeSlot;
    procedure Test_NEON_AndNotSlots_Keep_AsmOwnedCompositions_And_RuntimeOwnership;
    procedure Test_RISCVV_DotF64Slots_Reuse_BaseScalar_When_ScalarForwarders_Are_Dead;
    procedure Test_RISCVV_ExactScalarHelperSlots_Reuse_BaseScalar_When_Owners_Are_Dead;
    procedure Test_RISCVV_FacadeSlots_Reuse_BaseScalar_When_Wrappers_Are_ScalarPassThrough;
    procedure Test_RISCVV_MemoryBatch_Intentionally_Scalar_Until_RealLeaf;
    procedure Test_RISCVV_WideFallbackOnlySlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
    procedure Test_RISCVV_ExtractSlots_Reuse_BaseScalar_When_NoAsmWrappers_Are_Dead;
    procedure Test_RISCVV_AndNotSlots_Keep_AsmOwnedCompositions_And_Reuse_BaseScalar_When_NoAsm;
    procedure Test_RISCVV_KeyOwnedWideSlots_Stay_BackendOwned;
    procedure Test_RISCVV_ClampF64x2_Drops_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
    procedure Test_RISCVV_ExactF64x2Slots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
    procedure Test_RISCVV_ArithmeticF64x2Slots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
    procedure Test_RISCVV_ArithmeticF32x4Slots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
    procedure Test_RISCVV_I32x4ConditionalIntegerSlots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
    procedure Test_RISCVV_I64x2ConditionalIntegerSlots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
    procedure Test_RISCVV_U32x4ConditionalIntegerSlots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
    procedure Test_RISCVV_I32x4CompareSlots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
    procedure Test_RISCVV_I64x2CompareSlots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
    procedure Test_RISCVV_ExactF32x4Slots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
    procedure Test_RISCVV_F32x4UtilitySlots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
    procedure Test_RISCVV_F64x2UtilitySlots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
    procedure Test_RISCVV_WideFloatLoadSlots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
    procedure Test_RISCVV_FloatStoreSlots_Keep_BackendOwnership_And_Reuse_ScalarPreconditions_When_NoAsm;
    procedure Test_RISCVV_LocalExtremaF64x2_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
    procedure Test_RISCVV_LocalExtremaF32x4_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
    procedure Test_RISCVV_CrossF32x3_Drops_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
    procedure Test_RISCVV_NormalizeF32Slots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
    procedure Test_RISCVV_ReduceF64x2_Stays_BackendOwned_With_ExactScalarNoAsmWitness;
    procedure Test_RISCVV_WideRoundingAndF32ClampSlots_Reuse_BaseScalar_When_ScalarForwarders_Are_Dead;
    procedure Test_NEON_BackendCapabilities_Expose_Shuffle_When_RepresentativeSlots_AreNonScalar;
    procedure Test_NEON_BackendCapabilities_Expose_IntegerOps_When_IntegerSlots_AreNative;
    procedure Test_NEON_BackendCapabilities_Expose_FMA_When_FmaSlots_AreNative;
    procedure Test_NEON_BackendCapabilities_Clear_VectorAsmGatedBits_When_VectorAsmDisabled;
    procedure Test_RISCVV_BackendCapabilities_Expose_IntegerOps_When_IntegerSlots_AreNative;
    procedure Test_RISCVV_BackendCapabilities_Expose_FMA_When_FmaSlots_AreNonScalar;
    procedure Test_RISCVV_BackendCapabilities_Expose_Shuffle_When_RepresentativeSlots_AreNonScalar;
    procedure Test_RISCVV_BackendCapabilities_Clear_VectorAsmGatedBits_When_VectorAsmDisabled;
    procedure Test_NonX86_DispatchTable_WiringChecklist_Grouped;
    procedure Test_NonX86_DispatchTable_WiringChecklist;
    procedure Test_NonX86_NativeWideFloorCeil_Slots_NotScalar_IfAvailable;
    procedure Test_X86_DispatchTable_WiringChecklist_Grouped;
    procedure Test_Phase19_DispatchTable_NestedOnly_NoDeadDraftArtifacts;
  end;

// Shared wiring assertion (exported: dispatchapi.nonx86.testcase reuses it).
procedure AssertNonX86DispatchTableWiringGroupsAssigned(aTestCase: TTestFixture; const aBackendName: string; const aTable: TSimdDispatchTable);

implementation

procedure AssertNonX86DispatchTableWiringGroupsAssigned(aTestCase: TTestFixture; const aBackendName: string; const aTable: TSimdDispatchTable);
  procedure AssertSlotGroup(const aGroupName: string;
    const aNames: array of string; const aSlots: array of Pointer);
  var
    LIndex: Integer;
  begin
    CheckEqual(Length(aNames), Length(aSlots), aGroupName + '.slot-count');
    for LIndex := 0 to High(aNames) do
      CheckTrue(aSlots[LIndex] <> nil, aGroupName + '.' + aNames[LIndex] + ' missing: ' + aBackendName);
  end;
begin
  AssertSlotGroup(
    'WideI64AndU64', ['AndNotI64x2', 'ShiftLeftI64x2', 'ShiftRightI64x2', 'ShiftRightArithI64x2', 'MinI64x2', 'MaxI64x2',
     'AddU64x2', 'SubU64x2', 'AndU64x2', 'OrU64x2', 'XorU64x2', 'NotU64x2', 'AndNotU64x2', 'CmpEqU64x2', 'CmpLtU64x2', 'CmpGtU64x2', 'MinU64x2', 'MaxU64x2'],
    [Pointer(aTable.CoreVectors.AndNotI64x2), Pointer(aTable.CoreVectors.ShiftLeftI64x2), Pointer(aTable.CoreVectors.ShiftRightI64x2), Pointer(aTable.CoreVectors.ShiftRightArithI64x2), Pointer(aTable.CoreVectors.MinI64x2), Pointer(aTable.CoreVectors.MaxI64x2), Pointer(aTable.CoreVectors.AddU64x2), Pointer(aTable.CoreVectors.SubU64x2),
     Pointer(aTable.CoreVectors.AndU64x2), Pointer(aTable.CoreVectors.OrU64x2), Pointer(aTable.CoreVectors.XorU64x2), Pointer(aTable.CoreVectors.NotU64x2), Pointer(aTable.CoreVectors.AndNotU64x2), Pointer(aTable.CoreVectors.CmpEqU64x2), Pointer(aTable.CoreVectors.CmpLtU64x2), Pointer(aTable.CoreVectors.CmpGtU64x2),
     Pointer(aTable.CoreVectors.MinU64x2), Pointer(aTable.CoreVectors.MaxU64x2)]
  );

  AssertSlotGroup(
    'Wide256I64x4U64x4', ['AddI64x4', 'SubI64x4', 'AndI64x4', 'OrI64x4', 'XorI64x4', 'NotI64x4', 'AndNotI64x4',
     'ShiftLeftI64x4', 'ShiftRightI64x4', 'ShiftRightArithI64x4', 'CmpEqI64x4', 'CmpLtI64x4', 'CmpGtI64x4', 'CmpLeI64x4', 'CmpGeI64x4', 'CmpNeI64x4', 'AddU64x4', 'SubU64x4', 'AndU64x4', 'OrU64x4', 'XorU64x4', 'NotU64x4',
     'ShiftLeftU64x4', 'ShiftRightU64x4', 'CmpEqU64x4', 'CmpLtU64x4', 'CmpGtU64x4', 'CmpLeU64x4', 'CmpGeU64x4', 'CmpNeU64x4'], [Pointer(aTable.CoreVectors.AddI64x4), Pointer(aTable.CoreVectors.SubI64x4), Pointer(aTable.CoreVectors.AndI64x4), Pointer(aTable.CoreVectors.OrI64x4), Pointer(aTable.CoreVectors.XorI64x4),
     Pointer(aTable.CoreVectors.NotI64x4), Pointer(aTable.CoreVectors.AndNotI64x4), Pointer(aTable.CoreVectors.ShiftLeftI64x4), Pointer(aTable.CoreVectors.ShiftRightI64x4), Pointer(aTable.CoreVectors.ShiftRightArithI64x4), Pointer(aTable.CoreVectors.CmpEqI64x4), Pointer(aTable.CoreVectors.CmpLtI64x4), Pointer(aTable.CoreVectors.CmpGtI64x4), Pointer(aTable.CoreVectors.CmpLeI64x4), Pointer(aTable.CoreVectors.CmpGeI64x4), Pointer(aTable.CoreVectors.CmpNeI64x4),
     Pointer(aTable.CoreVectors.AddU64x4), Pointer(aTable.CoreVectors.SubU64x4), Pointer(aTable.CoreVectors.AndU64x4), Pointer(aTable.CoreVectors.OrU64x4), Pointer(aTable.CoreVectors.XorU64x4), Pointer(aTable.CoreVectors.NotU64x4), Pointer(aTable.CoreVectors.ShiftLeftU64x4), Pointer(aTable.CoreVectors.ShiftRightU64x4), Pointer(aTable.CoreVectors.CmpEqU64x4), Pointer(aTable.CoreVectors.CmpLtU64x4), Pointer(aTable.CoreVectors.CmpGtU64x4),
     Pointer(aTable.CoreVectors.CmpLeU64x4), Pointer(aTable.CoreVectors.CmpGeU64x4), Pointer(aTable.CoreVectors.CmpNeU64x4)]
  );

  AssertSlotGroup(
    'Wide512I64x8', ['AddI64x8', 'SubI64x8', 'AndI64x8', 'OrI64x8', 'XorI64x8', 'NotI64x8',
     'CmpEqI64x8', 'CmpLtI64x8', 'CmpGtI64x8', 'CmpLeI64x8', 'CmpGeI64x8', 'CmpNeI64x8'], [Pointer(aTable.CoreVectors.AddI64x8), Pointer(aTable.CoreVectors.SubI64x8), Pointer(aTable.CoreVectors.AndI64x8), Pointer(aTable.CoreVectors.OrI64x8),
     Pointer(aTable.CoreVectors.XorI64x8), Pointer(aTable.CoreVectors.NotI64x8), Pointer(aTable.CoreVectors.CmpEqI64x8), Pointer(aTable.CoreVectors.CmpLtI64x8), Pointer(aTable.CoreVectors.CmpGtI64x8), Pointer(aTable.CoreVectors.CmpLeI64x8), Pointer(aTable.CoreVectors.CmpGeI64x8), Pointer(aTable.CoreVectors.CmpNeI64x8)]
  );
end;

procedure TTestCase_DispatchAPI.Test_NEON_PlatformFacadeSlots_Reuse_BaseScalar_When_AlwaysScalarByDesign;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;

  procedure AssertRegisterKeepsBaseScalar(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0, 'RegisterNEONBackend should keep base scalar ' + aLabel + ' until a real NEON leaf exists');
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot until a real NEON leaf exists');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.facade.platform.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'NEON platform facade source should exist for implementation-shape audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  // Phase 22b closed Memory (15/15). Phase 23 + B1/B2 own BatchF32 Add/Sub/Mul/
  // Min/Max/Abs/Neg/Div/MulScalar/AddScalar under ASM (FacadeFastSlots). Remaining Batch* stay scalar.
  CheckTrue(Trim(LFacadeSource) <> '', 'Retired platform facade include should remain as an audited empty boundary');
  // Wave C4 + C5–C5d: F32/F64 transc sample — forbid broader expansion.
  CheckTrue(Pos('table.batchf64.arrayround :=', LRegisterSource) = 0, 'RegisterNEONBackend should not override BatchF64.ArrayRound until owned');
  CheckTrue(Pos('table.batchf64.arraylog :=', LRegisterSource) = 0, 'RegisterNEONBackend should not override BatchF64.ArrayLog until owned');
  CheckTrue(Pos('table.batchf64.arraycos :=', LRegisterSource) = 0, 'RegisterNEONBackend should not override BatchF64.ArrayCos until owned');
  CheckTrue(Pos('table.batchf32.arraytan :=', LRegisterSource) = 0, 'RegisterNEONBackend should not override BatchF32.ArrayTan until owned');
  CheckTrue(Pos('table.batchinteger.', LRegisterSource) = 0, 'RegisterNEONBackend should not override BatchInteger until a real NEON leaf exists');
  // Wave C boundary: Round still unowned (C2 owns Ceil/Floor/Trunc only).
  CheckTrue(Pos('table.batchf32.arrayround :=', LRegisterSource) = 0, 'RegisterNEONBackend should not override BatchF32.ArrayRound until C2b owns it');

  // Defensive: no Memory dead wrappers reintroduced into the retired include.
  AssertRegisterKeepsBaseScalar('retired MemReverse platform path', 'table.Memory.Reverse := @MemReverse_Scalar;');
  CheckTrue(Pos('procedure memreverse_neon(', LFacadeSource) = 0, 'MemReverse_NEON must not live in the retired platform facade include');
  CheckTrue(Pos('function utf8validate_neon(', LFacadeSource) = 0, 'Utf8Validate_NEON must not live in the retired platform facade include');
  CheckTrue(Pos('function bytesindexof_neon(', LFacadeSource) = 0, 'BytesIndexOf_NEON must not live in the retired platform facade include');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  // Remaining Batch slots still inherit FillBase scalar (outside owned leaves).
  AssertSlotReusesScalar('BatchF32.ArrayTan', Pointer(LScalarTable.BatchF32.ArrayTan), Pointer(LNEONTable.BatchF32.ArrayTan));
  AssertSlotReusesScalar('BatchF32.ArrayRound', Pointer(LScalarTable.BatchF32.ArrayRound), Pointer(LNEONTable.BatchF32.ArrayRound));
  AssertSlotReusesScalar('BatchF64.ArrayLog', Pointer(LScalarTable.BatchF64.ArrayLog), Pointer(LNEONTable.BatchF64.ArrayLog));
  AssertSlotReusesScalar('BatchF64.ArrayCos', Pointer(LScalarTable.BatchF64.ArrayCos), Pointer(LNEONTable.BatchF64.ArrayCos));
  AssertSlotReusesScalar('BatchF64.ArrayRound', Pointer(LScalarTable.BatchF64.ArrayRound), Pointer(LNEONTable.BatchF64.ArrayRound));
  AssertSlotReusesScalar('BatchInteger.ArrayAddI32', Pointer(LScalarTable.BatchInteger.ArrayAddI32), Pointer(LNEONTable.BatchInteger.ArrayAddI32));
end;

procedure TTestCase_DispatchAPI.Test_NEON_FacadeFastSlots_OnlyBind_When_NEONAsm_Is_Compiled;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LAsmFacadeSourcePath: string;
  LScalarFacadeSourcePath: string;
  LRegisterSource: string;
  LAsmFacadeSource: string;
  LScalarFacadeSource: string;

  procedure AssertSourceContains(const aLabel, aSnippet, aSource: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), aSource) > 0, aLabel + ' source should contain expected implementation snippet');
  end;

  procedure AssertRuntimeSlotExpectation(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
    CheckTrue(aBackendSlot <> aScalarSlot, 'NEON ' + aLabel + ' should stay native when NEON asm facade is compiled');
    {$ELSE}
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should stay scalar when NEON asm facade is not compiled');
    {$ENDIF}
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LAsmFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.facade.asm.inc');
    CheckTrue(FileExists(LAsmFacadeSourcePath), 'NEON asm facade source should exist for implementation-shape audit: ' + LAsmFacadeSourcePath);
    LSourceLines.LoadFromFile(LAsmFacadeSourcePath);
    LAsmFacadeSource := LowerCase(LSourceLines.Text);

    LScalarFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.facade.scalar.inc');
    CheckTrue(FileExists(LScalarFacadeSourcePath), 'NEON scalar facade source should exist for implementation-shape audit: ' + LScalarFacadeSourcePath);
    LSourceLines.LoadFromFile(LScalarFacadeSourcePath);
    LScalarFacadeSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertSourceContains('MemEqual_NEON asm', 'function MemEqual_NEON(a, b: Pointer; len: SizeUInt): LongBool; assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('MemFindByte_NEON asm', 'function MemFindByte_NEON(p: Pointer; len: SizeUInt; value: Byte): PtrInt; assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('MemDiffRange_NEON asm', 'function MemDiffRange_NEON(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean; assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('MemCopy_NEON asm', 'procedure MemCopy_NEON(src, dst: Pointer; len: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('MemSet_NEON asm', 'procedure MemSet_NEON(dst: Pointer; len: SizeUInt; value: Byte); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('MemReverse_NEON asm', 'procedure MemReverse_NEON(p: Pointer; len: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('BytesIndexOf_NEON asm', 'function BytesIndexOf_NEON(haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt): PtrInt; assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('Utf8Validate_NEON asm', 'function Utf8Validate_NEON(p: Pointer; len: SizeUInt): Boolean; assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayAddF32 asm', 'procedure NEONArrayAddF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArraySubF32 asm', 'procedure NEONArraySubF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayMulF32 asm', 'procedure NEONArrayMulF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayDivF32 asm', 'procedure NEONArrayDivF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayMinF32 asm', 'procedure NEONArrayMinF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayMaxF32 asm', 'procedure NEONArrayMaxF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayAbsF32 asm', 'procedure NEONArrayAbsF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayNegF32 asm', 'procedure NEONArrayNegF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayMulScalarF32 asm', 'procedure NEONArrayMulScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayAddScalarF32 asm', 'procedure NEONArrayAddScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayClampF32 asm', 'procedure NEONArrayClampF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMin, aMax: Single); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayLerpF32 asm', 'procedure NEONArrayLerpF32(aStart, aEnd, aDst: PSingle; aCount: SizeUInt; aT: Single); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayFmaF32 asm', 'procedure NEONArrayFmaF32(aA, aB, aC, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayAxpyF32 asm', 'procedure NEONArrayAxpyF32(aAlpha: Single; aX, aY, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArraySqrtF32 asm', 'procedure NEONArraySqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONReduceSumF32 asm', 'function NEONReduceSumF32(aSrc: PSingle; aCount: SizeUInt): Single; assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONReduceMinF32 asm', 'function NEONReduceMinF32(aSrc: PSingle; aCount: SizeUInt): Single; assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONReduceMaxF32 asm', 'function NEONReduceMaxF32(aSrc: PSingle; aCount: SizeUInt): Single; assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayRcpF32 asm', 'procedure NEONArrayRcpF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONReduceDotF32 asm', 'function NEONReduceDotF32(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single; assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayRsqrtF32 asm', 'procedure NEONArrayRsqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayRcpRefineF32 asm', 'procedure NEONArrayRcpRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayRsqrtRefineF32 asm', 'procedure NEONArrayRsqrtRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayLinearF32 asm', 'procedure NEONArrayLinearF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayCeilF32 asm', 'procedure NEONArrayCeilF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayFloorF32 asm', 'procedure NEONArrayFloorF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayTruncF32 asm', 'procedure NEONArrayTruncF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayReLUF32 asm', 'procedure NEONArrayReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayAbsDiffF32 asm', 'procedure NEONArrayAbsDiffF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayAddF64 asm', 'procedure NEONArrayAddF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArraySubF64 asm', 'procedure NEONArraySubF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayMulF64 asm', 'procedure NEONArrayMulF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayDivF64 asm', 'procedure NEONArrayDivF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayMinF64 asm', 'procedure NEONArrayMinF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayMaxF64 asm', 'procedure NEONArrayMaxF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayAbsF64 asm', 'procedure NEONArrayAbsF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayNegF64 asm', 'procedure NEONArrayNegF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArraySqrtF64 asm', 'procedure NEONArraySqrtF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayMulScalarF64 asm', 'procedure NEONArrayMulScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayAddScalarF64 asm', 'procedure NEONArrayAddScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONReduceSumF64 asm', 'function NEONReduceSumF64(aSrc: PDouble; aCount: SizeUInt): Double; assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONReduceDotF64 asm', 'function NEONReduceDotF64(aSrc1, aSrc2: PDouble; aCount: SizeUInt): Double; assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONReduceMinF64 asm', 'function NEONReduceMinF64(aSrc: PDouble; aCount: SizeUInt): Double; assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONReduceMaxF64 asm', 'function NEONReduceMaxF64(aSrc: PDouble; aCount: SizeUInt): Double; assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayLinearF64 asm', 'procedure NEONArrayLinearF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayClampF64 asm', 'procedure NEONArrayClampF64(aSrc, aDst: PDouble; aCount: SizeUInt; aMin, aMax: Double); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayLerpF64 asm', 'procedure NEONArrayLerpF64(aStart, aEnd, aDst: PDouble; aCount: SizeUInt; aT: Double); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayFmaF64 asm', 'procedure NEONArrayFmaF64(aA, aB, aC, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayAxpyF64 asm', 'procedure NEONArrayAxpyF64(aAlpha: Double; aX, aY, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayCeilF64 asm', 'procedure NEONArrayCeilF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayFloorF64 asm', 'procedure NEONArrayFloorF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayTruncF64 asm', 'procedure NEONArrayTruncF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayReLUF64 asm', 'procedure NEONArrayReLUF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayAbsDiffF64 asm', 'procedure NEONArrayAbsDiffF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayRcpF64 asm', 'procedure NEONArrayRcpF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayRsqrtF64 asm', 'procedure NEONArrayRsqrtF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayRcpRefineF64 asm', 'procedure NEONArrayRcpRefineF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayRsqrtRefineF64 asm', 'procedure NEONArrayRsqrtRefineF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArraySinF32 C5e asm', 'procedure NEONArraySinF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayExpF32 C5e asm', 'procedure NEONArrayExpF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArraySinF32 C5e 4-wide', 'fmul  v3.4s, v2.4s, v16.4s', LAsmFacadeSource);
  AssertSourceContains('NEONArrayExpF32 C5e 4-wide', 'fmul  v1.4s, v0.4s, v16.4s', LAsmFacadeSource);
  AssertSourceContains('NEONArrayCosF32 C5e-ext asm', 'procedure NEONArrayCosF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArraySinCosF32 C5b', 'procedure NEONArraySinCosF32(aSrc, aSinDst, aCosDst: PSingle; aCount: SizeUInt);', LAsmFacadeSource);
  AssertSourceContains('NEONArrayLogF32 C5e-ext asm', 'procedure NEONArrayLogF32(aSrc, aDst: PSingle; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayLog2F32 C5c', 'procedure NEONArrayLog2F32(aSrc, aDst: PSingle; aCount: SizeUInt);', LAsmFacadeSource);
  AssertSourceContains('NEONArrayLog10F32 C5c', 'procedure NEONArrayLog10F32(aSrc, aDst: PSingle; aCount: SizeUInt);', LAsmFacadeSource);
  AssertSourceContains('NEONArraySinF64 C5e-ext asm', 'procedure NEONArraySinF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayExpF64 C5e-ext asm', 'procedure NEONArrayExpF64(aSrc, aDst: PDouble; aCount: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('NEONArrayCosF32 4-wide', 'fmul  v3.4s, v2.4s, v16.4s', LAsmFacadeSource);
  AssertSourceContains('NEONArrayLogF32 4-wide', 'fdiv  v4.4s, v4.4s, v5.4s', LAsmFacadeSource);
  AssertSourceContains('NEONArraySinF64 2-wide', 'fmul  v3.2d, v2.2d, v16.2d', LAsmFacadeSource);
  AssertSourceContains('NEONArrayExpF64 2-wide', 'fmul  v1.2d, v0.2d, v16.2d', LAsmFacadeSource);
  AssertSourceContains('SumBytes_NEON asm', 'function SumBytes_NEON(p: Pointer; len: SizeUInt): UInt64; assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('MinMaxBytes_NEON asm', 'procedure MinMaxBytes_NEON(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('CountByte_NEON asm', 'function CountByte_NEON(p: Pointer; len: SizeUInt; value: Byte): SizeUInt; assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('AsciiIEqual_NEON asm', 'function AsciiIEqual_NEON(a, b: Pointer; len: SizeUInt): Boolean; assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('ToLowerAscii_NEON asm', 'procedure ToLowerAscii_NEON(p: Pointer; len: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('ToUpperAscii_NEON asm', 'procedure ToUpperAscii_NEON(p: Pointer; len: SizeUInt); assembler; nostackframe;', LAsmFacadeSource);
  AssertSourceContains('BitsetPopCount_NEON asm', 'function BitsetPopCount_NEON(p: Pointer; byteLen: SizeUInt): SizeUInt; assembler; nostackframe;', LAsmFacadeSource);

  AssertSourceContains('MemEqual_NEON scalar fallback', 'Result := MemEqual_Scalar(a, b, len);', LScalarFacadeSource);
  AssertSourceContains('MemFindByte_NEON scalar fallback', 'Result := MemFindByte_Scalar(p, len, value);', LScalarFacadeSource);
  AssertSourceContains('MemDiffRange_NEON scalar fallback', 'Result := MemDiffRange_Scalar(a, b, len, firstDiff, lastDiff);', LScalarFacadeSource);
  AssertSourceContains('MemCopy_NEON scalar fallback', 'MemCopy_Scalar(src, dst, len);', LScalarFacadeSource);
  AssertSourceContains('MemSet_NEON scalar fallback', 'MemSet_Scalar(dst, len, value);', LScalarFacadeSource);
  AssertSourceContains('MemReverse_NEON scalar fallback', 'MemReverse_Scalar(p, len);', LScalarFacadeSource);
  AssertSourceContains('BytesIndexOf_NEON scalar fallback', 'Result := BytesIndexOf_Scalar(haystack, haystackLen, needle, needleLen);', LScalarFacadeSource);
  AssertSourceContains('Utf8Validate_NEON scalar fallback', 'Result := Utf8Validate_Scalar(p, len);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayAddF32 scalar fallback', 'ScalarArrayAddF32(aSrc1, aSrc2, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArraySubF32 scalar fallback', 'ScalarArraySubF32(aSrc1, aSrc2, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayMulF32 scalar fallback', 'ScalarArrayMulF32(aSrc1, aSrc2, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayDivF32 scalar fallback', 'ScalarArrayDivF32(aSrc1, aSrc2, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayMinF32 scalar fallback', 'ScalarArrayMinF32(aSrc1, aSrc2, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayMaxF32 scalar fallback', 'ScalarArrayMaxF32(aSrc1, aSrc2, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayAbsF32 scalar fallback', 'ScalarArrayAbsF32(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayNegF32 scalar fallback', 'ScalarArrayNegF32(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayMulScalarF32 scalar fallback', 'ScalarArrayMulScalarF32(aSrc, aDst, aCount, aScalar);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayAddScalarF32 scalar fallback', 'ScalarArrayAddScalarF32(aSrc, aDst, aCount, aScalar);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayClampF32 scalar fallback', 'ScalarArrayClampF32(aSrc, aDst, aCount, aMin, aMax);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayLerpF32 scalar fallback', 'ScalarArrayLerpF32(aStart, aEnd, aDst, aCount, aT);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayFmaF32 scalar fallback', 'ScalarArrayFmaF32(aA, aB, aC, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayAxpyF32 scalar fallback', 'ScalarArrayAxpyF32(aAlpha, aX, aY, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArraySqrtF32 scalar fallback', 'ScalarArraySqrtF32(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONReduceSumF32 scalar fallback', 'Result := ScalarReduceSumF32(aSrc, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONReduceMinF32 scalar fallback', 'Result := ScalarReduceMinF32(aSrc, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONReduceMaxF32 scalar fallback', 'Result := ScalarReduceMaxF32(aSrc, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayRcpF32 scalar fallback', 'ScalarArrayRcpF32(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONReduceDotF32 scalar fallback', 'Result := ScalarReduceDotF32(aSrc1, aSrc2, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayRsqrtF32 scalar fallback', 'ScalarArrayRsqrtF32(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayRcpRefineF32 scalar fallback', 'ScalarArrayRcpRefineF32(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayRsqrtRefineF32 scalar fallback', 'ScalarArrayRsqrtRefineF32(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayLinearF32 scalar fallback', 'ScalarArrayLinearF32(aSrc, aDst, aCount, aScale, aBias);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayCeilF32 scalar fallback', 'ScalarArrayCeilF32(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayFloorF32 scalar fallback', 'ScalarArrayFloorF32(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayTruncF32 scalar fallback', 'ScalarArrayTruncF32(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayReLUF32 scalar fallback', 'ScalarArrayReLUF32(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayAbsDiffF32 scalar fallback', 'ScalarArrayAbsDiffF32(aSrc1, aSrc2, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayAddF64 scalar fallback', 'ScalarArrayAddF64(aSrc1, aSrc2, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArraySubF64 scalar fallback', 'ScalarArraySubF64(aSrc1, aSrc2, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayMulF64 scalar fallback', 'ScalarArrayMulF64(aSrc1, aSrc2, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayDivF64 scalar fallback', 'ScalarArrayDivF64(aSrc1, aSrc2, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayMinF64 scalar fallback', 'ScalarArrayMinF64(aSrc1, aSrc2, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayMaxF64 scalar fallback', 'ScalarArrayMaxF64(aSrc1, aSrc2, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayAbsF64 scalar fallback', 'ScalarArrayAbsF64(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayNegF64 scalar fallback', 'ScalarArrayNegF64(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArraySqrtF64 scalar fallback', 'ScalarArraySqrtF64(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayMulScalarF64 scalar fallback', 'ScalarArrayMulScalarF64(aSrc, aDst, aCount, aScalar);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayAddScalarF64 scalar fallback', 'ScalarArrayAddScalarF64(aSrc, aDst, aCount, aScalar);', LScalarFacadeSource);
  AssertSourceContains('NEONReduceSumF64 scalar fallback', 'Result := ScalarReduceSumF64(aSrc, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONReduceDotF64 scalar fallback', 'Result := ScalarReduceDotF64(aSrc1, aSrc2, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONReduceMinF64 scalar fallback', 'Result := ScalarReduceMinF64(aSrc, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONReduceMaxF64 scalar fallback', 'Result := ScalarReduceMaxF64(aSrc, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayLinearF64 scalar fallback', 'ScalarArrayLinearF64(aSrc, aDst, aCount, aScale, aBias);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayClampF64 scalar fallback', 'ScalarArrayClampF64(aSrc, aDst, aCount, aMin, aMax);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayLerpF64 scalar fallback', 'ScalarArrayLerpF64(aStart, aEnd, aDst, aCount, aT);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayFmaF64 scalar fallback', 'ScalarArrayFmaF64(aA, aB, aC, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayAxpyF64 scalar fallback', 'ScalarArrayAxpyF64(aAlpha, aX, aY, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayCeilF64 scalar fallback', 'ScalarArrayCeilF64(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayFloorF64 scalar fallback', 'ScalarArrayFloorF64(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayTruncF64 scalar fallback', 'ScalarArrayTruncF64(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayReLUF64 scalar fallback', 'ScalarArrayReLUF64(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayAbsDiffF64 scalar fallback', 'ScalarArrayAbsDiffF64(aSrc1, aSrc2, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayRcpF64 scalar fallback', 'ScalarArrayRcpF64(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayRsqrtF64 scalar fallback', 'ScalarArrayRsqrtF64(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayRcpRefineF64 scalar fallback', 'ScalarArrayRcpRefineF64(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayRsqrtRefineF64 scalar fallback', 'ScalarArrayRsqrtRefineF64(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArraySinF32 scalar fallback', 'ScalarArraySinF32(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayExpF32 scalar fallback', 'ScalarArrayExpF32(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayCosF32 scalar fallback', 'ScalarArrayCosF32(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArraySinCosF32 scalar fallback', 'ScalarArraySinCosF32(aSrc, aSinDst, aCosDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayLogF32 scalar fallback', 'ScalarArrayLogF32(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayLog2F32 scalar fallback', 'ScalarArrayLog2F32(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayLog10F32 scalar fallback', 'ScalarArrayLog10F32(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArraySinF64 scalar fallback', 'ScalarArraySinF64(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('NEONArrayExpF64 scalar fallback', 'ScalarArrayExpF64(aSrc, aDst, aCount);', LScalarFacadeSource);
  AssertSourceContains('SumBytes_NEON scalar fallback', 'Result := SumBytes_Scalar(p, len);', LScalarFacadeSource);
  AssertSourceContains('MinMaxBytes_NEON scalar fallback', 'MinMaxBytes_Scalar(p, len, minVal, maxVal);', LScalarFacadeSource);
  AssertSourceContains('CountByte_NEON scalar fallback', 'Result := CountByte_Scalar(p, len, value);', LScalarFacadeSource);
  AssertSourceContains('AsciiIEqual_NEON scalar fallback', 'Result := AsciiIEqual_Scalar(a, b, len);', LScalarFacadeSource);
  AssertSourceContains('ToLowerAscii_NEON scalar fallback', 'ToLowerAscii_Scalar(p, len);', LScalarFacadeSource);
  AssertSourceContains('ToUpperAscii_NEON scalar fallback', 'ToUpperAscii_Scalar(p, len);', LScalarFacadeSource);
  AssertSourceContains('BitsetPopCount_NEON scalar fallback', 'Result := BitsetPopCount_Scalar(p, byteLen);', LScalarFacadeSource);

  CheckTrue(Pos('table.memory.equal := @memequal_neon;', LRegisterSource) > 0, 'RegisterNEONBackend should still wire MemEqual_NEON explicitly so asm builds keep the native facade slot');
  CheckTrue(Pos('table.memory.findbyte := @memfindbyte_neon;', LRegisterSource) > 0, 'RegisterNEONBackend should still wire MemFindByte_NEON explicitly so asm builds keep the native facade slot');
  CheckTrue(Pos('table.memory.diffrange := @memdiffrange_neon;', LRegisterSource) > 0, 'RegisterNEONBackend should wire MemDiffRange_NEON for Phase 22a Memory leaves');
  CheckTrue(Pos('table.memory.copy := @memcopy_neon;', LRegisterSource) > 0, 'RegisterNEONBackend should wire MemCopy_NEON for Phase 22a Memory leaves');
  CheckTrue(Pos('table.memory.fill := @memset_neon;', LRegisterSource) > 0, 'RegisterNEONBackend should wire MemSet_NEON for Phase 22a Memory leaves');
  CheckTrue(Pos('table.memory.reverse := @memreverse_neon;', LRegisterSource) > 0, 'RegisterNEONBackend should wire MemReverse_NEON for Phase 22b Memory leaves');
  CheckTrue(Pos('table.memory.bytesindexof := @bytesindexof_neon;', LRegisterSource) > 0, 'RegisterNEONBackend should wire BytesIndexOf_NEON for Phase 22b Memory leaves');
  CheckTrue(Pos('table.memory.utf8validate := @utf8validate_neon;', LRegisterSource) > 0, 'RegisterNEONBackend should wire Utf8Validate_NEON for Phase 22b Memory leaves');
  CheckTrue(Pos('table.batchf32.arrayadd := @neonarrayaddf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayAddF32 for Phase 23a BatchF32 leaves');
  CheckTrue(Pos('table.batchf32.arraysub := @neonarraysubf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArraySubF32 for Phase 23a BatchF32 leaves');
  CheckTrue(Pos('table.batchf32.arraymul := @neonarraymulf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayMulF32 for Phase 23a BatchF32 leaves');
  CheckTrue(Pos('table.batchf32.arraydiv := @neonarraydivf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayDivF32 for Batch B1 BatchF32 leaves');
  CheckTrue(Pos('table.batchf32.arraymin := @neonarrayminf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayMinF32 for Phase 23b BatchF32 leaves');
  CheckTrue(Pos('table.batchf32.arraymax := @neonarraymaxf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayMaxF32 for Phase 23b BatchF32 leaves');
  CheckTrue(Pos('table.batchf32.arrayabs := @neonarrayabsf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayAbsF32 for Phase 23b BatchF32 leaves');
  CheckTrue(Pos('table.batchf32.arrayneg := @neonarraynegf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayNegF32 for Phase 23b BatchF32 leaves');
  CheckTrue(Pos('table.batchf32.arraymulscalar := @neonarraymulscalarf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayMulScalarF32 for Batch B2');
  CheckTrue(Pos('table.batchf32.arrayaddscalar := @neonarrayaddscalarf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayAddScalarF32 for Batch B2');
  CheckTrue(Pos('table.batchf32.arrayclamp := @neonarrayclampf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayClampF32 for Batch B3');
  CheckTrue(Pos('table.batchf32.arraylerp := @neonarraylerpf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayLerpF32 for Batch B3');
  CheckTrue(Pos('table.batchf32.arrayfma := @neonarrayfmaf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayFmaF32 for Batch B4');
  CheckTrue(Pos('table.batchf32.arrayaxpy := @neonarrayaxpyf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayAxpyF32 for Batch B4');
  CheckTrue(Pos('table.batchf32.arraysqrt := @neonarraysqrtf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArraySqrtF32 for Batch B5');
  CheckTrue(Pos('table.batchf32.reducesum := @neonreducesumf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONReduceSumF32 for Batch B5');
  CheckTrue(Pos('table.batchf32.reducemin := @neonreduceminf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONReduceMinF32 for Batch B6');
  CheckTrue(Pos('table.batchf32.reducemax := @neonreducemaxf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONReduceMaxF32 for Batch B6');
  CheckTrue(Pos('table.batchf32.arrayrcp := @neonarrayrcpf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayRcpF32 for Batch B7');
  CheckTrue(Pos('table.batchf32.reducedot := @neonreducedotf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONReduceDotF32 for Batch B7');
  CheckTrue(Pos('table.batchf32.arrayrsqrt := @neonarrayrsqrtf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayRsqrtF32 for Batch B8');
  CheckTrue(Pos('table.batchf32.arrayrcprefine := @neonarrayrcprefinef32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayRcpRefineF32 for Batch B8');
  CheckTrue(Pos('table.batchf32.arrayrsqrtrefine := @neonarrayrsqrtrefinef32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayRsqrtRefineF32 for Batch B9');
  CheckTrue(Pos('table.batchf32.arraylinear := @neonarraylinearf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayLinearF32 for Wave C1');
  CheckTrue(Pos('table.batchf32.arrayceil := @neonarrayceilf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayCeilF32 for Wave C2');
  CheckTrue(Pos('table.batchf32.arrayfloor := @neonarrayfloorf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayFloorF32 for Wave C2');
  CheckTrue(Pos('table.batchf32.arraytrunc := @neonarraytruncf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayTruncF32 for Wave C2');
  CheckTrue(Pos('table.batchf32.arrayrelu := @neonarrayreluf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayReLUF32 for Wave C3');
  CheckTrue(Pos('table.batchf32.arrayabsdiff := @neonarrayabsdifff32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayAbsDiffF32 for Wave C3');
  CheckTrue(Pos('table.batchf64.arrayadd := @neonarrayaddf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayAddF64 for Wave C4a');
  CheckTrue(Pos('table.batchf64.arraysub := @neonarraysubf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArraySubF64 for Wave C4a');
  CheckTrue(Pos('table.batchf64.arraymul := @neonarraymulf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayMulF64 for Wave C4a');
  CheckTrue(Pos('table.batchf64.arraydiv := @neonarraydivf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayDivF64 for Wave C4a');
  CheckTrue(Pos('table.batchf64.arraymin := @neonarrayminf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayMinF64 for Wave C4a');
  CheckTrue(Pos('table.batchf64.arraymax := @neonarraymaxf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayMaxF64 for Wave C4a');
  CheckTrue(Pos('table.batchf64.arrayabs := @neonarrayabsf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayAbsF64 for Wave C4a');
  CheckTrue(Pos('table.batchf64.arrayneg := @neonarraynegf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayNegF64 for Wave C4a');
  CheckTrue(Pos('table.batchf64.arraysqrt := @neonarraysqrtf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArraySqrtF64 for Wave C4b');
  CheckTrue(Pos('table.batchf64.arraymulscalar := @neonarraymulscalarf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayMulScalarF64 for Wave C4b');
  CheckTrue(Pos('table.batchf64.arrayaddscalar := @neonarrayaddscalarf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayAddScalarF64 for Wave C4b');
  CheckTrue(Pos('table.batchf64.reducesum := @neonreducesumf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONReduceSumF64 for Wave C4b');
  CheckTrue(Pos('table.batchf64.reducedot := @neonreducedotf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONReduceDotF64 for Wave C4b');
  CheckTrue(Pos('table.batchf64.reducemin := @neonreduceminf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONReduceMinF64 for Wave C4b');
  CheckTrue(Pos('table.batchf64.reducemax := @neonreducemaxf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONReduceMaxF64 for Wave C4b');
  CheckTrue(Pos('table.batchf64.arraylinear := @neonarraylinearf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayLinearF64 for Wave C4c');
  CheckTrue(Pos('table.batchf64.arrayclamp := @neonarrayclampf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayClampF64 for Wave C4c');
  CheckTrue(Pos('table.batchf64.arraylerp := @neonarraylerpf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayLerpF64 for Wave C4c');
  CheckTrue(Pos('table.batchf64.arrayfma := @neonarrayfmaf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayFmaF64 for Wave C4c');
  CheckTrue(Pos('table.batchf64.arrayaxpy := @neonarrayaxpyf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayAxpyF64 for Wave C4c');
  CheckTrue(Pos('table.batchf64.arrayceil := @neonarrayceilf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayCeilF64 for Wave C4d');
  CheckTrue(Pos('table.batchf64.arrayfloor := @neonarrayfloorf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayFloorF64 for Wave C4d');
  CheckTrue(Pos('table.batchf64.arraytrunc := @neonarraytruncf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayTruncF64 for Wave C4d');
  CheckTrue(Pos('table.batchf64.arrayrelu := @neonarrayreluf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayReLUF64 for Wave C4d');
  CheckTrue(Pos('table.batchf64.arrayabsdiff := @neonarrayabsdifff64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayAbsDiffF64 for Wave C4d');
  CheckTrue(Pos('table.batchf64.arrayrcp := @neonarrayrcpf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayRcpF64 for Wave C4e');
  CheckTrue(Pos('table.batchf64.arrayrsqrt := @neonarrayrsqrtf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayRsqrtF64 for Wave C4e');
  CheckTrue(Pos('table.batchf64.arrayrcprefine := @neonarrayrcprefinef64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayRcpRefineF64 for Wave C4e');
  CheckTrue(Pos('table.batchf64.arrayrsqrtrefine := @neonarrayrsqrtrefinef64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayRsqrtRefineF64 for Wave C4e');
  CheckTrue(Pos('table.batchf32.arraysin := @neonarraysinf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArraySinF32 for Wave C5');
  CheckTrue(Pos('table.batchf32.arrayexp := @neonarrayexpf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayExpF32 for Wave C5');
  CheckTrue(Pos('table.batchf32.arraycos := @neonarraycosf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayCosF32 for Wave C5b');
  CheckTrue(Pos('table.batchf32.arraysincos := @neonarraysincosf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArraySinCosF32 for Wave C5b');
  CheckTrue(Pos('table.batchf32.arraylog := @neonarraylogf32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayLogF32 for Wave C5c');
  CheckTrue(Pos('table.batchf32.arraylog2 := @neonarraylog2f32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayLog2F32 for Wave C5c');
  CheckTrue(Pos('table.batchf32.arraylog10 := @neonarraylog10f32;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayLog10F32 for Wave C5c');
  CheckTrue(Pos('table.batchf64.arraysin := @neonarraysinf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArraySinF64 for Wave C5d');
  CheckTrue(Pos('table.batchf64.arrayexp := @neonarrayexpf64;', LRegisterSource) > 0, 'RegisterNEONBackend should wire NEONArrayExpF64 for Wave C5d');
  CheckTrue(Pos('table.memory.sumbytes := @sumbytes_neon;', LRegisterSource) > 0, 'RegisterNEONBackend should still wire SumBytes_NEON explicitly so asm builds keep the native facade slot');
  CheckTrue(Pos('table.memory.minmaxbytes := @minmaxbytes_neon;', LRegisterSource) > 0, 'RegisterNEONBackend should still wire MinMaxBytes_NEON explicitly so asm builds keep the native facade slot');
  CheckTrue(Pos('table.memory.countbyte := @countbyte_neon;', LRegisterSource) > 0, 'RegisterNEONBackend should still wire CountByte_NEON explicitly so asm builds keep the native facade slot');
  CheckTrue(Pos('table.memory.asciiiequal := @asciiiequal_neon;', LRegisterSource) > 0, 'RegisterNEONBackend should still wire AsciiIEqual_NEON explicitly so asm builds keep the native facade slot');
  CheckTrue(Pos('table.memory.tolowerascii := @tolowerascii_neon;', LRegisterSource) > 0, 'RegisterNEONBackend should still wire ToLowerAscii_NEON explicitly so asm builds keep the native facade slot');
  CheckTrue(Pos('table.memory.toupperascii := @toupperascii_neon;', LRegisterSource) > 0, 'RegisterNEONBackend should still wire ToUpperAscii_NEON explicitly so asm builds keep the native facade slot');
  CheckTrue(Pos('table.memory.bitsetpopcount := @bitsetpopcount_neon;', LRegisterSource) > 0, 'RegisterNEONBackend should still wire BitsetPopCount_NEON explicitly so asm builds keep the native facade slot');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertRuntimeSlotExpectation('MemEqual', Pointer(LScalarTable.Memory.Equal), Pointer(LNEONTable.Memory.Equal));
  AssertRuntimeSlotExpectation('MemFindByte', Pointer(LScalarTable.Memory.FindByte), Pointer(LNEONTable.Memory.FindByte));
  AssertRuntimeSlotExpectation('MemDiffRange', Pointer(LScalarTable.Memory.DiffRange), Pointer(LNEONTable.Memory.DiffRange));
  AssertRuntimeSlotExpectation('MemCopy', Pointer(LScalarTable.Memory.Copy), Pointer(LNEONTable.Memory.Copy));
  AssertRuntimeSlotExpectation('MemSet', Pointer(LScalarTable.Memory.Fill), Pointer(LNEONTable.Memory.Fill));
  AssertRuntimeSlotExpectation('MemReverse', Pointer(LScalarTable.Memory.Reverse), Pointer(LNEONTable.Memory.Reverse));
  AssertRuntimeSlotExpectation('BytesIndexOf', Pointer(LScalarTable.Memory.BytesIndexOf), Pointer(LNEONTable.Memory.BytesIndexOf));
  AssertRuntimeSlotExpectation('Utf8Validate', Pointer(LScalarTable.Memory.Utf8Validate), Pointer(LNEONTable.Memory.Utf8Validate));
  AssertRuntimeSlotExpectation('BatchF32.ArrayAdd', Pointer(LScalarTable.BatchF32.ArrayAdd), Pointer(LNEONTable.BatchF32.ArrayAdd));
  AssertRuntimeSlotExpectation('BatchF32.ArraySub', Pointer(LScalarTable.BatchF32.ArraySub), Pointer(LNEONTable.BatchF32.ArraySub));
  AssertRuntimeSlotExpectation('BatchF32.ArrayMul', Pointer(LScalarTable.BatchF32.ArrayMul), Pointer(LNEONTable.BatchF32.ArrayMul));
  AssertRuntimeSlotExpectation('BatchF32.ArrayDiv', Pointer(LScalarTable.BatchF32.ArrayDiv), Pointer(LNEONTable.BatchF32.ArrayDiv));
  AssertRuntimeSlotExpectation('BatchF32.ArrayMin', Pointer(LScalarTable.BatchF32.ArrayMin), Pointer(LNEONTable.BatchF32.ArrayMin));
  AssertRuntimeSlotExpectation('BatchF32.ArrayMax', Pointer(LScalarTable.BatchF32.ArrayMax), Pointer(LNEONTable.BatchF32.ArrayMax));
  AssertRuntimeSlotExpectation('BatchF32.ArrayAbs', Pointer(LScalarTable.BatchF32.ArrayAbs), Pointer(LNEONTable.BatchF32.ArrayAbs));
  AssertRuntimeSlotExpectation('BatchF32.ArrayNeg', Pointer(LScalarTable.BatchF32.ArrayNeg), Pointer(LNEONTable.BatchF32.ArrayNeg));
  AssertRuntimeSlotExpectation('BatchF32.ArrayMulScalar', Pointer(LScalarTable.BatchF32.ArrayMulScalar), Pointer(LNEONTable.BatchF32.ArrayMulScalar));
  AssertRuntimeSlotExpectation('BatchF32.ArrayAddScalar', Pointer(LScalarTable.BatchF32.ArrayAddScalar), Pointer(LNEONTable.BatchF32.ArrayAddScalar));
  AssertRuntimeSlotExpectation('BatchF32.ArrayClamp', Pointer(LScalarTable.BatchF32.ArrayClamp), Pointer(LNEONTable.BatchF32.ArrayClamp));
  AssertRuntimeSlotExpectation('BatchF32.ArrayLerp', Pointer(LScalarTable.BatchF32.ArrayLerp), Pointer(LNEONTable.BatchF32.ArrayLerp));
  AssertRuntimeSlotExpectation('BatchF32.ArrayFma', Pointer(LScalarTable.BatchF32.ArrayFma), Pointer(LNEONTable.BatchF32.ArrayFma));
  AssertRuntimeSlotExpectation('BatchF32.ArrayAxpy', Pointer(LScalarTable.BatchF32.ArrayAxpy), Pointer(LNEONTable.BatchF32.ArrayAxpy));
  AssertRuntimeSlotExpectation('BatchF32.ArraySqrt', Pointer(LScalarTable.BatchF32.ArraySqrt), Pointer(LNEONTable.BatchF32.ArraySqrt));
  AssertRuntimeSlotExpectation('BatchF32.ReduceSum', Pointer(LScalarTable.BatchF32.ReduceSum), Pointer(LNEONTable.BatchF32.ReduceSum));
  AssertRuntimeSlotExpectation('BatchF32.ReduceMin', Pointer(LScalarTable.BatchF32.ReduceMin), Pointer(LNEONTable.BatchF32.ReduceMin));
  AssertRuntimeSlotExpectation('BatchF32.ReduceMax', Pointer(LScalarTable.BatchF32.ReduceMax), Pointer(LNEONTable.BatchF32.ReduceMax));
  AssertRuntimeSlotExpectation('BatchF32.ArrayRcp', Pointer(LScalarTable.BatchF32.ArrayRcp), Pointer(LNEONTable.BatchF32.ArrayRcp));
  AssertRuntimeSlotExpectation('BatchF32.ReduceDot', Pointer(LScalarTable.BatchF32.ReduceDot), Pointer(LNEONTable.BatchF32.ReduceDot));
  AssertRuntimeSlotExpectation('BatchF32.ArrayRsqrt', Pointer(LScalarTable.BatchF32.ArrayRsqrt), Pointer(LNEONTable.BatchF32.ArrayRsqrt));
  AssertRuntimeSlotExpectation('BatchF32.ArrayRcpRefine', Pointer(LScalarTable.BatchF32.ArrayRcpRefine), Pointer(LNEONTable.BatchF32.ArrayRcpRefine));
  AssertRuntimeSlotExpectation('BatchF32.ArrayRsqrtRefine', Pointer(LScalarTable.BatchF32.ArrayRsqrtRefine), Pointer(LNEONTable.BatchF32.ArrayRsqrtRefine));
  AssertRuntimeSlotExpectation('BatchF32.ArrayLinear', Pointer(LScalarTable.BatchF32.ArrayLinear), Pointer(LNEONTable.BatchF32.ArrayLinear));
  AssertRuntimeSlotExpectation('BatchF32.ArrayCeil', Pointer(LScalarTable.BatchF32.ArrayCeil), Pointer(LNEONTable.BatchF32.ArrayCeil));
  AssertRuntimeSlotExpectation('BatchF32.ArrayFloor', Pointer(LScalarTable.BatchF32.ArrayFloor), Pointer(LNEONTable.BatchF32.ArrayFloor));
  AssertRuntimeSlotExpectation('BatchF32.ArrayTrunc', Pointer(LScalarTable.BatchF32.ArrayTrunc), Pointer(LNEONTable.BatchF32.ArrayTrunc));
  AssertRuntimeSlotExpectation('BatchF32.ArrayReLU', Pointer(LScalarTable.BatchF32.ArrayReLU), Pointer(LNEONTable.BatchF32.ArrayReLU));
  AssertRuntimeSlotExpectation('BatchF32.ArrayAbsDiff', Pointer(LScalarTable.BatchF32.ArrayAbsDiff), Pointer(LNEONTable.BatchF32.ArrayAbsDiff));
  AssertRuntimeSlotExpectation('BatchF64.ArrayAdd', Pointer(LScalarTable.BatchF64.ArrayAdd), Pointer(LNEONTable.BatchF64.ArrayAdd));
  AssertRuntimeSlotExpectation('BatchF64.ArraySub', Pointer(LScalarTable.BatchF64.ArraySub), Pointer(LNEONTable.BatchF64.ArraySub));
  AssertRuntimeSlotExpectation('BatchF64.ArrayMul', Pointer(LScalarTable.BatchF64.ArrayMul), Pointer(LNEONTable.BatchF64.ArrayMul));
  AssertRuntimeSlotExpectation('BatchF64.ArrayDiv', Pointer(LScalarTable.BatchF64.ArrayDiv), Pointer(LNEONTable.BatchF64.ArrayDiv));
  AssertRuntimeSlotExpectation('BatchF64.ArrayMin', Pointer(LScalarTable.BatchF64.ArrayMin), Pointer(LNEONTable.BatchF64.ArrayMin));
  AssertRuntimeSlotExpectation('BatchF64.ArrayMax', Pointer(LScalarTable.BatchF64.ArrayMax), Pointer(LNEONTable.BatchF64.ArrayMax));
  AssertRuntimeSlotExpectation('BatchF64.ArrayAbs', Pointer(LScalarTable.BatchF64.ArrayAbs), Pointer(LNEONTable.BatchF64.ArrayAbs));
  AssertRuntimeSlotExpectation('BatchF64.ArrayNeg', Pointer(LScalarTable.BatchF64.ArrayNeg), Pointer(LNEONTable.BatchF64.ArrayNeg));
  AssertRuntimeSlotExpectation('BatchF64.ArraySqrt', Pointer(LScalarTable.BatchF64.ArraySqrt), Pointer(LNEONTable.BatchF64.ArraySqrt));
  AssertRuntimeSlotExpectation('BatchF64.ArrayMulScalar', Pointer(LScalarTable.BatchF64.ArrayMulScalar), Pointer(LNEONTable.BatchF64.ArrayMulScalar));
  AssertRuntimeSlotExpectation('BatchF64.ArrayAddScalar', Pointer(LScalarTable.BatchF64.ArrayAddScalar), Pointer(LNEONTable.BatchF64.ArrayAddScalar));
  AssertRuntimeSlotExpectation('BatchF64.ReduceSum', Pointer(LScalarTable.BatchF64.ReduceSum), Pointer(LNEONTable.BatchF64.ReduceSum));
  AssertRuntimeSlotExpectation('BatchF64.ReduceDot', Pointer(LScalarTable.BatchF64.ReduceDot), Pointer(LNEONTable.BatchF64.ReduceDot));
  AssertRuntimeSlotExpectation('BatchF64.ReduceMin', Pointer(LScalarTable.BatchF64.ReduceMin), Pointer(LNEONTable.BatchF64.ReduceMin));
  AssertRuntimeSlotExpectation('BatchF64.ReduceMax', Pointer(LScalarTable.BatchF64.ReduceMax), Pointer(LNEONTable.BatchF64.ReduceMax));
  AssertRuntimeSlotExpectation('BatchF64.ArrayLinear', Pointer(LScalarTable.BatchF64.ArrayLinear), Pointer(LNEONTable.BatchF64.ArrayLinear));
  AssertRuntimeSlotExpectation('BatchF64.ArrayClamp', Pointer(LScalarTable.BatchF64.ArrayClamp), Pointer(LNEONTable.BatchF64.ArrayClamp));
  AssertRuntimeSlotExpectation('BatchF64.ArrayLerp', Pointer(LScalarTable.BatchF64.ArrayLerp), Pointer(LNEONTable.BatchF64.ArrayLerp));
  AssertRuntimeSlotExpectation('BatchF64.ArrayFma', Pointer(LScalarTable.BatchF64.ArrayFma), Pointer(LNEONTable.BatchF64.ArrayFma));
  AssertRuntimeSlotExpectation('BatchF64.ArrayAxpy', Pointer(LScalarTable.BatchF64.ArrayAxpy), Pointer(LNEONTable.BatchF64.ArrayAxpy));
  AssertRuntimeSlotExpectation('BatchF64.ArrayCeil', Pointer(LScalarTable.BatchF64.ArrayCeil), Pointer(LNEONTable.BatchF64.ArrayCeil));
  AssertRuntimeSlotExpectation('BatchF64.ArrayFloor', Pointer(LScalarTable.BatchF64.ArrayFloor), Pointer(LNEONTable.BatchF64.ArrayFloor));
  AssertRuntimeSlotExpectation('BatchF64.ArrayTrunc', Pointer(LScalarTable.BatchF64.ArrayTrunc), Pointer(LNEONTable.BatchF64.ArrayTrunc));
  AssertRuntimeSlotExpectation('BatchF64.ArrayReLU', Pointer(LScalarTable.BatchF64.ArrayReLU), Pointer(LNEONTable.BatchF64.ArrayReLU));
  AssertRuntimeSlotExpectation('BatchF64.ArrayAbsDiff', Pointer(LScalarTable.BatchF64.ArrayAbsDiff), Pointer(LNEONTable.BatchF64.ArrayAbsDiff));
  AssertRuntimeSlotExpectation('BatchF64.ArrayRcp', Pointer(LScalarTable.BatchF64.ArrayRcp), Pointer(LNEONTable.BatchF64.ArrayRcp));
  AssertRuntimeSlotExpectation('BatchF64.ArrayRsqrt', Pointer(LScalarTable.BatchF64.ArrayRsqrt), Pointer(LNEONTable.BatchF64.ArrayRsqrt));
  AssertRuntimeSlotExpectation('BatchF64.ArrayRcpRefine', Pointer(LScalarTable.BatchF64.ArrayRcpRefine), Pointer(LNEONTable.BatchF64.ArrayRcpRefine));
  AssertRuntimeSlotExpectation('BatchF64.ArrayRsqrtRefine', Pointer(LScalarTable.BatchF64.ArrayRsqrtRefine), Pointer(LNEONTable.BatchF64.ArrayRsqrtRefine));
  AssertRuntimeSlotExpectation('BatchF32.ArraySin', Pointer(LScalarTable.BatchF32.ArraySin), Pointer(LNEONTable.BatchF32.ArraySin));
  AssertRuntimeSlotExpectation('BatchF32.ArrayExp', Pointer(LScalarTable.BatchF32.ArrayExp), Pointer(LNEONTable.BatchF32.ArrayExp));
  AssertRuntimeSlotExpectation('BatchF32.ArrayCos', Pointer(LScalarTable.BatchF32.ArrayCos), Pointer(LNEONTable.BatchF32.ArrayCos));
  AssertRuntimeSlotExpectation('BatchF32.ArraySinCos', Pointer(LScalarTable.BatchF32.ArraySinCos), Pointer(LNEONTable.BatchF32.ArraySinCos));
  AssertRuntimeSlotExpectation('BatchF32.ArrayLog', Pointer(LScalarTable.BatchF32.ArrayLog), Pointer(LNEONTable.BatchF32.ArrayLog));
  AssertRuntimeSlotExpectation('BatchF32.ArrayLog2', Pointer(LScalarTable.BatchF32.ArrayLog2), Pointer(LNEONTable.BatchF32.ArrayLog2));
  AssertRuntimeSlotExpectation('BatchF32.ArrayLog10', Pointer(LScalarTable.BatchF32.ArrayLog10), Pointer(LNEONTable.BatchF32.ArrayLog10));
  AssertRuntimeSlotExpectation('BatchF64.ArraySin', Pointer(LScalarTable.BatchF64.ArraySin), Pointer(LNEONTable.BatchF64.ArraySin));
  AssertRuntimeSlotExpectation('BatchF64.ArrayExp', Pointer(LScalarTable.BatchF64.ArrayExp), Pointer(LNEONTable.BatchF64.ArrayExp));
  AssertRuntimeSlotExpectation('SumBytes', Pointer(LScalarTable.Memory.SumBytes), Pointer(LNEONTable.Memory.SumBytes));
  AssertRuntimeSlotExpectation('MinMaxBytes', Pointer(LScalarTable.Memory.MinMaxBytes), Pointer(LNEONTable.Memory.MinMaxBytes));
  AssertRuntimeSlotExpectation('CountByte', Pointer(LScalarTable.Memory.CountByte), Pointer(LNEONTable.Memory.CountByte));
  AssertRuntimeSlotExpectation('AsciiIEqual', Pointer(LScalarTable.Memory.AsciiIEqual), Pointer(LNEONTable.Memory.AsciiIEqual));
  AssertRuntimeSlotExpectation('ToLowerAscii', Pointer(LScalarTable.Memory.ToLowerAscii), Pointer(LNEONTable.Memory.ToLowerAscii));
  AssertRuntimeSlotExpectation('ToUpperAscii', Pointer(LScalarTable.Memory.ToUpperAscii), Pointer(LNEONTable.Memory.ToUpperAscii));
  AssertRuntimeSlotExpectation('BitsetPopCount', Pointer(LScalarTable.Memory.BitsetPopCount), Pointer(LNEONTable.Memory.BitsetPopCount));
end;

procedure TTestCase_DispatchAPI.Test_NEON_WideFloatMemoryUtilitySlots_Bind_AsmHelpers_When_Available;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LAutowrapSourcePath: string;
  LRegisterSource: string;
  LAutowrapSource: string;

  procedure AssertSourceContains(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, aLabel + ' source should bind the wide-float slot to its NEON asm helper');
  end;

  procedure AssertSourceOmits(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0, aLabel + ' should not be rebound to the scalar-forwarder wrapper later in RegisterNEONBackend');
  end;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LAutowrapSource) = 0, aLabel + ' dead scalar-forwarder wrapper should be removed from the NEON autowrap include');
  end;

  procedure AssertRuntimeSlotExpectation(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
    CheckTrue(aBackendSlot <> aScalarSlot, 'NEON ' + aLabel + ' should stay native when wide-float asm helpers are compiled');
    {$ELSE}
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should stay scalar when wide-float asm helpers are not compiled');
    {$ENDIF}
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LAutowrapSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.autowrap.inc');
    CheckTrue(FileExists(LAutowrapSourcePath), 'NEON scalar autowrap source should exist for implementation-shape audit: ' + LAutowrapSourcePath);
    LSourceLines.LoadFromFile(LAutowrapSourcePath);
    LAutowrapSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertSourceContains('LoadF32x8', 'table.CoreVectors.LoadF32x8 := @NEONLoadF32x8_ASM;');
  AssertSourceContains('LoadF32x16', 'table.CoreVectors.LoadF32x16 := @NEONLoadF32x16_ASM;');
  AssertSourceContains('LoadF64x4', 'table.CoreVectors.LoadF64x4 := @NEONLoadF64x4_ASM;');
  AssertSourceContains('LoadF64x8', 'table.CoreVectors.LoadF64x8 := @NEONLoadF64x8_ASM;');
  AssertSourceContains('StoreF32x8', 'table.CoreVectors.StoreF32x8 := @NEONStoreF32x8_ASM;');
  AssertSourceContains('StoreF32x16', 'table.CoreVectors.StoreF32x16 := @NEONStoreF32x16_ASM;');
  AssertSourceContains('StoreF64x4', 'table.CoreVectors.StoreF64x4 := @NEONStoreF64x4_ASM;');
  AssertSourceContains('StoreF64x8', 'table.CoreVectors.StoreF64x8 := @NEONStoreF64x8_ASM;');
  AssertSourceContains('SplatF32x8', 'table.CoreVectors.SplatF32x8 := @NEONSplatF32x8_ASM;');
  AssertSourceContains('SplatF32x16', 'table.CoreVectors.SplatF32x16 := @NEONSplatF32x16_ASM;');
  AssertSourceContains('SplatF64x4', 'table.CoreVectors.SplatF64x4 := @NEONSplatF64x4_ASM;');
  AssertSourceContains('SplatF64x8', 'table.CoreVectors.SplatF64x8 := @NEONSplatF64x8_ASM;');
  AssertSourceContains('ZeroF32x8', 'table.CoreVectors.ZeroF32x8 := @NEONZeroF32x8_ASM;');
  AssertSourceContains('ZeroF32x16', 'table.CoreVectors.ZeroF32x16 := @NEONZeroF32x16_ASM;');
  AssertSourceContains('ZeroF64x4', 'table.CoreVectors.ZeroF64x4 := @NEONZeroF64x4_ASM;');
  AssertSourceContains('ZeroF64x8', 'table.CoreVectors.ZeroF64x8 := @NEONZeroF64x8_ASM;');

  AssertSourceOmits('LoadF32x8 wrapper rebinding', 'table.CoreVectors.LoadF32x8 := @NEONLoadF32x8;');
  AssertSourceOmits('LoadF32x16 wrapper rebinding', 'table.CoreVectors.LoadF32x16 := @NEONLoadF32x16;');
  AssertSourceOmits('LoadF64x4 wrapper rebinding', 'table.CoreVectors.LoadF64x4 := @NEONLoadF64x4;');
  AssertSourceOmits('LoadF64x8 wrapper rebinding', 'table.CoreVectors.LoadF64x8 := @NEONLoadF64x8;');
  AssertSourceOmits('StoreF32x8 wrapper rebinding', 'table.CoreVectors.StoreF32x8 := @NEONStoreF32x8;');
  AssertSourceOmits('StoreF32x16 wrapper rebinding', 'table.CoreVectors.StoreF32x16 := @NEONStoreF32x16;');
  AssertSourceOmits('StoreF64x4 wrapper rebinding', 'table.CoreVectors.StoreF64x4 := @NEONStoreF64x4;');
  AssertSourceOmits('StoreF64x8 wrapper rebinding', 'table.CoreVectors.StoreF64x8 := @NEONStoreF64x8;');
  AssertSourceOmits('SplatF32x8 wrapper rebinding', 'table.CoreVectors.SplatF32x8 := @NEONSplatF32x8;');
  AssertSourceOmits('SplatF32x16 wrapper rebinding', 'table.CoreVectors.SplatF32x16 := @NEONSplatF32x16;');
  AssertSourceOmits('SplatF64x4 wrapper rebinding', 'table.CoreVectors.SplatF64x4 := @NEONSplatF64x4;');
  AssertSourceOmits('SplatF64x8 wrapper rebinding', 'table.CoreVectors.SplatF64x8 := @NEONSplatF64x8;');
  AssertSourceOmits('ZeroF32x8 wrapper rebinding', 'table.CoreVectors.ZeroF32x8 := @NEONZeroF32x8;');
  AssertSourceOmits('ZeroF32x16 wrapper rebinding', 'table.CoreVectors.ZeroF32x16 := @NEONZeroF32x16;');
  AssertSourceOmits('ZeroF64x4 wrapper rebinding', 'table.CoreVectors.ZeroF64x4 := @NEONZeroF64x4;');
  AssertSourceOmits('ZeroF64x8 wrapper rebinding', 'table.CoreVectors.ZeroF64x8 := @NEONZeroF64x8;');

  AssertDeadWrapperRemoved('NEONLoadF32x8', 'function NEONLoadF32x8(');
  AssertDeadWrapperRemoved('NEONLoadF32x16', 'function NEONLoadF32x16(');
  AssertDeadWrapperRemoved('NEONLoadF64x4', 'function NEONLoadF64x4(');
  AssertDeadWrapperRemoved('NEONLoadF64x8', 'function NEONLoadF64x8(');
  AssertDeadWrapperRemoved('NEONStoreF32x8', 'procedure NEONStoreF32x8(');
  AssertDeadWrapperRemoved('NEONStoreF32x16', 'procedure NEONStoreF32x16(');
  AssertDeadWrapperRemoved('NEONStoreF64x4', 'procedure NEONStoreF64x4(');
  AssertDeadWrapperRemoved('NEONStoreF64x8', 'procedure NEONStoreF64x8(');
  AssertDeadWrapperRemoved('NEONSplatF32x8', 'function NEONSplatF32x8(');
  AssertDeadWrapperRemoved('NEONSplatF32x16', 'function NEONSplatF32x16(');
  AssertDeadWrapperRemoved('NEONSplatF64x4', 'function NEONSplatF64x4(');
  AssertDeadWrapperRemoved('NEONSplatF64x8', 'function NEONSplatF64x8(');
  AssertDeadWrapperRemoved('NEONZeroF32x8', 'function NEONZeroF32x8');
  AssertDeadWrapperRemoved('NEONZeroF32x16', 'function NEONZeroF32x16');
  AssertDeadWrapperRemoved('NEONZeroF64x4', 'function NEONZeroF64x4');
  AssertDeadWrapperRemoved('NEONZeroF64x8', 'function NEONZeroF64x8');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertRuntimeSlotExpectation('LoadF32x8', Pointer(LScalarTable.CoreVectors.LoadF32x8), Pointer(LNEONTable.CoreVectors.LoadF32x8));
  AssertRuntimeSlotExpectation('LoadF32x16', Pointer(LScalarTable.CoreVectors.LoadF32x16), Pointer(LNEONTable.CoreVectors.LoadF32x16));
  AssertRuntimeSlotExpectation('LoadF64x4', Pointer(LScalarTable.CoreVectors.LoadF64x4), Pointer(LNEONTable.CoreVectors.LoadF64x4));
  AssertRuntimeSlotExpectation('LoadF64x8', Pointer(LScalarTable.CoreVectors.LoadF64x8), Pointer(LNEONTable.CoreVectors.LoadF64x8));
  AssertRuntimeSlotExpectation('StoreF32x8', Pointer(LScalarTable.CoreVectors.StoreF32x8), Pointer(LNEONTable.CoreVectors.StoreF32x8));
  AssertRuntimeSlotExpectation('StoreF32x16', Pointer(LScalarTable.CoreVectors.StoreF32x16), Pointer(LNEONTable.CoreVectors.StoreF32x16));
  AssertRuntimeSlotExpectation('StoreF64x4', Pointer(LScalarTable.CoreVectors.StoreF64x4), Pointer(LNEONTable.CoreVectors.StoreF64x4));
  AssertRuntimeSlotExpectation('StoreF64x8', Pointer(LScalarTable.CoreVectors.StoreF64x8), Pointer(LNEONTable.CoreVectors.StoreF64x8));
  AssertRuntimeSlotExpectation('SplatF32x8', Pointer(LScalarTable.CoreVectors.SplatF32x8), Pointer(LNEONTable.CoreVectors.SplatF32x8));
  AssertRuntimeSlotExpectation('SplatF32x16', Pointer(LScalarTable.CoreVectors.SplatF32x16), Pointer(LNEONTable.CoreVectors.SplatF32x16));
  AssertRuntimeSlotExpectation('SplatF64x4', Pointer(LScalarTable.CoreVectors.SplatF64x4), Pointer(LNEONTable.CoreVectors.SplatF64x4));
  AssertRuntimeSlotExpectation('SplatF64x8', Pointer(LScalarTable.CoreVectors.SplatF64x8), Pointer(LNEONTable.CoreVectors.SplatF64x8));
  AssertRuntimeSlotExpectation('ZeroF32x8', Pointer(LScalarTable.CoreVectors.ZeroF32x8), Pointer(LNEONTable.CoreVectors.ZeroF32x8));
  AssertRuntimeSlotExpectation('ZeroF32x16', Pointer(LScalarTable.CoreVectors.ZeroF32x16), Pointer(LNEONTable.CoreVectors.ZeroF32x16));
  AssertRuntimeSlotExpectation('ZeroF64x4', Pointer(LScalarTable.CoreVectors.ZeroF64x4), Pointer(LNEONTable.CoreVectors.ZeroF64x4));
  AssertRuntimeSlotExpectation('ZeroF64x8', Pointer(LScalarTable.CoreVectors.ZeroF64x8), Pointer(LNEONTable.CoreVectors.ZeroF64x8));
end;

procedure TTestCase_DispatchAPI.Test_NEON_DotFallbackSlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LDotSourcePath: string;
  LRegisterSource: string;
  LDotSource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LDotSource) = 0, aLabel + ' dead wrapper should be removed from the NEON dot include');
  end;

  procedure AssertRegisterKeepsBaseScalar(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0, 'RegisterNEONBackend should keep base scalar ' + aLabel + ' when the NEON dot wrapper is only a scalar forwarder');
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the NEON dot wrapper is only a scalar forwarder');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LDotSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.dot.inc');
    CheckTrue(FileExists(LDotSourcePath), 'NEON dot source should exist for implementation-shape audit: ' + LDotSourcePath);
    LSourceLines.LoadFromFile(LDotSourcePath);
    LDotSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('NEONDotF32x8', 'function NEONDotF32x8(');
  AssertDeadWrapperRemoved('NEONDotF64x2', 'function NEONDotF64x2(');
  AssertDeadWrapperRemoved('NEONDotF64x4', 'function NEONDotF64x4(');

  AssertRegisterKeepsBaseScalar('DotF32x8', 'table.CoreVectors.DotF32x8 := @NEONDotF32x8;');
  AssertRegisterKeepsBaseScalar('DotF64x2', 'table.CoreVectors.DotF64x2 := @NEONDotF64x2;');
  AssertRegisterKeepsBaseScalar('DotF64x4', 'table.CoreVectors.DotF64x4 := @NEONDotF64x4;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('DotF32x8', Pointer(LScalarTable.CoreVectors.DotF32x8), Pointer(LNEONTable.CoreVectors.DotF32x8));
  AssertSlotReusesScalar('DotF64x2', Pointer(LScalarTable.CoreVectors.DotF64x2), Pointer(LNEONTable.CoreVectors.DotF64x2));
  AssertSlotReusesScalar('DotF64x4', Pointer(LScalarTable.CoreVectors.DotF64x4), Pointer(LNEONTable.CoreVectors.DotF64x4));
end;

procedure TTestCase_DispatchAPI.Test_NEON_WideFallbackOnlySlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LAutowrapSourcePath: string;
  LRegisterSource: string;
  LAutowrapSource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LAutowrapSource) = 0, aLabel + ' dead wrapper should be removed from the NEON scalar autowrap include');
  end;

  procedure AssertRegisterKeepsBaseScalar(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0, 'RegisterNEONBackend should keep base scalar ' + aLabel + ' when the NEON wrapper is only a scalar forwarder');
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the NEON wrapper is only a scalar forwarder');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LAutowrapSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.autowrap.inc');
    CheckTrue(FileExists(LAutowrapSourcePath), 'NEON scalar autowrap source should exist for implementation-shape audit: ' + LAutowrapSourcePath);
    LSourceLines.LoadFromFile(LAutowrapSourcePath);
    LAutowrapSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('NEONAddI16x32', 'function NEONAddI16x32(');
  AssertDeadWrapperRemoved('NEONSubI16x32', 'function NEONSubI16x32(');
  AssertDeadWrapperRemoved('NEONAndI16x32', 'function NEONAndI16x32(');
  AssertDeadWrapperRemoved('NEONOrI16x32', 'function NEONOrI16x32(');
  AssertDeadWrapperRemoved('NEONXorI16x32', 'function NEONXorI16x32(');
  AssertDeadWrapperRemoved('NEONNotI16x32', 'function NEONNotI16x32(');
  AssertDeadWrapperRemoved('NEONAndNotI16x32', 'function NEONAndNotI16x32(');
  AssertDeadWrapperRemoved('NEONCmpEqI16x32', 'function NEONCmpEqI16x32(');
  AssertDeadWrapperRemoved('NEONCmpLtI16x32', 'function NEONCmpLtI16x32(');
  AssertDeadWrapperRemoved('NEONCmpGtI16x32', 'function NEONCmpGtI16x32(');
  AssertDeadWrapperRemoved('NEONMinI16x32', 'function NEONMinI16x32(');
  AssertDeadWrapperRemoved('NEONMaxI16x32', 'function NEONMaxI16x32(');
  AssertDeadWrapperRemoved('NEONShiftLeftI16x32', 'function NEONShiftLeftI16x32(');
  AssertDeadWrapperRemoved('NEONShiftRightI16x32', 'function NEONShiftRightI16x32(');
  AssertDeadWrapperRemoved('NEONShiftRightArithI16x32', 'function NEONShiftRightArithI16x32(');
  AssertDeadWrapperRemoved('NEONAddI8x64', 'function NEONAddI8x64(');
  AssertDeadWrapperRemoved('NEONSubI8x64', 'function NEONSubI8x64(');
  AssertDeadWrapperRemoved('NEONAndI8x64', 'function NEONAndI8x64(');
  AssertDeadWrapperRemoved('NEONOrI8x64', 'function NEONOrI8x64(');
  AssertDeadWrapperRemoved('NEONXorI8x64', 'function NEONXorI8x64(');
  AssertDeadWrapperRemoved('NEONNotI8x64', 'function NEONNotI8x64(');
  AssertDeadWrapperRemoved('NEONAndNotI8x64', 'function NEONAndNotI8x64(');
  AssertDeadWrapperRemoved('NEONCmpEqI8x64', 'function NEONCmpEqI8x64(');
  AssertDeadWrapperRemoved('NEONCmpLtI8x64', 'function NEONCmpLtI8x64(');
  AssertDeadWrapperRemoved('NEONCmpGtI8x64', 'function NEONCmpGtI8x64(');
  AssertDeadWrapperRemoved('NEONMinI8x64', 'function NEONMinI8x64(');
  AssertDeadWrapperRemoved('NEONMaxI8x64', 'function NEONMaxI8x64(');
  AssertDeadWrapperRemoved('NEONAddU8x64', 'function NEONAddU8x64(');
  AssertDeadWrapperRemoved('NEONSubU8x64', 'function NEONSubU8x64(');
  AssertDeadWrapperRemoved('NEONAndU8x64', 'function NEONAndU8x64(');
  AssertDeadWrapperRemoved('NEONOrU8x64', 'function NEONOrU8x64(');
  AssertDeadWrapperRemoved('NEONXorU8x64', 'function NEONXorU8x64(');
  AssertDeadWrapperRemoved('NEONNotU8x64', 'function NEONNotU8x64(');
  AssertDeadWrapperRemoved('NEONCmpEqU8x64', 'function NEONCmpEqU8x64(');
  AssertDeadWrapperRemoved('NEONCmpLtU8x64', 'function NEONCmpLtU8x64(');
  AssertDeadWrapperRemoved('NEONCmpGtU8x64', 'function NEONCmpGtU8x64(');
  AssertDeadWrapperRemoved('NEONMinU8x64', 'function NEONMinU8x64(');
  AssertDeadWrapperRemoved('NEONMaxU8x64', 'function NEONMaxU8x64(');
  AssertDeadWrapperRemoved('NEONAddU32x16', 'function NEONAddU32x16(');
  AssertDeadWrapperRemoved('NEONSubU32x16', 'function NEONSubU32x16(');
  AssertDeadWrapperRemoved('NEONMulU32x16', 'function NEONMulU32x16(');
  AssertDeadWrapperRemoved('NEONAndU32x16', 'function NEONAndU32x16(');
  AssertDeadWrapperRemoved('NEONOrU32x16', 'function NEONOrU32x16(');
  AssertDeadWrapperRemoved('NEONXorU32x16', 'function NEONXorU32x16(');
  AssertDeadWrapperRemoved('NEONNotU32x16', 'function NEONNotU32x16(');
  AssertDeadWrapperRemoved('NEONAndNotU32x16', 'function NEONAndNotU32x16(');
  AssertDeadWrapperRemoved('NEONShiftLeftU32x16', 'function NEONShiftLeftU32x16(');
  AssertDeadWrapperRemoved('NEONShiftRightU32x16', 'function NEONShiftRightU32x16(');
  AssertDeadWrapperRemoved('NEONCmpEqU32x16', 'function NEONCmpEqU32x16(');
  AssertDeadWrapperRemoved('NEONCmpLtU32x16', 'function NEONCmpLtU32x16(');
  AssertDeadWrapperRemoved('NEONCmpGtU32x16', 'function NEONCmpGtU32x16(');
  AssertDeadWrapperRemoved('NEONCmpLeU32x16', 'function NEONCmpLeU32x16(');
  AssertDeadWrapperRemoved('NEONCmpGeU32x16', 'function NEONCmpGeU32x16(');
  AssertDeadWrapperRemoved('NEONCmpNeU32x16', 'function NEONCmpNeU32x16(');
  AssertDeadWrapperRemoved('NEONMinU32x16', 'function NEONMinU32x16(');
  AssertDeadWrapperRemoved('NEONMaxU32x16', 'function NEONMaxU32x16(');
  AssertDeadWrapperRemoved('NEONAddU64x8', 'function NEONAddU64x8(');
  AssertDeadWrapperRemoved('NEONSubU64x8', 'function NEONSubU64x8(');
  AssertDeadWrapperRemoved('NEONAndU64x8', 'function NEONAndU64x8(');
  AssertDeadWrapperRemoved('NEONOrU64x8', 'function NEONOrU64x8(');
  AssertDeadWrapperRemoved('NEONXorU64x8', 'function NEONXorU64x8(');
  AssertDeadWrapperRemoved('NEONNotU64x8', 'function NEONNotU64x8(');
  AssertDeadWrapperRemoved('NEONShiftLeftU64x8', 'function NEONShiftLeftU64x8(');
  AssertDeadWrapperRemoved('NEONShiftRightU64x8', 'function NEONShiftRightU64x8(');
  AssertDeadWrapperRemoved('NEONCmpEqU64x8', 'function NEONCmpEqU64x8(');
  AssertDeadWrapperRemoved('NEONCmpLtU64x8', 'function NEONCmpLtU64x8(');
  AssertDeadWrapperRemoved('NEONCmpGtU64x8', 'function NEONCmpGtU64x8(');
  AssertDeadWrapperRemoved('NEONCmpLeU64x8', 'function NEONCmpLeU64x8(');
  AssertDeadWrapperRemoved('NEONCmpGeU64x8', 'function NEONCmpGeU64x8(');
  AssertDeadWrapperRemoved('NEONCmpNeU64x8', 'function NEONCmpNeU64x8(');

  AssertRegisterKeepsBaseScalar('AddI16x32', 'table.CoreVectors.AddI16x32 := @NEONAddI16x32;');
  AssertRegisterKeepsBaseScalar('SubI16x32', 'table.CoreVectors.SubI16x32 := @NEONSubI16x32;');
  AssertRegisterKeepsBaseScalar('AndI16x32', 'table.CoreVectors.AndI16x32 := @NEONAndI16x32;');
  AssertRegisterKeepsBaseScalar('OrI16x32', 'table.CoreVectors.OrI16x32 := @NEONOrI16x32;');
  AssertRegisterKeepsBaseScalar('XorI16x32', 'table.CoreVectors.XorI16x32 := @NEONXorI16x32;');
  AssertRegisterKeepsBaseScalar('NotI16x32', 'table.CoreVectors.NotI16x32 := @NEONNotI16x32;');
  AssertRegisterKeepsBaseScalar('AndNotI16x32', 'table.CoreVectors.AndNotI16x32 := @NEONAndNotI16x32;');
  AssertRegisterKeepsBaseScalar('CmpEqI16x32', 'table.CoreVectors.CmpEqI16x32 := @NEONCmpEqI16x32;');
  AssertRegisterKeepsBaseScalar('CmpLtI16x32', 'table.CoreVectors.CmpLtI16x32 := @NEONCmpLtI16x32;');
  AssertRegisterKeepsBaseScalar('CmpGtI16x32', 'table.CoreVectors.CmpGtI16x32 := @NEONCmpGtI16x32;');
  AssertRegisterKeepsBaseScalar('MinI16x32', 'table.CoreVectors.MinI16x32 := @NEONMinI16x32;');
  AssertRegisterKeepsBaseScalar('MaxI16x32', 'table.CoreVectors.MaxI16x32 := @NEONMaxI16x32;');
  AssertRegisterKeepsBaseScalar('ShiftLeftI16x32', 'table.CoreVectors.ShiftLeftI16x32 := @NEONShiftLeftI16x32;');
  AssertRegisterKeepsBaseScalar('ShiftRightI16x32', 'table.CoreVectors.ShiftRightI16x32 := @NEONShiftRightI16x32;');
  AssertRegisterKeepsBaseScalar('ShiftRightArithI16x32', 'table.CoreVectors.ShiftRightArithI16x32 := @NEONShiftRightArithI16x32;');
  AssertRegisterKeepsBaseScalar('AddI8x64', 'table.CoreVectors.AddI8x64 := @NEONAddI8x64;');
  AssertRegisterKeepsBaseScalar('SubI8x64', 'table.CoreVectors.SubI8x64 := @NEONSubI8x64;');
  AssertRegisterKeepsBaseScalar('AndI8x64', 'table.CoreVectors.AndI8x64 := @NEONAndI8x64;');
  AssertRegisterKeepsBaseScalar('OrI8x64', 'table.CoreVectors.OrI8x64 := @NEONOrI8x64;');
  AssertRegisterKeepsBaseScalar('XorI8x64', 'table.CoreVectors.XorI8x64 := @NEONXorI8x64;');
  AssertRegisterKeepsBaseScalar('NotI8x64', 'table.CoreVectors.NotI8x64 := @NEONNotI8x64;');
  AssertRegisterKeepsBaseScalar('AndNotI8x64', 'table.CoreVectors.AndNotI8x64 := @NEONAndNotI8x64;');
  AssertRegisterKeepsBaseScalar('CmpEqI8x64', 'table.CoreVectors.CmpEqI8x64 := @NEONCmpEqI8x64;');
  AssertRegisterKeepsBaseScalar('CmpLtI8x64', 'table.CoreVectors.CmpLtI8x64 := @NEONCmpLtI8x64;');
  AssertRegisterKeepsBaseScalar('CmpGtI8x64', 'table.CoreVectors.CmpGtI8x64 := @NEONCmpGtI8x64;');
  AssertRegisterKeepsBaseScalar('MinI8x64', 'table.CoreVectors.MinI8x64 := @NEONMinI8x64;');
  AssertRegisterKeepsBaseScalar('MaxI8x64', 'table.CoreVectors.MaxI8x64 := @NEONMaxI8x64;');
  AssertRegisterKeepsBaseScalar('AddU8x64', 'table.CoreVectors.AddU8x64 := @NEONAddU8x64;');
  AssertRegisterKeepsBaseScalar('SubU8x64', 'table.CoreVectors.SubU8x64 := @NEONSubU8x64;');
  AssertRegisterKeepsBaseScalar('AndU8x64', 'table.CoreVectors.AndU8x64 := @NEONAndU8x64;');
  AssertRegisterKeepsBaseScalar('OrU8x64', 'table.CoreVectors.OrU8x64 := @NEONOrU8x64;');
  AssertRegisterKeepsBaseScalar('XorU8x64', 'table.CoreVectors.XorU8x64 := @NEONXorU8x64;');
  AssertRegisterKeepsBaseScalar('NotU8x64', 'table.CoreVectors.NotU8x64 := @NEONNotU8x64;');
  AssertRegisterKeepsBaseScalar('CmpEqU8x64', 'table.CoreVectors.CmpEqU8x64 := @NEONCmpEqU8x64;');
  AssertRegisterKeepsBaseScalar('CmpLtU8x64', 'table.CoreVectors.CmpLtU8x64 := @NEONCmpLtU8x64;');
  AssertRegisterKeepsBaseScalar('CmpGtU8x64', 'table.CoreVectors.CmpGtU8x64 := @NEONCmpGtU8x64;');
  AssertRegisterKeepsBaseScalar('MinU8x64', 'table.CoreVectors.MinU8x64 := @NEONMinU8x64;');
  AssertRegisterKeepsBaseScalar('MaxU8x64', 'table.CoreVectors.MaxU8x64 := @NEONMaxU8x64;');
  AssertRegisterKeepsBaseScalar('AddU32x16', 'table.CoreVectors.AddU32x16 := @NEONAddU32x16;');
  AssertRegisterKeepsBaseScalar('SubU32x16', 'table.CoreVectors.SubU32x16 := @NEONSubU32x16;');
  AssertRegisterKeepsBaseScalar('MulU32x16', 'table.CoreVectors.MulU32x16 := @NEONMulU32x16;');
  AssertRegisterKeepsBaseScalar('AndU32x16', 'table.CoreVectors.AndU32x16 := @NEONAndU32x16;');
  AssertRegisterKeepsBaseScalar('OrU32x16', 'table.CoreVectors.OrU32x16 := @NEONOrU32x16;');
  AssertRegisterKeepsBaseScalar('XorU32x16', 'table.CoreVectors.XorU32x16 := @NEONXorU32x16;');
  AssertRegisterKeepsBaseScalar('NotU32x16', 'table.CoreVectors.NotU32x16 := @NEONNotU32x16;');
  AssertRegisterKeepsBaseScalar('AndNotU32x16', 'table.CoreVectors.AndNotU32x16 := @NEONAndNotU32x16;');
  AssertRegisterKeepsBaseScalar('ShiftLeftU32x16', 'table.CoreVectors.ShiftLeftU32x16 := @NEONShiftLeftU32x16;');
  AssertRegisterKeepsBaseScalar('ShiftRightU32x16', 'table.CoreVectors.ShiftRightU32x16 := @NEONShiftRightU32x16;');
  AssertRegisterKeepsBaseScalar('CmpEqU32x16', 'table.CoreVectors.CmpEqU32x16 := @NEONCmpEqU32x16;');
  AssertRegisterKeepsBaseScalar('CmpLtU32x16', 'table.CoreVectors.CmpLtU32x16 := @NEONCmpLtU32x16;');
  AssertRegisterKeepsBaseScalar('CmpGtU32x16', 'table.CoreVectors.CmpGtU32x16 := @NEONCmpGtU32x16;');
  AssertRegisterKeepsBaseScalar('CmpLeU32x16', 'table.CoreVectors.CmpLeU32x16 := @NEONCmpLeU32x16;');
  AssertRegisterKeepsBaseScalar('CmpGeU32x16', 'table.CoreVectors.CmpGeU32x16 := @NEONCmpGeU32x16;');
  AssertRegisterKeepsBaseScalar('CmpNeU32x16', 'table.CoreVectors.CmpNeU32x16 := @NEONCmpNeU32x16;');
  AssertRegisterKeepsBaseScalar('MinU32x16', 'table.CoreVectors.MinU32x16 := @NEONMinU32x16;');
  AssertRegisterKeepsBaseScalar('MaxU32x16', 'table.CoreVectors.MaxU32x16 := @NEONMaxU32x16;');
  AssertRegisterKeepsBaseScalar('AddU64x8', 'table.CoreVectors.AddU64x8 := @NEONAddU64x8;');
  AssertRegisterKeepsBaseScalar('SubU64x8', 'table.CoreVectors.SubU64x8 := @NEONSubU64x8;');
  AssertRegisterKeepsBaseScalar('AndU64x8', 'table.CoreVectors.AndU64x8 := @NEONAndU64x8;');
  AssertRegisterKeepsBaseScalar('OrU64x8', 'table.CoreVectors.OrU64x8 := @NEONOrU64x8;');
  AssertRegisterKeepsBaseScalar('XorU64x8', 'table.CoreVectors.XorU64x8 := @NEONXorU64x8;');
  AssertRegisterKeepsBaseScalar('NotU64x8', 'table.CoreVectors.NotU64x8 := @NEONNotU64x8;');
  AssertRegisterKeepsBaseScalar('ShiftLeftU64x8', 'table.CoreVectors.ShiftLeftU64x8 := @NEONShiftLeftU64x8;');
  AssertRegisterKeepsBaseScalar('ShiftRightU64x8', 'table.CoreVectors.ShiftRightU64x8 := @NEONShiftRightU64x8;');
  AssertRegisterKeepsBaseScalar('CmpEqU64x8', 'table.CoreVectors.CmpEqU64x8 := @NEONCmpEqU64x8;');
  AssertRegisterKeepsBaseScalar('CmpLtU64x8', 'table.CoreVectors.CmpLtU64x8 := @NEONCmpLtU64x8;');
  AssertRegisterKeepsBaseScalar('CmpGtU64x8', 'table.CoreVectors.CmpGtU64x8 := @NEONCmpGtU64x8;');
  AssertRegisterKeepsBaseScalar('CmpLeU64x8', 'table.CoreVectors.CmpLeU64x8 := @NEONCmpLeU64x8;');
  AssertRegisterKeepsBaseScalar('CmpGeU64x8', 'table.CoreVectors.CmpGeU64x8 := @NEONCmpGeU64x8;');
  AssertRegisterKeepsBaseScalar('CmpNeU64x8', 'table.CoreVectors.CmpNeU64x8 := @NEONCmpNeU64x8;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('AddI16x32', Pointer(LScalarTable.CoreVectors.AddI16x32), Pointer(LNEONTable.CoreVectors.AddI16x32));
  AssertSlotReusesScalar('SubI16x32', Pointer(LScalarTable.CoreVectors.SubI16x32), Pointer(LNEONTable.CoreVectors.SubI16x32));
  AssertSlotReusesScalar('AndI16x32', Pointer(LScalarTable.CoreVectors.AndI16x32), Pointer(LNEONTable.CoreVectors.AndI16x32));
  AssertSlotReusesScalar('OrI16x32', Pointer(LScalarTable.CoreVectors.OrI16x32), Pointer(LNEONTable.CoreVectors.OrI16x32));
  AssertSlotReusesScalar('XorI16x32', Pointer(LScalarTable.CoreVectors.XorI16x32), Pointer(LNEONTable.CoreVectors.XorI16x32));
  AssertSlotReusesScalar('NotI16x32', Pointer(LScalarTable.CoreVectors.NotI16x32), Pointer(LNEONTable.CoreVectors.NotI16x32));
  AssertSlotReusesScalar('AndNotI16x32', Pointer(LScalarTable.CoreVectors.AndNotI16x32), Pointer(LNEONTable.CoreVectors.AndNotI16x32));
  AssertSlotReusesScalar('CmpEqI16x32', Pointer(LScalarTable.CoreVectors.CmpEqI16x32), Pointer(LNEONTable.CoreVectors.CmpEqI16x32));
  AssertSlotReusesScalar('CmpLtI16x32', Pointer(LScalarTable.CoreVectors.CmpLtI16x32), Pointer(LNEONTable.CoreVectors.CmpLtI16x32));
  AssertSlotReusesScalar('CmpGtI16x32', Pointer(LScalarTable.CoreVectors.CmpGtI16x32), Pointer(LNEONTable.CoreVectors.CmpGtI16x32));
  AssertSlotReusesScalar('MinI16x32', Pointer(LScalarTable.CoreVectors.MinI16x32), Pointer(LNEONTable.CoreVectors.MinI16x32));
  AssertSlotReusesScalar('MaxI16x32', Pointer(LScalarTable.CoreVectors.MaxI16x32), Pointer(LNEONTable.CoreVectors.MaxI16x32));
  AssertSlotReusesScalar('ShiftLeftI16x32', Pointer(LScalarTable.CoreVectors.ShiftLeftI16x32), Pointer(LNEONTable.CoreVectors.ShiftLeftI16x32));
  AssertSlotReusesScalar('ShiftRightI16x32', Pointer(LScalarTable.CoreVectors.ShiftRightI16x32), Pointer(LNEONTable.CoreVectors.ShiftRightI16x32));
  AssertSlotReusesScalar('ShiftRightArithI16x32', Pointer(LScalarTable.CoreVectors.ShiftRightArithI16x32), Pointer(LNEONTable.CoreVectors.ShiftRightArithI16x32));
  AssertSlotReusesScalar('AddI8x64', Pointer(LScalarTable.CoreVectors.AddI8x64), Pointer(LNEONTable.CoreVectors.AddI8x64));
  AssertSlotReusesScalar('SubI8x64', Pointer(LScalarTable.CoreVectors.SubI8x64), Pointer(LNEONTable.CoreVectors.SubI8x64));
  AssertSlotReusesScalar('AndI8x64', Pointer(LScalarTable.CoreVectors.AndI8x64), Pointer(LNEONTable.CoreVectors.AndI8x64));
  AssertSlotReusesScalar('OrI8x64', Pointer(LScalarTable.CoreVectors.OrI8x64), Pointer(LNEONTable.CoreVectors.OrI8x64));
  AssertSlotReusesScalar('XorI8x64', Pointer(LScalarTable.CoreVectors.XorI8x64), Pointer(LNEONTable.CoreVectors.XorI8x64));
  AssertSlotReusesScalar('NotI8x64', Pointer(LScalarTable.CoreVectors.NotI8x64), Pointer(LNEONTable.CoreVectors.NotI8x64));
  AssertSlotReusesScalar('AndNotI8x64', Pointer(LScalarTable.CoreVectors.AndNotI8x64), Pointer(LNEONTable.CoreVectors.AndNotI8x64));
  AssertSlotReusesScalar('CmpEqI8x64', Pointer(LScalarTable.CoreVectors.CmpEqI8x64), Pointer(LNEONTable.CoreVectors.CmpEqI8x64));
  AssertSlotReusesScalar('CmpLtI8x64', Pointer(LScalarTable.CoreVectors.CmpLtI8x64), Pointer(LNEONTable.CoreVectors.CmpLtI8x64));
  AssertSlotReusesScalar('CmpGtI8x64', Pointer(LScalarTable.CoreVectors.CmpGtI8x64), Pointer(LNEONTable.CoreVectors.CmpGtI8x64));
  AssertSlotReusesScalar('MinI8x64', Pointer(LScalarTable.CoreVectors.MinI8x64), Pointer(LNEONTable.CoreVectors.MinI8x64));
  AssertSlotReusesScalar('MaxI8x64', Pointer(LScalarTable.CoreVectors.MaxI8x64), Pointer(LNEONTable.CoreVectors.MaxI8x64));
  AssertSlotReusesScalar('AddU8x64', Pointer(LScalarTable.CoreVectors.AddU8x64), Pointer(LNEONTable.CoreVectors.AddU8x64));
  AssertSlotReusesScalar('SubU8x64', Pointer(LScalarTable.CoreVectors.SubU8x64), Pointer(LNEONTable.CoreVectors.SubU8x64));
  AssertSlotReusesScalar('AndU8x64', Pointer(LScalarTable.CoreVectors.AndU8x64), Pointer(LNEONTable.CoreVectors.AndU8x64));
  AssertSlotReusesScalar('OrU8x64', Pointer(LScalarTable.CoreVectors.OrU8x64), Pointer(LNEONTable.CoreVectors.OrU8x64));
  AssertSlotReusesScalar('XorU8x64', Pointer(LScalarTable.CoreVectors.XorU8x64), Pointer(LNEONTable.CoreVectors.XorU8x64));
  AssertSlotReusesScalar('NotU8x64', Pointer(LScalarTable.CoreVectors.NotU8x64), Pointer(LNEONTable.CoreVectors.NotU8x64));
  AssertSlotReusesScalar('CmpEqU8x64', Pointer(LScalarTable.CoreVectors.CmpEqU8x64), Pointer(LNEONTable.CoreVectors.CmpEqU8x64));
  AssertSlotReusesScalar('CmpLtU8x64', Pointer(LScalarTable.CoreVectors.CmpLtU8x64), Pointer(LNEONTable.CoreVectors.CmpLtU8x64));
  AssertSlotReusesScalar('CmpGtU8x64', Pointer(LScalarTable.CoreVectors.CmpGtU8x64), Pointer(LNEONTable.CoreVectors.CmpGtU8x64));
  AssertSlotReusesScalar('MinU8x64', Pointer(LScalarTable.CoreVectors.MinU8x64), Pointer(LNEONTable.CoreVectors.MinU8x64));
  AssertSlotReusesScalar('MaxU8x64', Pointer(LScalarTable.CoreVectors.MaxU8x64), Pointer(LNEONTable.CoreVectors.MaxU8x64));
  AssertSlotReusesScalar('AddU32x16', Pointer(LScalarTable.CoreVectors.AddU32x16), Pointer(LNEONTable.CoreVectors.AddU32x16));
  AssertSlotReusesScalar('SubU32x16', Pointer(LScalarTable.CoreVectors.SubU32x16), Pointer(LNEONTable.CoreVectors.SubU32x16));
  AssertSlotReusesScalar('MulU32x16', Pointer(LScalarTable.CoreVectors.MulU32x16), Pointer(LNEONTable.CoreVectors.MulU32x16));
  AssertSlotReusesScalar('AndU32x16', Pointer(LScalarTable.CoreVectors.AndU32x16), Pointer(LNEONTable.CoreVectors.AndU32x16));
  AssertSlotReusesScalar('OrU32x16', Pointer(LScalarTable.CoreVectors.OrU32x16), Pointer(LNEONTable.CoreVectors.OrU32x16));
  AssertSlotReusesScalar('XorU32x16', Pointer(LScalarTable.CoreVectors.XorU32x16), Pointer(LNEONTable.CoreVectors.XorU32x16));
  AssertSlotReusesScalar('NotU32x16', Pointer(LScalarTable.CoreVectors.NotU32x16), Pointer(LNEONTable.CoreVectors.NotU32x16));
  AssertSlotReusesScalar('AndNotU32x16', Pointer(LScalarTable.CoreVectors.AndNotU32x16), Pointer(LNEONTable.CoreVectors.AndNotU32x16));
  AssertSlotReusesScalar('ShiftLeftU32x16', Pointer(LScalarTable.CoreVectors.ShiftLeftU32x16), Pointer(LNEONTable.CoreVectors.ShiftLeftU32x16));
  AssertSlotReusesScalar('ShiftRightU32x16', Pointer(LScalarTable.CoreVectors.ShiftRightU32x16), Pointer(LNEONTable.CoreVectors.ShiftRightU32x16));
  AssertSlotReusesScalar('CmpEqU32x16', Pointer(LScalarTable.CoreVectors.CmpEqU32x16), Pointer(LNEONTable.CoreVectors.CmpEqU32x16));
  AssertSlotReusesScalar('CmpLtU32x16', Pointer(LScalarTable.CoreVectors.CmpLtU32x16), Pointer(LNEONTable.CoreVectors.CmpLtU32x16));
  AssertSlotReusesScalar('CmpGtU32x16', Pointer(LScalarTable.CoreVectors.CmpGtU32x16), Pointer(LNEONTable.CoreVectors.CmpGtU32x16));
  AssertSlotReusesScalar('CmpLeU32x16', Pointer(LScalarTable.CoreVectors.CmpLeU32x16), Pointer(LNEONTable.CoreVectors.CmpLeU32x16));
  AssertSlotReusesScalar('CmpGeU32x16', Pointer(LScalarTable.CoreVectors.CmpGeU32x16), Pointer(LNEONTable.CoreVectors.CmpGeU32x16));
  AssertSlotReusesScalar('CmpNeU32x16', Pointer(LScalarTable.CoreVectors.CmpNeU32x16), Pointer(LNEONTable.CoreVectors.CmpNeU32x16));
  AssertSlotReusesScalar('MinU32x16', Pointer(LScalarTable.CoreVectors.MinU32x16), Pointer(LNEONTable.CoreVectors.MinU32x16));
  AssertSlotReusesScalar('MaxU32x16', Pointer(LScalarTable.CoreVectors.MaxU32x16), Pointer(LNEONTable.CoreVectors.MaxU32x16));
  AssertSlotReusesScalar('AddU64x8', Pointer(LScalarTable.CoreVectors.AddU64x8), Pointer(LNEONTable.CoreVectors.AddU64x8));
  AssertSlotReusesScalar('SubU64x8', Pointer(LScalarTable.CoreVectors.SubU64x8), Pointer(LNEONTable.CoreVectors.SubU64x8));
  AssertSlotReusesScalar('AndU64x8', Pointer(LScalarTable.CoreVectors.AndU64x8), Pointer(LNEONTable.CoreVectors.AndU64x8));
  AssertSlotReusesScalar('OrU64x8', Pointer(LScalarTable.CoreVectors.OrU64x8), Pointer(LNEONTable.CoreVectors.OrU64x8));
  AssertSlotReusesScalar('XorU64x8', Pointer(LScalarTable.CoreVectors.XorU64x8), Pointer(LNEONTable.CoreVectors.XorU64x8));
  AssertSlotReusesScalar('NotU64x8', Pointer(LScalarTable.CoreVectors.NotU64x8), Pointer(LNEONTable.CoreVectors.NotU64x8));
  AssertSlotReusesScalar('ShiftLeftU64x8', Pointer(LScalarTable.CoreVectors.ShiftLeftU64x8), Pointer(LNEONTable.CoreVectors.ShiftLeftU64x8));
  AssertSlotReusesScalar('ShiftRightU64x8', Pointer(LScalarTable.CoreVectors.ShiftRightU64x8), Pointer(LNEONTable.CoreVectors.ShiftRightU64x8));
  AssertSlotReusesScalar('CmpEqU64x8', Pointer(LScalarTable.CoreVectors.CmpEqU64x8), Pointer(LNEONTable.CoreVectors.CmpEqU64x8));
  AssertSlotReusesScalar('CmpLtU64x8', Pointer(LScalarTable.CoreVectors.CmpLtU64x8), Pointer(LNEONTable.CoreVectors.CmpLtU64x8));
  AssertSlotReusesScalar('CmpGtU64x8', Pointer(LScalarTable.CoreVectors.CmpGtU64x8), Pointer(LNEONTable.CoreVectors.CmpGtU64x8));
  AssertSlotReusesScalar('CmpLeU64x8', Pointer(LScalarTable.CoreVectors.CmpLeU64x8), Pointer(LNEONTable.CoreVectors.CmpLeU64x8));
  AssertSlotReusesScalar('CmpGeU64x8', Pointer(LScalarTable.CoreVectors.CmpGeU64x8), Pointer(LNEONTable.CoreVectors.CmpGeU64x8));
  AssertSlotReusesScalar('CmpNeU64x8', Pointer(LScalarTable.CoreVectors.CmpNeU64x8), Pointer(LNEONTable.CoreVectors.CmpNeU64x8));
end;

procedure TTestCase_DispatchAPI.Test_NEON_NoAsmFloatCompareSlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LAutowrapSourcePath: string;
  LRegisterSource: string;
  LAutowrapSource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LAutowrapSource) = 0, aLabel + ' dead wrapper should be removed from the NEON scalar autowrap include');
  end;

  procedure AssertRegisterKeepsBaseScalar(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0, 'RegisterNEONBackend should keep base scalar ' + aLabel + ' when the no-asm NEON wrapper is only a scalar forwarder');
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the no-asm NEON wrapper is only a scalar forwarder');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LAutowrapSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.autowrap.inc');
    CheckTrue(FileExists(LAutowrapSourcePath), 'NEON scalar autowrap source should exist for implementation-shape audit: ' + LAutowrapSourcePath);
    LSourceLines.LoadFromFile(LAutowrapSourcePath);
    LAutowrapSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('NEONCmpEqF32x16', 'function NEONCmpEqF32x16(');
  AssertDeadWrapperRemoved('NEONCmpEqF32x8', 'function NEONCmpEqF32x8(');
  AssertDeadWrapperRemoved('NEONCmpEqF64x4', 'function NEONCmpEqF64x4(');
  AssertDeadWrapperRemoved('NEONCmpEqF64x8', 'function NEONCmpEqF64x8(');
  AssertDeadWrapperRemoved('NEONCmpGeF32x16', 'function NEONCmpGeF32x16(');
  AssertDeadWrapperRemoved('NEONCmpGeF32x8', 'function NEONCmpGeF32x8(');
  AssertDeadWrapperRemoved('NEONCmpGeF64x4', 'function NEONCmpGeF64x4(');
  AssertDeadWrapperRemoved('NEONCmpGeF64x8', 'function NEONCmpGeF64x8(');
  AssertDeadWrapperRemoved('NEONCmpGtF32x16', 'function NEONCmpGtF32x16(');
  AssertDeadWrapperRemoved('NEONCmpGtF32x8', 'function NEONCmpGtF32x8(');
  AssertDeadWrapperRemoved('NEONCmpGtF64x4', 'function NEONCmpGtF64x4(');
  AssertDeadWrapperRemoved('NEONCmpGtF64x8', 'function NEONCmpGtF64x8(');
  AssertDeadWrapperRemoved('NEONCmpLeF32x16', 'function NEONCmpLeF32x16(');
  AssertDeadWrapperRemoved('NEONCmpLeF32x8', 'function NEONCmpLeF32x8(');
  AssertDeadWrapperRemoved('NEONCmpLeF64x4', 'function NEONCmpLeF64x4(');
  AssertDeadWrapperRemoved('NEONCmpLeF64x8', 'function NEONCmpLeF64x8(');
  AssertDeadWrapperRemoved('NEONCmpLtF32x16', 'function NEONCmpLtF32x16(');
  AssertDeadWrapperRemoved('NEONCmpLtF32x8', 'function NEONCmpLtF32x8(');
  AssertDeadWrapperRemoved('NEONCmpLtF64x4', 'function NEONCmpLtF64x4(');
  AssertDeadWrapperRemoved('NEONCmpLtF64x8', 'function NEONCmpLtF64x8(');
  AssertDeadWrapperRemoved('NEONCmpNeF32x16', 'function NEONCmpNeF32x16(');
  AssertDeadWrapperRemoved('NEONCmpNeF32x8', 'function NEONCmpNeF32x8(');
  AssertDeadWrapperRemoved('NEONCmpNeF64x4', 'function NEONCmpNeF64x4(');
  AssertDeadWrapperRemoved('NEONCmpNeF64x8', 'function NEONCmpNeF64x8(');

  AssertRegisterKeepsBaseScalar('CmpEqF32x16', 'table.CoreVectors.CmpEqF32x16 := @NEONCmpEqF32x16;');
  AssertRegisterKeepsBaseScalar('CmpEqF32x8', 'table.CoreVectors.CmpEqF32x8 := @NEONCmpEqF32x8;');
  AssertRegisterKeepsBaseScalar('CmpEqF64x4', 'table.CoreVectors.CmpEqF64x4 := @NEONCmpEqF64x4;');
  AssertRegisterKeepsBaseScalar('CmpEqF64x8', 'table.CoreVectors.CmpEqF64x8 := @NEONCmpEqF64x8;');
  AssertRegisterKeepsBaseScalar('CmpGeF32x16', 'table.CoreVectors.CmpGeF32x16 := @NEONCmpGeF32x16;');
  AssertRegisterKeepsBaseScalar('CmpGeF32x8', 'table.CoreVectors.CmpGeF32x8 := @NEONCmpGeF32x8;');
  AssertRegisterKeepsBaseScalar('CmpGeF64x4', 'table.CoreVectors.CmpGeF64x4 := @NEONCmpGeF64x4;');
  AssertRegisterKeepsBaseScalar('CmpGeF64x8', 'table.CoreVectors.CmpGeF64x8 := @NEONCmpGeF64x8;');
  AssertRegisterKeepsBaseScalar('CmpGtF32x16', 'table.CoreVectors.CmpGtF32x16 := @NEONCmpGtF32x16;');
  AssertRegisterKeepsBaseScalar('CmpGtF32x8', 'table.CoreVectors.CmpGtF32x8 := @NEONCmpGtF32x8;');
  AssertRegisterKeepsBaseScalar('CmpGtF64x4', 'table.CoreVectors.CmpGtF64x4 := @NEONCmpGtF64x4;');
  AssertRegisterKeepsBaseScalar('CmpGtF64x8', 'table.CoreVectors.CmpGtF64x8 := @NEONCmpGtF64x8;');
  AssertRegisterKeepsBaseScalar('CmpLeF32x16', 'table.CoreVectors.CmpLeF32x16 := @NEONCmpLeF32x16;');
  AssertRegisterKeepsBaseScalar('CmpLeF32x8', 'table.CoreVectors.CmpLeF32x8 := @NEONCmpLeF32x8;');
  AssertRegisterKeepsBaseScalar('CmpLeF64x4', 'table.CoreVectors.CmpLeF64x4 := @NEONCmpLeF64x4;');
  AssertRegisterKeepsBaseScalar('CmpLeF64x8', 'table.CoreVectors.CmpLeF64x8 := @NEONCmpLeF64x8;');
  AssertRegisterKeepsBaseScalar('CmpLtF32x16', 'table.CoreVectors.CmpLtF32x16 := @NEONCmpLtF32x16;');
  AssertRegisterKeepsBaseScalar('CmpLtF32x8', 'table.CoreVectors.CmpLtF32x8 := @NEONCmpLtF32x8;');
  AssertRegisterKeepsBaseScalar('CmpLtF64x4', 'table.CoreVectors.CmpLtF64x4 := @NEONCmpLtF64x4;');
  AssertRegisterKeepsBaseScalar('CmpLtF64x8', 'table.CoreVectors.CmpLtF64x8 := @NEONCmpLtF64x8;');
  AssertRegisterKeepsBaseScalar('CmpNeF32x16', 'table.CoreVectors.CmpNeF32x16 := @NEONCmpNeF32x16;');
  AssertRegisterKeepsBaseScalar('CmpNeF32x8', 'table.CoreVectors.CmpNeF32x8 := @NEONCmpNeF32x8;');
  AssertRegisterKeepsBaseScalar('CmpNeF64x4', 'table.CoreVectors.CmpNeF64x4 := @NEONCmpNeF64x4;');
  AssertRegisterKeepsBaseScalar('CmpNeF64x8', 'table.CoreVectors.CmpNeF64x8 := @NEONCmpNeF64x8;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('CmpEqF32x16', Pointer(LScalarTable.CoreVectors.CmpEqF32x16), Pointer(LNEONTable.CoreVectors.CmpEqF32x16));
  AssertSlotReusesScalar('CmpEqF32x8', Pointer(LScalarTable.CoreVectors.CmpEqF32x8), Pointer(LNEONTable.CoreVectors.CmpEqF32x8));
  AssertSlotReusesScalar('CmpEqF64x4', Pointer(LScalarTable.CoreVectors.CmpEqF64x4), Pointer(LNEONTable.CoreVectors.CmpEqF64x4));
  AssertSlotReusesScalar('CmpEqF64x8', Pointer(LScalarTable.CoreVectors.CmpEqF64x8), Pointer(LNEONTable.CoreVectors.CmpEqF64x8));
  AssertSlotReusesScalar('CmpGeF32x16', Pointer(LScalarTable.CoreVectors.CmpGeF32x16), Pointer(LNEONTable.CoreVectors.CmpGeF32x16));
  AssertSlotReusesScalar('CmpGeF32x8', Pointer(LScalarTable.CoreVectors.CmpGeF32x8), Pointer(LNEONTable.CoreVectors.CmpGeF32x8));
  AssertSlotReusesScalar('CmpGeF64x4', Pointer(LScalarTable.CoreVectors.CmpGeF64x4), Pointer(LNEONTable.CoreVectors.CmpGeF64x4));
  AssertSlotReusesScalar('CmpGeF64x8', Pointer(LScalarTable.CoreVectors.CmpGeF64x8), Pointer(LNEONTable.CoreVectors.CmpGeF64x8));
  AssertSlotReusesScalar('CmpGtF32x16', Pointer(LScalarTable.CoreVectors.CmpGtF32x16), Pointer(LNEONTable.CoreVectors.CmpGtF32x16));
  AssertSlotReusesScalar('CmpGtF32x8', Pointer(LScalarTable.CoreVectors.CmpGtF32x8), Pointer(LNEONTable.CoreVectors.CmpGtF32x8));
  AssertSlotReusesScalar('CmpGtF64x4', Pointer(LScalarTable.CoreVectors.CmpGtF64x4), Pointer(LNEONTable.CoreVectors.CmpGtF64x4));
  AssertSlotReusesScalar('CmpGtF64x8', Pointer(LScalarTable.CoreVectors.CmpGtF64x8), Pointer(LNEONTable.CoreVectors.CmpGtF64x8));
  AssertSlotReusesScalar('CmpLeF32x16', Pointer(LScalarTable.CoreVectors.CmpLeF32x16), Pointer(LNEONTable.CoreVectors.CmpLeF32x16));
  AssertSlotReusesScalar('CmpLeF32x8', Pointer(LScalarTable.CoreVectors.CmpLeF32x8), Pointer(LNEONTable.CoreVectors.CmpLeF32x8));
  AssertSlotReusesScalar('CmpLeF64x4', Pointer(LScalarTable.CoreVectors.CmpLeF64x4), Pointer(LNEONTable.CoreVectors.CmpLeF64x4));
  AssertSlotReusesScalar('CmpLeF64x8', Pointer(LScalarTable.CoreVectors.CmpLeF64x8), Pointer(LNEONTable.CoreVectors.CmpLeF64x8));
  AssertSlotReusesScalar('CmpLtF32x16', Pointer(LScalarTable.CoreVectors.CmpLtF32x16), Pointer(LNEONTable.CoreVectors.CmpLtF32x16));
  AssertSlotReusesScalar('CmpLtF32x8', Pointer(LScalarTable.CoreVectors.CmpLtF32x8), Pointer(LNEONTable.CoreVectors.CmpLtF32x8));
  AssertSlotReusesScalar('CmpLtF64x4', Pointer(LScalarTable.CoreVectors.CmpLtF64x4), Pointer(LNEONTable.CoreVectors.CmpLtF64x4));
  AssertSlotReusesScalar('CmpLtF64x8', Pointer(LScalarTable.CoreVectors.CmpLtF64x8), Pointer(LNEONTable.CoreVectors.CmpLtF64x8));
  AssertSlotReusesScalar('CmpNeF32x16', Pointer(LScalarTable.CoreVectors.CmpNeF32x16), Pointer(LNEONTable.CoreVectors.CmpNeF32x16));
  AssertSlotReusesScalar('CmpNeF32x8', Pointer(LScalarTable.CoreVectors.CmpNeF32x8), Pointer(LNEONTable.CoreVectors.CmpNeF32x8));
  AssertSlotReusesScalar('CmpNeF64x4', Pointer(LScalarTable.CoreVectors.CmpNeF64x4), Pointer(LNEONTable.CoreVectors.CmpNeF64x4));
  AssertSlotReusesScalar('CmpNeF64x8', Pointer(LScalarTable.CoreVectors.CmpNeF64x8), Pointer(LNEONTable.CoreVectors.CmpNeF64x8));
end;

procedure TTestCase_DispatchAPI.Test_NEON_WideRcpAndReductionSlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LAutowrapSourcePath: string;
  LRegisterSource: string;
  LAutowrapSource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LAutowrapSource) = 0, aLabel + ' dead wrapper should be removed from the NEON scalar autowrap include');
  end;

  procedure AssertRegisterKeepsBaseScalar(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0, 'RegisterNEONBackend should keep base scalar ' + aLabel + ' when the NEON wrapper is only a scalar forwarder');
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the NEON wrapper is only a scalar forwarder');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LAutowrapSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.autowrap.inc');
    CheckTrue(FileExists(LAutowrapSourcePath), 'NEON scalar autowrap source should exist for implementation-shape audit: ' + LAutowrapSourcePath);
    LSourceLines.LoadFromFile(LAutowrapSourcePath);
    LAutowrapSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('NEONRcpF64x4', 'function NEONRcpF64x4(');
  AssertDeadWrapperRemoved('NEONReduceAddF32x16', 'function NEONReduceAddF32x16(');
  AssertDeadWrapperRemoved('NEONReduceAddF32x8', 'function NEONReduceAddF32x8(');
  AssertDeadWrapperRemoved('NEONReduceAddF64x4', 'function NEONReduceAddF64x4(');
  AssertDeadWrapperRemoved('NEONReduceAddF64x8', 'function NEONReduceAddF64x8(');
  AssertDeadWrapperRemoved('NEONReduceMaxF32x16', 'function NEONReduceMaxF32x16(');
  AssertDeadWrapperRemoved('NEONReduceMaxF32x8', 'function NEONReduceMaxF32x8(');
  AssertDeadWrapperRemoved('NEONReduceMaxF64x4', 'function NEONReduceMaxF64x4(');
  AssertDeadWrapperRemoved('NEONReduceMaxF64x8', 'function NEONReduceMaxF64x8(');
  AssertDeadWrapperRemoved('NEONReduceMinF32x16', 'function NEONReduceMinF32x16(');
  AssertDeadWrapperRemoved('NEONReduceMinF32x8', 'function NEONReduceMinF32x8(');
  AssertDeadWrapperRemoved('NEONReduceMinF64x4', 'function NEONReduceMinF64x4(');
  AssertDeadWrapperRemoved('NEONReduceMinF64x8', 'function NEONReduceMinF64x8(');
  AssertDeadWrapperRemoved('NEONReduceMulF32x16', 'function NEONReduceMulF32x16(');
  AssertDeadWrapperRemoved('NEONReduceMulF32x8', 'function NEONReduceMulF32x8(');
  AssertDeadWrapperRemoved('NEONReduceMulF64x4', 'function NEONReduceMulF64x4(');
  AssertDeadWrapperRemoved('NEONReduceMulF64x8', 'function NEONReduceMulF64x8(');

  AssertRegisterKeepsBaseScalar('RcpF64x4', 'table.CoreVectors.RcpF64x4 := @NEONRcpF64x4;');
  AssertRegisterKeepsBaseScalar('ReduceAddF32x16', 'table.CoreVectors.ReduceAddF32x16 := @NEONReduceAddF32x16;');
  AssertRegisterKeepsBaseScalar('ReduceAddF32x8', 'table.CoreVectors.ReduceAddF32x8 := @NEONReduceAddF32x8;');
  AssertRegisterKeepsBaseScalar('ReduceAddF64x4', 'table.CoreVectors.ReduceAddF64x4 := @NEONReduceAddF64x4;');
  AssertRegisterKeepsBaseScalar('ReduceAddF64x8', 'table.CoreVectors.ReduceAddF64x8 := @NEONReduceAddF64x8;');
  AssertRegisterKeepsBaseScalar('ReduceMaxF32x16', 'table.CoreVectors.ReduceMaxF32x16 := @NEONReduceMaxF32x16;');
  AssertRegisterKeepsBaseScalar('ReduceMaxF32x8', 'table.CoreVectors.ReduceMaxF32x8 := @NEONReduceMaxF32x8;');
  AssertRegisterKeepsBaseScalar('ReduceMaxF64x4', 'table.CoreVectors.ReduceMaxF64x4 := @NEONReduceMaxF64x4;');
  AssertRegisterKeepsBaseScalar('ReduceMaxF64x8', 'table.CoreVectors.ReduceMaxF64x8 := @NEONReduceMaxF64x8;');
  AssertRegisterKeepsBaseScalar('ReduceMinF32x16', 'table.CoreVectors.ReduceMinF32x16 := @NEONReduceMinF32x16;');
  AssertRegisterKeepsBaseScalar('ReduceMinF32x8', 'table.CoreVectors.ReduceMinF32x8 := @NEONReduceMinF32x8;');
  AssertRegisterKeepsBaseScalar('ReduceMinF64x4', 'table.CoreVectors.ReduceMinF64x4 := @NEONReduceMinF64x4;');
  AssertRegisterKeepsBaseScalar('ReduceMinF64x8', 'table.CoreVectors.ReduceMinF64x8 := @NEONReduceMinF64x8;');
  AssertRegisterKeepsBaseScalar('ReduceMulF32x16', 'table.CoreVectors.ReduceMulF32x16 := @NEONReduceMulF32x16;');
  AssertRegisterKeepsBaseScalar('ReduceMulF32x8', 'table.CoreVectors.ReduceMulF32x8 := @NEONReduceMulF32x8;');
  AssertRegisterKeepsBaseScalar('ReduceMulF64x4', 'table.CoreVectors.ReduceMulF64x4 := @NEONReduceMulF64x4;');
  AssertRegisterKeepsBaseScalar('ReduceMulF64x8', 'table.CoreVectors.ReduceMulF64x8 := @NEONReduceMulF64x8;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('RcpF64x4', Pointer(LScalarTable.CoreVectors.RcpF64x4), Pointer(LNEONTable.CoreVectors.RcpF64x4));
  AssertSlotReusesScalar('ReduceAddF32x16', Pointer(LScalarTable.CoreVectors.ReduceAddF32x16), Pointer(LNEONTable.CoreVectors.ReduceAddF32x16));
  AssertSlotReusesScalar('ReduceAddF32x8', Pointer(LScalarTable.CoreVectors.ReduceAddF32x8), Pointer(LNEONTable.CoreVectors.ReduceAddF32x8));
  AssertSlotReusesScalar('ReduceAddF64x4', Pointer(LScalarTable.CoreVectors.ReduceAddF64x4), Pointer(LNEONTable.CoreVectors.ReduceAddF64x4));
  AssertSlotReusesScalar('ReduceAddF64x8', Pointer(LScalarTable.CoreVectors.ReduceAddF64x8), Pointer(LNEONTable.CoreVectors.ReduceAddF64x8));
  AssertSlotReusesScalar('ReduceMaxF32x16', Pointer(LScalarTable.CoreVectors.ReduceMaxF32x16), Pointer(LNEONTable.CoreVectors.ReduceMaxF32x16));
  AssertSlotReusesScalar('ReduceMaxF32x8', Pointer(LScalarTable.CoreVectors.ReduceMaxF32x8), Pointer(LNEONTable.CoreVectors.ReduceMaxF32x8));
  AssertSlotReusesScalar('ReduceMaxF64x4', Pointer(LScalarTable.CoreVectors.ReduceMaxF64x4), Pointer(LNEONTable.CoreVectors.ReduceMaxF64x4));
  AssertSlotReusesScalar('ReduceMaxF64x8', Pointer(LScalarTable.CoreVectors.ReduceMaxF64x8), Pointer(LNEONTable.CoreVectors.ReduceMaxF64x8));
  AssertSlotReusesScalar('ReduceMinF32x16', Pointer(LScalarTable.CoreVectors.ReduceMinF32x16), Pointer(LNEONTable.CoreVectors.ReduceMinF32x16));
  AssertSlotReusesScalar('ReduceMinF32x8', Pointer(LScalarTable.CoreVectors.ReduceMinF32x8), Pointer(LNEONTable.CoreVectors.ReduceMinF32x8));
  AssertSlotReusesScalar('ReduceMinF64x4', Pointer(LScalarTable.CoreVectors.ReduceMinF64x4), Pointer(LNEONTable.CoreVectors.ReduceMinF64x4));
  AssertSlotReusesScalar('ReduceMinF64x8', Pointer(LScalarTable.CoreVectors.ReduceMinF64x8), Pointer(LNEONTable.CoreVectors.ReduceMinF64x8));
  AssertSlotReusesScalar('ReduceMulF32x16', Pointer(LScalarTable.CoreVectors.ReduceMulF32x16), Pointer(LNEONTable.CoreVectors.ReduceMulF32x16));
  AssertSlotReusesScalar('ReduceMulF32x8', Pointer(LScalarTable.CoreVectors.ReduceMulF32x8), Pointer(LNEONTable.CoreVectors.ReduceMulF32x8));
  AssertSlotReusesScalar('ReduceMulF64x4', Pointer(LScalarTable.CoreVectors.ReduceMulF64x4), Pointer(LNEONTable.CoreVectors.ReduceMulF64x4));
  AssertSlotReusesScalar('ReduceMulF64x8', Pointer(LScalarTable.CoreVectors.ReduceMulF64x8), Pointer(LNEONTable.CoreVectors.ReduceMulF64x8));
end;

procedure TTestCase_DispatchAPI.Test_NEON_ExtractInsertSelectSlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LAutowrapSourcePath: string;
  LRegisterSource: string;
  LAutowrapSource: string;
  LOldVectorAsm: Boolean;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LAutowrapSource) = 0, aLabel + ' dead wrapper should be removed from the NEON scalar autowrap include');
  end;

  procedure AssertRegisterKeepsBaseScalar(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0, 'RegisterNEONBackend should keep base scalar ' + aLabel + ' when the NEON wrapper is only a scalar forwarder');
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the NEON wrapper is only a scalar forwarder');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LAutowrapSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.autowrap.inc');
    CheckTrue(FileExists(LAutowrapSourcePath), 'NEON scalar autowrap source should exist for implementation-shape audit: ' + LAutowrapSourcePath);
    LSourceLines.LoadFromFile(LAutowrapSourcePath);
    LAutowrapSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('NEONExtractF32x16', 'function NEONExtractF32x16(');
  AssertDeadWrapperRemoved('NEONExtractF32x8', 'function NEONExtractF32x8(');
  AssertDeadWrapperRemoved('NEONExtractF64x4', 'function NEONExtractF64x4(');
  AssertDeadWrapperRemoved('NEONExtractI32x4', 'function NEONExtractI32x4(');
  AssertDeadWrapperRemoved('NEONExtractI64x2', 'function NEONExtractI64x2(');
  AssertDeadWrapperRemoved('NEONInsertF32x16', 'function NEONInsertF32x16(');
  AssertDeadWrapperRemoved('NEONInsertF32x8', 'function NEONInsertF32x8(');
  AssertDeadWrapperRemoved('NEONInsertF64x4', 'function NEONInsertF64x4(');
  AssertDeadWrapperRemoved('NEONInsertI32x4', 'function NEONInsertI32x4(');
  AssertDeadWrapperRemoved('NEONInsertI64x2', 'function NEONInsertI64x2(');
  AssertDeadWrapperRemoved('NEONSelectF32x16', 'function NEONSelectF32x16(');
  AssertDeadWrapperRemoved('NEONSelectF32x8', 'function NEONSelectF32x8(');
  AssertDeadWrapperRemoved('NEONSelectF64x4', 'function NEONSelectF64x4(');
  AssertDeadWrapperRemoved('NEONSelectF64x8', 'function NEONSelectF64x8(');
  AssertDeadWrapperRemoved('NEONSelectI32x4', 'function NEONSelectI32x4(');

  AssertRegisterKeepsBaseScalar('ExtractF32x16', 'table.CoreVectors.ExtractF32x16 := @NEONExtractF32x16;');
  AssertRegisterKeepsBaseScalar('ExtractF32x8', 'table.CoreVectors.ExtractF32x8 := @NEONExtractF32x8;');
  AssertRegisterKeepsBaseScalar('ExtractF64x4', 'table.CoreVectors.ExtractF64x4 := @NEONExtractF64x4;');
  AssertRegisterKeepsBaseScalar('ExtractI32x4', 'table.CoreVectors.ExtractI32x4 := @NEONExtractI32x4;');
  AssertRegisterKeepsBaseScalar('ExtractI64x2', 'table.CoreVectors.ExtractI64x2 := @NEONExtractI64x2;');
  AssertRegisterKeepsBaseScalar('InsertF32x16', 'table.CoreVectors.InsertF32x16 := @NEONInsertF32x16;');
  AssertRegisterKeepsBaseScalar('InsertF32x8', 'table.CoreVectors.InsertF32x8 := @NEONInsertF32x8;');
  AssertRegisterKeepsBaseScalar('InsertF64x4', 'table.CoreVectors.InsertF64x4 := @NEONInsertF64x4;');
  AssertRegisterKeepsBaseScalar('InsertI32x4', 'table.CoreVectors.InsertI32x4 := @NEONInsertI32x4;');
  AssertRegisterKeepsBaseScalar('InsertI64x2', 'table.CoreVectors.InsertI64x2 := @NEONInsertI64x2;');
  AssertRegisterKeepsBaseScalar('SelectF32x16', 'table.CoreVectors.SelectF32x16 := @NEONSelectF32x16;');
  AssertRegisterKeepsBaseScalar('SelectF32x8', 'table.CoreVectors.SelectF32x8 := @NEONSelectF32x8;');
  AssertRegisterKeepsBaseScalar('SelectF64x4', 'table.CoreVectors.SelectF64x4 := @NEONSelectF64x4;');
  AssertRegisterKeepsBaseScalar('SelectF64x8', 'table.CoreVectors.SelectF64x8 := @NEONSelectF64x8;');
  AssertRegisterKeepsBaseScalar('SelectI32x4', 'table.CoreVectors.SelectI32x4 := @NEONSelectI32x4;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  LOldVectorAsm := IsVectorAsmEnabled;
  try
    SetVectorAsmEnabled(True);
    if not IsVectorAsmEnabled then
      Exit;

    {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
    CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
    {$ELSE}
    if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
      Exit;
    {$ENDIF}

    AssertSlotReusesScalar('ExtractF32x16', Pointer(LScalarTable.CoreVectors.ExtractF32x16), Pointer(LNEONTable.CoreVectors.ExtractF32x16));
    AssertSlotReusesScalar('ExtractF32x8', Pointer(LScalarTable.CoreVectors.ExtractF32x8), Pointer(LNEONTable.CoreVectors.ExtractF32x8));
    AssertSlotReusesScalar('ExtractF64x4', Pointer(LScalarTable.CoreVectors.ExtractF64x4), Pointer(LNEONTable.CoreVectors.ExtractF64x4));
    AssertSlotReusesScalar('ExtractI32x4', Pointer(LScalarTable.CoreVectors.ExtractI32x4), Pointer(LNEONTable.CoreVectors.ExtractI32x4));
    AssertSlotReusesScalar('ExtractI64x2', Pointer(LScalarTable.CoreVectors.ExtractI64x2), Pointer(LNEONTable.CoreVectors.ExtractI64x2));
    AssertSlotReusesScalar('InsertF32x16', Pointer(LScalarTable.CoreVectors.InsertF32x16), Pointer(LNEONTable.CoreVectors.InsertF32x16));
    AssertSlotReusesScalar('InsertF32x8', Pointer(LScalarTable.CoreVectors.InsertF32x8), Pointer(LNEONTable.CoreVectors.InsertF32x8));
    AssertSlotReusesScalar('InsertF64x4', Pointer(LScalarTable.CoreVectors.InsertF64x4), Pointer(LNEONTable.CoreVectors.InsertF64x4));
    AssertSlotReusesScalar('InsertI32x4', Pointer(LScalarTable.CoreVectors.InsertI32x4), Pointer(LNEONTable.CoreVectors.InsertI32x4));
    AssertSlotReusesScalar('InsertI64x2', Pointer(LScalarTable.CoreVectors.InsertI64x2), Pointer(LNEONTable.CoreVectors.InsertI64x2));
    AssertSlotReusesScalar('SelectF32x16', Pointer(LScalarTable.CoreVectors.SelectF32x16), Pointer(LNEONTable.CoreVectors.SelectF32x16));
    AssertSlotReusesScalar('SelectF32x8', Pointer(LScalarTable.CoreVectors.SelectF32x8), Pointer(LNEONTable.CoreVectors.SelectF32x8));
    AssertSlotReusesScalar('SelectF64x4', Pointer(LScalarTable.CoreVectors.SelectF64x4), Pointer(LNEONTable.CoreVectors.SelectF64x4));
    AssertSlotReusesScalar('SelectF64x8', Pointer(LScalarTable.CoreVectors.SelectF64x8), Pointer(LNEONTable.CoreVectors.SelectF64x8));
    AssertSlotReusesScalar('SelectI32x4', Pointer(LScalarTable.CoreVectors.SelectI32x4), Pointer(LNEONTable.CoreVectors.SelectI32x4));
  finally
    SetVectorAsmEnabled(LOldVectorAsm);
    RebindSimdDataPlane;
  end;
end;

procedure TTestCase_DispatchAPI.Test_NEON_NoAsmFMASlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LExtMathSourcePath: string;
  LAutowrapSourcePath: string;
  LRegisterSource: string;
  LExtMathSource: string;
  LAutowrapSource: string;

  procedure AssertDeadExtMathWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LExtMathSource) = 0, aLabel + ' dead wrapper should be removed from the NEON scalar ext-math include');
  end;

  procedure AssertDeadAutowrapWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LAutowrapSource) = 0, aLabel + ' dead wrapper should be removed from the NEON scalar autowrap include');
  end;

  procedure AssertAsmBindingStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterNEONBackend should still keep the asm-enabled binding source for ' + aLabel);
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the no-asm NEON wrapper is only a scalar forwarder');
  end;
begin
  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  Exit;
  {$ENDIF}

  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LExtMathSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.ext.math.inc');
    CheckTrue(FileExists(LExtMathSourcePath), 'NEON scalar ext-math source should exist for implementation-shape audit: ' + LExtMathSourcePath);
    LSourceLines.LoadFromFile(LExtMathSourcePath);
    LExtMathSource := LowerCase(LSourceLines.Text);

    LAutowrapSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.autowrap.inc');
    CheckTrue(FileExists(LAutowrapSourcePath), 'NEON scalar autowrap source should exist for implementation-shape audit: ' + LAutowrapSourcePath);
    LSourceLines.LoadFromFile(LAutowrapSourcePath);
    LAutowrapSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadExtMathWrapperRemoved('NEONFmaF32x4', 'function NEONFmaF32x4(');
  AssertDeadAutowrapWrapperRemoved('NEONFmaF32x16', 'function NEONFmaF32x16(');
  AssertDeadAutowrapWrapperRemoved('NEONFmaF32x8', 'function NEONFmaF32x8(');
  AssertDeadAutowrapWrapperRemoved('NEONFmaF64x2', 'function NEONFmaF64x2(');
  AssertDeadAutowrapWrapperRemoved('NEONFmaF64x4', 'function NEONFmaF64x4(');
  AssertDeadAutowrapWrapperRemoved('NEONFmaF64x8', 'function NEONFmaF64x8(');

  AssertAsmBindingStillPresent('FmaF32x4', 'table.CoreVectors.FmaF32x4 := @NEONFmaF32x4;');
  AssertAsmBindingStillPresent('FmaF32x16', 'table.CoreVectors.FmaF32x16 := @NEONFmaF32x16;');
  AssertAsmBindingStillPresent('FmaF32x8', 'table.CoreVectors.FmaF32x8 := @NEONFmaF32x8;');
  AssertAsmBindingStillPresent('FmaF64x2', 'table.CoreVectors.FmaF64x2 := @NEONFmaF64x2;');
  AssertAsmBindingStillPresent('FmaF64x4', 'table.CoreVectors.FmaF64x4 := @NEONFmaF64x4;');
  AssertAsmBindingStillPresent('FmaF64x8', 'table.CoreVectors.FmaF64x8 := @NEONFmaF64x8;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('FmaF32x4', Pointer(LScalarTable.CoreVectors.FmaF32x4), Pointer(LNEONTable.CoreVectors.FmaF32x4));
  AssertSlotReusesScalar('FmaF32x16', Pointer(LScalarTable.CoreVectors.FmaF32x16), Pointer(LNEONTable.CoreVectors.FmaF32x16));
  AssertSlotReusesScalar('FmaF32x8', Pointer(LScalarTable.CoreVectors.FmaF32x8), Pointer(LNEONTable.CoreVectors.FmaF32x8));
  AssertSlotReusesScalar('FmaF64x2', Pointer(LScalarTable.CoreVectors.FmaF64x2), Pointer(LNEONTable.CoreVectors.FmaF64x2));
  AssertSlotReusesScalar('FmaF64x4', Pointer(LScalarTable.CoreVectors.FmaF64x4), Pointer(LNEONTable.CoreVectors.FmaF64x4));
  AssertSlotReusesScalar('FmaF64x8', Pointer(LScalarTable.CoreVectors.FmaF64x8), Pointer(LNEONTable.CoreVectors.FmaF64x8));
end;

procedure TTestCase_DispatchAPI.Test_NEON_NoAsmNarrowReciprocalSlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LExtMathSourcePath: string;
  LRegisterSource: string;
  LExtMathSource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LExtMathSource) = 0, aLabel + ' dead wrapper should be removed from the NEON scalar ext-math include');
  end;

  procedure AssertAsmBindingStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterNEONBackend should still keep the asm-enabled binding source for ' + aLabel);
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the no-asm NEON wrapper is only a scalar forwarder');
  end;
begin
  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  Exit;
  {$ENDIF}

  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LExtMathSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.ext.math.inc');
    CheckTrue(FileExists(LExtMathSourcePath), 'NEON scalar ext-math source should exist for implementation-shape audit: ' + LExtMathSourcePath);
    LSourceLines.LoadFromFile(LExtMathSourcePath);
    LExtMathSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('NEONRcpF32x4', 'function NEONRcpF32x4(');
  AssertDeadWrapperRemoved('NEONRsqrtF32x4', 'function NEONRsqrtF32x4(');

  AssertAsmBindingStillPresent('RcpF32x4', 'table.CoreVectors.RcpF32x4 := @NEONRcpF32x4;');
  AssertAsmBindingStillPresent('RsqrtF32x4', 'table.CoreVectors.RsqrtF32x4 := @NEONRsqrtF32x4;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('RcpF32x4', Pointer(LScalarTable.CoreVectors.RcpF32x4), Pointer(LNEONTable.CoreVectors.RcpF32x4));
  AssertSlotReusesScalar('RsqrtF32x4', Pointer(LScalarTable.CoreVectors.RsqrtF32x4), Pointer(LNEONTable.CoreVectors.RsqrtF32x4));
end;

procedure TTestCase_DispatchAPI.Test_NEON_NoAsmNarrowI16U16ShiftSlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LAutowrapSourcePath: string;
  LRegisterSource: string;
  LAutowrapSource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LAutowrapSource) = 0, aLabel + ' dead wrapper should be removed from the NEON scalar autowrap include');
  end;

  procedure AssertAsmBindingStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterNEONBackend should still keep the asm-enabled binding source for ' + aLabel);
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the no-asm NEON wrapper is only a scalar forwarder');
  end;
begin
  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  Exit;
  {$ENDIF}

  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LAutowrapSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.autowrap.inc');
    CheckTrue(FileExists(LAutowrapSourcePath), 'NEON scalar autowrap source should exist for implementation-shape audit: ' + LAutowrapSourcePath);
    LSourceLines.LoadFromFile(LAutowrapSourcePath);
    LAutowrapSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('NEONShiftLeftI16x8', 'function NEONShiftLeftI16x8(');
  AssertDeadWrapperRemoved('NEONShiftLeftU16x8', 'function NEONShiftLeftU16x8(');
  AssertDeadWrapperRemoved('NEONShiftRightArithI16x8', 'function NEONShiftRightArithI16x8(');
  AssertDeadWrapperRemoved('NEONShiftRightI16x8', 'function NEONShiftRightI16x8(');
  AssertDeadWrapperRemoved('NEONShiftRightU16x8', 'function NEONShiftRightU16x8(');

  AssertAsmBindingStillPresent('ShiftLeftI16x8', 'table.CoreVectors.ShiftLeftI16x8 := @NEONShiftLeftI16x8;');
  AssertAsmBindingStillPresent('ShiftLeftU16x8', 'table.CoreVectors.ShiftLeftU16x8 := @NEONShiftLeftU16x8;');
  AssertAsmBindingStillPresent('ShiftRightArithI16x8', 'table.CoreVectors.ShiftRightArithI16x8 := @NEONShiftRightArithI16x8;');
  AssertAsmBindingStillPresent('ShiftRightI16x8', 'table.CoreVectors.ShiftRightI16x8 := @NEONShiftRightI16x8;');
  AssertAsmBindingStillPresent('ShiftRightU16x8', 'table.CoreVectors.ShiftRightU16x8 := @NEONShiftRightU16x8;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('ShiftLeftI16x8', Pointer(LScalarTable.CoreVectors.ShiftLeftI16x8), Pointer(LNEONTable.CoreVectors.ShiftLeftI16x8));
  AssertSlotReusesScalar('ShiftLeftU16x8', Pointer(LScalarTable.CoreVectors.ShiftLeftU16x8), Pointer(LNEONTable.CoreVectors.ShiftLeftU16x8));
  AssertSlotReusesScalar('ShiftRightArithI16x8', Pointer(LScalarTable.CoreVectors.ShiftRightArithI16x8), Pointer(LNEONTable.CoreVectors.ShiftRightArithI16x8));
  AssertSlotReusesScalar('ShiftRightI16x8', Pointer(LScalarTable.CoreVectors.ShiftRightI16x8), Pointer(LNEONTable.CoreVectors.ShiftRightI16x8));
  AssertSlotReusesScalar('ShiftRightU16x8', Pointer(LScalarTable.CoreVectors.ShiftRightU16x8), Pointer(LNEONTable.CoreVectors.ShiftRightU16x8));
end;

procedure TTestCase_DispatchAPI.Test_NEON_NoAsmNarrowF64MemorySlots_Reuse_BaseScalar_When_Wrappers_Have_No_Live_SourceConsumers;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LAutowrapSourcePath: string;
  LRegisterSource: string;
  LAutowrapSource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LAutowrapSource) = 0, aLabel + ' dead wrapper should be removed from the NEON scalar autowrap include');
  end;

  procedure AssertAsmBindingStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterNEONBackend should still keep the asm-enabled binding source for ' + aLabel);
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the no-asm NEON wrapper has no live source consumers');
  end;
begin
  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  Exit;
  {$ENDIF}

  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LAutowrapSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.autowrap.inc');
    CheckTrue(FileExists(LAutowrapSourcePath), 'NEON scalar autowrap source should exist for implementation-shape audit: ' + LAutowrapSourcePath);
    LSourceLines.LoadFromFile(LAutowrapSourcePath);
    LAutowrapSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('NEONLoadF64x2', 'function NEONLoadF64x2(');
  AssertDeadWrapperRemoved('NEONStoreF64x2', 'procedure NEONStoreF64x2(');
  AssertDeadWrapperRemoved('NEONSplatF64x2', 'function NEONSplatF64x2(');
  AssertDeadWrapperRemoved('NEONZeroF64x2', 'function NEONZeroF64x2');

  AssertAsmBindingStillPresent('LoadF64x2', 'table.CoreVectors.LoadF64x2 := @NEONLoadF64x2;');
  AssertAsmBindingStillPresent('StoreF64x2', 'table.CoreVectors.StoreF64x2 := @NEONStoreF64x2;');
  AssertAsmBindingStillPresent('SplatF64x2', 'table.CoreVectors.SplatF64x2 := @NEONSplatF64x2;');
  AssertAsmBindingStillPresent('ZeroF64x2', 'table.CoreVectors.ZeroF64x2 := @NEONZeroF64x2;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('LoadF64x2', Pointer(LScalarTable.CoreVectors.LoadF64x2), Pointer(LNEONTable.CoreVectors.LoadF64x2));
  AssertSlotReusesScalar('StoreF64x2', Pointer(LScalarTable.CoreVectors.StoreF64x2), Pointer(LNEONTable.CoreVectors.StoreF64x2));
  AssertSlotReusesScalar('SplatF64x2', Pointer(LScalarTable.CoreVectors.SplatF64x2), Pointer(LNEONTable.CoreVectors.SplatF64x2));
  AssertSlotReusesScalar('ZeroF64x2', Pointer(LScalarTable.CoreVectors.ZeroF64x2), Pointer(LNEONTable.CoreVectors.ZeroF64x2));
end;

procedure TTestCase_DispatchAPI.Test_NEON_NoAsmWideF32x8ArithmeticSlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFallbackSourcePath: string;
  LRegisterSource: string;
  LFallbackSource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LFallbackSource) = 0, aLabel + ' dead wrapper should be removed from the NEON scalar fallback include');
  end;

  procedure AssertAsmBindingStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterNEONBackend should still keep the asm-enabled binding source for ' + aLabel);
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the no-asm NEON wrapper is only a scalar forwarder');
  end;
begin
  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  Exit;
  {$ENDIF}

  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFallbackSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.fallback.inc');
    CheckTrue(FileExists(LFallbackSourcePath), 'NEON scalar fallback source should exist for implementation-shape audit: ' + LFallbackSourcePath);
    LSourceLines.LoadFromFile(LFallbackSourcePath);
    LFallbackSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('NEONAddF32x8', 'function NEONAddF32x8(');
  AssertDeadWrapperRemoved('NEONSubF32x8', 'function NEONSubF32x8(');
  AssertDeadWrapperRemoved('NEONMulF32x8', 'function NEONMulF32x8(');
  AssertDeadWrapperRemoved('NEONDivF32x8', 'function NEONDivF32x8(');

  AssertAsmBindingStillPresent('AddF32x8', 'table.CoreVectors.AddF32x8 := @NEONAddF32x8;');
  AssertAsmBindingStillPresent('SubF32x8', 'table.CoreVectors.SubF32x8 := @NEONSubF32x8;');
  AssertAsmBindingStillPresent('MulF32x8', 'table.CoreVectors.MulF32x8 := @NEONMulF32x8;');
  AssertAsmBindingStillPresent('DivF32x8', 'table.CoreVectors.DivF32x8 := @NEONDivF32x8;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('AddF32x8', Pointer(LScalarTable.CoreVectors.AddF32x8), Pointer(LNEONTable.CoreVectors.AddF32x8));
  AssertSlotReusesScalar('SubF32x8', Pointer(LScalarTable.CoreVectors.SubF32x8), Pointer(LNEONTable.CoreVectors.SubF32x8));
  AssertSlotReusesScalar('MulF32x8', Pointer(LScalarTable.CoreVectors.MulF32x8), Pointer(LNEONTable.CoreVectors.MulF32x8));
  AssertSlotReusesScalar('DivF32x8', Pointer(LScalarTable.CoreVectors.DivF32x8), Pointer(LNEONTable.CoreVectors.DivF32x8));
end;

procedure TTestCase_DispatchAPI.Test_NEON_NoAsmWideLeafFloatArithmeticSlots_Keep_SourceCompanions_But_Reuse_BaseScalar;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LAutowrapSourcePath: string;
  LRegisterSource: string;
  LAutowrapSource: string;

  procedure AssertWrapperStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LAutowrapSource) > 0, aLabel + ' source companion should remain in the NEON scalar autowrap include');
  end;

  procedure AssertAsmBindingStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterNEONBackend should still keep the asm-enabled binding source for ' + aLabel);
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the no-asm wide wrapper is only a backend-local composition');
  end;
begin
  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  Exit;
  {$ENDIF}

  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LAutowrapSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.autowrap.inc');
    CheckTrue(FileExists(LAutowrapSourcePath), 'NEON scalar autowrap source should exist for implementation-shape audit: ' + LAutowrapSourcePath);
    LSourceLines.LoadFromFile(LAutowrapSourcePath);
    LAutowrapSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertWrapperStillPresent('NEONAddF32x16', 'function NEONAddF32x16(');
  AssertWrapperStillPresent('NEONAddF64x4', 'function NEONAddF64x4(');
  AssertWrapperStillPresent('NEONSubF32x16', 'function NEONSubF32x16(');
  AssertWrapperStillPresent('NEONSubF64x4', 'function NEONSubF64x4(');
  AssertWrapperStillPresent('NEONMulF32x16', 'function NEONMulF32x16(');
  AssertWrapperStillPresent('NEONMulF64x4', 'function NEONMulF64x4(');
  AssertWrapperStillPresent('NEONDivF32x16', 'function NEONDivF32x16(');
  AssertWrapperStillPresent('NEONDivF64x4', 'function NEONDivF64x4(');
  AssertWrapperStillPresent('NEONAddF64x8', 'function NEONAddF64x8(');
  AssertWrapperStillPresent('NEONSubF64x8', 'function NEONSubF64x8(');
  AssertWrapperStillPresent('NEONMulF64x8', 'function NEONMulF64x8(');
  AssertWrapperStillPresent('NEONDivF64x8', 'function NEONDivF64x8(');

  AssertAsmBindingStillPresent('AddF32x16', 'table.CoreVectors.AddF32x16 := @NEONAddF32x16;');
  AssertAsmBindingStillPresent('AddF64x4', 'table.CoreVectors.AddF64x4 := @NEONAddF64x4;');
  AssertAsmBindingStillPresent('SubF32x16', 'table.CoreVectors.SubF32x16 := @NEONSubF32x16;');
  AssertAsmBindingStillPresent('SubF64x4', 'table.CoreVectors.SubF64x4 := @NEONSubF64x4;');
  AssertAsmBindingStillPresent('MulF32x16', 'table.CoreVectors.MulF32x16 := @NEONMulF32x16;');
  AssertAsmBindingStillPresent('MulF64x4', 'table.CoreVectors.MulF64x4 := @NEONMulF64x4;');
  AssertAsmBindingStillPresent('DivF32x16', 'table.CoreVectors.DivF32x16 := @NEONDivF32x16;');
  AssertAsmBindingStillPresent('DivF64x4', 'table.CoreVectors.DivF64x4 := @NEONDivF64x4;');
  AssertAsmBindingStillPresent('AddF64x8', 'table.CoreVectors.AddF64x8 := @NEONAddF64x8;');
  AssertAsmBindingStillPresent('SubF64x8', 'table.CoreVectors.SubF64x8 := @NEONSubF64x8;');
  AssertAsmBindingStillPresent('MulF64x8', 'table.CoreVectors.MulF64x8 := @NEONMulF64x8;');
  AssertAsmBindingStillPresent('DivF64x8', 'table.CoreVectors.DivF64x8 := @NEONDivF64x8;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('AddF32x16', Pointer(LScalarTable.CoreVectors.AddF32x16), Pointer(LNEONTable.CoreVectors.AddF32x16));
  AssertSlotReusesScalar('AddF64x4', Pointer(LScalarTable.CoreVectors.AddF64x4), Pointer(LNEONTable.CoreVectors.AddF64x4));
  AssertSlotReusesScalar('SubF32x16', Pointer(LScalarTable.CoreVectors.SubF32x16), Pointer(LNEONTable.CoreVectors.SubF32x16));
  AssertSlotReusesScalar('SubF64x4', Pointer(LScalarTable.CoreVectors.SubF64x4), Pointer(LNEONTable.CoreVectors.SubF64x4));
  AssertSlotReusesScalar('MulF32x16', Pointer(LScalarTable.CoreVectors.MulF32x16), Pointer(LNEONTable.CoreVectors.MulF32x16));
  AssertSlotReusesScalar('MulF64x4', Pointer(LScalarTable.CoreVectors.MulF64x4), Pointer(LNEONTable.CoreVectors.MulF64x4));
  AssertSlotReusesScalar('DivF32x16', Pointer(LScalarTable.CoreVectors.DivF32x16), Pointer(LNEONTable.CoreVectors.DivF32x16));
  AssertSlotReusesScalar('DivF64x4', Pointer(LScalarTable.CoreVectors.DivF64x4), Pointer(LNEONTable.CoreVectors.DivF64x4));
  AssertSlotReusesScalar('AddF64x8', Pointer(LScalarTable.CoreVectors.AddF64x8), Pointer(LNEONTable.CoreVectors.AddF64x8));
  AssertSlotReusesScalar('SubF64x8', Pointer(LScalarTable.CoreVectors.SubF64x8), Pointer(LNEONTable.CoreVectors.SubF64x8));
  AssertSlotReusesScalar('MulF64x8', Pointer(LScalarTable.CoreVectors.MulF64x8), Pointer(LNEONTable.CoreVectors.MulF64x8));
  AssertSlotReusesScalar('DivF64x8', Pointer(LScalarTable.CoreVectors.DivF64x8), Pointer(LNEONTable.CoreVectors.DivF64x8));
end;

procedure TTestCase_DispatchAPI.Test_NEON_NoAsmWideMinMaxSlots_Keep_Necessary_Wrappers_But_Reuse_BaseScalar;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LAutowrapSourcePath: string;
  LRegisterSource: string;
  LAutowrapSource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LAutowrapSource) = 0, aLabel + ' dead wrapper should be removed from the NEON scalar autowrap include');
  end;

  procedure AssertWrapperStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LAutowrapSource) > 0, aLabel + ' wrapper should remain in the NEON scalar autowrap include because asm or wider source graphs still consume it');
  end;

  procedure AssertAsmBindingStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterNEONBackend should still keep the asm-enabled binding source for ' + aLabel);
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the no-asm wide min/max wrapper has no standalone published backend-local truth');
  end;
begin
  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  Exit;
  {$ENDIF}

  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LAutowrapSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.autowrap.inc');
    CheckTrue(FileExists(LAutowrapSourcePath), 'NEON scalar autowrap source should exist for implementation-shape audit: ' + LAutowrapSourcePath);
    LSourceLines.LoadFromFile(LAutowrapSourcePath);
    LAutowrapSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('NEONMaxF32x8', 'function NEONMaxF32x8(');
  AssertDeadWrapperRemoved('NEONMinF32x8', 'function NEONMinF32x8(');

  AssertWrapperStillPresent('NEONMaxF32x16', 'function NEONMaxF32x16(');
  AssertWrapperStillPresent('NEONMinF32x16', 'function NEONMinF32x16(');
  AssertWrapperStillPresent('NEONMaxF64x4', 'function NEONMaxF64x4(');
  AssertWrapperStillPresent('NEONMinF64x4', 'function NEONMinF64x4(');
  AssertWrapperStillPresent('NEONMaxF64x8', 'function NEONMaxF64x8(');
  AssertWrapperStillPresent('NEONMinF64x8', 'function NEONMinF64x8(');

  AssertAsmBindingStillPresent('MaxF32x16', 'table.CoreVectors.MaxF32x16 := @NEONMaxF32x16;');
  AssertAsmBindingStillPresent('MaxF32x8', 'table.CoreVectors.MaxF32x8 := @NEONMaxF32x8;');
  AssertAsmBindingStillPresent('MaxF64x4', 'table.CoreVectors.MaxF64x4 := @NEONMaxF64x4;');
  AssertAsmBindingStillPresent('MaxF64x8', 'table.CoreVectors.MaxF64x8 := @NEONMaxF64x8;');
  AssertAsmBindingStillPresent('MinF32x16', 'table.CoreVectors.MinF32x16 := @NEONMinF32x16;');
  AssertAsmBindingStillPresent('MinF32x8', 'table.CoreVectors.MinF32x8 := @NEONMinF32x8;');
  AssertAsmBindingStillPresent('MinF64x4', 'table.CoreVectors.MinF64x4 := @NEONMinF64x4;');
  AssertAsmBindingStillPresent('MinF64x8', 'table.CoreVectors.MinF64x8 := @NEONMinF64x8;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('MaxF32x16', Pointer(LScalarTable.CoreVectors.MaxF32x16), Pointer(LNEONTable.CoreVectors.MaxF32x16));
  AssertSlotReusesScalar('MaxF32x8', Pointer(LScalarTable.CoreVectors.MaxF32x8), Pointer(LNEONTable.CoreVectors.MaxF32x8));
  AssertSlotReusesScalar('MaxF64x4', Pointer(LScalarTable.CoreVectors.MaxF64x4), Pointer(LNEONTable.CoreVectors.MaxF64x4));
  AssertSlotReusesScalar('MaxF64x8', Pointer(LScalarTable.CoreVectors.MaxF64x8), Pointer(LNEONTable.CoreVectors.MaxF64x8));
  AssertSlotReusesScalar('MinF32x16', Pointer(LScalarTable.CoreVectors.MinF32x16), Pointer(LNEONTable.CoreVectors.MinF32x16));
  AssertSlotReusesScalar('MinF32x8', Pointer(LScalarTable.CoreVectors.MinF32x8), Pointer(LNEONTable.CoreVectors.MinF32x8));
  AssertSlotReusesScalar('MinF64x4', Pointer(LScalarTable.CoreVectors.MinF64x4), Pointer(LNEONTable.CoreVectors.MinF64x4));
  AssertSlotReusesScalar('MinF64x8', Pointer(LScalarTable.CoreVectors.MinF64x8), Pointer(LNEONTable.CoreVectors.MinF64x8));
end;

procedure TTestCase_DispatchAPI.Test_NEON_NoAsmNarrowF64MinMaxSlots_Keep_SourceCompanion_But_Reuse_BaseScalar;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LAutowrapSourcePath: string;
  LRegisterSource: string;
  LAutowrapSource: string;

  procedure AssertScalarAlignedWrapper(const aLabel, aSignatureSnippet, aBodySnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSignatureSnippet), LAutowrapSource) > 0, aLabel + ' source companion should remain in the NEON scalar autowrap include');
    CheckTrue(Pos(LowerCase(aBodySnippet), LAutowrapSource) > 0, aLabel + ' should now align exactly with the scalar F64x2 min/max semantics in no-asm builds');
  end;

  procedure AssertSourceConsumerStillPresent(const aLabel, aSignatureSnippet, aBodySnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSignatureSnippet), LAutowrapSource) > 0, aLabel + ' should remain in the NEON scalar autowrap include as the narrow F64x2 source consumer');
    CheckTrue(Pos(LowerCase(aBodySnippet), LAutowrapSource) > 0, aLabel + ' should still consume the narrow F64x2 companion in the no-asm fallback graph');
  end;

  procedure AssertAsmBindingStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterNEONBackend should still keep the asm-enabled binding source for ' + aLabel);
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the no-asm narrow F64 min/max wrapper only remains as a source companion for wider fallback graphs');
  end;
begin
  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  Exit;
  {$ENDIF}

  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LAutowrapSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.autowrap.inc');
    CheckTrue(FileExists(LAutowrapSourcePath), 'NEON scalar autowrap source should exist for implementation-shape audit: ' + LAutowrapSourcePath);
    LSourceLines.LoadFromFile(LAutowrapSourcePath);
    LAutowrapSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertScalarAlignedWrapper('NEONMaxF64x2', 'function NEONMaxF64x2(', 'Result := ScalarMaxF64x2(a, b);');
  AssertScalarAlignedWrapper('NEONMinF64x2', 'function NEONMinF64x2(', 'Result := ScalarMinF64x2(a, b);');
  AssertSourceConsumerStillPresent('NEONMaxF64x4', 'function NEONMaxF64x4(', 'Result.lo := NEONMaxF64x2(a.lo, b.lo);');
  AssertSourceConsumerStillPresent('NEONMinF64x4', 'function NEONMinF64x4(', 'Result.lo := NEONMinF64x2(a.lo, b.lo);');

  AssertAsmBindingStillPresent('MaxF64x2', 'table.CoreVectors.MaxF64x2 := @NEONMaxF64x2;');
  AssertAsmBindingStillPresent('MinF64x2', 'table.CoreVectors.MinF64x2 := @NEONMinF64x2;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('MaxF64x2', Pointer(LScalarTable.CoreVectors.MaxF64x2), Pointer(LNEONTable.CoreVectors.MaxF64x2));
  AssertSlotReusesScalar('MinF64x2', Pointer(LScalarTable.CoreVectors.MinF64x2), Pointer(LNEONTable.CoreVectors.MinF64x2));
end;

procedure TTestCase_DispatchAPI.Test_NEON_NoAsmNarrowF64SqrtSlots_Reuse_BaseScalar_When_Wrappers_Are_Dead;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LAutowrapSourcePath: string;
  LRegisterSource: string;
  LAutowrapSource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LAutowrapSource) = 0, aLabel + ' dead wrapper should be removed from the NEON scalar autowrap include');
  end;

  procedure AssertAsmBindingStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterNEONBackend should still keep the asm-enabled binding source for ' + aLabel);
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the no-asm narrow F64 sqrt wrapper has no standalone backend-local truth or wider source consumer');
  end;
begin
  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  Exit;
  {$ENDIF}

  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LAutowrapSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.autowrap.inc');
    CheckTrue(FileExists(LAutowrapSourcePath), 'NEON scalar autowrap source should exist for implementation-shape audit: ' + LAutowrapSourcePath);
    LSourceLines.LoadFromFile(LAutowrapSourcePath);
    LAutowrapSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('NEONSqrtF64x2', 'function NEONSqrtF64x2(');
  AssertDeadWrapperRemoved('NEONSqrtF64x4', 'function NEONSqrtF64x4(');

  AssertAsmBindingStillPresent('SqrtF64x2', 'table.CoreVectors.SqrtF64x2 := @NEONSqrtF64x2;');
  AssertAsmBindingStillPresent('SqrtF64x4', 'table.CoreVectors.SqrtF64x4 := @NEONSqrtF64x4;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('SqrtF64x2', Pointer(LScalarTable.CoreVectors.SqrtF64x2), Pointer(LNEONTable.CoreVectors.SqrtF64x2));
  AssertSlotReusesScalar('SqrtF64x4', Pointer(LScalarTable.CoreVectors.SqrtF64x4), Pointer(LNEONTable.CoreVectors.SqrtF64x4));
end;

procedure TTestCase_DispatchAPI.Test_NEON_NoAsmNarrowF64ExtremaReductionSlots_Reuse_BaseScalar_When_Wrappers_Have_No_SourceConsumers;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LAutowrapSourcePath: string;
  LRegisterSource: string;
  LAutowrapSource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LAutowrapSource) = 0, aLabel + ' dead wrapper should be removed from the NEON scalar autowrap include');
  end;

  procedure AssertAsmBindingStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterNEONBackend should still keep the asm-enabled binding source for ' + aLabel);
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the no-asm narrow F64 extrema reduction wrapper has no standalone backend-local truth or wider source consumer');
  end;
begin
  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  Exit;
  {$ENDIF}

  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LAutowrapSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.autowrap.inc');
    CheckTrue(FileExists(LAutowrapSourcePath), 'NEON scalar autowrap source should exist for implementation-shape audit: ' + LAutowrapSourcePath);
    LSourceLines.LoadFromFile(LAutowrapSourcePath);
    LAutowrapSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('NEONReduceMaxF64x2', 'function NEONReduceMaxF64x2(');
  AssertDeadWrapperRemoved('NEONReduceMinF64x2', 'function NEONReduceMinF64x2(');

  AssertAsmBindingStillPresent('ReduceMaxF64x2', 'table.CoreVectors.ReduceMaxF64x2 := @NEONReduceMaxF64x2;');
  AssertAsmBindingStillPresent('ReduceMinF64x2', 'table.CoreVectors.ReduceMinF64x2 := @NEONReduceMinF64x2;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('ReduceMaxF64x2', Pointer(LScalarTable.CoreVectors.ReduceMaxF64x2), Pointer(LNEONTable.CoreVectors.ReduceMaxF64x2));
  AssertSlotReusesScalar('ReduceMinF64x2', Pointer(LScalarTable.CoreVectors.ReduceMinF64x2), Pointer(LNEONTable.CoreVectors.ReduceMinF64x2));
end;

procedure TTestCase_DispatchAPI.Test_NEON_NoAsmNarrowF64RoundFamilySlots_Reuse_BaseScalar_When_Wrappers_Are_Dead;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LAutowrapSourcePath: string;
  LRegisterSource: string;
  LAutowrapSource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LAutowrapSource) = 0, aLabel + ' dead wrapper should be removed from the NEON scalar autowrap include once the local no-asm fallback is retired');
  end;

  procedure AssertAsmBindingStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterNEONBackend should still keep the asm-enabled binding source for ' + aLabel);
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the no-asm narrow F64 round-family wrapper has no standalone backend-local truth or live source consumer');
  end;
begin
  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  Exit;
  {$ENDIF}

  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LAutowrapSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.autowrap.inc');
    CheckTrue(FileExists(LAutowrapSourcePath), 'NEON scalar autowrap source should exist for implementation-shape audit: ' + LAutowrapSourcePath);
    LSourceLines.LoadFromFile(LAutowrapSourcePath);
    LAutowrapSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('NEONCeilF64x2', 'function NEONCeilF64x2(');
  AssertDeadWrapperRemoved('NEONFloorF64x2', 'function NEONFloorF64x2(');
  AssertDeadWrapperRemoved('NEONRoundF64x2', 'function NEONRoundF64x2(');
  AssertDeadWrapperRemoved('NEONTruncF64x2', 'function NEONTruncF64x2(');
  AssertDeadWrapperRemoved('NEONRoundF64x4', 'function NEONRoundF64x4(');
  AssertDeadWrapperRemoved('NEONTruncF64x4', 'function NEONTruncF64x4(');

  AssertAsmBindingStillPresent('CeilF64x2', 'table.CoreVectors.CeilF64x2 := @NEONCeilF64x2;');
  AssertAsmBindingStillPresent('FloorF64x2', 'table.CoreVectors.FloorF64x2 := @NEONFloorF64x2;');
  AssertAsmBindingStillPresent('RoundF64x2', 'table.CoreVectors.RoundF64x2 := @NEONRoundF64x2;');
  AssertAsmBindingStillPresent('TruncF64x2', 'table.CoreVectors.TruncF64x2 := @NEONTruncF64x2;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('CeilF64x2', Pointer(LScalarTable.CoreVectors.CeilF64x2), Pointer(LNEONTable.CoreVectors.CeilF64x2));
  AssertSlotReusesScalar('FloorF64x2', Pointer(LScalarTable.CoreVectors.FloorF64x2), Pointer(LNEONTable.CoreVectors.FloorF64x2));
  AssertSlotReusesScalar('RoundF64x2', Pointer(LScalarTable.CoreVectors.RoundF64x2), Pointer(LNEONTable.CoreVectors.RoundF64x2));
  AssertSlotReusesScalar('TruncF64x2', Pointer(LScalarTable.CoreVectors.TruncF64x2), Pointer(LNEONTable.CoreVectors.TruncF64x2));
end;

procedure TTestCase_DispatchAPI.Test_NEON_NoAsmWideSqrtSlots_Reuse_BaseScalar_When_Wrappers_Are_Dead;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LAutowrapSourcePath: string;
  LRegisterSource: string;
  LAutowrapSource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LAutowrapSource) = 0, aLabel + ' dead wrapper should be removed from the NEON scalar autowrap include');
  end;

  procedure AssertAsmBindingStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterNEONBackend should still keep the asm-enabled binding source for ' + aLabel);
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the no-asm wide sqrt wrapper is fully dead outside the asm-only publication path');
  end;
begin
  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  Exit;
  {$ENDIF}

  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LAutowrapSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.autowrap.inc');
    CheckTrue(FileExists(LAutowrapSourcePath), 'NEON scalar autowrap source should exist for implementation-shape audit: ' + LAutowrapSourcePath);
    LSourceLines.LoadFromFile(LAutowrapSourcePath);
    LAutowrapSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('NEONSqrtF32x16', 'function NEONSqrtF32x16(');
  AssertDeadWrapperRemoved('NEONSqrtF32x8', 'function NEONSqrtF32x8(');
  AssertDeadWrapperRemoved('NEONSqrtF64x4', 'function NEONSqrtF64x4(');
  AssertDeadWrapperRemoved('NEONSqrtF64x8', 'function NEONSqrtF64x8(');

  AssertAsmBindingStillPresent('SqrtF32x16', 'table.CoreVectors.SqrtF32x16 := @NEONSqrtF32x16;');
  AssertAsmBindingStillPresent('SqrtF32x8', 'table.CoreVectors.SqrtF32x8 := @NEONSqrtF32x8;');
  AssertAsmBindingStillPresent('SqrtF64x4', 'table.CoreVectors.SqrtF64x4 := @NEONSqrtF64x4;');
  AssertAsmBindingStillPresent('SqrtF64x8', 'table.CoreVectors.SqrtF64x8 := @NEONSqrtF64x8;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('SqrtF32x16', Pointer(LScalarTable.CoreVectors.SqrtF32x16), Pointer(LNEONTable.CoreVectors.SqrtF32x16));
  AssertSlotReusesScalar('SqrtF32x8', Pointer(LScalarTable.CoreVectors.SqrtF32x8), Pointer(LNEONTable.CoreVectors.SqrtF32x8));
  AssertSlotReusesScalar('SqrtF64x4', Pointer(LScalarTable.CoreVectors.SqrtF64x4), Pointer(LNEONTable.CoreVectors.SqrtF64x4));
  AssertSlotReusesScalar('SqrtF64x8', Pointer(LScalarTable.CoreVectors.SqrtF64x8), Pointer(LNEONTable.CoreVectors.SqrtF64x8));
end;

procedure TTestCase_DispatchAPI.Test_NEON_NoAsmWideRoundTruncSlots_Reuse_BaseScalar_When_Wrappers_Are_Dead;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LAutowrapSourcePath: string;
  LRegisterSource: string;
  LAutowrapSource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LAutowrapSource) = 0, aLabel + ' dead wrapper should be removed from the NEON scalar autowrap include');
  end;

  procedure AssertAsmBindingStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterNEONBackend should still keep the asm-enabled binding source for ' + aLabel);
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the no-asm wide round/trunc wrapper is fully dead outside the asm-only publication path');
  end;
begin
  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  Exit;
  {$ENDIF}

  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LAutowrapSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.autowrap.inc');
    CheckTrue(FileExists(LAutowrapSourcePath), 'NEON scalar autowrap source should exist for implementation-shape audit: ' + LAutowrapSourcePath);
    LSourceLines.LoadFromFile(LAutowrapSourcePath);
    LAutowrapSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('NEONRoundF32x8', 'function NEONRoundF32x8(');
  AssertDeadWrapperRemoved('NEONRoundF32x16', 'function NEONRoundF32x16(');
  AssertDeadWrapperRemoved('NEONRoundF64x4', 'function NEONRoundF64x4(');
  AssertDeadWrapperRemoved('NEONRoundF64x8', 'function NEONRoundF64x8(');
  AssertDeadWrapperRemoved('NEONTruncF32x8', 'function NEONTruncF32x8(');
  AssertDeadWrapperRemoved('NEONTruncF32x16', 'function NEONTruncF32x16(');
  AssertDeadWrapperRemoved('NEONTruncF64x4', 'function NEONTruncF64x4(');
  AssertDeadWrapperRemoved('NEONTruncF64x8', 'function NEONTruncF64x8(');

  AssertAsmBindingStillPresent('RoundF32x8', 'table.CoreVectors.RoundF32x8 := @NEONRoundF32x8;');
  AssertAsmBindingStillPresent('RoundF32x16', 'table.CoreVectors.RoundF32x16 := @NEONRoundF32x16;');
  AssertAsmBindingStillPresent('RoundF64x4', 'table.CoreVectors.RoundF64x4 := @NEONRoundF64x4;');
  AssertAsmBindingStillPresent('RoundF64x8', 'table.CoreVectors.RoundF64x8 := @NEONRoundF64x8;');
  AssertAsmBindingStillPresent('TruncF32x8', 'table.CoreVectors.TruncF32x8 := @NEONTruncF32x8;');
  AssertAsmBindingStillPresent('TruncF32x16', 'table.CoreVectors.TruncF32x16 := @NEONTruncF32x16;');
  AssertAsmBindingStillPresent('TruncF64x4', 'table.CoreVectors.TruncF64x4 := @NEONTruncF64x4;');
  AssertAsmBindingStillPresent('TruncF64x8', 'table.CoreVectors.TruncF64x8 := @NEONTruncF64x8;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('RoundF32x8', Pointer(LScalarTable.CoreVectors.RoundF32x8), Pointer(LNEONTable.CoreVectors.RoundF32x8));
  AssertSlotReusesScalar('RoundF32x16', Pointer(LScalarTable.CoreVectors.RoundF32x16), Pointer(LNEONTable.CoreVectors.RoundF32x16));
  AssertSlotReusesScalar('RoundF64x4', Pointer(LScalarTable.CoreVectors.RoundF64x4), Pointer(LNEONTable.CoreVectors.RoundF64x4));
  AssertSlotReusesScalar('RoundF64x8', Pointer(LScalarTable.CoreVectors.RoundF64x8), Pointer(LNEONTable.CoreVectors.RoundF64x8));
  AssertSlotReusesScalar('TruncF32x8', Pointer(LScalarTable.CoreVectors.TruncF32x8), Pointer(LNEONTable.CoreVectors.TruncF32x8));
  AssertSlotReusesScalar('TruncF32x16', Pointer(LScalarTable.CoreVectors.TruncF32x16), Pointer(LNEONTable.CoreVectors.TruncF32x16));
  AssertSlotReusesScalar('TruncF64x4', Pointer(LScalarTable.CoreVectors.TruncF64x4), Pointer(LNEONTable.CoreVectors.TruncF64x4));
  AssertSlotReusesScalar('TruncF64x8', Pointer(LScalarTable.CoreVectors.TruncF64x8), Pointer(LNEONTable.CoreVectors.TruncF64x8));
end;

procedure TTestCase_DispatchAPI.Test_NEON_NoAsmNarrowF64CompareAndSimpleReductionSlots_Reuse_BaseScalar_When_Wrappers_Have_No_SourceConsumers;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LAutowrapSourcePath: string;
  LRegisterSource: string;
  LAutowrapSource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LAutowrapSource) = 0, aLabel + ' dead wrapper should be removed from the NEON scalar autowrap include');
  end;

  procedure AssertAsmBindingStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterNEONBackend should still keep the asm-enabled binding source for ' + aLabel);
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the no-asm narrow F64 compare/reduction wrapper has no standalone backend-local truth or wider source consumer');
  end;
begin
  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  Exit;
  {$ENDIF}

  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LAutowrapSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.autowrap.inc');
    CheckTrue(FileExists(LAutowrapSourcePath), 'NEON scalar autowrap source should exist for implementation-shape audit: ' + LAutowrapSourcePath);
    LSourceLines.LoadFromFile(LAutowrapSourcePath);
    LAutowrapSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('NEONCmpEqF64x2', 'function NEONCmpEqF64x2(');
  AssertDeadWrapperRemoved('NEONCmpGeF64x2', 'function NEONCmpGeF64x2(');
  AssertDeadWrapperRemoved('NEONCmpGtF64x2', 'function NEONCmpGtF64x2(');
  AssertDeadWrapperRemoved('NEONCmpLeF64x2', 'function NEONCmpLeF64x2(');
  AssertDeadWrapperRemoved('NEONCmpLtF64x2', 'function NEONCmpLtF64x2(');
  AssertDeadWrapperRemoved('NEONCmpNeF64x2', 'function NEONCmpNeF64x2(');
  AssertDeadWrapperRemoved('NEONReduceAddF64x2', 'function NEONReduceAddF64x2(');
  AssertDeadWrapperRemoved('NEONReduceMulF64x2', 'function NEONReduceMulF64x2(');

  AssertAsmBindingStillPresent('CmpEqF64x2', 'table.CoreVectors.CmpEqF64x2 := @NEONCmpEqF64x2;');
  AssertAsmBindingStillPresent('CmpGeF64x2', 'table.CoreVectors.CmpGeF64x2 := @NEONCmpGeF64x2;');
  AssertAsmBindingStillPresent('CmpGtF64x2', 'table.CoreVectors.CmpGtF64x2 := @NEONCmpGtF64x2;');
  AssertAsmBindingStillPresent('CmpLeF64x2', 'table.CoreVectors.CmpLeF64x2 := @NEONCmpLeF64x2;');
  AssertAsmBindingStillPresent('CmpLtF64x2', 'table.CoreVectors.CmpLtF64x2 := @NEONCmpLtF64x2;');
  AssertAsmBindingStillPresent('CmpNeF64x2', 'table.CoreVectors.CmpNeF64x2 := @NEONCmpNeF64x2;');
  AssertAsmBindingStillPresent('ReduceAddF64x2', 'table.CoreVectors.ReduceAddF64x2 := @NEONReduceAddF64x2;');
  AssertAsmBindingStillPresent('ReduceMulF64x2', 'table.CoreVectors.ReduceMulF64x2 := @NEONReduceMulF64x2;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('CmpEqF64x2', Pointer(LScalarTable.CoreVectors.CmpEqF64x2), Pointer(LNEONTable.CoreVectors.CmpEqF64x2));
  AssertSlotReusesScalar('CmpGeF64x2', Pointer(LScalarTable.CoreVectors.CmpGeF64x2), Pointer(LNEONTable.CoreVectors.CmpGeF64x2));
  AssertSlotReusesScalar('CmpGtF64x2', Pointer(LScalarTable.CoreVectors.CmpGtF64x2), Pointer(LNEONTable.CoreVectors.CmpGtF64x2));
  AssertSlotReusesScalar('CmpLeF64x2', Pointer(LScalarTable.CoreVectors.CmpLeF64x2), Pointer(LNEONTable.CoreVectors.CmpLeF64x2));
  AssertSlotReusesScalar('CmpLtF64x2', Pointer(LScalarTable.CoreVectors.CmpLtF64x2), Pointer(LNEONTable.CoreVectors.CmpLtF64x2));
  AssertSlotReusesScalar('CmpNeF64x2', Pointer(LScalarTable.CoreVectors.CmpNeF64x2), Pointer(LNEONTable.CoreVectors.CmpNeF64x2));
  AssertSlotReusesScalar('ReduceAddF64x2', Pointer(LScalarTable.CoreVectors.ReduceAddF64x2), Pointer(LNEONTable.CoreVectors.ReduceAddF64x2));
  AssertSlotReusesScalar('ReduceMulF64x2', Pointer(LScalarTable.CoreVectors.ReduceMulF64x2), Pointer(LNEONTable.CoreVectors.ReduceMulF64x2));
end;

procedure TTestCase_DispatchAPI.Test_NEON_NoAsmWideClampSlots_Reuse_BaseScalar_For_F32_And_F64_When_NoAsm;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LAutowrapSourcePath: string;
  LRegisterSource: string;
  LAutowrapSource: string;
  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LAutowrapSource) = 0, aLabel + ' dead wrapper should be removed from the NEON scalar autowrap include');
  end;

  procedure AssertWrapperStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LAutowrapSource) > 0, aLabel + ' local fallback/source companion should remain in the NEON scalar autowrap include');
  end;

  procedure AssertAsmBindingStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterNEONBackend should still keep the asm-enabled binding source for ' + aLabel);
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the no-asm wide Clamp wrapper is not backend-owned');
  end;

  procedure AssertSlotKeepsBackendOwnership(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, 'NEON ' + aLabel + ' should stay assigned in the registered backend table');
    CheckTrue(aBackendSlot <> aScalarSlot, 'NEON ' + aLabel + ' should keep backend ownership when the asm leaf is compiled');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LAutowrapSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.autowrap.inc');
    CheckTrue(FileExists(LAutowrapSourcePath), 'NEON scalar autowrap source should exist for implementation-shape audit: ' + LAutowrapSourcePath);
    LSourceLines.LoadFromFile(LAutowrapSourcePath);
    LAutowrapSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('NEONClampF32x16', 'function NEONClampF32x16(');
  AssertDeadWrapperRemoved('NEONClampF32x8', 'function NEONClampF32x8(');
  AssertWrapperStillPresent('NEONClampF64x2', 'function NEONClampF64x2(');
  AssertWrapperStillPresent('NEONClampF64x4', 'function NEONClampF64x4(');
  AssertWrapperStillPresent('NEONClampF64x8', 'function NEONClampF64x8(');

  AssertAsmBindingStillPresent('ClampF32x16', 'table.CoreVectors.ClampF32x16 := @NEONClampF32x16;');
  AssertAsmBindingStillPresent('ClampF32x8', 'table.CoreVectors.ClampF32x8 := @NEONClampF32x8;');
  AssertAsmBindingStillPresent('ClampF64x2', 'table.CoreVectors.ClampF64x2 := @NEONClampF64x2;');
  AssertAsmBindingStillPresent('ClampF64x4', 'table.CoreVectors.ClampF64x4 := @NEONClampF64x4;');
  AssertAsmBindingStillPresent('ClampF64x8', 'table.CoreVectors.ClampF64x8 := @NEONClampF64x8;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('ClampF32x16', Pointer(LScalarTable.CoreVectors.ClampF32x16), Pointer(LNEONTable.CoreVectors.ClampF32x16));
  AssertSlotReusesScalar('ClampF32x8', Pointer(LScalarTable.CoreVectors.ClampF32x8), Pointer(LNEONTable.CoreVectors.ClampF32x8));
  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  AssertSlotKeepsBackendOwnership('ClampF64x2', Pointer(LScalarTable.CoreVectors.ClampF64x2), Pointer(LNEONTable.CoreVectors.ClampF64x2));
  AssertSlotKeepsBackendOwnership('ClampF64x4', Pointer(LScalarTable.CoreVectors.ClampF64x4), Pointer(LNEONTable.CoreVectors.ClampF64x4));
  AssertSlotKeepsBackendOwnership('ClampF64x8', Pointer(LScalarTable.CoreVectors.ClampF64x8), Pointer(LNEONTable.CoreVectors.ClampF64x8));
  {$ELSE}
  AssertSlotReusesScalar('ClampF64x2', Pointer(LScalarTable.CoreVectors.ClampF64x2), Pointer(LNEONTable.CoreVectors.ClampF64x2));
  AssertSlotReusesScalar('ClampF64x4', Pointer(LScalarTable.CoreVectors.ClampF64x4), Pointer(LNEONTable.CoreVectors.ClampF64x4));
  AssertSlotReusesScalar('ClampF64x8', Pointer(LScalarTable.CoreVectors.ClampF64x8), Pointer(LNEONTable.CoreVectors.ClampF64x8));
  {$ENDIF}
end;

procedure TTestCase_DispatchAPI.Test_NEON_NoAsmAbsAndWideFloorCeilSlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LAutowrapSourcePath: string;
  LRegisterSource: string;
  LAutowrapSource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LAutowrapSource) = 0, aLabel + ' dead wrapper should be removed from the NEON scalar autowrap include');
  end;

  procedure AssertRegisterKeepsBaseScalar(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0, 'RegisterNEONBackend should keep base scalar ' + aLabel + ' when the no-asm NEON wrapper is only a scalar forwarder');
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the no-asm NEON wrapper is only a scalar forwarder');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LAutowrapSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.autowrap.inc');
    CheckTrue(FileExists(LAutowrapSourcePath), 'NEON scalar autowrap source should exist for implementation-shape audit: ' + LAutowrapSourcePath);
    LSourceLines.LoadFromFile(LAutowrapSourcePath);
    LAutowrapSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('NEONAbsF32x16', 'function NEONAbsF32x16(');
  AssertDeadWrapperRemoved('NEONAbsF32x8', 'function NEONAbsF32x8(');
  AssertDeadWrapperRemoved('NEONAbsF64x2', 'function NEONAbsF64x2(');
  AssertDeadWrapperRemoved('NEONAbsF64x4', 'function NEONAbsF64x4(');
  AssertDeadWrapperRemoved('NEONAbsF64x8', 'function NEONAbsF64x8(');
  AssertDeadWrapperRemoved('NEONCeilF32x16', 'function NEONCeilF32x16(');
  AssertDeadWrapperRemoved('NEONCeilF32x8', 'function NEONCeilF32x8(');
  AssertDeadWrapperRemoved('NEONCeilF64x4', 'function NEONCeilF64x4(');
  AssertDeadWrapperRemoved('NEONCeilF64x8', 'function NEONCeilF64x8(');
  AssertDeadWrapperRemoved('NEONFloorF32x16', 'function NEONFloorF32x16(');
  AssertDeadWrapperRemoved('NEONFloorF32x8', 'function NEONFloorF32x8(');
  AssertDeadWrapperRemoved('NEONFloorF64x4', 'function NEONFloorF64x4(');
  AssertDeadWrapperRemoved('NEONFloorF64x8', 'function NEONFloorF64x8(');

  AssertRegisterKeepsBaseScalar('AbsF32x16', 'table.CoreVectors.AbsF32x16 := @NEONAbsF32x16;');
  AssertRegisterKeepsBaseScalar('AbsF32x8', 'table.CoreVectors.AbsF32x8 := @NEONAbsF32x8;');
  AssertRegisterKeepsBaseScalar('AbsF64x2', 'table.CoreVectors.AbsF64x2 := @NEONAbsF64x2;');
  AssertRegisterKeepsBaseScalar('AbsF64x4', 'table.CoreVectors.AbsF64x4 := @NEONAbsF64x4;');
  AssertRegisterKeepsBaseScalar('AbsF64x8', 'table.CoreVectors.AbsF64x8 := @NEONAbsF64x8;');
  AssertRegisterKeepsBaseScalar('CeilF32x16', 'table.CoreVectors.CeilF32x16 := @NEONCeilF32x16;');
  AssertRegisterKeepsBaseScalar('CeilF32x8', 'table.CoreVectors.CeilF32x8 := @NEONCeilF32x8;');
  AssertRegisterKeepsBaseScalar('CeilF64x4', 'table.CoreVectors.CeilF64x4 := @NEONCeilF64x4;');
  AssertRegisterKeepsBaseScalar('CeilF64x8', 'table.CoreVectors.CeilF64x8 := @NEONCeilF64x8;');
  AssertRegisterKeepsBaseScalar('FloorF32x16', 'table.CoreVectors.FloorF32x16 := @NEONFloorF32x16;');
  AssertRegisterKeepsBaseScalar('FloorF32x8', 'table.CoreVectors.FloorF32x8 := @NEONFloorF32x8;');
  AssertRegisterKeepsBaseScalar('FloorF64x4', 'table.CoreVectors.FloorF64x4 := @NEONFloorF64x4;');
  AssertRegisterKeepsBaseScalar('FloorF64x8', 'table.CoreVectors.FloorF64x8 := @NEONFloorF64x8;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('AbsF32x16', Pointer(LScalarTable.CoreVectors.AbsF32x16), Pointer(LNEONTable.CoreVectors.AbsF32x16));
  AssertSlotReusesScalar('AbsF32x8', Pointer(LScalarTable.CoreVectors.AbsF32x8), Pointer(LNEONTable.CoreVectors.AbsF32x8));
  AssertSlotReusesScalar('AbsF64x2', Pointer(LScalarTable.CoreVectors.AbsF64x2), Pointer(LNEONTable.CoreVectors.AbsF64x2));
  AssertSlotReusesScalar('AbsF64x4', Pointer(LScalarTable.CoreVectors.AbsF64x4), Pointer(LNEONTable.CoreVectors.AbsF64x4));
  AssertSlotReusesScalar('AbsF64x8', Pointer(LScalarTable.CoreVectors.AbsF64x8), Pointer(LNEONTable.CoreVectors.AbsF64x8));
  AssertSlotReusesScalar('CeilF32x16', Pointer(LScalarTable.CoreVectors.CeilF32x16), Pointer(LNEONTable.CoreVectors.CeilF32x16));
  AssertSlotReusesScalar('CeilF32x8', Pointer(LScalarTable.CoreVectors.CeilF32x8), Pointer(LNEONTable.CoreVectors.CeilF32x8));
  AssertSlotReusesScalar('CeilF64x4', Pointer(LScalarTable.CoreVectors.CeilF64x4), Pointer(LNEONTable.CoreVectors.CeilF64x4));
  AssertSlotReusesScalar('CeilF64x8', Pointer(LScalarTable.CoreVectors.CeilF64x8), Pointer(LNEONTable.CoreVectors.CeilF64x8));
  AssertSlotReusesScalar('FloorF32x16', Pointer(LScalarTable.CoreVectors.FloorF32x16), Pointer(LNEONTable.CoreVectors.FloorF32x16));
  AssertSlotReusesScalar('FloorF32x8', Pointer(LScalarTable.CoreVectors.FloorF32x8), Pointer(LNEONTable.CoreVectors.FloorF32x8));
  AssertSlotReusesScalar('FloorF64x4', Pointer(LScalarTable.CoreVectors.FloorF64x4), Pointer(LNEONTable.CoreVectors.FloorF64x4));
  AssertSlotReusesScalar('FloorF64x8', Pointer(LScalarTable.CoreVectors.FloorF64x8), Pointer(LNEONTable.CoreVectors.FloorF64x8));
end;

procedure TTestCase_DispatchAPI.Test_NEON_MaskHelperSlots_Bind_SharedMask_Without_DeadNEONWrappers;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LUtilitySourcePath: string;
  LRegisterSource: string;
  LUtilitySource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LUtilitySource) = 0, aLabel + ' dead wrapper should stay removed from the NEON scalar utility include');
  end;

  procedure AssertRegisterForbidsDeadNEONMask(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0, 'RegisterNEONBackend must not bind dead NEONMask* wrappers for ' + aLabel);
  end;

  procedure AssertRegisterBindsSharedMask(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterNEONBackend should bind SharedMask for ' + aLabel);
  end;

  procedure AssertSlotNotScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, 'NEON ' + aLabel + ' should be assigned');
    CheckTrue(PtrUInt(aBackendSlot) <> PtrUInt(aScalarSlot), 'NEON ' + aLabel + ' should own SharedMask rather than reuse the base scalar slot');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LUtilitySourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.utility.inc');
    CheckTrue(FileExists(LUtilitySourcePath), 'NEON scalar utility source should exist for implementation-shape audit: ' + LUtilitySourcePath);
    LSourceLines.LoadFromFile(LUtilitySourcePath);
    LUtilitySource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('NEONMask2All', 'function NEONMask2All(');
  AssertDeadWrapperRemoved('NEONMask2Any', 'function NEONMask2Any(');
  AssertDeadWrapperRemoved('NEONMask2None', 'function NEONMask2None(');
  AssertDeadWrapperRemoved('NEONMask2PopCount', 'function NEONMask2PopCount(');
  AssertDeadWrapperRemoved('NEONMask2FirstSet', 'function NEONMask2FirstSet(');
  AssertDeadWrapperRemoved('NEONMask4All', 'function NEONMask4All(');
  AssertDeadWrapperRemoved('NEONMask4Any', 'function NEONMask4Any(');
  AssertDeadWrapperRemoved('NEONMask4None', 'function NEONMask4None(');
  AssertDeadWrapperRemoved('NEONMask4PopCount', 'function NEONMask4PopCount(');
  AssertDeadWrapperRemoved('NEONMask4FirstSet', 'function NEONMask4FirstSet(');
  AssertDeadWrapperRemoved('NEONMask8All', 'function NEONMask8All(');
  AssertDeadWrapperRemoved('NEONMask8Any', 'function NEONMask8Any(');
  AssertDeadWrapperRemoved('NEONMask8None', 'function NEONMask8None(');
  AssertDeadWrapperRemoved('NEONMask8PopCount', 'function NEONMask8PopCount(');
  AssertDeadWrapperRemoved('NEONMask8FirstSet', 'function NEONMask8FirstSet(');
  AssertDeadWrapperRemoved('NEONMask16All', 'function NEONMask16All(');
  AssertDeadWrapperRemoved('NEONMask16Any', 'function NEONMask16Any(');
  AssertDeadWrapperRemoved('NEONMask16None', 'function NEONMask16None(');
  AssertDeadWrapperRemoved('NEONMask16PopCount', 'function NEONMask16PopCount(');
  AssertDeadWrapperRemoved('NEONMask16FirstSet', 'function NEONMask16FirstSet(');

  AssertRegisterForbidsDeadNEONMask('Mask2All', 'table.Mask.Mask2All := @NEONMask2All;');
  AssertRegisterForbidsDeadNEONMask('Mask2Any', 'table.Mask.Mask2Any := @NEONMask2Any;');
  AssertRegisterForbidsDeadNEONMask('Mask2None', 'table.Mask.Mask2None := @NEONMask2None;');
  AssertRegisterForbidsDeadNEONMask('Mask2PopCount', 'table.Mask.Mask2PopCount := @NEONMask2PopCount;');
  AssertRegisterForbidsDeadNEONMask('Mask2FirstSet', 'table.Mask.Mask2FirstSet := @NEONMask2FirstSet;');
  AssertRegisterForbidsDeadNEONMask('Mask4All', 'table.Mask.Mask4All := @NEONMask4All;');
  AssertRegisterForbidsDeadNEONMask('Mask4Any', 'table.Mask.Mask4Any := @NEONMask4Any;');
  AssertRegisterForbidsDeadNEONMask('Mask4None', 'table.Mask.Mask4None := @NEONMask4None;');
  AssertRegisterForbidsDeadNEONMask('Mask4PopCount', 'table.Mask.Mask4PopCount := @NEONMask4PopCount;');
  AssertRegisterForbidsDeadNEONMask('Mask4FirstSet', 'table.Mask.Mask4FirstSet := @NEONMask4FirstSet;');
  AssertRegisterForbidsDeadNEONMask('Mask8All', 'table.Mask.Mask8All := @NEONMask8All;');
  AssertRegisterForbidsDeadNEONMask('Mask8Any', 'table.Mask.Mask8Any := @NEONMask8Any;');
  AssertRegisterForbidsDeadNEONMask('Mask8None', 'table.Mask.Mask8None := @NEONMask8None;');
  AssertRegisterForbidsDeadNEONMask('Mask8PopCount', 'table.Mask.Mask8PopCount := @NEONMask8PopCount;');
  AssertRegisterForbidsDeadNEONMask('Mask8FirstSet', 'table.Mask.Mask8FirstSet := @NEONMask8FirstSet;');
  AssertRegisterForbidsDeadNEONMask('Mask16All', 'table.Mask.Mask16All := @NEONMask16All;');
  AssertRegisterForbidsDeadNEONMask('Mask16Any', 'table.Mask.Mask16Any := @NEONMask16Any;');
  AssertRegisterForbidsDeadNEONMask('Mask16None', 'table.Mask.Mask16None := @NEONMask16None;');
  AssertRegisterForbidsDeadNEONMask('Mask16PopCount', 'table.Mask.Mask16PopCount := @NEONMask16PopCount;');
  AssertRegisterForbidsDeadNEONMask('Mask16FirstSet', 'table.Mask.Mask16FirstSet := @NEONMask16FirstSet;');

  AssertRegisterBindsSharedMask('Mask2All', 'table.Mask.Mask2All := @SharedMask2All;');
  AssertRegisterBindsSharedMask('Mask2Any', 'table.Mask.Mask2Any := @SharedMask2Any;');
  AssertRegisterBindsSharedMask('Mask2None', 'table.Mask.Mask2None := @SharedMask2None;');
  AssertRegisterBindsSharedMask('Mask2PopCount', 'table.Mask.Mask2PopCount := @SharedMask2PopCount;');
  AssertRegisterBindsSharedMask('Mask2FirstSet', 'table.Mask.Mask2FirstSet := @SharedMask2FirstSet;');
  AssertRegisterBindsSharedMask('Mask4All', 'table.Mask.Mask4All := @SharedMask4All;');
  AssertRegisterBindsSharedMask('Mask4Any', 'table.Mask.Mask4Any := @SharedMask4Any;');
  AssertRegisterBindsSharedMask('Mask4None', 'table.Mask.Mask4None := @SharedMask4None;');
  AssertRegisterBindsSharedMask('Mask4PopCount', 'table.Mask.Mask4PopCount := @SharedMask4PopCount;');
  AssertRegisterBindsSharedMask('Mask4FirstSet', 'table.Mask.Mask4FirstSet := @SharedMask4FirstSet;');
  AssertRegisterBindsSharedMask('Mask8All', 'table.Mask.Mask8All := @SharedMask8All;');
  AssertRegisterBindsSharedMask('Mask8Any', 'table.Mask.Mask8Any := @SharedMask8Any;');
  AssertRegisterBindsSharedMask('Mask8None', 'table.Mask.Mask8None := @SharedMask8None;');
  AssertRegisterBindsSharedMask('Mask8PopCount', 'table.Mask.Mask8PopCount := @SharedMask8PopCount;');
  AssertRegisterBindsSharedMask('Mask8FirstSet', 'table.Mask.Mask8FirstSet := @SharedMask8FirstSet;');
  AssertRegisterBindsSharedMask('Mask16All', 'table.Mask.Mask16All := @SharedMask16All;');
  AssertRegisterBindsSharedMask('Mask16Any', 'table.Mask.Mask16Any := @SharedMask16Any;');
  AssertRegisterBindsSharedMask('Mask16None', 'table.Mask.Mask16None := @SharedMask16None;');
  AssertRegisterBindsSharedMask('Mask16PopCount', 'table.Mask.Mask16PopCount := @SharedMask16PopCount;');
  AssertRegisterBindsSharedMask('Mask16FirstSet', 'table.Mask.Mask16FirstSet := @SharedMask16FirstSet;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotNotScalar('Mask2All', Pointer(LScalarTable.Mask.Mask2All), Pointer(LNEONTable.Mask.Mask2All));
  AssertSlotNotScalar('Mask2Any', Pointer(LScalarTable.Mask.Mask2Any), Pointer(LNEONTable.Mask.Mask2Any));
  AssertSlotNotScalar('Mask2None', Pointer(LScalarTable.Mask.Mask2None), Pointer(LNEONTable.Mask.Mask2None));
  AssertSlotNotScalar('Mask2PopCount', Pointer(LScalarTable.Mask.Mask2PopCount), Pointer(LNEONTable.Mask.Mask2PopCount));
  AssertSlotNotScalar('Mask2FirstSet', Pointer(LScalarTable.Mask.Mask2FirstSet), Pointer(LNEONTable.Mask.Mask2FirstSet));
  AssertSlotNotScalar('Mask4All', Pointer(LScalarTable.Mask.Mask4All), Pointer(LNEONTable.Mask.Mask4All));
  AssertSlotNotScalar('Mask4Any', Pointer(LScalarTable.Mask.Mask4Any), Pointer(LNEONTable.Mask.Mask4Any));
  AssertSlotNotScalar('Mask4None', Pointer(LScalarTable.Mask.Mask4None), Pointer(LNEONTable.Mask.Mask4None));
  AssertSlotNotScalar('Mask4PopCount', Pointer(LScalarTable.Mask.Mask4PopCount), Pointer(LNEONTable.Mask.Mask4PopCount));
  AssertSlotNotScalar('Mask4FirstSet', Pointer(LScalarTable.Mask.Mask4FirstSet), Pointer(LNEONTable.Mask.Mask4FirstSet));
  AssertSlotNotScalar('Mask8All', Pointer(LScalarTable.Mask.Mask8All), Pointer(LNEONTable.Mask.Mask8All));
  AssertSlotNotScalar('Mask8Any', Pointer(LScalarTable.Mask.Mask8Any), Pointer(LNEONTable.Mask.Mask8Any));
  AssertSlotNotScalar('Mask8None', Pointer(LScalarTable.Mask.Mask8None), Pointer(LNEONTable.Mask.Mask8None));
  AssertSlotNotScalar('Mask8PopCount', Pointer(LScalarTable.Mask.Mask8PopCount), Pointer(LNEONTable.Mask.Mask8PopCount));
  AssertSlotNotScalar('Mask8FirstSet', Pointer(LScalarTable.Mask.Mask8FirstSet), Pointer(LNEONTable.Mask.Mask8FirstSet));
  AssertSlotNotScalar('Mask16All', Pointer(LScalarTable.Mask.Mask16All), Pointer(LNEONTable.Mask.Mask16All));
  AssertSlotNotScalar('Mask16Any', Pointer(LScalarTable.Mask.Mask16Any), Pointer(LNEONTable.Mask.Mask16Any));
  AssertSlotNotScalar('Mask16None', Pointer(LScalarTable.Mask.Mask16None), Pointer(LNEONTable.Mask.Mask16None));
  AssertSlotNotScalar('Mask16PopCount', Pointer(LScalarTable.Mask.Mask16PopCount), Pointer(LNEONTable.Mask.Mask16PopCount));
  AssertSlotNotScalar('Mask16FirstSet', Pointer(LScalarTable.Mask.Mask16FirstSet), Pointer(LNEONTable.Mask.Mask16FirstSet));
end;

procedure TTestCase_DispatchAPI.Test_NEON_BackendCapabilities_Expose_MaskedOps_When_MaskSlots_AreShared;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  CheckTrue(Assigned(LNEONTable.Mask.Mask2All), 'NEON Mask2All should be assigned');
  CheckTrue(Assigned(LNEONTable.Mask.Mask4PopCount), 'NEON Mask4PopCount should be assigned');
  CheckTrue(Assigned(LNEONTable.Mask.Mask16FirstSet), 'NEON Mask16FirstSet should be assigned');
  CheckTrue(
    (Pointer(LNEONTable.Mask.Mask2All) <> Pointer(LScalarTable.Mask.Mask2All)) or
    (Pointer(LNEONTable.Mask.Mask4PopCount) <> Pointer(LScalarTable.Mask.Mask4PopCount)) or
    (Pointer(LNEONTable.Mask.Mask16FirstSet) <> Pointer(LScalarTable.Mask.Mask16FirstSet)),
    'Representative NEON mask helper slots should own SharedMask rather than scalar baseline');
  CheckTrue(scMaskedOps in LNEONTable.BackendInfo.Capabilities, 'NEON should advertise scMaskedOps when Mask slots own SharedMask');
end;

procedure TTestCase_DispatchAPI.Test_NEON_NoAsmWideIntegerCompareSlots_Keep_SourceCompanions_But_Reuse_BaseScalar;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LAutowrapSourcePath: string;
  LRegisterSource: string;
  LAutowrapSource: string;

  procedure AssertSourceCompanionStillPresent(const aLabel, aSignatureSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSignatureSnippet), LAutowrapSource) > 0, aLabel + ' source companion should remain in the NEON scalar autowrap include');
  end;

  procedure AssertSourceCompositionStillPresent(const aLabel, aBodySnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aBodySnippet), LAutowrapSource) > 0, aLabel + ' should still compose narrower compare helpers in the NEON scalar autowrap include');
  end;

  procedure AssertAsmBindingStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterNEONBackend should still keep the asm-enabled binding source for ' + aLabel);
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when the no-asm wide integer compare wrapper only remains as a source companion for narrower helper composition');
  end;
begin
  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  Exit;
  {$ENDIF}

  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LAutowrapSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.autowrap.inc');
    CheckTrue(FileExists(LAutowrapSourcePath), 'NEON scalar autowrap source should exist for implementation-shape audit: ' + LAutowrapSourcePath);
    LSourceLines.LoadFromFile(LAutowrapSourcePath);
    LAutowrapSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertSourceCompanionStillPresent('NEONCmpEqI32x16', 'function NEONCmpEqI32x16(');
  AssertSourceCompanionStillPresent('NEONCmpEqI32x8', 'function NEONCmpEqI32x8(');
  AssertSourceCompanionStillPresent('NEONCmpEqI64x4', 'function NEONCmpEqI64x4(');
  AssertSourceCompanionStillPresent('NEONCmpEqI64x8', 'function NEONCmpEqI64x8(');
  AssertSourceCompanionStillPresent('NEONCmpEqU32x8', 'function NEONCmpEqU32x8(');
  AssertSourceCompanionStillPresent('NEONCmpEqU64x4', 'function NEONCmpEqU64x4(');
  AssertSourceCompanionStillPresent('NEONCmpGeI32x16', 'function NEONCmpGeI32x16(');
  AssertSourceCompanionStillPresent('NEONCmpGeI32x8', 'function NEONCmpGeI32x8(');
  AssertSourceCompanionStillPresent('NEONCmpGeI64x4', 'function NEONCmpGeI64x4(');
  AssertSourceCompanionStillPresent('NEONCmpGeI64x8', 'function NEONCmpGeI64x8(');
  AssertSourceCompanionStillPresent('NEONCmpGeU32x8', 'function NEONCmpGeU32x8(');
  AssertSourceCompanionStillPresent('NEONCmpGeU64x4', 'function NEONCmpGeU64x4(');
  AssertSourceCompanionStillPresent('NEONCmpGtI32x16', 'function NEONCmpGtI32x16(');
  AssertSourceCompanionStillPresent('NEONCmpGtI32x8', 'function NEONCmpGtI32x8(');
  AssertSourceCompanionStillPresent('NEONCmpGtI64x4', 'function NEONCmpGtI64x4(');
  AssertSourceCompanionStillPresent('NEONCmpGtI64x8', 'function NEONCmpGtI64x8(');
  AssertSourceCompanionStillPresent('NEONCmpGtU32x8', 'function NEONCmpGtU32x8(');
  AssertSourceCompanionStillPresent('NEONCmpGtU64x4', 'function NEONCmpGtU64x4(');
  AssertSourceCompanionStillPresent('NEONCmpLeI32x16', 'function NEONCmpLeI32x16(');
  AssertSourceCompanionStillPresent('NEONCmpLeI32x8', 'function NEONCmpLeI32x8(');
  AssertSourceCompanionStillPresent('NEONCmpLeI64x4', 'function NEONCmpLeI64x4(');
  AssertSourceCompanionStillPresent('NEONCmpLeI64x8', 'function NEONCmpLeI64x8(');
  AssertSourceCompanionStillPresent('NEONCmpLeU32x8', 'function NEONCmpLeU32x8(');
  AssertSourceCompanionStillPresent('NEONCmpLeU64x4', 'function NEONCmpLeU64x4(');
  AssertSourceCompanionStillPresent('NEONCmpLtI32x16', 'function NEONCmpLtI32x16(');
  AssertSourceCompanionStillPresent('NEONCmpLtI32x8', 'function NEONCmpLtI32x8(');
  AssertSourceCompanionStillPresent('NEONCmpLtI64x4', 'function NEONCmpLtI64x4(');
  AssertSourceCompanionStillPresent('NEONCmpLtI64x8', 'function NEONCmpLtI64x8(');
  AssertSourceCompanionStillPresent('NEONCmpLtU32x8', 'function NEONCmpLtU32x8(');
  AssertSourceCompanionStillPresent('NEONCmpLtU64x4', 'function NEONCmpLtU64x4(');
  AssertSourceCompanionStillPresent('NEONCmpNeI32x16', 'function NEONCmpNeI32x16(');
  AssertSourceCompanionStillPresent('NEONCmpNeI32x8', 'function NEONCmpNeI32x8(');
  AssertSourceCompanionStillPresent('NEONCmpNeI64x4', 'function NEONCmpNeI64x4(');
  AssertSourceCompanionStillPresent('NEONCmpNeI64x8', 'function NEONCmpNeI64x8(');
  AssertSourceCompanionStillPresent('NEONCmpNeU32x8', 'function NEONCmpNeU32x8(');
  AssertSourceCompanionStillPresent('NEONCmpNeU64x4', 'function NEONCmpNeU64x4(');

  AssertSourceCompositionStillPresent('NEONCmpEqI32x16', 'Result := NEONCombineMask8To16(NEONCmpEqI32x8(a.lo, b.lo), NEONCmpEqI32x8(a.hi, b.hi));');
  AssertSourceCompositionStillPresent('NEONCmpEqI32x8', 'Result := NEONCombineMask4To8(NEONCmpEqI32x4(a.lo, b.lo), NEONCmpEqI32x4(a.hi, b.hi));');
  AssertSourceCompositionStillPresent('NEONCmpEqI64x4', 'Result := NEONCombineMask2To4(NEONCmpEqI64x2(a.lo, b.lo), NEONCmpEqI64x2(a.hi, b.hi));');
  AssertSourceCompositionStillPresent('NEONCmpEqI64x8', 'Result := NEONCombineMask4To8(NEONCmpEqI64x4(a.lo, b.lo), NEONCmpEqI64x4(a.hi, b.hi));');
  AssertSourceCompositionStillPresent('NEONCmpEqU32x8', 'Result := NEONCombineMask4To8(NEONCmpEqU32x4(a.lo, b.lo), NEONCmpEqU32x4(a.hi, b.hi));');
  AssertSourceCompositionStillPresent('NEONCmpEqU64x4', 'Result := NEONCombineMask2To4(NEONCmpEqU64x2(a.lo, b.lo), NEONCmpEqU64x2(a.hi, b.hi));');
  AssertSourceCompositionStillPresent('NEONCmpGeU64x4', 'TMask2(Byte(MASK2_ALL_SET) xor Byte(NEONCmpLtU64x2(a.lo, b.lo)))');

  AssertAsmBindingStillPresent('CmpEqI32x16', 'table.CoreVectors.CmpEqI32x16 := @NEONCmpEqI32x16;');
  AssertAsmBindingStillPresent('CmpEqI32x8', 'table.CoreVectors.CmpEqI32x8 := @NEONCmpEqI32x8;');
  AssertAsmBindingStillPresent('CmpEqI64x4', 'table.CoreVectors.CmpEqI64x4 := @NEONCmpEqI64x4;');
  AssertAsmBindingStillPresent('CmpEqI64x8', 'table.CoreVectors.CmpEqI64x8 := @NEONCmpEqI64x8;');
  AssertAsmBindingStillPresent('CmpEqU32x8', 'table.CoreVectors.CmpEqU32x8 := @NEONCmpEqU32x8;');
  AssertAsmBindingStillPresent('CmpEqU64x4', 'table.CoreVectors.CmpEqU64x4 := @NEONCmpEqU64x4;');
  AssertAsmBindingStillPresent('CmpGeI32x16', 'table.CoreVectors.CmpGeI32x16 := @NEONCmpGeI32x16;');
  AssertAsmBindingStillPresent('CmpGeI32x8', 'table.CoreVectors.CmpGeI32x8 := @NEONCmpGeI32x8;');
  AssertAsmBindingStillPresent('CmpGeI64x4', 'table.CoreVectors.CmpGeI64x4 := @NEONCmpGeI64x4;');
  AssertAsmBindingStillPresent('CmpGeI64x8', 'table.CoreVectors.CmpGeI64x8 := @NEONCmpGeI64x8;');
  AssertAsmBindingStillPresent('CmpGeU32x8', 'table.CoreVectors.CmpGeU32x8 := @NEONCmpGeU32x8;');
  AssertAsmBindingStillPresent('CmpGeU64x4', 'table.CoreVectors.CmpGeU64x4 := @NEONCmpGeU64x4;');
  AssertAsmBindingStillPresent('CmpGtI32x16', 'table.CoreVectors.CmpGtI32x16 := @NEONCmpGtI32x16;');
  AssertAsmBindingStillPresent('CmpGtI32x8', 'table.CoreVectors.CmpGtI32x8 := @NEONCmpGtI32x8;');
  AssertAsmBindingStillPresent('CmpGtI64x4', 'table.CoreVectors.CmpGtI64x4 := @NEONCmpGtI64x4;');
  AssertAsmBindingStillPresent('CmpGtI64x8', 'table.CoreVectors.CmpGtI64x8 := @NEONCmpGtI64x8;');
  AssertAsmBindingStillPresent('CmpGtU32x8', 'table.CoreVectors.CmpGtU32x8 := @NEONCmpGtU32x8;');
  AssertAsmBindingStillPresent('CmpGtU64x4', 'table.CoreVectors.CmpGtU64x4 := @NEONCmpGtU64x4;');
  AssertAsmBindingStillPresent('CmpLeI32x16', 'table.CoreVectors.CmpLeI32x16 := @NEONCmpLeI32x16;');
  AssertAsmBindingStillPresent('CmpLeI32x8', 'table.CoreVectors.CmpLeI32x8 := @NEONCmpLeI32x8;');
  AssertAsmBindingStillPresent('CmpLeI64x4', 'table.CoreVectors.CmpLeI64x4 := @NEONCmpLeI64x4;');
  AssertAsmBindingStillPresent('CmpLeI64x8', 'table.CoreVectors.CmpLeI64x8 := @NEONCmpLeI64x8;');
  AssertAsmBindingStillPresent('CmpLeU32x8', 'table.CoreVectors.CmpLeU32x8 := @NEONCmpLeU32x8;');
  AssertAsmBindingStillPresent('CmpLeU64x4', 'table.CoreVectors.CmpLeU64x4 := @NEONCmpLeU64x4;');
  AssertAsmBindingStillPresent('CmpLtI32x16', 'table.CoreVectors.CmpLtI32x16 := @NEONCmpLtI32x16;');
  AssertAsmBindingStillPresent('CmpLtI32x8', 'table.CoreVectors.CmpLtI32x8 := @NEONCmpLtI32x8;');
  AssertAsmBindingStillPresent('CmpLtI64x4', 'table.CoreVectors.CmpLtI64x4 := @NEONCmpLtI64x4;');
  AssertAsmBindingStillPresent('CmpLtI64x8', 'table.CoreVectors.CmpLtI64x8 := @NEONCmpLtI64x8;');
  AssertAsmBindingStillPresent('CmpLtU32x8', 'table.CoreVectors.CmpLtU32x8 := @NEONCmpLtU32x8;');
  AssertAsmBindingStillPresent('CmpLtU64x4', 'table.CoreVectors.CmpLtU64x4 := @NEONCmpLtU64x4;');
  AssertAsmBindingStillPresent('CmpNeI32x16', 'table.CoreVectors.CmpNeI32x16 := @NEONCmpNeI32x16;');
  AssertAsmBindingStillPresent('CmpNeI32x8', 'table.CoreVectors.CmpNeI32x8 := @NEONCmpNeI32x8;');
  AssertAsmBindingStillPresent('CmpNeI64x4', 'table.CoreVectors.CmpNeI64x4 := @NEONCmpNeI64x4;');
  AssertAsmBindingStillPresent('CmpNeI64x8', 'table.CoreVectors.CmpNeI64x8 := @NEONCmpNeI64x8;');
  AssertAsmBindingStillPresent('CmpNeU32x8', 'table.CoreVectors.CmpNeU32x8 := @NEONCmpNeU32x8;');
  AssertAsmBindingStillPresent('CmpNeU64x4', 'table.CoreVectors.CmpNeU64x4 := @NEONCmpNeU64x4;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('CmpEqI32x16', Pointer(LScalarTable.CoreVectors.CmpEqI32x16), Pointer(LNEONTable.CoreVectors.CmpEqI32x16));
  AssertSlotReusesScalar('CmpEqI32x8', Pointer(LScalarTable.CoreVectors.CmpEqI32x8), Pointer(LNEONTable.CoreVectors.CmpEqI32x8));
  AssertSlotReusesScalar('CmpEqI64x4', Pointer(LScalarTable.CoreVectors.CmpEqI64x4), Pointer(LNEONTable.CoreVectors.CmpEqI64x4));
  AssertSlotReusesScalar('CmpEqI64x8', Pointer(LScalarTable.CoreVectors.CmpEqI64x8), Pointer(LNEONTable.CoreVectors.CmpEqI64x8));
  AssertSlotReusesScalar('CmpEqU32x8', Pointer(LScalarTable.CoreVectors.CmpEqU32x8), Pointer(LNEONTable.CoreVectors.CmpEqU32x8));
  AssertSlotReusesScalar('CmpEqU64x4', Pointer(LScalarTable.CoreVectors.CmpEqU64x4), Pointer(LNEONTable.CoreVectors.CmpEqU64x4));
  AssertSlotReusesScalar('CmpGeI32x16', Pointer(LScalarTable.CoreVectors.CmpGeI32x16), Pointer(LNEONTable.CoreVectors.CmpGeI32x16));
  AssertSlotReusesScalar('CmpGeI32x8', Pointer(LScalarTable.CoreVectors.CmpGeI32x8), Pointer(LNEONTable.CoreVectors.CmpGeI32x8));
  AssertSlotReusesScalar('CmpGeI64x4', Pointer(LScalarTable.CoreVectors.CmpGeI64x4), Pointer(LNEONTable.CoreVectors.CmpGeI64x4));
  AssertSlotReusesScalar('CmpGeI64x8', Pointer(LScalarTable.CoreVectors.CmpGeI64x8), Pointer(LNEONTable.CoreVectors.CmpGeI64x8));
  AssertSlotReusesScalar('CmpGeU32x8', Pointer(LScalarTable.CoreVectors.CmpGeU32x8), Pointer(LNEONTable.CoreVectors.CmpGeU32x8));
  AssertSlotReusesScalar('CmpGeU64x4', Pointer(LScalarTable.CoreVectors.CmpGeU64x4), Pointer(LNEONTable.CoreVectors.CmpGeU64x4));
  AssertSlotReusesScalar('CmpGtI32x16', Pointer(LScalarTable.CoreVectors.CmpGtI32x16), Pointer(LNEONTable.CoreVectors.CmpGtI32x16));
  AssertSlotReusesScalar('CmpGtI32x8', Pointer(LScalarTable.CoreVectors.CmpGtI32x8), Pointer(LNEONTable.CoreVectors.CmpGtI32x8));
  AssertSlotReusesScalar('CmpGtI64x4', Pointer(LScalarTable.CoreVectors.CmpGtI64x4), Pointer(LNEONTable.CoreVectors.CmpGtI64x4));
  AssertSlotReusesScalar('CmpGtI64x8', Pointer(LScalarTable.CoreVectors.CmpGtI64x8), Pointer(LNEONTable.CoreVectors.CmpGtI64x8));
  AssertSlotReusesScalar('CmpGtU32x8', Pointer(LScalarTable.CoreVectors.CmpGtU32x8), Pointer(LNEONTable.CoreVectors.CmpGtU32x8));
  AssertSlotReusesScalar('CmpGtU64x4', Pointer(LScalarTable.CoreVectors.CmpGtU64x4), Pointer(LNEONTable.CoreVectors.CmpGtU64x4));
  AssertSlotReusesScalar('CmpLeI32x16', Pointer(LScalarTable.CoreVectors.CmpLeI32x16), Pointer(LNEONTable.CoreVectors.CmpLeI32x16));
  AssertSlotReusesScalar('CmpLeI32x8', Pointer(LScalarTable.CoreVectors.CmpLeI32x8), Pointer(LNEONTable.CoreVectors.CmpLeI32x8));
  AssertSlotReusesScalar('CmpLeI64x4', Pointer(LScalarTable.CoreVectors.CmpLeI64x4), Pointer(LNEONTable.CoreVectors.CmpLeI64x4));
  AssertSlotReusesScalar('CmpLeI64x8', Pointer(LScalarTable.CoreVectors.CmpLeI64x8), Pointer(LNEONTable.CoreVectors.CmpLeI64x8));
  AssertSlotReusesScalar('CmpLeU32x8', Pointer(LScalarTable.CoreVectors.CmpLeU32x8), Pointer(LNEONTable.CoreVectors.CmpLeU32x8));
  AssertSlotReusesScalar('CmpLeU64x4', Pointer(LScalarTable.CoreVectors.CmpLeU64x4), Pointer(LNEONTable.CoreVectors.CmpLeU64x4));
  AssertSlotReusesScalar('CmpLtI32x16', Pointer(LScalarTable.CoreVectors.CmpLtI32x16), Pointer(LNEONTable.CoreVectors.CmpLtI32x16));
  AssertSlotReusesScalar('CmpLtI32x8', Pointer(LScalarTable.CoreVectors.CmpLtI32x8), Pointer(LNEONTable.CoreVectors.CmpLtI32x8));
  AssertSlotReusesScalar('CmpLtI64x4', Pointer(LScalarTable.CoreVectors.CmpLtI64x4), Pointer(LNEONTable.CoreVectors.CmpLtI64x4));
  AssertSlotReusesScalar('CmpLtI64x8', Pointer(LScalarTable.CoreVectors.CmpLtI64x8), Pointer(LNEONTable.CoreVectors.CmpLtI64x8));
  AssertSlotReusesScalar('CmpLtU32x8', Pointer(LScalarTable.CoreVectors.CmpLtU32x8), Pointer(LNEONTable.CoreVectors.CmpLtU32x8));
  AssertSlotReusesScalar('CmpLtU64x4', Pointer(LScalarTable.CoreVectors.CmpLtU64x4), Pointer(LNEONTable.CoreVectors.CmpLtU64x4));
  AssertSlotReusesScalar('CmpNeI32x16', Pointer(LScalarTable.CoreVectors.CmpNeI32x16), Pointer(LNEONTable.CoreVectors.CmpNeI32x16));
  AssertSlotReusesScalar('CmpNeI32x8', Pointer(LScalarTable.CoreVectors.CmpNeI32x8), Pointer(LNEONTable.CoreVectors.CmpNeI32x8));
  AssertSlotReusesScalar('CmpNeI64x4', Pointer(LScalarTable.CoreVectors.CmpNeI64x4), Pointer(LNEONTable.CoreVectors.CmpNeI64x4));
  AssertSlotReusesScalar('CmpNeI64x8', Pointer(LScalarTable.CoreVectors.CmpNeI64x8), Pointer(LNEONTable.CoreVectors.CmpNeI64x8));
  AssertSlotReusesScalar('CmpNeU32x8', Pointer(LScalarTable.CoreVectors.CmpNeU32x8), Pointer(LNEONTable.CoreVectors.CmpNeU32x8));
  AssertSlotReusesScalar('CmpNeU64x4', Pointer(LScalarTable.CoreVectors.CmpNeU64x4), Pointer(LNEONTable.CoreVectors.CmpNeU64x4));
end;

procedure TTestCase_DispatchAPI.Test_NEON_NoAsmIntegerFallbackSlots_Reuse_BaseScalar_When_Wrappers_Are_Not_BackendOwned;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LRegisterSource: string;

  procedure AssertRegisterHasAsmOwnedSlot(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterNEONBackend should keep an asm-owned assignment for ' + aLabel + ' when a real NEON implementation exists');
  end;

  procedure AssertRegisterKeepsBaseScalar(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0, 'RegisterNEONBackend should keep base scalar ' + aLabel + ' when NEON only has a scalar-forward wrapper');
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should reuse the base scalar slot when no NEON asm-backed integer ownership exists');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertRegisterHasAsmOwnedSlot('AddI64x2', 'table.CoreVectors.AddI64x2 := @NEONAddI64x2;');
  AssertRegisterHasAsmOwnedSlot('CmpEqI64x2', 'table.CoreVectors.CmpEqI64x2 := @NEONCmpEqI64x2;');
  AssertRegisterHasAsmOwnedSlot('AddI32x4', 'table.CoreVectors.AddI32x4 := @NEONAddI32x4;');
  AssertRegisterHasAsmOwnedSlot('AndI32x4', 'table.CoreVectors.AndI32x4 := @NEONAndI32x4;');
  AssertRegisterHasAsmOwnedSlot('CmpEqI32x4', 'table.CoreVectors.CmpEqI32x4 := @NEONCmpEqI32x4;');
  AssertRegisterHasAsmOwnedSlot('AddU32x4', 'table.CoreVectors.AddU32x4 := @NEONAddU32x4;');
  AssertRegisterHasAsmOwnedSlot('CmpEqU32x4', 'table.CoreVectors.CmpEqU32x4 := @NEONCmpEqU32x4;');
  AssertRegisterHasAsmOwnedSlot('AddI16x8', 'table.CoreVectors.AddI16x8 := @NEONAddI16x8;');
  AssertRegisterHasAsmOwnedSlot('AddI8x16', 'table.CoreVectors.AddI8x16 := @NEONAddI8x16;');
  AssertRegisterHasAsmOwnedSlot('AddU16x8', 'table.CoreVectors.AddU16x8 := @NEONAddU16x8;');
  AssertRegisterHasAsmOwnedSlot('AddU8x16', 'table.CoreVectors.AddU8x16 := @NEONAddU8x16;');
  AssertRegisterHasAsmOwnedSlot('AddI32x8', 'table.CoreVectors.AddI32x8 := @NEONAddI32x8;');
  AssertRegisterHasAsmOwnedSlot('AddU32x8', 'table.CoreVectors.AddU32x8 := @NEONAddU32x8;');
  AssertRegisterHasAsmOwnedSlot('AddU64x4', 'table.CoreVectors.AddU64x4 := @NEONAddU64x4;');
  AssertRegisterHasAsmOwnedSlot('AndI32x8', 'table.CoreVectors.AndI32x8 := @NEONAndI32x8;');
  AssertRegisterHasAsmOwnedSlot('AndI64x4', 'table.CoreVectors.AndI64x4 := @NEONAndI64x4;');
  AssertRegisterHasAsmOwnedSlot('AndNotI32x8', 'table.CoreVectors.AndNotI32x8 := @NEONAndNotI32x8;');
  AssertRegisterHasAsmOwnedSlot('AndNotI64x4', 'table.CoreVectors.AndNotI64x4 := @NEONAndNotI64x4;');
  AssertRegisterHasAsmOwnedSlot('AndNotU32x8', 'table.CoreVectors.AndNotU32x8 := @NEONAndNotU32x8;');
  AssertRegisterHasAsmOwnedSlot('AndU32x8', 'table.CoreVectors.AndU32x8 := @NEONAndU32x8;');
  AssertRegisterHasAsmOwnedSlot('AndU64x4', 'table.CoreVectors.AndU64x4 := @NEONAndU64x4;');
  AssertRegisterHasAsmOwnedSlot('MaxU32x8', 'table.CoreVectors.MaxU32x8 := @NEONMaxU32x8;');
  AssertRegisterHasAsmOwnedSlot('MinU32x8', 'table.CoreVectors.MinU32x8 := @NEONMinU32x8;');
  AssertRegisterHasAsmOwnedSlot('MulI32x8', 'table.CoreVectors.MulI32x8 := @NEONMulI32x8;');
  AssertRegisterHasAsmOwnedSlot('NotI32x8', 'table.CoreVectors.NotI32x8 := @NEONNotI32x8;');
  AssertRegisterHasAsmOwnedSlot('NotI64x4', 'table.CoreVectors.NotI64x4 := @NEONNotI64x4;');
  AssertRegisterHasAsmOwnedSlot('NotU32x8', 'table.CoreVectors.NotU32x8 := @NEONNotU32x8;');
  AssertRegisterHasAsmOwnedSlot('NotU64x4', 'table.CoreVectors.NotU64x4 := @NEONNotU64x4;');
  AssertRegisterHasAsmOwnedSlot('OrI32x8', 'table.CoreVectors.OrI32x8 := @NEONOrI32x8;');
  AssertRegisterHasAsmOwnedSlot('OrI64x4', 'table.CoreVectors.OrI64x4 := @NEONOrI64x4;');
  AssertRegisterHasAsmOwnedSlot('OrU32x8', 'table.CoreVectors.OrU32x8 := @NEONOrU32x8;');
  AssertRegisterHasAsmOwnedSlot('OrU64x4', 'table.CoreVectors.OrU64x4 := @NEONOrU64x4;');
  AssertRegisterHasAsmOwnedSlot('ShiftLeftI32x16', 'table.CoreVectors.ShiftLeftI32x16 := @NEONShiftLeftI32x16;');
  AssertRegisterHasAsmOwnedSlot('ShiftLeftI32x8', 'table.CoreVectors.ShiftLeftI32x8 := @NEONShiftLeftI32x8;');
  AssertRegisterHasAsmOwnedSlot('ShiftLeftI64x4', 'table.CoreVectors.ShiftLeftI64x4 := @NEONShiftLeftI64x4;');
  AssertRegisterHasAsmOwnedSlot('ShiftLeftU32x8', 'table.CoreVectors.ShiftLeftU32x8 := @NEONShiftLeftU32x8;');
  AssertRegisterHasAsmOwnedSlot('ShiftLeftU64x4', 'table.CoreVectors.ShiftLeftU64x4 := @NEONShiftLeftU64x4;');
  AssertRegisterHasAsmOwnedSlot('ShiftRightArithI32x16', 'table.CoreVectors.ShiftRightArithI32x16 := @NEONShiftRightArithI32x16;');
  AssertRegisterHasAsmOwnedSlot('ShiftRightArithI32x8', 'table.CoreVectors.ShiftRightArithI32x8 := @NEONShiftRightArithI32x8;');
  AssertRegisterHasAsmOwnedSlot('ShiftRightI32x16', 'table.CoreVectors.ShiftRightI32x16 := @NEONShiftRightI32x16;');
  AssertRegisterHasAsmOwnedSlot('ShiftRightI32x8', 'table.CoreVectors.ShiftRightI32x8 := @NEONShiftRightI32x8;');
  AssertRegisterHasAsmOwnedSlot('ShiftRightI64x4', 'table.CoreVectors.ShiftRightI64x4 := @NEONShiftRightI64x4;');
  AssertRegisterHasAsmOwnedSlot('ShiftRightArithI64x4', 'table.CoreVectors.ShiftRightArithI64x4 := @NEONShiftRightArithI64x4;');
  AssertRegisterHasAsmOwnedSlot('ShiftRightU32x8', 'table.CoreVectors.ShiftRightU32x8 := @NEONShiftRightU32x8;');
  AssertRegisterHasAsmOwnedSlot('ShiftRightU64x4', 'table.CoreVectors.ShiftRightU64x4 := @NEONShiftRightU64x4;');
  AssertRegisterHasAsmOwnedSlot('SubI32x8', 'table.CoreVectors.SubI32x8 := @NEONSubI32x8;');
  AssertRegisterHasAsmOwnedSlot('SubU32x8', 'table.CoreVectors.SubU32x8 := @NEONSubU32x8;');
  AssertRegisterHasAsmOwnedSlot('SubU64x4', 'table.CoreVectors.SubU64x4 := @NEONSubU64x4;');
  AssertRegisterHasAsmOwnedSlot('XorI32x8', 'table.CoreVectors.XorI32x8 := @NEONXorI32x8;');
  AssertRegisterHasAsmOwnedSlot('XorI64x4', 'table.CoreVectors.XorI64x4 := @NEONXorI64x4;');
  AssertRegisterHasAsmOwnedSlot('XorU32x8', 'table.CoreVectors.XorU32x8 := @NEONXorU32x8;');
  AssertRegisterHasAsmOwnedSlot('XorU64x4', 'table.CoreVectors.XorU64x4 := @NEONXorU64x4;');
  AssertRegisterHasAsmOwnedSlot('LoadI64x4', 'table.CoreVectors.LoadI64x4 := @NEONLoadI64x4_ASM;');
  AssertRegisterHasAsmOwnedSlot('SplatI64x4', 'table.CoreVectors.SplatI64x4 := @NEONSplatI64x4_ASM;');
  AssertRegisterHasAsmOwnedSlot('StoreI64x4', 'table.CoreVectors.StoreI64x4 := @NEONStoreI64x4_ASM;');
  AssertRegisterHasAsmOwnedSlot('ZeroI64x4', 'table.CoreVectors.ZeroI64x4 := @NEONZeroI64x4_ASM;');
  AssertRegisterKeepsBaseScalar('AddU64x2', 'table.CoreVectors.AddU64x2 := @NEONAddU64x2;');
  AssertRegisterKeepsBaseScalar('CmpEqU64x2', 'table.CoreVectors.CmpEqU64x2 := @NEONCmpEqU64x2;');
  AssertRegisterKeepsBaseScalar('MinI32x4', 'table.CoreVectors.MinI32x4 := @NEONMinI32x4;');
  AssertRegisterKeepsBaseScalar('MaxI32x4', 'table.CoreVectors.MaxI32x4 := @NEONMaxI32x4;');
  AssertRegisterKeepsBaseScalar('MulU32x4', 'table.CoreVectors.MulU32x4 := @NEONMulU32x4;');
  AssertRegisterKeepsBaseScalar('AddI32x16', 'table.CoreVectors.AddI32x16 := @NEONAddI32x16;');
  AssertRegisterKeepsBaseScalar('AddI64x4', 'table.CoreVectors.AddI64x4 := @NEONAddI64x4;');
  AssertRegisterKeepsBaseScalar('AddI64x8', 'table.CoreVectors.AddI64x8 := @NEONAddI64x8;');
  AssertRegisterKeepsBaseScalar('AndI32x16', 'table.CoreVectors.AndI32x16 := @NEONAndI32x16;');
  AssertRegisterKeepsBaseScalar('AndI64x8', 'table.CoreVectors.AndI64x8 := @NEONAndI64x8;');
  AssertRegisterKeepsBaseScalar('AndNotI32x16', 'table.CoreVectors.AndNotI32x16 := @NEONAndNotI32x16;');
  AssertRegisterKeepsBaseScalar('ExtractI32x16', 'table.CoreVectors.ExtractI32x16 := @NEONExtractI32x16;');
  AssertRegisterKeepsBaseScalar('ExtractI32x8', 'table.CoreVectors.ExtractI32x8 := @NEONExtractI32x8;');
  AssertRegisterKeepsBaseScalar('ExtractI64x4', 'table.CoreVectors.ExtractI64x4 := @NEONExtractI64x4;');
  AssertRegisterKeepsBaseScalar('InsertI32x16', 'table.CoreVectors.InsertI32x16 := @NEONInsertI32x16;');
  AssertRegisterKeepsBaseScalar('InsertI32x8', 'table.CoreVectors.InsertI32x8 := @NEONInsertI32x8;');
  AssertRegisterKeepsBaseScalar('InsertI64x4', 'table.CoreVectors.InsertI64x4 := @NEONInsertI64x4;');
  AssertRegisterKeepsBaseScalar('MaxI32x16', 'table.CoreVectors.MaxI32x16 := @NEONMaxI32x16;');
  AssertRegisterKeepsBaseScalar('MaxI32x8', 'table.CoreVectors.MaxI32x8 := @NEONMaxI32x8;');
  AssertRegisterKeepsBaseScalar('MinI32x16', 'table.CoreVectors.MinI32x16 := @NEONMinI32x16;');
  AssertRegisterKeepsBaseScalar('MinI32x8', 'table.CoreVectors.MinI32x8 := @NEONMinI32x8;');
  AssertRegisterKeepsBaseScalar('MulI32x16', 'table.CoreVectors.MulI32x16 := @NEONMulI32x16;');
  AssertRegisterKeepsBaseScalar('MulU32x8', 'table.CoreVectors.MulU32x8 := @NEONMulU32x8;');
  AssertRegisterKeepsBaseScalar('NotI32x16', 'table.CoreVectors.NotI32x16 := @NEONNotI32x16;');
  AssertRegisterKeepsBaseScalar('NotI64x8', 'table.CoreVectors.NotI64x8 := @NEONNotI64x8;');
  AssertRegisterKeepsBaseScalar('OrI32x16', 'table.CoreVectors.OrI32x16 := @NEONOrI32x16;');
  AssertRegisterKeepsBaseScalar('OrI64x8', 'table.CoreVectors.OrI64x8 := @NEONOrI64x8;');
  AssertRegisterKeepsBaseScalar('SubI32x16', 'table.CoreVectors.SubI32x16 := @NEONSubI32x16;');
  AssertRegisterKeepsBaseScalar('SubI64x4', 'table.CoreVectors.SubI64x4 := @NEONSubI64x4;');
  AssertRegisterKeepsBaseScalar('SubI64x8', 'table.CoreVectors.SubI64x8 := @NEONSubI64x8;');
  AssertRegisterKeepsBaseScalar('XorI32x16', 'table.CoreVectors.XorI32x16 := @NEONXorI32x16;');
  AssertRegisterKeepsBaseScalar('XorI64x8', 'table.CoreVectors.XorI64x8 := @NEONXorI64x8;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('MinI32x4', Pointer(LScalarTable.CoreVectors.MinI32x4), Pointer(LNEONTable.CoreVectors.MinI32x4));
  AssertSlotReusesScalar('MaxI32x4', Pointer(LScalarTable.CoreVectors.MaxI32x4), Pointer(LNEONTable.CoreVectors.MaxI32x4));
  AssertSlotReusesScalar('MulU32x4', Pointer(LScalarTable.CoreVectors.MulU32x4), Pointer(LNEONTable.CoreVectors.MulU32x4));
  AssertSlotReusesScalar('AddU64x2', Pointer(LScalarTable.CoreVectors.AddU64x2), Pointer(LNEONTable.CoreVectors.AddU64x2));
  AssertSlotReusesScalar('CmpEqU64x2', Pointer(LScalarTable.CoreVectors.CmpEqU64x2), Pointer(LNEONTable.CoreVectors.CmpEqU64x2));
  AssertSlotReusesScalar('AddI32x16', Pointer(LScalarTable.CoreVectors.AddI32x16), Pointer(LNEONTable.CoreVectors.AddI32x16));
  AssertSlotReusesScalar('AddI64x4', Pointer(LScalarTable.CoreVectors.AddI64x4), Pointer(LNEONTable.CoreVectors.AddI64x4));
  AssertSlotReusesScalar('AddI64x8', Pointer(LScalarTable.CoreVectors.AddI64x8), Pointer(LNEONTable.CoreVectors.AddI64x8));
  AssertSlotReusesScalar('AndI32x16', Pointer(LScalarTable.CoreVectors.AndI32x16), Pointer(LNEONTable.CoreVectors.AndI32x16));
  AssertSlotReusesScalar('AndI64x8', Pointer(LScalarTable.CoreVectors.AndI64x8), Pointer(LNEONTable.CoreVectors.AndI64x8));
  AssertSlotReusesScalar('AndNotI32x16', Pointer(LScalarTable.CoreVectors.AndNotI32x16), Pointer(LNEONTable.CoreVectors.AndNotI32x16));
  AssertSlotReusesScalar('ExtractI32x16', Pointer(LScalarTable.CoreVectors.ExtractI32x16), Pointer(LNEONTable.CoreVectors.ExtractI32x16));
  AssertSlotReusesScalar('ExtractI32x8', Pointer(LScalarTable.CoreVectors.ExtractI32x8), Pointer(LNEONTable.CoreVectors.ExtractI32x8));
  AssertSlotReusesScalar('ExtractI64x4', Pointer(LScalarTable.CoreVectors.ExtractI64x4), Pointer(LNEONTable.CoreVectors.ExtractI64x4));
  AssertSlotReusesScalar('InsertI32x16', Pointer(LScalarTable.CoreVectors.InsertI32x16), Pointer(LNEONTable.CoreVectors.InsertI32x16));
  AssertSlotReusesScalar('InsertI32x8', Pointer(LScalarTable.CoreVectors.InsertI32x8), Pointer(LNEONTable.CoreVectors.InsertI32x8));
  AssertSlotReusesScalar('InsertI64x4', Pointer(LScalarTable.CoreVectors.InsertI64x4), Pointer(LNEONTable.CoreVectors.InsertI64x4));
  AssertSlotReusesScalar('MaxI32x16', Pointer(LScalarTable.CoreVectors.MaxI32x16), Pointer(LNEONTable.CoreVectors.MaxI32x16));
  AssertSlotReusesScalar('MaxI32x8', Pointer(LScalarTable.CoreVectors.MaxI32x8), Pointer(LNEONTable.CoreVectors.MaxI32x8));
  AssertSlotReusesScalar('MinI32x16', Pointer(LScalarTable.CoreVectors.MinI32x16), Pointer(LNEONTable.CoreVectors.MinI32x16));
  AssertSlotReusesScalar('MinI32x8', Pointer(LScalarTable.CoreVectors.MinI32x8), Pointer(LNEONTable.CoreVectors.MinI32x8));
  AssertSlotReusesScalar('MulI32x16', Pointer(LScalarTable.CoreVectors.MulI32x16), Pointer(LNEONTable.CoreVectors.MulI32x16));
  AssertSlotReusesScalar('MulU32x8', Pointer(LScalarTable.CoreVectors.MulU32x8), Pointer(LNEONTable.CoreVectors.MulU32x8));
  AssertSlotReusesScalar('NotI32x16', Pointer(LScalarTable.CoreVectors.NotI32x16), Pointer(LNEONTable.CoreVectors.NotI32x16));
  AssertSlotReusesScalar('NotI64x8', Pointer(LScalarTable.CoreVectors.NotI64x8), Pointer(LNEONTable.CoreVectors.NotI64x8));
  AssertSlotReusesScalar('OrI32x16', Pointer(LScalarTable.CoreVectors.OrI32x16), Pointer(LNEONTable.CoreVectors.OrI32x16));
  AssertSlotReusesScalar('OrI64x8', Pointer(LScalarTable.CoreVectors.OrI64x8), Pointer(LNEONTable.CoreVectors.OrI64x8));
  AssertSlotReusesScalar('SubI32x16', Pointer(LScalarTable.CoreVectors.SubI32x16), Pointer(LNEONTable.CoreVectors.SubI32x16));
  AssertSlotReusesScalar('SubI64x4', Pointer(LScalarTable.CoreVectors.SubI64x4), Pointer(LNEONTable.CoreVectors.SubI64x4));
  AssertSlotReusesScalar('SubI64x8', Pointer(LScalarTable.CoreVectors.SubI64x8), Pointer(LNEONTable.CoreVectors.SubI64x8));
  AssertSlotReusesScalar('XorI32x16', Pointer(LScalarTable.CoreVectors.XorI32x16), Pointer(LNEONTable.CoreVectors.XorI32x16));
  AssertSlotReusesScalar('XorI64x8', Pointer(LScalarTable.CoreVectors.XorI64x8), Pointer(LNEONTable.CoreVectors.XorI64x8));
  {$IFNDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  AssertSlotReusesScalar('AddI32x4', Pointer(LScalarTable.CoreVectors.AddI32x4), Pointer(LNEONTable.CoreVectors.AddI32x4));
  AssertSlotReusesScalar('AndI32x4', Pointer(LScalarTable.CoreVectors.AndI32x4), Pointer(LNEONTable.CoreVectors.AndI32x4));
  AssertSlotReusesScalar('CmpEqI32x4', Pointer(LScalarTable.CoreVectors.CmpEqI32x4), Pointer(LNEONTable.CoreVectors.CmpEqI32x4));
  AssertSlotReusesScalar('AddU32x4', Pointer(LScalarTable.CoreVectors.AddU32x4), Pointer(LNEONTable.CoreVectors.AddU32x4));
  AssertSlotReusesScalar('CmpEqU32x4', Pointer(LScalarTable.CoreVectors.CmpEqU32x4), Pointer(LNEONTable.CoreVectors.CmpEqU32x4));
  AssertSlotReusesScalar('AddI64x2', Pointer(LScalarTable.CoreVectors.AddI64x2), Pointer(LNEONTable.CoreVectors.AddI64x2));
  AssertSlotReusesScalar('CmpEqI64x2', Pointer(LScalarTable.CoreVectors.CmpEqI64x2), Pointer(LNEONTable.CoreVectors.CmpEqI64x2));
  AssertSlotReusesScalar('AddI16x8', Pointer(LScalarTable.CoreVectors.AddI16x8), Pointer(LNEONTable.CoreVectors.AddI16x8));
  AssertSlotReusesScalar('AddI8x16', Pointer(LScalarTable.CoreVectors.AddI8x16), Pointer(LNEONTable.CoreVectors.AddI8x16));
  AssertSlotReusesScalar('AddU16x8', Pointer(LScalarTable.CoreVectors.AddU16x8), Pointer(LNEONTable.CoreVectors.AddU16x8));
  AssertSlotReusesScalar('AddU8x16', Pointer(LScalarTable.CoreVectors.AddU8x16), Pointer(LNEONTable.CoreVectors.AddU8x16));
  AssertSlotReusesScalar('AddI32x8', Pointer(LScalarTable.CoreVectors.AddI32x8), Pointer(LNEONTable.CoreVectors.AddI32x8));
  AssertSlotReusesScalar('AddU32x8', Pointer(LScalarTable.CoreVectors.AddU32x8), Pointer(LNEONTable.CoreVectors.AddU32x8));
  AssertSlotReusesScalar('AddU64x4', Pointer(LScalarTable.CoreVectors.AddU64x4), Pointer(LNEONTable.CoreVectors.AddU64x4));
  AssertSlotReusesScalar('AndI32x8', Pointer(LScalarTable.CoreVectors.AndI32x8), Pointer(LNEONTable.CoreVectors.AndI32x8));
  AssertSlotReusesScalar('AndI64x4', Pointer(LScalarTable.CoreVectors.AndI64x4), Pointer(LNEONTable.CoreVectors.AndI64x4));
  AssertSlotReusesScalar('AndNotI32x8', Pointer(LScalarTable.CoreVectors.AndNotI32x8), Pointer(LNEONTable.CoreVectors.AndNotI32x8));
  AssertSlotReusesScalar('AndNotI64x4', Pointer(LScalarTable.CoreVectors.AndNotI64x4), Pointer(LNEONTable.CoreVectors.AndNotI64x4));
  AssertSlotReusesScalar('AndNotU32x8', Pointer(LScalarTable.CoreVectors.AndNotU32x8), Pointer(LNEONTable.CoreVectors.AndNotU32x8));
  AssertSlotReusesScalar('AndU32x8', Pointer(LScalarTable.CoreVectors.AndU32x8), Pointer(LNEONTable.CoreVectors.AndU32x8));
  AssertSlotReusesScalar('AndU64x4', Pointer(LScalarTable.CoreVectors.AndU64x4), Pointer(LNEONTable.CoreVectors.AndU64x4));
  AssertSlotReusesScalar('MaxU32x8', Pointer(LScalarTable.CoreVectors.MaxU32x8), Pointer(LNEONTable.CoreVectors.MaxU32x8));
  AssertSlotReusesScalar('MinU32x8', Pointer(LScalarTable.CoreVectors.MinU32x8), Pointer(LNEONTable.CoreVectors.MinU32x8));
  AssertSlotReusesScalar('MulI32x8', Pointer(LScalarTable.CoreVectors.MulI32x8), Pointer(LNEONTable.CoreVectors.MulI32x8));
  AssertSlotReusesScalar('NotI32x8', Pointer(LScalarTable.CoreVectors.NotI32x8), Pointer(LNEONTable.CoreVectors.NotI32x8));
  AssertSlotReusesScalar('NotI64x4', Pointer(LScalarTable.CoreVectors.NotI64x4), Pointer(LNEONTable.CoreVectors.NotI64x4));
  AssertSlotReusesScalar('NotU32x8', Pointer(LScalarTable.CoreVectors.NotU32x8), Pointer(LNEONTable.CoreVectors.NotU32x8));
  AssertSlotReusesScalar('NotU64x4', Pointer(LScalarTable.CoreVectors.NotU64x4), Pointer(LNEONTable.CoreVectors.NotU64x4));
  AssertSlotReusesScalar('OrI32x8', Pointer(LScalarTable.CoreVectors.OrI32x8), Pointer(LNEONTable.CoreVectors.OrI32x8));
  AssertSlotReusesScalar('OrI64x4', Pointer(LScalarTable.CoreVectors.OrI64x4), Pointer(LNEONTable.CoreVectors.OrI64x4));
  AssertSlotReusesScalar('OrU32x8', Pointer(LScalarTable.CoreVectors.OrU32x8), Pointer(LNEONTable.CoreVectors.OrU32x8));
  AssertSlotReusesScalar('OrU64x4', Pointer(LScalarTable.CoreVectors.OrU64x4), Pointer(LNEONTable.CoreVectors.OrU64x4));
  AssertSlotReusesScalar('ShiftLeftI32x16', Pointer(LScalarTable.CoreVectors.ShiftLeftI32x16), Pointer(LNEONTable.CoreVectors.ShiftLeftI32x16));
  AssertSlotReusesScalar('ShiftLeftI32x8', Pointer(LScalarTable.CoreVectors.ShiftLeftI32x8), Pointer(LNEONTable.CoreVectors.ShiftLeftI32x8));
  AssertSlotReusesScalar('ShiftLeftI64x4', Pointer(LScalarTable.CoreVectors.ShiftLeftI64x4), Pointer(LNEONTable.CoreVectors.ShiftLeftI64x4));
  AssertSlotReusesScalar('ShiftLeftU32x8', Pointer(LScalarTable.CoreVectors.ShiftLeftU32x8), Pointer(LNEONTable.CoreVectors.ShiftLeftU32x8));
  AssertSlotReusesScalar('ShiftLeftU64x4', Pointer(LScalarTable.CoreVectors.ShiftLeftU64x4), Pointer(LNEONTable.CoreVectors.ShiftLeftU64x4));
  AssertSlotReusesScalar('ShiftRightArithI32x16', Pointer(LScalarTable.CoreVectors.ShiftRightArithI32x16), Pointer(LNEONTable.CoreVectors.ShiftRightArithI32x16));
  AssertSlotReusesScalar('ShiftRightArithI32x8', Pointer(LScalarTable.CoreVectors.ShiftRightArithI32x8), Pointer(LNEONTable.CoreVectors.ShiftRightArithI32x8));
  AssertSlotReusesScalar('ShiftRightI32x16', Pointer(LScalarTable.CoreVectors.ShiftRightI32x16), Pointer(LNEONTable.CoreVectors.ShiftRightI32x16));
  AssertSlotReusesScalar('ShiftRightI32x8', Pointer(LScalarTable.CoreVectors.ShiftRightI32x8), Pointer(LNEONTable.CoreVectors.ShiftRightI32x8));
  AssertSlotReusesScalar('ShiftRightI64x4', Pointer(LScalarTable.CoreVectors.ShiftRightI64x4), Pointer(LNEONTable.CoreVectors.ShiftRightI64x4));
  AssertSlotReusesScalar('ShiftRightArithI64x4', Pointer(LScalarTable.CoreVectors.ShiftRightArithI64x4), Pointer(LNEONTable.CoreVectors.ShiftRightArithI64x4));
  AssertSlotReusesScalar('ShiftRightU32x8', Pointer(LScalarTable.CoreVectors.ShiftRightU32x8), Pointer(LNEONTable.CoreVectors.ShiftRightU32x8));
  AssertSlotReusesScalar('ShiftRightU64x4', Pointer(LScalarTable.CoreVectors.ShiftRightU64x4), Pointer(LNEONTable.CoreVectors.ShiftRightU64x4));
  AssertSlotReusesScalar('SubI32x8', Pointer(LScalarTable.CoreVectors.SubI32x8), Pointer(LNEONTable.CoreVectors.SubI32x8));
  AssertSlotReusesScalar('SubU32x8', Pointer(LScalarTable.CoreVectors.SubU32x8), Pointer(LNEONTable.CoreVectors.SubU32x8));
  AssertSlotReusesScalar('SubU64x4', Pointer(LScalarTable.CoreVectors.SubU64x4), Pointer(LNEONTable.CoreVectors.SubU64x4));
  AssertSlotReusesScalar('XorI32x8', Pointer(LScalarTable.CoreVectors.XorI32x8), Pointer(LNEONTable.CoreVectors.XorI32x8));
  AssertSlotReusesScalar('XorI64x4', Pointer(LScalarTable.CoreVectors.XorI64x4), Pointer(LNEONTable.CoreVectors.XorI64x4));
  AssertSlotReusesScalar('XorU32x8', Pointer(LScalarTable.CoreVectors.XorU32x8), Pointer(LNEONTable.CoreVectors.XorU32x8));
  AssertSlotReusesScalar('XorU64x4', Pointer(LScalarTable.CoreVectors.XorU64x4), Pointer(LNEONTable.CoreVectors.XorU64x4));
  AssertSlotReusesScalar('LoadI64x4', Pointer(LScalarTable.CoreVectors.LoadI64x4), Pointer(LNEONTable.CoreVectors.LoadI64x4));
  AssertSlotReusesScalar('SplatI64x4', Pointer(LScalarTable.CoreVectors.SplatI64x4), Pointer(LNEONTable.CoreVectors.SplatI64x4));
  AssertSlotReusesScalar('StoreI64x4', Pointer(LScalarTable.CoreVectors.StoreI64x4), Pointer(LNEONTable.CoreVectors.StoreI64x4));
  AssertSlotReusesScalar('ZeroI64x4', Pointer(LScalarTable.CoreVectors.ZeroI64x4), Pointer(LNEONTable.CoreVectors.ZeroI64x4));
  AssertSlotReusesScalar('I8x16SatAdd', Pointer(LScalarTable.CoreVectors.I8x16SatAdd), Pointer(LNEONTable.CoreVectors.I8x16SatAdd));
  AssertSlotReusesScalar('I16x8SatAdd', Pointer(LScalarTable.CoreVectors.I16x8SatAdd), Pointer(LNEONTable.CoreVectors.I16x8SatAdd));
  AssertSlotReusesScalar('U8x16SatAdd', Pointer(LScalarTable.CoreVectors.U8x16SatAdd), Pointer(LNEONTable.CoreVectors.U8x16SatAdd));
  AssertSlotReusesScalar('U16x8SatAdd', Pointer(LScalarTable.CoreVectors.U16x8SatAdd), Pointer(LNEONTable.CoreVectors.U16x8SatAdd));
  {$ENDIF}
end;

procedure TTestCase_DispatchAPI.Test_NEON_SelectF32x4_Keep_LocalSourceCompanion_But_Reuse_BaseScalar_RuntimeSlot;
var
  LSourceLines: TSourceLines;
  LNEONSourcePath: string;
  LScalarUtilityPath: string;
  LRegisterSourcePath: string;
  LNEONSource: string;
  LScalarUtilitySource: string;
  LRegisterSource: string;
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;

  procedure AssertScalarCompanionStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LScalarUtilitySource) > 0, aLabel + ' should keep the no-asm scalar companion wrapper');
  end;

  procedure AssertRegisterKeepsBaseScalar(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0, 'RegisterNEONBackend should keep base scalar ' + aLabel + ' because the asm branch only keeps a local Pascal companion and not a runtime-owned shuffle leaf');
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should fall back to the base scalar slot when vector asm is not compiled');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LNEONSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.pas');
    CheckTrue(FileExists(LNEONSourcePath), 'NEON source should exist for implementation-shape audit: ' + LNEONSourcePath);
    LSourceLines.LoadFromFile(LNEONSourcePath);
    LNEONSource := LowerCase(LSourceLines.Text);

    LScalarUtilityPath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.scalar.utility.inc');
    CheckTrue(FileExists(LScalarUtilityPath), 'NEON scalar utility source should exist for implementation-shape audit: ' + LScalarUtilityPath);
    LSourceLines.LoadFromFile(LScalarUtilityPath);
    LScalarUtilitySource := LowerCase(LSourceLines.Text);

    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  CheckTrue(Pos('result := scalarselectf32x4(mask, a, b);', LNEONSource) = 0, 'asm-enabled NEONSelectF32x4 should not forward directly to ScalarSelectF32x4');
  AssertScalarCompanionStillPresent('NEONSelectF32x4', 'result := scalarselectf32x4(mask, a, b);');
  AssertRegisterKeepsBaseScalar('SelectF32x4', 'table.CoreVectors.SelectF32x4 := @NEONSelectF32x4;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('SelectF32x4', Pointer(LScalarTable.CoreVectors.SelectF32x4), Pointer(LNEONTable.CoreVectors.SelectF32x4));
end;

procedure TTestCase_DispatchAPI.Test_NEON_AndNotSlots_Keep_AsmOwnedCompositions_And_RuntimeOwnership;
var
  LSourceLines: TSourceLines;
  LCompareSourcePath: string;
  LRegisterSourcePath: string;
  LCompareSource: string;
  LRegisterSource: string;
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;

  procedure AssertWrapperStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LCompareSource) > 0, aLabel + ' should keep its backend-local composition in the NEON compare source');
  end;

  procedure AssertRegisterHasAsmOwnedSlot(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterNEONBackend should keep the asm-enabled binding source for ' + aLabel);
  end;

  procedure AssertSlotKeepsBackendOwnership(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, 'NEON ' + aLabel + ' should stay assigned in the registered backend table');
    CheckTrue(aBackendSlot <> aScalarSlot, 'NEON ' + aLabel + ' should keep backend ownership when vector asm is compiled');
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'NEON ' + aLabel + ' should fall back to the base scalar slot when vector asm is not compiled');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LCompareSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.compare.inc');
    CheckTrue(FileExists(LCompareSourcePath), 'NEON compare source should exist for implementation-shape audit: ' + LCompareSourcePath);
    LSourceLines.LoadFromFile(LCompareSourcePath);
    LCompareSource := LowerCase(LSourceLines.Text);

    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'NEON register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertWrapperStillPresent('NEONAndNotI8x16', 'result := neonandi8x16(neonnoti8x16(a), b);');
  AssertWrapperStillPresent('NEONAndNotU16x8', 'result := neonandu16x8(neonnotu16x8(a), b);');
  AssertWrapperStillPresent('NEONAndNotU8x16', 'result := neonandu8x16(neonnotu8x16(a), b);');

  AssertRegisterHasAsmOwnedSlot('AndNotI8x16', 'table.CoreVectors.AndNotI8x16 := @NEONAndNotI8x16;');
  AssertRegisterHasAsmOwnedSlot('AndNotU16x8', 'table.CoreVectors.AndNotU16x8 := @NEONAndNotU16x8;');
  AssertRegisterHasAsmOwnedSlot('AndNotU8x16', 'table.CoreVectors.AndNotU8x16 := @NEONAndNotU8x16;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  AssertSlotKeepsBackendOwnership('AndNotI8x16', Pointer(LScalarTable.CoreVectors.AndNotI8x16), Pointer(LNEONTable.CoreVectors.AndNotI8x16));
  AssertSlotKeepsBackendOwnership('AndNotU16x8', Pointer(LScalarTable.CoreVectors.AndNotU16x8), Pointer(LNEONTable.CoreVectors.AndNotU16x8));
  AssertSlotKeepsBackendOwnership('AndNotU8x16', Pointer(LScalarTable.CoreVectors.AndNotU8x16), Pointer(LNEONTable.CoreVectors.AndNotU8x16));
  {$ELSE}
  AssertSlotReusesScalar('AndNotI8x16', Pointer(LScalarTable.CoreVectors.AndNotI8x16), Pointer(LNEONTable.CoreVectors.AndNotI8x16));
  AssertSlotReusesScalar('AndNotU16x8', Pointer(LScalarTable.CoreVectors.AndNotU16x8), Pointer(LNEONTable.CoreVectors.AndNotU16x8));
  AssertSlotReusesScalar('AndNotU8x16', Pointer(LScalarTable.CoreVectors.AndNotU8x16), Pointer(LNEONTable.CoreVectors.AndNotU8x16));
  {$ENDIF}
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_DotF64Slots_Reuse_BaseScalar_When_ScalarForwarders_Are_Dead;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LUnitSourcePath: string;
  LFacadeSourcePath: string;
  LRegisterSource: string;
  LUnitSource: string;
  LFacadeSource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LUnitSource) = 0, aLabel + ' dead wrapper should be removed from the RISCVV unit source');
    CheckTrue(Pos(LowerCase(aSnippet), LFacadeSource) = 0, aLabel + ' dead wrapper should be removed from the RISCVV facade include');
  end;

  procedure AssertRegisterKeepsBaseScalar(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0, 'RegisterRISCVVBackend should keep base scalar ' + aLabel + ' when the RISCVV dot implementation is only a dead scalar-forwarder');
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the base scalar slot when both asm/common and no-asm wrappers are dead scalar-forwarders');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LUnitSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LUnitSourcePath), 'RISCVV unit source should exist for implementation-shape audit: ' + LUnitSourcePath);
    LSourceLines.LoadFromFile(LUnitSourcePath);
    LUnitSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for implementation-shape audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('RISCVVDotF64x2', 'function RISCVVDotF64x2(');
  AssertDeadWrapperRemoved('RISCVVDotF64x4', 'function RISCVVDotF64x4(');

  AssertRegisterKeepsBaseScalar('DotF64x2', 'table.CoreVectors.DotF64x2 := @RISCVVDotF64x2;');
  AssertRegisterKeepsBaseScalar('DotF64x4', 'table.CoreVectors.DotF64x4 := @RISCVVDotF64x4;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('DotF64x2', Pointer(LScalarTable.CoreVectors.DotF64x2), Pointer(LRISCVVTable.CoreVectors.DotF64x2));
  AssertSlotReusesScalar('DotF64x4', Pointer(LScalarTable.CoreVectors.DotF64x4), Pointer(LRISCVVTable.CoreVectors.DotF64x4));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_ExactScalarHelperSlots_Reuse_BaseScalar_When_Owners_Are_Dead;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LHelperSourcePath: string;
  LUnitSourcePath: string;
  LRegisterSource: string;
  LHelperSource: string;
  LUnitSource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LUnitSource) = 0, aLabel + ' dead owner should be removed from the RISCVV asm/common unit source');
    CheckTrue(Pos(LowerCase(aSnippet), LHelperSource) = 0, aLabel + ' dead owner should be removed from the RISCVV no-asm helper source');
  end;

  procedure AssertRegisterKeepsBaseScalar(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0, 'RegisterRISCVVBackend should keep base scalar ' + aLabel + ' when both the asm/common and no-asm RISCVV owners are dead scalar-forwarders');
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the base scalar slot when both owners are dead scalar-forwarders');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for exact-scalar helper audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LHelperSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.helpers.inc');
    CheckTrue(FileExists(LHelperSourcePath), 'RISCVV helper source should exist for exact-scalar helper audit: ' + LHelperSourcePath);
    LSourceLines.LoadFromFile(LHelperSourcePath);
    LHelperSource := LowerCase(LSourceLines.Text);

    LUnitSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LUnitSourcePath), 'RISCVV unit source should exist for exact-scalar helper audit: ' + LUnitSourcePath);
    LSourceLines.LoadFromFile(LUnitSourcePath);
    LUnitSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('RISCVVAndNotI64x2', 'function RISCVVAndNotI64x2(');
  AssertDeadWrapperRemoved('RISCVVMinI64x2', 'function RISCVVMinI64x2(');
  AssertDeadWrapperRemoved('RISCVVMaxI64x2', 'function RISCVVMaxI64x2(');
  AssertDeadWrapperRemoved('RISCVVAndNotU64x2', 'function RISCVVAndNotU64x2(');
  AssertDeadWrapperRemoved('RISCVVCmpEqU64x2', 'function RISCVVCmpEqU64x2(');
  AssertDeadWrapperRemoved('RISCVVCmpLtU64x2', 'function RISCVVCmpLtU64x2(');
  AssertDeadWrapperRemoved('RISCVVCmpGtU64x2', 'function RISCVVCmpGtU64x2(');
  AssertDeadWrapperRemoved('RISCVVMinU64x2', 'function RISCVVMinU64x2(');
  AssertDeadWrapperRemoved('RISCVVMaxU64x2', 'function RISCVVMaxU64x2(');

  AssertRegisterKeepsBaseScalar('AndNotI64x2', 'table.CoreVectors.AndNotI64x2 := @RISCVVAndNotI64x2;');
  AssertRegisterKeepsBaseScalar('MinI64x2', 'table.CoreVectors.MinI64x2 := @RISCVVMinI64x2;');
  AssertRegisterKeepsBaseScalar('MaxI64x2', 'table.CoreVectors.MaxI64x2 := @RISCVVMaxI64x2;');
  AssertRegisterKeepsBaseScalar('AndNotU64x2', 'table.CoreVectors.AndNotU64x2 := @RISCVVAndNotU64x2;');
  AssertRegisterKeepsBaseScalar('CmpEqU64x2', 'table.CoreVectors.CmpEqU64x2 := @RISCVVCmpEqU64x2;');
  AssertRegisterKeepsBaseScalar('CmpLtU64x2', 'table.CoreVectors.CmpLtU64x2 := @RISCVVCmpLtU64x2;');
  AssertRegisterKeepsBaseScalar('CmpGtU64x2', 'table.CoreVectors.CmpGtU64x2 := @RISCVVCmpGtU64x2;');
  AssertRegisterKeepsBaseScalar('MinU64x2', 'table.CoreVectors.MinU64x2 := @RISCVVMinU64x2;');
  AssertRegisterKeepsBaseScalar('MaxU64x2', 'table.CoreVectors.MaxU64x2 := @RISCVVMaxU64x2;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('AndNotI64x2', Pointer(LScalarTable.CoreVectors.AndNotI64x2), Pointer(LRISCVVTable.CoreVectors.AndNotI64x2));
  AssertSlotReusesScalar('MinI64x2', Pointer(LScalarTable.CoreVectors.MinI64x2), Pointer(LRISCVVTable.CoreVectors.MinI64x2));
  AssertSlotReusesScalar('MaxI64x2', Pointer(LScalarTable.CoreVectors.MaxI64x2), Pointer(LRISCVVTable.CoreVectors.MaxI64x2));
  AssertSlotReusesScalar('AndNotU64x2', Pointer(LScalarTable.CoreVectors.AndNotU64x2), Pointer(LRISCVVTable.CoreVectors.AndNotU64x2));
  AssertSlotReusesScalar('CmpEqU64x2', Pointer(LScalarTable.CoreVectors.CmpEqU64x2), Pointer(LRISCVVTable.CoreVectors.CmpEqU64x2));
  AssertSlotReusesScalar('CmpLtU64x2', Pointer(LScalarTable.CoreVectors.CmpLtU64x2), Pointer(LRISCVVTable.CoreVectors.CmpLtU64x2));
  AssertSlotReusesScalar('CmpGtU64x2', Pointer(LScalarTable.CoreVectors.CmpGtU64x2), Pointer(LRISCVVTable.CoreVectors.CmpGtU64x2));
  AssertSlotReusesScalar('MinU64x2', Pointer(LScalarTable.CoreVectors.MinU64x2), Pointer(LRISCVVTable.CoreVectors.MinU64x2));
  AssertSlotReusesScalar('MaxU64x2', Pointer(LScalarTable.CoreVectors.MaxU64x2), Pointer(LRISCVVTable.CoreVectors.MaxU64x2));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_FacadeSlots_Reuse_BaseScalar_When_Wrappers_Are_ScalarPassThrough;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LUnitSourcePath: string;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LUnitSource: string;
  LRegisterSource: string;
  LFacadeSource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LUnitSource) = 0, aLabel + ' dead wrapper should be removed from the RISCVV unit interface');
    CheckTrue(Pos(LowerCase(aSnippet), LFacadeSource) = 0, aLabel + ' dead wrapper should be removed from the RISCVV facade include');
  end;

  procedure AssertRegisterKeepsBaseScalar(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0, 'RegisterRISCVVBackend should keep base scalar ' + aLabel + ' when the facade implementation is scalar pass-through');
  end;

  procedure AssertRegisterOwnsBackendSlot(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a backend-owned assignment for ' + aLabel + ' when the implementation is intentionally backend-local');
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the base scalar slot when the facade implementation is scalar pass-through');
  end;

  procedure AssertSlotKeepsBackendOwnership(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should keep a backend-owned slot when the implementation is intentionally backend-local');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LUnitSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LUnitSourcePath), 'RISCVV unit source should exist for implementation-shape audit: ' + LUnitSourcePath);
    LSourceLines.LoadFromFile(LUnitSourcePath);
    LUnitSource := LowerCase(LSourceLines.Text);

    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for implementation-shape audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('MemEqual_RISCVV', 'function MemEqual_RISCVV(');
  AssertDeadWrapperRemoved('MemFindByte_RISCVV', 'function MemFindByte_RISCVV(');
  AssertDeadWrapperRemoved('MemDiffRange_RISCVV', 'function MemDiffRange_RISCVV(');
  AssertDeadWrapperRemoved('MemCopy_RISCVV', 'procedure MemCopy_RISCVV(');
  AssertDeadWrapperRemoved('MemSet_RISCVV', 'procedure MemSet_RISCVV(');
  AssertDeadWrapperRemoved('MemReverse_RISCVV', 'procedure MemReverse_RISCVV(');
  AssertDeadWrapperRemoved('SumBytes_RISCVV', 'function SumBytes_RISCVV(');
  AssertDeadWrapperRemoved('MinMaxBytes_RISCVV', 'procedure MinMaxBytes_RISCVV(');
  AssertDeadWrapperRemoved('CountByte_RISCVV', 'function CountByte_RISCVV(');
  AssertDeadWrapperRemoved('Utf8Validate_RISCVV', 'function Utf8Validate_RISCVV(');
  AssertDeadWrapperRemoved('AsciiIEqual_RISCVV', 'function AsciiIEqual_RISCVV(');
  AssertDeadWrapperRemoved('ToLowerAscii_RISCVV', 'procedure ToLowerAscii_RISCVV(');
  AssertDeadWrapperRemoved('ToUpperAscii_RISCVV', 'procedure ToUpperAscii_RISCVV(');
  AssertDeadWrapperRemoved('BytesIndexOf_RISCVV', 'function BytesIndexOf_RISCVV(');
  AssertDeadWrapperRemoved('BitsetPopCount_RISCVV', 'function BitsetPopCount_RISCVV(');
  AssertDeadWrapperRemoved('RISCVVSelectF32x8 wide dispatch wrapper', 'function RISCVVSelectF32x8(const mask: TVecU32x8; const a, b: TVecF32x8): TVecF32x8;');
  AssertDeadWrapperRemoved('RISCVVSelectF32x8 legacy mask wrapper', 'function RISCVVSelectF32x8(const mask: TMask8; const a, b: TVecF32x8): TVecF32x8;');
  AssertDeadWrapperRemoved('RISCVVSelectF64x4 wide dispatch wrapper', 'function RISCVVSelectF64x4(const mask: TVecU64x4; const a, b: TVecF64x4): TVecF64x4;');
  AssertDeadWrapperRemoved('RISCVVSelectF64x4 legacy mask wrapper', 'function RISCVVSelectF64x4(const mask: TMask4; const a, b: TVecF64x4): TVecF64x4;');
  AssertDeadWrapperRemoved('RISCVVSelectI32x4 wide dispatch wrapper', 'function RISCVVSelectI32x4(const mask: TVecI32x4; const a, b: TVecI32x4): TVecI32x4;');
  AssertDeadWrapperRemoved('RISCVVFloorF32x4 dead wrapper', 'function RISCVVFloorF32x4(const a: TVecF32x4): TVecF32x4;');
  AssertDeadWrapperRemoved('RISCVVCeilF32x4 dead wrapper', 'function RISCVVCeilF32x4(const a: TVecF32x4): TVecF32x4;');
  AssertDeadWrapperRemoved('RISCVVRoundF32x4 dead wrapper', 'function RISCVVRoundF32x4(const a: TVecF32x4): TVecF32x4;');
  AssertDeadWrapperRemoved('RISCVVTruncF32x4 dead wrapper', 'function RISCVVTruncF32x4(const a: TVecF32x4): TVecF32x4;');
  AssertDeadWrapperRemoved('RISCVVFloorF64x2 dead wrapper', 'function RISCVVFloorF64x2(const a: TVecF64x2): TVecF64x2;');
  AssertDeadWrapperRemoved('RISCVVCeilF64x2 dead wrapper', 'function RISCVVCeilF64x2(const a: TVecF64x2): TVecF64x2;');
  AssertDeadWrapperRemoved('RISCVVRoundF64x2 dead wrapper', 'function RISCVVRoundF64x2(const a: TVecF64x2): TVecF64x2;');
  AssertDeadWrapperRemoved('RISCVVTruncF64x2 dead wrapper', 'function RISCVVTruncF64x2(const a: TVecF64x2): TVecF64x2;');

  AssertRegisterKeepsBaseScalar('MemEqual', 'table.Memory.Equal := @MemEqual_RISCVV;');
  AssertRegisterKeepsBaseScalar('MemFindByte', 'table.Memory.FindByte := @MemFindByte_RISCVV;');
  AssertRegisterKeepsBaseScalar('MemDiffRange', 'table.Memory.DiffRange := @MemDiffRange_RISCVV;');
  AssertRegisterKeepsBaseScalar('MemCopy', 'table.Memory.Copy := @MemCopy_RISCVV;');
  AssertRegisterKeepsBaseScalar('MemSet', 'table.Memory.Fill := @MemSet_RISCVV;');
  AssertRegisterKeepsBaseScalar('MemReverse', 'table.Memory.Reverse := @MemReverse_RISCVV;');
  AssertRegisterKeepsBaseScalar('SumBytes', 'table.Memory.SumBytes := @SumBytes_RISCVV;');
  AssertRegisterKeepsBaseScalar('MinMaxBytes', 'table.Memory.MinMaxBytes := @MinMaxBytes_RISCVV;');
  AssertRegisterKeepsBaseScalar('CountByte', 'table.Memory.CountByte := @CountByte_RISCVV;');
  AssertRegisterKeepsBaseScalar('Utf8Validate', 'table.Memory.Utf8Validate := @Utf8Validate_RISCVV;');
  AssertRegisterKeepsBaseScalar('AsciiIEqual', 'table.Memory.AsciiIEqual := @AsciiIEqual_RISCVV;');
  AssertRegisterKeepsBaseScalar('ToLowerAscii', 'table.Memory.ToLowerAscii := @ToLowerAscii_RISCVV;');
  AssertRegisterKeepsBaseScalar('ToUpperAscii', 'table.Memory.ToUpperAscii := @ToUpperAscii_RISCVV;');
  AssertRegisterKeepsBaseScalar('BytesIndexOf', 'table.Memory.BytesIndexOf := @BytesIndexOf_RISCVV;');
  AssertRegisterKeepsBaseScalar('BitsetPopCount', 'table.Memory.BitsetPopCount := @BitsetPopCount_RISCVV;');
  AssertRegisterKeepsBaseScalar('FloorF32x4 scalar override', 'table.CoreVectors.FloorF32x4 := @ScalarFloorF32x4;');
  AssertRegisterKeepsBaseScalar('CeilF32x4 scalar override', 'table.CoreVectors.CeilF32x4 := @ScalarCeilF32x4;');
  AssertRegisterKeepsBaseScalar('RoundF32x4 scalar override', 'table.CoreVectors.RoundF32x4 := @ScalarRoundF32x4;');
  AssertRegisterKeepsBaseScalar('TruncF32x4 scalar override', 'table.CoreVectors.TruncF32x4 := @ScalarTruncF32x4;');
  AssertRegisterKeepsBaseScalar('FloorF32x4 backend override', 'table.CoreVectors.FloorF32x4 := @RISCVVFloorF32x4;');
  AssertRegisterKeepsBaseScalar('CeilF32x4 backend override', 'table.CoreVectors.CeilF32x4 := @RISCVVCeilF32x4;');
  AssertRegisterKeepsBaseScalar('RoundF32x4 backend override', 'table.CoreVectors.RoundF32x4 := @RISCVVRoundF32x4;');
  AssertRegisterKeepsBaseScalar('TruncF32x4 backend override', 'table.CoreVectors.TruncF32x4 := @RISCVVTruncF32x4;');
  AssertRegisterKeepsBaseScalar('FloorF64x2 scalar override', 'table.CoreVectors.FloorF64x2 := @ScalarFloorF64x2;');
  AssertRegisterKeepsBaseScalar('CeilF64x2 scalar override', 'table.CoreVectors.CeilF64x2 := @ScalarCeilF64x2;');
  AssertRegisterKeepsBaseScalar('RoundF64x2 scalar override', 'table.CoreVectors.RoundF64x2 := @ScalarRoundF64x2;');
  AssertRegisterKeepsBaseScalar('TruncF64x2 scalar override', 'table.CoreVectors.TruncF64x2 := @ScalarTruncF64x2;');
  AssertRegisterKeepsBaseScalar('FloorF64x2 backend override', 'table.CoreVectors.FloorF64x2 := @RISCVVFloorF64x2;');
  AssertRegisterKeepsBaseScalar('CeilF64x2 backend override', 'table.CoreVectors.CeilF64x2 := @RISCVVCeilF64x2;');
  AssertRegisterKeepsBaseScalar('RoundF64x2 backend override', 'table.CoreVectors.RoundF64x2 := @RISCVVRoundF64x2;');
  AssertRegisterKeepsBaseScalar('TruncF64x2 backend override', 'table.CoreVectors.TruncF64x2 := @RISCVVTruncF64x2;');
  AssertRegisterKeepsBaseScalar('SelectF32x8', 'table.CoreVectors.SelectF32x8 := @RISCVVSelectF32x8;');
  AssertRegisterKeepsBaseScalar('SelectF64x4', 'table.CoreVectors.SelectF64x4 := @RISCVVSelectF64x4;');
  AssertRegisterKeepsBaseScalar('SelectI32x4', 'table.CoreVectors.SelectI32x4 := @RISCVVSelectI32x4;');
  AssertRegisterOwnsBackendSlot('AddF32x4', 'table.CoreVectors.AddF32x4 := @RISCVVAddF32x4;');
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('MemEqual', Pointer(LScalarTable.Memory.Equal), Pointer(LRISCVVTable.Memory.Equal));
  AssertSlotReusesScalar('MemFindByte', Pointer(LScalarTable.Memory.FindByte), Pointer(LRISCVVTable.Memory.FindByte));
  AssertSlotReusesScalar('MemDiffRange', Pointer(LScalarTable.Memory.DiffRange), Pointer(LRISCVVTable.Memory.DiffRange));
  AssertSlotReusesScalar('MemCopy', Pointer(LScalarTable.Memory.Copy), Pointer(LRISCVVTable.Memory.Copy));
  AssertSlotReusesScalar('MemSet', Pointer(LScalarTable.Memory.Fill), Pointer(LRISCVVTable.Memory.Fill));
  AssertSlotReusesScalar('MemReverse', Pointer(LScalarTable.Memory.Reverse), Pointer(LRISCVVTable.Memory.Reverse));
  AssertSlotReusesScalar('SumBytes', Pointer(LScalarTable.Memory.SumBytes), Pointer(LRISCVVTable.Memory.SumBytes));
  AssertSlotReusesScalar('MinMaxBytes', Pointer(LScalarTable.Memory.MinMaxBytes), Pointer(LRISCVVTable.Memory.MinMaxBytes));
  AssertSlotReusesScalar('CountByte', Pointer(LScalarTable.Memory.CountByte), Pointer(LRISCVVTable.Memory.CountByte));
  AssertSlotReusesScalar('Utf8Validate', Pointer(LScalarTable.Memory.Utf8Validate), Pointer(LRISCVVTable.Memory.Utf8Validate));
  AssertSlotReusesScalar('AsciiIEqual', Pointer(LScalarTable.Memory.AsciiIEqual), Pointer(LRISCVVTable.Memory.AsciiIEqual));
  AssertSlotReusesScalar('ToLowerAscii', Pointer(LScalarTable.Memory.ToLowerAscii), Pointer(LRISCVVTable.Memory.ToLowerAscii));
  AssertSlotReusesScalar('ToUpperAscii', Pointer(LScalarTable.Memory.ToUpperAscii), Pointer(LRISCVVTable.Memory.ToUpperAscii));
  AssertSlotReusesScalar('BytesIndexOf', Pointer(LScalarTable.Memory.BytesIndexOf), Pointer(LRISCVVTable.Memory.BytesIndexOf));
  AssertSlotReusesScalar('BitsetPopCount', Pointer(LScalarTable.Memory.BitsetPopCount), Pointer(LRISCVVTable.Memory.BitsetPopCount));
  AssertSlotReusesScalar('FloorF32x4', Pointer(LScalarTable.CoreVectors.FloorF32x4), Pointer(LRISCVVTable.CoreVectors.FloorF32x4));
  AssertSlotReusesScalar('CeilF32x4', Pointer(LScalarTable.CoreVectors.CeilF32x4), Pointer(LRISCVVTable.CoreVectors.CeilF32x4));
  AssertSlotReusesScalar('RoundF32x4', Pointer(LScalarTable.CoreVectors.RoundF32x4), Pointer(LRISCVVTable.CoreVectors.RoundF32x4));
  AssertSlotReusesScalar('TruncF32x4', Pointer(LScalarTable.CoreVectors.TruncF32x4), Pointer(LRISCVVTable.CoreVectors.TruncF32x4));
  AssertSlotReusesScalar('FloorF64x2', Pointer(LScalarTable.CoreVectors.FloorF64x2), Pointer(LRISCVVTable.CoreVectors.FloorF64x2));
  AssertSlotReusesScalar('CeilF64x2', Pointer(LScalarTable.CoreVectors.CeilF64x2), Pointer(LRISCVVTable.CoreVectors.CeilF64x2));
  AssertSlotReusesScalar('RoundF64x2', Pointer(LScalarTable.CoreVectors.RoundF64x2), Pointer(LRISCVVTable.CoreVectors.RoundF64x2));
  AssertSlotReusesScalar('TruncF64x2', Pointer(LScalarTable.CoreVectors.TruncF64x2), Pointer(LRISCVVTable.CoreVectors.TruncF64x2));
  AssertSlotReusesScalar('SelectF32x8', Pointer(LScalarTable.CoreVectors.SelectF32x8), Pointer(LRISCVVTable.CoreVectors.SelectF32x8));
  AssertSlotReusesScalar('SelectF64x4', Pointer(LScalarTable.CoreVectors.SelectF64x4), Pointer(LRISCVVTable.CoreVectors.SelectF64x4));
  AssertSlotReusesScalar('SelectI32x4', Pointer(LScalarTable.CoreVectors.SelectI32x4), Pointer(LRISCVVTable.CoreVectors.SelectI32x4));
  {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
  AssertSlotKeepsBackendOwnership('AddF32x4', Pointer(LScalarTable.CoreVectors.AddF32x4), Pointer(LRISCVVTable.CoreVectors.AddF32x4));
  {$ELSE}
  AssertSlotReusesScalar('AddF32x4', Pointer(LScalarTable.CoreVectors.AddF32x4), Pointer(LRISCVVTable.CoreVectors.AddF32x4));
  {$ENDIF}
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_MemoryBatch_Intentionally_Scalar_Until_RealLeaf;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LUnitSourcePath: string;
  LFacadeSourcePath: string;
  LHelperSourcePath: string;
  LRegisterSource: string;
  LUnitSource: string;
  LFacadeSource: string;
  LHelperSource: string;

  procedure AssertNoGroupOverride(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0,
      'RegisterRISCVVBackend must not override ' + aLabel +
      ' until a real RVV Memory/Batch leaf exists (Phase 24a honesty)');
  end;

  procedure AssertDeadBatchOrMemoryWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LUnitSource) = 0,
      aLabel + ' must not exist in riscvv.pas (no dead Memory/Batch native claim)');
    CheckTrue(Pos(LowerCase(aSnippet), LFacadeSource) = 0,
      aLabel + ' must not exist in riscvv.facade.inc (no dead Memory/Batch native claim)');
    CheckTrue(Pos(LowerCase(aSnippet), LHelperSource) = 0,
      aLabel + ' must not exist in riscvv.helpers.inc (no dead Memory/Batch native claim)');
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot),
      'RISCVV ' + aLabel + ' must reuse the base scalar slot until a real RVV leaf owns it');
  end;
begin
  // Phase 24a honesty matrix (software-only):
  // RVV Memory (15) and all Batch* groups intentionally inherit FillBaseDispatchTable
  // scalar baseline. No Mem*_RISCVV / RISCVVArray* dead wrappers, no register overrides.
  // Real leaves require S24b (hardware/QEMU evidence).
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for Memory/Batch honesty audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LUnitSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LUnitSourcePath), 'RISCVV unit source should exist for Memory/Batch honesty audit: ' + LUnitSourcePath);
    LSourceLines.LoadFromFile(LUnitSourcePath);
    LUnitSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for Memory/Batch honesty audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LHelperSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.helpers.inc');
    CheckTrue(FileExists(LHelperSourcePath), 'RISCVV helper source should exist for Memory/Batch honesty audit: ' + LHelperSourcePath);
    LSourceLines.LoadFromFile(LHelperSourcePath);
    LHelperSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertNoGroupOverride('Memory group', 'table.memory.');
  AssertNoGroupOverride('BatchF32 group', 'table.batchf32.');
  AssertNoGroupOverride('BatchF64 group', 'table.batchf64.');
  AssertNoGroupOverride('BatchInteger group', 'table.batchinteger.');

  AssertDeadBatchOrMemoryWrapperRemoved('MemEqual_RISCVV', 'function MemEqual_RISCVV(');
  AssertDeadBatchOrMemoryWrapperRemoved('MemCopy_RISCVV', 'procedure MemCopy_RISCVV(');
  AssertDeadBatchOrMemoryWrapperRemoved('MemSet_RISCVV', 'procedure MemSet_RISCVV(');
  AssertDeadBatchOrMemoryWrapperRemoved('RISCVVArrayAddF32', 'procedure RISCVVArrayAddF32(');
  AssertDeadBatchOrMemoryWrapperRemoved('RISCVVArrayMulF32', 'procedure RISCVVArrayMulF32(');
  AssertDeadBatchOrMemoryWrapperRemoved('RISCVVArrayAddF64', 'procedure RISCVVArrayAddF64(');
  AssertDeadBatchOrMemoryWrapperRemoved('RISCVVArrayAddI32', 'procedure RISCVVArrayAddI32(');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  // Memory 15/15 intentionally scalar
  AssertSlotReusesScalar('Memory.Equal', Pointer(LScalarTable.Memory.Equal), Pointer(LRISCVVTable.Memory.Equal));
  AssertSlotReusesScalar('Memory.FindByte', Pointer(LScalarTable.Memory.FindByte), Pointer(LRISCVVTable.Memory.FindByte));
  AssertSlotReusesScalar('Memory.DiffRange', Pointer(LScalarTable.Memory.DiffRange), Pointer(LRISCVVTable.Memory.DiffRange));
  AssertSlotReusesScalar('Memory.Copy', Pointer(LScalarTable.Memory.Copy), Pointer(LRISCVVTable.Memory.Copy));
  AssertSlotReusesScalar('Memory.Fill', Pointer(LScalarTable.Memory.Fill), Pointer(LRISCVVTable.Memory.Fill));
  AssertSlotReusesScalar('Memory.Reverse', Pointer(LScalarTable.Memory.Reverse), Pointer(LRISCVVTable.Memory.Reverse));
  AssertSlotReusesScalar('Memory.SumBytes', Pointer(LScalarTable.Memory.SumBytes), Pointer(LRISCVVTable.Memory.SumBytes));
  AssertSlotReusesScalar('Memory.MinMaxBytes', Pointer(LScalarTable.Memory.MinMaxBytes), Pointer(LRISCVVTable.Memory.MinMaxBytes));
  AssertSlotReusesScalar('Memory.CountByte', Pointer(LScalarTable.Memory.CountByte), Pointer(LRISCVVTable.Memory.CountByte));
  AssertSlotReusesScalar('Memory.Utf8Validate', Pointer(LScalarTable.Memory.Utf8Validate), Pointer(LRISCVVTable.Memory.Utf8Validate));
  AssertSlotReusesScalar('Memory.AsciiIEqual', Pointer(LScalarTable.Memory.AsciiIEqual), Pointer(LRISCVVTable.Memory.AsciiIEqual));
  AssertSlotReusesScalar('Memory.ToLowerAscii', Pointer(LScalarTable.Memory.ToLowerAscii), Pointer(LRISCVVTable.Memory.ToLowerAscii));
  AssertSlotReusesScalar('Memory.ToUpperAscii', Pointer(LScalarTable.Memory.ToUpperAscii), Pointer(LRISCVVTable.Memory.ToUpperAscii));
  AssertSlotReusesScalar('Memory.BytesIndexOf', Pointer(LScalarTable.Memory.BytesIndexOf), Pointer(LRISCVVTable.Memory.BytesIndexOf));
  AssertSlotReusesScalar('Memory.BitsetPopCount', Pointer(LScalarTable.Memory.BitsetPopCount), Pointer(LRISCVVTable.Memory.BitsetPopCount));

  // Batch representative set intentionally scalar (full groups inherit baseline)
  AssertSlotReusesScalar('BatchF32.ArrayAdd', Pointer(LScalarTable.BatchF32.ArrayAdd), Pointer(LRISCVVTable.BatchF32.ArrayAdd));
  AssertSlotReusesScalar('BatchF32.ArraySub', Pointer(LScalarTable.BatchF32.ArraySub), Pointer(LRISCVVTable.BatchF32.ArraySub));
  AssertSlotReusesScalar('BatchF32.ArrayMul', Pointer(LScalarTable.BatchF32.ArrayMul), Pointer(LRISCVVTable.BatchF32.ArrayMul));
  AssertSlotReusesScalar('BatchF32.ArrayMin', Pointer(LScalarTable.BatchF32.ArrayMin), Pointer(LRISCVVTable.BatchF32.ArrayMin));
  AssertSlotReusesScalar('BatchF32.ArrayMax', Pointer(LScalarTable.BatchF32.ArrayMax), Pointer(LRISCVVTable.BatchF32.ArrayMax));
  AssertSlotReusesScalar('BatchF32.ArrayAbs', Pointer(LScalarTable.BatchF32.ArrayAbs), Pointer(LRISCVVTable.BatchF32.ArrayAbs));
  AssertSlotReusesScalar('BatchF32.ArrayNeg', Pointer(LScalarTable.BatchF32.ArrayNeg), Pointer(LRISCVVTable.BatchF32.ArrayNeg));
  AssertSlotReusesScalar('BatchF32.ArrayDiv', Pointer(LScalarTable.BatchF32.ArrayDiv), Pointer(LRISCVVTable.BatchF32.ArrayDiv));
  AssertSlotReusesScalar('BatchF32.ArraySqrt', Pointer(LScalarTable.BatchF32.ArraySqrt), Pointer(LRISCVVTable.BatchF32.ArraySqrt));
  AssertSlotReusesScalar('BatchF32.ArraySin', Pointer(LScalarTable.BatchF32.ArraySin), Pointer(LRISCVVTable.BatchF32.ArraySin));
  AssertSlotReusesScalar('BatchF32.ReduceSum', Pointer(LScalarTable.BatchF32.ReduceSum), Pointer(LRISCVVTable.BatchF32.ReduceSum));
  AssertSlotReusesScalar('BatchF64.ArrayAdd', Pointer(LScalarTable.BatchF64.ArrayAdd), Pointer(LRISCVVTable.BatchF64.ArrayAdd));
  AssertSlotReusesScalar('BatchF64.ArrayMul', Pointer(LScalarTable.BatchF64.ArrayMul), Pointer(LRISCVVTable.BatchF64.ArrayMul));
  AssertSlotReusesScalar('BatchF64.ArraySin', Pointer(LScalarTable.BatchF64.ArraySin), Pointer(LRISCVVTable.BatchF64.ArraySin));
  AssertSlotReusesScalar('BatchInteger.ArrayAddI32', Pointer(LScalarTable.BatchInteger.ArrayAddI32), Pointer(LRISCVVTable.BatchInteger.ArrayAddI32));
  AssertSlotReusesScalar('BatchInteger.ArrayMulI16', Pointer(LScalarTable.BatchInteger.ArrayMulI16), Pointer(LRISCVVTable.BatchInteger.ArrayMulI16));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_WideFallbackOnlySlots_Reuse_BaseScalar_When_Wrappers_Are_Only_ScalarForwarders;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LFacadeSource) = 0, aLabel + ' dead wrapper should be removed from the RISCVV facade include');
  end;

  procedure AssertRegisterKeepsBaseScalar(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0, 'RegisterRISCVVBackend should keep base scalar ' + aLabel + ' when the RISCVV wrapper is only a scalar forwarder');
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the base scalar slot when the RISCVV wrapper is only a scalar forwarder');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for implementation-shape audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('RISCVVDotF32x8', 'function RISCVVDotF32x8(');
  AssertDeadWrapperRemoved('RISCVVAddI16x32', 'function RISCVVAddI16x32(');
  AssertDeadWrapperRemoved('RISCVVSubI16x32', 'function RISCVVSubI16x32(');
  AssertDeadWrapperRemoved('RISCVVAndI16x32', 'function RISCVVAndI16x32(');
  AssertDeadWrapperRemoved('RISCVVOrI16x32', 'function RISCVVOrI16x32(');
  AssertDeadWrapperRemoved('RISCVVXorI16x32', 'function RISCVVXorI16x32(');
  AssertDeadWrapperRemoved('RISCVVNotI16x32', 'function RISCVVNotI16x32(');
  AssertDeadWrapperRemoved('RISCVVAndNotI16x32', 'function RISCVVAndNotI16x32(');
  AssertDeadWrapperRemoved('RISCVVCmpEqI16x32', 'function RISCVVCmpEqI16x32(');
  AssertDeadWrapperRemoved('RISCVVCmpLtI16x32', 'function RISCVVCmpLtI16x32(');
  AssertDeadWrapperRemoved('RISCVVCmpGtI16x32', 'function RISCVVCmpGtI16x32(');
  AssertDeadWrapperRemoved('RISCVVMinI16x32', 'function RISCVVMinI16x32(');
  AssertDeadWrapperRemoved('RISCVVMaxI16x32', 'function RISCVVMaxI16x32(');
  AssertDeadWrapperRemoved('RISCVVShiftLeftI16x32', 'function RISCVVShiftLeftI16x32(');
  AssertDeadWrapperRemoved('RISCVVShiftRightI16x32', 'function RISCVVShiftRightI16x32(');
  AssertDeadWrapperRemoved('RISCVVShiftRightArithI16x32', 'function RISCVVShiftRightArithI16x32(');
  AssertDeadWrapperRemoved('RISCVVAddI8x64', 'function RISCVVAddI8x64(');
  AssertDeadWrapperRemoved('RISCVVSubI8x64', 'function RISCVVSubI8x64(');
  AssertDeadWrapperRemoved('RISCVVAndI8x64', 'function RISCVVAndI8x64(');
  AssertDeadWrapperRemoved('RISCVVOrI8x64', 'function RISCVVOrI8x64(');
  AssertDeadWrapperRemoved('RISCVVXorI8x64', 'function RISCVVXorI8x64(');
  AssertDeadWrapperRemoved('RISCVVNotI8x64', 'function RISCVVNotI8x64(');
  AssertDeadWrapperRemoved('RISCVVAndNotI8x64', 'function RISCVVAndNotI8x64(');
  AssertDeadWrapperRemoved('RISCVVCmpEqI8x64', 'function RISCVVCmpEqI8x64(');
  AssertDeadWrapperRemoved('RISCVVCmpLtI8x64', 'function RISCVVCmpLtI8x64(');
  AssertDeadWrapperRemoved('RISCVVCmpGtI8x64', 'function RISCVVCmpGtI8x64(');
  AssertDeadWrapperRemoved('RISCVVMinI8x64', 'function RISCVVMinI8x64(');
  AssertDeadWrapperRemoved('RISCVVMaxI8x64', 'function RISCVVMaxI8x64(');
  AssertDeadWrapperRemoved('RISCVVAddU8x64', 'function RISCVVAddU8x64(');
  AssertDeadWrapperRemoved('RISCVVSubU8x64', 'function RISCVVSubU8x64(');
  AssertDeadWrapperRemoved('RISCVVAndU8x64', 'function RISCVVAndU8x64(');
  AssertDeadWrapperRemoved('RISCVVOrU8x64', 'function RISCVVOrU8x64(');
  AssertDeadWrapperRemoved('RISCVVXorU8x64', 'function RISCVVXorU8x64(');
  AssertDeadWrapperRemoved('RISCVVNotU8x64', 'function RISCVVNotU8x64(');
  AssertDeadWrapperRemoved('RISCVVCmpEqU8x64', 'function RISCVVCmpEqU8x64(');
  AssertDeadWrapperRemoved('RISCVVCmpLtU8x64', 'function RISCVVCmpLtU8x64(');
  AssertDeadWrapperRemoved('RISCVVCmpGtU8x64', 'function RISCVVCmpGtU8x64(');
  AssertDeadWrapperRemoved('RISCVVMinU8x64', 'function RISCVVMinU8x64(');
  AssertDeadWrapperRemoved('RISCVVMaxU8x64', 'function RISCVVMaxU8x64(');
  AssertDeadWrapperRemoved('RISCVVAddU32x16', 'function RISCVVAddU32x16(');
  AssertDeadWrapperRemoved('RISCVVSubU32x16', 'function RISCVVSubU32x16(');
  AssertDeadWrapperRemoved('RISCVVMulU32x16', 'function RISCVVMulU32x16(');
  AssertDeadWrapperRemoved('RISCVVAndU32x16', 'function RISCVVAndU32x16(');
  AssertDeadWrapperRemoved('RISCVVOrU32x16', 'function RISCVVOrU32x16(');
  AssertDeadWrapperRemoved('RISCVVXorU32x16', 'function RISCVVXorU32x16(');
  AssertDeadWrapperRemoved('RISCVVNotU32x16', 'function RISCVVNotU32x16(');
  AssertDeadWrapperRemoved('RISCVVAndNotU32x16', 'function RISCVVAndNotU32x16(');
  AssertDeadWrapperRemoved('RISCVVShiftLeftU32x16', 'function RISCVVShiftLeftU32x16(');
  AssertDeadWrapperRemoved('RISCVVShiftRightU32x16', 'function RISCVVShiftRightU32x16(');
  AssertDeadWrapperRemoved('RISCVVCmpEqU32x16', 'function RISCVVCmpEqU32x16(');
  AssertDeadWrapperRemoved('RISCVVCmpLtU32x16', 'function RISCVVCmpLtU32x16(');
  AssertDeadWrapperRemoved('RISCVVCmpGtU32x16', 'function RISCVVCmpGtU32x16(');
  AssertDeadWrapperRemoved('RISCVVCmpLeU32x16', 'function RISCVVCmpLeU32x16(');
  AssertDeadWrapperRemoved('RISCVVCmpGeU32x16', 'function RISCVVCmpGeU32x16(');
  AssertDeadWrapperRemoved('RISCVVCmpNeU32x16', 'function RISCVVCmpNeU32x16(');
  AssertDeadWrapperRemoved('RISCVVMinU32x16', 'function RISCVVMinU32x16(');
  AssertDeadWrapperRemoved('RISCVVMaxU32x16', 'function RISCVVMaxU32x16(');
  AssertDeadWrapperRemoved('RISCVVAddU64x8', 'function RISCVVAddU64x8(');
  AssertDeadWrapperRemoved('RISCVVSubU64x8', 'function RISCVVSubU64x8(');
  AssertDeadWrapperRemoved('RISCVVAndU64x8', 'function RISCVVAndU64x8(');
  AssertDeadWrapperRemoved('RISCVVOrU64x8', 'function RISCVVOrU64x8(');
  AssertDeadWrapperRemoved('RISCVVXorU64x8', 'function RISCVVXorU64x8(');
  AssertDeadWrapperRemoved('RISCVVNotU64x8', 'function RISCVVNotU64x8(');
  AssertDeadWrapperRemoved('RISCVVShiftLeftU64x8', 'function RISCVVShiftLeftU64x8(');
  AssertDeadWrapperRemoved('RISCVVShiftRightU64x8', 'function RISCVVShiftRightU64x8(');
  AssertDeadWrapperRemoved('RISCVVCmpEqU64x8', 'function RISCVVCmpEqU64x8(');
  AssertDeadWrapperRemoved('RISCVVCmpLtU64x8', 'function RISCVVCmpLtU64x8(');
  AssertDeadWrapperRemoved('RISCVVCmpGtU64x8', 'function RISCVVCmpGtU64x8(');
  AssertDeadWrapperRemoved('RISCVVCmpLeU64x8', 'function RISCVVCmpLeU64x8(');
  AssertDeadWrapperRemoved('RISCVVCmpGeU64x8', 'function RISCVVCmpGeU64x8(');
  AssertDeadWrapperRemoved('RISCVVCmpNeU64x8', 'function RISCVVCmpNeU64x8(');

  AssertRegisterKeepsBaseScalar('DotF32x8', 'table.CoreVectors.DotF32x8 := @RISCVVDotF32x8;');
  AssertRegisterKeepsBaseScalar('AddI16x32', 'table.CoreVectors.AddI16x32 := @RISCVVAddI16x32;');
  AssertRegisterKeepsBaseScalar('SubI16x32', 'table.CoreVectors.SubI16x32 := @RISCVVSubI16x32;');
  AssertRegisterKeepsBaseScalar('AndI16x32', 'table.CoreVectors.AndI16x32 := @RISCVVAndI16x32;');
  AssertRegisterKeepsBaseScalar('OrI16x32', 'table.CoreVectors.OrI16x32 := @RISCVVOrI16x32;');
  AssertRegisterKeepsBaseScalar('XorI16x32', 'table.CoreVectors.XorI16x32 := @RISCVVXorI16x32;');
  AssertRegisterKeepsBaseScalar('NotI16x32', 'table.CoreVectors.NotI16x32 := @RISCVVNotI16x32;');
  AssertRegisterKeepsBaseScalar('AndNotI16x32', 'table.CoreVectors.AndNotI16x32 := @RISCVVAndNotI16x32;');
  AssertRegisterKeepsBaseScalar('CmpEqI16x32', 'table.CoreVectors.CmpEqI16x32 := @RISCVVCmpEqI16x32;');
  AssertRegisterKeepsBaseScalar('CmpLtI16x32', 'table.CoreVectors.CmpLtI16x32 := @RISCVVCmpLtI16x32;');
  AssertRegisterKeepsBaseScalar('CmpGtI16x32', 'table.CoreVectors.CmpGtI16x32 := @RISCVVCmpGtI16x32;');
  AssertRegisterKeepsBaseScalar('MinI16x32', 'table.CoreVectors.MinI16x32 := @RISCVVMinI16x32;');
  AssertRegisterKeepsBaseScalar('MaxI16x32', 'table.CoreVectors.MaxI16x32 := @RISCVVMaxI16x32;');
  AssertRegisterKeepsBaseScalar('ShiftLeftI16x32', 'table.CoreVectors.ShiftLeftI16x32 := @RISCVVShiftLeftI16x32;');
  AssertRegisterKeepsBaseScalar('ShiftRightI16x32', 'table.CoreVectors.ShiftRightI16x32 := @RISCVVShiftRightI16x32;');
  AssertRegisterKeepsBaseScalar('ShiftRightArithI16x32', 'table.CoreVectors.ShiftRightArithI16x32 := @RISCVVShiftRightArithI16x32;');
  AssertRegisterKeepsBaseScalar('AddI8x64', 'table.CoreVectors.AddI8x64 := @RISCVVAddI8x64;');
  AssertRegisterKeepsBaseScalar('SubI8x64', 'table.CoreVectors.SubI8x64 := @RISCVVSubI8x64;');
  AssertRegisterKeepsBaseScalar('AndI8x64', 'table.CoreVectors.AndI8x64 := @RISCVVAndI8x64;');
  AssertRegisterKeepsBaseScalar('OrI8x64', 'table.CoreVectors.OrI8x64 := @RISCVVOrI8x64;');
  AssertRegisterKeepsBaseScalar('XorI8x64', 'table.CoreVectors.XorI8x64 := @RISCVVXorI8x64;');
  AssertRegisterKeepsBaseScalar('NotI8x64', 'table.CoreVectors.NotI8x64 := @RISCVVNotI8x64;');
  AssertRegisterKeepsBaseScalar('AndNotI8x64', 'table.CoreVectors.AndNotI8x64 := @RISCVVAndNotI8x64;');
  AssertRegisterKeepsBaseScalar('CmpEqI8x64', 'table.CoreVectors.CmpEqI8x64 := @RISCVVCmpEqI8x64;');
  AssertRegisterKeepsBaseScalar('CmpLtI8x64', 'table.CoreVectors.CmpLtI8x64 := @RISCVVCmpLtI8x64;');
  AssertRegisterKeepsBaseScalar('CmpGtI8x64', 'table.CoreVectors.CmpGtI8x64 := @RISCVVCmpGtI8x64;');
  AssertRegisterKeepsBaseScalar('MinI8x64', 'table.CoreVectors.MinI8x64 := @RISCVVMinI8x64;');
  AssertRegisterKeepsBaseScalar('MaxI8x64', 'table.CoreVectors.MaxI8x64 := @RISCVVMaxI8x64;');
  AssertRegisterKeepsBaseScalar('AddU8x64', 'table.CoreVectors.AddU8x64 := @RISCVVAddU8x64;');
  AssertRegisterKeepsBaseScalar('SubU8x64', 'table.CoreVectors.SubU8x64 := @RISCVVSubU8x64;');
  AssertRegisterKeepsBaseScalar('AndU8x64', 'table.CoreVectors.AndU8x64 := @RISCVVAndU8x64;');
  AssertRegisterKeepsBaseScalar('OrU8x64', 'table.CoreVectors.OrU8x64 := @RISCVVOrU8x64;');
  AssertRegisterKeepsBaseScalar('XorU8x64', 'table.CoreVectors.XorU8x64 := @RISCVVXorU8x64;');
  AssertRegisterKeepsBaseScalar('NotU8x64', 'table.CoreVectors.NotU8x64 := @RISCVVNotU8x64;');
  AssertRegisterKeepsBaseScalar('CmpEqU8x64', 'table.CoreVectors.CmpEqU8x64 := @RISCVVCmpEqU8x64;');
  AssertRegisterKeepsBaseScalar('CmpLtU8x64', 'table.CoreVectors.CmpLtU8x64 := @RISCVVCmpLtU8x64;');
  AssertRegisterKeepsBaseScalar('CmpGtU8x64', 'table.CoreVectors.CmpGtU8x64 := @RISCVVCmpGtU8x64;');
  AssertRegisterKeepsBaseScalar('MinU8x64', 'table.CoreVectors.MinU8x64 := @RISCVVMinU8x64;');
  AssertRegisterKeepsBaseScalar('MaxU8x64', 'table.CoreVectors.MaxU8x64 := @RISCVVMaxU8x64;');
  AssertRegisterKeepsBaseScalar('AddU32x16', 'table.CoreVectors.AddU32x16 := @RISCVVAddU32x16;');
  AssertRegisterKeepsBaseScalar('SubU32x16', 'table.CoreVectors.SubU32x16 := @RISCVVSubU32x16;');
  AssertRegisterKeepsBaseScalar('MulU32x16', 'table.CoreVectors.MulU32x16 := @RISCVVMulU32x16;');
  AssertRegisterKeepsBaseScalar('AndU32x16', 'table.CoreVectors.AndU32x16 := @RISCVVAndU32x16;');
  AssertRegisterKeepsBaseScalar('OrU32x16', 'table.CoreVectors.OrU32x16 := @RISCVVOrU32x16;');
  AssertRegisterKeepsBaseScalar('XorU32x16', 'table.CoreVectors.XorU32x16 := @RISCVVXorU32x16;');
  AssertRegisterKeepsBaseScalar('NotU32x16', 'table.CoreVectors.NotU32x16 := @RISCVVNotU32x16;');
  AssertRegisterKeepsBaseScalar('AndNotU32x16', 'table.CoreVectors.AndNotU32x16 := @RISCVVAndNotU32x16;');
  AssertRegisterKeepsBaseScalar('ShiftLeftU32x16', 'table.CoreVectors.ShiftLeftU32x16 := @RISCVVShiftLeftU32x16;');
  AssertRegisterKeepsBaseScalar('ShiftRightU32x16', 'table.CoreVectors.ShiftRightU32x16 := @RISCVVShiftRightU32x16;');
  AssertRegisterKeepsBaseScalar('CmpEqU32x16', 'table.CoreVectors.CmpEqU32x16 := @RISCVVCmpEqU32x16;');
  AssertRegisterKeepsBaseScalar('CmpLtU32x16', 'table.CoreVectors.CmpLtU32x16 := @RISCVVCmpLtU32x16;');
  AssertRegisterKeepsBaseScalar('CmpGtU32x16', 'table.CoreVectors.CmpGtU32x16 := @RISCVVCmpGtU32x16;');
  AssertRegisterKeepsBaseScalar('CmpLeU32x16', 'table.CoreVectors.CmpLeU32x16 := @RISCVVCmpLeU32x16;');
  AssertRegisterKeepsBaseScalar('CmpGeU32x16', 'table.CoreVectors.CmpGeU32x16 := @RISCVVCmpGeU32x16;');
  AssertRegisterKeepsBaseScalar('CmpNeU32x16', 'table.CoreVectors.CmpNeU32x16 := @RISCVVCmpNeU32x16;');
  AssertRegisterKeepsBaseScalar('MinU32x16', 'table.CoreVectors.MinU32x16 := @RISCVVMinU32x16;');
  AssertRegisterKeepsBaseScalar('MaxU32x16', 'table.CoreVectors.MaxU32x16 := @RISCVVMaxU32x16;');
  AssertRegisterKeepsBaseScalar('AddU64x8', 'table.CoreVectors.AddU64x8 := @RISCVVAddU64x8;');
  AssertRegisterKeepsBaseScalar('SubU64x8', 'table.CoreVectors.SubU64x8 := @RISCVVSubU64x8;');
  AssertRegisterKeepsBaseScalar('AndU64x8', 'table.CoreVectors.AndU64x8 := @RISCVVAndU64x8;');
  AssertRegisterKeepsBaseScalar('OrU64x8', 'table.CoreVectors.OrU64x8 := @RISCVVOrU64x8;');
  AssertRegisterKeepsBaseScalar('XorU64x8', 'table.CoreVectors.XorU64x8 := @RISCVVXorU64x8;');
  AssertRegisterKeepsBaseScalar('NotU64x8', 'table.CoreVectors.NotU64x8 := @RISCVVNotU64x8;');
  AssertRegisterKeepsBaseScalar('ShiftLeftU64x8', 'table.CoreVectors.ShiftLeftU64x8 := @RISCVVShiftLeftU64x8;');
  AssertRegisterKeepsBaseScalar('ShiftRightU64x8', 'table.CoreVectors.ShiftRightU64x8 := @RISCVVShiftRightU64x8;');
  AssertRegisterKeepsBaseScalar('CmpEqU64x8', 'table.CoreVectors.CmpEqU64x8 := @RISCVVCmpEqU64x8;');
  AssertRegisterKeepsBaseScalar('CmpLtU64x8', 'table.CoreVectors.CmpLtU64x8 := @RISCVVCmpLtU64x8;');
  AssertRegisterKeepsBaseScalar('CmpGtU64x8', 'table.CoreVectors.CmpGtU64x8 := @RISCVVCmpGtU64x8;');
  AssertRegisterKeepsBaseScalar('CmpLeU64x8', 'table.CoreVectors.CmpLeU64x8 := @RISCVVCmpLeU64x8;');
  AssertRegisterKeepsBaseScalar('CmpGeU64x8', 'table.CoreVectors.CmpGeU64x8 := @RISCVVCmpGeU64x8;');
  AssertRegisterKeepsBaseScalar('CmpNeU64x8', 'table.CoreVectors.CmpNeU64x8 := @RISCVVCmpNeU64x8;');
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('DotF32x8', Pointer(LScalarTable.CoreVectors.DotF32x8), Pointer(LRISCVVTable.CoreVectors.DotF32x8));
  AssertSlotReusesScalar('AddI16x32', Pointer(LScalarTable.CoreVectors.AddI16x32), Pointer(LRISCVVTable.CoreVectors.AddI16x32));
  AssertSlotReusesScalar('SubI16x32', Pointer(LScalarTable.CoreVectors.SubI16x32), Pointer(LRISCVVTable.CoreVectors.SubI16x32));
  AssertSlotReusesScalar('AndI16x32', Pointer(LScalarTable.CoreVectors.AndI16x32), Pointer(LRISCVVTable.CoreVectors.AndI16x32));
  AssertSlotReusesScalar('OrI16x32', Pointer(LScalarTable.CoreVectors.OrI16x32), Pointer(LRISCVVTable.CoreVectors.OrI16x32));
  AssertSlotReusesScalar('XorI16x32', Pointer(LScalarTable.CoreVectors.XorI16x32), Pointer(LRISCVVTable.CoreVectors.XorI16x32));
  AssertSlotReusesScalar('NotI16x32', Pointer(LScalarTable.CoreVectors.NotI16x32), Pointer(LRISCVVTable.CoreVectors.NotI16x32));
  AssertSlotReusesScalar('AndNotI16x32', Pointer(LScalarTable.CoreVectors.AndNotI16x32), Pointer(LRISCVVTable.CoreVectors.AndNotI16x32));
  AssertSlotReusesScalar('CmpEqI16x32', Pointer(LScalarTable.CoreVectors.CmpEqI16x32), Pointer(LRISCVVTable.CoreVectors.CmpEqI16x32));
  AssertSlotReusesScalar('CmpLtI16x32', Pointer(LScalarTable.CoreVectors.CmpLtI16x32), Pointer(LRISCVVTable.CoreVectors.CmpLtI16x32));
  AssertSlotReusesScalar('CmpGtI16x32', Pointer(LScalarTable.CoreVectors.CmpGtI16x32), Pointer(LRISCVVTable.CoreVectors.CmpGtI16x32));
  AssertSlotReusesScalar('MinI16x32', Pointer(LScalarTable.CoreVectors.MinI16x32), Pointer(LRISCVVTable.CoreVectors.MinI16x32));
  AssertSlotReusesScalar('MaxI16x32', Pointer(LScalarTable.CoreVectors.MaxI16x32), Pointer(LRISCVVTable.CoreVectors.MaxI16x32));
  AssertSlotReusesScalar('ShiftLeftI16x32', Pointer(LScalarTable.CoreVectors.ShiftLeftI16x32), Pointer(LRISCVVTable.CoreVectors.ShiftLeftI16x32));
  AssertSlotReusesScalar('ShiftRightI16x32', Pointer(LScalarTable.CoreVectors.ShiftRightI16x32), Pointer(LRISCVVTable.CoreVectors.ShiftRightI16x32));
  AssertSlotReusesScalar('ShiftRightArithI16x32', Pointer(LScalarTable.CoreVectors.ShiftRightArithI16x32), Pointer(LRISCVVTable.CoreVectors.ShiftRightArithI16x32));
  AssertSlotReusesScalar('AddI8x64', Pointer(LScalarTable.CoreVectors.AddI8x64), Pointer(LRISCVVTable.CoreVectors.AddI8x64));
  AssertSlotReusesScalar('SubI8x64', Pointer(LScalarTable.CoreVectors.SubI8x64), Pointer(LRISCVVTable.CoreVectors.SubI8x64));
  AssertSlotReusesScalar('AndI8x64', Pointer(LScalarTable.CoreVectors.AndI8x64), Pointer(LRISCVVTable.CoreVectors.AndI8x64));
  AssertSlotReusesScalar('OrI8x64', Pointer(LScalarTable.CoreVectors.OrI8x64), Pointer(LRISCVVTable.CoreVectors.OrI8x64));
  AssertSlotReusesScalar('XorI8x64', Pointer(LScalarTable.CoreVectors.XorI8x64), Pointer(LRISCVVTable.CoreVectors.XorI8x64));
  AssertSlotReusesScalar('NotI8x64', Pointer(LScalarTable.CoreVectors.NotI8x64), Pointer(LRISCVVTable.CoreVectors.NotI8x64));
  AssertSlotReusesScalar('AndNotI8x64', Pointer(LScalarTable.CoreVectors.AndNotI8x64), Pointer(LRISCVVTable.CoreVectors.AndNotI8x64));
  AssertSlotReusesScalar('CmpEqI8x64', Pointer(LScalarTable.CoreVectors.CmpEqI8x64), Pointer(LRISCVVTable.CoreVectors.CmpEqI8x64));
  AssertSlotReusesScalar('CmpLtI8x64', Pointer(LScalarTable.CoreVectors.CmpLtI8x64), Pointer(LRISCVVTable.CoreVectors.CmpLtI8x64));
  AssertSlotReusesScalar('CmpGtI8x64', Pointer(LScalarTable.CoreVectors.CmpGtI8x64), Pointer(LRISCVVTable.CoreVectors.CmpGtI8x64));
  AssertSlotReusesScalar('MinI8x64', Pointer(LScalarTable.CoreVectors.MinI8x64), Pointer(LRISCVVTable.CoreVectors.MinI8x64));
  AssertSlotReusesScalar('MaxI8x64', Pointer(LScalarTable.CoreVectors.MaxI8x64), Pointer(LRISCVVTable.CoreVectors.MaxI8x64));
  AssertSlotReusesScalar('AddU8x64', Pointer(LScalarTable.CoreVectors.AddU8x64), Pointer(LRISCVVTable.CoreVectors.AddU8x64));
  AssertSlotReusesScalar('SubU8x64', Pointer(LScalarTable.CoreVectors.SubU8x64), Pointer(LRISCVVTable.CoreVectors.SubU8x64));
  AssertSlotReusesScalar('AndU8x64', Pointer(LScalarTable.CoreVectors.AndU8x64), Pointer(LRISCVVTable.CoreVectors.AndU8x64));
  AssertSlotReusesScalar('OrU8x64', Pointer(LScalarTable.CoreVectors.OrU8x64), Pointer(LRISCVVTable.CoreVectors.OrU8x64));
  AssertSlotReusesScalar('XorU8x64', Pointer(LScalarTable.CoreVectors.XorU8x64), Pointer(LRISCVVTable.CoreVectors.XorU8x64));
  AssertSlotReusesScalar('NotU8x64', Pointer(LScalarTable.CoreVectors.NotU8x64), Pointer(LRISCVVTable.CoreVectors.NotU8x64));
  AssertSlotReusesScalar('CmpEqU8x64', Pointer(LScalarTable.CoreVectors.CmpEqU8x64), Pointer(LRISCVVTable.CoreVectors.CmpEqU8x64));
  AssertSlotReusesScalar('CmpLtU8x64', Pointer(LScalarTable.CoreVectors.CmpLtU8x64), Pointer(LRISCVVTable.CoreVectors.CmpLtU8x64));
  AssertSlotReusesScalar('CmpGtU8x64', Pointer(LScalarTable.CoreVectors.CmpGtU8x64), Pointer(LRISCVVTable.CoreVectors.CmpGtU8x64));
  AssertSlotReusesScalar('MinU8x64', Pointer(LScalarTable.CoreVectors.MinU8x64), Pointer(LRISCVVTable.CoreVectors.MinU8x64));
  AssertSlotReusesScalar('MaxU8x64', Pointer(LScalarTable.CoreVectors.MaxU8x64), Pointer(LRISCVVTable.CoreVectors.MaxU8x64));
  AssertSlotReusesScalar('AddU32x16', Pointer(LScalarTable.CoreVectors.AddU32x16), Pointer(LRISCVVTable.CoreVectors.AddU32x16));
  AssertSlotReusesScalar('SubU32x16', Pointer(LScalarTable.CoreVectors.SubU32x16), Pointer(LRISCVVTable.CoreVectors.SubU32x16));
  AssertSlotReusesScalar('MulU32x16', Pointer(LScalarTable.CoreVectors.MulU32x16), Pointer(LRISCVVTable.CoreVectors.MulU32x16));
  AssertSlotReusesScalar('AndU32x16', Pointer(LScalarTable.CoreVectors.AndU32x16), Pointer(LRISCVVTable.CoreVectors.AndU32x16));
  AssertSlotReusesScalar('OrU32x16', Pointer(LScalarTable.CoreVectors.OrU32x16), Pointer(LRISCVVTable.CoreVectors.OrU32x16));
  AssertSlotReusesScalar('XorU32x16', Pointer(LScalarTable.CoreVectors.XorU32x16), Pointer(LRISCVVTable.CoreVectors.XorU32x16));
  AssertSlotReusesScalar('NotU32x16', Pointer(LScalarTable.CoreVectors.NotU32x16), Pointer(LRISCVVTable.CoreVectors.NotU32x16));
  AssertSlotReusesScalar('AndNotU32x16', Pointer(LScalarTable.CoreVectors.AndNotU32x16), Pointer(LRISCVVTable.CoreVectors.AndNotU32x16));
  AssertSlotReusesScalar('ShiftLeftU32x16', Pointer(LScalarTable.CoreVectors.ShiftLeftU32x16), Pointer(LRISCVVTable.CoreVectors.ShiftLeftU32x16));
  AssertSlotReusesScalar('ShiftRightU32x16', Pointer(LScalarTable.CoreVectors.ShiftRightU32x16), Pointer(LRISCVVTable.CoreVectors.ShiftRightU32x16));
  AssertSlotReusesScalar('CmpEqU32x16', Pointer(LScalarTable.CoreVectors.CmpEqU32x16), Pointer(LRISCVVTable.CoreVectors.CmpEqU32x16));
  AssertSlotReusesScalar('CmpLtU32x16', Pointer(LScalarTable.CoreVectors.CmpLtU32x16), Pointer(LRISCVVTable.CoreVectors.CmpLtU32x16));
  AssertSlotReusesScalar('CmpGtU32x16', Pointer(LScalarTable.CoreVectors.CmpGtU32x16), Pointer(LRISCVVTable.CoreVectors.CmpGtU32x16));
  AssertSlotReusesScalar('CmpLeU32x16', Pointer(LScalarTable.CoreVectors.CmpLeU32x16), Pointer(LRISCVVTable.CoreVectors.CmpLeU32x16));
  AssertSlotReusesScalar('CmpGeU32x16', Pointer(LScalarTable.CoreVectors.CmpGeU32x16), Pointer(LRISCVVTable.CoreVectors.CmpGeU32x16));
  AssertSlotReusesScalar('CmpNeU32x16', Pointer(LScalarTable.CoreVectors.CmpNeU32x16), Pointer(LRISCVVTable.CoreVectors.CmpNeU32x16));
  AssertSlotReusesScalar('MinU32x16', Pointer(LScalarTable.CoreVectors.MinU32x16), Pointer(LRISCVVTable.CoreVectors.MinU32x16));
  AssertSlotReusesScalar('MaxU32x16', Pointer(LScalarTable.CoreVectors.MaxU32x16), Pointer(LRISCVVTable.CoreVectors.MaxU32x16));
  AssertSlotReusesScalar('AddU64x8', Pointer(LScalarTable.CoreVectors.AddU64x8), Pointer(LRISCVVTable.CoreVectors.AddU64x8));
  AssertSlotReusesScalar('SubU64x8', Pointer(LScalarTable.CoreVectors.SubU64x8), Pointer(LRISCVVTable.CoreVectors.SubU64x8));
  AssertSlotReusesScalar('AndU64x8', Pointer(LScalarTable.CoreVectors.AndU64x8), Pointer(LRISCVVTable.CoreVectors.AndU64x8));
  AssertSlotReusesScalar('OrU64x8', Pointer(LScalarTable.CoreVectors.OrU64x8), Pointer(LRISCVVTable.CoreVectors.OrU64x8));
  AssertSlotReusesScalar('XorU64x8', Pointer(LScalarTable.CoreVectors.XorU64x8), Pointer(LRISCVVTable.CoreVectors.XorU64x8));
  AssertSlotReusesScalar('NotU64x8', Pointer(LScalarTable.CoreVectors.NotU64x8), Pointer(LRISCVVTable.CoreVectors.NotU64x8));
  AssertSlotReusesScalar('ShiftLeftU64x8', Pointer(LScalarTable.CoreVectors.ShiftLeftU64x8), Pointer(LRISCVVTable.CoreVectors.ShiftLeftU64x8));
  AssertSlotReusesScalar('ShiftRightU64x8', Pointer(LScalarTable.CoreVectors.ShiftRightU64x8), Pointer(LRISCVVTable.CoreVectors.ShiftRightU64x8));
  AssertSlotReusesScalar('CmpEqU64x8', Pointer(LScalarTable.CoreVectors.CmpEqU64x8), Pointer(LRISCVVTable.CoreVectors.CmpEqU64x8));
  AssertSlotReusesScalar('CmpLtU64x8', Pointer(LScalarTable.CoreVectors.CmpLtU64x8), Pointer(LRISCVVTable.CoreVectors.CmpLtU64x8));
  AssertSlotReusesScalar('CmpGtU64x8', Pointer(LScalarTable.CoreVectors.CmpGtU64x8), Pointer(LRISCVVTable.CoreVectors.CmpGtU64x8));
  AssertSlotReusesScalar('CmpLeU64x8', Pointer(LScalarTable.CoreVectors.CmpLeU64x8), Pointer(LRISCVVTable.CoreVectors.CmpLeU64x8));
  AssertSlotReusesScalar('CmpGeU64x8', Pointer(LScalarTable.CoreVectors.CmpGeU64x8), Pointer(LRISCVVTable.CoreVectors.CmpGeU64x8));
  AssertSlotReusesScalar('CmpNeU64x8', Pointer(LScalarTable.CoreVectors.CmpNeU64x8), Pointer(LRISCVVTable.CoreVectors.CmpNeU64x8));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_ClampF64x2_Drops_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LAsmSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;
  LAsmSource: string;

  function CountOccurrences(const aHaystack, aNeedle: string): Integer;
  var
    LRest: string;
    LPos: SizeInt;
  begin
    Result := 0;
    LRest := aHaystack;
    LPos := Pos(aNeedle, LRest);
    while LPos > 0 do
    begin
      Inc(Result);
      Delete(LRest, 1, LPos + Length(aNeedle) - 1);
      LPos := Pos(aNeedle, LRest);
    end;
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for ClampF64x2 dead-facade audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for ClampF64x2 dead-facade audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LAsmSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LAsmSourcePath), 'RISCVV unit source should exist for ClampF64x2 dead-facade audit: ' + LAsmSourcePath);
    LSourceLines.LoadFromFile(LAsmSourcePath);
    LAsmSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  CheckEqual(1, CountOccurrences(LRegisterSource, 'table.corevectors.clampf64x2 := @riscvvclampf64x2;'), 'RegisterRISCVVBackend should keep exactly one ClampF64x2 source assignment site');
  CheckTrue(Pos('table.corevectors.clampf64x2 := @riscvvclampf64x2;', LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a dedicated asm-gated ClampF64x2 source assignment');
  CheckTrue(Pos('function riscvvclampf64x2(const a, minval, maxval: tvecf64x2): tvecf64x2;', LFacadeSource) = 0, 'no-asm RISCVV facade should no longer define the dead ClampF64x2 witness');
  CheckTrue(Pos('procedure riscvvclampf64x2asm(const a, minval, maxval: tvecf64x2; var r: tvecf64x2);', LAsmSource) > 0, 'RVV asm source should still expose RISCVVClampF64x2Asm');
  CheckTrue((Pos('vfmax.vv v0, v0, v1', LAsmSource) > 0) and (Pos('vfmin.vv v0, v0, v2', LAsmSource) > 0), 'RVV asm source should still clamp ClampF64x2 via vfmax/vfmin');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  CheckTrue(Pointer(LRISCVVTable.CoreVectors.ClampF64x2) <> nil, 'RISCVV ClampF64x2 should stay assigned in the backend dispatch table');
  {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
  CheckTrue(PtrUInt(LScalarTable.CoreVectors.ClampF64x2) <> PtrUInt(LRISCVVTable.CoreVectors.ClampF64x2), 'RISCVV ClampF64x2 should keep a backend-owned runtime slot when RVV asm is compiled');
  {$ELSE}
  CheckEqual(PtrUInt(LScalarTable.CoreVectors.ClampF64x2), PtrUInt(LRISCVVTable.CoreVectors.ClampF64x2), 'RISCVV ClampF64x2 should reuse the base scalar runtime slot when RVV asm is not compiled on this host');
  {$ENDIF}
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_ExactF64x2Slots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LAsmSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;
  LAsmSource: string;

  function CountOccurrences(const aHaystack, aNeedle: string): Integer;
  var
    LRest: string;
    LPos: SizeInt;
  begin
    Result := 0;
    LRest := aHaystack;
    LPos := Pos(aNeedle, LRest);
    while LPos > 0 do
    begin
      Inc(Result);
      Delete(LRest, 1, LPos + Length(aNeedle) - 1);
      LPos := Pos(aNeedle, LRest);
    end;
  end;

  procedure AssertRegisterHasAsmOwnedSlot(const aLabel, aSnippet: string);
  var
    LNeedle: string;
  begin
    LNeedle := LowerCase(aSnippet);
    CheckEqual(1, CountOccurrences(LRegisterSource, LNeedle), 'RegisterRISCVVBackend should keep exactly one ' + aLabel + ' source assignment site');
    CheckTrue(Pos(LNeedle, LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a dedicated asm-gated ' + aLabel + ' source assignment');
  end;

  procedure AssertAsmConditionalExactF64x2Slot(
    const aLabel, aFunctionSnippet, aAsmWrapperSnippet, aAsmHelperSnippet, aAsmOpSnippet: string;
    const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(Pos(LowerCase(aFunctionSnippet), LFacadeSource) = 0, 'no-asm RISCVV facade should no longer define the dead ' + aLabel + ' witness');
    CheckTrue(Pos(LowerCase(aAsmWrapperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated wrapper call for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmHelperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated helper signature for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmOpSnippet), LAsmSource) > 0, 'RVV asm source should keep a dedicated vector op body for ' + aLabel);
    CheckTrue(aBackendSlot <> nil, 'RISCVV ' + aLabel + ' should stay assigned in the backend dispatch table');
    {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should keep a backend-owned runtime slot when RVV asm is compiled');
    {$ELSE}
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the base scalar runtime slot when RVV asm is not compiled on this host');
    {$ENDIF}
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for exact F64x2 dead-facade audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for exact F64x2 dead-facade audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LAsmSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LAsmSourcePath), 'RISCVV unit source should exist for exact F64x2 dead-facade audit: ' + LAsmSourcePath);
    LSourceLines.LoadFromFile(LAsmSourcePath);
    LAsmSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertRegisterHasAsmOwnedSlot('AbsF64x2', 'table.CoreVectors.AbsF64x2 := @RISCVVAbsF64x2;');
  AssertRegisterHasAsmOwnedSlot('SqrtF64x2', 'table.CoreVectors.SqrtF64x2 := @RISCVVSqrtF64x2;');
  AssertRegisterHasAsmOwnedSlot('FmaF64x2', 'table.CoreVectors.FmaF64x2 := @RISCVVFmaF64x2;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertAsmConditionalExactF64x2Slot('AbsF64x2', 'function RISCVVAbsF64x2(const a: TVecF64x2): TVecF64x2;',
    'RISCVVAbsF64x2Asm(a, Result);', 'procedure RISCVVAbsF64x2Asm(const a: TVecF64x2; var r: TVecF64x2);',
    'vfsgnjx.vv v0, v0, v0', Pointer(LScalarTable.CoreVectors.AbsF64x2), Pointer(LRISCVVTable.CoreVectors.AbsF64x2));
  AssertAsmConditionalExactF64x2Slot('SqrtF64x2', 'function RISCVVSqrtF64x2(const a: TVecF64x2): TVecF64x2;',
    'RISCVVSqrtF64x2Asm(a, Result);', 'procedure RISCVVSqrtF64x2Asm(const a: TVecF64x2; var r: TVecF64x2);',
    'vfsqrt.v v0, v0', Pointer(LScalarTable.CoreVectors.SqrtF64x2), Pointer(LRISCVVTable.CoreVectors.SqrtF64x2));
  AssertAsmConditionalExactF64x2Slot('FmaF64x2', 'function RISCVVFmaF64x2(const a, b, c: TVecF64x2): TVecF64x2;',
    'RISCVVFmaF64x2Asm(a, b, c, Result);', 'procedure RISCVVFmaF64x2Asm(const a, b, c: TVecF64x2; var r: TVecF64x2);',
    'vfmacc.vv v2, v0, v1', Pointer(LScalarTable.CoreVectors.FmaF64x2), Pointer(LRISCVVTable.CoreVectors.FmaF64x2));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_ArithmeticF64x2Slots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LAsmSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;
  LAsmSource: string;

  function CountOccurrences(const aHaystack, aNeedle: string): Integer;
  var
    LRest: string;
    LPos: SizeInt;
  begin
    Result := 0;
    LRest := aHaystack;
    LPos := Pos(aNeedle, LRest);
    while LPos > 0 do
    begin
      Inc(Result);
      Delete(LRest, 1, LPos + Length(aNeedle) - 1);
      LPos := Pos(aNeedle, LRest);
    end;
  end;

  procedure AssertRegisterHasAsmOwnedSlot(const aLabel, aSnippet: string);
  var
    LNeedle: string;
  begin
    LNeedle := LowerCase(aSnippet);
    CheckEqual(1, CountOccurrences(LRegisterSource, LNeedle), 'RegisterRISCVVBackend should keep exactly one ' + aLabel + ' source assignment site');
    CheckTrue(Pos(LNeedle, LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a dedicated asm-gated ' + aLabel + ' source assignment');
  end;

  procedure AssertAsmConditionalArithmeticF64x2Slot(
    const aLabel, aFunctionSnippet, aAsmWrapperSnippet, aAsmHelperSnippet, aAsmOpSnippet: string;
    const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(Pos(LowerCase(aFunctionSnippet), LFacadeSource) = 0, 'no-asm RISCVV facade should no longer define the dead ' + aLabel + ' witness');
    CheckTrue(Pos(LowerCase(aAsmWrapperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated wrapper call for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmHelperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated helper signature for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmOpSnippet), LAsmSource) > 0, 'RVV asm source should keep a dedicated vector op body for ' + aLabel);
    CheckTrue(aBackendSlot <> nil, 'RISCVV ' + aLabel + ' should stay assigned in the backend dispatch table');
    {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should keep a backend-owned runtime slot when RVV asm is compiled');
    {$ELSE}
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the base scalar runtime slot when RVV asm is not compiled on this host');
    {$ENDIF}
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for arithmetic F64x2 dead-facade audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for arithmetic F64x2 dead-facade audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LAsmSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LAsmSourcePath), 'RISCVV unit source should exist for arithmetic F64x2 dead-facade audit: ' + LAsmSourcePath);
    LSourceLines.LoadFromFile(LAsmSourcePath);
    LAsmSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertRegisterHasAsmOwnedSlot('AddF64x2', 'table.CoreVectors.AddF64x2 := @RISCVVAddF64x2;');
  AssertRegisterHasAsmOwnedSlot('SubF64x2', 'table.CoreVectors.SubF64x2 := @RISCVVSubF64x2;');
  AssertRegisterHasAsmOwnedSlot('MulF64x2', 'table.CoreVectors.MulF64x2 := @RISCVVMulF64x2;');
  AssertRegisterHasAsmOwnedSlot('DivF64x2', 'table.CoreVectors.DivF64x2 := @RISCVVDivF64x2;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertAsmConditionalArithmeticF64x2Slot('AddF64x2', 'function RISCVVAddF64x2(const a, b: TVecF64x2): TVecF64x2;',
    'RISCVVAddF64x2Asm(a, b, Result);', 'procedure RISCVVAddF64x2Asm(const a, b: TVecF64x2; var r: TVecF64x2);',
    'vfadd.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.AddF64x2), Pointer(LRISCVVTable.CoreVectors.AddF64x2));
  AssertAsmConditionalArithmeticF64x2Slot('SubF64x2', 'function RISCVVSubF64x2(const a, b: TVecF64x2): TVecF64x2;',
    'RISCVVSubF64x2Asm(a, b, Result);', 'procedure RISCVVSubF64x2Asm(const a, b: TVecF64x2; var r: TVecF64x2);',
    'vfsub.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.SubF64x2), Pointer(LRISCVVTable.CoreVectors.SubF64x2));
  AssertAsmConditionalArithmeticF64x2Slot('MulF64x2', 'function RISCVVMulF64x2(const a, b: TVecF64x2): TVecF64x2;',
    'RISCVVMulF64x2Asm(a, b, Result);', 'procedure RISCVVMulF64x2Asm(const a, b: TVecF64x2; var r: TVecF64x2);',
    'vfmul.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.MulF64x2), Pointer(LRISCVVTable.CoreVectors.MulF64x2));
  AssertAsmConditionalArithmeticF64x2Slot('DivF64x2', 'function RISCVVDivF64x2(const a, b: TVecF64x2): TVecF64x2;',
    'RISCVVDivF64x2Asm(a, b, Result);', 'procedure RISCVVDivF64x2Asm(const a, b: TVecF64x2; var r: TVecF64x2);',
    'vfdiv.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.DivF64x2), Pointer(LRISCVVTable.CoreVectors.DivF64x2));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_ArithmeticF32x4Slots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LAsmSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;
  LAsmSource: string;

  function CountOccurrences(const aHaystack, aNeedle: string): Integer;
  var
    LRest: string;
    LPos: SizeInt;
  begin
    Result := 0;
    LRest := aHaystack;
    LPos := Pos(aNeedle, LRest);
    while LPos > 0 do
    begin
      Inc(Result);
      Delete(LRest, 1, LPos + Length(aNeedle) - 1);
      LPos := Pos(aNeedle, LRest);
    end;
  end;

  procedure AssertRegisterHasAsmOwnedSlot(const aLabel, aSnippet: string);
  var
    LNeedle: string;
  begin
    LNeedle := LowerCase(aSnippet);
    CheckEqual(1, CountOccurrences(LRegisterSource, LNeedle), 'RegisterRISCVVBackend should keep exactly one ' + aLabel + ' source assignment site');
    CheckTrue(Pos(LNeedle, LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a dedicated asm-gated ' + aLabel + ' source assignment');
  end;

  procedure AssertAsmConditionalArithmeticF32x4Slot(
    const aLabel, aFunctionSnippet, aAsmWrapperSnippet, aAsmHelperSnippet, aAsmOpSnippet: string;
    const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(Pos(LowerCase(aFunctionSnippet), LFacadeSource) = 0, 'no-asm RISCVV facade should no longer define the dead ' + aLabel + ' witness');
    CheckTrue(Pos(LowerCase(aAsmWrapperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated wrapper call for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmHelperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated helper signature for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmOpSnippet), LAsmSource) > 0, 'RVV asm source should keep a dedicated vector op body for ' + aLabel);
    CheckTrue(aBackendSlot <> nil, 'RISCVV ' + aLabel + ' should stay assigned in the backend dispatch table');
    {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should keep a backend-owned runtime slot when RVV asm is compiled');
    {$ELSE}
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the base scalar runtime slot when RVV asm is not compiled on this host');
    {$ENDIF}
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for arithmetic F32x4 dead-facade audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for arithmetic F32x4 dead-facade audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LAsmSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LAsmSourcePath), 'RISCVV unit source should exist for arithmetic F32x4 dead-facade audit: ' + LAsmSourcePath);
    LSourceLines.LoadFromFile(LAsmSourcePath);
    LAsmSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertRegisterHasAsmOwnedSlot('AddF32x4', 'table.CoreVectors.AddF32x4 := @RISCVVAddF32x4;');
  AssertRegisterHasAsmOwnedSlot('SubF32x4', 'table.CoreVectors.SubF32x4 := @RISCVVSubF32x4;');
  AssertRegisterHasAsmOwnedSlot('MulF32x4', 'table.CoreVectors.MulF32x4 := @RISCVVMulF32x4;');
  AssertRegisterHasAsmOwnedSlot('DivF32x4', 'table.CoreVectors.DivF32x4 := @RISCVVDivF32x4;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertAsmConditionalArithmeticF32x4Slot('AddF32x4', 'function RISCVVAddF32x4(const a, b: TVecF32x4): TVecF32x4;',
    'RISCVVAddF32x4Asm(a, b, Result);', 'procedure RISCVVAddF32x4Asm(const a, b: TVecF32x4; var r: TVecF32x4);',
    'vfadd.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.AddF32x4), Pointer(LRISCVVTable.CoreVectors.AddF32x4));
  AssertAsmConditionalArithmeticF32x4Slot('SubF32x4', 'function RISCVVSubF32x4(const a, b: TVecF32x4): TVecF32x4;',
    'RISCVVSubF32x4Asm(a, b, Result);', 'procedure RISCVVSubF32x4Asm(const a, b: TVecF32x4; var r: TVecF32x4);',
    'vfsub.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.SubF32x4), Pointer(LRISCVVTable.CoreVectors.SubF32x4));
  AssertAsmConditionalArithmeticF32x4Slot('MulF32x4', 'function RISCVVMulF32x4(const a, b: TVecF32x4): TVecF32x4;',
    'RISCVVMulF32x4Asm(a, b, Result);', 'procedure RISCVVMulF32x4Asm(const a, b: TVecF32x4; var r: TVecF32x4);',
    'vfmul.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.MulF32x4), Pointer(LRISCVVTable.CoreVectors.MulF32x4));
  AssertAsmConditionalArithmeticF32x4Slot('DivF32x4', 'function RISCVVDivF32x4(const a, b: TVecF32x4): TVecF32x4;',
    'RISCVVDivF32x4Asm(a, b, Result);', 'procedure RISCVVDivF32x4Asm(const a, b: TVecF32x4; var r: TVecF32x4);',
    'vfdiv.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.DivF32x4), Pointer(LRISCVVTable.CoreVectors.DivF32x4));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_I32x4ConditionalIntegerSlots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LAsmSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;
  LAsmSource: string;

  function CountOccurrences(const aHaystack, aNeedle: string): Integer;
  var
    LRest: string;
    LPos: SizeInt;
  begin
    Result := 0;
    LRest := aHaystack;
    LPos := Pos(aNeedle, LRest);
    while LPos > 0 do
    begin
      Inc(Result);
      Delete(LRest, 1, LPos + Length(aNeedle) - 1);
      LPos := Pos(aNeedle, LRest);
    end;
  end;

  procedure AssertRegisterHasAsmOwnedSlot(const aLabel, aSnippet: string);
  var
    LNeedle: string;
  begin
    LNeedle := LowerCase(aSnippet);
    CheckEqual(1, CountOccurrences(LRegisterSource, LNeedle), 'RegisterRISCVVBackend should keep exactly one ' + aLabel + ' source assignment site');
    CheckTrue(Pos(LNeedle, LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a dedicated asm-gated ' + aLabel + ' source assignment');
  end;

  procedure AssertAsmConditionalI32x4IntegerSlot(
    const aLabel, aFunctionSnippet, aAsmWrapperSnippet, aAsmHelperSnippet, aAsmOpSnippet: string;
    const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(Pos(LowerCase(aFunctionSnippet), LFacadeSource) = 0, 'no-asm RISCVV facade should no longer define the dead ' + aLabel + ' witness');
    CheckTrue(Pos(LowerCase(aAsmWrapperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated wrapper call for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmHelperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated helper signature for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmOpSnippet), LAsmSource) > 0, 'RVV asm source should keep the vector integer body for ' + aLabel);
    CheckTrue(aBackendSlot <> nil, 'RISCVV ' + aLabel + ' should stay assigned in the backend dispatch table');
    {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should keep a backend-owned runtime slot when RVV asm is compiled');
    {$ELSE}
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the base scalar runtime slot when RVV asm is not compiled on this host');
    {$ENDIF}
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for I32x4 integer dead-facade audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for I32x4 integer dead-facade audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LAsmSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LAsmSourcePath), 'RISCVV unit source should exist for I32x4 integer dead-facade audit: ' + LAsmSourcePath);
    LSourceLines.LoadFromFile(LAsmSourcePath);
    LAsmSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertRegisterHasAsmOwnedSlot('AddI32x4', 'table.CoreVectors.AddI32x4 := @RISCVVAddI32x4;');
  AssertRegisterHasAsmOwnedSlot('SubI32x4', 'table.CoreVectors.SubI32x4 := @RISCVVSubI32x4;');
  AssertRegisterHasAsmOwnedSlot('MulI32x4', 'table.CoreVectors.MulI32x4 := @RISCVVMulI32x4;');
  AssertRegisterHasAsmOwnedSlot('AndI32x4', 'table.CoreVectors.AndI32x4 := @RISCVVAndI32x4;');
  AssertRegisterHasAsmOwnedSlot('OrI32x4', 'table.CoreVectors.OrI32x4 := @RISCVVOrI32x4;');
  AssertRegisterHasAsmOwnedSlot('XorI32x4', 'table.CoreVectors.XorI32x4 := @RISCVVXorI32x4;');
  AssertRegisterHasAsmOwnedSlot('NotI32x4', 'table.CoreVectors.NotI32x4 := @RISCVVNotI32x4;');
  AssertRegisterHasAsmOwnedSlot('AndNotI32x4', 'table.CoreVectors.AndNotI32x4 := @RISCVVAndNotI32x4;');
  AssertRegisterHasAsmOwnedSlot('ShiftLeftI32x4', 'table.CoreVectors.ShiftLeftI32x4 := @RISCVVShiftLeftI32x4;');
  AssertRegisterHasAsmOwnedSlot('ShiftRightI32x4', 'table.CoreVectors.ShiftRightI32x4 := @RISCVVShiftRightI32x4;');
  AssertRegisterHasAsmOwnedSlot('ShiftRightArithI32x4', 'table.CoreVectors.ShiftRightArithI32x4 := @RISCVVShiftRightArithI32x4;');
  AssertRegisterHasAsmOwnedSlot('MinI32x4', 'table.CoreVectors.MinI32x4 := @RISCVVMinI32x4;');
  AssertRegisterHasAsmOwnedSlot('MaxI32x4', 'table.CoreVectors.MaxI32x4 := @RISCVVMaxI32x4;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertAsmConditionalI32x4IntegerSlot('AddI32x4', 'function RISCVVAddI32x4(const a, b: TVecI32x4): TVecI32x4;',
    'RISCVVAddI32x4Asm(a, b, Result);', 'procedure RISCVVAddI32x4Asm(const a, b: TVecI32x4; var r: TVecI32x4);',
    'vadd.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.AddI32x4), Pointer(LRISCVVTable.CoreVectors.AddI32x4));
  AssertAsmConditionalI32x4IntegerSlot('SubI32x4', 'function RISCVVSubI32x4(const a, b: TVecI32x4): TVecI32x4;',
    'RISCVVSubI32x4Asm(a, b, Result);', 'procedure RISCVVSubI32x4Asm(const a, b: TVecI32x4; var r: TVecI32x4);',
    'vsub.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.SubI32x4), Pointer(LRISCVVTable.CoreVectors.SubI32x4));
  AssertAsmConditionalI32x4IntegerSlot('MulI32x4', 'function RISCVVMulI32x4(const a, b: TVecI32x4): TVecI32x4;',
    'RISCVVMulI32x4Asm(a, b, Result);', 'procedure RISCVVMulI32x4Asm(const a, b: TVecI32x4; var r: TVecI32x4);',
    'vmul.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.MulI32x4), Pointer(LRISCVVTable.CoreVectors.MulI32x4));
  AssertAsmConditionalI32x4IntegerSlot('AndI32x4', 'function RISCVVAndI32x4(const a, b: TVecI32x4): TVecI32x4;',
    'RISCVVAndI32x4Asm(a, b, Result);', 'procedure RISCVVAndI32x4Asm(const a, b: TVecI32x4; var r: TVecI32x4);',
    'vand.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.AndI32x4), Pointer(LRISCVVTable.CoreVectors.AndI32x4));
  AssertAsmConditionalI32x4IntegerSlot('OrI32x4', 'function RISCVVOrI32x4(const a, b: TVecI32x4): TVecI32x4;',
    'RISCVVOrI32x4Asm(a, b, Result);', 'procedure RISCVVOrI32x4Asm(const a, b: TVecI32x4; var r: TVecI32x4);',
    'vor.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.OrI32x4), Pointer(LRISCVVTable.CoreVectors.OrI32x4));
  AssertAsmConditionalI32x4IntegerSlot('XorI32x4', 'function RISCVVXorI32x4(const a, b: TVecI32x4): TVecI32x4;',
    'RISCVVXorI32x4Asm(a, b, Result);', 'procedure RISCVVXorI32x4Asm(const a, b: TVecI32x4; var r: TVecI32x4);',
    'vxor.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.XorI32x4), Pointer(LRISCVVTable.CoreVectors.XorI32x4));
  AssertAsmConditionalI32x4IntegerSlot('NotI32x4', 'function RISCVVNotI32x4(const a: TVecI32x4): TVecI32x4;',
    'RISCVVNotI32x4Asm(a, Result);', 'procedure RISCVVNotI32x4Asm(const a: TVecI32x4; var r: TVecI32x4);',
    'vxor.vi v0, v0, -1', Pointer(LScalarTable.CoreVectors.NotI32x4), Pointer(LRISCVVTable.CoreVectors.NotI32x4));
  AssertAsmConditionalI32x4IntegerSlot('AndNotI32x4', 'function RISCVVAndNotI32x4(const a, b: TVecI32x4): TVecI32x4;',
    'RISCVVAndNotI32x4Asm(a, b, Result);', 'procedure RISCVVAndNotI32x4Asm(const a, b: TVecI32x4; var r: TVecI32x4);',
    'vand.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.AndNotI32x4), Pointer(LRISCVVTable.CoreVectors.AndNotI32x4));
  AssertAsmConditionalI32x4IntegerSlot('ShiftLeftI32x4', 'function RISCVVShiftLeftI32x4(const a: TVecI32x4; count: Integer): TVecI32x4;',
    'RISCVVShiftLeftI32x4Asm(a, count, Result);', 'procedure RISCVVShiftLeftI32x4Asm(const a: TVecI32x4; count: Integer; var r: TVecI32x4);',
    'vsll.vx v0, v0, a1', Pointer(LScalarTable.CoreVectors.ShiftLeftI32x4), Pointer(LRISCVVTable.CoreVectors.ShiftLeftI32x4));
  AssertAsmConditionalI32x4IntegerSlot('ShiftRightI32x4', 'function RISCVVShiftRightI32x4(const a: TVecI32x4; count: Integer): TVecI32x4;',
    'RISCVVShiftRightI32x4Asm(a, count, Result);', 'procedure RISCVVShiftRightI32x4Asm(const a: TVecI32x4; count: Integer; var r: TVecI32x4);',
    'vsrl.vx v0, v0, a1', Pointer(LScalarTable.CoreVectors.ShiftRightI32x4), Pointer(LRISCVVTable.CoreVectors.ShiftRightI32x4));
  AssertAsmConditionalI32x4IntegerSlot('ShiftRightArithI32x4', 'function RISCVVShiftRightArithI32x4(const a: TVecI32x4; count: Integer): TVecI32x4;',
    'RISCVVShiftRightArithI32x4Asm(a, count, Result);', 'procedure RISCVVShiftRightArithI32x4Asm(const a: TVecI32x4; count: Integer; var r: TVecI32x4);',
    'vsra.vx v0, v0, a1', Pointer(LScalarTable.CoreVectors.ShiftRightArithI32x4), Pointer(LRISCVVTable.CoreVectors.ShiftRightArithI32x4));
  AssertAsmConditionalI32x4IntegerSlot('MinI32x4', 'function RISCVVMinI32x4(const a, b: TVecI32x4): TVecI32x4;',
    'RISCVVMinI32x4Asm(a, b, Result);', 'procedure RISCVVMinI32x4Asm(const a, b: TVecI32x4; var r: TVecI32x4);',
    'vmin.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.MinI32x4), Pointer(LRISCVVTable.CoreVectors.MinI32x4));
  AssertAsmConditionalI32x4IntegerSlot('MaxI32x4', 'function RISCVVMaxI32x4(const a, b: TVecI32x4): TVecI32x4;',
    'RISCVVMaxI32x4Asm(a, b, Result);', 'procedure RISCVVMaxI32x4Asm(const a, b: TVecI32x4; var r: TVecI32x4);',
    'vmax.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.MaxI32x4), Pointer(LRISCVVTable.CoreVectors.MaxI32x4));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_I64x2ConditionalIntegerSlots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LAsmSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;
  LAsmSource: string;

  function CountOccurrences(const aHaystack, aNeedle: string): Integer;
  var
    LRest: string;
    LPos: SizeInt;
  begin
    Result := 0;
    LRest := aHaystack;
    LPos := Pos(aNeedle, LRest);
    while LPos > 0 do
    begin
      Inc(Result);
      Delete(LRest, 1, LPos + Length(aNeedle) - 1);
      LPos := Pos(aNeedle, LRest);
    end;
  end;

  procedure AssertRegisterHasAsmOwnedSlot(const aLabel, aSnippet: string);
  var
    LNeedle: string;
  begin
    LNeedle := LowerCase(aSnippet);
    CheckEqual(1, CountOccurrences(LRegisterSource, LNeedle), 'RegisterRISCVVBackend should keep exactly one ' + aLabel + ' source assignment site');
    CheckTrue(Pos(LNeedle, LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a dedicated asm-gated ' + aLabel + ' source assignment');
  end;

  procedure AssertAsmConditionalI64x2IntegerSlot(
    const aLabel, aFunctionSnippet, aAsmWrapperSnippet, aAsmHelperSnippet, aAsmOpSnippet: string;
    const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(Pos(LowerCase(aFunctionSnippet), LFacadeSource) = 0, 'no-asm RISCVV facade should no longer define the dead ' + aLabel + ' witness');
    CheckTrue(Pos(LowerCase(aAsmWrapperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated wrapper call for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmHelperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated helper signature for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmOpSnippet), LAsmSource) > 0, 'RVV asm source should keep the vector integer body for ' + aLabel);
    CheckTrue(aBackendSlot <> nil, 'RISCVV ' + aLabel + ' should stay assigned in the backend dispatch table');
    {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should keep a backend-owned runtime slot when RVV asm is compiled');
    {$ELSE}
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the base scalar runtime slot when RVV asm is not compiled on this host');
    {$ENDIF}
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for I64x2 integer dead-facade audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for I64x2 integer dead-facade audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LAsmSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LAsmSourcePath), 'RISCVV unit source should exist for I64x2 integer dead-facade audit: ' + LAsmSourcePath);
    LSourceLines.LoadFromFile(LAsmSourcePath);
    LAsmSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertRegisterHasAsmOwnedSlot('AddI64x2', 'table.CoreVectors.AddI64x2 := @RISCVVAddI64x2;');
  AssertRegisterHasAsmOwnedSlot('SubI64x2', 'table.CoreVectors.SubI64x2 := @RISCVVSubI64x2;');
  AssertRegisterHasAsmOwnedSlot('AndI64x2', 'table.CoreVectors.AndI64x2 := @RISCVVAndI64x2;');
  AssertRegisterHasAsmOwnedSlot('OrI64x2', 'table.CoreVectors.OrI64x2 := @RISCVVOrI64x2;');
  AssertRegisterHasAsmOwnedSlot('XorI64x2', 'table.CoreVectors.XorI64x2 := @RISCVVXorI64x2;');
  AssertRegisterHasAsmOwnedSlot('NotI64x2', 'table.CoreVectors.NotI64x2 := @RISCVVNotI64x2;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertAsmConditionalI64x2IntegerSlot('AddI64x2', 'function RISCVVAddI64x2(const a, b: TVecI64x2): TVecI64x2;',
    'RISCVVAddI64x2Asm(a, b, Result);', 'procedure RISCVVAddI64x2Asm(const a, b: TVecI64x2; var r: TVecI64x2);',
    'vadd.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.AddI64x2), Pointer(LRISCVVTable.CoreVectors.AddI64x2));
  AssertAsmConditionalI64x2IntegerSlot('SubI64x2', 'function RISCVVSubI64x2(const a, b: TVecI64x2): TVecI64x2;',
    'RISCVVSubI64x2Asm(a, b, Result);', 'procedure RISCVVSubI64x2Asm(const a, b: TVecI64x2; var r: TVecI64x2);',
    'vsub.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.SubI64x2), Pointer(LRISCVVTable.CoreVectors.SubI64x2));
  AssertAsmConditionalI64x2IntegerSlot('AndI64x2', 'function RISCVVAndI64x2(const a, b: TVecI64x2): TVecI64x2;',
    'RISCVVAndI64x2Asm(a, b, Result);', 'procedure RISCVVAndI64x2Asm(const a, b: TVecI64x2; var r: TVecI64x2);',
    'vand.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.AndI64x2), Pointer(LRISCVVTable.CoreVectors.AndI64x2));
  AssertAsmConditionalI64x2IntegerSlot('OrI64x2', 'function RISCVVOrI64x2(const a, b: TVecI64x2): TVecI64x2;',
    'RISCVVOrI64x2Asm(a, b, Result);', 'procedure RISCVVOrI64x2Asm(const a, b: TVecI64x2; var r: TVecI64x2);',
    'vor.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.OrI64x2), Pointer(LRISCVVTable.CoreVectors.OrI64x2));
  AssertAsmConditionalI64x2IntegerSlot('XorI64x2', 'function RISCVVXorI64x2(const a, b: TVecI64x2): TVecI64x2;',
    'RISCVVXorI64x2Asm(a, b, Result);', 'procedure RISCVVXorI64x2Asm(const a, b: TVecI64x2; var r: TVecI64x2);',
    'vxor.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.XorI64x2), Pointer(LRISCVVTable.CoreVectors.XorI64x2));
  AssertAsmConditionalI64x2IntegerSlot('NotI64x2', 'function RISCVVNotI64x2(const a: TVecI64x2): TVecI64x2;',
    'RISCVVNotI64x2Asm(a, Result);', 'procedure RISCVVNotI64x2Asm(const a: TVecI64x2; var r: TVecI64x2);',
    'vxor.vi v0, v0, -1', Pointer(LScalarTable.CoreVectors.NotI64x2), Pointer(LRISCVVTable.CoreVectors.NotI64x2));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_U32x4ConditionalIntegerSlots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LAsmSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;
  LAsmSource: string;

  function CountOccurrences(const aHaystack, aNeedle: string): Integer;
  var
    LRest: string;
    LPos: SizeInt;
  begin
    Result := 0;
    LRest := aHaystack;
    LPos := Pos(aNeedle, LRest);
    while LPos > 0 do
    begin
      Inc(Result);
      Delete(LRest, 1, LPos + Length(aNeedle) - 1);
      LPos := Pos(aNeedle, LRest);
    end;
  end;

  procedure AssertRegisterHasAsmOwnedSlot(const aLabel, aSnippet: string);
  var
    LNeedle: string;
  begin
    LNeedle := LowerCase(aSnippet);
    CheckEqual(1, CountOccurrences(LRegisterSource, LNeedle), 'RegisterRISCVVBackend should keep exactly one ' + aLabel + ' source assignment site');
    CheckTrue(Pos(LNeedle, LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a dedicated asm-gated ' + aLabel + ' source assignment');
  end;

  procedure AssertAsmConditionalU32x4IntegerSlot(
    const aLabel, aFunctionSnippet, aAsmWrapperSnippet, aAsmHelperSnippet, aAsmOpSnippet: string;
    const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(Pos(LowerCase(aFunctionSnippet), LFacadeSource) = 0, 'no-asm RISCVV facade should no longer define the dead ' + aLabel + ' witness');
    CheckTrue(Pos(LowerCase(aAsmWrapperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated wrapper call for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmHelperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated helper signature for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmOpSnippet), LAsmSource) > 0, 'RVV asm source should keep the vector integer body for ' + aLabel);
    CheckTrue(aBackendSlot <> nil, 'RISCVV ' + aLabel + ' should stay assigned in the backend dispatch table');
    {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should keep a backend-owned runtime slot when RVV asm is compiled');
    {$ELSE}
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the base scalar runtime slot when RVV asm is not compiled on this host');
    {$ENDIF}
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for U32x4 integer dead-facade audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for U32x4 integer dead-facade audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LAsmSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LAsmSourcePath), 'RISCVV unit source should exist for U32x4 integer dead-facade audit: ' + LAsmSourcePath);
    LSourceLines.LoadFromFile(LAsmSourcePath);
    LAsmSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertRegisterHasAsmOwnedSlot('AddU32x4', 'table.CoreVectors.AddU32x4 := @RISCVVAddU32x4;');
  AssertRegisterHasAsmOwnedSlot('SubU32x4', 'table.CoreVectors.SubU32x4 := @RISCVVSubU32x4;');
  AssertRegisterHasAsmOwnedSlot('MulU32x4', 'table.CoreVectors.MulU32x4 := @RISCVVMulU32x4;');
  AssertRegisterHasAsmOwnedSlot('AndU32x4', 'table.CoreVectors.AndU32x4 := @RISCVVAndU32x4;');
  AssertRegisterHasAsmOwnedSlot('OrU32x4', 'table.CoreVectors.OrU32x4 := @RISCVVOrU32x4;');
  AssertRegisterHasAsmOwnedSlot('XorU32x4', 'table.CoreVectors.XorU32x4 := @RISCVVXorU32x4;');
  AssertRegisterHasAsmOwnedSlot('NotU32x4', 'table.CoreVectors.NotU32x4 := @RISCVVNotU32x4;');
  AssertRegisterHasAsmOwnedSlot('ShiftLeftU32x4', 'table.CoreVectors.ShiftLeftU32x4 := @RISCVVShiftLeftU32x4;');
  AssertRegisterHasAsmOwnedSlot('ShiftRightU32x4', 'table.CoreVectors.ShiftRightU32x4 := @RISCVVShiftRightU32x4;');
  AssertRegisterHasAsmOwnedSlot('MinU32x4', 'table.CoreVectors.MinU32x4 := @RISCVVMinU32x4;');
  AssertRegisterHasAsmOwnedSlot('MaxU32x4', 'table.CoreVectors.MaxU32x4 := @RISCVVMaxU32x4;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertAsmConditionalU32x4IntegerSlot('AddU32x4', 'function RISCVVAddU32x4(const a, b: TVecU32x4): TVecU32x4;',
    'RISCVVAddU32x4Asm(a, b, Result);', 'procedure RISCVVAddU32x4Asm(const a, b: TVecU32x4; var r: TVecU32x4);',
    'vadd.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.AddU32x4), Pointer(LRISCVVTable.CoreVectors.AddU32x4));
  AssertAsmConditionalU32x4IntegerSlot('SubU32x4', 'function RISCVVSubU32x4(const a, b: TVecU32x4): TVecU32x4;',
    'RISCVVSubU32x4Asm(a, b, Result);', 'procedure RISCVVSubU32x4Asm(const a, b: TVecU32x4; var r: TVecU32x4);',
    'vsub.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.SubU32x4), Pointer(LRISCVVTable.CoreVectors.SubU32x4));
  AssertAsmConditionalU32x4IntegerSlot('MulU32x4', 'function RISCVVMulU32x4(const a, b: TVecU32x4): TVecU32x4;',
    'RISCVVMulU32x4Asm(a, b, Result);', 'procedure RISCVVMulU32x4Asm(const a, b: TVecU32x4; var r: TVecU32x4);',
    'vmul.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.MulU32x4), Pointer(LRISCVVTable.CoreVectors.MulU32x4));
  AssertAsmConditionalU32x4IntegerSlot('AndU32x4', 'function RISCVVAndU32x4(const a, b: TVecU32x4): TVecU32x4;',
    'RISCVVAndU32x4Asm(a, b, Result);', 'procedure RISCVVAndU32x4Asm(const a, b: TVecU32x4; var r: TVecU32x4);',
    'vand.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.AndU32x4), Pointer(LRISCVVTable.CoreVectors.AndU32x4));
  AssertAsmConditionalU32x4IntegerSlot('OrU32x4', 'function RISCVVOrU32x4(const a, b: TVecU32x4): TVecU32x4;',
    'RISCVVOrU32x4Asm(a, b, Result);', 'procedure RISCVVOrU32x4Asm(const a, b: TVecU32x4; var r: TVecU32x4);',
    'vor.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.OrU32x4), Pointer(LRISCVVTable.CoreVectors.OrU32x4));
  AssertAsmConditionalU32x4IntegerSlot('XorU32x4', 'function RISCVVXorU32x4(const a, b: TVecU32x4): TVecU32x4;',
    'RISCVVXorU32x4Asm(a, b, Result);', 'procedure RISCVVXorU32x4Asm(const a, b: TVecU32x4; var r: TVecU32x4);',
    'vxor.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.XorU32x4), Pointer(LRISCVVTable.CoreVectors.XorU32x4));
  AssertAsmConditionalU32x4IntegerSlot('NotU32x4', 'function RISCVVNotU32x4(const a: TVecU32x4): TVecU32x4;',
    'RISCVVNotU32x4Asm(a, Result);', 'procedure RISCVVNotU32x4Asm(const a: TVecU32x4; var r: TVecU32x4);',
    'vxor.vi v0, v0, -1', Pointer(LScalarTable.CoreVectors.NotU32x4), Pointer(LRISCVVTable.CoreVectors.NotU32x4));
  AssertAsmConditionalU32x4IntegerSlot('ShiftLeftU32x4', 'function RISCVVShiftLeftU32x4(const a: TVecU32x4; count: Integer): TVecU32x4;',
    'RISCVVShiftLeftU32x4Asm(a, count, Result);', 'procedure RISCVVShiftLeftU32x4Asm(const a: TVecU32x4; count: Integer; var r: TVecU32x4);',
    'vsll.vx v0, v0, a1', Pointer(LScalarTable.CoreVectors.ShiftLeftU32x4), Pointer(LRISCVVTable.CoreVectors.ShiftLeftU32x4));
  AssertAsmConditionalU32x4IntegerSlot('ShiftRightU32x4', 'function RISCVVShiftRightU32x4(const a: TVecU32x4; count: Integer): TVecU32x4;',
    'RISCVVShiftRightU32x4Asm(a, count, Result);', 'procedure RISCVVShiftRightU32x4Asm(const a: TVecU32x4; count: Integer; var r: TVecU32x4);',
    'vsrl.vx v0, v0, a1', Pointer(LScalarTable.CoreVectors.ShiftRightU32x4), Pointer(LRISCVVTable.CoreVectors.ShiftRightU32x4));
  AssertAsmConditionalU32x4IntegerSlot('MinU32x4', 'function RISCVVMinU32x4(const a, b: TVecU32x4): TVecU32x4;',
    'RISCVVMinU32x4Asm(a, b, Result);', 'procedure RISCVVMinU32x4Asm(const a, b: TVecU32x4; var r: TVecU32x4);',
    'vminu.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.MinU32x4), Pointer(LRISCVVTable.CoreVectors.MinU32x4));
  AssertAsmConditionalU32x4IntegerSlot('MaxU32x4', 'function RISCVVMaxU32x4(const a, b: TVecU32x4): TVecU32x4;',
    'RISCVVMaxU32x4Asm(a, b, Result);', 'procedure RISCVVMaxU32x4Asm(const a, b: TVecU32x4; var r: TVecU32x4);',
    'vmaxu.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.MaxU32x4), Pointer(LRISCVVTable.CoreVectors.MaxU32x4));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_I32x4CompareSlots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LAsmSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;
  LAsmSource: string;

  function CountOccurrences(const aHaystack, aNeedle: string): Integer;
  var
    LRest: string;
    LPos: SizeInt;
  begin
    Result := 0;
    LRest := aHaystack;
    LPos := Pos(aNeedle, LRest);
    while LPos > 0 do
    begin
      Inc(Result);
      Delete(LRest, 1, LPos + Length(aNeedle) - 1);
      LPos := Pos(aNeedle, LRest);
    end;
  end;

  procedure AssertRegisterHasAsmOwnedSlot(const aLabel, aSnippet: string);
  var
    LNeedle: string;
  begin
    LNeedle := LowerCase(aSnippet);
    CheckEqual(1, CountOccurrences(LRegisterSource, LNeedle), 'RegisterRISCVVBackend should keep exactly one ' + aLabel + ' source assignment site');
    CheckTrue(Pos(LNeedle, LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a dedicated asm-gated ' + aLabel + ' source assignment');
  end;

  procedure AssertAsmConditionalI32x4CompareSlot(
    const aLabel, aFunctionSnippet, aAsmOpSnippet: string;
    const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(Pos(LowerCase(aFunctionSnippet), LFacadeSource) = 0, 'no-asm RISCVV facade should no longer define the dead ' + aLabel + ' witness');
    CheckTrue(Pos(LowerCase(aAsmOpSnippet), LAsmSource) > 0, 'RVV asm source should keep the dedicated compare body for ' + aLabel);
    CheckTrue(aBackendSlot <> nil, 'RISCVV ' + aLabel + ' should stay assigned in the backend dispatch table');
    {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should keep a backend-owned runtime slot when RVV asm is compiled');
    {$ELSE}
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the base scalar runtime slot when RVV asm is not compiled on this host');
    {$ENDIF}
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for I32x4 compare dead-facade audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for I32x4 compare dead-facade audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LAsmSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LAsmSourcePath), 'RISCVV unit source should exist for I32x4 compare dead-facade audit: ' + LAsmSourcePath);
    LSourceLines.LoadFromFile(LAsmSourcePath);
    LAsmSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertRegisterHasAsmOwnedSlot('CmpEqI32x4', 'table.CoreVectors.CmpEqI32x4 := @RISCVVCmpEqI32x4;');
  AssertRegisterHasAsmOwnedSlot('CmpLtI32x4', 'table.CoreVectors.CmpLtI32x4 := @RISCVVCmpLtI32x4;');
  AssertRegisterHasAsmOwnedSlot('CmpGtI32x4', 'table.CoreVectors.CmpGtI32x4 := @RISCVVCmpGtI32x4;');
  AssertRegisterHasAsmOwnedSlot('CmpLeI32x4', 'table.CoreVectors.CmpLeI32x4 := @RISCVVCmpLeI32x4;');
  AssertRegisterHasAsmOwnedSlot('CmpGeI32x4', 'table.CoreVectors.CmpGeI32x4 := @RISCVVCmpGeI32x4;');
  AssertRegisterHasAsmOwnedSlot('CmpNeI32x4', 'table.CoreVectors.CmpNeI32x4 := @RISCVVCmpNeI32x4;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertAsmConditionalI32x4CompareSlot('CmpEqI32x4', 'function RISCVVCmpEqI32x4(const a, b: TVecI32x4): TMask4;',
    'vmseq.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.CmpEqI32x4), Pointer(LRISCVVTable.CoreVectors.CmpEqI32x4));
  AssertAsmConditionalI32x4CompareSlot('CmpLtI32x4', 'function RISCVVCmpLtI32x4(const a, b: TVecI32x4): TMask4;',
    'vmslt.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.CmpLtI32x4), Pointer(LRISCVVTable.CoreVectors.CmpLtI32x4));
  AssertAsmConditionalI32x4CompareSlot('CmpGtI32x4', 'function RISCVVCmpGtI32x4(const a, b: TVecI32x4): TMask4;',
    'vmslt.vv v0, v1, v0', Pointer(LScalarTable.CoreVectors.CmpGtI32x4), Pointer(LRISCVVTable.CoreVectors.CmpGtI32x4));
  AssertAsmConditionalI32x4CompareSlot('CmpLeI32x4', 'function RISCVVCmpLeI32x4(const a, b: TVecI32x4): TMask4;',
    'vmsle.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.CmpLeI32x4), Pointer(LRISCVVTable.CoreVectors.CmpLeI32x4));
  AssertAsmConditionalI32x4CompareSlot('CmpGeI32x4', 'function RISCVVCmpGeI32x4(const a, b: TVecI32x4): TMask4;',
    'vmnand.mm v0, v0, v0', Pointer(LScalarTable.CoreVectors.CmpGeI32x4), Pointer(LRISCVVTable.CoreVectors.CmpGeI32x4));
  AssertAsmConditionalI32x4CompareSlot('CmpNeI32x4', 'function RISCVVCmpNeI32x4(const a, b: TVecI32x4): TMask4;',
    'vmsne.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.CmpNeI32x4), Pointer(LRISCVVTable.CoreVectors.CmpNeI32x4));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_I64x2CompareSlots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LAsmSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;
  LAsmSource: string;

  function CountOccurrences(const aHaystack, aNeedle: string): Integer;
  var
    LRest: string;
    LPos: SizeInt;
  begin
    Result := 0;
    LRest := aHaystack;
    LPos := Pos(aNeedle, LRest);
    while LPos > 0 do
    begin
      Inc(Result);
      Delete(LRest, 1, LPos + Length(aNeedle) - 1);
      LPos := Pos(aNeedle, LRest);
    end;
  end;

  procedure AssertRegisterHasAsmOwnedSlot(const aLabel, aSnippet: string);
  var
    LNeedle: string;
  begin
    LNeedle := LowerCase(aSnippet);
    CheckEqual(1, CountOccurrences(LRegisterSource, LNeedle), 'RegisterRISCVVBackend should keep exactly one ' + aLabel + ' source assignment site');
    CheckTrue(Pos(LNeedle, LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a dedicated asm-gated ' + aLabel + ' source assignment');
  end;

  procedure AssertAsmConditionalI64x2CompareSlot(
    const aLabel, aFunctionSnippet, aAsmOpSnippet: string;
    const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(Pos(LowerCase(aFunctionSnippet), LFacadeSource) = 0, 'no-asm RISCVV facade should no longer define the dead ' + aLabel + ' witness');
    CheckTrue(Pos(LowerCase(aAsmOpSnippet), LAsmSource) > 0, 'RVV asm source should keep the dedicated compare body for ' + aLabel);
    CheckTrue(aBackendSlot <> nil, 'RISCVV ' + aLabel + ' should stay assigned in the backend dispatch table');
    {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should keep a backend-owned runtime slot when RVV asm is compiled');
    {$ELSE}
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the base scalar runtime slot when RVV asm is not compiled on this host');
    {$ENDIF}
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for I64x2 compare dead-facade audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for I64x2 compare dead-facade audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LAsmSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LAsmSourcePath), 'RISCVV unit source should exist for I64x2 compare dead-facade audit: ' + LAsmSourcePath);
    LSourceLines.LoadFromFile(LAsmSourcePath);
    LAsmSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertRegisterHasAsmOwnedSlot('CmpEqI64x2', 'table.CoreVectors.CmpEqI64x2 := @RISCVVCmpEqI64x2;');
  AssertRegisterHasAsmOwnedSlot('CmpLtI64x2', 'table.CoreVectors.CmpLtI64x2 := @RISCVVCmpLtI64x2;');
  AssertRegisterHasAsmOwnedSlot('CmpGtI64x2', 'table.CoreVectors.CmpGtI64x2 := @RISCVVCmpGtI64x2;');
  AssertRegisterHasAsmOwnedSlot('CmpLeI64x2', 'table.CoreVectors.CmpLeI64x2 := @RISCVVCmpLeI64x2;');
  AssertRegisterHasAsmOwnedSlot('CmpGeI64x2', 'table.CoreVectors.CmpGeI64x2 := @RISCVVCmpGeI64x2;');
  AssertRegisterHasAsmOwnedSlot('CmpNeI64x2', 'table.CoreVectors.CmpNeI64x2 := @RISCVVCmpNeI64x2;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertAsmConditionalI64x2CompareSlot('CmpEqI64x2', 'function RISCVVCmpEqI64x2(const a, b: TVecI64x2): TMask2;',
    'vmseq.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.CmpEqI64x2), Pointer(LRISCVVTable.CoreVectors.CmpEqI64x2));
  AssertAsmConditionalI64x2CompareSlot('CmpLtI64x2', 'function RISCVVCmpLtI64x2(const a, b: TVecI64x2): TMask2;',
    'vmslt.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.CmpLtI64x2), Pointer(LRISCVVTable.CoreVectors.CmpLtI64x2));
  AssertAsmConditionalI64x2CompareSlot('CmpGtI64x2', 'function RISCVVCmpGtI64x2(const a, b: TVecI64x2): TMask2;',
    'vmslt.vv v0, v1, v0', Pointer(LScalarTable.CoreVectors.CmpGtI64x2), Pointer(LRISCVVTable.CoreVectors.CmpGtI64x2));
  AssertAsmConditionalI64x2CompareSlot('CmpLeI64x2', 'function RISCVVCmpLeI64x2(const a, b: TVecI64x2): TMask2;',
    'vmsle.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.CmpLeI64x2), Pointer(LRISCVVTable.CoreVectors.CmpLeI64x2));
  AssertAsmConditionalI64x2CompareSlot('CmpGeI64x2', 'function RISCVVCmpGeI64x2(const a, b: TVecI64x2): TMask2;',
    'vmsle.vv v0, v1, v0', Pointer(LScalarTable.CoreVectors.CmpGeI64x2), Pointer(LRISCVVTable.CoreVectors.CmpGeI64x2));
  AssertAsmConditionalI64x2CompareSlot('CmpNeI64x2', 'function RISCVVCmpNeI64x2(const a, b: TVecI64x2): TMask2;',
    'vmsne.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.CmpNeI64x2), Pointer(LRISCVVTable.CoreVectors.CmpNeI64x2));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_ExactF32x4Slots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LAsmSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;
  LAsmSource: string;

  function CountOccurrences(const aHaystack, aNeedle: string): Integer;
  var
    LRest: string;
    LPos: SizeInt;
  begin
    Result := 0;
    LRest := aHaystack;
    LPos := Pos(aNeedle, LRest);
    while LPos > 0 do
    begin
      Inc(Result);
      Delete(LRest, 1, LPos + Length(aNeedle) - 1);
      LPos := Pos(aNeedle, LRest);
    end;
  end;

  procedure AssertRegisterHasAsmOwnedSlot(const aLabel, aSnippet: string);
  var
    LNeedle: string;
  begin
    LNeedle := LowerCase(aSnippet);
    CheckEqual(1, CountOccurrences(LRegisterSource, LNeedle), 'RegisterRISCVVBackend should keep exactly one ' + aLabel + ' source assignment site');
    CheckTrue(Pos(LNeedle, LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a dedicated asm-gated ' + aLabel + ' source assignment');
  end;

  procedure AssertAsmConditionalExactF32x4Slot(
    const aLabel, aFunctionSnippet, aAsmWrapperSnippet, aAsmHelperSnippet, aAsmOpSnippet: string;
    const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(Pos(LowerCase(aFunctionSnippet), LFacadeSource) = 0, 'no-asm RISCVV facade should no longer define the dead ' + aLabel + ' witness');
    CheckTrue(Pos(LowerCase(aAsmWrapperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated wrapper call for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmHelperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated helper signature for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmOpSnippet), LAsmSource) > 0, 'RVV asm source should keep a dedicated vector op body for ' + aLabel);
    CheckTrue(aBackendSlot <> nil, 'RISCVV ' + aLabel + ' should stay assigned in the backend dispatch table');
    {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should keep a backend-owned runtime slot when RVV asm is compiled');
    {$ELSE}
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the base scalar runtime slot when RVV asm is not compiled on this host');
    {$ENDIF}
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for exact F32x4 dead-facade audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for exact F32x4 dead-facade audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LAsmSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LAsmSourcePath), 'RISCVV unit source should exist for exact F32x4 dead-facade audit: ' + LAsmSourcePath);
    LSourceLines.LoadFromFile(LAsmSourcePath);
    LAsmSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertRegisterHasAsmOwnedSlot('AbsF32x4', 'table.CoreVectors.AbsF32x4 := @RISCVVAbsF32x4;');
  AssertRegisterHasAsmOwnedSlot('SqrtF32x4', 'table.CoreVectors.SqrtF32x4 := @RISCVVSqrtF32x4;');
  AssertRegisterHasAsmOwnedSlot('FmaF32x4', 'table.CoreVectors.FmaF32x4 := @RISCVVFmaF32x4;');
  AssertRegisterHasAsmOwnedSlot('RcpF32x4', 'table.CoreVectors.RcpF32x4 := @RISCVVRcpF32x4;');
  AssertRegisterHasAsmOwnedSlot('RsqrtF32x4', 'table.CoreVectors.RsqrtF32x4 := @RISCVVRsqrtF32x4;');
  AssertRegisterHasAsmOwnedSlot('ClampF32x4', 'table.CoreVectors.ClampF32x4 := @RISCVVClampF32x4;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertAsmConditionalExactF32x4Slot('AbsF32x4', 'function RISCVVAbsF32x4(const a: TVecF32x4): TVecF32x4;',
    'RISCVVAbsF32x4Asm(a, Result);', 'procedure RISCVVAbsF32x4Asm(const a: TVecF32x4; var r: TVecF32x4);',
    'vfsgnjx.vv v0, v0, v0', Pointer(LScalarTable.CoreVectors.AbsF32x4), Pointer(LRISCVVTable.CoreVectors.AbsF32x4));
  AssertAsmConditionalExactF32x4Slot('SqrtF32x4', 'function RISCVVSqrtF32x4(const a: TVecF32x4): TVecF32x4;',
    'RISCVVSqrtF32x4Asm(a, Result);', 'procedure RISCVVSqrtF32x4Asm(const a: TVecF32x4; var r: TVecF32x4);',
    'vfsqrt.v v0, v0', Pointer(LScalarTable.CoreVectors.SqrtF32x4), Pointer(LRISCVVTable.CoreVectors.SqrtF32x4));
  AssertAsmConditionalExactF32x4Slot('FmaF32x4', 'function RISCVVFmaF32x4(const a, b, c: TVecF32x4): TVecF32x4;',
    'RISCVVFmaF32x4Asm(a, b, c, Result);', 'procedure RISCVVFmaF32x4Asm(const a, b, c: TVecF32x4; var r: TVecF32x4);',
    'vfmacc.vv v2, v0, v1', Pointer(LScalarTable.CoreVectors.FmaF32x4), Pointer(LRISCVVTable.CoreVectors.FmaF32x4));
  AssertAsmConditionalExactF32x4Slot('RcpF32x4', 'function RISCVVRcpF32x4(const a: TVecF32x4): TVecF32x4;',
    'RISCVVRcpF32x4Asm(a, Result);', 'procedure RISCVVRcpF32x4Asm(const a: TVecF32x4; var r: TVecF32x4);',
    'vfrec7.v v0, v0', Pointer(LScalarTable.CoreVectors.RcpF32x4), Pointer(LRISCVVTable.CoreVectors.RcpF32x4));
  AssertAsmConditionalExactF32x4Slot('RsqrtF32x4', 'function RISCVVRsqrtF32x4(const a: TVecF32x4): TVecF32x4;',
    'RISCVVRsqrtF32x4Asm(a, Result);', 'procedure RISCVVRsqrtF32x4Asm(const a: TVecF32x4; var r: TVecF32x4);',
    'vfrsqrt7.v v0, v0', Pointer(LScalarTable.CoreVectors.RsqrtF32x4), Pointer(LRISCVVTable.CoreVectors.RsqrtF32x4));
  AssertAsmConditionalExactF32x4Slot('ClampF32x4', 'function RISCVVClampF32x4(const a, minVal, maxVal: TVecF32x4): TVecF32x4;',
    'RISCVVClampF32x4Asm(a, minVal, maxVal, Result);', 'procedure RISCVVClampF32x4Asm(const a, minVal, maxVal: TVecF32x4; var r: TVecF32x4);',
    'vfmin.vv v0, v0, v2', Pointer(LScalarTable.CoreVectors.ClampF32x4), Pointer(LRISCVVTable.CoreVectors.ClampF32x4));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_F32x4UtilitySlots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LAsmSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;
  LAsmSource: string;

  function CountOccurrences(const aHaystack, aNeedle: string): Integer;
  var
    LRest: string;
    LPos: SizeInt;
  begin
    Result := 0;
    LRest := aHaystack;
    LPos := Pos(aNeedle, LRest);
    while LPos > 0 do
    begin
      Inc(Result);
      Delete(LRest, 1, LPos + Length(aNeedle) - 1);
      LPos := Pos(aNeedle, LRest);
    end;
  end;

  procedure AssertRegisterHasAsmOwnedSlot(const aLabel, aSnippet: string);
  var
    LNeedle: string;
  begin
    LNeedle := LowerCase(aSnippet);
    CheckEqual(1, CountOccurrences(LRegisterSource, LNeedle), 'RegisterRISCVVBackend should keep exactly one ' + aLabel + ' source assignment site');
    CheckTrue(Pos(LNeedle, LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a dedicated asm-gated ' + aLabel + ' source assignment');
  end;

  procedure AssertAsmConditionalUtilityF32x4Slot(
    const aLabel, aFunctionSnippet, aAsmWrapperSnippet, aAsmHelperSnippet, aAsmOpSnippet: string;
    const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(Pos(LowerCase(aFunctionSnippet), LFacadeSource) = 0, 'no-asm RISCVV facade should no longer define the dead ' + aLabel + ' witness');
    CheckTrue(Pos(LowerCase(aAsmWrapperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated wrapper call for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmHelperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated helper signature for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmOpSnippet), LAsmSource) > 0, 'RVV asm source should keep a dedicated vector op body for ' + aLabel);
    CheckTrue(aBackendSlot <> nil, 'RISCVV ' + aLabel + ' should stay assigned in the backend dispatch table');
    {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should keep a backend-owned runtime slot when RVV asm is compiled');
    {$ELSE}
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the base scalar runtime slot when RVV asm is not compiled on this host');
    {$ENDIF}
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for utility F32x4 dead-facade audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for utility F32x4 dead-facade audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LAsmSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LAsmSourcePath), 'RISCVV unit source should exist for utility F32x4 dead-facade audit: ' + LAsmSourcePath);
    LSourceLines.LoadFromFile(LAsmSourcePath);
    LAsmSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertRegisterHasAsmOwnedSlot('LoadF32x4', 'table.CoreVectors.LoadF32x4 := @RISCVVLoadF32x4;');
  AssertRegisterHasAsmOwnedSlot('LoadF32x4Aligned', 'table.CoreVectors.LoadF32x4Aligned := @RISCVVLoadF32x4Aligned;');
  AssertRegisterHasAsmOwnedSlot('SplatF32x4', 'table.CoreVectors.SplatF32x4 := @RISCVVSplatF32x4;');
  AssertRegisterHasAsmOwnedSlot('ZeroF32x4', 'table.CoreVectors.ZeroF32x4 := @RISCVVZeroF32x4;');
  AssertRegisterHasAsmOwnedSlot('SelectF32x4', 'table.CoreVectors.SelectF32x4 := @RISCVVSelectF32x4;');
  AssertRegisterHasAsmOwnedSlot('InsertF32x4', 'table.CoreVectors.InsertF32x4 := @RISCVVInsertF32x4;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertAsmConditionalUtilityF32x4Slot('LoadF32x4', 'function RISCVVLoadF32x4(p: PSingle): TVecF32x4;',
    'RISCVVLoadF32x4Asm(p, Result);', 'procedure RISCVVLoadF32x4Asm(p: PSingle; var r: TVecF32x4);',
    'vle32.v v0, (a0)', Pointer(LScalarTable.CoreVectors.LoadF32x4), Pointer(LRISCVVTable.CoreVectors.LoadF32x4));
  AssertAsmConditionalUtilityF32x4Slot('LoadF32x4Aligned', 'function RISCVVLoadF32x4Aligned(p: PSingle): TVecF32x4;',
    'RISCVVLoadF32x4AlignedAsm(p, Result);', 'procedure RISCVVLoadF32x4AlignedAsm(p: PSingle; var r: TVecF32x4);',
    'vle32.v v0, (a0)', Pointer(LScalarTable.CoreVectors.LoadF32x4Aligned), Pointer(LRISCVVTable.CoreVectors.LoadF32x4Aligned));
  AssertAsmConditionalUtilityF32x4Slot('SplatF32x4', 'function RISCVVSplatF32x4(value: Single): TVecF32x4;',
    'RISCVVSplatF32x4Asm(value, Result);', 'procedure RISCVVSplatF32x4Asm(value: Single; var r: TVecF32x4);',
    'vfmv.v.f v0, f10', Pointer(LScalarTable.CoreVectors.SplatF32x4), Pointer(LRISCVVTable.CoreVectors.SplatF32x4));
  AssertAsmConditionalUtilityF32x4Slot('ZeroF32x4', 'function RISCVVZeroF32x4: TVecF32x4;',
    'RISCVVZeroF32x4Asm(Result);', 'procedure RISCVVZeroF32x4Asm(var r: TVecF32x4);',
    'vmv.v.i v0, 0', Pointer(LScalarTable.CoreVectors.ZeroF32x4), Pointer(LRISCVVTable.CoreVectors.ZeroF32x4));
  AssertAsmConditionalUtilityF32x4Slot('SelectF32x4', 'function RISCVVSelectF32x4(const mask: TMask4; const a, b: TVecF32x4): TVecF32x4;',
    'RISCVVSelectF32x4Asm(mask, a, b, Result);', 'procedure RISCVVSelectF32x4Asm(const mask: TMask4; const a, b: TVecF32x4; var r: TVecF32x4);',
    'vmerge.vvm v1, v2, v1, v0', Pointer(LScalarTable.CoreVectors.SelectF32x4), Pointer(LRISCVVTable.CoreVectors.SelectF32x4));
  AssertAsmConditionalUtilityF32x4Slot('InsertF32x4', 'function RISCVVInsertF32x4(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4;',
    'RISCVVInsertF32x4Asm(a, value, LIndex, Result);', 'procedure RISCVVInsertF32x4Asm(const a: TVecF32x4; value: Single; index: Integer; var r: TVecF32x4);',
    'fsw f10, (t0)', Pointer(LScalarTable.CoreVectors.InsertF32x4), Pointer(LRISCVVTable.CoreVectors.InsertF32x4));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_F64x2UtilitySlots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LAsmSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;
  LAsmSource: string;

  function CountOccurrences(const aHaystack, aNeedle: string): Integer;
  var
    LRest: string;
    LPos: SizeInt;
  begin
    Result := 0;
    LRest := aHaystack;
    LPos := Pos(aNeedle, LRest);
    while LPos > 0 do
    begin
      Inc(Result);
      Delete(LRest, 1, LPos + Length(aNeedle) - 1);
      LPos := Pos(aNeedle, LRest);
    end;
  end;

  procedure AssertRegisterHasAsmOwnedSlot(const aLabel, aSnippet: string);
  var
    LNeedle: string;
  begin
    LNeedle := LowerCase(aSnippet);
    CheckEqual(1, CountOccurrences(LRegisterSource, LNeedle), 'RegisterRISCVVBackend should keep exactly one ' + aLabel + ' source assignment site');
    CheckTrue(Pos(LNeedle, LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a dedicated asm-gated ' + aLabel + ' source assignment');
  end;

  procedure AssertAsmConditionalUtilityF64x2Slot(
    const aLabel, aFunctionSnippet, aAsmWrapperSnippet, aAsmHelperSnippet, aAsmOpSnippet: string;
    const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(Pos(LowerCase(aFunctionSnippet), LFacadeSource) = 0, 'no-asm RISCVV facade should no longer define the dead ' + aLabel + ' witness');
    CheckTrue(Pos(LowerCase(aAsmWrapperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated wrapper call for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmHelperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated helper signature for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmOpSnippet), LAsmSource) > 0, 'RVV asm source should keep a dedicated vector op body for ' + aLabel);
    CheckTrue(aBackendSlot <> nil, 'RISCVV ' + aLabel + ' should stay assigned in the backend dispatch table');
    {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should keep a backend-owned runtime slot when RVV asm is compiled');
    {$ELSE}
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the base scalar runtime slot when RVV asm is not compiled on this host');
    {$ENDIF}
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for utility F64x2 dead-facade audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for utility F64x2 dead-facade audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LAsmSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LAsmSourcePath), 'RISCVV unit source should exist for utility F64x2 dead-facade audit: ' + LAsmSourcePath);
    LSourceLines.LoadFromFile(LAsmSourcePath);
    LAsmSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertRegisterHasAsmOwnedSlot('LoadF64x2', 'table.CoreVectors.LoadF64x2 := @RISCVVLoadF64x2;');
  AssertRegisterHasAsmOwnedSlot('SplatF64x2', 'table.CoreVectors.SplatF64x2 := @RISCVVSplatF64x2;');
  AssertRegisterHasAsmOwnedSlot('ZeroF64x2', 'table.CoreVectors.ZeroF64x2 := @RISCVVZeroF64x2;');
  AssertRegisterHasAsmOwnedSlot('InsertF64x2', 'table.CoreVectors.InsertF64x2 := @RISCVVInsertF64x2;');
  AssertRegisterHasAsmOwnedSlot('SelectF64x2', 'table.CoreVectors.SelectF64x2 := @RISCVVSelectF64x2;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertAsmConditionalUtilityF64x2Slot('LoadF64x2', 'function RISCVVLoadF64x2(p: PDouble): TVecF64x2;',
    'RISCVVLoadF64x2Asm(p, Result);', 'procedure RISCVVLoadF64x2Asm(p: PDouble; var r: TVecF64x2);',
    'vle64.v v0, (a0)', Pointer(LScalarTable.CoreVectors.LoadF64x2), Pointer(LRISCVVTable.CoreVectors.LoadF64x2));
  AssertAsmConditionalUtilityF64x2Slot('SplatF64x2', 'function RISCVVSplatF64x2(value: Double): TVecF64x2;',
    'RISCVVSplatF64x2Asm(value, Result);', 'procedure RISCVVSplatF64x2Asm(value: Double; var r: TVecF64x2);',
    'vfmv.v.f v0, f10', Pointer(LScalarTable.CoreVectors.SplatF64x2), Pointer(LRISCVVTable.CoreVectors.SplatF64x2));
  AssertAsmConditionalUtilityF64x2Slot('ZeroF64x2', 'function RISCVVZeroF64x2: TVecF64x2;',
    'RISCVVZeroF64x2Asm(Result);', 'procedure RISCVVZeroF64x2Asm(var r: TVecF64x2);',
    'vmv.v.i v0, 0', Pointer(LScalarTable.CoreVectors.ZeroF64x2), Pointer(LRISCVVTable.CoreVectors.ZeroF64x2));
  AssertAsmConditionalUtilityF64x2Slot('InsertF64x2', 'function RISCVVInsertF64x2(const a: TVecF64x2; value: Double; index: Integer): TVecF64x2;',
    'RISCVVInsertF64x2Asm(a, value, LIndex, Result);', 'procedure RISCVVInsertF64x2Asm(const a: TVecF64x2; value: Double; index: Integer; var r: TVecF64x2);',
    'fsd f10, (t0)', Pointer(LScalarTable.CoreVectors.InsertF64x2), Pointer(LRISCVVTable.CoreVectors.InsertF64x2));
  AssertAsmConditionalUtilityF64x2Slot('SelectF64x2', 'function RISCVVSelectF64x2(const mask: TMask2; const a, b: TVecF64x2): TVecF64x2;',
    'RISCVVSelectF64x2Asm(mask, a, b, Result);', 'procedure RISCVVSelectF64x2Asm(const mask: TMask2; const a, b: TVecF64x2; var r: TVecF64x2);',
    'vmerge.vvm v1, v2, v1, v0', Pointer(LScalarTable.CoreVectors.SelectF64x2), Pointer(LRISCVVTable.CoreVectors.SelectF64x2));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_WideFloatLoadSlots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LAsmSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;
  LAsmSource: string;

  function CountOccurrences(const aHaystack, aNeedle: string): Integer;
  var
    LRest: string;
    LPos: SizeInt;
  begin
    Result := 0;
    LRest := aHaystack;
    LPos := Pos(aNeedle, LRest);
    while LPos > 0 do
    begin
      Inc(Result);
      Delete(LRest, 1, LPos + Length(aNeedle) - 1);
      LPos := Pos(aNeedle, LRest);
    end;
  end;

  procedure AssertRegisterHasAsmOwnedSlot(const aLabel, aSnippet: string);
  var
    LNeedle: string;
  begin
    LNeedle := LowerCase(aSnippet);
    CheckEqual(1, CountOccurrences(LRegisterSource, LNeedle), 'RegisterRISCVVBackend should keep exactly one ' + aLabel + ' source assignment site');
    CheckTrue(Pos(LNeedle, LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a dedicated asm-gated ' + aLabel + ' source assignment');
  end;

  procedure AssertAsmConditionalWideLoadSlot(
    const aLabel, aFunctionSnippet, aAsmWrapperSnippet, aAsmHelperSnippet, aAsmOpSnippet: string;
    const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(Pos(LowerCase(aFunctionSnippet), LFacadeSource) = 0, 'no-asm RISCVV facade should no longer define the dead ' + aLabel + ' witness');
    CheckTrue(Pos(LowerCase(aAsmWrapperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated wrapper call for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmHelperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated helper signature for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmOpSnippet), LAsmSource) > 0, 'RVV asm source should keep a dedicated vector op body for ' + aLabel);
    CheckTrue(aBackendSlot <> nil, 'RISCVV ' + aLabel + ' should stay assigned in the backend dispatch table');
    {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should keep a backend-owned runtime slot when RVV asm is compiled');
    {$ELSE}
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the base scalar runtime slot when RVV asm is not compiled on this host');
    {$ENDIF}
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for wide float load dead-facade audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for wide float load dead-facade audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LAsmSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LAsmSourcePath), 'RISCVV unit source should exist for wide float load dead-facade audit: ' + LAsmSourcePath);
    LSourceLines.LoadFromFile(LAsmSourcePath);
    LAsmSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertRegisterHasAsmOwnedSlot('LoadF32x8', 'table.CoreVectors.LoadF32x8 := @RISCVVLoadF32x8;');
  AssertRegisterHasAsmOwnedSlot('LoadF32x16', 'table.CoreVectors.LoadF32x16 := @RISCVVLoadF32x16;');
  AssertRegisterHasAsmOwnedSlot('LoadF64x4', 'table.CoreVectors.LoadF64x4 := @RISCVVLoadF64x4;');
  AssertRegisterHasAsmOwnedSlot('LoadF64x8', 'table.CoreVectors.LoadF64x8 := @RISCVVLoadF64x8;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertAsmConditionalWideLoadSlot('LoadF32x8', 'function RISCVVLoadF32x8(p: PSingle): TVecF32x8;',
    'RISCVVLoadF32x8Asm(p, Result);', 'procedure RISCVVLoadF32x8Asm(p: PSingle; var r: TVecF32x8);',
    'vsetivli zero, 8, 0xd1', Pointer(LScalarTable.CoreVectors.LoadF32x8), Pointer(LRISCVVTable.CoreVectors.LoadF32x8));
  AssertAsmConditionalWideLoadSlot('LoadF32x16', 'function RISCVVLoadF32x16(p: PSingle): TVecF32x16;',
    'RISCVVLoadF32x16Asm(p, Result);', 'procedure RISCVVLoadF32x16Asm(p: PSingle; var r: TVecF32x16);',
    'vsetivli zero, 16, 0xd2', Pointer(LScalarTable.CoreVectors.LoadF32x16), Pointer(LRISCVVTable.CoreVectors.LoadF32x16));
  AssertAsmConditionalWideLoadSlot('LoadF64x4', 'function RISCVVLoadF64x4(p: PDouble): TVecF64x4;',
    'RISCVVLoadF64x4Asm(p, Result);', 'procedure RISCVVLoadF64x4Asm(p: PDouble; var r: TVecF64x4);',
    'vsetivli zero, 4, 0xd9', Pointer(LScalarTable.CoreVectors.LoadF64x4), Pointer(LRISCVVTable.CoreVectors.LoadF64x4));
  AssertAsmConditionalWideLoadSlot('LoadF64x8', 'function RISCVVLoadF64x8(p: PDouble): TVecF64x8;',
    'RISCVVLoadF64x8Asm(p, Result);', 'procedure RISCVVLoadF64x8Asm(p: PDouble; var r: TVecF64x8);',
    'vsetivli zero, 8, 0xda', Pointer(LScalarTable.CoreVectors.LoadF64x8), Pointer(LRISCVVTable.CoreVectors.LoadF64x8));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_FloatStoreSlots_Keep_BackendOwnership_And_Reuse_ScalarPreconditions_When_NoAsm;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LAsmSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;
  LAsmSource: string;

  function CountOccurrences(const aHaystack, aNeedle: string): Integer;
  var
    LRest: string;
    LPos: SizeInt;
  begin
    Result := 0;
    LRest := aHaystack;
    LPos := Pos(aNeedle, LRest);
    while LPos > 0 do
    begin
      Inc(Result);
      Delete(LRest, 1, LPos + Length(aNeedle) - 1);
      LPos := Pos(aNeedle, LRest);
    end;
  end;

  procedure AssertRegisterKeepsBackendOwnedSlot(const aLabel, aSnippet: string);
  var
    LNeedle: string;
  begin
    LNeedle := LowerCase(aSnippet);
    CheckEqual(1, CountOccurrences(LRegisterSource, LNeedle), 'RegisterRISCVVBackend should keep exactly one ' + aLabel + ' backend-owned assignment site');
    CheckTrue(Pos(LNeedle, LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a dedicated backend-owned assignment for ' + aLabel);
  end;

  procedure AssertScalarPreconditionForwardingStoreSlot(
    const aLabel, aFacadeScalarSnippet, aAsmSignatureSnippet, aAsmOpSnippet: string;
    const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(Pos(LowerCase(aFacadeScalarSnippet), LFacadeSource) > 0, 'no-asm RISCVV facade should reuse the scalar store precondition/body for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmSignatureSnippet), LAsmSource) > 0, 'RVV asm source should keep the dedicated helper signature for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmOpSnippet), LAsmSource) > 0, 'RVV asm source should keep the dedicated vector store body for ' + aLabel);
    CheckTrue(aBackendSlot <> nil, 'RISCVV ' + aLabel + ' should stay assigned in the backend dispatch table');
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should stay backend-owned instead of reusing the scalar slot');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for float store ownership audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for float store ownership audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LAsmSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LAsmSourcePath), 'RISCVV unit source should exist for float store ownership audit: ' + LAsmSourcePath);
    LSourceLines.LoadFromFile(LAsmSourcePath);
    LAsmSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertRegisterKeepsBackendOwnedSlot('StoreF32x4', 'table.CoreVectors.StoreF32x4 := @RISCVVStoreF32x4;');
  AssertRegisterKeepsBackendOwnedSlot('StoreF32x4Aligned', 'table.CoreVectors.StoreF32x4Aligned := @RISCVVStoreF32x4Aligned;');
  AssertRegisterKeepsBackendOwnedSlot('StoreF32x8', 'table.CoreVectors.StoreF32x8 := @RISCVVStoreF32x8;');
  AssertRegisterKeepsBackendOwnedSlot('StoreF32x16', 'table.CoreVectors.StoreF32x16 := @RISCVVStoreF32x16;');
  AssertRegisterKeepsBackendOwnedSlot('StoreF64x2', 'table.CoreVectors.StoreF64x2 := @RISCVVStoreF64x2;');
  AssertRegisterKeepsBackendOwnedSlot('StoreF64x4', 'table.CoreVectors.StoreF64x4 := @RISCVVStoreF64x4;');
  AssertRegisterKeepsBackendOwnedSlot('StoreF64x8', 'table.CoreVectors.StoreF64x8 := @RISCVVStoreF64x8;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertScalarPreconditionForwardingStoreSlot('StoreF32x4', 'ScalarStoreF32x4(p, a);',
    'procedure RISCVVStoreF32x4(p: PSingle; const a: TVecF32x4); assembler; nostackframe;', 'vsetivli zero, 4, 0xd0',
    Pointer(LScalarTable.CoreVectors.StoreF32x4), Pointer(LRISCVVTable.CoreVectors.StoreF32x4));
  AssertScalarPreconditionForwardingStoreSlot('StoreF32x4Aligned', 'ScalarStoreF32x4Aligned(p, a);',
    'procedure RISCVVStoreF32x4Aligned(p: PSingle; const a: TVecF32x4); assembler; nostackframe;', 'vsetivli zero, 4, 0xd0',
    Pointer(LScalarTable.CoreVectors.StoreF32x4Aligned), Pointer(LRISCVVTable.CoreVectors.StoreF32x4Aligned));
  AssertScalarPreconditionForwardingStoreSlot('StoreF32x8', 'ScalarStoreF32x8(p, a);',
    'procedure RISCVVStoreF32x8(p: PSingle; const a: TVecF32x8); assembler; nostackframe;', 'vsetivli zero, 8, 0xd1',
    Pointer(LScalarTable.CoreVectors.StoreF32x8), Pointer(LRISCVVTable.CoreVectors.StoreF32x8));
  AssertScalarPreconditionForwardingStoreSlot('StoreF32x16', 'ScalarStoreF32x16(p, a);',
    'procedure RISCVVStoreF32x16(p: PSingle; const a: TVecF32x16); assembler; nostackframe;', 'vsetivli zero, 16, 0xd2',
    Pointer(LScalarTable.CoreVectors.StoreF32x16), Pointer(LRISCVVTable.CoreVectors.StoreF32x16));
  AssertScalarPreconditionForwardingStoreSlot('StoreF64x2', 'ScalarStoreF64x2(p, a);',
    'procedure RISCVVStoreF64x2(p: PDouble; const a: TVecF64x2); assembler; nostackframe;', 'vsetivli zero, 2, 0xd8',
    Pointer(LScalarTable.CoreVectors.StoreF64x2), Pointer(LRISCVVTable.CoreVectors.StoreF64x2));
  AssertScalarPreconditionForwardingStoreSlot('StoreF64x4', 'ScalarStoreF64x4(p, a);',
    'procedure RISCVVStoreF64x4(p: PDouble; const a: TVecF64x4); assembler; nostackframe;', 'vsetivli zero, 4, 0xd9',
    Pointer(LScalarTable.CoreVectors.StoreF64x4), Pointer(LRISCVVTable.CoreVectors.StoreF64x4));
  AssertScalarPreconditionForwardingStoreSlot('StoreF64x8', 'ScalarStoreF64x8(p, a);',
    'procedure RISCVVStoreF64x8(p: PDouble; const a: TVecF64x8); assembler; nostackframe;', 'vsetivli zero, 8, 0xda',
    Pointer(LScalarTable.CoreVectors.StoreF64x8), Pointer(LRISCVVTable.CoreVectors.StoreF64x8));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_LocalExtremaF64x2_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LAsmSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;
  LAsmSource: string;

  function CountOccurrences(const aHaystack, aNeedle: string): Integer;
  var
    LRest: string;
    LPos: SizeInt;
  begin
    Result := 0;
    LRest := aHaystack;
    LPos := Pos(aNeedle, LRest);
    while LPos > 0 do
    begin
      Inc(Result);
      Delete(LRest, 1, LPos + Length(aNeedle) - 1);
      LPos := Pos(aNeedle, LRest);
    end;
  end;

  procedure AssertRegisterHasAsmOwnedSlot(const aLabel, aSnippet: string);
  var
    LNeedle: string;
  begin
    LNeedle := LowerCase(aSnippet);
    CheckEqual(1, CountOccurrences(LRegisterSource, LNeedle), 'RegisterRISCVVBackend should keep exactly one ' + aLabel + ' source assignment site');
    CheckTrue(Pos(LNeedle, LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a dedicated asm-gated ' + aLabel + ' source assignment');
  end;

  procedure AssertAsmConditionalExtremaF64x2Slot(
    const aLabel, aFunctionSnippet, aAsmWrapperSnippet, aAsmHelperSnippet, aAsmOpSnippet: string;
    const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(Pos(LowerCase(aFunctionSnippet), LFacadeSource) = 0, 'no-asm RISCVV facade should no longer define the dead ' + aLabel + ' witness');
    CheckTrue(Pos(LowerCase(aAsmWrapperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated wrapper call for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmHelperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated helper signature for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmOpSnippet), LAsmSource) > 0, 'RVV asm source should keep a dedicated vector op body for ' + aLabel);
    CheckTrue(aBackendSlot <> nil, 'RISCVV ' + aLabel + ' should stay assigned in the backend dispatch table');
    {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should keep a backend-owned runtime slot when RVV asm is compiled');
    {$ELSE}
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the base scalar runtime slot when RVV asm is not compiled on this host');
    {$ENDIF}
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for local extrema F64x2 dead-facade audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for local extrema F64x2 dead-facade audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LAsmSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LAsmSourcePath), 'RISCVV unit source should exist for local extrema F64x2 dead-facade audit: ' + LAsmSourcePath);
    LSourceLines.LoadFromFile(LAsmSourcePath);
    LAsmSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertRegisterHasAsmOwnedSlot('MinF64x2', 'table.CoreVectors.MinF64x2 := @RISCVVMinF64x2;');
  AssertRegisterHasAsmOwnedSlot('MaxF64x2', 'table.CoreVectors.MaxF64x2 := @RISCVVMaxF64x2;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertAsmConditionalExtremaF64x2Slot('MinF64x2', 'function RISCVVMinF64x2(const a, b: TVecF64x2): TVecF64x2;',
    'RISCVVMinF64x2Asm(a, b, Result);', 'procedure RISCVVMinF64x2Asm(const a, b: TVecF64x2; var r: TVecF64x2);',
    'vfmin.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.MinF64x2), Pointer(LRISCVVTable.CoreVectors.MinF64x2));
  AssertAsmConditionalExtremaF64x2Slot('MaxF64x2', 'function RISCVVMaxF64x2(const a, b: TVecF64x2): TVecF64x2;',
    'RISCVVMaxF64x2Asm(a, b, Result);', 'procedure RISCVVMaxF64x2Asm(const a, b: TVecF64x2; var r: TVecF64x2);',
    'vfmax.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.MaxF64x2), Pointer(LRISCVVTable.CoreVectors.MaxF64x2));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_LocalExtremaF32x4_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LAsmSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;
  LAsmSource: string;

  function CountOccurrences(const aHaystack, aNeedle: string): Integer;
  var
    LRest: string;
    LPos: SizeInt;
  begin
    Result := 0;
    LRest := aHaystack;
    LPos := Pos(aNeedle, LRest);
    while LPos > 0 do
    begin
      Inc(Result);
      Delete(LRest, 1, LPos + Length(aNeedle) - 1);
      LPos := Pos(aNeedle, LRest);
    end;
  end;

  procedure AssertRegisterHasAsmOwnedSlot(const aLabel, aSnippet: string);
  var
    LNeedle: string;
  begin
    LNeedle := LowerCase(aSnippet);
    CheckEqual(1, CountOccurrences(LRegisterSource, LNeedle), 'RegisterRISCVVBackend should keep exactly one ' + aLabel + ' source assignment site');
    CheckTrue(Pos(LNeedle, LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a dedicated asm-gated ' + aLabel + ' source assignment');
  end;

  procedure AssertAsmConditionalExtremaF32x4Slot(
    const aLabel, aFunctionSnippet, aAsmWrapperSnippet, aAsmHelperSnippet, aAsmOpSnippet: string;
    const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(Pos(LowerCase(aFunctionSnippet), LFacadeSource) = 0, 'no-asm RISCVV facade should no longer define the dead ' + aLabel + ' witness');
    CheckTrue(Pos(LowerCase(aAsmWrapperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated wrapper call for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmHelperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated helper signature for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmOpSnippet), LAsmSource) > 0, 'RVV asm source should keep a dedicated vector op body for ' + aLabel);
    CheckTrue(aBackendSlot <> nil, 'RISCVV ' + aLabel + ' should stay assigned in the backend dispatch table');
    {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should keep a backend-owned runtime slot when RVV asm is compiled');
    {$ELSE}
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the base scalar runtime slot when RVV asm is not compiled on this host');
    {$ENDIF}
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for local extrema F32x4 dead-facade audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for local extrema F32x4 dead-facade audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LAsmSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LAsmSourcePath), 'RISCVV unit source should exist for local extrema F32x4 dead-facade audit: ' + LAsmSourcePath);
    LSourceLines.LoadFromFile(LAsmSourcePath);
    LAsmSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertRegisterHasAsmOwnedSlot('MinF32x4', 'table.CoreVectors.MinF32x4 := @RISCVVMinF32x4;');
  AssertRegisterHasAsmOwnedSlot('MaxF32x4', 'table.CoreVectors.MaxF32x4 := @RISCVVMaxF32x4;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertAsmConditionalExtremaF32x4Slot('MinF32x4', 'function RISCVVMinF32x4(const a, b: TVecF32x4): TVecF32x4;',
    'RISCVVMinF32x4Asm(a, b, Result);', 'procedure RISCVVMinF32x4Asm(const a, b: TVecF32x4; var r: TVecF32x4);',
    'vfmin.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.MinF32x4), Pointer(LRISCVVTable.CoreVectors.MinF32x4));
  AssertAsmConditionalExtremaF32x4Slot('MaxF32x4', 'function RISCVVMaxF32x4(const a, b: TVecF32x4): TVecF32x4;',
    'RISCVVMaxF32x4Asm(a, b, Result);', 'procedure RISCVVMaxF32x4Asm(const a, b: TVecF32x4; var r: TVecF32x4);',
    'vfmax.vv v0, v0, v1', Pointer(LScalarTable.CoreVectors.MaxF32x4), Pointer(LRISCVVTable.CoreVectors.MaxF32x4));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_CrossF32x3_Drops_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LAsmSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;
  LAsmSource: string;

  function CountOccurrences(const aHaystack, aNeedle: string): Integer;
  var
    LRest: string;
    LPos: SizeInt;
  begin
    Result := 0;
    LRest := aHaystack;
    LPos := Pos(aNeedle, LRest);
    while LPos > 0 do
    begin
      Inc(Result);
      Delete(LRest, 1, LPos + Length(aNeedle) - 1);
      LPos := Pos(aNeedle, LRest);
    end;
  end;

  procedure AssertRegisterHasAsmOwnedSlot(const aLabel, aSnippet: string);
  var
    LNeedle: string;
  begin
    LNeedle := LowerCase(aSnippet);
    CheckEqual(1, CountOccurrences(LRegisterSource, LNeedle), 'RegisterRISCVVBackend should keep exactly one ' + aLabel + ' source assignment site');
    CheckTrue(Pos(LNeedle, LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a dedicated asm-gated ' + aLabel + ' source assignment');
  end;

  procedure AssertAsmConditionalCrossF32x3Slot(
    const aFunctionSnippet, aAsmWrapperSnippet, aAsmHelperSnippet, aAsmBodySnippet, aAsmZeroWSnippet: string;
    const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(Pos(LowerCase(aFunctionSnippet), LFacadeSource) = 0, 'no-asm RISCVV facade should no longer define the dead CrossF32x3 witness');
    CheckTrue(Pos(LowerCase(aAsmWrapperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated wrapper call for CrossF32x3');
    CheckTrue(Pos(LowerCase(aAsmHelperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated helper signature for CrossF32x3');
    CheckTrue(Pos(LowerCase(aAsmBodySnippet), LAsmSource) > 0, 'RVV asm source should keep the vector multiply/subtract body for CrossF32x3');
    CheckTrue(Pos(LowerCase(aAsmZeroWSnippet), LAsmSource) > 0, 'RVV asm source should keep explicit w-lane zeroing for CrossF32x3');
    CheckTrue(aBackendSlot <> nil, 'RISCVV CrossF32x3 should stay assigned in the backend dispatch table');
    {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV CrossF32x3 should keep a backend-owned runtime slot when RVV asm is compiled');
    {$ELSE}
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV CrossF32x3 should reuse the base scalar runtime slot when RVV asm is not compiled on this host');
    {$ENDIF}
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for CrossF32x3 dead-facade audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for CrossF32x3 dead-facade audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LAsmSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LAsmSourcePath), 'RISCVV unit source should exist for CrossF32x3 dead-facade audit: ' + LAsmSourcePath);
    LSourceLines.LoadFromFile(LAsmSourcePath);
    LAsmSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertRegisterHasAsmOwnedSlot('CrossF32x3', 'table.CoreVectors.CrossF32x3 := @RISCVVCrossF32x3;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertAsmConditionalCrossF32x3Slot(
    'function RISCVVCrossF32x3(const a, b: TVecF32x4): TVecF32x4;', 'RISCVVCrossF32x3Asm(a, b, Result);',
    'procedure RISCVVCrossF32x3Asm(const a, b: TVecF32x4; var r: TVecF32x4);', 'fsub.s f6, f6, f7',
    'sw zero, 12(a2)', Pointer(LScalarTable.CoreVectors.CrossF32x3), Pointer(LRISCVVTable.CoreVectors.CrossF32x3));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_NormalizeF32Slots_Drop_DeadNoAsmFacade_While_Keeping_AsmConditional_RuntimeBinding;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LAsmSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;
  LAsmSource: string;

  function CountOccurrences(const aHaystack, aNeedle: string): Integer;
  var
    LRest: string;
    LPos: SizeInt;
  begin
    Result := 0;
    LRest := aHaystack;
    LPos := Pos(aNeedle, LRest);
    while LPos > 0 do
    begin
      Inc(Result);
      Delete(LRest, 1, LPos + Length(aNeedle) - 1);
      LPos := Pos(aNeedle, LRest);
    end;
  end;

  procedure AssertRegisterHasAsmOwnedSlot(const aLabel, aSnippet: string);
  var
    LNeedle: string;
  begin
    LNeedle := LowerCase(aSnippet);
    CheckEqual(1, CountOccurrences(LRegisterSource, LNeedle), 'RegisterRISCVVBackend should keep exactly one ' + aLabel + ' source assignment site');
    CheckTrue(Pos(LNeedle, LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a dedicated asm-gated ' + aLabel + ' source assignment');
  end;

  procedure AssertAsmConditionalNormalizeF32Slot(
    const aLabel, aFunctionSnippet, aAsmWrapperSnippet, aAsmHelperSnippet, aAsmBranchSnippet, aAsmBodySnippet: string;
    const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(Pos(LowerCase(aFunctionSnippet), LFacadeSource) = 0, 'no-asm RISCVV facade should no longer define the dead ' + aLabel + ' witness');
    CheckTrue(Pos(LowerCase(aAsmWrapperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated wrapper call for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmHelperSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated helper signature for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmBranchSnippet), LAsmSource) > 0, 'RVV asm source should keep the zero-branch guard for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmBodySnippet), LAsmSource) > 0, 'RVV asm source should keep the vector normalize body for ' + aLabel);
    CheckTrue(aBackendSlot <> nil, 'RISCVV ' + aLabel + ' should stay assigned in the backend dispatch table');
    {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should keep a backend-owned runtime slot when RVV asm is compiled');
    {$ELSE}
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the base scalar runtime slot when RVV asm is not compiled on this host');
    {$ENDIF}
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for normalize dead-facade audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for normalize dead-facade audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LAsmSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LAsmSourcePath), 'RISCVV unit source should exist for normalize dead-facade audit: ' + LAsmSourcePath);
    LSourceLines.LoadFromFile(LAsmSourcePath);
    LAsmSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertRegisterHasAsmOwnedSlot('NormalizeF32x4', 'table.CoreVectors.NormalizeF32x4 := @RISCVVNormalizeF32x4;');
  AssertRegisterHasAsmOwnedSlot('NormalizeF32x3', 'table.CoreVectors.NormalizeF32x3 := @RISCVVNormalizeF32x3;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertAsmConditionalNormalizeF32Slot('NormalizeF32x4', 'function RISCVVNormalizeF32x4(const a: TVecF32x4): TVecF32x4;',
    'RISCVVNormalizeF32x4Asm(a, Result);', 'procedure RISCVVNormalizeF32x4Asm(const a: TVecF32x4; var r: TVecF32x4);',
    'bnez t1, .lzero_norm4', 'vfdiv.vv v0, v0, v1',
    Pointer(LScalarTable.CoreVectors.NormalizeF32x4), Pointer(LRISCVVTable.CoreVectors.NormalizeF32x4));
  AssertAsmConditionalNormalizeF32Slot('NormalizeF32x3', 'function RISCVVNormalizeF32x3(const a: TVecF32x4): TVecF32x4;',
    'RISCVVNormalizeF32x3Asm(a, Result);', 'procedure RISCVVNormalizeF32x3Asm(const a: TVecF32x4; var r: TVecF32x4);',
    'bnez t1, .lzero_norm3', 'vslideup.vi v0, v1, 3',
    Pointer(LScalarTable.CoreVectors.NormalizeF32x3), Pointer(LRISCVVTable.CoreVectors.NormalizeF32x3));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_ReduceF64x2_Stays_BackendOwned_With_ExactScalarNoAsmWitness;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LAsmSourcePath: string;
  LRegisterSource: string;
  LFacadeSource: string;
  LAsmSource: string;

  function CountOccurrences(const aHaystack, aNeedle: string): Integer;
  var
    LRest: string;
    LPos: SizeInt;
  begin
    Result := 0;
    LRest := aHaystack;
    LPos := Pos(aNeedle, LRest);
    while LPos > 0 do
    begin
      Inc(Result);
      Delete(LRest, 1, LPos + Length(aNeedle) - 1);
      LPos := Pos(aNeedle, LRest);
    end;
  end;

  procedure AssertRegisterOwnsBackendSlot(const aLabel, aSnippet: string);
  var
    LNeedle: string;
  begin
    LNeedle := LowerCase(aSnippet);
    CheckEqual(1, CountOccurrences(LRegisterSource, LNeedle), 'RegisterRISCVVBackend should keep exactly one ' + aLabel + ' source assignment site');
    CheckTrue(Pos(LNeedle, LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a backend-owned assignment for ' + aLabel);
  end;

  procedure AssertExactReductionF64x2Slot(
    const aLabel, aScalarForwardSnippet, aFunctionSnippet, aSeedSnippet, aLoopSnippet, aCompareSnippet, aAsmSignatureSnippet, aAsmOpSnippet: string;
    const aScalarSlot, aBackendSlot: Pointer);
  var
    LFunctionNeedle: string;
    LFunctionStart: SizeInt;
    LRelativeEnd: SizeInt;
    LFunctionBlock: string;
  begin
    LFunctionNeedle := LowerCase(aFunctionSnippet);
    LFunctionStart := Pos(LFunctionNeedle, LFacadeSource);
    CheckTrue(LFunctionStart > 0, 'no-asm RISCVV facade should still define ' + aLabel + ' locally');
    LRelativeEnd := Pos(LineEnding + 'end;', Copy(LFacadeSource, LFunctionStart, MaxInt));
    CheckTrue(LRelativeEnd > 0, 'no-asm RISCVV facade should keep a closed function block for ' + aLabel);
    LFunctionBlock := Copy(LFacadeSource, LFunctionStart, LRelativeEnd + Length(LineEnding + 'end;') - 1);

    CheckTrue(Pos(LowerCase(aScalarForwardSnippet), LFunctionBlock) > 0, 'no-asm RISCVV facade should keep exact scalar forwarding for ' + aLabel);
    CheckTrue(Pos(LowerCase(aSeedSnippet), LFunctionBlock) = 0, 'no-asm RISCVV facade should not keep the old local reduction seed for ' + aLabel);
    CheckTrue(Pos(LowerCase(aLoopSnippet), LFunctionBlock) = 0, 'no-asm RISCVV facade should not keep the old explicit local reduction loop for ' + aLabel);
    CheckTrue(Pos(LowerCase(aCompareSnippet), LFunctionBlock) = 0, 'no-asm RISCVV facade should not keep the old local compare branch for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmSignatureSnippet), LAsmSource) > 0, 'RVV asm source should keep dedicated assembler entry for ' + aLabel);
    CheckTrue(Pos(LowerCase(aAsmOpSnippet), LAsmSource) > 0, 'RVV asm source should keep a dedicated reduction opcode for ' + aLabel);
    CheckTrue(aBackendSlot <> nil, 'RISCVV ' + aLabel + ' should stay assigned in the backend dispatch table');
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should stay backend-owned instead of reusing the scalar slot');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for exact reduction F64x2 witness audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for exact reduction F64x2 witness audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LAsmSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LAsmSourcePath), 'RISCVV unit source should exist for exact reduction F64x2 witness audit: ' + LAsmSourcePath);
    LSourceLines.LoadFromFile(LAsmSourcePath);
    LAsmSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertRegisterOwnsBackendSlot('ReduceMaxF64x2', 'table.CoreVectors.ReduceMaxF64x2 := @RISCVVReduceMaxF64x2;');
  AssertRegisterOwnsBackendSlot('ReduceMinF64x2', 'table.CoreVectors.ReduceMinF64x2 := @RISCVVReduceMinF64x2;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertExactReductionF64x2Slot('ReduceMaxF64x2', 'Result := ScalarReduceMaxF64x2(a);',
    'function RISCVVReduceMaxF64x2(const a: TVecF64x2): Double;', 'Result := a.d[0];',
    'for i := 1 to 1 do', 'if a.d[i] > Result then',
    'function RISCVVReduceMaxF64x2(const a: TVecF64x2): Double; assembler; nostackframe;', 'vfredmax.vs v1, v0, v0',
    Pointer(LScalarTable.CoreVectors.ReduceMaxF64x2), Pointer(LRISCVVTable.CoreVectors.ReduceMaxF64x2));
  AssertExactReductionF64x2Slot('ReduceMinF64x2', 'Result := ScalarReduceMinF64x2(a);',
    'function RISCVVReduceMinF64x2(const a: TVecF64x2): Double;', 'Result := a.d[0];',
    'for i := 1 to 1 do', 'if a.d[i] < Result then',
    'function RISCVVReduceMinF64x2(const a: TVecF64x2): Double; assembler; nostackframe;', 'vfredmin.vs v1, v0, v0',
    Pointer(LScalarTable.CoreVectors.ReduceMinF64x2), Pointer(LRISCVVTable.CoreVectors.ReduceMinF64x2));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_KeyOwnedWideSlots_Stay_BackendOwned;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LRegisterSourcePath: string;
  LRegisterSource: string;
  LSavedMask: TFPUExceptionMask;
  LF64x4A, LF64x4Min, LF64x4Max: TVecF64x4;
  LF64x4ByScalar, LF64x4ByRISCVV: TVecF64x4;
  LF64x8A, LF64x8Min, LF64x8Max: TVecF64x8;
  LF64x8ByScalar, LF64x8ByRISCVV: TVecF64x8;
  LIndex: Integer;

  procedure AssertRegisterOwnsBackendSlot(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a dedicated backend-owned assignment for ' + aLabel);
  end;

  procedure AssertSlotKeepsBackendOwnership(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, 'RISCVV ' + aLabel + ' should stay assigned in the backend dispatch table');
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should stay backend-owned instead of reusing the scalar slot');
  end;

  function LocalDoubleBits(const aValue: Double): QWord; inline;
  begin
    Move(aValue, Result, SizeOf(Result));
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertRegisterOwnsBackendSlot('AndI64x8', 'table.CoreVectors.AndI64x8 := @RISCVVAndI64x8;');
  AssertRegisterOwnsBackendSlot('NotI64x8', 'table.CoreVectors.NotI64x8 := @RISCVVNotI64x8;');
  AssertRegisterOwnsBackendSlot('ShiftLeftI32x16', 'table.CoreVectors.ShiftLeftI32x16 := @RISCVVShiftLeftI32x16;');
  AssertRegisterOwnsBackendSlot('ShiftRightArithI64x4', 'table.CoreVectors.ShiftRightArithI64x4 := @RISCVVShiftRightArithI64x4;');
  AssertRegisterOwnsBackendSlot('SubI32x8', 'table.CoreVectors.SubI32x8 := @RISCVVSubI32x8;');
  AssertRegisterOwnsBackendSlot('MinU32x8', 'table.CoreVectors.MinU32x8 := @RISCVVMinU32x8;');
  AssertRegisterOwnsBackendSlot('AddI64x4', 'table.CoreVectors.AddI64x4 := @RISCVVAddI64x4;');
  AssertRegisterOwnsBackendSlot('MulI32x16', 'table.CoreVectors.MulI32x16 := @RISCVVMulI32x16;');
  AssertRegisterOwnsBackendSlot('SubI64x8', 'table.CoreVectors.SubI64x8 := @RISCVVSubI64x8;');
  AssertRegisterOwnsBackendSlot('ClampF64x4', 'table.CoreVectors.ClampF64x4 := @RISCVVClampF64x4;');
  AssertRegisterOwnsBackendSlot('ClampF64x8', 'table.CoreVectors.ClampF64x8 := @RISCVVClampF64x8;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertSlotKeepsBackendOwnership('AndI64x8', Pointer(LScalarTable.CoreVectors.AndI64x8), Pointer(LRISCVVTable.CoreVectors.AndI64x8));
  AssertSlotKeepsBackendOwnership('NotI64x8', Pointer(LScalarTable.CoreVectors.NotI64x8), Pointer(LRISCVVTable.CoreVectors.NotI64x8));
  AssertSlotKeepsBackendOwnership('ShiftLeftI32x16', Pointer(LScalarTable.CoreVectors.ShiftLeftI32x16), Pointer(LRISCVVTable.CoreVectors.ShiftLeftI32x16));
  AssertSlotKeepsBackendOwnership('ShiftRightArithI64x4', Pointer(LScalarTable.CoreVectors.ShiftRightArithI64x4), Pointer(LRISCVVTable.CoreVectors.ShiftRightArithI64x4));
  AssertSlotKeepsBackendOwnership('SubI32x8', Pointer(LScalarTable.CoreVectors.SubI32x8), Pointer(LRISCVVTable.CoreVectors.SubI32x8));
  AssertSlotKeepsBackendOwnership('MinU32x8', Pointer(LScalarTable.CoreVectors.MinU32x8), Pointer(LRISCVVTable.CoreVectors.MinU32x8));
  AssertSlotKeepsBackendOwnership('AddI64x4', Pointer(LScalarTable.CoreVectors.AddI64x4), Pointer(LRISCVVTable.CoreVectors.AddI64x4));
  AssertSlotKeepsBackendOwnership('MulI32x16', Pointer(LScalarTable.CoreVectors.MulI32x16), Pointer(LRISCVVTable.CoreVectors.MulI32x16));
  AssertSlotKeepsBackendOwnership('SubI64x8', Pointer(LScalarTable.CoreVectors.SubI64x8), Pointer(LRISCVVTable.CoreVectors.SubI64x8));
  AssertSlotKeepsBackendOwnership('ClampF64x4', Pointer(LScalarTable.CoreVectors.ClampF64x4), Pointer(LRISCVVTable.CoreVectors.ClampF64x4));
  AssertSlotKeepsBackendOwnership('ClampF64x8', Pointer(LScalarTable.CoreVectors.ClampF64x8), Pointer(LRISCVVTable.CoreVectors.ClampF64x8));

  // RISCVV F64 clamp intentionally keeps the local NaN/signed-zero fallback
  // contract for now; do not silently collapse it to scalar semantics.
  for LIndex := 0 to 3 do
  begin
    LF64x4A.d[LIndex] := LIndex + 1.0;
    LF64x4Min.d[LIndex] := -10.0 + LIndex;
    LF64x4Max.d[LIndex] := 10.0 + LIndex;
  end;
  LF64x4A.d[0] := NaN;
  LF64x4A.d[1] := -0.0;
  LF64x4Min.d[0] := 0.0;
  LF64x4Min.d[1] := 0.0;
  LF64x4Max.d[0] := 10.0;
  LF64x4Max.d[1] := 0.0;

  for LIndex := 0 to 7 do
  begin
    LF64x8A.d[LIndex] := (LIndex - 2) * 1.5;
    LF64x8Min.d[LIndex] := -20.0 + LIndex;
    LF64x8Max.d[LIndex] := 20.0 + LIndex;
  end;
  LF64x8A.d[0] := NaN;
  LF64x8A.d[1] := -0.0;
  LF64x8Min.d[0] := 0.0;
  LF64x8Min.d[1] := 0.0;
  LF64x8Max.d[0] := 10.0;
  LF64x8Max.d[1] := 0.0;

  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    LF64x4ByScalar := LScalarTable.CoreVectors.ClampF64x4(LF64x4A, LF64x4Min, LF64x4Max);
    LF64x4ByRISCVV := LRISCVVTable.CoreVectors.ClampF64x4(LF64x4A, LF64x4Min, LF64x4Max);
    LF64x8ByScalar := LScalarTable.CoreVectors.ClampF64x8(LF64x8A, LF64x8Min, LF64x8Max);
    LF64x8ByRISCVV := LRISCVVTable.CoreVectors.ClampF64x8(LF64x8A, LF64x8Min, LF64x8Max);
  finally
    SetExceptionMask(LSavedMask);
  end;

  CheckTrue(LocalDoubleBits(LF64x4ByScalar.d[0]) = LocalDoubleBits(10.0), 'Scalar ClampF64x4 NaN witness should collapse to the max bound');
  CheckTrue(IsNaN(LF64x4ByRISCVV.d[0]), 'RISCVV ClampF64x4 NaN witness should keep the local NaN fallback');
  CheckTrue(LocalDoubleBits(LF64x4ByScalar.d[1]) = QWord($0000000000000000), 'Scalar ClampF64x4 signed-zero witness should normalize to +0');
  CheckTrue(LocalDoubleBits(LF64x4ByRISCVV.d[1]) = QWord($8000000000000000), 'RISCVV ClampF64x4 signed-zero witness should keep -0 local fallback');

  CheckTrue(LocalDoubleBits(LF64x8ByScalar.d[0]) = LocalDoubleBits(10.0), 'Scalar ClampF64x8 NaN witness should collapse to the max bound');
  CheckTrue(IsNaN(LF64x8ByRISCVV.d[0]), 'RISCVV ClampF64x8 NaN witness should keep the local NaN fallback');
  CheckTrue(LocalDoubleBits(LF64x8ByScalar.d[1]) = QWord($0000000000000000), 'Scalar ClampF64x8 signed-zero witness should normalize to +0');
  CheckTrue(LocalDoubleBits(LF64x8ByRISCVV.d[1]) = QWord($8000000000000000), 'RISCVV ClampF64x8 signed-zero witness should keep -0 local fallback');
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_AndNotSlots_Keep_AsmOwnedCompositions_And_Reuse_BaseScalar_When_NoAsm;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LUnitSourcePath: string;
  LHelpersSourcePath: string;
  LRegisterSourcePath: string;
  LUnitSource: string;
  LHelpersSource: string;
  LRegisterSource: string;

  procedure AssertWrapperStillPresent(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LUnitSource) > 0, 'RISCVV unit source should keep the asm-local AndNot composition for ' + aLabel);
  end;

  procedure AssertNoAsmHelperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LHelpersSource) = 0, 'RISCVV no-asm helpers should stop owning the exact scalar AndNot fallback for ' + aLabel);
  end;

  procedure AssertRegisterHasAsmOwnedSlot(const aLabel, aRegisterSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aRegisterSnippet), LRegisterSource) > 0, 'RegisterRISCVVBackend should keep the asm-gated binding source for ' + aLabel);
  end;

  procedure AssertRuntimeOwnership(
    const aLabel: string;
    const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, 'RISCVV ' + aLabel + ' should stay assigned in the backend dispatch table');
    {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should keep backend ownership when RVV asm is compiled');
    {$ELSE}
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the base scalar slot when RVV asm is not compiled on this host');
    {$ENDIF}
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LUnitSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LUnitSourcePath), 'RISCVV unit source should exist for implementation-shape audit: ' + LUnitSourcePath);
    LSourceLines.LoadFromFile(LUnitSourcePath);
    LUnitSource := LowerCase(LSourceLines.Text);

    LHelpersSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.helpers.inc');
    CheckTrue(FileExists(LHelpersSourcePath), 'RISCVV helper source should exist for implementation-shape audit: ' + LHelpersSourcePath);
    LSourceLines.LoadFromFile(LHelpersSourcePath);
    LHelpersSource := LowerCase(LSourceLines.Text);

    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertWrapperStillPresent('AndNotI8x16', 'Result := RISCVVAndI8x16(RISCVVNotI8x16(a), b);');
  AssertWrapperStillPresent('AndNotU16x8', 'Result := RISCVVAndU16x8(RISCVVNotU16x8(a), b);');
  AssertWrapperStillPresent('AndNotU8x16', 'Result := RISCVVAndU8x16(RISCVVNotU8x16(a), b);');

  AssertNoAsmHelperRemoved('AndNotI8x16', 'Result := ScalarAndNotI8x16(a, b);');
  AssertNoAsmHelperRemoved('AndNotU16x8', 'Result := ScalarAndNotU16x8(a, b);');
  AssertNoAsmHelperRemoved('AndNotU8x16', 'Result := ScalarAndNotU8x16(a, b);');

  AssertRegisterHasAsmOwnedSlot('AndNotI8x16', 'table.CoreVectors.AndNotI8x16 := @RISCVVAndNotI8x16;');
  AssertRegisterHasAsmOwnedSlot('AndNotU16x8', 'table.CoreVectors.AndNotU16x8 := @RISCVVAndNotU16x8;');
  AssertRegisterHasAsmOwnedSlot('AndNotU8x16', 'table.CoreVectors.AndNotU8x16 := @RISCVVAndNotU8x16;');

  AssertRuntimeOwnership('AndNotI8x16', Pointer(LScalarTable.CoreVectors.AndNotI8x16), Pointer(LRISCVVTable.CoreVectors.AndNotI8x16));
  AssertRuntimeOwnership('AndNotU16x8', Pointer(LScalarTable.CoreVectors.AndNotU16x8), Pointer(LRISCVVTable.CoreVectors.AndNotU16x8));
  AssertRuntimeOwnership('AndNotU8x16', Pointer(LScalarTable.CoreVectors.AndNotU8x16), Pointer(LRISCVVTable.CoreVectors.AndNotU8x16));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_ExtractSlots_Reuse_BaseScalar_When_NoAsmWrappers_Are_Dead;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LFacadeSourcePath: string;
  LAsmSourcePath: string;
  LRegisterSourcePath: string;
  LFacadeSource: string;
  LAsmSource: string;
  LRegisterSource: string;

  function CountRegisterAssignments(const aSnippet: string): Integer;
  var
    LNeedle: string;
    LRest: string;
    LPos: SizeInt;
  begin
    Result := 0;
    LNeedle := LowerCase(aSnippet);
    LRest := LRegisterSource;
    LPos := Pos(LNeedle, LRest);
    while LPos > 0 do
    begin
      Inc(Result);
      Delete(LRest, 1, LPos + Length(LNeedle) - 1);
      LPos := Pos(LNeedle, LRest);
    end;
  end;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LFacadeSource) = 0, 'RISCVV no-asm facade dead wrapper should be removed for ' + aLabel);
  end;

  procedure AssertAsmWrapperRetained(const aLabel, aAsmSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aAsmSnippet), LAsmSource) > 0, 'RISCVV asm source should keep dedicated helper-backed wrapper for ' + aLabel);
  end;

  procedure AssertRegisterHasAsmOwnedSlot(const aLabel, aRegisterSnippet: string);
  begin
    CheckEqual(1, CountRegisterAssignments(aRegisterSnippet), 'RegisterRISCVVBackend should keep exactly one asm-gated assignment site for ' + aLabel);
    CheckTrue(Pos(LowerCase(aRegisterSnippet), LRegisterSource) > 0, 'RegisterRISCVVBackend should keep a dedicated asm-gated source assignment for ' + aLabel);
  end;

  procedure AssertSlotMatchesRuntimeAvailability(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, 'RISCVV ' + aLabel + ' should stay assigned in the backend dispatch table');
    {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
    CheckTrue(PtrUInt(aScalarSlot) <> PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should keep a backend-owned runtime slot when RVV asm is compiled');
    {$ELSE}
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the base scalar slot when RVV asm is unavailable');
    {$ENDIF}
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for implementation-shape audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);

    LAsmSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LAsmSourcePath), 'RISCVV asm source should exist for implementation-shape audit: ' + LAsmSourcePath);
    LSourceLines.LoadFromFile(LAsmSourcePath);
    LAsmSource := LowerCase(LSourceLines.Text);

    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertDeadWrapperRemoved('ExtractF32x8', 'function RISCVVExtractF32x8(');
  AssertAsmWrapperRetained('ExtractF32x8', 'Result := RISCVVExtractF32x8Asm(a, LIndex);');
  AssertRegisterHasAsmOwnedSlot('ExtractF32x8', 'table.CoreVectors.ExtractF32x8 := @RISCVVExtractF32x8;');
  AssertSlotMatchesRuntimeAvailability('ExtractF32x8', Pointer(LScalarTable.CoreVectors.ExtractF32x8), Pointer(LRISCVVTable.CoreVectors.ExtractF32x8));

  AssertDeadWrapperRemoved('ExtractF32x16', 'function RISCVVExtractF32x16(');
  AssertAsmWrapperRetained('ExtractF32x16', 'Result := RISCVVExtractF32x16Asm(a, LIndex);');
  AssertRegisterHasAsmOwnedSlot('ExtractF32x16', 'table.CoreVectors.ExtractF32x16 := @RISCVVExtractF32x16;');
  AssertSlotMatchesRuntimeAvailability('ExtractF32x16', Pointer(LScalarTable.CoreVectors.ExtractF32x16), Pointer(LRISCVVTable.CoreVectors.ExtractF32x16));

  AssertDeadWrapperRemoved('ExtractF64x2', 'function RISCVVExtractF64x2(');
  AssertAsmWrapperRetained('ExtractF64x2', 'Result := RISCVVExtractF64x2Asm(a, LIndex);');
  AssertRegisterHasAsmOwnedSlot('ExtractF64x2', 'table.CoreVectors.ExtractF64x2 := @RISCVVExtractF64x2;');
  AssertSlotMatchesRuntimeAvailability('ExtractF64x2', Pointer(LScalarTable.CoreVectors.ExtractF64x2), Pointer(LRISCVVTable.CoreVectors.ExtractF64x2));

  AssertDeadWrapperRemoved('ExtractF64x4', 'function RISCVVExtractF64x4(');
  AssertAsmWrapperRetained('ExtractF64x4', 'Result := RISCVVExtractF64x4Asm(a, LIndex);');
  AssertRegisterHasAsmOwnedSlot('ExtractF64x4', 'table.CoreVectors.ExtractF64x4 := @RISCVVExtractF64x4;');
  AssertSlotMatchesRuntimeAvailability('ExtractF64x4', Pointer(LScalarTable.CoreVectors.ExtractF64x4), Pointer(LRISCVVTable.CoreVectors.ExtractF64x4));

  AssertDeadWrapperRemoved('ExtractI32x4', 'function RISCVVExtractI32x4(');
  AssertAsmWrapperRetained('ExtractI32x4', 'Result := RISCVVExtractI32x4Asm(a, LIndex);');
  AssertRegisterHasAsmOwnedSlot('ExtractI32x4', 'table.CoreVectors.ExtractI32x4 := @RISCVVExtractI32x4;');
  AssertSlotMatchesRuntimeAvailability('ExtractI32x4', Pointer(LScalarTable.CoreVectors.ExtractI32x4), Pointer(LRISCVVTable.CoreVectors.ExtractI32x4));

  AssertDeadWrapperRemoved('ExtractI32x8', 'function RISCVVExtractI32x8(');
  AssertAsmWrapperRetained('ExtractI32x8', 'Result := RISCVVExtractI32x8Asm(a, LIndex);');
  AssertRegisterHasAsmOwnedSlot('ExtractI32x8', 'table.CoreVectors.ExtractI32x8 := @RISCVVExtractI32x8;');
  AssertSlotMatchesRuntimeAvailability('ExtractI32x8', Pointer(LScalarTable.CoreVectors.ExtractI32x8), Pointer(LRISCVVTable.CoreVectors.ExtractI32x8));

  AssertDeadWrapperRemoved('ExtractI32x16', 'function RISCVVExtractI32x16(');
  AssertAsmWrapperRetained('ExtractI32x16', 'Result := RISCVVExtractI32x16Asm(a, LIndex);');
  AssertRegisterHasAsmOwnedSlot('ExtractI32x16', 'table.CoreVectors.ExtractI32x16 := @RISCVVExtractI32x16;');
  AssertSlotMatchesRuntimeAvailability('ExtractI32x16', Pointer(LScalarTable.CoreVectors.ExtractI32x16), Pointer(LRISCVVTable.CoreVectors.ExtractI32x16));

  AssertDeadWrapperRemoved('ExtractI64x2', 'function RISCVVExtractI64x2(');
  AssertAsmWrapperRetained('ExtractI64x2', 'Result := RISCVVExtractI64x2Asm(a, LIndex);');
  AssertRegisterHasAsmOwnedSlot('ExtractI64x2', 'table.CoreVectors.ExtractI64x2 := @RISCVVExtractI64x2;');
  AssertSlotMatchesRuntimeAvailability('ExtractI64x2', Pointer(LScalarTable.CoreVectors.ExtractI64x2), Pointer(LRISCVVTable.CoreVectors.ExtractI64x2));

  AssertDeadWrapperRemoved('ExtractI64x4', 'function RISCVVExtractI64x4(');
  AssertAsmWrapperRetained('ExtractI64x4', 'Result := RISCVVExtractI64x4Asm(a, LIndex);');
  AssertRegisterHasAsmOwnedSlot('ExtractI64x4', 'table.CoreVectors.ExtractI64x4 := @RISCVVExtractI64x4;');
  AssertSlotMatchesRuntimeAvailability('ExtractI64x4', Pointer(LScalarTable.CoreVectors.ExtractI64x4), Pointer(LRISCVVTable.CoreVectors.ExtractI64x4));
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_WideRoundingAndF32ClampSlots_Reuse_BaseScalar_When_ScalarForwarders_Are_Dead;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LSourceLines: TSourceLines;
  LUnitSourcePath: string;
  LRegisterSourcePath: string;
  LFacadeSourcePath: string;
  LUnitSource: string;
  LRegisterSource: string;
  LFacadeSource: string;

  procedure AssertDeadWrapperRemoved(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LUnitSource) = 0, 'RISCVV unit source should no longer publish a dead scalar-forward wrapper for ' + aLabel);
    CheckTrue(Pos(LowerCase(aSnippet), LFacadeSource) = 0, 'RISCVV facade include should no longer publish a dead scalar-forward wrapper for ' + aLabel);
  end;

  procedure AssertRegisterKeepsBaseScalar(const aLabel, aSnippet: string);
  begin
    CheckTrue(Pos(LowerCase(aSnippet), LRegisterSource) = 0, 'RegisterRISCVVBackend should keep the base scalar slot for ' + aLabel + ' when the RISCVV-specific wrapper is fully dead');
  end;

  procedure AssertSlotReusesScalar(const aLabel: string; const aScalarSlot, aBackendSlot: Pointer);
  begin
    CheckTrue(aBackendSlot <> nil, 'RISCVV ' + aLabel + ' should stay assigned in the backend dispatch table');
    CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), 'RISCVV ' + aLabel + ' should reuse the canonical base scalar slot when the RISCVV-specific wrapper is fully dead');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LUnitSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.pas');
    CheckTrue(FileExists(LUnitSourcePath), 'RISCVV unit source should exist for implementation-shape audit: ' + LUnitSourcePath);
    LSourceLines.LoadFromFile(LUnitSourcePath);
    LUnitSource := LowerCase(LSourceLines.Text);

    LRegisterSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    CheckTrue(FileExists(LRegisterSourcePath), 'RISCVV register source should exist for implementation-shape audit: ' + LRegisterSourcePath);
    LSourceLines.LoadFromFile(LRegisterSourcePath);
    LRegisterSource := LowerCase(LSourceLines.Text);

    LFacadeSourcePath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.facade.inc');
    CheckTrue(FileExists(LFacadeSourcePath), 'RISCVV facade source should exist for implementation-shape audit: ' + LFacadeSourcePath);
    LSourceLines.LoadFromFile(LFacadeSourcePath);
    LFacadeSource := LowerCase(LSourceLines.Text);
  finally
    LSourceLines.Free;
  end;

  AssertDeadWrapperRemoved('CeilF32x8', 'function RISCVVCeilF32x8(');
  AssertDeadWrapperRemoved('CeilF64x4', 'function RISCVVCeilF64x4(');
  AssertDeadWrapperRemoved('CeilF32x16', 'function RISCVVCeilF32x16(');
  AssertDeadWrapperRemoved('CeilF64x8', 'function RISCVVCeilF64x8(');
  AssertDeadWrapperRemoved('FloorF32x8', 'function RISCVVFloorF32x8(');
  AssertDeadWrapperRemoved('FloorF64x4', 'function RISCVVFloorF64x4(');
  AssertDeadWrapperRemoved('FloorF32x16', 'function RISCVVFloorF32x16(');
  AssertDeadWrapperRemoved('FloorF64x8', 'function RISCVVFloorF64x8(');
  AssertDeadWrapperRemoved('RoundF32x8', 'function RISCVVRoundF32x8(');
  AssertDeadWrapperRemoved('RoundF64x4', 'function RISCVVRoundF64x4(');
  AssertDeadWrapperRemoved('RoundF32x16', 'function RISCVVRoundF32x16(');
  AssertDeadWrapperRemoved('RoundF64x8', 'function RISCVVRoundF64x8(');
  AssertDeadWrapperRemoved('TruncF32x8', 'function RISCVVTruncF32x8(');
  AssertDeadWrapperRemoved('TruncF64x4', 'function RISCVVTruncF64x4(');
  AssertDeadWrapperRemoved('TruncF32x16', 'function RISCVVTruncF32x16(');
  AssertDeadWrapperRemoved('TruncF64x8', 'function RISCVVTruncF64x8(');
  AssertDeadWrapperRemoved('ClampF32x8', 'function RISCVVClampF32x8(');
  AssertDeadWrapperRemoved('ClampF32x16', 'function RISCVVClampF32x16(');

  AssertRegisterKeepsBaseScalar('CeilF32x8', 'table.CoreVectors.CeilF32x8 := @RISCVVCeilF32x8;');
  AssertRegisterKeepsBaseScalar('CeilF64x4', 'table.CoreVectors.CeilF64x4 := @RISCVVCeilF64x4;');
  AssertRegisterKeepsBaseScalar('CeilF32x16', 'table.CoreVectors.CeilF32x16 := @RISCVVCeilF32x16;');
  AssertRegisterKeepsBaseScalar('CeilF64x8', 'table.CoreVectors.CeilF64x8 := @RISCVVCeilF64x8;');
  AssertRegisterKeepsBaseScalar('FloorF32x8', 'table.CoreVectors.FloorF32x8 := @RISCVVFloorF32x8;');
  AssertRegisterKeepsBaseScalar('FloorF64x4', 'table.CoreVectors.FloorF64x4 := @RISCVVFloorF64x4;');
  AssertRegisterKeepsBaseScalar('FloorF32x16', 'table.CoreVectors.FloorF32x16 := @RISCVVFloorF32x16;');
  AssertRegisterKeepsBaseScalar('FloorF64x8', 'table.CoreVectors.FloorF64x8 := @RISCVVFloorF64x8;');
  AssertRegisterKeepsBaseScalar('RoundF32x8', 'table.CoreVectors.RoundF32x8 := @RISCVVRoundF32x8;');
  AssertRegisterKeepsBaseScalar('RoundF64x4', 'table.CoreVectors.RoundF64x4 := @RISCVVRoundF64x4;');
  AssertRegisterKeepsBaseScalar('RoundF32x16', 'table.CoreVectors.RoundF32x16 := @RISCVVRoundF32x16;');
  AssertRegisterKeepsBaseScalar('RoundF64x8', 'table.CoreVectors.RoundF64x8 := @RISCVVRoundF64x8;');
  AssertRegisterKeepsBaseScalar('TruncF32x8', 'table.CoreVectors.TruncF32x8 := @RISCVVTruncF32x8;');
  AssertRegisterKeepsBaseScalar('TruncF64x4', 'table.CoreVectors.TruncF64x4 := @RISCVVTruncF64x4;');
  AssertRegisterKeepsBaseScalar('TruncF32x16', 'table.CoreVectors.TruncF32x16 := @RISCVVTruncF32x16;');
  AssertRegisterKeepsBaseScalar('TruncF64x8', 'table.CoreVectors.TruncF64x8 := @RISCVVTruncF64x8;');
  AssertRegisterKeepsBaseScalar('ClampF32x8', 'table.CoreVectors.ClampF32x8 := @RISCVVClampF32x8;');
  AssertRegisterKeepsBaseScalar('ClampF32x16', 'table.CoreVectors.ClampF32x16 := @RISCVVClampF32x16;');

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present for wide rounding/clamp source audit');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  AssertSlotReusesScalar('CeilF32x8', Pointer(LScalarTable.CoreVectors.CeilF32x8), Pointer(LRISCVVTable.CoreVectors.CeilF32x8));
  AssertSlotReusesScalar('CeilF64x4', Pointer(LScalarTable.CoreVectors.CeilF64x4), Pointer(LRISCVVTable.CoreVectors.CeilF64x4));
  AssertSlotReusesScalar('CeilF32x16', Pointer(LScalarTable.CoreVectors.CeilF32x16), Pointer(LRISCVVTable.CoreVectors.CeilF32x16));
  AssertSlotReusesScalar('CeilF64x8', Pointer(LScalarTable.CoreVectors.CeilF64x8), Pointer(LRISCVVTable.CoreVectors.CeilF64x8));
  AssertSlotReusesScalar('FloorF32x8', Pointer(LScalarTable.CoreVectors.FloorF32x8), Pointer(LRISCVVTable.CoreVectors.FloorF32x8));
  AssertSlotReusesScalar('FloorF64x4', Pointer(LScalarTable.CoreVectors.FloorF64x4), Pointer(LRISCVVTable.CoreVectors.FloorF64x4));
  AssertSlotReusesScalar('FloorF32x16', Pointer(LScalarTable.CoreVectors.FloorF32x16), Pointer(LRISCVVTable.CoreVectors.FloorF32x16));
  AssertSlotReusesScalar('FloorF64x8', Pointer(LScalarTable.CoreVectors.FloorF64x8), Pointer(LRISCVVTable.CoreVectors.FloorF64x8));
  AssertSlotReusesScalar('RoundF32x8', Pointer(LScalarTable.CoreVectors.RoundF32x8), Pointer(LRISCVVTable.CoreVectors.RoundF32x8));
  AssertSlotReusesScalar('RoundF64x4', Pointer(LScalarTable.CoreVectors.RoundF64x4), Pointer(LRISCVVTable.CoreVectors.RoundF64x4));
  AssertSlotReusesScalar('RoundF32x16', Pointer(LScalarTable.CoreVectors.RoundF32x16), Pointer(LRISCVVTable.CoreVectors.RoundF32x16));
  AssertSlotReusesScalar('RoundF64x8', Pointer(LScalarTable.CoreVectors.RoundF64x8), Pointer(LRISCVVTable.CoreVectors.RoundF64x8));
  AssertSlotReusesScalar('TruncF32x8', Pointer(LScalarTable.CoreVectors.TruncF32x8), Pointer(LRISCVVTable.CoreVectors.TruncF32x8));
  AssertSlotReusesScalar('TruncF64x4', Pointer(LScalarTable.CoreVectors.TruncF64x4), Pointer(LRISCVVTable.CoreVectors.TruncF64x4));
  AssertSlotReusesScalar('TruncF32x16', Pointer(LScalarTable.CoreVectors.TruncF32x16), Pointer(LRISCVVTable.CoreVectors.TruncF32x16));
  AssertSlotReusesScalar('TruncF64x8', Pointer(LScalarTable.CoreVectors.TruncF64x8), Pointer(LRISCVVTable.CoreVectors.TruncF64x8));
  AssertSlotReusesScalar('ClampF32x8', Pointer(LScalarTable.CoreVectors.ClampF32x8), Pointer(LRISCVVTable.CoreVectors.ClampF32x8));
  AssertSlotReusesScalar('ClampF32x16', Pointer(LScalarTable.CoreVectors.ClampF32x16), Pointer(LRISCVVTable.CoreVectors.ClampF32x16));
end;

procedure TTestCase_DispatchAPI.Test_NEON_BackendCapabilities_Expose_Shuffle_When_RepresentativeSlots_AreNonScalar;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  CheckTrue(Assigned(LNEONTable.CoreVectors.SelectF32x4), 'NEON SelectF32x4 should be assigned');
  CheckTrue(Assigned(LNEONTable.CoreVectors.InsertF32x4), 'NEON InsertF32x4 should be assigned');
  CheckTrue(Assigned(LNEONTable.CoreVectors.ExtractF32x4), 'NEON ExtractF32x4 should be assigned');

  if (Pointer(LNEONTable.CoreVectors.SelectF32x4) = Pointer(LScalarTable.CoreVectors.SelectF32x4)) and
     (Pointer(LNEONTable.CoreVectors.InsertF32x4) = Pointer(LScalarTable.CoreVectors.InsertF32x4)) and
     (Pointer(LNEONTable.CoreVectors.ExtractF32x4) = Pointer(LScalarTable.CoreVectors.ExtractF32x4)) and
     (Pointer(LNEONTable.CoreVectors.SelectF32x8) = Pointer(LScalarTable.CoreVectors.SelectF32x8)) and
     (Pointer(LNEONTable.CoreVectors.SelectF64x4) = Pointer(LScalarTable.CoreVectors.SelectF64x4)) then
    Exit;

  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  CheckTrue(scShuffle in LNEONTable.BackendInfo.Capabilities, 'NEON should advertise scShuffle when NEON asm-backed representative shuffle slots are non-scalar');
  {$ELSE}
  CheckFalse(scShuffle in LNEONTable.BackendInfo.Capabilities, 'NEON should not advertise scShuffle when only scalar fallback shuffle slots are compiled');
  {$ENDIF}
end;

procedure TTestCase_DispatchAPI.Test_NEON_BackendCapabilities_Expose_FMA_When_FmaSlots_AreNative;
var
  LNEONTable: TSimdDispatchTable;
begin
  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  CheckTrue(Assigned(LNEONTable.CoreVectors.FmaF32x4), 'NEON FmaF32x4 should be assigned');
  CheckTrue(Assigned(LNEONTable.CoreVectors.FmaF32x8), 'NEON FmaF32x8 should be assigned');
  CheckTrue(Assigned(LNEONTable.CoreVectors.FmaF64x2), 'NEON FmaF64x2 should be assigned');
  CheckTrue(Assigned(LNEONTable.CoreVectors.FmaF64x4), 'NEON FmaF64x4 should be assigned');

  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  CheckTrue(scFMA in LNEONTable.BackendInfo.Capabilities, 'NEON should advertise scFMA when NEON asm-backed FMA slots are compiled');
  {$ELSE}
  CheckFalse(scFMA in LNEONTable.BackendInfo.Capabilities, 'NEON should not advertise scFMA when only scalar/common fallback FMA slots are compiled');
  {$ENDIF}
end;

procedure TTestCase_DispatchAPI.Test_NEON_BackendCapabilities_Expose_IntegerOps_When_IntegerSlots_AreNative;
var
  LNEONTable: TSimdDispatchTable;
begin
  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  {$ENDIF}

  CheckTrue(Assigned(LNEONTable.CoreVectors.AddI32x4), 'NEON AddI32x4 should be assigned');
  CheckTrue(Assigned(LNEONTable.CoreVectors.AndI32x4), 'NEON AndI32x4 should be assigned');
  CheckTrue(Assigned(LNEONTable.CoreVectors.AddI16x8), 'NEON AddI16x8 should be assigned');

  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  CheckTrue(scIntegerOps in LNEONTable.BackendInfo.Capabilities, 'NEON should advertise scIntegerOps when NEON asm-backed integer slots are compiled');
  {$ELSE}
  CheckFalse(scIntegerOps in LNEONTable.BackendInfo.Capabilities, 'NEON should not advertise scIntegerOps when only scalar/common fallback integer slots are compiled');
  {$ENDIF}
end;

procedure TTestCase_DispatchAPI.Test_NEON_BackendCapabilities_Clear_VectorAsmGatedBits_When_VectorAsmDisabled;
var
  LExpectedBaseTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
begin
  {$IFNDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  Exit;
  {$ENDIF}

  FillBaseDispatchTable(LExpectedBaseTable);
  CheckTrue(Assigned(LExpectedBaseTable.CoreVectors.FmaF32x4), 'Base fallback FmaF32x4 should be assigned');
  CheckTrue(Assigned(LExpectedBaseTable.CoreVectors.SelectF32x4), 'Base fallback SelectF32x4 should be assigned');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  SetVectorAsmEnabled(False);
  CheckFalse(IsVectorAsmEnabled, 'Vector asm should be disabled for NEON capability rebuild test');
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable), 'NEON backend should remain registered after runtime rebuild');

  CheckEqual(PtrUInt(LExpectedBaseTable.CoreVectors.FmaF32x4), PtrUInt(LNEONTable.CoreVectors.FmaF32x4), 'NEON FmaF32x4 should fall back to the base scalar table when vector asm is disabled');
  CheckEqual(PtrUInt(LExpectedBaseTable.CoreVectors.SelectF32x4), PtrUInt(LNEONTable.CoreVectors.SelectF32x4), 'NEON SelectF32x4 should fall back to the base scalar table when vector asm is disabled');
  CheckEqual(PtrUInt(LExpectedBaseTable.CoreVectors.InsertF32x4), PtrUInt(LNEONTable.CoreVectors.InsertF32x4), 'NEON InsertF32x4 should fall back to the base scalar table when vector asm is disabled');
  CheckEqual(PtrUInt(LExpectedBaseTable.CoreVectors.ExtractF32x4), PtrUInt(LNEONTable.CoreVectors.ExtractF32x4), 'NEON ExtractF32x4 should fall back to the base scalar table when vector asm is disabled');

  CheckFalse(scFMA in LNEONTable.BackendInfo.Capabilities, 'NEON scFMA should clear when vector asm is disabled');
  CheckFalse(scIntegerOps in LNEONTable.BackendInfo.Capabilities, 'NEON scIntegerOps should clear when vector asm is disabled');
  CheckFalse(scShuffle in LNEONTable.BackendInfo.Capabilities, 'NEON scShuffle should clear when vector asm is disabled');
  // SharedMask ownership is not vector-asm gated; keep scMaskedOps and non-scalar Mask slots.
  CheckTrue(scMaskedOps in LNEONTable.BackendInfo.Capabilities, 'NEON scMaskedOps should remain when SharedMask slots stay owned after vector asm disable');
  CheckTrue(PtrUInt(LNEONTable.Mask.Mask2All) <> PtrUInt(LExpectedBaseTable.Mask.Mask2All), 'NEON Mask2All should keep SharedMask ownership when vector asm is disabled');
  CheckTrue(PtrUInt(LNEONTable.Mask.Mask16FirstSet) <> PtrUInt(LExpectedBaseTable.Mask.Mask16FirstSet), 'NEON Mask16FirstSet should keep SharedMask ownership when vector asm is disabled');
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_BackendCapabilities_Expose_IntegerOps_When_IntegerSlots_AreNative;
var
  LRISCVVTable: TSimdDispatchTable;
begin
  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  CheckTrue(Assigned(LRISCVVTable.CoreVectors.AddI32x4), 'RISCVV AddI32x4 should be assigned');
  CheckTrue(Assigned(LRISCVVTable.CoreVectors.AndI32x4), 'RISCVV AndI32x4 should be assigned');
  CheckTrue(Assigned(LRISCVVTable.CoreVectors.AddI64x2), 'RISCVV AddI64x2 should be assigned');

  {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
  CheckTrue(scIntegerOps in LRISCVVTable.BackendInfo.Capabilities, 'RISCVV should advertise scIntegerOps when RVV asm-backed integer slots are compiled');
  {$ELSE}
  CheckFalse(scIntegerOps in LRISCVVTable.BackendInfo.Capabilities, 'RISCVV should not advertise scIntegerOps when only scalar/common fallback integer slots are compiled');
  {$ENDIF}
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_BackendCapabilities_Expose_FMA_When_FmaSlots_AreNonScalar;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  CheckTrue(Assigned(LRISCVVTable.CoreVectors.FmaF32x4), 'RISCVV FmaF32x4 should be assigned');
  CheckTrue(Assigned(LRISCVVTable.CoreVectors.FmaF32x8), 'RISCVV FmaF32x8 should be assigned');
  CheckTrue(Assigned(LRISCVVTable.CoreVectors.FmaF64x4), 'RISCVV FmaF64x4 should be assigned');

  if (Pointer(LRISCVVTable.CoreVectors.FmaF32x4) = Pointer(LScalarTable.CoreVectors.FmaF32x4)) and
     (Pointer(LRISCVVTable.CoreVectors.FmaF32x8) = Pointer(LScalarTable.CoreVectors.FmaF32x8)) and
     (Pointer(LRISCVVTable.CoreVectors.FmaF64x2) = Pointer(LScalarTable.CoreVectors.FmaF64x2)) and
     (Pointer(LRISCVVTable.CoreVectors.FmaF64x4) = Pointer(LScalarTable.CoreVectors.FmaF64x4)) and
     (Pointer(LRISCVVTable.CoreVectors.FmaF32x16) = Pointer(LScalarTable.CoreVectors.FmaF32x16)) and
     (Pointer(LRISCVVTable.CoreVectors.FmaF64x8) = Pointer(LScalarTable.CoreVectors.FmaF64x8)) then
    Exit;

  {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
  CheckTrue(scFMA in LRISCVVTable.BackendInfo.Capabilities, 'RISCVV should advertise scFMA when RVV asm-backed representative FMA slots are non-scalar');
  {$ELSE}
  CheckFalse(scFMA in LRISCVVTable.BackendInfo.Capabilities, 'RISCVV should not advertise scFMA when only scalar fallback FMA slots are compiled');
  {$ENDIF}
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_BackendCapabilities_Expose_Shuffle_When_RepresentativeSlots_AreNonScalar;
var
  LRISCVVTable: TSimdDispatchTable;
begin
  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  {$ENDIF}

  CheckTrue(Assigned(LRISCVVTable.CoreVectors.SelectF32x4), 'RISCVV SelectF32x4 should be assigned');
  CheckTrue(Assigned(LRISCVVTable.CoreVectors.InsertF32x4), 'RISCVV InsertF32x4 should be assigned');
  CheckTrue(Assigned(LRISCVVTable.CoreVectors.ExtractF32x4), 'RISCVV ExtractF32x4 should be assigned');

  {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
  CheckTrue(scShuffle in LRISCVVTable.BackendInfo.Capabilities, 'RISCVV should advertise scShuffle when RVV asm-backed representative shuffle slots are compiled');
  {$ELSE}
  CheckFalse(scShuffle in LRISCVVTable.BackendInfo.Capabilities, 'RISCVV should not advertise scShuffle when only scalar/common fallback shuffle slots are compiled');
  {$ENDIF}
end;

procedure TTestCase_DispatchAPI.Test_RISCVV_BackendCapabilities_Clear_VectorAsmGatedBits_When_VectorAsmDisabled;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
begin
  {$IFNDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
  Exit;
  {$ENDIF}

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  SetVectorAsmEnabled(False);
  CheckFalse(IsVectorAsmEnabled, 'Vector asm should be disabled for RISCVV capability rebuild test');
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV backend should remain registered after runtime rebuild');

  CheckEqual(PtrUInt(LScalarTable.CoreVectors.FmaF32x4), PtrUInt(LRISCVVTable.CoreVectors.FmaF32x4), 'RISCVV FmaF32x4 should fall back to scalar when vector asm is disabled');
  CheckEqual(PtrUInt(LScalarTable.CoreVectors.SelectF32x4), PtrUInt(LRISCVVTable.CoreVectors.SelectF32x4), 'RISCVV SelectF32x4 should fall back to scalar when vector asm is disabled');
  CheckEqual(PtrUInt(LScalarTable.CoreVectors.InsertF32x4), PtrUInt(LRISCVVTable.CoreVectors.InsertF32x4), 'RISCVV InsertF32x4 should fall back to scalar when vector asm is disabled');
  CheckEqual(PtrUInt(LScalarTable.CoreVectors.ExtractF32x4), PtrUInt(LRISCVVTable.CoreVectors.ExtractF32x4), 'RISCVV ExtractF32x4 should fall back to scalar when vector asm is disabled');

  CheckFalse(scFMA in LRISCVVTable.BackendInfo.Capabilities, 'RISCVV scFMA should clear when vector asm is disabled');
  CheckFalse(scIntegerOps in LRISCVVTable.BackendInfo.Capabilities, 'RISCVV scIntegerOps should clear when vector asm is disabled');
  CheckFalse(scShuffle in LRISCVVTable.BackendInfo.Capabilities, 'RISCVV scShuffle should clear when vector asm is disabled');
end;

procedure TTestCase_DispatchAPI.Test_NonX86_DispatchTable_WiringChecklist_Grouped;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LTable: TSimdDispatchTable;
  LRegisteredCount: Integer;
begin
  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LRegisteredCount := 0;

  for LBackend in LBackends do
  begin
    if not TryGetRegisteredBackendDispatchTable(LBackend, LTable) then
      Continue;

    Inc(LRegisteredCount);
    AssertNonX86DispatchTableWiringGroupsAssigned(Self, DispatchApiBackendName(LBackend), LTable);
  end;

  if LRegisteredCount = 0 then
    CheckTrue(True, 'No non-x86 backend registered on this host (allowed)');
end;

procedure TTestCase_DispatchAPI.Test_X86_DispatchTable_WiringChecklist_Grouped;
var
  LBackends: array[0..2] of TSimdBackend;
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
  LRegisteredCount := 0;

  for LBackend in LBackends do
  begin
    if not TryGetRegisteredBackendDispatchTable(LBackend, LTable) then
      Continue;

    Inc(LRegisteredCount);

    AssertAssigned(DispatchApiBackendName(LBackend), 'AndNotI64x2', Pointer(LTable.CoreVectors.AndNotI64x2));
    AssertAssigned(DispatchApiBackendName(LBackend), 'ShiftLeftI64x2', Pointer(LTable.CoreVectors.ShiftLeftI64x2));
    AssertAssigned(DispatchApiBackendName(LBackend), 'ShiftRightI64x2', Pointer(LTable.CoreVectors.ShiftRightI64x2));
    AssertAssigned(DispatchApiBackendName(LBackend), 'ShiftRightArithI64x2', Pointer(LTable.CoreVectors.ShiftRightArithI64x2));
    AssertAssigned(DispatchApiBackendName(LBackend), 'MinI64x2', Pointer(LTable.CoreVectors.MinI64x2));
    AssertAssigned(DispatchApiBackendName(LBackend), 'MaxI64x2', Pointer(LTable.CoreVectors.MaxI64x2));

    AssertAssigned(DispatchApiBackendName(LBackend), 'AddU64x2', Pointer(LTable.CoreVectors.AddU64x2));
    AssertAssigned(DispatchApiBackendName(LBackend), 'SubU64x2', Pointer(LTable.CoreVectors.SubU64x2));
    AssertAssigned(DispatchApiBackendName(LBackend), 'AndU64x2', Pointer(LTable.CoreVectors.AndU64x2));
    AssertAssigned(DispatchApiBackendName(LBackend), 'OrU64x2', Pointer(LTable.CoreVectors.OrU64x2));
    AssertAssigned(DispatchApiBackendName(LBackend), 'XorU64x2', Pointer(LTable.CoreVectors.XorU64x2));
    AssertAssigned(DispatchApiBackendName(LBackend), 'NotU64x2', Pointer(LTable.CoreVectors.NotU64x2));
    AssertAssigned(DispatchApiBackendName(LBackend), 'AndNotU64x2', Pointer(LTable.CoreVectors.AndNotU64x2));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpEqU64x2', Pointer(LTable.CoreVectors.CmpEqU64x2));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpLtU64x2', Pointer(LTable.CoreVectors.CmpLtU64x2));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpGtU64x2', Pointer(LTable.CoreVectors.CmpGtU64x2));
    AssertAssigned(DispatchApiBackendName(LBackend), 'MinU64x2', Pointer(LTable.CoreVectors.MinU64x2));
    AssertAssigned(DispatchApiBackendName(LBackend), 'MaxU64x2', Pointer(LTable.CoreVectors.MaxU64x2));

    AssertAssigned(DispatchApiBackendName(LBackend), 'AddI64x4', Pointer(LTable.CoreVectors.AddI64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'SubI64x4', Pointer(LTable.CoreVectors.SubI64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'AndI64x4', Pointer(LTable.CoreVectors.AndI64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'OrI64x4', Pointer(LTable.CoreVectors.OrI64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'XorI64x4', Pointer(LTable.CoreVectors.XorI64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'NotI64x4', Pointer(LTable.CoreVectors.NotI64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'AndNotI64x4', Pointer(LTable.CoreVectors.AndNotI64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'ShiftLeftI64x4', Pointer(LTable.CoreVectors.ShiftLeftI64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'ShiftRightI64x4', Pointer(LTable.CoreVectors.ShiftRightI64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'ShiftRightArithI64x4', Pointer(LTable.CoreVectors.ShiftRightArithI64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpEqI64x4', Pointer(LTable.CoreVectors.CmpEqI64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpLtI64x4', Pointer(LTable.CoreVectors.CmpLtI64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpGtI64x4', Pointer(LTable.CoreVectors.CmpGtI64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpLeI64x4', Pointer(LTable.CoreVectors.CmpLeI64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpGeI64x4', Pointer(LTable.CoreVectors.CmpGeI64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpNeI64x4', Pointer(LTable.CoreVectors.CmpNeI64x4));

    AssertAssigned(DispatchApiBackendName(LBackend), 'AddU64x4', Pointer(LTable.CoreVectors.AddU64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'SubU64x4', Pointer(LTable.CoreVectors.SubU64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'AndU64x4', Pointer(LTable.CoreVectors.AndU64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'OrU64x4', Pointer(LTable.CoreVectors.OrU64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'XorU64x4', Pointer(LTable.CoreVectors.XorU64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'NotU64x4', Pointer(LTable.CoreVectors.NotU64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'ShiftLeftU64x4', Pointer(LTable.CoreVectors.ShiftLeftU64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'ShiftRightU64x4', Pointer(LTable.CoreVectors.ShiftRightU64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpEqU64x4', Pointer(LTable.CoreVectors.CmpEqU64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpLtU64x4', Pointer(LTable.CoreVectors.CmpLtU64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpGtU64x4', Pointer(LTable.CoreVectors.CmpGtU64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpLeU64x4', Pointer(LTable.CoreVectors.CmpLeU64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpGeU64x4', Pointer(LTable.CoreVectors.CmpGeU64x4));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpNeU64x4', Pointer(LTable.CoreVectors.CmpNeU64x4));

    AssertAssigned(DispatchApiBackendName(LBackend), 'AddI64x8', Pointer(LTable.CoreVectors.AddI64x8));
    AssertAssigned(DispatchApiBackendName(LBackend), 'SubI64x8', Pointer(LTable.CoreVectors.SubI64x8));
    AssertAssigned(DispatchApiBackendName(LBackend), 'AndI64x8', Pointer(LTable.CoreVectors.AndI64x8));
    AssertAssigned(DispatchApiBackendName(LBackend), 'OrI64x8', Pointer(LTable.CoreVectors.OrI64x8));
    AssertAssigned(DispatchApiBackendName(LBackend), 'XorI64x8', Pointer(LTable.CoreVectors.XorI64x8));
    AssertAssigned(DispatchApiBackendName(LBackend), 'NotI64x8', Pointer(LTable.CoreVectors.NotI64x8));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpEqI64x8', Pointer(LTable.CoreVectors.CmpEqI64x8));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpLtI64x8', Pointer(LTable.CoreVectors.CmpLtI64x8));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpGtI64x8', Pointer(LTable.CoreVectors.CmpGtI64x8));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpLeI64x8', Pointer(LTable.CoreVectors.CmpLeI64x8));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpGeI64x8', Pointer(LTable.CoreVectors.CmpGeI64x8));
    AssertAssigned(DispatchApiBackendName(LBackend), 'CmpNeI64x8', Pointer(LTable.CoreVectors.CmpNeI64x8));
  end;

  if LRegisteredCount = 0 then
    CheckTrue(True, 'No x86 backend registered on this host (allowed)');
end;

procedure TTestCase_DispatchAPI.Test_NonX86_DispatchTable_WiringChecklist;
var
  LBackends: array[0..1] of TSimdBackend;
  LBackend: TSimdBackend;
  LTable: TSimdDispatchTable;
  LRegisteredCount: Integer;
begin
  LBackends[0] := sbNEON;
  LBackends[1] := sbRISCVV;
  LRegisteredCount := 0;

  for LBackend in LBackends do
  begin
    if not IsBackendRegistered(LBackend) then
      Continue;

    Inc(LRegisteredCount);
    CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, LTable), 'TryGetRegisteredBackendDispatchTable failed: ' + DispatchApiBackendName(LBackend));
    AssertNonX86DispatchTableWiringGroupsAssigned(Self, DispatchApiBackendName(LBackend), LTable);
  end;

  if LRegisteredCount = 0 then
    CheckTrue(True, 'No non-x86 backend registered on this host (allowed)');
end;

procedure TTestCase_DispatchAPI.Test_Phase19_DispatchTable_NestedOnly_NoDeadDraftArtifacts;
var
  LSourceLines: TSourceLines;
  LTableSource: string;
  LTypesSource: string;
  LRegisterSource: string;
  LPath: string;
  LFiles: array[0..8] of string;
  LIndex: Integer;
  LLine: string;
  LLower: string;
  LAssignPos: SizeInt;
  LDotPos: SizeInt;
  LGroup: string;
  LAllowed: Boolean;

  function IsAllowedNestedGroup(const aGroup: string): Boolean;
  begin
    Result :=
      (aGroup = 'corevectors') or
      (aGroup = 'memory') or
      (aGroup = 'mask') or
      (aGroup = 'batchf32') or
      (aGroup = 'batchf64') or
      (aGroup = 'batchinteger') or
      (aGroup = 'backend') or
      (aGroup = 'backendinfo');
  end;
begin
  LSourceLines := TSourceLines.Create;
  try
    LPath := ExpandSimdRepoPath('src/nextpas.core.simd.dispatch.table.inc');
    CheckTrue(FileExists(LPath), 'dispatch.table.inc should exist: ' + LPath);
    LSourceLines.LoadFromFile(LPath);
    LTableSource := LowerCase(LSourceLines.Text);
    CheckTrue(Pos('corevectors: tsimdcorevectorops;', LTableSource) > 0, 'table.inc should nest CoreVectors');
    CheckTrue(Pos('memory: tsimdmemoryops;', LTableSource) > 0, 'table.inc should nest Memory');
    CheckTrue(Pos('mask: tsimdmaskops;', LTableSource) > 0, 'table.inc should nest Mask');
    CheckTrue(Pos('batchf32: tsimdbatchf32ops;', LTableSource) > 0, 'table.inc should nest BatchF32');
    CheckTrue(Pos('batchf64: tsimdbatchf64ops;', LTableSource) > 0, 'table.inc should nest BatchF64');
    CheckTrue(Pos('batchinteger: tsimdbatchintegerops;', LTableSource) > 0, 'table.inc should nest BatchInteger');
    CheckTrue(Pos('addf32x4:', LTableSource) = 0, 'table.inc must not keep flat AddF32x4 fields');
    CheckTrue(Pos('f32x4: tsimdvecf32x4ops;', LTableSource) = 0, 'table.inc must not use experimental short-name F32x4 group');

    LPath := ExpandSimdRepoPath('src/nextpas.core.simd.dispatch.types.inc');
    CheckTrue(FileExists(LPath), 'dispatch.types.inc should exist: ' + LPath);
    LSourceLines.LoadFromFile(LPath);
    LTypesSource := LowerCase(LSourceLines.Text);
    CheckTrue(Pos('tsimdcorevectorops = record', LTypesSource) > 0, 'types.inc should define TSimdCoreVectorOps');
    CheckTrue(Pos('tsimdvecf32x4ops = record', LTypesSource) = 0, 'Phase 6 must drop experimental TSimdVecF32x4Ops');
    CheckTrue(Pos('tsimdvecf64x2ops = record', LTypesSource) = 0, 'Phase 6 must drop experimental TSimdVecF64x2Ops');
    CheckTrue(Pos('tsimdveci32x4ops = record', LTypesSource) = 0, 'Phase 6 must drop experimental TSimdVecI32x4Ops');

    CheckTrue(not FileExists(ExpandSimdRepoPath('src/nextpas.core.simd.dispatch.table.new.inc')),
      'Phase 6 must remove unused dispatch.table.new.inc draft');

    LFiles[0] := 'src/nextpas.core.simd.dispatch.baseline.inc';
    LFiles[1] := 'src/nextpas.core.simd.sse2.register.inc';
    LFiles[2] := 'src/nextpas.core.simd.avx2.register.inc';
    LFiles[3] := 'src/nextpas.core.simd.avx512.register.inc';
    LFiles[4] := 'src/nextpas.core.simd.neon.register.inc';
    LFiles[5] := 'src/nextpas.core.simd.riscvv.register.inc';
    LFiles[6] := 'src/nextpas.core.simd.sse3.register.inc';
    LFiles[7] := 'src/nextpas.core.simd.sse41.register.inc';
    LFiles[8] := 'src/nextpas.core.simd.sse42.register.inc';

    for LIndex := Low(LFiles) to High(LFiles) do
    begin
      LPath := ExpandSimdRepoPath(LFiles[LIndex]);
      CheckTrue(FileExists(LPath), 'register/baseline source missing: ' + LPath);
      LSourceLines.LoadFromFile(LPath);
      LRegisterSource := LSourceLines.Text;
      for LLine in LSourceLines do
      begin
        LLower := LowerCase(Trim(LLine));
        if (Pos('//', LLower) = 1) then
          Continue;
        LAssignPos := Pos('dispatchtable.', LLower);
        if LAssignPos = 0 then
          LAssignPos := Pos('table.', LLower);
        if LAssignPos = 0 then
          Continue;
        if Pos(':=', LLower) = 0 then
          Continue;
        // Extract first group after table/dispatchtable.
        if Pos('dispatchtable.', LLower) > 0 then
          LGroup := Copy(LLower, Pos('dispatchtable.', LLower) + Length('dispatchtable.'), 64)
        else
          LGroup := Copy(LLower, Pos('table.', LLower) + Length('table.'), 64);
        LDotPos := Pos('.', LGroup);
        if LDotPos > 0 then
          LGroup := Copy(LGroup, 1, LDotPos - 1)
        else
        begin
          LDotPos := Pos(' ', LGroup);
          if LDotPos > 0 then
            LGroup := Copy(LGroup, 1, LDotPos - 1);
          LDotPos := Pos(':', LGroup);
          if LDotPos > 0 then
            LGroup := Copy(LGroup, 1, LDotPos - 1);
          LDotPos := Pos(';', LGroup);
          if LDotPos > 0 then
            LGroup := Copy(LGroup, 1, LDotPos - 1);
        end;
        LAllowed := IsAllowedNestedGroup(LGroup);
        CheckTrue(LAllowed,
          'Phase 19 residual: non-nested dispatch assignment in ' + LFiles[LIndex] +
          ' group=' + LGroup + ' line=' + LLine);
      end;
    end;

    // NEON / RVV path alignment: same nested group names as x86 (not short-name F32x4.*).
    LPath := ExpandSimdRepoPath('src/nextpas.core.simd.neon.register.inc');
    LSourceLines.LoadFromFile(LPath);
    LRegisterSource := LowerCase(LSourceLines.Text);
    CheckTrue(Pos('table.corevectors.', LRegisterSource) > 0, 'NEON register must assign CoreVectors nested paths');
    CheckTrue(Pos('table.memory.', LRegisterSource) > 0, 'NEON register must assign Memory nested paths');
    CheckTrue(Pos('fillbasedispatchtable(table)', LRegisterSource) > 0, 'NEON must seed from FillBaseDispatchTable');

    LPath := ExpandSimdRepoPath('src/nextpas.core.simd.riscvv.register.inc');
    LSourceLines.LoadFromFile(LPath);
    LRegisterSource := LowerCase(LSourceLines.Text);
    CheckTrue(Pos('table.corevectors.', LRegisterSource) > 0, 'RVV register must assign CoreVectors nested paths');
    CheckTrue(Pos('table.mask.', LRegisterSource) > 0, 'RVV register must assign Mask nested paths');
    CheckTrue(Pos('fillbasedispatchtable(table)', LRegisterSource) > 0, 'RVV must seed from FillBaseDispatchTable');
  finally
    LSourceLines.Free;
  end;
end;

procedure TTestCase_DispatchAPI.Test_NonX86_NativeWideFloorCeil_Slots_NotScalar_IfAvailable;
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

  procedure AssertBackendOwnedSlotIfExpected(
    const aBackend: TSimdBackend;
    const aBackendName, aSlotName: string;
    const aScalarSlot, aBackendSlot: Pointer
  );
  begin
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + aBackendName);
    if (aBackend = sbNEON) or
       ((aBackend = sbRISCVV) and (aSlotName = 'SelectI32x4')) then
      CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), aSlotName + ' should intentionally reuse the published scalar slot on ' + aBackendName)
    else
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
    CheckTrue(aBackendSlot <> nil, aSlotName + ' missing: ' + DispatchApiBackendName(LBackend));
    if ShouldReuseScalarWideSlot(aSlotName) then
      CheckEqual(PtrUInt(aScalarSlot), PtrUInt(aBackendSlot), aSlotName + ' should reuse the scalar slot when the current non-x86 backend truth is canonical base-scalar inheritance')
    else
      CheckTrue(aBackendSlot <> aScalarSlot, aSlotName + ' unexpectedly falls back to scalar slot: ' + DispatchApiBackendName(LBackend));
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
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;

    Inc(LCheckedBackends);

  // Current ownership contract for non-x86 wide round/floor/ceil/trunc and the
  // F32 Clamp pair: reuse the base scalar slot where the backend-specific
  // wrapper is intentionally absent, otherwise keep a dedicated native slot.
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
  AssertNativeSlotNotScalar(DispatchApiBackendName(LBackend), 'FmaF32x8', Pointer(LScalarTable.CoreVectors.FmaF32x8), Pointer(LBackendTable.CoreVectors.FmaF32x8));
  AssertNeonReusesScalarOtherwiseNative('ClampF32x8', Pointer(LScalarTable.CoreVectors.ClampF32x8), Pointer(LBackendTable.CoreVectors.ClampF32x8));

  AssertNeonReusesScalarOtherwiseNative('AddF64x4', Pointer(LScalarTable.CoreVectors.AddF64x4), Pointer(LBackendTable.CoreVectors.AddF64x4));
  AssertNeonReusesScalarOtherwiseNative('SubF64x4', Pointer(LScalarTable.CoreVectors.SubF64x4), Pointer(LBackendTable.CoreVectors.SubF64x4));
  AssertNeonReusesScalarOtherwiseNative('MulF64x4', Pointer(LScalarTable.CoreVectors.MulF64x4), Pointer(LBackendTable.CoreVectors.MulF64x4));
  AssertNeonReusesScalarOtherwiseNative('DivF64x4', Pointer(LScalarTable.CoreVectors.DivF64x4), Pointer(LBackendTable.CoreVectors.DivF64x4));
  AssertNeonReusesScalarOtherwiseNative('MinF64x4', Pointer(LScalarTable.CoreVectors.MinF64x4), Pointer(LBackendTable.CoreVectors.MinF64x4));
  AssertNeonReusesScalarOtherwiseNative('MaxF64x4', Pointer(LScalarTable.CoreVectors.MaxF64x4), Pointer(LBackendTable.CoreVectors.MaxF64x4));
  AssertNeonReusesScalarOtherwiseNative('AbsF64x4', Pointer(LScalarTable.CoreVectors.AbsF64x4), Pointer(LBackendTable.CoreVectors.AbsF64x4));
  AssertNeonReusesScalarOtherwiseNative('SqrtF64x4', Pointer(LScalarTable.CoreVectors.SqrtF64x4), Pointer(LBackendTable.CoreVectors.SqrtF64x4));
  AssertNativeSlotNotScalar(DispatchApiBackendName(LBackend), 'FmaF64x4', Pointer(LScalarTable.CoreVectors.FmaF64x4), Pointer(LBackendTable.CoreVectors.FmaF64x4));
  AssertNeonReusesScalarOtherwiseNative('ClampF64x4', Pointer(LScalarTable.CoreVectors.ClampF64x4), Pointer(LBackendTable.CoreVectors.ClampF64x4));

  AssertNeonReusesScalarOtherwiseNative('AddF32x16', Pointer(LScalarTable.CoreVectors.AddF32x16), Pointer(LBackendTable.CoreVectors.AddF32x16));
  AssertNeonReusesScalarOtherwiseNative('SubF32x16', Pointer(LScalarTable.CoreVectors.SubF32x16), Pointer(LBackendTable.CoreVectors.SubF32x16));
  AssertNeonReusesScalarOtherwiseNative('MulF32x16', Pointer(LScalarTable.CoreVectors.MulF32x16), Pointer(LBackendTable.CoreVectors.MulF32x16));
  AssertNeonReusesScalarOtherwiseNative('DivF32x16', Pointer(LScalarTable.CoreVectors.DivF32x16), Pointer(LBackendTable.CoreVectors.DivF32x16));
  AssertNeonReusesScalarOtherwiseNative('MinF32x16', Pointer(LScalarTable.CoreVectors.MinF32x16), Pointer(LBackendTable.CoreVectors.MinF32x16));
  AssertNeonReusesScalarOtherwiseNative('MaxF32x16', Pointer(LScalarTable.CoreVectors.MaxF32x16), Pointer(LBackendTable.CoreVectors.MaxF32x16));
  AssertNeonReusesScalarOtherwiseNative('AbsF32x16', Pointer(LScalarTable.CoreVectors.AbsF32x16), Pointer(LBackendTable.CoreVectors.AbsF32x16));
  AssertNeonReusesScalarOtherwiseNative('SqrtF32x16', Pointer(LScalarTable.CoreVectors.SqrtF32x16), Pointer(LBackendTable.CoreVectors.SqrtF32x16));
  AssertNativeSlotNotScalar(DispatchApiBackendName(LBackend), 'FmaF32x16', Pointer(LScalarTable.CoreVectors.FmaF32x16), Pointer(LBackendTable.CoreVectors.FmaF32x16));
  AssertNeonReusesScalarOtherwiseNative('ClampF32x16', Pointer(LScalarTable.CoreVectors.ClampF32x16), Pointer(LBackendTable.CoreVectors.ClampF32x16));

  AssertNeonReusesScalarOtherwiseNative('AddF64x8', Pointer(LScalarTable.CoreVectors.AddF64x8), Pointer(LBackendTable.CoreVectors.AddF64x8));
  AssertNeonReusesScalarOtherwiseNative('SubF64x8', Pointer(LScalarTable.CoreVectors.SubF64x8), Pointer(LBackendTable.CoreVectors.SubF64x8));
  AssertNeonReusesScalarOtherwiseNative('MulF64x8', Pointer(LScalarTable.CoreVectors.MulF64x8), Pointer(LBackendTable.CoreVectors.MulF64x8));
  AssertNeonReusesScalarOtherwiseNative('DivF64x8', Pointer(LScalarTable.CoreVectors.DivF64x8), Pointer(LBackendTable.CoreVectors.DivF64x8));
  AssertNeonReusesScalarOtherwiseNative('MinF64x8', Pointer(LScalarTable.CoreVectors.MinF64x8), Pointer(LBackendTable.CoreVectors.MinF64x8));
  AssertNeonReusesScalarOtherwiseNative('MaxF64x8', Pointer(LScalarTable.CoreVectors.MaxF64x8), Pointer(LBackendTable.CoreVectors.MaxF64x8));
  AssertNeonReusesScalarOtherwiseNative('AbsF64x8', Pointer(LScalarTable.CoreVectors.AbsF64x8), Pointer(LBackendTable.CoreVectors.AbsF64x8));
  AssertNeonReusesScalarOtherwiseNative('SqrtF64x8', Pointer(LScalarTable.CoreVectors.SqrtF64x8), Pointer(LBackendTable.CoreVectors.SqrtF64x8));
  AssertNativeSlotNotScalar(DispatchApiBackendName(LBackend), 'FmaF64x8', Pointer(LScalarTable.CoreVectors.FmaF64x8), Pointer(LBackendTable.CoreVectors.FmaF64x8));
  AssertNeonReusesScalarOtherwiseNative('ClampF64x8', Pointer(LScalarTable.CoreVectors.ClampF64x8), Pointer(LBackendTable.CoreVectors.ClampF64x8));
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 backend registered on this host (allowed)');
end;

end.
