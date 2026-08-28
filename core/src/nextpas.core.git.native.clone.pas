unit nextpas.core.git.native.clone;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.advertise;

{ Bare clone via local `git upload-pack` stateless RPC.

  Pure-Pascal counterpart of `clone.c` / `transport` local clone path.
  It advertises refs from a local gitdir (`git upload-pack --advertise-refs`),
  fetches all reachable objects in one pack (`GitFetchPack` + `GitBuildPackIndex`),
  materializes a minimal bare repository (objects/pack, refs, HEAD, config)
  and leaves the pack verification to `git verify-pack`.

  Non-bare checkout (worktree + index) is handled by `GitClone` which
  clones into `<worktree>/.git` with `bare=false` and then materializes
  the HEAD tree into the worktree and builds a v2 index so that
  `git status --porcelain` is clean and the pack remains the object store. }

function GitLsRemote(const ARemoteGitDir: string): TGitAdvertised;
function GitCloneBare(const ARemoteGitDir, ALocalGitDir: string): TGitOid;
function GitCloneBareHead(const ARemoteGitDir, ALocalGitDir: string): string; inline;
function GitClone(const ARemoteGitDir, ALocalWorkTree: string): TGitOid;
function GitCloneHead(const ARemoteGitDir, ALocalWorkTree: string): string; inline;

implementation

uses
  nextpas.core.fs,
  nextpas.core.process,
  nextpas.core.text.conv,
  nextpas.core.git.native.pktline,
  nextpas.core.git.native.fetch,
  nextpas.core.git.native.indexer,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.checkout;

function BytesToHexLower(const B: TBytes): string;
const Hex: array[0..15] of Char = ('0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f');
var I: Integer;
begin
  SetLength(Result, Length(B) * 2);
  for I := 0 to High(B) do
  begin
    Result[I*2+1] := Hex[(B[I] shr 4) and $F];
    Result[I*2+2] := Hex[B[I] and $F];
  end;
end;

function PackTrailerHex(const APack: TBytes): string;
var Trailer: TBytes;
begin
  if Length(APack) < 20 then
    raise EGitError.Create('clone: pack too short for trailer');
  SetLength(Trailer, 20);
  Move(APack[Length(APack)-20], Trailer[0], 20);
  Result := BytesToHexLower(Trailer);
end;

function ContainsOid(const AArr: array of TGitOid; const AOid: TGitOid): Boolean;
var I: Integer;
begin
  for I := 0 to High(AArr) do
    if GitOidSame(AArr[I], AOid) then Exit(True);
  Result := False;
end;

function IsDirEmpty(const APath: string): Boolean;
var Ents: TDirEntryArray;
begin
  if not DirectoryExists(APath) then Exit(True);
  Ents := ReadDir(APath);
  Result := Length(Ents) = 0;
end;

function HeadTargetFromCaps(const ACaps: TStringArray): string;
var I: Integer;
    Cap: string;
begin
  Result := '';
  for I := 0 to High(ACaps) do
  begin
    Cap := ACaps[I];
    if Copy(Cap, 1, Length('symref=HEAD:')) = 'symref=HEAD:' then
      Exit(Copy(Cap, Length('symref=HEAD:')+1, MaxInt));
  end;
end;

function StrippedBranchName(const ARef: string): string;
begin
  if Copy(ARef, 1, 11) = 'refs/heads/' then
    Result := Copy(ARef, 12, MaxInt)
  else
    Result := ARef;
end;

function GitLsRemote(const ARemoteGitDir: string): TGitAdvertised;
var Out_: TProcessOutput;
    Raw: TBytes;
begin
  if not DirectoryExists(ARemoteGitDir) and not FileExists(ARemoteGitDir) then
    raise EGitError.CreateFmt('ls-remote: remote not found %s', [ARemoteGitDir]);
  Out_ := Run('git', ['upload-pack', '--advertise-refs', ARemoteGitDir]);
  if not ProcessSucceeded(Out_) then
    raise EGitError.CreateFmt('advertise failed (%d): %s', [Out_.ExitCode, Trim(Out_.StdErr + Out_.StdOut)]);
  Raw := GitStringToBytes(Out_.StdOut);
  Result := GitParseAdvertise(Raw);
  if Length(Result.Refs) = 0 then
    raise EGitError.CreateFmt('ls-remote: no refs advertised from %s', [ARemoteGitDir]);
end;

procedure DoCloneCore(const ARemoteGitDir, ALocalGitDir: string; ABare: Boolean;
  out AAdv: TGitAdvertised; out AHeadTarget: string; out AHeadOid: TGitOid);
var Wants: array of TGitOid;
    I: Integer;
    Pack, Idx: TBytes;
    PackHash, PackPath, IdxPath, RefPath, ConfigText: string;
    NeedMkdir: string;
