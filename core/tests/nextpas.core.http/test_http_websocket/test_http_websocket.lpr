program test_http_websocket;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.net,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.http,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.router,
  nextpas.core.http.server,
  nextpas.core.compress.deflate,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.atomic,
  nextpas.core.platform.thread;

var
  T: TTestSuite;
  { G3 写超时测试的跨线程标志（handler 线程写、主线程断言）。 }
  G3WriteTimeoutHit: LongInt;

function ReadTextFile(const APath: string): string;
var
  F: file;
  LSize: Int64;
begin
  AssignFile(F, APath);
  Reset(F, 1);
  try
    LSize := FileSize(F);
    SetLength(Result, LSize);
    if LSize > 0 then
      BlockRead(F, Result[1], Int32(LSize));
  finally
    CloseFile(F);
  end;
end;

function SourceHas(const ASource, AText: string): Boolean;
begin
  Result := Pos(AText, ASource) > 0;
end;

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

function StartServerWithOpts(const AHandler: IHttpHandler;
  const AOpts: THttpServerOptions; out AServer: THttpServer;
  out APort: UInt16): TPlatformThreadHandle;
var
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
begin
  AServer := THttpServer.Create(AHandler, AOpts);
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

function RepeatChar(const ACh: Char; const ACount: SizeUInt): string;
var
  I: SizeUInt;
begin
  SetLength(Result, ACount);
  for I := 1 to ACount do
    Result[I] := ACh;
end;

{ Build a masked WebSocket frame (client → server) }
function BuildMaskedFrame(AOpcode: Byte; const AData: string): string;
var
  LMaskKey: array[0..3] of Byte;
  LHdr: string;
  LPayloadLen: SizeUInt;
  I: SizeUInt;
begin
  { Fixed mask key for reproducibility }
  LMaskKey[0] := $12; LMaskKey[1] := $34;
  LMaskKey[2] := $56; LMaskKey[3] := $78;

  LPayloadLen := SizeUInt(Length(AData));

  if LPayloadLen < 126 then
  begin
    SetLength(LHdr, 6);
    LHdr[1] := Chr($80 or AOpcode);
    LHdr[2] := Chr($80 or LPayloadLen); { MASK bit set }
    LHdr[3] := Chr(LMaskKey[0]);
    LHdr[4] := Chr(LMaskKey[1]);
    LHdr[5] := Chr(LMaskKey[2]);
    LHdr[6] := Chr(LMaskKey[3]);
  end
  else
  begin
    SetLength(LHdr, 8);
    LHdr[1] := Chr($80 or AOpcode);
    LHdr[2] := Chr($80 or 126);
    LHdr[3] := Chr(LPayloadLen shr 8);
    LHdr[4] := Chr(LPayloadLen and $FF);
    LHdr[5] := Chr(LMaskKey[0]);
    LHdr[6] := Chr(LMaskKey[1]);
    LHdr[7] := Chr(LMaskKey[2]);
    LHdr[8] := Chr(LMaskKey[3]);
  end;

  Result := LHdr;
  for I := 1 to LPayloadLen do
    Result := Result + Chr(Ord(AData[I]) xor LMaskKey[(I - 1) mod 4]);
end;

function BuildUnmaskedFrame(AOpcode: Byte; const AData: string): string;
var
  LPayloadLen: SizeUInt;
begin
  LPayloadLen := SizeUInt(Length(AData));
  SetLength(Result, 2);
  Result[1] := Chr($80 or AOpcode);
  Result[2] := Chr(LPayloadLen);
  if LPayloadLen > 0 then
    Result := Result + AData;
end;

function BuildMaskedFrameWithFin(AOpcode: Byte; const AData: string; AFin: Boolean): string;
var
  LMaskKey: array[0..3] of Byte;
  LHdr: string;
  LPayloadLen: SizeUInt;
  I: SizeUInt;
begin
  LMaskKey[0] := $12; LMaskKey[1] := $34;
  LMaskKey[2] := $56; LMaskKey[3] := $78;

  LPayloadLen := SizeUInt(Length(AData));
  SetLength(LHdr, 6);
  if AFin then
    LHdr[1] := Chr($80 or AOpcode)
  else
    LHdr[1] := Chr(AOpcode);
  LHdr[2] := Chr($80 or LPayloadLen);
  LHdr[3] := Chr(LMaskKey[0]);
  LHdr[4] := Chr(LMaskKey[1]);
  LHdr[5] := Chr(LMaskKey[2]);
  LHdr[6] := Chr(LMaskKey[3]);

  Result := LHdr;
  for I := 1 to LPayloadLen do
    Result := Result + Chr(Ord(AData[I]) xor LMaskKey[(I - 1) mod 4]);
end;

function BuildMaskedFrameWithFirstByte(AFirstByte: Byte; const AData: string): string;
var
  LMaskKey: array[0..3] of Byte;
  LPayloadLen: SizeUInt;
  I: SizeUInt;
begin
  LMaskKey[0] := $12; LMaskKey[1] := $34;
  LMaskKey[2] := $56; LMaskKey[3] := $78;

  LPayloadLen := SizeUInt(Length(AData));
  SetLength(Result, 6);
  Result[1] := Chr(AFirstByte);
  Result[2] := Chr($80 or LPayloadLen);
  Result[3] := Chr(LMaskKey[0]);
  Result[4] := Chr(LMaskKey[1]);
  Result[5] := Chr(LMaskKey[2]);
  Result[6] := Chr(LMaskKey[3]);

  for I := 1 to LPayloadLen do
    Result := Result + Chr(Ord(AData[I]) xor LMaskKey[(I - 1) mod 4]);
end;

function BuildMaskedFrameWithLength16(AOpcode: Byte; const AData: string): string;
var
  LMaskKey: array[0..3] of Byte;
  LPayloadLen: SizeUInt;
  I: SizeUInt;
begin
  LMaskKey[0] := $12; LMaskKey[1] := $34;
  LMaskKey[2] := $56; LMaskKey[3] := $78;

  LPayloadLen := SizeUInt(Length(AData));
  SetLength(Result, 8);
  Result[1] := Chr($80 or AOpcode);
  Result[2] := Chr($80 or 126);
  Result[3] := Chr(LPayloadLen shr 8);
  Result[4] := Chr(LPayloadLen and $FF);
  Result[5] := Chr(LMaskKey[0]);
  Result[6] := Chr(LMaskKey[1]);
  Result[7] := Chr(LMaskKey[2]);
  Result[8] := Chr(LMaskKey[3]);

  for I := 1 to LPayloadLen do
    Result := Result + Chr(Ord(AData[I]) xor LMaskKey[(I - 1) mod 4]);
end;

function BuildMaskedFrameWithLength64(AOpcode: Byte; const AData: string): string;
var
  LMaskKey: array[0..3] of Byte;
  LPayloadLen: UInt64;
  I: SizeUInt;
begin
  LMaskKey[0] := $12; LMaskKey[1] := $34;
  LMaskKey[2] := $56; LMaskKey[3] := $78;

  LPayloadLen := UInt64(Length(AData));
  SetLength(Result, 14);
  Result[1] := Chr($80 or AOpcode);
  Result[2] := Chr($80 or 127);
  Result[3] := Chr((LPayloadLen shr 56) and $FF);
  Result[4] := Chr((LPayloadLen shr 48) and $FF);
  Result[5] := Chr((LPayloadLen shr 40) and $FF);
  Result[6] := Chr((LPayloadLen shr 32) and $FF);
  Result[7] := Chr((LPayloadLen shr 24) and $FF);
  Result[8] := Chr((LPayloadLen shr 16) and $FF);
  Result[9] := Chr((LPayloadLen shr 8) and $FF);
  Result[10] := Chr(LPayloadLen and $FF);
  Result[11] := Chr(LMaskKey[0]);
  Result[12] := Chr(LMaskKey[1]);
  Result[13] := Chr(LMaskKey[2]);
  Result[14] := Chr(LMaskKey[3]);

  for I := 1 to SizeUInt(LPayloadLen) do
    Result := Result + Chr(Ord(AData[I]) xor LMaskKey[(I - 1) mod 4]);
end;

function BuildMaskedFrameWithHighBitLength64(AOpcode: Byte): string;
begin
  SetLength(Result, 14);
  Result[1] := Chr($80 or AOpcode);
  Result[2] := Chr($80 or 127);
  Result[3] := Chr($80);
  Result[4] := #0;
  Result[5] := #0;
  Result[6] := #0;
  Result[7] := #0;
  Result[8] := #0;
  Result[9] := #0;
  Result[10] := #0;
  Result[11] := Chr($12);
  Result[12] := Chr($34);
  Result[13] := Chr($56);
  Result[14] := Chr($78);
end;

function BuildMaskedFrameWithDeclaredLength64(AOpcode: Byte; ALength: UInt64): string;
begin
  SetLength(Result, 14);
  Result[1] := Chr($80 or AOpcode);
  Result[2] := Chr($80 or 127);
  Result[3] := Chr((ALength shr 56) and $FF);
  Result[4] := Chr((ALength shr 48) and $FF);
  Result[5] := Chr((ALength shr 40) and $FF);
  Result[6] := Chr((ALength shr 32) and $FF);
  Result[7] := Chr((ALength shr 24) and $FF);
  Result[8] := Chr((ALength shr 16) and $FF);
  Result[9] := Chr((ALength shr 8) and $FF);
  Result[10] := Chr(ALength and $FF);
  Result[11] := Chr($12);
  Result[12] := Chr($34);
  Result[13] := Chr($56);
  Result[14] := Chr($78);
end;

function SendRawAndRead(const APort: UInt16; const ARequest: string; AReadLen: Integer): string;
var
  LConn: ITcpStream;
  LBuf: array[0..8191] of Byte;
  LN: SizeUInt;
  LTotal: Integer;
