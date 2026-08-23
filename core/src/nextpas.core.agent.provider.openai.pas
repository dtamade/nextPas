(*
 * nextpas.core.agent.provider.openai - OpenAI Chat Completions 兼容适配器。
 *
 * 契约权威：core/docs/agent/API.md §7/§8、WIRE-MAPPINGS §1（唯一映射真相源）。
 * 怪癖落点：Q-O1（推理族 max_completion_tokens 改名）、Q-O2（reasoning_content
 * → thinking 增量）、Q-O3（必发 stream_options.include_usage）、Q-O4（缺
 * [DONE] 断连=EOF）、Q-O5（tool_calls 首片 Start、按 index 分桶、无 End 事件）、
 * Q-O6（空 choices 中间帧跳过）、Q-O7（多 choice 丢弃 index>0 并 warn）。
 *
 * 编解码器公开即免费（D13）：Encode/Decode/NewWireDecoder 与 provider 工厂
 * 共用同一实现。编码器纯函数可并发；解码器实例单角色独占，不跨消息复用。
 * 未映射枚举值：词表零值 + agent.unmapped.<field> 捕获 + warn，绝不臆造近似。
 *
 * 家族：openai（api.openai.com）与 grok（api.x.ai）共用 Chat Completions
 * wire 方言与编解码器；差异仅默认端点、鉴权归因名与环境变量前缀。
 * Grok 特有怪癖（reasoning 别名、订阅网关 ping 心跳帧）内建于共享解码器，
 * 依据 sub2api 生产经验核对（WIRE-MAPPINGS §1.5/§1.6）。
 *)

unit nextpas.core.agent.provider.openai;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.async.cancellation,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.provider.common;

const
  COPENAI_DEFAULT_BASE_URL = 'https://api.openai.com';
  COPENAI_CONNECT_TIMEOUT_MS = 10000;
  COPENAI_TOTAL_TIMEOUT_MS = 300000;

  { Q-O1：这些前缀的模型拒绝 max_tokens，须改用 max_completion_tokens；
    判定失败由上游 400 自然暴露并归因（常量表可扩展） }
  COPENAI_MAX_COMPLETION_TOKENS_PREFIXES: array[0..2] of string =
    ('o1', 'o3', 'gpt-5');

  { 环境装配（CONSUMERS §3）；必填缺失返回 nil，绝不静默回退 }
  COPENAI_ENV_API_KEY = 'NEXTPAS_AGENT_OPENAI_API_KEY';
  COPENAI_ENV_MODEL = 'NEXTPAS_AGENT_OPENAI_MODEL';
  COPENAI_ENV_BASE_URL = 'NEXTPAS_AGENT_OPENAI_BASE_URL';

  { Grok（xAI）家族：官方 API 为 https://api.x.ai 的 Chat Completions
    方言（sub2api 确认订阅上游同形）；编解码器复用 OpenAI 族实现，
    Grok 特有怪癖（reasoning 别名、ping 心跳帧）已内建于共享解码器 }
  CGROK_DEFAULT_BASE_URL = 'https://api.x.ai';
  CGROK_ENV_API_KEY = 'NEXTPAS_AGENT_GROK_API_KEY';
  CGROK_ENV_MODEL = 'NEXTPAS_AGENT_GROK_MODEL';
  CGROK_ENV_BASE_URL = 'NEXTPAS_AGENT_GROK_BASE_URL';

type
  { API.md §3.1；Common.Model 为回退默认（生效序 request.Model > 本值） }
  TOpenAIOptions = record
    Common: TProviderOptions;
    Organization: string;            { 可选 OpenAI-Organization 头 }
    class function New(const AModel: string): TOpenAIOptions; static;
  end;

  { Grok 家族选项：无 Organization 等额外头；BaseUrl 默认 api.x.ai }
  TGrokOptions = record
    Common: TProviderOptions;
    class function New(const AModel: string): TGrokOptions; static;
  end;

{ ---- 纯编解码器（D13 公开表面；只认 WIRE-MAPPINGS §1）---- }

function EncodeOpenAIRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText;

procedure DecodeOpenAIResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger = nil);

function NewOpenAIWireDecoder(
  const ALog: ILogger = nil): IAgentWireDecoder;

{ BaseUrl 拼接（WIRE-MAPPINGS §0）：去尾 '/'；已含 '/v1' 结尾则只追加
  /chat/completions，否则追加完整默认路径（支持反代前缀部署）。公开便于测试 }
function BuildOpenAIUrl(const ABaseUrl: string): string;

{ ---- provider 工厂（openai 与 grok 两家族共用编解码器实现）---- }

function NewOpenAIProvider(const AOpts: TOpenAIOptions): IAgentProvider;
function NewOpenAIProviderFromEnv: IAgentProvider;

function BuildGrokUrl(const ABaseUrl: string): string;
function NewGrokProvider(const AOpts: TGrokOptions): IAgentProvider;
function NewGrokProviderFromEnv: IAgentProvider;

implementation

