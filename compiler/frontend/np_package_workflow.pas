unit np_package_workflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, np_package_manifest, np_package_lock, np_workspace_model;

type
  TPackageManifestTruth = record
    Status: string;
    ManifestPath: string;
    PackageRootPath: string;
    PackageName: string;
    SourceRootCount: LongInt;
    SourceRoots: TStringArray;
    DependencyCount: LongInt;
    Dependencies: TPackageDependencyInfoArray;
    DependencyValidationStatus: string;
    DependencyIssueCount: LongInt;
    DependencyIssues: TPackageDependencyIssueInfoArray;
  end;

  TPackageLockTruth = record
    Status: string;
    LockfilePath: string;
    FormatVersion: LongInt;
    EntryCount: LongInt;
    Entries: TPackageLockEntryInfoArray;
    IssueCount: LongInt;
    Issues: TPackageLockIssueInfoArray;
  end;

  TPackageInstallPlanTruth = record
    Status: string;
    WorkspaceRootPath: string;
    PackageRootPath: string;
    BlockerCode: string;
    BlockerMessage: string;
  end;

  TPackageGraphNodeInfo = record
    NodeId: string;
    Kind: string;
    PackageName: string;
    Requirement: string;
    ManifestPath: string;
    PackageRootPath: string;
  end;

  TPackageGraphNodeInfoArray = array of TPackageGraphNodeInfo;

  TPackageGraphEdgeInfo = record
    FromNodeId: string;
    ToNodeId: string;
    Kind: string;
    Requirement: string;
  end;

  TPackageGraphEdgeInfoArray = array of TPackageGraphEdgeInfo;

  TPackageGraphTruth = record
    Status: string;
    NodeCount: LongInt;
    EdgeCount: LongInt;
    Nodes: TPackageGraphNodeInfoArray;
    Edges: TPackageGraphEdgeInfoArray;
  end;

  TPackageWorkflowTruth = record
    Status: string;
    ManifestTruth: TPackageManifestTruth;
    LockTruth: TPackageLockTruth;
    InstallPlanTruth: TPackageInstallPlanTruth;
    GraphTruth: TPackageGraphTruth;
    PackageSourceRootCount: LongInt;
    PackageDependencyCount: LongInt;
    PackageDependencyValidationStatus: string;
    PackageDependencyIssueCount: LongInt;
  end;

function BuildPackageWorkflowTruth(
  const AManifestInfo: TPackageManifestInfo;
  const AWorkspaceRootPath: string
): TPackageWorkflowTruth;
function BuildPackageWorkflowTruthFromWorkspaceModel(
  const AWorkspaceModel: TWorkspaceModel
): TPackageWorkflowTruth;

implementation

procedure AppendGraphNode(
  var AValues: TPackageGraphNodeInfoArray;
  const AValue: TPackageGraphNodeInfo
);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(AValues);
  SetLength(AValues, NextIndex + 1);
  AValues[NextIndex] := AValue;
end;

procedure AppendGraphEdge(
  var AValues: TPackageGraphEdgeInfoArray;
  const AValue: TPackageGraphEdgeInfo
);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(AValues);
  SetLength(AValues, NextIndex + 1);
  AValues[NextIndex] := AValue;
end;

function PackageGraphRootNodeId(const AManifestTruth: TPackageManifestTruth): string;
begin
  if Trim(AManifestTruth.PackageName) <> '' then
    Exit('package:' + AManifestTruth.PackageName);

  Result := 'package:root';
end;

function PackageGraphDependencyNodeId(
  const ADependency: TPackageDependencyInfo
): string;
begin
  Result := 'dependency:' + ADependency.PackageName;
end;

function BuildPackageGraphTruth(
  const AManifestTruth: TPackageManifestTruth
): TPackageGraphTruth;
var
  DependencyIndex: LongInt;
  DependencyNode: TPackageGraphNodeInfo;
  Edge: TPackageGraphEdgeInfo;
  RootNode: TPackageGraphNodeInfo;
  RootNodeId: string;
