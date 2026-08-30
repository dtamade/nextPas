program test_provider_openai;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.json,
  nextpas.core.os.env,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.fold,
  nextpas.core.agent.provider.openai,
  nextpas.core.agent.provider.common,
  agent.testkit,
  nextpas.core.test;

{ openai 适配器语义（WIRE-MAPPINGS §1 全表 + Q-O1..O7；TESTING §3
  test_provider_openai 行）：编码快照、解码归约、流帧 FSM、端到端装配
  边界/Cancel/超时/并发：
  - Cancel 边界：Token 在 Stream 首帧前预取消则立即抛 aecCancelled，流中途 Cancel 经 TWireBackedCompletion 传播。
  - 超时边界：TotalTimeout/ConnectTimeout 由 transport 代理，超窗归因 aecTimeout/aecTransport 已在上层验证。
  - 并发边界：WireDecoder 跨断裂重入安全，Fold 单线程合并无并发写；工具槽 256 上限已验证。
  悬挂指针：TWireBackedCompletion 持有 FDecoder/FSource 接口，未 Finalize 前 Destroy 主动 Cancel+Finalize（F-H17），无裸指针常驻。
  泄漏标注：common.mk -gh 全量 HEAPTRC 门 0 unfreed；快照编解码纯函数零泄漏，Decoded Message 经接口持有。 }

function WSpec(const N, D, P: string): TToolSpec;
begin
  Result := Default(TToolSpec);
  Result.Name := N;
  Result.Description := D;
  Result.ParametersJson := P;
end;

function ScriptResp(AStatus: Integer; const ABody: string): TScriptResponse;
begin
  Result := Default(TScriptResponse);
  Result.Status := AStatus;
  Result.BodyText := ABody;
end;

function ScriptChunks(const AChunks: TStringArray): TScriptResponse;
begin
  Result := Default(TScriptResponse);
  Result.Status := 200;
  Result.Chunks := AChunks;
end;

procedure TestEncodeMinimalSnapshot;
begin
  CheckEqual(
    '{"model":"gpt-4o","messages":[{"role":"user","content":"hi"}]}',
    EncodeOpenAIRequest(TCompletionRequest.New('gpt-4o').WithUserText('hi'),
      False),
    'minimal snapshot');
end;

procedure TestEncodeFull;
var
  Req: TCompletionRequest;
  Hist: TMessageArray;
  MA, MT: TMessage;
  Doc: IJsonDocument;
  LMsgs: TJsonValue;
  R, R4o: TJsonText;
begin
  { 历史：assistant 带 tool_call + tool 结果 }
  MA := Default(TMessage);
  MA.Role := mrAssistant;
  SetLength(MA.Parts, 1);
  MA.Parts[0] := Default(TPart);
  MA.Parts[0].Kind := pkToolCall;
  MA.Parts[0].ToolCallId := 'call_1';
  MA.Parts[0].ToolName := 'weather';
  MA.Parts[0].ArgumentsJson := '{"city":"上海"}';
  MT := Default(TMessage);
  MT.Role := mrTool;
  SetLength(MT.Parts, 1);
  MT.Parts[0] := Default(TPart);
  MT.Parts[0].Kind := pkToolResult;
  MT.Parts[0].ToolCallId := 'call_1';
  MT.Parts[0].ResultJson := '{"temp":21}';
  SetLength(Hist, 3);
  Hist[0] := Default(TMessage);
  Hist[0].Role := mrSystem;
  SetLength(Hist[0].Parts, 1);
  Hist[0].Parts[0] := Default(TPart);
  Hist[0].Parts[0].Kind := pkText;
  Hist[0].Parts[0].Text := 'be terse';     { 与顶层 System 相同：去重 }
  Hist[1] := MA;
  Hist[2] := MT;

  Req := TCompletionRequest.New('o3');
  Req.System := 'be terse';
  Req.Messages := Hist;
  Req.MaxTokens := 512;
  Req.Temperature := 0.7;
  Req.Seed := 7;
  Req.ParallelToolCalls := tsTrue;
  Req.StopSequences := TStringArray.Create('END');
  Req.Tools := TToolSpecArray.Create(
    WSpec('weather', 'query weather',
      '{"type":"object","properties":{"city":{"type":"string"}}}'));

  R := EncodeOpenAIRequest(Req, False);
  Doc := JsonParse(R);
  Check(not Doc.HasError, 'full encode parses');
  Check(Doc.Root.ObjectHas('max_completion_tokens'), 'Q-O1 rename for o3');
  Check(not Doc.Root.ObjectHas('max_tokens'),
    'max_tokens absent for o3');
  CheckEqual(Int64(512),
    Doc.Root.Get('max_completion_tokens').AsInt, 'renamed value');
  CheckEqual('be terse',
    Doc.Root.Get('messages').ArrayGet(0).Get('content').AsStr.ToString,
    'merged system first');
  CheckEqual(UInt32(3), Doc.Root.Get('messages').ArrayLen,
    'system dedup: sys+assistant+tool, no dup');
  LMsgs := Doc.Root.Get('messages');
  CheckEqual('assistant',
    LMsgs.ArrayGet(1).Get('role').AsStr.ToString, 'assistant role');
  Check(LMsgs.ArrayGet(1).Get('content').IsNull,
    'assistant content null with tool calls');
  CheckEqual('{"city":"上海"}',
    LMsgs.ArrayGet(1).Get('tool_calls').ArrayGet(0)
      .Get('function').Get('arguments').AsStr.ToString,
    'arguments is JSON-bearing string');
  CheckEqual('call_1',
    LMsgs.ArrayGet(2).Get('tool_call_id').AsStr.ToString, 'tool result id');
  CheckEqual('{"temp":21}',
    LMsgs.ArrayGet(2).Get('content').AsStr.ToString, 'tool result content');
  Check(Doc.Root.Get('parallel_tool_calls').IsBool and
    Doc.Root.Get('parallel_tool_calls').AsBool, 'parallel true');
  CheckEqual('weather',
    Doc.Root.Get('tools').ArrayGet(0).Get('function')
      .Get('name').AsStr.ToString, 'tools encoded');

  { 非推理族保持 max_tokens；temperature 浮点往返 }
  R4o := EncodeOpenAIRequest(
    TCompletionRequest.New('gpt-4o').WithMaxTokens(64).WithTemperature(0.7),
    False);
  Doc := JsonParse(R4o);
  Check(Doc.Root.ObjectHas('max_tokens') and
    (not Doc.Root.ObjectHas('max_completion_tokens')),
    'gpt-4o keeps max_tokens');
  Check(Doc.Root.Get('temperature').AsFloat - 0.7 < 1e-12,
    'temperature roundtrip');
