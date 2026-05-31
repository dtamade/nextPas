program test_ssl_handshake;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.consts;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  
  // SSL Context and objects
  ClientCtx, ServerCtx: PSSL_CTX;
  ClientSSL, ServerSSL: PSSL;
  
  // BIO pairs for connecting client and server
  ClientToBioInternal, ClientToBioNetwork: PBIO;
  ServerToBioInternal, ServerToBioNetwork: PBIO;

procedure TestResult(const TestName: string; Passed: Boolean; const Reason: string = '');
begin
  if Passed then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    if Reason <> '' then
      WriteLn('       Reason: ', Reason);
    Inc(TestsFailed);
  end;
end;

procedure PrintSeparator;
begin
  WriteLn('----------------------------------------');
end;

procedure PrintHeader(const Title: string);
begin
  WriteLn;
  WriteLn('Test: ', Title);
  PrintSeparator;
end;

{ Transfer data between BIO pairs to simulate network communication }
function TransferBIOData(FromBIO, ToBIO: PBIO): Integer;
var
  Buffer: array[0..16383] of Byte;
  BytesRead, BytesWritten: Integer;
begin
  Result := 0;
  
  if not Assigned(BIO_ctrl) then
    Exit;
    
  // Check if there's data to transfer
  BytesRead := BIO_ctrl(FromBIO, BIO_CTRL_PENDING, 0, nil);
  if BytesRead <= 0 then
    Exit;
    
  // Read from source BIO
  if BytesRead > SizeOf(Buffer) then
    BytesRead := SizeOf(Buffer);
    
  if Assigned(BIO_read) then
    BytesRead := BIO_read(FromBIO, @Buffer[0], BytesRead)
  else
    Exit;
    
  if BytesRead <= 0 then
    Exit;
    
  // Write to destination BIO
  if Assigned(BIO_write) then
    BytesWritten := BIO_write(ToBIO, @Buffer[0], BytesRead)
  else
    Exit;
    
  Result := BytesWritten;
end;

{ Pump data between client and server BIOs }
procedure PumpBIOData;
begin
  // Transfer data from client to server
  TransferBIOData(ClientToBioNetwork, ServerToBioNetwork);
  
  // Transfer data from server to client
  TransferBIOData(ServerToBioNetwork, ClientToBioNetwork);
end;

procedure Test1_LoadLibraries;
begin
  PrintHeader('Load OpenSSL Libraries');
  try
    LoadOpenSSLCore;
    TestResult('Load OpenSSL core', True);
    
    LoadOpenSSLBIO;
    TestResult('Load BIO module', True);
    
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

procedure Test2_CreateContexts;
var
  Method: PSSL_METHOD;
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
    
  except
    on E: Exception do
      TestResult('Create contexts', False, E.Message);
  end;
end;

procedure Test3_CreateBIOPairs;
var
  Ret: Integer;
begin
  PrintHeader('Create BIO Pairs');
  try
    // Create BIO pair for client
    if not Assigned(BIO_new_bio_pair) then
    begin
      TestResult('BIO_new_bio_pair available', False, 'Function not loaded');
      // Try alternative: create memory BIOs
      WriteLn('       Attempting alternative: memory BIOs');
      
      if Assigned(BIO_s_mem) and Assigned(BIO_new) then
      begin
        ClientToBioInternal := BIO_new(BIO_s_mem());
        ClientToBioNetwork := BIO_new(BIO_s_mem());
        ServerToBioInternal := BIO_new(BIO_s_mem());
        ServerToBioNetwork := BIO_new(BIO_s_mem());
        
        if (ClientToBioInternal <> nil) and (ClientToBioNetwork <> nil) and
           (ServerToBioInternal <> nil) and (ServerToBioNetwork <> nil) then
        begin
          TestResult('Create memory BIOs (alternative)', True);
          Exit;
        end
        else
        begin
          TestResult('Create memory BIOs', False, 'BIO creation failed');
          Exit;
        end;
      end
      else
      begin
        TestResult('Create BIOs', False, 'No BIO functions available');
        Exit;
      end;
    end;
    
    // Create BIO pairs
    Ret := BIO_new_bio_pair(@ClientToBioInternal, 0, @ClientToBioNetwork, 0);
    if Ret <> 1 then
    begin
      TestResult('Create client BIO pair', False, 'Return code: ' + IntToStr(Ret));
      Exit;
    end;
    TestResult('Create client BIO pair', True);
    
    Ret := BIO_new_bio_pair(@ServerToBioInternal, 0, @ServerToBioNetwork, 0);
    if Ret <> 1 then
    begin
      TestResult('Create server BIO pair', False, 'Return code: ' + IntToStr(Ret));
      Exit;
    end;
    TestResult('Create server BIO pair', True);
    
  except
    on E: Exception do
      TestResult('Create BIO pairs', False, E.Message);
  end;
end;

procedure Test4_CreateSSLObjects;
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
    
  except
    on E: Exception do
      TestResult('Create SSL objects', False, E.Message);
  end;
end;

procedure Test5_AttachBIOs;
begin
  PrintHeader('Attach BIOs to SSL Objects');
  try
    if (ClientSSL = nil) or (ServerSSL = nil) then
    begin
      TestResult('Attach BIOs', False, 'SSL objects not created');
      Exit;
    end;
    
    if (ClientToBioInternal = nil) or (ClientToBioNetwork = nil) or
       (ServerToBioInternal = nil) or (ServerToBioNetwork = nil) then
    begin
      TestResult('Attach BIOs', False, 'BIOs not created');
      Exit;
    end;
    
    // Attach BIOs to client SSL
    // Note: SSL takes ownership of the BIOs
    SSL_set_bio(ClientSSL, ClientToBioInternal, ClientToBioInternal);
    TestResult('Attach client BIOs', True);
    
    // Attach BIOs to server SSL
    SSL_set_bio(ServerSSL, ServerToBioInternal, ServerToBioInternal);
    TestResult('Attach server BIOs', True);
    
  except
    on E: Exception do
      TestResult('Attach BIOs', False, E.Message);
  end;
