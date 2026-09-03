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
  nextpas.compiler.syntax.ast_facade, nextpas.compiler.diagnostics.sink, nextpas.compiler.syntax.green_tree, nextpas.compiler.syntax.lexer,
  nextpas.compiler.frontend.package_manifest, nextpas.compiler.syntax.preprocessor, nextpas.compiler.frontend.source_database,
  nextpas.compiler.targets.facts, np_text_primitives, nextpas.compiler.toolchain.profiles, nextpas.compiler.frontend.unit_graph;

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

{$I np_unit_resolver_helpers.inc}

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

  procedure EnsureStrArrayCapacity(var AArr: TStringArray; var ACap: SizeUInt; const ARequired: SizeUInt);
  var
    LNewCap: SizeUInt;
  begin
    if ARequired <= ACap then
      Exit;
    LNewCap := ACap;
    if LNewCap < 4 then
      LNewCap := 4;
    while LNewCap < ARequired do
    begin
      if LNewCap <= High(SizeUInt) div 2 then
        LNewCap := LNewCap * 2
      else
      begin
        LNewCap := ARequired;
        Break;
      end;
    end;
    SetLength(AArr, LNewCap);
    ACap := LNewCap;
  end;

  procedure AppendUse(var AUses: TStringArray; var ACap: SizeUInt; var ACount: SizeUInt; const AName: string);
  begin
    if AName = '' then
      Exit;
    EnsureStrArrayCapacity(AUses, ACap, ACount + 1);
    AUses[ACount] := AName;
    Inc(ACount);
  end;

  function ParseUsesList(var ACursor: LongInt; var AUses: TStringArray; var ACap: SizeUInt; var ACount: SizeUInt): Boolean;
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
      AppendUse(AUses, ACap, ACount, UseName);
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
  InterfaceCap: SizeUInt;
  ImplementationCap: SizeUInt;
  InterfaceCount: SizeUInt;
  ImplementationCount: SizeUInt;
begin
  ADeclaredName := '';
  ARootKindName := 'unknown';
  SetLength(AInterfaceUses, 0);
  SetLength(AImplementationUses, 0);
  InterfaceCap := 0;
  ImplementationCap := 0;
  InterfaceCount := 0;
  ImplementationCount := 0;
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
          if not ParseUsesList(Cursor, AInterfaceUses, InterfaceCap, InterfaceCount) then
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
          if not ParseUsesList(Cursor, AImplementationUses, ImplementationCap, ImplementationCount) then
            Exit(False);
        end;
      end;
    tkProgramKeyword, tkLibraryKeyword:
      begin
        if not ParseUsesList(Cursor, AInterfaceUses, InterfaceCap, InterfaceCount) then
          Exit(False);
      end;
    tkPackageKeyword:
      begin
        { package requires/contains — not needed for stage0 unit graph edges. }
      end;
  end;
  { Trim geometric over-allocation to logical count (zero-copy final SetLength). }
  SetLength(AInterfaceUses, InterfaceCount);
  SetLength(AImplementationUses, ImplementationCount);
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

{$I np_unit_resolver_resolution.inc}
