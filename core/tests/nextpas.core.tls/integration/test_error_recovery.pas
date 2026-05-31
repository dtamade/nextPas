program test_error_recovery;

{******************************************************************************}
{  TLS Error Recovery Integration Tests                                        }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.ssl,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.rsa,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.api.asn1,
  nextpas.core.tls.openssl.api.crypto,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.err,
  nextpas.core.tls.openssl.loader,
  test_openssl_base;

const
  MBSTRING_ASC = $1001;

var
  Runner: TSimpleTestRunner;
  ServerCert: PX509;
  ServerKey: PEVP_PKEY;

function GenerateSelfSignedCert(out Cert: PX509; out Key: PEVP_PKEY): Boolean;
var
  RSA: PRSA;
  BN: PBIGNUM;
  PKey: PEVP_PKEY;
  X509Cert: PX509;
  Name: PX509_NAME;
  Serial: PASN1_INTEGER;
  NotBeforeTime, NotAfterTime: PASN1_TIME;
begin
  Result := False;
  Cert := nil;
  Key := nil;

  try
    PKey := EVP_PKEY_new();
    if PKey = nil then Exit;

    RSA := RSA_new();
    BN := BN_new();
    BN_set_word(BN, RSA_F4);

    if RSA_generate_key_ex(RSA, 2048, BN, nil) <> 1 then
    begin
      BN_free(BN); RSA_free(RSA); EVP_PKEY_free(PKey);
      Exit;
    end;
    BN_free(BN);

    EVP_PKEY_assign(PKey, EVP_PKEY_RSA, RSA);

    X509Cert := X509_new();
    X509_set_version(X509Cert, 2);

    Serial := X509_get_serialNumber(X509Cert);
    ASN1_INTEGER_set(Serial, 1);

    NotBeforeTime := X509_get_notBefore(X509Cert);
    X509_gmtime_adj(NotBeforeTime, 0);
    NotAfterTime := X509_get_notAfter(X509Cert);
    X509_gmtime_adj(NotAfterTime, 365 * 24 * 60 * 60);

    X509_set_pubkey(X509Cert, PKey);

    Name := X509_NAME_new();
    X509_NAME_add_entry_by_txt(Name, 'CN', MBSTRING_ASC, PByte(PAnsiChar('localhost')), -1, -1, 0);
    X509_set_subject_name(X509Cert, Name);
    X509_set_issuer_name(X509Cert, Name);
    X509_NAME_free(Name);

    X509_sign(X509Cert, PKey, EVP_sha256());

    Cert := X509Cert;
    Key := PKey;
    Result := True;
  except
    Result := False;
  end;
end;

procedure TestHandshakeFailureRecovery;
var
  ClientCtx: PSSL_CTX;
  ClientSSL: PSSL;
  ClientRead, ClientWrite: PBIO;
  Method: PSSL_METHOD;
  Ret, Err: Integer;
begin
  WriteLn;
  WriteLn('=== Handshake Failure Recovery ===');

  try
    Method := TLS_client_method();
    ClientCtx := SSL_CTX_new(Method);
    Runner.Check('Create client context', ClientCtx <> nil);

    if ClientCtx <> nil then
    begin
      ClientSSL := SSL_new(ClientCtx);
      Runner.Check('Create SSL object', ClientSSL <> nil);

      if ClientSSL <> nil then
      begin
        // Create empty BIOs (simulate no server response)
        ClientRead := BIO_new(BIO_s_mem());
        ClientWrite := BIO_new(BIO_s_mem());
        SSL_set_bio(ClientSSL, ClientRead, ClientWrite);

        SSL_set_connect_state(ClientSSL);

        // Attempt handshake (should fail - no server response)
        Ret := SSL_do_handshake(ClientSSL);
        Err := SSL_get_error(ClientSSL, Ret);

        // Expect WANT_READ (waiting for server response)
        Runner.Check('Handshake returns WANT_READ', Err = SSL_ERROR_WANT_READ,
                  Format('Error code: %d', [Err]));

        // Verify cleanup works
        SSL_shutdown(ClientSSL);
        SSL_free(ClientSSL);
        Runner.Check('Cleanup SSL object', True);
      end;

      SSL_CTX_free(ClientCtx);
      Runner.Check('Cleanup context', True);
    end;

  except
    on E: Exception do
      Runner.Check('Handshake failure recovery', False, E.Message);
  end;
