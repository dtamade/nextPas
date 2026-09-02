{**
 * nextpas.core.agent — AI provider 客户端与通用工具循环门面。
 *
 * 契约权威：core/docs/agent/API.md；分组与白名单见 ARCHITECTURE §7。
 * 实现与文档冲突时，先改文档。门面纯 re-export + inline 转发，零逻辑。
 * DoS / 截断上限单一真源：nextpas.core.agent.base（CAgentMax*）。
 * 词表经 base / errors 直接可用；provider 构造入口随 W1 / W2 落位。
 * 分组导出：按 ARCH §7 白名单八域分组（词表与常量 / Provider 工厂与编解码器 /
 * 时钟 / 工具 / 循环 / 会话 / 韧性与可靠性装饰器 / 配额），wire 细节不进门面。
 * 设计质感：克制、精准、可回滚 — 少即是多。
 *}

unit nextpas.core.agent;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.async.cancellation,
  nextpas.core.thread,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.clock,
  nextpas.core.agent.retry,
  nextpas.core.agent.provider.common,
  nextpas.core.agent.provider.openai,
  nextpas.core.agent.provider.anthropic,
  nextpas.core.agent.provider.fake,
  nextpas.core.agent.tools,
  nextpas.core.agent.loop,
  nextpas.core.agent.session,
  nextpas.core.agent.resilience,
  nextpas.core.agent.fallback,
  nextpas.core.agent.throttle,
  nextpas.core.agent.hedge,
  nextpas.core.agent.provider.openai.responses,
  nextpas.core.agent.transport.trace,
  nextpas.core.agent.quota,
  nextpas.core.agent.pricing,
  nextpas.core.agent.snapshot,
  nextpas.core.agent.streambox;

function ErrorCodeForStatus(AStatus: Integer): TAgentErrorCode; inline;
function IsRetryable(ACode: TAgentErrorCode): Boolean; inline;
function AgentErrorCodeName(ACode: TAgentErrorCode): string; inline;

{ ── DoS 上限常量 · 单一真源透出（nextpas.core.agent.base，免破层 uses） ── }
const
  CAgentMaxSlotMap = nextpas.core.agent.base.CAgentMaxSlotMap;
  CAgentMaxWireHeaderValueBytes = nextpas.core.agent.base.CAgentMaxWireHeaderValueBytes;
  CAgentMaxWireTotalHeaderBytes = nextpas.core.agent.base.CAgentMaxWireTotalHeaderBytes;
  CAgentMaxSuccessBodyBytes = nextpas.core.agent.base.CAgentMaxSuccessBodyBytes;
  CAgentMaxRawBodySnippetBytes = nextpas.core.agent.base.CAgentMaxRawBodySnippetBytes;
  CAgentMaxExtraKeys = nextpas.core.agent.base.CAgentMaxExtraKeys;
  CAgentMaxToolArgsBytes = nextpas.core.agent.base.CAgentMaxToolArgsBytes;
  CAgentToolArgsInitialCap = nextpas.core.agent.base.CAgentToolArgsInitialCap;
  CAgentSystemTextInitialCap = nextpas.core.agent.base.CAgentSystemTextInitialCap;
  CAgentSessionForkInitialCap = nextpas.core.agent.base.CAgentSessionForkInitialCap;

{ ── 词表 helpers · 单入口透出（base，免破层 uses） ── }

function MessageText(const AMsg: TMessage): string; inline;
function WireHeaderValue(const AHeaders: TWireHeaderArray;
  const AName: string): string; inline;
function MergeExtraJson(const ATexts: array of TJsonText): TJsonText; inline;
function AgentUtf8SafeTruncate(const S: string; AMaxBytes: Integer): string; inline;
procedure AgentInitUsageUnknown(var AUsage: TTokenUsage); inline;
function AgentTruncateLines(const S: string; AMaxLines: Integer): string; inline;
function AgentTruncateEnvelope(const S: string; AMaxLines, AMaxBytes: Integer;
  out ATruncated: Boolean): string; inline;
