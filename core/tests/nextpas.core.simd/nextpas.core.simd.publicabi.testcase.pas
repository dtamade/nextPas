unit nextpas.core.simd.publicabi.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

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
  SysUtils, fpcunit, testregistry,
  nextpas.core.simd,
  nextpas.core.simd.fixturehelpers,
  nextpas.core.simd.testcase,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.runtime,
  nextpas.core.simd;

type
  TTestCase_PublicAbi = class(TSimdVectorAsmStatefulTestCase)
  protected
    procedure AssertCrossSurfaceCurrentState(const aContext: string;
      aExpectedBackend: TSimdBackend; const aExpectAutomatic: Boolean);
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Test_PublicApi_Table_IsBound_And_Metadata_IsPresent;
    procedure Test_PublicApi_V2_Table_IsBound_And_Metadata_IsPresent;
    procedure Test_PublicApi_CachedTable_RemainsCallable_Across_Rebind;
    procedure Test_PublicApi_CachedTable_Preserves_PreviousSnapshot_Metadata_Across_Rebind;
    procedure Test_PublicApi_V2_SnapshotGeneration_Refreshes_AfterBackendSwitch;
    procedure Test_PublicApi_Table_Refreshes_AfterBackendSwitch;
    procedure Test_PublicApi_Table_Uses_Stable_Cdecl_EntryPoints_AfterBackendSwitch;
    procedure Test_PublicApi_CachedTable_Cdecl_EntryPoints_Follow_CurrentDataPlane_After_ReRegister;
    procedure Test_PublicApi_BackendRoundTrip_Reuses_PreviouslyPublishedMetadataTable;
    procedure Test_PublicApi_VectorAsmRoundTrip_Reuses_PreviouslyPublishedMetadataTable;
    procedure Test_PublicApi_BackendPodInfo_Flags_AreSelfConsistent;
    procedure Test_PublicAbi_BackendText_Getters_Refresh_After_RegisterBackend;
    procedure Test_PublicAbi_BackendText_Getters_PreviousPointers_RemainValid_After_Refresh;
    procedure Test_PublicApi_BackendPodInfo_CapabilityBits_DoNotUnderclaim_Shuffle;
    procedure Test_PublicApi_BackendPodInfo_CapabilityBits_DoNotUnderclaim_X86MaskedOps;
    procedure Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_AVX2Shuffle_WhenNativeSlotsPresent;
    procedure Test_PublicApi_BackendPodInfo_CapabilityBits_Clear_X86Shuffle_WhenVectorAsmDisabled;
    procedure Test_PublicApi_BackendPodInfo_CapabilityBits_Keep_X86IntegerOps_When_AlwaysOn_NarrowSlots_Remain_NonScalar;
    procedure Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_AVX512FMA_WhenNativeSlotsPresent;
    procedure Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_AVX512Shuffle_WhenNativeSlotsPresent;
    procedure Test_PublicApi_BackendPodInfo_CapabilityBits_Clear_AVX512VectorAsmGatedBits_WhenVectorAsmDisabled;
    procedure Test_PublicApi_BackendPodInfo_CapabilityBits_Keep_X86MaskedOps_WhenVectorAsmDisabled;
    procedure Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_NEONShuffle_WhenNativeSlotsPresent;
    procedure Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_NEONIntegerOps_WhenNativeSlotsPresent;
    procedure Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_NEONFMA_WhenNativeSlotsPresent;
    procedure Test_PublicApi_BackendPodInfo_CapabilityBits_Clear_NEONVectorAsmGatedBits_WhenVectorAsmDisabled;
    procedure Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_RISCVVIntegerOps_WhenNativeSlotsPresent;
    procedure Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_RISCVVFMA_WhenNativeSlotsPresent;
    procedure Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_RISCVVShuffle_WhenNativeSlotsPresent;
    procedure Test_PublicApi_BackendPodInfo_CapabilityBits_Clear_RISCVVVectorAsmGatedBits_WhenVectorAsmDisabled;
    procedure Test_PublicApi_BackendPodInfo_Refreshes_WhenBackendBecomesNonDispatchable;
    procedure Test_PublicApi_ActiveBackendId_Tracks_RegisterSlot_After_ReRegister;
    procedure Test_PublicApi_StableState_Tracks_CurrentBackend_After_ControlPlaneSwitches;
    procedure Test_PublicApi_ActiveBackendId_Tracks_FinalState_When_HookReRegister_Overrides_ForcedSelection;
    procedure Test_PublicApi_FailedHookMutation_DoesNotRevive_PreviouslyRequestedBackend_AfterRestore;
    procedure Test_PublicApi_FailedHookMutation_Restores_AutomaticBackend_Immediately;
    procedure Test_PublicApi_FailedHookMutation_Restores_PreviousForcedBackend;
    procedure Test_PublicApi_RollbackRestore_ReSelects_RequestedBackend_Before_Return;
    procedure Test_PublicApi_RollbackRestore_Success_Preserves_ForcedSelection;
    procedure Test_PublicApi_RollbackRestore_Success_FromPreviousForcedState_Preserves_RequestedSelection;
    procedure Test_PublicApi_RollbackRestore_Success_FromPreviousForcedState_LateForce_DuringThirdRestore_Preserves_RequestedSelection;
    procedure Test_PublicApi_RollbackRestore_Success_FromPreviousForcedState_LateForce_UntilAttemptCap_Restores_PreviousStableState;
    procedure Test_PublicApi_RollbackRestore_Success_FromLowerPriorityPreviousForcedState_LateForce_UntilAttemptCap_Restores_PreviousStableState;
    procedure Test_PublicApi_RollbackRestore_Success_LateForce_DuringThirdRestore_Preserves_ForcedSelection;
    procedure Test_PublicApi_RollbackRestore_Success_LateForce_UntilAttemptCap_Restores_AutomaticIntent;
    procedure Test_PublicApi_RollbackRestore_LateForce_Restores_AutomaticBackend;
    procedure Test_PublicApi_RollbackRestore_LateForce_DuringRestore_Restores_AutomaticBackend;
    procedure Test_PublicApi_RollbackRestore_LateForce_DuringThirdRestore_Restores_AutomaticBackend;
    procedure Test_PublicApi_RollbackRestore_LateForce_UntilAttemptCap_Restores_AutomaticBackend;
    procedure Test_PublicApi_RollbackRestore_LateForce_Preserves_PreviousForcedBackend;
    procedure Test_PublicApi_RollbackRestore_LateForce_DuringThirdRestore_Preserves_PreviousForcedBackend;
    procedure Test_PublicApi_SetActiveBackend_HookLateFailure_Preserves_PreviousForcedBackend;
    procedure Test_PublicApi_ResetToAutomaticBackend_HookLateForce_Restores_AutomaticBackend;
    procedure Test_PublicApi_ResetToAutomaticBackend_HookLateForce_DuringRestore_Restores_AutomaticBackend;
    procedure Test_PublicApi_ResetToAutomaticBackend_HookLateForce_DuringThirdRestore_Restores_AutomaticBackend;
    procedure Test_PublicApi_ResetToAutomaticBackend_HookLateForce_UntilAttemptCap_Restores_AutomaticBackend;
    procedure Test_PublicApi_SetVectorAsmEnabled_HookLateForce_Restores_AutomaticBackend;
    procedure Test_PublicApi_SetVectorAsmEnabled_HookLateForce_DuringRestore_Restores_AutomaticBackend;
    procedure Test_PublicApi_SetVectorAsmEnabled_HookLateForce_DuringThirdRestore_Restores_AutomaticBackend;
    procedure Test_PublicApi_SetVectorAsmEnabled_HookLateForce_UntilAttemptCap_Restores_AutomaticBackend;
    procedure Test_PublicApi_SetVectorAsmEnabled_HookLateAutomaticReset_Preserves_PreviousForcedBackend;
    procedure Test_PublicApi_SetVectorAsmEnabled_HookLateAutomaticReset_DuringRestore_Preserves_PreviousForcedBackend;
    procedure Test_PublicApi_SetVectorAsmEnabled_HookLateForce_DuringRestore_Preserves_PreviousForcedBackend;
    procedure Test_PublicApi_SetVectorAsmEnabled_HookLateForce_DuringThirdRestore_Preserves_PreviousForcedBackend;
    procedure Test_PublicApi_SetVectorAsmEnabled_HookLateForce_UntilAttemptCap_Preserves_PreviousForcedBackend;
    procedure Test_PublicApi_RegisterBackend_HookLateForce_Restores_AutomaticBackend;
    procedure Test_PublicApi_RegisterBackend_HookLateForce_DuringThirdRestore_Restores_AutomaticBackend;
    procedure Test_PublicApi_RegisterBackend_HookLateAutomaticReset_Preserves_PreviousForcedBackend;
    procedure Test_PublicApi_RegisterBackend_HookLateForce_DuringRestore_Preserves_PreviousForcedBackend;
    procedure Test_PublicApi_RegisterBackend_HookLateForce_DuringThirdRestore_Preserves_PreviousForcedBackend;
    procedure Test_PublicApi_RegisterBackend_HookLateForce_UntilAttemptCap_Restores_AutomaticBackend;
    procedure Test_PublicApi_RegisterBackend_HookLateForce_UntilAttemptCap_Preserves_PreviousForcedBackend;
    procedure Test_PublicApi_Refreshes_WhenVectorAsmDisabled_ReSelects_Away_From_ScalarBacked_CurrentBackend;
    procedure Test_PublicApi_DataPlane_Parity;
    procedure Test_PublicApi_V1_And_V2_DataPlane_Parity;
  end;

implementation

function PublicAbiSyntheticMemEqualAlwaysTrue(aA, aB: Pointer; aLen: SizeUInt): LongBool;
begin
  Result := True;
end;

function PublicAbiSyntheticMemEqualAlwaysFalse(aA, aB: Pointer; aLen: SizeUInt): LongBool;
begin
  Result := False;
end;

function PublicAbiBackendName(const aBackend: TSimdBackend): string;
begin
  Result := GetBackendInfo(aBackend).Name;
end;

var
  GPublicAbiHookDisableBackendEnabled: Boolean = False;
  GPublicAbiHookDisableBackendArmed: Boolean = False;
  GPublicAbiHookDisableBackendDone: Boolean = False;
  GPublicAbiHookDisableBackendTarget: TSimdBackend = sbScalar;
  GPublicAbiHookDisableBackendOriginalTable: TSimdDispatchTable;
  GPublicAbiHookRestoreBackendEnabled: Boolean = False;
  GPublicAbiHookRestoreBackendStage: Integer = 0;
  GPublicAbiHookRestoreBackendTarget: TSimdBackend = sbScalar;
  GPublicAbiHookRestoreBackendOriginalTable: TSimdDispatchTable;
  GPublicAbiHookRollbackForceSuccessEnabled: Boolean = False;
  GPublicAbiHookRollbackForceSuccessStage: Integer = 0;
  GPublicAbiHookRollbackForceSuccessInMutation: Boolean = False;
  GPublicAbiHookRollbackForceSuccessTarget: TSimdBackend = sbScalar;
  GPublicAbiHookRollbackForceSuccessTargetTable: TSimdDispatchTable;
  GPublicAbiHookRollbackForceSuccessHigherCount: Integer = 0;
  GPublicAbiHookRollbackForceSuccessHigherBackends: array[0..Ord(High(TSimdBackend))] of TSimdBackend;
  GPublicAbiHookRollbackForceSuccessHigherTables: array[0..Ord(High(TSimdBackend))] of TSimdDispatchTable;
  GPublicAbiHookReForceBackendEnabled: Boolean = False;
  GPublicAbiHookReForceBackendStage: Integer = 0;
  GPublicAbiHookReForceBackendTarget: TSimdBackend = sbScalar;
  GPublicAbiHookResetToAutomaticEnabled: Boolean = False;
  GPublicAbiHookResetToAutomaticStage: Integer = 0;
  GPublicAbiHookResetLateForceEnabled: Boolean = False;
  GPublicAbiHookResetLateForceStage: Integer = 0;
  GPublicAbiHookResetLateForceTarget: TSimdBackend = sbScalar;
  GPublicAbiHookToggleRestoreResetEnabled: Boolean = False;
  GPublicAbiHookToggleRestoreResetStage: Integer = 0;
  GPublicAbiHookRollbackLateForceEnabled: Boolean = False;
  GPublicAbiHookRollbackLateForceStage: Integer = 0;
  GPublicAbiHookRollbackLateForceRequestedBackend: TSimdBackend = sbScalar;
  GPublicAbiHookRollbackLateForceRequestedTable: TSimdDispatchTable;
  GPublicAbiHookAutomaticRollbackLateForceEnabled: Boolean = False;
  GPublicAbiHookAutomaticRollbackLateForceStage: Integer = 0;
  GPublicAbiHookAutomaticRollbackLateForceRequestedBackend: TSimdBackend = sbScalar;
  GPublicAbiHookAutomaticRollbackLateForceRequestedTable: TSimdDispatchTable;
  GPublicAbiHookAutomaticRollbackRestoreLateForceEnabled: Boolean = False;
  GPublicAbiHookAutomaticRollbackRestoreLateForceStage: Integer = 0;
  GPublicAbiHookAutomaticRollbackRestoreLateForceRequestedBackend: TSimdBackend = sbScalar;
  GPublicAbiHookAutomaticRollbackRestoreLateForceRequestedTable: TSimdDispatchTable;
  GPublicAbiHookRegisterRestoreResetEnabled: Boolean = False;
  GPublicAbiHookRegisterRestoreResetStage: Integer = 0;

procedure PublicAbiHookDisableBackendOnce;
var
  LModifiedTable: TSimdDispatchTable;
begin
  if not GPublicAbiHookDisableBackendEnabled then
    Exit;

  if not GPublicAbiHookDisableBackendArmed then
  begin
    GPublicAbiHookDisableBackendArmed := True;
    Exit;
  end;

  if GPublicAbiHookDisableBackendDone then
    Exit;

  GPublicAbiHookDisableBackendDone := True;
  LModifiedTable := GPublicAbiHookDisableBackendOriginalTable;
  LModifiedTable.BackendInfo.Available := False;
  RegisterBackend(GPublicAbiHookDisableBackendTarget, LModifiedTable);
end;

procedure PublicAbiHookDisableThenRestoreBackendOnRollback;
var
  LModifiedTable: TSimdDispatchTable;
begin
  if not GPublicAbiHookRestoreBackendEnabled then
    Exit;

  case GPublicAbiHookRestoreBackendStage of
    0:
      begin
        GPublicAbiHookRestoreBackendStage := 1;
        Exit;
      end;
    1:
      begin
        GPublicAbiHookRestoreBackendStage := 2;
        LModifiedTable := GPublicAbiHookRestoreBackendOriginalTable;
        LModifiedTable.BackendInfo.Available := False;
        RegisterBackend(GPublicAbiHookRestoreBackendTarget, LModifiedTable);
        Exit;
      end;
    2:
      begin
        GPublicAbiHookRestoreBackendStage := 3;
        Exit;
      end;
    3:
      begin
        GPublicAbiHookRestoreBackendStage := 4;
        RegisterBackend(GPublicAbiHookRestoreBackendTarget, GPublicAbiHookRestoreBackendOriginalTable);
        Exit;
      end;
  end;
end;

procedure PublicAbiHookRollbackForceSuccessWithoutForcedIntent;
var
  LModifiedTable: TSimdDispatchTable;
  LIndex: Integer;
begin
  if not GPublicAbiHookRollbackForceSuccessEnabled then
    Exit;

  if GPublicAbiHookRollbackForceSuccessInMutation then
    Exit;

  case GPublicAbiHookRollbackForceSuccessStage of
    0:
      begin
        GPublicAbiHookRollbackForceSuccessStage := 1;
        Exit;
      end;
    1:
      begin
        GPublicAbiHookRollbackForceSuccessStage := 2;
        GPublicAbiHookRollbackForceSuccessInMutation := True;
        try
          LModifiedTable := GPublicAbiHookRollbackForceSuccessTargetTable;
          LModifiedTable.BackendInfo.Available := False;
          RegisterBackend(GPublicAbiHookRollbackForceSuccessTarget, LModifiedTable);
        finally
          GPublicAbiHookRollbackForceSuccessInMutation := False;
        end;
        Exit;
      end;
    2:
      begin
        GPublicAbiHookRollbackForceSuccessStage := 3;
        GPublicAbiHookRollbackForceSuccessInMutation := True;
        try
          RegisterBackend(GPublicAbiHookRollbackForceSuccessTarget,
            GPublicAbiHookRollbackForceSuccessTargetTable);
          for LIndex := 0 to GPublicAbiHookRollbackForceSuccessHigherCount - 1 do
          begin
            LModifiedTable := GPublicAbiHookRollbackForceSuccessHigherTables[LIndex];
            LModifiedTable.BackendInfo.Available := False;
            RegisterBackend(GPublicAbiHookRollbackForceSuccessHigherBackends[LIndex], LModifiedTable);
          end;
        finally
          GPublicAbiHookRollbackForceSuccessInMutation := False;
        end;
        Exit;
      end;
  end;
end;

procedure PublicAbiHookRollbackForceSuccessThenLateForceUntilAttemptCap;
var
  LModifiedTable: TSimdDispatchTable;
  LIndex: Integer;
begin
  if not GPublicAbiHookRollbackForceSuccessEnabled then
    Exit;

  if GPublicAbiHookRollbackForceSuccessInMutation then
    Exit;

  case GPublicAbiHookRollbackForceSuccessStage of
    0:
      begin
        GPublicAbiHookRollbackForceSuccessStage := 1;
        Exit;
      end;
    1:
      begin
        GPublicAbiHookRollbackForceSuccessStage := 2;
        GPublicAbiHookRollbackForceSuccessInMutation := True;
        try
          LModifiedTable := GPublicAbiHookRollbackForceSuccessTargetTable;
          LModifiedTable.BackendInfo.Available := False;
          RegisterBackend(GPublicAbiHookRollbackForceSuccessTarget, LModifiedTable);
        finally
          GPublicAbiHookRollbackForceSuccessInMutation := False;
        end;
        Exit;
      end;
    2:
      begin
        GPublicAbiHookRollbackForceSuccessStage := 3;
        GPublicAbiHookRollbackForceSuccessInMutation := True;
        try
          RegisterBackend(GPublicAbiHookRollbackForceSuccessTarget,
            GPublicAbiHookRollbackForceSuccessTargetTable);
          for LIndex := 0 to GPublicAbiHookRollbackForceSuccessHigherCount - 1 do
          begin
            LModifiedTable := GPublicAbiHookRollbackForceSuccessHigherTables[LIndex];
            LModifiedTable.BackendInfo.Available := False;
            RegisterBackend(GPublicAbiHookRollbackForceSuccessHigherBackends[LIndex], LModifiedTable);
          end;
        finally
          GPublicAbiHookRollbackForceSuccessInMutation := False;
        end;
        Exit;
      end;
    3, 5, 7, 9, 11, 13, 15, 17:
      begin
        Inc(GPublicAbiHookRollbackForceSuccessStage);
        SetActiveBackend(sbScalar);
        Exit;
      end;
    4, 6, 8, 10, 12, 14, 16, 18:
      begin
        Inc(GPublicAbiHookRollbackForceSuccessStage);
        Exit;
      end;
    19:
      begin
        GPublicAbiHookRollbackForceSuccessStage := 20;
        Exit;
      end;
  end;
end;

procedure PublicAbiHookRollbackForceSuccessThenLateForceOnThirdRestore;
var
  LModifiedTable: TSimdDispatchTable;
  LIndex: Integer;
begin
  if not GPublicAbiHookRollbackForceSuccessEnabled then
    Exit;

  if GPublicAbiHookRollbackForceSuccessInMutation then
    Exit;

  case GPublicAbiHookRollbackForceSuccessStage of
    0:
      begin
        GPublicAbiHookRollbackForceSuccessStage := 1;
        Exit;
      end;
    1:
      begin
        GPublicAbiHookRollbackForceSuccessStage := 2;
        GPublicAbiHookRollbackForceSuccessInMutation := True;
        try
          LModifiedTable := GPublicAbiHookRollbackForceSuccessTargetTable;
          LModifiedTable.BackendInfo.Available := False;
          RegisterBackend(GPublicAbiHookRollbackForceSuccessTarget, LModifiedTable);
        finally
          GPublicAbiHookRollbackForceSuccessInMutation := False;
        end;
        Exit;
      end;
    2:
      begin
        GPublicAbiHookRollbackForceSuccessStage := 3;
        GPublicAbiHookRollbackForceSuccessInMutation := True;
        try
          RegisterBackend(GPublicAbiHookRollbackForceSuccessTarget,
            GPublicAbiHookRollbackForceSuccessTargetTable);
          for LIndex := 0 to GPublicAbiHookRollbackForceSuccessHigherCount - 1 do
          begin
            LModifiedTable := GPublicAbiHookRollbackForceSuccessHigherTables[LIndex];
            LModifiedTable.BackendInfo.Available := False;
            RegisterBackend(GPublicAbiHookRollbackForceSuccessHigherBackends[LIndex], LModifiedTable);
          end;
        finally
          GPublicAbiHookRollbackForceSuccessInMutation := False;
        end;
        Exit;
      end;
    3:
      begin
        GPublicAbiHookRollbackForceSuccessStage := 4;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    4:
      begin
        GPublicAbiHookRollbackForceSuccessStage := 5;
        Exit;
      end;
    5:
      begin
        GPublicAbiHookRollbackForceSuccessStage := 6;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    6:
      begin
        GPublicAbiHookRollbackForceSuccessStage := 7;
        Exit;
      end;
    7:
      begin
        GPublicAbiHookRollbackForceSuccessStage := 8;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    8:
      begin
        GPublicAbiHookRollbackForceSuccessStage := 9;
        Exit;
      end;
  end;
end;

procedure PublicAbiHookReForceBackendOnce;
begin
  if not GPublicAbiHookReForceBackendEnabled then
    Exit;

  case GPublicAbiHookReForceBackendStage of
    0:
      begin
        GPublicAbiHookReForceBackendStage := 1;
        Exit;
      end;
    1:
      begin
        GPublicAbiHookReForceBackendStage := 2;
        SetActiveBackend(GPublicAbiHookReForceBackendTarget);
        Exit;
      end;
  end;
end;

procedure PublicAbiHookResetToAutomaticOnce;
begin
  if not GPublicAbiHookResetToAutomaticEnabled then
    Exit;

  case GPublicAbiHookResetToAutomaticStage of
    0:
      begin
        GPublicAbiHookResetToAutomaticStage := 1;
        Exit;
      end;
    1:
      begin
        GPublicAbiHookResetToAutomaticStage := 2;
        ResetToAutomaticBackend;
        Exit;
      end;
  end;
end;

procedure PublicAbiHookReForceBackendOnAutomaticRestore;
begin
  if not GPublicAbiHookResetLateForceEnabled then
    Exit;

  case GPublicAbiHookResetLateForceStage of
    0:
      begin
        GPublicAbiHookResetLateForceStage := 1;
        Exit;
      end;
    1:
      begin
        GPublicAbiHookResetLateForceStage := 2;
        SetActiveBackend(GPublicAbiHookResetLateForceTarget);
        Exit;
      end;
    2:
      begin
        GPublicAbiHookResetLateForceStage := 3;
        Exit;
      end;
    3:
      begin
        GPublicAbiHookResetLateForceStage := 4;
        SetActiveBackend(GPublicAbiHookResetLateForceTarget);
        Exit;
      end;
    4:
      begin
        GPublicAbiHookResetLateForceStage := 5;
        Exit;
      end;
  end;
end;

procedure PublicAbiHookReForceBackendOnAutomaticThirdRestore;
begin
  if not GPublicAbiHookResetLateForceEnabled then
    Exit;

  case GPublicAbiHookResetLateForceStage of
    0:
      begin
        GPublicAbiHookResetLateForceStage := 1;
        Exit;
      end;
    1:
      begin
        GPublicAbiHookResetLateForceStage := 2;
        SetActiveBackend(GPublicAbiHookResetLateForceTarget);
        Exit;
      end;
    2:
      begin
        GPublicAbiHookResetLateForceStage := 3;
        Exit;
      end;
    3:
      begin
        GPublicAbiHookResetLateForceStage := 4;
        SetActiveBackend(GPublicAbiHookResetLateForceTarget);
        Exit;
      end;
    4:
      begin
        GPublicAbiHookResetLateForceStage := 5;
        Exit;
      end;
    5:
      begin
        GPublicAbiHookResetLateForceStage := 6;
        SetActiveBackend(GPublicAbiHookResetLateForceTarget);
        Exit;
      end;
    6:
      begin
        GPublicAbiHookResetLateForceStage := 7;
        Exit;
      end;
  end;
end;

procedure PublicAbiHookReForceBackendOnAutomaticRestoreUntilAttemptCap;
begin
  if not GPublicAbiHookResetLateForceEnabled then
    Exit;

  case GPublicAbiHookResetLateForceStage of
    0:
      begin
        GPublicAbiHookResetLateForceStage := 1;
        Exit;
      end;
    1, 3, 5, 7, 9, 11, 13, 15:
      begin
        Inc(GPublicAbiHookResetLateForceStage);
        SetActiveBackend(GPublicAbiHookResetLateForceTarget);
        Exit;
      end;
    2, 4, 6, 8, 10, 12, 14, 16:
      begin
        Inc(GPublicAbiHookResetLateForceStage);
        Exit;
      end;
    17:
      begin
        GPublicAbiHookResetLateForceStage := 18;
        Exit;
      end;
  end;
end;

procedure PublicAbiHookReForceBackendOnToggleRestoreUntilAttemptCap;
begin
  if not GPublicAbiHookResetLateForceEnabled then
    Exit;

  case GPublicAbiHookResetLateForceStage of
    0:
      begin
        GPublicAbiHookResetLateForceStage := 1;
        Exit;
      end;
    1, 3, 5, 7, 9, 11, 13, 15, 17:
      begin
        Inc(GPublicAbiHookResetLateForceStage);
        SetActiveBackend(GPublicAbiHookResetLateForceTarget);
        Exit;
      end;
    2, 4, 6, 8, 10, 12, 14, 16, 18:
      begin
        Inc(GPublicAbiHookResetLateForceStage);
        Exit;
      end;
    19:
      begin
        GPublicAbiHookResetLateForceStage := 20;
        Exit;
      end;
  end;
end;

procedure PublicAbiHookResetToAutomaticOnToggleRestore;
begin
  if not GPublicAbiHookToggleRestoreResetEnabled then
    Exit;

  case GPublicAbiHookToggleRestoreResetStage of
    0:
      begin
        GPublicAbiHookToggleRestoreResetStage := 1;
        Exit;
      end;
    1:
      begin
        GPublicAbiHookToggleRestoreResetStage := 2;
        ResetToAutomaticBackend;
        Exit;
      end;
    2:
      begin
        GPublicAbiHookToggleRestoreResetStage := 3;
        Exit;
      end;
    3:
      begin
        GPublicAbiHookToggleRestoreResetStage := 4;
        ResetToAutomaticBackend;
        Exit;
      end;
    4:
      begin
        GPublicAbiHookToggleRestoreResetStage := 5;
        Exit;
      end;
  end;
end;

procedure PublicAbiHookDisableRequestedThenLateForceOnPreviousRestore;
var
  LModifiedTable: TSimdDispatchTable;
begin
  if not GPublicAbiHookRollbackLateForceEnabled then
    Exit;

  case GPublicAbiHookRollbackLateForceStage of
    0:
      begin
        GPublicAbiHookRollbackLateForceStage := 1;
        Exit;
      end;
    1:
      begin
        GPublicAbiHookRollbackLateForceStage := 2;
        LModifiedTable := GPublicAbiHookRollbackLateForceRequestedTable;
        LModifiedTable.BackendInfo.Available := False;
        RegisterBackend(GPublicAbiHookRollbackLateForceRequestedBackend, LModifiedTable);
        Exit;
      end;
    2:
      begin
        GPublicAbiHookRollbackLateForceStage := 3;
        Exit;
      end;
    3:
      begin
        GPublicAbiHookRollbackLateForceStage := 4;
        Exit;
      end;
    4:
      begin
        GPublicAbiHookRollbackLateForceStage := 5;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    5:
      begin
        GPublicAbiHookRollbackLateForceStage := 6;
        Exit;
      end;
  end;
end;

procedure PublicAbiHookDisableRequestedThenLateForceOnPreviousThirdRestore;
var
  LModifiedTable: TSimdDispatchTable;
begin
  if not GPublicAbiHookRollbackLateForceEnabled then
    Exit;

  case GPublicAbiHookRollbackLateForceStage of
    0:
      begin
        GPublicAbiHookRollbackLateForceStage := 1;
        Exit;
      end;
    1:
      begin
        GPublicAbiHookRollbackLateForceStage := 2;
        LModifiedTable := GPublicAbiHookRollbackLateForceRequestedTable;
        LModifiedTable.BackendInfo.Available := False;
        RegisterBackend(GPublicAbiHookRollbackLateForceRequestedBackend, LModifiedTable);
        Exit;
      end;
    2:
      begin
        GPublicAbiHookRollbackLateForceStage := 3;
        Exit;
      end;
    3:
      begin
        GPublicAbiHookRollbackLateForceStage := 4;
        Exit;
      end;
    4:
      begin
        GPublicAbiHookRollbackLateForceStage := 5;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    5:
      begin
        GPublicAbiHookRollbackLateForceStage := 6;
        Exit;
      end;
    6:
      begin
        GPublicAbiHookRollbackLateForceStage := 7;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    7:
      begin
        GPublicAbiHookRollbackLateForceStage := 8;
        Exit;
      end;
    8:
      begin
        GPublicAbiHookRollbackLateForceStage := 9;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    9:
      begin
        GPublicAbiHookRollbackLateForceStage := 10;
        Exit;
      end;
  end;
end;

procedure PublicAbiHookDisableRequestedThenLateForceOnAutomaticRestore;
var
  LModifiedTable: TSimdDispatchTable;
begin
  if not GPublicAbiHookAutomaticRollbackLateForceEnabled then
    Exit;

  case GPublicAbiHookAutomaticRollbackLateForceStage of
    0:
      begin
        GPublicAbiHookAutomaticRollbackLateForceStage := 1;
        Exit;
      end;
    1:
      begin
        GPublicAbiHookAutomaticRollbackLateForceStage := 2;
        LModifiedTable := GPublicAbiHookAutomaticRollbackLateForceRequestedTable;
        LModifiedTable.BackendInfo.Available := False;
        RegisterBackend(GPublicAbiHookAutomaticRollbackLateForceRequestedBackend, LModifiedTable);
        Exit;
      end;
    2:
      begin
        GPublicAbiHookAutomaticRollbackLateForceStage := 3;
        Exit;
      end;
    3:
      begin
        GPublicAbiHookAutomaticRollbackLateForceStage := 4;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    4:
      begin
        GPublicAbiHookAutomaticRollbackLateForceStage := 5;
        Exit;
      end;
  end;
end;

procedure PublicAbiHookDisableRequestedThenLateForceOnAutomaticThirdRestore;
var
  LModifiedTable: TSimdDispatchTable;
begin
  if not GPublicAbiHookAutomaticRollbackRestoreLateForceEnabled then
    Exit;

  case GPublicAbiHookAutomaticRollbackRestoreLateForceStage of
    0:
      begin
        GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 1;
        Exit;
      end;
    1:
      begin
        GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 2;
        LModifiedTable := GPublicAbiHookAutomaticRollbackRestoreLateForceRequestedTable;
        LModifiedTable.BackendInfo.Available := False;
        RegisterBackend(GPublicAbiHookAutomaticRollbackRestoreLateForceRequestedBackend, LModifiedTable);
        Exit;
      end;
    2:
      begin
        GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 3;
        Exit;
      end;
    3:
      begin
        GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 4;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    4:
      begin
        GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 5;
        Exit;
      end;
    5:
      begin
        GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 6;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    6:
      begin
        GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 7;
        Exit;
      end;
  end;
end;

procedure PublicAbiHookDisableRequestedThenLateForceOnAutomaticRestoreUntilAttemptCap;
var
  LModifiedTable: TSimdDispatchTable;
begin
  if not GPublicAbiHookAutomaticRollbackRestoreLateForceEnabled then
    Exit;

  case GPublicAbiHookAutomaticRollbackRestoreLateForceStage of
    0:
      begin
        GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 1;
        Exit;
      end;
    1:
      begin
        GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 2;
        LModifiedTable := GPublicAbiHookAutomaticRollbackRestoreLateForceRequestedTable;
        LModifiedTable.BackendInfo.Available := False;
        RegisterBackend(GPublicAbiHookAutomaticRollbackRestoreLateForceRequestedBackend, LModifiedTable);
        Exit;
      end;
    2:
      begin
        GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 3;
        Exit;
      end;
    3, 5, 7, 9, 11, 13, 15, 17:
      begin
        Inc(GPublicAbiHookAutomaticRollbackRestoreLateForceStage);
        SetActiveBackend(sbScalar);
        Exit;
      end;
    4, 6, 8, 10, 12, 14, 16, 18:
      begin
        Inc(GPublicAbiHookAutomaticRollbackRestoreLateForceStage);
        Exit;
      end;
    19:
      begin
        GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 20;
        Exit;
      end;
  end;
end;

procedure PublicAbiHookDisableRequestedThenLateForceOnAutomaticRestoreTwice;
var
  LModifiedTable: TSimdDispatchTable;
begin
  if not GPublicAbiHookAutomaticRollbackRestoreLateForceEnabled then
    Exit;

  case GPublicAbiHookAutomaticRollbackRestoreLateForceStage of
    0:
      begin
        GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 1;
        Exit;
      end;
    1:
      begin
        GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 2;
        LModifiedTable := GPublicAbiHookAutomaticRollbackRestoreLateForceRequestedTable;
        LModifiedTable.BackendInfo.Available := False;
        RegisterBackend(GPublicAbiHookAutomaticRollbackRestoreLateForceRequestedBackend, LModifiedTable);
        Exit;
      end;
    2:
      begin
        GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 3;
        Exit;
      end;
    3:
      begin
        GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 4;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    4:
      begin
        GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 5;
        Exit;
      end;
    5:
      begin
        GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 6;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    6:
      begin
        GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 7;
        Exit;
      end;
  end;
