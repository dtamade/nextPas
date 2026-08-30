{**
 * nextpas.core.agent.provider.openai - OpenAI Chat Completions 兼容适配器。
 *
 * 契约权威：core/docs/agent/API.md §7/§8、WIRE-MAPPINGS §1（唯一映射真相源）。
 * 怪癖落点：Q-O1（推理族 max_completion_tokens 改名）、Q-O2（reasoning_content
 * → thinking 增量）、Q-O3（必发 stream_options.include_usage）、Q-O4（缺
 * [DONE] 断连=EOF）、Q-O5（tool_calls 首片 Start、按 index 分桶、无 End 事件）、
 * Q-O6（空 choices 中间帧跳过）、Q-O7（多 choice 丢弃 index>0 并 warn）。
 *
 * 编解码器公开即免费（D13）：Encode/Decode/NewWireDecoder 与 provider 工厂
 * 共用同一实现。编码器纯函数可并发；解码器实例单角色独占，不跨消息复用。
 * 未映射枚举值：词表零值 + agent.unmapped.<field> 捕获 + warn，绝不臆造近似。
 *
 * 家族：openai（api.openai.com）与 grok（api.x.ai）共用 Chat Completions
 * wire 方言与编解码器；差异仅默认端点、鉴权归因名与环境变量前缀。
 * Grok 特有怪癖（reasoning 别名、订阅网关 ping 心跳帧）内建于共享解码器，
 * 依据 sub2api 生产经验核对（WIRE-MAPPINGS §1.5/§1.6）。
 *
 * 体积与拆分（P-modularity，F-M10）：
 *  - 现状 397 行（原 1144 行，已拆 encode 352 + decode 216 + decoder 331 至子域；已 <800 阈值，
 *    模块化达标，ARCHITECTURE §2 已更新进度）；
 *    后续新增代码优先落子域。
 *  - 拆分进度（调用方零改动，已落地 3/4）：
 *      ✓ nextpas.core.agent.provider.openai.encode   （Encode* 纯函数）
 *      ✓ nextpas.core.agent.provider.openai.decode   （Decode* 纯函数）
 *      ✓ nextpas.core.agent.provider.openai.decoder  （WireDecoder 状态机）
 *      ○ nextpas.core.agent.provider.openai.factory  （BuildUrl/Provider 工厂）
 *    本单元为转发薄壳（inline 转发，调用方 `uses ...openai` 零改动）；
 *    门面 `nextpas.core.agent` 同步透出（ARCH §7 白名单）。
 *  - 约束：子域互不循环，仅向下依赖 base/errors/intf/common 等。
 *}

unit nextpas.core.agent.provider.openai;

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
  COPENAI_DEFAULT_BASE_URL = 'https://api.openai.com';
  COPENAI_CONNECT_TIMEOUT_MS = 10000;
  COPENAI_TOTAL_TIMEOUT_MS = 300000;

  COPENAI_MAX_COMPLETION_TOKENS_PREFIXES: array[0..2] of string =
    ('o1', 'o3', 'gpt-5');

  COPENAI_ENV_API_KEY = 'NEXTPAS_AGENT_OPENAI_API_KEY';
  COPENAI_ENV_MODEL = 'NEXTPAS_AGENT_OPENAI_MODEL';
  COPENAI_ENV_BASE_URL = 'NEXTPAS_AGENT_OPENAI_BASE_URL';

  CGROK_DEFAULT_BASE_URL = 'https://api.x.ai';
  CGROK_ENV_API_KEY = 'NEXTPAS_AGENT_GROK_API_KEY';
  CGROK_ENV_MODEL = 'NEXTPAS_AGENT_GROK_MODEL';
  CGROK_ENV_BASE_URL = 'NEXTPAS_AGENT_GROK_BASE_URL';

type
  TOpenAIOptions = record
    Common: TProviderOptions;
    Organization: string;
    class function New(const AModel: string): TOpenAIOptions; static;
  end;

  TGrokOptions = record
    Common: TProviderOptions;
    class function New(const AModel: string): TGrokOptions; static;
  end;

