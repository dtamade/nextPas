{**
 * nextpas.core.sync.pool — TSyncPool: 线程安全高性能对象池
 *
 * 架构: Thread-Local Cache (64 slots) + Global Shared Pool
 * 热路径 (~90%): TLS 数组栈 pop/push, 无锁无原子操作
 * 冷路径 (~10%): TMemMutex 保护的全局池, 批量转移减少争用
 *
 * @note 确定性析构: Destroy 收集所有 TLS 对象后统一销毁
 * @note 不使用 threadvar (FPC 泛型不兼容), 用 slot 数组 + ThreadID hash
 * @thread_safety Acquire/Release 可多线程并发调用
 * @warning 调用者必须确保所有使用者线程停止使用后才能调用 Destroy 或 Reset
 *}
unit nextpas.core.sync.pool;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic.types,
  nextpas.core.mem.pool,
  nextpas.core.mem.mutex,
  nextpas.core.platform.thread;

const
  SYNC_POOL_MAX_SLOTS = 64;
  SYNC_POOL_DEFAULT_MAX_PER_THREAD = 32;
  SYNC_POOL_DEFAULT_BATCH_SIZE = 16;
  SYNC_POOL_NO_SLOT = -1;  { fallback: 无可用 TLS slot, 直接走全局池 }

type
  TPoolStats = record
    TotalCreated: SizeUInt;
    Acquired: SizeUInt;
    InGlobalPool: SizeUInt;
    CacheHits: SizeUInt;
    CacheMisses: SizeUInt;
    BatchTransfers: SizeUInt;
  end;

  { 对象创建/重置/销毁回调 }
  TPoolFactory = function: TObject;
  TPoolReset = procedure(AObj: TObject);
  TPoolDestroy = procedure(AObj: TObject);

  TSyncPoolConfig = record
    Factory: TPoolFactory;
    OnReset: TPoolReset;
    OnDestroy: TPoolDestroy;
    MaxPerThread: SizeUInt;
    MaxGlobal: SizeUInt;
    BatchSize: SizeUInt;
  end;

function DefaultSyncPoolConfig(AFactory: TPoolFactory): TSyncPoolConfig;

type
  TSyncPool = class(TInterfacedObject, IPool)
  private
    type
      TCacheSlot = record
        FOwnerTID: TAtomicISize;  { CAS 管理所有权, 0 = 空闲 }
        FItems: array of TObject;
        FTop: SizeInt;
        FMaxSize: SizeUInt;
        FCacheHits: SizeUInt;
        FCacheMisses: SizeUInt;
      end;
    var
      FSlots: array[0..SYNC_POOL_MAX_SLOTS - 1] of TCacheSlot;
      FGlobalLock: TMemMutex;
      FGlobalItems: array of TObject;
      FGlobalTop: SizeInt;
      FGlobalMaxSize: SizeUInt;
      FTotalCreated: TAtomicISize;
      FAcquired: SizeUInt;
      FBatchTransfers: SizeUInt;
      FFactory: TPoolFactory;
      FOnReset: TPoolReset;
      FOnDestroy: TPoolDestroy;
      FMaxPerThread: SizeUInt;
      FBatchSize: SizeUInt;

    function FindSlot: SizeInt;
    procedure SlotPush(ASlot: SizeInt; AItem: TObject);
    function SlotPop(ASlot: SizeInt): TObject;
    procedure SlotFillFromGlobal(ASlot: SizeInt);
    procedure SlotDrainToGlobal(ASlot: SizeInt);
    function GlobalCreate: TObject;

  public
    constructor Create(const AConfig: TSyncPoolConfig);
    destructor Destroy; override;

    { IPool }
    function Acquire(out APtr: Pointer): Boolean;
    function TryAcquire(out APtr: Pointer): Boolean;
    function AcquireN(out APtrs: array of Pointer; ACount: Integer): Integer;
    procedure Release(APtr: Pointer);
    procedure ReleaseN(const APtrs: array of Pointer; ACount: Integer);
    procedure Reset;

    { 扩展查询 }
    function GetPoolStats: TPoolStats;
    property Stats: TPoolStats read GetPoolStats;
  end;

implementation

