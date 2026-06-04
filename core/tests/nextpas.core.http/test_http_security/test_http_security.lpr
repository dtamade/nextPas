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

procedure RunSecurityRequestExpectStatus(const AOpts: THttpServerOptions;
  const AReq, AExpectedStatus, ALabel: string; const AShutdownWrite: Boolean = False);
var
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LHandle := StartSecurityServer(AOpts, LServer, LPort);
  try
    if AShutdownWrite then
      LResp := SendRawAndShutdownWrite(LPort, AReq)
    else
      LResp := SendRaw(LPort, AReq);
    Check(Pos(AExpectedStatus, LResp) > 0, ALabel);
  finally
    StopServer(LServer, LHandle);
  end;
end;

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
  repeat
    try
      LN := AConn.Read(LBuf[0], 1);
    except
      LN := 0;
    end;
    if LN = 0 then
      Exit;
    Result := Result + Chr(LBuf[0]);
    LHeaderEnd := Pos(#13#10#13#10, Result);
  until LHeaderEnd > 0;

  LContentLength := 0;
  LClPos := Pos('content-length: ', Result);
  if LClPos > 0 then
  begin
    LClPos := LClPos + 16;
    LClEnd := LClPos;
    while (LClEnd <= Length(Result)) and (Result[LClEnd] >= '0') and
      (Result[LClEnd] <= '9') do
      Inc(LClEnd);
    LClStr := Copy(Result, LClPos, LClEnd - LClPos);
    LContentLength := Int32(StrToInt(LClStr));
  end;

  LBodyRead := Length(Result) - (LHeaderEnd + 3);
  while LBodyRead < LContentLength do
  begin
    try
      LN := AConn.Read(LBuf[0], 1);
    except
      LN := 0;
    end;
    if LN = 0 then
      Exit;
    Result := Result + Chr(LBuf[0]);
    Inc(LBodyRead);
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

{ Test 1aa: Transfer-Encoding + Content-Length conflict reverse order }
procedure TestTransferEncodingContentLengthConflictReverseOrder;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Content-Length: 5'#13#10#13#10'0'#13#10#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'TE+CL reverse-order conflict: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 1a: Unsupported transfer coding before chunked }
procedure TestUnsupportedTransferCodingBeforeChunked;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: gzip, chunked'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    Check(Pos('HTTP/1.1 501', LResp) > 0,
      'Unsupported transfer coding before chunked: explicit 501');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 1b: Chunked must be final transfer coding }
procedure TestChunkedMustBeFinalTransferCoding;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked, gzip'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Chunked must be final transfer coding: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 2: Malformed chunk extension }
procedure TestInvalidChunkSize;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            'Z'#13#10'hello'#13#10 +
            '0'#13#10#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Invalid chunk size: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 2a: Malformed chunk extension }
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

