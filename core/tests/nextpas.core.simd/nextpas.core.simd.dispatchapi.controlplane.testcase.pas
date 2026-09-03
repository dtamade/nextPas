unit nextpas.core.simd.dispatchapi.controlplane.testcase;

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
  nextpas.core.simd.dispatchapi.support;

type
  TTestCase_DispatchAPIControlPlane = class(TDispatchAPIStatefulTestCase)
  published
    procedure Test_TryForceBackend_Scalar_ReturnsTrue;
    procedure Test_TryForceBackend_Unavailable_NoChange;
    procedure Test_TrySetActiveBackend_Scalar_ReturnsTrue;
    procedure Test_TrySetActiveBackend_Unavailable_NoChange;
    procedure Test_TrySetActiveBackend_Fails_When_HookReRegister_ReSelects_Away;
    procedure Test_TrySetActiveBackend_FailedHookMutation_DoesNotLeave_LingeringForcedSelection;
    procedure Test_TrySetActiveBackend_FailedHookMutation_Restores_AutomaticBackend;
    procedure Test_TrySetActiveBackend_FailedHookMutation_Restores_PreviousForcedBackend;
    procedure Test_TrySetActiveBackend_RollbackRestore_ReSelects_RequestedBackend_Before_Return;
    procedure Test_TrySetActiveBackend_RollbackRestore_Success_Preserves_ForcedSelection;
    procedure Test_TrySetActiveBackend_RollbackRestore_Success_FromPreviousForcedState_Preserves_RequestedSelection;
    procedure Test_TrySetActiveBackend_RollbackRestore_Success_FromPreviousForcedState_LateForce_DuringThirdRestore_Preserves_RequestedSelection;
    procedure Test_TrySetActiveBackend_RollbackRestore_Success_FromPreviousForcedState_LateForce_UntilAttemptCap_Restores_PreviousStableState;
    procedure Test_TrySetActiveBackend_RollbackRestore_Success_FromLowerPriorityPreviousForcedState_LateForce_UntilAttemptCap_Restores_PreviousStableState;
    procedure Test_TrySetActiveBackend_RollbackRestore_Success_LateForce_DuringThirdRestore_Preserves_ForcedSelection;
    procedure Test_TrySetActiveBackend_RollbackRestore_Success_LateForce_UntilAttemptCap_Restores_AutomaticIntent;
    procedure Test_TrySetActiveBackend_RollbackRestore_LateForce_Restores_AutomaticBackend;
    procedure Test_TrySetActiveBackend_RollbackRestore_LateForce_DuringRestore_Restores_AutomaticBackend;
    procedure Test_TrySetActiveBackend_RollbackRestore_LateForce_DuringThirdRestore_Restores_AutomaticBackend;
    procedure Test_TrySetActiveBackend_RollbackRestore_LateForce_UntilAttemptCap_Restores_AutomaticBackend;
    procedure Test_TrySetActiveBackend_RollbackRestore_LateForce_Preserves_PreviousForcedBackend;
    procedure Test_TrySetActiveBackend_RollbackRestore_LateForce_DuringThirdRestore_Preserves_PreviousForcedBackend;
    procedure Test_SetActiveBackend_Unavailable_FallsBackToScalar;
    procedure Test_SetActiveBackend_HookLateFailure_Preserves_PreviousForcedBackend;
    procedure Test_ResetToAutomaticBackend_HookLateForce_Restores_AutomaticBackend;
    procedure Test_ResetToAutomaticBackend_HookLateForce_DuringRestore_Restores_AutomaticBackend;
    procedure Test_ResetToAutomaticBackend_HookLateForce_DuringThirdRestore_Restores_AutomaticBackend;
    procedure Test_ResetToAutomaticBackend_HookLateForce_UntilAttemptCap_Restores_AutomaticBackend;
    procedure Test_SetVectorAsmEnabled_HookLateForce_Restores_AutomaticBackend;
    procedure Test_SetVectorAsmEnabled_HookLateForce_DuringRestore_Restores_AutomaticBackend;
    procedure Test_SetVectorAsmEnabled_HookLateForce_DuringThirdRestore_Restores_AutomaticBackend;
    procedure Test_SetVectorAsmEnabled_HookLateForce_UntilAttemptCap_Restores_AutomaticBackend;
    procedure Test_SetVectorAsmEnabled_HookLateAutomaticReset_Preserves_PreviousForcedBackend;
    procedure Test_SetVectorAsmEnabled_HookLateAutomaticReset_DuringRestore_Preserves_PreviousForcedBackend;
    procedure Test_SetVectorAsmEnabled_HookLateForce_DuringRestore_Preserves_PreviousForcedBackend;
    procedure Test_SetVectorAsmEnabled_HookLateForce_DuringThirdRestore_Preserves_PreviousForcedBackend;
    procedure Test_SetVectorAsmEnabled_HookLateForce_UntilAttemptCap_Preserves_PreviousForcedBackend;
    procedure Test_RegisterBackend_HookLateForce_Restores_AutomaticBackend;
    procedure Test_RegisterBackend_HookLateForce_DuringThirdRestore_Restores_AutomaticBackend;
    procedure Test_RegisterBackend_HookLateAutomaticReset_Preserves_PreviousForcedBackend;
    procedure Test_RegisterBackend_HookLateForce_DuringRestore_Preserves_PreviousForcedBackend;
    procedure Test_RegisterBackend_HookLateForce_DuringThirdRestore_Preserves_PreviousForcedBackend;
    procedure Test_RegisterBackend_HookLateForce_UntilAttemptCap_Restores_AutomaticBackend;
    procedure Test_RegisterBackend_HookLateForce_UntilAttemptCap_Preserves_PreviousForcedBackend;
    procedure Test_DispatchChangedHooks_MultiSubscriber_Dedup_And_Remove;
    procedure Test_BackendInfoAvailableFalse_IsNotSelectable;
    procedure Test_RegisterBackend_Canonicalizes_TableIdentity_For_ForcedSelection;
    procedure Test_SupportedAliases_StayCpuOnly_WhenBackendBecomesNonDispatchable;
    procedure Test_PublicSmokeDefaultBackendPredictor_Tracks_CanonicalDispatchPriority;
    procedure Test_VectorAsmDisabled_ReSelects_Away_From_ScalarBacked_CurrentBackend;
    procedure Test_BackendConceptViews_AreSelfConsistent;
    procedure Test_GetAvailableBackendList_AliasesDispatchableView;
    procedure Test_RegisteredBackendPriority_MatchesCanonicalPriority;
    procedure Test_UnregisteredBackendInfo_PreservesCanonicalTextMetadata;
    procedure Test_RegisterBackend_SameBackendRoundTrip_Reuses_PreviouslyPublishedDispatchSnapshot;
    procedure Test_SetVectorAsmEnabled_RoundTrip_Reuses_PreviouslyPublishedDispatchSnapshot;
    procedure Test_RegisteredBackendDispatchTable_PreservesCanonicalTextMetadata_After_ReRegister;
    procedure Test_CurrentBackendInfo_PreservesCanonicalTextMetadata_After_ReRegister;
    procedure Test_CurrentBackendHelpers_StayAligned_After_ControlPlaneSwitches;
  end;

  TTestCase_RISCVFallbackDispatchContract = class(TDispatchAPIStatefulTestCase)
  published
    procedure Test_ScalarAndCurrentDispatch_Keep_RepresentativeWideSlots_Assigned;
    procedure Test_RollbackRestoreSuccess_Keep_RepresentativeWideSlots_Assigned;
  end;

implementation

procedure DispatchHookProbeA;
begin
  Inc(GDispatchHookCountA);
end;

procedure DispatchHookProbeB;
begin
  Inc(GDispatchHookCountB);
end;

procedure DispatchHookDisableBackendOnce;
var
  LModifiedTable: TSimdDispatchTable;
begin
  if not GDispatchHookDisableBackendEnabled then
    Exit;

  if not GDispatchHookDisableBackendArmed then
  begin
    GDispatchHookDisableBackendArmed := True;
    Exit;
  end;

  if GDispatchHookDisableBackendDone then
    Exit;

  GDispatchHookDisableBackendDone := True;
  LModifiedTable := GDispatchHookDisableBackendOriginalTable;
  LModifiedTable.BackendInfo.Available := False;
  RegisterBackend(GDispatchHookDisableBackendTarget, LModifiedTable);
end;

procedure DispatchHookDisableThenRestoreBackendOnRollback;
var
  LModifiedTable: TSimdDispatchTable;
begin
  if not GDispatchHookRestoreBackendEnabled then
    Exit;

  case GDispatchHookRestoreBackendStage of
    0:
      begin
        // Immediate callback on AddDispatchChangedHook arms the synthetic sequence.
        GDispatchHookRestoreBackendStage := 1;
        Exit;
      end;
    1:
      begin
        // First real dispatch-change callback: make requested backend unavailable
        // so the forced-selection attempt fails.
        GDispatchHookRestoreBackendStage := 2;
        LModifiedTable := GDispatchHookRestoreBackendOriginalTable;
        LModifiedTable.BackendInfo.Available := False;
        RegisterBackend(GDispatchHookRestoreBackendTarget, LModifiedTable);
        Exit;
      end;
    2:
      begin
        // Nested forced-fallback reinitialize callback triggered by the disable
        // RegisterBackend. Ignore it and wait for the failure-rollback callback.
        GDispatchHookRestoreBackendStage := 3;
        Exit;
      end;
    3:
      begin
        // Failure rollback has already cleared forced mode and re-entered
        // automatic selection. Restore the requested backend before the API
        // returns so return-value and return-time state must agree.
        GDispatchHookRestoreBackendStage := 4;
        RegisterBackend(GDispatchHookRestoreBackendTarget, GDispatchHookRestoreBackendOriginalTable);
        Exit;
      end;
  end;
end;

procedure DispatchHookRollbackForceSuccessWithoutForcedIntent;
var
  LModifiedTable: TSimdDispatchTable;
  LIndex: Integer;
begin
  if not GDispatchHookRollbackForceSuccessEnabled then
    Exit;

  if GDispatchHookRollbackForceSuccessInMutation then
    Exit;

  case GDispatchHookRollbackForceSuccessStage of
    0:
      begin
        GDispatchHookRollbackForceSuccessStage := 1;
        Exit;
      end;
    1:
      begin
        GDispatchHookRollbackForceSuccessStage := 2;
        GDispatchHookRollbackForceSuccessInMutation := True;
        try
          LModifiedTable := GDispatchHookRollbackForceSuccessTargetTable;
          LModifiedTable.BackendInfo.Available := False;
          RegisterBackend(GDispatchHookRollbackForceSuccessTarget, LModifiedTable);
        finally
          GDispatchHookRollbackForceSuccessInMutation := False;
        end;
        Exit;
      end;
    2:
      begin
        GDispatchHookRollbackForceSuccessStage := 3;
        GDispatchHookRollbackForceSuccessInMutation := True;
        try
          RegisterBackend(GDispatchHookRollbackForceSuccessTarget, GDispatchHookRollbackForceSuccessTargetTable);
          for LIndex := 0 to GDispatchHookRollbackForceSuccessHigherCount - 1 do
          begin
            LModifiedTable := GDispatchHookRollbackForceSuccessHigherTables[LIndex];
            LModifiedTable.BackendInfo.Available := False;
            RegisterBackend(GDispatchHookRollbackForceSuccessHigherBackends[LIndex], LModifiedTable);
          end;
        finally
          GDispatchHookRollbackForceSuccessInMutation := False;
        end;
        Exit;
      end;
  end;
end;

procedure DispatchHookRollbackForceSuccessThenLateForceOnThirdRestore;
var
  LModifiedTable: TSimdDispatchTable;
  LIndex: Integer;
begin
  if not GDispatchHookRollbackForceSuccessEnabled then
    Exit;

  if GDispatchHookRollbackForceSuccessInMutation then
    Exit;

  case GDispatchHookRollbackForceSuccessStage of
    0:
      begin
        GDispatchHookRollbackForceSuccessStage := 1;
        Exit;
      end;
    1:
      begin
        GDispatchHookRollbackForceSuccessStage := 2;
        GDispatchHookRollbackForceSuccessInMutation := True;
        try
          LModifiedTable := GDispatchHookRollbackForceSuccessTargetTable;
          LModifiedTable.BackendInfo.Available := False;
          RegisterBackend(GDispatchHookRollbackForceSuccessTarget, LModifiedTable);
        finally
          GDispatchHookRollbackForceSuccessInMutation := False;
        end;
        Exit;
      end;
    2:
      begin
        GDispatchHookRollbackForceSuccessStage := 3;
        GDispatchHookRollbackForceSuccessInMutation := True;
        try
          RegisterBackend(GDispatchHookRollbackForceSuccessTarget, GDispatchHookRollbackForceSuccessTargetTable);
          for LIndex := 0 to GDispatchHookRollbackForceSuccessHigherCount - 1 do
          begin
            LModifiedTable := GDispatchHookRollbackForceSuccessHigherTables[LIndex];
            LModifiedTable.BackendInfo.Available := False;
            RegisterBackend(GDispatchHookRollbackForceSuccessHigherBackends[LIndex], LModifiedTable);
          end;
        finally
          GDispatchHookRollbackForceSuccessInMutation := False;
        end;
        Exit;
      end;
    3:
      begin
        GDispatchHookRollbackForceSuccessStage := 4;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    4:
      begin
        GDispatchHookRollbackForceSuccessStage := 5;
        Exit;
      end;
    5:
      begin
        GDispatchHookRollbackForceSuccessStage := 6;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    6:
      begin
        GDispatchHookRollbackForceSuccessStage := 7;
        Exit;
      end;
    7:
      begin
        GDispatchHookRollbackForceSuccessStage := 8;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    8:
      begin
        GDispatchHookRollbackForceSuccessStage := 9;
        Exit;
      end;
  end;
end;

procedure DispatchHookRollbackForceSuccessThenLateForceUntilAttemptCap;
var
  LModifiedTable: TSimdDispatchTable;
  LIndex: Integer;
begin
  if not GDispatchHookRollbackForceSuccessEnabled then
    Exit;

  if GDispatchHookRollbackForceSuccessInMutation then
    Exit;

  case GDispatchHookRollbackForceSuccessStage of
    0:
      begin
        GDispatchHookRollbackForceSuccessStage := 1;
        Exit;
      end;
    1:
      begin
        GDispatchHookRollbackForceSuccessStage := 2;
        GDispatchHookRollbackForceSuccessInMutation := True;
        try
          LModifiedTable := GDispatchHookRollbackForceSuccessTargetTable;
          LModifiedTable.BackendInfo.Available := False;
          RegisterBackend(GDispatchHookRollbackForceSuccessTarget, LModifiedTable);
        finally
          GDispatchHookRollbackForceSuccessInMutation := False;
        end;
        Exit;
      end;
    2:
      begin
        GDispatchHookRollbackForceSuccessStage := 3;
        GDispatchHookRollbackForceSuccessInMutation := True;
        try
          RegisterBackend(GDispatchHookRollbackForceSuccessTarget, GDispatchHookRollbackForceSuccessTargetTable);
          for LIndex := 0 to GDispatchHookRollbackForceSuccessHigherCount - 1 do
          begin
            LModifiedTable := GDispatchHookRollbackForceSuccessHigherTables[LIndex];
            LModifiedTable.BackendInfo.Available := False;
            RegisterBackend(GDispatchHookRollbackForceSuccessHigherBackends[LIndex], LModifiedTable);
          end;
        finally
          GDispatchHookRollbackForceSuccessInMutation := False;
        end;
        Exit;
      end;
    3, 5, 7, 9, 11, 13, 15, 17:
      begin
        Inc(GDispatchHookRollbackForceSuccessStage);
        SetActiveBackend(sbScalar);
        Exit;
      end;
    4, 6, 8, 10, 12, 14, 16, 18:
      begin
        Inc(GDispatchHookRollbackForceSuccessStage);
        Exit;
      end;
    19:
      begin
        GDispatchHookRollbackForceSuccessStage := 20;
        Exit;
      end;
  end;
end;

procedure DispatchHookReForceBackendOnce;
begin
  if not GDispatchHookReForceBackendEnabled then
    Exit;

  case GDispatchHookReForceBackendStage of
    0:
      begin
        GDispatchHookReForceBackendStage := 1;
        Exit;
      end;
    1:
      begin
        GDispatchHookReForceBackendStage := 2;
        SetActiveBackend(GDispatchHookReForceBackendTarget);
        Exit;
      end;
  end;
end;

procedure DispatchHookResetToAutomaticOnce;
begin
  if not GDispatchHookResetToAutomaticEnabled then
    Exit;

  case GDispatchHookResetToAutomaticStage of
    0:
      begin
        GDispatchHookResetToAutomaticStage := 1;
        Exit;
      end;
    1:
      begin
        GDispatchHookResetToAutomaticStage := 2;
        ResetToAutomaticBackend;
        Exit;
      end;
  end;
end;

procedure DispatchHookReForceBackendOnAutomaticRestore;
begin
  if not GDispatchHookResetLateForceEnabled then
    Exit;

  case GDispatchHookResetLateForceStage of
    0:
      begin
        GDispatchHookResetLateForceStage := 1;
        Exit;
      end;
    1:
      begin
        GDispatchHookResetLateForceStage := 2;
        SetActiveBackend(GDispatchHookResetLateForceTarget);
        Exit;
      end;
    2:
      begin
        GDispatchHookResetLateForceStage := 3;
        Exit;
      end;
    3:
      begin
        GDispatchHookResetLateForceStage := 4;
        SetActiveBackend(GDispatchHookResetLateForceTarget);
        Exit;
      end;
    4:
      begin
        GDispatchHookResetLateForceStage := 5;
        Exit;
      end;
  end;
end;

procedure DispatchHookReForceBackendOnAutomaticThirdRestore;
begin
  if not GDispatchHookResetLateForceEnabled then
    Exit;

  case GDispatchHookResetLateForceStage of
    0:
      begin
        GDispatchHookResetLateForceStage := 1;
        Exit;
      end;
    1:
      begin
        GDispatchHookResetLateForceStage := 2;
        SetActiveBackend(GDispatchHookResetLateForceTarget);
        Exit;
      end;
    2:
      begin
        GDispatchHookResetLateForceStage := 3;
        Exit;
      end;
    3:
      begin
        GDispatchHookResetLateForceStage := 4;
        SetActiveBackend(GDispatchHookResetLateForceTarget);
        Exit;
      end;
    4:
      begin
        GDispatchHookResetLateForceStage := 5;
        Exit;
      end;
    5:
      begin
        GDispatchHookResetLateForceStage := 6;
        SetActiveBackend(GDispatchHookResetLateForceTarget);
        Exit;
      end;
    6:
      begin
        GDispatchHookResetLateForceStage := 7;
        Exit;
      end;
  end;
end;

procedure DispatchHookReForceBackendOnAutomaticRestoreUntilAttemptCap;
begin
  if not GDispatchHookResetLateForceEnabled then
    Exit;

  case GDispatchHookResetLateForceStage of
    0:
      begin
        GDispatchHookResetLateForceStage := 1;
        Exit;
      end;
    1, 3, 5, 7, 9, 11, 13, 15:
      begin
        Inc(GDispatchHookResetLateForceStage);
        SetActiveBackend(GDispatchHookResetLateForceTarget);
        Exit;
      end;
    2, 4, 6, 8, 10, 12, 14, 16:
      begin
        Inc(GDispatchHookResetLateForceStage);
        Exit;
      end;
    17:
      begin
        GDispatchHookResetLateForceStage := 18;
        Exit;
      end;
  end;
end;

procedure DispatchHookReForceBackendOnToggleRestoreUntilAttemptCap;
begin
  if not GDispatchHookResetLateForceEnabled then
    Exit;

  case GDispatchHookResetLateForceStage of
    0:
      begin
        GDispatchHookResetLateForceStage := 1;
        Exit;
      end;
    1, 3, 5, 7, 9, 11, 13, 15, 17:
      begin
        Inc(GDispatchHookResetLateForceStage);
        SetActiveBackend(GDispatchHookResetLateForceTarget);
        Exit;
      end;
    2, 4, 6, 8, 10, 12, 14, 16, 18:
      begin
        Inc(GDispatchHookResetLateForceStage);
        Exit;
      end;
    19:
      begin
        GDispatchHookResetLateForceStage := 20;
        Exit;
      end;
  end;
end;