function DefaultSyncPoolConfig(AFactory: TPoolFactory): TSyncPoolConfig;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Factory := AFactory;
  Result.MaxPerThread := SYNC_POOL_DEFAULT_MAX_PER_THREAD;
  Result.BatchSize := SYNC_POOL_DEFAULT_BATCH_SIZE;
end;

{ ===== TSyncPool ===== }

constructor TSyncPool.Create(const AConfig: TSyncPoolConfig);
var
  I: SizeInt;
begin
  inherited Create;
  FFactory := AConfig.Factory;
  FOnReset := AConfig.OnReset;
  FOnDestroy := AConfig.OnDestroy;
  FMaxPerThread := AConfig.MaxPerThread;
  if FMaxPerThread = 0 then
    FMaxPerThread := SYNC_POOL_DEFAULT_MAX_PER_THREAD;
  FBatchSize := AConfig.BatchSize;
  if FBatchSize = 0 then
    FBatchSize := FMaxPerThread div 2;
  if FBatchSize = 0 then
    FBatchSize := 1;
  FGlobalMaxSize := AConfig.MaxGlobal;

  FGlobalLock.Init;
  FGlobalTop := -1;
  FTotalCreated := TAtomicISize.Create(0);
  SetLength(FGlobalItems, 0);

  for I := 0 to SYNC_POOL_MAX_SLOTS - 1 do
  begin
    FSlots[I].FOwnerTID := TAtomicISize.Create(0);
    FSlots[I].FTop := -1;
    FSlots[I].FMaxSize := FMaxPerThread;
    SetLength(FSlots[I].FItems, FMaxPerThread);
  end;
end;

destructor TSyncPool.Destroy;
var
  I, J: SizeInt;
  LSlot: ^TCacheSlot;
begin
  { 收集所有 TLS 中的对象到全局 }
  for I := 0 to SYNC_POOL_MAX_SLOTS - 1 do
  begin
    LSlot := @FSlots[I];
    for J := 0 to LSlot^.FTop do
    begin
      if Assigned(FOnDestroy) then
        FOnDestroy(LSlot^.FItems[J]);
      LSlot^.FItems[J].Free;
      LSlot^.FItems[J] := nil;
    end;
    LSlot^.FTop := -1;
    SetLength(LSlot^.FItems, 0);
  end;

  { 释放全局池中剩余对象 }
  FGlobalLock.Acquire;
  try
    for J := 0 to FGlobalTop do
    begin
      if Assigned(FOnDestroy) then
        FOnDestroy(FGlobalItems[J]);
      FGlobalItems[J].Free;
      FGlobalItems[J] := nil;
    end;
    FGlobalTop := -1;
    SetLength(FGlobalItems, 0);
  finally
    FGlobalLock.Release;
  end;

  FGlobalLock.Done;
  inherited Destroy;
end;

function TSyncPool.FindSlot: SizeInt;
var
  LThreadID: PtrInt;
  LIdx: SizeInt;
  LTry: SizeInt;
  LExpected: PtrInt;
begin
  LThreadID := PtrInt(GetCurrentThreadId);
  if LThreadID = 0 then
    LThreadID := 1; { 避免 0 = 空闲 }

  { 快速路径: 已注册的 slot }
  LIdx := SizeInt(LThreadID mod SYNC_POOL_MAX_SLOTS);
  if FSlots[LIdx].FOwnerTID.Load = LThreadID then
  begin
    Result := LIdx;
    Exit;
  end;

  { CAS 注册: 从 hash 位置开始线性探测 }
  for LTry := 0 to SYNC_POOL_MAX_SLOTS - 1 do
  begin
    if FSlots[LIdx].FOwnerTID.Load = LThreadID then
    begin
      Result := LIdx;
      Exit;
    end;
    LExpected := 0;
    if FSlots[LIdx].FOwnerTID.CompareExchangeStrong(LExpected, LThreadID) then
    begin
      Result := LIdx;
      Exit;
    end;
    LIdx := (LIdx + 1) mod SYNC_POOL_MAX_SLOTS;
  end;

  { 所有 slot 都被占用, 无 TLS — 直接走全局池 }
  Result := SYNC_POOL_NO_SLOT;
end;

procedure TSyncPool.SlotPush(ASlot: SizeInt; AItem: TObject);
begin
  Inc(FSlots[ASlot].FTop);
  FSlots[ASlot].FItems[FSlots[ASlot].FTop] := AItem;
