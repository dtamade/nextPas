program test_evp_cipher;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.evp;

// Helper function to convert bytes to hex string
function BytesToHex(const Data: array of Byte): string;
var
  i: Integer;
begin
  Result := '';
  for i := Low(Data) to High(Data) do
    Result := Result + IntToHex(Data[i], 2);
end;

// Test AES-128-CBC encryption/decryption
procedure TestAES128CBC;
const
  TestKey: array[0..15] of Byte = (
    $2b, $7e, $15, $16, $28, $ae, $d2, $a6, $ab, $f7, $15, $88, $09, $cf, $4f, $3c
  );
  TestIV: array[0..15] of Byte = (
    $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $0c, $0d, $0e, $0f
  );
  TestPlaintext: AnsiString = 'Hello, OpenSSL!';
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  ciphertext: array of Byte;
  plaintext: array of Byte;
  outlen, tmplen: Integer;
  success: Boolean;
begin
  WriteLn('Testing AES-128-CBC Encryption/Decryption...');
  WriteLn;

  success := False;
  try
    // Check if EVP functions are loaded
    if not Assigned(EVP_aes_128_cbc) then
    begin
      WriteLn('  [-] EVP_aes_128_cbc function not loaded');
      Exit;
    end;
    if not Assigned(EVP_CIPHER_CTX_new) then
    begin
      WriteLn('  [-] EVP_CIPHER_CTX_new function not loaded');
      Exit;
    end;

    // Get cipher
    cipher := EVP_aes_128_cbc();
    if not Assigned(cipher) then
    begin
      WriteLn('  [-] Failed to get AES-128-CBC cipher');
      Exit;
    end;
    WriteLn('  [+] AES-128-CBC cipher obtained');
    
    // === ENCRYPTION ===
    ctx := EVP_CIPHER_CTX_new();
    if not Assigned(ctx) then
    begin
      WriteLn('  [-] Failed to create cipher context');
      Exit;
    end;
    
    try
      // Initialize encryption
      if EVP_EncryptInit_ex(ctx, cipher, nil, @TestKey[0], @TestIV[0]) <> 1 then
      begin
        WriteLn('  [-] Failed to initialize encryption');
        Exit;
      end;
      
      // Prepare output buffer (plaintext size + block size for padding)
      SetLength(ciphertext, Length(TestPlaintext) + 32);
      
      // Encrypt
      outlen := 0;
      if EVP_EncryptUpdate(ctx, @ciphertext[0], outlen, 
         PByte(TestPlaintext), Length(TestPlaintext)) <> 1 then
      begin
        WriteLn('  [-] Failed to encrypt data');
        Exit;
      end;
      
      // Finalize encryption
      tmplen := 0;
      if EVP_EncryptFinal_ex(ctx, @ciphertext[outlen], tmplen) <> 1 then
      begin
        WriteLn('  [-] Failed to finalize encryption');
        Exit;
      end;
      
      outlen := outlen + tmplen;
      SetLength(ciphertext, outlen);
      WriteLn('  [+] Encryption successful (', outlen, ' bytes)');
      WriteLn('      Ciphertext: ', BytesToHex(ciphertext));
      
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
    // === DECRYPTION ===
    ctx := EVP_CIPHER_CTX_new();
    if not Assigned(ctx) then
    begin
      WriteLn('  [-] Failed to create cipher context for decryption');
      Exit;
    end;
    
    try
      // Initialize decryption
      if EVP_DecryptInit_ex(ctx, cipher, nil, @TestKey[0], @TestIV[0]) <> 1 then
      begin
        WriteLn('  [-] Failed to initialize decryption');
        Exit;
      end;
      
      // Prepare output buffer
      SetLength(plaintext, Length(ciphertext) + 16);
      
      // Decrypt
      outlen := 0;
      if EVP_DecryptUpdate(ctx, @plaintext[0], outlen,
         @ciphertext[0], Length(ciphertext)) <> 1 then
      begin
        WriteLn('  [-] Failed to decrypt data');
        Exit;
      end;
      
      // Finalize decryption
      tmplen := 0;
      if EVP_DecryptFinal_ex(ctx, @plaintext[outlen], tmplen) <> 1 then
      begin
        WriteLn('  [-] Failed to finalize decryption');
        Exit;
      end;
      
      outlen := outlen + tmplen;
      SetLength(plaintext, outlen);
      
      // Verify result
      if CompareMem(@plaintext[0], PByte(TestPlaintext), Length(TestPlaintext)) then
      begin
        WriteLn('  [+] Decryption successful');
        WriteLn('      Plaintext: ', PAnsiChar(@plaintext[0]));
        success := True;
      end
      else
        WriteLn('  [-] Decryption result mismatch!');
      
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
  finally
    if success then
      WriteLn('  ✅ AES-128-CBC test PASSED')
    else
      WriteLn('  ❌ AES-128-CBC test FAILED');
  end;
  
  WriteLn;
