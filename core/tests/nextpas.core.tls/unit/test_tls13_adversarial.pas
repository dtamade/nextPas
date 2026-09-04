program test_tls13_adversarial;

{$mode objfpc}{$H+}{$J-}

uses
  nextpas.core.thread.init,
  nextpas.core.platform.socket, nextpas.core.platform.signal,
  nextpas.core.system.sysutils, nextpas.core.system.classes,
  nextpas.core.tls.base,
  nextpas.core.tls.freepascal.lib;

var
  LTotal, LPassed: Integer;

procedure Check(ACondition: Boolean; const AName: string);
begin
  Inc(LTotal);
  if ACondition then begin Inc(LPassed); WriteLn('  PASS: ', AName); end
  else begin WriteLn('  FAIL: ', AName); Halt(1); end;
end;

{$IFDEF UNIX}
procedure IgnoreSIGPIPE;
begin
  platform_signal_ignore(PLATFORM_SIGPIPE);
end;
{$ENDIF}

function CreateListenSocket(APort: Word): TPlatformSocket;
var LAddr: TPlatformSockAddr; LOptVal: LongInt;
begin
  if platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0,
    Result) <> 0 then
    Exit(PLATFORM_INVALID_SOCKET);
  LOptVal := 1;
  platform_socket_setsockopt(Result, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_REUSEADDR, @LOptVal, SizeOf(LOptVal));
  platform_sockaddr_loopback4(APort, LAddr);
  if platform_socket_bind(Result, @LAddr.Storage[0], LAddr.Len) <> 0 then
  begin
    platform_socket_close(Result);
    Exit(PLATFORM_INVALID_SOCKET);
  end;
  if platform_socket_listen(Result, 5) <> 0 then
  begin
    platform_socket_close(Result);
    Exit(PLATFORM_INVALID_SOCKET);
  end;
end;

function ConnectTo(APort: Word): TPlatformSocket;
var LAddr: TPlatformSockAddr;
begin
  if platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0,
    Result) <> 0 then
    Exit(PLATFORM_INVALID_SOCKET);
  platform_socket_set_timeout(Result, PLATFORM_SO_RCVTIMEO, 2000);
  platform_socket_set_timeout(Result, PLATFORM_SO_SNDTIMEO, 2000);
  platform_sockaddr_loopback4(APort, LAddr);
  if platform_socket_connect(Result, @LAddr.Storage[0], LAddr.Len) <> 0 then
  begin
    platform_socket_close(Result);
    Exit(PLATFORM_INVALID_SOCKET);
  end;
end;

procedure SendAndClose(AListenSock: TPlatformSocket; const AData: array of Byte);
var LSock: TPlatformSocket; LAddr: TPlatformSockAddr; LAddrLen: Int32;
  LSent: Int32;
begin
  LAddr.Clear;
  LAddrLen := SizeOf(LAddr.Storage);
  if platform_socket_accept(AListenSock, @LAddr.Storage[0], @LAddrLen,
    LSock) <> 0 then
    Exit;
  if Length(AData) > 0 then
    platform_socket_send(LSock, @AData[0], Length(AData), 0, LSent);
  platform_socket_shutdown(LSock, PLATFORM_SHUT_RDWR);
  platform_socket_close(LSock);
end;

procedure TestTruncatedServerHello;
var
  LLib: ISSLLibrary; LCtx: ISSLContext; LConn: ISSLConnection;
  LListenSock, LClientSock: TPlatformSocket;
  LPort: Word;
  LBadSH: array[0..9] of Byte;