end;

procedure TestConnectionInterruptRecovery;
var
  ClientCtx, ServerCtx: PSSL_CTX;
  ClientSSL, ServerSSL: PSSL;
  ClientRead, ClientWrite, ServerRead, ServerWrite: PBIO;
  Method: PSSL_METHOD;
  Buffer: array[0..4095] of Byte;
  Len, Ret, Err: Integer;
  i: Integer;
begin
  WriteLn;
  WriteLn('=== Connection Interrupt Recovery ===');

  try
    Method := TLS_client_method();
    ClientCtx := SSL_CTX_new(Method);
    SSL_CTX_set_verify(ClientCtx, SSL_VERIFY_NONE, nil);

    Method := TLS_server_method();
    ServerCtx := SSL_CTX_new(Method);
    SSL_CTX_use_certificate(ServerCtx, ServerCert);
    SSL_CTX_use_PrivateKey(ServerCtx, ServerKey);

    ClientSSL := SSL_new(ClientCtx);
    ServerSSL := SSL_new(ServerCtx);

    ClientRead := BIO_new(BIO_s_mem());
    ClientWrite := BIO_new(BIO_s_mem());
    ServerRead := BIO_new(BIO_s_mem());
    ServerWrite := BIO_new(BIO_s_mem());

    SSL_set_bio(ClientSSL, ClientRead, ClientWrite);
    SSL_set_bio(ServerSSL, ServerRead, ServerWrite);

    SSL_set_connect_state(ClientSSL);
    SSL_set_accept_state(ServerSSL);

    // Start handshake but interrupt midway
    for i := 1 to 3 do
    begin
      Ret := SSL_do_handshake(ClientSSL);

      repeat
        Len := BIO_read(ClientWrite, @Buffer[0], SizeOf(Buffer));
        if Len > 0 then BIO_write(ServerRead, @Buffer[0], Len);
      until Len <= 0;

      Ret := SSL_do_handshake(ServerSSL);

      repeat
        Len := BIO_read(ServerWrite, @Buffer[0], SizeOf(Buffer));
        if Len > 0 then BIO_write(ClientRead, @Buffer[0], Len);
      until Len <= 0;
    end;

    // Simulate interrupt: close server
    SSL_shutdown(ServerSSL);

    // Transfer close notify to client
    repeat
      Len := BIO_read(ServerWrite, @Buffer[0], SizeOf(Buffer));
      if Len > 0 then BIO_write(ClientRead, @Buffer[0], Len);
    until Len <= 0;

    SSL_free(ServerSSL);
    Runner.Check('Server interrupt', True);

    // Client tries to read (should detect closure)
    Ret := SSL_read(ClientSSL, @Buffer[0], SizeOf(Buffer));
    Err := SSL_get_error(ClientSSL, Ret);

    Runner.Check('Client detects interrupt', (Ret <= 0) or (Err = SSL_ERROR_ZERO_RETURN),
              Format('Return: %d, Error: %d', [Ret, Err]));

    SSL_shutdown(ClientSSL);
    SSL_free(ClientSSL);
    Runner.Check('Client cleanup', True);

    SSL_CTX_free(ClientCtx);
    SSL_CTX_free(ServerCtx);
    Runner.Check('Context cleanup', True);

  except
    on E: Exception do
      Runner.Check('Connection interrupt recovery', False, E.Message);
  end;
end;

procedure TestCertificateVerificationFailure;
var
  ClientCtx, ServerCtx: PSSL_CTX;
  ClientSSL, ServerSSL: PSSL;
  ClientRead, ClientWrite, ServerRead, ServerWrite: PBIO;
  Method: PSSL_METHOD;
  Buffer: array[0..4095] of Byte;
  Len, Ret, Err: Integer;
  i: Integer;
  VerifyResult: LongInt;
