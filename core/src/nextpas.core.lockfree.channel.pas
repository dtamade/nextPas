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
  TChannelNotifier = procedure(AData: Pointer) of object;

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
    { Cache line padding to avoid false sharing between producer and consumer }
    FSendPos: Int64;
    FSendPad: array[0..47] of Byte; { Pad to 64 bytes }
    FRecvPos: Int64;
    FRecvPad: array[0..47] of Byte; { Pad to 64 bytes }
    FSpaceEpoch: Int32;
    FSpaceWaiters: Int32;
    FDataEpoch: Int32;
    FDataWaiters: Int32;
    FClosed: Int32;
    FResizing: Int32; { 0 = normal, 1 = resize in progress }
    FNotifier: TChannelNotifier;
    FNotifierData: Pointer;
    procedure WakeAllWaiters;
    procedure NotifyData;
    procedure NotifySpace;
    procedure SpinWhileResizing; inline;
  public
    {** @desc 创建有界无锁 Channel }
    constructor Create(const ACapacity: PtrUInt);
    destructor Destroy; override;

    {** @desc 设置状态变更通知器（供 Selector 使用）
      @param ANotifier 通知回调
      @param AData 通知器上下文数据 }
    procedure SetNotifier(ANotifier: TChannelNotifier; AData: Pointer);

    {** @desc 阻塞发送，直到有空间或 channel 关闭
      @raises EInvalidOperationError 如果 channel 已关闭（与 Go 的 panic 语义对齐） }
    procedure Send(const AValue: T);
    {** @desc 非阻塞发送，无空间或已关闭时立即返回 False
      @note 关闭时返回 False 而非抛异常——与 Go 的 `ch <- v` (panic) vs `select { case ch <- v: }` (ok=false) 语义对齐 }
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
    {** @desc 尝试动态调整 Channel 容量
      @param ANewCapacity 新容量（会被向上对齐到 2 的幂）
      @returns True 调整成功，False 调整失败（Channel 已关闭或正在调整中）
      @note 非阻塞；调整期间 send/receive 会 spin 等待（<1μs） }
    function TryResize(const ANewCapacity: PtrUInt): Boolean;
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
  FResizing := 0;
  FNotifier := nil;
  FNotifierData := nil;
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
  if Assigned(FNotifier) then
    FNotifier(FNotifierData);
end;

procedure TLockFreeChannelImpl.NotifyData;
begin
  if Assigned(FNotifier) then
    FNotifier(FNotifierData);
end;

procedure TLockFreeChannelImpl.NotifySpace;
begin
  if Assigned(FNotifier) then
    FNotifier(FNotifierData);
end;

procedure TLockFreeChannelImpl.SetNotifier(ANotifier: TChannelNotifier; AData: Pointer);
begin
  FNotifier := ANotifier;
  FNotifierData := AData;
end;

procedure TLockFreeChannelImpl.SpinWhileResizing;
begin
  while AtomicLoad32(FResizing, moAcquire) <> 0 do
    CpuPause;
end;

function TLockFreeChannelImpl.TrySend(const AValue: T): Boolean;
var
  LPos: Int64;
  LIdx: PtrUInt;
  LSeq: Int64;
  LBackoff: Integer;
  LI: Integer;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  SpinWhileResizing;
  LBackoff := 1;
  while True do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(False);
    LPos := AtomicLoad64(FSendPos, moRelaxed);
    LIdx := PtrUInt(LPos) and FMask;
    LSeq := AtomicLoad64(FSlots[LIdx].Sequence, moAcquire);
    if LSeq = LPos then
    begin
      if AtomicCompareExchange64(FSendPos, LPos, LPos + 1, moRelaxed) = LPos then
      begin
        FSlots[LIdx].Value := AValue;
        AtomicStore64(FSlots[LIdx].Sequence, LPos + 1, moRelease);
        { Fast path: only notify if there are waiters }
        if AtomicLoad32(FDataWaiters, moRelaxed) > 0 then
          LockFreeNotifyData(@FDataEpoch, @FDataWaiters);
        NotifyData;
        Exit(True);
      end;
      { CAS failed — another sender won this slot }
      if LBackoff < 256 then
      begin
        LI := LBackoff + Integer(LPos and 3);
        repeat
          CpuPause;
          Dec(LI);
        until LI <= 0;
        LBackoff := LBackoff * 2;
      end
      else
        CpuPause;
    end
    else if LSeq < LPos then
      Exit(False)
    else
      CpuPause;
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
      raise EInvalidOperationError.CreateFmt('TLockFreeChannel.Send: channel closed (capacity=%d)', [FCapacity]);
    LEpoch := AtomicLoad32(FSpaceEpoch, moAcquire);
    if TrySend(AValue) then
      Exit;
    LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, LOCKFREE_WAIT_TIMEOUT_NS);
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
  LBackoff: Integer;
  LI: Integer;
