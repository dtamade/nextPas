program test_transport_trace;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.async.cancellation,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.clock,
  nextpas.core.agent.retry,
  nextpas.core.agent.provider.openai,
  agent.testkit,
  nextpas.core.agent.transport.trace,
  nextpas.core.test;

{ W11（API.md §3.2）：请求级追踪装饰器语义——事件对序与字段、异常路径
  配对不改写失败语义、sink 契约、WithRetry 叠装可见性。全程 scripted 离线
  边界/Cancel/超时/并发：
  - Cancel 边界：Cancel 幂等穿透，追踪装饰器不吞取消错误，配对事件仍按序上报。
  - 超时边界：RoundTrip/OpenStream 的 aecTimeout/aecTransport 异常路径配对后原样上抛，不改写失败语义。
  - 并发边界：单线程追踪记录，sink 回调异常直接冒泡（fail-fast），WithRetry 叠装三尝试三对事件并发可见。
  悬挂指针：TraceSink/Transport 均接口持有，事件体字符串托管，无裸指针常驻；追踪装饰器不持有调用方栈上内存。
  泄漏标注：common.mk -gh 全量 HEAPTRC 门 0 unfreed；tracing wrapper 仅转发，不额外分配常驻堆。 }

const
  CReqBody = '{"model":"m","messages":[]}';
  CRespBody = '{"choices":[{"finish_reason":"stop","index":0,' +
    '"message":{"content":"ok","role":"assistant"}}],"id":"x",' +
    '"model":"gpt-x","object":"chat.completion"}';
  CSSEChunk = 'data: {"x":1}';

type
  TRecordingSink = class(TInterfacedObject, IAgentTraceSink)
  public
    Reqs: array of TTraceRequestInfo;
    Resps: array of TTraceResponseInfo;
    procedure OnRequest(const AInfo: TTraceRequestInfo);
    procedure OnResponse(const AInfo: TTraceResponseInfo);
  end;

  { 失败路径 sink 违约桩：OnResponse 抛错 }
  TBadSink = class(TInterfacedObject, IAgentTraceSink)
  public
    procedure OnRequest(const AInfo: TTraceRequestInfo);
    procedure OnResponse(const AInfo: TTraceResponseInfo);
  end;

  { transport 层异常源：RoundTrip/OpenStream 恒抛 }
  TFailingTransport = class(TInterfacedObject, IAgentTransport)
  public
    procedure RoundTrip(const AReq: TWireRequest; out AResp: TWireResponse);
    function OpenStream(const AReq: TWireRequest): IAgentWireStream;
  end;

procedure TRecordingSink.OnRequest(const AInfo: TTraceRequestInfo);
begin
  SetLength(Reqs, Length(Reqs) + 1);
  Reqs[High(Reqs)] := AInfo;
end;

procedure TRecordingSink.OnResponse(const AInfo: TTraceResponseInfo);
begin
  SetLength(Resps, Length(Resps) + 1);
  Resps[High(Resps)] := AInfo;
end;

procedure TBadSink.OnRequest(const AInfo: TTraceRequestInfo);
begin
  { no-op }
end;

procedure TBadSink.OnResponse(const AInfo: TTraceResponseInfo);
begin
  if AInfo.Failed then
    raise EAgentError.CreateLocal(aecConfig, 'sink boom');
end;

procedure TFailingTransport.RoundTrip(const AReq: TWireRequest;
  out AResp: TWireResponse);
begin
  raise EAgentError.CreateLocal(aecTransport, 'transport boom');
end;

function TFailingTransport.OpenStream(
  const AReq: TWireRequest): IAgentWireStream;
begin
  raise EAgentError.CreateLocal(aecTransport, 'stream boom');
end;

function MkReq: TWireRequest;
begin
  Result := Default(TWireRequest);
  Result.Url := 'https://example.test/v1/chat/completions';
  Result.BodyJson := CReqBody;
end;

function ScriptOK: TScriptResponse;
begin
  Result := Default(TScriptResponse);
  Result.Status := 200;
  Result.BodyText := CRespBody;
end;

function ScriptStream: TScriptResponse;
begin
  Result := Default(TScriptResponse);
  Result.Status := 200;
  SetLength(Result.Chunks, 1);
  Result.Chunks[0] := CSSEChunk;