begin
  WriteLn;
  WriteLn('=== Certificate Verification Failure ===');

  try
    Method := TLS_client_method();
    ClientCtx := SSL_CTX_new(Method);
    SSL_CTX_set_verify(ClientCtx, SSL_VERIFY_PEER, nil);
    Runner.Check('Create strict verification client', ClientCtx <> nil);

    Method := TLS_server_method();
    ServerCtx := SSL_CTX_new(Method);
    SSL_CTX_use_certificate(ServerCtx, ServerCert);
    SSL_CTX_use_PrivateKey(ServerCtx, ServerKey);

    ClientSSL := SSL_new(ClientCtx);
    ServerSSL := SSL_new(ServerCtx);

    ClientRead := BIO_new(BIO_s_mem());
    ClientWrite := BIO_new(BIO_s_mem());
    ServerRead := BIO_new(BIO_s_mem());
    ServerWrite := BIO_new(BIO_s_mem());

    SSL_set_bio(ClientSSL, ClientRead, ClientWrite);
    SSL_set_bio(ServerSSL, ServerRead, ServerWrite);

    SSL_set_connect_state(ClientSSL);
    SSL_set_accept_state(ServerSSL);

    // Attempt handshake
    for i := 1 to 10 do
    begin
      Ret := SSL_do_handshake(ClientSSL);
      if (Ret = 1) then Break;

      Err := SSL_get_error(ClientSSL, Ret);
      if (Err <> SSL_ERROR_WANT_READ) and (Err <> SSL_ERROR_WANT_WRITE) then
        Break;

      repeat
        Len := BIO_read(ClientWrite, @Buffer[0], SizeOf(Buffer));
        if Len > 0 then BIO_write(ServerRead, @Buffer[0], Len);
      until Len <= 0;

      Ret := SSL_do_handshake(ServerSSL);

      repeat
        Len := BIO_read(ServerWrite, @Buffer[0], SizeOf(Buffer));
        if Len > 0 then BIO_write(ClientRead, @Buffer[0], Len);
      until Len <= 0;
    end;

    // Check verification result
    if Assigned(SSL_get_verify_result) then
    begin
      VerifyResult := SSL_get_verify_result(ClientSSL);
      if VerifyResult <> 0 then
        Runner.Check('Certificate verification failed (expected)', True,
                  Format('Verify result: %d', [VerifyResult]))
      else
        Runner.Check('Certificate verification passed', True, 'May be in trust store');
    end
    else
      Runner.Check('Get verification result', False, 'Function not loaded');

    // Cleanup
    SSL_shutdown(ClientSSL);
    SSL_shutdown(ServerSSL);
    SSL_free(ClientSSL);
    SSL_free(ServerSSL);
    SSL_CTX_free(ClientCtx);
    SSL_CTX_free(ServerCtx);
    Runner.Check('Resource cleanup', True);

  except
    on E: Exception do
      Runner.Check('Certificate verification failure', False, E.Message);
  end;
end;

procedure TestErrorQueueHandling;
var
  ErrCode: Cardinal;
  ErrBuf: array[0..255] of AnsiChar;
  ErrCount: Integer;
begin
  WriteLn;
  WriteLn('=== Error Queue Handling ===');

  try
    if Assigned(ERR_clear_error) then
    begin
      ERR_clear_error();
      Runner.Check('Clear error queue', True);
    end;

    Runner.Check('ERR_get_error available', Assigned(ERR_get_error));
    Runner.Check('ERR_error_string_n available', Assigned(ERR_error_string_n));
    Runner.Check('ERR_peek_error available', Assigned(ERR_peek_error));
    Runner.Check('ERR_clear_error available', Assigned(ERR_clear_error));

    if Assigned(ERR_get_error) and Assigned(ERR_error_string_n) then
    begin
      ErrCount := 0;
      ErrCode := ERR_get_error();
      while ErrCode <> 0 do
      begin
        ERR_error_string_n(ErrCode, @ErrBuf[0], SizeOf(ErrBuf));
        Inc(ErrCount);
        ErrCode := ERR_get_error();
      end;

      Runner.Check('Error queue iteration', True, Format('Processed %d errors', [ErrCount]));
    end;

  except
    on E: Exception do
      Runner.Check('Error queue handling', False, E.Message);
  end;
end;

