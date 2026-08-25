{**
 * nextpas.core.agent.retry - WithRetry 装饰器：可注入时钟的重试策略。
 *
 * 契约权威：core/docs/agent/API.md §5。实现与文档冲突时先改文档。
 * 语义要点（DESIGN D6）：provider 层零自动重试，策略全部在本装饰器；
 * 仅对 RetryOn ∩ IsRetryable 的错误重试；Retry-After 优先于退避曲线；
 * 累计退避超 MaxTotalRetryMs 即停，抛最后一次原始错误；取消优先于一切。
 * 流式作用域：只重试到拿到流且收到首个 delta 为止——流中途失败原样上抛
 * （重放意味着向消费方重复投递 delta，禁止）。
 *
 * OnAttempt 钩子收到的 ALastError 实例仅在调用期内有效，不得留存。
 *}

unit nextpas.core.agent.retry;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.async.cancellation,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.provider.common;

type
  { 每次尝试前上报（含首次：ADelayMs=0、ALastError=nil）；
    AAttempt=即将开始的尝试序号从 1 起。
    ALastError 为借用引用：仅回调期内有效，不得留存（通知对象随调用释放）}
  TRetryAttemptHook = reference to procedure(const AAttempt: Integer;
    const ADelayMs: Int64; const ALastError: EAgentError);

  TRetryPolicy = record
    MaxAttempts: Integer;            { >=1；1=不重试 }
    InitialDelayMs: Int64;
    MaxDelayMs: Int64;               { 单次退避上限 }
    Multiplier: Double;              { 指数底数 }
    Jitter: Double;                  { [0..1] 比例抖动 }
    RetryOn: TAgentErrorCodes;       { 与 IsRetryable 取交集生效 }
    RespectRetryAfter: Boolean;      { True=服务器指示优先于退避曲线 }
    MaxTotalRetryMs: Int64;          { 累计退避上限 }
    OnAttempt: TRetryAttemptHook;    { nil=静默 }
    class function Default: TRetryPolicy; static;
    function WithOnAttempt(const AHook: TRetryAttemptHook): TRetryPolicy;
  end;

{ 装饰任意 IAgentProvider（含 fake/scripted）；睡在 AClock 上（测试零睡眠，
  时钟经 nextpas.core.agent.clock 构造）。四参重载的 AToken 为环境令牌：
  调用方未传令牌的调用落到它上 }
function WithRetry(const AInner: IAgentProvider; const APolicy: TRetryPolicy;
  const AClock: IAgentClock): IAgentProvider; overload;
function WithRetry(const AInner: IAgentProvider; const APolicy: TRetryPolicy;
  const AClock: IAgentClock;
  const AToken: IAsyncCancellationToken): IAgentProvider; overload;

implementation

uses
  nextpas.core.platform.random;

const
  CTWO_POW_64: Double = 18446744073709551616.0;

type
  TRetryProvider = class(TInterfacedObject, IAgentProvider)
  private
    FInner: IAgentProvider;
    FPolicy: TRetryPolicy;
    FClock: IAgentClock;
    FAmbientToken: IAsyncCancellationToken;
    function ShouldRetry(AErr: EAgentError): Boolean;
    { 退避曲线（不含 Retry-After 直取路径）：min(initial×m^(n-1), max)×jitter }
    function BackoffDelayMs(ARetryNo: Integer): Int64;
    { 尝试前通知；AHaveFail=False 时传 0/nil。返回本尝试前应睡时长；
      超累计退避上限抛最后一次原始错误（此时不发通知——尝试未开始）}
    function GateAttempt(AHaveFail: Boolean; const APrior: TProviderFailure;
      AAttemptsDone: Integer; ASleptMs: Int64): Int64;
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
      const APolicy: TRetryPolicy; const AClock: IAgentClock;
      const AToken: IAsyncCancellationToken);
  end;

{ ---- TRetryPolicy ---- }

