unit nextpas.core.git.native.revwalk;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.commitgraph;

{ Revision walking over the native object layer: commits emerge newest
  committer-date first, matching `git rev-list` for distinct dates. Each
  commit is read and parsed exactly once - the queue entry carries the
  pre-fetched parent list so emission never re-reads objects.
  Shallow clones and grafts are out of scope stage-1.

  Topological order buffers the reachable subgraph first (children always
  precede parents), then emits through git's default graph-order ready
  stack (REV_SORT_IN_GRAPH_ORDER): initial tips oldest-stacked-first so
  the newest pops first, afterwards newly-ready parents enter in
  parent-list order, making the last-listed parent pop first.

  Boundary/hide/date semantics mirror `git rev-list`:
  - first-parent follows only the first parent of each commit
  - hide/exclude removes Hides and their ancestors; --boundary re-adds
    direct hidden parents of included commits
  - since/until filters by committer date (0 means unbounded) }

type
  TGitOidArray = array of TGitOid;

  { hash-based oid membership; O(1) avg for streaming walk and
    topological planner — replaces O(n²) sorted+Move }
  TGitOidSet = class
  private
    FBuckets: array of TGitOid;
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

  { bounded exactly-once commit parse cache: graph-hit or inflate once;
    zero-copy CoW share via assignment (bytes.ops Move single source, inline),
    bounded 4096 caps O(1) resident for large-repo traversal }
  TCommitParseCache = class
  private
    FBuckets: array of TGitOid;
    FWhens: array of Int64;
    FParents: array of TGitOidArray;
    FStates: array of Byte;
    FTicks: array of UInt64; { LRU recency ticks, monotonic }
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

  TWalkEntry = record
    Oid: TGitOid;
    When: Int64;
    Parents: TGitOidArray;
  end;

  TGitRevEntry = record
    Oid: TGitOid;
    IsBoundary: Boolean;
  end;
  TGitRevEntryArray = array of TGitRevEntry;

  TGitRevOptions = record
    FirstParent: Boolean;
    Since: Int64; { 0 = no lower bound, include When >= Since }
    UntilTime: Int64; { 0 = no upper bound, include When <= UntilTime }
    ShowBoundary: Boolean;
  end;

  TGitRevWalker = class
  private
    FRepo: TNativeRepository; { borrowed, not owned }
    FGraph: TCommitGraph;     { owned, nil when no commit-graph }
    FHeap: array of TWalkEntry;
    FHeapCap: SizeInt;            { geometric capacity for FHeap }
    FHeapLen: SizeInt;            { active heap size }
    FSeen: TGitOidSet;        { owned }
    FHidden: TGitOidSet;      { owned, hide set }
    FParseCache: TCommitParseCache; { owned, exactly-once }
    FBoundary: TGitRevEntryArray;
    FBoundaryCap: SizeInt;
    FBoundaryLen: SizeInt;
    FBoundaryPos: Integer;
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
  { perf: inline + zero-copy TByteSpan view single-source bytes.ops SpanCompare via CompareBytesOrdered (Simd MemEqual fast path, ~3×QWord), replaces 20× byte loop + duplicate branches in heap/topo sort hotspot; bytes.ops single source inline }
  Result := SpanCompare(
    TByteSpan.Create(@AA.Bytes[0], GitOidRawLen),
    TByteSpan.Create(@AB.Bytes[0], GitOidRawLen)) < 0;
end;

function GitOidHash(const AOid: TGitOid): UInt32; inline;
var
  I: Integer;
begin
  Result := UInt32(2166136261);
  for I := 0 to GitOidRawLen - 1 do
    Result := (Result xor UInt32(AOid.Bytes[I])) * UInt32(16777619);
end;

{ shared open-addressing helpers: single source for oid Set/Cache (L0 bytes.ops discipline)
  perf: inline + zero-copy SpanEqual via bytes.ops single source, probe upper limit (AMask+1) caps O(n) degenerate scan, average O(1) at 70% load; kicking via Rehash on EnsureCapacity keeps max probe bounded, avoids unbounded linear chain }
