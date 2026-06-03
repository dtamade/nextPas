program test_http_server;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
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

function StartServerWithOptions(const AHandler: IHttpHandler; const AOptions: THttpServerOptions;
  out AServer: THttpServer; out APort: UInt16): TPlatformThreadHandle;
var
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
begin
  AServer := THttpServer.Create(AHandler, AOptions);
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

function SendRawRequestAndShutdownWrite(const APort: UInt16; const ARequest: string): string;
var
  LConn: ITcpStream;
  LBuf: array[0..8191] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  LConn := TcpConnect('127.0.0.1', APort);
  try
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
    if ARequest <> '' then
      LConn.Write(ARequest[1], SizeUInt(Length(ARequest)));
    LConn.Shutdown;
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

function SendRawRequestBytes(const APort: UInt16; const AData: PByte; ALen: SizeUInt): string;
var
  LConn: ITcpStream;
  LBuf: array[0..8191] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  LConn := TcpConnect('127.0.0.1', APort);
  try
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
    if ALen > 0 then
      LConn.Write(AData^, ALen);
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

procedure TestPipelinedRequestsInSingleWrite;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1, LResp2: string;
  LSeenUpload: Boolean;
  LSeenNext: Boolean;
  LCombinedReq: string;
const
  REQ1 = 'POST /upload HTTP/1.1'#13#10 +
         'Host: localhost'#13#10 +
         'Content-Length: 5'#13#10#13#10 +
         'hello';
  REQ2 = 'GET /next HTTP/1.1'#13#10 +
         'Host: localhost'#13#10 +
         'Connection: close'#13#10#13#10;
