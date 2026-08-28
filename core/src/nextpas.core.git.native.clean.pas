unit nextpas.core.git.native.clean;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base;

{ Pure-Pascal git clean (untracked files/dirs removal).

  Counterpart of `clean.c` / `git clean -f [-d] [-x]`.
  It reuses the ignore matcher from status (info/exclude +
  core.excludesFile + per-dir .gitignore) and the index-tracked set.

  - Default `GitClean(GitDir, WorkTree)` removes untracked files
    that are *not* ignored (like `git clean -f`), leaves
    ignored files and untracked directories untouched.
  - `ARemoveDirs=True`  adds `-d` semantics: untracked directories
    (not containing tracked descendents) are removed wholesale.
  - `ARemoveIgnored=True` adds `-x` semantics: ignored untracked
    files/dirs are also removed (otherwise they are kept and
    ignored directories are pruned).
  - `ADryRun=True` collects without touching the filesystem
    (like `git clean -n`).

  Returns the list of removed (or would-be) worktree-relative
  paths, sorted. Directories are reported with their own path
  (not expanded). }

function GitClean(const AGitDir, AWorkTree: string): TStringArray; overload;
function GitClean(const AGitDir, AWorkTree: string;
  ARemoveDirs: Boolean): TStringArray; overload;
function GitClean(const AGitDir, AWorkTree: string;
  ARemoveDirs, ARemoveIgnored: Boolean): TStringArray; overload;
function GitClean(const AGitDir, AWorkTree: string;
  ARemoveDirs, ARemoveIgnored, ADryRun: Boolean): TStringArray; overload;

implementation

uses
  nextpas.core.fs,
  nextpas.core.text.conv,
  nextpas.core.git.native.base,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.index,
  nextpas.core.git.native.ignore,
  nextpas.core.git.native.config,
  nextpas.core.os.env;

procedure PushBaseIgnores(AIgnore: TGitIgnoreMatcher; const AGitDir: string);
var
  ExcludeFile: string;
  Cfg: TGitConfig;
  GlobalPath: string;
  Expanded: string;
begin
  ExcludeFile := PathJoin([AGitDir, 'info', 'exclude']);
  if Exists(ExcludeFile) then
    try
      AIgnore.PushSource('', ReadFileText(ExcludeFile));
    except
    end;
  try
    Cfg := GitReadConfig(AGitDir);
    GlobalPath := Trim(GitConfigGet(Cfg, 'core.excludesfile'));
  except
    GlobalPath := '';
  end;
  if GlobalPath = '' then Exit;
  if (Length(GlobalPath) > 0) and (GlobalPath[1] = '~') then
  begin
    if GlobalPath = '~' then Expanded := GetEnv('HOME')
    else if (Length(GlobalPath) >= 2) and (GlobalPath[2] = '/') then
      Expanded := PathJoin([GetEnv('HOME'), Copy(GlobalPath, 3, MaxInt)])
    else Expanded := GlobalPath;
    GlobalPath := Expanded;
  end;
  if Exists(GlobalPath) then
    try
      AIgnore.PushSource('', ReadFileText(GlobalPath));
    except
    end;
end;

function SortedHasString(const ASorted: TStringArray; const AValue: string): Boolean;
var
  Lo, Hi, Mid: Integer;
begin
  Result := False;
  Lo := 0; Hi := High(ASorted);
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    if ASorted[Mid] = AValue then Exit(True);
    if ASorted[Mid] < AValue then Lo := Mid + 1 else Hi := Mid - 1;
  end;
end;

function HasTrackedDescendant(const ASorted: TStringArray; const ADir: string): Boolean;
var
  Lo, Hi, Mid: Integer;
  Prefix: string;
  Found: Integer;
  I: Integer;
begin
  Result := False;
  if Length(ASorted) = 0 then Exit;
  Prefix := ADir + '/';
  // binary search for first >= Prefix
  Lo := 0; Hi := High(ASorted);
  Found := Length(ASorted);
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    if ASorted[Mid] >= Prefix then
    begin
      Found := Mid;
      Hi := Mid - 1;
    end
    else
      Lo := Mid + 1;
  end;
  if Found >= Length(ASorted) then Exit;
  // check if ASorted[Found] starts with Prefix
  if (Length(ASorted[Found]) > Length(Prefix)) and (Copy(ASorted[Found], 1, Length(Prefix)) = Prefix) then
    Exit(True);
  Result := False;
end;

procedure SortStrings(var AList: TStringArray);
  procedure MergeSort(var AItems, ATemp: TStringArray; ALo, AHi: Integer);
  var
    Mid, I, J, K: Integer;
  begin
    if ALo >= AHi then Exit;
    Mid := (ALo + AHi) div 2;
    MergeSort(AItems, ATemp, ALo, Mid);
    MergeSort(AItems, ATemp, Mid + 1, AHi);
    I := ALo; J := Mid + 1;
    for K := ALo to AHi do
    begin
      if (I <= Mid) and ((J > AHi) or (AItems[I] <= AItems[J])) then
      begin ATemp[K] := AItems[I]; Inc(I); end
      else
      begin ATemp[K] := AItems[J]; Inc(J); end;
    end;
    for K := ALo to AHi do AItems[K] := ATemp[K];
  end;