end;

procedure PublicAbiHookLateAutomaticResetOnRegisterRestore;
begin
  if not GPublicAbiHookRegisterRestoreResetEnabled then
    Exit;

  case GPublicAbiHookRegisterRestoreResetStage of
    0:
      begin
        GPublicAbiHookRegisterRestoreResetStage := 1;
        Exit;
      end;
    1:
      begin
        GPublicAbiHookRegisterRestoreResetStage := 2;
        ResetToAutomaticBackend;
        Exit;
      end;
    2:
      begin
        GPublicAbiHookRegisterRestoreResetStage := 3;
        Exit;
      end;
    3:
      begin
        GPublicAbiHookRegisterRestoreResetStage := 4;
        ResetToAutomaticBackend;
        Exit;
      end;
    4:
      begin
        GPublicAbiHookRegisterRestoreResetStage := 5;
        Exit;
      end;
  end;
end;

procedure PublicAbiHookReForceBackendOnRegisterRestoreUntilAttemptCap;
begin
  if not GPublicAbiHookResetLateForceEnabled then
    Exit;

  case GPublicAbiHookResetLateForceStage of
    0:
      begin
        GPublicAbiHookResetLateForceStage := 1;
        Exit;
      end;
    1, 3, 5, 7, 9, 11, 13, 15, 17:
      begin
        Inc(GPublicAbiHookResetLateForceStage);
        SetActiveBackend(GPublicAbiHookResetLateForceTarget);
        Exit;
      end;
    2, 4, 6, 8, 10, 12, 14, 16, 18:
      begin
        Inc(GPublicAbiHookResetLateForceStage);
        Exit;
      end;
    19:
      begin
        GPublicAbiHookResetLateForceStage := 20;
        Exit;
      end;
  end;
end;

procedure RegisterPublicAbiSyntheticHook(aHook: TSimdDispatchChangedHook); inline;
begin
  AddDispatchChangedHook(aHook);
end;

procedure UnregisterPublicAbiSyntheticHook(aHook: TSimdDispatchChangedHook); inline;
begin
  RemoveDispatchChangedHook(aHook);
end;

procedure EnablePublicAbiDisableBackendHook(aTarget: TSimdBackend;
  const aOriginalTable: TSimdDispatchTable);
begin
  GPublicAbiHookDisableBackendOriginalTable := aOriginalTable;
  GPublicAbiHookDisableBackendTarget := aTarget;
  GPublicAbiHookDisableBackendEnabled := True;
  GPublicAbiHookDisableBackendArmed := False;
  GPublicAbiHookDisableBackendDone := False;
  RegisterPublicAbiSyntheticHook(@PublicAbiHookDisableBackendOnce);
end;

procedure DisablePublicAbiDisableBackendHook;
begin
  UnregisterPublicAbiSyntheticHook(@PublicAbiHookDisableBackendOnce);
  GPublicAbiHookDisableBackendEnabled := False;
  GPublicAbiHookDisableBackendArmed := False;
  GPublicAbiHookDisableBackendDone := False;
end;

procedure ResetPublicAbiSyntheticHookState;
var
  LIndex: Integer;
begin
  UnregisterPublicAbiSyntheticHook(@PublicAbiHookDisableBackendOnce);
  UnregisterPublicAbiSyntheticHook(@PublicAbiHookDisableThenRestoreBackendOnRollback);
  UnregisterPublicAbiSyntheticHook(@PublicAbiHookRollbackForceSuccessWithoutForcedIntent);
  UnregisterPublicAbiSyntheticHook(@PublicAbiHookRollbackForceSuccessThenLateForceUntilAttemptCap);
  UnregisterPublicAbiSyntheticHook(@PublicAbiHookReForceBackendOnce);
  UnregisterPublicAbiSyntheticHook(@PublicAbiHookResetToAutomaticOnce);
  UnregisterPublicAbiSyntheticHook(@PublicAbiHookReForceBackendOnAutomaticRestore);
  UnregisterPublicAbiSyntheticHook(@PublicAbiHookReForceBackendOnAutomaticRestoreUntilAttemptCap);
  UnregisterPublicAbiSyntheticHook(@PublicAbiHookReForceBackendOnToggleRestoreUntilAttemptCap);
  UnregisterPublicAbiSyntheticHook(@PublicAbiHookResetToAutomaticOnToggleRestore);
  UnregisterPublicAbiSyntheticHook(@PublicAbiHookDisableRequestedThenLateForceOnPreviousRestore);
  UnregisterPublicAbiSyntheticHook(@PublicAbiHookDisableRequestedThenLateForceOnAutomaticRestore);
  UnregisterPublicAbiSyntheticHook(@PublicAbiHookDisableRequestedThenLateForceOnAutomaticRestoreUntilAttemptCap);
  UnregisterPublicAbiSyntheticHook(@PublicAbiHookDisableRequestedThenLateForceOnAutomaticRestoreTwice);
  UnregisterPublicAbiSyntheticHook(@PublicAbiHookLateAutomaticResetOnRegisterRestore);
  UnregisterPublicAbiSyntheticHook(@PublicAbiHookReForceBackendOnRegisterRestoreUntilAttemptCap);

  GPublicAbiHookDisableBackendEnabled := False;
  GPublicAbiHookDisableBackendArmed := False;
  GPublicAbiHookDisableBackendDone := False;
  GPublicAbiHookDisableBackendTarget := sbScalar;
  GPublicAbiHookDisableBackendOriginalTable := Default(TSimdDispatchTable);
  GPublicAbiHookRestoreBackendEnabled := False;
  GPublicAbiHookRestoreBackendStage := 0;
  GPublicAbiHookRestoreBackendTarget := sbScalar;
  GPublicAbiHookRestoreBackendOriginalTable := Default(TSimdDispatchTable);
  GPublicAbiHookRollbackForceSuccessEnabled := False;
  GPublicAbiHookRollbackForceSuccessStage := 0;
  GPublicAbiHookRollbackForceSuccessInMutation := False;
  GPublicAbiHookRollbackForceSuccessTarget := sbScalar;
  GPublicAbiHookRollbackForceSuccessTargetTable := Default(TSimdDispatchTable);
  GPublicAbiHookRollbackForceSuccessHigherCount := 0;
  for LIndex := Low(GPublicAbiHookRollbackForceSuccessHigherBackends) to
    High(GPublicAbiHookRollbackForceSuccessHigherBackends) do
  begin
    GPublicAbiHookRollbackForceSuccessHigherBackends[LIndex] := sbScalar;
    GPublicAbiHookRollbackForceSuccessHigherTables[LIndex] := Default(TSimdDispatchTable);
  end;
  GPublicAbiHookReForceBackendEnabled := False;
  GPublicAbiHookReForceBackendStage := 0;
  GPublicAbiHookReForceBackendTarget := sbScalar;
  GPublicAbiHookResetToAutomaticEnabled := False;
  GPublicAbiHookResetToAutomaticStage := 0;
  GPublicAbiHookResetLateForceEnabled := False;
  GPublicAbiHookResetLateForceStage := 0;
  GPublicAbiHookResetLateForceTarget := sbScalar;
  GPublicAbiHookToggleRestoreResetEnabled := False;
  GPublicAbiHookToggleRestoreResetStage := 0;
  GPublicAbiHookRollbackLateForceEnabled := False;
  GPublicAbiHookRollbackLateForceStage := 0;
  GPublicAbiHookRollbackLateForceRequestedBackend := sbScalar;
  GPublicAbiHookRollbackLateForceRequestedTable := Default(TSimdDispatchTable);
  GPublicAbiHookAutomaticRollbackLateForceEnabled := False;
  GPublicAbiHookAutomaticRollbackLateForceStage := 0;
  GPublicAbiHookAutomaticRollbackLateForceRequestedBackend := sbScalar;
  GPublicAbiHookAutomaticRollbackLateForceRequestedTable := Default(TSimdDispatchTable);
  GPublicAbiHookAutomaticRollbackRestoreLateForceEnabled := False;
  GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 0;
  GPublicAbiHookAutomaticRollbackRestoreLateForceRequestedBackend := sbScalar;
  GPublicAbiHookAutomaticRollbackRestoreLateForceRequestedTable := Default(TSimdDispatchTable);
  GPublicAbiHookRegisterRestoreResetEnabled := False;
  GPublicAbiHookRegisterRestoreResetStage := 0;

  SetVectorAsmEnabled(False);
  ResetToAutomaticBackend;
end;

procedure TTestCase_PublicAbi.SetUp;
begin
  inherited SetUp;
  ResetPublicAbiSyntheticHookState;
end;

procedure TTestCase_PublicAbi.TearDown;
begin
  ResetPublicAbiSyntheticHookState;
  inherited TearDown;
end;

procedure TTestCase_PublicAbi.AssertCrossSurfaceCurrentState(const aContext: string;
  aExpectedBackend: TSimdBackend; const aExpectAutomatic: Boolean);
var
  LApi: PFafafaSimdPublicApi;
  LDispatch: PSimdDispatchTable;
  LFrameworkInfo: TSimdBackendInfo;
  LFrameworkSnapshot: TSimdRuntimeSnapshot;
  LRuntimeInfo: TSimdBackendInfo;
  LRuntimeSnapshot: TSimdRuntimeSnapshot;
  LPodInfo: TFafafaSimdBackendPodInfo;
  LNamePtr: PAnsiChar;
  LDescriptionPtr: PAnsiChar;
  LDispatchableBackends: TSimdBackendArray;
  LFoundExpectedBackend: Boolean;
  LListIndex: Integer;
begin
  LDispatch := GetDispatchTable;
  AssertNotNull(aContext + ': dispatch table should not be nil', LDispatch);
  AssertEquals(aContext + ': facade current backend should match expected backend',
    Ord(aExpectedBackend), Ord(GetCurrentBackend));
  AssertEquals(aContext + ': runtime current backend should match expected backend',
    Ord(aExpectedBackend), Ord(nextpas.core.simd.runtime.GetCurrentBackend));

  LFrameworkSnapshot := GetCurrentRuntimeSnapshot;
  AssertEquals(aContext + ': facade runtime snapshot should match expected backend',
    Ord(aExpectedBackend), Ord(LFrameworkSnapshot.CurrentBackend));
  LRuntimeSnapshot := nextpas.core.simd.runtime.GetCurrentRuntimeSnapshot;
  AssertEquals(aContext + ': canonical runtime snapshot should match expected backend',
    Ord(aExpectedBackend), Ord(LRuntimeSnapshot.CurrentBackend));

  LFrameworkInfo := GetCurrentBackendInfo;
  AssertEquals(aContext + ': facade current backend info should match expected backend',
    Ord(aExpectedBackend), Ord(LFrameworkInfo.Backend));
  LRuntimeInfo := nextpas.core.simd.runtime.GetCurrentBackendInfo;
  AssertEquals(aContext + ': canonical runtime current backend info should match expected backend',
    Ord(aExpectedBackend), Ord(LRuntimeInfo.Backend));

  AssertEquals(aContext + ': facade runtime snapshot backend info should match expected backend',
    Ord(aExpectedBackend), Ord(LFrameworkSnapshot.CurrentBackendInfo.Backend));
  AssertEquals(aContext + ': canonical runtime snapshot backend info should match expected backend',
    Ord(aExpectedBackend), Ord(LRuntimeSnapshot.CurrentBackendInfo.Backend));
  AssertEquals(aContext + ': dispatch table backend should match expected backend',
    Ord(aExpectedBackend), Ord(LDispatch^.Backend));
  AssertEquals(aContext + ': dispatch table backend info should match expected backend',
    Ord(aExpectedBackend), Ord(LDispatch^.BackendInfo.Backend));

  AssertTrue(aContext + ': active backend pod info should remain queryable',
    TryGetSimdBackendPodInfo(aExpectedBackend, LPodInfo));
  AssertEquals(aContext + ': active backend pod info backend id should match expected backend',
    Ord(aExpectedBackend), Integer(LPodInfo.BackendId));

  LApi := GetSimdPublicApi;
  AssertNotNull(aContext + ': public API table should not be nil', LApi);
  AssertEquals(aContext + ': public API active backend id should match expected backend',
    Ord(aExpectedBackend), Integer(LApi^.ActiveBackendId));
  AssertEquals(aContext + ': public API active flags should match active backend pod flags',
    LPodInfo.Flags, LApi^.ActiveFlags);
  AssertTrue(aContext + ': public API active flags should include dispatchable',
    (LApi^.ActiveFlags and FAF_SIMD_ABI_FLAG_DISPATCHABLE) <> 0);
  AssertTrue(aContext + ': public API active flags should include active',
    (LApi^.ActiveFlags and FAF_SIMD_ABI_FLAG_ACTIVE) <> 0);

  LNamePtr := GetSimdBackendNamePtr(aExpectedBackend);
  LDescriptionPtr := GetSimdBackendDescriptionPtr(aExpectedBackend);
  AssertNotNull(aContext + ': backend name pointer should not be nil', Pointer(LNamePtr));
  AssertNotNull(aContext + ': backend description pointer should not be nil', Pointer(LDescriptionPtr));
  AssertEquals(aContext + ': facade current backend info name should align with public ABI text getter',
    LFrameworkInfo.Name, string(StrPas(LNamePtr)));
  AssertEquals(aContext + ': facade current backend info description should align with public ABI text getter',
    LFrameworkInfo.Description, string(StrPas(LDescriptionPtr)));
  AssertEquals(aContext + ': canonical runtime current backend info name should align with public ABI text getter',
    LRuntimeInfo.Name, string(StrPas(LNamePtr)));
  AssertEquals(aContext + ': canonical runtime current backend info description should align with public ABI text getter',
    LRuntimeInfo.Description, string(StrPas(LDescriptionPtr)));
  AssertEquals(aContext + ': facade runtime snapshot backend info name should align with public ABI text getter',
    LFrameworkSnapshot.CurrentBackendInfo.Name, string(StrPas(LNamePtr)));
  AssertEquals(aContext + ': facade runtime snapshot backend info description should align with public ABI text getter',
    LFrameworkSnapshot.CurrentBackendInfo.Description, string(StrPas(LDescriptionPtr)));
  AssertEquals(aContext + ': canonical runtime snapshot backend info name should align with public ABI text getter',
    LRuntimeSnapshot.CurrentBackendInfo.Name, string(StrPas(LNamePtr)));
  AssertEquals(aContext + ': canonical runtime snapshot backend info description should align with public ABI text getter',
    LRuntimeSnapshot.CurrentBackendInfo.Description, string(StrPas(LDescriptionPtr)));

  LDispatchableBackends := GetDispatchableBackendList;
  LFoundExpectedBackend := False;
  for LListIndex := 0 to High(LDispatchableBackends) do
    if LDispatchableBackends[LListIndex] = aExpectedBackend then
    begin
      LFoundExpectedBackend := True;
      Break;
    end;
  AssertTrue(aContext + ': dispatchable backend list should contain the expected backend',
    LFoundExpectedBackend);

  if aExpectAutomatic then
  begin
    AssertEquals(aContext + ': facade best dispatchable backend should match expected backend',
      Ord(aExpectedBackend), Ord(GetBestDispatchableBackend));
    AssertEquals(aContext + ': canonical runtime best dispatchable backend should match expected backend',
      Ord(aExpectedBackend), Ord(nextpas.core.simd.runtime.GetBestDispatchableBackend));
    AssertEquals(aContext + ': facade runtime snapshot best backend should match expected backend',
      Ord(aExpectedBackend), Ord(LFrameworkSnapshot.BestDispatchableBackend));
    AssertEquals(aContext + ': canonical runtime snapshot best backend should match expected backend',
      Ord(aExpectedBackend), Ord(LRuntimeSnapshot.BestDispatchableBackend));
  end;
end;

function GetPublicApiFuncPointer(const aApi: PFafafaSimdPublicApi; aSlotIndex: Integer): Pointer;
begin
  if aApi = nil then
    Exit(nil);

  case aSlotIndex of
    0: Result := Pointer(aApi^.MemEqual);
    1: Result := Pointer(aApi^.MemFindByte);
    2: Result := Pointer(aApi^.MemDiffRange);
    3: Result := Pointer(aApi^.SumBytes);
    4: Result := Pointer(aApi^.CountByte);
    5: Result := Pointer(aApi^.BitsetPopCount);
    6: Result := Pointer(aApi^.Utf8Validate);
    7: Result := Pointer(aApi^.AsciiIEqual);
    8: Result := Pointer(aApi^.BytesIndexOf);
    9: Result := Pointer(aApi^.MemCopy);
    10: Result := Pointer(aApi^.MemSet);
    11: Result := Pointer(aApi^.ToLowerAscii);
    12: Result := Pointer(aApi^.ToUpperAscii);
    13: Result := Pointer(aApi^.MemReverse);
    14: Result := Pointer(aApi^.MinMaxBytes);
  else
    Result := nil;
  end;
end;

function GetDispatchTableFuncPointer(const aDispatch: PSimdDispatchTable; aSlotIndex: Integer): Pointer;
begin
  if aDispatch = nil then
    Exit(nil);

  case aSlotIndex of
    0: Result := Pointer(aDispatch^.MemEqual);
    1: Result := Pointer(aDispatch^.MemFindByte);
    2: Result := Pointer(aDispatch^.MemDiffRange);
    3: Result := Pointer(aDispatch^.SumBytes);
    4: Result := Pointer(aDispatch^.CountByte);
    5: Result := Pointer(aDispatch^.BitsetPopCount);
    6: Result := Pointer(aDispatch^.Utf8Validate);
    7: Result := Pointer(aDispatch^.AsciiIEqual);
    8: Result := Pointer(aDispatch^.BytesIndexOf);
    9: Result := Pointer(aDispatch^.MemCopy);
    10: Result := Pointer(aDispatch^.MemSet);
    11: Result := Pointer(aDispatch^.ToLowerAscii);
    12: Result := Pointer(aDispatch^.ToUpperAscii);
    13: Result := Pointer(aDispatch^.MemReverse);
    14: Result := Pointer(aDispatch^.MinMaxBytes);
  else
    Result := nil;
  end;
end;

function GetPublicApiFuncName(aSlotIndex: Integer): string;
begin
  case aSlotIndex of
    0: Result := 'MemEqual';
    1: Result := 'MemFindByte';
    2: Result := 'MemDiffRange';
    3: Result := 'SumBytes';
    4: Result := 'CountByte';
    5: Result := 'BitsetPopCount';
    6: Result := 'Utf8Validate';
    7: Result := 'AsciiIEqual';
    8: Result := 'BytesIndexOf';
    9: Result := 'MemCopy';
    10: Result := 'MemSet';
    11: Result := 'ToLowerAscii';
    12: Result := 'ToUpperAscii';
    13: Result := 'MemReverse';
    14: Result := 'MinMaxBytes';
  else
    Result := 'UnknownSlot';
  end;
end;

function FindDifferingPublicApiDispatchSlot(const aLeft, aRight: PSimdDispatchTable;
  out aSlotIndex: Integer): Boolean;
var
  LIndex: Integer;
begin
  for LIndex := 0 to 14 do
    if GetDispatchTableFuncPointer(aLeft, LIndex) <> GetDispatchTableFuncPointer(aRight, LIndex) then
    begin
      aSlotIndex := LIndex;
      Exit(True);
    end;

  aSlotIndex := -1;
  Result := False;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_Table_IsBound_And_Metadata_IsPresent;
var
  LApi: PFafafaSimdPublicApi;
begin
  LApi := GetSimdPublicApi;
  AssertNotNull('Public API table should not be nil', LApi);
  AssertEquals('StructSize should match record size',
    SizeOf(TFafafaSimdPublicApi), LApi^.StructSize);
  AssertEquals('ABI major should match getter',
    GetSimdAbiVersionMajor, LApi^.AbiVersionMajor);
  AssertEquals('ABI minor should match getter',
    GetSimdAbiVersionMinor, LApi^.AbiVersionMinor);
  AssertTrue('ABI signature hi should be non-zero', LApi^.AbiSignatureHi <> 0);
  AssertTrue('ABI signature lo should be non-zero', LApi^.AbiSignatureLo <> 0);
  AssertEquals('Active backend id should match current backend',
    Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
  AssertTrue('MemEqual function pointer should be bound', Assigned(LApi^.MemEqual));
  AssertTrue('MemFindByte function pointer should be bound', Assigned(LApi^.MemFindByte));
  AssertTrue('MemDiffRange function pointer should be bound', Assigned(LApi^.MemDiffRange));
  AssertTrue('SumBytes function pointer should be bound', Assigned(LApi^.SumBytes));
  AssertTrue('CountByte function pointer should be bound', Assigned(LApi^.CountByte));
  AssertTrue('BitsetPopCount function pointer should be bound', Assigned(LApi^.BitsetPopCount));
  AssertTrue('Utf8Validate function pointer should be bound', Assigned(LApi^.Utf8Validate));
  AssertTrue('AsciiIEqual function pointer should be bound', Assigned(LApi^.AsciiIEqual));
  AssertTrue('BytesIndexOf function pointer should be bound', Assigned(LApi^.BytesIndexOf));
  AssertTrue('MemCopy function pointer should be bound', Assigned(LApi^.MemCopy));
  AssertTrue('MemSet function pointer should be bound', Assigned(LApi^.MemSet));
  AssertTrue('ToLowerAscii function pointer should be bound', Assigned(LApi^.ToLowerAscii));
  AssertTrue('ToUpperAscii function pointer should be bound', Assigned(LApi^.ToUpperAscii));
  AssertTrue('MemReverse function pointer should be bound', Assigned(LApi^.MemReverse));
  AssertTrue('MinMaxBytes function pointer should be bound', Assigned(LApi^.MinMaxBytes));
end;

procedure TTestCase_PublicAbi.Test_PublicApi_V2_Table_IsBound_And_Metadata_IsPresent;
var
  LApiV1: PFafafaSimdPublicApi;
  LApiV2: PFafafaSimdPublicApiV2;
begin
  LApiV1 := GetSimdPublicApi;
  LApiV2 := GetSimdPublicApiV2;
  AssertNotNull('Public API v1 table should not be nil', LApiV1);
  AssertNotNull('Public API v2 table should not be nil', LApiV2);
  AssertEquals('V2 StructSize should match record size',
    SizeOf(TFafafaSimdPublicApiV2), LApiV2^.StructSize);
  AssertEquals('V2 ABI major should be 2', 2, Integer(LApiV2^.AbiVersionMajor));
  AssertEquals('V2 ABI minor should be 0', 0, Integer(LApiV2^.AbiVersionMinor));
  AssertTrue('V2 ABI signature hi should be non-zero', LApiV2^.AbiSignatureHi <> 0);
  AssertTrue('V2 ABI signature lo should be non-zero', LApiV2^.AbiSignatureLo <> 0);
  AssertEquals('V2 active backend id should match current backend',
    Ord(GetCurrentBackend), Integer(LApiV2^.ActiveBackendId));
  AssertEquals('V2 active backend id should match v1 snapshot',
    Integer(LApiV1^.ActiveBackendId), Integer(LApiV2^.ActiveBackendId));
  AssertEquals('V2 active flags should match v1 snapshot',
    LApiV1^.ActiveFlags, LApiV2^.ActiveFlags);
  AssertTrue('V2 snapshot generation should start at a positive value',
    LApiV2^.SnapshotGeneration > 0);
  AssertTrue('V2 should advertise snapshot-bound semantics',
    (LApiV2^.SnapshotFlags and FAF_SIMD_PUBLIC_API_V2_FLAG_SNAPSHOT_BOUND) <> 0);
  AssertTrue('V2 should advertise v1 compatibility semantics',
    (LApiV2^.SnapshotFlags and FAF_SIMD_PUBLIC_API_V2_FLAG_COMPAT_V1) <> 0);
  AssertEquals('Current v2 wrapper should not advertise direct data-plane binding',
    0, Integer(LApiV2^.SnapshotFlags and FAF_SIMD_PUBLIC_API_V2_FLAG_DIRECT_DATA_PLANE));
  AssertTrue('V2 MemEqual function pointer should be bound', Assigned(LApiV2^.MemEqual));
  AssertTrue('V2 MemFindByte function pointer should be bound', Assigned(LApiV2^.MemFindByte));
  AssertTrue('V2 MemDiffRange function pointer should be bound', Assigned(LApiV2^.MemDiffRange));
  AssertTrue('V2 SumBytes function pointer should be bound', Assigned(LApiV2^.SumBytes));
  AssertTrue('V2 CountByte function pointer should be bound', Assigned(LApiV2^.CountByte));
  AssertTrue('V2 BitsetPopCount function pointer should be bound', Assigned(LApiV2^.BitsetPopCount));
  AssertTrue('V2 Utf8Validate function pointer should be bound', Assigned(LApiV2^.Utf8Validate));
  AssertTrue('V2 AsciiIEqual function pointer should be bound', Assigned(LApiV2^.AsciiIEqual));
  AssertTrue('V2 BytesIndexOf function pointer should be bound', Assigned(LApiV2^.BytesIndexOf));
  AssertTrue('V2 MemCopy function pointer should be bound', Assigned(LApiV2^.MemCopy));
  AssertTrue('V2 MemSet function pointer should be bound', Assigned(LApiV2^.MemSet));
  AssertTrue('V2 ToLowerAscii function pointer should be bound', Assigned(LApiV2^.ToLowerAscii));
  AssertTrue('V2 ToUpperAscii function pointer should be bound', Assigned(LApiV2^.ToUpperAscii));
  AssertTrue('V2 MemReverse function pointer should be bound', Assigned(LApiV2^.MemReverse));
  AssertTrue('V2 MinMaxBytes function pointer should be bound', Assigned(LApiV2^.MinMaxBytes));
end;

procedure TTestCase_PublicAbi.Test_PublicApi_CachedTable_RemainsCallable_Across_Rebind;
var
  LApiBefore: PFafafaSimdPublicApi;
  LApiAfter: PFafafaSimdPublicApi;
  LBufferA: array[0..31] of Byte;
  LBufferB: array[0..31] of Byte;
begin
  LApiBefore := GetSimdPublicApi;
  AssertNotNull('Public API table should not be nil before rebind', LApiBefore);
  FillChar(LBufferA, SizeOf(LBufferA), $42);
  FillChar(LBufferB, SizeOf(LBufferB), $42);

  AssertTrue('TrySetActiveBackend(sbScalar) should succeed', TrySetActiveBackend(sbScalar));
  LApiAfter := GetSimdPublicApi;
  AssertNotNull('Public API table should not be nil after rebind', LApiAfter);
  AssertEquals('Fresh getter should expose refreshed active backend metadata after rebind',
    Ord(sbScalar), Integer(LApiAfter^.ActiveBackendId));
  AssertTrue('Cached pre-rebind MemEqual pointer should remain callable after rebind',
    Assigned(LApiBefore^.MemEqual) and
    LApiBefore^.MemEqual(@LBufferA[0], @LBufferB[0], SizeUInt(Length(LBufferA))));
end;

procedure TTestCase_PublicAbi.Test_PublicApi_CachedTable_Preserves_PreviousSnapshot_Metadata_Across_Rebind;
var
  LApiBefore: PFafafaSimdPublicApi;
  LApiAfter: PFafafaSimdPublicApi;
  LOriginalBackend: TSimdBackend;
  LTargetBackend: TSimdBackend;
  LBeforeFlags: TFafafaSimdAbiFlags;
  LDispatchable: TSimdBackendArray;
  LFoundDifferent: Boolean;
  LIndex: Integer;
begin
  LApiBefore := GetSimdPublicApi;
  AssertNotNull('Public API table should not be nil before snapshot-preservation test', LApiBefore);
  LOriginalBackend := GetCurrentBackend;
  LBeforeFlags := LApiBefore^.ActiveFlags;
  LTargetBackend := LOriginalBackend;
  LFoundDifferent := False;

  if LOriginalBackend <> sbScalar then
  begin
    LTargetBackend := sbScalar;
    LFoundDifferent := True;
  end
  else
  begin
    LDispatchable := GetDispatchableBackendList;
    for LIndex := 0 to High(LDispatchable) do
      if LDispatchable[LIndex] <> LOriginalBackend then
      begin
        LTargetBackend := LDispatchable[LIndex];
        LFoundDifferent := True;
        Break;
      end;
  end;

  if not LFoundDifferent then
    Exit;

  AssertTrue('TrySetActiveBackend(target) should succeed in snapshot-preservation test',
    TrySetActiveBackend(LTargetBackend));

  LApiAfter := GetSimdPublicApi;
  AssertNotNull('Fresh public API table should not be nil after snapshot-preservation rebind', LApiAfter);
  AssertTrue('Fresh getter should publish a different table pointer after rebind',
    PtrUInt(LApiBefore) <> PtrUInt(LApiAfter));
  AssertEquals('Cached pre-rebind table should preserve previous active backend metadata after rebind',
    Ord(LOriginalBackend), Integer(LApiBefore^.ActiveBackendId));
  AssertEquals('Cached pre-rebind table should preserve previous active flags after rebind',
    LBeforeFlags, LApiBefore^.ActiveFlags);
  AssertEquals('Fresh public API table should expose the new active backend after rebind',
    Ord(LTargetBackend), Integer(LApiAfter^.ActiveBackendId));
  AssertTrue('Fresh public API table active flags should remain non-zero after rebind',
    LApiAfter^.ActiveFlags <> 0);
  AssertTrue('Rebind should produce fresh metadata instead of mutating the cached snapshot in place',
    (LApiAfter^.ActiveBackendId <> LApiBefore^.ActiveBackendId) or
    (LApiAfter^.ActiveFlags <> LApiBefore^.ActiveFlags));
end;

procedure TTestCase_PublicAbi.Test_PublicApi_V2_SnapshotGeneration_Refreshes_AfterBackendSwitch;
var
  LApiBefore: PFafafaSimdPublicApiV2;
  LApiAfter: PFafafaSimdPublicApiV2;
  LOriginalBackend: TSimdBackend;
  LDispatchable: TSimdBackendArray;
  LTargetBackend: TSimdBackend;
  LFoundDifferent: Boolean;
  LIndex: Integer;
begin
  LApiBefore := GetSimdPublicApiV2;
  AssertNotNull('Public API v2 table should not be nil before rebind', LApiBefore);
  LOriginalBackend := GetCurrentBackend;
  LTargetBackend := LOriginalBackend;
  LFoundDifferent := False;

  if LOriginalBackend <> sbScalar then
  begin
    LTargetBackend := sbScalar;
    LFoundDifferent := True;
  end
  else
  begin
    LDispatchable := GetDispatchableBackendList;
    for LIndex := 0 to High(LDispatchable) do
      if LDispatchable[LIndex] <> LOriginalBackend then
      begin
        LTargetBackend := LDispatchable[LIndex];
        LFoundDifferent := True;
        Break;
      end;
  end;

  if not LFoundDifferent then
    Exit;

  try
    AssertTrue('TrySetActiveBackend(target) should succeed in v2 generation test',
      TrySetActiveBackend(LTargetBackend));
    LApiAfter := GetSimdPublicApiV2;
    AssertNotNull('Public API v2 table should not be nil after rebind', LApiAfter);
    AssertTrue('V2 rebind should publish a different table pointer',
      PtrUInt(LApiBefore) <> PtrUInt(LApiAfter));
    AssertTrue('V2 snapshot generation should strictly increase after rebind',
      LApiAfter^.SnapshotGeneration > LApiBefore^.SnapshotGeneration);
    AssertEquals('V2 active backend should refresh after rebind',
      Ord(LTargetBackend), Integer(LApiAfter^.ActiveBackendId));
    AssertEquals('Cached v2 snapshot should preserve original active backend metadata',
      Ord(LOriginalBackend), Integer(LApiBefore^.ActiveBackendId));
  finally
    if GetCurrentBackend <> LOriginalBackend then
      AssertTrue('Restoring original active backend should succeed after v2 generation test',
        TrySetActiveBackend(LOriginalBackend));
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_Table_Refreshes_AfterBackendSwitch;
var
  LApi: PFafafaSimdPublicApi;
  LOriginalBackend: TSimdBackend;
  LOriginalDispatchable: TSimdBackend;
  LDispatchable: TSimdBackendArray;
  LTargetBackend: TSimdBackend;
  LFoundDifferent: Boolean;
  LIndex: Integer;
begin
  LApi := GetSimdPublicApi;
  AssertNotNull('Public API table should not be nil', LApi);
  LOriginalBackend := GetCurrentBackend;
  LOriginalDispatchable := GetBestDispatchableBackend;

  LDispatchable := GetDispatchableBackendList;
  LTargetBackend := LOriginalBackend;
  LFoundDifferent := False;
  for LIndex := 0 to High(LDispatchable) do
    if LDispatchable[LIndex] <> LOriginalBackend then
    begin
      LTargetBackend := LDispatchable[LIndex];
      LFoundDifferent := True;
      Break;
    end;

  try
    AssertTrue('TrySetActiveBackend(sbScalar) should succeed', TrySetActiveBackend(sbScalar));
    AssertEquals('Public API active backend should refresh to Scalar',
      Ord(sbScalar), Integer(GetSimdPublicApi^.ActiveBackendId));

    if LFoundDifferent then
    begin
      AssertTrue('TrySetActiveBackend(target) should succeed', TrySetActiveBackend(LTargetBackend));
      AssertEquals('Public API active backend should refresh to target backend',
        Ord(LTargetBackend), Integer(GetSimdPublicApi^.ActiveBackendId));
    end;

    ResetToAutomaticBackend;
    AssertEquals('Public API active backend should refresh after reset-to-auto',
      Ord(GetCurrentBackend), Integer(GetSimdPublicApi^.ActiveBackendId));
    AssertEquals('ResetToAutomaticBackend should restore best dispatchable backend',
      Ord(LOriginalDispatchable), Ord(GetCurrentBackend));
  finally
    if GetCurrentBackend <> LOriginalBackend then
      AssertTrue('Restoring original active backend should succeed',
        RestoreSavedBackendStateAndVerify(LOriginalBackend,
        @GetCurrentBackend));
  end;

  AssertEquals('Public API active backend should track the restored backend',
    Ord(GetCurrentBackend), Integer(GetSimdPublicApi^.ActiveBackendId));
end;

procedure TTestCase_PublicAbi.Test_PublicApi_Table_Uses_Stable_Cdecl_EntryPoints_AfterBackendSwitch;
var
  LApiBefore: PFafafaSimdPublicApi;
  LApiAfter: PFafafaSimdPublicApi;
  LDispatchBefore: PSimdDispatchTable;
  LDispatchAfter: PSimdDispatchTable;
  LDispatchable: TSimdBackendArray;
  LOriginalBackend: TSimdBackend;
  LTargetBackend: TSimdBackend;
  LSlotIndex: Integer;
  LIndex: Integer;
  LFoundDifferentBinding: Boolean;
begin
  LOriginalBackend := GetCurrentBackend;
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LOriginalBackend := GetCurrentBackend;
  LApiBefore := GetSimdPublicApi;
  LDispatchBefore := GetDispatchTable;
  AssertNotNull('Public API table should not be nil before data-plane rebind test', LApiBefore);
  AssertNotNull('Dispatch table should not be nil before data-plane rebind test', LDispatchBefore);

  LDispatchable := GetDispatchableBackendList;
  LFoundDifferentBinding := False;
  LTargetBackend := LOriginalBackend;
  LSlotIndex := -1;

  for LIndex := 0 to High(LDispatchable) do
  begin
    if LDispatchable[LIndex] = LOriginalBackend then
      Continue;
    if not TrySetActiveBackend(LDispatchable[LIndex]) then
      Continue;

    LDispatchAfter := GetDispatchTable;
    if FindDifferingPublicApiDispatchSlot(LDispatchBefore, LDispatchAfter, LSlotIndex) then
    begin
      LFoundDifferentBinding := True;
      LTargetBackend := LDispatchable[LIndex];
      Break;
    end;
  end;

  if not LFoundDifferentBinding then
    Exit;

  LApiAfter := GetSimdPublicApi;
  LDispatchAfter := GetDispatchTable;
  AssertNotNull('Fresh public API table should not be nil after backend switch', LApiAfter);
  AssertNotNull('Dispatch table should not be nil after backend switch', LDispatchAfter);
  AssertEquals('Public API active backend should track switched backend in data-plane rebind test',
    Ord(LTargetBackend), Integer(LApiAfter^.ActiveBackendId));
  AssertTrue('Underlying dispatch slot should actually change in data-plane rebind test',
    GetDispatchTableFuncPointer(LDispatchBefore, LSlotIndex) <>
    GetDispatchTableFuncPointer(LDispatchAfter, LSlotIndex));
  AssertTrue('Public API should keep a stable cdecl ABI entry point for ' +
    GetPublicApiFuncName(LSlotIndex),
    GetPublicApiFuncPointer(LApiBefore, LSlotIndex) =
    GetPublicApiFuncPointer(LApiAfter, LSlotIndex));
end;

procedure TTestCase_PublicAbi.Test_PublicApi_CachedTable_Cdecl_EntryPoints_Follow_CurrentDataPlane_After_ReRegister;
var
  LBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LModifiedTable: TSimdDispatchTable;
  LApiBefore: PFafafaSimdPublicApi;
  LApiAfter: PFafafaSimdPublicApi;
  LBufferA: array[0..7] of Byte;
  LBufferB: array[0..7] of Byte;
  LOriginalTableRestored: Boolean;
begin
  LBackend := GetCurrentBackend;
  AssertTrue('Current backend should be registered before public ABI re-register test',
    TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable));

  FillChar(LBufferA, SizeOf(LBufferA), $11);
  FillChar(LBufferB, SizeOf(LBufferB), $22);
  LApiBefore := GetSimdPublicApi;
  AssertNotNull('Public API table should be assigned before public ABI re-register test', LApiBefore);
  LOriginalTableRestored := False;

  LModifiedTable := LOriginalTable;
  LModifiedTable.MemEqual := @PublicAbiSyntheticMemEqualAlwaysTrue;
  RegisterBackend(LBackend, LModifiedTable);
  try
    AssertTrue('Cached cdecl entry point should observe the latest rebound MemEqual=true slot',
      LApiBefore^.MemEqual(@LBufferA[0], @LBufferB[0], SizeUInt(Length(LBufferA))));

    LModifiedTable := LOriginalTable;
    LModifiedTable.MemEqual := @PublicAbiSyntheticMemEqualAlwaysFalse;
    RegisterBackend(LBackend, LModifiedTable);
    try
      LApiAfter := GetSimdPublicApi;
      AssertNotNull('Public API table should stay assigned after re-register', LApiAfter);
      AssertTrue('Public API should keep the same MemEqual cdecl entry point across re-register',
        Pointer(LApiBefore^.MemEqual) = Pointer(LApiAfter^.MemEqual));
      AssertTrue('Cached cdecl entry point should track the current rebound MemEqual=false slot',
        not LApiBefore^.MemEqual(@LBufferA[0], @LBufferB[0], SizeUInt(Length(LBufferA))));
      AssertTrue('Freshly fetched cdecl entry point should track the current rebound MemEqual=false slot',
        not LApiAfter^.MemEqual(@LBufferA[0], @LBufferB[0], SizeUInt(Length(LBufferA))));
    finally
      RegisterBackend(LBackend, LOriginalTable);
      LOriginalTableRestored := True;
    end;
  finally
    if not LOriginalTableRestored then
      RegisterBackend(LBackend, LOriginalTable);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_BackendRoundTrip_Reuses_PreviouslyPublishedMetadataTable;
