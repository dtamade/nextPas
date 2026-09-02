unit nextpas.core.git.native.history.query;

{$I nextpas.core.settings.inc}

{**
 * @desc History shard — query domain (log/describe/diff/blame/mergebase/show)
 * Invariant: log/describe via revwalk+revparse aggregation; diff/blame via
 *   flat recursion+sorted merge (Added/Modified/Deleted/TypeChanged); mergebase
 *   via ancestor BFS; show via log+diff. No traversal cache or mutate logic.
 * Fan-in: 6 owner units — log/describe/diff/blame/mergebase/show.
 * Perf: all forwards `inline`; zero-copy via bytes.ops single source
 *   (TByteSpan, PByte+Len) + owner single-parse/cached.
 * Stability: ownership in owners (checkout/index try..finally via owner);
 *   facade zero alloc/zero leak.
 *}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.log,
  nextpas.core.git.native.describe,
  nextpas.core.git.native.diff,
  nextpas.core.git.native.blame,
  nextpas.core.git.native.mergebase,
  nextpas.core.git.native.show;

type
  TGitLogEntry = nextpas.core.git.native.log.TGitLogEntry;
  TGitLogArray = nextpas.core.git.native.log.TGitLogArray;
  TGitDiffStatus = nextpas.core.git.native.diff.TGitDiffStatus;
  TGitDiffEntry = nextpas.core.git.native.diff.TGitDiffEntry;
  TGitDiffArray = nextpas.core.git.native.diff.TGitDiffArray;
  TGitBlameEntry = nextpas.core.git.native.blame.TGitBlameEntry;
  TGitBlameArray = nextpas.core.git.native.blame.TGitBlameArray;
  TGitShow = nextpas.core.git.native.show.TGitShow;
  TGitOid = nextpas.core.git.native.base.TGitOid;

const
  gdsAdded = nextpas.core.git.native.diff.gdsAdded;
  gdsModified = nextpas.core.git.native.diff.gdsModified;
  gdsDeleted = nextpas.core.git.native.diff.gdsDeleted;
  gdsTypeChanged = nextpas.core.git.native.diff.gdsTypeChanged;

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

implementation

function GitLogList(const AGitDir: string; AMaxCount: Integer): TGitLogArray; inline;
begin
  Result := nextpas.core.git.native.log.GitLogList(AGitDir, AMaxCount);
end;

function GitLogList(const AGitDir, ARef: string; AMaxCount: Integer): TGitLogArray; inline;
begin
  Result := nextpas.core.git.native.log.GitLogList(AGitDir, ARef, AMaxCount);
end;

function GitLogOneline(const AGitDir: string; AMaxCount: Integer): TStringArray; inline;
begin
  Result := nextpas.core.git.native.log.GitLogOneline(AGitDir, AMaxCount);
end;

function GitLogOneline(const AGitDir, ARef: string; AMaxCount: Integer): TStringArray; inline;
begin
  Result := nextpas.core.git.native.log.GitLogOneline(AGitDir, ARef, AMaxCount);
end;

function GitLogFind(const AGitDir: string; const AOid: TGitOid): TGitLogEntry; inline;
begin
  Result := nextpas.core.git.native.log.GitLogFind(AGitDir, AOid);
end;

function GitLogFirstLine(const AMessage: string): string; inline;
begin
  Result := nextpas.core.git.native.log.GitLogFirstLine(AMessage);
end;

function GitDescribe(const AGitDir: string): string; inline;
begin
  Result := nextpas.core.git.native.describe.GitDescribe(AGitDir);
end;

function GitDescribe(const AGitDir, ARef: string): string; inline;
begin
  Result := nextpas.core.git.native.describe.GitDescribe(AGitDir, ARef);
end;

function GitDescribeTags(const AGitDir: string): string; inline;
begin
  Result := nextpas.core.git.native.describe.GitDescribeTags(AGitDir);
end;

function GitDescribeTags(const AGitDir, ARef: string): string; inline;
begin
  Result := nextpas.core.git.native.describe.GitDescribeTags(AGitDir, ARef);
end;

function GitDiffTrees(const AGitDir: string; const AOldTree, ANewTree: TGitOid): TGitDiffArray; inline;
begin
  Result := nextpas.core.git.native.diff.GitDiffTrees(AGitDir, AOldTree, ANewTree);
end;

function GitDiffCommits(const AGitDir: string; const AOldCommit, ANewCommit: TGitOid): TGitDiffArray; inline;
begin
  Result := nextpas.core.git.native.diff.GitDiffCommits(AGitDir, AOldCommit, ANewCommit);
end;

function GitDiffRefs(const AGitDir, AOldRef, ANewRef: string): TGitDiffArray; inline;
begin
  Result := nextpas.core.git.native.diff.GitDiffRefs(AGitDir, AOldRef, ANewRef);
end;

function GitDiffNameStatus(const AGitDir: string; const AOldTree, ANewTree: TGitOid): TStringArray; inline;
begin
  Result := nextpas.core.git.native.diff.GitDiffNameStatus(AGitDir, AOldTree, ANewTree);
end;

function GitDiffStatSummary(const AGitDir: string; const AOldTree, ANewTree: TGitOid): string; inline;
begin
  Result := nextpas.core.git.native.diff.GitDiffStatSummary(AGitDir, AOldTree, ANewTree);
end;

function GitBlame(const AGitDir, ARef, APath: string): TGitBlameArray; inline;
begin
  Result := nextpas.core.git.native.blame.GitBlame(AGitDir, ARef, APath);
end;

function GitBlame(const AGitDir, APath: string): TGitBlameArray; inline;
begin
  Result := nextpas.core.git.native.blame.GitBlame(AGitDir, APath);
end;

function GitMergeBase(const AGitDir, ARefA, ARefB: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.mergebase.GitMergeBase(AGitDir, ARefA, ARefB);
end;

function GitMergeBase(const AGitDir: string; const AOidA, AOidB: TGitOid): TGitOid; inline;
begin
  Result := nextpas.core.git.native.mergebase.GitMergeBase(AGitDir, AOidA, AOidB);
end;

function GitMergeBaseMany(const AGitDir: string; const AOids: array of TGitOid): TGitOid; inline;
begin
  Result := nextpas.core.git.native.mergebase.GitMergeBaseMany(AGitDir, AOids);
end;

function GitShow(const AGitDir, ARef: string): TGitShow; inline;
begin
  Result := nextpas.core.git.native.show.GitShow(AGitDir, ARef);
end;

function GitShow(const AGitDir: string; const AOid: TGitOid): TGitShow; inline;
begin
  Result := nextpas.core.git.native.show.GitShow(AGitDir, AOid);
end;

function GitShowText(const AGitDir, ARef: string): string; inline;
begin
  Result := nextpas.core.git.native.show.GitShowText(AGitDir, ARef);
end;

function GitShowText(const AGitDir: string; const AOid: TGitOid): string; inline;
begin
  Result := nextpas.core.git.native.show.GitShowText(AGitDir, AOid);
end;

end.