end;

function TSyncPool.SlotPop(ASlot: SizeInt): TObject;
begin
  Result := FSlots[ASlot].FItems[FSlots[ASlot].FTop];
  FSlots[ASlot].FItems[FSlots[ASlot].FTop] := nil;
  Dec(FSlots[ASlot].FTop);
end;

procedure TSyncPool.SlotFillFromGlobal(ASlot: SizeInt);
var
  LCount, LI: SizeInt;
begin
  FGlobalLock.Acquire;
  try
    LCount := FBatchSize;
    if LCount > SizeUInt(FGlobalTop + 1) then
      LCount := FGlobalTop + 1;
    if LCount > SizeInt(FSlots[ASlot].FMaxSize) - (FSlots[ASlot].FTop + 1) then
      LCount := SizeInt(FSlots[ASlot].FMaxSize) - (FSlots[ASlot].FTop + 1);
    if LCount <= 0 then
      Exit;

    for LI := 0 to LCount - 1 do
    begin
      SlotPush(ASlot, FGlobalItems[FGlobalTop]);
      FGlobalItems[FGlobalTop] := nil;
      Dec(FGlobalTop);
    end;
    Inc(FBatchTransfers);
  finally
    FGlobalLock.Release;
  end;
end;

procedure TSyncPool.SlotDrainToGlobal(ASlot: SizeInt);
var
  LCount, LI: SizeInt;
begin
  FGlobalLock.Acquire;
  try
    LCount := FBatchSize;
    if LCount > FSlots[ASlot].FTop + 1 then
      LCount := FSlots[ASlot].FTop + 1;
    if (FGlobalMaxSize > 0) and
       (SizeUInt(FGlobalTop + 1 + LCount) > FGlobalMaxSize) then
      LCount := SizeInt(FGlobalMaxSize) - (FGlobalTop + 1);
    if LCount <= 0 then
    begin
      { 全局池已满, 丢弃多余的 }
      for LI := 1 to FBatchSize do
      begin
        if FSlots[ASlot].FTop < 0 then
          Break;
        { 先读引用, 再 Pop 清 slot, 最后 Free }
        if Assigned(FOnDestroy) then
          FOnDestroy(FSlots[ASlot].FItems[FSlots[ASlot].FTop]);
        SlotPop(ASlot).Free;
        FTotalCreated.FetchSub(1);
      end;
      Exit;
    end;

    { 扩展全局池 }
    if Length(FGlobalItems) < FGlobalTop + 1 + LCount then
      SetLength(FGlobalItems, (FGlobalTop + 1 + LCount) * 2);

    for LI := 0 to LCount - 1 do
    begin
      Inc(FGlobalTop);
      FGlobalItems[FGlobalTop] := SlotPop(ASlot);
    end;
    Inc(FBatchTransfers);
  finally
    FGlobalLock.Release;
  end;
end;

function TSyncPool.GlobalCreate: TObject;
begin
  if (FGlobalMaxSize > 0) and
     (SizeUInt(FTotalCreated.Load) >= FGlobalMaxSize) then
  begin
    Result := nil;
    Exit;
  end;
  Result := FFactory();
  FTotalCreated.FetchAdd(1);
end;

{ IPool }

function TSyncPool.Acquire(out APtr: Pointer): Boolean;
var
  LSlot: SizeInt;
  LItem: TObject;
begin
  LSlot := FindSlot;

  { 有 TLS slot 时走快速路径 }
  if LSlot <> SYNC_POOL_NO_SLOT then
  begin
    { TLS 命中 }
    if FSlots[LSlot].FTop >= 0 then
    begin
      LItem := SlotPop(LSlot);
      Inc(FSlots[LSlot].FCacheHits);
      Inc(FAcquired);
      APtr := Pointer(LItem);
      Result := True;
      Exit;
    end;
    { TLS 空, 从全局池批量补充 }
    Inc(FSlots[LSlot].FCacheMisses);
    SlotFillFromGlobal(LSlot);
    if FSlots[LSlot].FTop >= 0 then
    begin
      LItem := SlotPop(LSlot);
      Inc(FAcquired);
      APtr := Pointer(LItem);
      Result := True;
      Exit;
    end;
  end;

  { 无 TLS 或 TLS+全局池都空, 创建新对象 }
  LItem := GlobalCreate;
  if LItem <> nil then
  begin
    Inc(FAcquired);
    APtr := Pointer(LItem);
    Result := True;
  end
  else
  begin
    APtr := nil;
    Result := False;
  end;
