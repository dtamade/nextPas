unit nextpas.core.mem.pool.slab.concurrent;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base.utils,
  nextpas.core.mem.intf,
  nextpas.core.mem.mutex,
  nextpas.core.mem.pool.memory_pool,
  nextpas.core.mem.pool.slab;

type
  {**
   * TSlabPoolConcurrent
   *
   * @desc 线程安全的 SlabPool 包装器（临界区串行化）
   *       Thread-safe wrapper for TSlabPool (single critical section)
   *
   * @note
   *   - 目标：先提供正确性与可用性；并发优化（分段锁 / tcache）后续再做
   *   - Reset 会使之前分配的指针失效；调用端需要自行保证语义正确
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
  public
    constructor Create(aCapacity: SizeUInt; aAllocator: IAllocator = nil; aMinShift: SizeUInt = 3); overload;
    constructor Create(aCapacity: SizeUInt; const aConfig: TSlabConfig; aAllocator: IAllocator = nil); overload;
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
    function ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(ADst: Pointer);
    function MemSize(APtr: Pointer): SizeUInt;
    // IAllocator aligned allocation
    function AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
    procedure FreeAligned(APtr: Pointer);
    // IAllocator capability
    function Traits: TAllocatorTraits;
  public
    // Compatibility helpers (same semantics as inner)
    function Alloc(ASize: SizeUInt): Pointer; inline;
    procedure Free(APtr: Pointer); inline;
    procedure ReleasePtr(APtr: Pointer); inline;
    function Warmup(aUnitSize: SizeUInt; aMinPages: SizeUInt): SizeUInt;
    // Diagnostics forwarding
    function Owns(APtr: Pointer): Boolean;
    function MemSizeOf(APtr: Pointer): SizeUInt;
    function Stats: TSlabPoolStats;
    function GetPerfCounters: TSlabPerfCounters;
    function SegmentCount: Integer;
    function FallbackAllocCount: Integer;
  end;

implementation

{ TSlabPoolConcurrent }

constructor TSlabPoolConcurrent.Create(aCapacity: SizeUInt; aAllocator: IAllocator; aMinShift: SizeUInt);
begin
  inherited Create;
  FLock.Init;
  FInner := TSlabPool.Create(aCapacity, aAllocator, aMinShift);
end;

constructor TSlabPoolConcurrent.Create(aCapacity: SizeUInt; const aConfig: TSlabConfig; aAllocator: IAllocator);
begin
  inherited Create;
  FLock.Init;
  FInner := TSlabPool.Create(aCapacity, aConfig, aAllocator);
end;

destructor TSlabPoolConcurrent.Destroy;
begin
  FLock.Acquire;
  try
    FreeAndNil(FInner);
  finally
    FLock.Release;
  end;
  FLock.Done;
  inherited Destroy;
end;

function TSlabPoolConcurrent.Acquire(out APtr: Pointer): Boolean;
begin
  FLock.Acquire;
  try
    Result := FInner.Acquire(APtr);
  finally
    FLock.Release;
  end;
end;

function TSlabPoolConcurrent.TryAcquire(out APtr: Pointer): Boolean;
begin
  FLock.Acquire;
  try
    Result := FInner.TryAcquire(APtr);
  finally
    FLock.Release;
  end;
end;

function TSlabPoolConcurrent.AcquireN(out aUnits: array of Pointer; aCount: Integer): Integer;
begin
  FLock.Acquire;
  try
    Result := FInner.AcquireN(aUnits, aCount);
  finally
    FLock.Release;
  end;
end;

procedure TSlabPoolConcurrent.Release(APtr: Pointer);
begin
  FLock.Acquire;
  try
    FInner.Release(APtr);
  finally
    FLock.Release;
  end;
end;

procedure TSlabPoolConcurrent.ReleaseN(const aUnits: array of Pointer; aCount: Integer);
begin
  FLock.Acquire;
  try
    FInner.ReleaseN(aUnits, aCount);
  finally
    FLock.Release;
  end;
end;

procedure TSlabPoolConcurrent.Reset;
begin
  FLock.Acquire;
  try
    FInner.Reset;
  finally
    FLock.Release;
  end;
end;

function TSlabPoolConcurrent.GetMem(ASize: SizeUInt): Pointer;
begin
  FLock.Acquire;
  try
    Result := FInner.GetMem(ASize);
  finally
    FLock.Release;
  end;
end;

function TSlabPoolConcurrent.AllocMem(ASize: SizeUInt): Pointer;
begin
  FLock.Acquire;
  try
    Result := FInner.AllocMem(ASize);
  finally
    FLock.Release;
  end;
end;

function TSlabPoolConcurrent.ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
begin
  FLock.Acquire;
  try
    Result := FInner.ReallocMem(ADst, ASize);
  finally
    FLock.Release;
  end;
end;

procedure TSlabPoolConcurrent.FreeMem(ADst: Pointer);
begin
  FLock.Acquire;
  try
    FInner.FreeMem(ADst);
  finally
    FLock.Release;
  end;
end;

function TSlabPoolConcurrent.MemSize(APtr: Pointer): SizeUInt;
begin
  FLock.Acquire;
  try
    Result := FInner.MemSize(APtr);
  finally
    FLock.Release;
  end;
end;

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
  FLock.Acquire;
  try
    FInner.FreeAligned(APtr);
  finally
    FLock.Release;
  end;
end;

function TSlabPoolConcurrent.Traits: TAllocatorTraits;
begin
  Result := FInner.Traits;
  Result.ThreadSafe := True;
end;

function TSlabPoolConcurrent.Alloc(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
end;

procedure TSlabPoolConcurrent.Free(APtr: Pointer); inline;
begin
  FreeMem(APtr);
end;

procedure TSlabPoolConcurrent.ReleasePtr(APtr: Pointer); inline;
begin
  FreeMem(APtr);
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

function TSlabPoolConcurrent.Owns(APtr: Pointer): Boolean;
begin
  FLock.Acquire;
  try
    Result := FInner.Owns(APtr);
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

end.
