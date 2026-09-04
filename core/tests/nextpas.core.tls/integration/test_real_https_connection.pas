{******************************************************************************}
{  Real Network HTTPS Connection Tests                                         }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

program test_real_https_connection;

{$mode objfpc}{$H+}{$J-}

uses
  nextpas.core.platform.socket,
  nextpas.core.text.conv,
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.time,
  nextpas.core.fs,
  nextpas.core.os.env,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  test_openssl_base;

var
  Runner: TSimpleTestRunner;

{ Create TCP socket }
function CreateTCPSocket: TPlatformSocket;
begin
  if platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0,
    Result) <> 0 then
    Result := PLATFORM_INVALID_SOCKET;
end;

{ Resolve hostname }
function ResolveHostname(const AHostname: string; out AAddress: UInt32): Boolean;
begin
  AAddress := 0;
  Result := platform_socket_resolve_ipv4(
    PAnsiChar(AnsiString(AHostname)), AAddress) = 0;
end;

{ Connect to server }
function ConnectToHost(ASocket: TPlatformSocket; const AHostname: string;
  APort: Word): Boolean;
var
  Addr: TPlatformSockAddr;
  IP: UInt32;
begin
  Result := False;

  if not ResolveHostname(AHostname, IP) then
    Exit;

  platform_sockaddr_ipv4(APort, IP, Addr);

  Result := platform_socket_connect(ASocket, @Addr.Storage[0],
    Addr.Len) = 0;
end;

function GetConnectionStateString(AConn: ISSLConnection): string;
var
  LConnInfo: ISSLConnectionInfo;
begin
  if Supports(AConn, ISSLConnectionInfo, LConnInfo) then
    Result := LConnInfo.GetStateString
  else
    Result := '[ISSLConnectionInfo unavailable]';
end;

function GetConnectionSelectedALPN(AConn: ISSLConnection): string;
var
  LConnInfo: ISSLConnectionInfo;
begin
  if Supports(AConn, ISSLConnectionInfo, LConnInfo) then
    Result := LConnInfo.GetSelectedALPNProtocol
  else
    Result := '';
end;

{ Set socket timeout }
procedure SetSocketTimeout(ASocket: TPlatformSocket; ATimeoutMs: Integer);
begin
  platform_socket_set_timeout(ASocket, PLATFORM_SO_RCVTIMEO, ATimeoutMs);
  platform_socket_set_timeout(ASocket, PLATFORM_SO_SNDTIMEO, ATimeoutMs);
end;

{ Test single HTTPS site connection }
function TestHTTPSConnection(const AHostname: string; APort: Word = 443): Boolean;
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  Conn: ISSLConnection;
  Sock: TPlatformSocket;
  Request: string;
  Buffer: array[0..4095] of Byte;
  BytesRead, BytesWritten: Integer;
  ResponseStr: AnsiString;
  RequestBytes: TBytes;
begin
  Result := False;
  Sock := PLATFORM_INVALID_SOCKET;

  try
    Sock := CreateTCPSocket;
    if Sock.IsInvalid then
    begin
      WriteLn('    Cannot create socket');
      Exit;
    end;

    SetSocketTimeout(Sock, 10000);

    if not ConnectToHost(Sock, AHostname, APort) then
    begin
      WriteLn('    TCP connect failed: ', AHostname);
      Exit;
    end;

    Lib := TOpenSSLLibrary.Create;
    if not Lib.Initialize then
    begin
      WriteLn('    OpenSSL init failed');
      Exit;
    end;

    Ctx := Lib.CreateContext(sslCtxClient);
    if Ctx = nil then
    begin
      WriteLn('    Create SSL context failed');
      Exit;
    end;

    Ctx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
    if FileExists('/etc/ssl/certs/ca-certificates.crt') then
    begin
      Ctx.LoadCAFile('/etc/ssl/certs/ca-certificates.crt');
      Ctx.SetVerifyMode([sslVerifyPeer]);
    end
    else
      Ctx.SetVerifyMode([]);
    Ctx.SetALPNProtocols('http/1.1');

    Conn := Ctx.CreateConnection(THandle(Sock.Value));
    if Conn = nil then
    begin
      WriteLn('    Create SSL connection failed');
      Exit;
    end;
    (Conn as ISSLClientConnection).SetServerName(AHostname);

    if not Conn.Connect then
    begin
      WriteLn('    TLS handshake failed: ', GetConnectionStateString(Conn));
      Exit;
    end;

    Request := 'GET / HTTP/1.1' + #13#10 +
               'Host: ' + AHostname + #13#10 +
               'User-Agent: nextpas.core.tls-test/1.0' + #13#10 +
               'Connection: close' + #13#10 +
               #13#10;

    RequestBytes := StringToUTF8Bytes(Request);
    BytesWritten := Conn.Write(RequestBytes[0], Length(RequestBytes));
    if BytesWritten <= 0 then
    begin
      WriteLn('    Send request failed');
      Exit;
    end;

    BytesRead := Conn.Read(Buffer, SizeOf(Buffer));
    if BytesRead <= 0 then
    begin
      WriteLn('    Read response failed');
      Exit;
    end;

    SetString(ResponseStr, PAnsiChar(@Buffer[0]), BytesRead);

    Result := (Pos('HTTP/', string(ResponseStr)) = 1);

    if Result then
    begin
      if Pos('200', string(ResponseStr)) > 0 then
        WriteLn('    Status: 200 OK')
      else if Pos('301', string(ResponseStr)) > 0 then
        WriteLn('    Status: 301 Redirect')
      else if Pos('302', string(ResponseStr)) > 0 then
        WriteLn('    Status: 302 Redirect')
      else if Pos('403', string(ResponseStr)) > 0 then
        WriteLn('    Status: 403 Forbidden (TLS success)')
      else
        WriteLn('    Status: Other HTTP response');

      WriteLn('    Protocol: ', ProtocolVersionToString(Conn.GetProtocolVersion));
      WriteLn('    Cipher: ', Conn.GetCipherName);
    end;

  except
    on E: Exception do
    begin
      WriteLn('    Exception: ', E.Message);
      Result := False;
    end;
  end;

  if Sock.IsValid then
    platform_socket_close(Sock);
