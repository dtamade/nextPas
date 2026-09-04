unit nextpas.core.git.native.revwalk;

{$I nextpas.core.settings.inc}

{ revwalk 薄门面: 类型别名 + inline 转发至按域分片实现.
  - base: 纯数据类型 (TWalkEntry/TGitRevEntry/TGitRevOptions) 单源.
  - intf: IGitRevWalker 契约接缝.
  - hashset: Oid 集合与索引映射 + 探针 helpers 单源.
  - parsecache: 4096-cap 解析缓存 (恰一次解析).
  - fetch: 单次交付 (图/缓存/解析) + 隐藏集 + 日期裁剪, 三域共享.
  - walker: committer-date 堆游标 + 单游标一次收集.
  - collect: 日期序边界收集 (自带堆与隐藏集).
  - topo: 拓扑序收集.
  TGitOidArray 显式别名至 revwalk.base（其本体即 git.native.base 单源，
  commitgraph.base 历史副本已同步收敛至同一单源；显式别名钉死实现签名解析, 见分片注释); 存量调用方零改动,
  新代码可直引分片. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.revwalk.base,
  nextpas.core.git.native.revwalk.intf,
  nextpas.core.git.native.revwalk.hashset,
  nextpas.core.git.native.revwalk.parsecache,
  nextpas.core.git.native.revwalk.walker,
  nextpas.core.git.native.repo;

type
  { re-export base types — canonical owner is revwalk.base, this unit is impl/facade }
  TGitOidArray = nextpas.core.git.native.revwalk.base.TGitOidArray;
  TWalkEntry = nextpas.core.git.native.revwalk.base.TWalkEntry;
  PWalkEntry = nextpas.core.git.native.revwalk.base.PWalkEntry;
  TGitRevEntry = nextpas.core.git.native.revwalk.base.TGitRevEntry;
  TGitRevEntryArray = nextpas.core.git.native.revwalk.base.TGitRevEntryArray;
  TGitRevOptions = nextpas.core.git.native.revwalk.base.TGitRevOptions;

  { re-export domain classes — canonical owners are the shard units }
  TGitOidSet = nextpas.core.git.native.revwalk.hashset.TGitOidSet;
  TCommitParseCache = nextpas.core.git.native.revwalk.parsecache.TCommitParseCache;
  TOidIndexMap = nextpas.core.git.native.revwalk.hashset.TOidIndexMap;
  TGitRevWalker = nextpas.core.git.native.revwalk.walker.TGitRevWalker;

function DefaultGitRevOptions: TGitRevOptions; inline;

{ one-shot convenience: AMaxCount < 0 means unlimited }
function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray; overload; inline;
function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray; overload; inline;
function GitCollectCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray; inline;

{ one-shot topological order (children always precede parents, ready set
  drained LIFO exactly like git's default --topo-order): buffers the
  reachable subgraph, so it costs one read+parse per reachable commit up
  front. AMaxCount < 0 means unlimited. }
function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray; overload; inline;
function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray; overload; inline;
function GitTopoOrderCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray; inline;

implementation

uses
  nextpas.core.git.native.revwalk.collect,
  nextpas.core.git.native.revwalk.topo;

function DefaultGitRevOptions: TGitRevOptions; inline;
begin
  Result := nextpas.core.git.native.revwalk.base.DefaultGitRevOptions;
end;

function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray; overload; inline;
begin
  Result := nextpas.core.git.native.revwalk.walker.GitCollectCommits(ARepo, AStarts, AMaxCount);
end;

function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray; overload; inline;
begin
  Result := nextpas.core.git.native.revwalk.collect.GitCollectCommits(ARepo, AStarts, AHides, AOptions, AMaxCount);
end;

function GitCollectCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray; inline;
begin
  Result := nextpas.core.git.native.revwalk.collect.GitCollectCommitsWithBoundary(ARepo, AStarts, AHides, AOptions, AMaxCount);
end;

function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray; overload; inline;
begin
  Result := nextpas.core.git.native.revwalk.topo.GitTopoOrderCommits(ARepo, AStarts, AMaxCount);
end;

function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray; overload; inline;
begin
  Result := nextpas.core.git.native.revwalk.topo.GitTopoOrderCommits(ARepo, AStarts, AHides, AOptions, AMaxCount);
end;

function GitTopoOrderCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray; inline;
begin
  Result := nextpas.core.git.native.revwalk.topo.GitTopoOrderCommitsWithBoundary(ARepo, AStarts, AHides, AOptions, AMaxCount);
end;

end.
