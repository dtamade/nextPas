{**
 * nextpas.core.agent.provider.common.wire - wire 头部/超时/校验/上游分类公共原语。
 *
 * 职责：AgentWire* 头部装配、超时透传、校验卫句、采样参数装配、枚举映射、
 *   上游错误分类（BuildUpstreamError 系）、UTF-8 安全截断等纯 wire 侧 helper。
 *   零装饰器语义，仅 provider 适配器（openai/anthropic/responses）依赖。
 *   与 extra/slots 互不循环，仅向下依赖 base/errors/intf/json。
 *
 * 契约权威：core/docs/agent/WIRE-MAPPINGS §0、ERRORS.md §3/§6、SECURITY.md §3。
 * 属 provider.common 三象限拆分之一（wire），与 extra/slots/facade 互不循环。
 *}

unit nextpas.core.agent.provider.common.wire;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.async.cancellation,
  nextpas.core.json.builder,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf;

type
  { provider 选项公共段（API.md §3.1）：两厂商选项 record 内嵌。
    Transport 注入点供测试/装饰器替换；nil → 生产 http transport }
  TProviderOptions = record
    ApiKey: string;
    BaseUrl: string;
    Model: string;
    ConnectTimeoutMs: Int64;
    TotalTimeoutMs: Int64;
    ReadIdleTimeoutMs: Int64;
    Transport: IAgentTransport;
    Logger: ILogger;
    ExtraHeaders: TWireHeaderArray;
  end;

{ UTF-8 安全截断：最多回退 3 字节到序列边界，绝不产出半字符 }
function Utf8SafeTruncate(const S: string; AMaxBytes: Integer): string; inline;

{ 超窗措辞识别（不区分大小写；WIRE-MAPPINGS §0 全集）}
function MatchesOverflowPhrases(const AMsg: string): Boolean;

{ retry-after-ms 头优先，其次秒级 retry-after；负值与 HTTP-date 形态
  一律不信任 → CRetryAfterUnknown }
function ParseRetryAfterMs(const AHeaders: TWireHeaderArray): Int64;

{ x-request-id / request-id / anthropic-request-id 依次探测，未命中空串 }
function ProbeRequestId(const AHeaders: TWireHeaderArray): string;

{ 上游错误体提取 error.message（两厂商信封同形；无则空串）}
function ExtractErrorMessage(const ABody: string): string;

{ 上游非 2xx 错误信封分类（ERRORS.md §3 算法）}
function BuildUpstreamError(const AProvider, ABody: string;
  AStatus: Integer; const AHeaders: TWireHeaderArray): EAgentError;

{ 共享日志辅助：nil 安全 }
procedure AgentWarnLog(const ALog: ILogger; const AMsg: string); inline;
procedure AgentDebugLog(const ALog: ILogger; const AMsg: string); inline;

{ 协议错误统一构造：前缀 AProvider + 截断体摘要，随即 raise aecProtocol }
procedure AgentProtocolError(const AProvider, ABodySrc, AMsg: string);

{ wire 头部与超时公共原语（openai/anthropic/responses 三路共享）}
procedure AgentWireApplyTimeouts(var AWire: TWireRequest;
  const ACommon: TProviderOptions); inline;
procedure AgentWireAppendExtraHeaders(var AHeaders: TWireHeaderArray;
  const AExtra: TWireHeaderArray);
procedure AgentWireAddOpenAIHeaders(var AWire: TWireRequest;
  const ACommon: TProviderOptions; const AOrganization: string);
procedure AgentWireAddAnthropicHeaders(var AWire: TWireRequest;
  const ACommon: TProviderOptions; const AVersion: string);
procedure AgentWireApplyIdempotency(var AWire: TWireRequest;
  const AReq: TCompletionRequest);
procedure AgentRequireApiKey(const AKey, AEnvName: string); inline;

{ 编码校验公共原语（三路共享，错误文案单点）}
procedure AgentValidateModelNotEmpty(const AModel, APrefix: string); inline;
procedure AgentValidateToolChoice(const AReq: TCompletionRequest;
  const APrefix: string); inline;
procedure AgentValidateResponseSchemaIsObject(const ASchema: TJsonText;
  const APrefix: string);
procedure AgentRejectResponseSchema(const ASchema: TJsonText;
  const APrefix: string);
