program test_ssl_client_connection;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Sockets, ssockets,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.base,
  nextpas.core.tls.native_handle;

const
  TEST_HOST = 'www.google.com';
  TEST_PORT = 443;
  TEST_REQUEST = 'GET / HTTP/1.0'#13#10'Host: www.google.com'#13#10#13#10;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  SSLLib: ISSLLibrary;
  Context: ISSLContext;
  Connection: ISSLConnection;
  Socket: TInetSocket;
  Stream: TSocketStream;

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

function ConnectToServer(const Host: string; Port: Word): Boolean;
var
  Addr: TInetSockAddr;
begin
  Result := False;
  try
    Socket := TInetSocket.Create(Host, Port);
    Socket.Connect;
    Result := True;
  except
    on E: Exception do
    begin
      WriteLn('Connection error: ', E.Message);
      Result := False;
    end;
  end;
end;

procedure GetCertificateVerificationInfo(AConnection: ISSLConnection;
  out AVerifyResult: Integer; out AVerifyResultString: string);
var
  LCertVerify: ISSLCertificateVerification;
begin
  AVerifyResult := -1;
  AVerifyResultString := 'Not verified';

  if AConnection = nil then
    Exit;

  if Supports(AConnection, ISSLCertificateVerification, LCertVerify) then
  begin
    AVerifyResult := LCertVerify.GetVerifyResult;
    AVerifyResultString := LCertVerify.GetVerifyResultString;
  end
  else
  begin
    {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
    AVerifyResult := AConnection.GetVerifyResult;
    AVerifyResultString := AConnection.GetVerifyResultString;
    {$POP}
  end;
end;

procedure Test1_InitializeLibrary;
begin
  WriteLn('Test 1: Initialize OpenSSL Library');
  try
    SSLLib := TOpenSSLLibrary.Create as ISSLLibrary;
    if SSLLib.Initialize then
    begin
      TestResult('OpenSSL library initialization', True);
      WriteLn('OpenSSL version: ', GetOpenSSLVersionString);
    end
    else
      TestResult('OpenSSL library initialization', False, 'Initialize returned false');
  except
    on E: Exception do
      TestResult('OpenSSL library initialization', False, E.Message);
  end;
  PrintSeparator;
end;

procedure Test2_CreateClientContext;
begin
  WriteLn('Test 2: Create SSL Client Context');
  try
    if SSLLib = nil then
    begin
      TestResult('Create SSL context', False, 'Library not initialized');
      Exit;
    end;
    
    Context := SSLLib.CreateContext(sslCtxClient);
    if Context <> nil then
    begin
      TestResult('Create client context', True);
      if Context.IsValid then
        TestResult('Context is valid', True)
      else
        TestResult('Context is valid', False, 'IsValid returned false');
    end
    else
      TestResult('Create client context', False, 'Context is nil');
  except
    on E: Exception do
      TestResult('Create SSL context', False, E.Message);
  end;
  PrintSeparator;
end;

procedure Test3_ConnectToHost;
begin
  WriteLn('Test 3: Connect to Host (TCP)');
  WriteLn('Connecting to ', TEST_HOST, ':', TEST_PORT, '...');
  try
    if ConnectToServer(TEST_HOST, TEST_PORT) then
    begin
      TestResult('TCP connection', True);
      Stream := TSocketStream.Create(Socket.Handle);
      TestResult('Create socket stream', True);
    end
    else
      TestResult('TCP connection', False, 'Failed to connect');
  except
    on E: Exception do
      TestResult('TCP connection', False, E.Message);
  end;
  PrintSeparator;
end;

procedure Test4_CreateSSLConnection;
begin
  WriteLn('Test 4: Create SSL Connection');
  try
    if Context = nil then
    begin
      TestResult('Create SSL connection', False, 'Context not initialized');
      Exit;
    end;
    
    if Stream = nil then
    begin
      TestResult('Create SSL connection', False, 'Stream not initialized');
      Exit;
    end;
    
    Connection := Context.CreateConnection(Stream);
    if Connection <> nil then
    begin
      TestResult('Create SSL connection object', True);
      
      if GetNativeHandle(Connection) <> nil then
        TestResult('SSL native handle is valid', True)
      else
        TestResult('SSL native handle is valid', False);
    end
    else
      TestResult('Create SSL connection object', False, 'Connection is nil');
  except
    on E: Exception do
      TestResult('Create SSL connection', False, E.Message);
  end;
  PrintSeparator;
end;

procedure Test5_PerformSSLHandshake;
var
  HandshakeState: TSSLHandshakeState;
  Attempts: Integer;
begin
  WriteLn('Test 5: Perform SSL Handshake');
  try
    if Connection = nil then
    begin
      TestResult('SSL handshake', False, 'Connection not initialized');
      Exit;
    end;
    
    WriteLn('Attempting SSL handshake...');
    Attempts := 0;
    repeat
      HandshakeState := Connection.DoHandshake;
      Inc(Attempts);
      
      case HandshakeState of
        sslHsCompleted:
        begin
          TestResult('SSL handshake completed', True);
          WriteLn('Handshake completed in ', Attempts, ' attempts');
          Break;
        end;
        sslHsInProgress:
        begin
          WriteLn('  Handshake in progress... (attempt ', Attempts, ')');
          if Attempts > 100 then
          begin
            TestResult('SSL handshake completed', False, 'Too many attempts');
            Break;
          end;
        end;
        sslHsFailed:
        begin
          TestResult('SSL handshake completed', False, 'Handshake failed');
          Break;
        end;
      end;
    until (HandshakeState <> sslHsInProgress) or (Attempts > 100);
    
  except
    on E: Exception do
      TestResult('SSL handshake', False, E.Message);
  end;
  PrintSeparator;
end;

procedure Test6_VerifyConnection;
var
  PeerCert: ISSLCertificate;
  VerifyResult: Integer;
  VerifyResultString: string;
begin
  WriteLn('Test 6: Verify SSL Connection');
  try
    if Connection = nil then
    begin
      TestResult('Connection verification', False, 'Connection not initialized');
      Exit;
    end;
    
    // Check if connected
    if Connection.IsConnected then
      TestResult('Connection is established', True)
    else
      TestResult('Connection is established', False);
    
    // Get protocol version
    try
      WriteLn('Protocol version: ', Ord(Connection.GetProtocolVersion));
      TestResult('Get protocol version', True);
    except
      on E: Exception do
        TestResult('Get protocol version', False, E.Message);
    end;
    
    // Get cipher name
    try
      WriteLn('Cipher: ', Connection.GetCipherName);
      TestResult('Get cipher name', True);
    except
      on E: Exception do
        TestResult('Get cipher name', False, E.Message);
    end;
    
    // Get peer certificate
    try
      PeerCert := Connection.GetPeerCertificate;
      if PeerCert <> nil then
      begin
        TestResult('Get peer certificate', True);
        WriteLn('Certificate subject: ', PeerCert.GetSubject);
      end
      else
        TestResult('Get peer certificate', False, 'Certificate is nil');
    except
      on E: Exception do
        TestResult('Get peer certificate', False, E.Message);
    end;
    
    // Get verify result
    try
      GetCertificateVerificationInfo(Connection, VerifyResult, VerifyResultString);
      WriteLn('Verify result: ', VerifyResult);
      if VerifyResult = 0 then
        TestResult('Certificate verification', True)
      else
      begin
        TestResult('Certificate verification', False, 
          'Verify failed: ' + VerifyResultString);
      end;
    except
      on E: Exception do
        TestResult('Certificate verification', False, E.Message);
    end;
    
  except
    on E: Exception do
      TestResult('Connection verification', False, E.Message);
  end;
  PrintSeparator;
end;

procedure Test7_SendData;
var
  BytesWritten: Integer;
begin
  WriteLn('Test 7: Send HTTP Request');
  try
    if Connection = nil then
    begin
      TestResult('Send data', False, 'Connection not initialized');
      Exit;
    end;
    
    if not Connection.IsConnected then
    begin
      TestResult('Send data', False, 'Not connected');
      Exit;
    end;
    
    WriteLn('Sending: ', TEST_REQUEST);
    BytesWritten := Connection.Write(TEST_REQUEST[1], Length(TEST_REQUEST));
    
    if BytesWritten > 0 then
    begin
      TestResult('Send HTTP request', True);
      WriteLn('Sent ', BytesWritten, ' bytes');
    end
    else
      TestResult('Send HTTP request', False, 'No bytes written');
      
  except
    on E: Exception do
      TestResult('Send data', False, E.Message);
  end;
  PrintSeparator;
end;

procedure Test8_ReceiveData;
var
  Buffer: array[0..4095] of Byte;
  BytesRead: Integer;
  Response: string;
begin
  WriteLn('Test 8: Receive HTTP Response');
  try
    if Connection = nil then
    begin
      TestResult('Receive data', False, 'Connection not initialized');
      Exit;
    end;
    
    if not Connection.IsConnected then
    begin
      TestResult('Receive data', False, 'Not connected');
      Exit;
    end;
    
    // Read response
    BytesRead := Connection.Read(Buffer[0], SizeOf(Buffer));
    
    if BytesRead > 0 then
    begin
      TestResult('Receive HTTP response', True);
      WriteLn('Received ', BytesRead, ' bytes');
      
      SetString(Response, PAnsiChar(@Buffer[0]), BytesRead);
      WriteLn('Response preview (first 200 chars):');
      if Length(Response) > 200 then
        WriteLn(Copy(Response, 1, 200), '...')
      else
        WriteLn(Response);
        
      // Check if it looks like HTTP response
      if Pos('HTTP/', Response) > 0 then
        TestResult('Valid HTTP response', True)
      else
        TestResult('Valid HTTP response', False, 'Not HTTP response');
    end
    else
      TestResult('Receive HTTP response', False, 'No data received');
      
  except
    on E: Exception do
      TestResult('Receive data', False, E.Message);
  end;
  PrintSeparator;
end;

procedure Test9_CloseConnection;
begin
  WriteLn('Test 9: Close SSL Connection');
  try
    if Connection <> nil then
    begin
      if Connection.Shutdown then
        TestResult('SSL shutdown', True)
      else
        TestResult('SSL shutdown', False, 'Shutdown returned false');
        
      Connection.Close;
      TestResult('Close connection', True);
      
      if not Connection.IsConnected then
        TestResult('Connection closed', True)
      else
        TestResult('Connection closed', False, 'Still connected');
    end
    else
      TestResult('Close connection', False, 'Connection not initialized');
      
  except
    on E: Exception do
      TestResult('Close connection', False, E.Message);
  end;
  PrintSeparator;
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
    WriteLn('Result: ALL TESTS PASSED!')
  else
    WriteLn('Result: ', TestsFailed, ' test(s) failed');
end;

begin
  WriteLn('========================================');
  WriteLn('SSL Client Connection Integration Test');
  WriteLn('========================================');
  WriteLn('Target: ', TEST_HOST, ':', TEST_PORT);
  WriteLn;
  
  try
    // Run all tests in sequence
    Test1_InitializeLibrary;
    Test2_CreateClientContext;
    Test3_ConnectToHost;
    Test4_CreateSSLConnection;
    Test5_PerformSSLHandshake;
    Test6_VerifyConnection;
    Test7_SendData;
    Test8_ReceiveData;
    Test9_CloseConnection;
    
    // Print summary
    PrintSummary;
    
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('FATAL ERROR: ', E.Message);
      ExitCode := 1;
    end;
  end;
  
  // Cleanup
  if SSLLib <> nil then
    SSLLib.Finalize;
    
  if Stream <> nil then
    Stream.Free;
    
  if Socket <> nil then
    Socket.Free;
  
  // Exit with error code if tests failed
  if TestsFailed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
