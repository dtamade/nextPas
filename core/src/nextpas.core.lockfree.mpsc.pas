unit nextpas.core.lockfree.mpsc;

{$I nextpas.core.settings.inc}

interface

{ Preferred atomics: atomic_* + mo_* (Go/Rust parity / Q2). }

uses
  nextpas.core.atomic.core,
  nextpas.core.lockfree.base;

type
  {**
   * 多生产者单消费者无界队列（MPSC Queue）。
   *
   * @constraints
   *   - **严格单消费者**：TryDequeue / DequeueWait / DequeueTimeout 只能由一个线程调用。
   *     多线程同时消费会导致数据竞争和 use-after-free。
   *   - Enqueue 可由多个线程并发调用。
   *   - T 必须是 unmanaged 类型。
   *   - Close 后 TryEnqueue 返回 False；Enqueue 抛出 EInvalidOperationError（与 Channel.Send 对齐）。
   *   - 生命周期：Close → join producers/waiters → Free。Destroy 会 Close+drain，但不能替代 join。
   *
   * @safety
   *   FTail 的非原子读取是刻意设计，依赖 single-consumer contract 保证安全。
   *}
  generic TMpscQueueImpl<T> = class
  private
    type
      PNode = ^TNode;
      TNode = record
        Value: T;
        Next: PNode;
      end;
  private
    FHead: PNode;
    FTail: PNode;
    FStub: TNode;
    FConstructed: Boolean;
    FClosed: Int32;
    FCount: Int64;
    FDataEpoch: Int32;
    FDataWaiters: Int32;
    function LoadNode(var ANode: PNode; const AOrder: memory_order_t): PNode; inline;
    procedure StoreNode(var ANode: PNode; const AValue: PNode; const AOrder: memory_order_t); inline;
    function ExchangeNode(var ANode: PNode; const AValue: PNode; const AOrder: memory_order_t): PNode; inline;
    procedure PublishNode(const AValue: T);
  public
    constructor Create;
    destructor Destroy; override;
    {** @desc 入队；已关闭时抛出 EInvalidOperationError（与 Channel.Send 对齐） }
    procedure Enqueue(const AValue: T);
    {** @desc 非阻塞入队；已关闭时返回 False }
    function TryEnqueue(const AValue: T): Boolean;
    {** @desc 非阻塞入队并返回失败原因；无界 publish 失败即为 closed；成功 AError=lfteNone }
    function TryEnqueueEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
    {** @desc 非阻塞出队（**严格单消费者**：只能由一个线程调用） }
    function TryDequeue(out AValue: T): Boolean;
    {** @desc 非阻塞出队并返回失败原因（empty vs closed-empty）；成功 AError=lfteNone }
    function TryDequeueEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
    {** @desc 阻塞出队（**严格单消费者**：只能由一个线程调用） }
    function DequeueWait(out AValue: T): Boolean;
    {** @desc 带超时出队（**严格单消费者**：只能由一个线程调用） }
    function DequeueTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
    function Drain(const AMaxCount: PtrUInt = High(PtrUInt)): PtrUInt;
    procedure Close;
    function IsClosed: Boolean; inline;
    function IsEmpty: Boolean; inline;
    {** @desc 近似元素计数（原子快照，非线性化） }
    function ApproxCount: PtrUInt;
  end;

  generic TMpscQueue<T> = class(specialize TMpscQueueImpl<T>)
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.wait,
  nextpas.core.time.base;

function TMpscQueueImpl.LoadNode(var ANode: PNode; const AOrder: memory_order_t): PNode;
begin
  Result := PNode(atomic_load(PPointer(@ANode)^, AOrder));
end;

procedure TMpscQueueImpl.StoreNode(var ANode: PNode; const AValue: PNode; const AOrder: memory_order_t);
begin
  atomic_store(PPointer(@ANode)^, Pointer(AValue), AOrder);
end;

function TMpscQueueImpl.ExchangeNode(var ANode: PNode; const AValue: PNode; const AOrder: memory_order_t): PNode;
begin
  Result := PNode(atomic_exchange(PPointer(@ANode)^, Pointer(AValue), AOrder));
end;

constructor TMpscQueueImpl.Create;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TMpscQueue: T must be unmanaged');
  inherited Create;
  FStub.Next := nil;
  FHead := @FStub;
  FTail := @FStub;
  FClosed := 0;
  FCount := 0;
  FDataEpoch := 0;
  FDataWaiters := 0;
  FConstructed := True;
end;

destructor TMpscQueueImpl.Destroy;
var
  LV: T;
begin
  if not FConstructed then
  begin
    inherited;
    Exit;
  end;
  { Wake any blocked single-consumer DequeueWait/Timeout, then drain remaining nodes.
    Callers must still stop and join producers before Free; Close alone is not a join barrier. }
  Close;
  while TryDequeue(LV) do;
  inherited;
end;

procedure TMpscQueueImpl.PublishNode(const AValue: T);
var
  LNode, LPrev: PNode;