procedure AgentValidateThinking(const AReq: TCompletionRequest;
  const APrefix: string); inline;
procedure AgentValidateExtraJson(const AExtra: TJsonText;
  const APrefix: string);

{ 编码装配公共原语（openai/responses 复用，wire 差异仅外层键）}
procedure AgentWriteStrictJsonSchemaInner(ABld: IJsonBuilder;
  const ASchema: TJsonText);
procedure AgentWriteToolIdentity(ABld: IJsonBuilder;
  const ASpec: TToolSpec); inline;
procedure AgentWriteToolCommonFields(ABld: IJsonBuilder;
  const ASpec: TToolSpec);

{ 采样参数哨兵装配（Temperature/TopP/Seed/Stop/Parallel 单点）}
procedure AgentWriteTemperature(ABld: IJsonBuilder; ATemp: Double); inline;
procedure AgentWriteTopP(ABld: IJsonBuilder; ATopP: Double); inline;
procedure AgentWriteSeed(ABld: IJsonBuilder; ASeed: Int64); inline;
procedure AgentWriteStopSequences(ABld: IJsonBuilder;
  const ASeq: nextpas.core.base.TStringArray; const AKey: string);
procedure AgentWriteParallelToolCalls(ABld: IJsonBuilder;
  AVal: TTriState); inline;

{ 枚举到 wire 文案映射（ReasoningEffort/ToolChoice 单点）}
function AgentReasoningEffortToStr(
  AEffort: TReasoningEffort): string; inline;
function AgentToolChoiceSimpleStr(AMode: TToolChoiceMode): string; inline;

{ Thinking 装配（anthropic §2.1：type enabled/disabled + budget_tokens）}
procedure AgentWriteThinking(ABld: IJsonBuilder;
  AThinking: TTriState; ABudget: Int64); inline;

{ wire 头部注入卫句（SECURITY §3：空名/CR-LF/单头 8KiB/总头 64KiB）}
procedure AgentValidateWireHeaders(const AHeaders: TWireHeaderArray); inline;

implementation

uses
  SysUtils,
  nextpas.core.json,
  nextpas.core.text.conv;

function Utf8SafeTruncate(const S: string; AMaxBytes: Integer): string; inline;
begin
  Result := AgentUtf8SafeTruncate(S, AMaxBytes);
end;

function MatchesOverflowPhrases(const AMsg: string): Boolean;
const
  PHRASES: array[0..5] of string = (
    'context length',
    'maximum context',
    'token limit',
    'too many tokens',
    'context_length_exceeded',
    'prompt is too long'
  );
var
  LLower: string;
  I, P, LStart, LLen: Integer;
  function IsWordChar(AC: Char): Boolean; inline;
  begin
    Result := AC in ['a'..'z', '0'..'9', '_'];
  end;
begin
  LLower := LowerCase(AMsg);
  Result := False;
  for I := Low(PHRASES) to High(PHRASES) do
  begin
    LLen := Length(PHRASES[I]);
    P := Pos(PHRASES[I], LLower);
    while P > 0 do
    begin
      LStart := P;
      if ((LStart = 1) or (not IsWordChar(LLower[LStart - 1]))) and
         ((LStart + LLen - 1 = Length(LLower)) or (not IsWordChar(LLower[LStart + LLen]))) then
        Exit(True);
      if LStart + 1 > Length(LLower) then
        Break;
      P := Pos(PHRASES[I], Copy(LLower, LStart + 1, MaxInt));
      if P > 0 then
        P := P + LStart;
    end;
  end;
end;

function ParsePlainInt64(const S: string; out AValue: Int64): Boolean;
var
  LCode: Integer;
begin
  Val(S, AValue, LCode);
  Result := (LCode = 0) and (Length(S) > 0);
end;

function ParseRetryAfterMs(const AHeaders: TWireHeaderArray): Int64;
var
  LRaw: string;
  LSecs: Int64;
begin
  LRaw := WireHeaderValue(AHeaders, 'retry-after-ms');
  if ParsePlainInt64(Trim(LRaw), Result) and (Result >= 0) then
    Exit;
  LRaw := Trim(WireHeaderValue(AHeaders, 'retry-after'));
  if ParsePlainInt64(LRaw, LSecs) and (LSecs >= 0) then
  begin
    if LSecs > High(Int64) div 1000 then
      Exit(CRetryAfterUnknown);
    Exit(LSecs * 1000);
  end;
  Result := CRetryAfterUnknown;
