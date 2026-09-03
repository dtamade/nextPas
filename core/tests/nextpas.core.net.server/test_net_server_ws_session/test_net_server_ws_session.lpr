program test_net_server_ws_session;

{ B8：事件驱动 WS 帧会话（epoll readiness 路径）集成测试。
  覆盖：poll-driven 读写循环、一次写入多帧、Ping 自动回 Pong、
  分片归并回显、读空闲超时关 1001、Cancel 中止、出站队列溢出中止、
  close 握手回执、协议错误关 1002、超限关 1009。 }

{$I nextpas.core.settings.inc}

{$IF not defined(NEXTPAS_LINUX)}
  {$ERROR test_net_server_ws_session requires the Linux epoll backend}
{$ENDIF}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.test,
  nextpas.core.net,
  nextpas.core.net.intf,
  nextpas.core.net.server,
  nextpas.core.net.server.ws,
  nextpas.core.net.server.ws.frame,
  nextpas.core.net.server.ws.session,
  nextpas.core.platform.thread,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.websocket.base, nextpas.core.exception;

type
  PServerFixture = ^TServerFixture;
  TServerFixture = record
    Server: ITcpServer;
    Handler: ITcpServerHandler;
    Addr: string;
    Port: UInt16;
  end;

  TWsSinkMode = (
    wsmEcho,          { 回显数据帧（同 opcode） }
    wsmCancelOnFrame, { 首个数据帧到达即 Cancel }
    wsmCloseOnFrame   { 首个数据帧到达即 SendClose(1000) }
  );

  { 测试 sink：仅由 reactor 线程回调；计数字段在主线程经等待循环观察
    （与 test_net_server 既有范式一致，无锁）。 }
  TTestWsSink = class(TInterfacedObject, IWebSocketFrameSink)
  public
    FrameCount: Int32;
    TimeoutCount: Int32;
    OverflowCount: Int32;
    ClosedCount: Int32;
    LastOpcode: Byte;
    LastFin: Boolean;
    LastPayload: TBytes;
    constructor Create(const AMode: TwsSinkMode);
    procedure OnSessionEvent(const AEvent: TNetWsSessionEvent;
      const AFrame: TNetWsFrame);
    procedure SetSession(const ASession: TNetWsFrameSession);
  private
    FMode: TwsSinkMode;
    FSessionPtr: Pointer; { 弱引用：会话存活期间由 reactor 线程驱动 }
  end;

  TTestWsHandler = class(TInterfacedObject, ITcpServerHandler,
    ITcpServerSessionFactoryWithContext)
  public
    CreateCount: Int32;
    ServeConnCalled: Boolean;
    constructor Create(const ASink: TTestWsSink;
      const AOptions: TNetWsFrameSessionOptions);
    function ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
    function NewSession(const AConn: ITcpStream;
      const AContext: ITcpServerSessionContext): ITcpServerSession;
  private
    FSinkObj: TTestWsSink;
    FSink: IWebSocketFrameSink;
    FOptions: TNetWsFrameSessionOptions;
  end;

  { 客户端帧读取器：解码器跨调用持有，覆盖一包多帧的剩余缓冲 }
  TWsTestReader = record
    Decoder: TNetWsFrameDecoder;
    procedure Init;
    function ReadFrame(const AConn: ITcpStream; const ATimeoutMs: UInt32;
      out AFrame: TNetWsFrame): TNetWsDecodeCode;
  end;

function ServerThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PServerFixture;
begin
  Result := nil;
  LCtx := PServerFixture(AArg);
  try
    LCtx^.Server.ListenAndServe(LCtx^.Addr, LCtx^.Port, LCtx^.Handler);
  finally
    LCtx^.Server := nil;
    LCtx^.Handler := nil;
    Dispose(LCtx);
  end;
end;

{ 启动 epoll 事件驱动服务器（factory → poll-driven 会话路径）。 }
procedure StartWsServer(const ASink: TTestWsSink;
  const AOptions: TNetWsFrameSessionOptions; out AServer: ITcpServer;
  out AHandler: TTestWsHandler; out AThread: TPlatformThreadHandle);
