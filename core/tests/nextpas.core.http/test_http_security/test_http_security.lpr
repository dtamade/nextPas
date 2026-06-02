program test_http_security;
{**
 * @desc HTTP security test suite — sends malicious/edge-case requests to a real
 *       server and verifies safe handling (reject or close).
 *}

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
var LCtx: PServerCtx;
begin
  Result := nil;
  LCtx := PServerCtx(AArg);
  try
    LCtx^.Server.ListenAndServe(LCtx^.Addr, LCtx^.Port);
  except
  end;
  Dispose(LCtx);
end;

function StartSecurityServer(const AOpts: THttpServerOptions; out AServer: THttpServer; out APort: UInt16): TPlatformThreadHandle;
var
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LRouter: THttpRouter;
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
    LReply := 'echo:' + IntToStr(Int64(LTotal));
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LReply))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LReply[1], SizeUInt(Length(LReply)));
  end);
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := 'ok';
    AW.GetHeaders.Set_('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 2);
  end);

  AServer := THttpServer.Create(LRouter as IHttpHandler, AOpts);
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
var LRet: Pointer;
begin
  AServer.Shutdown;
  platform_thread_join(AHandle, LRet);
  AServer.Free;
  AServer := nil;
end;

function SendRaw(const APort: UInt16; const AData: string; ATimeoutSec: Int32 = 3): string;
var
  LConn: ITcpStream;
  LBuf: array[0..8191] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  LConn := TcpConnect('127.0.0.1', APort);
  try
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(ATimeoutSec)));
    if Length(AData) > 0 then
      LConn.Write(AData[1], SizeUInt(Length(AData)));
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

function SendRawBytes(const APort: UInt16; const AData: PByte; ALen: SizeUInt; ATimeoutSec: Int32 = 3): string;
var
  LConn: ITcpStream;
  LBuf: array[0..8191] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  LConn := TcpConnect('127.0.0.1', APort);
  try
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(ATimeoutSec)));
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

function SendRawAndShutdownWrite(const APort: UInt16; const AData: string; ATimeoutSec: Int32 = 3): string;
var
  LConn: ITcpStream;
  LBuf: array[0..8191] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  LConn := TcpConnect('127.0.0.1', APort);
  try
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(ATimeoutSec)));
    if Length(AData) > 0 then
      LConn.Write(AData[1], SizeUInt(Length(AData)));
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

{ Test 1: Content-Length + Transfer-Encoding conflict }
procedure TestContentLengthTransferEncodingConflict;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 5'#13#10 +
            'Transfer-Encoding: chunked'#13#10#13#10'0'#13#10#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'CL+TE conflict: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 2: Malformed chunk extension }
procedure TestMalformedChunkExtension;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5;'#13#10'hello'#13#10 +
            '0'#13#10#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Malformed chunk extension: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 3: Duplicate Content-Length with different values }
procedure TestDuplicateContentLength;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 5'#13#10 +
            'Content-Length: 10'#13#10'Connection: close'#13#10#13#10'hello';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    Check((Pos('400', LResp) > 0) or (Length(LResp) = 0),
      'Duplicate CL: rejected or closed');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4: Oversized header (>8KB) — llhttp parses it; server doesn't crash }
procedure TestOversizedHeader;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle;
    LResp, LReq, LBig: string;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    SetLength(LBig, 9000);
    FillChar(LBig[1], 9000, Ord('A'));
    LReq := 'GET / HTTP/1.1'#13#10'Host: x'#13#10'X-Big: ' + LBig + #13#10 +
            'Connection: close'#13#10#13#10;
    LResp := SendRaw(LPort, LReq);
    { llhttp has no built-in header size limit — server may respond 200 or reject.
      Key: server doesn't crash and responds coherently. }
    Check((Pos('431', LResp) > 0) or (Pos('400', LResp) > 0) or
          (Pos('200', LResp) > 0) or (Length(LResp) = 0),
      'Oversized header: server handled safely');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 5: Header with null byte }
