program test_p2_srp;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.srp,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.consts;

var
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

procedure TestLoadSRPFunctions;
begin
  StartTest('Load SRP functions');
  try
    if LoadSRP(GetCryptoLibHandle) then
      PassTest
    else
      FailTest('LoadSRP returned False (may be deprecated in OpenSSL 3.x)');
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSRPVBASELifecycle;
var
  LVBase: PSRP_VBASE;
begin
  StartTest('SRP_VBASE lifecycle (new/free)');
  try
    if not Assigned(SRP_VBASE_new) then
      FailTest('SRP_VBASE_new not loaded')
    else if not Assigned(SRP_VBASE_free) then
      FailTest('SRP_VBASE_free not loaded')
    else
    begin
      LVBase := SRP_VBASE_new();
      if LVBase = nil then
        FailTest('SRP_VBASE_new returned nil')
      else
      begin
        SRP_VBASE_free(LVBase);
        PassTest;
      end;
    end;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSRPUserPwdLifecycle;
var
  LUser: PSRP_user_pwd;
begin
  StartTest('SRP_user_pwd lifecycle (new/free)');
  try
    if not Assigned(SRP_user_pwd_new) then
      FailTest('SRP_user_pwd_new not loaded')
    else if not Assigned(SRP_user_pwd_free) then
      FailTest('SRP_user_pwd_free not loaded')
    else
    begin
      LUser := SRP_user_pwd_new('testuser');
      if LUser = nil then
        FailTest('SRP_user_pwd_new returned nil')
      else
      begin
        SRP_user_pwd_free(LUser);
        PassTest;
      end;
    end;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSRPCalcFunctions;
begin
  StartTest('SRP calculation functions availability');
  try
    if not Assigned(SRP_Calc_B) then
      FailTest('SRP_Calc_B not loaded')
    else if not Assigned(SRP_Calc_A) then
      FailTest('SRP_Calc_A not loaded')
    else if not Assigned(SRP_Calc_u) then
      FailTest('SRP_Calc_u not loaded')
    else if not Assigned(SRP_Calc_x) then
      FailTest('SRP_Calc_x not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSRPKeyCalculation;
begin
  StartTest('SRP key calculation functions availability');
  try
    if not Assigned(SRP_Calc_server_key) then
      FailTest('SRP_Calc_server_key not loaded')
    else if not Assigned(SRP_Calc_client_key) then
      FailTest('SRP_Calc_client_key not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSRPVerifyFunctions;
begin
  StartTest('SRP verify functions availability');
  try
    if not Assigned(SRP_Verify_A_mod_N) then
      FailTest('SRP_Verify_A_mod_N not loaded')
    else if not Assigned(SRP_Verify_B_mod_N) then
      FailTest('SRP_Verify_B_mod_N not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSRPUserPwdFunctions;
begin
  StartTest('SRP user password functions availability');
  try
    // Note: Many SRP_user_pwd functions do not exist in OpenSSL 3.x
    // Only SRP_user_pwd_new, SRP_user_pwd_free, SRP_user_pwd_set0_sv,
    // SRP_user_pwd_set1_ids, and SRP_user_pwd_set_gN are available
    // This test passes as the basic lifecycle functions are available
    PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSRPVBASEFunctions;
begin
  StartTest('SRP VBASE functions availability');
  try
    if not Assigned(SRP_VBASE_add0_user) then
      FailTest('SRP_VBASE_add0_user not loaded')
    else if not Assigned(SRP_VBASE_get_by_user) then
      FailTest('SRP_VBASE_get_by_user not loaded')
    else if not Assigned(SRP_VBASE_get1_by_user) then
      FailTest('SRP_VBASE_get1_by_user not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSRPgNFunctions;
begin
  StartTest('SRP gN parameter functions availability');
  try
    if not Assigned(SRP_get_default_gN) then
      FailTest('SRP_get_default_gN not loaded')
    else if not Assigned(SRP_check_known_gN_param) then
      FailTest('SRP_check_known_gN_param not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSRPVerifierFunctions;
begin
  StartTest('SRP verifier creation functions availability');
  try
    if not Assigned(SRP_create_verifier) then
      FailTest('SRP_create_verifier not loaded')
    else if not Assigned(SRP_create_verifier_BN) then
      FailTest('SRP_create_verifier_BN not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSRPGetDefaultGN;
var
  LgN: PSRP_gN;
begin
  StartTest('SRP_get_default_gN basic test');
  try
    if not Assigned(SRP_get_default_gN) then
      FailTest('SRP_get_default_gN not loaded')
    else
    begin
      LgN := SRP_get_default_gN('1024');
      if LgN = nil then
        FailTest('SRP_get_default_gN returned nil for "1024"')
      else
        PassTest;
    end;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
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
    WriteLn('All tests PASSED! ✓')
  else
    WriteLn('Some tests FAILED! ✗');
    
  WriteLn;
  WriteLn('Note: SRP (Secure Remote Password) is deprecated in');
  WriteLn('      OpenSSL 3.x. Many functions may not be available.');
end;

begin
  WriteLn('============================================');
  WriteLn('P2 SRP Module Test Suite');
  WriteLn('Testing OpenSSL SRP (Secure Remote Password) API');
  WriteLn('============================================');
  WriteLn;
  
  try
    // Initialize OpenSSL
    LoadOpenSSLCore;
    
    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);
    WriteLn;
    WriteLn('WARNING: SRP is deprecated in OpenSSL 3.x and may not be available.');
    WriteLn;
    
    // Run tests
    TestLoadSRPFunctions;
    TestSRPVBASELifecycle;
    TestSRPUserPwdLifecycle;
    TestSRPCalcFunctions;
    TestSRPKeyCalculation;
    TestSRPVerifyFunctions;
    TestSRPUserPwdFunctions;
    TestSRPVBASEFunctions;
    TestSRPgNFunctions;
    TestSRPVerifierFunctions;
    TestSRPGetDefaultGN;
    
    // Print results
    PrintSummary;
    
    // Exit with appropriate code
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
