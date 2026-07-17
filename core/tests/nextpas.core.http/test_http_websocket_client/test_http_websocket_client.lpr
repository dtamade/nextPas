program test_http_websocket_client;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.fs,
  nextpas.core.io.intf,
  nextpas.core.net,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.http,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.router,
  nextpas.core.http.server,
  nextpas.core.http.websocket,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.thread;

var
  T: TTestSuite;

type
  PServerCtx = ^TServerCtx;
  TServerCtx = record
    Server: THttpServer;
    Addr: string;
    Port: UInt16;
  end;

function ServerThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PServerCtx;
begin
  Result := nil;
  LCtx := PServerCtx(AArg);
  try
    LCtx^.Server.ListenAndServe(LCtx^.Addr, LCtx^.Port);
  except
  end;
  Dispose(LCtx);
end;

function StartServer(const AHandler: IHttpHandler; out AServer: THttpServer; out APort: UInt16): TPlatformThreadHandle;
var
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
begin
  AServer := THttpServer.Create(AHandler, THttpServerOptions.Default);
  New(LCtx);
  LCtx^.Server := AServer;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);
  LWait := 0;
  while (not AServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;
  APort := AServer.LocalAddr.Port;
  Result := LHandle;
end;

procedure StopServer(var AServer: THttpServer; const AHandle: TPlatformThreadHandle);
var
  LRet: Pointer;
begin
  AServer.Shutdown;
  platform_thread_join(AHandle, LRet);
  AServer.Free;
  AServer := nil;
end;

{ Test WebSocket client echo }
procedure TestClientEcho;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LWs: IWebSocket;
  LFrame: TWebSocketFrame;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    LF := LWs.ReadFrame;
    if LF.Opcode = wsOpText then
      LWs.WriteText(UTF8BytesToString(LF.Payload));
    LWs.Close(1000, '');
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LWs := ConnectWebSocket('ws://127.0.0.1:' + IntToStr(LPort) + '/ws');
    try
      CheckTrue(LWs.IsOpen, 'connection open');

      { Send text }
      LWs.WriteText('hello');
      LFrame := LWs.ReadFrame;
      CheckEqual(Ord(wsOpText), Ord(LFrame.Opcode), 'opcode text');
      CheckEqual('hello', UTF8BytesToString(LFrame.Payload), 'payload hello');

      { Close }
      LWs.Close(1000, 'done');
    finally
      LWs := nil;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test WebSocket client ping/pong }
procedure TestClientPingPong;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LWs: IWebSocket;
  LFrame: TWebSocketFrame;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    LWs.Ping(StringToUTF8Bytes('server-ping'));
    LF := LWs.ReadFrame;
    if LF.Opcode = wsOpPong then
      LWs.WriteText('pong-received');
    LWs.Close(1000, '');
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LWs := ConnectWebSocket('ws://127.0.0.1:' + IntToStr(LPort) + '/ws');
    try
      CheckTrue(LWs.IsOpen, 'connection open');

      { Server sends ping, client receives it }
      LFrame := LWs.ReadFrame;
      CheckEqual(Ord(wsOpPing), Ord(LFrame.Opcode), 'opcode ping');
      CheckEqual('server-ping', UTF8BytesToString(LFrame.Payload), 'ping payload');

      { Client sends pong }
      LWs.Pong(StringToUTF8Bytes('server-ping'));

      { Server sends confirmation }
      LFrame := LWs.ReadFrame;
      CheckEqual(Ord(wsOpText), Ord(LFrame.Opcode), 'opcode text');
      CheckEqual('pong-received', UTF8BytesToString(LFrame.Payload), 'confirmation');

      { Server closes }
      LFrame := LWs.ReadFrame;
      CheckEqual(Ord(wsOpClose), Ord(LFrame.Opcode), 'opcode close');

      LWs.Close(1000, 'done');
    finally
      LWs := nil;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test WebSocket client error handling }
procedure TestClientRejectsInvalidScheme;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LCaught: Boolean;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    { Should not reach here }
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LCaught := False;
    try
      ConnectWebSocket('http://127.0.0.1:' + IntToStr(LPort) + '/ws');
    except
      on E: EHttpError do
        LCaught := True;
    end;
    CheckTrue(LCaught, 'expected EHttpError');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestWebSocketOptionsDefaultTimeouts;
var
  LOpts: TWebSocketOptions;