var
  LCtx: PServerFixture;
  LOptions: TTcpServerOptions;
  LWait: Int32;
begin
  AHandler := TTestWsHandler.Create(ASink, AOptions);
  LOptions := TTcpServerOptions.Default;
  LOptions.Backend := TCP_SERVER_BACKEND_EPOLL;
  AServer := NewTcpServer(LOptions);
  New(LCtx);
  LCtx^.Server := AServer;
  LCtx^.Handler := AHandler;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(AThread, @ServerThreadFunc, LCtx);
  LWait := 0;
  while (not AServer.IsRunning) and (LWait < 600) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;
  Check(AServer.IsRunning, 'ws session epoll server should start');
  Check(AServer.LocalAddr.Port > 0,
    'ws session epoll server exposes bound port');
end;

{ 等待某计数达到目标（5ms 步进，最大 3s）。 }
function SpinWait(var AValue: Int32; const ATarget: Int32): Boolean;
var
  I: Int32;
begin
  Result := False;
  for I := 1 to 600 do
  begin
    if AValue >= ATarget then
      Exit(True);
    platform_thread_sleep_ns(5000000);
  end;
end;

function BytesFrom(const AValue: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[1], Result[0], SizeUInt(Length(AValue)));
end;

{ 客户端（掩码）数据帧。 }
function WsFrame(const AOpcode: Byte; const AFin: Boolean;
  const APayload: TBytes): TBytes;
var
  E: TNetWsFrameEncoder;
  W: TBytes;
begin
  CheckEqual(Int64(Ord(nwsEncodeOk)), Int64(Ord(
    E.BuildFrame(AOpcode, AFin, APayload, nwsClient, W))),
    'client frame encode');
  Result := W;
end;

function WsCloseFrame(const ACode: UInt16; const AReason: string): TBytes;
var
  E: TNetWsFrameEncoder;
  W: TBytes;
begin
  CheckEqual(Int64(Ord(nwsEncodeOk)), Int64(Ord(
    E.BuildCloseFrame(ACode, AReason, nwsClient, W))),
    'client close frame encode');
  Result := W;
end;

{ 绕过编码器构造非法帧（编码器拒绝的 opcode 等）。掩码 + FIN。 }
function WsBadFrame(const AOpcode: Byte; const APayload: TBytes): TBytes;
var
  LMask: array[0..3] of Byte;
  LPos: SizeUInt;
  LI: SizeInt;
begin
  Result := nil;
  SetLength(Result, 2 + 4 + Length(APayload));
  Result[0] := $80 or AOpcode;
  Result[1] := $80 or Byte(Length(APayload));
  LMask[0] := 1;
  LMask[1] := 2;
  LMask[2] := 3;
  LMask[3] := 4;
  for LI := 0 to 3 do
    Result[2 + SizeUInt(LI)] := LMask[LI];
  LPos := 6;
  for LI := 0 to Length(APayload) - 1 do
    Result[LPos + SizeUInt(LI)] := APayload[LI] xor LMask[LI mod 4];
end;

procedure WriteWire(const AConn: ITcpStream; const AWire: TBytes);
begin
  AConn.Write(AWire[0], SizeUInt(Length(AWire)));
end;

{ TWsTestReader }

procedure TWsTestReader.Init;
begin
  Decoder := TNetWsFrameDecoder.Create(True, 4096, 65536);
end;

function TWsTestReader.ReadFrame(const AConn: ITcpStream;
  const ATimeoutMs: UInt32; out AFrame: TNetWsFrame): TNetWsDecodeCode;
var
  LCode: TNetWsDecodeCode;
  LBuf: array[0..2047] of Byte;
  LN: SizeUInt;
