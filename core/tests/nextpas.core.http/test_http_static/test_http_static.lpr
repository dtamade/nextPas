program test_http_static;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.test,
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
  LBinary := TBytes.Create($00, $01, $FE, $FF, Ord('A'), Ord('Z'));
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
    Check((Pos('HTTP/1.1 400', LResp) > 0) or (Pos('HTTP/1.1 404', LResp) > 0),
      'traversal blocked with 400 or 404');
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
      'Windows-style traversal separator must be rejected before file lookup');
    Check(Pos('HTTP/1.1 404', LResp) = 0,
      'Windows-style traversal separator must not fall through to missing file');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

procedure TestServeDirUrlEncodedTraversalRejected;
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
    LResp := SendRawRequest(LPort, 'GET /files/%2e%2e/etc/passwd HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'URL-encoded traversal should be rejected before file lookup');
    Check(Pos('HTTP/1.1 404', LResp) = 0,
      'URL-encoded traversal must not fall through to missing file');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Test 7b: ServeDir double-encoded path traversal blocked ===== }
procedure TestServeDirDoubleEncodedTraversalRejected;
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
    { Double-encoded: %252e%252e → after first decode becomes %2e%2e → should be rejected }
    LResp := SendRawRequest(LPort, 'GET /files/%252e%252e/etc/passwd HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Double-encoded traversal must be rejected');
    { Also test %252f variant }
    LResp := SendRawRequest(LPort, 'GET /files/..%252f..%252fetc%252fpasswd HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Double-encoded slash traversal must be rejected');
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

procedure TestStaticFileUsesBinaryStreamTransfer;
var
  LSource: string;
begin
  LSource := nextpas.core.fs.ReadFileText('../../../src/nextpas.core.http.static.pas');
  Check(Pos('ReadFileText(AFilePath)', LSource) = 0,
    'static file body path must not depend on text file reads');
  Check(Pos('ReadFile(AFilePath)', LSource) = 0,
    'static file body path must not load entire file into memory');
  Check(Pos('nextpas.core.fs.Open(AFilePath', LSource) > 0,
    'static file body path opens a file stream');
  Check(Pos('nextpas.core.io.Copy(', LSource) > 0,
    'static file body path streams through io.Copy');
end;

procedure TestServeFilePreservesBinaryBodyBytes;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LBodyPos: SizeInt;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/', ServeFile(CTmpDir + '/binary.bin'));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'binary file status 200');
    Check(Pos('content-length: 6', LResp) > 0,
      'binary content length should match raw byte count');
    LBodyPos := Pos(#13#10#13#10, LResp);
    Check(LBodyPos > 0, 'binary response contains header-body separator');
    Inc(LBodyPos, 4);
    Check(Length(LResp) >= LBodyPos + 5, 'binary response includes all body bytes');
    Check(Ord(LResp[LBodyPos]) = $00, 'binary byte 0 preserved');
    Check(Ord(LResp[LBodyPos + 1]) = $01, 'binary byte 1 preserved');
    Check(Ord(LResp[LBodyPos + 2]) = $FE, 'binary byte 2 preserved');
    Check(Ord(LResp[LBodyPos + 3]) = $FF, 'binary byte 3 preserved');
    Check(LResp[LBodyPos + 4] = 'A', 'binary byte A preserved');
    Check(LResp[LBodyPos + 5] = 'Z', 'binary byte Z preserved');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Test: ServeFile sets ETag header ===== }
procedure TestServeFileETag;
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
    Check(Pos('etag: "', LResp) > 0, 'ETag header present');
    Check(Pos('last-modified: ', LResp) > 0, 'Last-Modified header present');
    Check(Pos('cache-control: ', LResp) > 0, 'Cache-Control header present');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Test: ServeFile returns 304 for If-None-Match ===== }
procedure TestServeFileNotModified;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LETagStart, LETagEnd: SizeInt;
  LETag: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/', ServeFile(CTmpDir + '/style.txt'));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    { First request to get ETag }
    LResp := SendRawRequest(LPort, 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    LETagStart := Pos('etag: "', LResp);
    Check(LETagStart > 0, 'ETag present in first response');
    Inc(LETagStart, 6);
    LETagEnd := Pos('"', LResp, LETagStart + 1);
    Check(LETagEnd > LETagStart, 'ETag closing quote found');
    LETag := System.Copy(LResp, LETagStart, LETagEnd - LETagStart + 1);

    { Second request with If-None-Match }
    LResp := SendRawRequest(LPort,
      'GET / HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'If-None-Match: ' + LETag + #13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 304', LResp) > 0, '304 Not Modified for matching ETag');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