procedure DispatchHookResetToAutomaticOnToggleRestore;
begin
  if not GDispatchHookToggleRestoreResetEnabled then
    Exit;

  case GDispatchHookToggleRestoreResetStage of
    0:
      begin
        GDispatchHookToggleRestoreResetStage := 1;
        Exit;
      end;
    1:
      begin
        GDispatchHookToggleRestoreResetStage := 2;
        ResetToAutomaticBackend;
        Exit;
      end;
    2:
      begin
        GDispatchHookToggleRestoreResetStage := 3;
        Exit;
      end;
    3:
      begin
        GDispatchHookToggleRestoreResetStage := 4;
        ResetToAutomaticBackend;
        Exit;
      end;
    4:
      begin
        GDispatchHookToggleRestoreResetStage := 5;
        Exit;
      end;
  end;
end;

procedure DispatchHookDisableRequestedThenLateForceOnPreviousRestore;
var
  LModifiedTable: TSimdDispatchTable;
begin
  if not GDispatchHookRollbackLateForceEnabled then
    Exit;

  case GDispatchHookRollbackLateForceStage of
    0:
      begin
        GDispatchHookRollbackLateForceStage := 1;
        Exit;
      end;
    1:
      begin
        GDispatchHookRollbackLateForceStage := 2;
        LModifiedTable := GDispatchHookRollbackLateForceRequestedTable;
        LModifiedTable.BackendInfo.Available := False;
        RegisterBackend(GDispatchHookRollbackLateForceRequestedBackend, LModifiedTable);
        Exit;
      end;
    2:
      begin
        GDispatchHookRollbackLateForceStage := 3;
        Exit;
      end;
    3:
      begin
        GDispatchHookRollbackLateForceStage := 4;
        Exit;
      end;
    4:
      begin
        GDispatchHookRollbackLateForceStage := 5;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    5:
      begin
        GDispatchHookRollbackLateForceStage := 6;
        Exit;
      end;
  end;
end;

procedure DispatchHookDisableRequestedThenLateForceOnPreviousThirdRestore;
var
  LModifiedTable: TSimdDispatchTable;
begin
  if not GDispatchHookRollbackLateForceEnabled then
    Exit;

  case GDispatchHookRollbackLateForceStage of
    0:
      begin
        GDispatchHookRollbackLateForceStage := 1;
        Exit;
      end;
    1:
      begin
        GDispatchHookRollbackLateForceStage := 2;
        LModifiedTable := GDispatchHookRollbackLateForceRequestedTable;
        LModifiedTable.BackendInfo.Available := False;
        RegisterBackend(GDispatchHookRollbackLateForceRequestedBackend, LModifiedTable);
        Exit;
      end;
    2:
      begin
        GDispatchHookRollbackLateForceStage := 3;
        Exit;
      end;
    3:
      begin
        GDispatchHookRollbackLateForceStage := 4;
        Exit;
      end;
    4:
      begin
        GDispatchHookRollbackLateForceStage := 5;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    5:
      begin
        GDispatchHookRollbackLateForceStage := 6;
        Exit;
      end;
    6:
      begin
        GDispatchHookRollbackLateForceStage := 7;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    7:
      begin
        GDispatchHookRollbackLateForceStage := 8;
        Exit;
      end;
    8:
      begin
        GDispatchHookRollbackLateForceStage := 9;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    9:
      begin
        GDispatchHookRollbackLateForceStage := 10;
        Exit;
      end;
  end;
end;

procedure DispatchHookDisableRequestedThenLateForceOnAutomaticRestore;
var
  LModifiedTable: TSimdDispatchTable;
begin
  if not GDispatchHookAutomaticRollbackLateForceEnabled then
    Exit;

  case GDispatchHookAutomaticRollbackLateForceStage of
    0:
      begin
        GDispatchHookAutomaticRollbackLateForceStage := 1;
        Exit;
      end;
    1:
      begin
        GDispatchHookAutomaticRollbackLateForceStage := 2;
        LModifiedTable := GDispatchHookAutomaticRollbackLateForceRequestedTable;
        LModifiedTable.BackendInfo.Available := False;
        RegisterBackend(GDispatchHookAutomaticRollbackLateForceRequestedBackend, LModifiedTable);
        Exit;
      end;
    2:
      begin
        GDispatchHookAutomaticRollbackLateForceStage := 3;
        Exit;
      end;
    3:
      begin
        GDispatchHookAutomaticRollbackLateForceStage := 4;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    4:
      begin
        GDispatchHookAutomaticRollbackLateForceStage := 5;
        Exit;
      end;
  end;
end;

procedure DispatchHookDisableRequestedThenLateForceOnAutomaticThirdRestore;
var
  LModifiedTable: TSimdDispatchTable;
begin
  if not GDispatchHookAutomaticRollbackRestoreLateForceEnabled then
    Exit;

  case GDispatchHookAutomaticRollbackRestoreLateForceStage of
    0:
      begin
        GDispatchHookAutomaticRollbackRestoreLateForceStage := 1;
        Exit;
      end;
    1:
      begin
        GDispatchHookAutomaticRollbackRestoreLateForceStage := 2;
        LModifiedTable := GDispatchHookAutomaticRollbackRestoreLateForceRequestedTable;
        LModifiedTable.BackendInfo.Available := False;
        RegisterBackend(GDispatchHookAutomaticRollbackRestoreLateForceRequestedBackend, LModifiedTable);
        Exit;
      end;
    2:
      begin
        GDispatchHookAutomaticRollbackRestoreLateForceStage := 3;
        Exit;
      end;
    3:
      begin
        GDispatchHookAutomaticRollbackRestoreLateForceStage := 4;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    4:
      begin
        GDispatchHookAutomaticRollbackRestoreLateForceStage := 5;
        Exit;
      end;
    5:
      begin
        GDispatchHookAutomaticRollbackRestoreLateForceStage := 6;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    6:
      begin
        GDispatchHookAutomaticRollbackRestoreLateForceStage := 7;
        Exit;
      end;
  end;
end;

procedure DispatchHookDisableRequestedThenLateForceOnAutomaticRestoreUntilAttemptCap;
var
  LModifiedTable: TSimdDispatchTable;
begin
  if not GDispatchHookAutomaticRollbackRestoreLateForceEnabled then
    Exit;

  case GDispatchHookAutomaticRollbackRestoreLateForceStage of
    0:
      begin
        GDispatchHookAutomaticRollbackRestoreLateForceStage := 1;
        Exit;
      end;
    1:
      begin
        GDispatchHookAutomaticRollbackRestoreLateForceStage := 2;
        LModifiedTable := GDispatchHookAutomaticRollbackRestoreLateForceRequestedTable;
        LModifiedTable.BackendInfo.Available := False;
        RegisterBackend(GDispatchHookAutomaticRollbackRestoreLateForceRequestedBackend, LModifiedTable);
        Exit;
      end;
    2:
      begin
        GDispatchHookAutomaticRollbackRestoreLateForceStage := 3;
        Exit;
      end;
    3, 5, 7, 9, 11, 13, 15, 17:
      begin
        Inc(GDispatchHookAutomaticRollbackRestoreLateForceStage);
        SetActiveBackend(sbScalar);
        Exit;
      end;
    4, 6, 8, 10, 12, 14, 16, 18:
      begin
        Inc(GDispatchHookAutomaticRollbackRestoreLateForceStage);
        Exit;
      end;
    19:
      begin
        GDispatchHookAutomaticRollbackRestoreLateForceStage := 20;
        Exit;
      end;
  end;
end;

procedure DispatchHookDisableRequestedThenLateForceOnAutomaticRestoreTwice;
var
  LModifiedTable: TSimdDispatchTable;
begin
  if not GDispatchHookAutomaticRollbackRestoreLateForceEnabled then
    Exit;

  case GDispatchHookAutomaticRollbackRestoreLateForceStage of
    0:
      begin
        GDispatchHookAutomaticRollbackRestoreLateForceStage := 1;
        Exit;
      end;
    1:
      begin
        GDispatchHookAutomaticRollbackRestoreLateForceStage := 2;
        LModifiedTable := GDispatchHookAutomaticRollbackRestoreLateForceRequestedTable;
        LModifiedTable.BackendInfo.Available := False;
        RegisterBackend(GDispatchHookAutomaticRollbackRestoreLateForceRequestedBackend, LModifiedTable);
        Exit;
      end;
    2:
      begin
        GDispatchHookAutomaticRollbackRestoreLateForceStage := 3;
        Exit;
      end;
    3:
      begin
        GDispatchHookAutomaticRollbackRestoreLateForceStage := 4;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    4:
      begin
        GDispatchHookAutomaticRollbackRestoreLateForceStage := 5;
        Exit;
      end;
    5:
      begin
        GDispatchHookAutomaticRollbackRestoreLateForceStage := 6;
        SetActiveBackend(sbScalar);
        Exit;
      end;
    6:
      begin
        GDispatchHookAutomaticRollbackRestoreLateForceStage := 7;
        Exit;
      end;
  end;
end;

procedure DispatchHookLateAutomaticResetOnRegisterRestore;
begin
  if not GDispatchHookRegisterRestoreResetEnabled then
    Exit;

  case GDispatchHookRegisterRestoreResetStage of
    0:
      begin
        GDispatchHookRegisterRestoreResetStage := 1;
        Exit;
      end;
    1:
      begin
        GDispatchHookRegisterRestoreResetStage := 2;
        ResetToAutomaticBackend;
        Exit;
      end;
    2:
      begin
        GDispatchHookRegisterRestoreResetStage := 3;
        Exit;
      end;
    3:
      begin
        GDispatchHookRegisterRestoreResetStage := 4;
        ResetToAutomaticBackend;
        Exit;
      end;
    4:
      begin
        GDispatchHookRegisterRestoreResetStage := 5;
        Exit;
      end;
  end;
end;

procedure DispatchHookReForceBackendOnRegisterRestoreUntilAttemptCap;
begin
  if not GDispatchHookResetLateForceEnabled then
    Exit;

  case GDispatchHookResetLateForceStage of
    0:
      begin
        GDispatchHookResetLateForceStage := 1;
        Exit;
      end;
    1, 3, 5, 7, 9, 11, 13, 15, 17:
      begin
        Inc(GDispatchHookResetLateForceStage);
        SetActiveBackend(GDispatchHookResetLateForceTarget);
        Exit;
      end;
    2, 4, 6, 8, 10, 12, 14, 16, 18:
      begin
        Inc(GDispatchHookResetLateForceStage);
        Exit;
      end;
    19:
      begin
        GDispatchHookResetLateForceStage := 20;
        Exit;
      end;
  end;
end;

{ TTestCase_DispatchAPIControlPlane }

procedure TTestCase_DispatchAPIControlPlane.Test_TryForceBackend_Scalar_ReturnsTrue;
begin
  CheckTrue(TryForceBackend(sbScalar), 'TryForceBackend(sbScalar) should succeed');
  CheckEqual(Ord(sbScalar), Ord(GetActiveBackend), 'Active backend should be Scalar after TryForceBackend');
end;

procedure TTestCase_DispatchAPIControlPlane.Test_TryForceBackend_Unavailable_NoChange;
var
  LOriginal: TSimdBackend;
begin
  LOriginal := GetActiveBackend;
  {$IFDEF CPUX86_64}
  CheckFalse(TryForceBackend(sbNEON), 'TryForceBackend(sbNEON) should fail on x86_64');
  {$ELSE}
  {$IFDEF CPUAARCH64}
  CheckFalse(TryForceBackend(sbSSE2), 'TryForceBackend(sbSSE2) should fail on AArch64');
  {$ELSE}
  CheckFalse(TryForceBackend(sbAVX512), 'TryForceBackend(sbAVX512) should fail when backend is unavailable');
  {$ENDIF}
  {$ENDIF}

  CheckEqual(Ord(LOriginal), Ord(GetActiveBackend), 'Active backend should remain unchanged after failed TryForceBackend');
end;

procedure TTestCase_DispatchAPIControlPlane.Test_TrySetActiveBackend_Scalar_ReturnsTrue;
begin
  CheckTrue(TrySetActiveBackend(sbScalar), 'TrySetActiveBackend(sbScalar) should succeed');
  CheckEqual(Ord(sbScalar), Ord(GetActiveBackend), 'Active backend should be Scalar after TrySetActiveBackend');
end;

procedure TTestCase_DispatchAPIControlPlane.Test_TrySetActiveBackend_Unavailable_NoChange;
var
  LOriginal: TSimdBackend;
begin
  LOriginal := GetActiveBackend;
  {$IFDEF CPUX86_64}
  CheckFalse(TrySetActiveBackend(sbNEON), 'TrySetActiveBackend(sbNEON) should fail on x86_64');
  {$ELSE}
  {$IFDEF CPUAARCH64}
  CheckFalse(TrySetActiveBackend(sbSSE2), 'TrySetActiveBackend(sbSSE2) should fail on AArch64');
  {$ELSE}
  CheckFalse(TrySetActiveBackend(sbAVX512), 'TrySetActiveBackend(sbAVX512) should fail when backend is unavailable');
  {$ENDIF}
  {$ENDIF}

  CheckEqual(Ord(LOriginal), Ord(GetActiveBackend), 'Active backend should remain unchanged after failed TrySetActiveBackend');
end;

procedure TTestCase_DispatchAPIControlPlane.Test_TrySetActiveBackend_Fails_When_HookReRegister_ReSelects_Away;
var
  LRequestedBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LRequestedBackend := GetActiveBackend;
  if LRequestedBackend = sbScalar then
    Exit;

  CheckTrue(TryGetRegisteredBackendDispatchTable(LRequestedBackend, LOriginalTable), 'Requested backend should be registered for hook-driven reselection test');
  CheckTrue(IsBackendDispatchable(LRequestedBackend), 'Requested backend should start dispatchable before hook-driven mutation');

  GDispatchHookDisableBackendOriginalTable := LOriginalTable;
  GDispatchHookDisableBackendTarget := LRequestedBackend;
  GDispatchHookDisableBackendEnabled := True;
  GDispatchHookDisableBackendArmed := False;
  GDispatchHookDisableBackendDone := False;
  AddDispatchChangedHook(@DispatchHookDisableBackendOnce);
  try
    CheckFalse(TrySetActiveBackend(LRequestedBackend), 'TrySetActiveBackend should fail when a dispatch-changed hook re-registers the requested backend as non-dispatchable before the call completes');
    CheckFalse(IsBackendDispatchable(LRequestedBackend), 'Hook-driven re-register should leave the requested backend non-dispatchable');
    CheckTrue(GetActiveBackend <> LRequestedBackend, 'Final active backend should move away from the requested backend after hook-driven re-selection');
    CheckEqual(Ord(GetBestDispatchableBackend), Ord(GetActiveBackend), 'Failed forced selection should return to the best remaining automatic backend when the requested backend becomes non-dispatchable before the call completes');
  finally
    RemoveDispatchChangedHook(@DispatchHookDisableBackendOnce);
    GDispatchHookDisableBackendEnabled := False;
    GDispatchHookDisableBackendArmed := False;
    GDispatchHookDisableBackendDone := False;
    RegisterBackend(LRequestedBackend, LOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_TrySetActiveBackend_FailedHookMutation_DoesNotLeave_LingeringForcedSelection;
var
  LAutomaticBackend: TSimdBackend;
  LRequestedBackend: TSimdBackend;
  LDispatchable: TSimdBackendArray;
  LOriginalTable: TSimdDispatchTable;
  LIndex: Integer;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LAutomaticBackend := GetActiveBackend;
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

  CheckTrue(TryGetRegisteredBackendDispatchTable(LRequestedBackend, LOriginalTable), 'Requested backend should be registered for lingering forced-selection test');
  CheckTrue(IsBackendDispatchable(LRequestedBackend), 'Requested backend should start dispatchable before hook-driven lingering-force test');

  GDispatchHookDisableBackendOriginalTable := LOriginalTable;
  GDispatchHookDisableBackendTarget := LRequestedBackend;
  GDispatchHookDisableBackendEnabled := True;
  GDispatchHookDisableBackendArmed := False;
  GDispatchHookDisableBackendDone := False;
  AddDispatchChangedHook(@DispatchHookDisableBackendOnce);
  try
    CheckFalse(TrySetActiveBackend(LRequestedBackend), 'TrySetActiveBackend should fail when hook-driven re-register makes the requested backend non-dispatchable before completion');
    CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'Failed forced selection should immediately return to automatic best backend after rollback');
  finally
    RemoveDispatchChangedHook(@DispatchHookDisableBackendOnce);
    GDispatchHookDisableBackendEnabled := False;
    GDispatchHookDisableBackendArmed := False;
    GDispatchHookDisableBackendDone := False;
  end;

  RegisterBackend(LRequestedBackend, LOriginalTable);
  CheckTrue(IsBackendDispatchable(LRequestedBackend), 'Requested backend should become dispatchable again after restoring its original table');
  CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'A failed TrySetActiveBackend must not leave lingering forced state that revives the requested backend on later re-register');
  CheckTrue(GetActiveBackend <> LRequestedBackend, 'Current backend should stay away from the previously failed requested backend after restore');
end;

