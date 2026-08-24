{**
 * nextpas.core.agent - AI provider 客户端与通用工具循环门面。
 *
 * 契约权威：core/docs/agent/API.md。实现与文档冲突时先改文档。
 * 词表经 base/errors 直接可用；provider 构造入口随 W1/W2 落位。
 *}

unit nextpas.core.agent;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.async.cancellation,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.clock,
  nextpas.core.agent.retry,
  nextpas.core.agent.provider.common,
  nextpas.core.agent.provider.openai,
  nextpas.core.agent.provider.anthropic,
  nextpas.core.agent.tools,
  nextpas.core.agent.loop,
  nextpas.core.agent.session;

function ErrorCodeForStatus(AStatus: Integer): TAgentErrorCode; inline;
function IsRetryable(ACode: TAgentErrorCode): Boolean; inline;
function AgentErrorCodeName(ACode: TAgentErrorCode): string; inline;

{ ---- 重试装饰器与时钟（API.md §3/§5）---- }

function WithRetry(const AInner: IAgentProvider; const APolicy: TRetryPolicy;
  const AClock: IAgentClock): IAgentProvider; overload; inline;
function WithRetry(const AInner: IAgentProvider; const APolicy: TRetryPolicy;
  const AClock: IAgentClock;
  const AToken: IAsyncCancellationToken): IAgentProvider; overload; inline;
function NewSystemClock: IAgentClock; inline;

{ ---- OpenAI Chat Completions 适配器（API.md §7/§8）---- }

function EncodeOpenAIRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText; inline;
procedure DecodeOpenAIResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger = nil); inline;
function NewOpenAIWireDecoder(
  const ALog: ILogger = nil): IAgentWireDecoder; inline;
function BuildOpenAIUrl(const ABaseUrl: string): string; inline;
function NewOpenAIProvider(const AOpts: TOpenAIOptions): IAgentProvider; inline;
function NewOpenAIProviderFromEnv: IAgentProvider; inline;

{ ---- Grok（xAI）家族：同族 wire，复用 OpenAI 编解码器 ---- }

function BuildGrokUrl(const ABaseUrl: string): string; inline;
function NewGrokProvider(const AOpts: TGrokOptions): IAgentProvider; inline;
function NewGrokProviderFromEnv: IAgentProvider; inline;

{ ---- Anthropic Messages 适配器（API.md §7/§8）---- }

function EncodeAnthropicRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText; inline;
procedure DecodeAnthropicResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger = nil); inline;
function NewAnthropicWireDecoder(
  const ALog: ILogger = nil): IAgentWireDecoder; inline;
function BuildAnthropicUrl(const ABaseUrl: string): string; inline;
function NewAnthropicProvider(
  const AOpts: TAnthropicOptions): IAgentProvider; inline;
function NewAnthropicProviderFromEnv: IAgentProvider; inline;

{ ---- 工具设施（API.md §1.5；TAgentLoop 经 uses 直接可用）---- }

procedure ValidateToolSpec(const ASpec: TToolSpec); inline;
function ValidateToolArguments(const ASpec: TToolSpec;
  const AArgsJson: TJsonText): TToolResult; inline;
function EnvelopeTruncation(const AResult: TToolResult;
  AMaxLines, AMaxBytes: Integer): TToolResult; inline;
function NewToolContext(const AToken: IAsyncCancellationToken;
  ACallIndex: Integer): IToolContext; inline;

{ ---- 会话存储（API.md §3；W5，设计权威 SESSION.md）---- }

type
  TJsonlTranscriptStore = nextpas.core.agent.session.TJsonlTranscriptStore;
  ETranscriptCorrupt = nextpas.core.agent.session.ETranscriptCorrupt;

function NewJsonlTranscriptStore(const ARootDir: string;
  ASyncEachAppend: Boolean = True): IAgentTranscriptStore; inline;

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

function NewAnthropicProvider(const AOpts: TAnthropicOptions): IAgentProvider;
begin
  Result := nextpas.core.agent.provider.anthropic.NewAnthropicProvider(AOpts);
end;

function NewAnthropicProviderFromEnv: IAgentProvider;
begin
  Result := nextpas.core.agent.provider.anthropic.NewAnthropicProviderFromEnv;
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

end.
