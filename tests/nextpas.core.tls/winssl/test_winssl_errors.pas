program test_winssl_errors;

{$mode objfpc}{$H+}

uses
  SysUtils, nextpas.core.tls.winssl.errors, nextpas.core.tls.winssl.base;

var
  GTestCount: Integer = 0;
  GPassCount: Integer = 0;

procedure TestErrorMessage(const aTestName: string; aErrorCode: DWORD; const aExpected: string);
var
  LResult: string;
begin
  Inc(GTestCount);
  LResult := GetFriendlyErrorMessageCN(aErrorCode);
  
  if Pos(aExpected, LResult) > 0 then
  begin
    Inc(GPassCount);
    WriteLn('[PASS] ', aTestName);
  end
  else
  begin
    WriteLn('[FAIL] ', aTestName);
    WriteLn('       Expected to contain: ', aExpected);
    WriteLn('       Got: ', LResult);
  end;
end;

procedure TestErrorMessageEN(const aTestName: string; aErrorCode: DWORD; const aExpected: string);
var
  LResult: string;
begin
  Inc(GTestCount);
  LResult := GetFriendlyErrorMessageEN(aErrorCode);
  
  if Pos(aExpected, LResult) > 0 then
  begin
    Inc(GPassCount);
    WriteLn('[PASS] ', aTestName);
  end
  else
  begin
    WriteLn('[FAIL] ', aTestName);
    WriteLn('       Expected to contain: ', aExpected);
    WriteLn('       Got: ', LResult);
  end;
end;

begin
  WriteLn('WinSSL Error Handling Test Suite');
  WriteLn;
  
  // Test English error messages (avoid encoding issues)
  TestErrorMessageEN('Test 1: SEC_E_OK', DWORD(SEC_E_OK), 'successful');
  TestErrorMessageEN('Test 2: SEC_I_CONTINUE_NEEDED', DWORD(SEC_I_CONTINUE_NEEDED), 'continues');
  TestErrorMessageEN('Test 3: SEC_E_INCOMPLETE_MESSAGE', DWORD(SEC_E_INCOMPLETE_MESSAGE), 'Incomplete');
  TestErrorMessageEN('Test 4: CERT_E_EXPIRED', DWORD(CERT_E_EXPIRED), 'expired');
  TestErrorMessageEN('Test 5: CERT_E_UNTRUSTEDROOT', DWORD(CERT_E_UNTRUSTEDROOT), 'untrusted');
  TestErrorMessageEN('Test 6: CERT_E_REVOKED', DWORD(CERT_E_REVOKED), 'revoked');
  
  // Test unknown error code - use English version
  Inc(GTestCount);
  if Pos('Unknown error', GetFriendlyErrorMessageEN($DEADBEEF)) > 0 then
  begin
    Inc(GPassCount);
    WriteLn('[PASS] Test 7: Unknown Error Code');
  end
  else
    WriteLn('[FAIL] Test 7: Unknown Error Code');
  
  WriteLn;
  WriteLn('=' + StringOfChar('=', 78));
  WriteLn(Format('Total: %d, Passed: %d, Failed: %d (%.1f%%)',
    [GTestCount, GPassCount, GTestCount - GPassCount,
     (GPassCount / GTestCount) * 100.0]));
  WriteLn('=' + StringOfChar('=', 78));
  
  if GPassCount < GTestCount then
    Halt(1);
end.

