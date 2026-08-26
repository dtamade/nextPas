(*
 * nextpas.core.agent.provider.openai.responses - OpenAI Responses 适配器。
 *
 * 契约权威：WIRE-MAPPINGS §3（唯一映射真相源）、API.md §8。第三协议支柱：
 * 与 Chat Completions 共享公共规则（§0）但请求/响应/SSE 三面形态均不同。
 * 怪癖落点：Q-R1（无 stop 参数，provider 层忽略+warn）、Q-R2（SSE event 名
 * 为主键）、Q-R3（function 定义与调用项平铺、id 叫 call_id）、Q-R4（usage
 * 字段名差异）、Q-R5（截断流 fail-closed）、Q-R6（structured output 走
 * text.format）。
 *
 * 编解码器公开即免费（D13）：与 provider 工厂共用同一实现。编码器纯函数；
 * 解码器实例单角色独占。未映射枚举值零值 + agent.unmapped.* 捕获 + warn。
 *)

unit nextpas.core.agent.provider.openai.responses;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.async.cancellation,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.provider.openai;

{ BaseUrl 拼接（同 §0 规则）：去尾 '/'；已含 '/v1' 结尾则只追加 /responses，
  否则追加完整默认路径（支持反代前缀部署）。公开便于测试 }
function BuildResponsesUrl(const ABaseUrl: string): string;

{ ---- 纯编解码器（D13 公开表面；只认 WIRE-MAPPINGS §3）---- }

function EncodeResponsesRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText;

procedure DecodeResponsesResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger = nil);

function NewResponsesWireDecoder(
  const ALog: ILogger = nil): IAgentWireDecoder;

{ ---- provider 工厂 ---- }
{ 端点/凭据环境变量与 Chat Completions 同族（NEXTPAS_AGENT_OPENAI_*）：
  同一供应商同一把 key，仅 wire 方言不同 }

function NewOpenAIResponsesProvider(
  const AOpts: TOpenAIOptions): IAgentProvider;
function NewOpenAIResponsesProviderFromEnv: IAgentProvider;

implementation

uses
  nextpas.core.json,
  nextpas.core.json.builder,
  nextpas.core.text.builder,
  nextpas.core.os.env,
  nextpas.core.agent.transport.http,
  nextpas.core.agent.provider.common;

const
  { 已映射字段黑名单：捕获时跳过；未列出的键一律无损进 ExtraJson }
  CKNOWN_ROOT: array[0..5] of string = ('id', 'object', 'model', 'status',
    'usage', 'error');
  CKNOWN_ITEM: array[0..5] of string = ('type', 'id', 'role', 'content',
    'name', 'call_id');
  { function_call 项的 arguments 单列（内容大）；summary 项整体已知 }
  CKNOWN_FCITEM: array[0..4] of string = ('type', 'id', 'call_id', 'name',
    'arguments');
  CKNOWN_CONTENT: array[0..2] of string = ('type', 'text', 'annotations');
  { SSE 事件 data 根对象的已知键（其余键无损捕获）}
  CKNOWN_EVENT: array[0..4] of string = ('type', 'item', 'item_id',
    'delta', 'response');

  CAGENT_UNMAPPED_STATUS = 'agent.unmapped.response_status';
  CAGENT_UNMAPPED_INCOMPLETE = 'agent.unmapped.incomplete_reason';

procedure WarnLog(const ALog: ILogger; const AMsg: string);
begin
  if ALog <> nil then
    ALog.Warn(AMsg);
end;

procedure ProtocolError(const ABodySrc: string; const AMsg: string);
var
  E: EAgentError;
begin
  E := EAgentError.CreateLocal(aecProtocol, 'openai.responses: ' + AMsg);
  E.RawBodySnippet := Utf8SafeTruncate(ABodySrc, CMaxRawBodySnippetBytes);
  raise E;
end;

function JoinRUrl(const ABaseUrl: string): string;
var
  LBase: string;
begin
  LBase := ABaseUrl;
  if LBase = '' then
    LBase := COPENAI_DEFAULT_BASE_URL;
  while (LBase <> '') and (LBase[Length(LBase)] = '/') do
    Delete(LBase, Length(LBase), 1);
  if (Length(LBase) >= 3) and
    (Copy(LBase, Length(LBase) - 2, 3) = '/v1') then
    Result := LBase + '/responses'
  else
    Result := LBase + '/v1/responses';
end;

function BuildResponsesUrl(const ABaseUrl: string): string;
begin
  Result := JoinRUrl(ABaseUrl);
end;

procedure AddPart(var AParts: TPartArray; AKind: TPartKind);
var
  N: Integer;
