program test_http_security;
{**
 * @desc HTTP security test suite — sends malicious/edge-case requests to a real
 *       server and verifies safe handling (reject or close).
 *}

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
  nextpas.core.http.impl.h1,
  nextpas.core.http.message,
  nextpas.core.http.router,
  nextpas.core.http.server,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.socket,
  nextpas.core.platform.thread;

var
  T: TTestRunner;

const
{$IFDEF NEXTPAS_LINUX}
  TEST_SOCKET_SO_RCVBUF = 8;
  TEST_SOCKET_SO_SNDBUF = 7;
{$ELSE}
  TEST_SOCKET_SO_RCVBUF = PLATFORM_SO_RCVBUF;
  TEST_SOCKET_SO_SNDBUF = PLATFORM_SO_SNDBUF;
{$ENDIF}

type
  PServerCtx = ^TServerCtx;
  TServerCtx = record
    Server: THttpServer;
    Addr: string;
    Port: UInt16;
  end;

  TSocketTuningServerTransport = class(TInterfacedObject, IHttpServerTransport,
    IHttpServerSessionFactory)
  private
    FInner: IHttpServerTransport;
    FSendBufferBytes: Int32;
    procedure TuneConn(const AConn: ITcpStream);
  public
    constructor Create(const AInner: IHttpServerTransport;
      const ASendBufferBytes: Int32);
    function ServeConn(const AConn: ITcpStream;
      const AHandler: IHttpHandler): TTcpServerConnOwnership;
    function NewSession(const AConn: ITcpStream;
      const AHandler: IHttpHandler): ITcpServerSession;
  end;

function StartSecurityServerWithTransportAndOptions(const AHandler: IHttpHandler;
  const ATransport: IHttpServerTransport; const AOpts: THttpServerOptions;
  out AServer: THttpServer; out APort: UInt16): TPlatformThreadHandle; forward;

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
  LHandler: IHttpHandler;
begin
  LHandler := nil;
  Result := StartSecurityServerWithTransportAndOptions(
    LHandler, nil, AOpts, AServer, APort);
end;

constructor TSocketTuningServerTransport.Create(const AInner: IHttpServerTransport;
  const ASendBufferBytes: Int32);
begin
  inherited Create;
  FInner := AInner;
  FSendBufferBytes := ASendBufferBytes;
end;

procedure TSocketTuningServerTransport.TuneConn(const AConn: ITcpStream);
var
  LRuntime: ITcpSocketRuntime;
  LSocket: TPlatformSocket;
  LSize: Int32;
begin
  if FSendBufferBytes <= 0 then
    Exit;
  if not Supports(AConn, ITcpSocketRuntime, LRuntime) then
    Exit;
  LSocket := PLATFORM_INVALID_SOCKET;
{$IFDEF NEXTPAS_WINDOWS}
  LSocket.Value := LRuntime.NativeSocketHandle;
{$ELSE}
  LSocket.Value := Int32(LRuntime.NativeSocketHandle);
{$ENDIF}
  LSize := FSendBufferBytes;
  if platform_socket_setsockopt(LSocket, PLATFORM_SOL_SOCKET,
    TEST_SOCKET_SO_SNDBUF, @LSize, SizeOf(LSize)) <> 0 then
    raise EIOError.Create('server send buffer tuning failed');
end;

function TSocketTuningServerTransport.ServeConn(const AConn: ITcpStream;
  const AHandler: IHttpHandler): TTcpServerConnOwnership;
begin
  TuneConn(AConn);
  Result := FInner.ServeConn(AConn, AHandler);
end;

function TSocketTuningServerTransport.NewSession(const AConn: ITcpStream;
  const AHandler: IHttpHandler): ITcpServerSession;
var
  LFactory: IHttpServerSessionFactory;
begin
  TuneConn(AConn);
  if not Supports(FInner, IHttpServerSessionFactory, LFactory) then
    raise EInvalidOperationError.Create(
      'inner transport does not expose session factory');
  Result := LFactory.NewSession(AConn, AHandler);
end;

function StartSecurityServerWithTransportAndOptions(const AHandler: IHttpHandler;
  const ATransport: IHttpServerTransport; const AOpts: THttpServerOptions;
  out AServer: THttpServer; out APort: UInt16): TPlatformThreadHandle;
var
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LRouter: THttpRouter;
  LResolvedHandler: IHttpHandler;
begin
  LResolvedHandler := AHandler;
  if LResolvedHandler = nil then
  begin
    LRouter := THttpRouter.Create;
    LRouter.Post('/', procedure(const AReq: IHttpRequest;
      const AW: IHttpResponseWriter)
    var
      LBuf: array[0..4095] of Byte;
      LN: SizeUInt;
      LTotal: SizeUInt;
      LReply: string;
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
    LRouter.Get('/', procedure(const AReq: IHttpRequest;
      const AW: IHttpResponseWriter)
    var
      LBody: string;
    begin
      LBody := 'ok';
      AW.GetHeaders.Set_('content-length', '2');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(LBody[1], 2);
    end);
    LResolvedHandler := LRouter as IHttpHandler;
  end;

  AServer := THttpServer.Create(LResolvedHandler, ATransport, AOpts);
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

function DefaultH1ServerTransportOptions(
  const AHttpOptions: THttpServerOptions): TH1ServerTransportOptions;
begin
  Result.ReadTimeout := AHttpOptions.ReadTimeout;
  Result.WriteTimeout := AHttpOptions.WriteTimeout;
  Result.IdleTimeout := AHttpOptions.IdleTimeout;
  Result.MaxHeaderSize := AHttpOptions.MaxHeaderSize;
  Result.MaxBodySize := AHttpOptions.MaxBodySize;
end;

function SocketFromRuntime(const ARuntime: ITcpSocketRuntime): TPlatformSocket;
begin
  Result := PLATFORM_INVALID_SOCKET;
{$IFDEF NEXTPAS_WINDOWS}
  Result.Value := ARuntime.NativeSocketHandle;
{$ELSE}
  Result.Value := Int32(ARuntime.NativeSocketHandle);
{$ENDIF}
end;

procedure SetSocketRecvBuffer(const AConn: ITcpStream; const ASize: Int32);
var
  LRuntime: ITcpSocketRuntime;
  LSocket: TPlatformSocket;
  LSize: Int32;
begin
  Check(Supports(AConn, ITcpSocketRuntime, LRuntime),
    'tcp stream exposes runtime socket control for recvbuf tuning');
  LSocket := SocketFromRuntime(LRuntime);
  LSize := ASize;
  CheckEqual(Int64(0), Int64(platform_socket_setsockopt(LSocket,
    PLATFORM_SOL_SOCKET, TEST_SOCKET_SO_RCVBUF, @LSize, SizeOf(LSize))),
    'recv buffer tuning succeeds');
end;

function ReadUntilClosedOrDeadline(const AConn: ITcpStream;
  const AReadTimeoutMs: Int64; out AClosed: Boolean;
  out ATimedOut: Boolean): string;
var
  LBuf: array[0..8191] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  AClosed := False;
  ATimedOut := False;
  AConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(
    AReadTimeoutMs)));
  repeat
    try
      LN := AConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    except
      on ENetworkError do
      begin
        ATimedOut := True;
        Break;
      end;
    end;
    if LN = 0 then
    begin
      AClosed := True;
      Break;
    end;
    SetLength(Result, Length(Result) + Int32(LN));
    Move(LBuf[0], Result[Length(Result) - Int32(LN) + 1], LN);
  until False;
end;

function CountSubstring(const AText, APattern: string): Int32;
var
  LSearchStart: Int32;
  LFoundAt: Int32;
begin
  Result := 0;
  if (AText = '') or (APattern = '') then
    Exit(0);
  LSearchStart := 1;
  repeat
    LFoundAt := Pos(APattern, Copy(AText, LSearchStart, MaxInt));
    if LFoundAt <= 0 then
      Exit;
    Inc(Result);
    Inc(LSearchStart, LFoundAt + Length(APattern) - 1);
  until False;
end;

function StatusLineMatchesExpectedPrefix(const AResp,
  AExpectedStatusLine: string): Boolean;
var
  LStatusPos: Int32;
  LLineEndRel: Int32;
  LLine: string;
