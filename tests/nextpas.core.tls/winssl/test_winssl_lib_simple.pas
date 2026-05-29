program test_winssl_lib_simple;

{$mode objfpc}{$H+}

uses
  SysUtils,
  
  nextpas.core.tls.base,
  nextpas.core.tls.winssl.lib;

var
  SSLLib: ISSLLibrary;
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure TestPass(const TestName: string);
begin
  WriteLn('[PASS] ', TestName);
  Inc(TestsPassed);
end;

procedure TestFail(const TestName, Reason: string);
begin
  WriteLn('[FAIL] ', TestName, ': ', Reason);
  Inc(TestsFailed);
end;

begin
  WriteLn('=== WinSSL Library Simple Tests ===');
  WriteLn;
  
  // Test 1: Create library
  WriteLn('Test 1: Creating WinSSL Library...');
  try
    SSLLib := CreateWinSSLLibrary;
    if SSLLib <> nil then
      TestPass('CreateWinSSLLibrary')
    else
      TestFail('CreateWinSSLLibrary', 'Returned nil');
  except
    on E: Exception do
      TestFail('CreateWinSSLLibrary', E.Message);
  end;
  
  // Test 2: Initialize library
  WriteLn('Test 2: Initializing library...');
  try
    if SSLLib.Initialize then
      TestPass('SSLLib.Initialize')
    else
      TestFail('SSLLib.Initialize', 'Returned False: ' + SSLLib.GetLastErrorString);
  except
    on E: Exception do
      TestFail('SSLLib.Initialize', E.Message);
  end;
  
  // Test 3: Check if initialized
  WriteLn('Test 3: Checking initialization status...');
  if SSLLib.IsInitialized then
    TestPass('SSLLib.IsInitialized')
  else
    TestFail('SSLLib.IsInitialized', 'Not initialized');
  
  // Test 4: Get library type
  WriteLn('Test 4: Getting library type...');
  try
    if SSLLib.GetLibraryType = sslWinSSL then
      TestPass('GetLibraryType = sslWinSSL')
    else
      TestFail('GetLibraryType', 'Wrong type');
  except
    on E: Exception do
      TestFail('GetLibraryType', E.Message);
  end;
  
  // Test 5: Get version string
  WriteLn('Test 5: Getting version string...');
  try
    WriteLn('  Version: ', SSLLib.GetVersionString);
    if Pos('Schannel', SSLLib.GetVersionString) > 0 then
      TestPass('GetVersionString contains "Schannel"')
    else
      TestFail('GetVersionString', 'Invalid version string');
  except
    on E: Exception do
      TestFail('GetVersionString', E.Message);
  end;
  
  // Test 6: Protocol support - TLS 1.2
  WriteLn('Test 6: Checking TLS 1.2 support...');
  try
    if SSLLib.IsProtocolSupported(sslProtocolTLS12) then
      TestPass('TLS 1.2 supported')
    else
      TestFail('TLS 1.2 supported', 'Should be supported');
  except
    on E: Exception do
      TestFail('TLS 1.2 support check', E.Message);
  end;
  
  // Test 7: Protocol support - SSL 2.0 (should NOT be supported)
  WriteLn('Test 7: Checking SSL 2.0 support (should be disabled)...');
  try
    if not SSLLib.IsProtocolSupported(sslProtocolSSL2) then
      TestPass('SSL 2.0 not supported (correct)')
    else
      TestFail('SSL 2.0 support check', 'Should not be supported');
  except
    on E: Exception do
      TestFail('SSL 2.0 support check', E.Message);
  end;
  
  // Test 8: Finalize
  WriteLn('Test 8: Finalizing library...');
  try
    SSLLib.Finalize;
    TestPass('SSLLib.Finalize');
  except
    on E: Exception do
      TestFail('SSLLib.Finalize', E.Message);
  end;
  
  // Summary
  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);
  
  if TestsFailed = 0 then
  begin
    WriteLn;
    WriteLn('ALL TESTS PASSED!');
    ExitCode := 0;
  end
  else
  begin
    WriteLn;
    WriteLn('SOME TESTS FAILED!');
    ExitCode := 1;
  end;
end.
