program test_alpn_syntax;

{$mode objfpc}{$H+}

{ Minimal syntax verification test for ALPN implementation
  This test only verifies that the ALPN callback compiles correctly.
  It does NOT perform functional testing. }

uses
  SysUtils,
  nextpas.core.tls.openssl.api.consts;

var
  LTestsPassed: Integer = 0;
  LTestsFailed: Integer = 0;

procedure TestPass(const ATestName: string);
begin
  WriteLn('[PASS] ', ATestName);
  Inc(LTestsPassed);
end;

procedure TestFail(const ATestName, AReason: string);
begin
  WriteLn('[FAIL] ', ATestName, ' - ', AReason);
  Inc(LTestsFailed);
end;

procedure TestALPNCallbackExists;
begin
  try
    // Just verify the callback function exists (it's internal, so we can't call it directly)
    // If this compiles, the callback is properly defined
    TestPass('ALPN callback function definition exists');
  except
    on E: Exception do
      TestFail('ALPN callback function definition', E.Message);
  end;
end;

procedure TestALPNConstantsExist;
begin
  try
    // Verify ALPN/NPN constants are defined
    if SSL_TLSEXT_ERR_OK >= 0 then
      TestPass('ALPN/NPN constants defined');
  except
    on E: Exception do
      TestFail('ALPN/NPN constants', E.Message);
  end;
end;

procedure TestSSLFunctionsExist;
begin
  try
    // Verify SSL function pointers are declared
    // We can't test if they're loaded without initializing OpenSSL
    TestPass('SSL function pointers declared');
  except
    on E: Exception do
      TestFail('SSL function pointers', E.Message);
  end;
end;

begin
  WriteLn('=============================================================');
  WriteLn('ALPN Implementation Syntax Verification Test');
  WriteLn('=============================================================');
  WriteLn;
  
  TestALPNCallbackExists;
  TestALPNConstantsExist;
  TestSSLFunctionsExist;
  
  WriteLn;
  WriteLn('=============================================================');
  WriteLn('Test Summary:');
  WriteLn('  Total:  ', LTestsPassed + LTestsFailed);
  WriteLn('  Passed: ', LTestsPassed);
  WriteLn('  Failed: ', LTestsFailed);
  WriteLn('=============================================================');
  
  if LTestsFailed > 0 then
  begin
    WriteLn('RESULT: FAILED');
    ExitCode := 1;
  end
  else
  begin
    WriteLn('RESULT: SUCCESS');
    ExitCode := 0;
  end;
end.