begin
  Result.Status := 'missing';
  Result.NodeCount := 0;
  Result.EdgeCount := 0;
  SetLength(Result.Nodes, 0);
  SetLength(Result.Edges, 0);

  if AManifestTruth.Status <> 'ready' then
    Exit;

  if AManifestTruth.DependencyValidationStatus = 'invalid' then
    Result.Status := 'invalid'
  else
    Result.Status := 'ready';

  RootNodeId := PackageGraphRootNodeId(AManifestTruth);
  RootNode.NodeId := RootNodeId;
  RootNode.Kind := 'workspace-package';
  RootNode.PackageName := AManifestTruth.PackageName;
  RootNode.Requirement := '';
  RootNode.ManifestPath := AManifestTruth.ManifestPath;
  RootNode.PackageRootPath := AManifestTruth.PackageRootPath;
  AppendGraphNode(Result.Nodes, RootNode);

  for DependencyIndex := 0 to Length(AManifestTruth.Dependencies) - 1 do
  begin
    DependencyNode.NodeId := PackageGraphDependencyNodeId(
      AManifestTruth.Dependencies[DependencyIndex]
    );
    DependencyNode.Kind := 'declared-dependency';
    DependencyNode.PackageName :=
      AManifestTruth.Dependencies[DependencyIndex].PackageName;
    DependencyNode.Requirement :=
      AManifestTruth.Dependencies[DependencyIndex].Requirement;
    DependencyNode.ManifestPath := '';
    DependencyNode.PackageRootPath := '';
    AppendGraphNode(Result.Nodes, DependencyNode);

    Edge.FromNodeId := RootNodeId;
    Edge.ToNodeId := DependencyNode.NodeId;
    Edge.Kind := 'declared-dependency';
    Edge.Requirement := AManifestTruth.Dependencies[DependencyIndex].Requirement;
    AppendGraphEdge(Result.Edges, Edge);
  end;

  Result.NodeCount := Length(Result.Nodes);
  Result.EdgeCount := Length(Result.Edges);
end;

function BuildPackageInstallPlanTruth(
  const AManifestTruth: TPackageManifestTruth;
  const ALockTruth: TPackageLockTruth;
  const AWorkspaceRootPath: string
): TPackageInstallPlanTruth;
begin
  Result.Status := 'missing';
  Result.WorkspaceRootPath := AWorkspaceRootPath;
  Result.PackageRootPath := AManifestTruth.PackageRootPath;
  Result.BlockerCode := 'package-manifest-missing';
  Result.BlockerMessage := 'package manifest is missing';

  if AManifestTruth.Status <> 'ready' then
    Exit;

  Result.Status := 'blocked';
  Result.BlockerCode := 'package-dependencies-invalid';
  Result.BlockerMessage := 'package dependency validation is invalid';

  if AManifestTruth.DependencyValidationStatus = 'invalid' then
    Exit;

  Result.BlockerCode := 'package-source-roots-missing';
  Result.BlockerMessage := 'package source roots are missing';
  if AManifestTruth.SourceRootCount <= 0 then
    Exit;

  Result.BlockerCode := 'package-lock-missing';
  Result.BlockerMessage := 'canonical package lockfile is missing';
  if ALockTruth.Status = 'invalid' then
  begin
    Result.BlockerCode := 'package-lock-invalid';
    Result.BlockerMessage := 'canonical package lockfile is invalid';
    Exit;
  end;
  if ALockTruth.Status <> 'ready' then
    Exit;

  Result.Status := 'ready';
  Result.BlockerCode := '';
  Result.BlockerMessage := '';
end;

function ResolveLockfilePath(const AWorkspaceRootPath: string): string;
begin
  if Trim(AWorkspaceRootPath) = '' then
    Exit('');

  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(AWorkspaceRootPath) + 'nextpas.lock'
  );
end;

function BuildPackageWorkflowTruth(
  const AManifestInfo: TPackageManifestInfo;
  const AWorkspaceRootPath: string
): TPackageWorkflowTruth;
var
  LockInfo: TPackageLockInfo;
  ManifestReady: Boolean;
  WorkspaceRootPath: string;
