unit nextpas.core.git.native.staging;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.git.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.index,
  nextpas.core.git.native.cachetree,
  nextpas.core.git.native.status,
  nextpas.core.git.native.ignore,
  nextpas.core.git.native.worktree,
  nextpas.core.git.native.lsfiles,
  nextpas.core.git.native.clean;

type
  TGitIndexEntry = nextpas.core.git.native.index.TGitIndexEntry;
  TGitIndexFile = nextpas.core.git.native.index.TGitIndexFile;
  TGitIndexEntryArray = nextpas.core.git.native.index.TGitIndexEntryArray;
  TGitCacheTree = nextpas.core.git.native.cachetree.TGitCacheTree;
  // single source via base — staging re-exports base vocab directly (native also aliases base, eliminates dual track)
  TGitStatusCode = nextpas.core.git.base.TGitStatusCode;
  TGitNativeStatusEntry =
    nextpas.core.git.native.status.TGitNativeStatusEntry;
  TGitNativeStatusArray =
    nextpas.core.git.native.status.TGitNativeStatusArray;
  TGitIgnoreMatcher = nextpas.core.git.native.ignore.TGitIgnoreMatcher;
  TGitWorktree = nextpas.core.git.native.worktree.TGitWorktree;
  TGitWorktreeArray = nextpas.core.git.native.worktree.TGitWorktreeArray;
  TGitLsFilesOptions = nextpas.core.git.native.lsfiles.TGitLsFilesOptions;

const
  // single source via base (inline zero-copy const alias, no alloc), keeps native.status qualified consumers valid via base single source
  gscUnmodified = nextpas.core.git.base.gscUnmodified;
  gscAdded = nextpas.core.git.base.gscAdded;
  gscModified = nextpas.core.git.base.gscModified;
  gscDeleted = nextpas.core.git.base.gscDeleted;
  gscTypeChanged = nextpas.core.git.base.gscTypeChanged;
  gscUnmerged = nextpas.core.git.base.gscUnmerged;
  gscUntracked = nextpas.core.git.base.gscUntracked;
  gscRenamed = nextpas.core.git.base.gscRenamed;
  gscCopied = nextpas.core.git.base.gscCopied;

function GitParseIndex(const AData: TBytes): TGitIndexFile; inline;
function GitReadIndex(const AGitDir: string): TGitIndexFile; inline;
procedure GitSortIndexEntries(var AEntries: TGitIndexEntryArray); inline;
function GitSerializeIndex(
  const AEntries: array of TGitIndexEntry;
  AVersion: Cardinal): TBytes; inline;
procedure GitWriteIndex(const AGitDir: string;
  var AEntries: TGitIndexEntryArray; AVersion: Cardinal); inline;

function GitParseCacheTree(const AData: TBytes): TGitCacheTree; inline;
function GitSerializeCacheTree(const ATree: TGitCacheTree): TBytes; inline;
function GitBuildIndexCacheTree(
  const AEntries: array of TGitIndexEntry): TGitCacheTree; inline;

function GitSerializeIndexFile(const AFile: TGitIndexFile): TBytes; inline;
procedure GitWriteIndexFile(const AGitDir: string;
  var AFile: TGitIndexFile); inline;

function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean): TGitNativeStatusArray; overload; inline;
function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean; AFindRenames: Boolean;
  ARenameThreshold: Integer): TGitNativeStatusArray; overload; inline;
function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean; AFindRenames: Boolean;
  ARenameThreshold: Integer; AFindCopies: Boolean;
  ACopyThreshold: Integer): TGitNativeStatusArray; overload; inline;

function GitCommonDir(const AGitDir: string): string; inline;
function GitIsWorktree(const AGitDir: string): Boolean; inline;
function GitWorktreeList(const AGitDir: string): TGitWorktreeArray; inline;
function GitWorktreeCount(const AGitDir: string): Integer; inline;
function GitWorktreeAdd(const AGitDir, AWorkTreePath, ABranchName: string): TGitWorktree; overload; inline;
function GitWorktreeAddDetached(const AGitDir, AWorkTreePath: string; const AOid: TGitOid): TGitWorktree; inline;
procedure GitWorktreeRemove(const AGitDir, AWorkTreePath: string); overload; inline;
procedure GitWorktreeRemove(const AGitDir, AWorkTreePath: string; AForce: Boolean); overload; inline;