begin
  repeat
    LCode := Decoder.TryDecode(AFrame);
    if LCode <> nwsDecodeNeedMore then
      Exit(LCode);
    AConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(ATimeoutMs)));
    LN := 0;
    try
      LN := AConn.Read(LBuf[0], SizeOf(LBuf));
    except
      on Exception do
        Exit(nwsDecodeNeedMore); { 读超时：本次读不到更多帧 }
    end;
    if LN = 0 then
      Exit(nwsDecodeNeedMore); { EOF：服务端已关闭连接 }
    Decoder.Feed(@LBuf[0], LN);
  until False;
end;

{ TTestWsSink }

constructor TTestWsSink.Create(const AMode: TwsSinkMode);
begin
  inherited Create;
  FMode := AMode;
end;

procedure TTestWsSink.SetSession(const ASession: TNetWsFrameSession);
begin
  FSessionPtr := Pointer(ASession);
end;

procedure TTestWsSink.OnSessionEvent(const AEvent: TNetWsSessionEvent;
  const AFrame: TNetWsFrame);
var
  LSess: TNetWsFrameSession;
begin
  LSess := TNetWsFrameSession(FSessionPtr);
  case AEvent of
    nwsEventFrame:
      begin
        Inc(FrameCount);
        LastOpcode := AFrame.Opcode;
        LastFin := AFrame.Fin;
        LastPayload := AFrame.Payload;
        if (FMode = wsmEcho) and
           (AFrame.Opcode in [Byte(WS_OPCODE_TEXT), Byte(WS_OPCODE_BINARY)]) then
          LSess.SendFrame(AFrame.Opcode, AFrame.Payload)
        else if (FMode = wsmCancelOnFrame) and
                (AFrame.Opcode = Byte(WS_OPCODE_TEXT)) then
          LSess.Cancel
        else if (FMode = wsmCloseOnFrame) and
                (AFrame.Opcode = Byte(WS_OPCODE_TEXT)) then
          LSess.SendClose(WS_CLOSE_NORMAL, 'bye');
      end;
    nwsEventTimeout:
      Inc(TimeoutCount);
    nwsEventOverflow:
      Inc(OverflowCount);
    nwsEventClosed:
      begin
        Inc(ClosedCount);
        FSessionPtr := nil;
      end;
  end;
end;

{ TTestWsHandler }

constructor TTestWsHandler.Create(const ASink: TTestWsSink;
  const AOptions: TNetWsFrameSessionOptions);
begin
  inherited Create;
  FSinkObj := ASink;
  FSink := ASink;
  FOptions := AOptions;
end;

function TTestWsHandler.ServeConn(
  const AConn: ITcpStream): TTcpServerConnOwnership;
begin
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
  ServeConnCalled := True;
  Fail('session factory path should bypass legacy ServeConn');
end;

function TTestWsHandler.NewSession(const AConn: ITcpStream;
  const AContext: ITcpServerSessionContext): ITcpServerSession;
var
  LSess: TNetWsFrameSession;
begin
  Inc(CreateCount);
  LSess := TNetWsFrameSession.Create(AConn, FSink, FOptions);
  FSinkObj.SetSession(LSess);
  Result := LSess;
end;

{ 每例的后台服务器 + 客户端回显循环 }

procedure TestWsSessionEchoRoundtrip;
var
  LSink: TTestWsSink;
  LHandler: TTestWsHandler;
  LServer: ITcpServer;
  LThread: TPlatformThreadHandle;
  LPort: UInt16;
  LClient: ITcpStream;
  R: TWsTestReader;
  F: TNetWsFrame;
  LRet: Pointer;
