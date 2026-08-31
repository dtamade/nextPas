unit nextpas.core.mem.pool.slab.concurrent;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base.utils,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.mutex,
  nextpas.core.mem.pool.base,
  nextpas.core.mem.pool.slab;

type
  {**
   * TSlabPoolConcurrent
   *
   * @desc 线程安全的 SlabPool 包装器，采用 TLS freelist 缓存 + 全局锁回退。
   *       Thread-safe SlabPool wrapper with TLS freelist cache + global lock fallback.
   *
   * @performance
   *   热路径（TLS 缓存命中）：零锁、零 syscall，仅 2-3 个 field write。
   *   冷路径（缓存未命中）：批量从全局池补充（默认 8 个指针），摊销锁开销。
   *   设计对标 jemalloc/tcmalloc 的 thread-local cache 模式。
   *
   *   Hot path (TLS cache hit): zero lock, zero syscall, 2-3 field writes.
   *   Cold path (cache miss): batch refill from global pool (default 8 pointers),
   *   amortizing lock cost. Modeled after jemalloc/tcmalloc thread-local cache.
   *
   * @thread_safety
   *   每线程维护独立的 TLS 缓存，与全局池交互时才加锁。
   *   多个 TSlabPoolConcurrent 实例可安全共存 — TLS 缓存通过池实例指针验证归属。
   *
   *   Each thread maintains an independent TLS cache. Lock only acquired when
   *   interacting with the global pool. Multiple TSlabPoolConcurrent instances
   *   can safely coexist — TLS cache validates ownership via pool instance pointer.
   *
   * @note
   *   - Reset 会使之前分配的指针失效；调用端需要自行保证语义正确
   *   - 选择指南：通用场景 → TSlabPoolConcurrent；极端分片需求 → TSlabPoolSharded
   *}
  TSlabPoolConcurrent = class(TInterfacedObject, IMemoryPool, IAllocator)
  private
    {**
     * Lock ordering: Single mutex (FLock). No nesting with other locks.
     * All IMemoryPool/IAllocator operations are serialized under FLock.
     *
     * 锁顺序：单锁（FLock），不与其他锁嵌套，所有操作在 FLock 下串行。
     *}
    FInner: TSlabPool;
    FLock: TMemMutex;
    FGuard: Pointer; // 哨兵：alive 时 = Self，Destroy 时置 nil，配合 PurgeDead 避免 threadvar 悬垂 UAF
  public
    constructor Create(aCapacity: SizeUInt; AAllocator: IAllocator = nil; aMinShift: SizeUInt = 3); overload;
    constructor Create(aCapacity: SizeUInt; const AConfig: TSlabConfig; AAllocator: IAllocator = nil); overload;
    destructor Destroy; override;
  public
    // IPool
    function Acquire(out APtr: Pointer): Boolean;
    function TryAcquire(out APtr: Pointer): Boolean;
    function AcquireN(out aUnits: array of Pointer; aCount: Integer): Integer;
    procedure Release(APtr: Pointer);
    procedure ReleaseN(const aUnits: array of Pointer; aCount: Integer);
    procedure Reset;
    // IMemoryPool
    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(APtr: Pointer);
    function MemSizeOf(APtr: Pointer): SizeUInt;
    // IAllocator aligned allocation
    function AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
    procedure FreeAligned(APtr: Pointer);
    // IAllocator capability
    function Traits: TAllocatorTraits;
  public
    function Warmup(aUnitSize: SizeUInt; aMinPages: SizeUInt): SizeUInt;
    // Diagnostics forwarding
    function Owns(APtr: Pointer): Boolean;
    function Stats: TSlabPoolStats;
    function GetPerfCounters: TSlabPerfCounters;
    function SegmentCount: Integer;
    function FallbackAllocCount: Integer;
  end;

implementation

const
  {** TLS 缓存容量：每线程最多缓存的指针数 *}
  TLS_SLAB_CACHE_SIZE = 32;
  {** 批量补充数量：从全局池一次取的指针数 *}
  TLS_SLAB_REFILL_COUNT = 8;

