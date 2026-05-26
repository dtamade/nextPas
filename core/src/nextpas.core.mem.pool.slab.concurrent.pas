unit nextpas.core.mem.pool.slab.concurrent;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.sync,
  nextpas.core.mem.allocator.base,
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
    FInner: TSlabPool;
    FLock: IMutex;
  public
    constructor Create(aCapacity: SizeUInt; aAllocator: IAllocator = nil; aMinShift: SizeUInt = 3); overload;
    constructor Create(aCapacity: SizeUInt; const aConfig: TSlabConfig; aAllocator: IAllocator = nil); overload;
    destructor Destroy; override;
  public
    // IPool
    function Acquire(out aPtr: Pointer): Boolean;
    function TryAcquire(out aPtr: Pointer): Boolean;
    function AcquireN(out aUnits: array of Pointer; aCount: Integer): Integer;
    procedure Release(aPtr: Pointer);
    procedure ReleaseN(const aUnits: array of Pointer; aCount: Integer);
    procedure Reset;
    // IMemoryPool
    function GetMem(aSize: SizeUInt): Pointer;
    function AllocMem(aSize: SizeUInt): Pointer;
    function ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
    procedure FreeMem(aDst: Pointer);
    function Allocate(const ASize: SizeUInt): Pointer;
    function Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
    procedure Deallocate(const APtr: Pointer);
    // IAllocator aligned allocation
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    procedure FreeAligned(aPtr: Pointer);
    // IAllocator capability
    function Traits: TAllocatorTraits;
  public
    // Compatibility helpers (same semantics as inner)
    function Alloc(aSize: SizeUInt): Pointer; inline;
    procedure Free(aPtr: Pointer); inline;
    procedure ReleasePtr(aPtr: Pointer); inline;
    function Warmup(aUnitSize: SizeUInt; aMinPages: SizeUInt): SizeUInt;
    // Diagnostics forwarding
    function Owns(aPtr: Pointer): Boolean;
    function MemSizeOf(aPtr: Pointer): SizeUInt;
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
  FLock := Mutex;
  FInner := TSlabPool.Create(aCapacity, aAllocator, aMinShift);
end;

constructor TSlabPoolConcurrent.Create(aCapacity: SizeUInt; const aConfig: TSlabConfig; aAllocator: IAllocator);
begin
  inherited Create;
  FLock := Mutex;
  FInner := TSlabPool.Create(aCapacity, aConfig, aAllocator);
end;

destructor TSlabPoolConcurrent.Destroy;
begin
  if FLock <> nil then
    FLock.Acquire;
  try
    FreeAndNil(FInner);
  finally
    if FLock <> nil then
      FLock.Release;
  end;
  FLock := nil;
  inherited Destroy;
end;

function TSlabPoolConcurrent.Acquire(out aPtr: Pointer): Boolean;
begin
  FLock.Acquire;
  try
    Result := FInner.Acquire(aPtr);
  finally
    FLock.Release;
  end;
end;

function TSlabPoolConcurrent.TryAcquire(out aPtr: Pointer): Boolean;
begin
  FLock.Acquire;
  try
    Result := FInner.TryAcquire(aPtr);
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

procedure TSlabPoolConcurrent.Release(aPtr: Pointer);
begin
  FLock.Acquire;
  try
    FInner.Release(aPtr);
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

function TSlabPoolConcurrent.GetMem(aSize: SizeUInt): Pointer;
begin
  FLock.Acquire;
  try
    Result := FInner.GetMem(aSize);
  finally
    FLock.Release;
  end;
end;

function TSlabPoolConcurrent.AllocMem(aSize: SizeUInt): Pointer;
begin
  FLock.Acquire;
  try
    Result := FInner.AllocMem(aSize);
  finally
    FLock.Release;
  end;
end;

function TSlabPoolConcurrent.ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
begin
  FLock.Acquire;
  try
    Result := FInner.ReallocMem(aDst, aSize);
  finally
    FLock.Release;
  end;
end;

procedure TSlabPoolConcurrent.FreeMem(aDst: Pointer);
begin
  FLock.Acquire;
  try
    FInner.FreeMem(aDst);
  finally
    FLock.Release;
  end;
end;

function TSlabPoolConcurrent.Allocate(const ASize: SizeUInt): Pointer;
begin
  Result := GetMem(ASize);
end;

function TSlabPoolConcurrent.Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
begin
  Result := ReallocMem(APtr, ANewSize);
end;

procedure TSlabPoolConcurrent.Deallocate(const APtr: Pointer);
begin
  FreeMem(APtr);
end;

function TSlabPoolConcurrent.AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
begin
  FLock.Acquire;
  try
    Result := FInner.AllocAligned(aSize, aAlignment);
  finally
    FLock.Release;
  end;
end;

procedure TSlabPoolConcurrent.FreeAligned(aPtr: Pointer);
begin
  FLock.Acquire;
  try
    FInner.FreeAligned(aPtr);
  finally
    FLock.Release;
  end;
end;

function TSlabPoolConcurrent.Traits: TAllocatorTraits;
begin
  Result := FInner.Traits;
  Result.ThreadSafe := True;
end;

function TSlabPoolConcurrent.Alloc(aSize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(aSize);
end;

procedure TSlabPoolConcurrent.Free(aPtr: Pointer); inline;
begin
  FreeMem(aPtr);
end;

procedure TSlabPoolConcurrent.ReleasePtr(aPtr: Pointer); inline;
begin
  FreeMem(aPtr);
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

function TSlabPoolConcurrent.Owns(aPtr: Pointer): Boolean;
begin
  FLock.Acquire;
  try
    Result := FInner.Owns(aPtr);
  finally
    FLock.Release;
  end;
end;

function TSlabPoolConcurrent.MemSizeOf(aPtr: Pointer): SizeUInt;
begin
  FLock.Acquire;
  try
    Result := FInner.MemSizeOf(aPtr);
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
