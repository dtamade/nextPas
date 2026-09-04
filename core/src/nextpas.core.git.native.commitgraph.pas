unit nextpas.core.git.native.commitgraph;

{$I nextpas.core.settings.inc}

{ commit-graph v1 薄门面: 类型别名 + inline 转发至按域分片实现.
  - base: chunk 常量 + 条目/原始提交类型单源.
  - cache: 16-cap LRU + mmap 槽位 (命中/落盘编排).
  - reader: TCommitGraph 解析/查找 + TryLoad/Verify/Path.
  - writer: 排序 + BuildGraphBytes + Build/Write.
  - collect: 全量收集 + WriteAll.
  存量调用方 (revwalk/history.traversal) 零改动; 新代码可直引分片. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.commitgraph.base,
  nextpas.core.git.native.commitgraph.reader;

type
  TGitOidArray = nextpas.core.git.native.commitgraph.base.TGitOidArray;
  TCommitGraphEntry = nextpas.core.git.native.commitgraph.base.TCommitGraphEntry;
  TCommitGraph = nextpas.core.git.native.commitgraph.reader.TCommitGraph;

function GitTryLoadCommitGraph(const AGitDir: string; out AGraph: TCommitGraph): Boolean; inline;
function GitCommitGraphPath(const AGitDir: string): string; inline;
function GitVerifyCommitGraph(const AGitDir: string): Boolean; inline;
procedure InvalidateCommitGraphCache(const AGitDir: string); inline;

function GitBuildCommitGraph(const AGitDir: string; const AOids: TGitOidArray): TBytes; inline;
function GitWriteCommitGraph(const AGitDir: string; const AOids: TGitOidArray): string; inline;
function GitWriteCommitGraphAll(const AGitDir: string): string; inline;

implementation

uses
  nextpas.core.git.native.commitgraph.cache,
  nextpas.core.git.native.commitgraph.writer,
  nextpas.core.git.native.commitgraph.collect;

function GitTryLoadCommitGraph(const AGitDir: string; out AGraph: TCommitGraph): Boolean; inline;
begin
  Result := nextpas.core.git.native.commitgraph.reader.GitTryLoadCommitGraph(AGitDir, AGraph);
end;

function GitCommitGraphPath(const AGitDir: string): string; inline;
begin
  Result := nextpas.core.git.native.commitgraph.reader.GitCommitGraphPath(AGitDir);
end;

function GitVerifyCommitGraph(const AGitDir: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.commitgraph.reader.GitVerifyCommitGraph(AGitDir);
end;

procedure InvalidateCommitGraphCache(const AGitDir: string); inline;
begin
  nextpas.core.git.native.commitgraph.cache.InvalidateCommitGraphCache(AGitDir);
end;

function GitBuildCommitGraph(const AGitDir: string; const AOids: TGitOidArray): TBytes; inline;
begin
  Result := nextpas.core.git.native.commitgraph.writer.GitBuildCommitGraph(AGitDir, AOids);
end;

function GitWriteCommitGraph(const AGitDir: string; const AOids: TGitOidArray): string; inline;
begin
  Result := nextpas.core.git.native.commitgraph.writer.GitWriteCommitGraph(AGitDir, AOids);
end;

function GitWriteCommitGraphAll(const AGitDir: string): string; inline;
begin
  Result := nextpas.core.git.native.commitgraph.collect.GitWriteCommitGraphAll(AGitDir);
end;

end.
