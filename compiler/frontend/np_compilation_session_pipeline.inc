procedure TCompilationSession.ResetSyntaxState;
begin
  ResetResolutionState;
  FreeAndNil(FAstFacade);
  FreeAndNil(FGreenTree);
  FreeAndNil(FLexerResult);
end;

procedure TCompilationSession.ResetResolutionState;
begin
  ResetSemanticState;
  FreeAndNil(FUnitGraph);
  FreeAndNil(FSearchPathSet);
  FResolutionStatus := 'deferred';
  FSearchIndexStatus := 'deferred';
  FIndexedSearchRootCount := 0;
  FSearchIndexScanCount := 0;
end;

procedure TCompilationSession.ResetSemanticState;
begin
  ResetIrState;
  FreeAndNil(FSemanticModel);
  FSemanticStatus := 'deferred';
end;

procedure TCompilationSession.ResetIrState;
begin
  ResetBackendState;
  FreeAndNil(FMirModule);
  FMirStatus := 'deferred';
end;

procedure TCompilationSession.ResetBackendState;
begin
  ResetToolchainState;
  FreeAndNil(FBackendPlan);
  FBackendStatus := 'deferred';
end;

procedure TCompilationSession.ResetToolchainState;
begin
  FreeAndNil(FToolchainPlan);
  FToolchainStatus := 'deferred';
  ClearToolRunState;
  ClearToolStatusEvents;
  ClearBuildTrace;
end;

procedure TCompilationSession.ClearToolRunState;
begin
  FToolRunStatus := '';
  FToolRunStepCount := 0;
  FPrimaryToolRunStatus := '';
end;

procedure TCompilationSession.ClearBuildTrace;
begin
  FBuildTraceRef := '';
  FBuildTraceJson := '';
end;

procedure TCompilationSession.ClearToolStatusEvents;
begin
  SetLength(FToolStatusEvents, 0);
end;

procedure TCompilationSession.AppendToolStatusEvent(
  const AEventKind: string;
  const AStepId: string;
  const AToolRole: string;
  const AProfileId: string;
  const ALogicalExecutable: string;
  const ASysrootRef: string;
  const AResolvedPath: string;
  const AStatus: string;
  const AResultValue: string;
  const ASummary: string;
  const AHasExitCode: Boolean;
  const AExitCode: LongInt
);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FToolStatusEvents);
  SetLength(FToolStatusEvents, NextIndex + 1);
  FToolStatusEvents[NextIndex].EventKind := AEventKind;
  FToolStatusEvents[NextIndex].StepId := AStepId;
  FToolStatusEvents[NextIndex].ToolRole := AToolRole;
  FToolStatusEvents[NextIndex].ProfileId := AProfileId;
  FToolStatusEvents[NextIndex].LogicalExecutable := ALogicalExecutable;
  FToolStatusEvents[NextIndex].SysrootRef := ASysrootRef;
  FToolStatusEvents[NextIndex].ResolvedPath := AResolvedPath;
  FToolStatusEvents[NextIndex].Status := AStatus;
  FToolStatusEvents[NextIndex].ResultValue := AResultValue;
  FToolStatusEvents[NextIndex].Summary := ASummary;
  FToolStatusEvents[NextIndex].HasExitCode := AHasExitCode;
  FToolStatusEvents[NextIndex].ExitCode := AExitCode;
end;

function TCompilationSession.BuildTracePlanId: string;
begin
  Result := 'plan-' + FSessionId + '-primary-tool';
end;

function TCompilationSession.BuildTraceDocumentRef: string;
begin
  Result := 'trace-' + FSessionId + '-toolchain-plan';
end;

function TCompilationSession.PrimaryToolResolvedPath: string;
var
  Index: LongInt;
begin
  for Index := High(FToolStatusEvents) downto 0 do
    if (FToolStatusEvents[Index].ResolvedPath <> '') and
      nextpas.core.text.SameText(FToolStatusEvents[Index].StepId, PrimaryToolStepId) then
      Exit(FToolStatusEvents[Index].ResolvedPath);

  if FToolchainPlan <> nil then
    Exit(FToolchainPlan.PrimaryToolExecutableRef);

  Result := '';
