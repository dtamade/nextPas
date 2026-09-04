{**
 * nextpas.core.agent.provider.openai.decode - OpenAI 非流式解码子域。
 *
 * 职责：Chat Completions 非流式响应解码（WIRE-MAPPINGS §1.2）——
 * content / reasoning_content / tool_calls 分拨、finish_reason 映射、
 * usage 合成、Extra 无损捕获（Q-O5/Q-O7 生产怪癖）。纯函数，零 IO。
 *
 * 属 provider.openai 四象限拆分之二（decode），与 encode/decoder/facade
 * 互不循环，仅向下依赖 base/errors/common/json。
 *}

unit nextpas.core.agent.provider.openai.decode;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.log.intf,
  nextpas.core.agent.base,
  nextpas.core.agent.intf;

procedure DecodeOpenAIResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger = nil);

implementation

uses
  nextpas.core.json.value,
  nextpas.core.json,
  nextpas.core.json.builder,
  nextpas.core.text.builder,
  nextpas.core.text.conv,
  nextpas.core.agent.errors,
  nextpas.core.agent.provider.common;

const
  CKNOWN_ROOT: array[0..4] of string = ('id', 'object', 'choices', 'usage',
    'model');
  CKNOWN_CHOICE: array[0..2] of string = ('index', 'message', 'finish_reason');
  CKNOWN_MESSAGE: array[0..3] of string =
    ('role', 'content', 'tool_calls', 'reasoning_content');
  CKNOWN_TOOLCALL: array[0..3] of string =
    ('id', 'type', 'function', 'index');
  CKNOWN_FUNCTION: array[0..1] of string = ('name', 'arguments');
  CAGENT_UNMAPPED_FINISH = 'agent.unmapped.finish_reason';

procedure WarnLog(const ALog: ILogger; const AMsg: string); inline;
begin
  AgentWarnLog(ALog, AMsg);
end;

procedure ProtocolError(const ABodySrc: string; const AMsg: string);
begin
  AgentProtocolError('openai', ABodySrc, AMsg);
end;

function MapFinishReason(const S: string;
  out AUnmapped: string): TFinishReason;
begin
  AUnmapped := '';
  if S = 'stop' then
    Exit(frStop);
  if S = 'length' then
    Exit(frLength);
  if S = 'tool_calls' then
    Exit(frToolCalls);
  if S = 'content_filter' then
    Exit(frContentFilter);
  Result := frNone;
  AUnmapped := S;
end;

procedure FillUsage(const AV: TJsonValue; out AU: TTokenUsage);
var
  LD: TJsonValue;
begin
  AgentInitUsageUnknown(AU);
  if not AV.IsObject then
    Exit;
  { 兼容网关偶发 Anthropic 式键名：主鍵缺失才回落，不覆盖显式值 }
  if AV.Get('prompt_tokens').IsInt then
    AU.InputTokens := AV.Get('prompt_tokens').AsInt
  else if AV.Get('input_tokens').IsInt then
    AU.InputTokens := AV.Get('input_tokens').AsInt;
  if AV.Get('completion_tokens').IsInt then
    AU.OutputTokens := AV.Get('completion_tokens').AsInt
  else if AV.Get('output_tokens').IsInt then
    AU.OutputTokens := AV.Get('output_tokens').AsInt;
  LD := AV.Get('completion_tokens_details');
  if LD.IsObject and LD.Get('reasoning_tokens').IsInt then
    AU.ReasoningTokens := LD.Get('reasoning_tokens').AsInt;
  LD := AV.Get('prompt_tokens_details');
  if LD.IsObject and LD.Get('cached_tokens').IsInt then
    AU.CacheReadInputTokens := LD.Get('cached_tokens').AsInt;
end;

procedure AddPart(var AParts: TPartArray; AKind: TPartKind); inline;
begin
  AgentAddPart(AParts, AKind);
end;

procedure DecodeOpenAIResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger);
var
  Doc: IJsonDocument;
  Root, LChoices, LC0, LM, LT, LItem, LFn: TJsonValue;
  I: Integer;
  LRv, LUnmapped, LUnmappedJson: string;
  LExtras: array of TJsonText;
  LRole: string;

  function ReqStr(const AV: TJsonValue; const AWhat: string): string;
  begin
    if not AV.IsStr then
      ProtocolError(ABody, AWhat + ' must be a string');
    Result := AV.AsStr.ToString;
    if Result = '' then
      ProtocolError(ABody, AWhat + ' must be non-empty');
  end;

