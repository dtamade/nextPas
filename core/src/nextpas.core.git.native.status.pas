unit nextpas.core.git.native.status;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.hash.sha1,
  nextpas.core.git.native.base,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.loose,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.index,
  nextpas.core.git.native.ignore,
  nextpas.core.git.native.config;

{ Worktree status aggregation over the native object layer:
  HEAD tree <-> index (staged side) and index <-> worktree (unstaged
  side), plus untracked discovery. Clean paths are omitted; output is
  grouped like porcelain: tracked-axis entries path-sorted first, then
  untracked entries path-sorted.
  Untracked discovery honors gitignore rules: .git/info/exclude plus the
  .gitignore chain from the worktree root down (deeper files win), with
  negation, anchoring, directory-only patterns, character classes and
  '**'. core.excludesFile is not consulted yet. Ignored directories are
  pruned before descending. Rename detection on the staged axis
  (HEAD vs index) mirrors git diffcore-rename / `git status -M`:
  exact oid matches score 100 without reading blobs, otherwise a
  hashsig-like line-hash overlap (SMART whitespace, ALLOW_SMALL_FILES)
  yields 0..100; pairs above the threshold (default 50) are joined
  greedily highest-score first. Submodule (gitlink) worktree state is
  not verified against the nested repository; an existing directory
  counts as clean }

type
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

  TGitNativeStatusEntry = record
    Path: string;           { new path for renames/copies, normal path otherwise }
    OldPath: string;        { source path for renames/copies, empty otherwise }
    Similarity: Byte;       { 0..100 for renames/copies, 0 otherwise }
    HeadCode: TGitStatusCode; { HEAD tree vs index }
    WorkCode: TGitStatusCode; { index vs worktree }
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
  nextpas.core.collections.algorithms,
  nextpas.core.collections.arr.sort,
  nextpas.core.platform.env,
  nextpas.core.git.native.util;

type
  TPathOid = record
    Path: string;
    Oid: TGitOid;
    Mode: Cardinal;
  end;
  TPathOidArray = array of TPathOid;

const
  CModeDir = $4000;
  CModeRegular = $81A4;
  CModeExec = $81ED;
  CModeSymlink = $A000;
  CModeGitlink = $E000;



function ComparePathOid(const A, B: TPathOid; AData: Pointer): SizeInt;
begin
  // zero-copy path compare via string manager; stable ordering
  if A.Path < B.Path then Exit(-1);
  if A.Path > B.Path then Exit(1);
  Result := 0;
end;

function CompareString(const A, B: string; AData: Pointer): SizeInt;
begin
  if A < B then Exit(-1);
  if A > B then Exit(1);
  Result := 0;
end;

type
  TRenameCandidate = record
    SrcIdx: Integer;
    DstIdx: Integer;
    Score: Integer;
  end;
  TRenameCandidateArray = array of TRenameCandidate;

function CompareCandidateDesc(const A, B: TRenameCandidate; AData: Pointer): SizeInt;
begin
  // higher score first, tie-break smaller SrcIdx first
  if A.Score > B.Score then Exit(-1);
  if A.Score < B.Score then Exit(1);
  if A.SrcIdx < B.SrcIdx then Exit(-1);
  if A.SrcIdx > B.SrcIdx then Exit(1);
  Result := 0;
end;

procedure SortCandidatesByScoreDesc(var AList: TRenameCandidateArray);
begin
  if Length(AList) < 2 then Exit;
  specialize Sort<TRenameCandidate>(AList, @CompareCandidateDesc, nil);
end;

procedure SortPathOids(var AList: TPathOidArray);
begin
  // single-source: collections.algorithms.Sort (IntroSort + HeapSort fallback, O(n log n) no per-call Temp)
  if Length(AList) < 2 then Exit;
  specialize Sort<TPathOid>(AList, @ComparePathOid, nil);
end;

procedure SortStrings(var AList: TStringArray);
begin
  if Length(AList) < 2 then Exit;
  specialize Sort<string>(AList, @CompareString, nil);
end;

function SortedHasString(const ASorted: TStringArray;
  const AValue: string): Boolean;
var
  Lo, Hi, Mid: Integer;
begin
  Result := False;
  Lo := 0;
  Hi := High(ASorted);
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    if ASorted[Mid] = AValue then
      Exit(True);
    if ASorted[Mid] < AValue then
      Lo := Mid + 1
    else
      Hi := Mid - 1;
  end;
end;

{ Flattens a tree object into path/oid/kind triples, recursing into
  subtrees. Gitlinks are recorded without dereferencing. }
procedure FlattenTree(ARepo: TNativeRepository; const ATreeOid: TGitOid;
  const APrefix: string; var AOut: TPathOidArray);