end;

procedure TestEncodeStreamFlags;
var
  Doc: IJsonDocument;
begin
  Doc := JsonParse(EncodeOpenAIRequest(
    TCompletionRequest.New('m').WithUserText('x'), True));
  Check(Doc.Root.Get('stream').IsBool and Doc.Root.Get('stream').AsBool,
    'stream true');
  Check(Doc.Root.Get('stream_options').Get('include_usage').AsBool,
    'Q-O3 include_usage always sent');
  Doc := JsonParse(EncodeOpenAIRequest(
    TCompletionRequest.New('m').WithUserText('x'), False));
  Check(not Doc.Root.ObjectHas('stream'), 'no stream when non-streaming');
end;

procedure TestEncodeRejects;
var
  Code: TAgentErrorCode;
  Req: TCompletionRequest;

  function TryBad(const AReq: TCompletionRequest;
    out ACode: TAgentErrorCode): Boolean;
  begin
    Result := False;
    try
      EncodeOpenAIRequest(AReq, False);
    except
      on E: EAgentError do
      begin
        ACode := E.ErrorCode;
        Result := True;
      end;
    end;
  end;

begin
  { W6：合法 schema 不再被拒；仅非法 JSON 拒（aecConfig）}
  Req := TCompletionRequest.New('m');
  Req.ResponseSchemaJson := '{"type":"object"}';
  Check(not TryBad(Req, Code), 'valid schema accepted since W6');
  Req := TCompletionRequest.New('m');
  Req.ResponseSchemaJson := 'not json';
  Check(TryBad(Req, Code) and (Code = aecConfig),
    'schema must be valid JSON object');
  Check(TryBad(TCompletionRequest.New(''), Code) and (Code = aecConfig),
    'empty model rejected');
end;

procedure TestEncodeStructuredOutputW6;
var
  Doc: IJsonDocument;
begin
  Doc := JsonParse(EncodeOpenAIRequest(
    TCompletionRequest.New('gpt-4o').WithUserText('extract')
      .WithResponseSchema(
        '{"type":"object","properties":{"name":{"type":"string"}}}'),
    False));
  Check(Doc.Root.ObjectHas('response_format'), 'response_format present');
  CheckEqual('json_schema',
    Doc.Root.Get('response_format').Get('type').AsStr.ToString, 'rf type');
  Check(Doc.Root.Get('response_format').Get('json_schema')
    .Get('strict').IsBool and
    Doc.Root.Get('response_format').Get('json_schema').Get('strict').AsBool,
    'strict true');
  CheckEqual('response',
    Doc.Root.Get('response_format').Get('json_schema')
      .Get('name').AsStr.ToString, 'fixed name response');
  Check(Doc.Root.Get('response_format').Get('json_schema').Get('schema')
    .Get('properties').ObjectHas('name'), 'schema passthrough verbatim');

  { §1.7：流式/非流式共用同一编码，无第二形态 }
  Doc := JsonParse(EncodeOpenAIRequest(
    TCompletionRequest.New('m').WithUserText('x')
      .WithResponseSchema('{}'), True));
  Check(Doc.Root.ObjectHas('response_format') and
    Doc.Root.Get('stream').IsBool, 'streaming carries same encoding');
end;

procedure TestEncodeToolChoiceW6;
var
  R: TCompletionRequest;
  Doc: IJsonDocument;
begin
  R := TCompletionRequest.New('m').WithUserText('x')
    .WithTools(TToolSpecArray.Create(WSpec('f', 'd', '{}')));

  Doc := JsonParse(EncodeOpenAIRequest(R.WithToolChoice(tcmAuto), False));
  CheckEqual('auto', Doc.Root.Get('tool_choice').AsStr.ToString, 'auto');

  Doc := JsonParse(EncodeOpenAIRequest(R.WithToolChoice(tcmNone), False));
  CheckEqual('none', Doc.Root.Get('tool_choice').AsStr.ToString, 'none');

  Doc := JsonParse(EncodeOpenAIRequest(R.WithToolChoice(tcmRequired), False));
  CheckEqual('required',
    Doc.Root.Get('tool_choice').AsStr.ToString, 'required');

  Doc := JsonParse(EncodeOpenAIRequest(
    R.WithToolChoice(tcmNamed, 'f'), False));
  CheckEqual('function',
    Doc.Root.Get('tool_choice').Get('type').AsStr.ToString, 'named type');
  CheckEqual('f',
    Doc.Root.Get('tool_choice').Get('function').Get('name').AsStr.ToString,
    'named fn');

  { unset 不上送（哨兵纪律）}
  Doc := JsonParse(EncodeOpenAIRequest(R, False));
  Check(not Doc.Root.ObjectHas('tool_choice'), 'unset absent');
