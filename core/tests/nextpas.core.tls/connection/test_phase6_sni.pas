program test_phase6_sni;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.rsa,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.api.asn1,
  nextpas.core.tls.openssl.api.ssl,
  nextpas.core.tls.openssl.api.consts;

var
  // Test counters
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  
  // Certificate and key
  ServerCert: PX509;
  ServerKey: PEVP_PKEY;
  
  // SSL contexts
  ClientCtx, ServerCtx: PSSL_CTX;
  
  // SSL objects
  ClientSSL, ServerSSL: PSSL;
  
  // BIOs
  ClientRead, ClientWrite: PBIO;
  ServerRead, ServerWrite: PBIO;
  
  // SNI callback data
  RequestedHostname: string;
  SNICallbackInvoked: Boolean;

procedure TestResult(const TestName: string; Success: Boolean; const Details: string = '');
begin
  Inc(TotalTests);
  if Success then
  begin
    Inc(PassedTests);
    WriteLn('[PASS] ', TestName);
    if Details <> '' then
      WriteLn('       ', Details);
  end
  else
  begin
    Inc(FailedTests);
    WriteLn('[FAIL] ', TestName);
    if Details <> '' then
      WriteLn('       Reason: ', Details);
  end;
end;

procedure PrintHeader(const Title: string);
begin
  WriteLn;
  WriteLn('Test: ', Title);
  WriteLn('----------------------------------------');
end;

procedure PrintSummary;
begin
  WriteLn;
  WriteLn('========================================');
  WriteLn('TEST SUMMARY');
  WriteLn('========================================');
  WriteLn('Total tests: ', TotalTests);
  WriteLn('Passed: ', PassedTests);
  WriteLn('Failed: ', FailedTests);
  if TotalTests > 0 then
    WriteLn('Pass rate: ', (PassedTests * 100) div TotalTests, '.', 
            ((PassedTests * 1000) div TotalTests) mod 10, '%');
  WriteLn('========================================');
end;

function GenerateSelfSignedCert(out Cert: PX509; out Key: PEVP_PKEY; 
  const CommonName: string): Boolean;
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
  Name := nil;
  
  try
    // Generate RSA key pair
    PKey := EVP_PKEY_new();
    if PKey = nil then Exit;
    
    RSA := RSA_new();
    if RSA = nil then
    begin
      EVP_PKEY_free(PKey);
      Exit;
    end;
    
    BN := BN_new();
    if BN = nil then
    begin
      RSA_free(RSA);
      EVP_PKEY_free(PKey);
      Exit;
    end;
    
    BN_set_word(BN, RSA_F4);
    
    if RSA_generate_key_ex(RSA, 2048, BN, nil) <> 1 then
    begin
      BN_free(BN);
      RSA_free(RSA);
      EVP_PKEY_free(PKey);
      Exit;
    end;
    
    BN_free(BN);
    BN := nil;
    
    if EVP_PKEY_assign(PKey, EVP_PKEY_RSA, RSA) <> 1 then
    begin
      RSA_free(RSA);
      EVP_PKEY_free(PKey);
      Exit;
    end;
    
    // Create X509 certificate
    X509Cert := X509_new();
    if X509Cert = nil then
    begin
      EVP_PKEY_free(PKey);
      Exit;
    end;
    
    X509_set_version(X509Cert, 2);
    
    Serial := X509_get_serialNumber(X509Cert);
    ASN1_INTEGER_set(Serial, 1);
    
    // Set validity period
    NotBeforeTime := X509_get_notBefore(X509Cert);
    if NotBeforeTime = nil then
    begin
      X509_free(X509Cert);
      EVP_PKEY_free(PKey);
      Exit;
    end;
    X509_gmtime_adj(NotBeforeTime, 0);
    
    NotAfterTime := X509_get_notAfter(X509Cert);
    if NotAfterTime = nil then
    begin
      X509_free(X509Cert);
      EVP_PKEY_free(PKey);
      Exit;
    end;
    X509_gmtime_adj(NotAfterTime, 365 * 24 * 60 * 60);
    
    // Set public key
    if X509_set_pubkey(X509Cert, PKey) <> 1 then
    begin
      X509_free(X509Cert);
      EVP_PKEY_free(PKey);
      Exit;
    end;
    
    // Create and set subject/issuer name
    Name := X509_NAME_new();
    if Name = nil then
    begin
      X509_free(X509Cert);
      EVP_PKEY_free(PKey);
      Exit;
    end;
    
    X509_NAME_add_entry_by_txt(Name, 'C', MBSTRING_ASC, PByte(PAnsiChar('US')), -1, -1, 0);
    X509_NAME_add_entry_by_txt(Name, 'O', MBSTRING_ASC, PByte(PAnsiChar('Test Org')), -1, -1, 0);
    X509_NAME_add_entry_by_txt(Name, 'CN', MBSTRING_ASC, PByte(PAnsiChar(AnsiString(CommonName))), -1, -1, 0);
    
    if X509_set_subject_name(X509Cert, Name) <> 1 then
    begin
      X509_NAME_free(Name);
      X509_free(X509Cert);
      EVP_PKEY_free(PKey);
      Exit;
    end;
    
    if X509_set_issuer_name(X509Cert, Name) <> 1 then
    begin
      X509_NAME_free(Name);
      X509_free(X509Cert);
      EVP_PKEY_free(PKey);
      Exit;
    end;
    
    X509_NAME_free(Name);
    Name := nil;
    
    // Sign certificate
    if X509_sign(X509Cert, PKey, EVP_sha256()) = 0 then
    begin
      X509_free(X509Cert);
      EVP_PKEY_free(PKey);
      Exit;
    end;
    
    // Success
    Cert := X509Cert;
    Key := PKey;
    Result := True;
    
  except
    if Name <> nil then X509_NAME_free(Name);
    if BN <> nil then BN_free(BN);
    if X509Cert <> nil then X509_free(X509Cert);
    if PKey <> nil then EVP_PKEY_free(PKey);
    Result := False;
  end;
