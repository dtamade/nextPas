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
  agent.testkit,
  nextpas.core.test;

{ openai 适配器语义（WIRE-MAPPINGS §1 全表 + Q-O1..O7；TESTING §3
  test_provider_openai 行）：编码快照、解码归约、流帧 FSM、端到端装配 }

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
  Req := TCompletionRequest.New('m');
  Req.ResponseSchemaJson := '{"type":"object"}';
  Check(TryBad(Req, Code) and (Code = aecConfig),
    'ResponseSchemaJson rejected in v1');
  Check(TryBad(TCompletionRequest.New(''), Code) and (Code = aecConfig),
    'empty model rejected');
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
  Log: TCapturingLogger;
begin
  Log := TCapturingLogger.Create;
  DecodeOpenAIResponse(
    '{"id":"x","model":"m","choices":[{"message":{"role":"assistant",' +
    '"content":"a"},"finish_reason":"weird_stop"}],"usage":{}}',
    M, Log);
  Check(M.FinishReason = frNone, 'unknown reason -> zero value');
  Check(Pos('"agent.unmapped.finish_reason":"weird_stop"',
    M.ExtraJson) > 0, 'unmapped preserved under reserved key');
  Check(Log.Count > 0, 'warn emitted');
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
  Log: TCapturingLogger;
begin
  Log := TCapturingLogger.Create;
  DecodeOpenAIResponse(
    '{"id":"x","model":"m","choices":[' +
    '{"message":{"role":"assistant","content":"first"},' +
    '"finish_reason":"stop"},' +
    '{"message":{"role":"assistant","content":"second"},' +
    '"finish_reason":"stop"}],"usage":{}}', M, Log);
  CheckEqual('first', MessageText(M), 'only choice 0 kept');
  Check(Log.Count > 0, 'Q-O7 warn logged');
end;

function Ev(const AData: string): TWireSSEEvent;
begin
  Result := Default(TWireSSEEvent);
  Result.Data := AData;
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
  Check(All[7].FinishReason = frStop, 'finish mapped');
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
    on E: EAgentMisuse do
      Misuse := True;
  end;
  Check(Misuse, 'GetMessage before EOF misuse');

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
  if not T.Run then Halt(1);
end.