end;

function TCompilationSession.BuildStepOutputsJson(
  const AToolStep: TToolInvocationStep
): string;
begin
  Result := BuildToolArtifactArrayJson(AToolStep.Outputs);
end;

function TCompilationSession.CollectAdditionalAssemblyBaseNames: TStringArray;
var
  CandidateBaseName: string;
  Index: LongInt;
  ResolvedSourcePath: string;
  ResolvedUnit: TResolvedUnit;

  procedure AddUniqueBaseName(const ABaseName: string);
  var
    ExistingIndex: LongInt;
    NextIndex: SizeInt;
  begin
    if Trim(ABaseName) = '' then
      Exit;
    for ExistingIndex := 0 to Length(Result) - 1 do
      if nextpas.core.text.SameText(Result[ExistingIndex], ABaseName) then
        Exit;
    NextIndex := Length(Result);
    SetLength(Result, NextIndex + 1);
    Result[NextIndex] := ABaseName;
  end;
begin
  SetLength(Result, 0);
  if FUnitGraph = nil then
    Exit;
  if nextpas.core.text.SameText(AstRootKindName, 'unit') then
    Exit;

  ResolvedSourcePath := ExpandFileName(FOptions.BuildContext.ResolvedSourcePath);
  for Index := 0 to FUnitGraph.ResolvedUnitCount - 1 do
  begin
    ResolvedUnit := FUnitGraph.ResolvedUnitAt(Index);
    if Trim(ResolvedUnit.SourcePath) = '' then
      Continue;
    if nextpas.core.text.SameText(ResolvedUnit.OriginClass, 'implicit-runtime') then
      Continue;
    if nextpas.core.text.SameText(ExpandFileName(ResolvedUnit.SourcePath), ResolvedSourcePath) then
      Continue;
    CandidateBaseName := ChangeFileExt(
      ExtractFileName(ResolvedUnit.SourcePath),
      ''
    );
    AddUniqueBaseName(CandidateBaseName);
  end;
end;

function TCompilationSession.FindToolInvocationStep(
  const AStepId: string
): TToolInvocationStep;
var
  Index: LongInt;
begin
  Result.StepId := '';
  Result.ToolRole := '';
  Result.ProfileId := '';
  Result.SysrootRef := '';
  Result.LogicalExecutable := '';
  Result.ExecutableRef := '';
  Result.WorkingDirectory := '';
  Result.FailureMapping := '';
  SetLength(Result.Argv, 0);
  SetLength(Result.EnvDelta, 0);
  SetLength(Result.Inputs, 0);
  SetLength(Result.Outputs, 0);
  SetLength(Result.Sidecars, 0);

  if FToolchainPlan = nil then
    Exit;

  for Index := 0 to FToolchainPlan.ToolInvocationCount - 1 do
    if nextpas.core.text.SameText(FToolchainPlan.StepAt(Index).StepId, AStepId) then
      Exit(FToolchainPlan.StepAt(Index));
end;

function TCompilationSession.BuildDiagnosticRefsJson(
  const ADiagnosticId: string
): string;
begin
  if ADiagnosticId = '' then
    Exit('[]');

  Result := '[' + JsonString(ADiagnosticId) + ']';
end;

function TCompilationSession.BuildToolchainBuildTraceJson(
  const ARunResult: TToolchainRunResult;
  const AResultValue: string;
  const AFailedStepId: string;
  const ADiagnosticId: string
): string;
var
  ExecutedStep: TToolchainExecutedStep;
  PrimaryToolStep: TToolInvocationStep;
  StepFields: string;
  StepJson: string;
  ToolStep: TToolInvocationStep;
  TraceFields: string;
  StepIndex: LongInt;
