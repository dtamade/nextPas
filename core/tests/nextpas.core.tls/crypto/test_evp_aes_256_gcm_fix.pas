program test_evp_aes_256_gcm_fix;

{$mode objfpc}{$H+}

uses
  SysUtils, DynLibs,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.evp;

var
  LCipher: PEVP_CIPHER;
  LSuccess: Boolean;
  LTestsPassed, LTestsFailed: Integer;
  LLibHandle: THandle;

procedure RunTest(const ATestName: string; ACondition: Boolean);
begin
  Write(ATestName, ': ');
  if ACondition then
  begin
    WriteLn('PASS ✓');
    Inc(LTestsPassed);
  end
  else
  begin
    WriteLn('FAIL ✗');
    Inc(LTestsFailed);
  end;
end;

begin
  WriteLn('=== EVP_aes_256_gcm Fix Verification Test ===');
  WriteLn;

  LTestsPassed := 0;
  LTestsFailed := 0;

  // Test 1: Load OpenSSL library manually
  WriteLn('[Test 1] Loading OpenSSL library...');
  {$IFDEF MSWINDOWS}
  LLibHandle := LoadLibrary('libcrypto-3.dll');
  if LLibHandle = 0 then
    LLibHandle := LoadLibrary('libcrypto-1_1.dll');
  {$ELSE}
  LLibHandle := LoadLibrary('libcrypto.so.3');
  if LLibHandle = 0 then
    LLibHandle := LoadLibrary('libcrypto.so.1.1');
  {$ENDIF}

  RunTest('  OpenSSL library loaded', LLibHandle <> 0);

  if LLibHandle = 0 then
  begin
    WriteLn('  ERROR: Could not load OpenSSL library');
    WriteLn('  Please ensure OpenSSL 3.x is installed');
    Halt(1);
  end;

  // Load EVP functions
  LSuccess := LoadEVP(LLibHandle);
  RunTest('  EVP functions loaded', LSuccess);

  WriteLn;

  // Test 2: Check EVP_CIPHER_fetch availability
  WriteLn('[Test 2] Checking EVP_CIPHER_fetch API...');
  RunTest('  EVP_CIPHER_fetch assigned', Assigned(EVP_CIPHER_fetch));
  RunTest('  EVP_CIPHER_free assigned', Assigned(EVP_CIPHER_free));

  WriteLn;

  // Test 3: Check EVP_aes_256_gcm loading
  WriteLn('[Test 3] Checking AES-256-GCM cipher availability...');
  RunTest('  EVP_aes_256_gcm assigned', Assigned(EVP_aes_256_gcm));

  if Assigned(EVP_aes_256_gcm) then
  begin
    LCipher := EVP_aes_256_gcm();
    RunTest('  EVP_aes_256_gcm() returns valid pointer', Assigned(LCipher));

    if Assigned(LCipher) then
    begin
      RunTest('  Cipher key length is 32 bytes', EVP_CIPHER_get_key_length(LCipher) = 32);
      RunTest('  Cipher IV length is 12 bytes', EVP_CIPHER_get_iv_length(LCipher) = 12);
      RunTest('  Cipher block size is 1 byte', EVP_CIPHER_get_block_size(LCipher) = 1);
    end;
  end
  else
  begin
    WriteLn('  ⚠️  WARNING: EVP_aes_256_gcm not available');
    WriteLn('  This may indicate:');
    WriteLn('    - OpenSSL version < 3.0');
    WriteLn('    - Provider not loaded');
    WriteLn('    - Library loading issue');
  end;

  WriteLn;

  // Test 4: Check other GCM ciphers
  WriteLn('[Test 4] Checking other GCM ciphers...');
  RunTest('  EVP_aes_128_gcm assigned', Assigned(EVP_aes_128_gcm));
  RunTest('  EVP_aes_192_gcm assigned', Assigned(EVP_aes_192_gcm));

  WriteLn;
  WriteLn('========================================');
  WriteLn('Total Tests: ', LTestsPassed + LTestsFailed);
  WriteLn('Passed: ', LTestsPassed, ' ✓');
  WriteLn('Failed: ', LTestsFailed, ' ✗');
  WriteLn('========================================');

  if LTestsFailed = 0 then
  begin
    WriteLn;
    WriteLn('🎉 All tests passed! EVP_aes_256_gcm fix verified.');
    ExitCode := 0;
  end
  else
  begin
    WriteLn;
    WriteLn('⚠️  Some tests failed. Please review the output.');
    ExitCode := 1;
  end;

  // Cleanup
  if LLibHandle <> 0 then
    FreeLibrary(LLibHandle);
end.
