{**
 * nextpas.core.agent.provider.openai.encode - OpenAI 编码子域。
 *
 * 职责：Chat Completions 请求体的纯函数编码（WIRE-MAPPINGS §1.1），
 * 含 System 合并去重、消息展开（text/image/tool）、tools/tool_choice、
 * reasoning_effort、response_format、stream_options（Q-O3）等全部上送规则。
 * 另含 BuildOpenAIUrl/BuildGrokUrl 纯 URL 拼接与 UsesMaxCompletionTokens
 * 前缀判定（Q-O1）。零 IO，零状态。
 *
 * 属 provider.openai 四象限拆分之一（encode），与 decode/decoder/facade
 * 互不循环，仅向下依赖 base/errors/intf/common/json。
 *}

unit nextpas.core.agent.provider.openai.encode;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.agent.base,
  nextpas.core.agent.intf;

function EncodeOpenAIRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText;

function BuildOpenAIUrl(const ABaseUrl: string): string;
function BuildGrokUrl(const ABaseUrl: string): string;

implementation

uses
  nextpas.core.json.value,
  nextpas.core.json,
  nextpas.core.json.builder,
  nextpas.core.text,
  nextpas.core.text.builder,
  nextpas.core.agent.errors,
  nextpas.core.agent.provider.common;

const
  COPENAI_DEFAULT_BASE_URL = 'https://api.openai.com';
  CGROK_DEFAULT_BASE_URL = 'https://api.x.ai';
  COPENAI_MAX_COMPLETION_TOKENS_PREFIXES: array[0..2] of string =
    ('o1', 'o3', 'gpt-5');

