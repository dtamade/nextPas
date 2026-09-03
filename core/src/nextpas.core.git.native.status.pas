unit nextpas.core.git.native.status;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.hash.sha1,
  nextpas.core.git.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.loose,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.index,
  nextpas.core.git.native.ignore,
  nextpas.core.git.native.config;

{ Status: HEAD<->index / index<->worktree + untracked (porcelain groups) }

type
  // single source via base — eliminates L2:base vs native dual track, reuse bytes.ops inline zero-copy
  TGitStatusCode = nextpas.core.git.base.TGitStatusCode;

const
  // re-export base vocab for qualified native.status.gsc* consumers (staging facade) — inline zero-copy, no alloc
  gscUnmodified  = nextpas.core.git.base.gscUnmodified;
  gscAdded       = nextpas.core.git.base.gscAdded;
  gscModified    = nextpas.core.git.base.gscModified;
  gscDeleted     = nextpas.core.git.base.gscDeleted;
  gscTypeChanged = nextpas.core.git.base.gscTypeChanged;
  gscUnmerged    = nextpas.core.git.base.gscUnmerged;
  gscUntracked   = nextpas.core.git.base.gscUntracked;
  gscRenamed     = nextpas.core.git.base.gscRenamed;
  gscCopied      = nextpas.core.git.base.gscCopied;

type
  TGitNativeStatusEntry = record
    Path: string;
    OldPath: string;
    Similarity: Byte;
    HeadCode: TGitStatusCode;
    WorkCode: TGitStatusCode;
  end;
  TGitNativeStatusArray = array of TGitNativeStatusEntry;

function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean): TGitNativeStatusArray; overload;
function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean; AFindRenames: Boolean;
  ARenameThreshold: Integer): TGitNativeStatusArray; overload;
function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean; AFindRenames: Boolean;
  ARenameThreshold: Integer; AFindCopies: Boolean;
  ACopyThreshold: Integer): TGitNativeStatusArray; overload;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.hash.intf,
  nextpas.core.fs.stream,
  nextpas.core.collections.algorithms,
  nextpas.core.collections.arr.sort,
  nextpas.core.platform.env,
  nextpas.core.git.native.util,
  nextpas.core.git.native.status.similarity;

type
  TPathOid = nextpas.core.git.native.status.similarity.TPathOid;
  TPathOidArray = nextpas.core.git.native.status.similarity.TPathOidArray;
  TRenameCandidate = nextpas.core.git.native.status.similarity.TRenameCandidate;
  TRenameCandidateArray = nextpas.core.git.native.status.similarity.TRenameCandidateArray;
  TBlobSig = nextpas.core.git.native.status.similarity.TBlobSig;
  TBlobSigArray = nextpas.core.git.native.status.similarity.TBlobSigArray;

const
  CModeDir = $4000;
  CModeRegular = $81A4;
  CModeExec = $81ED;
  CModeSymlink = $A000;
  CModeGitlink = $E000;
  CMaxFlattenDepth = 32;

function ComparePathOid(const A, B: TPathOid; AData: Pointer): SizeInt;
var
  LA, LB: TByteSpan;
begin
  if A.Path = B.Path then Exit(0);
  if A.Path = '' then LA := TByteSpan.Empty
  else LA := TByteSpan.Create(PByte(@A.Path[1]), SizeUInt(Length(A.Path)));
  if B.Path = '' then LB := TByteSpan.Empty
  else LB := TByteSpan.Create(PByte(@B.Path[1]), SizeUInt(Length(B.Path)));
  Result := SpanCompare(LA, LB);
end;

function CompareString(const A, B: string; AData: Pointer): SizeInt;
var
  LA, LB: TByteSpan;
begin
  if A = B then Exit(0);
  if A = '' then LA := TByteSpan.Empty
  else LA := TByteSpan.Create(PByte(@A[1]), SizeUInt(Length(A)));
  if B = '' then LB := TByteSpan.Empty
  else LB := TByteSpan.Create(PByte(@B[1]), SizeUInt(Length(B)));
  Result := SpanCompare(LA, LB);
end;

procedure SortPathOids(var AList: TPathOidArray);
begin
  if Length(AList) < 2 then Exit;
  specialize Sort<TPathOid>(AList, @ComparePathOid, nil);
end;

procedure SortStrings(var AList: TStringArray);
begin
  if Length(AList) < 2 then Exit;
  specialize Sort<string>(AList, @CompareString, nil);
end;

function SortedHasString(const ASorted: TStringArray; const AValue: string): Boolean;
var
  Idx: SizeInt;
begin
  Result := specialize BinarySearch<string>(ASorted, AValue, @CompareString, nil, Idx);
end;

procedure FlattenTree(ARepo: TNativeRepository; const ATreeOid: TGitOid;
  const APrefix: string; var AOut: TPathOidArray);
var
  LCount, LCap: SizeInt;
  procedure DoFlatten(const ATreeOidInner: TGitOid; const APrefixInner: string; ADepth: Integer);
  var
    Data: TBytes;
    Kind: TGitObjectKind;
    Entries: TGitTreeEntryArray;
    I: SizeInt;
  begin
    if ADepth > CMaxFlattenDepth then
      raise EGitError.Create('tree depth exceeds limit');
    Data := ARepo.ReadObject(ATreeOidInner, Kind);
    if Kind <> gokTree then
      raise EGitError.Create('head commit points at a non-tree object');
    Entries := GitParseTree(Data);
    for I := 0 to High(Entries) do
    begin
      if Entries[I].Mode = CModeDir then
        DoFlatten(Entries[I].Oid, APrefixInner + Entries[I].Name + '/', ADepth + 1)
      else
      begin
        if LCount = LCap then
        begin
          LCap := SizeInt(GrowArrayCapacity(SizeUInt(LCap), SizeUInt(LCount + 1)));
          SetLength(AOut, LCap);
        end;
        AOut[LCount].Path := APrefixInner + Entries[I].Name;
        AOut[LCount].Oid := Entries[I].Oid;
        AOut[LCount].Mode := Entries[I].Mode;
        Inc(LCount);
      end;
    end;
  end;