type
  {** TLS 缓存条目：指针 + 实际分配大小 + 所属池实例 *}
  TTlsSlabEntry = record
    Ptr: Pointer;
    Size: SizeUInt;  { 实际分配大小（来自 MemSizeOf），用于匹配请求 }
    Pool: Pointer;   { TSlabPoolConcurrent 实例指针，用于验证归属 }
  end;

  {** TLS freelist 缓存：数组栈实现，LIFO 顺序 *}
  TTlsSlabCache = record
    Entries: array[0..TLS_SLAB_CACHE_SIZE - 1] of TTlsSlabEntry;
    Count: Integer;
  end;

threadvar
  GTlsSlabCache: TTlsSlabCache;

var
  GDeadLock: TMemMutex;
  GDeadList: array of Pointer;
  GDeadCount: Integer;
  GDeadLockInited: Boolean;

{ ---------------------------------------------------------------------------
  TLS 缓存内部函数 — UAF 修复：FGuard 哨兵 + PurgeDead 零拷贝紧凑
  --------------------------------------------------------------------------- }

function IsDeadPool(APool: Pointer): Boolean;
var
  I: Integer;
begin
  if (APool = nil) or (not GDeadLockInited) then
    Exit(False);
  GDeadLock.Acquire;
  try
    for I := 0 to GDeadCount - 1 do
      if GDeadList[I] = APool then
        Exit(True);
    Result := False;
  finally
    GDeadLock.Release;
  end;
end;

procedure RegisterDeadPool(APool: Pointer);
begin
  if APool = nil then Exit;
  if not GDeadLockInited then Exit;
  GDeadLock.Acquire;
  try
    if GDeadCount = Length(GDeadList) then
      SetLength(GDeadList, GDeadCount + 16);
    GDeadList[GDeadCount] := APool;
    Inc(GDeadCount);
  finally
    GDeadLock.Release;
  end;
end;

// 零拷贝紧凑：移除已死亡池的悬垂条目，不拷贝有效条目之外的内存
procedure PurgeDead(var ACache: TTlsSlabCache);
var
  I, W: Integer;
begin
  if ACache.Count = 0 then Exit;
  W := 0;
  for I := 0 to ACache.Count - 1 do
  begin
    if IsDeadPool(ACache.Entries[I].Pool) then
      Continue; // 悬垂条目：丢弃，不归还（池已销毁）
    if W <> I then
      ACache.Entries[W] := ACache.Entries[I];
    Inc(W);
  end;
  ACache.Count := W;
end;

{** 从 TLS 缓存弹出匹配池实例且实际大小 >= 请求大小的条目 *}
function TlsCachePop(var ACache: TTlsSlabCache; APool: Pointer; AMinSize: SizeUInt): Pointer;
var
  I, L: Integer;
begin
  // 热路径先惰性清理悬垂条目（FGuard 哨兵）
  if ACache.Count > 0 then
    PurgeDead(ACache);
  for I := ACache.Count - 1 downto 0 do
  begin
    if (ACache.Entries[I].Pool = APool) and (ACache.Entries[I].Size >= AMinSize) then
    begin
      Result := ACache.Entries[I].Ptr;
      L := ACache.Count - 1;
      if I <> L then
        ACache.Entries[I] := ACache.Entries[L];
      ACache.Count := L;
      Exit;
    end;
  end;
  Result := nil;
end;

{** 向 TLS 缓存压入条目。返回 True 表示成功，False 表示缓存已满 *}
function TlsCachePush(var ACache: TTlsSlabCache; APtr: Pointer; ASize: SizeUInt; APool: Pointer): Boolean;
begin
  // 热路径先惰性清理悬垂条目
  if ACache.Count > 0 then
    PurgeDead(ACache);
  if ACache.Count >= TLS_SLAB_CACHE_SIZE then
    Exit(False);
  ACache.Entries[ACache.Count].Ptr := APtr;
  ACache.Entries[ACache.Count].Size := ASize;
  ACache.Entries[ACache.Count].Pool := APool;
  Inc(ACache.Count);
  Result := True;
end;

{** 将 TLS 缓存中属于指定池的条目归还全局池，保留其他池的条目 *}
procedure TlsCacheFlushPoolEntries(var ACache: TTlsSlabCache; APool: Pointer;
  AInner: TSlabPool);
var
  I, LWrite: Integer;
begin
  LWrite := 0;
  for I := 0 to ACache.Count - 1 do
  begin
    if ACache.Entries[I].Pool = APool then
      AInner.FreeMem(ACache.Entries[I].Ptr)
    else
    begin
      if LWrite <> I then
        ACache.Entries[LWrite] := ACache.Entries[I];
      Inc(LWrite);
    end;
  end;
  ACache.Count := LWrite;