begin
  New(LNode);
  LNode^.Value := AValue;
  LNode^.Next := nil;
  LPrev := ExchangeNode(FHead, LNode, mo_acq_rel);
  atomic_fetch_add_64(FCount, 1, mo_relaxed);
  StoreNode(LPrev^.Next, LNode, mo_release);
  { Fast path: only notify if there are waiters }
  if atomic_load(FDataWaiters, mo_relaxed) > 0 then
    LockFreeNotifyData(@FDataEpoch, @FDataWaiters);
end;

procedure TMpscQueueImpl.Enqueue(const AValue: T);
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    raise EInvalidOperationError.Create('TMpscQueue: Enqueue on closed queue');
  PublishNode(AValue);
end;

function TMpscQueueImpl.TryEnqueue(const AValue: T): Boolean;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(False);
  PublishNode(AValue);
  Result := True;
end;

function TMpscQueueImpl.TryEnqueueEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
begin
  if TryEnqueue(AValue) then
  begin
    AError := lfteNone;
    Exit(True);
  end;
  { Unbounded: False is closed under ClosedPublishPolicy. }
  if IsClosed then
    AError := lfteClosed
  else
    AError := lfteFull;
  Result := False;
end;

function TMpscQueueImpl.TryDequeue(out AValue: T): Boolean;
var
  LTail, LNext, LPrev: PNode;
begin
  LTail := FTail;
  LNext := LoadNode(LTail^.Next, mo_acquire);
  if LTail = @FStub then
  begin
    if LNext = nil then
      Exit(False);
    FTail := LNext;
    LTail := LNext;
    LNext := LoadNode(LTail^.Next, mo_acquire);
  end;
  if LNext <> nil then
  begin
    FTail := LNext;
    AValue := LTail^.Value;
    Dispose(LTail);
    atomic_fetch_sub_64(FCount, 1, mo_relaxed);
    Result := True;
    Exit;
  end;
  if LTail <> LoadNode(FHead, mo_acquire) then
    Exit(False);
  FStub.Next := nil;
  LPrev := ExchangeNode(FHead, @FStub, mo_acq_rel);
  StoreNode(LPrev^.Next, @FStub, mo_release);
  LNext := LoadNode(LTail^.Next, mo_acquire);
  if LNext <> nil then
  begin
    FTail := LNext;
    AValue := LTail^.Value;
    Dispose(LTail);
    atomic_fetch_sub_64(FCount, 1, mo_relaxed);
    Result := True;
    Exit;
  end;
  Result := False;
end;

function TMpscQueueImpl.TryDequeueEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
begin
  if TryDequeue(AValue) then
  begin
    AError := lfteNone;
    Exit(True);
  end;
  if IsClosed then
    AError := lfteClosed
  else
    AError := lfteEmpty;
  Result := False;
end;

function TMpscQueueImpl.DequeueWait(out AValue: T): Boolean;
var
  LEpoch: Int32;
begin
  if TryDequeue(AValue) then
    Exit(True);
  while True do
  begin
    LEpoch := atomic_load(FDataEpoch, mo_acquire);
    if TryDequeue(AValue) then
      Exit(True);
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(TryDequeue(AValue));
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LOCKFREE_WAIT_TIMEOUT_NS);
  end;
end;

function TMpscQueueImpl.DequeueTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
var
  LEpoch: Int32;
  LStart: TInstant;
  LRemaining: Int64;
begin
  if TryDequeue(AValue) then
    Exit(True);
  LStart := TInstant.Now;
  while True do
  begin
    LRemaining := ATimeoutNs - LStart.Elapsed.AsNanoseconds;
    if LRemaining <= 0 then
      Exit(TryDequeue(AValue));
    LEpoch := atomic_load(FDataEpoch, mo_acquire);
    if TryDequeue(AValue) then
      Exit(True);
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(TryDequeue(AValue));
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LRemaining);
  end;
end;

function TMpscQueueImpl.Drain(const AMaxCount: PtrUInt): PtrUInt;
var
  LValue: T;
  LCount: PtrUInt;
begin
  LCount := 0;
  while LCount < AMaxCount do
  begin
    if not TryDequeue(LValue) then
      Break;
    Inc(LCount);
  end;
  Result := LCount;
end;

procedure TMpscQueueImpl.Close;
begin
  atomic_store(FClosed, 1, mo_release);
  LockFreeWakeAll(@FDataEpoch);
end;

function TMpscQueueImpl.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

function TMpscQueueImpl.IsEmpty: Boolean; inline;
var
  LTail, LNext: PNode;
begin
  LTail := FTail;
  LNext := LoadNode(LTail^.Next, mo_acquire);
  if LTail = @FStub then
    Result := LNext = nil
  else
    Result := False;
end;

function TMpscQueueImpl.ApproxCount: PtrUInt;
var
  LCount: Int64;
begin
  LCount := atomic_load_64(FCount, mo_relaxed);
  if LCount > 0 then
    Result := PtrUInt(LCount)
  else
    Result := 0;
end;

end.
