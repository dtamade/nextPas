unit np_package_workflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, np_package_manifest;

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

end.
