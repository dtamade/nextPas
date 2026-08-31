unit nextpas.core.lockfree.channel;
{**
 * @desc Lock-free bounded MPMC channel using sequence-based slots.
 *
 * @details Multi-producer multi-consumer channel with:
 *   - Bounded capacity with dynamic resize support
 *   - Blocking Send/Receive with timeout variants
 *   - Non-blocking TrySend/TryReceive
 *   - Close semantics with drain support
 *   - Selector integration for multiplexing
 *
 * @concurrency Thread-safe for multiple producers and consumers:
 *   - Send/TrySend: producers compete for slots
 *   - Receive/TryReceive: consumers compete for data
 *   - Close: safe to call from any thread
 *
 * @see Go channels — similar CSP model
 * @see Rust crossbeam::channel — similar bounded channel
 *
 * Preferred atomics: atomic_* + mo_* (Go/Rust parity / Q2).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.base,
  nextpas.core.lockfree.wait,
  nextpas.core.time.base;

const
  CHANNEL_NOTIFIER_NONE = 0;
  CHANNEL_NOTIFIER_ENABLED = 1;
  CHANNEL_NOTIFIER_DRAINING = 2;
  { Resize-guard stripes: threads hash onto separate counter lines so the
    per-op Enter/Leave RMW pair stays uncontended; TryResize scans them all. }
  CHANNEL_OP_STRIPES = 8; { power of 2 }

type
  TChannelNotifier = procedure(AData: Pointer) of object;

  { One resize-guard counter per stripe. The trailing full-line pad keeps
    consecutive Count fields >= 64B apart, so no two stripes can share a
    cache line at any heap placement phase (same argument as TCacheLinePad). }
  TChannelOpStripe = record
    Count: Int32;
    Pad: TCacheLinePad;
  end;

  generic TLockFreeChannelImpl<T> = class
  private
    { Separate empty/full sequence tokens so capacity=1 distinguishes full from empty.
      Same encoding as TMpmcQueue: empty(pos)=pos*2, full(pos)=pos*2+1. }
    class function EmptySequence(const APos: Int64): Int64; static; inline;
    class function FullSequence(const APos: Int64): Int64; static; inline;
    class function OpStripeIndex: PtrUInt; static; inline;
  private type
    TSlot = record
      Sequence: Int64;
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
    FDataEpoch: Int32;
    FDataWaiters: Int32;
    {$PUSH} {$WARN 05029 OFF} // padding field for cache-line isolation
    FPadSend: TCacheLinePad;
    {$POP}
    // Receiver line (mirror)
    FRecvPos: Int64;
    FSpaceEpoch: Int32;
    FSpaceWaiters: Int32;
    {$PUSH} {$WARN 05029 OFF} // padding field for cache-line isolation
    FPadRecv: TCacheLinePad;
    {$POP}
    // RMW'd by every operation from both sides (resize guard) — striped by
    // thread-id hash so the per-op RMW pair lands on an uncontended line
    // instead of ping-ponging one shared counter between all threads.
    // Each stripe carries its own full-line pad (isolates the cold tail too).
    FOpStripes: array[0..CHANNEL_OP_STRIPES - 1] of TChannelOpStripe;
    // Read-mostly control words + cold notifier state
    FClosed: Int32;
    FResizing: Int32; { 0 = normal, 1 = resize in progress }
    FNotifierLock: Int32;
    FNotifierState: Int32;
    FNotifierCallbacks: Int32;
    FNotifier: TChannelNotifier;
    FNotifierData: Pointer;
    procedure WakeAllWaiters;
    procedure NotifyData;
    procedure NotifySpace;
    procedure NotifySelector;
    procedure LockNotifier; inline;
    procedure UnlockNotifier; inline;
    function SameNotifier(const ALeft, ARight: TChannelNotifier): Boolean; inline;
    procedure EnterOperation(const AStripe: PtrUInt); inline;
    procedure LeaveOperation(const AStripe: PtrUInt); inline;
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
      @note 关闭时返回 False 而非抛异常——对齐 Go 语义：阻塞发送 panic、非阻塞发送返回 ok=false }
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
    {** @desc 尝试动态调整 Channel 容量
      @param ANewCapacity 新容量（会被向上对齐到 2 的幂）
      @returns True 调整成功，False 调整失败（Channel 已关闭或正在调整中）
      @note 非阻塞；调整期间 send/receive 会 spin 等待（<1μs） }
    function TryResize(const ANewCapacity: PtrUInt): Boolean;
  end;

  generic TLockFreeChannel<T> = class(specialize TLockFreeChannelImpl<T>)
  end;

