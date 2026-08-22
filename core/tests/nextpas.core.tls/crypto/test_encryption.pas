program test_encryption;

{$mode objfpc}{$H+}

uses
  nextpas.core.tls.openssl.backed,
  nextpas.core.system.sysutils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.secure;

var
  LKeyStore: ISecureKeyStore;
  LOriginal, LDecrypted: TSecureBytes;
  LPassword: string;
  LTestData: TBytes;
  LFactory: ISSLLibrary;
begin
  WriteLn('=== Testing ISecureKeyStore AES-256-GCM Encryption ===');
  WriteLn;

  // Initialize OpenSSL backend so EVP/KDF symbols are loaded
  LFactory := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  if LFactory = nil then
  begin
    WriteLn('FATAL: OpenSSL backend is not available');
    ExitCode := 1;
    Exit;
  end;
  WriteLn('OpenSSL backend: ', LFactory.GetVersionString);
  WriteLn;

  // Create key store
  WriteLn('1. Creating key store...');
  LKeyStore := CreateSecureKeyStore;
  try
    WriteLn('   ✓ Key store created');
    WriteLn;

    // Create test data
    WriteLn('2. Creating test data...');
    SetLength(LTestData, 35);
    Move('Hello, World! This is secret data.'[1], LTestData[0], 35);
    LOriginal := TSecureBytes.Create(LTestData);
    WriteLn('   Data size: ', LOriginal.Size, ' bytes');
    Write('   Original: ');
    Write(PChar(LOriginal.Data));
    WriteLn;
    WriteLn;

    // Encrypt and store under a key id
    WriteLn('3. Encrypting with AES-256-GCM...');
    LPassword := 'MySecurePassword123!';
    LKeyStore.StoreKey('test-key', LOriginal, LPassword);
    WriteLn('   ✓ Encryption successful');
    WriteLn('   Encrypted blob size: ', LOriginal.Size, ' bytes (plaintext)');
    WriteLn;

    // Decrypt
    WriteLn('4. Decrypting...');
    LDecrypted := LKeyStore.LoadKey('test-key', LPassword);
    WriteLn('   ✓ Decryption successful');
    WriteLn;

    // Verify
    WriteLn('5. Verifying integrity...');
    if (LOriginal.Size = LDecrypted.Size) and
       (CompareMem(LOriginal.Data, LDecrypted.Data, LOriginal.Size)) then
    begin
      WriteLn('   ✓ SUCCESS: Data matches!');
      WriteLn;

      // Test wrong password
      WriteLn('6. Testing authentication (wrong password)...');
      try
        LDecrypted := LKeyStore.LoadKey('test-key', 'WrongPassword');
        WriteLn('   ✗ FAILED: Should have rejected wrong password');
        ExitCode := 1;
      except
        on E: Exception do
        begin
          WriteLn('   ✓ Correctly rejected');
        end;
      end;
      WriteLn;

      WriteLn('=== ALL TESTS PASSED ===');
    end
    else
    begin
      WriteLn('   ✗ FAILED: Data mismatch');
      ExitCode := 1;
    end;
  finally
    LKeyStore := nil;
  end;
end.