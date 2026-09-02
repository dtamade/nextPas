unit nextpas.core.git.native.commitgraph;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.io.mapped,
  nextpas.core.hash.intf,
  nextpas.core.hash.sha1, // git-native-commitgraph-l2-exempt: L2 git→hash.sha1 single-source via bytes.ops, registry core/docs/core-module-registry.md git row (C5 zlib anchor pattern)
  nextpas.core.git.native.base;

{ Commit-graph v1 reader+writer+cache (SHA-1) for local revwalk acceleration.
  Note: history-domain core (~1320 lines) exceeds design-conventions §2
    800-line soft guide; retained per CONTRACT.history §6 as cohesive
    exception — reader+writer+cache+collect share CGPH/OIDF/OIDL/CDAT/EDGE
    invariants + single mmap owner. Thin aggregator is history.traversal;
    split would dilute ownership + double cache owner + merge conflict risk.
    Monitored 1320→1500 hard split threshold per CONTRACT.history §6;
    I-Cache impact bounded via inline red-line discipline (thin O(1) forwards
    inline, loops/SIMD not inline) + 4 region markers for audit.
  L2 exempt: git-native-commitgraph-l2-exempt — L2 git→hash.sha1 single-source
    via bytes.ops SpanCompare/SpanCopy + NewSHA1, no duplicate SHA-1 loop;
    registry core/docs/core-module-registry.md git row (same-layer one-way
    fs/compress/hash/zlib/checksum), traceable via C5 anchor pattern (zlib analog).

  Audit: 4 regions via markers — Cache / Reader / Writer / Collect;
    1320 vs 800 is §2 soft-guide exception with shared invariants, not
    exemption from audit. Volume restraint via region markers + 1500 hard
    threshold (see CONTRACT.history §1/§6). Hashed Dir index (FNV-1a via
    bytes.ops) keeps cache O(1) avg without string-scan churn.

  Perf: mmap zero-copy via io.mapped + bytes.ops single source
    (SpanCopy/SpanCompare, PByte window); inline O(1) touch;
    OID copies single Move via SpanCopy (no for K byte loop); index-indirect
    sort via integer indices avoids TRawCommit Parents AddRef/Release churn
    (O(n log n) int swaps + O(n) reorder).
  Stability: IMappedFile refcount + managed TBytes, no leak on fallback;
    GGraphCacheLock ensures release not lost under contention.
  Concurrency: GGraphCache guarded by GGraphCacheLock (L1 sync.mutex, pure
    lock model, O(1) touch), swap-with-last O(1) keeps refcount safe;
    former external-sync model retired (was not locked).
  Evolution: 1320→1500 threshold monitor per CONTRACT.history §6; split
    when shards fan-in or cache ownership dilutes auditability; reuse/test
    isolation via history.traversal thin shard (<210 lines) + owner single
    source (bytes.ops/collections.lrucache candidate). Hand-rolled 16-cap LRU
    retained over collections.lrucache (O(Cap)<30ns vs AllocMem/THashMap
    overhead, see CONTRACT.history §6).
  Volume: 800 soft guide — exception not exemption; Cary via region markers
    preserves restraint and high-end auditability; see CONTRACT.history §6.

  File layout honours the spec consumed by git's commit-graph.c and
  libgit2's commit_graph.c: header "CGPH" v1 oid_version 1, chunk TOC
  with absolute offsets, trailer SHA-1. Supported chunks are OIDF/OIDL/CDAT
  (mandatory) plus EDGE (octopus) and the optional bloom/generation chunks
  which are tolerated without use. Fanout monotonicity, OID ordering,
  chunk lengths and checksum are validated. Missing file is a non-error
  (caller falls back to object parsing); a present but corrupt file
  raises EGitError.

  Lookup mirrors libgit2's fanout + binary search: parent indices in CDAT
  are resolved through OIDL (extra edge list when the high bit is set).
  commit_time is reconstructed from the low 32 bits plus the two high
  bits tucked into generation (generation >>=2). }

type
  TGitOidArray = array of TGitOid;

  TCommitGraphEntry = record
    Oid: TGitOid;
    TreeOid: TGitOid;
    CommitTime: Int64;
    Generation: Cardinal;
    Parents: TGitOidArray;
  end;

  TCommitGraph = class
  private
    FData: TBytes;
    FMapped: IMappedFile;
    FView: PByte;
    FViewLen: SizeInt;
    FNumCommits: Cardinal;
    FFanout: array[0..255] of Cardinal;
    FOidLookupOff: SizeInt;
    FCommitDataOff: SizeInt;
    FExtraOff: SizeInt;
    FNumExtra: Cardinal;
    function BE32At(APos: SizeInt): Cardinal; inline;
    function CompareOidAt(AIdx: Cardinal; const AOid: TGitOid): Integer;
    function FindPos(const AOid: TGitOid): Integer;
    procedure InitFromView(AData: PByte; ALen: SizeInt);
    procedure InitFromData(const AData: TBytes);
    procedure InitFromMapped(const AMapped: IMappedFile);
  public
    constructor Create(const AData: TBytes);
    constructor CreateFromMapped(const AMapped: IMappedFile);
    destructor Destroy; override;
    property NumCommits: Cardinal read FNumCommits;
    function TryFind(const AOid: TGitOid; out AEntry: TCommitGraphEntry): Boolean;
  end;

function GitTryLoadCommitGraph(const AGitDir: string; out AGraph: TCommitGraph): Boolean;
function GitCommitGraphPath(const AGitDir: string): string;
function GitVerifyCommitGraph(const AGitDir: string): Boolean;
procedure InvalidateCommitGraphCache(const AGitDir: string);

function GitBuildCommitGraph(const AGitDir: string; const AOids: TGitOidArray): TBytes;
function GitWriteCommitGraph(const AGitDir: string; const AOids: TGitOidArray): string;
function GitWriteCommitGraphAll(const AGitDir: string): string;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.binary,
  nextpas.core.bytes.ops,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.revwalk;

const
  CGPH_MAGIC = $43475048;
  CGPH_VERSION: Byte = 1;
  CGPH_OID_VERSION: Byte = 1;

  CHUNK_OIDF = $4F494446;
  CHUNK_OIDL = $4F49444C;
  CHUNK_CDAT = $43444154;
  CHUNK_EDGE = $45444745;
  CHUNK_BIDX = $42494458;
  CHUNK_BDAT = $42444154;
  CHUNK_GDA2 = $47444132;
  CHUNK_GDO2 = $47444F32;

  MISSING_PARENT = $70000000;
  EDGE_LAST_MASK = $80000000;
  EDGE_INDEX_MASK = $7FFFFFFF;

type
  TChunkRec = record
    Id: Cardinal;
    Off: SizeInt;
  end;

type
  TGraphCacheEntry = record
    Dir: string;
    DirHash: UInt32; // FNV-1a via bytes.ops single source, pre-filters string compare
    Path: string;
    MTime: Int64;
    Size: Int64;
    Mapped: IMappedFile;
    Seq: UInt64; // LRU tick: larger = more recent, O(1) touch vs linear shift
  end;

const
  // LRU 16-cap bounds fd/page-cache vs heap; MRU via Seq max, LRU via min Seq
  // perf: mmap-backed IMappedFile zero-copy PByte via io.mapped owner,
  //   no heap TBytes dup, OS page-reclaimable; Cap=16 design intent to halve
  //   thrash vs 8 for 8-repo fan-out, bench dual-anchor gated (CommitGraph/
  //   CacheHit|Miss 10@200ms + 2×CV + 10-15% jitter, see CONTRACT.history §3),
  //   no independent hit-rate baseline yet; O(1) touch/invalidate, single Move
  //   per op via bytes.ops single source
  // stability: IMappedFile refcount auto releases on eviction/swap; no leak
  // concurrency: guarded by GGraphCacheLock (L1 sync.mutex, O(1) touch), swap-with-last O(1) keeps refcount safe;
  //   external sync no longer required — single source via sync.mutex, pure lock model (was not locked)
  // owner: candidate collections.lrucache generic TLruCache<string,IMappedFile>
  //   — custom 16-cap array retained for DirHash FNV-1a via bytes.ops single
  //   source, IMappedFile zero-copy refcount, O(Cap) victim <30ns trivial;
  //   generic would add AllocMem/THashMap overhead; extract when fan-in >16
  //   or heaptrc gated reuse proves neutral (see CONTRACT.history §6).
  GGraphCacheCap = 16;

