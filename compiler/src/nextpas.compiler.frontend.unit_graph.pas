unit nextpas.compiler.frontend.unit_graph;

{$mode objfpc}{$H+}
{$UNITPATH .}
{$UNITPATH ../../rtl/core/text}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.core.mem.intf,
  nextpas.core.collections.vec,
  nextpas.core.text.conv, nextpas.compiler.frontend.source_database, np_text_primitives;

type
  TStringArray = array of string;

  TResolvedUnitOrigin = (
    ruoRootSource,
    ruoProjectSource,
    ruoInstalledSource,
    ruoImplicitRuntime
  );

  TUnitGraphEdgeKind = (
    ugeRootRequest,
    ugeInterfaceUse,
    ugeImplementationUse,
    ugeImplicitRuntime
  );

  TSearchPathEntry = record
    RootPath: string;
    ScopeName: string;
    ProvenanceKind: string;
    PackageName: string;
    ManifestPath: string;
    WorkspaceMemberPath: string;
  end;

  TResolvedUnit = record
    UnitId: string;
    CanonicalName: string;
    SourcePath: string;
    OriginClass: string;
    TargetAffinity: string;
    RootKind: string;
    FileId: TSourceFileId;
  end;

  TUnitGraphEdge = record
    Kind: TUnitGraphEdgeKind;
    SourceUnitId: string;
    TargetUnitId: string;
  end;

  TResolvedUnitVec = specialize TVec<TResolvedUnit>;
  TUnitGraphEdgeVec = specialize TVec<TUnitGraphEdge>;
  TUnitGraphLongIntVec = specialize TVec<LongInt>;
  TSearchPathEntryVec = specialize TVec<TSearchPathEntry>;

  TSearchPathSet = class
  private
    FAllocator: IAllocator;
    FEntries: TSearchPathEntryVec;
    function IndexOfRootPath(const ARootPath: string): LongInt;
  public
    { Optional AAllocator for entry TVec. Detach products use default (nil)
      so buffers outlive phase ResetScratchAllocator. }
    constructor Create(AAllocator: IAllocator = nil);
    destructor Destroy; override;
    procedure AddRoot(
      const ARootPath: string;
      const AScopeName: string;
      const AProvenanceKind: string = '';
      const APackageName: string = '';
      const AManifestPath: string = '';
      const AWorkspaceMemberPath: string = ''
    );
    function Count: LongInt;
    function EntryAt(const AIndex: LongInt): TSearchPathEntry;
    function RootPathAt(const AIndex: LongInt): string;
    function ScopeNameAt(const AIndex: LongInt): string;
  end;

  TUnitGraph = class
  private
    FAllocator: IAllocator;
    FResolvedUnits: TResolvedUnitVec;
    FEdges: TUnitGraphEdgeVec;
    FRootName: string;
    FStatus: string;
    function CreateLongIntVec: TUnitGraphLongIntVec;
    function IndexOfUnitId(const AUnitId: string): LongInt;
    function EdgeExists(
      const AKind: TUnitGraphEdgeKind;
      const ASourceUnitId: string;
      const ATargetUnitId: string
    ): Boolean;
  public
    { Optional AAllocator for units/edges/topo TVec. Detach products use default
      (nil) so buffers outlive phase ResetScratchAllocator. }
    constructor Create(AAllocator: IAllocator = nil);
    destructor Destroy; override;
    procedure AddResolvedUnit(const AUnit: TResolvedUnit);
    procedure AddEdge(
      const AKind: TUnitGraphEdgeKind;
      const ASourceUnitId: string;
      const ATargetUnitId: string
    );
    function HasUnit(const AUnitId: string): Boolean;
    function FindUnit(
      const AUnitId: string;
      out AUnit: TResolvedUnit
    ): Boolean;
    function ResolvedUnitCount: LongInt;
    function ResolvedUnitAt(const AIndex: LongInt): TResolvedUnit;
    function EdgeCount: LongInt;
    function EdgeAt(const AIndex: LongInt): TUnitGraphEdge;
    procedure SetRootName(const AName: string);
    function RootName: string;
    procedure MarkReady;
    procedure MarkFailure;
    function Status: string;
    function TopologicalInitOrder: TStringArray;
  end;

function NormalizeUnitIdentity(const AName: string): string;
function UnitOriginName(const AOrigin: TResolvedUnitOrigin): string;
function UnitGraphEdgeKindName(const AKind: TUnitGraphEdgeKind): string;
function BuildResolvedUnit(
  const ACanonicalName: string;
  const ASourcePath: string;
  const AOrigin: TResolvedUnitOrigin;
  const ATargetAffinity: string;
  const ARootKind: string;
  const AFileId: TSourceFileId
): TResolvedUnit;

