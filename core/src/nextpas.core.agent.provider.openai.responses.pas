{**
 * nextpas.core.agent.provider.openai.responses - OpenAI Responses 适配器。
 *
 * 契约权威：WIRE-MAPPINGS §3（唯一映射真相源）、API.md §8。第三协议支柱：
 * 与 Chat Completions 共享公共规则（§0）但请求/响应/SSE 三面形态均不同。
 * 怪癖落点：Q-R1（无 stop 参数，provider 层忽略+warn）、Q-R2（SSE event 名
 * 为主键）、Q-R3（function 定义与调用项平铺、id 叫 call_id）、Q-R4（usage
 * 字段名差异）、Q-R5（截断流 fail-closed）、Q-R6（structured output 走
 * text.format）。
 *
 * 编解码器公开即免费（D13）：与 provider 工厂共用同一实现。编码器纯函数；
 * 解码器实例单角色独占。未映射枚举值零值 + agent.unmapped.* 捕获 + warn。
 *
 * 体积与拆分（P-modularity，F-M10 同款）：
 *  - 现状 256 行（原 1141 行，已拆 encode 307 + decode 245 + decoder 441 至子域；已 <800 阈值，
 *    模块化达标，ARCHITECTURE §2 已更新进度）；
 *    后续新增代码优先落子域。
 *  - 拆分进度（调用方零改动，已落地 3/4）：
 *      ✓ nextpas.core.agent.provider.openai.responses.encode  （Encode* 纯函数，307 行）
 *      ✓ nextpas.core.agent.provider.openai.responses.decode  （Decode* 纯函数，245 行）
 *      ✓ nextpas.core.agent.provider.openai.responses.decoder （WireDecoder 状态机，441 行）
 *      ○ nextpas.core.agent.provider.openai.responses.factory （BuildUrl/Provider 工厂）
 *    本单元为转发薄壳（inline 转发，调用方 `uses ...responses` 零改动）；
 *    门面 `nextpas.core.agent` 同步透出（ARCH §7 白名单）。
 *  - 约束：子域互不循环，仅向下依赖 base/errors/intf/common 等。
 *}

unit nextpas.core.agent.provider.openai.responses;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.async.cancellation,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.provider.openai;

{ BaseUrl 拼接（同 §0 规则）：去尾 '/'；已含 '/v1' 结尾则只追加 /responses，
  否则追加完整默认路径（支持反代前缀部署）。公开便于测试 }
function BuildResponsesUrl(const ABaseUrl: string): string;

{ ---- 纯编解码器（D13 公开表面；只认 WIRE-MAPPINGS §3）---- }

function EncodeResponsesRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText;

procedure DecodeResponsesResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger = nil);

function NewResponsesWireDecoder(
  const ALog: ILogger = nil): IAgentWireDecoder;

{ ---- provider 工厂 ---- }
{ 端点/凭据环境变量与 Chat Completions 同族（NEXTPAS_AGENT_OPENAI_*）：
  同一供应商同一把 key，仅 wire 方言不同 }

function NewOpenAIResponsesProvider(
  const AOpts: TOpenAIOptions): IAgentProvider;
type
  TAgentEnvReaderResp = function(const AName: string): string;
function NewOpenAIResponsesProviderFromEnv: IAgentProvider;
function NewOpenAIResponsesProviderFromEnvWithReader(const AReader: TAgentEnvReaderResp): IAgentProvider;

implementation

uses
  nextpas.core.json,
  nextpas.core.json.builder,
  nextpas.core.text.builder,
  nextpas.core.os.env,
  nextpas.core.agent.transport.http,
  nextpas.core.agent.provider.common,
  nextpas.core.agent.provider.openai.responses.encode,
  nextpas.core.agent.provider.openai.responses.decode,
  nextpas.core.agent.provider.openai.responses.decoder;

procedure WarnLog(const ALog: ILogger; const AMsg: string); inline;
begin
  AgentWarnLog(ALog, AMsg);
end;

procedure ProtocolError(const ABodySrc: string; const AMsg: string); inline;
begin
  AgentProtocolError('openai.responses', ABodySrc, AMsg);
end;

function BuildResponsesUrl(const ABaseUrl: string): string;
begin
  Result := AgentJoinWireUrl(ABaseUrl, COPENAI_DEFAULT_BASE_URL, '/responses');
end;

{ ---- 编码薄壳：实现已下沉至 responses.encode 子域 ---- }
function EncodeResponsesRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText; inline;
begin
  Result := nextpas.core.agent.provider.openai.responses.encode.EncodeResponsesRequest(AReq, AStream);
end;

{ ---- 非流式解码薄壳：实现已下沉至 responses.decode 子域 ---- }
procedure DecodeResponsesResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger); inline;
begin
  nextpas.core.agent.provider.openai.responses.decode.DecodeResponsesResponse(ABody, AMsg, ALog);
end;

{ ---- 流帧解码器薄壳：实现已下沉至 responses.decoder 子域 ---- }
function NewResponsesWireDecoder(const ALog: ILogger): IAgentWireDecoder; inline;
begin
  Result := nextpas.core.agent.provider.openai.responses.decoder.NewResponsesWireDecoder(ALog);
