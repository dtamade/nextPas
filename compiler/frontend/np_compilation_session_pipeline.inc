procedure TCompilationSession.ResetSyntaxState;
begin
  ResetResolutionState;
  FreeAndNil(FAstFacade);
  FreeAndNil(FGreenTree);
  FreeAndNil(FLexerResult);
  { Drop AST arena slabs after trees freed (buffers may no-op FreeMem). }
  if FAstAllocator <> nil then
    (FAstAllocator as TVirtualArenaAllocator).Reset;
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
  if FSemanticModel <> nil then
  begin
    if (FQueryDB <> nil) and FQueryDB.ContainsValue(FSemanticModel) then
    begin
      FQueryDB.ForgetValue(FSemanticModel);
      FreeAndNil(FSemanticModel);
    end
    else
      FreeAndNil(FSemanticModel);
  end;
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
  if FToolStatusEvents <> nil then
    FToolStatusEvents.Clear;
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
  Event: TToolStatusEventRecord;
begin
  if FToolStatusEvents = nil then
    FToolStatusEvents := TToolStatusEventVec.Create;
  Event.EventKind := AEventKind;
  Event.StepId := AStepId;
  Event.ToolRole := AToolRole;
  Event.ProfileId := AProfileId;
  Event.LogicalExecutable := ALogicalExecutable;
  Event.SysrootRef := ASysrootRef;
  Event.ResolvedPath := AResolvedPath;
  Event.Status := AStatus;
  Event.ResultValue := AResultValue;
  Event.Summary := ASummary;
  Event.HasExitCode := AHasExitCode;
  Event.ExitCode := AExitCode;
  FToolStatusEvents.Push(Event);
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
  Event: ^TToolStatusEventRecord;
begin
  if FToolStatusEvents <> nil then
    for Index := LongInt(FToolStatusEvents.Count) - 1 downto 0 do
    begin
      { Prefer GetPtr: full record Items[] copy of multi-string events is fragile. }
      Event := FToolStatusEvents.GetPtr(SizeUInt(Index));
      if (Event^.ResolvedPath <> '') and
        nextpas.core.text.conv.SameText(Event^.StepId, PrimaryToolStepId) then
        Exit(Event^.ResolvedPath);
    end;

  if FToolchainPlan <> nil then
    Exit(FToolchainPlan.PrimaryToolExecutableRef);

  Result := '';
end;

function TCompilationSession.BuildStepOutputsJson(
  const AToolStep: TToolInvocationStep
): string;
begin
  Result := BuildToolArtifactVecJson(AToolStep.Outputs);
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
      if nextpas.core.text.conv.SameText(Result[ExistingIndex], ABaseName) then
        Exit;
    NextIndex := Length(Result);
    SetLength(Result, NextIndex + 1);
    Result[NextIndex] := ABaseName;
  end;
begin
  SetLength(Result, 0);
  if FUnitGraph = nil then
    Exit;
  if nextpas.core.text.conv.SameText(AstRootKindName, 'unit') then
    Exit;

  ResolvedSourcePath := ExpandFileName(FOptions.BuildContext.ResolvedSourcePath);
  for Index := 0 to FUnitGraph.ResolvedUnitCount - 1 do
  begin
    ResolvedUnit := FUnitGraph.ResolvedUnitAt(Index);
    if Trim(ResolvedUnit.SourcePath) = '' then
      Continue;
    if nextpas.core.text.conv.SameText(ResolvedUnit.OriginClass, 'implicit-runtime') then
      Continue;
    if nextpas.core.text.conv.SameText(ExpandFileName(ResolvedUnit.SourcePath), ResolvedSourcePath) then
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
  ClearToolInvocationStepView(Result);

  if FToolchainPlan = nil then
    Exit;

  for Index := 0 to FToolchainPlan.ToolInvocationCount - 1 do
    if nextpas.core.text.conv.SameText(FToolchainPlan.StepAt(Index).StepId, AStepId) then
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
    if nextpas.core.text.conv.SameText(ExecutedStep.StepId, AFailedStepId) then
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

  { Store 泄漏补漏：DB 已 Free 被失效的 Value，Session 悬垂指针需清零 }
  if (FSemanticModel <> nil) and (FQueryDB <> nil) and
     (not FQueryDB.ContainsValue(FSemanticModel)) then
  begin
    FSemanticModel := nil;
    FSemanticStatus := 'deferred';
  end
  else if FSemanticModel <> nil then
  begin
    for I := 0 to Length(Changed) - 1 do
      if Changed[I] = RootPath then
      begin
        if FQueryDB.ContainsValue(FSemanticModel) then
          FQueryDB.ForgetValue(FSemanticModel);
        FSemanticModel := nil;
        FSemanticStatus := 'deferred';
        Break;
      end;
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
  CanonPath: string;
  PathScratch: PAnsiChar;
  PathLen: SizeUInt;
  ScratchSize: SizeUInt;