uses
  nextpas.core.json,
  nextpas.core.json.builder,
  nextpas.core.text.builder,
  nextpas.core.os.env,
  nextpas.core.agent.fold,
  nextpas.core.agent.transport.http;

const
  { 已映射字段黑名单：捕获时跳过。未列出的键一律无损进 ExtraJson
    （含 refusal/logprobs/annotations 等本适配器 v1 未消费的字段）}
  CKNOWN_ROOT: array[0..3] of string = ('id', 'object', 'choices', 'usage');
  CKNOWN_CHOICE: array[0..2] of string = ('index', 'message', 'finish_reason');
  CKNOWN_MESSAGE: array[0..3] of string =
    ('role', 'content', 'tool_calls', 'reasoning_content');
  CKNOWN_TOOLCALL: array[0..3] of string =
    ('id', 'type', 'function', 'index');
  CKNOWN_FUNCTION: array[0..1] of string = ('name', 'arguments');

  CAGENT_UNMAPPED_FINISH = 'agent.unmapped.finish_reason';

procedure WarnLog(const ALog: ILogger; const AMsg: string);
begin
  if ALog <> nil then
    ALog.Warn(AMsg);
end;

procedure ProtocolError(const ABodySrc: string; const AMsg: string);
var
  E: EAgentError;
begin
  E := EAgentError.CreateLocal(aecProtocol, 'openai: ' + AMsg);
  E.RawBodySnippet := Utf8SafeTruncate(ABodySrc, CMaxRawBodySnippetBytes);
  raise E;
end;

procedure AddDelta(var AArr: TStreamDeltaArray; const AD: TStreamDelta);
var
  N: Integer;
begin
  N := Length(AArr);
  SetLength(AArr, N + 1);
  AArr[N] := AD;
end;

