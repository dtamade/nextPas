program test_upstream_ws;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.http,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.router,
  nextpas.core.http.server,
  nextpas.core.http.websocket,
  nextpas.core.websocket.upstream,
  nextpas.core.text.conv,
  nextpas.core.platform.thread, nextpas.core.text;

var
  T: TTestSuite;

type
  PServerCtx = ^TServerCtx;
  TServerCtx = record
    Server: THttpServer;
    Addr: string;
    Port: UInt16;
  end;

  TFrameCollector = class
  public
    Frames: array of TWebSocketFrame;
    procedure OnFrame(const AFrame: TWebSocketFrame);
    procedure Clear;
    function WaitForCount(const AExpected: Integer; const ATimeoutMs: Integer): Boolean;
  end;

procedure TFrameCollector.OnFrame(const AFrame: TWebSocketFrame);
var
  N: Integer;
begin
  N := Length(Frames);
  SetLength(Frames, N + 1);
  Frames[N] := AFrame;
end;

procedure TFrameCollector.Clear;
begin
  SetLength(Frames, 0);
end;

function TFrameCollector.WaitForCount(const AExpected: Integer; const ATimeoutMs: Integer): Boolean;
var
  Elapsed: Integer;
begin
  Elapsed := 0;
  while Elapsed < ATimeoutMs do
  begin
    if Length(Frames) >= AExpected then Exit(True);
    platform_thread_sleep_ns(5000000);
    Inc(Elapsed, 5);
  end;
  Result := Length(Frames) >= AExpected;
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

procedure TestConnect;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LOpts: TUpstreamWsOptions;
  LSession: TUpstreamWsSession;
  LCollector: TFrameCollector;
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
    LCollector := TFrameCollector.Create;
    try
      LOpts := TUpstreamWsOptions.Create('ws://127.0.0.1:' + IntToStr(LPort) + '/ws');
      LSession := TUpstreamWsSession.Create(LOpts);
      try
        LSession.OnFrame := @LCollector.OnFrame;
        LSession.Connect;
        CheckTrue(LSession.IsConnected, 'connected');
        LSession.SendText('hello-upstream');
        CheckTrue(LCollector.WaitForCount(1, 2000), 'OnFrame received echo');
        CheckEqual(Ord(wsOpText), Ord(LCollector.Frames[0].Opcode), 'echo opcode text');
        CheckEqual('hello-upstream', UTF8BytesToString(LCollector.Frames[0].Payload), 'echo payload');
        LSession.Close;
        CheckFalse(LSession.IsConnected, 'not connected after Close');
      finally
        LSession.Free;
      end;
    finally
      LCollector.Free;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHeaders;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LOpts: TUpstreamWsOptions;
  LSession: TUpstreamWsSession;
  LCaught: Boolean;
  LMsg: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
  begin
    if AReq.Headers.Get('X-Auth') <> 'secret-token' then
    begin
      HttpWriteErrorUnauthorized(AW, 'missing auth');
      Exit;
    end;
    LWs := UpgradeWebSocket(AReq, AW);
    LWs.WriteText('ok-auth');
    LWs.Close(1000, '');
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    // without header should fail (401 -> EHttpError)
    LOpts := TUpstreamWsOptions.Create('ws://127.0.0.1:' + IntToStr(LPort) + '/ws');
    LSession := TUpstreamWsSession.Create(LOpts);
    try
      LCaught := False;
      LMsg := '';
      try
        LSession.Connect;
      except
        on E: EHttpError do
        begin
          LCaught := True;
          LMsg := E.Message;
        end;
      end;
      CheckTrue(LCaught, 'headers missing should be rejected');
      Check(Pos('401', LMsg) > 0, 'rejection surfaces 401');
    finally
      LSession.Free;
    end;
    // with header should succeed
    LOpts := TUpstreamWsOptions.Create('ws://127.0.0.1:' + IntToStr(LPort) + '/ws');
    LOpts := LOpts.WithHeader('X-Auth', 'secret-token');
    LSession := TUpstreamWsSession.Create(LOpts);
    try
      LSession.Connect;
      CheckTrue(LSession.IsConnected, 'headers: connected with auth');
      LSession.Close;
    finally
      LSession.Free;
    end;
    // BuildWebSocketOptions should contain header
    LOpts := TUpstreamWsOptions.Create('ws://example.com/ws');
    LOpts := LOpts.WithHeader('Cookie', 'sid=abc');
    LOpts := LOpts.WithHeader('X-Auth', 'secret-token');
    LSession := TUpstreamWsSession.Create(LOpts);
    try
      CheckEqual(2, Length(LSession.BuildWebSocketOptions.Headers), 'headers propagated');
      CheckEqual('Cookie', LSession.BuildWebSocketOptions.Headers[0].Name, 'header 0 name');
      CheckEqual('sid=abc', LSession.BuildWebSocketOptions.Headers[0].Value, 'header 0 value');
    finally
      LSession.Free;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClose;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LOpts: TUpstreamWsOptions;
  LSession: TUpstreamWsSession;
  LKind: THttpErrorKind;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    try
      LWs.ReadFrame;
    except
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LOpts := TUpstreamWsOptions.Create('ws://127.0.0.1:' + IntToStr(LPort) + '/ws');
    LSession := TUpstreamWsSession.Create(LOpts);
    try
      LSession.Connect;
      CheckTrue(LSession.IsConnected, 'close test open');
      LSession.Close;
      CheckFalse(LSession.IsConnected, 'close makes not connected');
      LSession.Close;
      CheckFalse(LSession.IsConnected, 'double close still not connected');
      LKind := hekUnknown;
      try
        LSession.SendText('after-close');
      except
        on E: EHttpError do LKind := E.Kind;
      end;
      CheckEqual(Ord(hekProtocol), Ord(LKind), 'SendText after Close is hekProtocol');
      LKind := hekUnknown;
      try
        LSession.SendBinary(nil);
      except
        on E: EHttpError do LKind := E.Kind;
      end;
      CheckEqual(Ord(hekProtocol), Ord(LKind), 'SendBinary after Close is hekProtocol');
    finally
      LSession.Free;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestReconnectPolicy;
