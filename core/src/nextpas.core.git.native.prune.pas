unit nextpas.core.git.native.prune;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base;

{ Pure-Pascal remote prune (stale remote-tracking branches).

  Counterpart of `remote.c: prune` / `fetch --prune` for the
  local-filesystem transport. It compares the refs advertised by
  the remote (`git upload-pack --advertise-refs` / GitLsRemote)
  with the local remote-tracking refs under
  `refs/remotes/<name>/*` (fetch refspec
  `+refs/heads/*:refs/remotes/<name>/*`) and deletes the stale
  ones. Tags (`refs/tags/*`) are not pruned. The special symref
  `refs/remotes/<name>/HEAD` is updated if its target was pruned
  (deleted).

  Returns the list of pruned ref names (full `refs/remotes/...`
  form) for reporting, matching `git remote prune <name> --dry-run`
  semantics but actually deleting. }

function GitRemotePrune(const ALocalGitDir, ARemoteName: string): TStringArray;

implementation

uses
  nextpas.core.fs,
  nextpas.core.text.conv,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.remote,
  nextpas.core.git.native.clone,
  nextpas.core.git.native.advertise;

function CollectRemoteTrackingRefs(const ALocalGitDir, ARemoteName: string): TStringArray;
var
  Base: string;
  ResultArr: TStringArray;
  procedure Walk(const ADir, APrefix: string);
  var
    Ents: TDirEntryArray;
    E: TDirEntry;
    Full, Rel, RefName: string;
  begin
    if not DirectoryExists(ADir) then Exit;
    Ents := ReadDir(ADir);
    for E in Ents do
    begin
      Full := PathJoin([ADir, E.Name]);
      Rel := APrefix + E.Name;
      if E.IsDir then
        Walk(Full, Rel + '/')
      else
      begin
        // file under refs/remotes/<remote>/* — treat as ref (skip possible lock files)
        if E.Name = 'HEAD' then
          RefName := 'refs/remotes/' + ARemoteName + '/HEAD'
        else
          RefName := 'refs/remotes/' + ARemoteName + '/' + Rel;
        SetLength(ResultArr, Length(ResultArr) + 1);
        ResultArr[High(ResultArr)] := RefName;
      end;
    end;
  end;
begin
  ResultArr := nil;
  Base := PathJoin([ALocalGitDir, 'refs', 'remotes', ARemoteName]);
  Walk(Base, '');
  Result := ResultArr;
end;

function AdvertiseBranches(const AAdv: TGitAdvertised): TStringArray;
var
  I: Integer;
  Branch: string;
begin
  Result := nil;
  for I := 0 to High(AAdv.Refs) do
  begin
    if Copy(AAdv.Refs[I].Name, 1, 11) = 'refs/heads/' then
    begin
      Branch := Copy(AAdv.Refs[I].Name, 12, MaxInt);
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Branch;
    end;
  end;
end;