end;

function TSyncPool.TryAcquire(out APtr: Pointer): Boolean;
begin
  Result := Acquire(APtr);
end;

function TSyncPool.AcquireN(out APtrs: array of Pointer; ACount: Integer): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to ACount - 1 do
  begin
    if not Acquire(APtrs[I]) then
      Break;
    Inc(Result);
  end;
end;

procedure TSyncPool.Release(APtr: Pointer);
var
  LSlot: SizeInt;
  LItem: TObject;
begin
  LItem := TObject(APtr);
  if LItem = nil then
    Exit;

  { 重置回调 }
  if Assigned(FOnReset) then
    FOnReset(LItem);

  LSlot := FindSlot;

  { 无 TLS slot, 直接放回全局池 }
  if LSlot = SYNC_POOL_NO_SLOT then
  begin
    FGlobalLock.Acquire;
    try
      if Length(FGlobalItems) < FGlobalTop + 2 then
        SetLength(FGlobalItems, (FGlobalTop + 2) * 2);
      Inc(FGlobalTop);
      FGlobalItems[FGlobalTop] := LItem;
    finally
      FGlobalLock.Release;
    end;
    Dec(FAcquired);
    Exit;
  end;

  { 快速路径: TLS 未满 }
  if FSlots[LSlot].FTop < SizeInt(FSlots[LSlot].FMaxSize) - 1 then
  begin
    SlotPush(LSlot, LItem);
    Dec(FAcquired);
    Exit;
  end;

  { 冷路径: TLS 已满, 批量转移到全局 }
  SlotDrainToGlobal(LSlot);
  SlotPush(LSlot, LItem);
  Dec(FAcquired);
end;

procedure TSyncPool.ReleaseN(const APtrs: array of Pointer; ACount: Integer);
var
  I: Integer;
begin
  for I := 0 to ACount - 1 do
    Release(APtrs[I]);
end;

procedure TSyncPool.Reset;
var
  I, J: SizeInt;
begin
  { 收集所有 TLS 对象到全局, 然后销毁 }
  for I := 0 to SYNC_POOL_MAX_SLOTS - 1 do
  begin
    for J := 0 to FSlots[I].FTop do
    begin
      if Assigned(FOnDestroy) then
        FOnDestroy(FSlots[I].FItems[J]);
      FSlots[I].FItems[J].Free;
      FSlots[I].FItems[J] := nil;
    end;
    FSlots[I].FTop := -1;
    FSlots[I].FCacheHits := 0;
    FSlots[I].FCacheMisses := 0;
  end;

  FGlobalLock.Acquire;
  try
    for J := 0 to FGlobalTop do
    begin
      if Assigned(FOnDestroy) then
        FOnDestroy(FGlobalItems[J]);
      FGlobalItems[J].Free;
      FGlobalItems[J] := nil;
    end;
    FGlobalTop := -1;
    FTotalCreated.Store(0);
    FAcquired := 0;
    FBatchTransfers := 0;
  finally
    FGlobalLock.Release;
  end;
end;

function TSyncPool.GetPoolStats: TPoolStats;
var
  I: SizeInt;
begin
  FillChar(Result, SizeOf(Result), 0);
  for I := 0 to SYNC_POOL_MAX_SLOTS - 1 do
  begin
    Result.CacheHits := Result.CacheHits + FSlots[I].FCacheHits;
    Result.CacheMisses := Result.CacheMisses + FSlots[I].FCacheMisses;
    Result.InGlobalPool := Result.InGlobalPool + SizeUInt(FSlots[I].FTop + 1);
  end;
  FGlobalLock.Acquire;
  try
    Result.InGlobalPool := Result.InGlobalPool + SizeUInt(FGlobalTop + 1);
    Result.TotalCreated := SizeUInt(FTotalCreated.Load);
    Result.Acquired := FAcquired;
    Result.BatchTransfers := FBatchTransfers;
  finally
    FGlobalLock.Release;
  end;
end;

end.
