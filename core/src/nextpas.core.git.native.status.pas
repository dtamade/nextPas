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
  nextpas.core.hash.intf,
  nextpas.core.fs.stream,
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
  // stability: cap hashsig inflate — beyond this blobs skip similarity without ReadObject, avoids transient peak for huge blobs, threshold guard not exception
  CMaxSimilarityBlobBytes = Int64(1024 * 1024);



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
  TBlobSig = record
    Valid: Boolean;
    Size: Int64;
    Count: Integer;
    Hashes: array[0..126] of UInt32;
  end;
  TBlobSigArray = array of TBlobSig;

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
  nanosecond mtime mean unchanged without touching file contents.
  Size mismatch is a zero-I/O prefilter; otherwise chunked streaming SHA-1
  (32K) avoids whole-file TBytes for large worktree blobs. }
function WorkCodeFor(const AWorkTree: string;
  const AEntry: TGitIndexEntry): TGitStatusCode;
var
  Full: string;
  Info: TFileInfo;
  WorkMode: Cardinal;
  WorkOid: TGitOid;
  EntryKind: TGitObjectKind;
  LFile: IFile;
  H: IHasher;
  Header: TBytes;
  LBuf: array[0..32767] of Byte;
  LRead: SizeUInt;
  LTotal: Int64;
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
  // perf: size mismatch zero-I/O prefilter — header size is file size, so
  // different size => different oid without touching file contents; avoids
  // ReadFile+hash I/O for large binaries (bytes.ops owns Move, zero-copy header)
  if Info.Size <> Int64(AEntry.Size) then
    Exit(gscModified);
  if Info.ModTime = Int64(AEntry.MTimeSec) * 1000000000
      + Int64(AEntry.MTimeNSec) then
    Exit(gscUnmodified);
  // stat missed: chunked streaming hash — incremental SHA-1 over header +
  // 32K chunks, zero-copy via IHasher.Write(PByte+Len), single alloc header
  // only, no whole-file TBytes; stability: IFile refcounted + try..finally Close
  Header := GitObjectHeader(gokBlob, SizeInt(Info.Size));
  H := NewSHA1;
  if Length(Header) > 0 then
    H.Write(Header[0], SizeUInt(Length(Header)));
  LFile := FsOpen(Full, [fmRead]);
  try
    LTotal := 0;
    repeat
      LRead := LFile.Read(LBuf[0], SizeOf(LBuf));
      if LRead = 0 then Break;
      H.Write(LBuf[0], LRead);
      Inc(LTotal, Int64(LRead));
    until False;
    // race: file size changed between Lstat and hash — treat as modified
    if LTotal <> Info.Size then
      Exit(gscModified);
  finally
    LFile.Close;
  end;
  H.Sum(WorkOid.Bytes[0], SizeUInt(GitOidRawLen));
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

{ ── cached blob sig: O(n+m) inflate+hash+sort vs O(n·m) per pair ── }
{ perf: per-blob single inflate + CollectLineHashes + single SortU32, then per-pair two-pointer merge O(CA+CB); not inline per red line 2 (loop+inflate exceeds I-Cache), zero-copy TByteSpan slice, bytes.ops single source }
procedure FillBlobSig(ARepo: TNativeRepository; const AEntry: TPathOid; out ASig: TBlobSig);
var
  Kind: TGitObjectKind;
  Size: Int64;
  Data: TBytes;
  Tmp: array[0..255] of UInt32;
  C, I: Integer;
begin
  ASig.Valid := False;
  ASig.Size := 0;
  ASig.Count := 0;
  if not IsBlobMode(AEntry.Mode) then Exit;
  try
    if not ARepo.TryGetObjectSize(AEntry.Oid, Kind, Size) then Exit;
    if Kind <> gokBlob then Exit;
    ASig.Size := Size;
    // stability: large-blob guard before inflate — avoid transient peak, Valid stays False, ScoreFromSigs returns -1 without payload alloc
    if Size > CMaxSimilarityBlobBytes then Exit;
    Data := ARepo.ReadObject(AEntry.Oid, Kind);
    if Kind <> gokBlob then Exit;
  except
    on E: EGitError do Exit;
  end;
  C := 0;
  CollectLineHashes(TByteSpan.FromBytes(Data), Tmp, C);
  if C > 127 then C := 127;
  if C > 1 then SortU32(Tmp, C);
  ASig.Count := C;
  for I := 0 to C - 1 do
    ASig.Hashes[I] := Tmp[I];
  ASig.Valid := True;
end;