var
  LApiInitial: PFafafaSimdPublicApi;
  LApiMiddle: PFafafaSimdPublicApi;
  LApiFinal: PFafafaSimdPublicApi;
  LOriginalBackend: TSimdBackend;
  LTargetBackend: TSimdBackend;
  LDispatchable: TSimdBackendArray;
  LFoundDifferent: Boolean;
  LIndex: Integer;
begin
  LApiInitial := GetSimdPublicApi;
  AssertNotNull('Public API table should be assigned before public ABI round-trip test', LApiInitial);
  LOriginalBackend := GetCurrentBackend;
  LTargetBackend := LOriginalBackend;
  LFoundDifferent := False;

  LDispatchable := GetDispatchableBackendList;
  for LIndex := 0 to High(LDispatchable) do
    if LDispatchable[LIndex] <> LOriginalBackend then
    begin
      LTargetBackend := LDispatchable[LIndex];
      LFoundDifferent := True;
      Break;
    end;

  if not LFoundDifferent then
    Exit;

  AssertTrue('TrySetActiveBackend(target) should succeed in public ABI round-trip test',
    TrySetActiveBackend(LTargetBackend));
  LApiMiddle := GetSimdPublicApi;
  AssertNotNull('Public API table should be assigned for target backend in round-trip test', LApiMiddle);
  AssertTrue('public ABI round-trip test should publish a different metadata table for the target backend',
    PtrUInt(LApiMiddle) <> PtrUInt(LApiInitial));

  AssertTrue('TrySetActiveBackend(original) should succeed in public ABI round-trip test',
    TrySetActiveBackend(LOriginalBackend));
  LApiFinal := GetSimdPublicApi;
  AssertNotNull('Public API table should be assigned after switching back in round-trip test', LApiFinal);

  AssertTrue('round-trip back to the original dispatch should reuse the original public ABI metadata table',
    PtrUInt(LApiFinal) = PtrUInt(LApiInitial));
  AssertEquals('reused public ABI table should expose the restored active backend metadata',
    Ord(LOriginalBackend), Integer(LApiFinal^.ActiveBackendId));
end;

procedure TTestCase_PublicAbi.Test_PublicApi_VectorAsmRoundTrip_Reuses_PreviouslyPublishedMetadataTable;
var
  LApiInitial: PFafafaSimdPublicApi;
  LApiMiddle: PFafafaSimdPublicApi;
  LApiFinal: PFafafaSimdPublicApi;
  LInitialBackend: TSimdBackend;
  LMiddleBackend: TSimdBackend;
begin
  GetDispatchTable;
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LInitialBackend := GetCurrentBackend;
  if LInitialBackend = sbScalar then
    Exit;

  LApiInitial := GetSimdPublicApi;
  AssertNotNull('Public API table should be assigned before vector-asm round-trip test', LApiInitial);
  AssertEquals('Initial public API table should expose the current backend before vector-asm round-trip test',
    Ord(LInitialBackend), Integer(LApiInitial^.ActiveBackendId));

  SetVectorAsmEnabled(False);
  LMiddleBackend := GetCurrentBackend;
  LApiMiddle := GetSimdPublicApi;
  AssertNotNull('Public API table should stay assigned after disabling vector asm', LApiMiddle);

  if LMiddleBackend = LInitialBackend then
    Exit;

  AssertTrue('Disabling vector asm should publish a different public ABI metadata table for the fallback backend',
    PtrUInt(LApiMiddle) <> PtrUInt(LApiInitial));

  SetVectorAsmEnabled(True);
  LApiFinal := GetSimdPublicApi;
  AssertNotNull('Public API table should stay assigned after re-enabling vector asm', LApiFinal);

  AssertEquals('Re-enabling vector asm should restore the original automatic backend for public ABI',
    Ord(LInitialBackend), Integer(LApiFinal^.ActiveBackendId));
  AssertTrue('Vector-asm round-trip should reuse the original published public ABI metadata table',
    PtrUInt(LApiFinal) = PtrUInt(LApiInitial));
end;

procedure TTestCase_PublicAbi.Test_PublicApi_BackendPodInfo_Flags_AreSelfConsistent;
var
  LBackend: TSimdBackend;
  LInfo: TFafafaSimdBackendPodInfo;
  LNamePtr: PAnsiChar;
begin
  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
  begin
    AssertTrue('TryGetSimdBackendPodInfo should succeed for backend=' + PublicAbiBackendName(LBackend),
      TryGetSimdBackendPodInfo(LBackend, LInfo));
    AssertEquals('StructSize mismatch for backend=' + PublicAbiBackendName(LBackend),
      SizeOf(TFafafaSimdBackendPodInfo), LInfo.StructSize);
    AssertEquals('BackendId mismatch for backend=' + PublicAbiBackendName(LBackend),
      Ord(LBackend), Integer(LInfo.BackendId));

    if IsBackendAvailableOnCPU(LBackend) then
      AssertTrue('supported_on_cpu flag missing for backend=' + PublicAbiBackendName(LBackend),
        (LInfo.Flags and FAF_SIMD_ABI_FLAG_SUPPORTED_ON_CPU) <> 0)
    else
      AssertTrue('supported_on_cpu flag should be clear for backend=' + PublicAbiBackendName(LBackend),
        (LInfo.Flags and FAF_SIMD_ABI_FLAG_SUPPORTED_ON_CPU) = 0);

    if IsBackendRegisteredInBinary(LBackend) then
      AssertTrue('registered flag missing for backend=' + PublicAbiBackendName(LBackend),
        (LInfo.Flags and FAF_SIMD_ABI_FLAG_REGISTERED) <> 0)
    else
      AssertTrue('registered flag should be clear for backend=' + PublicAbiBackendName(LBackend),
        (LInfo.Flags and FAF_SIMD_ABI_FLAG_REGISTERED) = 0);

    if IsBackendDispatchable(LBackend) then
      AssertTrue('dispatchable flag missing for backend=' + PublicAbiBackendName(LBackend),
        (LInfo.Flags and FAF_SIMD_ABI_FLAG_DISPATCHABLE) <> 0)
    else
      AssertTrue('dispatchable flag should be clear for backend=' + PublicAbiBackendName(LBackend),
        (LInfo.Flags and FAF_SIMD_ABI_FLAG_DISPATCHABLE) = 0);

    if GetCurrentBackend = LBackend then
      AssertTrue('active flag missing for backend=' + PublicAbiBackendName(LBackend),
        (LInfo.Flags and FAF_SIMD_ABI_FLAG_ACTIVE) <> 0)
    else
      AssertTrue('active flag should be clear for backend=' + PublicAbiBackendName(LBackend),
        (LInfo.Flags and FAF_SIMD_ABI_FLAG_ACTIVE) = 0);

    if LBackend = sbRISCVV then
      AssertTrue('experimental flag missing for RISCVV',
        (LInfo.Flags and FAF_SIMD_ABI_FLAG_EXPERIMENTAL) <> 0);

    LNamePtr := GetSimdBackendNamePtr(LBackend);
    AssertNotNull('Backend name pointer should not be nil for backend=' + PublicAbiBackendName(LBackend), Pointer(LNamePtr));
    AssertTrue('Backend name should not be empty for backend=' + PublicAbiBackendName(LBackend), LNamePtr^ <> #0);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicAbi_BackendText_Getters_Refresh_After_RegisterBackend;
var
  LBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LModifiedTable: TSimdDispatchTable;
  LBackendInfo: TSimdBackendInfo;
  LNamePtr: PAnsiChar;
  LDescriptionPtr: PAnsiChar;
begin
  LBackend := GetCurrentBackend;
  AssertTrue('Backend should be registered before dynamic text refresh test',
    TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable));

  // Prime the consumer-facing text cache before mutating the backend table.
  LNamePtr := GetSimdBackendNamePtr(LBackend);
  LDescriptionPtr := GetSimdBackendDescriptionPtr(LBackend);
  AssertNotNull('Original backend name pointer should not be nil', Pointer(LNamePtr));
  AssertNotNull('Original backend description pointer should not be nil', Pointer(LDescriptionPtr));

  LModifiedTable := LOriginalTable;
  LModifiedTable.BackendInfo.Name := 'MutatedBackendName';
  LModifiedTable.BackendInfo.Description := 'Mutated backend description for public ABI refresh';
  RegisterBackend(LBackend, LModifiedTable);
  try
    LBackendInfo := GetBackendInfo(LBackend);
    AssertEquals('Dispatch metadata should reflect the updated backend name',
      'MutatedBackendName', LBackendInfo.Name);
    AssertEquals('Dispatch metadata should reflect the updated backend description',
      'Mutated backend description for public ABI refresh', LBackendInfo.Description);

    LNamePtr := GetSimdBackendNamePtr(LBackend);
    LDescriptionPtr := GetSimdBackendDescriptionPtr(LBackend);
    AssertNotNull('Updated backend name pointer should not be nil', Pointer(LNamePtr));
    AssertNotNull('Updated backend description pointer should not be nil', Pointer(LDescriptionPtr));
    AssertEquals('Public ABI backend name getter should refresh after RegisterBackend',
      'MutatedBackendName', string(StrPas(LNamePtr)));
    AssertEquals('Public ABI backend description getter should refresh after RegisterBackend',
      'Mutated backend description for public ABI refresh', string(StrPas(LDescriptionPtr)));
  finally
    RegisterBackend(LBackend, LOriginalTable);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicAbi_BackendText_Getters_PreviousPointers_RemainValid_After_Refresh;
const
  TEXT_LEN = 1024;
  REFRESH_COUNT = 32;
  CHURN_COUNT = 1024;
var
  LBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LNamePtrHistory: array of PAnsiChar;
  LDescriptionPtrHistory: array of PAnsiChar;
  LNameSnapshotHistory: array of AnsiString;
  LDescriptionSnapshotHistory: array of AnsiString;
  LNameTextLen: Integer;
  LDescriptionTextLen: Integer;
  LIndex: Integer;
  LRefreshIndex: Integer;

  function BuildFixedLengthText(const aPrefix: AnsiString; const aFill: Char;
    const aTargetLen: Integer): AnsiString;
  var
    LFillLen: Integer;
  begin
    Result := aPrefix;
    if Length(Result) < aTargetLen then
    begin
      LFillLen := aTargetLen - Length(Result);
      Result := Result + AnsiString(StringOfChar(aFill, LFillLen));
    end
    else
      SetLength(Result, aTargetLen);
  end;

  procedure RegisterBackendText(const aNameText, aDescriptionText: AnsiString);
  var
    LWorkingTable: TSimdDispatchTable;
  begin
    LWorkingTable := LOriginalTable;
    LWorkingTable.BackendInfo.Name := string(aNameText);
    LWorkingTable.BackendInfo.Description := string(aDescriptionText);
    RegisterBackend(LBackend, LWorkingTable);
  end;

  procedure CaptureBackendTextHistory(const aIndex: Integer;
    const aExpectedName, aExpectedDescription: AnsiString);
  begin
    LNamePtrHistory[aIndex] := GetSimdBackendNamePtr(LBackend);
    LDescriptionPtrHistory[aIndex] := GetSimdBackendDescriptionPtr(LBackend);
    AssertNotNull('Backend name pointer should not be nil in pointer lifetime history capture',
      Pointer(LNamePtrHistory[aIndex]));
    AssertNotNull('Backend description pointer should not be nil in pointer lifetime history capture',
      Pointer(LDescriptionPtrHistory[aIndex]));
    LNameSnapshotHistory[aIndex] := AnsiString(StrPas(LNamePtrHistory[aIndex]));
    LDescriptionSnapshotHistory[aIndex] := AnsiString(StrPas(LDescriptionPtrHistory[aIndex]));
    AssertEquals('Captured backend name should match the just-registered text',
      string(aExpectedName), string(LNameSnapshotHistory[aIndex]));
    AssertEquals('Captured backend description should match the just-registered text',
      string(aExpectedDescription), string(LDescriptionSnapshotHistory[aIndex]));
  end;

  procedure AssertHistoryStillValid(const aMaxIndex: Integer; const aContext: string);
  var
    LHistoryIndex: Integer;
  begin
    for LHistoryIndex := 0 to aMaxIndex do
    begin
      AssertEquals('Previously returned backend name pointer should remain process-lifetime valid after ' + aContext +
        ' history_index=' + IntToStr(LHistoryIndex),
        string(LNameSnapshotHistory[LHistoryIndex]), string(StrPas(LNamePtrHistory[LHistoryIndex])));
      AssertEquals('Previously returned backend description pointer should remain process-lifetime valid after ' + aContext +
        ' history_index=' + IntToStr(LHistoryIndex),
        string(LDescriptionSnapshotHistory[LHistoryIndex]), string(StrPas(LDescriptionPtrHistory[LHistoryIndex])));
    end;
  end;

  function BuildRefreshNameText(const aRefreshIndex: Integer): AnsiString;
  begin
    Result := BuildFixedLengthText(
      'PointerLifetimeNameRefresh_' + AnsiString(IntToStr(aRefreshIndex)) + '_',
      Chr(Ord('A') + (aRefreshIndex mod 20)), LNameTextLen);
  end;

  function BuildRefreshDescriptionText(const aRefreshIndex: Integer): AnsiString;
  begin
    Result := BuildFixedLengthText(
      'PointerLifetimeDescriptionRefresh_' + AnsiString(IntToStr(aRefreshIndex)) + '_',
      Chr(Ord('a') + (aRefreshIndex mod 20)), LDescriptionTextLen);
  end;

  function BuildChurnNameText(const aChurnIndex: Integer): AnsiString;
  begin
    Result := BuildFixedLengthText(
      'PointerLifetimeNameChurn_' + AnsiString(IntToStr(aChurnIndex)) + '_',
      Chr(Ord('Q') + (aChurnIndex mod 7)), LNameTextLen);
  end;

  function BuildChurnDescriptionText(const aChurnIndex: Integer): AnsiString;
  begin
    Result := BuildFixedLengthText(
      'PointerLifetimeDescriptionChurn_' + AnsiString(IntToStr(aChurnIndex)) + '_',
      Chr(Ord('q') + (aChurnIndex mod 7)), LDescriptionTextLen);
  end;
begin
  LBackend := GetCurrentBackend;
  AssertTrue('Backend should be registered before backend text pointer lifetime test',
    TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable));

  try
    LNameTextLen := Length('PointerLifetimeNameA_' + StringOfChar('A', TEXT_LEN));
    LDescriptionTextLen := Length('PointerLifetimeDescriptionA_' + StringOfChar('a', TEXT_LEN));
    SetLength(LNamePtrHistory, REFRESH_COUNT + 1);
    SetLength(LDescriptionPtrHistory, REFRESH_COUNT + 1);
    SetLength(LNameSnapshotHistory, REFRESH_COUNT + 1);
    SetLength(LDescriptionSnapshotHistory, REFRESH_COUNT + 1);

    RegisterBackendText(
      BuildFixedLengthText('PointerLifetimeNameA_', 'A', LNameTextLen),
      BuildFixedLengthText('PointerLifetimeDescriptionA_', 'a', LDescriptionTextLen));
    CaptureBackendTextHistory(0,
      BuildFixedLengthText('PointerLifetimeNameA_', 'A', LNameTextLen),
      BuildFixedLengthText('PointerLifetimeDescriptionA_', 'a', LDescriptionTextLen));

    for LRefreshIndex := 1 to REFRESH_COUNT do
    begin
      RegisterBackendText(
        BuildRefreshNameText(LRefreshIndex),
        BuildRefreshDescriptionText(LRefreshIndex));
      CaptureBackendTextHistory(LRefreshIndex,
        BuildRefreshNameText(LRefreshIndex),
        BuildRefreshDescriptionText(LRefreshIndex));
      AssertHistoryStillValid(LRefreshIndex - 1, 'refresh ' + IntToStr(LRefreshIndex));
    end;

    for LIndex := 0 to CHURN_COUNT - 1 do
    begin
      RegisterBackendText(
        BuildChurnNameText(LIndex),
        BuildChurnDescriptionText(LIndex));
      AssertEquals('Current churned backend name should be visible through the latest getter at churn_index=' +
        IntToStr(LIndex),
        string(BuildChurnNameText(LIndex)), string(StrPas(GetSimdBackendNamePtr(LBackend))));
      AssertEquals('Current churned backend description should be visible through the latest getter at churn_index=' +
        IntToStr(LIndex),
        string(BuildChurnDescriptionText(LIndex)), string(StrPas(GetSimdBackendDescriptionPtr(LBackend))));
      if (LIndex and 31) = 31 then
        AssertHistoryStillValid(REFRESH_COUNT, 're-register churn ' + IntToStr(LIndex));
    end;

    AssertHistoryStillValid(REFRESH_COUNT, 'same-sized re-register churn');
  finally
    RegisterBackend(LBackend, LOriginalTable);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_BackendPodInfo_CapabilityBits_DoNotUnderclaim_Shuffle;
var
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;
  LInfo: TFafafaSimdBackendPodInfo;
  LHasNonScalarShuffleSlots: Boolean;

  procedure ObserveRepresentativeSlot(aScalarSlot, aBackendSlot: Pointer);
  begin
    if aBackendSlot <> aScalarSlot then
      LHasNonScalarShuffleSlots := True;
  end;
begin
  AssertTrue('Scalar dispatch table should be registered',
    TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable));

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
  begin
    if LBackend = sbScalar then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TryGetSimdBackendPodInfo(LBackend, LInfo) then
      Continue;

    LHasNonScalarShuffleSlots := False;
    ObserveRepresentativeSlot(Pointer(LScalarTable.SelectF32x4), Pointer(LBackendTable.SelectF32x4));
    ObserveRepresentativeSlot(Pointer(LScalarTable.InsertF32x4), Pointer(LBackendTable.InsertF32x4));
    ObserveRepresentativeSlot(Pointer(LScalarTable.ExtractF32x4), Pointer(LBackendTable.ExtractF32x4));
    ObserveRepresentativeSlot(Pointer(LScalarTable.SelectF32x8), Pointer(LBackendTable.SelectF32x8));
    ObserveRepresentativeSlot(Pointer(LScalarTable.SelectF64x4), Pointer(LBackendTable.SelectF64x4));

    if not LHasNonScalarShuffleSlots then
      Continue;

    AssertTrue('Public ABI CapabilityBits missing scShuffle while representative shuffle slots are non-scalar for backend=' + PublicAbiBackendName(LBackend),
      (LInfo.CapabilityBits and (UInt64(1) shl Ord(scShuffle))) <> 0);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_BackendPodInfo_CapabilityBits_DoNotUnderclaim_X86MaskedOps;
var
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;
  LInfo: TFafafaSimdBackendPodInfo;
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

  procedure ObserveRepresentativeSlot(aScalarSlot, aBackendSlot: Pointer);
  begin
    if aBackendSlot <> aScalarSlot then
      LHasNonScalarMaskedSlots := True;
  end;
begin
  AssertTrue('Scalar dispatch table should be registered',
    TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable));

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
  begin
    if not IsX86MaskedOpsBackend(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TryGetSimdBackendPodInfo(LBackend, LInfo) then
      Continue;

    LHasNonScalarMaskedSlots := False;
    ObserveRepresentativeSlot(Pointer(LScalarTable.Mask2All), Pointer(LBackendTable.Mask2All));
    ObserveRepresentativeSlot(Pointer(LScalarTable.Mask4PopCount), Pointer(LBackendTable.Mask4PopCount));
    ObserveRepresentativeSlot(Pointer(LScalarTable.Mask8All), Pointer(LBackendTable.Mask8All));
    ObserveRepresentativeSlot(Pointer(LScalarTable.Mask8PopCount), Pointer(LBackendTable.Mask8PopCount));
    ObserveRepresentativeSlot(Pointer(LScalarTable.Mask16FirstSet), Pointer(LBackendTable.Mask16FirstSet));

    if not LHasNonScalarMaskedSlots then
      Continue;

    AssertTrue('Public ABI CapabilityBits missing scMaskedOps while representative x86 mask helper slots are non-scalar for backend=' + PublicAbiBackendName(LBackend),
      (LInfo.CapabilityBits and (UInt64(1) shl Ord(scMaskedOps))) <> 0);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_AVX2Shuffle_WhenNativeSlotsPresent;
var
  LScalarTable: TSimdDispatchTable;
  LAVX2Table: TSimdDispatchTable;
  LInfo: TFafafaSimdBackendPodInfo;
begin
  AssertTrue('Scalar dispatch table should be registered',
    TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable));

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;
  if not TryGetRegisteredBackendDispatchTable(sbAVX2, LAVX2Table) then
    Exit;
  if not TryGetSimdBackendPodInfo(sbAVX2, LInfo) then
    Exit;

  if (Pointer(LAVX2Table.SelectF32x4) = Pointer(LScalarTable.SelectF32x4)) and
     (Pointer(LAVX2Table.InsertF32x4) = Pointer(LScalarTable.InsertF32x4)) and
     (Pointer(LAVX2Table.ExtractF32x4) = Pointer(LScalarTable.ExtractF32x4)) and
     (Pointer(LAVX2Table.SelectF32x8) = Pointer(LScalarTable.SelectF32x8)) and
     (Pointer(LAVX2Table.SelectF64x4) = Pointer(LScalarTable.SelectF64x4)) then
    Exit;

  AssertTrue('Public ABI CapabilityBits should expose AVX2 scShuffle when representative shuffle slots are non-scalar',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scShuffle))) <> 0);
end;

procedure TTestCase_PublicAbi.Test_PublicApi_BackendPodInfo_CapabilityBits_Clear_X86Shuffle_WhenVectorAsmDisabled;
var
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;
  LInfo: TFafafaSimdBackendPodInfo;

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
  AssertTrue('Scalar dispatch table should be registered',
    TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable));

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  SetVectorAsmEnabled(False);
  AssertFalse('Vector asm should be disabled for x86 shuffle public ABI rebuild test', IsVectorAsmEnabled);

  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
  begin
    if not IsShuffleCapabilityGatedBackend(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TryGetSimdBackendPodInfo(LBackend, LInfo) then
      Continue;

    AssertEquals('Representative SelectF32x4 slot should be scalar when vector asm is disabled for backend=' + PublicAbiBackendName(LBackend),
      PtrUInt(LScalarTable.SelectF32x4), PtrUInt(LBackendTable.SelectF32x4));
    AssertEquals('Representative InsertF32x4 slot should be scalar when vector asm is disabled for backend=' + PublicAbiBackendName(LBackend),
      PtrUInt(LScalarTable.InsertF32x4), PtrUInt(LBackendTable.InsertF32x4));
    AssertEquals('Representative ExtractF32x4 slot should be scalar when vector asm is disabled for backend=' + PublicAbiBackendName(LBackend),
      PtrUInt(LScalarTable.ExtractF32x4), PtrUInt(LBackendTable.ExtractF32x4));

    AssertTrue('Public ABI CapabilityBits should clear scShuffle when representative shuffle slots are scalar for backend=' + PublicAbiBackendName(LBackend),
      (LInfo.CapabilityBits and (UInt64(1) shl Ord(scShuffle))) = 0);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_BackendPodInfo_CapabilityBits_Keep_X86IntegerOps_When_AlwaysOn_NarrowSlots_Remain_NonScalar;
var
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;
  LInfo: TFafafaSimdBackendPodInfo;
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
  AssertTrue('Scalar dispatch table should be registered',
    TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable));

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  SetVectorAsmEnabled(False);
  AssertFalse('Vector asm should be disabled for always-on x86 integer public ABI rebuild test', IsVectorAsmEnabled);

  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
  begin
    if not IsAlwaysOnNarrowIntegerBackend(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TryGetSimdBackendPodInfo(LBackend, LInfo) then
      Continue;

    LHasNonScalarAlwaysOnIntegerSlots := False;
    ObserveRepresentativeSlot(Pointer(LScalarTable.AddI16x8), Pointer(LBackendTable.AddI16x8));
    ObserveRepresentativeSlot(Pointer(LScalarTable.AndI16x8), Pointer(LBackendTable.AndI16x8));
    ObserveRepresentativeSlot(Pointer(LScalarTable.CmpEqI16x8), Pointer(LBackendTable.CmpEqI16x8));
    ObserveRepresentativeSlot(Pointer(LScalarTable.AddU8x16), Pointer(LBackendTable.AddU8x16));
    ObserveRepresentativeSlot(Pointer(LScalarTable.MaxU8x16), Pointer(LBackendTable.MaxU8x16));

    if not LHasNonScalarAlwaysOnIntegerSlots then
      Continue;

    AssertTrue('Public ABI CapabilityBits should keep scIntegerOps while always-on narrow integer slots remain non-scalar after vector asm disable for backend=' +
      PublicAbiBackendName(LBackend),
      (LInfo.CapabilityBits and (UInt64(1) shl Ord(scIntegerOps))) <> 0);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_AVX512FMA_WhenNativeSlotsPresent;
var
  LScalarTable: TSimdDispatchTable;
  LAVX512Table: TSimdDispatchTable;
  LInfo: TFafafaSimdBackendPodInfo;
begin
  AssertTrue('Scalar dispatch table should be registered',
    TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable));

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;
  if not TryGetRegisteredBackendDispatchTable(sbAVX512, LAVX512Table) then
    Exit;
  if not TryGetSimdBackendPodInfo(sbAVX512, LInfo) then
    Exit;

  AssertTrue('AVX512 FmaF32x16 should be assigned', Assigned(LAVX512Table.FmaF32x16));
  AssertTrue('AVX512 FmaF64x8 should be assigned', Assigned(LAVX512Table.FmaF64x8));

  if (Pointer(LAVX512Table.FmaF32x16) = Pointer(LScalarTable.FmaF32x16)) and
     (Pointer(LAVX512Table.FmaF64x8) = Pointer(LScalarTable.FmaF64x8)) then
    Exit;

  AssertTrue('Public ABI CapabilityBits should expose AVX512 scFMA when wide FMA slots are non-scalar',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scFMA))) <> 0);
end;

procedure TTestCase_PublicAbi.Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_AVX512Shuffle_WhenNativeSlotsPresent;
var
  LScalarTable: TSimdDispatchTable;
  LAVX512Table: TSimdDispatchTable;
  LInfo: TFafafaSimdBackendPodInfo;
begin
  AssertTrue('Scalar dispatch table should be registered',
    TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable));

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;
  if not TryGetRegisteredBackendDispatchTable(sbAVX512, LAVX512Table) then
    Exit;
  if not TryGetSimdBackendPodInfo(sbAVX512, LInfo) then
    Exit;

  if (Pointer(LAVX512Table.SelectF32x16) = Pointer(LScalarTable.SelectF32x16)) and
     (Pointer(LAVX512Table.SelectF64x8) = Pointer(LScalarTable.SelectF64x8)) then
    Exit;

  AssertTrue('Public ABI CapabilityBits should expose AVX512 scShuffle when wide select slots are non-scalar',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scShuffle))) <> 0);
end;

procedure TTestCase_PublicAbi.Test_PublicApi_BackendPodInfo_CapabilityBits_Clear_AVX512VectorAsmGatedBits_WhenVectorAsmDisabled;
var
  LAVX512Table: TSimdDispatchTable;
  LInfo: TFafafaSimdBackendPodInfo;
begin
  if not TryGetRegisteredBackendDispatchTable(sbAVX512, LAVX512Table) then
    Exit;

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;
  SetVectorAsmEnabled(False);
  AssertFalse('Vector asm should be disabled for AVX512 public ABI rebuild test', IsVectorAsmEnabled);
  AssertTrue('AVX512 backend should remain registered after runtime rebuild',
    TryGetRegisteredBackendDispatchTable(sbAVX512, LAVX512Table));
  AssertTrue('AVX512 backend pod info should remain queryable after runtime rebuild',
    TryGetSimdBackendPodInfo(sbAVX512, LInfo));

  AssertTrue('Public ABI CapabilityBits should clear AVX512 scFMA when vector asm is disabled',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scFMA))) = 0);
  AssertTrue('Public ABI CapabilityBits should clear AVX512 scShuffle when vector asm is disabled',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scShuffle))) = 0);
  AssertTrue('Public ABI CapabilityBits should clear AVX512 scIntegerOps when vector asm is disabled',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scIntegerOps))) = 0);
  AssertTrue('Public ABI CapabilityBits should clear AVX512 sc512BitOps when vector asm is disabled',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(sc512BitOps))) = 0);
end;

procedure TTestCase_PublicAbi.Test_PublicApi_BackendPodInfo_CapabilityBits_Keep_X86MaskedOps_WhenVectorAsmDisabled;
var
  LBackend: TSimdBackend;
  LScalarTable: TSimdDispatchTable;
  LBackendTable: TSimdDispatchTable;
  LInfo: TFafafaSimdBackendPodInfo;
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

  procedure ObserveRepresentativeSlot(aScalarSlot, aBackendSlot: Pointer);
  begin
    if aBackendSlot <> aScalarSlot then
      LHasNonScalarMaskedSlots := True;
  end;