function AgentJoinWireUrl(const ABaseUrl, ADefault, ASuffix: string): string; inline;
function AgentBuildSystemText(const ASystem: string;
  const AMessages: TMessageArray): string; inline;
function AgentBuildBatchSignature(const AMsg: TMessage): string; inline;
procedure AgentValidateWireHeaders(const AHeaders: TWireHeaderArray); inline;

{ ── 时钟 · ARCH §7 白名单（NewSystemClock / TFakeClock / IAgentClock） ── }

function NewSystemClock: IAgentClock; inline;
type
  TFakeClock = nextpas.core.agent.clock.TFakeClock;

{ ── 重试装饰器 · API.md §3 / §5（WithRetry / TRetryPolicy） ── }

function WithRetry(const AInner: IAgentProvider; const APolicy: TRetryPolicy;
  const AClock: IAgentClock): IAgentProvider; overload; inline;
function WithRetry(const AInner: IAgentProvider; const APolicy: TRetryPolicy;
  const AClock: IAgentClock;
  const AToken: IAsyncCancellationToken): IAgentProvider; overload; inline;

{ ── Provider 工厂与编解码器（D13 公开表面）· ARCH §7 白名单 ── }
{ OpenAI Chat Completions · API.md §7 / §8 }

function EncodeOpenAIRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText; inline;
procedure DecodeOpenAIResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger = nil); inline;
function NewOpenAIWireDecoder(
  const ALog: ILogger = nil): IAgentWireDecoder; inline;
function BuildOpenAIUrl(const ABaseUrl: string): string; inline;
function NewOpenAIProvider(const AOpts: TOpenAIOptions): IAgentProvider; inline;
function NewOpenAIProviderFromEnv: IAgentProvider; inline;

{ ── Grok（xAI）家族 · 同族 wire，复用 OpenAI 编解码器 ── }

function BuildGrokUrl(const ABaseUrl: string): string; inline;
function NewGrokProvider(const AOpts: TGrokOptions): IAgentProvider; inline;
function NewGrokProviderFromEnv: IAgentProvider; inline;

{ ── Anthropic Messages · API.md §7 / §8 ── }

function EncodeAnthropicRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText; inline;
procedure DecodeAnthropicResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger = nil); inline;
function NewAnthropicWireDecoder(
  const ALog: ILogger = nil): IAgentWireDecoder; inline;
function BuildAnthropicUrl(const ABaseUrl: string): string; inline;
function EncodeAnthropicCountTokensRequest(
  const AReq: TCompletionRequest): TJsonText; inline;
function BuildAnthropicCountTokensUrl(const ABaseUrl: string): string; inline;
function NewAnthropicProvider(
  const AOpts: TAnthropicOptions): IAgentProvider; inline;
function NewAnthropicProviderFromEnv: IAgentProvider; inline;

{ ── OpenAI Responses · API.md §8 / W9 第三支柱 · D13 公开编解码器 ── }

function EncodeResponsesRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText; inline;
procedure DecodeResponsesResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger = nil); inline;
function NewResponsesWireDecoder(
  const ALog: ILogger = nil): IAgentWireDecoder; inline;
function BuildResponsesUrl(const ABaseUrl: string): string; inline;

{ ── 工具 · ARCH §7 白名单（ValidateToolSpec / ValidateToolArguments / EnvelopeTruncation / NewToolContext / WithTools） ── }

procedure ValidateToolSpec(const ASpec: TToolSpec); inline;
function ValidateToolArguments(const ASpec: TToolSpec;
  const AArgsJson: TJsonText): TToolResult; inline;
function EnvelopeTruncation(const AResult: TToolResult;
  AMaxLines, AMaxBytes: Integer): TToolResult; inline;
function NewToolContext(const AToken: IAsyncCancellationToken;
  ACallIndex: Integer): IToolContext; inline;
function WithTools(const ATools: array of IAgentTool): TToolSpecArray; inline;

