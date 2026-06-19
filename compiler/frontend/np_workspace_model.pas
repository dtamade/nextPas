unit np_workspace_model;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.text, nextpas.core.text.conv, nextpas.core.path,
  nextpas.core.fs.util, nextpas.core.exception,
  np_package_manifest;

type
  EWorkspaceModelError = class(Exception)
  end;

  TPackageRef = record
    PackageName: string;
    PackageVersion: string;
    ManifestPath: string;
    PackageRootPath: string;
    WorkspaceMemberPath: string;
    SourceRoots: TStringArray;
    Dependencies: TPackageDependencyInfoArray;
    DependencyIssues: TPackageDependencyIssueInfoArray;
  end;

  TTargetSelection = record
    RequestedTargetId: string;
    ResolvedTargetId: string;
  end;

  TArtifactRootSet = record
    ArtifactRootPath: string;
    OutputDirPath: string;
    HostCompilerCacheRootPath: string;
  end;

  TWorkspaceModel = class
  private
    FResolvedSourcePath: string;
    FWorkspaceRootPath: string;
    FDiscoveryKind: string;
    FWorkspaceDescriptorPath: string;
    FPackageManifestPath: string;
    FPackageRefs: array of TPackageRef;
    FProjectUnitRootInfos: TProjectUnitRootInfoArray;
    FProjectUnitRoots: TStringArray;
    FTargetSelection: TTargetSelection;
    FArtifactRoots: TArtifactRootSet;
  public
    constructor Create;
    function WorkspaceRootPath: string;
    function DiscoveryKind: string;
    function WorkspaceDescriptorPath: string;
    function PackageManifestPath: string;
    function PackageRefCount: LongInt;
    function PackageRefAt(const AIndex: LongInt): TPackageRef;
    function SourceRootInfoCount: LongInt;
    function ProjectUnitRootInfos: TProjectUnitRootInfoArray;
    function ProjectUnitRoots: TStringArray;
    function ArtifactRootPath: string;
    function OutputDirPath: string;
    function HostCompilerCacheRootPath: string;
    function RequestedTargetId: string;
    function ResolvedTargetId: string;
  end;

function ResolveWorkspaceModel(
  const AResolvedSourcePath: string;
  const AWorkspaceOverride: string;
  const ATargetId: string;
  const AOutDirOverride: string
): TWorkspaceModel;

function ResolveWorkspaceArtifactRootPath(
  const AWorkspaceRootPath: string
): string;

function TryResolveWorkspaceModel(
  const AResolvedSourcePath: string;
  const AWorkspaceOverride: string;
  const ATargetId: string;
  const AOutDirOverride: string;
  out AMalformedManifestWarning: string
): TWorkspaceModel;

implementation

procedure AppendUniqueString(var AValues: TStringArray; const AValue: string);
var
  Index: SizeInt;
  NextIndex: SizeInt;
begin
  for Index := 0 to Length(AValues) - 1 do
    if AValues[Index] = AValue then
      Exit;

  NextIndex := Length(AValues);
  SetLength(AValues, NextIndex + 1);
  AValues[NextIndex] := AValue;
end;

function IsAbsolutePath(const APath: string): Boolean;
begin
  if APath = '' then
    Exit(False);

  if APath[1] = DirectorySeparator then
    Exit(True);

  Result := (Length(APath) >= 2) and (APath[2] = ':');
end;

function ResolveWorkspaceRelativePath(
  const AWorkspaceRoot: string;
  const APath: string
): string;
begin
  if IsAbsolutePath(APath) then
    Exit(ExpandFileName(APath));

  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(AWorkspaceRoot) + APath
  );
end;

function FindNearestMarkerDir(
  const AStartDirectory: string;
  const AMarkerName: string
): string;
var
  CandidateDirectory: string;
  ParentDirectory: string;
