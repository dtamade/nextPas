program test_http_static;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.fs,
  nextpas.core.io.intf,
  nextpas.core.vfs.base,
  nextpas.core.vfs.intf,
  nextpas.core.vfs,
  nextpas.core.vfs.memtree,
  nextpas.core.vfs.os,
  nextpas.core.respack,
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
  nextpas.core.http.static,
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

{ 提取响应里首个 header 值（AName 须为小写）；找不到返回空串 }
function HeaderValue(const AResp, AName: string): string;
var
  LKeyStart, LValStart, LValEnd: SizeInt;
begin
  Result := '';
  LKeyStart := Pos(AName + ': ', AResp);
  if LKeyStart = 0 then
    Exit;
  LValStart := LKeyStart + Length(AName) + 2;
  LValEnd := LValStart;
  while (LValEnd <= Length(AResp)) and (AResp[LValEnd] <> #13) do
    Inc(LValEnd);
  Result := System.Copy(AResp, LValStart, LValEnd - LValStart);
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
  Check(Pos('CopyRange(', LSource) > 0,
    'range body path streams via CopyRange');
  Check(Pos('accept-ranges', LowerCase(LSource)) > 0,
    'static responses advertise Accept-Ranges');
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
    Check(Pos('accept-ranges: bytes', LResp) > 0, 'Accept-Ranges: bytes on 200');
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

{ HTTP-date 三格式解析（Go http.ParseTime 同集）：
  IMF-fixdate / RFC850 / ANSIC，合法矩阵 + 非法拒绝。 }
procedure TestTryParseHttpDate;
var
  LUnix: Int64;
begin
  { IMF-fixdate（首选形态）。 }
  Check(TryParseHttpDate('Sun, 06 Nov 1994 08:49:37 GMT', LUnix),
    'IMF 解析');
  CheckEqual(784111777, LUnix, 'IMF 值（1994-11-06T08:49:37Z）');
  { RFC850（旧形态，两位年 + 全称星期）。 }
  Check(TryParseHttpDate('Sunday, 06-Nov-94 08:49:37 GMT', LUnix),
    'RFC850 解析');
  CheckEqual(784111777, LUnix, 'RFC850 值（94 → 1994）');
  Check(TryParseHttpDate('Sunday, 06-Nov-69 08:49:37 GMT', LUnix),
    'RFC850 69 阈值下沿');
  CheckEqual(-4806623, LUnix, '69 → 1969（POSIX 规则）');
  { ANSIC（Go 原生形态，日左补空格）。 }
  Check(TryParseHttpDate('Sun Nov  6 08:49:37 1994', LUnix),
    'ANSIC 解析');
  CheckEqual(784111777, LUnix, 'ANSIC 值');
  Check(TryParseHttpDate('Sun Nov 16 08:49:37 1994', LUnix),
    'ANSIC 两位数日');
  CheckEqual(784975777, LUnix, 'ANSIC 两位日值');
  { 非法拒绝。 }
  Check(not TryParseHttpDate('', LUnix), '空串拒绝');
  Check(not TryParseHttpDate('not a date', LUnix), '乱串拒绝');
  Check(not TryParseHttpDate('Sun, 06 Nov 1994', LUnix), '缺时间拒绝');
  Check(not TryParseHttpDate('Mon, 99 Nov 1994 08:49:37 GMT', LUnix),
    '非法日拒绝');
  Check(not TryParseHttpDate('Sun, 06 Foo 1994 08:49:37 GMT', LUnix),
    '非法月拒绝');
  Check(not TryParseHttpDate('Sun, 06 Nov 1994 25:49:37 GMT', LUnix),
    '非法时拒绝');
  Check(not TryParseHttpDate('Sunday, 06-Nov-94 25:49:37 GMT', LUnix),
    'RFC850 非法时拒绝');
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
    Check(Pos('accept-ranges: bytes', LResp) > 0, 'Accept-Ranges on 206');
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

procedure TestServeFileRangeOpenEnded;
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
    LResp := SendRawRequest(LPort,
      'GET / HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Range: bytes=3-'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 206', LResp) > 0, '206 for open-ended range');
    Check(Pos('content-range: bytes 3-5/6', LResp) > 0, 'open-ended Content-Range');
    LBodyPos := Pos(#13#10#13#10, LResp);
    Inc(LBodyPos, 4);
    CheckEqual('y{}', System.Copy(LResp, LBodyPos, 3), 'open-ended body');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

procedure TestServeFileMultiRangeRejected;
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
      'Range: bytes=0-1,3-4'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 416', LResp) > 0, 'multi-range returns 416');
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

{ ===== ServeVfs: shared in-memory tree ===== }
{ ASCII-only string → bytes (SysUtils facade helpers are off-limits here). }
function StrBytes(const S: string): TBytes;
var
  LI: SizeInt;
begin
  SetLength(Result, Length(S));
  for LI := 1 to Length(S) do
    Result[LI - 1] := Byte(Ord(S[LI]));
end;

{ Entries cover both ETag regimes: hash-backed fnv and size+mtime fallback,
  and both mtime regimes: known Unix seconds and unknown zero. }
function BuildMemVfs: IVfs;
var
  LItems: array of TVfsMemEntry;
  LStyle, LCss, LHashed, LNoMtime, LBin: TBytes;
begin
  LStyle := StrBytes('body{}');
  LCss := StrBytes('.a{color:red}');
  LHashed := StrBytes('let x=1;');
  LNoMtime := StrBytes('plain');
  LBin := TBytes.Create($00, $01, $FE, $FF, Ord('A'), Ord('Z'));
  SetLength(LItems, 5);
  LItems[0].Name := 'style.txt';
  LItems[0].Data := LStyle;
  LItems[0].ModTime := 1700000000;
  LItems[0].Hash := 0;
  LItems[1].Name := 'css/main.css';
  LItems[1].Data := LCss;
  LItems[1].ModTime := 0;
  LItems[1].Hash := $DEADBEEF;
  LItems[2].Name := 'hashed.js';
  LItems[2].Data := LHashed;
  LItems[2].ModTime := 0;
  LItems[2].Hash := $DEADBEEF;
  LItems[3].Name := 'nomtime.txt';
  LItems[3].Data := LNoMtime;
  LItems[3].ModTime := 0;
  LItems[3].Hash := 0;
  LItems[4].Name := 'binary.bin';
  LItems[4].Data := LBin;
  LItems[4].ModTime := 1700000000;
  LItems[4].Hash := $12345678;
  Result := CreateMemTreeVfs(LItems);
end;

procedure TestServeVfsExistingFile;
var
  LVfs: IVfs;
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LVfs := BuildMemVfs;
  LRouter := THttpRouter.Create;
  LRouter.Get('/m/*filepath', ServeVfs(LVfs));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET /m/style.txt HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'status 200');
    Check(Pos('body{}', LResp) > 0, 'vfs file content served');
    Check(Pos('content-type: text/plain', LResp) > 0, 'mime type txt');
    Check(Pos('accept-ranges: bytes', LResp) > 0, 'Accept-Ranges advertised');

    LResp := SendRawRequest(LPort, 'GET /m/css/main.css HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'nested status 200');
    Check(Pos('.a{color:red}', LResp) > 0, 'nested content served');
    Check(Pos('content-type: text/css', LResp) > 0, 'nested mime css');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

procedure TestServeVfsMissingFile404;
var
  LVfs: IVfs;
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LVfs := BuildMemVfs;
  LRouter := THttpRouter.Create;
  LRouter.Get('/m/*filepath', ServeVfs(LVfs));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET /m/nope.txt HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 404', LResp) > 0, 'missing vfs entry returns 404');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

procedure TestServeVfsDirectoryReturns404;
var
  LVfs: IVfs;
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LVfs := BuildMemVfs;
  LRouter := THttpRouter.Create;
  LRouter.Get('/m/*filepath', ServeVfs(LVfs));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    { Directories are never served (no index): plain miss. }
    LResp := SendRawRequest(LPort, 'GET /m/css HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 404', LResp) > 0, 'directory entry returns 404');

    LResp := SendRawRequest(LPort, 'GET /m HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 404', LResp) > 0, 'empty relative path returns 404');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

procedure TestServeVfsInvalidPathsReturn404;
var
  LVfs: IVfs;
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LVfs := BuildMemVfs;
  LRouter := THttpRouter.Create;
  LRouter.Get('/m/*filepath', ServeVfs(LVfs));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    { The VFS namespace is canonical: traversal/rooted forms are misses,
      indistinguishable from nonexistent entries (no probing oracle). }
    LResp := SendRawRequest(LPort, 'GET /m/../secret HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 404', LResp) > 0, 'dot-dot segment is a miss');

    LResp := SendRawRequest(LPort, 'GET /m/%2e%2e/secret HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 404', LResp) > 0, 'URL-encoded dot-dot is a miss');

    LResp := SendRawRequest(LPort, 'GET /m/%2fetc%2fpasswd HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 404', LResp) > 0, 'rooted decoded path is a miss');

    LResp := SendRawRequest(LPort, 'GET /m/a//b HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) = 0,
      'empty segment never resolves to content');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

