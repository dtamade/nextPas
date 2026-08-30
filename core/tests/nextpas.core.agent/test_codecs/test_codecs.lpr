program test_codecs;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.json,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.fold,
  nextpas.core.agent.provider.openai,
  nextpas.core.agent.provider.anthropic,
  nextpas.core.agent.provider.openai.responses,
  nextpas.core.agent.provider.common,
  agent.testkit,
  nextpas.core.test;

{ 公开编解码器（D13；TESTING §3 test_codecs 行）：wire→Decode→词表→Encode
  语义等价往返（Extra 保真）、未映射枚举→零值+agent.unmapped.*+warn、协议
  违例抛 aecProtocol 带 RawBodySnippet、跨断裂帧与 Finalize 双序等价、
  网关式双角色并行解码互不污染。openai 与 anthropic 各自成套 }

const
  CWireRich =
    '{"id":"rt-1","object":"chat.completion","created":42,' +
    '"model":"gpt-4o","service_tier":"default",' +
    '"choices":[{"index":0,"logprobs":null,' +
    '"message":{"role":"assistant","content":"plan:",' +
    '"tool_calls":[{"id":"call_a","type":"function","custom_tc":7,' +
    '"function":{"name":"calc","arguments":"{\"n\":1}","x_extra":true}}],' +
    '"cust_msg":"keepme"},"finish_reason":"tool_calls"}],' +
    '"usage":{"prompt_tokens":9,"completion_tokens":11}}';

function Ev(const AData: string): TWireSSEEvent;
begin
  Result := Default(TWireSSEEvent);
  Result.Data := AData;
end;

