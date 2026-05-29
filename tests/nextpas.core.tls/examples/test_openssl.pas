program test_openssl;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  SysUtils,
  fafafa.ssl,
  fafafa.examples.tcp;

const
  BUFFER_SIZE = 4096;

procedure TestOpenSSLAvailability;
begin
  WriteLn('=== OpenSSL Availability Test ===');
  WriteLn;

  WriteLn('Checking if OpenSSL is available...');
  if TSSLFactory.IsLibraryAvailable(sslOpenSSL) then
  begin
    WriteLn('OpenSSL is available!');
    WriteLn('Description: ', TSSLFactory.GetLibraryDescription(sslOpenSSL));
  end
  else
  begin
    WriteLn('OpenSSL is NOT available');
    WriteLn('Please make sure OpenSSL shared libraries are available');
  end;

  WriteLn;
end;

procedure TestOpenSSLConnection;
var
  Ctx: ISSLContext;
  Store: ISSLCertificateStore;
  Conn: ISSLConnection;
  ClientConn: ISSLClientConnection;
  Sock: TSocketHandle;
  Req: RawByteString;
  Resp: array[0..BUFFER_SIZE - 1] of Byte;
  BytesRead, TotalBytes: Integer;
  Cert: ISSLCertificate;
  NetErr: string;
  LVerifyResult: Integer;
  LVerifyResultString: string;
begin
  WriteLn('=== OpenSSL Backend Test ===');
  WriteLn;

  if not InitNetwork(NetErr) then
  begin
    WriteLn('Network init failed: ', NetErr);
    Exit;
  end;

  try
    // Create OpenSSL context
    Ctx := TSSLFactory.CreateContext(sslCtxClient, sslOpenSSL);
    Ctx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);

    // Enable verification + system roots
    Store := TSSLFactory.CreateCertificateStore(sslOpenSSL);
    if Store <> nil then
    begin
      Store.LoadSystemStore;
      Ctx.SetCertificateStore(Store);
    end;
    Ctx.SetVerifyMode([sslVerifyPeer]);

    Sock := INVALID_SOCKET;
    try
      Sock := ConnectTCP('www.google.com', 443);

      Conn := Ctx.CreateConnection(THandle(Sock));
      if Conn = nil then
      begin
        WriteLn('Failed to create SSL connection');
        Exit;
      end;

      // per-connection SNI/hostname
      if Supports(Conn, ISSLClientConnection, ClientConn) then
        ClientConn.SetServerName('www.google.com');

      if not Conn.Connect then
      begin
        GetCertificateVerificationInfo(Conn, LVerifyResult, LVerifyResultString);
        WriteLn('TLS handshake failed: ', LVerifyResultString);
        Exit;
      end;

      WriteLn('Connected successfully!');
      WriteLn('Protocol Version: ', ProtocolVersionToString(Conn.GetProtocolVersion));
      WriteLn('Cipher: ', Conn.GetCipherName);
      WriteLn;

      Cert := Conn.GetPeerCertificate;
      if Cert <> nil then
      begin
        WriteLn('Server Certificate:');
        WriteLn('  Subject: ', Cert.GetSubject);
        WriteLn('  Issuer: ', Cert.GetIssuer);
        WriteLn('  Valid From: ', DateTimeToStr(Cert.GetNotBefore));
        WriteLn('  Valid To: ', DateTimeToStr(Cert.GetNotAfter));
        WriteLn('  Public Key Algorithm: ', Cert.GetPublicKeyAlgorithm);
        WriteLn;
      end;

      Req := 'GET / HTTP/1.1' + #13#10 +
             'Host: www.google.com' + #13#10 +
             'User-Agent: test_openssl/1.0' + #13#10 +
             'Connection: close' + #13#10 +
             #13#10;

      Conn.Write(Req[1], Length(Req));

      WriteLn('Reading response (first ~1000 bytes)...');
      WriteLn('----------------------------------------');

      TotalBytes := 0;
      repeat
        BytesRead := Conn.Read(Resp[0], SizeOf(Resp));
        if BytesRead > 0 then
        begin
          Write(Copy(PAnsiChar(@Resp[0]), 1, BytesRead));
          Inc(TotalBytes, BytesRead);
          if TotalBytes > 1000 then
          begin
            WriteLn;
            WriteLn('... (truncated, total ', TotalBytes, ' bytes received)');
            Break;
          end;
        end;
      until BytesRead <= 0;

      WriteLn;
      WriteLn('----------------------------------------');

      Conn.Shutdown;
    finally
      CloseSocket(Sock);
    end;
  finally
    CleanupNetwork;
  end;
end;

begin
  try
    TestOpenSSLAvailability;
    WriteLn;

    if TSSLFactory.IsLibraryAvailable(sslOpenSSL) then
      TestOpenSSLConnection
    else
      WriteLn('Skipping connection test as OpenSSL is not available');

    WriteLn;
    WriteLn('Press Enter to exit...');
    ReadLn;
  except
    on E: Exception do
    begin
      WriteLn('Fatal error: ', E.ClassName, ': ', E.Message);
      WriteLn('Press Enter to exit...');
      ReadLn;
    end;
  end;
end.