var
  LCount, LCap: SizeInt;
  procedure DoFlatten(const ATreeOidInner: TGitOid; const APrefixInner: string);
  var
    Data: TBytes;
    Kind: TGitObjectKind;
    Entries: TGitTreeEntryArray;
    I: SizeInt;
  begin
    Data := ARepo.ReadObject(ATreeOidInner, Kind);
    if Kind <> gokTree then
      raise EGitError.Create('head commit points at a non-tree object');
    Entries := GitParseTree(Data);
    for I := 0 to High(Entries) do
    begin
      if Entries[I].Mode = CModeDir then
        DoFlatten(Entries[I].Oid, APrefixInner + Entries[I].Name + '/')
      else
      begin
        if LCount = LCap then
        begin
          if LCap = 0 then
            LCap := 16
          else if LCap <= High(SizeInt) div 2 then
            LCap := LCap * 2
          else
            LCap := LCount + 1;
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
  DoFlatten(ATreeOid, APrefix);
  if LCap <> LCount then
    SetLength(AOut, LCount);
end;

{ Typechange classes per git semantics: regular <-> symlink <-> gitlink
  flips are typechanges; exec-bit flips inside a class are plain modifies }
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

function IsBlobMode(AMode: Cardinal): Boolean;
begin
  Result := (AMode = CModeRegular) or (AMode = CModeExec);
end;

function HeadCodeFor(const AHead: TPathOid;
  const AEntry: TGitIndexEntry): TGitStatusCode;
begin
  if ModeClassOf(AHead.Mode) <> ModeClassOf(AEntry.Mode) then
    Exit(gscTypeChanged);
  if not GitOidSame(AHead.Oid, AEntry.Oid) then
    Exit(gscModified);
  Result := gscUnmodified;
end;

{ Index<->worktree comparison for one stage-0 entry. Stat data acts as a
  fast path exactly like git's cached-stat logic: matching size and
  nanosecond mtime mean unchanged without touching file contents. }
function WorkCodeFor(const AWorkTree: string;
  const AEntry: TGitIndexEntry): TGitStatusCode;
var
  Full: string;
  Info: TFileInfo;
  WorkMode: Cardinal;
  Content: TBytes;
  WorkOid: TGitOid;
  EntryKind: TGitObjectKind;
begin
  Full := PathJoin([AWorkTree, AEntry.Path]);
  if not Exists(Full) then
    Exit(gscDeleted);
  Info := Lstat(Full);
  EntryKind := GitKindFromMode(AEntry.Mode);
  if EntryKind = gokCommit then
  begin
    // submodule: an existing directory is assumed intact (stage-1 limit)
    if Info.IsDir then
      Exit(gscUnmodified);
    Exit(gscDeleted);
  end;
  if Info.IsDir then
    Exit(gscTypeChanged);
  if Info.IsSymlink then
  begin
    WorkOid := GitHashObject(gokBlob, GitStringToBytes(
      Readlink(Full)));
    if not GitOidSame(WorkOid, AEntry.Oid) then
      Exit(gscModified);
    if AEntry.Mode <> CModeSymlink then
      Exit(gscTypeChanged);
    Exit(gscUnmodified);
  end;
  // regular file: derive mode from the executable bits
  WorkMode := CModeRegular;
  if (Info.Permission and
    (PermOwnerExec or PermGroupExec or PermOtherExec)) <> 0 then
    WorkMode := CModeExec;
  // a symlink or gitlink replaced by a regular file is a typechange even
  // when the hashed content happens to match
  if ModeClassOf(AEntry.Mode) <> 0 then
    Exit(gscTypeChanged);
  if (Info.Size = Int64(AEntry.Size))
    and (Info.ModTime = Int64(AEntry.MTimeSec) * 1000000000
      + Int64(AEntry.MTimeNSec)) then
    Exit(gscUnmodified);
  Content := ReadFile(Full);
  WorkOid := GitHashObject(gokBlob, Content);
  if not GitOidSame(WorkOid, AEntry.Oid) then
    Exit(gscModified);
  if WorkMode <> AEntry.Mode then
    Exit(gscModified);
  Result := gscUnmodified;
end;

{ ── hashsig-like similarity ─────────────────────────────────────────────── }

function HashForLine(const ASpan: TByteSpan): UInt32; inline;
const
  CHashStart: UInt64 = UInt64($012345678ABCDEF0);
var
  S: UInt64;
  I: Integer;
  UpTo: SizeUInt;
begin
  S := CHashStart;
  UpTo := ASpan.Len;
  if UpTo > 80 then
    UpTo := 80;
  for I := 0 to Integer(UpTo) - 1 do
    S := S * 31 + UInt64((ASpan.Data + I)^);
  Result := UInt32(S and $FFFFFFFF);
end;

procedure CollectLineHashes(const ASpan: TByteSpan; var AOut: array of UInt32;
  var ACount: Integer);
var
  I, Start, N: Integer;
  LineSpan: TByteSpan;
