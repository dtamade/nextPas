program test_transport_stream;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.clock,
  nextpas.core.agent.transport.http,
  nextpas.core.net.intf,
  nextpas.core.net.tcp,
  nextpas.core.platform.thread,
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

{ ---- W2 硬取消：回环时序验证（真实 TWireStream + IHttpCancelToken；
  服务器侧为裸 TCP 恒长 chunked SSE 源，与 http 域 live-dispatch 用例同款）---- }

const
  { 恒长帧：'data: tNN' + CRLFCRLF = 13 字节（$D），chunked 头恒为 'D' }
  CSSEFrameLenHex = 'D';

var
  GListener: ITcpListener = nil;
  GServerPort: UInt16 = 0;
  GServerHandle: TPlatformThreadHandle;

function SlowSSEThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LAccum: string;
  LP: SizeInt;
  I: Integer;
  LOut: string;
begin
  Result := nil;
  LConn := nil;
  try
    try
      LConn := GListener.Accept;
      if LConn = nil then
        Exit;
      LAccum := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN = 0 then
          Break;
        SetLength(LAccum, Length(LAccum) + Int32(LN));
        Move(LBuf[0], LAccum[Length(LAccum) - Int32(LN) + 1], LN);
        LP := Pos(#13#10#13#10, LAccum);
      until LP > 0;
      if LP <= 0 then
        Exit;
      LOut := 'HTTP/1.1 200 OK'#13#10 +
        'Content-Type: text/event-stream'#13#10 +
        'Transfer-Encoding: chunked'#13#10#13#10;
      LConn.Write(LOut[1], SizeUInt(Length(LOut)));
      for I := 1 to 60 do
      begin
        LOut := CSSEFrameLenHex + #13#10 + 'data: t' +
          Chr(48 + I div 10) + Chr(48 + I mod 10) + #13#10#13#10 + #13#10;
        LConn.Write(LOut[1], SizeUInt(Length(LOut)));
        platform_thread_sleep_ns(50 * 1000 * 1000);
      end;
      LOut := '0'#13#10#13#10;
      LConn.Write(LOut[1], SizeUInt(Length(LOut)));
    except
      { 客户端取消后写对端断管：静默收线程 }
    end;
  finally
    if LConn <> nil then
      LConn.Close;
  end;
end;

function StartLoopback: Boolean;
var
  LDummy: Pointer;
begin
  GListener := NetTcpListen('127.0.0.1', 0);
  if GListener = nil then
    Exit(False);
  GServerPort := GListener.LocalAddr.Port;
  GServerHandle := Default(TPlatformThreadHandle);
  platform_thread_create(GServerHandle, @SlowSSEThread, nil);
  Result := True;
end;

procedure StopLoopback;
var
  LDummy: Pointer;
begin
  if GListener = nil then
    Exit;
  platform_thread_join(GServerHandle, LDummy);
  GListener := nil;                  { 释放监听器，收合连接 }
end;
function SlowStreamReq: TWireRequest;
begin
  Result := Default(TWireRequest);
  Result.Url := 'http://127.0.0.1:' + IntToStr(GServerPort) + '/sse';
  Result.BodyJson := '{}';
  Result.TotalTimeoutMs := 60000;
end;

{ Cancel 后 NextEvent 必须在 IO 切片级返回 False，而非等满请求超时 }
procedure TestHardCancelAbortsInflightSend;
var
  Tr: IAgentTransport;
  W: IAgentWireStream;
  Ev: TWireSSEEvent;
  CK: IAgentClock;
  LT0, LElapsedMs: Int64;
begin
  if not StartLoopback then
  begin
    Check(False, 'loopback server failed to start');
    Exit;
  end;
  try
    CK := NewSystemClock;
    Tr := NewHttpTransport('openai');
    W := Tr.OpenStream(SlowStreamReq);
    Check(W.NextEvent(Ev) and (Ev.Data = 't01'), 'streaming live');
    LT0 := CK.NowMs;
    W.Cancel;
    Check(not W.NextEvent(Ev), 'cancel ends stream');
    Check(W.GetCancelled, 'cancelled flag set');
    LElapsedMs := CK.NowMs - LT0;
    Check(LElapsedMs < 3000,
      'hard cancel prompt (took ' + IntToStr(LElapsedMs) + 'ms)');
  finally
    StopLoopback;
  end;
end;

{ 弃置未读完的流：Destroy 硬取消并快速收合 worker，不拖满超时 }
procedure TestDestroyJoinsWorkerPromptly;
var
  Tr: IAgentTransport;
  W: IAgentWireStream;
  Ev: TWireSSEEvent;
  CK: IAgentClock;
  LT0, LElapsedMs: Int64;
begin
  if not StartLoopback then
  begin
    Check(False, 'loopback server failed to start');
    Exit;
  end;
  try
    CK := NewSystemClock;
    Tr := NewHttpTransport('openai');
    W := Tr.OpenStream(SlowStreamReq);
    Check(W.NextEvent(Ev), 'first frame arrives');
    LT0 := CK.NowMs;
    W := nil;                        { 弃置：析构硬取消+等待 }
    LElapsedMs := CK.NowMs - LT0;
    Check(LElapsedMs < 3000,
      'destroy joins promptly (took ' + IntToStr(LElapsedMs) + 'ms)');
  finally
    StopLoopback;
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
  T2.Test('hard cancel aborts inflight send', @TestHardCancelAbortsInflightSend);
  T2.Test('destroy joins worker promptly', @TestDestroyJoinsWorkerPromptly);
  if not T2.Run then Halt(1);
end.
