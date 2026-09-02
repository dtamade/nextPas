unit nextpas.core.git.native.repository;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.git.intf,
  nextpas.core.git.base,
  nextpas.core.text.conv;

type
  TNativeRepositoryAdapter = class(TInterfacedObject, IGitRepository, IGitRepositoryExt, IGitWorktreeExt)
  private
    FGitDir: string;
    FWorkTree: string;
    procedure EnsureOpen;
  public
    constructor Create(const AGitDir, AWorkTree: string);
    function Path: string;
    function WorkDir: string;
    function IsBare: Boolean;
    function IsEmpty: Boolean;
    function Head: IGitReference;
    function CurrentBranch: string;
    function ListBranches(Kind: TGitBranchKind = gbLocal): TStringArray;
    function CommitByHash(const Hash: string): IGitCommit;
    function HeadCommit: IGitCommit;
    function Remote(const Name: string = 'origin'): IGitRemote;
    function Fetch(const RemoteName: string = 'origin'): Boolean;
    function CheckoutBranch(const Branch: string): Boolean;
    function CheckoutBranchEx(const Branch: string; Force: Boolean): Boolean;
    function Status: TStringArray;
    function StatusEntries(const Filter: TGitStatusFilter): TGitStatusEntryArray;
    function IsClean: Boolean;
    function HasUncommittedChanges: Boolean;
    function ListRemotes: TStringArray;
    function PullFastForward(const RemoteName: string; out Error: string): TGitPullFastForwardResult;
    function Diff(const AOldRef, ANewRef: string): TGitDiff;
    function DiffEx(const AOldRef, ANewRef: string; const AOptions: TGitDiffOptions): TGitDiff;
    function DiffWorkingTree(const ARef: string): TGitDiff;
    function DiffWorkingTreeEx(const ARef: string; const AOptions: TGitDiffOptions): TGitDiff;
    function RevWalk(const AStartRef: string; ALimit: Integer): TGitCommitArray;
    function Blame(const APath: string): TGitBlame;
    function ConfigEntries: TGitConfigEntryArray;
    procedure ApplyPatch(const APatchText: string);
    procedure CheckoutPaths(const ARevspec: string; const APaths: TStringArray);
    function WorkdirPatchText(const ARevspec: string; const APaths: TStringArray; AShowBinary: Boolean): string;
    function AddWorktree(const AName, APath, ARef: string; ADetach: Boolean = False): IGitWorktree;
    function LookupWorktree(const AName: string): IGitWorktree;
    function ListWorktrees: TStringArray;
    function PruneWorktree(const AName: string): Boolean;
    function CommitOnHead(const AMessage: string; const AAuthorName, AAuthorEmail: string): string;
  end;

implementation

uses
  nextpas.core.git.native.base;

constructor TNativeRepositoryAdapter.Create(const AGitDir, AWorkTree: string);
begin inherited Create; FGitDir:=AGitDir; FWorkTree:=AWorkTree; end;
procedure TNativeRepositoryAdapter.EnsureOpen; begin end;
function TNativeRepositoryAdapter.Path: string; begin Result:=FGitDir; end;
function TNativeRepositoryAdapter.WorkDir: string; begin Result:=FWorkTree; end;
function TNativeRepositoryAdapter.IsBare: Boolean; begin Result:=FWorkTree=''; end;
function TNativeRepositoryAdapter.IsEmpty: Boolean; begin Result:=True; end;
function TNativeRepositoryAdapter.Head: IGitReference; begin raise EGitError.Create('not implemented'); Result:=nil; end;
function TNativeRepositoryAdapter.CurrentBranch: string; begin Result:=''; end;
function TNativeRepositoryAdapter.ListBranches(Kind: TGitBranchKind): TStringArray; begin Result:=nil; end;
function TNativeRepositoryAdapter.CommitByHash(const Hash: string): IGitCommit; begin Result:=nil; raise EGitError.Create('not implemented'); end;
function TNativeRepositoryAdapter.HeadCommit: IGitCommit; begin Result:=nil; raise EGitError.Create('not implemented'); end;
function TNativeRepositoryAdapter.Remote(const Name: string): IGitRemote; begin Result:=nil; end;
function TNativeRepositoryAdapter.Fetch(const RemoteName: string): Boolean; begin Result:=False; end;
function TNativeRepositoryAdapter.CheckoutBranch(const Branch: string): Boolean; begin Result:=False; end;
function TNativeRepositoryAdapter.CheckoutBranchEx(const Branch: string; Force: Boolean): Boolean; begin Result:=False; end;
function TNativeRepositoryAdapter.Status: TStringArray; begin Result:=nil; end;
function TNativeRepositoryAdapter.StatusEntries(const Filter: TGitStatusFilter): TGitStatusEntryArray; begin Result:=nil; end;
function TNativeRepositoryAdapter.IsClean: Boolean; begin Result:=True; end;
function TNativeRepositoryAdapter.HasUncommittedChanges: Boolean; begin Result:=False; end;
function TNativeRepositoryAdapter.ListRemotes: TStringArray; begin Result:=nil; end;
function TNativeRepositoryAdapter.PullFastForward(const RemoteName: string; out Error: string): TGitPullFastForwardResult; begin Error:=''; Result:=gpffUpToDate; end;
function TNativeRepositoryAdapter.Diff(const AOldRef, ANewRef: string): TGitDiff; begin Result.Files:=nil; end;
function TNativeRepositoryAdapter.DiffEx(const AOldRef, ANewRef: string; const AOptions: TGitDiffOptions): TGitDiff; begin Result.Files:=nil; end;
function TNativeRepositoryAdapter.DiffWorkingTree(const ARef: string): TGitDiff; begin Result.Files:=nil; end;
function TNativeRepositoryAdapter.DiffWorkingTreeEx(const ARef: string; const AOptions: TGitDiffOptions): TGitDiff; begin Result.Files:=nil; end;
function TNativeRepositoryAdapter.RevWalk(const AStartRef: string; ALimit: Integer): TGitCommitArray; begin Result:=nil; end;
function TNativeRepositoryAdapter.Blame(const APath: string): TGitBlame; begin Result.Path:=APath; Result.Hunks:=nil; end;
function TNativeRepositoryAdapter.ConfigEntries: TGitConfigEntryArray; begin Result:=nil; end;
procedure TNativeRepositoryAdapter.ApplyPatch(const APatchText: string); begin raise EGitError.Create('not implemented'); end;
procedure TNativeRepositoryAdapter.CheckoutPaths(const ARevspec: string; const APaths: TStringArray); begin raise EGitError.Create('not implemented'); end;
function TNativeRepositoryAdapter.WorkdirPatchText(const ARevspec: string; const APaths: TStringArray; AShowBinary: Boolean): string; begin Result:=''; end;
function TNativeRepositoryAdapter.AddWorktree(const AName, APath, ARef: string; ADetach: Boolean): IGitWorktree; begin Result:=nil; raise EGitError.Create('not implemented'); end;
function TNativeRepositoryAdapter.LookupWorktree(const AName: string): IGitWorktree; begin Result:=nil; raise EGitError.Create('not implemented'); end;
function TNativeRepositoryAdapter.ListWorktrees: TStringArray; begin Result:=nil; end;
function TNativeRepositoryAdapter.PruneWorktree(const AName: string): Boolean; begin Result:=False; end;
function TNativeRepositoryAdapter.CommitOnHead(const AMessage: string; const AAuthorName, AAuthorEmail: string): string; begin Result:=''; end;

end.
