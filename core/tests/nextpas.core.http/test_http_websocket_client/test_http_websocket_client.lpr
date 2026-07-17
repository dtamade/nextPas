program test_http_websocket_client;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.errors,
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

begin
  T := TTestSuite.Create('nextpas.core.http.websocket.client');

  T.Test('WebSocket client echoes text', @TestClientEcho);
  T.Test('WebSocket client handles ping/pong', @TestClientPingPong);
  T.Test('WebSocket client rejects invalid scheme', @TestClientRejectsInvalidScheme);

  if not T.Run then Halt(1);
end.
