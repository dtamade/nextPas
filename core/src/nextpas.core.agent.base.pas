{**
 * nextpas.core.agent.base - agent 模块词表：纯数据与纯枚举，零 IO。
 *
 * 契约权威：core/docs/agent/API.md §1。实现与文档冲突时先改文档。
 * 拆分：常量 → base.constants，类型 → base.types，助手 → base.helpers；
 * 本单元为转发薄壳（inline 转发，调用方 `uses nextpas.core.agent.base` 零改动）。
 * 体积：拆前 1177，拆后 ≤300（P-modularity）。
 *}

unit nextpas.core.agent.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.agent.base.constants,
  nextpas.core.agent.base.types,
  nextpas.core.agent.base.helpers;

{ ---- Constants re-export (SECURITY §3 单一真源) ---- }
const
  CTemperatureUnset   = nextpas.core.agent.base.constants.CTemperatureUnset;
  CTopPUnset          = nextpas.core.agent.base.constants.CTopPUnset;
  CMaxTokensUnset     = nextpas.core.agent.base.constants.CMaxTokensUnset;
  CSeedUnset          = nextpas.core.agent.base.constants.CSeedUnset;
  CTimeoutDefault     = nextpas.core.agent.base.constants.CTimeoutDefault;
  CUsageUnknown       = nextpas.core.agent.base.constants.CUsageUnknown;
  CRetryAfterUnknown  = nextpas.core.agent.base.constants.CRetryAfterUnknown;
  CAgentMaxSlotMap    = nextpas.core.agent.base.constants.CAgentMaxSlotMap;
  CAgentMaxWireHeaderValueBytes = nextpas.core.agent.base.constants.CAgentMaxWireHeaderValueBytes;
  CAgentMaxWireTotalHeaderBytes = nextpas.core.agent.base.constants.CAgentMaxWireTotalHeaderBytes;
  CAgentMaxSuccessBodyBytes = nextpas.core.agent.base.constants.CAgentMaxSuccessBodyBytes;
  CAgentMaxRawBodySnippetBytes = nextpas.core.agent.base.constants.CAgentMaxRawBodySnippetBytes;
  CAgentMaxExtraKeys = nextpas.core.agent.base.constants.CAgentMaxExtraKeys;
  CAgentMaxToolArgsBytes = nextpas.core.agent.base.constants.CAgentMaxToolArgsBytes;
  CAgentToolArgsInitialCap = nextpas.core.agent.base.constants.CAgentToolArgsInitialCap;
  CAgentSystemTextInitialCap = nextpas.core.agent.base.constants.CAgentSystemTextInitialCap;
  CAgentSessionForkInitialCap = nextpas.core.agent.base.constants.CAgentSessionForkInitialCap;

{ ---- Types re-export (types → 单一真源) ---- }
type
  TJsonText = nextpas.core.agent.base.types.TJsonText;
  TMessageRole = nextpas.core.agent.base.types.TMessageRole;
  TPartKind = nextpas.core.agent.base.types.TPartKind;
  TFinishReason = nextpas.core.agent.base.types.TFinishReason;
  TTriState = nextpas.core.agent.base.types.TTriState;
  TToolChoiceMode = nextpas.core.agent.base.types.TToolChoiceMode;
  TReasoningEffort = nextpas.core.agent.base.types.TReasoningEffort;
  TCacheControlMode = nextpas.core.agent.base.types.TCacheControlMode;
  TStreamDeltaKind = nextpas.core.agent.base.types.TStreamDeltaKind;
  TAgentErrorCode = nextpas.core.agent.base.types.TAgentErrorCode;
  TTokenUsage = nextpas.core.agent.base.types.TTokenUsage;
  TPart = nextpas.core.agent.base.types.TPart;
  TPartArray = nextpas.core.agent.base.types.TPartArray;
  TMessage = nextpas.core.agent.base.types.TMessage;
  TMessageArray = nextpas.core.agent.base.types.TMessageArray;
  TAgentErrorInfo = nextpas.core.agent.base.types.TAgentErrorInfo;
  TStreamDelta = nextpas.core.agent.base.types.TStreamDelta;
  TStreamDeltaArray = nextpas.core.agent.base.types.TStreamDeltaArray;
  TToolCapability = nextpas.core.agent.base.types.TToolCapability;
  TToolCapabilities = nextpas.core.agent.base.types.TToolCapabilities;
  TToolSpec = nextpas.core.agent.base.types.TToolSpec;
  TToolSpecArray = nextpas.core.agent.base.types.TToolSpecArray;
  TToolResult = nextpas.core.agent.base.types.TToolResult;
  TWireHeader = nextpas.core.agent.base.types.TWireHeader;
  TWireHeaderArray = nextpas.core.agent.base.types.TWireHeaderArray;
  TWireRequest = nextpas.core.agent.base.types.TWireRequest;
  TWireResponse = nextpas.core.agent.base.types.TWireResponse;
  TTraceRequestInfo = nextpas.core.agent.base.types.TTraceRequestInfo;
  TTraceResponseInfo = nextpas.core.agent.base.types.TTraceResponseInfo;
  TWireSSEEvent = nextpas.core.agent.base.types.TWireSSEEvent;
  TWireSSEEventArray = nextpas.core.agent.base.types.TWireSSEEventArray;
  TCompletionRequest = nextpas.core.agent.base.types.TCompletionRequest;