begin
  Result := '';
  LConn := TcpConnect('127.0.0.1', APort);
  LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
  LConn.Write(ARequest[1], SizeUInt(Length(ARequest)));
  LTotal := 0;
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
      Inc(LTotal, Int32(LN));
    end;
  until (LN = 0) or (LTotal >= AReadLen);
  LConn.Close;
end;

{ Test 1: Handshake succeeds with correct headers }
procedure TestHandshakeSuccess;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LKey: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LWs: IWebSocket;
  begin
    try
      LWs := UpgradeWebSocket(AReq, AW);
      { Just accept and close }
      LWs.Close(1000, 'ok');
    except
      on E: EHttpError do
      begin
        AW.GetHeaders.SetHeader('content-length', '0');
        AW.WriteHeader(HTTP_STATUS_BAD_REQUEST);
      end;
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LResp := SendRawAndRead(LPort,
      'GET /ws HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Upgrade: websocket'#13#10 +
      'Connection: Upgrade'#13#10 +
      'Sec-WebSocket-Key: ' + LKey + #13#10 +
      'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
      #13#10, 256);
    Check(Pos('HTTP/1.1 101', LResp) > 0, 'should get 101 status');
    Check(Pos('Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=', LResp) > 0,
      'should have RFC 6455 accept key');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestWebSocketAcceptGuidSourceContract;
var
  LBaseSource: string;
  LHttpSource: string;
begin
  LBaseSource := ReadTextFile('../../../src/nextpas.core.websocket.base.pas');
  LHttpSource := ReadTextFile('../../../src/nextpas.core.http.websocket.pas');
  Check(not SourceHas(LBaseSource, '5AB0F964E80E'),
    'standalone WebSocket base must not use old wrong GUID suffix');
  Check(not SourceHas(LHttpSource, '5AB53DC85B11'),
    'HTTP WebSocket helper must not use old wrong GUID suffix');
  Check(SourceHas(LBaseSource, '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'),
    'standalone WebSocket base uses RFC 6455 GUID');
end;

procedure TestWebSocketWriteAllSourceContract;
var
  LHttpSource: string;
begin
  LHttpSource := ReadTextFile('../../../src/nextpas.core.http.websocket.pas');
  Check(SourceHas(LHttpSource, 'IoWriteAll(LConn'),
    'server handshake must handle short writes');
  Check(SourceHas(LHttpSource, 'WriteAll(LBuf[0], LBufLen)'),
    'websocket frames must handle short writes via deadline-aware WriteAll');
  Check(SourceHas(LHttpSource, 'IoWriteAll(LWriter'),
    'client handshake must handle short writes');
end;

{ Test 2: Handshake fails without Upgrade header }
procedure TestHandshakeNoUpgrade;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LWs: IWebSocket;
  begin
    try
      LWs := UpgradeWebSocket(AReq, AW);
    except
      on E: EHttpError do
      begin
        AW.GetHeaders.SetHeader('content-length', '0');
        AW.WriteHeader(HTTP_STATUS_BAD_REQUEST);
      end;
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawAndRead(LPort,
      'GET /ws HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Connection: close'#13#10 +
      #13#10, 256);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'should get 400 without Upgrade header');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 3: Handshake fails without Sec-WebSocket-Key }
procedure TestHandshakeNoKey;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LWs: IWebSocket;
  begin
    try
      LWs := UpgradeWebSocket(AReq, AW);
    except
      on E: EHttpError do
      begin
        AW.GetHeaders.SetHeader('content-length', '0');
        AW.WriteHeader(HTTP_STATUS_BAD_REQUEST);
      end;
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawAndRead(LPort,
      'GET /ws HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Upgrade: websocket'#13#10 +
      'Connection: Upgrade'#13#10 +
      'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
      #13#10, 256);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'should get 400 without Key');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 3b: Handshake fails when Sec-WebSocket-Key is malformed }
procedure TestHandshakeInvalidKeyRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;

  procedure AssertRejected(const ACaseName, AKey: string);
  begin
    LResp := SendRawAndRead(LPort,
      'GET /ws HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Upgrade: websocket'#13#10 +
      'Connection: Upgrade'#13#10 +
      'Sec-WebSocket-Key: ' + AKey + #13#10 +
      'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
      #13#10, 256);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      ACaseName + ': should get 400 for invalid Key');
    Check(Pos('HTTP/1.1 101', LResp) = 0,
      ACaseName + ': should not upgrade invalid Key');
  end;

begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LWs: IWebSocket;
  begin
    try
      LWs := UpgradeWebSocket(AReq, AW);
      LWs.Close(1000, 'invalid key accepted');
    except
      on E: EHttpError do
      begin
        AW.GetHeaders.SetHeader('content-length', '0');
        AW.WriteHeader(HTTP_STATUS_BAD_REQUEST);
      end;
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    AssertRejected('invalid-base64', 'not-base64');
    AssertRejected('short-decoded-nonce', 'aGk=');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 3c: Handshake requires an exact Connection upgrade token }
procedure TestHandshakeConnectionUpgradeTokenRequired;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LWs: IWebSocket;
  begin
    try
      LWs := UpgradeWebSocket(AReq, AW);
      LWs.Close(1000, 'invalid connection token accepted');
    except
      on E: EHttpError do
      begin
        AW.GetHeaders.SetHeader('content-length', '0');
        AW.WriteHeader(HTTP_STATUS_BAD_REQUEST);
      end;
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawAndRead(LPort,
      'GET /ws HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Upgrade: websocket'#13#10 +
      'Connection: keep-alive, notupgrade'#13#10 +
      'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ=='#13#10 +
      'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
      #13#10, 256);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'should get 400 without exact Connection upgrade token');
    Check(Pos('HTTP/1.1 101', LResp) = 0,
      'should not upgrade substring Connection token');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 3b: Handshake accepts upgrade token split across duplicate Connection headers }
procedure TestHandshakeAcceptsDuplicateConnectionUpgradeToken;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LKey, LExpectedAccept: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LWs: IWebSocket;
  begin
    try
      LWs := UpgradeWebSocket(AReq, AW);
      LWs.Close(1000, 'ok');
    except
      on E: EHttpError do
      begin
        AW.GetHeaders.SetHeader('content-length', '0');
        AW.WriteHeader(HTTP_STATUS_BAD_REQUEST);
      end;
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LExpectedAccept := 's3pPLMBiTxaQ9kYGzzhZRbK+xOo=';
    LResp := SendRawAndRead(LPort,
      'GET /ws HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Upgrade: websocket'#13#10 +
      'Connection: keep-alive'#13#10 +
      'Connection: Upgrade'#13#10 +
      'Sec-WebSocket-Key: ' + LKey + #13#10 +
      'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
      #13#10, 256);
    Check(Pos('HTTP/1.1 101', LResp) > 0,
      'duplicate Connection headers should expose upgrade token');
    Check(Pos('Sec-WebSocket-Accept: ' + LExpectedAccept, LResp) > 0,
      'duplicate Connection header upgrade should complete handshake');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4: Text frame echo }
procedure TestTextFrameEcho;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LFrame: string;
  LPayloadStart: Integer;
  LPayloadLen: Byte;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    LF := LWs.ReadFrame;
    if LF.Opcode = wsOpText then
      LWs.WriteText(UTF8BytesToString(LF.Payload));
    LWs.Close(1000, '');
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      { Send upgrade request }
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      { Read 101 response }
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('101', LResp) > 0, 'echo: got 101');

      { Send masked text frame: "hello" }
      LFrame := BuildMaskedFrame($01, 'hello');
      LConn.Write(LFrame[1], SizeUInt(Length(LFrame)));

      { Read server response frame (unmasked text) }
      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Length(LResp) >= 7) or (LN = 0);

      { Parse: first byte = $81 (FIN+text), second byte = payload len }
      Check(Length(LResp) >= 7, 'echo: got response frame');
      Check(Ord(LResp[1]) = $81, 'echo: FIN+text opcode');
      LPayloadLen := Ord(LResp[2]) and $7F;
      CheckEqual(Int64(5), Int64(LPayloadLen), 'echo: payload len = 5');
      LPayloadStart := 3;
      CheckEqual('hello', Copy(LResp, LPayloadStart, LPayloadLen), 'echo: payload matches');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4b: Upgrade request and first frame coalesced in one write }
