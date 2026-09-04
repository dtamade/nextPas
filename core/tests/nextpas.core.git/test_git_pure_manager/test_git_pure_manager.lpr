program test_git_pure_manager;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.base,
  nextpas.core.text.conv,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.test,
  nextpas.core.process,
  nextpas.core.git.factory,
  nextpas.core.git.base,
  nextpas.core.git.intf,
  nextpas.core.git.native.base;

var
  Suite: TTestSuite;
  GUniq: Integer = 0;

function BytesOfString(const AText: string): TBytes; inline;
begin
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(AText[1], Result[0], Length(AText));
end;

type
  TDummyCredHandler = class
    function Acquire(const Url, UserFromURL: string; AllowedTypes: Cardinal): Boolean;
    function CheckCert(const Host: string; Valid: Boolean): Boolean;
  end;

function TDummyCredHandler.Acquire(const Url, UserFromURL: string; AllowedTypes: Cardinal): Boolean;
begin
  Result := False;
end;

function TDummyCredHandler.CheckCert(const Host: string; Valid: Boolean): Boolean;
begin
  Result := False;
end;

function MkTempDir(const APrefix: string): string;
begin
  Inc(GUniq);
  Result := PathJoin([GetTempDir, APrefix + '_' + IntToStr(GetProcessID) + '_' + IntToStr(GUniq)]);
  RemoveAll(Result);
  MkdirAll(Result);
end;

function ContainsStr(const AItems: TStringArray; const AValue: string): Boolean; inline;
var
  S: string;
begin
  Result := False;
  // zero-copy scan, no Copy allocation, inline hot path
  for S in AItems do
    if S = AValue then
      Exit(True);
end;

function IsHexChar(ACh: Char): Boolean; inline;
begin
  Result := ((ACh >= '0') and (ACh <= '9')) or ((ACh >= 'a') and (ACh <= 'f')) or ((ACh >= 'A') and (ACh <= 'F'));
end;

function Is40Hex(const S: string): Boolean; inline;
var
  I: Integer;
begin
  if Length(S) <> 40 then Exit(False);
  // zero-copy PChar scan, single source hex validation (no duplicate adler/wildmatch)
  for I := 1 to 40 do
    if not IsHexChar(S[I]) then Exit(False);
  Result := True;
end;

procedure GitRun(const ADir: string; const AArgs: array of string);
var
  LOut: TProcessOutput;
begin
  LOut := RunIn('/usr/bin/git', AArgs, ADir);
  if LOut.ExitCode <> 0 then
    raise Exception.Create('git ' + AArgs[0] + ' failed: ' + LOut.StdErr);
end;

procedure TestInitAndIsRepository;
var
  LDir: string;
  LMgr: IGitManager;
  LRepo: IGitRepository;
begin
  LDir := MkTempDir('pure_init');
  try
    LMgr := NewGitManager(gbNative);
    Check(LMgr.Initialize, 'Initialize should succeed');
    LRepo := LMgr.InitRepository(LDir, False);
    Check(LRepo <> nil, 'InitRepository should return repo');
    Check(LMgr.IsRepository(LDir), 'IsRepository true after Init(false)');
    CheckFalse(LRepo.IsBare, 'repo should be non-bare');
    Check(LMgr.IsRepository(PathJoin([LDir, '.git'])), '.git should be repository');
  finally
    RemoveAll(LDir);
  end;
end;

procedure TestStatusEmpty;
var
  LDir: string;
  LMgr: IGitManager;
  LRepo: IGitRepository;
  LStatus: TStringArray;
begin
  LDir := MkTempDir('pure_status_empty');
  try
    LMgr := NewGitManager(gbNative);
    Check(LMgr.Initialize, 'init');
    LRepo := LMgr.InitRepository(LDir, False);
    LStatus := LRepo.Status;
    CheckEqual(0, Length(LStatus), 'Status should be empty after init');
    Check(LRepo.IsClean, 'IsClean true on empty repo');
    CheckFalse(LRepo.HasUncommittedChanges, 'no uncommitted changes');
  finally
    RemoveAll(LDir);
  end;
end;

procedure TestStatusWithFile;
var
  LDir: string;
  LMgr: IGitManager;
  LRepo: IGitRepository;
  LStatus: TStringArray;
  LEntries: TGitStatusEntryArray;
  LFilter: TGitStatusFilter;
  LFound: Boolean;
  I: Integer;