procedure TTestCase_DispatchAPIControlPlane.Test_TrySetActiveBackend_FailedHookMutation_Restores_AutomaticBackend;
var
  LAutomaticBackend: TSimdBackend;
  LRequestedBackend: TSimdBackend;
  LDispatchable: TSimdBackendArray;
  LOriginalTable: TSimdDispatchTable;
  LIndex: Integer;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LAutomaticBackend := GetActiveBackend;
  if LAutomaticBackend = sbScalar then
    Exit;

  CheckEqual(Ord(LAutomaticBackend), Ord(GetBestDispatchableBackend), 'Automatic selection should start from best dispatchable backend before failed hook-mutation restore test');

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

  CheckTrue(TryGetRegisteredBackendDispatchTable(LRequestedBackend, LOriginalTable), 'Requested backend should be registered for failed-hook automatic-restore test');
  CheckTrue(IsBackendDispatchable(LRequestedBackend), 'Requested backend should start dispatchable before failed-hook automatic-restore test');

  GDispatchHookDisableBackendOriginalTable := LOriginalTable;
  GDispatchHookDisableBackendTarget := LRequestedBackend;
  GDispatchHookDisableBackendEnabled := True;
  GDispatchHookDisableBackendArmed := False;
  GDispatchHookDisableBackendDone := False;
  AddDispatchChangedHook(@DispatchHookDisableBackendOnce);
  try
    CheckFalse(TrySetActiveBackend(LRequestedBackend), 'TrySetActiveBackend should fail when hook-driven mutation makes the requested backend non-dispatchable before automatic restore');
    CheckFalse(IsBackendDispatchable(LRequestedBackend), 'Hook-driven mutation should leave the requested backend non-dispatchable until the test restores its table');
    CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'A failed TrySetActiveBackend should restore automatic best backend instead of leaving scalar forced fallback active');
    CheckTrue(GetActiveBackend <> sbScalar, 'Failed hook-driven selection should not leave Scalar active when automatic mode has a better backend');
  finally
    RemoveDispatchChangedHook(@DispatchHookDisableBackendOnce);
    GDispatchHookDisableBackendEnabled := False;
    GDispatchHookDisableBackendArmed := False;
    GDispatchHookDisableBackendDone := False;
    RegisterBackend(LRequestedBackend, LOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_TrySetActiveBackend_FailedHookMutation_Restores_PreviousForcedBackend;
var
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

    CheckTrue(LPreviousForcedBackend <> LAutomaticBackend, 'Previous forced backend should differ from automatic best backend in previous-forced rollback test');
    CheckTrue(TrySetActiveBackend(LPreviousForcedBackend), 'Previous forced backend setup should succeed before late-failure rollback test');
    CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Previous forced backend should be active before attempting the failing switch');

    CheckTrue(TryGetRegisteredBackendDispatchTable(LRequestedBackend, LRequestedOriginalTable), 'Requested backend should be registered for previous-forced rollback test');
    LRequestedTableCaptured := True;
    CheckTrue(IsBackendDispatchable(LRequestedBackend), 'Requested backend should start dispatchable before previous-forced rollback test');

    GDispatchHookDisableBackendOriginalTable := LRequestedOriginalTable;
    GDispatchHookDisableBackendTarget := LRequestedBackend;
    GDispatchHookDisableBackendEnabled := True;
    GDispatchHookDisableBackendArmed := False;
    GDispatchHookDisableBackendDone := False;
    AddDispatchChangedHook(@DispatchHookDisableBackendOnce);
    try
      CheckFalse(TrySetActiveBackend(LRequestedBackend), 'TrySetActiveBackend should fail when hook-driven mutation makes the requested backend non-dispatchable after a different backend was already forced');
      CheckFalse(IsBackendDispatchable(LRequestedBackend), 'Hook-driven mutation should leave the requested backend non-dispatchable until the test restores its table');
      CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'A failed TrySetActiveBackend must restore the previously forced backend instead of reverting to automatic best backend');
    finally
      RemoveDispatchChangedHook(@DispatchHookDisableBackendOnce);
      GDispatchHookDisableBackendEnabled := False;
      GDispatchHookDisableBackendArmed := False;
      GDispatchHookDisableBackendDone := False;
    end;

    RegisterBackend(LRequestedBackend, LRequestedOriginalTable);
    CheckTrue(IsBackendDispatchable(LRequestedBackend), 'Requested backend should become dispatchable again after restoring its original table in previous-forced rollback test');
    CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Restoring the requested backend table after a failed switch must keep the previous forced backend active');
  finally
    if LRequestedTableCaptured then
      RegisterBackend(LRequestedBackend, LRequestedOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_TrySetActiveBackend_RollbackRestore_ReSelects_RequestedBackend_Before_Return;
var
  LRequestedBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LRequestedBackend := GetActiveBackend;
  if LRequestedBackend = sbScalar then
    Exit;

  CheckEqual(Ord(LRequestedBackend), Ord(GetBestDispatchableBackend), 'Automatic selection should start from best dispatchable backend before rollback-restore consistency test');
  CheckTrue(TryGetRegisteredBackendDispatchTable(LRequestedBackend, LOriginalTable), 'Requested backend should be registered for rollback-restore consistency test');
  CheckTrue(IsBackendDispatchable(LRequestedBackend), 'Requested backend should start dispatchable before rollback-restore consistency test');

  GDispatchHookRestoreBackendOriginalTable := LOriginalTable;
  GDispatchHookRestoreBackendTarget := LRequestedBackend;
  GDispatchHookRestoreBackendEnabled := True;
  GDispatchHookRestoreBackendStage := 0;
  AddDispatchChangedHook(@DispatchHookDisableThenRestoreBackendOnRollback);
  try
    CheckTrue(TrySetActiveBackend(LRequestedBackend), 'TrySetActiveBackend should report success when rollback-time restore makes the requested backend active again before return');
    CheckEqual(Ord(LRequestedBackend), Ord(GetActiveBackend), 'Return-time active backend should stay on the requested backend after rollback-time restore');
    CheckEqual(4, GDispatchHookRestoreBackendStage, 'Synthetic rollback-restore hook should complete all expected stages');
  finally
    RemoveDispatchChangedHook(@DispatchHookDisableThenRestoreBackendOnRollback);
    GDispatchHookRestoreBackendEnabled := False;
    GDispatchHookRestoreBackendStage := 0;
    RegisterBackend(LRequestedBackend, LOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_TrySetActiveBackend_RollbackRestore_Success_Preserves_ForcedSelection;
var
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LRequestedBackend: TSimdBackend;
  LBackend: TSimdBackend;
  LTargetTableCaptured: Boolean;
  LIndex: Integer;
begin
  LTargetTableCaptured := False;
  GDispatchHookRollbackForceSuccessHigherCount := 0;
  GDispatchHookRollbackForceSuccessTarget := sbScalar;
  GDispatchHookRollbackForceSuccessTargetTable := Default(TSimdDispatchTable);
  GDispatchHookRollbackForceSuccessStage := 0;
  GDispatchHookRollbackForceSuccessEnabled := False;
  GDispatchHookRollbackForceSuccessInMutation := False;
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

    CheckTrue(TryGetRegisteredBackendDispatchTable(LRequestedBackend, GDispatchHookRollbackForceSuccessTargetTable), 'Requested backend should be registered for rollback forced-success preservation test');
    LTargetTableCaptured := True;

    GDispatchHookRollbackForceSuccessHigherCount := 0;
    for LBackend in LDispatchable do
    begin
      if LBackend = LRequestedBackend then
        Break;
      if LBackend = sbScalar then
        Continue;
      CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, GDispatchHookRollbackForceSuccessHigherTables[GDispatchHookRollbackForceSuccessHigherCount]), 'Higher-priority backend should be registered for rollback forced-success preservation test');
      GDispatchHookRollbackForceSuccessHigherBackends[GDispatchHookRollbackForceSuccessHigherCount] := LBackend;
      Inc(GDispatchHookRollbackForceSuccessHigherCount);
    end;
    CheckTrue(GDispatchHookRollbackForceSuccessHigherCount > 0, 'Rollback forced-success preservation test requires at least one higher-priority backend to suppress');

    GDispatchHookRollbackForceSuccessTarget := LRequestedBackend;
    GDispatchHookRollbackForceSuccessEnabled := True;
    GDispatchHookRollbackForceSuccessStage := 0;
    GDispatchHookRollbackForceSuccessInMutation := False;
    AddDispatchChangedHook(@DispatchHookRollbackForceSuccessWithoutForcedIntent);
    try
      CheckTrue(TrySetActiveBackend(LRequestedBackend), 'TrySetActiveBackend should report success when rollback-time restore reselects the requested backend');
      CheckEqual(Ord(LRequestedBackend), Ord(GetActiveBackend), 'Return-time active backend should equal the requested backend in rollback forced-success preservation test');
      CheckEqual(3, GDispatchHookRollbackForceSuccessStage, 'Synthetic rollback forced-success hook should complete all expected stages');
    finally
      RemoveDispatchChangedHook(@DispatchHookRollbackForceSuccessWithoutForcedIntent);
      GDispatchHookRollbackForceSuccessEnabled := False;
      GDispatchHookRollbackForceSuccessInMutation := False;
    end;

    for LIndex := 0 to GDispatchHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GDispatchHookRollbackForceSuccessHigherBackends[LIndex], GDispatchHookRollbackForceSuccessHigherTables[LIndex]);

    CheckEqual(Ord(LRequestedBackend), Ord(GetActiveBackend), 'A successful TrySetActiveBackend must keep the requested backend forced even after higher-priority backends are restored');
  finally
    if LTargetTableCaptured then
      RegisterBackend(GDispatchHookRollbackForceSuccessTarget, GDispatchHookRollbackForceSuccessTargetTable);
    for LIndex := 0 to GDispatchHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GDispatchHookRollbackForceSuccessHigherBackends[LIndex], GDispatchHookRollbackForceSuccessHigherTables[LIndex]);
    GDispatchHookRollbackForceSuccessHigherCount := 0;
    GDispatchHookRollbackForceSuccessTarget := sbScalar;
    GDispatchHookRollbackForceSuccessStage := 0;
    GDispatchHookRollbackForceSuccessEnabled := False;
    GDispatchHookRollbackForceSuccessInMutation := False;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_TrySetActiveBackend_RollbackRestore_Success_FromPreviousForcedState_Preserves_RequestedSelection;
var
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
  GDispatchHookRollbackForceSuccessHigherCount := 0;
  GDispatchHookRollbackForceSuccessTarget := sbScalar;
  GDispatchHookRollbackForceSuccessTargetTable := Default(TSimdDispatchTable);
  GDispatchHookRollbackForceSuccessStage := 0;
  GDispatchHookRollbackForceSuccessEnabled := False;
  GDispatchHookRollbackForceSuccessInMutation := False;
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

    CheckTrue(LPreviousForcedBackend <> LAutomaticBackend, 'Previous forced backend should differ from automatic best backend in rollback forced-success previous-state test');
    CheckTrue(TrySetActiveBackend(LPreviousForcedBackend), 'Previous forced backend setup should succeed before rollback forced-success previous-state test');
    CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Previous forced backend should be active before rollback forced-success previous-state test');

    CheckTrue(TryGetRegisteredBackendDispatchTable(LRequestedBackend, GDispatchHookRollbackForceSuccessTargetTable), 'Requested backend should be registered for rollback forced-success previous-state test');
    LTargetTableCaptured := True;

    GDispatchHookRollbackForceSuccessHigherCount := 0;
    for LBackend in LDispatchable do
    begin
      if LBackend = LRequestedBackend then
        Break;
      if LBackend = sbScalar then
        Continue;
      CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, GDispatchHookRollbackForceSuccessHigherTables[GDispatchHookRollbackForceSuccessHigherCount]), 'Higher-priority backend should be registered for rollback forced-success previous-state test');
      GDispatchHookRollbackForceSuccessHigherBackends[GDispatchHookRollbackForceSuccessHigherCount] := LBackend;
      Inc(GDispatchHookRollbackForceSuccessHigherCount);
    end;
    CheckTrue(GDispatchHookRollbackForceSuccessHigherCount > 0, 'Rollback forced-success previous-state test requires at least one higher-priority backend to suppress');

    GDispatchHookRollbackForceSuccessTarget := LRequestedBackend;
    GDispatchHookRollbackForceSuccessEnabled := True;
    GDispatchHookRollbackForceSuccessStage := 0;
    GDispatchHookRollbackForceSuccessInMutation := False;
    AddDispatchChangedHook(@DispatchHookRollbackForceSuccessWithoutForcedIntent);
    try
      CheckTrue(TrySetActiveBackend(LRequestedBackend), 'TrySetActiveBackend should report success when rollback-time restore reselects the requested backend even if the call started from a different forced backend');
      CheckEqual(Ord(LRequestedBackend), Ord(GetActiveBackend), 'Return-time active backend should switch to the requested backend instead of restoring the previous forced backend in rollback forced-success previous-state test');
      CheckEqual(3, GDispatchHookRollbackForceSuccessStage, 'Synthetic rollback forced-success previous-state hook should complete all expected stages');
    finally
      RemoveDispatchChangedHook(@DispatchHookRollbackForceSuccessWithoutForcedIntent);
      GDispatchHookRollbackForceSuccessEnabled := False;
      GDispatchHookRollbackForceSuccessInMutation := False;
    end;

    for LIndex := 0 to GDispatchHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GDispatchHookRollbackForceSuccessHigherBackends[LIndex], GDispatchHookRollbackForceSuccessHigherTables[LIndex]);

    CheckEqual(Ord(LRequestedBackend), Ord(GetActiveBackend), 'A successful TrySetActiveBackend should keep the requested backend forced even after higher-priority backends are restored when the call started from a previous forced backend');
    CheckTrue(GetActiveBackend <> LPreviousForcedBackend, 'Successful rollback forced-success previous-state path should not drift back to the pre-call forced backend');
  finally
    if LTargetTableCaptured then
      RegisterBackend(GDispatchHookRollbackForceSuccessTarget, GDispatchHookRollbackForceSuccessTargetTable);
    for LIndex := 0 to GDispatchHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GDispatchHookRollbackForceSuccessHigherBackends[LIndex], GDispatchHookRollbackForceSuccessHigherTables[LIndex]);
    GDispatchHookRollbackForceSuccessHigherCount := 0;
    GDispatchHookRollbackForceSuccessTarget := sbScalar;
    GDispatchHookRollbackForceSuccessStage := 0;
    GDispatchHookRollbackForceSuccessEnabled := False;
    GDispatchHookRollbackForceSuccessInMutation := False;
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_TrySetActiveBackend_RollbackRestore_Success_FromPreviousForcedState_LateForce_DuringThirdRestore_Preserves_RequestedSelection;
var
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
  GDispatchHookRollbackForceSuccessHigherCount := 0;
  GDispatchHookRollbackForceSuccessTarget := sbScalar;
  GDispatchHookRollbackForceSuccessTargetTable := Default(TSimdDispatchTable);
  GDispatchHookRollbackForceSuccessStage := 0;
  GDispatchHookRollbackForceSuccessEnabled := False;
  GDispatchHookRollbackForceSuccessInMutation := False;
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

    CheckTrue(LPreviousForcedBackend <> LAutomaticBackend, 'Previous forced backend should differ from automatic best backend in rollback forced-success previous-state third-restore test');
    CheckTrue(TrySetActiveBackend(LPreviousForcedBackend), 'Previous forced backend setup should succeed before rollback forced-success previous-state third-restore test');
    CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Previous forced backend should be active before rollback forced-success previous-state third-restore test');

    CheckTrue(TryGetRegisteredBackendDispatchTable(LRequestedBackend, GDispatchHookRollbackForceSuccessTargetTable), 'Requested backend should be registered for rollback forced-success previous-state third-restore test');
    LTargetTableCaptured := True;

    GDispatchHookRollbackForceSuccessHigherCount := 0;
    for LBackend in LDispatchable do
    begin
      if LBackend = LRequestedBackend then
        Break;
      if LBackend = sbScalar then
        Continue;
      CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, GDispatchHookRollbackForceSuccessHigherTables[GDispatchHookRollbackForceSuccessHigherCount]), 'Higher-priority backend should be registered for rollback forced-success previous-state third-restore test');
      GDispatchHookRollbackForceSuccessHigherBackends[GDispatchHookRollbackForceSuccessHigherCount] := LBackend;
      Inc(GDispatchHookRollbackForceSuccessHigherCount);
    end;
    CheckTrue(GDispatchHookRollbackForceSuccessHigherCount > 0, 'Rollback forced-success previous-state third-restore test requires at least one higher-priority backend to suppress');

    GDispatchHookRollbackForceSuccessTarget := LRequestedBackend;
    GDispatchHookRollbackForceSuccessEnabled := True;
    GDispatchHookRollbackForceSuccessStage := 0;
    GDispatchHookRollbackForceSuccessInMutation := False;
    AddDispatchChangedHook(@DispatchHookRollbackForceSuccessThenLateForceOnThirdRestore);
    try
      CheckTrue(TrySetActiveBackend(LRequestedBackend), 'TrySetActiveBackend should still report success when rollback-time restore reselects the requested backend before late-force third-restore observation even if the call started from a different forced backend');
      CheckEqual(Ord(LRequestedBackend), Ord(GetActiveBackend), 'Return-time active backend should stay on the requested backend instead of drifting back to the previous forced backend during the third forced-intent restore callback');
      CheckTrue(GetActiveBackend <> sbScalar, 'Rollback forced-success previous-state third-restore path should not remain stuck on scalar at return time');
      CheckTrue(GetActiveBackend <> LPreviousForcedBackend, 'Rollback forced-success previous-state third-restore path should not drift back to the pre-call forced backend at return time');
      CheckEqual(9, GDispatchHookRollbackForceSuccessStage, 'Synthetic rollback forced-success previous-state third-restore hook should complete all expected stages');
    finally
      RemoveDispatchChangedHook(@DispatchHookRollbackForceSuccessThenLateForceOnThirdRestore);
      GDispatchHookRollbackForceSuccessEnabled := False;
      GDispatchHookRollbackForceSuccessInMutation := False;
    end;

    for LIndex := 0 to GDispatchHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GDispatchHookRollbackForceSuccessHigherBackends[LIndex], GDispatchHookRollbackForceSuccessHigherTables[LIndex]);

    CheckEqual(Ord(LRequestedBackend), Ord(GetActiveBackend), 'A successful TrySetActiveBackend must keep the requested backend forced even after higher-priority backends are restored from third-restore late-force success path that started from a previous forced backend');
    CheckTrue(GetActiveBackend <> LPreviousForcedBackend, 'Successful rollback forced-success previous-state third-restore path should still not drift back to the pre-call forced backend after higher-priority backends are restored');
  finally
    if LTargetTableCaptured then
      RegisterBackend(GDispatchHookRollbackForceSuccessTarget, GDispatchHookRollbackForceSuccessTargetTable);
    for LIndex := 0 to GDispatchHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GDispatchHookRollbackForceSuccessHigherBackends[LIndex], GDispatchHookRollbackForceSuccessHigherTables[LIndex]);
    GDispatchHookRollbackForceSuccessHigherCount := 0;
    GDispatchHookRollbackForceSuccessTarget := sbScalar;
    GDispatchHookRollbackForceSuccessStage := 0;
    GDispatchHookRollbackForceSuccessEnabled := False;
    GDispatchHookRollbackForceSuccessInMutation := False;
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_TrySetActiveBackend_RollbackRestore_Success_FromPreviousForcedState_LateForce_UntilAttemptCap_Restores_PreviousStableState;
var
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
  GDispatchHookRollbackForceSuccessHigherCount := 0;
  GDispatchHookRollbackForceSuccessTarget := sbScalar;
  GDispatchHookRollbackForceSuccessTargetTable := Default(TSimdDispatchTable);
  GDispatchHookRollbackForceSuccessStage := 0;
  GDispatchHookRollbackForceSuccessEnabled := False;
  GDispatchHookRollbackForceSuccessInMutation := False;
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

    CheckTrue(LPreviousForcedBackend <> LAutomaticBackend, 'Previous forced backend should differ from automatic best backend in rollback forced-success attempt-cap test');
    CheckTrue(TrySetActiveBackend(LPreviousForcedBackend), 'Previous forced backend setup should succeed before rollback forced-success attempt-cap test');
    CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Previous forced backend should be active before rollback forced-success attempt-cap test');

    CheckTrue(TryGetRegisteredBackendDispatchTable(LRequestedBackend, GDispatchHookRollbackForceSuccessTargetTable), 'Requested backend should be registered for rollback forced-success attempt-cap test');
    LTargetTableCaptured := True;

    GDispatchHookRollbackForceSuccessHigherCount := 0;
    for LBackend in LDispatchable do
    begin
      if LBackend = LRequestedBackend then
        Break;
      if (LBackend = sbScalar) or (LBackend = LPreviousForcedBackend) then
        Continue;
      CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, GDispatchHookRollbackForceSuccessHigherTables[GDispatchHookRollbackForceSuccessHigherCount]), 'Higher-priority backend should be registered for rollback forced-success attempt-cap test');
      GDispatchHookRollbackForceSuccessHigherBackends[GDispatchHookRollbackForceSuccessHigherCount] := LBackend;
      Inc(GDispatchHookRollbackForceSuccessHigherCount);
    end;
    CheckTrue(GDispatchHookRollbackForceSuccessHigherCount > 0, 'Rollback forced-success attempt-cap test requires at least one higher-priority backend to suppress');

    GDispatchHookRollbackForceSuccessTarget := LRequestedBackend;
    GDispatchHookRollbackForceSuccessEnabled := True;
    GDispatchHookRollbackForceSuccessStage := 0;
    GDispatchHookRollbackForceSuccessInMutation := False;
    AddDispatchChangedHook(@DispatchHookRollbackForceSuccessThenLateForceUntilAttemptCap);
    try
      CheckFalse(TrySetActiveBackend(LRequestedBackend), 'TrySetActiveBackend should report failure when repeated late scalar re-force exhausts forced-intent restore attempts after rollback-time reselect');
      CheckEqual(20, GDispatchHookRollbackForceSuccessStage, 'Synthetic rollback forced-success attempt-cap hook should also observe the follow-up callback from failure rollback stabilization');
      CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'TrySetActiveBackend should restore the previous forced backend when forced-intent stabilization exhausts the bounded attempt cap');
      CheckTrue(GetActiveBackend <> sbScalar, 'Attempt-cap exhaustion should not leave stale scalar forced fallback while a previous forced backend exists');
      CheckTrue(GetActiveBackend <> LRequestedBackend, 'Attempt-cap exhaustion should not incorrectly report the requested backend as still active after failure rollback');
    finally
      RemoveDispatchChangedHook(@DispatchHookRollbackForceSuccessThenLateForceUntilAttemptCap);
      GDispatchHookRollbackForceSuccessEnabled := False;
      GDispatchHookRollbackForceSuccessInMutation := False;
    end;

    for LIndex := 0 to GDispatchHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GDispatchHookRollbackForceSuccessHigherBackends[LIndex], GDispatchHookRollbackForceSuccessHigherTables[LIndex]);

    CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Restoring higher-priority backends after attempt-cap exhaustion must keep the previous forced backend active');
  finally
    if LTargetTableCaptured then
      RegisterBackend(GDispatchHookRollbackForceSuccessTarget, GDispatchHookRollbackForceSuccessTargetTable);
    for LIndex := 0 to GDispatchHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GDispatchHookRollbackForceSuccessHigherBackends[LIndex], GDispatchHookRollbackForceSuccessHigherTables[LIndex]);
    GDispatchHookRollbackForceSuccessHigherCount := 0;
    GDispatchHookRollbackForceSuccessTarget := sbScalar;
    GDispatchHookRollbackForceSuccessStage := 0;
    GDispatchHookRollbackForceSuccessEnabled := False;
    GDispatchHookRollbackForceSuccessInMutation := False;
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_TrySetActiveBackend_RollbackRestore_Success_FromLowerPriorityPreviousForcedState_LateForce_UntilAttemptCap_Restores_PreviousStableState;
var
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
  GDispatchHookRollbackForceSuccessHigherCount := 0;
  GDispatchHookRollbackForceSuccessTarget := sbScalar;
  GDispatchHookRollbackForceSuccessTargetTable := Default(TSimdDispatchTable);
  GDispatchHookRollbackForceSuccessStage := 0;
  GDispatchHookRollbackForceSuccessEnabled := False;
  GDispatchHookRollbackForceSuccessInMutation := False;
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

    CheckTrue(LPreviousForcedBackend <> LAutomaticBackend, 'Previous forced backend should differ from automatic best backend in rollback forced-success lower-priority previous-state attempt-cap test');
    CheckTrue(TrySetActiveBackend(LPreviousForcedBackend), 'Previous forced backend setup should succeed before rollback forced-success lower-priority previous-state attempt-cap test');
    CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Previous forced backend should be active before rollback forced-success lower-priority previous-state attempt-cap test');

    CheckTrue(TryGetRegisteredBackendDispatchTable(LRequestedBackend, GDispatchHookRollbackForceSuccessTargetTable), 'Requested backend should be registered for rollback forced-success lower-priority previous-state attempt-cap test');
    LTargetTableCaptured := True;

    GDispatchHookRollbackForceSuccessHigherCount := 0;
    for LBackend in LDispatchable do
    begin
      if LBackend = LRequestedBackend then
        Break;
      if LBackend = sbScalar then
        Continue;
      CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, GDispatchHookRollbackForceSuccessHigherTables[GDispatchHookRollbackForceSuccessHigherCount]), 'Higher-priority backend should be registered for rollback forced-success lower-priority previous-state attempt-cap test');
      GDispatchHookRollbackForceSuccessHigherBackends[GDispatchHookRollbackForceSuccessHigherCount] := LBackend;
      Inc(GDispatchHookRollbackForceSuccessHigherCount);
    end;
    CheckTrue(GDispatchHookRollbackForceSuccessHigherCount > 0, 'Rollback forced-success lower-priority previous-state attempt-cap test requires at least one higher-priority backend to suppress');

    GDispatchHookRollbackForceSuccessTarget := LRequestedBackend;
    GDispatchHookRollbackForceSuccessEnabled := True;
    GDispatchHookRollbackForceSuccessStage := 0;
    GDispatchHookRollbackForceSuccessInMutation := False;
    AddDispatchChangedHook(@DispatchHookRollbackForceSuccessThenLateForceUntilAttemptCap);
    try
      CheckFalse(TrySetActiveBackend(LRequestedBackend), 'TrySetActiveBackend should report failure when repeated late scalar re-force exhausts forced-intent restore attempts after rollback-time reselect from a lower-priority previous forced backend');
      CheckEqual(20, GDispatchHookRollbackForceSuccessStage, 'Synthetic rollback forced-success lower-priority previous-state attempt-cap hook should also observe the follow-up callback from failure rollback stabilization');
      CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'TrySetActiveBackend should restore the lower-priority previous forced backend when forced-intent stabilization exhausts the bounded attempt cap');
      CheckTrue(GetActiveBackend <> sbScalar, 'Attempt-cap exhaustion should not leave stale scalar forced fallback while a lower-priority previous forced backend exists');
      CheckTrue(GetActiveBackend <> LRequestedBackend, 'Attempt-cap exhaustion should not incorrectly report the requested backend as still active after failure rollback from a lower-priority previous forced backend');
    finally
      RemoveDispatchChangedHook(@DispatchHookRollbackForceSuccessThenLateForceUntilAttemptCap);
      GDispatchHookRollbackForceSuccessEnabled := False;
      GDispatchHookRollbackForceSuccessInMutation := False;
    end;

    for LIndex := 0 to GDispatchHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GDispatchHookRollbackForceSuccessHigherBackends[LIndex], GDispatchHookRollbackForceSuccessHigherTables[LIndex]);

    CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Restoring higher-priority backends after lower-priority previous-state attempt-cap exhaustion must keep the previous forced backend active');
  finally
    if LTargetTableCaptured then
      RegisterBackend(GDispatchHookRollbackForceSuccessTarget, GDispatchHookRollbackForceSuccessTargetTable);
    for LIndex := 0 to GDispatchHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GDispatchHookRollbackForceSuccessHigherBackends[LIndex], GDispatchHookRollbackForceSuccessHigherTables[LIndex]);
    GDispatchHookRollbackForceSuccessHigherCount := 0;
    GDispatchHookRollbackForceSuccessTarget := sbScalar;
    GDispatchHookRollbackForceSuccessStage := 0;
    GDispatchHookRollbackForceSuccessEnabled := False;
    GDispatchHookRollbackForceSuccessInMutation := False;
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_TrySetActiveBackend_RollbackRestore_Success_LateForce_DuringThirdRestore_Preserves_ForcedSelection;
var
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LRequestedBackend: TSimdBackend;
  LBackend: TSimdBackend;
  LTargetTableCaptured: Boolean;
  LIndex: Integer;
