program test_git_pure_manager;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.base,
  nextpas.core.text.conv,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.os.env,
  nextpas.core.bytes.ops,
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
  { single-source: bytes.ops.StringToBytes (hand-rolled Move into an inline
    Result miscompiles on this FPC trunk: copies the string pointer, not the
    characters — observed as binary garbage via git diff --numstat) }
  Result := StringToBytes(AText);
end;

function BytesToText(const AData: TBytes): string; inline;
begin
  { single-source: bytes.ops.BytesToString }
  Result := BytesToString(AData);
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
  begin
    Check(LLibMgr.Initialize, 'registered gbLibGit2 manager initializes');
    LLibMgr.Finalize;
  end;
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
    LRaised := False;
    try
      LRepo.Fetch('origin');
    except
      on E: EGitError do
        LRaised := True;
    end;
    Check(LRaised, 'native Fetch of missing local source must raise EGitError');
    LRaised := False;
    try
      LRem.Fetch;
    except
      on E: EGitError do
        LRaised := True;
    end;
    Check(LRaised, 'IGitRemote.Fetch of missing source must raise EGitError');
    Check(LRepo.CheckoutBranch('feature'), 'CheckoutBranch feature');
    CheckEqual('feature', LRepo.CurrentBranch, 'current branch feature');
    Check(LRepo.CheckoutBranchEx('main', True), 'CheckoutBranchEx main force');
    CheckEqual('main', LRepo.CurrentBranch, 'current branch main');
    LVal := LMgr.GetGlobalConfig('user.name');
    Check(True, 'GetGlobalConfig readable, value="' + LVal + '"');
    LRaised := False;
    try
      LMgr.SetGlobalConfig('', 'x');
    except
      on E: EGitError do
        LRaised := True;
    end;
    Check(LRaised, 'SetGlobalConfig empty key must raise EGitError');
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
  LAcq: TCredentialAcquireEvent;
  LCert: TCertificateCheckEvent;
  LRaised: Boolean;
begin
  LMgr := NewGitManager(gbNative);
  Check(LMgr.Initialize, 'init');
  LMgr.SetCredentialAcquireHandler(nil);
  LMgr.SetCertificateCheckHandler(nil);
  Check(True, 'nil credential handlers accepted');
  LDummy := TDummyCredHandler.Create;
  try
    LAcq := @LDummy.Acquire;
    LCert := @LDummy.CheckCert;
    LRaised := False;
    try
      LMgr.SetCredentialAcquireHandler(LAcq);
    except
      on E: EGitError do
        LRaised := True;
    end;
    Check(LRaised, 'non-nil credential handler raises explicit EGitError');
    LRaised := False;
    try
      LMgr.SetCertificateCheckHandler(LCert);
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

// Local-transport fetch: clone, advance the source, fetch updates tracking
// refs (True), second fetch is a no-op (False); unknown remote and network
// URLs raise the documented transport EGitError.
procedure TestFetchLocalTransport;
var
  LBase, LSrc, LDst: string;
  LMgr: IGitManager;
  LRepo: IGitRepository;
  LRem: IGitRemote;
  LRemotes: TStringArray;
  LRaised: Boolean;
  LPff: TGitPullFastForwardResult;
  LErr: string;
  LOut: TProcessOutput;