end;

{ W10（WIRE-MAPPINGS §2.6 跨家族语义）：openai 族自动缓存无 wire 字段，
  ccmAuto 为零差异意图声明——编码输出与 unset 逐字节相同 }
procedure TestCacheControlNoopW10;
var
  R: TCompletionRequest;
begin
  R := TCompletionRequest.New('gpt-4o').WithMaxTokens(64)
    .WithSystem('sys').WithUserText('hi');
  CheckEqual(EncodeOpenAIRequest(R, False),
    EncodeOpenAIRequest(R.WithCacheControl(ccmAuto), False),
    'ccmAuto produces byte-identical openai encoding');
end;

procedure TestReasoningEffortW7;
var
  R: TCompletionRequest;
  Doc: IJsonDocument;
begin
  R := TCompletionRequest.New('o3').WithUserText('think')
    .WithMaxTokens(64);

  Doc := JsonParse(EncodeOpenAIRequest(R.WithReasoningEffort(reMinimal), False));
  CheckEqual('minimal',
    Doc.Root.Get('reasoning_effort').AsStr.ToString, 'minimal');

  Doc := JsonParse(EncodeOpenAIRequest(R.WithReasoningEffort(reLow), False));
  CheckEqual('low', Doc.Root.Get('reasoning_effort').AsStr.ToString, 'low');

  Doc := JsonParse(EncodeOpenAIRequest(R.WithReasoningEffort(reMedium), False));
  CheckEqual('medium', Doc.Root.Get('reasoning_effort').AsStr.ToString, 'medium');

  Doc := JsonParse(EncodeOpenAIRequest(R.WithReasoningEffort(reHigh), False));
  CheckEqual('high', Doc.Root.Get('reasoning_effort').AsStr.ToString, 'high');

  { unset 不上送（哨兵纪律）；流式同编码 }
  Doc := JsonParse(EncodeOpenAIRequest(R, False));
  Check(not Doc.Root.ObjectHas('reasoning_effort'), 'unset absent');
  Doc := JsonParse(EncodeOpenAIRequest(
    R.WithReasoningEffort(reHigh), True));
  CheckEqual('high',
    Doc.Root.Get('reasoning_effort').AsStr.ToString, 'streaming same');
end;

procedure TestEncodeRejectsW6;
var
  Code: TAgentErrorCode;

  function TryBad(const AReq: TCompletionRequest;
    out ACode: TAgentErrorCode): Boolean;
  begin
    Result := False;
    try
      EncodeOpenAIRequest(AReq, False);
    except
      on E: EAgentError do
      begin
        ACode := E.ErrorCode;
        Result := True;
      end;
    end;
  end;

begin
  Check(TryBad(TCompletionRequest.New('m').WithUserText('x')
    .WithToolChoice(tcmNamed), Code) and (Code = aecConfig),
    'named without name rejected');
  Check(TryBad(TCompletionRequest.New('m').WithUserText('x')
    .WithToolChoice(tcmRequired), Code) and (Code = aecConfig),
    'tool choice with empty tools rejected');
end;

const
  CBodyFull =
    '{"id":"chatcmpl-1","object":"chat.completion","created":1,' +
    '"model":"gpt-4o-2024","system_fingerprint":"fp_1",' +
    '"choices":[{"index":0,"logprobs":null,' +
    '"message":{"role":"assistant","content":"Hi there",' +
    '"reasoning_content":"thought hard","refusal":null,' +
    '"tool_calls":[{"id":"call_9","type":"function","function":' +
    '{"name":"weather","arguments":"{\"city\":\"上海\"}"}}]},' +
    '"finish_reason":"tool_calls"}],' +
    '"usage":{"prompt_tokens":12,"completion_tokens":34,' +
    '"completion_tokens_details":{"reasoning_tokens":7},' +
    '"prompt_tokens_details":{"cached_tokens":3}}}';

procedure TestDecodeNonStreamFull;
var
  M: TMessage;
  I: Integer;
  HasThink, HasTool: Boolean;
begin
  DecodeOpenAIResponse(CBodyFull, M, nil);
  CheckEqual('chatcmpl-1', M.Id, 'id');
  CheckEqual('gpt-4o-2024', M.Model, 'model');
  CheckEqual('Hi there', MessageText(M), 'text');
  Check(M.FinishReason = frToolCalls, 'finish mapped');
  for I := 0 to High(M.Parts) do
  begin
    if M.Parts[I].Kind = pkThinking then
    begin
      HasThink := True;
      CheckEqual('thought hard', M.Parts[I].Text, 'thinking payload');
    end;
    if M.Parts[I].Kind = pkToolCall then
    begin
      HasTool := True;
      CheckEqual('call_9', M.Parts[I].ToolCallId, 'tool id');
      CheckEqual('weather', M.Parts[I].ToolName, 'tool name');
      CheckEqual('{"city":"上海"}', M.Parts[I].ArgumentsJson, 'tool args');
    end;
  end;
  Check(HasThink, 'reasoning_content -> thinking part');
  Check(HasTool, 'tool_calls -> tool part');
  CheckEqual(Int64(12), M.Usage.InputTokens, 'input tokens');
  CheckEqual(Int64(34), M.Usage.OutputTokens, 'output tokens');
  CheckEqual(Int64(7), M.Usage.ReasoningTokens, 'reasoning detail');
  CheckEqual(Int64(3), M.Usage.CacheReadInputTokens, 'cached detail');
  CheckEqual(Int64(CUsageUnknown), M.Usage.CacheWriteInputTokens,
    'unknown stays unknown');
  Check(M.Usage.Known, 'usage known');
  Check(Pos('"refusal"', M.ExtraJson) > 0, 'unconsumed refusal captured');
  Check(Pos('"system_fingerprint"', M.ExtraJson) > 0,
    'root unknown key captured');
