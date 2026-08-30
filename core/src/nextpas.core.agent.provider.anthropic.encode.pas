{**
 * nextpas.core.agent.provider.anthropic.encode - Anthropic 编码子域。
 *
 * 职责：Messages / count_tokens 请求体的纯函数编码（§2.1/§2.7），
 * 含 System 去重、cache_control 断点、tool/input_schema、thinking、
 * image data URI 等全部上送规则。零 IO，零状态。
 *
 * 属 provider.anthropic 四象限拆分之一（encode），与 decode/decoder/factory
 * 互不循环，仅向下依赖 base/errors/intf/common/json。
 *}

unit nextpas.core.agent.provider.anthropic.encode;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.agent.base,
  nextpas.core.agent.intf;

function EncodeAnthropicRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText;
function EncodeAnthropicCountTokensRequest(
  const AReq: TCompletionRequest): TJsonText;

implementation

uses
  SysUtils,
  nextpas.core.json,
  nextpas.core.json.builder,
  nextpas.core.text.builder,
  nextpas.core.agent.errors,
  nextpas.core.agent.provider.common;

const
  CIMAGE_MIMES: array[0..3] of string = (
    'image/png', 'image/jpeg', 'image/gif', 'image/webp');

function MimeAllowed(const AMime: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := Low(CIMAGE_MIMES) to High(CIMAGE_MIMES) do
    if CIMAGE_MIMES[I] = AMime then
      Exit(True);
end;

function ParseDataUri(const AUri: string;
  out AMime, APayload: string): Boolean;
const
  CPREFIX = 'data:';
var
  LRest, LMeta: string;
  LSemi: SizeInt;
begin
  Result := False;
  AMime := '';
  APayload := '';
  if (Copy(AUri, 1, Length(CPREFIX)) <> CPREFIX) or (Length(AUri) < 6) then
    Exit;
  LRest := Copy(AUri, Length(CPREFIX) + 1, MaxInt);
  LSemi := Pos(';', LRest);
  if LSemi < 2 then
    Exit;
  LMeta := Copy(LRest, 1, LSemi - 1);
  APayload := Copy(LRest, LSemi + 1, MaxInt);
  if Copy(APayload, 1, 7) <> 'base64,' then
    Exit;
  APayload := Copy(APayload, 8, MaxInt);
  if Copy(LMeta, 1, 6) <> 'image/' then
    Exit;
  AMime := LMeta;
  Result := (APayload <> '') and MimeAllowed(AMime);
end;

procedure WriteImageSource(ABld: IJsonBuilder; const AImageUrl: string);
var
  LMime, LPayload: string;
begin
  ABld.Key('source');
  ABld.BeginObject;
  if Copy(AImageUrl, 1, 5) = 'data:' then
  begin
    if not ParseDataUri(AImageUrl, LMime, LPayload) then
      raise EAgentError.CreateLocal(aecConfig,
        'anthropic: image data URI requires base64 payload and one of ' +
        'image/png|jpeg|gif|webp');
    ABld.Key('type');
    ABld.Str('base64');
    ABld.Key('media_type');
    ABld.Str(LMime);
    ABld.Key('data');
    ABld.Str(LPayload);
  end
  else if (Copy(AImageUrl, 1, 7) = 'http://') or
    (Copy(AImageUrl, 1, 8) = 'https://') then
  begin
    ABld.Key('type');
    ABld.Str('url');
    ABld.Key('url');
    ABld.Str(AImageUrl);
  end
  else
    raise EAgentError.CreateLocal(aecConfig,
      'anthropic: image url must be http(s) URL or data URI');
  ABld.EndObject;
end;

procedure WriteToolUseInput(ABld: IJsonBuilder; const AArgs: TJsonText);
var
  Doc: IJsonDocument;
begin
  ABld.Key('input');
  if Trim(AArgs) = '' then
  begin
    ABld.RawJson('{}');
    Exit;
  end;
  Doc := JsonParse(AArgs);
  if Doc.HasError or (not Doc.Root.IsObject) then
    raise EAgentError.CreateLocal(aecProtocol,
      'anthropic: tool call arguments must be a JSON object');
  ABld.RawJson(JsonStringify(Doc.Root));
end;

procedure WriteCacheControl(ABld: IJsonBuilder);
begin
  ABld.Key('cache_control');
  ABld.BeginObject;
  ABld.Key('type');
  ABld.Str('ephemeral');
  ABld.EndObject;
end;

procedure WriteUserBlocks(ABld: IJsonBuilder; const AM: TMessage;
  AMarkTail: Boolean = False);
var
  J: Integer;
  P: TPart;
begin
  ABld.Key('content');
  ABld.BeginArray;
  for J := 0 to High(AM.Parts) do
  begin
    P := AM.Parts[J];
    case P.Kind of
      pkText:
        begin
          ABld.BeginObject;
          ABld.Key('type');
          ABld.Str('text');
          ABld.Key('text');
          ABld.Str(P.Text);
          if AMarkTail and (J = High(AM.Parts)) then
            WriteCacheControl(ABld);
          ABld.EndObject;
        end;
      pkImage:
        begin
          ABld.BeginObject;
          ABld.Key('type');
          ABld.Str('image');
          WriteImageSource(ABld, P.ImageUrl);
          if AMarkTail and (J = High(AM.Parts)) then
            WriteCacheControl(ABld);
          ABld.EndObject;
        end;
      pkToolResult:
        begin
          ABld.BeginObject;
          ABld.Key('type');
          ABld.Str('tool_result');
          ABld.Key('tool_use_id');
          ABld.Str(P.ToolCallId);
          ABld.Key('content');
          ABld.Str(P.ResultJson);
          if P.IsError then
          begin
            ABld.Key('is_error');
            ABld.RawJson('true');
          end;
          if AMarkTail and (J = High(AM.Parts)) then
            WriteCacheControl(ABld);
          ABld.EndObject;
        end;
      pkThinking,
      pkToolCall:
        raise EAgentError.CreateLocal(aecProtocol,
          'anthropic: thinking/tool_call parts belong to assistant messages');
    end;
  end;
  ABld.EndArray;
end;

procedure WriteAssistantBlocks(ABld: IJsonBuilder; const AM: TMessage;
  AMarkTail: Boolean = False);
var
  J: Integer;
  P: TPart;
begin
  ABld.Key('content');
  ABld.BeginArray;
  for J := 0 to High(AM.Parts) do
  begin
    P := AM.Parts[J];
    case P.Kind of
      pkText:
        begin
          ABld.BeginObject;
          ABld.Key('type');
          ABld.Str('text');
          ABld.Key('text');
          ABld.Str(P.Text);
          if AMarkTail and (J = High(AM.Parts)) then
            WriteCacheControl(ABld);
          ABld.EndObject;
        end;
      pkThinking:
        begin
          ABld.BeginObject;
          ABld.Key('type');
          ABld.Str('thinking');
          ABld.Key('thinking');
          ABld.Str(P.Text);
          if P.Signature <> '' then
          begin
            ABld.Key('signature');
            ABld.Str(P.Signature);
          end;
          if AMarkTail and (J = High(AM.Parts)) then
            WriteCacheControl(ABld);
          ABld.EndObject;
        end;
      pkToolCall:
        begin
          ABld.BeginObject;
          ABld.Key('type');
          ABld.Str('tool_use');
          ABld.Key('id');
          ABld.Str(P.ToolCallId);
          ABld.Key('name');
          ABld.Str(P.ToolName);
          WriteToolUseInput(ABld, P.ArgumentsJson);
          if AMarkTail and (J = High(AM.Parts)) then
            WriteCacheControl(ABld);
          ABld.EndObject;
        end;
      pkImage,
      pkToolResult:
        raise EAgentError.CreateLocal(aecProtocol,
          'anthropic: image/tool_result parts belong to user messages');
    end;
  end;
  ABld.EndArray;
end;

procedure WriteTools(ABld: IJsonBuilder; const ASpecs: TToolSpecArray;
  AMarkTail: Boolean = False);
var
  I: Integer;
  Doc: IJsonDocument;
begin
  ABld.Key('tools');
  ABld.BeginArray;
  for I := 0 to High(ASpecs) do
  begin
    ABld.BeginObject;
    AgentWriteToolIdentity(ABld, ASpecs[I]);
    ABld.Key('input_schema');
    if Trim(ASpecs[I].ParametersJson) = '' then
      ABld.RawJson('{"type":"object"}')
    else
    begin
      Doc := JsonParse(ASpecs[I].ParametersJson);
      if Doc.HasError or (not Doc.Root.IsObject) then
        raise EAgentError.CreateLocal(aecProtocol,
          'anthropic: tool input_schema must be a JSON object');
      ABld.RawJson(JsonStringify(Doc.Root));
    end;
    if AMarkTail and (I = High(ASpecs)) then
      WriteCacheControl(ABld);
    ABld.EndObject;
  end;
  ABld.EndArray;
end;

function EncodeAnthropicBody(const AReq: TCompletionRequest;
  AStream, ACountMode: Boolean): TJsonText;
var
  B: IJsonBuilder;
  I: Integer;
  M: TMessage;
  LSysText: string;
  LCache: Boolean;
  LLastMsg: Integer;
begin
  AgentRejectResponseSchema(AReq.ResponseSchemaJson, 'anthropic');
  AgentValidateModelNotEmpty(AReq.Model, 'anthropic');
  if not ACountMode and (AReq.MaxTokens <= CMaxTokensUnset) then
    raise EAgentError.CreateLocal(aecConfig,
      'anthropic: max_tokens is required by the vendor (set MaxTokens)');
  AgentValidateThinking(AReq, 'anthropic');
  AgentValidateToolChoice(AReq, 'anthropic');
  AgentValidateExtraJson(AReq.ExtraJson, 'anthropic');
  LCache := AReq.CacheControl = ccmAuto;
  LLastMsg := -1;
  for I := 0 to High(AReq.Messages) do
    if AReq.Messages[I].Role <> mrSystem then
      LLastMsg := I;
  B := JsonBuilder;
  B.BeginObject;
  B.Key('model');
  B.Str(AReq.Model);
  if not ACountMode then
  begin
    B.Key('max_tokens');
    B.Int(AReq.MaxTokens);
  end;
  LSysText := AgentBuildSystemText(AReq.System, AReq.Messages);
  if LSysText <> '' then
  begin
    B.Key('system');
    if LCache then
    begin
      B.BeginArray;
      B.BeginObject;
      B.Key('type');
      B.Str('text');
      B.Key('text');
      B.Str(LSysText);
      WriteCacheControl(B);
      B.EndObject;
      B.EndArray;
    end
    else
      B.Str(LSysText);
  end;
  B.Key('messages');
  B.BeginArray;
  for I := 0 to High(AReq.Messages) do
  begin
    M := AReq.Messages[I];
    case M.Role of
      mrSystem:
        Continue;
      mrUser:
        begin
          B.BeginObject;
          B.Key('role');
          B.Str('user');
          WriteUserBlocks(B, M, LCache and (I = LLastMsg));
          WriteExtraFields(B, M.ExtraJson, ['role', 'content']);
          B.EndObject;
        end;
      mrAssistant:
        begin
          B.BeginObject;
          B.Key('role');
          B.Str('assistant');
          WriteAssistantBlocks(B, M, LCache and (I = LLastMsg));
          WriteExtraFields(B, M.ExtraJson, ['role', 'content']);
          B.EndObject;
        end;
      mrTool:
        begin
          B.BeginObject;
          B.Key('role');
          B.Str('user');
          WriteUserBlocks(B, M, LCache and (I = LLastMsg));
          WriteExtraFields(B, M.ExtraJson, ['role', 'content']);
          B.EndObject;
        end;
    end;
  end;
  B.EndArray;
  if AReq.ToolChoice <> tcmNone then
  begin
    if Length(AReq.Tools) > 0 then
      WriteTools(B, AReq.Tools, LCache);
    case AReq.ToolChoice of
      tcmAuto:
        begin
          B.Key('tool_choice');
          B.BeginObject;
          B.Key('type');
          B.Str('auto');
          B.EndObject;
        end;
      tcmRequired:
        begin
          B.Key('tool_choice');
          B.BeginObject;
          B.Key('type');
          B.Str('any');
          B.EndObject;
        end;
      tcmNamed:
        begin
          B.Key('tool_choice');
          B.BeginObject;
          B.Key('type');
          B.Str('tool');
          B.Key('name');
          B.Str(AReq.ToolChoiceName);
          B.EndObject;
        end;
      tcmNone, tcmUnset:
        ;
    end;
  end;
  if not ACountMode then
  begin
    AgentWriteTemperature(B, AReq.Temperature);
    AgentWriteTopP(B, AReq.TopP);
    AgentWriteStopSequences(B, AReq.StopSequences, 'stop_sequences');
  end;
  AgentWriteThinking(B, AReq.Thinking, AReq.ThinkingBudgetTokens);
  if AStream then
  begin
    B.Key('stream');
    B.RawJson('true');
  end;
  if ACountMode then
    WriteExtraFields(B, AReq.ExtraJson,
      ['model', 'system', 'messages', 'tools', 'tool_choice', 'thinking'])
  else
    WriteExtraFields(B, AReq.ExtraJson,
      ['model', 'max_tokens', 'system', 'messages', 'tools', 'tool_choice',
       'temperature', 'top_p', 'stop_sequences', 'thinking', 'stream']);
  B.EndObject;
  Result := B.ToString;
end;

function EncodeAnthropicRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText;
begin
  Result := EncodeAnthropicBody(AReq, AStream, False);
end;

function EncodeAnthropicCountTokensRequest(
  const AReq: TCompletionRequest): TJsonText;
begin
  Result := EncodeAnthropicBody(AReq, False, True);
end;

end.
