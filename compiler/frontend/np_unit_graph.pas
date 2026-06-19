unit np_unit_graph;

{$mode objfpc}{$H+}
{$UNITPATH .}
{$UNITPATH ../../rtl/core/text}

interface

uses
  nextpas.core.text.conv, np_source_database, np_text_primitives;

type
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

end.