begin
  SpinWhileResizing;
  LBackoff := 1;
  while True do
  begin
    if (AtomicLoad32(FClosed, moAcquire) <> 0) and (AtomicLoad64(FSendPos, moRelaxed) <= AtomicLoad64(FRecvPos, moRelaxed)) then
      Exit(False);
    LPos := AtomicLoad64(FRecvPos, moRelaxed);
    LIdx := PtrUInt(LPos) and FMask;
    LSeq := AtomicLoad64(FSlots[LIdx].Sequence, moAcquire);
    if LSeq = LPos + 1 then
    begin
      if AtomicCompareExchange64(FRecvPos, LPos, LPos + 1, moRelaxed) = LPos then
      begin
        AValue := FSlots[LIdx].Value;
        FSlots[LIdx].Value := Default(T);
        AtomicStore64(FSlots[LIdx].Sequence, LPos + Int64(FCapacity), moRelease);
        { Fast path: only notify if there are waiters }
        if AtomicLoad32(FSpaceWaiters, moRelaxed) > 0 then
          LockFreeNotifySpace(@FSpaceEpoch, @FSpaceWaiters);
        NotifySpace;
        Exit(True);
      end;
      { CAS failed — another receiver won this slot }
      if LBackoff < 256 then
      begin
        LI := LBackoff + Integer(LPos and 3);
        repeat
          CpuPause;
          Dec(LI);
        until LI <= 0;
        LBackoff := LBackoff * 2;
      end
      else
        CpuPause;
    end
    else if LSeq < LPos + 1 then
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
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LOCKFREE_WAIT_TIMEOUT_NS);
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

function TLockFreeChannelImpl.IsEmpty: Boolean;
begin
  Result := ApproxLen = 0;
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

function TLockFreeChannelImpl.TryResize(const ANewCapacity: PtrUInt): Boolean;
var
  LNewCap: PtrUInt;
  LNewMask: PtrUInt;
  LNewSlots: array of TSlot;
  LSend, LRecv: Int64;
  LCount: PtrUInt;
  LI: PtrUInt;
  LOldIdx, LNewIdx: PtrUInt;
begin
  Result := False;
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  if ANewCapacity = 0 then
    Exit(False);
  { Acquire resize flag }
  if AtomicCompareExchange32(FResizing, 0, 1, moAcqRel) <> 0 then
    Exit(False);
  try
    { Compute new capacity (power of 2, at least 1) }
    LNewCap := LockFreeNextPow2(ANewCapacity);
    if LNewCap < 1 then
      LNewCap := 1;
    if LNewCap = FCapacity then
      Exit(True);

    LSend := AtomicLoad64(FSendPos, moRelaxed);
    LRecv := AtomicLoad64(FRecvPos, moRelaxed);
    if LSend > LRecv then
      LCount := PtrUInt(LSend - LRecv)
    else
      LCount := 0;
    if LCount > LNewCap then
      Exit(False);

    LNewMask := LNewCap - 1;
    { Allocate new slots }
    SetLength(LNewSlots, LNewCap);
    for LI := 0 to LNewCap - 1 do
      LNewSlots[LI].Sequence := Int64(LI);

    { Migrate existing data: read positions first }
    if LCount > 0 then
      for LI := 0 to LCount - 1 do
      begin
        LOldIdx := PtrUInt(LRecv + Int64(LI)) and FMask;
        LNewIdx := PtrUInt(LRecv + Int64(LI)) and LNewMask;
        LNewSlots[LNewIdx].Value := FSlots[LOldIdx].Value;
        { Mark slot as ready for receive: sequence = position + 1 }
        AtomicStore64(LNewSlots[LNewIdx].Sequence, LRecv + Int64(LI) + 1, moRelease);
      end;

    { Swap buffer pointers }
    FSlots := LNewSlots;
    FCapacity := LNewCap;
    FMask := LNewMask;
    Result := True;
  finally
    AtomicStore32(FResizing, 0, moRelease);
  end;
end;

end.