begin
  LTargetTableCaptured := False;
  GDispatchHookRollbackForceSuccessHigherCount := 0;
  GDispatchHookRollbackForceSuccessTarget := sbScalar;
  GDispatchHookRollbackForceSuccessTargetTable := Default(TSimdDispatchTable);
  GDispatchHookRollbackForceSuccessStage := 0;
  GDispatchHookRollbackForceSuccessEnabled := False;
  GDispatchHookRollbackForceSuccessInMutation := False;
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

    CheckTrue(TryGetRegisteredBackendDispatchTable(LRequestedBackend, GDispatchHookRollbackForceSuccessTargetTable), 'Requested backend should be registered for rollback forced-success third-restore preservation test');
    LTargetTableCaptured := True;

    GDispatchHookRollbackForceSuccessHigherCount := 0;
    for LBackend in LDispatchable do
    begin
      if LBackend = LRequestedBackend then
        Break;
      if LBackend = sbScalar then
        Continue;
      CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, GDispatchHookRollbackForceSuccessHigherTables[GDispatchHookRollbackForceSuccessHigherCount]), 'Higher-priority backend should be registered for rollback forced-success third-restore preservation test');
      GDispatchHookRollbackForceSuccessHigherBackends[GDispatchHookRollbackForceSuccessHigherCount] := LBackend;
      Inc(GDispatchHookRollbackForceSuccessHigherCount);
    end;
    CheckTrue(GDispatchHookRollbackForceSuccessHigherCount > 0, 'Rollback forced-success third-restore preservation test requires at least one higher-priority backend to suppress');

    GDispatchHookRollbackForceSuccessTarget := LRequestedBackend;
    GDispatchHookRollbackForceSuccessEnabled := True;
    GDispatchHookRollbackForceSuccessStage := 0;
    GDispatchHookRollbackForceSuccessInMutation := False;
    AddDispatchChangedHook(@DispatchHookRollbackForceSuccessThenLateForceOnThirdRestore);
    try
      CheckTrue(TrySetActiveBackend(LRequestedBackend), 'TrySetActiveBackend should report success when rollback-time restore reselects the requested backend before late-force third-restore observation');
      CheckEqual(Ord(LRequestedBackend), Ord(GetActiveBackend), 'Return-time active backend should remain the requested backend in rollback forced-success third-restore preservation test');
      CheckTrue(GetActiveBackend <> sbScalar, 'Rollback forced-success third-restore preservation path should not remain stuck on scalar at return time');
      CheckEqual(9, GDispatchHookRollbackForceSuccessStage, 'Synthetic rollback forced-success third-restore hook should complete all expected stages');
    finally
      RemoveDispatchChangedHook(@DispatchHookRollbackForceSuccessThenLateForceOnThirdRestore);
      GDispatchHookRollbackForceSuccessEnabled := False;
      GDispatchHookRollbackForceSuccessInMutation := False;
    end;

    for LIndex := 0 to GDispatchHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GDispatchHookRollbackForceSuccessHigherBackends[LIndex], GDispatchHookRollbackForceSuccessHigherTables[LIndex]);

    CheckEqual(Ord(LRequestedBackend), Ord(GetActiveBackend), 'A successful TrySetActiveBackend must keep the requested backend forced even after higher-priority backends are restored from third-restore late-force success path');
  finally
    if LTargetTableCaptured then
      RegisterBackend(GDispatchHookRollbackForceSuccessTarget, GDispatchHookRollbackForceSuccessTargetTable);
    for LIndex := 0 to GDispatchHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GDispatchHookRollbackForceSuccessHigherBackends[LIndex], GDispatchHookRollbackForceSuccessHigherTables[LIndex]);
    GDispatchHookRollbackForceSuccessHigherCount := 0;
    GDispatchHookRollbackForceSuccessTarget := sbScalar;
    GDispatchHookRollbackForceSuccessStage := 0;
    GDispatchHookRollbackForceSuccessEnabled := False;
    GDispatchHookRollbackForceSuccessInMutation := False;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_TrySetActiveBackend_RollbackRestore_Success_LateForce_UntilAttemptCap_Restores_AutomaticIntent;
var
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
  GDispatchHookRollbackForceSuccessHigherCount := 0;
  GDispatchHookRollbackForceSuccessTarget := sbScalar;
  GDispatchHookRollbackForceSuccessTargetTable := Default(TSimdDispatchTable);
  GDispatchHookRollbackForceSuccessStage := 0;
  GDispatchHookRollbackForceSuccessEnabled := False;
  GDispatchHookRollbackForceSuccessInMutation := False;
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

    CheckTrue(TryGetRegisteredBackendDispatchTable(LRequestedBackend, GDispatchHookRollbackForceSuccessTargetTable), 'Requested backend should be registered for rollback forced-success automatic-intent attempt-cap test');
    LTargetTableCaptured := True;

    GDispatchHookRollbackForceSuccessHigherCount := 0;
    for LBackend in LDispatchable do
    begin
      if LBackend = LRequestedBackend then
        Break;
      if LBackend = sbScalar then
        Continue;
      CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, GDispatchHookRollbackForceSuccessHigherTables[GDispatchHookRollbackForceSuccessHigherCount]), 'Higher-priority backend should be registered for rollback forced-success automatic-intent attempt-cap test');
      GDispatchHookRollbackForceSuccessHigherBackends[GDispatchHookRollbackForceSuccessHigherCount] := LBackend;
      Inc(GDispatchHookRollbackForceSuccessHigherCount);
    end;
    CheckTrue(GDispatchHookRollbackForceSuccessHigherCount > 0, 'Rollback forced-success automatic-intent attempt-cap test requires at least one higher-priority backend to suppress');

    GDispatchHookRollbackForceSuccessTarget := LRequestedBackend;
    GDispatchHookRollbackForceSuccessEnabled := True;
    GDispatchHookRollbackForceSuccessStage := 0;
    GDispatchHookRollbackForceSuccessInMutation := False;
    AddDispatchChangedHook(@DispatchHookRollbackForceSuccessThenLateForceUntilAttemptCap);
    try
      CheckFalse(TrySetActiveBackend(LRequestedBackend), 'TrySetActiveBackend should report failure when repeated late scalar re-force exhausts forced-intent restore attempts after rollback-time reselect from automatic mode');
      CheckEqual(20, GDispatchHookRollbackForceSuccessStage, 'Synthetic rollback forced-success automatic-intent attempt-cap hook should also observe the follow-up callback from automatic-intent stabilization');
      CheckEqual(Ord(LRequestedBackend), Ord(GetActiveBackend), 'Attempt-cap exhaustion should restore automatic intent at return time, which under the hook-suppressed higher backends still means the requested backend remains the current automatic best backend');
      CheckTrue(GetActiveBackend <> sbScalar, 'Rollback forced-success automatic-intent attempt-cap path should not remain stuck on scalar at return time');
    finally
      RemoveDispatchChangedHook(@DispatchHookRollbackForceSuccessThenLateForceUntilAttemptCap);
      GDispatchHookRollbackForceSuccessEnabled := False;
      GDispatchHookRollbackForceSuccessInMutation := False;
    end;

    for LIndex := 0 to GDispatchHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GDispatchHookRollbackForceSuccessHigherBackends[LIndex], GDispatchHookRollbackForceSuccessHigherTables[LIndex]);

    CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'Restoring higher-priority backends after attempt-cap exhaustion must drift back to the automatic best backend instead of preserving the requested forced selection');
    CheckTrue(GetActiveBackend <> LRequestedBackend, 'Restoring higher-priority backends after success-path attempt-cap exhaustion should not keep the requested backend forced');
  finally
    if LTargetTableCaptured then
      RegisterBackend(GDispatchHookRollbackForceSuccessTarget, GDispatchHookRollbackForceSuccessTargetTable);
    for LIndex := 0 to GDispatchHookRollbackForceSuccessHigherCount - 1 do
      RegisterBackend(GDispatchHookRollbackForceSuccessHigherBackends[LIndex], GDispatchHookRollbackForceSuccessHigherTables[LIndex]);
    GDispatchHookRollbackForceSuccessHigherCount := 0;
    GDispatchHookRollbackForceSuccessTarget := sbScalar;
    GDispatchHookRollbackForceSuccessStage := 0;
    GDispatchHookRollbackForceSuccessEnabled := False;
    GDispatchHookRollbackForceSuccessInMutation := False;
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_SetActiveBackend_Unavailable_FallsBackToScalar;
begin
  {$IFDEF CPUX86_64}
  SetActiveBackend(sbNEON);
  {$ELSE}
  {$IFDEF CPUAARCH64}
  SetActiveBackend(sbSSE2);
  {$ELSE}
  SetActiveBackend(sbAVX512);
  {$ENDIF}
  {$ENDIF}

  CheckEqual(Ord(sbScalar), Ord(GetActiveBackend), 'SetActiveBackend(unavailable) should fall back to Scalar');
end;

