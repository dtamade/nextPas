unit nextpas.core.git.native.revwalk.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.revwalk.base;

type
  { revwalk contracts — thin interface seam for walker, keeps base←intf layering }
  IGitRevWalker = interface
    procedure Push(const AOid: TGitOid);
    procedure PushHead(const AGitDir: string);
    procedure PushHide(const AOid: TGitOid);
    procedure SetFirstParent(AValue: Boolean);
    procedure SetDateRange(ASince, AUntilTime: Int64);
    procedure SetShowBoundary(AValue: Boolean);
    function Next(out AOid: TGitOid): Boolean;
    function NextWithBoundary(out AEntry: TGitRevEntry): Boolean;
  end;

implementation

end.