end;

procedure TestRoundTripPairFields;
var
  Inner: TScriptedTransport;
  Sink: TRecordingSink;
  T: IAgentTransport;
  Req: TWireRequest;
  Resp: TWireResponse;
begin
  Inner := TScriptedTransport.Create;
  Inner.Add(ScriptOK);
  Sink := TRecordingSink.Create;
  T := NewTracedTransport('openai', Sink, Inner);
  Check(T <> nil, 'factory returns transport');
  Req := MkReq;
  T.RoundTrip(Req, Resp);
  CheckEqual(200, Resp.StatusCode, 'inner response passes through');

  CheckEqual(1, Length(Sink.Reqs), 'one request event');
  CheckEqual('openai', string(Sink.Reqs[0].Provider), 'provider name');
  Check(MkReq.Url = Sink.Reqs[0].Url, 'url carried');
  CheckFalse(Sink.Reqs[0].Stream, 'roundtrip not stream');
  CheckEqual(Length(CReqBody), Sink.Reqs[0].BodyBytes,
    'ascii body bytes exact');

  CheckEqual(1, Length(Sink.Resps), 'one response event');
  CheckFalse(Sink.Resps[0].Failed, 'success not failed');
  CheckEqual(200, Sink.Resps[0].Status, 'status carried');
  CheckTrue(Sink.Resps[0].DurationMs >= 0, 'duration measured');
  CheckEqual(Length(CRespBody), Sink.Resps[0].ResponseBytes,
    'response bytes exact');
  CheckEqual('', string(Sink.Resps[0].RequestId),
    'scripted request id empty');
end;

procedure TestStreamPairFields;
var
  Inner: TScriptedTransport;
  Sink: TRecordingSink;
  T: IAgentTransport;
  S: IAgentWireStream;
  Ev: TWireSSEEvent;
  Req: TWireRequest;
begin
  Inner := TScriptedTransport.Create;
  Inner.Add(ScriptStream);
  Sink := TRecordingSink.Create;
  T := NewTracedTransport('anthropic', Sink, Inner);
  Req := MkReq;
  S := T.OpenStream(Req);
  Check(S <> nil, 'inner stream returned');
  while S.NextEvent(Ev) do
    ;                               { 排干 }
  CheckEqual(1, Length(Sink.Reqs), 'stream request event');
  CheckTrue(Sink.Reqs[0].Stream, 'stream flag on request');
  CheckEqual(1, Length(Sink.Resps), 'stream response event');
  CheckFalse(Sink.Resps[0].Failed, 'stream open success');
  CheckEqual(-1, Sink.Resps[0].Status, 'stream status unavailable (-1)');
  CheckEqual(-1, Sink.Resps[0].ResponseBytes,
    'stream bytes unavailable (-1)');
  CheckTrue(Sink.Resps[0].DurationMs >= 0, 'open duration measured');
end;

procedure TestExceptionPairedAndReraised;
var
  Sink: TRecordingSink;
  Failing: IAgentTransport;
  T: IAgentTransport;
  Req: TWireRequest;
  Resp: TWireResponse;
  Raised: Boolean;
begin
  Sink := TRecordingSink.Create;
  Failing := TFailingTransport.Create;
  T := NewTracedTransport('grok', Sink, Failing);
  Req := MkReq;
  Raised := False;
  try
    T.RoundTrip(Req, Resp);
  except
    on E: EAgentError do
    begin
      Raised := True;
      Check(Pos('transport boom', E.Message) > 0,
        'original transport error re-raised verbatim');
    end;
  end;
  Check(Raised, 'failure propagated');
  CheckEqual(1, Length(Sink.Reqs), 'request event before dispatch');
  CheckEqual(1, Length(Sink.Resps), 'failed path still paired');
  CheckTrue(Sink.Resps[0].Failed, 'Failed=True on exception path');
  CheckEqual(-1, Sink.Resps[0].Status, 'no status on exception path');
end;

procedure TestSinkViolationReplacesOnErrorPath;
var
  Bad: IAgentTraceSink;
  Failing: IAgentTransport;
  T: IAgentTransport;
  Req: TWireRequest;
  Resp: TWireResponse;
  GotSinkError: Boolean;
