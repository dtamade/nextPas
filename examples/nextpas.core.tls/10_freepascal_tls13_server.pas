program freepascal_tls13_server;

{$mode objfpc}{$H+}
uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.text.conv,
  nextpas.core.fs,
  nextpas.core.platform.signal,
  nextpas.core.platform.socket,
  nextpas.core.tls.base, nextpas.core.tls.factory,
  nextpas.core.tls.freepascal.lib;

{ ============================================================================
  FreePascal TLS 1.3 Server — 纯 Pascal，零外部依赖

  编译: fpc -B -Fu./src ./examples/10_freepascal_tls13_server.pas
  运行: ./10_freepascal_tls13_server [port]

  需要 server.crt 和 server.key 文件（可用 openssl 生成）:
    openssl req -x509 -newkey rsa:2048 -keyout server.key \
      -out server.crt -days 365 -nodes -subj "/CN=localhost"
  ============================================================================ }

const
  DEFAULT_PORT = 4433;
  RESPONSE_BODY = '{"status":"ok","backend":"freepascal","tls":"1.3"}';

{$IFDEF UNIX}
procedure IgnoreSIGPIPE;
begin
  platform_signal_ignore(PLATFORM_SIGPIPE);
end;
{$ENDIF}

function CreateListenSocket(APort: Word): TPlatformSocket;
var LAddr: TPlatformSockAddr; LOptVal: LongInt;
begin
  if platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    0, Result) <> 0 then
  begin WriteLn('ERROR: socket() failed'); Halt(1); end;
  LOptVal := 1;
  platform_socket_setsockopt(Result, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_REUSEADDR, @LOptVal, SizeOf(LOptVal));
  platform_sockaddr_ipv4(APort, platform_ipv4_parse('0.0.0.0'), LAddr);
  if platform_socket_bind(Result, @LAddr.Storage[0], LAddr.Len) <> 0 then
  begin WriteLn('ERROR: bind() failed on port ', APort); Halt(1); end;
  if platform_socket_listen(Result, 5) <> 0 then
  begin WriteLn('ERROR: listen() failed'); Halt(1); end;
end;
procedure PrintLastHandshakeError(const AConn: ISSLConnection);
var
  LDia: ISSLDiagnostics;
  LInfo: TSSLDiagnosticInfo;
  LI: Integer;
begin
  if not Supports(AConn, ISSLDiagnostics, LDia) then
    Exit;
  LInfo := LDia.GetDiagnosticInfo;
  for LI := 0 to High(LInfo.ErrorHistory) do
    WriteLn('    [ERR] ' + LInfo.ErrorHistory[LI].ErrorMessage);
end;

var
  LPort: Word;
  LListenSock, LClientSock: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LAddrLen: Int32;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LBuf: array[0..4095] of Byte;
  LRead: Integer;
  LResponse: string;
  LResponseBytes: TBytes;
  LOnce: Boolean;
  LServed: Boolean;
begin
  {$IFDEF UNIX}IgnoreSIGPIPE;{$ENDIF}

  if ParamCount >= 1 then
    LPort := StrToIntDef(ParamStr(1), DEFAULT_PORT)
  else
    LPort := DEFAULT_PORT;
  // Optional second argument "once": serve a single connection then exit.
  // Exit code 0 = handshake succeeded, 1 = handshake failed. Used by interop tests.
  LOnce := (ParamCount >= 2) and (ParamStr(2) = 'once');

  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  LCtx.SetPreferredVersion(sslProtocolTLS13);
  LCtx.LoadCertificate('server.crt');
  LCtx.LoadPrivateKey('server.key');

  LListenSock := CreateListenSocket(LPort);
  WriteLn('FreePascal TLS 1.3 server listening on port ', LPort);
  if not LOnce then
  begin
    WriteLn('Test with: curl -k https://localhost:', LPort, '/');
    WriteLn('Press Ctrl+C to stop.');
  end;
  WriteLn;

  LServed := False;
  while True do
  begin
    LAddr.Clear;
    LAddrLen := SizeOf(LAddr.Storage);
    if platform_socket_accept(LListenSock, @LAddr.Storage[0],
      @LAddrLen, LClientSock) <> 0 then Continue;

    LConn := LCtx.CreateConnection(THandle(LClientSock.Value));
    if LConn.Accept then
    begin
      LRead := LConn.Read(LBuf[0], SizeOf(LBuf));
      if LRead > 0 then
      begin
        LResponse :=
          'HTTP/1.1 200 OK'#13#10 +
          'Content-Type: application/json'#13#10 +
          'Content-Length: ' + IntToStr(Length(RESPONSE_BODY)) + #13#10 +
          'Connection: close'#13#10 +
          #13#10 +
          RESPONSE_BODY;
        LResponseBytes := StringToUTF8Bytes(LResponse);
        LConn.Write(LResponseBytes[0], Length(LResponseBytes));
      end;
      LConn.Shutdown;
      WriteLn('  [OK] Served TLS 1.3 connection');
      LServed := True;
    end
    else
    begin
      WriteLn('  [FAIL] TLS handshake failed');
      PrintLastHandshakeError(LConn);
    end;

    LConn := nil;
    platform_socket_close(LClientSock);

    if LOnce then
    begin
      platform_socket_close(LListenSock);
      if LServed then Halt(0) else Halt(1);
    end;
  end;

  platform_socket_close(LListenSock);
end.
