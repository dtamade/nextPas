{**
 * nextpas.core.agent.provider.openai.responses.decode - Responses 非流式解码子域。
 *
 * 职责：Responses 非流式响应解码（WIRE-MAPPINGS §3.2）—— output 三类项
 * （message/reasoning/function_call）分拨、usage（Q-R4 字段名差异）
 * 合成、finish 推导（frToolCalls/frLength/frStop）、错误信封上抛
 * （aecServer）、Extra 无损捕获。纯函数，零 IO。
 *
 * 属 provider.openai.responses 四象限拆分之二（decode），与
 * encode/decoder/facade 互不循环，仅向下依赖 base/errors/common/json。
 *}

unit nextpas.core.agent.provider.openai.responses.decode;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.log.intf,
  nextpas.core.agent.base,
  nextpas.core.agent.intf;

procedure DecodeResponsesResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger = nil);

implementation

uses
  nextpas.core.json,
  nextpas.core.agent.errors,
  nextpas.core.agent.provider.common;

const
  CKNOWN_ROOT: array[0..5] of string = ('id', 'object', 'model', 'status',
    'usage', 'error');
  CKNOWN_ITEM: array[0..5] of string = ('type', 'id', 'role', 'content',
    'name', 'call_id');
  CKNOWN_FCITEM: array[0..4] of string = ('type', 'id', 'call_id', 'name',
    'arguments');
  CKNOWN_CONTENT: array[0..2] of string = ('type', 'text', 'annotations');

  CAGENT_UNMAPPED_STATUS = 'agent.unmapped.response_status';
  CAGENT_UNMAPPED_INCOMPLETE = 'agent.unmapped.incomplete_reason';

procedure WarnLog(const ALog: ILogger; const AMsg: string); inline;
begin
  AgentWarnLog(ALog, AMsg);
end;

procedure ProtocolError(const ABodySrc: string; const AMsg: string);
begin
  AgentProtocolError('openai.responses', ABodySrc, AMsg);
end;

procedure AddPart(var AParts: TPartArray; AKind: TPartKind); inline;
begin
  AgentAddPart(AParts, AKind);
end;

procedure FillUsageResponses(const AV: TJsonValue; out AU: TTokenUsage);
var
  LD: TJsonValue;
begin
  AgentInitUsageUnknown(AU);
  if not AV.IsObject then
    Exit;
  if AV.Get('input_tokens').IsInt then
    AU.InputTokens := AV.Get('input_tokens').AsInt;
  if AV.Get('output_tokens').IsInt then
    AU.OutputTokens := AV.Get('output_tokens').AsInt;
  LD := AV.Get('output_tokens_details');
  if LD.IsObject and LD.Get('reasoning_tokens').IsInt then
    AU.ReasoningTokens := LD.Get('reasoning_tokens').AsInt;
  LD := AV.Get('input_tokens_details');
  if LD.IsObject and LD.Get('cached_tokens').IsInt then
    AU.CacheReadInputTokens := LD.Get('cached_tokens').AsInt;
end;

procedure DecodeOutputItems(const AOutput: TJsonValue; const ABody: string;
  var AMsg: TMessage; out AHasToolCall: Boolean; const ALog: ILogger);
var
  I, J: Integer;
  LItem, LContent, LC, LS: TJsonValue;
  LTyp, LTxt: string;

  function ReqStr(const AV: TJsonValue; const AWhat: string): string;
  begin
    if not AV.IsStr then
      ProtocolError(ABody, AWhat + ' must be a string');
    Result := AV.AsStr.ToString;
    if Result = '' then
      ProtocolError(ABody, AWhat + ' must be non-empty');
  end;