begin
  if (ARunResult = nil) or (ARunResult.StepCount = 0) then
    Exit('');

  PrimaryToolStep := FindToolInvocationStep(ARunResult.StepAt(0).StepId);
  StepJson := '';
  for StepIndex := 0 to ARunResult.StepCount - 1 do
  begin
    ExecutedStep := ARunResult.StepAt(StepIndex);
    ToolStep := FindToolInvocationStep(ExecutedStep.StepId);
    if StepJson <> '' then
      StepJson := StepJson + ',';

    StepFields := '';
    AppendJsonField(StepFields, 'stepId', JsonString(ExecutedStep.StepId));
    AppendJsonField(StepFields, 'profileId', JsonString(ToolStep.ProfileId));
    AppendJsonField(StepFields, 'toolRole', JsonString(ToolStep.ToolRole));
    AppendJsonField(StepFields, 'status', JsonString(ExecutedStep.Status));
    AppendJsonField(
      StepFields,
      'logicalExecutable',
      JsonString(ToolStep.LogicalExecutable)
    );
    AppendJsonField(StepFields, 'sysrootRef', JsonString(ToolStep.SysrootRef));
    if ExecutedStep.ResolvedPath <> '' then
      AppendJsonField(
        StepFields,
        'resolvedPath',
        JsonString(ExecutedStep.ResolvedPath)
      );
    AppendJsonField(
      StepFields,
      'primaryOutputs',
      BuildStepOutputsJson(ToolStep)
    );
    AppendJsonField(
      StepFields,
      'sidecars',
      BuildExecutedSidecarArrayJson(ExecutedStep.Sidecars)
    );
    if nextpas.core.text.SameText(ExecutedStep.StepId, AFailedStepId) then
      AppendJsonField(
        StepFields,
        'diagnosticRefs',
        BuildDiagnosticRefsJson(ADiagnosticId)
      )
    else
      AppendJsonField(StepFields, 'diagnosticRefs', '[]');
    if ExecutedStep.HasExitCode then
      AppendJsonField(StepFields, 'exitCode', IntToStr(ExecutedStep.ExitCode));
    StepJson := StepJson + '{' + StepFields + '}';
  end;

  TraceFields := '';
  AppendJsonField(
    TraceFields,
    'traceKind',
    JsonString('toolchain-build-trace')
  );
  AppendJsonField(TraceFields, 'sessionId', JsonString(FSessionId));
  AppendJsonField(TraceFields, 'planId', JsonString(BuildTracePlanId));
  AppendJsonField(TraceFields, 'bindingId', JsonString(ToolchainBindingId));
  AppendJsonField(TraceFields, 'hostId', JsonString(HostId));
  AppendJsonField(TraceFields, 'targetId', JsonString(FTargetFacts.TargetId));
  AppendJsonField(
    TraceFields,
    'profileId',
    JsonString(PrimaryToolStep.ProfileId)
  );
  AppendJsonField(
    TraceFields,
    'toolRole',
    JsonString(PrimaryToolStep.ToolRole)
  );
  AppendJsonField(
    TraceFields,
    'sysrootRef',
    JsonString(PrimaryToolStep.SysrootRef)
  );
  AppendJsonField(TraceFields, 'result', JsonString(AResultValue));
  AppendJsonField(TraceFields, 'steps', '[' + StepJson + ']');
  Result := '{' + TraceFields + '}';
end;

function TCompilationSession.GetScheduler: TParallelScheduler;
begin
  if FScheduler = nil then
    FScheduler := TParallelScheduler.Create;
  Result := FScheduler;
end;

function TCompilationSession.PrepareIncrementalBuild: Boolean;
var
  RootPath: string;
  Changed: TStringArray;
  I: LongInt;