end;

{ Test TLS version negotiation }
procedure TestTLSVersionNegotiation;
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  Conn: ISSLConnection;
  Sock: TPlatformSocket;
  Protocol: string;
  ProtoVer: TSSLProtocolVersion;
begin
  WriteLn;
  WriteLn('=== TLS Version Negotiation ===');

  Sock := CreateTCPSocket;
  if Sock.IsInvalid then
  begin
    Runner.Skip('TLS 1.3 negotiation', '[environment] cannot create socket');
    Exit;
  end;

  SetSocketTimeout(Sock, 10000);

  if not ConnectToHost(Sock, 'www.google.com', 443) then
  begin
    platform_socket_close(Sock);
    Runner.Skip('TLS 1.3 negotiation', '[environment] TCP connect failed');
    Exit;
  end;

  try
    Lib := TOpenSSLLibrary.Create;
    if not Lib.Initialize then
    begin
      Runner.Skip('TLS 1.3 negotiation', '[dependency] OpenSSL init failed');
      Exit;
    end;

    Ctx := Lib.CreateContext(sslCtxClient);
    Ctx.SetProtocolVersions([sslProtocolTLS13]);
    Ctx.SetVerifyMode([]);

    Conn := Ctx.CreateConnection(THandle(Sock.Value));
    (Conn as ISSLClientConnection).SetServerName('www.google.com');
    if Conn.Connect then
    begin
      ProtoVer := Conn.GetProtocolVersion;
      Protocol := ProtocolVersionToString(ProtoVer);
      Runner.Check('TLS 1.3 negotiation', ProtoVer = sslProtocolTLS13, 'Actual: ' + Protocol);
    end
    else
      Runner.Check('TLS 1.3 negotiation', False, 'TLS handshake failed');

  except
    on E: Exception do
      Runner.Check('TLS 1.3 negotiation', False, E.Message);
  end;

  platform_socket_close(Sock);
end;

{ Test certificate verification }
procedure TestCertificateVerification;
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  Conn: ISSLConnection;
  Sock: TPlatformSocket;
  CertInfo: TSSLCertificateInfo;
  PeerCert: ISSLCertificate;
begin
  WriteLn;
  WriteLn('=== Certificate Verification ===');

  Sock := CreateTCPSocket;
  if Sock.IsInvalid then
  begin
    Runner.Skip('Get server certificate', '[environment] cannot create socket');
    Exit;
  end;

  SetSocketTimeout(Sock, 10000);

  if not ConnectToHost(Sock, 'www.github.com', 443) then
  begin
    platform_socket_close(Sock);
    Runner.Skip('Get server certificate', '[environment] TCP connect failed');
    Exit;
  end;

  try
    Lib := TOpenSSLLibrary.Create;
    Lib.Initialize;

    Ctx := Lib.CreateContext(sslCtxClient);
    Ctx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
    Ctx.SetVerifyMode([]);

    Conn := Ctx.CreateConnection(THandle(Sock.Value));
    (Conn as ISSLClientConnection).SetServerName('www.github.com');
    if Conn.Connect then
    begin
      Runner.Check('TLS handshake success', True);

      PeerCert := Conn.GetPeerCertificate;
      if PeerCert <> nil then
      begin
        CertInfo := PeerCert.GetInfo;
        Runner.Check('Get certificate subject', CertInfo.Subject <> '', 'Subject: ' + CertInfo.Subject);
        Runner.Check('Get certificate issuer', CertInfo.Issuer <> '', 'Issuer: ' + CertInfo.Issuer);
        Runner.Check('Certificate validity', CertInfo.NotAfter > DateTimeNow, 'Valid until: ' + DateTimeToStr(CertInfo.NotAfter));
      end
      else
        Runner.Check('Get server certificate', False, 'Cannot get peer certificate');
    end
    else
      Runner.Check('TLS handshake success', False, GetConnectionStateString(Conn));

  except
    on E: Exception do
      Runner.Check('Get server certificate', False, E.Message);
  end;

  platform_socket_close(Sock);