implementation

function NormalizeUnitIdentity(const AName: string): string;
begin
  Result := NormalizeCoreIdentity(AName);
end;

function UnitOriginName(const AOrigin: TResolvedUnitOrigin): string;
begin
  case AOrigin of
    ruoRootSource:
      Result := 'root-source';
    ruoProjectSource:
      Result := 'project-source';
    ruoInstalledSource:
      Result := 'installed-source';
    ruoImplicitRuntime:
      Result := 'implicit-runtime';
  end;
end;

function UnitGraphEdgeKindName(const AKind: TUnitGraphEdgeKind): string;
begin
  case AKind of
    ugeRootRequest:
      Result := 'root-request';
    ugeInterfaceUse:
      Result := 'interface-use';
    ugeImplementationUse:
      Result := 'implementation-use';
    ugeImplicitRuntime:
      Result := 'implicit-runtime';
  end;
end;

function BuildResolvedUnit(
  const ACanonicalName: string;
  const ASourcePath: string;
  const AOrigin: TResolvedUnitOrigin;
  const ATargetAffinity: string;
  const ARootKind: string;
  const AFileId: TSourceFileId
): TResolvedUnit;
begin
  Result.UnitId := NormalizeUnitIdentity(ACanonicalName);
  Result.CanonicalName := ACanonicalName;
  Result.SourcePath := ASourcePath;
  Result.OriginClass := UnitOriginName(AOrigin);
  Result.TargetAffinity := ATargetAffinity;
  Result.RootKind := ARootKind;
  Result.FileId := AFileId;
end;

constructor TSearchPathSet.Create(AAllocator: IAllocator);
begin
  inherited Create;
  FAllocator := AAllocator;
  if FAllocator <> nil then
    FEntries := TSearchPathEntryVec.Create(0, FAllocator)
  else
    FEntries := TSearchPathEntryVec.Create;
end;

destructor TSearchPathSet.Destroy;
begin
  FEntries.Free;
  inherited Destroy;
end;

function TSearchPathSet.IndexOfRootPath(const ARootPath: string): LongInt;
var
  Index: LongInt;
begin
  for Index := 0 to LongInt(FEntries.Count) - 1 do
    if FEntries[Index].RootPath = ARootPath then
      Exit(Index);

  Result := -1;
end;

procedure TSearchPathSet.AddRoot(
  const ARootPath: string;
  const AScopeName: string;
  const AProvenanceKind: string;
  const APackageName: string;
  const AManifestPath: string;
  const AWorkspaceMemberPath: string
);
var
  CanonicalRootPath: string;
  Entry: TSearchPathEntry;
begin
  if Trim(ARootPath) = '' then
    Exit;

  CanonicalRootPath := NormalizeCorePath(ARootPath);
  if IndexOfRootPath(CanonicalRootPath) >= 0 then
    Exit;

  Entry.RootPath := CanonicalRootPath;
  Entry.ScopeName := AScopeName;
  if Trim(AProvenanceKind) <> '' then
    Entry.ProvenanceKind := AProvenanceKind
  else
    Entry.ProvenanceKind := AScopeName;
  Entry.PackageName := APackageName;
  if Trim(AManifestPath) <> '' then
    Entry.ManifestPath := NormalizeCorePath(AManifestPath)
  else
    Entry.ManifestPath := '';
  if Trim(AWorkspaceMemberPath) <> '' then
    Entry.WorkspaceMemberPath := NormalizeCorePath(AWorkspaceMemberPath)
  else
    Entry.WorkspaceMemberPath := '';
  FEntries.Push(Entry);
end;

function TSearchPathSet.Count: LongInt;
begin
  Result := LongInt(FEntries.Count);
end;

function TSearchPathSet.EntryAt(const AIndex: LongInt): TSearchPathEntry;
begin
  if (AIndex < 0) or (AIndex >= LongInt(FEntries.Count)) then
  begin
    Result.RootPath := '';
    Result.ScopeName := '';
    Result.ProvenanceKind := '';
    Result.PackageName := '';
    Result.ManifestPath := '';
    Result.WorkspaceMemberPath := '';
    Exit;
  end;

  Result := FEntries[AIndex];
end;

function TSearchPathSet.RootPathAt(const AIndex: LongInt): string;
begin
  Result := EntryAt(AIndex).RootPath;
end;

function TSearchPathSet.ScopeNameAt(const AIndex: LongInt): string;
begin
  Result := EntryAt(AIndex).ScopeName;