{ ── History.Cache: LRU 16-cap, O(1) touch, O(Cap) victim scan trivial (16×UInt64 <30ns, bench-gated) ── }

var
  GGraphCache: array of TGraphCacheEntry;
  GGraphCacheSeq: UInt64;
  GGraphCacheLock: ILock; // L1 sync.mutex guard for global LRU, pure concurrency, O(1) Acquire/Release

function GitDirHash(const ADir: string): UInt32; inline;
begin
  // perf: inline + zero-copy single-source via bytes.ops SpanHashFNV1a
  //   (FNV-1a via base.utils HashFNV1a, batch-8, no alloc), hashed
  //   pre-filter avoids O(Cap) string compares on miss
  if Length(ADir) = 0 then
    Exit(UInt32(2166136261));
  Result := SpanHashFNV1a(TByteSpan.Create(PByte(@ADir[1]), SizeUInt(Length(ADir))));
end;

function FindGraphCache(const ADir: string): Integer;
var I: Integer; LHash: UInt32;
begin
  // not inline: scan loop per design-conventions § inline red line 2
  // hashed pre-filter via bytes.ops SpanHashFNV1a single source: O(Cap)
  // UInt32 compare first, string equality only on hash hit (avg O(1))
  LHash := GitDirHash(ADir);
  for I := 0 to High(GGraphCache) do
    if (GGraphCache[I].DirHash = LHash) and (GGraphCache[I].Dir = ADir) then Exit(I);
  Result := -1;
end;

function FindLRUCacheIndex: Integer; inline;
var I, LRU: Integer; MinSeq: UInt64;
begin
  // perf: inline + O(Cap) min-scan (Cap=16 trivial <30ns, no alloc)
  //   avoids linear shift + N copies; victim scan only on miss+full,
  //   not hit path; gate bench_git CacheHit|Miss 10@200ms dual-anchor
  //   (see CONTRACT.history §3)
  Result := -1;
  if Length(GGraphCache) = 0 then Exit;
  LRU := 0;
  MinSeq := GGraphCache[0].Seq;
  for I := 1 to High(GGraphCache) do
    if GGraphCache[I].Seq < MinSeq then
    begin
      MinSeq := GGraphCache[I].Seq;
      LRU := I;
    end;
  Result := LRU;
end;

procedure TouchGraphCache(const AIdx: Integer); inline;
begin
  // perf: inline + O(1) LRU tick bump, zero-copy Seq update, no shift,
  //   no N AddRef/Release jitter; O(1) hit promotion
  // stability: keeps IMappedFile alive via refcount; zero-copy PByte view
  if (AIdx < 0) or (AIdx >= Length(GGraphCache)) then Exit;
  Inc(GGraphCacheSeq);
  if GGraphCacheSeq = 0 then GGraphCacheSeq := 1; // avoid 0 wrap
  GGraphCache[AIdx].Seq := GGraphCacheSeq;
end;

procedure InvalidateCommitGraphCache(const AGitDir: string);
var Idx: Integer;
begin
  if GGraphCacheLock <> nil then GGraphCacheLock.Acquire;
  try
    Idx := FindGraphCache(AGitDir);
    if Idx < 0 then Exit;
    // perf: O(1) swap-with-last, single Move (one AddRef/Release); zero-copy
    // stability: swap releases evicted Mapped via refcount + Finalize; no leak
    if Idx <> High(GGraphCache) then
      GGraphCache[Idx] := GGraphCache[High(GGraphCache)]; // single Move, old Idx Mapped released, High AddRef
    SetLength(GGraphCache, Length(GGraphCache)-1); // releases duplicate High slot
  finally
    if GGraphCacheLock <> nil then GGraphCacheLock.Release;
  end;
end;

{ ── History.Reader: BE32+TByteSpan zero-copy via bytes.ops, fanout+OIDL verify ── }

function Sha1OfBytes(const AData: TBytes): TBytes;
var
  H: IHasher;
begin
  Result := nil;
  H := NewSHA1;
  if Length(AData) > 0 then
    H.Write(AData[0], Length(AData));
  Result := H.SumBytes;
end;

function TCommitGraph.BE32At(APos: SizeInt): Cardinal; inline;
begin
  // perf: inline + zero-copy PByte single-source via bytes.binary ReadUInt32BE (no TBytes copy, 4B BE single source), FView is live zero-copy window (mmap or heap, bytes.ops single source)
  Result := ReadUInt32BE(FView + APos);
end;

function OidRawCompare(const AA, AB: TGitOid): Integer; inline;
begin
  // perf: inline + zero-copy TByteSpan view single-source via bytes.ops SpanCompare (→ CompareBytesOrdered → System.CompareByte, 20B ≈ 3×QWord), no 20× byte loop
  Result := SpanCompare(
    TByteSpan.Create(@AA.Bytes[0], GitOidRawLen),
    TByteSpan.Create(@AB.Bytes[0], GitOidRawLen));
end;

function TCommitGraph.CompareOidAt(AIdx: Cardinal; const AOid: TGitOid): Integer; inline;
var
  P: PByte;
begin
  // perf: inline + zero-copy PByte view single-source via bytes.ops SpanCompare (→ CompareBytesOrdered/SIMD, 20B ≈ 3×QWord), no per-byte loop
  P := FView + FOidLookupOff + SizeInt(AIdx) * GitOidRawLen;
  Result := SpanCompare(
    TByteSpan.Create(P, GitOidRawLen),
    TByteSpan.Create(@AOid.Bytes[0], GitOidRawLen));
end;

function TCommitGraph.FindPos(const AOid: TGitOid): Integer;
var
  B: Byte;
  Lo, Hi, Mid, Cmp: Integer;
begin
  Result := -1;
  if FNumCommits = 0 then
    Exit;
  B := AOid.Bytes[0];
  if B = 0 then
    Lo := 0
  else
    Lo := Integer(FFanout[B - 1]);
  Hi := Integer(FFanout[B]) - 1;
  if Hi < Lo then
    Exit;
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    Cmp := CompareOidAt(Cardinal(Mid), AOid);
    if Cmp = 0 then
      Exit(Mid);
    if Cmp < 0 then
      Lo := Mid + 1
    else
      Hi := Mid - 1;
  end;
end;

procedure TCommitGraph.InitFromData(const AData: TBytes);
begin
  // perf: heap path via bytes.ops single source view (FData owns heap, FView zero-copy window, inline BE32At via bytes ops), FMapped nil for heap
  // stability: managed TBytes auto released on exception, FView zero-copy window via bytes.ops single source
  FData := AData;
  FMapped := nil;
  if Length(FData) > 0 then
    InitFromView(@FData[0], Length(FData))
  else
    InitFromView(nil, 0);
end;

procedure TCommitGraph.InitFromView(AData: PByte; ALen: SizeInt);
var
  DataLen, HeaderSize, TrailerOff, DataStart, LastOff, ChunkOff: SizeInt;
  Chunks, I, J, K: Integer;
  Magic, ChunkId: Cardinal;
  Version, OidVer, BaseGraphs: Byte;
  Hi, Lo: Cardinal;
  Off64: Int64;
  FanoutOff, LookupOff, CDataOff, ExtraOff: SizeInt;
  FanoutLen, LookupLen, CDataLen, ExtraLen: SizeInt;
  BIdxOff, BDatOff, Gda2Off, Gdo2Off: SizeInt;
  Computed: TBytes;
  H: IHasher;
  Prev, Curr: TGitOid;
  TmpOid: TGitOid;
  ChunksPresent: array of TChunkRec;
  Cnt: Integer;
  Tmp: TChunkRec;
