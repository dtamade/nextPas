unit nextpas.core.git.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.text.base;

type
  EGitError = class(Exception)
  private
    FErrorCode: Integer;
    FErrorClass: Integer;
  public
    constructor Create(AErrorCode: Integer; const AOperation: string = ''); overload;
    property ErrorCode: Integer read FErrorCode;
    property ErrorClass: Integer read FErrorClass;
  end;

  // High-level abstraction of branch types, avoiding direct exposure of libgit2 enums
  TGitBranchKind = (
    gbLocal,
    gbRemote,
    gbAll
  );

  // TStringArray 来自 nextpas.core.text.base，无需重定义

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

  // Per-axis status code — single source via base (native + L2 facade reuse via bytes.ops inline zero-copy)
  // Native HeadCode/WorkCode and facade IndexStatus/WorkdirStatus share this vocab; alias via base eliminates dual track.
  TGitStatusCode = (
    gscUnmodified,
    gscAdded,       { in index, absent from HEAD }
    gscModified,    { content or permission bits changed, same kind }
    gscDeleted,     { present on one side, gone from the other }
    gscTypeChanged, { blob/symlink/gitlink kind flipped }
    gscUnmerged,    { conflict stages present in the index }
    gscUntracked,   { in worktree, absent from index }
    gscRenamed,     { paired delete+add with similarity >= threshold }
    gscCopied       { paired copy (source retained) }
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

  // Diff 参数化（M5 更深语义 2026-08-15）：unified 上下文行数 + 路径过滤
  TGitDiffOptions = record
    UnifiedLines: Integer;       // <=0 = libgit2 默认（3 行）
    InterhunkLines: Integer;     // <=0 = 默认（0）
    Paths: TStringArray;         // 空 = 全仓
  end;

  // One blame hunk: 一段连续行归属同一 commit
  TGitBlameHunk = record
    LinesInHunk: Integer;
    FinalCommitId: string;       // 40-hex
    FinalStartLine: Integer;     // 1-based（新文件行号）
    OrigCommitId: string;        // 40-hex
    OrigPath: string;
    OrigStartLine: Integer;      // 1-based（原始文件行号）
    Boundary: Boolean;           // 边界提交（超出可追溯历史）
  end;
  TGitBlameHunkArray = array of TGitBlameHunk;

  // Whole blame result: hunks 按行序（文件 → 归属 commit 映射线）
  TGitBlame = record
    Path: string;
    Hunks: TGitBlameHunkArray;
  end;

  // One repo configuration entry (k42): include-resolved merged view
  // (local + worktree + global + system, libgit2 config semantics).
  TGitConfigEntry = record
    Name: string;
    Value: string;
  end;
  TGitConfigEntryArray = array of TGitConfigEntry;

function GitStatusCodesToFlags(AHeadCode, AWorkCode: TGitStatusCode): TGitStatusFlags;

function DefaultGitDiffOptions: TGitDiffOptions; inline;

implementation

function GitStatusCodesToFlags(AHeadCode, AWorkCode: TGitStatusCode): TGitStatusFlags; inline;
begin
  // single source mapping HeadCode/WorkCode -> Flags (bytes.ops inline zero-copy set ops, no alloc)
  Result := [];
  case AHeadCode of
    gscAdded: Include(Result, gsIndexNew);
    gscModified: Include(Result, gsIndexModified);
    gscDeleted: Include(Result, gsIndexDeleted);
    gscRenamed: Include(Result, gsIndexRenamed);
    gscTypeChanged: Include(Result, gsIndexTypeChange);
    gscCopied: Include(Result, gsIndexRenamed);
    gscUnmerged: Include(Result, gsConflicted);
    gscUntracked: Include(Result, gsWtNew);
  end;
  case AWorkCode of
    gscAdded: Include(Result, gsWtNew);
    gscModified: Include(Result, gsWtModified);
    gscDeleted: Include(Result, gsWtDeleted);
    gscTypeChanged: Include(Result, gsWtTypeChange);
    gscRenamed: Include(Result, gsWtRenamed);
    gscCopied: Include(Result, gsWtRenamed);
    gscUnmerged: Include(Result, gsConflicted);
    gscUntracked: Include(Result, gsWtNew);
  end;
  if AWorkCode = gscUntracked then
    Include(Result, gsWtNew);
end;

constructor EGitError.Create(AErrorCode: Integer; const AOperation: string);
begin
  FErrorCode := AErrorCode;
  FErrorClass := 0;
  if AOperation <> '' then
    inherited Create(AOperation)
  else
    inherited CreateFmt('git error %d', [AErrorCode]);
end;

function DefaultGitDiffOptions: TGitDiffOptions; inline;
begin
  Result.UnifiedLines := 3;    { libgit2 默认 -U3，与无参 Diff 原行为一致 }
  Result.InterhunkLines := 0;
  Result.Paths := nil;
end;

end.