begin
  LSink := TTestWsSink.Create(wsmEcho);
  StartWsServer(LSink, TNetWsFrameSessionOptions.Default, LServer, LHandler,
    LThread);
  try
    LPort := LServer.LocalAddr.Port;
    LClient := TcpConnect('127.0.0.1', LPort);
    try
      WriteWire(LClient, WsFrame(Byte(WS_OPCODE_TEXT), True,
        BytesFrom('hello')));
      R.Init;
      CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(R.ReadFrame(
        LClient, 1000, F))), 'echo frame should arrive');
      CheckEqual(Int64(Byte(WS_OPCODE_TEXT)), Int64(F.Opcode),
        'echo frame keeps text opcode');
      CheckTrue(F.Fin, 'echo frame is final');
      CheckEqual(BytesFrom('hello'), F.Payload);
    finally
      LClient.Close;
    end;
    Check(SpinWait(LSink.FrameCount, 1), 'server sink observed the frame');
    CheckEqual(Int64(1), Int64(LHandler.CreateCount), 'one session created');
    Check(not LHandler.ServeConnCalled, 'context factory path used');
  finally
    LServer.Shutdown;
    platform_thread_join(LThread, LRet);
  end;
end;

procedure TestWsSessionBatchFrames;
var
  LSink: TTestWsSink;
  LHandler: TTestWsHandler;
  LServer: ITcpServer;
  LThread: TPlatformThreadHandle;
  LPort: UInt16;
  LClient: ITcpStream;
  R: TWsTestReader;
  F: TNetWsFrame;
  W1, W2, WAll: TBytes;
  LRet: Pointer;
begin
  LSink := TTestWsSink.Create(wsmEcho);
  StartWsServer(LSink, TNetWsFrameSessionOptions.Default, LServer, LHandler,
    LThread);
  try
    LPort := LServer.LocalAddr.Port;
    LClient := TcpConnect('127.0.0.1', LPort);
    try
      { 一次写入两帧：覆盖一包多帧的连续解码（echo 期间状态迁移
        不得中断剩余缓冲帧的处理） }
      W1 := WsFrame(Byte(WS_OPCODE_TEXT), True, BytesFrom('one'));
      W2 := WsFrame(Byte(WS_OPCODE_TEXT), True, BytesFrom('two'));
      SetLength(WAll, Length(W1) + Length(W2));
      Move(W1[0], WAll[0], Length(W1));
      Move(W2[0], WAll[Length(W1)], Length(W2));
      WriteWire(LClient, WAll);
      R.Init;
      CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(R.ReadFrame(
        LClient, 1000, F))), 'first batch frame should arrive');
      CheckEqual(BytesFrom('one'), F.Payload);
      CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(R.ReadFrame(
        LClient, 1000, F))), 'second batch frame should arrive');
      CheckEqual(BytesFrom('two'), F.Payload);
    finally
      LClient.Close;
    end;
    Check(SpinWait(LSink.FrameCount, 2),
      'server sink observed both batch frames');
  finally
    LServer.Shutdown;
    platform_thread_join(LThread, LRet);
  end;
end;

procedure TestWsSessionPingAutoPong;
var
  LSink: TTestWsSink;
  LHandler: TTestWsHandler;
  LServer: ITcpServer;
  LThread: TPlatformThreadHandle;
  LPort: UInt16;
  LClient: ITcpStream;
  R: TWsTestReader;
  F: TNetWsFrame;
  LRet: Pointer;
begin
  LSink := TTestWsSink.Create(wsmEcho);
  StartWsServer(LSink, TNetWsFrameSessionOptions.Default, LServer, LHandler,
    LThread);
  try
    LPort := LServer.LocalAddr.Port;
    LClient := TcpConnect('127.0.0.1', LPort);
    try
      WriteWire(LClient, WsFrame(Byte(WS_OPCODE_PING), True,
        BytesFrom('abc')));
      R.Init;
      CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(R.ReadFrame(
        LClient, 1000, F))), 'pong should arrive');
      CheckEqual(Int64(Byte(WS_OPCODE_PONG)), Int64(F.Opcode),
        'auto reply is pong');
      CheckEqual(BytesFrom('abc'), F.Payload);
    finally
      LClient.Close;
    end;
    CheckEqual(Int64(0), Int64(LSink.FrameCount),
      'ping is handled internally, not surfaced to sink');
  finally
    LServer.Shutdown;
    platform_thread_join(LThread, LRet);
  end;