begin
  LCount := Length(AOut);
  LCap := Length(AOut);
  DoFlatten(ATreeOid, APrefix, 0);
  if LCap <> LCount then
    SetLength(AOut, LCount);
end;

function ModeClassOf(AMode: Cardinal): Integer;
begin
  case AMode of
    CModeSymlink: Result := 1;
    CModeGitlink: Result := 2;
    CModeDir: Result := 3;
  else
    Result := 0;
  end;
end;

function WorkCodeFor(const AWorkTree: string; const AEntry: TGitIndexEntry): TGitStatusCode;
var
  Full: string;
  Info: TFileInfo;
  WorkMode: Cardinal;
  WorkOid: TGitOid;
  EntryKind: TGitObjectKind;
begin
  Full := PathJoin([AWorkTree, AEntry.Path]);
  try
    if not Exists(Full) then Exit(gscDeleted);
  except
    Exit(gscDeleted);
  end;
  try
    Info := Lstat(Full);
  except
    Exit(gscDeleted);
  end;
  EntryKind := GitKindFromMode(AEntry.Mode);
  if EntryKind = gokCommit then
  begin
    if Info.IsDir then Exit(gscUnmodified);
    Exit(gscDeleted);
  end;
  if Info.IsDir then Exit(gscTypeChanged);
  if Info.IsSymlink then
  begin
    try
      WorkOid := GitHashObject(gokBlob, GitStringToBytes(Readlink(Full)));
    except
      Exit(gscDeleted);
    end;
    if not GitOidSame(WorkOid, AEntry.Oid) then Exit(gscModified);
    if AEntry.Mode <> CModeSymlink then Exit(gscTypeChanged);
    Exit(gscUnmodified);
  end;
  WorkMode := CModeRegular;
  if (Info.Permission and (PermOwnerExec or PermGroupExec or PermOtherExec)) <> 0 then
    WorkMode := CModeExec;
  if ModeClassOf(AEntry.Mode) <> 0 then Exit(gscTypeChanged);
  if Info.Size <> Int64(AEntry.Size) then Exit(gscModified);
  if Info.ModTime = Int64(AEntry.MTimeSec) * 1000000000 + Int64(AEntry.MTimeNSec) then
    Exit(gscUnmodified);
  if WorkMode <> AEntry.Mode then Exit(gscModified);
  Result := gscModified;
end;

var
  GIgnoreCache: array of record Path: string; Text: string; end;

function GetIgnoreTextCached(const APath: string): string;
var
  I: Integer;
begin
  for I := 0 to High(GIgnoreCache) do
    if GIgnoreCache[I].Path = APath then Exit(GIgnoreCache[I].Text);
  if not Exists(APath) then Exit('');
  try
    Result := ReadFileText(APath);
  except
    Result := '';
  end;
  I := Length(GIgnoreCache);
  SetLength(GIgnoreCache, I + 1);
  GIgnoreCache[I].Path := APath;
  GIgnoreCache[I].Text := Result;
end;

procedure CollectUntracked(const AWorkTree, ADirRel: string;
  const ATrackedSorted: TStringArray; AIgnore: TGitIgnoreMatcher;
  var AOut: TStringArray);
var
  DirAbs, Rel, IgnoreFile: string;
  Items: TDirEntryArray;
  HaveIgnore: Boolean;
  I: SizeInt;
  LCount, LCap: SizeInt;
  IgnoreText: string;
begin
  if ADirRel = '' then DirAbs := AWorkTree else DirAbs := PathJoin([AWorkTree, ADirRel]);
  IgnoreFile := PathJoin([DirAbs, '.gitignore']);
  HaveIgnore := Exists(IgnoreFile);
  if HaveIgnore then
  begin
    IgnoreText := GetIgnoreTextCached(IgnoreFile);
    if IgnoreText <> '' then
      AIgnore.PushSource(ADirRel, IgnoreText)
    else if Exists(IgnoreFile) then
      AIgnore.PushSource(ADirRel, '')
    else
      HaveIgnore := False;
    if (IgnoreText = '') and HaveIgnore then
      if not Exists(IgnoreFile) then HaveIgnore := False;
  end;
  LCount := Length(AOut);
  LCap := LCount;
  try
    Items := ReadDir(DirAbs);
    for I := 0 to High(Items) do
    begin
      if Items[I].Name = '.git' then Continue;
      if ADirRel = '' then Rel := Items[I].Name else Rel := PathJoin([ADirRel, Items[I].Name]);
      if Items[I].IsDir then
      begin
        if AIgnore.IsIgnored(Rel, True) then Continue;
        if Length(AOut) <> LCount then SetLength(AOut, LCount);
        CollectUntracked(AWorkTree, Rel, ATrackedSorted, AIgnore, AOut);
        LCount := Length(AOut);
        LCap := LCount;
      end
      else if (not SortedHasString(ATrackedSorted, Rel)) and (not AIgnore.IsIgnored(Rel, False)) then
      begin
        if LCount = LCap then
        begin
          LCap := SizeInt(GrowArrayCapacity(SizeUInt(LCap), SizeUInt(LCount + 1)));
          SetLength(AOut, LCap);
        end;
        AOut[LCount] := Rel;
        Inc(LCount);
      end;
    end;
    if LCap <> LCount then SetLength(AOut, LCount);
  finally
    if Length(AOut) <> LCount then SetLength(AOut, LCount);
    if HaveIgnore then AIgnore.PopSource;
  end;