begin
  CandidateDirectory := ExpandFileName(AStartDirectory);
  while CandidateDirectory <> '' do
  begin
    if FsExists(
      IncludeTrailingPathDelimiter(CandidateDirectory) + AMarkerName
    ) then
      Exit(CandidateDirectory);

    ParentDirectory := ExpandFileName(
      IncludeTrailingPathDelimiter(CandidateDirectory) + '..'
    );
    if ParentDirectory = CandidateDirectory then
      Break;
    CandidateDirectory := ParentDirectory;
  end;

  Result := '';
end;

function ResolveWorkspaceDescriptorPath(const AWorkspaceRootPath: string): string;
var
  CandidatePath: string;
begin
  if Trim(AWorkspaceRootPath) = '' then
    Exit('');

  CandidatePath := ExpandFileName(
    IncludeTrailingPathDelimiter(AWorkspaceRootPath) + 'nextpas.workspace.toml'
  );
  if FsExists(CandidatePath) then
    Exit(CandidatePath);

  Result := '';
end;

function BuildArtifactRootPath(const AWorkspaceRootPath: string): string;
begin
  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(AWorkspaceRootPath) + '.nextpas'
  );
end;

function ResolveWorkspaceArtifactRootPath(
  const AWorkspaceRootPath: string
): string;
begin
  Result := BuildArtifactRootPath(AWorkspaceRootPath);
end;

function BuildOutputDirPath(
  const AWorkspaceRootPath: string;
  const AArtifactRootPath: string;
  const ATargetId: string;
  const AOutDirOverride: string
): string;
begin
  if AOutDirOverride <> '' then
    Exit(ResolveWorkspaceRelativePath(AWorkspaceRootPath, AOutDirOverride));

  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(AArtifactRootPath) + 'out' +
    DirectorySeparator + ATargetId
  );
end;

function BuildHostCompilerCacheRootPath(
  const AArtifactRootPath: string;
  const ATargetId: string
): string;
begin
  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(AArtifactRootPath) + 'cache' +
    DirectorySeparator + 'host-fpc' + DirectorySeparator + ATargetId
  );
end;

constructor TWorkspaceModel.Create;
begin
  inherited Create;
  SetLength(FPackageRefs, 0);
  SetLength(FProjectUnitRootInfos, 0);
  SetLength(FProjectUnitRoots, 0);
end;

function TWorkspaceModel.WorkspaceRootPath: string;
begin
  Result := FWorkspaceRootPath;
end;

function TWorkspaceModel.DiscoveryKind: string;
begin
  Result := FDiscoveryKind;
end;

function TWorkspaceModel.WorkspaceDescriptorPath: string;
begin
  Result := FWorkspaceDescriptorPath;
end;

function TWorkspaceModel.PackageManifestPath: string;
begin
  Result := FPackageManifestPath;
end;

function TWorkspaceModel.PackageRefCount: LongInt;
begin
  Result := Length(FPackageRefs);
end;

function TWorkspaceModel.PackageRefAt(const AIndex: LongInt): TPackageRef;
begin
  if (AIndex < 0) or (AIndex > High(FPackageRefs)) then
  begin
    Result.PackageName := '';
    Result.ManifestPath := '';
    Result.PackageRootPath := '';
    Result.WorkspaceMemberPath := '';
    SetLength(Result.SourceRoots, 0);
    SetLength(Result.Dependencies, 0);
    SetLength(Result.DependencyIssues, 0);
    Exit;
  end;

  Result := FPackageRefs[AIndex];
end;

function TWorkspaceModel.SourceRootInfoCount: LongInt;
begin
  Result := Length(FProjectUnitRootInfos);
end;

function TWorkspaceModel.ProjectUnitRootInfos: TProjectUnitRootInfoArray;
begin
  Result := FProjectUnitRootInfos;
end;

function TWorkspaceModel.ProjectUnitRoots: TStringArray;
begin
  Result := FProjectUnitRoots;
end;

function TWorkspaceModel.ArtifactRootPath: string;
begin
  Result := FArtifactRoots.ArtifactRootPath;
end;