end;

procedure TestWsSessionFragmentedAssembly;
var
  LSink: TTestWsSink;
  LHandler: TTestWsHandler;
  LServer: ITcpServer;
  LThread: TPlatformThreadHandle;
  LPort: UInt16;
  LClient: ITcpStream;
  R: TWsTestReader;
  F: TNetWsFrame;
  LRet: Pointer;
begin
  LSink := TTestWsSink.Create(wsmEcho);
  StartWsServer(LSink, TNetWsFrameSessionOptions.Default, LServer, LHandler,
    LThread);
  try
    LPort := LServer.LocalAddr.Port;
    LClient := TcpConnect('127.0.0.1', LPort);
    try
      { 文本分片 'he' + 终续片 'llo'：服务端归并后回显整条消息 }
      WriteWire(LClient, WsFrame(Byte(WS_OPCODE_TEXT), False,
        BytesFrom('he')));
      WriteWire(LClient, WsFrame(Byte(WS_OPCODE_CONTINUATION), True,
        BytesFrom('llo')));
      R.Init;
      CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(R.ReadFrame(
        LClient, 1000, F))), 'assembled echo should arrive');
      CheckEqual(Int64(Byte(WS_OPCODE_TEXT)), Int64(F.Opcode),
        'assembled opcode is text');
      CheckTrue(F.Fin, 'assembled echo is final');
      CheckEqual(BytesFrom('hello'), F.Payload);
    finally
      LClient.Close;
    end;
    Check(SpinWait(LSink.FrameCount, 1), 'sink saw one assembled message');
  finally
    LServer.Shutdown;
    platform_thread_join(LThread, LRet);
  end;
end;

procedure TestWsSessionIdleTimeoutClose;
var
  LSink: TTestWsSink;
  LHandler: TTestWsHandler;
  LServer: ITcpServer;
  LThread: TPlatformThreadHandle;
  LPort: UInt16;
  LClient: ITcpStream;
  R: TWsTestReader;
  F: TNetWsFrame;
  LRet: Pointer;
  LOptions: TNetWsFrameSessionOptions;
begin
  LSink := TTestWsSink.Create(wsmEcho);
  LOptions := TNetWsFrameSessionOptions.Default.WithIdleTimeout(
    TDuration.FromMilliseconds(150));
  StartWsServer(LSink, LOptions, LServer, LHandler, LThread);
  try
    LPort := LServer.LocalAddr.Port;
    LClient := TcpConnect('127.0.0.1', LPort);
    try
      { 连接后不发任何数据：应被空闲超时唤醒并回 close 1001 }
      Check(SpinWait(LSink.TimeoutCount, 1), 'idle timeout event observed');
      R.Init;
      CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(R.ReadFrame(
        LClient, 1000, F))), 'close frame should arrive after idle timeout');
      CheckEqual(Int64(Byte(WS_OPCODE_CLOSE)), Int64(F.Opcode),
        'idle timeout produces close frame');
      CheckEqual(UInt64(WS_CLOSE_GOING_AWAY), UInt64(F.CloseCode),
        'idle timeout closes with 1001');
      Check(SpinWait(LSink.ClosedCount, 1), 'sink observed closed event');
    finally
      LClient.Close;
    end;
  finally
    LServer.Shutdown;
    platform_thread_join(LThread, LRet);
  end;
end;

procedure TestWsSessionCancelAborts;
var
  LSink: TTestWsSink;
  LHandler: TTestWsHandler;
  LServer: ITcpServer;
  LThread: TPlatformThreadHandle;
  LPort: UInt16;
  LClient: ITcpStream;
  R: TWsTestReader;
  F: TNetWsFrame;
  LRet: Pointer;
