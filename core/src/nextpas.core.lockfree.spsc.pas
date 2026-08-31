unit nextpas.core.lockfree.spsc;
{**
 * @desc Lock-free Single-Producer Single-Consumer bounded queue.
 *
 * @details Sequence-based SPSC queue using cache-line padding:
 *   - Bounded capacity (power-of-2 required)
 *   - Non-blocking TryEnqueue/TryDequeue
 *   - Blocking EnqueueWait/DequeueWait with timeout variants
 *   - Batch operations for high-throughput scenarios
 *   - Close semantics with drain support
 *
 * @concurrency Thread-safe for single producer and single consumer:
 *   - Enqueue: only producer thread can call
 *   - Dequeue: only consumer thread can call
 *   - Close: safe to call from any thread
 *   - $IFDEF LOCKFREE_DEBUG: claim/check producer and consumer thread ids (audit F-005)
 *
 * @see Dmitry Vyukov SPSC queue — lock-free bounded queue
 * @see crossbeam (Rust) — similar SPSC implementation
 *
 * Preferred atomics: atomic_* + mo_* (Go/Rust parity / Q2).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  generic TSpscQueueImpl<T> = class
  private
    FSlots: array of T;
    FCapacity: PtrUInt;
    FMask: PtrUInt;
    {$PUSH} {$WARN 05029 OFF} // keep the read-mostly header off the hot lines
    FPadHeader: TCacheLinePad;
    {$POP}
    // Grouped by ACCESSING THREAD, not by direction: each line holds what
    // one thread writes per-op — its index, its published copy, its private
    // cache of the other side's progress, and the wait cell it bumps when
    // notifying.  The other thread touches these only on a cache refresh or
    // while blocking, so steady-state ops stay on the owner's line.
    // Producer-thread line
    FTail: Int64;
    FTailPublished: Int64;
    FHeadCache: Int64;
    FDataEpoch: Int32;
    FDataWaiters: Int32;
    {$PUSH} {$WARN 05029 OFF} // padding field for cache-line isolation
    FPadProducer: TCacheLinePad;
    {$POP}
    // Consumer-thread line (mirror of the producer line)
    FHead: Int64;
    FHeadPublished: Int64;
    FTailCache: Int64;
    FSpaceEpoch: Int32;
    FSpaceWaiters: Int32;
    {$PUSH} {$WARN 05029 OFF} // padding field for cache-line isolation
    FPadConsumer: TCacheLinePad;
    {$POP}
    // Cold shared fields
    FClosed: Int32;
    {$IFDEF LOCKFREE_DEBUG}
    FProducerThreadId: UInt64;
    FConsumerThreadId: UInt64;
    procedure DebugClaimProducer; inline;
    procedure DebugClaimConsumer; inline;
    {$ENDIF}
  public
    constructor Create(const ACapacity: PtrUInt);
    destructor Destroy; override;
    function TryEnqueue(const AValue: T): Boolean;
    {** @desc 非阻塞入队并返回失败原因（full vs closed）；成功 AError=lfteNone }
    function TryEnqueueEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
    function TryDequeue(out AValue: T): Boolean;
    {** @desc 非阻塞出队并返回失败原因（empty vs closed-empty）；成功 AError=lfteNone }
    function TryDequeueEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
    function EnqueueWait(const AValue: T): Boolean;
    function DequeueWait(out AValue: T): Boolean;
    function EnqueueTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
    function DequeueTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
    function EnqueueBatch(const AValues: array of T): PtrUInt;
    function DequeueBatch(out AValues: array of T; const AMaxCount: PtrUInt): PtrUInt;
    function Drain(const AMaxCount: PtrUInt = High(PtrUInt)): PtrUInt;
    procedure Close;
    function IsClosed: Boolean;
    function IsEmpty: Boolean;
    function IsFull: Boolean;
    function Capacity: PtrUInt;
    function ApproxCount: PtrUInt;
  end;

  generic TSpscQueue<T> = class(specialize TSpscQueueImpl<T>)
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.wait,
  nextpas.core.time.base
  {$IFDEF LOCKFREE_DEBUG}
  , nextpas.core.platform.thread
  {$ENDIF};

constructor TSpscQueueImpl.Create(const ACapacity: PtrUInt);
var
  LCap: PtrUInt;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TSpscQueue: T must be unmanaged (no string/interface/dynarray)');
  if ACapacity = 0 then
    raise EArgumentError.Create('TSpscQueue: capacity must be > 0');
  inherited Create;
  LCap := LockFreeNextPow2(ACapacity);
  FCapacity := LCap;
  FMask := LCap - 1;
  SetLength(FSlots, LCap);
  FTail := 0;
  FHead := 0;
  FTailPublished := 0;
  FHeadPublished := 0;
  FHeadCache := 0;
  FTailCache := 0;
  FClosed := 0;
  FDataEpoch := 0;
  FSpaceEpoch := 0;
  FDataWaiters := 0;
  FSpaceWaiters := 0;
  {$IFDEF LOCKFREE_DEBUG}
  FProducerThreadId := 0;
  FConsumerThreadId := 0;
  {$ENDIF}
end;

{$IFDEF LOCKFREE_DEBUG}
procedure TSpscQueueImpl.DebugClaimProducer;
var
  LSelf: UInt64;
begin
  LSelf := platform_thread_id;
  if FProducerThreadId = 0 then
    FProducerThreadId := LSelf
  else if FProducerThreadId <> LSelf then
    raise EInvalidOperationError.Create(
      'TSpscQueue LOCKFREE_DEBUG: enqueue must run on a single producer thread');
end;

procedure TSpscQueueImpl.DebugClaimConsumer;
var
  LSelf: UInt64;
begin
  LSelf := platform_thread_id;
  if FConsumerThreadId = 0 then
    FConsumerThreadId := LSelf
  else if FConsumerThreadId <> LSelf then
    raise EInvalidOperationError.Create(
      'TSpscQueue LOCKFREE_DEBUG: dequeue must run on a single consumer thread');
end;
{$ENDIF}

function TSpscQueueImpl.TryEnqueue(const AValue: T): Boolean;
var
  LTail: Int64;
begin
  {$IFDEF LOCKFREE_DEBUG}
  DebugClaimProducer;
  {$ENDIF}
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(False);
  LTail := FTail;
  if LTail - FHeadCache >= Int64(FCapacity) then
  begin
    FHeadCache := atomic_load_64(FHeadPublished, mo_acquire);
    if LTail - FHeadCache >= Int64(FCapacity) then
      Exit(False);
  end;
  FSlots[LTail and Int64(FMask)] := AValue;
  FTail := LTail + 1;
  atomic_store_64(FTailPublished, LTail + 1, mo_release);
  { Fast path: only notify if there are waiters }
  if atomic_load(FDataWaiters, mo_relaxed) > 0 then
    LockFreeNotifyData(@FDataEpoch, @FDataWaiters);
  Result := True;
end;

function TSpscQueueImpl.TryEnqueueEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
begin
  if TryEnqueue(AValue) then
  begin
    AError := lfteNone;
    Exit(True);
  end;
  if IsClosed then
    AError := lfteClosed
  else
    AError := lfteFull;
  Result := False;
end;

function TSpscQueueImpl.TryDequeue(out AValue: T): Boolean;
var
  LHead: Int64;
begin
  {$IFDEF LOCKFREE_DEBUG}
  DebugClaimConsumer;
  {$ENDIF}
  LHead := FHead;
  if LHead >= FTailCache then
  begin
    FTailCache := atomic_load_64(FTailPublished, mo_acquire);
    if LHead >= FTailCache then
      Exit(False);
  end;
  AValue := FSlots[LHead and Int64(FMask)];
  FHead := LHead + 1;
  atomic_store_64(FHeadPublished, LHead + 1, mo_release);
  { Fast path: only notify if there are waiters }
  if atomic_load(FSpaceWaiters, mo_relaxed) > 0 then
    LockFreeNotifySpace(@FSpaceEpoch, @FSpaceWaiters);
  Result := True;
end;

function TSpscQueueImpl.TryDequeueEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
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

function TSpscQueueImpl.EnqueueWait(const AValue: T): Boolean;
var
  LEpoch: Int32;
begin
  if TryEnqueue(AValue) then
  begin
    Exit(True);
  end;
  while True do
  begin
    LEpoch := atomic_load(FSpaceEpoch, mo_acquire);
    if TryEnqueue(AValue) then
      Exit(True);
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(False);
    LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, LOCKFREE_WAIT_TIMEOUT_NS);
  end;
