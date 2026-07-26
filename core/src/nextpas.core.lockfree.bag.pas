unit nextpas.core.lockfree.bag;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TLockFreeBagAddResult = (arAdded, arFull, arClosed);

  {** @desc 并发 Bag（允许重复元素）— T2 Guarded / H3-2 生产子集
    @details 有界 MPMC 序列号 ring；允许重复；TryAdd/TryTake/Wait/Timeout/Close。
      Managed T 在 Create 拒绝。Close 后禁止新增，已有元素可继续 Take。
      **不**经默认 `uses nextpas.core.lockfree` 门面；见 CONTRACT §0.3。
 * @concurrency Thread-safe; progress = lock-free ring + optional wait-address block.
  }
  generic TLockFreeBagImpl<T> = class
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
    {$PUSH} {$WARN 05029 OFF} // keep the read-mostly header off the hot lines
    FPadHeader: TCacheLinePad;
    {$POP}
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
    class function EmptySequence(const APos: Int64): Int64; static; inline;
    class function FullSequence(const APos: Int64): Int64; static; inline;
    function ClosedAndNoActiveEnqueues: Boolean; inline;
    procedure LeaveActiveEnqueue; inline;
  public
    constructor Create(const ACapacity: PtrUInt);
    destructor Destroy; override;
    function TryAdd(const AValue: T): TLockFreeBagAddResult;
    function TryTake(out AValue: T): Boolean;
    function AddWait(const AValue: T): Boolean;
    function TakeWait(out AValue: T): Boolean;
    function AddTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
    function TakeTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
    procedure Close;
    function IsClosed: Boolean;
    function IsEmpty: Boolean;
    function IsFull: Boolean;
    function Capacity: PtrUInt;
    function ApproxCount: PtrUInt;
  end;

  generic TLockFreeBag<T> = class(specialize TLockFreeBagImpl<T>)
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.wait,
  nextpas.core.time.base,
  nextpas.core.math;

class function TLockFreeBagImpl.EmptySequence(const APos: Int64): Int64;
begin
  Result := APos * 2;
end;

class function TLockFreeBagImpl.FullSequence(const APos: Int64): Int64;
begin
  Result := (APos * 2) + 1;
end;

constructor TLockFreeBagImpl.Create(const ACapacity: PtrUInt);
var
  LCap: PtrUInt;
  LI: PtrUInt;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TLockFreeBag: T must be unmanaged (no string/interface/dynarray)');
  if ACapacity = 0 then
    raise EArgumentError.Create('TLockFreeBag: capacity must be > 0');
  inherited Create;
  LCap := LockFreeNextPow2(ACapacity);
  FCapacity := LCap;
  FMask := LCap - 1;
  SetLength(FSlots, LCap);
  for LI := 0 to LCap - 1 do
    FSlots[LI].Sequence := EmptySequence(Int64(LI));
  FEnqueuePos := 0;
  FActiveEnqueues := 0;
  FDequeuePos := 0;
  FClosed := 0;
  FDataEpoch := 0;
  FSpaceEpoch := 0;
  FDataWaiters := 0;
  FSpaceWaiters := 0;
end;

function TLockFreeBagImpl.ClosedAndNoActiveEnqueues: Boolean;
begin
  Result := (atomic_load(FClosed, mo_acquire) <> 0) and
    (atomic_load(FActiveEnqueues, mo_acquire) = 0);
end;

procedure TLockFreeBagImpl.LeaveActiveEnqueue;
begin
  if atomic_fetch_sub(FActiveEnqueues, 1, mo_acq_rel) = 1 then
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
      LockFreeWakeAll(@FDataEpoch);
  end;
end;

function TLockFreeBagImpl.TryAdd(const AValue: T): TLockFreeBagAddResult;
var
  LPos: Int64;
  LIdx: PtrUInt;
  LSeq, LExpected, LDiff: Int64;
begin
  atomic_fetch_add(FActiveEnqueues, 1, mo_acq_rel);
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(arClosed);
    while True do
    begin
      if atomic_load(FClosed, mo_acquire) <> 0 then
        Exit(arClosed);
      LPos := atomic_load_64(FEnqueuePos, mo_relaxed);
      LIdx := PtrUInt(LPos) and FMask;
      LSeq := atomic_load_64(FSlots[LIdx].Sequence, mo_acquire);
      LExpected := EmptySequence(LPos);
      LDiff := LSeq - LExpected;
      if LDiff = 0 then
      begin
        if atomic_compare_exchange_strong_64(FEnqueuePos, LPos, LPos + 1, mo_relaxed, mo_relaxed) then
        begin
          FSlots[LIdx].Value := AValue;
          atomic_store_64(FSlots[LIdx].Sequence, FullSequence(LPos), mo_release);
          if atomic_load(FDataWaiters, mo_relaxed) > 0 then
            LockFreeNotifyData(@FDataEpoch, @FDataWaiters);
          Exit(arAdded);
        end;
      end;
      if LDiff < 0 then
      begin
        if LPos - atomic_load_64(FDequeuePos, mo_acquire) >= Int64(FCapacity) then
          Exit(arFull);
      end;
      CpuPause;
    end;
  finally
    LeaveActiveEnqueue;
  end;
end;

function TLockFreeBagImpl.TryTake(out AValue: T): Boolean;
var
  LPos: Int64;
  LIdx: PtrUInt;
  LSeq, LExpected, LDiff: Int64;
