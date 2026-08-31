var
  GSessionNonce: LongInt = 0;

function BuildToolArtifactArrayJson(
  const AValues: array of TToolArtifactRef
): string;
var
  EntryFields: string;
  Index: SizeInt;
begin
  Result := '';
  for Index := 0 to High(AValues) do
  begin
    if Result <> '' then
      Result := Result + ',';
    EntryFields := '';
    AppendJsonField(EntryFields, 'kind', JsonString(AValues[Index].Kind));
    AppendJsonField(EntryFields, 'path', JsonString(AValues[Index].Path));
    Result := Result + '{' + EntryFields + '}';
  end;
  Result := '[' + Result + ']';
end;

function BuildExecutedSidecarArrayJson(
  const AValues: TToolchainExecutedSidecarArray
): string;
var
  EntryFields: string;
  Index: SizeInt;
begin
  Result := '';
  for Index := 0 to High(AValues) do
  begin
    if Result <> '' then
      Result := Result + ',';
    EntryFields := '';
    AppendJsonField(EntryFields, 'kind', JsonString(AValues[Index].Kind));
    AppendJsonField(EntryFields, 'path', JsonString(AValues[Index].Path));
    AppendJsonField(EntryFields, 'ownerStepId', JsonString(AValues[Index].OwnerStepId));
    AppendJsonField(
      EntryFields,
      'materializationTiming',
      JsonString(AValues[Index].MaterializationTiming)
    );
    AppendJsonField(
      EntryFields,
      'cleanupPolicy',
      JsonString(AValues[Index].CleanupPolicy)
    );
    if AValues[Index].Materialized then
      AppendJsonField(EntryFields, 'materialized', 'true')
    else
      AppendJsonField(EntryFields, 'materialized', 'false');
    AppendJsonField(
      EntryFields,
      'cleanupStatus',
      JsonString(AValues[Index].CleanupStatus)
    );
    Result := Result + '{' + EntryFields + '}';
  end;
  Result := '[' + Result + ']';
end;

function BuildSessionId(
  const ACommandName: string;
  const ATargetId: string;
  const ARootFileId: TSourceFileId
): string;
var
  EntropyToken: string;
  SessionNonceText: string;
begin
  Inc(GSessionNonce);
  SessionNonceText := IntToStr(GSessionNonce);
  while Length(SessionNonceText) < 2 do
    SessionNonceText := '0' + SessionNonceText;
  EntropyToken := FormatDateTime('yyyymmddhhnnsszzz', DateTimeNow) + '-' +
    SessionNonceText;
  Result := ACommandName + '-' + ATargetId + '-' + EntropyToken +
    '-file-' + IntToStr(ARootFileId);
end;

