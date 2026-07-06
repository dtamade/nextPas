unit nextpas.core.lockfree.selector.impl;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.platform.thread,
  nextpas.core.lockfree.selector,
  nextpas.core.lockfree.channel;

const
  SELECTOR_DEFAULT_CAPACITY = 4;

type
  {** @desc 多路 Channel 复用器（泛型实现，类型安全 API）
    @details 支持在同一 T 类型的多个 channel 上多路复用。
      所有 case 必须使用相同的元素类型 T（与 Go select 的类型约束一致）。

      **与 Go select 的对应关系**:
      - `case v := <-ch:` → `LSelector.AddRecv(LChannel, LOutVar)`
      - `case ch <- v:` → `LSelector.AddSend(LChannel, LValue)`
      - `select` → `LResult := LSelector.Select`
      - `select with default` → 先 TrySend/TryReceive，不走 Select

      **设计约束**:
      - 所有 channel 必须是相同类型 T 的 TLockFreeChannelImpl<T>
      - 不支持 default 分支（需要时直接 TrySend/TryReceive）
      - poll + backoff 策略（非内核 wait address，纯用户态轮询）

      **与 THazardGuard/TEbrGuard 的区别**:
      - Guard 管理单个域的生命周期（RAII）
      - Selector 管理多个 channel 的多路复用（事件驱动）
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
    function PollOnce: PtrInt;
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
  inherited Create;
  if AExpectedCount = 0 then
    SetLength(FCases, SELECTOR_DEFAULT_CAPACITY)
  else
    SetLength(FCases, AExpectedCount);
  FCount := 0;
end;

destructor TLockFreeSelectorImpl.Destroy;
var
  LI: PtrUInt;
begin
  for LI := 0 to FCount - 1 do
  begin
    if FCases[LI].IsSend and (FCases[LI].SendValuePtr <> nil) then
      Dispose(FCases[LI].SendValuePtr);
  end;
  SetLength(FCases, 0);
  inherited;
end;

procedure TLockFreeSelectorImpl.AddRecv(AChannel: TChannel; var AOutValue: T);
begin
  if not Assigned(AChannel) then
    raise EArgumentError.Create('TLockFreeSelector.AddRecv: nil channel');
  if FCount >= PtrUInt(Length(FCases)) then
    SetLength(FCases, Length(FCases) * 2);
  FCases[FCount].Channel := AChannel;
  FCases[FCount].DataPtr := @AOutValue;
  FCases[FCount].SendValuePtr := nil;
  FCases[FCount].IsSend := False;
  Inc(FCount);
end;

procedure TLockFreeSelectorImpl.AddSend(AChannel: TChannel; const AValue: T);
var
  LIdx: PtrUInt;
  LCopy: PT;
begin
  if not Assigned(AChannel) then
    raise EArgumentError.Create('TLockFreeSelector.AddSend: nil channel');
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
  Inc(FCount);
end;

function TLockFreeSelectorImpl.PollOnce: PtrInt;
var
  LI: PtrUInt;
begin
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
      platform_thread_sleep_ns(SELECTOR_BACKOFF_NS);
    end;
  end;
end;

function TLockFreeSelectorImpl.SelectTimeout(const ATimeoutNs: Int64): TSelectResult;
var
  LIdx: PtrInt;
  LSpins: Int32;
  LElapsed: Int64;
  LSleepNs: Int64;
begin
  LElapsed := 0;
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
    if LElapsed >= ATimeoutNs then
      Break;
    Inc(LSpins);
    if LSpins < SELECTOR_MAX_SPIN then
      CpuPause
    else
    begin
      LSpins := 0;
      LSleepNs := SELECTOR_BACKOFF_NS;
      if LSleepNs > (ATimeoutNs - LElapsed) then
        LSleepNs := ATimeoutNs - LElapsed;
      platform_thread_sleep_ns(LSleepNs);
      Inc(LElapsed, LSleepNs);
    end;
  end;
  Result.Index := -1;
  Result.Completed := False;
end;

procedure TLockFreeSelectorImpl.Clear;
var
  LI: PtrUInt;
begin
  for LI := 0 to FCount - 1 do
  begin
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