end;

function TSpscQueueImpl.DequeueWait(out AValue: T): Boolean;
var
  LEpoch: Int32;
begin
  if TryDequeue(AValue) then
  begin
    Exit(True);
  end;
  while True do
  begin
    LEpoch := atomic_load(FDataEpoch, mo_acquire);
    if TryDequeue(AValue) then
      Exit(True);
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(False);
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LOCKFREE_WAIT_TIMEOUT_NS);
  end;
end;

function TSpscQueueImpl.EnqueueTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
var
  LEpoch: Int32;
  LStart: TInstant;
  LRemaining: Int64;
begin
  if TryEnqueue(AValue) then
    Exit(True);
  LStart := TInstant.Now;
  while True do
  begin
    LRemaining := ATimeoutNs - LStart.Elapsed.AsNanoseconds;
    if LRemaining <= 0 then
      Exit(TryEnqueue(AValue));
    LEpoch := atomic_load(FSpaceEpoch, mo_acquire);
    if TryEnqueue(AValue) then
      Exit(True);
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(False);
    LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, LRemaining);
  end;
end;

function TSpscQueueImpl.DequeueTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
var
  LEpoch: Int32;
  LStart: TInstant;
  LRemaining: Int64;
begin
  if TryDequeue(AValue) then
  begin
    Exit(True);
  end;
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
      Exit(False);
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LRemaining);
  end;
