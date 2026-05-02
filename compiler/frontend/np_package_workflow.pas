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

  Result.LockTruth.Status := 'deferred';
  Result.LockTruth.LockfilePath := ResolveLockfilePath(WorkspaceRootPath);

  Result.InstallPlanTruth.Status := 'deferred';
  Result.InstallPlanTruth.WorkspaceRootPath := WorkspaceRootPath;
  Result.InstallPlanTruth.PackageRootPath := AManifestInfo.PackageRootPath;

  Result.PackageSourceRootCount := Result.ManifestTruth.SourceRootCount;
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

  if (AWorkspaceModel <> nil) and (AWorkspaceModel.PackageRefCount > 0) then
  begin
    PackageRef := AWorkspaceModel.PackageRefAt(0);
    ManifestInfo.ManifestPath := PackageRef.ManifestPath;
    ManifestInfo.PackageRootPath := PackageRef.PackageRootPath;
    ManifestInfo.PackageName := PackageRef.PackageName;
    ManifestInfo.SourceRoots := PackageRef.SourceRoots;
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
