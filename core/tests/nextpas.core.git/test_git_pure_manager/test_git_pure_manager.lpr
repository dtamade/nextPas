program test_git_pure_manager;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.fs,
  nextpas.core.process,
  nextpas.core.git.factory,
  nextpas.core.git.base,
  nextpas.core.git.intf,
  nextpas.core.git.native.base;

var
  Suite: TTestSuite;

function BytesOfString(const AText: string): TBytes;
begin
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(AText[1], Result[0], Length(AText));
end;

function MkTempDir(const APrefix: string): string;
begin
  Result := PathJoin([GetTempDir, APrefix + '_' + IntToStr(GetProcessID) + '_' + IntToStr(Random(1000000))]);
  RemoveAll(Result);
  MkdirAll(Result);
end;

function ContainsStr(const AItems: TStringArray; const AValue: string): Boolean;
var
  S: string;
begin
  Result := False;
  for S in AItems do
    if S = AValue then
      Exit(True);
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
  LMgr: IGitManager;
begin
  LMgr := NewGitManager(gbAuto);
  Check(LMgr <> nil, 'NewGitManager(gbAuto) should not be nil');
  Check(LMgr.Initialize, 'gbAuto Initialize should succeed');
  Check(LMgr.Initialized, 'gbAuto should report Initialized');
  LMgr.Finalize;
  CheckFalse(LMgr.Initialized, 'gbAuto Finalize should clear Initialized');
end;

begin
  Randomize;
  Suite := TTestSuite.Create('pure_manager');
  Suite.Test('TestInitAndIsRepository', @TestInitAndIsRepository);
  Suite.Test('TestStatusEmpty', @TestStatusEmpty);
  Suite.Test('TestStatusWithFile', @TestStatusWithFile);
  Suite.Test('TestHeadAndLookup', @TestHeadAndLookup);
  Suite.Test('TestFactoryGbAutoCompat', @TestFactoryGbAutoCompat);

  if not Suite.Run then
    Halt(1);
end.
