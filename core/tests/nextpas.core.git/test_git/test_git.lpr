program test_git;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.fs,
  nextpas.core.os.env,
  nextpas.core.process,
  nextpas.core.git,
  nextpas.core.git.libgit2.binding;

type
  TGitCallbackFixture = class
    function Credential(const Url, UserFromURL: string; AllowedTypes: Cardinal): Boolean;
    function Certificate(const Host: string; Valid: Boolean): Boolean;
  end;

var
  T: TTestRunner;
  GTmpDir: string;

function TGitCallbackFixture.Credential(const Url, UserFromURL: string; AllowedTypes: Cardinal): Boolean;
begin
  if (Url = '') and (UserFromURL = '') and (AllowedTypes = 0) then;
  Result := False;
end;

function TGitCallbackFixture.Certificate(const Host: string; Valid: Boolean): Boolean;
begin
  if (Host = '') and Valid then;
  Result := False;
end;

procedure SetupTmpDir;
begin
  GTmpDir := nextpas.core.fs.PathJoin([
    nextpas.core.fs.GetTempDir,
    'nextpas_git_test_' + IntToStr(GetProcessID)
  ]);
  nextpas.core.fs.RemoveAll(GTmpDir);
  nextpas.core.fs.MkdirAll(GTmpDir);
end;

procedure CleanupTmpDir;
begin
  nextpas.core.fs.RemoveAll(GTmpDir);
end;

function BytesOfString(const AText: string): TBytes;
begin
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(AText[1], Result[0], Length(AText));
end;

function ContainsPath(const AItems: TStringArray; const AName: string): Boolean;
var
  LItem: string;
begin
  Result := False;
  for LItem in AItems do
    if LItem = AName then
      Exit(True);
end;

procedure RestoreEnv(const AName: string; const AHadValue: Boolean; const AOldValue: string);
begin
  if AHadValue then
    SetEnv(AName, AOldValue)
  else
    UnsetEnv(AName);
end;

procedure CheckGitOk(const ADir: string; const AArgs: array of string; const AMessage: string);
var
  LOut: TProcessOutput;
begin
  LOut := nextpas.core.process.RunIn('/usr/bin/git', AArgs, ADir);
  CheckEqual(0, LOut.ExitCode, AMessage + ': ' + LOut.StdErr);
end;

procedure TestLibGit2LoaderReportsMissingOverride;
const
  LIBGIT2_PATH_ENV = 'NEXTPAS_LIBGIT2_PATH';
var
  LHadPath: Boolean;
  LOldPath: string;
  LMissingPath: string;
begin
  {$IFDEF NEXTPAS_CORE_GIT_LIBGIT2_STATIC}
  Exit;
  {$ENDIF}

  LHadPath := HasEnv(LIBGIT2_PATH_ENV);
  LOldPath := GetEnv(LIBGIT2_PATH_ENV);
  LMissingPath := nextpas.core.fs.PathJoin([GTmpDir, 'missing-libgit2.so']);

  try
    SetEnv(LIBGIT2_PATH_ENV, LMissingPath);

    Check(not EnsureLibGit2Loaded,
      'libgit2 loader should fail when explicit override points to a missing library');
    Check(not IsLibGit2Loaded,
      'libgit2 loader should remain unloaded after a failed explicit override');
    CheckEqual('', GetLibGit2LoadedPath,
      'libgit2 loaded path should be empty after failed load');
  finally
    RestoreEnv(LIBGIT2_PATH_ENV, LHadPath, LOldPath);
  end;
end;

procedure TestLibGit2LoaderReportsSymbolResolutionFailure;
const
  LIBGIT2_PATH_ENV = 'NEXTPAS_LIBGIT2_PATH';
var
  LHadPath: Boolean;
  LOldPath: string;
  LWrongLibraryPath: string;