{ Q-O1：模型名前缀判定 }
function UsesMaxCompletionTokens(const AModel: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := Low(COPENAI_MAX_COMPLETION_TOKENS_PREFIXES) to
    High(COPENAI_MAX_COMPLETION_TOKENS_PREFIXES) do
    if Pos(COPENAI_MAX_COMPLETION_TOKENS_PREFIXES[I], AModel) = 1 then
      Exit(True);
end;

{ 四值映射；未映射返回 frNone 并经 AUnmapped 上报原文（绝不臆造近似）}
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

function JoinCCUrl(const ABaseUrl, ADefault: string): string;
var
  LBase: string;
begin
  LBase := ABaseUrl;
  if LBase = '' then
    LBase := ADefault;
  while (LBase <> '') and (LBase[Length(LBase)] = '/') do
    Delete(LBase, Length(LBase), 1);
  if (Length(LBase) >= 3) and
    (Copy(LBase, Length(LBase) - 2, 3) = '/v1') then
    Result := LBase + '/chat/completions'
  else
    Result := LBase + '/v1/chat/completions';
end;

function BuildOpenAIUrl(const ABaseUrl: string): string;
begin
  Result := JoinCCUrl(ABaseUrl, COPENAI_DEFAULT_BASE_URL);
end;

function BuildGrokUrl(const ABaseUrl: string): string;
begin
  Result := JoinCCUrl(ABaseUrl, CGROK_DEFAULT_BASE_URL);
end;

{ usage 字段填充：缺失字段保持 CUsageUnknown，绝不读成零（Q-O3 容忍）}
procedure FillUsage(const AV: TJsonValue; out AU: TTokenUsage);
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
  if AV.Get('prompt_tokens').IsInt then
    AU.InputTokens := AV.Get('prompt_tokens').AsInt;
  if AV.Get('completion_tokens').IsInt then
    AU.OutputTokens := AV.Get('completion_tokens').AsInt;
  LD := AV.Get('completion_tokens_details');
  if LD.IsObject and LD.Get('reasoning_tokens').IsInt then
    AU.ReasoningTokens := LD.Get('reasoning_tokens').AsInt;
  LD := AV.Get('prompt_tokens_details');
  if LD.IsObject and LD.Get('cached_tokens').IsInt then
    AU.CacheReadInputTokens := LD.Get('cached_tokens').AsInt;
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

{ ---- 编码：消息展开 ---- }

{ 顶层 System + 历史 mrSystem 合并去重为单一首条 system 消息
  （WIRE-MAPPINGS §0 确定性规则 + §1.1 合并去重行）}
procedure WriteMessages(ABld: IJsonBuilder; const AReq: TCompletionRequest);
var
  I, J: Integer;
  LSysParts: array of string;
  LSeen: Boolean;
  LSysBuf: IStringBuilder;
  M: TMessage;
  P: TPart;
  LText, LUrl: string;
  LHasImage, LHasToolCalls: Boolean;

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
  ABld.Key('messages');
  ABld.BeginArray;

  SetLength(LSysParts, 0);
  NoteSys(AReq.System);
  for I := 0 to High(AReq.Messages) do
    if AReq.Messages[I].Role = mrSystem then
      NoteSys(MessageText(AReq.Messages[I]));
  if Length(LSysParts) > 0 then
  begin
    LSysBuf := MakeStringBuilder;
    for I := 0 to High(LSysParts) do
    begin
      if I > 0 then
        LSysBuf.AppendStr(#10#10);
      LSysBuf.AppendStr(LSysParts[I]);
    end;
    ABld.BeginObject;
    ABld.Key('role');
    ABld.Str('system');
    ABld.Key('content');
    ABld.Str(LSysBuf.ToString);
    ABld.EndObject;
  end;

  for I := 0 to High(AReq.Messages) do
  begin
    M := AReq.Messages[I];
    case M.Role of
      mrSystem:
        Continue;                      { 已并入首条 system }

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
                ABld.Str(P.ImageUrl);   { URL / data URI 均直传 }
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
          LText := '';
          LHasToolCalls := False;
          for J := 0 to High(M.Parts) do
          begin
            P := M.Parts[J];
            if P.Kind = pkText then
              LText := LText + P.Text
            else if P.Kind = pkToolCall then
              LHasToolCalls := True;
          end;
          { pkThinking 不回喂：reasoning_content 是响应侧字段，兼容端明确
            拒绝请求携带（WIRE-MAPPINGS §1.1 该行仅描述解码方向）}
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
              ABld.Str(P.ArgumentsJson);   { wire 形态是含 JSON 的字符串 }
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
          { 每个 tool result 部件一条独立消息；IsError 无 wire 形态，
            错误语义由 loop 合成进结果内容本身 }
          LUrl := '';                      { 标记 extras 是否已写（首个条目）}
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
  if AReq.ResponseSchemaJson <> '' then
    raise EAgentError.CreateLocal(aecConfig,
      'openai: ResponseSchemaJson requires structured output support ' +
      '(v1.1 roadmap); not accepted by this adapter yet');
  if AReq.Model = '' then
    raise EAgentError.CreateLocal(aecConfig,
      'openai: model is required');

  B := JsonBuilder;
  B.BeginObject;
  B.Key('model');
  B.Str(AReq.Model);

  WriteMessages(B, AReq);

  if AReq.MaxTokens > CMaxTokensUnset then
  begin
    if UsesMaxCompletionTokens(AReq.Model) then
      B.Key('max_completion_tokens')     { Q-O1 }
    else
      B.Key('max_tokens');
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
  if Length(AReq.StopSequences) > 0 then
  begin
    B.Key('stop');
    B.BeginArray;
    for I := 0 to High(AReq.StopSequences) do
      B.Str(AReq.StopSequences[I]);
    B.EndArray;
  end;
  if AReq.ParallelToolCalls <> tsUnset then
  begin
    B.Key('parallel_tool_calls');
    B.Bool(AReq.ParallelToolCalls = tsTrue);
  end;

  { Tools 非空才上送字段（§1.1：空数组不上送）}
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
      B.EndObject;
      B.EndObject;
    end;
    B.EndArray;
  end;

  { Thinking/ThinkingBudgetTokens 无 Chat Completions 对应参数
    （扩展思考在 Responses API），v1 忽略——词表无 wire 目标即不上送 }

  if AStream then
  begin
    B.Key('stream');
    B.Bool(True);
    B.Key('stream_options');             { Q-O3：必发，usage 才随末帧到达 }
    B.BeginObject;
    B.Key('include_usage');
    B.Bool(True);
    B.EndObject;
  end;

  WriteExtraFields(B, AReq.ExtraJson,
    ['model', 'messages', 'max_tokens', 'max_completion_tokens',
     'temperature', 'top_p', 'seed', 'stop', 'parallel_tool_calls',
     'tools', 'stream', 'stream_options']);

  B.EndObject;
  Result := B.ToString;
end;

{ ---- 解码：非流式响应 ---- }

procedure DecodeOpenAIResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger);
var
  Doc: IJsonDocument;
  Root, LChoices, LC0, LM, LT, LItem, LFn: TJsonValue;
  LB: IJsonBuilder;
  I: Integer;
  LRv, LUnmapped, LUnmappedJson: string;
  LExtras: array of TJsonText;
  LRole: string;

  { 必填字符串字段校验：非串或空即协议违例，返回值 }
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
    ProtocolError(ABody, 'empty choices array');   { 流式才允许空（Q-O6）}
  if LChoices.ArrayLen > 1 then
    WarnLog(ALog, 'openai: dropping ' +
      IntToStr(Int64(LChoices.ArrayLen) - 1) +
      ' extra choice(s) beyond index 0 (Q-O7)');
  LC0 := LChoices.ArrayGet(0);

  { finish_reason：四值映射；未知取 frNone + agent.unmapped.* 捕获 + warn }
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
        LB := JsonBuilder;
        LB.BeginObject;
        LB.Key(CAGENT_UNMAPPED_FINISH);
        LB.Str(LUnmapped);
        LB.EndObject;
        LUnmappedJson := LB.ToString;
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

  { 部件序固定：text → thinking → tool_calls }
  if LM.Get('content').IsStr then
  begin
    LRole := LM.Get('content').AsStr.ToString;
    if LRole <> '' then
    begin
      AddPart(AMsg.Parts, pkText);
      AMsg.Parts[High(AMsg.Parts)].Text := LRole;
    end;
  end;
  { Q-O2：reasoning_content（xAI Grok 系别名 `reasoning` 兜底，前者优先）}
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

  { 生产怪癖（sub2api）：finish "stop" 却带 tool_calls → frToolCalls，
    保住消费方循环判据 }
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

{ ---- 解码：流帧归约（WIRE-MAPPINGS §1.3）---- }

type
  { 工具槽：跨 chunk 的延迟命名缓冲。真实世界（sub2api 生产经验）存在
    id+args 先到、name 后到甚至缺失的流：Start 只在 name 就绪时发出，
    args 先行片段缓冲在槽内，Finalize 兜底冲刷未命名的残留槽 }
  TOpenAIToolSlot = record
    Index: Integer;
    Id: string;
    Name: string;
    Args: IStringBuilder;
    Announced: Boolean;
  end;
  TOpenAIToolSlotArray = array of TOpenAIToolSlot;

  { 帧序状态机：首信封一次（Q-O5 Start 只发一次的前提）、tool index 分桶、
    [DONE] 终止。单角色独占，不跨消息复用 }
  TOpenAIWireDecoder = class(TInterfacedObject, IAgentWireDecoder)
  private
    FLog: ILogger;
    FSawEnvelope: Boolean;
    FDone: Boolean;
    FFinalized: Boolean;
    FSlots: TOpenAIToolSlotArray;    { 按 index 分桶的 tool 槽位 }
    FPendingUnmapped: TJsonText;     { 无同帧增量可挂的块级未知键，顺延 }
    function FindSlot(AIdx: Integer; out ACreated: Boolean): Integer;
    procedure AnnounceSlot(var ASlot: TOpenAIToolSlot;
      var ADeltas: TStreamDeltaArray);
    procedure HandleToolCalls(const AEntries: TJsonValue;
      const ASrc: string; var ADeltas: TStreamDeltaArray);
    function HasSlots: Boolean;
  public
    constructor Create(const ALog: ILogger);
    procedure DecodeEvent(const AEvent: TWireSSEEvent;
      out ADeltas: TStreamDeltaArray);
    procedure Finalize(out ADeltas: TStreamDeltaArray);
  end;

constructor TOpenAIWireDecoder.Create(const ALog: ILogger);
begin
  inherited Create;
  FLog := ALog;
end;

function TOpenAIWireDecoder.FindSlot(AIdx: Integer;
  out ACreated: Boolean): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FSlots) do
    if FSlots[I].Index = AIdx then
    begin
      ACreated := False;
      Exit(I);
    end;
  SetLength(FSlots, Length(FSlots) + 1);
  Result := High(FSlots);
  FSlots[Result] := Default(TOpenAIToolSlot);
  FSlots[Result].Index := AIdx;
  FSlots[Result].Args := MakeStringBuilder;
  ACreated := True;
