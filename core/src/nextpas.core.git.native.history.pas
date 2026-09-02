unit nextpas.core.git.native.history;

{$I nextpas.core.settings.inc}

{**
 * @desc History umbrella facade — aggregates 3 invariant shards
 *   traversal (revwalk/commitgraph/reflog/revparse) + query
 *   (log/describe/diff/blame/mergebase/show) + ops
 *   (shortlog/catfile/cherrypick/revert). Each shard <250 lines, umbrella
 *   <200 lines, total <600 pre-split (was 14 units / 464 lines overweight).
 *   Split domains: revwalk/commitgraph vs log/describe vs diff/blame vs
 *   mergebase/show vs shortlog/catfile/cherrypick/revert — grouped as
 *   traversal / query / ops; direct consumers may use shards for finer fan-in.
 * Perf: all forwards `inline`; zero-copy via bytes.ops single source
 *   (TGitOid 20B Move, TByteSpan, PByte+Len) + owner single-parse/cached.
 * Stability: ownership in owners (TCommitGraph/TPackFile IMappedFile refcounted,
 *   revwalk queues try..finally, cherrypick/revert checkout try..finally index);
 *   umbrella zero alloc/zero leak.
 *}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.history.traversal,
  nextpas.core.git.native.history.query,
  nextpas.core.git.native.history.ops;

type
  TNativeRepository = nextpas.core.git.native.history.traversal.TNativeRepository;
  TGitOidArray = nextpas.core.git.native.history.traversal.TGitOidArray;
  TGitOidSet = nextpas.core.git.native.history.traversal.TGitOidSet;
  TGitRevWalker = nextpas.core.git.native.history.traversal.TGitRevWalker;
  TGitRevEntry = nextpas.core.git.native.history.traversal.TGitRevEntry;
  TGitRevEntryArray = nextpas.core.git.native.history.traversal.TGitRevEntryArray;
  TGitRevOptions = nextpas.core.git.native.history.traversal.TGitRevOptions;
  TCommitGraph = nextpas.core.git.native.history.traversal.TCommitGraph;
  TCommitGraphEntry = nextpas.core.git.native.history.traversal.TCommitGraphEntry;
  TGitReflogEntry = nextpas.core.git.native.history.traversal.TGitReflogEntry;
  TGitReflog = nextpas.core.git.native.history.traversal.TGitReflog;
  TGitLogEntry = nextpas.core.git.native.history.query.TGitLogEntry;
  TGitLogArray = nextpas.core.git.native.history.query.TGitLogArray;
  TGitDiffStatus = nextpas.core.git.native.history.query.TGitDiffStatus;
  TGitDiffEntry = nextpas.core.git.native.history.query.TGitDiffEntry;
  TGitDiffArray = nextpas.core.git.native.history.query.TGitDiffArray;
  TGitBlameEntry = nextpas.core.git.native.history.query.TGitBlameEntry;
  TGitBlameArray = nextpas.core.git.native.history.query.TGitBlameArray;
  TGitShow = nextpas.core.git.native.history.query.TGitShow;
  TGitShortlogEntry = nextpas.core.git.native.history.ops.TGitShortlogEntry;
  TGitShortlogArray = nextpas.core.git.native.history.ops.TGitShortlogArray;
  TGitCatFile = nextpas.core.git.native.history.ops.TGitCatFile;
  TGitOid = nextpas.core.git.native.base.TGitOid;

const
  gdsAdded = nextpas.core.git.native.history.query.gdsAdded;
  gdsModified = nextpas.core.git.native.history.query.gdsModified;
  gdsDeleted = nextpas.core.git.native.history.query.gdsDeleted;
  gdsTypeChanged = nextpas.core.git.native.history.query.gdsTypeChanged;

function DefaultGitRevOptions: TGitRevOptions; inline;

function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray; overload; inline;
function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray; overload; inline;
function GitCollectCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray; inline;

function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray; overload; inline;
function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray; overload; inline;
function GitTopoOrderCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray; inline;

