function TUnitResolver.ResolveDependencyList(
  const ASourceUnitId: string;
  const AOwnerFileId: TSourceFileId;
  const AFacade: TAstFacade;
  const AEdgeKind: TUnitGraphEdgeKind
): Boolean;
var
  Index: LongInt;
  UseCount: LongInt;
  UseName: string;
  AnyFailure: Boolean;
begin
  AnyFailure := False;
  if AEdgeKind = ugeImplementationUse then
    UseCount := AFacade.ImplementationUseCount
  else
    UseCount := AFacade.InterfaceUseCount;

  for Index := 0 to UseCount - 1 do
  begin
    if AEdgeKind = ugeImplementationUse then
      UseName := AFacade.ImplementationUseAt(Index)
    else
      UseName := AFacade.InterfaceUseAt(Index);

    if not ResolveDependency(ASourceUnitId, UseName, AEdgeKind, AOwnerFileId) then
      AnyFailure := True;
  end;

  Result := not AnyFailure;
end;

procedure TUnitResolver.BuildSearchPaths;
var
  Index: LongInt;
  RootSourcePath: string;
begin
  RootSourcePath := FSourceDatabase.RootSourceCanonicalPath;
  if RootSourcePath <> '' then
    FSearchPaths.AddRoot(ExtractFileDir(RootSourcePath), 'root-source');
  if FProjectUnitRootInfos <> nil then
    for Index := 0 to LongInt(FProjectUnitRootInfos.Count) - 1 do
      FSearchPaths.AddRoot(
        FProjectUnitRootInfos[SizeUInt(Index)].RootPath,
        FProjectUnitRootInfos[SizeUInt(Index)].ScopeName,
        FProjectUnitRootInfos[SizeUInt(Index)].ProvenanceKind,
        FProjectUnitRootInfos[SizeUInt(Index)].PackageName,
        FProjectUnitRootInfos[SizeUInt(Index)].ManifestPath,
        FProjectUnitRootInfos[SizeUInt(Index)].WorkspaceMemberPath
      );
  if FExplicitUnitRoots <> nil then
    for Index := 0 to LongInt(FExplicitUnitRoots.Count) - 1 do
      FSearchPaths.AddRoot(
        FExplicitUnitRoots[SizeUInt(Index)],
        'explicit-unit-root'
      );
  if FTargetFacts.UnitsDir <> '' then
    FSearchPaths.AddRoot(FTargetFacts.UnitsDir, 'target-installed');
  InitializeRootIndexes;
end;

function TUnitResolver.CandidateCountFor(const ARequestedName: string): LongInt;
begin
  Result := Length(FindCandidatePaths(ARequestedName));
end;

function TUnitResolver.IndexedRootCount: LongInt;
var
  Index: LongInt;
begin
  Result := 0;
  for Index := 0 to LongInt(FRootIndexes.Count) - 1 do
    if FRootIndexes[Index].Status = 'ready' then
      Inc(Result);
end;

function TUnitResolver.SearchIndexScanCount: LongInt;
var
  Index: LongInt;
begin
  Result := 0;
  for Index := 0 to LongInt(FRootIndexes.Count) - 1 do
    Inc(Result, FRootIndexes[Index].ScanCount);
end;

function TUnitResolver.SearchIndexStatus: string;
begin
  if FRootIndexes.Count = 0 then
    Exit('empty');
  if IndexedRootCount = 0 then
    Exit('deferred');
  if IndexedRootCount = LongInt(FRootIndexes.Count) then
    Exit('ready');

  Result := 'partial';
end;

function TUnitResolver.SearchIndexLastScanTimestamp: Int64;
var
  Index: LongInt;
begin
  Result := 0;
  for Index := 0 to LongInt(FRootIndexes.Count) - 1 do
    if FRootIndexes[Index].LastScanTimestamp > Result then
      Result := FRootIndexes[Index].LastScanTimestamp;
end;

procedure TUnitResolver.ResolveRoot(const ARootAst: TAstFacade);
var
  RootUnit: TResolvedUnit;
  RuntimeUnit: TResolvedUnit;
begin
  if (ARootAst = nil) or not ARootAst.IsValid then
  begin
    FResolutionStatus := 'failure';
    FUnitGraph.MarkFailure;
    Exit;
  end;

  RootUnit := BuildResolvedUnit(
    ARootAst.DeclaredName,
    FSourceDatabase.RootSourceCanonicalPath,
    ruoRootSource,
    FTargetFacts.TargetId,
    ARootAst.RootKindName,
    FRootFileId
  );
  FUnitGraph.SetRootName(RootUnit.CanonicalName);
  FUnitGraph.AddResolvedUnit(RootUnit);
  FUnitGraph.AddEdge(ugeRootRequest, '@build', RootUnit.UnitId);

  PushResolutionStack(RootUnit.UnitId, ugeRootRequest);
  try
    EnsureImplicitRuntimeDependency(RootUnit.UnitId);

    if not ResolveDependencyList(
      RootUnit.UnitId,
      FRootFileId,
      ARootAst,
      ugeInterfaceUse
    ) then
      Exit;
    if not ResolveDependencyList(
      RootUnit.UnitId,
      FRootFileId,
      ARootAst,
      ugeImplementationUse
    ) then
      Exit;
  finally
    PopResolutionStack;
  end;

  if FDiagnostics.HasErrors then
  begin
    FResolutionStatus := 'failure';
    FUnitGraph.MarkFailure;
    Exit;
  end;

  FResolutionStatus := 'ready';
  FUnitGraph.MarkReady;
end;

function TUnitResolver.ResolutionStatus: string;
begin
  Result := FResolutionStatus;
end;

function TUnitResolver.DetachSearchPaths: TSearchPathSet;
begin
  Result := FSearchPaths;
  FSearchPaths := nil;
end;

function TUnitResolver.DetachUnitGraph: TUnitGraph;
begin
  Result := FUnitGraph;
  FUnitGraph := nil;
end;

end.
