unit nextpas.core.lockfree.channel;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.base,
  nextpas.core.lockfree.wait,
  nextpas.core.time.base;

type
  generic TLockFreeChannelImpl<T> = class
  private type
    TSlot = record
      Sequence: Int64;
      Value: T;
    end;
  private
    FSlots: array of TSlot;
    FCapacity: PtrUInt;
    FMask: PtrUInt;
    FSendPos: Int64;
    FRecvPos: Int64;
    FSpaceEpoch: Int32;
    FSpaceWaiters: Int32;
    FDataEpoch: Int32;
    FDataWaiters: Int32;
    FClosed: Int32;
    procedure WakeAllWaiters;
  public
    {** @desc 创建有界无锁 Channel }
    constructor Create(const ACapacity: PtrUInt);
    destructor Destroy; override;

    {** @desc 阻塞发送，直到有空间或 channel 关闭 }
    procedure Send(const AValue: T);
    {** @desc 非阻塞发送，无空间时立即返回 False }
    function TrySend(const AValue: T): Boolean;
    {** @desc 带超时发送，超时返回 False }
    function SendTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;

    {** @desc 阻塞接收；channel 关闭且无数据时返回 False }
    function Receive(out AValue: T): Boolean;
    {** @desc 非阻塞接收；无数据时返回 False }
    function TryReceive(out AValue: T): Boolean;
    {** @desc 带超时接收；超时返回 False }
    function ReceiveTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;

    {** @desc 关闭 Channel（唤醒所有等待者，已入队数据仍可读） }
    procedure Close;
    {** @desc Channel 是否已关闭 }
    function IsClosed: Boolean;
    {** @desc 近似队列长度 }
    function ApproxLen: PtrUInt;
    {** @desc Channel 容量 }
    function Capacity: PtrUInt;
  end;

  generic TLockFreeChannel<T> = class(specialize TLockFreeChannelImpl<T>)
  end;

implementation

constructor TLockFreeChannelImpl.Create(const ACapacity: PtrUInt);
var
  LCap: PtrUInt;
  LI: PtrUInt;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TLockFreeChannel: T must be unmanaged');
  if ACapacity = 0 then
    raise EArgumentError.Create('TLockFreeChannel: capacity must be > 0');
  inherited Create;
  LCap := LockFreeNextPow2(ACapacity);
  FCapacity := LCap;
  FMask := LCap - 1;
  SetLength(FSlots, LCap);
  for LI := 0 to LCap - 1 do
    FSlots[LI].Sequence := Int64(LI);
  FSendPos := 0;
  FRecvPos := 0;
  FSpaceEpoch := 0;
  FDataEpoch := 0;
  FSpaceWaiters := 0;
  FDataWaiters := 0;
  FClosed := 0;
end;

destructor TLockFreeChannelImpl.Destroy;
var
  LI: PtrUInt;
begin
  for LI := 0 to FCapacity - 1 do
    FSlots[LI].Value := Default(T);
  inherited;
end;

procedure TLockFreeChannelImpl.WakeAllWaiters;
begin
  LockFreeWakeAll(@FSpaceEpoch);
  LockFreeWakeAll(@FDataEpoch);
end;

function TLockFreeChannelImpl.TrySend(const AValue: T): Boolean;
var
  LPos: Int64;
  LIdx: PtrUInt;
  LSeq: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  LPos := AtomicLoad64(FSendPos, moRelaxed);
  while True do
  begin
    LIdx := PtrUInt(LPos) and FMask;
    LSeq := AtomicLoad64(FSlots[LIdx].Sequence, moAcquire);
    if LSeq = LPos then
    begin
      if AtomicCompareExchange64(FSendPos, LPos, LPos + 1, moRelaxed) = LPos then
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
      Exit(False);
  end;
end;

procedure TLockFreeChannelImpl.Send(const AValue: T);
var
  LEpoch: Int32;
