unit nextpas.core.lockfree.selector.impl;
{**
 * @desc Channel Selector implementation for multiplexing.
 *
 * @details Go-style select for channels (same element type T):
 *   - AddRecv: register channel for receiving
 *   - AddSend: register channel for sending
 *   - Select: blocking wait for any case
 *   - TrySelect: non-blocking full scan — Go select-with-default 等价物
 *   - SelectTimeout: blocking with timeout
 *   - Clear: reset for reuse
 *
 * Case choice: PollOnce walks Add order (index 0 first). When several cases
 * are ready, the earliest registered wins (not random like Go).
 *
 * Wait path: spin (SELECTOR_MAX_SPIN) then LockFreeWaitData on FNotifyEpoch
 * (wait-address via lockfree.wait). Channels SetNotifier → NotifyChange.
 *
 * Preferred atomics: atomic_* + mo_* (Q3-a).
 *
 * @concurrency Thread-safe for single selector user:
 *   - Not thread-safe for concurrent Select calls on same selector
 *   - Thread-safe for channel operations (channels handle their own concurrency)
 *
 * @see Go select — multiplexing channels
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.base,
  nextpas.core.platform.thread,
  nextpas.core.platform.time,
  nextpas.core.lockfree.selector,
  nextpas.core.lockfree.channel,
  nextpas.core.lockfree.wait;

const
  SELECTOR_DEFAULT_CAPACITY = 4;

type
  {** @desc 多路 Channel 复用器（泛型实现，类型安全 API）
    @details 支持在同一 T 类型的多个 channel 上多路复用。
      所有 case 必须使用相同的元素类型 T（与 Go select 的类型约束一致）。

      **与 Go select 的对应关系**:
      - `case v := <-ch:` → `LSelector.AddRecv(LChannel, LOutVar)`
      - `case ch <- v:` → `LSelector.AddSend(LChannel, LValue)`
      - select 块 → LResult := LSelector.Select
      - select 块含 default → LResult := LSelector.TrySelect（Completed=False 即走 default）

      **设计约束**:
      - 所有 channel 必须是相同类型 T 的 TLockFreeChannelImpl<T>
      - 无语言级 default case 对象；用 TrySelect 表达 default
      - 多就绪时按 **Add 注册序** 选最早 case（非 Go 随机）
      - 等待：短 spin 后经 lockfree.wait 的 wait-address（非纯忙轮询）

      **与 THazardGuard/TEbrGuard 的区别**:
      - Guard 管理单个域的生命周期（RAII）
      - Selector 管理多个 channel 的多路复用
    @example
      var LSel: specialize TLockFreeSelectorImpl<Integer>;
          LCh1, LCh2: specialize TLockFreeChannelImpl<Integer>;
          LResult: TSelectResult;
          LVal: Integer;
      LSel := specialize TLockFreeSelectorImpl<Integer>.Create;
      try
        LSel.AddRecv(LCh1, LVal);
        LSel.AddSend(LCh2, 42);
        LResult := LSel.Select;
        if LResult.Completed then
          case LResult.Index of
            0: WriteLn('Received ', LVal, ' from Ch1');
            1: WriteLn('Sent 42 to Ch2');
          end;
      finally
        LSel.Free;
      end;
  }
  generic TLockFreeSelectorImpl<T> = class
  private type
    PT = ^T;
    TChannel = specialize TLockFreeChannelImpl<T>;
    TCase = record
      Channel: TChannel;
      DataPtr: PT;
      SendValuePtr: PT;   // 堆分配的发送值副本（数组扩容不影响指针）
      IsSend: Boolean;
    end;
  private
    FCases: array of TCase;
    FCount: PtrUInt;
    FNotifyEpoch: Int32;
    FNotifyWaiters: Int32;
    function PollOnce: PtrInt;
    procedure NotifyChange(AData: Pointer);
  public
    constructor Create(const AExpectedCount: PtrUInt = SELECTOR_DEFAULT_CAPACITY);
    destructor Destroy; override;

    {** @desc 添加接收 case：当 AChannel 有数据时，将值写入 AOutValue
      @param AChannel 要监听的 channel
      @param AOutValue 接收成功时写入的目标变量（Select 返回后立即可用） }
    procedure AddRecv(AChannel: TChannel; var AOutValue: T);
    {** @desc 添加发送 case：当 AChannel 有空间时，发送 AValue
      @param AChannel 要监听的 channel
      @param AValue 要发送的值 }
    procedure AddSend(AChannel: TChannel; const AValue: T);
    {** @desc 阻塞等待第一个 case 完成
      @return 结果记录：Index=完成的 case 索引（按 Add 顺序从 0 开始），Completed=True }
    function Select: TSelectResult;
    {** @desc 非阻塞尝试（Go select default 等价）：立即检查所有 case
      @return 就绪则 Completed=True + Index；否则 Completed=False（Index 通常为 -1） }
    function TrySelect: TSelectResult;
    {** @desc 带超时等待第一个 case 完成
      @param ATimeoutNs 超时时间（纳秒）
      @return 结果记录：超时则 Completed=False, Index=-1 }
    function SelectTimeout(const ATimeoutNs: Int64): TSelectResult;
    {** @desc 清空所有 case（可复用 selector 实例） }
    procedure Clear;
    {** @desc 当前已注册的 case 数 }
    function CaseCount: PtrUInt;
  end;

implementation

{ TLockFreeSelectorImpl<T> }

constructor TLockFreeSelectorImpl.Create(const AExpectedCount: PtrUInt);
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TLockFreeSelector: T must be unmanaged');
  inherited Create;
  if AExpectedCount = 0 then
    SetLength(FCases, SELECTOR_DEFAULT_CAPACITY)
  else
    SetLength(FCases, AExpectedCount);
  FCount := 0;
  FNotifyEpoch := 0;
  FNotifyWaiters := 0;
end;

destructor TLockFreeSelectorImpl.Destroy;
var
  LI: PtrUInt;
begin
  // Guard: FCount is PtrUInt (unsigned), FCount-1 wraps to MaxPtrUInt when FCount=0
  if FCount > 0 then
    for LI := 0 to FCount - 1 do
    begin
      FCases[LI].Channel.SetNotifier(nil, nil);
      if FCases[LI].IsSend and (FCases[LI].SendValuePtr <> nil) then
        Dispose(FCases[LI].SendValuePtr);
    end;
  SetLength(FCases, 0);
  inherited;
end;

procedure TLockFreeSelectorImpl.AddRecv(AChannel: TChannel; var AOutValue: T);
begin
  if not Assigned(AChannel) then
    raise EArgumentError.CreateFmt('TLockFreeSelector.AddRecv: nil channel (case count=%d)', [FCount]);
  if FCount >= PtrUInt(Length(FCases)) then
    SetLength(FCases, Length(FCases) * 2);
  FCases[FCount].Channel := AChannel;
  FCases[FCount].DataPtr := @AOutValue;
  FCases[FCount].SendValuePtr := nil;
  FCases[FCount].IsSend := False;
  AChannel.SetNotifier(@NotifyChange, Self);
  Inc(FCount);
end;

procedure TLockFreeSelectorImpl.AddSend(AChannel: TChannel; const AValue: T);
var
  LIdx: PtrUInt;
  LCopy: PT;
begin
  if not Assigned(AChannel) then
    raise EArgumentError.CreateFmt('TLockFreeSelector.AddSend: nil channel (case count=%d)', [FCount]);
  if FCount >= PtrUInt(Length(FCases)) then
    SetLength(FCases, Length(FCases) * 2);
  LIdx := FCount;
  // 堆分配值副本——指针不受 FCases 数组扩容影响
  New(LCopy);
  LCopy^ := AValue;
  FCases[LIdx].Channel := AChannel;
  FCases[LIdx].SendValuePtr := LCopy;
  FCases[LIdx].DataPtr := LCopy;
  FCases[LIdx].IsSend := True;
  try
    FCases[LIdx].Channel.SetNotifier(@NotifyChange, Self);
  except
    Dispose(LCopy);
    FCases[LIdx].Channel := nil;
    FCases[LIdx].SendValuePtr := nil;
    FCases[LIdx].DataPtr := nil;
    raise;
  end;
  Inc(FCount);
end;

procedure TLockFreeSelectorImpl.NotifyChange(AData: Pointer);
begin
  atomic_fetch_add(FNotifyEpoch, 1, mo_release);
  if atomic_load(FNotifyWaiters, mo_relaxed) > 0 then
    LockFreeWakeAll(@FNotifyEpoch);
end;

function TLockFreeSelectorImpl.PollOnce: PtrInt;
var
  LI: PtrUInt;
begin
  if FCount = 0 then
    Exit(-1);
  for LI := 0 to FCount - 1 do
  begin
    if FCases[LI].IsSend then
    begin
      if FCases[LI].Channel.TrySend(FCases[LI].DataPtr^) then
        Exit(PtrInt(LI));
    end
    else
    begin
      if FCases[LI].Channel.TryReceive(FCases[LI].DataPtr^) then
        Exit(PtrInt(LI));
    end;
  end;
  Result := -1;
end;

function TLockFreeSelectorImpl.Select: TSelectResult;
var
  LIdx: PtrInt;
  LSpins: Int32;
  LEpoch: Int32;
begin
  LSpins := 0;
  while True do
  begin
    LIdx := PollOnce;
    if LIdx >= 0 then
    begin
      Result.Index := LIdx;
      Result.Completed := True;
      Exit;
    end;
    Inc(LSpins);
    if LSpins < SELECTOR_MAX_SPIN then
      CpuPause
    else
    begin
      LSpins := 0;
      LEpoch := atomic_load(FNotifyEpoch, mo_acquire);
      atomic_fetch_add(FNotifyWaiters, 1, mo_acq_rel);
      try
        LIdx := PollOnce;
        if LIdx >= 0 then
        begin
          Result.Index := LIdx;
          Result.Completed := True;
          Exit;
        end;
        if atomic_load(FNotifyEpoch, mo_acquire) = LEpoch then
          LockFreeWaitData(@FNotifyEpoch, @FNotifyWaiters, LEpoch, LOCKFREE_WAIT_TIMEOUT_NS);
      finally
        atomic_fetch_sub(FNotifyWaiters, 1, mo_acq_rel);
      end;
    end;
  end;
end;

function TLockFreeSelectorImpl.TrySelect: TSelectResult;
begin
  Result.Index := PollOnce;
  Result.Completed := Result.Index >= 0;
end;

function TLockFreeSelectorImpl.SelectTimeout(const ATimeoutNs: Int64): TSelectResult;
var
  LIdx: PtrInt;
  LSpins: Int32;
  LElapsed: Int64;
  LWaitNs: Int64;
  LEpoch: Int32;
  LStart: QWord;
begin
  LStart := platform_monotonic_ns;
  LSpins := 0;
  while True do
  begin
    LIdx := PollOnce;
    if LIdx >= 0 then
    begin
      Result.Index := LIdx;
      Result.Completed := True;
      Exit;
    end;
    LElapsed := Int64(platform_monotonic_ns - LStart);
    if LElapsed >= ATimeoutNs then
      Break;
    Inc(LSpins);
    if LSpins < SELECTOR_MAX_SPIN then
      CpuPause
    else
    begin
      LSpins := 0;
      LWaitNs := ATimeoutNs - LElapsed;
      if LWaitNs > 1000000 then
        LWaitNs := 1000000;
      LEpoch := atomic_load(FNotifyEpoch, mo_acquire);
      atomic_fetch_add(FNotifyWaiters, 1, mo_acq_rel);
      try
        LIdx := PollOnce;
        if LIdx >= 0 then
        begin
          Result.Index := LIdx;
          Result.Completed := True;
          Exit;
        end;
        LElapsed := Int64(platform_monotonic_ns - LStart);
        LWaitNs := ATimeoutNs - LElapsed;
        if LWaitNs > 1000000 then
          LWaitNs := 1000000;
        if (LWaitNs > 0) and (atomic_load(FNotifyEpoch, mo_acquire) = LEpoch) then
          LockFreeWaitData(@FNotifyEpoch, @FNotifyWaiters, LEpoch, LWaitNs);
      finally
        atomic_fetch_sub(FNotifyWaiters, 1, mo_acq_rel);
      end;
    end;
  end;
  Result.Index := -1;
  Result.Completed := False;
end;

procedure TLockFreeSelectorImpl.Clear;
var
  LI: PtrUInt;
begin
  if FCount > 0 then
    for LI := 0 to FCount - 1 do
    begin
      FCases[LI].Channel.SetNotifier(nil, nil);
      if FCases[LI].IsSend and (FCases[LI].SendValuePtr <> nil) then
      begin
        Dispose(FCases[LI].SendValuePtr);
        FCases[LI].SendValuePtr := nil;
      end;
    end;
  FCount := 0;
end;

function TLockFreeSelectorImpl.CaseCount: PtrUInt;
begin
  Result := FCount;
end;

end.
