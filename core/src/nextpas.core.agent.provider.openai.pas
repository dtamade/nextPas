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
 *  - 现状 ~150 行薄壳（原 1144 行，已拆 encode 352 + decode 216 + decoder 331 + factory 280 至子域；已 <800 阈值，
 *    模块化达标，ARCHITECTURE §2 已更新进度）；
 *    后续新增代码优先落子域。
 *  - 拆分进度（调用方零改动，已落地 4/4）：
 *      ✓ nextpas.core.agent.provider.openai.encode   （Encode* 纯函数）
 *      ✓ nextpas.core.agent.provider.openai.decode   （Decode* 纯函数）
 *      ✓ nextpas.core.agent.provider.openai.decoder  （WireDecoder 状态机）
 *      ✓ nextpas.core.agent.provider.openai.factory  （BuildUrl/Provider 工厂）
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
  nextpas.core.agent.provider.common,
  nextpas.core.agent.provider.openai.factory;

const
  COPENAI_DEFAULT_BASE_URL = nextpas.core.agent.provider.openai.factory.COPENAI_DEFAULT_BASE_URL;
  COPENAI_CONNECT_TIMEOUT_MS = nextpas.core.agent.provider.openai.factory.COPENAI_CONNECT_TIMEOUT_MS;
  COPENAI_TOTAL_TIMEOUT_MS = nextpas.core.agent.provider.openai.factory.COPENAI_TOTAL_TIMEOUT_MS;
  COPENAI_MAX_COMPLETION_TOKENS_PREFIXES: array[0..2] of string =
    ('o1', 'o3', 'gpt-5');
  COPENAI_ENV_API_KEY = nextpas.core.agent.provider.openai.factory.COPENAI_ENV_API_KEY;
  COPENAI_ENV_MODEL = nextpas.core.agent.provider.openai.factory.COPENAI_ENV_MODEL;
  COPENAI_ENV_BASE_URL = nextpas.core.agent.provider.openai.factory.COPENAI_ENV_BASE_URL;
  CGROK_DEFAULT_BASE_URL = nextpas.core.agent.provider.openai.factory.CGROK_DEFAULT_BASE_URL;
  CGROK_ENV_API_KEY = nextpas.core.agent.provider.openai.factory.CGROK_ENV_API_KEY;
  CGROK_ENV_MODEL = nextpas.core.agent.provider.openai.factory.CGROK_ENV_MODEL;
  CGROK_ENV_BASE_URL = nextpas.core.agent.provider.openai.factory.CGROK_ENV_BASE_URL;

type
  TOpenAIOptions = nextpas.core.agent.provider.openai.factory.TOpenAIOptions;
  TGrokOptions = nextpas.core.agent.provider.openai.factory.TGrokOptions;
  TAgentEnvReader = nextpas.core.agent.provider.openai.factory.TAgentEnvReader;

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
function NewOpenAIProviderFromEnvWithReader(const AReader: TAgentEnvReader): IAgentProvider;

function BuildGrokUrl(const ABaseUrl: string): string;
function NewGrokProvider(const AOpts: TGrokOptions): IAgentProvider;
function NewGrokProviderFromEnv: IAgentProvider;
function NewGrokProviderFromEnvWithReader(const AReader: TAgentEnvReader): IAgentProvider;

implementation

uses
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
  Result := nextpas.core.agent.provider.openai.factory.BuildOpenAIUrl(ABaseUrl);
end;

function BuildGrokUrl(const ABaseUrl: string): string; inline;
begin
  Result := nextpas.core.agent.provider.openai.factory.BuildGrokUrl(ABaseUrl);
end;

function NewOpenAIProvider(const AOpts: TOpenAIOptions): IAgentProvider; inline;
begin
  Result := nextpas.core.agent.provider.openai.factory.NewOpenAIProvider(AOpts);
end;

function NewOpenAIProviderFromEnv: IAgentProvider; inline;
begin
  Result := nextpas.core.agent.provider.openai.factory.NewOpenAIProviderFromEnv;
end;

function NewOpenAIProviderFromEnvWithReader(const AReader: TAgentEnvReader): IAgentProvider; inline;
begin
  Result := nextpas.core.agent.provider.openai.factory.NewOpenAIProviderFromEnvWithReader(AReader);
end;

function NewGrokProvider(const AOpts: TGrokOptions): IAgentProvider; inline;
begin
  Result := nextpas.core.agent.provider.openai.factory.NewGrokProvider(AOpts);
end;

function NewGrokProviderFromEnv: IAgentProvider; inline;
begin
  Result := nextpas.core.agent.provider.openai.factory.NewGrokProviderFromEnv;
end;

function NewGrokProviderFromEnvWithReader(const AReader: TAgentEnvReader): IAgentProvider; inline;
begin
  Result := nextpas.core.agent.provider.openai.factory.NewGrokProviderFromEnvWithReader(AReader);
end;

end.
