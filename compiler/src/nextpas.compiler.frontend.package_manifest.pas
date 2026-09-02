unit nextpas.compiler.frontend.package_manifest;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.base, nextpas.core.text.conv, nextpas.core.path,
  nextpas.core.fs, nextpas.core.fs.util, nextpas.core.exception;

type
  TPackageDependencyInfo = record
    PackageName: string;
    Requirement: string;
  end;

  TPackageDependencyInfoArray = array of TPackageDependencyInfo;

  TPackageDependencyIssueInfo = record
    PackageName: string;
    Requirement: string;
    Code: string;
    Message: string;
  end;

  TPackageDependencyIssueInfoArray = array of TPackageDependencyIssueInfo;

  TPackageManifestInfo = record
    ManifestPath: string;
    PackageRootPath: string;
    PackageName: string;
    PackageVersion: string;
    SourceRoots: TStringArray;
    Dependencies: TPackageDependencyInfoArray;
    DependencyIssues: TPackageDependencyIssueInfoArray;
  end;

  TPackageManifestInfoArray = array of TPackageManifestInfo;

  TProjectUnitRootInfo = record
    RootPath: string;
    ScopeName: string;
    ProvenanceKind: string;
    PackageName: string;
    ManifestPath: string;
    WorkspaceMemberPath: string;
  end;

  TProjectUnitRootInfoArray = array of TProjectUnitRootInfo;

function LoadPackageManifestInfo(const AManifestPath: string): TPackageManifestInfo;
function TryLoadPackageManifestInfo(
  const AManifestPath: string;
  out AInfo: TPackageManifestInfo;
  out AErrorText: string
): Boolean;
function ResolveNearestPackageManifestInfo(
  const AResolvedSourcePath: string;
  const AWorkspaceRootPath: string
): TPackageManifestInfo;
function ResolveWorkspaceMemberRootInfos(
  const AWorkspaceRootPath: string
): TProjectUnitRootInfoArray;
function ResolveProjectUnitRootInfos(
  const AResolvedSourcePath: string;
  const AWorkspaceRootPath: string
): TProjectUnitRootInfoArray;
function ResolvePackageSourceRoots(
  const AResolvedSourcePath: string;
  const AWorkspaceRootPath: string
): TStringArray;
function ResolveWorkspaceMemberPackageInfos(
  const AWorkspaceRootPath: string
): TPackageManifestInfoArray;
function ResolveWorkspacePackageManifestInfos(
  const AResolvedSourcePath: string;
  const AWorkspaceRootPath: string
): TPackageManifestInfoArray;

implementation

{$I np_package_manifest_helpers.inc}
function LoadPackageManifestInfo(
  const AManifestPath: string
): TPackageManifestInfo;
var
  CurrentSection: string;
  EntryIndex: LongInt;
  EqPos: SizeInt;
  KeyName: string;
  LineIndex: LongInt;
  Lines: TStringArray;
  DependencyInfo: TPackageDependencyInfo;
  ManifestDirectory: string;
  ManifestPath: string;
  RawLine: string;
  ResolvedRoot: string;
  RootEntries: TStringArray;
  TrimmedLine: string;
begin
  Result.ManifestPath := '';
  Result.PackageRootPath := '';
  Result.PackageName := '';
  Result.PackageVersion := '';
  Result.SourceRoots := nil;
  SetLength(Result.SourceRoots, 0);
  Result.Dependencies := nil;
  SetLength(Result.Dependencies, 0);
  Result.DependencyIssues := nil;
  SetLength(Result.DependencyIssues, 0);

  ManifestPath := ExpandFileName(AManifestPath);
  if not FsExists(ManifestPath) then
    Exit;

  Result.ManifestPath := ManifestPath;
  ManifestDirectory := ExtractFileDir(ManifestPath);
  Result.PackageRootPath := ExpandFileName(ManifestDirectory);
  Lines := ReadFileLines(ManifestPath);
  CurrentSection := '';
  for LineIndex := 0 to High(Lines) do
  begin
    RawLine := StripTomlComment(Lines[LineIndex]);
      TrimmedLine := Trim(RawLine);
      if TrimmedLine = '' then
        Continue;

      if (TrimmedLine[1] = '[') and (TrimmedLine[Length(TrimmedLine)] = ']') then
      begin
        CurrentSection := LowerCase(
          Trim(Copy(TrimmedLine, 2, Length(TrimmedLine) - 2))
        );
        Continue;
      end;

      EqPos := Pos('=', TrimmedLine);
      if EqPos <= 0 then
        Continue;

      KeyName := LowerCase(Trim(Copy(TrimmedLine, 1, EqPos - 1)));
      if (CurrentSection = 'package') and (KeyName = 'name') then
      begin
        Result.PackageName := Trim(Copy(TrimmedLine, EqPos + 1, MaxInt));
        Result.PackageName := ParseTomlStringLiteral(Result.PackageName);
        Continue;
      end;

      if (CurrentSection = 'package') and (KeyName = 'version') then
      begin
        Result.PackageVersion := Trim(Copy(TrimmedLine, EqPos + 1, MaxInt));
        Result.PackageVersion := ParseTomlStringLiteral(Result.PackageVersion);
        Continue;
      end;

      if (CurrentSection <> 'sources') or (KeyName <> 'roots') then
      begin
        if CurrentSection <> 'dependencies' then
          Continue;

        if not ParsePackageDependencyInfo(TrimmedLine, DependencyInfo) then
          Continue;

        AppendUniquePackageDependencyInfo(Result.Dependencies, DependencyInfo);
        if not IsPackageDependencyRequirementValid(DependencyInfo.Requirement) then
          AppendPackageDependencyIssueInfo(
            Result.DependencyIssues,
            BuildPackageDependencyIssueInfo(DependencyInfo)
          );
        Continue;
      end;

      RootEntries := ParseTomlStringArray(Copy(TrimmedLine, EqPos + 1, MaxInt));
      for EntryIndex := 0 to Length(RootEntries) - 1 do
      begin
        if IsAbsolutePath(RootEntries[EntryIndex]) then
          ResolvedRoot := ExpandFileName(RootEntries[EntryIndex])
        else
          ResolvedRoot := ExpandFileName(
            IncludeTrailingPathDelimiter(ManifestDirectory) + RootEntries[EntryIndex]
          );

        if FsIsDir(ResolvedRoot) then
          AppendUniqueString(Result.SourceRoots, ResolvedRoot);
      end;
    end;
  end;