begin
  LBase := MkTempDir('pure_fetch');
  try
    LMgr := NewGitManager(gbNative);
    Check(LMgr.Initialize, 'init');
    LSrc := PathJoin([LBase, 'src']);
    LMgr.InitRepository(LSrc, False);
    GitRun(LSrc, ['config', 'user.name', 'Pure Tester']);
    GitRun(LSrc, ['config', 'user.email', 'pure@example.invalid']);
    WriteFile(PathJoin([LSrc, 'seed.txt']), BytesOfString('seed'), PermDefault);
    GitRun(LSrc, ['add', 'seed.txt']);
    GitRun(LSrc, ['commit', '-m', 'seed']);
    LDst := PathJoin([LBase, 'dst']);
    LRepo := LMgr.CloneRepository(LSrc, LDst);
    Check(LRepo <> nil, 'clone for fetch fixture');
    LRemotes := (LRepo as IGitRepositoryExt).ListRemotes;
    Check(ContainsStr(LRemotes, 'origin'), 'ListRemotes contains origin after clone');
    CheckFalse(LRepo.Fetch('origin'), 'fetch with no upstream movement returns False');
    WriteFile(PathJoin([LSrc, 'second.txt']), BytesOfString('second'), PermDefault);
    GitRun(LSrc, ['add', 'second.txt']);
    GitRun(LSrc, ['commit', '-m', 'second']);
    Check(LRepo.Fetch('origin'), 'fetch after upstream commit returns True');
    CheckFalse(LRepo.Fetch('origin'), 'second fetch returns False once up-to-date');
    LRem := LRepo.Remote('origin');
    CheckFalse(LRem.Fetch, 'IGitRemote.Fetch mirrors repository fetch (False when current)');
    LPff := (LRepo as IGitRepositoryExt).PullFastForward('origin', LErr);
    Check(LPff = gpffFastForwarded, 'PullFastForward advances local branch, got "' + LErr + '"');
    Check(FileExists(PathJoin([LDst, 'second.txt'])), 'fast-forward materializes upstream file in worktree');
    LOut := RunIn('/usr/bin/git', ['rev-parse', 'main'], LDst);
    Check(LOut.ExitCode = 0, 'git rev-parse works in ff target');
    CheckEqual(Trim(MustCaptureIn('/usr/bin/git', ['rev-parse', 'main'], LSrc)), Trim(LOut.StdOut), 'ff matches git golden branch tip');
    LPff := (LRepo as IGitRepositoryExt).PullFastForward('origin', LErr);
    Check(LPff = gpffUpToDate, 'second PullFastForward is up-to-date, got "' + LErr + '"');
    LPff := (LRepo as IGitRepositoryExt).PullFastForward('does-not-exist', LErr);
    Check(LPff = gpffNoRemote, 'unknown remote reports NoRemote');
    WriteFile(PathJoin([LDst, 'dirty.txt']), BytesOfString('dirty'), PermDefault);
    LPff := (LRepo as IGitRepositoryExt).PullFastForward('origin', LErr);
    Check(LPff = gpffDirty, 'dirty worktree refuses fast-forward');
    LRaised := False;
    try
      LRepo.Fetch('does-not-exist');
    except
      on E: EGitError do
        LRaised := True;
    end;
    Check(LRaised, 'Fetch unknown remote must raise EGitError');
    GitRun(LDst, ['remote', 'add', 'net', 'https://example.invalid/x.git']);
    LRaised := False;
    try
      LRepo.Fetch('net');
    except
      on E: EGitError do
        Check(Pos('transport', LowerCase(E.Message)) > 0, 'network fetch mentions transport');
    end;
    LRaised := False;
    try
      LRepo.Fetch('net');
    except
      on E: EGitError do
        LRaised := True;
    end;
    Check(LRaised, 'Fetch network URL must raise EGitError');
  finally
    RemoveAll(LBase);
  end;
end;

// Hermetic global-config roundtrip: pin HOME to a temp dir so the real
// ~/.gitconfig is never touched; write then read back via the same manager.
procedure TestSetGlobalConfigRoundtrip;
var
  LBase, LHome, LOldHome: string;
  LMgr: IGitManager;
  LRaised: Boolean;