end;

procedure Test6_SetConnectionStates;
begin
  PrintHeader('Set Connection States');
  try
    if (ClientSSL = nil) or (ServerSSL = nil) then
    begin
      TestResult('Set states', False, 'SSL objects not created');
      Exit;
    end;
    
    // Set client to connect mode
    SSL_set_connect_state(ClientSSL);
    TestResult('Set client connect state', True);
    
    // Set server to accept mode
    SSL_set_accept_state(ServerSSL);
    TestResult('Set server accept state', True);
    
  except
    on E: Exception do
      TestResult('Set connection states', False, E.Message);
  end;
end;

procedure Test7_PerformHandshake;
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
    
    if not Assigned(SSL_do_handshake) then
    begin
      TestResult('SSL_do_handshake available', False, 'Function not loaded');
      Exit;
    end;
    TestResult('SSL_do_handshake available', True);
    
    HandshakeComplete := False;
    MaxIterations := 100;  // Prevent infinite loops
    
    for i := 1 to MaxIterations do
    begin
      // Try client handshake
      ClientRet := SSL_do_handshake(ClientSSL);
      if ClientRet = 1 then
      begin
        WriteLn('       Client handshake complete at iteration ', i);
      end
      else
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
      
      // Pump data between client and server
      PumpBIOData;
      
      // Try server handshake
      ServerRet := SSL_do_handshake(ServerSSL);
      if ServerRet = 1 then
      begin
        WriteLn('       Server handshake complete at iteration ', i);
      end
      else
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
      PumpBIOData;
      
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

procedure Test8_DataTransfer;
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
    
    if not Assigned(SSL_write) or not Assigned(SSL_read) then
    begin
      TestResult('SSL_write/SSL_read available', False, 'Functions not loaded');
      Exit;
    end;
    TestResult('SSL_write/SSL_read available', True);
    
    // Client sends data to server
    SendBuf := TEST_MESSAGE;
    BytesWritten := SSL_write(ClientSSL, PAnsiChar(SendBuf), Length(SendBuf));
    
    if BytesWritten > 0 then
    begin
      TestResult('Client write data', True, IntToStr(BytesWritten) + ' bytes written');
    end
    else
    begin
      TestResult('Client write data', False, 
        'Error: ' + IntToStr(SSL_get_error(ClientSSL, BytesWritten)));
      Exit;
    end;
    
    // Pump data from client to server
    PumpBIOData;
    
    // Server receives data
    FillChar(RecvBuf, SizeOf(RecvBuf), 0);
    BytesRead := SSL_read(ServerSSL, @RecvBuf[0], SizeOf(RecvBuf));
    
    if BytesRead > 0 then
    begin
      SetString(ReceivedMessage, PAnsiChar(@RecvBuf[0]), BytesRead);
      TestResult('Server read data', True, IntToStr(BytesRead) + ' bytes read');
      
      // Verify data integrity
      if ReceivedMessage = TEST_MESSAGE then
        TestResult('Data integrity check', True, 'Messages match')
      else
        TestResult('Data integrity check', False, 
          'Expected: "' + TEST_MESSAGE + '", Got: "' + ReceivedMessage + '"');
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

procedure Test9_Cleanup;
begin
  PrintHeader('Cleanup Resources');
  try
    // Free SSL objects
    if ClientSSL <> nil then
    begin
      SSL_free(ClientSSL);
      TestResult('Free client SSL', True);
      ClientSSL := nil;
    end;
    
    if ServerSSL <> nil then
    begin
      SSL_free(ServerSSL);
      TestResult('Free server SSL', True);
      ServerSSL := nil;
    end;
    
    // Free contexts
    if ClientCtx <> nil then
    begin
      SSL_CTX_free(ClientCtx);
      TestResult('Free client context', True);
      ClientCtx := nil;
    end;
    
    if ServerCtx <> nil then
    begin
      SSL_CTX_free(ServerCtx);
      TestResult('Free server context', True);
      ServerCtx := nil;
    end;
    
  except
    on E: Exception do
      TestResult('Cleanup', False, E.Message);
  end;
end;

procedure PrintSummary;
var
  Total: Integer;
  PassRate: Double;
begin
  WriteLn;
  WriteLn('========================================');
  WriteLn('TEST SUMMARY');
  WriteLn('========================================');
  
  Total := TestsPassed + TestsFailed;
  if Total > 0 then
    PassRate := (TestsPassed / Total) * 100
  else
    PassRate := 0;
    
  WriteLn('Total tests: ', Total);
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Pass rate: ', PassRate:0:1, '%');
  WriteLn('========================================');
  
  if TestsFailed = 0 then
  begin
    WriteLn('Result: ALL TESTS PASSED! 🎉');
    Halt(0);
  end
  else
  begin
    WriteLn('Result: ', TestsFailed, ' test(s) failed');
    Halt(1);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('SSL/TLS Handshake and Data Transfer Test');
  WriteLn('Phase 4: Integration Testing');
  WriteLn('========================================');
  
  Test1_LoadLibraries;
  Test2_CreateContexts;
  Test3_CreateBIOPairs;
  Test4_CreateSSLObjects;
  Test5_AttachBIOs;
  Test6_SetConnectionStates;
  Test7_PerformHandshake;
  Test8_DataTransfer;
  Test9_Cleanup;
  
  PrintSummary;
end.