class function TRetryPolicy.Default: TRetryPolicy;
begin
  { 方法名与 Default() 内在函数同名，此处显式逐字段初始化 }
  Result.MaxAttempts := 3;
  Result.InitialDelayMs := 1000;
  Result.MaxDelayMs := 30000;
  Result.Multiplier := 2.0;
  Result.Jitter := 0.1;
  Result.RetryOn := [aecRateLimited, aecTransport, aecTimeout, aecServer];
  Result.RespectRetryAfter := True;
  Result.MaxTotalRetryMs := 120000;
  Result.OnAttempt := nil;
end;

function TRetryPolicy.WithOnAttempt(
  const AHook: TRetryAttemptHook): TRetryPolicy;
begin
  Result := Self;
  Result.OnAttempt := AHook;
end;

{ ---- TRetryProvider ---- }

constructor TRetryProvider.Create(const AInner: IAgentProvider;
  const APolicy: TRetryPolicy; const AClock: IAgentClock;
  const AToken: IAsyncCancellationToken);
begin
  inherited Create;
  if AInner = nil then
    raise EAgentError.CreateLocal(aecConfig, 'WithRetry: inner is required');
  if AClock = nil then
    raise EAgentError.CreateLocal(aecConfig, 'WithRetry: clock is required');
  if APolicy.MaxAttempts < 1 then
    raise EAgentError.CreateLocal(aecConfig,
      'WithRetry: MaxAttempts must be >= 1');
  FInner := AInner;
  FPolicy := APolicy;
  FClock := AClock;
  FAmbientToken := AToken;
end;

function TRetryProvider.GetName: string;
begin
  Result := FInner.GetName;
end;

function TRetryProvider.ShouldRetry(AErr: EAgentError): Boolean;
begin
  { 白名单交集：RetryOn 之外永不重试；IsRetryable 兜底防御语义漂移 }
  Result := (AErr.ErrorCode in FPolicy.RetryOn) and
    IsRetryable(AErr.ErrorCode);
end;

function TRetryProvider.BackoffDelayMs(ARetryNo: Integer): Int64;
var
  LBase, LFrac: Double;
  LJit: Double;
  U: UInt64;
  I: Integer;
begin
  LBase := FPolicy.InitialDelayMs;
  { 连乘代替幂函数：Multiplier^(ARetryNo-1)，无精度争议 }
  for I := 2 to ARetryNo do
    LBase := LBase * FPolicy.Multiplier;
  if LBase > FPolicy.MaxDelayMs then
    LBase := FPolicy.MaxDelayMs;
  if LBase < 0 then
    LBase := 0;
  LJit := FPolicy.Jitter;
  if LJit < 0 then
    LJit := 0
  else if LJit > 1 then
    LJit := 1;
  U := platform_random_u64;
  LFrac := (1.0 - LJit) + (2.0 * LJit) * (U / CTWO_POW_64);
  Result := Round(LBase * LFrac);
  if Result < 0 then
    Result := 0;
end;

function TRetryProvider.GateAttempt(AHaveFail: Boolean;
  const APrior: TProviderFailure; AAttemptsDone: Integer;
  ASleptMs: Int64): Int64;
var
  LDelay: Int64;
  LNoti: EAgentError;
begin
  if not AHaveFail then
  begin
    if FPolicy.OnAttempt <> nil then
      FPolicy.OnAttempt(1, 0, nil);
    Exit(0);
  end;
  if FPolicy.RespectRetryAfter and
     (APrior.RetryAfterMs <> CRetryAfterUnknown) then
    LDelay := APrior.RetryAfterMs
  else
    LDelay := BackoffDelayMs(AAttemptsDone);
  { 累计退避超限：尝试不开始、不发通知，抛最后一次原始错误 }
  if (LDelay > 0) and (ASleptMs + LDelay > FPolicy.MaxTotalRetryMs) then
    raise APrior.Rebuild;
  if FPolicy.OnAttempt <> nil then
  begin
    { 钩子只借用（const）：通知对象随调用结束释放，留存即悬挂 }
    LNoti := APrior.Rebuild;
    try
      FPolicy.OnAttempt(AAttemptsDone + 1, LDelay, LNoti);
    finally
      LNoti.Free;
    end;
  end;
  Result := LDelay;