end;

// Test AES-256-GCM encryption/decryption (AEAD)
procedure TestAES256GCM;
const
  TestKey: array[0..31] of Byte = (
    $fe, $ff, $e9, $92, $86, $65, $73, $1c, $6d, $6a, $8f, $94, $67, $30, $83, $08,
    $fe, $ff, $e9, $92, $86, $65, $73, $1c, $6d, $6a, $8f, $94, $67, $30, $83, $08
  );
  TestIV: array[0..11] of Byte = (
    $ca, $fe, $ba, $be, $fa, $ce, $db, $ad, $de, $ca, $f8, $88
  );
  TestAAD: AnsiString = 'Additional data';
  TestPlaintext: AnsiString = 'Secret message';
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  ciphertext: array of Byte;
  plaintext: array of Byte;
  tag: array[0..15] of Byte;
  outlen, tmplen: Integer;
  success: Boolean;
begin
  WriteLn('Testing AES-256-GCM Encryption/Decryption...');
  WriteLn;

  success := False;
  try
    // Check if EVP functions are loaded
    if not Assigned(EVP_aes_256_gcm) then
    begin
      WriteLn('  [-] EVP_aes_256_gcm function not loaded');
      Exit;
    end;

    // Get cipher
    cipher := EVP_aes_256_gcm();
    if not Assigned(cipher) then
    begin
      WriteLn('  [-] Failed to get AES-256-GCM cipher');
      Exit;
    end;
    WriteLn('  [+] AES-256-GCM cipher obtained');
    
    // === ENCRYPTION ===
    ctx := EVP_CIPHER_CTX_new();
    if not Assigned(ctx) then
    begin
      WriteLn('  [-] Failed to create cipher context');
      Exit;
    end;
    
    try
      // Initialize encryption
      if EVP_EncryptInit_ex(ctx, cipher, nil, @TestKey[0], @TestIV[0]) <> 1 then
      begin
        WriteLn('  [-] Failed to initialize encryption');
        Exit;
      end;
      
      // Set AAD
      if EVP_EncryptUpdate(ctx, nil, outlen, PByte(TestAAD), Length(TestAAD)) <> 1 then
      begin
        WriteLn('  [-] Failed to set AAD');
        Exit;
      end;
      
      // Prepare output buffer
      SetLength(ciphertext, Length(TestPlaintext) + 16);
      
      // Encrypt
      if EVP_EncryptUpdate(ctx, @ciphertext[0], outlen,
         PByte(TestPlaintext), Length(TestPlaintext)) <> 1 then
      begin
        WriteLn('  [-] Failed to encrypt data');
        Exit;
      end;
      
      // Finalize encryption
      if EVP_EncryptFinal_ex(ctx, @ciphertext[outlen], tmplen) <> 1 then
      begin
        WriteLn('  [-] Failed to finalize encryption');
        Exit;
      end;
      
      outlen := outlen + tmplen;
      SetLength(ciphertext, outlen);
      
      // Get authentication tag
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16, @tag[0]) <> 1 then
      begin
        WriteLn('  [-] Failed to get authentication tag');
        Exit;
      end;
      
      WriteLn('  [+] Encryption successful (', outlen, ' bytes)');
      WriteLn('      Ciphertext: ', BytesToHex(ciphertext));
      WriteLn('      Tag: ', BytesToHex(tag));
      
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
    // === DECRYPTION ===
    ctx := EVP_CIPHER_CTX_new();
    if not Assigned(ctx) then
    begin
      WriteLn('  [-] Failed to create cipher context for decryption');
      Exit;
    end;
    
    try
      // Initialize decryption
      if EVP_DecryptInit_ex(ctx, cipher, nil, @TestKey[0], @TestIV[0]) <> 1 then
      begin
        WriteLn('  [-] Failed to initialize decryption');
        Exit;
      end;
      
      // Set AAD
      if EVP_DecryptUpdate(ctx, nil, outlen, PByte(TestAAD), Length(TestAAD)) <> 1 then
      begin
        WriteLn('  [-] Failed to set AAD for decryption');
        Exit;
      end;
      
      // Prepare output buffer
      SetLength(plaintext, Length(ciphertext) + 16);
      
      // Decrypt
      if EVP_DecryptUpdate(ctx, @plaintext[0], outlen,
         @ciphertext[0], Length(ciphertext)) <> 1 then
      begin
        WriteLn('  [-] Failed to decrypt data');
        Exit;
      end;
      
      // Set expected tag
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, 16, @tag[0]) <> 1 then
      begin
        WriteLn('  [-] Failed to set tag');
        Exit;
      end;
      
      // Finalize decryption (verifies tag)
      if EVP_DecryptFinal_ex(ctx, @plaintext[outlen], tmplen) <> 1 then
      begin
        WriteLn('  [-] Failed to finalize decryption (tag verification failed)');
        Exit;
      end;
      
      outlen := outlen + tmplen;
      SetLength(plaintext, outlen);
      
      // Verify result
      if CompareMem(@plaintext[0], PByte(TestPlaintext), Length(TestPlaintext)) then
      begin
        WriteLn('  [+] Decryption successful');
        WriteLn('      Plaintext: ', PAnsiChar(@plaintext[0]));
        WriteLn('  [+] Authentication tag verified');
        success := True;
      end
      else
        WriteLn('  [-] Decryption result mismatch!');
      
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
  finally
    if success then
      WriteLn('  ✅ AES-256-GCM test PASSED')
    else
      WriteLn('  ❌ AES-256-GCM test FAILED');
  end;
  
  WriteLn;
