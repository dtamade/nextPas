unit nextpas.core.git.libgit2;

{$I nextpas.core.settings.inc}

interface

uses nextpas.core.base, nextpas.core.fs, nextpas.core.git.intf, nextpas.core.git.base, nextpas.core.git.libgit2.ffi, nextpas.core.git.libgit2.backend, nextpas.core.git.libgit2.binding;

type
  EGitError = nextpas.core.git.libgit2.backend.EGitError;

  // Adapter implementation using existing TGit* classes as backend
  TGitManagerImpl = class(TInterfacedObject, IGitManager)
  private
    FMgr: TGitManager;
    FActiveHandles: LongInt;
    FFinalizeRequested: Boolean;
    procedure AcquireHandle; inline;
    procedure ReleaseHandle; inline;
  public
    constructor Create;
    destructor Destroy; override;

    function Initialize: Boolean;
    procedure Finalize;

    function OpenRepository(const APath: string): IGitRepository;
    function CloneRepository(const AURL, ALocalPath: string): IGitRepository;
    function InitRepository(const APath: string; ABare: Boolean = False): IGitRepository;
    function IsRepository(const APath: string): Boolean;
    function DiscoverRepository(const AStartPath: string): string;

    function GetGlobalConfig(const AKey: string): string;
    function SetGlobalConfig(const AKey, AValue: string): Boolean;
    function Version: string;

    procedure SetVerifySSL(AEnabled: Boolean);
    procedure SetCredentialAcquireHandler({%H-} AHandler: TCredentialAcquireEvent);
    procedure SetCertificateCheckHandler({%H-} AHandler: TCertificateCheckEvent);

    function Initialized: Boolean;
    function VerifySSL: Boolean;
  end;

  TGitRepositoryImpl = class(TInterfacedObject, IGitRepository, IGitRepositoryExt, IGitWorktreeExt)
  private
    FRepo: TGitRepository;
    FOwner: IGitManager;
    FOwnerImpl: TGitManagerImpl;
  public
    constructor Create(Repo: TGitRepository; const AOwner: IGitManager; AOwnerImpl: TGitManagerImpl);
    destructor Destroy; override;

    function Path: string;
    function WorkDir: string;
    function IsBare: Boolean;
    function IsEmpty: Boolean;

    function Head: IGitReference;
    function CurrentBranch: string;
    function ListBranches(Kind: TGitBranchKind = gbLocal): TStringArray;

    function CommitByHash(const Hash: string): IGitCommit;
    function HeadCommit: IGitCommit;

    function Remote(const Name: string = 'origin'): IGitRemote;
    function Fetch(const RemoteName: string = 'origin'): Boolean;
    function CheckoutBranch(const Branch: string): Boolean;
    function CheckoutBranchEx(const Branch: string; Force: Boolean): Boolean;


    function Status: TStringArray;
    function StatusEntries(const Filter: TGitStatusFilter): TGitStatusEntryArray;
    function IsClean: Boolean;
    function HasUncommittedChanges: Boolean;

    // Extended operations
    function ListRemotes: TStringArray;
    function PullFastForward(const RemoteName: string; out Error: string): TGitPullFastForwardResult;
    // M5: diff / revwalk facade
    function Diff(const AOldRef, ANewRef: string): TGitDiff;
    function DiffEx(const AOldRef, ANewRef: string;
      const AOptions: TGitDiffOptions): TGitDiff;
    function DiffWorkingTree(const ARef: string): TGitDiff;
    function DiffWorkingTreeEx(const ARef: string;
      const AOptions: TGitDiffOptions): TGitDiff;
    function RevWalk(const AStartRef: string; ALimit: Integer): TGitCommitArray;
    // M5+ (2026-08-15): blame a file (libgit2 native)
    function Blame(const APath: string): TGitBlame;
    // k42 (2026-08-20): repo config entry snapshot (include-resolved merged view)
    function ConfigEntries: TGitConfigEntryArray;
    // k97/k101: patch/checkout helpers
    procedure ApplyPatch(const APatchText: string);
    procedure CheckoutPaths(const ARevspec: string; const APaths: TStringArray);
    function WorkdirPatchText(const ARevspec: string; const APaths: TStringArray;
      AShowBinary: Boolean): string;

    // Worktree operations (IGitWorktreeExt)
    function AddWorktree(const AName, APath, ARef: string;
      ADetach: Boolean = False): IGitWorktree;
    function LookupWorktree(const AName: string): IGitWorktree;
    function ListWorktrees: TStringArray;
    function PruneWorktree(const AName: string): Boolean;
    function CommitOnHead(const AMessage: string;
      const AAuthorName, AAuthorEmail: string): string;
  end;

  TGitCommitImpl = class(TInterfacedObject, IGitCommit)
  private
    FRepo: TGitRepository;
    FRepoOwner: IGitRepository;
    FCommit: TGitCommit;
  public
    constructor Create(const ARepoOwner: IGitRepository; ARepo: TGitRepository; C: TGitCommit);
    destructor Destroy; override;

    function Message: string;
    function ShortMessage: string;
    function AuthorString: string;
    function CommitterString: string;
    function Time: TDateTime;
    function ParentCount: Integer;
    function OIDString: string;
    // M5: parent commit OID as 40-byte hex; '' when index out of range
    function ParentOIDString(AIndex: Integer): string;
  end;

  TGitReferenceImpl = class(TInterfacedObject, IGitReference)
  private
    FRepoOwner: IGitRepository;
    FRef: TGitReference;
  public
    constructor Create(const ARepoOwner: IGitRepository; R: TGitReference);
    destructor Destroy; override;

    function Name: string;
    function ShortName: string;
    function TargetOIDString: string;
    function IsBranch: Boolean;
    function IsRemote: Boolean;
    function IsTag: Boolean;
  end;

  TGitRemoteImpl = class(TInterfacedObject, IGitRemote)
  private
    FRepoOwner: IGitRepository;
    FRemote: TGitRemote;
  public
    constructor Create(const ARepoOwner: IGitRepository; R: TGitRemote);
    destructor Destroy; override;

    function Name: string;
    function URL: string;
    function Fetch: Boolean;
  end;

  TGitWorktreeImpl = class(TInterfacedObject, IGitWorktree)
  private
    FRepoOwner: IGitRepository;
    FHandle: git_worktree;
    FName: string;
    FPath: string;
    FLocked: Boolean;
  public
    constructor Create(const ARepoOwner: IGitRepository; AHandle: git_worktree);
    destructor Destroy; override;
    function Name: string;
    function Path: string;
    function IsLocked: Boolean;
  end;

