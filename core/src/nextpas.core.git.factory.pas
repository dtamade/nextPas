unit nextpas.core.git.factory;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.git.intf,
  nextpas.core.git.libgit2.backend;

type
  EGitError = nextpas.core.git.libgit2.backend.EGitError;
  TGitBackend = (gbNative, gbLibGit2, gbAuto);

function NewGitManager(ABackend: TGitBackend = gbAuto): IGitManager; inline;

implementation

uses
  nextpas.core.git.libgit2;

function NewGitManager(ABackend: TGitBackend): IGitManager; inline;
begin
  // gbAuto策略：首版恒等于gbLibGit2（见PURE-BACKEND.md §3），零拷贝枚举分发
  if ABackend = gbAuto then
    ABackend := gbLibGit2;
  case ABackend of
    gbNative:
      // native backend尚未闭合，显式抛EGitError而非静默回退，资源零泄漏
      raise EGitError.Create(-3, 'native git backend not implemented');
    gbLibGit2:
      Result := nextpas.core.git.libgit2.NewGitManager;
  else
    raise EGitError.Create(-12, 'unknown git backend');
  end;
end;

end.