begin
  WriteLn('TestTruncatedServerHello');
  LPort := 44700;
  LLib := TFreePascalSSLLibrary.Create; LLib.Initialize;
  LCtx := LLib.CreateContext(sslCtxClient);
  LCtx.SetProtocolVersions([sslProtocolTLS13]);
  LCtx.SetVerifyMode([]);

  LListenSock := CreateListenSocket(LPort);
  LClientSock := ConnectTo(LPort);

  // Send truncated TLS record (valid header, short body)
  LBadSH[0] := $16; LBadSH[1] := $03; LBadSH[2] := $03;
  LBadSH[3] := $00; LBadSH[4] := $05; // length = 5 (too short for ServerHello)
  LBadSH[5] := $02; LBadSH[6] := $00; LBadSH[7] := $00;
  LBadSH[8] := $01; LBadSH[9] := $00;
  SendAndClose(LListenSock, LBadSH);

  LConn := LCtx.CreateConnection(THandle(LClientSock.Value));
  try
    Check(not LConn.Connect, 'Truncated ServerHello rejected');
  except
    on E: Exception do
      Check(True, 'Truncated ServerHello raised: ' + E.ClassName);
  end;

  LConn := nil;
  platform_socket_close(LClientSock); platform_socket_close(LListenSock);
  LCtx := nil; LLib.Finalize; LLib := nil;
end;

procedure TestWrongContentType;
var
  LLib: ISSLLibrary; LCtx: ISSLContext; LConn: ISSLConnection;
  LListenSock, LClientSock: TPlatformSocket;
  LPort: Word;
  LBad: array[0..9] of Byte;
begin
  WriteLn('TestWrongContentType');
  LPort := 44701;
  LLib := TFreePascalSSLLibrary.Create; LLib.Initialize;
  LCtx := LLib.CreateContext(sslCtxClient);
  LCtx.SetProtocolVersions([sslProtocolTLS13]);
  LCtx.SetVerifyMode([]);

  LListenSock := CreateListenSocket(LPort);
  LClientSock := ConnectTo(LPort);

  // Send alert content type instead of handshake
  LBad[0] := $15; // alert
  LBad[1] := $03; LBad[2] := $03;
  LBad[3] := $00; LBad[4] := $02; // length = 2
  LBad[5] := $02; LBad[6] := $28; // fatal, handshake_failure
  SendAndClose(LListenSock, LBad);

  LConn := LCtx.CreateConnection(THandle(LClientSock.Value));
  try
    Check(not LConn.Connect, 'Alert instead of ServerHello rejected');
  except
    on E: Exception do
      Check(True, 'Alert raised: ' + E.ClassName);
  end;

  LConn := nil;
  platform_socket_close(LClientSock); platform_socket_close(LListenSock);
  LCtx := nil; LLib.Finalize; LLib := nil;
end;

procedure TestZeroLengthRecord;
var
  LLib: ISSLLibrary; LCtx: ISSLContext; LConn: ISSLConnection;
  LListenSock, LClientSock: TPlatformSocket;
  LPort: Word;
  LBad: array[0..4] of Byte;
begin
  WriteLn('TestZeroLengthRecord');
  LPort := 44702;
  LLib := TFreePascalSSLLibrary.Create; LLib.Initialize;
  LCtx := LLib.CreateContext(sslCtxClient);
  LCtx.SetProtocolVersions([sslProtocolTLS13]);
  LCtx.SetVerifyMode([]);

  LListenSock := CreateListenSocket(LPort);
  LClientSock := ConnectTo(LPort);

  // Zero-length handshake record
  LBad[0] := $16; LBad[1] := $03; LBad[2] := $03;
  LBad[3] := $00; LBad[4] := $00;
  SendAndClose(LListenSock, LBad);

  LConn := LCtx.CreateConnection(THandle(LClientSock.Value));
  try
    Check(not LConn.Connect, 'Zero-length record rejected');
  except
    on E: Exception do
      Check(True, 'Zero-length raised: ' + E.ClassName);
  end;

  LConn := nil;
  platform_socket_close(LClientSock); platform_socket_close(LListenSock);
  LCtx := nil; LLib.Finalize; LLib := nil;
end;