begin
  LSink := TTestWsSink.Create(wsmCancelOnFrame);
  StartWsServer(LSink, TNetWsFrameSessionOptions.Default, LServer, LHandler,
    LThread);
  try
    LPort := LServer.LocalAddr.Port;
    LClient := TcpConnect('127.0.0.1', LPort);
    try
      WriteWire(LClient, WsFrame(Byte(WS_OPCODE_TEXT), True,
        BytesFrom('cancel')));
      Check(SpinWait(LSink.ClosedCount, 1), 'sink observed cancel close');
      { Cancel 不发 close 帧：客户端不应收到任何 WS 帧 }
      R.Init;
      CheckEqual(Int64(Ord(nwsDecodeNeedMore)), Int64(Ord(R.ReadFrame(
        LClient, 500, F))), 'cancel aborts without close frame');
    finally
      LClient.Close;
    end;
  finally
    LServer.Shutdown;
    platform_thread_join(LThread, LRet);
  end;
end;

procedure TestWsSessionOutboundOverflow;
var
  LSink: TTestWsSink;
  LHandler: TTestWsHandler;
  LServer: ITcpServer;
  LThread: TPlatformThreadHandle;
  LPort: UInt16;
  LClient: ITcpStream;
  R: TWsTestReader;
  F: TNetWsFrame;
  LRet: Pointer;
  LOptions: TNetWsFrameSessionOptions;
begin
  LSink := TTestWsSink.Create(wsmEcho);
  LOptions := TNetWsFrameSessionOptions.Default.WithOutboundQueueLimit(32);
  StartWsServer(LSink, LOptions, LServer, LHandler, LThread);
  try
    LPort := LServer.LocalAddr.Port;
    LClient := TcpConnect('127.0.0.1', LPort);
    try
      { 64 字节负载回显（66 字节线缆）> 32 字节队列上限 → 溢出中止 }
      WriteWire(LClient, WsFrame(Byte(WS_OPCODE_BINARY), True,
        BytesFrom(StringOfChar('x', 64))));
      Check(SpinWait(LSink.OverflowCount, 1), 'overflow event observed');
      Check(SpinWait(LSink.ClosedCount, 1), 'overflow aborts the session');
      R.Init;
      CheckEqual(Int64(Ord(nwsDecodeNeedMore)), Int64(Ord(R.ReadFrame(
        LClient, 500, F))), 'overflow abort sends no frame');
    finally
      LClient.Close;
    end;
  finally
    LServer.Shutdown;
    platform_thread_join(LThread, LRet);
  end;
end;

procedure TestWsSessionCloseHandshake;
var
  LSink: TTestWsSink;
  LHandler: TTestWsHandler;
  LServer: ITcpServer;
  LThread: TPlatformThreadHandle;
  LPort: UInt16;
  LClient: ITcpStream;
  R: TWsTestReader;
  F: TNetWsFrame;
  LRet: Pointer;
begin
  LSink := TTestWsSink.Create(wsmEcho);
  StartWsServer(LSink, TNetWsFrameSessionOptions.Default, LServer, LHandler,
    LThread);
  try
    LPort := LServer.LocalAddr.Port;
    LClient := TcpConnect('127.0.0.1', LPort);
    try
      WriteWire(LClient, WsCloseFrame(1000, 'bye'));
      R.Init;
      CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(R.ReadFrame(
        LClient, 1000, F))), 'close reply should arrive');
      CheckEqual(Int64(Byte(WS_OPCODE_CLOSE)), Int64(F.Opcode),
        'reply is a close frame');
      CheckEqual(UInt64(1000), UInt64(F.CloseCode),
        'close reply echoes peer code');
      CheckEqual('', F.CloseReason, 'reply carries no reason');
      Check(SpinWait(LSink.FrameCount, 1), 'sink observed the close frame');
    finally
      LClient.Close;
    end;
  finally
    LServer.Shutdown;
    platform_thread_join(LThread, LRet);
  end;
end;

procedure TestWsSessionProtocolErrorClose;
var
  LSink: TTestWsSink;
  LHandler: TTestWsHandler;
  LServer: ITcpServer;
  LThread: TPlatformThreadHandle;
  LPort: UInt16;
  LClient: ITcpStream;
  R: TWsTestReader;
  F: TNetWsFrame;
  LRet: Pointer;