begin
  AssertTrue('Scalar dispatch table should be registered',
    TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable));

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;
  SetVectorAsmEnabled(False);
  AssertFalse('Vector asm should be disabled for x86 masked-ops public ABI rebuild test', IsVectorAsmEnabled);

  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
  begin
    if not IsX86MaskedOpsBackend(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LBackendTable) then
      Continue;
    if not TryGetSimdBackendPodInfo(LBackend, LInfo) then
      Continue;

    LHasNonScalarMaskedSlots := False;
    ObserveRepresentativeSlot(Pointer(LScalarTable.Mask2All), Pointer(LBackendTable.Mask2All));
    ObserveRepresentativeSlot(Pointer(LScalarTable.Mask4PopCount), Pointer(LBackendTable.Mask4PopCount));
    ObserveRepresentativeSlot(Pointer(LScalarTable.Mask8All), Pointer(LBackendTable.Mask8All));
    ObserveRepresentativeSlot(Pointer(LScalarTable.Mask8PopCount), Pointer(LBackendTable.Mask8PopCount));
    ObserveRepresentativeSlot(Pointer(LScalarTable.Mask16FirstSet), Pointer(LBackendTable.Mask16FirstSet));

    if not LHasNonScalarMaskedSlots then
      Continue;

    AssertTrue('Public ABI CapabilityBits should keep scMaskedOps while representative x86 mask helper slots remain non-scalar after vector asm disable for backend=' + PublicAbiBackendName(LBackend),
      (LInfo.CapabilityBits and (UInt64(1) shl Ord(scMaskedOps))) <> 0);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_NEONShuffle_WhenNativeSlotsPresent;
var
  LScalarTable: TSimdDispatchTable;
  LNEONTable: TSimdDispatchTable;
  LInfo: TFafafaSimdBackendPodInfo;
begin
  AssertTrue('Scalar dispatch table should be registered',
    TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable));

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  AssertTrue('NEON opt-in test registration should be present',
    TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable));
  AssertTrue('NEON opt-in public ABI pod info should be present',
    TryGetSimdBackendPodInfo(sbNEON, LInfo));
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  if not TryGetSimdBackendPodInfo(sbNEON, LInfo) then
    Exit;
  {$ENDIF}

  if (Pointer(LNEONTable.SelectF32x4) = Pointer(LScalarTable.SelectF32x4)) and
     (Pointer(LNEONTable.InsertF32x4) = Pointer(LScalarTable.InsertF32x4)) and
     (Pointer(LNEONTable.ExtractF32x4) = Pointer(LScalarTable.ExtractF32x4)) and
     (Pointer(LNEONTable.SelectF32x8) = Pointer(LScalarTable.SelectF32x8)) and
     (Pointer(LNEONTable.SelectF64x4) = Pointer(LScalarTable.SelectF64x4)) then
    Exit;

  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  AssertTrue('Public ABI CapabilityBits should expose NEON scShuffle when NEON asm-backed representative shuffle slots are non-scalar',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scShuffle))) <> 0);
  {$ELSE}
  AssertTrue('Public ABI CapabilityBits should clear NEON scShuffle when only scalar fallback shuffle slots are compiled',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scShuffle))) = 0);
  {$ENDIF}
end;

procedure TTestCase_PublicAbi.Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_NEONFMA_WhenNativeSlotsPresent;
var
  LNEONTable: TSimdDispatchTable;
  LInfo: TFafafaSimdBackendPodInfo;
begin
  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  AssertTrue('NEON opt-in test registration should be present',
    TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable));
  AssertTrue('NEON opt-in public ABI pod info should be present',
    TryGetSimdBackendPodInfo(sbNEON, LInfo));
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  if not TryGetSimdBackendPodInfo(sbNEON, LInfo) then
    Exit;
  {$ENDIF}

  AssertTrue('NEON FmaF32x4 should be assigned', Assigned(LNEONTable.FmaF32x4));
  AssertTrue('NEON FmaF32x8 should be assigned', Assigned(LNEONTable.FmaF32x8));
  AssertTrue('NEON FmaF64x2 should be assigned', Assigned(LNEONTable.FmaF64x2));
  AssertTrue('NEON FmaF64x4 should be assigned', Assigned(LNEONTable.FmaF64x4));

  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  AssertTrue('Public ABI CapabilityBits should expose NEON scFMA when NEON asm-backed FMA slots are compiled',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scFMA))) <> 0);
  {$ELSE}
  AssertTrue('Public ABI CapabilityBits should clear NEON scFMA when only scalar/common fallback FMA slots are compiled',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scFMA))) = 0);
  {$ENDIF}
end;

procedure TTestCase_PublicAbi.Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_NEONIntegerOps_WhenNativeSlotsPresent;
var
  LNEONTable: TSimdDispatchTable;
  LInfo: TFafafaSimdBackendPodInfo;
begin
  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  AssertTrue('NEON opt-in test registration should be present',
    TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable));
  AssertTrue('NEON opt-in public ABI pod info should be present',
    TryGetSimdBackendPodInfo(sbNEON, LInfo));
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable) then
    Exit;
  if not TryGetSimdBackendPodInfo(sbNEON, LInfo) then
    Exit;
  {$ENDIF}

  AssertTrue('NEON AddI32x4 should be assigned', Assigned(LNEONTable.AddI32x4));
  AssertTrue('NEON AndI32x4 should be assigned', Assigned(LNEONTable.AndI32x4));
  AssertTrue('NEON AddI16x8 should be assigned', Assigned(LNEONTable.AddI16x8));

  {$IFDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  AssertTrue('Public ABI CapabilityBits should expose NEON scIntegerOps when NEON asm-backed integer slots are compiled',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scIntegerOps))) <> 0);
  {$ELSE}
  AssertTrue('Public ABI CapabilityBits should clear NEON scIntegerOps when only scalar/common fallback integer slots are compiled',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scIntegerOps))) = 0);
  {$ENDIF}
end;

procedure TTestCase_PublicAbi.Test_PublicApi_BackendPodInfo_CapabilityBits_Clear_NEONVectorAsmGatedBits_WhenVectorAsmDisabled;
var
  LNEONTable: TSimdDispatchTable;
  LInfo: TFafafaSimdBackendPodInfo;
begin
  {$IFNDEF NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
  Exit;
  {$ENDIF}

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  SetVectorAsmEnabled(False);
  AssertFalse('Vector asm should be disabled for NEON public ABI rebuild test', IsVectorAsmEnabled);
  AssertTrue('NEON backend should remain registered after runtime rebuild',
    TryGetRegisteredBackendDispatchTable(sbNEON, LNEONTable));
  AssertTrue('NEON backend pod info should remain queryable after runtime rebuild',
    TryGetSimdBackendPodInfo(sbNEON, LInfo));

  AssertTrue('Public ABI CapabilityBits should clear NEON scFMA when vector asm is disabled',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scFMA))) = 0);
  AssertTrue('Public ABI CapabilityBits should clear NEON scIntegerOps when vector asm is disabled',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scIntegerOps))) = 0);
  AssertTrue('Public ABI CapabilityBits should clear NEON scShuffle when vector asm is disabled',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scShuffle))) = 0);
end;

procedure TTestCase_PublicAbi.Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_RISCVVIntegerOps_WhenNativeSlotsPresent;
var
  LRISCVVTable: TSimdDispatchTable;
  LInfo: TFafafaSimdBackendPodInfo;
begin
  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  AssertTrue('RISCVV opt-in test registration should be present',
    TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable));
  AssertTrue('RISCVV opt-in public ABI pod info should be present',
    TryGetSimdBackendPodInfo(sbRISCVV, LInfo));
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  if not TryGetSimdBackendPodInfo(sbRISCVV, LInfo) then
    Exit;
  {$ENDIF}

  AssertTrue('RISCVV AddI32x4 should be assigned', Assigned(LRISCVVTable.AddI32x4));
  AssertTrue('RISCVV AndI32x4 should be assigned', Assigned(LRISCVVTable.AndI32x4));
  AssertTrue('RISCVV AddI64x2 should be assigned', Assigned(LRISCVVTable.AddI64x2));

  {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
  AssertTrue('Public ABI CapabilityBits should expose RISCVV scIntegerOps when RVV asm-backed integer slots are compiled',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scIntegerOps))) <> 0);
  {$ELSE}
  AssertTrue('Public ABI CapabilityBits should clear RISCVV scIntegerOps when only scalar/common fallback integer slots are compiled',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scIntegerOps))) = 0);
  {$ENDIF}
end;

procedure TTestCase_PublicAbi.Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_RISCVVFMA_WhenNativeSlotsPresent;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LInfo: TFafafaSimdBackendPodInfo;
begin
  AssertTrue('Scalar dispatch table should be registered',
    TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable));

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  AssertTrue('RISCVV opt-in test registration should be present',
    TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable));
  AssertTrue('RISCVV opt-in public ABI pod info should be present',
    TryGetSimdBackendPodInfo(sbRISCVV, LInfo));
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  if not TryGetSimdBackendPodInfo(sbRISCVV, LInfo) then
    Exit;
  {$ENDIF}

  if (Pointer(LRISCVVTable.FmaF32x4) = Pointer(LScalarTable.FmaF32x4)) and
     (Pointer(LRISCVVTable.FmaF32x8) = Pointer(LScalarTable.FmaF32x8)) and
     (Pointer(LRISCVVTable.FmaF64x2) = Pointer(LScalarTable.FmaF64x2)) and
     (Pointer(LRISCVVTable.FmaF64x4) = Pointer(LScalarTable.FmaF64x4)) and
     (Pointer(LRISCVVTable.FmaF32x16) = Pointer(LScalarTable.FmaF32x16)) and
     (Pointer(LRISCVVTable.FmaF64x8) = Pointer(LScalarTable.FmaF64x8)) then
    Exit;

  {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
  AssertTrue('Public ABI CapabilityBits should expose RISCVV scFMA when RVV asm-backed representative FMA slots are non-scalar',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scFMA))) <> 0);
  {$ELSE}
  AssertTrue('Public ABI CapabilityBits should clear RISCVV scFMA when only scalar fallback FMA slots are compiled',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scFMA))) = 0);
  {$ENDIF}
end;

procedure TTestCase_PublicAbi.Test_PublicApi_BackendPodInfo_CapabilityBits_Expose_RISCVVShuffle_WhenNativeSlotsPresent;
var
  LRISCVVTable: TSimdDispatchTable;
  LInfo: TFafafaSimdBackendPodInfo;
begin
  GetDispatchTable;
  SetVectorAsmEnabled(True);
  if not IsVectorAsmEnabled then
    Exit;

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  AssertTrue('RISCVV opt-in test registration should be present',
    TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable));
  AssertTrue('RISCVV opt-in public ABI pod info should be present',
    TryGetSimdBackendPodInfo(sbRISCVV, LInfo));
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
    Exit;
  if not TryGetSimdBackendPodInfo(sbRISCVV, LInfo) then
    Exit;
  {$ENDIF}

  AssertTrue('RISCVV SelectF32x4 should be assigned', Assigned(LRISCVVTable.SelectF32x4));
  AssertTrue('RISCVV InsertF32x4 should be assigned', Assigned(LRISCVVTable.InsertF32x4));
  AssertTrue('RISCVV ExtractF32x4 should be assigned', Assigned(LRISCVVTable.ExtractF32x4));

  {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
  AssertTrue('Public ABI CapabilityBits should expose RISCVV scShuffle when RVV asm-backed representative shuffle slots are compiled',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scShuffle))) <> 0);
  {$ELSE}
  AssertTrue('Public ABI CapabilityBits should clear RISCVV scShuffle when only scalar/common fallback shuffle slots are compiled',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scShuffle))) = 0);
  {$ENDIF}
end;

procedure TTestCase_PublicAbi.Test_PublicApi_BackendPodInfo_CapabilityBits_Clear_RISCVVVectorAsmGatedBits_WhenVectorAsmDisabled;
var
  LRISCVVTable: TSimdDispatchTable;
  LInfo: TFafafaSimdBackendPodInfo;
begin
  {$IFNDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
  Exit;
  {$ENDIF}

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  SetVectorAsmEnabled(False);
  AssertFalse('Vector asm should be disabled for RISCVV public ABI rebuild test', IsVectorAsmEnabled);
  AssertTrue('RISCVV backend should remain registered after runtime rebuild',
    TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable));
  AssertTrue('RISCVV backend pod info should remain queryable after runtime rebuild',
    TryGetSimdBackendPodInfo(sbRISCVV, LInfo));

  AssertTrue('Public ABI CapabilityBits should clear RISCVV scFMA when vector asm is disabled',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scFMA))) = 0);
  AssertTrue('Public ABI CapabilityBits should clear RISCVV scIntegerOps when vector asm is disabled',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scIntegerOps))) = 0);
  AssertTrue('Public ABI CapabilityBits should clear RISCVV scShuffle when vector asm is disabled',
    (LInfo.CapabilityBits and (UInt64(1) shl Ord(scShuffle))) = 0);
end;

procedure TTestCase_PublicAbi.Test_PublicApi_BackendPodInfo_Refreshes_WhenBackendBecomesNonDispatchable;
var
  LApi: PFafafaSimdPublicApi;
  LOriginalBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LModifiedTable: TSimdDispatchTable;
  LOriginalInfo: TFafafaSimdBackendPodInfo;
  LUpdatedInfo: TFafafaSimdBackendPodInfo;
  LActiveInfo: TFafafaSimdBackendPodInfo;
