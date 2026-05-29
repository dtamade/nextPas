program test_openssl_simple;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.core;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  SSLMethod, SSLMethod2: PSSL_METHOD;
  SSLCtx, SSLCtx2: PSSL_CTX;
  SSL: PSSL;

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

begin
  WriteLn('========================================');
  WriteLn('OpenSSL API Basic Tests');
  WriteLn('========================================');
  WriteLn;
  
  try
    // Test 1: Load OpenSSL
    WriteLn('Test 1: Loading OpenSSL...');
    try
      LoadOpenSSLCore;
      TestResult('OpenSSL library loaded', True);
      WriteLn('Version: ', GetOpenSSLVersionString);
    except
      on E: Exception do
      begin
        TestResult('OpenSSL library loaded', False, E.Message);
        WriteLn;
        WriteLn('FATAL: Cannot continue without OpenSSL');
        Halt(1);
      end;
    end;
    WriteLn;
    
    // Test 2: Check critical function pointers
    WriteLn('Test 2: Checking API function pointers...');
    TestResult('TLS_method', Assigned(TLS_method));
    TestResult('SSL_CTX_new', Assigned(SSL_CTX_new));
    TestResult('SSL_new', Assigned(SSL_new));
    TestResult('SSL_connect', Assigned(SSL_connect));
    TestResult('SSL_accept', Assigned(SSL_accept));
    TestResult('SSL_read', Assigned(SSL_read));
    TestResult('SSL_write', Assigned(SSL_write));
    TestResult('SSL_shutdown', Assigned(SSL_shutdown));
    TestResult('SSL_free', Assigned(SSL_free));
    TestResult('SSL_CTX_free', Assigned(SSL_CTX_free));
    WriteLn;
    
    // Test 3: Check newly added functions
    WriteLn('Test 3: Checking newly added API functions...');
    TestResult('SSL_set_connect_state', Assigned(SSL_set_connect_state));
    TestResult('SSL_set_accept_state', Assigned(SSL_set_accept_state));
    TestResult('SSL_get_peer_certificate', Assigned(SSL_get_peer_certificate));
    TestResult('SSL_get_peer_cert_chain', Assigned(SSL_get_peer_cert_chain));
    TestResult('SSL_get0_verified_chain', Assigned(SSL_get0_verified_chain));
    TestResult('SSL_get_verify_result', Assigned(SSL_get_verify_result));
    TestResult('SSL_session_reused', Assigned(SSL_session_reused));
    WriteLn;
    
    // Test 4: Creating SSL context...
    WriteLn('Test 4: Creating SSL context...');
    SSLMethod := TLS_method();
      TestResult('TLS_method() returned non-nil', SSLMethod <> nil);
      
      if SSLMethod <> nil then
      begin
        SSLCtx := SSL_CTX_new(SSLMethod);
        TestResult('SSL_CTX_new() returned non-nil', SSLCtx <> nil);
        
        if SSLCtx <> nil then
        begin
          SSL_CTX_free(SSLCtx);
          TestResult('SSL_CTX_free() succeeded', True);
        end;
      end;
    WriteLn;
    
    // Test 5: Create SSL object
    WriteLn('Test 5: Creating SSL object...');
    SSLMethod2 := TLS_method();
      if SSLMethod2 <> nil then
      begin
        SSLCtx2 := SSL_CTX_new(SSLMethod2);
        if SSLCtx2 <> nil then
        begin
          SSL := SSL_new(SSLCtx2);
          TestResult('SSL_new() returned non-nil', SSL <> nil);
          
          if SSL <> nil then
          begin
            // Test state functions
            SSL_set_connect_state(SSL);
            TestResult('SSL_set_connect_state() succeeded', True);
            
            SSL_free(SSL);
            TestResult('SSL_free() succeeded', True);
          end;
          
          SSL_CTX_free(SSLCtx2);
        end;
      end;
    WriteLn;
    
    // Print summary
    WriteLn('========================================');
    WriteLn('TEST SUMMARY');
    WriteLn('========================================');
    WriteLn('Total tests: ', TestsPassed + TestsFailed);
    WriteLn('Passed: ', TestsPassed);
    WriteLn('Failed: ', TestsFailed);
    
    if TestsFailed = 0 then
    begin
      WriteLn;
      WriteLn('Result: ALL TESTS PASSED!');
      ExitCode := 0;
    end
    else
    begin
      WriteLn;
      WriteLn('Result: SOME TESTS FAILED');
      ExitCode := 1;
    end;
    
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('FATAL ERROR: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