begin
  N := Length(AParts);
  SetLength(AParts, N + 1);
  AParts[N] := Default(TPart);
  AParts[N].Kind := AKind;
end;

{ usage 字段填充（Q-R4）：字段名与 chat completions 不同；
  缺失字段保持 CUsageUnknown 绝不读成零 }
procedure FillUsageResponses(const AV: TJsonValue; out AU: TTokenUsage);
var
  LD: TJsonValue;
begin
  AU := Default(TTokenUsage);
  AU.InputTokens := CUsageUnknown;
  AU.OutputTokens := CUsageUnknown;
  AU.CacheReadInputTokens := CUsageUnknown;
  AU.CacheWriteInputTokens := CUsageUnknown;
  AU.ReasoningTokens := CUsageUnknown;
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

{ ---- 编码：input 数组展开 ---- }

{ 顶层 System + 历史 mrSystem 合并去重为 instructions（§0 确定性规则；
  Q-R7：全局前缀单落点，input 内不再重复注入 system 角色）}
function BuildInstructions(const AReq: TCompletionRequest): string;
var
  I: Integer;
  LSysParts: array of string;
  LSeen: Boolean;
  LBuf: IStringBuilder;

  procedure NoteSys(const ATxt: string);
  var
    K: Integer;
  begin
    if ATxt = '' then
      Exit;
    LSeen := False;
    for K := 0 to High(LSysParts) do
      if LSysParts[K] = ATxt then
      begin
        LSeen := True;
        Break;
      end;
    if not LSeen then
    begin
      SetLength(LSysParts, Length(LSysParts) + 1);
      LSysParts[High(LSysParts)] := ATxt;
    end;
  end;

