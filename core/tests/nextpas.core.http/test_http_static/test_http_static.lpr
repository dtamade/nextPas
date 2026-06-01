program test_http_static;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.text.conv,
  nextpas.core.fs,
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
  nextpas.core.http.static,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.thread;

const
  CTmpDir = '/tmp/nextpas_test_static';

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

function StartTestServer(const AHandler: IHttpHandler; out AServer: THttpServer; out APort: UInt16): TPlatformThreadHandle;
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

procedure StopTestServer(var AServer: THttpServer; const AHandle: TPlatformThreadHandle);
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

procedure SetupTmpDir;
begin
  { Create test directory structure }
  nextpas.core.fs.MkdirAll(CTmpDir);
  nextpas.core.fs.MkdirAll(CTmpDir + '/css');
  nextpas.core.fs.WriteFileText(CTmpDir + '/index.html', '<h1>Hello</h1>');
  nextpas.core.fs.WriteFileText(CTmpDir + '/style.txt', 'body{}');
  nextpas.core.fs.WriteFileText(CTmpDir + '/css/main.css', '.a{color:red}');
end;

procedure CleanupTmpDir;
begin
  nextpas.core.fs.RemoveAll(CTmpDir);
end;

{ ===== Test 1: ServeFile existing ===== }
procedure TestServeFileExisting;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/', ServeFile(CTmpDir + '/style.txt'));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'status 200');
    Check(Pos('body{}', LResp) > 0, 'file content in body');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Test 2: ServeFile sets Content-Type ===== }
procedure TestServeFileContentType;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/', ServeFile(CTmpDir + '/index.html'));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('content-type: text/html', LResp) > 0, 'content-type text/html');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Test 3: ServeFile sets Content-Length ===== }
procedure TestServeFileContentLength;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/', ServeFile(CTmpDir + '/style.txt'));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('content-length: 6', LResp) > 0, 'content-length matches body{}');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Test 4: ServeFile missing returns 404 ===== }
procedure TestServeFileMissing;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/', ServeFile('/tmp/nonexistent_file_xyz.txt'));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 404', LResp) > 0, 'status 404 for missing file');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Test 5: ServeDir existing file ===== }
procedure TestServeDirExisting;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/static/*filepath', ServeDir(CTmpDir));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET /static/index.html HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'status 200');
    Check(Pos('<h1>Hello</h1>', LResp) > 0, 'file content served');
    Check(Pos('content-type: text/html', LResp) > 0, 'mime type html');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Test 6: ServeDir nested path ===== }
procedure TestServeDirNested;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/assets/*filepath', ServeDir(CTmpDir));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET /assets/css/main.css HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'status 200');
    Check(Pos('.a{color:red}', LResp) > 0, 'nested file content');
    Check(Pos('content-type: text/css', LResp) > 0, 'mime type css');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Test 7: ServeDir path traversal blocked ===== }
procedure TestServeDirTraversalBlocked;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/files/*filepath', ServeDir(CTmpDir));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET /files/../etc/passwd HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check((Pos('HTTP/1.1 400', LResp) > 0) or (Pos('HTTP/1.1 404', LResp) > 0),
      'traversal blocked with 400 or 404');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Test 8: ServeDir missing file returns 404 ===== }
procedure TestServeDirMissing;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/static/*filepath', ServeDir(CTmpDir));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET /static/nope.txt HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 404', LResp) > 0, 'status 404 for missing file');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Test 9: ServeDir absolute path rejected ===== }
procedure TestServeDirAbsolutePathRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/files/*filepath', ServeDir(CTmpDir));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET /files//etc/passwd HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check((Pos('HTTP/1.1 400', LResp) > 0) or (Pos('HTTP/1.1 404', LResp) > 0),
      'absolute path rejected');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Main ===== }
begin
  SetupTmpDir;
  try
    T := TTestRunner.Create('nextpas.core.http.static');
    T.Run('ServeFile existing file', @TestServeFileExisting);
    T.Run('ServeFile sets Content-Type', @TestServeFileContentType);
    T.Run('ServeFile sets Content-Length', @TestServeFileContentLength);
    T.Run('ServeFile missing returns 404', @TestServeFileMissing);
    T.Run('ServeDir existing file', @TestServeDirExisting);
    T.Run('ServeDir nested path', @TestServeDirNested);
    T.Run('ServeDir path traversal blocked', @TestServeDirTraversalBlocked);
    T.Run('ServeDir missing file returns 404', @TestServeDirMissing);
    T.Run('ServeDir absolute path rejected', @TestServeDirAbsolutePathRejected);
    T.Summary;
  finally
    CleanupTmpDir;
  end;
end.
