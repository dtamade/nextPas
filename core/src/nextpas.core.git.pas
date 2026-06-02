unit nextpas.core.git;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.git.base,
  nextpas.core.git.intf,
  nextpas.core.git.libgit2;

type
  TGitBranchKind = nextpas.core.git.base.TGitBranchKind;
  TGitPullFastForwardResult = nextpas.core.git.base.TGitPullFastForwardResult;
  TGitStatusFlag = nextpas.core.git.base.TGitStatusFlag;
  TGitStatusFlags = nextpas.core.git.base.TGitStatusFlags;
  TGitStatusEntry = nextpas.core.git.base.TGitStatusEntry;
  TGitStatusEntryArray = nextpas.core.git.base.TGitStatusEntryArray;
  TGitStatusFilter = nextpas.core.git.base.TGitStatusFilter;

  TCredentialAcquireEvent = nextpas.core.git.intf.TCredentialAcquireEvent;
  TCertificateCheckEvent = nextpas.core.git.intf.TCertificateCheckEvent;
  IGitCommit = nextpas.core.git.intf.IGitCommit;
  IGitReference = nextpas.core.git.intf.IGitReference;
  IGitRemote = nextpas.core.git.intf.IGitRemote;
  IGitRepository = nextpas.core.git.intf.IGitRepository;
  IGitRepositoryExt = nextpas.core.git.intf.IGitRepositoryExt;
  IGitManager = nextpas.core.git.intf.IGitManager;
  EGitError = nextpas.core.git.libgit2.EGitError;

const
  gbLocal = nextpas.core.git.base.gbLocal;
  gbRemote = nextpas.core.git.base.gbRemote;
  gbAll = nextpas.core.git.base.gbAll;

  gpffUpToDate = nextpas.core.git.base.gpffUpToDate;
  gpffFastForwarded = nextpas.core.git.base.gpffFastForwarded;
  gpffNeedsMerge = nextpas.core.git.base.gpffNeedsMerge;
  gpffNoRemote = nextpas.core.git.base.gpffNoRemote;
  gpffDetachedHead = nextpas.core.git.base.gpffDetachedHead;
  gpffDirty = nextpas.core.git.base.gpffDirty;
  gpffError = nextpas.core.git.base.gpffError;

  gsIndexNew = nextpas.core.git.base.gsIndexNew;
  gsIndexModified = nextpas.core.git.base.gsIndexModified;
  gsIndexDeleted = nextpas.core.git.base.gsIndexDeleted;
  gsIndexRenamed = nextpas.core.git.base.gsIndexRenamed;
  gsIndexTypeChange = nextpas.core.git.base.gsIndexTypeChange;
  gsWtNew = nextpas.core.git.base.gsWtNew;
  gsWtModified = nextpas.core.git.base.gsWtModified;
  gsWtDeleted = nextpas.core.git.base.gsWtDeleted;
  gsWtTypeChange = nextpas.core.git.base.gsWtTypeChange;
  gsWtRenamed = nextpas.core.git.base.gsWtRenamed;
  gsIgnored = nextpas.core.git.base.gsIgnored;
  gsConflicted = nextpas.core.git.base.gsConflicted;

function NewGitManager: IGitManager; inline;

implementation

function NewGitManager: IGitManager;
begin
  Result := nextpas.core.git.libgit2.NewGitManager;
end;

end.
