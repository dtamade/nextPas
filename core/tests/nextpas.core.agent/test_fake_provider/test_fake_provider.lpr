program test_fake_provider;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.async.cancellation,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.provider.fake,
  nextpas.core.test;

{ fake/scripted provider 自身语义（API.md §7；TESTING §3 test_fake_provider 行）：
  脚本回放顺序、耗尽再调抛错、echo 桩、EOF 前访问 misuse }

const
  CScript2 =
    '[{"deltas":[{"kind":"text_delta","text":"A"}]},' +
     '{"deltas":[{"kind":"text_delta","text":"B"}]}]';

  CScriptTool =
    '[{"deltas":[' +
      '{"kind":"envelope","id":"msg_1","model":"fake-x"},' +
      '{"kind":"tool_call_start","index":0,"id":"call_1","name":"weather"},' +
      '{"kind":"tool_call_delta","index":0,"args":"{\"city\":\"上海\"}"},' +
      '{"kind":"tool_call_end","index":0},' +
      '{"kind":"finish","reason":"tool_calls"},' +
      '{"kind":"usage","in":12,"out":34} ]}]';

procedure TestReplayOrder;
var
  P: IAgentProvider;
  M: TMessage;
begin
  P := NewFakeProvider(CScript2);
  M := P.Complete(TCompletionRequest.New('m'));
  Check(MessageText(M) = 'A', 'first script first');
  M := P.Complete(TCompletionRequest.New('m'));
  Check(MessageText(M) = 'B', 'second script second');
end;

procedure TestW6FieldsDoNotAffectReplay;
var
  P: IAgentProvider;
  M: TMessage;
  R: TCompletionRequest;
begin
  { W6 词表字段对回放路径零影响：脚本即所得，不校验 schema }
  P := NewFakeProvider(CScript2);
  R := TCompletionRequest.New('m').WithUserText('hi')
    .WithResponseSchema('{"type":"object"}')
    .WithToolChoice(tcmRequired);
  M := P.Complete(R);
  Check(MessageText(M) = 'A', 'replay first with W6 fields');
end;

procedure TestStreamFoldAndEnvelope;
var
  P: IAgentProvider;
  C: IAgentCompletion;
  D: TStreamDelta;
  M: TMessage;
begin
  P := NewFakeProvider(CScriptTool);
  C := P.Stream(TCompletionRequest.New('m'));
  { 逐 delta 拉取：信封 + 工具三件套 + finish + usage }
  Check(C.NextDelta(D) and (D.Kind = sdkEnvelope), 'envelope delta');
  Check(C.NextDelta(D) and (D.Kind = sdkToolCallStart), 'start delta');
  Check(C.NextDelta(D) and (D.Kind = sdkToolCallDelta), 'args delta');
  Check(C.NextDelta(D) and (D.Kind = sdkToolCallEnd), 'end delta');
  Check(C.NextDelta(D) and (D.Kind = sdkFinish), 'finish delta');
  Check(C.NextDelta(D) and (D.Kind = sdkUsage), 'usage delta');
  Check(not C.NextDelta(D), 'eof after script');
  M := C.GetMessage;
  Check(M.Id = 'msg_1', 'message id from envelope');
  Check(M.Model = 'fake-x', 'model from envelope');
  Check(M.FinishReason = frToolCalls, 'finish folded');
  Check((Length(M.Parts) = 1) and (M.Parts[0].Kind = pkToolCall),
    'tool part folded');
  Check(M.Parts[0].ArgumentsJson = '{"city":"上海"}', 'args folded utf8');
  Check((M.Usage.InputTokens = 12) and (M.Usage.OutputTokens = 34),
    'usage mapped from in/out');
  { EOF 后重复 GetMessage 稳定 }
  Check(C.GetMessage.FinishReason = frToolCalls, 'get message repeatable');
end;

procedure TestExhaustionRaises;
var
  P: IAgentProvider;
  M: TMessage;
  C: IAgentCompletion;
  D: TStreamDelta;
begin
  P := NewFakeProvider('[{"deltas":[]}]');
  M := P.Complete(TCompletionRequest.New('m'));
  Check(M.IsEmpty, 'empty deltas fold to empty message');
  try
    P.Complete(TCompletionRequest.New('m'));
    Check(False, 'exhausted Complete must raise');
  except
    on E: EAgentError do
      Check(E.ErrorCode = aecProtocol, 'exhaustion is protocol error');
  end;
  try
    C := P.Stream(TCompletionRequest.New('m'));
    Check(False, 'exhausted Stream must raise');
  except
    on E: EAgentError do
      Check(E.ErrorCode = aecProtocol, 'stream exhaustion protocol too');
  end;
end;

procedure TestEchoProvider;
var
  P: IAgentProvider;
  Req: TCompletionRequest;
  M: TMessage;
  C: IAgentCompletion;
  D: TStreamDelta;
begin
  P := NewEchoProvider;
  Req := TCompletionRequest.New('m')
    .WithUserText('你好，世界').WithUserText('final words');
  M := P.Complete(Req);
  Check(MessageText(M) = 'final words', 'echo returns last user text');
  C := P.Stream(Req);
  Check(C.NextDelta(D) and (D.TextDelta = 'final words'),
    'echo stream single delta');
  Check(not C.NextDelta(D), 'echo stream ends');
  Check(P.GetName = 'fake', 'name fake');
end;

procedure TestGetMessageBeforeEofMisuse;
var
  P: IAgentProvider;
  C: IAgentCompletion;
  D: TStreamDelta;
begin
  P := NewFakeProvider(CScript2);
  C := P.Stream(TCompletionRequest.New('m'));
  Check(C.NextDelta(D), 'first delta ok');
  try
    C.GetMessage;
    Check(False, 'GetMessage before EOF must raise');
  except
    on E: EAgentError do
      Check((E.ErrorCode = aecProtocol) and (Pos('completion not drained', E.Message) > 0), 'aecProtocol completion not drained (F-H20)');
    on E: Exception do
      Check(False, 'wrong exception class');
  end;
  { Cancel 后 NextDelta 即 EOF；仍不可取消息（未折叠）}
  C.Cancel;
  Check(C.GetCancelled and (not C.NextDelta(D)), 'cancel ends pull');
end;

procedure TestMalformedScripts;
var
  Code: TAgentErrorCode;

  function TryBad(const AJson: string): Boolean;
  begin
    Result := False;
    try
      NewFakeProvider(AJson);
    except
      on E: EAgentError do
      begin
        Code := E.ErrorCode;
        Result := True;
      end;
    end;
  end;

begin
  Check(TryBad('{"not":"array"}') and (Code = aecProtocol),
    'root not array is protocol');
  Check(TryBad('[{"no_deltas":1}]') and (Code = aecProtocol),
    'missing deltas is protocol');
  Check(TryBad('[{"deltas":[{"kind":"warp_delta"}]}]')
    and (Code = aecProtocol), 'unknown kind is protocol');
  Check(TryBad('[{"deltas":[{"kind":"finish","reason":"wat"}]}]')
    and (Code = aecProtocol), 'unknown reason is protocol');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.fake_provider');
  T.Test('replay order', @TestReplayOrder);
  T.Test('W6 fields do not affect replay', @TestW6FieldsDoNotAffectReplay);
  T.Test('stream fold and envelope', @TestStreamFoldAndEnvelope);
  T.Test('exhaustion raises', @TestExhaustionRaises);
  T.Test('echo provider', @TestEchoProvider);
  T.Test('get message before eof misuse', @TestGetMessageBeforeEofMisuse);
  T.Test('malformed scripts', @TestMalformedScripts);
  if not T.Run then Halt(1);
end.
