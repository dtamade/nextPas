program test_http_client;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.net,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.tcp,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.router,
  nextpas.core.http.server,
  nextpas.core.http.client,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.thread;

var
  T: TTestRunner;

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

// PLACEHOLDER_TEST_CONTINUE

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
  LCtx^.Port := 0; { OS picks a free port }
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);
  { Wait for server to start listening }
  LWait := 0;
  while (not AServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000); { 5ms }
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

function ReadBodyStr(const AResp: IHttpResponse): string;
var
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  if AResp.Body = nil then Exit;
  repeat
    LN := AResp.Body.Read(LBuf[0], 4096);
    if LN > 0 then
    begin
      SetLength(Result, Length(Result) + Int32(LN));
      Move(LBuf[0], Result[Length(Result) - Int32(LN) + 1], LN);
    end;
  until LN = 0;
end;

{ Test 1: Client GET returns 200 + body }
procedure TestClientGet200;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LBody: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/hello', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LB: string;
  begin
    LB := 'world';
    AW.GetHeaders.Set_('content-length', '5');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], 5);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/hello');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    LBody := ReadBodyStr(LResp);
    CheckEqual('world', LBody, 'body matches');
  finally
    StopServer(LServer, LHandle);
  end;
end;

// PLACEHOLDER_TEST2

{ Test 2: Client GET with custom headers }
procedure TestClientGetCustomHeaders;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LReq: IHttpRequest;
  LUrl: TUrl;
  LGotHeader: string;
begin
  LGotHeader := '';
  LRouter := THttpRouter.Create;
  LRouter.Get('/echo-header', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LB: string;
  begin
    LGotHeader := AReq.Headers.Get('x-custom');
    LB := 'ok';
    AW.GetHeaders.Set_('content-length', '2');
    AW.GetHeaders.Set_('x-echo', LGotHeader);
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LUrl := TUrl.Parse('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/echo-header');
    LReq := THttpRequest.Create(hmGet, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
    LReq.Headers.Set_('x-custom', 'hello-from-client');
    LResp := LClient.Do_(LReq);
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    CheckEqual('hello-from-client', LResp.Headers.Get('x-echo'), 'custom header echoed');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 3: Client POST with body }
procedure TestClientPostBody;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LBody: string;
  LBodyStream: IStream;
  LPostData: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Post('/submit', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LB: string;
  begin
    LB := 'accepted';
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_CREATED);
    AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LPostData := 'key=value';
    LBodyStream := CreateBytesStreamFrom(nil);
    (LBodyStream as IWriter).Write(LPostData[1], SizeUInt(Length(LPostData)));
    LBodyStream.Position := 0;
    LResp := LClient.Post(
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/submit',
      'application/x-www-form-urlencoded',
      LBodyStream as IReader);
    CheckEqual(Int64(201), Int64(LResp.StatusCode), 'status 201');
    LBody := ReadBodyStr(LResp);
    CheckEqual('accepted', LBody, 'body matches');
  finally
    StopServer(LServer, LHandle);
  end;
end;

// PLACEHOLDER_TEST4

{ Test 4: Client follows redirect (301 -> 200) }
procedure TestClientFollowsRedirect;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LBody: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/old', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.GetHeaders.Set_('location', '/new');
    AW.GetHeaders.Set_('content-length', '0');
    AW.WriteHeader(THttpStatus(301));
  end);
  LRouter.Get('/new', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LB: string;
  begin
    LB := 'arrived';
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/old');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'followed redirect to 200');
    LBody := ReadBodyStr(LResp);
    CheckEqual('arrived', LBody, 'body from final destination');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 5: Client respects max redirects (infinite loop -> error) }
procedure TestClientMaxRedirects;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LOptions: THttpClientOptions;
  LCaught: Boolean;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/loop', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.GetHeaders.Set_('location', '/loop');
    AW.GetHeaders.Set_('content-length', '0');
    AW.WriteHeader(THttpStatus(302));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LOptions := THttpClientOptions.Default;
    LOptions.MaxRedirects := 3;
    LClient := NewHttpClient(LOptions);
    LCaught := False;
    try
      LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/loop');
    except
      on E: EHttpError do
        LCaught := True;
    end;
    Check(LCaught, 'too many redirects raises EHttpError');
  finally
    StopServer(LServer, LHandle);
  end;
end;

// PLACEHOLDER_TEST6