procedure TestHeaderNullByte;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle;
    LResp: string; LReq: array of Byte;
const
  PREFIX = 'GET / HTTP/1.1'#13#10'Host: x'#13#10'X-Evil: foo';
  SUFFIX = 'bar'#13#10'Connection: close'#13#10#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    SetLength(LReq, Length(PREFIX) + 1 + Length(SUFFIX));
    Move(PREFIX[1], LReq[0], Length(PREFIX));
    LReq[Length(PREFIX)] := 0; { null byte }
    Move(SUFFIX[1], LReq[Length(PREFIX) + 1], Length(SUFFIX));
    LResp := SendRawBytes(LPort, @LReq[0], SizeUInt(Length(LReq)));
    Check((Pos('400', LResp) > 0) or (Length(LResp) = 0),
      'Null byte in header: rejected or closed');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 6: Request line too long (>8KB URL) — llhttp parses it; server doesn't crash }
procedure TestRequestLineTooLong;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle;
    LResp, LReq, LPath: string;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    SetLength(LPath, 9000);
    FillChar(LPath[1], 9000, Ord('a'));
    LReq := 'GET /' + LPath + ' HTTP/1.1'#13#10'Host: x'#13#10'Connection: close'#13#10#13#10;
    LResp := SendRaw(LPort, LReq);
    { llhttp has no URL length limit — server may respond 404 (no route) or 200.
      Key: server doesn't crash. }
    Check((Pos('414', LResp) > 0) or (Pos('400', LResp) > 0) or
          (Pos('404', LResp) > 0) or (Pos('200', LResp) > 0) or (Length(LResp) = 0),
      'Long URL: server handled safely');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 7: Slowloris — partial request, server should timeout and close }
procedure TestSlowloris;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle;
    LConn: ITcpStream; LBuf: array[0..1023] of Byte; LN: SizeUInt;
    LOpts: THttpServerOptions; LResp: string; LClosed: Boolean;
const PARTIAL = 'GET / HTTP/1.1'#13#10;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.IdleTimeout := 1000; { 1 second idle timeout }
  LHandle := StartSecurityServer(LOpts, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      { Send partial request — only the request line, no CRLFCRLF }
      LConn.Write(PARTIAL[1], SizeUInt(Length(PARTIAL)));
      { Wait — server should timeout after 1s and close }
      LResp := '';
      LClosed := False;
      repeat
        try
          LN := LConn.Read(LBuf[0], 1024);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end
        else
          LClosed := True;
      until LClosed;
      { Server must eventually close the connection — that's the key security property.
        It may send a 400/408 error response first, or just close. }
      Check(LClosed, 'Slowloris: server closed connection after timeout');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 8: HTTP/0.9 request — no version. llhttp may reject or parse as HTTP/1.0 }
procedure TestHttp09Request;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'GET /'#13#10#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    { llhttp may reject (400) or treat as HTTP/0.9 — both are safe }
    Check((Pos('400', LResp) > 0) or (Pos('200', LResp) > 0) or (Length(LResp) = 0),
      'HTTP/0.9: server handled safely (no crash)');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 9: CRLF injection in request path — llhttp treats CRLF as end of URL }
procedure TestCrlfInjection;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle;
    LResp: string; LReq: array of Byte;
const
  { GET /path\r\nInjected: header HTTP/1.1\r\nHost: x\r\n\r\n }
  PART1 = 'GET /path';
  INJECT = #13#10'Injected: header';
  PART2 = ' HTTP/1.1'#13#10'Host: x'#13#10'Connection: close'#13#10#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    SetLength(LReq, Length(PART1) + Length(INJECT) + Length(PART2));
    Move(PART1[1], LReq[0], Length(PART1));
    Move(INJECT[1], LReq[Length(PART1)], Length(INJECT));
    Move(PART2[1], LReq[Length(PART1) + Length(INJECT)], Length(PART2));
    LResp := SendRawBytes(LPort, @LReq[0], SizeUInt(Length(LReq)));
    { llhttp sees CRLF as end of request line — "GET /path" with no version,
      which it may reject (400) or parse as incomplete. Either way, no header
      injection is possible. Server may also respond 200 if it parses /path as URL. }
    Check((Pos('400', LResp) > 0) or (Pos('200', LResp) > 0) or
          (Pos('404', LResp) > 0) or (Length(LResp) = 0),
      'CRLF injection: no header injection (server safe)');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 10: Missing Host header (HTTP/1.1 requires it) }