begin
  LSeenUpload := False;
  LSeenNext := False;
  LCombinedReq := REQ1 + REQ2;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
    LBody := '';
    if AReq.Body <> nil then
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
        if LN > 0 then
        begin
          SetLength(LBody, Length(LBody) + Int32(LN));
          Move(LBuf[0], LBody[Length(LBody) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
    LBody := 'upload:' + LBody;
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LRouter.Get('/next', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LSeenNext := True;
    LBody := 'next';
    AW.GetHeaders.Set_('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(LCombinedReq[1], SizeUInt(Length(LCombinedReq)));
      LResp1 := ReadOneResponse(LConn);
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp1) > 0, 'pipeline-single-write: first response 200');
      Check(Pos('upload:hello', LResp1) > 0, 'pipeline-single-write: first body preserved');
      Check(Pos('200 OK', LResp2) > 0, 'pipeline-single-write: second response 200');
      Check(Pos('next', LResp2) > 0, 'pipeline-single-write: second body preserved');
      Check(LSeenUpload, 'pipeline-single-write: upload handler called');
      Check(LSeenNext, 'pipeline-single-write: next handler called');
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

{ Test 12: Generic malformed request returns explicit 400 }
procedure TestMalformedRequest;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GARBAGE DATA HERE'#13#10#13#10);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'generic malformed request: status 400');
    Check(not LHandlerCalled, 'generic malformed request: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestDuplicateContentLength;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Content-Length: 5'#13#10 +
        'Content-Length: 10'#13#10 +
        'Connection: close'#13#10#13#10 +
        'hello';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'duplicate content-length: status 400');
    Check(not LHandlerCalled, 'duplicate content-length: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHeaderNullByte;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LReq: array of Byte;
  LHandlerCalled: Boolean;
const
  PREFIX = 'GET / HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'X-Evil: foo';
  SUFFIX = 'bar'#13#10 +
           'Connection: close'#13#10#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    SetLength(LReq, Length(PREFIX) + 1 + Length(SUFFIX));
    Move(PREFIX[1], LReq[0], Length(PREFIX));
    LReq[Length(PREFIX)] := 0;
    Move(SUFFIX[1], LReq[Length(PREFIX) + 1], Length(SUFFIX));
    LResp := SendRawRequestBytes(LPort, @LReq[0], SizeUInt(Length(LReq)));
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'null byte in header: status 400');
    Check(not LHandlerCalled, 'null byte in header: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestRequestLineTruncatedAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'GET / HTTP/1.';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'truncated request line: status 400');
    Check(not LHandlerCalled, 'truncated request line: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHeadersTruncatedAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'GET / HTTP/1.1'#13#10 +
        'Host: local';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'truncated headers: status 400');
    Check(not LHandlerCalled, 'truncated headers: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMissingHostHeader;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'GET / HTTP/1.1'#13#10 +
        'Connection: close'#13#10#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'missing host http11: status 400');
    Check(not LHandlerCalled, 'missing host http11: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHttp10WithoutHostStillAllowed;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
const
  REQ = 'GET /ping HTTP/1.0'#13#10#13#10;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ping', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LBody := 'pong';
    AW.GetHeaders.Set_('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'missing host http10: status 200');
    Check(Pos('pong', LResp) > 0, 'missing host http10: body pong');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHttp09NoVersionRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'GET /'#13#10#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'http09 request: status 400');
    Check(not LHandlerCalled, 'http09 request: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestRequestLineSplittingRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'GET /path'#13#10 +
        'Injected: header HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Connection: close'#13#10#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Get('/path', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'request-line splitting: status 400');
    Check(not LHandlerCalled, 'request-line splitting: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestNegativeContentLengthRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Content-Length: -1'#13#10 +
        'Connection: close'#13#10#13#10 +
        'hello';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'negative content-length: status 400');
    Check(not LHandlerCalled, 'negative content-length: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestVeryLongMethodRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
  LMethod: string;
  LReq: string;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  SetLength(LMethod, 1000);
  FillChar(LMethod[1], 1000, Ord('X'));
  LReq := LMethod + ' / HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Connection: close'#13#10#13#10;
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, LReq);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'very long method: status 400');
    Check(not LHandlerCalled, 'very long method: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestContentLengthRequestExtraBytesAfterCloseRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Content-Length: 5'#13#10 +
        'Connection: close'#13#10#13#10 +
        'hello_extra_bytes_here';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'content-length extra bytes after close: status 400');
    Check(not LHandlerCalled, 'content-length extra bytes after close: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestContentLengthKeepAliveGarbageTailBecomesFollowUp400;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1: string;
  LResp2: string;
  LGotBody: string;
  LSeenUpload: Boolean;
const
  REQ = 'POST /upload HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Content-Length: 5'#13#10#13#10 +
        'hello_extra_bytes_here';
begin
  LGotBody := '';
  LSeenUpload := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
    LBody := '';
    if AReq.Body <> nil then
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
        if LN > 0 then
        begin
          SetLength(LBody, Length(LBody) + Int32(LN));
          Move(LBuf[0], LBody[Length(LBody) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
    LGotBody := LBody;
    LBody := 'upload:' + LBody;
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ[1], SizeUInt(Length(REQ)));
      LResp1 := ReadOneResponse(LConn);
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp1) > 0, 'keep-alive tail: first response 200');
      Check(Pos('upload:hello', LResp1) > 0, 'keep-alive tail: first body preserved');
      Check(LSeenUpload, 'keep-alive tail: first handler called');
      CheckEqual('hello', LGotBody, 'keep-alive tail: handler sees declared body only');
      Check(Pos('HTTP/1.1 400', LResp2) > 0, 'keep-alive tail: malformed follow-up gets 400');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestContentLengthKeepAliveTruncatedFollowUpRequestLineBecomesFollowUp400;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LGotBody: string;
  LSeenUpload: Boolean;
const
  REQ = 'POST /upload HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Content-Length: 5'#13#10#13#10 +
        'hello' +
        'GET /next HTTP/1.1';
begin
  LGotBody := '';
  LSeenUpload := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
    LBody := '';
    if AReq.Body <> nil then
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
        if LN > 0 then
        begin
          SetLength(LBody, Length(LBody) + Int32(LN));
          Move(LBuf[0], LBody[Length(LBody) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
    LGotBody := LBody;
    LBody := 'upload:' + LBody;
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('200 OK', LResp) > 0, 'keep-alive partial follow-up line: first response 200');
    Check(Pos('upload:hello', LResp) > 0, 'keep-alive partial follow-up line: first body preserved');
    Check(LSeenUpload, 'keep-alive partial follow-up line: first handler called');
    CheckEqual('hello', LGotBody, 'keep-alive partial follow-up line: handler sees declared body only');
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'keep-alive partial follow-up line: malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestContentLengthKeepAliveTruncatedFollowUpHeadersBecomesFollowUp400;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LGotBody: string;
  LSeenUpload: Boolean;
const
  REQ = 'POST /upload HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Content-Length: 5'#13#10#13#10 +
        'hello' +
        'GET /next HTTP/1.1'#13#10 +
        'Host: localhost'#13#10;
begin
  LGotBody := '';
  LSeenUpload := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
    LBody := '';
    if AReq.Body <> nil then
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
        if LN > 0 then
        begin
          SetLength(LBody, Length(LBody) + Int32(LN));
          Move(LBuf[0], LBody[Length(LBody) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
    LGotBody := LBody;
    LBody := 'upload:' + LBody;
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('200 OK', LResp) > 0, 'keep-alive partial follow-up headers: first response 200');
    Check(Pos('upload:hello', LResp) > 0, 'keep-alive partial follow-up headers: first body preserved');
    Check(LSeenUpload, 'keep-alive partial follow-up headers: first handler called');
    CheckEqual('hello', LGotBody, 'keep-alive partial follow-up headers: handler sees declared body only');
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'keep-alive partial follow-up headers: malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedRequestExtraBytesAfterCloseRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10#13#10 +
        'garbage';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'chunked extra bytes after close: status 400');
    Check(not LHandlerCalled, 'chunked extra bytes after close: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedKeepAliveGarbageTailBecomesFollowUp400;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1: string;
  LResp2: string;
  LGotBody: string;
  LSeenUpload: Boolean;
const
  REQ = 'POST /upload HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10#13#10 +
        'garbage';
begin
  LGotBody := '';
  LSeenUpload := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
    LBody := '';
    if AReq.Body <> nil then
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
        if LN > 0 then
        begin
          SetLength(LBody, Length(LBody) + Int32(LN));
          Move(LBuf[0], LBody[Length(LBody) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
    LGotBody := LBody;
    LBody := 'upload:' + LBody;
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ[1], SizeUInt(Length(REQ)));
      LResp1 := ReadOneResponse(LConn);
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp1) > 0, 'keep-alive chunked tail: first response 200');
      Check(Pos('upload:hello', LResp1) > 0, 'keep-alive chunked tail: first body preserved');
      Check(LSeenUpload, 'keep-alive chunked tail: first handler called');
      CheckEqual('hello', LGotBody, 'keep-alive chunked tail: handler sees decoded body only');
      Check(Pos('HTTP/1.1 400', LResp2) > 0, 'keep-alive chunked tail: malformed follow-up gets 400');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedKeepAliveTruncatedFollowUpRequestLineBecomesFollowUp400;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LGotBody: string;
  LSeenUpload: Boolean;
const
  REQ = 'POST /upload HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10#13#10 +
        'GET /next HTTP/1.1';
begin
  LGotBody := '';
  LSeenUpload := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
    LBody := '';
    if AReq.Body <> nil then
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
        if LN > 0 then
        begin
          SetLength(LBody, Length(LBody) + Int32(LN));
          Move(LBuf[0], LBody[Length(LBody) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
    LGotBody := LBody;
    LBody := 'upload:' + LBody;
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('200 OK', LResp) > 0, 'keep-alive chunked partial follow-up line: first response 200');
    Check(Pos('upload:hello', LResp) > 0, 'keep-alive chunked partial follow-up line: first body preserved');
    Check(LSeenUpload, 'keep-alive chunked partial follow-up line: first handler called');
    CheckEqual('hello', LGotBody, 'keep-alive chunked partial follow-up line: handler sees decoded body only');
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'keep-alive chunked partial follow-up line: malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedKeepAliveTruncatedFollowUpHeadersBecomesFollowUp400;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LGotBody: string;
  LSeenUpload: Boolean;
const
  REQ = 'POST /upload HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10#13#10 +
        'GET /next HTTP/1.1'#13#10 +
        'Host: localhost'#13#10;
begin
  LGotBody := '';
  LSeenUpload := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
    LBody := '';
    if AReq.Body <> nil then
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
        if LN > 0 then
        begin
          SetLength(LBody, Length(LBody) + Int32(LN));
          Move(LBuf[0], LBody[Length(LBody) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
    LGotBody := LBody;
    LBody := 'upload:' + LBody;
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('200 OK', LResp) > 0, 'keep-alive chunked partial follow-up headers: first response 200');
    Check(Pos('upload:hello', LResp) > 0, 'keep-alive chunked partial follow-up headers: first body preserved');
    Check(LSeenUpload, 'keep-alive chunked partial follow-up headers: first handler called');
    CheckEqual('hello', LGotBody, 'keep-alive chunked partial follow-up headers: handler sees decoded body only');
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'keep-alive chunked partial follow-up headers: malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedTrailerKeepAliveGarbageTailBecomesFollowUp400;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1: string;
  LResp2: string;
  LGotBody: string;
  LGotTrailerDecl: string;
  LGotTrailerValue: string;
  LSeenUpload: Boolean;
const
  REQ = 'POST /upload HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test: value'#13#10#13#10 +
        'garbage';
begin
  LGotBody := '';
  LGotTrailerDecl := '';
  LGotTrailerValue := '';
  LSeenUpload := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
    LBody := '';
    if AReq.Body <> nil then
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
        if LN > 0 then
        begin
          SetLength(LBody, Length(LBody) + Int32(LN));
          Move(LBuf[0], LBody[Length(LBody) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
    LGotBody := LBody;
    LGotTrailerDecl := AReq.Headers.Get('Trailer');
    LGotTrailerValue := AReq.Headers.Get('X-Test');
    LBody := 'upload:' + LBody;
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ[1], SizeUInt(Length(REQ)));
      LResp1 := ReadOneResponse(LConn);
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp1) > 0, 'keep-alive chunked trailer tail: first response 200');
      Check(Pos('upload:hello', LResp1) > 0, 'keep-alive chunked trailer tail: first body preserved');
      Check(LSeenUpload, 'keep-alive chunked trailer tail: first handler called');
      CheckEqual('hello', LGotBody, 'keep-alive chunked trailer tail: handler sees decoded body only');
      CheckEqual('X-Test', LGotTrailerDecl, 'keep-alive chunked trailer tail: trailer declaration preserved');
      CheckEqual('', LGotTrailerValue, 'keep-alive chunked trailer tail: trailer field not exposed as regular header');
      Check(Pos('HTTP/1.1 400', LResp2) > 0, 'keep-alive chunked trailer tail: malformed follow-up gets 400');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedTrailerKeepAliveTruncatedFollowUpRequestLineBecomesFollowUp400;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LGotBody: string;
  LGotTrailerDecl: string;
  LGotTrailerValue: string;
  LSeenUpload: Boolean;
const
  REQ = 'POST /upload HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test: value'#13#10#13#10 +
        'GET /next HTTP/1.1';
begin
  LGotBody := '';
  LGotTrailerDecl := '';
  LGotTrailerValue := '';
  LSeenUpload := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
    LBody := '';
    if AReq.Body <> nil then
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
        if LN > 0 then
        begin
          SetLength(LBody, Length(LBody) + Int32(LN));
          Move(LBuf[0], LBody[Length(LBody) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
    LGotBody := LBody;
    LGotTrailerDecl := AReq.Headers.Get('Trailer');
    LGotTrailerValue := AReq.Headers.Get('X-Test');
    LBody := 'upload:' + LBody;
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('200 OK', LResp) > 0, 'keep-alive chunked trailer partial follow-up line: first response 200');
    Check(Pos('upload:hello', LResp) > 0, 'keep-alive chunked trailer partial follow-up line: first body preserved');
    Check(LSeenUpload, 'keep-alive chunked trailer partial follow-up line: first handler called');
    CheckEqual('hello', LGotBody, 'keep-alive chunked trailer partial follow-up line: handler sees decoded body only');
    CheckEqual('X-Test', LGotTrailerDecl, 'keep-alive chunked trailer partial follow-up line: trailer declaration preserved');
    CheckEqual('', LGotTrailerValue, 'keep-alive chunked trailer partial follow-up line: trailer field not exposed as regular header');
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'keep-alive chunked trailer partial follow-up line: malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedTrailerKeepAliveTruncatedFollowUpHeadersBecomesFollowUp400;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LGotBody: string;
  LGotTrailerDecl: string;
  LGotTrailerValue: string;
  LSeenUpload: Boolean;
const
  REQ = 'POST /upload HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test: value'#13#10#13#10 +
        'GET /next HTTP/1.1'#13#10 +
        'Host: localhost'#13#10;
begin
  LGotBody := '';
  LGotTrailerDecl := '';
  LGotTrailerValue := '';
  LSeenUpload := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
    LBody := '';
    if AReq.Body <> nil then
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
        if LN > 0 then
        begin
          SetLength(LBody, Length(LBody) + Int32(LN));
          Move(LBuf[0], LBody[Length(LBody) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
    LGotBody := LBody;
    LGotTrailerDecl := AReq.Headers.Get('Trailer');
    LGotTrailerValue := AReq.Headers.Get('X-Test');
    LBody := 'upload:' + LBody;
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('200 OK', LResp) > 0, 'keep-alive chunked trailer partial follow-up headers: first response 200');
    Check(Pos('upload:hello', LResp) > 0, 'keep-alive chunked trailer partial follow-up headers: first body preserved');
    Check(LSeenUpload, 'keep-alive chunked trailer partial follow-up headers: first handler called');
    CheckEqual('hello', LGotBody, 'keep-alive chunked trailer partial follow-up headers: handler sees decoded body only');
    CheckEqual('X-Test', LGotTrailerDecl, 'keep-alive chunked trailer partial follow-up headers: trailer declaration preserved');
    CheckEqual('', LGotTrailerValue, 'keep-alive chunked trailer partial follow-up headers: trailer field not exposed as regular header');
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'keep-alive chunked trailer partial follow-up headers: malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedTrailerPipelinedRequestsInSingleWrite;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1: string;
  LResp2: string;
  LSeenUpload: Boolean;
  LSeenNext: Boolean;
  LGotBody: string;
  LGotTrailerDecl: string;
  LGotTrailerValue: string;
  LCombinedReq: string;
const
  REQ1 = 'POST /upload HTTP/1.1'#13#10 +
         'Host: localhost'#13#10 +
         'Transfer-Encoding: chunked'#13#10 +
         'Trailer: X-Test'#13#10#13#10 +
         '5'#13#10'hello'#13#10 +
         '0'#13#10 +
         'X-Test: value'#13#10#13#10;
  REQ2 = 'GET /next HTTP/1.1'#13#10 +
         'Host: localhost'#13#10 +
         'Connection: close'#13#10#13#10;
begin
  LSeenUpload := False;
  LSeenNext := False;
  LGotBody := '';
  LGotTrailerDecl := '';
  LGotTrailerValue := '';
  LCombinedReq := REQ1 + REQ2;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
    LBody := '';
    if AReq.Body <> nil then
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
        if LN > 0 then
        begin
          SetLength(LBody, Length(LBody) + Int32(LN));
          Move(LBuf[0], LBody[Length(LBody) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
    LGotBody := LBody;
    LGotTrailerDecl := AReq.Headers.Get('Trailer');
    LGotTrailerValue := AReq.Headers.Get('X-Test');
    LBody := 'upload:' + LBody;
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LRouter.Get('/next', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LSeenNext := True;
    LBody := 'next';
    AW.GetHeaders.Set_('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(LCombinedReq[1], SizeUInt(Length(LCombinedReq)));
      LResp1 := ReadOneResponse(LConn);
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp1) > 0, 'pipeline-chunked-trailer: first response 200');
      Check(Pos('upload:hello', LResp1) > 0, 'pipeline-chunked-trailer: first body preserved');
      Check(Pos('200 OK', LResp2) > 0, 'pipeline-chunked-trailer: second response 200');
      Check(Pos('next', LResp2) > 0, 'pipeline-chunked-trailer: second body preserved');
      Check(LSeenUpload, 'pipeline-chunked-trailer: upload handler called');
      Check(LSeenNext, 'pipeline-chunked-trailer: next handler called');
      CheckEqual('hello', LGotBody, 'pipeline-chunked-trailer: handler sees decoded body only');
      CheckEqual('X-Test', LGotTrailerDecl, 'pipeline-chunked-trailer: trailer declaration preserved');
      CheckEqual('', LGotTrailerValue, 'pipeline-chunked-trailer: trailer field not exposed as regular header');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedTrailerPartialFollowUpRequestLineCanCompleteLater;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1: string;
  LResp2: string;
  LSeenUpload: Boolean;
  LSeenNext: Boolean;
  LGotBody: string;
  LGotTrailerDecl: string;
  LGotTrailerValue: string;
const
  REQ1 = 'POST /upload HTTP/1.1'#13#10 +
         'Host: localhost'#13#10 +
         'Transfer-Encoding: chunked'#13#10 +
         'Trailer: X-Test'#13#10#13#10 +
         '5'#13#10'hello'#13#10 +
         '0'#13#10 +
         'X-Test: value'#13#10#13#10 +
         'GET /next HTTP/1.1';
  REQ2_REST = #13#10 +
              'Host: localhost'#13#10 +
              'Connection: close'#13#10#13#10;
begin
  LSeenUpload := False;
  LSeenNext := False;
  LGotBody := '';
  LGotTrailerDecl := '';
  LGotTrailerValue := '';
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
    LBody := '';
    if AReq.Body <> nil then
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
        if LN > 0 then
        begin
          SetLength(LBody, Length(LBody) + Int32(LN));
          Move(LBuf[0], LBody[Length(LBody) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
    LGotBody := LBody;
    LGotTrailerDecl := AReq.Headers.Get('Trailer');
    LGotTrailerValue := AReq.Headers.Get('X-Test');
    LBody := 'upload:' + LBody;
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LRouter.Get('/next', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LSeenNext := True;
    LBody := 'next';
    AW.GetHeaders.Set_('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ1[1], SizeUInt(Length(REQ1)));
      LResp1 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp1) > 0, 'chunked trailer partial-next-line: first response 200');
      Check(Pos('upload:hello', LResp1) > 0, 'chunked trailer partial-next-line: first body preserved');
      Check(LSeenUpload, 'chunked trailer partial-next-line: first handler called');
      CheckEqual('hello', LGotBody, 'chunked trailer partial-next-line: handler sees decoded body only');
      CheckEqual('X-Test', LGotTrailerDecl, 'chunked trailer partial-next-line: trailer declaration preserved');
      CheckEqual('', LGotTrailerValue, 'chunked trailer partial-next-line: trailer field not exposed as regular header');

      LConn.Write(REQ2_REST[1], SizeUInt(Length(REQ2_REST)));
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp2) > 0, 'chunked trailer partial-next-line: second response 200');
      Check(Pos('next', LResp2) > 0, 'chunked trailer partial-next-line: second body preserved');
      Check(LSeenNext, 'chunked trailer partial-next-line: second handler called');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedPipelinedRequestsInSingleWrite;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1: string;
  LResp2: string;
  LSeenUpload: Boolean;
  LSeenNext: Boolean;
  LCombinedReq: string;
const
  REQ1 = 'POST /upload HTTP/1.1'#13#10 +
         'Host: localhost'#13#10 +
         'Transfer-Encoding: chunked'#13#10#13#10 +
         '5'#13#10'hello'#13#10 +
         '0'#13#10#13#10;
  REQ2 = 'GET /next HTTP/1.1'#13#10 +
         'Host: localhost'#13#10 +
         'Connection: close'#13#10#13#10;
begin
  LSeenUpload := False;
  LSeenNext := False;
  LCombinedReq := REQ1 + REQ2;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
    LBody := '';
    if AReq.Body <> nil then
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
        if LN > 0 then
        begin
          SetLength(LBody, Length(LBody) + Int32(LN));
          Move(LBuf[0], LBody[Length(LBody) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
    LBody := 'upload:' + LBody;
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LRouter.Get('/next', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LSeenNext := True;
    LBody := 'next';
    AW.GetHeaders.Set_('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(LCombinedReq[1], SizeUInt(Length(LCombinedReq)));
      LResp1 := ReadOneResponse(LConn);
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp1) > 0, 'pipeline-chunked: first response 200');
      Check(Pos('upload:hello', LResp1) > 0, 'pipeline-chunked: first body preserved');
      Check(Pos('200 OK', LResp2) > 0, 'pipeline-chunked: second response 200');
      Check(Pos('next', LResp2) > 0, 'pipeline-chunked: second body preserved');
      Check(LSeenUpload, 'pipeline-chunked: upload handler called');
      Check(LSeenNext, 'pipeline-chunked: next handler called');
    finally
      LConn.Close;
    end;
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
  LRead: SizeUInt;
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

{ Test 16: MaxHeaderSize enforcement — 431 }
procedure TestMaxHeaderSize;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LOpts: THttpServerOptions;
  LReq: string;
  LBigHeader: string;
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
  LOpts := THttpServerOptions.Default;
  LOpts.MaxHeaderSize := 256; { Very small limit for testing }
  LHandle := StartServerWithOptions(LRouter as IHttpHandler, LOpts, LServer, LPort);
  try
    { Build a request with headers > 256 bytes }
    SetLength(LBigHeader, 300);
    FillChar(LBigHeader[1], 300, Ord('x'));
    LReq := 'GET / HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'X-Big: ' + LBigHeader + #13#10 +
      'Connection: close'#13#10#13#10;
    LResp := SendRawRequest(LPort, LReq);
    Check((Pos('431', LResp) > 0) or (Length(LResp) = 0),
      'max header size: 431 or connection closed');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 17: MaxBodySize enforcement — 413 }
procedure TestMaxBodySize;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LOpts: THttpServerOptions;
  LBody: string;
  LReq: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LReply: string;
  begin
    LReply := 'ok';
    AW.GetHeaders.Set_('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LReply[1], 2);
  end);
  LOpts := THttpServerOptions.Default;
  LOpts.MaxBodySize := 1024; { 1KB limit }
  LHandle := StartServerWithOptions(LRouter as IHttpHandler, LOpts, LServer, LPort);
  try
    { Send body > 1KB }
    SetLength(LBody, 2048);
    FillChar(LBody[1], 2048, Ord('A'));
    LReq := 'POST / HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Content-Length: 2048'#13#10 +
      'Connection: close'#13#10#13#10 +
      LBody;
    LResp := SendRawRequest(LPort, LReq);
    Check((Pos('413', LResp) > 0) or (Length(LResp) = 0),
      'max body size: 413 or connection closed');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestContentLengthRequestTruncatedAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Content-Length: 10'#13#10 +
        'Connection: close'#13#10#13#10 +
        'hello';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated content-length request: status 400');
    Check(not LHandlerCalled, 'truncated content-length request: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedRequestBodyReadable;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LGotBody: string;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '6'#13#10' world'#13#10 +
        '0'#13#10#13#10;
begin
  LGotBody := '';
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LReply: string;
    LBuf: array[0..255] of Byte;
    LN: SizeUInt;
  begin
    repeat
      LN := AReq.Body.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
      if LN > 0 then
      begin
        SetLength(LGotBody, Length(LGotBody) + Int32(LN));
        Move(LBuf[0], LGotBody[Length(LGotBody) - Int32(LN) + 1], LN);
      end;
    until LN = 0;
    LReply := 'ok';
    AW.GetHeaders.Set_('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LReply[1], 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'chunked request: status 200');
    CheckEqual('hello world', LGotBody, 'chunked request body decoded for handler');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedRequestMaxBodySize;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LOpts: THttpServerOptions;
  LChunk1: string;
  LChunk2: string;
  LReq: string;
  LChunkHex1: string;
  LChunkHex2: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LReply: string;
  begin
    LReply := 'ok';
    AW.GetHeaders.Set_('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LReply[1], 2);
  end);
  LOpts := THttpServerOptions.Default;
  LOpts.MaxBodySize := 1024;
  LHandle := StartServerWithOptions(LRouter as IHttpHandler, LOpts, LServer, LPort);
  try
    SetLength(LChunk1, 700);
    FillChar(LChunk1[1], 700, Ord('B'));
    SetLength(LChunk2, 700);
    FillChar(LChunk2[1], 700, Ord('C'));
    LChunkHex1 := IntToHex(Length(LChunk1), 1);
    LChunkHex2 := IntToHex(Length(LChunk2), 1);
    LReq := 'POST / HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Transfer-Encoding: chunked'#13#10 +
      'Connection: close'#13#10#13#10 +
      LChunkHex1 + #13#10 +
      LChunk1 + #13#10 +
      LChunkHex2 + #13#10 +
      LChunk2 + #13#10 +
      '0'#13#10#13#10;
    LResp := SendRawRequest(LPort, LReq);
    Check((Pos('413', LResp) > 0) or (Length(LResp) = 0),
      'chunked max body size across chunks: 413 or connection closed');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestInvalidChunkSize;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Connection: close'#13#10#13#10 +
        'Z'#13#10'hello'#13#10 +
        '0'#13#10#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'invalid chunk size: status 400');
    Check(not LHandlerCalled, 'invalid chunk size: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestMalformedChunkExtension;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5;'#13#10'hello'#13#10 +
        '0'#13#10#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'malformed chunk extension: status 400');
    Check(not LHandlerCalled, 'malformed chunk extension: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedChunkExtensionAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5;sig=abc';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated chunk extension: status 400');
    Check(not LHandlerCalled, 'truncated chunk extension: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedChunkExtensionCrAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5;sig=abc'#13;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated chunk extension CR: status 400');
    Check(not LHandlerCalled, 'truncated chunk extension CR: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hel';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated chunked request: status 400');
    Check(not LHandlerCalled, 'truncated chunked request: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedChunkSizeLineAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated chunk-size line: status 400');
    Check(not LHandlerCalled, 'truncated chunk-size line: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedTerminalChunkEndingAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated terminal chunk ending: status 400');
    Check(not LHandlerCalled, 'truncated terminal chunk ending: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedTerminalChunkEndingCrAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10#13;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated terminal chunk ending CR: status 400');
    Check(not LHandlerCalled, 'truncated terminal chunk ending CR: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedTerminalChunkExtensionAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0;sig=abc';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated terminal chunk extension: status 400');
    Check(not LHandlerCalled, 'truncated terminal chunk extension: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedTerminalChunkExtensionCrAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0;sig=abc'#13;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated terminal chunk extension CR: status 400');
    Check(not LHandlerCalled, 'truncated terminal chunk extension CR: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedTerminalChunkEndingAfterExtensionAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0;sig=abc'#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated terminal chunk ending after extension: status 400');
    Check(not LHandlerCalled, 'truncated terminal chunk ending after extension: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedTerminalChunkEndingAfterExtensionCrAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0;sig=abc'#13#10#13;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated terminal chunk ending after extension CR: status 400');
    Check(not LHandlerCalled, 'truncated terminal chunk ending after extension CR: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedChunkDataEndingAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated chunk-data ending: status 400');
    Check(not LHandlerCalled, 'truncated chunk-data ending: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedChunkDataCrAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated chunk-data CR: status 400');
    Check(not LHandlerCalled, 'truncated chunk-data CR: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestMissingChunkDataCrLf;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello0'#13#10#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'missing chunk-data CRLF: status 400');
    Check(not LHandlerCalled, 'missing chunk-data CRLF: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedRequestContentLengthConflict;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Content-Length: 5'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Connection: close'#13#10#13#10 +
        '0'#13#10#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'content-length then chunked: status 400');
    Check(not LHandlerCalled, 'content-length then chunked: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedRequestContentLengthConflictReverseOrder;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Content-Length: 5'#13#10 +
        'Connection: close'#13#10#13#10 +
        '0'#13#10#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'chunked then content-length: status 400');
    Check(not LHandlerCalled, 'chunked then content-length: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedRequestTrailerDoesNotPolluteHeaders;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LGotBody: string;
  LGotTrailerDecl: string;
  LGotTrailerValue: string;
  LGotTrailerValues: TStringArray;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Auth-Context'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Auth-Context: admin'#13#10#13#10;
begin
  LGotBody := '';
  LGotTrailerDecl := '';
  LGotTrailerValue := '';
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LReply: string;
    LBuf: array[0..255] of Byte;
    LN: SizeUInt;
  begin
    LGotTrailerDecl := AReq.Headers.Get('Trailer');
    LGotTrailerValue := AReq.Headers.Get('X-Auth-Context');
    LGotTrailerValues := AReq.Headers.GetAll('X-Auth-Context');
    repeat
      LN := AReq.Body.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
      if LN > 0 then
      begin
        SetLength(LGotBody, Length(LGotBody) + Int32(LN));
        Move(LBuf[0], LGotBody[Length(LGotBody) - Int32(LN) + 1], LN);
      end;
    until LN = 0;
    LReply := 'ok';
    AW.GetHeaders.Set_('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LReply[1], 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'chunked trailer request: status 200');
    CheckEqual('hello', LGotBody, 'chunked trailer request body decoded');
    CheckEqual('X-Auth-Context', LGotTrailerDecl, 'trailer declaration preserved');
    CheckEqual('', LGotTrailerValue, 'trailer field not exposed as regular header');
    CheckEqual(Int64(0), Int64(Length(LGotTrailerValues)),
      'trailer field has no regular header entries');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedRequestOversizeTrailerUsesMaxHeaderSize;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp: string;
  LBuf: array[0..8191] of Byte;
  LN: SizeUInt;
  LHandlerCalled: Boolean;
  LOpts: THttpServerOptions;
  LTrailerValue: string;
  LPart1: string;
  LPart2: string;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LBody := 'ok';
    LHandlerCalled := True;
    AW.GetHeaders.Set_('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 2);
  end);
  LOpts := THttpServerOptions.Default;
  LOpts.MaxHeaderSize := 256;
  LHandle := StartServerWithOptions(LRouter as IHttpHandler, LOpts, LServer, LPort);
  try
    SetLength(LTrailerValue, 300);
    FillChar(LTrailerValue[1], 300, Ord('x'));
    LPart1 := 'POST / HTTP/1.1'#13#10 +
              'Host: localhost'#13#10 +
              'Transfer-Encoding: chunked'#13#10 +
              'Trailer: X-Big'#13#10 +
              'Connection: close'#13#10#13#10 +
              '5'#13#10'hello'#13#10;
    LPart2 := '0'#13#10 +
              'X-Big: ' + LTrailerValue + #13#10#13#10;
    LResp := '';
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(LPart1[1], SizeUInt(Length(LPart1)));
      platform_thread_sleep_ns(100000000);
      LConn.Write(LPart2[1], SizeUInt(Length(LPart2)));
      LConn.Shutdown;
      repeat
        try
          LN := LConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
    finally
      LConn.Close;
    end;
    Check((Pos('431', LResp) > 0) or (Length(LResp) = 0),
      'oversize trailer: 431 or connection closed');
    Check(not LHandlerCalled, 'oversize trailer: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestInvalidTrailerField;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Bad'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'Bad Header: value'#13#10#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'invalid trailer field: status 400');
    Check(not LHandlerCalled, 'invalid trailer field: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedTrailerAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test: value'#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated trailer at eof: status 400');
    Check(not LHandlerCalled, 'truncated trailer at eof: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedTrailerFieldNameAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated trailer field-name at eof: status 400');
    Check(not LHandlerCalled, 'truncated trailer field-name at eof: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedTrailerSeparatorAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test:';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated trailer separator at eof: status 400');
    Check(not LHandlerCalled, 'truncated trailer separator at eof: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedTrailerEmptyValueCrAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test:'#13;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated trailer empty-value CR at eof: status 400');
    Check(not LHandlerCalled, 'truncated trailer empty-value CR at eof: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedTrailerEmptyValueAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test:'#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated trailer empty-value at eof: status 400');
    Check(not LHandlerCalled, 'truncated trailer empty-value at eof: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedTrailerEmptyValueSectionCrAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test:'#13#10#13;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated trailer empty-value section CR at eof: status 400');
    Check(not LHandlerCalled, 'truncated trailer empty-value section CR at eof: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedTrailerWhitespaceAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test: ';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated trailer whitespace at eof: status 400');
    Check(not LHandlerCalled, 'truncated trailer whitespace at eof: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedTrailerWhitespaceCrAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test: '#13;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated trailer whitespace CR at eof: status 400');
    Check(not LHandlerCalled, 'truncated trailer whitespace CR at eof: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedTrailerWhitespaceSectionAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test: '#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated trailer whitespace section at eof: status 400');
    Check(not LHandlerCalled, 'truncated trailer whitespace section at eof: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedTrailerWhitespaceSectionCrAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test: '#13#10#13;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated trailer whitespace section CR at eof: status 400');
    Check(not LHandlerCalled, 'truncated trailer whitespace section CR at eof: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedTrailerFieldLineAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test: value';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated trailer field line at eof: status 400');
    Check(not LHandlerCalled, 'truncated trailer field line at eof: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedTrailerFieldCrAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test: value'#13;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated trailer field CR at eof: status 400');
    Check(not LHandlerCalled, 'truncated trailer field CR at eof: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMalformedChunkedRequestTruncatedTrailerCrAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test: value'#13#10#13;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated trailer CR at eof: status 400');
    Check(not LHandlerCalled, 'truncated trailer CR at eof: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 18: Chunked response — handler writes without Content-Length }
procedure TestChunkedResponse;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/chunked', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LP1, LP2, LP3: string;
  begin
    LP1 := 'Hello';
    LP2 := ', ';
    LP3 := 'World!';
    { No content-length set — should trigger chunked encoding }
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LP1[1], SizeUInt(Length(LP1)));
    AW.Write(LP2[1], SizeUInt(Length(LP2)));
    AW.Write(LP3[1], SizeUInt(Length(LP3)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort,
      'GET /chunked HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('transfer-encoding: chunked', LResp) > 0, 'chunked: has TE header');
    Check(Pos('Hello', LResp) > 0, 'chunked: body contains Hello');
    Check(Pos('World!', LResp) > 0, 'chunked: body contains World!');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 19: Chunked response preserves keep-alive }
procedure TestChunkedKeepAlive;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1, LResp2: string;
  LBuf: array[0..8191] of Byte;
  LN: SizeUInt;
const
  REQ1 = 'GET /chunked HTTP/1.1'#13#10'Host: localhost'#13#10#13#10;
  REQ2 = 'GET /fixed HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/chunked', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := 'chunk1';
    { No content-length — triggers chunked }
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LRouter.Get('/fixed', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := 'fixed';
    AW.GetHeaders.Set_('content-length', '5');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 5);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));

      { First request — chunked response }
      LConn.Write(REQ1[1], SizeUInt(Length(REQ1)));
      { Read until we see the terminal chunk marker 0\r\n\r\n }
      LResp1 := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 8192);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp1, Length(LResp1) + Int32(LN));
          Move(LBuf[0], LResp1[Length(LResp1) - Int32(LN) + 1], LN);
        end;
      until (Pos(#13#10'0'#13#10#13#10, LResp1) > 0) or (LN = 0);
      Check(Pos('200 OK', LResp1) > 0, 'chunked-ka: first response 200');
      Check(Pos('chunk1', LResp1) > 0, 'chunked-ka: first body');

      { Second request on same connection — proves keep-alive worked }
      LConn.Write(REQ2[1], SizeUInt(Length(REQ2)));
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp2) > 0, 'chunked-ka: second response 200');
      Check(Pos('fixed', LResp2) > 0, 'chunked-ka: second body');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 20: Hijack transfers connection ownership away from server loop }
procedure TestHijackLeavesConnectionOpenForHandlerOwner;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LServerSideConn: ITcpStream;
  LHijacker: IHttpHijacker;
  LResp: string;
  LBuf: array[0..255] of Byte;
  LN: SizeUInt;
  LProbe: string;
const
  REQ = 'GET /hijack HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Connection: keep-alive'#13#10#13#10;
  RAW_RESP = 'HTTP/1.1 200 OK'#13#10 +
             'content-length: 7'#13#10 +
             'connection: keep-alive'#13#10#13#10 +
             'hijack!';
begin
  LServerSideConn := nil;
  LRouter := THttpRouter.Create;
  LRouter.Get('/hijack', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    if not Supports(AW, IHttpHijacker, LHijacker) then
      Fail('response writer does not support IHttpHijacker');
    LServerSideConn := LHijacker.Hijack;
    LServerSideConn.Write(RAW_RESP[1], SizeUInt(Length(RAW_RESP)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ[1], SizeUInt(Length(REQ)));
      LResp := ReadOneResponse(LConn);
      Check(Pos('hijack!', LResp) > 0, 'hijack owner wrote raw response');

      platform_thread_sleep_ns(100000000); { let the server loop return }
      Check(LServerSideConn <> nil, 'handler captured hijacked connection');
      LProbe := '!';
      LServerSideConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(1)));
      LConn.Write(LProbe[1], SizeUInt(Length(LProbe)));
      LN := LServerSideConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
      CheckEqual(Int64(Length(LProbe)), Int64(LN),
        'handler-owned stream can read after handler returns');
      Check(Chr(LBuf[0]) = LProbe, 'handler-owned stream received probe byte');
    finally
      LConn.Close;
      LServerSideConn := nil;
    end;
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
  T.Run('Pipelined requests in single write', @TestPipelinedRequestsInSingleWrite);
  T.Run('Connection: close stops keep-alive', @TestConnectionClose);
  T.Run('HTTP/1.0 no keep-alive', @TestHttp10NoKeepAlive);
  T.Run('POST body readable via IReader', @TestPostBodyReadable);
  T.Run('Large body 131072 bytes', @TestLargeBody);
  T.Run('Generic malformed request -> 400', @TestMalformedRequest);
  T.Run('Duplicate Content-Length -> 400', @TestDuplicateContentLength);
  T.Run('Header with null byte -> 400', @TestHeaderNullByte);
  T.Run('Request line truncated at EOF -> 400', @TestRequestLineTruncatedAtEof);
  T.Run('Headers truncated at EOF -> 400', @TestHeadersTruncatedAtEof);
  T.Run('HTTP/1.1 missing Host -> 400', @TestMissingHostHeader);
  T.Run('HTTP/1.0 missing Host still allowed', @TestHttp10WithoutHostStillAllowed);
  T.Run('HTTP/0.9 no version -> 400', @TestHttp09NoVersionRejected);
  T.Run('Request-line splitting -> 400', @TestRequestLineSplittingRejected);
  T.Run('Negative Content-Length -> 400', @TestNegativeContentLengthRejected);
  T.Run('Very long method -> 400', @TestVeryLongMethodRejected);
  T.Run('Content-Length extra bytes after close -> 400', @TestContentLengthRequestExtraBytesAfterCloseRejected);
  T.Run('Content-Length keep-alive garbage tail -> follow-up 400', @TestContentLengthKeepAliveGarbageTailBecomesFollowUp400);
  T.Run('Content-Length keep-alive truncated follow-up request line -> follow-up 400',
    @TestContentLengthKeepAliveTruncatedFollowUpRequestLineBecomesFollowUp400);
  T.Run('Content-Length keep-alive truncated follow-up headers -> follow-up 400',
    @TestContentLengthKeepAliveTruncatedFollowUpHeadersBecomesFollowUp400);
  T.Run('Chunked extra bytes after close -> 400', @TestChunkedRequestExtraBytesAfterCloseRejected);
  T.Run('Chunked keep-alive garbage tail -> follow-up 400', @TestChunkedKeepAliveGarbageTailBecomesFollowUp400);
  T.Run('Chunked keep-alive truncated follow-up request line -> follow-up 400',
    @TestChunkedKeepAliveTruncatedFollowUpRequestLineBecomesFollowUp400);
  T.Run('Chunked keep-alive truncated follow-up headers -> follow-up 400',
    @TestChunkedKeepAliveTruncatedFollowUpHeadersBecomesFollowUp400);
  T.Run('Chunked trailer keep-alive garbage tail -> follow-up 400',
    @TestChunkedTrailerKeepAliveGarbageTailBecomesFollowUp400);
  T.Run('Chunked trailer keep-alive truncated follow-up request line -> follow-up 400',
    @TestChunkedTrailerKeepAliveTruncatedFollowUpRequestLineBecomesFollowUp400);
  T.Run('Chunked trailer keep-alive truncated follow-up headers -> follow-up 400',
    @TestChunkedTrailerKeepAliveTruncatedFollowUpHeadersBecomesFollowUp400);
  T.Run('Chunked trailer pipelined requests in single write',
    @TestChunkedTrailerPipelinedRequestsInSingleWrite);
  T.Run('Chunked trailer partial follow-up request line can complete later',
    @TestChunkedTrailerPartialFollowUpRequestLineCanCompleteLater);
  T.Run('Chunked pipelined requests in single write', @TestChunkedPipelinedRequestsInSingleWrite);
  T.Run('Query parameters', @TestQueryParam);
  T.Run('RemoteAddr is 127.0.0.1', @TestRemoteAddr);
  T.Run('Concurrent stress 10x100', @TestConcurrentStress);
  T.Run('MaxHeaderSize enforcement -> 431', @TestMaxHeaderSize);
  T.Run('MaxBodySize enforcement -> 413', @TestMaxBodySize);
  T.Run('Content-Length request truncated at EOF -> 400', @TestContentLengthRequestTruncatedAtEof);
  T.Run('Chunked request body readable', @TestChunkedRequestBodyReadable);
  T.Run('Chunked request MaxBodySize -> 413', @TestChunkedRequestMaxBodySize);
  T.Run('Malformed chunked request invalid size -> 400', @TestMalformedChunkedRequestInvalidChunkSize);
  T.Run('Malformed chunked request malformed chunk extension -> 400', @TestMalformedChunkedRequestMalformedChunkExtension);
  T.Run('Malformed chunked request truncated chunk extension at EOF -> 400', @TestMalformedChunkedRequestTruncatedChunkExtensionAtEof);
  T.Run('Malformed chunked request truncated chunk extension CR at EOF -> 400', @TestMalformedChunkedRequestTruncatedChunkExtensionCrAtEof);
  T.Run('Malformed chunked request truncated at EOF -> 400', @TestMalformedChunkedRequestTruncatedAtEof);
  T.Run('Malformed chunked request truncated chunk-size line at EOF -> 400', @TestMalformedChunkedRequestTruncatedChunkSizeLineAtEof);
  T.Run('Malformed chunked request truncated terminal chunk ending at EOF -> 400', @TestMalformedChunkedRequestTruncatedTerminalChunkEndingAtEof);
  T.Run('Malformed chunked request truncated terminal chunk ending CR at EOF -> 400',
    @TestMalformedChunkedRequestTruncatedTerminalChunkEndingCrAtEof);
  T.Run('Malformed chunked request truncated terminal chunk extension at EOF -> 400', @TestMalformedChunkedRequestTruncatedTerminalChunkExtensionAtEof);
  T.Run('Malformed chunked request truncated terminal chunk extension CR at EOF -> 400', @TestMalformedChunkedRequestTruncatedTerminalChunkExtensionCrAtEof);
  T.Run('Malformed chunked request truncated terminal chunk ending after extension at EOF -> 400',
    @TestMalformedChunkedRequestTruncatedTerminalChunkEndingAfterExtensionAtEof);
  T.Run('Malformed chunked request truncated terminal chunk ending after extension CR at EOF -> 400',
    @TestMalformedChunkedRequestTruncatedTerminalChunkEndingAfterExtensionCrAtEof);
  T.Run('Malformed chunked request truncated chunk-data ending at EOF -> 400', @TestMalformedChunkedRequestTruncatedChunkDataEndingAtEof);
  T.Run('Malformed chunked request truncated chunk-data CR at EOF -> 400', @TestMalformedChunkedRequestTruncatedChunkDataCrAtEof);
  T.Run('Malformed chunked request missing chunk-data CRLF -> 400', @TestMalformedChunkedRequestMissingChunkDataCrLf);
  T.Run('Chunked request content-length conflict -> 400', @TestChunkedRequestContentLengthConflict);
  T.Run('Chunked request content-length conflict reverse order -> 400', @TestChunkedRequestContentLengthConflictReverseOrder);
  T.Run('Chunked request trailer does not pollute headers', @TestChunkedRequestTrailerDoesNotPolluteHeaders);
  T.Run('Chunked request oversize trailer uses MaxHeaderSize', @TestChunkedRequestOversizeTrailerUsesMaxHeaderSize);
  T.Run('Malformed chunked request invalid trailer field -> 400', @TestMalformedChunkedRequestInvalidTrailerField);
  T.Run('Malformed chunked request truncated trailer at EOF -> 400', @TestMalformedChunkedRequestTruncatedTrailerAtEof);
  T.Run('Malformed chunked request truncated trailer field-name at EOF -> 400',
    @TestMalformedChunkedRequestTruncatedTrailerFieldNameAtEof);
  T.Run('Malformed chunked request truncated trailer separator at EOF -> 400',
    @TestMalformedChunkedRequestTruncatedTrailerSeparatorAtEof);
  T.Run('Malformed chunked request truncated trailer empty-value CR at EOF -> 400',
    @TestMalformedChunkedRequestTruncatedTrailerEmptyValueCrAtEof);
  T.Run('Malformed chunked request truncated trailer empty-value at EOF -> 400',
    @TestMalformedChunkedRequestTruncatedTrailerEmptyValueAtEof);
  T.Run('Malformed chunked request truncated trailer empty-value section CR at EOF -> 400',
    @TestMalformedChunkedRequestTruncatedTrailerEmptyValueSectionCrAtEof);
  T.Run('Malformed chunked request truncated trailer whitespace at EOF -> 400',
    @TestMalformedChunkedRequestTruncatedTrailerWhitespaceAtEof);
  T.Run('Malformed chunked request truncated trailer whitespace CR at EOF -> 400',
    @TestMalformedChunkedRequestTruncatedTrailerWhitespaceCrAtEof);
  T.Run('Malformed chunked request truncated trailer whitespace section at EOF -> 400',
    @TestMalformedChunkedRequestTruncatedTrailerWhitespaceSectionAtEof);
  T.Run('Malformed chunked request truncated trailer whitespace section CR at EOF -> 400',
    @TestMalformedChunkedRequestTruncatedTrailerWhitespaceSectionCrAtEof);
  T.Run('Malformed chunked request truncated trailer field line at EOF -> 400',
    @TestMalformedChunkedRequestTruncatedTrailerFieldLineAtEof);
  T.Run('Malformed chunked request truncated trailer field CR at EOF -> 400',
    @TestMalformedChunkedRequestTruncatedTrailerFieldCrAtEof);
  T.Run('Malformed chunked request truncated trailer CR at EOF -> 400',
    @TestMalformedChunkedRequestTruncatedTrailerCrAtEof);
  T.Run('Chunked response (no Content-Length)', @TestChunkedResponse);
  T.Run('Chunked response preserves keep-alive', @TestChunkedKeepAlive);
  T.Run('Hijack keeps connection open for handler owner', @TestHijackLeavesConnectionOpenForHandlerOwner);
  T.Summary;
end.
