unit nextpas.core.git.libgit2;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.git.base,
  nextpas.core.git.intf,
  nextpas.core.git.libgit2.manager;

type
  EGitError = nextpas.core.git.libgit2.manager.EGitError;
  TGitManagerImpl = nextpas.core.git.libgit2.manager.TGitManagerImpl;
  TGitRepositoryImpl = nextpas.core.git.libgit2.manager.TGitRepositoryImpl;
  TGitCommitImpl = nextpas.core.git.libgit2.manager.TGitCommitImpl;
  TGitReferenceImpl = nextpas.core.git.libgit2.manager.TGitReferenceImpl;
  TGitRemoteImpl = nextpas.core.git.libgit2.manager.TGitRemoteImpl;
  TGitWorktreeImpl = nextpas.core.git.libgit2.manager.TGitWorktreeImpl;

function NewGitManager: IGitManager; inline;

implementation

function NewGitManager: IGitManager; inline;
begin
  Result := nextpas.core.git.libgit2.manager.NewGitManager;
end;

end.
