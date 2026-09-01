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
    FClosed: Boolean;
    procedure EnsureOpen;
    procedure RaiseNotImpl(const AMethod: string);
  public
    constructor Create(const AGitDir, AWorkTree: string);
    // IGitRepository
    function Path: string;
    function WorkDir: string;
    function IsBare: Boolean;
    function IsEmpty: Boolean;
    function Head: IGitReference;
    function CurrentBranch: string;
    function ListBranches(Kind: TGitBranchKind = gbLocal): nextpas.core.base.TStringArray;
    function CommitByHash(const Hash: string): IGitCommit;
    function HeadCommit: IGitCommit;
    function Remote(const Name: string = 'origin'): IGitRemote;
    function Fetch(const RemoteName: string = 'origin'): Boolean;
    function CheckoutBranch(const Branch: string): Boolean;
    function CheckoutBranchEx(const Branch: string; Force: Boolean): Boolean;
    function Status: nextpas.core.base.TStringArray;
    function StatusEntries(const Filter: TGitStatusFilter): TGitStatusEntryArray;
    function IsClean: Boolean;
    function HasUncommittedChanges: Boolean;
    // IGitRepositoryExt
    function ListRemotes: nextpas.core.base.TStringArray;
    function PullFastForward(const RemoteName: string; out Error: string): TGitPullFastForwardResult;
    function Diff(const AOldRef, ANewRef: string): TGitDiff;
    function DiffEx(const AOldRef, ANewRef: string; const AOptions: TGitDiffOptions): TGitDiff;
    function DiffWorkingTree(const ARef: string): TGitDiff;
    function DiffWorkingTreeEx(const ARef: string; const AOptions: TGitDiffOptions): TGitDiff;
    function RevWalk(const AStartRef: string; ALimit: Integer): TGitCommitArray;
    function Blame(const APath: string): TGitBlame;
    function ConfigEntries: TGitConfigEntryArray;
    procedure ApplyPatch(const APatchText: string);
    procedure CheckoutPaths(const ARevspec: string; const APaths: nextpas.core.base.TStringArray);
    function WorkdirPatchText(const ARevspec: string; const APaths: nextpas.core.base.TStringArray; AShowBinary: Boolean): string;
    function AddWorktree(const AName, APath, ARef: string; ADetach: Boolean = False): IGitWorktree;
    function LookupWorktree(const AName: string): IGitWorktree;
    function ListWorktrees: nextpas.core.base.TStringArray;
    function PruneWorktree(const AName: string): Boolean;
    function CommitOnHead(const AMessage: string; const AAuthorName, AAuthorEmail: string): string;
  end;

implementation

uses
  nextpas.core.fs,
  nextpas.core.git.native.base,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.status,
  nextpas.core.git.native.branch,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.common,
  nextpas.core.git.native.diff,
  nextpas.core.git.native.blame,
  nextpas.core.git.native.config,
  nextpas.core.git.native.remote,
  nextpas.core.git.native.loose,
  nextpas.core.git.native.util,
  nextpas.core.git.native.worktree,
  nextpas.core.git.native.write,
  nextpas.core.git.native.index,
  nextpas.core.git.native.checkout,
  nextpas.core.git.native.revwalk,
  nextpas.core.git.native.repository.diff,
  nextpas.core.git.native.repository.worktree,
  nextpas.core.os.env;

type
  TNativeReference = class(TInterfacedObject, IGitReference)
  private
    FName: string;
    FShort: string;
    FOID: string;
  public
    constructor Create(const AName, AShort, AOIDHex: string);
    function Name: string;
    function ShortName: string;
    function TargetOIDString: string;
    function IsBranch: Boolean;
    function IsRemote: Boolean;
    function IsTag: Boolean;
  end;

  TNativeCommit = class(TInterfacedObject, IGitCommit)
  private
    FOIDHex: string;
    FInfo: TGitCommitInfo;
  public
    constructor Create(const AOIDHex: string; const AInfo: TGitCommitInfo);
    function Message: string;
    function ShortMessage: string;
    function AuthorString: string;
    function CommitterString: string;
    function Time: TDateTime;
    function ParentCount: Integer;
    function OIDString: string;
    function ParentOIDString(AIndex: Integer): string;
  end;

{ TNativeReference }

constructor TNativeReference.Create(const AName, AShort, AOIDHex: string);
begin
  inherited Create;
  FName := AName;
  FShort := AShort;
  FOID := AOIDHex;