procedure TestTextFrameEchoWithCoalescedFirstFrame;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq, LFrame, LCombined: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LPayloadStart: Integer;
  LPayloadLen: Byte;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    LF := LWs.ReadFrame;
    if LF.Opcode = wsOpText then
      LWs.WriteText(UTF8BytesToString(LF.Payload));
    LWs.Close(1000, '');
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;
    LFrame := BuildMaskedFrame($01, 'hello');
    LCombined := LReq + LFrame;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LCombined[1], SizeUInt(Length(LCombined)));
      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Pos(#13#10#13#10, LResp) > 0) and
            (Length(LResp) >= Pos(#13#10#13#10, LResp) + 4 + 7) or
            (LN = 0);

      Check(Pos('101', LResp) > 0, 'coalesced echo: got 101');
      LPayloadStart := Pos(#13#10#13#10, LResp) + 4;
      Check(LPayloadStart >= 5, 'coalesced echo: headers complete');
      Check(Length(LResp) >= LPayloadStart + 6, 'coalesced echo: got response frame');
      Check(Ord(LResp[LPayloadStart]) = $81, 'coalesced echo: FIN+text opcode');
      LPayloadLen := Ord(LResp[LPayloadStart + 1]) and $7F;
      CheckEqual(Int64(5), Int64(LPayloadLen), 'coalesced echo: payload len = 5');
      CheckEqual('hello', Copy(LResp, LPayloadStart + 2, LPayloadLen), 'coalesced echo: payload matches');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestReadMessagePreservesFragmentedOpcode;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq, LFrame1, LFrame2, LCombined: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LPayloadStart: Integer;
  LPayloadLen: Byte;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LMessage: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    LMessage := LWs.ReadMessage;
    if LMessage.Opcode = wsOpText then
      LWs.WriteText('text')
    else
      LWs.WriteText('wrong');
    LWs.Close(1000, '');
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;
    LFrame1 := BuildMaskedFrameWithFin($01, 'hel', False);
    LFrame2 := BuildMaskedFrame($00, 'lo');
    LCombined := LReq + LFrame1 + LFrame2;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LCombined[1], SizeUInt(Length(LCombined)));
      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Pos(#13#10#13#10, LResp) > 0) and
            (Length(LResp) >= Pos(#13#10#13#10, LResp) + 4 + 6) or
            (LN = 0);

      LPayloadStart := Pos(#13#10#13#10, LResp) + 4;
      Check(LPayloadStart >= 5, 'fragmented message: headers complete');
      Check(Ord(LResp[LPayloadStart]) = $81,
        'fragmented message: response is text');
      LPayloadLen := Ord(LResp[LPayloadStart + 1]) and $7F;
      CheckEqual('text', Copy(LResp, LPayloadStart + 2, LPayloadLen),
        'ReadMessage preserves original text opcode');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestNegativeWebSocketOptionsRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LKey: string;
  LOptions: TWebSocketOptions;
begin
  LOptions := TWebSocketOptions.Default;
  LOptions.MaxFrameSize := -1;
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
  begin
    try
      LWs := UpgradeWebSocket(AReq, AW, LOptions);
      LWs.Close(1000, '');
    except
      on E: EHttpError do
      begin
        Check(E.Kind = hekArgument, 'negative MaxFrameSize is hekArgument');
        AW.GetHeaders.SetHeader('content-length', '0');
        AW.WriteHeader(HTTP_STATUS_BAD_REQUEST);
      end;
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LResp := SendRawAndRead(LPort,
      'GET /ws HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Upgrade: websocket'#13#10 +
      'Connection: Upgrade'#13#10 +
      'Sec-WebSocket-Key: ' + LKey + #13#10 +
      'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
      #13#10, 256);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'negative websocket limits rejected before hijack');
    Check(Pos('HTTP/1.1 101', LResp) = 0,
      'invalid options must not upgrade connection');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4c: Upgrade exception does not append 500 or close owned websocket }
procedure TestUpgradeExceptionDoesNotWrite500OrCloseOwnedWebSocket;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LServerSideWs: IWebSocket;
  LKey, LReq, LFrame: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LFrameResp: string;
  LPayloadLen: Byte;
  LPayloadStart: Integer;
  LReceived: TWebSocketFrame;
begin
  LServerSideWs := nil;
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws-crash', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    LServerSideWs := UpgradeWebSocket(AReq, AW);
    raise Exception.Create('crash after websocket upgrade');
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws-crash HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('HTTP/1.1 101 Switching Protocols', LResp) = 1,
        'upgrade-crash: got 101 status');

      LConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(200)));
      try
        LN := LConn.Read(LBuf[0], 1);
      except
        LN := 0;
      end;
      CheckEqual(Int64(0), Int64(LN),
        'upgrade-crash: server does not append 500 after handler exception');

      platform_thread_sleep_ns(100000000);
      Check(LServerSideWs <> nil,
        'upgrade-crash: handler retained owned websocket after exception');

      LFrame := BuildMaskedFrame($01, 'probe');
      LConn.Write(LFrame[1], SizeUInt(Length(LFrame)));
      LReceived := LServerSideWs.ReadFrame;
      Check(LReceived.Opcode = wsOpText,
        'upgrade-crash: server-owned websocket still reads text frame');
      CheckEqual('probe', UTF8BytesToString(LReceived.Payload),
        'upgrade-crash: server-owned websocket reads probe payload');
      LServerSideWs.WriteText(UTF8BytesToString(LReceived.Payload));

      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
      LFrameResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LFrameResp, Length(LFrameResp) + Int32(LN));
          Move(LBuf[0], LFrameResp[Length(LFrameResp) - Int32(LN) + 1], LN);
        end;
      until (Length(LFrameResp) >= 7) or (LN = 0);

      Check(Length(LFrameResp) >= 7,
        'upgrade-crash: client receives websocket frame after exception');
      LPayloadStart := 1;
      Check(Ord(LFrameResp[LPayloadStart]) = $81,
        'upgrade-crash: reply frame keeps text opcode');
      LPayloadLen := Ord(LFrameResp[LPayloadStart + 1]) and $7F;
      CheckEqual(Int64(5), Int64(LPayloadLen),
        'upgrade-crash: reply payload len = 5');
      CheckEqual('probe', Copy(LFrameResp, LPayloadStart + 2, LPayloadLen),
        'upgrade-crash: reply payload matches');

      LServerSideWs.Close(1000, '');
    finally
      LConn.Close;
      LServerSideWs := nil;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4d: unmasked client frames are rejected as protocol errors }
procedure TestUnmaskedClientFrameRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LFrame: string;
  LPayloadLen: Byte;
  LCode: UInt16;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    try
      LF := LWs.ReadFrame;
      if LF.Opcode = wsOpText then
        LWs.WriteText(UTF8BytesToString(LF.Payload));
    except
      on E: EHttpError do
        LWs.Close(1002, 'protocol');
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('HTTP/1.1 101', LResp) > 0, 'unmasked: got 101');

      LFrame := BuildUnmaskedFrame($01, 'hello');
      LConn.Write(LFrame[1], SizeUInt(Length(LFrame)));

      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Length(LResp) >= 4) or (LN = 0);

      Check(Length(LResp) >= 4, 'unmasked: got close response');
      Check(Ord(LResp[1]) = $88, 'unmasked: server sends close frame');
      LPayloadLen := Ord(LResp[2]) and $7F;
      Check(LPayloadLen >= 2, 'unmasked: close frame includes code');
      LCode := (UInt16(Ord(LResp[3])) shl 8) or UInt16(Ord(LResp[4]));
      CheckEqual(Int64(1002), Int64(LCode), 'unmasked: close code protocol error');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4e: control frames with payload > 125 are rejected as protocol errors }
procedure TestControlFramePayloadTooLargeRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LFrame: string;
  LPayload: string;
  LPayloadLen: Byte;
  LCode: UInt16;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    try
      LF := LWs.ReadFrame;
      if LF.Opcode = wsOpPing then
        LWs.Pong(LF.Payload);
    except
      on E: EHttpError do
        LWs.Close(1002, 'protocol');
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('HTTP/1.1 101', LResp) > 0, 'control-oversize: got 101');

      LPayload := TextOfChar('x', 126);
      LFrame := BuildMaskedFrame($09, LPayload);
      LConn.Write(LFrame[1], SizeUInt(Length(LFrame)));

      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Length(LResp) >= 4) or (LN = 0);

      Check(Length(LResp) >= 4, 'control-oversize: got close response');
      Check(Ord(LResp[1]) = $88, 'control-oversize: server sends close frame');
      LPayloadLen := Ord(LResp[2]) and $7F;
      Check(LPayloadLen >= 2, 'control-oversize: close frame includes code');
      LCode := (UInt16(Ord(LResp[3])) shl 8) or UInt16(Ord(LResp[4]));
      CheckEqual(Int64(1002), Int64(LCode), 'control-oversize: close code protocol error');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4f: reserved opcodes are rejected as protocol errors }
procedure TestReservedOpcodeRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LFrame: string;
  LPayloadLen: Byte;
  LCode: UInt16;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    try
      LF := LWs.ReadFrame;
      if LF.Opcode = wsOpText then
        LWs.WriteText(UTF8BytesToString(LF.Payload));
    except
      on E: EHttpError do
        LWs.Close(1002, 'protocol');
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('HTTP/1.1 101', LResp) > 0, 'reserved-opcode: got 101');

      LFrame := BuildMaskedFrame($03, 'bad');
      LConn.Write(LFrame[1], SizeUInt(Length(LFrame)));

      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Length(LResp) >= 4) or (LN = 0);

      Check(Length(LResp) >= 4, 'reserved-opcode: got close response');
      Check(Ord(LResp[1]) = $88, 'reserved-opcode: server sends close frame');
      LPayloadLen := Ord(LResp[2]) and $7F;
      Check(LPayloadLen >= 2, 'reserved-opcode: close frame includes code');
      LCode := (UInt16(Ord(LResp[3])) shl 8) or UInt16(Ord(LResp[4]));
      CheckEqual(Int64(1002), Int64(LCode), 'reserved-opcode: close code protocol error');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4g: RSV bits are rejected unless an extension negotiated them }
procedure TestReservedBitsRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LFrame: string;
  LPayloadLen: Byte;
  LCode: UInt16;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    try
      LF := LWs.ReadFrame;
      if LF.Opcode = wsOpText then
        LWs.WriteText(UTF8BytesToString(LF.Payload));
    except
      on E: EHttpError do
        LWs.Close(1002, 'protocol');
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('HTTP/1.1 101', LResp) > 0, 'reserved-bits: got 101');

      LFrame := BuildMaskedFrameWithFirstByte($C1, 'bad');
      LConn.Write(LFrame[1], SizeUInt(Length(LFrame)));

      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Length(LResp) >= 4) or (LN = 0);

      Check(Length(LResp) >= 4, 'reserved-bits: got close response');
      Check(Ord(LResp[1]) = $88, 'reserved-bits: server sends close frame');
      LPayloadLen := Ord(LResp[2]) and $7F;
      Check(LPayloadLen >= 2, 'reserved-bits: close frame includes code');
      LCode := (UInt16(Ord(LResp[3])) shl 8) or UInt16(Ord(LResp[4]));
      CheckEqual(Int64(1002), Int64(LCode), 'reserved-bits: close code protocol error');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4g: control frames must not be fragmented }
procedure TestFragmentedControlFrameRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LFrame: string;
  LPayloadLen: Byte;
  LCode: UInt16;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    try
      LF := LWs.ReadFrame;
      if LF.Opcode = wsOpPing then
        LWs.Pong(LF.Payload);
    except
      on E: EHttpError do
        LWs.Close(1002, 'protocol');
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('HTTP/1.1 101', LResp) > 0, 'fragmented-control: got 101');

      LFrame := BuildMaskedFrameWithFin($09, 'bad', False);
      LConn.Write(LFrame[1], SizeUInt(Length(LFrame)));

      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Length(LResp) >= 4) or (LN = 0);

      Check(Length(LResp) >= 4, 'fragmented-control: got close response');
      Check(Ord(LResp[1]) = $88, 'fragmented-control: server sends close frame');
      LPayloadLen := Ord(LResp[2]) and $7F;
      Check(LPayloadLen >= 2, 'fragmented-control: close frame includes code');
      LCode := (UInt16(Ord(LResp[3])) shl 8) or UInt16(Ord(LResp[4]));
      CheckEqual(Int64(1002), Int64(LCode), 'fragmented-control: close code protocol error');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4h: close frames with invalid close codes are rejected }
procedure TestInvalidCloseCodeRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LFrame: string;
  LPayloadLen: Byte;
  LCode: UInt16;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    try
      LF := LWs.ReadFrame;
      if LF.Opcode = wsOpClose then
        LWs.Close(1000, 'bye');
    except
      on E: EHttpError do
        LWs.Close(1002, 'protocol');
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('HTTP/1.1 101', LResp) > 0, 'invalid-close-code: got 101');

      LFrame := BuildMaskedFrame($08, #$03#$E7);
      LConn.Write(LFrame[1], SizeUInt(Length(LFrame)));

      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Length(LResp) >= 4) or (LN = 0);

      Check(Length(LResp) >= 4, 'invalid-close-code: got close response');
      Check(Ord(LResp[1]) = $88, 'invalid-close-code: server sends close frame');
      LPayloadLen := Ord(LResp[2]) and $7F;
      Check(LPayloadLen >= 2, 'invalid-close-code: close frame includes code');
      LCode := (UInt16(Ord(LResp[3])) shl 8) or UInt16(Ord(LResp[4]));
      CheckEqual(Int64(1002), Int64(LCode), 'invalid-close-code: close code protocol error');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4i: text frames must carry valid UTF-8 payloads }
procedure TestInvalidUtf8TextFrameRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LFrame: string;
  LPayloadLen: Byte;
  LCode: UInt16;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    try
      LF := LWs.ReadFrame;
      if LF.Opcode = wsOpText then
        LWs.WriteText(UTF8BytesToString(LF.Payload));
    except
      on E: EHttpError do
        LWs.Close(1002, 'protocol');
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('HTTP/1.1 101', LResp) > 0, 'invalid-utf8-text: got 101');

      LFrame := BuildMaskedFrame($01, #$C0#$AF);
      LConn.Write(LFrame[1], SizeUInt(Length(LFrame)));

      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Length(LResp) >= 4) or (LN = 0);

      Check(Length(LResp) >= 4, 'invalid-utf8-text: got close response');
      Check(Ord(LResp[1]) = $88, 'invalid-utf8-text: server sends close frame');
      LPayloadLen := Ord(LResp[2]) and $7F;
      Check(LPayloadLen >= 2, 'invalid-utf8-text: close frame includes code');
      LCode := (UInt16(Ord(LResp[3])) shl 8) or UInt16(Ord(LResp[4]));
      CheckEqual(Int64(1002), Int64(LCode), 'invalid-utf8-text: close code protocol error');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4j: close frame reasons must carry valid UTF-8 }
procedure TestInvalidUtf8CloseReasonRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LFrame: string;
  LPayloadLen: Byte;
  LCode: UInt16;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    try
      LF := LWs.ReadFrame;
      if LF.Opcode = wsOpClose then
        LWs.Close(1000, 'bye');
    except
      on E: EHttpError do
        LWs.Close(1002, 'protocol');
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('HTTP/1.1 101', LResp) > 0, 'invalid-utf8-close-reason: got 101');

      LFrame := BuildMaskedFrame($08, #$03#$E8#$C0#$AF);
      LConn.Write(LFrame[1], SizeUInt(Length(LFrame)));

      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Length(LResp) >= 4) or (LN = 0);

      Check(Length(LResp) >= 4, 'invalid-utf8-close-reason: got close response');
      Check(Ord(LResp[1]) = $88, 'invalid-utf8-close-reason: server sends close frame');
      LPayloadLen := Ord(LResp[2]) and $7F;
      Check(LPayloadLen >= 2, 'invalid-utf8-close-reason: close frame includes code');
      LCode := (UInt16(Ord(LResp[3])) shl 8) or UInt16(Ord(LResp[4]));
      CheckEqual(Int64(1002), Int64(LCode),
        'invalid-utf8-close-reason: close code protocol error');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4k: continuation frames require an open fragmented data message }
procedure TestStandaloneContinuationFrameRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LFrame: string;
  LPayloadLen: Byte;
  LCode: UInt16;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    try
      LF := LWs.ReadFrame;
      if LF.Opcode = wsOpContinuation then
        LWs.WriteText('unexpected');
    except
      on E: EHttpError do
        LWs.Close(1002, 'protocol');
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('HTTP/1.1 101', LResp) > 0, 'standalone-continuation: got 101');

      LFrame := BuildMaskedFrame($00, 'orphan');
      LConn.Write(LFrame[1], SizeUInt(Length(LFrame)));

      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Length(LResp) >= 4) or (LN = 0);

      Check(Length(LResp) >= 4, 'standalone-continuation: got close response');
      Check(Ord(LResp[1]) = $88, 'standalone-continuation: server sends close frame');
      LPayloadLen := Ord(LResp[2]) and $7F;
      Check(LPayloadLen >= 2, 'standalone-continuation: close frame includes code');
      LCode := (UInt16(Ord(LResp[3])) shl 8) or UInt16(Ord(LResp[4]));
      CheckEqual(Int64(1002), Int64(LCode),
        'standalone-continuation: close code protocol error');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4l: fragmented text may split a UTF-8 sequence across frames }
procedure TestFragmentedTextUtf8SequenceAccepted;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LFrame1: string;
  LFrame2: string;
  LPayloadLen: Byte;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    try
      LF := LWs.ReadFrame;
      if (LF.Opcode = wsOpText) and (not LF.Fin) then
      begin
        LF := LWs.ReadFrame;
        if (LF.Opcode = wsOpContinuation) and LF.Fin then
          LWs.WriteText('ok');
      end;
    except
      on E: EHttpError do
        LWs.Close(1002, 'protocol');
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('HTTP/1.1 101', LResp) > 0, 'fragmented-utf8: got 101');

      LFrame1 := BuildMaskedFrameWithFin($01, #$C3, False);
      LFrame2 := BuildMaskedFrame($00, #$A9);
      LConn.Write(LFrame1[1], SizeUInt(Length(LFrame1)));
      LConn.Write(LFrame2[1], SizeUInt(Length(LFrame2)));

      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Length(LResp) >= 4) or (LN = 0);

      Check(Length(LResp) >= 4, 'fragmented-utf8: got response frame');
      Check(Ord(LResp[1]) = $81, 'fragmented-utf8: server sends text frame');
      LPayloadLen := Ord(LResp[2]) and $7F;
      CheckEqual(Int64(2), Int64(LPayloadLen), 'fragmented-utf8: payload len = 2');
      CheckEqual('ok', Copy(LResp, 3, LPayloadLen), 'fragmented-utf8: payload');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4m: payload length must use the shortest possible encoding }
procedure TestNonCanonicalPayloadLengthRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LFrame: string;
  LPayloadLen: Byte;
  LCode: UInt16;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    try
      LF := LWs.ReadFrame;
      if LF.Opcode = wsOpText then
        LWs.WriteText(UTF8BytesToString(LF.Payload));
    except
      on E: EHttpError do
        LWs.Close(1002, 'protocol');
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('HTTP/1.1 101', LResp) > 0, 'non-canonical-length: got 101');

      LFrame := BuildMaskedFrameWithLength16($01, 'hi');
      LConn.Write(LFrame[1], SizeUInt(Length(LFrame)));

      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Length(LResp) >= 4) or (LN = 0);

      Check(Length(LResp) >= 4, 'non-canonical-length: got close response');
      Check(Ord(LResp[1]) = $88, 'non-canonical-length: server sends close frame');
      LPayloadLen := Ord(LResp[2]) and $7F;
      Check(LPayloadLen >= 2, 'non-canonical-length: close frame includes code');
      LCode := (UInt16(Ord(LResp[3])) shl 8) or UInt16(Ord(LResp[4]));
      CheckEqual(Int64(1002), Int64(LCode),
        'non-canonical-length: close code protocol error');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4n: 64-bit payload length must also be canonical }
