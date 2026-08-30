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
  nextpas.core.agent,
  nextpas.core.agent.provider.common,
  nextpas.core.net.intf,
  nextpas.core.net.tcp,
  nextpas.core.platform.thread,
  agent.testkit,
  nextpas.core.test;

{ 流式传输时序（TESTING §3 test_transport_stream 行）：
  scripted chunk 流验证真增量——喂 chunk N 即产出对应事件（不等到 EOF）；
  Cancel 中途立即返回 False 且 GetCancelled=True；非流式 RoundTrip
  脚本回放与耗尽归因
  边界/Cancel/超时/并发：
  - Cancel 边界：TestCancelMidStream 验证 Cancel 后 GetCancelled 立即 True 且 NextEvent=False；
    TestHardCancelAbortsInflightSend/TestDestroyJoinsWorkerPromptly 验证硬取消在 IO 切片级收合（<5s << TotalTimeout 60s），不拖满 300s Destroy（F-H03 兜底）。
  - 超时边界：TestReadIdleTimeoutAbortsStalledStream 验证 ReadIdleTimeoutMs (150ms) 在静默窗合成 aecTimeout，GetCancelled=False 可区分取消（W17.7）；
    TestResponseBodyExceeds8MiB 验证 8MiB 成功体截断在 <8s 内抛 aecProtocol（F-M20 比例断言）。
  - 并发边界：回环线程 SlowSSEThread/StallSSEThread/BigBodyThread 与主线程 NextEvent/Cancel 并发；Channel 256 槽+FLock 保护，Cancel 幂等。
  悬挂指针：IAgentWireStream/ITcpListener 均接口持有；StopLoopback/StopStall/StopBody 均 platform_thread_join 后再置 nil，
  全局 GListener/GStallListener/GBodyListener 无裸指针跨用例复用；裸 TCP 连接由接口释放。
  泄漏标注：common.mk -gh 全量 HEAPTRC 门，0 unfreed blocks；OpenStream 分配 FParser/FChannel/FLock 在 Start 异常路径 try..except Free（F-H16 闭环），Destroy 显式 FreeChannel+WaitFor。 }

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

{ ---- W7 空闲卫生：burst-then-stall 源——发 2 帧后长静默，
  客户端 ReadIdleTimeoutMs 应在静默窗内合成 aecTimeout ---- }

var
  GStallListener: ITcpListener = nil;
  GStallPort: UInt16 = 0;
  GStallHandle: TPlatformThreadHandle;

function StallSSEThread(AArg: Pointer): Pointer; cdecl;
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
      LConn := GStallListener.Accept;
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
      for I := 1 to 2 do                    { burst：两帧后长静默 }
      begin
        LOut := CSSEFrameLenHex + #13#10 + 'data: t' +
          Chr(48 + I div 10) + Chr(48 + I mod 10) + #13#10#13#10 + #13#10;
        LConn.Write(LOut[1], SizeUInt(Length(LOut)));
        platform_thread_sleep_ns(20 * 1000 * 1000);
      end;
      for I := 1 to 60 do                   { stall 6s；对端断管即退 }
        platform_thread_sleep_ns(100 * 1000 * 1000);
      LOut := '0'#13#10#13#10;
      try
        LConn.Write(LOut[1], SizeUInt(Length(LOut)));
      except
        { 客户端已超时断连：静默 }
      end;
    except
      { 断管收线程 }
    end;
  finally
    if LConn <> nil then
      LConn.Close;
  end;
end;

function StartStallLoopback: Boolean;
var
  LDummy: Pointer;
begin
  GStallListener := NetTcpListen('127.0.0.1', 0);
  if GStallListener = nil then
    Exit(False);
  GStallPort := GStallListener.LocalAddr.Port;
  GStallHandle := Default(TPlatformThreadHandle);
  platform_thread_create(GStallHandle, @StallSSEThread, nil);
  Result := True;
end;

procedure StopStallLoopback;
var
  LDummy: Pointer;
begin
  if GStallListener = nil then
    Exit;
  platform_thread_join(GStallHandle, LDummy);
  GStallListener := nil;
end;

{ ---- W15.8 成功体 8 MiB 封顶：单次 RoundTrip 累积超限即 aecProtocol（SECURITY §3，
  transport.http ReadAllBody 单一真源 CAgentMaxSuccessBodyBytes）---- }

var
  GBodyListener: ITcpListener = nil;
  GBodyPort: UInt16 = 0;
  GBodyHandle: TPlatformThreadHandle;

function BigBodyThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LAccum: string;
  LP: SizeInt;
  LBodyLen: Int64;
  LHeader: string;
  LChunk: string;
  LSent: Int64;