{ ── 循环 · ARCH §7 白名单（TAgentLoop / TAgentLoopOptions / TLoopEvent / TLoopOutcome / Set* / WithRetry） ── }
type
  TAgentLoop = nextpas.core.agent.loop.TAgentLoop;
  TAgentLoopOptions = nextpas.core.agent.loop.TAgentLoopOptions;
  TLoopEvent = nextpas.core.agent.loop.TLoopEvent;
  TLoopEventKind = nextpas.core.agent.loop.TLoopEventKind;
  TLoopOutcome = nextpas.core.agent.loop.TLoopOutcome;

{ ── 会话 · ARCH §7 白名单 / W5 · API.md §3 · SESSION.md ── }

type
  TJsonlTranscriptStore = nextpas.core.agent.session.TJsonlTranscriptStore;
  ETranscriptCorrupt = nextpas.core.agent.session.ETranscriptCorrupt;

function NewJsonlTranscriptStore(const ARootDir: string;
  ASyncEachAppend: Boolean = True): IAgentTranscriptStore; inline;

{ ── 韧性与可靠性装饰器 · ARCH §7 白名单 / W8-W11 · 自 code888 韧弧 K69-K75 提炼 ── }

function StreamHasError(const ADeltas: TStreamDeltaArray;
  ACode: TAgentErrorCode): Boolean; inline;
function WaitCancelMs(const AToken: IAsyncCancellationToken;
  ADelayMs: Int64): Boolean; overload; inline;
function WaitCancelMs(const ASource: ICancellationSource;
  ADelayMs: Int64): Boolean; overload; inline; deprecated 'use IAsyncCancellationToken overload (C10)';
function WaitCancelSlice(const AToken: IAsyncCancellationToken;
  ASliceMs: Int64): Boolean; inline;
function ClampHintMs(AHintMs, ACapMs: Int64): Int64; inline;

{ ── 可靠性装饰器（续）· 策略域：fallback / throttle / hedge / trace / tokenCounter ── }

type
  TFallbackPolicy = nextpas.core.agent.fallback.TFallbackPolicy;
  TFallbackSwitchHook = nextpas.core.agent.fallback.TFallbackSwitchHook;
  IAgentRateGate = nextpas.core.agent.throttle.IAgentRateGate;
  TThrottlePolicy = nextpas.core.agent.throttle.TThrottlePolicy;
  TThrottleWaitHook = nextpas.core.agent.throttle.TThrottleWaitHook;
  THedgePolicy = nextpas.core.agent.hedge.THedgePolicy;
  THedgeFireHook = nextpas.core.agent.hedge.THedgeFireHook;
  IAgentTraceSink = nextpas.core.agent.intf.IAgentTraceSink;
  TTraceRequestInfo = nextpas.core.agent.base.TTraceRequestInfo;
  TTraceResponseInfo = nextpas.core.agent.base.TTraceResponseInfo;
  IAgentTokenCounter = nextpas.core.agent.intf.IAgentTokenCounter;
  IAgentUsageSink = nextpas.core.agent.intf.IAgentUsageSink;

function NewFallbackProvider(const AChain: array of IAgentProvider;
  const APolicy: TFallbackPolicy): IAgentProvider; inline;
function NewThrottledProvider(const AInner: IAgentProvider;
  const AGate: IAgentRateGate; const AClock: IAgentClock;
  const APolicy: TThrottlePolicy): IAgentProvider; inline;
function NewTokenBucketGate(ARatePerSecond,
  ABurst: Double): IAgentRateGate; inline;

{ ── W9 · 对冲装饰器 + OpenAI Responses 协议支柱 ── }
function NewHedgedProvider(const AInner: IAgentProvider;
  const AClock: IAgentClock; const APolicy: THedgePolicy): IAgentProvider; inline;
function NewOpenAIResponsesProvider(
  const AOpts: TOpenAIOptions): IAgentProvider; inline;
function NewOpenAIResponsesProviderFromEnv: IAgentProvider; inline;

{ ── Fake / Echo · 测试替身 · API.md §7 ── }
function NewFakeProvider(const AScriptJson: TJsonText): IAgentProvider; inline;
function NewEchoProvider: IAgentProvider; inline;