end;

{ TSlabPoolConcurrent }

constructor TSlabPoolConcurrent.Create(aCapacity: SizeUInt; AAllocator: IAllocator; aMinShift: SizeUInt);
begin
  inherited Create;
  FLock.Init;
  FInner := TSlabPool.Create(aCapacity, AAllocator, aMinShift);
  FGuard := Pointer(Self);
end;

constructor TSlabPoolConcurrent.Create(aCapacity: SizeUInt; const AConfig: TSlabConfig; AAllocator: IAllocator);
begin
  inherited Create;
  FLock.Init;
  FInner := TSlabPool.Create(aCapacity, AConfig, AAllocator);
  FGuard := Pointer(Self);
end;

destructor TSlabPoolConcurrent.Destroy;
begin
  // 哨兵失效：先标记 dead，再清理当前线程 TLS，避免悬垂 UAF
  FGuard := nil;
  RegisterDeadPool(Pointer(Self));
  PurgeDead(GTlsSlabCache);
  // 零拷贝紧凑前先尽量归还（对 alive 池有效，dead 池的条目已被 PurgeDead 丢弃）
  TlsCacheFlushPoolEntries(GTlsSlabCache, Pointer(Self), FInner);
  FLock.Acquire;
  try
    FreeAndNil(FInner);
  finally
    FLock.Release;
  end;
  FLock.Done;
  inherited Destroy;
end;

{ ---------------------------------------------------------------------------
  IPool
  --------------------------------------------------------------------------- }

function TSlabPoolConcurrent.Acquire(out APtr: Pointer): Boolean;
var
  LUnitSize: SizeUInt;
begin
  LUnitSize := SizeUInt(1) shl 3;
  if LUnitSize < SizeOf(Pointer) then LUnitSize := SizeOf(Pointer);
  APtr := GetMem(LUnitSize);
  Result := APtr <> nil;
end;

function TSlabPoolConcurrent.TryAcquire(out APtr: Pointer): Boolean;
begin
  Result := Acquire(APtr);
end;

function TSlabPoolConcurrent.AcquireN(out aUnits: array of Pointer; aCount: Integer): Integer;
var
  LIdx: Integer;
begin
  Result := 0;
  for LIdx := 0 to aCount - 1 do
  begin
    if LIdx > High(aUnits) then Break;
    if not Acquire(aUnits[LIdx]) then Break;
    Inc(Result);
  end;
end;

procedure TSlabPoolConcurrent.Release(APtr: Pointer);
begin
  FreeMem(APtr);
end;

procedure TSlabPoolConcurrent.ReleaseN(const aUnits: array of Pointer; aCount: Integer);
var
  LIdx: Integer;
begin
  for LIdx := 0 to aCount - 1 do
  begin
    if LIdx > High(aUnits) then Break;
    FreeMem(aUnits[LIdx]);
  end;
end;

procedure TSlabPoolConcurrent.Reset;
begin
  TlsCacheFlushPoolEntries(GTlsSlabCache, Pointer(Self), FInner);
  FLock.Acquire;
  try
    FInner.Reset;
  finally
    FLock.Release;
  end;
end;

{ ---------------------------------------------------------------------------
  IMemoryPool — TLS freelist 热路径
  --------------------------------------------------------------------------- }

function TSlabPoolConcurrent.GetMem(ASize: SizeUInt): Pointer;
var
  LPtr: Pointer;
  LActualSize: SizeUInt;
  LCount: Integer;
begin
  if ASize = 0 then Exit(nil);

  { 热路径：从 TLS 缓存取（零锁）。条目存储的是实际分配大小（>= 请求大小） }
  LPtr := TlsCachePop(GTlsSlabCache, Pointer(Self), ASize);
  if LPtr <> nil then
    Exit(LPtr);

  { 冷路径：加锁，批量从全局池补充 }
  FLock.Acquire;
  try
    LCount := 0;
    while LCount < TLS_SLAB_REFILL_COUNT do
    begin
      LPtr := FInner.GetMem(ASize);
      if LPtr = nil then Break;
      Inc(LCount);
      if LCount = 1 then
      begin
        { 第一个直接返回给调用方 }
        Result := LPtr;
        Continue;
      end;
      { 后续的放入 TLS 缓存，存储实际分配大小（此时持有锁，可查 MemSizeOf） }
      LActualSize := FInner.MemSizeOf(LPtr);
      if LActualSize < ASize then LActualSize := ASize;
      if not TlsCachePush(GTlsSlabCache, LPtr, LActualSize, Pointer(Self)) then
      begin
        { 缓存满了，直接归还全局池 }
        FInner.FreeMem(LPtr);
        Break;
      end;
    end;
  finally
    FLock.Release;
  end;

  if LCount = 0 then
    Result := nil;
