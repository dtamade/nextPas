unit nextpas.core.git.native.status;

{$I nextpas.core.settings.inc}

{ status 薄门面: 类型/状态码重导出 + 三重载 inline 转发至 collect 域.
  - base: 状态码/条目纯数据类型与模式类常量单源.
  - scan: 树扁平化 + 工作树比对.
  - untracked: 忽略栈 + 未跟踪扫描 + 全局排除.
  - match: 结果行追加 + 路径序输出.
  - collect: 七参主入口编排.
  - similarity: 重命名/拷贝相似度 (既有分片, 直连复用).
  存量调用方零改动, 新代码可直引分片. }

interface

uses
  nextpas.core.git.base,
  nextpas.core.git.native.status.base,
  nextpas.core.git.native.status.collect;

{ Status: HEAD<->index / index<->worktree + untracked (porcelain groups) }

type
  // single source via base — eliminates L2:base vs native dual track, reuse bytes.ops inline zero-copy
  TGitStatusCode = nextpas.core.git.native.status.base.TGitStatusCode;

const
  // re-export base vocab for qualified native.status.gsc* consumers (staging facade) — inline zero-copy, no alloc
  gscUnmodified  = nextpas.core.git.native.status.base.gscUnmodified;
  gscAdded       = nextpas.core.git.native.status.base.gscAdded;
  gscModified    = nextpas.core.git.native.status.base.gscModified;
  gscDeleted     = nextpas.core.git.native.status.base.gscDeleted;
  gscTypeChanged = nextpas.core.git.native.status.base.gscTypeChanged;
  gscUnmerged    = nextpas.core.git.native.status.base.gscUnmerged;
  gscUntracked   = nextpas.core.git.native.status.base.gscUntracked;
  gscRenamed     = nextpas.core.git.native.status.base.gscRenamed;
  gscCopied      = nextpas.core.git.native.status.base.gscCopied;

type
  TGitNativeStatusEntry =
    nextpas.core.git.native.status.base.TGitNativeStatusEntry;
  TGitNativeStatusArray =
    nextpas.core.git.native.status.base.TGitNativeStatusArray;

function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean): TGitNativeStatusArray; overload; inline;
function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean; AFindRenames: Boolean;
  ARenameThreshold: Integer): TGitNativeStatusArray; overload; inline;
function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean; AFindRenames: Boolean;
  ARenameThreshold: Integer; AFindCopies: Boolean;
  ACopyThreshold: Integer): TGitNativeStatusArray; overload; inline;

implementation

function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean): TGitNativeStatusArray; overload; inline;
begin
  Result := nextpas.core.git.native.status.collect.GitCollectStatus(
    AGitDir, AWorkTree, AIncludeUntracked, True, 50, False, 50);
end;

function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean; AFindRenames: Boolean;
  ARenameThreshold: Integer): TGitNativeStatusArray; overload; inline;
begin
  Result := nextpas.core.git.native.status.collect.GitCollectStatus(
    AGitDir, AWorkTree, AIncludeUntracked, AFindRenames, ARenameThreshold, False, 50);
end;

function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean; AFindRenames: Boolean;
  ARenameThreshold: Integer; AFindCopies: Boolean;
  ACopyThreshold: Integer): TGitNativeStatusArray; overload; inline;
begin
  Result := nextpas.core.git.native.status.collect.GitCollectStatus(
    AGitDir, AWorkTree, AIncludeUntracked, AFindRenames, ARenameThreshold, AFindCopies, ACopyThreshold);
end;

end.
