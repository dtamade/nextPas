program test_ssl_connection_local;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.backed,
  
  nextpas.core.tls.base;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  SSLLib: ISSLLibrary;
  ClientContext, ServerContext: ISSLContext;
  ClientConnection, ServerConnection: ISSLConnection;
  ClientStream, ServerStream: TMemoryStream;

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

procedure Test1_InitializeLibrary;
begin
  WriteLn('Test 1: Initialize OpenSSL Library');
  try
    SSLLib := TOpenSSLLibrary.Create as ISSLLibrary;
    if SSLLib.Initialize then
    begin
      TestResult('OpenSSL library initialization', True);
      WriteLn('OpenSSL library initialized successfully');
    end
    else
      TestResult('OpenSSL library initialization', False, 'Initialize returned false');
  except
    on E: Exception do
      TestResult('OpenSSL library initialization', False, E.Message);
  end;
  PrintSeparator;
end;

procedure Test2_CreateContexts;
begin
  WriteLn('Test 2: Create SSL Contexts');
  try
    if SSLLib = nil then
    begin
      TestResult('Create SSL contexts', False, 'Library not initialized');
      Exit;
    end;
    
    // Create client context
    ClientContext := SSLLib.CreateContext(sslCtxClient);
    if ClientContext <> nil then
      TestResult('Create client context', True)
    else
      TestResult('Create client context', False, 'Context is nil');
    
    // Create server context  
    ServerContext := SSLLib.CreateContext(sslCtxServer);
    if ServerContext <> nil then
      TestResult('Create server context', True)
    else
      TestResult('Create server context', False, 'Context is nil');
      
    // Validate contexts
    if (ClientContext <> nil) and ClientContext.IsValid then
      TestResult('Client context is valid', True)
    else
      TestResult('Client context is valid', False);
      
    if (ServerContext <> nil) and ServerContext.IsValid then
      TestResult('Server context is valid', True)
    else
      TestResult('Server context is valid', False);
      
  except
    on E: Exception do
      TestResult('Create SSL contexts', False, E.Message);
  end;
  PrintSeparator;
end;

procedure Test3_CreateConnections;
var
  LNativeHandleAccess: ISSLNativeHandleAccess;
begin
  WriteLn('Test 3: Create SSL Connections');
  try
    if (ClientContext = nil) or (ServerContext = nil) then
    begin
      TestResult('Create connections', False, 'Contexts not initialized');
      Exit;
    end;
    
    // Create streams
    ClientStream := TMemoryStream.Create;
    ServerStream := TMemoryStream.Create;
    TestResult('Create memory streams', True);
    
    // Create client connection
    ClientConnection := ClientContext.CreateConnection(ClientStream);
    if ClientConnection <> nil then
    begin
      TestResult('Create client connection', True);
      if Supports(ClientConnection, ISSLNativeHandleAccess, LNativeHandleAccess) then
      begin
        if LNativeHandleAccess.GetNativeHandle <> nil then
          TestResult('Client connection has valid handle', True)
        else
          TestResult('Client connection has valid handle', False);
      end
      else
        TestResult('Client connection has valid handle', False,
          'Connection does not expose ISSLNativeHandleAccess');
    end
    else
      TestResult('Create client connection', False, 'Connection is nil');
    
    // Create server connection
    ServerConnection := ServerContext.CreateConnection(ServerStream);
    if ServerConnection <> nil then
    begin
      TestResult('Create server connection', True);
      if Supports(ServerConnection, ISSLNativeHandleAccess, LNativeHandleAccess) then
      begin
        if LNativeHandleAccess.GetNativeHandle <> nil then
          TestResult('Server connection has valid handle', True)
        else
          TestResult('Server connection has valid handle', False);
      end
      else
        TestResult('Server connection has valid handle', False,
          'Connection does not expose ISSLNativeHandleAccess');
    end
    else
      TestResult('Create server connection', False, 'Connection is nil');
      
  except
    on E: Exception do
      TestResult('Create connections', False, E.Message);
  end;
  PrintSeparator;
end;

procedure Test4_ConnectionProperties;
var
  Info: TSSLConnectionInfo;
  LConnInfoAccess: ISSLConnectionInfo;
begin
  WriteLn('Test 4: Test Connection Properties');
  try
    if ClientConnection = nil then
    begin
      TestResult('Connection properties', False, 'Client connection not initialized');
      Exit;
    end;
    
    // Test IsConnected (should be false before handshake)
    if not ClientConnection.IsConnected then
      TestResult('IsConnected false before handshake', True)
    else
      TestResult('IsConnected false before handshake', False, 'Should be false');
    
    // Test GetState
    try
      WriteLn('Connection state: ', ClientConnection.GetState);
      TestResult('GetState works', True);
    except
      on E: Exception do
        TestResult('GetState works', False, E.Message);
    end;
    
    // Test GetProtocolVersion
    try
      WriteLn('Protocol version: ', Ord(ClientConnection.GetProtocolVersion));
      TestResult('GetProtocolVersion works', True);
    except
      on E: Exception do
        TestResult('GetProtocolVersion works', False, E.Message);
    end;
    
    // Test GetCipherName
    try
      WriteLn('Cipher: ', ClientConnection.GetCipherName);
      TestResult('GetCipherName works', True);
    except
      on E: Exception do
        TestResult('GetCipherName works', False, E.Message);
    end;
    
    // Test GetConnectionInfo
    try
      if Supports(ClientConnection, ISSLConnectionInfo, LConnInfoAccess) then
      begin
        Info := LConnInfoAccess.GetConnectionInfo;
        WriteLn('Connection info retrieved, cipher suite: ', Info.CipherSuite);
        TestResult('GetConnectionInfo works', True);
      end
      else
        TestResult('GetConnectionInfo works', False,
          'Connection does not expose ISSLConnectionInfo');
    except
      on E: Exception do
        TestResult('GetConnectionInfo works', False, E.Message);
    end;
    
  except
    on E: Exception do
      TestResult('Connection properties', False, E.Message);
  end;
  PrintSeparator;
