procedure TCompilationSession.PropagateSemanticLibraryRequestsToBackendPlan;
var
  Index: LongInt;
  LibraryRequest: TSemanticLibraryRequest;
begin
  if (FBackendPlan = nil) or (FSemanticModel = nil) or
    (FSemanticStatus <> 'ready') then
    Exit;

  for Index := 0 to FSemanticModel.LibraryRequestCount - 1 do
  begin
    LibraryRequest := FSemanticModel.LibraryRequestAt(Index);
    FBackendPlan.AddLogicalLibraryRequest(
      LibraryRequest.LogicalId,
      LibraryRequest.LinkageKind,
      LibraryRequest.Strength
    );
  end;
end;

procedure TCompilationSession.PlanToolchain;
var
  PlanningProfileId: string;
  Planner: TToolchainPlanner;
begin
  ResetToolchainState;
  if (FBackendPlan = nil) or (FBackendStatus <> 'ready') then
  begin
    FToolchainStatus := 'failure';
    Exit;
  end;

  Planner := TToolchainPlanner.Create(
    FBackendPlan,
    FTargetFacts,
    FOptions.BuildContext.ResolvedSourcePath,
    ArtifactRootPath,
    FOptions.WorkspaceModel.ProjectUnitRoots,
    FOptions.ExplicitUnitRoots,
    CollectAdditionalAssemblyBaseNames
  );
  try
    Planner.PlanFromBackend;
    FToolchainPlan := Planner.DetachPlan;
  finally
    Planner.Free;
  end;

  if FToolchainPlan = nil then
  begin
    FToolchainStatus := 'deferred';
    Exit;
  end;

  FToolchainStatus := FToolchainPlan.Status;
  if (FToolchainStatus <> 'failure') or (FToolchainPlan.FailureCode = '') then
    Exit;

  PlanningProfileId := FToolchainPlan.PrimaryToolProfileId;
  if PlanningProfileId = '' then
    PlanningProfileId := FToolchainPlan.LlvmExecutableSetId;
  FDiagnosticsSink.EmitToolchainError(
    FToolchainPlan.FailureCode,
    ToolchainBindingId,
    PlanningProfileId,
    FToolchainPlan.PrimaryToolStepId,
    FToolchainPlan.PrimaryToolLogicalExecutable,
    FToolchainPlan.PrimaryToolSysrootRef,
    '',
    BackendPrimaryArtifactKind,
    BackendPrimaryArtifactPath,
    False,
    0,
    FToolchainPlan.FailureMessage
  );
end;

procedure TCompilationSession.RecordToolSelection(
  const AToolStep: TToolInvocationStep;
  const AResolvedPath: string
);
begin
  AppendToolStatusEvent(
    'toolchain.tool-selected',
    AToolStep.StepId,
    AToolStep.ToolRole,
    AToolStep.ProfileId,
    AToolStep.LogicalExecutable,
    AToolStep.SysrootRef,
    AResolvedPath,
    '',
    '',
    'tool selected',
    False,
    0
  );
end;

procedure TCompilationSession.RecordToolStepStarted(
  const AToolStep: TToolInvocationStep;
  const AResolvedPath: string
);
begin
  AppendToolStatusEvent(
    'toolchain.step-started',
    AToolStep.StepId,
    AToolStep.ToolRole,
    AToolStep.ProfileId,
    AToolStep.LogicalExecutable,
    AToolStep.SysrootRef,
    AResolvedPath,
    '',
    '',
    'step started',
    False,
    0
  );
end;

procedure TCompilationSession.RecordToolStepFinished(
  const AToolStep: TToolInvocationStep;
  const AResolvedPath: string;
  const AStatus: string;
  const AHasExitCode: Boolean;
  const AExitCode: LongInt
);
begin
  AppendToolStatusEvent(
    'toolchain.step-finished',
    AToolStep.StepId,
    AToolStep.ToolRole,
    AToolStep.ProfileId,
    AToolStep.LogicalExecutable,
    AToolStep.SysrootRef,
    AResolvedPath,
    AStatus,
    '',
    'step finished',
    AHasExitCode,
    AExitCode
  );
end;

procedure TCompilationSession.RecordToolPlanFinished(
  const AToolStep: TToolInvocationStep;
  const AResolvedPath: string;
  const AResultValue: string;
  const AHasExitCode: Boolean;
  const AExitCode: LongInt
);
begin
  AppendToolStatusEvent(
    'toolchain.plan-finished',
    AToolStep.StepId,
    AToolStep.ToolRole,
    AToolStep.ProfileId,
    AToolStep.LogicalExecutable,
    AToolStep.SysrootRef,
    AResolvedPath,
    '',
    AResultValue,
    'plan finished',
    AHasExitCode,
    AExitCode
  );
end;

procedure TCompilationSession.RecordToolchainSuccess(
  const ARunResult: TToolchainRunResult
);
var
  LastStep: TToolchainExecutedStep;
  LastToolStep: TToolInvocationStep;
  StepIndex: LongInt;
  ToolStep: TToolInvocationStep;