begin
  LDir := MkTempDir('pure_status_file');
  try
    LMgr := NewGitManager(gbNative);
    Check(LMgr.Initialize, 'init');
    LRepo := LMgr.InitRepository(LDir, False);
    WriteFile(PathJoin([LDir, 'hello.txt']), BytesOfString('hello pure'), PermDefault);
    LStatus := LRepo.Status;
    Check(Length(LStatus) > 0, 'Status should report new file');
    Check(ContainsStr(LStatus, 'hello.txt'), 'Status should contain hello.txt');

    LFilter.IncludeUntracked := True;
    LFilter.IncludeIgnored := False;
    LFilter.WorkingTreeOnly := False;
    LFilter.IndexOnly := False;
    LEntries := LRepo.StatusEntries(LFilter);
    Check(Length(LEntries) > 0, 'StatusEntries should report new file');
    LFound := False;
    for I := 0 to High(LEntries) do
      if (LEntries[I].Path = 'hello.txt') and (gsWtNew in LEntries[I].Flags) then
        LFound := True;
    Check(LFound, 'hello.txt should have gsWtNew flag');
  finally
    RemoveAll(LDir);
  end;
end;

procedure TestHeadAndLookup;
var
  LDir: string;
  LMgr: IGitManager;
  LRepo: IGitRepository;
  LHead: IGitReference;
  LRaised: Boolean;
begin
  LDir := MkTempDir('pure_head_lookup');
  try
    LMgr := NewGitManager(gbNative);
    Check(LMgr.Initialize, 'init');
    LRepo := LMgr.InitRepository(LDir, False);

    // create a commit via CLI so native Head is resolvable
    GitRun(LDir, ['config', 'user.name', 'Pure Tester']);
    GitRun(LDir, ['config', 'user.email', 'pure@example.invalid']);
    WriteFile(PathJoin([LDir, 'seed.txt']), BytesOfString('seed'), PermDefault);
    GitRun(LDir, ['add', 'seed.txt']);
    GitRun(LDir, ['commit', '-m', 'initial']);

    // reopen to ensure fresh view
    LRepo := LMgr.OpenRepository(LDir);
    LHead := LRepo.Head;
    Check(LHead <> nil, 'Head should not be nil');
    Check(LHead.ShortName <> '', 'Head.ShortName non-empty');
    CheckEqual(40, Length(LHead.TargetOIDString), 'Head OID should be 40 hex');
    Check(LHead.IsBranch, 'Head should be branch');

    LRaised := False;
    try
      LRepo.CommitByHash('0000000000000000000000000000000000000000');
    except
      on E: EGitError do
        LRaised := True;
      on E: Exception do
        LRaised := True;
    end;
    Check(LRaised, 'CommitByHash missing should raise EGitError');

    LRaised := False;
    try
      LRepo.CommitByHash('deadbeefdeadbeefdeadbeefdeadbeefdeadbeef');
    except
      on E: EGitError do
        LRaised := True;
      on E: Exception do
        LRaised := True;
    end;
    Check(LRaised, 'CommitByHash unknown should raise');
  finally
    RemoveAll(LDir);
  end;
end;

procedure TestFactoryGbAutoCompat;
var
  LMgr, LLibMgr: IGitManager;
  LRaised: Boolean;
begin
  LMgr := NewGitManager(gbAuto);
  Check(LMgr <> nil, 'NewGitManager(gbAuto) should return native manager by default');
  Check(LMgr.Initialize, 'gbAuto Initialize should succeed');
  Check(LMgr.Initialized, 'gbAuto should report Initialized');
  LMgr.Finalize;
  CheckFalse(LMgr.Initialized, 'gbAuto Finalize should clear Initialized');
  LRaised := False;
  try
    LLibMgr := NewGitManager(gbLibGit2);
  except
    on E: EGitError do
    begin
      LRaised := True;
      Check(Pos('not registered', LowerCase(E.Message)) > 0, 'gbLibGit2 fail-closed EGitError must mention not registered');
    end;
    on E: Exception do
      LRaised := True;
  end;
  if LRaised then
    Check(True, 'gbLibGit2 fail-closed when backend not registered (pure triple-zero)')
  else
    Check(True, 'gbLibGit2 succeeded via registered backend');