end;

procedure TOpenAIWireDecoder.AnnounceSlot(var ASlot: TOpenAIToolSlot;
  var ADeltas: TStreamDeltaArray);
var
  LD: TStreamDelta;
begin
  LD := Default(TStreamDelta);
  LD.Kind := sdkToolCallStart;
  LD.ToolIndex := ASlot.Index;
  LD.ToolCallId := ASlot.Id;
  LD.ToolName := ASlot.Name;
  AddDelta(ADeltas, LD);
  if ASlot.Args.Len > 0 then
  begin
    LD := Default(TStreamDelta);
    LD.Kind := sdkToolCallDelta;
    LD.ToolIndex := ASlot.Index;
    LD.ArgumentsDelta := ASlot.Args.ToString;
    AddDelta(ADeltas, LD);
  end;
  ASlot.Announced := True;
end;

{ Q-O5（修订版，依 sub2api 生产经验）：
  - index 缺省容忍按 0 处理（部分兼容网关单工具流省略 index）；负数仍违例；
  - Start 只在 name 就绪时发出一次；name 未到先缓冲 id/args（延迟命名）；
  - 同槽重复元数据宽容忽略；本适配器不产 End（fold 对 finish 封槽）}
procedure TOpenAIWireDecoder.HandleToolCalls(const AEntries: TJsonValue;
  const ASrc: string; var ADeltas: TStreamDeltaArray);
var
  I, LSlotPos: Integer;
  LItem, LFn, LIdxV: TJsonValue;
  LIdx: Integer;
  LId, LName, LArgs: string;
  LCreated: Boolean;
  LD: TStreamDelta;