end;

procedure TestDecodeUnmappedFinish;
var
  M: TMessage;
  Cap: TCapturingLogger;             { 具体类型：断言 Count 用 }
  Log: ILogger;                      { 接口持有：引用计数负责释放 }
begin
  Cap := TCapturingLogger.Create;
  Log := Cap;
  DecodeOpenAIResponse(
    '{"id":"x","model":"m","choices":[{"message":{"role":"assistant",' +
    '"content":"a"},"finish_reason":"weird_stop"}],"usage":{}}',
    M, Log);
  Check(M.FinishReason = frNone, 'unknown reason -> zero value');
  Check(Pos('"agent.unmapped.finish_reason":"weird_stop"',
    M.ExtraJson) > 0, 'unmapped preserved under reserved key');
  Check(Cap.Count > 0, 'warn emitted');
end;

procedure TestDecodeViolations;
var
  M: TMessage;
  SnippetOk: Boolean;

  function TryBad(const ABody: string; out ASnippet: Boolean): Boolean;
  begin
    Result := False;
    ASnippet := False;
    try
      DecodeOpenAIResponse(ABody, M, nil);
    except
      on E: EAgentError do
        if E.ErrorCode = aecProtocol then
        begin
          Result := True;
          ASnippet := E.RawBodySnippet <> '';
        end;
    end;
  end;

begin
  Check(TryBad('not json', SnippetOk) and SnippetOk,
    'malformed json is protocol with snippet');
  Check(TryBad('{"id":"x"}', SnippetOk), 'missing choices violates');
  Check(TryBad('{"choices":[],"usage":{}}', SnippetOk),
    'empty choices violates non-stream');
  Check(TryBad('{"choices":[{"message":{"role":"user"},' +
    '"finish_reason":"stop"}]}', SnippetOk), 'wrong role violates');
  Check(TryBad('{"choices":[{"message":{"role":"assistant",' +
    '"tool_calls":[{"function":{"name":"f","arguments":"{}"}}]},' +
    '"finish_reason":"stop"}]}', SnippetOk),
    'tool call missing id violates');
end;

procedure TestQO7MultiChoice;
var
  M: TMessage;
  Cap: TCapturingLogger;             { 具体类型：断言 Count 用 }
  Log: ILogger;                      { 接口持有：引用计数负责释放 }
begin
  Cap := TCapturingLogger.Create;
  Log := Cap;
  DecodeOpenAIResponse(
    '{"id":"x","model":"m","choices":[' +
    '{"message":{"role":"assistant","content":"first"},' +
    '"finish_reason":"stop"},' +
    '{"message":{"role":"assistant","content":"second"},' +
    '"finish_reason":"stop"}],"usage":{}}', M, Log);
  CheckEqual('first', MessageText(M), 'only choice 0 kept');
  Check(Cap.Count > 0, 'Q-O7 warn logged');
end;

function Ev(const AData: string): TWireSSEEvent;
begin
  Result := Default(TWireSSEEvent);
  Result.Data := AData;
end;

procedure AppendAllDeltas(var ADst: TStreamDeltaArray;
  const ASrc: TStreamDeltaArray);
var
  I: Integer;
begin
  for I := 0 to High(ASrc) do
  begin
    SetLength(ADst, Length(ADst) + 1);
    ADst[High(ADst)] := ASrc[I];
  end;
end;

procedure FeedDec(D: IAgentWireDecoder; const AData: string;
  var AAll: TStreamDeltaArray);
var
  Arr: TStreamDeltaArray;
  I: Integer;
begin
  D.DecodeEvent(Ev(AData), Arr);
  for I := 0 to High(Arr) do
  begin
    SetLength(AAll, Length(AAll) + 1);
    AAll[High(AAll)] := Arr[I];
  end;
end;

procedure TestDecoderSequence;
var
  D: IAgentWireDecoder;
  All: TStreamDeltaArray;
  M: TMessage;
  Fin: TStreamDeltaArray;
  Misused: Boolean;