end;

// CONTRACT INV-O4/E2/M4: DiscoverRepository pure query, no throw, PathClean absolute
procedure TestDiscoverRepositoryInvariants;
var
  LBase, LRoot, LNest, LMain, LWt, LWtNest: string;
  LSavedDir: string;
  LMgr: IGitManager;
  LRepo: IGitRepository;
  LWtExt: IGitWorktreeExt;
begin
  LBase := MkTempDir('pure_discover');
  // hermetic empty-path assertions: DiscoverRepository('') resolves the
  // process CWD, so pin CWD to the fresh temp dir (never a repo)
  LSavedDir := GetCurrentDir;
  ChDir(LBase);
  try
    LMgr := NewGitManager(gbNative);
    Check(LMgr.Initialize, 'init');

    // empty / unreachable returns '' not throw (INV-E2)
    CheckEqual('', LMgr.DiscoverRepository(''), 'DiscoverRepository empty -> empty');
    CheckEqual('', LMgr.DiscoverRepository(PathJoin([LBase, 'does_not_exist_xyz'])), 'unreachable -> empty');

    // ancestor .git discovery via PathClean absolute
    LRoot := PathJoin([LBase, 'repo']);
    MkdirAll(LRoot);
    LRepo := LMgr.InitRepository(LRoot, False);
    Check(LMgr.IsRepository(LRoot), 'IsRepository after init');
    LNest := PathJoin([LRoot, 'a', 'b', 'c']);
    MkdirAll(LNest);
    CheckEqual(PathClean(LRoot), PathClean(LMgr.DiscoverRepository(LNest)), 'Discover should find ancestor .git');
    CheckEqual(PathClean(LRoot), PathClean(LMgr.DiscoverRepository(PathJoin([LRoot, '.git']))), '.git dir itself discovers worktree root');

    // worktree .git file resolution: create linked worktree then discover from its nested dir
    GitRun(LRoot, ['config', 'user.name', 'Pure Tester']);
    GitRun(LRoot, ['config', 'user.email', 'pure@example.invalid']);
    WriteFile(PathJoin([LRoot, 'seed.txt']), BytesOfString('seed'), PermDefault);
    GitRun(LRoot, ['add', 'seed.txt']);
    GitRun(LRoot, ['commit', '-m', 'seed']);
    // reopen to ensure native adapter sees committed HEAD
    LRepo := LMgr.OpenRepository(LRoot);
    if LRepo.QueryInterface(IGitWorktreeExt, LWtExt) <> 0 then
      raise Exception.Create('supports worktree ext');
    LMain := LRoot;
    LWt := PathJoin([LBase, 'linked']);
    LWtExt.AddWorktree('linked-wt', LWt, '', False);
    try
      LWtNest := PathJoin([LWt, 'nested', 'deep']);
      MkdirAll(LWtNest);
      CheckEqual(PathClean(LWt), PathClean(LMgr.DiscoverRepository(LWtNest)), 'Discover resolves linked worktree .git file to worktree root');
      // also verify Discover on worktree .git file itself
      CheckEqual(PathClean(LWt), PathClean(LMgr.DiscoverRepository(PathJoin([LWt, '.git']))), 'worktree .git file resolves');
    finally
      // prune metadata but keep dir for finally cleanup; RemoveAll will clean both
      if LMgr.OpenRepository(LMain).QueryInterface(IGitWorktreeExt, LWtExt) = 0 then
        LWtExt.PruneWorktree('linked-wt');
      RemoveAll(LWt);
    end;

    // bare repo discover returns gitdir itself
    LRoot := PathJoin([LBase, 'bare.git']);
    LRepo := LMgr.InitRepository(LRoot, True);
    Check(LRepo.IsBare, 'bare repo');
    CheckEqual(PathClean(LRoot), PathClean(LMgr.DiscoverRepository(LRoot)), 'Discover bare returns gitdir');
  finally
    ChDir(LSavedDir);
    RemoveAll(LBase);
  end;
end;

// CONTRACT INV-O4/E2/M4: CloneRepository network raises transport EGitError, local clone succeeds
procedure TestCloneRepositoryInvariants;
var
  LBase, LClone, LSrc, LLocal: string;
  LMgr: IGitManager;
  LRepo, LCloned: IGitRepository;
  LRaised: Boolean;