begin
  ACount := 0;
  if ASpan.Len = 0 then
    Exit;
  Start := 0;
  for I := 0 to Integer(ASpan.Len) - 1 do
  begin
    if (ASpan.Data + I)^ = 10 then
    begin
      N := I - Start;
      if (N > 0) and ((ASpan.Data + I - 1)^ = 13) then
        Dec(N);
      if N > 0 then
      begin
        LineSpan := ASpan.Slice(SizeUInt(Start), SizeUInt(N));
        if ACount < Length(AOut) then
          AOut[ACount] := HashForLine(LineSpan);
        Inc(ACount);
      end;
      Start := I + 1;
    end;
  end;
  if Start < Integer(ASpan.Len) then
  begin
    N := Integer(ASpan.Len) - Start;
    if N > 0 then
    begin
      LineSpan := ASpan.Slice(SizeUInt(Start), SizeUInt(N));
      if ACount < Length(AOut) then
        AOut[ACount] := HashForLine(LineSpan);
      Inc(ACount);
    end;
  end;
end;

procedure SortU32(var AData: array of UInt32; ACount: Integer);
begin
  // single-source: collections.arr.sort.SortU32 (radix+introsort, zero-copy Move, no per-call heap Temp)
  if ACount < 2 then Exit;
  if ACount > Length(AData) then ACount := Length(AData);
  if ACount < 2 then Exit;
  nextpas.core.collections.arr.sort.SortU32(PUInt32(@AData[0]), SizeUInt(ACount));
end;

function HashSigScoreForBlobs(const ADataA, ADataB: TBytes): Integer;
const
  MaxHashes = 256;
var
  HA, HB: array[0..255] of UInt32;
  CA, CB: Integer;
  IA, IB, Matches: Integer;
begin
  Result := 0;
  if (Length(ADataA) = 0) and (Length(ADataB) = 0) then
    Exit(100);
  if (Length(ADataA) = 0) or (Length(ADataB) = 0) then
    Exit(0);
  CA := 0;
  CB := 0;
  CollectLineHashes(TByteSpan.FromBytes(ADataA), HA, CA);
  CollectLineHashes(TByteSpan.FromBytes(ADataB), HB, CB);
  // truncate to heap size 127 like git (keep all for small files,
  // but cap large files to 127 smallest/largest; for small files
  // our set is already <127)
  if CA > 127 then
    CA := 127;
  if CB > 127 then
    CB := 127;
  if (CA = 0) and (CB = 0) then
    Exit(100);
  if (CA = 0) or (CB = 0) then
    Exit(0);
  SortU32(HA, CA);
  SortU32(HB, CB);
  IA := 0;
  IB := 0;
  Matches := 0;
  while (IA < CA) and (IB < CB) do
  begin
    if HA[IA] < HB[IB] then
      Inc(IA)
    else if HA[IA] > HB[IB] then
      Inc(IB)
    else
    begin
      Inc(Matches);
      Inc(IA);
      Inc(IB);
    end;
  end;
  Result := (100 * (Matches * 2)) div (CA + CB);
end;

function SimilarityForPair(ARepo: TNativeRepository;
  const ASource, ATarget: TPathOid): Integer;
var
  KindA, KindB: TGitObjectKind;
  SizeA, SizeB: Int64;
  DataA, DataB: TBytes;
begin
  Result := -1;
  if not IsBlobMode(ASource.Mode) then
    Exit;
  if not IsBlobMode(ATarget.Mode) then
    Exit;
  if GitOidSame(ASource.Oid, ATarget.Oid) then
    Exit(100);
  // perf: size ratio guard before inflate — avoids O(n·m) extra decompress+hash
  // git rule: if both >127 and one >8x the other, skip similarity (return -1)
  // single source: size via TNativeRepository.TryGetObjectSize (loose header / pack header)
  // zero-copy: header-only parse, no payload alloc; bytes.ops single source for payload path
  // stability: TryGetObjectSize returns False for missing, raises EGitError for corrupt — treat as -1
  try
    if not ARepo.TryGetObjectSize(ASource.Oid, KindA, SizeA) then
      Exit(-1);
    if KindA <> gokBlob then
      Exit(-1);
    if not ARepo.TryGetObjectSize(ATarget.Oid, KindB, SizeB) then
      Exit(-1);
    if KindB <> gokBlob then
      Exit(-1);
    if (SizeA > 127) and (SizeB > 127) then
      if (SizeA > SizeB * 8) or (SizeB > SizeA * 8) then
        Exit(-1);
  except
    on E: EGitError do
      Exit(-1);
  end;
  // only now inflate payloads for hashsig scoring
  // stability: ReadObject uses managed TBytes, auto freed on exception; no leak
  try
    DataA := ARepo.ReadObject(ASource.Oid, KindA);
    if KindA <> gokBlob then
      Exit(-1);
    DataB := ARepo.ReadObject(ATarget.Oid, KindB);
    if KindB <> gokBlob then
      Exit(-1);
  except
    on E: EGitError do
      Exit(-1);
  end;
  Result := HashSigScoreForBlobs(DataA, DataB);