function TWorkspaceModel.OutputDirPath: string;
begin
  Result := FArtifactRoots.OutputDirPath;
end;

function TWorkspaceModel.HostCompilerCacheRootPath: string;
begin
  Result := FArtifactRoots.HostCompilerCacheRootPath;
end;

function TWorkspaceModel.RequestedTargetId: string;
begin
  Result := FTargetSelection.RequestedTargetId;
end;

function TWorkspaceModel.ResolvedTargetId: string;
begin
  Result := FTargetSelection.ResolvedTargetId;
end;

function ResolveWorkspaceModel(
  const AResolvedSourcePath: string;
  const AWorkspaceOverride: string;
  const ATargetId: string;
  const AOutDirOverride: string
): TWorkspaceModel;
var
  Index: LongInt;
  PackageInfo: TPackageManifestInfo;
  PackageInfos: TPackageManifestInfoArray;
  PackageRef: TPackageRef;
  SourceDirectory: string;
  WorkspaceDescriptorRoot: string;
begin
  Result := TWorkspaceModel.Create;
  Result.FResolvedSourcePath := ExpandFileName(AResolvedSourcePath);
  Result.FTargetSelection.RequestedTargetId := ATargetId;
  Result.FTargetSelection.ResolvedTargetId := ATargetId;

  if AWorkspaceOverride <> '' then
  begin
    Result.FWorkspaceRootPath := ExpandFileName(AWorkspaceOverride);
    if not FsIsDir(Result.FWorkspaceRootPath) then
      raise EWorkspaceModelError.Create(
        'invalid-workspace-root: ' + AWorkspaceOverride
      );
    Result.FDiscoveryKind := 'explicit-workspace-override';
    Result.FWorkspaceDescriptorPath := ResolveWorkspaceDescriptorPath(
      Result.FWorkspaceRootPath
    );
  end
  else
  begin
    SourceDirectory := ExtractFileDir(Result.FResolvedSourcePath);
    WorkspaceDescriptorRoot := FindNearestMarkerDir(
      SourceDirectory,
      'nextpas.workspace.toml'
    );
    if WorkspaceDescriptorRoot <> '' then
    begin
      Result.FWorkspaceRootPath := WorkspaceDescriptorRoot;
      Result.FDiscoveryKind := 'nearest-workspace-descriptor';
      Result.FWorkspaceDescriptorPath := ExpandFileName(
        IncludeTrailingPathDelimiter(WorkspaceDescriptorRoot) +
        'nextpas.workspace.toml'
      );
    end
    else
    begin
      Result.FWorkspaceRootPath := FindNearestMarkerDir(
        SourceDirectory,
        'nextpas.package.toml'
      );
      if Result.FWorkspaceRootPath <> '' then
        Result.FDiscoveryKind := 'nearest-package-manifest'
      else
      begin
        Result.FWorkspaceRootPath := SourceDirectory;
        Result.FDiscoveryKind := 'source-directory-fallback';
      end;
      Result.FWorkspaceDescriptorPath := '';
    end;
  end;

  Result.FArtifactRoots.ArtifactRootPath := BuildArtifactRootPath(
    Result.FWorkspaceRootPath
  );
  Result.FArtifactRoots.OutputDirPath := BuildOutputDirPath(
    Result.FWorkspaceRootPath,
    Result.FArtifactRoots.ArtifactRootPath,
    ATargetId,
    AOutDirOverride
  );
  Result.FArtifactRoots.HostCompilerCacheRootPath :=
    BuildHostCompilerCacheRootPath(
      Result.FArtifactRoots.ArtifactRootPath,
      ATargetId
    );

  PackageInfos := ResolveWorkspacePackageManifestInfos(
    Result.FResolvedSourcePath,
    Result.FWorkspaceRootPath
  );
  for Index := 0 to Length(PackageInfos) - 1 do
  begin
    PackageInfo := PackageInfos[Index];
    PackageRef.PackageName := PackageInfo.PackageName;
    PackageRef.PackageVersion := PackageInfo.PackageVersion;
    PackageRef.ManifestPath := PackageInfo.ManifestPath;
    PackageRef.PackageRootPath := PackageInfo.PackageRootPath;
    if Result.FWorkspaceDescriptorPath <> '' then
      PackageRef.WorkspaceMemberPath := PackageInfo.PackageRootPath
    else
    PackageRef.WorkspaceMemberPath := '';
    PackageRef.SourceRoots := PackageInfo.SourceRoots;
    PackageRef.Dependencies := PackageInfo.Dependencies;
    PackageRef.DependencyIssues := PackageInfo.DependencyIssues;

    SetLength(Result.FPackageRefs, Length(Result.FPackageRefs) + 1);
    Result.FPackageRefs[High(Result.FPackageRefs)] := PackageRef;
  end;

  if Length(PackageInfos) > 0 then
    Result.FPackageManifestPath := PackageInfos[0].ManifestPath;

  Result.FProjectUnitRootInfos := ResolveProjectUnitRootInfos(
    Result.FResolvedSourcePath,
    Result.FWorkspaceRootPath
  );
  for Index := 0 to Length(Result.FProjectUnitRootInfos) - 1 do
    AppendUniqueString(
      Result.FProjectUnitRoots,
      Result.FProjectUnitRootInfos[Index].RootPath
    );