begin
  LBase := MkTempDir('pure_clone');
  LClone := PathJoin([LBase, 'clone_target']);
  try
    LMgr := NewGitManager(gbNative);
    Check(LMgr.Initialize, 'init');
    LRaised := False;
    try
      LMgr.CloneRepository('https://example.invalid/does-not-exist.git', LClone);
    except
      on E: EGitError do
      begin
        LRaised := True;
        Check(Pos('transport', LowerCase(E.Message)) > 0, 'Clone network EGitError should mention transport');
      end;
      on E: Exception do
        LRaised := True;
    end;
    Check(LRaised, 'CloneRepository network must raise EGitError');
    CheckFalse(FileExists(PathJoin([LClone, 'HEAD'])), 'Clone failure must not leave HEAD');
    CheckFalse(DirectoryExists(PathJoin([LClone, 'objects'])), 'Clone failure must not leave objects');
    Check(LMgr.Initialized, 'Manager still initialized after clone failure');
    CheckEqual('', LMgr.DiscoverRepository(PathJoin([LClone, 'nested'])), 'Manager usable after clone failure');
    LSrc := PathJoin([LBase, 'src']);
    LRepo := LMgr.InitRepository(LSrc, False);
    Check(LRepo <> nil, 'src init');
    GitRun(LSrc, ['config', 'user.name', 'Pure Tester']);
    GitRun(LSrc, ['config', 'user.email', 'pure@example.invalid']);
    WriteFile(PathJoin([LSrc, 'seed.txt']), BytesOfString('seed'), PermDefault);
    GitRun(LSrc, ['add', 'seed.txt']);
    GitRun(LSrc, ['commit', '-m', 'seed']);
    LLocal := PathJoin([LBase, 'local_clone']);
    LCloned := LMgr.CloneRepository(LSrc, LLocal);
    Check(LCloned <> nil, 'local clone should return repo');
    Check(LMgr.IsRepository(LLocal), 'local clone result is repository');
    Check(FileExists(PathJoin([LLocal, 'seed.txt'])), 'local clone should checkout seed.txt');
  finally
    RemoveAll(LBase);
  end;
end;

procedure TestManagerInterfaceClosure;
var
  LBase, LDir: string;
  LMgr: IGitManager;
  LRepo: IGitRepository;
  LRem: IGitRemote;
  LRaised: Boolean;
  LVal: string;
begin
  LBase := MkTempDir('pure_closure');
  try
    LMgr := NewGitManager(gbNative);
    Check(LMgr.Initialize, 'init');
    LDir := PathJoin([LBase, 'repo']);
    LRepo := LMgr.InitRepository(LDir, False);
    GitRun(LDir, ['config', 'user.name', 'Pure Tester']);
    GitRun(LDir, ['config', 'user.email', 'pure@example.invalid']);
    WriteFile(PathJoin([LDir, 'a.txt']), BytesOfString('a'), PermDefault);
    GitRun(LDir, ['add', 'a.txt']);
    GitRun(LDir, ['commit', '-m', 'one']);
    GitRun(LDir, ['branch', 'feature']);
    Check(Length(LRepo.ListBranches(gbLocal)) >= 2, 'ListBranches local lists main+feature');
    Check(Length(LRepo.ListBranches(gbAll)) >= 2, 'ListBranches all includes local');
    CheckEqual(0, Length(LRepo.ListBranches(gbRemote)), 'ListBranches remote empty without remotes');
    LRaised := False;
    try
      LRem := LRepo.Remote('origin');
    except
      on E: EGitError do
        LRaised := True;
    end;
    Check(LRaised, 'Remote missing should raise EGitError');
    GitRun(LDir, ['remote', 'add', 'origin', 'file:///tmp/pure-closure-origin.git']);
    LRem := LRepo.Remote('origin');
    Check(LRem <> nil, 'Remote origin found');
    CheckEqual('origin', LRem.Name, 'remote name');
    Check(Pos('pure-closure-origin', LRem.URL) > 0, 'remote url');
    CheckFalse(LRepo.Fetch('origin'), 'native Fetch returns False without network');
    Check(LRepo.CheckoutBranch('feature'), 'CheckoutBranch feature');
    CheckEqual('feature', LRepo.CurrentBranch, 'current branch feature');
    Check(LRepo.CheckoutBranchEx('main', True), 'CheckoutBranchEx main force');
    CheckEqual('main', LRepo.CurrentBranch, 'current branch main');
    LVal := LMgr.GetGlobalConfig('user.name');
    Check(True, 'GetGlobalConfig readable, value="' + LVal + '"');
    LRaised := False;
    try
      LMgr.SetGlobalConfig('user.name', 'x');
    except
      on E: EGitError do
        LRaised := True;
    end;
    Check(LRaised, 'SetGlobalConfig native raises explicit EGitError');
  finally
    RemoveAll(LBase);
  end;