begin
  if AResp = '' then
    Exit(True);

  LStatusPos := Pos('HTTP/1.1', AResp);
  if LStatusPos > 0 then
  begin
    LLineEndRel := Pos(#13#10, Copy(AResp, LStatusPos, MaxInt));
    if LLineEndRel > 0 then
      LLine := Copy(AResp, LStatusPos, LLineEndRel - 1)
    else
      LLine := Copy(AResp, LStatusPos, MaxInt);
    Exit((LLine = AExpectedStatusLine) or
      (Copy(AExpectedStatusLine, 1, Length(LLine)) = LLine));
  end;

  Result := Copy(AExpectedStatusLine, 1, Length(AResp)) = AResp;
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

procedure RunTruncatedChunkedAtEofCase(const AOpts: THttpServerOptions;
  const AReq, ALabel: string);
begin
  RunSecurityRequestExpectStatus(
    AOpts,
    AReq,
    'HTTP/1.1 400',
    ALabel + ': explicit 400',
    True);
end;

{ Test 2aa: Truncated chunk extension at EOF }
procedure TestTruncatedChunkExtensionAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5;sig=abc';
begin
  RunTruncatedChunkedAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated chunk extension EOF');
end;

{ Test 2ab: Truncated chunk extension CR at EOF }
procedure TestTruncatedChunkExtensionCrAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5;sig=abc'#13;
begin
  RunTruncatedChunkedAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated chunk extension CR EOF');
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
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hel';
begin
  RunTruncatedChunkedAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated chunked request EOF');
end;

{ Test 2d: Truncated chunk-size line at EOF }
procedure TestTruncatedChunkSizeLineAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5';
begin
  RunTruncatedChunkedAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated chunk-size line EOF');
end;

{ Test 2e: Truncated terminal chunk ending at EOF }
procedure TestTruncatedTerminalChunkEndingAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10;
begin
  RunTruncatedChunkedAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated terminal chunk ending EOF');
end;

{ Test 2e0: Truncated terminal chunk ending CR at EOF }
procedure TestTruncatedTerminalChunkEndingCrAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10#13;
begin
  RunTruncatedChunkedAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated terminal chunk ending CR EOF');
end;

{ Test 2ea: Truncated terminal chunk extension at EOF }
procedure TestTruncatedTerminalChunkExtensionAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0;sig=abc';
begin
  RunTruncatedChunkedAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated terminal chunk extension EOF');
end;

{ Test 2eb: Truncated terminal chunk extension CR at EOF }
procedure TestTruncatedTerminalChunkExtensionCrAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0;sig=abc'#13;
begin
  RunTruncatedChunkedAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated terminal chunk extension CR EOF');
end;

{ Test 2ec: Truncated terminal chunk ending after extension at EOF }
procedure TestTruncatedTerminalChunkEndingAfterExtensionAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0;sig=abc'#13#10;
begin
  RunTruncatedChunkedAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated terminal chunk ending after extension EOF');
end;

{ Test 2ed: Truncated terminal chunk ending after extension CR at EOF }
procedure TestTruncatedTerminalChunkEndingAfterExtensionCrAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0;sig=abc'#13#10#13;
begin
  RunTruncatedChunkedAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated terminal chunk ending after extension CR EOF');
end;

{ Test 2f: Truncated chunk-data ending at EOF }
procedure TestTruncatedChunkDataEndingAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello';
begin
  RunTruncatedChunkedAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated chunk-data ending EOF');
end;

{ Test 2g: Truncated chunk-data CR at EOF }
procedure TestTruncatedChunkDataCrAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13;
begin
  RunTruncatedChunkedAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated chunk-data CR EOF');
end;

procedure RunFixedLengthMaxBodySizeRejected(
  const AOpts: THttpServerOptions; const ALabel: string);
var
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LBody: string;
  LReq: string;
begin
  LHandle := StartSecurityServer(AOpts, LServer, LPort);
  try
    SetLength(LBody, 2048);
    FillChar(LBody[1], 2048, Ord('A'));
    LReq := 'POST / HTTP/1.1'#13#10 +
            'Host: x'#13#10 +
            'Content-Length: 2048'#13#10 +
            'Connection: close'#13#10#13#10 +
            LBody;
    LResp := SendRaw(LPort, LReq);
    Check(Pos('HTTP/1.1 413', LResp) > 0,
      ALabel + ': explicit 413');
    Check(Pos('HTTP/1.1 200', LResp) = 0,
      ALabel + ': no success response');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestFixedLengthMaxBodySizeRejected;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.MaxBodySize := 1024;
  RunFixedLengthMaxBodySizeRejected(
    LOpts,
    'Fixed-length MaxBodySize');
end;

procedure RunChunkedMaxBodySizeRejectsBeforeTerminalChunk(
  const AOpts: THttpServerOptions; const ALabel: string);
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
  LOpts := AOpts;
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
      ALabel + ': explicit 413 before terminal chunk');
    Check(Pos('echo:', LResp) = 0,
      ALabel + ': handler response never written before terminal chunk');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 2h: Chunked MaxBodySize rejection must happen before terminal chunk }
procedure TestChunkedMaxBodySizeRejectsBeforeTerminalChunk;
begin
  RunChunkedMaxBodySizeRejectsBeforeTerminalChunk(
    THttpServerOptions.Default,
    'Chunked MaxBodySize');
end;

procedure TestChunkedMaxBodySizeRejectsBeforeTerminalChunkEpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunChunkedMaxBodySizeRejectsBeforeTerminalChunk(
    LOpts,
    'epoll chunked MaxBodySize');
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

procedure RunHeaderFieldOverMaxHeaderSizeUsesExplicit431(
  const AOpts: THttpServerOptions; const ALabel: string);
var
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LReq: string;
  LBig: string;
begin
  LHandle := StartSecurityServer(AOpts, LServer, LPort);
  try
    SetLength(LBig, 300);
    FillChar(LBig[1], 300, Ord('A'));
    LReq := 'GET / HTTP/1.1'#13#10 +
            'Host: x'#13#10 +
            'X-Big: ' + LBig + #13#10 +
            'Connection: close'#13#10#13#10;
    LResp := SendRaw(LPort, LReq);
    Check(Pos('HTTP/1.1 431', LResp) > 0,
      ALabel + ': explicit 431 for oversized header field');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHeaderFieldOverMaxHeaderSizeUsesExplicit431;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.MaxHeaderSize := 256;
  RunHeaderFieldOverMaxHeaderSizeUsesExplicit431(
    LOpts,
    'threaded header field over max-header');
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

{ Test 6: Request line too long (>8KB URL) — server stays safe even if
  request-line bytes trip the same MaxHeaderSize/431 budget path }
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
    { llhttp has no URL length limit, but transport-side MaxHeaderSize accounting
      may still reject the request-line with 431 before routing. Key: server stays safe. }
    Check((Pos('431', LResp) > 0) or (Pos('414', LResp) > 0) or
          (Pos('400', LResp) > 0) or (Pos('404', LResp) > 0) or
          (Pos('200', LResp) > 0) or (Length(LResp) = 0),
      'Long URL: server handled safely');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure RunRequestTargetOverMaxHeaderSizeUsesExplicit431(
  const AOpts: THttpServerOptions; const ALabel: string);
var
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LReq: string;
  LPath: string;
begin
  LHandle := StartSecurityServer(AOpts, LServer, LPort);
  try
    SetLength(LPath, 400);
    FillChar(LPath[1], 400, Ord('a'));
    LReq := 'GET /' + LPath + ' HTTP/1.1'#13#10 +
      'Host: x'#13#10 +
      'Connection: close'#13#10#13#10;
    LResp := SendRaw(LPort, LReq);
    Check(Pos('HTTP/1.1 431', LResp) > 0,
      ALabel + ': explicit 431 for request-target over MaxHeaderSize');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestRequestTargetOverMaxHeaderSizeUsesExplicit431;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.MaxHeaderSize := 256;
  RunRequestTargetOverMaxHeaderSizeUsesExplicit431(
    LOpts,
    'threaded request-target over max-header');
end;

procedure RunIdleTimeoutCloseSecurityCase(
  const AOpts: THttpServerOptions; const APartial: string; const ALabel: string);
var
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LBuf: array[0..1023] of Byte;
  LN: SizeUInt;
  LResp: string;
  LClosed: Boolean;
begin
  LHandle := StartSecurityServer(AOpts, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(APartial[1], SizeUInt(Length(APartial)));
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

      Check(LClosed, ALabel + ': server closed connection after timeout');
      Check(Pos('HTTP/1.1 200', LResp) = 0,
        ALabel + ': partial request must not reach success response');
      Check(Pos('echo:', LResp) = 0,
        ALabel + ': partial request must not reach echo handler');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 7: Slowloris — partial request, server should timeout and close }