end;

function TRetryProvider.Complete(const AReq: TCompletionRequest): TMessage;
begin
  Result := Complete(AReq, nil);
end;

function TRetryProvider.Complete(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): TMessage;
var
  LToken: IAsyncCancellationToken;
  LFail: TProviderFailure;
  LHaveFail: Boolean;
  LAttempts: Integer;
  LDelay, LSleptMs: Int64;
begin
  LToken := MergeCancellationTokens(FAmbientToken, AToken);
  LHaveFail := False;
  LAttempts := 0;
  LSleptMs := 0;
  LFail := Default(TProviderFailure);
  while True do
  begin
    RequireNotCancelled(LToken);
    { 时序：算延迟→通知→睡眠→尝试。通知里的 ADelayMs 即本尝试前实睡时长 }
    LDelay := GateAttempt(LHaveFail, LFail, LAttempts, LSleptMs);
    if not FClock.SleepMs(LDelay, LToken) then
      raise EAgentCancelled.Create;
    LSleptMs := LSleptMs + LDelay;
    try
      Result := FInner.Complete(AReq, LToken);
      Exit;
    except
      on E: EAgentError do
      begin
        LFail.Capture(E);
        LHaveFail := True;
        Inc(LAttempts);
        if (not ShouldRetry(E)) or
           (LAttempts >= FPolicy.MaxAttempts) then
          raise;                     { 抛最后一次原始错误 }
      end;
    end;
  end;
end;

function TRetryProvider.Stream(
  const AReq: TCompletionRequest): IAgentCompletion;
begin
  Result := Stream(AReq, nil);
end;

function TRetryProvider.Stream(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): IAgentCompletion;
var
  LToken: IAsyncCancellationToken;
  LFail: TProviderFailure;
  LHaveFail: Boolean;
  LAttempts: Integer;
  LDelay, LSleptMs: Int64;
  LComp: IAgentCompletion;
  LD: TStreamDelta;
  LHaveFirst: Boolean;
begin
  LToken := MergeCancellationTokens(FAmbientToken, AToken);
  LHaveFail := False;
  LAttempts := 0;
  LSleptMs := 0;
  LFail := Default(TProviderFailure);
  while True do
  begin
    RequireNotCancelled(LToken);
    LDelay := GateAttempt(LHaveFail, LFail, LAttempts, LSleptMs);
    if not FClock.SleepMs(LDelay, LToken) then
      raise EAgentCancelled.Create;
    LSleptMs := LSleptMs + LDelay;
    LComp := nil;
    try
      LComp := FInner.Stream(AReq, LToken);
      { 首 delta 门：上游非 2xx / 早断连在此显形为可重试失败 }
      LHaveFirst := LComp.NextDelta(LD);
      Result := TFirstGateCompletion.Create(LComp, LD, LHaveFirst);
      Exit;
    except
      on E: EAgentError do
      begin
        LFail.Capture(E);
        LHaveFail := True;
        Inc(LAttempts);
        if (not ShouldRetry(E)) or
           (LAttempts >= FPolicy.MaxAttempts) then
        begin
          if LComp <> nil then
            LComp.Cancel;
          raise;
        end;
        if LComp <> nil then
        begin
          LComp.Cancel;                { 弃置失败尝试的流，防资源悬挂 }
          LComp := nil;
        end;
      end;
    end;
  end;
end;

function WithRetry(const AInner: IAgentProvider; const APolicy: TRetryPolicy;
  const AClock: IAgentClock): IAgentProvider;
begin
  Result := TRetryProvider.Create(AInner, APolicy, AClock, nil);
end;

function WithRetry(const AInner: IAgentProvider; const APolicy: TRetryPolicy;
  const AClock: IAgentClock;
  const AToken: IAsyncCancellationToken): IAgentProvider;
begin
  Result := TRetryProvider.Create(AInner, APolicy, AClock, AToken);
end;

end.