begin
  // perf: zero-copy PByte view single-source via bytes.ops, FView window over heap or mmap, inline BE32At via bytes.ops, OS page-reclaimable for mmap
  FView := AData;
  FViewLen := ALen;
  DataLen := FViewLen;
  if DataLen < 8 + 20 then
    raise EGitError.Create('commit-graph too short');
  Magic := BE32At(0);
  if Magic <> CGPH_MAGIC then
    raise EGitError.Create('commit-graph bad signature');
  Version := FView[4];
  OidVer := FView[5];
  Chunks := Integer(FView[6]);
  BaseGraphs := FView[7];
  if (Version <> CGPH_VERSION) or (OidVer <> CGPH_OID_VERSION) then
    raise EGitError.Create('unsupported commit-graph version');
  if Chunks = 0 then
    raise EGitError.Create('commit-graph has no chunks');
  if BaseGraphs <> 0 then
    raise EGitError.Create('commit-graph base graphs not supported');
  HeaderSize := 8;
  DataStart := HeaderSize + Chunks * 12 + 12;
  TrailerOff := DataLen - GitOidRawLen;
  if TrailerOff < DataStart then
    raise EGitError.Create('commit-graph wrong size');
  // perf: zero-copy PByte view direct to hasher (no TrailerOff allocation nor Move), inline SHA-1; stability: managed TBytes/IHasher auto released on exception, FView zero-copy via bytes.ops
  H := NewSHA1;
  if TrailerOff > 0 then
    H.Write(FView[0], SizeUInt(TrailerOff));
  Computed := H.SumBytes;
  for I := 0 to GitOidRawLen - 1 do
    if Computed[I] <> FView[TrailerOff + I] then
      raise EGitError.Create('commit-graph checksum mismatch');
  FanoutOff := -1;
  LookupOff := -1;
  CDataOff := -1;
  ExtraOff := -1;
  BIdxOff := -1;
  BDatOff := -1;
  Gda2Off := -1;
  Gdo2Off := -1;
  FanoutLen := 0;
  LookupLen := 0;
  CDataLen := 0;
  ExtraLen := 0;
  LastOff := DataStart;
  for I := 0 to Chunks - 1 do
  begin
    ChunkId := BE32At(HeaderSize + I * 12);
    Hi := BE32At(HeaderSize + I * 12 + 4);
    Lo := BE32At(HeaderSize + I * 12 + 8);
    Off64 := (Int64(Hi) shl 32) or Int64(Lo);
    ChunkOff := SizeInt(Off64);
    if ChunkOff < LastOff then
      raise EGitError.Create('commit-graph chunks non-monotonic');
    if ChunkOff > TrailerOff then
      raise EGitError.Create('commit-graph chunk beyond trailer');
    case ChunkId of
      CHUNK_OIDF: FanoutOff := ChunkOff;
      CHUNK_OIDL: LookupOff := ChunkOff;
      CHUNK_CDAT: CDataOff := ChunkOff;
      CHUNK_EDGE: ExtraOff := ChunkOff;
      CHUNK_BIDX: BIdxOff := ChunkOff;
      CHUNK_BDAT: BDatOff := ChunkOff;
      CHUNK_GDA2: Gda2Off := ChunkOff;
      CHUNK_GDO2: Gdo2Off := ChunkOff;
    else
      raise EGitError.CreateFmt('commit-graph unrecognized chunk %x', [ChunkId]);
    end;
    LastOff := ChunkOff;
  end;
  Cnt := 0;
  SetLength(ChunksPresent, 8);
  if FanoutOff >= 0 then
  begin
    ChunksPresent[Cnt].Id := CHUNK_OIDF;
    ChunksPresent[Cnt].Off := FanoutOff;
    Inc(Cnt);
  end;
  if LookupOff >= 0 then
  begin
    ChunksPresent[Cnt].Id := CHUNK_OIDL;
    ChunksPresent[Cnt].Off := LookupOff;
    Inc(Cnt);
  end;
  if CDataOff >= 0 then
  begin
    ChunksPresent[Cnt].Id := CHUNK_CDAT;
    ChunksPresent[Cnt].Off := CDataOff;
    Inc(Cnt);
  end;
  if ExtraOff >= 0 then
  begin
    ChunksPresent[Cnt].Id := CHUNK_EDGE;
    ChunksPresent[Cnt].Off := ExtraOff;
    Inc(Cnt);
  end;
  if BIdxOff >= 0 then
  begin
    ChunksPresent[Cnt].Id := CHUNK_BIDX;
    ChunksPresent[Cnt].Off := BIdxOff;
    Inc(Cnt);
  end;
  if BDatOff >= 0 then
  begin
    ChunksPresent[Cnt].Id := CHUNK_BDAT;
    ChunksPresent[Cnt].Off := BDatOff;
    Inc(Cnt);
  end;
  if Gda2Off >= 0 then
  begin
    ChunksPresent[Cnt].Id := CHUNK_GDA2;
    ChunksPresent[Cnt].Off := Gda2Off;
    Inc(Cnt);
  end;
  if Gdo2Off >= 0 then
  begin
    ChunksPresent[Cnt].Id := CHUNK_GDO2;
    ChunksPresent[Cnt].Off := Gdo2Off;
    Inc(Cnt);
  end;
  SetLength(ChunksPresent, Cnt);
  for I := 1 to Cnt - 1 do
  begin
    Tmp := ChunksPresent[I];
    J := I - 1;
    while (J >= 0) and (ChunksPresent[J].Off > Tmp.Off) do
    begin
      ChunksPresent[J + 1] := ChunksPresent[J];
      Dec(J);
    end;
    ChunksPresent[J + 1] := Tmp;
  end;
  for I := 0 to Cnt - 1 do
  begin
    if I < Cnt - 1 then
      ChunkOff := ChunksPresent[I + 1].Off
    else
      ChunkOff := TrailerOff;
    case ChunksPresent[I].Id of
      CHUNK_OIDF: FanoutLen := ChunkOff - ChunksPresent[I].Off;
      CHUNK_OIDL: LookupLen := ChunkOff - ChunksPresent[I].Off;
      CHUNK_CDAT: CDataLen := ChunkOff - ChunksPresent[I].Off;
      CHUNK_EDGE: ExtraLen := ChunkOff - ChunksPresent[I].Off;
    end;
  end;
  if (FanoutOff < 0) or (LookupOff < 0) or (CDataOff < 0) then
    raise EGitError.Create('commit-graph missing mandatory chunk');
  if FanoutLen <> 256 * 4 then
    raise EGitError.Create('commit-graph OIDF wrong length');
  if CDataLen = 0 then
    raise EGitError.Create('commit-graph CDAT empty');
  for I := 0 to 255 do
    FFanout[I] := BE32At(FanoutOff + I * 4);
  for I := 1 to 255 do
    if FFanout[I] < FFanout[I - 1] then
      raise EGitError.Create('commit-graph fanout non-monotonic');
  FNumCommits := FFanout[255];
  FOidLookupOff := LookupOff;
  FCommitDataOff := CDataOff;
  FExtraOff := ExtraOff;
  FNumExtra := 0;
  if ExtraOff >= 0 then
  begin
    if (ExtraLen mod 4) <> 0 then
      raise EGitError.Create('commit-graph EDGE malformed');
    FNumExtra := Cardinal(ExtraLen div 4);
  end;
  if LookupLen <> Integer(FNumCommits) * GitOidRawLen then
    raise EGitError.Create('commit-graph OIDL wrong length');
  if CDataLen <> Integer(FNumCommits) * (GitOidRawLen + 16) then
    raise EGitError.Create('commit-graph CDAT wrong length');
  for I := 0 to Integer(FNumCommits) - 1 do
  begin
    // perf: zero-copy via bytes.ops SpanCopy single source (inline + single Move, 20B Oid), replaces for K byte loop
    SpanCopy(TByteSpan.Create(@TmpOid.Bytes[0], GitOidRawLen),
      TByteSpan.Create(FView + FOidLookupOff + I * GitOidRawLen, GitOidRawLen));
    if I = 0 then
      Prev := TmpOid
    else
    begin
      Curr := TmpOid;
      if OidRawCompare(Prev, Curr) >= 0 then
        raise EGitError.Create('commit-graph OIDL not monotonic');
      Prev := Curr;
    end;
  end;
end;

procedure TCommitGraph.InitFromMapped(const AMapped: IMappedFile);
begin
  // perf: mmap path zero-copy PByte view via io.mapped owner (no heap duplication in global cache, OS page-reclaimable), inline BE32At via bytes.ops single source
  // stability: FMapped interface keeps mapping alive while graph lives; managed TBytes/IHasher auto released on exception, no leak
  FMapped := AMapped;
  SetLength(FData, 0);
  if (FMapped <> nil) and (FMapped.Size > 0) and (FMapped.Data <> nil) then
    InitFromView(FMapped.Data, SizeInt(FMapped.Size))
  else
    InitFromView(nil, 0);