{ ── W11 · 请求级追踪 · transport 装饰器一处接线三适配器（API.md §3.2） ── }
function NewTracedTransport(const AName: string;
  const ASink: IAgentTraceSink; const AInner: IAgentTransport;
  const AClock: IAgentClock = nil): IAgentTransport; inline;

{ ── 配额标量滚动窗口 · 纯标量 O(1) 零IO · Phase1 T1.2 ── }
type
  TPlatformQuotaWindowKind = nextpas.core.agent.quota.TPlatformQuotaWindowKind;
  TPlatformQuotaItem = nextpas.core.agent.quota.TPlatformQuotaItem;
  TPlatformQuotaArray = nextpas.core.agent.quota.TPlatformQuotaArray;

function PlatformQuotaWindowSeconds(const AKind: TPlatformQuotaWindowKind): Int64; inline;
function PlatformQuotaWindowExpired(const AKind: TPlatformQuotaWindowKind;
  const AStart, ANowSec: Int64): Boolean; inline;
function PlatformQuotaExpired(const AKind: TPlatformQuotaWindowKind;
  const AStart, ANowSec: Int64): Boolean; inline;
function PlatformQuotaUsage(const AKind: TPlatformQuotaWindowKind;
  const AUsage, AStart, ANowSec: Int64): Int64; inline;
function PlatformQuotaExceeded(const AKind: TPlatformQuotaWindowKind;
  const ALimit, AUsage, AStart, ANowSec, AEstCost: Int64): Boolean; inline;
function SerializePlatformQuotaItem(const AItem: TPlatformQuotaItem;
  const ANowSec: Int64): string; inline;
function PlatformQuotaSerialize(const AItem: TPlatformQuotaItem;
  const ANowSec: Int64): string; inline;

{ ── 定价 · 纯策略计费 · Phase1 T1.1 / T1.4 ── }
type
  TModelPricing = nextpas.core.agent.pricing.TModelPricing;
  TPassthroughPricing = nextpas.core.agent.pricing.TPassthroughPricing;

const
  CDefaultPromptPer1k = nextpas.core.agent.pricing.CDefaultPromptPer1k;
  CDefaultCompletionPer1k = nextpas.core.agent.pricing.CDefaultCompletionPer1k;

function EstimateCost(const APricing: TModelPricing;
  APromptTokens, ACompletionTokens: Int64;
  ARateMultiplier: Int64 = 10000): Int64; overload; inline;
function EstimateCost(const AUsage: TTokenUsage): Int64; overload; inline;
function EstimateCost(const AUsage: TTokenUsage;
  APromptPer1k, ACompletionPer1k: Int64): Int64; overload; inline;
function EstimateCost(APromptTokens, ACompletionTokens: Int64): Int64; overload; inline;
function EstimateCost(APromptTokens, ACompletionTokens: Int64;
  APromptPer1k, ACompletionPer1k: Int64): Int64; overload; inline;
function ImageTierOf(const AWidth, AHeight: Int64): Int64; inline;
function AgentEstimateTokens(const S: string): Int64; inline;
function AgentEstimateTokensFromMessage(const AMsg: TMessage): Int64; inline;

{ ── 有界快照 · PROMPT-BUDGET.md §2/§5 经 nextpas.core.agent.snapshot 复用 ── }
const
  CBoundedSnapshotBudget = nextpas.core.agent.snapshot.CBoundedSnapshotBudget;
function BuildBoundedSnapshot(const ASystem: string;
  const AMessages: TMessageArray; ABudget: Integer = CBoundedSnapshotBudget): string; inline;
function BoundedSnapshotTokens(const ASnapshot: string): Int64; inline;
function BoundedSnapshotCost(const ASnapshot: string; ACompletionTokens: Int64 = 0): Int64; inline;

{ ── 流式盒 · PERFORMANCE.md §7.2 经 nextpas.core.agent.streambox 复用 ── }
type
  TAgentStreamBox = nextpas.core.agent.streambox.TAgentStreamBox;

implementation

function ErrorCodeForStatus(AStatus: Integer): TAgentErrorCode;
begin
  Result := nextpas.core.agent.errors.ErrorCodeForStatus(AStatus);