function NewGitManager: IGitManager;

implementation

{ TGitManagerImpl }

constructor TGitManagerImpl.Create;
begin
  inherited Create;
  FMgr := TGitManager.Create;
  FActiveHandles := 0;
  FFinalizeRequested := False;
end;

destructor TGitManagerImpl.Destroy;
begin
  FFinalizeRequested := True;
  Finalize;
  FMgr.Free;
  inherited Destroy;
end;

procedure TGitManagerImpl.AcquireHandle; inline;
begin
  InterlockedIncrement(FActiveHandles);
end;

procedure TGitManagerImpl.ReleaseHandle; inline;
var
  LNew: LongInt;
begin
  if InterlockedExchangeAdd(FActiveHandles, 0) <= 0 then
    Exit;
  LNew := InterlockedDecrement(FActiveHandles);
  if LNew < 0 then
  begin
    InterlockedIncrement(FActiveHandles);
    Exit;
  end;
  if (LNew = 0) and FFinalizeRequested then
    Finalize;
end;

function TGitManagerImpl.Initialize: Boolean;
begin
  Result := FMgr.Initialize;
  if Result then
    FFinalizeRequested := False;
end;

procedure TGitManagerImpl.Finalize;
begin
  if InterlockedExchangeAdd(FActiveHandles, 0) > 0 then
  begin
    FFinalizeRequested := True;
    Exit;
  end;
  FMgr.Finalize;
  FFinalizeRequested := False;
end;

function TGitManagerImpl.OpenRepository(const APath: string): IGitRepository;
begin
  Result := TGitRepositoryImpl.Create(FMgr.OpenRepository(APath), Self as IGitManager, Self);
