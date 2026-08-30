{**
 * nextpas.core.agent.provider.anthropic - Anthropic Messages 适配器。
 *
 * 契约权威：core/docs/agent/WIRE-MAPPINGS §2、API.md §3/§7/§8。
 * 实现与文档冲突时先改文档。公开编解码器与工厂共用同一实现（DESIGN D13）；
 * 流式事件以 event 名为主键归约为统一词表（§2.3）；截断流 fail-closed
 * （Q-A8），与 OpenAI Q-O4 的宽容是各自协议现实。
 *
 * 体积与拆分（P-modularity，F-M10）：
 *  - 现状 395 行（原 1445 行，已拆 encode 449 + decode 196 + decoder 332 至子域；已 <800 阈值，
 *    模块化达标，ARCHITECTURE §2 已更新进度）；
 *    后续新增代码优先落子域。
 *  - 拆分进度（调用方零改动，已落地 3/4）：
 *      ✓ nextpas.core.agent.provider.anthropic.encode   （Encode* 纯函数，449 行）
 *      ✓ nextpas.core.agent.provider.anthropic.decode   （Decode* 纯函数，196 行）
 *      ✓ nextpas.core.agent.provider.anthropic.decoder  （WireDecoder 状态机，332 行）
 *      ○ nextpas.core.agent.provider.anthropic.factory  （BuildUrl/Provider/CountTokens 工厂）
 *    本单元为转发薄壳（inline 转发，调用方 `uses ...anthropic` 零改动）；
 *    门面 `nextpas.core.agent` 同步透出（ARCH §7 白名单）。
 *  - 约束：子域互不循环，仅向下依赖 base/errors/intf/common 等。
 *}

unit nextpas.core.agent.provider.anthropic;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.async.cancellation,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.provider.common;

const
  CANTHROPIC_DEFAULT_BASE_URL = 'https://api.anthropic.com';
  CANTHROPIC_VERSION_DEFAULT = '2023-06-01';
  CANTHROPIC_CONNECT_TIMEOUT_MS = 10000;
  CANTHROPIC_TOTAL_TIMEOUT_MS = 300000;
  CANTHROPIC_ENV_API_KEY = 'NEXTPAS_AGENT_ANTHROPIC_API_KEY';
  CANTHROPIC_ENV_MODEL = 'NEXTPAS_AGENT_ANTHROPIC_MODEL';
  CANTHROPIC_ENV_BASE_URL = 'NEXTPAS_AGENT_ANTHROPIC_BASE_URL';

type
  { provider 选项（API.md §3.1）：公共段 + anthropic-version }
  TAnthropicOptions = record
    Common: TProviderOptions;
    AnthropicVersion: string;        { 默认 CANTHROPIC_VERSION_DEFAULT }
    class function New(const AModel: string): TAnthropicOptions; static;
  end;

{ 编码：词表 → Messages wire（§2.1）。MaxTokens 强制必填（unset → aecConfig，
  绝不静默填默认）；Thinking=tsTrue 而 Budget unset → aecConfig；
  image mime 白名单违者 aecConfig；ResponseSchemaJson 非空 → aecConfig }
function EncodeAnthropicRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText;

{ W12 count_tokens 编码（§2.7）：与 messages 同构但无 max_tokens/stream 键，
  MaxTokens sentinel 不校验；其余校验同 §2.1 }
function EncodeAnthropicCountTokensRequest(
  const AReq: TCompletionRequest): TJsonText;

{ 非流式响应解码（§2.2）：违反协议抛 aecProtocol（带 RawBodySnippet）}
procedure DecodeAnthropicResponse(const ABody: TJsonText;
  out AMsg: TMessage;
  const ALog: ILogger = nil);

{ 流帧解码器（§2.3）：event 名为主键；message_start→message_stop 完整轨迹
  之外 Finalize 抛 aecProtocol（Q-A8 fail-closed）；ping 忽略 }
function NewAnthropicWireDecoder(
  const ALog: ILogger = nil): IAgentWireDecoder;

function BuildAnthropicUrl(const ABaseUrl: string): string;

{ W12：count_tokens 端点拼接，规则同 §0 }
function BuildAnthropicCountTokensUrl(const ABaseUrl: string): string;

function NewAnthropicProvider(
  const AOpts: TAnthropicOptions): IAgentProvider;

