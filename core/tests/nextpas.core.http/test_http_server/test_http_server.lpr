program test_http_server;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.net,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.router,
  nextpas.core.http.server,
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

function SendRawRequest(const APort: UInt16; const ARequest: string): string;
var
  LConn: ITcpStream;
  LBuf: array[0..8191] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  LConn := TcpConnect('127.0.0.1', APort);
  try
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
    LConn.Write(ARequest[1], SizeUInt(Length(ARequest)));
    { Read response — read until connection closed or timeout }
    repeat
      try
        LN := LConn.Read(LBuf[0], 8192);
      except
        LN := 0;
      end;
      if LN > 0 then
      begin
        SetLength(Result, Length(Result) + Int32(LN));
        Move(LBuf[0], Result[Length(Result) - Int32(LN) + 1], LN);
      end;
    until LN = 0;
  finally
    LConn.Close;
  end;
end;

{ Test 1: Server responds 200 to simple GET }
procedure TestSimpleGet200;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ping', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := 'pong';
    AW.GetHeaders.Set_('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET /ping HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'status 200 in response');
    Check(Pos('pong', LResp) > 0, 'body pong in response');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 2: Server responds with custom body }
procedure TestCustomBody;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/hello', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := 'Hello, World!';
    AW.GetHeaders.Set_('content-type', 'text/plain');
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET /hello HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'status 200');
    Check(Pos('Hello, World!', LResp) > 0, 'custom body present');
    Check(Pos('content-type: text/plain', LResp) > 0, 'content-type header');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 3: Server responds 404 for unmatched route }
procedure TestNotFound404;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/exists', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET /nope HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 404', LResp) > 0, 'status 404 for unmatched route');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4: Handler exception results in 500 }
type
  TCrashHandler = class(TInterfacedObject, IHttpHandler)
    procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
  end;

procedure TCrashHandler.ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
begin
  raise Exception.Create('intentional crash');
end;

procedure TestHandlerException500;
var
  LHandler: IHttpHandler;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LHandler := TCrashHandler.Create;
  LHandle := StartServer(LHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 500', LResp) > 0, 'status 500 on handler exception');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 5: Shutdown stops accepting }
procedure TestShutdownStopsAccepting;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LConnected: Boolean;
  LConn: ITcpStream;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/x', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  { Shutdown the server }
  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
  { Verify server is no longer running }
  Check(not LServer.IsRunning, 'server not running after shutdown');
  { Try to connect — should fail }
  LConnected := True;
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.Close;
  except
    LConnected := False;
  end;
  Check(not LConnected, 'connection refused after shutdown');
  LServer.Free;
end;

{ Test 6: POST request with body }
procedure TestPostWithBody;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Post('/echo', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := 'received';
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_CREATED);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort,
      'POST /echo HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Content-Length: 5'#13#10 +
      'Connection: close'#13#10#13#10 +
      'hello');
    Check(Pos('HTTP/1.1 201', LResp) > 0, 'status 201 for POST');
    Check(Pos('received', LResp) > 0, 'response body present');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Helper: read a single HTTP response from a connection (reads headers + content-length body) }
function ReadOneResponse(const AConn: ITcpStream): string;
var
  LBuf: array[0..0] of Byte;
  LN: SizeUInt;
  LHeaderEnd: Int32;
  LContentLength: Int32;
  LClPos, LClEnd: Int32;
  LClStr: string;
  LBodyRead: Int32;