begin
  SetLength(LSysParts, 0);
  NoteSys(AReq.System);
  for I := 0 to High(AReq.Messages) do
    if AReq.Messages[I].Role = mrSystem then
      NoteSys(MessageText(AReq.Messages[I]));
  if Length(LSysParts) = 0 then
    Exit('');
  LBuf := MakeStringBuilder;
  for I := 0 to High(LSysParts) do
  begin
    if I > 0 then
      LBuf.AppendStr(#10#10);
    LBuf.AppendStr(LSysParts[I]);
  end;
  Result := LBuf.ToString;
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
      ABld.Str('input_image');       { 平铺 image_url（异于 chat 版包装）}
      ABld.Key('image_url');
      ABld.Str(P.ImageUrl);          { URL / data URI 均直传 }
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
        Continue;                      { 已并入 instructions }

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
            { 文本回填走 assistant/output_text 形态 }
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
          { Q-R3：历史轮工具调用以平铺 function_call 项回放（不嵌消息内）；
            call_id 用词表 ToolCallId 承载的上游原始 id }
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
            { 无正文纯 Extra 的罕见形态：降级为最小 assistant 项承接 }
            ABld.BeginObject;
            ABld.Key('role');
            ABld.Str('assistant');
            ABld.Key('content');
            ABld.Str('');
            WriteExtraFields(ABld, M.ExtraJson, ['role', 'content']);
            ABld.EndObject;
          end;
        end;

      mrTool:
        begin
          { 每个结果部件一项 function_call_output；IsError 无 wire 形态，
            错误语义由 loop 合成进结果内容本身 }
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
  LSchema: IJsonDocument;
  LInstr: string;
begin
  { §3.1/Q-R6：schema 须为合法 JSON object，违者本地 aecConfig 不发网 }
  if AReq.ResponseSchemaJson <> '' then
  begin
    LSchema := JsonParse(AReq.ResponseSchemaJson);
    if (LSchema = nil) or LSchema.HasError or (not LSchema.Root.IsObject) then
      raise EAgentError.CreateLocal(aecConfig,
        'openai.responses: ResponseSchemaJson must be a JSON object');
  end;
  if AReq.Model = '' then
    raise EAgentError.CreateLocal(aecConfig,
      'openai.responses: model is required');
  if (AReq.ToolChoice <> tcmUnset) and (Length(AReq.Tools) = 0) then
    raise EAgentError.CreateLocal(aecConfig,
      'openai.responses: ToolChoice requires a non-empty Tools array');

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
  { Temperature/TopP sentinel 为 -2.0，合法域 [0,2]，>=0 即有效 }
  if AReq.Temperature >= 0 then
  begin
    B.Key('temperature');
    B.Float(AReq.Temperature);
  end;
  if AReq.TopP >= 0 then
  begin
    B.Key('top_p');
    B.Float(AReq.TopP);
  end;
  if AReq.Seed <> CSeedUnset then
  begin
    B.Key('seed');
    B.Int(AReq.Seed);
  end;
  { Q-R1：StopSequences 在 Responses 无对应参数——编码侧不上送，
    provider 层 warn（对齐 anthropic ReasoningEffort 待遇先例）}
  if AReq.ParallelToolCalls <> tsUnset then
  begin
    B.Key('parallel_tool_calls');
    B.Bool(AReq.ParallelToolCalls = tsTrue);
  end;

  { Tools（Q-R3）：function 定义平铺；strict 直译 chat 版 json_schema 行为 }
  if Length(AReq.Tools) > 0 then
  begin
    B.Key('tools');
    B.BeginArray;
    for I := 0 to High(AReq.Tools) do
    begin
      B.BeginObject;
      B.Key('type');
      B.Str('function');
      B.Key('name');
      B.Str(AReq.Tools[I].Name);
      if AReq.Tools[I].Description <> '' then
      begin
        B.Key('description');
        B.Str(AReq.Tools[I].Description);
      end;
      B.Key('parameters');
      if AReq.Tools[I].ParametersJson <> '' then
        B.RawJson(AReq.Tools[I].ParametersJson)
      else
        B.RawJson('{}');
      B.Key('strict');
      B.Bool(True);
      B.EndObject;
    end;
    B.EndArray;
  end;

  { ToolChoice 四形态直映（named 缺名本地 aecConfig）}
  case AReq.ToolChoice of
    tcmAuto:
      begin
        B.Key('tool_choice');
        B.Str('auto');
      end;
    tcmNone:
      begin
        B.Key('tool_choice');
        B.Str('none');
      end;
    tcmRequired:
      begin
        B.Key('tool_choice');
        B.Str('required');
      end;
    tcmNamed:
      begin
        if AReq.ToolChoiceName = '' then
          raise EAgentError.CreateLocal(aecConfig,
            'openai.responses: ToolChoice=tcmNamed requires ToolChoiceName');
        B.Key('tool_choice');
        B.BeginObject;
        B.Key('type');
        B.Str('function');
        B.Key('name');
        B.Str(AReq.ToolChoiceName);
        B.EndObject;
      end;
    tcmUnset:
      ;                        { 不上送（哨兵纪律）}
  end;

  { ReasoningEffort → reasoning.effort（reUnset 整字段省略）}
  case AReq.ReasoningEffort of
    reMinimal:
      begin
        B.Key('reasoning');
        B.BeginObject;
        B.Key('effort');
        B.Str('minimal');
        B.EndObject;
      end;
    reLow:
      begin
        B.Key('reasoning');
        B.BeginObject;
        B.Key('effort');
        B.Str('low');
        B.EndObject;
      end;
    reMedium:
      begin
        B.Key('reasoning');
        B.BeginObject;
        B.Key('effort');
        B.Str('medium');
        B.EndObject;
      end;
    reHigh:
      begin
        B.Key('reasoning');
        B.BeginObject;
        B.Key('effort');
        B.Str('high');
        B.EndObject;
      end;
    reUnset:
      ;                        { 不上送（哨兵纪律）}
  end;

  { ResponseSchemaJson（Q-R6）：structured output 走 text.format 而非
    response_format；strict 语义一致 }
  if AReq.ResponseSchemaJson <> '' then
  begin
    B.Key('text');
    B.BeginObject;
    B.Key('format');
    B.BeginObject;
    B.Key('type');
    B.Str('json_schema');
    B.Key('name');
    B.Str('response');
    B.Key('strict');
    B.Bool(True);
    B.Key('schema');
    B.RawJson(AReq.ResponseSchemaJson);
    B.EndObject;
    B.EndObject;
  end;

  { Thinking/ThinkingBudgetTokens：扩展思考的显式开关在 Responses 属
    reasoning effort 域之外的服务端能力，v1 忽略——词表无 wire 目标不上送 }

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

{ ---- 解码：非流式响应 ---- }

{ output 项展开：message 文本/reasoning 思考/function_call 工具槽；
  返回是否出现 function_call 项（finish 推导用）}
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
          { refusal 已知但 v1 无词表落点：Extra 保真（CKNOWN_CONTENT 外）}
        end;
      end;
      AMsg.ExtraJson := MergeExtraJson([AMsg.ExtraJson,
        CaptureExtraJson(LItem, CKNOWN_ITEM, CMaxExtraKeys, ALog)]);
    end
    else if LTyp = 'reasoning' then
    begin
      { summary[] 拼 thinking part（词表落点 pkThinking）}
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
      { 内建工具项（web_search 等）/未知类型：v1 词表外，整项 Extra 保真 }
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

  { 根级 error 信封（status=failed 或独立 error 对象）：归因上游业务失败，
    不是协议违例——按 §0 分类器语义合成 aecServer 上抛 }
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

  { finish 推导（Responses 无显式 finish_reason）：
    有 function_call 项 → frToolCalls（对齐 chat 版生产怪癖规则）；
    status=incomplete（典型 max_output_tokens 截断）→ frLength；
    其余 completed → frStop；未知 status 记 unmapped 并按 frStop 收口 }
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

{ ---- 解码：流帧归约（WIRE-MAPPINGS §3.3）---- }

type
  { 事件名主键状态机（Q-R2）：created 强制首信封、item_id→槽位映射、
    created→终态轨迹校验（Q-R5 fail-closed）。单角色独占 }
  TResponsesWireDecoder = class(TInterfacedObject, IAgentWireDecoder)
  private
    FLog: ILogger;
    FSawEnvelope: Boolean;
    FTerminal: Boolean;              { completed/failed/error/incomplete 见过 }
    FFinalized: Boolean;
    FPool: TWireToolSlotPool;
    FIds: array of record
      ItemId: string;
      Slot: Integer;
    end;
    FPendingUnmapped: TJsonText;
    function SlotFor(const AItemId: string): Integer;
    procedure HandleItemAdded(const ARoot: TJsonValue;
      const ASrc: string; var ADeltas: TStreamDeltaArray);
    procedure HandleArgsDelta(const ARoot: TJsonValue;
      const ASrc: string; var ADeltas: TStreamDeltaArray);
    procedure HandleItemDone(const ARoot: TJsonValue;
      const ASrc: string; var ADeltas: TStreamDeltaArray);
    procedure EmitError(const AErrObj: TJsonValue; const ASrc: string;
      var ADeltas: TStreamDeltaArray);
  public
    constructor Create(const ALog: ILogger);
    destructor Destroy; override;
    procedure DecodeEvent(const AEvent: TWireSSEEvent;
      out ADeltas: TStreamDeltaArray);
    procedure Finalize(out ADeltas: TStreamDeltaArray);
  end;

constructor TResponsesWireDecoder.Create(const ALog: ILogger);
begin
  inherited Create;
  FLog := ALog;
  FPool := TWireToolSlotPool.Create;
end;

destructor TResponsesWireDecoder.Destroy;
begin
  FPool.Free;
  inherited Destroy;
end;

{ item_id 字符串 → 整数槽位（TWireToolSlotPool 以整数分桶）：
  未见过即顺序分配新槽；重复 item_id 宽容返回既有槽（平铺流幂等防御）}
function TResponsesWireDecoder.SlotFor(const AItemId: string): Integer;
var
  I: Integer;
  LCreated: Boolean;
begin
  for I := 0 to High(FIds) do
    if FIds[I].ItemId = AItemId then
      Exit(FIds[I].Slot);
  Result := FPool.Count;             { 新槽 index = 当前槽总数 }
  FPool.Find(Result, LCreated);
  SetLength(FIds, Length(FIds) + 1);
  FIds[High(FIds)].ItemId := AItemId;
  FIds[High(FIds)].Slot := Result;
end;

{ response.output_item.added：function_call 项注册身份并尽早宣告；
  message/reasoning 项信封已发，静默 }
procedure TResponsesWireDecoder.HandleItemAdded(const ARoot: TJsonValue;
  const ASrc: string; var ADeltas: TStreamDeltaArray);
var
  LItem: TJsonValue;
  LTyp, LItemId, LCallId, LName: string;
  LSlot: Integer;
begin
  LItem := ARoot.Get('item');
  if not LItem.IsObject then
    ProtocolError(ASrc, 'output_item.added requires item object');
  LTyp := '';
  if LItem.Get('type').IsStr then
    LTyp := LItem.Get('type').AsStr.ToString;
  if LTyp <> 'function_call' then
    Exit;
  LItemId := '';
  LCallId := '';
  LName := '';
  if LItem.Get('id').IsStr then
    LItemId := LItem.Get('id').AsStr.ToString;
  if LItem.Get('call_id').IsStr then
    LCallId := LItem.Get('call_id').AsStr.ToString;
  if LItem.Get('name').IsStr then
    LName := LItem.Get('name').AsStr.ToString;
  if (LItemId = '') and (LCallId = '') then
    ProtocolError(ASrc, 'function_call item requires id or call_id');
  if LItemId = '' then
    LItemId := LCallId;              { 兼容实现缺 id 时以 call_id 代槽键 }
  LSlot := SlotFor(LItemId);
  { 身份：优先 call_id（词表 ToolCallId 回喂 loop 的就是它），缺则 item.id }
  FPool.UpdateIdentity(LSlot, LCallId, LName);
  if FPool.HasName[LSlot] and (not FPool.Announced[LSlot]) then
    FPool.Announce(LSlot, ADeltas);
end;

{ response.function_call_arguments.delta：按 item_id 分桶累积 }
procedure TResponsesWireDecoder.HandleArgsDelta(const ARoot: TJsonValue;
  const ASrc: string; var ADeltas: TStreamDeltaArray);
var
  LDeltaV: TJsonValue;
  LItemId, LArgs: string;
  LSlot: Integer;
  LD: TStreamDelta;
begin
  LItemId := '';
  if ARoot.Get('item_id').IsStr then
    LItemId := ARoot.Get('item_id').AsStr.ToString;
  if LItemId = '' then
    ProtocolError(ASrc, 'arguments.delta requires item_id');
  LDeltaV := ARoot.Get('delta');
  if not LDeltaV.IsStr then
    ProtocolError(ASrc, 'arguments.delta requires string delta');
  LArgs := LDeltaV.AsStr.ToString;
  LSlot := SlotFor(LItemId);
  if FPool.Announced[LSlot] then
  begin
    LD := Default(TStreamDelta);
    LD.Kind := sdkToolCallDelta;
    LD.ToolIndex := LSlot;
    LD.ArgumentsDelta := LArgs;
    AddStreamDelta(ADeltas, LD);
  end
  else
    FPool.AppendArgs(LSlot, LArgs);  { 未宣告：缓冲至 name 就绪 }
end;

{ response.output_item.done(function_call)：兜底——delta 全跳的兼容流
  在此以完整 arguments 补齐宣告；已宣告槽依 §0 投递不重复原则放弃
  done 补齐（分桶 delta 流已保证完整性，直出完整串会造成重复投递）}
procedure TResponsesWireDecoder.HandleItemDone(const ARoot: TJsonValue;
  const ASrc: string; var ADeltas: TStreamDeltaArray);
var
  LItem: TJsonValue;
  LTyp, LItemId, LCallId, LName, LArgs: string;
  LSlot: Integer;
begin
  LItem := ARoot.Get('item');
  if not LItem.IsObject then
    Exit;
  LTyp := '';
  if LItem.Get('type').IsStr then
    LTyp := LItem.Get('type').AsStr.ToString;
  if LTyp <> 'function_call' then
    Exit;
  LItemId := '';
  LCallId := '';
  LName := '';
  LArgs := '';
  if LItem.Get('id').IsStr then
    LItemId := LItem.Get('id').AsStr.ToString;
  if LItem.Get('call_id').IsStr then
    LCallId := LItem.Get('call_id').AsStr.ToString;
  if LItem.Get('name').IsStr then
    LName := LItem.Get('name').AsStr.ToString;
  if LItem.Get('arguments').IsStr then
    LArgs := LItem.Get('arguments').AsStr.ToString;
  if LItemId = '' then
    LItemId := LCallId;
  if LItemId = '' then
    Exit;
  LSlot := SlotFor(LItemId);
  FPool.UpdateIdentity(LSlot, LCallId, LName);
  if not FPool.Announced[LSlot] then
  begin
    if LArgs <> '' then
      FPool.AppendArgs(LSlot, LArgs);
    if FPool.HasName[LSlot] then
      FPool.Announce(LSlot, ADeltas);
  end;
end;

{ response.failed / response.error：流中失败上浮（§0 流中途错误规则；
  错误体形态对齐 §3.2 根级 error）}
procedure TResponsesWireDecoder.EmitError(const AErrObj: TJsonValue;
  const ASrc: string; var ADeltas: TStreamDeltaArray);
var
  LD: TStreamDelta;
  LCode, LMsg: string;
begin
  if not AErrObj.IsObject then
    ProtocolError(ASrc, 'error event requires error object');
  LCode := '';
  LMsg := '';
  if AErrObj.Get('code').IsStr then
    LCode := AErrObj.Get('code').AsStr.ToString;
  if AErrObj.Get('message').IsStr then
    LMsg := AErrObj.Get('message').AsStr.ToString;
  LD := Default(TStreamDelta);
  LD.Kind := sdkError;
  if LCode = 'rate_limit_exceeded' then
    LD.Error.Code := aecRateLimited
  else if LCode = 'context_length_exceeded' then
    LD.Error.Code := aecContextOverflow
  else if LCode = 'invalid_request_error' then
    LD.Error.Code := aecInvalidRequest
  else
    LD.Error.Code := aecServer;
  LD.Error.Message := LMsg;
  if LCode <> '' then
    LD.Error.Message := '[' + LCode + '] ' + LD.Error.Message;
  LD.Error.Retryable := IsRetryable(LD.Error.Code);
  LD.Error.RetryAfterMs := CRetryAfterUnknown;
  AddStreamDelta(ADeltas, LD);
end;

procedure TResponsesWireDecoder.DecodeEvent(const AEvent: TWireSSEEvent;
  out ADeltas: TStreamDeltaArray);
var
  Doc: IJsonDocument;
  Root, LRsp, LU: TJsonValue;
  LD: TStreamDelta;
  LId, LModel, LEv, LDeltaTxt, LCapture: string;

  function AttachPending(const AExisting: string): string;
  begin
    if FPendingUnmapped = '' then
      Exit(AExisting);
    Result := MergeExtraJson([AExisting, FPendingUnmapped]);
    FPendingUnmapped := '';
  end;

begin
  ADeltas := nil;
  if FFinalized then
    raise EAgentMisuse.Create('responses decoder reused after Finalize');
  LEv := AEvent.Event;               { Q-R2：event 名为主键 }
  if (LEv = '') or (LEv = 'ping') then
  begin
    { 无 event 名或心跳帧：尝试 data JSON 兜底解析（兼容实现可能省略
      event 行——按 data 内 type 字段二次分派）}
    if AEvent.Data = '[DONE]' then
    begin
      FTerminal := True;             { 部分代理以 [DONE] 收口 }
      Exit;
    end;
  end;

  Doc := JsonParse(AEvent.Data);
  if Doc.HasError or (not Doc.Root.IsObject) then
    ProtocolError(AEvent.Data, 'stream payload must be a JSON object');
  Root := Doc.Root;

  { data.type 二次分派（event 名缺失/不一致的兼容容错）：官方响应对象
    带 type:"response.*"；直接采 data.type 优先级低于 event 名 }
  if LEv = '' then
  begin
    if Root.Get('type').IsStr then
      LEv := Root.Get('type').AsStr.ToString;
  end;

  if LEv = 'response.created' then
  begin
    if FSawEnvelope then
      Exit;                          { 重复 created 宽容忽略 }
    LRsp := Root.Get('response');
    LId := '';
    LModel := '';
    if LRsp.IsObject then
    begin
      if LRsp.Get('id').IsStr then
        LId := LRsp.Get('id').AsStr.ToString;
      if LRsp.Get('model').IsStr then
        LModel := LRsp.Get('model').AsStr.ToString;
    end;
    LD := Default(TStreamDelta);
    LD.Kind := sdkEnvelope;
    LD.MessageId := LId;
    LD.Model := LModel;
    AddStreamDelta(ADeltas, LD);
    FSawEnvelope := True;
    Exit;
  end;

  if LEv = 'response.output_text.delta' then
  begin
    LDeltaTxt := '';
    if Root.Get('delta').IsStr then
      LDeltaTxt := Root.Get('delta').AsStr.ToString;
    if LDeltaTxt <> '' then
    begin
      LD := Default(TStreamDelta);
      LD.Kind := sdkTextDelta;
      LD.TextDelta := LDeltaTxt;
      AddStreamDelta(ADeltas, LD);
    end;
  end
  else if LEv = 'response.reasoning_summary_text.delta' then
  begin
    LDeltaTxt := '';
    if Root.Get('delta').IsStr then
      LDeltaTxt := Root.Get('delta').AsStr.ToString;
    if LDeltaTxt <> '' then
    begin
      LD := Default(TStreamDelta);
      LD.Kind := sdkThinkingDelta;
      LD.TextDelta := LDeltaTxt;
      AddStreamDelta(ADeltas, LD);
    end;
  end
  else if LEv = 'response.output_item.added' then
    HandleItemAdded(Root, AEvent.Data, ADeltas)
  else if LEv = 'response.function_call_arguments.delta' then
    HandleArgsDelta(Root, AEvent.Data, ADeltas)
  else if LEv = 'response.output_item.done' then
    HandleItemDone(Root, AEvent.Data, ADeltas)
  else if (LEv = 'response.completed') or (LEv = 'response.incomplete') then
  begin
    LRsp := Root.Get('response');
    if LRsp.IsObject then
    begin
      LU := LRsp.Get('usage');
      if LU.IsObject then
      begin
        LD := Default(TStreamDelta);
        LD.Kind := sdkUsage;
        FillUsageResponses(LU, LD.Usage);
        AddStreamDelta(ADeltas, LD);
      end;
    end;
    LD := Default(TStreamDelta);
    LD.Kind := sdkFinish;
    if LEv = 'response.incomplete' then
      LD.FinishReason := frLength
    else
      LD.FinishReason := frStop;
    { 生产怪癖（对齐 chat 版）：completed 却已开工具槽 → frToolCalls，
      保住消费方循环判据 }
    if (LD.FinishReason = frStop) and (FPool.Count > 0) then
      LD.FinishReason := frToolCalls;
    AddStreamDelta(ADeltas, LD);
    FTerminal := True;
  end
  else if (LEv = 'response.failed') or (LEv = 'response.error') then
  begin
    if LEv = 'response.failed' then
    begin
      LRsp := Root.Get('response');
      if LRsp.IsObject then
        EmitError(LRsp.Get('error'), AEvent.Data, ADeltas)
      else
        EmitError(Root, AEvent.Data, ADeltas);
    end
    else
      EmitError(Root.Get('error'), AEvent.Data, ADeltas);
    FTerminal := True;
  end;
  { 其余事件（in_progress/content_part.*/output_text.done/...）：零增量
    合法帧，静默吞（块级未知键证据照录下方）}

  { 块级未知键无损捕获：挂本帧末个增量；无增量顺延；Finalize 仍无落点
    则降级 warn }
  LCapture := CaptureExtraJson(Root, CKNOWN_EVENT, CMaxExtraKeys, FLog);
  if LCapture <> '' then
  begin
    if Length(ADeltas) > 0 then
      ADeltas[High(ADeltas)].UnmappedJson :=
        MergeExtraJson([ADeltas[High(ADeltas)].UnmappedJson, LCapture])
    else
      FPendingUnmapped := MergeExtraJson([FPendingUnmapped, LCapture]);
  end;
  if Length(ADeltas) > 0 then
    ADeltas[0].UnmappedJson := AttachPending(ADeltas[0].UnmappedJson);
end;

procedure TResponsesWireDecoder.Finalize(out ADeltas: TStreamDeltaArray);
begin
  ADeltas := nil;
  if FFinalized then
    Exit;                              { 幂等：重复调用返回空数组 }
  FFinalized := True;
  { Q-R5 fail-closed：无首信封或未见任何终态事件（completed/incomplete/
    failed/error/[DONE]）即截断流——绝不把残缺答案合成完整消息
    （Q-A8 同精神；对照 chat completions Q-O4 的宽容是各自协议现实）}
  if (not FSawEnvelope) or (not FTerminal) then
    ProtocolError('', 'stream ended without terminal response event ' +
      '(truncated stream)');
  FPool.FlushUnannounced(FLog, 'openai.responses', ADeltas);
  if FPendingUnmapped <> '' then
  begin
    WarnLog(FLog,
      'openai.responses: dropping trailing unmapped keys without carrier');
    FPendingUnmapped := '';
  end;
end;

function NewResponsesWireDecoder(
  const ALog: ILogger): IAgentWireDecoder;
begin
  Result := TResponsesWireDecoder.Create(ALog);
end;

{ ---- provider 与 completion ---- }

type
  TResponsesProvider = class(TInterfacedObject, IAgentProvider)
  private
    FOpts: TOpenAIOptions;
    FTransport: IAgentTransport;
    FLog: ILogger;
    FName: string;
    function ResolveModel(const AReq: TCompletionRequest): string;
    function BuildWireRequest(const AReq: TCompletionRequest;
      AStream: Boolean): TWireRequest;
  public
    constructor Create(const AOpts: TOpenAIOptions;
      const AName: string = 'openai-responses');
    function GetName: string;
    function Complete(const AReq: TCompletionRequest): TMessage; overload;
    function Complete(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): TMessage; overload;
    function Stream(
      const AReq: TCompletionRequest): IAgentCompletion; overload;
    function Stream(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): IAgentCompletion; overload;
  end;

constructor TResponsesProvider.Create(const AOpts: TOpenAIOptions;
  const AName: string);
begin
  inherited Create;
  FOpts := AOpts;
  FName := AName;
  FLog := AOpts.Common.Logger;
  if FOpts.Common.Transport <> nil then
    FTransport := FOpts.Common.Transport
  else
    FTransport := NewHttpTransport(FName);
end;

function TResponsesProvider.GetName: string;
begin
  Result := FName;
end;

function TResponsesProvider.ResolveModel(
  const AReq: TCompletionRequest): string;
begin
  if AReq.Model <> '' then
    Exit(AReq.Model);
  if FOpts.Common.Model <> '' then
    Exit(FOpts.Common.Model);
  raise EAgentError.CreateLocal(aecConfig,
    'openai.responses: model is required ' +
    '(request.Model or options.Common.Model)');
end;

function TResponsesProvider.BuildWireRequest(
  const AReq: TCompletionRequest; AStream: Boolean): TWireRequest;
var
  LReq: TCompletionRequest;
  I, N: Integer;
begin
  if FOpts.Common.ApiKey = '' then
    raise EAgentError.CreateLocal(aecConfig,
      'openai.responses: api key is required (' +
      COPENAI_ENV_API_KEY + ')');
  LReq := AReq;
  LReq.Model := ResolveModel(AReq);
  { Q-R1：StopSequences 无 wire 参数——provider 层 warn 后丢弃
    （编码侧不上送；对齐 anthropic ReasoningEffort 待遇先例）}
  if Length(LReq.StopSequences) > 0 then
    WarnLog(FLog,
      'openai.responses: stop sequences have no wire parameter (Q-R1), ' +
      'ignored');
  LReq.StopSequences := nil;
  Result := Default(TWireRequest);
  Result.Url := BuildResponsesUrl(FOpts.Common.BaseUrl);
  Result.BodyJson := EncodeResponsesRequest(LReq, AStream);
  Result.ReadIdleTimeoutMs := FOpts.Common.ReadIdleTimeoutMs;   { W7 }
  SetLength(Result.Headers, 0);
  N := Length(Result.Headers);
  SetLength(Result.Headers, N + 1);
  Result.Headers[N].Name := 'Authorization';
  Result.Headers[N].Value := 'Bearer ' + FOpts.Common.ApiKey;
  if FOpts.Organization <> '' then
  begin
    N := Length(Result.Headers);
    SetLength(Result.Headers, N + 1);
    Result.Headers[N].Name := 'OpenAI-Organization';
    Result.Headers[N].Value := FOpts.Organization;
  end;
  for I := 0 to High(FOpts.Common.ExtraHeaders) do
  begin
    N := Length(Result.Headers);
    SetLength(Result.Headers, N + 1);
    Result.Headers[N] := FOpts.Common.ExtraHeaders[I];
  end;
  Result.ConnectTimeoutMs := FOpts.Common.ConnectTimeoutMs;
  Result.TotalTimeoutMs := FOpts.Common.TotalTimeoutMs;
end;

function TResponsesProvider.Complete(
  const AReq: TCompletionRequest): TMessage;
var
  LResp: TWireResponse;
begin
  FTransport.RoundTrip(BuildWireRequest(AReq, False), LResp);
  DecodeResponsesResponse(LResp.BodyText, Result, FLog);
end;

function TResponsesProvider.Complete(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): TMessage;
begin
  { 同步 transport 无法中断在途请求：令牌在起止点检查（诚实边界，
    全程取消由 Stream 路径承担）}
  if Assigned(AToken) and AToken.IsCancelled then
    raise EAgentCancelled.Create;
  Result := Complete(AReq);
end;

function TResponsesProvider.Stream(
  const AReq: TCompletionRequest): IAgentCompletion;
begin
  Result := TWireBackedCompletion.Create(
    FTransport.OpenStream(BuildWireRequest(AReq, True)),
    NewResponsesWireDecoder(FLog), nil, FName);
end;

function TResponsesProvider.Stream(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): IAgentCompletion;
begin
  Result := TWireBackedCompletion.Create(
    FTransport.OpenStream(BuildWireRequest(AReq, True)),
    NewResponsesWireDecoder(FLog), AToken, FName);
end;

{ ---- 工厂 ---- }

function NewOpenAIResponsesProvider(
  const AOpts: TOpenAIOptions): IAgentProvider;
begin
  Result := TResponsesProvider.Create(AOpts);
end;

function NewOpenAIResponsesProviderFromEnv: IAgentProvider;
var
  O: TOpenAIOptions;
  LUrl: string;
begin
  O := TOpenAIOptions.New('');
  O.Common.ApiKey := GetEnvironmentVariable(COPENAI_ENV_API_KEY);
  O.Common.Model := GetEnvironmentVariable(COPENAI_ENV_MODEL);
  LUrl := GetEnvironmentVariable(COPENAI_ENV_BASE_URL);
  if LUrl <> '' then
    O.Common.BaseUrl := LUrl;
  { 必填缺失返回 nil，绝不静默回退（CONSUMERS §3）}
  if (O.Common.ApiKey = '') or (O.Common.Model = '') then
    Exit(nil);
  Result := NewOpenAIResponsesProvider(O);
end;

end.
