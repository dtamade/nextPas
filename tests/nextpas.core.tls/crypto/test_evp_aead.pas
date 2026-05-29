program test_evp_aead;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  SysUtils,
  DynLibs,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.evp;

// Helper function to convert bytes to hex string
function BytesToHex(const AData: PByte; ALen: Integer): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to ALen - 1 do
    Result := Result + IntToHex(PByte(AData + i)^, 2);
end;

// Test AES-256-GCM (AEAD mode)
function TestAES256GCM: Boolean;
const
  // Test vectors from NIST
  TestKey: array[0..31] of Byte = (
    $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $0c, $0d, $0e, $0f,
    $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $1a, $1b, $1c, $1d, $1e, $1f
  );
  TestIV: array[0..11] of Byte = (
    $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b
  );
  TestAAD: AnsiString = 'Additional authenticated data';
  TestPlaintext: AnsiString = 'Hello, AEAD World!';
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  ciphertext: array[0..1023] of Byte;
  plaintext: array[0..1023] of Byte;
  tag: array[0..15] of Byte;
  outlen, tmplen: Integer;
  LCiphertextLen: Integer;
  LSuccess: Boolean;
begin
  Result := False;
  LSuccess := False;
  WriteLn('Testing AES-256-GCM (AEAD)...');
  
  try
    // Check function availability
    if not Assigned(EVP_aes_256_gcm) then
    begin
      WriteLn('  [-] EVP_aes_256_gcm not loaded');
      Exit;
    end;
    
    cipher := EVP_aes_256_gcm();
    if not Assigned(cipher) then
    begin
      WriteLn('  [-] Failed to get AES-256-GCM cipher');
      Exit;
    end;
    
    WriteLn('  [+] Cipher obtained');
    
    // === ENCRYPTION ===
    ctx := EVP_CIPHER_CTX_new();
    if not Assigned(ctx) then
    begin
      WriteLn('  [-] Failed to create encryption context');
      Exit;
    end;
    
    try
      // Initialize encryption
      if EVP_EncryptInit_ex(ctx, cipher, nil, @TestKey[0], @TestIV[0]) <> 1 then
      begin
        WriteLn('  [-] Failed to init encryption');
        Exit;
      end;
      
      // Add AAD (Additional Authenticated Data)
      if Length(TestAAD) > 0 then
      begin
        outlen := 0;
        if EVP_EncryptUpdate(ctx, nil, outlen, PByte(TestAAD), Length(TestAAD)) <> 1 then
        begin
          WriteLn('  [-] Failed to set AAD');
          Exit;
        end;
      end;
      
      // Encrypt plaintext
      outlen := 0;
      if EVP_EncryptUpdate(ctx, @ciphertext[0], outlen, PByte(TestPlaintext), Length(TestPlaintext)) <> 1 then
      begin
        WriteLn('  [-] Failed to encrypt');
        Exit;
      end;
      
      LCiphertextLen := outlen;
      
      // Finalize encryption
      tmplen := 0;
      if EVP_EncryptFinal_ex(ctx, @ciphertext[LCiphertextLen], tmplen) <> 1 then
      begin
        WriteLn('  [-] Failed to finalize encryption');
        Exit;
      end;
      
      LCiphertextLen := LCiphertextLen + tmplen;
      
      // Get authentication tag
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16, @tag[0]) <> 1 then
      begin
        WriteLn('  [-] Failed to get authentication tag');
        Exit;
      end;
      
      WriteLn('  [+] Encrypted ', LCiphertextLen, ' bytes');
      WriteLn('      Ciphertext: ', BytesToHex(@ciphertext[0], LCiphertextLen));
      WriteLn('      Tag: ', BytesToHex(@tag[0], 16));
      
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
    // === DECRYPTION ===
    ctx := EVP_CIPHER_CTX_new();
    if not Assigned(ctx) then
    begin
      WriteLn('  [-] Failed to create decryption context');
      Exit;
    end;
    
    try
      // Initialize decryption
      if EVP_DecryptInit_ex(ctx, cipher, nil, @TestKey[0], @TestIV[0]) <> 1 then
      begin
        WriteLn('  [-] Failed to init decryption');
        Exit;
      end;
      
      // Add AAD
      if Length(TestAAD) > 0 then
      begin
        outlen := 0;
        if EVP_DecryptUpdate(ctx, nil, outlen, PByte(TestAAD), Length(TestAAD)) <> 1 then
        begin
          WriteLn('  [-] Failed to set AAD for decryption');
          Exit;
        end;
      end;
      
      // Decrypt ciphertext
      outlen := 0;
      if EVP_DecryptUpdate(ctx, @plaintext[0], outlen, @ciphertext[0], LCiphertextLen) <> 1 then
      begin
        WriteLn('  [-] Failed to decrypt');
        Exit;
      end;
      
      // Set expected tag
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, 16, @tag[0]) <> 1 then
      begin
        WriteLn('  [-] Failed to set authentication tag');
        Exit;
      end;
      
      // Finalize decryption (verifies tag)
      tmplen := 0;
      if EVP_DecryptFinal_ex(ctx, @plaintext[outlen], tmplen) <> 1 then
      begin
        WriteLn('  [-] Authentication tag verification failed!');
        Exit;
      end;
      
      // Verify plaintext
      if CompareMem(@plaintext[0], PByte(TestPlaintext), Length(TestPlaintext)) then
      begin
        WriteLn('  [+] Decrypted and authenticated successfully');
        WriteLn('      Plaintext: ', PAnsiChar(@plaintext[0]));
        LSuccess := True;
      end
      else
        WriteLn('  [-] Plaintext mismatch');
      
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
  except
    on E: Exception do
      WriteLn('  ❌ Exception: ', E.Message);
  end;
  
  if LSuccess then
  begin
    WriteLn('  ✅ AES-256-GCM Test PASSED');
    Result := True;
  end
  else
    WriteLn('  ❌ AES-256-GCM Test FAILED');
    
  WriteLn;
