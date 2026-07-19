unit nextpas.core.lockfree.mpmc;
{**
 * @desc Lock-free Multi-Producer Multi-Consumer bounded queue.
 *
 * @details Sequence-based MPMC queue using cache-line padding:
 *   - Bounded capacity (power-of-2 required)
 *   - Non-blocking TryEnqueue/TryDequeue
 *   - Blocking EnqueueWait/DequeueWait with timeout variants
 *   - Batch operations for high-throughput scenarios
 *   - Close semantics with drain support
 *
 * @concurrency Thread-safe for multiple producers and consumers:
 *   - Enqueue: producers compete for slots via CAS
 *   - Dequeue: consumers compete for data via CAS
 *   - Close: safe to call from any thread
 *   - Active producer tracking: Close + empty is terminal only after
 *     all admitted enqueues have left (FActiveEnqueues)
 *
 * @see Dmitry Vyukov MPMC queue — lock-free bounded queue
 * @see crossbeam (Rust) — similar MPMC implementation
 *
 * Preferred atomics: atomic_* + mo_* (Go/Rust parity / Q2).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  generic TMpmcQueueImpl<T> = class
  private
    class function EmptySequence(const APos: Int64): Int64; static; inline;
    class function FullSequence(const APos: Int64): Int64; static; inline;
    function ClosedAndNoActiveEnqueues: Boolean; inline;
    procedure LeaveActiveEnqueue; inline;
  private
    type
      TSlot = record
        Sequence: Int64;
        Value: T;
      end;
  private
    FSlots: array of TSlot;
    FCapacity: PtrUInt;
    FMask: PtrUInt;
    // Producer-owned fields (cache line 1)
    FEnqueuePos: Int64;
    FActiveEnqueues: Int32;
    FSpaceEpoch: Int32;
    FSpaceWaiters: Int32;
    {$PUSH} {$WARN 05029 OFF} // padding field for cache-line isolation
    FPadProducer: TCacheLinePad;
    {$POP}
    // Consumer-owned fields (cache line 2)
    FDequeuePos: Int64;
    FDataEpoch: Int32;
    FDataWaiters: Int32;
    {$PUSH} {$WARN 05029 OFF} // padding field for cache-line isolation
    FPadConsumer: TCacheLinePad;
    {$POP}
    // Shared (published) fields (cache line 3)
    FClosed: Int32;
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
    function IsClosed: Boolean; inline;
    function IsEmpty: Boolean; inline;
    function IsFull: Boolean; inline;
    function Capacity: PtrUInt; inline;
    function ApproxCount: PtrUInt; inline;
  end;

  generic TMpmcQueue<T> = class(specialize TMpmcQueueImpl<T>)
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.wait,
  nextpas.core.time.base;

class function TMpmcQueueImpl.EmptySequence(const APos: Int64): Int64;
begin
  Result := APos * 2;
end;

class function TMpmcQueueImpl.FullSequence(const APos: Int64): Int64;
begin
  Result := (APos * 2) + 1;
end;

constructor TMpmcQueueImpl.Create(const ACapacity: PtrUInt);
var
  LCap: PtrUInt;
  LI: PtrUInt;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TMpmcQueue: T must be unmanaged (no string/interface/dynarray)');
  if ACapacity = 0 then
    raise EArgumentError.Create('TMpmcQueue: capacity must be > 0');
  inherited Create;
  LCap := LockFreeNextPow2(ACapacity);
  FCapacity := LCap;
  FMask := LCap - 1;
  SetLength(FSlots, LCap);
  for LI := 0 to LCap - 1 do
    FSlots[LI].Sequence := EmptySequence(Int64(LI));
  FEnqueuePos := 0;
  FDequeuePos := 0;
  FClosed := 0;
  FActiveEnqueues := 0;
  FDataEpoch := 0;
  FSpaceEpoch := 0;
  FDataWaiters := 0;
  FSpaceWaiters := 0;
end;

function TMpmcQueueImpl.ClosedAndNoActiveEnqueues: Boolean;
begin
  Result := (atomic_load(FClosed, mo_acquire) <> 0) and
    (atomic_load(FActiveEnqueues, mo_acquire) = 0);
end;

procedure TMpmcQueueImpl.LeaveActiveEnqueue;
begin
  if atomic_fetch_sub(FActiveEnqueues, 1, mo_acq_rel) = 1 then
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
      LockFreeWakeAll(@FDataEpoch);
  end;
end;

function TMpmcQueueImpl.TryEnqueue(const AValue: T): Boolean;
var
  LPos: Int64;
  LIdx: PtrUInt;
  LSeq, LExpected, LDiff: Int64;
  LPosExpected: Int64;
  LBackoff: Integer;
  LI: Integer;
begin
  atomic_fetch_add(FActiveEnqueues, 1, mo_acq_rel);
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(False);
    LBackoff := 1;
    while True do
    begin
      if atomic_load(FClosed, mo_acquire) <> 0 then
        Exit(False);
      LPos := atomic_load_64(FEnqueuePos, mo_relaxed);
      LIdx := PtrUInt(LPos) and FMask;
      LSeq := atomic_load_64(FSlots[LIdx].Sequence, mo_acquire);
      LExpected := EmptySequence(LPos);
      LDiff := LSeq - LExpected;
      if LDiff = 0 then
      begin
        LPosExpected := LPos;
        if atomic_compare_exchange_strong_64(FEnqueuePos, LPosExpected, LPos + 1,
          mo_relaxed, mo_relaxed) then
        begin
          FSlots[LIdx].Value := AValue;
          atomic_store_64(FSlots[LIdx].Sequence, FullSequence(LPos), mo_release);
          { Fast path: only notify if there are waiters }
          if atomic_load(FDataWaiters, mo_relaxed) > 0 then
            LockFreeNotifyData(@FDataEpoch, @FDataWaiters);
          Result := True;
          Exit;
        end;
        { CAS failed — another producer won this slot }
        if LBackoff < 256 then
        begin
          { Add variation based on position to reduce livelock }
          LI := LBackoff + Integer(LPos and 3);
          repeat
            CpuPause;
            Dec(LI);
          until LI <= 0;
          LBackoff := LBackoff * 2;
        end
        else
          CpuPause;
      end
      else if LDiff < 0 then
        Exit(False)
      else
        CpuPause;
    end;
  finally
    LeaveActiveEnqueue;
  end;
end;

function TMpmcQueueImpl.TryEnqueueEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
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

function TMpmcQueueImpl.TryDequeue(out AValue: T): Boolean;
var
  LPos: Int64;
  LIdx: PtrUInt;
  LSeq, LExpected, LDiff: Int64;
  LPosExpected: Int64;
  LBackoff: Integer;
  LI: Integer;
begin
  LBackoff := 1;
  while True do
  begin
    LPos := atomic_load_64(FDequeuePos, mo_relaxed);
    LIdx := PtrUInt(LPos) and FMask;
    LSeq := atomic_load_64(FSlots[LIdx].Sequence, mo_acquire);
    LExpected := FullSequence(LPos);
    LDiff := LSeq - LExpected;
    if LDiff = 0 then
    begin
      LPosExpected := LPos;
      if atomic_compare_exchange_strong_64(FDequeuePos, LPosExpected, LPos + 1,
        mo_relaxed, mo_relaxed) then
      begin
        AValue := FSlots[LIdx].Value;
        FSlots[LIdx].Value := Default(T);
        atomic_store_64(FSlots[LIdx].Sequence, EmptySequence(LPos + Int64(FCapacity)), mo_release);
        { Fast path: only notify if there are waiters }
        if atomic_load(FSpaceWaiters, mo_relaxed) > 0 then
          LockFreeNotifySpace(@FSpaceEpoch, @FSpaceWaiters);
        Result := True;
        Exit;
      end;
      { CAS failed — another consumer won this slot }
      if LBackoff < 256 then
      begin
        { Add variation based on position to reduce livelock }
        LI := LBackoff + Integer(LPos and 3);
        repeat
          CpuPause;
          Dec(LI);
        until LI <= 0;
        LBackoff := LBackoff * 2;
      end
      else
        CpuPause;
    end
    else if LDiff < 0 then
      Exit(False)
    else
      CpuPause;
  end;
end;

function TMpmcQueueImpl.TryDequeueEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
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

function TMpmcQueueImpl.EnqueueWait(const AValue: T): Boolean;
var
  LEpoch: Int32;
begin
  if TryEnqueue(AValue) then
    Exit(True);
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

function TMpmcQueueImpl.DequeueWait(out AValue: T): Boolean;
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
    if ClosedAndNoActiveEnqueues then
    begin
      if TryDequeue(AValue) then
        Exit(True);
      Exit(False);
    end;
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LOCKFREE_WAIT_TIMEOUT_NS);
  end;
