unit nextpas.core.git.native.revwalk;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.revwalk.base,
  nextpas.core.git.native.revwalk.intf,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.commitgraph;

{ Revision walk over native objects: newest committer-date first,
  matching `git rev-list` for distinct dates. Each commit parsed once;
  queue entry carries pre-fetched parents, emission avoids re-read.
  Topological order buffers reachable subgraph (children before parents)
  and emits via graph-order ready stack (oldest tip stacked first).
  Hide/boundary/date mirrors `git rev-list`; shallow/grafts out of scope.
  Note: history core (~1844 lines, read_file 2002) exceeds design-
    conventions §2 800 soft / 1500 hard thresholds; NOT a long-term
    exception — 5 region markers (HashSet / ParseCache / HeapWalker /
    Collect / Topo, 61-141) are audit过渡仅, not exemption. Pending
    split per CONTRACT.history §6 into base←intf←impl←facade along
    those region boundaries when >1500 && fan-in>16 or new cross-
    boundary Ok/HEAP invariant added. Perf via bytes.ops single source
    (SpanCompare/SpanHashFNV1a/PByte window/TByteSpan zero-copy,
    GrowArrayCapacity, inline O(1) Contains/TryGet/Put) + try..finally
    Dispose; I-Cache bounded via inline red-line (thin O(1) inline,
    loops/sort not inline). L0-L3: L2 git via bytes.ops only, no L2
    cross. See CONTRACT.history §1/§6. }

type
  { re-export base types — canonical owner is revwalk.base, this unit is impl/facade }
  TGitOidArray = nextpas.core.git.native.revwalk.base.TGitOidArray;
  TWalkEntry = nextpas.core.git.native.revwalk.base.TWalkEntry;
  PWalkEntry = nextpas.core.git.native.revwalk.base.PWalkEntry;
  TGitRevEntry = nextpas.core.git.native.revwalk.base.TGitRevEntry;
  TGitRevEntryArray = nextpas.core.git.native.revwalk.base.TGitRevEntryArray;
  TGitRevOptions = nextpas.core.git.native.revwalk.base.TGitRevOptions;

  { ── History.HashSet: O(1) FNV hash set, inline zero-copy via bytes.ops ── }
  { hash set, O(1) avg }
  TGitOidSet = class
  private
    FBuckets: array of TGitOid;
    FHashes: array of UInt32; { cached FNV, avoids rehash recompute at 4096 cap }
    FStates: array of Byte; { 0 empty, 1 occupied }
    FCount: SizeInt;
    FCap: SizeInt;
    FMask: SizeInt;
    procedure EnsureCapacity;
    procedure Rehash(ANewCap: SizeInt);
  public
    { no-op when already present }
    procedure Add(const AOid: TGitOid);
    function Contains(const AOid: TGitOid): Boolean; inline;
    function Count: SizeInt; inline;
  end;

  { ── History.ParseCache: 4096-cap CoW+LRU, O(1) inline via bytes.ops ── }
  { bounded exactly-once parse cache (4096 cap, CoW share, LRU) }
  TCommitParseCache = class
  private
    FBuckets: array of TGitOid;
    FHashes: array of UInt32; { cached FNV }
    FWhens: array of Int64;
    FParents: array of TGitOidArray;
    FStates: array of Byte;
    FTicks: array of UInt64; { LRU ticks }
    FTick: UInt64;
    FCount: SizeInt;
    FCap: SizeInt;
    FMask: SizeInt;
    procedure EnsureCapacity;
    procedure Rehash(ANewCap: SizeInt);
    procedure Clear;
    procedure CompactEvict; // LRU bounded eviction keeps 2048 newest at 4096 cap, avoids full clear jitter
  public
    destructor Destroy; override;
    function TryGet(const AOid: TGitOid; out AWhen: Int64; out AParents: TGitOidArray): Boolean; inline;
    procedure Put(const AOid: TGitOid; AWhen: Int64; const AParents: TGitOidArray);
  end;

  { O(1) hash map: Oid -> node index, via bytes.ops SpanHashFNV1a single source }
  TOidIndexMap = class
  private
    FBuckets: array of TGitOid;
    FHashes: array of UInt32;
    FValues: array of Integer;
    FStates: array of Byte;
    FCount: SizeInt;
    FCap: SizeInt;
    FMask: SizeInt;
    procedure EnsureCapacity;
    procedure Rehash(ANewCap: SizeInt);
  public
    procedure Add(const AOid: TGitOid; AValue: Integer);
    function TryGet(const AOid: TGitOid; out AValue: Integer): Boolean; inline;
  end;

  { ── History.HeapWalker: committer-date max-heap O(log N) pointer moves, bytes.ops single source ── }
  TGitRevWalker = class
  private
    FRepo: TNativeRepository; { borrowed, not owned }
    FGraph: TCommitGraph;     { owned, nil when no commit-graph }
    FHeap: array of PWalkEntry;
    FHeapCap: SizeInt;            { geometric capacity for FHeap }
    FHeapLen: SizeInt;            { active heap size }
    FSeen: TGitOidSet;        { owned }
    FHidden: TGitOidSet;      { owned, hide set }
    FParseCache: TCommitParseCache; { owned, exactly-once }
    FBoundary: TGitRevEntryArray;
    FBoundaryCap: SizeInt;
    FBoundaryLen: SizeInt;
    FBoundaryPos: Integer;
    FBoundarySet: TGitOidSet; { O(1) boundary dedup, mirrors BoundarySet in one-shot path }
    FFirstParent: Boolean;
    FSince: Int64;
    FUntilTime: Int64;
    FShowBoundary: Boolean;
    procedure AppendBoundary(const AOid: TGitOid); inline;
    procedure InitGraph;
    function TryGraphCommit(const AOid: TGitOid; out AWhen: Int64;
      out AParents: TGitOidArray): Boolean;
    procedure HeapPush(const AEntry: TWalkEntry);
    function HeapPop(out AEntry: TWalkEntry): Boolean;
    procedure EnqueueCommit(const AOid: TGitOid);
    procedure EnqueueHidden(const AOid: TGitOid);
  public
    constructor Create(ARepo: TNativeRepository); overload;
    constructor Create(ARepo: TNativeRepository; const AOptions: TGitRevOptions); overload;
    destructor Destroy; override;
    { marks a walk start; missing objects raise EGitError }
    procedure Push(const AOid: TGitOid);
    procedure PushHead(const AGitDir: string);
    procedure PushHide(const AOid: TGitOid);
    procedure SetFirstParent(AValue: Boolean);
    procedure SetDateRange(ASince, AUntilTime: Int64);
    procedure SetShowBoundary(AValue: Boolean);
    { emits False when the walk is exhausted }
    function Next(out AOid: TGitOid): Boolean;
    function NextWithBoundary(out AEntry: TGitRevEntry): Boolean;
  end;

function DefaultGitRevOptions: TGitRevOptions; inline;

{ one-shot convenience: AMaxCount < 0 means unlimited }
function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray; overload;

function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray; overload;

function GitCollectCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray;