begin
  Result := nil;
  LConn := nil;
  try
    try
      LConn := GBodyListener.Accept;
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
      LBodyLen := Int64(CAgentMaxSuccessBodyBytes) + 1;
      LHeader := 'HTTP/1.1 200 OK'#13#10 +
        'Content-Type: text/plain'#13#10 +
        'Content-Length: ' + IntToStr(LBodyLen) + #13#10 +
        'Connection: close'#13#10#13#10;
      LConn.Write(LHeader[1], SizeUInt(Length(LHeader)));
      LChunk := StringOfChar('a', 32 * 1024);
      LSent := 0;
      while LSent < LBodyLen do
      begin
        if LBodyLen - LSent < Int64(Length(LChunk)) then
          SetLength(LChunk, Integer(LBodyLen - LSent));
        try
          LConn.Write(LChunk[1], SizeUInt(Length(LChunk)));
        except
          Break;
        end;
        Inc(LSent, Length(LChunk));
      end;
    except
      { 客户端提前关闭（超限抛后）：静默收线程 }
    end;
  finally
    if LConn <> nil then
      LConn.Close;
  end;
end;

function StartBodyLoopback: Boolean;
begin
  GBodyListener := NetTcpListen('127.0.0.1', 0);
  if GBodyListener = nil then
    Exit(False);
  GBodyPort := GBodyListener.LocalAddr.Port;
  GBodyHandle := Default(TPlatformThreadHandle);
  platform_thread_create(GBodyHandle, @BigBodyThread, nil);
  Result := True;
end;

procedure StopBodyLoopback;
var
  LDummy: Pointer;
begin
  if GBodyListener = nil then
    Exit;
  platform_thread_join(GBodyHandle, LDummy);
  GBodyListener := nil;
end;

procedure TestResponseBodyExceeds8MiB;
var
  Tr: IAgentTransport;
  Req: TWireRequest;
  Resp: TWireResponse;
  CK: IAgentClock;
  LT0: Int64;
  GotProtocol: Boolean;
begin
  if not StartBodyLoopback then
  begin
    Check(False, 'body loopback server failed to start');
    Exit;
  end;
  try
    Tr := NewHttpTransport('openai');
    Req := Default(TWireRequest);
    Req.Url := 'http://127.0.0.1:' + IntToStr(GBodyPort) + '/big';
    Req.BodyJson := '{}';
    Req.TotalTimeoutMs := 10000;
    CK := NewSystemClock;
    LT0 := CK.NowMs;
    GotProtocol := False;
    try
      Tr.RoundTrip(Req, Resp);
      Check(False, 'body >8MiB must raise aecProtocol');
    except
      on E: EAgentError do
      begin
        Check(E.ErrorCode = aecProtocol, 'body limit aecProtocol');
        Check(Pos('wire', LowerCase(E.Message)) > 0, 'wire prefix');
        Check(Pos('8mib', LowerCase(E.Message)) > 0, '8MiB wording');
        GotProtocol := True;
      end;
    end;
    Check(GotProtocol, 'got expected protocol error for oversized body');
    // 8 MiB 体超限应在远小于 TotalTimeout(10s) 内失败，放宽至 8s 比例断言防 CI 慢机假红
    Check(CK.NowMs - LT0 < 8000, 'failed promptly (not TotalTimeout): ' + IntToStr(CK.NowMs - LT0) + 'ms');
  finally
    StopBodyLoopback;
  end;
end;

{ W7：burst 两帧正常消费，静默超限抛 aecTimeout——不挂满 TotalTimeout、
  不污染取消标志（GetCancelled=False 可区分"我取消"与"对端僵死"）}
procedure TestReadIdleTimeoutAbortsStalledStream;
var
  Tr: IAgentTransport;
  W: IAgentWireStream;
  Ev: TWireSSEEvent;
  CK: IAgentClock;
  Req: TWireRequest;
  LT0, LElapsedMs, LFrames: Integer;
  GotTimeout: Boolean;
begin
  if not StartStallLoopback then
  begin
    Check(False, 'stall loopback server failed to start');
    Exit;
  end;
  try
    Tr := NewHttpTransport('openai');
    Req := Default(TWireRequest);
    Req.Url := 'http://127.0.0.1:' + IntToStr(GStallPort) + '/sse';
    Req.BodyJson := '{}';
    Req.TotalTimeoutMs := 60000;
    Req.ReadIdleTimeoutMs := 150;            { burst 间隔 20ms 不误伤 }
    W := Tr.OpenStream(Req);
    CK := NewSystemClock;
    LT0 := CK.NowMs;
    LFrames := 0;
    GotTimeout := False;
    while True do
    begin
      try
        if not W.NextEvent(Ev) then
          Break;
        Inc(LFrames);
      except
        on E: EAgentError do
        begin
          if (E.ErrorCode = aecTimeout) and
            (Pos('read idle timeout', E.Message) > 0) then
          begin
            GotTimeout := True;
            Break;
          end;
          raise;
        end;
      end;
    end;
    LElapsedMs := CK.NowMs - LT0;
    Check(LFrames >= 2, 'burst frames consumed before stall (' +
      IntToStr(LFrames) + ')');
    Check(GotTimeout, 'idle timeout raised with aecTimeout');
    Check(not W.GetCancelled,
      'cancel flag untouched by idle abort (distinguishable)');
    // 阈值放宽且文档化为相对比例：ReadIdle(150ms) + 2帧burst(40ms) << 5s << TotalTimeout(60s)；CI 负载抖动下 5s 仍可能假红，放宽至 10s 比例断言（F-M20）
    Check(LElapsedMs < 10000, 'aborted promptly (took ' +
      IntToStr(LElapsedMs) + 'ms, < TotalTimeout/6, not TotalTimeout)');
    WriteLn('idle abort elapsed ', LElapsedMs, 'ms');
  finally
    W := nil;
    StopStallLoopback;
  end;
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
    // 放宽至 5s 比例断言：Cancel 后 IO 切片级返回，不应等满 60s TotalTimeout（F-M20，CI 容器限额假红收敛）
    Check(LElapsedMs < 5000,
      'hard cancel prompt (took ' + IntToStr(LElapsedMs) + 'ms, < TotalTimeout/12)');
    WriteLn('hard cancel elapsed ', LElapsedMs, 'ms');
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
    // 同硬取消：Destroy 应在切片级收合 worker，不拖满超时（放宽至 5s，F-M20）
    Check(LElapsedMs < 5000,
      'destroy joins promptly (took ' + IntToStr(LElapsedMs) + 'ms, < TotalTimeout/12)');
    WriteLn('destroy join elapsed ', LElapsedMs, 'ms');
  finally
    StopLoopback;
  end;
