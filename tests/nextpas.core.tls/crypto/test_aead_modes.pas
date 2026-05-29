{$MODE DELPHI}{$H+}
{
  AEAD Modes Compatibility Test for OpenSSL 3.x
  
  Tests all AEAD (Authenticated Encryption with Associated Data) modes:
  - AES-GCM (Galois/Counter Mode)
  - AES-CCM (Counter with CBC-MAC)
  - AES-XTS (XEX-based tweaked-codebook mode with ciphertext stealing)
  - AES-OCB (Offset Codebook Mode)
  - ChaCha20-Poly1305
  
  This test verifies that all AEAD modes work correctly with both
  OpenSSL 1.1.1 and OpenSSL 3.x using the EVP API.
}

program test_aead_modes;

uses
  SysUtils,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.base;

function BytesToHex(const Bytes: TBytes): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(Bytes) do
    Result := Result + IntToHex(Bytes[i], 2);
end;

function HexToBytes(const Hex: string): TBytes;
var
  i: Integer;
begin
  SetLength(Result, Length(Hex) div 2);
  for i := 0 to High(Result) do
    Result[i] := StrToInt('$' + Copy(Hex, i * 2 + 1, 2));
end;

function CompareBytes(const A, B: TBytes): Boolean;
var
  i: Integer;
begin
  if Length(A) <> Length(B) then
    Exit(False);
  for i := 0 to High(A) do
    if A[i] <> B[i] then
      Exit(False);
  Result := True;
end;

procedure TestAESGCM;
var
  key, iv, plaintext, aad, ciphertext, tag, decrypted: TBytes;
  test_name: string;
begin
  test_name := 'AES-128-GCM';
  WriteLn('Testing ', test_name, '...');
  
  try
    // NIST test vector for AES-128-GCM
    key := HexToBytes('00000000000000000000000000000000');
    iv := HexToBytes('000000000000000000000000');
    plaintext := HexToBytes('00000000000000000000000000000000');
    aad := HexToBytes('');
    
    // Encrypt
    ciphertext := AES_GCM_Encrypt(key, iv, aad, plaintext, tag);
    
    WriteLn('  Plaintext:  ', BytesToHex(plaintext));
    WriteLn('  Ciphertext: ', BytesToHex(ciphertext));
    WriteLn('  Tag:        ', BytesToHex(tag));
    
    // Decrypt and verify
    decrypted := AES_GCM_Decrypt(key, iv, aad, ciphertext, tag);
    
    if CompareBytes(plaintext, decrypted) then
      WriteLn('  ✓ ', test_name, ' encrypt/decrypt: PASSED')
    else
    begin
      WriteLn('  ✗ ', test_name, ' encrypt/decrypt: FAILED');
      WriteLn('    Expected: ', BytesToHex(plaintext));
      WriteLn('    Got:      ', BytesToHex(decrypted));
    end;
    
    // Test with actual data
    plaintext := HexToBytes('00112233445566778899aabbccddeeff');
    aad := HexToBytes('feedfacedeadbeeffeedfacedeadbeef');
    
    ciphertext := AES_GCM_Encrypt(key, iv, aad, plaintext, tag);
    decrypted := AES_GCM_Decrypt(key, iv, aad, ciphertext, tag);
    
    if CompareBytes(plaintext, decrypted) then
      WriteLn('  ✓ ', test_name, ' with AAD: PASSED')
    else
      WriteLn('  ✗ ', test_name, ' with AAD: FAILED');
      
  except
    on E: Exception do
      WriteLn('  ✗ ', test_name, ' EXCEPTION: ', E.Message);
  end;
  
  WriteLn;
end;

procedure TestAES256GCM;
var
  key, iv, plaintext, aad, ciphertext, tag, decrypted: TBytes;
  test_name: string;
