program test_connection_basic;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.factory,
  
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.api.core,
  fafafa.ssl;

var
  LContext: ISSLContext;
  LConnection: ISSLConnection;
  LConfig: TSSLConfig;
  LTestsPassed: Integer = 0;
  LTestsFailed: Integer = 0;

procedure PrintSeparator;
begin
  WriteLn('----------------------------------------');
end;

procedure TestPassed(const ATestName: string);
begin
  WriteLn('[PASS] ', ATestName);
  Inc(LTestsPassed);
end;

procedure TestFailed(const ATestName, AReason: string);
begin
  WriteLn('[FAIL] ', ATestName, ': ', AReason);
  Inc(LTestsFailed);
end;

procedure Test1_FactoryCreation;
begin
  WriteLn('Test 1: Factory Creation');
  try
    // TSSLFactory is a class with class methods - no instance needed
    if TSSLFactory.GetAvailableLibraries <> [] then
      TestPassed('Factory creation (TSSLFactory available)')
    else
      TestFailed('Factory creation', 'No SSL libraries available');
  except
    on E: Exception do
      TestFailed('Factory creation', E.Message);
  end;
  PrintSeparator;
end;

procedure Test2_ContextCreation;
var
  LLib: ISSLLibrary;
  LErr: string;
begin
  WriteLn('Test 2: Context Creation');
  try
    // TSSLFactory is a class - no instance initialization needed

    LConfig := CreateDefaultConfig(sslCtxClient);
    LConfig.LibraryType := sslOpenSSL;
    LConfig.ProtocolVersions := [sslProtocolTLS12, sslProtocolTLS13];
    LConfig.VerifyMode := [sslVerifyNone]; // No verification for basic test
    
    LContext := TSSLFactory.CreateContext(LConfig);
    if LContext <> nil then
    begin
      if LContext.IsValid then
        TestPassed('Context creation and validation')
      else
        TestFailed('Context creation', 'Context is invalid');
    end
    else
    begin
      // Try to obtain more diagnostics from the library
      LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
      if LLib <> nil then
        LErr := LLib.GetLastErrorString
      else
        LErr := '';
      if LErr <> '' then
        TestFailed('Context creation', 'Context is nil; LastError=' + LErr)
      else
        TestFailed('Context creation', 'Context is nil');
    end;
  except
    on E: Exception do
      TestFailed('Context creation', E.Message);
  end;
  PrintSeparator;
end;

procedure Test3_ConnectionCreation;
var
  LStream: TMemoryStream;
begin
  WriteLn('Test 3: Connection Creation');
  try
    if LContext = nil then
    begin
      TestFailed('Connection creation', 'Context not initialized');
      Exit;
    end;
    
    // Create a memory stream for the connection
    LStream := TMemoryStream.Create;
    try
      LConnection := LContext.CreateConnection(LStream);
      if LConnection <> nil then
        TestPassed('Connection creation')
      else
        TestFailed('Connection creation', 'Connection is nil');
    finally
      // Don't free stream - it's owned by the connection
      // LStream.Free;
    end;
  except
    on E: Exception do
      TestFailed('Connection creation', E.Message);
  end;
  PrintSeparator;
end;

procedure Test4_ConnectionProperties;
var
  LNativeHandleAccess: ISSLNativeHandleAccess;
begin
  WriteLn('Test 4: Connection Properties');
  try
    if LConnection = nil then
    begin
      TestFailed('Connection properties', 'Connection not initialized');
      Exit;
    end;
    
    // Test IsConnected before any connection attempt
    if not LConnection.IsConnected then
      TestPassed('IsConnected returns False before connection')
    else
      TestFailed('IsConnected', 'Should be False before connection');
      
    // Test GetNativeHandle
    if Supports(LConnection, ISSLNativeHandleAccess, LNativeHandleAccess) then
    begin
      if LNativeHandleAccess.GetNativeHandle <> nil then
        TestPassed('GetNativeHandle returns non-nil')
      else
        TestFailed('GetNativeHandle', 'Should not be nil after creation');
    end
    else
      TestFailed('GetNativeHandle', 'Connection does not expose ISSLNativeHandleAccess');
      
  except
    on E: Exception do
      TestFailed('Connection properties', E.Message);
  end;
  PrintSeparator;
end;

procedure Test5_ConnectionState;
var
  LConnInfo: ISSLConnectionInfo;