begin
  Result := '';
  { Read byte-by-byte until we see CRLFCRLF (header end) }
  repeat
    try
      LN := AConn.Read(LBuf[0], 1);
    except
      LN := 0;
    end;
    if LN = 0 then Exit;
    Result := Result + Chr(LBuf[0]);
    LHeaderEnd := Pos(#13#10#13#10, Result);
  until LHeaderEnd > 0;

  { Parse content-length from headers }
  LContentLength := 0;
  LClPos := Pos('content-length: ', Result);
  if LClPos > 0 then
  begin
    LClPos := LClPos + 16; { length of 'content-length: ' }
    LClEnd := LClPos;
    while (LClEnd <= Length(Result)) and (Result[LClEnd] >= '0') and (Result[LClEnd] <= '9') do
      Inc(LClEnd);
    LClStr := Copy(Result, LClPos, LClEnd - LClPos);
    LContentLength := Int32(StrToInt(LClStr));
  end;

  { Read body bytes }
  LBodyRead := Length(Result) - (LHeaderEnd + 3); { bytes after CRLFCRLF already in buffer }
  while LBodyRead < LContentLength do
  begin
    try
      LN := AConn.Read(LBuf[0], 1);
    except
      LN := 0;
    end;
    if LN = 0 then Exit;
    Result := Result + Chr(LBuf[0]);
    Inc(LBodyRead);
  end;
end;

{ Test 7: Keep-alive — two requests on same connection }
procedure TestKeepAlive;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1, LResp2: string;
const
  REQ = 'GET /ping HTTP/1.1'#13#10'Host: localhost'#13#10#13#10;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ping', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := 'pong';
    AW.GetHeaders.Set_('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));

      { First request }
      LConn.Write(REQ[1], SizeUInt(Length(REQ)));
      LResp1 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp1) > 0, 'keep-alive: first response 200');
      Check(Pos('pong', LResp1) > 0, 'keep-alive: first body');

      { Second request on same connection }
      LConn.Write(REQ[1], SizeUInt(Length(REQ)));
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp2) > 0, 'keep-alive: second response 200');
      Check(Pos('pong', LResp2) > 0, 'keep-alive: second body');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 8: Connection: close header stops keep-alive }
procedure TestConnectionClose;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp: string;
  LBuf: array[0..0] of Byte;
  LN: SizeUInt;
const
  REQ = 'GET /ping HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ping', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := 'pong';
    AW.GetHeaders.Set_('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ[1], SizeUInt(Length(REQ)));
      LResp := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp) > 0, 'conn-close: got 200');
      Check(Pos('connection: close', LResp) > 0, 'conn-close: header present');
      { Verify server closed the connection }
      try
        LN := LConn.Read(LBuf[0], 1);
      except
        LN := 0;
      end;
      Check(LN = 0, 'conn-close: server closed connection');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 9: HTTP/1.0 without keep-alive closes connection }
procedure TestHttp10NoKeepAlive;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp: string;
  LBuf: array[0..0] of Byte;
  LN: SizeUInt;
const
  REQ = 'GET /ping HTTP/1.0'#13#10'Host: localhost'#13#10#13#10;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ping', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := 'pong';
    AW.GetHeaders.Set_('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ[1], SizeUInt(Length(REQ)));
      LResp := ReadOneResponse(LConn);
      Check(Pos('200', LResp) > 0, 'http10: got 200');
      { Verify server closed the connection }
      try
        LN := LConn.Read(LBuf[0], 1);
      except
        LN := 0;
      end;
      Check(LN = 0, 'http10: server closed connection');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 10: POST body readable via IReader }
procedure TestPostBodyReadable;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBuf: array[0..4095] of Byte; LN: SizeUInt; LBody: string;
  begin
    LBody := '';
    if AReq.Body <> nil then
    begin
      LN := AReq.Body.Read(LBuf[0], 4096);
      if LN > 0 then SetString(LBody, PAnsiChar(@LBuf[0]), LN);
    end;
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    if Length(LBody) > 0 then
      AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort,
      'POST / HTTP/1.1'#13#10 +
      'Host: x'#13#10 +
      'Content-Length: 11'#13#10 +
      'Connection: close'#13#10#13#10 +
      'hello world');
    Check(Pos('hello world', LResp) > 0, 'body echoed back');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 11: Large body (131072 bytes) }
procedure TestLargeBody;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LReq: string;
  LBody: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBuf: array[0..4095] of Byte; LN: SizeUInt; LTotal: SizeUInt; LReply: string;
  begin
    LTotal := 0;
    if AReq.Body <> nil then
    begin
      repeat
        LN := AReq.Body.Read(LBuf[0], 4096);
        LTotal := LTotal + LN;
      until LN = 0;
    end;
    LReply := IntToStr(Int64(LTotal));
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LReply))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LReply[1], SizeUInt(Length(LReply)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    SetLength(LBody, 131072);
    FillChar(LBody[1], 131072, Ord('x'));
    LReq := 'POST / HTTP/1.1'#13#10 +
      'Host: x'#13#10 +
      'Content-Length: 131072'#13#10 +
      'Connection: close'#13#10#13#10 +
      LBody;
    LResp := SendRawRequest(LPort, LReq);
    Check(Pos('131072', LResp) > 0, 'large body length echoed');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 12: Malformed request returns 400 or closes }
