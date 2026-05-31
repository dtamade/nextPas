program test_context_cert_loading;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.native_handle;

var
  Factory: ISSLLibrary;
  Context: ISSLContext;
  Store: ISSLCertificateStore;
  NativeHandle: Pointer;
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
  WriteLn('Context Certificate & Private Key Loading Test Suite');
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
    
    // Test 1: Create server context
    WriteLn('Test 1: Create server context');
    Context := Factory.CreateContext(sslCtxServer);
    WriteTestResult('Context created', Context <> nil);
    
    // Test 2: Check context is valid
    WriteLn('Test 2: Check context is valid');
    if Context <> nil then
      WriteTestResult('Context is valid', Context.IsValid);
    
    // Test 3: Get native handle
    WriteLn('Test 3: Get native handle');
    if Context <> nil then
      WriteTestResult('Native handle is not nil',
        TryGetNativeHandle(Context, NativeHandle) and (NativeHandle <> nil));
    
    // Test 4: Certificate store integration
    WriteLn('Test 4: Set certificate store');
    if Context <> nil then
    begin
      Store := Factory.CreateCertificateStore;
      if Store <> nil then
      begin
        Store.LoadSystemStore;  // Load system certificates
        try
          Context.SetCertificateStore(Store);
          WriteTestResult('SetCertificateStore API', True);
        except
          on E: Exception do
          begin
            WriteTestResult('SetCertificateStore API', False);
            WriteLn('  Exception: ', E.Message);
          end;
        end;
      end;
    end;
    
    // Test 5: Protocol versions
    WriteLn('Test 5: Set protocol versions');
    if Context <> nil then
    begin
      try
        Context.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
        WriteTestResult('SetProtocolVersions API', True);
      except
        on E: Exception do
        begin
          WriteTestResult('SetProtocolVersions API', False);
          WriteLn('  Exception: ', E.Message);
        end;
      end;
    end;
    
    // Test 6: Verify mode
    WriteLn('Test 6: Set verify mode');
    if Context <> nil then
    begin
      try
        Context.SetVerifyMode([sslVerifyPeer]);
        Context.SetVerifyDepth(10);
        WriteTestResult('SetVerifyMode/Depth API', True);
      except
        on E: Exception do
        begin
          WriteTestResult('SetVerifyMode/Depth API', False);
          WriteLn('  Exception: ', E.Message);
        end;
      end;
    end;
    
    // Test 7: Cipher configuration
    WriteLn('Test 7: Set cipher list');
    if Context <> nil then
    begin
      try
        Context.SetCipherList('HIGH:!aNULL:!MD5');
        WriteTestResult('SetCipherList API', True);
      except
        on E: Exception do
        begin
          WriteTestResult('SetCipherList API', False);
          WriteLn('  Exception: ', E.Message);
        end;
      end;
    end;
    
    // Test 8: Session settings
    WriteLn('Test 8: Session configuration');
    if Context <> nil then
    begin
      try
        Context.SetSessionCacheMode(True);
        Context.SetSessionTimeout(300);
        WriteTestResult('Session configuration API', True);
      except
        on E: Exception do
        begin
          WriteTestResult('Session configuration API', False);
          WriteLn('  Exception: ', E.Message);
        end;
      end;
    end;
    
    WriteLn;
    WriteLn('NOTE: Certificate/Key file loading tests skipped');
    WriteLn('      (requires actual certificate files)');
    WriteLn;
    WriteLn('To test file loading, you would do:');
    WriteLn('  Context.LoadCertificate(''server.crt'');');
    WriteLn('  Context.LoadPrivateKey(''server.key'', ''password'');');
    WriteLn('  Context.LoadCAFile(''ca-bundle.crt'');');
    WriteLn;
    
    WriteLn('==========================================================');
    WriteLn('Test Summary');
    WriteLn('==========================================================');
    WriteLn('Passed: ', Passed);
    WriteLn('Failed: ', Failed);
    WriteLn('Total:  ', Passed + Failed);
    if Passed + Failed > 0 then
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
