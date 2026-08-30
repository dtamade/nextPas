{**
 * nextpas.core.agent.provider.openai.responses.encode - Responses 编码子域。
 *
 * 职责：Responses 请求体的纯函数编码（WIRE-MAPPINGS §3.1），
 * 含 instructions 合并（Q-R7）、input 数组展开（user/assistant/tool
 * 三角色，Q-R3 平铺 function_call/output）、tools 平铺 + strict、
 * tool_choice 四形态、reasoning.effort、text.format（Q-R6）、
 * temperature/top_p/seed/parallel_tool_calls 及 stream 标志。
 * 零 IO，零状态。
 *
 * 属 provider.openai.responses 四象限拆分之一（encode），与
 * decode/decoder/facade 互不循环，仅向下依赖 base/errors/intf/common/json。
 *}

unit nextpas.core.agent.provider.openai.responses.encode;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.agent.base,
  nextpas.core.agent.intf;

function EncodeResponsesRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText;

implementation

uses
  nextpas.core.json,
  nextpas.core.json.builder,
  nextpas.core.text.builder,
  nextpas.core.agent.errors,
  nextpas.core.agent.provider.common;

{ 顶层 System + 历史 mrSystem 合并去重为 instructions（§0 确定性规则；
  Q-R7：全局前缀单落点，input 内不再重复注入 system 角色）}
function BuildInstructions(const AReq: TCompletionRequest): string;
begin
  Result := AgentBuildSystemText(AReq.System, AReq.Messages);
end;

{ user 消息 content 数组：文本/图片混排（pkThinking 不回喂——响应侧字段）}
procedure WriteUserContent(ABld: IJsonBuilder; const M: TMessage);
var
  J: Integer;
  LHasImage: Boolean;
  P: TPart;
begin
  LHasImage := False;
  for J := 0 to High(M.Parts) do
    if M.Parts[J].Kind = pkImage then
      LHasImage := True;
  ABld.Key('content');
  if not LHasImage then
  begin
    ABld.Str(MessageText(M));
    Exit;
  end;
  ABld.BeginArray;
  for J := 0 to High(M.Parts) do
  begin
    P := M.Parts[J];
    if P.Kind = pkText then
    begin
      ABld.BeginObject;
      ABld.Key('type');
      ABld.Str('input_text');
      ABld.Key('text');
      ABld.Str(P.Text);
      ABld.EndObject;
    end
    else if P.Kind = pkImage then
    begin
      ABld.BeginObject;
      ABld.Key('type');
      ABld.Str('input_image');
      ABld.Key('image_url');
      ABld.Str(P.ImageUrl);
      ABld.EndObject;
    end;
  end;
  ABld.EndArray;
end;

procedure WriteInputItems(ABld: IJsonBuilder; const AReq: TCompletionRequest);
var
  I, J: Integer;
  M: TMessage;
  P: TPart;
  LText: string;
