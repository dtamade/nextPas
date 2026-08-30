unit nextpas.core.git.native.reset;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base;

{ Pure-Pascal reset --hard (object layer → worktree + index + ref).

  Counterpart of `reset.c` / `read-tree --reset -u` for the
  single-branch hard path. It reuses `checkout` for the filesystem
  materialization (type flips, orphan prune, executable bits, v2
  index) and then moves the current branch ref (or detached HEAD)
  to the target commit.

  Tag chains are peeled to the underlying commit exactly like
  `checkout`. The worktree must be the one belonging to AGitDir
  (typically <worktree> where <worktree>/.git = AGitDir). }

function GitResetHard(const AGitDir, AWorkTree: string;
  const ATargetOid: TGitOid): TGitOid; overload;
function GitResetHard(const AGitDir, AWorkTree, ATargetRef: string): TGitOid; overload;

implementation

uses
  nextpas.core.fs,
  nextpas.core.process,
  nextpas.core.text.conv,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.checkout;

function PeelToCommit(ARepo: TNativeRepository; AOid: TGitOid; AKind: TGitObjectKind): TGitOid;
var
  Data: TBytes;
  TagInfo: TGitTagInfo;
begin
  Result := AOid;
  while AKind = gokTag do
  begin
    Data := ARepo.ReadObject(Result, AKind);
    TagInfo := GitParseTag(Data);
    Result := TagInfo.Target;
    Data := ARepo.ReadObject(Result, AKind);
    if AKind = gokCommit then Exit;
  end;
  if AKind <> gokCommit then
    raise EGitError.CreateFmt('reset: oid %s is not a commit', [GitOidToHex(AOid)]);
end;

function GitResetHard(const AGitDir, AWorkTree: string;
  const ATargetOid: TGitOid): TGitOid;
var
  Repo: TNativeRepository;
  Kind: TGitObjectKind;
  Data: TBytes;
  Peeled: TGitOid;
  Info: TGitCommitInfo;
  TreeOid: TGitOid;
  HeadRef: string;
  BranchPath: string;
begin
  if AGitDir = '' then
    raise EGitError.Create('reset: gitdir empty');
  if AWorkTree = '' then
    raise EGitError.Create('reset: worktree empty');
  if not IsGitDirShape(AGitDir) then
    raise EGitError.CreateFmt('reset: not a git dir %s', [AGitDir]);
  if not DirectoryExists(AWorkTree) then
    raise EGitError.CreateFmt('reset: worktree not found %s', [AWorkTree]);

  Repo := TNativeRepository.Create(AGitDir);
  try
    Data := Repo.ReadObject(ATargetOid, Kind);
    Peeled := PeelToCommit(Repo, ATargetOid, Kind);
    Data := Repo.ReadObject(Peeled, Kind);
    Info := GitParseCommit(Data);
    TreeOid := Info.Tree;
  finally
    Repo.Free;
  end;

  // materialize worktree + index via checkout reuse
  GitCheckoutTree(AGitDir, AWorkTree, TreeOid);
  Result := Peeled;

  // move ref: if HEAD is symref to branch, update that branch; otherwise detach
  HeadRef := '';
  try
    HeadRef := GitHeadRefName(AGitDir);
  except
    HeadRef := '';
  end;
  if (HeadRef <> '') and (Copy(HeadRef, 1, 11) = 'refs/heads/') then
  begin
    BranchPath := PathJoin([AGitDir, HeadRef]);
    MkdirAll(PathDir(BranchPath), PermDirDefault);
    WriteFileText(BranchPath, GitOidToHex(Result) + #10);
  end
  else
  begin
    WriteFileText(PathJoin([AGitDir, 'HEAD']), GitOidToHex(Result) + #10);
  end;
end;

function GitResetHard(const AGitDir, AWorkTree, ATargetRef: string): TGitOid;
var
  Oid: TGitOid;
  Out_: TProcessOutput;
  Hex: string;
begin
  if ATargetRef = '' then
    raise EGitError.Create('reset: target ref empty');
  try
    Oid := GitRevParse(AGitDir, ATargetRef);
  except
    on E: EGitError do
    begin
      // fallback to git for revs not yet covered (e.g. short hex, :path, @{upstream})
      Out_ := Run('git', ['--git-dir=' + AGitDir, 'rev-parse', '--verify', ATargetRef]);
      if not ProcessSucceeded(Out_) then
        raise EGitError.CreateFmt('reset: cannot resolve %s: %s', [ATargetRef, Trim(Out_.StdErr + Out_.StdOut)]);
      Hex := Trim(Out_.StdOut);
      if not GitOidIsValidHex(Hex) then
        raise EGitError.CreateFmt('reset: rev-parse returned invalid oid %s', [Hex]);
      Oid := GitOidFromHex(Hex);
    end;
  end;
  Result := GitResetHard(AGitDir, AWorkTree, Oid);
end;

end.
