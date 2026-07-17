unit np_unit_resolver;

{$mode objfpc}{$H+}
{$UNITPATH .}
{$UNITPATH ../diagnostics}
{$UNITPATH ../syntax}
{$UNITPATH ../targets}
{$UNITPATH ../../rtl/core/text}

interface

uses
  nextpas.core.text, nextpas.core.text.conv, nextpas.core.path,
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

{$I np_unit_resolver_helpers.inc}
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
  DependencyGreenTree: TGreenTree;
  DependencyAst: TAstFacade;
  DependencyName: string;
  ExistingStackIndex: LongInt;
begin
  Result := False;
  RequestedUnitId := NormalizeUnitIdentity(ARequestedName);
  if RequestedUnitId = '' then
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
      nextpas.core.text.SameText(ResolvedUnit.OriginClass, 'implicit-runtime'))) then
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
  DependencyDiag := TDiagnosticsSink.Create;
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
  DependencyPP := TPreprocessor.Create(DependencyDefines, True, DependencyIncResolver,
    FNodeAllocator);
  try
    DependencyPP.Process(DependencyLexer);
    DependencyLexer.Free;
    DependencyLexer := DependencyPP.ToLexerResult;
  finally
    DependencyPP.Free;
  end;
  DependencyGreenTree := ParseGreenTree(
    DependencyLexer,
    DependencyDiag,
    DependencyFileId,
    FNodeAllocator
  );
  DependencyAst := TAstFacade.Create(DependencyGreenTree);
  try
    if (DependencyGreenTree = nil) or (DependencyGreenTree.RootNode = nil) then
    begin
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
    EnsureImplicitRuntimeDependency(ResolvedUnit.UnitId);

    PushResolutionStack(ResolvedUnit.UnitId, AEdgeKind);
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
    DependencyDiag.Free;
  end;

  Result := True;
end;

{$I np_unit_resolver_resolution.inc}