begin
  {$IFDEF NEXTPAS_CORE_GIT_LIBGIT2_STATIC}
  Exit;
  {$ENDIF}

  {$IFDEF NEXTPAS_LINUX}
  LWrongLibraryPath := '/lib/x86_64-linux-gnu/libc.so.6';
  if not FileExists(LWrongLibraryPath) then
    LWrongLibraryPath := '/lib64/libc.so.6';
  if not FileExists(LWrongLibraryPath) then
    Exit;
  {$ELSE}
  Exit;
  {$ENDIF}

  LHadPath := HasEnv(LIBGIT2_PATH_ENV);
  LOldPath := GetEnv(LIBGIT2_PATH_ENV);
  try
    SetEnv(LIBGIT2_PATH_ENV, LWrongLibraryPath);

    Check(not EnsureLibGit2Loaded,
      'libgit2 loader should fail when required libgit2 symbols are missing');
    Check(not IsLibGit2Loaded,
      'libgit2 loader should remain unloaded after symbol resolution failure');
    CheckEqual('', GetLibGit2LoadedPath,
      'libgit2 loaded path should be empty after symbol resolution failure');
  finally
    RestoreEnv(LIBGIT2_PATH_ENV, LHadPath, LOldPath);
  end;
end;

procedure TestLibGit2LoaderReportsLoadedPath;
var
  LPath: string;
begin
  Check(EnsureLibGit2Loaded, 'libgit2 loader should load the real library');
  Check(IsLibGit2Loaded, 'libgit2 loader should report loaded state');
  LPath := GetLibGit2LoadedPath;
  Check(LPath <> '', 'libgit2 loader should expose the loaded library path');
  Check(Pos('git2', LowerCase(LPath)) > 0,
    'libgit2 loaded library path should identify a git2 library');
end;

procedure TestDiscoverRepositoryFallsBackToDotGitDirectory;
var
  LMgr: IGitManager;
  LRootDir: string;
  LNestedDir: string;
begin
  LRootDir := nextpas.core.fs.PathJoin([GTmpDir, 'discover']);
  LNestedDir := nextpas.core.fs.PathJoin([LRootDir, 'a', 'b', 'c']);
  nextpas.core.fs.MkdirAll(nextpas.core.fs.PathJoin([LRootDir, '.git']));
  nextpas.core.fs.MkdirAll(LNestedDir);

  LMgr := NewGitManager;
  CheckEqual(ExpandFileName(LRootDir), LMgr.DiscoverRepository(LNestedDir),
    'DiscoverRepository should find ancestor .git directory');
end;

procedure TestDiscoverRepositorySupportsGitFileWorktree;
var
  LMgr: IGitManager;
  LMainDir: string;
  LLinkedDir: string;
  LNestedDir: string;
begin
  LMainDir := nextpas.core.fs.PathJoin([GTmpDir, 'discover-main']);
  LLinkedDir := nextpas.core.fs.PathJoin([GTmpDir, 'discover-linked']);
  LNestedDir := nextpas.core.fs.PathJoin([LLinkedDir, 'nested']);
  nextpas.core.fs.MkdirAll(LMainDir);

  CheckGitOk(LMainDir, ['init'], 'git init main repo for worktree discover');
  CheckGitOk(LMainDir, ['config', 'user.name', 'NextPas Tester'], 'git config user.name');
  CheckGitOk(LMainDir, ['config', 'user.email', 'nextpas@example.invalid'], 'git config user.email');
  nextpas.core.fs.WriteFile(
    nextpas.core.fs.PathJoin([LMainDir, 'seed.txt']),
    BytesOfString('seed')
  );
  CheckGitOk(LMainDir, ['add', 'seed.txt'], 'git add seed file');
  CheckGitOk(LMainDir, ['commit', '-m', 'seed'], 'git commit seed');
  CheckGitOk(LMainDir, ['worktree', 'add', '-b', 'linked-branch', LLinkedDir, 'HEAD'],
    'git worktree add linked repo');
  nextpas.core.fs.MkdirAll(LNestedDir);

  LMgr := NewGitManager;
  CheckEqual(ExpandFileName(LLinkedDir), LMgr.DiscoverRepository(LNestedDir),
    'DiscoverRepository should resolve linked worktree .git file to worktree root');
end;