begin
  if TrySend(AValue) then
    Exit;
  while True do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      raise EInvalidOperationError.Create('TLockFreeChannel.Send: channel closed');
    LEpoch := AtomicLoad32(FSpaceEpoch, moAcquire);
    if TrySend(AValue) then
      Exit;
    LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, -1);
  end;
end;

function TLockFreeChannelImpl.SendTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
var
  LEpoch: Int32;
  LStart: TInstant;
  LRemaining: Int64;
begin
  if TrySend(AValue) then
    Exit(True);
  LStart := TInstant.Now;
  while True do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(False);
    LRemaining := ATimeoutNs - LStart.Elapsed.AsNanoseconds;
    if LRemaining <= 0 then
      Exit(TrySend(AValue));
    LEpoch := AtomicLoad32(FSpaceEpoch, moAcquire);
    if TrySend(AValue) then
      Exit(True);
    LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, LRemaining);
  end;
end;

function TLockFreeChannelImpl.TryReceive(out AValue: T): Boolean;
var
  LPos: Int64;
  LIdx: PtrUInt;
  LSeq: Int64;
begin
  while True do
  begin
    if (AtomicLoad32(FClosed, moAcquire) <> 0) and (AtomicLoad64(FSendPos, moRelaxed) <= AtomicLoad64(FRecvPos, moRelaxed)) then
      Exit(False);
    LPos := AtomicLoad64(FRecvPos, moRelaxed);
    LIdx := PtrUInt(LPos) and FMask;
    LSeq := AtomicLoad64(FSlots[LIdx].Sequence, moAcquire);
    if LSeq = LPos + 2 then
    begin
      if AtomicCompareExchange64(FRecvPos, LPos, LPos + 1, moRelaxed) = LPos then
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

function TLockFreeChannelImpl.Receive(out AValue: T): Boolean;
var
  LEpoch: Int32;
begin
  if TryReceive(AValue) then
    Exit(True);
  while True do
  begin
    if (AtomicLoad32(FClosed, moAcquire) <> 0) and (AtomicLoad64(FSendPos, moRelaxed) <= AtomicLoad64(FRecvPos, moRelaxed)) then
      Exit(False);
    LEpoch := AtomicLoad32(FDataEpoch, moAcquire);
    if TryReceive(AValue) then
      Exit(True);
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, -1);
  end;
end;

function TLockFreeChannelImpl.ReceiveTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
var
  LEpoch: Int32;
  LStart: TInstant;
  LRemaining: Int64;
begin
  if TryReceive(AValue) then
    Exit(True);
  LStart := TInstant.Now;
  while True do
  begin
    if (AtomicLoad32(FClosed, moAcquire) <> 0) and (AtomicLoad64(FSendPos, moRelaxed) <= AtomicLoad64(FRecvPos, moRelaxed)) then
      Exit(False);
    LRemaining := ATimeoutNs - LStart.Elapsed.AsNanoseconds;
    if LRemaining <= 0 then
      Exit(TryReceive(AValue));
    LEpoch := AtomicLoad32(FDataEpoch, moAcquire);
    if TryReceive(AValue) then
      Exit(True);
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LRemaining);
  end;
end;

procedure TLockFreeChannelImpl.Close;
begin
  if AtomicExchange32(FClosed, 1, moAcqRel) <> 0 then
    Exit;
  WakeAllWaiters;
end;

function TLockFreeChannelImpl.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moRelaxed) <> 0;
end;

function TLockFreeChannelImpl.ApproxLen: PtrUInt;
var
  LSent: Int64;
  LRecv: Int64;
begin
  LSent := AtomicLoad64(FSendPos, moRelaxed);
  LRecv := AtomicLoad64(FRecvPos, moRelaxed);
  if LSent > LRecv then
    Result := PtrUInt(LSent - LRecv)
  else
    Result := 0;
end;

function TLockFreeChannelImpl.Capacity: PtrUInt;
begin
  Result := FCapacity;
end;

end.