{ 环境装配（CONSUMERS §3）：必填 env 缺失返回 nil，绝不静默回退 }
type
  TAgentEnvReaderAnth = function(const AName: string): string;
function NewAnthropicProviderFromEnv: IAgentProvider;
function NewAnthropicProviderFromEnvWithReader(const AReader: TAgentEnvReaderAnth): IAgentProvider;

implementation

uses
  nextpas.core.json,
  nextpas.core.json.builder,
  nextpas.core.text.builder,
  nextpas.core.text.conv,
  nextpas.core.os.env,
  nextpas.core.agent.fold,
  nextpas.core.agent.transport.http,
  nextpas.core.agent.provider.anthropic.encode,
  nextpas.core.agent.provider.anthropic.decode,
  nextpas.core.agent.provider.anthropic.decoder;

const
  CAGENT_UNMAPPED_STOP = 'agent.unmapped.stop_reason';
  CAGENT_UNMAPPED_BLOCK = 'agent.unmapped.content_block_type';
  CAGENT_UNMAPPED_DELTA = 'agent.unmapped.content_delta_type';
  CAGENT_UNMAPPED_ERRTYPE = 'agent.unmapped.error_type';

procedure WarnLog(const ALog: ILogger; const AMsg: string); inline;
begin
  AgentWarnLog(ALog, AMsg);
end;

procedure DebugLog(const ALog: ILogger; const AMsg: string); inline;
begin
  AgentDebugLog(ALog, AMsg);
end;

procedure ProtocolError(const ABodySrc: string; const AMsg: string);
begin
  AgentProtocolError('anthropic', ABodySrc, AMsg);
end;

function BuildAnthropicUrl(const ABaseUrl: string): string;
begin
  Result := AgentJoinWireUrl(ABaseUrl, CANTHROPIC_DEFAULT_BASE_URL, '/messages');
end;

function BuildAnthropicCountTokensUrl(const ABaseUrl: string): string;
begin
  Result := AgentJoinWireUrl(ABaseUrl, CANTHROPIC_DEFAULT_BASE_URL, '/messages/count_tokens');
end;

{ stop_reason 四值映射；未知取 frNone + unmapped 文本回传（§0 未映射规则）}
function MapStopReason(const S: string; out AUnmapped: string): TFinishReason;
begin
  AUnmapped := '';
  Result := frNone;
  if S = 'end_turn' then
    Exit(frStop);
  if S = 'stop_sequence' then
    Exit(frStop);
  if S = 'max_tokens' then
    Exit(frLength);
  if S = 'tool_use' then
    Exit(frToolCalls);
  if S = 'refusal' then
    Exit(frContentFilter);
  if S <> '' then
    AUnmapped := S;
end;

{ 流内错误类型 → 错误码（§2.4）：无状态码可依，按类型名映射；
  未映射类型归 aecServer（重试白名单类，原始文本经 sdkError 消息保真）}
function ErrorCodeForStreamErrType(const AType: string): TAgentErrorCode;
begin
  if AType = 'rate_limit_error' then
    Exit(aecRateLimited);
  if (AType = 'overloaded_error') or (AType = 'api_error') then
    Exit(aecServer);
  if (AType = 'invalid_request_error') or (AType = 'request_too_large') then
    Exit(aecInvalidRequest);
  if (AType = 'authentication_error') or (AType = 'permission_error') or
    (AType = 'billing_error') then
    Exit(aecAuthentication);
  if AType = 'not_found_error' then
    Exit(aecNotFound);
  Result := aecServer;
end;

{ ---- 编码（§2.1）薄壳：实现已下沉至 anthropic.encode 子域 ---- }
function EncodeAnthropicRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText; inline;
begin
  Result := nextpas.core.agent.provider.anthropic.encode.EncodeAnthropicRequest(AReq, AStream);
end;

function EncodeAnthropicCountTokensRequest(
  const AReq: TCompletionRequest): TJsonText; inline;
begin
  Result := nextpas.core.agent.provider.anthropic.encode.EncodeAnthropicCountTokensRequest(AReq);
end;

{ ---- 非流式解码（§2.2）薄壳：实现已下沉至 anthropic.decode 子域 ---- }
procedure DecodeAnthropicResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger); inline;
begin
  nextpas.core.agent.provider.anthropic.decode.DecodeAnthropicResponse(ABody, AMsg, ALog);
