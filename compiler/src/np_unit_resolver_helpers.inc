procedure FreeSearchIndexEntryNested(var AEntry: TSearchIndexEntry);
begin
  AEntry.CandidatePaths.Free;
  AEntry.CandidatePaths := nil;
end;

procedure FreeSearchIndexEntriesNested(AEntries: TSearchIndexEntryVec);
var
  Index: LongInt;
  Entry: PSearchIndexEntry;
begin
  if AEntries = nil then
    Exit;
  { Count is SizeUInt — cast before -1 so empty vec does not underflow. }
  for Index := 0 to LongInt(AEntries.Count) - 1 do
  begin
    Entry := AEntries.GetPtr(SizeUInt(Index));
    FreeSearchIndexEntryNested(Entry^);
  end;
end;

function CreateCandidatePathVec(AAllocator: IAllocator): TUnitResolverStringVec;
begin
  if AAllocator <> nil then
    Result := TUnitResolverStringVec.Create(0, AAllocator)
  else
    Result := TUnitResolverStringVec.Create;
end;

constructor TUnitResolver.Create(
  const ASourceDatabase: TSourceDatabase;
  const ATargetFacts: TTargetFactsView;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const AProjectUnitRootInfos: TProjectUnitRootInfoArray;
  const AExplicitUnitRoots: TStringArray;
  const ANodeAllocator: IAllocator
);
var
  Index: LongInt;
begin
  inherited Create;
  FSourceDatabase := ASourceDatabase;
  FDiagnostics := ADiagnostics;
  FTargetFacts := ATargetFacts;
  FRootFileId := ARootFileId;
  FNodeAllocator := ANodeAllocator;
  { Session-long root tables (survive into BuildSearchPaths ownership on
    FSearchPaths / Detach products). Dynarray ctor args are copied onto
    default-heap TVec — not phase scratch. }
  FProjectUnitRootInfos := TProjectUnitRootInfoVec.Create;
  for Index := 0 to Length(AProjectUnitRootInfos) - 1 do
    FProjectUnitRootInfos.Push(AProjectUnitRootInfos[Index]);
  FExplicitUnitRoots := TUnitResolverStringVec.Create;
  for Index := 0 to Length(AExplicitUnitRoots) - 1 do
    FExplicitUnitRoots.Push(AExplicitUnitRoots[Index]);
  { Detached into session (FUnitGraph / FSearchPathSet) and used after
    ResolveUnits ResetScratchAllocator — must be default-heap, not phase scratch. }
  FSearchPaths := TSearchPathSet.Create;
  FUnitGraph := TUnitGraph.Create;
  FResolutionStatus := 'deferred';
  { Phase-local only: destroyed with resolver before ResetScratchAllocator. }
  if FNodeAllocator <> nil then
  begin
    FResolutionStack := TResolutionStackVec.Create(0, FNodeAllocator);
    FRootIndexes := TRootSearchIndexVec.Create(0, FNodeAllocator);
  end
  else
  begin
    FResolutionStack := TResolutionStackVec.Create;
    FRootIndexes := TRootSearchIndexVec.Create;
  end;
  BuildSearchPaths;
end;

procedure TUnitResolver.FreeRootIndexEntries;
var
  Index: LongInt;
  Root: TRootSearchIndex;
begin
  if FRootIndexes = nil then
    Exit;
  for Index := 0 to LongInt(FRootIndexes.Count) - 1 do
  begin
    Root := FRootIndexes[Index];
    FreeSearchIndexEntriesNested(Root.Entries);
    Root.Entries.Free;
    Root.Entries := nil;
    FRootIndexes[Index] := Root;
  end;
end;

destructor TUnitResolver.Destroy;
begin
  FreeRootIndexEntries;
  FRootIndexes.Free;
  FResolutionStack.Free;
  FUnitGraph.Free;
  FSearchPaths.Free;
  FProjectUnitRootInfos.Free;
  FProjectUnitRootInfos := nil;
  FExplicitUnitRoots.Free;
  FExplicitUnitRoots := nil;
  inherited Destroy;
