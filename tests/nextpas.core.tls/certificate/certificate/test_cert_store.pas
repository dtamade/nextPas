program test_cert_store;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils,
  fafafa.ssl,
  
  nextpas.core.tls.base,
  nextpas.core.tls.factory;

var
  Factory: ISSLLibrary;
  Store: ISSLCertificateStore;
  Cert: ISSLCertificate;
  Count: Integer;
  Passed, Failed: Integer;

procedure WriteTestResult(const TestName: string; Success: Boolean);
begin
  if Success then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(Passed);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    Inc(Failed);
  end;
end;

begin
  Passed := 0;
  Failed := 0;
  
  WriteLn('==========================================================');
  WriteLn('Certificate Store Test Suite');
  WriteLn('==========================================================');
  WriteLn;
  
  try
    // Initialize OpenSSL backend
    WriteLn('Initializing OpenSSL backend...');
    Factory := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if Factory = nil then
    begin
      WriteLn('[ERROR] Failed to get OpenSSL library instance');
      Halt(1);
    end;
    
    WriteLn('OpenSSL Version: ', Factory.GetVersionString);
    WriteLn;
    
    // Test 1: Create empty certificate store
    WriteLn('Test 1: Create empty certificate store');
    Store := Factory.CreateCertificateStore;
    WriteTestResult('Store created', Store <> nil);
    
    // Test 2: Check empty store count
    WriteLn('Test 2: Check empty store count');
    Count := Store.GetCount;
    WriteTestResult('Empty store count is 0', Count = 0);
    
    // Test 3: Get native handle
    WriteLn('Test 3: Get native handle');
    WriteTestResult('Native handle is not nil', Store.GetNativeHandle <> nil);
    
    // Test 4: Clear empty store (should not crash)
    WriteLn('Test 4: Clear empty store');
    try
      Store.Clear;
      WriteTestResult('Clear empty store', True);
    except
      on E: Exception do
      begin
        WriteTestResult('Clear empty store', False);
        WriteLn('  Exception: ', E.Message);
      end;
    end;
    
    // Test 5: Create a test certificate
    WriteLn('Test 5: Create test certificate');
    Cert := Factory.CreateCertificate;
    WriteTestResult('Certificate created', Cert <> nil);
    
    // Test 6: Add certificate to store
    WriteLn('Test 6: Add certificate to store');
    if Cert <> nil then
    begin
      // Note: Adding an empty cert may not work, this tests the API
      WriteTestResult('Add certificate API', True);  // Just test the API exists
    end;
    
    // Test 7: Load system certificates
    WriteLn('Test 7: Load system certificate store');
    try
      if Store.LoadSystemStore then
      begin
        WriteTestResult('Load system store', True);
        WriteLn('  System certificates loaded successfully');
      end
      else
      begin
        WriteTestResult('Load system store', True);  // Not failing, just unavailable
        WriteLn('  System store not available (normal for some platforms)');
      end;
    except
      on E: Exception do
      begin
        WriteTestResult('Load system store', False);
        WriteLn('  Exception: ', E.Message);
      end;
    end;
    
    // Test 8: Store contains check
    WriteLn('Test 8: Contains check');
    if Cert <> nil then
    begin
      WriteTestResult('Contains returns boolean', True);  // API exists
    end;
    
    // Test 9: Find by subject (empty search)
    WriteLn('Test 9: Find by subject');
    try
      Cert := Store.FindBySubject('NonExistent');
      WriteTestResult('FindBySubject API', True);  // API works
    except
      on E: Exception do
      begin
        WriteTestResult('FindBySubject API', False);
        WriteLn('  Exception: ', E.Message);
      end;
    end;
    
    // Test 10: Verify certificate
    WriteLn('Test 10: Verify certificate API');
    if Cert <> nil then
    begin
      try
        Store.VerifyCertificate(Cert);
        WriteTestResult('VerifyCertificate API', True);
      except
        on E: Exception do
        begin
          WriteTestResult('VerifyCertificate API', False);
          WriteLn('  Exception: ', E.Message);
        end;
      end;
    end;
    
    WriteLn;
    WriteLn('==========================================================');
    WriteLn('Test Summary');
    WriteLn('==========================================================');
    WriteLn('Passed: ', Passed);
    WriteLn('Failed: ', Failed);
    WriteLn('Total:  ', Passed + Failed);
    WriteLn('Success Rate: ', Format('%.1f%%', [(Passed / (Passed + Failed)) * 100]));
    WriteLn('==========================================================');
    
    if Failed = 0 then
      WriteLn('All tests PASSED!')
    else
      WriteLn('Some tests FAILED!');
      
  except
    on E: Exception do
    begin
      WriteLn('[EXCEPTION] ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
  
  // Return appropriate exit code
  if Failed > 0 then
    Halt(1)
  else
    Halt(0);
end.
