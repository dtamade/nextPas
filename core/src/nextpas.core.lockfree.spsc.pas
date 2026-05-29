unit nextpas.core.lockfree.spsc;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  generic TSpscQueue<T> = class
  private
    FSlots: array of T;
    FCapacity: PtrUInt;
    FMask: PtrUInt;
    FTail: Int64;
    FHead: Int64;
    FTailPublished: Int64;
    FHeadPublished: Int64;
    FHeadCache: Int64;
    FTailCache: Int64;
    FClosed: Int32;
    FDataEpoch: Int32;
    FSpaceEpoch: Int32;
  public
    constructor Create(const ACapacity: PtrUInt);
    function TryEnqueue(const AValue: T): Boolean;
    function TryDequeue(out AValue: T): Boolean;
    procedure EnqueueWait(const AValue: T);
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

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.wait,
  nextpas.core.time.base;

constructor TSpscQueue.Create(const ACapacity: PtrUInt);
var
  LCap: PtrUInt;
begin
  inherited Create;
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
end;

function TSpscQueue.TryEnqueue(const AValue: T): Boolean;
var
  LTail: Int64;
begin
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
  Result := True;
end;

function TSpscQueue.TryDequeue(out AValue: T): Boolean;
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
  Result := True;
end;

procedure TSpscQueue.EnqueueWait(const AValue: T);
var
  LEpoch: Int32;
begin
  if TryEnqueue(AValue) then
  begin
    LockFreeWakeData(@FDataEpoch);
    Exit;
  end;
  while True do
  begin
    LEpoch := AtomicLoad32(FSpaceEpoch, moAcquire);
    if TryEnqueue(AValue) then
    begin
      LockFreeWakeData(@FDataEpoch);
      Exit;
    end;
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit;
    LockFreeWaitSpace(@FSpaceEpoch, LEpoch, -1);
  end;
end;

function TSpscQueue.DequeueWait(out AValue: T): Boolean;
var
  LEpoch: Int32;
begin
  if TryDequeue(AValue) then
  begin
    LockFreeWakeSpace(@FSpaceEpoch);
    Exit(True);
  end;
  while True do
  begin
    LEpoch := AtomicLoad32(FDataEpoch, moAcquire);
    if TryDequeue(AValue) then
    begin
      LockFreeWakeSpace(@FSpaceEpoch);
      Exit(True);
    end;
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(False);
    LockFreeWaitData(@FDataEpoch, LEpoch, -1);
  end;
end;

function TSpscQueue.EnqueueTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
var
  LEpoch: Int32;
  LStart: TInstant;
  LRemaining: Int64;
begin
  if TryEnqueue(AValue) then
  begin
    LockFreeWakeData(@FDataEpoch);
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
      LockFreeWakeData(@FDataEpoch);
      Exit(True);
    end;
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(False);
    LockFreeWaitSpace(@FSpaceEpoch, LEpoch, LRemaining);
  end;
end;

function TSpscQueue.DequeueTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
var
  LEpoch: Int32;
  LStart: TInstant;
  LRemaining: Int64;
begin
  if TryDequeue(AValue) then
  begin
    LockFreeWakeSpace(@FSpaceEpoch);
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
      LockFreeWakeSpace(@FSpaceEpoch);
      Exit(True);
    end;
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(False);
    LockFreeWaitData(@FDataEpoch, LEpoch, LRemaining);
  end;
end;

function TSpscQueue.EnqueueBatch(const AValues: array of T): PtrUInt;
var
  LTail, LAvail: Int64;
  LI: PtrUInt;
  LCount: PtrUInt;
begin
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
  Result := LCount;
end;

function TSpscQueue.DequeueBatch(out AValues: array of T; const AMaxCount: PtrUInt): PtrUInt;
var
  LHead, LAvail: Int64;
  LI: PtrUInt;
  LCount: PtrUInt;
begin
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
  Result := LCount;
end;

procedure TSpscQueue.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
  LockFreeWakeData(@FDataEpoch);
  LockFreeWakeSpace(@FSpaceEpoch);
end;

function TSpscQueue.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TSpscQueue.ApproxCount: PtrUInt;
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

function TSpscQueue.IsEmpty: Boolean;
begin
  Result := ApproxCount = 0;
end;

function TSpscQueue.IsFull: Boolean;
begin
  Result := ApproxCount >= FCapacity;
end;

function TSpscQueue.Capacity: PtrUInt;
begin
  Result := FCapacity;
end;

end.