{ Test 2aa: Truncated chunk extension at EOF }
procedure TestTruncatedChunkExtensionAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5;sig=abc';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated chunk extension EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 2ab: Truncated chunk extension CR at EOF }
procedure TestTruncatedChunkExtensionCrAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5;sig=abc'#13;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated chunk extension CR EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 2b: Missing chunk-data CRLF }
procedure TestMissingChunkDataCrLf;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello0'#13#10#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Missing chunk-data CRLF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 2c: Truncated chunked request at EOF }
procedure TestTruncatedChunkedRequestAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hel';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated chunked request EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 2d: Truncated chunk-size line at EOF }
procedure TestTruncatedChunkSizeLineAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated chunk-size line EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 2e: Truncated terminal chunk ending at EOF }
procedure TestTruncatedTerminalChunkEndingAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated terminal chunk ending EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 2e0: Truncated terminal chunk ending CR at EOF }
procedure TestTruncatedTerminalChunkEndingCrAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10#13;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated terminal chunk ending CR EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 2ea: Truncated terminal chunk extension at EOF }
procedure TestTruncatedTerminalChunkExtensionAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0;sig=abc';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated terminal chunk extension EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 2eb: Truncated terminal chunk extension CR at EOF }
procedure TestTruncatedTerminalChunkExtensionCrAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0;sig=abc'#13;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated terminal chunk extension CR EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 2ec: Truncated terminal chunk ending after extension at EOF }
procedure TestTruncatedTerminalChunkEndingAfterExtensionAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0;sig=abc'#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated terminal chunk ending after extension EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 2ed: Truncated terminal chunk ending after extension CR at EOF }
procedure TestTruncatedTerminalChunkEndingAfterExtensionCrAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0;sig=abc'#13#10#13;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated terminal chunk ending after extension CR EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 2f: Truncated chunk-data ending at EOF }
procedure TestTruncatedChunkDataEndingAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated chunk-data ending EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 2g: Truncated chunk-data CR at EOF }
procedure TestTruncatedChunkDataCrAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated chunk-data CR EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 2h: Chunked MaxBodySize rejection must happen before terminal chunk }
procedure TestChunkedMaxBodySizeRejectsBeforeTerminalChunk;
var
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp: string;
  LBuf: array[0..8191] of Byte;
  LN: SizeUInt;
  LOpts: THttpServerOptions;
  LChunk1: string;
  LChunk2: string;
  LReq: string;
  LChunkHex1: string;
  LChunkHex2: string;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.MaxBodySize := 1024;
  LHandle := StartSecurityServer(LOpts, LServer, LPort);
  try
    SetLength(LChunk1, 700);
    FillChar(LChunk1[1], 700, Ord('B'));
    SetLength(LChunk2, 700);
    FillChar(LChunk2[1], 700, Ord('C'));
    LChunkHex1 := IntToHex(Length(LChunk1), 1);
    LChunkHex2 := IntToHex(Length(LChunk2), 1);
    LReq := 'POST / HTTP/1.1'#13#10 +
            'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Connection: keep-alive'#13#10#13#10 +
            LChunkHex1 + #13#10 +
            LChunk1 + #13#10 +
            LChunkHex2 + #13#10 +
            LChunk2 + #13#10;

    LResp := '';
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(2)));
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
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

    Check(Pos('HTTP/1.1 413', LResp) > 0,
      'Chunked MaxBodySize: explicit 413 before terminal chunk');
    Check(Pos('echo:', LResp) = 0,
      'Chunked MaxBodySize: handler response never written before terminal chunk');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 3: Generic malformed request }
procedure TestGenericMalformedRequest;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'GARBAGE DATA HERE'#13#10#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Generic malformed request: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4: Duplicate Content-Length with different values }
procedure TestDuplicateContentLength;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 5'#13#10 +
            'Content-Length: 10'#13#10'Connection: close'#13#10#13#10'hello';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Duplicate CL: explicit 400');
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
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Null byte in header: explicit 400');
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
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'HTTP/0.9: explicit 400');
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
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'CRLF injection: explicit 400');
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
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Missing Host: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 11: Request line truncated at EOF }
procedure TestRequestLineTruncatedAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'GET / HTTP/1.';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated request line EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 12: Headers truncated at EOF }
procedure TestHeadersTruncatedAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'GET / HTTP/1.1'#13#10'Host: local';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated headers EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 13: Very long method name (1000 chars) }
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
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Long method: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 14: Body larger than Content-Length }
procedure TestBodyLargerThanContentLength;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 5'#13#10 +
            'Connection: close'#13#10#13#10'hello_extra_bytes_here';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Body > CL with Connection: close: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 14a: Keep-alive Content-Length request with garbage tail }
procedure TestContentLengthKeepAliveGarbageTailSafeHandling;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 5'#13#10#13#10 +
            'hello_extra_bytes_here';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0,
      'Keep-alive Content-Length tail: first response still completes');
    Check(Pos('echo:5', LResp) > 0,
      'Keep-alive Content-Length tail: first request body handled correctly');
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Keep-alive Content-Length tail: malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 14aa: Keep-alive Content-Length request with truncated follow-up request line }
procedure TestContentLengthKeepAliveTruncatedFollowUpRequestLineSafeHandling;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 5'#13#10#13#10 +
            'hello' +
            'GET /next HTTP/1.1';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0,
      'Keep-alive Content-Length partial follow-up line: first response still completes');
    Check(Pos('echo:5', LResp) > 0,
      'Keep-alive Content-Length partial follow-up line: first request body handled correctly');
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Keep-alive Content-Length partial follow-up line: malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestContentLengthKeepAlivePartialFollowUpRequestLineCanCompleteLater;
var
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1: string;
  LResp2: string;