end;

// Test ChaCha20-Poly1305 (AEAD mode)
function TestChaCha20Poly1305: Boolean;
const
  TestKey: array[0..31] of Byte = (
    $80, $81, $82, $83, $84, $85, $86, $87, $88, $89, $8a, $8b, $8c, $8d, $8e, $8f,
    $90, $91, $92, $93, $94, $95, $96, $97, $98, $99, $9a, $9b, $9c, $9d, $9e, $9f
  );
  TestIV: array[0..11] of Byte = (
    $07, $00, $00, $00, $40, $41, $42, $43, $44, $45, $46, $47
  );
  TestAAD: AnsiString = 'ChaCha20 AAD';
  TestPlaintext: AnsiString = 'ChaCha20-Poly1305 test message';
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  ciphertext: array[0..1023] of Byte;
  plaintext: array[0..1023] of Byte;
  tag: array[0..15] of Byte;
  outlen, tmplen: Integer;
  LCiphertextLen: Integer;
  LSuccess: Boolean;
begin
  Result := False;
  LSuccess := False;
  WriteLn('Testing ChaCha20-Poly1305 (AEAD)...');
  
  try
    if not Assigned(EVP_chacha20_poly1305) then
    begin
      WriteLn('  [-] EVP_chacha20_poly1305 not loaded');
      Exit;
    end;
    
    cipher := EVP_chacha20_poly1305();
    if not Assigned(cipher) then
    begin
      WriteLn('  [-] Failed to get ChaCha20-Poly1305 cipher');
      Exit;
    end;
    
    WriteLn('  [+] Cipher obtained');
    
    // === ENCRYPTION ===
    ctx := EVP_CIPHER_CTX_new();
    if not Assigned(ctx) then
    begin
      WriteLn('  [-] Failed to create encryption context');
      Exit;
    end;
    
    try
      if EVP_EncryptInit_ex(ctx, cipher, nil, @TestKey[0], @TestIV[0]) <> 1 then
      begin
        WriteLn('  [-] Failed to init encryption');
        Exit;
      end;
      
      // Add AAD
      if Length(TestAAD) > 0 then
      begin
        outlen := 0;
        if EVP_EncryptUpdate(ctx, nil, outlen, PByte(TestAAD), Length(TestAAD)) <> 1 then
        begin
          WriteLn('  [-] Failed to set AAD');
          Exit;
        end;
      end;
      
      // Encrypt
      outlen := 0;
      if EVP_EncryptUpdate(ctx, @ciphertext[0], outlen, PByte(TestPlaintext), Length(TestPlaintext)) <> 1 then
      begin
        WriteLn('  [-] Failed to encrypt');
        Exit;
      end;
      
      LCiphertextLen := outlen;
      
      tmplen := 0;
      if EVP_EncryptFinal_ex(ctx, @ciphertext[LCiphertextLen], tmplen) <> 1 then
      begin
        WriteLn('  [-] Failed to finalize encryption');
        Exit;
      end;
      
      LCiphertextLen := LCiphertextLen + tmplen;
      
      // Get tag (Poly1305 uses 16-byte tag)
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_GET_TAG, 16, @tag[0]) <> 1 then
      begin
        WriteLn('  [-] Failed to get authentication tag');
        Exit;
      end;
      
      WriteLn('  [+] Encrypted ', LCiphertextLen, ' bytes');
      WriteLn('      Ciphertext: ', BytesToHex(@ciphertext[0], LCiphertextLen));
      WriteLn('      Tag: ', BytesToHex(@tag[0], 16));
      
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
    // === DECRYPTION ===
    ctx := EVP_CIPHER_CTX_new();
    if not Assigned(ctx) then
    begin
      WriteLn('  [-] Failed to create decryption context');
      Exit;
    end;
    
    try
      if EVP_DecryptInit_ex(ctx, cipher, nil, @TestKey[0], @TestIV[0]) <> 1 then
      begin
        WriteLn('  [-] Failed to init decryption');
        Exit;
      end;
      
      // Add AAD
      if Length(TestAAD) > 0 then
      begin
        outlen := 0;
        if EVP_DecryptUpdate(ctx, nil, outlen, PByte(TestAAD), Length(TestAAD)) <> 1 then
        begin
          WriteLn('  [-] Failed to set AAD for decryption');
          Exit;
        end;
      end;
      
      // Decrypt
      outlen := 0;
      if EVP_DecryptUpdate(ctx, @plaintext[0], outlen, @ciphertext[0], LCiphertextLen) <> 1 then
      begin
        WriteLn('  [-] Failed to decrypt');
        Exit;
      end;
      
      // Set tag for verification
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_TAG, 16, @tag[0]) <> 1 then
      begin
        WriteLn('  [-] Failed to set authentication tag');
        Exit;
      end;
      
      // Finalize (verifies tag)
      tmplen := 0;
      if EVP_DecryptFinal_ex(ctx, @plaintext[outlen], tmplen) <> 1 then
      begin
        WriteLn('  [-] Authentication tag verification failed!');
        Exit;
      end;
      
      if CompareMem(@plaintext[0], PByte(TestPlaintext), Length(TestPlaintext)) then
      begin
        WriteLn('  [+] Decrypted and authenticated successfully');
        WriteLn('      Plaintext: ', PAnsiChar(@plaintext[0]));
        LSuccess := True;
      end
      else
        WriteLn('  [-] Plaintext mismatch');
      
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
  except
    on E: Exception do
      WriteLn('  ❌ Exception: ', E.Message);
  end;
  
  if LSuccess then
  begin
    WriteLn('  ✅ ChaCha20-Poly1305 Test PASSED');
    Result := True;
  end
  else
    WriteLn('  ❌ ChaCha20-Poly1305 Test FAILED');
    
  WriteLn;