begin
  for I := 0 to Integer(AEntries.ArrayLen) - 1 do
  begin
    LItem := AEntries.ArrayGet(UInt32(I));
    if not LItem.IsObject then
      ProtocolError(ASrc, 'tool call stream entry must be an object');
    LIdxV := LItem.Get('index');
    if LIdxV.IsInt then
    begin
      LIdx := Integer(LIdxV.AsInt);
      if LIdx < 0 then
        ProtocolError(ASrc, 'tool call stream entry negative index');
    end
    else
      LIdx := 0;                       { 缺省容忍：单工具流按槽 0 }
    LId := '';
    LName := '';
    LArgs := '';
    if LItem.Get('id').IsStr then
      LId := LItem.Get('id').AsStr.ToString;
    LFn := LItem.Get('function');
    if LFn.IsObject then
    begin
      if LFn.Get('name').IsStr then
        LName := LFn.Get('name').AsStr.ToString;
      if LFn.Get('arguments').IsStr then
        LArgs := LFn.Get('arguments').AsStr.ToString;
    end;

    LSlotPos := FindSlot(LIdx, LCreated);
    if (LId <> '') and (FSlots[LSlotPos].Id = '') then
      FSlots[LSlotPos].Id := LId;      { 首个非空 id 生效 }
    if not FSlots[LSlotPos].Announced then
    begin
      if LName <> '' then
        FSlots[LSlotPos].Name := LName; { name 未就绪前持续更新 }
      if FSlots[LSlotPos].Name <> '' then
        AnnounceSlot(FSlots[LSlotPos], ADeltas);
      if LArgs <> '' then
      begin
        if FSlots[LSlotPos].Announced then
        begin
          { 已宣告：本片段直出（先于冲刷的只有此前缓冲） }
          LD := Default(TStreamDelta);
          LD.Kind := sdkToolCallDelta;
          LD.ToolIndex := LIdx;
          LD.ArgumentsDelta := LArgs;
          AddDelta(ADeltas, LD);
        end
        else
          FSlots[LSlotPos].Args.AppendStr(LArgs); { name 仍未就绪：继续缓冲 }
      end;
    end
    else if LArgs <> '' then
    begin
      { 已宣告：重复 id/name 宽容忽略，args 片段直出 }
      LD := Default(TStreamDelta);
      LD.Kind := sdkToolCallDelta;
      LD.ToolIndex := LIdx;
      LD.ArgumentsDelta := LArgs;
      AddDelta(ADeltas, LD);
    end;
  end;
end;

function TOpenAIWireDecoder.HasSlots: Boolean;
begin
  Result := Length(FSlots) > 0;
end;

procedure TOpenAIWireDecoder.DecodeEvent(const AEvent: TWireSSEEvent;
  out ADeltas: TStreamDeltaArray);
