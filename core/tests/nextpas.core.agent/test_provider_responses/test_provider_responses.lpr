program test_provider_responses;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.async.cancellation,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  agent.testkit,
  nextpas.core.agent.provider.openai,
  nextpas.core.agent.provider.openai.responses,
  nextpas.core.test;

{ OpenAI Responses 适配器语义（WIRE-MAPPINGS §3；TESTING §3）：
  请求映射/非流式 output 三类项/SSE 事件全集/截断 fail-closed(Q-R5)/
  错误归因。全程 scripted transport 离线 }

const
  CRespOKBody =
    '{"id":"resp_1","object":"response","model":"m1","status":"completed",' +
    '"output":[' +
      '{"type":"message","role":"assistant","id":"msg_1","content":[' +
        '{"type":"output_text","text":"hi there"}]}]}';

  CRespToolBody =
    '{"id":"resp_2","object":"response","model":"m1","status":"completed",' +
    '"usage":{"input_tokens":10,"output_tokens":5,' +
      '"output_tokens_details":{"reasoning_tokens":3},' +
      '"input_tokens_details":{"cached_tokens":2}},' +
    '"output":[' +
      '{"type":"reasoning","id":"rs_1","summary":[' +
        '{"type":"summary_text","text":"thinking..."}]},' +
      '{"type":"function_call","id":"fc_1","call_id":"call_9",' +
       '"name":"get_weather","arguments":"{\"city\":\"sf\"}"}]}';

  CRespIncompleteBody =
    '{"id":"resp_3","object":"response","model":"m1","status":"incomplete",' +
    '"incomplete_details":{"reason":"max_output_tokens"},"output":[]}';

  CRespFailedBody =
    '{"id":"resp_4","object":"response","model":"m1","status":"failed",' +
    '"error":{"code":"server_error","message":"boom upstream"}}';

{ SSE 帧：event 行为主键（Q-R2），data 载荷 JSON，空行终结 }
  CGoodChunks: array[0..3] of string = (
    'event: response.created'#10'data: {"type":"response.created",' +
      '"response":{"id":"resp_s","model":"m1"}}'#10#10,
    'event: response.output_text.delta'#10 +
      'data: {"type":"response.output_text.delta","delta":"Hel"}'#10#10,
    'event: response.output_text.delta'#10 +
      'data: {"type":"response.output_text.delta","delta":"lo"}'#10#10,
    'event: response.completed'#10 +
      'data: {"type":"response.completed","response":{"id":"resp_s",' +
      '"usage":{"input_tokens":7,"output_tokens":2}}}'#10#10
  );

  CToolChunks: array[0..4] of string = (
    'event: response.created'#10'data: {"type":"response.created",' +
      '"response":{"id":"resp_t"}}'#10#10,
    'event: response.output_item.added'#10 +
      'data: {"type":"response.output_item.added","item":{"type":' +
      '"function_call","id":"fc_a","call_id":"call_1","name":"ping"}}'#10#10,
    'event: response.function_call_arguments.delta'#10 +
      'data: {"type":"response.function_call_arguments.delta",' +
      '"item_id":"fc_a","delta":"{\"x\""}'#10#10,
    'event: response.function_call_arguments.delta'#10 +
      'data: {"type":"response.function_call_arguments.delta",' +
      '"item_id":"fc_a","delta":":1}"}'#10#10,
    'event: response.completed'#10 +
      'data: {"type":"response.completed","response":{"id":"resp_t"}}'#10#10
  );

function PlainOK: TScriptResponse;
begin
  Result := Default(TScriptResponse);
  Result.Status := 200;
  Result.BodyText := CRespOKBody;
end;

function ToolOK: TScriptResponse;
begin
  Result := Default(TScriptResponse);
  Result.Status := 200;
  Result.BodyText := CRespToolBody;
end;

function GoodStream: TScriptResponse;
var
  I: Integer;
  LChunks: TStringArray;
begin
  Result := Default(TScriptResponse);
  Result.Status := 200;
  SetLength(LChunks, Length(CGoodChunks));
  for I := 0 to High(CGoodChunks) do
    LChunks[I] := CGoodChunks[I];
  Result.Chunks := LChunks;
end;