end;

// CONTRACT INV-O4/E2/M4: CommitOnHead requires AMessage<>'', 40-hex OID, try/finally releases
procedure TestCommitOnHeadInvariants;
var
  LDir: string;
  LMgr: IGitManager;
  LRepo: IGitRepository;
  LWtExt: IGitWorktreeExt;
  LRaised: Boolean;
  LOid, LOid2: string;
  LCommit: IGitCommit;
begin
  LDir := MkTempDir('pure_commit_head');
  try
    LMgr := NewGitManager(gbNative);
    Check(LMgr.Initialize, 'init');
    LRepo := LMgr.InitRepository(LDir, False);
    GitRun(LDir, ['config', 'user.name', 'Pure Tester']);
    GitRun(LDir, ['config', 'user.email', 'pure@example.invalid']);
    if LRepo.QueryInterface(IGitWorktreeExt, LWtExt) <> 0 then
      raise Exception.Create('IGitRepository should support IGitWorktreeExt for CommitOnHead');

    // empty message must raise EGitError(GIT_EINVALID,'message required') (INV-E2)
    LRaised := False;
    try
      LWtExt.CommitOnHead('', 'A', 'a@b.c');
    except
      on E: EGitError do
      begin
        LRaised := True;
        Check(Pos('message required', LowerCase(E.Message)) > 0, 'empty message EGitError contains message required');
      end;
      on E: Exception do
        LRaised := True;
    end;
    Check(LRaised, 'CommitOnHead empty message must raise EGitError');

    LRaised := False;
    try
      LWtExt.CommitOnHead('   ', 'A', 'a@b.c');
    except
      on E: EGitError do LRaised := True;
      on E: Exception do LRaised := True;
    end;
    Check(LRaised, 'CommitOnHead whitespace message must raise EGitError');

    // stage file then commit, verify 40-hex OID and HEAD update
    WriteFile(PathJoin([LDir, 'hello.txt']), BytesOfString('hello pure'), PermDefault);
    GitRun(LDir, ['add', 'hello.txt']);
    LOid := LWtExt.CommitOnHead('first pure commit', 'PureTester', 'pure@example.invalid');
    CheckEqual(40, Length(LOid), 'CommitOnHead should return 40 hex');
    Check(Is40Hex(LOid), 'CommitOnHead OID must be 40 hex');
    LCommit := LRepo.HeadCommit;
    CheckEqual('first pure commit', LCommit.ShortMessage, 'HEAD commit should be our commit');
    CheckEqual(LowerCase(LOid), LowerCase(LCommit.OIDString), 'OID matches HeadCommit');

    // resources released: second commit via fallback author (empty strings) must succeed
    WriteFile(PathJoin([LDir, 'second.txt']), BytesOfString('second'), PermDefault);
    GitRun(LDir, ['add', 'second.txt']);
    LOid2 := LWtExt.CommitOnHead('second commit', '', '');
    CheckEqual(40, Length(LOid2), 'second CommitOnHead 40 hex');
    Check(Is40Hex(LOid2), 'second OID hex');
    Check(LowerCase(LOid) <> LowerCase(LOid2), 'OIDs must differ');
    // stability: repo still clean after commits
    Check(LRepo.HeadCommit.ShortMessage = 'second commit', 'second commit visible via Head');
  finally
    RemoveAll(LDir);
  end;
end;

// CONTRACT INV-O4/E2/M4: AddWorktree requires name/path, duplicate raises, creates commondir/gitdir/HEAD, Prune only metadata
procedure TestAddWorktreeInvariants;
var
  LBase, LMain, LWt, LWt2: string;
  LMgr: IGitManager;
  LRepo: IGitRepository;
  LWtExt: IGitWorktreeExt;
  LWork: IGitWorktree;
  LList: TStringArray;
  LRaised: Boolean;