implementation

uses
  nextpas.core.platform.thread;

class function TLockFreeChannelImpl.EmptySequence(const APos: Int64): Int64;
begin
  Result := APos * 2;
end;

class function TLockFreeChannelImpl.FullSequence(const APos: Int64): Int64;
begin
  Result := (APos * 2) + 1;
end;

constructor TLockFreeChannelImpl.Create(const ACapacity: PtrUInt);
var
  LCap: PtrUInt;
  LI: PtrUInt;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TLockFreeChannel: T must be unmanaged (no string/interface/dynarray)');
  if ACapacity = 0 then
    raise EArgumentError.Create('TLockFreeChannel: capacity must be > 0');
  inherited Create;
  LCap := LockFreeNextPow2(ACapacity);
  FCapacity := LCap;
  FMask := LCap - 1;
  SetLength(FSlots, LCap);
  for LI := 0 to LCap - 1 do
    FSlots[LI].Sequence := EmptySequence(Int64(LI));
  FSendPos := 0;
  FRecvPos := 0;
  FSpaceEpoch := 0;
  FDataEpoch := 0;
  FSpaceWaiters := 0;
  FDataWaiters := 0;
  FClosed := 0;
  FResizing := 0;
  for LI := 0 to CHANNEL_OP_STRIPES - 1 do
    FOpStripes[LI].Count := 0;
  FNotifierLock := 0;
  FNotifierState := CHANNEL_NOTIFIER_NONE;
  FNotifierCallbacks := 0;
  FNotifier := nil;
  FNotifierData := nil;
end;

destructor TLockFreeChannelImpl.Destroy;
var
  LI: PtrUInt;
begin
  { Failed construction (e.g. managed-type reject before capacity init) leaves
    FCapacity=0. PtrUInt underflow on FCapacity-1 would walk the whole address space. }
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

procedure TLockFreeChannelImpl.WakeAllWaiters;
begin
  LockFreeWakeAll(@FSpaceEpoch);
  LockFreeWakeAll(@FDataEpoch);
  NotifySelector;
end;

procedure TLockFreeChannelImpl.NotifyData;
begin
  NotifySelector;
end;

procedure TLockFreeChannelImpl.NotifySpace;
begin
  NotifySelector;
end;

procedure TLockFreeChannelImpl.LockNotifier;
var
  LExpected: Int32;
begin
  while True do
  begin
    LExpected := 0;
    if atomic_compare_exchange_strong(FNotifierLock, LExpected, 1, mo_acq_rel, mo_acquire) then
      Exit;
    CpuPause;
  end;
end;

procedure TLockFreeChannelImpl.UnlockNotifier;
begin
  atomic_store(FNotifierLock, 0, mo_release);
end;

function TLockFreeChannelImpl.SameNotifier(const ALeft, ARight: TChannelNotifier): Boolean;
var
  LLeftMethod: TMethod;
  LRightMethod: TMethod;
begin
  LLeftMethod := TMethod(ALeft);
  LRightMethod := TMethod(ARight);
  Result := (LLeftMethod.Code = LRightMethod.Code) and
    (LLeftMethod.Data = LRightMethod.Data);
end;

procedure TLockFreeChannelImpl.NotifySelector;
var
  LNotifier: TChannelNotifier;
  LData: Pointer;
begin
  { Phase E: skip notifier lock on the common path (no selector registered).
    Matched channel bench and most runtime send/recv never set a notifier. }
  if atomic_load(FNotifierState, mo_relaxed) = CHANNEL_NOTIFIER_NONE then
    Exit;
  LNotifier := nil;
  LData := nil;
  LockNotifier;
  try
    if (atomic_load(FNotifierState, mo_relaxed) = CHANNEL_NOTIFIER_ENABLED) and
       Assigned(FNotifier) then
    begin
      LNotifier := FNotifier;
      LData := FNotifierData;
      atomic_fetch_add(FNotifierCallbacks, 1, mo_acq_rel);
    end;
  finally
    UnlockNotifier;
  end;
  if Assigned(LNotifier) then
    try
      LNotifier(LData);
    finally
      atomic_fetch_sub(FNotifierCallbacks, 1, mo_acq_rel);
    end;
