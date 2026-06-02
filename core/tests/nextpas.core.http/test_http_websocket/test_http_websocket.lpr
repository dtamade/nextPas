program test_http_websocket;

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
  nextpas.core.http.router,
  nextpas.core.http.server,
  nextpas.core.http.websocket,
  nextpas.core.hash,
  nextpas.core.hash.base,
  nextpas.core.encoding,
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

function ComputeExpectedAccept(const AKey: string): string;
var
  LConcat: string;
  LDigest: TSHA1Digest;
  LBytes: TBytes;
begin
  LConcat := AKey + '258EAFA5-E914-47DA-95CA-5AB53DC85B11';
  LDigest := SHA1Of(LConcat[1], SizeUInt(Length(LConcat)));
  SetLength(LBytes, SHA1_DIGEST_SIZE);
  Move(LDigest[0], LBytes[0], SHA1_DIGEST_SIZE);
  Result := Base64Encode(LBytes);
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
  LKey, LExpectedAccept: string;
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
        AW.GetHeaders.Set_('content-length', '0');
        AW.WriteHeader(HTTP_STATUS_BAD_REQUEST);
      end;
    end;
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LKey := 'dGhlIHNhbXBsZSBub25jZQ==';
    LExpectedAccept := ComputeExpectedAccept(LKey);
    LResp := SendRawAndRead(LPort,
      'GET /ws HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Upgrade: websocket'#13#10 +
      'Connection: Upgrade'#13#10 +
      'Sec-WebSocket-Key: ' + LKey + #13#10 +
      'Sec-WebSocket-Version: 13'#13#10 +
      #13#10, 256);
    Check(Pos('HTTP/1.1 101', LResp) > 0, 'should get 101 status');
    Check(Pos('Sec-WebSocket-Accept: ' + LExpectedAccept, LResp) > 0, 'should have correct accept key');
  finally
    StopServer(LServer, LHandle);
  end;
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
        AW.GetHeaders.Set_('content-length', '0');
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
        AW.GetHeaders.Set_('content-length', '0');
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
      #13#10, 256);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'should get 400 without Key');
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
      LWs.WriteText(LF.Payload);
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
      LWs.WriteText(LF.Payload);
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

{ Main }
begin
  T := TTestRunner.Create('http.websocket');
  T.Run('HandshakeSuccess', @TestHandshakeSuccess);
  T.Run('HandshakeNoUpgrade', @TestHandshakeNoUpgrade);
  T.Run('HandshakeNoKey', @TestHandshakeNoKey);
  T.Run('TextFrameEcho', @TestTextFrameEcho);
  T.Run('TextFrameEchoCoalescedFirstFrame', @TestTextFrameEchoWithCoalescedFirstFrame);
  T.Run('BinaryFrame', @TestBinaryFrame);
  T.Run('CloseFrame', @TestCloseFrame);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