begin
  WorkspaceRootPath := '';
  if Trim(AWorkspaceRootPath) <> '' then
    WorkspaceRootPath := ExpandFileName(AWorkspaceRootPath);

  ManifestReady := Trim(AManifestInfo.ManifestPath) <> '';

  if ManifestReady then
    Result.ManifestTruth.Status := 'ready'
  else
    Result.ManifestTruth.Status := 'missing';
  Result.ManifestTruth.ManifestPath := AManifestInfo.ManifestPath;
  Result.ManifestTruth.PackageRootPath := AManifestInfo.PackageRootPath;
  Result.ManifestTruth.PackageName := AManifestInfo.PackageName;
  Result.ManifestTruth.SourceRootCount := Length(AManifestInfo.SourceRoots);
  Result.ManifestTruth.SourceRoots := AManifestInfo.SourceRoots;
  Result.ManifestTruth.DependencyCount := Length(AManifestInfo.Dependencies);
  Result.ManifestTruth.Dependencies := AManifestInfo.Dependencies;
  Result.ManifestTruth.DependencyIssueCount :=
    Length(AManifestInfo.DependencyIssues);
  Result.ManifestTruth.DependencyIssues := AManifestInfo.DependencyIssues;
  if not ManifestReady then
    Result.ManifestTruth.DependencyValidationStatus := 'missing'
  else if Result.ManifestTruth.DependencyIssueCount > 0 then
    Result.ManifestTruth.DependencyValidationStatus := 'invalid'
  else
    Result.ManifestTruth.DependencyValidationStatus := 'valid';

  LockInfo := LoadPackageLockInfo(ResolveLockfilePath(WorkspaceRootPath));
  Result.LockTruth.Status := LockInfo.Status;
  Result.LockTruth.LockfilePath := LockInfo.LockfilePath;
  Result.LockTruth.FormatVersion := LockInfo.FormatVersion;
  Result.LockTruth.EntryCount := Length(LockInfo.Entries);
  Result.LockTruth.Entries := LockInfo.Entries;
  Result.LockTruth.IssueCount := Length(LockInfo.Issues);
  Result.LockTruth.Issues := LockInfo.Issues;

  Result.InstallPlanTruth := BuildPackageInstallPlanTruth(
    Result.ManifestTruth,
    Result.LockTruth,
    WorkspaceRootPath
  );
  Result.GraphTruth := BuildPackageGraphTruth(Result.ManifestTruth);

  Result.PackageSourceRootCount := Result.ManifestTruth.SourceRootCount;
  Result.PackageDependencyCount := Result.ManifestTruth.DependencyCount;
  Result.PackageDependencyValidationStatus :=
    Result.ManifestTruth.DependencyValidationStatus;
  Result.PackageDependencyIssueCount := Result.ManifestTruth.DependencyIssueCount;
  if ManifestReady then
    Result.Status := 'ready'
  else
    Result.Status := 'missing';
end;

function BuildPackageWorkflowTruthFromWorkspaceModel(
  const AWorkspaceModel: TWorkspaceModel
): TPackageWorkflowTruth;
var
  ManifestInfo: TPackageManifestInfo;
  PackageRef: TPackageRef;
begin
  ManifestInfo.ManifestPath := '';
  ManifestInfo.PackageRootPath := '';
  ManifestInfo.PackageName := '';
  SetLength(ManifestInfo.SourceRoots, 0);
  SetLength(ManifestInfo.Dependencies, 0);
  SetLength(ManifestInfo.DependencyIssues, 0);

  if (AWorkspaceModel <> nil) and (AWorkspaceModel.PackageRefCount > 0) then
  begin
    PackageRef := AWorkspaceModel.PackageRefAt(0);
    ManifestInfo.ManifestPath := PackageRef.ManifestPath;
    ManifestInfo.PackageRootPath := PackageRef.PackageRootPath;
    ManifestInfo.PackageName := PackageRef.PackageName;
    ManifestInfo.SourceRoots := PackageRef.SourceRoots;
    ManifestInfo.Dependencies := PackageRef.Dependencies;
    ManifestInfo.DependencyIssues := PackageRef.DependencyIssues;
  end;

  if AWorkspaceModel <> nil then
    Result := BuildPackageWorkflowTruth(
      ManifestInfo,
      AWorkspaceModel.WorkspaceRootPath
    )
  else
    Result := BuildPackageWorkflowTruth(ManifestInfo, '');
end;

end.