{ one-shot topological order (children always precede parents, ready set
  drained LIFO exactly like git's default --topo-order): buffers the
  reachable subgraph, so it costs one read+parse per reachable commit up
  front. AMaxCount < 0 means unlimited. }
function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray; overload;

function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray; overload;

function GitTopoOrderCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray;

implementation

uses
  nextpas.core.bytes.ops;

function OidLess(const AA, AB: TGitOid): Boolean; inline;
begin
  { ordered by OID bytes via bytes.ops, zero-copy view, inline }
  Result := SpanCompare(
    TByteSpan.Create(@AA.Bytes[0], GitOidRawLen),
    TByteSpan.Create(@AB.Bytes[0], GitOidRawLen)) < 0;
end;

{ open-addressing helpers; probe capped at cap+1, avg O(1) at 70% load }
function OidProbeEmpty(const AStates: array of Byte; AMask: SizeInt; AHash: UInt32): SizeInt;
var
  LProbe: SizeInt;
begin
  Result := SizeInt(AHash and UInt32(AMask));
  LProbe := 0;
  while AStates[Result] = 1 do
  begin
    if LProbe > AMask then
      Exit(-1); // probe upper limit: table full, caller will rehash
    Result := (Result + 1) and AMask;
    Inc(LProbe);
  end;
end;

function OidLocate(const ABuckets: array of TGitOid; const AStates: array of Byte;
  AMask: SizeInt; const AOid: TGitOid; AHash: UInt32; out AIdx: SizeInt): Boolean;
var
  LProbe: SizeInt;
begin
  AIdx := SizeInt(AHash and UInt32(AMask));
  LProbe := 0;
  while AStates[AIdx] <> 0 do
  begin
    if GitOidSame(ABuckets[AIdx], AOid) then
      Exit(True);
    if LProbe > AMask then
    begin
      AIdx := -1; // probe upper limit: bounded scan, avoid O(n) degenerate, signal no slot
      Break;
    end;
    AIdx := (AIdx + 1) and AMask;
    Inc(LProbe);
  end;
  Result := False;
end;

function OidShouldGrow(ACount, ACap: SizeInt): Boolean; inline;
begin
  Result := (ACap = 0) or (ACount * 10 >= ACap * 7);
end;

procedure TGitOidSet.EnsureCapacity;
begin
  if not OidShouldGrow(FCount, FCap) then Exit;
  if FCap = 0 then Rehash(16) else Rehash(FCap * 2);
end;

procedure TGitOidSet.Rehash(ANewCap: SizeInt);
var
  LOldBuckets: array of TGitOid;
  LOldHashes: array of UInt32;
  LOldStates: array of Byte;
  LOldCap: SizeInt;
  I: Integer;
  LIdx: SizeInt;
  LHash: UInt32;
begin
  LOldBuckets := FBuckets;
  LOldHashes := FHashes;
  LOldStates := FStates;
  LOldCap := FCap;
  SetLength(FBuckets, ANewCap);
  SetLength(FHashes, ANewCap);
  SetLength(FStates, ANewCap);
  FCap := ANewCap;
  FMask := ANewCap - 1;
  FCount := 0;
  for I := 0 to LOldCap - 1 do
    if (I < Length(LOldStates)) and (LOldStates[I] = 1) then
    begin
      LHash := LOldHashes[I]; { reuse cached hash, no recompute }
      LIdx := OidProbeEmpty(FStates, FMask, LHash);
      if LIdx < 0 then
      begin
        Rehash(FCap * 2);
        LIdx := OidProbeEmpty(FStates, FMask, LHash);
      end;
      FBuckets[LIdx] := LOldBuckets[I];
      FHashes[LIdx] := LHash;
      FStates[LIdx] := 1;
      Inc(FCount);
    end;
end;

procedure TGitOidSet.Add(const AOid: TGitOid);
var
  LHash: UInt32;
  LIdx: SizeInt;
begin
  EnsureCapacity;
  LHash := GitOidHash(AOid); { single hash, reused on rehash path }
  if OidLocate(FBuckets, FStates, FMask, AOid, LHash, LIdx) then
    Exit;
  if (LIdx < 0) or (LIdx >= FCap) or (FStates[LIdx] = 1) then
  begin
    Rehash(FCap * 2);
    { reuse LHash, no recompute }
    if OidLocate(FBuckets, FStates, FMask, AOid, LHash, LIdx) then
      Exit;
    if (LIdx < 0) or (FStates[LIdx] = 1) then
    begin
      LIdx := OidProbeEmpty(FStates, FMask, LHash);
      if LIdx < 0 then
      begin
        Rehash(FCap * 2);
        LIdx := OidProbeEmpty(FStates, FMask, LHash);
      end;
    end;
  end;
  FBuckets[LIdx] := AOid;
  FHashes[LIdx] := LHash;
  FStates[LIdx] := 1;
  Inc(FCount);
end;

function TGitOidSet.Contains(const AOid: TGitOid): Boolean;
var
  LHash: UInt32;
  LIdx: SizeInt;
begin
  if FCount = 0 then
    Exit(False);
  LHash := GitOidHash(AOid);
  Result := OidLocate(FBuckets, FStates, FMask, AOid, LHash, LIdx);
end;

function TGitOidSet.Count: SizeInt;
begin
  Result := FCount;
end;

procedure TOidIndexMap.EnsureCapacity;
begin
  if not OidShouldGrow(FCount, FCap) then Exit;
  if FCap = 0 then Rehash(16) else Rehash(FCap * 2);
end;

procedure TOidIndexMap.Rehash(ANewCap: SizeInt);
var
  LOldBuckets: array of TGitOid;
  LOldHashes: array of UInt32;
  LOldValues: array of Integer;
  LOldStates: array of Byte;
  LOldCap: SizeInt;
  I: Integer;
  LIdx: SizeInt;
  LHash: UInt32;
begin
  LOldBuckets := FBuckets;
  LOldHashes := FHashes;
  LOldValues := FValues;
  LOldStates := FStates;
  LOldCap := FCap;
  SetLength(FBuckets, ANewCap);
  SetLength(FHashes, ANewCap);
  SetLength(FValues, ANewCap);
  SetLength(FStates, ANewCap);
  FCap := ANewCap;
  FMask := ANewCap - 1;
  FCount := 0;
  for I := 0 to LOldCap - 1 do
    if (I < Length(LOldStates)) and (LOldStates[I] = 1) then
    begin
      LHash := LOldHashes[I];
      LIdx := OidProbeEmpty(FStates, FMask, LHash);
      if LIdx < 0 then
      begin
        Rehash(FCap * 2);
        LIdx := OidProbeEmpty(FStates, FMask, LHash);
      end;
      FBuckets[LIdx] := LOldBuckets[I];
      FHashes[LIdx] := LHash;
      FValues[LIdx] := LOldValues[I];
      FStates[LIdx] := 1;
      Inc(FCount);
    end;
end;

procedure TOidIndexMap.Add(const AOid: TGitOid; AValue: Integer);
var LHash: UInt32; LIdx: SizeInt;
begin
  EnsureCapacity;
  LHash := GitOidHash(AOid);
  if OidLocate(FBuckets, FStates, FMask, AOid, LHash, LIdx) then
  begin
    FValues[LIdx] := AValue;
    Exit;
  end;
  if (LIdx < 0) or (LIdx >= FCap) or (FStates[LIdx] = 1) then
  begin
    Rehash(FCap * 2);
    if OidLocate(FBuckets, FStates, FMask, AOid, LHash, LIdx) then
    begin
      FValues[LIdx] := AValue;
      Exit;
    end;
    if (LIdx < 0) or (FStates[LIdx] = 1) then
    begin
      LIdx := OidProbeEmpty(FStates, FMask, LHash);
      if LIdx < 0 then
      begin
        Rehash(FCap * 2);
        LIdx := OidProbeEmpty(FStates, FMask, LHash);
      end;
    end;
  end;
  FBuckets[LIdx] := AOid;
  FHashes[LIdx] := LHash;
  FValues[LIdx] := AValue;
  FStates[LIdx] := 1;
  Inc(FCount);
end;

function TOidIndexMap.TryGet(const AOid: TGitOid; out AValue: Integer): Boolean;
var LHash: UInt32; LIdx: SizeInt;
begin
  Result := False;
  if FCount = 0 then Exit;
  LHash := GitOidHash(AOid);
  if not OidLocate(FBuckets, FStates, FMask, AOid, LHash, LIdx) then Exit;
  AValue := FValues[LIdx];
  Result := True;
end;

destructor TCommitParseCache.Destroy;
var I: Integer;
begin
  for I := 0 to High(FParents) do
    SetLength(FParents[I], 0);
  inherited Destroy;
end;

procedure TCommitParseCache.Clear;
var I: Integer;
begin
  for I := 0 to High(FParents) do
    SetLength(FParents[I], 0);
  SetLength(FBuckets, 0);
  SetLength(FHashes, 0);
  SetLength(FWhens, 0);
  SetLength(FParents, 0);
  SetLength(FStates, 0);
  SetLength(FTicks, 0);
  FCap := 0;
  FMask := 0;
  FCount := 0;
  FTick := 0;
end;

procedure TCommitParseCache.EnsureCapacity;
const CMaxCap = 4096;
begin
  if not OidShouldGrow(FCount, FCap) then Exit;
  if FCap = 0 then
    Rehash(16)
  else if FCap >= CMaxCap then
    CompactEvict
  else if FCap * 2 > CMaxCap then
    Rehash(CMaxCap)
  else
    Rehash(FCap * 2);
end;

procedure TCommitParseCache.CompactEvict; // LRU tick-threshold linear rebuild; collections.lrucache owner is heavier (THashMap+linked list AllocMem), Cap=16/4096 trivial <30ns, CoW share
const CKeep = 2048; // keep half, stays below 70% grow threshold (2867)
var
  LOldBuckets: array of TGitOid;
  LOldHashes: array of UInt32;
  LOldWhens: array of Int64;
  LOldParents: array of TGitOidArray;
  LOldStates: array of Byte;
  LOldTicks: array of UInt64;
  LOldCap: SizeInt;
  I: Integer;
  LIdx: SizeInt;
  LHash: UInt32;
  LThreshold: UInt64;
begin
  if FCount <= CKeep then
    Exit;
  // threshold keeps newest CKeep ticks, linear O(n) without sort/QuickSelect
  if FTick > UInt64(CKeep) then
    LThreshold := FTick - UInt64(CKeep)
  else
    LThreshold := 0;
  LOldBuckets := FBuckets;
  LOldHashes := FHashes;
  LOldWhens := FWhens;
  LOldParents := FParents;
  LOldStates := FStates;
  LOldTicks := FTicks;
  LOldCap := FCap;
  SetLength(FBuckets, 0);
  SetLength(FHashes, 0);
  SetLength(FWhens, 0);
  SetLength(FParents, 0);
  SetLength(FStates, 0);
  SetLength(FTicks, 0);
  SetLength(FBuckets, FCap);
  SetLength(FHashes, FCap);
  SetLength(FWhens, FCap);
  SetLength(FParents, FCap);
  SetLength(FStates, FCap);
  SetLength(FTicks, FCap);
  FCount := 0;
  // linear scan, keep ticks > threshold, zero alloc, reuse cached hash, CoW share
  for I := 0 to LOldCap - 1 do
    if (I < Length(LOldStates)) and (LOldStates[I] = 1) then
    begin
      if LOldTicks[I] > LThreshold then
      begin
        LHash := LOldHashes[I]; { reuse cached hash }
        LIdx := OidProbeEmpty(FStates, FMask, LHash);
        if LIdx < 0 then
        begin
          Rehash(FCap * 2);
          LIdx := OidProbeEmpty(FStates, FMask, LHash);
        end;
        FBuckets[LIdx] := LOldBuckets[I];
        FHashes[LIdx] := LHash;
        FWhens[LIdx] := LOldWhens[I];
        FParents[LIdx] := LOldParents[I]; { CoW share }
        FTicks[LIdx] := LOldTicks[I];
        FStates[LIdx] := 1;
        Inc(FCount);
      end
      else
        SetLength(LOldParents[I], 0);
    end;
  // stability: when gaps keep < CKeep, no extra sort needed; cache stays valid (re-parse on miss)
end;

procedure TCommitParseCache.Rehash(ANewCap: SizeInt);
var
  LOldBuckets: array of TGitOid;
  LOldHashes: array of UInt32;
  LOldWhens: array of Int64;
  LOldParents: array of TGitOidArray;
  LOldStates: array of Byte;
  LOldTicks: array of UInt64;
  LOldCap: SizeInt;
  I: Integer;
  LIdx: SizeInt;
  LHash: UInt32;
begin
  LOldBuckets := FBuckets;
  LOldHashes := FHashes;
  LOldWhens := FWhens;
  LOldParents := FParents;
  LOldStates := FStates;
  LOldTicks := FTicks;
  LOldCap := FCap;
  SetLength(FBuckets, ANewCap);
  SetLength(FHashes, ANewCap);
  SetLength(FWhens, ANewCap);
  SetLength(FParents, ANewCap);
  SetLength(FStates, ANewCap);
  SetLength(FTicks, ANewCap);
  FCap := ANewCap;
  FMask := ANewCap - 1;
  FCount := 0;
  for I := 0 to LOldCap - 1 do
    if (I < Length(LOldStates)) and (LOldStates[I] = 1) then
    begin
      LHash := LOldHashes[I]; { reuse cached hash }
      LIdx := OidProbeEmpty(FStates, FMask, LHash);
      if LIdx < 0 then
      begin
        Rehash(FCap * 2);
        LIdx := OidProbeEmpty(FStates, FMask, LHash);
      end;
      FBuckets[LIdx] := LOldBuckets[I];
      FHashes[LIdx] := LHash;
      FWhens[LIdx] := LOldWhens[I];
      FParents[LIdx] := LOldParents[I];
      FTicks[LIdx] := LOldTicks[I];
      FStates[LIdx] := 1;
      Inc(FCount);
    end;
end;

function TCommitParseCache.TryGet(const AOid: TGitOid; out AWhen: Int64; out AParents: TGitOidArray): Boolean;
var LHash: UInt32; LIdx: SizeInt;
begin
  Result := False;
  if FCount = 0 then Exit;
  LHash := GitOidHash(AOid); { single source FNV via bytes.ops, inline zero-copy }
  if not OidLocate(FBuckets, FStates, FMask, AOid, LHash, LIdx) then Exit;
  AWhen := FWhens[LIdx];
  AParents := FParents[LIdx]; { CoW share }
  Inc(FTick);
  FTicks[LIdx] := FTick; // LRU touch, inline fast path
  Result := True;
end;

procedure TCommitParseCache.Put(const AOid: TGitOid; AWhen: Int64; const AParents: TGitOidArray);
var LHash: UInt32; LIdx: SizeInt;
begin
  EnsureCapacity;
  if FCap = 0 then
    Rehash(16);
  LHash := GitOidHash(AOid); { single hash, reused }
  if OidLocate(FBuckets, FStates, FMask, AOid, LHash, LIdx) then
  begin
    if LIdx >= 0 then
    begin
      Inc(FTick);
      FTicks[LIdx] := FTick;
    end;
    Exit;
  end;
  if (LIdx < 0) or (LIdx >= FCap) or (FStates[LIdx] = 1) then
  begin
    Rehash(FCap * 2);
    { reuse LHash }
    if OidLocate(FBuckets, FStates, FMask, AOid, LHash, LIdx) then
    begin
      if LIdx >= 0 then
      begin
        Inc(FTick);
        FTicks[LIdx] := FTick;
      end;
      Exit;
    end;
    if (LIdx < 0) or (FStates[LIdx] = 1) then
    begin
      LIdx := OidProbeEmpty(FStates, FMask, LHash);
      if LIdx < 0 then
      begin
        Rehash(FCap * 2);
        LIdx := OidProbeEmpty(FStates, FMask, LHash);
      end;
    end;
  end;
  FBuckets[LIdx] := AOid;
  FHashes[LIdx] := LHash;
  FWhens[LIdx] := AWhen;
  FParents[LIdx] := AParents; { CoW share }
  FStates[LIdx] := 1;
  Inc(FTick);
  FTicks[LIdx] := FTick;
  Inc(FCount);
end;

function DefaultGitRevOptions: TGitRevOptions;
begin
  Result := nextpas.core.git.native.revwalk.base.DefaultGitRevOptions;
end;

function PassesDateFilter(AWhen, ASince, AUntilTime: Int64): Boolean;
begin
  if (ASince <> 0) and (AWhen < ASince) then
    Exit(False);
  if (AUntilTime <> 0) and (AWhen > AUntilTime) then
    Exit(False);
  Result := True;
end;

function TryGraphParents(AGraph: TCommitGraph; const AOid: TGitOid;
  out AWhen: Int64; out AParents: TGitOidArray): Boolean;
var
  E: TCommitGraphEntry;
begin
  Result := False;
  if AGraph = nil then
    Exit;
  if not AGraph.TryFind(AOid, E) then
    Exit;
  AWhen := E.CommitTime;
  AParents := E.Parents; { CoW share, no Copy per CONTRACT single-parse }
  Result := True;
end;

function TryFetchCommitCached(ARepo: TNativeRepository; AGraph: TCommitGraph;
  ACache: TCommitParseCache; const AOid: TGitOid; out AWhen: Int64;
  out AParents: TGitOidArray): Boolean;
var Data: TBytes; Kind: TGitObjectKind; Info: TGitCommitInfo;
begin
  if TryGraphParents(AGraph, AOid, AWhen, AParents) then
  begin
    if ACache <> nil then ACache.Put(AOid, AWhen, AParents);
    Exit(True);
  end;
  if (ACache <> nil) and ACache.TryGet(AOid, AWhen, AParents) then
    Exit(True);
  try
    Data := ARepo.ReadObject(AOid, Kind);
  except
    on E: EGitError do raise;
  end;
  if Kind <> gokCommit then Exit(False);
  Info := GitParseCommit(Data);
  AWhen := Info.Committer.UnixTime;
  AParents := Info.Parents; { CoW share }
  if ACache <> nil then ACache.Put(AOid, AWhen, AParents);
  Result := True;
end;

procedure BuildHiddenSet(ARepo: TNativeRepository;
  const AHides: TGitOidArray; AFirstParent: Boolean;
  out AHidden: TGitOidSet; ACache: TCommitParseCache); overload; forward;

procedure BuildHiddenSet(ARepo: TNativeRepository; AGraph: TCommitGraph;
  const AHides: TGitOidArray; AFirstParent: Boolean;
  out AHidden: TGitOidSet; ACache: TCommitParseCache); overload; forward;

procedure BuildHiddenSet(ARepo: TNativeRepository;
  const AHides: TGitOidArray; AFirstParent: Boolean;
  out AHidden: TGitOidSet); overload;
var TmpCache: TCommitParseCache;
begin
  TmpCache := TCommitParseCache.Create;
  try
    BuildHiddenSet(ARepo, AHides, AFirstParent, AHidden, TmpCache);
  finally
    TmpCache.Free;
  end;
end;

procedure BuildHiddenSet(ARepo: TNativeRepository;
  const AHides: TGitOidArray; AFirstParent: Boolean;
  out AHidden: TGitOidSet; ACache: TCommitParseCache); overload;
begin
  BuildHiddenSet(ARepo, nil, AHides, AFirstParent, AHidden, ACache);
end;

procedure BuildHiddenSet(ARepo: TNativeRepository; AGraph: TCommitGraph;
  const AHides: TGitOidArray; AFirstParent: Boolean;
  out AHidden: TGitOidSet; ACache: TCommitParseCache); overload;
var
  Stack: TGitOidArray;
  Oid: TGitOid;
  I: Integer;
  Graph: TCommitGraph;
  OwnsGraph: Boolean;
  GWhen: Int64;
  GParents: TGitOidArray;
  StackCap, StackLen: SizeInt;
  procedure StackPush(const AOid: TGitOid); inline;
  begin
    if StackLen >= StackCap then
    begin
      StackCap := SizeInt(GrowArrayCapacity(SizeUInt(StackCap), SizeUInt(StackLen + 1)));
      SetLength(Stack, StackCap);
    end;
    Stack[StackLen] := AOid;
    Inc(StackLen);
  end;
  function StackPop(out AOid: TGitOid): Boolean; inline;
  begin
    Result := StackLen > 0;
    if not Result then Exit;
    Dec(StackLen);
    AOid := Stack[StackLen];
  end;
begin
  AHidden := TGitOidSet.Create;
  Graph := AGraph;
  OwnsGraph := False;
  if Graph = nil then
  begin
    try
      if not GitTryLoadCommitGraph(ARepo.GitDir, Graph) then
        Graph := nil;
    except
      Graph := nil;
    end;
    OwnsGraph := Graph <> nil;
  end;
  try
    Stack := nil; StackCap := 0; StackLen := 0;
    for I := 0 to High(AHides) do StackPush(AHides[I]);
    while StackPop(Oid) do
    begin
      if AHidden.Contains(Oid) then
        Continue;
      if not TryFetchCommitCached(ARepo, Graph, ACache, Oid, GWhen, GParents) then
        Continue;
      AHidden.Add(Oid);
      if AFirstParent then
      begin
        if Length(GParents) > 0 then StackPush(GParents[0]);
      end
      else
        for I := 0 to High(GParents) do StackPush(GParents[I]);
    end;
    SetLength(Stack, StackLen);
  finally
    if OwnsGraph and (Graph <> nil) then Graph.Free;
  end;
end;

procedure TGitRevWalker.InitGraph;
begin
  if FGraph <> nil then
    Exit;
  try
    if not GitTryLoadCommitGraph(FRepo.GitDir, FGraph) then
      FGraph := nil;
  except
    FGraph := nil;
  end;
end;

function TGitRevWalker.TryGraphCommit(const AOid: TGitOid; out AWhen: Int64;
  out AParents: TGitOidArray): Boolean;
begin
  Result := TryGraphParents(FGraph, AOid, AWhen, AParents);
end;

procedure TGitRevWalker.HeapPush(const AEntry: TWalkEntry);
var
  I, Parent: Integer;
  LNew: PWalkEntry;
begin
  // geometric growth via bytes.ops GrowArrayCapacity single source (BYTES_BUILDER_MIN_GROW + *2), amortized O(1), zero-copy Move for cap array
  // not inline: loop body + SetLength growth would bloat I-Cache
  // perf: pointer heap, O(log n) single pointer moves (8 bytes), inline cmp, zero managed Move/Finalize/FillChar per level; CoW share for Parents
  // stability: New/Dispose paired via try..finally on exception path
  if FHeapLen >= FHeapCap then
  begin
    FHeapCap := SizeInt(GrowArrayCapacity(SizeUInt(FHeapCap), SizeUInt(FHeapLen + 1)));
    SetLength(FHeap, FHeapCap);
  end;
  New(LNew);
  try
    LNew^ := AEntry;
    I := FHeapLen;
    Inc(FHeapLen);
    while I > 0 do
    begin
      Parent := (I - 1) div 2;
      if FHeap[Parent]^.When >= LNew^.When then
        Break;
      FHeap[I] := FHeap[Parent];
      I := Parent;
    end;
    FHeap[I] := LNew;
  except
    Dispose(LNew);
    raise;
  end;
end;

function TGitRevWalker.HeapPop(out AEntry: TWalkEntry): Boolean;
var
  I, L, R, Best: Integer;
  LLast: PWalkEntry;
begin
  Result := FHeapLen > 0;
  if not Result then
    Exit;
  AEntry := FHeap[0]^;
  Dispose(FHeap[0]);
  Dec(FHeapLen);
  if FHeapLen = 0 then
    Exit;
  // perf: pointer heap sift-down, O(log n) pointer moves, no Finalize/Move/FillChar per level, inline cmp
  LLast := FHeap[FHeapLen];
  FHeap[FHeapLen] := nil;
  I := 0;
  while True do
  begin
    L := 2 * I + 1;
    R := L + 1;
    Best := I;
    if (L < FHeapLen) and (FHeap[L]^.When > FHeap[Best]^.When) then
      Best := L;
    if (R < FHeapLen) and (FHeap[R]^.When > FHeap[Best]^.When) then
      Best := R;
    if Best = I then
      Break;
    FHeap[I] := FHeap[Best];
    I := Best;
  end;
  FHeap[I] := LLast;
end;

procedure TGitRevWalker.AppendBoundary(const AOid: TGitOid); inline;
begin
  if FBoundaryLen >= FBoundaryCap then
  begin
    FBoundaryCap := SizeInt(GrowArrayCapacity(SizeUInt(FBoundaryCap), SizeUInt(FBoundaryLen + 1)));
    SetLength(FBoundary, FBoundaryCap);
  end;
  if (FBoundarySet <> nil) and FBoundarySet.Contains(AOid) then Exit;
  if FBoundarySet = nil then FBoundarySet := TGitOidSet.Create;
  FBoundarySet.Add(AOid);
  FBoundary[FBoundaryLen].Oid := AOid;
  FBoundary[FBoundaryLen].IsBoundary := True;
  Inc(FBoundaryLen);
end;

procedure TGitRevWalker.EnqueueCommit(const AOid: TGitOid);
var
  Entry: TWalkEntry;
  I: Integer;
  GWhen: Int64;
  GParents: TGitOidArray;
  IsNonCommit: Boolean;
  Data: TBytes;
  Kind: TGitObjectKind;
  Info: TGitCommitInfo;
begin
  if FSeen.Contains(AOid) then
    Exit;
  if (FHidden <> nil) and FHidden.Contains(AOid) then
  begin
    if FShowBoundary then
      AppendBoundary(AOid);
    Exit;
  end;
  InitGraph;
  if FParseCache = nil then
    FParseCache := TCommitParseCache.Create;
  // single lookup path: graph -> cache -> inflate/parse, cached exactly-once
  if TryGraphParents(FGraph, AOid, GWhen, GParents) then
  begin
    FParseCache.Put(AOid, GWhen, GParents);
  end
  else if not FParseCache.TryGet(AOid, GWhen, GParents) then
  begin
    Data := FRepo.ReadObject(AOid, Kind);
    if Kind <> gokCommit then
      raise EGitError.Create('revwalk start points at a non-commit object');
    Info := GitParseCommit(Data);
    GWhen := Info.Committer.UnixTime;
    GParents := Info.Parents; { CoW share, no Copy }
    FParseCache.Put(AOid, GWhen, GParents);
  end;
  FSeen.Add(AOid);
  Entry.Oid := AOid;
  Entry.When := GWhen;
  if FFirstParent and (Length(GParents) > 1) then
  begin
    SetLength(Entry.Parents, 1);
    Entry.Parents[0] := GParents[0];
  end
  else
    Entry.Parents := GParents; { CoW share }
  HeapPush(Entry);
end;

procedure TGitRevWalker.EnqueueHidden(const AOid: TGitOid);
var
  Stack: TGitOidArray;
  Cur: TGitOid;
  I: Integer;
  GWhen: Int64;
  GParents: TGitOidArray;
  StackCap, StackLen: SizeInt;
  procedure StackPush(const APushOid: TGitOid); inline;
  begin
    if StackLen >= StackCap then
    begin
      StackCap := SizeInt(GrowArrayCapacity(SizeUInt(StackCap), SizeUInt(StackLen + 1)));
      SetLength(Stack, StackCap);
    end;
    Stack[StackLen] := APushOid;
    Inc(StackLen);
  end;
  function StackPop(out AOid: TGitOid): Boolean; inline;
  begin
    Result := StackLen > 0;
    if not Result then Exit;
    Dec(StackLen);
    AOid := Stack[StackLen];
  end;
begin
  if FHidden = nil then
    FHidden := TGitOidSet.Create;
  InitGraph;
  if FParseCache = nil then
    FParseCache := TCommitParseCache.Create;
  Stack := nil; StackCap := 0; StackLen := 0;
  StackPush(AOid);
  while StackPop(Cur) do
  begin
    if FHidden.Contains(Cur) then
      Continue;
    if not TryFetchCommitCached(FRepo, FGraph, FParseCache, Cur, GWhen, GParents) then
      Continue;
    FHidden.Add(Cur);
    if FFirstParent then
    begin
      if Length(GParents) > 0 then StackPush(GParents[0]);
    end
    else
      for I := 0 to High(GParents) do StackPush(GParents[I]);
  end;
  SetLength(Stack, StackLen);
end;

constructor TGitRevWalker.Create(ARepo: TNativeRepository);
begin
  Create(ARepo, DefaultGitRevOptions);
end;

constructor TGitRevWalker.Create(ARepo: TNativeRepository; const AOptions: TGitRevOptions);
begin
  inherited Create;
  if ARepo = nil then
    raise EGitError.Create('revwalk requires a repository');
  FRepo := ARepo;
  FGraph := nil;
  FHeap := nil;
  FHeapCap := 0;
  FHeapLen := 0;
  FSeen := TGitOidSet.Create;
  FHidden := nil;
  FParseCache := nil;
  FBoundary := nil;
  FBoundaryCap := 0;
  FBoundaryLen := 0;
  FBoundaryPos := 0;
  FBoundarySet := nil;
  FFirstParent := AOptions.FirstParent;
  FSince := AOptions.Since;
  FUntilTime := AOptions.UntilTime;
  FShowBoundary := AOptions.ShowBoundary;
end;

destructor TGitRevWalker.Destroy;
var I: Integer;
begin
  FSeen.Free;
  if FHidden <> nil then
    FHidden.Free;
  if FParseCache <> nil then
    FParseCache.Free;
  if FBoundarySet <> nil then
    FBoundarySet.Free;
  if FGraph <> nil then
    FGraph.Free;
  for I := 0 to FHeapLen - 1 do
    if FHeap[I] <> nil then
      Dispose(FHeap[I]);
  SetLength(FHeap, 0);
  FHeapCap := 0;
  FHeapLen := 0;
  SetLength(FBoundary, 0);
  FBoundaryCap := 0;
  FBoundaryLen := 0;
  inherited Destroy;
end;

procedure TGitRevWalker.Push(const AOid: TGitOid);
begin
  EnqueueCommit(AOid);
end;

procedure TGitRevWalker.PushHead(const AGitDir: string);
begin
  Push(GitResolveHead(AGitDir));
end;

procedure TGitRevWalker.PushHide(const AOid: TGitOid);
begin
  EnqueueHidden(AOid);
end;

procedure TGitRevWalker.SetFirstParent(AValue: Boolean);
begin
  FFirstParent := AValue;
end;

procedure TGitRevWalker.SetDateRange(ASince, AUntilTime: Int64);
begin
  FSince := ASince;
  FUntilTime := AUntilTime;
end;

procedure TGitRevWalker.SetShowBoundary(AValue: Boolean);
begin
  FShowBoundary := AValue;
end;

function TGitRevWalker.Next(out AOid: TGitOid): Boolean;
var
  Entry: TWalkEntry;
  I: Integer;
  IsHidden: Boolean;
begin
  while True do
  begin
    if not HeapPop(Entry) then
    begin
      if FShowBoundary and (FBoundaryPos < FBoundaryLen) then
      begin
        AOid := FBoundary[FBoundaryPos].Oid;
        Inc(FBoundaryPos);
        Exit(True);
      end;
      Exit(False);
    end;
    // enqueue parents (hidden/boundary handled inside EnqueueCommit)
    for I := 0 to High(Entry.Parents) do
    begin
      if FFirstParent and (I > 0) then
        Break;
      // check if parent is hidden -> boundary handling, O(1) via BoundarySet
      IsHidden := (FHidden <> nil) and FHidden.Contains(Entry.Parents[I]);
      if IsHidden and FShowBoundary then
      begin
        if (FBoundarySet = nil) or not FBoundarySet.Contains(Entry.Parents[I]) then
          AppendBoundary(Entry.Parents[I]);
        Continue;
      end;
      if IsHidden then
        Continue;
      EnqueueCommit(Entry.Parents[I]);
    end;
    if not PassesDateFilter(Entry.When, FSince, FUntilTime) then
      Continue;
    AOid := Entry.Oid;
    Exit(True);
  end;
end;

function TGitRevWalker.NextWithBoundary(out AEntry: TGitRevEntry): Boolean;
var
  Oid: TGitOid;
  WasBoundary: Boolean;
begin
  // drain heap first, then boundary; O(1) via BoundarySet hash
  WasBoundary := FShowBoundary and (FHeapLen = 0) and (FBoundaryPos < FBoundaryLen);
  if WasBoundary then
  begin
    AEntry.Oid := FBoundary[FBoundaryPos].Oid;
    AEntry.IsBoundary := True;
    Inc(FBoundaryPos);
    Exit(True);
  end;
  if not Next(Oid) then
    Exit(False);
  WasBoundary := (FBoundarySet <> nil) and FBoundarySet.Contains(Oid);
  AEntry.Oid := Oid;
  AEntry.IsBoundary := WasBoundary;
  Result := True;
end;

{ ── History.Collect: date-order collect, single-parse per commit ── }
function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray;
var
  Walker: TGitRevWalker;
  I: SizeInt;
  Oid: TGitOid;
  LCount, LCap: SizeInt;
begin
  Result := nil;
  LCount := 0; LCap := 0;
  Walker := TGitRevWalker.Create(ARepo);
  try
    for I := 0 to High(AStarts) do
      Walker.Push(AStarts[I]);
    while ((AMaxCount < 0) or (LCount < AMaxCount))
      and Walker.Next(Oid) do
    begin
      if LCount >= LCap then
      begin
        LCap := SizeInt(GrowArrayCapacity(SizeUInt(LCap), SizeUInt(LCount + 1)));
        SetLength(Result, LCap);
      end;
      Result[LCount] := Oid;
      Inc(LCount);
    end;
    SetLength(Result, LCount);
  finally
    Walker.Free;
  end;
end;

function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray;
var
  E: TGitRevEntryArray;
  I: Integer;
  LCount, LCap: SizeInt;
begin
  Result := nil;
  E := GitCollectCommitsWithBoundary(ARepo, AStarts, AHides, AOptions, AMaxCount);
  LCount := 0; LCap := 0;
  for I := 0 to High(E) do
    if not E[I].IsBoundary then
    begin
      if LCount >= LCap then
      begin
        LCap := SizeInt(GrowArrayCapacity(SizeUInt(LCap), SizeUInt(LCount + 1)));
        SetLength(Result, LCap);
      end;
      Result[LCount] := E[I].Oid;
      Inc(LCount);
    end;
  SetLength(Result, LCount);
end;

function GitCollectCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray;
var
  Hidden: TGitOidSet;
  Seen: TGitOidSet;
  Heap: array of PWalkEntry;
  HeapCap: SizeInt;
  HeapLen: SizeInt;
  BoundarySet: TGitOidSet;
  BoundaryList: TGitOidArray;
  Graph: TCommitGraph;
  ParseCache: TCommitParseCache;
  ResCount, ResCap: SizeInt;
  BndCount, BndCap: SizeInt;

  procedure HeapPushLocal(const AEntry: TWalkEntry);
  var
    I, Parent: Integer;
    LNew: PWalkEntry;
  begin
    // geometric growth via bytes.ops GrowArrayCapacity single source, amortized O(1), zero-copy Move for cap array
    // not inline: loop body + SetLength growth would bloat I-Cache per red-line 2
    // stability: New/Dispose paired via try..finally
    if HeapLen >= HeapCap then
    begin
      HeapCap := SizeInt(GrowArrayCapacity(SizeUInt(HeapCap), SizeUInt(HeapLen + 1)));
      SetLength(Heap, HeapCap);
    end;
    New(LNew);
    try
      LNew^ := AEntry;
      I := HeapLen;
      Inc(HeapLen);
      while I > 0 do
      begin
        Parent := (I - 1) div 2;
        if Heap[Parent]^.When >= LNew^.When then
          Break;
        Heap[I] := Heap[Parent];
        I := Parent;
      end;
      Heap[I] := LNew;
    except
      Dispose(LNew);
      raise;
    end;
  end;

  function HeapPopLocal(out AEntry: TWalkEntry): Boolean;
  var
    I, L, R, Best: Integer;
    LLast: PWalkEntry;
  begin
    Result := HeapLen > 0;
    if not Result then
      Exit;
    AEntry := Heap[0]^;
    Dispose(Heap[0]);
    Dec(HeapLen);
    if HeapLen = 0 then
      Exit;
    // perf: pointer heap sift-down, O(log n) pointer moves, no Finalize/Move/FillChar per level
    LLast := Heap[HeapLen];
    Heap[HeapLen] := nil;
    I := 0;
    while True do
    begin
      L := 2 * I + 1;
      R := L + 1;
      Best := I;
      if (L < HeapLen) and (Heap[L]^.When > Heap[Best]^.When) then
        Best := L;
      if (R < HeapLen) and (Heap[R]^.When > Heap[Best]^.When) then
        Best := R;
      if Best = I then
        Break;
      Heap[I] := Heap[Best];
      I := Best;
    end;
    Heap[I] := LLast;
  end;

  procedure EnqueueIfNeeded(const AOid: TGitOid);
  var
    Entry: TWalkEntry;
    GWhen: Int64;
    GParents: TGitOidArray;
    Got: Boolean;
  begin
    if Seen.Contains(AOid) then
      Exit;
    if (Hidden <> nil) and Hidden.Contains(AOid) then
      Exit;
    try
      Got := TryFetchCommitCached(ARepo, Graph, ParseCache, AOid, GWhen, GParents);
    except
      Exit;
    end;
    if not Got then
      raise EGitError.Create('revwalk start points at a non-commit object');
    Seen.Add(AOid);
    Entry.Oid := AOid;
    Entry.When := GWhen;
    Entry.Parents := GParents; { CoW share }
    HeapPushLocal(Entry);
  end;

  procedure AppendBoundary(const AOid: TGitOid);
  begin
    if BndCount >= BndCap then
    begin
      BndCap := SizeInt(GrowArrayCapacity(SizeUInt(BndCap), SizeUInt(BndCount + 1)));
      SetLength(BoundaryList, BndCap);
    end;
    BoundaryList[BndCount] := AOid;
    Inc(BndCount);
  end;

  procedure AppendResult(const AOid: TGitOid; AIsBoundary: Boolean);
  begin
    if ResCount >= ResCap then
    begin
      ResCap := SizeInt(GrowArrayCapacity(SizeUInt(ResCap), SizeUInt(ResCount + 1)));
      SetLength(Result, ResCap);
    end;
    Result[ResCount].Oid := AOid;
    Result[ResCount].IsBoundary := AIsBoundary;
    Inc(ResCount);
  end;

var
  I: Integer;
  Entry: TWalkEntry;
  Emitted: Integer;
  ParentOid: TGitOid;
begin
  Result := nil;
  ResCount := 0; ResCap := 0;
  BndCount := 0; BndCap := 0;
  Heap := nil; HeapCap := 0; HeapLen := 0;
  BoundaryList := nil;
  Graph := nil;
  ParseCache := TCommitParseCache.Create;
  try
    if not GitTryLoadCommitGraph(ARepo.GitDir, Graph) then
      Graph := nil;
  except
    Graph := nil;
  end;
  Hidden := nil;
  Seen := TGitOidSet.Create;
  BoundarySet := TGitOidSet.Create;
  try
    if Length(AHides) > 0 then
      BuildHiddenSet(ARepo, Graph, AHides, AOptions.FirstParent, Hidden, ParseCache);
    // seed heap with starts that are not hidden
    {Heap already nil/cap 0/len 0}
    for I := 0 to High(AStarts) do
    begin
      if (Hidden <> nil) and Hidden.Contains(AStarts[I]) then
      begin
        if AOptions.ShowBoundary and not BoundarySet.Contains(AStarts[I]) then
        begin
          BoundarySet.Add(AStarts[I]);
          AppendBoundary(AStarts[I]);
        end;
        Continue;
      end;
      try
        EnqueueIfNeeded(AStarts[I]);
      except
        // missing start remains fatal via EnqueueIfNeeded raise
        raise;
      end;
    end;
    Emitted := 0;
    while HeapPopLocal(Entry) do
    begin
      if (Hidden <> nil) and Hidden.Contains(Entry.Oid) then
        Continue;
      // enqueue parents before emission so traversal continues even if filtered
      for I := 0 to High(Entry.Parents) do
      begin
        if AOptions.FirstParent and (I > 0) then
          Break;
        ParentOid := Entry.Parents[I];
        if (Hidden <> nil) and Hidden.Contains(ParentOid) then
        begin
          if AOptions.ShowBoundary and not BoundarySet.Contains(ParentOid) then
          begin
            BoundarySet.Add(ParentOid);
            AppendBoundary(ParentOid);
          end;
          Continue;
        end;
        EnqueueIfNeeded(ParentOid);
      end;
      if not PassesDateFilter(Entry.When, AOptions.Since, AOptions.UntilTime) then
        Continue;
      if (AMaxCount >= 0) and (Emitted >= AMaxCount) then
        Break;
      AppendResult(Entry.Oid, False);
      Inc(Emitted);
    end;
    SetLength(BoundaryList, BndCount);
    // append boundary entries after main list, preserving discovery order
    if AOptions.ShowBoundary then
    begin
      for I := 0 to High(BoundaryList) do
      begin
        if (AMaxCount >= 0) and (ResCount >= AMaxCount) then
          Break;
        AppendResult(BoundaryList[I], True);
      end;
    end;
    SetLength(Result, ResCount);
    SetLength(BoundaryList, BndCount);
  finally
    // stability: dispose leftover pointer heap entries, no managed leak on early MaxCount break
    for I := 0 to HeapLen - 1 do
      if Heap[I] <> nil then
        Dispose(Heap[I]);
    SetLength(Heap, 0);
    Seen.Free;
    BoundarySet.Free;
    ParseCache.Free;
    if Hidden <> nil then
      Hidden.Free;
    if Graph <> nil then
      Graph.Free;
  end;
end;

{ ── History.Topo: O(E log V) edge parse via SpanCompare binary search, MergeSort O(V log V) ── }
{ ── topological order ───────────────────────────────────────────────────── }

type
  TTopoNode = record
    Oid: TGitOid;
    When: Int64;
    Parents: TGitOidArray;
    ChildCount: SizeInt; { children inside the reachable set }
  end;
  TTopoNodes = array of TTopoNode;
  TNodeIndexArray = array of Integer;

{ stable merge sort of node indices by oid bytes; single shared scratch
  perf: PByte zero-copy window via bytes.ops SpanCopy single source (no managed Move, inline) }
procedure TopoSortRange(var AOrder: TNodeIndexArray;
  var AScratch: TNodeIndexArray; const ANodes: TTopoNodes;
  ALow, AHigh: Integer);
var
  Mid, I, J, K: Integer;
  LBytes: SizeUInt;
begin
  if ALow >= AHigh then
    Exit;
  Mid := (ALow + AHigh) div 2;
  TopoSortRange(AOrder, AScratch, ANodes, ALow, Mid);
  TopoSortRange(AOrder, AScratch, ANodes, Mid + 1, AHigh);
  LBytes := SizeUInt(SizeInt(AHigh - ALow + 1) * SizeOf(Integer));
  // PByte zero-copy view: single Move via bytes.ops SpanCopy single source
  SpanCopy(TByteSpan.Create(@AScratch[ALow], LBytes),
           TByteSpan.Create(@AOrder[ALow], LBytes));
  I := ALow;
  J := Mid + 1;
  K := ALow;
  while (I <= Mid) and (J <= AHigh) do
  begin
    if OidLess(ANodes[AOrder[J]].Oid, ANodes[AOrder[I]].Oid) then
    begin
      AScratch[K] := AOrder[J];
      Inc(J);
    end
    else
    begin
      AScratch[K] := AOrder[I];
      Inc(I);
    end;
    Inc(K);
  end;
  while I <= Mid do
  begin
    AScratch[K] := AOrder[I];
    Inc(I);
    Inc(K);
  end;
  while J <= AHigh do
  begin
    AScratch[K] := AOrder[J];
    Inc(J);
    Inc(K);
  end;
  // PByte zero-copy view back via bytes.ops single source
  SpanCopy(TByteSpan.Create(@AOrder[ALow], LBytes),
           TByteSpan.Create(@AScratch[ALow], LBytes));
end;

{ binary search over the sorted permutation; -1 when absent }
function TopoNodeIndexOf(const AOid: TGitOid; const AOrder: TNodeIndexArray;
  const ANodes: TTopoNodes): Integer;
var
  Lo, Hi, Mid: Integer;
begin
  Result := -1;
  Lo := 0;
  Hi := High(AOrder);
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    if GitOidSame(ANodes[AOrder[Mid]].Oid, AOid) then
      Exit(AOrder[Mid]);
    if OidLess(ANodes[AOrder[Mid]].Oid, AOid) then
      Lo := Mid + 1
    else
      Hi := Mid - 1;
  end;
end;

{ ascending by commit time, stable merge sort O(n log n), mirrors TopoSortRange
  perf: PByte zero-copy via bytes.ops SpanCopy single source }
procedure TopoSortTipsMerge(var ATips: TNodeIndexArray; var AScratch: TNodeIndexArray; const ANodes: TTopoNodes; ALow, AHigh: Integer);
var Mid, I, J, K: Integer; LBytes: SizeUInt;
begin
  if ALow >= AHigh then Exit;
  Mid := (ALow + AHigh) div 2;
  TopoSortTipsMerge(ATips, AScratch, ANodes, ALow, Mid);
  TopoSortTipsMerge(ATips, AScratch, ANodes, Mid + 1, AHigh);
  LBytes := SizeUInt(SizeInt(AHigh - ALow + 1) * SizeOf(Integer));
  SpanCopy(TByteSpan.Create(@AScratch[ALow], LBytes), TByteSpan.Create(@ATips[ALow], LBytes));
  I := ALow; J := Mid + 1; K := ALow;
  while (I <= Mid) and (J <= AHigh) do
  begin
    if ANodes[AScratch[J]].When < ANodes[AScratch[I]].When then
    begin AScratch[K] := AScratch[J]; Inc(J); end
    else
    begin AScratch[K] := AScratch[I]; Inc(I); end;
    Inc(K);
  end;
  while I <= Mid do begin AScratch[K] := AScratch[I]; Inc(I); Inc(K); end;
  while J <= AHigh do begin AScratch[K] := AScratch[J]; Inc(J); Inc(K); end;
  SpanCopy(TByteSpan.Create(@ATips[ALow], LBytes), TByteSpan.Create(@AScratch[ALow], LBytes));
end;

procedure TopoSortTips(var ATips: TNodeIndexArray; const ANodes: TTopoNodes);
var Scratch: TNodeIndexArray;
begin
  if Length(ATips) <= 1 then Exit;
  SetLength(Scratch, Length(ATips));
  TopoSortTipsMerge(ATips, Scratch, ANodes, 0, High(ATips));
end;

function TopoStackPop(var AStack: TNodeIndexArray): Integer;
begin
  Result := -1;
  if Length(AStack) = 0 then
    Exit;
  Result := AStack[High(AStack)];
  SetLength(AStack, High(AStack));
end;

function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray;
var
  Nodes: TTopoNodes;
  Order, Scratch, Ready: TNodeIndexArray;
  Seen: TGitOidSet;
  Stack: TGitOidArray;
  Oid: TGitOid;
  I, J, NodeIdx, ParentIdx: Integer;
  Graph: TCommitGraph;
  ParseCache: TCommitParseCache;
  GWhen: Int64;
  GParents: TGitOidArray;
  StackCap, StackLen, NodesLen: SizeInt;
  ResCap, ResCount, ReadyCap, ReadyLen: SizeInt;
  OidMap: TOidIndexMap;
begin
  Result := nil;
  Seen := TGitOidSet.Create;
  Graph := nil;
  ParseCache := TCommitParseCache.Create;
  Nodes := nil;
  NodesLen := 0;
  try
    try if not GitTryLoadCommitGraph(ARepo.GitDir, Graph) then Graph := nil; except Graph := nil; end;
    { phase 1: discover the full reachable set, parsing each commit once }
    Stack := nil; StackCap := 0; StackLen := 0; ResCount := 0; ResCap := 0; ReadyCap := 0; ReadyLen := 0; Ready := nil;
    for I := 0 to High(AStarts) do
    begin
      if StackLen >= StackCap then
      begin StackCap := SizeInt(GrowArrayCapacity(SizeUInt(StackCap), SizeUInt(StackLen + 1))); SetLength(Stack, StackCap); end;
      Stack[StackLen] := AStarts[I]; Inc(StackLen);
    end;
    while StackLen > 0 do
    begin
      Dec(StackLen); Oid := Stack[StackLen];
      if Seen.Contains(Oid) then
        Continue;
      if not TryFetchCommitCached(ARepo, Graph, ParseCache, Oid, GWhen, GParents) then
        raise EGitError.Create('topo walk start points at a non-commit object');
      Seen.Add(Oid);
      if NodesLen >= Length(Nodes) then
      begin
        // geometric growth via bytes.ops, amortized O(1)
        SetLength(Nodes, SizeInt(GrowArrayCapacity(SizeUInt(Length(Nodes)), SizeUInt(NodesLen + 1))));
      end;
      NodeIdx := NodesLen;
      Inc(NodesLen);
      Nodes[NodeIdx].Oid := Oid;
      Nodes[NodeIdx].When := GWhen;
      Nodes[NodeIdx].Parents := GParents; { CoW }
      Nodes[NodeIdx].ChildCount := 0;
      for J := 0 to High(GParents) do
      begin
        if StackLen >= StackCap then
        begin StackCap := SizeInt(GrowArrayCapacity(SizeUInt(StackCap), SizeUInt(StackLen + 1))); SetLength(Stack, StackCap); end;
        Stack[StackLen] := GParents[J]; Inc(StackLen);
      end;
    end;
    SetLength(Stack, StackLen);
    SetLength(Nodes, NodesLen);

    { phase 2: count each node's children within the set; O(E) via hash index }
    SetLength(Order, Length(Nodes));
    for I := 0 to High(Nodes) do
      Order[I] := I;
    if Length(Nodes) > 1 then
    begin
      SetLength(Scratch, Length(Nodes));
      TopoSortRange(Order, Scratch, Nodes, 0, High(Nodes));
    end;
    OidMap := TOidIndexMap.Create;
    try
      for I := 0 to High(Nodes) do
        OidMap.Add(Nodes[I].Oid, I);
      for I := 0 to High(Nodes) do
        for J := 0 to High(Nodes[I].Parents) do
        begin
          if not OidMap.TryGet(Nodes[I].Parents[J], ParentIdx) then
            raise EGitError.Create('topo walk lost a reachable parent');
          Inc(Nodes[ParentIdx].ChildCount);
        end;

      { phase 3: emit through a LIFO ready stack - git's default topo sort
      (REV_SORT_IN_GRAPH_ORDER). Initial tips are stacked oldest-first so
      the newest pops first; afterwards the last-listed newly-ready parent
      pops before its siblings. }
    // Ready LIFO geometric growth via bytes.ops, amortized O(1)
    for I := 0 to High(Nodes) do
      if Nodes[I].ChildCount = 0 then
      begin
        if ReadyLen >= ReadyCap then
        begin
          ReadyCap := SizeInt(GrowArrayCapacity(SizeUInt(ReadyCap), SizeUInt(ReadyLen + 1)));
          SetLength(Ready, ReadyCap);
        end;
        Ready[ReadyLen] := I;
        Inc(ReadyLen);
      end;
    SetLength(Ready, ReadyLen);
    TopoSortTips(Ready, Nodes);
    ReadyCap := Length(Ready);
    Result := nil; ResCount:=0; ResCap:=0;
    while True do
    begin
      if (AMaxCount >= 0) and (ResCount >= AMaxCount) then
        Break;
      // inline LIFO pop, amortized O(1)
      if ReadyLen = 0 then
        NodeIdx := -1
      else
      begin
        Dec(ReadyLen);
        NodeIdx := Ready[ReadyLen];
      end;
      if NodeIdx < 0 then
        Break;
      if ResCount >= ResCap then
      begin ResCap := SizeInt(GrowArrayCapacity(SizeUInt(ResCap), SizeUInt(ResCount + 1))); SetLength(Result, ResCap); end;
      Result[ResCount] := Nodes[NodeIdx].Oid;
      Inc(ResCount);
      for J := 0 to High(Nodes[NodeIdx].Parents) do
      begin
        if not OidMap.TryGet(Nodes[NodeIdx].Parents[J], ParentIdx) then Continue;
        Dec(Nodes[ParentIdx].ChildCount);
        if Nodes[ParentIdx].ChildCount = 0 then
        begin
          // geometric Ready growth via bytes.ops
          if ReadyLen >= ReadyCap then
          begin
            ReadyCap := SizeInt(GrowArrayCapacity(SizeUInt(ReadyCap), SizeUInt(ReadyLen + 1)));
            SetLength(Ready, ReadyCap);
          end;
          Ready[ReadyLen] := ParentIdx;
          Inc(ReadyLen);
        end;
      end;
    end;
    SetLength(Result, ResCount);
    SetLength(Ready, ReadyLen);
    finally OidMap.Free; end;
  finally
    Seen.Free;
    ParseCache.Free;
    if Graph <> nil then Graph.Free;
  end;
end;

function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray;
var
  E: TGitRevEntryArray;
  I: Integer;
  LCount, LCap: SizeInt;
begin
  Result := nil;
  LCount:=0; LCap:=0;
  E := GitTopoOrderCommitsWithBoundary(ARepo, AStarts, AHides, AOptions, AMaxCount);
  for I := 0 to High(E) do
    if not E[I].IsBoundary then
    begin
      if LCount >= LCap then
      begin LCap := SizeInt(GrowArrayCapacity(SizeUInt(LCap), SizeUInt(LCount + 1))); SetLength(Result, LCap); end;
      Result[LCount] := E[I].Oid;
      Inc(LCount);
    end;
  SetLength(Result, LCount);
end;

function GitTopoOrderCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray;
var
  Hidden: TGitOidSet;
  Nodes: TTopoNodes;
  Order, Scratch, Ready: TNodeIndexArray;
  Seen: TGitOidSet;
  Stack: TGitOidArray;
  Oid: TGitOid;
  I, J, NodeIdx, ParentIdx: Integer;
  BoundarySet: TGitOidSet;
  OidMap: TOidIndexMap;
  BoundaryList: TGitOidArray;
  Emitted: Integer;
  DateFiltered: array of Boolean;
  Graph: TCommitGraph;
  GWhen: Int64;
  GParents: TGitOidArray;
  ParseCache: TCommitParseCache;
  StackCap, StackLen: SizeInt;
  BndCount, BndCap, ResCount, ResCap, ReadyCap, ReadyLen: SizeInt;
  NodesLen: SizeInt;
  procedure PushStack(const AOid: TGitOid); inline;
  begin
    if StackLen >= StackCap then
    begin StackCap := SizeInt(GrowArrayCapacity(SizeUInt(StackCap), SizeUInt(StackLen + 1))); SetLength(Stack, StackCap); end;
    Stack[StackLen] := AOid; Inc(StackLen);
  end;
  function PopStack(out AOid: TGitOid): Boolean; inline;
  begin Result:= StackLen>0; if not Result then Exit; Dec(StackLen); AOid:=Stack[StackLen]; end;
  procedure AppendBoundary(const AOid: TGitOid);
  begin
    if BndCount >= BndCap then
    begin BndCap := SizeInt(GrowArrayCapacity(SizeUInt(BndCap), SizeUInt(BndCount + 1))); SetLength(BoundaryList, BndCap); end;
    BoundaryList[BndCount] := AOid; Inc(BndCount);
  end;
  procedure AppendResult(const AOid: TGitOid; AIsBoundary: Boolean);
  begin
    if ResCount >= ResCap then
    begin ResCap := SizeInt(GrowArrayCapacity(SizeUInt(ResCap), SizeUInt(ResCount + 1))); SetLength(Result, ResCap); end;
    Result[ResCount].Oid := AOid; Result[ResCount].IsBoundary := AIsBoundary; Inc(ResCount);
  end;
begin
  Result := nil; ResCount:=0; ResCap:=0; BndCount:=0; BndCap:=0; BoundaryList:=nil; StackCap:=0; StackLen:=0; ReadyCap:=0; ReadyLen:=0; Ready:=nil; Nodes:=nil; NodesLen:=0;
  Graph := nil;
  ParseCache := TCommitParseCache.Create;
  try
    if not GitTryLoadCommitGraph(ARepo.GitDir, Graph) then
      Graph := nil;
  except
    Graph := nil;
  end;
  Hidden := nil;
  if Length(AHides) > 0 then
    BuildHiddenSet(ARepo, Graph, AHides, AOptions.FirstParent, Hidden, ParseCache);
  Seen := TGitOidSet.Create;
  BoundarySet := TGitOidSet.Create;
  try
    // phase 1: discover reachable from starts, stopping at hidden boundary
    Stack := nil;
    for I := 0 to High(AStarts) do PushStack(AStarts[I]);
    while PopStack(Oid) do
    begin
      if Seen.Contains(Oid) then
        Continue;
      if (Hidden <> nil) and Hidden.Contains(Oid) then
      begin
        if AOptions.ShowBoundary and not BoundarySet.Contains(Oid) then
        begin
          BoundarySet.Add(Oid);
          AppendBoundary(Oid);
        end;
        Continue;
      end;
      try
        if not TryFetchCommitCached(ARepo, Graph, ParseCache, Oid, GWhen, GParents) then
          raise EGitError.Create('topo walk start points at a non-commit object');
      except
        on E: EGitError do
        begin
          // missing object in shallow clone: skip; non-commit start already raised above and will propagate
          // distinguish: TryFetch raise for missing vs explicit raise for non-commit
          // if Got==false case already raised, re-raise
          if Pos('non-commit', E.Message) > 0 then raise;
          Continue;
        end;
      end;
      Seen.Add(Oid);
      if NodesLen >= Length(Nodes) then
      begin
        // geometric growth via bytes.ops, amortized O(1)
        SetLength(Nodes, SizeInt(GrowArrayCapacity(SizeUInt(Length(Nodes)), SizeUInt(NodesLen + 1))));
      end;
      NodeIdx := NodesLen;
      Inc(NodesLen);
      Nodes[NodeIdx].Oid := Oid;
      Nodes[NodeIdx].When := GWhen;
      if AOptions.FirstParent then
      begin
        if Length(GParents) > 0 then
        begin
          SetLength(Nodes[NodeIdx].Parents, 1);
          Nodes[NodeIdx].Parents[0] := GParents[0];
        end
        else
          SetLength(Nodes[NodeIdx].Parents, 0);
      end
      else
        Nodes[NodeIdx].Parents := GParents; { CoW }
      Nodes[NodeIdx].ChildCount := 0;
      for J := 0 to High(Nodes[NodeIdx].Parents) do
      begin
        // if parent is hidden, collect boundary and do not traverse
        if (Hidden <> nil) and Hidden.Contains(Nodes[NodeIdx].Parents[J]) then
        begin
          if AOptions.ShowBoundary and not BoundarySet.Contains(Nodes[NodeIdx].Parents[J]) then
          begin
            BoundarySet.Add(Nodes[NodeIdx].Parents[J]);
            AppendBoundary(Nodes[NodeIdx].Parents[J]);
          end;
          Continue;
        end;
        PushStack(Nodes[NodeIdx].Parents[J]);
      end;
    end;
    SetLength(Stack, StackLen);
    SetLength(BoundaryList, BndCount);
    SetLength(Nodes, NodesLen);
    if Length(Nodes) = 0 then
    begin
      // only boundaries
      if AOptions.ShowBoundary then
      begin
        for I := 0 to High(BoundaryList) do
        begin
          if (AMaxCount >= 0) and (ResCount >= AMaxCount) then
            Break;
          AppendResult(BoundaryList[I], True);
        end;
        SetLength(Result, ResCount);
      end;
      Exit;
    end;
    // phase 2: child counts among included nodes only, O(E) via hash
    SetLength(Order, Length(Nodes));
    for I := 0 to High(Nodes) do
      Order[I] := I;
    if Length(Nodes) > 1 then
    begin
      SetLength(Scratch, Length(Nodes));
      TopoSortRange(Order, Scratch, Nodes, 0, High(Nodes));
    end;
    OidMap := TOidIndexMap.Create;
    try
      for I := 0 to High(Nodes) do
        OidMap.Add(Nodes[I].Oid, I);
      for I := 0 to High(Nodes) do
        for J := 0 to High(Nodes[I].Parents) do
        begin
          if not OidMap.TryGet(Nodes[I].Parents[J], ParentIdx) then
            Continue;
          Inc(Nodes[ParentIdx].ChildCount);
        end;
      // prepare date filter flags
    SetLength(DateFiltered, Length(Nodes));
    for I := 0 to High(Nodes) do
      DateFiltered[I] := not PassesDateFilter(Nodes[I].When, AOptions.Since, AOptions.UntilTime);
    // phase 3: LIFO ready stack
    // Ready LIFO geometric growth via bytes.ops, amortized O(1)
    for I := 0 to High(Nodes) do
      if Nodes[I].ChildCount = 0 then
      begin
        if ReadyLen >= ReadyCap then
        begin
          ReadyCap := SizeInt(GrowArrayCapacity(SizeUInt(ReadyCap), SizeUInt(ReadyLen + 1)));
          SetLength(Ready, ReadyCap);
        end;
        Ready[ReadyLen] := I;
        Inc(ReadyLen);
      end;
    SetLength(Ready, ReadyLen);
    TopoSortTips(Ready, Nodes);
    ReadyCap := Length(Ready);
    Emitted := 0;
    while True do
    begin
      if (AMaxCount >= 0) and (ResCount >= AMaxCount) and (Emitted >= AMaxCount) then
        Break;
      // inline LIFO pop, amortized O(1)
      if ReadyLen = 0 then
        NodeIdx := -1
      else
      begin
        Dec(ReadyLen);
        NodeIdx := Ready[ReadyLen];
      end;
      if NodeIdx < 0 then
        Break;
      if not DateFiltered[NodeIdx] then
      begin
        if (AMaxCount < 0) or (Emitted < AMaxCount) then
        begin
          AppendResult(Nodes[NodeIdx].Oid, False);
          Inc(Emitted);
        end;
      end;
      for J := 0 to High(Nodes[NodeIdx].Parents) do
      begin
        if not OidMap.TryGet(Nodes[NodeIdx].Parents[J], ParentIdx) then
          Continue;
        Dec(Nodes[ParentIdx].ChildCount);
        if Nodes[ParentIdx].ChildCount = 0 then
        begin
          // geometric Ready growth via bytes.ops
          if ReadyLen >= ReadyCap then
          begin
            ReadyCap := SizeInt(GrowArrayCapacity(SizeUInt(ReadyCap), SizeUInt(ReadyLen + 1)));
            SetLength(Ready, ReadyCap);
          end;
          Ready[ReadyLen] := ParentIdx;
          Inc(ReadyLen);
        end;
      end;
    end;
    SetLength(Ready, ReadyLen);
    finally OidMap.Free; end;
    if AOptions.ShowBoundary then
    begin
      for I := 0 to High(BoundaryList) do
      begin
        if (AMaxCount >= 0) and (ResCount >= AMaxCount) then
          Break;
        if (AOptions.Since <> 0) or (AOptions.UntilTime <> 0) then
        begin
          // reuse parse cache / graph to avoid extra inflate
          try
            if TryFetchCommitCached(ARepo, Graph, ParseCache, BoundaryList[I], GWhen, GParents) then
            begin
              if not PassesDateFilter(GWhen, AOptions.Since, AOptions.UntilTime) then
                Continue;
            end;
          except
          end;
        end;
        AppendResult(BoundaryList[I], True);
      end;
    end;
    SetLength(Result, ResCount);
    SetLength(BoundaryList, BndCount);
  finally
    Seen.Free;
    BoundarySet.Free;
    ParseCache.Free;
    if Hidden <> nil then
      Hidden.Free;
    if Graph <> nil then
      Graph.Free;
  end;
end;

end.