end;

procedure TUnitResolver.EmitResolutionError(
  const ACode: string;
  const AFileId: TSourceFileId;
  const AMessage: string
);
begin
  FDiagnostics.EmitError(ACode, 'resolution', AFileId, 0, AMessage);
  FResolutionStatus := 'failure';
  FUnitGraph.MarkFailure;
end;

procedure TUnitResolver.PushResolutionStack(
  const AUnitId: string;
  const AEnteredBy: TUnitGraphEdgeKind
);
var
  Entry: TResolutionStackEntry;
begin
  Entry.UnitId := AUnitId;
  Entry.EnteredBy := AEnteredBy;
  FResolutionStack.Push(Entry);
end;

procedure TUnitResolver.PopResolutionStack;
var
  Entry: TResolutionStackEntry;
begin
  if FResolutionStack.Count = 0 then
    Exit;
  if not FResolutionStack.TryPop(Entry) then
    ;
end;

function TUnitResolver.StackIndexOf(const AUnitId: string): LongInt;
var
  Index: LongInt;
begin
  for Index := 0 to LongInt(FResolutionStack.Count) - 1 do
    if FResolutionStack[Index].UnitId = AUnitId then
      Exit(Index);

  Result := -1;
end;

function TUnitResolver.StackPathHasImplementationBoundary(
  const AStartIndex: LongInt
): Boolean;
var
  Index: LongInt;
begin
  for Index := AStartIndex + 1 to LongInt(FResolutionStack.Count) - 1 do
    if FResolutionStack[Index].EnteredBy = ugeImplementationUse then
      Exit(True);

  Result := False;
end;

function TUnitResolver.BuildCyclePath(const AUnitId: string): string;
var
  Index: LongInt;
  StartIndex: LongInt;
begin
  StartIndex := StackIndexOf(AUnitId);
  if StartIndex < 0 then
    StartIndex := 0;

  Result := '';
  for Index := StartIndex to LongInt(FResolutionStack.Count) - 1 do
  begin
    if Result <> '' then
      Result := Result + ' -> ';
    Result := Result + FResolutionStack[Index].UnitId;
  end;

  if Result <> '' then
    Result := Result + ' -> ';
  Result := Result + AUnitId;
end;

function TUnitResolver.DescribeSearchPathEntry(
  const AEntry: TSearchPathEntry
): string;
begin
  Result := 'scope=' + AEntry.ScopeName;

  if AEntry.ProvenanceKind <> '' then
    Result := Result + ' provenance=' + AEntry.ProvenanceKind;
  if AEntry.PackageName <> '' then
    Result := Result + ' package=' + AEntry.PackageName;
  if AEntry.ManifestPath <> '' then
    Result := Result + ' manifest=' + AEntry.ManifestPath;
  if AEntry.WorkspaceMemberPath <> '' then
    Result := Result + ' workspace-member=' + AEntry.WorkspaceMemberPath;

  Result := Result + ' root=' + AEntry.RootPath;
end;

function TUnitResolver.FindSearchPathEntryForPath(
  const APath: string;
  out AEntry: TSearchPathEntry
): Boolean;
var
  Index: LongInt;
  BestIndex: LongInt;
  Entry: TSearchPathEntry;
begin
  BestIndex := -1;
  AEntry.RootPath := '';
  AEntry.ScopeName := '';
  AEntry.ProvenanceKind := '';
  AEntry.PackageName := '';
  AEntry.ManifestPath := '';
  AEntry.WorkspaceMemberPath := '';

  for Index := 0 to LongInt(FSearchPaths.Count) - 1 do
  begin
    Entry := FSearchPaths.EntryAt(Index);
    if not CorePathStartsWith(APath, Entry.RootPath) then
      Continue;

    if (BestIndex < 0) or
      (Length(Entry.RootPath) > Length(FSearchPaths.EntryAt(BestIndex).RootPath)) then
    begin
      BestIndex := Index;
      AEntry := Entry;
    end;
  end;

  Result := BestIndex >= 0;