function TryLoadPackageManifestInfo(
  const AManifestPath: string;
  out AInfo: TPackageManifestInfo;
  out AErrorText: string
): Boolean;
begin
  try
    AInfo := LoadPackageManifestInfo(AManifestPath);
    AErrorText := '';
    Result := True;
  except
    on E: Exception do
    begin
      AInfo.ManifestPath := ExpandFileName(AManifestPath);
      AInfo.PackageRootPath := ExtractFileDir(ExpandFileName(AManifestPath));
      AInfo.PackageName := '';
      AInfo.PackageVersion := '';
      AInfo.SourceRoots := nil;
      SetLength(AInfo.SourceRoots, 0);
      AInfo.Dependencies := nil;
      SetLength(AInfo.Dependencies, 0);
      AInfo.DependencyIssues := nil;
      SetLength(AInfo.DependencyIssues, 0);
      AErrorText := E.Message;
      Result := False;
    end;
  end;
end;

function ResolveWorkspaceMemberPackageInfos(
  const AWorkspaceRootPath: string
): TPackageManifestInfoArray;
var
  CurrentSection: string;
  EntryIndex: LongInt;
  EqPos: SizeInt;
  KeyName: string;
  LineIndex: LongInt;
  Lines: TStringArray;
  MemberEntries: TStringArray;
  MemberManifestPath: string;
  MemberRootPath: string;
  PackageInfo: TPackageManifestInfo;
  TrimmedLine: string;
  WorkspaceDescriptorPath: string;
begin
  Result := nil;
  SetLength(Result, 0);

  if Trim(AWorkspaceRootPath) = '' then
    Exit;

  WorkspaceDescriptorPath := IncludeTrailingPathDelimiter(
    ExpandFileName(AWorkspaceRootPath)
  ) + 'nextpas.workspace.toml';
  if not FsExists(WorkspaceDescriptorPath) then
    Exit;

  Lines := ReadFileLines(WorkspaceDescriptorPath);
  CurrentSection := '';
  for LineIndex := 0 to High(Lines) do
  begin
    TrimmedLine := Trim(StripTomlComment(Lines[LineIndex]));
      if TrimmedLine = '' then
        Continue;

      if (TrimmedLine[1] = '[') and (TrimmedLine[Length(TrimmedLine)] = ']') then
      begin
        CurrentSection := LowerCase(
          Trim(Copy(TrimmedLine, 2, Length(TrimmedLine) - 2))
        );
        Continue;
      end;

      EqPos := Pos('=', TrimmedLine);
      if EqPos <= 0 then
        Continue;

      KeyName := LowerCase(Trim(Copy(TrimmedLine, 1, EqPos - 1)));
      if (CurrentSection <> 'workspace') or (KeyName <> 'members') then
        Continue;

      MemberEntries := ParseTomlStringArray(Copy(TrimmedLine, EqPos + 1, MaxInt));
      for EntryIndex := 0 to Length(MemberEntries) - 1 do
      begin
        if IsAbsolutePath(MemberEntries[EntryIndex]) then
          MemberRootPath := ExpandFileName(MemberEntries[EntryIndex])
        else
          MemberRootPath := ExpandFileName(
            IncludeTrailingPathDelimiter(AWorkspaceRootPath) + MemberEntries[EntryIndex]
          );

        MemberManifestPath := IncludeTrailingPathDelimiter(MemberRootPath) +
          'nextpas.package.toml';
        if not FsExists(MemberManifestPath) then
          Continue;

        PackageInfo := LoadPackageManifestInfo(MemberManifestPath);
        PackageInfo.PackageRootPath := ExpandFileName(MemberRootPath);
        AppendUniquePackageManifestInfo(Result, PackageInfo);
      end;
    end;
  end;