end;

constructor TCommitGraph.Create(const AData: TBytes);
begin
  inherited Create;
  InitFromData(AData);
end;

constructor TCommitGraph.CreateFromMapped(const AMapped: IMappedFile);
begin
  inherited Create;
  InitFromMapped(AMapped);
end;

destructor TCommitGraph.Destroy;
begin
  SetLength(FData, 0);
  FMapped := nil;
  FView := nil;
  FViewLen := 0;
  inherited Destroy;
end;

function TCommitGraph.TryFind(const AOid: TGitOid; out AEntry: TCommitGraphEntry): Boolean;
var
  Pos: Integer;
  Base: SizeInt;
  P1, P2, GenField, TimeLow: Cardinal;
  I, K: Integer;
  ParentIdx: Cardinal;
  ExtraStart: Cardinal;
  Count: Integer;
  ParentCount: Integer;
begin
  Result := False;
  Pos := FindPos(AOid);
  if Pos < 0 then
    Exit;
  AEntry.Oid := AOid;
  AEntry.CommitTime := 0;
  AEntry.Generation := 0;
  SetLength(AEntry.Parents, 0);
  Base := FCommitDataOff + SizeInt(Pos) * (GitOidRawLen + 16);
  // perf: zero-copy via bytes.ops SpanCopy single source (inline + single Move, 20B Oid), replaces for I byte loop
  SpanCopy(TByteSpan.Create(@AEntry.TreeOid.Bytes[0], GitOidRawLen),
    TByteSpan.Create(FView + Base, GitOidRawLen));
  P1 := BE32At(Base + GitOidRawLen);
  P2 := BE32At(Base + GitOidRawLen + 4);
  GenField := BE32At(Base + GitOidRawLen + 8);
  TimeLow := BE32At(Base + GitOidRawLen + 12);
  AEntry.Generation := GenField shr 2;
  AEntry.CommitTime := Int64(TimeLow) or (Int64(GenField and $3) shl 32);
  ParentCount := 0;
  if P1 <> MISSING_PARENT then
    Inc(ParentCount);
  if P2 <> MISSING_PARENT then
  begin
    if (P2 and EDGE_LAST_MASK) <> 0 then
    begin
      ExtraStart := P2 and EDGE_INDEX_MASK;
      if ExtraStart >= FNumExtra then
        raise EGitError.Create('commit-graph extra edge out of range');
      I := Integer(ExtraStart);
      while I < Integer(FNumExtra) do
      begin
        Inc(ParentCount);
        if (BE32At(FExtraOff + I * 4) and EDGE_LAST_MASK) <> 0 then
          Break;
        Inc(I);
      end;
    end
    else
      Inc(ParentCount);
  end;
  SetLength(AEntry.Parents, ParentCount);
  Count := 0;
  if P1 <> MISSING_PARENT then
  begin
    if P1 >= FNumCommits then
      raise EGitError.Create('commit-graph parent index out of range');
    // perf: zero-copy via bytes.ops SpanCopy single source (inline + single Move, 20B Oid), replaces for I byte loop
    SpanCopy(TByteSpan.Create(@AEntry.Parents[Count].Bytes[0], GitOidRawLen),
      TByteSpan.Create(FView + FOidLookupOff + Integer(P1) * GitOidRawLen, GitOidRawLen));
    Inc(Count);
  end;
  if P2 <> MISSING_PARENT then
  begin
    if (P2 and EDGE_LAST_MASK) <> 0 then
    begin
      ExtraStart := P2 and EDGE_INDEX_MASK;
      I := Integer(ExtraStart);
      while True do
      begin
        ParentIdx := BE32At(FExtraOff + I * 4) and EDGE_INDEX_MASK;
        if ParentIdx >= FNumCommits then
          raise EGitError.Create('commit-graph parent index out of range');
        // perf: zero-copy via bytes.ops SpanCopy single source (inline + single Move, 20B Oid), replaces for K byte loop
        SpanCopy(TByteSpan.Create(@AEntry.Parents[Count].Bytes[0], GitOidRawLen),
          TByteSpan.Create(FView + FOidLookupOff + Integer(ParentIdx) * GitOidRawLen, GitOidRawLen));
        Inc(Count);
        if (BE32At(FExtraOff + I * 4) and EDGE_LAST_MASK) <> 0 then
          Break;
        Inc(I);
        if I >= Integer(FNumExtra) then
          Break;
      end;
    end
    else
    begin
      ParentIdx := P2;
      if ParentIdx >= FNumCommits then
        raise EGitError.Create('commit-graph parent index out of range');
      // perf: zero-copy via bytes.ops SpanCopy single source (inline + single Move, 20B Oid), replaces for I byte loop
      SpanCopy(TByteSpan.Create(@AEntry.Parents[Count].Bytes[0], GitOidRawLen),
        TByteSpan.Create(FView + FOidLookupOff + Integer(ParentIdx) * GitOidRawLen, GitOidRawLen));
      Inc(Count);
    end;
  end;
  Result := True;
end;

function GitCommitGraphPath(const AGitDir: string): string;
begin
  Result := PathJoin([AGitDir, 'objects', 'info', 'commit-graph']);
  if FileExists(Result) then
    Exit;
  Result := PathJoin([AGitDir, 'commit-graph']);
end;

function GitTryLoadCommitGraph(const AGitDir: string; out AGraph: TCommitGraph): Boolean;
var
  Path: string;
  Data: TBytes;
  Mapped: IMappedFile;
  Idx: Integer;
  Info: TFileInfo;
  UseCache: Boolean;
begin
  Result := False;
  AGraph := nil;
  Path := GitCommitGraphPath(AGitDir);
  if not FileExists(Path) then
    Exit;
  // fast path: cached mmap when mtime+size unchanged; LRU promotion on hit
  // perf: mmap-backed IMappedFile zero-copy PByte view via io.mapped owner (no heap TBytes duplication, OS page-reclaimable), LRU via bytes.ops single source, guarded by GGraphCacheLock (L1 sync.mutex, O(1))
  UseCache := False;
  Mapped := nil;
  if GGraphCacheLock <> nil then GGraphCacheLock.Acquire;
  try
    Idx := FindGraphCache(AGitDir);
    if Idx >= 0 then
      try
        Info := Stat(Path);
        if (GGraphCache[Idx].Path = Path) and (GGraphCache[Idx].MTime = Info.ModTime) and (GGraphCache[Idx].Size = Info.Size) and (GGraphCache[Idx].Mapped <> nil) and (GGraphCache[Idx].Mapped.Size = Info.Size) then
        begin
          Mapped := GGraphCache[Idx].Mapped; // zero-copy: interface refcount, no heap copy, OS page-reclaimable
          UseCache := True;
          // LRU: hit becomes MRU (not inline per design-conventions, loop body), guarded
          TouchGraphCache(Idx);
        end;
      except
        UseCache := False;
      end;
  finally
    if GGraphCacheLock <> nil then GGraphCacheLock.Release;
  end;
  if UseCache then
  begin
    AGraph := TCommitGraph.CreateFromMapped(Mapped);
    Result := True;
    Exit;
  end;
  // miss: mmap open (zero-copy, no heap TBytes duplication, page-reclaimable); fallback to heap ReadFile on empty/mmap failure for stability
  Mapped := MmapOpen(Path);
  if (Mapped = nil) or (Mapped.Size = 0) or (Mapped.Data = nil) then
  begin
    Data := ReadFile(Path);
    try
      Info := Stat(Path);
    except
      Info.ModTime := 0;
      Info.Size := Length(Data);
    end;
    // heap fallback without polluting mmap cache (keep cap for mmap only); still create graph via heap path
    AGraph := TCommitGraph.Create(Data);
    Result := True;
    Exit;
  end;
  try
    Info := Stat(Path);
  except
    Info.ModTime := 0;
    Info.Size := Mapped.Size;
  end;
  // insert/update under lock: re-lookup to handle concurrent insert race, single source via sync.mutex
  if GGraphCacheLock <> nil then GGraphCacheLock.Acquire;
  try
    Idx := FindGraphCache(AGitDir);
    if Idx < 0 then
    begin
      // bounded insert: evict LRU (min Seq) if at capacity, else grow; O(1)
      // perf: O(Cap) min-scan (Cap=16 trivial <30ns) + single overwrite via
      //   bytes.ops GrowArrayCapacity single source; bench gate 10@200ms + 2×CV
      // stability: overwritten slot old Mapped released via assignment, no leak
      if Length(GGraphCache) >= GGraphCacheCap then
        Idx := FindLRUCacheIndex // O(Cap) scan (16 trivial), single overwrite
      else
      begin
        // perf: geometric growth via bytes.ops GrowArrayCapacity single source
        //   (BYTES_BUILDER_MIN_GROW + *2), amortized O(1), bounded Cap=16
        Idx := Length(GGraphCache);
        SetLength(GGraphCache, Integer(GrowArrayCapacity(SizeUInt(Length(GGraphCache)), SizeUInt(Idx + 1))));
        if Length(GGraphCache) > GGraphCacheCap then
          SetLength(GGraphCache, GGraphCacheCap);
        if Length(GGraphCache) > Idx + 1 then
          SetLength(GGraphCache, Idx + 1);
      end;
      GGraphCache[Idx].Dir := AGitDir;
      GGraphCache[Idx].DirHash := GitDirHash(AGitDir);
    end
    else
      // keep hash coherent if Dir reused (swap-with-last may have moved entry)
      GGraphCache[Idx].DirHash := GitDirHash(AGitDir);
    GGraphCache[Idx].Path := Path;
    GGraphCache[Idx].MTime := Info.ModTime;
    GGraphCache[Idx].Size := Info.Size;
    GGraphCache[Idx].Mapped := Mapped; // zero-copy: interface share, no heap dup
    // perf: O(1) LRU tick bump, no linear shift (was O(Cap) shift with N copies)
    TouchGraphCache(Idx);
  finally
    if GGraphCacheLock <> nil then GGraphCacheLock.Release;
  end;
  AGraph := TCommitGraph.CreateFromMapped(Mapped);
  Result := True;