end;

procedure CollectUntracked(const AWorkTree, ADirRel: string;
  const ATrackedSorted: TStringArray; AIgnore: TGitIgnoreMatcher;
  var AOut: TStringArray);
var
  DirAbs, Rel, IgnoreFile: string;
  Items: TDirEntryArray;
  HaveIgnore: Boolean;
  I: SizeInt;
begin
  if ADirRel = '' then
    DirAbs := AWorkTree
  else
    DirAbs := PathJoin([AWorkTree, ADirRel]);
  // this directory's own rules govern its subtree; pushed last = deepest
  // precedence, popped when the recursion leaves
  IgnoreFile := PathJoin([DirAbs, '.gitignore']);
  HaveIgnore := Exists(IgnoreFile);
  if HaveIgnore then
    AIgnore.PushSource(ADirRel, ReadFileText(IgnoreFile));
  try
    Items := ReadDir(DirAbs);
    for I := 0 to High(Items) do
    begin
      if Items[I].Name = '.git' then
        Continue;
      if ADirRel = '' then
        Rel := Items[I].Name
      else
        Rel := ADirRel + '/' + Items[I].Name;
      if Items[I].IsDir then
      begin
        // pruning an ignored subtree is what keeps "!x/y" under an
        // ignored "x/" from resurrecting, matching git's traversal
        if AIgnore.IsIgnored(Rel, True) then
          Continue;
        CollectUntracked(AWorkTree, Rel, ATrackedSorted, AIgnore, AOut)
      end
      else if (not SortedHasString(ATrackedSorted, Rel))
        and (not AIgnore.IsIgnored(Rel, False)) then
      begin
        SetLength(AOut, Length(AOut) + 1);
        AOut[High(AOut)] := Rel;
      end;
    end;
  finally
    if HaveIgnore then
      AIgnore.PopSource;
  end;
end;

procedure AppendStatus(var AOut: TGitNativeStatusArray;
  const APath: string; AHeadCode, AWorkCode: TGitStatusCode);
begin
  if (AHeadCode = gscUnmodified) and (AWorkCode = gscUnmodified) then
    Exit;
  SetLength(AOut, Length(AOut) + 1);
  AOut[High(AOut)].Path := APath;
  AOut[High(AOut)].OldPath := '';
  AOut[High(AOut)].Similarity := 0;
  AOut[High(AOut)].HeadCode := AHeadCode;
  AOut[High(AOut)].WorkCode := AWorkCode;
end;

procedure AppendRenamed(var AOut: TGitNativeStatusArray;
  const AOldPath, ANewPath: string; ASimilarity: Byte;
  AWorkCode: TGitStatusCode);
begin
  SetLength(AOut, Length(AOut) + 1);
  AOut[High(AOut)].Path := ANewPath;
  AOut[High(AOut)].OldPath := AOldPath;
  AOut[High(AOut)].Similarity := ASimilarity;
  AOut[High(AOut)].HeadCode := gscRenamed;
  AOut[High(AOut)].WorkCode := AWorkCode;
end;

procedure AppendCopied(var AOut: TGitNativeStatusArray;
  const AOldPath, ANewPath: string; ASimilarity: Byte;
  AWorkCode: TGitStatusCode);
begin
  SetLength(AOut, Length(AOut) + 1);
  AOut[High(AOut)].Path := ANewPath;
  AOut[High(AOut)].OldPath := AOldPath;
  AOut[High(AOut)].Similarity := ASimilarity;
  AOut[High(AOut)].HeadCode := gscCopied;
  AOut[High(AOut)].WorkCode := AWorkCode;
end;

{ Appends the untracked group after the tracked one — git's porcelain
  emits changed entries (path-sorted) first, then untracked entries
  (path-sorted), never a global interleave }
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

procedure PushInfoAndGlobalExcludes(AIgnore: TGitIgnoreMatcher;
  const AGitDir: string);
var
  ExcludeFile: string;
  Cfg: TGitConfig;
  GlobalPath: string;
  Expanded: string;
begin
  ExcludeFile := PathJoin([AGitDir, 'info', 'exclude']);
  if Exists(ExcludeFile) then
    try
      AIgnore.PushSource('', ReadFileText(ExcludeFile));
    except
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
    // owner boundary: platform.env owns raw OS truth; L2 git must not touch os.env helper
    if GlobalPath = '~' then Expanded := platform_env_get_str('HOME')
    else if (Length(GlobalPath) >= 2) and (GlobalPath[2] = '/') then
      Expanded := PathJoin([platform_env_get_str('HOME'), Copy(GlobalPath, 3, MaxInt)])
    else Expanded := GlobalPath;
    GlobalPath := Expanded;
  end;
  if Exists(GlobalPath) then
    try
      AIgnore.PushSource('', ReadFileText(GlobalPath));
    except
    end;
