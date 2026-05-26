unit nextpas.core.mem.pool.fixed.concurrent;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.sync,
  nextpas.core.mem.pool.base,      // IPool
  nextpas.core.mem.pool.fixed,     // TFixedPool
  nextpas.core.mem.allocator;      // IAllocator + GetRtlAllocator

// 说明（原型）：
// - 并发包装器：以临界区保护内部固定块池，提供线程安全的 Acquire/Release
// - 目标：最小可用原型，便于上层并发场景落地；性能优化与无锁/线程本地策略在后续迭代
// - 注意：Reset/Destroy 等操作也受保护；调用端应避免与其它线程并发重置/销毁

type
  TFixedPoolConcurrent = class(TInterfacedObject, IPool)
  private
    FInner: TFixedPool;
    FLock: IMutex;
  private
    function GetBlockSize: SizeUInt; inline;
    function GetCapacity: Integer; inline;
    function GetAllocatedCount: Integer; inline;
  public
    constructor Create(aBlockSize: SizeUInt; aCapacity: Integer; aAlignment: SizeUInt = 0; aAllocator: IAllocator = nil); overload;
    constructor Create(const aConfig: TFixedPoolConfig); overload;
    destructor Destroy; override;
  public
    // IPool
    function Acquire(out aUnit: Pointer): Boolean; inline;
    function TryAcquire(out aUnit: Pointer): Boolean; inline;
    function AcquireN(out aUnits: array of Pointer; aCount: Integer): Integer; inline;
    procedure Release(aUnit: Pointer); inline;
    procedure ReleaseN(const aUnits: array of Pointer; aCount: Integer); inline;

    // 便捷转发（非接口）
    function Alloc: Pointer; inline;
    function TryAlloc(out aPtr: Pointer): Boolean; inline;
    procedure ReleasePtr(aPtr: Pointer); inline;
    procedure Reset; inline;

    // 只读属性
    property BlockSize: SizeUInt read GetBlockSize;
    property Capacity: Integer read GetCapacity;
    property AllocatedCount: Integer read GetAllocatedCount;
  end;

implementation

{ TFixedPoolConcurrent }

constructor TFixedPoolConcurrent.Create(aBlockSize: SizeUInt; aCapacity: Integer; aAlignment: SizeUInt; aAllocator: IAllocator);
begin
  inherited Create;
  FLock := Mutex;
  FInner := TFixedPool.Create(aBlockSize, aCapacity, aAlignment, aAllocator);
end;

constructor TFixedPoolConcurrent.Create(const aConfig: TFixedPoolConfig);
begin
  inherited Create;
  FLock := Mutex;
  FInner := TFixedPool.Create(aConfig);
end;

destructor TFixedPoolConcurrent.Destroy;
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

function TFixedPoolConcurrent.Acquire(out aUnit: Pointer): Boolean;
begin
  FLock.Acquire;
  try
    Result := FInner.Acquire(aUnit);
  finally
    FLock.Release;
  end;
end;

function TFixedPoolConcurrent.TryAcquire(out aUnit: Pointer): Boolean;
begin
  FLock.Acquire;
  try
    Result := FInner.TryAcquire(aUnit);
  finally
    FLock.Release;
  end;
end;

function TFixedPoolConcurrent.AcquireN(out aUnits: array of Pointer; aCount: Integer): Integer;
begin
  FLock.Acquire;
  try
    Result := FInner.AcquireN(aUnits, aCount);
  finally
    FLock.Release;
  end;
end;

procedure TFixedPoolConcurrent.Release(aUnit: Pointer);
begin
  FLock.Acquire;
  try
    FInner.Release(aUnit);
  finally
    FLock.Release;
  end;
end;

procedure TFixedPoolConcurrent.ReleaseN(const aUnits: array of Pointer; aCount: Integer);
begin
  FLock.Acquire;
  try
    FInner.ReleaseN(aUnits, aCount);
  finally
    FLock.Release;
  end;
end;

function TFixedPoolConcurrent.Alloc: Pointer;
begin
  FLock.Acquire;
  try
    Result := FInner.Alloc;
  finally
    FLock.Release;
  end;
end;

function TFixedPoolConcurrent.TryAlloc(out aPtr: Pointer): Boolean;
begin
  FLock.Acquire;
  try
    Result := FInner.TryAlloc(aPtr);
  finally
    FLock.Release;
  end;
end;

procedure TFixedPoolConcurrent.ReleasePtr(aPtr: Pointer);
begin
  FLock.Acquire;
  try
    FInner.ReleasePtr(aPtr);
  finally
    FLock.Release;
  end;
end;

procedure TFixedPoolConcurrent.Reset;
begin
  FLock.Acquire;
  try
    FInner.Reset;
  finally
    FLock.Release;
  end;
end;

function TFixedPoolConcurrent.GetBlockSize: SizeUInt;
begin
  Result := FInner.BlockSize;
end;

function TFixedPoolConcurrent.GetCapacity: Integer;
begin
  Result := FInner.Capacity;
end;

function TFixedPoolConcurrent.GetAllocatedCount: Integer;
begin
  Result := FInner.AllocatedCount;
end;

end.