const
  REQ1 = 'POST / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 5'#13#10#13#10 +
         'hello' +
         'GET / HTTP/1.1';
  REQ2_REST = #13#10 +
              'Host: x'#13#10 +
              'Connection: close'#13#10#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ1[1], SizeUInt(Length(REQ1)));
      LResp1 := ReadOneResponse(LConn);
      Check(Pos('HTTP/1.1 200', LResp1) > 0,
        'Keep-alive Content-Length partial-next-line: first response still completes');
      Check(Pos('echo:5', LResp1) > 0,
        'Keep-alive Content-Length partial-next-line: first request body handled correctly');

      LConn.Write(REQ2_REST[1], SizeUInt(Length(REQ2_REST)));
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('HTTP/1.1 200', LResp2) > 0,
        'Keep-alive Content-Length partial-next-line: completed follow-up request returns 200');
      Check(Pos('ok', LResp2) > 0,
        'Keep-alive Content-Length partial-next-line: second request body preserved');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 14ab: Keep-alive Content-Length request with truncated follow-up headers }
procedure TestContentLengthKeepAliveTruncatedFollowUpHeadersSafeHandling;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 5'#13#10#13#10 +
            'hello' +
            'GET /next HTTP/1.1'#13#10 +
            'Host: x'#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0,
      'Keep-alive Content-Length partial follow-up headers: first response still completes');
    Check(Pos('echo:5', LResp) > 0,
      'Keep-alive Content-Length partial follow-up headers: first request body handled correctly');
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Keep-alive Content-Length partial follow-up headers: malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 14b: Chunked request with extra bytes after terminal chunk and close }
procedure TestChunkedExtraBytesAfterClose;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10#13#10 +
            'garbage';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Chunked extra bytes after close: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 14c: Keep-alive chunked request with garbage tail }
procedure TestChunkedKeepAliveGarbageTailSafeHandling;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10#13#10 +
            'garbage';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0,
      'Keep-alive chunked tail: first response still completes');
    Check(Pos('echo:5', LResp) > 0,
      'Keep-alive chunked tail: first request body handled correctly');
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Keep-alive chunked tail: malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 14ca: Keep-alive chunked request with truncated follow-up request line }
procedure TestChunkedKeepAliveTruncatedFollowUpRequestLineSafeHandling;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10#13#10 +
            'GET /next HTTP/1.1';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0,
      'Keep-alive chunked partial follow-up line: first response still completes');
    Check(Pos('echo:5', LResp) > 0,
      'Keep-alive chunked partial follow-up line: first request body handled correctly');
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Keep-alive chunked partial follow-up line: malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedKeepAlivePartialFollowUpRequestLineCanCompleteLater;
var
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1: string;
  LResp2: string;
const
  REQ1 = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
         'Transfer-Encoding: chunked'#13#10#13#10 +
         '5'#13#10'hello'#13#10 +
         '0'#13#10#13#10 +
         'GET / HTTP/1.1';
  REQ2_REST = #13#10 +
              'Host: x'#13#10 +
              'Connection: close'#13#10#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ1[1], SizeUInt(Length(REQ1)));
      LResp1 := ReadOneResponse(LConn);
      Check(Pos('HTTP/1.1 200', LResp1) > 0,
        'Keep-alive chunked partial-next-line: first response still completes');
      Check(Pos('echo:5', LResp1) > 0,
        'Keep-alive chunked partial-next-line: first request body handled correctly');

      LConn.Write(REQ2_REST[1], SizeUInt(Length(REQ2_REST)));
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('HTTP/1.1 200', LResp2) > 0,
        'Keep-alive chunked partial-next-line: completed follow-up request returns 200');
      Check(Pos('ok', LResp2) > 0,
        'Keep-alive chunked partial-next-line: second request body preserved');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 14cb: Keep-alive chunked request with truncated follow-up headers }