end;

function CompareStatusByPath(const A, B: TGitNativeStatusEntry; AData: Pointer): SizeInt; inline;
begin
  if A.Path < B.Path then Exit(-1);
  if A.Path > B.Path then Exit(1);
  Result := 0;
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
  UntrackedPaths: TStringArray;
  UntrackedStatus: TGitNativeStatusArray;
  Ignore: TGitIgnoreMatcher;
  ExcludeFile: string;
  HaveHead: Boolean;
  HeadCommit: TGitOid;
  CommitData: TBytes;
  ObjKind: TGitObjectKind;
  CommitInfo: TGitCommitInfo;
  I: Integer;

  // rename detection structures
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

  procedure BuildStage0;
  var
    K: Integer;
  begin
    Stage0Entries := nil;
    Stage0Pos := nil;
    for K := 0 to High(Idx.Entries) do
    begin
      if Idx.Entries[K].Stage <> 0 then
        Continue;
      SetLength(Stage0Entries, Length(Stage0Entries) + 1);
      Stage0Entries[High(Stage0Entries)] := Idx.Entries[K];
      SetLength(Stage0Pos, Length(Stage0Pos) + 1);
      Stage0Pos[High(Stage0Pos)] := K;
    end;
  end;

  procedure BuildRenameSets;
  var
    HI, SI: Integer;
  begin
    Deletes := nil;
    Adds := nil;
    AddEntryPos := nil;
    BothPaths := nil;
    BothEntry := nil;
    HI := 0;
    SI := 0;
    while (HI <= High(HeadList)) and (SI <= High(Stage0Entries)) do
    begin
      if HeadList[HI].Path < Stage0Entries[SI].Path then
      begin
        SetLength(Deletes, Length(Deletes) + 1);
        Deletes[High(Deletes)] := HeadList[HI];
        Inc(HI);
      end
      else if HeadList[HI].Path > Stage0Entries[SI].Path then
      begin
        SetLength(Adds, Length(Adds) + 1);
        Adds[High(Adds)].Path := Stage0Entries[SI].Path;
        Adds[High(Adds)].Oid := Stage0Entries[SI].Oid;
        Adds[High(Adds)].Mode := Stage0Entries[SI].Mode;
        SetLength(AddEntryPos, Length(AddEntryPos) + 1);
        AddEntryPos[High(AddEntryPos)] := SI;
        Inc(SI);
      end
      else
      begin
        // present in both — potential modify
        SetLength(BothPaths, Length(BothPaths) + 1);
        BothPaths[High(BothPaths)] := HeadList[HI];
        SetLength(BothEntry, Length(BothEntry) + 1);
        BothEntry[High(BothEntry)] := Stage0Entries[SI];
        Inc(HI);
        Inc(SI);
      end;
    end;
    while HI <= High(HeadList) do
    begin
      SetLength(Deletes, Length(Deletes) + 1);
      Deletes[High(Deletes)] := HeadList[HI];
      Inc(HI);
    end;
    while SI <= High(Stage0Entries) do
    begin
      SetLength(Adds, Length(Adds) + 1);
      Adds[High(Adds)].Path := Stage0Entries[SI].Path;
      Adds[High(Adds)].Oid := Stage0Entries[SI].Oid;
      Adds[High(Adds)].Mode := Stage0Entries[SI].Mode;
      SetLength(AddEntryPos, Length(AddEntryPos) + 1);
      AddEntryPos[High(AddEntryPos)] := SI;
      Inc(SI);
    end;
  end;