function UsesMaxCompletionTokens(const AModel: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := Low(COPENAI_MAX_COMPLETION_TOKENS_PREFIXES) to
    High(COPENAI_MAX_COMPLETION_TOKENS_PREFIXES) do
    if nextpas.core.text.TextStartsWith(AModel,
      COPENAI_MAX_COMPLETION_TOKENS_PREFIXES[I]) then
      Exit(True);
end;

function BuildOpenAIUrl(const ABaseUrl: string): string;
begin
  Result := AgentJoinWireUrl(ABaseUrl, COPENAI_DEFAULT_BASE_URL, '/chat/completions');
end;

function BuildGrokUrl(const ABaseUrl: string): string;
begin
  Result := AgentJoinWireUrl(ABaseUrl, CGROK_DEFAULT_BASE_URL, '/chat/completions');
end;

procedure AddPart(var AParts: TPartArray; AKind: TPartKind); inline;
begin
  AgentAddPart(AParts, AKind);
end;

{ 顶层 System + 历史 mrSystem 合并去重为单一首条 system 消息
  （WIRE-MAPPINGS §0 确定性规则 + §1.1 合并去重行）}
procedure WriteMessages(ABld: IJsonBuilder; const AReq: TCompletionRequest);
var
  I, J: Integer;
  LSysText: string;
  M: TMessage;
  P: TPart;
  LText, LUrl: string;
  LHasImage, LHasToolCalls: Boolean;
  LB: IStringBuilder;
begin
  ABld.Key('messages');
  ABld.BeginArray;

  LSysText := AgentBuildSystemText(AReq.System, AReq.Messages);
  if LSysText <> '' then
  begin
    ABld.BeginObject;
    ABld.Key('role');
    ABld.Str('system');
    ABld.Key('content');
    ABld.Str(LSysText);
    ABld.EndObject;
  end;

  for I := 0 to High(AReq.Messages) do
  begin
    M := AReq.Messages[I];
    case M.Role of
      mrSystem:
        Continue;

      mrUser:
        begin
          LHasImage := False;
          for J := 0 to High(M.Parts) do
            if M.Parts[J].Kind = pkImage then
              LHasImage := True;
          ABld.BeginObject;
          ABld.Key('role');
          ABld.Str('user');
          if not LHasImage then
          begin
            ABld.Key('content');
            ABld.Str(MessageText(M));
          end
          else
          begin
            ABld.Key('content');
            ABld.BeginArray;
            for J := 0 to High(M.Parts) do
            begin
              P := M.Parts[J];
              if P.Kind = pkText then
              begin
                ABld.BeginObject;
                ABld.Key('type');
                ABld.Str('text');
                ABld.Key('text');
                ABld.Str(P.Text);
                ABld.EndObject;
              end
              else if P.Kind = pkImage then
              begin
                ABld.BeginObject;
                ABld.Key('type');
                ABld.Str('image_url');
                ABld.Key('image_url');
                ABld.BeginObject;
                ABld.Key('url');
                ABld.Str(P.ImageUrl);
                ABld.EndObject;
                ABld.EndObject;
              end;
            end;
            ABld.EndArray;
          end;
          WriteExtraFields(ABld, M.ExtraJson, ['role', 'content']);
          ABld.EndObject;
        end;

      mrAssistant:
        begin
          // perf: text.builder single source (BytesCopy zero-copy, geometric growth) — replaces O(N²) S+S hot path; evidence: AppendStr via bytes.ops.BytesCopy inline
          LB := MakeStringBuilder(256);
          LHasToolCalls := False;
          for J := 0 to High(M.Parts) do
          begin
            P := M.Parts[J];
            if P.Kind = pkText then
              LB.AppendStr(P.Text)
            else if P.Kind = pkToolCall then
              LHasToolCalls := True;
          end;
          LText := LB.ToString;
          ABld.BeginObject;
          ABld.Key('role');
          ABld.Str('assistant');
          ABld.Key('content');
          if LHasToolCalls and (LText = '') then
            ABld.Null
          else
            ABld.Str(LText);
          if LHasToolCalls then
          begin
            ABld.Key('tool_calls');
            ABld.BeginArray;
            for J := 0 to High(M.Parts) do
            begin
              P := M.Parts[J];
              if P.Kind <> pkToolCall then
                Continue;
              ABld.BeginObject;
              ABld.Key('id');
              ABld.Str(P.ToolCallId);
              ABld.Key('type');
              ABld.Str('function');
              ABld.Key('function');
              ABld.BeginObject;
              ABld.Key('name');
              ABld.Str(P.ToolName);
              ABld.Key('arguments');
              ABld.Str(P.ArgumentsJson);
              ABld.EndObject;
              WriteExtraFields(ABld, P.ExtraJson,
                ['id', 'type', 'function']);
              ABld.EndObject;
            end;
            ABld.EndArray;
          end;
          WriteExtraFields(ABld, M.ExtraJson,
            ['role', 'content', 'tool_calls', 'reasoning_content']);
          ABld.EndObject;
        end;

      mrTool:
        begin
          LUrl := '';
          for J := 0 to High(M.Parts) do
          begin
            P := M.Parts[J];
            if P.Kind <> pkToolResult then
              Continue;
            ABld.BeginObject;
            ABld.Key('role');
            ABld.Str('tool');
            ABld.Key('tool_call_id');
            ABld.Str(P.ToolCallId);
            ABld.Key('content');
            ABld.Str(P.ResultJson);
            if LUrl = '' then
            begin
              WriteExtraFields(ABld, M.ExtraJson,
                ['role', 'tool_call_id', 'content']);
              LUrl := '1';
            end;
            ABld.EndObject;
          end;
        end;
    end;
  end;

  ABld.EndArray;
end;

function EncodeOpenAIRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText;
var
  B: IJsonBuilder;
  I: Integer;
begin
  AgentValidateResponseSchemaIsObject(AReq.ResponseSchemaJson, 'openai');
  AgentValidateModelNotEmpty(AReq.Model, 'openai');
  AgentValidateToolChoice(AReq, 'openai');
  AgentValidateExtraJson(AReq.ExtraJson, 'openai');

  B := JsonBuilder;
  B.BeginObject;
  B.Key('model');
  B.Str(AReq.Model);

  WriteMessages(B, AReq);

  if AReq.MaxTokens > CMaxTokensUnset then
  begin
    if UsesMaxCompletionTokens(AReq.Model) then
      B.Key('max_completion_tokens')
    else
      B.Key('max_tokens');
    B.Int(AReq.MaxTokens);
  end;

  AgentWriteTemperature(B, AReq.Temperature);
  AgentWriteTopP(B, AReq.TopP);
  AgentWriteSeed(B, AReq.Seed);
  AgentWriteStopSequences(B, AReq.StopSequences, 'stop');
  AgentWriteParallelToolCalls(B, AReq.ParallelToolCalls);

  if Length(AReq.Tools) > 0 then
  begin
    B.Key('tools');
    B.BeginArray;
    for I := 0 to High(AReq.Tools) do
    begin
      B.BeginObject;
      B.Key('type');
      B.Str('function');
      B.Key('function');
      B.BeginObject;
      AgentWriteToolCommonFields(B, AReq.Tools[I]);
      B.EndObject;
      B.EndObject;
    end;
    B.EndArray;
  end;

  case AReq.ToolChoice of
    tcmAuto, tcmNone, tcmRequired:
      begin
        B.Key('tool_choice');
        B.Str(AgentToolChoiceSimpleStr(AReq.ToolChoice));
      end;
    tcmNamed:
      begin
        B.Key('tool_choice');
        B.BeginObject;
        B.Key('type');
        B.Str('function');
        B.Key('function');
        B.BeginObject;
        B.Key('name');
        B.Str(AReq.ToolChoiceName);
        B.EndObject;
        B.EndObject;
      end;
    tcmUnset:
      ;
  end;

  if AgentReasoningEffortToStr(AReq.ReasoningEffort) <> '' then
  begin
    B.Key('reasoning_effort');
    B.Str(AgentReasoningEffortToStr(AReq.ReasoningEffort));
  end;

  if AReq.ResponseSchemaJson <> '' then
  begin
    B.Key('response_format');
    B.BeginObject;
    B.Key('type');
    B.Str('json_schema');
    B.Key('json_schema');
    B.BeginObject;
    AgentWriteStrictJsonSchemaInner(B, AReq.ResponseSchemaJson);
    B.EndObject;
    B.EndObject;
  end;

  if AStream then
  begin
    B.Key('stream');
    B.Bool(True);
    B.Key('stream_options');
    B.BeginObject;
    B.Key('include_usage');
    B.Bool(True);
    B.EndObject;
  end;

  WriteExtraFields(B, AReq.ExtraJson,
    ['model', 'messages', 'max_tokens', 'max_completion_tokens',
     'temperature', 'top_p', 'seed', 'stop', 'parallel_tool_calls',
     'tools', 'tool_choice', 'response_format', 'reasoning_effort',
     'stream', 'stream_options']);

  B.EndObject;
  Result := B.ToString;
end;

end.
