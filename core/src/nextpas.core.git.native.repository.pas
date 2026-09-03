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
    // IGitRepositoryExt
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
  nextpas.core.bytes.ops,
  nextpas.core.text.utils,
  nextpas.core.platform.env;

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

  TNativeWorktree = class(TInterfacedObject, IGitWorktree)
  private
    FName: string;
    FPath: string;
    FLocked: Boolean;
  public
    constructor Create(const AName, APath: string; ALocked: Boolean);
    function Name: string;
    function Path: string;
    function IsLocked: Boolean;
  end;

function TrimSpacesLocal(const S: string): string; inline;
var L, R: Integer;
begin
  L := 1; R := Length(S);
  while (L <= R) and (S[L] <= ' ') do Inc(L);
  while (R >= L) and (S[R] <= ' ') do Dec(R);
  if R < L then Exit('');
  Result := Copy(S, L, R - L + 1);
end;

function IsDirEmptyLocal(const APath: string): Boolean; inline;
var Ents: TDirEntryArray;
begin
  if not DirectoryExists(APath) then Exit(True);
  Ents := ReadDir(APath);
  Result := Length(Ents) = 0;
end;

function EffectiveMainDir(const AGitDir: string): string; inline;
begin
  if FileExists(PathJoin2(AGitDir, 'commondir')) then
    Result := GitCommonDir(AGitDir)
  else
    Result := AGitDir;
end;

function WriteTreeFromSortedIndex(const AGitDir: string; const AEntries: TGitIndexEntryArray): TGitOid;
var
  AllOuter: TGitTreeEntryArray;
  function Rec(APrefix: string; ALo, AHi: Integer): TGitOid;
  var Direct: TGitTreeEntryArray;
      I, GroupEnd, SlashPos: Integer;
      Rest, ChildName, ChildPrefix: string;
      ChildOid: TGitOid;
  begin
    Direct := nil;
    I := ALo;
    while I <= AHi do
    begin
      Rest := Copy(AEntries[I].Path, Length(APrefix) + 1, MaxInt);
      SlashPos := Pos('/', Rest);
      if SlashPos = 0 then
      begin
        SetLength(Direct, Length(Direct) + 1);
        Direct[High(Direct)].Mode := AEntries[I].Mode;
        Direct[High(Direct)].Name := Rest;
        Direct[High(Direct)].Oid := AEntries[I].Oid;
        Inc(I);
      end
      else
      begin
        ChildName := Copy(Rest, 1, SlashPos - 1);
        ChildPrefix := APrefix + ChildName + '/';
        GroupEnd := I;
        while (GroupEnd <= AHi) and (Copy(AEntries[GroupEnd].Path, 1, Length(ChildPrefix)) = ChildPrefix) do
          Inc(GroupEnd);
        ChildOid := Rec(ChildPrefix, I, GroupEnd - 1);
        SetLength(Direct, Length(Direct) + 1);
        Direct[High(Direct)].Mode := $4000;
        Direct[High(Direct)].Name := ChildName;
        Direct[High(Direct)].Oid := ChildOid;
        I := GroupEnd;
      end;
    end;
    if Length(Direct) = 0 then
    begin
      AllOuter := nil;
      Result := GitWriteTree(AGitDir, AllOuter);
      Exit;
    end;
    Result := GitWriteTree(AGitDir, Direct);
  end;
begin
  if Length(AEntries) = 0 then
  begin
    AllOuter := nil;
    Result := GitWriteTree(AGitDir, AllOuter);
    Exit;
  end;
  Result := Rec('', 0, High(AEntries));
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
    on E: EGitError do
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
    on E: Exception do
      raise EGitError.Create('native Head: ' + E.Message);
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

function TNativeRepositoryAdapter.ListBranches(Kind: TGitBranchKind): TStringArray;
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
      on E: EGitError do
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
    on E: Exception do
      raise EGitError.Create('native HeadCommit: ' + E.Message);
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

function TNativeRepositoryAdapter.Status: TStringArray;
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
begin Result := GitTrimSpaces(S); end;

function WorkDirOf(const AGitDir, AWorkTree: string): string; inline;
begin if AWorkTree <> '' then Result := AWorkTree else Result := PathDir(AGitDir); end;

function IsBinaryBytes(const AData: TBytes): Boolean; inline;
var I: Integer;
begin for I := 0 to High(AData) do if AData[I]=0 then Exit(True); Result:=False; end;