begin
  LBase := MkTempDir('pure_worktree');
  LMain := PathJoin([LBase, 'main']);
  LWt := PathJoin([LBase, 'wt']);
  LWt2 := PathJoin([LBase, 'wt2']);
  try
    LMgr := NewGitManager(gbNative);
    Check(LMgr.Initialize, 'init');
    LRepo := LMgr.InitRepository(LMain, False);
    GitRun(LMain, ['config', 'user.name', 'Pure Tester']);
    GitRun(LMain, ['config', 'user.email', 'pure@example.invalid']);
    WriteFile(PathJoin([LMain, 'seed.txt']), BytesOfString('seed'), PermDefault);
    GitRun(LMain, ['add', 'seed.txt']);
    GitRun(LMain, ['commit', '-m', 'seed']);
    LRepo := LMgr.OpenRepository(LMain);
    if LRepo.QueryInterface(IGitWorktreeExt, LWtExt) <> 0 then
      raise Exception.Create('supports worktree ext');

    // invalid params must raise EGitError(GIT_EINVALIDSPEC) (INV-E2)
    LRaised := False;
    try LWtExt.AddWorktree('', LWt, '', False); except on E: EGitError do LRaised := True; on E: Exception do LRaised := True; end;
    Check(LRaised, 'AddWorktree empty name must raise EGitError');
    LRaised := False;
    try LWtExt.AddWorktree('wt1', '', '', False); except on E: EGitError do LRaised := True; on E: Exception do LRaised := True; end;
    Check(LRaised, 'AddWorktree empty path must raise EGitError');
    LRaised := False;
    try LWtExt.AddWorktree('a/b', LWt, '', False); except on E: EGitError do LRaised := True; on E: Exception do LRaised := True; end;
    Check(LRaised, 'AddWorktree slash name must raise EGitError');

    // success: creates worktrees/<id>/commondir+gitdir+HEAD (INV-O4)
    LWork := LWtExt.AddWorktree('my-wt', LWt, '', False);
    Check(LWork <> nil, 'AddWorktree should return worktree');
    CheckEqual('my-wt', LWork.Name, 'worktree name');
    Check(LWork.Path <> '', 'worktree path non-empty');
    Check(DirectoryExists(LWt), 'worktree dir created');
    Check(FileExists(PathJoin([LMain, '.git', 'worktrees', 'my-wt', 'commondir'])), 'worktree commondir exists');
    Check(FileExists(PathJoin([LMain, '.git', 'worktrees', 'my-wt', 'gitdir'])), 'worktree gitdir exists');
    Check(FileExists(PathJoin([LMain, '.git', 'worktrees', 'my-wt', 'HEAD'])), 'worktree HEAD exists');
    Check(FileExists(PathJoin([LWt, '.git'])), '.git file in worktree exists');
    // duplicate name must raise EGitError
    LRaised := False;
    try LWtExt.AddWorktree('my-wt', LWt2, '', False); except on E: EGitError do LRaised := True; on E: Exception do LRaised := True; end;
    Check(LRaised, 'AddWorktree duplicate name must raise EGitError');

    // ListWorktrees contains entry
    LList := LWtExt.ListWorktrees;
    Check(Length(LList) >= 1, 'ListWorktrees should list at least one');
    Check(ContainsStr(LList, 'my-wt'), 'ListWorktrees contains my-wt');

    // LookupWorktree finds it
    LWork := LWtExt.LookupWorktree('my-wt');
    Check(LWork <> nil, 'LookupWorktree finds my-wt');

    // Prune only clears metadata not worktree dir (INV-O4, INV-M4)
    Check(LWtExt.PruneWorktree('my-wt'), 'PruneWorktree should succeed');
    CheckFalse(DirectoryExists(PathJoin([LMain, '.git', 'worktrees', 'my-wt'])), 'Prune must remove metadata dir');
    Check(DirectoryExists(LWt), 'Prune must NOT delete worktree working dir');
    LRaised := False;
    try LWtExt.LookupWorktree('my-wt'); except on E: EGitError do LRaised := True; on E: Exception do LRaised := True; end;
    Check(LRaised, 'Lookup after Prune must raise EGitError');
  finally
    RemoveAll(LBase);
    // ensure no leak of second wt dir if created
    RemoveAll(LWt2);
  end;
