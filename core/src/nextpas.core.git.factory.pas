unit nextpas.core.git.factory;

{$I nextpas.core.settings.inc}

{ 选择层静态汇聚 — 依赖隔离见 PURE-BACKEND.md §1-§2 / CONTRACT.md §1.1
  - 静态仅 native.manager，libgit2 经 RegisterLibGit2Creator 注册注入
  - gbNative/NewNativeGitManager 零 libgit2 (inline 值类型枚举零拷贝分发, 接口引用计数零泄漏)
  - gbLibGit2/gbAuto 未注册时 fail-closed 抛 EGitError (native.base 单源, 零 {$IFDEF}) }

interface

uses
  nextpas.core.git.intf;

type
  TGitBackend = (gbNative, gbLibGit2, gbAuto);
  TLibGit2Creator = function: IGitManager;

procedure RegisterLibGit2Creator(ACreator: TLibGit2Creator);
function NewGitManager(ABackend: TGitBackend = gbAuto): IGitManager; inline;
function NewNativeGitManager: IGitManager; inline;

implementation

uses
  nextpas.core.git.native.manager,
  nextpas.core.git.native.base;

var
  GLibGit2Creator: TLibGit2Creator;

procedure RegisterLibGit2Creator(ACreator: TLibGit2Creator);
begin
  GLibGit2Creator := ACreator;
end;

function NewNativeGitManager: IGitManager; inline;
begin
  Result := TNativeGitManager.Create;
end;

function NewGitManager(ABackend: TGitBackend): IGitManager; inline;
begin
  case ABackend of
    gbNative:
      Result := TNativeGitManager.Create;
    gbLibGit2, gbAuto:
      begin
        if Assigned(GLibGit2Creator) then
          Result := GLibGit2Creator()
        else
          raise EGitError.Create('libgit2 backend not registered (uses nextpas.core.git.libgit2 required for gbLibGit2/gbAuto)');
      end;
  end;
end;

end.