procedure TestOversizeRecord;
var
  LLib: ISSLLibrary; LCtx: ISSLContext; LConn: ISSLConnection;
  LListenSock, LClientSock: TPlatformSocket;
  LPort: Word;
  LBad: array[0..4] of Byte;
begin
  WriteLn('TestOversizeRecord');
  LPort := 44703;
  LLib := TFreePascalSSLLibrary.Create; LLib.Initialize;
  LCtx := LLib.CreateContext(sslCtxClient);
  LCtx.SetProtocolVersions([sslProtocolTLS13]);
  LCtx.SetVerifyMode([]);

  LListenSock := CreateListenSocket(LPort);
  LClientSock := ConnectTo(LPort);

  // Record claiming 65535 bytes (oversize)
  LBad[0] := $16; LBad[1] := $03; LBad[2] := $03;
  LBad[3] := $FF; LBad[4] := $FF;
  SendAndClose(LListenSock, LBad);

  LConn := LCtx.CreateConnection(THandle(LClientSock.Value));
  try
    Check(not LConn.Connect, 'Oversize record rejected');
  except
    on E: Exception do
      Check(True, 'Oversize raised: ' + E.ClassName);
  end;

  LConn := nil;
  platform_socket_close(LClientSock); platform_socket_close(LListenSock);
  LCtx := nil; LLib.Finalize; LLib := nil;
end;

procedure TestServerAcceptGarbage;
var
  LLib: ISSLLibrary; LCtx: ISSLContext; LConn: ISSLConnection;
  LListenSock, LServerSock: TPlatformSocket;
  LAddr: TPlatformSockAddr; LAddrLen: Int32;
  LPort: Word;
  LGarbage: array[0..31] of Byte;
  LClientSock: TPlatformSocket;
  LSent: Int32;
begin
  WriteLn('TestServerAcceptGarbage');
  LPort := 44704;
  LLib := TFreePascalSSLLibrary.Create; LLib.Initialize;
  LCtx := LLib.CreateContext(sslCtxServer);
  LCtx.SetProtocolVersions([sslProtocolTLS13]);
  LCtx.LoadCertificate('tests/certs/server-cert.pem');
  LCtx.LoadPrivateKey('tests/certs/server-key.pem');

  LListenSock := CreateListenSocket(LPort);
  LClientSock := ConnectTo(LPort);

  // Send garbage as "ClientHello"
  FillChar(LGarbage, SizeOf(LGarbage), $DE);
  platform_socket_send(LClientSock, @LGarbage, SizeOf(LGarbage), 0, LSent);

  LAddr.Clear;
  LAddrLen := SizeOf(LAddr.Storage);
  platform_socket_accept(LListenSock, @LAddr.Storage[0], @LAddrLen,
    LServerSock);

  LConn := LCtx.CreateConnection(THandle(LServerSock.Value));
  try
    Check(not LConn.Accept, 'Server rejects garbage ClientHello');
  except
    on E: Exception do
      Check(True, 'Server raised on garbage: ' + E.ClassName);
  end;

  LConn := nil;
  platform_socket_close(LServerSock); platform_socket_close(LClientSock); platform_socket_close(LListenSock);
  LCtx := nil; LLib.Finalize; LLib := nil;
end;

procedure TestVersionDowngradeAttack;
var
  LLib: ISSLLibrary; LCtx: ISSLContext; LConn: ISSLConnection;
  LListenSock, LClientSock: TPlatformSocket;
  LPort: Word;
  LBadSH: array[0..42] of Byte;
