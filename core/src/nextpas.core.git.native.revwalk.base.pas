unit nextpas.core.git.native.revwalk.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base;

type
  { revwalk pure data types — owner L1 bytes.ops via git.native.base }
  TGitOidArray = array of TGitOid;

  TWalkEntry = record
    Oid: TGitOid;
    When: Int64;
    Parents: TGitOidArray;
  end;
  PWalkEntry = ^TWalkEntry;

  TGitRevEntry = record
    Oid: TGitOid;
    IsBoundary: Boolean;
  end;
  TGitRevEntryArray = array of TGitRevEntry;

  TGitRevOptions = record
    FirstParent: Boolean;
    Since: Int64; { 0 = no lower bound }
    UntilTime: Int64; { 0 = no upper bound }
    ShowBoundary: Boolean;
  end;

function DefaultGitRevOptions: TGitRevOptions; inline;

implementation

function DefaultGitRevOptions: TGitRevOptions; inline;
begin
  Result.FirstParent := False;
  Result.Since := 0;
  Result.UntilTime := 0;
  Result.ShowBoundary := False;
end;

end.