begin
  LOriginalBackend := GetCurrentBackend;

  // If the platform only has the scalar backend dispatchable, this dynamic split
  // cannot be exercised meaningfully.
  if LOriginalBackend = sbScalar then
    Exit;

  AssertTrue('Original active backend should be registered',
    TryGetRegisteredBackendDispatchTable(LOriginalBackend, LOriginalTable));
  AssertTrue('Original active backend pod info should be queryable',
    TryGetSimdBackendPodInfo(LOriginalBackend, LOriginalInfo));
  AssertTrue('Original active backend should start as dispatchable',
    (LOriginalInfo.Flags and FAF_SIMD_ABI_FLAG_DISPATCHABLE) <> 0);
  AssertTrue('Original active backend should start as active',
    (LOriginalInfo.Flags and FAF_SIMD_ABI_FLAG_ACTIVE) <> 0);

  LModifiedTable := LOriginalTable;
  LModifiedTable.BackendInfo.Available := False;
  RegisterBackend(LOriginalBackend, LModifiedTable);
  try
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should not be nil after backend re-registration', LApi);
    AssertEquals('Public API active backend should track current backend after re-registration',
      Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
    AssertTrue('Re-selection should move away from backend marked unavailable',
      GetCurrentBackend <> LOriginalBackend);
    AssertTrue('Public API active flags should keep active bit after re-selection',
      (LApi^.ActiveFlags and FAF_SIMD_ABI_FLAG_ACTIVE) <> 0);
    AssertTrue('Public API active flags should keep dispatchable bit after re-selection',
      (LApi^.ActiveFlags and FAF_SIMD_ABI_FLAG_DISPATCHABLE) <> 0);

    AssertTrue('Original backend pod info should remain queryable after re-registration',
      TryGetSimdBackendPodInfo(LOriginalBackend, LUpdatedInfo));
    AssertTrue('Original backend should remain CPU-supported after re-registration',
      (LUpdatedInfo.Flags and FAF_SIMD_ABI_FLAG_SUPPORTED_ON_CPU) <> 0);
    AssertTrue('Original backend should remain registered after re-registration',
      (LUpdatedInfo.Flags and FAF_SIMD_ABI_FLAG_REGISTERED) <> 0);
    AssertTrue('Original backend should lose dispatchable bit after re-registration',
      (LUpdatedInfo.Flags and FAF_SIMD_ABI_FLAG_DISPATCHABLE) = 0);
    AssertTrue('Original backend should lose active bit after re-selection',
      (LUpdatedInfo.Flags and FAF_SIMD_ABI_FLAG_ACTIVE) = 0);

    AssertTrue('New active backend pod info should be queryable',
      TryGetSimdBackendPodInfo(GetCurrentBackend, LActiveInfo));
    AssertEquals('Active backend pod flags should match public api active flags after re-selection',
      LActiveInfo.Flags, LApi^.ActiveFlags);
  finally
    RegisterBackend(LOriginalBackend, LOriginalTable);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_ActiveBackendId_Tracks_RegisterSlot_After_ReRegister;
var
  LApi: PFafafaSimdPublicApi;
  LOriginalBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LModifiedTable: TSimdDispatchTable;
  LActiveInfo: TFafafaSimdBackendPodInfo;
begin
  GetSimdPublicApi;
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LOriginalBackend := GetCurrentBackend;
  if LOriginalBackend = sbScalar then
    Exit;

  AssertTrue('Original active backend should be registered for public ABI identity test',
    TryGetRegisteredBackendDispatchTable(LOriginalBackend, LOriginalTable));

  LModifiedTable := LOriginalTable;
  LModifiedTable.Backend := sbScalar;
  LModifiedTable.BackendInfo.Backend := sbScalar;
  RegisterBackend(LOriginalBackend, LModifiedTable);
  try
    AssertTrue('TrySetActiveBackend should succeed for the requested backend slot after re-register',
      TrySetActiveBackend(LOriginalBackend));

    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after identity-mismatch re-register', LApi);
    AssertEquals('Public API active backend id should track the registered backend slot, not the stale table Backend field',
      Ord(LOriginalBackend), Integer(LApi^.ActiveBackendId));
    AssertTrue('Backend pod info should remain queryable for the requested backend slot',
      TryGetSimdBackendPodInfo(LOriginalBackend, LActiveInfo));
    AssertEquals('Public API active flags should match the requested backend pod flags after re-register',
      LActiveInfo.Flags, LApi^.ActiveFlags);
  finally
    RegisterBackend(LOriginalBackend, LOriginalTable);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_StableState_Tracks_CurrentBackend_After_ControlPlaneSwitches;
var
  LAvailableBackends: TSimdBackendArray;
  LForcedBackend: TSimdBackend;
  LIndex: Integer;
  LHasForcedBackend: Boolean;

  procedure AssertStableCurrentState(const aContext: string; const aExpectAutomatic: Boolean);
  var
    LApi: PFafafaSimdPublicApi;
    LCurrentBackend: TSimdBackend;
    LCurrentInfo: TSimdBackendInfo;
    LCurrentPodInfo: TFafafaSimdBackendPodInfo;
    LDispatchableBackends: TSimdBackendArray;
    LFoundCurrent: Boolean;
    LListIndex: Integer;
    LNamePtr: PAnsiChar;
    LDescriptionPtr: PAnsiChar;
  begin
    LCurrentBackend := GetCurrentBackend;
    LCurrentInfo := GetCurrentBackendInfo;
    AssertTrue(aContext + ': active backend pod info should remain queryable',
      TryGetSimdBackendPodInfo(LCurrentBackend, LCurrentPodInfo));
    LApi := GetSimdPublicApi;
    AssertNotNull(aContext + ': public API table should not be nil', LApi);
    LNamePtr := GetSimdBackendNamePtr(LCurrentBackend);
    LDescriptionPtr := GetSimdBackendDescriptionPtr(LCurrentBackend);
    LDispatchableBackends := GetAvailableBackendList;

    AssertEquals(aContext + ': public API active backend id should match current backend',
      Ord(LCurrentBackend), Integer(LApi^.ActiveBackendId));
    AssertEquals(aContext + ': public API active flags should match active backend pod flags',
      LCurrentPodInfo.Flags, LApi^.ActiveFlags);
    AssertEquals(aContext + ': current backend info backend should match current backend',
      Ord(LCurrentBackend), Ord(LCurrentInfo.Backend));
    AssertTrue(aContext + ': public API active flags should include dispatchable',
      (LApi^.ActiveFlags and FAF_SIMD_ABI_FLAG_DISPATCHABLE) <> 0);
    AssertTrue(aContext + ': public API active flags should include active',
      (LApi^.ActiveFlags and FAF_SIMD_ABI_FLAG_ACTIVE) <> 0);
    AssertNotNull(aContext + ': backend name pointer should not be nil', Pointer(LNamePtr));
    AssertNotNull(aContext + ': backend description pointer should not be nil', Pointer(LDescriptionPtr));
    AssertEquals(aContext + ': current backend info name should stay aligned with public ABI text getter',
      LCurrentInfo.Name, string(StrPas(LNamePtr)));
    AssertEquals(aContext + ': current backend info description should stay aligned with public ABI text getter',
      LCurrentInfo.Description, string(StrPas(LDescriptionPtr)));

    LFoundCurrent := False;
    for LListIndex := 0 to High(LDispatchableBackends) do
      if LDispatchableBackends[LListIndex] = LCurrentBackend then
      begin
        LFoundCurrent := True;
        Break;
      end;
    AssertTrue(aContext + ': dispatchable list should contain current backend in stable state',
      LFoundCurrent);

    if aExpectAutomatic then
      AssertEquals(aContext + ': best dispatchable backend should match current backend in automatic stable state',
        Ord(GetBestDispatchableBackend), Ord(LCurrentBackend));
  end;
begin
  LForcedBackend := sbScalar;
  LHasForcedBackend := False;

  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  AssertStableCurrentState('vector asm enabled automatic', True);

  LAvailableBackends := GetAvailableBackendList;
  for LIndex := 0 to High(LAvailableBackends) do
    if LAvailableBackends[LIndex] <> GetCurrentBackend then
    begin
      LForcedBackend := LAvailableBackends[LIndex];
      LHasForcedBackend := True;
      Break;
    end;

  if LHasForcedBackend then
  begin
    SetActiveBackend(LForcedBackend);
    AssertStableCurrentState('forced backend stable state', False);
  end;

  ResetToAutomaticBackend;
  AssertStableCurrentState('automatic reset stable state', True);

  SetVectorAsmEnabled(False);
  ResetToAutomaticBackend;
  AssertStableCurrentState('vector asm disabled automatic', True);
end;

procedure TTestCase_PublicAbi.Test_PublicApi_ActiveBackendId_Tracks_FinalState_When_HookReRegister_Overrides_ForcedSelection;
var
  LApi: PFafafaSimdPublicApi;
  LRequestedBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LRequestedBackend := GetCurrentBackend;
  if LRequestedBackend = sbScalar then
    Exit;

  AssertTrue('Requested backend should be registered for public ABI hook-driven reselection test',
    TryGetRegisteredBackendDispatchTable(LRequestedBackend, LOriginalTable));
  AssertTrue('Requested backend should start dispatchable before hook-driven mutation',
    IsBackendDispatchable(LRequestedBackend));

  EnablePublicAbiDisableBackendHook(LRequestedBackend, LOriginalTable);
  try
    AssertFalse('TrySetActiveBackend should fail when hook-driven re-register makes the requested backend non-dispatchable before the call completes',
      TrySetActiveBackend(LRequestedBackend));

    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after hook-driven re-selection', LApi);
    AssertEquals('Public API active backend id should track the final active backend after hook-driven re-selection',
      Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
    AssertTrue('Hook-driven re-selection should move public API active backend away from the requested backend',
      Integer(LApi^.ActiveBackendId) <> Ord(LRequestedBackend));
  finally
    DisablePublicAbiDisableBackendHook;
    RegisterBackend(LRequestedBackend, LOriginalTable);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_FailedHookMutation_DoesNotRevive_PreviouslyRequestedBackend_AfterRestore;
var
  LApi: PFafafaSimdPublicApi;
  LAutomaticBackend: TSimdBackend;
  LRequestedBackend: TSimdBackend;
  LDispatchable: TSimdBackendArray;
  LOriginalTable: TSimdDispatchTable;
  LRequestedTableCaptured: Boolean;
  LIndex: Integer;
begin
  LRequestedTableCaptured := False;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LAutomaticBackend := GetCurrentBackend;
    LRequestedBackend := LAutomaticBackend;
    LDispatchable := GetDispatchableBackendList;
    for LIndex := 0 to High(LDispatchable) do
      if (LDispatchable[LIndex] <> LAutomaticBackend) and
         (LDispatchable[LIndex] <> sbScalar) then
      begin
        LRequestedBackend := LDispatchable[LIndex];
        Break;
      end;

    if (LRequestedBackend = LAutomaticBackend) or (LRequestedBackend = sbScalar) then
      Exit;

    AssertTrue('Requested backend should be registered for public ABI lingering-force test',
      TryGetRegisteredBackendDispatchTable(LRequestedBackend, LOriginalTable));
    LRequestedTableCaptured := True;
    AssertTrue('Requested backend should start dispatchable before public ABI lingering-force test',
      IsBackendDispatchable(LRequestedBackend));

    EnablePublicAbiDisableBackendHook(LRequestedBackend, LOriginalTable);
    try
      AssertFalse('TrySetActiveBackend should fail when hook-driven mutation makes the requested backend non-dispatchable before completion',
        TrySetActiveBackend(LRequestedBackend));
    finally
      DisablePublicAbiDisableBackendHook;
    end;

    RegisterBackend(LRequestedBackend, LOriginalTable);
    LRequestedTableCaptured := False;
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after restoring the requested backend table', LApi);
    AssertEquals('Public API active backend should return to automatic selection instead of reviving the previously failed requested backend',
      Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
    AssertTrue('Public API active backend should stay away from the previously failed requested backend after restore',
      Integer(LApi^.ActiveBackendId) <> Ord(LRequestedBackend));
    AssertEquals('Public API active backend id should keep tracking the actual current backend after restore',
      Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
  finally
    if LRequestedTableCaptured then
      RegisterBackend(LRequestedBackend, LOriginalTable);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_FailedHookMutation_Restores_AutomaticBackend_Immediately;
var
  LApi: PFafafaSimdPublicApi;
  LActiveInfo: TFafafaSimdBackendPodInfo;
  LAutomaticBackend: TSimdBackend;
  LRequestedBackend: TSimdBackend;
  LDispatchable: TSimdBackendArray;
  LOriginalTable: TSimdDispatchTable;
  LIndex: Integer;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LAutomaticBackend := GetCurrentBackend;
  if LAutomaticBackend = sbScalar then
    Exit;

  AssertEquals('Automatic selection should start from best dispatchable backend before public ABI failed-hook restore test',
    Ord(LAutomaticBackend), Ord(GetBestDispatchableBackend));

  LRequestedBackend := sbScalar;
  LDispatchable := GetDispatchableBackendList;
  for LIndex := 0 to High(LDispatchable) do
    if (LDispatchable[LIndex] <> LAutomaticBackend) and (LDispatchable[LIndex] <> sbScalar) then
    begin
      LRequestedBackend := LDispatchable[LIndex];
      Break;
    end;

  if LRequestedBackend = sbScalar then
    Exit;

  AssertTrue('Requested backend should be registered for public ABI failed-hook automatic-restore test',
    TryGetRegisteredBackendDispatchTable(LRequestedBackend, LOriginalTable));
  AssertTrue('Requested backend should start dispatchable before public ABI failed-hook automatic-restore test',
    IsBackendDispatchable(LRequestedBackend));

  EnablePublicAbiDisableBackendHook(LRequestedBackend, LOriginalTable);
  try
    AssertFalse('TrySetActiveBackend should fail when hook-driven mutation makes the requested backend non-dispatchable before public ABI automatic restore',
      TrySetActiveBackend(LRequestedBackend));

    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after failed hook-driven automatic restore', LApi);
    AssertEquals('Public API active backend should immediately return to automatic best backend after failed hook-driven selection',
      Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
    AssertEquals('Public API active backend id should keep tracking the actual current backend after failed hook-driven selection',
      Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
    AssertTrue('Public API active backend should not remain Scalar when automatic mode has a better backend',
      Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
    AssertTrue('Backend pod info for the restored automatic backend should remain queryable',
      TryGetSimdBackendPodInfo(LAutomaticBackend, LActiveInfo));
    AssertEquals('Public API active flags should stay aligned with the automatic backend pod flags after failed hook-driven selection',
      LActiveInfo.Flags, LApi^.ActiveFlags);
  finally
    DisablePublicAbiDisableBackendHook;
    RegisterBackend(LRequestedBackend, LOriginalTable);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_FailedHookMutation_Restores_PreviousForcedBackend;
var
  LApi: PFafafaSimdPublicApi;
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LPreviousForcedBackend: TSimdBackend;
  LRequestedBackend: TSimdBackend;
  LRequestedOriginalTable: TSimdDispatchTable;
  LRequestedTableCaptured: Boolean;
  LSelectedCount: Integer;
  LIndex: Integer;
begin
  LRequestedTableCaptured := False;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LDispatchable := GetDispatchableBackendList;
    if Length(LDispatchable) < 3 then
      Exit;

    LAutomaticBackend := GetBestDispatchableBackend;
    LPreviousForcedBackend := sbScalar;
    LRequestedBackend := sbScalar;
    LSelectedCount := 0;
    for LIndex := 0 to High(LDispatchable) do
      if (LDispatchable[LIndex] <> LAutomaticBackend) and (LDispatchable[LIndex] <> sbScalar) then
      begin
        Inc(LSelectedCount);
        if LSelectedCount = 1 then
          LPreviousForcedBackend := LDispatchable[LIndex]
        else
        begin
          LRequestedBackend := LDispatchable[LIndex];
          Break;
        end;
      end;

    if (LPreviousForcedBackend = sbScalar) or (LRequestedBackend = sbScalar) then
      Exit;

    AssertTrue('Previous forced backend should differ from automatic best backend in public ABI previous-forced rollback test',
      LPreviousForcedBackend <> LAutomaticBackend);
    AssertTrue('Previous forced backend setup should succeed before public ABI late-failure rollback test',
      TrySetActiveBackend(LPreviousForcedBackend));
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after setting up the previous forced backend', LApi);
    AssertEquals('Public API active backend should reflect the previous forced backend before attempting the failing switch',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));

    AssertTrue('Requested backend should be registered for public ABI previous-forced rollback test',
      TryGetRegisteredBackendDispatchTable(LRequestedBackend, LRequestedOriginalTable));
    LRequestedTableCaptured := True;
    AssertTrue('Requested backend should start dispatchable before public ABI previous-forced rollback test',
      IsBackendDispatchable(LRequestedBackend));

    EnablePublicAbiDisableBackendHook(LRequestedBackend, LRequestedOriginalTable);
    try
      AssertFalse('TrySetActiveBackend should fail when hook-driven mutation makes the requested backend non-dispatchable after a different backend was already forced',
        TrySetActiveBackend(LRequestedBackend));
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available after previous-forced late-failure rollback', LApi);
      AssertEquals('Public API active backend must restore the previously forced backend instead of reverting to automatic best backend',
        Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));
      AssertEquals('Public API active backend should keep tracking the actual current backend after previous-forced late-failure rollback',
        Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
    finally
      DisablePublicAbiDisableBackendHook;
    end;

    RegisterBackend(LRequestedBackend, LRequestedOriginalTable);
    LRequestedTableCaptured := False;
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after restoring the requested backend table in previous-forced rollback test', LApi);
    AssertEquals('Restoring the requested backend table after a failed switch must keep the previous forced backend active in public ABI',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));
    AssertEquals('Public API active backend should keep tracking the current backend after restoring the requested backend table',
      Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
  finally
    if LRequestedTableCaptured then
      RegisterBackend(LRequestedBackend, LRequestedOriginalTable);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_RollbackRestore_ReSelects_RequestedBackend_Before_Return;
var
  LApi: PFafafaSimdPublicApi;
  LRequestedBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LRequestedBackend := GetCurrentBackend;
  if LRequestedBackend = sbScalar then
    Exit;

  AssertEquals('Automatic selection should start from best dispatchable backend before public ABI rollback-restore consistency test',
    Ord(LRequestedBackend), Ord(GetBestDispatchableBackend));
  AssertTrue('Requested backend should be registered for public ABI rollback-restore consistency test',
    TryGetRegisteredBackendDispatchTable(LRequestedBackend, LOriginalTable));
  AssertTrue('Requested backend should start dispatchable before public ABI rollback-restore consistency test',
    IsBackendDispatchable(LRequestedBackend));

  GPublicAbiHookRestoreBackendOriginalTable := LOriginalTable;
  GPublicAbiHookRestoreBackendTarget := LRequestedBackend;
  GPublicAbiHookRestoreBackendEnabled := True;
  GPublicAbiHookRestoreBackendStage := 0;
  AddDispatchChangedHook(@PublicAbiHookDisableThenRestoreBackendOnRollback);
  try
    AssertTrue('TrySetActiveBackend should report success when rollback-time restore makes the requested backend active again before public ABI observation',
      TrySetActiveBackend(LRequestedBackend));
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after rollback-time restore consistency test', LApi);
    AssertEquals('Public API active backend id should match the requested backend when rollback-time restore re-selects it before return',
      Ord(LRequestedBackend), Integer(LApi^.ActiveBackendId));
    AssertEquals('Public API active backend should keep tracking the actual current backend after rollback-time restore',
      Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
    AssertEquals('Synthetic public ABI rollback-restore hook should complete all expected stages',
      4, GPublicAbiHookRestoreBackendStage);
  finally
    RemoveDispatchChangedHook(@PublicAbiHookDisableThenRestoreBackendOnRollback);
    GPublicAbiHookRestoreBackendEnabled := False;
    GPublicAbiHookRestoreBackendStage := 0;
    RegisterBackend(LRequestedBackend, LOriginalTable);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_RollbackRestore_Success_Preserves_ForcedSelection;
var
  LApi: PFafafaSimdPublicApi;
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LRequestedBackend: TSimdBackend;
  LBackend: TSimdBackend;
  LTargetTableCaptured: Boolean;
  LIndex: Integer;
begin
  LTargetTableCaptured := False;
  GPublicAbiHookRollbackForceSuccessHigherCount := 0;
  GPublicAbiHookRollbackForceSuccessTarget := sbScalar;
  GPublicAbiHookRollbackForceSuccessTargetTable := Default(TSimdDispatchTable);
  GPublicAbiHookRollbackForceSuccessStage := 0;
  GPublicAbiHookRollbackForceSuccessEnabled := False;
  GPublicAbiHookRollbackForceSuccessInMutation := False;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LDispatchable := GetDispatchableBackendList;
    if Length(LDispatchable) < 2 then
      Exit;

    LAutomaticBackend := GetBestDispatchableBackend;
    LRequestedBackend := sbScalar;
    for LIndex := High(LDispatchable) downto 0 do
      if (LDispatchable[LIndex] <> sbScalar) and (LDispatchable[LIndex] <> LAutomaticBackend) then
      begin
        LRequestedBackend := LDispatchable[LIndex];
        Break;
      end;
    if LRequestedBackend = sbScalar then
      Exit;

    AssertTrue('Requested backend should be registered for public ABI rollback forced-success preservation test',
      TryGetRegisteredBackendDispatchTable(LRequestedBackend, GPublicAbiHookRollbackForceSuccessTargetTable));
    LTargetTableCaptured := True;

    GPublicAbiHookRollbackForceSuccessHigherCount := 0;
    for LBackend in LDispatchable do
    begin
      if LBackend = LRequestedBackend then
        Break;
      if LBackend = sbScalar then
        Continue;
      AssertTrue('Higher-priority backend should be registered for public ABI rollback forced-success preservation test',
        TryGetRegisteredBackendDispatchTable(LBackend,
          GPublicAbiHookRollbackForceSuccessHigherTables[GPublicAbiHookRollbackForceSuccessHigherCount]));
      GPublicAbiHookRollbackForceSuccessHigherBackends[GPublicAbiHookRollbackForceSuccessHigherCount] := LBackend;
      Inc(GPublicAbiHookRollbackForceSuccessHigherCount);
    end;
    AssertTrue('Public ABI rollback forced-success preservation test requires at least one higher-priority backend to suppress',
      GPublicAbiHookRollbackForceSuccessHigherCount > 0);

    GPublicAbiHookRollbackForceSuccessTarget := LRequestedBackend;
    GPublicAbiHookRollbackForceSuccessEnabled := True;
    GPublicAbiHookRollbackForceSuccessStage := 0;
    GPublicAbiHookRollbackForceSuccessInMutation := False;
    AddDispatchChangedHook(@PublicAbiHookRollbackForceSuccessWithoutForcedIntent);
    try
      AssertTrue('TrySetActiveBackend should report success when rollback-time restore reselects the requested backend before public ABI observation',
        TrySetActiveBackend(LRequestedBackend));
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available in rollback forced-success preservation test', LApi);
      AssertEquals('Return-time public API active backend should equal the requested backend in rollback forced-success preservation test',
        Ord(LRequestedBackend), Integer(LApi^.ActiveBackendId));
      AssertEquals('Synthetic public ABI rollback forced-success hook should complete all expected stages',
        3, GPublicAbiHookRollbackForceSuccessStage);
    finally
      RemoveDispatchChangedHook(@PublicAbiHookRollbackForceSuccessWithoutForcedIntent);
      GPublicAbiHookRollbackForceSuccessEnabled := False;
      GPublicAbiHookRollbackForceSuccessInMutation := False;
    end;

    for LIndex := 0 to GPublicAbiHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GPublicAbiHookRollbackForceSuccessHigherBackends[LIndex],
        GPublicAbiHookRollbackForceSuccessHigherTables[LIndex]);

    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after restoring higher-priority backends', LApi);
    AssertEquals('A successful TrySetActiveBackend must keep the requested backend active in public ABI after higher-priority backends are restored',
      Ord(LRequestedBackend), Integer(LApi^.ActiveBackendId));
    AssertEquals('Public API active backend should keep tracking the actual current backend after restoring higher-priority backends',
      Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
    LTargetTableCaptured := False;
    GPublicAbiHookRollbackForceSuccessHigherCount := 0;
  finally
    if LTargetTableCaptured then
      RegisterBackend(GPublicAbiHookRollbackForceSuccessTarget,
        GPublicAbiHookRollbackForceSuccessTargetTable);
    for LIndex := 0 to GPublicAbiHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GPublicAbiHookRollbackForceSuccessHigherBackends[LIndex],
        GPublicAbiHookRollbackForceSuccessHigherTables[LIndex]);
    GPublicAbiHookRollbackForceSuccessHigherCount := 0;
    GPublicAbiHookRollbackForceSuccessTarget := sbScalar;
    GPublicAbiHookRollbackForceSuccessStage := 0;
    GPublicAbiHookRollbackForceSuccessEnabled := False;
    GPublicAbiHookRollbackForceSuccessInMutation := False;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_RollbackRestore_Success_FromPreviousForcedState_Preserves_RequestedSelection;
var
  LApi: PFafafaSimdPublicApi;
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LPreviousForcedBackend: TSimdBackend;
  LRequestedBackend: TSimdBackend;
  LBackend: TSimdBackend;
  LOldVectorAsm: Boolean;
  LTargetTableCaptured: Boolean;
  LSelectedCount: Integer;
  LIndex: Integer;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LTargetTableCaptured := False;
  GPublicAbiHookRollbackForceSuccessHigherCount := 0;
  GPublicAbiHookRollbackForceSuccessTarget := sbScalar;
  GPublicAbiHookRollbackForceSuccessTargetTable := Default(TSimdDispatchTable);
  GPublicAbiHookRollbackForceSuccessStage := 0;
  GPublicAbiHookRollbackForceSuccessEnabled := False;
  GPublicAbiHookRollbackForceSuccessInMutation := False;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LDispatchable := GetDispatchableBackendList;
    if Length(LDispatchable) < 3 then
      Exit;

    LAutomaticBackend := GetBestDispatchableBackend;
    LPreviousForcedBackend := sbScalar;
    LRequestedBackend := sbScalar;
    LSelectedCount := 0;
    for LIndex := 0 to High(LDispatchable) do
      if (LDispatchable[LIndex] <> LAutomaticBackend) and (LDispatchable[LIndex] <> sbScalar) then
      begin
        Inc(LSelectedCount);
        if LSelectedCount = 1 then
          LPreviousForcedBackend := LDispatchable[LIndex]
        else
        begin
          LRequestedBackend := LDispatchable[LIndex];
          Break;
        end;
      end;

    if (LPreviousForcedBackend = sbScalar) or (LRequestedBackend = sbScalar) then
      Exit;

    AssertTrue('Previous forced backend should differ from automatic best backend in public ABI rollback forced-success previous-state test',
      LPreviousForcedBackend <> LAutomaticBackend);
    AssertTrue('Previous forced backend setup should succeed before public ABI rollback forced-success previous-state test',
      TrySetActiveBackend(LPreviousForcedBackend));
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after setting up previous forced backend for rollback forced-success previous-state test', LApi);
    AssertEquals('Public API active backend should reflect the previous forced backend before rollback forced-success previous-state test',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));

    AssertTrue('Requested backend should be registered for public ABI rollback forced-success previous-state test',
      TryGetRegisteredBackendDispatchTable(LRequestedBackend, GPublicAbiHookRollbackForceSuccessTargetTable));
    LTargetTableCaptured := True;

    GPublicAbiHookRollbackForceSuccessHigherCount := 0;
    for LBackend in LDispatchable do
    begin
      if LBackend = LRequestedBackend then
        Break;
      if LBackend = sbScalar then
        Continue;
      AssertTrue('Higher-priority backend should be registered for public ABI rollback forced-success previous-state test',
        TryGetRegisteredBackendDispatchTable(LBackend,
          GPublicAbiHookRollbackForceSuccessHigherTables[GPublicAbiHookRollbackForceSuccessHigherCount]));
      GPublicAbiHookRollbackForceSuccessHigherBackends[GPublicAbiHookRollbackForceSuccessHigherCount] := LBackend;
      Inc(GPublicAbiHookRollbackForceSuccessHigherCount);
    end;
    AssertTrue('Public ABI rollback forced-success previous-state test requires at least one higher-priority backend to suppress',
      GPublicAbiHookRollbackForceSuccessHigherCount > 0);

    GPublicAbiHookRollbackForceSuccessTarget := LRequestedBackend;
    GPublicAbiHookRollbackForceSuccessEnabled := True;
    GPublicAbiHookRollbackForceSuccessStage := 0;
    GPublicAbiHookRollbackForceSuccessInMutation := False;
    AddDispatchChangedHook(@PublicAbiHookRollbackForceSuccessWithoutForcedIntent);
    try
      AssertTrue('TrySetActiveBackend should report success when rollback-time restore reselects the requested backend even if the call started from a different forced backend before public ABI observation',
        TrySetActiveBackend(LRequestedBackend));
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available in rollback forced-success previous-state test', LApi);
      AssertEquals('Return-time public API active backend should switch to the requested backend instead of restoring the previous forced backend in rollback forced-success previous-state test',
        Ord(LRequestedBackend), Integer(LApi^.ActiveBackendId));
      AssertEquals('Synthetic public ABI rollback forced-success previous-state hook should complete all expected stages',
        3, GPublicAbiHookRollbackForceSuccessStage);
      AssertCrossSurfaceCurrentState(
        'TrySetActiveBackend success from previous forced state return-time state',
        LRequestedBackend, False);
    finally
      RemoveDispatchChangedHook(@PublicAbiHookRollbackForceSuccessWithoutForcedIntent);
      GPublicAbiHookRollbackForceSuccessEnabled := False;
      GPublicAbiHookRollbackForceSuccessInMutation := False;
    end;

    for LIndex := 0 to GPublicAbiHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GPublicAbiHookRollbackForceSuccessHigherBackends[LIndex],
        GPublicAbiHookRollbackForceSuccessHigherTables[LIndex]);

    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after restoring higher-priority backends in rollback forced-success previous-state test', LApi);
    AssertEquals('A successful TrySetActiveBackend should keep the requested backend active in public ABI even after higher-priority backends are restored when the call started from a previous forced backend',
      Ord(LRequestedBackend), Integer(LApi^.ActiveBackendId));
    AssertTrue('Public API rollback forced-success previous-state path should not drift back to the pre-call forced backend',
      Integer(LApi^.ActiveBackendId) <> Ord(LPreviousForcedBackend));
    AssertCrossSurfaceCurrentState(
      'TrySetActiveBackend success from previous forced state post-restore state',
      LRequestedBackend, False);
  finally
    if LTargetTableCaptured then
      RegisterBackend(GPublicAbiHookRollbackForceSuccessTarget,
        GPublicAbiHookRollbackForceSuccessTargetTable);
    for LIndex := 0 to GPublicAbiHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GPublicAbiHookRollbackForceSuccessHigherBackends[LIndex],
        GPublicAbiHookRollbackForceSuccessHigherTables[LIndex]);
    GPublicAbiHookRollbackForceSuccessHigherCount := 0;
    GPublicAbiHookRollbackForceSuccessTarget := sbScalar;
    GPublicAbiHookRollbackForceSuccessStage := 0;
    GPublicAbiHookRollbackForceSuccessEnabled := False;
    GPublicAbiHookRollbackForceSuccessInMutation := False;
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_RollbackRestore_Success_FromPreviousForcedState_LateForce_DuringThirdRestore_Preserves_RequestedSelection;
var
  LApi: PFafafaSimdPublicApi;
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LPreviousForcedBackend: TSimdBackend;
  LRequestedBackend: TSimdBackend;
  LBackend: TSimdBackend;
  LOldVectorAsm: Boolean;
  LTargetTableCaptured: Boolean;
  LSelectedCount: Integer;
  LIndex: Integer;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LTargetTableCaptured := False;
  GPublicAbiHookRollbackForceSuccessHigherCount := 0;
  GPublicAbiHookRollbackForceSuccessTarget := sbScalar;
  GPublicAbiHookRollbackForceSuccessTargetTable := Default(TSimdDispatchTable);
  GPublicAbiHookRollbackForceSuccessStage := 0;
  GPublicAbiHookRollbackForceSuccessEnabled := False;
  GPublicAbiHookRollbackForceSuccessInMutation := False;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LDispatchable := GetDispatchableBackendList;
    if Length(LDispatchable) < 3 then
      Exit;

    LAutomaticBackend := GetBestDispatchableBackend;
    LPreviousForcedBackend := sbScalar;
    LRequestedBackend := sbScalar;
    LSelectedCount := 0;
    for LIndex := 0 to High(LDispatchable) do
      if (LDispatchable[LIndex] <> LAutomaticBackend) and (LDispatchable[LIndex] <> sbScalar) then
      begin
        Inc(LSelectedCount);
        if LSelectedCount = 1 then
          LPreviousForcedBackend := LDispatchable[LIndex]
        else
        begin
          LRequestedBackend := LDispatchable[LIndex];
          Break;
        end;
      end;

    if (LPreviousForcedBackend = sbScalar) or (LRequestedBackend = sbScalar) then
      Exit;

    AssertTrue('Previous forced backend should differ from automatic best backend in public ABI rollback forced-success previous-state third-restore test',
      LPreviousForcedBackend <> LAutomaticBackend);
    AssertTrue('Previous forced backend setup should succeed before public ABI rollback forced-success previous-state third-restore test',
      TrySetActiveBackend(LPreviousForcedBackend));
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after setting up previous forced backend for rollback forced-success previous-state third-restore test', LApi);
    AssertEquals('Public API active backend should reflect the previous forced backend before rollback forced-success previous-state third-restore test',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));

    AssertTrue('Requested backend should be registered for public ABI rollback forced-success previous-state third-restore test',
      TryGetRegisteredBackendDispatchTable(LRequestedBackend, GPublicAbiHookRollbackForceSuccessTargetTable));
    LTargetTableCaptured := True;

    GPublicAbiHookRollbackForceSuccessHigherCount := 0;
    for LBackend in LDispatchable do
    begin
      if LBackend = LRequestedBackend then
        Break;
      if LBackend = sbScalar then
        Continue;
      AssertTrue('Higher-priority backend should be registered for public ABI rollback forced-success previous-state third-restore test',
        TryGetRegisteredBackendDispatchTable(LBackend,
          GPublicAbiHookRollbackForceSuccessHigherTables[GPublicAbiHookRollbackForceSuccessHigherCount]));
      GPublicAbiHookRollbackForceSuccessHigherBackends[GPublicAbiHookRollbackForceSuccessHigherCount] := LBackend;
      Inc(GPublicAbiHookRollbackForceSuccessHigherCount);
    end;
    AssertTrue('Public ABI rollback forced-success previous-state third-restore test requires at least one higher-priority backend to suppress',
      GPublicAbiHookRollbackForceSuccessHigherCount > 0);

    GPublicAbiHookRollbackForceSuccessTarget := LRequestedBackend;
    GPublicAbiHookRollbackForceSuccessEnabled := True;
    GPublicAbiHookRollbackForceSuccessStage := 0;
    GPublicAbiHookRollbackForceSuccessInMutation := False;
    AddDispatchChangedHook(@PublicAbiHookRollbackForceSuccessThenLateForceOnThirdRestore);
    try
      AssertTrue('TrySetActiveBackend should still report success when rollback-time restore reselects the requested backend before public ABI third-restore late-force observation even if the call started from a different forced backend',
        TrySetActiveBackend(LRequestedBackend));
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available in rollback forced-success previous-state third-restore test', LApi);
      AssertEquals('Return-time public API active backend should stay on the requested backend instead of drifting back to the previous forced backend during the third forced-intent restore callback',
        Ord(LRequestedBackend), Integer(LApi^.ActiveBackendId));
      AssertEquals('Synthetic public ABI rollback forced-success previous-state third-restore hook should complete all expected stages',
        9, GPublicAbiHookRollbackForceSuccessStage);
      AssertTrue('Public API rollback forced-success previous-state third-restore path should not remain stuck on scalar at return time',
        Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
      AssertTrue('Public API rollback forced-success previous-state third-restore path should not drift back to the pre-call forced backend at return time',
        Integer(LApi^.ActiveBackendId) <> Ord(LPreviousForcedBackend));
      AssertCrossSurfaceCurrentState(
        'TrySetActiveBackend success from previous forced state third-restore return-time state',
        LRequestedBackend, False);
    finally
      RemoveDispatchChangedHook(@PublicAbiHookRollbackForceSuccessThenLateForceOnThirdRestore);
      GPublicAbiHookRollbackForceSuccessEnabled := False;
      GPublicAbiHookRollbackForceSuccessInMutation := False;
    end;

    for LIndex := 0 to GPublicAbiHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GPublicAbiHookRollbackForceSuccessHigherBackends[LIndex],
        GPublicAbiHookRollbackForceSuccessHigherTables[LIndex]);

    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after restoring higher-priority backends in rollback forced-success previous-state third-restore test', LApi);
    AssertEquals('A successful TrySetActiveBackend must keep the requested backend active in public ABI after higher-priority backends are restored from third-restore late-force success path that started from a previous forced backend',
      Ord(LRequestedBackend), Integer(LApi^.ActiveBackendId));
    AssertTrue('Public API rollback forced-success previous-state third-restore path should still not drift back to the pre-call forced backend after higher-priority backends are restored',
      Integer(LApi^.ActiveBackendId) <> Ord(LPreviousForcedBackend));
    AssertCrossSurfaceCurrentState(
      'TrySetActiveBackend success from previous forced state third-restore post-restore state',
      LRequestedBackend, False);
  finally
    if LTargetTableCaptured then
      RegisterBackend(GPublicAbiHookRollbackForceSuccessTarget,
        GPublicAbiHookRollbackForceSuccessTargetTable);
    for LIndex := 0 to GPublicAbiHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GPublicAbiHookRollbackForceSuccessHigherBackends[LIndex],
        GPublicAbiHookRollbackForceSuccessHigherTables[LIndex]);
    GPublicAbiHookRollbackForceSuccessHigherCount := 0;
    GPublicAbiHookRollbackForceSuccessTarget := sbScalar;
    GPublicAbiHookRollbackForceSuccessStage := 0;
    GPublicAbiHookRollbackForceSuccessEnabled := False;
    GPublicAbiHookRollbackForceSuccessInMutation := False;
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_RollbackRestore_Success_FromPreviousForcedState_LateForce_UntilAttemptCap_Restores_PreviousStableState;
var
  LApi: PFafafaSimdPublicApi;
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LPreviousForcedBackend: TSimdBackend;
  LRequestedBackend: TSimdBackend;
  LBackend: TSimdBackend;
  LOldVectorAsm: Boolean;
  LTargetTableCaptured: Boolean;
  LSelectedCount: Integer;
  LIndex: Integer;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LTargetTableCaptured := False;
  GPublicAbiHookRollbackForceSuccessHigherCount := 0;
  GPublicAbiHookRollbackForceSuccessTarget := sbScalar;
  GPublicAbiHookRollbackForceSuccessTargetTable := Default(TSimdDispatchTable);
  GPublicAbiHookRollbackForceSuccessStage := 0;
  GPublicAbiHookRollbackForceSuccessEnabled := False;
  GPublicAbiHookRollbackForceSuccessInMutation := False;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LDispatchable := GetDispatchableBackendList;
    if Length(LDispatchable) < 3 then
      Exit;

    LAutomaticBackend := GetBestDispatchableBackend;
    LPreviousForcedBackend := sbScalar;
    LRequestedBackend := sbScalar;
    LSelectedCount := 0;
    for LIndex := 0 to High(LDispatchable) do
      if (LDispatchable[LIndex] <> LAutomaticBackend) and (LDispatchable[LIndex] <> sbScalar) then
      begin
        Inc(LSelectedCount);
        if LSelectedCount = 1 then
          LPreviousForcedBackend := LDispatchable[LIndex]
        else
        begin
          LRequestedBackend := LDispatchable[LIndex];
          Break;
        end;
      end;

    if (LPreviousForcedBackend = sbScalar) or (LRequestedBackend = sbScalar) then
      Exit;

    AssertTrue('Previous forced backend should differ from automatic best backend in public ABI rollback forced-success attempt-cap test',
      LPreviousForcedBackend <> LAutomaticBackend);
    AssertTrue('Previous forced backend setup should succeed before public ABI rollback forced-success attempt-cap test',
      TrySetActiveBackend(LPreviousForcedBackend));
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after setting up previous forced backend for rollback forced-success attempt-cap test', LApi);
    AssertEquals('Public API active backend should reflect the previous forced backend before rollback forced-success attempt-cap test',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));

    AssertTrue('Requested backend should be registered for public ABI rollback forced-success attempt-cap test',
      TryGetRegisteredBackendDispatchTable(LRequestedBackend, GPublicAbiHookRollbackForceSuccessTargetTable));
    LTargetTableCaptured := True;

    GPublicAbiHookRollbackForceSuccessHigherCount := 0;
    for LBackend in LDispatchable do
    begin
      if LBackend = LRequestedBackend then
        Break;
      if (LBackend = sbScalar) or (LBackend = LPreviousForcedBackend) then
        Continue;
      AssertTrue('Higher-priority backend should be registered for public ABI rollback forced-success attempt-cap test',
        TryGetRegisteredBackendDispatchTable(LBackend,
          GPublicAbiHookRollbackForceSuccessHigherTables[GPublicAbiHookRollbackForceSuccessHigherCount]));
      GPublicAbiHookRollbackForceSuccessHigherBackends[GPublicAbiHookRollbackForceSuccessHigherCount] := LBackend;
      Inc(GPublicAbiHookRollbackForceSuccessHigherCount);
    end;
    AssertTrue('Public ABI rollback forced-success attempt-cap test requires at least one higher-priority backend to suppress',
      GPublicAbiHookRollbackForceSuccessHigherCount > 0);

    GPublicAbiHookRollbackForceSuccessTarget := LRequestedBackend;
    GPublicAbiHookRollbackForceSuccessEnabled := True;
    GPublicAbiHookRollbackForceSuccessStage := 0;
    GPublicAbiHookRollbackForceSuccessInMutation := False;
    AddDispatchChangedHook(@PublicAbiHookRollbackForceSuccessThenLateForceUntilAttemptCap);
    try
      AssertFalse('TrySetActiveBackend should report failure when repeated late scalar re-force exhausts public ABI forced-intent restore attempts after rollback-time reselect',
        TrySetActiveBackend(LRequestedBackend));
      AssertEquals('Synthetic public ABI rollback forced-success attempt-cap hook should also observe the follow-up callback from failure rollback stabilization',
        20, GPublicAbiHookRollbackForceSuccessStage);
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available in rollback forced-success attempt-cap test', LApi);
      AssertEquals('Public API active backend should roll back to the previous forced backend when forced-intent stabilization exhausts the bounded attempt cap',
        Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));
      AssertTrue('Public API rollback forced-success attempt-cap path should not remain stuck on scalar at return time',
        Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
      AssertTrue('Public API rollback forced-success attempt-cap path should not incorrectly keep the requested backend active after failure rollback',
        Integer(LApi^.ActiveBackendId) <> Ord(LRequestedBackend));
      AssertCrossSurfaceCurrentState(
        'TrySetActiveBackend failure after forced-intent attempt-cap exhaustion return-time state',
        LPreviousForcedBackend, False);
    finally
      RemoveDispatchChangedHook(@PublicAbiHookRollbackForceSuccessThenLateForceUntilAttemptCap);
      GPublicAbiHookRollbackForceSuccessEnabled := False;
      GPublicAbiHookRollbackForceSuccessInMutation := False;
    end;

    for LIndex := 0 to GPublicAbiHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GPublicAbiHookRollbackForceSuccessHigherBackends[LIndex],
        GPublicAbiHookRollbackForceSuccessHigherTables[LIndex]);

    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after restoring higher-priority backends in rollback forced-success attempt-cap test', LApi);
    AssertEquals('Restoring higher-priority backends after attempt-cap exhaustion must keep the previous forced backend active in public ABI',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));
    AssertCrossSurfaceCurrentState(
      'TrySetActiveBackend failure after forced-intent attempt-cap exhaustion post-restore state',
      LPreviousForcedBackend, False);
  finally
    if LTargetTableCaptured then
      RegisterBackend(GPublicAbiHookRollbackForceSuccessTarget,
        GPublicAbiHookRollbackForceSuccessTargetTable);
    for LIndex := 0 to GPublicAbiHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GPublicAbiHookRollbackForceSuccessHigherBackends[LIndex],
        GPublicAbiHookRollbackForceSuccessHigherTables[LIndex]);
    GPublicAbiHookRollbackForceSuccessHigherCount := 0;
    GPublicAbiHookRollbackForceSuccessTarget := sbScalar;
    GPublicAbiHookRollbackForceSuccessStage := 0;
    GPublicAbiHookRollbackForceSuccessEnabled := False;
    GPublicAbiHookRollbackForceSuccessInMutation := False;
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_RollbackRestore_Success_FromLowerPriorityPreviousForcedState_LateForce_UntilAttemptCap_Restores_PreviousStableState;
var
  LApi: PFafafaSimdPublicApi;
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LPreviousForcedBackend: TSimdBackend;
  LRequestedBackend: TSimdBackend;
  LBackend: TSimdBackend;
  LOldVectorAsm: Boolean;
  LTargetTableCaptured: Boolean;
  LSelectedCount: Integer;
  LIndex: Integer;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LTargetTableCaptured := False;
  GPublicAbiHookRollbackForceSuccessHigherCount := 0;
  GPublicAbiHookRollbackForceSuccessTarget := sbScalar;
  GPublicAbiHookRollbackForceSuccessTargetTable := Default(TSimdDispatchTable);
  GPublicAbiHookRollbackForceSuccessStage := 0;
  GPublicAbiHookRollbackForceSuccessEnabled := False;
  GPublicAbiHookRollbackForceSuccessInMutation := False;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LDispatchable := GetDispatchableBackendList;
    if Length(LDispatchable) < 3 then
      Exit;

    LAutomaticBackend := GetBestDispatchableBackend;
    LPreviousForcedBackend := sbScalar;
    LRequestedBackend := sbScalar;
    LSelectedCount := 0;
    for LIndex := 0 to High(LDispatchable) do
      if (LDispatchable[LIndex] <> LAutomaticBackend) and (LDispatchable[LIndex] <> sbScalar) then
      begin
        Inc(LSelectedCount);
        if LSelectedCount = 1 then
          LRequestedBackend := LDispatchable[LIndex]
        else
        begin
          LPreviousForcedBackend := LDispatchable[LIndex];
          Break;
        end;
      end;

    if (LPreviousForcedBackend = sbScalar) or (LRequestedBackend = sbScalar) then
      Exit;

    AssertTrue('Previous forced backend setup should succeed before public ABI lower-priority previous-forced success-path attempt-cap test',
      TrySetActiveBackend(LPreviousForcedBackend));
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after setting up lower-priority previous forced backend for success-path attempt-cap test', LApi);
    AssertEquals('Public API active backend should reflect the lower-priority previous forced backend before success-path attempt-cap test',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));

    AssertTrue('Requested backend should be registered for public ABI lower-priority previous-forced success-path attempt-cap test',
      TryGetRegisteredBackendDispatchTable(LRequestedBackend, GPublicAbiHookRollbackForceSuccessTargetTable));
    LTargetTableCaptured := True;

    GPublicAbiHookRollbackForceSuccessHigherCount := 0;
    for LBackend in LDispatchable do
    begin
      if LBackend = LRequestedBackend then
        Break;
      if LBackend = sbScalar then
        Continue;
      AssertTrue('Higher-priority backend should be registered for public ABI lower-priority previous-forced success-path attempt-cap test',
        TryGetRegisteredBackendDispatchTable(LBackend,
          GPublicAbiHookRollbackForceSuccessHigherTables[GPublicAbiHookRollbackForceSuccessHigherCount]));
      GPublicAbiHookRollbackForceSuccessHigherBackends[GPublicAbiHookRollbackForceSuccessHigherCount] := LBackend;
      Inc(GPublicAbiHookRollbackForceSuccessHigherCount);
    end;
    AssertTrue('Public ABI lower-priority previous-forced success-path attempt-cap test requires at least one higher-priority backend to suppress',
      GPublicAbiHookRollbackForceSuccessHigherCount > 0);

    GPublicAbiHookRollbackForceSuccessTarget := LRequestedBackend;
    GPublicAbiHookRollbackForceSuccessEnabled := True;
    GPublicAbiHookRollbackForceSuccessStage := 0;
    GPublicAbiHookRollbackForceSuccessInMutation := False;
    AddDispatchChangedHook(@PublicAbiHookRollbackForceSuccessThenLateForceUntilAttemptCap);
    try
      AssertFalse('TrySetActiveBackend should report failure when repeated late scalar re-force exhausts public ABI forced-intent restore attempts after rollback-time reselect from a lower-priority previous forced backend',
        TrySetActiveBackend(LRequestedBackend));
      AssertEquals('Synthetic public ABI lower-priority previous-forced success-path attempt-cap hook should also observe the follow-up callback from pre-call forced-intent stabilization',
        20, GPublicAbiHookRollbackForceSuccessStage);
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available in lower-priority previous-forced success-path attempt-cap test', LApi);
      AssertEquals('Public API active backend should restore the lower-priority pre-call forced backend when success-path forced-intent stabilization exhausts the bounded attempt cap',
        Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));
      AssertTrue('Public API lower-priority previous-forced success-path attempt-cap path should not remain stuck on scalar at return time',
        Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
      AssertTrue('Public API lower-priority previous-forced success-path attempt-cap path should not incorrectly keep the requested backend active after failure closeout',
        Integer(LApi^.ActiveBackendId) <> Ord(LRequestedBackend));
      AssertCrossSurfaceCurrentState(
        'TrySetActiveBackend lower-priority previous forced success-path attempt-cap return-time state',
        LPreviousForcedBackend, False);
    finally
      RemoveDispatchChangedHook(@PublicAbiHookRollbackForceSuccessThenLateForceUntilAttemptCap);
      GPublicAbiHookRollbackForceSuccessEnabled := False;
      GPublicAbiHookRollbackForceSuccessInMutation := False;
    end;

    for LIndex := 0 to GPublicAbiHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GPublicAbiHookRollbackForceSuccessHigherBackends[LIndex],
        GPublicAbiHookRollbackForceSuccessHigherTables[LIndex]);

    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after restoring higher-priority backends in lower-priority previous-forced success-path attempt-cap test', LApi);
    AssertEquals('Restoring higher-priority backends after lower-priority previous-forced success-path attempt-cap exhaustion must keep the original forced backend active in public ABI',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));
    AssertCrossSurfaceCurrentState(
      'TrySetActiveBackend lower-priority previous forced success-path attempt-cap post-restore state',
      LPreviousForcedBackend, False);
  finally
    if LTargetTableCaptured then
      RegisterBackend(GPublicAbiHookRollbackForceSuccessTarget,
        GPublicAbiHookRollbackForceSuccessTargetTable);
    for LIndex := 0 to GPublicAbiHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GPublicAbiHookRollbackForceSuccessHigherBackends[LIndex],
        GPublicAbiHookRollbackForceSuccessHigherTables[LIndex]);
    GPublicAbiHookRollbackForceSuccessHigherCount := 0;
    GPublicAbiHookRollbackForceSuccessTarget := sbScalar;
    GPublicAbiHookRollbackForceSuccessStage := 0;
    GPublicAbiHookRollbackForceSuccessEnabled := False;
    GPublicAbiHookRollbackForceSuccessInMutation := False;
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_RollbackRestore_Success_LateForce_DuringThirdRestore_Preserves_ForcedSelection;
var
  LApi: PFafafaSimdPublicApi;
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LRequestedBackend: TSimdBackend;
  LBackend: TSimdBackend;
  LOldVectorAsm: Boolean;
  LTargetTableCaptured: Boolean;
  LIndex: Integer;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LTargetTableCaptured := False;
  GPublicAbiHookRollbackForceSuccessHigherCount := 0;
  GPublicAbiHookRollbackForceSuccessTarget := sbScalar;
  GPublicAbiHookRollbackForceSuccessTargetTable := Default(TSimdDispatchTable);
  GPublicAbiHookRollbackForceSuccessStage := 0;
  GPublicAbiHookRollbackForceSuccessEnabled := False;
  GPublicAbiHookRollbackForceSuccessInMutation := False;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LDispatchable := GetDispatchableBackendList;
    if Length(LDispatchable) < 2 then
      Exit;

    LAutomaticBackend := GetBestDispatchableBackend;
    LRequestedBackend := sbScalar;
    for LIndex := High(LDispatchable) downto 0 do
      if (LDispatchable[LIndex] <> sbScalar) and (LDispatchable[LIndex] <> LAutomaticBackend) then
      begin
        LRequestedBackend := LDispatchable[LIndex];
        Break;
      end;
    if LRequestedBackend = sbScalar then
      Exit;

    AssertTrue('Requested backend should be registered for public ABI rollback forced-success third-restore preservation test',
      TryGetRegisteredBackendDispatchTable(LRequestedBackend, GPublicAbiHookRollbackForceSuccessTargetTable));
    LTargetTableCaptured := True;

    GPublicAbiHookRollbackForceSuccessHigherCount := 0;
    for LBackend in LDispatchable do
    begin
      if LBackend = LRequestedBackend then
        Break;
      if LBackend = sbScalar then
        Continue;
      AssertTrue('Higher-priority backend should be registered for public ABI rollback forced-success third-restore preservation test',
        TryGetRegisteredBackendDispatchTable(LBackend,
          GPublicAbiHookRollbackForceSuccessHigherTables[GPublicAbiHookRollbackForceSuccessHigherCount]));
      GPublicAbiHookRollbackForceSuccessHigherBackends[GPublicAbiHookRollbackForceSuccessHigherCount] := LBackend;
      Inc(GPublicAbiHookRollbackForceSuccessHigherCount);
    end;
    AssertTrue('Public ABI rollback forced-success third-restore preservation test requires at least one higher-priority backend to suppress',
      GPublicAbiHookRollbackForceSuccessHigherCount > 0);

    GPublicAbiHookRollbackForceSuccessTarget := LRequestedBackend;
    GPublicAbiHookRollbackForceSuccessEnabled := True;
    GPublicAbiHookRollbackForceSuccessStage := 0;
    GPublicAbiHookRollbackForceSuccessInMutation := False;
    AddDispatchChangedHook(@PublicAbiHookRollbackForceSuccessThenLateForceOnThirdRestore);
    try
      AssertTrue('TrySetActiveBackend should still report success when rollback-time restore reselects the requested backend before public ABI third-restore late-force observation',
        TrySetActiveBackend(LRequestedBackend));
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available in rollback forced-success third-restore preservation test', LApi);
      AssertEquals('Return-time public API active backend should stay on the requested backend even if a late hook re-forces scalar during the third forced-intent restore callback',
        Ord(LRequestedBackend), Integer(LApi^.ActiveBackendId));
      AssertEquals('Synthetic public ABI rollback forced-success third-restore hook should complete all expected stages',
        9, GPublicAbiHookRollbackForceSuccessStage);
      AssertTrue('Public API rollback forced-success third-restore path should not remain stuck on scalar at return time',
        Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
      AssertCrossSurfaceCurrentState(
        'TrySetActiveBackend success third forced-intent restore return-time state',
        LRequestedBackend, False);
    finally
      RemoveDispatchChangedHook(@PublicAbiHookRollbackForceSuccessThenLateForceOnThirdRestore);
      GPublicAbiHookRollbackForceSuccessEnabled := False;
      GPublicAbiHookRollbackForceSuccessInMutation := False;
    end;

    for LIndex := 0 to GPublicAbiHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GPublicAbiHookRollbackForceSuccessHigherBackends[LIndex],
        GPublicAbiHookRollbackForceSuccessHigherTables[LIndex]);

    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after restoring higher-priority backends in third-restore forced-success preservation test', LApi);
    AssertEquals('A successful TrySetActiveBackend must keep the requested backend active in public ABI after higher-priority backends are restored from third-restore late-force success path',
      Ord(LRequestedBackend), Integer(LApi^.ActiveBackendId));
    AssertCrossSurfaceCurrentState(
      'TrySetActiveBackend success third forced-intent restore post-restore state',
      LRequestedBackend, False);
  finally
    if LTargetTableCaptured then
      RegisterBackend(GPublicAbiHookRollbackForceSuccessTarget,
        GPublicAbiHookRollbackForceSuccessTargetTable);
    for LIndex := 0 to GPublicAbiHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GPublicAbiHookRollbackForceSuccessHigherBackends[LIndex],
        GPublicAbiHookRollbackForceSuccessHigherTables[LIndex]);
    GPublicAbiHookRollbackForceSuccessHigherCount := 0;
    GPublicAbiHookRollbackForceSuccessTarget := sbScalar;
    GPublicAbiHookRollbackForceSuccessStage := 0;
    GPublicAbiHookRollbackForceSuccessEnabled := False;
    GPublicAbiHookRollbackForceSuccessInMutation := False;
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_RollbackRestore_Success_LateForce_UntilAttemptCap_Restores_AutomaticIntent;
var
  LApi: PFafafaSimdPublicApi;
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LRequestedBackend: TSimdBackend;
  LBackend: TSimdBackend;
  LOldVectorAsm: Boolean;
  LTargetTableCaptured: Boolean;
  LIndex: Integer;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LTargetTableCaptured := False;
  GPublicAbiHookRollbackForceSuccessHigherCount := 0;
  GPublicAbiHookRollbackForceSuccessTarget := sbScalar;
  GPublicAbiHookRollbackForceSuccessTargetTable := Default(TSimdDispatchTable);
  GPublicAbiHookRollbackForceSuccessStage := 0;
  GPublicAbiHookRollbackForceSuccessEnabled := False;
  GPublicAbiHookRollbackForceSuccessInMutation := False;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LDispatchable := GetDispatchableBackendList;
    if Length(LDispatchable) < 2 then
      Exit;

    LAutomaticBackend := GetBestDispatchableBackend;
    LRequestedBackend := sbScalar;
    for LIndex := High(LDispatchable) downto 0 do
      if (LDispatchable[LIndex] <> sbScalar) and (LDispatchable[LIndex] <> LAutomaticBackend) then
      begin
        LRequestedBackend := LDispatchable[LIndex];
        Break;
      end;
    if LRequestedBackend = sbScalar then
      Exit;

    AssertTrue('Requested backend should be registered for public ABI rollback forced-success automatic-intent attempt-cap test',
      TryGetRegisteredBackendDispatchTable(LRequestedBackend, GPublicAbiHookRollbackForceSuccessTargetTable));
    LTargetTableCaptured := True;

    GPublicAbiHookRollbackForceSuccessHigherCount := 0;
    for LBackend in LDispatchable do
    begin
      if LBackend = LRequestedBackend then
        Break;
      if LBackend = sbScalar then
        Continue;
      AssertTrue('Higher-priority backend should be registered for public ABI rollback forced-success automatic-intent attempt-cap test',
        TryGetRegisteredBackendDispatchTable(LBackend,
          GPublicAbiHookRollbackForceSuccessHigherTables[GPublicAbiHookRollbackForceSuccessHigherCount]));
      GPublicAbiHookRollbackForceSuccessHigherBackends[GPublicAbiHookRollbackForceSuccessHigherCount] := LBackend;
      Inc(GPublicAbiHookRollbackForceSuccessHigherCount);
    end;
    AssertTrue('Public ABI rollback forced-success automatic-intent attempt-cap test requires at least one higher-priority backend to suppress',
      GPublicAbiHookRollbackForceSuccessHigherCount > 0);

    GPublicAbiHookRollbackForceSuccessTarget := LRequestedBackend;
    GPublicAbiHookRollbackForceSuccessEnabled := True;
    GPublicAbiHookRollbackForceSuccessStage := 0;
    GPublicAbiHookRollbackForceSuccessInMutation := False;
    AddDispatchChangedHook(@PublicAbiHookRollbackForceSuccessThenLateForceUntilAttemptCap);
    try
      AssertFalse('TrySetActiveBackend should report failure when repeated late scalar re-force exhausts public ABI forced-intent restore attempts after rollback-time reselect from automatic mode',
        TrySetActiveBackend(LRequestedBackend));
      AssertEquals('Synthetic public ABI rollback forced-success automatic-intent attempt-cap hook should also observe the follow-up callback from automatic-intent stabilization',
        20, GPublicAbiHookRollbackForceSuccessStage);
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available in rollback forced-success automatic-intent attempt-cap test', LApi);
      AssertEquals('Public API active backend should restore automatic intent at return time, which under the hook-suppressed higher backends still means the requested backend remains the current automatic best backend',
        Ord(LRequestedBackend), Integer(LApi^.ActiveBackendId));
      AssertTrue('Public API rollback forced-success automatic-intent attempt-cap path should not remain stuck on scalar at return time',
        Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
      AssertCrossSurfaceCurrentState(
        'TrySetActiveBackend failure after automatic success-path attempt-cap exhaustion return-time state',
        LRequestedBackend, True);
    finally
      RemoveDispatchChangedHook(@PublicAbiHookRollbackForceSuccessThenLateForceUntilAttemptCap);
      GPublicAbiHookRollbackForceSuccessEnabled := False;
      GPublicAbiHookRollbackForceSuccessInMutation := False;
    end;

    for LIndex := 0 to GPublicAbiHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GPublicAbiHookRollbackForceSuccessHigherBackends[LIndex],
        GPublicAbiHookRollbackForceSuccessHigherTables[LIndex]);

    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after restoring higher-priority backends in rollback forced-success automatic-intent attempt-cap test', LApi);
    AssertEquals('Restoring higher-priority backends after automatic success-path attempt-cap exhaustion must drift back to the automatic best backend in public ABI',
      Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
    AssertTrue('Restoring higher-priority backends after automatic success-path attempt-cap exhaustion should not keep the requested backend forced in public ABI',
      Integer(LApi^.ActiveBackendId) <> Ord(LRequestedBackend));
    AssertCrossSurfaceCurrentState(
      'TrySetActiveBackend failure after automatic success-path attempt-cap exhaustion post-restore state',
      LAutomaticBackend, True);
  finally
    if LTargetTableCaptured then
      RegisterBackend(GPublicAbiHookRollbackForceSuccessTarget,
        GPublicAbiHookRollbackForceSuccessTargetTable);
    for LIndex := 0 to GPublicAbiHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GPublicAbiHookRollbackForceSuccessHigherBackends[LIndex],
        GPublicAbiHookRollbackForceSuccessHigherTables[LIndex]);
    GPublicAbiHookRollbackForceSuccessHigherCount := 0;
    GPublicAbiHookRollbackForceSuccessTarget := sbScalar;
    GPublicAbiHookRollbackForceSuccessStage := 0;
    GPublicAbiHookRollbackForceSuccessEnabled := False;
    GPublicAbiHookRollbackForceSuccessInMutation := False;
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_SetActiveBackend_HookLateFailure_Preserves_PreviousForcedBackend;
var
  LApi: PFafafaSimdPublicApi;
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LPreviousForcedBackend: TSimdBackend;
  LRequestedBackend: TSimdBackend;
  LRequestedOriginalTable: TSimdDispatchTable;
  LRequestedTableCaptured: Boolean;
  LSelectedCount: Integer;
  LIndex: Integer;
