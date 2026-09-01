{**
 * nextpas.core.agent.provider.common - 两厂商适配器共享 helper（转发薄壳）。
 *
 * 契约权威：core/docs/agent/WIRE-MAPPINGS §0、ERRORS.md §3/§6、SECURITY.md §3。
 * 体积与拆分（P-modularity，F-M07/F-M10）：
 *  - 现状 ≤350 行（原 1188 行，已拆 wire / extra / slots 三子域；已 <800 阈值，模块化达标）；
 *    后续新增代码优先落子域。
 *  - 拆分落地（调用方零改动，已落地 3/3）：
 *      ✓ nextpas.core.agent.provider.common.wire   （wire 头部/校验/装配/上游分类）
 *      ✓ nextpas.core.agent.provider.common.extra  （Extra 捕获/回注）
 *      ✓ nextpas.core.agent.provider.common.slots  （槽池/流式完成/装饰器基建）
 *    本单元为转发薄壳（inline 转发，调用方 `uses ...provider.common` 零改动）。
 *  - 约束：子域互不循环，仅向下依赖 base/errors/intf/json 等。
 *}

unit nextpas.core.agent.provider.common;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.json.value,
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.async.cancellation,
  nextpas.core.text.conv,
  nextpas.core.json,
  nextpas.core.json.builder,
  nextpas.core.text.builder,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.provider.common.wire,
  nextpas.core.agent.provider.common.extra,
  nextpas.core.agent.provider.common.slots;

type
  TProviderOptions = nextpas.core.agent.provider.common.wire.TProviderOptions;
  TWireToolSlot = nextpas.core.agent.provider.common.slots.TWireToolSlot;
  TWireToolSlotPool = nextpas.core.agent.provider.common.slots.TWireToolSlotPool;
  TWireBackedCompletion = nextpas.core.agent.provider.common.slots.TWireBackedCompletion;
  TProviderFailure = nextpas.core.agent.provider.common.slots.TProviderFailure;
  TFirstGateCompletion = nextpas.core.agent.provider.common.slots.TFirstGateCompletion;

const
  CMaxRawBodySnippetBytes = nextpas.core.agent.base.CAgentMaxRawBodySnippetBytes;
  CMaxExtraKeys = nextpas.core.agent.base.CAgentMaxExtraKeys;
  CAgentMaxWireHeaderValueBytes = nextpas.core.agent.base.CAgentMaxWireHeaderValueBytes;
  CAgentMaxWireTotalHeaderBytes = nextpas.core.agent.base.CAgentMaxWireTotalHeaderBytes;

{ 词表增量追加 }
procedure AddStreamDelta(var AArr: TStreamDeltaArray; const AD: TStreamDelta); inline;

function Utf8SafeTruncate(const S: string; AMaxBytes: Integer): string; inline;
function MatchesOverflowPhrases(const AMsg: string): Boolean; inline;
function ParseRetryAfterMs(const AHeaders: TWireHeaderArray): Int64; inline;
function ProbeRequestId(const AHeaders: TWireHeaderArray): string; inline;
function ExtractErrorMessage(const ABody: string): string; inline;
function BuildUpstreamError(const AProvider, ABody: string; AStatus: Integer; const AHeaders: TWireHeaderArray): EAgentError; inline;

function CaptureExtraJson(const AValue: TJsonValue; const AKnownKeys: array of string; ALimit: Integer; const ALog: ILogger): TJsonText; inline;
procedure WriteExtraFields(const ABld: IJsonBuilder; const AExtraJson: TJsonText; const AKnownNames: array of string); inline;

function MergeCancellationTokens(const AAmbient, ACall: IAsyncCancellationToken): IAsyncCancellationToken; inline;
procedure RequireNotCancelled(const AToken: IAsyncCancellationToken); inline;

procedure AgentWarnLog(const ALog: ILogger; const AMsg: string); inline;
procedure AgentDebugLog(const ALog: ILogger; const AMsg: string); inline;
procedure AgentProtocolError(const AProvider, ABodySrc, AMsg: string); inline;

procedure AgentWireApplyTimeouts(var AWire: TWireRequest; const ACommon: TProviderOptions); inline;
procedure AgentWireAppendExtraHeaders(var AHeaders: TWireHeaderArray; const AExtra: TWireHeaderArray); inline;
procedure AgentWireAddOpenAIHeaders(var AWire: TWireRequest; const ACommon: TProviderOptions; const AOrganization: string); inline;
procedure AgentWireAddAnthropicHeaders(var AWire: TWireRequest; const ACommon: TProviderOptions; const AVersion: string); inline;
procedure AgentWireApplyIdempotency(var AWire: TWireRequest; const AReq: TCompletionRequest); inline;
procedure AgentRequireApiKey(const AKey, AEnvName: string); inline;