procedure TTestCase_DispatchAPIControlPlane.Test_TrySetActiveBackend_RollbackRestore_LateForce_Restores_AutomaticBackend;
var
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

    CheckEqual(Ord(LAutomaticBackend), Ord(GetBestDispatchableBackend), 'Automatic selection should start from best dispatchable backend before automatic rollback late-force test');

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

    CheckTrue(TryGetRegisteredBackendDispatchTable(LRequestedBackend, LOriginalTable), 'Requested backend should be registered for automatic rollback late-force test');
    LRequestedTableCaptured := True;
    CheckTrue(IsBackendDispatchable(LRequestedBackend), 'Requested backend should start dispatchable before automatic rollback late-force test');

    GDispatchHookAutomaticRollbackLateForceRequestedBackend := LRequestedBackend;
    GDispatchHookAutomaticRollbackLateForceRequestedTable := LOriginalTable;
    GDispatchHookAutomaticRollbackLateForceEnabled := True;
    GDispatchHookAutomaticRollbackLateForceStage := 0;
    AddDispatchChangedHook(@DispatchHookDisableRequestedThenLateForceOnAutomaticRestore);
    try
      CheckFalse(TrySetActiveBackend(LRequestedBackend), 'TrySetActiveBackend should still report failure when requested backend is disabled before automatic rollback late-force observation');
      CheckEqual(5, GDispatchHookAutomaticRollbackLateForceStage, 'Synthetic automatic rollback late-force hook should run through the full callback sequence');
      CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'A failed TrySetActiveBackend in automatic mode must restore the automatic best backend even if a late hook re-forces scalar during rollback');
      CheckTrue(GetActiveBackend <> sbScalar, 'Automatic rollback late-force path should not leave Scalar active when a better automatic backend exists');
    finally
      RemoveDispatchChangedHook(@DispatchHookDisableRequestedThenLateForceOnAutomaticRestore);
      GDispatchHookAutomaticRollbackLateForceEnabled := False;
      GDispatchHookAutomaticRollbackLateForceStage := 0;
      GDispatchHookAutomaticRollbackLateForceRequestedBackend := sbScalar;
    end;

    RegisterBackend(LRequestedBackend, LOriginalTable);
    CheckTrue(IsBackendDispatchable(LRequestedBackend), 'Requested backend should become dispatchable again after restoring its original table in automatic rollback late-force test');
    CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'Restoring the requested backend table after automatic rollback late-force failure must keep automatic best backend active');
  finally
    if LRequestedTableCaptured then
      RegisterBackend(LRequestedBackend, LOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_TrySetActiveBackend_RollbackRestore_LateForce_DuringRestore_Restores_AutomaticBackend;
var
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

    CheckEqual(Ord(LAutomaticBackend), Ord(GetBestDispatchableBackend), 'Automatic selection should start from best dispatchable backend before automatic rollback restore-callback late-force test');

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

    CheckTrue(TryGetRegisteredBackendDispatchTable(LRequestedBackend, LOriginalTable), 'Requested backend should be registered for automatic rollback restore-callback late-force test');
    LRequestedTableCaptured := True;
    CheckTrue(IsBackendDispatchable(LRequestedBackend), 'Requested backend should start dispatchable before automatic rollback restore-callback late-force test');

    GDispatchHookAutomaticRollbackRestoreLateForceRequestedBackend := LRequestedBackend;
    GDispatchHookAutomaticRollbackRestoreLateForceRequestedTable := LOriginalTable;
    GDispatchHookAutomaticRollbackRestoreLateForceEnabled := True;
    GDispatchHookAutomaticRollbackRestoreLateForceStage := 0;
    AddDispatchChangedHook(@DispatchHookDisableRequestedThenLateForceOnAutomaticRestoreTwice);
    try
      CheckFalse(TrySetActiveBackend(LRequestedBackend), 'TrySetActiveBackend should still report failure when requested backend is disabled before automatic rollback restore-callback late-force observation');
      CheckEqual(7, GDispatchHookAutomaticRollbackRestoreLateForceStage, 'Synthetic automatic rollback restore-callback late-force hook should run through the full callback sequence');
      CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'A failed TrySetActiveBackend in automatic mode must still restore automatic best backend even if a late hook re-forces scalar during rollback restore callback');
      CheckTrue(GetActiveBackend <> sbScalar, 'Automatic rollback restore-callback late-force path should not remain stuck on scalar when a better automatic backend exists');
    finally
      RemoveDispatchChangedHook(@DispatchHookDisableRequestedThenLateForceOnAutomaticRestoreTwice);
      GDispatchHookAutomaticRollbackRestoreLateForceEnabled := False;
      GDispatchHookAutomaticRollbackRestoreLateForceStage := 0;
      GDispatchHookAutomaticRollbackRestoreLateForceRequestedBackend := sbScalar;
    end;

    RegisterBackend(LRequestedBackend, LOriginalTable);
    CheckTrue(IsBackendDispatchable(LRequestedBackend), 'Requested backend should become dispatchable again after restoring its original table in automatic rollback restore-callback late-force test');
    CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'Restoring the requested backend table after automatic rollback restore-callback late-force failure must keep automatic best backend active');
  finally
    if LRequestedTableCaptured then
      RegisterBackend(LRequestedBackend, LOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_TrySetActiveBackend_RollbackRestore_LateForce_DuringThirdRestore_Restores_AutomaticBackend;
var
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

    CheckEqual(Ord(LAutomaticBackend), Ord(GetBestDispatchableBackend), 'Automatic selection should start from best dispatchable backend before automatic rollback third-restore late-force test');

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

    CheckTrue(TryGetRegisteredBackendDispatchTable(LRequestedBackend, LOriginalTable), 'Requested backend should be registered for automatic rollback third-restore late-force test');
    LRequestedTableCaptured := True;
    CheckTrue(IsBackendDispatchable(LRequestedBackend), 'Requested backend should start dispatchable before automatic rollback third-restore late-force test');

    GDispatchHookAutomaticRollbackRestoreLateForceRequestedBackend := LRequestedBackend;
    GDispatchHookAutomaticRollbackRestoreLateForceRequestedTable := LOriginalTable;
    GDispatchHookAutomaticRollbackRestoreLateForceEnabled := True;
    GDispatchHookAutomaticRollbackRestoreLateForceStage := 0;
    AddDispatchChangedHook(@DispatchHookDisableRequestedThenLateForceOnAutomaticThirdRestore);
    try
      CheckFalse(TrySetActiveBackend(LRequestedBackend), 'TrySetActiveBackend should still report failure when requested backend is disabled before automatic rollback third-restore late-force observation');
      CheckEqual(7, GDispatchHookAutomaticRollbackRestoreLateForceStage, 'Synthetic automatic rollback third-restore late-force hook should run through the full callback sequence');
      CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'A failed TrySetActiveBackend in automatic mode must still restore automatic best backend even if a late hook re-forces scalar during the third rollback restore callback');
      CheckTrue(GetActiveBackend <> sbScalar, 'Automatic rollback third-restore late-force path should not remain stuck on scalar when a better automatic backend exists');
    finally
      RemoveDispatchChangedHook(@DispatchHookDisableRequestedThenLateForceOnAutomaticThirdRestore);
      GDispatchHookAutomaticRollbackRestoreLateForceEnabled := False;
      GDispatchHookAutomaticRollbackRestoreLateForceStage := 0;
      GDispatchHookAutomaticRollbackRestoreLateForceRequestedBackend := sbScalar;
    end;

    RegisterBackend(LRequestedBackend, LOriginalTable);
    CheckTrue(IsBackendDispatchable(LRequestedBackend), 'Requested backend should become dispatchable again after restoring its original table in automatic rollback third-restore late-force test');
    CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'Restoring the requested backend table after automatic rollback third-restore late-force failure must keep automatic best backend active');
  finally
    if LRequestedTableCaptured then
      RegisterBackend(LRequestedBackend, LOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_TrySetActiveBackend_RollbackRestore_LateForce_Preserves_PreviousForcedBackend;
var
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

    CheckTrue(LPreviousForcedBackend <> LAutomaticBackend, 'Previous forced backend should differ from automatic best backend in rollback late-force test');
    CheckTrue(TrySetActiveBackend(LPreviousForcedBackend), 'Previous forced backend setup should succeed before rollback late-force test');
    CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Previous forced backend should be active before rollback late-force test');

    CheckTrue(TryGetRegisteredBackendDispatchTable(LRequestedBackend, LRequestedOriginalTable), 'Requested backend should be registered for rollback late-force test');
    LRequestedTableCaptured := True;
    CheckTrue(IsBackendDispatchable(LRequestedBackend), 'Requested backend should start dispatchable before rollback late-force test');

    GDispatchHookRollbackLateForceRequestedBackend := LRequestedBackend;
    GDispatchHookRollbackLateForceRequestedTable := LRequestedOriginalTable;
    GDispatchHookRollbackLateForceEnabled := True;
    GDispatchHookRollbackLateForceStage := 0;
    AddDispatchChangedHook(@DispatchHookDisableRequestedThenLateForceOnPreviousRestore);
    try
      CheckFalse(TrySetActiveBackend(LRequestedBackend), 'TrySetActiveBackend should still report failure when requested backend is disabled by hook before rollback late-force observation');
      CheckEqual(6, GDispatchHookRollbackLateForceStage, 'Synthetic rollback late-force hook should run through the full callback sequence');
      CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'TrySetActiveBackend should preserve the previous forced backend even if a late hook re-forces scalar during rollback restore');
      CheckTrue(GetActiveBackend <> sbScalar, 'Rollback restore should not leave stale scalar forced fallback while a previous forced backend exists');
    finally
      RemoveDispatchChangedHook(@DispatchHookDisableRequestedThenLateForceOnPreviousRestore);
      GDispatchHookRollbackLateForceEnabled := False;
      GDispatchHookRollbackLateForceStage := 0;
      GDispatchHookRollbackLateForceRequestedBackend := sbScalar;
    end;

    RegisterBackend(LRequestedBackend, LRequestedOriginalTable);
    CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Restoring the requested backend table after rollback late-force failure must keep the previous forced backend active');
  finally
    if LRequestedTableCaptured then
      RegisterBackend(LRequestedBackend, LRequestedOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_TrySetActiveBackend_RollbackRestore_LateForce_DuringThirdRestore_Preserves_PreviousForcedBackend;
var
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

    CheckTrue(LPreviousForcedBackend <> LAutomaticBackend, 'Previous forced backend should differ from automatic best backend in rollback third-restore late-force test');
    CheckTrue(TrySetActiveBackend(LPreviousForcedBackend), 'Previous forced backend setup should succeed before rollback third-restore late-force test');
    CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Previous forced backend should be active before rollback third-restore late-force test');

    CheckTrue(TryGetRegisteredBackendDispatchTable(LRequestedBackend, LRequestedOriginalTable), 'Requested backend should be registered for rollback third-restore late-force test');
    LRequestedTableCaptured := True;
    CheckTrue(IsBackendDispatchable(LRequestedBackend), 'Requested backend should start dispatchable before rollback third-restore late-force test');

    GDispatchHookRollbackLateForceRequestedBackend := LRequestedBackend;
    GDispatchHookRollbackLateForceRequestedTable := LRequestedOriginalTable;
    GDispatchHookRollbackLateForceEnabled := True;
    GDispatchHookRollbackLateForceStage := 0;
    AddDispatchChangedHook(@DispatchHookDisableRequestedThenLateForceOnPreviousThirdRestore);
    try
      CheckFalse(TrySetActiveBackend(LRequestedBackend), 'TrySetActiveBackend should still report failure when requested backend is disabled by hook before rollback third-restore late-force observation');
      CheckEqual(10, GDispatchHookRollbackLateForceStage, 'Synthetic rollback third-late-force hook should run through the full callback sequence');
      CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'TrySetActiveBackend should preserve the previous forced backend even if a late hook re-forces scalar during the third rollback restore callback');
      CheckTrue(GetActiveBackend <> sbScalar, 'Rollback third-restore should not leave stale scalar forced fallback while a previous forced backend exists');
    finally
      RemoveDispatchChangedHook(@DispatchHookDisableRequestedThenLateForceOnPreviousThirdRestore);
      GDispatchHookRollbackLateForceEnabled := False;
      GDispatchHookRollbackLateForceStage := 0;
      GDispatchHookRollbackLateForceRequestedBackend := sbScalar;
    end;

    RegisterBackend(LRequestedBackend, LRequestedOriginalTable);
    CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Restoring the requested backend table after rollback third-restore late-force failure must keep the previous forced backend active');
  finally
    if LRequestedTableCaptured then
      RegisterBackend(LRequestedBackend, LRequestedOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_TrySetActiveBackend_RollbackRestore_LateForce_UntilAttemptCap_Restores_AutomaticBackend;
var
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

    CheckEqual(Ord(LAutomaticBackend), Ord(GetBestDispatchableBackend), 'Automatic selection should start from best dispatchable backend before automatic rollback attempt-cap late-force test');

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

    CheckTrue(TryGetRegisteredBackendDispatchTable(LRequestedBackend, LOriginalTable), 'Requested backend should be registered for automatic rollback attempt-cap late-force test');
    LRequestedTableCaptured := True;
    CheckTrue(IsBackendDispatchable(LRequestedBackend), 'Requested backend should start dispatchable before automatic rollback attempt-cap late-force test');

    GDispatchHookAutomaticRollbackRestoreLateForceRequestedBackend := LRequestedBackend;
    GDispatchHookAutomaticRollbackRestoreLateForceRequestedTable := LOriginalTable;
    GDispatchHookAutomaticRollbackRestoreLateForceEnabled := True;
    GDispatchHookAutomaticRollbackRestoreLateForceStage := 0;
    AddDispatchChangedHook(@DispatchHookDisableRequestedThenLateForceOnAutomaticRestoreUntilAttemptCap);
    try
      CheckFalse(TrySetActiveBackend(LRequestedBackend), 'TrySetActiveBackend should still report failure when requested backend is disabled before automatic rollback attempt-cap late-force observation');
      CheckEqual(20, GDispatchHookAutomaticRollbackRestoreLateForceStage, 'Synthetic automatic rollback attempt-cap late-force hook should also observe the follow-up callback from post-cap automatic stabilization');
      CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'A failed TrySetActiveBackend in automatic mode must still restore automatic best backend after rollback restore attempts are exhausted by repeated late scalar force');
      CheckTrue(GetActiveBackend <> sbScalar, 'Automatic rollback attempt-cap late-force path should not remain stuck on scalar when a better automatic backend exists');
    finally
      RemoveDispatchChangedHook(@DispatchHookDisableRequestedThenLateForceOnAutomaticRestoreUntilAttemptCap);
      GDispatchHookAutomaticRollbackRestoreLateForceEnabled := False;
      GDispatchHookAutomaticRollbackRestoreLateForceStage := 0;
      GDispatchHookAutomaticRollbackRestoreLateForceRequestedBackend := sbScalar;
    end;

    RegisterBackend(LRequestedBackend, LOriginalTable);
    CheckTrue(IsBackendDispatchable(LRequestedBackend), 'Requested backend should become dispatchable again after restoring its original table in automatic rollback attempt-cap late-force test');
    CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'Restoring the requested backend table after automatic rollback attempt-cap late-force failure must keep automatic best backend active');
  finally
    if LRequestedTableCaptured then
      RegisterBackend(LRequestedBackend, LOriginalTable);
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_BackendInfoAvailableFalse_IsNotSelectable;
var
  LOriginalBackend: TSimdBackend;
  LBeforeTry: TSimdBackend;
  LAfterAuto: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LModifiedTable: TSimdDispatchTable;
begin
  ResetToAutomaticBackend;
  LOriginalBackend := GetActiveBackend;

  // If we ended up on Scalar, there's nothing meaningful to test.
  if LOriginalBackend = sbScalar then
    Exit;

  CheckTrue(TryGetRegisteredBackendDispatchTable(LOriginalBackend, LOriginalTable), 'Active backend should be registered');

  LModifiedTable := LOriginalTable;
  LModifiedTable.BackendInfo.Available := False;

  // Re-register same backend but mark it unavailable.
  RegisterBackend(LOriginalBackend, LModifiedTable);
  try
    // Forced selection must now fail.
    LBeforeTry := GetActiveBackend;
    CheckFalse(TrySetActiveBackend(LOriginalBackend), 'TrySetActiveBackend should fail when BackendInfo.Available=False');
    CheckEqual(Ord(LBeforeTry), Ord(GetActiveBackend), 'Active backend should remain unchanged after failed TrySetActiveBackend');

    // Automatic selection must not pick this backend anymore.
    ResetToAutomaticBackend;
    LAfterAuto := GetActiveBackend;
    CheckTrue(LAfterAuto <> LOriginalBackend, 'Automatic selection should skip backend marked unavailable');
  finally
    // Restore original table.
    RegisterBackend(LOriginalBackend, LOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_SetActiveBackend_HookLateFailure_Preserves_PreviousForcedBackend;
var
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

    CheckTrue(LPreviousForcedBackend <> LAutomaticBackend, 'Previous forced backend should differ from automatic best backend in SetActiveBackend late-failure test');
    CheckTrue(TrySetActiveBackend(LPreviousForcedBackend), 'Previous forced backend setup should succeed before SetActiveBackend late-failure test');
    CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Previous forced backend should be active before SetActiveBackend attempts the failing switch');

    CheckTrue(TryGetRegisteredBackendDispatchTable(LRequestedBackend, LRequestedOriginalTable), 'Requested backend should be registered for SetActiveBackend late-failure test');
    LRequestedTableCaptured := True;
    CheckTrue(IsBackendDispatchable(LRequestedBackend), 'Requested backend should start dispatchable before SetActiveBackend late-failure test');

    GDispatchHookDisableBackendOriginalTable := LRequestedOriginalTable;
    GDispatchHookDisableBackendTarget := LRequestedBackend;
    GDispatchHookDisableBackendEnabled := True;
    GDispatchHookDisableBackendArmed := False;
    GDispatchHookDisableBackendDone := False;
    AddDispatchChangedHook(@DispatchHookDisableBackendOnce);
    try
      SetActiveBackend(LRequestedBackend);
      CheckFalse(IsBackendDispatchable(LRequestedBackend), 'Hook-driven mutation should leave the requested backend non-dispatchable until the test restores its table');
      CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'SetActiveBackend should preserve the previous forced backend when a late hook-driven failure rejects the requested backend');
      CheckTrue(GetActiveBackend <> sbScalar, 'SetActiveBackend late failure should not silently drop to scalar fallback while a previous forced backend exists');
    finally
      RemoveDispatchChangedHook(@DispatchHookDisableBackendOnce);
      GDispatchHookDisableBackendEnabled := False;
      GDispatchHookDisableBackendArmed := False;
      GDispatchHookDisableBackendDone := False;
    end;

    RegisterBackend(LRequestedBackend, LRequestedOriginalTable);
    CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Restoring the requested backend table after SetActiveBackend late failure must keep the previous forced backend active');
  finally
    if LRequestedTableCaptured then
      RegisterBackend(LRequestedBackend, LRequestedOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_ResetToAutomaticBackend_HookLateForce_Restores_AutomaticBackend;
var
  LAutomaticBackend: TSimdBackend;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LAutomaticBackend := GetBestDispatchableBackend;
  if LAutomaticBackend = sbScalar then
    Exit;

  CheckTrue(TrySetActiveBackend(sbScalar), 'Scalar force setup should succeed before ResetToAutomaticBackend late-force test');
  CheckEqual(Ord(sbScalar), Ord(GetActiveBackend), 'Scalar should be active before ResetToAutomaticBackend late-force test');

  GDispatchHookReForceBackendTarget := sbScalar;
  GDispatchHookReForceBackendEnabled := True;
  GDispatchHookReForceBackendStage := 0;
  AddDispatchChangedHook(@DispatchHookReForceBackendOnce);
  try
    ResetToAutomaticBackend;
    CheckEqual(2, GDispatchHookReForceBackendStage, 'Synthetic late-force hook should run through the real ResetToAutomaticBackend callback sequence');
    CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'ResetToAutomaticBackend should restore automatic best backend even if a late hook re-forces scalar during notification');
    CheckTrue(GetActiveBackend <> sbScalar, 'ResetToAutomaticBackend should not return with stale scalar forced fallback when a better automatic backend exists');
    CheckEqual(Ord(GetBestDispatchableBackend), Ord(GetActiveBackend), 'ResetToAutomaticBackend should leave active backend aligned with best dispatchable backend after late hook mutation');
  finally
    RemoveDispatchChangedHook(@DispatchHookReForceBackendOnce);
    GDispatchHookReForceBackendEnabled := False;
    GDispatchHookReForceBackendStage := 0;
    GDispatchHookReForceBackendTarget := sbScalar;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_ResetToAutomaticBackend_HookLateForce_DuringRestore_Restores_AutomaticBackend;
var
  LAutomaticBackend: TSimdBackend;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LAutomaticBackend := GetBestDispatchableBackend;
  if LAutomaticBackend = sbScalar then
    Exit;

  CheckTrue(TrySetActiveBackend(sbScalar), 'Scalar force setup should succeed before ResetToAutomaticBackend restore-callback late-force test');
  CheckEqual(Ord(sbScalar), Ord(GetActiveBackend), 'Scalar should be active before ResetToAutomaticBackend restore-callback late-force test');

  GDispatchHookResetLateForceTarget := sbScalar;
  GDispatchHookResetLateForceEnabled := True;
  GDispatchHookResetLateForceStage := 0;
  AddDispatchChangedHook(@DispatchHookReForceBackendOnAutomaticRestore);
  try
    ResetToAutomaticBackend;
    CheckEqual(5, GDispatchHookResetLateForceStage, 'Synthetic second-late-force hook should run through the full ResetToAutomaticBackend callback sequence');
    CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'ResetToAutomaticBackend should still restore automatic best backend even if a late hook re-forces scalar during restore callback');
    CheckTrue(GetActiveBackend <> sbScalar, 'ResetToAutomaticBackend restore-callback late-force path should not return with stale scalar forced fallback when a better automatic backend exists');
    CheckEqual(Ord(GetBestDispatchableBackend), Ord(GetActiveBackend), 'ResetToAutomaticBackend restore-callback late-force path should leave active backend aligned with best dispatchable backend');
  finally
    RemoveDispatchChangedHook(@DispatchHookReForceBackendOnAutomaticRestore);
    GDispatchHookResetLateForceEnabled := False;
    GDispatchHookResetLateForceStage := 0;
    GDispatchHookResetLateForceTarget := sbScalar;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_ResetToAutomaticBackend_HookLateForce_DuringThirdRestore_Restores_AutomaticBackend;
var
  LAutomaticBackend: TSimdBackend;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LAutomaticBackend := GetBestDispatchableBackend;
  if LAutomaticBackend = sbScalar then
    Exit;

  CheckTrue(TrySetActiveBackend(sbScalar), 'Scalar force setup should succeed before ResetToAutomaticBackend third-restore late-force test');
  CheckEqual(Ord(sbScalar), Ord(GetActiveBackend), 'Scalar should be active before ResetToAutomaticBackend third-restore late-force test');

  GDispatchHookResetLateForceTarget := sbScalar;
  GDispatchHookResetLateForceEnabled := True;
  GDispatchHookResetLateForceStage := 0;
  AddDispatchChangedHook(@DispatchHookReForceBackendOnAutomaticThirdRestore);
  try
    ResetToAutomaticBackend;
    CheckEqual(7, GDispatchHookResetLateForceStage, 'Synthetic third-late-force hook should run through the full ResetToAutomaticBackend callback sequence');
    CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'ResetToAutomaticBackend should still restore automatic best backend even if a late hook re-forces scalar during the third restore callback');
    CheckTrue(GetActiveBackend <> sbScalar, 'ResetToAutomaticBackend third-restore late-force path should not return with stale scalar forced fallback when a better automatic backend exists');
    CheckEqual(Ord(GetBestDispatchableBackend), Ord(GetActiveBackend), 'ResetToAutomaticBackend third-restore late-force path should leave active backend aligned with best dispatchable backend');
  finally
    RemoveDispatchChangedHook(@DispatchHookReForceBackendOnAutomaticThirdRestore);
    GDispatchHookResetLateForceEnabled := False;
    GDispatchHookResetLateForceStage := 0;
    GDispatchHookResetLateForceTarget := sbScalar;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_ResetToAutomaticBackend_HookLateForce_UntilAttemptCap_Restores_AutomaticBackend;
var
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

    CheckTrue(TrySetActiveBackend(sbScalar), 'Scalar force setup should succeed before ResetToAutomaticBackend attempt-cap late-force test');
    CheckEqual(Ord(sbScalar), Ord(GetActiveBackend), 'Scalar should be active before ResetToAutomaticBackend attempt-cap late-force test');

    GDispatchHookResetLateForceTarget := sbScalar;
    GDispatchHookResetLateForceEnabled := True;
    GDispatchHookResetLateForceStage := 0;
    AddDispatchChangedHook(@DispatchHookReForceBackendOnAutomaticRestoreUntilAttemptCap);
    try
      ResetToAutomaticBackend;
      CheckEqual(18, GDispatchHookResetLateForceStage, 'Synthetic ResetToAutomaticBackend attempt-cap late-force hook should observe the post-cap automatic closeout callback');
      CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'ResetToAutomaticBackend must restore automatic best backend after repeated late scalar force exhausts the bounded restore helper');
      CheckTrue(GetActiveBackend <> sbScalar, 'ResetToAutomaticBackend attempt-cap late-force path should not remain stuck on scalar when a better automatic backend exists');
      CheckEqual(Ord(GetBestDispatchableBackend), Ord(GetActiveBackend), 'ResetToAutomaticBackend attempt-cap late-force path should leave active backend aligned with best dispatchable backend');
    finally
      RemoveDispatchChangedHook(@DispatchHookReForceBackendOnAutomaticRestoreUntilAttemptCap);
      GDispatchHookResetLateForceEnabled := False;
      GDispatchHookResetLateForceStage := 0;
      GDispatchHookResetLateForceTarget := sbScalar;
    end;
  finally
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_SetVectorAsmEnabled_HookLateForce_Restores_AutomaticBackend;
var
  LAutomaticBackend: TSimdBackend;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LAutomaticBackend := GetBestDispatchableBackend;
  if LAutomaticBackend = sbScalar then
    Exit;

  SetVectorAsmEnabled(False);
  ResetToAutomaticBackend;
  CheckEqual(Ord(GetBestDispatchableBackend), Ord(GetActiveBackend), 'Vector-asm disable precondition should leave active backend aligned with automatic best backend');

  GDispatchHookReForceBackendTarget := sbScalar;
  GDispatchHookReForceBackendEnabled := True;
  GDispatchHookReForceBackendStage := 0;
  AddDispatchChangedHook(@DispatchHookReForceBackendOnce);
  try
    SetVectorAsmEnabled(True);
    CheckEqual(2, GDispatchHookReForceBackendStage, 'Synthetic vector-asm late-force hook should run through the real SetVectorAsmEnabled callback sequence');
    CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'SetVectorAsmEnabled should restore automatic best backend even if a late hook re-forces scalar during re-enable notification');
    CheckTrue(GetActiveBackend <> sbScalar, 'SetVectorAsmEnabled re-enable late-force path should not return with stale scalar forced fallback when a better automatic backend exists');
    CheckEqual(Ord(GetBestDispatchableBackend), Ord(GetActiveBackend), 'SetVectorAsmEnabled re-enable late-force path should leave active backend aligned with best dispatchable backend');
  finally
    RemoveDispatchChangedHook(@DispatchHookReForceBackendOnce);
    GDispatchHookReForceBackendEnabled := False;
    GDispatchHookReForceBackendStage := 0;
    GDispatchHookReForceBackendTarget := sbScalar;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_SetVectorAsmEnabled_HookLateForce_DuringRestore_Restores_AutomaticBackend;