begin
  ClearToolStatusEvents;
  ClearBuildTrace;
  if ARunResult = nil then
    Exit;

  for StepIndex := 0 to ARunResult.StepCount - 1 do
  begin
    ToolStep := FindToolInvocationStep(ARunResult.StepAt(StepIndex).StepId);
    RecordToolSelection(ToolStep, ARunResult.StepAt(StepIndex).ResolvedPath);
    RecordToolStepStarted(ToolStep, ARunResult.StepAt(StepIndex).ResolvedPath);
    RecordToolStepFinished(
      ToolStep,
      ARunResult.StepAt(StepIndex).ResolvedPath,
      ARunResult.StepAt(StepIndex).Status,
      ARunResult.StepAt(StepIndex).HasExitCode,
      ARunResult.StepAt(StepIndex).ExitCode
    );
  end;

  if ARunResult.StepCount = 0 then
    Exit;

  LastStep := ARunResult.StepAt(ARunResult.StepCount - 1);
  LastToolStep := FindToolInvocationStep(LastStep.StepId);
  RecordToolPlanFinished(
    LastToolStep,
    LastStep.ResolvedPath,
    'success',
    LastStep.HasExitCode,
    LastStep.ExitCode
  );
  FBuildTraceRef := BuildTraceDocumentRef;
  FBuildTraceJson := BuildToolchainBuildTraceJson(
    ARunResult,
    'success',
    '',
    ''
  );
end;

procedure TCompilationSession.RecordToolchainFailure(
  const ARunResult: TToolchainRunResult;
  const AToolStep: TToolInvocationStep;
  const AResolvedPath: string;
  const AMessageText: string;
  const AHasExitCode: Boolean;
  const AExitCode: LongInt
);
var
  DiagnosticIdValue: string;
  LastStep: TToolchainExecutedStep;
  LastToolStep: TToolInvocationStep;
  StepIndex: LongInt;
  ToolStep: TToolInvocationStep;
begin
  FDiagnosticsSink.EmitToolchainError(
    AToolStep.FailureMapping,
    ToolchainBindingId,
    AToolStep.ProfileId,
    AToolStep.StepId,
    AToolStep.LogicalExecutable,
    AToolStep.SysrootRef,
    AResolvedPath,
    BackendPrimaryArtifactKind,
    BackendPrimaryArtifactPath,
    AHasExitCode,
    AExitCode,
    AMessageText
  );

  DiagnosticIdValue := FDiagnosticsSink.LastDiagnosticId;
  ClearToolStatusEvents;
  ClearBuildTrace;
  if ARunResult = nil then
    Exit;

  for StepIndex := 0 to ARunResult.StepCount - 1 do
  begin
    ToolStep := FindToolInvocationStep(ARunResult.StepAt(StepIndex).StepId);
    RecordToolSelection(ToolStep, ARunResult.StepAt(StepIndex).ResolvedPath);
    RecordToolStepStarted(ToolStep, ARunResult.StepAt(StepIndex).ResolvedPath);
    RecordToolStepFinished(
      ToolStep,
      ARunResult.StepAt(StepIndex).ResolvedPath,
      ARunResult.StepAt(StepIndex).Status,
      ARunResult.StepAt(StepIndex).HasExitCode,
      ARunResult.StepAt(StepIndex).ExitCode
    );
  end;

  if ARunResult.StepCount = 0 then
    Exit;

  LastStep := ARunResult.StepAt(ARunResult.StepCount - 1);
  LastToolStep := FindToolInvocationStep(LastStep.StepId);
  RecordToolPlanFinished(
    LastToolStep,
    LastStep.ResolvedPath,
    'failed',
    AHasExitCode,
    AExitCode
  );
  FBuildTraceRef := BuildTraceDocumentRef;
  FBuildTraceJson := BuildToolchainBuildTraceJson(
    ARunResult,
    'failed',
    AToolStep.StepId,
    DiagnosticIdValue
  );
end;

function TCompilationSession.ExecuteToolchain(
  const AExecutableSearchPath: string
): TToolchainRunResult;
var
  FailedStep: TToolchainExecutedStep;
  FailedToolStep: TToolInvocationStep;
  FailureMessageText: string;
  PrimaryStep: TToolchainExecutedStep;
  PrimaryToolStep: TToolInvocationStep;
  StepIndex: LongInt;
begin
  Result := ExecuteToolchainPlan(FToolchainPlan, AExecutableSearchPath);

  ClearToolRunState;
  if Result = nil then
    Exit;

  if Result.StepCount > 0 then
  begin
    PrimaryStep := Result.StepAt(0);
    PrimaryToolStep := FindToolInvocationStep(PrimaryStep.StepId);
    RecordToolSelection(PrimaryToolStep, PrimaryStep.ResolvedPath);
    RecordToolStepStarted(PrimaryToolStep, PrimaryStep.ResolvedPath);
  end
  else
  begin
    ClearToolInvocationStepView(PrimaryToolStep);
    PrimaryStep.StepId := '';
    PrimaryStep.LogicalExecutable := '';
    PrimaryStep.ResolvedPath := '';
    PrimaryStep.Status := '';
    PrimaryStep.ExitCode := 0;
    PrimaryStep.HasExitCode := False;
  end;

  if Result.Status = 'success' then
    RecordToolchainSuccess(Result)
  else
  begin
    FailedStep := PrimaryStep;
    FailedToolStep := PrimaryToolStep;
    for StepIndex := 0 to Result.StepCount - 1 do
      if Result.StepAt(StepIndex).Status = 'failed' then
      begin
        FailedStep := Result.StepAt(StepIndex);
        FailedToolStep := FindToolInvocationStep(FailedStep.StepId);
        Break;
      end;

    if FailedStep.HasExitCode then
      FailureMessageText := 'compiler exit code ' + IntToStr(FailedStep.ExitCode)
    else if Result.FailureMessage <> '' then
      FailureMessageText := Result.FailureMessage
    else
      FailureMessageText := 'toolchain execution failed';

    RecordToolchainFailure(
      Result,
      FailedToolStep,
      FailedStep.ResolvedPath,
      FailureMessageText,
      FailedStep.HasExitCode,
      FailedStep.ExitCode
    );
  end;

  FToolRunStatus := Result.Status;
  FToolRunStepCount := Result.StepCount;
  FPrimaryToolRunStatus := PrimaryStep.Status;
end;