procedure AgentValidateModelNotEmpty(const AModel, APrefix: string); inline;
procedure AgentValidateToolChoice(const AReq: TCompletionRequest; const APrefix: string); inline;
procedure AgentValidateResponseSchemaIsObject(const ASchema: TJsonText; const APrefix: string); inline;
procedure AgentRejectResponseSchema(const ASchema: TJsonText; const APrefix: string); inline;
procedure AgentValidateThinking(const AReq: TCompletionRequest; const APrefix: string); inline;
procedure AgentValidateExtraJson(const AExtra: TJsonText; const APrefix: string); inline;
procedure AgentValidateWireHeaders(const AHeaders: TWireHeaderArray); inline;

procedure AgentWriteStrictJsonSchemaInner(ABld: IJsonBuilder; const ASchema: TJsonText); inline;
procedure AgentWriteToolIdentity(ABld: IJsonBuilder; const ASpec: TToolSpec); inline;
procedure AgentWriteToolCommonFields(ABld: IJsonBuilder; const ASpec: TToolSpec); inline;
procedure AgentWriteTemperature(ABld: IJsonBuilder; ATemp: Double); inline;
procedure AgentWriteTopP(ABld: IJsonBuilder; ATopP: Double); inline;
procedure AgentWriteSeed(ABld: IJsonBuilder; ASeed: Int64); inline;
procedure AgentWriteStopSequences(ABld: IJsonBuilder; const ASeq: TStringArray; const AKey: string); inline;
procedure AgentWriteParallelToolCalls(ABld: IJsonBuilder; AVal: TTriState); inline;
function AgentReasoningEffortToStr(AEffort: TReasoningEffort): string; inline;
function AgentToolChoiceSimpleStr(AMode: TToolChoiceMode): string; inline;
procedure AgentWriteThinking(ABld: IJsonBuilder; AThinking: TTriState; ABudget: Int64); inline;

implementation

procedure AddStreamDelta(var AArr: TStreamDeltaArray; const AD: TStreamDelta); inline;
begin
  nextpas.core.agent.provider.common.slots.AddStreamDelta(AArr, AD);
end;

function Utf8SafeTruncate(const S: string; AMaxBytes: Integer): string; inline;
begin
  Result := nextpas.core.agent.provider.common.wire.Utf8SafeTruncate(S, AMaxBytes);
end;

function MatchesOverflowPhrases(const AMsg: string): Boolean; inline;
begin
  Result := nextpas.core.agent.provider.common.wire.MatchesOverflowPhrases(AMsg);
end;

function ParseRetryAfterMs(const AHeaders: TWireHeaderArray): Int64; inline;
begin
  Result := nextpas.core.agent.provider.common.wire.ParseRetryAfterMs(AHeaders);
end;

function ProbeRequestId(const AHeaders: TWireHeaderArray): string; inline;
begin
  Result := nextpas.core.agent.provider.common.wire.ProbeRequestId(AHeaders);
end;

function ExtractErrorMessage(const ABody: string): string; inline;
begin
  Result := nextpas.core.agent.provider.common.wire.ExtractErrorMessage(ABody);
end;

function BuildUpstreamError(const AProvider, ABody: string; AStatus: Integer; const AHeaders: TWireHeaderArray): EAgentError; inline;
begin
  Result := nextpas.core.agent.provider.common.wire.BuildUpstreamError(AProvider, ABody, AStatus, AHeaders);
end;

function CaptureExtraJson(const AValue: TJsonValue; const AKnownKeys: array of string; ALimit: Integer; const ALog: ILogger): TJsonText; inline;
begin
  Result := nextpas.core.agent.provider.common.extra.CaptureExtraJson(AValue, AKnownKeys, ALimit, ALog);
end;

procedure WriteExtraFields(const ABld: IJsonBuilder; const AExtraJson: TJsonText; const AKnownNames: array of string); inline;
begin
  nextpas.core.agent.provider.common.extra.WriteExtraFields(ABld, AExtraJson, AKnownNames);
end;

function MergeCancellationTokens(const AAmbient, ACall: IAsyncCancellationToken): IAsyncCancellationToken; inline;
begin
  Result := nextpas.core.agent.provider.common.slots.MergeCancellationTokens(AAmbient, ACall);
end;

procedure RequireNotCancelled(const AToken: IAsyncCancellationToken); inline;
begin
  nextpas.core.agent.provider.common.slots.RequireNotCancelled(AToken);
end;