var
  LAutomaticBackend: TSimdBackend;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LAutomaticBackend := GetBestDispatchableBackend;
  if LAutomaticBackend = sbScalar then
    Exit;

  SetVectorAsmEnabled(False);
  ResetToAutomaticBackend;
  CheckEqual(Ord(GetBestDispatchableBackend), Ord(GetActiveBackend), 'Vector-asm disable precondition should keep active backend aligned with automatic best backend before restore-callback late-force test');

  GDispatchHookResetLateForceTarget := sbScalar;
  GDispatchHookResetLateForceEnabled := True;
  GDispatchHookResetLateForceStage := 0;
  AddDispatchChangedHook(@DispatchHookReForceBackendOnAutomaticRestore);
  try
    SetVectorAsmEnabled(True);
    CheckEqual(5, GDispatchHookResetLateForceStage, 'Synthetic vector-asm second-late-force hook should run through the full SetVectorAsmEnabled callback sequence');
    CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'SetVectorAsmEnabled should still restore automatic best backend even if a late hook re-forces scalar during restore callback');
    CheckTrue(GetActiveBackend <> sbScalar, 'SetVectorAsmEnabled restore-callback late-force path should not return with stale scalar forced fallback when a better automatic backend exists');
    CheckEqual(Ord(GetBestDispatchableBackend), Ord(GetActiveBackend), 'SetVectorAsmEnabled restore-callback late-force path should leave active backend aligned with best dispatchable backend');
  finally
    RemoveDispatchChangedHook(@DispatchHookReForceBackendOnAutomaticRestore);
    GDispatchHookResetLateForceEnabled := False;
    GDispatchHookResetLateForceStage := 0;
    GDispatchHookResetLateForceTarget := sbScalar;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_SetVectorAsmEnabled_HookLateForce_DuringThirdRestore_Restores_AutomaticBackend;
var
  LAutomaticBackend: TSimdBackend;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LAutomaticBackend := GetBestDispatchableBackend;
  if LAutomaticBackend = sbScalar then
    Exit;

  SetVectorAsmEnabled(False);
  ResetToAutomaticBackend;
  CheckEqual(Ord(GetBestDispatchableBackend), Ord(GetActiveBackend), 'Vector-asm disable precondition should keep active backend aligned with automatic best backend before third-restore late-force test');

  GDispatchHookResetLateForceTarget := sbScalar;
  GDispatchHookResetLateForceEnabled := True;
  GDispatchHookResetLateForceStage := 0;
  AddDispatchChangedHook(@DispatchHookReForceBackendOnAutomaticThirdRestore);
  try
    SetVectorAsmEnabled(True);
    CheckEqual(7, GDispatchHookResetLateForceStage, 'Synthetic vector-asm third-late-force hook should run through the full SetVectorAsmEnabled callback sequence');
    CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'SetVectorAsmEnabled should still restore automatic best backend even if a late hook re-forces scalar during the third restore callback');
    CheckTrue(GetActiveBackend <> sbScalar, 'SetVectorAsmEnabled third-restore late-force path should not return with stale scalar forced fallback when a better automatic backend exists');
    CheckEqual(Ord(GetBestDispatchableBackend), Ord(GetActiveBackend), 'SetVectorAsmEnabled third-restore late-force path should leave active backend aligned with best dispatchable backend');
  finally
    RemoveDispatchChangedHook(@DispatchHookReForceBackendOnAutomaticThirdRestore);
    GDispatchHookResetLateForceEnabled := False;
    GDispatchHookResetLateForceStage := 0;
    GDispatchHookResetLateForceTarget := sbScalar;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_SetVectorAsmEnabled_HookLateForce_UntilAttemptCap_Restores_AutomaticBackend;
var
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
    CheckEqual(Ord(GetBestDispatchableBackend), Ord(GetActiveBackend), 'Vector-asm disable precondition should keep active backend aligned with automatic best backend before attempt-cap late-force test');

    GDispatchHookResetLateForceTarget := sbScalar;
    GDispatchHookResetLateForceEnabled := True;
    GDispatchHookResetLateForceStage := 0;
    AddDispatchChangedHook(@DispatchHookReForceBackendOnToggleRestoreUntilAttemptCap);
    try
      SetVectorAsmEnabled(True);
      CheckEqual(20, GDispatchHookResetLateForceStage, 'Synthetic vector-asm attempt-cap late-force hook should observe the post-cap automatic closeout callback');
      CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'SetVectorAsmEnabled should restore automatic best backend after repeated late scalar force exhausts the bounded restore helper');
      CheckTrue(GetActiveBackend <> sbScalar, 'SetVectorAsmEnabled attempt-cap late-force path should not return with stale scalar forced fallback when a better automatic backend exists');
      CheckEqual(Ord(GetBestDispatchableBackend), Ord(GetActiveBackend), 'SetVectorAsmEnabled attempt-cap late-force path should leave active backend aligned with best dispatchable backend');
    finally
      RemoveDispatchChangedHook(@DispatchHookReForceBackendOnToggleRestoreUntilAttemptCap);
      GDispatchHookResetLateForceEnabled := False;
      GDispatchHookResetLateForceStage := 0;
      GDispatchHookResetLateForceTarget := sbScalar;
    end;
  finally
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_SetVectorAsmEnabled_HookLateAutomaticReset_Preserves_PreviousForcedBackend;
var
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

  CheckTrue(LPreviousForcedBackend <> LAutomaticBackend, 'Previous forced backend should differ from automatic best backend in vector-asm late-reset test');
  CheckTrue(TrySetActiveBackend(LPreviousForcedBackend), 'Previous forced backend setup should succeed before vector-asm late-reset test');
  CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Previous forced backend should be active before vector-asm late-reset test');

  GDispatchHookResetToAutomaticEnabled := True;
  GDispatchHookResetToAutomaticStage := 0;
  AddDispatchChangedHook(@DispatchHookResetToAutomaticOnce);
  try
    SetVectorAsmEnabled(False);
    CheckEqual(2, GDispatchHookResetToAutomaticStage, 'Synthetic vector-asm late-reset hook should run through the real SetVectorAsmEnabled callback sequence');
    CheckTrue(GetActiveBackend <> LPreviousForcedBackend, 'Disabling vector asm should move current backend away from the previously forced backend when it becomes non-dispatchable');
  finally
    RemoveDispatchChangedHook(@DispatchHookResetToAutomaticOnce);
    GDispatchHookResetToAutomaticEnabled := False;
    GDispatchHookResetToAutomaticStage := 0;
  end;

  SetVectorAsmEnabled(True);
  CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Re-enabling vector asm should preserve the previously forced backend even if a late hook resets to automatic during disable');
end;

procedure TTestCase_DispatchAPIControlPlane.Test_SetVectorAsmEnabled_HookLateAutomaticReset_DuringRestore_Preserves_PreviousForcedBackend;
var
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

  CheckTrue(LPreviousForcedBackend <> LAutomaticBackend, 'Previous forced backend should differ from automatic best backend in vector-asm restore-callback late-reset test');
  CheckTrue(TrySetActiveBackend(LPreviousForcedBackend), 'Previous forced backend setup should succeed before vector-asm restore-callback late-reset test');
  CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Previous forced backend should be active before vector-asm restore-callback late-reset test');

  GDispatchHookToggleRestoreResetEnabled := True;
  GDispatchHookToggleRestoreResetStage := 0;
  AddDispatchChangedHook(@DispatchHookResetToAutomaticOnToggleRestore);
  try
    SetVectorAsmEnabled(False);
    CheckEqual(5, GDispatchHookToggleRestoreResetStage, 'Synthetic vector-asm restore-callback late-reset hook should run through the full callback sequence');
    CheckTrue(GetActiveBackend <> LPreviousForcedBackend, 'Disabling vector asm should move current backend away from the previously forced backend when it becomes non-dispatchable');
  finally
    RemoveDispatchChangedHook(@DispatchHookResetToAutomaticOnToggleRestore);
    GDispatchHookToggleRestoreResetEnabled := False;
    GDispatchHookToggleRestoreResetStage := 0;
  end;

  SetVectorAsmEnabled(True);
  CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Re-enabling vector asm should preserve the previously forced backend even if a late hook resets to automatic during restore callback');
end;

procedure TTestCase_DispatchAPIControlPlane.Test_SetVectorAsmEnabled_HookLateForce_DuringRestore_Preserves_PreviousForcedBackend;
var
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

  CheckTrue(LPreviousForcedBackend <> LAutomaticBackend, 'Previous forced backend should differ from automatic best backend in vector-asm restore-callback late-force test');
  CheckTrue(TrySetActiveBackend(LPreviousForcedBackend), 'Previous forced backend setup should succeed before vector-asm restore-callback late-force test');
  CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Previous forced backend should be active before vector-asm restore-callback late-force test');

  GDispatchHookResetLateForceEnabled := True;
  GDispatchHookResetLateForceStage := 0;
  GDispatchHookResetLateForceTarget := sbScalar;
  AddDispatchChangedHook(@DispatchHookReForceBackendOnAutomaticRestore);
  try
    SetVectorAsmEnabled(False);
    CheckEqual(5, GDispatchHookResetLateForceStage, 'Synthetic vector-asm restore-callback late-force hook should run through the full callback sequence');
    CheckTrue(GetActiveBackend <> LPreviousForcedBackend, 'Disabling vector asm should move current backend away from the previously forced backend when it becomes non-dispatchable');
  finally
    RemoveDispatchChangedHook(@DispatchHookReForceBackendOnAutomaticRestore);
    GDispatchHookResetLateForceEnabled := False;
    GDispatchHookResetLateForceStage := 0;
    GDispatchHookResetLateForceTarget := sbScalar;
  end;

  SetVectorAsmEnabled(True);
  CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Re-enabling vector asm should preserve the previously forced backend even if a late hook re-forces scalar during restore callback');
  CheckTrue(GetActiveBackend <> sbScalar, 'Vector-asm restore-callback late-force path should not remain stuck on scalar after re-enable');
end;

procedure TTestCase_DispatchAPIControlPlane.Test_SetVectorAsmEnabled_HookLateForce_DuringThirdRestore_Preserves_PreviousForcedBackend;
var
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

  CheckTrue(LPreviousForcedBackend <> LAutomaticBackend, 'Previous forced backend should differ from automatic best backend in vector-asm third-restore late-force test');
  CheckTrue(TrySetActiveBackend(LPreviousForcedBackend), 'Previous forced backend setup should succeed before vector-asm third-restore late-force test');
  CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Previous forced backend should be active before vector-asm third-restore late-force test');

  GDispatchHookResetLateForceEnabled := True;
  GDispatchHookResetLateForceStage := 0;
  GDispatchHookResetLateForceTarget := sbScalar;
  AddDispatchChangedHook(@DispatchHookReForceBackendOnAutomaticThirdRestore);
  try
    SetVectorAsmEnabled(False);
    CheckEqual(7, GDispatchHookResetLateForceStage, 'Synthetic vector-asm third-restore late-force hook should run through the full callback sequence');
    CheckTrue(GetActiveBackend <> LPreviousForcedBackend, 'Disabling vector asm should move current backend away from the previously forced backend when it becomes non-dispatchable');
  finally
    RemoveDispatchChangedHook(@DispatchHookReForceBackendOnAutomaticThirdRestore);
    GDispatchHookResetLateForceEnabled := False;
    GDispatchHookResetLateForceStage := 0;
    GDispatchHookResetLateForceTarget := sbScalar;
  end;

  SetVectorAsmEnabled(True);
  CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Re-enabling vector asm should preserve the previously forced backend even if a late hook re-forces scalar during the third restore callback');
  CheckTrue(GetActiveBackend <> sbScalar, 'Vector-asm third-restore late-force path should not remain stuck on scalar after re-enable');
end;

procedure TTestCase_DispatchAPIControlPlane.Test_SetVectorAsmEnabled_HookLateForce_UntilAttemptCap_Preserves_PreviousForcedBackend;
var
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

    CheckTrue(LPreviousForcedBackend <> LAutomaticBackend, 'Previous forced backend should differ from automatic best backend in vector-asm attempt-cap late-force test');
    CheckTrue(TrySetActiveBackend(LPreviousForcedBackend), 'Previous forced backend setup should succeed before vector-asm attempt-cap late-force test');
    CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Previous forced backend should be active before vector-asm attempt-cap late-force test');

    GDispatchHookResetLateForceEnabled := True;
    GDispatchHookResetLateForceStage := 0;
    GDispatchHookResetLateForceTarget := sbScalar;
    AddDispatchChangedHook(@DispatchHookReForceBackendOnToggleRestoreUntilAttemptCap);
    try
      SetVectorAsmEnabled(False);
      CheckEqual(20, GDispatchHookResetLateForceStage, 'Synthetic vector-asm previous-forced attempt-cap late-force hook should observe the post-cap restore closeout callback');
      CheckTrue(GetActiveBackend <> LPreviousForcedBackend, 'Disabling vector asm should move current backend away from the previously forced backend when it becomes non-dispatchable');
    finally
      RemoveDispatchChangedHook(@DispatchHookReForceBackendOnToggleRestoreUntilAttemptCap);
      GDispatchHookResetLateForceEnabled := False;
      GDispatchHookResetLateForceStage := 0;
      GDispatchHookResetLateForceTarget := sbScalar;
    end;

    SetVectorAsmEnabled(True);
    CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Re-enabling vector asm should preserve the previously forced backend after repeated late scalar force exhausts the bounded restore helper');
  finally
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_RegisterBackend_HookLateForce_Restores_AutomaticBackend;
var
  LAutomaticBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
begin
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LAutomaticBackend := GetBestDispatchableBackend;
  if LAutomaticBackend = sbScalar then
    Exit;

  CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'Automatic backend should be active before RegisterBackend late-force test');
  CheckTrue(TryGetRegisteredBackendDispatchTable(LAutomaticBackend, LOriginalTable), 'Automatic backend table should be registered for RegisterBackend late-force test');

  GDispatchHookReForceBackendTarget := sbScalar;
  GDispatchHookReForceBackendEnabled := True;
  GDispatchHookReForceBackendStage := 0;
  AddDispatchChangedHook(@DispatchHookReForceBackendOnce);
  try
    RegisterBackend(LAutomaticBackend, LOriginalTable);
    CheckEqual(2, GDispatchHookReForceBackendStage, 'Synthetic RegisterBackend late-force hook should run through the real callback sequence');
    CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'RegisterBackend should restore automatic best backend even if a late hook re-forces scalar during notification');
    CheckTrue(GetActiveBackend <> sbScalar, 'RegisterBackend should not return with stale scalar forced fallback when automatic best backend remains non-scalar');
    CheckEqual(Ord(GetBestDispatchableBackend), Ord(GetActiveBackend), 'RegisterBackend should leave active backend aligned with best dispatchable backend after late hook mutation');
  finally
    RemoveDispatchChangedHook(@DispatchHookReForceBackendOnce);
    GDispatchHookReForceBackendEnabled := False;
    GDispatchHookReForceBackendStage := 0;
    GDispatchHookReForceBackendTarget := sbScalar;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_RegisterBackend_HookLateForce_DuringThirdRestore_Restores_AutomaticBackend;