function DefaultGitLsFilesOptions: TGitLsFilesOptions; inline;
function GitLsFiles(const AGitDir: string): TStringArray; overload; inline;
function GitLsFiles(const AGitDir: string; const AOptions: TGitLsFilesOptions): TStringArray; overload; inline;
function GitLsFilesDetailed(const AGitDir: string): TGitIndexEntryArray; inline;
function GitLsFilesStage(const AGitDir: string): TStringArray; inline;

function GitClean(const AGitDir, AWorkTree: string): TStringArray; overload; inline;
function GitClean(const AGitDir, AWorkTree: string; ARemoveDirs: Boolean): TStringArray; overload; inline;
function GitClean(const AGitDir, AWorkTree: string; ARemoveDirs, ARemoveIgnored: Boolean): TStringArray; overload; inline;
function GitClean(const AGitDir, AWorkTree: string; ARemoveDirs, ARemoveIgnored, ADryRun: Boolean): TStringArray; overload; inline;

implementation

function GitParseIndex(const AData: TBytes): TGitIndexFile; inline;
begin
  Result := nextpas.core.git.native.index.GitParseIndex(AData);
end;

function GitReadIndex(const AGitDir: string): TGitIndexFile; inline;
begin
  Result := nextpas.core.git.native.index.GitReadIndex(AGitDir);
end;

procedure GitSortIndexEntries(var AEntries: TGitIndexEntryArray); inline;
begin
  nextpas.core.git.native.index.GitSortIndexEntries(AEntries);
end;

function GitSerializeIndex(
  const AEntries: array of TGitIndexEntry;
  AVersion: Cardinal): TBytes; inline;
begin
  Result := nextpas.core.git.native.index.GitSerializeIndex(
    AEntries, AVersion);
end;

procedure GitWriteIndex(const AGitDir: string;
  var AEntries: TGitIndexEntryArray; AVersion: Cardinal); inline;
begin
  nextpas.core.git.native.index.GitWriteIndex(AGitDir, AEntries, AVersion);
end;

function GitParseCacheTree(const AData: TBytes): TGitCacheTree; inline;
begin
  Result := nextpas.core.git.native.cachetree.GitParseCacheTree(AData);
end;

function GitSerializeCacheTree(const ATree: TGitCacheTree): TBytes; inline;
begin
  Result := nextpas.core.git.native.cachetree.GitSerializeCacheTree(ATree);
end;

function GitBuildIndexCacheTree(
  const AEntries: array of TGitIndexEntry): TGitCacheTree; inline;
begin
  Result := nextpas.core.git.native.index.GitBuildIndexCacheTree(AEntries);
end;

function GitSerializeIndexFile(const AFile: TGitIndexFile): TBytes; inline;
begin
  Result := nextpas.core.git.native.index.GitSerializeIndexFile(AFile);
end;

procedure GitWriteIndexFile(const AGitDir: string;
  var AFile: TGitIndexFile); inline;
begin
  nextpas.core.git.native.index.GitWriteIndexFile(AGitDir, AFile);
end;

function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean): TGitNativeStatusArray; inline;
begin
  Result := nextpas.core.git.native.status.GitCollectStatus(
    AGitDir, AWorkTree, AIncludeUntracked);
end;

function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean; AFindRenames: Boolean;
  ARenameThreshold: Integer): TGitNativeStatusArray; inline;
begin
  Result := nextpas.core.git.native.status.GitCollectStatus(
    AGitDir, AWorkTree, AIncludeUntracked, AFindRenames, ARenameThreshold);
end;

function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean; AFindRenames: Boolean;
  ARenameThreshold: Integer; AFindCopies: Boolean;
  ACopyThreshold: Integer): TGitNativeStatusArray; inline;