{ ---- Slot / Builder re-export (helpers → 单一真源) ---- }
type
  TAgentSlotMap = nextpas.core.agent.base.helpers.TAgentSlotMap;
  TAgentSlotRegistry = nextpas.core.agent.base.helpers.TAgentSlotRegistry;
  PStreamDelta = nextpas.core.agent.base.helpers.PStreamDelta;
  TAgentDeltaBuilder = nextpas.core.agent.base.helpers.TAgentDeltaBuilder;

{ ---- Enum literals re-export (preserve `uses base;` literal visibility) ---- }
const
  mrSystem = nextpas.core.agent.base.types.mrSystem;
  mrUser = nextpas.core.agent.base.types.mrUser;
  mrAssistant = nextpas.core.agent.base.types.mrAssistant;
  mrTool = nextpas.core.agent.base.types.mrTool;
  pkText = nextpas.core.agent.base.types.pkText;
  pkThinking = nextpas.core.agent.base.types.pkThinking;
  pkToolCall = nextpas.core.agent.base.types.pkToolCall;
  pkToolResult = nextpas.core.agent.base.types.pkToolResult;
  pkImage = nextpas.core.agent.base.types.pkImage;
  frNone = nextpas.core.agent.base.types.frNone;
  frStop = nextpas.core.agent.base.types.frStop;
  frLength = nextpas.core.agent.base.types.frLength;
  frToolCalls = nextpas.core.agent.base.types.frToolCalls;
  frContentFilter = nextpas.core.agent.base.types.frContentFilter;
  tsUnset = nextpas.core.agent.base.types.tsUnset;
  tsFalse = nextpas.core.agent.base.types.tsFalse;
  tsTrue = nextpas.core.agent.base.types.tsTrue;
  tcmUnset = nextpas.core.agent.base.types.tcmUnset;
  tcmAuto = nextpas.core.agent.base.types.tcmAuto;
  tcmNone = nextpas.core.agent.base.types.tcmNone;
  tcmRequired = nextpas.core.agent.base.types.tcmRequired;
  tcmNamed = nextpas.core.agent.base.types.tcmNamed;
  reUnset = nextpas.core.agent.base.types.reUnset;
  reMinimal = nextpas.core.agent.base.types.reMinimal;
  reLow = nextpas.core.agent.base.types.reLow;
  reMedium = nextpas.core.agent.base.types.reMedium;
  reHigh = nextpas.core.agent.base.types.reHigh;
  reXHigh = nextpas.core.agent.base.types.reXHigh;
  reMax = nextpas.core.agent.base.types.reMax;
  ccmUnset = nextpas.core.agent.base.types.ccmUnset;
  ccmAuto = nextpas.core.agent.base.types.ccmAuto;
  sdkTextDelta = nextpas.core.agent.base.types.sdkTextDelta;
  sdkThinkingDelta = nextpas.core.agent.base.types.sdkThinkingDelta;
  sdkToolCallStart = nextpas.core.agent.base.types.sdkToolCallStart;
  sdkToolCallDelta = nextpas.core.agent.base.types.sdkToolCallDelta;
  sdkToolCallEnd = nextpas.core.agent.base.types.sdkToolCallEnd;
  sdkFinish = nextpas.core.agent.base.types.sdkFinish;
  sdkUsage = nextpas.core.agent.base.types.sdkUsage;
  sdkError = nextpas.core.agent.base.types.sdkError;
  sdkEnvelope = nextpas.core.agent.base.types.sdkEnvelope;
  aecNone = nextpas.core.agent.base.types.aecNone;
  aecInvalidRequest = nextpas.core.agent.base.types.aecInvalidRequest;
  aecAuthentication = nextpas.core.agent.base.types.aecAuthentication;
  aecNotFound = nextpas.core.agent.base.types.aecNotFound;
  aecRateLimited = nextpas.core.agent.base.types.aecRateLimited;
  aecTransport = nextpas.core.agent.base.types.aecTransport;
  aecTimeout = nextpas.core.agent.base.types.aecTimeout;
  aecServer = nextpas.core.agent.base.types.aecServer;
  aecContextOverflow = nextpas.core.agent.base.types.aecContextOverflow;
  aecProtocol = nextpas.core.agent.base.types.aecProtocol;
  aecCancelled = nextpas.core.agent.base.types.aecCancelled;
  aecConfig = nextpas.core.agent.base.types.aecConfig;
  aecToolFailed = nextpas.core.agent.base.types.aecToolFailed;
  aecBudgetExhausted = nextpas.core.agent.base.types.aecBudgetExhausted;
  tcParallel = nextpas.core.agent.base.types.tcParallel;

