{**
 * nextpas.core.agent.throttle - 客户端限流装饰器（W8）。
 *
 * 每次 Complete/Stream 先向 gate 取票；拒绝→在 AClock 上取消感知等待
 * gate 建议毫秒后重取（建议 <=0 视为未指明，按 CIdlePollMs 轮询步进）；
 * 累计等待超 MaxWaitMs 或重取次数超 MaxAcquires → 本地抛 aecRateLimited
 * （RetryAfterMs=gate 最近建议值，Message 带 'throttled: ' 前缀——与上游
 * 429 归因分离：本地路径从未触网）。取消打断等待立即 EAgentCancelled。
 *
 * IAgentRateGate 是细接口：NewTokenBucketGate 把 core.lockfree.ratelimit
 * 标准库令牌桶接入（标准库协同）；测试用 fake gate 自由编排拒绝序列。
 *}

unit nextpas.core.agent.throttle;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.async.cancellation,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.clock,
  nextpas.core.agent.provider.common;

type
  { 限流源细接口：True=放行；False=拒绝并给出建议等待毫秒（0=未指明）}
  IAgentRateGate = interface
    function TryAcquire(out ARetryAfterMs: Int64): Boolean;
  end;

  { 每次等待前上报：AWaitNo=第几次等待（1 起）；ANextRetryAfterMs=本等待时长 }
  TThrottleWaitHook = reference to procedure(AWaitNo: Integer;
    ANextRetryAfterMs: Int64);

  TThrottlePolicy = record
    MaxWaitMs: Int64;                { 单次调用累计等待上限；默认 30_000 }
    MaxAcquires: Integer;            { 等待-重取循环上限，默认 64 }
    OnWait: TThrottleWaitHook;       { nil=静默 }
    class function Default: TThrottlePolicy; static;
    function WithOnWait(const AHook: TThrottleWaitHook): TThrottlePolicy;
  end;

{ core.lockfree.ratelimit 令牌桶 → IAgentRateGate 适配器。
  单桶 TryAcquire 不携带 retry-after，本适配器建议值恒 0（未指明，
  由装饰器轮询步长兜底）}
function NewTokenBucketGate(ARatePerSecond, ABurst: Double): IAgentRateGate;

{ 装饰任意 IAgentProvider（含已叠 WithRetry/fallback 的组合）}
function NewThrottledProvider(const AInner: IAgentProvider;
  const AGate: IAgentRateGate; const AClock: IAgentClock;
  const APolicy: TThrottlePolicy): IAgentProvider;

implementation

uses
  nextpas.core.lockfree.ratelimit;

const
  CGateSuggestUnknownMs = 0;
  CIdlePollMs = 25;                  { gate 未给建议时的轮询步长 }

type
  { 持有裸类实例的适配器：随接口引用计数释放桶 }
  TTokenBucketGate = class(TInterfacedObject, IAgentRateGate)
  private
    FBucket: TTokenBucketLimiter;
  public
    constructor Create(ARatePerSecond, ABurst: Double);
    destructor Destroy; override;
    function TryAcquire(out ARetryAfterMs: Int64): Boolean;
  end;

  TThrottledProvider = class(TInterfacedObject, IAgentProvider)
  private
    FInner: IAgentProvider;
    FGate: IAgentRateGate;
    FClock: IAgentClock;
    FPolicy: TThrottlePolicy;
    FAmbientToken: IAsyncCancellationToken;
    { 入口取票：成功返回；取消/超窗以异常出。返回值无意义，统一出口 }
    procedure AcquireSlot(const AToken: IAsyncCancellationToken);
    function GetName: string;
    function Complete(const AReq: TCompletionRequest): TMessage; overload;
    function Complete(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): TMessage; overload;
    function Stream(
      const AReq: TCompletionRequest): IAgentCompletion; overload;
    function Stream(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): IAgentCompletion; overload;
  public
    constructor Create(const AInner: IAgentProvider;
      const AGate: IAgentRateGate; const AClock: IAgentClock;
      const APolicy: TThrottlePolicy;
      const AToken: IAsyncCancellationToken);
  end;

{ ---- TThrottlePolicy ---- }

class function TThrottlePolicy.Default: TThrottlePolicy;
begin
  Result.MaxWaitMs := 30000;
  Result.MaxAcquires := 64;
  Result.OnWait := nil;
end;

function TThrottlePolicy.WithOnWait(
  const AHook: TThrottleWaitHook): TThrottlePolicy;
begin
  Result := Self;
  Result.OnWait := AHook;