begin
  if not DirectoryExists(ARemoteGitDir) and not FileExists(ARemoteGitDir) then
    raise EGitError.CreateFmt('clone: remote not found %s', [ARemoteGitDir]);
  if ALocalGitDir = '' then
    raise EGitError.Create('clone: local path empty');
  if FileExists(ALocalGitDir) then
    raise EGitError.CreateFmt('clone: local path exists as file %s', [ALocalGitDir]);

  MkdirAll(ALocalGitDir, PermDirDefault);
  MkdirAll(PathJoin([ALocalGitDir, 'objects', 'pack']), PermDirDefault);
  MkdirAll(PathJoin([ALocalGitDir, 'objects', 'info']), PermDirDefault);
  MkdirAll(PathJoin([ALocalGitDir, 'refs', 'heads']), PermDirDefault);
  MkdirAll(PathJoin([ALocalGitDir, 'refs', 'tags']), PermDirDefault);
  MkdirAll(PathJoin([ALocalGitDir, 'info']), PermDirDefault);

  AAdv := GitLsRemote(ARemoteGitDir);

  SetLength(Wants, 0);
  for I := 0 to High(AAdv.Refs) do
  begin
    if (Length(AAdv.Refs[I].Name) >= 3) and (Copy(AAdv.Refs[I].Name, Length(AAdv.Refs[I].Name)-2, 3) = '^{}') then
      Continue;
    if not ContainsOid(Wants, AAdv.Refs[I].Oid) then
    begin
      SetLength(Wants, Length(Wants)+1);
      Wants[High(Wants)] := AAdv.Refs[I].Oid;
    end;
  end;
  if Length(Wants) = 0 then
    raise EGitError.Create('clone: no wants to fetch');

  Pack := GitFetchPack(ARemoteGitDir, Wants);
  if Length(Pack) < 12 + 20 then
    raise EGitError.Create('clone: fetched pack too short');
  if (Pack[0] <> Ord('P')) or (Pack[1] <> Ord('A')) or (Pack[2] <> Ord('C')) or (Pack[3] <> Ord('K')) then
    raise EGitError.Create('clone: invalid pack header');

  Idx := GitBuildPackIndex(Pack);
  PackHash := PackTrailerHex(Pack);
  PackPath := PathJoin([ALocalGitDir, 'objects', 'pack', 'pack-' + PackHash + '.pack']);
  IdxPath := GitPackIndexPath(PackPath);
  WriteAtomic(PackPath, Pack);
  WriteAtomic(IdxPath, Idx);

  for I := 0 to High(AAdv.Refs) do
  begin
    if (Length(AAdv.Refs[I].Name) >= 3) and (Copy(AAdv.Refs[I].Name, Length(AAdv.Refs[I].Name)-2, 3) = '^{}') then
      Continue;
    RefPath := PathJoin([ALocalGitDir, AAdv.Refs[I].Name]);
    NeedMkdir := PathDir(RefPath);
    if NeedMkdir <> '' then MkdirAll(NeedMkdir, PermDirDefault);
    WriteFileText(RefPath, GitOidToHex(AAdv.Refs[I].Oid) + #10);
  end;

  AHeadTarget := HeadTargetFromCaps(AAdv.Capabilities);
  if AHeadTarget = '' then
    for I := 0 to High(AAdv.Refs) do
      if (Copy(AAdv.Refs[I].Name, 1, 11) = 'refs/heads/') and not ((Length(AAdv.Refs[I].Name) >= 3) and (Copy(AAdv.Refs[I].Name, Length(AAdv.Refs[I].Name)-2, 3) = '^{}')) then
      begin AHeadTarget := AAdv.Refs[I].Name; Break; end;

  if AHeadTarget <> '' then
    WriteFileText(PathJoin([ALocalGitDir, 'HEAD']), 'ref: ' + AHeadTarget + #10)
  else
  begin
    for I := 0 to High(AAdv.Refs) do
      if not ((Length(AAdv.Refs[I].Name) >= 3) and (Copy(AAdv.Refs[I].Name, Length(AAdv.Refs[I].Name)-2, 3) = '^{}')) then
      begin
        WriteFileText(PathJoin([ALocalGitDir, 'HEAD']), GitOidToHex(AAdv.Refs[I].Oid) + #10);
        Break;
      end;
    if not FileExists(PathJoin([ALocalGitDir, 'HEAD'])) then
      WriteFileText(PathJoin([ALocalGitDir, 'HEAD']), GitOidToHex(AAdv.Refs[0].Oid) + #10);
  end;

  if ABare then
    ConfigText :=
      '[core]'#10 +
      #9'repositoryformatversion = 0'#10 +
      #9'filemode = true'#10 +
      #9'bare = true'#10 +
      '[remote "origin"]'#10 +
      #9'url = ' + ARemoteGitDir + #10 +
      #9'fetch = +refs/heads/*:refs/remotes/origin/*'#10
  else
  begin
    ConfigText :=
      '[core]'#10 +
      #9'repositoryformatversion = 0'#10 +
      #9'filemode = true'#10 +
      #9'bare = false'#10 +
      #9'logallrefupdates = true'#10 +
      '[remote "origin"]'#10 +
      #9'url = ' + ARemoteGitDir + #10 +
      #9'fetch = +refs/heads/*:refs/remotes/origin/*'#10;
    if AHeadTarget <> '' then
      ConfigText := ConfigText +
        '[branch "' + StrippedBranchName(AHeadTarget) + '"]'#10 +
        #9'remote = origin'#10 +
        #9'merge = ' + AHeadTarget + #10;
  end;
  WriteFileText(PathJoin([ALocalGitDir, 'config']), ConfigText);

  WriteFileText(PathJoin([ALocalGitDir, 'description']), 'Unnamed repository'#10);
  WriteFileText(PathJoin([ALocalGitDir, 'info', 'exclude']), '# git ls-files --others --exclude-from=...'#10);

  if AHeadTarget <> '' then
  begin
    for I := 0 to High(AAdv.Refs) do
      if AAdv.Refs[I].Name = AHeadTarget then
      begin AHeadOid := AAdv.Refs[I].Oid; Exit; end;
  end;
  for I := 0 to High(AAdv.Refs) do
    if not ((Length(AAdv.Refs[I].Name) >= 3) and (Copy(AAdv.Refs[I].Name, Length(AAdv.Refs[I].Name)-2, 3) = '^{}')) then
    begin AHeadOid := AAdv.Refs[I].Oid; Exit; end;
  AHeadOid := AAdv.Refs[0].Oid;
end;

function GitCloneBare(const ARemoteGitDir, ALocalGitDir: string): TGitOid;
var Adv: TGitAdvertised;
    HeadTarget: string;
    HeadOid: TGitOid;
begin
  if ALocalGitDir = '' then
    raise EGitError.Create('clone: local path empty');
  if FileExists(ALocalGitDir) then
    raise EGitError.CreateFmt('clone: local path exists as file %s', [ALocalGitDir]);
  if DirectoryExists(ALocalGitDir) and not IsDirEmpty(ALocalGitDir) then
    raise EGitError.CreateFmt('clone: local dir not empty %s', [ALocalGitDir]);
  DoCloneCore(ARemoteGitDir, ALocalGitDir, True, Adv, HeadTarget, HeadOid);
  Result := HeadOid;
end;

function GitCloneBareHead(const ARemoteGitDir, ALocalGitDir: string): string;
begin
  Result := GitOidToHex(GitCloneBare(ARemoteGitDir, ALocalGitDir));
end;

function GitClone(const ARemoteGitDir, ALocalWorkTree: string): TGitOid;
var Adv: TGitAdvertised;
    HeadTarget: string;
    HeadOid: TGitOid;
    GitDir, RefPath, NeedMkdir: string;
    I: Integer;
    BranchName: string;
begin
  if ALocalWorkTree = '' then
    raise EGitError.Create('clone: worktree path empty');
  if FileExists(ALocalWorkTree) then
    raise EGitError.CreateFmt('clone: worktree path exists as file %s', [ALocalWorkTree]);
  if DirectoryExists(ALocalWorkTree) and not IsDirEmpty(ALocalWorkTree) then
    raise EGitError.CreateFmt('clone: worktree dir not empty %s', [ALocalWorkTree]);

  MkdirAll(ALocalWorkTree, PermDirDefault);
  GitDir := PathJoin([ALocalWorkTree, '.git']);

  DoCloneCore(ARemoteGitDir, GitDir, False, Adv, HeadTarget, HeadOid);

  { mirror branches to refs/remotes/origin/* and create remote HEAD symref }
  MkdirAll(PathJoin([GitDir, 'refs', 'remotes', 'origin']), PermDirDefault);
  for I := 0 to High(Adv.Refs) do
  begin
    if (Length(Adv.Refs[I].Name) >= 3) and (Copy(Adv.Refs[I].Name, Length(Adv.Refs[I].Name)-2, 3) = '^{}') then
      Continue;
    if Copy(Adv.Refs[I].Name, 1, 11) = 'refs/heads/' then
    begin
      BranchName := Copy(Adv.Refs[I].Name, 12, MaxInt);
      RefPath := PathJoin([GitDir, 'refs', 'remotes', 'origin', BranchName]);
      NeedMkdir := PathDir(RefPath);
      if NeedMkdir <> '' then MkdirAll(NeedMkdir, PermDirDefault);
      WriteFileText(RefPath, GitOidToHex(Adv.Refs[I].Oid) + #10);
    end;
  end;
  if HeadTarget <> '' then
  begin
    BranchName := StrippedBranchName(HeadTarget);
    WriteFileText(PathJoin([GitDir, 'refs', 'remotes', 'origin', 'HEAD']), 'ref: refs/remotes/origin/' + BranchName + #10);
  end;

  GitCheckoutHead(GitDir, ALocalWorkTree);
  Result := HeadOid;
end;

function GitCloneHead(const ARemoteGitDir, ALocalWorkTree: string): string;
begin
  Result := GitOidToHex(GitClone(ARemoteGitDir, ALocalWorkTree));
end;

end.