procedure TestNonCanonicalPayloadLength64Rejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LFrame: string;
  LPayloadLen: Byte;
  LCode: UInt16;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    try
      LF := LWs.ReadFrame;
      if LF.Opcode = wsOpText then
        LWs.WriteText(UTF8BytesToString(LF.Payload));
    except
      on E: EHttpError do
        LWs.Close(1002, 'protocol');
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('HTTP/1.1 101', LResp) > 0, 'non-canonical-length64: got 101');

      LFrame := BuildMaskedFrameWithLength64($01, 'hi');
      LConn.Write(LFrame[1], SizeUInt(Length(LFrame)));

      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Length(LResp) >= 4) or (LN = 0);

      Check(Length(LResp) >= 4, 'non-canonical-length64: got close response');
      Check(Ord(LResp[1]) = $88, 'non-canonical-length64: server sends close frame');
      LPayloadLen := Ord(LResp[2]) and $7F;
      Check(LPayloadLen >= 2, 'non-canonical-length64: close frame includes code');
      LCode := (UInt16(Ord(LResp[3])) shl 8) or UInt16(Ord(LResp[4]));
      CheckEqual(Int64(1002), Int64(LCode),
        'non-canonical-length64: close code protocol error');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4o: 64-bit payload length must fit the RFC 6455 63-bit field }
procedure TestHighBitPayloadLength64Rejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LFrame: string;
  LPayloadLen: Byte;
  LCode: UInt16;
  LReason: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    try
      LF := LWs.ReadFrame;
      if LF.Opcode = wsOpText then
        LWs.WriteText(UTF8BytesToString(LF.Payload));
    except
      on E: EHttpError do
        LWs.Close(1002, E.Message);
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('HTTP/1.1 101', LResp) > 0, 'high-bit-length64: got 101');

      LFrame := BuildMaskedFrameWithHighBitLength64($09);
      LConn.Write(LFrame[1], SizeUInt(Length(LFrame)));

      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Length(LResp) >= 4) or (LN = 0);

      Check(Length(LResp) >= 4, 'high-bit-length64: got close response');
      Check(Ord(LResp[1]) = $88, 'high-bit-length64: server sends close frame');
      LPayloadLen := Ord(LResp[2]) and $7F;
      Check(LPayloadLen >= 2, 'high-bit-length64: close frame includes code');
      LCode := (UInt16(Ord(LResp[3])) shl 8) or UInt16(Ord(LResp[4]));
      CheckEqual(Int64(1002), Int64(LCode),
        'high-bit-length64: close code protocol error');
      LReason := Copy(LResp, 5, LPayloadLen - 2);
      CheckEqual('WebSocket: invalid 64-bit payload length', LReason,
        'high-bit-length64: fail-fast reason');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4p: websocket options bound frame allocation before payload read }
procedure TestWebSocketMaxFrameSizeRejectsDeclaredOversizeFrame;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LFrame: string;
  LPayloadLen: Byte;
  LCode: UInt16;
  LReason: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LOptions: TWebSocketOptions;
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LOptions := TWebSocketOptions.Default;
    CheckEqual(Int64(WEBSOCKET_DEFAULT_MAX_FRAME_SIZE), LOptions.MaxFrameSize,
      'websocket-options: default max frame size');
    CheckEqual(Int64(WEBSOCKET_DEFAULT_MAX_MESSAGE_SIZE), LOptions.MaxMessageSize,
      'websocket-options: default max message size');
    LOptions.MaxFrameSize := 16;
    LOptions.MaxMessageSize := 32;
    LWs := UpgradeWebSocket(AReq, AW, LOptions);
    try
      LF := LWs.ReadFrame;
      if LF.Opcode = wsOpText then
        LWs.WriteText(UTF8BytesToString(LF.Payload));
    except
      on E: EHttpError do
        LWs.Close(1009, E.Message);
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('HTTP/1.1 101', LResp) > 0, 'max-frame-size: got 101');

      LFrame := BuildMaskedFrameWithDeclaredLength64($01, 65536);
      LConn.Write(LFrame[1], SizeUInt(Length(LFrame)));

      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Length(LResp) >= 4) or (LN = 0);

      Check(Length(LResp) >= 4, 'max-frame-size: got close response');
      Check(Ord(LResp[1]) = $88, 'max-frame-size: server sends close frame');
      LPayloadLen := Ord(LResp[2]) and $7F;
      Check(LPayloadLen >= 2, 'max-frame-size: close frame includes code');
      LCode := (UInt16(Ord(LResp[3])) shl 8) or UInt16(Ord(LResp[4]));
      CheckEqual(Int64(1009), Int64(LCode),
        'max-frame-size: close code message too big');
      LReason := Copy(LResp, 5, LPayloadLen - 2);
      CheckEqual('WebSocket: frame too large', LReason,
        'max-frame-size: fail-fast reason');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4q: websocket options bound accumulated fragmented messages }
procedure TestWebSocketMaxMessageSizeRejectsFragmentedMessage;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LFrame1: string;
  LFrame2: string;
  LPayloadLen: Byte;
  LCode: UInt16;
  LReason: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LOptions: TWebSocketOptions;
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LOptions := TWebSocketOptions.Default;
    LOptions.MaxFrameSize := 16;
    LOptions.MaxMessageSize := 3;
    LWs := UpgradeWebSocket(AReq, AW, LOptions);
    try
      LF := LWs.ReadFrame;
      if (LF.Opcode = wsOpText) and (not LF.Fin) then
      begin
        LF := LWs.ReadFrame;
        if (LF.Opcode = wsOpContinuation) and LF.Fin then
          LWs.WriteText('ok');
      end;
    except
      on E: EHttpError do
        LWs.Close(1009, E.Message);
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('HTTP/1.1 101', LResp) > 0, 'max-message-size: got 101');

      LFrame1 := BuildMaskedFrameWithFin($01, 'ab', False);
      LFrame2 := BuildMaskedFrame($00, 'cd');
      LConn.Write(LFrame1[1], SizeUInt(Length(LFrame1)));
      LConn.Write(LFrame2[1], SizeUInt(Length(LFrame2)));

      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Length(LResp) >= 4) or (LN = 0);

      Check(Length(LResp) >= 4, 'max-message-size: got close response');
      Check(Ord(LResp[1]) = $88, 'max-message-size: server sends close frame');
      LPayloadLen := Ord(LResp[2]) and $7F;
      Check(LPayloadLen >= 2, 'max-message-size: close frame includes code');
      LCode := (UInt16(Ord(LResp[3])) shl 8) or UInt16(Ord(LResp[4]));
      CheckEqual(Int64(1009), Int64(LCode),
        'max-message-size: close code message too big');
      LReason := Copy(LResp, 5, LPayloadLen - 2);
      CheckEqual('WebSocket: message too large', LReason,
        'max-message-size: fail-fast reason');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4r: server Ping must not generate oversize control frames }