procedure TestSlowloris;
var
  LOpts: THttpServerOptions;
const
  PARTIAL = 'GET / HTTP/1.1'#13#10;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.IdleTimeout := 1000; { 1 second idle timeout }
  RunIdleTimeoutCloseSecurityCase(LOpts, PARTIAL, 'Slowloris');
end;

procedure TestPartialFixedLengthBodyIdleTimeout;
var
  LOpts: THttpServerOptions;
const
  PARTIAL =
    'POST / HTTP/1.1'#13#10 +
    'Host: x'#13#10 +
    'Content-Length: 5'#13#10 +
    'Connection: close'#13#10#13#10 +
    'ab';
begin
  LOpts := THttpServerOptions.Default;
  LOpts.IdleTimeout := 200;
  RunIdleTimeoutCloseSecurityCase(
    LOpts,
    PARTIAL,
    'Partial fixed-length body idle-timeout');
end;

procedure TestPartialChunkSizeLineIdleTimeout;
var
  LOpts: THttpServerOptions;
const
  PARTIAL =
    'POST / HTTP/1.1'#13#10 +
    'Host: x'#13#10 +
    'Transfer-Encoding: chunked'#13#10 +
    'Connection: close'#13#10#13#10 +
    'A';
begin
  LOpts := THttpServerOptions.Default;
  LOpts.IdleTimeout := 200;
  RunIdleTimeoutCloseSecurityCase(
    LOpts,
    PARTIAL,
    'Partial chunk-size line idle-timeout');
end;

procedure TestPartialChunkedTrailerIdleTimeout;
var
  LOpts: THttpServerOptions;
const
  PARTIAL =
    'POST / HTTP/1.1'#13#10 +
    'Host: x'#13#10 +
    'Transfer-Encoding: chunked'#13#10 +
    'Trailer: X-Test'#13#10 +
    'Connection: close'#13#10#13#10 +
    '3'#13#10 +
    'abc'#13#10 +
    '0'#13#10 +
    'X-Test: value'#13#10;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.IdleTimeout := 200;
  RunIdleTimeoutCloseSecurityCase(
    LOpts,
    PARTIAL,
    'Partial chunked trailer idle-timeout');
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

procedure RunDirectErrorBackpressureSafeHandling(const AOpts: THttpServerOptions;
  const AReq, AExpectedStatusLine, ALabel: string);
var
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LTransport: IHttpServerTransport;
  LH1Opts: TH1ServerTransportOptions;
  LResp: string;
  LClosed: Boolean;
  LTimedOut: Boolean;
const
  RECV_BUFFER_BYTES = 1024;
  SEND_BUFFER_BYTES = 1024;
  BACKPRESSURE_WAIT_NS = 500000000;
  CLOSE_WAIT_MS = 5000;
begin
  LH1Opts := DefaultH1ServerTransportOptions(AOpts);
  LTransport := TSocketTuningServerTransport.Create(
    NewH1ServerTransport(LH1Opts), SEND_BUFFER_BYTES);
  LHandle := StartSecurityServerWithTransportAndOptions(
    nil, LTransport, AOpts, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      SetSocketRecvBuffer(LConn, RECV_BUFFER_BYTES);
      if AReq <> '' then
        LConn.Write(AReq[1], SizeUInt(Length(AReq)));
      platform_thread_sleep_ns(BACKPRESSURE_WAIT_NS);

      LResp := ReadUntilClosedOrDeadline(LConn, CLOSE_WAIT_MS, LClosed, LTimedOut);

      Check(LClosed,
        ALabel + ': connection closes within observation window');
      Check(not LTimedOut,
        ALabel + ': close does not overrun read deadline');
      Check(Pos('HTTP/1.1 200 OK', LResp) = 0,
        ALabel + ': malformed request never reaches success response');
      Check(Pos('HTTP/1.1 500', LResp) = 0,
        ALabel + ': malformed request does not append synthetic 500');
      Check(CountSubstring(LResp, 'HTTP/1.1 ') <= 1,
        ALabel + ': wire never exposes more than one status line');
      Check(StatusLineMatchesExpectedPrefix(LResp, AExpectedStatusLine),
        ALabel + ': wire bytes stay within expected direct-error status prefix');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

function BuildChunkedOversizeTrailerRequest: string; forward;

procedure TestMalformedRequestBackpressureSafeHandling;
const
  REQ = 'GARBAGE DATA HERE'#13#10#13#10;
begin
  RunDirectErrorBackpressureSafeHandling(
    THttpServerOptions.Default,
    REQ,
    'HTTP/1.1 400 Bad Request',
    'Malformed direct error backpressure');
end;

procedure TestUnsupportedTransferCodingBackpressureSafeHandling;
const
  REQ =
    'POST /unsupported HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Transfer-Encoding: gzip, chunked'#13#10 +
    'Connection: close'#13#10#13#10 +
    '5'#13#10'hello'#13#10 +
    '0'#13#10#13#10;
begin
  RunDirectErrorBackpressureSafeHandling(
    THttpServerOptions.Default,
    REQ,
    'HTTP/1.1 501 Not Implemented',
    'Unsupported transfer-coding direct error backpressure');
end;

procedure TestChunkedOversizeTrailerBackpressureSafeHandling;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.MaxHeaderSize := 256;
  RunDirectErrorBackpressureSafeHandling(
    LOpts,
    BuildChunkedOversizeTrailerRequest,
    'HTTP/1.1 431 Request Header Fields Too Large',
    'Oversize trailer direct error backpressure');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestMalformedRequestBackpressureSafeHandlingEpollBackend;
var
  LOpts: THttpServerOptions;
const
  REQ = 'GARBAGE DATA HERE'#13#10#13#10;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunDirectErrorBackpressureSafeHandling(
    LOpts,
    REQ,
    'HTTP/1.1 400 Bad Request',
    'epoll malformed direct error backpressure');
end;

procedure TestUnsupportedTransferCodingBackpressureSafeHandlingEpollBackend;
var
  LOpts: THttpServerOptions;
const
  REQ =
    'POST /unsupported HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Transfer-Encoding: gzip, chunked'#13#10 +
    'Connection: close'#13#10#13#10 +
    '5'#13#10'hello'#13#10 +
    '0'#13#10#13#10;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunDirectErrorBackpressureSafeHandling(
    LOpts,
    REQ,
    'HTTP/1.1 501 Not Implemented',
    'epoll unsupported transfer-coding direct error backpressure');
end;

procedure TestChunkedOversizeTrailerBackpressureSafeHandlingEpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.MaxHeaderSize := 256;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunDirectErrorBackpressureSafeHandling(
    LOpts,
    BuildChunkedOversizeTrailerRequest,
    'HTTP/1.1 431 Request Header Fields Too Large',
    'epoll oversize trailer direct error backpressure');
end;
{$ENDIF}

{ Test 14a: Keep-alive Content-Length request with garbage tail }
procedure RunContentLengthKeepAliveGarbageTailSafeHandling(
  const AOpts: THttpServerOptions; const ALabel: string);
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 5'#13#10#13#10 +
            'hello_extra_bytes_here';
begin
  LHandle := StartSecurityServer(AOpts, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0,
      ALabel + ': first response still completes');
    Check(Pos('echo:5', LResp) > 0,
      ALabel + ': first request body handled correctly');
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      ALabel + ': malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestContentLengthKeepAliveGarbageTailSafeHandling;
begin
  RunContentLengthKeepAliveGarbageTailSafeHandling(
    THttpServerOptions.Default,
    'Keep-alive Content-Length tail');
end;

{ Test 14aa: Keep-alive Content-Length request with truncated follow-up request line }
procedure RunContentLengthKeepAliveTruncatedFollowUpRequestLineSafeHandling(
  const AOpts: THttpServerOptions; const ALabel: string);
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 5'#13#10#13#10 +
            'hello' +
            'GET /next HTTP/1.1';
begin
  LHandle := StartSecurityServer(AOpts, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0,
      ALabel + ': first response still completes');
    Check(Pos('echo:5', LResp) > 0,
      ALabel + ': first request body handled correctly');
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      ALabel + ': malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestContentLengthKeepAliveTruncatedFollowUpRequestLineSafeHandling;
begin
  RunContentLengthKeepAliveTruncatedFollowUpRequestLineSafeHandling(
    THttpServerOptions.Default,
    'Keep-alive Content-Length partial follow-up line');
end;

procedure RunContentLengthKeepAlivePartialFollowUpRequestLineCanCompleteLater(
  const AOpts: THttpServerOptions; const ALabel: string);
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