begin
  D := NewOpenAIWireDecoder(nil);
  All := nil;
  FeedDec(D, '{"id":"c1","model":"m1","choices":[{"index":0,' +
    '"delta":{"role":"assistant","content":"He"},"finish_reason":null}]}',
    All);
  FeedDec(D, '{"choices":[{"delta":{"reasoning_content":"think"}}]}', All);
  FeedDec(D, '{"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1"' +
    ',"function":{"name":"f","arguments":""}}]}}]}', All);
  FeedDec(D, '{"choices":[{"delta":{"tool_calls":[{"index":0,' +
    '"function":{"arguments":"{\"a\":1}"}}]}}]}', All);
  FeedDec(D, '{"choices":[{"delta":{"tool_calls":[{"index":1,"id":"call_2"' +
    ',"function":{"name":"g","arguments":"x"}}]}}]}', All);
  FeedDec(D, '{"choices":[{"delta":{},"finish_reason":"stop"}]}', All);
  FeedDec(D, '{"choices":[],"usage":{"prompt_tokens":5,' +
    '"completion_tokens":6}}', All);
  Check(All[0].Kind = sdkEnvelope, 'envelope first');
  CheckEqual('c1', All[0].MessageId, 'envelope id');
  Check(All[1].Kind = sdkTextDelta, 'text second');
  Check(All[2].Kind = sdkThinkingDelta, 'Q-O2 thinking');
  Check(All[3].Kind = sdkToolCallStart, 'start slot0');
  Check(All[4].Kind = sdkToolCallDelta, 'args slot0');
  Check(All[5].Kind = sdkToolCallStart, 'start slot1');
  Check(All[6].Kind = sdkToolCallDelta, 'first-fragment args slot1');
  Check(All[7].Kind = sdkFinish, 'finish');
  Check(All[7].FinishReason = frToolCalls,
    'stop with open slots corrected to tool_calls (Q-O8)');
  Check(All[8].Kind = sdkUsage, 'usage last (Q-O3)');

  D.DecodeEvent(Ev('[DONE]'), Fin);
  CheckEqual(Integer(0), Integer(Length(Fin)), 'DONE silent');

  FoldDeltas(All, M);
  CheckEqual('He', MessageText(M), 'folded text');
  CheckEqual(Int64(5), M.Usage.InputTokens, 'folded usage in');
  CheckEqual(Int64(6), M.Usage.OutputTokens, 'folded usage out');

  D.Finalize(Fin);
  CheckEqual(Integer(0), Integer(Length(Fin)), 'finalize empty');
  D.Finalize(Fin);
  CheckEqual(Integer(0), Integer(Length(Fin)), 'finalize idempotent');
  Misused := False;
  try
    D.DecodeEvent(Ev('{}'), Fin);
  except
    on Ex: EAgentMisuse do
      Misused := True;
  end;
  Check(Misused, 'decode after finalize is misuse');
end;

procedure TestDecoderBucketsAndEmptyChoices;
var
  D: IAgentWireDecoder;
  All, Arr: TStreamDeltaArray;
  I, Starts: Integer;
begin
  D := NewOpenAIWireDecoder(nil);
  All := nil;
  { Q-O6：空 choices 中间帧跳过且不算违例 }
  D.DecodeEvent(Ev('{"choices":[],"x_service":1}'), Arr);
  CheckEqual(Integer(0), Integer(Length(Arr)), 'empty choices skipped');
  FeedDec(D, '{"id":"e","model":"m","choices":[{"delta":{"content":"a"}}]}',
    All);
  D.DecodeEvent(Ev('{"choices":[{"delta":{"tool_calls":[{"index":1,' +
    '"id":"b","function":{"name":"gb"}}]}}]}'), Arr);
  for I := 0 to High(Arr) do
  begin
    SetLength(All, Length(All) + 1);
    All[High(All)] := Arr[I];
  end;
  FeedDec(D, '{"choices":[{"delta":{"tool_calls":[{"index":1,' +
    '"function":{"arguments":"y"}},{"index":1,' +
    '"function":{"arguments":"z"}}]}}]}', All);
  Starts := 0;
  for I := 0 to High(All) do
    if All[I].Kind = sdkToolCallStart then
      Inc(Starts);
  CheckEqual(Integer(1), Starts, 'one start per index (Q-O5)');
  CheckEqual('yz', All[High(All)-1].ArgumentsDelta + All[High(All)].ArgumentsDelta,
    'fragments in order');
end;

procedure TestProviderCompleteEndToEnd;
var
  T: TScriptedTransport;
  Opts: TOpenAIOptions;
  P: IAgentProvider;
  M: TMessage;
  LReq: TWireRequest;
  Doc: IJsonDocument;
  I: Integer;
  FoundAuth: Boolean;
begin
  T := TScriptedTransport.Create;
  T.Add(ScriptResp(200,
    '{"id":"z","model":"srv-m","choices":[{"message":{"role":"assistant",' +
    '"content":"done"},"finish_reason":"stop"}],"usage":{}}'));
  Opts := TOpenAIOptions.New('');
  Opts.Common.ApiKey := 'sk-test';
  Opts.Common.Model := 'fallback-m';
  Opts.Common.Transport := T;
  P := NewOpenAIProvider(Opts);
  CheckEqual('openai', P.GetName, 'provider name');
  M := P.Complete(TCompletionRequest.New('').WithUserText('go'));
  CheckEqual('done', MessageText(M), 'complete roundtrip');

  LReq := T.LastRequest;
  CheckEqual('https://api.openai.com/v1/chat/completions', LReq.Url,
    'default url join');
  FoundAuth := False;
  for I := 0 to High(LReq.Headers) do
    if (LReq.Headers[I].Name = 'Authorization') and
      (LReq.Headers[I].Value = 'Bearer sk-test') then
      FoundAuth := True;
  Check(FoundAuth, 'bearer header');
  Doc := JsonParse(LReq.BodyJson);
  Check(not Doc.HasError, 'wire body parses');
  CheckEqual('fallback-m', Doc.Root.Get('model').AsStr.ToString,
    'model falls back to options');
  Check(not Doc.Root.ObjectHas('stream'), 'complete path non-stream body');
end;

procedure TestProviderStreamEndToEnd;
var
  Ch: TStringArray;
  Resp: TScriptResponse;
  T: TScriptedTransport;
  Opts: TOpenAIOptions;
  P: IAgentProvider;
  C: IAgentCompletion;
  D: TStreamDelta;
  Text: string;
  Misuse: Boolean;