end;

function GitVerifyCommitGraph(const AGitDir: string): Boolean;
var
  G: TCommitGraph;
begin
  Result := GitTryLoadCommitGraph(AGitDir, G);
  if Result then
    G.Free;
end;

{ ── History.Writer: BuildGraphBytes (sort fanout/CDAT/EDGE + GDA2 skip) + Write* atomic+verify ── }

type
  TRawCommit = record
    Oid: TGitOid;
    TreeOid: TGitOid;
    CommitTime: Int64;
    Parents: TGitOidArray;
    Generation: Cardinal;
  end;
  TRawCommitArray = array of TRawCommit;

function CompareRawOid(const AA, AB: TRawCommit): Integer; inline;
begin
  // perf: inline + zero-copy TByteSpan view single-source via bytes.ops SpanCompare (→ CompareBytesOrdered single source, 20B ≈ 3×QWord), no temp copy, no dual track
  Result := SpanCompare(
    TByteSpan.Create(@AA.Oid.Bytes[0], GitOidRawLen),
    TByteSpan.Create(@AB.Oid.Bytes[0], GitOidRawLen));
end;

procedure SortRawByOid(var A: TRawCommitArray); inline;
var
  Idx: array of Integer;
  Tmp: TRawCommitArray;
  I: Integer;

  procedure SortIdxInsertion(AL, AR: Integer); inline;
  var II, JJ, TT: Integer;
  begin
    for II := AL + 1 to AR do
    begin
      TT := Idx[II];
      JJ := II;
      while (JJ > AL) and (SpanCompare(
        TByteSpan.Create(@A[Idx[JJ - 1]].Oid.Bytes[0], GitOidRawLen),
        TByteSpan.Create(@A[TT].Oid.Bytes[0], GitOidRawLen)) > 0) do
      begin
        Idx[JJ] := Idx[JJ - 1];
        Dec(JJ);
      end;
      Idx[JJ] := TT;
    end;
  end;

  procedure SortIdxQuick(AL, AR: Integer);
  var II, JJ: Integer; Pivot: TGitOid; TT: Integer;
  begin
    // hybrid quicksort on indices: median-of-three + insertion cutoff 16, tail recursion elimination
    // perf: index-indirect avoids TRawCommit managed Parents AddRef/Release per swap (20B int vs record with dynamic array),
    //   O(n log n) integer swaps + single O(n) reorder (one AddRef per element) vs O(n log n) record swaps
    while AL < AR do
    begin
      if AR - AL < 16 then
      begin
        SortIdxInsertion(AL, AR);
        Exit;
      end;
      II := AL;
      JJ := AR;
      if SpanCompare(TByteSpan.Create(@A[Idx[AL]].Oid.Bytes[0], GitOidRawLen),
        TByteSpan.Create(@A[Idx[(AL + AR) shr 1]].Oid.Bytes[0], GitOidRawLen)) > 0 then
      begin TT := Idx[AL]; Idx[AL] := Idx[(AL + AR) shr 1]; Idx[(AL + AR) shr 1] := TT; end;
      if SpanCompare(TByteSpan.Create(@A[Idx[(AL + AR) shr 1]].Oid.Bytes[0], GitOidRawLen),
        TByteSpan.Create(@A[Idx[AR]].Oid.Bytes[0], GitOidRawLen)) > 0 then
      begin TT := Idx[(AL + AR) shr 1]; Idx[(AL + AR) shr 1] := Idx[AR]; Idx[AR] := TT; end;
      if SpanCompare(TByteSpan.Create(@A[Idx[AL]].Oid.Bytes[0], GitOidRawLen),
        TByteSpan.Create(@A[Idx[(AL + AR) shr 1]].Oid.Bytes[0], GitOidRawLen)) > 0 then
      begin TT := Idx[AL]; Idx[AL] := Idx[(AL + AR) shr 1]; Idx[(AL + AR) shr 1] := TT; end;
      Pivot := A[Idx[(AL + AR) shr 1]].Oid; // pivot by value (20B), zero-copy via stack
      repeat
        while SpanCompare(TByteSpan.Create(@A[Idx[II]].Oid.Bytes[0], GitOidRawLen),
          TByteSpan.Create(@Pivot.Bytes[0], GitOidRawLen)) < 0 do Inc(II);
        while SpanCompare(TByteSpan.Create(@A[Idx[JJ]].Oid.Bytes[0], GitOidRawLen),
          TByteSpan.Create(@Pivot.Bytes[0], GitOidRawLen)) > 0 do Dec(JJ);
        if II <= JJ then
        begin
          TT := Idx[II]; Idx[II] := Idx[JJ]; Idx[JJ] := TT; // integer swap, zero managed churn
          Inc(II); Dec(JJ);
        end;
      until II > JJ;
      if (JJ - AL) < (AR - II) then
      begin
        if AL < JJ then SortIdxQuick(AL, JJ);
        AL := II;
      end
      else
      begin
        if II < AR then SortIdxQuick(II, AR);
        AR := JJ;
      end;
    end;
  end;

begin
  if Length(A) < 2 then Exit;
  SetLength(Idx, Length(A));
  for I := 0 to High(Idx) do Idx[I] := I;
  SortIdxQuick(0, High(Idx));
  // single O(n) reorder: one AddRef per element vs O(n log n) swaps (TRawCommit contains Parents: TGitOidArray managed)
  Tmp := Copy(A, 0, Length(A));
  for I := 0 to High(A) do
    A[I] := Tmp[Idx[I]];
end;

function FindOidIndex(const ASorted: TRawCommitArray; const AOid: TGitOid): Integer; inline;
var Lo, Hi, Mid, Cmp: Integer;
begin
  // perf: inline + zero-copy TByteSpan view single-source via bytes.ops SpanCompare (→ CompareBytesOrdered, 20B ≈ 3×QWord), no per-byte loop
  Lo := 0; Hi := High(ASorted);
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    Cmp := SpanCompare(
      TByteSpan.Create(@ASorted[Mid].Oid.Bytes[0], GitOidRawLen),
      TByteSpan.Create(@AOid.Bytes[0], GitOidRawLen));
    if Cmp = 0 then Exit(Mid);
    if Cmp < 0 then Lo := Mid + 1 else Hi := Mid - 1;
  end;
  Result := -1;