begin
  ABld.Key('input');
  ABld.BeginArray;
  for I := 0 to High(AReq.Messages) do
  begin
    M := AReq.Messages[I];
    case M.Role of
      mrSystem:
        Continue;

      mrUser:
        begin
          ABld.BeginObject;
          ABld.Key('role');
          ABld.Str('user');
          WriteUserContent(ABld, M);
          WriteExtraFields(ABld, M.ExtraJson, ['role', 'content']);
          ABld.EndObject;
        end;

      mrAssistant:
        begin
          LText := '';
          for J := 0 to High(M.Parts) do
            if M.Parts[J].Kind = pkText then
              LText := LText + M.Parts[J].Text;
          if LText <> '' then
          begin
            ABld.BeginObject;
            ABld.Key('role');
            ABld.Str('assistant');
            ABld.Key('content');
            ABld.BeginArray;
            ABld.BeginObject;
            ABld.Key('type');
            ABld.Str('output_text');
            ABld.Key('text');
            ABld.Str(LText);
            ABld.EndObject;
            ABld.EndArray;
            WriteExtraFields(ABld, M.ExtraJson, ['role', 'content']);
            ABld.EndObject;
          end;
          for J := 0 to High(M.Parts) do
          begin
            P := M.Parts[J];
            if P.Kind <> pkToolCall then
              Continue;
            ABld.BeginObject;
            ABld.Key('type');
            ABld.Str('function_call');
            ABld.Key('call_id');
            ABld.Str(P.ToolCallId);
            ABld.Key('name');
            ABld.Str(P.ToolName);
            ABld.Key('arguments');
            ABld.Str(P.ArgumentsJson);
            WriteExtraFields(ABld, P.ExtraJson,
              ['type', 'call_id', 'name', 'arguments']);
            ABld.EndObject;
          end;
          if (LText = '') and (M.ExtraJson <> '') then
          begin
            ABld.BeginObject;
            ABld.Key('role');
            ABld.Str('assistant');
            ABld.Key('content');
            ABld.BeginArray;
            ABld.BeginObject;
            ABld.Key('type');
            ABld.Str('output_text');
            ABld.Key('text');
            ABld.Str('');
            ABld.EndObject;
            ABld.EndArray;
            WriteExtraFields(ABld, M.ExtraJson, ['role', 'content']);
            ABld.EndObject;
          end;
        end;

      mrTool:
        begin
          for J := 0 to High(M.Parts) do
          begin
            P := M.Parts[J];
            if P.Kind <> pkToolResult then
              Continue;
            ABld.BeginObject;
            ABld.Key('type');
            ABld.Str('function_call_output');
            ABld.Key('call_id');
            ABld.Str(P.ToolCallId);
            ABld.Key('output');
            ABld.Str(P.ResultJson);
            WriteExtraFields(ABld, M.ExtraJson,
              ['type', 'call_id', 'output']);
            ABld.EndObject;
          end;
        end;
    end;
  end;
  ABld.EndArray;
end;

function EncodeResponsesRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText;
var
  B: IJsonBuilder;
  I: Integer;
  LInstr: string;
begin
  AgentValidateResponseSchemaIsObject(AReq.ResponseSchemaJson, 'openai.responses');
  AgentValidateModelNotEmpty(AReq.Model, 'openai.responses');
  AgentValidateToolChoice(AReq, 'openai.responses');
  AgentValidateExtraJson(AReq.ExtraJson, 'openai.responses');

  B := JsonBuilder;
  B.BeginObject;
  B.Key('model');
  B.Str(AReq.Model);

  LInstr := BuildInstructions(AReq);
  if LInstr <> '' then
  begin
    B.Key('instructions');
    B.Str(LInstr);
  end;

  WriteInputItems(B, AReq);

  if AReq.MaxTokens > CMaxTokensUnset then
  begin
    B.Key('max_output_tokens');
    B.Int(AReq.MaxTokens);
  end;
  AgentWriteTemperature(B, AReq.Temperature);
  AgentWriteTopP(B, AReq.TopP);
  AgentWriteSeed(B, AReq.Seed);
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
      AgentWriteToolCommonFields(B, AReq.Tools[I]);
      B.Key('strict');
      B.Bool(True);
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
        B.Key('name');
        B.Str(AReq.ToolChoiceName);
        B.EndObject;
      end;
    tcmUnset:
      ;
  end;

  if AgentReasoningEffortToStr(AReq.ReasoningEffort) <> '' then
  begin
    B.Key('reasoning');
    B.BeginObject;
    B.Key('effort');
    B.Str(AgentReasoningEffortToStr(AReq.ReasoningEffort));
    B.EndObject;
  end;

  if AReq.ResponseSchemaJson <> '' then
  begin
    B.Key('text');
    B.BeginObject;
    B.Key('format');
    B.BeginObject;
    B.Key('type');
    B.Str('json_schema');
    AgentWriteStrictJsonSchemaInner(B, AReq.ResponseSchemaJson);
    B.EndObject;
    B.EndObject;
  end;

  if AStream then
  begin
    B.Key('stream');
    B.Bool(True);
  end;

  WriteExtraFields(B, AReq.ExtraJson,
    ['model', 'instructions', 'input', 'max_output_tokens',
     'temperature', 'top_p', 'seed', 'parallel_tool_calls',
     'tools', 'tool_choice', 'reasoning', 'text', 'stream']);

  B.EndObject;
  Result := B.ToString;
end;

end.