end;

function TNativeReference.Name: string;
begin
  Result := FName;
end;

function TNativeReference.ShortName: string;
begin
  Result := FShort;
end;

function TNativeReference.TargetOIDString: string;
begin
  Result := FOID;
end;

function TNativeReference.IsBranch: Boolean;
begin
  Result := Pos('refs/heads/', FName) = 1;
end;

function TNativeReference.IsRemote: Boolean;
begin
  Result := Pos('refs/remotes/', FName) = 1;
end;

function TNativeReference.IsTag: Boolean;
begin
  Result := Pos('refs/tags/', FName) = 1;
end;

{ TNativeCommit }

constructor TNativeCommit.Create(const AOIDHex: string; const AInfo: TGitCommitInfo);
begin
  inherited Create;
  FOIDHex := LowerCase(AOIDHex);
  FInfo := AInfo;
end;

function TNativeCommit.Message: string;
begin
  Result := FInfo.Message;
end;

function TNativeCommit.ShortMessage: string;
var
  P: Integer;
begin
  P := Pos(#10, FInfo.Message);
  if P > 0 then
    Result := Trim(Copy(FInfo.Message, 1, P - 1))
  else
    Result := Trim(FInfo.Message);
end;

function Pad2(AValue: Integer): string; inline;
begin
  if AValue < 10 then
    Result := '0' + IntToStr(AValue)
  else
    Result := IntToStr(AValue);
end;

function FormatSig(const ASig: TGitSignature): string;
var
  Sign: Char;
  AbsM: Integer;
  H, M: Integer;
begin
  AbsM := ASig.TzMinutes;
  if AbsM < 0 then
  begin
    Sign := '-';
    AbsM := -AbsM;
  end
  else
    Sign := '+';
  H := AbsM div 60;
  M := AbsM mod 60;
  Result := ASig.Name + ' <' + ASig.Email + '> ' + IntToStr(ASig.UnixTime) +
    ' ' + Sign + Pad2(H) + Pad2(M);
end;

function TNativeCommit.AuthorString: string;
begin
  Result := FormatSig(FInfo.Author);
end;

function TNativeCommit.CommitterString: string;
begin
  Result := FormatSig(FInfo.Committer);
end;

function TNativeCommit.Time: TDateTime;
begin
  Result := (FInfo.Author.UnixTime / 86400) + 25569;
end;

function TNativeCommit.ParentCount: Integer;
begin
  Result := Length(FInfo.Parents);
end;

function TNativeCommit.OIDString: string;
begin
  Result := FOIDHex;
end;

function TNativeCommit.ParentOIDString(AIndex: Integer): string;
begin
  if (AIndex < 0) or (AIndex >= Length(FInfo.Parents)) then
    Exit('');
  Result := GitOidToHex(FInfo.Parents[AIndex]);
end;

{ TNativeRepositoryAdapter }

constructor TNativeRepositoryAdapter.Create(const AGitDir, AWorkTree: string);
begin
  inherited Create;
  FGitDir := AGitDir;
  FWorkTree := AWorkTree;
  FClosed := False;
end;

procedure TNativeRepositoryAdapter.EnsureOpen;
begin
  if FClosed then
    raise EGitError.Create('repository is closed');
end;

procedure TNativeRepositoryAdapter.RaiseNotImpl(const AMethod: string);
begin
  raise EGitError.Create('not implemented for native backend: ' + AMethod);
end;

function TNativeRepositoryAdapter.Path: string;
begin
  Result := FGitDir;
end;

function TNativeRepositoryAdapter.WorkDir: string;
begin
  Result := FWorkTree;
end;

function TNativeRepositoryAdapter.IsBare: Boolean;
begin
  Result := FWorkTree = '';
end;

function TNativeRepositoryAdapter.IsEmpty: Boolean;
begin
  EnsureOpen;
  try
    GitResolveHead(FGitDir);
    Result := False;
  except
    on EGitError do
      Result := True;
  end;
end;

function TNativeRepositoryAdapter.Head: IGitReference;
var
  RefName: string;
  Oid: TGitOid;
  Hex: string;
  Short: string;
begin
  EnsureOpen;
  RefName := GitHeadRefName(FGitDir);
  try
    Oid := GitResolveHead(FGitDir);
    Hex := GitOidToHex(Oid);
  except
    on Exception do
      raise EGitError.Create('native Head: ' + CurrentExceptionMessage);
  end;
  if RefName = '' then
    Result := TNativeReference.Create('HEAD', 'HEAD', Hex)
  else
  begin
    Short := RefName;
    if Pos('refs/heads/', Short) = 1 then
      Short := Copy(Short, 12, MaxInt)
    else if Pos('refs/tags/', Short) = 1 then
      Short := Copy(Short, 11, MaxInt)
    else if Pos('refs/remotes/', Short) = 1 then
      Short := Copy(Short, 14, MaxInt);
    Result := TNativeReference.Create(RefName, Short, Hex);
  end;
end;

function TNativeRepositoryAdapter.CurrentBranch: string;
begin
  EnsureOpen;
  Result := GitBranchCurrent(FGitDir);
end;

function TNativeRepositoryAdapter.ListBranches(Kind: TGitBranchKind): nextpas.core.base.TStringArray;
var
  List: TGitBranchArray;
  I: Integer;
begin
  EnsureOpen;
  if Kind <> gbLocal then
    RaiseNotImpl('ListBranches(Kind<>gbLocal)');
  List := GitBranchList(FGitDir);
  SetLength(Result, Length(List));
  for I := 0 to High(List) do
    Result[I] := List[I].RefName;
end;

function TNativeRepositoryAdapter.CommitByHash(const Hash: string): IGitCommit;
var
  Oid: TGitOid;
  Repo: TNativeRepository;
  Kind: TGitObjectKind;
  Data: TBytes;
  Info: TGitCommitInfo;
  PeelOid: TGitOid;
  TagInfo: TGitTagInfo;
begin
  EnsureOpen;
  if not GitOidIsValidHex(Hash) then
    raise EGitError.CreateFmt('invalid hash "%s"', [Hash]);
  Oid := GitOidFromHex(LowerCase(Hash));
  Repo := TNativeRepository.Create(FGitDir);
  try
    try
      Data := Repo.ReadObject(Oid, Kind);
    except
      on EGitError do
        raise EGitError.CreateFmt('object %s not found', [Hash]);
    end;
    while Kind = gokTag do
    begin
      TagInfo := GitParseTag(Data);
      PeelOid := TagInfo.Target;
      try
        Data := Repo.ReadObject(PeelOid, Kind);
      except
        raise EGitError.CreateFmt('object %s not found', [GitOidToHex(PeelOid)]);
      end;
      Oid := PeelOid;
    end;
    if Kind <> gokCommit then
      raise EGitError.CreateFmt('object %s is not a commit', [Hash]);
    Info := GitParseCommit(Data);
    Result := TNativeCommit.Create(GitOidToHex(Oid), Info);
  finally
    Repo.Free;
  end;
end;

function TNativeRepositoryAdapter.HeadCommit: IGitCommit;
var
  Oid: TGitOid;
  Hex: string;
begin
  EnsureOpen;
  try
    Oid := GitResolveHead(FGitDir);
    Hex := GitOidToHex(Oid);
  except
    on Exception do
      raise EGitError.Create('native HeadCommit: ' + CurrentExceptionMessage);
  end;
  Result := CommitByHash(Hex);
end;

function TNativeRepositoryAdapter.Remote(const Name: string): IGitRemote;
begin
  EnsureOpen;
  RaiseNotImpl('Remote');
  Result := nil;
end;

function TNativeRepositoryAdapter.Fetch(const RemoteName: string): Boolean;
begin
  EnsureOpen;
  RaiseNotImpl('Fetch');
  Result := False;
end;

function TNativeRepositoryAdapter.CheckoutBranch(const Branch: string): Boolean;
begin
  EnsureOpen;
  RaiseNotImpl('CheckoutBranch');
  Result := False;
end;

function TNativeRepositoryAdapter.CheckoutBranchEx(const Branch: string; Force: Boolean): Boolean;
begin
  EnsureOpen;
  RaiseNotImpl('CheckoutBranchEx');
  Result := False;
end;

function MapNativeToFlags(HeadCode, WorkCode: TGitStatusCode): TGitStatusFlags;
begin
  Result := [];
  case HeadCode of
    gscAdded: Include(Result, gsIndexNew);
    gscModified: Include(Result, gsIndexModified);
    gscDeleted: Include(Result, gsIndexDeleted);
    gscRenamed: Include(Result, gsIndexRenamed);
    gscTypeChanged: Include(Result, gsIndexTypeChange);
    gscCopied: Include(Result, gsIndexRenamed);
    gscUnmerged: Include(Result, gsConflicted);
    gscUntracked: Include(Result, gsWtNew);
  end;
  case WorkCode of
    gscAdded: Include(Result, gsWtNew);
    gscModified: Include(Result, gsWtModified);
    gscDeleted: Include(Result, gsWtDeleted);
    gscTypeChanged: Include(Result, gsWtTypeChange);
    gscRenamed: Include(Result, gsWtRenamed);
    gscCopied: Include(Result, gsWtRenamed);
    gscUnmerged: Include(Result, gsConflicted);
    gscUntracked: Include(Result, gsWtNew);
  end;
  if WorkCode = gscUntracked then
    Include(Result, gsWtNew);
end;

function TNativeRepositoryAdapter.Status: nextpas.core.base.TStringArray;
var
  Arr: TGitNativeStatusArray;
  I: Integer;
  Work: string;
begin
  EnsureOpen;
  Work := FWorkTree;
  if Work = '' then
    Work := PathDir(FGitDir);
  Arr := GitCollectStatus(FGitDir, Work, True);
  SetLength(Result, Length(Arr));
  for I := 0 to High(Arr) do
    Result[I] := Arr[I].Path;
end;

function TNativeRepositoryAdapter.StatusEntries(const Filter: TGitStatusFilter): TGitStatusEntryArray;
var
  Arr: TGitNativeStatusArray;
  Work: string;
  I, Count: Integer;
  Flags: TGitStatusFlags;
  Include: Boolean;
begin
  EnsureOpen;
  Work := FWorkTree;
  if Work = '' then
    Work := PathDir(FGitDir);
  Arr := GitCollectStatus(FGitDir, Work, Filter.IncludeUntracked);
  Count := 0;
  SetLength(Result, Length(Arr));
  for I := 0 to High(Arr) do
  begin
    Flags := MapNativeToFlags(Arr[I].HeadCode, Arr[I].WorkCode);
    Include := True;
    if Filter.IndexOnly then
      Include := (Arr[I].HeadCode <> gscUnmodified) and (Arr[I].HeadCode <> gscUntracked);
    if Filter.WorkingTreeOnly then
      Include := Include and (Arr[I].WorkCode <> gscUnmodified);
    if not Filter.IncludeUntracked then
      if Arr[I].WorkCode = gscUntracked then
        Include := False;
    if not Filter.IncludeIgnored then
      if gsIgnored in Flags then
        Include := False;
    if not Include then
      Continue;
    Result[Count].Path := Arr[I].Path;
    Result[Count].Flags := Flags;
    Inc(Count);
  end;
  SetLength(Result, Count);
end;

function TNativeRepositoryAdapter.IsClean: Boolean;
begin
  EnsureOpen;
  Result := Length(Status) = 0;
end;

function TNativeRepositoryAdapter.HasUncommittedChanges: Boolean;
begin
  Result := not IsClean;
end;

function TrimInline(const S: string): string; inline;
begin
  Result := GitTrimSpaces(S);
end;

function TNativeRepositoryAdapter.ListRemotes: nextpas.core.base.TStringArray;
var
  List: TGitRemoteArray;
  I: Integer;
begin
  EnsureOpen;
  try
    List:=GitRemoteList(FGitDir);
  except
    on EGitError do raise;
    on Exception do raise EGitError.Create(CurrentExceptionMessage);
  end;
  SetLength(Result,Length(List));
  for I:=0 to High(List) do
    Result[I]:=List[I].Name;
end;

function TNativeRepositoryAdapter.PullFastForward(const RemoteName: string; out Error: string): TGitPullFastForwardResult;
var
  RName, Branch, LocalRef, RemoteRef: string;
  HasDirty: Boolean;
  Rem: TGitRemote;
begin
  EnsureOpen;
  Error:='';
  RName:=TrimInline(RemoteName);
  if RName='' then
    RName:='origin';
  try HasDirty:=HasUncommittedChanges; except HasDirty:=False; end;
  if HasDirty then begin Error:='dirty worktree'; Exit(gpffDirty); end;
  Branch:=CurrentBranch;
  if Branch='' then begin Error:='detached HEAD'; Exit(gpffDetachedHead); end;
  if not GitRemoteFind(FGitDir,RName,Rem) then begin Error:='no remote "'+RName+'"'; Exit(gpffNoRemote); end;
  LocalRef:='refs/heads/'+Branch;
  RemoteRef:='refs/remotes/'+RName+'/'+Branch;
  try
    if not GitOidSame(GitResolveRef(FGitDir,LocalRef),GitResolveRef(FGitDir,RemoteRef)) then
    begin
      Error:='needs merge (pure backend, no fetch)';
      Exit(gpffNeedsMerge);
    end;
  except
    on EGitError do begin Error:=CurrentExceptionMessage; Exit(gpffError); end;
  end;
  Result:=gpffUpToDate;
end;

function TNativeRepositoryAdapter.Diff(const AOldRef, ANewRef: string): TGitDiff;
begin
  Result:=DiffEx(AOldRef,ANewRef,DefaultGitDiffOptions);
end;

function TNativeRepositoryAdapter.DiffEx(const AOldRef, ANewRef: string; const AOptions: TGitDiffOptions): TGitDiff;
begin
  EnsureOpen;
  Result := RepositoryDiffEx(FGitDir, AOldRef, ANewRef, AOptions);
end;

function TNativeRepositoryAdapter.DiffWorkingTree(const ARef: string): TGitDiff;
begin
  Result:=DiffWorkingTreeEx(ARef,DefaultGitDiffOptions);
end;

function TNativeRepositoryAdapter.DiffWorkingTreeEx(const ARef: string; const AOptions: TGitDiffOptions): TGitDiff;
begin
  EnsureOpen;
  Result := RepositoryDiffWorkingTreeEx(FGitDir, FWorkTree, ARef, AOptions);
end;

function TNativeRepositoryAdapter.RevWalk(const AStartRef: string; ALimit: Integer): TGitCommitArray;
var
  StartOid: TGitOid;
  Repo: TNativeRepository;
  Oids: TGitOidArray;
  I: Integer;
  MaxCount: SizeInt;
  Kind: TGitObjectKind;
  Data: TBytes;
  Info: TGitCommitInfo;
begin
  EnsureOpen;
  Result := nil;
  if TrimInline(AStartRef) = '' then
    raise EGitError.Create('RevWalk: start ref required');
  try
    StartOid := GitRevParse(FGitDir, TrimInline(AStartRef));
  except
    on EGitError do raise;
    on Exception do raise EGitError.Create(CurrentExceptionMessage);
  end;
  Repo := TNativeRepository.Create(FGitDir);
  try
    if ALimit <= 0 then
      MaxCount := -1
    else
      MaxCount := ALimit;
    // owner revwalk: single-source via bytes.ops, inline zero-copy, bounded cache, try..finally resource not lost
    Oids := GitCollectCommits(Repo, [StartOid], MaxCount);
    SetLength(Result, Length(Oids));
    for I := 0 to High(Oids) do
    begin
      try
        Data := Repo.ReadObject(Oids[I], Kind);
      except
        on EGitError do raise EGitError.CreateFmt('RevWalk: object %s not found', [GitOidToHex(Oids[I])]);
        on Exception do raise EGitError.Create(CurrentExceptionMessage);
      end;
      if Kind <> gokCommit then
        raise EGitError.CreateFmt('RevWalk: object %s is not a commit', [GitOidToHex(Oids[I])]);
      Info := GitParseCommit(Data);
      Result[I] := TNativeCommit.Create(GitOidToHex(Oids[I]), Info);
    end;
  finally
    Repo.Free;
  end;
end;

function TNativeRepositoryAdapter.Blame(const APath: string): TGitBlame;
var
  NativeBlame: TGitBlameArray;
  I, StartIdx: Integer;
  H: TGitBlameHunk;
  CurId: string;
begin
  EnsureOpen;
  Result.Path:=APath;
  Result.Hunks:=nil;
  if TrimInline(APath)='' then
    Exit;
  try
    NativeBlame:=GitBlame(FGitDir,APath);
  except
    on EGitError do raise;
    on Exception do raise EGitError.Create(CurrentExceptionMessage);
  end;
  if Length(NativeBlame)=0 then
    Exit;
  StartIdx:=0;
  CurId:=GitOidToHex(NativeBlame[0].CommitOid);
  for I:=1 to Length(NativeBlame) do
  begin
    if (I=Length(NativeBlame)) or (GitOidToHex(NativeBlame[I].CommitOid)<>CurId) then
    begin
      H.LinesInHunk:=I-StartIdx;
      H.FinalCommitId:=CurId;
      H.OrigCommitId:=CurId;
      H.FinalStartLine:=NativeBlame[StartIdx].LineNo;
      H.OrigStartLine:=NativeBlame[StartIdx].LineNo;
      H.OrigPath:=APath;
      H.Boundary:=False;
      SetLength(Result.Hunks,Length(Result.Hunks)+1);
      Result.Hunks[High(Result.Hunks)]:=H;
      if I < Length(NativeBlame) then
      begin
        StartIdx:=I;
        CurId:=GitOidToHex(NativeBlame[I].CommitOid);
      end;
    end;
  end;
end;

function TNativeRepositoryAdapter.ConfigEntries: TGitConfigEntryArray;
var
  Cfg: TGitConfig;
  IncPath, Home: string;
  IncData: TBytes;
  IncCfg: TGitConfig;
  J, I: Integer;
begin
  EnsureOpen;
  Result:=nil;
  try
    Cfg:=GitReadConfig(FGitDir);
    SetLength(Result,Length(Cfg.Entries));
    for I:=0 to High(Cfg.Entries) do
    begin
      Result[I].Name:=Cfg.Entries[I].Key;
      Result[I].Value:=Cfg.Entries[I].Value;
    end;
    // include.path expansion — pure, single-source via GitParseConfig / bytes.ops, inline zero-copy Home handling
    for I:=0 to High(Cfg.Entries) do
      if Cfg.Entries[I].Key='include.path' then
      begin
        IncPath:=Cfg.Entries[I].Value;
        if (Length(IncPath)>0) and (IncPath[1]='~') then
        begin
          Home:=nextpas.core.os.env.GetEnv('HOME');
          if Home<>'' then
            IncPath:=Home+Copy(IncPath,2,MaxInt);
        end
        else if not PathIsAbsolute(IncPath) then
          IncPath:=PathJoin([PathDir(FGitDir),IncPath]);
        if FileExists(IncPath) then
          try
            IncData:=ReadFile(IncPath);
            IncCfg:=GitParseConfig(IncData);
            for J:=0 to High(IncCfg.Entries) do
            begin
              SetLength(Result,Length(Result)+1);
              Result[High(Result)].Name:=IncCfg.Entries[J].Key;
              Result[High(Result)].Value:=IncCfg.Entries[J].Value;
            end;
          except
          end;
      end;
  except
    on EGitError do raise;
    on Exception do raise EGitError.Create(CurrentExceptionMessage);
  end;
end;

procedure TNativeRepositoryAdapter.ApplyPatch(const APatchText: string);
begin
  EnsureOpen;
  RepositoryApplyPatch(FGitDir, FWorkTree, APatchText);
end;

procedure TNativeRepositoryAdapter.CheckoutPaths(const ARevspec: string; const APaths: nextpas.core.base.TStringArray);
begin
  EnsureOpen;
  RepositoryCheckoutPaths(FGitDir, FWorkTree, ARevspec, APaths);
end;

function TNativeRepositoryAdapter.WorkdirPatchText(const ARevspec: string; const APaths: nextpas.core.base.TStringArray; AShowBinary: Boolean): string;
begin
  EnsureOpen;
  Result := RepositoryWorkdirPatchText(FGitDir, FWorkTree, ARevspec, APaths, AShowBinary);
end;

function TNativeRepositoryAdapter.AddWorktree(const AName, APath, ARef: string; ADetach: Boolean): IGitWorktree;
begin
  EnsureOpen;
  Result := RepositoryAddWorktree(FGitDir, FWorkTree, AName, APath, ARef, ADetach);
end;

function TNativeRepositoryAdapter.LookupWorktree(const AName: string): IGitWorktree;
begin
  EnsureOpen;
  Result := RepositoryLookupWorktree(FGitDir, AName);
end;

function TNativeRepositoryAdapter.ListWorktrees: nextpas.core.base.TStringArray;
begin
  EnsureOpen;
  Result := RepositoryListWorktrees(FGitDir);
end;

function TNativeRepositoryAdapter.PruneWorktree(const AName: string): Boolean;
begin
  EnsureOpen;
  Result := RepositoryPruneWorktree(FGitDir, AName);
end;

function TNativeRepositoryAdapter.CommitOnHead(const AMessage: string; const AAuthorName, AAuthorEmail: string): string;
begin
  EnsureOpen;
  Result := RepositoryCommitOnHead(FGitDir, FWorkTree, AMessage, AAuthorName, AAuthorEmail);
end;

end.