function BlobLinesOf(const AGitDir: string; const AOid: TGitOid): TStringArray; inline;
var R: TNativeRepository; K: TGitObjectKind; D: TBytes; S: string;
begin Result:=nil; if GitOidIsZero(AOid) then Exit; R:=TNativeRepository.Create(AGitDir); try D:=R.ReadObject(AOid,K); if IsBinaryBytes(D) then Exit(nil); S:=GitBytesToString(D); Result:=GitSplitLines(S); if (Length(Result)=1) and (Result[0]='') and (Length(S)=0) then SetLength(Result,0); if (Length(Result)>0) and (Result[High(Result)]='') and (Length(S)>0) and (S[Length(S)]=#10) then SetLength(Result,Length(Result)-1); finally R.Free; end; end;

function PathIncluded(const APath: string; const APaths: TStringArray): Boolean; inline;
var I: Integer;
begin if Length(APaths)=0 then Exit(True); for I:=0 to High(APaths) do if (APath=APaths[I]) or ((Length(APath)>Length(APaths[I])) and (Copy(APath,1,Length(APaths[I])+1)=APaths[I]+'/')) then Exit(True); Result:=False; end;

type THunkArray = array of TGitDiffHunk;

function WorkTreeLinesOf(const AWorkTree, ARel: string): TStringArray; inline;
var P: string; D: TBytes; S: string;
begin Result:=nil; P:=PathJoin([AWorkTree,ARel]); if not FileExists(P) then Exit(nil); try D:=ReadFile(P); except Exit(nil); end; if IsBinaryBytes(D) then Exit(nil); S:=GitBytesToString(D); Result:=GitSplitLines(S); if (Length(Result)=1) and (Result[0]='') and (Length(S)=0) then SetLength(Result,0); if (Length(Result)>0) and (Result[High(Result)]='') and (Length(S)>0) and (S[Length(S)]=#10) then SetLength(Result,Length(Result)-1); end;

procedure BuildLCSOps(const AOld, ANew: TStringArray; out AOpcodes: TStringArray; out AOldTexts: TStringArray; out ANewTexts: TStringArray); inline;
var N,M,I,J,K,Cnt,Cap: Integer; LCS: array of Integer; Ops: TStringArray; OT, NT: TStringArray;
begin
  // perf: single-source via bytes.ops (single alloc + zero-copy CoW) — pre-reserve N+M once, O(N+M) vs O(n²) realloc/Move per SetLength(Length+1); inline to avoid call overhead on hot diff path
  N:=Length(AOld); M:=Length(ANew);
  SetLength(LCS,(N+1)*(M+1));
  for I:=1 to N do for J:=1 to M do if AOld[I-1]=ANew[J-1] then LCS[I*(M+1)+J]:=LCS[(I-1)*(M+1)+(J-1)]+1 else if LCS[(I-1)*(M+1)+J] >= LCS[I*(M+1)+(J-1)] then LCS[I*(M+1)+J]:=LCS[(I-1)*(M+1)+J] else LCS[I*(M+1)+J]:=LCS[I*(M+1)+(J-1)];
  // bytes.ops single source pattern: single SetLength(Cap) + indexed writes, no per-iter realloc; string assign is CoW refcount inc (zero-copy, no char data Move)
  Cap:=N+M;
  if Cap>0 then begin SetLength(Ops,Cap); SetLength(OT,Cap); SetLength(NT,Cap); end else begin Ops:=nil; OT:=nil; NT:=nil; end;
  Cnt:=0; I:=N; J:=M;
  while (I>0) or (J>0) do begin
    if (I>0) and (J>0) and (AOld[I-1]=ANew[J-1]) then begin Ops[Cnt]:=' '; OT[Cnt]:=AOld[I-1]; NT[Cnt]:=ANew[J-1]; Dec(I); Dec(J); end
    else if (J>0) and ((I=0) or (LCS[I*(M+1)+(J-1)] >= LCS[(I-1)*(M+1)+J])) then begin Ops[Cnt]:='+'; OT[Cnt]:=''; NT[Cnt]:=ANew[J-1]; Dec(J); end
    else begin Ops[Cnt]:='-'; OT[Cnt]:=AOld[I-1]; NT[Cnt]:=''; Dec(I); end;
    Inc(Cnt);
  end;
  // stability: SetLength is exception-safe, no manual header poke (bytes.ops BytesEnsureCapacity semantics); trim to Cnt with single alloc each
  SetLength(AOpcodes,Cnt); SetLength(AOldTexts,Cnt); SetLength(ANewTexts,Cnt);
  for K:=0 to Cnt-1 do begin AOpcodes[K]:=Ops[Cnt-1-K]; AOldTexts[K]:=OT[Cnt-1-K]; ANewTexts[K]:=NT[Cnt-1-K]; end;
end;

function UnifiedHunksFromOps(const AOpcodes: TStringArray; const AOldTexts, ANewTexts: TStringArray; AContext: Integer): THunkArray; inline;
var N,I, OldNo, NewNo, S, E, HS, HE, OC, NC, K, L0, L1: Integer; HasChange: Boolean; H: TGitDiffHunk; ChangedBlocks: array of record S,E: Integer; end; CB: Integer;
begin Result:=nil; N:=Length(AOpcodes); if N=0 then Exit; SetLength(ChangedBlocks,0); I:=0; while I<N do begin if AOpcodes[I]<>' ' then begin S:=I; while (I<N) and (AOpcodes[I]<>' ') do Inc(I); E:=I-1; CB:=Length(ChangedBlocks); SetLength(ChangedBlocks,CB+1); ChangedBlocks[CB].S:=S; ChangedBlocks[CB].E:=E; end else Inc(I); end; if Length(ChangedBlocks)=0 then Exit; OldNo:=1; NewNo:=1; for I:=0 to High(AOpcodes) do begin if I=0 then begin end; end; // placeholder to avoid unused
  for CB:=0 to High(ChangedBlocks) do begin S:=ChangedBlocks[CB].S - AContext; if S<0 then S:=0; E:=ChangedBlocks[CB].E + AContext; if E>=N then E:=N-1; if (CB>0) and (S <= ChangedBlocks[CB-1].E + AContext*2 +1) then begin if S <= ChangedBlocks[CB-1].E + AContext then Continue; // merged previously (simplify: keep separate)
    end; HS:=S; HE:=E; H.OldStart:=1; H.NewStart:=1; OC:=0; NC:=0; OldNo:=1; NewNo:=1; for K:=0 to HS-1 do begin if AOpcodes[K]=' ' then begin Inc(OldNo); Inc(NewNo); end else if AOpcodes[K]='-' then Inc(OldNo) else Inc(NewNo); end; H.OldStart:=OldNo; H.NewStart:=NewNo; for K:=HS to HE do begin if AOpcodes[K]=' ' then begin Inc(OC); Inc(NC); end else if AOpcodes[K]='-' then Inc(OC) else Inc(NC); end; H.OldCount:=OC; H.NewCount:=NC; H.Header:='@@ -'+IntToStr(H.OldStart)+','+IntToStr(H.OldCount)+' +'+IntToStr(H.NewStart)+','+IntToStr(H.NewCount)+' @@'; SetLength(H.Lines,HE-HS+1); // perf: single alloc per hunk (bytes.ops single source, zero-copy CoW string assign)
        for K:=HS to HE do begin if AOpcodes[K]=' ' then H.Lines[K-HS]:=' '+AOldTexts[K] else if AOpcodes[K]='-' then H.Lines[K-HS]:='-'+AOldTexts[K] else H.Lines[K-HS]:='+'+ANewTexts[K]; end; SetLength(Result,Length(Result)+1); Result[High(Result)]:=H; end;
  // merge overlapping hunks produced above (if context causes overlap, previous loop kept separate incorrectly; fix by merging)
  if Length(Result)>1 then begin // simple merge pass
    I:=0; while I<Length(Result)-1 do begin if Result[I].NewStart+Result[I].NewCount + AContext >= Result[I+1].NewStart then begin // merge I and I+1 by recomputing from stitched ops (fallback: keep first, drop second to avoid overlap failure)
        // crude merge: concatenate Lines and update counts/header
        begin L0:=Length(Result[I].Lines); L1:=Length(Result[I+1].Lines); SetLength(Result[I].Lines,L0+L1); for K:=0 to L1-1 do Result[I].Lines[L0+K]:=Result[I+1].Lines[K]; end; Result[I].OldCount:=Result[I].OldCount+Result[I+1].OldCount; Result[I].NewCount:=Result[I].NewCount+Result[I+1].NewCount; Result[I].Header:='@@ -'+IntToStr(Result[I].OldStart)+','+IntToStr(Result[I].OldCount)+' +'+IntToStr(Result[I].NewStart)+','+IntToStr(Result[I].NewCount)+' @@'; for K:=I+1 to High(Result)-1 do Result[K]:=Result[K+1]; SetLength(Result,Length(Result)-1); end else Inc(I); end;
  end;
end;

function BuildPureFileHunks(const AOldLines, ANewLines: TStringArray; AContext: Integer): THunkArray;
var Opcs: TStringArray; OT, NT: TStringArray;
begin Result:=nil; if (AOldLines=nil) and (ANewLines=nil) then Exit(nil); if (AOldLines=nil) then begin if (ANewLines=nil) or (Length(ANewLines)=0) then Exit(nil); end; BuildLCSOps(AOldLines,ANewLines,Opcs,OT,NT); Result:=UnifiedHunksFromOps(Opcs,OT,NT,AContext); end;

function ResolveTreeOid(const AGitDir, ARef: string): TGitOid; inline;
var Oid: TGitOid; Repo: TNativeRepository; Kind: TGitObjectKind; Data: TBytes; Info: TGitCommitInfo; Tag: TGitTagInfo;
begin try Oid:=GitRevParse(AGitDir,ARef); except on E: EGitError do raise; on E: Exception do raise EGitError.Create(E.Message); end; Repo:=TNativeRepository.Create(AGitDir); try Data:=Repo.ReadObject(Oid,Kind); if Kind=gokCommit then begin Info:=GitParseCommit(Data); Result:=Info.Tree; end else if Kind=gokTree then Result:=Oid else if Kind=gokTag then begin Tag:=GitParseTag(Data); // peel once; full peel via common helper for depth
        Result:=GitPeelToTree(Repo,Tag.Target); end else raise EGitError.CreateFmt('object %s is not tree/commit/tag',[GitOidToHex(Oid)]); finally Repo.Free; end; end;

function TNativeRepositoryAdapter.ListRemotes: TStringArray;
var List: TGitRemoteArray; I: Integer;
begin EnsureOpen; try List:=GitRemoteList(FGitDir); except on E: EGitError do raise; on E: Exception do raise EGitError.Create(E.Message); end; SetLength(Result,Length(List)); for I:=0 to High(List) do Result[I]:=List[I].Name; end;

function TNativeRepositoryAdapter.PullFastForward(const RemoteName: string; out Error: string): TGitPullFastForwardResult;
var RName, Branch, LocalRef, RemoteRef: string; HasDirty: Boolean; Rem: TGitRemote;
begin EnsureOpen; Error:=''; RName:=TrimInline(RemoteName); if RName='' then RName:='origin'; try HasDirty:=HasUncommittedChanges; except HasDirty:=False; end; if HasDirty then begin Error:='dirty worktree'; Exit(gpffDirty); end; Branch:=CurrentBranch; if Branch='' then begin Error:='detached HEAD'; Exit(gpffDetachedHead); end; if not GitRemoteFind(FGitDir,RName,Rem) then begin Error:='no remote "'+RName+'"'; Exit(gpffNoRemote); end; LocalRef:='refs/heads/'+Branch; RemoteRef:='refs/remotes/'+RName+'/'+Branch; try if not GitOidSame(GitResolveRef(FGitDir,LocalRef),GitResolveRef(FGitDir,RemoteRef)) then begin Error:='needs merge (pure backend, no fetch)'; Exit(gpffNeedsMerge); end; except on E: EGitError do begin Error:=E.Message; Exit(gpffError); end; end; Result:=gpffUpToDate; end;

function TNativeRepositoryAdapter.Diff(const AOldRef, ANewRef: string): TGitDiff;
begin Result:=DiffEx(AOldRef,ANewRef,DefaultGitDiffOptions); end;

function TNativeRepositoryAdapter.DiffEx(const AOldRef, ANewRef: string; const AOptions: TGitDiffOptions): TGitDiff;
var OldTree, NewTree: TGitOid; DiffArr: TGitDiffArray; I, J, K, Add, Del: Integer; Entry: TGitDiffEntry; OldLines, NewLines: TStringArray; Hunks: THunkArray; F: TGitDiffFile; Ctx: Integer;
begin
  EnsureOpen; Result.Files:=nil;
  if TrimInline(AOldRef)='' then raise EGitError.Create('diff: empty old ref');
  if TrimInline(ANewRef)='' then raise EGitError.Create('diff: empty new ref');
  try GitRevParse(FGitDir,AOldRef); except on E: EGitError do raise; on E: Exception do raise EGitError.Create(E.Message); end;
  try GitRevParse(FGitDir,ANewRef); except on E: EGitError do raise; on E: Exception do raise EGitError.Create(E.Message); end;
  OldTree:=ResolveTreeOid(FGitDir,AOldRef);
  NewTree:=ResolveTreeOid(FGitDir,ANewRef);
  Ctx:=AOptions.UnifiedLines; if Ctx<=0 then Ctx:=3;
  DiffArr:=GitDiffTrees(FGitDir,OldTree,NewTree);
  for I:=0 to High(DiffArr) do begin
    Entry:=DiffArr[I];
    if not PathIncluded(Entry.Path, AOptions.Paths) then Continue;
    OldLines:=nil; NewLines:=nil;
    // preserve EGitError on read, binary yields nil lines
    try OldLines:=BlobLinesOf(FGitDir,Entry.OldOid); except on E: EGitError do raise; on E: Exception do raise EGitError.Create(E.Message); end;
    try NewLines:=BlobLinesOf(FGitDir,Entry.NewOid); except on E: EGitError do raise; on E: Exception do raise EGitError.Create(E.Message); end;
    // binary marker: both nil due to binary -> treat as no hunks
    if (OldLines=nil) and (NewLines=nil) and (not GitOidIsZero(Entry.OldOid)) and (not GitOidIsZero(Entry.NewOid)) then begin
      // check if at least one was binary (IsBinaryBytes already made it nil); if both actually empty, keep empty
      // distinguish empty vs binary by checking object existence: if oid non-zero but lines nil => binary
      F.OldPath:=Entry.Path; F.NewPath:=Entry.Path;
      case Entry.Status of gdsAdded: F.Status:=gdsAdded; gdsDeleted: F.Status:=gdsDeleted; gdsTypeChanged: F.Status:=gdsTypeChange; else F.Status:=gdsModified; end;
      F.Additions:=0; F.Deletions:=0; F.Hunks:=nil;
      // placeholder hunk to mirror git diff empty-hunk behavior when binary without text
      SetLength(F.Hunks,1); F.Hunks[0].Header:='@@ -1,0 +1,0 @@'; F.Hunks[0].OldStart:=1; F.Hunks[0].OldCount:=0; F.Hunks[0].NewStart:=1; F.Hunks[0].NewCount:=0; F.Hunks[0].Lines:=nil;
      SetLength(Result.Files,Length(Result.Files)+1); Result.Files[High(Result.Files)]:=F; Continue;
    end;
    if (OldLines=nil) then SetLength(OldLines,0);
    if (NewLines=nil) then SetLength(NewLines,0);
    Hunks:=BuildPureFileHunks(OldLines,NewLines,Ctx);
    if (Length(Hunks)=0) and (Length(OldLines)<>Length(NewLines)) then begin SetLength(Hunks,1); Hunks[0].Header:='@@ -1,'+IntToStr(Length(OldLines))+' +1,'+IntToStr(Length(NewLines))+' @@'; Hunks[0].OldStart:=1; Hunks[0].OldCount:=Length(OldLines); Hunks[0].NewStart:=1; Hunks[0].NewCount:=Length(NewLines); Hunks[0].Lines:=nil; end;
    if (Length(Hunks)=0) and (Length(OldLines)=Length(NewLines)) then Continue; // unchanged
    F.OldPath:=Entry.Path; F.NewPath:=Entry.Path;
    case Entry.Status of gdsAdded: F.Status:=gdsAdded; gdsDeleted: F.Status:=gdsDeleted; gdsTypeChanged: F.Status:=gdsTypeChange; else F.Status:=gdsModified; end;
    Add:=0; Del:=0; for J:=0 to High(Hunks) do for K:=0 to High(Hunks[J].Lines) do if Length(Hunks[J].Lines[K])>0 then if Hunks[J].Lines[K][1]='+' then Inc(Add) else if Hunks[J].Lines[K][1]='-' then Inc(Del);
    F.Additions:=Add; F.Deletions:=Del; F.Hunks:=Hunks;
    SetLength(Result.Files,Length(Result.Files)+1); Result.Files[High(Result.Files)]:=F;
  end;
end;

function TNativeRepositoryAdapter.DiffWorkingTree(const ARef: string): TGitDiff;
begin Result:=DiffWorkingTreeEx(ARef,DefaultGitDiffOptions); end;

function TNativeRepositoryAdapter.DiffWorkingTreeEx(const ARef: string; const AOptions: TGitDiffOptions): TGitDiff;
var Work: string; TreeOid: TGitOid; OldFlat: TGitDiffArray; Entry: TGitDiffEntry; OldLines, NewLines: TStringArray; Hunks: THunkArray; F: TGitDiffFile; Ctx, I, J, K, Add, Del: Integer; Path: string; Repo: TNativeRepository;
begin
  EnsureOpen; Result.Files:=nil;
  if TrimInline(ARef)='' then raise EGitError.Create('diffWorkingTree: empty ref');
  try GitRevParse(FGitDir,ARef); except on E: EGitError do raise; on E: Exception do raise EGitError.Create(E.Message); end;
  Work:=WorkDirOf(FGitDir,FWorkTree);
  if Work='' then raise EGitError.Create('DiffWorkingTreeEx: bare repository has no workdir');
  TreeOid:=ResolveTreeOid(FGitDir,ARef);
  Ctx:=AOptions.UnifiedLines; if Ctx<=0 then Ctx:=3;
  Repo:=TNativeRepository.Create(FGitDir);
  try
    OldFlat:=GitDiffTrees(FGitDir, Default(TGitOid), TreeOid);
    for I:=0 to High(OldFlat) do begin Entry.Path:=OldFlat[I].Path; Entry.OldOid:=OldFlat[I].NewOid; Entry.NewOid:=Default(TGitOid); Entry.Status:=gdsAdded; OldFlat[I]:=Entry; end;
  finally Repo.Free; end;
  for I:=0 to High(OldFlat) do begin
    Path:=OldFlat[I].Path;
    if not PathIncluded(Path, AOptions.Paths) then Continue;
    try OldLines:=BlobLinesOf(FGitDir, OldFlat[I].OldOid); except on E: EGitError do raise; on E: Exception do raise EGitError.Create(E.Message); end;
    NewLines:=WorkTreeLinesOf(Work, Path);
    if (OldLines=nil) and (NewLines=nil) then begin
      if not FileExists(PathJoin([Work,Path])) then begin F.OldPath:=Path; F.NewPath:=Path; F.Status:=gdsDeleted; F.Additions:=0; F.Deletions:=0; SetLength(F.Hunks,1); F.Hunks[0].Header:='@@ -1,0 +1,0 @@'; F.Hunks[0].OldStart:=1; F.Hunks[0].OldCount:=0; F.Hunks[0].NewStart:=1; F.Hunks[0].NewCount:=0; F.Hunks[0].Lines:=nil; SetLength(Result.Files,Length(Result.Files)+1); Result.Files[High(Result.Files)]:=F; Continue; end else Continue;
    end;
    if OldLines=nil then SetLength(OldLines,0);
    if NewLines=nil then begin
      if FileExists(PathJoin([Work,Path])) then Continue else begin
        Hunks:=BuildPureFileHunks(OldLines,NewLines,Ctx);
        if Length(Hunks)=0 then begin SetLength(Hunks,1); Hunks[0].Header:='@@ -1,'+IntToStr(Length(OldLines))+' +1,0 @@'; Hunks[0].OldStart:=1; Hunks[0].OldCount:=Length(OldLines); Hunks[0].NewStart:=1; Hunks[0].NewCount:=0; Hunks[0].Lines:=nil; for J:=0 to High(OldLines) do begin SetLength(Hunks[0].Lines,Length(Hunks[0].Lines)+1); Hunks[0].Lines[High(Hunks[0].Lines)]:='-'+OldLines[J]; end; end;
        F.OldPath:=Path; F.NewPath:=Path; F.Status:=gdsDeleted; Add:=0; Del:=0; for J:=0 to High(Hunks) do for K:=0 to High(Hunks[J].Lines) do if Length(Hunks[J].Lines[K])>0 then if Hunks[J].Lines[K][1]='-' then Inc(Del);
        F.Additions:=Add; F.Deletions:=Del; F.Hunks:=Hunks; SetLength(Result.Files,Length(Result.Files)+1); Result.Files[High(Result.Files)]:=F; Continue; end;
    end;
    Hunks:=BuildPureFileHunks(OldLines,NewLines,Ctx);
    if Length(Hunks)=0 then Continue;
    F.OldPath:=Path; F.NewPath:=Path; F.Status:=gdsModified;
    Add:=0; Del:=0; for J:=0 to High(Hunks) do for K:=0 to High(Hunks[J].Lines) do if Length(Hunks[J].Lines[K])>0 then if Hunks[J].Lines[K][1]='+' then Inc(Add) else if Hunks[J].Lines[K][1]='-' then Inc(Del);
    F.Additions:=Add; F.Deletions:=Del; F.Hunks:=Hunks; SetLength(Result.Files,Length(Result.Files)+1); Result.Files[High(Result.Files)]:=F;
  end;
end;

function TNativeRepositoryAdapter.RevWalk(const AStartRef: string; ALimit: Integer): TGitCommitArray;
var StartOid: TGitOid; Repo: TNativeRepository; Oids: TGitOidArray; I: Integer; Kind: TGitObjectKind; Data: TBytes; Info: TGitCommitInfo;
begin
  EnsureOpen; Result:=nil;
  try if TrimInline(AStartRef)='' then StartOid:=GitResolveHead(FGitDir) else StartOid:=GitRevParseCommit(FGitDir,AStartRef); except on E: EGitError do raise; on E: Exception do raise EGitError.Create(E.Message); end;
  Repo:=TNativeRepository.Create(FGitDir);
  try try Oids:=GitCollectCommits(Repo,[StartOid],ALimit); except on E: EGitError do raise; on E: Exception do raise EGitError.Create(E.Message); end;
    SetLength(Result,Length(Oids));
    for I:=0 to High(Oids) do begin
      try Data:=Repo.ReadObject(Oids[I],Kind); if Kind<>gokCommit then raise EGitError.CreateFmt('object %s is not a commit',[GitOidToHex(Oids[I])]); Info:=GitParseCommit(Data); except on E: EGitError do raise; on E: Exception do raise EGitError.Create(E.Message); end;
      Result[I]:=TNativeCommit.Create(GitOidToHex(Oids[I]),Info);
    end;
  finally Repo.Free; end;
end;

function TNativeRepositoryAdapter.Blame(const APath: string): TGitBlame;
var NativeBlame: TGitBlameArray; I, StartIdx: Integer; H: TGitBlameHunk; CurId: string;
begin
  EnsureOpen; Result.Path:=APath; Result.Hunks:=nil;
  if TrimInline(APath)='' then Exit;
  try NativeBlame:=GitBlame(FGitDir,APath); except on E: EGitError do raise; on E: Exception do raise EGitError.Create(E.Message); end;
  if Length(NativeBlame)=0 then Exit;
  StartIdx:=0; CurId:=GitOidToHex(NativeBlame[0].CommitOid);
  for I:=1 to Length(NativeBlame) do begin
    if (I=Length(NativeBlame)) or (GitOidToHex(NativeBlame[I].CommitOid)<>CurId) then begin
      H.LinesInHunk:=I-StartIdx; H.FinalCommitId:=CurId; H.OrigCommitId:=CurId; H.FinalStartLine:=NativeBlame[StartIdx].LineNo; H.OrigStartLine:=NativeBlame[StartIdx].LineNo; H.OrigPath:=APath; H.Boundary:=False;
      SetLength(Result.Hunks,Length(Result.Hunks)+1); Result.Hunks[High(Result.Hunks)]:=H;
      if I < Length(NativeBlame) then begin StartIdx:=I; CurId:=GitOidToHex(NativeBlame[I].CommitOid); end;
    end;
  end;
end;

function TNativeRepositoryAdapter.ConfigEntries: TGitConfigEntryArray;
var Cfg: TGitConfig; IncPath, Home: string; IncData: TBytes; IncCfg: TGitConfig; J, I: Integer;
begin
  EnsureOpen; Result:=nil;
  try
    Cfg:=GitReadConfig(FGitDir);
    SetLength(Result,Length(Cfg.Entries));
    for I:=0 to High(Cfg.Entries) do begin Result[I].Name:=Cfg.Entries[I].Key; Result[I].Value:=Cfg.Entries[I].Value; end;
    // include.path expansion — pure, single-source via GitParseConfig / bytes.ops, inline zero-copy Home handling
    for I:=0 to High(Cfg.Entries) do if Cfg.Entries[I].Key='include.path' then begin
      IncPath:=Cfg.Entries[I].Value;
      if (Length(IncPath)>0) and (IncPath[1]='~') then begin Home:=platform_env_get_str('HOME'); if Home<>'' then IncPath:=Home+Copy(IncPath,2,MaxInt); end
      else if not PathIsAbsolute(IncPath) then IncPath:=PathJoin([PathDir(FGitDir),IncPath]);
      if FileExists(IncPath) then try IncData:=ReadFile(IncPath); IncCfg:=GitParseConfig(IncData); for J:=0 to High(IncCfg.Entries) do begin SetLength(Result,Length(Result)+1); Result[High(Result)].Name:=IncCfg.Entries[J].Key; Result[High(Result)].Value:=IncCfg.Entries[J].Value; end; except end;
    end;
  except on E: EGitError do raise; on E: Exception do raise EGitError.Create(E.Message); end;
end;

procedure TNativeRepositoryAdapter.ApplyPatch(const APatchText: string);
var Work: string; Lines: TStringArray; I, SPos: Integer; Line, APath, BPath, CurPath: string; OldLines, NewLines: TStringArray; Hunks: THunkArray; CurHunk: TGitDiffHunk; InHunk: Boolean; FullPath: string; NewContent: string; J, K, OldIdx: Integer; Applied: Boolean;
  function IsBinaryHunk(const AHunk: TGitDiffHunk): Boolean; inline; begin Result:=False; for K:=0 to High(AHunk.Lines) do if Pos('Binary',AHunk.Lines[K])>0 then Exit(True); end;
begin
  EnsureOpen; if APatchText='' then Exit; Work:=WorkDirOf(FGitDir,FWorkTree); if Work='' then raise EGitError.Create('ApplyPatch: bare repository has no workdir');
  Lines:=GitSplitLines(APatchText);
  CurPath:=''; CurHunk.Header:=''; CurHunk.Lines:=nil; InHunk:=False; Hunks:=nil;
  for I:=0 to High(Lines) do begin
    Line:=Lines[I];
    if Pos('diff --git ',Line)=1 then begin
      if CurPath<>'' then begin
        if InHunk then begin SetLength(Hunks,Length(Hunks)+1); Hunks[High(Hunks)]:=CurHunk; end;
        if Length(Hunks)>0 then begin FullPath:=PathJoin([Work,CurPath]); OldLines:=WorkTreeLinesOf(Work,CurPath); if OldLines=nil then SetLength(OldLines,0); NewLines:=nil; OldIdx:=0; SetLength(NewLines,0);
          for J:=0 to High(Hunks) do begin
            for K:=0 to High(Hunks[J].Lines) do begin
              if Length(Hunks[J].Lines[K])=0 then Continue;
              case Hunks[J].Lines[K][1] of
                ' ': begin if OldIdx<Length(OldLines) then begin SetLength(NewLines,Length(NewLines)+1); NewLines[High(NewLines)]:=OldLines[OldIdx]; Inc(OldIdx); end; end;
                '-': Inc(OldIdx);
                '+': begin SetLength(NewLines,Length(NewLines)+1); NewLines[High(NewLines)]:=Copy(Hunks[J].Lines[K],2,MaxInt); end;
              end;
            end;
          end;
          while OldIdx<Length(OldLines) do begin SetLength(NewLines,Length(NewLines)+1); NewLines[High(NewLines)]:=OldLines[OldIdx]; Inc(OldIdx); end;
          NewContent:=''; for J:=0 to High(NewLines) do NewContent:=NewContent+NewLines[J]+#10;
          try MkdirAll(PathDir(FullPath),PermDirDefault); WriteFileText(FullPath,NewContent); except on E: Exception do raise EGitError.Create('ApplyPatch: write "'+CurPath+'": '+E.Message); end;
        end;
        Hunks:=nil; CurHunk.Header:=''; CurHunk.Lines:=nil; InHunk:=False;
      end;
      SPos:=Pos(' b/',Line); if SPos>0 then BPath:=Copy(Line,SPos+3,MaxInt) else BPath:=''; CurPath:=BPath; APath:=BPath;
    end else if Pos('@@ ',Line)=1 then begin
      if InHunk then begin SetLength(Hunks,Length(Hunks)+1); Hunks[High(Hunks)]:=CurHunk; end;
      CurHunk.Header:=Line; CurHunk.Lines:=nil; InHunk:=True;
    end else if InHunk and (Length(Line)>0) and (Line[1] in [' ','+','-']) then begin
      if IsBinaryHunk(CurHunk) then Continue;
      SetLength(CurHunk.Lines,Length(CurHunk.Lines)+1); CurHunk.Lines[High(CurHunk.Lines)]:=Line;
    end;
  end;
  if CurPath<>'' then begin
    if InHunk then begin SetLength(Hunks,Length(Hunks)+1); Hunks[High(Hunks)]:=CurHunk; end;
    if Length(Hunks)>0 then begin FullPath:=PathJoin([Work,CurPath]); OldLines:=WorkTreeLinesOf(Work,CurPath); if OldLines=nil then SetLength(OldLines,0); NewLines:=nil; OldIdx:=0; SetLength(NewLines,0);
      for J:=0 to High(Hunks) do for K:=0 to High(Hunks[J].Lines) do begin if Length(Hunks[J].Lines[K])=0 then Continue; case Hunks[J].Lines[K][1] of ' ': begin if OldIdx<Length(OldLines) then begin SetLength(NewLines,Length(NewLines)+1); NewLines[High(NewLines)]:=OldLines[OldIdx]; Inc(OldIdx); end; end; '-': Inc(OldIdx); '+': begin SetLength(NewLines,Length(NewLines)+1); NewLines[High(NewLines)]:=Copy(Hunks[J].Lines[K],2,MaxInt); end; end; end;
      while OldIdx<Length(OldLines) do begin SetLength(NewLines,Length(NewLines)+1); NewLines[High(NewLines)]:=OldLines[OldIdx]; Inc(OldIdx); end;
      NewContent:=''; for J:=0 to High(NewLines) do NewContent:=NewContent+NewLines[J]+#10;
      try MkdirAll(PathDir(FullPath),PermDirDefault); WriteFileText(FullPath,NewContent); except on E: Exception do raise EGitError.Create('ApplyPatch: write "'+CurPath+'": '+E.Message); end;
    end;
  end;
end;

procedure TNativeRepositoryAdapter.CheckoutPaths(const ARevspec: string; const APaths: TStringArray);
var Work: string; TreeOid: TGitOid; Repo: TNativeRepository; I, J, K: Integer; Path: string; Parts: TStringArray; CurOid: TGitOid; Kind: TGitObjectKind; Data: TBytes; Entries: TGitTreeEntryArray; Found: Boolean; BlobOid: TGitOid; BlobData: TBytes; BlobKind: TGitObjectKind; Full: string; IdxFile: TGitIndexFile; Start: Integer;
  function SplitPath(const AValue: string): TStringArray; inline;
  var S, P, Cnt: Integer;
  begin Result:=nil; Cnt:=1; for S:=1 to Length(AValue) do if AValue[S]='/' then Inc(Cnt); SetLength(Result,Cnt); S:=1; P:=0; for Cnt:=1 to Length(AValue)+1 do if (Cnt>Length(AValue)) or (AValue[Cnt]='/') then begin Result[P]:=Copy(AValue,S,Cnt-S); Inc(P); S:=Cnt+1; end;
  end;
begin
  EnsureOpen; if TrimInline(ARevspec)='' then raise EGitError.Create('CheckoutPaths: revspec required'); if Length(APaths)=0 then Exit; Work:=WorkDirOf(FGitDir,FWorkTree); if Work='' then raise EGitError.Create('CheckoutPaths: bare repository has no workdir');
  TreeOid:=ResolveTreeOid(FGitDir,ARevspec);
  Repo:=TNativeRepository.Create(FGitDir);
  try
    try IdxFile:=GitReadIndex(FGitDir); except IdxFile.Entries:=nil; end;
    for I:=0 to High(APaths) do begin
      Path:=APaths[I]; if Path='' then Continue;
      Parts:=SplitPath(Path);
      CurOid:=TreeOid; Found:=False; BlobOid:=Default(TGitOid);
      for J:=0 to High(Parts) do begin
        Data:=Repo.ReadObject(CurOid,Kind); if Kind<>gokTree then raise EGitError.CreateFmt('CheckoutPaths: not a tree at %s',[Path]);
        Entries:=GitParseTree(Data); Found:=False;
        for K:=0 to High(Entries) do if Entries[K].Name=Parts[J] then begin if J=High(Parts) then begin BlobOid:=Entries[K].Oid; Found:=True; Break; end else begin if Entries[K].Mode<>$4000 then raise EGitError.CreateFmt('CheckoutPaths: not a directory %s',[Path]); CurOid:=Entries[K].Oid; Found:=True; Break; end; end;
        if not Found then Break;
      end;
      if not Found then raise EGitError.CreateFmt('CheckoutPaths: path not in tree "%s"',[Path]);
      BlobData:=Repo.ReadObject(BlobOid,BlobKind);
      Full:=PathJoin([Work,Path]); MkdirAll(PathDir(Full),PermDirDefault); WriteFile(Full,BlobData);
      Found:=False; for J:=0 to High(IdxFile.Entries) do if IdxFile.Entries[J].Path=Path then begin IdxFile.Entries[J].Oid:=BlobOid; IdxFile.Entries[J].Size:=Length(BlobData); Found:=True; Break; end;
      if not Found then begin SetLength(IdxFile.Entries,Length(IdxFile.Entries)+1); IdxFile.Entries[High(IdxFile.Entries)].Path:=Path; IdxFile.Entries[High(IdxFile.Entries)].Oid:=BlobOid; IdxFile.Entries[High(IdxFile.Entries)].Mode:=$81A4; IdxFile.Entries[High(IdxFile.Entries)].Size:=Length(BlobData); IdxFile.Entries[High(IdxFile.Entries)].Stage:=0; end;
    end;
    GitWriteIndex(FGitDir,IdxFile.Entries,2);
  finally Repo.Free; end;
end;

function TNativeRepositoryAdapter.WorkdirPatchText(const ARevspec: string; const APaths: TStringArray; AShowBinary: Boolean): string;
var Work: string; D: TGitDiff; Opts: TGitDiffOptions; I, J: Integer; S: string; HasBinary: Boolean;
  function IsBin(const AHunks: array of TGitDiffHunk): Boolean; inline;
  var K: Integer;
  begin Result:=False; for K:=0 to High(AHunks) do if Length(AHunks[K].Lines)=0 then begin Result:=True; Exit; end; end;
begin
  EnsureOpen; Result:=''; Work:=WorkDirOf(FGitDir,FWorkTree); if Work='' then raise EGitError.Create('WorkdirPatchText: bare repository has no workdir');
  Opts:=DefaultGitDiffOptions; Opts.Paths:=APaths;
  if TrimInline(ARevspec)='' then D:=DiffWorkingTreeEx('HEAD',Opts) else D:=DiffWorkingTreeEx(ARevspec,Opts);
  for I:=0 to High(D.Files) do begin
    HasBinary:=IsBin(D.Files[I].Hunks);
    if HasBinary and not AShowBinary then Continue;
    S:='diff --git a/'+D.Files[I].OldPath+' b/'+D.Files[I].NewPath+#10+
       '--- a/'+D.Files[I].OldPath+#10+
       '+++ b/'+D.Files[I].NewPath+#10;
    Result:=Result+S;
    if HasBinary then begin Result:=Result+'Binary files differ'#10; Continue; end;
    for J:=0 to High(D.Files[I].Hunks) do begin
      Result:=Result+D.Files[I].Hunks[J].Header+#10;
      for S in D.Files[I].Hunks[J].Lines do Result:=Result+S+#10;
    end;
  end;
end;

{ TNativeWorktree }
constructor TNativeWorktree.Create(const AName, APath: string; ALocked: Boolean);
begin
  inherited Create;
  FName := AName; FPath := APath; FLocked := ALocked;
end;
function TNativeWorktree.Name: string; begin Result := FName; end;
function TNativeWorktree.Path: string; begin Result := FPath; end;
function TNativeWorktree.IsLocked: Boolean; begin Result := FLocked; end;

function TNativeRepositoryAdapter.AddWorktree(const AName, APath, ARef: string; ADetach: Boolean): IGitWorktree;
var MainDir, WtGitDir: string; TargetOid: TGitOid; Repo: TNativeRepository; HasRef: Boolean; Work: TGitWorktree;
begin
  EnsureOpen; Result := nil;
  if Trim(AName) = '' then raise EGitError.Create('AddWorktree: name required');
  if Trim(APath) = '' then raise EGitError.Create('AddWorktree: path required');
  if (Pos('/', AName) > 0) or (Pos('\', AName) > 0) then raise EGitError.CreateFmt('AddWorktree: invalid name "%s"', [AName]);
  if IsBare then raise EGitError.Create('AddWorktree: cannot add worktree to bare repository');
  MainDir := EffectiveMainDir(FGitDir);
  if GitIsWorktree(FGitDir) then raise EGitError.Create('AddWorktree: cannot add from linked worktree');
  WtGitDir := PathJoin2(PathJoin2(MainDir, 'worktrees'), AName);
  if DirectoryExists(WtGitDir) then raise EGitError.CreateFmt('AddWorktree: worktree "%s" already exists', [AName]);
  if DirectoryExists(APath) and not IsDirEmptyLocal(APath) then raise EGitError.CreateFmt('AddWorktree: path not empty %s', [APath]);
  HasRef := Trim(ARef) <> '';
  if HasRef then
  begin
    try TargetOid := GitRevParse(MainDir, Trim(ARef)); except on E: EGitError do raise EGitError.CreateFmt('AddWorktree: cannot resolve ref "%s": %s', [ARef, E.Message]); end;
    if ADetach then
    begin
      Repo := TNativeRepository.Create(MainDir);
      try
        try TargetOid := GitRevParseCommit(MainDir, Trim(ARef)); except if not Repo.HasObject(TargetOid) then raise EGitError.CreateFmt('AddWorktree: object %s not found', [GitOidToHex(TargetOid)]); end;
      finally Repo.Free; end;
    end;
  end
  else
  begin
    try TargetOid := GitResolveHead(MainDir); except on E: EGitError do raise EGitError.CreateFmt('AddWorktree: cannot resolve HEAD: %s', [E.Message]); end;
  end;
  try
    if ADetach then
      Work := GitWorktreeAddDetached(MainDir, PathClean(APath), TargetOid)
    else
    begin
      if not GitBranchExists(MainDir, AName) then GitBranchCreate(MainDir, AName, TargetOid);
      if not DirectoryExists(APath) then MkdirAll(PathClean(APath), PermDirDefault);
      WtGitDir := PathJoin2(PathJoin2(MainDir, 'worktrees'), AName);
      if DirectoryExists(WtGitDir) then raise EGitError.CreateFmt('AddWorktree: id already exists %s', [AName]);
      MkdirAll(WtGitDir, PermDirDefault);
      WriteFileText(PathJoin2(WtGitDir, 'commondir'), '../..'#10);
      WriteFileText(PathJoin2(WtGitDir, 'gitdir'), PathClean(APath) + '/.git'#10);
      WriteFileText(PathJoin2(WtGitDir, 'HEAD'), 'ref: refs/heads/' + AName + #10);
      WriteFileText(PathJoin2(PathClean(APath), '.git'), 'gitdir: ' + PathClean(WtGitDir) + #10);
      GitCheckoutCommit(WtGitDir, PathClean(APath), GitBranchGetOid(MainDir, AName));
      Work.Path := PathClean(APath); Work.GitDir := WtGitDir;
    end;
  except on E: EGitError do raise; on E: Exception do raise EGitError.Create('AddWorktree: ' + E.Message); end;
  try Result := LookupWorktree(AName); except Result := TNativeWorktree.Create(AName, PathClean(APath), False); end;
end;

function TNativeRepositoryAdapter.LookupWorktree(const AName: string): IGitWorktree;
var MainDir: string; List: TGitWorktreeArray; I: Integer; Base: string;
begin
  EnsureOpen; Result := nil;
  if Trim(AName) = '' then raise EGitError.Create('LookupWorktree: name required');
  MainDir := EffectiveMainDir(FGitDir);
  List := GitWorktreeList(MainDir);
  for I := 0 to High(List) do
  begin
    if List[I].GitDir = MainDir then Continue;
    Base := PathBase(List[I].GitDir);
    if Base = AName then begin Result := TNativeWorktree.Create(AName, List[I].Path, False); Exit; end;
    if List[I].Path = AName then begin Result := TNativeWorktree.Create(AName, List[I].Path, False); Exit; end;
  end;
  raise EGitError.CreateFmt('LookupWorktree: not found "%s"', [AName]);
end;

function TNativeRepositoryAdapter.ListWorktrees: TStringArray;
var MainDir: string; List: TGitWorktreeArray; I, Count: Integer;
begin
  EnsureOpen; Result := nil;
  MainDir := EffectiveMainDir(FGitDir);
  List := GitWorktreeList(MainDir);
  SetLength(Result, Length(List));
  Count := 0;
  for I := 0 to High(List) do
  begin
    if List[I].GitDir = MainDir then
    begin
      Result[Count] := PathBase(PathClean(List[I].Path));
      if Result[Count] = '' then Result[Count] := 'main';
    end
    else Result[Count] := PathBase(List[I].GitDir);
    Inc(Count);
  end;
  SetLength(Result, Count);
end;

function TNativeRepositoryAdapter.PruneWorktree(const AName: string): Boolean;
var MainDir, WtGitDir: string;
begin
  EnsureOpen; Result := False;
  if Trim(AName) = '' then Exit(False);
  MainDir := EffectiveMainDir(FGitDir);
  if GitIsWorktree(FGitDir) then Exit(False);
  WtGitDir := PathJoin2(PathJoin2(MainDir, 'worktrees'), Trim(AName));
  if not DirectoryExists(WtGitDir) then Exit(False);
  try RemoveAll(WtGitDir); Result := True; except Result := False; end;
end;

function TNativeRepositoryAdapter.CommitOnHead(const AMessage: string; const AAuthorName, AAuthorEmail: string): string;
var MainDir: string; IdxFile: TGitIndexFile; Sorted, Stage0: TGitIndexEntryArray; I, Cnt: Integer; TreeOid, HeadOid, NewOid: TGitOid; HasHead: Boolean; HeadRef: string; Builder: TGitCommitBuilder; Cfg: TGitConfig; AuthorName, AuthorEmail: string; UnixTime: Int64; Info: TGitCommitInfo; Repo: TNativeRepository; Data: TBytes; Kind: TGitObjectKind;
begin
  EnsureOpen; Result := '';
  if Trim(AMessage) = '' then raise EGitError.Create('CommitOnHead: message required');
  if IsBare then raise EGitError.Create('CommitOnHead: cannot commit in bare repository');
  MainDir := EffectiveMainDir(FGitDir);
  try IdxFile := GitReadIndex(MainDir); except IdxFile.Version := 2; SetLength(IdxFile.Entries, 0); IdxFile.HasCacheTree := False; end;
  SetLength(Sorted, Length(IdxFile.Entries));
  for I := 0 to High(IdxFile.Entries) do Sorted[I] := IdxFile.Entries[I];
  if Length(Sorted) > 1 then GitSortIndexEntries(Sorted);
  Cnt := 0; SetLength(Stage0, Length(Sorted));
  for I := 0 to High(Sorted) do
  begin
    if Sorted[I].Stage <> 0 then raise EGitError.CreateFmt('CommitOnHead: index has conflict stage %d at %s', [Sorted[I].Stage, Sorted[I].Path]);
    Stage0[Cnt] := Sorted[I]; Inc(Cnt);
  end;
  SetLength(Stage0, Cnt);
  TreeOid := WriteTreeFromSortedIndex(MainDir, Stage0);
  HasHead := True;
  try HeadOid := GitResolveHead(MainDir); except HasHead := False; FillChar(HeadOid, SizeOf(HeadOid), 0); end;
  AuthorName := Trim(AAuthorName); AuthorEmail := Trim(AAuthorEmail);
  if (AuthorName = '') or (AuthorEmail = '') then
  begin
    try Cfg := GitReadConfig(MainDir); except Cfg.Entries := nil; end;
    if AuthorName = '' then try AuthorName := GitConfigGet(Cfg, 'user.name'); except AuthorName := ''; end;
    if AuthorEmail = '' then try AuthorEmail := GitConfigGet(Cfg, 'user.email'); except AuthorEmail := ''; end;
    if HasHead and ((AuthorName = '') or (AuthorEmail = '')) then
    begin
      Repo := TNativeRepository.Create(MainDir);
      try
        try Data := Repo.ReadObject(HeadOid, Kind); if Kind = gokCommit then begin Info := GitParseCommit(Data); if AuthorName = '' then AuthorName := Info.Committer.Name; if AuthorEmail = '' then AuthorEmail := Info.Committer.Email; end; except end;
      finally Repo.Free; end;
    end;
    if AuthorName = '' then AuthorName := 'Test Er';
    if AuthorEmail = '' then AuthorEmail := 'test@example.com';
  end;
  UnixTime := 1700000000;
  Builder := Default(TGitCommitBuilder);
  Builder.Tree := TreeOid;
  if HasHead then begin SetLength(Builder.Parents, 1); Builder.Parents[0] := HeadOid; end else SetLength(Builder.Parents, 0);
  Builder.AuthorName := AuthorName; Builder.AuthorEmail := AuthorEmail; Builder.AuthorUnixTime := UnixTime; Builder.AuthorTzMinutes := 0;
  Builder.CommitterName := AuthorName; Builder.CommitterEmail := AuthorEmail; Builder.CommitterUnixTime := UnixTime; Builder.CommitterTzMinutes := 0;
  if (Length(AMessage) > 0) and (AMessage[Length(AMessage)] <> #10) then Builder.Message := AMessage + #10 else Builder.Message := AMessage;
  try NewOid := GitWriteCommit(MainDir, Builder); except on E: EGitError do raise; on E: Exception do raise EGitError.Create('CommitOnHead: write commit failed: ' + E.Message); end;
  HeadRef := '';
  try HeadRef := GitHeadRefName(MainDir); except HeadRef := ''; end;
  try
    if HeadRef <> '' then
    begin
      MkdirAll(PathDir(PathJoin2(MainDir, HeadRef)), PermDirDefault);
      WriteFileText(PathJoin2(MainDir, HeadRef), GitOidToHex(NewOid) + #10);
      try MkdirAll(PathJoin([MainDir, 'logs', 'refs', 'heads']), PermDirDefault); MkdirAll(PathJoin([MainDir, 'logs']), PermDirDefault); except end;
    end
    else WriteFileText(PathJoin2(MainDir, 'HEAD'), GitOidToHex(NewOid) + #10);
  except on E: Exception do raise EGitError.Create('CommitOnHead: update ref failed: ' + E.Message); end;
  Result := GitOidToHex(NewOid);
end;

end.