end;

function TUnitResolver.SearchRootsSummary: string;
var
  Index: LongInt;
begin
  Result := '';
  for Index := 0 to LongInt(FSearchPaths.Count) - 1 do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + DescribeSearchPathEntry(FSearchPaths.EntryAt(Index));
  end;
end;

function TUnitResolver.CandidateSummary(const ACandidates: TStringArray): string;
var
  Index: LongInt;
  Entry: TSearchPathEntry;
begin
  Result := '';
  for Index := 0 to Length(ACandidates) - 1 do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + 'path=' + ACandidates[Index];
    if FindSearchPathEntryForPath(ACandidates[Index], Entry) then
      Result := Result + ' ' + DescribeSearchPathEntry(Entry)
    else
      Result := Result + ' root=' + ExtractFileDir(ACandidates[Index]);
  end;
end;

function TUnitResolver.ResolveUnitOrigin(
  const ASourcePath: string
): TResolvedUnitOrigin;
begin
  if CorePathStartsWith(ASourcePath, FTargetFacts.UnitsDir) then
    Exit(ruoInstalledSource);

  Result := ruoProjectSource;
end;

function TUnitResolver.EnsureRuntimeUnit: TResolvedUnit;
var
  RuntimeSystemPath: string;
begin
  if not FUnitGraph.FindUnit('system', Result) then
  begin
    RuntimeSystemPath := '';
    if FTargetFacts.UnitsDir <> '' then
    begin
      RuntimeSystemPath := IncludeTrailingPathDelimiter(FTargetFacts.UnitsDir) +
        'System.pas';
      if not FsExists(RuntimeSystemPath) then
        RuntimeSystemPath := '';
    end;
    Result := BuildResolvedUnit(
      'System',
      RuntimeSystemPath,
      ruoImplicitRuntime,
      FTargetFacts.TargetId,
      'unit',
      0
    );
    FUnitGraph.AddResolvedUnit(Result);
  end;
end;

procedure TUnitResolver.EnsureImplicitRuntimeDependency(
  const ASourceUnitId: string
);
var
  RuntimeUnit: TResolvedUnit;
begin
  if (Trim(ASourceUnitId) = '') or SameText(ASourceUnitId, 'system') then
    Exit;

  RuntimeUnit := EnsureRuntimeUnit;
  if RuntimeUnit.UnitId = '' then
    Exit;
  FUnitGraph.AddEdge(ugeImplicitRuntime, ASourceUnitId, RuntimeUnit.UnitId);
end;

function TUnitResolver.FindIndexedEntry(
  const ARootIndex: LongInt;
  const AUnitId: string
): LongInt;
var
  Index: LongInt;
  Root: TRootSearchIndex;
begin
  if (ARootIndex < 0) or (ARootIndex >= LongInt(FRootIndexes.Count)) then
    Exit(-1);

  Root := FRootIndexes[ARootIndex];
  if Root.Entries = nil then
    Exit(-1);
  for Index := 0 to LongInt(Root.Entries.Count) - 1 do
    if Root.Entries[Index].UnitId = AUnitId then
      Exit(Index);

  Result := -1;
end;

procedure TUnitResolver.InitializeRootIndexes;
var
  Index: LongInt;
  Root: TRootSearchIndex;
begin
  FreeRootIndexEntries;
  FRootIndexes.Clear;
  { Capacity only — Ensure() raises Count and would double after Push. }
  FRootIndexes.EnsureCapacity(SizeUInt(FSearchPaths.Count));
  for Index := 0 to LongInt(FSearchPaths.Count) - 1 do
  begin
    Root.RootPath := FSearchPaths.RootPathAt(Index);
    Root.Status := 'deferred';
    if FNodeAllocator <> nil then
      Root.Entries := TSearchIndexEntryVec.Create(0, FNodeAllocator)
    else
      Root.Entries := TSearchIndexEntryVec.Create;
    Root.ScanCount := 0;
    Root.LastScanTimestamp := 0;
    FRootIndexes.Push(Root);
  end;
