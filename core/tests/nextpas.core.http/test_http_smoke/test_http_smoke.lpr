program test_http_smoke;
{**
 * @desc Full-stack smoke test — proves the HTTP facade is complete:
 *       start server, use client to make requests, verify responses.
 *}

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  nextpas.core.testing,
  nextpas.core.io.intf,
  nextpas.core.text.conv,
  nextpas.core.http,
  nextpas.core.http.base,
  nextpas.core.http.server,
  nextpas.core.http.client,
  nextpas.core.http.middleware,
  nextpas.core.platform.thread,
  nextpas.core.time.base,
  nextpas.core.time.deadline;

var
  T: TTestRunner;

{ ===== Server helpers ===== }

type
  PServerCtx = ^TServerCtx;
  TServerCtx = record
    Server: THttpServer;
  end;

function ServerThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PServerCtx;
begin
  Result := nil;
  LCtx := PServerCtx(AArg);
  try
    LCtx^.Server.ListenAndServe('127.0.0.1', 0);
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
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);
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

function ReadBody(const AResp: IHttpResponse): string;
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

function MakeUrl(const APort: UInt16; const APath: string): string;
begin
  Result := 'http://127.0.0.1:' + IntToStr(Int64(APort)) + APath;
end;

{ ===== Test 1: GET 200 with body ===== }

procedure TestGet200WithBody;
var
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LBody: string;
begin
  LHandle := StartServer(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var LB: string;
    begin
      LB := 'Hello';
      AW.GetHeaders.SetHeader('content-length', '5');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(LB[1], 5);
    end),
    LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Get(MakeUrl(LPort, '/anything'));
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    LBody := ReadBody(LResp);
    CheckEqual('Hello', LBody, 'body is Hello');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ ===== Test 2: POST with JSON ===== }

procedure TestPostWithJson;
var
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LGotCT: string;
  LRouter: IHttpRouter;
begin
  LGotCT := '';
  LRouter := NewRouter;
  LRouter.Handle(hmPost, '/api/data', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LB: string;
  begin
    LGotCT := AReq.Headers.Get('content-type');
    LB := 'created';
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_CREATED);
    AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Post(
      MakeUrl(LPort, '/api/data'),
      'application/json',
      IReader(nil));
    CheckEqual(Int64(201), Int64(LResp.StatusCode), 'status 201');
    CheckEqual('application/json', LGotCT, 'content-type received');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ ===== Test 3: Router path params ===== }

procedure TestRouterPathParams;
var
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LBody: string;
  LRouter: IHttpRouter;
begin
  LRouter := NewRouter;
  LRouter.Handle(hmGet, '/users/:id', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LB: string;
  begin
    LB := 'user=' + AReq.PathParam('id');
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Get(MakeUrl(LPort, '/users/42'));
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    LBody := ReadBody(LResp);
    CheckEqual('user=42', LBody, 'path param extracted');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ ===== Test 4: Redirect chain ===== }

procedure TestRedirectChain;
var
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LBody: string;
  LRouter: IHttpRouter;
begin
  LRouter := NewRouter;
  LRouter.Handle(hmGet, '/old', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.GetHeaders.SetHeader('location', '/new');
    AW.GetHeaders.SetHeader('content-length', '0');
    AW.WriteHeader(THttpStatus(301));
  end);
  LRouter.Handle(hmGet, '/new', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LB: string;
  begin
    LB := 'final';
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Get(MakeUrl(LPort, '/old'));
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'followed redirect to 200');
    LBody := ReadBody(LResp);
    CheckEqual('final', LBody, 'body from final destination');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ ===== Test 5: Concurrent clients ===== }

var
  GConcurrentOK: array[0..9] of Boolean;

function ConcurrentClientThread(AArg: Pointer): Pointer; cdecl;
var
  LIdx: PtrUInt;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LPort: UInt16;
  LI: Int32;
begin
  Result := nil;
  LIdx := PtrUInt(AArg);
  LPort := UInt16(LIdx shr 16);
  LIdx := LIdx and $FFFF;
  LClient := NewHttpClient;
  GConcurrentOK[LIdx] := True;
  for LI := 0 to 4 do
  begin
    try
      LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/ping');
      if LResp.StatusCode <> HTTP_STATUS_OK then
        GConcurrentOK[LIdx] := False;
    except
      GConcurrentOK[LIdx] := False;
    end;
  end;
end;

procedure TestConcurrentClients;
var
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LThreads: array[0..1] of TPlatformThreadHandle;
  LRet: Pointer;
  LI: Int32;
begin
  LHandle := StartServer(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var LB: string;
    begin
      LB := 'pong';
      AW.GetHeaders.SetHeader('content-length', '4');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(LB[1], 4);
    end),
    LServer, LPort);
  try
    for LI := 0 to 1 do
    begin
      GConcurrentOK[LI] := False;
      platform_thread_create(LThreads[LI], @ConcurrentClientThread,
        Pointer(PtrUInt((PtrUInt(LPort) shl 16) or PtrUInt(LI))));
    end;
    for LI := 0 to 1 do
      platform_thread_join(LThreads[LI], LRet);
    Check(GConcurrentOK[0], 'thread 0 all requests OK');
    Check(GConcurrentOK[1], 'thread 1 all requests OK');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ ===== Test 6: Client timeout ===== }

procedure TestClientTimeout;
var
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LOptions: THttpClientOptions;
  LCaught: Boolean;
begin
  LHandle := StartServer(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      platform_thread_sleep_ns(2000000000); { 2s }
      AW.GetHeaders.SetHeader('content-length', '2');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(PAnsiChar('ok')^, 2);
    end),
    LServer, LPort);
  try
    LOptions := THttpClientOptions.Default;
    LOptions.Timeout := 100; { 100ms }
    LClient := NewHttpClient(LOptions);
    LCaught := False;
    try
      LClient.Get(MakeUrl(LPort, '/slow'));
    except
      LCaught := True;
    end;
    Check(LCaught, 'timeout raises exception');
  finally
    StopServer(LServer, LHandle);
    { Wait for slow handler thread to finish }
    platform_thread_sleep_ns(2500000000);
  end;
end;

{ ===== Main ===== }

begin
  T := TTestRunner.Create('nextpas.core.http.smoke');
  T.Run('GET 200 with body', @TestGet200WithBody);
  T.Run('POST with JSON content-type', @TestPostWithJson);
  T.Run('Router path params', @TestRouterPathParams);
  T.Run('Redirect chain (301 -> 200)', @TestRedirectChain);
  T.Run('Concurrent clients (2x5 requests)', @TestConcurrentClients);
  T.Run('Client timeout', @TestClientTimeout);
  T.Summary;
end.