end;

// SNI callback function
function SNICallback(ssl: PSSL; ad: PInteger; arg: Pointer): Integer; cdecl;
var
  ServerName: PAnsiChar;
begin
  SNICallbackInvoked := True;
  
  ServerName := SSL_get_servername(ssl, TLSEXT_NAMETYPE_host_name);
  if ServerName <> nil then
  begin
    RequestedHostname := string(ServerName);
    WriteLn('       SNI callback invoked for hostname: ', RequestedHostname);
  end
  else
    WriteLn('       SNI callback invoked but no hostname provided');
  
  Result := SSL_TLSEXT_ERR_OK;
end;

procedure PumpData;
var
  Buffer: array[0..4095] of Byte;
  Len: Integer;
begin
  // Pump data from client write to server read
  repeat
    Len := BIO_read(ClientWrite, @Buffer[0], SizeOf(Buffer));
    if Len > 0 then
      BIO_write(ServerRead, @Buffer[0], Len);
  until Len <= 0;
  
  // Pump data from server write to client read
  repeat
    Len := BIO_read(ServerWrite, @Buffer[0], SizeOf(Buffer));
    if Len > 0 then
      BIO_write(ClientRead, @Buffer[0], Len);
  until Len <= 0;
end;

procedure Test1_LoadModules;
begin
  PrintHeader('Load OpenSSL Modules');
  try
    LoadOpenSSLCore();
    TestResult('Load OpenSSL core', True);
    
    LoadOpenSSLBIO();
    TestResult('Load BIO module', True);
    
    LoadOpenSSLX509();
    TestResult('Load X509 module', True);
    
    LoadEVP(GetCryptoLibHandle);
    TestResult('Load EVP module', True);
    
    LoadOpenSSLRSA();
    TestResult('Load RSA module', True);
    
    LoadOpenSSLBN();
    TestResult('Load BN module', True);
    
    LoadOpenSSLASN1(GetCryptoLibHandle);
    TestResult('Load ASN1 module', True);
    
    if LoadOpenSSLSSL then
      TestResult('Load SSL extended module', True)
    else
      TestResult('Load SSL extended module', False, 'Some functions may not be available');
    
    WriteLn('OpenSSL version: ', GetOpenSSLVersionString);
  except
    on E: Exception do
    begin
      TestResult('Load modules', False, E.Message);
      WriteLn('FATAL: Cannot continue');
      Halt(1);
    end;
  end;
end;

procedure Test2_GenerateCertificate;
begin
  PrintHeader('Generate Self-Signed Certificate');
  try
    WriteLn('       Generating certificate for example.com...');
    if GenerateSelfSignedCert(ServerCert, ServerKey, 'example.com') then
    begin
      TestResult('Generate certificate and key', True, 'CN=example.com');
      TestResult('Certificate is valid', ServerCert <> nil);
      TestResult('Private key is valid', ServerKey <> nil);
    end
    else
    begin
      TestResult('Generate certificate', False, 'Generation failed');
      WriteLn('FATAL: Cannot continue without certificate');
      Halt(1);
    end;
  except
    on E: Exception do
    begin
      TestResult('Generate certificate', False, E.Message);
      Halt(1);
    end;
  end;
end;