function GitTryLoadCommitGraph(const AGitDir: string; out AGraph: TCommitGraph): Boolean; inline;
function GitCommitGraphPath(const AGitDir: string): string; inline;
function GitVerifyCommitGraph(const AGitDir: string): Boolean; inline;
procedure InvalidateCommitGraphCache(const AGitDir: string); inline;
function GitBuildCommitGraph(const AGitDir: string; const AOids: TGitOidArray): TBytes; inline;
function GitWriteCommitGraph(const AGitDir: string; const AOids: TGitOidArray): string; inline;
function GitWriteCommitGraphAll(const AGitDir: string): string; inline;

function GitReflogPath(const AGitDir, ARefName: string): string; inline;
function GitReflogExists(const AGitDir, ARefName: string): Boolean; inline;
function GitParseReflogLine(const ALine: string): TGitReflogEntry; inline;
function GitParseReflog(const AData: TBytes): TGitReflog; inline;
function GitReadReflog(const AGitDir, ARefName: string): TGitReflog; inline;

function GitRevParse(const AGitDir, ARev: string): TGitOid; inline;
function GitRevParseCommit(const AGitDir, ARev: string): TGitOid; inline;

function GitLogList(const AGitDir: string; AMaxCount: Integer): TGitLogArray; overload; inline;
function GitLogList(const AGitDir, ARef: string; AMaxCount: Integer): TGitLogArray; overload; inline;
function GitLogOneline(const AGitDir: string; AMaxCount: Integer): TStringArray; overload; inline;
function GitLogOneline(const AGitDir, ARef: string; AMaxCount: Integer): TStringArray; overload; inline;
function GitLogFind(const AGitDir: string; const AOid: TGitOid): TGitLogEntry; inline;
function GitLogFirstLine(const AMessage: string): string; inline;

function GitDescribe(const AGitDir: string): string; overload; inline;
function GitDescribe(const AGitDir, ARef: string): string; overload; inline;
function GitDescribeTags(const AGitDir: string): string; overload; inline;
function GitDescribeTags(const AGitDir, ARef: string): string; overload; inline;

function GitDiffTrees(const AGitDir: string; const AOldTree, ANewTree: TGitOid): TGitDiffArray; inline;
function GitDiffCommits(const AGitDir: string; const AOldCommit, ANewCommit: TGitOid): TGitDiffArray; inline;
function GitDiffRefs(const AGitDir, AOldRef, ANewRef: string): TGitDiffArray; inline;
function GitDiffNameStatus(const AGitDir: string; const AOldTree, ANewTree: TGitOid): TStringArray; inline;
function GitDiffStatSummary(const AGitDir: string; const AOldTree, ANewTree: TGitOid): string; inline;

function GitBlame(const AGitDir, ARef, APath: string): TGitBlameArray; overload; inline;
function GitBlame(const AGitDir, APath: string): TGitBlameArray; overload; inline;

function GitMergeBase(const AGitDir, ARefA, ARefB: string): TGitOid; overload; inline;
function GitMergeBase(const AGitDir: string; const AOidA, AOidB: TGitOid): TGitOid; overload; inline;
function GitMergeBaseMany(const AGitDir: string; const AOids: array of TGitOid): TGitOid; inline;

function GitShow(const AGitDir, ARef: string): TGitShow; overload; inline;
function GitShow(const AGitDir: string; const AOid: TGitOid): TGitShow; overload; inline;
function GitShowText(const AGitDir, ARef: string): string; overload; inline;
function GitShowText(const AGitDir: string; const AOid: TGitOid): string; overload; inline;

function GitShortlog(const AGitDir, ARef: string; AMaxCount: Integer): TGitShortlogArray; overload; inline;
function GitShortlog(const AGitDir: string; AMaxCount: Integer): TGitShortlogArray; overload; inline;
function GitShortlogText(const AGitDir, ARef: string; AMaxCount: Integer): string; overload; inline;
function GitShortlogText(const AGitDir: string; AMaxCount: Integer): string; overload; inline;

function GitCatFile(const AGitDir: string; const AOid: TGitOid): TGitCatFile; overload; inline;
function GitCatFile(const AGitDir, ARev: string): TGitCatFile; overload; inline;
function GitCatFileType(const AGitDir: string; const AOid: TGitOid): string; overload; inline;
function GitCatFileType(const AGitDir, ARev: string): string; overload; inline;
function GitCatFileSize(const AGitDir: string; const AOid: TGitOid): Integer; overload; inline;
function GitCatFileSize(const AGitDir, ARev: string): Integer; overload; inline;
function GitCatFilePretty(const AGitDir: string; const AOid: TGitOid): string; overload; inline;
function GitCatFilePretty(const AGitDir, ARev: string): string; overload; inline;

