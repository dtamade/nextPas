program test_transport_stream;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  agent.testkit,
  nextpas.core.test;

{ 流式传输时序（TESTING §3 test_transport_stream 行）：
  scripted chunk 流验证真增量——喂 chunk N 即产出对应事件（不等到 EOF）；
  Cancel 中途立即返回 False 且 GetCancelled=True；非流式 RoundTrip
  脚本回放与耗尽归因 }

procedure TestIncrementalTiming;
var
  T: TScriptedTransport;
  S: TStringArray;
  LScript: TScriptResponse;
  W: IAgentWireStream;
  Ev: TWireSSEEvent;
begin
  T := TScriptedTransport.Create;
  try
    S := TStringArray.Create(
      'data: A'#10#10,
      'data: B'#10#10,
      'data: C'#10#10);
    LScript := Default(TScriptResponse);
    LScript.Status := 200;
    LScript.Chunks := S;
    T.Add(LScript);
    W := T.OpenStream(Default(TWireRequest));
    { chunk 边界即事件产出边界：逐块喂入，事件按序出现 }
    Check(W.NextEvent(Ev) and (Ev.Data = 'A'), 'event A from chunk1');
    Check(W.NextEvent(Ev) and (Ev.Data = 'B'), 'event B from chunk2');
    Check(W.NextEvent(Ev) and (Ev.Data = 'C'), 'event C from chunk3');
    Check(not W.NextEvent(Ev), 'eof after all chunks');
    Check(not W.NextEvent(Ev), 'eof idempotent on repeat calls');
    Check(not W.GetCancelled, 'not cancelled on natural eof');
  finally
    T.Free;
  end;
end;

procedure TestCancelMidStream;
var
  T: TScriptedTransport;
  S: TStringArray;
  LScript: TScriptResponse;
  W: IAgentWireStream;
  Ev: TWireSSEEvent;
begin
  T := TScriptedTransport.Create;
  try
    S := TStringArray.Create('data: one'#10#10, 'data: two'#10#10);
    LScript := Default(TScriptResponse);
    LScript.Status := 200;
    LScript.Chunks := S;
    T.Add(LScript);
    W := T.OpenStream(Default(TWireRequest));
    Check(W.NextEvent(Ev) and (Ev.Data = 'one'), 'first event ok');
    W.Cancel;
    Check(W.GetCancelled, 'cancelled flag visible immediately');
    Check(not W.NextEvent(Ev), 'cancel makes next event return false');
  finally
    T.Free;
  end;
end;

procedure TestHalfChunkStateKept;
var
  T: TScriptedTransport;
  S: TStringArray;
  LScript: TScriptResponse;
  W: IAgentWireStream;
  Ev: TWireSSEEvent;
begin
  { 帧跨 chunk 断裂经 transport 层仍完整 }
  T := TScriptedTransport.Create;
  try
    S := TStringArray.Create('data: he', 'llo'#10#10'data: x'#10#10);
    LScript := Default(TScriptResponse);
    LScript.Status := 200;
    LScript.Chunks := S;
    T.Add(LScript);
    W := T.OpenStream(Default(TWireRequest));
    Check(W.NextEvent(Ev) and (Ev.Data = 'hello'), 'split frame intact');
    Check(W.NextEvent(Ev) and (Ev.Data = 'x'), 'second frame after split');
    Check(not W.NextEvent(Ev), 'eof');
  finally
    T.Free;
  end;
end;

procedure TestRoundTripScripted;
var
  T: TScriptedTransport;
  R1, R2: TScriptResponse;
  Hdrs: TWireHeaderArray;
  Resp: TWireResponse;
begin
  T := TScriptedTransport.Create;
  SetLength(Hdrs, 1);
  Hdrs[0].Name := 'x-request-id';
  Hdrs[0].Value := 'req-7';
  R1 := Default(TScriptResponse);
  R1.Status := 200;
  R1.Headers := Hdrs;
  R1.BodyText := '{"ok":true}';
  T.Add(R1);
  R2 := Default(TScriptResponse);
  R2.Status := 429;
  R2.BodyText := 'rate limited';
  T.Add(R2);
  try
    T.RoundTrip(Default(TWireRequest), Resp);
    Check(Resp.StatusCode = 200, 'status passed through');
    Check(Resp.RequestId = 'req-7', 'request id probed');
    Check(Resp.BodyText = '{"ok":true}', 'body passed through');
    T.RoundTrip(Default(TWireRequest), Resp);
    Check(Resp.StatusCode = 429, 'second script entry replayed');
    try
      T.RoundTrip(Default(TWireRequest), Resp);
      Check(False, 'exhausted script must raise');
    except
      on E: EAgentError do
        Check(E.ErrorCode = aecProtocol, 'exhaustion is protocol error');
    end;
  finally
    T.Free;
  end;
end;

var
  T2: TTestSuite;
begin
  T2 := TTestSuite.Create('nextpas.core.agent.transport_stream');
  T2.Test('incremental timing', @TestIncrementalTiming);
  T2.Test('cancel mid stream', @TestCancelMidStream);
  T2.Test('half chunk state kept', @TestHalfChunkStateKept);
  T2.Test('round trip scripted', @TestRoundTripScripted);
  if not T2.Run then Halt(1);
end.