begin
  Result := nextpas.core.git.native.status.GitCollectStatus(
    AGitDir, AWorkTree, AIncludeUntracked, AFindRenames, ARenameThreshold,
    AFindCopies, ACopyThreshold);
end;

function GitCommonDir(const AGitDir: string): string; inline;
begin
  Result := nextpas.core.git.native.worktree.GitCommonDir(AGitDir);
end;

function GitIsWorktree(const AGitDir: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.worktree.GitIsWorktree(AGitDir);
end;

function GitWorktreeList(const AGitDir: string): TGitWorktreeArray; inline;
begin
  Result := nextpas.core.git.native.worktree.GitWorktreeList(AGitDir);
end;

function GitWorktreeCount(const AGitDir: string): Integer; inline;
begin
  Result := nextpas.core.git.native.worktree.GitWorktreeCount(AGitDir);
end;

function GitWorktreeAdd(const AGitDir, AWorkTreePath, ABranchName: string): TGitWorktree; inline;
begin
  Result := nextpas.core.git.native.worktree.GitWorktreeAdd(AGitDir, AWorkTreePath, ABranchName);
end;

function GitWorktreeAddDetached(const AGitDir, AWorkTreePath: string; const AOid: TGitOid): TGitWorktree; inline;
begin
  Result := nextpas.core.git.native.worktree.GitWorktreeAddDetached(AGitDir, AWorkTreePath, AOid);
end;

procedure GitWorktreeRemove(const AGitDir, AWorkTreePath: string); inline;
begin
  nextpas.core.git.native.worktree.GitWorktreeRemove(AGitDir, AWorkTreePath);
end;

procedure GitWorktreeRemove(const AGitDir, AWorkTreePath: string; AForce: Boolean); inline;
begin
  nextpas.core.git.native.worktree.GitWorktreeRemove(AGitDir, AWorkTreePath, AForce);
end;

function DefaultGitLsFilesOptions: TGitLsFilesOptions; inline;
begin
  Result := nextpas.core.git.native.lsfiles.DefaultGitLsFilesOptions;
end;

function GitLsFiles(const AGitDir: string): TStringArray; inline;
begin
  Result := nextpas.core.git.native.lsfiles.GitLsFiles(AGitDir);
end;

function GitLsFiles(const AGitDir: string; const AOptions: TGitLsFilesOptions): TStringArray; inline;
begin
  Result := nextpas.core.git.native.lsfiles.GitLsFiles(AGitDir, AOptions);
end;

function GitLsFilesDetailed(const AGitDir: string): TGitIndexEntryArray; inline;
begin
  Result := nextpas.core.git.native.lsfiles.GitLsFilesDetailed(AGitDir);
end;

function GitLsFilesStage(const AGitDir: string): TStringArray; inline;
begin
  Result := nextpas.core.git.native.lsfiles.GitLsFilesStage(AGitDir);
end;

function GitClean(const AGitDir, AWorkTree: string): TStringArray; inline;
begin
  Result := nextpas.core.git.native.clean.GitClean(AGitDir, AWorkTree);
end;

function GitClean(const AGitDir, AWorkTree: string; ARemoveDirs: Boolean): TStringArray; inline;
begin
  Result := nextpas.core.git.native.clean.GitClean(AGitDir, AWorkTree, ARemoveDirs);
end;

function GitClean(const AGitDir, AWorkTree: string; ARemoveDirs, ARemoveIgnored: Boolean): TStringArray; inline;
begin
  Result := nextpas.core.git.native.clean.GitClean(AGitDir, AWorkTree, ARemoveDirs, ARemoveIgnored);
end;

function GitClean(const AGitDir, AWorkTree: string; ARemoveDirs, ARemoveIgnored, ADryRun: Boolean): TStringArray; inline;
begin
  Result := nextpas.core.git.native.clean.GitClean(AGitDir, AWorkTree, ARemoveDirs, ARemoveIgnored, ADryRun);
end;

end.