begin
  Result := True;
  RootPath := FSourceDatabase.RootSourceCanonicalPath;

  { First build: no snapshots yet }
  if FFileDetector.SnapshotCount = 0 then
    Exit;

  { Check if any tracked file changed }
  if not FFileDetector.AnyChanged then
  begin
    { Nothing changed — all queries still valid }
    Exit;
  end;

  { Something changed — invalidate affected queries }
  Changed := FFileDetector.ChangedFiles;
  for I := 0 to Length(Changed) - 1 do
  begin
    FQueryDB.InvalidatePrefix('parse:' + Changed[I]);
    FQueryDB.InvalidatePrefix('semantic:' + Changed[I]);
  end;

  { Reset state for recompilation }
  Result := True;
end;

procedure TCompilationSession.FinalizeIncrementalBuild;
var
  RootPath: string;
begin
  RootPath := FSourceDatabase.RootSourceCanonicalPath;
  FFileDetector.TakeSnapshot(RootPath, []);
end;

procedure TCompilationSession.AnalyzeSyntax;
var
  RawLexer: TLexerResult;
  PP: TPreprocessor;
  Defines: TDefineTable;
  IncResolver: TFileIncludeResolver;
  SourceDir: string;
begin
  ResetSyntaxState;
  RawLexer := TLexerResult.Create(FSourceDatabase.RootSourceText,
    FDiagnosticsSink, FRootFileId);
  Defines := TDefineTable.Create;
  Defines.SeedFPCDefines;
  SourceDir := ExtractFileDir(FSourceDatabase.RootSourceCanonicalPath);
  IncResolver := TFileIncludeResolver.Create(SourceDir);
  IncResolver.AddSearchPath(SourceDir);
  PP := TPreprocessor.Create(Defines, True, IncResolver);
  PP.Process(RawLexer);
  FLexerResult := PP.ToLexerResult;
  PP.Free;
  RawLexer.Free;
  FGreenTree := ParseGreenTree(FLexerResult, FDiagnosticsSink, FRootFileId);
  FAstFacade := TAstFacade.Create(FGreenTree);

  if FDiagnosticsSink.HasErrors or (FGreenTree = nil) or not FGreenTree.IsValid then
    FSyntaxStatus := 'failure'
  else
    FSyntaxStatus := 'ready';
end;

procedure TCompilationSession.ResolveUnits;
var
  Resolver: TUnitResolver;
begin
  ResetResolutionState;
  if (FAstFacade = nil) or not FAstFacade.IsValid then
  begin
    FResolutionStatus := 'failure';
    Exit;
  end;

  Resolver := TUnitResolver.Create(
    FSourceDatabase,
    FTargetFacts,
    FDiagnosticsSink,
    FRootFileId,
    FOptions.WorkspaceModel.ProjectUnitRootInfos,
    FOptions.ExplicitUnitRoots
  );
  try
    Resolver.ResolveRoot(FAstFacade);
    FSearchIndexStatus := Resolver.SearchIndexStatus;
    FIndexedSearchRootCount := Resolver.IndexedRootCount;
    FSearchIndexScanCount := Resolver.SearchIndexScanCount;
    FSearchPathSet := Resolver.DetachSearchPaths;
    FUnitGraph := Resolver.DetachUnitGraph;
    FResolutionStatus := Resolver.ResolutionStatus;
  finally
    Resolver.Free;
  end;

  if (FUnitGraph <> nil) and (FUnitGraph.ResolvedUnitCount > FUnitStateCount) then
    FUnitStateCount := FUnitGraph.ResolvedUnitCount;
end;

procedure TCompilationSession.AnalyzeSemantics;
var
  Analyzer: TSemanticAnalyzer;
  CacheKey: string;
  CachedModel: TObject;