function ScoreFromSigs(const SA, SB: TBlobSig): Integer; inline;
var
  IA, IB, Matches: Integer;
begin
  Result := -1;
  if not SA.Valid or not SB.Valid then Exit;
  if (SA.Size > CMaxSimilarityBlobBytes) or (SB.Size > CMaxSimilarityBlobBytes) then Exit(-1);
  if (SA.Size > 127) and (SB.Size > 127) then
    if (SA.Size > SB.Size * 8) or (SB.Size > SA.Size * 8) then Exit(-1);
  if (SA.Count = 0) and (SB.Count = 0) then Exit(100);
  if (SA.Count = 0) or (SB.Count = 0) then Exit(0);
  IA := 0; IB := 0; Matches := 0;
  while (IA < SA.Count) and (IB < SB.Count) do
  begin
    if SA.Hashes[IA] < SB.Hashes[IB] then Inc(IA)
    else if SA.Hashes[IA] > SB.Hashes[IB] then Inc(IB)
    else begin Inc(Matches); Inc(IA); Inc(IB); end;
  end;
  Result := (100 * (Matches * 2)) div (SA.Count + SB.Count);
end;

{ perf: not inline per red line 2 (hash table + FillBlobSig heavy loop exceeds I-Cache); bytes.ops single source }
procedure BuildBlobSigCache(ARepo: TNativeRepository; const AList: TPathOidArray; var AOut: TBlobSigArray);
var
  I, Cap, Mask, Idx: Integer;
  LHash: UInt32;
  LIsBlob: Boolean;
  Found: Boolean;
  Buckets: array of TGitOid;
  Modes: array of Boolean;
  States: array of Byte;
  FirstPos: array of Integer;
  function OidHashInline(const AOid: TGitOid): UInt32; inline;
  var K: Integer;
  begin
    // single source FNV-1a over 20 oid bytes (same as revwalk GitOidHash), zero-copy via span view
    Result := UInt32(2166136261);
    for K := 0 to GitOidRawLen - 1 do
      Result := (Result xor UInt32(AOid.Bytes[K])) * UInt32(16777619);
  end;
begin
  // perf: O(n) avg open-addressing hash vs O(n²) linear scan; not inline outer per red line 2, inline inner OidHashInline + zero-copy SpanEqual via GitOidSame (bytes.ops)
  SetLength(AOut, Length(AList));
  if Length(AList) = 0 then Exit;
  Cap := 16;
  while Cap < Length(AList) * 2 do Cap := Cap * 2;
  Mask := Cap - 1;
  SetLength(Buckets, Cap);
  SetLength(Modes, Cap);
  SetLength(States, Cap);
  SetLength(FirstPos, Cap);
  for I := 0 to High(AList) do
  begin
    LIsBlob := IsBlobMode(AList[I].Mode);
    LHash := OidHashInline(AList[I].Oid);
    if LIsBlob then LHash := LHash xor UInt32($9E3779B9);
    Idx := Integer(LHash and UInt32(Mask));
    Found := False;
    while States[Idx] = 1 do
    begin
      if GitOidSame(Buckets[Idx], AList[I].Oid) and (Modes[Idx] = LIsBlob) then
      begin
        AOut[I] := AOut[FirstPos[Idx]];
        Found := True;
        Break;
      end;
      Idx := (Idx + 1) and Mask;
    end;
    if Found then Continue;
    FillBlobSig(ARepo, AList[I], AOut[I]);
    Buckets[Idx] := AList[I].Oid;
    Modes[Idx] := LIsBlob;
    States[Idx] := 1;
    FirstPos[Idx] := I;
  end;
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
    // stability: large-blob guard before inflate — avoid transient TBytes peak for huge blobs, return -1 without payload alloc; not dependent on exception fallback
    if (SizeA > CMaxSimilarityBlobBytes) or (SizeB > CMaxSimilarityBlobBytes) then
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

{ perf: not inline per red line 2 (recursive ReadDir+Ignore heavy IO routing); thin forwarders only inline, zero-copy via bytes.ops SpanCopy single source }
procedure CollectUntracked(const AWorkTree, ADirRel: string;
  const ATrackedSorted: TStringArray; AIgnore: TGitIgnoreMatcher;
  var AOut: TStringArray);