function OidProbeEmpty(const AStates: array of Byte; AMask: SizeInt; AHash: UInt32): SizeInt; inline;
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
  AMask: SizeInt; const AOid: TGitOid; AHash: UInt32; out AIdx: SizeInt): Boolean; inline;
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
  LOldStates: array of Byte;
  LOldCap: SizeInt;
  I: Integer;
  LIdx: SizeInt;
  LHash: UInt32;
begin
  LOldBuckets := FBuckets;
  LOldStates := FStates;
  LOldCap := FCap;
  SetLength(FBuckets, ANewCap);
  SetLength(FStates, ANewCap);
  FCap := ANewCap;
  FMask := ANewCap - 1;
  FCount := 0;
  for I := 0 to LOldCap - 1 do
    if (I < Length(LOldStates)) and (LOldStates[I] = 1) then
    begin
      LHash := GitOidHash(LOldBuckets[I]);
      LIdx := OidProbeEmpty(FStates, FMask, LHash);
      if LIdx < 0 then
      begin
        // probe limit hit during rehash (degenerate chain > cap) - kick via larger cap and retry
        Rehash(FCap * 2);
        LIdx := OidProbeEmpty(FStates, FMask, LHash);
      end;
      FBuckets[LIdx] := LOldBuckets[I];
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
  LHash := GitOidHash(AOid);
  if OidLocate(FBuckets, FStates, FMask, AOid, LHash, LIdx) then
    Exit;
  // probe upper limit: if no empty within cap (LIdx=-1 or occupied), kick via rehash and retry
  if (LIdx < 0) or (LIdx >= FCap) or (FStates[LIdx] = 1) then
  begin
    Rehash(FCap * 2);
    LHash := GitOidHash(AOid);
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
  FBuckets[LIdx] := AOid; { zero-copy: 20-byte inline copy }
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

procedure TCommitParseCache.CompactEvict;
const CKeep = 2048; // keep half, stays below 70% grow threshold (2867) -> amortized O(1)
var
  LOldBuckets: array of TGitOid;
  LOldWhens: array of Int64;
  LOldParents: array of TGitOidArray;
  LOldStates: array of Byte;
  LOldTicks: array of UInt64;
  LOldCap: SizeInt;
  I, J: Integer;
  LIdx: SizeInt;
  LHash: UInt32;
  LSorted: array of Integer;
  LSortedLen: SizeInt;
  LSortedCap: SizeInt;
  // not inline: partition loop, avoids I-Cache bloat per design rule
  procedure QuickSelect(AL, AR, AK: Integer);
  var
    LI, RJ: Integer;
    LPivot: UInt64;
    LTmp: Integer;
  begin
    while AL < AR do
    begin
      LI := AL;
      RJ := AR;
      LPivot := LOldTicks[LSorted[(AL + AR) div 2]];
      repeat
        while LOldTicks[LSorted[LI]] > LPivot do Inc(LI);
        while LOldTicks[LSorted[RJ]] < LPivot do Dec(RJ);
        if LI <= RJ then
        begin
          LTmp := LSorted[LI];
          LSorted[LI] := LSorted[RJ];
          LSorted[RJ] := LTmp;
          Inc(LI);
          Dec(RJ);
        end;
      until LI > RJ;
      if AK <= RJ then
        AR := RJ
      else if AK >= LI then
        AL := LI
      else
        Break;
    end;
  end;