end;

{ ---- 流帧解码器（§2.3）---- }

{ ---- 流帧解码器（§2.3）薄壳：实现已下沉至 anthropic.decoder 子域 ---- }
function NewAnthropicWireDecoder(const ALog: ILogger): IAgentWireDecoder; inline;
begin
  Result := nextpas.core.agent.provider.anthropic.decoder.NewAnthropicWireDecoder(ALog);
end;

{ ---- provider ---- }

type
  TAnthropicProvider = class(TInterfacedObject, IAgentProvider,
    IAgentTokenCounter)
  private
    FOpts: TAnthropicOptions;
    FTransport: IAgentTransport;
    FLog: ILogger;
    function ResolveModel(const AReq: TCompletionRequest): string;
    { W12 拆分：装配前置（鉴权/模型解析/Q-A5 待遇）与传输选项填装，
      messages 与 count_tokens 两路径共用 }
    function PrepRequest(
      const AReq: TCompletionRequest): TCompletionRequest;
    procedure ApplyTransportOptions(var AWire: TWireRequest);
    function BuildWireRequest(const AReq: TCompletionRequest;
      AStream: Boolean): TWireRequest;
  public
    constructor Create(const AOpts: TAnthropicOptions);
    function GetName: string;
    function Complete(const AReq: TCompletionRequest): TMessage; overload;
    function Complete(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): TMessage; overload;
    function Stream(
      const AReq: TCompletionRequest): IAgentCompletion; overload;
    function Stream(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): IAgentCompletion; overload;
    function CountTokens(const AReq: TCompletionRequest): Int64;
  end;

constructor TAnthropicProvider.Create(const AOpts: TAnthropicOptions);
begin
  inherited Create;
  FOpts := AOpts;
  FLog := AOpts.Common.Logger;
  if FOpts.Common.Transport <> nil then
    FTransport := FOpts.Common.Transport
  else
    FTransport := NewHttpTransport('anthropic');
end;

function TAnthropicProvider.GetName: string;
begin
  Result := 'anthropic';
end;

function TAnthropicProvider.ResolveModel(
  const AReq: TCompletionRequest): string;
begin
  if AReq.Model <> '' then
    Exit(AReq.Model);
  if FOpts.Common.Model <> '' then
    Exit(FOpts.Common.Model);
  raise EAgentError.CreateLocal(aecConfig,
    'anthropic: model is required (request.Model or options.Common.Model)');
end;

function TAnthropicProvider.PrepRequest(
  const AReq: TCompletionRequest): TCompletionRequest;
begin
  if FOpts.Common.ApiKey = '' then
    raise EAgentError.CreateLocal(aecConfig,
      'anthropic: api key is required (' + CANTHROPIC_ENV_API_KEY + ')');
  Result := AReq;
  Result.Model := ResolveModel(AReq);
  { Q-A5 / Seed：无对应参数，忽略并记日志，不算错误 }
  if Result.ParallelToolCalls <> tsUnset then
    WarnLog(FLog,
      'anthropic: parallel_tool_calls has no wire parameter (Q-A5), ignored');
  if Result.Seed <> CSeedUnset then
    DebugLog(FLog, 'anthropic: seed has no wire parameter, ignored');
  if Result.ReasoningEffort <> reUnset then
    WarnLog(FLog,
      'anthropic: reasoning_effort has no wire parameter (W7), ignored; ' +
      'use Thinking/ThinkingBudgetTokens');
  if Result.ToolChoice = tcmNone then
    DebugLog(FLog,
      'anthropic: tool_choice none translated to omitting tools (Q-A9)');
end;

procedure TAnthropicProvider.ApplyTransportOptions(var AWire: TWireRequest);
var
  LVer: string;
begin
  LVer := FOpts.AnthropicVersion;
  if LVer = '' then
    LVer := CANTHROPIC_VERSION_DEFAULT;
  AgentWireAddAnthropicHeaders(AWire, FOpts.Common, LVer);
end;

function TAnthropicProvider.BuildWireRequest(
  const AReq: TCompletionRequest; AStream: Boolean): TWireRequest;
begin
  Result := Default(TWireRequest);
  Result.Url := BuildAnthropicUrl(FOpts.Common.BaseUrl);
  Result.BodyJson := EncodeAnthropicRequest(PrepRequest(AReq), AStream);
  ApplyTransportOptions(Result);
  AgentWireApplyIdempotency(Result, AReq);