end;

function TGitManagerImpl.CloneRepository(const AURL, ALocalPath: string): IGitRepository;
begin
  Result := TGitRepositoryImpl.Create(FMgr.CloneRepository(AURL, ALocalPath), Self as IGitManager, Self);
end;

function TGitManagerImpl.InitRepository(const APath: string; ABare: Boolean): IGitRepository;
begin
  Result := TGitRepositoryImpl.Create(FMgr.InitRepository(APath, ABare), Self as IGitManager, Self);
end;

function TGitManagerImpl.IsRepository(const APath: string): Boolean;
begin
  Result := FMgr.IsRepository(APath);
end;

function TGitManagerImpl.DiscoverRepository(const AStartPath: string): string;
var
  p, prev: string;
begin
  // Use pure Pascal fallback first to avoid instability due to header signature differences
  p := PathAbs(AStartPath);
  prev := '';
  while (p <> '') and (p <> prev) do
  begin
    if Exists(PathEnsureSep(p) + '.git') then
    begin
      Exit(p);
    end;
    prev := p;
    p := PathDir(p);
  end;
  // If not found, try calling underlying layer (wrap exceptions to avoid crashes)
  try
    Result := FMgr.DiscoverRepository(AStartPath);
  except
    Result := '';
  end;
end;

function TGitManagerImpl.GetGlobalConfig(const AKey: string): string;
begin
  Result := FMgr.GetGlobalConfig(AKey);
end;

function TGitManagerImpl.SetGlobalConfig(const AKey, AValue: string): Boolean;
begin
  Result := FMgr.SetGlobalConfig(AKey, AValue);
end;

function TGitManagerImpl.Version: string;
begin
  Result := FMgr.GetVersion;
end;

procedure TGitManagerImpl.SetVerifySSL(AEnabled: Boolean);
begin
  FMgr.SetVerifySSL(AEnabled);
end;

procedure TGitManagerImpl.SetCredentialAcquireHandler({%H-} AHandler: TCredentialAcquireEvent);
begin
  if Assigned(AHandler) then
    raise EGitError.Create(GIT_EUSER,
      'Credential callback handlers are not supported by nextpas.core.git.libgit2 yet');
end;

procedure TGitManagerImpl.SetCertificateCheckHandler({%H-} AHandler: TCertificateCheckEvent);
begin
  if Assigned(AHandler) then
    raise EGitError.Create(GIT_EUSER,
      'Certificate callback handlers are not supported by nextpas.core.git.libgit2 yet');
end;

function TGitManagerImpl.Initialized: Boolean;
begin
  Result := FMgr.Initialized;
end;

function TGitManagerImpl.VerifySSL: Boolean;
begin
  Result := FMgr.VerifySSL;
end;

{ TGitRepositoryImpl }

constructor TGitRepositoryImpl.Create(Repo: TGitRepository; const AOwner: IGitManager; AOwnerImpl: TGitManagerImpl);
begin
  inherited Create;
  FRepo := Repo;
  FOwner := AOwner;
  FOwnerImpl := AOwnerImpl;
  if Assigned(FOwnerImpl) then
    FOwnerImpl.AcquireHandle;
end;

destructor TGitRepositoryImpl.Destroy;
begin
  FRepo.Free;
  if Assigned(FOwnerImpl) then
    FOwnerImpl.ReleaseHandle;
  inherited Destroy;
end;

function TGitRepositoryImpl.Path: string;
begin
  Result := FRepo.Path;
end;

function TGitRepositoryImpl.WorkDir: string;
begin
  Result := FRepo.WorkDir;
end;

function TGitRepositoryImpl.IsBare: Boolean;
begin
  Result := FRepo.IsBare;
end;

function TGitRepositoryImpl.IsEmpty: Boolean;
begin
  Result := FRepo.IsEmpty;
end;

function TGitRepositoryImpl.Head: IGitReference;
begin
  Result := TGitReferenceImpl.Create(Self as IGitRepository, FRepo.GetHead);
end;

function TGitRepositoryImpl.CurrentBranch: string;
begin
  Result := FRepo.GetCurrentBranch;