end;

function IsRetryable(ACode: TAgentErrorCode): Boolean;
begin
  Result := nextpas.core.agent.errors.IsRetryable(ACode);
end;

function AgentErrorCodeName(ACode: TAgentErrorCode): string;
begin
  Result := nextpas.core.agent.errors.AgentErrorCodeName(ACode);
end;

function EncodeOpenAIRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText;
begin
  Result := nextpas.core.agent.provider.openai.EncodeOpenAIRequest(
    AReq, AStream);
end;

procedure DecodeOpenAIResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger);
begin
  nextpas.core.agent.provider.openai.DecodeOpenAIResponse(
    ABody, AMsg, ALog);
end;

function NewOpenAIWireDecoder(const ALog: ILogger): IAgentWireDecoder;
begin
  Result := nextpas.core.agent.provider.openai.NewOpenAIWireDecoder(ALog);
end;

function BuildOpenAIUrl(const ABaseUrl: string): string;
begin
  Result := nextpas.core.agent.provider.openai.BuildOpenAIUrl(ABaseUrl);
end;

function NewOpenAIProvider(const AOpts: TOpenAIOptions): IAgentProvider;
begin
  Result := nextpas.core.agent.provider.openai.NewOpenAIProvider(AOpts);
end;

function NewOpenAIProviderFromEnv: IAgentProvider;
begin
  Result := nextpas.core.agent.provider.openai.NewOpenAIProviderFromEnv;
end;

function BuildGrokUrl(const ABaseUrl: string): string;
begin
  Result := nextpas.core.agent.provider.openai.BuildGrokUrl(ABaseUrl);
end;

function NewGrokProvider(const AOpts: TGrokOptions): IAgentProvider;
begin
  Result := nextpas.core.agent.provider.openai.NewGrokProvider(AOpts);
end;

function NewGrokProviderFromEnv: IAgentProvider;
begin
  Result := nextpas.core.agent.provider.openai.NewGrokProviderFromEnv;
end;

function EncodeAnthropicRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText;
begin
  Result := nextpas.core.agent.provider.anthropic.EncodeAnthropicRequest(
    AReq, AStream);
end;

procedure DecodeAnthropicResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger);
begin
  nextpas.core.agent.provider.anthropic.DecodeAnthropicResponse(
    ABody, AMsg, ALog);
end;

function NewAnthropicWireDecoder(const ALog: ILogger): IAgentWireDecoder;
begin
  Result := nextpas.core.agent.provider.anthropic.NewAnthropicWireDecoder(
    ALog);
end;

function BuildAnthropicUrl(const ABaseUrl: string): string;
begin
  Result := nextpas.core.agent.provider.anthropic.BuildAnthropicUrl(ABaseUrl);
end;

function EncodeAnthropicCountTokensRequest(
  const AReq: TCompletionRequest): TJsonText;
begin
  Result :=
    nextpas.core.agent.provider.anthropic.EncodeAnthropicCountTokensRequest(
      AReq);
end;

function BuildAnthropicCountTokensUrl(const ABaseUrl: string): string;
begin
  Result :=
    nextpas.core.agent.provider.anthropic.BuildAnthropicCountTokensUrl(
      ABaseUrl);
end;

function NewAnthropicProvider(const AOpts: TAnthropicOptions): IAgentProvider;
begin
  Result := nextpas.core.agent.provider.anthropic.NewAnthropicProvider(AOpts);
end;

function NewAnthropicProviderFromEnv: IAgentProvider;
begin
  Result := nextpas.core.agent.provider.anthropic.NewAnthropicProviderFromEnv;
end;

function EncodeResponsesRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText;
begin
  Result :=
    nextpas.core.agent.provider.openai.responses.EncodeResponsesRequest(
      AReq, AStream);
end;

procedure DecodeResponsesResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger);
begin
  nextpas.core.agent.provider.openai.responses.DecodeResponsesResponse(
    ABody, AMsg, ALog);
end;

function NewResponsesWireDecoder(
  const ALog: ILogger): IAgentWireDecoder;
