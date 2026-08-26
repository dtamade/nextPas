unit nextpas.core.git.libgit2.backend;

{$I nextpas.core.settings.inc}

{
  Shared libgit2 backend core.

  This unit owns the concrete libgit2-backed classes and helpers that are
  reused by both:
  - nextpas.core.git.libgit2 (preferred interface adapter)
  - backend-specific consumers and compatibility shims
}

interface

uses
  nextpas.core.base, nextpas.core.text.conv, nextpas.core.time,
  nextpas.core.exception, nextpas.core.fs, nextpas.core.system.classes,
  nextpas.core.git.libgit2.ffi, nextpas.core.git.libgit2.binding,
  nextpas.core.git.base,
  nextpas.core.text.format;

type
  EGitError = class(Exception)
  private
    FErrorCode: Integer;
    FErrorClass: Integer;
  public
    constructor Create(AErrorCode: Integer; const AOperation: string = '');
    property ErrorCode: Integer read FErrorCode;
    property ErrorClass: Integer read FErrorClass;
  end;

  TGitOID = record
    Data: git_oid;
  end;

  TGitTime = record
    Time: TDateTime;
    Offset: Integer;
  end;

  TGitSignature = class
  private
    FName: string;
    FEmail: string;
    FWhen: TGitTime;
  public
    constructor Create(const AName, AEmail: string; const AWhen: TGitTime);
    constructor CreateNow(const AName, AEmail: string);
    function ToString: string; override;
    property Name: string read FName;
    property Email: string read FEmail;
    property When: TGitTime read FWhen;
  end;

  TGitRepository = class;
  TGitCommit = class;
  TGitReference = class;

  TGitRemote = class;

  // Backend-level commit list; the interface adapter (nextpas.core.git.libgit2)
  // wraps each entry into an IGitCommit array.
  TGitCommitList = array of TGitCommit;

  { M5+ (2026-08-15): pathspec 缓冲区数组（BuildDiffOptions 用，动态数组参数） }
  TPAnsiCharArray = array of PAnsiChar;

  TGitRepository = class
  private
    FHandle: git_repository;
    FPath: string;
    FWorkDir: string;
    procedure CheckResult(AResult: Integer; const AOperation: string = '');
    // M5 helpers: resolve revspec to tree; collect libgit2 diff into TGitDiff
    procedure ResolveRevToTree(const ASpec: string; out AObj: git_object; out ATree: git_tree);
    function CollectDiff(ADiff: git_diff): TGitDiff;
    // M5+ (2026-08-15): assemble git_diff_options from TGitDiffOptions
    procedure BuildDiffOptions(const AOptions: TGitDiffOptions;
      out LOpts: git_diff_options; var LPathStrs: TStringArray;
      var LPathPtrs: TPAnsiCharArray);
  public
    constructor Create(const APath: string);
    constructor Clone(const AURL, ALocalPath: string);
    destructor Destroy; override;

    function GetPath: string;
    function GetWorkDir: string;

    function GetHead: TGitReference;
    function GetReference(const AName: string): TGitReference;
    function GetCurrentBranch: string;
    function ListBranches(AType: git_branch_t = GIT_BRANCH_LOCAL): TStringArray;
    function ListRemotes: TStringArray;
    function CheckoutBranch(const ABranch: string): Boolean;
    function CheckoutBranchEx(const ABranch: string; const Force: Boolean): Boolean;

    // Status interface (simple and detailed)
    // Status: Returns simplified path string array (without flags)
    // StatusEntries: Returns entry array with flags. Filter meanings:
    //   - WorkingTreeOnly: Working tree changes only
    //   - IndexOnly: Index/staging area changes only
    //                (takes priority when mutually exclusive with WorkingTreeOnly)
    //   - IncludeUntracked: Whether to include untracked files
    //   - IncludeIgnored: Whether to include ignored files (affected by .gitignore)
    function Status: TStringArray;
    function StatusEntries(const Filter: TGitStatusFilter): TGitStatusEntryArray;
    function IsClean: Boolean;
    function IsBare: Boolean;
    function IsEmpty: Boolean;
    function HasUncommittedChanges: Boolean;

    function GetCommit(const AOID: TGitOID): TGitCommit;
    function GetHeadCommit: TGitCommit;
    function GetLastCommit: TGitCommit;

    // M5: diff / revwalk facade (libgit2-based)
    function Diff(const AOldRef, ANewRef: string): TGitDiff;
    function DiffEx(const AOldRef, ANewRef: string;
      const AOptions: TGitDiffOptions): TGitDiff;
    function DiffWorkingTree(const ARef: string): TGitDiff;
    function DiffWorkingTreeEx(const ARef: string;
      const AOptions: TGitDiffOptions): TGitDiff;
    function RevWalk(const AStartRef: string; ALimit: Integer): TGitCommitList;
    // M5+ (2026-08-15): blame a file (libgit2 native, no CLI spawn)
    function Blame(const APath: string): TGitBlame;
    // k42 (2026-08-20): repo config entry snapshot (include-resolved merged view)
    function ConfigEntries: TGitConfigEntryArray;
    // k97: apply unified patch text to the working directory (raises on
    // parse or hunk failure; partial writes possible — see intf comment)
    procedure ApplyPatch(const APatch: string);
    // k97: force-restore listed paths to their ASpec content (discard)
    procedure CheckoutPaths(const ASpec: string; const APaths: TStringArray);

    // Backward compatibility with old naming
    function HasUncommit: Boolean;

    function GetRemote(const AName: string): TGitRemote;
    function Fetch(const ARemoteName: string = 'origin'): Boolean;
    function PullFastForward(const ARemoteName: string; out AError: string): TGitPullFastForwardResult;

    property Path: string read GetPath;
    property WorkDir: string read GetWorkDir;
    function RawHandle: git_repository;
  end;
  TGitReference = class
  private
    FRepository: TGitRepository;
    FHandle: git_reference;
    FName: string;
    FShortName: string;
    FOID: TGitOID;
    FSymbolicTarget: string;
    FType: git_reference_t;
  public
    constructor Create(ARepository: TGitRepository; AHandle: git_reference);
    destructor Destroy; override;
    property Name: string read FName;
    property ShortName: string read FShortName;
    property OID: TGitOID read FOID;
    property SymbolicTarget: string read FSymbolicTarget;
    property RefType: git_reference_t read FType;
  end;


  TGitCommit = class
  private
    FRepository: TGitRepository;
    FOID: TGitOID;
    FHandle: git_commit;
    FMessage: string;
    FShortMessage: string;
    FAuthor: TGitSignature;
    FCommitter: TGitSignature;
    FTime: TDateTime;
    FParentCount: Integer;
    FLoaded: Boolean;
    procedure LoadData;
    function GetMessage: string;
    function GetShortMessage: string;
    function GetAuthor: TGitSignature;
    function GetCommitter: TGitSignature;
    function GetTime: TDateTime;
    function GetParentCount: Integer;
  public
    constructor Create(ARepository: TGitRepository; const AOID: TGitOID);
    destructor Destroy; override;
    procedure EnsureLoaded;
    property Message: string read GetMessage;
    property ShortMessage: string read GetShortMessage;
    property Author: TGitSignature read GetAuthor;
    property Committer: TGitSignature read GetCommitter;
    property Time: TDateTime read GetTime;
    property ParentCount: Integer read GetParentCount;
    property OID: TGitOID read FOID;
    // M5: parent commit OID as 40-byte hex; '' when index out of range
    function GetParentOIDString(AIndex: Integer): string;
  end;




  TGitRemote = class
  private
    FRepository: TGitRepository;
    FHandle: git_remote;
    FName: string;
    FURL: string;
  public
    constructor Create(ARepository: TGitRepository; AHandle: git_remote);
    destructor Destroy; override;
    function Fetch: Boolean;
    property Name: string read FName;
    property URL: string read FURL;
  end;

  TGitManager = class  // Legacy concrete class - use IGitManager from nextpas.core.git.intf for new code
  private
    FInitialized: Boolean;
    FVerifySSL: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function Initialize: Boolean;
    procedure Finalize;
    function OpenRepository(const APath: string): TGitRepository;
    function CloneRepository(const AURL, ALocalPath: string): TGitRepository;
    function InitRepository(const APath: string; ABare: Boolean = False): TGitRepository;
    function IsRepository(const APath: string): Boolean;
    function DiscoverRepository(const AStartPath: string): string;
    function GetGlobalConfig(const AKey: string): string;
    function SetGlobalConfig(const AKey, AValue: string): Boolean;
    procedure SetVerifySSL(AEnabled: Boolean);
    function GetVersion: string;
    property Initialized: Boolean read FInitialized;
    property VerifySSL: Boolean read FVerifySSL;
  end;