var
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

    CheckTrue(TryGetRegisteredBackendDispatchTable(LAutomaticBackend, LOriginalTable), 'Automatic backend table should be registered for RegisterBackend third-restore late-force test');

    GDispatchHookResetLateForceTarget := sbScalar;
    GDispatchHookResetLateForceEnabled := True;
    GDispatchHookResetLateForceStage := 0;
    AddDispatchChangedHook(@DispatchHookReForceBackendOnAutomaticThirdRestore);
    try
      RegisterBackend(LAutomaticBackend, LOriginalTable);
      CheckEqual(7, GDispatchHookResetLateForceStage, 'Synthetic RegisterBackend automatic third-late-force hook should run through the full callback sequence');
      CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'RegisterBackend should still restore automatic best backend even if a late hook re-forces scalar during the third restore notification');
      CheckTrue(GetActiveBackend <> sbScalar, 'RegisterBackend automatic third-restore late-force path should not remain stuck on scalar when a better automatic backend exists');
      CheckEqual(Ord(GetBestDispatchableBackend), Ord(GetActiveBackend), 'RegisterBackend automatic third-restore late-force path should leave active backend aligned with best dispatchable backend');
    finally
      RemoveDispatchChangedHook(@DispatchHookReForceBackendOnAutomaticThirdRestore);
      GDispatchHookResetLateForceEnabled := False;
      GDispatchHookResetLateForceStage := 0;
      GDispatchHookResetLateForceTarget := sbScalar;
    end;
  finally
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_RegisterBackend_HookLateForce_UntilAttemptCap_Restores_AutomaticBackend;
var
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

    CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'Automatic backend should be active before RegisterBackend attempt-cap late-force test');
    CheckTrue(TryGetRegisteredBackendDispatchTable(LAutomaticBackend, LOriginalTable), 'Automatic backend table should be registered for RegisterBackend attempt-cap late-force test');

    GDispatchHookResetLateForceTarget := sbScalar;
    GDispatchHookResetLateForceEnabled := True;
    GDispatchHookResetLateForceStage := 0;
    AddDispatchChangedHook(@DispatchHookReForceBackendOnRegisterRestoreUntilAttemptCap);
    try
      RegisterBackend(LAutomaticBackend, LOriginalTable);
      CheckEqual(20, GDispatchHookResetLateForceStage, 'Synthetic RegisterBackend attempt-cap late-force hook should observe the post-cap automatic closeout callback');
      CheckEqual(Ord(LAutomaticBackend), Ord(GetActiveBackend), 'RegisterBackend should restore automatic best backend after repeated late scalar force exhausts the bounded restore helper');
      CheckTrue(GetActiveBackend <> sbScalar, 'RegisterBackend attempt-cap late-force path should not remain stuck on scalar when a better automatic backend exists');
      CheckEqual(Ord(GetBestDispatchableBackend), Ord(GetActiveBackend), 'RegisterBackend attempt-cap late-force path should leave active backend aligned with best dispatchable backend');
    finally
      RemoveDispatchChangedHook(@DispatchHookReForceBackendOnRegisterRestoreUntilAttemptCap);
      GDispatchHookResetLateForceEnabled := False;
      GDispatchHookResetLateForceStage := 0;
      GDispatchHookResetLateForceTarget := sbScalar;
    end;
  finally
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_RegisterBackend_HookLateAutomaticReset_Preserves_PreviousForcedBackend;
var
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

    CheckTrue(LPreviousForcedBackend <> LAutomaticBackend, 'Previous forced backend should differ from automatic best backend in RegisterBackend late-reset test');
    CheckTrue(TrySetActiveBackend(LPreviousForcedBackend), 'Previous forced backend setup should succeed before RegisterBackend late-reset test');
    CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Previous forced backend should be active before RegisterBackend late-reset test');

    CheckTrue(TryGetRegisteredBackendDispatchTable(LPreviousForcedBackend, LPreviousOriginalTable), 'Previous forced backend table should be registered for RegisterBackend late-reset test');
    LPreviousTableCaptured := True;

    GDispatchHookRegisterRestoreResetEnabled := True;
    GDispatchHookRegisterRestoreResetStage := 0;
    AddDispatchChangedHook(@DispatchHookLateAutomaticResetOnRegisterRestore);
    try
      RegisterBackend(LPreviousForcedBackend, LPreviousOriginalTable);
      CheckEqual(5, GDispatchHookRegisterRestoreResetStage, 'Synthetic RegisterBackend late-reset hook should run through the full callback sequence');
      CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'RegisterBackend should preserve the previous forced backend even if a late hook resets to automatic during restore notification');
      CheckTrue(GetActiveBackend <> LAutomaticBackend, 'RegisterBackend late-reset path should not silently drift to automatic best backend when a previous forced backend exists');
      CheckTrue(GetActiveBackend <> sbScalar, 'RegisterBackend late-reset path should not leave scalar active while restoring previous forced backend');
    finally
      RemoveDispatchChangedHook(@DispatchHookLateAutomaticResetOnRegisterRestore);
      GDispatchHookRegisterRestoreResetEnabled := False;
      GDispatchHookRegisterRestoreResetStage := 0;
    end;
  finally
    if LPreviousTableCaptured then
      RegisterBackend(LPreviousForcedBackend, LPreviousOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_RegisterBackend_HookLateForce_DuringRestore_Preserves_PreviousForcedBackend;
var
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

    CheckTrue(LPreviousForcedBackend <> LAutomaticBackend, 'Previous forced backend should differ from automatic best backend in RegisterBackend restore-callback late-force test');
    CheckTrue(TrySetActiveBackend(LPreviousForcedBackend), 'Previous forced backend setup should succeed before RegisterBackend restore-callback late-force test');
    CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Previous forced backend should be active before RegisterBackend restore-callback late-force test');

    CheckTrue(TryGetRegisteredBackendDispatchTable(LPreviousForcedBackend, LPreviousOriginalTable), 'Previous forced backend table should be registered for RegisterBackend restore-callback late-force test');
    LPreviousTableCaptured := True;

    GDispatchHookResetLateForceEnabled := True;
    GDispatchHookResetLateForceStage := 0;
    GDispatchHookResetLateForceTarget := sbScalar;
    AddDispatchChangedHook(@DispatchHookReForceBackendOnAutomaticRestore);
    try
      RegisterBackend(LPreviousForcedBackend, LPreviousOriginalTable);
      CheckEqual(5, GDispatchHookResetLateForceStage, 'Synthetic RegisterBackend restore-callback late-force hook should run through the full callback sequence');
      CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'RegisterBackend should preserve the previous forced backend even if a late hook re-forces scalar during restore notification');
      CheckTrue(GetActiveBackend <> LAutomaticBackend, 'RegisterBackend restore-callback late-force path should not silently drift to automatic best backend when a previous forced backend exists');
      CheckTrue(GetActiveBackend <> sbScalar, 'RegisterBackend restore-callback late-force path should not remain stuck on scalar while restoring previous forced backend');
    finally
      RemoveDispatchChangedHook(@DispatchHookReForceBackendOnAutomaticRestore);
      GDispatchHookResetLateForceEnabled := False;
      GDispatchHookResetLateForceStage := 0;
      GDispatchHookResetLateForceTarget := sbScalar;
    end;
  finally
    if LPreviousTableCaptured then
      RegisterBackend(LPreviousForcedBackend, LPreviousOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_RegisterBackend_HookLateForce_DuringThirdRestore_Preserves_PreviousForcedBackend;
var
  LDispatchable: TSimdBackendArray;
  LAutomaticBackend: TSimdBackend;
  LPreviousForcedBackend: TSimdBackend;
  LPreviousOriginalTable: TSimdDispatchTable;
  LPreviousTableCaptured: Boolean;
  LOldVectorAsm: Boolean;
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

    CheckTrue(LPreviousForcedBackend <> LAutomaticBackend, 'Previous forced backend should differ from automatic best backend in RegisterBackend third-restore late-force test');
    CheckTrue(TrySetActiveBackend(LPreviousForcedBackend), 'Previous forced backend setup should succeed before RegisterBackend third-restore late-force test');
    CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Previous forced backend should be active before RegisterBackend third-restore late-force test');

    CheckTrue(TryGetRegisteredBackendDispatchTable(LPreviousForcedBackend, LPreviousOriginalTable), 'Previous forced backend table should be registered for RegisterBackend third-restore late-force test');
    LPreviousTableCaptured := True;

    GDispatchHookResetLateForceEnabled := True;
    GDispatchHookResetLateForceStage := 0;
    GDispatchHookResetLateForceTarget := sbScalar;
    AddDispatchChangedHook(@DispatchHookReForceBackendOnAutomaticThirdRestore);
    try
      RegisterBackend(LPreviousForcedBackend, LPreviousOriginalTable);
      CheckEqual(7, GDispatchHookResetLateForceStage, 'Synthetic RegisterBackend third-late-force hook should run through the full callback sequence');
      CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'RegisterBackend should preserve the previous forced backend even if a late hook re-forces scalar during the third restore notification');
      CheckTrue(GetActiveBackend <> LAutomaticBackend, 'RegisterBackend third-restore late-force path should not silently drift to automatic best backend when a previous forced backend exists');
      CheckTrue(GetActiveBackend <> sbScalar, 'RegisterBackend third-restore late-force path should not remain stuck on scalar while restoring previous forced backend');
    finally
      RemoveDispatchChangedHook(@DispatchHookReForceBackendOnAutomaticThirdRestore);
      GDispatchHookResetLateForceEnabled := False;
      GDispatchHookResetLateForceStage := 0;
      GDispatchHookResetLateForceTarget := sbScalar;
    end;
  finally
    if LPreviousTableCaptured then
      RegisterBackend(LPreviousForcedBackend, LPreviousOriginalTable);
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_RegisterBackend_HookLateForce_UntilAttemptCap_Preserves_PreviousForcedBackend;
var
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

    CheckTrue(LPreviousForcedBackend <> LAutomaticBackend, 'Previous forced backend should differ from automatic best backend in RegisterBackend attempt-cap late-force test');
    CheckTrue(TrySetActiveBackend(LPreviousForcedBackend), 'Previous forced backend setup should succeed before RegisterBackend attempt-cap late-force test');
    CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'Previous forced backend should be active before RegisterBackend attempt-cap late-force test');

    CheckTrue(TryGetRegisteredBackendDispatchTable(LPreviousForcedBackend, LPreviousOriginalTable), 'Previous forced backend table should be registered for RegisterBackend attempt-cap late-force test');
    LPreviousTableCaptured := True;

    GDispatchHookResetLateForceEnabled := True;
    GDispatchHookResetLateForceStage := 0;
    GDispatchHookResetLateForceTarget := sbScalar;
    AddDispatchChangedHook(@DispatchHookReForceBackendOnRegisterRestoreUntilAttemptCap);
    try
      RegisterBackend(LPreviousForcedBackend, LPreviousOriginalTable);
      CheckEqual(20, GDispatchHookResetLateForceStage, 'Synthetic RegisterBackend previous-forced attempt-cap late-force hook should observe the post-cap restore closeout callback');
      CheckEqual(Ord(LPreviousForcedBackend), Ord(GetActiveBackend), 'RegisterBackend should preserve the previous forced backend after repeated late scalar force exhausts the bounded restore helper');
      CheckTrue(GetActiveBackend <> LAutomaticBackend, 'RegisterBackend attempt-cap late-force path should not silently drift to automatic best backend when a previous forced backend exists');
      CheckTrue(GetActiveBackend <> sbScalar, 'RegisterBackend attempt-cap late-force path should not remain stuck on scalar while restoring previous forced backend');
    finally
      RemoveDispatchChangedHook(@DispatchHookReForceBackendOnRegisterRestoreUntilAttemptCap);
      GDispatchHookResetLateForceEnabled := False;
      GDispatchHookResetLateForceStage := 0;
      GDispatchHookResetLateForceTarget := sbScalar;
    end;
  finally
    if LPreviousTableCaptured then
      RegisterBackend(LPreviousForcedBackend, LPreviousOriginalTable);
    SetVectorAsmEnabled(LOldVectorAsm);
    ResetToAutomaticBackend;
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_RegisterBackend_Canonicalizes_TableIdentity_For_ForcedSelection;
var
  LOriginalBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LModifiedTable: TSimdDispatchTable;
begin
  GetDispatchTable;
  SetVectorAsmEnabled(True);
  ResetToAutomaticBackend;
  LOriginalBackend := GetActiveBackend;
  if LOriginalBackend = sbScalar then
    Exit;

  CheckTrue(TryGetRegisteredBackendDispatchTable(LOriginalBackend, LOriginalTable), 'Original active backend should be registered for canonical identity test');

  LModifiedTable := LOriginalTable;
  LModifiedTable.Backend := sbScalar;
  LModifiedTable.BackendInfo.Backend := sbScalar;
  RegisterBackend(LOriginalBackend, LModifiedTable);
  try
    CheckTrue(IsBackendDispatchable(LOriginalBackend), 'Synthetic identity-mismatch setup should keep the backend dispatchable');
    CheckTrue(TrySetActiveBackend(LOriginalBackend), 'TrySetActiveBackend should still report success for the requested backend slot');
    CheckEqual(Ord(LOriginalBackend), Ord(GetActiveBackend), 'Forced selection should expose the requested backend id, not the stale table Backend field');
    CheckEqual(Ord(LOriginalBackend), Ord(GetBackendInfo(LOriginalBackend).Backend), 'GetBackendInfo should expose the canonical backend id after RegisterBackend');
  finally
    RegisterBackend(LOriginalBackend, LOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_SupportedAliases_StayCpuOnly_WhenBackendBecomesNonDispatchable;
var
  LOriginalBackend: TSimdBackend;
  LOriginalBestSupported: TSimdBackend;
  LAfterAuto: TSimdBackend;
  LSupportedView: TSimdBackendArray;
  LSupportedCompatView: TSimdBackendArray;
  LDispatchableView: TSimdBackendArray;
  LAvailableView: TSimdBackendArray;
  LOriginalTable: TSimdDispatchTable;
  LModifiedTable: TSimdDispatchTable;

  function BackendInArray(const aItems: TSimdBackendArray; aBackend: TSimdBackend): Boolean;
  var
    LItemIndex: Integer;
  begin
    for LItemIndex := 0 to High(aItems) do
      if aItems[LItemIndex] = aBackend then
        Exit(True);
    Result := False;
  end;
begin
  ResetToAutomaticBackend;
  LOriginalBackend := GetActiveBackend;

  // On targets where Scalar is the only meaningful runtime backend, this
  // semantic split cannot be exercised.
  if LOriginalBackend = sbScalar then
    Exit;

  CheckTrue(IsBackendAvailableOnCPU(LOriginalBackend), 'Original active backend should be CPU-supported');
  CheckTrue(IsBackendDispatchable(LOriginalBackend), 'Original active backend should be dispatchable');
  CheckEqual(Ord(LOriginalBackend), Ord(GetBestDispatchableBackend), 'Automatic selection should start from best dispatchable backend');
  LOriginalBestSupported := nextpas.core.simd.GetBestSupportedBackend;

  CheckTrue(TryGetRegisteredBackendDispatchTable(LOriginalBackend, LOriginalTable), 'Original active backend should be registered');

  LSupportedView := nextpas.core.simd.GetSupportedBackendList;
  LSupportedCompatView := nextpas.core.simd.cpuinfo.GetAvailableBackends;
  LDispatchableView := nextpas.core.simd.GetDispatchableBackendList;
  LAvailableView := nextpas.core.simd.GetAvailableBackendList;
  CheckTrue(BackendInArray(LSupportedView, LOriginalBackend), 'Supported view should include original active backend');
  CheckTrue(BackendInArray(LSupportedCompatView, LOriginalBackend), 'cpuinfo compatibility alias should include original active backend');
  CheckTrue(BackendInArray(LDispatchableView, LOriginalBackend), 'Dispatchable view should include original active backend');
  CheckTrue(BackendInArray(LAvailableView, LOriginalBackend), 'Available backend list should include original active backend');

  LModifiedTable := LOriginalTable;
  LModifiedTable.BackendInfo.Available := False;
  RegisterBackend(LOriginalBackend, LModifiedTable);
  try
    CheckTrue(IsBackendAvailableOnCPU(LOriginalBackend), 'CPU-supported predicate should not change when dispatch wiring is disabled');
    CheckFalse(IsBackendDispatchable(LOriginalBackend), 'Dispatchable predicate should clear when BackendInfo.Available=False');

    LSupportedView := nextpas.core.simd.GetSupportedBackendList;
    LSupportedCompatView := nextpas.core.simd.cpuinfo.GetAvailableBackends;
    LDispatchableView := nextpas.core.simd.GetDispatchableBackendList;
    LAvailableView := nextpas.core.simd.GetAvailableBackendList;

    CheckTrue(BackendInArray(LSupportedView, LOriginalBackend), 'Supported view should remain CPU-only when dispatchability changes');
    CheckTrue(BackendInArray(LSupportedCompatView, LOriginalBackend), 'cpuinfo compatibility alias should remain CPU-only when dispatchability changes');
    CheckFalse(BackendInArray(LDispatchableView, LOriginalBackend), 'Dispatchable view should exclude backend marked unavailable for dispatch');
    CheckFalse(BackendInArray(LAvailableView, LOriginalBackend), 'Available backend list should continue to alias dispatchable view');
    CheckEqual(Ord(LOriginalBestSupported), Ord(nextpas.core.simd.GetBestSupportedBackend), 'Best supported backend should remain tied to CPU-only semantics');

    ResetToAutomaticBackend;
    LAfterAuto := GetActiveBackend;
    CheckTrue(LAfterAuto <> LOriginalBackend, 'Automatic selection should move away from backend marked unavailable');
    CheckEqual(Ord(LOriginalBestSupported), Ord(nextpas.core.simd.GetBestSupportedBackend), 'Best supported backend should remain stable after automatic reselection');
  finally
    RegisterBackend(LOriginalBackend, LOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_PublicSmokeDefaultBackendPredictor_Tracks_CanonicalDispatchPriority;
var
  LAVX2Table: TSimdDispatchTable;
  LModifiedAVX2Table: TSimdDispatchTable;
begin
  {$IFNDEF SIMD_X86_AVAILABLE}
  Exit;
  {$ENDIF}

  GetDispatchTable;
  try
    SetVectorAsmEnabled(True);
    if not IsVectorAsmEnabled then
      Exit;
    if not IsBackendDispatchable(sbAVX2) then
      Exit;
    if not IsBackendDispatchable(sbSSE42) then
      Exit;

    CheckEqual(Ord(GetBestDispatchableBackend), Ord(GetExpectedPublicSmokeDefaultBackend), 'Public smoke default backend predictor should initially match canonical dispatch priority');

    CheckTrue(TryGetRegisteredBackendDispatchTable(sbAVX2, LAVX2Table), 'AVX2 backend should be registered for synthetic dispatch-priority split');

    LModifiedAVX2Table := LAVX2Table;
    LModifiedAVX2Table.BackendInfo.Available := False;
    RegisterBackend(sbAVX2, LModifiedAVX2Table);
    try
      CheckEqual(Ord(sbSSE42), Ord(GetBestDispatchableBackend), 'Canonical dispatch priority should move to SSE4.2 when AVX2 becomes non-dispatchable');
      CheckEqual(Ord(GetBestDispatchableBackend), Ord(GetExpectedPublicSmokeDefaultBackend), 'Public smoke default backend predictor should follow canonical dispatch priority after AVX2 becomes non-dispatchable');
    finally
      RegisterBackend(sbAVX2, LAVX2Table);
    end;
  finally
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_VectorAsmDisabled_ReSelects_Away_From_ScalarBacked_CurrentBackend;
var
  LOriginalBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LDispatchableView: TSimdBackendArray;
  LAvailableView: TSimdBackendArray;
  LIndex: Integer;

  function BackendInArray(const aItems: TSimdBackendArray; aBackend: TSimdBackend): Boolean;
  var
    LItemIndex: Integer;
  begin
    for LItemIndex := 0 to High(aItems) do
      if aItems[LItemIndex] = aBackend then
        Exit(True);
    Result := False;
  end;

  function IsScalarBackedForRepresentativeSlots(const aBackendTable, aScalarTable: TSimdDispatchTable): Boolean;
  begin
    Result :=
      (Pointer(aBackendTable.CoreVectors.AddF32x4) = Pointer(aScalarTable.CoreVectors.AddF32x4)) and
      (Pointer(aBackendTable.CoreVectors.MulF32x4) = Pointer(aScalarTable.CoreVectors.MulF32x4)) and
      (Pointer(aBackendTable.CoreVectors.AddI32x4) = Pointer(aScalarTable.CoreVectors.AddI32x4)) and
      (Pointer(aBackendTable.CoreVectors.SelectF32x4) = Pointer(aScalarTable.CoreVectors.SelectF32x4));
  end;
begin
  ResetToAutomaticBackend;
  LOriginalBackend := GetCurrentBackend;
  if LOriginalBackend = sbScalar then
    Exit;

  CheckTrue(TryGetRegisteredBackendDispatchTable(LOriginalBackend, LOriginalTable), 'Original active backend should be registered');
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  GetDispatchTable;
  try
    SetVectorAsmEnabled(True);
    SetVectorAsmEnabled(False);
    CheckFalse(IsVectorAsmEnabled, 'Vector asm should be disabled for current-backend reselection test');

    CheckTrue(TryGetRegisteredBackendDispatchTable(LOriginalBackend, LOriginalTable), 'Original active backend should remain registered after runtime rebuild');

    if not IsScalarBackedForRepresentativeSlots(LOriginalTable, LScalarTable) then
      Exit;

    CheckFalse(IsBackendDispatchable(LOriginalBackend), 'Scalar-backed backend should not remain dispatchable after vector asm disable');
    CheckTrue(GetCurrentBackend <> LOriginalBackend, 'Automatic selection should move away from scalar-backed original backend after vector asm disable');
    CheckEqual(Ord(GetBestDispatchableBackend), Ord(GetCurrentBackend), 'Best dispatchable backend should track current backend after vector asm disable reselection');

    LDispatchableView := GetDispatchableBackendList;
    LAvailableView := nextpas.core.simd.GetAvailableBackendList;
    CheckFalse(BackendInArray(LDispatchableView, LOriginalBackend), 'Dispatchable view should exclude scalar-backed original backend after vector asm disable');
    CheckFalse(BackendInArray(LAvailableView, LOriginalBackend), 'Available backend list should continue to alias dispatchable view after vector asm disable');

    for LIndex := 0 to High(LDispatchableView) do
      CheckTrue(IsBackendDispatchable(LDispatchableView[LIndex]), 'Dispatchable view should only contain dispatchable backends after vector asm disable');
  finally
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_BackendConceptViews_AreSelfConsistent;
var
  LSupported: TSimdBackendArray;
  LRegistered: TSimdBackendArray;
  LDispatchable: TSimdBackendArray;
  LBackend: TSimdBackend;
  LIndex: Integer;

  function BackendInArray(const aItems: TSimdBackendArray; aBackend: TSimdBackend): Boolean;
  var
    LItemIndex: Integer;
  begin
    for LItemIndex := 0 to High(aItems) do
      if aItems[LItemIndex] = aBackend then
        Exit(True);
    Result := False;
  end;
begin
  LSupported := nextpas.core.simd.GetSupportedBackendList;
  LRegistered := nextpas.core.simd.GetRegisteredBackendList;
  LDispatchable := nextpas.core.simd.GetDispatchableBackendList;

  CheckTrue(BackendInArray(LSupported, sbScalar), 'Supported backend list should contain Scalar');
  CheckTrue(BackendInArray(LRegistered, sbScalar), 'Registered backend list should contain Scalar');
  CheckTrue(BackendInArray(LDispatchable, sbScalar), 'Dispatchable backend list should contain Scalar');

  for LIndex := 0 to High(LSupported) do
  begin
    LBackend := LSupported[LIndex];
    CheckTrue(IsBackendAvailableOnCPU(LBackend), 'Supported view must satisfy cpu-support predicate for backend=' + DispatchApiBackendName(LBackend));
  end;

  for LIndex := 0 to High(LRegistered) do
  begin
    LBackend := LRegistered[LIndex];
    CheckTrue(nextpas.core.simd.IsBackendRegisteredInBinary(LBackend), 'Registered view must satisfy registered predicate for backend=' + DispatchApiBackendName(LBackend));
  end;

  for LIndex := 0 to High(LDispatchable) do
  begin
    LBackend := LDispatchable[LIndex];
    CheckTrue(IsBackendDispatchable(LBackend), 'Dispatchable view must satisfy dispatchable predicate for backend=' + DispatchApiBackendName(LBackend));
    CheckTrue(BackendInArray(LRegistered, LBackend), 'Dispatchable view must be subset of registered view for backend=' + DispatchApiBackendName(LBackend));
    CheckTrue(BackendInArray(LSupported, LBackend), 'Dispatchable view must be subset of supported view for backend=' + DispatchApiBackendName(LBackend));
  end;

  CheckTrue(IsBackendDispatchable(nextpas.core.simd.GetCurrentBackend), 'Current active backend must be dispatchable');
  CheckTrue(IsBackendDispatchable(nextpas.core.simd.GetBestDispatchableBackend), 'Best dispatchable backend must be dispatchable');
  CheckTrue(IsBackendAvailableOnCPU(nextpas.core.simd.GetBestSupportedBackend), 'Best supported backend must be cpu-supported');
end;

procedure TTestCase_DispatchAPIControlPlane.Test_GetAvailableBackendList_AliasesDispatchableView;
var
  LAvailable: TSimdBackendArray;
  LDispatchable: TSimdBackendArray;
  LIndex: Integer;
begin
  LAvailable := nextpas.core.simd.GetAvailableBackendList;
  LDispatchable := nextpas.core.simd.GetDispatchableBackendList;

  CheckEqual(Length(LDispatchable), Length(LAvailable), 'Available backend list length should match dispatchable view');

  for LIndex := 0 to High(LAvailable) do
    CheckEqual(Ord(LDispatchable[LIndex]), Ord(LAvailable[LIndex]), 'Available backend list should alias dispatchable ordering at index ' + IntToStr(LIndex));
end;

procedure TTestCase_DispatchAPIControlPlane.Test_RegisteredBackendPriority_MatchesCanonicalPriority;
var
  LBackend: TSimdBackend;
  LTable: TSimdDispatchTable;
begin
  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
  begin
    if not TryGetRegisteredBackendDispatchTable(LBackend, LTable) then
      Continue;

    CheckEqual(GetSimdBackendPriorityValue(LBackend), LTable.BackendInfo.Priority, 'Registered table priority should match canonical priority for backend=' + DispatchApiBackendName(LBackend));
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_UnregisteredBackendInfo_PreservesCanonicalTextMetadata;
var
  LBackend: TSimdBackend;
  LInfo: TSimdBackendInfo;
  LNamePtr: PAnsiChar;
  LDescriptionPtr: PAnsiChar;
  LFoundUnregistered: Boolean;
begin
  LFoundUnregistered := False;
  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
  begin
    if IsBackendRegistered(LBackend) then
      Continue;

    LFoundUnregistered := True;
    LInfo := GetBackendInfo(LBackend);
    LNamePtr := GetSimdBackendNamePtr(LBackend);
    LDescriptionPtr := GetSimdBackendDescriptionPtr(LBackend);

    CheckTrue(LInfo.Name <> '', 'GetBackendInfo should preserve non-empty name for unregistered backend=' + DispatchApiBackendName(LBackend));
    CheckTrue(LInfo.Description <> '', 'GetBackendInfo should preserve non-empty description for unregistered backend=' + DispatchApiBackendName(LBackend));
    CheckNotNil(Pointer(LNamePtr), 'Public ABI backend name pointer should not be nil for unregistered backend=' + DispatchApiBackendName(LBackend));
    CheckNotNil(Pointer(LDescriptionPtr), 'Public ABI backend description pointer should not be nil for unregistered backend=' + DispatchApiBackendName(LBackend));
    CheckEqual(LInfo.Name, string(LNamePtr), 'Dispatch/public ABI backend name should stay aligned for unregistered backend=' + DispatchApiBackendName(LBackend));
    CheckEqual(LInfo.Description, string(LDescriptionPtr), 'Dispatch/public ABI backend description should stay aligned for unregistered backend=' + DispatchApiBackendName(LBackend));
  end;

  CheckTrue(LFoundUnregistered, 'At least one unregistered backend should exist for metadata coverage');
end;

procedure TTestCase_DispatchAPIControlPlane.Test_RegisteredBackendDispatchTable_PreservesCanonicalTextMetadata_After_ReRegister;
var
  LBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LModifiedTable: TSimdDispatchTable;
  LReloadedTable: TSimdDispatchTable;
  LCanonicalInfo: TSimdBackendInfo;
begin
  ResetToAutomaticBackend;
  LBackend := GetCurrentBackend;

  CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable), 'Current backend should be registered for registered-table canonical text test');

  LModifiedTable := LOriginalTable;
  LModifiedTable.BackendInfo.Name := '';
  LModifiedTable.BackendInfo.Description := '';
  RegisterBackend(LBackend, LModifiedTable);
  try
    CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, LReloadedTable), 'Registered backend table should still be readable after re-register');

    LCanonicalInfo := GetBackendInfo(LBackend);

    CheckEqual(Ord(LBackend), Ord(LReloadedTable.Backend), 'Registered table backend id should stay canonical after re-register');
    CheckEqual(Ord(LBackend), Ord(LReloadedTable.BackendInfo.Backend), 'Registered table BackendInfo.Backend should stay canonical after re-register');
    CheckTrue(LReloadedTable.BackendInfo.Name <> '', 'Registered backend table should preserve non-empty name after re-register');
    CheckTrue(LReloadedTable.BackendInfo.Description <> '', 'Registered backend table should preserve non-empty description after re-register');
    CheckEqual(LCanonicalInfo.Name, LReloadedTable.BackendInfo.Name, 'Registered backend table name should stay aligned with canonical backend info after re-register');
    CheckEqual(LCanonicalInfo.Description, LReloadedTable.BackendInfo.Description, 'Registered backend table description should stay aligned with canonical backend info after re-register');
    CheckEqual(LModifiedTable.BackendInfo.Available, LReloadedTable.BackendInfo.Available, 'Registered backend table should preserve current availability after re-register');
    CheckTrue(LReloadedTable.BackendInfo.Capabilities = LModifiedTable.BackendInfo.Capabilities, 'Registered backend table should preserve current capability set after re-register');
  finally
    RegisterBackend(LBackend, LOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_RegisterBackend_SameBackendRoundTrip_Reuses_PreviouslyPublishedDispatchSnapshot;
var
  LBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LModifiedTable: TSimdDispatchTable;
  LInitialDispatch: PSimdDispatchTable;
  LModifiedDispatch: PSimdDispatchTable;
  LFinalDispatch: PSimdDispatchTable;
begin
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LBackend := GetCurrentBackend;

    CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable), 'Current backend should be registered for dispatch snapshot reuse test');

    LInitialDispatch := GetDispatchTable;
    CheckNotNil(LInitialDispatch, 'Current dispatch should be assigned before dispatch snapshot reuse test');
    CheckEqual(Ord(LBackend), Ord(LInitialDispatch^.Backend), 'Initial dispatch backend should match current backend in dispatch snapshot reuse test');

    LModifiedTable := LOriginalTable;
    LModifiedTable.CoreVectors.ReduceAddF32x4 := @SyntheticReduceAddF32x4CurrentDispatch;
    RegisterBackend(LBackend, LModifiedTable);
    try
      LModifiedDispatch := GetDispatchTable;
      CheckNotNil(LModifiedDispatch, 'Current dispatch should stay assigned after synthetic re-register');
      CheckTrue(PtrUInt(LModifiedDispatch) <> PtrUInt(LInitialDispatch), 'Same-backend synthetic re-register should publish a different dispatch snapshot while table contents differ');
      CheckTrue(Pointer(LModifiedDispatch^.CoreVectors.ReduceAddF32x4) = Pointer(@SyntheticReduceAddF32x4CurrentDispatch), 'Synthetic re-register should update the active dispatch slot');

      RegisterBackend(LBackend, LOriginalTable);
      LFinalDispatch := GetDispatchTable;
      CheckNotNil(LFinalDispatch, 'Current dispatch should stay assigned after restoring original backend table');
      CheckTrue(PtrUInt(LFinalDispatch) = PtrUInt(LInitialDispatch), 'Restoring the original backend table should reuse the original published dispatch snapshot');
      CheckTrue(Pointer(LFinalDispatch^.CoreVectors.ReduceAddF32x4) = Pointer(LOriginalTable.CoreVectors.ReduceAddF32x4), 'Restored dispatch snapshot should expose the original ReduceAddF32x4 slot');
    finally
      RegisterBackend(LBackend, LOriginalTable);
    end;
  finally
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_SetVectorAsmEnabled_RoundTrip_Reuses_PreviouslyPublishedDispatchSnapshot;
var
  LInitialDispatch: PSimdDispatchTable;
  LMiddleDispatch: PSimdDispatchTable;
  LFinalDispatch: PSimdDispatchTable;
  LInitialBackend: TSimdBackend;
  LMiddleBackend: TSimdBackend;
  LFinalBackend: TSimdBackend;
