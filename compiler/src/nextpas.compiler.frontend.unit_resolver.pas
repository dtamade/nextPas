unit nextpas.compiler.frontend.unit_resolver;

{$mode objfpc}{$H+}
{$UNITPATH .}
{$UNITPATH ../diagnostics}
{$UNITPATH ../syntax}
{$UNITPATH ../targets}
{$UNITPATH ../../rtl/core/text}

interface

uses
  { SameText via text.conv — do not pull nextpas.core.text unicode facade. }
  nextpas.core.text.conv, nextpas.core.path,
  nextpas.core.fs.util, nextpas.core.fs.dir, nextpas.core.fs.base,
  nextpas.core.time, nextpas.core.mem.intf,
  nextpas.core.collections.vec,
  np_ast_facade, np_diagnostics_sink, np_green_tree, np_lexer,
  np_package_manifest, np_preprocessor, np_source_database,
  np_target_facts, np_text_primitives, np_toolchain_profiles, np_unit_graph;

type
  TUnitResolverStringVec = specialize TVec<string>;
  TProjectUnitRootInfoVec = specialize TVec<TProjectUnitRootInfo>;

  TSearchIndexEntry = record
    UnitId: string;
    { Nested product table owned by the search-index entry (phase FNodeAllocator
      when provided, else default heap). Free in FreeRootIndexEntries / Clear. }
    CandidatePaths: TUnitResolverStringVec;
  end;
  PSearchIndexEntry = ^TSearchIndexEntry;

  TSearchIndexEntryVec = specialize TVec<TSearchIndexEntry>;

  TResolutionStackEntry = record
    UnitId: string;
    EnteredBy: TUnitGraphEdgeKind;
  end;

  TResolutionStackVec = specialize TVec<TResolutionStackEntry>;

  TRootSearchIndex = record
    RootPath: string;
    Status: string;
    Entries: TSearchIndexEntryVec;
    ScanCount: LongInt;
    LastScanTimestamp: Int64;
  end;

  TRootSearchIndexVec = specialize TVec<TRootSearchIndex>;

  TUnitResolver = class
  private
    FSourceDatabase: TSourceDatabase;
    FDiagnostics: TDiagnosticsSink;
    FTargetFacts: TTargetFactsView;
    FSearchPaths: TSearchPathSet;
    FUnitGraph: TUnitGraph;
    FRootFileId: TSourceFileId;
    FResolutionStatus: string;
    FResolutionStack: TResolutionStackVec;
    FProjectUnitRootInfos: TProjectUnitRootInfoVec;
    FExplicitUnitRoots: TUnitResolverStringVec;
    FRootIndexes: TRootSearchIndexVec;
    { Optional node storage for dependency ParseGreenTree (session scratch). }
    FNodeAllocator: IAllocator;
    procedure FreeRootIndexEntries;
    procedure EmitResolutionError(
      const ACode: string;
      const AFileId: TSourceFileId;
      const AMessage: string
    );
    procedure PushResolutionStack(
      const AUnitId: string;
      const AEnteredBy: TUnitGraphEdgeKind
    );
    procedure PopResolutionStack;
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
    procedure EnsureImplicitRuntimeDependency(const ASourceUnitId: string);
    function StackIndexOf(const AUnitId: string): LongInt;
    function FindIndexedEntry(
      const ARootIndex: LongInt;
      const AUnitId: string
    ): LongInt;
    function StackPathHasImplementationBoundary(
      const AStartIndex: LongInt
    ): Boolean;
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
    function ResolveDependencyListFromNames(
      const ASourceUnitId: string;
      const AOwnerFileId: TSourceFileId;
      const ANames: TStringArray;
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
      const AExplicitUnitRoots: TStringArray;
      const ANodeAllocator: IAllocator = nil
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

{--- inlined np_unit_resolver_helpers.inc ---}
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


{--- end ---}

{ Lightweight unit-header scan for resolution:
  only root kind + declared name + interface/implementation uses.
  Avoids full green-tree parse + free (pathological on large mem facades). }
function ExtractUnitClosureHeader(
  const ALexer: TLexerResult;
  out ADeclaredName: string;
  out ARootKindName: string;
  out AInterfaceUses: TStringArray;
  out AImplementationUses: TStringArray
): Boolean;

  procedure SkipTrivia(var ACursor: LongInt);
  begin
    while ACursor < ALexer.TokenCount do
    begin
      case ALexer.TokenAt(ACursor).Kind of
        tkCompilerDirective:
          Inc(ACursor);
      else
        Break;
      end;
    end;
  end;

  function Tok(const ACursor: LongInt): TTokenKind;
  begin
    if (ACursor < 0) or (ACursor >= ALexer.TokenCount) then
      Exit(tkEOF);
    Result := ALexer.TokenAt(ACursor).Kind;
  end;

  function IsPathSegmentToken(const AKind: TTokenKind): Boolean;
  begin
    { Unit path segments may be keyword-like (virtual/platform/static/…).
      Accept any keyword-ish token that still carries an identifier lexeme —
      broader than green-tree IsMethodNameToken to avoid truncating paths. }
    Result := (AKind = tkIdentifier) or
      (AKind = tkContainsKeyword) or (AKind = tkRequiresKeyword) or
      (AKind = tkNameKeyword) or (AKind = tkMessageKeyword) or
      (AKind = tkStringKeyword) or (AKind = tkFileKeyword) or
      (AKind = tkOnKeyword) or (AKind = tkIsKeyword) or
      (AKind = tkAsKeyword) or (AKind = tkInKeyword) or
      (AKind = tkToKeyword) or (AKind = tkOfKeyword) or
      (AKind = tkSelfKeyword) or (AKind = tkInlineKeyword) or
      (AKind = tkOverloadKeyword) or (AKind = tkVirtualKeyword) or
      (AKind = tkOverrideKeyword) or (AKind = tkAbstractKeyword) or
      (AKind = tkStaticKeyword) or (AKind = tkDynamicKeyword) or
      (AKind = tkReintroduceKeyword) or (AKind = tkDeprecatedKeyword) or
      (AKind = tkPlatformKeyword) or (AKind = tkExperimentalKeyword) or
      (AKind = tkForwardKeyword) or
      (AKind = tkExportsKeyword) or (AKind = tkObjectKeyword) or
      (AKind = tkClassKeyword) or (AKind = tkRecordKeyword) or
      (AKind = tkSetKeyword) or (AKind = tkArrayKeyword) or
      (AKind = tkTypeKeyword) or (AKind = tkConstKeyword) or
      (AKind = tkVarKeyword) or (AKind = tkThreadVarKeyword) or
      (AKind = tkUnitKeyword) or (AKind = tkProgramKeyword) or
      (AKind = tkLibraryKeyword) or (AKind = tkPackageKeyword) or
      (AKind = tkInterfaceKeyword) or (AKind = tkImplementationKeyword) or
      (AKind = tkPropertyKeyword) or (AKind = tkLabelKeyword);
  end;

  function ConsumePath(var ACursor: LongInt; out AName: string): Boolean;
  begin
    AName := '';
    SkipTrivia(ACursor);
    if not IsPathSegmentToken(Tok(ACursor)) then
      Exit(False);
    AName := ALexer.TokenAt(ACursor).Lexeme;
    Inc(ACursor);
    while True do
    begin
      SkipTrivia(ACursor);
      if Tok(ACursor) <> tkDot then
        Break;
      if not IsPathSegmentToken(Tok(ACursor + 1)) then
        Break;
      Inc(ACursor); { dot }
      SkipTrivia(ACursor);
      AName := AName + '.' + ALexer.TokenAt(ACursor).Lexeme;
      Inc(ACursor);
    end;
    Result := True;
  end;

  procedure SkipInClause(var ACursor: LongInt);
  begin
    SkipTrivia(ACursor);
    if Tok(ACursor) <> tkInKeyword then
      Exit;
    Inc(ACursor);
    SkipTrivia(ACursor);
    if Tok(ACursor) = tkStringLiteral then
      Inc(ACursor);
  end;

  procedure AppendUse(var AUses: TStringArray; const AName: string);
  begin
    if AName = '' then
      Exit;
    SetLength(AUses, Length(AUses) + 1);
    AUses[High(AUses)] := AName;
  end;

  function ParseUsesList(var ACursor: LongInt; var AUses: TStringArray): Boolean;
  var
    UseName: string;
  begin
    Result := True;
    SkipTrivia(ACursor);
    if Tok(ACursor) <> tkUsesKeyword then
      Exit(True);
    Inc(ACursor);
    while True do
    begin
      SkipTrivia(ACursor);
      if Tok(ACursor) = tkSemicolon then
      begin
        Inc(ACursor);
        Exit(True);
      end;
      if not ConsumePath(ACursor, UseName) then
        Exit(False);
      AppendUse(AUses, UseName);
      SkipInClause(ACursor);
      SkipTrivia(ACursor);
      if Tok(ACursor) = tkComma then
      begin
        Inc(ACursor);
        Continue;
      end;
      if Tok(ACursor) = tkSemicolon then
      begin
        Inc(ACursor);
        Exit(True);
      end;
      { FPC leniency: missing semicolon before type/const/var/... }
      Exit(True);
    end;
  end;

var
  Cursor: LongInt;
  Kind: TTokenKind;
  Dummy: string;
begin
  ADeclaredName := '';
  ARootKindName := 'unknown';
  SetLength(AInterfaceUses, 0);
  SetLength(AImplementationUses, 0);
  Result := False;
  Cursor := 0;
  SkipTrivia(Cursor);
  Kind := Tok(Cursor);
  case Kind of
    tkUnitKeyword: ARootKindName := 'unit';
    tkProgramKeyword: ARootKindName := 'program';
    tkLibraryKeyword: ARootKindName := 'library';
    tkPackageKeyword: ARootKindName := 'package';
  else
    Exit(False);
  end;
  Inc(Cursor);
  if not ConsumePath(Cursor, ADeclaredName) then
    Exit(False);
  SkipTrivia(Cursor);
  if Tok(Cursor) = tkSemicolon then
    Inc(Cursor);

  case Kind of
    tkUnitKeyword:
      begin
        SkipTrivia(Cursor);
        if Tok(Cursor) = tkInterfaceKeyword then
        begin
          Inc(Cursor);
          if not ParseUsesList(Cursor, AInterfaceUses) then
            Exit(False);
        end;
        { Skip interface body until implementation (token scan, no parse). }
        while Cursor < ALexer.TokenCount do
        begin
          SkipTrivia(Cursor);
          if Tok(Cursor) = tkImplementationKeyword then
            Break;
          if Tok(Cursor) = tkEOF then
            Break;
          Inc(Cursor);
        end;
        if Tok(Cursor) = tkImplementationKeyword then
        begin
          Inc(Cursor);
          if not ParseUsesList(Cursor, AImplementationUses) then
            Exit(False);
        end;
      end;
    tkProgramKeyword, tkLibraryKeyword:
      begin
        if not ParseUsesList(Cursor, AInterfaceUses) then
          Exit(False);
      end;
    tkPackageKeyword:
      begin
        { package requires/contains — not needed for stage0 unit graph edges. }
      end;
  end;
  Dummy := '';
  Result := ADeclaredName <> '';
end;

function TUnitResolver.ResolveDependencyListFromNames(
  const ASourceUnitId: string;
  const AOwnerFileId: TSourceFileId;
  const ANames: TStringArray;
  const AEdgeKind: TUnitGraphEdgeKind
): Boolean;
var
  Index: LongInt;
  AnyFailure: Boolean;
begin
  AnyFailure := False;
  for Index := 0 to Length(ANames) - 1 do
    if not ResolveDependency(ASourceUnitId, ANames[Index], AEdgeKind, AOwnerFileId) then
      AnyFailure := True;
  Result := not AnyFailure;
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
  DependencyDiag: TDiagnosticsSink;
  DependencyLexer: TLexerResult;
  DependencyDefines: TDefineTable;
  DependencyIncResolver: TFileIncludeResolver;
  DependencyPP: TPreprocessor;
  DependencyName: string;
  RootKindName: string;
  InterfaceUses: TStringArray;
  ImplementationUses: TStringArray;
  ExistingStackIndex: LongInt;
  HeaderOk: Boolean;
begin
  Result := False;
  RequestedUnitId := NormalizeUnitIdentity(ARequestedName);
  if RequestedUnitId = '' then
    Exit(True);

  { Self-use is a no-op (malformed or truncated header scan must not hard-cycle). }
  if RequestedUnitId = NormalizeUnitIdentity(ASourceUnitId) then
    Exit(True);

  ExistingStackIndex := StackIndexOf(RequestedUnitId);
  if ExistingStackIndex >= 0 then
  begin
    if (AEdgeKind = ugeImplementationUse) or
      StackPathHasImplementationBoundary(ExistingStackIndex) then
    begin
      FUnitGraph.AddEdge(AEdgeKind, ASourceUnitId, RequestedUnitId);
      Exit(True);
    end;

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
      nextpas.core.text.conv.SameText(ResolvedUnit.OriginClass, 'implicit-runtime'))) then
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
  { CreateDefault initializes FDiagnostics; bare Create leaves garbage and AV on Free. }
  DependencyDiag := TDiagnosticsSink.CreateDefault;
  DependencyLexer := nil;
  DependencyDefines := nil;
  DependencyIncResolver := nil;
  DependencyPP := nil;
  try
    DependencyLexer := TLexerResult.Create(
      FSourceDatabase.SourceTextForFileId(DependencyFileId),
      DependencyDiag,
      DependencyFileId
    );
    DependencyDefines := TDefineTable.Create(FNodeAllocator);
    DependencyDefines.SeedFPCDefines;
    DependencyIncResolver := TFileIncludeResolver.Create(
      ExtractFileDir(Candidates[0]), FNodeAllocator);
    DependencyIncResolver.AddSearchPath(ExtractFileDir(Candidates[0]));
    DependencyIncResolver.AddSearchPath(
      ExtractFileDir(ExtractFileDir(Candidates[0])) + DirectorySeparator + 'objpas');
    DependencyIncResolver.AddSearchPath(
      ExtractFileDir(ExtractFileDir(Candidates[0])) + DirectorySeparator + 'objpas' +
      DirectorySeparator + 'sysutils');
    DependencyIncResolver.AddSearchPath(
      ExtractFileDir(ExtractFileDir(Candidates[0])) + DirectorySeparator + 'inc');
    { OwnsDefines=False: we free defines after PP so cleanup order is explicit. }
    DependencyPP := TPreprocessor.Create(
      DependencyDefines, False, DependencyIncResolver, FNodeAllocator);
    DependencyPP.Process(DependencyLexer);
    DependencyLexer.Free;
    DependencyLexer := DependencyPP.ToLexerResult;
    DependencyPP.Free;
    DependencyPP := nil;
    DependencyDefines.Free;
    DependencyDefines := nil;
    DependencyIncResolver := nil; { released via PP interface ref }

    HeaderOk := ExtractUnitClosureHeader(
      DependencyLexer,
      DependencyName,
      RootKindName,
      InterfaceUses,
      ImplementationUses
    );
    if not HeaderOk then
    begin
      EmitResolutionError(
        'resolver.unit-header-scan-failed',
        ARequestFileId,
        'unit "' + ARequestedName + '" header scan failed for "' + Candidates[0] + '"'
      );
      Exit;
    end;

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
      RootKindName,
      DependencyFileId
    );
    FUnitGraph.AddResolvedUnit(ResolvedUnit);
    FUnitGraph.AddEdge(AEdgeKind, ASourceUnitId, ResolvedUnit.UnitId);
    EnsureImplicitRuntimeDependency(ResolvedUnit.UnitId);

    PushResolutionStack(ResolvedUnit.UnitId, AEdgeKind);
    try
      if not ResolveDependencyListFromNames(
        ResolvedUnit.UnitId,
        DependencyFileId,
        InterfaceUses,
        ugeInterfaceUse
      ) then
        Exit;
      if not ResolveDependencyListFromNames(
        ResolvedUnit.UnitId,
        DependencyFileId,
        ImplementationUses,
        ugeImplementationUse
      ) then
        Exit;
    finally
      PopResolutionStack;
    end;
  finally
    DependencyPP.Free;
    DependencyDefines.Free;
    DependencyLexer.Free;
    DependencyDiag.Free;
  end;

  Result := True;
end;

{--- inlined np_unit_resolver_resolution.inc ---}
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

{--- end ---}
