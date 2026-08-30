{**
 * nextpas.core.agent.fallback - 多供应商容灾链装饰器（W8）。
 *
 * 链内单尝试逐家切换：AChain[0] 抛出且 ErrorCode ∈ FailOn ∩ IsRetryable →
 * 试下一家；白名单外首错立即上抛不切换；全链耗尽透传最后一次原始错误
 * （不包装不改码，对齐 WithRetry 哲学）。流式仅拿到流且收到首个 delta 前
 * 允许降级——首 delta 后失败原样上抛（投递不重复语义，与 retry 同门）。
 * 取消优先于一切：令牌已触发不再切换。
 *
 * 纯组合：不认识任何 wire/provider 形态，可与 WithRetry/WithThrottle/
 * fake 任意叠装。OnSwitch 钩子做观测；睡与重试不归它管（叠 WithRetry）。
 *}

unit nextpas.core.agent.fallback;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.async.cancellation,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.provider.common;

type
  { 切换发生时上报：AIndex=即将尝试的链内序号（0 起）；
    AProviderName=即将尝试的供应商名；错误以快照字段传递 }
  TFallbackSwitchHook = reference to procedure(AIndex: Integer;
    const AProviderName: string; AErrCode: TAgentErrorCode;
    const AErrMsg: string);

  TFallbackPolicy = record
    FailOn: TAgentErrorCodes;        { 触发降级的错误码集；默认同 retry 四码 }
    OnSwitch: TFallbackSwitchHook;   { nil=静默 }
    class function Default: TFallbackPolicy; static;
    function WithOnSwitch(const AHook: TFallbackSwitchHook): TFallbackPolicy;
  end;

{ 装饰器：AChain 至少一家（1 家=恒直通等价无装饰）；请求对象按值传给
  每一家，各 provider 自行编码互不干扰 }
function NewFallbackProvider(const AChain: array of IAgentProvider;
  const APolicy: TFallbackPolicy): IAgentProvider;

implementation

type
  TFallbackProvider = class(TInterfacedObject, IAgentProvider)
  private
    FChain: array of IAgentProvider;
    FPolicy: TFallbackPolicy;
    FAmbientToken: IAsyncCancellationToken;
    function ShouldFailover(AErr: EAgentError): Boolean;
      { 白名单交集：FailOn 之外永不降级；IsRetryable 兜底防御语义漂移 }
    procedure NotifySwitch(AIndex: Integer; const APrior: TProviderFailure);
    function GetName: string;
    function Complete(const AReq: TCompletionRequest): TMessage; overload;
    function Complete(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): TMessage; overload;
    function Stream(
      const AReq: TCompletionRequest): IAgentCompletion; overload;
    function Stream(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): IAgentCompletion; overload;
  public
    constructor Create(const AChain: array of IAgentProvider;
      const APolicy: TFallbackPolicy;
      const AToken: IAsyncCancellationToken);
  end;

{ ---- TFallbackPolicy ---- }

class function TFallbackPolicy.Default: TFallbackPolicy;
begin
  Result.FailOn := [aecRateLimited, aecTransport, aecTimeout, aecServer];
  Result.OnSwitch := nil;
end;

function TFallbackPolicy.WithOnSwitch(
  const AHook: TFallbackSwitchHook): TFallbackPolicy;
begin
  Result := Self;
  Result.OnSwitch := AHook;
end;

{ ---- TFallbackProvider ---- }

constructor TFallbackProvider.Create(const AChain: array of IAgentProvider;
  const APolicy: TFallbackPolicy; const AToken: IAsyncCancellationToken);
begin
  inherited Create;
  if Length(AChain) = 0 then
    raise EAgentError.CreateLocal(aecConfig,
      'NewFallbackProvider: chain is required');
  FChain := Copy(AChain, 0, Length(AChain));
  FPolicy := APolicy;
  FAmbientToken := AToken;
end;

function TFallbackProvider.GetName: string;
begin
  { 主路身份：装饰器不改变消费方可见的 provider 名 }
  Result := FChain[0].GetName;
end;

function TFallbackProvider.ShouldFailover(AErr: EAgentError): Boolean;
begin
  Result := (AErr.ErrorCode in FPolicy.FailOn) and
    IsRetryable(AErr.ErrorCode);
end;

procedure TFallbackProvider.NotifySwitch(AIndex: Integer;
  const APrior: TProviderFailure);
begin
  if FPolicy.OnSwitch = nil then
    Exit;
  FPolicy.OnSwitch(AIndex, FChain[AIndex].GetName, APrior.Code,
    APrior.Msg);
end;

function TFallbackProvider.Complete(const AReq: TCompletionRequest): TMessage;
begin
  Result := Complete(AReq, nil);
end;

function TFallbackProvider.Complete(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): TMessage;
var
  LToken: IAsyncCancellationToken;
  LFail: TProviderFailure;
  I: Integer;
begin
  LToken := MergeCancellationTokens(FAmbientToken, AToken);
  for I := 0 to High(FChain) do
  begin
    RequireNotCancelled(LToken);
    try
      Result := FChain[I].Complete(AReq, LToken);
      Exit;
    except
      on E: EAgentCancelled do
        raise;                       { 取消直通：不是故障，不降级 }
      on E: EAgentError do
      begin
        LFail.Capture(E);
        if (I = High(FChain)) or (not ShouldFailover(E)) then
          raise;                     { 最后一家或白名单外：原样上抛 }
        NotifySwitch(I + 1, LFail);
      end;
    end;
  end;
  { 不可达：循环内必 Exit 或 raise }
  raise EAgentError.CreateLocal(aecConfig,
    'fallback: unreachable state');
end;

function TFallbackProvider.Stream(
  const AReq: TCompletionRequest): IAgentCompletion;
begin
  Result := Stream(AReq, nil);
end;

function TFallbackProvider.Stream(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): IAgentCompletion;
var
  LToken: IAsyncCancellationToken;
  LFail: TProviderFailure;
  LComp: IAgentCompletion;
  LD: TStreamDelta;
  LHaveFirst: Boolean;
  I: Integer;
begin
  LToken := MergeCancellationTokens(FAmbientToken, AToken);
  for I := 0 to High(FChain) do
  begin
    RequireNotCancelled(LToken);
    LComp := nil;
    try
      LComp := FChain[I].Stream(AReq, LToken);
      { 首 delta 门：上游非 2xx / 早断连在此显形为可降级失败；
        拿到首 delta 即成局——后续失败原样上抛（投递不重复）}
      LHaveFirst := LComp.NextDelta(LD);
      Result := TFirstGateCompletion.Create(LComp, LD, LHaveFirst);
      Exit;
    except
      on E: EAgentCancelled do
      begin
        if LComp <> nil then
          try
            LComp.Cancel;
          except
          end;
        raise;
      end;
      on E: EAgentError do
      begin
        if LComp <> nil then
          try
            LComp.Cancel;
          except
          end;
        LFail.Capture(E);
        if (I = High(FChain)) or (not ShouldFailover(E)) then
          raise;
        NotifySwitch(I + 1, LFail);
      end;
    end;
  end;
  raise EAgentError.CreateLocal(aecConfig,
    'fallback: unreachable state');
end;

{ ---- 工厂 ---- }

function NewFallbackProvider(const AChain: array of IAgentProvider;
  const APolicy: TFallbackPolicy): IAgentProvider;
begin
  Result := TFallbackProvider.Create(AChain, APolicy, nil);
end;

end.
