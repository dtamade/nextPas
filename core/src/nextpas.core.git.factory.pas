unit nextpas.core.git.factory;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.git.intf,
  nextpas.core.git.libgit2.backend;

type
  EGitError = nextpas.core.git.libgit2.backend.EGitError;

function NewGitManager: IGitManager;

implementation

uses
  nextpas.core.git.libgit2;

function NewGitManager: IGitManager;
begin
  Result := nextpas.core.git.libgit2.NewGitManager;
end;

end.
