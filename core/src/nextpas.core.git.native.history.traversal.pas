unit nextpas.core.git.native.history.traversal;

{$I nextpas.core.settings.inc}

{**
 * @desc History shard — traversal domain (revwalk/commitgraph/reflog/revparse)
 * Invariant: commit-graph-aware revwalk (date/topo, hide/boundary, single-parse),
 *   reflog line parsing, rev-parse peeling. No log/diff/mutate logic.
 * Fan-in: 4 owner units — revwalk/commitgraph/reflog/revparse.
 * Perf: all forwards `inline`; zero-copy via bytes.ops single source
 *   (TGitOid 20B Move, TByteSpan, PByte+Len) + owner single-parse/cached
 *   (revwalk once, commitgraph mtime+size cache).
 * Stability: ownership in owners (TCommitGraph/TPackFile IMappedFile refcounted,
 *   revwalk queues try..finally); facade zero alloc/zero leak.
 *}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.revwalk,
  nextpas.core.git.native.commitgraph,
  nextpas.core.git.native.reflog,
  nextpas.core.git.native.revparse;

type
  TNativeRepository = nextpas.core.git.native.repo.TNativeRepository;
  TGitOidArray = nextpas.core.git.native.revwalk.TGitOidArray;
  TGitOidSet = nextpas.core.git.native.revwalk.TGitOidSet;
  TGitRevWalker = nextpas.core.git.native.revwalk.TGitRevWalker;
  TGitRevEntry = nextpas.core.git.native.revwalk.TGitRevEntry;
  TGitRevEntryArray = nextpas.core.git.native.revwalk.TGitRevEntryArray;
  TGitRevOptions = nextpas.core.git.native.revwalk.TGitRevOptions;
  TCommitGraph = nextpas.core.git.native.commitgraph.TCommitGraph;
  TCommitGraphEntry = nextpas.core.git.native.commitgraph.TCommitGraphEntry;
  TGitReflogEntry = nextpas.core.git.native.reflog.TGitReflogEntry;
  TGitReflog = nextpas.core.git.native.reflog.TGitReflog;
  TGitOid = nextpas.core.git.native.base.TGitOid;

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

implementation

function DefaultGitRevOptions: TGitRevOptions; inline;
begin
  Result := nextpas.core.git.native.revwalk.DefaultGitRevOptions;
end;

function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray; inline;
begin
  Result := nextpas.core.git.native.revwalk.GitCollectCommits(
    ARepo, AStarts, AMaxCount);
end;

function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray; inline;
begin
  Result := nextpas.core.git.native.revwalk.GitCollectCommits(
    ARepo, AStarts, AHides, AOptions, AMaxCount);
end;

function GitCollectCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray; inline;
begin
  Result := nextpas.core.git.native.revwalk.GitCollectCommitsWithBoundary(
    ARepo, AStarts, AHides, AOptions, AMaxCount);
end;

function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray; inline;
begin
  Result := nextpas.core.git.native.revwalk.GitTopoOrderCommits(
    ARepo, AStarts, AMaxCount);
end;

function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray; inline;
begin
  Result := nextpas.core.git.native.revwalk.GitTopoOrderCommits(
    ARepo, AStarts, AHides, AOptions, AMaxCount);
end;

function GitTopoOrderCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray; inline;
begin
  Result := nextpas.core.git.native.revwalk.GitTopoOrderCommitsWithBoundary(
    ARepo, AStarts, AHides, AOptions, AMaxCount);
end;

function GitTryLoadCommitGraph(const AGitDir: string; out AGraph: TCommitGraph): Boolean; inline;
begin
  Result := nextpas.core.git.native.commitgraph.GitTryLoadCommitGraph(AGitDir, AGraph);
end;

function GitCommitGraphPath(const AGitDir: string): string; inline;
begin
  Result := nextpas.core.git.native.commitgraph.GitCommitGraphPath(AGitDir);
end;

function GitVerifyCommitGraph(const AGitDir: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.commitgraph.GitVerifyCommitGraph(AGitDir);
end;

procedure InvalidateCommitGraphCache(const AGitDir: string); inline;
begin
  nextpas.core.git.native.commitgraph.InvalidateCommitGraphCache(AGitDir);
end;

function GitBuildCommitGraph(const AGitDir: string; const AOids: TGitOidArray): TBytes; inline;
begin
  Result := nextpas.core.git.native.commitgraph.GitBuildCommitGraph(AGitDir, AOids);
end;

function GitWriteCommitGraph(const AGitDir: string; const AOids: TGitOidArray): string; inline;
begin
  Result := nextpas.core.git.native.commitgraph.GitWriteCommitGraph(AGitDir, AOids);
end;

function GitWriteCommitGraphAll(const AGitDir: string): string; inline;
begin
  Result := nextpas.core.git.native.commitgraph.GitWriteCommitGraphAll(AGitDir);
end;

function GitReflogPath(const AGitDir, ARefName: string): string; inline;
begin
  Result := nextpas.core.git.native.reflog.GitReflogPath(AGitDir, ARefName);
end;

function GitReflogExists(const AGitDir, ARefName: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.reflog.GitReflogExists(AGitDir, ARefName);
end;

function GitParseReflogLine(const ALine: string): TGitReflogEntry; inline;
begin
  Result := nextpas.core.git.native.reflog.GitParseReflogLine(ALine);
end;

function GitParseReflog(const AData: TBytes): TGitReflog; inline;
begin
  Result := nextpas.core.git.native.reflog.GitParseReflog(AData);
end;

function GitReadReflog(const AGitDir, ARefName: string): TGitReflog; inline;
begin
  Result := nextpas.core.git.native.reflog.GitReadReflog(AGitDir, ARefName);
end;

function GitRevParse(const AGitDir, ARev: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.revparse.GitRevParse(AGitDir, ARev);
end;

function GitRevParseCommit(const AGitDir, ARev: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.revparse.GitRevParseCommit(AGitDir, ARev);
end;

end.