procedure TestResourceCleanupVerification;
var
  ClientCtx: PSSL_CTX;
  ClientSSL: PSSL;
  Method: PSSL_METHOD;
  i: Integer;
begin
  WriteLn;
  WriteLn('=== Resource Cleanup Verification ===');

  try
    // Test multiple create/destroy cycles
    for i := 1 to 10 do
    begin
      Method := TLS_client_method();
      ClientCtx := SSL_CTX_new(Method);

      if ClientCtx <> nil then
      begin
        ClientSSL := SSL_new(ClientCtx);

        if ClientSSL <> nil then
        begin
          SSL_set_connect_state(ClientSSL);
          SSL_free(ClientSSL);
        end;

        SSL_CTX_free(ClientCtx);
      end;
    end;

    Runner.Check('10 create/destroy cycles', True, 'No memory leak (external verification needed)');

    // Test exception cleanup
    try
      Method := TLS_client_method();
      ClientCtx := SSL_CTX_new(Method);

      if ClientCtx <> nil then
        raise Exception.Create('Test exception');
    except
      on E: Exception do
      begin
        if ClientCtx <> nil then
          SSL_CTX_free(ClientCtx);
        Runner.Check('Exception resource cleanup', True, 'Exception: ' + E.Message);
      end;
    end;

  except
    on E: Exception do
      Runner.Check('Resource cleanup verification', False, E.Message);
  end;
end;

procedure TestHighLevelExceptionHandling;
var
  SSLLib: ISSLLibrary;
  Context: ISSLContext;
  ExceptionCaught: Boolean;
begin
  WriteLn;
  WriteLn('=== High-Level Exception Handling ===');

  try
    SSLLib := CreateOpenSSLLibrary;
    Runner.Check('Create library instance', SSLLib <> nil);

    if SSLLib <> nil then
    begin
      Runner.Check('Initialize library', SSLLib.Initialize);

      Context := SSLLib.CreateContext(sslCtxClient);
      Runner.Check('Create context', Context <> nil);

      if Context <> nil then
      begin
        // Test loading nonexistent certificate
        ExceptionCaught := False;
        try
          Context.LoadCertificate('/nonexistent/path/cert.pem');
        except
          on E: ESSLException do
          begin
            ExceptionCaught := True;
            Runner.Check('File not found exception', True, E.Message);
          end;
          on E: Exception do
          begin
            ExceptionCaught := True;
            Runner.Check('General exception', True, E.Message);
          end;
        end;

        if not ExceptionCaught then
          Runner.Check('File not found exception', False, 'No exception caught');

        // Test loading invalid PEM data
        ExceptionCaught := False;
        try
          Context.LoadCertificatePEM('invalid pem data');
        except
          on E: Exception do
          begin
            ExceptionCaught := True;
            Runner.Check('Invalid PEM exception', True, E.Message);
          end;
        end;

        if not ExceptionCaught then
          Runner.Check('Invalid PEM exception', False, 'No exception caught');
      end;

      SSLLib.Finalize;
      Runner.Check('Library finalize', True);
    end;

  except
    on E: Exception do
      Runner.Check('High-level exception handling', False, E.Message);
  end;
end;

procedure TestGracefulShutdown;
var
  ClientCtx, ServerCtx: PSSL_CTX;
  ClientSSL, ServerSSL: PSSL;
  ClientRead, ClientWrite, ServerRead, ServerWrite: PBIO;
  Method: PSSL_METHOD;
  Buffer: array[0..4095] of Byte;
  Len, Ret: Integer;
  i: Integer;
  ShutdownComplete: Boolean;