begin
  Result :=
    nextpas.core.agent.provider.openai.responses.NewResponsesWireDecoder(ALog);
end;

function BuildResponsesUrl(const ABaseUrl: string): string;
begin
  Result :=
    nextpas.core.agent.provider.openai.responses.BuildResponsesUrl(ABaseUrl);
end;

procedure ValidateToolSpec(const ASpec: TToolSpec);
begin
  nextpas.core.agent.tools.ValidateToolSpec(ASpec);
end;

function ValidateToolArguments(const ASpec: TToolSpec;
  const AArgsJson: TJsonText): TToolResult;
begin
  Result := nextpas.core.agent.tools.ValidateToolArguments(
    ASpec, AArgsJson);
end;

function EnvelopeTruncation(const AResult: TToolResult;
  AMaxLines, AMaxBytes: Integer): TToolResult;
begin
  Result := nextpas.core.agent.tools.EnvelopeTruncation(
    AResult, AMaxLines, AMaxBytes);
end;

function NewToolContext(const AToken: IAsyncCancellationToken;
  ACallIndex: Integer): IToolContext;
begin
  Result := nextpas.core.agent.tools.NewToolContext(AToken, ACallIndex);
end;

function WithTools(const ATools: array of IAgentTool): TToolSpecArray;
begin
  Result := nextpas.core.agent.tools.WithTools(ATools);
end;

function WithRetry(const AInner: IAgentProvider; const APolicy: TRetryPolicy;
  const AClock: IAgentClock): IAgentProvider;
begin
  Result := nextpas.core.agent.retry.WithRetry(AInner, APolicy, AClock);
end;

function WithRetry(const AInner: IAgentProvider; const APolicy: TRetryPolicy;
  const AClock: IAgentClock;
  const AToken: IAsyncCancellationToken): IAgentProvider;
begin
  Result := nextpas.core.agent.retry.WithRetry(
    AInner, APolicy, AClock, AToken);
end;

function NewSystemClock: IAgentClock;
begin
  Result := nextpas.core.agent.clock.NewSystemClock;
end;

function NewJsonlTranscriptStore(const ARootDir: string;
  ASyncEachAppend: Boolean = True): IAgentTranscriptStore;
begin
  Result := nextpas.core.agent.session.NewJsonlTranscriptStore(
    ARootDir, ASyncEachAppend);
end;

function StreamHasError(const ADeltas: TStreamDeltaArray;
  ACode: TAgentErrorCode): Boolean;
begin
  Result := nextpas.core.agent.resilience.StreamHasError(ADeltas, ACode);
end;

function WaitCancelMs(const AToken: IAsyncCancellationToken;
  ADelayMs: Int64): Boolean;
begin
  Result := nextpas.core.agent.resilience.WaitCancelMs(AToken, ADelayMs);
end;

function WaitCancelMs(const ASource: ICancellationSource;
  ADelayMs: Int64): Boolean;
begin
  Result := nextpas.core.agent.resilience.WaitCancelMs(ASource, ADelayMs);
end;

function WaitCancelSlice(const AToken: IAsyncCancellationToken;
  ASliceMs: Int64): Boolean;
begin
  Result := nextpas.core.agent.resilience.WaitCancelSlice(AToken, ASliceMs);
end;

function ClampHintMs(AHintMs, ACapMs: Int64): Int64;
begin
  Result := nextpas.core.agent.resilience.ClampHintMs(AHintMs, ACapMs);
end;

function NewFallbackProvider(const AChain: array of IAgentProvider;
  const APolicy: TFallbackPolicy): IAgentProvider;
begin
  Result := nextpas.core.agent.fallback.NewFallbackProvider(AChain,
    APolicy);
end;

function NewThrottledProvider(const AInner: IAgentProvider;
  const AGate: IAgentRateGate; const AClock: IAgentClock;
  const APolicy: TThrottlePolicy): IAgentProvider;
begin
  Result := nextpas.core.agent.throttle.NewThrottledProvider(AInner,
    AGate, AClock, APolicy);
end;