end;

function TGitRepositoryImpl.ListBranches(Kind: TGitBranchKind): TStringArray;
var
  t: git_branch_t;
begin
  case Kind of
    gbLocal:  t := GIT_BRANCH_LOCAL;
    gbRemote: t := GIT_BRANCH_REMOTE;
  else
    t := GIT_BRANCH_ALL;
  end;
  Result := FRepo.ListBranches(t);
end;

function TGitRepositoryImpl.CommitByHash(const Hash: string): IGitCommit;
var
  oid: TGitOID;
  c: TGitCommit;
begin
  oid := CreateGitOIDFromString(Hash);
  c := FRepo.GetCommit(oid);
  Result := TGitCommitImpl.Create(Self as IGitRepository, FRepo, c);
end;

function TGitRepositoryImpl.HeadCommit: IGitCommit;
begin
  Result := TGitCommitImpl.Create(Self as IGitRepository, FRepo, FRepo.GetHeadCommit);
end;

function TGitRepositoryImpl.Remote(const Name: string): IGitRemote;
begin
  Result := TGitRemoteImpl.Create(Self as IGitRepository, FRepo.GetRemote(Name));
end;

function TGitRepositoryImpl.Fetch(const RemoteName: string): Boolean;
begin
  Result := FRepo.Fetch(RemoteName);
end;
function TGitRepositoryImpl.CheckoutBranchEx(const Branch: string; Force: Boolean): Boolean;
begin
  Result := FRepo.CheckoutBranchEx(Branch, Force);
end;


function TGitRepositoryImpl.CheckoutBranch(const Branch: string): Boolean;
begin
  Result := FRepo.CheckoutBranch(Branch);
end;

function TGitRepositoryImpl.Status: TStringArray;
begin
  Result := FRepo.Status;
end;

function TGitRepositoryImpl.IsClean: Boolean;
begin
  Result := FRepo.IsClean;
end;

function TGitRepositoryImpl.StatusEntries(const Filter: TGitStatusFilter): TGitStatusEntryArray;
begin
  Result := FRepo.StatusEntries(Filter);
end;

function TGitRepositoryImpl.HasUncommittedChanges: Boolean;
begin
  Result := FRepo.HasUncommittedChanges;
end;

function TGitRepositoryImpl.Diff(const AOldRef, ANewRef: string): TGitDiff;
begin
  Result := FRepo.Diff(AOldRef, ANewRef);
end;

function TGitRepositoryImpl.DiffEx(const AOldRef, ANewRef: string;
  const AOptions: TGitDiffOptions): TGitDiff;
begin
  Result := FRepo.DiffEx(AOldRef, ANewRef, AOptions);
end;

function TGitRepositoryImpl.DiffWorkingTree(const ARef: string): TGitDiff;
begin
  Result := FRepo.DiffWorkingTree(ARef);
end;

function TGitRepositoryImpl.DiffWorkingTreeEx(const ARef: string;
  const AOptions: TGitDiffOptions): TGitDiff;
begin
  Result := FRepo.DiffWorkingTreeEx(ARef, AOptions);
end;

function TGitRepositoryImpl.Blame(const APath: string): TGitBlame;
begin
  Result := FRepo.Blame(APath);
end;

function TGitRepositoryImpl.ConfigEntries: TGitConfigEntryArray;
begin
  Result := FRepo.ConfigEntries;
end;

procedure TGitRepositoryImpl.ApplyPatch(const APatchText: string);
begin
  FRepo.ApplyPatch(APatchText);
end;

procedure TGitRepositoryImpl.CheckoutPaths(const ARevspec: string; const APaths: TStringArray);
begin
  FRepo.CheckoutPaths(ARevspec, APaths);
end;

function TGitRepositoryImpl.WorkdirPatchText(const ARevspec: string; const APaths: TStringArray;
  AShowBinary: Boolean): string;
begin
  Result := FRepo.WorkdirPatchText(ARevspec, APaths, AShowBinary);
end;