{ ---- Helpers re-export (inline thin facade) ---- }
function MessageText(const AMsg: TMessage): string; inline;
function WireHeaderValue(const AHeaders: TWireHeaderArray; const AName: string): string; inline;
function MergeExtraJson(const ATexts: array of TJsonText): TJsonText; inline;
function AgentUtf8SafeTruncate(const S: string; AMaxBytes: Integer): string; inline;
function AgentUtf8SafeCutLen(const S: string; AMaxBytes: Integer): Integer; inline;
function AgentIsKnownKey(const AKey: string; const AKnown: array of string): Boolean; inline;
function AgentBuildBatchSignature(const AMsg: TMessage): string; inline;
function AgentTruncateLines(const S: string; AMaxLines: Integer): string; inline;
function AgentTruncateEnvelope(const S: string; AMaxLines, AMaxBytes: Integer; out ATruncated: Boolean): string; inline;
procedure AgentInitUsageUnknown(var AUsage: TTokenUsage); inline;
function AgentJoinWireUrl(const ABaseUrl, ADefault, ASuffix: string): string; inline;
function AgentBuildSystemText(const ASystem: string; const AMessages: TMessageArray): string; inline;
procedure AgentSlotMapEnsureSize(var AMap: TAgentSlotMap; AIdx: Integer); inline;
procedure AgentValidateWireHeaders(const AHeaders: TWireHeaderArray); inline;
function AgentAddPart(var AParts: TPartArray; AKind: TPartKind): Integer; inline;
procedure AgentAppendDelta(var AArr: TStreamDeltaArray; const ADelta: TStreamDelta); inline;
function AgentUnmappedJson(const AKey, AValue: string): TJsonText; inline;

implementation

function MessageText(const AMsg: TMessage): string; inline;
begin
  Result := nextpas.core.agent.base.helpers.MessageText(AMsg);
end;

function WireHeaderValue(const AHeaders: TWireHeaderArray; const AName: string): string; inline;
begin
  Result := nextpas.core.agent.base.helpers.WireHeaderValue(AHeaders, AName);
end;

function MergeExtraJson(const ATexts: array of TJsonText): TJsonText; inline;
begin
  Result := nextpas.core.agent.base.types.MergeExtraJson(ATexts);
end;

function AgentUtf8SafeTruncate(const S: string; AMaxBytes: Integer): string; inline;
begin
  Result := nextpas.core.agent.base.helpers.AgentUtf8SafeTruncate(S, AMaxBytes);
end;

function AgentUtf8SafeCutLen(const S: string; AMaxBytes: Integer): Integer; inline;
begin
  Result := nextpas.core.agent.base.helpers.AgentUtf8SafeCutLen(S, AMaxBytes);
end;

function AgentIsKnownKey(const AKey: string; const AKnown: array of string): Boolean; inline;
begin
  Result := nextpas.core.agent.base.helpers.AgentIsKnownKey(AKey, AKnown);
end;

function AgentBuildBatchSignature(const AMsg: TMessage): string; inline;
begin
  Result := nextpas.core.agent.base.helpers.AgentBuildBatchSignature(AMsg);
end;

function AgentTruncateLines(const S: string; AMaxLines: Integer): string; inline;
begin
  Result := nextpas.core.agent.base.helpers.AgentTruncateLines(S, AMaxLines);
end;

function AgentTruncateEnvelope(const S: string; AMaxLines, AMaxBytes: Integer; out ATruncated: Boolean): string; inline;
begin
  Result := nextpas.core.agent.base.helpers.AgentTruncateEnvelope(S, AMaxLines, AMaxBytes, ATruncated);
end;

procedure AgentInitUsageUnknown(var AUsage: TTokenUsage); inline;
begin
  nextpas.core.agent.base.helpers.AgentInitUsageUnknown(AUsage);
end;

function AgentJoinWireUrl(const ABaseUrl, ADefault, ASuffix: string): string; inline;
begin
  Result := nextpas.core.agent.base.helpers.AgentJoinWireUrl(ABaseUrl, ADefault, ASuffix);
end;

function AgentBuildSystemText(const ASystem: string; const AMessages: TMessageArray): string; inline;
begin
  Result := nextpas.core.agent.base.helpers.AgentBuildSystemText(ASystem, AMessages);
end;

procedure AgentSlotMapEnsureSize(var AMap: TAgentSlotMap; AIdx: Integer); inline;
begin
  nextpas.core.agent.base.helpers.AgentSlotMapEnsureSize(AMap, AIdx);
end;

procedure AgentValidateWireHeaders(const AHeaders: TWireHeaderArray); inline;
begin
  nextpas.core.agent.base.helpers.AgentValidateWireHeaders(AHeaders);
end;

function AgentAddPart(var AParts: TPartArray; AKind: TPartKind): Integer; inline;
begin
  Result := nextpas.core.agent.base.helpers.AgentAddPart(AParts, AKind);
end;

procedure AgentAppendDelta(var AArr: TStreamDeltaArray; const ADelta: TStreamDelta); inline;
begin
  nextpas.core.agent.base.helpers.AgentAppendDelta(AArr, ADelta);
end;

function AgentUnmappedJson(const AKey, AValue: string): TJsonText; inline;
begin
  Result := nextpas.core.agent.base.helpers.AgentUnmappedJson(AKey, AValue);
end;

end.