end;

function TSpscQueueImpl.EnqueueBatch(const AValues: array of T): PtrUInt;
var
  LTail, LAvail: Int64;
  LCount: PtrUInt;
  LStart: PtrUInt;
  LContiguous: PtrUInt;
  LWrap: PtrUInt;
begin
  if Length(AValues) = 0 then
    Exit(0);
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(0);
  LTail := FTail;
  FHeadCache := atomic_load_64(FHeadPublished, mo_acquire);
  LAvail := Int64(FCapacity) - (LTail - FHeadCache);
  if LAvail <= 0 then
    Exit(0);
  LCount := PtrUInt(Length(AValues));
  if LCount > PtrUInt(LAvail) then
    LCount := PtrUInt(LAvail);
  LStart := PtrUInt(LTail) and FMask;
  LContiguous := FCapacity - LStart;
  if LCount <= LContiguous then
    Move(AValues[0], FSlots[LStart], LCount * SizeOf(T))
  else
  begin
    LWrap := LCount - LContiguous;
    Move(AValues[0], FSlots[LStart], LContiguous * SizeOf(T));
    Move(AValues[LContiguous], FSlots[0], LWrap * SizeOf(T));
  end;
  FTail := LTail + Int64(LCount);
  atomic_store_64(FTailPublished, FTail, mo_release);
  { Fast path: only notify if there are waiters }
  if atomic_load(FDataWaiters, mo_relaxed) > 0 then
    LockFreeNotifyData(@FDataEpoch, @FDataWaiters);
  Result := LCount;
end;

function TSpscQueueImpl.DequeueBatch(out AValues: array of T; const AMaxCount: PtrUInt): PtrUInt;
var
  LHead, LAvail: Int64;
  LCount: PtrUInt;
  LStart: PtrUInt;
  LContiguous: PtrUInt;
  LWrap: PtrUInt;
begin
  if (AMaxCount = 0) or (Length(AValues) = 0) then
    Exit(0);
  LHead := FHead;
  FTailCache := atomic_load_64(FTailPublished, mo_acquire);
  LAvail := FTailCache - LHead;
  if LAvail <= 0 then
    Exit(0);
  LCount := AMaxCount;
  if LCount > PtrUInt(LAvail) then
    LCount := PtrUInt(LAvail);
  if LCount > PtrUInt(Length(AValues)) then
    LCount := PtrUInt(Length(AValues));
  LStart := PtrUInt(LHead) and FMask;
  LContiguous := FCapacity - LStart;
  if LCount <= LContiguous then
    Move(FSlots[LStart], AValues[0], LCount * SizeOf(T))
  else
  begin
    LWrap := LCount - LContiguous;
    Move(FSlots[LStart], AValues[0], LContiguous * SizeOf(T));
    Move(FSlots[0], AValues[LContiguous], LWrap * SizeOf(T));
  end;
  FHead := LHead + Int64(LCount);
  atomic_store_64(FHeadPublished, FHead, mo_release);
  { Fast path: only notify if there are waiters }
  if atomic_load(FSpaceWaiters, mo_relaxed) > 0 then
    LockFreeNotifySpace(@FSpaceEpoch, @FSpaceWaiters);
  Result := LCount;
end;

function TSpscQueueImpl.Drain(const AMaxCount: PtrUInt): PtrUInt;
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

procedure TSpscQueueImpl.Close;
begin
  atomic_store(FClosed, 1, mo_release);
  LockFreeWakeAll(@FDataEpoch);
  LockFreeWakeAll(@FSpaceEpoch);
end;

destructor TSpscQueueImpl.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TSpscQueueImpl.IsClosed: Boolean;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

function TSpscQueueImpl.ApproxCount: PtrUInt;
var
  LTail, LHead: Int64;
begin
  LTail := atomic_load_64(FTailPublished, mo_acquire);
  LHead := atomic_load_64(FHeadPublished, mo_acquire);
  if LTail > LHead then
    Result := PtrUInt(LTail - LHead)
  else
    Result := 0;
end;

function TSpscQueueImpl.IsEmpty: Boolean;
begin
  Result := ApproxCount = 0;
end;

function TSpscQueueImpl.IsFull: Boolean;
begin
  Result := ApproxCount >= FCapacity;
end;

function TSpscQueueImpl.Capacity: PtrUInt;
begin
  Result := FCapacity;
end;

end.