end;

function TAnthropicProvider.CountTokens(
  const AReq: TCompletionRequest): Int64;
var
  LWire: TWireRequest;
  LResp: TWireResponse;
  LDoc: IJsonDocument;
begin
  { §2.7：count_tokens 端点往返；错误分类与 Complete 同一管线
    （本地 aecConfig / 上游 transport 归约 / 缺键 aecProtocol）}
  LWire := Default(TWireRequest);
  LWire.Url := BuildAnthropicCountTokensUrl(FOpts.Common.BaseUrl);
  LWire.BodyJson := EncodeAnthropicCountTokensRequest(PrepRequest(AReq));
  ApplyTransportOptions(LWire);
  AgentWireApplyIdempotency(LWire, AReq);
  FTransport.RoundTrip(LWire, LResp);
  LDoc := JsonParse(LResp.BodyText);
  if LDoc.HasError or (not LDoc.Root.IsObject) then
    ProtocolError(LResp.BodyText, 'count_tokens response must be a JSON object');
  if not LDoc.Root.Get('input_tokens').IsInt then
    ProtocolError(LResp.BodyText, 'count_tokens response missing input_tokens');
  Result := LDoc.Root.Get('input_tokens').AsInt;
end;

function TAnthropicProvider.Complete(
  const AReq: TCompletionRequest): TMessage;
var
  LResp: TWireResponse;
begin
  FTransport.RoundTrip(BuildWireRequest(AReq, False), LResp);
  DecodeAnthropicResponse(LResp.BodyText, Result, FLog);
end;

function TAnthropicProvider.Complete(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): TMessage;
begin
  { 同步 transport 无法中断在途请求：令牌在起止点检查（诚实边界）}
  if Assigned(AToken) and AToken.IsCancelled then
    raise EAgentCancelled.Create;
  Result := Complete(AReq);
end;

function TAnthropicProvider.Stream(
  const AReq: TCompletionRequest): IAgentCompletion;
begin
  Result := TWireBackedCompletion.Create(
    FTransport.OpenStream(BuildWireRequest(AReq, True)),
    NewAnthropicWireDecoder(FLog), nil, 'anthropic');
end;

function TAnthropicProvider.Stream(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): IAgentCompletion;
begin
  Result := TWireBackedCompletion.Create(
    FTransport.OpenStream(BuildWireRequest(AReq, True)),
    NewAnthropicWireDecoder(FLog), AToken, 'anthropic');
end;

class function TAnthropicOptions.New(
  const AModel: string): TAnthropicOptions;
begin
  Result := Default(TAnthropicOptions);
  Result.Common.BaseUrl := CANTHROPIC_DEFAULT_BASE_URL;
  Result.Common.Model := AModel;
  Result.Common.ConnectTimeoutMs := CANTHROPIC_CONNECT_TIMEOUT_MS;
  Result.Common.TotalTimeoutMs := CANTHROPIC_TOTAL_TIMEOUT_MS;
  Result.AnthropicVersion := CANTHROPIC_VERSION_DEFAULT;
end;

function NewAnthropicProvider(
  const AOpts: TAnthropicOptions): IAgentProvider;
begin
  Result := TAnthropicProvider.Create(AOpts);
end;

function NewAnthropicProviderFromEnvWithReader(const AReader: TAgentEnvReaderAnth): IAgentProvider;
var
  O: TAnthropicOptions;
  LUrl: string;
begin
  if not Assigned(AReader) then
    Exit(nil);
  O := TAnthropicOptions.New('');
  O.Common.ApiKey := AReader(CANTHROPIC_ENV_API_KEY);
  O.Common.Model := AReader(CANTHROPIC_ENV_MODEL);
  LUrl := AReader(CANTHROPIC_ENV_BASE_URL);
  if LUrl <> '' then
    O.Common.BaseUrl := LUrl;
  if (O.Common.ApiKey = '') or (O.Common.Model = '') then
    Exit(nil);
  Result := NewAnthropicProvider(O);
end;

function NewAnthropicProviderFromEnv: IAgentProvider;
begin
  Result := NewAnthropicProviderFromEnvWithReader(@GetEnvironmentVariable);
end;

end.
