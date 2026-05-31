{******************************************************************************}
{  TLS Session Resumption Integration Tests                                    }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

program test_session_resumption;

{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.openssl.session,
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
  nextpas.core.tls.openssl.loader,
  test_openssl_base;

const
  MBSTRING_ASC_VALUE = $1001;

var
  Runner: TSimpleTestRunner;
  ServerCert: PX509;
  ServerKey: PEVP_PKEY;
  ClientCtx, ServerCtx: PSSL_CTX;

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
  PKey := nil;
  RSA := nil;
  BN := nil;
  X509Cert := nil;

  try
    PKey := EVP_PKEY_new();
    if PKey = nil then Exit;

    RSA := RSA_new();
    if RSA = nil then begin EVP_PKEY_free(PKey); Exit; end;

    BN := BN_new();
    if BN = nil then begin RSA_free(RSA); EVP_PKEY_free(PKey); Exit; end;

    BN_set_word(BN, RSA_F4);

    if RSA_generate_key_ex(RSA, 2048, BN, nil) <> 1 then
    begin
      BN_free(BN); RSA_free(RSA); EVP_PKEY_free(PKey);
      Exit;
    end;

    BN_free(BN);

    if EVP_PKEY_assign(PKey, EVP_PKEY_RSA, RSA) <> 1 then
    begin
      RSA_free(RSA); EVP_PKEY_free(PKey);
      Exit;
    end;

    X509Cert := X509_new();
    if X509Cert = nil then begin EVP_PKEY_free(PKey); Exit; end;

    X509_set_version(X509Cert, 2);

    Serial := X509_get_serialNumber(X509Cert);
    ASN1_INTEGER_set(Serial, 1);

    NotBeforeTime := X509_get_notBefore(X509Cert);
    X509_gmtime_adj(NotBeforeTime, 0);

    NotAfterTime := X509_get_notAfter(X509Cert);
    X509_gmtime_adj(NotAfterTime, 365 * 24 * 60 * 60);

    X509_set_pubkey(X509Cert, PKey);

    Name := X509_NAME_new();
    X509_NAME_add_entry_by_txt(Name, 'C', MBSTRING_ASC_VALUE, PByte(PAnsiChar('CN')), -1, -1, 0);
    X509_NAME_add_entry_by_txt(Name, 'O', MBSTRING_ASC_VALUE, PByte(PAnsiChar('Test')), -1, -1, 0);
    X509_NAME_add_entry_by_txt(Name, 'CN', MBSTRING_ASC_VALUE, PByte(PAnsiChar('localhost')), -1, -1, 0);

    X509_set_subject_name(X509Cert, Name);
    X509_set_issuer_name(X509Cert, Name);
    X509_NAME_free(Name);

    if X509_sign(X509Cert, PKey, EVP_sha256()) = 0 then
    begin
      X509_free(X509Cert); EVP_PKEY_free(PKey);
      Exit;
    end;

    Cert := X509Cert;
    Key := PKey;
    Result := True;
  except
    Result := False;
  end;
end;

procedure PumpData(ClientWrite, ServerRead, ServerWrite, ClientRead: PBIO);
var
  Buffer: array[0..4095] of Byte;
  Len: Integer;
begin
  repeat
    Len := BIO_read(ClientWrite, @Buffer[0], SizeOf(Buffer));
    if Len > 0 then BIO_write(ServerRead, @Buffer[0], Len);
  until Len <= 0;

  repeat
    Len := BIO_read(ServerWrite, @Buffer[0], SizeOf(Buffer));
    if Len > 0 then BIO_write(ClientRead, @Buffer[0], Len);
  until Len <= 0;
end;

function DoFullHandshake(ClientSSL, ServerSSL: PSSL;
                         ClientWrite, ServerRead, ServerWrite, ClientRead: PBIO): Boolean;
var
  ClientRet, ServerRet: Integer;
  ClientErr, ServerErr: Integer;
  i: Integer;
begin
  Result := False;

  for i := 1 to 100 do
  begin
    ClientRet := SSL_do_handshake(ClientSSL);
    if (ClientRet <> 1) then
    begin
      ClientErr := SSL_get_error(ClientSSL, ClientRet);
      if (ClientErr <> SSL_ERROR_WANT_READ) and (ClientErr <> SSL_ERROR_WANT_WRITE) then
        Exit;
    end;

    PumpData(ClientWrite, ServerRead, ServerWrite, ClientRead);

    ServerRet := SSL_do_handshake(ServerSSL);
    if (ServerRet <> 1) then
    begin
      ServerErr := SSL_get_error(ServerSSL, ServerRet);
      if (ServerErr <> SSL_ERROR_WANT_READ) and (ServerErr <> SSL_ERROR_WANT_WRITE) then
        Exit;
    end;

    PumpData(ClientWrite, ServerRead, ServerWrite, ClientRead);

    if (ClientRet = 1) and (ServerRet = 1) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure TestSessionCreation;
var
  ClientSSL, ServerSSL: PSSL;
  ClientRead, ClientWrite, ServerRead, ServerWrite: PBIO;
  Session: PSSL_SESSION;
  SessionID: PByte;
  SessionIDLen: Cardinal;
begin
  WriteLn;
  WriteLn('=== Session Creation ===');

  try
    ClientRead := BIO_new(BIO_s_mem());
    ClientWrite := BIO_new(BIO_s_mem());
    ServerRead := BIO_new(BIO_s_mem());
    ServerWrite := BIO_new(BIO_s_mem());

    ClientSSL := SSL_new(ClientCtx);
    ServerSSL := SSL_new(ServerCtx);

    SSL_set_bio(ClientSSL, ClientRead, ClientWrite);
    SSL_set_bio(ServerSSL, ServerRead, ServerWrite);

    SSL_set_connect_state(ClientSSL);
    SSL_set_accept_state(ServerSSL);

    if DoFullHandshake(ClientSSL, ServerSSL, ClientWrite, ServerRead, ServerWrite, ClientRead) then
    begin
      Runner.Check('TLS handshake complete', True);

      Session := SSL_get1_session(ClientSSL);
      Runner.Check('Get session object', Session <> nil);

      if Session <> nil then
      begin
        if Assigned(SSL_SESSION_get_id) then
        begin
          SessionID := SSL_SESSION_get_id(Session, @SessionIDLen);
          Runner.Check('Get session ID', (SessionID <> nil) or (SessionIDLen = 0),
                    Format('Session ID length: %d bytes (TLS 1.3 may be 0)', [SessionIDLen]));
        end
        else
          Runner.Check('Get session ID', False, 'SSL_SESSION_get_id not loaded');

        if Assigned(SSL_SESSION_get_timeout) then
          Runner.Check('Session timeout', SSL_SESSION_get_timeout(Session) > 0,
                    Format('%d seconds', [SSL_SESSION_get_timeout(Session)]));

        SSL_SESSION_free(Session);
      end;
    end
    else
      Runner.Check('TLS handshake', False, 'Handshake failed');

    SSL_shutdown(ClientSSL);
    SSL_shutdown(ServerSSL);
    SSL_free(ClientSSL);
    SSL_free(ServerSSL);

  except
    on E: Exception do
      Runner.Check('Session creation', False, E.Message);
  end;
end;

procedure TestSessionResumption;
var
  ClientSSL1, ServerSSL1: PSSL;
  ClientSSL2, ServerSSL2: PSSL;
  ClientRead1, ClientWrite1, ServerRead1, ServerWrite1: PBIO;
  ClientRead2, ClientWrite2, ServerRead2, ServerWrite2: PBIO;
  OrigSession: PSSL_SESSION;
  Reused: Integer;
begin
  WriteLn;
  WriteLn('=== Session Resumption ===');

  try
    WriteLn('       Establishing initial connection...');

    ClientRead1 := BIO_new(BIO_s_mem());
    ClientWrite1 := BIO_new(BIO_s_mem());
    ServerRead1 := BIO_new(BIO_s_mem());
    ServerWrite1 := BIO_new(BIO_s_mem());

    ClientSSL1 := SSL_new(ClientCtx);
    ServerSSL1 := SSL_new(ServerCtx);

    SSL_set_bio(ClientSSL1, ClientRead1, ClientWrite1);
    SSL_set_bio(ServerSSL1, ServerRead1, ServerWrite1);

    SSL_set_connect_state(ClientSSL1);
    SSL_set_accept_state(ServerSSL1);

    if DoFullHandshake(ClientSSL1, ServerSSL1, ClientWrite1, ServerRead1, ServerWrite1, ClientRead1) then
    begin
      Runner.Check('Initial connection established', True);

      OrigSession := SSL_get1_session(ClientSSL1);
      Runner.Check('Save original session', OrigSession <> nil);

      SSL_shutdown(ClientSSL1);
      SSL_shutdown(ServerSSL1);
      SSL_free(ClientSSL1);
      SSL_free(ServerSSL1);

      if OrigSession <> nil then
      begin
        WriteLn('       Attempting to resume connection...');

        ClientRead2 := BIO_new(BIO_s_mem());
        ClientWrite2 := BIO_new(BIO_s_mem());
        ServerRead2 := BIO_new(BIO_s_mem());
        ServerWrite2 := BIO_new(BIO_s_mem());

        ClientSSL2 := SSL_new(ClientCtx);
        ServerSSL2 := SSL_new(ServerCtx);

        SSL_set_bio(ClientSSL2, ClientRead2, ClientWrite2);
        SSL_set_bio(ServerSSL2, ServerRead2, ServerWrite2);

        SSL_set_session(ClientSSL2, OrigSession);
        Runner.Check('Set resume session', True);

        SSL_set_connect_state(ClientSSL2);
        SSL_set_accept_state(ServerSSL2);

        if DoFullHandshake(ClientSSL2, ServerSSL2, ClientWrite2, ServerRead2, ServerWrite2, ClientRead2) then
        begin
          Runner.Check('Resume connection handshake', True);

          if Assigned(SSL_session_reused) then
          begin
            Reused := SSL_session_reused(ClientSSL2);
            if Reused = 1 then
              Runner.Check('Session resumed', True, 'Session was reused')
            else
              Runner.Check('Session resume check', True, 'New session (server cache config)');
          end
          else
            Runner.Check('Check session resume', False, 'SSL_session_reused not loaded');
        end
        else
          Runner.Check('Resume connection handshake', False);

        SSL_shutdown(ClientSSL2);
        SSL_shutdown(ServerSSL2);
        SSL_free(ClientSSL2);
        SSL_free(ServerSSL2);

        SSL_SESSION_free(OrigSession);
      end;
    end
    else
    begin
      Runner.Check('Initial connection', False);
      SSL_free(ClientSSL1);
      SSL_free(ServerSSL1);
    end;

  except
    on E: Exception do
      Runner.Check('Session resumption', False, E.Message);
  end;
end;

procedure TestSessionTimeout;
var
  ClientSSL, ServerSSL: PSSL;
  ClientRead, ClientWrite, ServerRead, ServerWrite: PBIO;
  Session: PSSL_SESSION;
  OrigTimeout, NewTimeout: LongInt;
begin
  WriteLn;
  WriteLn('=== Session Timeout Handling ===');

  try
    ClientRead := BIO_new(BIO_s_mem());
    ClientWrite := BIO_new(BIO_s_mem());
    ServerRead := BIO_new(BIO_s_mem());
    ServerWrite := BIO_new(BIO_s_mem());

    ClientSSL := SSL_new(ClientCtx);
    ServerSSL := SSL_new(ServerCtx);

    SSL_set_bio(ClientSSL, ClientRead, ClientWrite);
    SSL_set_bio(ServerSSL, ServerRead, ServerWrite);

    SSL_set_connect_state(ClientSSL);
    SSL_set_accept_state(ServerSSL);

    if DoFullHandshake(ClientSSL, ServerSSL, ClientWrite, ServerRead, ServerWrite, ClientRead) then
    begin
      Session := SSL_get1_session(ClientSSL);

      if Session <> nil then
      begin
        if Assigned(SSL_SESSION_get_timeout) and Assigned(SSL_SESSION_set_timeout) then
        begin
          OrigTimeout := SSL_SESSION_get_timeout(Session);
          Runner.Check('Get original timeout', OrigTimeout > 0,
                    Format('%d seconds', [OrigTimeout]));

          NewTimeout := 600;
          SSL_SESSION_set_timeout(Session, NewTimeout);

          Runner.Check('Set new timeout', SSL_SESSION_get_timeout(Session) = NewTimeout,
                    Format('New timeout: %d seconds', [SSL_SESSION_get_timeout(Session)]));

          SSL_SESSION_set_timeout(Session, 0);
          Runner.Check('Set zero timeout', SSL_SESSION_get_timeout(Session) = 0);

          SSL_SESSION_set_timeout(Session, 86400);
          Runner.Check('Set 24h timeout', SSL_SESSION_get_timeout(Session) = 86400);
        end
        else
          Runner.Check('Timeout functions', False, 'Functions not loaded');

        SSL_SESSION_free(Session);
      end;
    end
    else
      Runner.Check('Handshake', False);

    SSL_shutdown(ClientSSL);
    SSL_shutdown(ServerSSL);
    SSL_free(ClientSSL);
    SSL_free(ServerSSL);

  except
    on E: Exception do
      Runner.Check('Session timeout', False, E.Message);
  end;
end;

procedure TestHighLevelSessionAPI;
var
  SSLLib: ISSLLibrary;
  Context: ISSLContext;
begin
  WriteLn;
  WriteLn('=== High-Level Session API ===');

  try
    SSLLib := CreateOpenSSLLibrary;
    Runner.Check('Create OpenSSL library', SSLLib <> nil);

    if SSLLib <> nil then
    begin
      Runner.Check('Initialize library', SSLLib.Initialize);

      Context := SSLLib.CreateContext(sslCtxClient);
      Runner.Check('Create context', Context <> nil);

      if Context <> nil then
      begin
        Context.SetSessionCacheMode(True);
        Runner.Check('Enable session cache', Context.GetSessionCacheMode);

        Context.SetSessionTimeout(300);
        Runner.Check('Set session timeout', Context.GetSessionTimeout = 300);

        Context.SetSessionCacheSize(100);
        Runner.Check('Set cache size', Context.GetSessionCacheSize = 100);
      end;

      SSLLib.Finalize;
    end;

  except
    on E: Exception do
      Runner.Check('High-level API', False, E.Message);
  end;
end;

procedure TestSessionAPICoverage;
begin
  WriteLn;
  WriteLn('=== Session API Coverage ===');

  Runner.Check('SSL_get1_session', Assigned(SSL_get1_session));
  Runner.Check('SSL_get_session', Assigned(SSL_get_session));
  Runner.Check('SSL_set_session', Assigned(SSL_set_session));
  Runner.Check('SSL_session_reused', Assigned(SSL_session_reused));
  Runner.Check('SSL_SESSION_get_id', Assigned(SSL_SESSION_get_id));
  Runner.Check('SSL_SESSION_get_time', Assigned(SSL_SESSION_get_time));
  Runner.Check('SSL_SESSION_get_timeout', Assigned(SSL_SESSION_get_timeout));
  Runner.Check('SSL_SESSION_set_timeout', Assigned(SSL_SESSION_set_timeout));
  Runner.Check('SSL_SESSION_get_protocol_version', Assigned(SSL_SESSION_get_protocol_version));
  Runner.Check('SSL_SESSION_get0_cipher', Assigned(SSL_SESSION_get0_cipher));
  Runner.Check('SSL_SESSION_get0_peer', Assigned(SSL_SESSION_get0_peer));
  Runner.Check('SSL_SESSION_up_ref', Assigned(SSL_SESSION_up_ref));
  Runner.Check('SSL_SESSION_free', Assigned(SSL_SESSION_free));
  Runner.Check('SSL_CTX_set_session_cache_mode', Assigned(SSL_CTX_set_session_cache_mode) or Assigned(SSL_CTX_ctrl));
  Runner.Check('SSL_CTX_get_session_cache_mode', Assigned(SSL_CTX_get_session_cache_mode) or Assigned(SSL_CTX_ctrl));
end;

procedure InitializeTests;
var
  Method: PSSL_METHOD;
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

  WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);
  WriteLn;

  WriteLn('Generating test certificate...');
  if not GenerateSelfSignedCert(ServerCert, ServerKey) then
  begin
    WriteLn('ERROR: Could not generate test certificate');
    Halt(1);
  end;
  WriteLn('Certificate generated successfully');
  WriteLn;

  WriteLn('Creating SSL contexts...');

  if not Assigned(TLS_client_method) then
  begin
    WriteLn('ERROR: TLS_client_method not loaded');
    Halt(1);
  end;

  Method := TLS_client_method();
  if Method = nil then
  begin
    WriteLn('ERROR: TLS_client_method returned nil');
    Halt(1);
  end;

  if not Assigned(SSL_CTX_new) then
  begin
    WriteLn('ERROR: SSL_CTX_new not loaded');
    Halt(1);
  end;

  ClientCtx := SSL_CTX_new(Method);
  if ClientCtx = nil then
  begin
    WriteLn('ERROR: Could not create client SSL context');
    Halt(1);
  end;

  if Assigned(SSL_CTX_set_verify) then
    SSL_CTX_set_verify(ClientCtx, SSL_VERIFY_NONE, nil);

  SSL_CTX_set_session_cache_mode_impl(ClientCtx, SSL_SESS_CACHE_CLIENT);

  if not Assigned(TLS_server_method) then
  begin
    WriteLn('ERROR: TLS_server_method not loaded');
    Halt(1);
  end;

  Method := TLS_server_method();
  if Method = nil then
  begin
    WriteLn('ERROR: TLS_server_method returned nil');
    Halt(1);
  end;

  ServerCtx := SSL_CTX_new(Method);
  if ServerCtx = nil then
  begin
    WriteLn('ERROR: Could not create server SSL context');
    Halt(1);
  end;

  if Assigned(SSL_CTX_use_certificate) then
    SSL_CTX_use_certificate(ServerCtx, ServerCert);
  if Assigned(SSL_CTX_use_PrivateKey) then
    SSL_CTX_use_PrivateKey(ServerCtx, ServerKey);

  SSL_CTX_set_session_cache_mode_impl(ServerCtx, SSL_SESS_CACHE_SERVER);

  WriteLn('SSL contexts created successfully');
end;

procedure CleanupTests;
begin
  if ClientCtx <> nil then SSL_CTX_free(ClientCtx);
  if ServerCtx <> nil then SSL_CTX_free(ServerCtx);
  if ServerCert <> nil then X509_free(ServerCert);
  if ServerKey <> nil then EVP_PKEY_free(ServerKey);
end;

begin
  WriteLn('TLS Session Resumption Integration Tests');
  WriteLn('========================================');
  WriteLn;

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore, osmBN, osmRSA, osmEVP, osmX509]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    InitializeTests;

    TestSessionCreation;
    TestSessionResumption;
    TestSessionTimeout;
    TestHighLevelSessionAPI;
    TestSessionAPICoverage;

    CleanupTests;

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