begin
  GetDispatchTable;
  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LInitialBackend := GetCurrentBackend;
    if LInitialBackend = sbScalar then
      Exit;

    LInitialDispatch := GetDispatchTable;
    CheckNotNil(LInitialDispatch, 'Initial dispatch should be assigned before vector-asm round-trip test');
    CheckEqual(Ord(LInitialBackend), Ord(LInitialDispatch^.Backend), 'Initial dispatch backend should match current backend before vector-asm round-trip test');

    SetVectorAsmEnabled(False);
    LMiddleBackend := GetCurrentBackend;
    LMiddleDispatch := GetDispatchTable;
    CheckNotNil(LMiddleDispatch, 'Dispatch should stay assigned after disabling vector asm');

    if LMiddleBackend = LInitialBackend then
      Exit;

    CheckTrue(PtrUInt(LMiddleDispatch) <> PtrUInt(LInitialDispatch), 'Disabling vector asm should publish a different dispatch snapshot for the fallback backend');

    SetVectorAsmEnabled(True);
    LFinalBackend := GetCurrentBackend;
    LFinalDispatch := GetDispatchTable;
    CheckNotNil(LFinalDispatch, 'Dispatch should stay assigned after re-enabling vector asm');

    CheckEqual(Ord(LInitialBackend), Ord(LFinalBackend), 'Re-enabling vector asm should restore the original automatic backend');
    CheckTrue(PtrUInt(LFinalDispatch) = PtrUInt(LInitialDispatch), 'Vector-asm round-trip should reuse the original published dispatch snapshot');
  finally
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_CurrentBackendInfo_PreservesCanonicalTextMetadata_After_ReRegister;
var
  LBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LModifiedTable: TSimdDispatchTable;
  LCurrentInfo: TSimdBackendInfo;
  LCanonicalInfo: TSimdBackendInfo;
  LNamePtr: PAnsiChar;
  LDescriptionPtr: PAnsiChar;
begin
  ResetToAutomaticBackend;
  LBackend := GetCurrentBackend;

  CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable), 'Current backend should be registered for current-info canonical text test');

  LModifiedTable := LOriginalTable;
  LModifiedTable.BackendInfo.Name := '';
  LModifiedTable.BackendInfo.Description := '';
  RegisterBackend(LBackend, LModifiedTable);
  try
    CheckEqual(Ord(LBackend), Ord(GetCurrentBackend), 'Re-registering the active backend should preserve the active backend id');

    LCurrentInfo := GetCurrentBackendInfo;
    LCanonicalInfo := GetBackendInfo(LBackend);
    LNamePtr := GetSimdBackendNamePtr(LBackend);
    LDescriptionPtr := GetSimdBackendDescriptionPtr(LBackend);

    CheckTrue(LCurrentInfo.Name <> '', 'GetCurrentBackendInfo should preserve non-empty name after re-register');
    CheckTrue(LCurrentInfo.Description <> '', 'GetCurrentBackendInfo should preserve non-empty description after re-register');
    CheckNotNil(Pointer(LNamePtr), 'Public ABI backend name pointer should not be nil for current backend after re-register');
    CheckNotNil(Pointer(LDescriptionPtr), 'Public ABI backend description pointer should not be nil for current backend after re-register');
    CheckEqual(Ord(LBackend), Ord(LCurrentInfo.Backend), 'GetCurrentBackendInfo.Backend should stay canonical after re-register');
    CheckEqual(LCanonicalInfo.Name, LCurrentInfo.Name, 'Current backend info name should stay aligned with canonical backend info after re-register');
    CheckEqual(LCanonicalInfo.Description, LCurrentInfo.Description, 'Current backend info description should stay aligned with canonical backend info after re-register');
    CheckEqual(LCurrentInfo.Name, string(LNamePtr), 'Current backend info name should stay aligned with public ABI text getter after re-register');
    CheckEqual(LCurrentInfo.Description, string(LDescriptionPtr), 'Current backend info description should stay aligned with public ABI text getter after re-register');
  finally
    RegisterBackend(LBackend, LOriginalTable);
  end;
end;

procedure TTestCase_DispatchAPIControlPlane.Test_CurrentBackendHelpers_StayAligned_After_ControlPlaneSwitches;
var
  LAvailableBackends: TSimdBackendArray;
  LForcedBackend: TSimdBackend;
  LIndex: Integer;
  LHasForcedBackend: Boolean;

  procedure AssertStableCurrentState(const aContext: string; const aExpectAutomatic: Boolean);
  var
    LCurrentBackend: TSimdBackend;
    LCurrentInfo: TSimdBackendInfo;
    LCanonicalInfo: TSimdBackendInfo;
    LDispatch: PSimdDispatchTable;
    LDispatchableBackends: TSimdBackendArray;
    LFoundCurrent: Boolean;
    LListIndex: Integer;
  begin
    LCurrentBackend := GetCurrentBackend;
    LCurrentInfo := GetCurrentBackendInfo;
    LCanonicalInfo := GetBackendInfo(LCurrentBackend);
    LDispatch := GetDispatchTable;
    LDispatchableBackends := GetAvailableBackendList;

    CheckNotNil(LDispatch, aContext + ': dispatch table should not be nil');
    CheckEqual(Ord(LCurrentBackend), Ord(LCurrentInfo.Backend), aContext + ': current backend info backend should match current backend');
    CheckEqual(Ord(LCurrentBackend), Ord(LDispatch^.Backend), aContext + ': dispatch table backend should match current backend');
    CheckEqual(Ord(LCurrentBackend), Ord(LDispatch^.BackendInfo.Backend), aContext + ': dispatch table backend info backend should match current backend');
    CheckEqual(LCanonicalInfo.Name, LCurrentInfo.Name, aContext + ': current backend info name should stay canonical');
    CheckEqual(LCanonicalInfo.Description, LCurrentInfo.Description, aContext + ': current backend info description should stay canonical');
    CheckEqual(LDispatch^.BackendInfo.Available, LCurrentInfo.Available, aContext + ': current backend info availability should match current dispatch snapshot');
    CheckTrue(LCurrentInfo.Capabilities = LDispatch^.BackendInfo.Capabilities, aContext + ': current backend info capabilities should match current dispatch snapshot');

    LFoundCurrent := False;
    for LListIndex := 0 to High(LDispatchableBackends) do
      if LDispatchableBackends[LListIndex] = LCurrentBackend then
      begin
        LFoundCurrent := True;
        Break;
      end;
    CheckTrue(LFoundCurrent, aContext + ': dispatchable list should contain current backend in stable state');

    if aExpectAutomatic then
      CheckEqual(Ord(GetBestDispatchableBackend), Ord(LCurrentBackend), aContext + ': best dispatchable backend should match current backend in automatic stable state');
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

procedure TTestCase_DispatchAPIControlPlane.Test_DispatchChangedHooks_MultiSubscriber_Dedup_And_Remove;
var
  LBeforeA: Integer;
  LBeforeB: Integer;
begin
  GDispatchHookCountA := 0;
  GDispatchHookCountB := 0;

  AddDispatchChangedHook(@DispatchHookProbeA);
  AddDispatchChangedHook(@DispatchHookProbeA);
  AddDispatchChangedHook(@DispatchHookProbeB);
  try
    CheckEqual(1, GDispatchHookCountA, 'Duplicate hook should be ignored for hook A');
    CheckEqual(1, GDispatchHookCountB, 'Second subscriber should be invoked immediately once');

    LBeforeA := GDispatchHookCountA;
    LBeforeB := GDispatchHookCountB;

    SetActiveBackend(sbScalar);

    CheckEqual(LBeforeA + 1, GDispatchHookCountA, 'Hook A should fire exactly once per dispatch change');
    CheckEqual(LBeforeB + 1, GDispatchHookCountB, 'Hook B should fire exactly once per dispatch change');

    RemoveDispatchChangedHook(@DispatchHookProbeA);
    LBeforeA := GDispatchHookCountA;
    LBeforeB := GDispatchHookCountB;

    ResetToAutomaticBackend;

    CheckEqual(LBeforeA, GDispatchHookCountA, 'Removed hook should not receive further notifications');
    CheckEqual(LBeforeB + 1, GDispatchHookCountB, 'Remaining hook should keep receiving notifications');
  finally
    RemoveDispatchChangedHook(@DispatchHookProbeA);
    RemoveDispatchChangedHook(@DispatchHookProbeB);
  end;
end;

procedure TTestCase_RISCVFallbackDispatchContract.Test_ScalarAndCurrentDispatch_Keep_RepresentativeWideSlots_Assigned;
var
  LCurrentDispatch: PSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
begin
  {$IFNDEF CPURISCV64}
  {$IFNDEF CPURISCV32}
  Exit;
  {$ENDIF}
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
  Exit;
  {$ENDIF}

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar backend should remain registered in riscv fallback contract test');
  CheckTrue(Assigned(LScalarTable.CoreVectors.AndNotI64x2), 'Registered scalar AndNotI64x2 should be assigned');
  CheckTrue(Assigned(LScalarTable.CoreVectors.AddU64x2), 'Registered scalar AddU64x2 should be assigned');
  CheckTrue(Assigned(LScalarTable.CoreVectors.AddU32x8), 'Registered scalar AddU32x8 should be assigned');
  CheckTrue(Assigned(LScalarTable.CoreVectors.LoadF32x16), 'Registered scalar LoadF32x16 should be assigned');
  CheckTrue(Assigned(LScalarTable.CoreVectors.AddU64x8), 'Registered scalar AddU64x8 should be assigned');

  LCurrentDispatch := GetDispatchTable;
  CheckNotNil(LCurrentDispatch, 'Current dispatch should be available in riscv fallback contract test');
  CheckEqual(Ord(sbScalar), Ord(LCurrentDispatch^.Backend), 'Fallback current backend should stay Scalar in riscv fallback contract test');
  CheckTrue(Assigned(LCurrentDispatch^.CoreVectors.AndNotI64x2), 'Current dispatch AndNotI64x2 should be assigned');
  CheckTrue(Assigned(LCurrentDispatch^.CoreVectors.AddU64x2), 'Current dispatch AddU64x2 should be assigned');
  CheckTrue(Assigned(LCurrentDispatch^.CoreVectors.AddU32x8), 'Current dispatch AddU32x8 should be assigned');
  CheckTrue(Assigned(LCurrentDispatch^.CoreVectors.LoadF32x16), 'Current dispatch LoadF32x16 should be assigned');
  CheckTrue(Assigned(LCurrentDispatch^.CoreVectors.AddU64x8), 'Current dispatch AddU64x8 should be assigned');
end;

procedure TTestCase_RISCVFallbackDispatchContract.Test_RollbackRestoreSuccess_Keep_RepresentativeWideSlots_Assigned;
var
  LCase: TTestCase_DispatchAPIControlPlane;
  LCurrentDispatch: PSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LInnerSetupDone: Boolean;
begin
  {$IFNDEF CPURISCV64}
  {$IFNDEF CPURISCV32}
  Exit;
  {$ENDIF}
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
  Exit;
  {$ENDIF}

  ResetToAutomaticBackend;
  LCurrentDispatch := GetDispatchTable;
  CheckNotNil(LCurrentDispatch, 'Current dispatch should be available before rollback-restore success probe');
  CheckEqual(Ord(sbScalar), Ord(LCurrentDispatch^.Backend), 'Rollback-restore success probe expects current backend to start Scalar');
  CheckTrue(Assigned(LCurrentDispatch^.CoreVectors.AndNotI64x2), 'Current dispatch AndNotI64x2 should start assigned before rollback-restore success probe');

  LInnerSetupDone := False;
  LCase := TTestCase_DispatchAPIControlPlane.Create;
  try
    LCase.BeforeEach;
    LInnerSetupDone := True;
    LCase.Test_TrySetActiveBackend_RollbackRestore_Success_Preserves_ForcedSelection;
  finally
    if LInnerSetupDone then
      LCase.AfterEach;
    LCase.Free;
  end;

  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar backend should remain registered after rollback-restore success probe');
  CheckTrue(Assigned(LScalarTable.CoreVectors.AndNotI64x2), 'Registered scalar AndNotI64x2 should remain assigned after rollback-restore success probe');
  CheckTrue(Assigned(LScalarTable.CoreVectors.AddU64x2), 'Registered scalar AddU64x2 should remain assigned after rollback-restore success probe');
  CheckTrue(Assigned(LScalarTable.CoreVectors.AddU32x8), 'Registered scalar AddU32x8 should remain assigned after rollback-restore success probe');
  CheckTrue(Assigned(LScalarTable.CoreVectors.LoadF32x16), 'Registered scalar LoadF32x16 should remain assigned after rollback-restore success probe');
  CheckTrue(Assigned(LScalarTable.CoreVectors.AddU64x8), 'Registered scalar AddU64x8 should remain assigned after rollback-restore success probe');

  LCurrentDispatch := GetDispatchTable;
  CheckNotNil(LCurrentDispatch, 'Current dispatch should be available after rollback-restore success probe');
  CheckEqual(Ord(sbScalar), Ord(LCurrentDispatch^.Backend), 'Current dispatch backend should stay Scalar after rollback-restore success probe');
  CheckTrue(Assigned(LCurrentDispatch^.CoreVectors.AndNotI64x2), 'Current dispatch AndNotI64x2 should remain assigned after rollback-restore success probe');
  CheckTrue(Assigned(LCurrentDispatch^.CoreVectors.AddU64x2), 'Current dispatch AddU64x2 should remain assigned after rollback-restore success probe');
  CheckTrue(Assigned(LCurrentDispatch^.CoreVectors.AddU32x8), 'Current dispatch AddU32x8 should remain assigned after rollback-restore success probe');
  CheckTrue(Assigned(LCurrentDispatch^.CoreVectors.LoadF32x16), 'Current dispatch LoadF32x16 should remain assigned after rollback-restore success probe');
  CheckTrue(Assigned(LCurrentDispatch^.CoreVectors.AddU64x8), 'Current dispatch AddU64x8 should remain assigned after rollback-restore success probe');
end;

end.