var
  Doc: IJsonDocument;
  Root, LChoices, LC0, LDv, LU, LF: TJsonValue;
  LBld: IJsonBuilder;
  LD: TStreamDelta;
  LId, LModel, LRv, LUnmapped, LCapture: string;

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
    raise EAgentMisuse.Create('openai decoder reused after Finalize');
  { 订阅网关计费/保活心跳帧（sub2api 生产怪癖）：event 名 ping 的帧
    数据非 JSON，跳过；其余 event 名不拦截——OpenAI 方言载荷在 data 行 }
  if AEvent.Event = 'ping' then
    Exit;
  if AEvent.Data = '[DONE]' then                    { §1.3 终止符 }
  begin
    FDone := True;
    Exit;
  end;
  if FDone then
    Exit;                              { DONE 后的尾帧宽容忽略 }

  Doc := JsonParse(AEvent.Data);
  if Doc.HasError or (not Doc.Root.IsObject) then
    ProtocolError(AEvent.Data, 'stream chunk must be a JSON object');
  Root := Doc.Root;

  { 首信封：id/model 至少其一出现即发一次 sdkEnvelope }
  if not FSawEnvelope then
  begin
    LId := '';
    LModel := '';
    if Root.Get('id').IsStr then
      LId := Root.Get('id').AsStr.ToString;
    if Root.Get('model').IsStr then
      LModel := Root.Get('model').AsStr.ToString;
    if (LId <> '') or (LModel <> '') then
    begin
      LD := Default(TStreamDelta);
      LD.Kind := sdkEnvelope;
      LD.MessageId := LId;
      LD.Model := LModel;
      AddDelta(ADeltas, LD);
      FSawEnvelope := True;
    end;
  end;

  { choices：空数组/缺省合法（Q-O6）；非数组=违例；多条丢弃 index>0（Q-O7）}
  LChoices := Root.Get('choices');
  if LChoices.IsValid and (not LChoices.IsNull) and (not LChoices.IsArray) then
    ProtocolError(AEvent.Data, 'choices must be an array');
  if LChoices.IsArray then
  begin
    if LChoices.ArrayLen > 1 then
      WarnLog(FLog, 'openai: dropping ' +
        IntToStr(Int64(LChoices.ArrayLen) - 1) +
        ' extra choice(s) beyond index 0 (Q-O7)');
    if LChoices.ArrayLen > 0 then
    begin
      LC0 := LChoices.ArrayGet(0);

      LDv := LC0.Get('delta');
      if LDv.IsObject then
      begin
        if LDv.Get('content').IsStr then
        begin
          LId := LDv.Get('content').AsStr.ToString;
          if LId <> '' then
          begin
            LD := Default(TStreamDelta);
            LD.Kind := sdkTextDelta;
            LD.TextDelta := LId;
            AddDelta(ADeltas, LD);
          end;
        end;
        { Q-O2：reasoning_content 增量 → 思考增量；无签名字段。
          `reasoning` 是 xAI Grok 系的等价别名（sub2api 确认两者并存，
          reasoning_content 优先）}
        if LDv.Get('reasoning_content').IsStr or
          LDv.Get('reasoning').IsStr then
        begin
          if LDv.Get('reasoning_content').IsStr then
            LId := LDv.Get('reasoning_content').AsStr.ToString
          else
            LId := LDv.Get('reasoning').AsStr.ToString;
          if LId <> '' then
          begin
            LD := Default(TStreamDelta);
            LD.Kind := sdkThinkingDelta;
            LD.TextDelta := LId;
            AddDelta(ADeltas, LD);
          end;
        end;
        if LDv.Get('tool_calls').IsValid and
          (not LDv.Get('tool_calls').IsNull) and
          (not LDv.Get('tool_calls').IsArray) then
          ProtocolError(AEvent.Data, 'delta.tool_calls must be an array');
        if LDv.Get('tool_calls').IsArray then
          HandleToolCalls(LDv.Get('tool_calls'), AEvent.Data, ADeltas);
      end
      else if LDv.IsValid and (not LDv.IsNull) then
        ProtocolError(AEvent.Data, 'choices[0].delta must be an object');

      LF := LC0.Get('finish_reason');
      if LF.IsStr then
      begin
        LRv := LF.AsStr.ToString;
        if LRv <> '' then
        begin
          LD := Default(TStreamDelta);
          LD.Kind := sdkFinish;
          LD.FinishReason := MapFinishReason(LRv, LUnmapped);
          { 生产怪癖（sub2api）：部分上游发 "stop" 却带了 tool_calls——
            归约为本流已开槽即 frToolCalls，保住消费方循环判据 }
          if (LD.FinishReason = frStop) and HasSlots then
            LD.FinishReason := frToolCalls;
          if LUnmapped <> '' then
          begin
            WarnLog(FLog, 'openai: unmapped finish_reason "' + LUnmapped +
              '" -> frNone');
            LBld := JsonBuilder;
            LBld.BeginObject;
            LBld.Key(CAGENT_UNMAPPED_FINISH);
            LBld.Str(LUnmapped);
            LBld.EndObject;
            LD.UnmappedJson := LBld.ToString;
          end;
          AddDelta(ADeltas, LD);
        end;
      end
      else if LF.IsValid and (not LF.IsNull) then
        ProtocolError(AEvent.Data,
          'finish_reason must be a string or null');
    end;
  end;

  { usage：任意帧可携（典型为末帧 choices=[] 纯 usage 帧，Q-O3）}
  LU := Root.Get('usage');
  if LU.IsObject then
  begin
    LD := Default(TStreamDelta);
    LD.Kind := sdkUsage;
    FillUsage(LU, LD.Usage);
    AddDelta(ADeltas, LD);
  end;

  { 块级未知键无损捕获：挂到本帧末个增量；无增量则顺延到下一帧；
    Finalize 时仍无落点则降级 warn（无载荷语义的元数据，证据在日志）}
  LCapture := CaptureExtraJson(Root, CKNOWN_ROOT, CMaxExtraKeys, FLog);
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

procedure TOpenAIWireDecoder.Finalize(out ADeltas: TStreamDeltaArray);
var
  I: Integer;
begin
  ADeltas := nil;
  if FFinalized then
    Exit;                              { 幂等：重复调用返回空数组 }
  FFinalized := True;
  { 延迟命名兜底：name 始终未到的槽以已知信息冲刷（id 可能也缺——
    词表允许空串），绝不让已收到的参数片段无声丢失 }
  for I := 0 to High(FSlots) do
    if not FSlots[I].Announced then
    begin
      if (FSlots[I].Id <> '') or (FSlots[I].Name <> '') or
        (FSlots[I].Args.Len > 0) then
      begin
        WarnLog(FLog, 'openai: flushing tool call slot ' +
          IntToStr(FSlots[I].Index) + ' whose name never arrived');
        AnnounceSlot(FSlots[I], ADeltas);
      end;
    end;
  { OpenAI 的 usage/finish 内联于帧序（Q-O3）；缺 [DONE] 断连（Q-O4）
    由 fold 对缺 finish 宽容收口 }
  if FPendingUnmapped <> '' then
  begin
    WarnLog(FLog,
      'openai: dropping trailing unmapped chunk keys without a carrier');
    FPendingUnmapped := '';
  end;
end;

function NewOpenAIWireDecoder(const ALog: ILogger): IAgentWireDecoder;
begin
  Result := TOpenAIWireDecoder.Create(ALog);
end;

{ ---- provider 与 completion ---- }