procedure CheckGitResult(AResult: Integer; const AOperation: string = '');
function GetGitErrorMessage: string;

function CreateGitOIDFromString(const AHashString: string): TGitOID;
function GitOIDToString(const AOID: TGitOID): string;
function GitOIDToShortString(const AOID: TGitOID): string;
function GitOIDEquals(const A, B: TGitOID): Boolean;
function IsGitOIDZero(const AOID: TGitOID): Boolean;
function CreateGitTimeFromGitTime(const AGitTime: git_time): TGitTime;
function GitTimeToString(const ATime: TGitTime): string;

implementation

uses
  nextpas.core.base.utils, nextpas.core.text.strings;

{ Local helpers replacing SysUtils functions to avoid TBytes/TStringArray conflicts }

function LocalLastDelimiter(const ADelimiter: Char; const S: string): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := Length(S) downto 1 do
    if S[i] = ADelimiter then
      Exit(i);
end;

function LocalExcludeTrailingPathDelimiter(const S: string): string;
begin
  Result := S;
  if (Length(Result) > 0) and (Result[Length(Result)] in ['/', '\']) then
    SetLength(Result, Length(Result) - 1);
end;

function LocalExpandFileName(const APath: string): string;
var
  Cwd: string;
begin
  if (Length(APath) > 0) and (APath[1] = '/') then
    Result := APath
  else
  begin
    {$I-}
    GetDir(0, Cwd);
    {$I+}
    if (Length(Cwd) > 0) and (Cwd[Length(Cwd)] <> '/') then
      Cwd := Cwd + '/';
    Result := Cwd + APath;
  end;
end;

function LocalExtractFileName(const APath: string): string;
var
  i: Integer;
begin
  for i := Length(APath) downto 1 do
    if APath[i] = '/' then
      Exit(Copy(APath, i + 1, MaxInt));
  Result := APath;
end;

function LocalExtractFileDir(const APath: string): string;
var
  i: Integer;
begin
  for i := Length(APath) downto 1 do
    if APath[i] = '/' then
      Exit(Copy(APath, 1, i - 1));
  Result := '';
end;

function LocalIncludeTrailingPathDelimiter(const S: string): string;
begin
  Result := S;
  if (Length(Result) = 0) or (Result[Length(Result)] <> '/') then
    Result := Result + '/';
end;


const
  GIT_REF_NAME_DELIMITER = '/';
  GIT_VERSION_UNKNOWN = '0.0.0';

type
  PStatusListPayload = ^TStatusListPayload;
  TStatusListPayload = record
    List: TStringArray;
  end;

  PGitStatusEntry = ^TGitStatusEntry;

  PStatusEntriesPayload = ^TStatusEntriesPayload;
  TStatusEntriesPayload = record
    Filter: TGitStatusFilter;
    Items: TList; // of PGitStatusEntry
  end;

function MapStatusFlags(AFlags: cuint): TGitStatusFlags;
begin
  Result := [];
  if (AFlags and GIT_STATUS_INDEX_NEW) <> 0 then Include(Result, gsIndexNew);
  if (AFlags and GIT_STATUS_INDEX_MODIFIED) <> 0 then Include(Result, gsIndexModified);
  if (AFlags and GIT_STATUS_INDEX_DELETED) <> 0 then Include(Result, gsIndexDeleted);
  if (AFlags and GIT_STATUS_INDEX_RENAMED) <> 0 then Include(Result, gsIndexRenamed);
  if (AFlags and GIT_STATUS_INDEX_TYPECHANGE) <> 0 then Include(Result, gsIndexTypeChange);
  if (AFlags and GIT_STATUS_WT_NEW) <> 0 then Include(Result, gsWtNew);
  if (AFlags and GIT_STATUS_WT_MODIFIED) <> 0 then Include(Result, gsWtModified);
  if (AFlags and GIT_STATUS_WT_DELETED) <> 0 then Include(Result, gsWtDeleted);
  if (AFlags and GIT_STATUS_WT_TYPECHANGE) <> 0 then Include(Result, gsWtTypeChange);
  if (AFlags and GIT_STATUS_WT_RENAMED) <> 0 then Include(Result, gsWtRenamed);
  if (AFlags and GIT_STATUS_IGNORED) <> 0 then Include(Result, gsIgnored);
  if (AFlags and GIT_STATUS_CONFLICTED) <> 0 then Include(Result, gsConflicted);
end;

function AcceptStatus(AFlags: cuint; const Filter: TGitStatusFilter): Boolean;
var
  LHasIndex, LHasWt, LIsUntracked, LIsIgnored, LIsConflicted: Boolean;
begin
  LHasIndex := (AFlags and (
    GIT_STATUS_INDEX_NEW or
    GIT_STATUS_INDEX_MODIFIED or
    GIT_STATUS_INDEX_DELETED or
    GIT_STATUS_INDEX_RENAMED or
    GIT_STATUS_INDEX_TYPECHANGE
  )) <> 0;
  LHasWt := (AFlags and (
    GIT_STATUS_WT_NEW or
    GIT_STATUS_WT_MODIFIED or
    GIT_STATUS_WT_DELETED or
    GIT_STATUS_WT_RENAMED or
    GIT_STATUS_WT_TYPECHANGE or
    GIT_STATUS_IGNORED
  )) <> 0;
  LIsUntracked := (AFlags and GIT_STATUS_WT_NEW) <> 0;
  LIsIgnored := (AFlags and GIT_STATUS_IGNORED) <> 0;
  LIsConflicted := (AFlags and GIT_STATUS_CONFLICTED) <> 0;
  if LIsConflicted then
  begin
    // Unmerged entries are visible from both index- and worktree-focused views.
    LHasIndex := True;
    LHasWt := True;
  end;
  if Filter.IndexOnly and not LHasIndex then Exit(False);
  if Filter.WorkingTreeOnly and not LHasWt then Exit(False);
  if (not Filter.IncludeUntracked) and LIsUntracked then Exit(False);
  if (not Filter.IncludeIgnored) and LIsIgnored then Exit(False);
  Result := (AFlags <> GIT_STATUS_CURRENT);
end;

function StatusListCb(const APath: PChar; AFlags: cuint; APayload: Pointer): cint; cdecl;
begin
  if (AFlags <> GIT_STATUS_CURRENT) and (APayload <> nil) then
    PStatusListPayload(APayload)^.List.Add(string(APath));
  Result := 0;
end;

function StatusEntriesCb(const APath: PChar; AFlags: cuint; APayload: Pointer): cint; cdecl;
var
  LP: PStatusEntriesPayload;
  LItem: PGitStatusEntry;
begin
  LP := PStatusEntriesPayload(APayload);
  if (LP <> nil) and AcceptStatus(AFlags, LP^.Filter) then
  begin
    New(LItem);
    LItem^.Path := string(APath);
    LItem^.Flags := MapStatusFlags(AFlags);
    LP^.Items.Add(LItem);
  end;
  Result := 0;
end;

procedure CheckGitResult(AResult: Integer; const AOperation: string);
begin
  if AResult <> GIT_OK then
    raise EGitError.Create(AResult, AOperation);
end;

function GetGitErrorMessage: string;
var
  Error: Pgit_error_t;
begin
  Error := git_error_last();
  if Assigned(Error) and Assigned(Error^.message) then
    Result := string(Error^.message)
  else
    Result := 'Unknown error';
end;

constructor EGitError.Create(AErrorCode: Integer; const AOperation: string);
var
  ErrorMsg: string;
begin
  FErrorCode := AErrorCode;
  FErrorClass := 0;
  ErrorMsg := GetGitErrorMessage;
  if AOperation <> '' then
    ErrorMsg := AOperation + ': ' + ErrorMsg;
  inherited Create(ErrorMsg);
end;

constructor TGitSignature.Create(const AName, AEmail: string; const AWhen: TGitTime);
begin
  inherited Create;
  FName := AName;
  FEmail := AEmail;
  FWhen := AWhen;
end;

constructor TGitSignature.CreateNow(const AName, AEmail: string);
var
  GitTime: git_time;
  Tm: TGitTime;
begin
  GitTime.time := DateTimeToUnix(DateTimeNow);
  GitTime.offset := 0;
  GitTime.sign := '+';
  Tm := CreateGitTimeFromGitTime(GitTime);
  inherited Create;
  FName := AName;
  FEmail := AEmail;
  FWhen := Tm;
end;

function TGitSignature.ToString: string;
begin
  Result := TextFormat('%s <%s> %s', [FName, FEmail, GitTimeToString(FWhen)]);
end;

function TGitRepository.CheckoutBranch(const ABranch: string): Boolean;
begin
  Result := CheckoutBranchEx(ABranch, False);
end;

function TGitRepository.CheckoutBranchEx(const ABranch: string; const Force: Boolean): Boolean;
var
  LRefName: string;
  LHeadRefName: string;
  TargetRef: git_reference;
  CreatedBranchRef: git_reference;
  TargetObj: git_object;
  CheckoutCommit: git_object;
  CheckoutTree: git_tree;
  CheckoutOpts: git_checkout_options;
  TargetOID: Pgit_oid;
  HeadTarget: Pgit_oid;
  LookupRC: cint;
  CreateLocalBranchFromRemote: Boolean;
  AllowForceRefresh: Boolean;
begin
  Result := False;
  TargetRef := nil;
  CreatedBranchRef := nil;
  TargetObj := nil;
  CheckoutCommit := nil;
  CheckoutTree := nil;
  try
    try
      if Trim(ABranch) = '' then Exit(False);
      CreateLocalBranchFromRemote := False;
      AllowForceRefresh := Force or IsClean;
      if Pos('refs/', ABranch) = 1 then
      begin
        LRefName := ABranch
      end
      else
      begin
        LRefName := 'refs/heads/' + ABranch;
        LookupRC := git_reference_lookup(TargetRef, FHandle, PChar(LRefName));
        if LookupRC <> GIT_OK then
        begin
          LRefName := 'refs/remotes/origin/' + ABranch;
          LookupRC := git_reference_lookup(TargetRef, FHandle, PChar(LRefName));
          if LookupRC = GIT_OK then
            CreateLocalBranchFromRemote := True
          else
          begin
            LRefName := 'refs/tags/' + ABranch;
            CheckGitResult(git_reference_lookup(TargetRef, FHandle, PChar(LRefName)),
              'Lookup reference ' + LRefName);
          end;
        end;
      end;

      if TargetRef = nil then
        CheckGitResult(git_reference_lookup(TargetRef, FHandle, PChar(LRefName)),
          'Lookup reference ' + LRefName);
      TargetOID := git_reference_target(TargetRef);
      if TargetOID = nil then
        Exit(False);

      CheckGitResult(git_object_lookup(TargetObj, FHandle, TargetOID, GIT_OBJECT_ANY),
        'Lookup checkout target ' + LRefName);

      case git_object_type(TargetObj) of
        GIT_OBJECT_COMMIT:
          CheckoutCommit := TargetObj;
        GIT_OBJECT_TAG:
          CheckGitResult(git_object_peel(CheckoutCommit, TargetObj, GIT_OBJECT_COMMIT),
            'Peel checkout target ' + LRefName);
      else
        Exit(False);
      end;

      CheckGitResult(git_commit_tree(CheckoutTree, git_commit(CheckoutCommit)),
        'Resolve checkout tree ' + LRefName);

      CheckoutOpts := Default(git_checkout_options);
      CheckGitResult(git_checkout_options_init(@CheckoutOpts, GIT_CHECKOUT_OPTIONS_VERSION), 'Init checkout options');
      if AllowForceRefresh then
        CheckoutOpts.checkout_strategy := GIT_CHECKOUT_FORCE or GIT_CHECKOUT_RECREATE_MISSING
      else
        CheckoutOpts.checkout_strategy := GIT_CHECKOUT_SAFE or GIT_CHECKOUT_RECREATE_MISSING;

      CheckGitResult(git_checkout_tree(FHandle, git_object(CheckoutTree), @CheckoutOpts),
        'Checkout tree ' + LRefName);

      if CreateLocalBranchFromRemote then
      begin
        LHeadRefName := 'refs/heads/' + ABranch;
        CheckGitResult(git_branch_create(CreatedBranchRef, FHandle, PChar(ABranch),
          git_commit(CheckoutCommit), Ord(Force)),
          'Create local branch ' + ABranch);
        CheckGitResult(git_repository_set_head(FHandle, PChar(LHeadRefName)),
          'Set HEAD to ' + LHeadRefName);
      end
      else if Pos('refs/heads/', LRefName) = 1 then
        CheckGitResult(git_repository_set_head(FHandle, PChar(LRefName)),
          'Set HEAD to ' + LRefName)
      else
      begin
        HeadTarget := git_object_id(CheckoutCommit);
        if HeadTarget = nil then
          Exit(False);
        CheckGitResult(git_repository_set_head_detached(FHandle, HeadTarget),
          'Detach HEAD at ' + LRefName);
      end;

      CheckGitResult(git_checkout_head(FHandle, @CheckoutOpts),
        'Refresh worktree for ' + LRefName);

      Result := True;
    except
      Result := False;
    end;
  finally
    if CreatedBranchRef <> nil then
      git_reference_free(CreatedBranchRef);
    if CheckoutTree <> nil then
      git_object_free(git_object(CheckoutTree));
    if (CheckoutCommit <> nil) and (CheckoutCommit <> TargetObj) then
      git_object_free(CheckoutCommit);
    if TargetObj <> nil then
      git_object_free(TargetObj);
    if TargetRef <> nil then
      git_reference_free(TargetRef);
  end;
end;

constructor TGitRepository.Create(const APath: string);
begin
  inherited Create;
  CheckResult(git_repository_open(FHandle, PChar(APath)), 'Open repository');
  FPath := APath;
  FWorkDir := string(git_repository_workdir(FHandle));
end;

constructor TGitRepository.Clone(const AURL, ALocalPath: string);
begin
  inherited Create;
  // Avoid passing clone options structs across nextpas.core.git.libgit2.ffi minor versions; use defaults.
  CheckResult(git_clone(FHandle, PChar(AURL), PChar(ALocalPath), nil), 'Clone repository');
  FPath := ALocalPath;
  FWorkDir := string(git_repository_workdir(FHandle));
end;

destructor TGitRepository.Destroy;
begin
  if Assigned(FHandle) then
    git_repository_free(FHandle);
  inherited Destroy;
end;

procedure TGitRepository.CheckResult(AResult: Integer; const AOperation: string);
begin
  if AResult <> GIT_OK then
    raise EGitError.Create(AResult, AOperation);
end;

function TGitRepository.GetPath: string;
begin
  if FPath = '' then
    FPath := string(git_repository_path(FHandle));
  Result := FPath;
end;

function TGitRepository.GetWorkDir: string;
begin
  if FWorkDir = '' then
    FWorkDir := string(git_repository_workdir(FHandle));
  Result := FWorkDir;
end;

function TGitRepository.RawHandle: git_repository;
begin
  Result := FHandle;
end;

function TGitRepository.GetHead: TGitReference;
var
  RefHandle: git_reference;
  rc: cint;
begin
  rc := git_repository_head(RefHandle, FHandle);
  if rc <> GIT_OK then
    raise EGitError.Create(rc, 'Get HEAD reference');
  Result := TGitReference.Create(Self, RefHandle);
end;

function TGitRepository.GetReference(const AName: string): TGitReference;
var
  RefHandle: git_reference;
begin
  CheckGitResult(git_reference_lookup(RefHandle, FHandle, PChar(AName)), 'Lookup reference');
  Result := TGitReference.Create(Self, RefHandle);
end;

function TGitRepository.GetCurrentBranch: string;
var
  RefHandle: git_reference;
  rc: cint;
  HeadRef: TGitReference;
begin
  // Try to get HEAD reference
  rc := git_repository_head(RefHandle, FHandle);

  // If repository is empty (no commits yet), return empty string
  if rc = GIT_EUNBORNBRANCH then
  begin
    Result := '';
    Exit;
  end;

  // If HEAD reference not found, return empty string
  if rc = GIT_ENOTFOUND then
  begin
    Result := '';
    Exit;
  end;

  // For other errors, raise exception
  if rc <> GIT_OK then
    raise EGitError.Create(rc, 'Get HEAD reference');

  // Get branch name from reference
  HeadRef := TGitReference.Create(Self, RefHandle);
  try
    Result := HeadRef.ShortName;
  finally
  end;
end;

function TGitRepository.ListBranches(AType: git_branch_t): TStringArray;
var
  Iterator: git_branch_iterator;
  RefHandle: git_reference;
  BranchType: git_branch_t;
  BranchName: string;
  List: TStringArray;
  rc: cint;
begin
  Result := nil;
  List := nil;
  try
    CheckGitResult(git_branch_iterator_new(Iterator, FHandle, AType), 'New branch iterator');
    try
      while True do
      begin
        rc := git_branch_next(RefHandle, BranchType, Iterator);
        if rc = GIT_ITEROVER then Break;
        if rc <> GIT_OK then
          raise EGitError.Create(rc, 'Iterate branches');
        BranchName := string(git_reference_name(RefHandle));
        List.Add(BranchName);
        git_reference_free(RefHandle);
      end;
    finally
      git_branch_iterator_free(Iterator);
    end;
    SetLength(Result, Length(List));
    if Length(List) > 0 then
      for rc := 0 to Length(List) - 1 do
        Result[rc] := List[rc];
  finally
  end;
end;

function TGitRepository.ListRemotes: TStringArray;
var
  Remotes: git_strarray;
  Count: SizeInt;
  i: SizeInt;
begin
  Result := nil;
  Remotes := Default(git_strarray);

  if git_remote_list(Remotes, FHandle) <> GIT_OK then
    Exit;

  try
    Count := SizeInt(Remotes.count);
    if Count <= 0 then
      Exit;
    SetLength(Result, Count);
    for i := 0 to Count - 1 do
      Result[i] := string(Remotes.strings[i]);
  finally
    git_strarray_free(@Remotes);
  end;
end;

function TGitRepository.GetCommit(const AOID: TGitOID): TGitCommit;
begin
  Result := TGitCommit.Create(Self, AOID);
end;

function TGitRepository.GetHeadCommit: TGitCommit;
var
  HeadRef: TGitReference;
begin
  HeadRef := GetHead;
  try
    Result := TGitCommit.Create(Self, HeadRef.OID);
  finally
    HeadRef.Free;
  end;
end;

function TGitRepository.GetLastCommit: TGitCommit;
begin
  Result := GetHeadCommit;
end;

function TGitRepository.Status: TStringArray;
var
  LP: TStatusListPayload;
begin
  { Callback mutates LP.List via SetLength/Add; return that array directly.
    Do not copy from a separate local: dynarray reallocation does not update
    sibling references that still point at the previous empty array. }
  LP.List := nil;
  CheckGitResult(git_status_foreach(FHandle, @StatusListCb, @LP), 'Status foreach');
  Result := LP.List;
end;

function TGitRepository.StatusEntries(const Filter: TGitStatusFilter): TGitStatusEntryArray;
var
  LP: TStatusEntriesPayload;
  LList: TList;
  i: Integer;
  LItem: PGitStatusEntry;
begin
  Result := nil;
  LList := TList.Create;
  try
    LP.Filter := Filter;
    LP.Items := LList;
    CheckGitResult(git_status_foreach(FHandle, @StatusEntriesCb, @LP), 'Status foreach');
    SetLength(Result, LList.Count);
    for i := 0 to LList.Count-1 do
    begin
      LItem := PGitStatusEntry(LList[i]);
      Result[i] := LItem^;
      Dispose(LItem);
      LList[i] := nil;
    end;
  finally
    for i := 0 to LList.Count - 1 do
      if LList[i] <> nil then
        Dispose(PGitStatusEntry(LList[i]));
  end;
  Exit; // keep function structure consistent
end;

function TGitRepository.IsClean: Boolean;
begin
  Result := Length(Status) = 0;
end;

function TGitRepository.HasUncommittedChanges: Boolean;
begin
  Result := not IsClean;
end;

function TGitRepository.HasUncommit: Boolean;
begin
  Result := HasUncommittedChanges;
end;

function TGitRepository.IsBare: Boolean;
begin
  Result := git_repository_is_bare(FHandle) <> 0;
end;

function TGitRepository.IsEmpty: Boolean;
begin
  Result := git_repository_is_empty(FHandle) <> 0;
end;

function TGitRepository.GetRemote(const AName: string): TGitRemote;
var
  RemoteHandle: git_remote;
begin
  CheckGitResult(git_remote_lookup(RemoteHandle, FHandle, PChar(AName)), 'Lookup remote');
  Result := TGitRemote.Create(Self, RemoteHandle);
end;

function TGitRepository.Fetch(const ARemoteName: string): Boolean;
var
  Remote: TGitRemote;
begin
  Result := False;
  Remote := GetRemote(ARemoteName);
  try
    Result := Remote.Fetch;
  finally
  end;
end;

function TGitRepository.PullFastForward(const ARemoteName: string; out AError: string): TGitPullFastForwardResult;
var
  Branch: string;
  LocalRefName: string;
  RemoteRefName: string;
  LocalRef: TGitReference;
  RemoteRef: TGitReference;
  Ahead: csize_t;
  Behind: csize_t;
  rc: cint;
  UpdatedRef: git_reference;
  CheckoutOpts: git_checkout_options;
  ErrorMsg: string;
begin
  Result := gpffError;
  AError := '';

  if Trim(ARemoteName) = '' then
  begin
    Result := gpffNoRemote;
    Exit;
  end;

  // For safety, refuse to update when working tree has local changes.
  if HasUncommittedChanges then
  begin
    Result := gpffDirty;
    Exit;
  end;

  Branch := GetCurrentBranch;
  if (Branch = '') or SameText(Branch, 'HEAD') then
  begin
    Result := gpffDetachedHead;
    Exit;
  end;

  // Fetch updates first.
  try
    if not Fetch(ARemoteName) then
    begin
      AError := GetGitErrorMessage;
      if AError = '' then
        AError := 'Fetch failed';
      Result := gpffError;
      Exit;
    end;
  except
    on E: Exception do
    begin
      AError := E.Message;
      Result := gpffNoRemote;
      Exit;
    end;
  end;

  LocalRefName := 'refs/heads/' + Branch;
  RemoteRefName := 'refs/remotes/' + ARemoteName + '/' + Branch;

  LocalRef := nil;
  RemoteRef := nil;
  try
    try
      LocalRef := GetReference(LocalRefName);
    except
      on E: Exception do
      begin
        AError := E.Message;
        Result := gpffError;
        Exit;
      end;
    end;

    try
      RemoteRef := GetReference(RemoteRefName);
    except
      on E: Exception do
      begin
        AError := E.Message;
        Result := gpffError;
        Exit;
      end;
    end;

    Ahead := 0;
    Behind := 0;
    rc := git_graph_ahead_behind(Ahead, Behind, FHandle, @LocalRef.FOID.Data, @RemoteRef.FOID.Data);
    if rc <> GIT_OK then
    begin
      AError := GetGitErrorMessage;
      Result := gpffError;
      Exit;
    end;

    if (Ahead = 0) and (Behind = 0) then
    begin
      Result := gpffUpToDate;
      Exit;
    end;

    if (Ahead = 0) and (Behind > 0) then
    begin
      UpdatedRef := nil;
      rc := git_reference_set_target(UpdatedRef, LocalRef.FHandle, @RemoteRef.FOID.Data, PChar('fpdev fast-forward'));
      if rc <> GIT_OK then
      begin
        AError := GetGitErrorMessage;
        Result := gpffError;
        Exit;
      end;

      if Assigned(UpdatedRef) then
        git_reference_free(UpdatedRef);

      // Update working directory to the new HEAD.
      CheckoutOpts := Default(git_checkout_options);
      rc := git_checkout_options_init(@CheckoutOpts, GIT_CHECKOUT_OPTIONS_VERSION);
      if rc <> GIT_OK then
      begin
        AError := GetGitErrorMessage;
        Result := gpffError;
        Exit;
      end;

      CheckoutOpts.checkout_strategy :=
        GIT_CHECKOUT_FORCE or
        GIT_CHECKOUT_RECREATE_MISSING or
        GIT_CHECKOUT_REMOVE_UNTRACKED;
      rc := git_checkout_head(FHandle, @CheckoutOpts);
      if rc <> GIT_OK then
      begin
        AError := GetGitErrorMessage;
        Result := gpffError;
        Exit;
      end;

      Result := gpffFastForwarded;
      Exit;
    end;

    // Diverged or ahead: requires merge/rebase (handled by CLI fallback in higher layer).
    Result := gpffNeedsMerge;
  finally
    if Assigned(RemoteRef) then
    if Assigned(LocalRef) then
  end;

  // Keep compiler happy about unreachable warnings in some configurations
  if Result = gpffError then
  begin
    ErrorMsg := AError;
    if ErrorMsg = '' then;
  end;
end;

constructor TGitCommit.Create(ARepository: TGitRepository; const AOID: TGitOID);
begin
  inherited Create;
  FRepository := ARepository;
  FOID := AOID;
  FLoaded := False;
end;

destructor TGitCommit.Destroy;
begin
  if Assigned(FAuthor) then FreeAndNil(FAuthor);
  if Assigned(FCommitter) then FreeAndNil(FCommitter);
  if Assigned(FHandle) then
    git_object_free(FHandle);
  inherited Destroy;
end;

procedure TGitCommit.EnsureLoaded;
begin
  LoadData;
end;

function TGitCommit.GetMessage: string;
begin
  EnsureLoaded;
  Result := FMessage;
end;

function TGitCommit.GetShortMessage: string;
begin
  EnsureLoaded;
  Result := FShortMessage;
end;

function TGitCommit.GetAuthor: TGitSignature;
begin
  EnsureLoaded;
  Result := FAuthor;
end;

function TGitCommit.GetCommitter: TGitSignature;
begin
  EnsureLoaded;
  Result := FCommitter;
end;

function TGitCommit.GetTime: TDateTime;
begin
  EnsureLoaded;
  Result := FTime;
end;

function TGitCommit.GetParentCount: Integer;
begin
  EnsureLoaded;
  Result := FParentCount;
end;

procedure TGitCommit.LoadData;
var
  Obj: git_object;
  CommitterSig, AuthorSig: Pgit_signature_t;
  CommitTime: git_time_t;
  AuthorTime, CommitterTime: TGitTime;
begin
  if FLoaded then Exit;
  CheckGitResult(git_object_lookup(Obj, FRepository.FHandle, @FOID.Data, GIT_OBJECT_COMMIT), 'Lookup object');
  try
    FHandle := git_commit(Obj);
    FMessage := string(git_commit_message(FHandle));
    FShortMessage := Trim(Copy(FMessage, 1, Pos(LineEnding, FMessage + LineEnding) - 1));

    CommitterSig := git_commit_committer(FHandle);
    if Assigned(CommitterSig) then
    begin
      CommitterTime := CreateGitTimeFromGitTime(CommitterSig^.when);
      FCommitter := TGitSignature.Create(string(CommitterSig^.name), string(CommitterSig^.email), CommitterTime);
    end;

    AuthorSig := git_commit_author(FHandle);
    if Assigned(AuthorSig) then
    begin
      AuthorTime := CreateGitTimeFromGitTime(AuthorSig^.when);
      FAuthor := TGitSignature.Create(string(AuthorSig^.name), string(AuthorSig^.email), AuthorTime);
    end;

    CommitTime := git_commit_time(FHandle);
    FTime := UnixToDateTime(CommitTime);

    FParentCount := git_commit_parentcount(FHandle);

    FLoaded := True;
  finally
    // Obj freed together with commit
  end;
end;

constructor TGitReference.Create(ARepository: TGitRepository; AHandle: git_reference);
begin
  inherited Create;
  FRepository := ARepository;
  FHandle := AHandle;
  FName := string(git_reference_name(AHandle));
  FType := git_reference_type(AHandle);
  if FType = GIT_REFERENCE_DIRECT then
  begin
    FOID.Data := git_reference_target(AHandle)^;
    FShortName := Copy(
      FName, LocalLastDelimiter(GIT_REF_NAME_DELIMITER, FName) + 1, MaxInt
    );
  end
  else
  begin
    FSymbolicTarget := string(git_reference_symbolic_target(AHandle));
    FShortName := Copy(
      FSymbolicTarget,
      LocalLastDelimiter(GIT_REF_NAME_DELIMITER, FSymbolicTarget) + 1,
      MaxInt
    );
  end;
end;

destructor TGitReference.Destroy;
begin
  if Assigned(FHandle) then
    git_reference_free(FHandle);
  inherited Destroy;
end;

constructor TGitRemote.Create(ARepository: TGitRepository; AHandle: git_remote);
begin
  inherited Create;
  FRepository := ARepository;
  FHandle := AHandle;
  FName := string(git_remote_name(AHandle));
  FURL := string(git_remote_url(AHandle));
end;

destructor TGitRemote.Destroy;
begin
  if Assigned(FHandle) then
    git_remote_free(FHandle);
  inherited Destroy;
end;

function TGitRemote.Fetch: Boolean;
begin
  try
    // Avoid passing fetch options structs across nextpas.core.git.libgit2.ffi minor versions; use defaults.
    Result := git_remote_fetch(FHandle, nil, nil, nil) = GIT_OK;
  except
    Result := False;
  end;
end;

constructor TGitManager.Create;
begin
  inherited Create;
  FInitialized := False;
end;

destructor TGitManager.Destroy;
begin
  if FInitialized then
    Finalize;
  inherited Destroy;
end;

function TGitManager.Initialize: Boolean;
begin
  if FInitialized then
    Exit(True);
  try
    Result := git_libgit2_init >= 0;
    if Result then
      FInitialized := True
    else
      Result := False;
  except
    Result := False;
  end;
end;

procedure TGitManager.Finalize;
begin
  if FInitialized then
  begin
    git_libgit2_shutdown;
    FInitialized := False;
  end;
end;

function TGitManager.OpenRepository(const APath: string): TGitRepository;
begin
  if not FInitialized then
    Initialize;
  Result := TGitRepository.Create(APath);
end;

function TGitManager.CloneRepository(const AURL, ALocalPath: string): TGitRepository;
begin
  if not FInitialized then
    Initialize;
  Result := TGitRepository.Clone(AURL, ALocalPath);
end;

function TGitManager.InitRepository(const APath: string; ABare: Boolean): TGitRepository;
var
  RepoHandle: git_repository;
begin
  if not FInitialized then
    Initialize;
  CheckGitResult(git_repository_init(RepoHandle, PChar(APath), Ord(ABare)), 'Initialize repository');
  git_repository_free(RepoHandle);
  Result := TGitRepository.Create(APath);
end;

function TGitManager.IsRepository(const APath: string): Boolean;
var
  RepoHandle: git_repository;
begin
  if not FInitialized then
    Initialize;
  Result := git_repository_open(RepoHandle, PChar(APath)) = GIT_OK;
  if Result then
    git_repository_free(RepoHandle);
end;

function TGitManager.DiscoverRepository(const AStartPath: string): string;
var
  LPath, LPrev: string;
  LBuf: git_buf;
  LRawPath: string;
  LRepoHandle: git_repository;
  LWorkDir: PChar;
begin
  if not FInitialized then
    Initialize;

  LBuf := Default(git_buf);
  try
    if (git_repository_discover(LBuf, PChar(AStartPath), 0, nil) = GIT_OK) and
       (LBuf.ptr <> nil) then
    begin
      LRawPath := LocalExcludeTrailingPathDelimiter(LocalExpandFileName(string(LBuf.ptr)));
      LRepoHandle := nil;
      if git_repository_open(LRepoHandle, PChar(LRawPath)) = GIT_OK then
      begin
        try
          LWorkDir := git_repository_workdir(LRepoHandle);
          if LWorkDir <> nil then
            Exit(LocalExcludeTrailingPathDelimiter(LocalExpandFileName(string(LWorkDir))));
        finally
          git_repository_free(LRepoHandle);
        end;
      end;
      if SameText(LocalExtractFileName(LRawPath), '.git') then
        Exit(LocalExtractFileDir(LRawPath));
      Exit(LRawPath);
    end;
  finally
    git_buf_dispose(@LBuf);
  end;

  Result := '';
  LPath := LocalExpandFileName(AStartPath);
  LPrev := '';
  while (LPath <> '') and (LPath <> LPrev) do
  begin
    if DirectoryExists(LocalIncludeTrailingPathDelimiter(LPath) + '.git') then
      Exit(LPath);
    LPrev := LPath;
    LPath := LocalExtractFileDir(LPath);
  end;
end;

function TGitManager.GetGlobalConfig(const AKey: string): string;
var
  Config: git_config;
  Value: PChar;
begin
  if not FInitialized then
    Initialize;
  if git_config_open_default(Config) = GIT_OK then
  try
    if git_config_get_string(Value, Config, PChar(AKey)) = GIT_OK then
      Result := string(Value)
    else
      Result := '';
  finally
    git_config_free(Config);
  end
  else
    Result := '';
end;

function TGitManager.SetGlobalConfig(const AKey, AValue: string): Boolean;
var
  Config: git_config;
begin
  if not FInitialized then
    Initialize;
  Result := False;
  if git_config_open_default(Config) = GIT_OK then
  try
    Result := git_config_set_string(Config, PChar(AKey), PChar(AValue)) = GIT_OK;
  finally
    git_config_free(Config);
  end;
end;

procedure TGitManager.SetVerifySSL(AEnabled: Boolean);
var
  Cfg: git_config;
  Val: PChar;
begin
  FVerifySSL := AEnabled;
  if not FInitialized then
    Initialize;
  if git_config_open_default(Cfg) = GIT_OK then
  try
    if AEnabled then Val := 'true' else Val := 'false';
    git_config_set_string(Cfg, 'http.sslVerify', Val);
  finally
    git_config_free(Cfg);
  end;
end;

function TGitManager.GetVersion: string;
var
  Major, Minor, Rev: cint;
begin
  Major := 0; Minor := 0; Rev := 0;
  if not FInitialized then
    Initialize;
  if git_libgit2_version(@Major, @Minor, @Rev) = GIT_OK then
    Result := TextFormat('%d.%d.%d', [Major, Minor, Rev])
  else
    Result := GIT_VERSION_UNKNOWN;
end;

function CreateGitOIDFromString(const AHashString: string): TGitOID;
begin
  CheckGitResult(git_oid_fromstr(Result.Data, PChar(AHashString)), 'Parse OID from string');
end;

function GitOIDToString(const AOID: TGitOID): string;
const
  Hex: PChar = '0123456789abcdef';
var
  i: Integer;
  s: string;
begin
  s := '';
  SetLength(s, 40);
  for i := 0 to 19 do
  begin
    s[i*2+1] := Hex[(AOID.Data.id[i] shr 4) and $F];
    s[i*2+2] := Hex[AOID.Data.id[i] and $F];
  end;
  Result := s;
end;

function GitOIDToShortString(const AOID: TGitOID): string;
const
  Hex: PChar = '0123456789abcdef';
var
  i: Integer;
  s: string;
begin
  s := '';
  SetLength(s, 7);
  for i := 0 to 2 do
  begin
    s[i*2+1] := Hex[(AOID.Data.id[i] shr 4) and $F];
    s[i*2+2] := Hex[AOID.Data.id[i] and $F];
  end;
  s[7] := Hex[(AOID.Data.id[3] shr 4) and $F];
  Result := s;
end;

function GitOIDEquals(const A, B: TGitOID): Boolean;
begin
  Result := git_oid_equal(@A.Data, @B.Data) <> 0;
end;

function IsGitOIDZero(const AOID: TGitOID): Boolean;
begin
  Result := git_oid_iszero(@AOID.Data) <> 0;
end;

function CreateGitTimeFromGitTime(const AGitTime: git_time): TGitTime;
begin
  Result.Time := UnixToDateTime(AGitTime.time);
  Result.Offset := AGitTime.offset;
end;

function GitTimeToString(const ATime: TGitTime): string;
var
  LHours, LMins: Integer;
  LSign: Char;
begin
  { TextFormat does not support the %+ width form used by SysUtils Format.
    Emit timezone offset as +HHMM / -HHMM with zero-padded fields. }
  Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', ATime.Time);
  LHours := ATime.Offset div 60;
  LMins := Abs(ATime.Offset) mod 60;
  if ATime.Offset >= 0 then
    LSign := '+'
  else
    LSign := '-';
  Result := Result + ' ' + LSign + TextFormat('%.2d%.2d', [Abs(LHours), LMins]);
end;

{ M5: diff / revwalk implementations }

procedure TGitRepository.ResolveRevToTree(const ASpec: string; out AObj: git_object; out ATree: git_tree);
begin
  AObj := nil;
  ATree := nil;
  if ASpec = '' then
    raise EGitError.Create(GIT_ENOTFOUND, 'Resolve revspec (empty)');
  CheckResult(git_revparse_single(AObj, FHandle, PChar(ASpec)), 'Resolve revspec ' + ASpec);
  try
    // git_object_peel yields a borrowed-into-new reference; caller frees both.
    CheckResult(git_object_peel(ATree, AObj, GIT_OBJECT_TREE), 'Peel revspec to tree');
  except
    git_object_free(AObj);
    AObj := nil;
    raise;
  end;
end;

function TGitRepository.CollectDiff(ADiff: git_diff): TGitDiff;
var
  LDeltaCount, I, J, K: Integer;
  LDelta: Pgit_diff_delta_t;
  LPatch: git_patch;
  LHunkCount, LLineCount, LLen: csize_t;
  LHunk: Pgit_diff_hunk;
  LLine: Pgit_diff_line;
  LFile: TGitDiffFile;
  LH: TGitDiffHunk;
begin
  Result.Files := nil;
  LDeltaCount := git_diff_num_deltas(ADiff);
  SetLength(Result.Files, LDeltaCount);
  for I := 0 to LDeltaCount - 1 do
  begin
    LDelta := git_diff_get_delta(ADiff, I);
    LFile.OldPath := string(LDelta^.old_file.path);
    LFile.NewPath := string(LDelta^.new_file.path);
    LFile.Status := TGitDiffStatus(LDelta^.status);
    LFile.Additions := 0;
    LFile.Deletions := 0;
    LFile.Hunks := nil;
    if git_patch_from_diff(LPatch, ADiff, I) = GIT_OK then
    begin
      try
        LHunkCount := git_patch_num_hunks(LPatch);
        SetLength(LFile.Hunks, LHunkCount);
        for J := 0 to LHunkCount - 1 do
        begin
          if git_patch_get_hunk(LHunk, LLineCount, LPatch, J) <> GIT_OK then
            Continue;
          LH.OldStart := LHunk^.old_start;
          LH.OldCount := LHunk^.old_lines;
          LH.NewStart := LHunk^.new_start;
          LH.NewCount := LHunk^.new_lines;
          SetLength(LH.Header, LHunk^.header_len);
          if LHunk^.header_len > 0 then
            Move(LHunk^.header[0], LH.Header[1], LHunk^.header_len);
          SetLength(LH.Lines, LLineCount);
          for K := 0 to LLineCount - 1 do
          begin
            if git_patch_get_line_in_hunk(LLine, LPatch, J, K) <> GIT_OK then
              Continue;
            LLen := LLine^.content_len;
            SetLength(LH.Lines[K], LLen + 1);
            if LLen > 0 then
              Move(LLine^.content^, LH.Lines[K][2], LLen);
            LH.Lines[K][1] := Char(LLine^.origin);
            case LLine^.origin of
              '+': Inc(LFile.Additions);
              '-': Inc(LFile.Deletions);
            end;
          end;
          LFile.Hunks[J] := LH;
        end;
      finally
        git_patch_free(LPatch);
      end;
    end;
    Result.Files[I] := LFile;
  end;
end;

procedure TGitRepository.BuildDiffOptions(const AOptions: TGitDiffOptions;
  out LOpts: git_diff_options; var LPathStrs: TStringArray;
  var LPathPtrs: TPAnsiCharArray);
var
  I: Integer;
begin
  FillChar(LOpts, SizeOf(LOpts), 0);
  LOpts.version := 1;   { GIT_DIFF_OPTIONS_VERSION }
  if AOptions.UnifiedLines > 0 then
    LOpts.context_lines := cuint(AOptions.UnifiedLines);
  if AOptions.InterhunkLines > 0 then
    LOpts.interhunk_lines := cuint(AOptions.InterhunkLines);
  SetLength(LPathPtrs, Length(AOptions.Paths));
  SetLength(LPathStrs, Length(AOptions.Paths));
  for I := 0 to High(AOptions.Paths) do
  begin
    LPathStrs[I] := AOptions.Paths[I];
    LPathPtrs[I] := PAnsiChar(LPathStrs[I]);
  end;
  if Length(LPathPtrs) > 0 then
  begin
    LOpts.pathspec.strings := PPChar(@LPathPtrs[0]);
    LOpts.pathspec.count := csize_t(Length(LPathPtrs));
  end;
end;

function TGitRepository.Diff(const AOldRef, ANewRef: string): TGitDiff;
begin
  Result := DiffEx(AOldRef, ANewRef, DefaultGitDiffOptions);
end;

function TGitRepository.DiffEx(const AOldRef, ANewRef: string;
  const AOptions: TGitDiffOptions): TGitDiff;
var
  LOldObj, LNewObj: git_object;
  LOldTree, LNewTree: git_tree;
  LDiff: git_diff;
  LOpts: git_diff_options;
  LPathStrs: TStringArray;
  LPathPtrs: TPAnsiCharArray;
begin
  Result.Files := nil;
  ResolveRevToTree(AOldRef, LOldObj, LOldTree);
  try
    ResolveRevToTree(ANewRef, LNewObj, LNewTree);
    try
      BuildDiffOptions(AOptions, LOpts, LPathStrs, LPathPtrs);
      CheckResult(git_diff_tree_to_tree(LDiff, FHandle, LOldTree, LNewTree,
        @LOpts), 'Diff trees');
      try
        Result := CollectDiff(LDiff);
      finally
        git_diff_free(LDiff);
      end;
    finally
      git_object_free(LNewObj);
      git_tree_free(LNewTree);
    end;
  finally
    git_object_free(LOldObj);
    git_tree_free(LOldTree);
  end;
end;

function TGitRepository.DiffWorkingTree(const ARef: string): TGitDiff;
begin
  Result := DiffWorkingTreeEx(ARef, DefaultGitDiffOptions);
end;

function TGitRepository.DiffWorkingTreeEx(const ARef: string;
  const AOptions: TGitDiffOptions): TGitDiff;
var
  LObj: git_object;
  LTree: git_tree;
  LDiff: git_diff;
  LOpts: git_diff_options;
  LPathStrs: TStringArray;
  LPathPtrs: TPAnsiCharArray;
begin
  Result.Files := nil;
  ResolveRevToTree(ARef, LObj, LTree);
  try
    BuildDiffOptions(AOptions, LOpts, LPathStrs, LPathPtrs);
    CheckResult(git_diff_tree_to_workdir_with_index(LDiff, FHandle, LTree,
      @LOpts), 'Diff tree to workdir');
    try
      Result := CollectDiff(LDiff);
    finally
      git_diff_free(LDiff);
    end;
  finally
    git_object_free(LObj);
    git_tree_free(LTree);
  end;
end;

{ k97: apply / pathspec checkout }

procedure TGitRepository.ApplyPatch(const APatch: string);
var
  LDiff: git_diff;
begin
  if APatch = '' then
    raise EGitError.Create(GIT_EINVALID, 'ApplyPatch: empty patch');
  { full-buffer parse first: a malformed patch fails before any write }
  CheckResult(git_diff_from_buffer(LDiff, PChar(APatch),
    csize_t(System.Length(APatch))), 'Parse patch buffer');
  try
    CheckResult(git_apply(FHandle, LDiff, GIT_APPLY_LOCATION_WORKING_DIR,
      nil), 'Apply patch');
  finally
    git_diff_free(LDiff);
  end;
end;

procedure TGitRepository.CheckoutPaths(const ASpec: string;
  const APaths: TStringArray);
var
  LObj: git_object;
  LTree: git_tree;
  LOpts: git_checkout_options;
  LPathStrs: TStringArray;
  LPathPtrs: TPAnsiCharArray;
  I: Integer;
begin
  if System.Length(APaths) = 0 then
    raise EGitError.Create(GIT_EINVALID, 'CheckoutPaths: empty pathspec');
  ResolveRevToTree(ASpec, LObj, LTree);
  try
    LOpts := Default(git_checkout_options);
    CheckResult(git_checkout_options_init(@LOpts,
      GIT_CHECKOUT_OPTIONS_VERSION), 'Init checkout options');
    LOpts.checkout_strategy := GIT_CHECKOUT_FORCE or GIT_CHECKOUT_RECREATE_MISSING;
    SetLength(LPathStrs, System.Length(APaths));
    SetLength(LPathPtrs, System.Length(APaths));
    for I := 0 to High(APaths) do
    begin
      LPathStrs[I] := APaths[I];
      LPathPtrs[I] := PAnsiChar(LPathStrs[I]);
    end;
    LOpts.paths.strings := PPChar(@LPathPtrs[0]);
    LOpts.paths.count := csize_t(System.Length(LPathPtrs));
    CheckResult(git_checkout_tree(FHandle, git_object(LTree), @LOpts),
      'Checkout paths from ' + ASpec);
  finally
    git_tree_free(LTree);
    git_object_free(LObj);
  end;
end;

function TGitRepository.Blame(const APath: string): TGitBlame;
var
  LBlame: git_blame;
  LOpts: git_blame_options;
  LHunk: Pgit_blame_hunk;
  LCount, I: cardinal;
  LOut: TGitBlame;
  LOID: TGitOID;
begin
  Result.Path := APath;
  Result.Hunks := nil;
  if APath = '' then
    Exit;
  FillChar(LOpts, SizeOf(LOpts), 0);
  LOpts.version := 1;   { GIT_BLAME_OPTIONS_VERSION }
  LOut.Hunks := nil;
  if git_blame_file(LBlame, FHandle, PAnsiChar(APath), @LOpts) <> GIT_OK then
    Exit;               { 无历史/路径不存在 → 空 hunks（非异常） }
  try
    LCount := git_blame_get_hunk_count(LBlame);
    if LCount = 0 then
      Exit;
    SetLength(LOut.Hunks, LCount);
    for I := 0 to LCount - 1 do
    begin
      LHunk := git_blame_get_hunk_byindex(LBlame, I);
      if LHunk = nil then
        Continue;
      LOut.Hunks[I].LinesInHunk := Integer(LHunk^.lines_in_hunk);
      LOut.Hunks[I].FinalStartLine := Integer(LHunk^.final_start_line_number);
      LOut.Hunks[I].OrigStartLine := Integer(LHunk^.orig_start_line_number);
      if LHunk^.orig_path <> nil then
        LOut.Hunks[I].OrigPath := string(LHunk^.orig_path);
      LOID.Data := LHunk^.final_commit_id;
      LOut.Hunks[I].FinalCommitId := GitOIDToString(LOID);
      LOID.Data := LHunk^.orig_commit_id;
      LOut.Hunks[I].OrigCommitId := GitOIDToString(LOID);
      LOut.Hunks[I].Boundary := LHunk^.boundary <> #0;
    end;
    Result.Hunks := LOut.Hunks;
  finally
    git_blame_free(LBlame);
  end;
end;

function TGitRepository.ConfigEntries: TGitConfigEntryArray;
var
  Cfg: git_config;
  Iter: git_config_iterator;
  LEntry: Pgit_config_entry;
  rc: cint;
  N: Integer;
begin
  Result := nil;
  CheckGitResult(git_repository_config(Cfg, FHandle), 'Open repository config');
  try
    CheckGitResult(git_config_iterator_new(Iter, Cfg), 'New config iterator');
    try
      N := 0;
      while True do
      begin
        rc := git_config_next(LEntry, Iter);
        if rc = GIT_ITEROVER then
          Break;
        if rc <> GIT_OK then
          raise EGitError.Create(rc, 'Iterate config entries');
        if LEntry <> nil then
        begin
          SetLength(Result, N + 1);
          if LEntry^.name <> nil then
            Result[N].Name := string(LEntry^.name);
          if LEntry^.value <> nil then
            Result[N].Value := string(LEntry^.value);
          Inc(N);
        end;
      end;
    finally
      git_config_iterator_free(Iter);
    end;
  finally
    git_config_free(Cfg);
  end;
end;

function TGitRepository.RevWalk(const AStartRef: string; ALimit: Integer): TGitCommitList;
var
  LWalk: git_revwalk;
  LOID: git_oid;
  LObj: git_object;
  LCommitOID: TGitOID;
  rc: cint;
  LCommits: TGitCommitList;
begin
  Result := nil;
  CheckResult(git_revwalk_new(LWalk, FHandle), 'Create revwalk');
  try
    CheckResult(git_revwalk_sorting(LWalk, GIT_SORT_TOPOLOGICAL or GIT_SORT_TIME), 'Set revwalk sorting');
    if AStartRef = '' then
      CheckResult(git_revwalk_push_head(LWalk), 'Push HEAD to revwalk')
    else
    begin
      CheckResult(git_revparse_single(LObj, FHandle, PChar(AStartRef)), 'Resolve revwalk start ' + AStartRef);
      try
        CheckResult(git_revwalk_push(LWalk, git_object_id(LObj)), 'Push revwalk start');
      finally
        git_object_free(LObj);
      end;
    end;
    LCommits := nil;
    while True do
    begin
      rc := git_revwalk_next(LOID, LWalk);
      if rc = GIT_ITEROVER then Break;
      if rc <> GIT_OK then
        raise EGitError.Create(rc, 'Iterate revwalk');
      LCommitOID.Data := LOID;
      SetLength(LCommits, Length(LCommits) + 1);
      LCommits[High(LCommits)] := GetCommit(LCommitOID);
      if (ALimit > 0) and (Length(LCommits) >= ALimit) then Break;
    end;
    Result := LCommits;
  finally
    git_revwalk_free(LWalk);
  end;
end;

function TGitCommit.GetParentOIDString(AIndex: Integer): string;
var
  LParent: git_commit;
  LParentOID: TGitOID;
begin
  EnsureLoaded;
  if (AIndex < 0) or (AIndex >= FParentCount) then
    Exit('');
  CheckGitResult(git_commit_parent(LParent, FHandle, AIndex), 'Get parent commit');
  try
    LParentOID.Data := git_object_id(LParent)^;
    Result := GitOIDToString(LParentOID);
  finally
    git_commit_free(LParent);
  end;
end;

end.