begin
  { Unit phase over session VirtualArena: MemAlloc scratch, UnitEnd bulk-reclaims. }
  FMemScope.UnitBegin;
  try
    ResetSyntaxState;

    { Phase scratch: canonical path bytes + work region for include path setup.
      Owned by FMemScope; do not FreeMem. Falls back to string path if OOM. }
    CanonPath := FSourceDatabase.RootSourceCanonicalPath;
    PathLen := SizeUInt(Length(CanonPath));
    ScratchSize := PathLen + 1 + 256;
    PathScratch := PAnsiChar(MemAlloc(ScratchSize));
    if PathScratch <> nil then
    begin
      if PathLen > 0 then
        Move(CanonPath[1], PathScratch^, PathLen);
      PathScratch[PathLen] := #0;
      SetString(SourceDir, PathScratch, SizeInt(PathLen));
      SourceDir := ExtractFileDir(SourceDir);
    end
    else
      SourceDir := ExtractFileDir(CanonPath);

    RawLexer := TLexerResult.Create(FSourceDatabase.RootSourceText,
      FDiagnosticsSink, FRootFileId);
    Defines := TDefineTable.Create(FScratchAllocator);
    Defines.SeedFPCDefines;
    IncResolver := TFileIncludeResolver.Create(SourceDir, FScratchAllocator);
    IncResolver.AddSearchPath(SourceDir);
    PP := TPreprocessor.Create(Defines, True, IncResolver, FScratchAllocator);
    PP.Process(RawLexer);
    FLexerResult := PP.ToLexerResult;
    PP.Free;
    RawLexer.Free;
    FGreenTree := ParseGreenTree(
      FLexerResult, FDiagnosticsSink, FRootFileId, FAstAllocator);
    FAstFacade := TAstFacade.Create(FGreenTree);

    if FDiagnosticsSink.HasErrors or (FGreenTree = nil) or not FGreenTree.IsValid then
      FSyntaxStatus := 'failure'
    else
      FSyntaxStatus := 'ready';
  finally
    FMemScope.UnitEnd;
  end;
end;

procedure TCompilationSession.ResolveUnits;
var
  Resolver: TUnitResolver;
  PathScratch: PAnsiChar;
  RootPath: string;
  PathLen: SizeUInt;
  ScratchUsed: SizeUInt;
