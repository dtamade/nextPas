unit nextpas.core.lockfree.channel.spsc;

{ Preferred atomics: atomic_* + mo_* (Go/Rust parity / Q2). }

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
    {$PUSH} {$WARN 05029 OFF} // keep the read-mostly header off the hot lines
    FPadHeader: TCacheLinePad;
    {$POP}
    // Grouped by ACCESSING THREAD; wait cells live with the notifying side.
    // (The former hand-rolled 48-byte pads never reached one line: 8+48=56.)
    // Sender line
    FSendPos: Int64;
    FRecvCache: Int64;  // sender-private cache of FRecvPos (refresh only on apparent-full)
    FDataEpoch: Int32;
    FDataWaiters: Int32;
    {$PUSH} {$WARN 05029 OFF} // padding field for cache-line isolation
    FPadSend: TCacheLinePad;
    {$POP}
    // Receiver line (mirror)
    FRecvPos: Int64;
    FSendCache: Int64;  // receiver-private cache of FSendPos (refresh only on apparent-empty)
    FSpaceEpoch: Int32;
    FSpaceWaiters: Int32;
    {$PUSH} {$WARN 05029 OFF} // padding field for cache-line isolation
    FPadRecv: TCacheLinePad;
    {$POP}
    // Cold shared fields
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
    {** @desc 非阻塞发送并返回失败原因（full vs closed）；成功 AError=lfteNone }
    function TrySendEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
    {** @desc 带超时发送，超时或已关闭返回 False }
    function SendTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;

    {** @desc 阻塞接收；channel 关闭且无数据时返回 False }
    function Receive(out AValue: T): Boolean;
    {** @desc 非阻塞接收；无数据时返回 False }
    function TryReceive(out AValue: T): Boolean;
    {** @desc 非阻塞接收并返回失败原因（empty vs closed-empty） }
    function TryReceiveEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
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
    raise EArgumentError.Create('TLockFreeChannelSpsc: T must be unmanaged (no string/interface/dynarray)');
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
  FRecvCache := 0;
  FSendCache := 0;
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
  { Failed construction leaves FCapacity=0; guard against PtrUInt underflow. }
  if FCapacity = 0 then
  begin
    inherited;
    Exit;
  end;
  Close;
  for LI := 0 to FCapacity - 1 do
    FSlots[LI].Value := Default(T);
  inherited;
end;

function TLockFreeChannelSpscImpl.TrySend(const AValue: T): Boolean;
var
  LSendPos: Int64;
  LIdx: PtrUInt;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(False);
  LSendPos := atomic_load_64(FSendPos, mo_relaxed);
  if LSendPos - FRecvCache >= Int64(FCapacity) then
  begin
    FRecvCache := atomic_load_64(FRecvPos, mo_acquire);
    if LSendPos - FRecvCache >= Int64(FCapacity) then
      Exit(False);
  end;
  LIdx := PtrUInt(LSendPos) and FMask;
  FSlots[LIdx].Value := AValue;
  atomic_store_64(FSendPos, LSendPos + 1, mo_release);
  { Fast path: only notify if there are waiters }
  if atomic_load(FDataWaiters, mo_relaxed) > 0 then
    LockFreeNotifyData(@FDataEpoch, @FDataWaiters);
  Result := True;
end;

function TLockFreeChannelSpscImpl.TrySendEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
begin
  if TrySend(AValue) then
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

procedure TLockFreeChannelSpscImpl.Send(const AValue: T);
var
  LEpoch: Int32;
begin
  if TrySend(AValue) then
    Exit;
  while True do
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
      raise EInvalidOperationError.Create('TLockFreeChannelSpsc.Send: channel closed');
    LEpoch := atomic_load(FSpaceEpoch, mo_acquire);
    if TrySend(AValue) then
      Exit;
    LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, LOCKFREE_WAIT_TIMEOUT_NS);
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
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(False);
    LRemaining := ATimeoutNs - LElapsed;
    if LRemaining <= 0 then
      Exit(TrySend(AValue));
    LEpoch := atomic_load(FSpaceEpoch, mo_acquire);
    if TrySend(AValue) then
      Exit(True);
    LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, LRemaining);
    LElapsed := Int64(platform_monotonic_ns - LStart);
  end;
end;

function TLockFreeChannelSpscImpl.TryReceive(out AValue: T): Boolean;
var
  LRecvPos: Int64;
  LIdx: PtrUInt;
begin
  LRecvPos := atomic_load_64(FRecvPos, mo_relaxed);
  if LRecvPos >= FSendCache then
  begin
    FSendCache := atomic_load_64(FSendPos, mo_acquire);
    if LRecvPos >= FSendCache then
      Exit(False);
  end;
  LIdx := PtrUInt(LRecvPos) and FMask;
  AValue := FSlots[LIdx].Value;
  FSlots[LIdx].Value := Default(T);
  atomic_store_64(FRecvPos, LRecvPos + 1, mo_release);
  { Fast path: only notify if there are waiters }
  if atomic_load(FSpaceWaiters, mo_relaxed) > 0 then
    LockFreeNotifySpace(@FSpaceEpoch, @FSpaceWaiters);
  Result := True;
end;

function TLockFreeChannelSpscImpl.TryReceiveEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
begin
  if TryReceive(AValue) then
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

function TLockFreeChannelSpscImpl.Receive(out AValue: T): Boolean;
var
  LEpoch: Int32;
begin
  if TryReceive(AValue) then
    Exit(True);
  while True do
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(TryReceive(AValue));
    LEpoch := atomic_load(FDataEpoch, mo_acquire);
    if TryReceive(AValue) then
      Exit(True);
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LOCKFREE_WAIT_TIMEOUT_NS);
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
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(TryReceive(AValue));
    LRemaining := ATimeoutNs - LElapsed;
    if LRemaining <= 0 then
      Exit(TryReceive(AValue));
    LEpoch := atomic_load(FDataEpoch, mo_acquire);
    if TryReceive(AValue) then
      Exit(True);
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LRemaining);
    LElapsed := Int64(platform_monotonic_ns - LStart);
  end;
end;

procedure TLockFreeChannelSpscImpl.Close;
begin
  atomic_store(FClosed, 1, mo_release);
  LockFreeWakeAll(@FSpaceEpoch);
  LockFreeWakeAll(@FDataEpoch);
end;

function TLockFreeChannelSpscImpl.IsClosed: Boolean;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

function TLockFreeChannelSpscImpl.IsEmpty: Boolean;
begin
  Result := atomic_load_64(FRecvPos, mo_acquire) >= atomic_load_64(FSendPos, mo_acquire);
end;

function TLockFreeChannelSpscImpl.ApproxLen: PtrUInt;
var
  LSend, LRecv: Int64;
begin
  LSend := atomic_load_64(FSendPos, mo_acquire);
  LRecv := atomic_load_64(FRecvPos, mo_acquire);
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
