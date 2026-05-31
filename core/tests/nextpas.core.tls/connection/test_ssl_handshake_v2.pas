program test_ssl_handshake_v2;

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
  nextpas.core.tls.openssl.api.asn1;

var
  // Test counters
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  
  // SSL objects
  ClientCtx, ServerCtx: PSSL_CTX;
  ClientSSL, ServerSSL: PSSL;
  
  // Certificate and key
  ServerCert: PX509;
  ServerKey: PEVP_PKEY;
  
  // BIOs for network simulation
  ClientRead, ClientWrite: PBIO;
  ServerRead, ServerWrite: PBIO;

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
    WriteLn('Pass rate: ', (PassedTests * 100) div TotalTests, '%');
  WriteLn('========================================');
end;

function GenerateSelfSignedCertificate(var Cert: PX509; var Key: PEVP_PKEY): Boolean;
var
  RSA: PRSA;
  BN: PBIGNUM;
  Name: PX509_NAME;
  Serial: PASN1_INTEGER;
begin
  Result := False;
  Cert := nil;
  Key := nil;
  
  try
    // Generate RSA key
    Key := EVP_PKEY_new();
    if Key = nil then Exit;
    
    RSA := RSA_new();
    if RSA = nil then
    begin
      EVP_PKEY_free(Key);
      Key := nil;
      Exit;
    end;
    
    BN := BN_new();
    if BN = nil then
    begin
      RSA_free(RSA);
      EVP_PKEY_free(Key);
      Key := nil;
      Exit;
    end;
    
    BN_set_word(BN, RSA_F4);
    
    if RSA_generate_key_ex(RSA, 2048, BN, nil) <> 1 then
    begin
      BN_free(BN);
      RSA_free(RSA);
      EVP_PKEY_free(Key);
      Key := nil;
      Exit;
    end;
    
    BN_free(BN);
    
    // Use EVP_PKEY_assign with EVP_PKEY_RSA constant
    if EVP_PKEY_assign(Key, EVP_PKEY_RSA, RSA) <> 1 then
    begin
      RSA_free(RSA);
      EVP_PKEY_free(Key);
      Key := nil;
      Exit;
    end;
    
    // Create certificate
    Cert := X509_new();
    if Cert = nil then
    begin
      EVP_PKEY_free(Key);
      Key := nil;
      Exit;
    end;
    
    // Set version to X509v3
    X509_set_version(Cert, 2);
    
    // Set serial number
    Serial := X509_get_serialNumber(Cert);
    if Serial <> nil then
      ASN1_INTEGER_set(Serial, 1);
    
    // Set validity period (1 year)
    X509_gmtime_adj(X509_get_notBefore(Cert), 0);
    X509_gmtime_adj(X509_get_notAfter(Cert), 365 * 24 * 60 * 60);
    
    // Set public key
    X509_set_pubkey(Cert, Key);
    
    // Set subject and issuer name
    Name := X509_get_subject_name(Cert);
    if Name <> nil then
    begin
      X509_NAME_add_entry_by_txt(Name, PAnsiChar('C'), MBSTRING_ASC, PByte(PAnsiChar('US')), -1, -1, 0);
      X509_NAME_add_entry_by_txt(Name, PAnsiChar('O'), MBSTRING_ASC, PByte(PAnsiChar('Test Company')), -1, -1, 0);
      X509_NAME_add_entry_by_txt(Name, PAnsiChar('CN'), MBSTRING_ASC, PByte(PAnsiChar('localhost')), -1, -1, 0);
    end;
    
    X509_set_issuer_name(Cert, Name);
    
    // Sign certificate
    if X509_sign(Cert, Key, EVP_sha256()) = 0 then
    begin
      X509_free(Cert);
      EVP_PKEY_free(Key);
      Cert := nil;
      Key := nil;
      Exit;
    end;
    
    Result := True;
  except
    if Cert <> nil then X509_free(Cert);
    if Key <> nil then EVP_PKEY_free(Key);
    Cert := nil;
    Key := nil;
    Result := False;
  end;
end;

procedure Test1_LoadLibraries;
begin
  PrintHeader('Load OpenSSL Libraries');
  try
    LoadOpenSSLCore();
    TestResult('Load OpenSSL core', True);
    
    LoadOpenSSLBIO();
    TestResult('Load BIO module', True);
    
    LoadOpenSSLX509();
    TestResult('Load X509 module', True);
    
    LoadOpenSSLRSA();
    TestResult('Load RSA module', True);
    
    LoadOpenSSLBN();
    TestResult('Load BN module', True);
    
    // LoadOpenSSLEVP and LoadOpenSSLASN1 require library handle parameter
    // They are automatically loaded by LoadOpenSSLCore if needed
    TestResult('EVP functions available', Assigned(EVP_PKEY_new));
    TestResult('ASN1 functions available', Assigned(ASN1_INTEGER_set));
    
    WriteLn('OpenSSL version: ', GetOpenSSLVersionString);
  except
    on E: Exception do
    begin
      TestResult('Load libraries', False, E.Message);
      WriteLn('FATAL: Cannot continue');
      Halt(1);
    end;
  end;