end;

{ ---- TTokenBucketGate ---- }

constructor TTokenBucketGate.Create(ARatePerSecond, ABurst: Double);
begin
  inherited Create;
  FBucket := TTokenBucketLimiter.Create(ARatePerSecond, ABurst);
end;

destructor TTokenBucketGate.Destroy;
begin
  FBucket.Free;
  inherited Destroy;
end;

function TTokenBucketGate.TryAcquire(out ARetryAfterMs: Int64): Boolean;
begin
  ARetryAfterMs := CGateSuggestUnknownMs;
  Result := FBucket.TryAcquire = rlAllowed;
end;

{ ---- TThrottledProvider ---- }

constructor TThrottledProvider.Create(const AInner: IAgentProvider;
  const AGate: IAgentRateGate; const AClock: IAgentClock;
  const APolicy: TThrottlePolicy; const AToken: IAsyncCancellationToken);
begin
  inherited Create;
  if AInner = nil then
    raise EAgentError.CreateLocal(aecConfig,
      'NewThrottledProvider: inner is required');
  if AGate = nil then
    raise EAgentError.CreateLocal(aecConfig,
      'NewThrottledProvider: gate is required');
  if AClock = nil then
    raise EAgentError.CreateLocal(aecConfig,
      'NewThrottledProvider: clock is required');
  if APolicy.MaxWaitMs < 0 then
    raise EAgentError.CreateLocal(aecConfig,
      'NewThrottledProvider: MaxWaitMs must be >= 0');
  FInner := AInner;
  FGate := AGate;
  FClock := AClock;
  FPolicy := APolicy;
  FAmbientToken := AToken;
end;

function TThrottledProvider.GetName: string;
begin
  Result := FInner.GetName;
end;

procedure TThrottledProvider.AcquireSlot(
  const AToken: IAsyncCancellationToken);
var
  LToken: IAsyncCancellationToken;
  LSleptMs: Int64;
  LAfter, LSuggest: Int64;
  LWaitNo: Integer;
  LErr: EAgentError;
begin
  LToken := MergeCancellationTokens(FAmbientToken, AToken);
  RequireNotCancelled(LToken);
  LSleptMs := 0;
  LWaitNo := 0;
  LSuggest := 0;
  for LAfter := 1 to FPolicy.MaxAcquires do
  begin
    if FGate.TryAcquire(LSuggest) then
      Exit;
    RequireNotCancelled(LToken);
    if LSuggest <= 0 then
      LSuggest := CIdlePollMs;         { 未指明：轮询步长兜底 }
    Inc(LWaitNo);
    if FPolicy.OnWait <> nil then
      FPolicy.OnWait(LWaitNo, LSuggest);
    if (LSleptMs + LSuggest > FPolicy.MaxWaitMs) or
       (LAfter = FPolicy.MaxAcquires) then
    begin
      { 本地整形拒绝：归因分离——从未触网，前缀明示 }
      LErr := EAgentError.CreateLocal(aecRateLimited,
        'throttled: local rate gate wait budget exceeded');
      LErr.RetryAfterMs := LSuggest;
      raise LErr;
    end;
    if not FClock.SleepMs(LSuggest, LToken) then
      raise EAgentCancelled.Create;    { 取消打断等待 }
    LSleptMs := LSleptMs + LSuggest;
  end;
end;

function TThrottledProvider.Complete(const AReq: TCompletionRequest): TMessage;
begin
  Result := Complete(AReq, nil);
end;

function TThrottledProvider.Complete(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): TMessage;
begin
  AcquireSlot(AToken);
  Result := FInner.Complete(AReq, AToken);
end;

function TThrottledProvider.Stream(
  const AReq: TCompletionRequest): IAgentCompletion;
begin
  Result := Stream(AReq, nil);
end;

function TThrottledProvider.Stream(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): IAgentCompletion;
begin
  AcquireSlot(AToken);
  Result := FInner.Stream(AReq, AToken);
end;

{ ---- 工厂 ---- }

function NewTokenBucketGate(ARatePerSecond, ABurst: Double): IAgentRateGate;
begin
  Result := TTokenBucketGate.Create(ARatePerSecond, ABurst);
end;

function NewThrottledProvider(const AInner: IAgentProvider;
  const AGate: IAgentRateGate; const AClock: IAgentClock;
  const APolicy: TThrottlePolicy): IAgentProvider;
begin
  Result := TThrottledProvider.Create(AInner, AGate, AClock, APolicy, nil);
end;

end.