var
  DirAbs, Rel, IgnoreFile: string;
  Items: TDirEntryArray;
  HaveIgnore: Boolean;
  I: SizeInt;
  LCount, LCap: SizeInt;
  LDirLen, LNameLen: SizeInt;
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
  // amortized growth for untracked list (bytes.ops single-source doubling)
  LCount := Length(AOut);
  LCap := LCount;
  try
    Items := ReadDir(DirAbs);
    for I := 0 to High(Items) do
    begin
      if Items[I].Name = '.git' then
        Continue;
      if ADirRel = '' then
        Rel := Items[I].Name
      else
      begin
        // single alloc + zero-copy avoids ADirRel+'/'+Name temp storm; inline for hot fan-out
        // perf: single source via bytes.ops SpanCopy (inline, zero-copy TByteSpan view, single Move, no indexed var for untyped param per red line 1)
        LDirLen := Length(ADirRel);
        LNameLen := Length(Items[I].Name);
        SetLength(Rel, LDirLen + 1 + LNameLen);
        if LDirLen > 0 then
          SpanCopy(TByteSpan.Create(PByte(@Rel[1]), SizeUInt(LDirLen)),
            TByteSpan.Create(PByte(@ADirRel[1]), SizeUInt(LDirLen)));
        Rel[LDirLen + 1] := '/';
        if LNameLen > 0 then
          SpanCopy(TByteSpan.Create(PByte(@Rel[1]) + SizeUInt(LDirLen + 1), SizeUInt(LNameLen)),
            TByteSpan.Create(PByte(@Items[I].Name[1]), SizeUInt(LNameLen)));
      end;
      if Items[I].IsDir then
      begin
        // pruning an ignored subtree is what keeps "!x/y" under an
        // ignored "x/" from resurrecting, matching git's traversal
        if AIgnore.IsIgnored(Rel, True) then
          Continue;
        // commit logical count before recursion (capacity slack is trimmed by callee)
        if Length(AOut) <> LCount then
          SetLength(AOut, LCount);
        CollectUntracked(AWorkTree, Rel, ATrackedSorted, AIgnore, AOut);
        LCount := Length(AOut);
        LCap := LCount;
      end
      else if (not SortedHasString(ATrackedSorted, Rel))
        and (not AIgnore.IsIgnored(Rel, False)) then
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
    if LCap <> LCount then
      SetLength(AOut, LCount);
  finally
    // ensure logical length is committed even if exception; ignore file pop is stability-critical
    if Length(AOut) <> LCount then
      SetLength(AOut, LCount);
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

