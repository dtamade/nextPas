unit nextpas.core.git.factory;

{$I nextpas.core.settings.inc}

{ 唯一跨轨汇聚点 — 依赖债务显式隔离见 PURE-BACKEND.md §1-§2 / CONTRACT.md §1.1
  - 本单元为唯一同时 uses native.manager 与 libgit2 的单元; 其余单元禁止跨轨
  - gbNative 经本单元: 运行时零 libgit2(无 dlopen, TNativeGitManager 纯路径, inline 零拷贝分发, 接口引用计数零泄漏)
  - 纯路径编译图仍含 libgit2(factory 跨轨致 fpc -va Loading 命中); 全维度三零(编译期/运行时/产物)需直连 native.manager.TNativeGitManager.Create
  - EGitError 单源 native.base; 零 {$IFDEF} 分叉, 隔离在 uses 图; 存量 gbAuto 首版=gbLibGit2 }

interface

uses
  nextpas.core.git.intf;

type
  TGitBackend = (gbNative, gbLibGit2, gbAuto);

function NewGitManager(ABackend: TGitBackend = gbAuto): IGitManager; inline;

implementation

uses
  nextpas.core.git.native.manager,
  nextpas.core.git.libgit2;

function NewGitManager(ABackend: TGitBackend): IGitManager; inline;
begin
  case ABackend of
    gbNative:
      Result := TNativeGitManager.Create;
    gbLibGit2, gbAuto:
      Result := nextpas.core.git.libgit2.NewGitManager;
  end;
end;

end.