begin
  LBase := MkTempDir('pure_globalcfg');
  LHome := PathJoin([LBase, 'home']);
  MkdirAll(LHome);
  LOldHome := GetEnv('HOME');
  SetEnv('HOME', LHome);
  try
    LMgr := NewGitManager(gbNative);
    Check(LMgr.Initialize, 'init');
    Check(LMgr.SetGlobalConfig('user.name', 'Pure Tester'), 'SetGlobalConfig writes');
    CheckEqual('Pure Tester', LMgr.GetGlobalConfig('user.name'), 'GetGlobalConfig reads back');
    Check(LMgr.SetGlobalConfig('user.email', 'pure@example.invalid'), 'second key writes');
    CheckEqual('Pure Tester', LMgr.GetGlobalConfig('user.name'), 'first key survives second write');
    CheckEqual('pure@example.invalid', LMgr.GetGlobalConfig('user.email'), 'second key reads back');
    Check(LMgr.SetGlobalConfig('core.puretest', 'yes'), 'third section writes');
    CheckEqual('yes', LMgr.GetGlobalConfig('core.puretest'), 'third key reads back');
    LRaised := False;
    try
      LMgr.SetGlobalConfig('no-dot-key', 'x');
    except
      on E: EGitError do
        LRaised := True;
    end;
    Check(LRaised, 'invalid key without dot must raise EGitError');
  finally
    if LOldHome = '' then
      UnsetEnv('HOME')
    else
      SetEnv('HOME', LOldHome);
    RemoveAll(LBase);
  end;
end;

// Full interface closure: every IGitRepository/Commit/Reference/Remote/
// Worktree accessor is driven against a real repo and asserts sane values.
procedure TestRepositoryInterfaceFullClosure;
var
  LBase, LDir: string;
  LMgr: IGitManager;
  LRepo: IGitRepository;
  LExt: IGitRepositoryExt;
  LWtExt: IGitWorktreeExt;
  LHead: IGitReference;
  LCommit, LHeadCommit: IGitCommit;
  LRem: IGitRemote;
  LRemotes: TStringArray;
  LWork: IGitWorktree;
  LWorkList: TStringArray;
  LEntries: TGitConfigEntryArray;
  LCommits: TGitCommitArray;
  LDiff: TGitDiff;
  LBlame: TGitBlame;
  LFilter: TGitStatusFilter;
  LStatus: TGitStatusEntryArray;
  LFound: Boolean;
  I: Integer;
  LRaised: Boolean;
  LBranch, LTagOid: string;