function NewTokenBucketGate(ARatePerSecond, ABurst: Double): IAgentRateGate;
begin
  Result := nextpas.core.agent.throttle.NewTokenBucketGate(ARatePerSecond,
    ABurst);
end;

function NewHedgedProvider(const AInner: IAgentProvider;
  const AClock: IAgentClock; const APolicy: THedgePolicy): IAgentProvider;
begin
  Result := nextpas.core.agent.hedge.NewHedgedProvider(AInner, AClock,
    APolicy);
end;

function NewOpenAIResponsesProvider(
  const AOpts: TOpenAIOptions): IAgentProvider;
begin
  Result :=
    nextpas.core.agent.provider.openai.responses.NewOpenAIResponsesProvider(
      AOpts);
end;

function NewOpenAIResponsesProviderFromEnv: IAgentProvider;
begin
  Result :=
    nextpas.core.agent.provider.openai.responses.
    NewOpenAIResponsesProviderFromEnv;
end;

function NewFakeProvider(const AScriptJson: TJsonText): IAgentProvider;
begin
  Result := nextpas.core.agent.provider.fake.NewFakeProvider(AScriptJson);
end;

function NewEchoProvider: IAgentProvider;
begin
  Result := nextpas.core.agent.provider.fake.NewEchoProvider;
end;

function NewTracedTransport(const AName: string;
  const ASink: IAgentTraceSink; const AInner: IAgentTransport;
  const AClock: IAgentClock): IAgentTransport;
begin
  Result := nextpas.core.agent.transport.trace.NewTracedTransport(
    AName, ASink, AInner, AClock);
end;

function PlatformQuotaWindowSeconds(const AKind: TPlatformQuotaWindowKind): Int64;
begin
  Result := nextpas.core.agent.quota.PlatformQuotaWindowSeconds(AKind);
end;

function PlatformQuotaWindowExpired(const AKind: TPlatformQuotaWindowKind;
  const AStart, ANowSec: Int64): Boolean;
begin
  Result := nextpas.core.agent.quota.PlatformQuotaWindowExpired(AKind, AStart, ANowSec);
end;

function PlatformQuotaExpired(const AKind: TPlatformQuotaWindowKind;
  const AStart, ANowSec: Int64): Boolean;
begin
  Result := nextpas.core.agent.quota.PlatformQuotaExpired(AKind, AStart, ANowSec);
end;

function PlatformQuotaUsage(const AKind: TPlatformQuotaWindowKind;
  const AUsage, AStart, ANowSec: Int64): Int64;
begin
  Result := nextpas.core.agent.quota.PlatformQuotaUsage(AKind, AUsage, AStart, ANowSec);
end;

function PlatformQuotaExceeded(const AKind: TPlatformQuotaWindowKind;
  const ALimit, AUsage, AStart, ANowSec, AEstCost: Int64): Boolean;
begin
  Result := nextpas.core.agent.quota.PlatformQuotaExceeded(AKind, ALimit, AUsage, AStart, ANowSec, AEstCost);
end;

function SerializePlatformQuotaItem(const AItem: TPlatformQuotaItem;
  const ANowSec: Int64): string;
begin
  Result := nextpas.core.agent.quota.SerializePlatformQuotaItem(AItem, ANowSec);
end;

function PlatformQuotaSerialize(const AItem: TPlatformQuotaItem;
  const ANowSec: Int64): string;
begin
  Result := nextpas.core.agent.quota.PlatformQuotaSerialize(AItem, ANowSec);
end;

function EstimateCost(const APricing: TModelPricing;
  APromptTokens, ACompletionTokens: Int64; ARateMultiplier: Int64): Int64; overload;
begin
  Result := nextpas.core.agent.pricing.EstimateCost(APricing,
    APromptTokens, ACompletionTokens, ARateMultiplier);
end;

function EstimateCost(const AUsage: TTokenUsage): Int64; overload;
begin
  Result := nextpas.core.agent.pricing.EstimateCost(AUsage);
end;

function EstimateCost(const AUsage: TTokenUsage;
  APromptPer1k, ACompletionPer1k: Int64): Int64; overload;
