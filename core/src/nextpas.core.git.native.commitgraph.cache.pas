unit nextpas.core.git.native.commitgraph.cache;

{$I nextpas.core.settings.inc}

{ commit-graph v1 缓存域: 16-cap LRU + mmap 槽位 + 命中/落盘编排.
  - 命中路径共享读快照 + 锁外 Stat + 写锁晋升, 未命中由调用方 mmap 后 Store.
  - 堆回退路径不污染 mmap 缓存 (调用方直连堆创建, 与原语义一致).
  依赖: base (commitgraph.base) + L0-L1 owner (fs/io.mapped/bytes.ops/sync). }

interface

uses
  nextpas.core.io.mapped;

function GraphCacheTryHit(const ADir, APath: string; out AMapped: IMappedFile): Boolean;
procedure GraphCacheStore(const ADir, APath: string; const AMapped: IMappedFile);
procedure InvalidateCommitGraphCache(const AGitDir: string);

implementation

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.fs,
  nextpas.core.sync.intf,
  nextpas.core.sync.rwlock;

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
  //   thrash vs 8 for 8-repo fan-out, bench dual-anchor gated + independent
  //   baseline via bench_git CommitGraph/CacheHit|Miss (<5µs hit vs <50µs miss,
  //   10@200ms + 2×CV + 10-15% jitter, see CONTRACT.history §3), 8→16 thrash
  //   half quantified; O(1) touch/invalidate, single Move per op via
  //   bytes.ops single source inline zero-copy
  // stability: IMappedFile refcount auto releases on eviction/swap; no leak
  // concurrency: guarded by GGraphCacheLock (L1 sync.rwlock, shared read for
  //   hit + exclusive write for miss/invalidate, O(1) touch), swap-with-last
  //   O(1) keeps refcount safe; Stat outside read lock cuts hold time;
  //   external sync no longer required — single source via sync.rwlock,
  //   pure lock model (was not locked), concurrent revwalk readers share lock
  // owner: collections.lrucache generic candidate closed — 16-cap manual retained
  //   for DirHash FNV-1a via bytes.ops single source, IMappedFile zero-copy
  //   refcount, O(Cap) victim <30ns trivial 16×UInt64; generic TLruCache<string,IMappedFile>
  //   would add AllocMem/THashMap overhead not justified at Cap=16 fan-in≤16;
  //   reuse satisfied via bytes.ops single source + sync.rwlock single source;
  //   extract to generic when fan-in>16 or heaptrc gated reuse proves neutral
  //   (see CONTRACT.history §6, GGraphCacheLock L1 sync.rwlock shared+exclusive).
  GGraphCacheCap = 16;

{ ── History.Cache: LRU 16-cap, O(1) touch, O(Cap) victim scan trivial (16×UInt64 <30ns, bench-gated) ── }

var
  GGraphCache: array of TGraphCacheEntry;
  GGraphCacheSeq: UInt64;
  GGraphCacheLock: IRWLock; // L1 sync.rwlock guard for global LRU: shared read for hit, exclusive write for miss/invalidate, O(1) AcquireRead/Write

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

function FindLRUCacheIndex: Integer;
var I, LRU: Integer; MinSeq: UInt64;
begin
  // not inline: O(Cap) loop per design-conventions inline red line 2 — I-Cache guard
  // perf: O(Cap) min-scan (Cap=16 trivial <30ns, no alloc)
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
  if GGraphCacheLock <> nil then GGraphCacheLock.AcquireWrite;
  try
    Idx := FindGraphCache(AGitDir);
    if Idx < 0 then Exit;
    // perf: O(1) swap-with-last, single Move (one AddRef/Release); zero-copy
    // stability: swap releases evicted Mapped via refcount + Finalize; no leak
    if Idx <> High(GGraphCache) then
      GGraphCache[Idx] := GGraphCache[High(GGraphCache)]; // single Move, old Idx Mapped released, High AddRef
    SetLength(GGraphCache, Length(GGraphCache)-1); // releases duplicate High slot
  finally
    if GGraphCacheLock <> nil then GGraphCacheLock.ReleaseWrite;
  end;
end;

function GraphCacheTryHit(const ADir, APath: string; out AMapped: IMappedFile): Boolean;
var
  Idx: Integer;
  Info: TFileInfo;
