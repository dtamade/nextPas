unit np_package_manifest;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TPackageManifestInfo = record
    ManifestPath: string;
    PackageRootPath: string;
    PackageName: string;
    SourceRoots: TStringArray;
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

procedure AppendString(var AValues: TStringArray; const AValue: string);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(AValues);
  SetLength(AValues, NextIndex + 1);
  AValues[NextIndex] := AValue;
end;

procedure AppendUniqueString(var AValues: TStringArray; const AValue: string);
var
  Index: SizeInt;
begin
  for Index := 0 to Length(AValues) - 1 do
    if AValues[Index] = AValue then
      Exit;

  AppendString(AValues, AValue);
end;

procedure AppendUniqueProjectUnitRootInfo(
  var AValues: TProjectUnitRootInfoArray;
  const AValue: TProjectUnitRootInfo
);
var
  Index: SizeInt;
  NextIndex: SizeInt;
begin
  for Index := 0 to Length(AValues) - 1 do
    if AValues[Index].RootPath = AValue.RootPath then
      Exit;

  NextIndex := Length(AValues);
  SetLength(AValues, NextIndex + 1);
  AValues[NextIndex] := AValue;
end;

procedure AppendUniquePackageManifestInfo(
  var AValues: TPackageManifestInfoArray;
  const AValue: TPackageManifestInfo
);
var
  Index: SizeInt;
  NextIndex: SizeInt;
begin
  if Trim(AValue.ManifestPath) = '' then
    Exit;

  for Index := 0 to Length(AValues) - 1 do
    if AValues[Index].ManifestPath = AValue.ManifestPath then
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

function DirectoryPrefix(const APath: string): string;
begin
  Result := IncludeTrailingPathDelimiter(ExpandFileName(APath));
end;

function IsWithinDirectory(
  const APath: string;
  const ADirectory: string
): Boolean;
var
  CandidatePath: string;
  DirectoryPath: string;
begin
  DirectoryPath := DirectoryPrefix(ADirectory);
  CandidatePath := ExpandFileName(APath);
  if CandidatePath = ExcludeTrailingPathDelimiter(DirectoryPath) then
    Exit(True);

  Result := Pos(DirectoryPath, IncludeTrailingPathDelimiter(CandidatePath)) = 1;
end;

function StripTomlComment(const ALine: string): string;
var
  Index: SizeInt;
  InString: Boolean;
begin
  Result := '';
  InString := False;
  for Index := 1 to Length(ALine) do
  begin
    if ALine[Index] = '"' then
      InString := not InString
    else if (ALine[Index] = '#') and not InString then
      Break;

    Result := Result + ALine[Index];
  end;
end;

function ParseTomlStringArray(const AValue: string): TStringArray;
var
  Content: string;
  Index: SizeInt;
  CurrentItem: string;
  InString: Boolean;
  TrimmedItem: string;
begin
  Result := nil;
  SetLength(Result, 0);

  Content := Trim(AValue);
  if (Length(Content) < 2) or (Content[1] <> '[') or
    (Content[Length(Content)] <> ']') then
    Exit;

  Content := Trim(Copy(Content, 2, Length(Content) - 2));
  if Content = '' then
    Exit;

  CurrentItem := '';
  InString := False;
  for Index := 1 to Length(Content) do
  begin
    if Content[Index] = '"' then
      InString := not InString;

    if (Content[Index] = ',') and not InString then
    begin
      TrimmedItem := Trim(CurrentItem);
      if (Length(TrimmedItem) >= 2) and (TrimmedItem[1] = '"') and
        (TrimmedItem[Length(TrimmedItem)] = '"') then
        AppendString(
          Result,
          Copy(TrimmedItem, 2, Length(TrimmedItem) - 2)
        );
      CurrentItem := '';
      Continue;
    end;

    CurrentItem := CurrentItem + Content[Index];
  end;

  TrimmedItem := Trim(CurrentItem);
  if (Length(TrimmedItem) >= 2) and (TrimmedItem[1] = '"') and
    (TrimmedItem[Length(TrimmedItem)] = '"') then
    AppendString(
      Result,
      Copy(TrimmedItem, 2, Length(TrimmedItem) - 2)
    );
end;