procedure AppendAll(var ADst: TStreamDeltaArray;
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

procedure Feed(D: IAgentWireDecoder; const AData: string;
  var AAll: TStreamDeltaArray);
var
  Arr: TStreamDeltaArray;
begin
  D.DecodeEvent(Ev(AData), Arr);
  AppendAll(AAll, Arr);
end;

procedure TestRoundtripExtraFidelity;
var
  M: TMessage;
  Req: TCompletionRequest;
  Hist: TMessageArray;
  Encoded: IJsonDocument;
  LMsgs, LAsst, LTc: TJsonValue;
begin
  { wire(含未知键) → 词表 }
  DecodeOpenAIResponse(CWireRich, M, nil);
  CheckEqual('plan:', MessageText(M), 'decode text');
  Check(M.FinishReason = frToolCalls, 'decode finish');

  { 词表作为历史 → 编码回 wire：语义等价 + Extra 保真 }
  SetLength(Hist, 1);
  Hist[0] := M;
  Req := TCompletionRequest.New('gpt-4o');
  Req.Messages := Hist;
  Encoded := JsonParse(EncodeOpenAIRequest(Req, False));
  Check(not Encoded.HasError, 're-encode parses');
  LMsgs := Encoded.Root.Get('messages');
  LAsst := LMsgs.ArrayGet(0);
  CheckEqual('assistant', LAsst.Get('role').AsStr.ToString, 'role kept');
  CheckEqual('plan:', LAsst.Get('content').AsStr.ToString, 'content kept');
  LTc := LAsst.Get('tool_calls').ArrayGet(0);
  CheckEqual('call_a', LTc.Get('id').AsStr.ToString, 'tool id kept');
  CheckEqual('{"n":1}',
    LTc.Get('function').Get('arguments').AsStr.ToString, 'args kept');
  { 未消费字段无损回注：消息级（含 choice/root 捕获合并）与部件级 }
  Check(Pos('"cust_msg"', JsonStringify(LAsst)) > 0,
    'message-level extra reinjected');
  Check(Pos('"service_tier"', JsonStringify(LAsst)) > 0,
    'root-level extra merged into message');
  Check(Pos('"custom_tc"', JsonStringify(LTc)) > 0,
    'tool-call-level extra reinjected');
end;

procedure TestUnmappedEnumZeroAndWarn;
var
  M: TMessage;
  Log: TCapturingLogger;
  D: IAgentWireDecoder;
  All, Fin: TStreamDeltaArray;
begin
  { 非流式路径 }
  Log := TCapturingLogger.Create;
  DecodeOpenAIResponse(
    '{"id":"u","model":"m","choices":[{"message":{"role":"assistant",' +
    '"content":"x"},"finish_reason":"mystery"}],"usage":{}}', M, Log);
  Check((M.FinishReason = frNone) and
    (Pos('"agent.unmapped.finish_reason":"mystery"', M.ExtraJson) > 0),
    'unmapped finish -> zero value + reserved key');
  Check(Log.Count > 0, 'warn on unmapped');

  { 流式路径同样成立并落入折叠消息 }
  D := NewOpenAIWireDecoder(Log);
  All := nil;
  Feed(D, '{"id":"s","model":"m","choices":[{"delta":{"content":"a"},' +
    '"finish_reason":"alien_stop"}]}', All);
  Feed(D, '[DONE]', All);
  FoldDeltas(All, M);
  Check((M.FinishReason = frNone) and
    (Pos('"agent.unmapped.finish_reason":"alien_stop"', M.ExtraJson) > 0),
    'stream unmapped lands in folded message');
  D.Finalize(Fin);
end;

procedure TestViolationCarriesSnippet;
var
  M: TMessage;
  Arr: TStreamDeltaArray;
  OkBody, OkStream: Boolean;
begin
  OkBody := False;
  try
    DecodeOpenAIResponse('{broken', M, nil);
  except
    on E: EAgentError do
      OkBody := (E.ErrorCode = aecProtocol) and
        (E.RawBodySnippet = '{broken');
  end;
  Check(OkBody, 'body violation carries raw snippet');

  OkStream := False;
  try
    NewOpenAIWireDecoder(nil).DecodeEvent(Ev('[1,2]'), Arr);
  except
    on E: EAgentError do
      OkStream := (E.ErrorCode = aecProtocol) and
        (E.RawBodySnippet = '[1,2]');
  end;
  Check(OkStream, 'frame violation carries frame snippet');
end;

procedure TestCrossBrokenFrameEquivalence;
var
  D1, D2: IAgentWireDecoder;
  A1, A2: TStreamDeltaArray;
  I: Integer;
  Same: Boolean;
begin
  { 同一逻辑块：单行 vs 在 JSON 空白处断裂成多行 data —— 归约等价 }
  D1 := NewOpenAIWireDecoder(nil);
  D2 := NewOpenAIWireDecoder(nil);
  A1 := nil;
  A2 := nil;
  Feed(D1, '{"id":"k","model":"km","choices":[{"delta":{"content":"v"}}]}',
    A1);
  Feed(D2, '{"id":"k",'#10'"model":"km",'#10 +
    '"choices":[{"delta":{'#10'"content":"v"}}]}', A2);
  Same := Length(A1) = Length(A2);
  if Same then
    for I := 0 to High(A1) do
      if (A1[I].Kind <> A2[I].Kind) or
        (A1[I].TextDelta <> A2[I].TextDelta) then
        Same := False;
  Check(Same and (Length(A1) = 2), 'broken-frame chunks reduce equally');
end;

procedure TestFinalizeOrderEquivalence;
var
  D1, D2: IAgentWireDecoder;
  A1, A2, Fin: TStreamDeltaArray;
  M1, M2: TMessage;

  procedure RunSeq(D: IAgentWireDecoder; AUsageFirst: Boolean;
    out AArr: TStreamDeltaArray);
  begin
    AArr := nil;
    Feed(D, '{"id":"o","model":"om","choices":[{"delta":{"content":"t"}}]}',
      AArr);
    if AUsageFirst then
    begin
      Feed(D, '{"choices":[],"usage":{"prompt_tokens":3,' +
        '"completion_tokens":4}}', AArr);
      Feed(D, '{"choices":[{"delta":{},"finish_reason":"stop"}]}', AArr);
    end
    else
    begin
      Feed(D, '{"choices":[{"delta":{},"finish_reason":"stop"}]}', AArr);
      Feed(D, '{"choices":[],"usage":{"prompt_tokens":3,' +
        '"completion_tokens":4}}', AArr);
    end;
    Feed(D, '[DONE]', AArr);
    D.Finalize(Fin);
    AppendAll(AArr, Fin);
  end;

begin
  D1 := NewOpenAIWireDecoder(nil);
  D2 := NewOpenAIWireDecoder(nil);
  RunSeq(D1, True, A1);
  RunSeq(D2, False, A2);
  FoldDeltas(A1, M1);
  FoldDeltas(A2, M2);
  Check(MessageText(M1) = MessageText(M2), 'text order-independent');
  Check((M1.FinishReason = frStop) and (M2.FinishReason = frStop),
    'finish both seen');
  Check((M1.Usage.InputTokens = 3) and (M2.Usage.InputTokens = 3) and
    (M1.Usage.OutputTokens = 4) and (M2.Usage.OutputTokens = 4),
    'usage survives either arrival order');
end;

procedure TestParallelDecodersIndependent;
var
  D1, D2: IAgentWireDecoder;
  A1, A2: TStreamDeltaArray;
  I: Integer;
  T1, T2: string;
begin
  { 网关双角色：两个解码器实例交错喂帧，状态互不污染 }
  D1 := NewOpenAIWireDecoder(nil);
  D2 := NewOpenAIWireDecoder(nil);
  A1 := nil;
  A2 := nil;
  Feed(D1, '{"id":"r1","model":"m1","choices":[{"delta":{"content":"1"}}]}',
    A1);
  Feed(D2, '{"id":"r2","model":"m2","choices":[{"delta":{"content":"2"}}]}',
    A2);
  Feed(D1, '{"choices":[{"delta":{"content":"a"}}]}', A1);
  Feed(D2, '{"choices":[{"delta":{"content":"b"}}]}', A2);
  T1 := '';
  T2 := '';
  for I := 0 to High(A1) do
    if A1[I].Kind = sdkTextDelta then
      T1 := T1 + A1[I].TextDelta;
  for I := 0 to High(A2) do
    if A2[I].Kind = sdkTextDelta then
      T2 := T2 + A2[I].TextDelta;
  CheckEqual('1a', T1, 'decoder one stream intact');
  CheckEqual('2b', T2, 'decoder two stream intact');
  CheckEqual('r1', A1[0].MessageId, 'envelope ownership kept');
  CheckEqual('r2', A2[0].MessageId, 'no cross pollution');
end;

{ ---- anthropic 套件（WIRE-MAPPINGS §2；D13 编解码器契约同表）---- }

const
  CWireAnthropicRich =
    '{"id":"rt-a","type":"message","role":"assistant","model":"cm",' +
    '"container":{"x":1},' +
    '"content":[{"type":"text","text":"plan:"},' +
    '{"type":"tool_use","id":"toolu_a","name":"calc","input":{"n":1}}],' +
    '"stop_reason":"tool_use","stop_sequence":null,' +
    '"usage":{"input_tokens":9,"output_tokens":11}}';

procedure FeedEv(D: IAgentWireDecoder; const AEvent, AData: string;
  var AAll: TStreamDeltaArray);
var
  Arr: TStreamDeltaArray;
  E: TWireSSEEvent;
  I: Integer;
begin
  E := Default(TWireSSEEvent);
  E.Event := AEvent;
  E.Data := AData;
  D.DecodeEvent(E, Arr);
  for I := 0 to High(Arr) do
  begin
    SetLength(AAll, Length(AAll) + 1);
    AAll[High(AAll)] := Arr[I];
  end;
end;

procedure TestAnthropicRoundtripExtraFidelity;
var
  M: TMessage;
  Req: TCompletionRequest;
  Encoded: IJsonDocument;
  LAsst, LBlocks: TJsonValue;
begin
  DecodeAnthropicResponse(CWireAnthropicRich, M, nil);
  CheckEqual('plan:', MessageText(M), 'decode text');
  Check(M.FinishReason = frToolCalls, 'decode finish');

  { 词表作为历史 → 编码回 wire：语义等价 + Extra 保真 }
  Req := TCompletionRequest.New('cm');
  Req.MaxTokens := 64;
  SetLength(Req.Messages, 1);
  Req.Messages[0] := M;
  Encoded := JsonParse(EncodeAnthropicRequest(Req, False));
  Check(not Encoded.HasError, 're-encode parses');
  LAsst := Encoded.Root.Get('messages').ArrayGet(0);
  CheckEqual('assistant', LAsst.Get('role').AsStr.ToString, 'role kept');
  LBlocks := LAsst.Get('content');
  CheckEqual('plan:',
    LBlocks.ArrayGet(0).Get('text').AsStr.ToString, 'text kept');
  CheckEqual('calc',
    LBlocks.ArrayGet(1).Get('name').AsStr.ToString, 'tool name kept');
  CheckEqual('{"n":1}',
    JsonStringify(LBlocks.ArrayGet(1).Get('input')),
    'input stays a real object (no re-quoting)');
  { root 未消费键无损并入消息级 Extra 回注 }
  Check(Pos('"container"', JsonStringify(LAsst)) > 0,
    'root-level extra reinjected into message');
end;

procedure TestAnthropicViolationCarriesSnippet;
var
  M: TMessage;
  Arr: TStreamDeltaArray;
  E: TWireSSEEvent;
  OkBody, OkFrame: Boolean;
begin
  OkBody := False;
  try
    DecodeAnthropicResponse('{broken', M, nil);
  except
    on Ex: EAgentError do
      OkBody := (Ex.ErrorCode = aecProtocol) and
        (Ex.RawBodySnippet = '{broken');
  end;
  Check(OkBody, 'body violation carries raw snippet');

  OkFrame := False;
  E := Default(TWireSSEEvent);
  E.Event := 'message_start';
  E.Data := '[1,2]';
  try
    NewAnthropicWireDecoder(nil).DecodeEvent(E, Arr);
  except
    on Ex: EAgentError do
      OkFrame := (Ex.ErrorCode = aecProtocol) and
        (Ex.RawBodySnippet = '[1,2]');
  end;
  Check(OkFrame, 'frame violation carries frame snippet');
end;

procedure TestAnthropicCrossBrokenFrameEquivalence;
var
  D1, D2: IAgentWireDecoder;
  A1, A2: TStreamDeltaArray;
  I: Integer;
  Same: Boolean;
begin
  { 同一逻辑事件：单行 data vs 在 JSON 空白处断裂成多行 —— 归约等价 }
  D1 := NewAnthropicWireDecoder(nil);
  D2 := NewAnthropicWireDecoder(nil);
  A1 := nil;
  A2 := nil;
  FeedEv(D1, 'message_start',
    '{"type":"message_start","message":{"id":"k","model":"km"}}', A1);
  FeedEv(D2, 'message_start',
    '{"type":"message_start",'#10'"message":{'#10'"id":"k","model":"km"}}',
    A2);
  Same := Length(A1) = Length(A2);
  if Same then
    for I := 0 to High(A1) do
      if (A1[I].Kind <> A2[I].Kind) or
        (A1[I].MessageId <> A2[I].MessageId) then
        Same := False;
  Check(Same and (Length(A1) = 1), 'broken-frame events reduce equally');
end;

procedure TestAnthropicFinalizeOrderEquivalence;
var
  D1, D2: IAgentWireDecoder;
  A1, A2, Fin: TStreamDeltaArray;
  M1, M2: TMessage;

  procedure RunSeq(D: IAgentWireDecoder; ADeltaEarly: Boolean;
    out AArr: TStreamDeltaArray);
  begin
    AArr := nil;
    FeedEv(D, 'message_start',
      '{"type":"message_start","message":{"id":"o","model":"om",' +
      '"usage":{"input_tokens":6}}}', AArr);
    FeedEv(D, 'content_block_start',
      '{"type":"content_block_start","index":0,' +
      '"content_block":{"type":"text","text":""}}', AArr);
    FeedEv(D, 'content_block_delta',
      '{"type":"content_block_delta","index":0,' +
      '"delta":{"type":"text_delta","text":"t"}}', AArr);
    if ADeltaEarly then
      { message_delta 提前到块收尾之前：stash 语义下必须等价 }
      FeedEv(D, 'message_delta',
        '{"type":"message_delta","delta":{"stop_reason":"end_turn"},' +
        '"usage":{"output_tokens":8}}', AArr);
    FeedEv(D, 'content_block_stop',
      '{"type":"content_block_stop","index":0}', AArr);
    if not ADeltaEarly then
      FeedEv(D, 'message_delta',
        '{"type":"message_delta","delta":{"stop_reason":"end_turn"},' +
        '"usage":{"output_tokens":8}}', AArr);
    FeedEv(D, 'message_stop', '{"type":"message_stop"}', AArr);
    D.Finalize(Fin);
    AppendAll(AArr, Fin);
  end;

begin
  D1 := NewAnthropicWireDecoder(nil);
  D2 := NewAnthropicWireDecoder(nil);
  RunSeq(D1, True, A1);
  RunSeq(D2, False, A2);
  FoldDeltas(A1, M1);
  FoldDeltas(A2, M2);
  Check(MessageText(M1) = MessageText(M2), 'text order-independent');
  Check((M1.FinishReason = frStop) and (M2.FinishReason = frStop),
    'stashed stop_reason applies in both orders');
  Check((M1.Usage.InputTokens = 6) and (M2.Usage.InputTokens = 6) and
    (M1.Usage.OutputTokens = 8) and (M2.Usage.OutputTokens = 8),
    'Q-A2 dual-source usage order-independent');
end;

procedure TestAnthropicParallelDecodersIndependent;
var
  D1, D2: IAgentWireDecoder;
  A1, A2: TStreamDeltaArray;
  I: Integer;
  T1, T2: string;
begin
  { 网关双角色：两个 anthropic 解码器交错喂帧，状态互不污染 }
  D1 := NewAnthropicWireDecoder(nil);
  D2 := NewAnthropicWireDecoder(nil);
  A1 := nil;
  A2 := nil;
  FeedEv(D1, 'message_start',
    '{"type":"message_start","message":{"id":"r1","model":"m"}}', A1);
  FeedEv(D2, 'message_start',
    '{"type":"message_start","message":{"id":"r2","model":"m"}}', A2);
  FeedEv(D1, 'content_block_start',
    '{"type":"content_block_start","index":0,' +
    '"content_block":{"type":"text","text":""}}', A1);
  FeedEv(D2, 'content_block_start',
    '{"type":"content_block_start","index":0,' +
    '"content_block":{"type":"text","text":""}}', A2);
  FeedEv(D1, 'content_block_delta',
    '{"type":"content_block_delta","index":0,' +
    '"delta":{"type":"text_delta","text":"1a"}}', A1);
  FeedEv(D2, 'content_block_delta',
    '{"type":"content_block_delta","index":0,' +
    '"delta":{"type":"text_delta","text":"2b"}}', A2);
  T1 := '';
  T2 := '';
  for I := 0 to High(A1) do
    if A1[I].Kind = sdkTextDelta then
      T1 := T1 + A1[I].TextDelta;
  for I := 0 to High(A2) do
    if A2[I].Kind = sdkTextDelta then
      T2 := T2 + A2[I].TextDelta;
  CheckEqual('1a', T1, 'decoder one stream intact');
  CheckEqual('2b', T2, 'decoder two stream intact');
  CheckEqual('r1', A1[0].MessageId, 'envelope ownership kept');
  CheckEqual('r2', A2[0].MessageId, 'no cross pollution');
end;

{ ---- W18.2 怪癖回放 6 条（Q-O6/Q-O4/Q-A6/Q-R2/unknown event/Q-A1）---- }

procedure TestQuirkO6EmptyChoicesSkipped;
var
  D: IAgentWireDecoder;
  Arr: TStreamDeltaArray;
  Log: TCapturingLogger;
begin
  // Q-O6 空 choices 跳过：中间帧空 choices 不抛协议且 0 deltas
  Log := TCapturingLogger.Create;
  D := NewOpenAIWireDecoder(Log);
  D.DecodeEvent(Ev('{"choices":[]}'), Arr);
  CheckEqual(Integer(0), Length(Arr), 'Q-O6 empty choices => 0 deltas');
  Check(Log.Count = 0, 'Q-O6 empty choices no warn');
  D.DecodeEvent(Ev('{"choices":[],"usage":{"prompt_tokens":1}}'), Arr);
  // 空 choices 纯 usage 帧应产出 usage delta，非空则跳过
  // 此处无 id/model，仅 usage：应产 1 条 sdkUsage
  Check(Length(Arr) = 1, 'Q-O6 empty with usage still yields usage');
  if Length(Arr) = 1 then
    Check(Arr[0].Kind = sdkUsage, 'Q-O6 usage delta kind');
  D.Finalize(Arr);
  CheckEqual(Integer(0), Length(Arr), 'Q-O6 finalize clean');
end;

procedure TestQuirkO4NoDoneEOFGraceful;
var
  D: IAgentWireDecoder;
  All, Fin: TStreamDeltaArray;
  M: TMessage;
begin
  // Q-O4 无 [DONE] 直接断连宽容（EOF 收口）：缺 DONE 仍干净 EOF
  D := NewOpenAIWireDecoder(nil);
  All := nil;
  Feed(D, '{"id":"o4","model":"m","choices":[{"delta":{"content":"hello"}}]}', All);
  Feed(D, '{"choices":[{"delta":{"content":" world"}}]}', All);
  Feed(D, '{"choices":[{"delta":{},"finish_reason":"stop"}]}', All);
  // 故意不喂 [DONE]，直接 Finalize 模拟断连
  D.Finalize(Fin);
  CheckEqual(Integer(0), Length(Fin), 'Q-O4 finalize without DONE clean');
  D.Finalize(Fin);
  CheckEqual(Integer(0), Length(Fin), 'Q-O4 second finalize still clean');
  FoldDeltas(All, M);
  CheckEqual('hello world', MessageText(M), 'Q-O4 EOF folded text intact');
  Check(M.FinishReason = frStop, 'Q-O4 finish survived without DONE');
end;

procedure TestQuirkA6InputJsonDeltaAccumulated;
var
  D: IAgentWireDecoder;
  All, Fin: TStreamDeltaArray;
  M: TMessage;
  SawStart, SawEnd: Boolean;
  Joined: string;
  I: Integer;
begin
  // Q-A6 input_json_delta 分片累积（anthropic tool id+delta）：槽位 Args 累积正确
  D := NewAnthropicWireDecoder(nil);
  All := nil;
  FeedEv(D, 'message_start',
    '{"type":"message_start","message":{"id":"a6","model":"cm","usage":{"input_tokens":1}}}', All);
  FeedEv(D, 'content_block_start',
    '{"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_a6","name":"calc","input":{}}}', All);
  FeedEv(D, 'content_block_delta',
    '{"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\"x\""}}', All);
  FeedEv(D, 'content_block_delta',
    '{"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":":1}"}}', All);
  FeedEv(D, 'content_block_stop',
    '{"type":"content_block_stop","index":0}', All);
  FeedEv(D, 'message_delta',
    '{"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":2}}', All);
  FeedEv(D, 'message_stop', '{"type":"message_stop"}', All);
  D.Finalize(Fin);
  AppendAll(All, Fin);
  SawStart := False; SawEnd := False; Joined := '';
  for I := 0 to High(All) do
    case All[I].Kind of
      sdkToolCallStart: SawStart := All[I].ToolCallId = 'toolu_a6';
      sdkToolCallDelta: Joined := Joined + All[I].ArgumentsDelta;
      sdkToolCallEnd: SawEnd := True;
      else ;
    end;
  Check(SawStart, 'Q-A6 start announced');
  CheckEqual('{"x":1}', Joined, 'Q-A6 delta fragments accumulated in order');
  Check(SawEnd, 'Q-A6 tool end emitted');
  FoldDeltas(All, M);
  CheckEqual('{"x":1}', M.Parts[0].ArgumentsJson, 'Q-A6 folded args correct');
  Check(M.FinishReason = frToolCalls, 'Q-A6 finish');
end;

procedure TestQuirkR2EventDispatch;
var
  D: IAgentWireDecoder;
  All, Fin: TStreamDeltaArray;
  HaveEnv, HaveFinish: Boolean;
  Text: string;
  I: Integer;

  procedure FeedR(const AEvent, AData: string);
  var
    Arr: TStreamDeltaArray;
    E: TWireSSEEvent;
    J: Integer;
  begin
    E := Default(TWireSSEEvent);
    E.Event := AEvent;
    E.Data := AData;
    D.DecodeEvent(E, Arr);
    for J := 0 to High(Arr) do
    begin
      SetLength(All, Length(All) + 1);
      All[High(All)] := Arr[J];
    end;
  end;

begin
  // Q-R2 event 主键分派 (response.*)：按 event 名而非 data.type 分派
  D := NewResponsesWireDecoder(nil);
  All := nil;
  FeedR('response.created',
    '{"type":"response.created","response":{"id":"r2","model":"m1"}}');
  FeedR('response.output_text.delta',
    '{"type":"response.output_text.delta","delta":"hello"}');
  FeedR('response.output_text.delta',
    '{"type":"response.output_text.delta","delta":" world"}');
  FeedR('response.completed',
    '{"type":"response.completed","response":{"id":"r2","usage":{"input_tokens":1,"output_tokens":2}}}');
  D.Finalize(Fin);
  AppendAll(All, Fin);
  HaveEnv := False; HaveFinish := False; Text := '';
  for I := 0 to High(All) do
    case All[I].Kind of
      sdkEnvelope: HaveEnv := All[I].MessageId = 'r2';
      sdkTextDelta: Text := Text + All[I].TextDelta;
      sdkFinish: HaveFinish := All[I].FinishReason = frStop;
      else ;
    end;
  Check(HaveEnv, 'Q-R2 envelope via event');
  CheckEqual('hello world', Text, 'Q-R2 text via event dispatch');
  Check(HaveFinish, 'Q-R2 finish via completed event');
end;

procedure TestQuirkUnknownEventSkipped;
var
  D1, D2: IAgentWireDecoder;
  Arr: TStreamDeltaArray;
  E: TWireSSEEvent;
begin
  // unknown event 跳过（openai/responses 各一条）：0 deltas 且不抛 aecProtocol
  D1 := NewOpenAIWireDecoder(nil);
  E := Default(TWireSSEEvent);
  E.Event := 'unknown_future_event';
  E.Data := '{"choices":[]}';
  try
    D1.DecodeEvent(E, Arr);
    CheckEqual(Integer(0), Length(Arr), 'Q-O unknown event => 0 deltas');
  except
    on Ex: EAgentError do
      Check(False, 'Q-O unknown should not throw aecProtocol');
  end;
  D2 := NewResponsesWireDecoder(nil);
  E.Event := 'response.unknown_event';
  E.Data := '{"type":"response.unknown_event","foo":123}';
  try
    D2.DecodeEvent(E, Arr);
    CheckEqual(Integer(0), Length(Arr), 'Q-R unknown event => 0 deltas');
  except
    on Ex: EAgentError do
      Check(False, 'Q-R unknown should not throw');
  end;
  // anthropic unknown as sanity
  D1 := NewAnthropicWireDecoder(nil);
  E.Event := 'unknown_future_event';
  E.Data := 'not json at all';
  try
    D1.DecodeEvent(E, Arr);
    CheckEqual(Integer(0), Length(Arr), 'Q-A unknown event => 0 deltas');
  except
    on Ex: EAgentError do
      Check(False, 'Q-A unknown should not throw');
  end;
end;

procedure TestQuirkA1MessageStartRequired;
var
  D: IAgentWireDecoder;
  All, Fin: TStreamDeltaArray;
  Raised: Boolean;
begin
  // Q-A1 message_start 强制首信封容忍（可与 Q-O1 合并简版）：首信封必须，容忍缺失仅终态报错
  D := NewAnthropicWireDecoder(nil);
  All := nil;
  FeedEv(D, 'message_start',
    '{"type":"message_start","message":{"id":"a1","model":"cm"}}', All);
  Check(All[0].Kind = sdkEnvelope, 'Q-A1 first envelope present');
  CheckEqual('a1', All[0].MessageId, 'Q-A1 envelope id');
  Raised := False;
  try
    FeedEv(D, 'message_start',
      '{"type":"message_start","message":{"id":"dup","model":"cm"}}', All);
  except
    on E: EAgentError do
      Raised := E.ErrorCode = aecProtocol;
  end;
  Check(Raised, 'Q-A1 duplicate start => aecProtocol');
  // 缺首信封的流容忍：Decode 不立即抛，Finalize 才 fail-closed
  D := NewAnthropicWireDecoder(nil);
  All := nil;
  FeedEv(D, 'content_block_start',
    '{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}', All);
  CheckEqual(Integer(0), Length(All), 'Q-A1 missing start still 0 deltas (tolerant)');
  Raised := False;
  try
    D.Finalize(Fin);
  except
    on E: EAgentError do
      Raised := E.ErrorCode = aecProtocol;
  end;
  Check(Raised, 'Q-A1 missing start finalizes to protocol error');
end;

{ ---- W18.2 续消 7 条中低成本怪癖（Q-O1/Q-O2/Q-O3/Q-O5/Q-O7/Q-A3/Q-R1）---- }

procedure TestQuirkO1MaxCompletionTokensRenameTolerance;
var
  R: TCompletionRequest;
  J: TJsonText;
  Doc: IJsonDocument;
  D: IAgentWireDecoder;
  Arr: TStreamDeltaArray;
begin
  // Q-O1 推理族 max_completion_tokens 改名容忍：o1 前缀走新键，gpt-4o 保持旧键；decoder 侧 Extra 容忍不抛 aecProtocol
  R := TCompletionRequest.New('o1-mini').WithMaxTokens(123).WithUserText('hi');
  J := EncodeOpenAIRequest(R, False);
  Doc := JsonParse(J);
  Check(not Doc.HasError, 'Q-O1 encode parses');
  Check(Doc.Root.ObjectHas('max_completion_tokens'), 'Q-O1 o1 uses max_completion_tokens');
  Check(not Doc.Root.ObjectHas('max_tokens'), 'Q-O1 max_tokens absent for reasoning');
  CheckEqual(Int64(123), Doc.Root.Get('max_completion_tokens').AsInt, 'Q-O1 value kept');
  R := TCompletionRequest.New('gpt-4o').WithMaxTokens(64).WithUserText('hi');
  J := EncodeOpenAIRequest(R, False);
  Doc := JsonParse(J);
  Check(Doc.Root.ObjectHas('max_tokens'), 'Q-O1 gpt-4o keeps max_tokens');
  Check(not Doc.Root.ObjectHas('max_completion_tokens'), 'Q-O1 no rename for gpt-4o');
  // decoder 侧：含额外 max_completion_tokens 的最小 vendor JSON 不抛 aecProtocol
  D := NewOpenAIWireDecoder(nil);
  try
    D.DecodeEvent(Ev('{"id":"o1","model":"o1-mini","choices":[{"delta":{"content":"hi"}}],"max_completion_tokens":123}'), Arr);
    Check(Length(Arr) >= 2, 'Q-O1 extra tolerated as deltas');
    Check(Arr[0].Kind = sdkEnvelope, 'Q-O1 envelope still emitted');
  except
    on E: EAgentError do
      Check(False, 'Q-O1 decoder should not throw aecProtocol');
  end;
  D.Finalize(Arr);
end;

procedure TestQuirkO2ReasoningContentThinkingDelta;
var
  D: IAgentWireDecoder;
  All: TStreamDeltaArray;
  M: TMessage;
  I: Integer;
  Found1, Found2, FoundPrio: Boolean;
begin
  // Q-O2 reasoning_content / reasoning → sdkThinkingDelta，reasoning_content 优先
  D := NewOpenAIWireDecoder(nil);
  All := nil;
  Feed(D, '{"id":"q2","model":"m","choices":[{"delta":{"reasoning_content":"think1"}}]}', All);
  Found1 := False;
  for I := 0 to High(All) do
    if (All[I].Kind = sdkThinkingDelta) and (All[I].TextDelta = 'think1') then
      Found1 := True;
  Check(Found1, 'Q-O2 reasoning_content -> sdkThinkingDelta');
  D := NewOpenAIWireDecoder(nil);
  All := nil;
  Feed(D, '{"choices":[{"delta":{"reasoning":"think2"}}]}', All);
  Found2 := False;
  for I := 0 to High(All) do
    if (All[I].Kind = sdkThinkingDelta) and (All[I].TextDelta = 'think2') then
      Found2 := True;
  Check(Found2, 'Q-O2 reasoning alias -> sdkThinkingDelta');
  D := NewOpenAIWireDecoder(nil);
  All := nil;
  Feed(D, '{"choices":[{"delta":{"reasoning_content":"deep","reasoning":"grok"}}]}', All);
  FoundPrio := False;
  for I := 0 to High(All) do
    if (All[I].Kind = sdkThinkingDelta) and (All[I].TextDelta = 'deep') then
      FoundPrio := True;
  Check(FoundPrio, 'Q-O2 priority: reasoning_content over reasoning');
  // 非流式同样映射为 pkThinking
  DecodeOpenAIResponse('{"id":"x","model":"m","choices":[{"message":{"role":"assistant","content":"x","reasoning_content":"deep"},"finish_reason":"stop"}]}', M, nil);
  Check((Length(M.Parts) >= 1) and (M.Parts[1].Kind = pkThinking) and (M.Parts[1].Text = 'deep'), 'Q-O2 non-stream maps to thinking');
  // 最小 vendor JSON 不抛 aecProtocol
  D := NewOpenAIWireDecoder(nil);
  try
    D.DecodeEvent(Ev('{"choices":[{"delta":{"reasoning_content":"ok"}}]}'), All);
    Check(True, 'Q-O2 minimal vendor JSON tolerated');
  except
    on E: EAgentError do
      Check(False, 'Q-O2 should not throw');
  end;
end;

procedure TestQuirkO3IncludeUsageHarmless;
var
  R: TCompletionRequest;
  Doc: IJsonDocument;
  D: IAgentWireDecoder;
  Arr: TStreamDeltaArray;
begin
  // Q-O3 stream_options.include_usage 无害：流式必发，decoder 空 choices+usage 容忍为 sdkUsage
  R := TCompletionRequest.New('m').WithUserText('hi');
  Doc := JsonParse(EncodeOpenAIRequest(R, True));
  Check(Doc.Root.ObjectHas('stream_options'), 'Q-O3 stream_options present');
  Check(Doc.Root.Get('stream_options').Get('include_usage').AsBool, 'Q-O3 include_usage true');
  Doc := JsonParse(EncodeOpenAIRequest(R, False));
  Check(not Doc.Root.ObjectHas('stream_options'), 'Q-O3 no stream_options when non-streaming');
  D := NewOpenAIWireDecoder(nil);
  try
    D.DecodeEvent(Ev('{"choices":[],"usage":{"prompt_tokens":1,"completion_tokens":2}}'), Arr);
    CheckEqual(Integer(1), Length(Arr), 'Q-O3 empty choices with usage => 1 delta');
    Check(Arr[0].Kind = sdkUsage, 'Q-O3 yields sdkUsage');
    CheckEqual(Int64(1), Arr[0].Usage.InputTokens, 'Q-O3 usage input');
  except
    on E: EAgentError do
      Check(False, 'Q-O3 should not throw aecProtocol');
  end;
  D := NewOpenAIWireDecoder(nil);
  try
    D.DecodeEvent(Ev('{"choices":[{"delta":{"content":"hi"}}]}'), Arr);
    Check(True, 'Q-O3 without usage still tolerated');
  except
    on E: EAgentError do
      Check(False, 'Q-O3 no usage should not throw');
  end;
end;

procedure TestQuirkO5ToolSlotDelayedNamingMissingIndex;
var
  D: IAgentWireDecoder;
  All, Fin: TStreamDeltaArray;
  I, Starts: Integer;
begin
  // Q-O5 工具 slot 延迟命名/缺 index 容忍：缺 index 按 0，name 未到先缓冲
  D := NewOpenAIWireDecoder(nil);
  All := nil;
  Feed(D, '{"id":"q5","model":"m","choices":[{"delta":{"tool_calls":[{"id":"t1","function":{"name":"f","arguments":"{}"}}]}}]}', All);
  Check(Length(All) >= 2, 'Q-O5 missing index tolerated envelope+start');
  Check(All[1].Kind = sdkToolCallStart, 'Q-O5 missing index => start');
  CheckEqual(Integer(0), All[1].ToolIndex, 'Q-O5 defaults to slot 0');
  D := NewOpenAIWireDecoder(nil);
  All := nil;
  Feed(D, '{"id":"q5b","model":"m","choices":[{"delta":{"tool_calls":[{"index":0,"id":"late_1","function":{"arguments":"{\"a\":1}"}}]}}]}', All);
  CheckEqual(Integer(1), Length(All), 'Q-O5 delayed: no start before name (envelope only)');
  Feed(D, '{"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"name":"calc","arguments":"}"}}]}}]}', All);
  Starts := 0;
  for I := 0 to High(All) do
    if All[I].Kind = sdkToolCallStart then
      Inc(Starts);
  CheckEqual(Integer(1), Starts, 'Q-O5 start after name');
  CheckEqual('late_1', All[1].ToolCallId, 'Q-O5 buffered id kept');
  CheckEqual('calc', All[1].ToolName, 'Q-O5 name announced');
  // 最小 vendor JSON 缺 index 不抛 aecProtocol
  D := NewOpenAIWireDecoder(nil);
  try
    D.DecodeEvent(Ev('{"choices":[{"delta":{"tool_calls":[{"function":{"arguments":"{}"}}]}}]}'), Fin);
    Check(True, 'Q-O5 minimal missing index not throw');
  except
    on E: EAgentError do
      Check(False, 'Q-O5 should not throw aecProtocol');
  end;
end;

procedure TestQuirkO7MultiChoiceDiscardWarn;
var
  Log: TCapturingLogger;
  LLog: ILogger;
  M: TMessage;
  D: IAgentWireDecoder;
  Arr: TStreamDeltaArray;
  I: Integer;
  Text: string;
begin
  // Q-O7 多 choice 丢弃 warn：仅保留 index 0，其余丢弃并 warn
  Log := TCapturingLogger.Create;
  LLog := Log;
  DecodeOpenAIResponse('{"id":"x","model":"m","choices":[{"message":{"role":"assistant","content":"first"},"finish_reason":"stop"},{"message":{"role":"assistant","content":"second"},"finish_reason":"stop"}]}', M, LLog);
  CheckEqual('first', MessageText(M), 'Q-O7 non-stream keeps first choice');
  Check(Log.Count > 0, 'Q-O7 non-stream warn');
  Log := TCapturingLogger.Create;
  LLog := Log;
  D := NewOpenAIWireDecoder(LLog);
  Arr := nil;
  try
    D.DecodeEvent(Ev('{"id":"o7","model":"m","choices":[{"delta":{"content":"a"}},{"index":1,"delta":{"content":"b"}}]}'), Arr);
    Text := '';
    for I := 0 to High(Arr) do
      if Arr[I].Kind = sdkTextDelta then
        Text := Text + Arr[I].TextDelta;
    CheckEqual('a', Text, 'Q-O7 stream drops index>0');
    Check(Log.Count > 0, 'Q-O7 stream warn');
  except
    on E: EAgentError do
      Check(False, 'Q-O7 should not throw aecProtocol');
  end;
end;

procedure TestQuirkA3ThinkingSignaturePassthrough;
var
  M: TMessage;
  D: IAgentWireDecoder;
  All, Fin: TStreamDeltaArray;
  I: Integer;
  FoundSig: Boolean;
begin
  // Q-A3 thinking signature 透传：非流式与流式均原样携带
  DecodeAnthropicResponse('{"id":"a3","type":"message","role":"assistant","model":"cm","content":[{"type":"thinking","thinking":"deep","signature":"sig-abc"}],"stop_reason":"end_turn","usage":{}}', M, nil);
  Check(Length(M.Parts) = 1, 'Q-A3 non-stream one part');
  Check(M.Parts[0].Kind = pkThinking, 'Q-A3 kind thinking');
  CheckEqual('deep', M.Parts[0].Text, 'Q-A3 text');
  CheckEqual('sig-abc', M.Parts[0].Signature, 'Q-A3 signature passthrough');
  D := NewAnthropicWireDecoder(nil);
  All := nil;
  FeedEv(D, 'message_start', '{"type":"message_start","message":{"id":"a3s","model":"cm"}}', All);
  FeedEv(D, 'content_block_start', '{"type":"content_block_start","index":1,"content_block":{"type":"thinking","thinking":""}}', All);
  FeedEv(D, 'content_block_delta', '{"type":"content_block_delta","index":1,"delta":{"type":"thinking_delta","thinking":"deep2"}}', All);
  FeedEv(D, 'content_block_delta', '{"type":"content_block_delta","index":1,"delta":{"type":"signature_delta","signature":"sig-xyz"}}', All);
  FoundSig := False;
  for I := 0 to High(All) do
    if (All[I].Kind = sdkThinkingDelta) and (All[I].Signature = 'sig-xyz') then
      FoundSig := True;
  Check(FoundSig, 'Q-A3 stream signature_delta -> sdkThinkingDelta.Signature');
  // 收口不抛 aecProtocol
  FeedEv(D, 'content_block_stop', '{"type":"content_block_stop","index":1}', All);
  FeedEv(D, 'message_delta', '{"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":1}}', All);
  FeedEv(D, 'message_stop', '{"type":"message_stop"}', All);
  try
    D.Finalize(Fin);
    Check(True, 'Q-A3 finalize clean');
  except
    on E: EAgentError do
      Check(False, 'Q-A3 should not throw on finalize');
  end;
end;

procedure TestQuirkR1StopSequencesIgnoredWarn;
var
  R: TCompletionRequest;
  J: TJsonText;
  Log: TCapturingLogger;
  LLog: ILogger;
  O: TOpenAIOptions;
  T: TScriptedTransport;
  P: IAgentProvider;
  D: IAgentWireDecoder;
  Arr: TStreamDeltaArray;
  Resp: TScriptResponse;
begin
  // Q-R1 stop_sequences 忽略 warn：responses 无 stop 参数，编码不上送且 provider 层 warn；decoder 容忍
  R := TCompletionRequest.New('m').WithUserText('hi').WithStop(TStringArray.Create('END'));
  J := EncodeResponsesRequest(R, False);
  Check(Pos('"stop"', J) = 0, 'Q-R1 encode omits stop');
  // provider 层 warn 可观测
  Log := TCapturingLogger.Create;
  LLog := Log;
  O := TOpenAIOptions.New('m');
  O.Common.ApiKey := 'k';
  O.Common.Logger := LLog;
  T := TScriptedTransport.Create;
  T.ProviderName := 'openai.responses';
  Resp := Default(TScriptResponse);
  Resp.Status := 200;
  Resp.BodyText := '{"id":"r1","object":"response","model":"m","status":"completed","output":[]}';
  T.Add(Resp);
  O.Common.Transport := T;
  P := NewOpenAIResponsesProvider(O);
  try
    P.Complete(R);
  except
    // 忽略上游错误，仅关心 warn 与不上送
  end;
  Check(Log.Count > 0, 'Q-R1 warn logged');
  Check(Pos('"stop"', T.LastRequest.BodyJson) = 0, 'Q-R1 wire body has no stop');
  // decoder 容忍未知 stop_sequences 键不抛 aecProtocol，产出 thinking/text 正常
  D := NewResponsesWireDecoder(nil);
  try
    D.DecodeEvent(Ev('{"type":"response.created","response":{"id":"r1","model":"m"}}'), Arr);
    Check(Length(Arr) = 1, 'Q-R1 decoder envelope ok');
    D.DecodeEvent(Ev('{"type":"response.output_text.delta","delta":"hi","stop_sequences":["END"]}'), Arr);
    Check(True, 'Q-R1 decoder tolerates extra stop_sequences');
  except
    on E: EAgentError do
      Check(False, 'Q-R1 decoder should not throw aecProtocol');
  end;
end;

procedure TestQuirkO8StopToolCallsCorrected;
var
  M: TMessage;
  D: IAgentWireDecoder;
  All, Fin: TStreamDeltaArray;
  I: Integer;
  LastFr: TFinishReason;
begin
  DecodeOpenAIResponse('{"id":"q8","model":"m","choices":[{"message":{"role":"assistant","tool_calls":[{"id":"c1","type":"function","function":{"name":"f","arguments":"{}"}}]},"finish_reason":"stop"}],"usage":{}}', M, nil);
  Check(M.FinishReason = frToolCalls, 'Q-O8 non-stream stop+tools -> frToolCalls');
  DecodeOpenAIResponse('{"id":"q8b","model":"m","choices":[{"message":{"role":"assistant","content":"hi"},"finish_reason":"stop"}],"usage":{}}', M, nil);
  Check(M.FinishReason = frStop, 'Q-O8 pure stop stays frStop');
  D := NewOpenAIWireDecoder(nil);
  All := nil;
  Feed(D, '{"id":"w","model":"m","choices":[{"delta":{"tool_calls":[{"index":0,"id":"c2","function":{"name":"g","arguments":""}}]}}]}', All);
  Feed(D, '{"choices":[{"delta":{},"finish_reason":"stop"}]}', All);
  LastFr := frNone;
  for I := 0 to High(All) do
    if All[I].Kind = sdkFinish then
      LastFr := All[I].FinishReason;
  Check(LastFr = frToolCalls, 'Q-O8 stream stop+slots -> frToolCalls');
  D := NewOpenAIWireDecoder(nil);
  All := nil;
  Feed(D, '{"id":"p","model":"m","choices":[{"delta":{"content":"hi"}}]}', All);
  Feed(D, '{"choices":[{"delta":{},"finish_reason":"stop"}]}', All);
  LastFr := frNone;
  for I := 0 to High(All) do
    if All[I].Kind = sdkFinish then
      LastFr := All[I].FinishReason;
  Check(LastFr = frStop, 'Q-O8 stream pure stop stays frStop');
  D.Finalize(Fin);
end;

procedure TestQuirkO9PingSkipped;
var
  D1, D2: IAgentWireDecoder;
  Arr: TStreamDeltaArray;
  E: TWireSSEEvent;
begin
  D1 := NewOpenAIWireDecoder(nil);
  E := Default(TWireSSEEvent);
  E.Event := 'ping';
  E.Data := 'not json';
  D1.DecodeEvent(E, Arr);
  CheckEqual(Integer(0), Length(Arr), 'Q-O9 openai ping non-json 0');
  E.Data := '"keepalive"';
  D1.DecodeEvent(E, Arr);
  CheckEqual(Integer(0), Length(Arr), 'Q-O9 openai ping json string 0');
  D2 := NewResponsesWireDecoder(nil);
  E.Event := 'ping';
  E.Data := '{"type":"response.created","response":{"id":"x"}}';
  D2.DecodeEvent(E, Arr);
  CheckEqual(Integer(0), Length(Arr), 'Q-O9 responses ping json object 0');
  E.Data := '{"unknown":1}';
  D2.DecodeEvent(E, Arr);
  CheckEqual(Integer(0), Length(Arr), 'Q-O9 responses ping unknown object 0');
  // non-JSON and JSON string for responses are protocol errors, treat as skipped via exception path
  E.Data := 'not json';
  try
    D2.DecodeEvent(E, Arr);
    CheckEqual(Integer(0), Length(Arr), 'Q-O9 responses ping non-json 0 or protocol');
  except
    on Ex: EAgentError do
      Check(Ex.ErrorCode = aecProtocol, 'Q-O9 responses ping non-json protocol');
  end;
  E.Data := '"keepalive"';
  try
    D2.DecodeEvent(E, Arr);
    CheckEqual(Integer(0), Length(Arr), 'Q-O9 responses ping json string 0 or protocol');
  except
    on Ex: EAgentError do
      Check(Ex.ErrorCode = aecProtocol, 'Q-O9 responses ping json string protocol');
  end;
end;

procedure TestQuirkA4ToolResultGrouped;
var
  Req: TCompletionRequest;
  M: TMessage;
  Encoded: IJsonDocument;
  LMsgs, LContent: TJsonValue;
begin
  M := Default(TMessage);
  M.Role := mrTool;
  SetLength(M.Parts, 2);
  M.Parts[0] := Default(TPart);
  M.Parts[0].Kind := pkToolResult;
  M.Parts[0].ToolCallId := 'toolu_a';
  M.Parts[0].ResultJson := '{"r":1}';
  M.Parts[1] := Default(TPart);
  M.Parts[1].Kind := pkToolResult;
  M.Parts[1].ToolCallId := 'toolu_b';
  M.Parts[1].ResultJson := '{"r":2}';
  Req := TCompletionRequest.New('claude-m').WithMaxTokens(64);
  SetLength(Req.Messages, 1);
  Req.Messages[0] := M;
  Encoded := JsonParse(EncodeAnthropicRequest(Req, False));
  Check(not Encoded.HasError, 'Q-A4 encode parses');
  LMsgs := Encoded.Root.Get('messages');
  CheckEqual(Integer(1), Integer(LMsgs.ArrayLen), 'Q-A4 grouped single user message');
  LContent := LMsgs.ArrayGet(0).Get('content');
  CheckEqual(Integer(2), Integer(LContent.ArrayLen), 'Q-A4 two tool_result blocks');
  CheckEqual('toolu_a', LContent.ArrayGet(0).Get('tool_use_id').AsStr.ToString, 'Q-A4 first id');
  CheckEqual('toolu_b', LContent.ArrayGet(1).Get('tool_use_id').AsStr.ToString, 'Q-A4 second id');
  DecodeAnthropicResponse('{"id":"a4","type":"message","role":"assistant","model":"cm","content":[{"type":"text","text":"hi"}],"stop_reason":"end_turn","usage":{}}', M, nil);
  CheckEqual('hi', MessageText(M), 'Q-A4 decode still works');
end;

procedure TestQuirkA5ParallelToolCallsIgnored;
var
  Req: TCompletionRequest;
  J: TJsonText;
  Log: TCapturingLogger;
  LLog: ILogger;
  T: TScriptedTransport;
  Opts: TAnthropicOptions;
  P: IAgentProvider;
  M: TMessage;
  Resp: TScriptResponse;
begin
  Req := TCompletionRequest.New('claude-m').WithMaxTokens(16).WithUserText('hi');
  Req.ParallelToolCalls := tsUnset;
  J := EncodeAnthropicRequest(Req, False);
  Check(Pos('"parallel', J) = 0, 'Q-A5 unset no parallel field');
  Req.ParallelToolCalls := tsTrue;
  J := EncodeAnthropicRequest(Req, False);
  Check(Pos('"parallel', J) = 0, 'Q-A5 true still no wire field');
  Log := TCapturingLogger.Create;
  LLog := Log;
  T := TScriptedTransport.Create;
  T.ProviderName := 'anthropic';
  Resp := Default(TScriptResponse);
  Resp.Status := 200;
  Resp.BodyText := '{"id":"x","type":"message","role":"assistant","model":"m","content":[{"type":"text","text":"hi"}],"stop_reason":"end_turn","usage":{}}';
  T.Add(Resp);
  Opts := TAnthropicOptions.New('m');
  Opts.Common.ApiKey := 'k';
  Opts.Common.Logger := LLog;
  Opts.Common.Transport := T;
  P := NewAnthropicProvider(Opts);
  M := P.Complete(Req);
  CheckEqual('hi', MessageText(M), 'Q-A5 complete still works');
  Check(Log.Count > 0, 'Q-A5 warn logged');
  Check(Pos('parallel_tool_calls', Log.Lines[0]) > 0, 'Q-A5 warn mentions parallel_tool_calls');
end;

procedure TestQuirkR3FunctionFlatten;
var
  Req: TCompletionRequest;
  M: TMessage;
  J: TJsonText;
  Doc: IJsonDocument;
  LInput: TJsonValue;
begin
  M := Default(TMessage);
  M.Role := mrAssistant;
  SetLength(M.Parts, 1);
  M.Parts[0] := Default(TPart);
  M.Parts[0].Kind := pkToolCall;
  M.Parts[0].ToolCallId := 'call_9';
  M.Parts[0].ToolName := 'calc';
  M.Parts[0].ArgumentsJson := '{"x":1}';
  Req := TCompletionRequest.New('m');
  SetLength(Req.Messages, 1);
  Req.Messages[0] := M;
  J := EncodeResponsesRequest(Req, False);
  Doc := JsonParse(J);
  Check(not Doc.HasError, 'Q-R3 encode parses');
  LInput := Doc.Root.Get('input');
  CheckEqual(Integer(1), Integer(LInput.ArrayLen), 'Q-R3 single function_call flattened');
  CheckEqual('function_call', LInput.ArrayGet(0).Get('type').AsStr.ToString, 'Q-R3 type flat');
  CheckEqual('call_9', LInput.ArrayGet(0).Get('call_id').AsStr.ToString, 'Q-R3 call_id flat');
  CheckEqual('calc', LInput.ArrayGet(0).Get('name').AsStr.ToString, 'Q-R3 name flat');
  DecodeResponsesResponse('{"id":"r","object":"response","model":"m","status":"completed","output":[{"type":"function_call","id":"fc_1","call_id":"call_9","name":"calc","arguments":"{\"x\":1}"}]}', M, nil);
  Check(M.Parts[0].Kind = pkToolCall, 'Q-R3 decode tool call');
  CheckEqual('call_9', M.Parts[0].ToolCallId, 'Q-R3 decode call_id');
end;

procedure TestQuirkR4UsageDiff;
var
  M: TMessage;
  D: IAgentWireDecoder;
  All, Fin: TStreamDeltaArray;
  I: Integer;
  HasUsage: Boolean;
begin
  DecodeResponsesResponse('{"id":"r","object":"response","model":"m","status":"completed","usage":{"input_tokens":9,"output_tokens":11,"output_tokens_details":{"reasoning_tokens":3},"input_tokens_details":{"cached_tokens":2}},"output":[]}', M, nil);
  CheckEqual(Int64(9), M.Usage.InputTokens, 'Q-R4 input_tokens');
  CheckEqual(Int64(11), M.Usage.OutputTokens, 'Q-R4 output_tokens');
  CheckEqual(Int64(3), M.Usage.ReasoningTokens, 'Q-R4 reasoning_tokens');
  CheckEqual(Int64(2), M.Usage.CacheReadInputTokens, 'Q-R4 cached_tokens');
  D := NewResponsesWireDecoder(nil);
  All := nil;
  Feed(D, '{"type":"response.created","response":{"id":"r4","model":"m"}}', All);
  Feed(D, '{"type":"response.completed","response":{"id":"r4","usage":{"input_tokens":7,"output_tokens":2}}}', All);
  D.Finalize(Fin);
  AppendAll(All, Fin);
  HasUsage := False;
  for I := 0 to High(All) do
    if All[I].Kind = sdkUsage then
    begin
      HasUsage := True;
      CheckEqual(Int64(7), All[I].Usage.InputTokens, 'Q-R4 stream input');
      CheckEqual(Int64(2), All[I].Usage.OutputTokens, 'Q-R4 stream output');
    end;
  Check(HasUsage, 'Q-R4 stream usage present');
end;

{ W6：词表→wire 保真快照（response_format + tool_choice，字段序稳定）}
procedure TestEncodeRequestW6Snapshot;
const
  CExpected =
    '{"model":"m","messages":[{"role":"user","content":"hi"}],' +
    '"tools":[{"type":"function","function":{"name":"f",' +
    '"parameters":{}}}],"tool_choice":"required",' +
    '"response_format":{"type":"json_schema","json_schema":' +
    '{"name":"response","strict":true,"schema":{"type":"object"}}}}';
var
  R: TCompletionRequest;
  Spec: TToolSpec;
begin
  Spec := Default(TToolSpec);
  Spec.Name := 'f';
  R := TCompletionRequest.New('m').WithUserText('hi')
    .WithTools(TToolSpecArray.Create(Spec))
    .WithToolChoice(tcmRequired)
    .WithResponseSchema('{"type":"object"}');
  CheckEqual(CExpected, EncodeOpenAIRequest(R, False), 'W6 encode snapshot');
end;

{ ---- W18.2 最后 6 条怪癖：Q-A7/Q-A8/Q-R5/Q-R6/Q-R7 + Q-O tool 校验 ---- }

procedure TestQuirkA7RetryAfterParsed;
var
  H: TWireHeaderArray;
  E: EAgentError;
begin
  // 秒级头 ×1000
  SetLength(H, 1);
  H[0].Name := 'retry-after';
  H[0].Value := '2';
  CheckEqual(Int64(2000), ParseRetryAfterMs(H), 'Q-A7 seconds scaled to ms');
  // ms 头直通
  SetLength(H, 1);
  H[0].Name := 'retry-after-ms';
  H[0].Value := '750';
  CheckEqual(Int64(750), ParseRetryAfterMs(H), 'Q-A7 ms header parsed');
  // ms 优先于秒级
  SetLength(H, 2);
  H[0].Name := 'retry-after-ms';
  H[0].Value := '250';
  H[1].Name := 'retry-after';
  H[1].Value := '9';
  CheckEqual(Int64(250), ParseRetryAfterMs(H), 'Q-A7 ms priority');
  // HTTP-date 形态不解析 -> unknown
  SetLength(H, 1);
  H[0].Name := 'retry-after';
  H[0].Value := 'Wed, 21 Oct 2015 07:28:00 GMT';
  CheckEqual(CRetryAfterUnknown, ParseRetryAfterMs(H), 'Q-A7 http-date unknown');
  // anthropic 429 秒级路径 via BuildUpstreamError
  SetLength(H, 1);
  H[0].Name := 'retry-after';
  H[0].Value := '3';
  E := BuildUpstreamError('anthropic', '{"error":{"message":"rate limited"}}', 429, H);
  try
    Check(E.ErrorCode = aecRateLimited, 'Q-A7 429 maps rate_limited');
    CheckEqual(Int64(3000), E.RetryAfterMs, 'Q-A7 anthropic seconds -> 3000ms');
  finally
    E.Free;
  end;
  SetLength(H, 1);
  H[0].Name := 'retry-after-ms';
  H[0].Value := '1234';
  E := BuildUpstreamError('anthropic', '{"error":{"message":"rate limited"}}', 429, H);
  try
    CheckEqual(Int64(1234), E.RetryAfterMs, 'Q-A7 anthropic ms -> 1234ms');
  finally
    E.Free;
  end;
end;

procedure TestQuirkA8TruncatedStreamFailClosed;
var
  D: IAgentWireDecoder;
  All, Fin: TStreamDeltaArray;
  Raised: Boolean;
begin
  // 有 message_start 但无 message_stop -> fail-closed 抛 aecProtocol 含 Q-A8 字面
  D := NewAnthropicWireDecoder(nil);
  All := nil;
  FeedEv(D, 'message_start',
    '{"type":"message_start","message":{"id":"a8","model":"cm"}}', All);
  FeedEv(D, 'content_block_start',
    '{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}', All);
  FeedEv(D, 'content_block_delta',
    '{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"half"}}', All);
  Raised := False;
  try
    D.Finalize(Fin);
  except
    on Ex: EAgentError do
      Raised := (Ex.ErrorCode = aecProtocol) and (Pos('Q-A8 fail-closed', Ex.Message) > 0)
        and (Pos('<stream>', Ex.RawBodySnippet) > 0);
  end;
  Check(Raised, 'Q-A8 truncated without message_stop => aecProtocol Q-A8 fail-closed');
  // 缺首信封同样 fail-closed
  D := NewAnthropicWireDecoder(nil);
  Raised := False;
  try
    D.Finalize(Fin);
  except
    on Ex: EAgentError do
      Raised := (Ex.ErrorCode = aecProtocol) and (Pos('Q-A8 fail-closed', Ex.Message) > 0);
  end;
  Check(Raised, 'Q-A8 missing start also fail-closed');
end;

procedure TestQuirkR5TruncatedStreamFailClosed;
var
  D: IAgentWireDecoder;
  Fin: TStreamDeltaArray;
  Raised: Boolean;
  E: TWireSSEEvent;
begin
  // 有 created 无 terminal -> fail-closed 含 truncated stream 字面
  D := NewResponsesWireDecoder(nil);
  E := Default(TWireSSEEvent);
  E.Event := 'response.created';
  E.Data := '{"type":"response.created","response":{"id":"r5","model":"m"}}';
  D.DecodeEvent(E, Fin);
  Raised := False;
  try
    D.Finalize(Fin);
  except
    on Ex: EAgentError do
      Raised := (Ex.ErrorCode = aecProtocol) and (Pos('truncated stream', Ex.Message) > 0);
  end;
  Check(Raised, 'Q-R5 truncated without terminal => aecProtocol truncated stream');
  // 完全缺 envelope 同样 fail-closed
  D := NewResponsesWireDecoder(nil);
  Raised := False;
  try
    D.Finalize(Fin);
  except
    on Ex: EAgentError do
      Raised := Ex.ErrorCode = aecProtocol;
  end;
  Check(Raised, 'Q-R5 missing envelope also fail-closed');
end;

procedure TestQuirkR6TextFormatStructuredOutput;
var
  R: TCompletionRequest;
  J: TJsonText;
  Doc: IJsonDocument;
begin
  R := TCompletionRequest.New('m').WithResponseSchema('{"type":"object"}');
  J := EncodeResponsesRequest(R, False);
  Doc := JsonParse(J);
  Check(not Doc.HasError, 'Q-R6 encode parses');
  Check(Doc.Root.Get('text').Get('format').Get('type').AsStr.ToString = 'json_schema', 'Q-R6 text.format type json_schema');
  Check(Doc.Root.Get('text').Get('format').Get('strict').AsBool, 'Q-R6 strict true');
  CheckEqual('response', Doc.Root.Get('text').Get('format').Get('name').AsStr.ToString, 'Q-R6 name response');
  Check(Doc.Root.Get('text').Get('format').Get('schema').Get('type').AsStr.ToString = 'object', 'Q-R6 schema passthrough');
  Check(Pos('"text":{"format"', J) > 0, 'Q-R6 literal text.format');
  Check(Pos('"response_format"', J) = 0, 'Q-R6 no response_format');
end;

procedure TestQuirkR7SubsetMissingTolerance;
var
  M: TMessage;
  D: IAgentWireDecoder;
  All, Fin: TStreamDeltaArray;
  E: TWireSSEEvent;
begin
  // 非流式缺失可选字段子集仍容忍（最小 payload）
  DecodeResponsesResponse('{"id":"r","object":"response","model":"m","status":"completed","output":[]}', M, nil);
  Check(M.FinishReason = frStop, 'Q-R7 minimal completed => frStop');
  DecodeResponsesResponse('{"object":"response","output":[]}', M, nil);
  Check(M.FinishReason = frStop, 'Q-R7 missing id/model/status still frStop');
  DecodeResponsesResponse('{"id":"r","object":"response","model":"m","status":"incomplete","output":[]}', M, nil);
  Check(M.FinishReason = frLength, 'Q-R7 incomplete => frLength');
  // 流式子集：created 空 response 对象仍产 envelope
  D := NewResponsesWireDecoder(nil);
  All := nil;
  E := Default(TWireSSEEvent);
  E.Event := 'response.created';
  E.Data := '{"type":"response.created","response":{}}';
  D.DecodeEvent(E, All);
  Check((Length(All) = 1) and (All[0].Kind = sdkEnvelope), 'Q-R7 stream minimal created tolerated');
  E.Event := 'response.output_text.delta';
  E.Data := '{"type":"response.output_text.delta","delta":"hi"}';
  D.DecodeEvent(E, All);
  Check(True, 'Q-R7 delta after minimal envelope tolerated');
  E.Event := 'response.completed';
  E.Data := '{"type":"response.completed","response":{"id":"r"}}';
  D.DecodeEvent(E, All);
  Check(True, 'Q-R7 minimal completed tolerates missing usage');
  D.Finalize(Fin);
  Check(True, 'Q-R7 minimal trajectory finalizes clean');
end;

procedure TestQuirkOToolValidation;
var
  R: TCompletionRequest;
  Spec: TToolSpec;
  Raised: Boolean;
begin
  // openai 家族 tool_choice 校验：具名缺名 / 空 Tools 抛 aecConfig（decoder 层最小 payload 的对照：编码侧 fail-fast）
  Spec := Default(TToolSpec);
  Spec.Name := 'f';
  R := TCompletionRequest.New('m').WithTools(TToolSpecArray.Create(Spec)).WithToolChoice(tcmNamed, '');
  Raised := False;
  try
    EncodeOpenAIRequest(R, False);
  except
    on Ex: EAgentError do
      Raised := Ex.ErrorCode = aecConfig;
  end;
  Check(Raised, 'Q-O named without name => aecConfig');
  R := TCompletionRequest.New('m').WithToolChoice(tcmRequired);
  Raised := False;
  try
    EncodeOpenAIRequest(R, False);
  except
    on Ex: EAgentError do
      Raised := Ex.ErrorCode = aecConfig;
  end;
  Check(Raised, 'Q-O tool_choice requires Tools');
  // responses 同族校验亦然（最小 payload 复用同一基校验）
  Spec.Name := 'g';
  R := TCompletionRequest.New('m').WithTools(TToolSpecArray.Create(Spec)).WithToolChoice(tcmNamed, '');
  Raised := False;
  try
    EncodeResponsesRequest(R, False);
  except
    on Ex: EAgentError do
      Raised := Ex.ErrorCode = aecConfig;
  end;
  Check(Raised, 'Q-O responses named without name => aecConfig');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.codecs');
  T.Test('encode request W6 snapshot', @TestEncodeRequestW6Snapshot);
  T.Test('roundtrip extra fidelity', @TestRoundtripExtraFidelity);
  T.Test('unmapped enum zero and warn', @TestUnmappedEnumZeroAndWarn);
  T.Test('violation carries snippet', @TestViolationCarriesSnippet);
  T.Test('cross broken frame equivalence', @TestCrossBrokenFrameEquivalence);
  T.Test('finalize order equivalence', @TestFinalizeOrderEquivalence);
  T.Test('parallel decoders independent', @TestParallelDecodersIndependent);
  T.Test('anthropic roundtrip extra fidelity',
    @TestAnthropicRoundtripExtraFidelity);
  T.Test('anthropic violation carries snippet',
    @TestAnthropicViolationCarriesSnippet);
  T.Test('anthropic cross broken frame equivalence',
    @TestAnthropicCrossBrokenFrameEquivalence);
  T.Test('anthropic finalize order equivalence',
    @TestAnthropicFinalizeOrderEquivalence);
  T.Test('anthropic parallel decoders independent',
    @TestAnthropicParallelDecodersIndependent);
  T.Test('Q-O6 empty choices skipped', @TestQuirkO6EmptyChoicesSkipped);
  T.Test('Q-O4 no DONE EOF graceful', @TestQuirkO4NoDoneEOFGraceful);
  T.Test('Q-A6 input_json_delta accumulated', @TestQuirkA6InputJsonDeltaAccumulated);
  T.Test('Q-R2 event dispatch', @TestQuirkR2EventDispatch);
  T.Test('unknown event skipped', @TestQuirkUnknownEventSkipped);
  T.Test('Q-A1 message_start required', @TestQuirkA1MessageStartRequired);
  T.Test('Q-O1 max_completion_tokens rename tolerance', @TestQuirkO1MaxCompletionTokensRenameTolerance);
  T.Test('Q-O2 reasoning_content thinking delta', @TestQuirkO2ReasoningContentThinkingDelta);
  T.Test('Q-O3 include_usage harmless', @TestQuirkO3IncludeUsageHarmless);
  T.Test('Q-O5 tool slot delayed naming missing index', @TestQuirkO5ToolSlotDelayedNamingMissingIndex);
  T.Test('Q-O7 multi choice discard warn', @TestQuirkO7MultiChoiceDiscardWarn);
  T.Test('Q-A3 thinking signature passthrough', @TestQuirkA3ThinkingSignaturePassthrough);
  T.Test('Q-R1 stop_sequences ignored warn', @TestQuirkR1StopSequencesIgnoredWarn);
  T.Test('Q-O8 stop+tool_calls corrected', @TestQuirkO8StopToolCallsCorrected);
  T.Test('Q-O9 ping skipped', @TestQuirkO9PingSkipped);
  T.Test('Q-A4 tool_result grouped', @TestQuirkA4ToolResultGrouped);
  T.Test('Q-A5 parallel_tool_calls ignored', @TestQuirkA5ParallelToolCallsIgnored);
  T.Test('Q-R3 function flatten', @TestQuirkR3FunctionFlatten);
  T.Test('Q-R4 usage diff', @TestQuirkR4UsageDiff);
  T.Test('Q-A7 retry-after parsed', @TestQuirkA7RetryAfterParsed);
  T.Test('Q-A8 truncated stream fail-closed', @TestQuirkA8TruncatedStreamFailClosed);
  T.Test('Q-R5 truncated stream fail-closed', @TestQuirkR5TruncatedStreamFailClosed);
  T.Test('Q-R6 text.format structured output', @TestQuirkR6TextFormatStructuredOutput);
  T.Test('Q-R7 subset missing tolerance', @TestQuirkR7SubsetMissingTolerance);
  T.Test('Q-O tool validation', @TestQuirkOToolValidation);
  if not T.Run then Halt(1);
end.
