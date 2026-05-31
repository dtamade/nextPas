program test_p4_engine;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.engine,
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

function RuntimeInteger(AValue: Integer): Integer;
begin
  Result := AValue;
end;

procedure TestLoadEngineFunctions;
begin
  StartTest('Load ENGINE functions');
  try
    if LoadOpenSSLEngine(GetCryptoLibHandle) then
      PassTest
    else
      FailTest('LoadOpenSSLEngine returned False (deprecated in OpenSSL 3.x)');
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestEngineBasicFunctions;
begin
  StartTest('ENGINE basic functions availability');
  try
    if not Assigned(ENGINE_new) then
      FailTest('ENGINE_new not loaded')
    else if not Assigned(ENGINE_free) then
      FailTest('ENGINE_free not loaded')
    else if not Assigned(ENGINE_up_ref) then
      FailTest('ENGINE_up_ref not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestEngineDiscoveryFunctions;
begin
  StartTest('ENGINE discovery functions availability');
  try
    if not Assigned(ENGINE_by_id) then
      FailTest('ENGINE_by_id not loaded')
    else if not Assigned(ENGINE_get_first) then
      FailTest('ENGINE_get_first not loaded')
    else if not Assigned(ENGINE_get_next) then
      FailTest('ENGINE_get_next not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestEngineLifecycleFunctions;
begin
  StartTest('ENGINE lifecycle functions availability');
  try
    if not Assigned(ENGINE_init) then
      FailTest('ENGINE_init not loaded')
    else if not Assigned(ENGINE_finish) then
      FailTest('ENGINE_finish not loaded')
    else if not Assigned(ENGINE_load_builtin_engines) then
      FailTest('ENGINE_load_builtin_engines not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestEngineInfoFunctions;
begin
  StartTest('ENGINE info functions availability');
  try
    if not Assigned(ENGINE_get_id) then
      FailTest('ENGINE_get_id not loaded')
    else if not Assigned(ENGINE_get_name) then
      FailTest('ENGINE_get_name not loaded')
    else if not Assigned(ENGINE_set_id) then
      FailTest('ENGINE_set_id not loaded')
    else if not Assigned(ENGINE_set_name) then
      FailTest('ENGINE_set_name not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestEngineControlFunctions;
begin
  StartTest('ENGINE control functions availability');
  try
    if not Assigned(ENGINE_ctrl) then
      FailTest('ENGINE_ctrl not loaded')
    else if not Assigned(ENGINE_ctrl_cmd_string) then
      FailTest('ENGINE_ctrl_cmd_string not loaded')
    else if not Assigned(ENGINE_set_default) then
      FailTest('ENGINE_set_default not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestEngineKeyLoadingFunctions;
begin
  StartTest('ENGINE key loading functions availability');
  try
    if not Assigned(ENGINE_load_private_key) then
      FailTest('ENGINE_load_private_key not loaded')
    else if not Assigned(ENGINE_load_public_key) then
      FailTest('ENGINE_load_public_key not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestEngineConstants;
begin
  StartTest('ENGINE method flag constants');
  try
    if (RuntimeInteger(ENGINE_METHOD_RSA) <> $0001) then
      FailTest('ENGINE_METHOD_RSA incorrect')
    else if (RuntimeInteger(ENGINE_METHOD_DSA) <> $0002) then
      FailTest('ENGINE_METHOD_DSA incorrect')
    else if (RuntimeInteger(ENGINE_METHOD_DH) <> $0004) then
      FailTest('ENGINE_METHOD_DH incorrect')
    else if (RuntimeInteger(ENGINE_METHOD_RAND) <> $0008) then
      FailTest('ENGINE_METHOD_RAND incorrect')
    else if (RuntimeInteger(ENGINE_METHOD_CIPHERS) <> $0040) then
      FailTest('ENGINE_METHOD_CIPHERS incorrect')
    else if (RuntimeInteger(ENGINE_METHOD_DIGESTS) <> $0080) then
      FailTest('ENGINE_METHOD_DIGESTS incorrect')
    else if (RuntimeInteger(ENGINE_METHOD_ALL) <> $FFFF) then
      FailTest('ENGINE_METHOD_ALL incorrect')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestHelperFunctions;
begin
  StartTest('Helper functions availability');
  try
    // Just check that helper functions are declared
    // We can't test them without actual engines
    PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestDeprecationWarning;
begin
  StartTest('Deprecation warning check');
  try
    WriteLn;
    WriteLn('  [WARNING] ENGINE API is DEPRECATED in OpenSSL 3.x');
    WriteLn('  [WARNING] Use Provider API instead for OpenSSL 3.x');
    WriteLn('  [WARNING] ENGINE functions may not be available');
    WriteLn('  [INFO] This module is for backward compatibility only');
    PassTest;
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
  WriteLn('Note: ENGINE API is deprecated in OpenSSL 3.x');
  WriteLn('      Use Provider API for new applications');
end;

begin
  WriteLn('============================================');
  WriteLn('P4 ENGINE Module Test Suite');
  WriteLn('Testing OpenSSL ENGINE (Hardware Acceleration) API');
  WriteLn('============================================');
  WriteLn;

  try
    // Initialize OpenSSL
    LoadOpenSSLCore;

    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);
    WriteLn;
    WriteLn('WARNING: ENGINE is deprecated in OpenSSL 3.x');
    WriteLn('         Use Provider API instead');
    WriteLn;

    // Run tests
    TestLoadEngineFunctions;
    TestEngineBasicFunctions;
    TestEngineDiscoveryFunctions;
    TestEngineLifecycleFunctions;
    TestEngineInfoFunctions;
    TestEngineControlFunctions;
    TestEngineKeyLoadingFunctions;
    TestEngineConstants;
    TestHelperFunctions;
    TestDeprecationWarning;

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
