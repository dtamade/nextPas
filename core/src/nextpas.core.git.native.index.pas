unit nextpas.core.git.native.index;

{$I nextpas.core.settings.inc}

{ index 薄门面: 类型重导出 + 八入口 inline 转发至按域分片实现.
  - base: 条目/文件纯数据类型与格式常量.
  - parse: DIRC v2/v3/v4 解析 + 校验 + 文件读取.
  - serialize: 规范排序 + DIRC 发射 + 原子落盘.
  - cachetree: 条目派生全量 cache-tree + 全记录序列化/落盘.
  存量调用方零改动, 新代码可直引分片. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.index.base,
  nextpas.core.git.native.cachetree,
  nextpas.core.git.native.index.parse,
  nextpas.core.git.native.index.serialize,
  nextpas.core.git.native.index.cachetree;

type
  TGitIndexEntry = nextpas.core.git.native.index.base.TGitIndexEntry;
  TGitIndexFile = nextpas.core.git.native.index.base.TGitIndexFile;
  TGitIndexEntryArray = nextpas.core.git.native.index.base.TGitIndexEntryArray;

function GitParseIndex(const AData: TBytes): TGitIndexFile; inline;
function GitReadIndex(const AGitDir: string): TGitIndexFile; inline;

{ Canonical index order: byte-compare paths, ties broken by ascending
  stage so conflict stages stay adjacent }
procedure GitSortIndexEntries(var AEntries: TGitIndexEntryArray); inline;
function GitSerializeIndex(
  const AEntries: array of TGitIndexEntry;
  AVersion: Cardinal): TBytes; inline;
{ Sorts in place (like GitWriteTree), then atomically replaces the index }
procedure GitWriteIndex(const AGitDir: string;
  var AEntries: TGitIndexEntryArray; AVersion: Cardinal); inline;

{ derives the full valid cache-tree hierarchy from index entries (any
  order); a single non-stage-0 entry invalidates the whole root, which
  consumers treat as "recompute" — coarser than git's per-directory
  invalidation but equally safe }
function GitBuildIndexCacheTree(
  const AEntries: array of TGitIndexEntry): TGitCacheTree; inline;

{ full-record variants: serialize/write preserving the TREE cache when
  the record carries one; extension-less otherwise }
function GitSerializeIndexFile(const AFile: TGitIndexFile): TBytes; inline;
procedure GitWriteIndexFile(const AGitDir: string;
  var AFile: TGitIndexFile); inline;

implementation

function GitParseIndex(const AData: TBytes): TGitIndexFile; inline;
begin
  Result := nextpas.core.git.native.index.parse.GitParseIndex(AData);
end;

function GitReadIndex(const AGitDir: string): TGitIndexFile; inline;
begin
  Result := nextpas.core.git.native.index.parse.GitReadIndex(AGitDir);
end;

procedure GitSortIndexEntries(var AEntries: TGitIndexEntryArray); inline;
begin
  nextpas.core.git.native.index.serialize.GitSortIndexEntries(AEntries);
end;

function GitSerializeIndex(
  const AEntries: array of TGitIndexEntry;
  AVersion: Cardinal): TBytes; inline;
begin
  Result := nextpas.core.git.native.index.serialize.GitSerializeIndex(AEntries, AVersion);
end;

procedure GitWriteIndex(const AGitDir: string;
  var AEntries: TGitIndexEntryArray; AVersion: Cardinal); inline;
begin
  nextpas.core.git.native.index.serialize.GitWriteIndex(AGitDir, AEntries, AVersion);
end;

function GitBuildIndexCacheTree(
  const AEntries: array of TGitIndexEntry): TGitCacheTree; inline;
begin
  Result := nextpas.core.git.native.index.cachetree.GitBuildIndexCacheTree(AEntries);
end;

function GitSerializeIndexFile(const AFile: TGitIndexFile): TBytes; inline;
begin
  Result := nextpas.core.git.native.index.cachetree.GitSerializeIndexFile(AFile);
end;

procedure GitWriteIndexFile(const AGitDir: string;
  var AFile: TGitIndexFile); inline;
begin
  nextpas.core.git.native.index.cachetree.GitWriteIndexFile(AGitDir, AFile);
end;

end.