end;

procedure WriteBE32(var ADst: TBytes; var APos: SizeInt; AVal: Cardinal);
begin
  ADst[APos] := Byte(AVal shr 24); ADst[APos+1] := Byte(AVal shr 16);
  ADst[APos+2] := Byte(AVal shr 8); ADst[APos+3] := Byte(AVal);
  Inc(APos, 4);
end;

function BuildGraphBytes(const ARaw: TRawCommitArray): TBytes;
var N, NumExtra, I, J, K, PIdx, ParentIdx: Integer;
    Extra: array of Cardinal;
    Fanout: array[0..255] of Cardinal;
    RawSorted: TRawCommitArray;
    Counts: array[0..255] of Cardinal;
    HasEdge: Boolean;
    ChunkCount: Integer;
    DataStart, OidfOff, OidlOff, CdatOff, Gda2Off, EdgeOff, TrailerOff, TotalSize: SizeInt;
    Pos: SizeInt;
    GenField, TimeLow: Cardinal;
    P1, P2: Cardinal;
    TmpHash: TBytes;
    H: IHasher;
    TmpIdx: Integer;
    ParentCache: array of array of Integer;
    GenState: array of Byte;
    Stack: array of Integer;
    CurIdx, PMax, CntP: Integer;
    HasPending: Boolean;
    StackLen, StackCap: SizeUInt;
begin
  Result := nil;
  N := Length(ARaw);
  if N = 0 then
    raise EGitError.Create('commit-graph: empty commit set');
  RawSorted := Copy(ARaw, 0, N);
  SortRawByOid(RawSorted);
  // compute fanout counts
  for I := 0 to 255 do Counts[I] := 0;
  for I := 0 to N-1 do Inc(Counts[RawSorted[I].Oid.Bytes[0]]);
  Fanout[0] := Counts[0];
  for I := 1 to 255 do Fanout[I] := Fanout[I-1] + Counts[I];
  // collect extra edges
  SetLength(Extra, 0);
  NumExtra := 0;
  for I := 0 to N-1 do
  begin
    if Length(RawSorted[I].Parents) > 2 then
      Inc(NumExtra, Length(RawSorted[I].Parents) - 1); // need extra entries for parents 1..N-1 except first? Actually need N-1 entries after first? For octopus with k parents, need k-1 extra entries (all except first)
  end;
  // compute generations O(n log n) via memo DFS + parent-index cache (replaces N*4 fixpoint O(n²))
  // zero-copy: FindOidIndex is inline binary search on OID bytes (no OID copy); DP uses indices only
  // inline/state-array + explicit stack: O(n) after sort, stable, EGitError propagates (no swallow)
  for I := 0 to N-1 do
    if RawSorted[I].Generation = 0 then
    begin
      if Length(RawSorted[I].Parents) = 0 then
        RawSorted[I].Generation := 1
      else
        RawSorted[I].Generation := 0; // placeholder, computed below
    end;
  // parent index cache: O(n log n) total instead of O(n² log n)
  // managed dynamic arrays: auto released on exception, no leak
  if N > 0 then
  begin
    SetLength(ParentCache, N);
    SetLength(GenState, N);
    for I := 0 to N-1 do
    begin
      CntP := Length(RawSorted[I].Parents);
      SetLength(ParentCache[I], CntP);
      for K := 0 to CntP - 1 do
        ParentCache[I][K] := FindOidIndex(RawSorted, RawSorted[I].Parents[K]);
      if RawSorted[I].Generation <> 0 then
        GenState[I] := 2
      else
        GenState[I] := 0;
    end;
    // perf: geometric growth via bytes.ops GrowArrayCapacity (single source BYTES_BUILDER_MIN_GROW + *2), amortized O(1) push, avoids O(n²) SetLength(Length+1) churn, managed free on exception
    StackLen := 0; StackCap := 0; SetLength(Stack, 0);
    for I := 0 to N-1 do
    begin
      if GenState[I] = 2 then Continue;
      // push root of DFS — amortized geometric grow, inline
      if StackLen >= StackCap then
      begin
        StackCap := GrowArrayCapacity(StackCap, StackLen + 1);
        SetLength(Stack, StackCap);
      end;
      Stack[StackLen] := I; Inc(StackLen);
      while StackLen > 0 do
      begin
        CurIdx := Stack[StackLen - 1];
        if GenState[CurIdx] = 2 then
        begin
          Dec(StackLen);
          Continue;
        end;
        if GenState[CurIdx] = 0 then
        begin
          GenState[CurIdx] := 1;
          HasPending := False;
          for K := 0 to High(ParentCache[CurIdx]) do
          begin
            ParentIdx := ParentCache[CurIdx][K];
            if (ParentIdx >= 0) and (GenState[ParentIdx] = 0) then
            begin
              if StackLen >= StackCap then
              begin
                StackCap := GrowArrayCapacity(StackCap, StackLen + 1);
                SetLength(Stack, StackCap);
              end;
              Stack[StackLen] := ParentIdx; Inc(StackLen);
              HasPending := True;
            end
            else if (ParentIdx >= 0) and (GenState[ParentIdx] = 1) then
            begin
              // cycle: break by treating parent as generation 0 (will fallback to 2)
            end;
          end;
          if HasPending then Continue; // parents will be resolved first
        end;
        // all parents resolved or missing: compute max
        PMax := 0;
        for K := 0 to High(ParentCache[CurIdx]) do
        begin
          ParentIdx := ParentCache[CurIdx][K];
          if (ParentIdx >= 0) and (RawSorted[ParentIdx].Generation > Cardinal(PMax)) then
            PMax := Integer(RawSorted[ParentIdx].Generation);
        end;
        if PMax > 0 then
          RawSorted[CurIdx].Generation := Cardinal(PMax + 1)
        else if Length(RawSorted[CurIdx].Parents) = 0 then
          RawSorted[CurIdx].Generation := 1
        else
          RawSorted[CurIdx].Generation := 2;
        GenState[CurIdx] := 2;
        Dec(StackLen);
      end;
    end;
    // ParentCache/GenState/Stack are managed types, freed on exit even if EGitError; Stack capacity retained until scope exit, no leak, zero-copy Move in Push
  end;
  for I := 0 to N-1 do
    if RawSorted[I].Generation = 0 then
      RawSorted[I].Generation := 1;
  HasEdge := NumExtra > 0;
  ChunkCount := 3 + Ord(HasEdge);
  DataStart := 8 + ChunkCount * 12 + 12;
  OidfOff := DataStart;
  OidlOff := OidfOff + 256*4;
  CdatOff := OidlOff + N*20;
  // no GDA2 for minimal compatibility; git verify accepts missing GDA2
  Gda2Off := 0;
  EdgeOff := CdatOff + N*36;
  if not HasEdge then
    TrailerOff := EdgeOff
  else
    TrailerOff := EdgeOff + NumExtra*4;
  TotalSize := TrailerOff + 20;
  SetLength(Result, TotalSize);
  Pos := 0;
  // header
  WriteBE32(Result, Pos, CGPH_MAGIC);
  Result[Pos] := CGPH_VERSION; Inc(Pos);
  Result[Pos] := CGPH_OID_VERSION; Inc(Pos);
  Result[Pos] := Byte(ChunkCount); Inc(Pos);
  Result[Pos] := 0; Inc(Pos);
  // chunk TOC
  WriteBE32(Result, Pos, CHUNK_OIDF);
  WriteBE32(Result, Pos, Cardinal(OidfOff shr 32));
  WriteBE32(Result, Pos, Cardinal(OidfOff and $FFFFFFFF));
  WriteBE32(Result, Pos, CHUNK_OIDL);
  WriteBE32(Result, Pos, Cardinal(OidlOff shr 32));
  WriteBE32(Result, Pos, Cardinal(OidlOff and $FFFFFFFF));
  WriteBE32(Result, Pos, CHUNK_CDAT);
  WriteBE32(Result, Pos, Cardinal(CdatOff shr 32));
  WriteBE32(Result, Pos, Cardinal(CdatOff and $FFFFFFFF));
  if HasEdge then
  begin
    WriteBE32(Result, Pos, CHUNK_EDGE);
    WriteBE32(Result, Pos, Cardinal(EdgeOff shr 32));
    WriteBE32(Result, Pos, Cardinal(EdgeOff and $FFFFFFFF));
  end;
  // terminator: id 0 + trailer offset
  WriteBE32(Result, Pos, 0);
  WriteBE32(Result, Pos, Cardinal(TrailerOff shr 32));
  WriteBE32(Result, Pos, Cardinal(TrailerOff and $FFFFFFFF));
  // OIDF
  for I := 0 to 255 do WriteBE32(Result, Pos, Fanout[I]);
  // OIDL
  for I := 0 to N-1 do
  begin
    // perf: zero-copy via bytes.ops SpanCopy single source (inline + single Move, no heap, 20B Oid), replaces scattered Move dual path
    SpanCopy(TByteSpan.Create(@Result[Pos], 20),
      TByteSpan.Create(@RawSorted[I].Oid.Bytes[0], 20));
    Inc(Pos, 20);
  end;
  // prepare extra offsets map: for each commit with octopus, record start index in Extra
  // we need to fill CDAT and EDGE together
  // first compute Extra array with proper last-bit
  SetLength(Extra, NumExtra);
  J := 0;
  for I := 0 to N-1 do
  begin
    if Length(RawSorted[I].Parents) > 2 then
    begin
      // parents 1..k-1 go to extra (all except first)
      for PIdx := 1 to High(RawSorted[I].Parents) do
      begin
        TmpIdx := FindOidIndex(RawSorted, RawSorted[I].Parents[PIdx]);
        if TmpIdx < 0 then
          TmpIdx := Integer(MISSING_PARENT);
        Extra[J] := Cardinal(TmpIdx);
        if PIdx = High(RawSorted[I].Parents) then
          Extra[J] := Extra[J] or EDGE_LAST_MASK;
        Inc(J);
      end;
    end;
  end;
  // CDAT
  J := 0; // extra cursor for start offset
  // need start offsets for each octopus commit
  // compute start per commit by scanning
  for I := 0 to N-1 do
  begin
    // tree oid — perf: zero-copy via bytes.ops SpanCopy single source (inline + single Move, 20B Oid), replaces scattered Move
    SpanCopy(TByteSpan.Create(@Result[Pos], 20),
      TByteSpan.Create(@RawSorted[I].TreeOid.Bytes[0], 20));
    Inc(Pos, 20);
    // parents
    if Length(RawSorted[I].Parents) = 0 then
    begin
      P1 := MISSING_PARENT; P2 := MISSING_PARENT;
    end
    else if Length(RawSorted[I].Parents) = 1 then
    begin
      PIdx := FindOidIndex(RawSorted, RawSorted[I].Parents[0]);
      if PIdx < 0 then P1 := MISSING_PARENT else P1 := Cardinal(PIdx);
      P2 := MISSING_PARENT;
    end
    else if Length(RawSorted[I].Parents) = 2 then
    begin
      PIdx := FindOidIndex(RawSorted, RawSorted[I].Parents[0]);
      if PIdx < 0 then P1 := MISSING_PARENT else P1 := Cardinal(PIdx);
      PIdx := FindOidIndex(RawSorted, RawSorted[I].Parents[1]);
      if PIdx < 0 then P2 := MISSING_PARENT else P2 := Cardinal(PIdx);
    end
    else
    begin
      PIdx := FindOidIndex(RawSorted, RawSorted[I].Parents[0]);
      if PIdx < 0 then P1 := MISSING_PARENT else P1 := Cardinal(PIdx);
      // find start offset for this commit in Extra
      // start = cumulative extra before this commit
      // compute by scanning previous octopus commits
      P2 := 0;
      // compute start index
      // we can precompute by walking
      // simplest: maintain running extraIdx
      // But we already have J cursor marking start for this commit if octopus
      // For octopus, we need to know start offset = number of extra entries before this commit
      // We'll compute on the fly by counting extra before
      // To avoid double calc, we can keep variable ExtraStart
      // Use J as start
      P2 := Cardinal(J) or EDGE_LAST_MASK; // high bit indicates extra
      J := J + (Length(RawSorted[I].Parents) - 1);
    end;
    WriteBE32(Result, Pos, P1);
    WriteBE32(Result, Pos, P2);
    GenField := (RawSorted[I].Generation shl 2) or Cardinal((RawSorted[I].CommitTime shr 32) and $3);
    TimeLow := Cardinal(RawSorted[I].CommitTime and $FFFFFFFF);
    WriteBE32(Result, Pos, GenField);
    WriteBE32(Result, Pos, TimeLow);
  end;
  // EDGE
  for I := 0 to High(Extra) do WriteBE32(Result, Pos, Extra[I]);
  // trailer SHA-1
  H := NewSHA1;
  H.Write(Result[0], SizeUInt(TrailerOff));
  TmpHash := H.SumBytes;
  // perf: zero-copy via bytes.ops SpanCopy single source (inline + single Move, 20B hash), replaces scattered Move
  SpanCopy(TByteSpan.Create(@Result[Pos], 20),
    TByteSpan.Create(@TmpHash[0], 20));