begin
  LSink := TTestWsSink.Create(wsmEcho);
  StartWsServer(LSink, TNetWsFrameSessionOptions.Default, LServer, LHandler,
    LThread);
  try
    LPort := LServer.LocalAddr.Port;
    LClient := TcpConnect('127.0.0.1', LPort);
    try
      { 保留 opcode 0x3：解码器按协议错误处理，服务端关 1002 }
      WriteWire(LClient, WsBadFrame($03, BytesFrom('x')));
      R.Init;
      CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(R.ReadFrame(
        LClient, 1000, F))), 'protocol error close should arrive');
      CheckEqual(Int64(Byte(WS_OPCODE_CLOSE)), Int64(F.Opcode),
        'protocol error reply is close');
      CheckEqual(UInt64(WS_CLOSE_PROTOCOL_ERROR), UInt64(F.CloseCode),
        'protocol error closes with 1002');
      Check(SpinWait(LSink.ClosedCount, 1),
        'sink observed closed after protocol error');
    finally
      LClient.Close;
    end;
  finally
    LServer.Shutdown;
    platform_thread_join(LThread, LRet);
  end;
end;

procedure TestWsSessionOversizeMessageClose;
var
  LSink: TTestWsSink;
  LHandler: TTestWsHandler;
  LServer: ITcpServer;
  LThread: TPlatformThreadHandle;
  LPort: UInt16;
  LClient: ITcpStream;
  R: TWsTestReader;
  F: TNetWsFrame;
  LRet: Pointer;
  LOptions: TNetWsFrameSessionOptions;
begin
  LSink := TTestWsSink.Create(wsmEcho);
  LOptions := TNetWsFrameSessionOptions.Default;
  LOptions.MaxMessageSize := 64;
  StartWsServer(LSink, LOptions, LServer, LHandler, LThread);
  try
    LPort := LServer.LocalAddr.Port;
    LClient := TcpConnect('127.0.0.1', LPort);
    try
      { 分片 40 + 40 > 消息上限 64：关 1009 }
      WriteWire(LClient, WsFrame(Byte(WS_OPCODE_TEXT), False,
        BytesFrom(StringOfChar('A', 40))));
      WriteWire(LClient, WsFrame(Byte(WS_OPCODE_CONTINUATION), True,
        BytesFrom(StringOfChar('A', 40))));
      R.Init;
      CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(R.ReadFrame(
        LClient, 1000, F))), 'oversize close should arrive');
      CheckEqual(Int64(Byte(WS_OPCODE_CLOSE)), Int64(F.Opcode),
        'oversize reply is close');
      CheckEqual(UInt64(WS_CLOSE_TOO_LARGE), UInt64(F.CloseCode),
        'oversize message closes with 1009');
      Check(SpinWait(LSink.ClosedCount, 1),
        'sink observed closed after oversize message');
    finally
      LClient.Close;
    end;
  finally
    LServer.Shutdown;
    platform_thread_join(LThread, LRet);
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.net.server.ws.session');
  T.Test('poll-driven echo roundtrip', @TestWsSessionEchoRoundtrip);
  T.Test('batch frames in one write', @TestWsSessionBatchFrames);
  T.Test('ping auto-pong', @TestWsSessionPingAutoPong);
  T.Test('fragmented message assembly', @TestWsSessionFragmentedAssembly);
  T.Test('idle timeout closes 1001', @TestWsSessionIdleTimeoutClose);
  T.Test('cancel aborts without close frame', @TestWsSessionCancelAborts);
  T.Test('outbound overflow aborts', @TestWsSessionOutboundOverflow);
  T.Test('close handshake replies echo code', @TestWsSessionCloseHandshake);
  T.Test('protocol error closes 1002', @TestWsSessionProtocolErrorClose);
  T.Test('oversize message closes 1009', @TestWsSessionOversizeMessageClose);
  if not T.Run then Halt(1);
end.