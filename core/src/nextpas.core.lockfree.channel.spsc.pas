unit nextpas.core.lockfree.channel.spsc;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.base,
  nextpas.core.lockfree.wait,
  nextpas.core.platform.time;

type
  {** @desc 单生产者单消费者有界 Channel（高性能）
    @details 专为 1P1C 场景优化，使用原子 load/store 替代 CAS。
      性能接近 Go channel，但保持无锁设计。

      **使用场景**:
      - 单生产者单消费者
      - 需要高性能的有界通道
      - 不需要 MPMC 支持

      **限制**:
      - 仅支持 1P1C，不支持 MPMC
      - 不支持 Close（需要手动同步）
    }
  generic TLockFreeChannelSpscImpl<T> = class
  private type
    TSlot = record
      Value: T;
    end;
  private
    FSlots: array of TSlot;
    FCapacity: PtrUInt;
    FMask: PtrUInt;
    { Cache line padding to avoid false sharing }
    FSendPos: Int64;
    FSendPad: array[0..47] of Byte;
    FRecvPos: Int64;
    FRecvPad: array[0..47] of Byte;
    FSpaceEpoch: Int32;
    FSpaceWaiters: Int32;
    FDataEpoch: Int32;
    FDataWaiters: Int32;
    FClosed: Int32;
  public
    {** @desc 创建有界 SPSC Channel }
    constructor Create(const ACapacity: PtrUInt);
    destructor Destroy; override;

    {** @desc 阻塞发送，直到有空间或 channel 关闭
      @raises EInvalidOperationError 如果 channel 已关闭 }
    procedure Send(const AValue: T);
    {** @desc 非阻塞发送，无空间或已关闭时立即返回 False }
    function TrySend(const AValue: T): Boolean;
    {** @desc 带超时发送，超时或已关闭返回 False }
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
    {** @desc Channel 是否为空 }
    function IsEmpty: Boolean;
    {** @desc 近似队列长度 }
    function ApproxLen: PtrUInt;
    {** @desc Channel 容量 }
    function Capacity: PtrUInt;
  end;

  generic TLockFreeChannelSpsc<T> = class(specialize TLockFreeChannelSpscImpl<T>)
  end;

implementation

constructor TLockFreeChannelSpscImpl.Create(const ACapacity: PtrUInt);
var
  LCap: PtrUInt;
  LI: PtrUInt;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TLockFreeChannelSpsc: T must be unmanaged');
  if ACapacity = 0 then
    raise EArgumentError.Create('TLockFreeChannelSpsc: capacity must be > 0');
  inherited Create;
  LCap := LockFreeNextPow2(ACapacity);
  FCapacity := LCap;
  FMask := LCap - 1;
  SetLength(FSlots, LCap);
  for LI := 0 to LCap - 1 do
    FSlots[LI].Value := Default(T);
  FSendPos := 0;
  FRecvPos := 0;
  FSpaceEpoch := 0;
  FDataEpoch := 0;
  FSpaceWaiters := 0;
  FDataWaiters := 0;
  FClosed := 0;
end;

destructor TLockFreeChannelSpscImpl.Destroy;
var
  LI: PtrUInt;
begin
  for LI := 0 to FCapacity - 1 do
    FSlots[LI].Value := Default(T);
  inherited;
end;

function TLockFreeChannelSpscImpl.TrySend(const AValue: T): Boolean;
var
  LSendPos, LRecvPos: Int64;
  LIdx: PtrUInt;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  LSendPos := AtomicLoad64(FSendPos, moRelaxed);
  LRecvPos := AtomicLoad64(FRecvPos, moAcquire);
  if LSendPos - LRecvPos >= Int64(FCapacity) then
    Exit(False);
  LIdx := PtrUInt(LSendPos) and FMask;
  FSlots[LIdx].Value := AValue;
  AtomicStore64(FSendPos, LSendPos + 1, moRelease);
  LockFreeNotifyData(@FDataEpoch, @FDataWaiters);
  Result := True;
end;

procedure TLockFreeChannelSpscImpl.Send(const AValue: T);
var
  LEpoch: Int32;