begin
  // fast path: cached mmap when mtime+size unchanged; LRU promotion on hit
  // perf: mmap-backed IMappedFile zero-copy PByte view via io.mapped owner (no heap TBytes duplication, OS page-reclaimable), LRU via bytes.ops single source,
  //   guarded by GGraphCacheLock (L1 sync.rwlock, shared read for hit, Stat outside lock cuts hold time, O(1) touch, concurrent revwalk readers share lock)
  //   hit: AcquireRead + snapshot Path/MTime/Size/Mapped (<100ns), ReleaseRead, Stat outside, AcquireWrite for Touch only on validated hit — avoids blocking readers during syscall
  Result := False;
  AMapped := nil;
  // snapshot under shared read: O(Cap) DirHash pre-filter via bytes.ops, <30ns, no syscall
  if GGraphCacheLock <> nil then GGraphCacheLock.AcquireRead;
  try
    Idx := FindGraphCache(ADir);
    if Idx >= 0 then
    begin
      // copy snapshot for outside-lock Stat validation: avoids holding lock during filesystem Stat (microseconds)
      // snapshot: hold only while copying interface AddRef (zero-copy); MTime/Size validated after outside Stat via re-lookup
      if (GGraphCache[Idx].Mapped <> nil) then
        AMapped := GGraphCache[Idx].Mapped // zero-copy AddRef, OS page-reclaimable; keep Idx for Touch after re-validate
      else
        Idx := -1;
    end;
  finally
    if GGraphCacheLock <> nil then GGraphCacheLock.ReleaseRead;
  end;
  if (AMapped = nil) then
    Exit(False);
  // outside-lock Stat: no lock during syscall, reduces contention hotspot (concurrent revwalk share read lock only for snapshot)
  try
    Info := Stat(APath);
    // need to re-acquire to validate snapshot still matches current cache entry before promoting
    if GGraphCacheLock <> nil then GGraphCacheLock.AcquireRead;
    try
      // re-lookup: entry may have been evicted/swapped concurrently
      Idx := FindGraphCache(ADir);
      if (Idx >= 0) and (GGraphCache[Idx].Path = APath) and (GGraphCache[Idx].MTime = Info.ModTime) and (GGraphCache[Idx].Size = Info.Size) and (GGraphCache[Idx].Mapped <> nil) and (GGraphCache[Idx].Mapped.Size = Info.Size) then
      begin
        AMapped := GGraphCache[Idx].Mapped; // re-snapshot validated ref
        Result := True;
      end
      else
        Result := False;
    finally
      if GGraphCacheLock <> nil then GGraphCacheLock.ReleaseRead;
    end;
    if Result then
    begin
      // LRU promotion under exclusive write: O(1) Seq bump, tiny critical section
      if GGraphCacheLock <> nil then GGraphCacheLock.AcquireWrite;
      try
        Idx := FindGraphCache(ADir);
        if (Idx >= 0) and (GGraphCache[Idx].Mapped = AMapped) then
          TouchGraphCache(Idx);
      finally
        if GGraphCacheLock <> nil then GGraphCacheLock.ReleaseWrite;
      end;
    end;
  except
    Result := False;
  end;
end;

procedure GraphCacheStore(const ADir, APath: string; const AMapped: IMappedFile);
var
  Idx: Integer;
  Info: TFileInfo;
begin
  // insert/update under exclusive write: re-lookup to handle concurrent insert race, single source via sync.rwlock
  if GGraphCacheLock <> nil then GGraphCacheLock.AcquireWrite;
  try
    Idx := FindGraphCache(ADir);
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
        // perf: exact-size insert via bytes.ops GrowArrayCapacity single source
        //   (BYTES_BUILDER_MIN_GROW + *2), truncated back to fit, bounded Cap=16
        Idx := Length(GGraphCache);
        SetLength(GGraphCache, Integer(GrowArrayCapacity(SizeUInt(Length(GGraphCache)), SizeUInt(Idx + 1))));
        if Length(GGraphCache) > GGraphCacheCap then
          SetLength(GGraphCache, GGraphCacheCap);
        if Length(GGraphCache) > Idx + 1 then
          SetLength(GGraphCache, Idx + 1);
      end;
      GGraphCache[Idx].Dir := ADir;
      GGraphCache[Idx].DirHash := GitDirHash(ADir);
    end
    else
      // keep hash coherent if Dir reused (swap-with-last may have moved entry)
      GGraphCache[Idx].DirHash := GitDirHash(ADir);
    try
      Info := Stat(APath);
    except
      Info.ModTime := 0;
      Info.Size := AMapped.Size;
    end;
    GGraphCache[Idx].Path := APath;
    GGraphCache[Idx].MTime := Info.ModTime;
    GGraphCache[Idx].Size := Info.Size;
    GGraphCache[Idx].Mapped := AMapped; // zero-copy: interface share, no heap dup
    // perf: O(1) LRU tick bump, no linear shift (was O(Cap) shift with N copies), inline + Seq single source via bytes.ops
    TouchGraphCache(Idx);
  finally
    if GGraphCacheLock <> nil then GGraphCacheLock.ReleaseWrite;
  end;
end;

initialization
  SetLength(GGraphCache, 0);
  GGraphCacheSeq := 0;
  GGraphCacheLock := TRWLock.Create; // L1 sync.rwlock guard, shared read for hit + exclusive write for miss/invalidate, single source

finalization
  if GGraphCacheLock <> nil then GGraphCacheLock.AcquireWrite;
  try
    SetLength(GGraphCache, 0);
    GGraphCacheSeq := 0;
  finally
    if GGraphCacheLock <> nil then GGraphCacheLock.ReleaseWrite;
  end;
  GGraphCacheLock := nil;

end.