procedure TestServeVfsETagForms;
var
  LVfs: IVfs;
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LVfs := BuildMemVfs;
  LRouter := THttpRouter.Create;
  LRouter.Get('/m/*filepath', ServeVfs(LVfs));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    { Hash-backed entry: ETag is "fnv-<8 uppercase hex>". }
    LResp := SendRawRequest(LPort, 'GET /m/hashed.js HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('etag: "fnv-DEADBEEF"', LResp) > 0,
      'hash-backed ETag is fnv-<8 hex> of ContentHash');

    { No-hash entry with known mtime: strong size+mtime ETag, no fnv form. }
    LResp := SendRawRequest(LPort, 'GET /m/style.txt HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('etag: "', LResp) > 0, 'fallback ETag present');
    Check(Pos('etag: "fnv-', LResp) = 0, 'fallback ETag is not fnv form');
    Check(Pos('last-modified: ', LResp) > 0,
      'known mtime yields Last-Modified');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

procedure TestServeVfsNotModifiedViaETag;
var
  LVfs: IVfs;
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LETagStart, LETagEnd: SizeInt;
  LETag: string;
begin
  LVfs := BuildMemVfs;
  LRouter := THttpRouter.Create;
  LRouter.Get('/m/*filepath', ServeVfs(LVfs));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET /m/hashed.js HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    LETagStart := Pos('etag: "', LResp);
    Check(LETagStart > 0, 'ETag present in first response');
    Inc(LETagStart, 6);
    LETagEnd := Pos('"', LResp, LETagStart + 1);
    LETag := System.Copy(LResp, LETagStart, LETagEnd - LETagStart + 1);

    LResp := SendRawRequest(LPort,
      'GET /m/hashed.js HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'If-None-Match: ' + LETag + #13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 304', LResp) > 0, '304 for matching hash ETag');

    LResp := SendRawRequest(LPort,
      'GET /m/hashed.js HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'If-None-Match: "nope"'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, '200 for mismatching ETag');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

procedure TestServeVfsUnknownModTimeConditional;
var
  LVfs: IVfs;
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LVfs := BuildMemVfs;
  LRouter := THttpRouter.Create;
  LRouter.Get('/m/*filepath', ServeVfs(LVfs));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    { ModTime=0 entry: no Last-Modified header at all. }
    LResp := SendRawRequest(LPort, 'GET /m/nomtime.txt HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'unknown-mtime entry serves 200');
    Check(Pos('last-modified:', LowerCase(LResp)) = 0,
      'unknown mtime suppresses Last-Modified');

    { If-Modified-Since must not produce a bogus 304 for t=0 resources. }
    LResp := SendRawRequest(LPort,
      'GET /m/nomtime.txt HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'If-Modified-Since: Thu, 01 Jan 2099 00:00:00 GMT'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0,
      'If-Modified-Since ignored when mtime unknown');
    Check(Pos('plain', LResp) > 0, 'body still served alongside IMS');

    { If-None-Match keeps working even without mtime. }
    LResp := SendRawRequest(LPort,
      'GET /m/nomtime.txt HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'If-None-Match: "nope"'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'INM mismatch still 200 without mtime');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

procedure TestServeVfsKnownModTimeConditional304;
var
  LVfs: IVfs;
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LLmStart, LLmEnd: SizeInt;
  LLastMod: string;
begin
  LVfs := BuildMemVfs;
  LRouter := THttpRouter.Create;
  LRouter.Get('/m/*filepath', ServeVfs(LVfs));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET /m/style.txt HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    LLmStart := Pos('last-modified: ', LowerCase(LResp));
    Check(LLmStart > 0, 'Last-Modified present for known mtime');
    Inc(LLmStart, Length('last-modified: '));
    LLmEnd := LLmStart;
    while (LLmEnd <= Length(LResp)) and (LResp[LLmEnd] <> #13) do
      Inc(LLmEnd);
    LLastMod := System.Copy(LResp, LLmStart, LLmEnd - LLmStart);

    LResp := SendRawRequest(LPort,
      'GET /m/style.txt HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'If-Modified-Since: ' + LLastMod + #13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 304', LResp) > 0, '304 for matching If-Modified-Since');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

procedure TestServeVfsRangeRequests;
var
  LVfs: IVfs;
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LBodyPos: SizeInt;
begin
  LVfs := BuildMemVfs;
  LRouter := THttpRouter.Create;
  LRouter.Get('/m/*filepath', ServeVfs(LVfs));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    { Fixed range over the 6-byte style.txt with body braces. }
    LResp := SendRawRequest(LPort,
      'GET /m/style.txt HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Range: bytes=0-2'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 206', LResp) > 0, '206 Partial Content');
    Check(Pos('content-range: bytes 0-2/6', LResp) > 0, 'Content-Range header');
    LBodyPos := Pos(#13#10#13#10, LResp);
    Inc(LBodyPos, 4);
    Check(System.Copy(LResp, LBodyPos, 3) = 'bod', 'range body prefix');

    { Suffix range. }
    LResp := SendRawRequest(LPort,
      'GET /m/style.txt HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Range: bytes=-3'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 206', LResp) > 0, '206 for suffix range');
    Check(Pos('content-range: bytes 3-5/6', LResp) > 0, 'suffix Content-Range');

    { Unsatisfiable range. }
    LResp := SendRawRequest(LPort,
      'GET /m/style.txt HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Range: bytes=100-200'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 416', LResp) > 0, '416 for out-of-range request');
    Check(Pos('content-range: bytes */6', LResp) > 0, '416 carries total size');

    { Multi-range stays unsupported → 416, same as fs backend. }
    LResp := SendRawRequest(LPort,
      'GET /m/style.txt HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Range: bytes=0-1,3-4'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 416', LResp) > 0, 'multi-range returns 416');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

procedure TestServeVfsBinaryBodyPreserved;
var
  LVfs: IVfs;
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LBodyPos: SizeInt;
begin
  LVfs := BuildMemVfs;
  LRouter := THttpRouter.Create;
  LRouter.Get('/m/*filepath', ServeVfs(LVfs));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET /m/binary.bin HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'binary status 200');
    Check(Pos('content-type: application/octet-stream', LResp) > 0,
      'bin maps to octet-stream');
    LBodyPos := Pos(#13#10#13#10, LResp);
    Inc(LBodyPos, 4);
    Check(Ord(LResp[LBodyPos]) = $00, 'byte $00 preserved');
    Check(Ord(LResp[LBodyPos + 1]) = $01, 'byte $01 preserved');
    Check(Ord(LResp[LBodyPos + 2]) = $FE, 'byte $FE preserved');
    Check(Ord(LResp[LBodyPos + 3]) = $FF, 'byte $FF preserved');
    Check(LResp[LBodyPos + 4] = 'A', 'byte A preserved');
    Check(LResp[LBodyPos + 5] = 'Z', 'byte Z preserved');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

procedure TestServeVfsOsBackendConsistency;
var
  LVfs: IVfs;
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  { Same handler contract over the os backend rooted at the shared tmpdir:
    real files have mtime+size but no ContentHash → size+mtime ETag regime. }
  LVfs := CreateOsVfs(CTmpDir);
  LRouter := THttpRouter.Create;
  LRouter.Get('/o/*filepath', ServeVfs(LVfs));
  LHandle := StartTestServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET /o/style.txt HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'os backend status 200');
    Check(Pos('body{}', LResp) > 0, 'os backend content matches fs copy');
    Check(Pos('etag: "', LResp) > 0, 'os backend has ETag');
    Check(Pos('etag: "fnv-', LResp) = 0, 'os backend uses size+mtime ETag');
    Check(Pos('last-modified: ', LResp) > 0, 'os backend has Last-Modified');

    LResp := SendRawRequest(LPort, 'GET /o/css/main.css HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'os backend nested status 200');
    Check(Pos('.a{color:red}', LResp) > 0, 'os backend nested content');

    LResp := SendRawRequest(LPort, 'GET /o/nope.txt HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 404', LResp) > 0, 'os backend missing returns 404');

    LResp := SendRawRequest(LPort, 'GET /o/css HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 404', LResp) > 0, 'os backend directory returns 404');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

{ ===== ServeVfs: embedded backend consistency ===== }
{ rp_pack 恒写条目 hash 且取真实 mtime，CLI 路径产不出 mtime=0 / 无 hash
  条目；此组直构 respack blob 覆盖这两条仅 embedded 可达的组合路径，
  并验证窗口流定位读与 hash 标志位读取。 }

function EmbedEntry(const APath: string; const AData: TBytes;
  const AModTime: Int64): TResPackInputEntry;
begin
  Result.Path := APath;
  Result.Data := @AData[0];
  Result.DataSize := SizeUInt(Length(AData));
  Result.ModTime := AModTime;
end;

function BuildEmbedVfs(AHashes: Boolean): IVfs;
var
  LIndex, LNoMtime, LBin, LCss: TBytes;
  LEntries: TResPackInputArray;
  LOpts: TResPackBuildOptions;
  LBlob: TResPackBlob;
begin
  LIndex := StrBytes('<html>embed</html>');
  LNoMtime := StrBytes('no-mtime');
  LBin := TBytes.Create($00, $FE, $FF, Ord('Z'));
  LCss := StrBytes('p{}');
  if AHashes then
  begin
    SetLength(LEntries, 3);
    LEntries[0] := EmbedEntry('index.html', LIndex, 1700000000);
    LEntries[1] := EmbedEntry('nomtime.txt', LNoMtime, 0);
    LEntries[2] := EmbedEntry('bin.bin', LBin, 1700000000);
  end
  else
  begin
    SetLength(LEntries, 1);
    LEntries[0] := EmbedEntry('style.css', LCss, 1700000000);
  end;
  LOpts := ResPackDefaultOptions;
  LOpts.Hashes := AHashes;
  LBlob := ResPackBuild(LEntries, LOpts);
  { AOwnsBlob=True：接口持所有权，门结束随引用释放（heaptrc 可证） }
  Result := CreateEmbeddedVfs(LBlob.Data, LBlob.Size, True);
end;

{ ETag 形态须为 "fnv-<8 个大写十六进制>" }
procedure CheckFnvETagForm(const AETag, AMsg: string);
var
  LI: Integer;
begin
  Check(Length(AETag) = 14, AMsg + ': length 14');
  Check(System.Copy(AETag, 1, 5) = '"fnv-', AMsg + ': fnv prefix');
  Check(AETag[14] = '"', AMsg + ': closing quote');
  for LI := 6 to 13 do
    Check(AETag[LI] in ['0'..'9', 'A'..'F'], AMsg + ': hex digit');
end;

procedure StartEmbedServer(const AVfs: IVfs; const ARoute: string;
  out AServer: THttpServer; out APort: UInt16;
  out AHandle: TPlatformThreadHandle);
var
  LRouter: THttpRouter;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get(ARoute, ServeVfs(AVfs));
  AHandle := StartTestServer(LRouter as IHttpHandler, AServer, APort);
end;

procedure TestServeVfsEmbeddedHashedETagAndConditional;
var
  LVfs: IVfs;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp, LETag: string;
begin
  LVfs := BuildEmbedVfs(True);
  StartEmbedServer(LVfs, '/e1/*filepath', LServer, LPort, LHandle);
  try
    LResp := SendRawRequest(LPort, 'GET /e1/index.html HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'embedded status 200');
    Check(Pos('<html>embed</html>', LResp) > 0, 'embedded content served');
    LETag := HeaderValue(LResp, 'etag');
    CheckFnvETagForm(LETag, 'embedded hashed entry etag');
    Check(Pos('last-modified: ', LowerCase(LResp)) > 0,
      'embedded known mtime yields Last-Modified');

    LResp := SendRawRequest(LPort,
      'GET /e1/index.html HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'If-None-Match: ' + LETag + #13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 304', LResp) > 0, 'embedded INM match yields 304');

    LResp := SendRawRequest(LPort,
      'GET /e1/index.html HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'If-None-Match: "other"'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'embedded INM mismatch yields 200');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

procedure TestServeVfsEmbeddedUnknownModTime;
var
  LVfs: IVfs;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LVfs := BuildEmbedVfs(True);
  StartEmbedServer(LVfs, '/e1/*filepath', LServer, LPort, LHandle);
  try
    LResp := SendRawRequest(LPort, 'GET /e1/nomtime.txt HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'embedded mtime=0 status 200');
    Check(Pos('last-modified:', LowerCase(LResp)) = 0,
      'embedded mtime=0 suppresses Last-Modified');

    LResp := SendRawRequest(LPort,
      'GET /e1/nomtime.txt HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'If-Modified-Since: Thu, 01 Jan 2099 00:00:00 GMT'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0,
      'embedded IMS ignored when mtime unknown');
    Check(Pos('no-mtime', LResp) > 0, 'embedded body served alongside IMS');

    LResp := SendRawRequest(LPort,
      'GET /e1/nomtime.txt HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'If-None-Match: "zz"'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0,
      'embedded INM mismatch still 200 without mtime');
  finally
    StopTestServer(LServer, LHandle);
  end;
end;

procedure TestServeVfsEmbeddedRangeAndUnhashedFallback;
var
  LVfs: IVfs;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp, LETag: string;
  LBodyPos: SizeInt;
begin
  LVfs := BuildEmbedVfs(True);
  StartEmbedServer(LVfs, '/e1/*filepath', LServer, LPort, LHandle);
  try
    LResp := SendRawRequest(LPort,
      'GET /e1/bin.bin HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Range: bytes=1-2'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 206', LResp) > 0, 'embedded range status 206');
    Check(Pos('content-range: bytes 1-2/4', LResp) > 0,
      'embedded window-stream Content-Range');
    LBodyPos := Pos(#13#10#13#10, LResp);
    Inc(LBodyPos, 4);
    Check((Ord(LResp[LBodyPos]) = $FE) and (Ord(LResp[LBodyPos + 1]) = $FF),
      'embedded positioned read lands on exact window bytes');

    LResp := SendRawRequest(LPort,
      'GET /e1/bin.bin HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Range: bytes=0-1,2-3'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 416', LResp) > 0, 'embedded multi-range yields 416');
  finally
    StopTestServer(LServer, LHandle);
  end;

  LVfs := BuildEmbedVfs(False);
  StartEmbedServer(LVfs, '/e2/*filepath', LServer, LPort, LHandle);
  try
    LResp := SendRawRequest(LPort, 'GET /e2/style.css HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'unhashed blob status 200');
    LETag := HeaderValue(LResp, 'etag');
    Check((Length(LETag) > 0) and (Pos('"fnv-', LETag) = 0),
      'unhashed entry falls back to size+mtime etag');
    Check(Pos('content-type: text/css', LResp) > 0, 'unhashed mime css');
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
    T.Test('ServeFile range open-ended bytes=N-',
      @TestServeFileRangeOpenEnded);
    T.Test('ServeFile multi-range rejected 416',
      @TestServeFileMultiRangeRejected);
    T.Test('ServeFile range suffix request',
      @TestServeFileRangeSuffix);
    T.Test('ServeFile range not satisfiable returns 416',
      @TestServeFileRangeNotSatisfiable);
    T.Test('ServeFileDownload sets Content-Disposition',
      @TestServeFileDownloadDisposition);
    T.Test('ServeFileDownload custom filename',
      @TestServeFileDownloadCustomName);
    T.Test('ServeVfs serves memtree file', @TestServeVfsExistingFile);
    T.Test('ServeVfs missing entry returns 404', @TestServeVfsMissingFile404);
    T.Test('ServeVfs directory and root return 404',
      @TestServeVfsDirectoryReturns404);
    T.Test('ServeVfs invalid paths are plain misses',
      @TestServeVfsInvalidPathsReturn404);
    T.Test('ServeVfs ETag forms fnv vs size+mtime', @TestServeVfsETagForms);
    T.Test('ServeVfs conditional via hash ETag',
      @TestServeVfsNotModifiedViaETag);
    T.Test('ServeVfs unknown mtime skips IMS negotiation',
      @TestServeVfsUnknownModTimeConditional);
    T.Test('ServeVfs known mtime yields 304 on IMS',
      @TestServeVfsKnownModTimeConditional304);
    T.Test('ServeVfs range 206/416 semantics', @TestServeVfsRangeRequests);
    T.Test('ServeVfs preserves binary body bytes',
      @TestServeVfsBinaryBodyPreserved);
    T.Test('ServeVfs os backend consistency',
      @TestServeVfsOsBackendConsistency);
    T.Test('ServeVfs embedded hashed etag and conditional',
      @TestServeVfsEmbeddedHashedETagAndConditional);
    T.Test('ServeVfs embedded unknown modtime',
      @TestServeVfsEmbeddedUnknownModTime);
    T.Test('ServeVfs embedded range and unhashed fallback',
      @TestServeVfsEmbeddedRangeAndUnhashedFallback);
    T.Test('TryParseHttpDate three formats', @TestTryParseHttpDate);
  if not T.Run then Halt(1);
  finally
    CleanupTmpDir;
  end;
end.