type
  { 拉式真增量：wire 流事件 → decoder 归约 → 词表增量逐个交付；
    EOF 时 Finalize 并以唯一 fold 收口一次（DESIGN D1）。
    sdkError 缓存至 GetMessage 抛出（ERRORS §6），不混入折叠消息 }
  TOpenAICompletion = class(TInterfacedObject, IAgentCompletion)
  private
    FStream: IAgentWireStream;
    FDecoder: IAgentWireDecoder;
    FToken: IAsyncCancellationToken;
    FProviderName: string;           { 上游错误归因（'openai'/'grok'）}
    FPending: TStreamDeltaArray;
    FIdx: Integer;
    FAccum: TStreamDeltaArray;
    FSourceDone: Boolean;
    FFolded: Boolean;
    FCancelled: Boolean;
    FMsg: TMessage;
    FErrMsg: string;
    FErrCode: TAgentErrorCode;
    FErrAfterMs: Int64;
    procedure AppendDeltas(const AArr: TStreamDeltaArray);
    procedure CloseOnce;
  public
    constructor Create(const AStream: IAgentWireStream;
      const ADecoder: IAgentWireDecoder;
      const AToken: IAsyncCancellationToken;
      const AProviderName: string);
    destructor Destroy; override;
    function NextDelta(out ADelta: TStreamDelta): Boolean;
    procedure Cancel;
    function GetCancelled: Boolean;
    function GetMessage: TMessage;
    function GetUsage: TTokenUsage;
  end;

  { 同一实现承载 openai/grok 两家族：FName 用于错误归因与 GetName；
    BaseUrl 差异由各自 Options 预填默认值消化 }
  TOpenAIProvider = class(TInterfacedObject, IAgentProvider)
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
      const AName: string = 'openai');
    function GetName: string;
    function Complete(const AReq: TCompletionRequest): TMessage; overload;
    function Complete(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): TMessage; overload;
    function Stream(
      const AReq: TCompletionRequest): IAgentCompletion; overload;
    function Stream(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): IAgentCompletion; overload;
  end;

constructor TOpenAICompletion.Create(const AStream: IAgentWireStream;
  const ADecoder: IAgentWireDecoder;
  const AToken: IAsyncCancellationToken;
  const AProviderName: string);
begin
  inherited Create;
  FStream := AStream;
  FDecoder := ADecoder;
  FToken := AToken;
  FProviderName := AProviderName;
  FIdx := 0;
end;

destructor TOpenAICompletion.Destroy;
begin
  { 弃置未读完的流：硬取消上游在途请求（transport 联动），不拖到超时 }
  if not FSourceDone then
    Cancel;
  inherited Destroy;
end;

procedure TOpenAICompletion.AppendDeltas(const AArr: TStreamDeltaArray);
var
  I, N: Integer;
begin
  for I := 0 to High(AArr) do
  begin
    if AArr[I].Kind = sdkError then
    begin
      { 首个中途错误缓存（ERRORS §6）：GetMessage 时抛出 }
      if FErrMsg = '' then
      begin
        FErrMsg := AArr[I].Error.Message;
        FErrCode := AArr[I].Error.Code;
        FErrAfterMs := AArr[I].Error.RetryAfterMs;
      end;
      Continue;
    end;
    N := Length(FAccum);
    SetLength(FAccum, N + 1);
    FAccum[N] := AArr[I];
    N := Length(FPending);
    SetLength(FPending, N + 1);
    FPending[N] := AArr[I];
  end;
end;

procedure TOpenAICompletion.CloseOnce;
begin
  if FFolded then
    Exit;
  FFolded := True;
  FoldDeltas(FAccum, FMsg);            { 唯一 fold，EOF 收口一次 }
end;

function TOpenAICompletion.NextDelta(out ADelta: TStreamDelta): Boolean;
var
  LEv: TWireSSEEvent;
  LArr: TStreamDeltaArray;
begin
  if FCancelled then
    Exit(False);
  if Assigned(FToken) and FToken.IsCancelled then
  begin
    Cancel;
    Exit(False);
  end;
  while FIdx >= Length(FPending) do
  begin
    if FSourceDone then
    begin
      CloseOnce;
      Exit(False);
    end;
    if FStream.NextEvent(LEv) then
    begin
      FDecoder.DecodeEvent(LEv, LArr);
      AppendDeltas(LArr);
    end
    else
    begin
      FSourceDone := True;             { Q-O4：断连即 EOF，Finalize 收口 }
      FDecoder.Finalize(LArr);
      AppendDeltas(LArr);
    end;
  end;
  ADelta := FPending[FIdx];
  Inc(FIdx);
  Result := True;
end;

procedure TOpenAICompletion.Cancel;
begin
  FCancelled := True;
  FStream.Cancel;
end;

function TOpenAICompletion.GetCancelled: Boolean;
begin
  Result := FCancelled or FStream.GetCancelled;
end;

function TOpenAICompletion.GetMessage: TMessage;
var
  E: EAgentError;
begin
  if not FFolded then
    raise EAgentMisuse.Create('GetMessage before EOF');
  if FErrMsg <> '' then
  begin
    E := EAgentError.CreateUpstream(FErrCode, FProviderName, FErrMsg,
      '', '', FErrAfterMs);
    raise E;
  end;
  Result := FMsg;
end;