procedure TestMalformedRequest;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GARBAGE DATA HERE'#13#10#13#10);
    Check((Pos('400', LResp) > 0) or (Length(LResp) = 0), 'malformed request: 400 or closed');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 13: Query parameters }
procedure TestQueryParam;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/search', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := AReq.QueryParam('q') + ':' + AReq.QueryParam('page');
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort,
      'GET /search?q=hello&page=2 HTTP/1.1'#13#10 +
      'Host: x'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('hello', LResp) > 0, 'query param q=hello');
    Check(Pos('2', LResp) > 0, 'query param page=2');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 14: RemoteAddr contains 127.0.0.1 }
procedure TestRemoteAddr;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := AReq.RemoteAddr;
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort,
      'GET / HTTP/1.1'#13#10 +
      'Host: x'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('127.0.0.1', LResp) > 0, 'remote addr is 127.0.0.1');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 15: Concurrent stress — 10 threads x 100 requests }
var
  GStressSuccess: Int32 = 0;
  GStressDone: Int32 = 0;
  GServerPort: UInt16 = 0;

function StressThread(AParam: Pointer): Pointer; cdecl;
var
  LI: Int32;
  LConn: ITcpStream;
  LBuf: array[0..1023] of Byte;
  LN, LRead: SizeUInt;
  LReq: string;
  LHeaderEnd: Int32;
  LResp: string;
begin
  Result := nil;
  try
    LReq := 'GET / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 0'#13#10#13#10;
    LConn := TcpConnect('127.0.0.1', GServerPort);
    LConn.SetNoDelay(True);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(10)));
    for LI := 1 to 100 do
    begin
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      { Read until we see end of response (CRLFCRLF + body) }
      LResp := '';
      repeat
        LRead := LConn.Read(LBuf[0], 1024);
        if LRead > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LRead));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LRead) + 1], LRead);
        end;
        LHeaderEnd := Pos(#13#10#13#10, LResp);
      until (LHeaderEnd > 0) or (LRead = 0);
      if Pos('200', LResp) > 0 then
        InterlockedIncrement(GStressSuccess);
    end;
    LConn.Close;
  except
  end;
  InterlockedIncrement(GStressDone);
end;

procedure TestConcurrentStress;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LThreads: array[0..9] of TPlatformThreadHandle;
  LI, LWait: Int32;
  LRet: Pointer;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := 'ok';
    AW.GetHeaders.Set_('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    GServerPort := LPort;
    GStressSuccess := 0;
    GStressDone := 0;
    for LI := 0 to 9 do
      platform_thread_create(LThreads[LI], @StressThread, nil);
    { Wait for all threads to finish }
    LWait := 0;
    while (GStressDone < 10) and (LWait < 2000) do
    begin
      platform_thread_sleep_ns(5000000); { 5ms }
      Inc(LWait);
    end;
    for LI := 0 to 9 do
      platform_thread_join(LThreads[LI], LRet);
    Check(GStressSuccess = 1000, 'stress: 1000 successes (got ' + IntToStr(Int64(GStressSuccess)) + ')');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Main }

begin
  T := TTestRunner.Create('nextpas.core.http.server');
  T.Run('Simple GET 200', @TestSimpleGet200);
  T.Run('Custom body response', @TestCustomBody);
  T.Run('404 for unmatched route', @TestNotFound404);
  T.Run('Handler exception -> 500', @TestHandlerException500);
  T.Run('Shutdown stops accepting', @TestShutdownStopsAccepting);
  T.Run('POST with body -> 201', @TestPostWithBody);
  T.Run('Keep-alive: two requests one connection', @TestKeepAlive);
  T.Run('Connection: close stops keep-alive', @TestConnectionClose);
  T.Run('HTTP/1.0 no keep-alive', @TestHttp10NoKeepAlive);
  T.Run('POST body readable via IReader', @TestPostBodyReadable);
  T.Run('Large body 131072 bytes', @TestLargeBody);
  T.Run('Malformed request -> 400 or close', @TestMalformedRequest);
  T.Run('Query parameters', @TestQueryParam);
  T.Run('RemoteAddr is 127.0.0.1', @TestRemoteAddr);
  T.Run('Concurrent stress 10x100', @TestConcurrentStress);
  T.Summary;
end.