begin
  Result := nextpas.core.agent.pricing.EstimateCost(AUsage,
    APromptPer1k, ACompletionPer1k);
end;

function EstimateCost(APromptTokens, ACompletionTokens: Int64): Int64; overload;
begin
  Result := nextpas.core.agent.pricing.EstimateCost(APromptTokens,
    ACompletionTokens);
end;

function EstimateCost(APromptTokens, ACompletionTokens: Int64;
  APromptPer1k, ACompletionPer1k: Int64): Int64; overload;
begin
  Result := nextpas.core.agent.pricing.EstimateCost(APromptTokens,
    ACompletionTokens, APromptPer1k, ACompletionPer1k);
end;

function ImageTierOf(const AWidth, AHeight: Int64): Int64;
begin
  Result := nextpas.core.agent.pricing.ImageTierOf(AWidth, AHeight);
end;

function AgentEstimateTokens(const S: string): Int64;
begin
  Result := nextpas.core.agent.pricing.AgentEstimateTokens(S);
end;

function AgentEstimateTokensFromMessage(const AMsg: TMessage): Int64;
begin
  Result := nextpas.core.agent.pricing.AgentEstimateTokensFromMessage(AMsg);
end;

function BuildBoundedSnapshot(const ASystem: string;
  const AMessages: TMessageArray; ABudget: Integer): string;
begin
  Result := nextpas.core.agent.snapshot.BuildBoundedSnapshot(ASystem, AMessages, ABudget);
end;

function BoundedSnapshotTokens(const ASnapshot: string): Int64;
begin
  Result := nextpas.core.agent.snapshot.BoundedSnapshotTokens(ASnapshot);
end;

function BoundedSnapshotCost(const ASnapshot: string; ACompletionTokens: Int64): Int64;
begin
  Result := nextpas.core.agent.snapshot.BoundedSnapshotCost(ASnapshot, ACompletionTokens);
end;

function MessageText(const AMsg: TMessage): string;
begin
  Result := nextpas.core.agent.base.MessageText(AMsg);
end;

function WireHeaderValue(const AHeaders: TWireHeaderArray;
  const AName: string): string;
begin
  Result := nextpas.core.agent.base.WireHeaderValue(AHeaders, AName);
end;

function MergeExtraJson(const ATexts: array of TJsonText): TJsonText;
begin
  Result := nextpas.core.agent.base.MergeExtraJson(ATexts);
end;

function AgentUtf8SafeTruncate(const S: string; AMaxBytes: Integer): string;
begin
  Result := nextpas.core.agent.base.AgentUtf8SafeTruncate(S, AMaxBytes);
end;

procedure AgentInitUsageUnknown(var AUsage: TTokenUsage);
begin
  nextpas.core.agent.base.AgentInitUsageUnknown(AUsage);
end;

function AgentTruncateLines(const S: string; AMaxLines: Integer): string;
begin
  Result := nextpas.core.agent.base.AgentTruncateLines(S, AMaxLines);
end;

function AgentTruncateEnvelope(const S: string; AMaxLines, AMaxBytes: Integer;
  out ATruncated: Boolean): string;
begin
  Result := nextpas.core.agent.base.AgentTruncateEnvelope(S, AMaxLines,
    AMaxBytes, ATruncated);
end;

function AgentJoinWireUrl(const ABaseUrl, ADefault, ASuffix: string): string;
begin
  Result := nextpas.core.agent.base.AgentJoinWireUrl(ABaseUrl, ADefault,
    ASuffix);
end;

function AgentBuildSystemText(const ASystem: string;
  const AMessages: TMessageArray): string;
begin
  Result := nextpas.core.agent.base.AgentBuildSystemText(ASystem, AMessages);
end;

function AgentBuildBatchSignature(const AMsg: TMessage): string;
begin
  Result := nextpas.core.agent.base.AgentBuildBatchSignature(AMsg);
end;

procedure AgentValidateWireHeaders(const AHeaders: TWireHeaderArray);
begin
  nextpas.core.agent.base.AgentValidateWireHeaders(AHeaders);
end;

end.