begin
  while True do
  begin
    LPos := atomic_load_64(FDequeuePos, mo_relaxed);
    LIdx := PtrUInt(LPos) and FMask;
    LSeq := atomic_load_64(FSlots[LIdx].Sequence, mo_acquire);
    LExpected := FullSequence(LPos);
    LDiff := LSeq - LExpected;
    if LDiff = 0 then
    begin
      if atomic_compare_exchange_strong_64(FDequeuePos, LPos, LPos + 1, mo_relaxed, mo_relaxed) then
      begin
        AValue := FSlots[LIdx].Value;
        FSlots[LIdx].Value := Default(T);
        atomic_store_64(FSlots[LIdx].Sequence, EmptySequence(LPos + Int64(FCapacity)), mo_release);
        if atomic_load(FSpaceWaiters, mo_relaxed) > 0 then
          LockFreeNotifySpace(@FSpaceEpoch, @FSpaceWaiters);
        Exit(True);
      end;
    end
    else if LDiff < 0 then
    begin
      if atomic_load(FClosed, mo_acquire) = 0 then
        Exit(False);
      if ClosedAndNoActiveEnqueues then
      begin
        LSeq := atomic_load_64(FSlots[LIdx].Sequence, mo_acquire);
        if LSeq = LExpected then
          Continue;
        Exit(False);
      end;
    end;
    CpuPause;
  end;
end;

function TLockFreeBagImpl.AddWait(const AValue: T): Boolean;
var
  LEpoch: Int32;
begin
  if TryAdd(AValue) = arAdded then
    Exit(True);
  while True do
  begin
    LEpoch := atomic_load(FSpaceEpoch, mo_acquire);
    case TryAdd(AValue) of
      arAdded: Exit(True);
      arClosed: Exit(False);
      arFull: ; // Continue to wait
    end;
    LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, LOCKFREE_WAIT_TIMEOUT_NS);
  end;
end;

function TLockFreeBagImpl.TakeWait(out AValue: T): Boolean;
var
  LEpoch: Int32;
begin
  if TryTake(AValue) then
    Exit(True);
  while True do
  begin
    LEpoch := atomic_load(FDataEpoch, mo_acquire);
    if TryTake(AValue) then
      Exit(True);
    if atomic_load(FClosed, mo_acquire) <> 0 then
    begin
      // Try once more after close
      if TryTake(AValue) then
        Exit(True);
      Exit(False);
    end;
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LOCKFREE_WAIT_TIMEOUT_NS);
  end;
end;

function TLockFreeBagImpl.AddTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
var
  LEpoch: Int32;
  LStart: TInstant;
  LRemaining: Int64;
begin
  if TryAdd(AValue) = arAdded then
    Exit(True);
  LStart := TInstant.Now;
  while True do
  begin
    LRemaining := ATimeoutNs - LStart.Elapsed.AsNanoseconds;
    if LRemaining <= 0 then
      Exit(TryAdd(AValue) = arAdded);
    LEpoch := atomic_load(FSpaceEpoch, mo_acquire);
    case TryAdd(AValue) of
      arAdded: Exit(True);
      arClosed: Exit(False);
      arFull: ; // Continue to wait
    end;
    LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, LRemaining);
  end;
end;

function TLockFreeBagImpl.TakeTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
var
  LEpoch: Int32;
  LStart: TInstant;
  LRemaining: Int64;
begin
  if TryTake(AValue) then
    Exit(True);
  LStart := TInstant.Now;
  while True do
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
    begin
      // Try once more after close
      if TryTake(AValue) then
        Exit(True);
      Exit(False);
    end;
    LRemaining := ATimeoutNs - LStart.Elapsed.AsNanoseconds;
    if LRemaining <= 0 then
      Exit(TryTake(AValue));
    LEpoch := atomic_load(FDataEpoch, mo_acquire);
    if TryTake(AValue) then
      Exit(True);
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LRemaining);
  end;
end;

procedure TLockFreeBagImpl.Close;
begin
  atomic_store(FClosed, 1, mo_release);
  // Wake all waiting consumers
  LockFreeWakeAll(@FDataEpoch);
  // Wake all waiting producers (so they can see close)
  LockFreeWakeAll(@FSpaceEpoch);
end;

destructor TLockFreeBagImpl.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TLockFreeBagImpl.IsClosed: Boolean;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

function TLockFreeBagImpl.IsEmpty: Boolean;
begin
  Result := atomic_load_64(FDequeuePos, mo_acquire) >= atomic_load_64(FEnqueuePos, mo_acquire);
end;

function TLockFreeBagImpl.IsFull: Boolean;
begin
  Result := atomic_load_64(FEnqueuePos, mo_acquire) - atomic_load_64(FDequeuePos, mo_acquire) >= Int64(FCapacity);
end;

function TLockFreeBagImpl.Capacity: PtrUInt;
begin
  Result := FCapacity;
end;

function TLockFreeBagImpl.ApproxCount: PtrUInt;
var
  LDequeue, LEnqueue: Int64;
begin
  LDequeue := atomic_load_64(FDequeuePos, mo_acquire);
  LEnqueue := atomic_load_64(FEnqueuePos, mo_acquire);
  if LEnqueue > LDequeue then
    Result := PtrUInt(LEnqueue - LDequeue)
  else
    Result := 0;
end;

end.
