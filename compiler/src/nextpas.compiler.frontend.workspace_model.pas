unit nextpas.compiler.frontend.workspace_model;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  { text.conv + base only: full nextpas.core.text facade pulls unicode tables and
    explodes under A+LLVM self-compile (multi-GB / multi-minute). }
  nextpas.core.base, nextpas.core.text.conv, nextpas.core.path,
  nextpas.core.fs.util, nextpas.core.exception,
  nextpas.core.collections.vec,
  nextpas.compiler.frontend.package_manifest;

type
  EWorkspaceModelError = class(ENextPasError)
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

  TPackageRefVec = specialize TVec<TPackageRef>;
  TProjectUnitRootInfoVec = specialize TVec<TProjectUnitRootInfo>;
  TProjectUnitRootVec = specialize TVec<string>;

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
    FPackageRefs: TPackageRefVec;
    FProjectUnitRootInfos: TProjectUnitRootInfoVec;
    FProjectUnitRoots: TProjectUnitRootVec;
    FTargetSelection: TTargetSelection;
    FArtifactRoots: TArtifactRootSet;
  public
    constructor Create;
    destructor Destroy; override;
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

procedure AppendUniqueRoot(
  const AValues: TProjectUnitRootVec;
  const AValue: string
);
var
  Index: SizeInt;
begin
  if AValues = nil then
    Exit;

  { Count is SizeUInt: `to Count - 1` underflows when empty. Use signed bound. }
  for Index := 0 to SizeInt(AValues.Count) - 1 do
    if AValues[SizeUInt(Index)] = AValue then
      Exit;

  { EnsureCapacity + PushUnchecked: TVec.Push single-element overloads are
    ambiguous under nextPas sema (open-array vs element). PushUnchecked does
    not grow — capacity must be reserved first. }
  AValues.EnsureCapacity(AValues.Count + 1);
  AValues.PushUnchecked(AValue);
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
  FPackageRefs := TPackageRefVec.Create;
  FProjectUnitRootInfos := TProjectUnitRootInfoVec.Create;
  FProjectUnitRoots := TProjectUnitRootVec.Create;
end;

destructor TWorkspaceModel.Destroy;
begin
  FPackageRefs.Free;
  FPackageRefs := nil;
  FProjectUnitRootInfos.Free;
  FProjectUnitRootInfos := nil;
  FProjectUnitRoots.Free;
  FProjectUnitRoots := nil;
  inherited Destroy;
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
  if FPackageRefs = nil then
    Exit(0);
  Result := LongInt(FPackageRefs.Count);
end;

function TWorkspaceModel.PackageRefAt(const AIndex: LongInt): TPackageRef;
begin
  if (FPackageRefs = nil) or (AIndex < 0) or
    (AIndex >= LongInt(FPackageRefs.Count)) then
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

  Result := FPackageRefs[SizeUInt(AIndex)];
end;

function TWorkspaceModel.SourceRootInfoCount: LongInt;
begin
  if FProjectUnitRootInfos = nil then
    Exit(0);
  Result := LongInt(FProjectUnitRootInfos.Count);
end;

function TWorkspaceModel.ProjectUnitRootInfos: TProjectUnitRootInfoArray;
var
  Index: SizeInt;
begin
  if (FProjectUnitRootInfos = nil) or (FProjectUnitRootInfos.Count = 0) then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  SetLength(Result, FProjectUnitRootInfos.Count);
  for Index := 0 to SizeInt(FProjectUnitRootInfos.Count) - 1 do
    Result[Index] := FProjectUnitRootInfos[SizeUInt(Index)];
end;

function TWorkspaceModel.ProjectUnitRoots: TStringArray;
var
  Index: SizeInt;
begin
  if (FProjectUnitRoots = nil) or (FProjectUnitRoots.Count = 0) then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  SetLength(Result, FProjectUnitRoots.Count);
  for Index := 0 to SizeInt(FProjectUnitRoots.Count) - 1 do
    Result[Index] := FProjectUnitRoots[SizeUInt(Index)];
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
  RootInfos: TProjectUnitRootInfoArray;
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

    if Result.FPackageRefs = nil then
      Result.FPackageRefs := TPackageRefVec.Create;
    Result.FPackageRefs.EnsureCapacity(Result.FPackageRefs.Count + 1);
    Result.FPackageRefs.PushUnchecked(PackageRef);
  end;

  if Length(PackageInfos) > 0 then
    Result.FPackageManifestPath := PackageInfos[0].ManifestPath;

  if Result.FProjectUnitRootInfos = nil then
    Result.FProjectUnitRootInfos := TProjectUnitRootInfoVec.Create
  else
    Result.FProjectUnitRootInfos.Clear;
  if Result.FProjectUnitRoots = nil then
    Result.FProjectUnitRoots := TProjectUnitRootVec.Create
  else
    Result.FProjectUnitRoots.Clear;

  RootInfos := ResolveProjectUnitRootInfos(
    Result.FResolvedSourcePath,
    Result.FWorkspaceRootPath
  );
  for Index := 0 to Length(RootInfos) - 1 do
  begin
    Result.FProjectUnitRootInfos.EnsureCapacity(Result.FProjectUnitRootInfos.Count + 1);
    Result.FProjectUnitRootInfos.PushUnchecked(RootInfos[Index]);
    AppendUniqueRoot(
      Result.FProjectUnitRoots,
      RootInfos[Index].RootPath
    );
  end;
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