end;

procedure AppendStatusFast(var AOut: TGitNativeStatusArray; var ACount, ACap: SizeInt;
  const APath: string; AHeadCode, AWorkCode: TGitStatusCode); inline;
begin
  if (AHeadCode = gscUnmodified) and (AWorkCode = gscUnmodified) then Exit;
  if ACount = ACap then
  begin
    ACap := SizeInt(GrowArrayCapacity(SizeUInt(ACap), SizeUInt(ACount + 1)));
    SetLength(AOut, ACap);
  end;
  AOut[ACount].Path := APath;
  AOut[ACount].OldPath := '';
  AOut[ACount].Similarity := 0;
  AOut[ACount].HeadCode := AHeadCode;
  AOut[ACount].WorkCode := AWorkCode;
  Inc(ACount);
end;

procedure AppendRenamedFast(var AOut: TGitNativeStatusArray; var ACount, ACap: SizeInt;
  const AOldPath, ANewPath: string; ASimilarity: Byte; AWorkCode: TGitStatusCode); inline;
begin
  if ACount = ACap then
  begin
    ACap := SizeInt(GrowArrayCapacity(SizeUInt(ACap), SizeUInt(ACount + 1)));
    SetLength(AOut, ACap);
  end;
  AOut[ACount].Path := ANewPath;
  AOut[ACount].OldPath := AOldPath;
  AOut[ACount].Similarity := ASimilarity;
  AOut[ACount].HeadCode := gscRenamed;
  AOut[ACount].WorkCode := AWorkCode;
  Inc(ACount);
end;

procedure AppendCopiedFast(var AOut: TGitNativeStatusArray; var ACount, ACap: SizeInt;
  const AOldPath, ANewPath: string; ASimilarity: Byte; AWorkCode: TGitStatusCode); inline;
begin
  if ACount = ACap then
  begin
    ACap := SizeInt(GrowArrayCapacity(SizeUInt(ACap), SizeUInt(ACount + 1)));
    SetLength(AOut, ACap);
  end;
  AOut[ACount].Path := ANewPath;
  AOut[ACount].OldPath := AOldPath;
  AOut[ACount].Similarity := ASimilarity;
  AOut[ACount].HeadCode := gscCopied;
  AOut[ACount].WorkCode := AWorkCode;
  Inc(ACount);
end;

procedure AppendUntrackedGroup(var AResult: TGitNativeStatusArray;
  const AExtra: TGitNativeStatusArray);
var
  OldLen, I: Integer;
begin
  OldLen := Length(AResult);
  SetLength(AResult, OldLen + Length(AExtra));
  for I := 0 to High(AExtra) do
    AResult[OldLen + I] := AExtra[I];
end;

procedure PushInfoAndGlobalExcludes(AIgnore: TGitIgnoreMatcher; const AGitDir: string);
var
  ExcludeFile: string;
  Cfg: TGitConfig;
  GlobalPath: string;
  Expanded: string;
begin
  ExcludeFile := PathJoin([AGitDir, 'info', 'exclude']);
  if Exists(ExcludeFile) then
  begin
    try
      AIgnore.PushSource('', ReadFileText(ExcludeFile));
    except
      on E: ENotFoundError do ;
      on E: EIOError do ;
      else raise;
    end;
  end;
  try
    Cfg := GitReadConfig(AGitDir);
    GlobalPath := Trim(GitConfigGet(Cfg, 'core.excludesfile'));
  except
    GlobalPath := '';
  end;
  if GlobalPath = '' then Exit;
  if (Length(GlobalPath) > 0) and (GlobalPath[1] = '~') then
  begin
    if GlobalPath = '~' then Expanded := platform_env_get_str('HOME')
    else if (Length(GlobalPath) >= 2) and (GlobalPath[2] = '/') then
      Expanded := PathJoin([platform_env_get_str('HOME'), Copy(GlobalPath, 3, MaxInt)])
    else Expanded := GlobalPath;
    GlobalPath := Expanded;
  end;
  if Exists(GlobalPath) then
  begin
    try
      AIgnore.PushSource('', ReadFileText(GlobalPath));
    except
      on E: ENotFoundError do ;
      on E: EIOError do ;
      else raise;
    end;
  end;
end;

function CompareStatusByPath(const A, B: TGitNativeStatusEntry; AData: Pointer): SizeInt; inline;
var
  LA, LB: TByteSpan;
begin
  if A.Path = B.Path then Exit(0);
  if A.Path = '' then LA := TByteSpan.Empty else LA := TByteSpan.Create(PByte(@A.Path[1]), SizeUInt(Length(A.Path)));
  if B.Path = '' then LB := TByteSpan.Empty else LB := TByteSpan.Create(PByte(@B.Path[1]), SizeUInt(Length(B.Path)));
  Result := SpanCompare(LA, LB);
end;

procedure SortStatusByPath(var AList: TGitNativeStatusArray); inline;
begin
  if Length(AList) < 2 then Exit;
  specialize Sort<TGitNativeStatusEntry>(AList, @CompareStatusByPath, nil);
end;