procedure TestOutgoingPingPayloadTooLargeRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LPayloadLen: Byte;
  LCode: UInt16;
  LReason: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    try
      LWs.Ping(StringToUTF8Bytes(RepeatChar('x', 126)));
      LWs.WriteText('bad');
    except
      on E: EHttpError do
        LWs.Close(1002, E.Message);
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('HTTP/1.1 101', LResp) > 0, 'outgoing-ping-oversize: got 101');

      { Preserve leftover bytes after HTTP headers — the WebSocket frame
        may have arrived in the same TCP segment as the 101 response. }
      LResp := Copy(LResp, Pos(#13#10#13#10, LResp) + 4, Length(LResp));
      while Length(LResp) < 4 do
      begin
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end
        else
          Break;
      end;

      Check(Length(LResp) >= 4, 'outgoing-ping-oversize: got response');
      Check(Ord(LResp[1]) = $88, 'outgoing-ping-oversize: server sends close frame');
      LPayloadLen := Ord(LResp[2]) and $7F;
      Check(LPayloadLen >= 2, 'outgoing-ping-oversize: close frame includes code');
      LCode := (UInt16(Ord(LResp[3])) shl 8) or UInt16(Ord(LResp[4]));
      CheckEqual(Int64(1002), Int64(LCode),
        'outgoing-ping-oversize: close code protocol error');
      LReason := Copy(LResp, 5, LPayloadLen - 2);
      CheckEqual('WebSocket: control frame payload too large', LReason,
        'outgoing-ping-oversize: fail-fast reason');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4s: server Close must reject reasons that exceed control-frame size }
procedure TestOutgoingClosePayloadTooLargeRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LPayloadLen: Byte;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    try
      LWs.Close(1000, RepeatChar('x', 124));
    except
      on E: EHttpError do
      begin
        LWs.WriteText(E.Message);
        LWs.Close(1000, '');
      end;
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('HTTP/1.1 101', LResp) > 0, 'outgoing-close-oversize: got 101');

      { Preserve leftover bytes after HTTP headers — the WebSocket frame
        may have arrived in the same TCP segment as the 101 response. }
      LResp := Copy(LResp, Pos(#13#10#13#10, LResp) + 4, Length(LResp));
      while Length(LResp) < 4 do
      begin
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end
        else
          Break;
      end;

      Check(Length(LResp) >= 4, 'outgoing-close-oversize: got response');
      Check(Ord(LResp[1]) = $81, 'outgoing-close-oversize: server sends text frame');
      LPayloadLen := Ord(LResp[2]) and $7F;
      CheckEqual('WebSocket: control frame payload too large',
        Copy(LResp, 3, LPayloadLen), 'outgoing-close-oversize: fail-fast reason');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure CheckOutgoingCloseRejected(const ACaseName: string; const ACode: UInt16;
  const AReason, AExpectedError: string);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LPayloadLen: Byte;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    try
      LWs.Close(ACode, AReason);
    except
      on E: EHttpError do
        LWs.WriteText(E.Message);
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('HTTP/1.1 101', LResp) > 0, ACaseName + ': got 101');

      { Preserve leftover bytes after HTTP headers — the WebSocket frame
        may have arrived in the same TCP segment as the 101 response. }
      LResp := Copy(LResp, Pos(#13#10#13#10, LResp) + 4, Length(LResp));
      while Length(LResp) < 4 do
      begin
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end
        else
          Break;
      end;

      Check(Length(LResp) >= 4, ACaseName + ': got response');
      Check(Ord(LResp[1]) = $81, ACaseName + ': server sends text frame');
      LPayloadLen := Ord(LResp[2]) and $7F;
      CheckEqual(AExpectedError, Copy(LResp, 3, LPayloadLen),
        ACaseName + ': fail-fast reason');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4t: server Close must reject invalid outbound close codes }
procedure TestOutgoingCloseInvalidCodeRejected;
begin
  CheckOutgoingCloseRejected('outgoing-close-invalid-code', 999, 'bad',
    'WebSocket: invalid close code');
end;

{ Test 4u: server Close must reject invalid outbound close reason encoding }
procedure TestOutgoingCloseInvalidUtf8ReasonRejected;
begin
  CheckOutgoingCloseRejected('outgoing-close-invalid-utf8', 1000, #$C3,
    'WebSocket: invalid close reason encoding');
end;

{ Test 4v: server WriteText must reject invalid outbound UTF-8 payloads }
procedure TestOutgoingTextInvalidUtf8Rejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LPayloadLen: Byte;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    try
      LWs.WriteText(#$C3);
      LWs.WriteText('bad');
    except
      on E: EHttpError do
        LWs.WriteText(E.Message);
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('HTTP/1.1 101', LResp) > 0, 'outgoing-text-invalid-utf8: got 101');

      { Preserve leftover bytes after HTTP headers — the WebSocket frame
        may have arrived in the same TCP segment as the 101 response. }
      LResp := Copy(LResp, Pos(#13#10#13#10, LResp) + 4, Length(LResp));
      while Length(LResp) < 4 do
      begin
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end
        else
          Break;
      end;

      Check(Length(LResp) >= 4, 'outgoing-text-invalid-utf8: got response');
      Check(Ord(LResp[1]) = $81, 'outgoing-text-invalid-utf8: server sends text frame');
      LPayloadLen := Ord(LResp[2]) and $7F;
      CheckEqual('WebSocket: invalid text payload encoding',
        Copy(LResp, 3, LPayloadLen), 'outgoing-text-invalid-utf8: fail-fast reason');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 5: Binary frame }
procedure TestBinaryFrame;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LFrame: string;
  LPayloadLen: Byte;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    LF := LWs.ReadFrame;
    if LF.Opcode = wsOpBinary then
      LWs.WriteBinary(LF.Payload);
    LWs.Close(1000, '');
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;

      { Send masked binary frame: 3 bytes }
      LFrame := BuildMaskedFrame($02, #$DE#$AD#$BE);
      LConn.Write(LFrame[1], SizeUInt(Length(LFrame)));

      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Length(LResp) >= 5) or (LN = 0);

      Check(Length(LResp) >= 5, 'binary: got response');
      Check(Ord(LResp[1]) = $82, 'binary: FIN+binary opcode');
      LPayloadLen := Ord(LResp[2]) and $7F;
      CheckEqual(Int64(3), Int64(LPayloadLen), 'binary: payload len = 3');
      Check(LResp[3] = #$DE, 'binary: byte 0');
      Check(LResp[4] = #$AD, 'binary: byte 1');
      Check(LResp[5] = #$BE, 'binary: byte 2');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 6: Close frame }
procedure TestCloseFrame;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LFrame: string;
  LPayloadLen: Byte;
  LCode: UInt16;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    LF := LWs.ReadFrame;
    { Echo close back }
    if LF.Opcode = wsOpClose then
      LWs.Close(1000, 'bye');
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;

      { Send masked close frame with code 1000 + reason "done" }
      LFrame := BuildMaskedFrame($08, #$03#$E8'done');
      LConn.Write(LFrame[1], SizeUInt(Length(LFrame)));

      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Length(LResp) >= 7) or (LN = 0);

      Check(Length(LResp) >= 7, 'close: got response');
      Check(Ord(LResp[1]) = $88, 'close: FIN+close opcode');
      LPayloadLen := Ord(LResp[2]) and $7F;
      Check(LPayloadLen >= 2, 'close: payload has code');
      LCode := (UInt16(Ord(LResp[3])) shl 8) or UInt16(Ord(LResp[4]));
      CheckEqual(Int64(1000), Int64(LCode), 'close: code = 1000');
      Check(Pos('bye', Copy(LResp, 5, LPayloadLen - 2)) > 0, 'close: reason = bye');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Origin check callbacks (must be standalone, not nested) }
function RejectAllOrigins(const AOrigin: string): Boolean;
begin
  Result := False;
end;

function AcceptAllOrigins(const AOrigin: string): Boolean;
begin
  Result := True;
end;

{ Test: Origin validation rejects disallowed origin }
procedure TestOriginValidationRejectsDisallowed;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LKey: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LOptions: TWebSocketOptions;
    LWs: IWebSocket;
  begin
    LOptions := TWebSocketOptions.Default;
    LOptions.OnCheckOrigin := @RejectAllOrigins;
    try
      LWs := UpgradeWebSocket(AReq, AW, LOptions);
      LWs.Close(1000, 'ok');
    except
      on E: EHttpError do
      begin
        AW.GetHeaders.SetHeader('content-length', '0');
        AW.WriteHeader(HTTP_STATUS_FORBIDDEN);
      end;
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LResp := SendRawAndRead(LPort,
      'GET /ws HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Upgrade: websocket'#13#10 +
      'Connection: Upgrade'#13#10 +
      'Sec-WebSocket-Key: ' + LKey + #13#10 +
      'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://evil.com'#13#10 +
      #13#10, 256);
    Check(Pos('HTTP/1.1 403', LResp) > 0, 'origin-reject: should get 403');
    Check(Pos('HTTP/1.1 101', LResp) = 0, 'origin-reject: should not upgrade');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test: Origin validation accepts allowed origin }
procedure TestOriginValidationAcceptsAllowed;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LKey: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LOptions: TWebSocketOptions;
    LWs: IWebSocket;
  begin
    LOptions := TWebSocketOptions.Default;
    LOptions.OnCheckOrigin := @AcceptAllOrigins;
    try
      LWs := UpgradeWebSocket(AReq, AW, LOptions);
      LWs.Close(1000, 'ok');
    except
      on E: EHttpError do
      begin
        AW.GetHeaders.SetHeader('content-length', '0');
        AW.WriteHeader(HTTP_STATUS_BAD_REQUEST);
      end;
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LResp := SendRawAndRead(LPort,
      'GET /ws HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Upgrade: websocket'#13#10 +
      'Connection: Upgrade'#13#10 +
      'Sec-WebSocket-Key: ' + LKey + #13#10 +
      'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://example.com'#13#10 +
      #13#10, 256);
    Check(Pos('HTTP/1.1 101', LResp) > 0, 'origin-accept: should get 101');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Wave I2: server with EnablePermessageDeflate accepts client offer. }
procedure TestPermessageDeflateHandshakeAccepted;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LKey: string;
  LOpts: TWebSocketOptions;
begin
  LOpts := TWebSocketOptions.Default.WithEnablePermessageDeflate(True);
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
  begin
    LWs := UpgradeWebSocket(AReq, AW, LOpts);
    LWs.Close(1000, 'ok');
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LResp := SendRawAndRead(LPort,
      'GET /ws HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Upgrade: websocket'#13#10 +
      'Connection: Upgrade'#13#10 +
      'Sec-WebSocket-Key: ' + LKey + #13#10 +
      'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://example.com'#13#10 +
      'Sec-WebSocket-Extensions: permessage-deflate; client_no_context_takeover; ' +
      'server_no_context_takeover'#13#10 +
      #13#10, 512);
    Check(Pos('HTTP/1.1 101', LResp) > 0, 'pmd accept: got 101');
    Check(Pos('permessage-deflate', LowerCase(LResp)) > 0,
      'pmd accept: response includes permessage-deflate');
    Check(Pos('client_no_context_takeover', LowerCase(LResp)) > 0,
      'pmd accept: no context takeover');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Wave I2: default options do not negotiate deflate even if client offers. }
procedure TestPermessageDeflateNotNegotiatedByDefault;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LKey: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    LWs.Close(1000, 'ok');
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LResp := SendRawAndRead(LPort,
      'GET /ws HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Upgrade: websocket'#13#10 +
      'Connection: Upgrade'#13#10 +
      'Sec-WebSocket-Key: ' + LKey + #13#10 +
      'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: http://example.com'#13#10 +
      'Sec-WebSocket-Extensions: permessage-deflate'#13#10 +
      #13#10, 512);
    Check(Pos('HTTP/1.1 101', LResp) > 0, 'pmd default: got 101');
    Check(Pos('permessage-deflate', LowerCase(LResp)) = 0,
      'pmd default: must not accept extension without opt-in');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Wave I2: RSV1 data frame accepted and decompressed after negotiation. }
procedure TestPermessageDeflateCompressedTextEcho;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq, LFrame, LResp: string;
  LBuf: array[0..8191] of Byte;
  LN: SizeUInt;
  LOpts: TWebSocketOptions;
  LPlain, LComp: TBytes;
  LPayload: string;
  I: SizeInt;
  LHdr: string;
  LMask: array[0..3] of Byte;
  LPayloadStart: Integer;
  LLen: Byte;
  LOut: string;
begin
  LOpts := TWebSocketOptions.Default.WithEnablePermessageDeflate(True);
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW, LOpts);
    LF := LWs.ReadFrame;
    if LF.Opcode = wsOpText then
      LWs.WriteText(UTF8BytesToString(LF.Payload));
    LWs.Close(1000, '');
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
            'Origin: http://localhost'#13#10 +
            'Sec-WebSocket-Extensions: permessage-deflate; client_no_context_takeover; ' +
            'server_no_context_takeover'#13#10 +
            #13#10;
    LPlain := StringToUTF8Bytes(RepeatChar('Z', 200));
    LComp := nextpas.core.compress.deflate.RawDeflateMessageCompress(LPlain);
    Check(Length(LComp) > 0, 'pmd echo: compressed payload non-empty');
    Check(Length(LComp) < Length(LPlain), 'pmd echo: compression shrinks');

    LMask[0] := $12; LMask[1] := $34; LMask[2] := $56; LMask[3] := $78;
    SetLength(LHdr, 6);
    LHdr[1] := Chr($C1); { FIN + RSV1 + text }
    LHdr[2] := Chr($80 or Length(LComp));
    LHdr[3] := Chr(LMask[0]);
    LHdr[4] := Chr(LMask[1]);
    LHdr[5] := Chr(LMask[2]);
    LHdr[6] := Chr(LMask[3]);
    LPayload := LHdr;
    for I := 0 to High(LComp) do
      LPayload := LPayload + Chr(LComp[I] xor LMask[I mod 4]);
    LFrame := LPayload;

    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('HTTP/1.1 101', LResp) > 0, 'pmd echo: got 101');
      Check(Pos('permessage-deflate', LowerCase(LResp)) > 0, 'pmd echo: negotiated');

      LConn.Write(LFrame[1], SizeUInt(Length(LFrame)));
      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Length(LResp) >= 4) or (LN = 0);

      Check(Length(LResp) >= 2, 'pmd echo: got frame');
      { Server may reply with RSV1 compressed or plain if not smaller. }
      Check((Ord(LResp[1]) and $0F) = $01, 'pmd echo: text opcode');
      LLen := Ord(LResp[2]) and $7F;
      Check(LLen > 0, 'pmd echo: payload present');
      LPayloadStart := 3;
      if (Ord(LResp[1]) and $40) <> 0 then
      begin
        SetLength(LComp, LLen);
        Move(LResp[LPayloadStart], LComp[0], LLen);
        LPlain := nextpas.core.compress.deflate.RawDeflateMessageDecompress(
          LComp, 65536);
        LOut := UTF8BytesToString(LPlain);
      end
      else
        LOut := Copy(LResp, LPayloadStart, LLen);
      CheckEqual(RepeatChar('Z', 200), LOut, 'pmd echo: decompressed text');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test: Origin: null rejected by default (no OnCheckOrigin) }
procedure TestOriginNullRejectedByDefault;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LKey: string;
begin
  LRouter := THttpRouter.Create;
  { No OnCheckOrigin set — default behavior should reject Origin: null }
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
  begin
    try
      LWs := UpgradeWebSocket(AReq, AW);
      LWs.Close(1000, 'ok');
    except
      on E: EHttpError do
      begin
        AW.GetHeaders.SetHeader('content-length', '0');
        AW.WriteHeader(HTTP_STATUS_FORBIDDEN);
      end;
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LResp := SendRawAndRead(LPort,
      'GET /ws HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Upgrade: websocket'#13#10 +
      'Connection: Upgrade'#13#10 +
      'Sec-WebSocket-Key: ' + LKey + #13#10 +
      'Sec-WebSocket-Version: 13'#13#10 +
      'Origin: null'#13#10 +
      #13#10, 256);
    Check(Pos('HTTP/1.1 403', LResp) > 0, 'Origin: null must be rejected by default');
    Check(Pos('HTTP/1.1 101', LResp) = 0, 'Origin: null must not upgrade');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test (B7 G1): server shutdown wakes a blocked WS read loop and the session
  teardown sends close frame 1001 going-away; connection is closed when
  Shutdown returns. }
procedure TestShutdownSendsGoingAwayClose;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq, LResp: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LPayloadLen: Integer;
  LCode: Integer;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    { 阻塞读循环（与 pascn realtime handler 同构）：shutdown 唤醒后退出，
      Destroy 收尾路径补发 close 1001。 }
    while True do
    begin
      try
        LF := LWs.ReadMessage;
      except
        Break;
      end;
      if LF.Opcode = wsOpClose then
        Break;
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
            'Origin: http://localhost'#13#10 +
            #13#10;
    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('101', LResp) > 0, 'shutdown-close: got 101');

      { 服务器 shutdown：waitable cancel 唤醒连接线程 → 收尾补发 close 1001。
        Shutdown 内部等待会话收尾完成后返回。 }
      LServer.Shutdown;

      { 客户端应收到 FIN+close 帧（首字节 $88），payload 前两字节 = 1001 }
      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Length(LResp) >= 2) or (LN = 0);
      Check(Length(LResp) >= 2, 'shutdown-close: received frame bytes');
      if Length(LResp) >= 2 then
      begin
        Check(Ord(LResp[1]) = $88, 'shutdown-close: FIN+close opcode');
        LPayloadLen := Ord(LResp[2]) and $7F;
        if Length(LResp) >= 2 + LPayloadLen then
        begin
          LCode := (Ord(LResp[3]) shl 8) or Ord(LResp[4]);
          CheckEqual(1001, LCode, 'shutdown-close: code 1001 going away');
        end
        else
          Check(False, 'shutdown-close: close frame payload incomplete');
      end;
      { shutdown 返回后连接应已关闭：后续读为 EOF }
      try
        LN := LConn.Read(LBuf[0], 4096);
      except
        LN := 0;
      end;
      Check(LN = 0, 'shutdown-close: EOF after shutdown returns');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test (B7 G2): server-side teardown without an explicit Close sends close
  frame 1001 going-away before the connection closes. }