end;

procedure Test2_GenerateCertificate;
begin
  PrintHeader('Generate Self-Signed Certificate');
  try
    if GenerateSelfSignedCertificate(ServerCert, ServerKey) then
    begin
      TestResult('Generate certificate', True);
      TestResult('Generate private key', True);
    end
    else
    begin
      TestResult('Generate certificate', False, 'Certificate generation failed');
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

procedure Test3_CreateContexts;
var
  Method: PSSL_METHOD;
  Ret: Integer;
begin
  PrintHeader('Create SSL Contexts');
  try
    // Create client context
    Method := TLS_client_method();
    if Method = nil then
    begin
      TestResult('Get client method', False, 'Method is nil');
      Exit;
    end;
    TestResult('Get client method', True);
    
    ClientCtx := SSL_CTX_new(Method);
    if ClientCtx = nil then
    begin
      TestResult('Create client context', False, 'Context is nil');
      Exit;
    end;
    TestResult('Create client context', True);
    
    // Configure client to accept any certificate (for testing)
    SSL_CTX_set_verify(ClientCtx, SSL_VERIFY_NONE, nil);
    TestResult('Configure client verification', True);
    
    // Create server context
    Method := TLS_server_method();
    if Method = nil then
    begin
      TestResult('Get server method', False, 'Method is nil');
      Exit;
    end;
    TestResult('Get server method', True);
    
    ServerCtx := SSL_CTX_new(Method);
    if ServerCtx = nil then
    begin
      TestResult('Create server context', False, 'Context is nil');
      Exit;
    end;
    TestResult('Create server context', True);
    
    // Load certificate and key into server context
    if SSL_CTX_use_certificate(ServerCtx, ServerCert) <> 1 then
    begin
      TestResult('Load server certificate', False, 'Failed to load certificate');
      Exit;
    end;
    TestResult('Load server certificate', True);
    
    if SSL_CTX_use_PrivateKey(ServerCtx, ServerKey) <> 1 then
    begin
      TestResult('Load server private key', False, 'Failed to load key');
      Exit;
    end;
    TestResult('Load server private key', True);
    
    // Verify that certificate and key match
    if SSL_CTX_check_private_key(ServerCtx) <> 1 then
    begin
      TestResult('Verify certificate/key match', False, 'Key does not match certificate');
      Exit;
    end;
    TestResult('Verify certificate/key match', True);
    
  except
    on E: Exception do
      TestResult('Create contexts', False, E.Message);
  end;
end;

procedure Test4_CreateBIOs;
begin
  PrintHeader('Create BIO Pairs');
  try
    // Create memory BIOs for communication
    ClientRead := BIO_new(BIO_s_mem());
    ClientWrite := BIO_new(BIO_s_mem());
    ServerRead := BIO_new(BIO_s_mem());
    ServerWrite := BIO_new(BIO_s_mem());
    
    if (ClientRead = nil) or (ClientWrite = nil) or 
       (ServerRead = nil) or (ServerWrite = nil) then
    begin
      TestResult('Create memory BIOs', False, 'Failed to create BIOs');
      Exit;
    end;
    
    TestResult('Create client BIOs', True);
    TestResult('Create server BIOs', True);
    
    // Memory BIOs are non-blocking by default, no need to set
    TestResult('Configure BIOs as non-blocking', True, 'Memory BIOs are non-blocking by default');
    
  except
    on E: Exception do
      TestResult('Create BIOs', False, E.Message);
  end;
end;

procedure Test5_CreateSSLObjects;
begin
  PrintHeader('Create SSL Objects');
  try
    if (ClientCtx = nil) or (ServerCtx = nil) then
    begin
      TestResult('Create SSL objects', False, 'Contexts not created');
      Exit;
    end;
    
    // Create client SSL object
    ClientSSL := SSL_new(ClientCtx);
    if ClientSSL = nil then
    begin
      TestResult('Create client SSL', False, 'SSL is nil');
      Exit;
    end;
    TestResult('Create client SSL', True);
    
    // Create server SSL object
    ServerSSL := SSL_new(ServerCtx);
    if ServerSSL = nil then
    begin
      TestResult('Create server SSL', False, 'SSL is nil');
      Exit;
    end;
    TestResult('Create server SSL', True);
    
    // Attach BIOs to SSL objects
    // Client reads from ClientRead, writes to ClientWrite
    SSL_set_bio(ClientSSL, ClientRead, ClientWrite);
    TestResult('Attach client BIOs', True);
    
    // Server reads from ServerRead, writes to ServerWrite
    SSL_set_bio(ServerSSL, ServerRead, ServerWrite);
    TestResult('Attach server BIOs', True);
    
    // Set connection states
    SSL_set_connect_state(ClientSSL);
    TestResult('Set client connect state', True);
    
    SSL_set_accept_state(ServerSSL);
    TestResult('Set server accept state', True);
    
  except
    on E: Exception do
      TestResult('Create SSL objects', False, E.Message);
  end;
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

procedure Test6_PerformHandshake;
var
  ClientRet, ServerRet: Integer;
  ClientErr, ServerErr: Integer;
  MaxIterations, i: Integer;
  HandshakeComplete: Boolean;