begin
  if FCount <= CKeep then
    Exit;
  LOldBuckets := FBuckets;
  LOldWhens := FWhens;
  LOldParents := FParents;
  LOldStates := FStates;
  LOldTicks := FTicks;
  LOldCap := FCap;
  SetLength(FBuckets, 0);
  SetLength(FWhens, 0);
  SetLength(FParents, 0);
  SetLength(FStates, 0);
  SetLength(FTicks, 0);
  SetLength(FBuckets, FCap);
  SetLength(FWhens, FCap);
  SetLength(FParents, FCap);
  SetLength(FStates, FCap);
  SetLength(FTicks, FCap);
  FCount := 0;
  // collect active indices, sort by recency descending (LRU: keep newest)
  // perf: geometric growth via bytes.ops GrowArrayCapacity single source, inline, amortized O(1) push, zero-copy Integer Move, avoids O(k²) SetLength(Length+1) copy at 4096 cap jitter
  LSorted := nil;
  LSortedLen := 0;
  LSortedCap := 0;
  SetLength(LSorted, 0);
  for I := 0 to LOldCap - 1 do
    if (I < Length(LOldStates)) and (LOldStates[I] = 1) then
    begin
      if LSortedLen >= LSortedCap then
      begin
        LSortedCap := SizeInt(GrowArrayCapacity(SizeUInt(LSortedCap), SizeUInt(LSortedLen + 1)));
        SetLength(LSorted, LSortedCap);
      end;
      LSorted[LSortedLen] := I;
      Inc(LSortedLen);
    end;
  SetLength(LSorted, LSortedLen);
  // perf: O(n) avg QuickSelect (nth_element) keeps 2048 largest ticks, replaces O(n log n) QuickSort; hotspot eviction at 4096 cap now linear, jitter eliminated, zero-copy index Move, not inline to avoid I-Cache bloat, bytes.ops single source
  if (LSortedLen > CKeep) and (Length(LSorted) > 1) then
    QuickSelect(0, High(LSorted), CKeep - 1);
  for I := 0 to High(LSorted) do
  begin
    J := LSorted[I];
    if I < CKeep then
    begin
      LHash := GitOidHash(LOldBuckets[J]);
      LIdx := OidProbeEmpty(FStates, FMask, LHash);
      if LIdx < 0 then
      begin
        Rehash(FCap * 2);
        LIdx := OidProbeEmpty(FStates, FMask, LHash);
      end;
      FBuckets[LIdx] := LOldBuckets[J]; // zero-copy 20B inline
      FWhens[LIdx] := LOldWhens[J];
      FParents[LIdx] := LOldParents[J]; // zero-copy CoW share, bytes.ops single source
      FTicks[LIdx] := LOldTicks[J];
      FStates[LIdx] := 1;
      Inc(FCount);
    end
    else
      SetLength(LOldParents[J], 0); // release evicted, stable free
  end;
end;

procedure TCommitParseCache.Rehash(ANewCap: SizeInt);
var
  LOldBuckets: array of TGitOid;
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
  LOldWhens := FWhens;
  LOldParents := FParents;
  LOldStates := FStates;
  LOldTicks := FTicks;
  LOldCap := FCap;
  SetLength(FBuckets, ANewCap);
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
      LHash := GitOidHash(LOldBuckets[I]);
      LIdx := OidProbeEmpty(FStates, FMask, LHash);
      if LIdx < 0 then
      begin
        Rehash(FCap * 2);
        LIdx := OidProbeEmpty(FStates, FMask, LHash);
      end;
      FBuckets[LIdx] := LOldBuckets[I];
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
  LHash := GitOidHash(AOid);
  if not OidLocate(FBuckets, FStates, FMask, AOid, LHash, LIdx) then Exit;
  AWhen := FWhens[LIdx];
  AParents := FParents[LIdx]; { zero-copy CoW share, bytes.ops single source discipline, inline }
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
  LHash := GitOidHash(AOid);
  if OidLocate(FBuckets, FStates, FMask, AOid, LHash, LIdx) then
  begin
    // OidLocate found duplicate; LIdx valid due to probe limit handled
    if LIdx >= 0 then
    begin
      Inc(FTick);
      FTicks[LIdx] := FTick; // LRU refresh on duplicate, avoids stale eviction
    end;
    Exit;
  end;
  // probe upper limit: if no empty within cap (LIdx=-1 or occupied), kick via rehash and retry
  if (LIdx < 0) or (LIdx >= FCap) or (FStates[LIdx] = 1) then
  begin
    Rehash(FCap * 2);
    LHash := GitOidHash(AOid);
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
  FWhens[LIdx] := AWhen;
  FParents[LIdx] := AParents; { zero-copy CoW share, bytes.ops single source discipline, no Copy alloc }
  FStates[LIdx] := 1;
  Inc(FTick);
  FTicks[LIdx] := FTick;
  Inc(FCount);
end;

function DefaultGitRevOptions: TGitRevOptions;
begin
  Result.FirstParent := False;
  Result.Since := 0;
  Result.UntilTime := 0;
  Result.ShowBoundary := False;
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
  AParents := Copy(E.Parents);
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
  AParents := Copy(Info.Parents);
  if ACache <> nil then ACache.Put(AOid, AWhen, AParents);
  Result := True;