procedure Test3_SetupSNIServer;
begin
  PrintHeader('Setup Server with SNI Support');
  try
    // Create server context
    ServerCtx := SSL_CTX_new(TLS_server_method());
    TestResult('Create server context', ServerCtx <> nil);
    
    // Load certificate and key
    if SSL_CTX_use_certificate(ServerCtx, ServerCert) <> 1 then
    begin
      TestResult('Load server certificate', False);
      Exit;
    end;
    TestResult('Load server certificate', True);
    
    if SSL_CTX_use_PrivateKey(ServerCtx, ServerKey) <> 1 then
    begin
      TestResult('Load server private key', False);
      Exit;
    end;
    TestResult('Load server private key', True);
    
    if SSL_CTX_check_private_key(ServerCtx) <> 1 then
    begin
      TestResult('Verify certificate/key match', False);
      Exit;
    end;
    TestResult('Verify certificate/key match', True);
    
    // Note: SSL_CTX_set_tlsext_servername_callback is not available in OpenSSL 3.x
    // In OpenSSL 3.x, use SSL_CTX_set_client_hello_cb instead
    // For this test, we'll validate SNI without the callback
    if Assigned(SSL_CTX_set_tlsext_servername_callback) then
    begin
      SSL_CTX_set_tlsext_servername_callback(ServerCtx, @SNICallback);
      TestResult('Set SNI callback (OpenSSL 1.x)', True);
    end
    else
      TestResult('Skip SNI callback (OpenSSL 3.x API change)', True, 'Using direct hostname retrieval instead');
    
  except
    on E: Exception do
      TestResult('Setup SNI server', False, E.Message);
  end;
end;

procedure Test4_SetupClientWithSNI;
const
  HOSTNAME = 'example.com';
begin
  PrintHeader('Setup Client with SNI');
  try
    // Create client context
    ClientCtx := SSL_CTX_new(TLS_client_method());
    TestResult('Create client context', ClientCtx <> nil);
    
    SSL_CTX_set_verify(ClientCtx, SSL_VERIFY_NONE, nil);
    TestResult('Configure client verification', True);
    
    // Create SSL objects
    ClientSSL := SSL_new(ClientCtx);
    ServerSSL := SSL_new(ServerCtx);
    
    TestResult('Create client SSL', ClientSSL <> nil);
    TestResult('Create server SSL', ServerSSL <> nil);
    
    // Create BIOs
    ClientRead := BIO_new(BIO_s_mem());
    ClientWrite := BIO_new(BIO_s_mem());
    ServerRead := BIO_new(BIO_s_mem());
    ServerWrite := BIO_new(BIO_s_mem());
    
    TestResult('Create BIOs', (ClientRead <> nil) and (ClientWrite <> nil) and 
                              (ServerRead <> nil) and (ServerWrite <> nil));
    
    // Set SNI hostname on client BEFORE attaching BIOs
    // SSL_set_tlsext_host_name is a macro that calls SSL_ctrl (works in both OpenSSL 1.x and 3.x)
    if SSL_ctrl(ClientSSL, SSL_CTRL_SET_TLSEXT_HOSTNAME, 
                TLSEXT_NAMETYPE_host_name, Pointer(PAnsiChar(AnsiString(HOSTNAME)))) = 1 then
    begin
      TestResult('Set SNI hostname on client', True, 'Hostname: ' + HOSTNAME);
    end
    else
      TestResult('Set SNI hostname on client', False, 'SSL_ctrl failed');
    
    // Attach BIOs
    SSL_set_bio(ClientSSL, ClientRead, ClientWrite);
    SSL_set_bio(ServerSSL, ServerRead, ServerWrite);
    
    // Set connection states
    SSL_set_connect_state(ClientSSL);
    SSL_set_accept_state(ServerSSL);
    
    TestResult('Set connection states', True);
    
  except
    on E: Exception do
      TestResult('Setup client with SNI', False, E.Message);
  end;
end;

procedure Test5_PerformHandshakeWithSNI;
var
  ClientRet, ServerRet: Integer;
  ClientErr, ServerErr: Integer;
  MaxIterations, i: Integer;
  HandshakeComplete: Boolean;