end;

procedure TLockFreeChannelImpl.SetNotifier(ANotifier: TChannelNotifier; AData: Pointer);
begin
  while True do
  begin
    LockNotifier;
    if Assigned(ANotifier) then
    begin
      if atomic_load(FNotifierState, mo_relaxed) = CHANNEL_NOTIFIER_DRAINING then
      begin
        UnlockNotifier;
        CpuPause;
        Continue;
      end;
      if atomic_load(FNotifierState, mo_relaxed) = CHANNEL_NOTIFIER_ENABLED then
      begin
        if SameNotifier(FNotifier, ANotifier) and (FNotifierData = AData) then
        begin
          UnlockNotifier;
          Exit;
        end;
        UnlockNotifier;
        raise EInvalidOperationError.Create(
          'TLockFreeChannel.SetNotifier: channel already belongs to another selector');
      end;
      FNotifier := ANotifier;
      FNotifierData := AData;
      atomic_store(FNotifierState, CHANNEL_NOTIFIER_ENABLED, mo_relaxed);
      UnlockNotifier;
      Exit;
    end;

    if atomic_load(FNotifierState, mo_relaxed) = CHANNEL_NOTIFIER_DRAINING then
    begin
      UnlockNotifier;
      while atomic_load(FNotifierState, mo_acquire) = CHANNEL_NOTIFIER_DRAINING do
        CpuPause;
      Continue;
    end;
    if atomic_load(FNotifierState, mo_relaxed) = CHANNEL_NOTIFIER_NONE then
    begin
      UnlockNotifier;
      Exit;
    end;
    atomic_store(FNotifierState, CHANNEL_NOTIFIER_DRAINING, mo_release);
    FNotifier := nil;
    FNotifierData := nil;
    UnlockNotifier;

    while atomic_load(FNotifierCallbacks, mo_acquire) <> 0 do
      CpuPause;
    LockNotifier;
    atomic_store(FNotifierState, CHANNEL_NOTIFIER_NONE, mo_release);
    UnlockNotifier;
    Exit;
  end;
end;

{$PUSH} {$Q-} {$R-} { hash multiply wraps mod 2^N by design }
class function TLockFreeChannelImpl.OpStripeIndex: PtrUInt;
begin
  { Thread ids (gettid) start at 1 and grow slowly, so a bare low-bit
    shift would collide across threads. Multiplying by an odd constant
    is a bijection mod 2^N and spreads any small stride across the high
    bits; take bits 24.. for the stripe. }
  Result := (PtrUInt(platform_thread_id) * PtrUInt($9E3779B9)) shr 24
    and (CHANNEL_OP_STRIPES - 1);
end;
{$POP}

procedure TLockFreeChannelImpl.EnterOperation(const AStripe: PtrUInt);
begin
  while True do
  begin
    while atomic_load(FResizing, mo_acquire) <> 0 do
      CpuPause;
    atomic_fetch_add(FOpStripes[AStripe].Count, 1, mo_acq_rel);
    if atomic_load(FResizing, mo_acquire) = 0 then
      Exit;
    atomic_fetch_sub(FOpStripes[AStripe].Count, 1, mo_acq_rel);
  end;
end;

procedure TLockFreeChannelImpl.LeaveOperation(const AStripe: PtrUInt);
begin
  atomic_fetch_sub(FOpStripes[AStripe].Count, 1, mo_acq_rel);
end;

