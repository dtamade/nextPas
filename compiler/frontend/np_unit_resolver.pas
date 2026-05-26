unit np_unit_resolver;

{$mode objfpc}{$H+}
{$UNITPATH .}
{$UNITPATH ../diagnostics}
{$UNITPATH ../syntax}
{$UNITPATH ../targets}
{$UNITPATH ../../rtl/core/text}

interface

uses
  SysUtils, np_ast_facade, np_diagnostics_sink, np_green_tree, np_lexer,
  np_package_manifest, np_source_database, np_target_facts, np_text_primitives,
  np_toolchain_profiles, np_unit_graph;

type
  TSearchIndexEntry = record
    UnitId: string;
    CandidatePaths: TStringArray;
  end;

  TRootSearchIndex = record
    RootPath: string;
    Status: string;
    Entries: array of TSearchIndexEntry;
    ScanCount: LongInt;
    LastScanTimestamp: Int64;
  end;

  TUnitResolver = class
  private
    FSourceDatabase: TSourceDatabase;
    FDiagnostics: TDiagnosticsSink;
    FTargetFacts: TTargetFactsView;
    FSearchPaths: TSearchPathSet;
    FUnitGraph: TUnitGraph;
    FRootFileId: TSourceFileId;
    FResolutionStatus: string;
    FResolutionStack: TStringArray;
    FProjectUnitRootInfos: TProjectUnitRootInfoArray;
    FExplicitUnitRoots: TStringArray;
    FRootIndexes: array of TRootSearchIndex;
    procedure EmitResolutionError(
      const ACode: string;
      const AFileId: TSourceFileId;
      const AMessage: string
    );
    procedure PushResolutionStack(const AUnitId: string);
    procedure PopResolutionStack;
    function StackContains(const AUnitId: string): Boolean;
    function BuildCyclePath(const AUnitId: string): string;
    function DescribeSearchPathEntry(const AEntry: TSearchPathEntry): string;
    function FindSearchPathEntryForPath(
      const APath: string;
      out AEntry: TSearchPathEntry
    ): Boolean;
    function SearchRootsSummary: string;
    function CandidateSummary(const ACandidates: TStringArray): string;
    function ResolveUnitOrigin(const ASourcePath: string): TResolvedUnitOrigin;
    function EnsureRuntimeUnit: TResolvedUnit;
    function FindIndexedEntry(
      const ARootIndex: LongInt;
      const AUnitId: string
    ): LongInt;
    function FindCandidatePaths(const ARequestedName: string): TStringArray;
    function FindCandidatePathsInRoot(
      const ARootIndex: LongInt;
      const ARequestedUnitId: string
    ): TStringArray;
    procedure InitializeRootIndexes;
    procedure EnsureRootIndex(const ARootIndex: LongInt);
    function ResolveDependency(
      const ASourceUnitId: string;
      const ARequestedName: string;
      const AEdgeKind: TUnitGraphEdgeKind;
      const ARequestFileId: TSourceFileId
    ): Boolean;
    function ResolveDependencyList(
      const ASourceUnitId: string;
      const AOwnerFileId: TSourceFileId;
      const AFacade: TAstFacade;
      const AEdgeKind: TUnitGraphEdgeKind
    ): Boolean;
    procedure BuildSearchPaths;
  public
    constructor Create(
      const ASourceDatabase: TSourceDatabase;
      const ATargetFacts: TTargetFactsView;
      const ADiagnostics: TDiagnosticsSink;
      const ARootFileId: TSourceFileId;
      const AProjectUnitRootInfos: TProjectUnitRootInfoArray;
      const AExplicitUnitRoots: TStringArray
    );
    destructor Destroy; override;
    function CandidateCountFor(const ARequestedName: string): LongInt;
    function IndexedRootCount: LongInt;
    function SearchIndexScanCount: LongInt;
    function SearchIndexStatus: string;
    function SearchIndexLastScanTimestamp: Int64;
    procedure ResolveRoot(const ARootAst: TAstFacade);
    function ResolutionStatus: string;
    function DetachSearchPaths: TSearchPathSet;
    function DetachUnitGraph: TUnitGraph;
    property SearchPaths: TSearchPathSet read FSearchPaths;
    property UnitGraph: TUnitGraph read FUnitGraph;
  end;

implementation

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

procedure TUnitResolver.PushResolutionStack(const AUnitId: string);
begin
  AppendString(FResolutionStack, AUnitId);
end;