begin
  WriteLn('TestVersionDowngradeAttack');
  LPort := 44705;
  LLib := TFreePascalSSLLibrary.Create; LLib.Initialize;
  LCtx := LLib.CreateContext(sslCtxClient);
  LCtx.SetProtocolVersions([sslProtocolTLS13]);
  LCtx.SetVerifyMode([]);

  LListenSock := CreateListenSocket(LPort);
  LClientSock := ConnectTo(LPort);

  // Craft a ServerHello claiming TLS 1.0 (version downgrade)
  FillChar(LBadSH, SizeOf(LBadSH), 0);
  LBadSH[0] := $16; LBadSH[1] := $03; LBadSH[2] := $01; // TLS 1.0 record
  LBadSH[3] := $00; LBadSH[4] := 38;  // length
  LBadSH[5] := $02; // ServerHello type
  LBadSH[6] := $00; LBadSH[7] := $00; LBadSH[8] := 34; // handshake length
  LBadSH[9] := $03; LBadSH[10] := $01; // version: TLS 1.0
  // rest is zeros (invalid random, session_id, etc.)
  SendAndClose(LListenSock, LBadSH);

  LConn := LCtx.CreateConnection(THandle(LClientSock.Value));
  try
    Check(not LConn.Connect, 'Version downgrade attack rejected');
  except
    on E: Exception do
      Check(True, 'Version downgrade raised: ' + E.ClassName);
  end;

  LConn := nil;
  platform_socket_close(LClientSock); platform_socket_close(LListenSock);
  LCtx := nil; LLib.Finalize; LLib := nil;
end;

procedure TestInvalidCipherSuiteSelection;
var
  LLib: ISSLLibrary; LCtx: ISSLContext; LConn: ISSLConnection;
  LListenSock, LClientSock: TPlatformSocket;
  LPort: Word;
  LBadSH: array[0..80] of Byte;
  LIdx: Integer;
begin
  WriteLn('TestInvalidCipherSuiteSelection');
  LPort := 44706;
  LLib := TFreePascalSSLLibrary.Create; LLib.Initialize;
  LCtx := LLib.CreateContext(sslCtxClient);
  LCtx.SetProtocolVersions([sslProtocolTLS13]);
  LCtx.SetVerifyMode([]);

  LListenSock := CreateListenSocket(LPort);
  LClientSock := ConnectTo(LPort);

  // ServerHello with cipher suite 0xFFFF (not offered by client)
  FillChar(LBadSH, SizeOf(LBadSH), 0);
  LBadSH[0] := $16; LBadSH[1] := $03; LBadSH[2] := $03;
  LBadSH[3] := $00; LBadSH[4] := 76; // length
  LBadSH[5] := $02; // ServerHello
  LBadSH[6] := $00; LBadSH[7] := $00; LBadSH[8] := 72; // handshake length
  LBadSH[9] := $03; LBadSH[10] := $03; // legacy version
  // random (32 bytes at offset 11)
  for LIdx := 11 to 42 do LBadSH[LIdx] := Byte(LIdx);
  LBadSH[43] := 0; // session_id length = 0
  LBadSH[44] := $FF; LBadSH[45] := $FF; // cipher suite = 0xFFFF (invalid)
  LBadSH[46] := $00; // compression = null
  // extensions length
  LBadSH[47] := $00; LBadSH[48] := 28;
  // supported_versions extension selecting TLS 1.3
  LBadSH[49] := $00; LBadSH[50] := $2B; // type = supported_versions
  LBadSH[51] := $00; LBadSH[52] := $02; // length = 2
  LBadSH[53] := $03; LBadSH[54] := $04; // TLS 1.3
  // key_share extension (minimal, X25519 with 32 zero bytes)
  LBadSH[55] := $00; LBadSH[56] := $33; // type = key_share
  LBadSH[57] := $00; LBadSH[58] := 36;  // length
  LBadSH[59] := $00; LBadSH[60] := $1D; // group = X25519
  LBadSH[61] := $00; LBadSH[62] := 32;  // key length
  // key data (zeros) at 63..94 — already zero from FillChar
  SendAndClose(LListenSock, LBadSH);

  LConn := LCtx.CreateConnection(THandle(LClientSock.Value));
  try
    Check(not LConn.Connect, 'Invalid cipher suite selection rejected');
  except
    on E: Exception do
      Check(True, 'Invalid cipher raised: ' + E.ClassName);
  end;

  LConn := nil;
  platform_socket_close(LClientSock); platform_socket_close(LListenSock);
  LCtx := nil; LLib.Finalize; LLib := nil;
