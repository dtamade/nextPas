unit nextpas.core.git.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.base;

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

  // File-level diff status (mirrors git_delta_t values)
  TGitDiffStatus = (
    gdsUnmodified,
    gdsAdded,
    gdsDeleted,
    gdsModified,
    gdsRenamed,
    gdsCopied,
    gdsTypeChange,
    gdsUnreadable,
    gdsConflicted
  );

  // One unified-diff hunk: "@@ -OldStart,OldCount +NewStart,NewCount @@"
  TGitDiffHunk = record
    OldStart: Integer;
    OldCount: Integer;
    NewStart: Integer;
    NewCount: Integer;
    Header: string;          // hunk header text (without trailing newline)
    Lines: TStringArray;     // prefixed lines (' ', '+', '-')
  end;

  // One changed file (opencode File.Diff analog: status + add/del counts + hunks)
  TGitDiffFile = record
    OldPath: string;
    NewPath: string;
    Status: TGitDiffStatus;
    Additions: Integer;
    Deletions: Integer;
    Hunks: array of TGitDiffHunk;
  end;
  TGitDiffFileArray = array of TGitDiffFile;

  // Whole diff result (files in delta order)
  TGitDiff = record
    Files: TGitDiffFileArray;
  end;

implementation

end.