end;

function ProbeRequestId(const AHeaders: TWireHeaderArray): string;
begin
  Result := WireHeaderValue(AHeaders, 'x-request-id');
  if Result <> '' then
    Exit;
  Result := WireHeaderValue(AHeaders, 'request-id');
  if Result <> '' then
    Exit;
  Result := WireHeaderValue(AHeaders, 'anthropic-request-id');
end;

function ExtractErrorMessage(const ABody: string): string;
var
  Doc: IJsonDocument;
  LErr, LMsg: TJsonValue;
begin
  Result := '';
  if ABody = '' then
    Exit;
  Doc := JsonParse(ABody);
  if Doc.HasError then
    Exit;
  LErr := Doc.Root.Get('error');
  if LErr.IsObject then
  begin
    LMsg := LErr.Get('message');
    if LMsg.IsStr then
      Exit(LMsg.AsStr.ToString);
    Exit('');
  end;
  if LErr.IsStr then
    Exit(LErr.AsStr.ToString);
end;

function BuildUpstreamError(const AProvider, ABody: string;
  AStatus: Integer; const AHeaders: TWireHeaderArray): EAgentError;
var
  LSnippet, LMsg, LRequestId: string;
  LCode: TAgentErrorCode;
  LRetryAfterMs: Int64;
begin
  LSnippet := Utf8SafeTruncate(ABody, CAgentMaxRawBodySnippetBytes);
  LMsg := ExtractErrorMessage(ABody);
  if LMsg = '' then
    LMsg := 'upstream status ' + IntToStr(AStatus);
  LCode := ErrorCodeForStatus(AStatus);
  if (LCode = aecInvalidRequest) and MatchesOverflowPhrases(LMsg) then
    LCode := aecContextOverflow;
  if AStatus = 429 then
    LRetryAfterMs := ParseRetryAfterMs(AHeaders)
  else
    LRetryAfterMs := CRetryAfterUnknown;
  LRequestId := ProbeRequestId(AHeaders);
  Result := EAgentError.CreateUpstream(LCode, AProvider, LMsg,
    LRequestId, LSnippet, LRetryAfterMs);
end;

procedure AgentWarnLog(const ALog: ILogger; const AMsg: string);
begin
  if ALog <> nil then
    ALog.Warn(AMsg);
end;

procedure AgentDebugLog(const ALog: ILogger; const AMsg: string);
begin
  if ALog <> nil then
    ALog.Debug(AMsg);
end;

procedure AgentProtocolError(const AProvider, ABodySrc, AMsg: string);
var
  E: EAgentError;
begin
  E := EAgentError.CreateLocal(aecProtocol, AProvider + ': ' + AMsg);
  E.RawBodySnippet := AgentUtf8SafeTruncate(ABodySrc, CAgentMaxRawBodySnippetBytes);
  raise E;
end;

procedure AgentWireApplyTimeouts(var AWire: TWireRequest;
  const ACommon: TProviderOptions);
begin
  AWire.ConnectTimeoutMs := ACommon.ConnectTimeoutMs;
  AWire.TotalTimeoutMs := ACommon.TotalTimeoutMs;
  AWire.ReadIdleTimeoutMs := ACommon.ReadIdleTimeoutMs;
end;

procedure AgentWireAppendExtraHeaders(var AHeaders: TWireHeaderArray;
  const AExtra: TWireHeaderArray);
var
  LOld, I: Integer;
begin
  if Length(AExtra) = 0 then
    Exit;
  LOld := Length(AHeaders);
  SetLength(AHeaders, LOld + Length(AExtra));
  for I := 0 to High(AExtra) do
    AHeaders[LOld + I] := AExtra[I];
  AgentValidateWireHeaders(AHeaders);
end;

procedure AgentWireAddOpenAIHeaders(var AWire: TWireRequest;
  const ACommon: TProviderOptions; const AOrganization: string);
var
  LExtra, I, LOff: Integer;
  LHasOrg: Boolean;
