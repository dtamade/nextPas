unit nextpas.core.lockfree.spsc;

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
    // Producer-owned fields (cache line 1)
    FTail: Int64;
    FTailCache: Int64;
    FSpaceEpoch: Int32;
    FSpaceWaiters: Int32;
    FPadProducer: array[0..3] of Int64;
    // Consumer-owned fields (cache line 2)
    FHead: Int64;
    FHeadCache: Int64;
    FDataEpoch: Int32;
    FDataWaiters: Int32;
    FPadConsumer: array[0..3] of Int64;
    // Shared (published) fields (cache line 3)
    FTailPublished: Int64;
    FHeadPublished: Int64;
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

  generic TSpscQueue<T> = class(specialize TSpscQueueImpl<T>)
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.wait,
  nextpas.core.time.base;

constructor TSpscQueueImpl.Create(const ACapacity: PtrUInt);
var
  LCap: PtrUInt;
begin
  inherited Create;
  if IsManagedType(T) then
    raise EArgumentError.Create('TSpscQueue: T must be unmanaged (no string/interface/dynarray)');
  if ACapacity = 0 then
    raise EArgumentError.Create('TSpscQueue: capacity must be > 0');
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
end;

function TSpscQueueImpl.TryEnqueue(const AValue: T): Boolean;
var
  LTail: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  LTail := FTail;
  if LTail - FHeadCache >= Int64(FCapacity) then
  begin
    FHeadCache := AtomicLoad64(FHeadPublished, moAcquire);
    if LTail - FHeadCache >= Int64(FCapacity) then
      Exit(False);
  end;
  FSlots[LTail and Int64(FMask)] := AValue;
  FTail := LTail + 1;
  AtomicStore64(FTailPublished, LTail + 1, moRelease);
  LockFreeNotifyData(@FDataEpoch, @FDataWaiters);
  Result := True;
end;

function TSpscQueueImpl.TryDequeue(out AValue: T): Boolean;
var
  LHead: Int64;
begin
  LHead := FHead;
  if LHead >= FTailCache then
  begin
    FTailCache := AtomicLoad64(FTailPublished, moAcquire);
    if LHead >= FTailCache then
      Exit(False);
  end;
  AValue := FSlots[LHead and Int64(FMask)];
  FHead := LHead + 1;
  AtomicStore64(FHeadPublished, LHead + 1, moRelease);
  LockFreeNotifySpace(@FSpaceEpoch, @FSpaceWaiters);
  Result := True;
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
    LEpoch := AtomicLoad32(FSpaceEpoch, moAcquire);
    if TryEnqueue(AValue) then
    begin
      LockFreeWakeAll(@FDataEpoch);
      Exit(True);
    end;
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(False);
    LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, -1);
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
    LEpoch := AtomicLoad32(FDataEpoch, moAcquire);
    if TryDequeue(AValue) then
    begin
      LockFreeWakeAll(@FSpaceEpoch);
      Exit(True);
    end;
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(False);
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, -1);
  end;
end;

function TSpscQueueImpl.EnqueueTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
var
  LEpoch: Int32;
  LStart: TInstant;
  LRemaining: Int64;
begin
  if TryEnqueue(AValue) then
  begin
    LockFreeWakeAll(@FDataEpoch);
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
      LockFreeWakeAll(@FDataEpoch);
      Exit(True);
    end;
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
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
    LEpoch := AtomicLoad32(FDataEpoch, moAcquire);
    if TryDequeue(AValue) then
    begin
      LockFreeWakeAll(@FSpaceEpoch);
      Exit(True);
    end;
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(False);
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LRemaining);
  end;
end;

function TSpscQueueImpl.EnqueueBatch(const AValues: array of T): PtrUInt;
var
  LTail, LAvail: Int64;
  LI: PtrUInt;
  LCount: PtrUInt;
begin
  if Length(AValues) = 0 then
    Exit(0);
  LTail := FTail;
  LAvail := Int64(FCapacity) - (LTail - FHeadCache);
  if LAvail <= 0 then
  begin
    FHeadCache := AtomicLoad64(FHeadPublished, moAcquire);
    LAvail := Int64(FCapacity) - (LTail - FHeadCache);
    if LAvail <= 0 then
      Exit(0);
  end;
  LCount := PtrUInt(Length(AValues));
  if LCount > PtrUInt(LAvail) then
    LCount := PtrUInt(LAvail);
  for LI := 0 to LCount - 1 do
    FSlots[(LTail + Int64(LI)) and Int64(FMask)] := AValues[LI];
  FTail := LTail + Int64(LCount);
  AtomicStore64(FTailPublished, FTail, moRelease);
  LockFreeNotifyData(@FDataEpoch, @FDataWaiters);
  Result := LCount;
end;

function TSpscQueueImpl.DequeueBatch(out AValues: array of T; const AMaxCount: PtrUInt): PtrUInt;
var
  LHead, LAvail: Int64;
  LI: PtrUInt;
  LCount: PtrUInt;
begin
  if (AMaxCount = 0) or (Length(AValues) = 0) then
    Exit(0);
  LHead := FHead;
  LAvail := FTailCache - LHead;
  if LAvail <= 0 then
  begin
    FTailCache := AtomicLoad64(FTailPublished, moAcquire);
    LAvail := FTailCache - LHead;
    if LAvail <= 0 then
      Exit(0);
  end;
  LCount := AMaxCount;
  if LCount > PtrUInt(LAvail) then
    LCount := PtrUInt(LAvail);
  if LCount > PtrUInt(Length(AValues)) then
    LCount := PtrUInt(Length(AValues));
  for LI := 0 to LCount - 1 do
    AValues[LI] := FSlots[(LHead + Int64(LI)) and Int64(FMask)];
  FHead := LHead + Int64(LCount);
  AtomicStore64(FHeadPublished, FHead, moRelease);
  LockFreeNotifySpace(@FSpaceEpoch, @FSpaceWaiters);
  Result := LCount;
end;

procedure TSpscQueueImpl.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
  LockFreeWakeAll(@FDataEpoch);
  LockFreeWakeAll(@FSpaceEpoch);
end;

function TSpscQueueImpl.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TSpscQueueImpl.ApproxCount: PtrUInt;
var
  LTail, LHead: Int64;
begin
  LTail := AtomicLoad64(FTailPublished, moAcquire);
  LHead := AtomicLoad64(FHeadPublished, moAcquire);
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
