unit nextpas.core.lockfree.mpmc;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  generic TMpmcQueue<T> = class
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
    FEnqueuePos: Int64;
    FDequeuePos: Int64;
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

constructor TMpmcQueue.Create(const ACapacity: PtrUInt);
var
  LCap: PtrUInt;
  LI: PtrUInt;
begin
  inherited Create;
  if ACapacity = 0 then
    raise EArgumentError.Create('TMpmcQueue: capacity must be > 0');
  LCap := LockFreeNextPow2(ACapacity);
  FCapacity := LCap;
  FMask := LCap - 1;
  SetLength(FSlots, LCap);
  for LI := 0 to LCap - 1 do
    FSlots[LI].Sequence := Int64(LI);
  FEnqueuePos := 0;
  FDequeuePos := 0;
  FClosed := 0;
  FDataEpoch := 0;
  FSpaceEpoch := 0;
end;

function TMpmcQueue.TryEnqueue(const AValue: T): Boolean;
var
  LPos: Int64;
  LIdx: PtrUInt;
  LSeq, LDiff: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  while True do
  begin
    LPos := AtomicLoad64(FEnqueuePos, moRelaxed);
    LIdx := PtrUInt(LPos) and FMask;
    LSeq := AtomicLoad64(FSlots[LIdx].Sequence, moAcquire);
    LDiff := LSeq - LPos;
    if LDiff = 0 then
    begin
      if AtomicCompareExchange64(FEnqueuePos, LPos, LPos + 1, moRelaxed) = LPos then
      begin
        FSlots[LIdx].Value := AValue;
        AtomicStore64(FSlots[LIdx].Sequence, LPos + 1, moRelease);
        LockFreeWakeData(@FDataEpoch);
        Result := True;
        Exit;
      end;
    end
    else if LDiff < 0 then
      Exit(False)
    else
      CpuPause;
  end;
end;

function TMpmcQueue.TryDequeue(out AValue: T): Boolean;
var
  LPos: Int64;
  LIdx: PtrUInt;
  LSeq, LDiff: Int64;
begin
  while True do
  begin
    LPos := AtomicLoad64(FDequeuePos, moRelaxed);
    LIdx := PtrUInt(LPos) and FMask;
    LSeq := AtomicLoad64(FSlots[LIdx].Sequence, moAcquire);
    LDiff := LSeq - (LPos + 1);
    if LDiff = 0 then
    begin
      if AtomicCompareExchange64(FDequeuePos, LPos, LPos + 1, moRelaxed) = LPos then
      begin
        AValue := FSlots[LIdx].Value;
        FSlots[LIdx].Value := Default(T);
        AtomicStore64(FSlots[LIdx].Sequence, LPos + Int64(FCapacity), moRelease);
        LockFreeWakeSpace(@FSpaceEpoch);
        Result := True;
        Exit;
      end;
    end
    else if LDiff < 0 then
      Exit(False)
    else
      CpuPause;
  end;
end;

procedure TMpmcQueue.EnqueueWait(const AValue: T);
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

function TMpmcQueue.DequeueWait(out AValue: T): Boolean;
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

function TMpmcQueue.EnqueueTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
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

function TMpmcQueue.DequeueTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
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

procedure TMpmcQueue.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
  LockFreeWakeData(@FDataEpoch);
  LockFreeWakeSpace(@FSpaceEpoch);
end;

function TMpmcQueue.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TMpmcQueue.ApproxCount: PtrUInt;
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

function TMpmcQueue.EnqueueBatch(const AValues: array of T): PtrUInt;
var
  LI: PtrUInt;
begin
  if Length(AValues) = 0 then
    Exit(0);
  Result := 0;
  for LI := 0 to PtrUInt(High(AValues)) do
  begin
    if not TryEnqueue(AValues[LI]) then
      Exit;
    Inc(Result);
  end;
end;

function TMpmcQueue.DequeueBatch(out AValues: array of T; const AMaxCount: PtrUInt): PtrUInt;
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
  if Result > 0 then
    LockFreeWakeSpace(@FSpaceEpoch);
end;

function TMpmcQueue.IsEmpty: Boolean;
begin
  Result := ApproxCount = 0;
end;

function TMpmcQueue.IsFull: Boolean;
begin
  Result := ApproxCount >= FCapacity;
end;

function TMpmcQueue.Capacity: PtrUInt;
begin
  Result := FCapacity;
end;

end.
