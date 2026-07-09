procedure AppendString(var AItems: TStringArray; const AValue: string);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(AItems);
  SetLength(AItems, NextIndex + 1);
  AItems[NextIndex] := AValue;
end;

constructor TUnitResolver.Create(
  const ASourceDatabase: TSourceDatabase;
  const ATargetFacts: TTargetFactsView;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const AProjectUnitRootInfos: TProjectUnitRootInfoArray;
  const AExplicitUnitRoots: TStringArray
);
begin
  inherited Create;
  FSourceDatabase := ASourceDatabase;
  FDiagnostics := ADiagnostics;
  FTargetFacts := ATargetFacts;
  FRootFileId := ARootFileId;
  FProjectUnitRootInfos := AProjectUnitRootInfos;
  FExplicitUnitRoots := AExplicitUnitRoots;
  FSearchPaths := TSearchPathSet.Create;
  FUnitGraph := TUnitGraph.Create;
  FResolutionStatus := 'deferred';
  SetLength(FResolutionStack, 0);
  BuildSearchPaths;
end;

destructor TUnitResolver.Destroy;
begin
  FUnitGraph.Free;
  FSearchPaths.Free;
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
  NextIndex: SizeInt;
begin
  NextIndex := Length(FResolutionStack);
  SetLength(FResolutionStack, NextIndex + 1);
  FResolutionStack[NextIndex].UnitId := AUnitId;
  FResolutionStack[NextIndex].EnteredBy := AEnteredBy;
end;

procedure TUnitResolver.PopResolutionStack;
begin
  if Length(FResolutionStack) = 0 then
    Exit;

  SetLength(FResolutionStack, Length(FResolutionStack) - 1);
end;

function TUnitResolver.StackIndexOf(const AUnitId: string): LongInt;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FResolutionStack) - 1 do
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
  for Index := AStartIndex + 1 to Length(FResolutionStack) - 1 do
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
  for Index := StartIndex to Length(FResolutionStack) - 1 do
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

  for Index := 0 to FSearchPaths.Count - 1 do
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
  for Index := 0 to FSearchPaths.Count - 1 do
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
begin
  if (ARootIndex < 0) or (ARootIndex >= Length(FRootIndexes)) then
    Exit(-1);

  for Index := 0 to Length(FRootIndexes[ARootIndex].Entries) - 1 do
    if FRootIndexes[ARootIndex].Entries[Index].UnitId = AUnitId then
      Exit(Index);

  Result := -1;
end;

procedure TUnitResolver.InitializeRootIndexes;
var
  Index: LongInt;
begin
  SetLength(FRootIndexes, FSearchPaths.Count);
  for Index := 0 to FSearchPaths.Count - 1 do
  begin
    FRootIndexes[Index].RootPath := FSearchPaths.RootPathAt(Index);
    FRootIndexes[Index].Status := 'deferred';
    SetLength(FRootIndexes[Index].Entries, 0);
    FRootIndexes[Index].ScanCount := 0;
    FRootIndexes[Index].LastScanTimestamp := 0;
  end;
end;

procedure TUnitResolver.EnsureRootIndex(const ARootIndex: LongInt);
var
  CandidatePath: string;
  EntryIndex: LongInt;
  Index: LongInt;
  UnitId: string;
  RootDir: string;
  Entries: TDirEntryArray;
  I: LongInt;
  Ext: string;
begin
  if (ARootIndex < 0) or (ARootIndex >= Length(FRootIndexes)) then
    Exit;
  if FRootIndexes[ARootIndex].Status = 'ready' then
    Exit;

  FRootIndexes[ARootIndex].RootPath := FSearchPaths.RootPathAt(ARootIndex);
  SetLength(FRootIndexes[ARootIndex].Entries, 0);
  Inc(FRootIndexes[ARootIndex].ScanCount);

  RootDir := FRootIndexes[ARootIndex].RootPath;
  Entries := FsReadDir(RootDir);
  for I := 0 to High(Entries) do
  begin
    if Entries[I].IsDir then
      Continue;

    Ext := LowerCase(PathExt(Entries[I].Name));
    if (Ext <> '.pas') and (Ext <> '.pp') then
      Continue;

    UnitId := NormalizeUnitIdentity(ChangeFileExt(Entries[I].Name, ''));
    if UnitId = '' then
      Continue;

    CandidatePath := NormalizeCorePath(
      IncludeTrailingPathDelimiter(RootDir) + Entries[I].Name
    );
    EntryIndex := FindIndexedEntry(ARootIndex, UnitId);
    if EntryIndex < 0 then
    begin
      Index := Length(FRootIndexes[ARootIndex].Entries);
      SetLength(FRootIndexes[ARootIndex].Entries, Index + 1);
      FRootIndexes[ARootIndex].Entries[Index].UnitId := UnitId;
      SetLength(FRootIndexes[ARootIndex].Entries[Index].CandidatePaths, 0);
      EntryIndex := Index;
    end;
    AppendString(
      FRootIndexes[ARootIndex].Entries[EntryIndex].CandidatePaths,
      CandidatePath
    );
  end;

  FRootIndexes[ARootIndex].Status := 'ready';
  FRootIndexes[ARootIndex].LastScanTimestamp := Round(DateTimeNow * 86400);
end;

function TUnitResolver.FindCandidatePathsInRoot(
  const ARootIndex: LongInt;
  const ARequestedUnitId: string
): TStringArray;
var
  EntryIndex: LongInt;
begin
  Result := nil;
  EnsureRootIndex(ARootIndex);
  EntryIndex := FindIndexedEntry(ARootIndex, ARequestedUnitId);
  if EntryIndex < 0 then
    Exit;

  Result := FRootIndexes[ARootIndex].Entries[EntryIndex].CandidatePaths;
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

  for Index := 0 to FSearchPaths.Count - 1 do
  begin
    RootCandidates := FindCandidatePathsInRoot(Index, BaseIdentity);
    if Length(RootCandidates) > 0 then
      Exit(RootCandidates);
  end;
end;