begin
  AgentWireApplyTimeouts(AWire, ACommon);
  LHasOrg := AOrganization <> '';
  LExtra := Length(ACommon.ExtraHeaders);
  SetLength(AWire.Headers, 1 + Ord(LHasOrg) + LExtra);
  AWire.Headers[0].Name := 'Authorization';
  AWire.Headers[0].Value := 'Bearer ' + ACommon.ApiKey;
  if LHasOrg then
  begin
    AWire.Headers[1].Name := 'OpenAI-Organization';
    AWire.Headers[1].Value := AOrganization;
  end;
  LOff := 1 + Ord(LHasOrg);
  for I := 0 to LExtra - 1 do
    AWire.Headers[LOff + I] := ACommon.ExtraHeaders[I];
  AgentValidateWireHeaders(AWire.Headers);
end;

procedure AgentWireAddAnthropicHeaders(var AWire: TWireRequest;
  const ACommon: TProviderOptions; const AVersion: string);
var
  LExtra, I: Integer;
begin
  AgentWireApplyTimeouts(AWire, ACommon);
  LExtra := Length(ACommon.ExtraHeaders);
  SetLength(AWire.Headers, 2 + LExtra);
  AWire.Headers[0].Name := 'x-api-key';
  AWire.Headers[0].Value := ACommon.ApiKey;
  AWire.Headers[1].Name := 'anthropic-version';
  AWire.Headers[1].Value := AVersion;
  for I := 0 to LExtra - 1 do
    AWire.Headers[2 + I] := ACommon.ExtraHeaders[I];
  AgentValidateWireHeaders(AWire.Headers);
end;

procedure AgentWireApplyIdempotency(var AWire: TWireRequest;
  const AReq: TCompletionRequest);
var
  LOld: Integer;
begin
  if AReq.IdempotencyKey = '' then
    Exit;
  LOld := Length(AWire.Headers);
  SetLength(AWire.Headers, LOld + 1);
  AWire.Headers[LOld].Name := 'Idempotency-Key';
  AWire.Headers[LOld].Value := AReq.IdempotencyKey;
  AgentValidateWireHeaders(AWire.Headers);
end;

procedure AgentRequireApiKey(const AKey, AEnvName: string);
begin
  if AKey = '' then
    raise EAgentError.CreateLocal(aecConfig,
      'api key is required — set ' + AEnvName + ' or TProviderOptions.ApiKey (auth, not retryable)');
end;

procedure AgentValidateModelNotEmpty(const AModel, APrefix: string);
begin
  if AModel = '' then
    raise EAgentError.CreateLocal(aecConfig, APrefix + ': model is required');
end;

procedure AgentValidateToolChoice(const AReq: TCompletionRequest;
  const APrefix: string);
begin
  if (AReq.ToolChoice <> tcmUnset) and (Length(AReq.Tools) = 0) then
    raise EAgentError.CreateLocal(aecConfig,
      APrefix + ': ToolChoice requires a non-empty Tools array');
  if (AReq.ToolChoice = tcmNamed) and (AReq.ToolChoiceName = '') then
    raise EAgentError.CreateLocal(aecConfig,
      APrefix + ': ToolChoice=tcmNamed requires ToolChoiceName');
end;

procedure AgentValidateResponseSchemaIsObject(const ASchema: TJsonText;
  const APrefix: string);
var
  Doc: IJsonDocument;
begin
  if ASchema = '' then
    Exit;
  Doc := JsonParse(ASchema);
  if (Doc = nil) or Doc.HasError or (not Doc.Root.IsObject) then
    raise EAgentError.CreateLocal(aecConfig,
      APrefix + ': ResponseSchemaJson must be a JSON object');
end;

procedure AgentRejectResponseSchema(const ASchema: TJsonText;
  const APrefix: string);
begin
  if ASchema <> '' then
    raise EAgentError.CreateLocal(aecConfig,
      APrefix + ': ResponseSchemaJson has no vendor wire parameter; ' +
      'use an OpenAI-family adapter for structured output');
end;

procedure AgentValidateThinking(const AReq: TCompletionRequest;
  const APrefix: string);
begin
  if (AReq.Thinking = tsTrue) and
    (AReq.ThinkingBudgetTokens <= CMaxTokensUnset) then
    raise EAgentError.CreateLocal(aecConfig,
      APrefix + ': thinking=true requires ThinkingBudgetTokens');
end;

procedure AgentValidateExtraJson(const AExtra: TJsonText; const APrefix: string);
var
  Doc: IJsonDocument;
