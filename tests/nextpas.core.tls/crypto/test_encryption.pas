program test_encryption;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fafafa.ssl,
  nextpas.core.tls.secure;

procedure TestEncryption;
var
  LKeyStore: TSecureKeyStoreImpl;
  LOriginal, LDecrypted: TSecureBytes;
  LEncrypted: TBytes;
  LPassword: string;
  LTestData: TBytes;
begin
  WriteLn('=== Testing TSecureKeyStore AES-256-GCM Encryption ===');
  WriteLn;
  
  // Create key store
  WriteLn('1. Creating TSecureKeyStore...');
  LKeyStore := TSecureKeyStoreImpl.Create('test_password');
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
    
    // Encrypt
    WriteLn('3. Encrypting with AES-256-GCM...');
    LPassword := 'MySecurePassword123!';
    LEncrypted := LKeyStore.EncryptKey(LOriginal, LPassword);
    WriteLn('   ✓ Encryption successful');
    WriteLn('   Encrypted size: ', Length(LEncrypted), ' bytes (includes salt+IV+tag)');
    WriteLn;
    
    // Decrypt
    WriteLn('4. Decrypting...');
    LDecrypted := LKeyStore.DecryptKey(LEncrypted, LPassword);
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
        LDecrypted := LKeyStore.DecryptKey(LEncrypted, 'WrongPassword');
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
    LKeyStore.Free;
  end;
end;

begin
  try
    TestEncryption;
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