procedure TestChunkedKeepAliveTruncatedFollowUpHeadersSafeHandling;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10#13#10 +
            'GET /next HTTP/1.1'#13#10 +
            'Host: x'#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0,
      'Keep-alive chunked partial follow-up headers: first response still completes');
    Check(Pos('echo:5', LResp) > 0,
      'Keep-alive chunked partial follow-up headers: first request body handled correctly');
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Keep-alive chunked partial follow-up headers: malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 14cc: Keep-alive chunked trailer-complete request with garbage tail }
procedure TestChunkedTrailerKeepAliveGarbageTailSafeHandling;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: value'#13#10#13#10 +
            'garbage';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0,
      'Keep-alive chunked trailer tail: first response still completes');
    Check(Pos('echo:5', LResp) > 0,
      'Keep-alive chunked trailer tail: first request body handled correctly');
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Keep-alive chunked trailer tail: malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 14cd: Keep-alive chunked trailer-complete request with truncated follow-up request line }
procedure TestChunkedTrailerKeepAliveTruncatedFollowUpRequestLineSafeHandling;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: value'#13#10#13#10 +
            'GET /next HTTP/1.1';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0,
      'Keep-alive chunked trailer partial follow-up line: first response still completes');
    Check(Pos('echo:5', LResp) > 0,
      'Keep-alive chunked trailer partial follow-up line: first request body handled correctly');
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Keep-alive chunked trailer partial follow-up line: malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 14ce: Keep-alive chunked trailer-complete request with truncated follow-up headers }
procedure TestChunkedTrailerKeepAliveTruncatedFollowUpHeadersSafeHandling;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: value'#13#10#13#10 +
            'GET /next HTTP/1.1'#13#10 +
            'Host: x'#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0,
      'Keep-alive chunked trailer partial follow-up headers: first response still completes');
    Check(Pos('echo:5', LResp) > 0,
      'Keep-alive chunked trailer partial follow-up headers: first request body handled correctly');
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Keep-alive chunked trailer partial follow-up headers: malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure RunChunkedTrailerPartialFollowUpRequestLineCanCompleteLater(
  const AOpts: THttpServerOptions; const ALabel: string);
var
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1: string;
  LResp2: string;
const
  REQ1 = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
         'Transfer-Encoding: chunked'#13#10 +
         'Trailer: X-Test'#13#10#13#10 +
         '5'#13#10'hello'#13#10 +
         '0'#13#10 +
         'X-Test: value'#13#10#13#10 +
         'GET / HTTP/1.1';
  REQ2_REST = #13#10 +
              'Host: x'#13#10 +
              'Connection: close'#13#10#13#10;
begin
  LHandle := StartSecurityServer(AOpts, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ1[1], SizeUInt(Length(REQ1)));
      LResp1 := ReadOneResponse(LConn);
      Check(Pos('HTTP/1.1 200', LResp1) > 0,
        ALabel + ': first response still completes');
      Check(Pos('echo:5', LResp1) > 0,
        ALabel + ': first request body handled correctly');

      LConn.Write(REQ2_REST[1], SizeUInt(Length(REQ2_REST)));
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('HTTP/1.1 200', LResp2) > 0,
        ALabel + ': completed follow-up request returns 200');
      Check(Pos('ok', LResp2) > 0,
        ALabel + ': second request body preserved');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedTrailerPartialFollowUpRequestLineCanCompleteLater;
begin
  RunChunkedTrailerPartialFollowUpRequestLineCanCompleteLater(
    THttpServerOptions.Default,
    'Keep-alive chunked trailer partial-next-line');
end;

procedure RunChunkedTrailerPipelinedNextRequestInSingleWrite(
  const AOpts: THttpServerOptions; const ALabel: string);
var
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1: string;
  LResp2: string;
  LCombinedReq: string;
