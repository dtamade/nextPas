program test_minimal_aes;

{$mode objfpc}{$H+}

{
  最小化AES测试 - 逐步调试
  直接复制test_evp_cipher的可工作模式
}

uses
  SysUtils,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.evp;

var
  LCtx: PEVP_CIPHER_CTX;
  LCipher: PEVP_CIPHER;
  LKey: array[0..31] of Byte;
  LIV: array[0..11] of Byte;
  LData: array[0..13] of Byte;  // "Hello, World!" = 13 bytes
  LCiphertext: array[0..100] of Byte;
  LOutLen: Integer;
  I: Integer;
begin
  WriteLn('=== Minimal AES-GCM Test ===');
  WriteLn;
  
  try
    // Step 1: Initialize OpenSSL
    WriteLn('[1] Loading OpenSSL...');
    LoadOpenSSLCore();
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      WriteLn('✗ Failed to load OpenSSL');
      Halt(1);
    end;
    WriteLn('✓ OpenSSL Core loaded: ', GetOpenSSLVersionString);
    
    WriteLn('[1.5] Loading EVP module...');
    LoadEVP(GetCryptoLibHandle);
    WriteLn('✓ EVP module loaded');
    WriteLn;
    
    // Step 2: Prepare test data
    WriteLn('[2] Preparing test data...');
    FillChar(LKey, SizeOf(LKey), $AA);      // Simple key
    FillChar(LIV, SizeOf(LIV), $BB);        // Simple IV
    Move('Hello, World!'[1], LData[0], 13); // Plaintext
    WriteLn('✓ Key, IV, and data prepared');
    WriteLn;
    
    // Step 3: Get cipher
    WriteLn('[3] Getting AES-256-GCM cipher...');
    LCipher := EVP_aes_256_gcm();
    if LCipher = nil then
    begin
      WriteLn('✗ EVP_aes_256_gcm() returned nil');
      Halt(1);
    end;
    WriteLn('✓ Cipher obtained: ', PtrUInt(LCipher));
    WriteLn;
    
    // Step 4: Create context
    WriteLn('[4] Creating cipher context...');
    LCtx := EVP_CIPHER_CTX_new();
    if LCtx = nil then
    begin
      WriteLn('✗ EVP_CIPHER_CTX_new() returned nil');
      Halt(1);
    end;
    WriteLn('✓ Context created: ', PtrUInt(LCtx));
    WriteLn;
    
    try
      // Step 5: Initialize encryption
      WriteLn('[5] Initializing encryption...');
      if EVP_EncryptInit_ex(LCtx, LCipher, nil, @LKey[0], @LIV[0]) <> 1 then
      begin
        WriteLn('✗ EVP_EncryptInit_ex() failed');
        Halt(1);
      end;
      WriteLn('✓ Encryption initialized');
      WriteLn;
      
      // Step 6: Encrypt data
      WriteLn('[6] Encrypting data...');
      LOutLen := 0;
      if EVP_EncryptUpdate(LCtx, @LCiphertext[0], LOutLen, @LData[0], 13) <> 1 then
      begin
        WriteLn('✗ EVP_EncryptUpdate() failed');
        Halt(1);
      end;
      WriteLn('✓ Encrypted ', LOutLen, ' bytes');
      
      // Print ciphertext
      Write('  Ciphertext: ');
      for I := 0 to LOutLen - 1 do
        Write(IntToHex(LCiphertext[I], 2));
      WriteLn;
      WriteLn;
      
      WriteLn('========================================');
      WriteLn('✓ SUCCESS! AES-GCM encryption works!');
      WriteLn('========================================');
      
    finally
      EVP_CIPHER_CTX_free(LCtx);
      WriteLn;
      WriteLn('Context freed');
    end;
    
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('========================================');
      WriteLn('✗ EXCEPTION: ', E.ClassName, ': ', E.Message);
      WriteLn('========================================');
      Halt(1);
    end;
  end;
  
  WriteLn;
  WriteLn('Press Enter...');
  ReadLn;
end.