begin
  test_name := 'AES-256-GCM';
  WriteLn('Testing ', test_name, '...');
  
  try
    // AES-256-GCM test
    key := HexToBytes('0000000000000000000000000000000000000000000000000000000000000000');
    iv := HexToBytes('000000000000000000000000');
    plaintext := HexToBytes('00000000000000000000000000000000');
    aad := HexToBytes('');
    
    ciphertext := AES_GCM_Encrypt(key, iv, aad, plaintext, tag);
    decrypted := AES_GCM_Decrypt(key, iv, aad, ciphertext, tag);
    
    if CompareBytes(plaintext, decrypted) then
      WriteLn('  ✓ ', test_name, ': PASSED')
    else
      WriteLn('  ✗ ', test_name, ': FAILED');
      
  except
    on E: Exception do
      WriteLn('  ✗ ', test_name, ' EXCEPTION: ', E.Message);
  end;
  
  WriteLn;
end;

procedure TestAESCCM;
var
  key, nonce, plaintext, aad, ciphertext, tag, decrypted: TBytes;
  test_name: string;
begin
  test_name := 'AES-128-CCM';
  WriteLn('Testing ', test_name, '...');
  
  try
    // CCM test vector
    key := HexToBytes('404142434445464748494a4b4c4d4e4f');
    nonce := HexToBytes('10111213141516');  // 7 bytes nonce
    plaintext := HexToBytes('20212223');
    aad := HexToBytes('0001020304050607');
    
    // Encrypt with 8-byte tag
    ciphertext := AES_CCM_Encrypt(key, nonce, aad, plaintext, 8, tag);
    
    WriteLn('  Plaintext:  ', BytesToHex(plaintext));
    WriteLn('  Ciphertext: ', BytesToHex(ciphertext));
    WriteLn('  Tag:        ', BytesToHex(tag));
    
    // Decrypt and verify
    decrypted := AES_CCM_Decrypt(key, nonce, aad, ciphertext, tag);
    
    if CompareBytes(plaintext, decrypted) then
      WriteLn('  ✓ ', test_name, ': PASSED')
    else
    begin
      WriteLn('  ✗ ', test_name, ': FAILED');
      WriteLn('    Expected: ', BytesToHex(plaintext));
      WriteLn('    Got:      ', BytesToHex(decrypted));
    end;
      
  except
    on E: Exception do
      WriteLn('  ✗ ', test_name, ' EXCEPTION: ', E.Message);
  end;
  
  WriteLn;
end;

procedure TestAESXTS;
var
  key1, key2, tweak, plaintext, ciphertext, decrypted: TBytes;
  test_name: string;
begin
  test_name := 'AES-128-XTS';
  WriteLn('Testing ', test_name, '...');
  
  try
    // XTS test - used for disk encryption
    // XTS requires two keys of the same size
    key1 := HexToBytes('00000000000000000000000000000000');
    key2 := HexToBytes('00000000000000000000000000000000');
    tweak := HexToBytes('00000000000000000000000000000000'); // 16-byte tweak (sector number)
    plaintext := HexToBytes('00000000000000000000000000000000');
    
    ciphertext := AES_XTS_Encrypt(key1, key2, tweak, plaintext);
    
    WriteLn('  Plaintext:  ', BytesToHex(plaintext));
    WriteLn('  Ciphertext: ', BytesToHex(ciphertext));
    
    decrypted := AES_XTS_Decrypt(key1, key2, tweak, ciphertext);
    
    if CompareBytes(plaintext, decrypted) then
      WriteLn('  ✓ ', test_name, ': PASSED')
    else
    begin
      WriteLn('  ✗ ', test_name, ': FAILED');
      WriteLn('    Expected: ', BytesToHex(plaintext));
      WriteLn('    Got:      ', BytesToHex(decrypted));
    end;
    
    // Test with longer data
    plaintext := HexToBytes('000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f');
    ciphertext := AES_XTS_Encrypt(key1, key2, tweak, plaintext);
    decrypted := AES_XTS_Decrypt(key1, key2, tweak, ciphertext);
    
    if CompareBytes(plaintext, decrypted) then
      WriteLn('  ✓ ', test_name, ' (longer): PASSED')
    else
      WriteLn('  ✗ ', test_name, ' (longer): FAILED');
      
  except
    on E: Exception do
      WriteLn('  ✗ ', test_name, ' EXCEPTION: ', E.Message);
  end;
  
  WriteLn;
end;

procedure TestAESOCB;
var
  key, nonce, plaintext, aad, ciphertext, tag, decrypted: TBytes;
  test_name: string;
