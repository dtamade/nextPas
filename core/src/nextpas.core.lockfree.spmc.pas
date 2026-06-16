unit nextpas.core.lockfree.spmc;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.base,
  nextpas.core.lockfree.wait,
  nextpas.core.time.base;

type
  generic TSpmcQueueImpl<T> = class
  private type
    TSlot = record
      Sequence: Int64;
      Value: T;
    end;
  private
    FSlots: array of TSlot;
    FCapacity: PtrUInt;
    FMask: PtrUInt;
    FEnqueuePos: Int64;
    {$PUSH} {$WARN 05029 OFF}
    FPadEnqueue: TCacheLinePad;
    {$POP}
    FDequeuePos: Int64;
    {$PUSH} {$WARN 05029 OFF}
    FPadDequeue: TCacheLinePad;
    {$POP}
    FSpaceEpoch: Int32;
    FSpaceWaiters: Int32;
    FDataEpoch: Int32;
    FDataWaiters: Int32;
  public
    {** @desc 创建 SPMC 环形队列（容量向上取 2 的幂） }
    constructor Create(const ACapacity: PtrUInt);
    {** @desc 非阻塞入队；队列满时立即返回 False }
    function TryEnqueue(const AValue: T): Boolean;
    {** @desc 阻塞入队；队列满时等待直到有空间 }
    function EnqueueWait(const AValue: T): Boolean;
    {** @desc 带超时入队；超时返回 False }
    function EnqueueTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
    {** @desc 非阻塞出队；队列空时立即返回 False }
    function TryDequeue(out AValue: T): Boolean;
    {** @desc 阻塞出队；队列空时等待直到有数据 }
    function DequeueWait(out AValue: T): Boolean;
    {** @desc 带超时出队；超时返回 False }
    function DequeueTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
    {** @desc 近似空判断（快照，非线性化） }
    function IsEmpty: Boolean;
    {** @desc 近似满判断（快照，非线性化） }
    function IsFull: Boolean;
    {** @desc 近似计数（快照，非线性化） }
    function ApproxCount: PtrUInt;
    {** @desc 队列实际容量（2 的幂） }
    function Capacity: PtrUInt;
  end;

  generic TSpmcQueue<T> = class(specialize TSpmcQueueImpl<T>)
  end;

implementation

constructor TSpmcQueueImpl.Create(const ACapacity: PtrUInt);
var
  LCap: PtrUInt;
  LI: PtrUInt;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TSpmcQueue: T must be unmanaged');
  if ACapacity = 0 then
    raise EArgumentError.Create('TSpmcQueue: capacity must be > 0');
  inherited Create;
  LCap := LockFreeNextPow2(ACapacity);
  FCapacity := LCap;
  FMask := LCap - 1;
  SetLength(FSlots, LCap);
  for LI := 0 to LCap - 1 do
    FSlots[LI].Sequence := Int64(LI);
  FEnqueuePos := 0;
  FDequeuePos := 0;
  FSpaceEpoch := 0;
  FDataEpoch := 0;
  FSpaceWaiters := 0;
  FDataWaiters := 0;
end;

function TSpmcQueueImpl.TryEnqueue(const AValue: T): Boolean;
var
  LPos: Int64;
  LIdx: PtrUInt;
  LSeq: Int64;
begin
  LPos := AtomicLoad64(FEnqueuePos, moRelaxed);
  while True do
  begin
    LIdx := PtrUInt(LPos) and FMask;
    LSeq := AtomicLoad64(FSlots[LIdx].Sequence, moAcquire);
    if LSeq = LPos then
    begin
      if AtomicCompareExchange64(FEnqueuePos, LPos, LPos + 1, moRelaxed) = LPos then
      begin
        FSlots[LIdx].Value := AValue;
        AtomicStore64(FSlots[LIdx].Sequence, LPos + 2, moRelease);
        LockFreeNotifyData(@FDataEpoch, @FDataWaiters);
        Exit(True);
      end;
    end
    else if LSeq < LPos then
      Exit(False)
    else
<<<<<<< HEAD
      Exit(False); // Single producer cannot wait for another producer to free this slot.
=======
      Exit(False); { Single producer cannot wait for another producer to free this slot }
>>>>>>> main
  end;
end;

function TSpmcQueueImpl.TryDequeue(out AValue: T): Boolean;
var
  LPos: Int64;
  LIdx: PtrUInt;
  LSeq: Int64;
begin
  while True do
  begin
    LPos := AtomicLoad64(FDequeuePos, moRelaxed);
    LIdx := PtrUInt(LPos) and FMask;
    LSeq := AtomicLoad64(FSlots[LIdx].Sequence, moAcquire);
    if LSeq = LPos + 2 then
    begin
      if AtomicCompareExchange64(FDequeuePos, LPos, LPos + 1, moRelaxed) = LPos then
      begin
        AValue := FSlots[LIdx].Value;
        FSlots[LIdx].Value := Default(T);
        AtomicStore64(FSlots[LIdx].Sequence, LPos + Int64(FCapacity), moRelease);
        LockFreeNotifySpace(@FSpaceEpoch, @FSpaceWaiters);
        Exit(True);
      end;
    end
    else if LSeq <= LPos + 1 then
      Exit(False)
    else
      CpuPause;
  end;
end;

function TSpmcQueueImpl.EnqueueWait(const AValue: T): Boolean;
var
  LEpoch: Int32;
begin
  if TryEnqueue(AValue) then
    Exit(True);
  while True do
  begin
    LEpoch := AtomicLoad32(FSpaceEpoch, moAcquire);
    if TryEnqueue(AValue) then
      Exit(True);
    LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, -1);
  end;
end;

function TSpmcQueueImpl.DequeueWait(out AValue: T): Boolean;
var
  LEpoch: Int32;
begin
  if TryDequeue(AValue) then
    Exit(True);
  while True do
  begin
    LEpoch := AtomicLoad32(FDataEpoch, moAcquire);
    if TryDequeue(AValue) then
      Exit(True);
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, -1);
  end;
end;

function TSpmcQueueImpl.EnqueueTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
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
    LEpoch := AtomicLoad32(FSpaceEpoch, moAcquire);
    if TryEnqueue(AValue) then
      Exit(True);
    LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, LRemaining);
  end;
end;

function TSpmcQueueImpl.DequeueTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
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
    LEpoch := AtomicLoad32(FDataEpoch, moAcquire);
    if TryDequeue(AValue) then
      Exit(True);
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LRemaining);
  end;
end;

function TSpmcQueueImpl.IsEmpty: Boolean;
begin
  Result := AtomicLoad64(FEnqueuePos, moRelaxed) <= AtomicLoad64(FDequeuePos, moRelaxed);
end;

function TSpmcQueueImpl.IsFull: Boolean;
begin
  Result := AtomicLoad64(FEnqueuePos, moRelaxed) >= (AtomicLoad64(FDequeuePos, moRelaxed) + Int64(FCapacity));
end;

function TSpmcQueueImpl.ApproxCount: PtrUInt;
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

function TSpmcQueueImpl.Capacity: PtrUInt;
begin
  Result := FCapacity;
end;

end.
