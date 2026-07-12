unit nextpas.core.lockfree.bag;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TLockFreeBagAddResult = (arAdded, arFull, arClosed);

  {** @desc 无锁并发 Bag（允许重复元素）
    @details 基于 MPMC 队列实现，允许重复元素。
      支持 TryAdd/TryTake/Wait/Timeout/Close。
      适用于任务队列、工作池等场景。
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
  Result := (AtomicLoad32(FClosed, moAcquire) <> 0) and
    (AtomicLoad32(FActiveEnqueues, moAcquire) = 0);
end;

procedure TLockFreeBagImpl.LeaveActiveEnqueue;
begin
  if AtomicFetchSub32(FActiveEnqueues, 1, moAcqRel) = 1 then
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      LockFreeWakeAll(@FDataEpoch);
  end;
end;

function TLockFreeBagImpl.TryAdd(const AValue: T): TLockFreeBagAddResult;
var
  LPos: Int64;
  LIdx: PtrUInt;
  LSeq, LExpected, LDiff: Int64;
begin
  AtomicFetchAdd32(FActiveEnqueues, 1, moAcqRel);
  try
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(arClosed);
    while True do
    begin
      if AtomicLoad32(FClosed, moAcquire) <> 0 then
        Exit(arClosed);
      LPos := AtomicLoad64(FEnqueuePos, moRelaxed);
      LIdx := PtrUInt(LPos) and FMask;
      LSeq := AtomicLoad64(FSlots[LIdx].Sequence, moAcquire);
      LExpected := EmptySequence(LPos);
      LDiff := LSeq - LExpected;
      if LDiff = 0 then
      begin
        if AtomicCompareExchange64(FEnqueuePos, LPos, LPos + 1, moRelaxed) = LPos then
        begin
          FSlots[LIdx].Value := AValue;
          AtomicStore64(FSlots[LIdx].Sequence, FullSequence(LPos), moRelease);
          if AtomicLoad32(FDataWaiters, moRelaxed) > 0 then
            LockFreeNotifyData(@FDataEpoch, @FDataWaiters);
          Exit(arAdded);
        end;
      end;
      if LDiff < 0 then
      begin
        if LPos - AtomicLoad64(FDequeuePos, moAcquire) >= Int64(FCapacity) then
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
    LPos := AtomicLoad64(FDequeuePos, moRelaxed);
    LIdx := PtrUInt(LPos) and FMask;
    LSeq := AtomicLoad64(FSlots[LIdx].Sequence, moAcquire);
    LExpected := FullSequence(LPos);
    LDiff := LSeq - LExpected;
    if LDiff = 0 then
    begin
      if AtomicCompareExchange64(FDequeuePos, LPos, LPos + 1, moRelaxed) = LPos then
      begin
        AValue := FSlots[LIdx].Value;
        FSlots[LIdx].Value := Default(T);
        AtomicStore64(FSlots[LIdx].Sequence, EmptySequence(LPos + Int64(FCapacity)), moRelease);
        if AtomicLoad32(FSpaceWaiters, moRelaxed) > 0 then
          LockFreeNotifySpace(@FSpaceEpoch, @FSpaceWaiters);
        Exit(True);
      end;
    end
    else if LDiff < 0 then
    begin
      if AtomicLoad32(FClosed, moAcquire) = 0 then
        Exit(False);
      if ClosedAndNoActiveEnqueues then
      begin
        LSeq := AtomicLoad64(FSlots[LIdx].Sequence, moAcquire);
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
    LEpoch := AtomicLoad32(FSpaceEpoch, moAcquire);
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
    LEpoch := AtomicLoad32(FDataEpoch, moAcquire);
    if TryTake(AValue) then
      Exit(True);
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
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
    LEpoch := AtomicLoad32(FSpaceEpoch, moAcquire);
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
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
    begin
      // Try once more after close
      if TryTake(AValue) then
        Exit(True);
      Exit(False);
    end;
    LRemaining := ATimeoutNs - LStart.Elapsed.AsNanoseconds;
    if LRemaining <= 0 then
      Exit(TryTake(AValue));
    LEpoch := AtomicLoad32(FDataEpoch, moAcquire);
    if TryTake(AValue) then
      Exit(True);
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LRemaining);
  end;
end;

procedure TLockFreeBagImpl.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
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
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TLockFreeBagImpl.IsEmpty: Boolean;
begin
  Result := AtomicLoad64(FDequeuePos, moAcquire) >= AtomicLoad64(FEnqueuePos, moAcquire);
end;

function TLockFreeBagImpl.IsFull: Boolean;
begin
  Result := AtomicLoad64(FEnqueuePos, moAcquire) - AtomicLoad64(FDequeuePos, moAcquire) >= Int64(FCapacity);
end;

function TLockFreeBagImpl.Capacity: PtrUInt;
begin
  Result := FCapacity;
end;

function TLockFreeBagImpl.ApproxCount: PtrUInt;
var
  LDequeue, LEnqueue: Int64;
begin
  LDequeue := AtomicLoad64(FDequeuePos, moAcquire);
  LEnqueue := AtomicLoad64(FEnqueuePos, moAcquire);
  if LEnqueue > LDequeue then
    Result := PtrUInt(LEnqueue - LDequeue)
  else
    Result := 0;
end;

end.