function TLockFreeChannelImpl.TrySend(const AValue: T): Boolean;
var
  LPos: Int64;
  LIdx: PtrUInt;
  LSeq, LExpected, LDiff: Int64;
  LPosExpected: Int64;
  LBackoff: Integer;
  LI: Integer;
  LStripe: PtrUInt;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(False);
  LStripe := OpStripeIndex;
  EnterOperation(LStripe);
  try
    LBackoff := 1;
    while True do
    begin
      if atomic_load(FClosed, mo_acquire) <> 0 then
        Exit(False);
      LPos := atomic_load_64(FSendPos, mo_relaxed);
      LIdx := PtrUInt(LPos) and FMask;
      LSeq := atomic_load_64(FSlots[LIdx].Sequence, mo_acquire);
      LExpected := EmptySequence(LPos);
      LDiff := LSeq - LExpected;
      if LDiff = 0 then
      begin
        LPosExpected := LPos;
        if atomic_compare_exchange_strong_64(FSendPos, LPosExpected, LPos + 1, mo_relaxed, mo_relaxed) then
        begin
          FSlots[LIdx].Value := AValue;
          atomic_store_64(FSlots[LIdx].Sequence, FullSequence(LPos), mo_release);
          if atomic_load(FDataWaiters, mo_relaxed) > 0 then
            LockFreeNotifyData(@FDataEpoch, @FDataWaiters);
          NotifyData;
          Exit(True);
        end;
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
      else if LDiff < 0 then
        Exit(False)
      else
        CpuPause;
    end;
  finally
    LeaveOperation(LStripe);
  end;
end;

function TLockFreeChannelImpl.TrySendEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
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

procedure TLockFreeChannelImpl.Send(const AValue: T);
var
  LEpoch: Int32;
begin
  if TrySend(AValue) then
    Exit;
  while True do
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
      raise EInvalidOperationError.CreateFmt('TLockFreeChannel.Send: channel closed (capacity=%d)', [Capacity]);
    LEpoch := atomic_load(FSpaceEpoch, mo_acquire);
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
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(False);
    LRemaining := ATimeoutNs - LStart.Elapsed.AsNanoseconds;
    if LRemaining <= 0 then
      Exit(TrySend(AValue));
    LEpoch := atomic_load(FSpaceEpoch, mo_acquire);
    if TrySend(AValue) then
      Exit(True);
    LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, LRemaining);
  end;
end;

function TLockFreeChannelImpl.TryReceive(out AValue: T): Boolean;
var
  LPos: Int64;
  LIdx: PtrUInt;
  LSeq, LExpected, LDiff: Int64;
  LPosExpected: Int64;
  LBackoff: Integer;
  LI: Integer;
  LStripe: PtrUInt;
begin
  LStripe := OpStripeIndex;
  EnterOperation(LStripe);
  try
    LBackoff := 1;
    while True do
    begin
      if (atomic_load(FClosed, mo_acquire) <> 0) and (atomic_load_64(FSendPos, mo_relaxed) <= atomic_load_64(FRecvPos, mo_relaxed)) then
        Exit(False);
      LPos := atomic_load_64(FRecvPos, mo_relaxed);
      LIdx := PtrUInt(LPos) and FMask;
      LSeq := atomic_load_64(FSlots[LIdx].Sequence, mo_acquire);
      LExpected := FullSequence(LPos);
      LDiff := LSeq - LExpected;
      if LDiff = 0 then
      begin
        LPosExpected := LPos;
        if atomic_compare_exchange_strong_64(FRecvPos, LPosExpected, LPos + 1, mo_relaxed, mo_relaxed) then
        begin
          AValue := FSlots[LIdx].Value;
          FSlots[LIdx].Value := Default(T);
          atomic_store_64(FSlots[LIdx].Sequence, EmptySequence(LPos + Int64(FCapacity)), mo_release);
          if atomic_load(FSpaceWaiters, mo_relaxed) > 0 then
            LockFreeNotifySpace(@FSpaceEpoch, @FSpaceWaiters);
          NotifySpace;
          Exit(True);
        end;
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
      else if LDiff < 0 then
        Exit(False)
      else
        CpuPause;
    end;
  finally
    LeaveOperation(LStripe);
  end;
end;

function TLockFreeChannelImpl.TryReceiveEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
begin
  if TryReceive(AValue) then
  begin
    AError := lfteNone;
    Exit(True);
  end;
  { Plain TryReceive conflates empty and closed-empty as False; Ex splits them. }
  if IsClosed then
    AError := lfteClosed
  else
    AError := lfteEmpty;
  Result := False;
end;

function TLockFreeChannelImpl.Receive(out AValue: T): Boolean;
var
  LEpoch: Int32;
begin
  if TryReceive(AValue) then
    Exit(True);
  while True do
  begin
    if (atomic_load(FClosed, mo_acquire) <> 0) and IsEmpty then
      Exit(False);
    LEpoch := atomic_load(FDataEpoch, mo_acquire);
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
    if (atomic_load(FClosed, mo_acquire) <> 0) and IsEmpty then
      Exit(False);
    LRemaining := ATimeoutNs - LStart.Elapsed.AsNanoseconds;
    if LRemaining <= 0 then
      Exit(TryReceive(AValue));
    LEpoch := atomic_load(FDataEpoch, mo_acquire);
    if TryReceive(AValue) then
      Exit(True);
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LRemaining);
  end;