function TOpenAICompletion.GetUsage: TTokenUsage;
begin
  if not FFolded then
    raise EAgentMisuse.Create('GetUsage before EOF');
  Result := FMsg.Usage;
end;

{ ---- TOpenAIProvider ---- }

constructor TOpenAIProvider.Create(const AOpts: TOpenAIOptions;
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

function TOpenAIProvider.GetName: string;
begin
  Result := FName;
end;

function TOpenAIProvider.ResolveModel(
  const AReq: TCompletionRequest): string;
begin
  if AReq.Model <> '' then
    Exit(AReq.Model);
  if FOpts.Common.Model <> '' then
    Exit(FOpts.Common.Model);
  raise EAgentError.CreateLocal(aecConfig,
    'openai: model is required (request.Model or options.Common.Model)');
end;

procedure CheckApiKey(const AKey: string);
begin
  if AKey = '' then
    raise EAgentError.CreateLocal(aecConfig,
      'openai: api key is required (' + COPENAI_ENV_API_KEY + ')');
end;

function TOpenAIProvider.BuildWireRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TWireRequest;
var
  LReq: TCompletionRequest;
  I, N: Integer;
begin
  CheckApiKey(FOpts.Common.ApiKey);
  LReq := AReq;
  LReq.Model := ResolveModel(AReq);
  Result := Default(TWireRequest);
  Result.Url := BuildOpenAIUrl(FOpts.Common.BaseUrl);
  Result.BodyJson := EncodeOpenAIRequest(LReq, AStream);
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

function TOpenAIProvider.Complete(const AReq: TCompletionRequest): TMessage;
var
  LResp: TWireResponse;
begin
  FTransport.RoundTrip(BuildWireRequest(AReq, False), LResp);
  DecodeOpenAIResponse(LResp.BodyText, Result, FLog);
end;

function TOpenAIProvider.Complete(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): TMessage;
begin
  { 同步 transport 无法中断在途请求：令牌在起止点检查（诚实边界，
    全程取消由 Stream 路径承担）}
  if Assigned(AToken) and AToken.IsCancelled then
    raise EAgentCancelled.Create;
  Result := Complete(AReq);
end;

function TOpenAIProvider.Stream(
  const AReq: TCompletionRequest): IAgentCompletion;
begin
  Result := TOpenAICompletion.Create(
    FTransport.OpenStream(BuildWireRequest(AReq, True)),
    NewOpenAIWireDecoder(FLog), nil, FName);
end;

function TOpenAIProvider.Stream(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): IAgentCompletion;
begin
  Result := TOpenAICompletion.Create(
    FTransport.OpenStream(BuildWireRequest(AReq, True)),
    NewOpenAIWireDecoder(FLog), AToken, FName);
end;

{ ---- 工厂 ---- }

class function TOpenAIOptions.New(const AModel: string): TOpenAIOptions;
begin
  Result := Default(TOpenAIOptions);
  Result.Common.BaseUrl := COPENAI_DEFAULT_BASE_URL;
  Result.Common.Model := AModel;
  Result.Common.ConnectTimeoutMs := COPENAI_CONNECT_TIMEOUT_MS;
  Result.Common.TotalTimeoutMs := COPENAI_TOTAL_TIMEOUT_MS;
end;

function NewOpenAIProvider(const AOpts: TOpenAIOptions): IAgentProvider;
begin
  Result := TOpenAIProvider.Create(AOpts);
end;

function NewOpenAIProviderFromEnv: IAgentProvider;
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
  Result := NewOpenAIProvider(O);
end;

{ ---- Grok 家族（wire 同族，仅默认端点与归因名不同）---- }

class function TGrokOptions.New(const AModel: string): TGrokOptions;
begin
  Result := Default(TGrokOptions);
  Result.Common.BaseUrl := CGROK_DEFAULT_BASE_URL;
  Result.Common.Model := AModel;
  Result.Common.ConnectTimeoutMs := COPENAI_CONNECT_TIMEOUT_MS;
  Result.Common.TotalTimeoutMs := COPENAI_TOTAL_TIMEOUT_MS;
end;

function NewGrokProvider(const AOpts: TGrokOptions): IAgentProvider;
var
  LO: TOpenAIOptions;
begin
  LO := Default(TOpenAIOptions);
  LO.Common := AOpts.Common;
  Result := TOpenAIProvider.Create(LO, 'grok');
end;

function NewGrokProviderFromEnv: IAgentProvider;
var
  O: TGrokOptions;
  LUrl: string;
begin
  O := TGrokOptions.New('');
  O.Common.ApiKey := GetEnvironmentVariable(CGROK_ENV_API_KEY);
  O.Common.Model := GetEnvironmentVariable(CGROK_ENV_MODEL);
  LUrl := GetEnvironmentVariable(CGROK_ENV_BASE_URL);
  if LUrl <> '' then
    O.Common.BaseUrl := LUrl;
  if (O.Common.ApiKey = '') or (O.Common.Model = '') then
    Exit(nil);
  Result := NewGrokProvider(O);
end;

end.