{ ---- 纯编解码器（D13 公开表面；只认 WIRE-MAPPINGS §1）---- }

function EncodeOpenAIRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText;

procedure DecodeOpenAIResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger = nil);

function NewOpenAIWireDecoder(
  const ALog: ILogger = nil): IAgentWireDecoder;

function BuildOpenAIUrl(const ABaseUrl: string): string;

{ ---- provider 工厂（openai 与 grok 两家族共用编解码器实现）---- }

function NewOpenAIProvider(const AOpts: TOpenAIOptions): IAgentProvider;
function NewOpenAIProviderFromEnv: IAgentProvider;
type
  TAgentEnvReader = function(const AName: string): string;
function NewOpenAIProviderFromEnvWithReader(const AReader: TAgentEnvReader): IAgentProvider;

function BuildGrokUrl(const ABaseUrl: string): string;
function NewGrokProvider(const AOpts: TGrokOptions): IAgentProvider;
function NewGrokProviderFromEnv: IAgentProvider;
function NewGrokProviderFromEnvWithReader(const AReader: TAgentEnvReader): IAgentProvider;

implementation

uses
  nextpas.core.os.env,
  nextpas.core.agent.fold,
  nextpas.core.agent.transport.http,
  nextpas.core.agent.provider.openai.encode,
  nextpas.core.agent.provider.openai.decode,
  nextpas.core.agent.provider.openai.decoder;

{ ---- 编码（§1.1）薄壳：实现已下沉至 openai.encode 子域 ---- }
function EncodeOpenAIRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText; inline;
begin
  Result := nextpas.core.agent.provider.openai.encode.EncodeOpenAIRequest(AReq, AStream);
end;

{ ---- 非流式解码（§1.2）薄壳：实现已下沉至 openai.decode 子域 ---- }
procedure DecodeOpenAIResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger); inline;
begin
  nextpas.core.agent.provider.openai.decode.DecodeOpenAIResponse(ABody, AMsg, ALog);
end;

{ ---- 流帧解码器（§1.3）薄壳：实现已下沉至 openai.decoder 子域 ---- }
function NewOpenAIWireDecoder(const ALog: ILogger): IAgentWireDecoder; inline;
begin
  Result := nextpas.core.agent.provider.openai.decoder.NewOpenAIWireDecoder(ALog);
end;

function BuildOpenAIUrl(const ABaseUrl: string): string; inline;
begin
  Result := nextpas.core.agent.provider.openai.encode.BuildOpenAIUrl(ABaseUrl);
end;

function BuildGrokUrl(const ABaseUrl: string): string; inline;
begin
  Result := nextpas.core.agent.provider.openai.encode.BuildGrokUrl(ABaseUrl);
end;

{ ---- provider 与 completion ---- }

type
  TOpenAIProvider = class(TInterfacedObject, IAgentProvider)
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
      const AName: string = 'openai');
    function GetName: string;
    function Complete(const AReq: TCompletionRequest): TMessage; overload;
    function Complete(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): TMessage; overload;
    function Stream(
      const AReq: TCompletionRequest): IAgentCompletion; overload;
    function Stream(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): IAgentCompletion; overload;
  end;