begin
  LOpts := TWebSocketOptions.Default;
  CheckEqual(Int64(30000), LOpts.ConnectTimeout,
    'Default ConnectTimeout is 30000 (production discipline)');
  CheckEqual(Int64(30000), LOpts.Timeout,
    'Default Timeout is 30000 for handshake I/O');
  LOpts := LOpts.WithConnectTimeout(1500).WithTimeout(5000);
  CheckEqual(Int64(1500), LOpts.ConnectTimeout, 'WithConnectTimeout sets field');
  CheckEqual(Int64(5000), LOpts.Timeout, 'WithTimeout sets field');
end;

procedure TestWebSocketConnectTimeoutSourceContract;
var
  LSource: string;
begin
  LSource := ReadFileText('../../../src/nextpas.core.http.websocket.pas');
  Check(Pos('LDialMs := WebSocketEffectiveDialTimeoutMs(AOptions);', LSource) > 0,
    'ConnectWebSocket computes effective dial budget');
  Check(Pos('LConn := TcpConnect(LHost, LPort, LDialMs)', LSource) > 0,
    'ConnectWebSocket uses timed TcpConnect when budget > 0');
  Check(Pos('ApplyWebSocketStreamDeadline(LActive, LHandshakeMs);', LSource) > 0,
    'handshake deadline applied after dial');
  Check(Pos('ClearWebSocketStreamDeadline(LActive);', LSource) > 0,
    'deadlines cleared after successful upgrade');
  Check(Pos('Result.ConnectTimeout := 30000;', LSource) > 0,
    'Default ConnectTimeout is 30000');
end;

{ Live WS dial timeout via backlog-full peer (same technique as test_net). }
procedure TestWebSocketLiveConnectTimeout;
var
  LListener: ITcpListener;
  LFillers: array of ITcpStream;
  LConn: ITcpStream;
  LOpts: TWebSocketOptions;
  LPort: UInt16;
  I: Integer;
  LFilled: Boolean;
  LGot: Boolean;
  LKind: THttpErrorKind;
begin
  LListener := TcpListen('127.0.0.1', 0);
  LPort := LListener.LocalAddr.Port;
  SetLength(LFillers, 0);
  LFilled := False;
  for I := 1 to 256 do
  begin
    try
      LConn := TcpConnect('127.0.0.1', LPort, 100);
      SetLength(LFillers, Length(LFillers) + 1);
      LFillers[High(LFillers)] := LConn;
    except
      on E: ETimeoutError do
      begin
        LFilled := True;
        Break;
      end;
      on E: ENetworkError do
      begin
        LFilled := True;
        Break;
      end;
    end;
  end;
  Check(LFilled or (Length(LFillers) > 0),
    'backlog fill made progress for WS connect-timeout setup');
  LOpts := TWebSocketOptions.Default.WithConnectTimeout(200).WithTimeout(200);
  LGot := False;
  LKind := hekUnknown;
  try
    ConnectWebSocket('ws://127.0.0.1:' + IntToStr(LPort) + '/ws', LOpts);
  except
    on E: EHttpError do
    begin
      LKind := E.Kind;
      LGot := E.Kind in [hekTimeout, hekConnect];
    end;
    on E: ETimeoutError do
    begin
      LGot := True;
      LKind := hekTimeout;
    end;
  end;
  Check(LGot,
    'live WS dial timeout surfaces as hekTimeout/hekConnect (kind=' +
    IntToStr(Ord(LKind)) + ')');
  for I := 0 to High(LFillers) do
    if LFillers[I] <> nil then
      LFillers[I].Close;
  LListener.Close;
end;

begin
  T := TTestSuite.Create('nextpas.core.http.websocket.client');

  T.Test('WebSocket client echoes text', @TestClientEcho);
  T.Test('WebSocket client handles ping/pong', @TestClientPingPong);
  T.Test('WebSocket client rejects invalid scheme', @TestClientRejectsInvalidScheme);
  T.Test('WebSocket options default timeouts', @TestWebSocketOptionsDefaultTimeouts);
  T.Test('WebSocket ConnectTimeout source contract',
    @TestWebSocketConnectTimeoutSourceContract);
  T.Test('WebSocket live ConnectTimeout via backlog-full peer',
    @TestWebSocketLiveConnectTimeout);

  if not T.Run then Halt(1);
end.