function BuildProjectUnitRootInfo(
  const ARootPath: string;
  const AProvenanceKind: string;
  const APackageName: string;
  const AManifestPath: string;
  const AWorkspaceMemberPath: string
): TProjectUnitRootInfo;
begin
  Result.RootPath := ExpandFileName(ARootPath);
  Result.ScopeName := 'package-source-root';
  if Trim(AProvenanceKind) <> '' then
    Result.ProvenanceKind := AProvenanceKind
  else
    Result.ProvenanceKind := Result.ScopeName;
  Result.PackageName := APackageName;
  if Trim(AManifestPath) <> '' then
    Result.ManifestPath := ExpandFileName(AManifestPath)
  else
    Result.ManifestPath := '';
  if Trim(AWorkspaceMemberPath) <> '' then
    Result.WorkspaceMemberPath := ExpandFileName(AWorkspaceMemberPath)
  else
    Result.WorkspaceMemberPath := '';
end;

function FindNearestPackageManifest(
  const AResolvedSourcePath: string;
  const AWorkspaceRootPath: string
): string;
var
  CandidateDirectory: string;
  ParentDirectory: string;
  WorkspaceRoot: string;
  ManifestPath: string;
begin
  CandidateDirectory := ExpandFileName(ExtractFileDir(AResolvedSourcePath));
  WorkspaceRoot := '';
  if Trim(AWorkspaceRootPath) <> '' then
    WorkspaceRoot := ExpandFileName(AWorkspaceRootPath);

  while CandidateDirectory <> '' do
  begin
    ManifestPath := IncludeTrailingPathDelimiter(CandidateDirectory) +
      'nextpas.package.toml';
    if FileExists(ManifestPath) then
      Exit(ExpandFileName(ManifestPath));

    if (WorkspaceRoot <> '') and
      (CandidateDirectory = ExcludeTrailingPathDelimiter(WorkspaceRoot)) then
      Break;

    ParentDirectory := ExpandFileName(
      IncludeTrailingPathDelimiter(CandidateDirectory) + '..'
    );
    if ParentDirectory = CandidateDirectory then
      Break;
    if (WorkspaceRoot <> '') and not IsWithinDirectory(ParentDirectory, WorkspaceRoot) then
      Break;
    CandidateDirectory := ParentDirectory;
  end;

  Result := '';
end;

function LoadPackageManifestInfo(
  const AManifestPath: string
): TPackageManifestInfo;
var
  CurrentSection: string;
  EntryIndex: LongInt;
  EqPos: SizeInt;
  KeyName: string;
  LineIndex: LongInt;
  Lines: TStringList;
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
  Result.SourceRoots := nil;
  SetLength(Result.SourceRoots, 0);

  ManifestPath := ExpandFileName(AManifestPath);
  if not FileExists(ManifestPath) then
    Exit;

  Result.ManifestPath := ManifestPath;
  ManifestDirectory := ExtractFileDir(ManifestPath);
  Result.PackageRootPath := ExpandFileName(ManifestDirectory);
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(ManifestPath);
    CurrentSection := '';
    for LineIndex := 0 to Lines.Count - 1 do
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
        if (Length(Result.PackageName) >= 2) and
          (Result.PackageName[1] = '"') and
          (Result.PackageName[Length(Result.PackageName)] = '"') then
          Result.PackageName := Copy(
            Result.PackageName,
            2,
            Length(Result.PackageName) - 2
          );
        Continue;
      end;

      if (CurrentSection <> 'sources') or (KeyName <> 'roots') then
        Continue;

      RootEntries := ParseTomlStringArray(Copy(TrimmedLine, EqPos + 1, MaxInt));
      for EntryIndex := 0 to Length(RootEntries) - 1 do
      begin
        if IsAbsolutePath(RootEntries[EntryIndex]) then
          ResolvedRoot := ExpandFileName(RootEntries[EntryIndex])
        else
          ResolvedRoot := ExpandFileName(
            IncludeTrailingPathDelimiter(ManifestDirectory) + RootEntries[EntryIndex]
          );

        if DirectoryExists(ResolvedRoot) then
          AppendUniqueString(Result.SourceRoots, ResolvedRoot);
      end;
    end;
  finally
    Lines.Free;
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
  Lines: TStringList;
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
  if not FileExists(WorkspaceDescriptorPath) then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(WorkspaceDescriptorPath);
    CurrentSection := '';
    for LineIndex := 0 to Lines.Count - 1 do
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
        if not FileExists(MemberManifestPath) then
          Continue;

        PackageInfo := LoadPackageManifestInfo(MemberManifestPath);
        PackageInfo.PackageRootPath := ExpandFileName(MemberRootPath);
        AppendUniquePackageManifestInfo(Result, PackageInfo);
      end;
    end;
  finally
    Lines.Free;
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
    Result.SourceRoots := nil;
    SetLength(Result.SourceRoots, 0);
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