procedure TestFacadeReexportsBaseConstants;
var
  LFlags: TGitStatusFlags;
begin
  CheckEqual(2, Ord(gbAll),
    'git facade should re-export branch constants');
  CheckEqual(5, Ord(gpffDirty),
    'git facade should re-export pull result constants');
  LFlags := [gsWtNew, gsIndexModified];
  Check(gsWtNew in LFlags, 'git facade should re-export status flags');
  Check(gsIndexModified in LFlags, 'git facade should re-export index status flags');
end;

procedure TestUnsupportedCallbacksAreExplicit;
var
  LMgr: IGitManager;
  LFixture: TGitCallbackFixture;
  LRaised: Boolean;
begin
  LMgr := NewGitManager;
  LFixture := TGitCallbackFixture.Create;
  try
    LMgr.SetCredentialAcquireHandler(nil);
    LMgr.SetCertificateCheckHandler(nil);

    LRaised := False;
    try
      LMgr.SetCredentialAcquireHandler(@LFixture.Credential);
    except
      on E: EGitError do
        LRaised := True;
    end;
    Check(LRaised, 'credential callback handler should report unsupported explicitly');

    LRaised := False;
    try
      LMgr.SetCertificateCheckHandler(@LFixture.Certificate);
    except
      on E: EGitError do
        LRaised := True;
    end;
    Check(LRaised, 'certificate callback handler should report unsupported explicitly');
  finally
    LFixture.Free;
  end;
end;

procedure TestInitRepositorySupportsDiscardedReturnValue;
var
  LMgr: IGitManager;
  LRepoDir: string;
  LRepo: IGitRepository;
begin
  LRepoDir := nextpas.core.fs.PathJoin([GTmpDir, 'init-discarded']);
  nextpas.core.fs.MkdirAll(LRepoDir);

  LMgr := NewGitManager;
  Check(LMgr.Initialize, 'libgit2 manager should initialize');

  LMgr.InitRepository(LRepoDir, False);

  Check(LMgr.IsRepository(LRepoDir), 'InitRepository should create a repository');
  LRepo := LMgr.OpenRepository(LRepoDir);
  Check(LRepo <> nil, 'OpenRepository should return repository after discarded init');
  CheckEqual(False, LRepo.IsBare, 'Repository should be non-bare by default');
end;

procedure TestStatusSeesUntrackedFileAfterInit;
var
  LMgr: IGitManager;
  LRepoDir: string;
  LRepo: IGitRepository;
  LStatuses: TStringArray;
begin
  LRepoDir := nextpas.core.fs.PathJoin([GTmpDir, 'status']);
  nextpas.core.fs.MkdirAll(LRepoDir);

  LMgr := NewGitManager;
  Check(LMgr.Initialize, 'libgit2 manager should initialize for status test');
  LRepo := LMgr.InitRepository(LRepoDir, False);
  Check(LRepo <> nil, 'InitRepository should return repository');

  nextpas.core.fs.WriteFile(
    nextpas.core.fs.PathJoin([LRepoDir, 'tracked-later.txt']),
    BytesOfString('hello git')
  );

  LStatuses := LRepo.Status;
  Check(Length(LStatuses) > 0, 'Status should report untracked file');
  Check(ContainsPath(LStatuses, 'tracked-later.txt'),
    'Status should include created file path');
end;

procedure TestExplicitFinalizeWaitsForLiveRepository;
var
  LMgr: IGitManager;
  LRepoDir: string;
  LRepo: IGitRepository;
begin
  LRepoDir := nextpas.core.fs.PathJoin([GTmpDir, 'deferred-finalize']);
  nextpas.core.fs.MkdirAll(LRepoDir);

  LMgr := NewGitManager;
  Check(LMgr.Initialize, 'libgit2 manager should initialize for deferred finalize test');
  LRepo := LMgr.InitRepository(LRepoDir, False);

  LMgr.Finalize;
  Check(LMgr.Initialized,
    'Finalize should be deferred while repository handles are still alive');
  CheckEqual(False, LRepo.IsBare,
    'Repository should remain usable after deferred Finalize request');

  LRepo := nil;
  Check(not LMgr.Initialized,
    'Finalize should complete after the last repository handle is released');
