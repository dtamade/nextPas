unit nextpas.core.git.factory;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.git.intf;

type
  TGitBackend = (gbNative, gbLibGit2, gbAuto);

function NewGitManager(ABackend: TGitBackend = gbAuto): IGitManager;

implementation

uses
  nextpas.core.git.native.manager,
  nextpas.core.git.libgit2;

function NewGitManager(ABackend: TGitBackend): IGitManager;
begin
  if ABackend = gbAuto then
    ABackend := gbLibGit2;
  case ABackend of
    gbNative:
      Result := TNativeGitManager.Create;
    gbLibGit2:
      Result := nextpas.core.git.libgit2.NewGitManager;
  else
    Result := nextpas.core.git.libgit2.NewGitManager;
  end;
end;

end.