function TGitRepositoryImpl.RevWalk(const AStartRef: string; ALimit: Integer): TGitCommitArray;
var
  LCommits: TGitCommitList;
  LRepoIface: IGitRepository;
  I: Integer;
begin
  Result := nil;
  LCommits := FRepo.RevWalk(AStartRef, ALimit);
  LRepoIface := Self as IGitRepository;
  SetLength(Result, Length(LCommits));
  for I := 0 to High(LCommits) do
    Result[I] := TGitCommitImpl.Create(LRepoIface, FRepo, LCommits[I]);
end;

function TGitRepositoryImpl.ListRemotes: TStringArray;
begin
  Result := FRepo.ListRemotes;
end;

function TGitRepositoryImpl.PullFastForward(const RemoteName: string; out Error: string): TGitPullFastForwardResult;
begin
  Result := FRepo.PullFastForward(RemoteName, Error);
end;

{ TGitCommitImpl }

constructor TGitCommitImpl.Create(const ARepoOwner: IGitRepository; ARepo: TGitRepository; C: TGitCommit);
begin
  inherited Create;
  FRepoOwner := ARepoOwner;
  FRepo := ARepo;
  FCommit := C;
  FCommit.EnsureLoaded;
end;

destructor TGitCommitImpl.Destroy;
begin
  FCommit.Free;
  inherited Destroy;
end;

function TGitCommitImpl.Message: string;
begin
  Result := FCommit.Message;
end;

function TGitCommitImpl.ShortMessage: string;
begin
  Result := FCommit.ShortMessage;
end;

function TGitCommitImpl.AuthorString: string;
begin
  if Assigned(FCommit.Author) then
    Result := FCommit.Author.ToString
  else
    Result := '';
end;

function TGitCommitImpl.CommitterString: string;
begin
  if Assigned(FCommit.Committer) then
    Result := FCommit.Committer.ToString
  else
    Result := '';
end;

function TGitCommitImpl.Time: TDateTime;
begin
  Result := FCommit.Time;
end;

function TGitCommitImpl.ParentCount: Integer;
begin
  Result := FCommit.ParentCount;
end;

function TGitCommitImpl.OIDString: string;
begin
  Result := GitOIDToString(FCommit.OID);
end;

function TGitCommitImpl.ParentOIDString(AIndex: Integer): string;
begin
  Result := FCommit.GetParentOIDString(AIndex);
end;

{ TGitReferenceImpl }

constructor TGitReferenceImpl.Create(const ARepoOwner: IGitRepository; R: TGitReference);
begin
  inherited Create;
  FRepoOwner := ARepoOwner;
  FRef := R;
end;

destructor TGitReferenceImpl.Destroy;
begin
  FRef.Free;
  inherited Destroy;
end;

function TGitReferenceImpl.Name: string;
begin
  Result := FRef.Name;
end;

function TGitReferenceImpl.ShortName: string;
begin
  Result := FRef.ShortName;
end;

function TGitReferenceImpl.TargetOIDString: string;
begin
  Result := GitOIDToString(FRef.OID);
end;

function TGitReferenceImpl.IsBranch: Boolean;
begin
  Result := (Pos('refs/heads/', FRef.Name) = 1);
end;

function TGitReferenceImpl.IsRemote: Boolean;
begin
  Result := (Pos('refs/remotes/', FRef.Name) = 1);
end;

function TGitReferenceImpl.IsTag: Boolean;
begin
  Result := (Pos('refs/tags/', FRef.Name) = 1);
end;

{ TGitRemoteImpl }

constructor TGitRemoteImpl.Create(const ARepoOwner: IGitRepository; R: TGitRemote);
begin
  inherited Create;
  FRepoOwner := ARepoOwner;
  FRemote := R;
end;

destructor TGitRemoteImpl.Destroy;
begin
  FRemote.Free;
  inherited Destroy;
end;

function TGitRemoteImpl.Name: string;
begin
  Result := FRemote.Name;
end;

function TGitRemoteImpl.URL: string;
begin
  Result := FRemote.URL;
end;

function TGitRemoteImpl.Fetch: Boolean;
begin
  Result := FRemote.Fetch;
end;

{ TGitWorktreeImpl }

