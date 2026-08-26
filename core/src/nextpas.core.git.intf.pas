unit nextpas.core.git.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.base,
  nextpas.core.git.base;

type
  // Optional authentication and certificate callbacks. Backends that cannot wire
  // them safely must report unsupported instead of silently ignoring handlers.
  TCredentialAcquireEvent = function(const Url, UserFromURL: string; AllowedTypes: Cardinal): Boolean of object;
  TCertificateCheckEvent = function(const Host: string; Valid: Boolean): Boolean of object;

  IGitCommit = interface;
  IGitReference = interface;
  IGitRemote = interface;
  IGitWorktree = interface;

  // Revwalk result: commits along parents, newest-first (caller holds refs)
  TGitCommitArray = array of IGitCommit;

  IGitRepository = interface
    ['{B3A3D3E7-7A20-4D59-8A71-1B8A4E2B2B6E}']
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
    // Optional: force checkout (overwrite working directory conflicts), default False
    function CheckoutBranchEx(const Branch: string; Force: Boolean): Boolean;


    // Simple list (compatible with old interface)
    function Status: TStringArray;
    // Detailed status and filtering
    function StatusEntries(const Filter: TGitStatusFilter): TGitStatusEntryArray;
    function IsClean: Boolean;
    function HasUncommittedChanges: Boolean;
  end;

  // Optional extended operations (implemented by the libgit2 adapter).
  // Keep these out of IGitRepository to preserve binary compatibility of the base interface.
  IGitRepositoryExt = interface
    ['{4E3F24A0-2F2B-4C62-8C9E-2C0D7E4A3A61}']
    function ListRemotes: TStringArray;
    function PullFastForward(const RemoteName: string; out Error: string): TGitPullFastForwardResult;
    // M5: diff between two revs (commit/branch/tag/hash; libgit2 revparse spec).
    // Unresolvable ref → EGitError. Returns files with hunks (empty hunks = no text delta).
    function Diff(const AOldRef, ANewRef: string): TGitDiff;
    // M5+（参数化，2026-08-15）：Diff 带 options（unified 上下文行数 / 路径过滤）。
    // 语义等同 Diff（向后兼容保留原签名）。
    function DiffEx(const AOldRef, ANewRef: string;
      const AOptions: TGitDiffOptions): TGitDiff;
    // M5: diff of a rev against the working tree + index (git diff <ref> semantics).
    function DiffWorkingTree(const ARef: string): TGitDiff;
    // M5+（参数化）：同上带 options。
    function DiffWorkingTreeEx(const ARef: string;
      const AOptions: TGitDiffOptions): TGitDiff;
    // M5: commit traversal from AStartRef along parents (topological + time order),
    // newest-first; ALimit <= 0 = unlimited. Unresolvable ref → EGitError.
    function RevWalk(const AStartRef: string; ALimit: Integer): TGitCommitArray;
    // M5+（2026-08-15）：blame 一个文件（经 libgit2 git_blame_file，不 spawn CLI）。
    // 返回逐 hunk 归属（commit id / 起止行 / 路径）；文件无提交历史 → 空 hunks。
    function Blame(const APath: string): TGitBlame;
    // k42（2026-08-20）：repo 本地配置条目快照（libgit2 git_repository_config +
    // 迭代器——include/includeIf/worktree config 由 libgit2 解析）。
    // 合并视图：local + worktree + global + system（同 git config --list 语义）。
    // 读取失败 → EGitError。
    function ConfigEntries: TGitConfigEntryArray;
    // k97: apply a unified-diff patch text to the working directory.
    // The buffer is parsed in full before the first file is written; a
    // failing hunk raises EGitError (partial writes possible — callers
    // wanting all-or-nothing semantics must snapshot touched files).
    procedure ApplyPatch(const APatch: string);
    // k97: force-restore the listed paths to their content at ASpec
    // (discard semantics; paths absent from ASpec are left untouched —
    // untracked removal stays the caller's job via status + fs).
    procedure CheckoutPaths(const ASpec: string; const APaths: TStringArray);
  end;

  IGitCommit = interface
    ['{5F1B0C6E-9E4C-4E67-9B83-21C0B7E676B7}']
    function Message: string;
    function ShortMessage: string;
    function AuthorString: string;  // "Name <email> time"
    function CommitterString: string;
    function Time: TDateTime;
    function ParentCount: Integer;
    function OIDString: string;     // 40-byte hex
    // M5: parent commit OID as 40-byte hex; '' when index out of range
    function ParentOIDString(AIndex: Integer): string;
  end;

  IGitReference = interface
    ['{0A8D4D72-9F56-4B1E-9C9B-3F3A0B7B98E1}']
    function Name: string;
    function ShortName: string;
    function TargetOIDString: string;
    function IsBranch: Boolean;
    function IsRemote: Boolean;
    function IsTag: Boolean;
  end;

  IGitRemote = interface
    ['{BE8C1C63-6F18-4A1A-8C8C-EA0E5B8F2E7A}']
    function Name: string;
    function URL: string;
    function Fetch: Boolean;
  end;

  IGitWorktree = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-EF1234567890}']
    function Name: string;
    function Path: string;
    function IsLocked: Boolean;
  end;

  IGitWorktreeExt = interface
    ['{A2B3C4D5-E6F7-8901-BCDE-F12345678901}']
    // Add a new worktree at the given path. Name must be unique. Ref is the
    // branch/commit/tag to base the worktree on; '' = HEAD. Detach = create a
    // detached HEAD worktree (no branch tracking).
    function AddWorktree(const AName, APath, ARef: string;
      ADetach: Boolean = False): IGitWorktree;
    function LookupWorktree(const AName: string): IGitWorktree;
    function ListWorktrees: TStringArray;
    // Prune (remove) a worktree's git metadata. Does NOT delete the working
    // directory files — caller must remove the directory separately.
    function PruneWorktree(const AName: string): Boolean;
    // Commit all staged changes in the index, creating a new commit on HEAD.
    // Author/Committer use the repository's default signature (or global config).
    function CommitOnHead(const AMessage: string;
      const AAuthorName, AAuthorEmail: string): string;
  end;

  IGitManager = interface
    ['{DECE8C92-7891-4831-A0C2-7D1A2FA8B9C1}']
    function Initialize: Boolean;
    procedure Finalize;

    function OpenRepository(const APath: string): IGitRepository;
    function CloneRepository(const AURL, ALocalPath: string): IGitRepository;
    function InitRepository(const APath: string; ABare: Boolean = False): IGitRepository;
    function IsRepository(const APath: string): Boolean;
    function DiscoverRepository(const AStartPath: string): string;

    function GetGlobalConfig(const AKey: string): string;
    function SetGlobalConfig(const AKey, AValue: string): Boolean;
    function Version: string;

    procedure SetVerifySSL(AEnabled: Boolean);
    procedure SetCredentialAcquireHandler(AHandler: TCredentialAcquireEvent);
    procedure SetCertificateCheckHandler(AHandler: TCertificateCheckEvent);

    function Initialized: Boolean;
    function VerifySSL: Boolean;
  end;

implementation

end.