procedure TestContentLengthKeepAlivePartialFollowUpRequestLineCanCompleteLater;
begin
  RunContentLengthKeepAlivePartialFollowUpRequestLineCanCompleteLater(
    THttpServerOptions.Default,
    'Keep-alive Content-Length partial-next-line');
end;

procedure RunContentLengthKeepAlivePartialFollowUpHeadersCanCompleteLater(
  const AOpts: THttpServerOptions; const ALabel: string);
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
         'GET / HTTP/1.1'#13#10 +
         'Host: x'#13#10;
  REQ2_REST = 'Connection: close'#13#10#13#10;
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

procedure TestContentLengthKeepAlivePartialFollowUpHeadersCanCompleteLater;
begin
  RunContentLengthKeepAlivePartialFollowUpHeadersCanCompleteLater(
    THttpServerOptions.Default,
    'Keep-alive Content-Length partial-next-headers');
end;

{ Test 14ab: Keep-alive Content-Length request with truncated follow-up headers }
procedure RunContentLengthKeepAliveTruncatedFollowUpHeadersSafeHandling(
  const AOpts: THttpServerOptions; const ALabel: string);
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 5'#13#10#13#10 +
            'hello' +
            'GET /next HTTP/1.1'#13#10 +
            'Host: x'#13#10;
begin
  LHandle := StartSecurityServer(AOpts, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0,
      ALabel + ': first response still completes');
    Check(Pos('echo:5', LResp) > 0,
      ALabel + ': first request body handled correctly');
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      ALabel + ': malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestContentLengthKeepAliveTruncatedFollowUpHeadersSafeHandling;
begin
  RunContentLengthKeepAliveTruncatedFollowUpHeadersSafeHandling(
    THttpServerOptions.Default,
    'Keep-alive Content-Length partial follow-up headers');
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
procedure RunChunkedKeepAliveGarbageTailSafeHandling(
  const AOpts: THttpServerOptions; const ALabel: string);
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10#13#10 +
            'garbage';
begin
  LHandle := StartSecurityServer(AOpts, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0,
      ALabel + ': first response still completes');
    Check(Pos('echo:5', LResp) > 0,
      ALabel + ': first request body handled correctly');
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      ALabel + ': malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedKeepAliveGarbageTailSafeHandling;
begin
  RunChunkedKeepAliveGarbageTailSafeHandling(
    THttpServerOptions.Default,
    'Keep-alive chunked tail');
end;

{ Test 14ca: Keep-alive chunked request with truncated follow-up request line }
procedure RunChunkedKeepAliveTruncatedFollowUpRequestLineSafeHandling(
  const AOpts: THttpServerOptions; const ALabel: string);
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10#13#10 +
            'GET /next HTTP/1.1';
begin
  LHandle := StartSecurityServer(AOpts, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0,
      ALabel + ': first response still completes');
    Check(Pos('echo:5', LResp) > 0,
      ALabel + ': first request body handled correctly');
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      ALabel + ': malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedKeepAliveTruncatedFollowUpRequestLineSafeHandling;
begin
  RunChunkedKeepAliveTruncatedFollowUpRequestLineSafeHandling(
    THttpServerOptions.Default,
    'Keep-alive chunked partial follow-up line');
end;