begin
  { Unit phase: resolution scratch on session arena; UnitEnd records peak. }
  FMemScope.UnitBegin;
  try
    ResetResolutionState;
    if (FAstFacade = nil) or not FAstFacade.IsValid then
    begin
      FResolutionStatus := 'failure';
      Exit;
    end;

    { Phase scratch: root path bytes + work region (no FreeMem; UnitEnd reclaims). }
    RootPath := FSourceDatabase.RootSourceCanonicalPath;
    PathLen := SizeUInt(Length(RootPath));
    PathScratch := PAnsiChar(MemAlloc(PathLen + 1 + 64));
    ScratchUsed := 0;
    if PathScratch <> nil then
    begin
      if PathLen > 0 then
        Move(RootPath[1], PathScratch^, PathLen);
      PathScratch[PathLen] := #0;
      ScratchUsed := PathLen + 1;
    end;

    { FScratchAllocator only for phase-local resolver work (stack/indexes/dep PP).
      DetachUnitGraph/DetachSearchPaths own default-heap TVecs for session use. }
    Resolver := TUnitResolver.Create(
      FSourceDatabase,
      FTargetFacts,
      FDiagnosticsSink,
      FRootFileId,
      FOptions.WorkspaceModel.ProjectUnitRootInfos,
      FOptions.ExplicitUnitRoots,
      FScratchAllocator
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
    { ScratchUsed documents phase path seed size; MemSessionPeak tracks peak. }
    if (ScratchUsed > 0) and (PathScratch <> nil) and (PathScratch[0] = #0) and
       (PathLen > 0) then
      ScratchUsed := 0; { inconsistent seed — ignore }
    ResetScratchAllocator;
  finally
    FMemScope.UnitEnd;
  end;
end;

procedure TCompilationSession.AnalyzeSemantics;
var
  CacheKey: string;
  CachedModel: TObject;
  DiskModel: TSemanticModel;
  PhaseScratch: Pointer;
begin
  { Query cache: if we already analyzed this file, skip }
  CacheKey := 'semantic:' + FSourceDatabase.RootSourceCanonicalPath;
  CachedModel := FQueryDB.Get(CacheKey, nil);
  if (CachedModel <> nil) and (CachedModel is TSemanticModel) then
  begin
    if FSemanticModel <> TSemanticModel(CachedModel) then
    begin
      if (FSemanticModel <> nil) and (FQueryDB <> nil) and FQueryDB.ContainsValue(FSemanticModel) then
        FQueryDB.ForgetValue(FSemanticModel);
      FreeAndNil(FSemanticModel);
    end;
    FSemanticModel := TSemanticModel(CachedModel);
    FSemanticStatus := FSemanticModel.Status;
    { Do NOT call ResetSemanticState — it would free the cached model }
    Exit;
  end;

  { Check persistent disk cache }
  if FIncrementalCache.HasCache(
    FSourceDatabase.RootSourceCanonicalPath,
    FSourceDatabase.RootSourceText,
    []) then
  begin
    if FIncrementalCache.Load(
      FSourceDatabase.RootSourceCanonicalPath,
      FSourceDatabase.RootSourceText,
      [],
      DiskModel) then
    begin
      if FSemanticModel <> DiskModel then
      begin
        if (FSemanticModel <> nil) and (FQueryDB <> nil) and FQueryDB.ContainsValue(FSemanticModel) then
          FQueryDB.ForgetValue(FSemanticModel);
        FreeAndNil(FSemanticModel);
      end;
      FSemanticModel := DiskModel;
      FSemanticStatus := FSemanticModel.Status;
      { Store in-memory cache too }
      if FSemanticStatus = 'ready' then
        FQueryDB.Store(CacheKey, FSemanticModel);
      Exit;
    end;
  end;

  FMemScope.UnitBegin;
  try
    ResetSemanticState;
    if (FAstFacade = nil) or (FUnitGraph = nil) or (FResolutionStatus <> 'ready') then
    begin
      FSemanticStatus := 'failure';
      Exit;
    end;

    { Phase scratch header + analyzer working storage on FScratchAllocator. }
    PhaseScratch := MemAlloc(256);
    if PhaseScratch = nil then
      ; { OOM soft: analyzer still runs on default heap if scratch nil }

    FSemanticModel := LowerAnalyzeSemantics(
      FAstFacade, FUnitGraph, FDiagnosticsSink, FRootFileId,
      FOptions.NoFold, FScratchAllocator);
    if FSemanticModel = nil then
      FSemanticStatus := 'deferred'
    else
    begin
      FSemanticStatus := FSemanticModel.Status;
      if FSemanticStatus = 'ready' then
      begin
        FQueryDB.Store(CacheKey, FSemanticModel);
        FIncrementalCache.Save(
          FSourceDatabase.RootSourceCanonicalPath,
          FSourceDatabase.RootSourceText,
          [], FSemanticModel);
      end;
    end;
    ResetScratchAllocator;
  finally
    FMemScope.UnitEnd;
  end;
end;

procedure TCompilationSession.LowerToMir;
var
  PhaseScratch: Pointer;
begin
  FMemScope.UnitBegin;
  try
    ResetIrState;
    if (FSemanticModel = nil) or (FSemanticStatus <> 'ready') then
    begin
      FMirStatus := 'failure';
      Exit;
    end;

    FMirStatus := 'ready';
    PhaseScratch := MemAlloc(128);
    if PhaseScratch = nil then
      ; { soft OOM }

    FMirModule := LowerBuildMirModule(
      FSemanticModel, FSourceDatabase, FRootFileId,
      FScratchAllocator, FDiagnosticsSink, FMirStatus);
    ResetScratchAllocator;
  finally
    FMemScope.UnitEnd;
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