end;

procedure TestMalformedHandshakeLength;
var
  LLib: ISSLLibrary; LCtx: ISSLContext; LConn: ISSLConnection;
  LListenSock, LClientSock: TPlatformSocket;
  LPort: Word;
  LBad: array[0..9] of Byte;
begin
  WriteLn('TestMalformedHandshakeLength');
  LPort := 44707;
  LLib := TFreePascalSSLLibrary.Create; LLib.Initialize;
  LCtx := LLib.CreateContext(sslCtxClient);
  LCtx.SetProtocolVersions([sslProtocolTLS13]);
  LCtx.SetVerifyMode([]);

  LListenSock := CreateListenSocket(LPort);
  LClientSock := ConnectTo(LPort);

  // Valid record header but handshake length exceeds record
  LBad[0] := $16; LBad[1] := $03; LBad[2] := $03;
  LBad[3] := $00; LBad[4] := $05; // record length = 5
  LBad[5] := $02; // ServerHello type
  LBad[6] := $00; LBad[7] := $FF; LBad[8] := $FF; // handshake length = 65535 (exceeds record)
  LBad[9] := $03;
  SendAndClose(LListenSock, LBad);

  LConn := LCtx.CreateConnection(THandle(LClientSock.Value));
  try
    Check(not LConn.Connect, 'Malformed handshake length rejected');
  except
    on E: Exception do
      Check(True, 'Malformed length raised: ' + E.ClassName);
  end;

  LConn := nil;
  platform_socket_close(LClientSock); platform_socket_close(LListenSock);
  LCtx := nil; LLib.Finalize; LLib := nil;
end;

procedure TestUnknownHandshakeType;
var
  LLib: ISSLLibrary; LCtx: ISSLContext; LConn: ISSLConnection;
  LListenSock, LClientSock: TPlatformSocket;
  LPort: Word;
  LBad: array[0..9] of Byte;
begin
  WriteLn('TestUnknownHandshakeType');
  LPort := 44708;
  LLib := TFreePascalSSLLibrary.Create; LLib.Initialize;
  LCtx := LLib.CreateContext(sslCtxClient);
  LCtx.SetProtocolVersions([sslProtocolTLS13]);
  LCtx.SetVerifyMode([]);

  LListenSock := CreateListenSocket(LPort);
  LClientSock := ConnectTo(LPort);

  // Valid record with unknown handshake type (0xFF)
  LBad[0] := $16; LBad[1] := $03; LBad[2] := $03;
  LBad[3] := $00; LBad[4] := $05; // record length = 5
  LBad[5] := $FF; // unknown handshake type
  LBad[6] := $00; LBad[7] := $00; LBad[8] := $01; // handshake length = 1
  LBad[9] := $00;
  SendAndClose(LListenSock, LBad);

  LConn := LCtx.CreateConnection(THandle(LClientSock.Value));
  try
    Check(not LConn.Connect, 'Unknown handshake type rejected');
  except
    on E: Exception do
      Check(True, 'Unknown type raised: ' + E.ClassName);
  end;

  LConn := nil;
  platform_socket_close(LClientSock); platform_socket_close(LListenSock);
  LCtx := nil; LLib.Finalize; LLib := nil;
end;

begin
  LTotal := 0; LPassed := 0;
  {$IFDEF UNIX}IgnoreSIGPIPE;{$ENDIF}

  TestTruncatedServerHello;
  TestWrongContentType;
  TestZeroLengthRecord;
  TestOversizeRecord;
  TestServerAcceptGarbage;
  TestVersionDowngradeAttack;
  TestInvalidCipherSuiteSelection;
  TestMalformedHandshakeLength;
  TestUnknownHandshakeType;

  WriteLn;
  WriteLn('Adversarial tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