procedure AgentWarnLog(const ALog: ILogger; const AMsg: string); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentWarnLog(ALog, AMsg);
end;

procedure AgentDebugLog(const ALog: ILogger; const AMsg: string); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentDebugLog(ALog, AMsg);
end;

procedure AgentProtocolError(const AProvider, ABodySrc, AMsg: string); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentProtocolError(AProvider, ABodySrc, AMsg);
end;

procedure AgentWireApplyTimeouts(var AWire: TWireRequest; const ACommon: TProviderOptions); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentWireApplyTimeouts(AWire, ACommon);
end;

procedure AgentWireAppendExtraHeaders(var AHeaders: TWireHeaderArray; const AExtra: TWireHeaderArray); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentWireAppendExtraHeaders(AHeaders, AExtra);
end;

procedure AgentWireAddOpenAIHeaders(var AWire: TWireRequest; const ACommon: TProviderOptions; const AOrganization: string); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentWireAddOpenAIHeaders(AWire, ACommon, AOrganization);
end;

procedure AgentWireAddAnthropicHeaders(var AWire: TWireRequest; const ACommon: TProviderOptions; const AVersion: string); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentWireAddAnthropicHeaders(AWire, ACommon, AVersion);
end;

procedure AgentWireApplyIdempotency(var AWire: TWireRequest; const AReq: TCompletionRequest); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentWireApplyIdempotency(AWire, AReq);
end;

procedure AgentRequireApiKey(const AKey, AEnvName: string); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentRequireApiKey(AKey, AEnvName);
end;

procedure AgentValidateModelNotEmpty(const AModel, APrefix: string); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentValidateModelNotEmpty(AModel, APrefix);
end;

procedure AgentValidateToolChoice(const AReq: TCompletionRequest; const APrefix: string); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentValidateToolChoice(AReq, APrefix);
end;

procedure AgentValidateResponseSchemaIsObject(const ASchema: TJsonText; const APrefix: string); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentValidateResponseSchemaIsObject(ASchema, APrefix);
end;

procedure AgentRejectResponseSchema(const ASchema: TJsonText; const APrefix: string); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentRejectResponseSchema(ASchema, APrefix);
end;

procedure AgentValidateThinking(const AReq: TCompletionRequest; const APrefix: string); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentValidateThinking(AReq, APrefix);
end;

procedure AgentValidateExtraJson(const AExtra: TJsonText; const APrefix: string); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentValidateExtraJson(AExtra, APrefix);
end;

procedure AgentValidateWireHeaders(const AHeaders: TWireHeaderArray); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentValidateWireHeaders(AHeaders);
end;

procedure AgentWriteStrictJsonSchemaInner(ABld: IJsonBuilder; const ASchema: TJsonText); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentWriteStrictJsonSchemaInner(ABld, ASchema);
end;

procedure AgentWriteToolIdentity(ABld: IJsonBuilder; const ASpec: TToolSpec); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentWriteToolIdentity(ABld, ASpec);
end;

procedure AgentWriteToolCommonFields(ABld: IJsonBuilder; const ASpec: TToolSpec); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentWriteToolCommonFields(ABld, ASpec);
end;

procedure AgentWriteTemperature(ABld: IJsonBuilder; ATemp: Double); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentWriteTemperature(ABld, ATemp);
end;

procedure AgentWriteTopP(ABld: IJsonBuilder; ATopP: Double); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentWriteTopP(ABld, ATopP);
end;

procedure AgentWriteSeed(ABld: IJsonBuilder; ASeed: Int64); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentWriteSeed(ABld, ASeed);
end;

procedure AgentWriteStopSequences(ABld: IJsonBuilder; const ASeq: TStringArray; const AKey: string); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentWriteStopSequences(ABld, ASeq, AKey);
end;

procedure AgentWriteParallelToolCalls(ABld: IJsonBuilder; AVal: TTriState); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentWriteParallelToolCalls(ABld, AVal);
end;

function AgentReasoningEffortToStr(AEffort: TReasoningEffort): string; inline;
begin
  Result := nextpas.core.agent.provider.common.wire.AgentReasoningEffortToStr(AEffort);
end;

function AgentToolChoiceSimpleStr(AMode: TToolChoiceMode): string; inline;
begin
  Result := nextpas.core.agent.provider.common.wire.AgentToolChoiceSimpleStr(AMode);
end;

procedure AgentWriteThinking(ABld: IJsonBuilder; AThinking: TTriState; ABudget: Int64); inline;
begin
  nextpas.core.agent.provider.common.wire.AgentWriteThinking(ABld, AThinking, ABudget);
end;

end.