begin
  if TrySend(AValue) then
    Exit;
  while True do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      raise EInvalidOperationError.Create('TLockFreeChannelSpsc.Send: channel closed');
    LEpoch := AtomicLoad32(FSpaceEpoch, moAcquire);
    if TrySend(AValue) then
      Exit;
    LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, -1);
  end;
end;

function TLockFreeChannelSpscImpl.SendTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
var
  LEpoch: Int32;
  LElapsed: Int64;
  LStart: UInt64;
  LRemaining: Int64;
begin
  if TrySend(AValue) then
    Exit(True);
  LElapsed := 0;
  LStart := platform_monotonic_ns;
  while True do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(False);
    LRemaining := ATimeoutNs - LElapsed;
    if LRemaining <= 0 then
      Exit(TrySend(AValue));
    LEpoch := AtomicLoad32(FSpaceEpoch, moAcquire);
    if TrySend(AValue) then
      Exit(True);
    LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, LRemaining);
    LElapsed := Int64(platform_monotonic_ns - LStart);
  end;
end;

function TLockFreeChannelSpscImpl.TryReceive(out AValue: T): Boolean;
var
  LSendPos, LRecvPos: Int64;
  LIdx: PtrUInt;
begin
  LRecvPos := AtomicLoad64(FRecvPos, moRelaxed);
  LSendPos := AtomicLoad64(FSendPos, moAcquire);
  if LRecvPos >= LSendPos then
  begin
    if (AtomicLoad32(FClosed, moAcquire) <> 0) and (LRecvPos >= AtomicLoad64(FSendPos, moAcquire)) then
      Exit(False);
    Exit(False);
  end;
  LIdx := PtrUInt(LRecvPos) and FMask;
  AValue := FSlots[LIdx].Value;
  FSlots[LIdx].Value := Default(T);
  AtomicStore64(FRecvPos, LRecvPos + 1, moRelease);
  LockFreeNotifySpace(@FSpaceEpoch, @FSpaceWaiters);
  Result := True;
end;

function TLockFreeChannelSpscImpl.Receive(out AValue: T): Boolean;
var
  LEpoch: Int32;
begin
  if TryReceive(AValue) then
    Exit(True);
  while True do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(TryReceive(AValue));
    LEpoch := AtomicLoad32(FDataEpoch, moAcquire);
    if TryReceive(AValue) then
      Exit(True);
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, -1);
  end;
end;

function TLockFreeChannelSpscImpl.ReceiveTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
var
  LEpoch: Int32;
  LElapsed: Int64;
  LStart: UInt64;
  LRemaining: Int64;
begin
  if TryReceive(AValue) then
    Exit(True);
  LElapsed := 0;
  LStart := platform_monotonic_ns;
  while True do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(TryReceive(AValue));
    LRemaining := ATimeoutNs - LElapsed;
    if LRemaining <= 0 then
      Exit(TryReceive(AValue));
    LEpoch := AtomicLoad32(FDataEpoch, moAcquire);
    if TryReceive(AValue) then
      Exit(True);
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LRemaining);
    LElapsed := Int64(platform_monotonic_ns - LStart);
  end;
end;

procedure TLockFreeChannelSpscImpl.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
  LockFreeWakeAll(@FSpaceEpoch);
  LockFreeWakeAll(@FDataEpoch);
end;

function TLockFreeChannelSpscImpl.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TLockFreeChannelSpscImpl.IsEmpty: Boolean;
begin
  Result := AtomicLoad64(FRecvPos, moAcquire) >= AtomicLoad64(FSendPos, moAcquire);
end;

function TLockFreeChannelSpscImpl.ApproxLen: PtrUInt;
var
  LSend, LRecv: Int64;
begin
  LSend := AtomicLoad64(FSendPos, moAcquire);
  LRecv := AtomicLoad64(FRecvPos, moAcquire);
  if LSend > LRecv then
    Result := PtrUInt(LSend - LRecv)
  else
    Result := 0;
end;

function TLockFreeChannelSpscImpl.Capacity: PtrUInt;
begin
  Result := FCapacity;
end;

end.
