program test_aead_simple;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.aead;

procedure TestAESGCM;
var
  Key, IV, PlainText, AAD: TBytes;
  EncResult: TAEADEncryptResult;
  DecResult: TAEADDecryptResult;
  i: Integer;
begin
  WriteLn;
  WriteLn('=== AES-GCM Test ===');
  WriteLn;
  
  // Prepare test data
  SetLength(Key, 32);  // AES-256
  for i := 0 to 31 do
    Key[i] := Byte(i);
  
  SetLength(IV, 12);
  for i := 0 to 11 do
    IV[i] := Byte(i);
  
  PlainText := TBytes.Create($48, $65, $6C, $6C, $6F, $20, $57, $6F, $72, $6C, $64); // "Hello World"
  AAD := TBytes.Create($41, $44, $20, $44, $61, $74, $61); // "AD Data"
  
  // Test encryption
  Write('1. Encrypting... ');
  EncResult := AES_GCM_Encrypt(Key, IV, PlainText, AAD);
  if EncResult.Success then
  begin
    WriteLn('OK');
    WriteLn('   CipherText length: ', Length(EncResult.CipherText), ' bytes');
    WriteLn('   Tag length: ', Length(EncResult.Tag), ' bytes');
  end
  else
  begin
    WriteLn('FAILED: ', EncResult.ErrorMessage);
    Exit;
  end;
  
  // Test decryption
  Write('2. Decrypting... ');
  DecResult := AES_GCM_Decrypt(Key, IV, EncResult.CipherText, EncResult.Tag, AAD);
  if DecResult.Success then
  begin
    WriteLn('OK');
    WriteLn('   PlainText length: ', Length(DecResult.PlainText), ' bytes');
  end
  else
  begin
    WriteLn('FAILED: ', DecResult.ErrorMessage);
    Exit;
  end;
  
  // Verify decrypted data matches original
  Write('3. Verifying... ');
  if Length(DecResult.PlainText) = Length(PlainText) then
  begin
    for i := 0 to Length(PlainText) - 1 do
      if DecResult.PlainText[i] <> PlainText[i] then
      begin
        WriteLn('FAILED: Data mismatch at byte ', i);
        Exit;
      end;
    WriteLn('OK - Data matches!');
  end
  else
    WriteLn('FAILED: Length mismatch');
  
  // Test tamper detection
  Write('4. Testing tamper detection... ');
  EncResult.Tag[0] := EncResult.Tag[0] xor $FF;  // Corrupt the tag
  DecResult := AES_GCM_Decrypt(Key, IV, EncResult.CipherText, EncResult.Tag, AAD);
  if not DecResult.Success then
    WriteLn('OK - Tampering detected!')
  else
    WriteLn('FAILED: Tampered data not detected');
end;

procedure TestChaCha20Poly1305;
var
  Key, Nonce, PlainText, AAD: TBytes;
  EncResult: TAEADEncryptResult;
  DecResult: TAEADDecryptResult;
  i: Integer;
begin
  WriteLn;
  WriteLn('=== ChaCha20-Poly1305 Test ===');
  WriteLn;
  
  // Prepare test data
  SetLength(Key, 32);
  for i := 0 to 31 do
    Key[i] := Byte(i + 100);
  
  SetLength(Nonce, 12);
  for i := 0 to 11 do
    Nonce[i] := Byte(i + 50);
  
  PlainText := TBytes.Create($54, $65, $73, $74, $20, $44, $61, $74, $61); // "Test Data"
  AAD := TBytes.Create($4D, $65, $74, $61); // "Meta"
  
  // Test encryption
  Write('1. Encrypting... ');
  EncResult := ChaCha20_Poly1305_Encrypt(Key, Nonce, PlainText, AAD);
  if EncResult.Success then
  begin
    WriteLn('OK');
    WriteLn('   CipherText length: ', Length(EncResult.CipherText), ' bytes');
    WriteLn('   Tag length: ', Length(EncResult.Tag), ' bytes');
  end
  else
  begin
    WriteLn('FAILED: ', EncResult.ErrorMessage);
    Exit;
  end;
  
  // Test decryption
  Write('2. Decrypting... ');
  DecResult := ChaCha20_Poly1305_Decrypt(Key, Nonce, EncResult.CipherText, EncResult.Tag, AAD);
  if DecResult.Success then
  begin
    WriteLn('OK');
    WriteLn('   PlainText length: ', Length(DecResult.PlainText), ' bytes');
  end
  else
  begin
    WriteLn('FAILED: ', DecResult.ErrorMessage);
    Exit;
  end;
  
  // Verify
  Write('3. Verifying... ');
  if Length(DecResult.PlainText) = Length(PlainText) then
  begin
    for i := 0 to Length(PlainText) - 1 do
      if DecResult.PlainText[i] <> PlainText[i] then
      begin
        WriteLn('FAILED: Data mismatch');
        Exit;
      end;
    WriteLn('OK - Data matches!');
  end
  else
    WriteLn('FAILED: Length mismatch');
  
  // Test tamper detection
  Write('4. Testing tamper detection... ');
  EncResult.CipherText[0] := EncResult.CipherText[0] xor $FF;  // Corrupt data
  DecResult := ChaCha20_Poly1305_Decrypt(Key, Nonce, EncResult.CipherText, EncResult.Tag, AAD);
  if not DecResult.Success then
    WriteLn('OK - Tampering detected!')
  else
    WriteLn('FAILED: Tampered data not detected');
end;

begin
  WriteLn;
  WriteLn('========================================');
  WriteLn('AEAD Cipher Test Suite');
  WriteLn('========================================');
  
  // Initialize OpenSSL
  Write('Loading OpenSSL... ');
  try
    LoadOpenSSLCore;
    WriteLn('OK');
  except
    on E: Exception do
    begin
      WriteLn('FAILED: ', E.Message);
      Halt(1);
    end;
  end;
  
  // Load EVP functions
  Write('Loading EVP functions... ');
  if LoadEVP(GetCryptoLibHandle) then
    WriteLn('OK')
  else
  begin
    WriteLn('FAILED');
    Halt(1);
  end;
  
  // Run tests
  TestAESGCM;
  TestChaCha20Poly1305;
  
  WriteLn;
  WriteLn('========================================');
  WriteLn('All tests completed!');
  WriteLn('========================================');
  WriteLn;
  
  // Cleanup
  UnloadEVP;
  UnloadOpenSSLCore;
  
  WriteLn('Press Enter to exit...');
  ReadLn;
end.