function ResolveWorkspaceMemberRootInfos(
  const AWorkspaceRootPath: string
): TProjectUnitRootInfoArray;
var
  PackageInfos: TPackageManifestInfoArray;
  PackageIndex: LongInt;
  RootIndex: LongInt;
begin
  Result := nil;
  SetLength(Result, 0);

  PackageInfos := ResolveWorkspaceMemberPackageInfos(AWorkspaceRootPath);
  for PackageIndex := 0 to Length(PackageInfos) - 1 do
    for RootIndex := 0 to Length(PackageInfos[PackageIndex].SourceRoots) - 1 do
      AppendUniqueProjectUnitRootInfo(
        Result,
        BuildProjectUnitRootInfo(
          PackageInfos[PackageIndex].SourceRoots[RootIndex],
          'workspace-member-package-source-root',
          PackageInfos[PackageIndex].PackageName,
          PackageInfos[PackageIndex].ManifestPath,
          PackageInfos[PackageIndex].PackageRootPath
        )
      );
end;

function ResolveNearestPackageManifestInfo(
  const AResolvedSourcePath: string;
  const AWorkspaceRootPath: string
): TPackageManifestInfo;
var
  ManifestPath: string;
begin
  ManifestPath := FindNearestPackageManifest(
    AResolvedSourcePath,
    AWorkspaceRootPath
  );
  if ManifestPath = '' then
  begin
    Result.ManifestPath := '';
    Result.PackageRootPath := '';
    Result.PackageName := '';
    Result.PackageVersion := '';
    Result.SourceRoots := nil;
    SetLength(Result.SourceRoots, 0);
    Result.Dependencies := nil;
    SetLength(Result.Dependencies, 0);
    Result.DependencyIssues := nil;
    SetLength(Result.DependencyIssues, 0);
    Exit;
  end;

  Result := LoadPackageManifestInfo(ManifestPath);
end;

function ResolveProjectUnitRootInfos(
  const AResolvedSourcePath: string;
  const AWorkspaceRootPath: string
): TProjectUnitRootInfoArray;
var
  ManifestInfo: TPackageManifestInfo;
  RootIndex: LongInt;
  WorkspaceMemberRoots: TProjectUnitRootInfoArray;
begin
  Result := nil;
  SetLength(Result, 0);

  ManifestInfo := ResolveNearestPackageManifestInfo(
    AResolvedSourcePath,
    AWorkspaceRootPath
  );
  for RootIndex := 0 to Length(ManifestInfo.SourceRoots) - 1 do
    AppendUniqueProjectUnitRootInfo(
      Result,
      BuildProjectUnitRootInfo(
        ManifestInfo.SourceRoots[RootIndex],
        'nearest-package-manifest-source-root',
        ManifestInfo.PackageName,
        ManifestInfo.ManifestPath,
        ''
      )
    );

  WorkspaceMemberRoots := ResolveWorkspaceMemberRootInfos(AWorkspaceRootPath);
  for RootIndex := 0 to Length(WorkspaceMemberRoots) - 1 do
    AppendUniqueProjectUnitRootInfo(Result, WorkspaceMemberRoots[RootIndex]);
end;

function ResolvePackageSourceRoots(
  const AResolvedSourcePath: string;
  const AWorkspaceRootPath: string
): TStringArray;
var
  RootInfos: TProjectUnitRootInfoArray;
  RootIndex: LongInt;
begin
  Result := nil;
  SetLength(Result, 0);

  RootInfos := ResolveProjectUnitRootInfos(
    AResolvedSourcePath,
    AWorkspaceRootPath
  );
  for RootIndex := 0 to Length(RootInfos) - 1 do
    AppendUniqueString(Result, RootInfos[RootIndex].RootPath);
end;

function ResolveWorkspacePackageManifestInfos(
  const AResolvedSourcePath: string;
  const AWorkspaceRootPath: string
): TPackageManifestInfoArray;
var
  ManifestInfo: TPackageManifestInfo;
  WorkspaceMemberInfos: TPackageManifestInfoArray;
  PackageIndex: LongInt;
begin
  Result := nil;
  SetLength(Result, 0);

  ManifestInfo := ResolveNearestPackageManifestInfo(
    AResolvedSourcePath,
    AWorkspaceRootPath
  );
  AppendUniquePackageManifestInfo(Result, ManifestInfo);

  WorkspaceMemberInfos := ResolveWorkspaceMemberPackageInfos(AWorkspaceRootPath);
  for PackageIndex := 0 to Length(WorkspaceMemberInfos) - 1 do
    AppendUniquePackageManifestInfo(Result, WorkspaceMemberInfos[PackageIndex]);
end;

end.