function HexChar(N: Byte): Char; inline;
begin
  if N < 10 then
    Result := Chr(Ord('0') + N)
  else
    Result := Chr(Ord('a') + N - 10);
end;

constructor TGitWorktreeImpl.Create(const ARepoOwner: IGitRepository; AHandle: git_worktree);
begin
  inherited Create;
  FRepoOwner := ARepoOwner;
  FHandle := AHandle;
  FName := string(git_worktree_name(FHandle));
  FPath := string(git_worktree_path(FHandle));
  FLocked := git_worktree_is_locked(nil, FHandle) <> 0;
end;

destructor TGitWorktreeImpl.Destroy;
begin
  { Note: git_worktree_free is intentionally NOT called.
    libgit2 1.9's git_worktree_free causes double-free / invalid-pointer
    aborts when the handle was obtained via git_worktree_add (works for
    git_worktree_lookup). Leaking the handle is safe — it's a lightweight
    wrapper, and the parent repository's git_repository_free reclaims the
    underlying worktree metadata. }
  FHandle := nil;
  inherited Destroy;
end;

function TGitWorktreeImpl.Name: string;
begin
  Result := FName;
end;

function TGitWorktreeImpl.Path: string;
begin
  Result := FPath;
end;

function TGitWorktreeImpl.IsLocked: Boolean;
begin
  Result := FLocked;
end;

{ TGitRepositoryImpl - Worktree operations }

function TGitRepositoryImpl.AddWorktree(const AName, APath, ARef: string;
  ADetach: Boolean): IGitWorktree;
var
  Wt: git_worktree;
  rc: cint;
begin
  Result := nil;
  if (AName = '') or (APath = '') then
    raise EGitError.Create(GIT_EINVALIDSPEC, 'AddWorktree: name and path required');

  Wt := nil;
  { Passing nil opts uses libgit2 defaults (safe checkout, no lock, no ref override) }
  rc := git_worktree_add(Wt, FRepo.RawHandle, PChar(AName), PChar(APath), nil);
  if rc <> GIT_OK then
    raise EGitError.Create(rc, 'AddWorktree: git_worktree_add failed for "' + AName + '" at "' + APath + '"');

  Result := TGitWorktreeImpl.Create(Self as IGitRepository, Wt);
end;

function TGitRepositoryImpl.LookupWorktree(const AName: string): IGitWorktree;
var
  Wt: git_worktree;
  rc: cint;
begin
  Result := nil;
  if AName = '' then
    raise EGitError.Create(GIT_EINVALIDSPEC, 'LookupWorktree: name required');

  Wt := nil;
  rc := git_worktree_lookup(Wt, FRepo.RawHandle, PChar(AName));
  if rc <> GIT_OK then
    raise EGitError.Create(rc, 'LookupWorktree: not found "' + AName + '"');

  Result := TGitWorktreeImpl.Create(Self as IGitRepository, Wt);
end;

function TGitRepositoryImpl.ListWorktrees: TStringArray;
var
  SA: git_strarray;
  rc: cint;
  I: Integer;
begin
  Result := nil;
  FillChar(SA, SizeOf(SA), 0);
  rc := git_worktree_list(SA, FRepo.RawHandle);
  if rc <> GIT_OK then
    raise EGitError.Create(rc, 'ListWorktrees failed');

  try
    SetLength(Result, Integer(SA.count));
    for I := 0 to Integer(SA.count) - 1 do
      Result[I] := string(PPChar(SA.strings)[I]);
  finally
    git_strarray_free(@SA);
  end;
end;

function TGitRepositoryImpl.PruneWorktree(const AName: string): Boolean;
var
  Wt: git_worktree;
  PruneOpts: git_worktree_prune_options;
  rc: cint;
begin
  Result := False;
  if AName = '' then
    Exit;

  Wt := nil;
  rc := git_worktree_lookup(Wt, FRepo.RawHandle, PChar(AName));
  if rc <> GIT_OK then
    Exit;

  try
    rc := git_worktree_prune_options_init(@PruneOpts, GIT_WORKTREE_PRUNE_OPTIONS_VERSION);
    if rc <> GIT_OK then
      Exit;
    PruneOpts.flags := GIT_WORKTREE_PRUNE_VALID or GIT_WORKTREE_PRUNE_WORKTREE;

    rc := git_worktree_prune(Wt, @PruneOpts);
    Result := rc = GIT_OK;
  finally
    git_worktree_free(Wt);
  end;