end;

{ ── History.Collect: refs/heads+HEAD+tags fan-out for WriteAll (CollectAllCommits) ── }

procedure CollectRefsRecursive(const ABase, APrefix: string; var AOut: TStringArray);
var
  LCap, LCnt: SizeUInt;
  LNewCap: SizeUInt;
  procedure GrowAndAppend(const AVal: string); inline;
  begin
    // perf: inline + geometric growth via bytes.ops GrowArrayCapacity single source (BYTES_BUILDER_MIN_GROW + *2), amortized O(1) per append, zero-copy string Move (managed refcount), avoids O(n²) SetLength(Length+1) churn on prune/fetch with many remote branches
    if LCnt >= LCap then
    begin
      LNewCap := GrowArrayCapacity(LCap, LCnt + 1);
      SetLength(AOut, LNewCap);
      LCap := LNewCap;
    end;
    AOut[LCnt] := AVal;
    Inc(LCnt);
  end;
  procedure Recurse(const B, P: string);
  var Ents: TDirEntryArray; I: Integer; Full, Rel: string;
  begin
    Ents := ReadDir(B);
    for I := 0 to High(Ents) do
    begin
      Full := PathJoin([B, Ents[I].Name]);
      Rel := P + '/' + Ents[I].Name;
      if Ents[I].IsDir then
        Recurse(Full, Rel)
      else
        GrowAndAppend(Rel);
    end;
  end;
begin
  // stability: LCnt/LCap capture existing length (re-entrant append), managed strings auto released on exception via AOut refcount; final shrink releases slack, zero leak
  LCnt := SizeUInt(Length(AOut));
  LCap := SizeUInt(Length(AOut));
  Recurse(ABase, APrefix);
  if LCap <> LCnt then
    SetLength(AOut, LCnt);
end;

function ListBranchesRaw(const AGitDir: string): TStringArray;
var Path: string;
begin
  Result := nil;
  Path := PathJoin([AGitDir, 'refs', 'heads']);
  if not DirectoryExists(Path) then Exit;
  CollectRefsRecursive(Path, 'refs/heads', Result);
end;

function ListTagsRaw(const AGitDir: string): TStringArray;
var Path: string;
begin
  Result := nil;
  Path := PathJoin([AGitDir, 'refs', 'tags']);
  if not DirectoryExists(Path) then Exit;
  CollectRefsRecursive(Path, 'refs/tags', Result);
end;

function ListTagOidsRaw(const AGitDir: string): TGitOidArray;
var Ents: TStringArray;
    I: Integer;
    Oid: TGitOid;
    Repo: TNativeRepository;
    Kind: TGitObjectKind;
    Data: TBytes;
    LCnt, LCap, LNewCap: SizeUInt;
