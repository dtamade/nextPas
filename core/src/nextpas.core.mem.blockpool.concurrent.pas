unit nextpas.core.mem.blockpool.concurrent;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base.utils,
  nextpas.core.mem.base,
  nextpas.core.mem.blockpool,
  nextpas.core.mem.mutex,
  nextpas.core.mem.error;

type
  {**
   * TBlockPoolConcurrent
   *
   * @desc Thread-safe wrapper for IBlockPool (mutex-protected).
   *}
  TBlockPoolConcurrent = class(TInterfacedObject, IBlockPool, IBlockPoolBatch)
  private
    {**
     * Lock ordering: TBlockPoolConcurrent uses a single mutex (FLock).
     * No nesting with other locks — safe to call from any context.
     * Lockless reads: BlockSize, Capacity (immutable after construction).
     * Locked reads: Available, InUse, Acquire, Release, Reset.
     *
     * 锁顺序：单锁（FLock），不与其他锁嵌套。
     * 不可变字段（BlockSize/Capacity）无需加锁。
     * 可变状态（Available/InUse/Acquire/Release/Reset）均在 FLock 下操作。
     *}
    FInner: IBlockPool;
    FLock: TMemMutex;
  public
    {** 使用已有 IBlockPool 实例创建线程安全包装器 *
    constructor Create(aInner: IBlockPool); overload;
    {** 创建线程安全块池，指定块大小、容量和对齐 *
    constructor Create(aBlockSize, aCapacity: SizeUInt; aAlignment: SizeUInt = DEFAULT_ALIGNMENT); overload;
    {** 销毁包装器，释放互斥锁 *
    destructor Destroy; override;

    { IBlockPool }
    {** 从池中获取一个块，已加锁 *
    function Acquire: Pointer;
    {** 尝试从池中获取一个块，池耗尽时返回 False *
    function TryAcquire(out aPtr: Pointer): Boolean;
    {** 归还一个块到池中 *
    procedure Release(aPtr: Pointer);
    {** 重置池，归还所有已分配的块 *
    procedure Reset;
    {** 返回每个块的字节大小（不可变） *
    function BlockSize: SizeUInt;
    {** 返回池的最大块容量（不可变） *
    function Capacity: SizeUInt;
    {** 返回当前空闲块数量 *
    function Available: SizeUInt;
    {** 返回当前已使用块数量 *
    function InUse: SizeUInt;

    { IBlockPoolBatch }
    {** 批量获取块，返回实际获取数量 *
    function AcquireN(out aPtrs: array of Pointer; aCount: Integer): Integer;
    {** 批量归还块 *
    procedure ReleaseN(const aPtrs: array of Pointer; aCount: Integer);

    property Inner: IBlockPool read FInner;
  end;

implementation

{ TBlockPoolConcurrent }

constructor TBlockPoolConcurrent.Create(aInner: IBlockPool);
begin
  inherited Create;
  if aInner = nil then
    raise EAllocError.Create(aeInvalidLayout, 'TBlockPoolConcurrent: inner pool cannot be nil');
  FLock.Init;
  FInner := aInner;
end;

constructor TBlockPoolConcurrent.Create(aBlockSize, aCapacity: SizeUInt; aAlignment: SizeUInt);
begin
  Create(TBlockPool.Create(aBlockSize, aCapacity, aAlignment));
end;

destructor TBlockPoolConcurrent.Destroy;
begin
  FLock.Acquire;
  try
    FInner := nil;
  finally
    FLock.Release;
  end;
  FLock.Done;
  inherited Destroy;
end;

function TBlockPoolConcurrent.Acquire: Pointer;
begin
  FLock.Acquire;
  try
    Result := FInner.Acquire;
  finally
    FLock.Release;
  end;
end;

function TBlockPoolConcurrent.TryAcquire(out aPtr: Pointer): Boolean;
begin
  FLock.Acquire;
  try
    Result := FInner.TryAcquire(aPtr);
  finally
    FLock.Release;
  end;
end;

function TBlockPoolConcurrent.AcquireN(out aPtrs: array of Pointer; aCount: Integer): Integer;
var
  LBatch: IBlockPoolBatch;
  LIdx: Integer;
  LPtr: Pointer;
begin
  Result := 0;
  if aCount <= 0 then Exit(0);
  FLock.Acquire;
  try
    if aCount > Length(aPtrs) then
      aCount := Length(aPtrs);
    if Supports(FInner, IBlockPoolBatch, LBatch) then
      Exit(LBatch.AcquireN(aPtrs, aCount));
    for LIdx := 0 to aCount - 1 do
    begin
      if LIdx > High(aPtrs) then
        Break;
      LPtr := FInner.Acquire;
      if LPtr = nil then
        Break;
      aPtrs[LIdx] := LPtr;
      Inc(Result);
    end;
  finally
    FLock.Release;
  end;
end;

procedure TBlockPoolConcurrent.ReleaseN(const aPtrs: array of Pointer; aCount: Integer);
var
  LBatch: IBlockPoolBatch;
  LIdx: Integer;
begin
  if aCount <= 0 then Exit;
  FLock.Acquire;
  try
    if aCount > Length(aPtrs) then
      aCount := Length(aPtrs);
    if Supports(FInner, IBlockPoolBatch, LBatch) then
    begin
      LBatch.ReleaseN(aPtrs, aCount);
      Exit;
    end;
    for LIdx := 0 to aCount - 1 do
    begin
      if LIdx > High(aPtrs) then
        Break;
      FInner.Release(aPtrs[LIdx]);
    end;
  finally
    FLock.Release;
  end;
end;

procedure TBlockPoolConcurrent.Release(aPtr: Pointer);
begin
  FLock.Acquire;
  try
    FInner.Release(aPtr);
  finally
    FLock.Release;
  end;
end;

procedure TBlockPoolConcurrent.Reset;
begin
  FLock.Acquire;
  try
    FInner.Reset;
  finally
    FLock.Release;
  end;
end;

function TBlockPoolConcurrent.BlockSize: SizeUInt;
begin
  Result := FInner.BlockSize;
end;

function TBlockPoolConcurrent.Capacity: SizeUInt;
begin
  Result := FInner.Capacity;
end;

function TBlockPoolConcurrent.Available: SizeUInt;
begin
  FLock.Acquire;
  try
    Result := FInner.Available;
  finally
    FLock.Release;
  end;
end;

function TBlockPoolConcurrent.InUse: SizeUInt;
begin
  FLock.Acquire;
  try
    Result := FInner.InUse;
  finally
    FLock.Release;
  end;
end;

end.
