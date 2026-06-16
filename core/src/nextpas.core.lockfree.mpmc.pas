unit nextpas.core.lockfree.mpmc;

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
    function TryEnqueue(const AValue: T): Boolean;
    function TryDequeue(out AValue: T): Boolean;
    function EnqueueWait(const AValue: T): Boolean;
    function DequeueWait(out AValue: T): Boolean;
    function EnqueueTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
    function DequeueTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
    function EnqueueBatch(const AValues: array of T): PtrUInt;
    function DequeueBatch(out AValues: array of T; const AMaxCount: PtrUInt): PtrUInt;
    procedure Close;
    function IsClosed: Boolean;
    function IsEmpty: Boolean;
    function IsFull: Boolean;
    function Capacity: PtrUInt;
    function ApproxCount: PtrUInt;
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
    raise EArgumentError.Create('TMpmcQueue: T must be unmanaged');
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
  Result := (AtomicLoad32(FClosed, moAcquire) <> 0) and
    (AtomicLoad32(FActiveEnqueues, moAcquire) = 0);
end;

procedure TMpmcQueueImpl.LeaveActiveEnqueue;
begin
  if AtomicFetchSub32(FActiveEnqueues, 1, moAcqRel) = 1 then
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      LockFreeWakeAll(@FDataEpoch);
  end;
end;

function TMpmcQueueImpl.TryEnqueue(const AValue: T): Boolean;
var
  LPos: Int64;
  LIdx: PtrUInt;
  LSeq, LExpected, LDiff: Int64;
  LBackoff: Integer;
  LI: Integer;
begin
  AtomicFetchAdd32(FActiveEnqueues, 1, moAcqRel);
  try
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(False);
    LBackoff := 1;
    while True do
    begin
      if AtomicLoad32(FClosed, moAcquire) <> 0 then
        Exit(False);
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
          LockFreeNotifyData(@FDataEpoch, @FDataWaiters);
          Result := True;
          Exit;
        end;
        { CAS failed — another producer won this slot }
        if LBackoff < 256 then
        begin
          LI := LBackoff;
          repeat
            CpuPause;
            Dec(LI);
          until LI = 0;
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

function TMpmcQueueImpl.TryDequeue(out AValue: T): Boolean;
var
  LPos: Int64;
  LIdx: PtrUInt;
  LSeq, LExpected, LDiff: Int64;
  LBackoff: Integer;
  LI: Integer;
begin
  LBackoff := 1;
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
        LockFreeNotifySpace(@FSpaceEpoch, @FSpaceWaiters);
        Result := True;
        Exit;
      end;
      { CAS failed — another consumer won this slot }
      if LBackoff < 256 then
      begin
        LI := LBackoff;
        repeat
          CpuPause;
          Dec(LI);
        until LI = 0;
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

function TMpmcQueueImpl.EnqueueWait(const AValue: T): Boolean;
var
  LEpoch: Int32;
begin
  if TryEnqueue(AValue) then
  begin

    Exit(True);
  end;
  while True do
  begin
    LEpoch := AtomicLoad32(FSpaceEpoch, moAcquire);
    if TryEnqueue(AValue) then
    begin

      Exit(True);
    end;
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(False);
    LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, -1);
  end;
end;

function TMpmcQueueImpl.DequeueWait(out AValue: T): Boolean;
var
  LEpoch: Int32;
begin
  if TryDequeue(AValue) then
  begin
    
    Exit(True);
  end;
  while True do
  begin
    LEpoch := AtomicLoad32(FDataEpoch, moAcquire);
    if TryDequeue(AValue) then
    begin
      
      Exit(True);
    end;
    if ClosedAndNoActiveEnqueues then
    begin
      if TryDequeue(AValue) then
        Exit(True);
      Exit(False);
    end;
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, -1);
  end;
end;

function TMpmcQueueImpl.EnqueueTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
var
  LEpoch: Int32;
  LStart: TInstant;
  LRemaining: Int64;
begin
  if TryEnqueue(AValue) then
  begin
    
    Exit(True);
  end;
  LStart := TInstant.Now;
  while True do
  begin
    LRemaining := ATimeoutNs - LStart.Elapsed.AsNanoseconds;
    if LRemaining <= 0 then
      Exit(TryEnqueue(AValue));
    LEpoch := AtomicLoad32(FSpaceEpoch, moAcquire);
    if TryEnqueue(AValue) then
    begin
      
      Exit(True);
    end;
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
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
  begin
    
    Exit(True);
  end;
  LStart := TInstant.Now;
  while True do
  begin
    LRemaining := ATimeoutNs - LStart.Elapsed.AsNanoseconds;
    if LRemaining <= 0 then
      Exit(TryDequeue(AValue));
    LEpoch := AtomicLoad32(FDataEpoch, moAcquire);
    if TryDequeue(AValue) then
    begin
      
      Exit(True);
    end;
    if ClosedAndNoActiveEnqueues then
    begin
      if TryDequeue(AValue) then
        Exit(True);
      Exit(False);
    end;
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LRemaining);
  end;
end;

procedure TMpmcQueueImpl.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
  LockFreeWakeAll(@FDataEpoch);
  LockFreeWakeAll(@FSpaceEpoch);
  
  
end;

function TMpmcQueueImpl.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TMpmcQueueImpl.ApproxCount: PtrUInt;
var
  LEnq, LDeq: Int64;
begin
  LEnq := AtomicLoad64(FEnqueuePos, moRelaxed);
  LDeq := AtomicLoad64(FDequeuePos, moRelaxed);
  if LEnq > LDeq then
    Result := PtrUInt(LEnq - LDeq)
  else
    Result := 0;
end;

function TMpmcQueueImpl.EnqueueBatch(const AValues: array of T): PtrUInt;
var
  LI: PtrUInt;
begin
  if Length(AValues) = 0 then
    Exit(0);
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(0);
  Result := 0;
  for LI := 0 to PtrUInt(High(AValues)) do
  begin
    if not TryEnqueue(AValues[LI]) then
      Exit;
    Inc(Result);
  end;
end;

function TMpmcQueueImpl.DequeueBatch(out AValues: array of T; const AMaxCount: PtrUInt): PtrUInt;
var
  LI, LCount: PtrUInt;
begin
  if (AMaxCount = 0) or (Length(AValues) = 0) then
    Exit(0);
  LCount := AMaxCount;
  if LCount > PtrUInt(Length(AValues)) then
    LCount := PtrUInt(Length(AValues));
  Result := 0;
  for LI := 0 to LCount - 1 do
  begin
    if not TryDequeue(AValues[LI]) then
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