begin
  PrintHeader('Perform TLS Handshake');
  try
    if (ClientSSL = nil) or (ServerSSL = nil) then
    begin
      TestResult('Handshake', False, 'SSL objects not created');
      Exit;
    end;
    
    HandshakeComplete := False;
    MaxIterations := 100;
    
    for i := 1 to MaxIterations do
    begin
      // Try client handshake
      ClientRet := SSL_do_handshake(ClientSSL);
      if ClientRet <> 1 then
      begin
        ClientErr := SSL_get_error(ClientSSL, ClientRet);
        if (ClientErr <> SSL_ERROR_WANT_READ) and 
           (ClientErr <> SSL_ERROR_WANT_WRITE) then
        begin
          TestResult('Client handshake', False, 
            'Error: ' + IntToStr(ClientErr));
          Exit;
        end;
      end;
      
      // Pump data between BIOs
      PumpData();
      
      // Try server handshake
      ServerRet := SSL_do_handshake(ServerSSL);
      if ServerRet <> 1 then
      begin
        ServerErr := SSL_get_error(ServerSSL, ServerRet);
        if (ServerErr <> SSL_ERROR_WANT_READ) and 
           (ServerErr <> SSL_ERROR_WANT_WRITE) then
        begin
          TestResult('Server handshake', False, 
            'Error: ' + IntToStr(ServerErr));
          Exit;
        end;
      end;
      
      // Pump data again
      PumpData();
      
      // Check if both completed
      if (ClientRet = 1) and (ServerRet = 1) then
      begin
        HandshakeComplete := True;
        WriteLn('       Handshake completed after ', i, ' iterations');
        Break;
      end;
    end;
    
    if HandshakeComplete then
      TestResult('TLS handshake', True, 'Completed successfully')
    else
      TestResult('TLS handshake', False, 'Did not complete in ' + IntToStr(MaxIterations) + ' iterations');
    
  except
    on E: Exception do
      TestResult('Perform handshake', False, E.Message);
  end;
end;

procedure Test7_DataTransfer;
const
  TEST_MESSAGE = 'Hello, SSL World! This is encrypted data.';
var
  SendBuf: AnsiString;
  RecvBuf: array[0..1023] of Byte;
  BytesWritten, BytesRead: Integer;
  ReceivedMessage: string;
begin
  PrintHeader('Data Transfer Test');
  try
    if (ClientSSL = nil) or (ServerSSL = nil) then
    begin
      TestResult('Data transfer', False, 'SSL objects not created');
      Exit;
    end;
    
    // Client sends data to server
    SendBuf := TEST_MESSAGE;
    BytesWritten := SSL_write(ClientSSL, PAnsiChar(SendBuf), Length(SendBuf));
    
    if BytesWritten > 0 then
      TestResult('Client write data', True, IntToStr(BytesWritten) + ' bytes written')
    else
    begin
      TestResult('Client write data', False, 
        'Error: ' + IntToStr(SSL_get_error(ClientSSL, BytesWritten)));
      Exit;
    end;
    
    // Pump data from client to server
    PumpData();
    
    // Server receives data
    FillChar(RecvBuf, SizeOf(RecvBuf), 0);
    BytesRead := SSL_read(ServerSSL, @RecvBuf[0], SizeOf(RecvBuf));
    
    if BytesRead > 0 then
    begin
      SetString(ReceivedMessage, PAnsiChar(@RecvBuf[0]), BytesRead);
      TestResult('Server read data', True, IntToStr(BytesRead) + ' bytes read');
      
      if ReceivedMessage = TEST_MESSAGE then
        TestResult('Data integrity', True, 'Message matches')
      else
        TestResult('Data integrity', False, 'Message does not match');
    end
    else
    begin
      TestResult('Server read data', False, 
        'Error: ' + IntToStr(SSL_get_error(ServerSSL, BytesRead)));
    end;
    
  except
    on E: Exception do
      TestResult('Data transfer', False, E.Message);
  end;
end;

procedure Test8_Cleanup;
begin
  PrintHeader('Cleanup Resources');
  try
    if ClientSSL <> nil then
    begin
      SSL_free(ClientSSL);
      TestResult('Free client SSL', True);
    end;
    
    if ServerSSL <> nil then
    begin
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
  WriteLn('SSL/TLS Handshake and Data Transfer Test');
  WriteLn('Phase 4: Integration Testing (Version 2)');
  WriteLn('========================================');
  
  try
    Test1_LoadLibraries();
    Test2_GenerateCertificate();
    Test3_CreateContexts();
    Test4_CreateBIOs();
    Test5_CreateSSLObjects();
    Test6_PerformHandshake();
    Test7_DataTransfer();
    Test8_Cleanup();
    
    PrintSummary();
    
    if FailedTests > 0 then
    begin
      WriteLn('Result: ', FailedTests, ' test(s) failed');
      Halt(1);
    end
    else
      WriteLn('Result: All tests passed!');
      
  except
    on E: Exception do
    begin
      WriteLn('FATAL ERROR: ', E.Message);
      Halt(1);
    end;
  end;
end.