procedure TestTeardownSendsGoingAwayClose;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq, LResp: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LPayloadLen: Integer;
  LCode: Integer;
  LPos: SizeInt;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    { 不显式 Close，直接返回：Destroy 收尾路径应补发 close 1001。 }
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
            'Origin: http://localhost'#13#10 +
            #13#10;
    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('101', LResp) > 0, 'teardown-close: got 101');

      { 保留 101 头之后已到达的残余字节：close frame 可能与 101 同段
        到达（loopback 合并段），重置会丢失它。 }
      LPos := Pos(#13#10#13#10, LResp) + 4;
      LResp := Copy(LResp, LPos, MaxInt);

      { 读至 EOF：应包含一个 close frame（1001），随后连接关闭 }
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
      Check(Length(LResp) >= 4, 'teardown-close: received close frame');
      if Length(LResp) >= 4 then
      begin
        Check(Ord(LResp[1]) = $88, 'teardown-close: FIN+close opcode');
        LPayloadLen := Ord(LResp[2]) and $7F;
        if Length(LResp) >= 2 + LPayloadLen then
        begin
          LCode := (Ord(LResp[3]) shl 8) or Ord(LResp[4]);
          CheckEqual(1001, LCode, 'teardown-close: code 1001 going away');
        end
        else
          Check(False, 'teardown-close: close frame payload incomplete');
      end;
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test (B7 G2b): an explicit Close(1000) must not be followed by a second
  close frame on teardown. }
procedure TestExplicitCloseSendsSingleCloseFrame;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq, LResp: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LPos: SizeInt;
  LOp: Byte;
  LFrameLen: Integer;
  LCloseCount: Integer;
  LCode: Integer;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    LWs.Close(1000, 'bye');
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
            'Origin: http://localhost'#13#10 +
            #13#10;
    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('101', LResp) > 0, 'single-close: got 101');

      { 保留 101 头之后的残余字节：close frame 可能与 101 同段到达。 }
      LPos := Pos(#13#10#13#10, LResp) + 4;
      LResp := Copy(LResp, LPos, MaxInt);

      { 读至 EOF，逐帧统计 close 帧（$88）：必须恰好一个 }
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
      LCloseCount := 0;
      LPos := 1;
      while LPos + 1 <= Length(LResp) do
      begin
        LOp := Ord(LResp[LPos]);
        LFrameLen := Ord(LResp[LPos + 1]) and $7F;
        if LOp = $88 then
        begin
          Inc(LCloseCount);
          if LPos + 3 <= Length(LResp) then
            LCode := (Ord(LResp[LPos + 2]) shl 8) or Ord(LResp[LPos + 3])
          else
            LCode := -1;
        end;
        Inc(LPos, 2 + LFrameLen);
      end;
      CheckEqual(1, LCloseCount, 'single-close: exactly one close frame');
      CheckEqual(1000, LCode, 'single-close: code 1000 normal closure');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test (B7 G3): server write timeout fires when the peer stops reading and
  fills the OS send buffer; the write raises instead of blocking forever. }
procedure TestServerWriteTimeoutKicksSlowClient;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq, LResp: string;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LPayload: TBytes;
begin
  SetLength(LPayload, 16777216);
  FillChar(LPayload[0], Length(LPayload), Ord('A'));
  InterlockedExchange(G3WriteTimeoutHit, 0);
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LOpts: TWebSocketOptions;
  begin
    LOpts := TWebSocketOptions.Default.WithWriteTimeout(200);
    LWs := UpgradeWebSocket(AReq, AW, LOpts);
    try
      { 16MB 单帧：对端不读 → OS 发送缓冲满 → 200ms 写超时抛错 }
      LWs.WriteBinary(LPayload);
    except
      on E: Exception do
        InterlockedExchange(G3WriteTimeoutHit, 1);
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
            'Origin: http://localhost'#13#10 +
            #13#10;
    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('101', LResp) > 0, 'write-timeout: got 101');

      { 故意不读：让服务端 16MB 写阻塞并触发 200ms 写超时 }
      platform_thread_sleep_ns(1500000000);

      { 读至 EOF（缓冲的 partial 数据 + 连接关闭） }
      LResp := '';
      repeat
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
      CheckEqual(1, InterlockedExchange(G3WriteTimeoutHit, 0),
        'write-timeout: handler observed write timeout');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ F-7 回归：升级后的连接不得继承 h1 每请求读死线。
  用例 1（带流量）：IdleTimeout=400ms 的服务器上持续收发约 1.5s（>3 倍超时窗），
  每帧都应得到回声——修复前连接在 ~400ms 被绝对死线掐断，第二轮即失败。 }