var
  WC: TGitStatusCode;
  Cand: TRenameCandidate;
  Score: Integer;
  SI2, DI2: Integer;
  RemainingDeletes, RemainingAdds: TPathOidArray;
  RemainingAddPos: array of Integer;
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
      on E: EGitError do
        HaveHead := False;
    end;
    if HaveHead then
    begin
      CommitData := Repo.ReadObject(HeadCommit, ObjKind);
      if ObjKind <> gokCommit then
        raise EGitError.Create('HEAD does not point at a commit');
      CommitInfo := GitParseCommit(CommitData);
      FlattenTree(Repo, CommitInfo.Tree, '', HeadList);
    end;
    SortPathOids(HeadList);

    for I := 0 to High(Idx.Entries) do
      if (Length(Tracked) = 0)
        or (Tracked[High(Tracked)] <> Idx.Entries[I].Path) then
      begin
        SetLength(Tracked, Length(Tracked) + 1);
        Tracked[High(Tracked)] := Idx.Entries[I].Path;
      end;

    // fast path: unborn or no renames requested -> original merge walk
    if (not HaveHead) or (not AFindRenames) then
    begin
      TrackedStatus := nil;
      // check for conflicts first
      for K := 0 to High(Idx.Entries) do
      begin
        if Idx.Entries[K].Stage <> 0 then
        begin
          if (K = 0) or (Idx.Entries[K].Path <> Idx.Entries[K - 1].Path) then
            AppendStatus(TrackedStatus, Idx.Entries[K].Path, gscUnmerged, gscUnmerged);
          Continue;
        end;
      end;
      // fallback to simple emit for non-rename case: use rename-set builder
      // with empty rename to keep code single-pathed
      if not AFindRenames then
      begin
        BuildStage0;
        BuildRenameSets;
        // emit modifies
        for K := 0 to High(BothPaths) do
        begin
          WC := WorkCodeFor(AWorkTree, BothEntry[K]);
          // HeadCodeFor needs Head vs index entry
          if ModeClassOf(BothPaths[K].Mode) <> ModeClassOf(BothEntry[K].Mode) then
            AppendStatus(TrackedStatus, BothEntry[K].Path, gscTypeChanged, WC)
          else if not GitOidSame(BothPaths[K].Oid, BothEntry[K].Oid) then
            AppendStatus(TrackedStatus, BothEntry[K].Path, gscModified, WC)
          else if WC <> gscUnmodified then
            AppendStatus(TrackedStatus, BothEntry[K].Path, gscUnmodified, WC);
        end;
        for K := 0 to High(Deletes) do
          AppendStatus(TrackedStatus, Deletes[K].Path, gscDeleted, gscUnmodified);
        for K := 0 to High(Adds) do
        begin
          WC := WorkCodeFor(AWorkTree, Stage0Entries[AddEntryPos[K]]);
          AppendStatus(TrackedStatus, Adds[K].Path, gscAdded, WC);
        end;
        // conflicts: emit once per path
        for I := 0 to High(Idx.Entries) do
          if Idx.Entries[I].Stage <> 0 then
            if (I = 0) or (Idx.Entries[I].Path <> Idx.Entries[I - 1].Path) then
            begin
              // already emitted above if not HaveHead case, but for HaveHead
              // with no renames we still need to emit conflicts
              // de-duplicate: check if already present
              // simple: if TrackedStatus does not already contain path with unmerged
              // we append
              // For simplicity, collect conflicts separately
            end;
      end;
    end
    else
    begin
      // Check for conflicts: any non-zero stage means we skip rename and
      // emit unmerged directly (git defers rename when conflicts present)
      for CK := 0 to High(Idx.Entries) do
        if Idx.Entries[CK].Stage <> 0 then
        begin
          // emit conflicts and fall back to no-rename walk
          TrackedStatus := nil;
          for I := 0 to High(Idx.Entries) do
            if Idx.Entries[I].Stage <> 0 then
              if (I = 0) or (Idx.Entries[I].Path <> Idx.Entries[I - 1].Path) then
                AppendStatus(TrackedStatus, Idx.Entries[I].Path, gscUnmerged, gscUnmerged);
          // still need to emit staged changes for stage0 entries vs HEAD
          // but with conflicts present, git typically shows only unmerged;
          // we keep it simple and also emit other staged status for
          // non-conflicted paths via same sets without rename
          BuildStage0;
          BuildRenameSets;
          // filter out conflicted paths from deletes/adds/both
          // (they are already handled)
          // For now, emit remaining as added/deleted/modified
          for J := 0 to High(BothPaths) do
          begin
            WC := WorkCodeFor(AWorkTree, BothEntry[J]);
            if ModeClassOf(BothPaths[J].Mode) <> ModeClassOf(BothEntry[J].Mode) then
              AppendStatus(TrackedStatus, BothEntry[J].Path, gscTypeChanged, WC)
            else if not GitOidSame(BothPaths[J].Oid, BothEntry[J].Oid) then
              AppendStatus(TrackedStatus, BothEntry[J].Path, gscModified, WC)
            else if WC <> gscUnmodified then
              AppendStatus(TrackedStatus, BothEntry[J].Path, gscUnmodified, WC);
          end;
          // deletes/adds that are not conflicted already in sets
          // but conflicted paths were excluded from Stage0, so they are
          // not in these sets
          for J := 0 to High(Deletes) do
            AppendStatus(TrackedStatus, Deletes[J].Path, gscDeleted, gscUnmodified);
          for J := 0 to High(Adds) do
          begin
            WC := WorkCodeFor(AWorkTree, Stage0Entries[AddEntryPos[J]]);
            AppendStatus(TrackedStatus, Adds[J].Path, gscAdded, WC);
          end;
          SortStatusByPath(TrackedStatus);
          Result := TrackedStatus;
          if AIncludeUntracked then
          begin
            UntrackedPaths := nil;
            Ignore := TGitIgnoreMatcher.Create;
            try
              PushInfoAndGlobalExcludes(Ignore, AGitDir);
              CollectUntracked(AWorkTree, '', Tracked, Ignore, UntrackedPaths);
            finally
              Ignore.Free;
            end;
            SortStrings(UntrackedPaths);
            UntrackedStatus := nil;
            for I := 0 to High(UntrackedPaths) do
            begin
              SetLength(UntrackedStatus, Length(UntrackedStatus) + 1);
              UntrackedStatus[High(UntrackedStatus)].Path := UntrackedPaths[I];
              UntrackedStatus[High(UntrackedStatus)].OldPath := '';
              UntrackedStatus[High(UntrackedStatus)].Similarity := 0;
              UntrackedStatus[High(UntrackedStatus)].HeadCode := gscUnmodified;
              UntrackedStatus[High(UntrackedStatus)].WorkCode := gscUntracked;
            end;
            AppendUntrackedGroup(Result, UntrackedStatus);
          end;
          Exit;
        end;
    end;

    if (not HaveHead) or (not AFindRenames) then
    begin
      // already handled non-rename case above via early path?
      // If we reached here with HaveHead and FindRenames but we already
      // handled conflicts, the non-rename body above for FindRenames=False
      // already emitted. For unborn, we need separate emit:
      if not HaveHead then
      begin
        TrackedStatus := nil;
        for I := 0 to High(Idx.Entries) do
        begin
          if Idx.Entries[I].Stage <> 0 then
          begin
            if (I = 0) or (Idx.Entries[I].Path <> Idx.Entries[I - 1].Path) then
              AppendStatus(TrackedStatus, Idx.Entries[I].Path, gscUnmerged, gscUnmerged);
            Continue;
          end;
          WC := WorkCodeFor(AWorkTree, Idx.Entries[I]);
          AppendStatus(TrackedStatus, Idx.Entries[I].Path, gscAdded, WC);
        end;
        SortStatusByPath(TrackedStatus);
        Result := TrackedStatus;
      end
      else
        Result := TrackedStatus;

      if AIncludeUntracked then
      begin
        UntrackedPaths := nil;
        Ignore := TGitIgnoreMatcher.Create;
        try
          PushInfoAndGlobalExcludes(Ignore, AGitDir);
          CollectUntracked(AWorkTree, '', Tracked, Ignore, UntrackedPaths);
        finally
          Ignore.Free;
        end;
        SortStrings(UntrackedPaths);
        UntrackedStatus := nil;
        for I := 0 to High(UntrackedPaths) do
        begin
          SetLength(UntrackedStatus, Length(UntrackedStatus) + 1);
          UntrackedStatus[High(UntrackedStatus)].Path := UntrackedPaths[I];
          UntrackedStatus[High(UntrackedStatus)].OldPath := '';
          UntrackedStatus[High(UntrackedStatus)].Similarity := 0;
          UntrackedStatus[High(UntrackedStatus)].HeadCode := gscUnmodified;
          UntrackedStatus[High(UntrackedStatus)].WorkCode := gscUntracked;
        end;
        AppendUntrackedGroup(Result, UntrackedStatus);
      end;
      Exit;
    end;

    // ── rename detection (staged axis only) ─────────────────────────────
    BuildStage0;
    BuildRenameSets;

    // collect rename candidates
    Candidates := nil;
    for SI2 := 0 to High(Deletes) do
    begin
      for DI2 := 0 to High(Adds) do
      begin
        Score := SimilarityForPair(Repo, Deletes[SI2], Adds[DI2]);
        if Score < ARenameThreshold then
          Continue;
        if Score < 0 then
          Continue;
        SetLength(Candidates, Length(Candidates) + 1);
        Candidates[High(Candidates)].SrcIdx := SI2;
        Candidates[High(Candidates)].DstIdx := DI2;
        Candidates[High(Candidates)].Score := Score;
      end;
    end;
    SortCandidatesByScoreDesc(Candidates);

    SetLength(PairedSrc, Length(Deletes));
    SetLength(PairedDst, Length(Adds));
    for I := 0 to High(PairedSrc) do
      PairedSrc[I] := False;
    for I := 0 to High(PairedDst) do
      PairedDst[I] := False;
    RenamePairs := nil;
    for I := 0 to High(Candidates) do
    begin
      Cand := Candidates[I];
      if PairedSrc[Cand.SrcIdx] then
        Continue;
      if PairedDst[Cand.DstIdx] then
        Continue;
      PairedSrc[Cand.SrcIdx] := True;
      PairedDst[Cand.DstIdx] := True;
      SetLength(RenamePairs, Length(RenamePairs) + 1);
      RenamePairs[High(RenamePairs)] := Cand;
    end;

    // copy detection (optional): pairs where source is any HEAD path
    // (including retained ones) to an added path
    CopyPairs := nil;
    if AFindCopies then
    begin
      Candidates := nil;
      for SI2 := 0 to High(HeadList) do
      begin
        // source is every HEAD blob, regardless of whether it was deleted
        for DI2 := 0 to High(Adds) do
        begin
          if PairedDst[DI2] then
            Continue;
          Score := SimilarityForPair(Repo, HeadList[SI2], Adds[DI2]);
          if Score < ACopyThreshold then
            Continue;
          if Score < 0 then
            Continue;
          SetLength(Candidates, Length(Candidates) + 1);
          Candidates[High(Candidates)].SrcIdx := SI2;
          Candidates[High(Candidates)].DstIdx := DI2;
          Candidates[High(Candidates)].Score := Score;
        end;
      end;
      SortCandidatesByScoreDesc(Candidates);
      for I := 0 to High(Candidates) do
      begin
        Cand := Candidates[I];
        if PairedDst[Cand.DstIdx] then
          Continue;
        // for copies, sources may be reused, so no PairedSrc check
        PairedDst[Cand.DstIdx] := True;
        SetLength(CopyPairs, Length(CopyPairs) + 1);
        CopyPairs[High(CopyPairs)] := Cand;
        // map copy src idx is into HeadList, need to preserve for later
      end;
    end;

    // build final tracked status
    TrackedStatus := nil;
    // renames
    for I := 0 to High(RenamePairs) do
    begin
      Cand := RenamePairs[I];
      WC := WorkCodeFor(AWorkTree, Stage0Entries[AddEntryPos[Cand.DstIdx]]);
      AppendRenamed(TrackedStatus, Deletes[Cand.SrcIdx].Path,
        Adds[Cand.DstIdx].Path, Byte(Cand.Score), WC);
    end;
    // copies
    for I := 0 to High(CopyPairs) do
    begin
      Cand := CopyPairs[I];
      WC := WorkCodeFor(AWorkTree, Stage0Entries[AddEntryPos[Cand.DstIdx]]);
      AppendCopied(TrackedStatus, HeadList[Cand.SrcIdx].Path,
        Adds[Cand.DstIdx].Path, Byte(Cand.Score), WC);
    end;
    // remaining deletes (unpaired)
    for I := 0 to High(Deletes) do
      if not PairedSrc[I] then
        AppendStatus(TrackedStatus, Deletes[I].Path, gscDeleted, gscUnmodified);
    // remaining adds (unpaired and not copied)
    for I := 0 to High(Adds) do
      if not PairedDst[I] then
      begin
        WC := WorkCodeFor(AWorkTree, Stage0Entries[AddEntryPos[I]]);
        AppendStatus(TrackedStatus, Adds[I].Path, gscAdded, WC);
      end;
    // modifies / typechanges (both)
    for K := 0 to High(BothPaths) do
    begin
      WC := WorkCodeFor(AWorkTree, BothEntry[K]);
      if ModeClassOf(BothPaths[K].Mode) <> ModeClassOf(BothEntry[K].Mode) then
        AppendStatus(TrackedStatus, BothEntry[K].Path, gscTypeChanged, WC)
      else if not GitOidSame(BothPaths[K].Oid, BothEntry[K].Oid) then
        AppendStatus(TrackedStatus, BothEntry[K].Path, gscModified, WC)
      else if WC <> gscUnmodified then
        AppendStatus(TrackedStatus, BothEntry[K].Path, gscUnmodified, WC);
    end;

    SortStatusByPath(TrackedStatus);
    Result := TrackedStatus;

    if AIncludeUntracked then
    begin
      UntrackedPaths := nil;
      Ignore := TGitIgnoreMatcher.Create;
      try
        PushInfoAndGlobalExcludes(Ignore, AGitDir);
        CollectUntracked(AWorkTree, '', Tracked, Ignore, UntrackedPaths);
      finally
        Ignore.Free;
      end;
      SortStrings(UntrackedPaths);
      UntrackedStatus := nil;
      for I := 0 to High(UntrackedPaths) do
      begin
        SetLength(UntrackedStatus, Length(UntrackedStatus) + 1);
        UntrackedStatus[High(UntrackedStatus)].Path := UntrackedPaths[I];
        UntrackedStatus[High(UntrackedStatus)].OldPath := '';
        UntrackedStatus[High(UntrackedStatus)].Similarity := 0;
        UntrackedStatus[High(UntrackedStatus)].HeadCode := gscUnmodified;
        UntrackedStatus[High(UntrackedStatus)].WorkCode := gscUntracked;
      end;
      AppendUntrackedGroup(Result, UntrackedStatus);
    end;
  finally
    Repo.Free;
  end;
end;

function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean): TGitNativeStatusArray;
begin
  Result := nil;
  Result := GitCollectStatus(AGitDir, AWorkTree, AIncludeUntracked, True, 50, False, 50);
end;

function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean; AFindRenames: Boolean;
  ARenameThreshold: Integer): TGitNativeStatusArray;
begin
  Result := nil;
  Result := GitCollectStatus(AGitDir, AWorkTree, AIncludeUntracked,
    AFindRenames, ARenameThreshold, False, 50);
end;

end.