begin
  if AExtra = '' then
    Exit;
  Doc := JsonParse(AExtra);
  if (Doc = nil) or Doc.HasError or (not Doc.Root.IsObject) then
    raise EAgentError.CreateLocal(aecConfig,
      APrefix + ': ExtraJson must be a JSON object');
end;

procedure AgentValidateWireHeaders(const AHeaders: TWireHeaderArray); inline;
begin
  nextpas.core.agent.base.AgentValidateWireHeaders(AHeaders);
end;

procedure AgentWriteStrictJsonSchemaInner(ABld: IJsonBuilder;
  const ASchema: TJsonText);
begin
  ABld.Key('name');
  ABld.Str('response');
  ABld.Key('strict');
  ABld.Bool(True);
  ABld.Key('schema');
  ABld.RawJson(ASchema);
end;

procedure AgentWriteToolIdentity(ABld: IJsonBuilder;
  const ASpec: TToolSpec);
begin
  ABld.Key('name');
  ABld.Str(ASpec.Name);
  if ASpec.Description <> '' then
  begin
    ABld.Key('description');
    ABld.Str(ASpec.Description);
  end;
end;

procedure AgentWriteToolCommonFields(ABld: IJsonBuilder;
  const ASpec: TToolSpec);
begin
  AgentWriteToolIdentity(ABld, ASpec);
  ABld.Key('parameters');
  if ASpec.ParametersJson <> '' then
    ABld.RawJson(ASpec.ParametersJson)
  else
    ABld.RawJson('{}');
end;

procedure AgentWriteTemperature(ABld: IJsonBuilder; ATemp: Double);
begin
  if ATemp >= 0 then
  begin
    ABld.Key('temperature');
    ABld.Float(ATemp);
  end;
end;

procedure AgentWriteTopP(ABld: IJsonBuilder; ATopP: Double);
begin
  if ATopP >= 0 then
  begin
    ABld.Key('top_p');
    ABld.Float(ATopP);
  end;
end;

procedure AgentWriteSeed(ABld: IJsonBuilder; ASeed: Int64);
begin
  if ASeed <> CSeedUnset then
  begin
    ABld.Key('seed');
    ABld.Int(ASeed);
  end;
end;

procedure AgentWriteStopSequences(ABld: IJsonBuilder;
  const ASeq: nextpas.core.base.TStringArray; const AKey: string);
var
  I: Integer;
begin
  if (AKey = '') or (Length(ASeq) = 0) then
    Exit;
  ABld.Key(AKey);
  ABld.BeginArray;
  for I := 0 to High(ASeq) do
    ABld.Str(ASeq[I]);
  ABld.EndArray;
end;

procedure AgentWriteParallelToolCalls(ABld: IJsonBuilder;
  AVal: TTriState);
begin
  if AVal <> tsUnset then
  begin
    ABld.Key('parallel_tool_calls');
    ABld.Bool(AVal = tsTrue);
  end;
end;

function AgentReasoningEffortToStr(AEffort: TReasoningEffort): string;
begin
  case AEffort of
    reMinimal: Exit('minimal');
    reLow:     Exit('low');
    reMedium:  Exit('medium');
    reHigh:    Exit('high');
    reXHigh:   Exit('xhigh');
    reMax:     Exit('max');
  else
    Exit('');
  end;
end;

function AgentToolChoiceSimpleStr(AMode: TToolChoiceMode): string;
begin
  case AMode of
    tcmAuto:     Exit('auto');
    tcmNone:     Exit('none');
    tcmRequired: Exit('required');
  else
    Exit('');
  end;
end;

procedure AgentWriteThinking(ABld: IJsonBuilder;
  AThinking: TTriState; ABudget: Int64);
begin
  case AThinking of
    tsTrue:
      begin
        ABld.Key('thinking');
        ABld.BeginObject;
        ABld.Key('type');
        ABld.Str('enabled');
        ABld.Key('budget_tokens');
        ABld.Int(ABudget);
        ABld.EndObject;
      end;
    tsFalse:
      begin
        ABld.Key('thinking');
        ABld.BeginObject;
        ABld.Key('type');
        ABld.Str('disabled');
        ABld.EndObject;
      end;
    tsUnset:
      ; // 不上送
  end;
end;

end.