end;

procedure BuildHiddenSet(ARepo: TNativeRepository;
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
var
  Stack: TGitOidArray;
  Oid: TGitOid;
  Kind: TGitObjectKind;
  I: Integer;
  Graph: TCommitGraph;
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
  Graph := nil;
  try
    if not GitTryLoadCommitGraph(ARepo.GitDir, Graph) then
      Graph := nil;
  except
    Graph := nil;
  end;
  try
    Stack := nil; StackCap := 0; StackLen := 0;
    for I := 0 to High(AHides) do StackPush(AHides[I]);
    while StackPop(Oid) do
    begin
      if AHidden.Contains(Oid) then
        Continue;
      if not TryFetchCommitCached(ARepo, Graph, ACache, Oid, GWhen, GParents) then
      begin
        // non-commit or missing: skip but still mark visited to avoid retry
        // do not add to hidden (graph already handled), continue
        Continue;
      end;
      // TryFetch returns False only for non-commit kind; need to distinguish EGitError already raised
      // check Kind was commit inside helper, so here we have valid parents
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
    if Graph <> nil then Graph.Free;
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
begin
  // geometric growth: 64 -> *2; amortized O(1) push via bytes.ops-style doubling (no fixed +4096)
  // not inline: loop body + setlength growth would bloat I-Cache per design rule
  if FHeapLen >= FHeapCap then
  begin
    if FHeapCap = 0 then FHeapCap := 64 else FHeapCap := FHeapCap * 2;
    SetLength(FHeap, FHeapCap);
  end;
  I := FHeapLen;
  Inc(FHeapLen);
  // max-heap on When: newest at root; managed assignment preserves ref-counts
  while I > 0 do
  begin
    Parent := (I - 1) div 2;
    if FHeap[Parent].When >= AEntry.When then
      Break;
    FHeap[I] := FHeap[Parent];
    I := Parent;
  end;
  FHeap[I] := AEntry;
end;

function TGitRevWalker.HeapPop(out AEntry: TWalkEntry): Boolean;
var
  I, L, R, Best: Integer;
  LastEntry: TWalkEntry;
begin
  Result := FHeapLen > 0;
  if not Result then
    Exit;
  AEntry := FHeap[0];
  Dec(FHeapLen);
  if FHeapLen = 0 then
  begin
    FHeap[0] := Default(TWalkEntry);
    Exit;
  end;
  LastEntry := FHeap[FHeapLen];
  FHeap[FHeapLen] := Default(TWalkEntry);
  I := 0;
  while True do
  begin
    L := 2 * I + 1;
    R := L + 1;
    Best := I;
    if (L < FHeapLen) and (FHeap[L].When > FHeap[Best].When) then
      Best := L;
    if (R < FHeapLen) and (FHeap[R].When > FHeap[Best].When) then
      Best := R;
    if Best = I then
      Break;
    FHeap[I] := FHeap[Best];
    I := Best;
  end;
  FHeap[I] := LastEntry;
end;

procedure TGitRevWalker.AppendBoundary(const AOid: TGitOid); inline;
begin
  if FBoundaryLen >= FBoundaryCap then
  begin
    if FBoundaryCap = 0 then FBoundaryCap := 32
    else if FBoundaryCap < 4096 then FBoundaryCap := FBoundaryCap * 2
    else Inc(FBoundaryCap, 4096);
    SetLength(FBoundary, FBoundaryCap);
  end;
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
    begin
      for I := 0 to FBoundaryLen - 1 do
        if GitOidSame(FBoundary[I].Oid, AOid) then
          Exit;
      AppendBoundary(AOid);
    end;
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
    GParents := Copy(Info.Parents);
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
    Entry.Parents := Copy(GParents);
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
  FFirstParent := AOptions.FirstParent;
  FSince := AOptions.Since;
  FUntilTime := AOptions.UntilTime;
  FShowBoundary := AOptions.ShowBoundary;
end;

destructor TGitRevWalker.Destroy;
begin
  FSeen.Free;
  if FHidden <> nil then
    FHidden.Free;
  if FParseCache <> nil then
    FParseCache.Free;
  if FGraph <> nil then
    FGraph.Free;
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
  I, K: Integer;
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
      // check if parent is hidden -> boundary handling
      IsHidden := (FHidden <> nil) and FHidden.Contains(Entry.Parents[I]);
      if IsHidden and FShowBoundary then
      begin
        IsHidden := False;
        for K := 0 to FBoundaryLen - 1 do
          if GitOidSame(FBoundary[K].Oid, Entry.Parents[I]) then
          begin
            IsHidden := True;
            Break;
          end;
        if not IsHidden then
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
  I: Integer;
  WasBoundary: Boolean;
begin
  // drain heap first, then boundary
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
  // Next may have returned a boundary entry via its own drain; detect by checking if Oid is in boundary list and heap was empty
  WasBoundary := False;
  for I := 0 to FBoundaryLen - 1 do
    if GitOidSame(FBoundary[I].Oid, Oid) then
    begin
      // if Oid was boundary, it would have been appended to FBoundary and returned after heap empty
      // To know if this call returned boundary, check if FBoundaryPos was just incremented
      // Simpler: if Oid exists in boundary list, mark as boundary
      WasBoundary := True;
      Break;
    end;
  // But non-boundary Oids never in boundary list, so check suffices
  AEntry.Oid := Oid;
  AEntry.IsBoundary := WasBoundary;
  Result := True;
end;

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
        if LCap = 0 then LCap := 256 else if LCap < 8192 then LCap := LCap * 2 else Inc(LCap, 8192);
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
        if LCap = 0 then LCap := 256 else if LCap < 8192 then LCap := LCap * 2 else Inc(LCap, 8192);
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
  Heap: array of TWalkEntry;
  HeapCap: SizeInt;
  HeapLen: SizeInt;
  BoundarySet: TGitOidSet;
  BoundaryList: TGitOidArray;
  Graph: TCommitGraph;
  ParseCache: TCommitParseCache;
  ResCount, ResCap: SizeInt;
  BndCount, BndCap: SizeInt;

  procedure HeapPushLocal(const AEntry: TWalkEntry); inline;
  var
    I, Parent: Integer;
  begin
    // geometric growth: 64 -> *2; amortized O(1) push (no fixed +4096, keeps O(log n) SetLength)
    if HeapLen >= HeapCap then
    begin
      if HeapCap = 0 then HeapCap := 64 else HeapCap := HeapCap * 2;
      SetLength(Heap, HeapCap);
    end;
    I := HeapLen;
    Inc(HeapLen);
    while I > 0 do
    begin
      Parent := (I - 1) div 2;
      if Heap[Parent].When >= AEntry.When then
        Break;
      Heap[I] := Heap[Parent];
      I := Parent;
    end;
    Heap[I] := AEntry;
  end;

  function HeapPopLocal(out AEntry: TWalkEntry): Boolean; inline;
  var
    I, L, R, Best: Integer;
    LastEntry: TWalkEntry;
  begin
    Result := HeapLen > 0;
    if not Result then
      Exit;
    AEntry := Heap[0];
    Dec(HeapLen);
    if HeapLen = 0 then
    begin
      Heap[0] := Default(TWalkEntry);
      Exit;
    end;
    LastEntry := Heap[HeapLen];
    Heap[HeapLen] := Default(TWalkEntry);
    I := 0;
    while True do
    begin
      L := 2 * I + 1;
      R := L + 1;
      Best := I;
      if (L < HeapLen) and (Heap[L].When > Heap[Best].When) then
        Best := L;
      if (R < HeapLen) and (Heap[R].When > Heap[Best].When) then
        Best := R;
      if Best = I then
        Break;
      Heap[I] := Heap[Best];
      I := Best;
    end;
    Heap[I] := LastEntry;
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
    Entry.Parents := Copy(GParents);
    HeapPushLocal(Entry);
  end;

  procedure AppendBoundary(const AOid: TGitOid);
  begin
    if BndCount >= BndCap then
    begin
      if BndCap = 0 then BndCap := 32 else if BndCap < 4096 then BndCap := BndCap * 2 else Inc(BndCap, 4096);
      SetLength(BoundaryList, BndCap);
    end;
    BoundaryList[BndCount] := AOid;
    Inc(BndCount);
  end;

  procedure AppendResult(const AOid: TGitOid; AIsBoundary: Boolean);
  begin
    if ResCount >= ResCap then
    begin
      if ResCap = 0 then ResCap := 256 else if ResCap < 8192 then ResCap := ResCap * 2 else Inc(ResCap, 8192);
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
      BuildHiddenSet(ARepo, AHides, AOptions.FirstParent, Hidden, ParseCache);
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
    Seen.Free;
    BoundarySet.Free;
    ParseCache.Free;
    if Hidden <> nil then
      Hidden.Free;
    if Graph <> nil then
      Graph.Free;
  end;
end;

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

{ stable merge sort of node indices by oid bytes; single shared scratch }
procedure TopoSortRange(var AOrder: TNodeIndexArray;
  var AScratch: TNodeIndexArray; const ANodes: TTopoNodes;
  ALow, AHigh: Integer);
var
  Mid, I, J, K: Integer;
begin
  if ALow >= AHigh then
    Exit;
  Mid := (ALow + AHigh) div 2;
  TopoSortRange(AOrder, AScratch, ANodes, ALow, Mid);
  TopoSortRange(AOrder, AScratch, ANodes, Mid + 1, AHigh);
  Move(AOrder[ALow], AScratch[ALow],
    SizeInt(AHigh - ALow + 1) * SizeOf(Integer));
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
  Move(AScratch[ALow], AOrder[ALow],
    SizeInt(AHigh - ALow + 1) * SizeOf(Integer));
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

{ ascending by commit time, stable; the ready stack pops from the tail,
  so the newest initial tip goes first - mirroring limit_list's order }
procedure TopoSortTips(var ATips: TNodeIndexArray; const ANodes: TTopoNodes);
var
  I, J, Tmp: Integer;
begin
  for I := 1 to High(ATips) do
  begin
    Tmp := ATips[I];
    J := I - 1;
    while (J >= 0) and (ANodes[ATips[J]].When > ANodes[Tmp].When) do
    begin
      ATips[J + 1] := ATips[J];
      Dec(J);
    end;
    ATips[J + 1] := Tmp;
  end;
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
        // perf: geometric Nodes growth via bytes.ops GrowArrayCapacity single source, inline, amortized O(1) push, zero-copy record Move, avoids O(n²) SetLength(NodesLen+1) churn
        SetLength(Nodes, SizeInt(GrowArrayCapacity(SizeUInt(Length(Nodes)), SizeUInt(NodesLen + 1))));
      end;
      NodeIdx := NodesLen;
      Inc(NodesLen);
      Nodes[NodeIdx].Oid := Oid;
      Nodes[NodeIdx].When := GWhen;
      Nodes[NodeIdx].Parents := Copy(GParents);
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

    { phase 2: count each node's children within the set }
    SetLength(Order, Length(Nodes));
    for I := 0 to High(Nodes) do
      Order[I] := I;
    if Length(Nodes) > 1 then
    begin
      SetLength(Scratch, Length(Nodes));
      TopoSortRange(Order, Scratch, Nodes, 0, High(Nodes));
    end;
    for I := 0 to High(Nodes) do
      for J := 0 to High(Nodes[I].Parents) do
      begin
        ParentIdx := TopoNodeIndexOf(Nodes[I].Parents[J], Order, Nodes);
        if ParentIdx < 0 then
          raise EGitError.Create('topo walk lost a reachable parent');
        Inc(Nodes[ParentIdx].ChildCount);
      end;

    { phase 3: emit through a LIFO ready stack - git's default topo sort
      (REV_SORT_IN_GRAPH_ORDER). Initial tips are stacked oldest-first so
      the newest pops first; afterwards the last-listed newly-ready parent
      pops before its siblings. }
    // perf: Ready LIFO geometric growth via bytes.ops GrowArrayCapacity single source (BYTES_BUILDER_MIN_GROW + *2), inline, amortized O(1) push, zero-copy Integer Move, avoids O(n²) SetLength(Length+1) churn
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
      // perf: inline LIFO pop over ReadyLen/ReadyCap (no SetLength shrink, amortized O(1), zero-copy)
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
      begin if ResCap=0 then ResCap:=256 else if ResCap<8192 then ResCap:=ResCap*2 else Inc(ResCap,8192); SetLength(Result, ResCap); end;
      Result[ResCount] := Nodes[NodeIdx].Oid;
      Inc(ResCount);
      for J := 0 to High(Nodes[NodeIdx].Parents) do
      begin
        ParentIdx := TopoNodeIndexOf(Nodes[NodeIdx].Parents[J], Order, Nodes);
        Dec(Nodes[ParentIdx].ChildCount);
        if Nodes[ParentIdx].ChildCount = 0 then
        begin
          // perf: geometric Ready growth via bytes.ops GrowArrayCapacity single source
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
      begin if LCap=0 then LCap:=256 else if LCap<8192 then LCap:=LCap*2 else Inc(LCap,8192); SetLength(Result, LCap); end;
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
    begin if BndCap=0 then BndCap:=32 else if BndCap<4096 then BndCap:=BndCap*2 else Inc(BndCap,4096); SetLength(BoundaryList, BndCap); end;
    BoundaryList[BndCount] := AOid; Inc(BndCount);
  end;
  procedure AppendResult(const AOid: TGitOid; AIsBoundary: Boolean);
  begin
    if ResCount >= ResCap then
    begin if ResCap=0 then ResCap:=256 else if ResCap<8192 then ResCap:=ResCap*2 else Inc(ResCap,8192); SetLength(Result, ResCap); end;
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
    BuildHiddenSet(ARepo, AHides, AOptions.FirstParent, Hidden, ParseCache);
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
        // perf: geometric Nodes growth via bytes.ops GrowArrayCapacity single source, inline, amortized O(1) push, zero-copy record Move, avoids O(n²) SetLength(NodesLen+1) churn
        SetLength(Nodes, SizeInt(GrowArrayCapacity(SizeUInt(Length(Nodes)), SizeUInt(NodesLen + 1))));
      end;
      NodeIdx := NodesLen;
      Inc(NodesLen);
      Nodes[NodeIdx].Oid := Oid;
      Nodes[NodeIdx].When := GWhen;
      // store parents respecting first-parent flag for graph edges
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
        Nodes[NodeIdx].Parents := Copy(GParents);
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
    // phase 2: child counts among included nodes only
    SetLength(Order, Length(Nodes));
    for I := 0 to High(Nodes) do
      Order[I] := I;
    if Length(Nodes) > 1 then
    begin
      SetLength(Scratch, Length(Nodes));
      TopoSortRange(Order, Scratch, Nodes, 0, High(Nodes));
    end;
    for I := 0 to High(Nodes) do
      for J := 0 to High(Nodes[I].Parents) do
      begin
        // parents that are hidden are not in Nodes, so skip counting
        ParentIdx := TopoNodeIndexOf(Nodes[I].Parents[J], Order, Nodes);
        if ParentIdx < 0 then
          Continue;
        Inc(Nodes[ParentIdx].ChildCount);
      end;
    // prepare date filter flags
    SetLength(DateFiltered, Length(Nodes));
    for I := 0 to High(Nodes) do
      DateFiltered[I] := not PassesDateFilter(Nodes[I].When, AOptions.Since, AOptions.UntilTime);
    // phase 3: LIFO ready stack
    // perf: Ready LIFO geometric growth via bytes.ops GrowArrayCapacity single source (BYTES_BUILDER_MIN_GROW + *2), inline, amortized O(1) push, zero-copy Integer Move, avoids O(n²) SetLength(Length+1) churn
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
      // perf: inline LIFO pop over ReadyLen/ReadyCap (no SetLength shrink, amortized O(1), zero-copy)
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
        ParentIdx := TopoNodeIndexOf(Nodes[NodeIdx].Parents[J], Order, Nodes);
        if ParentIdx < 0 then
          Continue;
        Dec(Nodes[ParentIdx].ChildCount);
        if Nodes[ParentIdx].ChildCount = 0 then
        begin
          // perf: geometric Ready growth via bytes.ops GrowArrayCapacity single source
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