end;

procedure TLockFreeChannelImpl.Close;
begin
  if atomic_exchange(FClosed, 1, mo_acq_rel) <> 0 then
    Exit;
  WakeAllWaiters;
end;

function TLockFreeChannelImpl.IsClosed: Boolean;
begin
  Result := atomic_load(FClosed, mo_relaxed) <> 0;
end;

function TLockFreeChannelImpl.IsEmpty: Boolean;
begin
  Result := ApproxLen = 0;
end;

function TLockFreeChannelImpl.ApproxLen: PtrUInt;
var
  LSent: Int64;
  LRecv: Int64;
  LStripe: PtrUInt;
begin
  LStripe := OpStripeIndex;
  EnterOperation(LStripe);
  try
    LSent := atomic_load_64(FSendPos, mo_relaxed);
    LRecv := atomic_load_64(FRecvPos, mo_relaxed);
    if LSent > LRecv then
      Result := PtrUInt(LSent - LRecv)
    else
      Result := 0;
  finally
    LeaveOperation(LStripe);
  end;
end;

function TLockFreeChannelImpl.Capacity: PtrUInt;
var
  LStripe: PtrUInt;
begin
  LStripe := OpStripeIndex;
  EnterOperation(LStripe);
  try
    Result := FCapacity;
  finally
    LeaveOperation(LStripe);
  end;
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
  LResizeExpected: Int32;
begin
  Result := False;
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(False);
  if ANewCapacity = 0 then
    Exit(False);
  { Acquire resize flag }
  LResizeExpected := 0;
  if not atomic_compare_exchange_strong(FResizing, LResizeExpected, 1, mo_acq_rel, mo_acquire) then
    Exit(False);
  try
    { Quiescence: once FResizing=1 is visible, any new entrant that bumps a
      stripe re-checks FResizing and backs off — a stripe observed at 0 here
      can only see transient (immediately undone) increments afterwards. }
    for LI := 0 to CHANNEL_OP_STRIPES - 1 do
      while atomic_load(FOpStripes[LI].Count, mo_acquire) <> 0 do
        CpuPause;
    { Compute new capacity (power of 2, at least 1) }
    LNewCap := LockFreeNextPow2(ANewCapacity);
    if LNewCap < 1 then
      LNewCap := 1;
    if LNewCap = FCapacity then
      Exit(True);

    LSend := atomic_load_64(FSendPos, mo_relaxed);
    LRecv := atomic_load_64(FRecvPos, mo_relaxed);
    if LSend > LRecv then
      LCount := PtrUInt(LSend - LRecv)
    else
      LCount := 0;
    if LCount > LNewCap then
      Exit(False);

    LNewMask := LNewCap - 1;
    { Allocate new slots with empty/full sequence tokens (capacity=1 safe). }
    SetLength(LNewSlots, LNewCap);
    for LI := 0 to LNewCap - 1 do
      LNewSlots[LI].Sequence := EmptySequence(Int64(LI));

    { Migrate existing data: read positions first }
    if LCount > 0 then
      for LI := 0 to LCount - 1 do
      begin
        LOldIdx := PtrUInt(LRecv + Int64(LI)) and FMask;
        LNewIdx := LI and LNewMask;
        LNewSlots[LNewIdx].Value := FSlots[LOldIdx].Value;
        atomic_store_64(LNewSlots[LNewIdx].Sequence, FullSequence(Int64(LI)), mo_release);
      end;

    FSlots := LNewSlots;
    FCapacity := LNewCap;
    FMask := LNewMask;
    // moRelease: 确保所有新槽位数据对后续读者可见
    atomic_store_64(FRecvPos, 0, mo_release);
    atomic_store_64(FSendPos, Int64(LCount), mo_release);
    Result := True;
  finally
    atomic_store(FResizing, 0, mo_release);
  end;
  if Result then
  begin
    LockFreeNotifySpace(@FSpaceEpoch, @FSpaceWaiters);
    NotifySpace;
  end;
end;

end.
