program test_git;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.base,
  nextpas.core.text.conv,
  nextpas.core.fs,
  nextpas.core.bytes.ops,
  nextpas.core.path,
  nextpas.core.test,
  nextpas.core.os.env,
  nextpas.core.process,
  nextpas.core.git,
  nextpas.core.git.base,
  nextpas.core.git.libgit2.binding,
  nextpas.core.git.libgit2;

type
  TGitCallbackFixture = class
    function Credential(const Url, UserFromURL: string; AllowedTypes: Cardinal): Boolean;
    function Certificate(const Host: string; Valid: Boolean): Boolean;
  end;

var
  T: TTestSuite;
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
  { single-source: bytes.ops.StringToBytes (a hand-rolled Move into an inline
    Result miscompiles on this FPC trunk: copies the string pointer, not the
    characters — observed as binary garbage via git diff --numstat) }
  Result := nextpas.core.bytes.ops.StringToBytes(AText);
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
  CheckEqual(ExpandFileName(LRootDir), ExpandFileName(LMgr.DiscoverRepository(LNestedDir)),
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
  CheckEqual(nextpas.core.fs.PathRealPath(ExpandFileName(LLinkedDir)),
    nextpas.core.fs.PathRealPath(LMgr.DiscoverRepository(LNestedDir)),
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

procedure TestAddWorktreeCreatesLinkedWorktree;
var
  LMgr: IGitManager;
  LMainDir, LWtDir: string;
  LRepo, LWtRepo: IGitRepository;
  LWtExt: IGitWorktreeExt;
  LWt: IGitWorktree;
  LList: TStringArray;
begin
  LMainDir := nextpas.core.fs.PathJoin([GTmpDir, 'wt-main']);
  LWtDir := nextpas.core.fs.PathJoin([GTmpDir, 'wt-linked']);

  nextpas.core.fs.MkdirAll(LMainDir);
  LMgr := NewGitManager;
  Check(LMgr.Initialize, 'libgit2 manager should initialize for worktree test');
  LRepo := LMgr.InitRepository(LMainDir, False);

  CheckGitOk(LMainDir, ['config', 'user.name', 'NextPas Tester'], 'git config user.name');
  CheckGitOk(LMainDir, ['config', 'user.email', 'nextpas@example.invalid'], 'git config user.email');
  nextpas.core.fs.WriteFile(
    nextpas.core.fs.PathJoin([LMainDir, 'seed.txt']),
    BytesOfString('seed')
  );
  CheckGitOk(LMainDir, ['add', 'seed.txt'], 'git add seed');
  CheckGitOk(LMainDir, ['commit', '-m', 'seed'], 'git commit seed');

  if LRepo.QueryInterface(IGitWorktreeExt, LWtExt) <> 0 then
  begin
    Check(False, 'IGitRepository should support IGitWorktreeExt');
    Exit;
  end;

  LWt := LWtExt.AddWorktree('my-wt', LWtDir, '', False);
  Check(LWt <> nil, 'AddWorktree should return a worktree');
  CheckEqual('my-wt', LWt.Name, 'worktree name');
  Check(Length(LWt.Path) > 0, 'worktree path should be non-empty');

  LList := LWtExt.ListWorktrees;
  Check(Length(LList) >= 1, 'ListWorktrees should list at least one worktree');

  { Open the worktree as a repository and verify it is a worktree }
  LWtRepo := LMgr.OpenRepository(LWtDir);
  Check(LWtRepo <> nil, 'should be able to open worktree as repository');
  Check(not LWtRepo.IsBare, 'worktree should not be bare');

  { Cleanup: release worktree handle before repo to avoid dangling ref }
  LWt := nil;
  LWtRepo := nil;
  { Remove worktree directory first, then prune git metadata via CLI }
  nextpas.core.fs.RemoveAll(LWtDir);
  { 'git worktree remove' may fail if dir already gone; that's ok }
  CheckGitOk(LMainDir, ['worktree', 'prune'], 'git worktree prune');
end;

procedure TestCommitOnHeadCreatesCommit;
var
  LMgr: IGitManager;
  LRepoDir: string;
  LRepo: IGitRepository;
  LWtExt: IGitWorktreeExt;
  LCommit: IGitCommit;
  LOID: string;
begin
  LRepoDir := nextpas.core.fs.PathJoin([GTmpDir, 'wt-commit']);
  nextpas.core.fs.MkdirAll(LRepoDir);

  LMgr := NewGitManager;
  Check(LMgr.Initialize, 'libgit2 manager should initialize for commit test');
  LRepo := LMgr.InitRepository(LRepoDir, False);

  CheckGitOk(LRepoDir, ['config', 'user.name', 'NextPas Tester'], 'git config user.name');
  CheckGitOk(LRepoDir, ['config', 'user.email', 'nextpas@example.invalid'], 'git config user.email');

  if LRepo.QueryInterface(IGitWorktreeExt, LWtExt) <> 0 then
  begin
    Check(False, 'IGitRepository should support IGitWorktreeExt');
    Exit;
  end;

  nextpas.core.fs.WriteFile(
    nextpas.core.fs.PathJoin([LRepoDir, 'file1.txt']),
    BytesOfString('content1')
  );
  { Stage via git CLI (libgit2 index add bypath would also work) }
  CheckGitOk(LRepoDir, ['add', 'file1.txt'], 'git add file1');

  LOID := LWtExt.CommitOnHead('first commit', 'Tester', 'test@example.invalid');
  CheckEqual(40, Length(LOID), 'CommitOnHead should return 40-char OID');

  LCommit := LRepo.HeadCommit;
  CheckEqual('first commit', LCommit.ShortMessage, 'HEAD commit should be our commit');
end;

procedure TestDiffReportsHunksAndStats;
var
  LMgr: IGitManager;
  LRepoDir: string;
  LRepo: IGitRepository;
  LExt: IGitRepositoryExt;
  LFile: string;
  LDiff: TGitDiff;
  LHunk: TGitDiffHunk;
begin
  LRepoDir := nextpas.core.fs.PathJoin([GTmpDir, 'diff']);
  nextpas.core.fs.MkdirAll(LRepoDir);

  LMgr := NewGitManager;
  Check(LMgr.Initialize, 'libgit2 manager should initialize for diff test');
  LRepo := LMgr.InitRepository(LRepoDir, False);
  CheckGitOk(LRepoDir, ['config', 'user.name', 'NextPas Tester'], 'git config user.name');
  CheckGitOk(LRepoDir, ['config', 'user.email', 'nextpas@example.invalid'], 'git config user.email');

  LFile := nextpas.core.fs.PathJoin([LRepoDir, 'a.txt']);
  nextpas.core.fs.WriteFile(LFile, BytesOfString('line1' + LineEnding + 'line2' + LineEnding + 'line3' + LineEnding));
  CheckGitOk(LRepoDir, ['add', 'a.txt'], 'git add a.txt');
  CheckGitOk(LRepoDir, ['commit', '-m', 'c1'], 'git commit c1');

  nextpas.core.fs.WriteFile(LFile, BytesOfString('line1' + LineEnding + 'line2-modified' + LineEnding + 'line3' + LineEnding + 'line4' + LineEnding));
  CheckGitOk(LRepoDir, ['add', 'a.txt'], 'git add a.txt (modified)');
  CheckGitOk(LRepoDir, ['commit', '-m', 'c2'], 'git commit c2');

  LExt := LRepo as IGitRepositoryExt;
  LDiff := LExt.Diff('HEAD~1', 'HEAD');

  CheckEqual(1, Length(LDiff.Files), 'Diff HEAD~1..HEAD should report one file');
  CheckEqual('a.txt', LDiff.Files[0].OldPath, 'Diff should report old path');
  CheckEqual('a.txt', LDiff.Files[0].NewPath, 'Diff should report new path');
  Check(LDiff.Files[0].Status = gdsModified, 'Diff should report modified status');
  CheckEqual(2, LDiff.Files[0].Additions, 'Diff should count two added lines');
  CheckEqual(1, LDiff.Files[0].Deletions, 'Diff should count one deleted line');
  Check(Length(LDiff.Files[0].Hunks) >= 1, 'Diff should expose at least one hunk');
  LHunk := LDiff.Files[0].Hunks[0];
  CheckEqual(1, LHunk.OldStart, 'Hunk old start should be line 1');
  CheckEqual(1, LHunk.NewStart, 'Hunk new start should be line 1');
  Check(Length(LHunk.Lines) >= 4, 'Hunk should expose prefixed lines');

  // Working-tree diff after an uncommitted change
  nextpas.core.fs.WriteFile(LFile, BytesOfString('line1' + LineEnding + 'line2-modified' + LineEnding + 'line3' + LineEnding + 'line4' + LineEnding + 'line5' + LineEnding));
  LDiff := LExt.DiffWorkingTree('HEAD');
  CheckEqual(1, Length(LDiff.Files), 'DiffWorkingTree should report the modified file');
  CheckEqual(1, LDiff.Files[0].Additions, 'DiffWorkingTree should count one added line');
end;

{ M5+ (2026-08-15): DiffEx 参数化——unified 行数 + 路径过滤 }
procedure TestDiffExOptions;
var
  LMgr: IGitManager;
  LRepoDir: string;
  LRepo: IGitRepository;
  LExt: IGitRepositoryExt;
  LFileA, LFileB: string;
  LDiff: TGitDiff;
  LOpts: TGitDiffOptions;
  I, J: Integer;
  LHunk: TGitDiffHunk;
  HasContext: Boolean;
begin
  LRepoDir := nextpas.core.fs.PathJoin([GTmpDir, 'diffex']);
  nextpas.core.fs.MkdirAll(LRepoDir);

  LMgr := NewGitManager;
  Check(LMgr.Initialize, 'libgit2 manager initialize for diffex');
  LRepo := LMgr.InitRepository(LRepoDir, False);
  CheckGitOk(LRepoDir, ['config', 'user.name', 'NextPas Tester'], 'git config user.name');
  CheckGitOk(LRepoDir, ['config', 'user.email', 'nextpas@example.invalid'], 'git config user.email');

  LFileA := nextpas.core.fs.PathJoin([LRepoDir, 'a.txt']);
  LFileB := nextpas.core.fs.PathJoin([LRepoDir, 'b.txt']);
  nextpas.core.fs.WriteFile(LFileA, BytesOfString('a1' + LineEnding + 'a2' + LineEnding + 'a3' + LineEnding));
  nextpas.core.fs.WriteFile(LFileB, BytesOfString('b1' + LineEnding + 'b2' + LineEnding + 'b3' + LineEnding));
  CheckGitOk(LRepoDir, ['add', '.'], 'git add all');
  CheckGitOk(LRepoDir, ['commit', '-m', 'c1'], 'git commit c1');

  nextpas.core.fs.WriteFile(LFileA, BytesOfString('a1' + LineEnding + 'a2-changed' + LineEnding + 'a3' + LineEnding));
  nextpas.core.fs.WriteFile(LFileB, BytesOfString('b1' + LineEnding + 'b2-changed' + LineEnding + 'b3' + LineEnding));
  CheckGitOk(LRepoDir, ['add', '.'], 'git add both');
  CheckGitOk(LRepoDir, ['commit', '-m', 'c2'], 'git commit c2');

  LExt := LRepo as IGitRepositoryExt;

  { 路径过滤：只 diff a.txt }
  LOpts := DefaultGitDiffOptions;
  SetLength(LOpts.Paths, 1);
  LOpts.Paths[0] := 'a.txt';
  LDiff := LExt.DiffEx('HEAD~1', 'HEAD', LOpts);
  CheckEqual(1, Length(LDiff.Files), 'path filter keeps only a.txt');
  CheckEqual('a.txt', LDiff.Files[0].NewPath, 'filtered file is a.txt');
  LDiff := LExt.DiffEx('HEAD~1', 'HEAD', DefaultGitDiffOptions);
  CheckEqual(2, Length(LDiff.Files), 'no filter reports both files');

  { unified=0：hunk 内无空格上下文行 }
  LOpts := DefaultGitDiffOptions;
  LOpts.UnifiedLines := 0;
  LDiff := LExt.DiffEx('HEAD~1', 'HEAD', LOpts);
  CheckEqual(2, Length(LDiff.Files), 'unified=0 still both files');
  HasContext := False;
  for I := 0 to High(LDiff.Files[0].Hunks) do
  begin
    LHunk := LDiff.Files[0].Hunks[I];
    for J := 0 to High(LHunk.Lines) do
      if (Length(LHunk.Lines[J]) > 0) and (LHunk.Lines[J][1] = ' ') then
        HasContext := True;
  end;
  Check(not HasContext, 'unified=0 drops context lines');
end;

{ M5+ (2026-08-15): Blame——逐 hunk 归属 commit }
procedure TestBlameFile;
var
  LMgr: IGitManager;
  LRepoDir: string;
  LRepo: IGitRepository;
  LExt: IGitRepositoryExt;
  LFile: string;
  LBlame: TGitBlame;
  I: Integer;
begin
  LRepoDir := nextpas.core.fs.PathJoin([GTmpDir, 'blame']);
  nextpas.core.fs.MkdirAll(LRepoDir);

  LMgr := NewGitManager;
  Check(LMgr.Initialize, 'libgit2 manager initialize for blame');
  LRepo := LMgr.InitRepository(LRepoDir, False);
  CheckGitOk(LRepoDir, ['config', 'user.name', 'NextPas Tester'], 'git config user.name');
  CheckGitOk(LRepoDir, ['config', 'user.email', 'nextpas@example.invalid'], 'git config user.email');

  LFile := nextpas.core.fs.PathJoin([LRepoDir, 'src.txt']);
  nextpas.core.fs.WriteFile(LFile, BytesOfString('one' + LineEnding + 'two' + LineEnding + 'three' + LineEnding));
  CheckGitOk(LRepoDir, ['add', 'src.txt'], 'git add src.txt');
  CheckGitOk(LRepoDir, ['commit', '-m', 'c1'], 'git commit c1');

  nextpas.core.fs.WriteFile(LFile, BytesOfString('one' + LineEnding + 'two-changed' + LineEnding + 'three' + LineEnding));
  CheckGitOk(LRepoDir, ['add', 'src.txt'], 'git add src.txt (modified)');
  CheckGitOk(LRepoDir, ['commit', '-m', 'c2'], 'git commit c2');

  LExt := LRepo as IGitRepositoryExt;
  LBlame := LExt.Blame('src.txt');

  CheckEqual('src.txt', LBlame.Path, 'blame path');
  Check(Length(LBlame.Hunks) >= 1, 'blame exposes hunks');
  for I := 0 to High(LBlame.Hunks) do
  begin
    CheckEqual(40, Length(LBlame.Hunks[I].FinalCommitId), 'blame commit id 40 hex');
    CheckEqual('src.txt', LBlame.Hunks[I].OrigPath, 'blame orig path');
    Check(LBlame.Hunks[I].LinesInHunk >= 1, 'blame hunk lines >= 1');
  end;
  { 第二行被 c2 修改 → 至少存在一个起始行=2 的 hunk（或整体 hunk 覆盖） }
end;

procedure TestRevWalkAndParents;
var
  LMgr: IGitManager;
  LRepoDir: string;
  LRepo: IGitRepository;
  LExt: IGitRepositoryExt;
  LFile: string;
  LCommits: TGitCommitArray;
  LHead: IGitCommit;
begin
  LRepoDir := nextpas.core.fs.PathJoin([GTmpDir, 'revwalk']);
  nextpas.core.fs.MkdirAll(LRepoDir);

  LMgr := NewGitManager;
  Check(LMgr.Initialize, 'libgit2 manager should initialize for revwalk test');
  LRepo := LMgr.InitRepository(LRepoDir, False);
  CheckGitOk(LRepoDir, ['config', 'user.name', 'NextPas Tester'], 'git config user.name');
  CheckGitOk(LRepoDir, ['config', 'user.email', 'nextpas@example.invalid'], 'git config user.email');

  LFile := nextpas.core.fs.PathJoin([LRepoDir, 'r.txt']);
  nextpas.core.fs.WriteFile(LFile, BytesOfString('v1' + LineEnding));
  CheckGitOk(LRepoDir, ['add', 'r.txt'], 'git add r.txt');
  CheckGitOk(LRepoDir, ['commit', '-m', 'r1'], 'git commit r1');
  nextpas.core.fs.WriteFile(LFile, BytesOfString('v2' + LineEnding));
  CheckGitOk(LRepoDir, ['add', 'r.txt'], 'git add r.txt (v2)');
  CheckGitOk(LRepoDir, ['commit', '-m', 'r2'], 'git commit r2');
  nextpas.core.fs.WriteFile(LFile, BytesOfString('v3' + LineEnding));
  CheckGitOk(LRepoDir, ['add', 'r.txt'], 'git add r.txt (v3)');
  CheckGitOk(LRepoDir, ['commit', '-m', 'r3'], 'git commit r3');

  LExt := LRepo as IGitRepositoryExt;

  LCommits := LExt.RevWalk('', 0);
  Check(Length(LCommits) >= 3, 'RevWalk should list all commits');
  LHead := LRepo.HeadCommit;
  CheckEqual(LHead.OIDString, LCommits[0].OIDString, 'RevWalk should start at HEAD');
  CheckEqual(40, Length(LCommits[0].ParentOIDString(0)), 'Parent OID should be 40-byte hex');
  CheckEqual(LCommits[1].OIDString, LCommits[0].ParentOIDString(0), 'Second commit should be HEAD parent');
  CheckEqual('', LCommits[0].ParentOIDString(1), 'Parent index out of range should return empty');
  Check(LCommits[0].Time >= LCommits[1].Time, 'RevWalk should be time-ordered newest first');

  LCommits := LExt.RevWalk('HEAD', 2);
  CheckEqual(2, Length(LCommits), 'RevWalk with limit should cap results');
  LCommits := LExt.RevWalk('HEAD~2', 0);
  CheckEqual(1, Length(LCommits), 'RevWalk from older start should list remaining commits');
end;

procedure TestConfigEntriesReadsRepoConfig;
var
  LMgr: IGitManager;
  LRepoDir: string;
  LRepo: IGitRepository;
  LExt: IGitRepositoryExt;
  LEntries: TGitConfigEntryArray;
  I: Integer;
  LHasFsmonitor, LHasDiffTextconv, LHasAliasStatus, LHasUserName: Boolean;
begin
  LRepoDir := nextpas.core.fs.PathJoin([GTmpDir, 'config']);
  nextpas.core.fs.MkdirAll(LRepoDir);

  LMgr := NewGitManager;
  Check(LMgr.Initialize, 'libgit2 manager should initialize for config test');
  LRepo := LMgr.InitRepository(LRepoDir, False);
  Check(LRepo <> nil, 'InitRepository should return repository');
  LExt := LRepo as IGitRepositoryExt;

  { 写入本地配置：exec-risk 相关键 + 常规键 }
  CheckGitOk(LRepoDir, ['config', 'core.fsmonitor', '/tmp/pwn'], 'write core.fsmonitor');
  CheckGitOk(LRepoDir, ['config', 'diff.evil.textconv', '/tmp/pwn'], 'write diff.*.textconv');
  CheckGitOk(LRepoDir, ['config', 'alias.status', '!whoami'], 'write alias.status');
  CheckGitOk(LRepoDir, ['config', 'user.name', 't'], 'write user.name');

  LEntries := LExt.ConfigEntries;
  Check(Length(LEntries) >= 4, 'ConfigEntries should enumerate entries');
  LHasFsmonitor := False;
  LHasDiffTextconv := False;
  LHasAliasStatus := False;
  LHasUserName := False;
  for I := 0 to High(LEntries) do
  begin
    if LEntries[I].Name = 'core.fsmonitor' then
      LHasFsmonitor := LEntries[I].Value = '/tmp/pwn';
    if LEntries[I].Name = 'diff.evil.textconv' then
      LHasDiffTextconv := LEntries[I].Value = '/tmp/pwn';
    if LEntries[I].Name = 'alias.status' then
      LHasAliasStatus := LEntries[I].Value = '!whoami';
    if LEntries[I].Name = 'user.name' then
      LHasUserName := LEntries[I].Value = 't';
  end;
  Check(LHasFsmonitor, 'ConfigEntries should see core.fsmonitor value');
  Check(LHasDiffTextconv, 'ConfigEntries should see diff.*.textconv value');
  Check(LHasAliasStatus, 'ConfigEntries should see alias.status=!cmd value');
  Check(LHasUserName, 'ConfigEntries should see plain user.name value');
end;

procedure TestConfigEntriesResolvesInclude;
var
  LMgr: IGitManager;
  LRepoDir: string;
  LRepo: IGitRepository;
  LExt: IGitRepositoryExt;
  LEntries: TGitConfigEntryArray;
  I: Integer;
  LSeen: Boolean;
begin
  LRepoDir := nextpas.core.fs.PathJoin([GTmpDir, 'config-include']);
  nextpas.core.fs.MkdirAll(LRepoDir);

  LMgr := NewGitManager;
  Check(LMgr.Initialize, 'libgit2 manager should initialize for include test');
  LRepo := LMgr.InitRepository(LRepoDir, False);
  Check(LRepo <> nil, 'InitRepository should return repository');
  LExt := LRepo as IGitRepositoryExt;

  { include.path → 附加配置里的键应被 libgit2 解析进快照 }
  CheckGitOk(LRepoDir, ['config', 'include.path', 'extra'], 'write include.path');
  nextpas.core.fs.WriteFile(
    nextpas.core.fs.PathJoin([LRepoDir, '.git', 'extra']),
    BytesOfString('[core]'#10'fsmonitor = /tmp/pwn-inc'#10)
  );

  LEntries := LExt.ConfigEntries;
  LSeen := False;
  for I := 0 to High(LEntries) do
    if (LEntries[I].Name = 'core.fsmonitor') and
      (LEntries[I].Value = '/tmp/pwn-inc') then
      LSeen := True;
  Check(LSeen, 'ConfigEntries should resolve include.path content');
end;

procedure TestWorkflowOps;
var
  LMgr: IGitManager;
  LDir, LRemoteDir: string;
  LRepo: IGitRepository;
  LOps: IGitWorkflowOps;
  LRaised: Boolean;
  LOid, LHead: string;
  LTags, LList: TStringArray;

  function GitOut(const AArgs: array of string): string;
  begin
    Result := nextpas.core.text.conv.Trim(
      nextpas.core.process.MustCaptureIn('/usr/bin/git', AArgs, LDir));
  end;

  function GitOutIn(const ADir: string; const AArgs: array of string): string;
  begin
    Result := nextpas.core.text.conv.Trim(
      nextpas.core.process.MustCaptureIn('/usr/bin/git', AArgs, ADir));
  end;

begin
  LDir := nextpas.core.fs.PathJoin([GTmpDir, 'wf-repo']);
  nextpas.core.fs.MkdirAll(LDir);
  LMgr := NewGitManager;
  Check(LMgr.Initialize, 'libgit2 manager should initialize for workflow test');
  LRepo := LMgr.InitRepository(LDir, False);
  if LRepo.QueryInterface(IGitWorkflowOps, LOps) <> 0 then
  begin
    Check(False, 'libgit2 repository should support IGitWorkflowOps');
    Exit;
  end;
  CheckGitOk(LDir, ['config', 'user.name', 'NextPas Tester'], 'git config user.name');
  CheckGitOk(LDir, ['config', 'user.email', 'nextpas@example.invalid'], 'git config user.email');
  nextpas.core.fs.WriteFile(nextpas.core.fs.PathJoin([LDir, 'a.txt']), BytesOfString('v1' + #10));
  CheckGitOk(LDir, ['add', 'a.txt'], 'git add a.txt');
  CheckGitOk(LDir, ['commit', '-m', 'first'], 'git commit first');
  nextpas.core.fs.WriteFile(nextpas.core.fs.PathJoin([LDir, 'b.txt']), BytesOfString('b' + #10));
  CheckGitOk(LDir, ['add', 'b.txt'], 'git add b.txt');
  CheckGitOk(LDir, ['commit', '-m', 'second'], 'git commit second');
  LHead := GitOut(['rev-parse', 'HEAD']);

  CheckEqual(0, Length(LOps.ListTags), 'no tags initially');
  LOid := LOps.CreateBranch('feature', 'HEAD', False);
  CheckEqual(LHead, LOid, 'created branch points at HEAD');
  Check(Pos('feature', GitOut(['branch', '--list'])) > 0, 'git sees feature');
  LRaised := False;
  try LOps.CreateBranch('feature', 'HEAD', False); except on E: EGitError do LRaised := True; end;
  Check(LRaised, 'duplicate branch without force raises');
  LOid := LOps.CreateBranch('feature', 'HEAD~1', True);
  CheckEqual(GitOut(['rev-parse', 'HEAD~1']), LOid, 'force recreates at new tip');
  LOps.RenameBranch('feature', 'renamed', False);
  CheckEqual(LOid, GitOut(['rev-parse', 'renamed']), 'git resolves renamed ref');
  LOps.CreateBranch('other', 'HEAD', False);
  LRaised := False;
  try LOps.RenameBranch('renamed', 'other', False); except on E: EGitError do LRaised := True; end;
  Check(LRaised, 'rename onto existing without force raises');
  LOps.RenameBranch('renamed', 'other', True);
  LOps.DeleteBranch('other');
  LRaised := False;
  try LOps.DeleteBranch('no-such-branch'); except on E: EGitError do LRaised := True; end;
  Check(LRaised, 'delete missing branch raises');
  LRaised := False;
  try LOps.DeleteBranch(LRepo.CurrentBranch); except on E: EGitError do LRaised := True; end;
  Check(LRaised, 'delete current branch raises');

  LOid := LOps.CreateLightweightTag('v1', 'HEAD', False);
  CheckEqual(LHead, LOid, 'lightweight tag points at HEAD');
  LTags := LOps.ListTags;
  Check(ContainsPath(LTags, 'v1'), 'ListTags contains v1');
  CheckEqual(LOid, GitOut(['rev-parse', 'v1']), 'git resolves v1');
  LRaised := False;
  try LOps.CreateLightweightTag('v1', 'HEAD', False); except on E: EGitError do LRaised := True; end;
  Check(LRaised, 'duplicate tag without force raises');
  LOps.CreateAnnotatedTag('v2', 'HEAD', 'release two', 'NextPas Tester', 'nextpas@example.invalid', False);
  CheckEqual('tag', GitOut(['cat-file', '-t', 'v2']), 'annotated tag object type');
  Check(ContainsPath(LOps.ListTags, 'v2'), 'ListTags contains v2');
  LRaised := False;
  try LOps.CreateAnnotatedTag('v3', 'HEAD', '', 'A', 'a@b.c', False); except on E: EGitError do LRaised := True; end;
  Check(LRaised, 'annotated tag without message raises');
  LOps.DeleteTag('v2');
  Check(not ContainsPath(LOps.ListTags, 'v2'), 'v2 gone after delete');
  LRaised := False;
  try LOps.DeleteTag('no-such-tag'); except on E: EGitError do LRaised := True; end;
  Check(LRaised, 'delete missing tag raises');

  CheckEqual(0, LOps.StashCount, 'no stashes initially');
  nextpas.core.fs.WriteFile(nextpas.core.fs.PathJoin([LDir, 'a.txt']), BytesOfString('modified' + #10));
  LOid := LOps.StashPush('wip work');
  CheckEqual(40, Length(LOid), 'stash push returns 40-hex');
  CheckEqual(1, LOps.StashCount, 'one stash after push');
  LList := LOps.StashList;
  CheckEqual(1, Length(LList), 'stash list has one entry');
  Check(Pos('wip work', LList[0]) > 0, 'stash entry carries message');
  Check(Pos('wip work', GitOut(['stash', 'list'])) > 0, 'git sees the stash');
  LOps.StashApply(0);
  LOps.StashDrop(0);
  CheckEqual(0, LOps.StashCount, 'empty after drop');
  LOps.StashPush('second stash');
  LOps.StashPop(0);
  CheckEqual(0, LOps.StashCount, 'empty after pop');
  LRaised := False;
  try LOps.StashApply(7); except on E: EGitError do LRaised := True; end;
  Check(LRaised, 'apply out-of-range index raises');
  LOps.StashPush('x');
  LOps.StashClear;
  CheckEqual(0, LOps.StashCount, 'empty after clear');
  CheckGitOk(LDir, ['checkout', '--', 'a.txt'], 'git checkout restore a.txt');

  nextpas.core.fs.WriteFile(nextpas.core.fs.PathJoin([LDir, 'c.txt']), BytesOfString('c' + #10));
  CheckGitOk(LDir, ['add', 'c.txt'], 'git add c.txt');
  CheckGitOk(LDir, ['commit', '-m', 'third'], 'git commit third');
  LOps.ResetHard('HEAD~1');
  CheckEqual(LHead, GitOut(['rev-parse', 'HEAD']), 'reset moves HEAD back');
  Check(not nextpas.core.fs.FileExists(nextpas.core.fs.PathJoin([LDir, 'c.txt'])), 'reset removes newer file');
  LRaised := False;
  try LOps.ResetHard(''); except on E: EGitError do LRaised := True; end;
  Check(LRaised, 'reset empty target raises');

  LRemoteDir := nextpas.core.fs.PathJoin([GTmpDir, 'wf-remote.git']);
  LMgr.InitRepository(LRemoteDir, True);
  CheckGitOk(LDir, ['remote', 'add', 'origin', LRemoteDir], 'git remote add origin');
  Check(LOps.PushBranch('origin', LRepo.CurrentBranch), 'first push moves remote');
  CheckEqual(GitOut(['rev-parse', LRepo.CurrentBranch]),
    GitOutIn(LRemoteDir, ['rev-parse', LRepo.CurrentBranch]), 'remote tip matches after push');
  Check(not LOps.PushBranch('origin', LRepo.CurrentBranch), 'second push is no-op');
  LRaised := False;
  try LOps.PushBranch('no-such-remote', 'main'); except on E: EGitError do LRaised := True; end;
  Check(LRaised, 'push unknown remote raises');
  LRaised := False;
  try LOps.PushBranch('origin', ''); except on E: EGitError do LRaised := True; end;
  Check(LRaised, 'push empty branch raises');

  LHead := GitOut(['rev-parse', 'HEAD']);
  CheckEqual('', LOps.NotesForTarget(LHead), 'no note initially');
  CheckEqual(0, Length(LOps.NotesList), 'notes list empty');
  LOps.NotesAdd(LHead, 'looks good');
  CheckEqual('looks good', nextpas.core.text.conv.Trim(LOps.NotesForTarget(LHead)), 'note reads back');
  Check(ContainsPath(LOps.NotesList, LHead), 'notes list carries target');
  Check(Pos(LHead, GitOut(['notes', 'list'])) > 0, 'git sees the note');
  Check(LOps.NotesRemove(LHead), 'remove reports True');
  CheckEqual('', LOps.NotesForTarget(LHead), 'note gone after remove');
  Check(not LOps.NotesRemove(LHead), 'second remove reports False');
  LRaised := False;
  try LOps.NotesAdd(LHead, '   '); except on E: EGitError do LRaised := True; end;
  Check(LRaised, 'empty note raises');
  LRaised := False;
  try LOps.NotesForTarget('not-hex'); except on E: EGitError do LRaised := True; end;
  Check(LRaised, 'non-hex target raises');
end;

procedure TestAddWorktreeHonorsRef;
var
  LMgr: IGitManager;
  LMainDir, LWtDir: string;
  LRepo, LWtRepo: IGitRepository;
  LWtExt: IGitWorktreeExt;
  LWt: IGitWorktree;
  LRaised: Boolean;
begin
  LMainDir := nextpas.core.fs.PathJoin([GTmpDir, 'wt-ref-main']);
  LWtDir := nextpas.core.fs.PathJoin([GTmpDir, 'wt-ref-linked']);
  nextpas.core.fs.MkdirAll(LMainDir);
  LMgr := NewGitManager;
  Check(LMgr.Initialize, 'libgit2 manager should initialize for worktree ref test');
  LRepo := LMgr.InitRepository(LMainDir, False);
  CheckGitOk(LMainDir, ['config', 'user.name', 'NextPas Tester'], 'git config user.name');
  CheckGitOk(LMainDir, ['config', 'user.email', 'nextpas@example.invalid'], 'git config user.email');
  nextpas.core.fs.WriteFile(nextpas.core.fs.PathJoin([LMainDir, 'seed.txt']), BytesOfString('seed'));
  CheckGitOk(LMainDir, ['add', 'seed.txt'], 'git add seed');
  CheckGitOk(LMainDir, ['commit', '-m', 'seed'], 'git commit seed');
  CheckGitOk(LMainDir, ['branch', 'feature'], 'git branch feature');
  if LRepo.QueryInterface(IGitWorktreeExt, LWtExt) <> 0 then
  begin
    Check(False, 'IGitRepository should support IGitWorktreeExt');
    Exit;
  end;
  LWt := LWtExt.AddWorktree('ref-wt', LWtDir, 'feature', False);
  Check(LWt <> nil, 'AddWorktree with branch ref should return a worktree');
  LWtRepo := LMgr.OpenRepository(LWtDir);
  CheckEqual('feature', LWtRepo.CurrentBranch, 'linked worktree checks out the requested branch');
  LWt := nil;
  LWtRepo := nil;
  nextpas.core.fs.RemoveAll(LWtDir);
  CheckGitOk(LMainDir, ['worktree', 'prune'], 'git worktree prune');
  LRaised := False;
  try
    LWtExt.AddWorktree('det-wt', nextpas.core.fs.PathJoin([GTmpDir, 'wt-det']), '', True);
  except
    on E: EGitError do LRaised := True;
  end;
  Check(LRaised, 'detached worktree raises explicit EGitError on libgit2 backend');
  LRaised := False;
  try
    LWtExt.AddWorktree('tag-wt', nextpas.core.fs.PathJoin([GTmpDir, 'wt-tag']), 'refs/tags/v1', False);
  except
    on E: EGitError do LRaised := True;
  end;
  Check(LRaised, 'non-branch ref raises explicit EGitError on libgit2 backend');
end;

begin
  SetupTmpDir;
  try
    T := TTestSuite.Create('nextpas.core.git');
    T.Test('libgit2 loader reports missing override', @TestLibGit2LoaderReportsMissingOverride);
    T.Test('libgit2 loader reports symbol failure', @TestLibGit2LoaderReportsSymbolResolutionFailure);
    T.Test('libgit2 loader reports loaded path', @TestLibGit2LoaderReportsLoadedPath);
    T.Test('Facade re-exports base constants', @TestFacadeReexportsBaseConstants);
    T.Test('Unsupported callbacks are explicit', @TestUnsupportedCallbacksAreExplicit);
    T.Test('DiscoverRepository fallback', @TestDiscoverRepositoryFallsBackToDotGitDirectory);
    T.Test('DiscoverRepository supports gitfile worktree', @TestDiscoverRepositorySupportsGitFileWorktree);
    T.Test('InitRepository discarded return value', @TestInitRepositorySupportsDiscardedReturnValue);
    T.Test('Initialize is idempotent', @TestInitializeIsIdempotent);
    T.Test('Status sees untracked file', @TestStatusSeesUntrackedFileAfterInit);
    T.Test('Explicit Finalize waits for live repository', @TestExplicitFinalizeWaitsForLiveRepository);
    T.Test('HeadCommit metadata', @TestHeadCommitLoadsMetadataAndSurvivesRepositoryRelease);
    T.Test('AddWorktree creates linked worktree', @TestAddWorktreeCreatesLinkedWorktree);
    T.Test('CommitOnHead creates commit', @TestCommitOnHeadCreatesCommit);
    T.Test('Diff reports hunks and stats', @TestDiffReportsHunksAndStats);
    T.Test('DiffEx honors pathspec and unified', @TestDiffExOptions);
    T.Test('Blame file', @TestBlameFile);
    T.Test('RevWalk and parent OIDs', @TestRevWalkAndParents);
    T.Test('ConfigEntries reads repo config (k42)', @TestConfigEntriesReadsRepoConfig);
    T.Test('ConfigEntries resolves include (k42)', @TestConfigEntriesResolvesInclude);
    T.Test('Workflow ops branch/tag/stash/notes/reset/push', @TestWorkflowOps);
    T.Test('AddWorktree honors ref and rejects detach', @TestAddWorktreeHonorsRef);
  if not T.Run then Halt(1);
  finally
    CleanupTmpDir;
  end;
end.
