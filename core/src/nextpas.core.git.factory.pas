unit nextpas.core.git.factory;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.git.intf,
  nextpas.core.git.native.base,
  nextpas.core.git.native.manager,
  nextpas.core.git.libgit2;

type
  EGitError = nextpas.core.git.native.base.EGitError;
  TGitBackend = (gbNative, gbLibGit2, gbAuto);

function NewGitManager(ABackend: TGitBackend = gbAuto): IGitManager; inline;

implementation

function NewGitManager(ABackend: TGitBackend): IGitManager; inline;
begin
  // gbAuto策略：首版恒等于gbLibGit2（见PURE-BACKEND.md §3），值类型枚举零拷贝inline分发
  if ABackend = gbAuto then
    ABackend := gbLibGit2;
  case ABackend of
    gbNative:
      // PURE-BACKEND唯一跨轨汇聚：gbNative→TNativeGitManager零libgit2，接口引用计数零泄漏，异常以EGitError不丢
      Result := TNativeGitManager.Create;
    gbLibGit2:
      Result := nextpas.core.git.libgit2.NewGitManager;
  else
    raise EGitError.Create('unknown git backend');
  end;
end;

end.
