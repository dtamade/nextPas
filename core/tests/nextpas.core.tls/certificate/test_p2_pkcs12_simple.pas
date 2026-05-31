program test_p2_pkcs12_simple;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.base;

type
  PPKCS12 = ^PKCS12;
  PKCS12 = record
    // Opaque structure
  end;

  TPKCS12_new = function(): PPKCS12; cdecl;
  TPKCS12_free = procedure(p12: PPKCS12); cdecl;

var
  PKCS12_new: TPKCS12_new = nil;
  PKCS12_free: TPKCS12_free = nil;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;

procedure StartTest(const TestName: string);
begin
  Inc(TotalTests);
  Write('[', TotalTests, '] ', TestName, '... ');
end;

procedure PassTest;
begin
  Inc(PassedTests);
  WriteLn('PASS');
end;

procedure FailTest(const Reason: string);
begin
  Inc(FailedTests);
  WriteLn('FAIL: ', Reason);
end;

procedure LoadPKCS12Functions;
var
  CryptoHandle: THandle;
begin
  CryptoHandle := GetCryptoLibHandle;
  if CryptoHandle = 0 then Exit;
  
  PKCS12_new := TPKCS12_new(GetProcAddress(CryptoHandle, 'PKCS12_new'));
  PKCS12_free := TPKCS12_free(GetProcAddress(CryptoHandle, 'PKCS12_free'));
end;

procedure TestPKCS12FunctionsAvailable;
begin
  StartTest('PKCS12 core functions available');
  try
    LoadPKCS12Functions;
    if Assigned(PKCS12_new) and Assigned(PKCS12_free) then
      PassTest
    else
      FailTest('Functions not loaded');
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestPKCS12ObjectLifecycle;
var
  P12: PPKCS12;
begin
  StartTest('PKCS12 object lifecycle');
  P12 := nil;
  try
    if not Assigned(PKCS12_new) or not Assigned(PKCS12_free) then
    begin
      FailTest('Functions not loaded');
      Exit;
    end;
    
    P12 := PKCS12_new();
    if P12 = nil then
      FailTest('PKCS12_new returned nil')
    else
    begin
      PassTest;
      PKCS12_free(P12);
      P12 := nil;
    end;
  except
    on E: Exception do
    begin
      FailTest('Exception: ' + E.Message);
      if (P12 <> nil) and Assigned(PKCS12_free) then
        PKCS12_free(P12);
    end;
  end;
end;

procedure PrintSummary;
begin
  WriteLn;
  WriteLn('============================================');
  WriteLn('Test Summary');
  WriteLn('============================================');
  WriteLn('Total Tests:  ', TotalTests);
  WriteLn('Passed:       ', PassedTests, ' (', Format('%.1f', [PassedTests * 100.0 / TotalTests]), '%)');
  WriteLn('Failed:       ', FailedTests, ' (', Format('%.1f', [FailedTests * 100.0 / TotalTests]), '%)');
  WriteLn('============================================');
  
  if FailedTests = 0 then
    WriteLn('All tests PASSED!')
  else
    WriteLn('Some tests FAILED!');
end;

begin
  WriteLn('============================================');
  WriteLn('P2 PKCS12 Module Simple Test Suite');
  WriteLn('Testing basic OpenSSL PKCS#12 functionality');
  WriteLn('============================================');
  WriteLn;
  
  try
    LoadOpenSSLCore;
    LoadOpenSSLBIO;
    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);
    WriteLn;
    
    TestPKCS12FunctionsAvailable;
    TestPKCS12ObjectLifecycle;
    
    PrintSummary;
    
    if FailedTests > 0 then
      Halt(1)
    else
      Halt(0);
      
  except
    on E: Exception do
    begin
      WriteLn('FATAL ERROR: ', E.Message);
      Halt(2);
    end;
  end;
end.
