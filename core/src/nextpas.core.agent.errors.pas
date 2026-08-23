{**
 * nextpas.core.agent.errors - agent 模块异常族与错误分类器。
 *
 * 契约权威：core/docs/agent/API.md §2、ERRORS.md。实现与文档冲突时先改文档。
 * 错误码词表 TAgentErrorCode 物理定义在 nextpas.core.agent.base；本单元只拥有
 * 异常类与分类函数。
 *}

unit nextpas.core.agent.errors;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.agent.base;

type
  TAgentErrorCodes = set of TAgentErrorCode;

  { 单一异常族：全部上下文进字段不进 message（ERRORS.md §4）}
  EAgentError = class(Exception)
  public
    ErrorCode: TAgentErrorCode;    { 缺省 aecNone }
    Retryable: Boolean;            { 由错误码推导，构造时算好 }
    RetryAfterMs: Int64;           { CRetryAfterUnknown=未提供；仅 RateLimited 有意义 }
    Provider: string;              { 'openai' | 'anthropic' | ''=本地 }
    RequestId: string;             { 上游 x-request-id 回显（有则填）}
    RawBodySnippet: string;        { 上游错误体摘要 ≤8KB；本地错误为空 }
    { 本地错误：Provider 空、消息无前缀 }
    constructor CreateLocal(ACode: TAgentErrorCode; const AMsg: string);
    { 上游错误信封：Message = '[<provider>] <code-name>: <msg>' }
    constructor CreateUpstream(ACode: TAgentErrorCode; const AProvider,
      AUpstreamMsg, ARequestId, ARawBodySnippet: string); overload;
    constructor CreateUpstream(ACode: TAgentErrorCode; const AProvider,
      AUpstreamMsg, ARequestId, ARawBodySnippet: string;
      ARetryAfterMs: Int64); overload;
  end;

  { ErrorCode 固定 aecCancelled；Message 固定 'operation cancelled'。
    判定取消永远看类型/码，不做字符串匹配 }
  EAgentCancelled = class(EAgentError)
  public
    constructor Create; reintroduce;
  end;

  { 消费方时序/用法违规（如 Active 期 GetMessage）：不占厂商协议错误码位，
    让 catch 边界能区分"我的 bug"与"上游的错" }
  EAgentMisuse = class(EAgentError)
  public
    constructor Create(const AMsg: string); reintroduce;
  end;

{ HTTP status → 错误码分类器（transport 与适配器共用，单一事实源；
  仅对非 2xx 调用；AStatus=0 即连接层失败 → aecTransport）}
function ErrorCodeForStatus(AStatus: Integer): TAgentErrorCode;

{ 重试白名单：[aecRateLimited, aecTransport, aecTimeout, aecServer]（ERRORS.md 铁律）}
function IsRetryable(ACode: TAgentErrorCode): Boolean;

{ 错误码稳定名（message 格式与日志用，snake_case）}
function AgentErrorCodeName(ACode: TAgentErrorCode): string;

implementation

constructor EAgentError.CreateLocal(ACode: TAgentErrorCode; const AMsg: string);
begin
  inherited Create(AMsg);
  ErrorCode := ACode;
  Retryable := IsRetryable(ACode);
  RetryAfterMs := CRetryAfterUnknown;
  Provider := '';
  RequestId := '';
  RawBodySnippet := '';
end;

constructor EAgentError.CreateUpstream(ACode: TAgentErrorCode; const AProvider,
  AUpstreamMsg, ARequestId, ARawBodySnippet: string);
begin
  CreateUpstream(ACode, AProvider, AUpstreamMsg, ARequestId,
    ARawBodySnippet, CRetryAfterUnknown);
end;

constructor EAgentError.CreateUpstream(ACode: TAgentErrorCode; const AProvider,
  AUpstreamMsg, ARequestId, ARawBodySnippet: string; ARetryAfterMs: Int64);
begin
  inherited Create('[' + AProvider + '] ' + AgentErrorCodeName(ACode)
    + ': ' + AUpstreamMsg);
  ErrorCode := ACode;
  Retryable := IsRetryable(ACode);
  RetryAfterMs := ARetryAfterMs;
  Provider := AProvider;
  RequestId := ARequestId;
  RawBodySnippet := ARawBodySnippet;
end;

constructor EAgentCancelled.Create;
begin
  inherited CreateLocal(aecCancelled, 'operation cancelled');
end;

constructor EAgentMisuse.Create(const AMsg: string);
begin
  inherited CreateLocal(aecConfig, AMsg);
end;

function ErrorCodeForStatus(AStatus: Integer): TAgentErrorCode;
begin
  if AStatus = 429 then
    Result := aecRateLimited
  else if (AStatus = 401) or (AStatus = 403) then
    Result := aecAuthentication
  else if AStatus = 404 then
    Result := aecNotFound
  else if AStatus = 408 then
    Result := aecTimeout
  else if AStatus >= 500 then
    Result := aecServer
  else if AStatus >= 400 then
    Result := aecInvalidRequest
  else if (AStatus >= 200) and (AStatus < 300) then
    Result := aecNone
  else
    Result := aecTransport;   { 无状态（0=连接层失败）或异常状态段 }
end;

function IsRetryable(ACode: TAgentErrorCode): Boolean;
begin
  Result := ACode in [aecRateLimited, aecTransport, aecTimeout, aecServer];
end;

function AgentErrorCodeName(ACode: TAgentErrorCode): string;
begin
  Result := 'unknown';   { 未映射枚举值防御位 }
  case ACode of
    aecNone:              Result := 'none';
    aecInvalidRequest:    Result := 'invalid_request';
    aecAuthentication:    Result := 'authentication';
    aecNotFound:          Result := 'not_found';
    aecRateLimited:       Result := 'rate_limited';
    aecTransport:         Result := 'transport';
    aecTimeout:           Result := 'timeout';
    aecServer:            Result := 'server';
    aecContextOverflow:   Result := 'context_overflow';
    aecProtocol:          Result := 'protocol';
    aecCancelled:         Result := 'cancelled';
    aecConfig:            Result := 'config';
    aecToolFailed:        Result := 'tool_failed';
    aecBudgetExhausted:   Result := 'budget_exhausted';
  end;
end;

end.