end;

constructor TUnitGraph.Create(AAllocator: IAllocator);
begin
  inherited Create;
  FAllocator := AAllocator;
  if FAllocator <> nil then
  begin
    FResolvedUnits := TResolvedUnitVec.Create(0, FAllocator);
    FEdges := TUnitGraphEdgeVec.Create(0, FAllocator);
  end
  else
  begin
    FResolvedUnits := TResolvedUnitVec.Create;
    FEdges := TUnitGraphEdgeVec.Create;
  end;
  FRootName := '';
  FStatus := 'deferred';
end;

destructor TUnitGraph.Destroy;
begin
  FEdges.Free;
  FResolvedUnits.Free;
  inherited Destroy;
end;

function TUnitGraph.CreateLongIntVec: TUnitGraphLongIntVec;
begin
  if FAllocator <> nil then
    Result := TUnitGraphLongIntVec.Create(0, FAllocator)
  else
    Result := TUnitGraphLongIntVec.Create;
end;

function TUnitGraph.IndexOfUnitId(const AUnitId: string): LongInt;
var
  Index: LongInt;
begin
  for Index := 0 to LongInt(FResolvedUnits.Count) - 1 do
    if FResolvedUnits[Index].UnitId = AUnitId then
      Exit(Index);

  Result := -1;
end;

function TUnitGraph.EdgeExists(
  const AKind: TUnitGraphEdgeKind;
  const ASourceUnitId: string;
  const ATargetUnitId: string
): Boolean;
var
  Index: LongInt;
begin
  for Index := 0 to LongInt(FEdges.Count) - 1 do
    if (FEdges[Index].Kind = AKind) and
      (FEdges[Index].SourceUnitId = ASourceUnitId) and
      (FEdges[Index].TargetUnitId = ATargetUnitId) then
      Exit(True);

  Result := False;
end;

procedure TUnitGraph.AddResolvedUnit(const AUnit: TResolvedUnit);
var
  ExistingIndex: LongInt;
  Existing: TResolvedUnit;
begin
  if AUnit.UnitId = '' then
    Exit;

  ExistingIndex := IndexOfUnitId(AUnit.UnitId);
  if ExistingIndex >= 0 then
  begin
    Existing := FResolvedUnits[ExistingIndex];
    if (Existing.SourcePath = '') and (AUnit.SourcePath <> '') then
      FResolvedUnits[ExistingIndex] := AUnit
    else if SameText(Existing.OriginClass, 'implicit-runtime') and
      (AUnit.SourcePath <> '') and
      (not SameText(AUnit.OriginClass, 'implicit-runtime')) then
      FResolvedUnits[ExistingIndex] := AUnit;
    Exit;
  end;

  FResolvedUnits.Push(AUnit);
end;

procedure TUnitGraph.AddEdge(
  const AKind: TUnitGraphEdgeKind;
  const ASourceUnitId: string;
  const ATargetUnitId: string
);
var
  Edge: TUnitGraphEdge;
begin
  if EdgeExists(AKind, ASourceUnitId, ATargetUnitId) then
    Exit;

  Edge.Kind := AKind;
  Edge.SourceUnitId := ASourceUnitId;
  Edge.TargetUnitId := ATargetUnitId;
  FEdges.Push(Edge);
end;

function TUnitGraph.HasUnit(const AUnitId: string): Boolean;
begin
  Result := IndexOfUnitId(AUnitId) >= 0;
end;

function TUnitGraph.FindUnit(
  const AUnitId: string;
  out AUnit: TResolvedUnit
): Boolean;
var
  UnitIndex: LongInt;
begin
  UnitIndex := IndexOfUnitId(AUnitId);
  Result := UnitIndex >= 0;
  if not Result then
    Exit;

  AUnit := FResolvedUnits[UnitIndex];
end;

function TUnitGraph.ResolvedUnitCount: LongInt;
begin
  Result := LongInt(FResolvedUnits.Count);
end;

function TUnitGraph.ResolvedUnitAt(const AIndex: LongInt): TResolvedUnit;
begin
  if (AIndex < 0) or (AIndex >= LongInt(FResolvedUnits.Count)) then
  begin
    Result.UnitId := '';
    Result.CanonicalName := '';
    Result.SourcePath := '';
    Result.OriginClass := '';
    Result.TargetAffinity := '';
    Result.RootKind := '';
    Result.FileId := 0;
    Exit;
  end;

  Result := FResolvedUnits[AIndex];
end;

function TUnitGraph.EdgeCount: LongInt;
begin
  Result := LongInt(FEdges.Count);
end;

