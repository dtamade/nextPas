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
  nextpas.core.http,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.router,
  nextpas.core.http.server,
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

function BinaryFixtureBytes: TBytes;
begin
  SetLength(Result, 8);
  Result[0] := $00;
  Result[1] := $01;
  Result[2] := $7F;
  Result[3] := $80;
  Result[4] := $FF;
  Result[5] := $0D;
  Result[6] := $0A;
  Result[7] := $00;
end;

function ResponseBodyBytes(const AResponse: string): TBytes;
var
  LHeaderEnd: SizeInt;
  LBodyStart: SizeInt;
  LBodyLen: SizeInt;
begin
  LHeaderEnd := Pos(#13#10#13#10, AResponse);
  if LHeaderEnd = 0 then
    Exit(nil);
  LBodyStart := LHeaderEnd + 4;
  LBodyLen := Length(AResponse) - LBodyStart + 1;
  if LBodyLen <= 0 then
    Exit(nil);
  SetLength(Result, LBodyLen);
  Move(AResponse[LBodyStart], Result[0], LBodyLen);
end;

function BytesEqual(const ALeft, ARight: TBytes): Boolean;
var
  LI: SizeInt;
begin
  if Length(ALeft) <> Length(ARight) then
    Exit(False);
  for LI := 0 to Length(ALeft) - 1 do
    if ALeft[LI] <> ARight[LI] then
      Exit(False);
  Result := True;
end;

procedure SetupTmpDir;
var
  LBinary: TBytes;
begin
  { Create test directory structure }
  nextpas.core.fs.MkdirAll(CTmpDir);
  nextpas.core.fs.MkdirAll(CTmpDir + '/css');
  nextpas.core.fs.WriteFileText(CTmpDir + '/index.html', '<h1>Hello</h1>');
  nextpas.core.fs.WriteFileText(CTmpDir + '/style.txt', 'body{}');
  nextpas.core.fs.WriteFileText(CTmpDir + '/css/main.css', '.a{color:red}');
  nextpas.core.fs.WriteFileText(CTmpDir + '/data.JSON', '{"ok":true}');
  nextpas.core.fs.WriteFileText(CTmpDir + '/asset.unknownext', 'opaque');
  LBinary := BinaryFixtureBytes;
  nextpas.core.fs.WriteFile(CTmpDir + '/binary.bin', LBinary);
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
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'traversal must be rejected with 400');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

procedure TestServeDirBackslashTraversalRejected;
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
    LResp := SendRawRequest(LPort, 'GET /files/..\\secret HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Windows-style traversal separator must be rejected with 400');
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
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'absolute path must be rejected with 400');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Test 10: ServeDir MIME matching is case-insensitive with safe fallback ===== }
procedure TestServeDirMimeTypeCaseInsensitiveAndFallback;
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
    LResp := SendRawRequest(LPort, 'GET /static/data.JSON HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'uppercase extension status 200');
    Check(Pos('content-type: application/json', LResp) > 0,
      'uppercase JSON extension maps to application/json');

    LResp := SendRawRequest(LPort, 'GET /static/asset.unknownext HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'unknown extension status 200');
    Check(Pos('content-type: application/octet-stream', LResp) > 0,
      'unknown extension maps to application/octet-stream');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Test 11: Static file uses stream-based transfer ===== }
procedure TestStaticFileUsesStreamTransfer;
var
  LSource: string;
begin
  LSource := nextpas.core.fs.ReadFileText('../../../src/nextpas.core.http.static.pas');
  Check(Pos('ReadFileText(AFilePath)', LSource) = 0,
    'static file body path must not depend on text file reads');
  Check(Pos('ReadFile(AFilePath)', LSource) = 0,
    'static file must not load entire file into memory');
  Check(Pos('nextpas.core.fs.Open(AFilePath', LSource) > 0,
    'static file uses stream-based Open for reading');
  Check(Pos('nextpas.core.io.Copy(', LSource) > 0,
    'static file uses io.Copy for streaming transfer');
end;

{ ===== Test 12: ServeFile preserves binary body bytes ===== }
procedure TestServeFilePreservesBinaryBodyBytes;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LBody: TBytes;
  LExpected: TBytes;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/', ServeFile(CTmpDir + '/binary.bin'));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    LExpected := BinaryFixtureBytes;
    LBody := ResponseBodyBytes(LResp);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'binary ServeFile status 200');
    Check(Pos('content-type: application/octet-stream', LResp) > 0,
      'binary ServeFile content-type fallback');
    Check(Pos('content-length: 8', LResp) > 0, 'binary ServeFile content-length');
    CheckEqual(Int64(Length(LExpected)), Int64(Length(LBody)), 'binary ServeFile body length');
    Check(BytesEqual(LExpected, LBody), 'binary ServeFile body bytes preserved');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Test 13: ServeDir preserves binary body bytes ===== }
procedure TestServeDirPreservesBinaryBodyBytes;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LBody: TBytes;
  LExpected: TBytes;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/static/*filepath', ServeDir(CTmpDir));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET /static/binary.bin HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    LExpected := BinaryFixtureBytes;
    LBody := ResponseBodyBytes(LResp);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'binary ServeDir status 200');
    Check(Pos('content-type: application/octet-stream', LResp) > 0,
      'binary ServeDir content-type fallback');
    Check(Pos('content-length: 8', LResp) > 0, 'binary ServeDir content-length');
    CheckEqual(Int64(Length(LExpected)), Int64(Length(LBody)), 'binary ServeDir body length');
    Check(BytesEqual(LExpected, LBody), 'binary ServeDir body bytes preserved');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Test 14: URL-encoded traversal blocked ===== }
procedure TestServeDirUrlEncodedTraversalBlocked;
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
    { %2e%2e = .. }
    LResp := SendRawRequest(LPort, 'GET /files/%2e%2e/etc/passwd HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'URL-encoded traversal (%2e%2e) must be rejected with 400');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Test 15: PathClean-based normalization ===== }
procedure TestServeDirNormalizationProtects;
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
    { foo/../../etc normalizes to ../etc which should be rejected }
    LResp := SendRawRequest(LPort, 'GET /files/foo/../../etc/passwd HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'double-dot traversal through nested path must be rejected with 400');
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
    T.Run('ServeDir backslash traversal rejected',
      @TestServeDirBackslashTraversalRejected);
    T.Run('ServeDir missing file returns 404', @TestServeDirMissing);
    T.Run('ServeDir absolute path rejected', @TestServeDirAbsolutePathRejected);
    T.Run('ServeDir MIME case-insensitive and fallback', @TestServeDirMimeTypeCaseInsensitiveAndFallback);
    T.Run('Static file uses stream-based transfer', @TestStaticFileUsesStreamTransfer);
    T.Run('ServeFile preserves binary body bytes', @TestServeFilePreservesBinaryBodyBytes);
    T.Run('ServeDir preserves binary body bytes', @TestServeDirPreservesBinaryBodyBytes);
    T.Run('URL-encoded traversal blocked', @TestServeDirUrlEncodedTraversalBlocked);
    T.Run('PathClean normalization protects', @TestServeDirNormalizationProtects);
    T.Summary;
  finally
    CleanupTmpDir;
  end;
end.