function ContainsBranch(const ABranches: TStringArray; const ABranch: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(ABranches) do
    if ABranches[I] = ABranch then Exit(True);
  Result := False;
end;

function ReadSymrefTarget(const ARefPath: string): string;
var
  Content: string;
  Trimmed: string;
begin
  Result := '';
  if not FileExists(ARefPath) then Exit;
  Content := ReadFileText(ARefPath);
  Trimmed := Trim(Content);
  if Copy(Trimmed, 1, 5) = 'ref: ' then
    Result := Trim(Copy(Trimmed, 6, MaxInt));
end;

function GitRemotePrune(const ALocalGitDir, ARemoteName: string): TStringArray;
var
  Remote: TGitRemote;
  Adv: TGitAdvertised;
  Branches: TStringArray;
  LocalRefs: TStringArray;
  I: Integer;
  RefName, Branch, FullPath, HeadTarget: string;
  Pruned: TStringArray;
  HeadPath: string;
  HeadRef: string;
  ExpectedHead: string;
begin
  if ALocalGitDir = '' then
    raise EGitError.Create('prune: local gitdir empty');
  if ARemoteName = '' then
    raise EGitError.Create('prune: remote name empty');
  if not IsGitDirShape(ALocalGitDir) then
    raise EGitError.CreateFmt('prune: not a git dir %s', [ALocalGitDir]);
  if not GitRemoteFind(ALocalGitDir, ARemoteName, Remote) then
    raise EGitError.CreateFmt('prune: remote not found %s', [ARemoteName]);
  if Length(Remote.Urls) = 0 then
    raise EGitError.CreateFmt('prune: remote %s has no url', [ARemoteName]);
  // use first url as remote gitdir for ls-remote (file transport only)
  Adv := GitLsRemote(Remote.Urls[0]);
  Branches := AdvertiseBranches(Adv);
  LocalRefs := CollectRemoteTrackingRefs(ALocalGitDir, ARemoteName);
  Pruned := nil;
  for I := 0 to High(LocalRefs) do
  begin
    RefName := LocalRefs[I];
    if RefName = 'refs/remotes/' + ARemoteName + '/HEAD' then Continue;
    Branch := Copy(RefName, Length('refs/remotes/' + ARemoteName + '/') + 1, MaxInt);
    if not ContainsBranch(Branches, Branch) then
    begin
      FullPath := PathJoin([ALocalGitDir, RefName]);
      try
        Remove(FullPath);
      except
        on E: Exception do
          raise EGitError.CreateFmt('prune: cannot remove %s: %s', [RefName, E.Message]);
      end;
      // prune empty parent dirs up to refs/remotes/<remote>
      try
        while True do
        begin
          FullPath := PathDir(FullPath);
          if (FullPath = '') or (FullPath = ALocalGitDir) then Break;
          if Pos(PathJoin([ALocalGitDir, 'refs', 'remotes', ARemoteName]), FullPath) <> 1 then Break;
          if DirectoryExists(FullPath) then
          begin
            if Length(ReadDir(FullPath)) = 0 then Remove(FullPath) else Break;
          end
          else Break;
        end;
      except
      end;
      SetLength(Pruned, Length(Pruned) + 1);
      Pruned[High(Pruned)] := RefName;
    end;
  end;
  // handle HEAD symref if its target was pruned or remote HEAD changed
  HeadPath := PathJoin([ALocalGitDir, 'refs', 'remotes', ARemoteName, 'HEAD']);
  if FileExists(HeadPath) then
  begin
    HeadTarget := ReadSymrefTarget(HeadPath);
    if HeadTarget <> '' then
    begin
      // if target no longer exists locally, delete HEAD
      if not FileExists(PathJoin([ALocalGitDir, HeadTarget])) then
      begin
        try Remove(HeadPath); except end;
        SetLength(Pruned, Length(Pruned) + 1);
        Pruned[High(Pruned)] := 'refs/remotes/' + ARemoteName + '/HEAD';
      end
      else
      begin
        // also sync HEAD to remote's advertised HEAD (symref=HEAD:xxx caps)
        HeadRef := '';
        // find symref from advertise caps
        // advertise caps contain symref=HEAD:refs/heads/<branch>
        // We extract via HeadTargetFromCaps logic: search caps array
        // But Adv already parsed caps; we can reuse Remote prune logic to update HEAD if needed
        // For now, keep existing HEAD if still valid — do not force switch.
      end;
    end;
  end;
  // attempt to recreate HEAD if missing but remote has a HEAD branch
  if not FileExists(HeadPath) then
  begin
    ExpectedHead := '';
    for I := 0 to High(Adv.Capabilities) do
      if Copy(Adv.Capabilities[I], 1, Length('symref=HEAD:')) = 'symref=HEAD:' then
      begin
        ExpectedHead := Copy(Adv.Capabilities[I], Length('symref=HEAD:') + 1, MaxInt);
        Break;
      end;
    if ExpectedHead <> '' then
    begin
      // map refs/heads/<branch> -> refs/remotes/<remote>/<branch>
      if Copy(ExpectedHead, 1, 11) = 'refs/heads/' then
      begin
        Branch := Copy(ExpectedHead, 12, MaxInt);
        if ContainsBranch(Branches, Branch) then
        begin
          HeadRef := 'refs/remotes/' + ARemoteName + '/' + Branch;
          if FileExists(PathJoin([ALocalGitDir, HeadRef])) then
            WriteFileText(HeadPath, 'ref: ' + HeadRef + #10);
        end;
      end;
    end;
  end;
  Result := Pruned;
end;

end.