begin
  AHasToolCall := False;
  for I := 0 to Integer(AOutput.ArrayLen) - 1 do
  begin
    LItem := AOutput.ArrayGet(UInt32(I));
    if not LItem.IsObject then
      ProtocolError(ABody, 'output entry must be an object');
    LTyp := '';
    if LItem.Get('type').IsStr then
      LTyp := LItem.Get('type').AsStr.ToString;

    if LTyp = 'message' then
    begin
      LContent := LItem.Get('content');
      if LContent.IsValid and (not LContent.IsNull) and
        (not LContent.IsArray) then
        ProtocolError(ABody, 'message.content must be an array');
      for J := 0 to Integer(LContent.ArrayLen) - 1 do
      begin
        LC := LContent.ArrayGet(UInt32(J));
        if not LC.IsObject then
          ProtocolError(ABody, 'message.content entry must be an object');
        LTyp := '';
        if LC.Get('type').IsStr then
          LTyp := LC.Get('type').AsStr.ToString;
        if LTyp = 'output_text' then
        begin
          LTxt := ReqStr(LC.Get('text'), 'output_text.text');
          AddPart(AMsg.Parts, pkText);
          AMsg.Parts[High(AMsg.Parts)].Text := LTxt;
          AMsg.Parts[High(AMsg.Parts)].ExtraJson :=
            CaptureExtraJson(LC, CKNOWN_CONTENT, CMaxExtraKeys, ALog);
        end
        else if LTyp = 'refusal' then
        begin
        end;
      end;
      AMsg.ExtraJson := MergeExtraJson([AMsg.ExtraJson,
        CaptureExtraJson(LItem, CKNOWN_ITEM, CMaxExtraKeys, ALog)]);
    end
    else if LTyp = 'reasoning' then
    begin
      LS := LItem.Get('summary');
      if LS.IsValid and (not LS.IsNull) and (not LS.IsArray) then
        ProtocolError(ABody, 'reasoning.summary must be an array');
      LTxt := '';
      for J := 0 to Integer(LS.ArrayLen) - 1 do
      begin
        LC := LS.ArrayGet(UInt32(J));
        if LC.IsObject and LC.Get('text').IsStr then
        begin
          if LTxt <> '' then
            LTxt := LTxt + #10;
          LTxt := LTxt + LC.Get('text').AsStr.ToString;
        end;
      end;
      if LTxt <> '' then
      begin
        AddPart(AMsg.Parts, pkThinking);
        AMsg.Parts[High(AMsg.Parts)].Text := LTxt;
      end;
      AMsg.ExtraJson := MergeExtraJson([AMsg.ExtraJson,
        CaptureExtraJson(LItem, CKNOWN_ITEM, CMaxExtraKeys, ALog)]);
    end
    else if LTyp = 'function_call' then
    begin
      AHasToolCall := True;
      AddPart(AMsg.Parts, pkToolCall);
      AMsg.Parts[High(AMsg.Parts)].ToolCallId :=
        ReqStr(LItem.Get('call_id'), 'function_call.call_id');
      AMsg.Parts[High(AMsg.Parts)].ToolName :=
        ReqStr(LItem.Get('name'), 'function_call.name');
      AMsg.Parts[High(AMsg.Parts)].ArgumentsJson :=
        ReqStr(LItem.Get('arguments'), 'function_call.arguments');
      AMsg.Parts[High(AMsg.Parts)].ExtraJson :=
        CaptureExtraJson(LItem, CKNOWN_FCITEM, CMaxExtraKeys, ALog);
    end
    else
    begin
      AMsg.ExtraJson := MergeExtraJson([AMsg.ExtraJson,
        CaptureExtraJson(LItem, [], CMaxExtraKeys, ALog)]);
    end;
  end;
end;

procedure DecodeResponsesResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger);
var
  Doc: IJsonDocument;
  Root, LOut, LU, LE: TJsonValue;
  LStatus: string;
  LHasToolCall: Boolean;
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

  LE := Root.Get('error');
  if LE.IsObject and (LE.Get('message').IsStr or LE.Get('code').IsStr) then
  begin
    if LE.Get('message').IsStr then
      raise EAgentError.CreateUpstream(aecServer, 'openai.responses',
        LE.Get('message').AsStr.ToString,
        AMsg.Id, ABody, CRetryAfterUnknown);
  end;

  LStatus := '';
  if Root.Get('status').IsStr then
    LStatus := Root.Get('status').AsStr.ToString;

  LU := Root.Get('usage');
  if LU.IsObject then
    FillUsageResponses(LU, AMsg.Usage);

  LOut := Root.Get('output');
  if LOut.IsValid and (not LOut.IsNull) and (not LOut.IsArray) then
    ProtocolError(ABody, 'output must be an array');
  if LOut.IsArray then
    DecodeOutputItems(LOut, ABody, AMsg, LHasToolCall, ALog);

  if LHasToolCall then
    AMsg.FinishReason := frToolCalls
  else if LStatus = 'incomplete' then
    AMsg.FinishReason := frLength
  else if (LStatus = 'completed') or (LStatus = '') then
    AMsg.FinishReason := frStop
  else
  begin
    WarnLog(ALog, 'openai.responses: unmapped status "' + LStatus +
      '" -> frStop');
    AMsg.FinishReason := frStop;
    AMsg.ExtraJson := MergeExtraJson([AMsg.ExtraJson,
      '{"' + CAGENT_UNMAPPED_STATUS + '":"' + LStatus + '"}']);
  end;
  if LStatus = 'incomplete' then
    AMsg.ExtraJson := MergeExtraJson([AMsg.ExtraJson,
      '{"' + CAGENT_UNMAPPED_INCOMPLETE + '":true}']);
  AMsg.ExtraJson := MergeExtraJson([AMsg.ExtraJson,
    CaptureExtraJson(Root, CKNOWN_ROOT, CMaxExtraKeys, ALog)]);
end;

end.