end;

function TryResolveWorkspaceModel(
  const AResolvedSourcePath: string;
  const AWorkspaceOverride: string;
  const ATargetId: string;
  const AOutDirOverride: string;
  out AMalformedManifestWarning: string
): TWorkspaceModel;
var
  ManifestError: string;
  ManifestInfo: TPackageManifestInfo;
  ManifestPath: string;
begin
  AMalformedManifestWarning := '';
  try
    Result := ResolveWorkspaceModel(
      AResolvedSourcePath,
      AWorkspaceOverride,
      ATargetId,
      AOutDirOverride
    );
  except
    on E: Exception do
    begin
      ManifestPath := ResolveNearestPackageManifestInfo(
        ExpandFileName(AResolvedSourcePath),
        ExpandFileName(AWorkspaceOverride)
      ).ManifestPath;
      if (ManifestPath <> '') and TryLoadPackageManifestInfo(
        ManifestPath, ManifestInfo, ManifestError
      ) then
        raise
      else if ManifestPath <> '' then
      begin
        AMalformedManifestWarning :=
          'malformed-package-manifest: ' + ManifestPath + ': ' + ManifestError;
        Result := TWorkspaceModel.Create;
        Result.FResolvedSourcePath := ExpandFileName(AResolvedSourcePath);
        Result.FTargetSelection.RequestedTargetId := ATargetId;
        Result.FTargetSelection.ResolvedTargetId := ATargetId;
        if AWorkspaceOverride <> '' then
        begin
          Result.FWorkspaceRootPath := ExpandFileName(AWorkspaceOverride);
          Result.FDiscoveryKind := 'explicit-workspace-override-malformed-manifest';
        end
        else
        begin
          Result.FWorkspaceRootPath := ExtractFileDir(Result.FResolvedSourcePath);
          Result.FDiscoveryKind := 'source-directory-fallback-malformed-manifest';
        end;
        Result.FWorkspaceDescriptorPath := '';
        Result.FPackageManifestPath := ManifestPath;
        Result.FArtifactRoots.ArtifactRootPath := BuildArtifactRootPath(
          Result.FWorkspaceRootPath
        );
        Result.FArtifactRoots.OutputDirPath := BuildOutputDirPath(
          Result.FWorkspaceRootPath,
          Result.FArtifactRoots.ArtifactRootPath,
          ATargetId,
          AOutDirOverride
        );
        Result.FArtifactRoots.HostCompilerCacheRootPath :=
          BuildHostCompilerCacheRootPath(
            Result.FArtifactRoots.ArtifactRootPath,
            ATargetId
          );
      end
      else
        raise;
    end;
  end;
end;

end.