begin
  LRequestedTableCaptured := False;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LDispatchable := GetDispatchableBackendList;
    if Length(LDispatchable) < 3 then
      Exit;

    LAutomaticBackend := GetBestDispatchableBackend;
    LPreviousForcedBackend := sbScalar;
    LRequestedBackend := sbScalar;
    LSelectedCount := 0;
    for LIndex := 0 to High(LDispatchable) do
      if (LDispatchable[LIndex] <> LAutomaticBackend) and (LDispatchable[LIndex] <> sbScalar) then
      begin
        Inc(LSelectedCount);
        if LSelectedCount = 1 then
          LPreviousForcedBackend := LDispatchable[LIndex]
        else
        begin
          LRequestedBackend := LDispatchable[LIndex];
          Break;
        end;
      end;

    if (LPreviousForcedBackend = sbScalar) or (LRequestedBackend = sbScalar) then
      Exit;

    AssertTrue('Previous forced backend should differ from automatic best backend in public ABI SetActiveBackend late-failure test',
      LPreviousForcedBackend <> LAutomaticBackend);
    AssertTrue('Previous forced backend setup should succeed before public ABI SetActiveBackend late-failure test',
      TrySetActiveBackend(LPreviousForcedBackend));
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after setting up the previous forced backend for SetActiveBackend late-failure test', LApi);
    AssertEquals('Public API active backend should reflect the previous forced backend before SetActiveBackend attempts the failing switch',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));

    AssertTrue('Requested backend should be registered for public ABI SetActiveBackend late-failure test',
      TryGetRegisteredBackendDispatchTable(LRequestedBackend, LRequestedOriginalTable));
    LRequestedTableCaptured := True;
    AssertTrue('Requested backend should start dispatchable before public ABI SetActiveBackend late-failure test',
      IsBackendDispatchable(LRequestedBackend));

    EnablePublicAbiDisableBackendHook(LRequestedBackend, LRequestedOriginalTable);
    try
      SetActiveBackend(LRequestedBackend);
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available after SetActiveBackend late failure', LApi);
      AssertEquals('Public API active backend should preserve the previous forced backend when SetActiveBackend hits a late hook-driven failure',
        Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));
      AssertEquals('Public API active backend should keep tracking the actual current backend after SetActiveBackend late failure',
        Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
      AssertTrue('Public API active backend should not silently drop to scalar fallback while a previous forced backend exists',
        Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
    finally
      DisablePublicAbiDisableBackendHook;
    end;

    RegisterBackend(LRequestedBackend, LRequestedOriginalTable);
    LRequestedTableCaptured := False;
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after restoring the requested backend table in SetActiveBackend late-failure test', LApi);
    AssertEquals('Restoring the requested backend table after SetActiveBackend late failure must keep the previous forced backend active in public ABI',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));
  finally
    if LRequestedTableCaptured then
      RegisterBackend(LRequestedBackend, LRequestedOriginalTable);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_RollbackRestore_LateForce_Restores_AutomaticBackend;
var
  LApi: PFafafaSimdPublicApi;
  LAutomaticBackend: TSimdBackend;
  LRequestedBackend: TSimdBackend;
  LDispatchable: TSimdBackendArray;
  LOriginalTable: TSimdDispatchTable;
  LRequestedTableCaptured: Boolean;
  LIndex: Integer;
begin
  LRequestedTableCaptured := False;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LAutomaticBackend := GetActiveBackend;
    if LAutomaticBackend = sbScalar then
      Exit;

    AssertEquals('Automatic selection should start from best dispatchable backend before public ABI automatic rollback late-force test',
      Ord(LAutomaticBackend), Ord(GetBestDispatchableBackend));

    LRequestedBackend := sbScalar;
    LDispatchable := GetDispatchableBackendList;
    for LIndex := 0 to High(LDispatchable) do
      if (LDispatchable[LIndex] <> LAutomaticBackend) and (LDispatchable[LIndex] <> sbScalar) then
      begin
        LRequestedBackend := LDispatchable[LIndex];
        Break;
      end;

    if LRequestedBackend = sbScalar then
      Exit;

    AssertTrue('Requested backend should be registered for public ABI automatic rollback late-force test',
      TryGetRegisteredBackendDispatchTable(LRequestedBackend, LOriginalTable));
    LRequestedTableCaptured := True;
    AssertTrue('Requested backend should start dispatchable before public ABI automatic rollback late-force test',
      IsBackendDispatchable(LRequestedBackend));

    GPublicAbiHookAutomaticRollbackLateForceRequestedBackend := LRequestedBackend;
    GPublicAbiHookAutomaticRollbackLateForceRequestedTable := LOriginalTable;
    GPublicAbiHookAutomaticRollbackLateForceEnabled := True;
    GPublicAbiHookAutomaticRollbackLateForceStage := 0;
    AddDispatchChangedHook(@PublicAbiHookDisableRequestedThenLateForceOnAutomaticRestore);
    try
      AssertFalse('TrySetActiveBackend should still report failure when requested backend is disabled before public ABI automatic rollback late-force observation',
        TrySetActiveBackend(LRequestedBackend));
      AssertEquals('Synthetic public ABI automatic rollback late-force hook should run through the full callback sequence',
        5, GPublicAbiHookAutomaticRollbackLateForceStage);
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available after automatic rollback late-force test', LApi);
      AssertEquals('Public API active backend should restore the automatic best backend even if a late hook re-forces scalar during rollback',
        Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
      AssertEquals('Public API active backend should keep tracking the actual current backend after automatic rollback late-force test',
        Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
      AssertTrue('Public API automatic rollback late-force path should not remain stuck on scalar when a better automatic backend exists',
        Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
    finally
      RemoveDispatchChangedHook(@PublicAbiHookDisableRequestedThenLateForceOnAutomaticRestore);
      GPublicAbiHookAutomaticRollbackLateForceEnabled := False;
      GPublicAbiHookAutomaticRollbackLateForceStage := 0;
      GPublicAbiHookAutomaticRollbackLateForceRequestedBackend := sbScalar;
    end;

    RegisterBackend(LRequestedBackend, LOriginalTable);
    LRequestedTableCaptured := False;
    AssertTrue('Requested backend should become dispatchable again after restoring its original table in public ABI automatic rollback late-force test',
      IsBackendDispatchable(LRequestedBackend));
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after restoring requested backend table in automatic rollback late-force test', LApi);
    AssertEquals('Restoring the requested backend table after automatic rollback late-force failure must keep automatic best backend active in public ABI',
      Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
  finally
    if LRequestedTableCaptured then
      RegisterBackend(LRequestedBackend, LOriginalTable);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_RollbackRestore_LateForce_DuringRestore_Restores_AutomaticBackend;
var
  LApi: PFafafaSimdPublicApi;
  LAutomaticBackend: TSimdBackend;
  LRequestedBackend: TSimdBackend;
  LDispatchable: TSimdBackendArray;
  LOriginalTable: TSimdDispatchTable;
  LRequestedTableCaptured: Boolean;
  LIndex: Integer;
begin
  LRequestedTableCaptured := False;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LAutomaticBackend := GetActiveBackend;
    if LAutomaticBackend = sbScalar then
      Exit;

    AssertEquals('Automatic selection should start from best dispatchable backend before public ABI automatic rollback restore-callback late-force test',
      Ord(LAutomaticBackend), Ord(GetBestDispatchableBackend));

    LRequestedBackend := sbScalar;
    LDispatchable := GetDispatchableBackendList;
    for LIndex := 0 to High(LDispatchable) do
      if (LDispatchable[LIndex] <> LAutomaticBackend) and (LDispatchable[LIndex] <> sbScalar) then
      begin
        LRequestedBackend := LDispatchable[LIndex];
        Break;
      end;

    if LRequestedBackend = sbScalar then
      Exit;

    AssertTrue('Requested backend should be registered for public ABI automatic rollback restore-callback late-force test',
      TryGetRegisteredBackendDispatchTable(LRequestedBackend, LOriginalTable));
    LRequestedTableCaptured := True;
    AssertTrue('Requested backend should start dispatchable before public ABI automatic rollback restore-callback late-force test',
      IsBackendDispatchable(LRequestedBackend));

    GPublicAbiHookAutomaticRollbackRestoreLateForceRequestedBackend := LRequestedBackend;
    GPublicAbiHookAutomaticRollbackRestoreLateForceRequestedTable := LOriginalTable;
    GPublicAbiHookAutomaticRollbackRestoreLateForceEnabled := True;
    GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 0;
    AddDispatchChangedHook(@PublicAbiHookDisableRequestedThenLateForceOnAutomaticRestoreTwice);
    try
      AssertFalse('TrySetActiveBackend should still report failure when requested backend is disabled before public ABI automatic rollback restore-callback late-force observation',
        TrySetActiveBackend(LRequestedBackend));
      AssertEquals('Synthetic public ABI automatic rollback restore-callback late-force hook should run through the full callback sequence',
        7, GPublicAbiHookAutomaticRollbackRestoreLateForceStage);
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available after automatic rollback restore-callback late-force test', LApi);
      AssertEquals('Public API active backend should still restore automatic best backend even if a late hook re-forces scalar during rollback restore callback',
        Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
      AssertEquals('Public API active backend should keep tracking the actual current backend after automatic rollback restore-callback late-force test',
        Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
      AssertTrue('Public API automatic rollback restore-callback late-force path should not remain stuck on scalar when a better automatic backend exists',
        Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
    finally
      RemoveDispatchChangedHook(@PublicAbiHookDisableRequestedThenLateForceOnAutomaticRestoreTwice);
      GPublicAbiHookAutomaticRollbackRestoreLateForceEnabled := False;
      GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 0;
      GPublicAbiHookAutomaticRollbackRestoreLateForceRequestedBackend := sbScalar;
    end;

    RegisterBackend(LRequestedBackend, LOriginalTable);
    LRequestedTableCaptured := False;
    AssertTrue('Requested backend should become dispatchable again after restoring its original table in public ABI automatic rollback restore-callback late-force test',
      IsBackendDispatchable(LRequestedBackend));
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after restoring requested backend table in automatic rollback restore-callback late-force test', LApi);
    AssertEquals('Restoring the requested backend table after automatic rollback restore-callback late-force failure must keep automatic best backend active in public ABI',
      Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
  finally
    if LRequestedTableCaptured then
      RegisterBackend(LRequestedBackend, LOriginalTable);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_RollbackRestore_LateForce_DuringThirdRestore_Restores_AutomaticBackend;
var
  LApi: PFafafaSimdPublicApi;
  LAutomaticBackend: TSimdBackend;
  LRequestedBackend: TSimdBackend;
  LDispatchable: TSimdBackendArray;
  LOriginalTable: TSimdDispatchTable;
  LOldVectorAsm: Boolean;
  LRequestedTableCaptured: Boolean;
  LIndex: Integer;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LRequestedTableCaptured := False;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LAutomaticBackend := GetActiveBackend;
    if LAutomaticBackend = sbScalar then
      Exit;

    AssertEquals('Automatic selection should start from best dispatchable backend before public ABI automatic rollback third-restore late-force test',
      Ord(LAutomaticBackend), Ord(GetBestDispatchableBackend));

    LRequestedBackend := sbScalar;
    LDispatchable := GetDispatchableBackendList;
    for LIndex := 0 to High(LDispatchable) do
      if (LDispatchable[LIndex] <> LAutomaticBackend) and (LDispatchable[LIndex] <> sbScalar) then
      begin
        LRequestedBackend := LDispatchable[LIndex];
        Break;
      end;

    if LRequestedBackend = sbScalar then
      Exit;

    AssertTrue('Requested backend should be registered for public ABI automatic rollback third-restore late-force test',
      TryGetRegisteredBackendDispatchTable(LRequestedBackend, LOriginalTable));
    LRequestedTableCaptured := True;
    AssertTrue('Requested backend should start dispatchable before public ABI automatic rollback third-restore late-force test',
      IsBackendDispatchable(LRequestedBackend));

    GPublicAbiHookAutomaticRollbackRestoreLateForceRequestedBackend := LRequestedBackend;
    GPublicAbiHookAutomaticRollbackRestoreLateForceRequestedTable := LOriginalTable;
    GPublicAbiHookAutomaticRollbackRestoreLateForceEnabled := True;
    GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 0;
    AddDispatchChangedHook(@PublicAbiHookDisableRequestedThenLateForceOnAutomaticThirdRestore);
    try
      AssertFalse('TrySetActiveBackend should still report failure when requested backend is disabled before public ABI automatic rollback third-restore late-force observation',
        TrySetActiveBackend(LRequestedBackend));
      AssertEquals('Synthetic public ABI automatic rollback third-restore late-force hook should run through the full callback sequence',
        7, GPublicAbiHookAutomaticRollbackRestoreLateForceStage);
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available after automatic rollback third-restore late-force test', LApi);
      AssertEquals('Public API active backend should still restore automatic best backend even if a late hook re-forces scalar during the third rollback restore callback',
        Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
      AssertEquals('Public API active backend should keep tracking the actual current backend after automatic rollback third-restore late-force test',
        Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
      AssertTrue('Public API automatic rollback third-restore late-force path should not remain stuck on scalar when a better automatic backend exists',
        Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
      AssertCrossSurfaceCurrentState(
        'TrySetActiveBackend automatic rollback third restore return-time state',
        LAutomaticBackend, True);
    finally
      RemoveDispatchChangedHook(@PublicAbiHookDisableRequestedThenLateForceOnAutomaticThirdRestore);
      GPublicAbiHookAutomaticRollbackRestoreLateForceEnabled := False;
      GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 0;
      GPublicAbiHookAutomaticRollbackRestoreLateForceRequestedBackend := sbScalar;
    end;

    RegisterBackend(LRequestedBackend, LOriginalTable);
    AssertTrue('Requested backend should become dispatchable again after restoring its original table in public ABI automatic rollback third-restore late-force test',
      IsBackendDispatchable(LRequestedBackend));
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after restoring requested backend table in automatic rollback third-restore late-force test', LApi);
    AssertEquals('Restoring the requested backend table after automatic rollback third-restore late-force failure must keep automatic best backend active in public ABI',
      Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
  finally
    if LRequestedTableCaptured then
      RegisterBackend(LRequestedBackend, LOriginalTable);
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_RollbackRestore_LateForce_Preserves_PreviousForcedBackend;
var
  LApi: PFafafaSimdPublicApi;
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LPreviousForcedBackend: TSimdBackend;
  LRequestedBackend: TSimdBackend;
  LRequestedOriginalTable: TSimdDispatchTable;
  LRequestedTableCaptured: Boolean;
  LSelectedCount: Integer;
  LIndex: Integer;
begin
  LRequestedTableCaptured := False;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LDispatchable := GetDispatchableBackendList;
    if Length(LDispatchable) < 3 then
      Exit;

    LAutomaticBackend := GetBestDispatchableBackend;
    LPreviousForcedBackend := sbScalar;
    LRequestedBackend := sbScalar;
    LSelectedCount := 0;
    for LIndex := 0 to High(LDispatchable) do
      if (LDispatchable[LIndex] <> LAutomaticBackend) and (LDispatchable[LIndex] <> sbScalar) then
      begin
        Inc(LSelectedCount);
        if LSelectedCount = 1 then
          LPreviousForcedBackend := LDispatchable[LIndex]
        else
        begin
          LRequestedBackend := LDispatchable[LIndex];
          Break;
        end;
      end;

    if (LPreviousForcedBackend = sbScalar) or (LRequestedBackend = sbScalar) then
      Exit;

    AssertTrue('Previous forced backend should differ from automatic best backend in public ABI rollback late-force test',
      LPreviousForcedBackend <> LAutomaticBackend);
    AssertTrue('Previous forced backend setup should succeed before public ABI rollback late-force test',
      TrySetActiveBackend(LPreviousForcedBackend));
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after setting up previous forced backend for rollback late-force test', LApi);
    AssertEquals('Public API active backend should reflect the previous forced backend before rollback late-force test',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));

    AssertTrue('Requested backend should be registered for public ABI rollback late-force test',
      TryGetRegisteredBackendDispatchTable(LRequestedBackend, LRequestedOriginalTable));
    LRequestedTableCaptured := True;
    AssertTrue('Requested backend should start dispatchable before public ABI rollback late-force test',
      IsBackendDispatchable(LRequestedBackend));

    GPublicAbiHookRollbackLateForceRequestedBackend := LRequestedBackend;
    GPublicAbiHookRollbackLateForceRequestedTable := LRequestedOriginalTable;
    GPublicAbiHookRollbackLateForceEnabled := True;
    GPublicAbiHookRollbackLateForceStage := 0;
    AddDispatchChangedHook(@PublicAbiHookDisableRequestedThenLateForceOnPreviousRestore);
    try
      AssertFalse('TrySetActiveBackend should still report failure when requested backend is disabled by hook before public ABI rollback late-force observation',
        TrySetActiveBackend(LRequestedBackend));
      AssertEquals('Synthetic public ABI rollback late-force hook should run through the full callback sequence',
        6, GPublicAbiHookRollbackLateForceStage);
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available after rollback late-force test', LApi);
      AssertEquals('Public API active backend should preserve the previous forced backend even if a late hook re-forces scalar during rollback restore',
        Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));
      AssertEquals('Public API active backend should keep tracking the actual current backend after rollback late-force test',
        Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
      AssertTrue('Public API active backend should not remain stuck on scalar after rollback late-force test',
        Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
    finally
      RemoveDispatchChangedHook(@PublicAbiHookDisableRequestedThenLateForceOnPreviousRestore);
      GPublicAbiHookRollbackLateForceEnabled := False;
      GPublicAbiHookRollbackLateForceStage := 0;
      GPublicAbiHookRollbackLateForceRequestedBackend := sbScalar;
    end;

    RegisterBackend(LRequestedBackend, LRequestedOriginalTable);
    LRequestedTableCaptured := False;
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after restoring requested backend table in rollback late-force test', LApi);
    AssertEquals('Restoring the requested backend table after rollback late-force failure must keep the previous forced backend active in public ABI',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));
  finally
    if LRequestedTableCaptured then
      RegisterBackend(LRequestedBackend, LRequestedOriginalTable);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_RollbackRestore_LateForce_DuringThirdRestore_Preserves_PreviousForcedBackend;
var
  LApi: PFafafaSimdPublicApi;
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LPreviousForcedBackend: TSimdBackend;
  LRequestedBackend: TSimdBackend;
  LRequestedOriginalTable: TSimdDispatchTable;
  LOldVectorAsm: Boolean;
  LRequestedTableCaptured: Boolean;
  LSelectedCount: Integer;
  LIndex: Integer;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LRequestedTableCaptured := False;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LDispatchable := GetDispatchableBackendList;
    if Length(LDispatchable) < 3 then
      Exit;

    LAutomaticBackend := GetBestDispatchableBackend;
    LPreviousForcedBackend := sbScalar;
    LRequestedBackend := sbScalar;
    LSelectedCount := 0;
    for LIndex := 0 to High(LDispatchable) do
      if (LDispatchable[LIndex] <> LAutomaticBackend) and (LDispatchable[LIndex] <> sbScalar) then
      begin
        Inc(LSelectedCount);
        if LSelectedCount = 1 then
          LPreviousForcedBackend := LDispatchable[LIndex]
        else
        begin
          LRequestedBackend := LDispatchable[LIndex];
          Break;
        end;
      end;

    if (LPreviousForcedBackend = sbScalar) or (LRequestedBackend = sbScalar) then
      Exit;

    AssertTrue('Previous forced backend should differ from automatic best backend in public ABI rollback third-restore late-force test',
      LPreviousForcedBackend <> LAutomaticBackend);
    AssertTrue('Previous forced backend setup should succeed before public ABI rollback third-restore late-force test',
      TrySetActiveBackend(LPreviousForcedBackend));
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after setting up previous forced backend for rollback third-restore late-force test', LApi);
    AssertEquals('Public API active backend should reflect the previous forced backend before rollback third-restore late-force test',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));

    AssertTrue('Requested backend should be registered for public ABI rollback third-restore late-force test',
      TryGetRegisteredBackendDispatchTable(LRequestedBackend, LRequestedOriginalTable));
    LRequestedTableCaptured := True;
    AssertTrue('Requested backend should start dispatchable before public ABI rollback third-restore late-force test',
      IsBackendDispatchable(LRequestedBackend));

    GPublicAbiHookRollbackLateForceRequestedBackend := LRequestedBackend;
    GPublicAbiHookRollbackLateForceRequestedTable := LRequestedOriginalTable;
    GPublicAbiHookRollbackLateForceEnabled := True;
    GPublicAbiHookRollbackLateForceStage := 0;
    AddDispatchChangedHook(@PublicAbiHookDisableRequestedThenLateForceOnPreviousThirdRestore);
    try
      AssertFalse('TrySetActiveBackend should still report failure when requested backend is disabled by hook before public ABI rollback third-restore late-force observation',
        TrySetActiveBackend(LRequestedBackend));
      AssertEquals('Synthetic public ABI rollback third-restore late-force hook should run through the full callback sequence',
        10, GPublicAbiHookRollbackLateForceStage);
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available after rollback third-restore late-force test', LApi);
      AssertEquals('Public API active backend should preserve the previous forced backend even if a late hook re-forces scalar during the third rollback restore callback',
        Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));
      AssertEquals('Public API active backend should keep tracking the actual current backend after rollback third-restore late-force test',
        Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
      AssertTrue('Public API rollback third-restore late-force path should not remain stuck on scalar at return time',
        Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
      AssertTrue('Public API rollback third-restore late-force path should not silently drift to automatic best backend when a previous forced backend exists',
        Integer(LApi^.ActiveBackendId) <> Ord(LAutomaticBackend));
      AssertCrossSurfaceCurrentState(
        'TrySetActiveBackend rollback third restore previous forced backend return-time state',
        LPreviousForcedBackend, False);
    finally
      RemoveDispatchChangedHook(@PublicAbiHookDisableRequestedThenLateForceOnPreviousThirdRestore);
      GPublicAbiHookRollbackLateForceEnabled := False;
      GPublicAbiHookRollbackLateForceStage := 0;
      GPublicAbiHookRollbackLateForceRequestedBackend := sbScalar;
    end;

    RegisterBackend(LRequestedBackend, LRequestedOriginalTable);
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after restoring requested backend table in rollback third-restore late-force test', LApi);
    AssertEquals('Restoring the requested backend table after rollback third-restore late-force failure must keep the previous forced backend active in public ABI',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));
    AssertCrossSurfaceCurrentState(
      'TrySetActiveBackend rollback third restore previous forced backend post-restore state',
      LPreviousForcedBackend, False);
  finally
    if LRequestedTableCaptured then
      RegisterBackend(LRequestedBackend, LRequestedOriginalTable);
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_ResetToAutomaticBackend_HookLateForce_Restores_AutomaticBackend;
var
  LApi: PFafafaSimdPublicApi;
  LAutomaticBackend: TSimdBackend;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LAutomaticBackend := GetBestDispatchableBackend;
  if LAutomaticBackend = sbScalar then
    Exit;

  AssertTrue('Scalar force setup should succeed before public ABI ResetToAutomaticBackend late-force test',
    TrySetActiveBackend(sbScalar));
  LApi := GetSimdPublicApi;
  AssertNotNull('Public API table should remain available after scalar force setup for ResetToAutomaticBackend late-force test', LApi);
  AssertEquals('Public API active backend should reflect scalar before ResetToAutomaticBackend late-force test',
    Ord(sbScalar), Integer(LApi^.ActiveBackendId));

  GPublicAbiHookReForceBackendTarget := sbScalar;
  GPublicAbiHookReForceBackendEnabled := True;
  GPublicAbiHookReForceBackendStage := 0;
  AddDispatchChangedHook(@PublicAbiHookReForceBackendOnce);
  try
    ResetToAutomaticBackend;
    AssertEquals('Synthetic public ABI late-force hook should run through the real ResetToAutomaticBackend callback sequence',
      2, GPublicAbiHookReForceBackendStage);
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after ResetToAutomaticBackend late-force test', LApi);
    AssertEquals('Public API active backend should restore automatic best backend even if a late hook re-forces scalar during reset',
      Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
    AssertEquals('Public API active backend should keep tracking the actual current backend after ResetToAutomaticBackend late-force test',
      Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
    AssertTrue('Public API active backend should not remain stuck on scalar after ResetToAutomaticBackend late-force test',
      Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
  finally
    RemoveDispatchChangedHook(@PublicAbiHookReForceBackendOnce);
    GPublicAbiHookReForceBackendEnabled := False;
    GPublicAbiHookReForceBackendStage := 0;
    GPublicAbiHookReForceBackendTarget := sbScalar;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_RollbackRestore_LateForce_UntilAttemptCap_Restores_AutomaticBackend;
var
  LApi: PFafafaSimdPublicApi;
  LAutomaticBackend: TSimdBackend;
  LRequestedBackend: TSimdBackend;
  LDispatchable: TSimdBackendArray;
  LOriginalTable: TSimdDispatchTable;
  LOldVectorAsm: Boolean;
  LRequestedTableCaptured: Boolean;
  LIndex: Integer;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LRequestedTableCaptured := False;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LAutomaticBackend := GetActiveBackend;
    if LAutomaticBackend = sbScalar then
      Exit;

    AssertEquals('Automatic selection should start from best dispatchable backend before public ABI automatic rollback attempt-cap late-force test',
      Ord(LAutomaticBackend), Ord(GetBestDispatchableBackend));

    LRequestedBackend := sbScalar;
    LDispatchable := GetDispatchableBackendList;
    for LIndex := 0 to High(LDispatchable) do
      if (LDispatchable[LIndex] <> LAutomaticBackend) and (LDispatchable[LIndex] <> sbScalar) then
      begin
        LRequestedBackend := LDispatchable[LIndex];
        Break;
      end;

    if LRequestedBackend = sbScalar then
      Exit;

    AssertTrue('Requested backend should be registered for public ABI automatic rollback attempt-cap late-force test',
      TryGetRegisteredBackendDispatchTable(LRequestedBackend, LOriginalTable));
    LRequestedTableCaptured := True;
    AssertTrue('Requested backend should start dispatchable before public ABI automatic rollback attempt-cap late-force test',
      IsBackendDispatchable(LRequestedBackend));

    GPublicAbiHookAutomaticRollbackRestoreLateForceRequestedBackend := LRequestedBackend;
    GPublicAbiHookAutomaticRollbackRestoreLateForceRequestedTable := LOriginalTable;
    GPublicAbiHookAutomaticRollbackRestoreLateForceEnabled := True;
    GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 0;
    AddDispatchChangedHook(@PublicAbiHookDisableRequestedThenLateForceOnAutomaticRestoreUntilAttemptCap);
    try
      AssertFalse('TrySetActiveBackend should still report failure when requested backend is disabled before public ABI automatic rollback attempt-cap late-force observation',
        TrySetActiveBackend(LRequestedBackend));
      AssertEquals('Synthetic public ABI automatic rollback attempt-cap late-force hook should also observe the follow-up callback from post-cap automatic stabilization',
        20, GPublicAbiHookAutomaticRollbackRestoreLateForceStage);
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available after automatic rollback attempt-cap late-force test', LApi);
      AssertEquals('Public API active backend should still restore automatic best backend after rollback restore attempts are exhausted by repeated late scalar force',
        Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
      AssertEquals('Public API active backend should keep tracking the actual current backend after automatic rollback attempt-cap late-force test',
        Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
      AssertTrue('Public API automatic rollback attempt-cap late-force path should not remain stuck on scalar when a better automatic backend exists',
        Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
      AssertCrossSurfaceCurrentState(
        'TrySetActiveBackend automatic rollback attempt-cap return-time state',
        LAutomaticBackend, True);
    finally
      RemoveDispatchChangedHook(@PublicAbiHookDisableRequestedThenLateForceOnAutomaticRestoreUntilAttemptCap);
      GPublicAbiHookAutomaticRollbackRestoreLateForceEnabled := False;
      GPublicAbiHookAutomaticRollbackRestoreLateForceStage := 0;
      GPublicAbiHookAutomaticRollbackRestoreLateForceRequestedBackend := sbScalar;
    end;

    RegisterBackend(LRequestedBackend, LOriginalTable);
    AssertTrue('Requested backend should become dispatchable again after restoring its original table in public ABI automatic rollback attempt-cap late-force test',
      IsBackendDispatchable(LRequestedBackend));
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after restoring requested backend table in automatic rollback attempt-cap late-force test', LApi);
    AssertEquals('Restoring the requested backend table after automatic rollback attempt-cap late-force failure must keep automatic best backend active in public ABI',
      Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
    AssertCrossSurfaceCurrentState(
      'TrySetActiveBackend automatic rollback attempt-cap post-restore state',
      LAutomaticBackend, True);
  finally
    if LRequestedTableCaptured then
      RegisterBackend(LRequestedBackend, LOriginalTable);
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_Refreshes_WhenVectorAsmDisabled_ReSelects_Away_From_ScalarBacked_CurrentBackend;
var
  LApi: PFafafaSimdPublicApi;
  LOriginalBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LOriginalInfo: TFafafaSimdBackendPodInfo;
  LActiveInfo: TFafafaSimdBackendPodInfo;

  function IsScalarBackedForRepresentativeSlots(const aBackendTable, aScalarTable: TSimdDispatchTable): Boolean;
  begin
    Result :=
      (Pointer(aBackendTable.AddF32x4) = Pointer(aScalarTable.AddF32x4)) and
      (Pointer(aBackendTable.MulF32x4) = Pointer(aScalarTable.MulF32x4)) and
      (Pointer(aBackendTable.AddI32x4) = Pointer(aScalarTable.AddI32x4)) and
      (Pointer(aBackendTable.SelectF32x4) = Pointer(aScalarTable.SelectF32x4));
  end;
begin
  ResetToAutomaticBackend;
  LOriginalBackend := GetCurrentBackend;
  if LOriginalBackend = sbScalar then
    Exit;

  AssertTrue('Original active backend should be registered',
    TryGetRegisteredBackendDispatchTable(LOriginalBackend, LOriginalTable));
  AssertTrue('Scalar dispatch table should be registered',
    TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable));

  GetDispatchTable;
  SetVectorAsmEnabled(True);
  SetVectorAsmEnabled(False);
  AssertFalse('Vector asm should be disabled for public ABI reselection test', IsVectorAsmEnabled);

  AssertTrue('Original active backend should remain registered after runtime rebuild',
    TryGetRegisteredBackendDispatchTable(LOriginalBackend, LOriginalTable));

  if not IsScalarBackedForRepresentativeSlots(LOriginalTable, LScalarTable) then
    Exit;

  LApi := GetSimdPublicApi;
  AssertNotNull('Public API table should not be nil after vector asm disable', LApi);
  AssertEquals('Public API active backend should track current backend after vector asm disable',
    Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
  AssertTrue('Vector-asm-disabled reselection should move away from scalar-backed original backend',
    GetCurrentBackend <> LOriginalBackend);

  AssertTrue('Original backend pod info should remain queryable after vector asm disable',
    TryGetSimdBackendPodInfo(LOriginalBackend, LOriginalInfo));
  AssertTrue('Original backend should remain CPU-supported after vector asm disable',
    (LOriginalInfo.Flags and FAF_SIMD_ABI_FLAG_SUPPORTED_ON_CPU) <> 0);
  AssertTrue('Original backend should remain registered after vector asm disable',
    (LOriginalInfo.Flags and FAF_SIMD_ABI_FLAG_REGISTERED) <> 0);
  AssertTrue('Original backend should lose dispatchable bit after becoming scalar-backed',
    (LOriginalInfo.Flags and FAF_SIMD_ABI_FLAG_DISPATCHABLE) = 0);
  AssertTrue('Original backend should lose active bit after reselection',
    (LOriginalInfo.Flags and FAF_SIMD_ABI_FLAG_ACTIVE) = 0);

  AssertTrue('New active backend pod info should be queryable after vector asm disable',
    TryGetSimdBackendPodInfo(GetCurrentBackend, LActiveInfo));
  AssertEquals('Public API active flags should match the new active backend pod flags',
    LActiveInfo.Flags, LApi^.ActiveFlags);
  AssertTrue('Public API active flags should keep active bit after reselection',
    (LApi^.ActiveFlags and FAF_SIMD_ABI_FLAG_ACTIVE) <> 0);
  AssertTrue('Public API active flags should keep dispatchable bit after reselection',
    (LApi^.ActiveFlags and FAF_SIMD_ABI_FLAG_DISPATCHABLE) <> 0);
end;

procedure TTestCase_PublicAbi.Test_PublicApi_ResetToAutomaticBackend_HookLateForce_DuringRestore_Restores_AutomaticBackend;
var
  LApi: PFafafaSimdPublicApi;
  LAutomaticBackend: TSimdBackend;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LAutomaticBackend := GetBestDispatchableBackend;
  if LAutomaticBackend = sbScalar then
    Exit;

  AssertTrue('Scalar force setup should succeed before public ABI ResetToAutomaticBackend restore-callback late-force test',
    TrySetActiveBackend(sbScalar));
  LApi := GetSimdPublicApi;
  AssertNotNull('Public API table should remain available after scalar force setup for ResetToAutomaticBackend restore-callback late-force test', LApi);
  AssertEquals('Public API active backend should reflect scalar before ResetToAutomaticBackend restore-callback late-force test',
    Ord(sbScalar), Integer(LApi^.ActiveBackendId));

  GPublicAbiHookResetLateForceTarget := sbScalar;
  GPublicAbiHookResetLateForceEnabled := True;
  GPublicAbiHookResetLateForceStage := 0;
  AddDispatchChangedHook(@PublicAbiHookReForceBackendOnAutomaticRestore);
  try
    ResetToAutomaticBackend;
    AssertEquals('Synthetic public ABI second-late-force hook should run through the full ResetToAutomaticBackend callback sequence',
      5, GPublicAbiHookResetLateForceStage);
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after ResetToAutomaticBackend restore-callback late-force test', LApi);
    AssertEquals('Public API active backend should still restore automatic best backend even if a late hook re-forces scalar during restore callback',
      Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
    AssertEquals('Public API active backend should keep tracking the actual current backend after ResetToAutomaticBackend restore-callback late-force test',
      Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
    AssertTrue('Public API reset restore-callback late-force path should not remain stuck on scalar when a better automatic backend exists',
      Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
  finally
    RemoveDispatchChangedHook(@PublicAbiHookReForceBackendOnAutomaticRestore);
    GPublicAbiHookResetLateForceEnabled := False;
    GPublicAbiHookResetLateForceStage := 0;
    GPublicAbiHookResetLateForceTarget := sbScalar;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_ResetToAutomaticBackend_HookLateForce_DuringThirdRestore_Restores_AutomaticBackend;
var
  LApi: PFafafaSimdPublicApi;
  LAutomaticBackend: TSimdBackend;
  LOldVectorAsm: Boolean;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LAutomaticBackend := GetBestDispatchableBackend;
    if LAutomaticBackend = sbScalar then
      Exit;

    AssertTrue('Scalar force setup should succeed before public ABI ResetToAutomaticBackend third-restore late-force test',
      TrySetActiveBackend(sbScalar));
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after scalar force setup for ResetToAutomaticBackend third-restore late-force test', LApi);
    AssertEquals('Public API active backend should reflect scalar before ResetToAutomaticBackend third-restore late-force test',
      Ord(sbScalar), Integer(LApi^.ActiveBackendId));

    GPublicAbiHookResetLateForceTarget := sbScalar;
    GPublicAbiHookResetLateForceEnabled := True;
    GPublicAbiHookResetLateForceStage := 0;
    AddDispatchChangedHook(@PublicAbiHookReForceBackendOnAutomaticThirdRestore);
    try
      ResetToAutomaticBackend;
      AssertEquals('Synthetic public ABI third-late-force hook should run through the full ResetToAutomaticBackend callback sequence',
        7, GPublicAbiHookResetLateForceStage);
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available after ResetToAutomaticBackend third-restore late-force test', LApi);
      AssertEquals('Public API active backend should still restore automatic best backend even if a late hook re-forces scalar during the third restore callback',
        Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
      AssertEquals('Public API active backend should keep tracking the actual current backend after ResetToAutomaticBackend third-restore late-force test',
        Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
      AssertTrue('Public API third-restore late-force path should not remain stuck on scalar when a better automatic backend exists',
        Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
    finally
      RemoveDispatchChangedHook(@PublicAbiHookReForceBackendOnAutomaticThirdRestore);
      GPublicAbiHookResetLateForceEnabled := False;
      GPublicAbiHookResetLateForceStage := 0;
      GPublicAbiHookResetLateForceTarget := sbScalar;
    end;
  finally
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_ResetToAutomaticBackend_HookLateForce_UntilAttemptCap_Restores_AutomaticBackend;
var
  LApi: PFafafaSimdPublicApi;
  LAutomaticBackend: TSimdBackend;
  LOldVectorAsm: Boolean;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LAutomaticBackend := GetBestDispatchableBackend;
    if LAutomaticBackend = sbScalar then
      Exit;

    AssertTrue('Scalar force setup should succeed before public ABI ResetToAutomaticBackend attempt-cap late-force test',
      TrySetActiveBackend(sbScalar));
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after scalar force setup for ResetToAutomaticBackend attempt-cap late-force test', LApi);
    AssertEquals('Public API active backend should reflect scalar before ResetToAutomaticBackend attempt-cap late-force test',
      Ord(sbScalar), Integer(LApi^.ActiveBackendId));

    GPublicAbiHookResetLateForceTarget := sbScalar;
    GPublicAbiHookResetLateForceEnabled := True;
    GPublicAbiHookResetLateForceStage := 0;
    AddDispatchChangedHook(@PublicAbiHookReForceBackendOnAutomaticRestoreUntilAttemptCap);
    try
      ResetToAutomaticBackend;
      AssertEquals('Synthetic public ABI ResetToAutomaticBackend attempt-cap late-force hook should observe the post-cap automatic closeout callback',
        18, GPublicAbiHookResetLateForceStage);
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available after ResetToAutomaticBackend attempt-cap late-force test', LApi);
      AssertEquals('Public API active backend should restore automatic best backend after repeated late scalar force exhausts the bounded restore helper',
        Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
      AssertEquals('Public API active backend should keep tracking the actual current backend after ResetToAutomaticBackend attempt-cap late-force test',
        Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
      AssertTrue('Public API ResetToAutomaticBackend attempt-cap late-force path should not remain stuck on scalar when a better automatic backend exists',
        Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
      AssertCrossSurfaceCurrentState(
        'ResetToAutomaticBackend attempt-cap return-time state',
        LAutomaticBackend, True);
    finally
      RemoveDispatchChangedHook(@PublicAbiHookReForceBackendOnAutomaticRestoreUntilAttemptCap);
      GPublicAbiHookResetLateForceEnabled := False;
      GPublicAbiHookResetLateForceStage := 0;
      GPublicAbiHookResetLateForceTarget := sbScalar;
    end;
  finally
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_SetVectorAsmEnabled_HookLateForce_Restores_AutomaticBackend;
var
  LApi: PFafafaSimdPublicApi;
  LAutomaticBackend: TSimdBackend;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LAutomaticBackend := GetBestDispatchableBackend;
  if LAutomaticBackend = sbScalar then
    Exit;

  SetVectorAsmEnabled(False);
  ResetToAutomaticBackend;
  LApi := GetSimdPublicApi;
  AssertNotNull('Public API table should remain available after vector-asm disable precondition for late-force test', LApi);
  AssertEquals('Public API vector-asm disable precondition should keep active backend aligned with automatic best backend',
    Ord(GetBestDispatchableBackend), Integer(LApi^.ActiveBackendId));

  GPublicAbiHookReForceBackendTarget := sbScalar;
  GPublicAbiHookReForceBackendEnabled := True;
  GPublicAbiHookReForceBackendStage := 0;
  AddDispatchChangedHook(@PublicAbiHookReForceBackendOnce);
  try
    SetVectorAsmEnabled(True);
    AssertEquals('Synthetic public ABI vector-asm late-force hook should run through the real SetVectorAsmEnabled callback sequence',
      2, GPublicAbiHookReForceBackendStage);
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after vector-asm re-enable late-force test', LApi);
    AssertEquals('Public API should restore automatic best backend even if a late hook re-forces scalar during vector-asm re-enable notification',
      Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
    AssertEquals('Public API active backend should keep tracking the actual current backend after vector-asm re-enable late-force test',
      Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
    AssertTrue('Public API vector-asm re-enable late-force path should not remain stuck on scalar when a better automatic backend exists',
      Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
  finally
    RemoveDispatchChangedHook(@PublicAbiHookReForceBackendOnce);
    GPublicAbiHookReForceBackendEnabled := False;
    GPublicAbiHookReForceBackendStage := 0;
    GPublicAbiHookReForceBackendTarget := sbScalar;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_SetVectorAsmEnabled_HookLateForce_DuringRestore_Restores_AutomaticBackend;
var
  LApi: PFafafaSimdPublicApi;
  LAutomaticBackend: TSimdBackend;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LAutomaticBackend := GetBestDispatchableBackend;
  if LAutomaticBackend = sbScalar then
    Exit;

  SetVectorAsmEnabled(False);
  ResetToAutomaticBackend;
  LApi := GetSimdPublicApi;
  AssertNotNull('Public API table should remain available after vector-asm disable precondition for restore-callback late-force test', LApi);
  AssertEquals('Public API vector-asm disable precondition should keep active backend aligned with automatic best backend before restore-callback late-force test',
    Ord(GetBestDispatchableBackend), Integer(LApi^.ActiveBackendId));

  GPublicAbiHookResetLateForceTarget := sbScalar;
  GPublicAbiHookResetLateForceEnabled := True;
  GPublicAbiHookResetLateForceStage := 0;
  AddDispatchChangedHook(@PublicAbiHookReForceBackendOnAutomaticRestore);
  try
    SetVectorAsmEnabled(True);
    AssertEquals('Synthetic public ABI vector-asm second-late-force hook should run through the full SetVectorAsmEnabled callback sequence',
      5, GPublicAbiHookResetLateForceStage);
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after vector-asm restore-callback late-force test', LApi);
    AssertEquals('Public API should still restore automatic best backend even if a late hook re-forces scalar during vector-asm restore callback',
      Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
    AssertEquals('Public API active backend should keep tracking the actual current backend after vector-asm restore-callback late-force test',
      Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
    AssertTrue('Public API vector-asm restore-callback late-force path should not remain stuck on scalar when a better automatic backend exists',
      Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
  finally
    RemoveDispatchChangedHook(@PublicAbiHookReForceBackendOnAutomaticRestore);
    GPublicAbiHookResetLateForceEnabled := False;
    GPublicAbiHookResetLateForceStage := 0;
    GPublicAbiHookResetLateForceTarget := sbScalar;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_SetVectorAsmEnabled_HookLateForce_DuringThirdRestore_Restores_AutomaticBackend;
var
  LApi: PFafafaSimdPublicApi;
  LAutomaticBackend: TSimdBackend;
  LOldVectorAsm: Boolean;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LAutomaticBackend := GetBestDispatchableBackend;
    if LAutomaticBackend = sbScalar then
      Exit;

    SetVectorAsmEnabled(False);
    ResetToAutomaticBackend;
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after vector-asm disable precondition for third-restore late-force test', LApi);
    AssertEquals('Public API vector-asm disable precondition should keep active backend aligned with automatic best backend before third-restore late-force test',
      Ord(GetBestDispatchableBackend), Integer(LApi^.ActiveBackendId));

    GPublicAbiHookResetLateForceTarget := sbScalar;
    GPublicAbiHookResetLateForceEnabled := True;
    GPublicAbiHookResetLateForceStage := 0;
    AddDispatchChangedHook(@PublicAbiHookReForceBackendOnAutomaticThirdRestore);
    try
      SetVectorAsmEnabled(True);
      AssertEquals('Synthetic public ABI vector-asm third-late-force hook should run through the full SetVectorAsmEnabled callback sequence',
        7, GPublicAbiHookResetLateForceStage);
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available after vector-asm third-restore late-force test', LApi);
      AssertEquals('Public API should still restore automatic best backend even if a late hook re-forces scalar during the third vector-asm restore callback',
        Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
      AssertEquals('Public API active backend should keep tracking the actual current backend after vector-asm third-restore late-force test',
        Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
      AssertTrue('Public API vector-asm third-restore late-force path should not remain stuck on scalar when a better automatic backend exists',
        Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
      AssertCrossSurfaceCurrentState(
        'SetVectorAsmEnabled third restore late force automatic backend return-time state',
        LAutomaticBackend, True);
    finally
      RemoveDispatchChangedHook(@PublicAbiHookReForceBackendOnAutomaticThirdRestore);
      GPublicAbiHookResetLateForceEnabled := False;
      GPublicAbiHookResetLateForceStage := 0;
      GPublicAbiHookResetLateForceTarget := sbScalar;
    end;
  finally
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_SetVectorAsmEnabled_HookLateForce_UntilAttemptCap_Restores_AutomaticBackend;
var
  LApi: PFafafaSimdPublicApi;
  LAutomaticBackend: TSimdBackend;
  LOldVectorAsm: Boolean;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LAutomaticBackend := GetBestDispatchableBackend;
    if LAutomaticBackend = sbScalar then
      Exit;

    SetVectorAsmEnabled(False);
    ResetToAutomaticBackend;
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after vector-asm disable precondition for attempt-cap late-force test', LApi);
    AssertEquals('Public API vector-asm disable precondition should keep active backend aligned with automatic best backend',
      Ord(GetBestDispatchableBackend), Integer(LApi^.ActiveBackendId));

    GPublicAbiHookResetLateForceTarget := sbScalar;
    GPublicAbiHookResetLateForceEnabled := True;
    GPublicAbiHookResetLateForceStage := 0;
    AddDispatchChangedHook(@PublicAbiHookReForceBackendOnToggleRestoreUntilAttemptCap);
    try
      SetVectorAsmEnabled(True);
      AssertEquals('Synthetic public ABI vector-asm attempt-cap late-force hook should observe the post-cap automatic closeout callback',
        20, GPublicAbiHookResetLateForceStage);
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available after vector-asm attempt-cap late-force test', LApi);
      AssertEquals('Public API should restore automatic best backend after repeated late scalar force exhausts the bounded restore helper',
        Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
      AssertEquals('Public API active backend should keep tracking the actual current backend after vector-asm attempt-cap late-force test',
        Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
      AssertTrue('Public API vector-asm attempt-cap late-force path should not remain stuck on scalar when a better automatic backend exists',
        Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
      AssertCrossSurfaceCurrentState(
        'SetVectorAsmEnabled attempt-cap automatic return-time state',
        LAutomaticBackend, True);
    finally
      RemoveDispatchChangedHook(@PublicAbiHookReForceBackendOnToggleRestoreUntilAttemptCap);
      GPublicAbiHookResetLateForceEnabled := False;
      GPublicAbiHookResetLateForceStage := 0;
      GPublicAbiHookResetLateForceTarget := sbScalar;
    end;
  finally
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_SetVectorAsmEnabled_HookLateAutomaticReset_Preserves_PreviousForcedBackend;
var
  LApi: PFafafaSimdPublicApi;
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LPreviousForcedBackend: TSimdBackend;
  LIndex: Integer;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LDispatchable := GetDispatchableBackendList;
  if Length(LDispatchable) < 2 then
    Exit;

  LAutomaticBackend := GetBestDispatchableBackend;
  LPreviousForcedBackend := sbScalar;
  for LIndex := High(LDispatchable) downto 0 do
    if (LDispatchable[LIndex] <> sbScalar) and (LDispatchable[LIndex] <> LAutomaticBackend) then
    begin
      LPreviousForcedBackend := LDispatchable[LIndex];
      Break;
    end;

  if LPreviousForcedBackend = sbScalar then
    Exit;

  AssertTrue('Previous forced backend should differ from automatic best backend in public ABI vector-asm late-reset test',
    LPreviousForcedBackend <> LAutomaticBackend);
  AssertTrue('Previous forced backend setup should succeed before public ABI vector-asm late-reset test',
    TrySetActiveBackend(LPreviousForcedBackend));
  LApi := GetSimdPublicApi;
  AssertNotNull('Public API table should remain available after previous forced backend setup in vector-asm late-reset test', LApi);
  AssertEquals('Public API active backend should reflect the previous forced backend before vector-asm late-reset test',
    Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));

  GPublicAbiHookResetToAutomaticEnabled := True;
  GPublicAbiHookResetToAutomaticStage := 0;
  AddDispatchChangedHook(@PublicAbiHookResetToAutomaticOnce);
  try
    SetVectorAsmEnabled(False);
    AssertEquals('Synthetic public ABI vector-asm late-reset hook should run through the real SetVectorAsmEnabled callback sequence',
      2, GPublicAbiHookResetToAutomaticStage);
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after vector-asm disable late-reset test', LApi);
    AssertTrue('Vector-asm disable should move public ABI active backend away from the previously forced backend when it becomes non-dispatchable',
      Integer(LApi^.ActiveBackendId) <> Ord(LPreviousForcedBackend));
  finally
    RemoveDispatchChangedHook(@PublicAbiHookResetToAutomaticOnce);
    GPublicAbiHookResetToAutomaticEnabled := False;
    GPublicAbiHookResetToAutomaticStage := 0;
  end;

  SetVectorAsmEnabled(True);
  LApi := GetSimdPublicApi;
  AssertNotNull('Public API table should remain available after vector-asm re-enable late-reset test', LApi);
  AssertEquals('Public API should preserve the previously forced backend after vector-asm re-enable even if a late hook reset to automatic during disable',
    Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));
  AssertEquals('Public API active backend should keep tracking the actual current backend after vector-asm late-reset test',
    Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
end;

procedure TTestCase_PublicAbi.Test_PublicApi_SetVectorAsmEnabled_HookLateAutomaticReset_DuringRestore_Preserves_PreviousForcedBackend;
var
  LApi: PFafafaSimdPublicApi;
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LPreviousForcedBackend: TSimdBackend;
  LIndex: Integer;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LDispatchable := GetDispatchableBackendList;
  if Length(LDispatchable) < 2 then
    Exit;

  LAutomaticBackend := GetBestDispatchableBackend;
  LPreviousForcedBackend := sbScalar;
  for LIndex := High(LDispatchable) downto 0 do
    if (LDispatchable[LIndex] <> sbScalar) and (LDispatchable[LIndex] <> LAutomaticBackend) then
    begin
      LPreviousForcedBackend := LDispatchable[LIndex];
      Break;
    end;

  if LPreviousForcedBackend = sbScalar then
    Exit;

  AssertTrue('Previous forced backend should differ from automatic best backend in public ABI vector-asm restore-callback late-reset test',
    LPreviousForcedBackend <> LAutomaticBackend);
  AssertTrue('Previous forced backend setup should succeed before public ABI vector-asm restore-callback late-reset test',
    TrySetActiveBackend(LPreviousForcedBackend));
  LApi := GetSimdPublicApi;
  AssertNotNull('Public API table should remain available after setting up previous forced backend for vector-asm restore-callback late-reset test', LApi);
  AssertEquals('Public API active backend should reflect the previous forced backend before vector-asm restore-callback late-reset test',
    Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));

  GPublicAbiHookToggleRestoreResetEnabled := True;
  GPublicAbiHookToggleRestoreResetStage := 0;
  AddDispatchChangedHook(@PublicAbiHookResetToAutomaticOnToggleRestore);
  try
    SetVectorAsmEnabled(False);
    AssertEquals('Synthetic public ABI vector-asm restore-callback late-reset hook should run through the full callback sequence',
      5, GPublicAbiHookToggleRestoreResetStage);
    AssertTrue('Disabling vector asm should move current backend away from the previously forced backend when it becomes non-dispatchable in public ABI restore-callback late-reset test',
      GetCurrentBackend <> LPreviousForcedBackend);
  finally
    RemoveDispatchChangedHook(@PublicAbiHookResetToAutomaticOnToggleRestore);
    GPublicAbiHookToggleRestoreResetEnabled := False;
    GPublicAbiHookToggleRestoreResetStage := 0;
  end;

  SetVectorAsmEnabled(True);
  LApi := GetSimdPublicApi;
  AssertNotNull('Public API table should remain available after vector-asm restore-callback late-reset test', LApi);
  AssertEquals('Public API should preserve the previously forced backend after vector-asm re-enable even if a late hook resets to automatic during restore callback',
    Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));
end;

procedure TTestCase_PublicAbi.Test_PublicApi_SetVectorAsmEnabled_HookLateForce_DuringRestore_Preserves_PreviousForcedBackend;
var
  LApi: PFafafaSimdPublicApi;
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LPreviousForcedBackend: TSimdBackend;
  LIndex: Integer;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LDispatchable := GetDispatchableBackendList;
  if Length(LDispatchable) < 2 then
    Exit;

  LAutomaticBackend := GetBestDispatchableBackend;
  LPreviousForcedBackend := sbScalar;
  for LIndex := High(LDispatchable) downto 0 do
    if (LDispatchable[LIndex] <> sbScalar) and (LDispatchable[LIndex] <> LAutomaticBackend) then
    begin
      LPreviousForcedBackend := LDispatchable[LIndex];
      Break;
    end;

  if LPreviousForcedBackend = sbScalar then
    Exit;

  AssertTrue('Previous forced backend should differ from automatic best backend in public ABI vector-asm restore-callback late-force test',
    LPreviousForcedBackend <> LAutomaticBackend);
  AssertTrue('Previous forced backend setup should succeed before public ABI vector-asm restore-callback late-force test',
    TrySetActiveBackend(LPreviousForcedBackend));
  LApi := GetSimdPublicApi;
  AssertNotNull('Public API table should remain available after setting up previous forced backend for vector-asm restore-callback late-force test', LApi);
  AssertEquals('Public API active backend should reflect the previous forced backend before vector-asm restore-callback late-force test',
    Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));

  GPublicAbiHookResetLateForceEnabled := True;
  GPublicAbiHookResetLateForceStage := 0;
  GPublicAbiHookResetLateForceTarget := sbScalar;
  AddDispatchChangedHook(@PublicAbiHookReForceBackendOnAutomaticRestore);
  try
    SetVectorAsmEnabled(False);
    AssertEquals('Synthetic public ABI vector-asm restore-callback late-force hook should run through the full callback sequence',
      5, GPublicAbiHookResetLateForceStage);
    AssertTrue('Disabling vector asm should move current backend away from the previously forced backend when it becomes non-dispatchable in public ABI restore-callback late-force test',
      GetCurrentBackend <> LPreviousForcedBackend);
  finally
    RemoveDispatchChangedHook(@PublicAbiHookReForceBackendOnAutomaticRestore);
    GPublicAbiHookResetLateForceEnabled := False;
    GPublicAbiHookResetLateForceStage := 0;
    GPublicAbiHookResetLateForceTarget := sbScalar;
  end;

  SetVectorAsmEnabled(True);
  LApi := GetSimdPublicApi;
  AssertNotNull('Public API table should remain available after public ABI vector-asm restore-callback late-force test', LApi);
  AssertEquals('Public API should preserve the previously forced backend after vector-asm re-enable even if a late hook re-forces scalar during restore callback',
    Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));
  AssertTrue('Public ABI vector-asm restore-callback late-force path should not remain stuck on scalar after re-enable',
    Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
end;

procedure TTestCase_PublicAbi.Test_PublicApi_SetVectorAsmEnabled_HookLateForce_DuringThirdRestore_Preserves_PreviousForcedBackend;
var
  LApi: PFafafaSimdPublicApi;
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LPreviousForcedBackend: TSimdBackend;
  LOldVectorAsm: Boolean;
  LIndex: Integer;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LDispatchable := GetDispatchableBackendList;
    if Length(LDispatchable) < 2 then
      Exit;

    LAutomaticBackend := GetBestDispatchableBackend;
    LPreviousForcedBackend := sbScalar;
    for LIndex := High(LDispatchable) downto 0 do
      if (LDispatchable[LIndex] <> sbScalar) and (LDispatchable[LIndex] <> LAutomaticBackend) then
      begin
        LPreviousForcedBackend := LDispatchable[LIndex];
        Break;
      end;

    if LPreviousForcedBackend = sbScalar then
      Exit;

    AssertTrue('Previous forced backend should differ from automatic best backend in public ABI vector-asm third-restore late-force test',
      LPreviousForcedBackend <> LAutomaticBackend);
    AssertTrue('Previous forced backend setup should succeed before public ABI vector-asm third-restore late-force test',
      TrySetActiveBackend(LPreviousForcedBackend));
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after setting up previous forced backend for vector-asm third-restore late-force test', LApi);
    AssertEquals('Public API active backend should reflect the previous forced backend before vector-asm third-restore late-force test',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));

    GPublicAbiHookResetLateForceEnabled := True;
    GPublicAbiHookResetLateForceStage := 0;
    GPublicAbiHookResetLateForceTarget := sbScalar;
    AddDispatchChangedHook(@PublicAbiHookReForceBackendOnAutomaticThirdRestore);
    try
      SetVectorAsmEnabled(False);
      AssertEquals('Synthetic public ABI vector-asm third-restore late-force hook should run through the full callback sequence',
        7, GPublicAbiHookResetLateForceStage);
      AssertTrue('Disabling vector asm should move current backend away from the previously forced backend when it becomes non-dispatchable in public ABI third-restore late-force test',
        GetCurrentBackend <> LPreviousForcedBackend);
    finally
      RemoveDispatchChangedHook(@PublicAbiHookReForceBackendOnAutomaticThirdRestore);
      GPublicAbiHookResetLateForceEnabled := False;
      GPublicAbiHookResetLateForceStage := 0;
      GPublicAbiHookResetLateForceTarget := sbScalar;
    end;

    SetVectorAsmEnabled(True);
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after public ABI vector-asm third-restore late-force test', LApi);
    AssertEquals('Public API should preserve the previously forced backend after vector-asm re-enable even if a late hook re-forces scalar during the third restore callback',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));
    AssertTrue('Public ABI vector-asm third-restore late-force path should not remain stuck on scalar after re-enable',
      Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
    AssertCrossSurfaceCurrentState(
      'SetVectorAsmEnabled third restore late force previous forced backend return-time state',
      LPreviousForcedBackend, False);
  finally
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_SetVectorAsmEnabled_HookLateForce_UntilAttemptCap_Preserves_PreviousForcedBackend;
var
  LApi: PFafafaSimdPublicApi;
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LPreviousForcedBackend: TSimdBackend;
  LOldVectorAsm: Boolean;
  LIndex: Integer;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LDispatchable := GetDispatchableBackendList;
    if Length(LDispatchable) < 2 then
      Exit;

    LAutomaticBackend := GetBestDispatchableBackend;
    LPreviousForcedBackend := sbScalar;
    for LIndex := High(LDispatchable) downto 0 do
      if (LDispatchable[LIndex] <> sbScalar) and (LDispatchable[LIndex] <> LAutomaticBackend) then
      begin
        LPreviousForcedBackend := LDispatchable[LIndex];
        Break;
      end;

    if LPreviousForcedBackend = sbScalar then
      Exit;

    AssertTrue('Previous forced backend should differ from automatic best backend in public ABI vector-asm attempt-cap late-force test',
      LPreviousForcedBackend <> LAutomaticBackend);
    AssertTrue('Previous forced backend setup should succeed before public ABI vector-asm attempt-cap late-force test',
      TrySetActiveBackend(LPreviousForcedBackend));
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after setting up previous forced backend for vector-asm attempt-cap late-force test', LApi);
    AssertEquals('Public API active backend should reflect the previous forced backend before vector-asm attempt-cap late-force test',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));

    GPublicAbiHookResetLateForceEnabled := True;
    GPublicAbiHookResetLateForceStage := 0;
    GPublicAbiHookResetLateForceTarget := sbScalar;
    AddDispatchChangedHook(@PublicAbiHookReForceBackendOnToggleRestoreUntilAttemptCap);
    try
      SetVectorAsmEnabled(False);
      AssertEquals('Synthetic public ABI vector-asm previous-forced attempt-cap late-force hook should observe the post-cap restore closeout callback',
        20, GPublicAbiHookResetLateForceStage);
      AssertTrue('Disabling vector asm should move current backend away from the previously forced backend when it becomes non-dispatchable in public ABI attempt-cap late-force test',
        GetCurrentBackend <> LPreviousForcedBackend);
    finally
      RemoveDispatchChangedHook(@PublicAbiHookReForceBackendOnToggleRestoreUntilAttemptCap);
      GPublicAbiHookResetLateForceEnabled := False;
      GPublicAbiHookResetLateForceStage := 0;
      GPublicAbiHookResetLateForceTarget := sbScalar;
    end;

    SetVectorAsmEnabled(True);
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after vector-asm previous-forced attempt-cap late-force test', LApi);
    AssertEquals('Public API should preserve the previously forced backend after repeated late scalar force exhausts the bounded restore helper during vector-asm disable',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));
    AssertCrossSurfaceCurrentState(
      'SetVectorAsmEnabled attempt-cap previous-forced post-restore state',
      LPreviousForcedBackend, False);
  finally
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_RegisterBackend_HookLateForce_Restores_AutomaticBackend;
var
  LApi: PFafafaSimdPublicApi;
  LAutomaticBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LAutomaticBackend := GetBestDispatchableBackend;
  if LAutomaticBackend = sbScalar then
    Exit;

  LApi := GetSimdPublicApi;
  AssertNotNull('Public API table should remain available before RegisterBackend late-force test', LApi);
  AssertEquals('Public API active backend should reflect automatic best backend before RegisterBackend late-force test',
    Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
  AssertTrue('Automatic backend table should be registered for public ABI RegisterBackend late-force test',
    TryGetRegisteredBackendDispatchTable(LAutomaticBackend, LOriginalTable));

  GPublicAbiHookReForceBackendTarget := sbScalar;
  GPublicAbiHookReForceBackendEnabled := True;
  GPublicAbiHookReForceBackendStage := 0;
  AddDispatchChangedHook(@PublicAbiHookReForceBackendOnce);
  try
    RegisterBackend(LAutomaticBackend, LOriginalTable);
    AssertEquals('Synthetic public ABI RegisterBackend late-force hook should run through the real callback sequence',
      2, GPublicAbiHookReForceBackendStage);
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after RegisterBackend late-force test', LApi);
    AssertEquals('Public API active backend should restore automatic best backend even if a late hook re-forces scalar during RegisterBackend',
      Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
    AssertEquals('Public API active backend should keep tracking the actual current backend after RegisterBackend late-force test',
      Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
    AssertTrue('Public API active backend should not remain stuck on scalar after RegisterBackend late-force test',
      Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
  finally
    RemoveDispatchChangedHook(@PublicAbiHookReForceBackendOnce);
    GPublicAbiHookReForceBackendEnabled := False;
    GPublicAbiHookReForceBackendStage := 0;
    GPublicAbiHookReForceBackendTarget := sbScalar;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_RegisterBackend_HookLateForce_UntilAttemptCap_Restores_AutomaticBackend;
var
  LApi: PFafafaSimdPublicApi;
  LAutomaticBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LOldVectorAsm: Boolean;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LAutomaticBackend := GetBestDispatchableBackend;
    if LAutomaticBackend = sbScalar then
      Exit;

    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available before RegisterBackend attempt-cap late-force test', LApi);
    AssertEquals('Public API active backend should reflect automatic best backend before RegisterBackend attempt-cap late-force test',
      Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
    AssertTrue('Automatic backend table should be registered for public ABI RegisterBackend attempt-cap late-force test',
      TryGetRegisteredBackendDispatchTable(LAutomaticBackend, LOriginalTable));

    GPublicAbiHookResetLateForceTarget := sbScalar;
    GPublicAbiHookResetLateForceEnabled := True;
    GPublicAbiHookResetLateForceStage := 0;
    AddDispatchChangedHook(@PublicAbiHookReForceBackendOnRegisterRestoreUntilAttemptCap);
    try
      RegisterBackend(LAutomaticBackend, LOriginalTable);
      AssertEquals('Synthetic public ABI RegisterBackend attempt-cap late-force hook should observe the post-cap automatic closeout callback',
        20, GPublicAbiHookResetLateForceStage);
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available after RegisterBackend attempt-cap late-force test', LApi);
      AssertEquals('Public API should restore automatic best backend after repeated late scalar force exhausts the bounded restore helper',
        Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
      AssertEquals('Public API active backend should keep tracking the actual current backend after RegisterBackend attempt-cap late-force test',
        Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
      AssertTrue('Public API RegisterBackend attempt-cap late-force path should not remain stuck on scalar when a better automatic backend exists',
        Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
      AssertCrossSurfaceCurrentState(
        'RegisterBackend attempt-cap automatic return-time state',
        LAutomaticBackend, True);
    finally
      RemoveDispatchChangedHook(@PublicAbiHookReForceBackendOnRegisterRestoreUntilAttemptCap);
      GPublicAbiHookResetLateForceEnabled := False;
      GPublicAbiHookResetLateForceStage := 0;
      GPublicAbiHookResetLateForceTarget := sbScalar;
    end;
  finally
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_RegisterBackend_HookLateForce_DuringThirdRestore_Restores_AutomaticBackend;
var
  LApi: PFafafaSimdPublicApi;
  LAutomaticBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LOldVectorAsm: Boolean;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LAutomaticBackend := GetBestDispatchableBackend;
    if LAutomaticBackend = sbScalar then
      Exit;

    AssertTrue('Automatic backend table should be registered for public ABI RegisterBackend third-restore late-force test',
      TryGetRegisteredBackendDispatchTable(LAutomaticBackend, LOriginalTable));

    GPublicAbiHookResetLateForceTarget := sbScalar;
    GPublicAbiHookResetLateForceEnabled := True;
    GPublicAbiHookResetLateForceStage := 0;
    AddDispatchChangedHook(@PublicAbiHookReForceBackendOnAutomaticThirdRestore);
    try
      RegisterBackend(LAutomaticBackend, LOriginalTable);
      AssertEquals('Synthetic public ABI RegisterBackend automatic third-late-force hook should run through the full callback sequence',
        7, GPublicAbiHookResetLateForceStage);
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available after public ABI RegisterBackend automatic third-restore late-force test', LApi);
      AssertEquals('Public API should still restore automatic best backend even if a late hook re-forces scalar during the third RegisterBackend restore notification',
        Ord(LAutomaticBackend), Integer(LApi^.ActiveBackendId));
      AssertEquals('Public API active backend should keep tracking the actual current backend after RegisterBackend automatic third-restore late-force test',
        Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
      AssertTrue('Public ABI RegisterBackend automatic third-restore late-force path should not remain stuck on scalar when a better automatic backend exists',
        Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
      AssertCrossSurfaceCurrentState(
        'RegisterBackend third restore late force automatic backend return-time state',
        LAutomaticBackend, True);
    finally
      RemoveDispatchChangedHook(@PublicAbiHookReForceBackendOnAutomaticThirdRestore);
      GPublicAbiHookResetLateForceEnabled := False;
      GPublicAbiHookResetLateForceStage := 0;
      GPublicAbiHookResetLateForceTarget := sbScalar;
    end;
  finally
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_RegisterBackend_HookLateAutomaticReset_Preserves_PreviousForcedBackend;
var
  LApi: PFafafaSimdPublicApi;
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LPreviousForcedBackend: TSimdBackend;
  LPreviousOriginalTable: TSimdDispatchTable;
  LPreviousTableCaptured: Boolean;
  LIndex: Integer;
begin
  LPreviousTableCaptured := False;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LDispatchable := GetDispatchableBackendList;
    if Length(LDispatchable) < 2 then
      Exit;

    LAutomaticBackend := GetBestDispatchableBackend;
    LPreviousForcedBackend := sbScalar;
    for LIndex := 0 to High(LDispatchable) do
      if (LDispatchable[LIndex] <> LAutomaticBackend) and (LDispatchable[LIndex] <> sbScalar) then
      begin
        LPreviousForcedBackend := LDispatchable[LIndex];
        Break;
      end;

    if LPreviousForcedBackend = sbScalar then
      Exit;

    AssertTrue('Previous forced backend should differ from automatic best backend in public ABI RegisterBackend late-reset test',
      LPreviousForcedBackend <> LAutomaticBackend);
    AssertTrue('Previous forced backend setup should succeed before public ABI RegisterBackend late-reset test',
      TrySetActiveBackend(LPreviousForcedBackend));
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after setting up previous forced backend for RegisterBackend late-reset test', LApi);
    AssertEquals('Public API active backend should reflect the previous forced backend before RegisterBackend late-reset test',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));

    AssertTrue('Previous forced backend table should be registered for public ABI RegisterBackend late-reset test',
      TryGetRegisteredBackendDispatchTable(LPreviousForcedBackend, LPreviousOriginalTable));
    LPreviousTableCaptured := True;

    GPublicAbiHookRegisterRestoreResetEnabled := True;
    GPublicAbiHookRegisterRestoreResetStage := 0;
    AddDispatchChangedHook(@PublicAbiHookLateAutomaticResetOnRegisterRestore);
    try
      RegisterBackend(LPreviousForcedBackend, LPreviousOriginalTable);
      LPreviousTableCaptured := False;
      AssertEquals('Synthetic public ABI RegisterBackend late-reset hook should run through the full callback sequence',
        5, GPublicAbiHookRegisterRestoreResetStage);
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available after RegisterBackend late-reset test', LApi);
      AssertEquals('Public API active backend should preserve the previous forced backend even if a late hook resets to automatic during RegisterBackend restore notification',
        Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));
      AssertEquals('Public API active backend should keep tracking the actual current backend after RegisterBackend late-reset test',
        Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
      AssertTrue('Public API RegisterBackend late-reset path should not silently drift to automatic best backend when a previous forced backend exists',
        Integer(LApi^.ActiveBackendId) <> Ord(LAutomaticBackend));
    finally
      RemoveDispatchChangedHook(@PublicAbiHookLateAutomaticResetOnRegisterRestore);
      GPublicAbiHookRegisterRestoreResetEnabled := False;
      GPublicAbiHookRegisterRestoreResetStage := 0;
    end;
  finally
    if LPreviousTableCaptured then
      RegisterBackend(LPreviousForcedBackend, LPreviousOriginalTable);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_RegisterBackend_HookLateForce_DuringRestore_Preserves_PreviousForcedBackend;
var
  LApi: PFafafaSimdPublicApi;
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LPreviousForcedBackend: TSimdBackend;
  LPreviousOriginalTable: TSimdDispatchTable;
  LPreviousTableCaptured: Boolean;
  LIndex: Integer;
begin
  LPreviousTableCaptured := False;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LDispatchable := GetDispatchableBackendList;
    if Length(LDispatchable) < 2 then
      Exit;

    LAutomaticBackend := GetBestDispatchableBackend;
    LPreviousForcedBackend := sbScalar;
    for LIndex := 0 to High(LDispatchable) do
      if (LDispatchable[LIndex] <> LAutomaticBackend) and (LDispatchable[LIndex] <> sbScalar) then
      begin
        LPreviousForcedBackend := LDispatchable[LIndex];
        Break;
      end;

    if LPreviousForcedBackend = sbScalar then
      Exit;

    AssertTrue('Previous forced backend should differ from automatic best backend in public ABI RegisterBackend restore-callback late-force test',
      LPreviousForcedBackend <> LAutomaticBackend);
    AssertTrue('Previous forced backend setup should succeed before public ABI RegisterBackend restore-callback late-force test',
      TrySetActiveBackend(LPreviousForcedBackend));
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after setting up previous forced backend for RegisterBackend restore-callback late-force test', LApi);
    AssertEquals('Public API active backend should reflect the previous forced backend before RegisterBackend restore-callback late-force test',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));

    AssertTrue('Previous forced backend table should be registered for public ABI RegisterBackend restore-callback late-force test',
      TryGetRegisteredBackendDispatchTable(LPreviousForcedBackend, LPreviousOriginalTable));
    LPreviousTableCaptured := True;

    GPublicAbiHookResetLateForceEnabled := True;
    GPublicAbiHookResetLateForceStage := 0;
    GPublicAbiHookResetLateForceTarget := sbScalar;
    AddDispatchChangedHook(@PublicAbiHookReForceBackendOnAutomaticRestore);
    try
      RegisterBackend(LPreviousForcedBackend, LPreviousOriginalTable);
      LPreviousTableCaptured := False;
      AssertEquals('Synthetic public ABI RegisterBackend restore-callback late-force hook should run through the full callback sequence',
        5, GPublicAbiHookResetLateForceStage);
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available after public ABI RegisterBackend restore-callback late-force test', LApi);
      AssertEquals('Public API active backend should preserve the previous forced backend even if a late hook re-forces scalar during RegisterBackend restore notification',
        Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));
      AssertTrue('Public ABI RegisterBackend restore-callback late-force path should not silently drift to automatic best backend when a previous forced backend exists',
        Integer(LApi^.ActiveBackendId) <> Ord(LAutomaticBackend));
      AssertTrue('Public ABI RegisterBackend restore-callback late-force path should not remain stuck on scalar while restoring previous forced backend',
        Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
      AssertEquals('Public API active backend should keep tracking the actual current backend after RegisterBackend restore-callback late-force test',
        Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
    finally
      RemoveDispatchChangedHook(@PublicAbiHookReForceBackendOnAutomaticRestore);
      GPublicAbiHookResetLateForceEnabled := False;
      GPublicAbiHookResetLateForceStage := 0;
      GPublicAbiHookResetLateForceTarget := sbScalar;
    end;
  finally
    if LPreviousTableCaptured then
      RegisterBackend(LPreviousForcedBackend, LPreviousOriginalTable);
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_RegisterBackend_HookLateForce_DuringThirdRestore_Preserves_PreviousForcedBackend;
var
  LApi: PFafafaSimdPublicApi;
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LPreviousForcedBackend: TSimdBackend;
  LPreviousOriginalTable: TSimdDispatchTable;
  LOldVectorAsm: Boolean;
  LPreviousTableCaptured: Boolean;
  LIndex: Integer;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LPreviousTableCaptured := False;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LDispatchable := GetDispatchableBackendList;
    if Length(LDispatchable) < 2 then
      Exit;

    LAutomaticBackend := GetBestDispatchableBackend;
    LPreviousForcedBackend := sbScalar;
    for LIndex := 0 to High(LDispatchable) do
      if (LDispatchable[LIndex] <> LAutomaticBackend) and (LDispatchable[LIndex] <> sbScalar) then
      begin
        LPreviousForcedBackend := LDispatchable[LIndex];
        Break;
      end;

    if LPreviousForcedBackend = sbScalar then
      Exit;

    AssertTrue('Previous forced backend should differ from automatic best backend in public ABI RegisterBackend third-restore late-force test',
      LPreviousForcedBackend <> LAutomaticBackend);
    AssertTrue('Previous forced backend setup should succeed before public ABI RegisterBackend third-restore late-force test',
      TrySetActiveBackend(LPreviousForcedBackend));
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after setting up previous forced backend for RegisterBackend third-restore late-force test', LApi);
    AssertEquals('Public API active backend should reflect the previous forced backend before RegisterBackend third-restore late-force test',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));

    AssertTrue('Previous forced backend table should be registered for public ABI RegisterBackend third-restore late-force test',
      TryGetRegisteredBackendDispatchTable(LPreviousForcedBackend, LPreviousOriginalTable));
    LPreviousTableCaptured := True;

    GPublicAbiHookResetLateForceEnabled := True;
    GPublicAbiHookResetLateForceStage := 0;
    GPublicAbiHookResetLateForceTarget := sbScalar;
    AddDispatchChangedHook(@PublicAbiHookReForceBackendOnAutomaticThirdRestore);
    try
      RegisterBackend(LPreviousForcedBackend, LPreviousOriginalTable);
      AssertEquals('Synthetic public ABI RegisterBackend third-late-force hook should run through the full callback sequence',
        7, GPublicAbiHookResetLateForceStage);
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available after public ABI RegisterBackend third-restore late-force test', LApi);
      AssertEquals('Public API active backend should preserve the previous forced backend even if a late hook re-forces scalar during the third RegisterBackend restore notification',
        Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));
      AssertTrue('Public ABI RegisterBackend third-restore late-force path should not silently drift to automatic best backend when a previous forced backend exists',
        Integer(LApi^.ActiveBackendId) <> Ord(LAutomaticBackend));
      AssertTrue('Public ABI RegisterBackend third-restore late-force path should not remain stuck on scalar while restoring previous forced backend',
        Integer(LApi^.ActiveBackendId) <> Ord(sbScalar));
      AssertEquals('Public API active backend should keep tracking the actual current backend after RegisterBackend third-restore late-force test',
        Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
      AssertCrossSurfaceCurrentState(
        'RegisterBackend third restore late force previous forced backend return-time state',
        LPreviousForcedBackend, False);
    finally
      RemoveDispatchChangedHook(@PublicAbiHookReForceBackendOnAutomaticThirdRestore);
      GPublicAbiHookResetLateForceEnabled := False;
      GPublicAbiHookResetLateForceStage := 0;
      GPublicAbiHookResetLateForceTarget := sbScalar;
    end;
  finally
    if LPreviousTableCaptured then
      RegisterBackend(LPreviousForcedBackend, LPreviousOriginalTable);
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_RegisterBackend_HookLateForce_UntilAttemptCap_Preserves_PreviousForcedBackend;
var
  LApi: PFafafaSimdPublicApi;
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LPreviousForcedBackend: TSimdBackend;
  LPreviousOriginalTable: TSimdDispatchTable;
  LOldVectorAsm: Boolean;
  LPreviousTableCaptured: Boolean;
  LIndex: Integer;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LPreviousTableCaptured := False;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LDispatchable := GetDispatchableBackendList;
    if Length(LDispatchable) < 2 then
      Exit;

    LAutomaticBackend := GetBestDispatchableBackend;
    LPreviousForcedBackend := sbScalar;
    for LIndex := 0 to High(LDispatchable) do
      if (LDispatchable[LIndex] <> LAutomaticBackend) and (LDispatchable[LIndex] <> sbScalar) then
      begin
        LPreviousForcedBackend := LDispatchable[LIndex];
        Break;
      end;

    if LPreviousForcedBackend = sbScalar then
      Exit;

    AssertTrue('Previous forced backend should differ from automatic best backend in public ABI RegisterBackend attempt-cap late-force test',
      LPreviousForcedBackend <> LAutomaticBackend);
    AssertTrue('Previous forced backend setup should succeed before public ABI RegisterBackend attempt-cap late-force test',
      TrySetActiveBackend(LPreviousForcedBackend));
    LApi := GetSimdPublicApi;
    AssertNotNull('Public API table should remain available after setting up previous forced backend for RegisterBackend attempt-cap late-force test', LApi);
    AssertEquals('Public API active backend should reflect the previous forced backend before RegisterBackend attempt-cap late-force test',
      Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));

    AssertTrue('Previous forced backend table should be registered for public ABI RegisterBackend attempt-cap late-force test',
      TryGetRegisteredBackendDispatchTable(LPreviousForcedBackend, LPreviousOriginalTable));
    LPreviousTableCaptured := True;

    GPublicAbiHookResetLateForceEnabled := True;
    GPublicAbiHookResetLateForceStage := 0;
    GPublicAbiHookResetLateForceTarget := sbScalar;
    AddDispatchChangedHook(@PublicAbiHookReForceBackendOnRegisterRestoreUntilAttemptCap);
    try
      RegisterBackend(LPreviousForcedBackend, LPreviousOriginalTable);
      AssertEquals('Synthetic public ABI RegisterBackend previous-forced attempt-cap late-force hook should observe the post-cap restore closeout callback',
        20, GPublicAbiHookResetLateForceStage);
      LApi := GetSimdPublicApi;
      AssertNotNull('Public API table should remain available after RegisterBackend previous-forced attempt-cap late-force test', LApi);
      AssertEquals('Public API should preserve the previous forced backend after repeated late scalar force exhausts the bounded restore helper',
        Ord(LPreviousForcedBackend), Integer(LApi^.ActiveBackendId));
      AssertEquals('Public API active backend should keep tracking the actual current backend after RegisterBackend previous-forced attempt-cap late-force test',
        Ord(GetCurrentBackend), Integer(LApi^.ActiveBackendId));
      AssertTrue('Public API RegisterBackend attempt-cap late-force path should not silently drift to automatic best backend when a previous forced backend exists',
        Integer(LApi^.ActiveBackendId) <> Ord(LAutomaticBackend));
      AssertCrossSurfaceCurrentState(
        'RegisterBackend attempt-cap previous-forced return-time state',
        LPreviousForcedBackend, False);
    finally
      RemoveDispatchChangedHook(@PublicAbiHookReForceBackendOnRegisterRestoreUntilAttemptCap);
      GPublicAbiHookResetLateForceEnabled := False;
      GPublicAbiHookResetLateForceStage := 0;
      GPublicAbiHookResetLateForceTarget := sbScalar;
    end;
  finally
    if LPreviousTableCaptured then
      RegisterBackend(LPreviousForcedBackend, LPreviousOriginalTable);
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_DataPlane_Parity;
var
  LApi: PFafafaSimdPublicApi;
  LStage: string;
  LA, LB: array[0..31] of Byte;
  LIdx: Integer;
  LSumApi, LSumFacade: UInt64;
  LCountApi, LCountFacade: SizeUInt;
  LPopApi, LPopFacade: SizeUInt;
  LEqApi, LEqFacade: LongBool;
  LFindApi, LFindFacade: PtrInt;
  LDiffApi, LDiffFacade: Boolean;
  LFirstApi, LLastApi: SizeUInt;
  LFirstFacade, LLastFacade: SizeUInt;
  LUtfApi, LUtfFacade: Boolean;
  LAsciiApi, LAsciiFacade: Boolean;
  LBytesApi, LBytesFacade: PtrInt;
  LNeedle: array[0..2] of Byte;
  LUtf8Text: RawByteString;
  LAsciiA, LAsciiB: RawByteString;
  LCopyApi, LCopyFacade: array[0..31] of Byte;
  LFillApi, LFillFacade: array[0..31] of Byte;
  LRevApi, LRevFacade: array[0..7] of Byte;
  LLowerApi, LLowerFacade: RawByteString;
  LUpperApi, LUpperFacade: RawByteString;
  LMinApi, LMaxApi: Byte;
  LMinFacade, LMaxFacade: Byte;
begin
  LApi := GetSimdPublicApi;
  AssertNotNull('Public API table should not be nil', LApi);

  LStage := 'init';
  try
    for LIdx := 0 to High(LA) do
    begin
      LA[LIdx] := Byte((LIdx * 7) and $FF);
      LB[LIdx] := LA[LIdx];
    end;
    LB[17] := $AA;

    LStage := 'MemEqual(facade)';
    LEqFacade := MemEqual(@LA[0], @LA[0], Length(LA));
    LStage := 'MemEqual(public-abi)';
    LEqApi := LApi^.MemEqual(@LA[0], @LA[0], Length(LA));
    AssertEquals('MemEqual parity', LEqFacade, LEqApi);

    LStage := 'MemFindByte';
    LFindApi := LApi^.MemFindByte(@LB[0], Length(LB), $AA);
    LFindFacade := MemFindByte(@LB[0], Length(LB), $AA);
    AssertEquals('MemFindByte parity', LFindFacade, LFindApi);

    LStage := 'MemDiffRange';
    LFirstApi := 0;
    LLastApi := 0;
    LFirstFacade := 0;
    LLastFacade := 0;
    LDiffApi := LApi^.MemDiffRange(@LA[0], @LB[0], Length(LA), LFirstApi, LLastApi);
    LDiffFacade := MemDiffRange(@LA[0], @LB[0], Length(LA), LFirstFacade, LLastFacade);
    AssertEquals('MemDiffRange parity(hasDiff)', LDiffFacade, LDiffApi);
    AssertEquals('MemDiffRange parity(firstDiff)', LFirstFacade, LFirstApi);
    AssertEquals('MemDiffRange parity(lastDiff)', LLastFacade, LLastApi);

    LStage := 'SumBytes';
    LSumApi := LApi^.SumBytes(@LA[0], Length(LA));
    LSumFacade := SumBytes(@LA[0], Length(LA));
    AssertEquals('SumBytes parity', LSumFacade, LSumApi);

    LStage := 'CountByte';
    LCountApi := LApi^.CountByte(@LB[0], Length(LB), $AA);
    LCountFacade := CountByte(@LB[0], Length(LB), $AA);
    AssertEquals('CountByte parity', LCountFacade, LCountApi);

    LStage := 'BitsetPopCount';
    LPopApi := LApi^.BitsetPopCount(@LA[0], Length(LA));
    LPopFacade := BitsetPopCount(@LA[0], Length(LA));
    AssertEquals('BitsetPopCount parity', LPopFacade, LPopApi);

    LStage := 'Utf8Validate';
    LUtf8Text := UTF8Encode('simd-测试-123');
    LUtfApi := LApi^.Utf8Validate(@LUtf8Text[1], Length(LUtf8Text));
    LUtfFacade := Utf8Validate(@LUtf8Text[1], Length(LUtf8Text));
    AssertEquals('Utf8Validate parity', LUtfFacade, LUtfApi);

    LStage := 'AsciiIEqual';
    LAsciiA := 'AbCdEf012';
    LAsciiB := 'aBcDeF012';
    LAsciiApi := LApi^.AsciiIEqual(@LAsciiA[1], @LAsciiB[1], Length(LAsciiA));
    LAsciiFacade := AsciiIEqual(@LAsciiA[1], @LAsciiB[1], Length(LAsciiA));
    AssertEquals('AsciiIEqual parity', LAsciiFacade, LAsciiApi);

    LStage := 'BytesIndexOf(hit)';
    LNeedle[0] := LA[7];
    LNeedle[1] := LA[8];
    LNeedle[2] := LA[9];
    LBytesApi := LApi^.BytesIndexOf(@LA[0], Length(LA), @LNeedle[0], Length(LNeedle));
    LBytesFacade := BytesIndexOf(@LA[0], Length(LA), @LNeedle[0], Length(LNeedle));
    AssertEquals('BytesIndexOf parity(hit)', LBytesFacade, LBytesApi);

    LStage := 'BytesIndexOf(miss)';
    LNeedle[0] := $FE;
    LNeedle[1] := $ED;
    LNeedle[2] := $DC;
    LBytesApi := LApi^.BytesIndexOf(@LA[0], Length(LA), @LNeedle[0], Length(LNeedle));
    LBytesFacade := BytesIndexOf(@LA[0], Length(LA), @LNeedle[0], Length(LNeedle));
    AssertEquals('BytesIndexOf parity(miss)', LBytesFacade, LBytesApi);

    LStage := 'MemCopy';
    FillChar(LCopyApi[0], SizeOf(LCopyApi), 0);
    FillChar(LCopyFacade[0], SizeOf(LCopyFacade), 0);
    LApi^.MemCopy(@LA[0], @LCopyApi[0], Length(LA));
    MemCopy(@LA[0], @LCopyFacade[0], Length(LA));
    AssertTrue('MemCopy parity', MemEqual(@LCopyApi[0], @LCopyFacade[0], Length(LA)));

    LStage := 'MemSet';
    FillChar(LFillApi[0], SizeOf(LFillApi), 0);
    FillChar(LFillFacade[0], SizeOf(LFillFacade), 0);
    LApi^.MemSet(@LFillApi[0], Length(LFillApi), $5A);
    MemSet(@LFillFacade[0], Length(LFillFacade), $5A);
    AssertTrue('MemSet parity', MemEqual(@LFillApi[0], @LFillFacade[0], Length(LFillApi)));

    LStage := 'ToLowerAscii';
    LLowerApi := 'AbCdEf012';
    LLowerFacade := LLowerApi;
    UniqueString(LLowerApi);
    UniqueString(LLowerFacade);
    LApi^.ToLowerAscii(PAnsiChar(LLowerApi), Length(LLowerApi));
    ToLowerAscii(PAnsiChar(LLowerFacade), Length(LLowerFacade));
    AssertEquals('ToLowerAscii parity', LLowerFacade, LLowerApi);
    AssertEquals('ToLowerAscii expected', 'abcdef012', LLowerApi);

    LStage := 'ToUpperAscii';
    LUpperApi := 'AbCdEf012';
    LUpperFacade := LUpperApi;
    UniqueString(LUpperApi);
    UniqueString(LUpperFacade);
    LApi^.ToUpperAscii(PAnsiChar(LUpperApi), Length(LUpperApi));
    ToUpperAscii(PAnsiChar(LUpperFacade), Length(LUpperFacade));
    AssertEquals('ToUpperAscii parity', LUpperFacade, LUpperApi);
    AssertEquals('ToUpperAscii expected', 'ABCDEF012', LUpperApi);

    LStage := 'MemReverse';
    LRevApi[0] := 1;
    LRevApi[1] := 2;
    LRevApi[2] := 3;
    LRevApi[3] := 4;
    LRevApi[4] := 5;
    LRevApi[5] := 6;
    LRevApi[6] := 7;
    LRevApi[7] := 8;
    LRevFacade := LRevApi;
    LApi^.MemReverse(@LRevApi[0], Length(LRevApi));
    MemReverse(@LRevFacade[0], Length(LRevFacade));
    AssertTrue('MemReverse parity', MemEqual(@LRevApi[0], @LRevFacade[0], Length(LRevApi)));

    LStage := 'MinMaxBytes';
    LMinApi := 0;
    LMaxApi := 0;
    LMinFacade := 0;
    LMaxFacade := 0;
    LApi^.MinMaxBytes(@LA[0], Length(LA), LMinApi, LMaxApi);
    MinMaxBytes(@LA[0], Length(LA), LMinFacade, LMaxFacade);
    AssertEquals('MinMaxBytes parity(min)', LMinFacade, LMinApi);
    AssertEquals('MinMaxBytes parity(max)', LMaxFacade, LMaxApi);
  except
    on E: Exception do
      Fail(Format('Public ABI data-plane stage %s raised %s: %s', [LStage, E.ClassName, E.Message]));
  end;
end;

procedure TTestCase_PublicAbi.Test_PublicApi_V1_And_V2_DataPlane_Parity;
var
  LApiV1: PFafafaSimdPublicApi;
  LApiV2: PFafafaSimdPublicApiV2;
  LA, LB: array[0..31] of Byte;
  LNeedle: array[0..2] of Byte;
  LFirstV1: SizeUInt;
  LLastV1: SizeUInt;
  LFirstV2: SizeUInt;
  LLastV2: SizeUInt;
  LMinV1: Byte;
  LMaxV1: Byte;
  LMinV2: Byte;
  LMaxV2: Byte;
  LIdx: Integer;
begin
  LApiV1 := GetSimdPublicApi;
  LApiV2 := GetSimdPublicApiV2;
  AssertNotNull('Public API v1 table should not be nil', LApiV1);
  AssertNotNull('Public API v2 table should not be nil', LApiV2);

  for LIdx := 0 to High(LA) do
  begin
    LA[LIdx] := Byte((LIdx * 9) and $FF);
    LB[LIdx] := LA[LIdx];
  end;
  LB[11] := $AA;
  LNeedle[0] := LA[4];
  LNeedle[1] := LA[5];
  LNeedle[2] := LA[6];

  AssertEquals('MemEqual parity between v1/v2',
    LApiV1^.MemEqual(@LA[0], @LA[0], Length(LA)),
    LApiV2^.MemEqual(@LA[0], @LA[0], Length(LA)));
  AssertEquals('MemFindByte parity between v1/v2',
    LApiV1^.MemFindByte(@LB[0], Length(LB), $AA),
    LApiV2^.MemFindByte(@LB[0], Length(LB), $AA));
  AssertEquals('SumBytes parity between v1/v2',
    LApiV1^.SumBytes(@LA[0], Length(LA)),
    LApiV2^.SumBytes(@LA[0], Length(LA)));
  AssertEquals('CountByte parity between v1/v2',
    LApiV1^.CountByte(@LB[0], Length(LB), $AA),
    LApiV2^.CountByte(@LB[0], Length(LB), $AA));
  AssertEquals('BitsetPopCount parity between v1/v2',
    LApiV1^.BitsetPopCount(@LA[0], Length(LA)),
    LApiV2^.BitsetPopCount(@LA[0], Length(LA)));
  AssertEquals('AsciiIEqual parity between v1/v2',
    LApiV1^.AsciiIEqual(PChar('AbCd'), PChar('aBcD'), 4),
    LApiV2^.AsciiIEqual(PChar('AbCd'), PChar('aBcD'), 4));
  AssertEquals('BytesIndexOf parity between v1/v2',
    LApiV1^.BytesIndexOf(@LA[0], Length(LA), @LNeedle[0], Length(LNeedle)),
    LApiV2^.BytesIndexOf(@LA[0], Length(LA), @LNeedle[0], Length(LNeedle)));

  LFirstV1 := 0;
  LLastV1 := 0;
  LFirstV2 := 0;
  LLastV2 := 0;
  AssertEquals('MemDiffRange parity(hasDiff) between v1/v2',
    LApiV1^.MemDiffRange(@LA[0], @LB[0], Length(LA), LFirstV1, LLastV1),
    LApiV2^.MemDiffRange(@LA[0], @LB[0], Length(LA), LFirstV2, LLastV2));
  AssertEquals('MemDiffRange firstDiff parity between v1/v2', LFirstV1, LFirstV2);
  AssertEquals('MemDiffRange lastDiff parity between v1/v2', LLastV1, LLastV2);

  LMinV1 := 0;
  LMaxV1 := 0;
  LMinV2 := 0;
  LMaxV2 := 0;
  LApiV1^.MinMaxBytes(@LB[0], Length(LB), LMinV1, LMaxV1);
  LApiV2^.MinMaxBytes(@LB[0], Length(LB), LMinV2, LMaxV2);
  AssertEquals('MinMaxBytes min parity between v1/v2', LMinV1, LMinV2);
  AssertEquals('MinMaxBytes max parity between v1/v2', LMaxV1, LMaxV2);
end;

initialization
  RegisterTest(TTestCase_PublicAbi);

end.