end;

var
  LCryptoLib: TLibHandle;
  LPassCount, LTotalCount: Integer;
  
begin
  WriteLn('========================================');
  WriteLn('EVP AEAD (Authenticated Encryption) Test');
  WriteLn('========================================');
  WriteLn;
  
  // Initialize OpenSSL
  try
    if not LoadOpenSSLLibrary then
      raise Exception.Create('Failed to load OpenSSL library');
  except
    on E: Exception do
    begin
      WriteLn('ERROR: Failed to load OpenSSL!');
      WriteLn('Message: ', E.Message);
      Halt(1);
    end;
  end;
  
  WriteLn('OpenSSL loaded successfully!');
  
  // Load libcrypto for EVP functions
  {$IFDEF MSWINDOWS}
  LCryptoLib := LoadLibrary('libcrypto-3-x64.dll');
  if LCryptoLib = NilHandle then
    LCryptoLib := LoadLibrary('libcrypto-3.dll');
  if LCryptoLib = NilHandle then
    LCryptoLib := LoadLibrary('libcrypto.dll');
  {$ELSE}
  LCryptoLib := LoadLibrary('libcrypto.so.3');
  if LCryptoLib = NilHandle then
    LCryptoLib := LoadLibrary('libcrypto.so');
  {$ENDIF}
  
  if LCryptoLib = NilHandle then
  begin
    WriteLn('ERROR: Failed to load libcrypto!');
    Halt(1);
  end;
  
  WriteLn('libcrypto loaded');
  
  // Load EVP module
  if not LoadEVP(LCryptoLib) then
  begin
    WriteLn('ERROR: Failed to load EVP module!');
    FreeLibrary(LCryptoLib);
    Halt(1);
  end;
  
  WriteLn('EVP module loaded successfully!');
  WriteLn;
  WriteLn('========================================');
  WriteLn;
  
  // Run tests
  LPassCount := 0;
  LTotalCount := 2;
  
  if TestAES256GCM then Inc(LPassCount);
  if TestChaCha20Poly1305 then Inc(LPassCount);
  
  // Summary
  WriteLn('========================================');
  WriteLn('Test Summary');
  WriteLn('========================================');
  WriteLn('Total tests:  ', LTotalCount);
  WriteLn('Passed:       ', LPassCount, ' ✅');
  WriteLn('Failed:       ', LTotalCount - LPassCount);
  WriteLn('Success rate: ', (LPassCount * 100) div LTotalCount, '%');
  WriteLn('========================================');
  
  if LPassCount = LTotalCount then
  begin
    WriteLn('🎉 All AEAD tests PASSED!');
    WriteLn;
    WriteLn('AEAD (Authenticated Encryption with Associated Data) provides:');
    WriteLn('  • Confidentiality (encryption)');
    WriteLn('  • Integrity (authentication)');
    WriteLn('  • Protection against tampering');
    WriteLn('  • Support for additional authenticated data (AAD)');
    Halt(0);
  end
  else
  begin
    WriteLn('⚠️  Some AEAD tests FAILED!');
    Halt(1);
  end;
end.