begin
  { Query cache: if we already analyzed this file, skip }
  CacheKey := 'semantic:' + FSourceDatabase.RootSourceCanonicalPath;
  CachedModel := FQueryDB.Get(CacheKey, nil);
  if (CachedModel <> nil) and (CachedModel is TSemanticModel) then
  begin
    FSemanticModel := TSemanticModel(CachedModel);
    FSemanticStatus := FSemanticModel.Status;
    { Do NOT call ResetSemanticState — it would free the cached model }
    Exit;
  end;

  ResetSemanticState;
  if (FAstFacade = nil) or (FUnitGraph = nil) or (FResolutionStatus <> 'ready') then
  begin
    FSemanticStatus := 'failure';
    Exit;
  end;

  Analyzer := TSemanticAnalyzer.Create(
    FAstFacade,
    FUnitGraph,
    FDiagnosticsSink,
    FRootFileId,
    FOptions.NoFold
  );
  try
    Analyzer.Analyze;
    FSemanticModel := Analyzer.DetachModel;
    if FSemanticModel = nil then
      FSemanticStatus := 'deferred'
    else
    begin
      FSemanticStatus := FSemanticModel.Status;
      { Cache for incremental compilation — query DB owns the reference }
      if FSemanticStatus = 'ready' then
        FQueryDB.Store(CacheKey, FSemanticModel);
    end;
  finally
    Analyzer.Free;
  end;
end;

procedure TCompilationSession.LowerToMir;
var
  HirBuilder: THIRBuilder;
  HirPrinter: THIRPrinter;
  HirPath: string;
  Lowering: THirToMirLowering;
  LlvmTranslator: TMirToLlvmTranslator;
  LlvmOutput: string;
begin
  ResetIrState;
  if (FSemanticModel = nil) or (FSemanticStatus <> 'ready') then
  begin
    FMirStatus := 'failure';
    Exit;
  end;

  FMirStatus := 'ready';

  // MIR lowering is enabled via NEXTPAS_MIR=1 env var (opt-in during development)
  if GetEnvironmentVariable('NEXTPAS_MIR') = '1' then
  begin
    HirBuilder := THIRBuilder.Create(FSemanticModel, FSourceDatabase, FRootFileId);
    try
      HirBuilder.Build;

      Lowering := THirToMirLowering.Create(HirBuilder.Module);
      try
        Lowering.Lower;
        FMirModule := Lowering.DetachModule;
      finally
        Lowering.Free;
      end;

      if GetEnvironmentVariable('NEXTPAS_MIR_DUMP') = '1' then
      begin
        LlvmTranslator := TMirToLlvmTranslator.Create(FMirModule);
        try
          LlvmOutput := LlvmTranslator.Translate;
        finally
          LlvmTranslator.Free;
        end;
      end;
    finally
      HirBuilder.Free;
    end;
  end
  else if GetEnvironmentVariable('NEXTPAS_HIR_DUMP') = '1' then
  begin
    HirBuilder := THIRBuilder.Create(FSemanticModel, FSourceDatabase, FRootFileId);
    try
      HirBuilder.Build;
      HirPath := ChangeFileExt(FOptions.BuildContext.ResolvedSourcePath, '.hir');
      HirPrinter := THIRPrinter.Create(HirBuilder.Module);
      try
        HirPrinter.Print;
        HirPrinter.SaveToFile(HirPath);
      finally
        HirPrinter.Free;
      end;
    finally
      HirBuilder.Free;
    end;
  end;
end;

procedure TCompilationSession.PlanBackend;
var
  Planner: TBackendPlanner;
begin
  ResetBackendState;
  if (FSemanticModel = nil) or (FMirStatus <> 'ready') then
  begin
    FBackendStatus := 'failure';
    Exit;
  end;

  Planner := TBackendPlanner.Create(
    FSemanticModel,
    FTargetFacts,
    FOptions.BuildContext.RequestedSourcePath,
    ArtifactRootPath,
    OutputDirPath,
    AstRootKindName,
    FOptions.NoFold,
    FOptions.OptLevel
  );
  try
    Planner.Plan;
    FBackendPlan := Planner.DetachPlan;
    if FBackendPlan = nil then
      FBackendStatus := 'deferred'
    else
      FBackendStatus := FBackendPlan.Status;
  finally
    Planner.Free;
  end;

  if FBackendStatus = 'ready' then
    PropagateSemanticLibraryRequestsToBackendPlan;
end;