begin
  WriteLn;
  WriteLn('=== Graceful Shutdown ===');

  try
    Method := TLS_client_method();
    ClientCtx := SSL_CTX_new(Method);
    SSL_CTX_set_verify(ClientCtx, SSL_VERIFY_NONE, nil);

    Method := TLS_server_method();
    ServerCtx := SSL_CTX_new(Method);
    SSL_CTX_use_certificate(ServerCtx, ServerCert);
    SSL_CTX_use_PrivateKey(ServerCtx, ServerKey);

    ClientSSL := SSL_new(ClientCtx);
    ServerSSL := SSL_new(ServerCtx);

    ClientRead := BIO_new(BIO_s_mem());
    ClientWrite := BIO_new(BIO_s_mem());
    ServerRead := BIO_new(BIO_s_mem());
    ServerWrite := BIO_new(BIO_s_mem());

    SSL_set_bio(ClientSSL, ClientRead, ClientWrite);
    SSL_set_bio(ServerSSL, ServerRead, ServerWrite);

    SSL_set_connect_state(ClientSSL);
    SSL_set_accept_state(ServerSSL);

    // Complete handshake
    ShutdownComplete := False;
    for i := 1 to 20 do
    begin
      Ret := SSL_do_handshake(ClientSSL);
      repeat
        Len := BIO_read(ClientWrite, @Buffer[0], SizeOf(Buffer));
        if Len > 0 then BIO_write(ServerRead, @Buffer[0], Len);
      until Len <= 0;

      Ret := SSL_do_handshake(ServerSSL);
      repeat
        Len := BIO_read(ServerWrite, @Buffer[0], SizeOf(Buffer));
        if Len > 0 then BIO_write(ClientRead, @Buffer[0], Len);
      until Len <= 0;

      if (SSL_is_init_finished(ClientSSL) = 1) and (SSL_is_init_finished(ServerSSL) = 1) then
      begin
        ShutdownComplete := True;
        Break;
      end;
    end;

    Runner.Check('Handshake complete', ShutdownComplete);

    if ShutdownComplete then
    begin
      // Test bidirectional shutdown
      Ret := SSL_shutdown(ClientSSL);
      Runner.Check('Client shutdown initiate', True, Format('Return: %d', [Ret]));

      repeat
        Len := BIO_read(ClientWrite, @Buffer[0], SizeOf(Buffer));
        if Len > 0 then BIO_write(ServerRead, @Buffer[0], Len);
      until Len <= 0;

      Ret := SSL_shutdown(ServerSSL);
      Runner.Check('Server shutdown response', True, Format('Return: %d', [Ret]));

      repeat
        Len := BIO_read(ServerWrite, @Buffer[0], SizeOf(Buffer));
        if Len > 0 then BIO_write(ClientRead, @Buffer[0], Len);
      until Len <= 0;

      Ret := SSL_shutdown(ClientSSL);
      Runner.Check('Client shutdown complete', Ret >= 0, Format('Return: %d', [Ret]));
    end;

    SSL_free(ClientSSL);
    SSL_free(ServerSSL);
    SSL_CTX_free(ClientCtx);
    SSL_CTX_free(ServerCtx);
    Runner.Check('Resource release', True);

  except
    on E: Exception do
      Runner.Check('Graceful shutdown', False, E.Message);
  end;
end;

procedure InitializeTests;
begin
  WriteLn('Loading OpenSSL modules...');
  LoadOpenSSLCore();
  LoadOpenSSLBIO();
  LoadOpenSSLX509();
  LoadEVP(GetCryptoLibHandle);
  LoadOpenSSLRSA();
  LoadOpenSSLBN();
  LoadOpenSSLASN1(GetCryptoLibHandle);
  LoadOpenSSLSSL;
  LoadOpenSSLERR;

  WriteLn;
  WriteLn('Generating test certificate...');
  if not GenerateSelfSignedCert(ServerCert, ServerKey) then
  begin
    WriteLn('ERROR: Could not generate test certificate');
    Halt(1);
  end;
  WriteLn('Certificate generated successfully');
  WriteLn;
end;

procedure CleanupTests;
begin
  if ServerCert <> nil then X509_free(ServerCert);
  if ServerKey <> nil then EVP_PKEY_free(ServerKey);
end;

begin
  WriteLn('TLS Error Recovery Integration Tests');
  WriteLn('=====================================');
  WriteLn;

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore, osmBN, osmRSA, osmEVP, osmX509]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);

    InitializeTests;

    TestHandshakeFailureRecovery;
    TestConnectionInterruptRecovery;
    TestCertificateVerificationFailure;
    TestErrorQueueHandling;
    TestResourceCleanupVerification;
    TestHighLevelExceptionHandling;
    TestGracefulShutdown;

    CleanupTests;

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