function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean; AFindRenames: Boolean;
  ARenameThreshold: Integer; AFindCopies: Boolean;
  ACopyThreshold: Integer): TGitNativeStatusArray;
var
  Repo: TNativeRepository;
  Idx: TGitIndexFile;
  HeadList: TPathOidArray;
  Tracked: TStringArray;
  HaveHead: Boolean;
  HeadCommit: TGitOid;
  CommitData: TBytes;
  ObjKind: TGitObjectKind;
  CommitInfo: TGitCommitInfo;
  I: Integer;
  Stage0Entries: array of TGitIndexEntry;
  Stage0Pos: array of Integer;
  Deletes: TPathOidArray;
  Adds: TPathOidArray;
  AddEntryPos: array of Integer;
  BothPaths: TPathOidArray;
  BothEntry: array of TGitIndexEntry;
  Candidates: TRenameCandidateArray;
  PairedSrc: array of Boolean;
  PairedDst: array of Boolean;
  RenamePairs: TRenameCandidateArray;
  CopyPairs: TRenameCandidateArray;
  TrackedStatus: TGitNativeStatusArray;
  LTrackedCount, LTrackedCap: SizeInt;
  LStatusCount, LStatusCap: SizeInt;
  LCandCount, LCandCap: SizeInt;
  LRenameCount, LRenameCap: SizeInt;
  LCopyCount, LCopyCap: SizeInt;
  DeleteSigs, AddSigs, HeadSigs: TBlobSigArray;
  LAddOidBuckets: array of Integer;
  LOidEntries: array of record AddIdx: Integer; Next: Integer; end;
  LAddOidCap: Integer;
  LHashHeads: array of Integer;
  LHashEntries: array of record Hash: UInt32; AddIdx: Integer; Next: Integer; end;
  LVisited: array of Boolean;
  LVisitedList: array of Integer;
  LVisitedCount: Integer;

  procedure BuildStage0;
  var
    K: Integer;
    LCount, LCap: SizeInt;
  begin
    Stage0Entries := nil;
    Stage0Pos := nil;
    LCount := 0;
    LCap := 0;
    for K := 0 to High(Idx.Entries) do
    begin
      if Idx.Entries[K].Stage <> 0 then Continue;
      if LCount = LCap then
      begin
        LCap := SizeInt(GrowArrayCapacity(SizeUInt(LCap), SizeUInt(LCount + 1)));
        SetLength(Stage0Entries, LCap);
        SetLength(Stage0Pos, LCap);
      end;
      Stage0Entries[LCount] := Idx.Entries[K];
      Stage0Pos[LCount] := K;
      Inc(LCount);
    end;
    if LCap <> LCount then
    begin
      SetLength(Stage0Entries, LCount);
      SetLength(Stage0Pos, LCount);
    end;
  end;

  procedure BuildRenameSets;
  var
    HI, SI: Integer;
    LDelCount, LDelCap: SizeInt;
    LAddCount, LAddCap: SizeInt;
    LBothCount, LBothCap: SizeInt;
    procedure EnsureDelCap;
    begin
      if LDelCount = LDelCap then
      begin
        LDelCap := SizeInt(GrowArrayCapacity(SizeUInt(LDelCap), SizeUInt(LDelCount + 1)));
        SetLength(Deletes, LDelCap);
      end;
    end;
    procedure EnsureAddCap;
    begin
      if LAddCount = LAddCap then
      begin
        LAddCap := SizeInt(GrowArrayCapacity(SizeUInt(LAddCap), SizeUInt(LAddCount + 1)));
        SetLength(Adds, LAddCap);
        SetLength(AddEntryPos, LAddCap);
      end;
    end;
    procedure EnsureBothCap;
    begin
      if LBothCount = LBothCap then
      begin
        LBothCap := SizeInt(GrowArrayCapacity(SizeUInt(LBothCap), SizeUInt(LBothCount + 1)));
        SetLength(BothPaths, LBothCap);
        SetLength(BothEntry, LBothCap);
      end;
    end;
  begin
    Deletes := nil; Adds := nil; AddEntryPos := nil; BothPaths := nil; BothEntry := nil;
    LDelCount := 0; LDelCap := 0; LAddCount := 0; LAddCap := 0; LBothCount := 0; LBothCap := 0;
    HI := 0; SI := 0;
    while (HI <= High(HeadList)) and (SI <= High(Stage0Entries)) do
    begin
      if CompareString(HeadList[HI].Path, Stage0Entries[SI].Path, nil) < 0 then
      begin
        EnsureDelCap; Deletes[LDelCount] := HeadList[HI]; Inc(LDelCount); Inc(HI);
      end
      else if CompareString(HeadList[HI].Path, Stage0Entries[SI].Path, nil) > 0 then
      begin
        EnsureAddCap;
        Adds[LAddCount].Path := Stage0Entries[SI].Path;
        Adds[LAddCount].Oid := Stage0Entries[SI].Oid;
        Adds[LAddCount].Mode := Stage0Entries[SI].Mode;
        AddEntryPos[LAddCount] := SI;
        Inc(LAddCount); Inc(SI);
      end
      else
      begin
        EnsureBothCap;
        BothPaths[LBothCount] := HeadList[HI];
        BothEntry[LBothCount] := Stage0Entries[SI];
        Inc(LBothCount); Inc(HI); Inc(SI);
      end;
    end;
    while HI <= High(HeadList) do
    begin EnsureDelCap; Deletes[LDelCount] := HeadList[HI]; Inc(LDelCount); Inc(HI); end;
    while SI <= High(Stage0Entries) do
    begin
      EnsureAddCap;
      Adds[LAddCount].Path := Stage0Entries[SI].Path;
      Adds[LAddCount].Oid := Stage0Entries[SI].Oid;
      Adds[LAddCount].Mode := Stage0Entries[SI].Mode;
      AddEntryPos[LAddCount] := SI;
      Inc(LAddCount); Inc(SI);
    end;
    if LDelCap <> LDelCount then SetLength(Deletes, LDelCount);
    if LAddCap <> LAddCount then begin SetLength(Adds, LAddCount); SetLength(AddEntryPos, LAddCount); end;
    if LBothCap <> LBothCount then begin SetLength(BothPaths, LBothCount); SetLength(BothEntry, LBothCount); end;
  end;

  procedure BuildAddIndexes;
  var
    II, KK, Bucket, DI2: Integer;
    HVal: UInt32;
    TotalHashes: Integer;
  begin
    LAddOidCap := 16;
    while LAddOidCap < Length(Adds) * 2 do LAddOidCap := LAddOidCap * 2;
    SetLength(LAddOidBuckets, LAddOidCap);
    SetLength(LOidEntries, Length(Adds));
    for II := 0 to LAddOidCap - 1 do LAddOidBuckets[II] := -1;
    for DI2 := 0 to High(Adds) do
    begin
      HVal := OidHash(Adds[DI2].Oid);
      if IsBlobMode(Adds[DI2].Mode) then HVal := HVal xor UInt32($9E3779B9);
      Bucket := Integer(HVal and UInt32(LAddOidCap - 1));
      LOidEntries[DI2].AddIdx := DI2;
      LOidEntries[DI2].Next := LAddOidBuckets[Bucket];
      LAddOidBuckets[Bucket] := DI2;
    end;
    TotalHashes := 0;
    for DI2 := 0 to High(Adds) do if AddSigs[DI2].Valid then Inc(TotalHashes, AddSigs[DI2].Count);
    II := 16;
    while II < TotalHashes * 2 do II := II * 2;
    if II < 16 then II := 16;
    SetLength(LHashHeads, II);
    for KK := 0 to High(LHashHeads) do LHashHeads[KK] := -1;
    SetLength(LHashEntries, TotalHashes);
    KK := 0;
    for DI2 := 0 to High(Adds) do if AddSigs[DI2].Valid then
      for II := 0 to AddSigs[DI2].Count - 1 do
      begin
        Bucket := Integer(AddSigs[DI2].Hashes[II] and UInt32(Length(LHashHeads) - 1));
        LHashEntries[KK].Hash := AddSigs[DI2].Hashes[II];
        LHashEntries[KK].AddIdx := DI2;
        LHashEntries[KK].Next := LHashHeads[Bucket];
        LHashHeads[Bucket] := KK;
        Inc(KK);
      end;
    SetLength(LVisited, Length(Adds));
    SetLength(LVisitedList, Length(Adds));
    for II := 0 to High(LVisited) do LVisited[II] := False;
  end;

  procedure AppendUntrackedGroupToResult(var AResult: TGitNativeStatusArray);
  var
    LPaths: TStringArray;
    LStatus: TGitNativeStatusArray;
    LCount, LCap: SizeInt;
    LIgnore: TGitIgnoreMatcher;
    II: Integer;
  begin
    if not AIncludeUntracked then Exit;
    LPaths := nil;
    LIgnore := TGitIgnoreMatcher.Create;
    try
      PushInfoAndGlobalExcludes(LIgnore, AGitDir);
      CollectUntracked(AWorkTree, '', Tracked, LIgnore, LPaths);
    finally
      LIgnore.Free;
    end;
    SortStrings(LPaths);
    LStatus := nil;
    LCount := 0; LCap := 0;
    for II := 0 to High(LPaths) do
    begin
      if LCount = LCap then
      begin
        LCap := SizeInt(GrowArrayCapacity(SizeUInt(LCap), SizeUInt(LCount + 1)));
        SetLength(LStatus, LCap);
      end;
      LStatus[LCount].Path := LPaths[II];
      LStatus[LCount].OldPath := '';
      LStatus[LCount].Similarity := 0;
      LStatus[LCount].HeadCode := gscUnmodified;
      LStatus[LCount].WorkCode := gscUntracked;
      Inc(LCount);
    end;
    if LCap <> LCount then SetLength(LStatus, LCount);
    AppendUntrackedGroup(AResult, LStatus);
  end;

