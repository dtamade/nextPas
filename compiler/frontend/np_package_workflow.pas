unit np_package_workflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, np_package_manifest, np_workspace_model;

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
  end;

  TPackageInstallPlanTruth = record
    Status: string;
    WorkspaceRootPath: string;
    PackageRootPath: string;
  end;

  TPackageWorkflowTruth = record
    Status: string;
    ManifestTruth: TPackageManifestTruth;
    LockTruth: TPackageLockTruth;
    InstallPlanTruth: TPackageInstallPlanTruth;
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

  Result.LockTruth.LockfilePath := ResolveLockfilePath(WorkspaceRootPath);
  if FileExists(Result.LockTruth.LockfilePath) then
    Result.LockTruth.Status := 'ready'
  else
    Result.LockTruth.Status := 'missing';

  Result.InstallPlanTruth.Status := 'deferred';
  Result.InstallPlanTruth.WorkspaceRootPath := WorkspaceRootPath;
  Result.InstallPlanTruth.PackageRootPath := AManifestInfo.PackageRootPath;

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