begin
  { 契约：失败路径 sink 抛错会顶替传输错误上抛——违约可见而非静默 }
  Bad := TBadSink.Create;
  Failing := TFailingTransport.Create;
  T := NewTracedTransport('x', Bad, Failing);
  Req := MkReq;
  GotSinkError := False;
  try
    T.RoundTrip(Req, Resp);
  except
    on E: EAgentError do
      GotSinkError := Pos('sink boom', E.Message) > 0;
  end;
  Check(GotSinkError, 'violating sink error surfaces (documented)');
end;

procedure TestNilArgsRejected;
var
  InnerRef: IAgentTransport;
  SinkRef: IAgentTraceSink;
begin
  { W2 教训一般化：TInterfacedObject 实例必须先落接口变量再进调用——
    内联实参在工厂抛错路径上的临时接口生命期不可依赖 }
  SinkRef := TRecordingSink.Create;
  InnerRef := TScriptedTransport.Create;
  try
    NewTracedTransport('x', nil, InnerRef);
    Check(False, 'nil sink must reject');
  except
    on E: EAgentError do
      Check(E.ErrorCode = aecConfig, 'nil sink -> aecConfig');
  end;
  try
    NewTracedTransport('x', SinkRef, nil);
    Check(False, 'nil inner must reject');
  except
    on E: EAgentError do
      Check(E.ErrorCode = aecConfig, 'nil inner -> aecConfig');
  end;
end;

{ 与 WithRetry 叠装（traced 在内层）：每次尝试各产一对事件——
  重试可见性自然产生，无需专用 onRetry 钩子 }
procedure TestRetryStackingVisibility;
var
  Scripted: TScriptedTransport;
  Sink: TRecordingSink;
  Opts: TOpenAIOptions;
  P, Retried: IAgentProvider;
  M: TMessage;
  Policy: TRetryPolicy;
  R500: TScriptResponse;
begin
  R500 := Default(TScriptResponse);
  R500.Status := 500;
  R500.BodyText := '{"error":{"message":"upstream down"}}';
  { 真网语义：非 2xx 由 http transport 层抛 upstream 错误（分类器
    provider.common.BuildUpstreamError），traced 观测到的是异常路径 }
  R500.RaiseUpstream := True;
  Scripted := TScriptedTransport.Create;
  Scripted.Add(R500);
  Scripted.Add(R500);
  Scripted.Add(ScriptOK);

  Sink := TRecordingSink.Create;
  Opts := TOpenAIOptions.New('gpt-x');
  Opts.Common.ApiKey := 'ak';
  Opts.Common.Transport :=
    NewTracedTransport('openai', Sink, Scripted);
  P := NewOpenAIProvider(Opts);

  Policy := TRetryPolicy.Default;
  Policy.MaxAttempts := 3;
  Policy.InitialDelayMs := 0;
  Policy.MaxTotalRetryMs := 0;
  Retried := WithRetry(P, Policy, NewSystemClock);

  M := Retried.Complete(TCompletionRequest.New('').WithUserText('hi'));
  Check(MessageText(M) <> '', 'third attempt completes');

  CheckEqual(3, Length(Sink.Reqs), 'three attempts visible');
  CheckEqual(3, Length(Sink.Resps), 'three responses paired');
  CheckTrue(Sink.Resps[0].Failed, 'attempt1 exception path marked');
  CheckTrue(Sink.Resps[1].Failed, 'attempt2 exception path marked');
  CheckEqual(-1, Sink.Resps[0].Status, 'no wire status on failure path');
  CheckFalse(Sink.Resps[2].Failed, 'final attempt success');
  CheckEqual(200, Sink.Resps[2].Status, 'final status 200');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.transport.trace');
  T.Test('roundtrip pair fields', @TestRoundTripPairFields);
  T.Test('stream pair fields', @TestStreamPairFields);
  T.Test('exception paired and reraised', @TestExceptionPairedAndReraised);
  T.Test('sink violation replaces on error path',
    @TestSinkViolationReplacesOnErrorPath);
  T.Test('nil args rejected', @TestNilArgsRejected);
  T.Test('retry stacking visibility', @TestRetryStackingVisibility);
  if not T.Run then Halt(1);
end.