var
  WC: TGitStatusCode;
  Cand: TRenameCandidate;
  Score: Integer;
  SI2, DI2: Integer;
  K, CK, J: Integer;

begin
  Result := nil;
  Repo := TNativeRepository.Create(AGitDir);
  try
    Idx := GitReadIndex(AGitDir);
    HaveHead := True;
    try
      HeadCommit := GitResolveHead(AGitDir);
    except
      on E: EGitError do HaveHead := False;
    end;
    if HaveHead then
    begin
      CommitData := Repo.ReadObject(HeadCommit, ObjKind);
      if ObjKind <> gokCommit then raise EGitError.Create('HEAD does not point at a commit');
      CommitInfo := GitParseCommit(CommitData);
      FlattenTree(Repo, CommitInfo.Tree, '', HeadList);
    end;
    SortPathOids(HeadList);
    LTrackedCount := 0; LTrackedCap := 0; Tracked := nil;
    for I := 0 to High(Idx.Entries) do
      if (LTrackedCount = 0) or (Tracked[LTrackedCount - 1] <> Idx.Entries[I].Path) then
      begin
        if LTrackedCount = LTrackedCap then
        begin
          LTrackedCap := SizeInt(GrowArrayCapacity(SizeUInt(LTrackedCap), SizeUInt(LTrackedCount + 1)));
          SetLength(Tracked, LTrackedCap);
        end;
        Tracked[LTrackedCount] := Idx.Entries[I].Path;
        Inc(LTrackedCount);
      end;
    if LTrackedCap <> LTrackedCount then SetLength(Tracked, LTrackedCount);
    if (not HaveHead) or (not AFindRenames) then
    begin
      TrackedStatus := nil; LStatusCount := 0; LStatusCap := 0;
      for K := 0 to High(Idx.Entries) do
      begin
        if Idx.Entries[K].Stage <> 0 then
        begin
          if (K = 0) or (Idx.Entries[K].Path <> Idx.Entries[K - 1].Path) then
            AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Idx.Entries[K].Path, gscUnmerged, gscUnmerged);
          Continue;
        end;
      end;
      if not AFindRenames then
      begin
        BuildStage0; BuildRenameSets;
        for K := 0 to High(BothPaths) do
        begin
          WC := WorkCodeFor(AWorkTree, BothEntry[K]);
          if ModeClassOf(BothPaths[K].Mode) <> ModeClassOf(BothEntry[K].Mode) then
            AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, BothEntry[K].Path, gscTypeChanged, WC)
          else if not GitOidSame(BothPaths[K].Oid, BothEntry[K].Oid) then
            AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, BothEntry[K].Path, gscModified, WC)
          else if WC <> gscUnmodified then
            AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, BothEntry[K].Path, gscUnmodified, WC);
        end;
        for K := 0 to High(Deletes) do
          AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Deletes[K].Path, gscDeleted, gscUnmodified);
        for K := 0 to High(Adds) do
        begin
          WC := WorkCodeFor(AWorkTree, Stage0Entries[AddEntryPos[K]]);
          AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Adds[K].Path, gscAdded, WC);
        end;
        if LStatusCap <> LStatusCount then SetLength(TrackedStatus, LStatusCount);
      end;
    end
    else
    begin
      for CK := 0 to High(Idx.Entries) do
        if Idx.Entries[CK].Stage <> 0 then
        begin
          TrackedStatus := nil; LStatusCount := 0; LStatusCap := 0;
          for I := 0 to High(Idx.Entries) do
            if Idx.Entries[I].Stage <> 0 then
              if (I = 0) or (Idx.Entries[I].Path <> Idx.Entries[I - 1].Path) then
                AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Idx.Entries[I].Path, gscUnmerged, gscUnmerged);
          BuildStage0; BuildRenameSets;
          for J := 0 to High(BothPaths) do
          begin
            WC := WorkCodeFor(AWorkTree, BothEntry[J]);
            if ModeClassOf(BothPaths[J].Mode) <> ModeClassOf(BothEntry[J].Mode) then
              AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, BothEntry[J].Path, gscTypeChanged, WC)
            else if not GitOidSame(BothPaths[J].Oid, BothEntry[J].Oid) then
              AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, BothEntry[J].Path, gscModified, WC)
            else if WC <> gscUnmodified then
              AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, BothEntry[J].Path, gscUnmodified, WC);
          end;
          for J := 0 to High(Deletes) do
            AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Deletes[J].Path, gscDeleted, gscUnmodified);
          for J := 0 to High(Adds) do
          begin
            WC := WorkCodeFor(AWorkTree, Stage0Entries[AddEntryPos[J]]);
            AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Adds[J].Path, gscAdded, WC);
          end;
          if LStatusCap <> LStatusCount then SetLength(TrackedStatus, LStatusCount);
          SortStatusByPath(TrackedStatus);
          Result := TrackedStatus;
          AppendUntrackedGroupToResult(Result);
          Exit;
        end;
    end;
    if (not HaveHead) or (not AFindRenames) then
    begin
      if not HaveHead then
      begin
        TrackedStatus := nil; LStatusCount := 0; LStatusCap := 0;
        for I := 0 to High(Idx.Entries) do
        begin
          if Idx.Entries[I].Stage <> 0 then
          begin
            if (I = 0) or (Idx.Entries[I].Path <> Idx.Entries[I - 1].Path) then
              AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Idx.Entries[I].Path, gscUnmerged, gscUnmerged);
            Continue;
          end;
          WC := WorkCodeFor(AWorkTree, Idx.Entries[I]);
          AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Idx.Entries[I].Path, gscAdded, WC);
        end;
        if LStatusCap <> LStatusCount then SetLength(TrackedStatus, LStatusCount);
        SortStatusByPath(TrackedStatus);
        Result := TrackedStatus;
      end
      else
      begin
        if LStatusCap <> LStatusCount then SetLength(TrackedStatus, LStatusCount);
        Result := TrackedStatus;
      end;
      AppendUntrackedGroupToResult(Result);
      Exit;
    end;
    BuildStage0;
    BuildRenameSets;
    BuildBlobSigCache(Repo, Deletes, DeleteSigs);
    BuildBlobSigCache(Repo, Adds, AddSigs);
    Candidates := nil; LCandCount := 0; LCandCap := 0;
    if (Length(Deletes) > 0) and (Length(Adds) > 0) then
    begin
      BuildAddIndexes;
      for SI2 := 0 to High(Deletes) do
      begin
        if not IsBlobMode(Deletes[SI2].Mode) then Continue;
        LVisitedCount := 0;
        Score := Integer(OidHash(Deletes[SI2].Oid));
        if IsBlobMode(Deletes[SI2].Mode) then Score := Score xor Integer(UInt32($9E3779B9));
        I := Integer(UInt32(Score) and UInt32(LAddOidCap - 1));
        DI2 := LAddOidBuckets[I];
        while DI2 <> -1 do
        begin
          K := LOidEntries[DI2].AddIdx;
          if GitOidSame(Deletes[SI2].Oid, Adds[K].Oid) and IsBlobMode(Adds[K].Mode) then
            if not LVisited[K] then
            begin LVisited[K] := True; LVisitedList[LVisitedCount] := K; Inc(LVisitedCount); end;
          DI2 := LOidEntries[DI2].Next;
        end;
        if DeleteSigs[SI2].Valid then
        begin
          if DeleteSigs[SI2].Count = 0 then
          begin
            for DI2 := 0 to High(Adds) do
              if AddSigs[DI2].Valid and (AddSigs[DI2].Count = 0) and IsBlobMode(Adds[DI2].Mode) then
                if not LVisited[DI2] then
                begin LVisited[DI2] := True; LVisitedList[LVisitedCount] := DI2; Inc(LVisitedCount); end;
          end
          else
          begin
            for I := 0 to DeleteSigs[SI2].Count - 1 do
            begin
              Score := Integer(DeleteSigs[SI2].Hashes[I] and UInt32(Length(LHashHeads) - 1));
              K := LHashHeads[Score];
              while K <> -1 do
              begin
                if LHashEntries[K].Hash = DeleteSigs[SI2].Hashes[I] then
                begin
                  DI2 := LHashEntries[K].AddIdx;
                  if not LVisited[DI2] then
                  begin LVisited[DI2] := True; LVisitedList[LVisitedCount] := DI2; Inc(LVisitedCount); end;
                end;
                K := LHashEntries[K].Next;
              end;
            end;
          end;
        end;
        for K := 0 to LVisitedCount - 1 do
        begin
          DI2 := LVisitedList[K];
          if not IsBlobMode(Adds[DI2].Mode) then Continue;
          if GitOidSame(Deletes[SI2].Oid, Adds[DI2].Oid) then Score := 100
          else Score := ScoreFromSigs(DeleteSigs[SI2], AddSigs[DI2]);
          if Score < 0 then Continue;
          if Score < ARenameThreshold then Continue;
          if LCandCount = LCandCap then
          begin
            LCandCap := SizeInt(GrowArrayCapacity(SizeUInt(LCandCap), SizeUInt(LCandCount + 1)));
            SetLength(Candidates, LCandCap);
          end;
          Candidates[LCandCount].SrcIdx := SI2;
          Candidates[LCandCount].DstIdx := DI2;
          Candidates[LCandCount].Score := Score;
          Inc(LCandCount);
        end;
        for K := 0 to LVisitedCount - 1 do LVisited[LVisitedList[K]] := False;
      end;
      if LCandCap <> LCandCount then SetLength(Candidates, LCandCount);
    end;
    SortCandidatesByScoreDesc(Candidates);
    SetLength(PairedSrc, Length(Deletes));
    SetLength(PairedDst, Length(Adds));
    for I := 0 to High(PairedSrc) do PairedSrc[I] := False;
    for I := 0 to High(PairedDst) do PairedDst[I] := False;
    RenamePairs := nil; LRenameCount := 0; LRenameCap := 0;
    for I := 0 to High(Candidates) do
    begin
      Cand := Candidates[I];
      if PairedSrc[Cand.SrcIdx] then Continue;
      if PairedDst[Cand.DstIdx] then Continue;
      PairedSrc[Cand.SrcIdx] := True;
      PairedDst[Cand.DstIdx] := True;
      if LRenameCount = LRenameCap then
      begin
        LRenameCap := SizeInt(GrowArrayCapacity(SizeUInt(LRenameCap), SizeUInt(LRenameCount + 1)));
        SetLength(RenamePairs, LRenameCap);
      end;
      RenamePairs[LRenameCount] := Cand;
      Inc(LRenameCount);
    end;
    if LRenameCap <> LRenameCount then SetLength(RenamePairs, LRenameCount);
    CopyPairs := nil; LCopyCount := 0; LCopyCap := 0;
    if AFindCopies then
    begin
      BuildBlobSigCache(Repo, HeadList, HeadSigs);
      Candidates := nil; LCandCount := 0; LCandCap := 0;
      if (Length(HeadList) > 0) and (Length(Adds) > 0) then
      begin
        if Length(LAddOidBuckets) = 0 then BuildAddIndexes;
        for SI2 := 0 to High(HeadList) do
        begin
          if not IsBlobMode(HeadList[SI2].Mode) then Continue;
          LVisitedCount := 0;
          Score := Integer(OidHash(HeadList[SI2].Oid));
          if IsBlobMode(HeadList[SI2].Mode) then Score := Score xor Integer(UInt32($9E3779B9));
          I := Integer(UInt32(Score) and UInt32(LAddOidCap - 1));
          DI2 := LAddOidBuckets[I];
          while DI2 <> -1 do
          begin
            K := LOidEntries[DI2].AddIdx;
            if GitOidSame(HeadList[SI2].Oid, Adds[K].Oid) and IsBlobMode(Adds[K].Mode) and not PairedDst[K] then
              if not LVisited[K] then
              begin LVisited[K] := True; LVisitedList[LVisitedCount] := K; Inc(LVisitedCount); end;
            DI2 := LOidEntries[DI2].Next;
          end;
          if HeadSigs[SI2].Valid then
          begin
            if HeadSigs[SI2].Count = 0 then
            begin
              for DI2 := 0 to High(Adds) do
                if not PairedDst[DI2] and AddSigs[DI2].Valid and (AddSigs[DI2].Count = 0) and IsBlobMode(Adds[DI2].Mode) then
                  if not LVisited[DI2] then
                  begin LVisited[DI2] := True; LVisitedList[LVisitedCount] := DI2; Inc(LVisitedCount); end;
            end
            else
            begin
              for I := 0 to HeadSigs[SI2].Count - 1 do
              begin
                Score := Integer(HeadSigs[SI2].Hashes[I] and UInt32(Length(LHashHeads) - 1));
                K := LHashHeads[Score];
                while K <> -1 do
                begin
                  if LHashEntries[K].Hash = HeadSigs[SI2].Hashes[I] then
                  begin
                    DI2 := LHashEntries[K].AddIdx;
                    if not PairedDst[DI2] and not LVisited[DI2] then
                    begin LVisited[DI2] := True; LVisitedList[LVisitedCount] := DI2; Inc(LVisitedCount); end;
                  end;
                  K := LHashEntries[K].Next;
                end;
              end;
            end;
          end;
          for K := 0 to LVisitedCount - 1 do
          begin
            DI2 := LVisitedList[K];
            if PairedDst[DI2] then Continue;
            if not IsBlobMode(Adds[DI2].Mode) then Continue;
            if GitOidSame(HeadList[SI2].Oid, Adds[DI2].Oid) then Score := 100
            else Score := ScoreFromSigs(HeadSigs[SI2], AddSigs[DI2]);
            if Score < 0 then Continue;
            if Score < ACopyThreshold then Continue;
            if LCandCount = LCandCap then
            begin
              LCandCap := SizeInt(GrowArrayCapacity(SizeUInt(LCandCap), SizeUInt(LCandCount + 1)));
              SetLength(Candidates, LCandCap);
            end;
            Candidates[LCandCount].SrcIdx := SI2;
            Candidates[LCandCount].DstIdx := DI2;
            Candidates[LCandCount].Score := Score;
            Inc(LCandCount);
          end;
          for K := 0 to LVisitedCount - 1 do LVisited[LVisitedList[K]] := False;
        end;
        if LCandCap <> LCandCount then SetLength(Candidates, LCandCount);
      end;
      SortCandidatesByScoreDesc(Candidates);
      for I := 0 to High(Candidates) do
      begin
        Cand := Candidates[I];
        if PairedDst[Cand.DstIdx] then Continue;
        PairedDst[Cand.DstIdx] := True;
        if LCopyCount = LCopyCap then
        begin
          LCopyCap := SizeInt(GrowArrayCapacity(SizeUInt(LCopyCap), SizeUInt(LCopyCount + 1)));
          SetLength(CopyPairs, LCopyCap);
        end;
        CopyPairs[LCopyCount] := Cand;
        Inc(LCopyCount);
      end;
      if LCopyCap <> LCopyCount then SetLength(CopyPairs, LCopyCount);
    end;
    TrackedStatus := nil; LStatusCount := 0; LStatusCap := 0;
    for I := 0 to High(RenamePairs) do
    begin
      Cand := RenamePairs[I];
      WC := WorkCodeFor(AWorkTree, Stage0Entries[AddEntryPos[Cand.DstIdx]]);
      AppendRenamedFast(TrackedStatus, LStatusCount, LStatusCap, Deletes[Cand.SrcIdx].Path, Adds[Cand.DstIdx].Path, Byte(Cand.Score), WC);
    end;
    for I := 0 to High(CopyPairs) do
    begin
      Cand := CopyPairs[I];
      WC := WorkCodeFor(AWorkTree, Stage0Entries[AddEntryPos[Cand.DstIdx]]);
      AppendCopiedFast(TrackedStatus, LStatusCount, LStatusCap, HeadList[Cand.SrcIdx].Path, Adds[Cand.DstIdx].Path, Byte(Cand.Score), WC);
    end;
    for I := 0 to High(Deletes) do
      if not PairedSrc[I] then
        AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Deletes[I].Path, gscDeleted, gscUnmodified);
    for I := 0 to High(Adds) do
      if not PairedDst[I] then
      begin
        WC := WorkCodeFor(AWorkTree, Stage0Entries[AddEntryPos[I]]);
        AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Adds[I].Path, gscAdded, WC);
      end;
    for K := 0 to High(BothPaths) do
    begin
      WC := WorkCodeFor(AWorkTree, BothEntry[K]);
      if ModeClassOf(BothPaths[K].Mode) <> ModeClassOf(BothEntry[K].Mode) then
        AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, BothEntry[K].Path, gscTypeChanged, WC)
      else if not GitOidSame(BothPaths[K].Oid, BothEntry[K].Oid) then
        AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, BothEntry[K].Path, gscModified, WC)
      else if WC <> gscUnmodified then
        AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, BothEntry[K].Path, gscUnmodified, WC);
    end;
    if LStatusCap <> LStatusCount then SetLength(TrackedStatus, LStatusCount);
    SortStatusByPath(TrackedStatus);
    Result := TrackedStatus;
    AppendUntrackedGroupToResult(Result);
  finally
    Repo.Free;
  end;
end;

function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean): TGitNativeStatusArray;
begin
  Result := GitCollectStatus(AGitDir, AWorkTree, AIncludeUntracked, True, 50, False, 50);
end;

function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean; AFindRenames: Boolean;
  ARenameThreshold: Integer): TGitNativeStatusArray;
begin
  Result := GitCollectStatus(AGitDir, AWorkTree, AIncludeUntracked, AFindRenames, ARenameThreshold, False, 50);
end;

end.
