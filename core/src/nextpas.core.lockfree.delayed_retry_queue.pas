unit nextpas.core.lockfree.delayed_retry_queue;

{** @desc 有界延迟重试队列（Delayed Retry Queue）
  @details 条目带「下次重试时刻」（单调时钟），按 key 分组且有每 key 上限；
    入队即排队，到期扫描时回调调用方决定移除或按指数退避推进重试。
    典型用途：配额恢复后的延迟投递、指数退避重试调度。
  @design 与 TTimeoutQueue 互补：TTimeoutQueue 是并发 ring + 超时跳过（出队侧），
    本队列是「回调 drain + 退避推进 + 每 key 上限 + 丢最旧」的有界重试调度。
    有界：全局上限 + 每 key 上限，满时丢最旧（FIFO 头）并计数 Dropped，
    防堆积/内存无界（长期不可达的 key 丢最旧消息可接受）。
  @concurrency Thread-safe：互斥保护全部方法；DrainDue 期间回调在锁内执行，
    回调内不得调用队列方法（互斥非重入），DrainDue 同一时刻至多一个调用方。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync;

type
  { 单调时钟源（纳秒）；默认 platform_monotonic_ns，测试注入假时钟。 }
  TDelayedNowNsFn = reference to function: UInt64;

  { 延迟条目（值语义；Payload 接口引用计数随条目生命周期自动管理）。 }
  TDelayedRetryItem = record
    Key: string;
    Payload: IInterface;
    RetryAtNs: UInt64;
    Attempts: Int64;
  end;

  { 到期回调：AHandled=True 移出队列；False 保留并按指数退避推进重试。 }
  TDelayedRetryHandler = reference to procedure(
    const AItem: TDelayedRetryItem; var AHandled: Boolean);

  {** @desc 有界延迟重试队列（线程安全）。 }
  TDelayedRetryQueue = class
  private
    FMaxItems: Integer;
    FMaxPerKey: Integer;
    FRetryBaseNs: Int64;
    FRetryMaxNs: Int64;
    FNowNs: TDelayedNowNsFn;
    FLock: INativeMutex;
    FItems: array of TDelayedRetryItem;
    FDropped: Int64;
    function RetryDelayNs(const AAttempts: Int64): Int64;
    function CountOfKey(const AKey: string): Integer;
    function FindFirstOfKey(const AKey: string): Integer;
    procedure RemoveAt(const AIndex: Integer);
  public
    { AMaxItems：全局上限；AMaxPerKey：每 key 上限；ARetryBaseNs/ARetryMaxNs：
      指数退避窗口（base × 2^(attempts-1)，钳到 max）；ANowNs：时钟源。 }
    constructor Create(const AMaxItems: Integer = 4096;
      const AMaxPerKey: Integer = 128;
      const ARetryBaseNs: Int64 = 5000000000;
      const ARetryMaxNs: Int64 = 300000000000;
      const ANowNs: TDelayedNowNsFn = nil);
    destructor Destroy; override;
    { 入队（首次重试 = now + base）；满丢最旧。重复 (key, payload) 判重
      由调用侧负责（如幂等集/唯一约束），队列不判重。 }
    procedure Enqueue(const AKey: string; const APayload: IInterface);
    { 到期扫描：逐一调 Handler；handled 移出，否则 Attempts+1 + 退避推进。 }
    procedure DrainDue(const AHandler: TDelayedRetryHandler);
    function Count: Int64; inline;
    function Dropped: Int64; inline;
    procedure Reset;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.platform.time;   { platform_monotonic_ns }

function DefaultNowNs: UInt64;
begin
  Result := platform_monotonic_ns;
end;

constructor TDelayedRetryQueue.Create(const AMaxItems: Integer;
  const AMaxPerKey: Integer; const ARetryBaseNs, ARetryMaxNs: Int64;
  const ANowNs: TDelayedNowNsFn);
begin
  inherited Create;
  if (AMaxItems < 1) or (AMaxPerKey < 1) then
    raise EArgumentError.Create('delayed retry queue: limits must be >= 1');
  if (ARetryBaseNs < 1) or (ARetryMaxNs < ARetryBaseNs) then
    raise EArgumentError.Create('delayed retry queue: invalid retry window');
  FMaxItems := AMaxItems;
  FMaxPerKey := AMaxPerKey;
  FRetryBaseNs := ARetryBaseNs;
  FRetryMaxNs := ARetryMaxNs;
  if ANowNs = nil then
    FNowNs := @DefaultNowNs
  else
    FNowNs := ANowNs;
  FLock := Mutex;
  FItems := nil;
  FDropped := 0;
end;

destructor TDelayedRetryQueue.Destroy;
begin
  FItems := nil;
  FNowNs := nil;
  FLock := nil;
  inherited Destroy;
end;

function TDelayedRetryQueue.RetryDelayNs(const AAttempts: Int64): Int64;
var
  LExp: Int64;
  LI: Integer;
begin
  { base × 2^(attempts-1)，指数钳到 max（Int64 移位防溢出）。 }
  LExp := 1;
  for LI := 1 to AAttempts - 1 do
  begin
    if LExp >= FRetryMaxNs div FRetryBaseNs then
    begin
      LExp := FRetryMaxNs div FRetryBaseNs;
      Break;
    end;
    LExp := LExp * 2;
  end;
  Result := LExp * FRetryBaseNs;
  if Result > FRetryMaxNs then
    Result := FRetryMaxNs;
end;

function TDelayedRetryQueue.CountOfKey(const AKey: string): Integer;
var
  LI: Integer;
begin
  Result := 0;
  for LI := 0 to High(FItems) do
    if FItems[LI].Key = AKey then
      Inc(Result);
end;

function TDelayedRetryQueue.FindFirstOfKey(const AKey: string): Integer;
var
  LI: Integer;
begin
  Result := -1;
  for LI := 0 to High(FItems) do
    if FItems[LI].Key = AKey then
      Exit(LI);
end;

procedure TDelayedRetryQueue.RemoveAt(const AIndex: Integer);
var
  LI: Integer;
begin
  for LI := AIndex to High(FItems) - 1 do
    FItems[LI] := FItems[LI + 1];
  SetLength(FItems, Length(FItems) - 1);
end;

procedure TDelayedRetryQueue.Enqueue(const AKey: string;
  const APayload: IInterface);
var
  LItem: TDelayedRetryItem;
  LIdx: Integer;
begin
  LItem.Key := AKey;
  LItem.Payload := APayload;
  LItem.Attempts := 0;
  FLock.Acquire;
  try
    LItem.RetryAtNs := FNowNs() + UInt64(FRetryBaseNs);
    { 有界：全局满丢最旧；每 key 满丢该 key 最旧。 }
    if Length(FItems) >= FMaxItems then
    begin
      RemoveAt(0);
      Inc(FDropped);
    end
    else
    begin
      LIdx := FindFirstOfKey(AKey);
      if (LIdx >= 0) and (CountOfKey(AKey) >= FMaxPerKey) then
      begin
        RemoveAt(LIdx);
        Inc(FDropped);
      end;
    end;
    SetLength(FItems, Length(FItems) + 1);
    FItems[High(FItems)] := LItem;
  finally
    FLock.Release;
  end;
end;

procedure TDelayedRetryQueue.DrainDue(const AHandler: TDelayedRetryHandler);
var
  LNow: UInt64;
  LI: Integer;
  LHandled: Boolean;
begin
  FLock.Acquire;
  try
    LNow := FNowNs();
    LI := 0;
    while LI < Length(FItems) do
    begin
      if FItems[LI].RetryAtNs > LNow then
      begin
        Inc(LI);
        Continue;
      end;
      LHandled := False;
      AHandler(FItems[LI], LHandled);
      if LHandled then
        RemoveAt(LI)
      else
      begin
        Inc(FItems[LI].Attempts);
        FItems[LI].RetryAtNs := FNowNs() + UInt64(RetryDelayNs(FItems[LI].Attempts));
        Inc(LI);
      end;
    end;
  finally
    FLock.Release;
  end;
end;

function TDelayedRetryQueue.Count: Int64;
begin
  Result := Int64(Length(FItems));
end;

function TDelayedRetryQueue.Dropped: Int64;
begin
  Result := FDropped;
end;

procedure TDelayedRetryQueue.Reset;
begin
  FLock.Acquire;
  try
    FItems := nil;
    FDropped := 0;
  finally
    FLock.Release;
  end;
end;

end.