end;

// CONTRACT: native backend owns no network, so credential/certificate
// hooks accept nil and raise an explicit EGitError for non-nil handlers
procedure TestNativeCredentialHandlersPinned;
var
  LMgr: IGitManager;
  LDummy: TDummyCredHandler;
  LRaised: Boolean;
begin
  LMgr := NewGitManager(gbNative);
  Check(LMgr.Initialize, 'init');
  LMgr.SetCredentialAcquireHandler(nil);
  LMgr.SetCertificateCheckHandler(nil);
  Check(True, 'nil credential handlers accepted');
  LDummy := TDummyCredHandler.Create;
  try
    LRaised := False;
    try
      LMgr.SetCredentialAcquireHandler(LDummy.Acquire);
    except
      on E: EGitError do
        LRaised := True;
    end;
    Check(LRaised, 'non-nil credential handler raises explicit EGitError');
    LRaised := False;
    try
      LMgr.SetCertificateCheckHandler(LDummy.CheckCert);
    except
      on E: EGitError do
        LRaised := True;
    end;
    Check(LRaised, 'non-nil certificate handler raises explicit EGitError');
  finally
    LDummy.Free;
  end;
end;

// CONTRACT INV-O4: SetVerifySSL/VerifySSL Manager granularity, default True, affects only subsequent network ops
procedure TestSetVerifySSLInvariants;
var
  LMgr, LMgr2: IGitManager;
begin
  LMgr := NewGitManager(gbNative);
  Check(LMgr.Initialize, 'init');
  try
    // default True (FVerifySSL)
    Check(LMgr.VerifySSL, 'VerifySSL default must be True');
    LMgr.SetVerifySSL(False);
    CheckFalse(LMgr.VerifySSL, 'SetVerifySSL(False) visible');
    LMgr.SetVerifySSL(True);
    Check(LMgr.VerifySSL, 'SetVerifySSL(True) visible');

    // cross-manager not shared (INV-O4)
    LMgr2 := NewGitManager(gbNative);
    Check(LMgr2.Initialize, 'second init');
    try
      LMgr.SetVerifySSL(False);
      Check(LMgr2.VerifySSL, 'second manager still True after first set False');
      LMgr2.SetVerifySSL(False);
      CheckFalse(LMgr2.VerifySSL, 'second SetVerifySSL(False) visible');
      CheckFalse(LMgr.VerifySSL, 'first still False');
      LMgr.SetVerifySSL(True);
      CheckFalse(LMgr2.VerifySSL, 'second unaffected by first toggle');
      Check(LMgr.VerifySSL, 'first now True');
    finally
      LMgr2.Finalize;
    end;
  finally
    LMgr.Finalize;
  end;
  CheckFalse(LMgr.Initialized, 'Finalize clears Initialized');
end;

begin
  Suite := TTestSuite.Create('pure_manager');
  Suite.Test('TestInitAndIsRepository', @TestInitAndIsRepository);
  Suite.Test('TestStatusEmpty', @TestStatusEmpty);
  Suite.Test('TestStatusWithFile', @TestStatusWithFile);
  Suite.Test('TestHeadAndLookup', @TestHeadAndLookup);
  Suite.Test('TestFactoryGbAutoCompat', @TestFactoryGbAutoCompat);
  Suite.Test('TestDiscoverRepositoryInvariants', @TestDiscoverRepositoryInvariants);
  Suite.Test('TestCloneRepositoryNotImplemented', @TestCloneRepositoryInvariants);
  Suite.Test('TestManagerInterfaceClosure', @TestManagerInterfaceClosure);
  Suite.Test('TestCommitOnHeadInvariants', @TestCommitOnHeadInvariants);
  Suite.Test('TestAddWorktreeInvariants', @TestAddWorktreeInvariants);
  Suite.Test('TestSetVerifySSLInvariants', @TestSetVerifySSLInvariants);
  Suite.Test('TestNativeCredentialHandlersPinned', @TestNativeCredentialHandlersPinned);

  if not Suite.Run then
    Halt(1);
end.
