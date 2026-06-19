unit np_unit_graph;

{$mode objfpc}{$H+}
{$UNITPATH .}
{$UNITPATH ../../rtl/core/text}

interface

uses
  nextpas.core.text.conv, np_source_database, np_text_primitives;

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

  TSearchPathSet = class
  private
    FEntries: array of TSearchPathEntry;
    function IndexOfRootPath(const ARootPath: string): LongInt;
  public
    constructor Create;
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
    FResolvedUnits: array of TResolvedUnit;
    FEdges: array of TUnitGraphEdge;
    FRootName: string;
    FStatus: string;
    function IndexOfUnitId(const AUnitId: string): LongInt;
    function EdgeExists(
      const AKind: TUnitGraphEdgeKind;
      const ASourceUnitId: string;
      const ATargetUnitId: string
    ): Boolean;
  public
    constructor Create;
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

constructor TSearchPathSet.Create;
begin
  inherited Create;
  SetLength(FEntries, 0);
end;

function TSearchPathSet.IndexOfRootPath(const ARootPath: string): LongInt;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FEntries) - 1 do
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
  NextIndex: SizeInt;
begin
  if Trim(ARootPath) = '' then
    Exit;

  CanonicalRootPath := NormalizeCorePath(ARootPath);
  if IndexOfRootPath(CanonicalRootPath) >= 0 then
    Exit;

  NextIndex := Length(FEntries);
  SetLength(FEntries, NextIndex + 1);
  FEntries[NextIndex].RootPath := CanonicalRootPath;
  FEntries[NextIndex].ScopeName := AScopeName;
  if Trim(AProvenanceKind) <> '' then
    FEntries[NextIndex].ProvenanceKind := AProvenanceKind
  else
    FEntries[NextIndex].ProvenanceKind := AScopeName;
  FEntries[NextIndex].PackageName := APackageName;
  if Trim(AManifestPath) <> '' then
    FEntries[NextIndex].ManifestPath := NormalizeCorePath(AManifestPath)
  else
    FEntries[NextIndex].ManifestPath := '';
  if Trim(AWorkspaceMemberPath) <> '' then
    FEntries[NextIndex].WorkspaceMemberPath := NormalizeCorePath(AWorkspaceMemberPath)
  else
    FEntries[NextIndex].WorkspaceMemberPath := '';
end;

function TSearchPathSet.Count: LongInt;
begin
  Result := Length(FEntries);
end;

function TSearchPathSet.EntryAt(const AIndex: LongInt): TSearchPathEntry;
begin
  if (AIndex < 0) or (AIndex >= Length(FEntries)) then
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

constructor TUnitGraph.Create;
begin
  inherited Create;
  SetLength(FResolvedUnits, 0);
  SetLength(FEdges, 0);
  FRootName := '';
  FStatus := 'deferred';
end;

function TUnitGraph.IndexOfUnitId(const AUnitId: string): LongInt;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FResolvedUnits) - 1 do
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
  for Index := 0 to Length(FEdges) - 1 do
    if (FEdges[Index].Kind = AKind) and
      (FEdges[Index].SourceUnitId = ASourceUnitId) and
      (FEdges[Index].TargetUnitId = ATargetUnitId) then
      Exit(True);

  Result := False;
end;

procedure TUnitGraph.AddResolvedUnit(const AUnit: TResolvedUnit);
var
  ExistingIndex: LongInt;
  NextIndex: SizeInt;
begin
  if AUnit.UnitId = '' then
    Exit;

  ExistingIndex := IndexOfUnitId(AUnit.UnitId);
  if ExistingIndex >= 0 then
  begin
    if (FResolvedUnits[ExistingIndex].SourcePath = '') and (AUnit.SourcePath <> '') then
      FResolvedUnits[ExistingIndex] := AUnit
    else if SameText(FResolvedUnits[ExistingIndex].OriginClass, 'implicit-runtime') and
      (AUnit.SourcePath <> '') and
      (not SameText(AUnit.OriginClass, 'implicit-runtime')) then
      FResolvedUnits[ExistingIndex] := AUnit;
    Exit;
  end;

  NextIndex := Length(FResolvedUnits);
  SetLength(FResolvedUnits, NextIndex + 1);
  FResolvedUnits[NextIndex] := AUnit;
end;

procedure TUnitGraph.AddEdge(
  const AKind: TUnitGraphEdgeKind;
  const ASourceUnitId: string;
  const ATargetUnitId: string
);
var
  NextIndex: SizeInt;
begin
  if EdgeExists(AKind, ASourceUnitId, ATargetUnitId) then
    Exit;

  NextIndex := Length(FEdges);
  SetLength(FEdges, NextIndex + 1);
  FEdges[NextIndex].Kind := AKind;
  FEdges[NextIndex].SourceUnitId := ASourceUnitId;
  FEdges[NextIndex].TargetUnitId := ATargetUnitId;
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
  Result := Length(FResolvedUnits);
end;

function TUnitGraph.ResolvedUnitAt(const AIndex: LongInt): TResolvedUnit;
begin
  if (AIndex < 0) or (AIndex >= Length(FResolvedUnits)) then
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
  Result := Length(FEdges);
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
  N, E, I, J, Front, Rear: LongInt;
  InDeg: array of LongInt;
  Queue: array of LongInt;
  Sorted: array of LongInt;
  SortedCount: LongInt;
  SrcIdx, TgtIdx: LongInt;
  SystemIdx: LongInt;
begin
  N := Length(FResolvedUnits);
  E := Length(FEdges);

  if N = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  // Build in-degree from ugeInterfaceUse and ugeImplementationUse edges.
  // An edge (Source -> Target) means Source depends on Target,
  // so Target must init before Source: Target's in-degree is unaffected,
  // but we increment in-degree of the dependant (Source).
  SetLength(InDeg, N);
  for I := 0 to N - 1 do
    InDeg[I] := 0;

  for I := 0 to E - 1 do
  begin
    if (FEdges[I].Kind <> ugeInterfaceUse) and
       (FEdges[I].Kind <> ugeImplementationUse) then
      Continue;
    // SourceUnitId depends on TargetUnitId
    SrcIdx := IndexOfUnitId(FEdges[I].SourceUnitId);
    if SrcIdx < 0 then Continue;
    Inc(InDeg[SrcIdx]);
  end;

  // Kahn's algorithm: BFS from units with in-degree 0
  SetLength(Queue, N);
  Front := 0;
  Rear := 0;

  for I := 0 to N - 1 do
    if InDeg[I] = 0 then
    begin
      Queue[Rear] := I;
      Inc(Rear);
    end;

  SetLength(Sorted, N);
  SortedCount := 0;

  while Front < Rear do
  begin
    I := Queue[Front];
    Inc(Front);
    Sorted[SortedCount] := I;
    Inc(SortedCount);

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
      Dec(InDeg[SrcIdx]);
      if InDeg[SrcIdx] = 0 then
      begin
        Queue[Rear] := SrcIdx;
        Inc(Rear);
      end;
    end;
  end;

  // If not all units were sorted, there is a cycle.
  // Report what we can; remaining units are appended in original order.
  if SortedCount < N then
  begin
    for I := 0 to N - 1 do
    begin
      if InDeg[I] > 0 then
      begin
        Sorted[SortedCount] := I;
        Inc(SortedCount);
      end;
    end;
  end;

  // Convert indices to canonical names
  SetLength(Result, SortedCount);
  for I := 0 to SortedCount - 1 do
    Result[I] := FResolvedUnits[Sorted[I]].CanonicalName;

  // Ensure System unit is first if present
  SystemIdx := -1;
  for I := 0 to SortedCount - 1 do
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