end;

function TGitRepositoryImpl.CommitOnHead(const AMessage: string;
  const AAuthorName, AAuthorEmail: string): string;
var
  Index: git_index;
  TreeOID: git_oid;
  Tree: git_tree;
  HeadCmt: git_commit;
  HeadRef: git_reference;
  HeadOID: Pgit_oid;
  Parents: array[0..0] of git_commit;
  Sig: git_signature;
  CommitOID: git_oid;
  rc: cint;
  ParentCount: csize_t;
  HasHead: Boolean;
begin
  Result := '';
  if AMessage = '' then
    raise EGitError.Create(GIT_EINVALID, 'CommitOnHead: message required');

  Index := nil;
  Tree := nil;
  HeadCmt := nil;
  HeadRef := nil;
  Sig := nil;
  try
    { 1. Get repository index }
    rc := git_repository_index(Index, FRepo.RawHandle);
    if rc <> GIT_OK then
      raise EGitError.Create(rc, 'CommitOnHead: git_repository_index failed');

    { 2. Write index to tree }
    FillChar(TreeOID, SizeOf(TreeOID), 0);
    rc := git_index_write_tree(TreeOID, Index);
    if rc <> GIT_OK then
      raise EGitError.Create(rc, 'CommitOnHead: git_index_write_tree failed');

    { 3. Lookup the tree }
    rc := git_tree_lookup(Tree, FRepo.RawHandle, @TreeOID);
    if rc <> GIT_OK then
      raise EGitError.Create(rc, 'CommitOnHead: git_tree_lookup failed');

    { 4. Get HEAD commit as parent (if repository is not unborn) }
    HasHead := git_repository_head_unborn(FRepo.RawHandle) = 0;
    if HasHead then
    begin
      { Get HEAD reference and lookup the commit it points to }
      rc := git_repository_head(HeadRef, FRepo.RawHandle);
      if rc = GIT_OK then
      begin
        HeadOID := git_reference_target(HeadRef);
        if HeadOID <> nil then
        begin
          rc := git_commit_lookup(HeadCmt, FRepo.RawHandle, HeadOID);
          if rc <> GIT_OK then
            HeadCmt := nil;
        end;
        git_reference_free(HeadRef);
      end;
    end;

    { 5. Create signature }
    rc := git_signature_now(Sig, PChar(AAuthorName), PChar(AAuthorEmail));
    if rc <> GIT_OK then
      raise EGitError.Create(rc, 'CommitOnHead: git_signature_now failed');

    { 6. Determine parent }
    if HasHead and (HeadCmt <> nil) then
    begin
      Parents[0] := HeadCmt;
      ParentCount := 1;
    end
    else
    begin
      ParentCount := 0;
    end;

    { 7. Create commit on HEAD }
    FillChar(CommitOID, SizeOf(CommitOID), 0);
    rc := git_commit_create(CommitOID, FRepo.RawHandle, 'HEAD',
      Sig, Sig, nil, PChar(AMessage), Tree, ParentCount, @Parents[0]);
    if rc <> GIT_OK then
      raise EGitError.Create(rc, 'CommitOnHead: git_commit_create failed');

    { 8. Return OID as hex string (manual hex encoding to avoid binding quirks) }
    Result := '';
    for rc := 0 to 19 do
    begin
      Result := Result + HexChar(CommitOID.id[rc] shr 4) +
        HexChar(CommitOID.id[rc] and $0F);
    end;

  finally
    if Sig <> nil then
      git_signature_free(Sig);
    if HeadCmt <> nil then
      git_commit_free(HeadCmt);
    if Tree <> nil then
      git_tree_free(Tree);
    if Index <> nil then
      git_index_free(Index);
  end;
end;

function NewGitManager: IGitManager;
begin
  Result := TGitManagerImpl.Create;
end;

end.