procedure TestUpgradedConnectionSurvivesPastIdleTimeout;
const
  IDLE_MS = 400;
  ROUNDS = 6;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq, LResp, LFrame: string;
  LBuf: array[0..1023] of Byte;
  LN: SizeUInt;
  I: Integer;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    repeat
      try
        LF := LWs.ReadFrame;
      except
        Exit;
      end;
      if LF.Opcode = wsOpClose then
      begin
        LWs.Close(1000, '');
        Exit;
      end;
      if LF.Opcode = wsOpText then
        LWs.WriteText(UTF8BytesToString(LF.Payload));
    until False;
  end);
  LHandle := StartServerWithOpts(LRouter as IHttpHandler,
    THttpServerOptions.Default.WithReadTimeout(IDLE_MS), LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
            'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], SizeOf(LBuf));
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('101', LResp) > 0, 'idle-survive: got 101');

      for I := 1 to ROUNDS do
      begin
        LFrame := BuildMaskedFrame($01, 'r' + IntToStr(I));
        LConn.Write(LFrame[1], SizeUInt(Length(LFrame)));
        { 每轮独立读期限：EOF（服务器掐线）或读超时都算失败 }
        LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(2)));
        LResp := '';
        repeat
          LN := 0;
          try
            LN := LConn.Read(LBuf[0], SizeOf(LBuf));
          except
            LN := 0;
          end;
          if LN > 0 then
          begin
            SetLength(LResp, Length(LResp) + Int32(LN));
            Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
          end;
        until (Length(LResp) >= 4) or (LN = 0);
        Check(Length(LResp) >= 4,
          'idle-survive: round ' + IntToStr(I) + ' got echo frame');
        if Length(LResp) >= 4 then
        begin
          Check(Ord(LResp[1]) = $81, 'idle-survive: FIN+text opcode');
          Check(Copy(LResp, 3, 2) = 'r' + IntToStr(I),
            'idle-survive: round ' + IntToStr(I) + ' payload matches');
        end
        else
          Break;
        platform_thread_sleep_ns(250000000);
      end;
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ 用例 2（静默）：升级后不发任何帧静置 3 倍超时窗，再发一帧仍应得到回声——
  证明移除的是绝对死线而非仅活跃期续命。 }
procedure TestSilentUpgradedConnectionSurvivesPastIdleTimeout;
const
  IDLE_MS = 400;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LKey, LReq, LResp, LFrame: string;
  LBuf: array[0..1023] of Byte;
  LN: SizeUInt;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ws', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LWs: IWebSocket;
    LF: TWebSocketFrame;
  begin
    LWs := UpgradeWebSocket(AReq, AW);
    repeat
      try
        LF := LWs.ReadFrame;
      except
        Exit;
      end;
      if LF.Opcode = wsOpClose then
      begin
        LWs.Close(1000, '');
        Exit;
      end;
      if LF.Opcode = wsOpText then
        LWs.WriteText(UTF8BytesToString(LF.Payload));
    until False;
  end);
  LHandle := StartServerWithOpts(LRouter as IHttpHandler,
    THttpServerOptions.Default.WithReadTimeout(IDLE_MS), LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LReq := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + LKey + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
            'Origin: http://localhost'#13#10 +
            #13#10;

    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      repeat
        LN := LConn.Read(LBuf[0], SizeOf(LBuf));
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until Pos(#13#10#13#10, LResp) > 0;
      Check(Pos('101', LResp) > 0, 'silent-survive: got 101');

      platform_thread_sleep_ns(1200000000);

      LFrame := BuildMaskedFrame($01, 'still-alive');
      LConn.Write(LFrame[1], SizeUInt(Length(LFrame)));
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(2)));
      LResp := '';
      repeat
        LN := 0;
        try
          LN := LConn.Read(LBuf[0], SizeOf(LBuf));
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (Pos('still-alive', LResp) > 0) or (LN = 0);
      Check(Pos('still-alive', LResp) > 0,
        'silent-survive: connection alive and echoing after idle window');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Main }
begin
  T := TTestSuite.Create('http.websocket');
  T.Test('HandshakeSuccess', @TestHandshakeSuccess);
  T.Test('WebSocketAcceptGuidSourceContract',
    @TestWebSocketAcceptGuidSourceContract);
  T.Test('WebSocketWriteAllSourceContract',
    @TestWebSocketWriteAllSourceContract);
  T.Test('HandshakeNoUpgrade', @TestHandshakeNoUpgrade);
  T.Test('HandshakeNoKey', @TestHandshakeNoKey);
  T.Test('HandshakeInvalidKeyRejected', @TestHandshakeInvalidKeyRejected);
  T.Test('HandshakeConnectionUpgradeTokenRequired',
    @TestHandshakeConnectionUpgradeTokenRequired);
  T.Test('HandshakeAcceptsDuplicateConnectionUpgradeToken',
    @TestHandshakeAcceptsDuplicateConnectionUpgradeToken);
  T.Test('TextFrameEcho', @TestTextFrameEcho);
  T.Test('TextFrameEchoCoalescedFirstFrame', @TestTextFrameEchoWithCoalescedFirstFrame);
  T.Test('ReadMessagePreservesFragmentedOpcode',
    @TestReadMessagePreservesFragmentedOpcode);
  T.Test('NegativeWebSocketOptionsRejected',
    @TestNegativeWebSocketOptionsRejected);
  T.Test('UpgradeExceptionDoesNotWrite500OrCloseOwnedWebSocket',
    @TestUpgradeExceptionDoesNotWrite500OrCloseOwnedWebSocket);
  T.Test('UnmaskedClientFrameRejected', @TestUnmaskedClientFrameRejected);
  T.Test('ControlFramePayloadTooLargeRejected', @TestControlFramePayloadTooLargeRejected);
  T.Test('ReservedOpcodeRejected', @TestReservedOpcodeRejected);
  T.Test('ReservedBitsRejected', @TestReservedBitsRejected);
  T.Test('FragmentedControlFrameRejected', @TestFragmentedControlFrameRejected);
  T.Test('InvalidCloseCodeRejected', @TestInvalidCloseCodeRejected);
  T.Test('InvalidUtf8TextFrameRejected', @TestInvalidUtf8TextFrameRejected);
  T.Test('InvalidUtf8CloseReasonRejected', @TestInvalidUtf8CloseReasonRejected);
  T.Test('StandaloneContinuationFrameRejected', @TestStandaloneContinuationFrameRejected);
  T.Test('FragmentedTextUtf8SequenceAccepted', @TestFragmentedTextUtf8SequenceAccepted);
  T.Test('NonCanonicalPayloadLengthRejected', @TestNonCanonicalPayloadLengthRejected);
  T.Test('NonCanonicalPayloadLength64Rejected', @TestNonCanonicalPayloadLength64Rejected);
  T.Test('HighBitPayloadLength64Rejected', @TestHighBitPayloadLength64Rejected);
  T.Test('WebSocketMaxFrameSizeRejectsDeclaredOversizeFrame',
    @TestWebSocketMaxFrameSizeRejectsDeclaredOversizeFrame);
  T.Test('WebSocketMaxMessageSizeRejectsFragmentedMessage',
    @TestWebSocketMaxMessageSizeRejectsFragmentedMessage);
  T.Test('OutgoingPingPayloadTooLargeRejected', @TestOutgoingPingPayloadTooLargeRejected);
  T.Test('OutgoingClosePayloadTooLargeRejected', @TestOutgoingClosePayloadTooLargeRejected);
  T.Test('OutgoingCloseInvalidCodeRejected', @TestOutgoingCloseInvalidCodeRejected);
  T.Test('OutgoingCloseInvalidUtf8ReasonRejected',
    @TestOutgoingCloseInvalidUtf8ReasonRejected);
  T.Test('OutgoingTextInvalidUtf8Rejected', @TestOutgoingTextInvalidUtf8Rejected);
  T.Test('BinaryFrame', @TestBinaryFrame);
  T.Test('CloseFrame', @TestCloseFrame);
  T.Test('ShutdownSendsGoingAwayClose', @TestShutdownSendsGoingAwayClose);
  T.Test('TeardownSendsGoingAwayClose', @TestTeardownSendsGoingAwayClose);
  T.Test('ExplicitCloseSendsSingleCloseFrame',
    @TestExplicitCloseSendsSingleCloseFrame);
  T.Test('ServerWriteTimeoutKicksSlowClient',
    @TestServerWriteTimeoutKicksSlowClient);
  T.Test('OriginValidationRejectsDisallowed', @TestOriginValidationRejectsDisallowed);
  T.Test('OriginValidationAcceptsAllowed', @TestOriginValidationAcceptsAllowed);
  T.Test('OriginNullRejectedByDefault', @TestOriginNullRejectedByDefault);
  T.Test('PermessageDeflateHandshakeAccepted',
    @TestPermessageDeflateHandshakeAccepted);
  T.Test('PermessageDeflateNotNegotiatedByDefault',
    @TestPermessageDeflateNotNegotiatedByDefault);
  T.Test('PermessageDeflateCompressedTextEcho',
    @TestPermessageDeflateCompressedTextEcho);
  T.Test('UpgradedConnectionSurvivesPastIdleTimeout',
    @TestUpgradedConnectionSurvivesPastIdleTimeout);
  T.Test('SilentUpgradedConnectionSurvivesPastIdleTimeout',
    @TestSilentUpgradedConnectionSurvivesPastIdleTimeout);
  if not T.Run then Halt(1);
end.