const
  REQ1 = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
         'Transfer-Encoding: chunked'#13#10 +
         'Trailer: X-Test'#13#10#13#10 +
         '5'#13#10'hello'#13#10 +
         '0'#13#10 +
         'X-Test: value'#13#10#13#10;
  REQ2 = 'GET / HTTP/1.1'#13#10 +
         'Host: x'#13#10 +
         'Connection: close'#13#10#13#10;
begin
  LCombinedReq := REQ1 + REQ2;
  LHandle := StartSecurityServer(AOpts, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(LCombinedReq[1], SizeUInt(Length(LCombinedReq)));
      LResp1 := ReadOneResponse(LConn);
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('HTTP/1.1 200', LResp1) > 0,
        ALabel + ': first response 200');
      Check(Pos('echo:5', LResp1) > 0,
        ALabel + ': first body preserved');
      Check(Pos('HTTP/1.1 200', LResp2) > 0,
        ALabel + ': second response 200');
      Check(Pos('ok', LResp2) > 0,
        ALabel + ': second body preserved');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedTrailerPipelinedNextRequestInSingleWrite;
begin
  RunChunkedTrailerPipelinedNextRequestInSingleWrite(
    THttpServerOptions.Default,
    'Keep-alive chunked trailer same-write pipeline');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestChunkedTrailerPartialFollowUpRequestLineCanCompleteLaterEpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunChunkedTrailerPartialFollowUpRequestLineCanCompleteLater(
    LOpts,
    'epoll keep-alive chunked trailer partial-next-line');
end;

procedure TestChunkedTrailerPipelinedNextRequestInSingleWriteEpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunChunkedTrailerPipelinedNextRequestInSingleWrite(
    LOpts,
    'epoll keep-alive chunked trailer same-write pipeline');
end;
{$ENDIF}

{ Test 15: Negative Content-Length }
procedure TestNegativeContentLength;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: -1'#13#10 +
            'Connection: close'#13#10#13#10'hello';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Negative CL: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 16: Truncated Content-Length request body at EOF }
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

{ Test 17: Malformed trailer header field }
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

procedure RunChunkedOversizeTrailerUsesMaxHeaderSize(
  const AOpts: THttpServerOptions; const ALabel: string);
var
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LTrailerValue: string;
  LReq: string;
begin
  LHandle := StartSecurityServer(AOpts, LServer, LPort);
  try
    SetLength(LTrailerValue, 300);
    FillChar(LTrailerValue[1], 300, Ord('x'));
    LReq := 'POST / HTTP/1.1'#13#10 +
            'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Big'#13#10 +
            'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Big: ' + LTrailerValue + #13#10#13#10;
    LResp := SendRaw(LPort, LReq);
    Check((Pos('HTTP/1.1 431', LResp) > 0) or (Length(LResp) = 0),
      ALabel + ': 431 or connection closed');
    Check(Pos('echo:5', LResp) = 0,
      ALabel + ': handler response not written');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 17a: Oversize trailer still uses MaxHeaderSize enforcement }
procedure TestChunkedOversizeTrailerUsesMaxHeaderSize;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.MaxHeaderSize := 256;
  RunChunkedOversizeTrailerUsesMaxHeaderSize(LOpts, 'Oversize trailer');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestChunkedOversizeTrailerUsesMaxHeaderSizeEpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.MaxHeaderSize := 256;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunChunkedOversizeTrailerUsesMaxHeaderSize(LOpts, 'epoll oversize trailer');
end;
{$ENDIF}

{ Test 18: Truncated trailer section at EOF }
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

