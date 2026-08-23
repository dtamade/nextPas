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
  agent.testkit,
  nextpas.core.test;

{ 公开编解码器（D13；TESTING §3 test_codecs 行，openai 部分）：
  wire→Decode→词表→Encode 语义等价往返（Extra 保真）、未映射枚举→零值+
  agent.unmapped.*+warn、协议违例抛 aecProtocol 带 RawBodySnippet、
  跨断裂帧与 Finalize 双序等价、网关式双角色并行解码互不污染。
  anthropic 对应条目随 W2 落位 }

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

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.codecs');
  T.Test('roundtrip extra fidelity', @TestRoundtripExtraFidelity);
  T.Test('unmapped enum zero and warn', @TestUnmappedEnumZeroAndWarn);
  T.Test('violation carries snippet', @TestViolationCarriesSnippet);
  T.Test('cross broken frame equivalence', @TestCrossBrokenFrameEquivalence);
  T.Test('finalize order equivalence', @TestFinalizeOrderEquivalence);
  T.Test('parallel decoders independent', @TestParallelDecodersIndependent);
  if not T.Run then Halt(1);
end.