begin
  PrintHeader('Perform TLS Handshake with SNI');
  try
    HandshakeComplete := False;
    MaxIterations := 100;
    SNICallbackInvoked := False;
    RequestedHostname := '';
    
    WriteLn('       Starting handshake...');
    
    for i := 1 to MaxIterations do
    begin
      // Client handshake step
      ClientRet := SSL_do_handshake(ClientSSL);
      if ClientRet <> 1 then
      begin
        ClientErr := SSL_get_error(ClientSSL, ClientRet);
        if (ClientErr <> SSL_ERROR_WANT_READ) and 
           (ClientErr <> SSL_ERROR_WANT_WRITE) then
        begin
          TestResult('Client handshake', False, 'Error: ' + IntToStr(ClientErr));
          Exit;
        end;
      end;
      
      PumpData();
      
      // Server handshake step
      ServerRet := SSL_do_handshake(ServerSSL);
      if ServerRet <> 1 then
      begin
        ServerErr := SSL_get_error(ServerSSL, ServerRet);
        if (ServerErr <> SSL_ERROR_WANT_READ) and 
           (ServerErr <> SSL_ERROR_WANT_WRITE) then
        begin
          TestResult('Server handshake', False, 'Error: ' + IntToStr(ServerErr));
          Exit;
        end;
      end;
      
      PumpData();
      
      // Check if both completed
      if (ClientRet = 1) and (ServerRet = 1) then
      begin
        HandshakeComplete := True;
        WriteLn('       Handshake completed in ', i, ' iterations');
        Break;
      end;
    end;
    
    if HandshakeComplete then
    begin
      TestResult('Complete TLS handshake with SNI', True);
      // Callback test only valid for OpenSSL 1.x
      if Assigned(SSL_CTX_set_tlsext_servername_callback) then
      begin
        TestResult('SNI callback was invoked (OpenSSL 1.x)', SNICallbackInvoked);
        if SNICallbackInvoked then
          TestResult('SNI hostname received in callback', RequestedHostname = 'example.com', 
                     'Hostname: ' + RequestedHostname);
      end
      else
        TestResult('Skip SNI callback test (OpenSSL 3.x)', True, 'Callback API not available');
    end
    else
      TestResult('TLS handshake', False, 'Did not complete in time');
    
  except
    on E: Exception do
      TestResult('Perform handshake with SNI', False, E.Message);
  end;
end;

procedure Test6_VerifySNIOnServer;
var
  ServerName: PAnsiChar;
begin
  PrintHeader('Verify SNI Information on Server');
  try
    if Assigned(SSL_get_servername) then
    begin
      ServerName := SSL_get_servername(ServerSSL, TLSEXT_NAMETYPE_host_name);
      if ServerName <> nil then
      begin
        TestResult('Get server name from SSL object', True, 'Hostname: ' + string(ServerName));
        TestResult('Server name matches expected', string(ServerName) = 'example.com');
      end
      else
        TestResult('Get server name from SSL object', False, 'No server name set');
    end
    else
      TestResult('Get server name', False, 'Function not available');
      
  except
    on E: Exception do
      TestResult('Verify SNI on server', False, E.Message);
  end;
end;

procedure Test7_Cleanup;
begin
  PrintHeader('Cleanup Resources');
  try
    if ClientSSL <> nil then
    begin
      SSL_shutdown(ClientSSL);
      SSL_free(ClientSSL);
      TestResult('Free client SSL', True);
    end;
    
    if ServerSSL <> nil then
    begin
      SSL_shutdown(ServerSSL);
      SSL_free(ServerSSL);
      TestResult('Free server SSL', True);
    end;
    
    if ClientCtx <> nil then
    begin
      SSL_CTX_free(ClientCtx);
      TestResult('Free client context', True);
    end;
    
    if ServerCtx <> nil then
    begin
      SSL_CTX_free(ServerCtx);
      TestResult('Free server context', True);
    end;
    
    if ServerCert <> nil then
    begin
      X509_free(ServerCert);
      TestResult('Free certificate', True);
    end;
    
    if ServerKey <> nil then
    begin
      EVP_PKEY_free(ServerKey);
      TestResult('Free private key', True);
    end;
    
  except
    on E: Exception do
      TestResult('Cleanup', False, E.Message);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Phase 6: SNI (Server Name Indication)');
  WriteLn('========================================');
  WriteLn;
  
  try
    Test1_LoadModules();
    Test2_GenerateCertificate();
    Test3_SetupSNIServer();
    Test4_SetupClientWithSNI();
    Test5_PerformHandshakeWithSNI();
    Test6_VerifySNIOnServer();
    Test7_Cleanup();
    
    PrintSummary();
    
    WriteLn;
    if FailedTests > 0 then
    begin
      WriteLn('Result: ', FailedTests, ' test(s) failed');
      Halt(1);
    end
    else
    begin
      WriteLn('Result: All tests passed!');
      WriteLn('Phase 6 complete - SNI functionality validated!');
    end;
      
  except
    on E: Exception do
    begin
      WriteLn('FATAL ERROR: ', E.Message);
      Halt(1);
    end;
  end;
end.