begin
  test_name := 'AES-128-OCB';
  WriteLn('Testing ', test_name, '...');
  
  try
    // OCB test vector
    key := HexToBytes('000102030405060708090A0B0C0D0E0F');
    nonce := HexToBytes('BBAA99887766554433221100');  // 12 bytes
    plaintext := HexToBytes('');  // Empty plaintext
    aad := HexToBytes('');
    
    ciphertext := AES_OCB_Encrypt(key, nonce, aad, plaintext, tag);
    
    WriteLn('  Empty plaintext test');
    WriteLn('  Tag: ', BytesToHex(tag));
    
    decrypted := AES_OCB_Decrypt(key, nonce, aad, ciphertext, tag);
    
    if CompareBytes(plaintext, decrypted) then
      WriteLn('  ✓ ', test_name, ' (empty): PASSED')
    else
      WriteLn('  ✗ ', test_name, ' (empty): FAILED');
    
    // Test with actual data
    plaintext := HexToBytes('000102030405060708090A0B0C0D0E0F');
    aad := HexToBytes('0001020304050607');
    
    ciphertext := AES_OCB_Encrypt(key, nonce, aad, plaintext, tag);
    decrypted := AES_OCB_Decrypt(key, nonce, aad, ciphertext, tag);
    
    if CompareBytes(plaintext, decrypted) then
      WriteLn('  ✓ ', test_name, ' with AAD: PASSED')
    else
      WriteLn('  ✗ ', test_name, ' with AAD: FAILED');
      
  except
    on E: Exception do
      WriteLn('  ✗ ', test_name, ' EXCEPTION: ', E.Message);
  end;
  
  WriteLn;
end;

procedure TestChaCha20Poly1305;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  key, nonce, plaintext, aad, ciphertext, tag, decrypted: TBytes;
  outlen, finlen: Integer;
  test_name: string;
begin
  test_name := 'ChaCha20-Poly1305';
  WriteLn('Testing ', test_name, '...');
  
  try
    // Load ChaCha functions
    if not LoadChaChaFunctions then
    begin
      WriteLn('  ✗ ', test_name, ': Failed to load ChaCha functions');
      WriteLn;
      Exit;
    end;
    
    if not Assigned(EVP_chacha20_poly1305) then
    begin
      WriteLn('  ⚠ ', test_name, ': Not available in this OpenSSL version');
      WriteLn;
      Exit;
    end;
    
    // RFC 8439 test vector
    key := HexToBytes('808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f');
    nonce := HexToBytes('070000004041424344454647');  // 12 bytes
    plaintext := HexToBytes('4c616469657320616e642047656e746c656d656e206f662074686520636c617373206f66202739393a204966204920636f756c64206f6666657220796f75206f6e6c79206f6e652074697020666f7220746865206675747572652c2073756e73637265656e20776f756c642062652069742e');
    aad := HexToBytes('50515253c0c1c2c3c4c5c6c7');
    
    SetLength(ciphertext, Length(plaintext));
    SetLength(tag, 16);
    
    // Encrypt
    cipher := EVP_chacha20_poly1305();
    ctx := EVP_CIPHER_CTX_new();
    try
      if EVP_EncryptInit_ex(ctx, cipher, nil, @key[0], @nonce[0]) <> 1 then
        raise Exception.Create('Failed to initialize ChaCha20-Poly1305');
      
      // Process AAD
      if Length(aad) > 0 then
      begin
        if EVP_EncryptUpdate(ctx, nil, @outlen, @aad[0], Length(aad)) <> 1 then
          raise Exception.Create('Failed to process AAD');
      end;
      
      // Encrypt plaintext
      if EVP_EncryptUpdate(ctx, @ciphertext[0], @outlen, @plaintext[0], Length(plaintext)) <> 1 then
        raise Exception.Create('Failed to encrypt');
      
      // Finalize
      if EVP_EncryptFinal_ex(ctx, @ciphertext[outlen], @finlen) <> 1 then
        raise Exception.Create('Failed to finalize encryption');
      
      SetLength(ciphertext, outlen + finlen);
      
      // Get tag
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_GET_TAG, 16, @tag[0]) <> 1 then
        raise Exception.Create('Failed to get tag');
      
      WriteLn('  Ciphertext (first 32 bytes): ', BytesToHex(Copy(ciphertext, 0, 32)));
      WriteLn('  Tag: ', BytesToHex(tag));
      
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
    // Decrypt
    SetLength(decrypted, Length(ciphertext));
    ctx := EVP_CIPHER_CTX_new();
    try
      if EVP_DecryptInit_ex(ctx, cipher, nil, @key[0], @nonce[0]) <> 1 then
        raise Exception.Create('Failed to initialize decryption');
      
      // Process AAD
      if Length(aad) > 0 then
      begin
        if EVP_DecryptUpdate(ctx, nil, @outlen, @aad[0], Length(aad)) <> 1 then
          raise Exception.Create('Failed to process AAD');
      end;
      
      // Decrypt
      if EVP_DecryptUpdate(ctx, @decrypted[0], @outlen, @ciphertext[0], Length(ciphertext)) <> 1 then
        raise Exception.Create('Failed to decrypt');
      
      // Set expected tag
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_TAG, 16, @tag[0]) <> 1 then
        raise Exception.Create('Failed to set tag');
      
      // Verify and finalize
      if EVP_DecryptFinal_ex(ctx, @decrypted[outlen], @finlen) <> 1 then
        raise Exception.Create('Authentication verification failed');
      
      SetLength(decrypted, outlen + finlen);
      
      if CompareBytes(plaintext, decrypted) then
        WriteLn('  ✓ ', test_name, ': PASSED')
      else
        WriteLn('  ✗ ', test_name, ': FAILED');
        
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
  except
    on E: Exception do
      WriteLn('  ✗ ', test_name, ' EXCEPTION: ', E.Message);
  end;
  
  WriteLn;