end;

{ ---- provider 与 completion ---- }

type
  TResponsesProvider = class(TInterfacedObject, IAgentProvider)
  private
    FOpts: TOpenAIOptions;
    FTransport: IAgentTransport;
    FLog: ILogger;
    FName: string;
    function ResolveModel(const AReq: TCompletionRequest): string;
    function BuildWireRequest(const AReq: TCompletionRequest;
      AStream: Boolean): TWireRequest;
  public
    constructor Create(const AOpts: TOpenAIOptions;
      const AName: string = 'openai-responses');
    function GetName: string;
    function Complete(const AReq: TCompletionRequest): TMessage; overload;
    function Complete(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): TMessage; overload;
    function Stream(
      const AReq: TCompletionRequest): IAgentCompletion; overload;
    function Stream(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): IAgentCompletion; overload;
  end;

constructor TResponsesProvider.Create(const AOpts: TOpenAIOptions;
  const AName: string);
begin
  inherited Create;
  FOpts := AOpts;
  FName := AName;
  FLog := AOpts.Common.Logger;
  if FOpts.Common.Transport <> nil then
    FTransport := FOpts.Common.Transport
  else
    FTransport := NewHttpTransport(FName);
end;

function TResponsesProvider.GetName: string;
begin
  Result := FName;
end;

function TResponsesProvider.ResolveModel(
  const AReq: TCompletionRequest): string;
begin
  if AReq.Model <> '' then
    Exit(AReq.Model);
  if FOpts.Common.Model <> '' then
    Exit(FOpts.Common.Model);
  raise EAgentError.CreateLocal(aecConfig,
    'openai.responses: model is required ' +
    '(request.Model or options.Common.Model)');
end;

function TResponsesProvider.BuildWireRequest(
  const AReq: TCompletionRequest; AStream: Boolean): TWireRequest;
var
  LReq: TCompletionRequest;
begin
  AgentRequireApiKey(FOpts.Common.ApiKey, COPENAI_ENV_API_KEY);
  LReq := AReq;
  LReq.Model := ResolveModel(AReq);
  if Length(LReq.StopSequences) > 0 then
    WarnLog(FLog,
      'openai.responses: stop sequences have no wire parameter (Q-R1), ' +
      'ignored');
  LReq.StopSequences := nil;
  Result := Default(TWireRequest);
  Result.Url := BuildResponsesUrl(FOpts.Common.BaseUrl);
  Result.BodyJson := EncodeResponsesRequest(LReq, AStream);
  AgentWireAddOpenAIHeaders(Result, FOpts.Common, FOpts.Organization);
  AgentWireApplyIdempotency(Result, AReq);
end;

function TResponsesProvider.Complete(
  const AReq: TCompletionRequest): TMessage;
var
  LResp: TWireResponse;
begin
  FTransport.RoundTrip(BuildWireRequest(AReq, False), LResp);
  DecodeResponsesResponse(LResp.BodyText, Result, FLog);
end;

function TResponsesProvider.Complete(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): TMessage;
begin
  if Assigned(AToken) and AToken.IsCancelled then
    raise EAgentCancelled.Create;
  Result := Complete(AReq);
end;

function TResponsesProvider.Stream(
  const AReq: TCompletionRequest): IAgentCompletion;
begin
  Result := TWireBackedCompletion.Create(
    FTransport.OpenStream(BuildWireRequest(AReq, True)),
    NewResponsesWireDecoder(FLog), nil, FName);
end;

function TResponsesProvider.Stream(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): IAgentCompletion;
begin
  Result := TWireBackedCompletion.Create(
    FTransport.OpenStream(BuildWireRequest(AReq, True)),
    NewResponsesWireDecoder(FLog), AToken, FName);
end;

{ ---- 工厂 ---- }

function NewOpenAIResponsesProvider(
  const AOpts: TOpenAIOptions): IAgentProvider;
begin
  Result := TResponsesProvider.Create(AOpts);
end;

function NewOpenAIResponsesProviderFromEnvWithReader(const AReader: TAgentEnvReaderResp): IAgentProvider;
var
  O: TOpenAIOptions;
  LUrl: string;
begin
  if not Assigned(AReader) then
    Exit(nil);
  O := TOpenAIOptions.New('');
  O.Common.ApiKey := AReader(COPENAI_ENV_API_KEY);
  O.Common.Model := AReader(COPENAI_ENV_MODEL);
  LUrl := AReader(COPENAI_ENV_BASE_URL);
  if LUrl <> '' then
    O.Common.BaseUrl := LUrl;
  if (O.Common.ApiKey = '') or (O.Common.Model = '') then
    Exit(nil);
  Result := NewOpenAIResponsesProvider(O);
end;

function NewOpenAIResponsesProviderFromEnv: IAgentProvider;
begin
  Result := NewOpenAIResponsesProviderFromEnvWithReader(@GetEnvironmentVariable);
end;

end.