end;

function TMpmcQueueImpl.EnqueueTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
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

function TMpmcQueueImpl.DequeueTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
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
    if ClosedAndNoActiveEnqueues then
    begin
      if TryDequeue(AValue) then
        Exit(True);
      Exit(False);
    end;
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LRemaining);
  end;
end;

function TMpmcQueueImpl.Drain(const AMaxCount: PtrUInt): PtrUInt;
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

procedure TMpmcQueueImpl.Close;
begin
  atomic_store(FClosed, 1, mo_release);
  LockFreeWakeAll(@FDataEpoch);
  LockFreeWakeAll(@FSpaceEpoch);
end;

destructor TMpmcQueueImpl.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TMpmcQueueImpl.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

function TMpmcQueueImpl.ApproxCount: PtrUInt;
var
  LEnq, LDeq: Int64;
begin
  LEnq := atomic_load_64(FEnqueuePos, mo_relaxed);
  LDeq := atomic_load_64(FDequeuePos, mo_relaxed);
  if LEnq > LDeq then
    Result := PtrUInt(LEnq - LDeq)
  else
    Result := 0;
end;

function TMpmcQueueImpl.EnqueueBatch(const AValues: array of T): PtrUInt;
begin
  Result := 0;
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit;
  while Result < PtrUInt(Length(AValues)) do
  begin
    if not TryEnqueue(AValues[Result]) then
      Exit;
    Inc(Result);
  end;
end;

function TMpmcQueueImpl.DequeueBatch(out AValues: array of T; const AMaxCount: PtrUInt): PtrUInt;
var
  LLimit: PtrUInt;
begin
  if (AMaxCount = 0) or (Length(AValues) = 0) then
    Exit(0);
  LLimit := AMaxCount;
  if LLimit > PtrUInt(Length(AValues)) then
    LLimit := PtrUInt(Length(AValues));
  Result := 0;
  while Result < LLimit do
  begin
    if not TryDequeue(AValues[Result]) then
      Exit;
    Inc(Result);
  end;
end;

function TMpmcQueueImpl.IsEmpty: Boolean;
begin
  Result := ApproxCount = 0;
end;

function TMpmcQueueImpl.IsFull: Boolean;
begin
  Result := ApproxCount >= FCapacity;
end;

function TMpmcQueueImpl.Capacity: PtrUInt;
begin
  Result := FCapacity;
end;

end.