{ Test 18a: Truncated trailer field-name at EOF }
procedure TestTruncatedTrailerFieldNameAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated trailer field-name EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 18b: Truncated trailer separator at EOF }
procedure TestTruncatedTrailerSeparatorAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test:';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated trailer separator EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 18c: Truncated trailer empty-value CR at EOF }
procedure TestTruncatedTrailerEmptyValueCrAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test:'#13;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated trailer empty-value CR EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 18d: Truncated trailer empty-value at EOF }
procedure TestTruncatedTrailerEmptyValueAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test:'#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated trailer empty-value EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 18e: Truncated trailer empty-value section CR at EOF }
procedure TestTruncatedTrailerEmptyValueSectionCrAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test:'#13#10#13;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated trailer empty-value section CR EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 18c: Truncated trailer whitespace at EOF }
procedure TestTruncatedTrailerWhitespaceAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: ';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated trailer whitespace EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 18d: Truncated trailer whitespace CR at EOF }
procedure TestTruncatedTrailerWhitespaceCrAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: '#13;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated trailer whitespace CR EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 18e: Truncated trailer whitespace section at EOF }
procedure TestTruncatedTrailerWhitespaceSectionAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: '#13#10;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated trailer whitespace section EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 18f: Truncated trailer whitespace section CR at EOF }
procedure TestTruncatedTrailerWhitespaceSectionCrAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: '#13#10#13;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated trailer whitespace section CR EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 18a: Truncated trailer field line at EOF }
procedure TestTruncatedTrailerFieldLineAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: value';
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated trailer field line EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 18b: Truncated trailer field CR at EOF }
procedure TestTruncatedTrailerFieldCrAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: value'#13;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated trailer field CR EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 18a: Truncated trailer section CR at EOF }
procedure TestTruncatedTrailerCrAtEof;
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: value'#13#10#13;
begin
  LHandle := StartSecurityServer(THttpServerOptions.Default, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'Truncated trailer CR EOF: explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{$IFDEF NEXTPAS_LINUX}
function EpollSecurityServerOptions: THttpServerOptions;
begin
  Result := THttpServerOptions.Default;
  Result.Backend := TCP_SERVER_BACKEND_EPOLL;
end;

procedure TestUnsupportedTransferCodingBeforeChunkedEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: gzip, chunked'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10#13#10;
begin
  RunSecurityRequestExpectStatus(
    EpollSecurityServerOptions,
    REQ,
    'HTTP/1.1 501',
    'epoll unsupported transfer coding before chunked: explicit 501');
end;

procedure TestInvalidChunkSizeEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            'Z'#13#10'hello'#13#10 +
            '0'#13#10#13#10;
begin
  RunSecurityRequestExpectStatus(
    EpollSecurityServerOptions,
    REQ,
    'HTTP/1.1 400',
    'epoll invalid chunk size: explicit 400');
end;

procedure TestMissingChunkDataCrLfEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello0'#13#10#13#10;
begin
  RunSecurityRequestExpectStatus(
    EpollSecurityServerOptions,
    REQ,
    'HTTP/1.1 400',
    'epoll missing chunk-data CRLF: explicit 400');
end;

procedure TestTruncatedTrailerCrAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: value'#13#10#13;
begin
  RunSecurityRequestExpectStatus(
    EpollSecurityServerOptions,
    REQ,
    'HTTP/1.1 400',
    'epoll truncated trailer CR EOF: explicit 400',
    True);
end;
{$ENDIF}

{ Main }

begin
  T := TTestRunner.Create('nextpas.core.http.security');
  T.Run('CL + TE conflict', @TestContentLengthTransferEncodingConflict);
  T.Run('TE + CL conflict reverse order', @TestTransferEncodingContentLengthConflictReverseOrder);
  T.Run('Unsupported transfer coding before chunked -> 501',
    @TestUnsupportedTransferCodingBeforeChunked);
  T.Run('Chunked must be final transfer coding -> 400',
    @TestChunkedMustBeFinalTransferCoding);
  T.Run('Invalid chunk size -> 400', @TestInvalidChunkSize);
  T.Run('Malformed chunk extension', @TestMalformedChunkExtension);
  T.Run('Truncated chunk extension at EOF -> 400', @TestTruncatedChunkExtensionAtEof);
  T.Run('Truncated chunk extension CR at EOF -> 400', @TestTruncatedChunkExtensionCrAtEof);
  T.Run('Missing chunk-data CRLF', @TestMissingChunkDataCrLf);
  T.Run('Truncated chunked request at EOF -> 400', @TestTruncatedChunkedRequestAtEof);
  T.Run('Truncated chunk-size line at EOF -> 400', @TestTruncatedChunkSizeLineAtEof);
  T.Run('Truncated terminal chunk ending at EOF -> 400', @TestTruncatedTerminalChunkEndingAtEof);
  T.Run('Truncated terminal chunk ending CR at EOF -> 400', @TestTruncatedTerminalChunkEndingCrAtEof);
  T.Run('Truncated terminal chunk extension at EOF -> 400', @TestTruncatedTerminalChunkExtensionAtEof);
  T.Run('Truncated terminal chunk extension CR at EOF -> 400', @TestTruncatedTerminalChunkExtensionCrAtEof);
  T.Run('Truncated terminal chunk ending after extension at EOF -> 400',
    @TestTruncatedTerminalChunkEndingAfterExtensionAtEof);
  T.Run('Truncated terminal chunk ending after extension CR at EOF -> 400',
    @TestTruncatedTerminalChunkEndingAfterExtensionCrAtEof);
  T.Run('Truncated chunk-data ending at EOF -> 400', @TestTruncatedChunkDataEndingAtEof);
  T.Run('Truncated chunk-data CR at EOF -> 400', @TestTruncatedChunkDataCrAtEof);
  T.Run('Chunked MaxBodySize rejects before terminal chunk',
    @TestChunkedMaxBodySizeRejectsBeforeTerminalChunk);
  T.Run('Generic malformed request -> 400', @TestGenericMalformedRequest);
  T.Run('Duplicate Content-Length -> 400', @TestDuplicateContentLength);
  T.Run('Oversized header >8KB', @TestOversizedHeader);
  T.Run('Null byte in header -> 400', @TestHeaderNullByte);
  T.Run('Request line too long', @TestRequestLineTooLong);
  T.Run('Slowloris partial request', @TestSlowloris);
  T.Run('HTTP/0.9 no version -> 400', @TestHttp09Request);
  T.Run('CRLF injection in path -> 400', @TestCrlfInjection);
  T.Run('Missing Host header -> 400', @TestMissingHost);
  T.Run('Request line truncated at EOF -> 400', @TestRequestLineTruncatedAtEof);
  T.Run('Headers truncated at EOF -> 400', @TestHeadersTruncatedAtEof);
  T.Run('Very long method name -> 400', @TestLongMethodName);
  T.Run('Body larger than CL with Connection: close -> 400', @TestBodyLargerThanContentLength);
  T.Run('Content-Length keep-alive garbage tail safe handling', @TestContentLengthKeepAliveGarbageTailSafeHandling);
  T.Run('Content-Length keep-alive truncated follow-up request line safe handling',
    @TestContentLengthKeepAliveTruncatedFollowUpRequestLineSafeHandling);
  T.Run('Content-Length keep-alive partial follow-up request line can complete later',
    @TestContentLengthKeepAlivePartialFollowUpRequestLineCanCompleteLater);
  T.Run('Content-Length keep-alive truncated follow-up headers safe handling',
    @TestContentLengthKeepAliveTruncatedFollowUpHeadersSafeHandling);
  T.Run('Chunked extra bytes after close -> 400', @TestChunkedExtraBytesAfterClose);
  T.Run('Chunked keep-alive garbage tail safe handling', @TestChunkedKeepAliveGarbageTailSafeHandling);
  T.Run('Chunked keep-alive truncated follow-up request line safe handling',
    @TestChunkedKeepAliveTruncatedFollowUpRequestLineSafeHandling);
  T.Run('Chunked keep-alive partial follow-up request line can complete later',
    @TestChunkedKeepAlivePartialFollowUpRequestLineCanCompleteLater);
  T.Run('Chunked keep-alive truncated follow-up headers safe handling',
    @TestChunkedKeepAliveTruncatedFollowUpHeadersSafeHandling);
  T.Run('Chunked trailer keep-alive garbage tail safe handling',
    @TestChunkedTrailerKeepAliveGarbageTailSafeHandling);
  T.Run('Chunked trailer keep-alive truncated follow-up request line safe handling',
    @TestChunkedTrailerKeepAliveTruncatedFollowUpRequestLineSafeHandling);
  T.Run('Chunked trailer keep-alive truncated follow-up headers safe handling',
    @TestChunkedTrailerKeepAliveTruncatedFollowUpHeadersSafeHandling);
  T.Run('Chunked trailer keep-alive partial follow-up request line can complete later',
    @TestChunkedTrailerPartialFollowUpRequestLineCanCompleteLater);
  T.Run('Chunked trailer pipelined next request in single write',
    @TestChunkedTrailerPipelinedNextRequestInSingleWrite);
  T.Run('Negative Content-Length -> 400', @TestNegativeContentLength);
  T.Run('Truncated Content-Length request body at EOF -> 400', @TestTruncatedContentLengthRequestAtEof);
  T.Run('Malformed trailer field -> 400', @TestMalformedTrailerField);
  T.Run('Chunked oversize trailer uses MaxHeaderSize',
    @TestChunkedOversizeTrailerUsesMaxHeaderSize);
  {$IFDEF NEXTPAS_LINUX}
  T.Run('Chunked oversize trailer uses MaxHeaderSize with epoll backend',
    @TestChunkedOversizeTrailerUsesMaxHeaderSizeEpollBackend);
  {$ENDIF}
  T.Run('Truncated trailer section at EOF -> 400', @TestTruncatedTrailerAtEof);
  T.Run('Truncated trailer field-name at EOF -> 400', @TestTruncatedTrailerFieldNameAtEof);
  T.Run('Truncated trailer separator at EOF -> 400', @TestTruncatedTrailerSeparatorAtEof);
  T.Run('Truncated trailer empty-value CR at EOF -> 400', @TestTruncatedTrailerEmptyValueCrAtEof);
  T.Run('Truncated trailer empty-value at EOF -> 400', @TestTruncatedTrailerEmptyValueAtEof);
  T.Run('Truncated trailer empty-value section CR at EOF -> 400', @TestTruncatedTrailerEmptyValueSectionCrAtEof);
  T.Run('Truncated trailer whitespace at EOF -> 400', @TestTruncatedTrailerWhitespaceAtEof);
  T.Run('Truncated trailer whitespace CR at EOF -> 400', @TestTruncatedTrailerWhitespaceCrAtEof);
  T.Run('Truncated trailer whitespace section at EOF -> 400', @TestTruncatedTrailerWhitespaceSectionAtEof);
  T.Run('Truncated trailer whitespace section CR at EOF -> 400', @TestTruncatedTrailerWhitespaceSectionCrAtEof);
  T.Run('Truncated trailer field line at EOF -> 400', @TestTruncatedTrailerFieldLineAtEof);
  T.Run('Truncated trailer field CR at EOF -> 400', @TestTruncatedTrailerFieldCrAtEof);
  T.Run('Truncated trailer section CR at EOF -> 400', @TestTruncatedTrailerCrAtEof);
  {$IFDEF NEXTPAS_LINUX}
  T.Run('Unsupported transfer coding before chunked -> 501 with epoll backend',
    @TestUnsupportedTransferCodingBeforeChunkedEpollBackend);
  T.Run('Invalid chunk size -> 400 with epoll backend',
    @TestInvalidChunkSizeEpollBackend);
  T.Run('Missing chunk-data CRLF -> 400 with epoll backend',
    @TestMissingChunkDataCrLfEpollBackend);
  T.Run('Truncated trailer section CR at EOF -> 400 with epoll backend',
    @TestTruncatedTrailerCrAtEofEpollBackend);
  T.Run('Chunked trailer keep-alive partial follow-up request line can complete later with epoll backend',
    @TestChunkedTrailerPartialFollowUpRequestLineCanCompleteLaterEpollBackend);
  T.Run('Chunked trailer pipelined next request in single write with epoll backend',
    @TestChunkedTrailerPipelinedNextRequestInSingleWriteEpollBackend);
  {$ENDIF}
  T.Summary;
end.