begin
  Doc := JsonParse(ABody);
  if Doc.HasError or (not Doc.Root.IsObject) then
    ProtocolError(ABody, 'response body must be a JSON object');
  Root := Doc.Root;

  AMsg := Default(TMessage);
  AMsg.Role := mrAssistant;
  if Root.Get('id').IsStr then
    AMsg.Id := Root.Get('id').AsStr.ToString;
  if Root.Get('model').IsStr then
    AMsg.Model := Root.Get('model').AsStr.ToString;

  LChoices := Root.Get('choices');
  if not LChoices.IsArray then
    ProtocolError(ABody, 'missing choices array');
  if LChoices.ArrayLen = 0 then
    ProtocolError(ABody, 'empty choices array');
  if LChoices.ArrayLen > 1 then
    WarnLog(ALog, 'openai: dropping ' +
      nextpas.core.text.conv.IntToStr(Int64(LChoices.ArrayLen) - 1) +
      ' extra choice(s) beyond index 0 (Q-O7)');
  LC0 := LChoices.ArrayGet(0);

  LUnmappedJson := '';
  if LC0.Get('finish_reason').IsStr then
  begin
    LRv := LC0.Get('finish_reason').AsStr.ToString;
    if LRv <> '' then
    begin
      AMsg.FinishReason := MapFinishReason(LRv, LUnmapped);
      if LUnmapped <> '' then
      begin
        WarnLog(ALog, 'openai: unmapped finish_reason "' + LUnmapped +
          '" -> frNone');
        LUnmappedJson := AgentUnmappedJson(CAGENT_UNMAPPED_FINISH, LUnmapped);
      end;
    end;
  end
  else if LC0.Get('finish_reason').IsValid and
    (not LC0.Get('finish_reason').IsNull) then
    ProtocolError(ABody, 'finish_reason must be a string or null');

  FillUsage(Root.Get('usage'), AMsg.Usage);

  LM := LC0.Get('message');
  if not LM.IsObject then
    ProtocolError(ABody, 'choices[0].message missing or not an object');
  if LM.Get('role').IsStr then
  begin
    LRole := LM.Get('role').AsStr.ToString;
    if LRole <> 'assistant' then
      ProtocolError(ABody, 'unexpected message role "' + LRole + '"');
  end;

  if LM.Get('content').IsStr then
  begin
    LRole := LM.Get('content').AsStr.ToString;
    if LRole <> '' then
    begin
      AddPart(AMsg.Parts, pkText);
      AMsg.Parts[High(AMsg.Parts)].Text := LRole;
    end;
  end;
  if LM.Get('reasoning_content').IsStr or LM.Get('reasoning').IsStr then
  begin
    if LM.Get('reasoning_content').IsStr then
      LRole := LM.Get('reasoning_content').AsStr.ToString
    else
      LRole := LM.Get('reasoning').AsStr.ToString;
    if LRole <> '' then
    begin
      AddPart(AMsg.Parts, pkThinking);
      AMsg.Parts[High(AMsg.Parts)].Text := LRole;
    end;
  end;
  LT := LM.Get('tool_calls');
  if LT.IsValid and (not LT.IsNull) and (not LT.IsArray) then
    ProtocolError(ABody, 'message.tool_calls must be an array');
  if LT.IsArray then
    for I := 0 to Integer(LT.ArrayLen) - 1 do
    begin
      LItem := LT.ArrayGet(UInt32(I));
      if not LItem.IsObject then
        ProtocolError(ABody, 'tool call entry must be an object');
      LFn := LItem.Get('function');
      if not LFn.IsObject then
        ProtocolError(ABody, 'tool call missing function object');
      AddPart(AMsg.Parts, pkToolCall);
      AMsg.Parts[High(AMsg.Parts)].ToolCallId :=
        ReqStr(LItem.Get('id'), 'tool call id');
      AMsg.Parts[High(AMsg.Parts)].ToolName :=
        ReqStr(LFn.Get('name'), 'tool call function.name');
      AMsg.Parts[High(AMsg.Parts)].ArgumentsJson :=
        ReqStr(LFn.Get('arguments'), 'tool call function.arguments');
      AMsg.Parts[High(AMsg.Parts)].ExtraJson := MergeExtraJson([
        CaptureExtraJson(LItem, CKNOWN_TOOLCALL, CMaxExtraKeys, ALog),
        CaptureExtraJson(LFn, CKNOWN_FUNCTION, CMaxExtraKeys, ALog)]);
    end;

  if AMsg.FinishReason = frStop then
    for I := 0 to High(AMsg.Parts) do
      if AMsg.Parts[I].Kind = pkToolCall then
      begin
        AMsg.FinishReason := frToolCalls;
        Break;
      end;

  SetLength(LExtras, 4);
  LExtras[0] := CaptureExtraJson(Root, CKNOWN_ROOT, CMaxExtraKeys, ALog);
  LExtras[1] := CaptureExtraJson(LC0, CKNOWN_CHOICE, CMaxExtraKeys, ALog);
  LExtras[2] := CaptureExtraJson(LM, CKNOWN_MESSAGE, CMaxExtraKeys, ALog);
  LExtras[3] := LUnmappedJson;
  AMsg.ExtraJson := MergeExtraJson(LExtras);
end;

end.
