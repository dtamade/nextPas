unit nextpas.compiler.frontend.package_manifest;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.base,
  nextpas.compiler.frontend.package_manifest;

type
  TPackageDependencyInfo = nextpas.compiler.frontend.package_manifest.TPackageDependencyInfo;
  TPackageDependencyInfoArray = nextpas.compiler.frontend.package_manifest.TPackageDependencyInfoArray;
  TPackageDependencyIssueInfo = nextpas.compiler.frontend.package_manifest.TPackageDependencyIssueInfo;
  TPackageDependencyIssueInfoArray = nextpas.compiler.frontend.package_manifest.TPackageDependencyIssueInfoArray;
  TPackageManifestInfo = nextpas.compiler.frontend.package_manifest.TPackageManifestInfo;
  TPackageManifestInfoArray = nextpas.compiler.frontend.package_manifest.TPackageManifestInfoArray;
  TProjectUnitRootInfo = nextpas.compiler.frontend.package_manifest.TProjectUnitRootInfo;
  TProjectUnitRootInfoArray = nextpas.compiler.frontend.package_manifest.TProjectUnitRootInfoArray;

function LoadPackageManifestInfo(const AManifestPath: string): TPackageManifestInfo;
function TryLoadPackageManifestInfo( const AManifestPath: string; out AInfo: TPackageManifestInfo; out AErrorText: string ): Boolean;
function ResolveNearestPackageManifestInfo( const AResolvedSourcePath: string; const AWorkspaceRootPath: string ): TPackageManifestInfo;
function ResolveWorkspaceMemberRootInfos( const AWorkspaceRootPath: string ): TProjectUnitRootInfoArray;
function ResolveProjectUnitRootInfos( const AResolvedSourcePath: string; const AWorkspaceRootPath: string ): TProjectUnitRootInfoArray;
function ResolvePackageSourceRoots( const AResolvedSourcePath: string; const AWorkspaceRootPath: string ): TStringArray;
function ResolveWorkspaceMemberPackageInfos( const AWorkspaceRootPath: string ): TPackageManifestInfoArray;
function ResolveWorkspacePackageManifestInfos( const AResolvedSourcePath: string; const AWorkspaceRootPath: string ): TPackageManifestInfoArray;

implementation

function LoadPackageManifestInfo(const AManifestPath: string): TPackageManifestInfo;
begin
  Result := nextpas.compiler.frontend.package_manifest.LoadPackageManifestInfo(AManifestPath);
end;

function TryLoadPackageManifestInfo( const AManifestPath: string; out AInfo: TPackageManifestInfo; out AErrorText: string ): Boolean;
begin
  Result := nextpas.compiler.frontend.package_manifest.TryLoadPackageManifestInfo(AManifestPath, AInfo, AErrorText);
end;

function ResolveNearestPackageManifestInfo( const AResolvedSourcePath: string; const AWorkspaceRootPath: string ): TPackageManifestInfo;
begin
  Result := nextpas.compiler.frontend.package_manifest.ResolveNearestPackageManifestInfo(AResolvedSourcePath, AWorkspaceRootPath);
end;

function ResolveWorkspaceMemberRootInfos( const AWorkspaceRootPath: string ): TProjectUnitRootInfoArray;
begin
  Result := nextpas.compiler.frontend.package_manifest.ResolveWorkspaceMemberRootInfos(AWorkspaceRootPath);
end;

function ResolveProjectUnitRootInfos( const AResolvedSourcePath: string; const AWorkspaceRootPath: string ): TProjectUnitRootInfoArray;
begin
  Result := nextpas.compiler.frontend.package_manifest.ResolveProjectUnitRootInfos(AResolvedSourcePath, AWorkspaceRootPath);
end;

function ResolvePackageSourceRoots( const AResolvedSourcePath: string; const AWorkspaceRootPath: string ): TStringArray;
begin
  Result := nextpas.compiler.frontend.package_manifest.ResolvePackageSourceRoots(AResolvedSourcePath, AWorkspaceRootPath);
end;

function ResolveWorkspaceMemberPackageInfos( const AWorkspaceRootPath: string ): TPackageManifestInfoArray;
begin
  Result := nextpas.compiler.frontend.package_manifest.ResolveWorkspaceMemberPackageInfos(AWorkspaceRootPath);
end;

function ResolveWorkspacePackageManifestInfos( const AResolvedSourcePath: string; const AWorkspaceRootPath: string ): TPackageManifestInfoArray;
begin
  Result := nextpas.compiler.frontend.package_manifest.ResolveWorkspacePackageManifestInfos(AResolvedSourcePath, AWorkspaceRootPath);
end;

end.