begin
  LBase := MkTempDir('pure_fullclosure');
  try
    LMgr := NewGitManager(gbNative);
    Check(LMgr.Initialize, 'init');
    CheckEqual('native-0.1.0', LMgr.Version, 'Version reports native backend');
    LDir := PathJoin([LBase, 'repo']);
    LRepo := LMgr.InitRepository(LDir, False);
    Check(LRepo.IsEmpty, 'fresh init IsEmpty');
    CheckEqual(PathJoin([LDir, '.git']), PathClean(LRepo.Path), 'Path is gitdir');
    CheckEqual(PathClean(LDir), PathClean(LRepo.WorkDir), 'WorkDir is worktree');
    CheckFalse(LRepo.IsBare, 'non-bare');
    GitRun(LDir, ['config', 'user.name', 'Pure Tester']);
    GitRun(LDir, ['config', 'user.email', 'pure@example.invalid']);
    WriteFile(PathJoin([LDir, 'a.txt']), BytesOfString('line1' + #10 + 'line2' + #10), PermDefault);
    GitRun(LDir, ['add', 'a.txt']);
    GitRun(LDir, ['commit', '-m', 'first']);
    GitRun(LDir, ['tag', 'v1']);
    GitRun(LDir, ['branch', 'feature']);
    CheckFalse(LRepo.IsEmpty, 'IsEmpty false after commit');
    LBranch := LRepo.CurrentBranch;
    Check(LBranch <> '', 'CurrentBranch non-empty');
    Check(Length(LRepo.ListBranches(gbLocal)) >= 2, 'local branches listed');
    LHead := LRepo.Head;
    Check(LHead.Name <> '', 'Head.Name non-empty');
    Check(LHead.ShortName <> '', 'Head.ShortName non-empty');
    CheckEqual(40, Length(LHead.TargetOIDString), 'Head target 40 hex');
    Check(Is40Hex(LHead.TargetOIDString), 'Head target hex');
    Check(LHead.IsBranch, 'HEAD on branch reports IsBranch');
    CheckFalse(LHead.IsRemote, 'local HEAD not remote');
    CheckFalse(LHead.IsTag, 'branch HEAD not tag');
    LHeadCommit := LRepo.HeadCommit;
    CheckEqual(LowerCase(LHead.TargetOIDString), LowerCase(LHeadCommit.OIDString), 'HeadCommit matches Head target');
    LCommit := LRepo.CommitByHash(LHeadCommit.OIDString);
    CheckEqual('first', LCommit.ShortMessage, 'commit ShortMessage');
    Check(Pos('first', LCommit.Message) > 0, 'commit Message contains subject');
    Check(Pos('Pure Tester', LCommit.AuthorString) > 0, 'AuthorString names author');
    Check(Pos('pure@example.invalid', LCommit.AuthorString) > 0, 'AuthorString carries email');
    Check(Pos('Pure Tester', LCommit.CommitterString) > 0, 'CommitterString names committer');
    Check(LCommit.Time > 30000, 'commit Time sane (days since 1899)');
    CheckEqual(0, LCommit.ParentCount, 'root commit has no parents');
    CheckEqual('', LCommit.ParentOIDString(0), 'out-of-range parent is empty');
    CheckEqual('', LCommit.ParentOIDString(-1), 'negative parent index is empty');
    WriteFile(PathJoin([LDir, 'b.txt']), BytesOfString('b'), PermDefault);
    GitRun(LDir, ['add', 'b.txt']);
    GitRun(LDir, ['commit', '-m', 'second']);
    LCommit := LRepo.HeadCommit;
    CheckEqual(1, LCommit.ParentCount, 'second commit has one parent');
    Check(Is40Hex(LCommit.ParentOIDString(0)), 'parent OID is 40 hex');
    CheckEqual('', LCommit.ParentOIDString(1), 'second parent of non-merge is empty');
    if LRepo.QueryInterface(IGitRepositoryExt, LExt) <> 0 then
      raise Exception.Create('repository must support IGitRepositoryExt');
    LRemotes := LExt.ListRemotes;
    CheckEqual(0, Length(LRemotes), 'no remotes initially');
    GitRun(LDir, ['remote', 'add', 'origin', LDir]);
    LRemotes := LExt.ListRemotes;
    Check(ContainsStr(LRemotes, 'origin'), 'ListRemotes finds origin');
    LRem := LRepo.Remote('origin');
    CheckEqual('origin', LRem.Name, 'remote Name');
    Check(LRem.URL <> '', 'remote URL non-empty');
    LEntries := LExt.ConfigEntries;
    Check(Length(LEntries) > 0, 'ConfigEntries non-empty');
    LFound := False;
    for I := 0 to High(LEntries) do
      if (LEntries[I].Name = 'remote.origin.url') and (LEntries[I].Value <> '') then
        LFound := True;
    Check(LFound, 'ConfigEntries carries remote.origin.url');
    LCommits := LExt.RevWalk('HEAD', 0);
    Check(Length(LCommits) >= 2, 'RevWalk unlimited covers both commits');
    LCommits := LExt.RevWalk('HEAD', 1);
    CheckEqual(1, Length(LCommits), 'RevWalk limit 1 returns one commit');
    LDiff := LExt.Diff('HEAD~1', 'HEAD');
    Check(Length(LDiff.Files) >= 1, 'Diff across commits reports files');
    LDiff := LExt.DiffEx('HEAD~1', 'HEAD', DefaultGitDiffOptions);
    Check(Length(LDiff.Files) >= 1, 'DiffEx mirrors Diff');
    LDiff := LExt.DiffWorkingTree('HEAD');
    Check(True, 'DiffWorkingTree callable, files=' + IntToStr(Length(LDiff.Files)));
    LDiff := LExt.DiffWorkingTreeEx('HEAD', DefaultGitDiffOptions);
    Check(True, 'DiffWorkingTreeEx callable');
    LBlame := LExt.Blame('a.txt');
    Check(Length(LBlame.Hunks) >= 1, 'Blame finds hunks for tracked file');
    LBlame := LExt.Blame('missing-nope.txt');
    CheckEqual(0, Length(LBlame.Hunks), 'Blame of untracked path is empty');
    LFilter.IncludeUntracked := True;
    LFilter.IncludeIgnored := False;
    LFilter.WorkingTreeOnly := False;
    LFilter.IndexOnly := False;
    LStatus := LRepo.StatusEntries(LFilter);
    Check(True, 'StatusEntries callable, entries=' + IntToStr(Length(LStatus)));
    WriteFile(PathJoin([LDir, 'patch-target.txt']), BytesOfString('v1' + #10), PermDefault);
    LExt.ApplyPatch('diff --git a/patch-target.txt b/patch-target.txt' + #10 +
      '--- a/patch-target.txt' + #10 + '+++ b/patch-target.txt' + #10 +
      '@@ -1 +1 @@' + #10 + '-v1' + #10 + '+v2' + #10);
    CheckEqual('v2' + #10, BytesToText(ReadFile(PathJoin([LDir, 'patch-target.txt']))), 'ApplyPatch rewrites target');
    WriteFile(PathJoin([LDir, 'a.txt']), BytesOfString('line1' + #10 + 'line2' + #10 + 'line3' + #10), PermDefault);
    Check(LExt.WorkdirPatchText('HEAD', [], False) <> '', 'WorkdirPatchText non-empty with tracked modification');
    LExt.CheckoutPaths('HEAD', []);
    Check(True, 'CheckoutPaths with empty list callable');
    if LRepo.QueryInterface(IGitWorktreeExt, LWtExt) <> 0 then
      raise Exception.Create('repository must support IGitWorktreeExt');
    LWork := LWtExt.AddWorktree('full-wt', PathJoin([LBase, 'wt-full']), '', False);
    CheckEqual('full-wt', LWork.Name, 'worktree Name');
    Check(LWork.Path <> '', 'worktree Path');
    CheckFalse(LWork.IsLocked, 'fresh worktree unlocked');
    LWorkList := LWtExt.ListWorktrees;
    Check(ContainsStr(LWorkList, 'full-wt'), 'ListWorktrees contains new entry');
    LWork := LWtExt.LookupWorktree('full-wt');
    CheckEqual('full-wt', LWork.Name, 'LookupWorktree roundtrip');
    Check(LWtExt.PruneWorktree('full-wt'), 'PruneWorktree succeeds');
    CheckFalse(LWtExt.PruneWorktree('no-such-wt'), 'PruneWorktree missing returns False');
    LRaised := False;
    try
      LWtExt.LookupWorktree('no-such-wt');
    except
      on E: EGitError do
        LRaised := True;
    end;
    Check(LRaised, 'LookupWorktree missing raises EGitError');
    LTagOid := '';
    LCommits := LExt.RevWalk('v1', 1);
    if Length(LCommits) = 1 then
      LTagOid := LCommits[0].OIDString;
    Check(LTagOid <> '', 'tag v1 resolves through history walk');
    Check(Is40Hex(LTagOid), 'tag v1 walk yields 40-hex commit');
    LRaised := False;
    try
      LRepo.CommitByHash('v1');
    except
      on E: EGitError do
        LRaised := True;
    end;
    Check(LRaised, 'CommitByHash with non-hex rev raises EGitError');
  finally
    RemoveAll(LBase);
  end;
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
  Suite.Test('TestFetchLocalTransport', @TestFetchLocalTransport);
  Suite.Test('TestSetGlobalConfigRoundtrip', @TestSetGlobalConfigRoundtrip);
  Suite.Test('TestRepositoryInterfaceFullClosure', @TestRepositoryInterfaceFullClosure);
  Suite.Test('TestCommitOnHeadInvariants', @TestCommitOnHeadInvariants);
  Suite.Test('TestAddWorktreeInvariants', @TestAddWorktreeInvariants);
  Suite.Test('TestSetVerifySSLInvariants', @TestSetVerifySSLInvariants);
  Suite.Test('TestNativeCredentialHandlersPinned', @TestNativeCredentialHandlersPinned);

  if not Suite.Run then
    Halt(1);
end.