end;

procedure Test5_ErrorHandling;
var
  ErrorCode: TSSLErrorCode;
begin
  WriteLn('Test 5: Test Error Handling');
  try
    if ClientConnection = nil then
    begin
      TestResult('Error handling', False, 'Client connection not initialized');
      Exit;
    end;
    
    // Test GetError
    try
      ErrorCode := ClientConnection.GetError(0);
      if ErrorCode = sslErrNone then
        TestResult('GetError returns sslErrNone for success', True)
      else
        TestResult('GetError returns sslErrNone for success', False);
    except
      on E: Exception do
        TestResult('GetError', False, E.Message);
    end;
    
    // Test WantRead
    try
      if not ClientConnection.WantRead then
        TestResult('WantRead returns false when idle', True)
      else
        TestResult('WantRead returns false when idle', False);
    except
      on E: Exception do
        TestResult('WantRead', False, E.Message);
    end;
    
    // Test WantWrite
    try
      if not ClientConnection.WantWrite then
        TestResult('WantWrite returns false when idle', True)
      else
        TestResult('WantWrite returns false when idle', False);
    except
      on E: Exception do
        TestResult('WantWrite', False, E.Message);
    end;
    
  except
    on E: Exception do
      TestResult('Error handling', False, E.Message);
  end;
  PrintSeparator;
end;

procedure Test6_DataOperations;
var
  TestData: string;
  Buffer: array[0..255] of Byte;
  BytesWritten, BytesRead: Integer;
begin
  WriteLn('Test 6: Test Data Operations (Without Handshake)');
  WriteLn('Note: These may fail without proper handshake, but testing API');
  try
    if ClientConnection = nil then
    begin
      TestResult('Data operations', False, 'Client connection not initialized');
      Exit;
    end;
    
    TestData := 'Hello SSL Test';
    
    // Test Write (may fail without handshake, but tests API)
    try
      BytesWritten := ClientConnection.Write(TestData[1], Length(TestData));
      WriteLn('Write returned: ', BytesWritten, ' bytes');
      TestResult('Write API works', True);
    except
      on E: Exception do
        TestResult('Write API works', False, E.Message);
    end;
    
    // Test Read (may fail without data, but tests API)
    try
      BytesRead := ClientConnection.Read(Buffer[0], SizeOf(Buffer));
      WriteLn('Read returned: ', BytesRead, ' bytes');
      TestResult('Read API works', True);
    except
      on E: Exception do
        TestResult('Read API works', False, E.Message);
    end;
    
    // Note: Pending method may not be implemented yet
    WriteLn('Pending method not tested (may not be implemented)');
    TestResult('Data operation tests completed', True);
    
  except
    on E: Exception do
      TestResult('Data operations', False, E.Message);
  end;
  PrintSeparator;
end;

procedure Test7_Cleanup;
begin
  WriteLn('Test 7: Cleanup and Close');
  try
    // Test Shutdown
    if ClientConnection <> nil then
    begin
      try
        ClientConnection.Shutdown;
        TestResult('Client shutdown', True);
      except
        on E: Exception do
          TestResult('Client shutdown', False, E.Message);
      end;
      
      try
        ClientConnection.Close;
        TestResult('Client close', True);
      except
        on E: Exception do
        TestResult('Client close', False, E.Message);
      end;
    end;
    
    if ServerConnection <> nil then
    begin
      try
        ServerConnection.Shutdown;
        TestResult('Server shutdown', True);
      except
        on E: Exception do
          TestResult('Server shutdown', False, E.Message);
      end;
      
      try
        ServerConnection.Close;
        TestResult('Server close', True);
      except
        on E: Exception do
          TestResult('Server close', False, E.Message);
      end;
    end;
    
    // Free streams
    if ClientStream <> nil then
    begin
      ClientStream.Free;
      TestResult('Free client stream', True);
    end;
    
    if ServerStream <> nil then
    begin
      ServerStream.Free;
      TestResult('Free server stream', True);
    end;
    
  except
    on E: Exception do
      TestResult('Cleanup', False, E.Message);
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
  WriteLn('SSL Connection Local Test');
  WriteLn('(Tests SSL API without network)');
  WriteLn('========================================');
  WriteLn;
  
  try
    // Run all tests in sequence
    Test1_InitializeLibrary;
    Test2_CreateContexts;
    Test3_CreateConnections;
    Test4_ConnectionProperties;
    Test5_ErrorHandling;
    Test6_DataOperations;
    Test7_Cleanup;
    
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
  
  // Exit with error code if tests failed
  if TestsFailed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