function ToolStream: TScriptResponse;
var
  I: Integer;
  LChunks: TStringArray;
begin
  Result := Default(TScriptResponse);
  Result.Status := 200;
  SetLength(LChunks, Length(CToolChunks));
  for I := 0 to High(CToolChunks) do
    LChunks[I] := CToolChunks[I];
  Result.Chunks := LChunks;
end;

function WithTransport(const A: TScriptedTransport): IAgentProvider;
var
  O: TOpenAIOptions;
begin
  O := TOpenAIOptions.New('test-model');
  O.Common.ApiKey := 'k';
  O.Common.Transport := A;
  Result := NewOpenAIResponsesProvider(O);
end;

var
  { 解码器增量累积（各用例开头 ResetDeltas）：DecodeEvent 批次 +
    Finalize 批次统一汇入，供直测断言 }
  GAll: TStreamDeltaArray;

procedure ResetDeltas;
begin
  GAll := nil;
end;

{ 本地 SSE 帧拆解：'event: <名>'#10'data: <载荷>'#10#10 → 词表事件，
  产出增量并入全局累积 }
procedure FeedChunk(const AChunk: string; const AD: IAgentWireDecoder);
var
  LEv: TWireSSEEvent;
  LLF, LDP, I: Integer;
  LArr: TStreamDeltaArray;