function GitCherryPick(const AGitDir, AWorkTree: string; const ATargetOid: TGitOid): TGitOid; overload; inline;
function GitCherryPick(const AGitDir, AWorkTree, ATargetRef: string): TGitOid; overload; inline;

function GitRevert(const AGitDir, AWorkTree: string; const ATargetOid: TGitOid): TGitOid; overload; inline;
function GitRevert(const AGitDir, AWorkTree, ATargetRef: string): TGitOid; overload; inline;

implementation

function DefaultGitRevOptions: TGitRevOptions; inline;
begin
  Result := nextpas.core.git.native.history.traversal.DefaultGitRevOptions;
end;

function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray; inline;
begin
  Result := nextpas.core.git.native.history.traversal.GitCollectCommits(
    ARepo, AStarts, AMaxCount);
end;

function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray; inline;
begin
  Result := nextpas.core.git.native.history.traversal.GitCollectCommits(
    ARepo, AStarts, AHides, AOptions, AMaxCount);
end;

function GitCollectCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray; inline;
begin
  Result := nextpas.core.git.native.history.traversal.GitCollectCommitsWithBoundary(
    ARepo, AStarts, AHides, AOptions, AMaxCount);
end;

function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray; inline;
begin
  Result := nextpas.core.git.native.history.traversal.GitTopoOrderCommits(
    ARepo, AStarts, AMaxCount);
end;

function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray; inline;
begin
  Result := nextpas.core.git.native.history.traversal.GitTopoOrderCommits(
    ARepo, AStarts, AHides, AOptions, AMaxCount);
end;

function GitTopoOrderCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray; inline;
begin
  Result := nextpas.core.git.native.history.traversal.GitTopoOrderCommitsWithBoundary(
    ARepo, AStarts, AHides, AOptions, AMaxCount);
end;

function GitTryLoadCommitGraph(const AGitDir: string; out AGraph: TCommitGraph): Boolean; inline;
begin
  Result := nextpas.core.git.native.history.traversal.GitTryLoadCommitGraph(AGitDir, AGraph);
end;

function GitCommitGraphPath(const AGitDir: string): string; inline;
begin
  Result := nextpas.core.git.native.history.traversal.GitCommitGraphPath(AGitDir);
end;