procedure TestServeFileIfNoneMatchListAndStar;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LETagStart, LETagEnd: SizeInt;
  LETag: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/', ServeFile(CTmpDir + '/style.txt'));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    LETagStart := Pos('etag: "', LResp);
    Check(LETagStart > 0, 'ETag present');
    Inc(LETagStart, 6);
    LETagEnd := Pos('"', LResp, LETagStart + 1);
    LETag := System.Copy(LResp, LETagStart, LETagEnd - LETagStart + 1);

    LResp := SendRawRequest(LPort,
      'GET / HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'If-None-Match: "other", ' + LETag + #13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 304', LResp) > 0, '304 for ETag in If-None-Match list');

    LResp := SendRawRequest(LPort,
      'GET / HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'If-None-Match: *'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 304', LResp) > 0, '304 for If-None-Match: *');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

procedure TestServeFileIfNoneMatchMismatchReturns200;
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
    LResp := SendRawRequest(LPort,
      'GET / HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'If-None-Match: "no-such-etag"'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'mismatch If-None-Match returns 200');
    Check(Pos('body{', LResp) > 0, 'mismatch returns body');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

procedure TestServeFileIfModifiedSince304;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LLmStart, LLmEnd: SizeInt;
  LLastMod: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/', ServeFile(CTmpDir + '/style.txt'));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    LLmStart := Pos('last-modified: ', LowerCase(LResp));
    Check(LLmStart > 0, 'Last-Modified present');
    Inc(LLmStart, Length('last-modified: '));
    LLmEnd := LLmStart;
    while (LLmEnd <= Length(LResp)) and (LResp[LLmEnd] <> #13) do
      Inc(LLmEnd);
    LLastMod := System.Copy(LResp, LLmStart, LLmEnd - LLmStart);

    LResp := SendRawRequest(LPort,
      'GET / HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'If-Modified-Since: ' + LLastMod + #13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 304', LResp) > 0, '304 for matching If-Modified-Since');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

procedure TestHttpIfNoneMatchMatchesHelper;
begin
  Check(HttpIfNoneMatchMatches('*', '"abc"'), '* matches any');
  Check(HttpIfNoneMatchMatches('"abc"', '"abc"'), 'exact match');
  Check(HttpIfNoneMatchMatches('"x", "abc"', '"abc"'), 'list match');
  Check(not HttpIfNoneMatchMatches('"x"', '"abc"'), 'mismatch');
  Check(not HttpIfNoneMatchMatches('', '"abc"'), 'empty header');
end;

{ ===== Test: ServeFile range request ===== }
procedure TestServeFileRangeRequest;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LBodyPos: SizeInt;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/', ServeFile(CTmpDir + '/style.txt'));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    { Request bytes 0-2 (first 3 bytes: "bod") }
    LResp := SendRawRequest(LPort,
      'GET / HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Range: bytes=0-2'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 206', LResp) > 0, '206 Partial Content');
    Check(Pos('content-range: bytes 0-2/6', LResp) > 0, 'Content-Range header');
    Check(Pos('content-length: 3', LResp) > 0, 'Content-Length for range');
    LBodyPos := Pos(#13#10#13#10, LResp);
    Check(LBodyPos > 0, 'header-body separator');
    Inc(LBodyPos, 4);
    Check(Length(LResp) >= LBodyPos + 2, 'body has 3 bytes');
    Check(LResp[LBodyPos] = 'b', 'byte 0 is b');
    Check(LResp[LBodyPos + 1] = 'o', 'byte 1 is o');
    Check(LResp[LBodyPos + 2] = 'd', 'byte 2 is d');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Test: ServeFile range request suffix ===== }
procedure TestServeFileRangeSuffix;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LBodyPos: SizeInt;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/', ServeFile(CTmpDir + '/style.txt'));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    { Request last 3 bytes: "y{}" }
    LResp := SendRawRequest(LPort,
      'GET / HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Range: bytes=-3'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 206', LResp) > 0, '206 Partial Content');
    Check(Pos('content-range: bytes 3-5/6', LResp) > 0, 'Content-Range suffix');
    LBodyPos := Pos(#13#10#13#10, LResp);
    Check(LBodyPos > 0, 'header-body separator');
    Inc(LBodyPos, 4);
    Check(Length(LResp) >= LBodyPos + 2, 'body has 3 bytes');
    Check(LResp[LBodyPos] = 'y', 'byte 0 is y');
    Check(LResp[LBodyPos + 1] = '{', 'byte 1 is {');
    Check(LResp[LBodyPos + 2] = '}', 'byte 2 is }');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Test: ServeFile range not satisfiable ===== }
procedure TestServeFileRangeNotSatisfiable;
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
    { Request range beyond file size }
    LResp := SendRawRequest(LPort,
      'GET / HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Range: bytes=100-200'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 416', LResp) > 0, '416 Range Not Satisfiable');
    Check(Pos('content-range: bytes */6', LResp) > 0, 'Content-Range with total size');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Test: ServeFileDownload sets Content-Disposition ===== }
procedure TestServeFileDownloadDisposition;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/', ServeFileDownload(CTmpDir + '/style.txt'));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'status 200');
    Check(Pos('content-disposition: attachment; filename="style.txt"', LResp) > 0,
      'Content-Disposition with filename');
    Check(Pos('body{}', LResp) > 0, 'file content in body');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Test: ServeFileDownload custom name ===== }
procedure TestServeFileDownloadCustomName;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/', ServeFileDownload(CTmpDir + '/style.txt', 'custom-name.css'));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'status 200');
    Check(Pos('content-disposition: attachment; filename="custom-name.css"', LResp) > 0,
      'Content-Disposition with custom name');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== Main ===== }
begin
  SetupTmpDir;
  try
    T := TTestSuite.Create('nextpas.core.http.static');
    T.Test('ServeFile existing file', @TestServeFileExisting);
    T.Test('ServeFile sets Content-Type', @TestServeFileContentType);
    T.Test('ServeFile sets Content-Length', @TestServeFileContentLength);
    T.Test('ServeFile missing returns 404', @TestServeFileMissing);
    T.Test('ServeDir existing file', @TestServeDirExisting);
    T.Test('ServeDir nested path', @TestServeDirNested);
    T.Test('ServeDir path traversal blocked', @TestServeDirTraversalBlocked);
    T.Test('ServeDir backslash traversal rejected',
      @TestServeDirBackslashTraversalRejected);
    T.Test('ServeDir URL-encoded traversal rejected',
      @TestServeDirUrlEncodedTraversalRejected);
    T.Test('ServeDir double-encoded traversal rejected',
      @TestServeDirDoubleEncodedTraversalRejected);
    T.Test('ServeDir missing file returns 404', @TestServeDirMissing);
    T.Test('ServeDir absolute path rejected', @TestServeDirAbsolutePathRejected);
    T.Test('ServeDir MIME case-insensitive and fallback', @TestServeDirMimeTypeCaseInsensitiveAndFallback);
    T.Test('Static file uses binary stream transfer',
      @TestStaticFileUsesBinaryStreamTransfer);
    T.Test('ServeFile preserves binary body bytes',
      @TestServeFilePreservesBinaryBodyBytes);
    T.Test('ServeFile sets ETag, Last-Modified, Cache-Control',
      @TestServeFileETag);
    T.Test('ServeFile returns 304 for If-None-Match',
      @TestServeFileNotModified);
    T.Test('ServeFile If-None-Match list and *',
      @TestServeFileIfNoneMatchListAndStar);
    T.Test('ServeFile If-None-Match mismatch returns 200',
      @TestServeFileIfNoneMatchMismatchReturns200);
    T.Test('ServeFile returns 304 for If-Modified-Since',
      @TestServeFileIfModifiedSince304);
    T.Test('HttpIfNoneMatchMatches helper',
      @TestHttpIfNoneMatchMatchesHelper);
    T.Test('ServeFile range request returns 206',
      @TestServeFileRangeRequest);
    T.Test('ServeFile range suffix request',
      @TestServeFileRangeSuffix);
    T.Test('ServeFile range not satisfiable returns 416',
      @TestServeFileRangeNotSatisfiable);
    T.Test('ServeFileDownload sets Content-Disposition',
      @TestServeFileDownloadDisposition);
    T.Test('ServeFileDownload custom filename',
      @TestServeFileDownloadCustomName);
  if not T.Run then Halt(1);
  finally
    CleanupTmpDir;
  end;
end.
