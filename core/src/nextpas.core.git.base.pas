unit nextpas.core.git.base;

{$I nextpas.core.settings.inc}

interface


type
  // High-level abstraction of branch types, avoiding direct exposure of libgit2 enums
  TGitBranchKind = (
    gbLocal,
    gbRemote,
    gbAll
  );

  // Note: TStringArray is already defined in SysUtils, no need to redefine

  // Pull fast-forward result (libgit2-first, CLI as fallback for merges)
  TGitPullFastForwardResult = (
    gpffUpToDate,
    gpffFastForwarded,
    gpffNeedsMerge,
    gpffNoRemote,
    gpffDetachedHead,
    gpffDirty,
    gpffError
  );

  // Status flags (high-level abstraction, avoiding direct exposure of libgit2 bitmasks)
  TGitStatusFlag = (
    gsIndexNew,
    gsIndexModified,
    gsIndexDeleted,
    gsIndexRenamed,
    gsIndexTypeChange,
    gsWtNew,
    gsWtModified,
    gsWtDeleted,
    gsWtTypeChange,
    gsWtRenamed,
    gsIgnored,
    gsConflicted
  );
  TGitStatusFlags = set of TGitStatusFlag;

  // Single status entry
  TGitStatusEntry = record
    Path: string;
    Flags: TGitStatusFlags;
  end;
  TGitStatusEntryArray = array of TGitStatusEntry;

  // Filter options
  TGitStatusFilter = record
    IncludeUntracked: Boolean;
    IncludeIgnored: Boolean;
    WorkingTreeOnly: Boolean;
    IndexOnly: Boolean;
  end;


implementation

end.