procedure TUnitResolver.PopResolutionStack;
begin
  if Length(FResolutionStack) = 0 then
    Exit;

  SetLength(FResolutionStack, Length(FResolutionStack) - 1);
end;

function TUnitResolver.StackContains(const AUnitId: string): Boolean;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FResolutionStack) - 1 do
    if FResolutionStack[Index] = AUnitId then
      Exit(True);

  Result := False;
end;

function TUnitResolver.BuildCyclePath(const AUnitId: string): string;
var
  Index: LongInt;
  StartIndex: LongInt;
begin
  StartIndex := 0;
  for Index := 0 to Length(FResolutionStack) - 1 do
    if FResolutionStack[Index] = AUnitId then
    begin
      StartIndex := Index;
      Break;
    end;

  Result := '';
  for Index := StartIndex to Length(FResolutionStack) - 1 do
  begin
    if Result <> '' then
      Result := Result + ' -> ';
    Result := Result + FResolutionStack[Index];
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
      if not FileExists(RuntimeSystemPath) then
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
  SearchRec: TSearchRec;
  UnitId: string;
begin
  if (ARootIndex < 0) or (ARootIndex >= Length(FRootIndexes)) then
    Exit;
  if FRootIndexes[ARootIndex].Status = 'ready' then
    Exit;

  FRootIndexes[ARootIndex].RootPath := FSearchPaths.RootPathAt(ARootIndex);
  SetLength(FRootIndexes[ARootIndex].Entries, 0);
  Inc(FRootIndexes[ARootIndex].ScanCount);

  if FindFirst(
    IncludeTrailingPathDelimiter(FRootIndexes[ARootIndex].RootPath) + '*.pas',
    faAnyFile,
    SearchRec
  ) = 0 then
  begin
    try
      repeat
        if (SearchRec.Attr and faDirectory) <> 0 then
          Continue;

        UnitId := NormalizeUnitIdentity(ChangeFileExt(SearchRec.Name, ''));
        if UnitId = '' then
          Continue;

        CandidatePath := NormalizeCorePath(
          IncludeTrailingPathDelimiter(FRootIndexes[ARootIndex].RootPath) +
            SearchRec.Name
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
      until FindNext(SearchRec) <> 0;
    finally
      FindClose(SearchRec);
    end;
  end;

  FRootIndexes[ARootIndex].Status := 'ready';
  FRootIndexes[ARootIndex].LastScanTimestamp := Round(Now * 86400);
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

function TUnitResolver.ResolveDependency(
  const ASourceUnitId: string;
  const ARequestedName: string;
  const AEdgeKind: TUnitGraphEdgeKind;
  const ARequestFileId: TSourceFileId
): Boolean;
var
  RequestedUnitId: string;
  Candidates: TStringArray;
  ResolvedUnit: TResolvedUnit;
  HasExistingUnit: Boolean;
  DependencyFileId: TSourceFileId;
  DependencyLexer: TLexerResult;
  DependencyGreenTree: TGreenTree;
  DependencyAst: TAstFacade;
  DependencyName: string;
begin
  Result := False;
  RequestedUnitId := NormalizeUnitIdentity(ARequestedName);
  if RequestedUnitId = '' then
    Exit(True);

  if StackContains(RequestedUnitId) then
  begin
    EmitResolutionError(
      'resolver.unit-cycle-detected',
      ARequestFileId,
      'unit cycle detected: ' + BuildCyclePath(RequestedUnitId)
    );
    Exit;
  end;

  HasExistingUnit := FUnitGraph.FindUnit(RequestedUnitId, ResolvedUnit);
  if HasExistingUnit and
    ((ResolvedUnit.SourcePath <> '') or (RequestedUnitId <> 'system')) and
    (not ((RequestedUnitId = 'system') and
      SameText(ResolvedUnit.OriginClass, 'implicit-runtime'))) then
  begin
    FUnitGraph.AddEdge(AEdgeKind, ASourceUnitId, ResolvedUnit.UnitId);
    Exit(True);
  end;

  Candidates := FindCandidatePaths(ARequestedName);
  if HasExistingUnit and (RequestedUnitId = 'system') and (Length(Candidates) = 0) then
  begin
    FUnitGraph.AddEdge(AEdgeKind, ASourceUnitId, ResolvedUnit.UnitId);
    Exit(True);
  end;
  if Length(Candidates) = 0 then
  begin
    EmitResolutionError(
      'resolver.unit-not-found',
      ARequestFileId,
      'unit "' + ARequestedName + '" not found; searched roots: ' + SearchRootsSummary
    );
    Exit;
  end;

  if Length(Candidates) > 1 then
  begin
    EmitResolutionError(
      'resolver.ambiguous-unit-source',
      ARequestFileId,
      'unit "' + ARequestedName + '" resolved to multiple sources: ' +
        CandidateSummary(Candidates)
    );
    Exit;
  end;

  DependencyFileId := FSourceDatabase.RegisterSource(Candidates[0]);
  DependencyLexer := TLexerResult.Create(
    FSourceDatabase.SourceTextForFileId(DependencyFileId)
  );
  DependencyGreenTree := ParseGreenTree(
    DependencyLexer,
    FDiagnostics,
    DependencyFileId
  );
  DependencyAst := TAstFacade.Create(DependencyGreenTree);
  try
    if FDiagnostics.HasErrors or not DependencyAst.IsValid then
    begin
      FResolutionStatus := 'failure';
      FUnitGraph.MarkFailure;
      Exit;
    end;

    DependencyName := DependencyAst.DeclaredName;
    if DependencyName = '' then
      DependencyName := ARequestedName;
    if NormalizeUnitIdentity(DependencyName) <> RequestedUnitId then
    begin
      EmitResolutionError(
        'resolver.unit-name-mismatch',
        ARequestFileId,
        'unit "' + ARequestedName + '" resolved to "' + Candidates[0] +
          '" but declares "' + DependencyName + '"'
      );
      Exit;
    end;

    ResolvedUnit := BuildResolvedUnit(
      DependencyName,
      Candidates[0],
      ResolveUnitOrigin(Candidates[0]),
      FTargetFacts.TargetId,
      DependencyAst.RootKindName,
      DependencyFileId
    );
    FUnitGraph.AddResolvedUnit(ResolvedUnit);
    FUnitGraph.AddEdge(AEdgeKind, ASourceUnitId, ResolvedUnit.UnitId);

    PushResolutionStack(ResolvedUnit.UnitId);
    try
      if not ResolveDependencyList(
        ResolvedUnit.UnitId,
        DependencyFileId,
        DependencyAst,
        ugeInterfaceUse
      ) then
        Exit;
      if not ResolveDependencyList(
        ResolvedUnit.UnitId,
        DependencyFileId,
        DependencyAst,
        ugeImplementationUse
      ) then
        Exit;
    finally
      PopResolutionStack;
    end;
  finally
    DependencyAst.Free;
    DependencyGreenTree.Free;
    DependencyLexer.Free;
  end;

  Result := not FDiagnostics.HasErrors;
end;

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
  for Index := 0 to Length(FProjectUnitRootInfos) - 1 do
    FSearchPaths.AddRoot(
      FProjectUnitRootInfos[Index].RootPath,
      FProjectUnitRootInfos[Index].ScopeName,
      FProjectUnitRootInfos[Index].ProvenanceKind,
      FProjectUnitRootInfos[Index].PackageName,
      FProjectUnitRootInfos[Index].ManifestPath,
      FProjectUnitRootInfos[Index].WorkspaceMemberPath
    );
  for Index := 0 to Length(FExplicitUnitRoots) - 1 do
    FSearchPaths.AddRoot(FExplicitUnitRoots[Index], 'explicit-unit-root');
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
  for Index := 0 to Length(FRootIndexes) - 1 do
    if FRootIndexes[Index].Status = 'ready' then
      Inc(Result);
end;

function TUnitResolver.SearchIndexScanCount: LongInt;
var
  Index: LongInt;
begin
  Result := 0;
  for Index := 0 to Length(FRootIndexes) - 1 do
    Inc(Result, FRootIndexes[Index].ScanCount);
end;

function TUnitResolver.SearchIndexStatus: string;
begin
  if Length(FRootIndexes) = 0 then
    Exit('empty');
  if IndexedRootCount = 0 then
    Exit('deferred');
  if IndexedRootCount = Length(FRootIndexes) then
    Exit('ready');

  Result := 'partial';
end;

function TUnitResolver.SearchIndexLastScanTimestamp: Int64;
var
  Index: LongInt;
begin
  Result := 0;
  for Index := 0 to Length(FRootIndexes) - 1 do
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

  PushResolutionStack(RootUnit.UnitId);
  try
    if (ARootAst.RootKindName = 'program') or
      (ARootAst.RootKindName = 'library') or
      (ARootAst.RootKindName = 'package') then
    begin
      RuntimeUnit := EnsureRuntimeUnit;
      FUnitGraph.AddEdge(ugeImplicitRuntime, RootUnit.UnitId, RuntimeUnit.UnitId);
    end;

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