end;

function TSlabPoolConcurrent.AllocMem(ASize: SizeUInt): Pointer;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TSlabPoolConcurrent.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  if APtr = nil then Exit(GetMem(ASize));
  if ASize = 0 then begin FreeMem(APtr); Exit(nil); end;

  { Realloc 需要精确的旧大小和数据拷贝，走全局池路径 }
  FLock.Acquire;
  try
    Result := FInner.ReallocMem(APtr, ASize);
  finally
    FLock.Release;
  end;
end;

procedure TSlabPoolConcurrent.FreeMem(APtr: Pointer);
var
  LSize: SizeUInt;
begin
  if APtr = nil then Exit;

  { 热路径：尝试放回 TLS 缓存（零锁）。存储实际分配大小以便后续 GetMem 匹配。 }
  LSize := FInner.MemSizeOf(APtr);
  if TlsCachePush(GTlsSlabCache, APtr, LSize, Pointer(Self)) then
    Exit;

  { 冷路径：TLS 缓存已满，批量归还全局池 }
  FLock.Acquire;
  try
    TlsCacheFlushPoolEntries(GTlsSlabCache, Pointer(Self), FInner);
    FInner.FreeMem(APtr);
  finally
    FLock.Release;
  end;
end;

function TSlabPoolConcurrent.MemSizeOf(APtr: Pointer): SizeUInt;
begin
  FLock.Acquire;
  try
    Result := FInner.MemSizeOf(APtr);
  finally
    FLock.Release;
  end;
end;

{ ---------------------------------------------------------------------------
  IAllocator aligned allocation — 全局池路径
  --------------------------------------------------------------------------- }

function TSlabPoolConcurrent.AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
begin
  FLock.Acquire;
  try
    Result := FInner.AllocAligned(ASize, AAlignment);
  finally
    FLock.Release;
  end;
end;

procedure TSlabPoolConcurrent.FreeAligned(APtr: Pointer);
begin
  FreeMem(APtr);
end;

function TSlabPoolConcurrent.Traits: TAllocatorTraits;
begin
  Result := FInner.Traits;
  Result.ThreadSafe := True;
end;

function TSlabPoolConcurrent.Warmup(aUnitSize: SizeUInt; aMinPages: SizeUInt): SizeUInt;
begin
  FLock.Acquire;
  try
    Result := FInner.Warmup(aUnitSize, aMinPages);
  finally
    FLock.Release;
  end;
end;

{ ---------------------------------------------------------------------------
  Diagnostics forwarding
  --------------------------------------------------------------------------- }

function TSlabPoolConcurrent.Owns(APtr: Pointer): Boolean;
begin
  FLock.Acquire;
  try
    Result := FInner.Owns(APtr);
  finally
    FLock.Release;
  end;
end;

function TSlabPoolConcurrent.Stats: TSlabPoolStats;
begin
  FLock.Acquire;
  try
    Result := FInner.Stats;
  finally
    FLock.Release;
  end;
end;

function TSlabPoolConcurrent.GetPerfCounters: TSlabPerfCounters;
begin
  FLock.Acquire;
  try
    Result := FInner.GetPerfCounters;
  finally
    FLock.Release;
  end;
end;

function TSlabPoolConcurrent.SegmentCount: Integer;
begin
  FLock.Acquire;
  try
    Result := FInner.SegmentCount;
  finally
    FLock.Release;
  end;
end;

function TSlabPoolConcurrent.FallbackAllocCount: Integer;
begin
  FLock.Acquire;
  try
    Result := FInner.FallbackAllocCount;
  finally
    FLock.Release;
  end;
end;

initialization
  GDeadLock.Init;
  GDeadLockInited := True;

finalization
  GDeadLockInited := False;
  GDeadLock.Done;
  SetLength(GDeadList, 0);
  GDeadCount := 0;

end.