var
  LPolicy: TUpstreamWsReconnectPolicy;
  LSession: TUpstreamWsSession;
  LOpts: TUpstreamWsOptions;
begin
  LPolicy := TUpstreamWsReconnectPolicy.Default;
  CheckEqual(3, LPolicy.MaxRetries, 'default maxRetries 3');
  CheckEqual(500, LPolicy.BaseMs, 'default baseMs 500');
  CheckEqual(8000, LPolicy.MaxMs, 'default maxMs 8000');
  CheckEqual(500, LPolicy.DelayMs(1), 'attempt 1 delay 500');
  CheckEqual(1000, LPolicy.DelayMs(2), 'attempt 2 delay 1000');
  CheckEqual(2000, LPolicy.DelayMs(3), 'attempt 3 delay 2000');
  CheckTrue(LPolicy.ShouldRetry(1), 'should retry 1');
  CheckTrue(LPolicy.ShouldRetry(3), 'should retry 3');
  CheckFalse(LPolicy.ShouldRetry(4), 'should not retry 4');
  CheckFalse(LPolicy.ShouldRetry(0), 'should not retry 0');
  // capped at maxMs
  LPolicy.MaxRetries := 5;
  LPolicy.BaseMs := 500;
  LPolicy.MaxMs := 8000;
  CheckEqual(4000, LPolicy.DelayMs(4), 'attempt 4 delay 4000');
  CheckEqual(8000, LPolicy.DelayMs(5), 'attempt 5 capped 8000');
  CheckEqual(8000, LPolicy.DelayMs(6), 'attempt 6 beyond max still capped');
  // session wrapper
  LOpts := TUpstreamWsOptions.Create('ws://example.com/ws');
  LSession := TUpstreamWsSession.Create(LOpts, LPolicy);
  try
    CheckEqual(500, LSession.ReconnectDelayMs(1), 'session delay 1');
    CheckTrue(LSession.ShouldRetry(2), 'session should retry 2');
    CheckFalse(LSession.ShouldRetry(6), 'session should not retry 6');
  finally
    LSession.Free;
  end;
end;

procedure TestPerMessageDeflateAndSubprotocols;
var
  LOpts: TUpstreamWsOptions;
  LSession: TUpstreamWsSession;
  LWsOpts: TWebSocketOptions;
  I: Integer;
  LHasProto, LHasDeflate: Boolean;
begin
  LOpts := TUpstreamWsOptions.Create('ws://example.com/ws');
  LOpts := LOpts.WithPerMessageDeflate(True);
  LOpts := LOpts.WithSubprotocol('chat');
  LOpts := LOpts.WithSubprotocol('superchat');
  LSession := TUpstreamWsSession.Create(LOpts);
  try
    LWsOpts := LSession.BuildWebSocketOptions;
    CheckTrue(LWsOpts.EnablePermessageDeflate, 'perMessageDeflate propagated');
    LHasProto := False;
    for I := 0 to High(LWsOpts.Headers) do
      if LowerCase(LWsOpts.Headers[I].Name) = 'sec-websocket-protocol' then
      begin
        LHasProto := True;
        CheckContains(LWsOpts.Headers[I].Value, 'chat', 'subprotocol chat present');
        CheckContains(LWsOpts.Headers[I].Value, 'superchat', 'subprotocol superchat present');
      end;
    CheckTrue(LHasProto, 'subprotocol header present');
  finally
    LSession.Free;
  end;
  // without deflate default false
  LOpts := TUpstreamWsOptions.Create('ws://example.com/ws');
  LSession := TUpstreamWsSession.Create(LOpts);
  try
    LWsOpts := LSession.BuildWebSocketOptions;
    LHasDeflate := LWsOpts.EnablePermessageDeflate;
    CheckFalse(LHasDeflate, 'default perMessageDeflate false');
  finally
    LSession.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.websocket.upstream');
  T.Test('connect', @TestConnect);
  T.Test('headers', @TestHeaders);
  T.Test('close', @TestClose);
  T.Test('reconnect policy', @TestReconnectPolicy);
  T.Test('perMessageDeflate and subprotocols', @TestPerMessageDeflateAndSubprotocols);
  if not T.Run then Halt(1);
end.