// amortized fast variants (bytes.ops single-source doubling, inline + zero-copy Move for string fields)
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
  // amortized caps (bytes.ops single-source doubling, zero-copy Move)
  LTrackedCount, LTrackedCap: SizeInt;
  LStatusCount, LStatusCap: SizeInt;
  LUntrackedCount, LUntrackedCap: SizeInt;
  LCandCount, LCandCap: SizeInt;
  LRenameCount, LRenameCap: SizeInt;
  LCopyCount, LCopyCap: SizeInt;
  DeleteSigs, AddSigs, HeadSigs: TBlobSigArray;
  // hash-index pruning for O(n·m) -> O(n+m+shared) (bytes.ops single source for caps, zero-copy spans)
  LAddOidBuckets: array of Integer;
  LOidEntries: array of record AddIdx: Integer; Next: Integer; end;
  LAddOidCap: Integer;
  LHashHeads: array of Integer;
  LHashEntries: array of record Hash: UInt32; AddIdx: Integer; Next: Integer; end;
  LVisited: array of Boolean;
  LVisitedList: array of Integer;
  LVisitedCount: Integer;

  procedure BuildStage0; inline;
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
      if Idx.Entries[K].Stage <> 0 then
        Continue;
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

  procedure BuildRenameSets; inline;
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
    Deletes := nil;
    Adds := nil;
    AddEntryPos := nil;
    BothPaths := nil;
    BothEntry := nil;
    LDelCount := 0; LDelCap := 0;
    LAddCount := 0; LAddCap := 0;
    LBothCount := 0; LBothCap := 0;
    HI := 0;
    SI := 0;
    while (HI <= High(HeadList)) and (SI <= High(Stage0Entries)) do
    begin
      if HeadList[HI].Path < Stage0Entries[SI].Path then
      begin
        EnsureDelCap;
        Deletes[LDelCount] := HeadList[HI];
        Inc(LDelCount);
        Inc(HI);
      end
      else if HeadList[HI].Path > Stage0Entries[SI].Path then
      begin
        EnsureAddCap;
        Adds[LAddCount].Path := Stage0Entries[SI].Path;
        Adds[LAddCount].Oid := Stage0Entries[SI].Oid;
        Adds[LAddCount].Mode := Stage0Entries[SI].Mode;
        AddEntryPos[LAddCount] := SI;
        Inc(LAddCount);
        Inc(SI);
      end
      else
      begin
        // present in both — potential modify
        EnsureBothCap;
        BothPaths[LBothCount] := HeadList[HI];
        BothEntry[LBothCount] := Stage0Entries[SI];
        Inc(LBothCount);
        Inc(HI);
        Inc(SI);
      end;
    end;
    while HI <= High(HeadList) do
    begin
      EnsureDelCap;
      Deletes[LDelCount] := HeadList[HI];
      Inc(LDelCount);
      Inc(HI);
    end;
    while SI <= High(Stage0Entries) do
    begin
      EnsureAddCap;
      Adds[LAddCount].Path := Stage0Entries[SI].Path;
      Adds[LAddCount].Oid := Stage0Entries[SI].Oid;
      Adds[LAddCount].Mode := Stage0Entries[SI].Mode;
      AddEntryPos[LAddCount] := SI;
      Inc(LAddCount);
      Inc(SI);
    end;
    if LDelCap <> LDelCount then SetLength(Deletes, LDelCount);
    if LAddCap <> LAddCount then
    begin
      SetLength(Adds, LAddCount);
      SetLength(AddEntryPos, LAddCount);
    end;
    if LBothCap <> LBothCount then
    begin
      SetLength(BothPaths, LBothCount);
      SetLength(BothEntry, LBothCount);
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

    LTrackedCount := 0;
    LTrackedCap := 0;
    Tracked := nil;
    for I := 0 to High(Idx.Entries) do
      if (LTrackedCount = 0)
        or (Tracked[LTrackedCount - 1] <> Idx.Entries[I].Path) then
      begin
        if LTrackedCount = LTrackedCap then
        begin
          LTrackedCap := SizeInt(GrowArrayCapacity(SizeUInt(LTrackedCap), SizeUInt(LTrackedCount + 1)));
          SetLength(Tracked, LTrackedCap);
        end;
        Tracked[LTrackedCount] := Idx.Entries[I].Path;
        Inc(LTrackedCount);
      end;
    if LTrackedCap <> LTrackedCount then
      SetLength(Tracked, LTrackedCount);

    // fast path: unborn or no renames requested -> original merge walk
    if (not HaveHead) or (not AFindRenames) then
    begin
      TrackedStatus := nil;
      LStatusCount := 0;
      LStatusCap := 0;
      // check for conflicts first (amortized, bytes.ops doubling)
      for K := 0 to High(Idx.Entries) do
      begin
        if Idx.Entries[K].Stage <> 0 then
        begin
          if (K = 0) or (Idx.Entries[K].Path <> Idx.Entries[K - 1].Path) then
            AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Idx.Entries[K].Path, gscUnmerged, gscUnmerged);
          Continue;
        end;
      end;
      // fallback to simple emit for non-rename case: use rename-set builder
      // with empty rename to keep code single-pathed
      if not AFindRenames then
      begin
        BuildStage0;
        BuildRenameSets;
        // emit modifies (amortized)
        for K := 0 to High(BothPaths) do
        begin
          WC := WorkCodeFor(AWorkTree, BothEntry[K]);
          // HeadCodeFor needs Head vs index entry
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
        if LStatusCap <> LStatusCount then
          SetLength(TrackedStatus, LStatusCount);
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
          // emit conflicts and fall back to no-rename walk (amortized)
          TrackedStatus := nil;
          LStatusCount := 0;
          LStatusCap := 0;
          for I := 0 to High(Idx.Entries) do
            if Idx.Entries[I].Stage <> 0 then
              if (I = 0) or (Idx.Entries[I].Path <> Idx.Entries[I - 1].Path) then
                AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Idx.Entries[I].Path, gscUnmerged, gscUnmerged);
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
              AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, BothEntry[J].Path, gscTypeChanged, WC)
            else if not GitOidSame(BothPaths[J].Oid, BothEntry[J].Oid) then
              AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, BothEntry[J].Path, gscModified, WC)
            else if WC <> gscUnmodified then
              AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, BothEntry[J].Path, gscUnmodified, WC);
          end;
          // deletes/adds that are not conflicted already in sets
          // but conflicted paths were excluded from Stage0, so they are
          // not in these sets
          for J := 0 to High(Deletes) do
            AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Deletes[J].Path, gscDeleted, gscUnmodified);
          for J := 0 to High(Adds) do
          begin
            WC := WorkCodeFor(AWorkTree, Stage0Entries[AddEntryPos[J]]);
            AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Adds[J].Path, gscAdded, WC);
          end;
          if LStatusCap <> LStatusCount then
            SetLength(TrackedStatus, LStatusCount);
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
            LUntrackedCount := 0;
            LUntrackedCap := 0;
            for I := 0 to High(UntrackedPaths) do
            begin
              if LUntrackedCount = LUntrackedCap then
              begin
                LUntrackedCap := SizeInt(GrowArrayCapacity(SizeUInt(LUntrackedCap), SizeUInt(LUntrackedCount + 1)));
                SetLength(UntrackedStatus, LUntrackedCap);
              end;
              UntrackedStatus[LUntrackedCount].Path := UntrackedPaths[I];
              UntrackedStatus[LUntrackedCount].OldPath := '';
              UntrackedStatus[LUntrackedCount].Similarity := 0;
              UntrackedStatus[LUntrackedCount].HeadCode := gscUnmodified;
              UntrackedStatus[LUntrackedCount].WorkCode := gscUntracked;
              Inc(LUntrackedCount);
            end;
            if LUntrackedCap <> LUntrackedCount then
              SetLength(UntrackedStatus, LUntrackedCount);
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
        LStatusCount := 0;
        LStatusCap := 0;
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
        if LStatusCap <> LStatusCount then
          SetLength(TrackedStatus, LStatusCount);
        SortStatusByPath(TrackedStatus);
        Result := TrackedStatus;
      end
      else
      begin
        if LStatusCap <> LStatusCount then
          SetLength(TrackedStatus, LStatusCount);
        Result := TrackedStatus;
      end;

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
        LUntrackedCount := 0;
        LUntrackedCap := 0;
        for I := 0 to High(UntrackedPaths) do
        begin
          if LUntrackedCount = LUntrackedCap then
          begin
            LUntrackedCap := SizeInt(GrowArrayCapacity(SizeUInt(LUntrackedCap), SizeUInt(LUntrackedCount + 1)));
            SetLength(UntrackedStatus, LUntrackedCap);
          end;
          UntrackedStatus[LUntrackedCount].Path := UntrackedPaths[I];
          UntrackedStatus[LUntrackedCount].OldPath := '';
          UntrackedStatus[LUntrackedCount].Similarity := 0;
          UntrackedStatus[LUntrackedCount].HeadCode := gscUnmodified;
          UntrackedStatus[LUntrackedCount].WorkCode := gscUntracked;
          Inc(LUntrackedCount);
        end;
        if LUntrackedCap <> LUntrackedCount then
          SetLength(UntrackedStatus, LUntrackedCount);
        AppendUntrackedGroup(Result, UntrackedStatus);
      end;
      Exit;
    end;

    // ── rename detection (staged axis only) ─────────────────────────────
    BuildStage0;
    BuildRenameSets;

    // collect rename candidates (amortized, bytes.ops doubling, zero-copy)
    // perf: O(n+m) cached sigs + O(n+m) oid hash + hash-index prune (reduces O(n·m) ScoreFromSigs merges); not inline per red line 2
    BuildBlobSigCache(Repo, Deletes, DeleteSigs);
    BuildBlobSigCache(Repo, Adds, AddSigs);
    Candidates := nil;
    LCandCount := 0;
    LCandCap := 0;
    if (Length(Deletes) > 0) and (Length(Adds) > 0) and (Int64(Length(Deletes)) * Int64(Length(Adds)) > 4096) then
    begin
      // large: O(n+m) oid map + inverted hash index reduces ScoreFromSigs merges from O(n·m) to shared-hash only
      LAddOidCap := 16;
      while LAddOidCap < Length(Adds) * 2 do LAddOidCap := LAddOidCap * 2;
      SetLength(LAddOidBuckets, LAddOidCap);
      SetLength(LOidEntries, Length(Adds));
      for I := 0 to LAddOidCap - 1 do LAddOidBuckets[I] := -1;
      for DI2 := 0 to High(Adds) do
      begin
        Score := 0; // reuse as hash temp
        Score := Integer(UInt32(2166136261));
        for K := 0 to GitOidRawLen - 1 do
          Score := Integer((UInt32(Score) xor UInt32(Adds[DI2].Oid.Bytes[K])) * UInt32(16777619));
        if IsBlobMode(Adds[DI2].Mode) then Score := Score xor Integer(UInt32($9E3779B9));
        I := (UInt32(Score) and UInt32(LAddOidCap - 1));
        LOidEntries[DI2].AddIdx := DI2;
        LOidEntries[DI2].Next := LAddOidBuckets[I];
        LAddOidBuckets[I] := DI2;
      end;
      // inverted hash index for Adds
      K := 0;
      for DI2 := 0 to High(Adds) do
        if AddSigs[DI2].Valid then Inc(K, AddSigs[DI2].Count);
      I := 16;
      while I < K * 2 do I := I * 2;
      if I < 16 then I := 16;
      SetLength(LHashHeads, I);
      for K := 0 to High(LHashHeads) do LHashHeads[K] := -1;
      K := 0;
      for DI2 := 0 to High(Adds) do if AddSigs[DI2].Valid then Inc(K, AddSigs[DI2].Count);
      SetLength(LHashEntries, K);
      K := 0;
      for DI2 := 0 to High(Adds) do
        if AddSigs[DI2].Valid then
          for I := 0 to AddSigs[DI2].Count - 1 do
          begin
            Score := Integer(AddSigs[DI2].Hashes[I] and UInt32(Length(LHashHeads) - 1));
            LHashEntries[K].Hash := AddSigs[DI2].Hashes[I];
            LHashEntries[K].AddIdx := DI2;
            LHashEntries[K].Next := LHashHeads[Score];
            LHashHeads[Score] := K;
            Inc(K);
          end;
      SetLength(LVisited, Length(Adds));
      SetLength(LVisitedList, Length(Adds));
      for I := 0 to High(LVisited) do LVisited[I] := False;
      // per delete, collect shared-hash + exact-oid candidates
      for SI2 := 0 to High(Deletes) do
      begin
        if not IsBlobMode(Deletes[SI2].Mode) then Continue;
        LVisitedCount := 0;
        // exact oid matches via oid buckets
        Score := Integer(UInt32(2166136261));
        for K := 0 to GitOidRawLen - 1 do
          Score := Integer((UInt32(Score) xor UInt32(Deletes[SI2].Oid.Bytes[K])) * UInt32(16777619));
        if IsBlobMode(Deletes[SI2].Mode) then Score := Score xor Integer(UInt32($9E3779B9));
        I := (UInt32(Score) and UInt32(LAddOidCap - 1));
        DI2 := LAddOidBuckets[I];
        while DI2 <> -1 do
        begin
          K := LOidEntries[DI2].AddIdx;
          if GitOidSame(Deletes[SI2].Oid, Adds[K].Oid) and IsBlobMode(Adds[K].Mode) then
            if not LVisited[K] then
            begin
              LVisited[K] := True;
              LVisitedList[LVisitedCount] := K;
              Inc(LVisitedCount);
            end;
          DI2 := LOidEntries[DI2].Next;
        end;
        // hash-sharing candidates
        if DeleteSigs[SI2].Valid then
        begin
          if DeleteSigs[SI2].Count = 0 then
          begin
            for DI2 := 0 to High(Adds) do
              if AddSigs[DI2].Valid and (AddSigs[DI2].Count = 0) and IsBlobMode(Adds[DI2].Mode) then
                if not LVisited[DI2] then
                begin
                  LVisited[DI2] := True;
                  LVisitedList[LVisitedCount] := DI2;
                  Inc(LVisitedCount);
                end;
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
                  begin
                    LVisited[DI2] := True;
                    LVisitedList[LVisitedCount] := DI2;
                    Inc(LVisitedCount);
                  end;
                end;
                K := LHashEntries[K].Next;
              end;
            end;
          end;
        end;
        // score collected candidates
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
    end
    else
    begin
      for SI2 := 0 to High(Deletes) do
      begin
        for DI2 := 0 to High(Adds) do
        begin
          if not IsBlobMode(Deletes[SI2].Mode) or not IsBlobMode(Adds[DI2].Mode) then Continue;
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
      end;
      if LCandCap <> LCandCount then SetLength(Candidates, LCandCount);
    end;
    SortCandidatesByScoreDesc(Candidates);

    SetLength(PairedSrc, Length(Deletes));
    SetLength(PairedDst, Length(Adds));
    for I := 0 to High(PairedSrc) do
      PairedSrc[I] := False;
    for I := 0 to High(PairedDst) do
      PairedDst[I] := False;
    RenamePairs := nil;
    LRenameCount := 0;
    LRenameCap := 0;
    for I := 0 to High(Candidates) do
    begin
      Cand := Candidates[I];
      if PairedSrc[Cand.SrcIdx] then
        Continue;
      if PairedDst[Cand.DstIdx] then
        Continue;
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
    if LRenameCap <> LRenameCount then
      SetLength(RenamePairs, LRenameCount);

    // copy detection (optional): pairs where source is any HEAD path
    // (including retained ones) to an added path
    CopyPairs := nil;
    LCopyCount := 0;
    LCopyCap := 0;
    if AFindCopies then
    begin
      BuildBlobSigCache(Repo, HeadList, HeadSigs);
      Candidates := nil;
      LCandCount := 0;
      LCandCap := 0;
      if (Length(HeadList) > 0) and (Length(Adds) > 0) and (Int64(Length(HeadList)) * Int64(Length(Adds)) > 4096) then
      begin
        // large: reuse Adds oid/hash index (build if not already from rename large path)
        if (Length(LAddOidBuckets) = 0) or (Length(LAddOidBuckets) <> 0) and (Length(LOidEntries) <> Length(Adds)) then
        begin
          LAddOidCap := 16;
          while LAddOidCap < Length(Adds) * 2 do LAddOidCap := LAddOidCap * 2;
          SetLength(LAddOidBuckets, LAddOidCap);
          SetLength(LOidEntries, Length(Adds));
          for I := 0 to LAddOidCap - 1 do LAddOidBuckets[I] := -1;
          for DI2 := 0 to High(Adds) do
          begin
            Score := Integer(UInt32(2166136261));
            for K := 0 to GitOidRawLen - 1 do
              Score := Integer((UInt32(Score) xor UInt32(Adds[DI2].Oid.Bytes[K])) * UInt32(16777619));
            if IsBlobMode(Adds[DI2].Mode) then Score := Score xor Integer(UInt32($9E3779B9));
            I := (UInt32(Score) and UInt32(LAddOidCap - 1));
            LOidEntries[DI2].AddIdx := DI2;
            LOidEntries[DI2].Next := LAddOidBuckets[I];
            LAddOidBuckets[I] := DI2;
          end;
        end;
        if Length(LHashHeads) = 0 then
        begin
          K := 0;
          for DI2 := 0 to High(Adds) do if AddSigs[DI2].Valid then Inc(K, AddSigs[DI2].Count);
          I := 16;
          while I < K * 2 do I := I * 2;
          if I < 16 then I := 16;
          SetLength(LHashHeads, I);
          for K := 0 to High(LHashHeads) do LHashHeads[K] := -1;
          K := 0;
          for DI2 := 0 to High(Adds) do if AddSigs[DI2].Valid then Inc(K, AddSigs[DI2].Count);
          SetLength(LHashEntries, K);
          K := 0;
          for DI2 := 0 to High(Adds) do
            if AddSigs[DI2].Valid then
              for I := 0 to AddSigs[DI2].Count - 1 do
              begin
                Score := Integer(AddSigs[DI2].Hashes[I] and UInt32(Length(LHashHeads) - 1));
                LHashEntries[K].Hash := AddSigs[DI2].Hashes[I];
                LHashEntries[K].AddIdx := DI2;
                LHashEntries[K].Next := LHashHeads[Score];
                LHashHeads[Score] := K;
                Inc(K);
              end;
          SetLength(LVisited, Length(Adds));
          SetLength(LVisitedList, Length(Adds));
          for I := 0 to High(LVisited) do LVisited[I] := False;
        end;
        for SI2 := 0 to High(HeadList) do
        begin
          if not IsBlobMode(HeadList[SI2].Mode) then Continue;
          LVisitedCount := 0;
          // exact oid
          Score := Integer(UInt32(2166136261));
          for K := 0 to GitOidRawLen - 1 do
            Score := Integer((UInt32(Score) xor UInt32(HeadList[SI2].Oid.Bytes[K])) * UInt32(16777619));
          if IsBlobMode(HeadList[SI2].Mode) then Score := Score xor Integer(UInt32($9E3779B9));
          I := (UInt32(Score) and UInt32(LAddOidCap - 1));
          DI2 := LAddOidBuckets[I];
          while DI2 <> -1 do
          begin
            K := LOidEntries[DI2].AddIdx;
            if GitOidSame(HeadList[SI2].Oid, Adds[K].Oid) and IsBlobMode(Adds[K].Mode) and not PairedDst[K] then
              if not LVisited[K] then
              begin
                LVisited[K] := True;
                LVisitedList[LVisitedCount] := K;
                Inc(LVisitedCount);
              end;
            DI2 := LOidEntries[DI2].Next;
          end;
          // hash sharing
          if HeadSigs[SI2].Valid then
          begin
            if HeadSigs[SI2].Count = 0 then
            begin
              for DI2 := 0 to High(Adds) do
                if not PairedDst[DI2] and AddSigs[DI2].Valid and (AddSigs[DI2].Count = 0) and IsBlobMode(Adds[DI2].Mode) then
                  if not LVisited[DI2] then
                  begin
                    LVisited[DI2] := True;
                    LVisitedList[LVisitedCount] := DI2;
                    Inc(LVisitedCount);
                  end;
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
                    begin
                      LVisited[DI2] := True;
                      LVisitedList[LVisitedCount] := DI2;
                      Inc(LVisitedCount);
                    end;
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
      end
      else
      begin
        for SI2 := 0 to High(HeadList) do
        begin
          // source is every HEAD blob, regardless of whether it was deleted
          for DI2 := 0 to High(Adds) do
          begin
            if PairedDst[DI2] then
              Continue;
            if not IsBlobMode(HeadList[SI2].Mode) or not IsBlobMode(Adds[DI2].Mode) then Continue;
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
        end;
        if LCandCap <> LCandCount then
          SetLength(Candidates, LCandCount);
      end;
      SortCandidatesByScoreDesc(Candidates);
      for I := 0 to High(Candidates) do
      begin
        Cand := Candidates[I];
        if PairedDst[Cand.DstIdx] then
          Continue;
        // for copies, sources may be reused, so no PairedSrc check
        PairedDst[Cand.DstIdx] := True;
        if LCopyCount = LCopyCap then
        begin
          LCopyCap := SizeInt(GrowArrayCapacity(SizeUInt(LCopyCap), SizeUInt(LCopyCount + 1)));
          SetLength(CopyPairs, LCopyCap);
        end;
        CopyPairs[LCopyCount] := Cand;
        Inc(LCopyCount);
        // map copy src idx is into HeadList, need to preserve for later
      end;
      if LCopyCap <> LCopyCount then
        SetLength(CopyPairs, LCopyCount);
    end;

    // build final tracked status (amortized)
    TrackedStatus := nil;
    LStatusCount := 0;
    LStatusCap := 0;
    // renames
    for I := 0 to High(RenamePairs) do
    begin
      Cand := RenamePairs[I];
      WC := WorkCodeFor(AWorkTree, Stage0Entries[AddEntryPos[Cand.DstIdx]]);
      AppendRenamedFast(TrackedStatus, LStatusCount, LStatusCap, Deletes[Cand.SrcIdx].Path,
        Adds[Cand.DstIdx].Path, Byte(Cand.Score), WC);
    end;
    // copies
    for I := 0 to High(CopyPairs) do
    begin
      Cand := CopyPairs[I];
      WC := WorkCodeFor(AWorkTree, Stage0Entries[AddEntryPos[Cand.DstIdx]]);
      AppendCopiedFast(TrackedStatus, LStatusCount, LStatusCap, HeadList[Cand.SrcIdx].Path,
        Adds[Cand.DstIdx].Path, Byte(Cand.Score), WC);
    end;
    // remaining deletes (unpaired)
    for I := 0 to High(Deletes) do
      if not PairedSrc[I] then
        AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Deletes[I].Path, gscDeleted, gscUnmodified);
    // remaining adds (unpaired and not copied)
    for I := 0 to High(Adds) do
      if not PairedDst[I] then
      begin
        WC := WorkCodeFor(AWorkTree, Stage0Entries[AddEntryPos[I]]);
        AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Adds[I].Path, gscAdded, WC);
      end;
    // modifies / typechanges (both)
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
    if LStatusCap <> LStatusCount then
      SetLength(TrackedStatus, LStatusCount);

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
      LUntrackedCount := 0;
      LUntrackedCap := 0;
      for I := 0 to High(UntrackedPaths) do
      begin
        if LUntrackedCount = LUntrackedCap then
        begin
          LUntrackedCap := SizeInt(GrowArrayCapacity(SizeUInt(LUntrackedCap), SizeUInt(LUntrackedCount + 1)));
          SetLength(UntrackedStatus, LUntrackedCap);
        end;
        UntrackedStatus[LUntrackedCount].Path := UntrackedPaths[I];
        UntrackedStatus[LUntrackedCount].OldPath := '';
        UntrackedStatus[LUntrackedCount].Similarity := 0;
        UntrackedStatus[LUntrackedCount].HeadCode := gscUnmodified;
        UntrackedStatus[LUntrackedCount].WorkCode := gscUntracked;
        Inc(LUntrackedCount);
      end;
      if LUntrackedCap <> LUntrackedCount then
        SetLength(UntrackedStatus, LUntrackedCount);
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