end;

{ Test multiple known websites }
procedure TestKnownWebsites;
const
  Websites: array[0..4] of string = (
    'www.google.com',
    'www.github.com',
    'www.cloudflare.com',
    'www.microsoft.com',
    'www.amazon.com'
  );
var
  I: Integer;
  SuccessCount: Integer;
begin
  WriteLn;
  WriteLn('=== Known Website Connection Tests ===');

  SuccessCount := 0;
  for I := Low(Websites) to High(Websites) do
  begin
    Write('  Testing ', Websites[I], '... ');
    if TestHTTPSConnection(Websites[I]) then
    begin
      Inc(SuccessCount);
      Runner.Check(Websites[I], True);
    end
    else
      Runner.Check(Websites[I], False, 'Connection failed');
  end;

  WriteLn;
  WriteLn('  Successful: ', SuccessCount, '/', Length(Websites));
end;

{ Test SNI (Server Name Indication) }
procedure TestSNI;
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  Conn: ISSLConnection;
  ClientConn: ISSLClientConnection;
  Sock: TPlatformSocket;
begin
  WriteLn;
  WriteLn('=== SNI Function Tests ===');

  Sock := CreateTCPSocket;
  if Sock.IsInvalid then
  begin
    Runner.Skip('SNI setup', '[environment] cannot create socket');
    Exit;
  end;

  SetSocketTimeout(Sock, 10000);

  if not ConnectToHost(Sock, 'www.cloudflare.com', 443) then
  begin
    platform_socket_close(Sock);
    Runner.Skip('SNI setup', '[environment] TCP connect failed');
    Exit;
  end;

  try
    Lib := TOpenSSLLibrary.Create;
    Lib.Initialize;

    Ctx := Lib.CreateContext(sslCtxClient);
    Ctx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
    Ctx.SetVerifyMode([]);

    Conn := Ctx.CreateConnection(THandle(Sock.Value));
    ClientConn := Conn as ISSLClientConnection;
    ClientConn.SetServerName('www.cloudflare.com');
    Runner.Check('Set SNI', ClientConn.GetServerName = 'www.cloudflare.com');
    if Conn.Connect then
      Runner.Check('SNI handshake success', True)
    else
      Runner.Check('SNI handshake success', False, GetConnectionStateString(Conn));

  except
    on E: Exception do
      Runner.Check('SNI function', False, E.Message);
  end;

  platform_socket_close(Sock);
end;

{ Test ALPN }
procedure TestALPN;
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  Conn: ISSLConnection;
  Sock: TPlatformSocket;
  NegotiatedProtocol: string;
begin
  WriteLn;
  WriteLn('=== ALPN Protocol Negotiation ===');

  Sock := CreateTCPSocket;
  if Sock.IsInvalid then
  begin
    Runner.Skip('ALPN negotiation', '[environment] cannot create socket');
    Exit;
  end;

  SetSocketTimeout(Sock, 10000);

  if not ConnectToHost(Sock, 'www.google.com', 443) then
  begin
    platform_socket_close(Sock);
    Runner.Skip('ALPN negotiation', '[environment] TCP connect failed');
    Exit;
  end;

  try
    Lib := TOpenSSLLibrary.Create;
    Lib.Initialize;

    Ctx := Lib.CreateContext(sslCtxClient);
    Ctx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
    Ctx.SetALPNProtocols('h2,http/1.1');
    Ctx.SetVerifyMode([]);

    Runner.Check('Set ALPN protocols', Ctx.GetALPNProtocols = 'h2,http/1.1');

    Conn := Ctx.CreateConnection(THandle(Sock.Value));
    (Conn as ISSLClientConnection).SetServerName('www.google.com');
    if Conn.Connect then
    begin
      Runner.Check('ALPN handshake success', True);
      NegotiatedProtocol := GetConnectionSelectedALPN(Conn);
      Runner.Check('ALPN negotiation result', NegotiatedProtocol <> '', 'Protocol: ' + NegotiatedProtocol);
    end
    else
      Runner.Check('ALPN handshake success', False, GetConnectionStateString(Conn));

  except
    on E: Exception do
      Runner.Check('ALPN function', False, E.Message);
  end;

  platform_socket_close(Sock);
end;

begin
  WriteLn('Real Network HTTPS Connection Test Suite');
  WriteLn('========================================');
  WriteLn;
  WriteLn('Note: This test requires network connectivity.');
  WriteLn;

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);

    if GetEnvironmentVariable('NEXTPAS_RUN_NETWORK_TESTS') <> '1' then
      Runner.Skip('Real HTTPS network suite', '[environment] network tests disabled (NEXTPAS_RUN_NETWORK_TESTS!=1)')
    else
    begin
      TestKnownWebsites;
      TestTLSVersionNegotiation;
      TestCertificateVerification;
      TestSNI;
      TestALPN;
    end;

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
