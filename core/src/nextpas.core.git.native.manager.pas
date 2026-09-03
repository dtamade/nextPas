unit nextpas.core.git.native.manager;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.git.intf;

type
  TNativeGitManager = class(TInterfacedObject, IGitManager)
  private
    FInitialized: Boolean;
    FVerifySSL: Boolean;
    function ResolveGitDir(const APath: string; out AGitDir, AWorkTree: string): Boolean;
  public
    constructor Create;
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
    procedure SetCredentialAcquireHandler(AHandler: TCredentialAcquireEvent);
    procedure SetCertificateCheckHandler(AHandler: TCertificateCheckEvent);
    function Initialized: Boolean; inline;
    function VerifySSL: Boolean; inline;
  end;

implementation

uses
  nextpas.core.fs,
  nextpas.core.text.conv,
  nextpas.core.git.native.base,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.index,
  nextpas.core.git.native.repository;

constructor TNativeGitManager.Create;
begin
  inherited Create;
  FInitialized := False;
  FVerifySSL := True;
end;

function TNativeGitManager.ResolveGitDir(const APath: string; out AGitDir, AWorkTree: string): Boolean;
var
  Clean: string;
begin
  Result := False;
  AGitDir := '';
  AWorkTree := '';
  Clean := PathClean(APath);
  if GitTryDiscoverGitDir(Clean, AGitDir) then
  begin
    if FileExists(PathJoin2(AGitDir, 'commondir')) then
    begin
      // worktree gitdir: gitdir file points to <wt>/.git
      try
        AWorkTree := PathDir(Trim(ReadFileText(PathJoin2(AGitDir, 'gitdir'))));
      except
        AWorkTree := '';
      end;
      if AWorkTree = '' then
        AWorkTree := PathDir(AGitDir);
      Result := True;
      Exit;
    end;
    if PathBase(AGitDir) = '.git' then
      AWorkTree := PathDir(AGitDir)
    else
    begin
      if IsGitDirShape(Clean) and (PathClean(Clean) = PathClean(AGitDir)) then
        AWorkTree := ''
      else if DirectoryExists(PathJoin2(AGitDir, 'objects')) then
      begin
        // bare: worktree empty, gitdir is repo root
        AWorkTree := '';
      end
      else
        AWorkTree := PathDir(AGitDir);
      // For worktree discovered via parent walk, infer worktree as dir containing .git
      // GitTryDiscover loses original start; re-derive by checking if AGitDir is inside APath's ancestor
      if (AWorkTree = '') and (PathBase(AGitDir) <> '.git') then
      begin
        // keep bare
      end
      else if AWorkTree = '' then
      begin
        // if gitdir ends with /.git, worktree is its parent
        if PathBase(AGitDir) = '.git' then
          AWorkTree := PathDir(AGitDir);
      end;
    end;
    // Correct worktree for non-bare: if AGitDir = <wt>/.git, worktree = <wt>
    // For bare, leave empty
    if (AWorkTree <> '') and IsGitDirShape(AWorkTree) then
      AWorkTree := '';
    // When APath itself is a worktree dir, GitTryDiscover returns <wt>/.git, so PathDir gives <wt>
    Result := True;
  end;
end;

function TNativeGitManager.Initialize: Boolean;
begin
  FInitialized := True;
  Result := True;
end;

procedure TNativeGitManager.Finalize;
begin
  FInitialized := False;
end;

function TNativeGitManager.OpenRepository(const APath: string): IGitRepository;
var
  GitDir, WorkTree: string;
begin
  if not ResolveGitDir(APath, GitDir, WorkTree) then
    raise EGitError.CreateFmt('not a git repository (or any parent): %s', [APath]);
  Result := TNativeRepositoryAdapter.Create(GitDir, WorkTree);
end;

function TNativeGitManager.CloneRepository(const AURL, ALocalPath: string): IGitRepository;
begin
  raise EGitError.Create('not implemented for native backend: CloneRepository');
  Result := nil;
end;

function TNativeGitManager.InitRepository(const APath: string; ABare: Boolean): IGitRepository;
var
  GitDir, WorkTree: string;
  ConfigText, HeadText: string;
  EmptyIdx: TGitIndexEntryArray;