function TUnitGraph.EdgeAt(const AIndex: LongInt): TUnitGraphEdge;
begin
  if (AIndex < 0) or (AIndex >= LongInt(FEdges.Count)) then
  begin
    Result.Kind := ugeRootRequest;
    Result.SourceUnitId := '';
    Result.TargetUnitId := '';
    Exit;
  end;
  Result := FEdges[AIndex];
end;

procedure TUnitGraph.SetRootName(const AName: string);
begin
  FRootName := AName;
end;

function TUnitGraph.RootName: string;
begin
  Result := FRootName;
end;

procedure TUnitGraph.MarkReady;
begin
  FStatus := 'ready';
end;

procedure TUnitGraph.MarkFailure;
begin
  FStatus := 'failure';
end;

function TUnitGraph.Status: string;
begin
  Result := FStatus;
end;

function TUnitGraph.TopologicalInitOrder: TStringArray;
var
  N, E, I, J, Front: LongInt;
  InDeg, Queue, Sorted: TUnitGraphLongIntVec;
  SrcIdx, TgtIdx: LongInt;
  SystemIdx: LongInt;
  Deg: LongInt;
begin
  Result := nil;
  N := LongInt(FResolvedUnits.Count);
  E := LongInt(FEdges.Count);

  if N = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  InDeg := CreateLongIntVec;
  Queue := CreateLongIntVec;
  Sorted := CreateLongIntVec;
  try
    // Build in-degree from ugeInterfaceUse and ugeImplementationUse edges.
    // An edge (Source -> Target) means Source depends on Target,
    // so Target must init before Source: Target's in-degree is unaffected,
    // but we increment in-degree of the dependant (Source).
    { Capacity only — Ensure() raises Count and would double after Push. }
    InDeg.EnsureCapacity(SizeUInt(N));
    for I := 0 to N - 1 do
      InDeg.PushUnchecked(0);

    for I := 0 to E - 1 do
    begin
      if (FEdges[I].Kind <> ugeInterfaceUse) and
         (FEdges[I].Kind <> ugeImplementationUse) then
        Continue;
      // SourceUnitId depends on TargetUnitId
      SrcIdx := IndexOfUnitId(FEdges[I].SourceUnitId);
      if SrcIdx < 0 then Continue;
      Deg := InDeg[SrcIdx];
      Inc(Deg);
      InDeg[SrcIdx] := Deg;
    end;

    // Kahn's algorithm: BFS from units with in-degree 0
    Queue.EnsureCapacity(SizeUInt(N));
    Sorted.EnsureCapacity(SizeUInt(N));
    Front := 0;

    for I := 0 to N - 1 do
      if InDeg[I] = 0 then
        Queue.PushUnchecked(I);

    while Front < LongInt(Queue.Count) do
    begin
      I := Queue[Front];
      Inc(Front);
      Sorted.PushUnchecked(I);

      // For all edges where I is the target (I must init before sources
      // that depend on it), decrease the source's in-degree
      for J := 0 to E - 1 do
      begin
        if (FEdges[J].Kind <> ugeInterfaceUse) and
           (FEdges[J].Kind <> ugeImplementationUse) then
          Continue;
        TgtIdx := IndexOfUnitId(FEdges[J].TargetUnitId);
        if TgtIdx <> I then Continue;
        SrcIdx := IndexOfUnitId(FEdges[J].SourceUnitId);
        if SrcIdx < 0 then Continue;
        Deg := InDeg[SrcIdx];
        Dec(Deg);
        InDeg[SrcIdx] := Deg;
        if Deg = 0 then
          Queue.PushUnchecked(SrcIdx);
      end;
    end;

    // If not all units were sorted, there is a cycle.
    // Report what we can; remaining units are appended in original order.
    if LongInt(Sorted.Count) < N then
    begin
      for I := 0 to N - 1 do
        if InDeg[I] > 0 then
          Sorted.PushUnchecked(I);
    end;

    // Convert indices to canonical names
    SetLength(Result, LongInt(Sorted.Count));
    for I := 0 to LongInt(Sorted.Count) - 1 do
      Result[I] := FResolvedUnits[Sorted[I]].CanonicalName;
  finally
    Sorted.Free;
    Queue.Free;
    InDeg.Free;
  end;

  // Ensure System unit is first if present
  SystemIdx := -1;
  for I := 0 to High(Result) do
    if SameText(Result[I], 'system') then
    begin
      SystemIdx := I;
      Break;
    end;
  if SystemIdx > 0 then
  begin
    // Swap System to front
    Result[SystemIdx] := Result[0];
    Result[0] := 'system';
  end;
end;

end.
