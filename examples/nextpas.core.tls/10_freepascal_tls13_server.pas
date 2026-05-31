program freepascal_tls13_server;

{$mode objfpc}{$H+}
{$IFDEF UNIX}
uses cthreads, BaseUnix, Sockets, SysUtils, Classes,
  fafafa.ssl, nextpas.core.tls.base, nextpas.core.tls.factory;
{$ELSE}
uses SysUtils, Classes, WinSock2,
  fafafa.ssl, nextpas.core.tls.base, nextpas.core.tls.factory;
{$ENDIF}

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
var SA: SigActionRec;
begin
  FillChar(SA, SizeOf(SA), 0);
  SA.sa_handler := SigActionHandler(SIG_IGN);
  fpSigAction(SIGPIPE, @SA, nil);
end;
{$ENDIF}

function CreateListenSocket(APort: Word): cint;
var LAddr: TInetSockAddr; LOptVal: cint;
begin
  Result := fpSocket(AF_INET, SOCK_STREAM, 0);
  if Result < 0 then begin WriteLn('ERROR: socket() failed'); Halt(1); end;
  LOptVal := 1;
  fpSetSockOpt(Result, SOL_SOCKET, SO_REUSEADDR, @LOptVal, SizeOf(LOptVal));
  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.sin_family := AF_INET;
  LAddr.sin_port := htons(APort);
  LAddr.sin_addr.s_addr := htonl(INADDR_ANY);
  if fpBind(Result, @LAddr, SizeOf(LAddr)) <> 0 then
  begin WriteLn('ERROR: bind() failed on port ', APort); Halt(1); end;
  if fpListen(Result, 5) <> 0 then
  begin WriteLn('ERROR: listen() failed'); Halt(1); end;
end;
var
  LPort: Word;
  LListenSock, LClientSock: cint;
  LAddr: TInetSockAddr;
  LAddrLen: TSockLen;
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
    LAddrLen := SizeOf(LAddr);
    LClientSock := fpAccept(LListenSock, @LAddr, @LAddrLen);
    if LClientSock < 0 then Continue;

    LConn := LCtx.CreateConnection(THandle(LClientSock));
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
        LResponseBytes := TEncoding.UTF8.GetBytes(LResponse);
        LConn.Write(LResponseBytes[0], Length(LResponseBytes));
      end;
      LConn.Shutdown;
      WriteLn('  [OK] Served TLS 1.3 connection');
      LServed := True;
    end
    else
      WriteLn('  [FAIL] TLS handshake failed');

    LConn := nil;
    fpClose(LClientSock);

    if LOnce then
    begin
      fpClose(LListenSock);
      if LServed then Halt(0) else Halt(1);
    end;
  end;

  fpClose(LListenSock);
end.

  fpClose(LListenSock);
end.