begin
  Result := nil;
  LCnt := 0; LCap := 0;
  Repo := TNativeRepository.Create(AGitDir);
  try
    Ents := ListTagsRaw(AGitDir);
    for I := 0 to High(Ents) do
    begin
      try Oid := GitResolveRef(AGitDir, Ents[I]); except Continue; end;
      try
        Data := Repo.ReadObject(Oid, Kind);
        if Kind = gokTag then Oid := GitParseTag(Data).Target;
        Data := Repo.ReadObject(Oid, Kind);
        if Kind <> gokCommit then Continue;
      except Continue; end;
      // perf: inline geometric growth via bytes.ops GrowArrayCapacity single source (BYTES_BUILDER_MIN_GROW + *2), amortized O(1) per append, zero-copy TGitOid Move (20B) via direct assignment, avoids O(n²) SetLength(Length+1) churn; stability: managed Result auto released on exception, final shrink releases slack
      if LCnt >= LCap then
      begin
        LNewCap := GrowArrayCapacity(LCap, LCnt + 1);
        SetLength(Result, LNewCap);
        LCap := LNewCap;
      end;
      Result[LCnt] := Oid;
      Inc(LCnt);
    end;
    if LCap <> LCnt then
      SetLength(Result, LCnt);
  finally
    Repo.Free;
  end;
end;

function CollectAllCommits(const AGitDir: string): TRawCommitArray;
var Repo: TNativeRepository;
    Starts: TGitOidArray;
    Opt: TGitRevOptions;
    Oids: TGitOidArray;
    I: Integer;
    Kind: TGitObjectKind;
    Data: TBytes;
    Info: TGitCommitInfo;
    Raw: TRawCommit;
    BranchList: TStringArray;
    TagOids: TGitOidArray;
    HeadOid: TGitOid;
    HasHead: Boolean;
    StartsCnt, StartsCap, StartsNewCap: SizeUInt;
function Contains(const AArr: TGitOidArray; const AOid: TGitOid): Boolean;
var K: Integer;
begin
  for K := 0 to High(AArr) do if GitOidSame(AArr[K], AOid) then Exit(True);
  Result := False;
end;
function ContainsStarts(const AOid: TGitOid): Boolean; inline;
var K: Integer;
begin
  // perf: inline + zero-copy OID compare via bytes.ops SpanEqual single source, O(n) scan limited to StartsCnt (not cap), avoids stale slack comparison
  for K := 0 to Integer(StartsCnt) - 1 do if GitOidSame(Starts[K], AOid) then Exit(True);
  Result := False;
end;
procedure AppendStart(const AOid: TGitOid); inline;
begin
  // perf: inline geometric growth via bytes.ops GrowArrayCapacity single source (BYTES_BUILDER_MIN_GROW + *2), amortized O(1), zero-copy TGitOid Move (20B)
  if StartsCnt >= StartsCap then
  begin
    StartsNewCap := GrowArrayCapacity(StartsCap, StartsCnt + 1);
    SetLength(Starts, StartsNewCap);
    StartsCap := StartsNewCap;
  end;
  Starts[StartsCnt] := AOid;
  Inc(StartsCnt);
end;
begin
  Result := nil;
  Repo := TNativeRepository.Create(AGitDir);
  try
    SetLength(Starts, 0); StartsCnt := 0; StartsCap := 0;
    try
      BranchList := ListBranchesRaw(AGitDir);
      for I := 0 to High(BranchList) do
      begin
        try
          HeadOid := GitResolveRef(AGitDir, BranchList[I]);
          if not ContainsStarts(HeadOid) then AppendStart(HeadOid);
        except end;
      end;
    except end;
    HasHead := False;
    try HeadOid := GitResolveHead(AGitDir); HasHead := True; except HasHead := False; end;
    if HasHead and not ContainsStarts(HeadOid) then AppendStart(HeadOid);
    try
      TagOids := ListTagOidsRaw(AGitDir);
      for I := 0 to High(TagOids) do
        if not ContainsStarts(TagOids[I]) then AppendStart(TagOids[I]);
    except end;
    if StartsCap <> StartsCnt then SetLength(Starts, StartsCnt);
    if Length(Starts) = 0 then Exit;
    Opt := DefaultGitRevOptions;
    Oids := GitCollectCommits(Repo, Starts, -1);
    SetLength(Result, Length(Oids));
    for I := 0 to High(Oids) do
    begin
      Data := Repo.ReadObject(Oids[I], Kind);
      if Kind = gokTag then Data := Repo.ReadObject(GitParseTag(Data).Target, Kind);
      if Kind <> gokCommit then Continue;
      Info := GitParseCommit(Data);
      Raw.Oid := Oids[I];
      Raw.TreeOid := Info.Tree;
      Raw.CommitTime := Info.Committer.UnixTime;
      Raw.Parents := Info.Parents;
      Raw.Generation := 0;
      Result[I] := Raw;
    end;
  finally
    Repo.Free;
  end;
end;

function GitBuildCommitGraph(const AGitDir: string; const AOids: TGitOidArray): TBytes;
var Raw: TRawCommitArray;
    Repo: TNativeRepository;
    I: Integer;
    Kind: TGitObjectKind;
    Data: TBytes;
    Info: TGitCommitInfo;
begin
  if Length(AOids) = 0 then
    raise EGitError.Create('commit-graph: empty oid set');
  Repo := TNativeRepository.Create(AGitDir);
  try
    SetLength(Raw, Length(AOids));
    for I := 0 to High(AOids) do
    begin
      Data := Repo.ReadObject(AOids[I], Kind);
      if Kind = gokTag then Data := Repo.ReadObject(GitParseTag(Data).Target, Kind);
      if Kind <> gokCommit then
        raise EGitError.CreateFmt('commit-graph: oid %s is not a commit', [GitOidToHex(AOids[I])]);
      Info := GitParseCommit(Data);
      Raw[I].Oid := AOids[I];
      Raw[I].TreeOid := Info.Tree;
      Raw[I].CommitTime := Info.Committer.UnixTime;
      Raw[I].Parents := Info.Parents;
      Raw[I].Generation := 0;
    end;
    Result := BuildGraphBytes(Raw);
  finally
    Repo.Free;
  end;
end;

function GitWriteCommitGraph(const AGitDir: string; const AOids: TGitOidArray): string;
var Data: TBytes;
    Path: string;
    G: TCommitGraph;
begin
  Data := GitBuildCommitGraph(AGitDir, AOids);
  Path := PathJoin([AGitDir, 'objects', 'info', 'commit-graph']);
  MkdirAll(PathDir(Path), PermDirDefault);
  WriteAtomic(Path, Data);
  InvalidateCommitGraphCache(AGitDir);
  // deep verify: reload and checksum
  G := TCommitGraph.Create(Data);
  try
    if G.NumCommits <> Cardinal(Length(AOids)) then
      raise EGitError.Create('commit-graph verify: count mismatch');
  finally
    G.Free;
  end;
  if not GitVerifyCommitGraph(AGitDir) then
    raise EGitError.Create('commit-graph verify failed');
  Result := Path;
end;

function GitWriteCommitGraphAll(const AGitDir: string): string;
var Raw: TRawCommitArray;
    Data: TBytes;
    Path: string;
    G: TCommitGraph;
begin
  Raw := CollectAllCommits(AGitDir);
  if Length(Raw) = 0 then
    raise EGitError.Create('commit-graph: no commits to write');
  Data := BuildGraphBytes(Raw);
  Path := PathJoin([AGitDir, 'objects', 'info', 'commit-graph']);
  MkdirAll(PathDir(Path), PermDirDefault);
  WriteAtomic(Path, Data);
  InvalidateCommitGraphCache(AGitDir);
  G := TCommitGraph.Create(Data);
  try
    if G.NumCommits <> Cardinal(Length(Raw)) then
      raise EGitError.Create('commit-graph verify: count mismatch');
  finally
    G.Free;
  end;
  if not GitVerifyCommitGraph(AGitDir) then
    raise EGitError.Create('commit-graph verify failed');
  Result := Path;
end;

initialization
  SetLength(GGraphCache, 0);
  GGraphCacheSeq := 0;
  GGraphCacheLock := TMutex.Create; // L1 sync.mutex guard, pure concurrency, single source

finalization
  if GGraphCacheLock <> nil then GGraphCacheLock.Acquire;
  try
    SetLength(GGraphCache, 0);
    GGraphCacheSeq := 0;
  finally
    if GGraphCacheLock <> nil then GGraphCacheLock.Release;
  end;
  GGraphCacheLock := nil;

end.