end;

procedure TUnitResolver.EnsureRootIndex(const ARootIndex: LongInt);
var
  CandidatePath: string;
  EntryIndex: LongInt;
  UnitId: string;
  RootDir: string;
  DirEntries: TDirEntryArray;
  I: LongInt;
  Ext: string;
  Root: TRootSearchIndex;
  Entry: TSearchIndexEntry;
begin
  if (ARootIndex < 0) or (ARootIndex >= LongInt(FRootIndexes.Count)) then
    Exit;
  Root := FRootIndexes[ARootIndex];
  if Root.Status = 'ready' then
    Exit;

  Root.RootPath := FSearchPaths.RootPathAt(ARootIndex);
  if Root.Entries <> nil then
  begin
    FreeSearchIndexEntriesNested(Root.Entries);
    Root.Entries.Clear;
  end;
  Inc(Root.ScanCount);
  FRootIndexes[ARootIndex] := Root;

  RootDir := Root.RootPath;
  DirEntries := FsReadDir(RootDir);
  for I := 0 to High(DirEntries) do
  begin
    if DirEntries[I].IsDir then
      Continue;

    Ext := LowerCase(PathExt(DirEntries[I].Name));
    if (Ext <> '.pas') and (Ext <> '.pp') then
      Continue;

    UnitId := NormalizeUnitIdentity(ChangeFileExt(DirEntries[I].Name, ''));
    if UnitId = '' then
      Continue;

    CandidatePath := NormalizeCorePath(
      IncludeTrailingPathDelimiter(RootDir) + DirEntries[I].Name
    );
    EntryIndex := FindIndexedEntry(ARootIndex, UnitId);
    Root := FRootIndexes[ARootIndex];
    if EntryIndex < 0 then
    begin
      Entry := Default(TSearchIndexEntry);
      Entry.UnitId := UnitId;
      Entry.CandidatePaths := CreateCandidatePathVec(FNodeAllocator);
      Root.Entries.Push(Entry);
      EntryIndex := LongInt(Root.Entries.Count) - 1;
    end;
    Entry := Root.Entries[EntryIndex];
    if Entry.CandidatePaths = nil then
      Entry.CandidatePaths := CreateCandidatePathVec(FNodeAllocator);
    Entry.CandidatePaths.Push(CandidatePath);
    Root.Entries[EntryIndex] := Entry;
    FRootIndexes[ARootIndex] := Root;
  end;

  Root := FRootIndexes[ARootIndex];
  Root.Status := 'ready';
  Root.LastScanTimestamp := Round(DateTimeNow * 86400);
  FRootIndexes[ARootIndex] := Root;
end;

function TUnitResolver.FindCandidatePathsInRoot(
  const ARootIndex: LongInt;
  const ARequestedUnitId: string
): TStringArray;
var
  EntryIndex: LongInt;
  Paths: TUnitResolverStringVec;
begin
  Result := nil;
  EnsureRootIndex(ARootIndex);
  EntryIndex := FindIndexedEntry(ARootIndex, ARequestedUnitId);
  if EntryIndex < 0 then
    Exit;

  Paths := FRootIndexes[ARootIndex].Entries[EntryIndex].CandidatePaths;
  if Paths = nil then
    Exit;
  Result := Paths.ToArray;
end;

function TUnitResolver.FindCandidatePaths(
  const ARequestedName: string
): TStringArray;
var
  BaseIdentity: string;
  RootCandidates: TStringArray;
  Index: LongInt;
begin
  Result := nil;
  BaseIdentity := NormalizeUnitIdentity(ARequestedName);
  if BaseIdentity = '' then
    Exit;

  for Index := 0 to LongInt(FSearchPaths.Count) - 1 do
  begin
    RootCandidates := FindCandidatePathsInRoot(Index, BaseIdentity);
    if Length(RootCandidates) > 0 then
      Exit(RootCandidates);
  end;
end;