begin
  WriteLn('Test 5: Connection State');
  try
    if LConnection = nil then
    begin
      TestFailed('Connection state', 'Connection not initialized');
      Exit;
    end;
    
    // Get state string
    try
      WriteLn('  State: ', LConnection.GetState);
      TestPassed('GetState method works');
    except
      on E: Exception do
        TestFailed('GetState', E.Message);
    end;
    
    // Get state string long
    try
      if Supports(LConnection, ISSLConnectionInfo, LConnInfo) then
      begin
        WriteLn('  State (long): ', LConnInfo.GetStateString);
        TestPassed('GetStateString method works');
      end
      else
        TestFailed('GetStateString', 'Connection does not expose ISSLConnectionInfo');
    except
      on E: Exception do
        TestFailed('GetStateString', E.Message);
    end;
      
  except
    on E: Exception do
      TestFailed('Connection state', E.Message);
  end;
  PrintSeparator;
end;

procedure Test6_ProtocolVersion;
begin
  WriteLn('Test 6: Protocol Version');
  try
    if LConnection = nil then
    begin
      TestFailed('Protocol version', 'Connection not initialized');
      Exit;
    end;
    
    // Get protocol version (should return default even if not connected)
    try
      WriteLn('  Protocol: ', Ord(LConnection.GetProtocolVersion));
      TestPassed('GetProtocolVersion method works');
    except
      on E: Exception do
        TestFailed('GetProtocolVersion', E.Message);
    end;
      
  except
    on E: Exception do
      TestFailed('Protocol version', E.Message);
  end;
  PrintSeparator;
end;

procedure Test7_ErrorHandling;
begin
  WriteLn('Test 7: Error Handling');
  try
    if LConnection = nil then
    begin
      TestFailed('Error handling', 'Connection not initialized');
      Exit;
    end;
    
    // Test GetError with zero (no error)
    try
      if LConnection.GetError(0) = sslErrNone then
        TestPassed('GetError returns sslErrNone for success')
      else
        TestFailed('GetError', 'Should return sslErrNone for 0');
    except
      on E: Exception do
        TestFailed('GetError', E.Message);
    end;
    
    // Test WantRead/WantWrite (should be false when not connected)
    try
      if not LConnection.WantRead then
        TestPassed('WantRead returns False when not connected')
      else
        TestFailed('WantRead', 'Should be False when not connected');
    except
      on E: Exception do
        TestFailed('WantRead', E.Message);
    end;
    
    try
      if not LConnection.WantWrite then
        TestPassed('WantWrite returns False when not connected')
      else
        TestFailed('WantWrite', 'Should be False when not connected');
    except
      on E: Exception do
        TestFailed('WantWrite', E.Message);
    end;
      
  except
    on E: Exception do
      TestFailed('Error handling', E.Message);
  end;
  PrintSeparator;
end;

procedure PrintSummary;
var
  LTotal: Integer;
  LPassRate: Double;
begin
  WriteLn;
  WriteLn('========================================');
  WriteLn('TEST SUMMARY');
  WriteLn('========================================');
  
  LTotal := LTestsPassed + LTestsFailed;
  if LTotal > 0 then
    LPassRate := (LTestsPassed / LTotal) * 100
  else
    LPassRate := 0;
    
  WriteLn('Total tests: ', LTotal);
  WriteLn('Passed: ', LTestsPassed);
  WriteLn('Failed: ', LTestsFailed);
  WriteLn('Pass rate: ', LPassRate:0:1, '%');
  WriteLn('========================================');
  
  if LTestsFailed = 0 then
    WriteLn('Result: ALL TESTS PASSED!')
  else
    WriteLn('Result: SOME TESTS FAILED');
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL Connection Basic Tests');
  WriteLn('========================================');
  WriteLn;
  
  try
    // Load OpenSSL
    WriteLn('Loading OpenSSL...');
    try
      LoadOpenSSLCore;
      WriteLn('OpenSSL loaded: ', GetOpenSSLVersionString);
      WriteLn;
    except
      on E: Exception do
      begin
        WriteLn('ERROR: Failed to load OpenSSL: ', E.Message);
        Halt(1);
      end;
    end;
    
    // Run tests
    Test1_FactoryCreation;
    Test2_ContextCreation;
    Test3_ConnectionCreation;
    Test4_ConnectionProperties;
    Test5_ConnectionState;
    Test6_ProtocolVersion;
    Test7_ErrorHandling;
    
    // Print summary
    PrintSummary;
    
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('FATAL ERROR: ', E.Message);
      Halt(1);
    end;
  end;
  
  // Exit with error code if tests failed
  if LTestsFailed > 0 then
    Halt(1);
end.