function GitVerifyCommitGraph(const AGitDir: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.history.traversal.GitVerifyCommitGraph(AGitDir);
end;

procedure InvalidateCommitGraphCache(const AGitDir: string); inline;
begin
  nextpas.core.git.native.history.traversal.InvalidateCommitGraphCache(AGitDir);
end;

function GitBuildCommitGraph(const AGitDir: string; const AOids: TGitOidArray): TBytes; inline;
begin
  Result := nextpas.core.git.native.history.traversal.GitBuildCommitGraph(AGitDir, AOids);
end;

function GitWriteCommitGraph(const AGitDir: string; const AOids: TGitOidArray): string; inline;
begin
  Result := nextpas.core.git.native.history.traversal.GitWriteCommitGraph(AGitDir, AOids);
end;

function GitWriteCommitGraphAll(const AGitDir: string): string; inline;
begin
  Result := nextpas.core.git.native.history.traversal.GitWriteCommitGraphAll(AGitDir);
end;

function GitReflogPath(const AGitDir, ARefName: string): string; inline;
begin
  Result := nextpas.core.git.native.history.traversal.GitReflogPath(AGitDir, ARefName);
end;

function GitReflogExists(const AGitDir, ARefName: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.history.traversal.GitReflogExists(AGitDir, ARefName);
end;

function GitParseReflogLine(const ALine: string): TGitReflogEntry; inline;
begin
  Result := nextpas.core.git.native.history.traversal.GitParseReflogLine(ALine);
end;

function GitParseReflog(const AData: TBytes): TGitReflog; inline;
begin
  Result := nextpas.core.git.native.history.traversal.GitParseReflog(AData);
end;

function GitReadReflog(const AGitDir, ARefName: string): TGitReflog; inline;
begin
  Result := nextpas.core.git.native.history.traversal.GitReadReflog(AGitDir, ARefName);
end;

function GitRevParse(const AGitDir, ARev: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.history.traversal.GitRevParse(AGitDir, ARev);
end;

function GitRevParseCommit(const AGitDir, ARev: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.history.traversal.GitRevParseCommit(AGitDir, ARev);
end;

function GitLogList(const AGitDir: string; AMaxCount: Integer): TGitLogArray; inline;
begin
  Result := nextpas.core.git.native.history.query.GitLogList(AGitDir, AMaxCount);
end;

function GitLogList(const AGitDir, ARef: string; AMaxCount: Integer): TGitLogArray; inline;
begin
  Result := nextpas.core.git.native.history.query.GitLogList(AGitDir, ARef, AMaxCount);
end;

function GitLogOneline(const AGitDir: string; AMaxCount: Integer): TStringArray; inline;
begin
  Result := nextpas.core.git.native.history.query.GitLogOneline(AGitDir, AMaxCount);
end;

function GitLogOneline(const AGitDir, ARef: string; AMaxCount: Integer): TStringArray; inline;
begin
  Result := nextpas.core.git.native.history.query.GitLogOneline(AGitDir, ARef, AMaxCount);
end;

function GitLogFind(const AGitDir: string; const AOid: TGitOid): TGitLogEntry; inline;
begin
  Result := nextpas.core.git.native.history.query.GitLogFind(AGitDir, AOid);
end;

function GitLogFirstLine(const AMessage: string): string; inline;
begin
  Result := nextpas.core.git.native.history.query.GitLogFirstLine(AMessage);
end;

function GitDescribe(const AGitDir: string): string; inline;
begin
  Result := nextpas.core.git.native.history.query.GitDescribe(AGitDir);
end;

function GitDescribe(const AGitDir, ARef: string): string; inline;
begin
  Result := nextpas.core.git.native.history.query.GitDescribe(AGitDir, ARef);
end;

function GitDescribeTags(const AGitDir: string): string; inline;
begin
  Result := nextpas.core.git.native.history.query.GitDescribeTags(AGitDir);
end;

function GitDescribeTags(const AGitDir, ARef: string): string; inline;
begin
  Result := nextpas.core.git.native.history.query.GitDescribeTags(AGitDir, ARef);
end;

function GitDiffTrees(const AGitDir: string; const AOldTree, ANewTree: TGitOid): TGitDiffArray; inline;
begin
  Result := nextpas.core.git.native.history.query.GitDiffTrees(AGitDir, AOldTree, ANewTree);
end;

function GitDiffCommits(const AGitDir: string; const AOldCommit, ANewCommit: TGitOid): TGitDiffArray; inline;
begin
  Result := nextpas.core.git.native.history.query.GitDiffCommits(AGitDir, AOldCommit, ANewCommit);
end;

function GitDiffRefs(const AGitDir, AOldRef, ANewRef: string): TGitDiffArray; inline;
begin
  Result := nextpas.core.git.native.history.query.GitDiffRefs(AGitDir, AOldRef, ANewRef);
end;

function GitDiffNameStatus(const AGitDir: string; const AOldTree, ANewTree: TGitOid): TStringArray; inline;
begin
  Result := nextpas.core.git.native.history.query.GitDiffNameStatus(AGitDir, AOldTree, ANewTree);
end;

function GitDiffStatSummary(const AGitDir: string; const AOldTree, ANewTree: TGitOid): string; inline;
begin
  Result := nextpas.core.git.native.history.query.GitDiffStatSummary(AGitDir, AOldTree, ANewTree);
end;

function GitBlame(const AGitDir, ARef, APath: string): TGitBlameArray; inline;
begin
  Result := nextpas.core.git.native.history.query.GitBlame(AGitDir, ARef, APath);
end;

function GitBlame(const AGitDir, APath: string): TGitBlameArray; inline;
begin
  Result := nextpas.core.git.native.history.query.GitBlame(AGitDir, APath);
end;

function GitMergeBase(const AGitDir, ARefA, ARefB: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.history.query.GitMergeBase(AGitDir, ARefA, ARefB);
end;

function GitMergeBase(const AGitDir: string; const AOidA, AOidB: TGitOid): TGitOid; inline;
begin
  Result := nextpas.core.git.native.history.query.GitMergeBase(AGitDir, AOidA, AOidB);
end;

function GitMergeBaseMany(const AGitDir: string; const AOids: array of TGitOid): TGitOid; inline;
begin
  Result := nextpas.core.git.native.history.query.GitMergeBaseMany(AGitDir, AOids);
end;

function GitShow(const AGitDir, ARef: string): TGitShow; inline;
begin
  Result := nextpas.core.git.native.history.query.GitShow(AGitDir, ARef);
end;

function GitShow(const AGitDir: string; const AOid: TGitOid): TGitShow; inline;
begin
  Result := nextpas.core.git.native.history.query.GitShow(AGitDir, AOid);
end;

function GitShowText(const AGitDir, ARef: string): string; inline;
begin
  Result := nextpas.core.git.native.history.query.GitShowText(AGitDir, ARef);
end;

function GitShowText(const AGitDir: string; const AOid: TGitOid): string; inline;
begin
  Result := nextpas.core.git.native.history.query.GitShowText(AGitDir, AOid);
end;

function GitShortlog(const AGitDir, ARef: string; AMaxCount: Integer): TGitShortlogArray; inline;
begin
  Result := nextpas.core.git.native.history.ops.GitShortlog(AGitDir, ARef, AMaxCount);
end;

function GitShortlog(const AGitDir: string; AMaxCount: Integer): TGitShortlogArray; inline;
begin
  Result := nextpas.core.git.native.history.ops.GitShortlog(AGitDir, AMaxCount);
end;

function GitShortlogText(const AGitDir, ARef: string; AMaxCount: Integer): string; inline;
begin
  Result := nextpas.core.git.native.history.ops.GitShortlogText(AGitDir, ARef, AMaxCount);
end;

function GitShortlogText(const AGitDir: string; AMaxCount: Integer): string; inline;
begin
  Result := nextpas.core.git.native.history.ops.GitShortlogText(AGitDir, AMaxCount);
end;

function GitCatFile(const AGitDir: string; const AOid: TGitOid): TGitCatFile; inline;
begin
  Result := nextpas.core.git.native.history.ops.GitCatFile(AGitDir, AOid);
end;

function GitCatFile(const AGitDir, ARev: string): TGitCatFile; inline;
begin
  Result := nextpas.core.git.native.history.ops.GitCatFile(AGitDir, ARev);
end;

function GitCatFileType(const AGitDir: string; const AOid: TGitOid): string; inline;
begin
  Result := nextpas.core.git.native.history.ops.GitCatFileType(AGitDir, AOid);
end;

function GitCatFileType(const AGitDir, ARev: string): string; inline;
begin
  Result := nextpas.core.git.native.history.ops.GitCatFileType(AGitDir, ARev);
end;

function GitCatFileSize(const AGitDir: string; const AOid: TGitOid): Integer; inline;
begin
  Result := nextpas.core.git.native.history.ops.GitCatFileSize(AGitDir, AOid);
end;

function GitCatFileSize(const AGitDir, ARev: string): Integer; inline;
begin
  Result := nextpas.core.git.native.history.ops.GitCatFileSize(AGitDir, ARev);
end;

function GitCatFilePretty(const AGitDir: string; const AOid: TGitOid): string; inline;
begin
  Result := nextpas.core.git.native.history.ops.GitCatFilePretty(AGitDir, AOid);
end;

function GitCatFilePretty(const AGitDir, ARev: string): string; inline;
begin
  Result := nextpas.core.git.native.history.ops.GitCatFilePretty(AGitDir, ARev);
end;

function GitCherryPick(const AGitDir, AWorkTree: string; const ATargetOid: TGitOid): TGitOid; inline;
begin
  Result := nextpas.core.git.native.history.ops.GitCherryPick(AGitDir, AWorkTree, ATargetOid);
end;

function GitCherryPick(const AGitDir, AWorkTree, ATargetRef: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.history.ops.GitCherryPick(AGitDir, AWorkTree, ATargetRef);
end;

function GitRevert(const AGitDir, AWorkTree: string; const ATargetOid: TGitOid): TGitOid; inline;
begin
  Result := nextpas.core.git.native.history.ops.GitRevert(AGitDir, AWorkTree, ATargetOid);
end;

function GitRevert(const AGitDir, AWorkTree, ATargetRef: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.history.ops.GitRevert(AGitDir, AWorkTree, ATargetRef);
end;

end.