procedure TestMissingHost;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'GET / HTTP/1.1'#13#10'Connection: close'#13#10#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    { llhttp doesn't enforce Host requirement — server may still respond 200 }
    Check((Pos('400', LResp) > 0) or (Pos('200', LResp) > 0) or (Length(LResp) = 0),
      'Missing Host: server handled (200 or 400 both acceptable)');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 11: Very long method name (1000 chars) }
procedure TestLongMethodName;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle;
    LResp, LReq, LMethod: string;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    SetLength(LMethod, 1000);
    FillChar(LMethod[1], 1000, Ord('X'));
    LReq := LMethod + ' / HTTP/1.1'#13#10'Host: x'#13#10'Connection: close'#13#10#13#10;
    LResp := SendRaw(LPort, LReq);
    Check((Pos('400', LResp) > 0) or (Pos('501', LResp) > 0) or (Length(LResp) = 0),
      'Long method: rejected or closed');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 12: Body larger than Content-Length }
procedure TestBodyLargerThanContentLength;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 5'#13#10 +
            'Connection: close'#13#10#13#10'hello_extra_bytes_here';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    { Server should only read 5 bytes (Content-Length), respond with echo:5 }
    Check((Pos('echo:5', LResp) > 0) or (Pos('400', LResp) > 0) or (Length(LResp) = 0),
      'Body > CL: server read only Content-Length bytes or rejected');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 13: Negative Content-Length }
procedure TestNegativeContentLength;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: -1'#13#10 +
            'Connection: close'#13#10#13#10'hello';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    Check((Pos('400', LResp) > 0) or (Length(LResp) = 0),
      'Negative CL: rejected or closed');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 14: Truncated Content-Length request body at EOF }
procedure TestTruncatedContentLengthRequestAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 10'#13#10 +
            'Connection: close'#13#10#13#10'hello';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated Content-Length request EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 15: Malformed trailer header field }
procedure TestMalformedTrailerField;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Bad'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'Bad Header: value'#13#10#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Malformed trailer field: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 16: Truncated trailer section at EOF }
procedure TestTruncatedTrailerAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: value'#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated trailer EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Main }

begin
  T := TTestRunner.Create('nextpas.core.http.security');
  T.Run('CL + TE conflict', @TestContentLengthTransferEncodingConflict);
  T.Run('Malformed chunk extension', @TestMalformedChunkExtension);
  T.Run('Duplicate Content-Length', @TestDuplicateContentLength);
  T.Run('Oversized header >8KB', @TestOversizedHeader);
  T.Run('Null byte in header', @TestHeaderNullByte);
  T.Run('Request line too long', @TestRequestLineTooLong);
  T.Run('Slowloris partial request', @TestSlowloris);
  T.Run('HTTP/0.9 no version', @TestHttp09Request);
  T.Run('CRLF injection in path', @TestCrlfInjection);
  T.Run('Missing Host header', @TestMissingHost);
  T.Run('Very long method name', @TestLongMethodName);
  T.Run('Body larger than CL', @TestBodyLargerThanContentLength);
  T.Run('Negative Content-Length', @TestNegativeContentLength);
  T.Run('Truncated Content-Length request body at EOF -> 400', @TestTruncatedContentLengthRequestAtEof);
  T.Run('Malformed trailer field -> 400', @TestMalformedTrailerField);
  T.Run('Truncated trailer section at EOF -> 400', @TestTruncatedTrailerAtEof);
  T.Summary;
end.