var
  Temp: TStringArray;
begin
  if Length(AList) < 2 then Exit;
  SetLength(Temp, Length(AList));
  MergeSort(AList, Temp, 0, Length(AList) - 1);
end;

function GitClean(const AGitDir, AWorkTree: string;
  ARemoveDirs, ARemoveIgnored, ADryRun: Boolean): TStringArray;
var
  Idx: TGitIndexFile;
  Tracked: TStringArray;
  Ignore: TGitIgnoreMatcher;
  Targets: TStringArray;
  I: Integer;
  Full: string;

  procedure Walk(const ADirRel: string);
  var
    DirAbs, IgnoreFile, Rel: string;
    HaveIgnore: Boolean;
    Ents: TDirEntryArray;
    E: TDirEntry;
    IsDir, IsIgnored, ShouldDelete: Boolean;
    IsTrackedFile, IsTrackedDir: Boolean;
  begin
    if ADirRel = '' then DirAbs := AWorkTree else DirAbs := PathJoin([AWorkTree, ADirRel]);
    IgnoreFile := PathJoin([DirAbs, '.gitignore']);
    HaveIgnore := Exists(IgnoreFile);
    if HaveIgnore then
      try
        Ignore.PushSource(ADirRel, ReadFileText(IgnoreFile));
      except
        HaveIgnore := False;
      end;
    try
      Ents := ReadDir(DirAbs);
      for E in Ents do
      begin
        if E.Name = '.git' then Continue;
        if ADirRel = '' then Rel := E.Name else Rel := ADirRel + '/' + E.Name;
        IsDir := E.IsDir;
        IsTrackedFile := SortedHasString(Tracked, Rel);
        IsTrackedDir := False;
        if IsDir then
          IsTrackedDir := HasTrackedDescendant(Tracked, Rel);
        if IsTrackedFile or IsTrackedDir then
        begin
          if IsDir then Walk(Rel);
          Continue;
        end;
        IsIgnored := Ignore.IsIgnored(Rel, IsDir);
        if IsIgnored then
          ShouldDelete := ARemoveIgnored
        else
          ShouldDelete := True;
        // When ShouldDelete includes ignored, both ignored and non-ignored are deletable.
        // For non-ignored case we already have ShouldDelete true.
        // But for ignored when not ShouldDelete, we prune ignored dirs.
        if not ShouldDelete then
        begin
          if IsDir and IsIgnored then Continue;
          if IsDir then Walk(Rel);
          Continue;
        end;
        if IsDir then
        begin
          if ARemoveDirs then
          begin
            SetLength(Targets, Length(Targets) + 1);
            Targets[High(Targets)] := Rel;
          end
          else
            Continue;
        end
        else
        begin
          SetLength(Targets, Length(Targets) + 1);
          Targets[High(Targets)] := Rel;
        end;
      end;
    finally
      if HaveIgnore then Ignore.PopSource;
    end;
  end;

begin
  if AGitDir = '' then raise EGitError.Create('clean: gitdir empty');
  if AWorkTree = '' then raise EGitError.Create('clean: worktree empty');
  if not IsGitDirShape(AGitDir) then raise EGitError.CreateFmt('clean: not a git dir %s', [AGitDir]);
  if not DirectoryExists(AWorkTree) then raise EGitError.CreateFmt('clean: worktree not found %s', [AWorkTree]);
  Idx := GitReadIndex(AGitDir);
  SetLength(Tracked, 0);
  for I := 0 to High(Idx.Entries) do
    if Idx.Entries[I].Stage = 0 then
      if (Length(Tracked) = 0) or (Tracked[High(Tracked)] <> Idx.Entries[I].Path) then
      begin
        SetLength(Tracked, Length(Tracked) + 1);
        Tracked[High(Tracked)] := Idx.Entries[I].Path;
      end;
  SortStrings(Tracked);
  Ignore := TGitIgnoreMatcher.Create;
  try
    PushBaseIgnores(Ignore, AGitDir);
    Targets := nil;
    Walk('');
    SortStrings(Targets);
    Result := Targets;
    if ADryRun then Exit;
    for I := 0 to High(Targets) do
    begin
      Full := PathJoin([AWorkTree, Targets[I]]);
      try
        if DirectoryExists(Full) then
          RemoveAll(Full)
        else if FileExists(Full) or IsSymlink(Full) then
          Remove(Full);
      except
        // ignore individual failures, continue
      end;
    end;
  finally
    Ignore.Free;
  end;
end;

function GitClean(const AGitDir, AWorkTree: string): TStringArray;
begin
  Result := GitClean(AGitDir, AWorkTree, False, False, False);
end;

function GitClean(const AGitDir, AWorkTree: string; ARemoveDirs: Boolean): TStringArray;
begin
  Result := GitClean(AGitDir, AWorkTree, ARemoveDirs, False, False);
end;

function GitClean(const AGitDir, AWorkTree: string; ARemoveDirs, ARemoveIgnored: Boolean): TStringArray;
begin
  Result := GitClean(AGitDir, AWorkTree, ARemoveDirs, ARemoveIgnored, False);
end;

end.