{ Test 6: Client timeout on slow server }
procedure TestClientTimeout;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LOptions: THttpClientOptions;
  LCaught: Boolean;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/slow', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    { Sleep 2 seconds — longer than client timeout }
    platform_thread_sleep_ns(2000000000);
    AW.GetHeaders.Set_('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(PAnsiChar('ok')^, 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LOptions := THttpClientOptions.Default;
    LOptions.Timeout := 500; { 500ms timeout }
    LClient := NewHttpClient(LOptions);
    LCaught := False;
    try
      LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/slow');
    except
      LCaught := True;
    end;
    Check(LCaught, 'timeout raises exception');
  finally
    StopServer(LServer, LHandle);
    { Wait for the slow handler thread to finish (it sleeps 2s) }
    platform_thread_sleep_ns(2500000000);
  end;
end;

{ Test 7: Client handles 404 response }
procedure TestClientHandles404;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/exists', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.GetHeaders.Set_('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(PAnsiChar('ok')^, 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/not-found');
    CheckEqual(Int64(404), Int64(LResp.StatusCode), 'status 404');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 8: Client sets Host header automatically }
procedure TestClientSetsHostHeader;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LGotHost: string;
begin
  LGotHost := '';
  LRouter := THttpRouter.Create;
  LRouter.Get('/check-host', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LB: string;
  begin
    LGotHost := AReq.Headers.Get('host');
    LB := LGotHost;
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_OK);
    if Length(LB) > 0 then
      AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/check-host');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    Check(LGotHost <> '', 'Host header was set');
    Check(Pos('127.0.0.1', LGotHost) > 0, 'Host contains IP');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 9: Connection reuse — multiple requests share one TCP connection }
var
  GAcceptCount: Int32;
  GPoolListener: ITcpListener;

function PoolAcceptThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LReply: string;
  LAccum: string;
  LP: SizeInt;
begin
  Result := nil;
  while True do
  begin
    try
      LConn := GPoolListener.Accept;
    except
      Break;
    end;
    if LConn = nil then Break;
    InterlockedIncrement(GAcceptCount);
    { Serve multiple requests on this connection by detecting \r\n\r\n boundaries }
    try
      LAccum := '';
      while True do
      begin
        LN := LConn.Read(LBuf[0], 4096);
        if LN = 0 then Break;
        SetLength(LAccum, Length(LAccum) + Int32(LN));
        Move(LBuf[0], LAccum[Length(LAccum) - Int32(LN) + 1], LN);
        { Process all complete requests in the buffer }
        while True do
        begin
          LP := Pos(#13#10#13#10, LAccum);
          if LP = 0 then Break;
          { Found a complete request — send response }
          LReply := 'HTTP/1.1 200 OK'#13#10 +
                    'Content-Length: 2'#13#10 +
                    #13#10 +
                    'ok';
          LConn.Write(LReply[1], SizeUInt(Length(LReply)));
          { Remove processed request from buffer }
          System.Delete(LAccum, 1, LP + 3);
        end;
      end;
    except
    end;
    LConn.Close;
  end;
end;

procedure TestConnectionReuse;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LI: Int32;
  LRet: Pointer;
begin
  GAcceptCount := 0;
  GPoolListener := NetTcpListen('127.0.0.1', 0);
  LPort := GPoolListener.LocalAddr.Port;
  platform_thread_create(LHandle, @PoolAcceptThread, nil);

  try
    LClient := NewHttpClient;
    for LI := 1 to 3 do
    begin
      LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/ping');
      CheckEqual(Int64(200), Int64(LResp.StatusCode), 'request ' + IntToStr(Int64(LI)) + ' status 200');
    end;
    { All 3 requests should have reused 1 connection }
    CheckEqual(Int64(1), Int64(GAcceptCount), 'only 1 accept (connection reused)');
    { Release client to close pooled connections, unblocking server thread }
    LClient := nil;
  finally
    GPoolListener.Close;
    platform_thread_join(LHandle, LRet);
    GPoolListener := nil;
  end;
end;

{ Main }

begin
  T := TTestRunner.Create('nextpas.core.http.client');
  T.Run('Client GET returns 200 + body', @TestClientGet200);
  T.Run('Client GET with custom headers', @TestClientGetCustomHeaders);
  T.Run('Client POST with body', @TestClientPostBody);
  T.Run('Client follows redirect (301 -> 200)', @TestClientFollowsRedirect);
  T.Run('Client respects max redirects', @TestClientMaxRedirects);
  T.Run('Client timeout on slow server', @TestClientTimeout);
  T.Run('Client handles 404 response', @TestClientHandles404);
  T.Run('Client sets Host header automatically', @TestClientSetsHostHeader);
  T.Run('Connection reuse', @TestConnectionReuse);
  T.Summary;
end.