begin
  LEv := Default(TWireSSEEvent);
  LLF := Pos(#10, AChunk);
  if (LLF > 7) and (Copy(AChunk, 1, 7) = 'event: ') then
    LEv.Event := Copy(AChunk, 8, LLF - 8);
  LDP := Pos('data: ', AChunk);
  if LDP > 0 then
  begin
    LEv.Data := Copy(AChunk, LDP + 6, MaxInt);
    SetLength(LEv.Data, Length(LEv.Data) - 2);   { 去尾 #10#10 }
  end;
  AD.DecodeEvent(LEv, LArr);
  for I := 0 to High(LArr) do
  begin
    SetLength(GAll, Length(GAll) + 1);
    GAll[High(GAll)] := LArr[I];
  end;
end;

procedure FinishDecoder(const AD: IAgentWireDecoder);
var
  LArr: TStreamDeltaArray;
  I: Integer;
begin
  AD.Finalize(LArr);
  for I := 0 to High(LArr) do
  begin
    SetLength(GAll, Length(GAll) + 1);
    GAll[High(GAll)] := LArr[I];
  end;
end;

function Req: TCompletionRequest;
begin
  Result := TCompletionRequest.New('m').WithUserText('hi');
end;

{ ---- 编码直测 ---- }

procedure TestEncodeBasics;
var
  R: TCompletionRequest;
  J, LDoc: string;
begin
  { Q-R7：System → instructions；user 文本进 input 数组 }
  R := Req.WithSystem('be brief');
  J := EncodeResponsesRequest(R, False);
  Check(Pos('"instructions":"be brief"', J) > 0, 'system to instructions');
  Check(Pos('"input":[{"role":"user","content":"hi"}]', J) > 0,
    'plain text user input');
  Check(Pos('"stream"', J) = 0, 'no stream flag when non-streaming');
  LDoc := EncodeResponsesRequest(R, True);
  Check(Pos('"stream":true', LDoc) > 0, 'stream flag set');
end;

{ W10（WIRE-MAPPINGS §2.6 跨家族语义）：responses 对象无显式缓存字段，
  ccmAuto 为零差异意图声明——编码输出与 unset 逐字节相同 }
procedure TestCacheControlNoopW10;
var
  R: TCompletionRequest;
begin
  R := Req.WithSystem('be brief');
  CheckEqual(EncodeResponsesRequest(R, False),
    EncodeResponsesRequest(R.WithCacheControl(ccmAuto), False),
    'ccmAuto produces byte-identical responses encoding');
end;

procedure TestEncodeToolsAndChoice;
var
  R: TCompletionRequest;
  Specs: TToolSpecArray;
  J: string;
begin
  { Q-R3：function 定义平铺 + strict；named 形态 }
  SetLength(Specs, 1);
  Specs[0] := Default(TToolSpec);
  Specs[0].Name := 'get_weather';
  Specs[0].Description := 'weather lookup';
  Specs[0].ParametersJson := '{"type":"object"}';
  R := Req.WithTools(Specs).WithToolChoice(tcmNamed, 'get_weather');
  J := EncodeResponsesRequest(R, False);
  Check(Pos('"tools":[{"type":"function","name":"get_weather"', J) > 0,
    'flat tool definition');
  Check(Pos('"strict":true', J) > 0, 'strict on tool');
  Check(
    Pos('"tool_choice":{"type":"function","name":"get_weather"}', J) > 0,
    'named choice shape');
  R := Req.WithTools(Specs).WithToolChoice(tcmRequired);
  Check(Pos('"tool_choice":"required"',
    EncodeResponsesRequest(R, False)) > 0, 'required literal');
  try
    R := Req.WithTools(Specs).WithToolChoice(tcmNamed, '');
    EncodeResponsesRequest(R, False);
    Check(False, 'named without name must raise');
  except
    on E: EAgentError do
      Check(E.ErrorCode = aecConfig, 'named missing name is aecConfig');
  end;
end;

procedure TestEncodeReasoningAndSchema;
var
  R: TCompletionRequest;
  J: string;
begin
  R := Req.WithReasoningEffort(reHigh);
  J := EncodeResponsesRequest(R, False);
  Check(Pos('"reasoning":{"effort":"high"}', J) > 0, 'effort mapping');
  R := Req.WithResponseSchema('{"type":"object"}');
  J := EncodeResponsesRequest(R, False);
  { Q-R6：structured output 走 text.format }
  Check(Pos('"text":{"format":{"type":"json_schema"', J) > 0,
    'schema via text.format');
  Check(Pos('"strict":true', J) > 0, 'schema strict');
  try
    R := Req.WithResponseSchema('[1,2]');
    EncodeResponsesRequest(R, False);
    Check(False, 'array schema must raise');
  except
    on E: EAgentError do
      Check(E.ErrorCode = aecConfig, 'non-object schema aecConfig');
  end;
end;

procedure TestBuildUrl;
begin
  Check(BuildResponsesUrl('https://api.example.com') =
    'https://api.example.com/v1/responses', 'default path appended');
  Check(BuildResponsesUrl('https://gw.example.com/v1') =
    'https://gw.example.com/v1/responses', '/v1 suffix honored');
end;

{ ---- 非流式解码直测 ---- }

procedure TestDecodeTextMessage;
var
  M: TMessage;
begin
  DecodeResponsesResponse(CRespOKBody, M, nil);
  Check(M.Id = 'resp_1', 'response id');
  Check(MessageText(M) = 'hi there', 'output_text decoded');
  Check(M.FinishReason = frStop, 'completed maps frStop');
end;

procedure TestDecodeToolAndUsageDetails;
var
  M: TMessage;
begin
  { Q-R4：usage 字段名与 reasoning 明细位置差异集中吸收 }
  DecodeResponsesResponse(CRespToolBody, M, nil);
  Check(M.Usage.InputTokens = 10, 'input tokens');
  Check(M.Usage.OutputTokens = 5, 'output tokens');
  Check(M.Usage.ReasoningTokens = 3, 'reasoning details');
  Check(M.Usage.CacheReadInputTokens = 2, 'cached tokens detail');
  Check(M.FinishReason = frToolCalls, 'tool call item implies frToolCalls');
  Check(Length(M.Parts) = 2, 'thinking + tool call parts');
  Check(M.Parts[0].Kind = pkThinking, 'reasoning summary as thinking');
  Check(M.Parts[0].Text = 'thinking...', 'summary text joined');
  Check(M.Parts[1].Kind = pkToolCall, 'flat function call item');
  Check(M.Parts[1].ToolCallId = 'call_9', 'call_id carried');
  Check(M.Parts[1].ArgumentsJson = '{"city":"sf"}', 'arguments carried');
end;

procedure TestDecodeIncompleteAndFailed;
var
  M: TMessage;
  Raised: Boolean;
begin
  DecodeResponsesResponse(CRespIncompleteBody, M, nil);
  Check(M.FinishReason = frLength, 'incomplete maps frLength');
  Raised := False;
  try
    DecodeResponsesResponse(CRespFailedBody, M, nil);
  except
    on E: EAgentError do
    begin
      Raised := True;
      Check(E.ErrorCode = aecServer, 'failed status attributes upstream');
      Check(Pos('boom upstream', E.Message) > 0, 'error message carried');
    end;
  end;
  Check(Raised, 'failed status raises');
end;

{ ---- 流式解码 ---- }

procedure TestStreamGoodPath;
var
  D: IAgentWireDecoder;
  I: Integer;
  HaveEnv, HaveText, HaveUsage, HaveFinish: Boolean;
begin
  ResetDeltas;
  D := NewResponsesWireDecoder(nil);
  for I := 0 to High(CGoodChunks) do
    FeedChunk(CGoodChunks[I], D);
  FinishDecoder(D);
  HaveEnv := False; HaveText := False; HaveUsage := False;
  HaveFinish := False;
  for I := 0 to High(GAll) do
    case GAll[I].Kind of
      sdkEnvelope:
        begin
          HaveEnv := True;
          CheckEqual('resp_s', GAll[I].MessageId, 'envelope id');
        end;
      sdkTextDelta:
        HaveText := True;
      sdkUsage:
        begin
          HaveUsage := True;
          Check(GAll[I].Usage.InputTokens = 7, 'stream usage input');
        end;
      sdkFinish:
        begin
          HaveFinish := True;
          Check(GAll[I].FinishReason = frStop, 'completed finish');
        end;
    end;
  Check(HaveEnv and HaveText and HaveUsage and HaveFinish,
    'all delta kinds present');
end;

procedure TestStreamToolCallSlots;
var
  D: IAgentWireDecoder;
  I: Integer;
  HaveStart, HaveArgs: Boolean;
  LJoined: string;
begin
  { Q-O5 同门：item_id 分桶、Start 一次、args 片段依序累积 }
  ResetDeltas;
  D := NewResponsesWireDecoder(nil);
  for I := 0 to High(CToolChunks) do
    FeedChunk(CToolChunks[I], D);
  FinishDecoder(D);
  HaveStart := False; HaveArgs := False;
  LJoined := '';
  for I := 0 to High(GAll) do
    case GAll[I].Kind of
      sdkToolCallStart:
        begin
          HaveStart := True;
          CheckEqual('call_1', GAll[I].ToolCallId, 'call_id identity');
          CheckEqual('ping', GAll[I].ToolName, 'tool name announced');
        end;
      sdkToolCallDelta:
        begin
          HaveArgs := True;
          LJoined := LJoined + GAll[I].ArgumentsDelta;
        end;
      sdkFinish:
        Check(GAll[I].FinishReason = frToolCalls,
          'completed with open slot maps frToolCalls');
    end;
  Check(HaveStart and HaveArgs, 'start + args deltas present');
  CheckEqual('{"x":1}', LJoined, 'args fragments in order');
end;

procedure TestStreamFailEvent;
var
  D: IAgentWireDecoder;
begin
  { response.failed：流中失败上浮 sdkError，终态轨迹完整不触发 Q-R5 }
  ResetDeltas;
  D := NewResponsesWireDecoder(nil);
  FeedChunk('event: response.created'#10'data: {"type":' +
    '"response.created","response":{"id":"r"}}'#10#10, D);
  FeedChunk('event: response.failed'#10'data: {"type":"response.failed",' +
    '"response":{"error":{"code":"rate_limit_exceeded",' +
    '"message":"slow down"}}}'#10#10, D);
  FinishDecoder(D);
  Check(Length(GAll) >= 2, 'envelope + error emitted');
  Check(GAll[High(GAll)].Kind = sdkError, 'error delta last');
  Check(GAll[High(GAll)].Error.Code = aecRateLimited,
    'rate limit code mapped');
end;

procedure TestTruncatedStreamFailClosed;
var
  D: IAgentWireDecoder;
  Raised: Boolean;
begin
  { Q-R5 fail-closed：有首信封无终态事件即截断流，绝不合成答案 }
  ResetDeltas;
  D := NewResponsesWireDecoder(nil);
  FeedChunk('event: response.created'#10'data: {"type":' +
    '"response.created","response":{"id":"r"}}'#10#10, D);
  FeedChunk('event: response.output_text.delta'#10'data: {"type":' +
    '"response.output_text.delta","delta":"half an an"}'#10#10, D);
  Raised := False;
  try
    FinishDecoder(D);
  except
    on E: EAgentError do
    begin
      Raised := True;
      Check(E.ErrorCode = aecProtocol, 'truncation is protocol error');
    end;
  end;
  Check(Raised, 'truncated stream rejected');
end;

{ ---- provider 全链（scripted transport）---- }

procedure TestProviderCompleteRoundTrip;
var
  T: TScriptedTransport;
  M: TMessage;
begin
  T := TScriptedTransport.Create;
  T.Add(PlainOK);
  M := WithTransport(T).Complete(Req);
  Check(MessageText(M) = 'hi there', 'round trip answer');
  Check(Pos('/responses', T.LastRequest.Url) > 0, 'responses endpoint');
  Check(Pos('Bearer k', T.LastRequest.
    Headers[0].Value) > 0, 'bearer auth');
end;

procedure TestProviderStopsIgnoredWarned;
var
  T: TScriptedTransport;
  L: TCapturingLogger;
  O: TOpenAIOptions;
  R: TCompletionRequest;
  Stops: TStringArray;
begin
  { Q-R1：stop 序列无 wire 参数——不上送且 warn 可观测 }
  T := TScriptedTransport.Create;
  T.Add(PlainOK);
  L := TCapturingLogger.Create;
  O := TOpenAIOptions.New('test-model');
  O.Common.ApiKey := 'k';
  O.Common.Transport := T;
  O.Common.Logger := L;
  SetLength(Stops, 1);
  Stops[0] := 'END';
  R := Req.WithStop(Stops);
  NewOpenAIResponsesProvider(O).Complete(R);
  Check(Pos('"stop"', T.LastRequest.BodyJson) = 0,
    'stop never sent (Q-R1)');
  Check(L.Count > 0, 'warn logged for dropped stop');
end;

procedure TestProviderStreamFold;
var
  T: TScriptedTransport;
  W: IAgentCompletion;
  D: TStreamDelta;
  LText: string;
begin
  T := TScriptedTransport.Create;
  T.Add(GoodStream);
  W := WithTransport(T).Stream(Req);
  LText := '';
  while W.NextDelta(D) do
    if D.Kind = sdkTextDelta then
      LText := LText + D.TextDelta;
  Check(LText = 'Hello', 'fold invariant across decoder');
end;

procedure TestProviderStreamToolLoopShape;
var
  T: TScriptedTransport;
  W: IAgentCompletion;
  D: TStreamDelta;
  M: TMessage;
  HaveCall: Boolean;
begin
  T := TScriptedTransport.Create;
  T.Add(ToolStream);
  W := WithTransport(T).Stream(Req);
  HaveCall := False;
  while W.NextDelta(D) do
    if D.Kind = sdkToolCallStart then
      HaveCall := True;
  M := W.GetMessage;
  Check(HaveCall, 'tool start surfaced');
  Check(M.FinishReason = frToolCalls, 'loop can drive next turn');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.provider.responses');
  T.Test('encode basics', @TestEncodeBasics);
  T.Test('encode tools and choice', @TestEncodeToolsAndChoice);
  T.Test('encode reasoning and schema', @TestEncodeReasoningAndSchema);
  T.Test('cache control noop W10', @TestCacheControlNoopW10);
  T.Test('build url', @TestBuildUrl);
  T.Test('decode text message', @TestDecodeTextMessage);
  T.Test('decode tool and usage details', @TestDecodeToolAndUsageDetails);
  T.Test('decode incomplete and failed', @TestDecodeIncompleteAndFailed);
  T.Test('stream good path', @TestStreamGoodPath);
  T.Test('stream tool call slots', @TestStreamToolCallSlots);
  T.Test('stream fail event', @TestStreamFailEvent);
  T.Test('truncated stream fail closed', @TestTruncatedStreamFailClosed);
  T.Test('provider complete round trip', @TestProviderCompleteRoundTrip);
  T.Test('provider stops ignored warned', @TestProviderStopsIgnoredWarned);
  T.Test('provider stream fold', @TestProviderStreamFold);
  T.Test('provider stream tool loop shape', @TestProviderStreamToolLoopShape);
  if not T.Run then Halt(1);
end.