procedure RunChunkedKeepAlivePartialFollowUpRequestLineCanCompleteLater(
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
         'Transfer-Encoding: chunked'#13#10#13#10 +
         '5'#13#10'hello'#13#10 +
         '0'#13#10#13#10 +
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

procedure TestChunkedKeepAlivePartialFollowUpRequestLineCanCompleteLater;
begin
  RunChunkedKeepAlivePartialFollowUpRequestLineCanCompleteLater(
    THttpServerOptions.Default,
    'Keep-alive chunked partial-next-line');
end;

procedure RunChunkedKeepAlivePartialFollowUpHeadersCanCompleteLater(
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
         'Transfer-Encoding: chunked'#13#10#13#10 +
         '5'#13#10'hello'#13#10 +
         '0'#13#10#13#10 +
         'GET / HTTP/1.1'#13#10 +
         'Host: x'#13#10;
  REQ2_REST = 'Connection: close'#13#10#13#10;
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

procedure TestChunkedKeepAlivePartialFollowUpHeadersCanCompleteLater;
begin
  RunChunkedKeepAlivePartialFollowUpHeadersCanCompleteLater(
    THttpServerOptions.Default,
    'Keep-alive chunked partial-next-headers');
end;

{ Test 14cb: Keep-alive chunked request with truncated follow-up headers }
procedure RunChunkedKeepAliveTruncatedFollowUpHeadersSafeHandling(
  const AOpts: THttpServerOptions; const ALabel: string);
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10#13#10 +
            'GET /next HTTP/1.1'#13#10 +
            'Host: x'#13#10;
begin
  LHandle := StartSecurityServer(AOpts, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0,
      ALabel + ': first response still completes');
    Check(Pos('echo:5', LResp) > 0,
      ALabel + ': first request body handled correctly');
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      ALabel + ': malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedKeepAliveTruncatedFollowUpHeadersSafeHandling;
begin
  RunChunkedKeepAliveTruncatedFollowUpHeadersSafeHandling(
    THttpServerOptions.Default,
    'Keep-alive chunked partial follow-up headers');
end;

{ Test 14cc: Keep-alive chunked trailer-complete request with garbage tail }
procedure RunChunkedTrailerKeepAliveGarbageTailSafeHandling(
  const AOpts: THttpServerOptions; const ALabel: string);
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: value'#13#10#13#10 +
            'garbage';
begin
  LHandle := StartSecurityServer(AOpts, LServer, LPort);
  try
    LResp := SendRaw(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0,
      ALabel + ': first response still completes');
    Check(Pos('echo:5', LResp) > 0,
      ALabel + ': first request body handled correctly');
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      ALabel + ': malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedTrailerKeepAliveGarbageTailSafeHandling;
begin
  RunChunkedTrailerKeepAliveGarbageTailSafeHandling(
    THttpServerOptions.Default,
    'Keep-alive chunked trailer tail');
end;

{ Test 14cd: Keep-alive chunked trailer-complete request with truncated follow-up request line }
procedure RunChunkedTrailerKeepAliveTruncatedFollowUpRequestLineSafeHandling(
  const AOpts: THttpServerOptions; const ALabel: string);
var LServer: THttpServer; LPort: UInt16; LHandle: TPlatformThreadHandle; LResp: string;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: value'#13#10#13#10 +
            'GET /next HTTP/1.1';
begin
  LHandle := StartSecurityServer(AOpts, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0,
      ALabel + ': first response still completes');
    Check(Pos('echo:5', LResp) > 0,
      ALabel + ': first request body handled correctly');
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      ALabel + ': malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedTrailerKeepAliveTruncatedFollowUpRequestLineSafeHandling;
begin
  RunChunkedTrailerKeepAliveTruncatedFollowUpRequestLineSafeHandling(
    THttpServerOptions.Default,
    'Keep-alive chunked trailer partial follow-up line');
end;

{ Test 14ce: Keep-alive chunked trailer-complete request with truncated follow-up headers }
procedure RunChunkedTrailerKeepAliveTruncatedFollowUpHeadersSafeHandling(
  const AOpts: THttpServerOptions; const ALabel: string);
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
  LHandle := StartSecurityServer(AOpts, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0,
      ALabel + ': first response still completes');
    Check(Pos('echo:5', LResp) > 0,
      ALabel + ': first request body handled correctly');
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      ALabel + ': malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedTrailerKeepAliveTruncatedFollowUpHeadersSafeHandling;
begin
  RunChunkedTrailerKeepAliveTruncatedFollowUpHeadersSafeHandling(
    THttpServerOptions.Default,
    'Keep-alive chunked trailer partial follow-up headers');
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

procedure RunChunkedTrailerPartialFollowUpHeadersCanCompleteLater(
  const AOpts: THttpServerOptions; const ALabel: string);
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
         'GET /next HTTP/1.1'#13#10 +
         'Host: localhost'#13#10;
  REQ2_REST = 'Connection: close'#13#10#13#10;
begin
  LSeenUpload := False;
  LSeenNext := False;
  LGotBody := '';
  LGotTrailerDecl := '';
  LGotTrailerValue := '';
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
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
  LRouter.Get('/next', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LSeenNext := True;
    LBody := 'next';
    AW.GetHeaders.Set_('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartSecurityServerWithTransportAndOptions(
    LRouter as IHttpHandler, nil, AOpts, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ1[1], SizeUInt(Length(REQ1)));
      LResp1 := ReadOneResponse(LConn);
      Check(Pos('HTTP/1.1 200', LResp1) > 0,
        ALabel + ': first response still completes');
      Check(Pos('upload:hello', LResp1) > 0,
        ALabel + ': first request body handled correctly');
      Check(LSeenUpload, ALabel + ': first handler called');
      CheckEqual('hello', LGotBody, ALabel + ': handler sees decoded body only');
      CheckEqual('X-Test', LGotTrailerDecl,
        ALabel + ': trailer declaration preserved');
      CheckEqual('', LGotTrailerValue,
        ALabel + ': trailer field not exposed as regular header');

      LConn.Write(REQ2_REST[1], SizeUInt(Length(REQ2_REST)));
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('HTTP/1.1 200', LResp2) > 0,
        ALabel + ': completed follow-up request returns 200');
      Check(Pos('next', LResp2) > 0,
        ALabel + ': second request body preserved');
      Check(LSeenNext, ALabel + ': second handler called');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedTrailerPartialFollowUpHeadersCanCompleteLater;
begin
  RunChunkedTrailerPartialFollowUpHeadersCanCompleteLater(
    THttpServerOptions.Default,
    'Keep-alive chunked trailer partial-next-headers');
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

procedure TestChunkedTrailerPartialFollowUpHeadersCanCompleteLaterEpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunChunkedTrailerPartialFollowUpHeadersCanCompleteLater(
    LOpts,
    'epoll keep-alive chunked trailer partial-next-headers');
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

procedure TestChunkedTrailerKeepAliveTruncatedFollowUpHeadersSafeHandlingEpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunChunkedTrailerKeepAliveTruncatedFollowUpHeadersSafeHandling(
    LOpts,
    'epoll keep-alive chunked trailer partial follow-up headers');
end;

procedure TestChunkedTrailerKeepAliveGarbageTailSafeHandlingEpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunChunkedTrailerKeepAliveGarbageTailSafeHandling(
    LOpts,
    'epoll keep-alive chunked trailer tail');
end;

procedure TestChunkedTrailerKeepAliveTruncatedFollowUpRequestLineSafeHandlingEpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunChunkedTrailerKeepAliveTruncatedFollowUpRequestLineSafeHandling(
    LOpts,
    'epoll keep-alive chunked trailer partial follow-up line');
end;

procedure TestChunkedKeepAliveTruncatedFollowUpHeadersSafeHandlingEpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunChunkedKeepAliveTruncatedFollowUpHeadersSafeHandling(
    LOpts,
    'epoll keep-alive chunked partial follow-up headers');
end;

procedure TestChunkedKeepAliveGarbageTailSafeHandlingEpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunChunkedKeepAliveGarbageTailSafeHandling(
    LOpts,
    'epoll keep-alive chunked tail');
end;

procedure TestChunkedKeepAliveTruncatedFollowUpRequestLineSafeHandlingEpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunChunkedKeepAliveTruncatedFollowUpRequestLineSafeHandling(
    LOpts,
    'epoll keep-alive chunked partial follow-up line');
end;

procedure TestChunkedKeepAlivePartialFollowUpRequestLineCanCompleteLaterEpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunChunkedKeepAlivePartialFollowUpRequestLineCanCompleteLater(
    LOpts,
    'epoll keep-alive chunked partial-next-line');
end;

procedure TestChunkedKeepAlivePartialFollowUpHeadersCanCompleteLaterEpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunChunkedKeepAlivePartialFollowUpHeadersCanCompleteLater(
    LOpts,
    'epoll keep-alive chunked partial-next-headers');
end;

procedure TestContentLengthKeepAlivePartialFollowUpRequestLineCanCompleteLaterEpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunContentLengthKeepAlivePartialFollowUpRequestLineCanCompleteLater(
    LOpts,
    'epoll keep-alive Content-Length partial-next-line');
end;

procedure TestContentLengthKeepAlivePartialFollowUpHeadersCanCompleteLaterEpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunContentLengthKeepAlivePartialFollowUpHeadersCanCompleteLater(
    LOpts,
    'epoll keep-alive Content-Length partial-next-headers');
end;

procedure TestContentLengthKeepAliveTruncatedFollowUpHeadersSafeHandlingEpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunContentLengthKeepAliveTruncatedFollowUpHeadersSafeHandling(
    LOpts,
    'epoll keep-alive Content-Length partial follow-up headers');
end;

procedure TestContentLengthKeepAliveGarbageTailSafeHandlingEpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunContentLengthKeepAliveGarbageTailSafeHandling(
    LOpts,
    'epoll keep-alive Content-Length tail');
end;

procedure TestContentLengthKeepAliveTruncatedFollowUpRequestLineSafeHandlingEpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunContentLengthKeepAliveTruncatedFollowUpRequestLineSafeHandling(
    LOpts,
    'epoll keep-alive Content-Length partial follow-up line');
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

function BuildChunkedOversizeTrailerRequest: string;
var
  LTrailerValue: string;
begin
  SetLength(LTrailerValue, 300);
  FillChar(LTrailerValue[1], 300, Ord('x'));
  Result := 'POST / HTTP/1.1'#13#10 +
            'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Big'#13#10 +
            'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Big: ' + LTrailerValue + #13#10#13#10;
end;

procedure RunChunkedOversizeTrailerUsesMaxHeaderSize(
  const AOpts: THttpServerOptions; const ALabel: string);
var
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LHandle := StartSecurityServer(AOpts, LServer, LPort);
  try
    LResp := SendRaw(LPort, BuildChunkedOversizeTrailerRequest);
    Check(Pos('HTTP/1.1 431', LResp) > 0,
      ALabel + ': explicit 431');
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

procedure RunTruncatedTrailerAtEofCase(
  const AOpts: THttpServerOptions; const AReq: string; const ALabel: string);
var
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LHandle := StartSecurityServer(AOpts, LServer, LPort);
  try
    LResp := SendRawAndShutdownWrite(LPort, AReq);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      ALabel + ': explicit 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 18: Truncated trailer section at EOF }
procedure TestTruncatedTrailerAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: value'#13#10;
begin
  RunTruncatedTrailerAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated trailer EOF');
end;

{ Test 18a: Truncated trailer field-name at EOF }
procedure TestTruncatedTrailerFieldNameAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test';
begin
  RunTruncatedTrailerAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated trailer field-name EOF');
end;

{ Test 18b: Truncated trailer separator at EOF }
procedure TestTruncatedTrailerSeparatorAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test:';
begin
  RunTruncatedTrailerAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated trailer separator EOF');
end;

{ Test 18c: Truncated trailer empty-value CR at EOF }
procedure TestTruncatedTrailerEmptyValueCrAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test:'#13;
begin
  RunTruncatedTrailerAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated trailer empty-value CR EOF');
end;

{ Test 18d: Truncated trailer empty-value at EOF }
procedure TestTruncatedTrailerEmptyValueAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test:'#13#10;
begin
  RunTruncatedTrailerAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated trailer empty-value EOF');
end;

{ Test 18e: Truncated trailer empty-value section CR at EOF }
procedure TestTruncatedTrailerEmptyValueSectionCrAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test:'#13#10#13;
begin
  RunTruncatedTrailerAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated trailer empty-value section CR EOF');
end;

{ Test 18c: Truncated trailer whitespace at EOF }
procedure TestTruncatedTrailerWhitespaceAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: ';
begin
  RunTruncatedTrailerAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated trailer whitespace EOF');
end;

{ Test 18d: Truncated trailer whitespace CR at EOF }
procedure TestTruncatedTrailerWhitespaceCrAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: '#13;
begin
  RunTruncatedTrailerAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated trailer whitespace CR EOF');
end;

{ Test 18e: Truncated trailer whitespace section at EOF }
procedure TestTruncatedTrailerWhitespaceSectionAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: '#13#10;
begin
  RunTruncatedTrailerAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated trailer whitespace section EOF');
end;

{ Test 18f: Truncated trailer whitespace section CR at EOF }
procedure TestTruncatedTrailerWhitespaceSectionCrAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: '#13#10#13;
begin
  RunTruncatedTrailerAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated trailer whitespace section CR EOF');
end;

{ Test 18a: Truncated trailer field line at EOF }
procedure TestTruncatedTrailerFieldLineAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: value';
begin
  RunTruncatedTrailerAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated trailer field line EOF');
end;

{ Test 18b: Truncated trailer field CR at EOF }
procedure TestTruncatedTrailerFieldCrAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: value'#13;
begin
  RunTruncatedTrailerAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated trailer field CR EOF');
end;

{ Test 18a: Truncated trailer section CR at EOF }
procedure TestTruncatedTrailerCrAtEof;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: value'#13#10#13;
begin
  RunTruncatedTrailerAtEofCase(
    THttpServerOptions.Default,
    REQ,
    'Truncated trailer CR EOF');
end;

{$IFDEF NEXTPAS_LINUX}
function EpollSecurityServerOptions: THttpServerOptions;
begin
  Result := THttpServerOptions.Default;
  Result.Backend := TCP_SERVER_BACKEND_EPOLL;
end;

procedure TestFixedLengthMaxBodySizeRejectedEpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := EpollSecurityServerOptions;
  LOpts.MaxBodySize := 1024;
  RunFixedLengthMaxBodySizeRejected(
    LOpts,
    'epoll fixed-length MaxBodySize');
end;

procedure TestHeaderFieldOverMaxHeaderSizeUsesExplicit431EpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := EpollSecurityServerOptions;
  LOpts.MaxHeaderSize := 256;
  RunHeaderFieldOverMaxHeaderSizeUsesExplicit431(
    LOpts,
    'epoll header field over max-header');
end;

procedure TestRequestTargetOverMaxHeaderSizeUsesExplicit431EpollBackend;
var
  LOpts: THttpServerOptions;
begin
  LOpts := EpollSecurityServerOptions;
  LOpts.MaxHeaderSize := 256;
  RunRequestTargetOverMaxHeaderSizeUsesExplicit431(
    LOpts,
    'epoll request-target over max-header');
end;

procedure TestContentLengthTransferEncodingConflictEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 5'#13#10 +
            'Transfer-Encoding: chunked'#13#10#13#10'0'#13#10#13#10;
begin
  RunSecurityRequestExpectStatus(
    EpollSecurityServerOptions,
    REQ,
    'HTTP/1.1 400',
    'epoll CL+TE conflict: explicit 400');
end;

procedure TestTransferEncodingContentLengthConflictReverseOrderEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Content-Length: 5'#13#10#13#10'0'#13#10#13#10;
begin
  RunSecurityRequestExpectStatus(
    EpollSecurityServerOptions,
    REQ,
    'HTTP/1.1 400',
    'epoll TE+CL reverse-order conflict: explicit 400');
end;

procedure TestDuplicateContentLengthEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 5'#13#10 +
            'Content-Length: 10'#13#10'Connection: close'#13#10#13#10'hello';
begin
  RunSecurityRequestExpectStatus(
    EpollSecurityServerOptions,
    REQ,
    'HTTP/1.1 400',
    'epoll duplicate Content-Length: explicit 400');
end;

procedure TestNegativeContentLengthEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: -1'#13#10 +
            'Connection: close'#13#10#13#10'hello';
begin
  RunSecurityRequestExpectStatus(
    EpollSecurityServerOptions,
    REQ,
    'HTTP/1.1 400',
    'epoll negative Content-Length: explicit 400');
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

procedure TestChunkedMustBeFinalTransferCodingEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked, gzip'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10#13#10;
begin
  RunSecurityRequestExpectStatus(
    EpollSecurityServerOptions,
    REQ,
    'HTTP/1.1 400',
    'epoll chunked must be final transfer coding: explicit 400');
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

procedure TestMalformedChunkExtensionEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5;'#13#10'hello'#13#10 +
            '0'#13#10#13#10;
begin
  RunSecurityRequestExpectStatus(
    EpollSecurityServerOptions,
    REQ,
    'HTTP/1.1 400',
    'epoll malformed chunk extension: explicit 400');
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

procedure TestChunkedExtraBytesAfterCloseEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10#13#10 +
            'garbage';
begin
  RunSecurityRequestExpectStatus(
    EpollSecurityServerOptions,
    REQ,
    'HTTP/1.1 400',
    'epoll chunked extra bytes after close: explicit 400');
end;

procedure TestMalformedTrailerFieldEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Bad'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'Bad Header: value'#13#10#13#10;
begin
  RunSecurityRequestExpectStatus(
    EpollSecurityServerOptions,
    REQ,
    'HTTP/1.1 400',
    'epoll malformed trailer field: explicit 400');
end;

procedure TestTruncatedChunkExtensionAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5;sig=abc';
begin
  RunTruncatedChunkedAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated chunk extension EOF');
end;

procedure TestTruncatedChunkExtensionCrAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5;sig=abc'#13;
begin
  RunTruncatedChunkedAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated chunk extension CR EOF');
end;

procedure TestTruncatedChunkedRequestAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hel';
begin
  RunTruncatedChunkedAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated chunked request EOF');
end;

procedure TestTruncatedChunkSizeLineAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5';
begin
  RunTruncatedChunkedAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated chunk-size line EOF');
end;

procedure TestTruncatedTerminalChunkEndingAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10;
begin
  RunTruncatedChunkedAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated terminal chunk ending EOF');
end;

procedure TestTruncatedTerminalChunkEndingCrAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10#13;
begin
  RunTruncatedChunkedAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated terminal chunk ending CR EOF');
end;

procedure TestTruncatedTerminalChunkExtensionAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0;sig=abc';
begin
  RunTruncatedChunkedAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated terminal chunk extension EOF');
end;

procedure TestTruncatedTerminalChunkExtensionCrAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0;sig=abc'#13;
begin
  RunTruncatedChunkedAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated terminal chunk extension CR EOF');
end;

procedure TestTruncatedTerminalChunkEndingAfterExtensionAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0;sig=abc'#13#10;
begin
  RunTruncatedChunkedAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated terminal chunk ending after extension EOF');
end;

procedure TestTruncatedTerminalChunkEndingAfterExtensionCrAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0;sig=abc'#13#10#13;
begin
  RunTruncatedChunkedAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated terminal chunk ending after extension CR EOF');
end;

procedure TestTruncatedChunkDataEndingAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello';
begin
  RunTruncatedChunkedAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated chunk-data ending EOF');
end;

procedure TestTruncatedChunkDataCrAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13;
begin
  RunTruncatedChunkedAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated chunk-data CR EOF');
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

procedure TestTruncatedTrailerAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: value'#13#10;
begin
  RunTruncatedTrailerAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated trailer EOF');
end;

procedure TestTruncatedTrailerFieldNameAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test';
begin
  RunTruncatedTrailerAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated trailer field-name EOF');
end;

procedure TestTruncatedTrailerSeparatorAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test:';
begin
  RunTruncatedTrailerAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated trailer separator EOF');
end;

procedure TestTruncatedTrailerEmptyValueCrAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test:'#13;
begin
  RunTruncatedTrailerAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated trailer empty-value CR EOF');
end;

procedure TestTruncatedTrailerEmptyValueAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test:'#13#10;
begin
  RunTruncatedTrailerAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated trailer empty-value EOF');
end;

procedure TestTruncatedTrailerEmptyValueSectionCrAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test:'#13#10#13;
begin
  RunTruncatedTrailerAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated trailer empty-value section CR EOF');
end;

procedure TestTruncatedTrailerWhitespaceAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: ';
begin
  RunTruncatedTrailerAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated trailer whitespace EOF');
end;

procedure TestTruncatedTrailerWhitespaceCrAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: '#13;
begin
  RunTruncatedTrailerAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated trailer whitespace CR EOF');
end;

procedure TestTruncatedTrailerWhitespaceSectionAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: '#13#10;
begin
  RunTruncatedTrailerAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated trailer whitespace section EOF');
end;

procedure TestTruncatedTrailerWhitespaceSectionCrAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: '#13#10#13;
begin
  RunTruncatedTrailerAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated trailer whitespace section CR EOF');
end;

procedure TestTruncatedTrailerFieldLineAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: value';
begin
  RunTruncatedTrailerAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated trailer field line EOF');
end;

procedure TestTruncatedTrailerFieldCrAtEofEpollBackend;
const REQ = 'POST / HTTP/1.1'#13#10'Host: x'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Test'#13#10'Connection: close'#13#10#13#10 +
            '5'#13#10'hello'#13#10 +
            '0'#13#10 +
            'X-Test: value'#13;
begin
  RunTruncatedTrailerAtEofCase(
    EpollSecurityServerOptions,
    REQ,
    'epoll truncated trailer field CR EOF');
end;

procedure TestSlowlorisEpollBackend;
const
  PARTIAL = 'GET / HTTP/1.1'#13#10;
var
  LOpts: THttpServerOptions;
begin
  LOpts := EpollSecurityServerOptions;
  LOpts.IdleTimeout := 1000;
  RunIdleTimeoutCloseSecurityCase(
    LOpts,
    PARTIAL,
    'epoll slowloris');
end;

procedure TestPartialFixedLengthBodyIdleTimeoutEpollBackend;
const
  PARTIAL =
    'POST / HTTP/1.1'#13#10 +
    'Host: x'#13#10 +
    'Content-Length: 5'#13#10 +
    'Connection: close'#13#10#13#10 +
    'ab';
var
  LOpts: THttpServerOptions;
begin
  LOpts := EpollSecurityServerOptions;
  LOpts.IdleTimeout := 200;
  RunIdleTimeoutCloseSecurityCase(
    LOpts,
    PARTIAL,
    'epoll partial fixed-length body idle-timeout');
end;

procedure TestPartialChunkSizeLineIdleTimeoutEpollBackend;
const
  PARTIAL =
    'POST / HTTP/1.1'#13#10 +
    'Host: x'#13#10 +
    'Transfer-Encoding: chunked'#13#10 +
    'Connection: close'#13#10#13#10 +
    'A';
var
  LOpts: THttpServerOptions;
begin
  LOpts := EpollSecurityServerOptions;
  LOpts.IdleTimeout := 200;
  RunIdleTimeoutCloseSecurityCase(
    LOpts,
    PARTIAL,
    'epoll partial chunk-size line idle-timeout');
end;

procedure TestPartialChunkedTrailerIdleTimeoutEpollBackend;
const
  PARTIAL =
    'POST / HTTP/1.1'#13#10 +
    'Host: x'#13#10 +
    'Transfer-Encoding: chunked'#13#10 +
    'Trailer: X-Test'#13#10 +
    'Connection: close'#13#10#13#10 +
    '3'#13#10 +
    'abc'#13#10 +
    '0'#13#10 +
    'X-Test: value'#13#10;
var
  LOpts: THttpServerOptions;
begin
  LOpts := EpollSecurityServerOptions;
  LOpts.IdleTimeout := 200;
  RunIdleTimeoutCloseSecurityCase(
    LOpts,
    PARTIAL,
    'epoll partial chunked trailer idle-timeout');
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
  T.Run('Fixed-length MaxBodySize -> 413', @TestFixedLengthMaxBodySizeRejected);
  T.Run('Chunked MaxBodySize rejects before terminal chunk',
    @TestChunkedMaxBodySizeRejectsBeforeTerminalChunk);
  T.Run('Generic malformed request -> 400', @TestGenericMalformedRequest);
  T.Run('Duplicate Content-Length -> 400', @TestDuplicateContentLength);
  T.Run('Oversized header >8KB', @TestOversizedHeader);
  T.Run('Header field over MaxHeaderSize -> explicit 431',
    @TestHeaderFieldOverMaxHeaderSizeUsesExplicit431);
  T.Run('Null byte in header -> 400', @TestHeaderNullByte);
  T.Run('Request line too long', @TestRequestLineTooLong);
  T.Run('Request-target over MaxHeaderSize -> explicit 431',
    @TestRequestTargetOverMaxHeaderSizeUsesExplicit431);
  T.Run('Slowloris partial request', @TestSlowloris);
  T.Run('Partial fixed-length body idle-timeout closes connection',
    @TestPartialFixedLengthBodyIdleTimeout);
  T.Run('Partial chunk-size line idle-timeout closes connection',
    @TestPartialChunkSizeLineIdleTimeout);
  T.Run('Partial chunked trailer idle-timeout closes connection',
    @TestPartialChunkedTrailerIdleTimeout);
  T.Run('HTTP/0.9 no version -> 400', @TestHttp09Request);
  T.Run('CRLF injection in path -> 400', @TestCrlfInjection);
  T.Run('Missing Host header -> 400', @TestMissingHost);
  T.Run('Request line truncated at EOF -> 400', @TestRequestLineTruncatedAtEof);
  T.Run('Headers truncated at EOF -> 400', @TestHeadersTruncatedAtEof);
  T.Run('Very long method name -> 400', @TestLongMethodName);
  T.Run('Body larger than CL with Connection: close -> 400', @TestBodyLargerThanContentLength);
  T.Run('Malformed direct error backpressure safe handling',
    @TestMalformedRequestBackpressureSafeHandling);
  T.Run('Unsupported transfer-coding direct error backpressure safe handling',
    @TestUnsupportedTransferCodingBackpressureSafeHandling);
  T.Run('Chunked oversize trailer direct error backpressure safe handling',
    @TestChunkedOversizeTrailerBackpressureSafeHandling);
  T.Run('Content-Length keep-alive garbage tail safe handling', @TestContentLengthKeepAliveGarbageTailSafeHandling);
  T.Run('Content-Length keep-alive truncated follow-up request line safe handling',
    @TestContentLengthKeepAliveTruncatedFollowUpRequestLineSafeHandling);
  T.Run('Content-Length keep-alive partial follow-up request line can complete later',
    @TestContentLengthKeepAlivePartialFollowUpRequestLineCanCompleteLater);
  T.Run('Content-Length keep-alive partial follow-up headers can complete later',
    @TestContentLengthKeepAlivePartialFollowUpHeadersCanCompleteLater);
  T.Run('Content-Length keep-alive truncated follow-up headers safe handling',
    @TestContentLengthKeepAliveTruncatedFollowUpHeadersSafeHandling);
  T.Run('Chunked extra bytes after close -> 400', @TestChunkedExtraBytesAfterClose);
  T.Run('Chunked keep-alive garbage tail safe handling', @TestChunkedKeepAliveGarbageTailSafeHandling);
  T.Run('Chunked keep-alive truncated follow-up request line safe handling',
    @TestChunkedKeepAliveTruncatedFollowUpRequestLineSafeHandling);
  T.Run('Chunked keep-alive partial follow-up request line can complete later',
    @TestChunkedKeepAlivePartialFollowUpRequestLineCanCompleteLater);
  T.Run('Chunked keep-alive partial follow-up headers can complete later',
    @TestChunkedKeepAlivePartialFollowUpHeadersCanCompleteLater);
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
  T.Run('Chunked trailer keep-alive partial follow-up headers can complete later',
    @TestChunkedTrailerPartialFollowUpHeadersCanCompleteLater);
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
  T.Run('CL + TE conflict with epoll backend',
    @TestContentLengthTransferEncodingConflictEpollBackend);
  T.Run('TE + CL conflict reverse order with epoll backend',
    @TestTransferEncodingContentLengthConflictReverseOrderEpollBackend);
  T.Run('Duplicate Content-Length -> 400 with epoll backend',
    @TestDuplicateContentLengthEpollBackend);
  T.Run('Negative Content-Length -> 400 with epoll backend',
    @TestNegativeContentLengthEpollBackend);
  T.Run('Unsupported transfer coding before chunked -> 501 with epoll backend',
    @TestUnsupportedTransferCodingBeforeChunkedEpollBackend);
  T.Run('Chunked must be final transfer coding -> 400 with epoll backend',
    @TestChunkedMustBeFinalTransferCodingEpollBackend);
  T.Run('Invalid chunk size -> 400 with epoll backend',
    @TestInvalidChunkSizeEpollBackend);
  T.Run('Malformed chunk extension -> 400 with epoll backend',
    @TestMalformedChunkExtensionEpollBackend);
  T.Run('Truncated chunk extension at EOF -> 400 with epoll backend',
    @TestTruncatedChunkExtensionAtEofEpollBackend);
  T.Run('Truncated chunk extension CR at EOF -> 400 with epoll backend',
    @TestTruncatedChunkExtensionCrAtEofEpollBackend);
  T.Run('Missing chunk-data CRLF -> 400 with epoll backend',
    @TestMissingChunkDataCrLfEpollBackend);
  T.Run('Chunked extra bytes after close -> 400 with epoll backend',
    @TestChunkedExtraBytesAfterCloseEpollBackend);
  T.Run('Truncated chunked request at EOF -> 400 with epoll backend',
    @TestTruncatedChunkedRequestAtEofEpollBackend);
  T.Run('Truncated chunk-size line at EOF -> 400 with epoll backend',
    @TestTruncatedChunkSizeLineAtEofEpollBackend);
  T.Run('Truncated terminal chunk ending at EOF -> 400 with epoll backend',
    @TestTruncatedTerminalChunkEndingAtEofEpollBackend);
  T.Run('Truncated terminal chunk ending CR at EOF -> 400 with epoll backend',
    @TestTruncatedTerminalChunkEndingCrAtEofEpollBackend);
  T.Run('Truncated terminal chunk extension at EOF -> 400 with epoll backend',
    @TestTruncatedTerminalChunkExtensionAtEofEpollBackend);
  T.Run('Truncated terminal chunk extension CR at EOF -> 400 with epoll backend',
    @TestTruncatedTerminalChunkExtensionCrAtEofEpollBackend);
  T.Run('Truncated terminal chunk ending after extension at EOF -> 400 with epoll backend',
    @TestTruncatedTerminalChunkEndingAfterExtensionAtEofEpollBackend);
  T.Run('Truncated terminal chunk ending after extension CR at EOF -> 400 with epoll backend',
    @TestTruncatedTerminalChunkEndingAfterExtensionCrAtEofEpollBackend);
  T.Run('Truncated chunk-data ending at EOF -> 400 with epoll backend',
    @TestTruncatedChunkDataEndingAtEofEpollBackend);
  T.Run('Truncated chunk-data CR at EOF -> 400 with epoll backend',
    @TestTruncatedChunkDataCrAtEofEpollBackend);
  T.Run('Fixed-length MaxBodySize -> 413 with epoll backend',
    @TestFixedLengthMaxBodySizeRejectedEpollBackend);
  T.Run('Chunked MaxBodySize rejects before terminal chunk with epoll backend',
    @TestChunkedMaxBodySizeRejectsBeforeTerminalChunkEpollBackend);
  T.Run('Truncated trailer section at EOF -> 400 with epoll backend',
    @TestTruncatedTrailerAtEofEpollBackend);
  T.Run('Truncated trailer field-name at EOF -> 400 with epoll backend',
    @TestTruncatedTrailerFieldNameAtEofEpollBackend);
  T.Run('Truncated trailer separator at EOF -> 400 with epoll backend',
    @TestTruncatedTrailerSeparatorAtEofEpollBackend);
  T.Run('Truncated trailer empty-value CR at EOF -> 400 with epoll backend',
    @TestTruncatedTrailerEmptyValueCrAtEofEpollBackend);
  T.Run('Truncated trailer empty-value at EOF -> 400 with epoll backend',
    @TestTruncatedTrailerEmptyValueAtEofEpollBackend);
  T.Run('Truncated trailer empty-value section CR at EOF -> 400 with epoll backend',
    @TestTruncatedTrailerEmptyValueSectionCrAtEofEpollBackend);
  T.Run('Truncated trailer whitespace at EOF -> 400 with epoll backend',
    @TestTruncatedTrailerWhitespaceAtEofEpollBackend);
  T.Run('Truncated trailer whitespace CR at EOF -> 400 with epoll backend',
    @TestTruncatedTrailerWhitespaceCrAtEofEpollBackend);
  T.Run('Truncated trailer whitespace section at EOF -> 400 with epoll backend',
    @TestTruncatedTrailerWhitespaceSectionAtEofEpollBackend);
  T.Run('Truncated trailer whitespace section CR at EOF -> 400 with epoll backend',
    @TestTruncatedTrailerWhitespaceSectionCrAtEofEpollBackend);
  T.Run('Truncated trailer field line at EOF -> 400 with epoll backend',
    @TestTruncatedTrailerFieldLineAtEofEpollBackend);
  T.Run('Truncated trailer field CR at EOF -> 400 with epoll backend',
    @TestTruncatedTrailerFieldCrAtEofEpollBackend);
  T.Run('Truncated trailer section CR at EOF -> 400 with epoll backend',
    @TestTruncatedTrailerCrAtEofEpollBackend);
  T.Run('Slowloris partial request with epoll backend',
    @TestSlowlorisEpollBackend);
  T.Run('Partial fixed-length body idle-timeout closes connection with epoll backend',
    @TestPartialFixedLengthBodyIdleTimeoutEpollBackend);
  T.Run('Partial chunk-size line idle-timeout closes connection with epoll backend',
    @TestPartialChunkSizeLineIdleTimeoutEpollBackend);
  T.Run('Partial chunked trailer idle-timeout closes connection with epoll backend',
    @TestPartialChunkedTrailerIdleTimeoutEpollBackend);
  T.Run('Malformed direct error backpressure safe handling with epoll backend',
    @TestMalformedRequestBackpressureSafeHandlingEpollBackend);
  T.Run('Unsupported transfer-coding direct error backpressure safe handling with epoll backend',
    @TestUnsupportedTransferCodingBackpressureSafeHandlingEpollBackend);
  T.Run('Chunked oversize trailer direct error backpressure safe handling with epoll backend',
    @TestChunkedOversizeTrailerBackpressureSafeHandlingEpollBackend);
  T.Run('Content-Length keep-alive garbage tail safe handling with epoll backend',
    @TestContentLengthKeepAliveGarbageTailSafeHandlingEpollBackend);
  T.Run('Content-Length keep-alive truncated follow-up request line safe handling with epoll backend',
    @TestContentLengthKeepAliveTruncatedFollowUpRequestLineSafeHandlingEpollBackend);
  T.Run('Content-Length keep-alive partial follow-up request line can complete later with epoll backend',
    @TestContentLengthKeepAlivePartialFollowUpRequestLineCanCompleteLaterEpollBackend);
  T.Run('Content-Length keep-alive partial follow-up headers can complete later with epoll backend',
    @TestContentLengthKeepAlivePartialFollowUpHeadersCanCompleteLaterEpollBackend);
  T.Run('Content-Length keep-alive truncated follow-up headers safe handling with epoll backend',
    @TestContentLengthKeepAliveTruncatedFollowUpHeadersSafeHandlingEpollBackend);
  T.Run('Chunked keep-alive garbage tail safe handling with epoll backend',
    @TestChunkedKeepAliveGarbageTailSafeHandlingEpollBackend);
  T.Run('Chunked keep-alive truncated follow-up request line safe handling with epoll backend',
    @TestChunkedKeepAliveTruncatedFollowUpRequestLineSafeHandlingEpollBackend);
  T.Run('Chunked keep-alive partial follow-up request line can complete later with epoll backend',
    @TestChunkedKeepAlivePartialFollowUpRequestLineCanCompleteLaterEpollBackend);
  T.Run('Chunked keep-alive partial follow-up headers can complete later with epoll backend',
    @TestChunkedKeepAlivePartialFollowUpHeadersCanCompleteLaterEpollBackend);
  T.Run('Chunked keep-alive truncated follow-up headers safe handling with epoll backend',
    @TestChunkedKeepAliveTruncatedFollowUpHeadersSafeHandlingEpollBackend);
  T.Run('Chunked trailer keep-alive garbage tail safe handling with epoll backend',
    @TestChunkedTrailerKeepAliveGarbageTailSafeHandlingEpollBackend);
  T.Run('Chunked trailer keep-alive truncated follow-up request line safe handling with epoll backend',
    @TestChunkedTrailerKeepAliveTruncatedFollowUpRequestLineSafeHandlingEpollBackend);
  T.Run('Chunked trailer keep-alive truncated follow-up headers safe handling with epoll backend',
    @TestChunkedTrailerKeepAliveTruncatedFollowUpHeadersSafeHandlingEpollBackend);
  T.Run('Chunked trailer keep-alive partial follow-up request line can complete later with epoll backend',
    @TestChunkedTrailerPartialFollowUpRequestLineCanCompleteLaterEpollBackend);
  T.Run('Chunked trailer keep-alive partial follow-up headers can complete later with epoll backend',
    @TestChunkedTrailerPartialFollowUpHeadersCanCompleteLaterEpollBackend);
  T.Run('Chunked trailer pipelined next request in single write with epoll backend',
    @TestChunkedTrailerPipelinedNextRequestInSingleWriteEpollBackend);
  T.Run('Malformed trailer field -> 400 with epoll backend',
    @TestMalformedTrailerFieldEpollBackend);
  T.Run('Header field over MaxHeaderSize -> explicit 431 with epoll backend',
    @TestHeaderFieldOverMaxHeaderSizeUsesExplicit431EpollBackend);
  T.Run('Request-target over MaxHeaderSize -> explicit 431 with epoll backend',
    @TestRequestTargetOverMaxHeaderSizeUsesExplicit431EpollBackend);
  {$ENDIF}
  T.Summary;
end.