constructor TOpenAIProvider.Create(const AOpts: TOpenAIOptions;
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

function TOpenAIProvider.GetName: string;
begin
  Result := FName;
end;

function TOpenAIProvider.ResolveModel(
  const AReq: TCompletionRequest): string;
begin
  if AReq.Model <> '' then
    Exit(AReq.Model);
  if FOpts.Common.Model <> '' then
    Exit(FOpts.Common.Model);
  raise EAgentError.CreateLocal(aecConfig,
    'openai: model is required (request.Model or options.Common.Model)');
end;

function TOpenAIProvider.BuildWireRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TWireRequest;
var
  LReq: TCompletionRequest;
begin
  AgentRequireApiKey(FOpts.Common.ApiKey, COPENAI_ENV_API_KEY);
  LReq := AReq;
  LReq.Model := ResolveModel(AReq);
  Result := Default(TWireRequest);
  Result.Url := BuildOpenAIUrl(FOpts.Common.BaseUrl);
  Result.BodyJson := EncodeOpenAIRequest(LReq, AStream);
  AgentWireAddOpenAIHeaders(Result, FOpts.Common, FOpts.Organization);
  AgentWireApplyIdempotency(Result, AReq);
end;

function TOpenAIProvider.Complete(const AReq: TCompletionRequest): TMessage;
var
  LResp: TWireResponse;
begin
  FTransport.RoundTrip(BuildWireRequest(AReq, False), LResp);
  DecodeOpenAIResponse(LResp.BodyText, Result, FLog);
end;

function TOpenAIProvider.Complete(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): TMessage;
begin
  if Assigned(AToken) and AToken.IsCancelled then
    raise EAgentCancelled.Create;
  Result := Complete(AReq);
end;

function TOpenAIProvider.Stream(
  const AReq: TCompletionRequest): IAgentCompletion;
begin
  Result := TWireBackedCompletion.Create(
    FTransport.OpenStream(BuildWireRequest(AReq, True)),
    NewOpenAIWireDecoder(FLog), nil, FName);
end;

function TOpenAIProvider.Stream(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): IAgentCompletion;
begin
  Result := TWireBackedCompletion.Create(
    FTransport.OpenStream(BuildWireRequest(AReq, True)),
    NewOpenAIWireDecoder(FLog), AToken, FName);
end;

{ ---- 工厂 ---- }

class function TOpenAIOptions.New(const AModel: string): TOpenAIOptions;
begin
  Result := Default(TOpenAIOptions);
  Result.Common.BaseUrl := COPENAI_DEFAULT_BASE_URL;
  Result.Common.Model := AModel;
  Result.Common.ConnectTimeoutMs := COPENAI_CONNECT_TIMEOUT_MS;
  Result.Common.TotalTimeoutMs := COPENAI_TOTAL_TIMEOUT_MS;
end;

function NewOpenAIProvider(const AOpts: TOpenAIOptions): IAgentProvider;
begin
  Result := TOpenAIProvider.Create(AOpts);
end;

function NewOpenAIProviderFromEnvWithReader(const AReader: TAgentEnvReader): IAgentProvider;
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
  Result := NewOpenAIProvider(O);
end;

function NewOpenAIProviderFromEnv: IAgentProvider;
begin
  Result := NewOpenAIProviderFromEnvWithReader(@GetEnvironmentVariable);
end;

{ ---- Grok 家族（wire 同族，仅默认端点与归因名不同）---- }

class function TGrokOptions.New(const AModel: string): TGrokOptions;
begin
  Result := Default(TGrokOptions);
  Result.Common.BaseUrl := CGROK_DEFAULT_BASE_URL;
  Result.Common.Model := AModel;
  Result.Common.ConnectTimeoutMs := COPENAI_CONNECT_TIMEOUT_MS;
  Result.Common.TotalTimeoutMs := COPENAI_TOTAL_TIMEOUT_MS;
end;

function NewGrokProvider(const AOpts: TGrokOptions): IAgentProvider;
var
  LO: TOpenAIOptions;
begin
  LO := Default(TOpenAIOptions);
  LO.Common := AOpts.Common;
  Result := TOpenAIProvider.Create(LO, 'grok');
end;

function NewGrokProviderFromEnvWithReader(const AReader: TAgentEnvReader): IAgentProvider;
var
  O: TGrokOptions;
  LUrl: string;
begin
  if not Assigned(AReader) then
    Exit(nil);
  O := TGrokOptions.New('');
  O.Common.ApiKey := AReader(CGROK_ENV_API_KEY);
  O.Common.Model := AReader(CGROK_ENV_MODEL);
  LUrl := AReader(CGROK_ENV_BASE_URL);
  if LUrl <> '' then
    O.Common.BaseUrl := LUrl;
  if (O.Common.ApiKey = '') or (O.Common.Model = '') then
    Exit(nil);
  Result := NewGrokProvider(O);
end;

function NewGrokProviderFromEnv: IAgentProvider;
begin
  Result := NewGrokProviderFromEnvWithReader(@GetEnvironmentVariable);
end;

end.