end;

procedure CheckOpenSSLVersion;
var
  version: Cardinal;
  version_str: string;
begin
  WriteLn('========================================');
  WriteLn('OpenSSL AEAD Modes Compatibility Test');
  WriteLn('========================================');
  WriteLn;
  
  if not LoadOpenSSL then
  begin
    WriteLn('ERROR: Failed to load OpenSSL library');
    Halt(1);
  end;
  
  version := OpenSSL_version_num();
  version_str := OpenSSL_version_text();
  
  WriteLn('OpenSSL Version: ', version_str);
  WriteLn('Version Number:  0x', IntToHex(version, 8));
  
  if (version >= $30000000) then
    WriteLn('Detected: OpenSSL 3.x')
  else if (version >= $10101000) then
    WriteLn('Detected: OpenSSL 1.1.1')
  else
    WriteLn('Detected: Older OpenSSL version');
    
  WriteLn;
  WriteLn('----------------------------------------');
  WriteLn;
end;

var
  TestsPassed, TestsFailed: Integer;

begin
  TestsPassed := 0;
  TestsFailed := 0;
  
  CheckOpenSSLVersion;
  
  // Load required modules
  WriteLn('Loading OpenSSL modules...');
  if not LoadEVPFunctions then
    WriteLn('  ⚠ Warning: Some EVP functions may not be available');
  if not LoadAESFunctions then
    WriteLn('  ⚠ Warning: Some AES functions may not be available');
  if not LoadModesFunctions then
    WriteLn('  ⚠ Warning: Some MODES functions may not be available');
  WriteLn;
  
  WriteLn('========================================');
  WriteLn('Running AEAD Mode Tests');
  WriteLn('========================================');
  WriteLn;
  
  // Test all AEAD modes
  TestAESGCM;
  TestAES256GCM;
  TestAESCCM;
  TestAESXTS;
  TestAESOCB;
  TestChaCha20Poly1305;
  
  WriteLn('========================================');
  WriteLn('Test Summary');
  WriteLn('========================================');
  WriteLn;
  WriteLn('All AEAD modes have been tested.');
  WriteLn('Check the output above for individual test results.');
  WriteLn;
  WriteLn('Note: Some modes (like OCB) may not be available in all');
  WriteLn('      OpenSSL builds due to patent restrictions.');
  WriteLn;
  
  WriteLn('Press Enter to exit...');
  ReadLn;
end.