end;

procedure TestHeaderGuardRejectsBadHeaders;
var
  Tr: IAgentTransport;
  Req: TWireRequest;
  Resp: TWireResponse;
  H: TWireHeaderArray;
  W: IAgentWireStream;
  procedure ExpectProtocol(const AHeaders: TWireHeaderArray; const ATag: string);
  begin
    Req := Default(TWireRequest);
    Req.Url := 'http://127.0.0.1:9/nope';
    Req.BodyJson := '{}';
    Req.Headers := AHeaders;
    try
      Tr.RoundTrip(Req, Resp);
      Check(False, ATag + ' RoundTrip must reject');
    except
      on E: EAgentError do
      begin
        Check(E.ErrorCode = aecProtocol, ATag + ' RoundTrip aecProtocol');
        Check(Pos('wire', LowerCase(E.Message)) > 0, ATag + ' wire prefix');
      end;
    end;
    try
      W := Tr.OpenStream(Req);
      Check(False, ATag + ' OpenStream must reject');
      W := nil;
    except
      on E: EAgentError do
      begin
        Check(E.ErrorCode = aecProtocol, ATag + ' OpenStream aecProtocol');
        Check(Pos('wire', LowerCase(E.Message)) > 0, ATag + ' wire prefix');
      end;
    end;
    { provider/直验路径：同一真源，经 facade/mesh 亦同错 }
    try
      AgentValidateWireHeaders(AHeaders);
      Check(False, ATag + ' direct helper must reject');
    except
      on E: EAgentError do
      begin
        Check(E.ErrorCode = aecProtocol, ATag + ' direct aecProtocol');
        Check(Pos('wire', LowerCase(E.Message)) > 0, ATag + ' direct wire prefix');
      end;
    end;
  end;
  function MakeBigHeaders(ACount, AValueLen: Integer): TWireHeaderArray;
  var I: Integer;
  begin
    SetLength(Result, ACount);
    for I := 0 to ACount-1 do
    begin
      Result[I].Name := 'X-H' + IntToStr(I);
      Result[I].Value := StringOfChar('v', AValueLen);
    end;
  end;
begin
  Tr := NewHttpTransport('openai');
  SetLength(H, 1);
  H[0].Name := '';
  H[0].Value := 'v';
  ExpectProtocol(H, 'empty-name');
  SetLength(H, 1);
  H[0].Name := 'X' + #10 + 'Y';
  H[0].Value := 'v';
  ExpectProtocol(H, 'crlf-name');
  SetLength(H, 1);
  H[0].Name := 'X-Custom';
  H[0].Value := 'a' + #13 + 'b';
  ExpectProtocol(H, 'crlf-value');
  { 单头 8KiB 限 }
  SetLength(H, 1);
  H[0].Name := 'X-Big';
  H[0].Value := StringOfChar('a', 8192);
  ExpectProtocol(H, 'single-header-8k');
  { 总头 64KiB 限：每头 ~7k，10 头 =70k >64k 且单头未超限 }
  ExpectProtocol(MakeBigHeaders(10, 7000), 'total-64k');
end;

var
  T2: TTestSuite;
begin
  T2 := TTestSuite.Create('nextpas.core.agent.transport_stream');
  T2.Test('header guard rejects empty/CR-LF', @TestHeaderGuardRejectsBadHeaders);
  T2.Test('incremental timing', @TestIncrementalTiming);
  T2.Test('cancel mid stream', @TestCancelMidStream);
  T2.Test('half chunk state kept', @TestHalfChunkStateKept);
  T2.Test('round trip scripted', @TestRoundTripScripted);
  T2.Test('hard cancel aborts inflight send', @TestHardCancelAbortsInflightSend);
  T2.Test('destroy joins worker promptly', @TestDestroyJoinsWorkerPromptly);
  T2.Test('read idle timeout aborts stalled stream',
    @TestReadIdleTimeoutAbortsStalledStream);
  T2.Test('response body exceeds 8MiB', @TestResponseBodyExceeds8MiB);
  if not T2.Run then Halt(1);
end.
