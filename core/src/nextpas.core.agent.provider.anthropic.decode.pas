{**
 * nextpas.core.agent.provider.anthropic.decode - Anthropic 非流式解码子域。
 *
 * 职责：Messages 非流式响应解码（§2.2）—— content 块类型分拨、
 * stop_reason 映射、usage 合成、Extra 无损捕获。纯函数，零 IO。
 *
 * 属 provider.anthropic 四象限拆分之二（decode），与 encode/decoder/factory
 * 互不循环，仅向下依赖 base/errors/common/json。
 *}

unit nextpas.core.agent.provider.anthropic.decode;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.log.intf,
  nextpas.core.agent.base,
  nextpas.core.agent.intf;

procedure DecodeAnthropicResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger = nil);

implementation

uses
  nextpas.core.json.value,
  nextpas.core.json,
  nextpas.core.agent.errors,
  nextpas.core.agent.provider.common;

const
  CAGENT_UNMAPPED_STOP = 'agent.unmapped.stop_reason';
  CAGENT_UNMAPPED_BLOCK = 'agent.unmapped.content_block_type';

procedure WarnLog(const ALog: ILogger; const AMsg: string); inline;
begin
  AgentWarnLog(ALog, AMsg);
end;

procedure ProtocolError(const ABodySrc: string; const AMsg: string); inline;
begin
  AgentProtocolError('anthropic', ABodySrc, AMsg);
end;

function MapStopReason(const S: string; out AUnmapped: string): TFinishReason;
begin
  AUnmapped := '';
  Result := frNone;
  if S = 'end_turn' then
    Exit(frStop);
  if S = 'stop_sequence' then
    Exit(frStop);
  if S = 'max_tokens' then
    Exit(frLength);
  if S = 'tool_use' then
    Exit(frToolCalls);
  if S = 'refusal' then
    Exit(frContentFilter);
  if S <> '' then
    AUnmapped := S;
end;

procedure DecodeAnthropicResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger);
var
  Doc: IJsonDocument;
  Root, LContent, LBlock, LU, LD: TJsonValue;
  I: Integer;
  LType, LTxt, LUnmapped: string;
  LCaps: array of TJsonText;

  procedure AddPart(APKind: TPartKind); inline;
  begin
    AgentAddPart(AMsg.Parts, APKind);
  end;

  procedure AddCap(const AKey, ARaw: string);
  begin
    if ARaw = '' then
      Exit;
    SetLength(LCaps, Length(LCaps) + 1);
    LCaps[High(LCaps)] := AgentUnmappedJson(AKey, ARaw);
  end;

begin
  Doc := JsonParse(ABody);
  if Doc.HasError or (not Doc.Root.IsObject) then
    ProtocolError(ABody, 'response body must be a JSON object');
  Root := Doc.Root;
  if Root.Get('type').IsStr and
    (Root.Get('type').AsStr.ToString = 'error') then
    ProtocolError(ABody,
      'error envelope on a success response is a protocol violation');
  AMsg := Default(TMessage);
  AMsg.Role := mrAssistant;
  if Root.Get('id').IsStr then
    AMsg.Id := Root.Get('id').AsStr.ToString;
  if Root.Get('model').IsStr then
    AMsg.Model := Root.Get('model').AsStr.ToString;
  LContent := Root.Get('content');
  if not LContent.IsArray then
    ProtocolError(ABody, 'missing content array');
  for I := 0 to Integer(LContent.ArrayLen) - 1 do
  begin
    LBlock := LContent.ArrayGet(UInt32(I));
    if not LBlock.IsObject then
      ProtocolError(ABody, 'content block must be an object');
    if not LBlock.Get('type').IsStr then
      ProtocolError(ABody, 'content block missing type');
    LType := LBlock.Get('type').AsStr.ToString;
    if LType = 'text' then
    begin
      if LBlock.Get('text').IsStr then
      begin
        LTxt := LBlock.Get('text').AsStr.ToString;
        if LTxt <> '' then
        begin
          AddPart(pkText);
          AMsg.Parts[High(AMsg.Parts)].Text := LTxt;
        end;
      end
      else
        ProtocolError(ABody, 'text block requires text string');
    end
    else if LType = 'thinking' then
    begin
      AddPart(pkThinking);
      if LBlock.Get('thinking').IsStr then
        AMsg.Parts[High(AMsg.Parts)].Text :=
          LBlock.Get('thinking').AsStr.ToString;
      if LBlock.Get('signature').IsStr then
        AMsg.Parts[High(AMsg.Parts)].Signature :=
          LBlock.Get('signature').AsStr.ToString;
    end
    else if LType = 'tool_use' then
    begin
      AddPart(pkToolCall);
      if LBlock.Get('id').IsStr then
        AMsg.Parts[High(AMsg.Parts)].ToolCallId :=
          LBlock.Get('id').AsStr.ToString;
      if LBlock.Get('name').IsStr then
        AMsg.Parts[High(AMsg.Parts)].ToolName :=
          LBlock.Get('name').AsStr.ToString;
      LD := LBlock.Get('input');
      if not LD.IsObject then
        ProtocolError(ABody, 'tool_use block requires input object');
      AMsg.Parts[High(AMsg.Parts)].ArgumentsJson := JsonStringify(LD);
    end
    else
    begin
      WarnLog(ALog, 'anthropic: unmapped content block type "' +
        LType + '" skipped');
      AddCap(CAGENT_UNMAPPED_BLOCK, LType);
    end;
  end;
  if Root.Get('stop_reason').IsStr then
  begin
    LTxt := Root.Get('stop_reason').AsStr.ToString;
    if LTxt <> '' then
    begin
      AMsg.FinishReason := MapStopReason(LTxt, LUnmapped);
      if LUnmapped <> '' then
      begin
        WarnLog(ALog, 'anthropic: unmapped stop_reason "' + LUnmapped +
          '" -> frNone');
        AddCap(CAGENT_UNMAPPED_STOP, LUnmapped);
      end;
    end;
  end
  else if Root.Get('stop_reason').IsValid and
    (not Root.Get('stop_reason').IsNull) then
    ProtocolError(ABody, 'stop_reason must be a string or null');
  LU := Root.Get('usage');
  if LU.IsObject then
  begin
    AgentInitUsageUnknown(AMsg.Usage);
    if LU.Get('input_tokens').IsInt then
      AMsg.Usage.InputTokens := LU.Get('input_tokens').AsInt;
    if LU.Get('output_tokens').IsInt then
      AMsg.Usage.OutputTokens := LU.Get('output_tokens').AsInt;
    if LU.Get('cache_read_input_tokens').IsInt then
      AMsg.Usage.CacheReadInputTokens :=
        LU.Get('cache_read_input_tokens').AsInt;
    if LU.Get('cache_creation_input_tokens').IsInt then
      AMsg.Usage.CacheWriteInputTokens :=
        LU.Get('cache_creation_input_tokens').AsInt;
  end;
  SetLength(LCaps, Length(LCaps) + 1);
  LCaps[High(LCaps)] := CaptureExtraJson(Root,
    ['id', 'type', 'role', 'content', 'model', 'stop_reason',
     'stop_sequence', 'usage'], CMaxExtraKeys, ALog);
  AMsg.ExtraJson := MergeExtraJson(LCaps);
end;

end.