constructor TCompilationSession.CreateBuildSession(
  const Options: TCompilationOptions;
  const TargetFacts: TTargetFactsView
);
begin
  inherited Create;

  { Session-owned VirtualArena — product wire to nextpas.core.compiler.mem. }
  FillChar(FMemScope, SizeOf(FMemScope), 0);
  FMemScope.BeginSession;
  FAstAllocator := CompilerCreateUnitAllocator;
  FScratchAllocator := CompilerCreateUnitAllocator;
  { Session-long; not phase scratch (survives ResetScratchAllocator). }
  FToolStatusEvents := TToolStatusEventVec.Create;

  FSourceDatabase := TSourceDatabase.Create;
  FDiagnosticsSink := TDiagnosticsSink.CreateDefault;
  FDiagnosticsSink.BindByteCountResolver(@FSourceDatabase.ResolveDiagnosticByteCount);
  FTargetFacts := TargetFacts;
  FOptions := Options;
  if FOptions.CommandName = '' then
    FOptions.CommandName := 'build';
  if FOptions.BuildContext.RequestedTargetId = '' then
    FOptions.BuildContext.RequestedTargetId := TargetFacts.TargetId;
  if FOptions.BuildContext.ResolvedSourcePath = '' then
    FOptions.BuildContext.ResolvedSourcePath := ExpandFileName(
      FOptions.BuildContext.RequestedSourcePath
    );
  FRootFileId := FSourceDatabase.RegisterRootSource(
    FOptions.BuildContext.RequestedSourcePath
  );
  FUnitStateCount := 1;
  FLexerResult := nil;
  FGreenTree := nil;
  FAstFacade := nil;
  FSyntaxStatus := 'deferred';
  FSearchPathSet := nil;
  FUnitGraph := nil;
  FResolutionStatus := 'deferred';
  FSearchIndexStatus := 'deferred';
  FIndexedSearchRootCount := 0;
  FSearchIndexScanCount := 0;
  FSemanticModel := nil;
  FSemanticStatus := 'deferred';
  FQueryDB := TQueryDatabase.Create;
  FFileDetector := TFileChangeDetector.Create;
  FScheduler := nil;  { Created on-demand for parallel builds }
  FIncrementalCache := TIncrementalCache.Create(
    ExtractFileDir(FOptions.BuildContext.ResolvedSourcePath) + '/.nextpas/cache'
  );
  FIncrementalCache.Enabled := FOptions.Incremental;
  FMirStatus := 'deferred';
  FBackendPlan := nil;
  FBackendStatus := 'deferred';
  FToolchainPlan := nil;
  FToolchainStatus := 'deferred';
  ClearToolRunState;
  ClearToolStatusEvents;
  ClearBuildTrace;
  FSessionId := BuildSessionId(
    FOptions.CommandName,
    FTargetFacts.TargetId,
    FRootFileId
  );
end;

destructor TCompilationSession.Destroy;
begin
  FOptions.WorkspaceModel.Free;
  FToolchainPlan.Free;
  FBackendPlan.Free;
  FMirModule.Free;
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
  FUnitGraph.Free;
  FSearchPathSet.Free;
  FAstFacade.Free;
  FGreenTree.Free;
  FLexerResult.Free;
  FDiagnosticsSink.Free;
  FSourceDatabase.Free;
  if FScheduler <> nil then FScheduler.Free;
  FIncrementalCache.Free;
  FFileDetector.Free;
  FQueryDB.Free;
  FreeAndNil(FToolStatusEvents);
  FScratchAllocator := nil;
  FAstAllocator := nil;
  FMemScope.EndSession;
  inherited Destroy;
end;

procedure TCompilationSession.ResetScratchAllocator;
begin
  if FScratchAllocator <> nil then
    (FScratchAllocator as TVirtualArenaAllocator).Reset;
end;

function TCompilationSession.MemScopeActive: Boolean;
begin
  Result := FMemScope.Active;
end;

function TCompilationSession.MemSessionPeak: SizeUInt;
begin
  Result := FMemScope.SessionPeak;
end;

function TCompilationSession.MemUnitCount: SizeUInt;
begin
  Result := FMemScope.UnitCount;
end;

function TCompilationSession.MemTotalUsed: SizeUInt;
begin
  Result := FMemScope.TotalUsed;
end;

function TCompilationSession.MemAlloc(const ASize: SizeUInt): Pointer;
begin
  Result := FMemScope.Alloc(ASize);
end;

function TCompilationSession.MemAstAllocator: IAllocator;
begin
  Result := FAstAllocator;
end;

function TCompilationSession.MemScratchAllocator: IAllocator;
begin
  Result := FScratchAllocator;
end;

function TCompilationSession.MemFormatSessionStats: string;
var
  LAst: string;
  LScratch: string;
begin
  { Core line from TCompilerSessionScope.FormatStats; session product flags
    for AST/scratch allocators are appended for ops. }
  if FAstAllocator <> nil then
    LAst := '1'
  else
    LAst := '0';
  if FScratchAllocator <> nil then
    LScratch := '1'
  else
    LScratch := '0';
  Result := FMemScope.FormatStats +
    ' ast=' + LAst +
    ' scratch=' + LScratch;
end;