end;

procedure TestInitializeIsIdempotent;
var
  LMgr: IGitManager;
  LInitCount: Integer;
begin
  LMgr := NewGitManager;
  Check(LMgr.Initialize, 'first Initialize should succeed');
  Check(LMgr.Initialize, 'second Initialize should be idempotent');
  LMgr.Finalize;
  Check(not LMgr.Initialized, 'single Finalize should close an idempotently initialized manager');

  LInitCount := git_libgit2_init;
  CheckEqual(1, LInitCount,
    'libgit2 init refcount should be balanced after idempotent Initialize/Finalize');
  CheckEqual(0, git_libgit2_shutdown,
    'direct libgit2 cleanup should return to zero after refcount probe');
end;

procedure TestHeadCommitLoadsMetadataAndSurvivesRepositoryRelease;
var
  LMgr: IGitManager;
  LRepoDir: string;
  LRepo: IGitRepository;
  LCommit: IGitCommit;
begin
  LRepoDir := nextpas.core.fs.PathJoin([GTmpDir, 'commit']);
  nextpas.core.fs.MkdirAll(LRepoDir);

  LMgr := NewGitManager;
  Check(LMgr.Initialize, 'libgit2 manager should initialize for commit test');
  LRepo := LMgr.InitRepository(LRepoDir, False);

  CheckGitOk(LRepoDir, ['config', 'user.name', 'NextPas Tester'], 'git config user.name');
  CheckGitOk(LRepoDir, ['config', 'user.email', 'nextpas@example.invalid'], 'git config user.email');
  nextpas.core.fs.WriteFile(
    nextpas.core.fs.PathJoin([LRepoDir, 'committed.txt']),
    BytesOfString('committed content')
  );
  CheckGitOk(LRepoDir, ['add', 'committed.txt'], 'git add committed file');
  CheckGitOk(LRepoDir, ['commit', '-m', 'core git commit metadata'], 'git commit');

  LCommit := LRepo.HeadCommit;
  LRepo := nil;
  LMgr := nil;

  CheckEqual('core git commit metadata', LCommit.ShortMessage,
    'HeadCommit should expose the short commit message');
  Check(Pos('NextPas Tester <nextpas@example.invalid>', LCommit.AuthorString) = 1,
    'HeadCommit should expose author identity');
  CheckEqual(40, Length(LCommit.OIDString), 'HeadCommit should expose 40-byte hex oid');
end;

begin
  SetupTmpDir;
  try
    T := TTestRunner.Create('nextpas.core.git');
    T.Run('libgit2 loader reports missing override', @TestLibGit2LoaderReportsMissingOverride);
    T.Run('libgit2 loader reports symbol failure', @TestLibGit2LoaderReportsSymbolResolutionFailure);
    T.Run('libgit2 loader reports loaded path', @TestLibGit2LoaderReportsLoadedPath);
    T.Run('Facade re-exports base constants', @TestFacadeReexportsBaseConstants);
    T.Run('Unsupported callbacks are explicit', @TestUnsupportedCallbacksAreExplicit);
    T.Run('DiscoverRepository fallback', @TestDiscoverRepositoryFallsBackToDotGitDirectory);
    T.Run('DiscoverRepository supports gitfile worktree', @TestDiscoverRepositorySupportsGitFileWorktree);
    T.Run('InitRepository discarded return value', @TestInitRepositorySupportsDiscardedReturnValue);
    T.Run('Initialize is idempotent', @TestInitializeIsIdempotent);
    T.Run('Status sees untracked file', @TestStatusSeesUntrackedFileAfterInit);
    T.Run('Explicit Finalize waits for live repository', @TestExplicitFinalizeWaitsForLiveRepository);
    T.Run('HeadCommit metadata', @TestHeadCommitLoadsMetadataAndSurvivesRepositoryRelease);
    T.Summary;
  finally
    CleanupTmpDir;
  end;
end.
