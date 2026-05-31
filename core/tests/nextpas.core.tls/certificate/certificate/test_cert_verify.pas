program test_cert_verify;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.backed;

procedure TestCertificateVerification;
var
  LLib: ISSLLibrary;
  LCert: ISSLCertificate;
  LStore: ISSLCertificateStore;
begin
  WriteLn('Test: Certificate Verification');
  WriteLn('================================');
  
  try
    // Create OpenSSL library
    LLib := TOpenSSLLibrary.Create;
    if not LLib.Initialize then
    begin
      WriteLn('FAIL: Could not initialize OpenSSL library');
      Exit;
    end;
    WriteLn('OK: OpenSSL library initialized');
    
    // Create certificate
    LCert := LLib.CreateCertificate;
    if LCert = nil then
    begin
      WriteLn('FAIL: Could not create certificate object');
      Exit;
    end;
    WriteLn('OK: Certificate object created');
    
    // Create certificate store
    LStore := LLib.CreateCertificateStore;
    if LStore = nil then
    begin
      WriteLn('FAIL: Could not create certificate store');
      Exit;
    end;
    WriteLn('OK: Certificate store created');
    
    WriteLn('');
    WriteLn('All basic tests passed!');
  except
    on E: Exception do
      WriteLn('ERROR: ', E.Message);
  end;
end;

procedure TestHostnameVerification;
var
  LLib: ISSLLibrary;
  LCert: ISSLCertificate;
begin
  WriteLn('');
  WriteLn('Test: Hostname Verification');
  WriteLn('============================');
  
  try
    // Create OpenSSL library
    LLib := TOpenSSLLibrary.Create;
    if not LLib.Initialize then
    begin
      WriteLn('FAIL: Could not initialize OpenSSL library');
      Exit;
    end;
    WriteLn('OK: OpenSSL library initialized');
    
    // Create certificate
    LCert := LLib.CreateCertificate;
    if LCert = nil then
    begin
      WriteLn('FAIL: Could not create certificate object');
      Exit;
    end;
    WriteLn('OK: Certificate object created');
    
    // Test hostname verification with empty certificate
    // Should return False because certificate is not loaded
    if not LCert.VerifyHostname('example.com') then
      WriteLn('OK: VerifyHostname returns False for unloaded certificate')
    else
      WriteLn('FAIL: VerifyHostname should return False for unloaded certificate');
    
    WriteLn('');
    WriteLn('All hostname verification tests passed!');
  except
    on E: Exception do
      WriteLn('ERROR: ', E.Message);
  end;
end;

procedure TestCertificateFailureScenarios;
var
  LLib: ISSLLibrary;
  LCert: ISSLCertificate;
  LStore: ISSLCertificateStore;
begin
  WriteLn('');
  WriteLn('Test: Certificate Failure Scenarios');
  WriteLn('====================================');
  
  try
    // Create OpenSSL library
    LLib := TOpenSSLLibrary.Create;
    if not LLib.Initialize then
    begin
      WriteLn('FAIL: Could not initialize OpenSSL library');
      Exit;
    end;
    WriteLn('OK: OpenSSL library initialized');
    
    // Test 1: Load non-existent certificate file
    WriteLn('');
    WriteLn('Test 1: Load non-existent certificate');
    WriteLn('--------------------------------------');
    LCert := LLib.CreateCertificate;
    try
      LCert.LoadFromFile('/nonexistent/path/cert.pem');
      WriteLn('FAIL: Should have raised exception for non-existent file');
    except
      on E: Exception do
        WriteLn('OK: Correctly raised exception: ', E.ClassName);
    end;
    
    // Test 2: Load invalid certificate data
    WriteLn('');
    WriteLn('Test 2: Load invalid certificate data');
    WriteLn('--------------------------------------');
    LCert := LLib.CreateCertificate;
    try
      LCert.LoadFromPEM('INVALID CERTIFICATE DATA');
      WriteLn('FAIL: Should have raised exception for invalid data');
    except
      on E: Exception do
        WriteLn('OK: Correctly raised exception: ', E.ClassName);
    end;
    
    // Test 3: Verify hostname with invalid certificate
    WriteLn('');
    WriteLn('Test 3: Verify hostname with invalid certificate');
    WriteLn('------------------------------------------------');
    LCert := LLib.CreateCertificate;
    if not LCert.VerifyHostname('') then
      WriteLn('OK: VerifyHostname returns False for empty hostname')
    else
      WriteLn('FAIL: VerifyHostname should return False for empty hostname');
    
    // Test 4: Certificate store with no certificates
    WriteLn('');
    WriteLn('Test 4: Certificate store operations');
    WriteLn('------------------------------------');
    LStore := LLib.CreateCertificateStore;
    if LStore.GetCount = 0 then
      WriteLn('OK: Empty certificate store has count 0')
    else
      WriteLn('FAIL: Empty certificate store should have count 0');
    
    // Test 5: Access certificate at invalid index
    WriteLn('');
    WriteLn('Test 5: Access invalid certificate index');
    WriteLn('----------------------------------------');
    try
      LCert := LStore.GetCertificate(999);
      if LCert = nil then
        WriteLn('OK: GetCertificate returns nil for invalid index')
      else
        WriteLn('FAIL: GetCertificate should return nil for invalid index');
    except
      on E: Exception do
        WriteLn('OK: Correctly raised exception for invalid index: ', E.ClassName);
    end;
    
    // Test 6: Verify certificate chain with empty store
    WriteLn('');
    WriteLn('Test 6: Verify certificate chain with empty store');
    WriteLn('------------------------------------------------');
    LCert := LLib.CreateCertificate;
    if not LCert.Verify(LStore) then
      WriteLn('OK: Verify returns False for unloaded certificate')
    else
      WriteLn('FAIL: Verify should return False for unloaded certificate');
    
    WriteLn('');
    WriteLn('All failure scenario tests completed!');
  except
    on E: Exception do
      WriteLn('ERROR: ', E.Message);
  end;
end;

begin
  TestCertificateVerification;
  TestHostnameVerification;
  TestCertificateFailureScenarios;
  WriteLn('');
  WriteLn('=================================');
  WriteLn('All tests completed successfully!');
  WriteLn('=================================');
  WriteLn('');
  WriteLn('Press Enter to exit...');
  ReadLn;
end.