begin
  if Trim(APath) = '' then
    raise EGitError.Create('init: path empty');
  if ABare then
    GitDir := PathClean(APath)
  else
    GitDir := PathJoin2(PathClean(APath), '.git');
  if IsGitDirShape(GitDir) then
    raise EGitError.CreateFmt('init: repository already exists at %s', [GitDir]);
  MkdirAll(GitDir, PermDirDefault);
  MkdirAll(PathJoin([GitDir, 'objects', 'pack']), PermDirDefault);
  MkdirAll(PathJoin([GitDir, 'objects', 'info']), PermDirDefault);
  MkdirAll(PathJoin([GitDir, 'refs', 'heads']), PermDirDefault);
  MkdirAll(PathJoin([GitDir, 'refs', 'tags']), PermDirDefault);
  MkdirAll(PathJoin([GitDir, 'info']), PermDirDefault);
  HeadText := 'ref: refs/heads/main' + #10;
  WriteFileText(PathJoin2(GitDir, 'HEAD'), HeadText);
  if ABare then
    ConfigText :=
      '[core]'#10 +
      #9'repositoryformatversion = 0'#10 +
      #9'filemode = true'#10 +
      #9'bare = true'#10
  else
    ConfigText :=
      '[core]'#10 +
      #9'repositoryformatversion = 0'#10 +
      #9'filemode = true'#10 +
      #9'bare = false'#10 +
      #9'logallrefupdates = true'#10;
  WriteFileText(PathJoin2(GitDir, 'config'), ConfigText);
  WriteFileText(PathJoin2(GitDir, 'description'), 'Unnamed repository' + #10);
  WriteFileText(PathJoin([GitDir, 'info', 'exclude']),
    '# git ls-files --others --exclude-from=... (via nextpas native)' + #10 +
    '# lines starting with # are ignored' + #10);
  if ABare then
  begin
    WorkTree := '';
  end
  else
  begin
    WorkTree := PathClean(APath);
    MkdirAll(WorkTree, PermDirDefault);
    SetLength(EmptyIdx, 0);
    GitWriteIndex(GitDir, EmptyIdx, 2);
  end;
  Result := TNativeRepositoryAdapter.Create(GitDir, WorkTree);
end;

function TNativeGitManager.IsRepository(const APath: string): Boolean;
var
  D: string;
begin
  Result := GitTryDiscoverGitDir(PathClean(APath), D);
end;

function TNativeGitManager.DiscoverRepository(const AStartPath: string): string;
var
  GitDir, WorkTree: string;
begin
  if ResolveGitDir(AStartPath, GitDir, WorkTree) then
  begin
    if WorkTree <> '' then
      Result := WorkTree
    else
      Result := GitDir;
  end
  else
    Result := '';
end;

function TNativeGitManager.GetGlobalConfig(const AKey: string): string;
begin
  raise EGitError.Create('not implemented for native backend: GetGlobalConfig');
  Result := '';
end;

function TNativeGitManager.SetGlobalConfig(const AKey, AValue: string): Boolean;
begin
  raise EGitError.Create('not implemented for native backend: SetGlobalConfig');
  Result := False;
end;

function TNativeGitManager.Version: string;
begin
  Result := 'native-0.1.0';
end;

procedure TNativeGitManager.SetVerifySSL(AEnabled: Boolean);
begin
  FVerifySSL := AEnabled;
end;

procedure TNativeGitManager.SetCredentialAcquireHandler(AHandler: TCredentialAcquireEvent);
begin
  if Assigned(AHandler) then
    raise EGitError.Create('not implemented for native backend: SetCredentialAcquireHandler');
end;

procedure TNativeGitManager.SetCertificateCheckHandler(AHandler: TCertificateCheckEvent);
begin
  if Assigned(AHandler) then
    raise EGitError.Create('not implemented for native backend: SetCertificateCheckHandler');
end;

function TNativeGitManager.Initialized: Boolean; inline;
begin
  Result := FInitialized;
end;

function TNativeGitManager.VerifySSL: Boolean; inline;
begin
  Result := FVerifySSL;
end;

end.