end;

// Test ChaCha20-Poly1305 encryption/decryption
procedure TestChaCha20Poly1305;
const
  TestKey: array[0..31] of Byte = (
    $80, $81, $82, $83, $84, $85, $86, $87, $88, $89, $8a, $8b, $8c, $8d, $8e, $8f,
    $90, $91, $92, $93, $94, $95, $96, $97, $98, $99, $9a, $9b, $9c, $9d, $9e, $9f
  );
  TestIV: array[0..11] of Byte = (
    $07, $00, $00, $00, $40, $41, $42, $43, $44, $45, $46, $47
  );
  TestPlaintext: AnsiString = 'ChaCha20-Poly1305 test';
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  ciphertext: array of Byte;
  plaintext: array of Byte;
  tag: array[0..15] of Byte;
  outlen, tmplen: Integer;
  success: Boolean;
begin
  WriteLn('Testing ChaCha20-Poly1305 Encryption/Decryption...');
  WriteLn;
  
  success := False;
  try
    
    // Get cipher
    cipher := EVP_chacha20_poly1305();
    if not Assigned(cipher) then
    begin
      WriteLn('  [-] Failed to get ChaCha20-Poly1305 cipher (may not be available)');
      WriteLn('  ⚠️  ChaCha20-Poly1305 test SKIPPED');
      WriteLn;
      Exit;
    end;
    WriteLn('  [+] ChaCha20-Poly1305 cipher obtained');
    
    // === ENCRYPTION ===
    ctx := EVP_CIPHER_CTX_new();
    if not Assigned(ctx) then
    begin
      WriteLn('  [-] Failed to create cipher context');
      Exit;
    end;
    
    try
      // Initialize encryption
      if EVP_EncryptInit_ex(ctx, cipher, nil, @TestKey[0], @TestIV[0]) <> 1 then
      begin
        WriteLn('  [-] Failed to initialize encryption');
        Exit;
      end;
      
      // Prepare output buffer
      SetLength(ciphertext, Length(TestPlaintext) + 16);
      
      // Encrypt
      if EVP_EncryptUpdate(ctx, @ciphertext[0], outlen,
         PByte(TestPlaintext), Length(TestPlaintext)) <> 1 then
      begin
        WriteLn('  [-] Failed to encrypt data');
        Exit;
      end;
      
      // Finalize encryption
      if EVP_EncryptFinal_ex(ctx, @ciphertext[outlen], tmplen) <> 1 then
      begin
        WriteLn('  [-] Failed to finalize encryption');
        Exit;
      end;
      
      outlen := outlen + tmplen;
      SetLength(ciphertext, outlen);
      
      // Get authentication tag
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_GET_TAG, 16, @tag[0]) <> 1 then
      begin
        WriteLn('  [-] Failed to get authentication tag');
        Exit;
      end;
      
      WriteLn('  [+] Encryption successful (', outlen, ' bytes)');
      WriteLn('      Ciphertext: ', BytesToHex(ciphertext));
      WriteLn('      Tag: ', BytesToHex(tag));
      
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
    // === DECRYPTION ===
    ctx := EVP_CIPHER_CTX_new();
    if not Assigned(ctx) then
    begin
      WriteLn('  [-] Failed to create cipher context for decryption');
      Exit;
    end;
    
    try
      // Initialize decryption
      if EVP_DecryptInit_ex(ctx, cipher, nil, @TestKey[0], @TestIV[0]) <> 1 then
      begin
        WriteLn('  [-] Failed to initialize decryption');
        Exit;
      end;
      
      // Prepare output buffer
      SetLength(plaintext, Length(ciphertext) + 16);
      
      // Decrypt
      if EVP_DecryptUpdate(ctx, @plaintext[0], outlen,
         @ciphertext[0], Length(ciphertext)) <> 1 then
      begin
        WriteLn('  [-] Failed to decrypt data');
        Exit;
      end;
      
      // Set expected tag
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_TAG, 16, @tag[0]) <> 1 then
      begin
        WriteLn('  [-] Failed to set tag');
        Exit;
      end;
      
      // Finalize decryption (verifies tag)
      if EVP_DecryptFinal_ex(ctx, @plaintext[outlen], tmplen) <> 1 then
      begin
        WriteLn('  [-] Failed to finalize decryption (tag verification failed)');
        Exit;
      end;
      
      outlen := outlen + tmplen;
      SetLength(plaintext, outlen);
      
      // Verify result
      if CompareMem(@plaintext[0], PByte(TestPlaintext), Length(TestPlaintext)) then
      begin
        WriteLn('  [+] Decryption successful');
        WriteLn('      Plaintext: ', PAnsiChar(@plaintext[0]));
        WriteLn('  [+] Authentication tag verified');
        success := True;
      end
      else
        WriteLn('  [-] Decryption result mismatch!');
      
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
  finally
    if success then
      WriteLn('  ✅ ChaCha20-Poly1305 test PASSED')
    else if cipher = nil then
      { already printed skip message }
    else
      WriteLn('  ❌ ChaCha20-Poly1305 test FAILED');
  end;
  
  WriteLn;
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL EVP Cipher Test Suite');
  WriteLn('========================================');
  WriteLn;

  // Initialize OpenSSL
  try
    if not LoadOpenSSLLibrary then
      raise Exception.Create('LoadOpenSSLLibrary returned False');
    LoadEVP(GetCryptoLibHandle);
  except
    on E: Exception do
    begin
      WriteLn('ERROR: Failed to load OpenSSL library!');
      WriteLn('Message: ', E.Message);
      WriteLn('Make sure OpenSSL 1.1.x or 3.x is installed and accessible.');
      Halt(1);
    end;
  end;

  WriteLn('OpenSSL loaded successfully!');
  WriteLn;

  // Run tests
  TestAES128CBC;
  TestAES256GCM;
  TestChaCha20Poly1305;

  WriteLn('========================================');
  WriteLn('EVP Cipher tests completed!');
  WriteLn('========================================');
end.