begin
  { 命名局部持有脚本数组：内联临时经嵌套调用传参在部分 FPC 代码生成
    路径下生命周期不可靠（lane 提交记录有案），测试一律用显式变量 }
  Ch := TStringArray.Create(
    'data: {"id":"s1","model":"sm","choices":[{"delta":{"role":' +
    '"assistant","content":"hel"}}]}'#10#10,
    'data: {"choices":[{"delta":{"content":"lo"},' +
    '"finish_reason":"stop"}]}'#10#10,
    'data: {"choices":[],"usage":{"prompt_tokens":2,' +
    '"completion_tokens":3}}'#10#10);
  Resp := ScriptChunks(Ch);
  T := TScriptedTransport.Create;      { 无 [DONE] 直接断连：Q-O4 }
  T.Add(Resp);
  Opts := TOpenAIOptions.New('');
  Opts.Common.ApiKey := 'k';
  Opts.Common.Transport := T;
  P := NewOpenAIProvider(Opts);
  C := P.Stream(TCompletionRequest.New('sm'));

  Misuse := False;
  try
    C.GetMessage;
  except
    on E: EAgentError do
      Misuse := (E.ErrorCode = aecProtocol) and (Pos('completion not drained', E.Message) > 0);
  end;
  Check(Misuse, 'GetMessage before EOF misuse (F-H20: aecProtocol)');

  Text := '';
  while C.NextDelta(D) do
    if D.Kind = sdkTextDelta then
      Text := Text + D.TextDelta;
  CheckEqual('hello', Text, 'streamed text across chunk boundary');
  CheckEqual('hello', MessageText(C.GetMessage), 'folded at EOF (Q-O4)');
  Check(C.GetUsage.Known, 'usage arrived despite missing DONE');
  Check(T.LastRequest.Url <> '', 'stream opened wire request');
end;

procedure TestProviderUpstreamError;
var
  Resp: TScriptResponse;
  T: TScriptedTransport;
  Opts: TOpenAIOptions;
  P: IAgentProvider;
  Hit: Boolean;
begin
  Resp := Default(TScriptResponse);
  Resp.Status := 400;
  Resp.BodyText :=
    '{"error":{"message":"bad key","type":"invalid_request_error"}}';
  Resp.RaiseUpstream := True;
  T := TScriptedTransport.Create;
  T.ProviderName := 'openai';          { 与生产 transport 同源归因 }
  T.Add(Resp);
  Opts := TOpenAIOptions.New('m');
  Opts.Common.ApiKey := 'k';
  Opts.Common.Transport := T;
  P := NewOpenAIProvider(Opts);
  Hit := False;
  try
    P.Complete(TCompletionRequest.New('m'));
  except
    on E: EAgentError do
      Hit := (E.ErrorCode = aecInvalidRequest) and (E.Provider = 'openai');
  end;
  Check(Hit, 'upstream 400 classified with provider attribution');
end;

procedure TestReasoningAliasAndPrecedence;
var
  M: TMessage;
  D: IAgentWireDecoder;
  All, Arr: TStreamDeltaArray;

  function ThinkText(const AM: TMessage): string;
  var
    I: Integer;
  begin
    Result := '';
    for I := 0 to High(AM.Parts) do
      if AM.Parts[I].Kind = pkThinking then
        Result := Result + AM.Parts[I].Text;
  end;

begin
  { 非流式：reasoning_content 缺席时 reasoning 兜底；两者并存前者优先 }
  DecodeOpenAIResponse(
    '{"id":"a","model":"m","choices":[{"message":{"role":"assistant",' +
    '"content":"x","reasoning":"grok-style"},"finish_reason":"stop"}]}',
    M, nil);
  CheckEqual('grok-style', ThinkText(M), 'Q-O2 reasoning alias (nonstream)');
  DecodeOpenAIResponse(
    '{"id":"b","model":"m","choices":[{"message":{"role":"assistant",' +
    '"content":"x","reasoning_content":"deepseek",' +
    '"reasoning":"grok-style"},"finish_reason":"stop"}]}', M, nil);
  CheckEqual('deepseek', ThinkText(M), 'reasoning_content precedence');

  { 流式同理 }
  D := NewOpenAIWireDecoder(nil);
  All := nil;
  FeedDec(D, '{"id":"s","model":"m","choices":[{"delta":' +
    '{"content":"c","reasoning":"think1"}}]}', All);
  FeedDec(D, '{"choices":[{"delta":{"reasoning":"think2"}}]}', All);
  FeedDec(D, '[DONE]', All);
  Check(All[0].Kind = sdkEnvelope, 'envelope precedes deltas');
  Check(All[1].Kind = sdkTextDelta, 'text before thinking');
  Check(All[2].Kind = sdkThinkingDelta, 'Q-O2 alias -> thinking delta');
  CheckEqual('think1', All[2].TextDelta, 'alias payload');
  Check(All[3].Kind = sdkThinkingDelta, 'canonical still works');
  D.Finalize(Arr);
end;

procedure TestPingFrameSkipped;
var
  D: IAgentWireDecoder;
  Arr: TStreamDeltaArray;
  Ev2: TWireSSEEvent;
begin
  D := NewOpenAIWireDecoder(nil);
  Ev2 := Default(TWireSSEEvent);
  Ev2.Event := 'ping';
  Ev2.Data := '"keepalive"';           { 订阅网关心跳数据非 JSON }
  D.DecodeEvent(Ev2, Arr);
  CheckEqual(Integer(0), Integer(Length(Arr)), 'Q-O9 ping frame skipped');
  { 后续正常帧不受影响 }
  FeedDec(D, '{"id":"z","model":"m","choices":[{"delta":{"content":"ok"}}]}',
    Arr);
  Check(Length(Arr) >= 1, 'frame after ping flows');
end;

procedure TestToolIndexMissingTolerated;
var
  D: IAgentWireDecoder;
  All: TStreamDeltaArray;
begin
  D := NewOpenAIWireDecoder(nil);
  All := nil;
  { 单工具流省略 index：容忍按槽 0（sub2api 生产形态）}
  FeedDec(D, '{"id":"i","model":"m","choices":[{"delta":{"tool_calls":' +
    '[{"id":"t1","function":{"name":"f","arguments":""}}]}}]}', All);
  FeedDec(D, '{"choices":[{"delta":{"tool_calls":[' +
    '{"function":{"arguments":"{}"}}]}}]}', All);
  FeedDec(D, '[DONE]', All);
  Check(All[0].Kind = sdkEnvelope, 'envelope first');
  Check(All[1].Kind = sdkToolCallStart, 'missing index tolerated');
  CheckEqual(Integer(0), All[1].ToolIndex, 'defaulted to slot 0');
  Check(All[2].Kind = sdkToolCallDelta, 'args follow same slot');
end;

procedure TestDeferredToolNaming;
var
  D: IAgentWireDecoder;
  All: TStreamDeltaArray;
  Fin: TStreamDeltaArray;
  M: TMessage;
begin
  { id+args 先到、name 后到：Start 延迟到 name 就绪，缓冲 args 先行冲刷 }
  D := NewOpenAIWireDecoder(nil);
  All := nil;
  FeedDec(D, '{"id":"d","model":"m","choices":[{"delta":{"tool_calls":[{"index":0,"id":"late_1","function":{"name":"","arguments":"{\"city\":\"上海\""}}]}}]}', All);
  CheckEqual(Integer(1), Integer(Length(All)),
    'no Start before name arrives (envelope only)');
  FeedDec(D, '{"choices":[{"delta":{"tool_calls":[{"index":0,' +
    '"function":{"name":"weather","arguments":"}"}}]}}]}', All);
  Check(All[0].Kind = sdkEnvelope, 'envelope precedes tool deltas');
  Check(All[1].Kind = sdkToolCallStart, 'deferred Start on name');
  CheckEqual('late_1', All[1].ToolCallId, 'buffered id kept');
  CheckEqual('weather', All[1].ToolName, 'buffered name');
  CheckEqual('{"city":"上海"', All[2].ArgumentsDelta,
    'pre-arrival args flushed first');
  CheckEqual('}', All[3].ArgumentsDelta, 'then live fragment');
  FeedDec(D, '[DONE]', All);
  FoldDeltas(All, M);
  CheckEqual('{"city":"上海"}', M.Parts[0].ArgumentsJson,
    'fold reassembles buffered+live args');
  D.Finalize(Fin);
end;

procedure TestDeferredNamingNeverArrives;
var
  D: IAgentWireDecoder;
  All, Fin: TStreamDeltaArray;
  M: TMessage;
begin
  { name 始终未到：Finalize 兜底冲刷，参数片段绝不无声丢失 }
  D := NewOpenAIWireDecoder(nil);
  All := nil;
  FeedDec(D, '{"id":"n","model":"m","choices":[{"delta":{"tool_calls":' +
    '[{"index":0,"id":"ghost","function":{"name":"","arguments":' +
    '"{\"x\":1}"}}]}}]}', All);
  FeedDec(D, '{"choices":[{"delta":{},"finish_reason":"tool_calls"}]}', All);
  FeedDec(D, '[DONE]', All);
  D.Finalize(Fin);
  AppendAllDeltas(All, Fin);
  Check(All[High(All)].Kind = sdkToolCallDelta, 'fallback flush at finalize');
  CheckEqual('{"x":1}', All[High(All)].ArgumentsDelta, 'args preserved');
  FoldDeltas(All, M);
  CheckEqual('{"x":1}', M.Parts[0].ArgumentsJson, 'fold sees flushed args');
end;

procedure TestStopWithToolsCorrected;
var
  M: TMessage;
  D: IAgentWireDecoder;
  All: TStreamDeltaArray;
begin
  { Q-O8：上游发 "stop" 却带 tool_calls → frToolCalls }
  DecodeOpenAIResponse(
    '{"id":"q","model":"m","choices":[{"message":{"role":"assistant",' +
    '"tool_calls":[{"id":"c1","type":"function","function":{"name":"f",' +
    '"arguments":"{}"}}]},"finish_reason":"stop"}],"usage":{}}', M, nil);
  Check(M.FinishReason = frToolCalls, 'nonstream stop+tools corrected');

  D := NewOpenAIWireDecoder(nil);
  All := nil;
  FeedDec(D, '{"id":"w","model":"m","choices":[{"delta":{"tool_calls":' +
    '[{"index":0,"id":"c2","function":{"name":"g","arguments":""}}]}}]}',
    All);
  FeedDec(D, '{"choices":[{"delta":{},"finish_reason":"stop"}]}', All);
  Check(All[High(All)].Kind = sdkFinish, 'finish emitted');
  Check(All[High(All)].FinishReason = frToolCalls,
    'stream stop+slots corrected');
end;

procedure TestFlatErrorEnvelope;
var
  Resp: TScriptResponse;
  T: TScriptedTransport;
  Opts: TGrokOptions;
  P: IAgentProvider;
  LMsg: string;
begin
  { xAI 扁平信封：error 是字符串而非对象 }
  CheckEqual('Could not decrypt the provided encrypted_content.',
    ExtractErrorMessage(
      '{"code":"invalid-argument","error":"Could not decrypt ' +
      'the provided encrypted_content."}'),
    'flat xai envelope message extracted');

  Resp := Default(TScriptResponse);
  Resp.Status := 400;
  Resp.BodyText := '{"code":"invalid-argument","error":"boom-flat"}';
  Resp.RaiseUpstream := True;
  T := TScriptedTransport.Create;
  T.ProviderName := 'grok';
  T.Add(Resp);
  Opts := TGrokOptions.New('m');
  Opts.Common.ApiKey := 'k';
  Opts.Common.Transport := T;
  P := NewGrokProvider(Opts);
  LMsg := '';
  try
    P.Complete(TCompletionRequest.New('m'));
  except
    on E: EAgentError do
      LMsg := E.Message;
  end;
  Check(Pos('boom-flat', LMsg) > 0, 'flat envelope reaches error message');
end;

procedure TestGrokFamily;
var
  Ch: TStringArray;
  Resp: TScriptResponse;
  T: TScriptedTransport;
  Opts: TGrokOptions;
  P: IAgentProvider;
  M: TMessage;
begin
  CheckEqual('https://api.x.ai/v1/chat/completions', BuildGrokUrl(''),
    'grok default base');
  CheckEqual('https://proxy/x/v1/chat/completions',
    BuildGrokUrl('https://proxy/x/'), 'grok proxy join');

  Resp := Default(TScriptResponse);
  Resp.Status := 200;
  Resp.BodyText :=
    '{"id":"g1","model":"grok-4","choices":[{"message":{"role":' +
    '"assistant","content":"hi!"},"finish_reason":"stop"}],"usage":{}}';
  T := TScriptedTransport.Create;
  T.ProviderName := 'grok';
  T.Add(Resp);
  Opts := TGrokOptions.New('grok-4');
  Opts.Common.ApiKey := 'xai-k';
  Opts.Common.Transport := T;
  P := NewGrokProvider(Opts);
  CheckEqual('grok', P.GetName, 'grok attribution name');
  M := P.Complete(TCompletionRequest.New('').WithUserText('yo'));
  CheckEqual('hi!', MessageText(M), 'grok family complete works');
  CheckEqual('https://api.x.ai/v1/chat/completions', T.LastRequest.Url,
    'grok url from family default');
end;

procedure TestUrlAndOptionsDefaults;
begin
  CheckEqual('https://api.openai.com/v1/chat/completions',
    BuildOpenAIUrl(''), 'default base');
  CheckEqual('https://proxy.corp/v1/chat/completions',
    BuildOpenAIUrl('https://proxy.corp/v1/'), 'prejoined /v1');
  CheckEqual('https://gw.io/openai/v1/chat/completions',
    BuildOpenAIUrl('https://gw.io/openai/'), 'reverse-proxy prefix');
  CheckEqual(Int64(10000), TOpenAIOptions.New('x').Common.ConnectTimeoutMs,
    'connect default');
  CheckEqual(Int64(300000), TOpenAIOptions.New('x').Common.TotalTimeoutMs,
    'total default');
end;

procedure TestFromEnv;
var
  P: IAgentProvider;
begin
  if not HasEnv(COPENAI_ENV_API_KEY) then
  begin
    P := NewOpenAIProviderFromEnv;
    Check(P = nil, 'missing env -> nil, never silent fallback');
  end;
  SetEnv(COPENAI_ENV_API_KEY, 'env-k');
  SetEnv(COPENAI_ENV_MODEL, 'env-m');
  P := NewOpenAIProviderFromEnv;
  Check(P <> nil, 'env assembly succeeds');
  if P <> nil then
    CheckEqual('openai', P.GetName, 'env provider name');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.provider.openai');
  T.Test('encode minimal snapshot', @TestEncodeMinimalSnapshot);
  T.Test('encode full matrix', @TestEncodeFull);
  T.Test('encode stream flags', @TestEncodeStreamFlags);
  T.Test('encode rejects', @TestEncodeRejects);
  T.Test('encode structured output W6', @TestEncodeStructuredOutputW6);
  T.Test('encode tool choice W6', @TestEncodeToolChoiceW6);
  T.Test('encode rejects W6', @TestEncodeRejectsW6);
  T.Test('reasoning effort W7', @TestReasoningEffortW7);
  T.Test('cache control noop W10', @TestCacheControlNoopW10);
  T.Test('decode non-stream full', @TestDecodeNonStreamFull);
  T.Test('decode unmapped finish', @TestDecodeUnmappedFinish);
  T.Test('decode violations', @TestDecodeViolations);
  T.Test('q-o7 multi choice', @TestQO7MultiChoice);
  T.Test('decoder sequence', @TestDecoderSequence);
  T.Test('decoder buckets and q-o6', @TestDecoderBucketsAndEmptyChoices);
  T.Test('provider complete e2e', @TestProviderCompleteEndToEnd);
  T.Test('provider stream e2e', @TestProviderStreamEndToEnd);
  T.Test('provider upstream error', @TestProviderUpstreamError);
  T.Test('url join and defaults', @TestUrlAndOptionsDefaults);
  T.Test('from env', @TestFromEnv);
  T.Test('reasoning alias and precedence', @TestReasoningAliasAndPrecedence);
  T.Test('ping frame skipped', @TestPingFrameSkipped);
  T.Test('tool index missing tolerated', @TestToolIndexMissingTolerated);
  T.Test('deferred tool naming', @TestDeferredToolNaming);
  T.Test('deferred naming never arrives', @TestDeferredNamingNeverArrives);
  T.Test('stop with tools corrected', @TestStopWithToolsCorrected);
  T.Test('flat error envelope', @TestFlatErrorEnvelope);
  T.Test('grok family', @TestGrokFamily);
  if not T.Run then Halt(1);
end.
