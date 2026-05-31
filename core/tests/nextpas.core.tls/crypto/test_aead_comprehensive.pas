program test_aead_comprehensive;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils,
  nextpas.core.tls.openssl.api;

type
  TTestResult = record
    Name: string;
    Success: Boolean;
    ErrorMsg: string;
  end;

var
  Results: array of TTestResult;
  TotalTests, PassedTests: Integer;

procedure AddResult(const AName: string; ASuccess: Boolean; const AError: string = '');
begin
  SetLength(Results, Length(Results) + 1);
  Results[High(Results)].Name := AName;
  Results[High(Results)].Success := ASuccess;
  Results[High(Results)].ErrorMsg := AError;
  Inc(TotalTests);
  if ASuccess then
    Inc(PassedTests);
end;

function BytesToHex(const Data: array of Byte; Len: Integer): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to Len - 1 do
    Result := Result + IntToHex(Data[i], 2);
end;

procedure PrintSeparator;
begin
  WriteLn('========================================');
end;

procedure PrintResults;
var
  i: Integer;
begin
  WriteLn;
  PrintSeparator;
  WriteLn('Test Results Summary');
  PrintSeparator;
  WriteLn;
  
  for i := 0 to High(Results) do
  begin
    if Results[i].Success then
      WriteLn('  [PASS] ', Results[i].Name)
    else
    begin
      WriteLn('  [FAIL] ', Results[i].Name);
      if Results[i].ErrorMsg <> '' then
        WriteLn('         Error: ', Results[i].ErrorMsg);
    end;
  end;
  
  WriteLn;
  PrintSeparator;
  WriteLn(Format('Total: %d tests, %d passed, %d failed (%.1f%%)',
    [TotalTests, PassedTests, TotalTests - PassedTests,
     (PassedTests / TotalTests) * 100]));
  PrintSeparator;
end;

// Test AES-256-GCM AEAD encryption
procedure TestAES256GCM;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  key: array[0..31] of Byte;  // 256-bit key
  iv: array[0..11] of Byte;   // 96-bit IV (recommended for GCM)
  plaintext: array[0..31] of Byte;
  aad: array[0..15] of Byte;  // Additional Authenticated Data
  ciphertext: array[0..63] of Byte;
  tag: array[0..15] of Byte;  // 128-bit authentication tag
  decrypted: array[0..63] of Byte;
  len, ciphertext_len, decrypted_len: Integer;
  i: Integer;
  success: Boolean;
begin
  WriteLn;
  WriteLn('Testing AES-256-GCM AEAD...');
  success := False;
  
  try
    // Initialize test data
    for i := 0 to 31 do key[i] := Byte(i);
    for i := 0 to 11 do iv[i] := Byte(i);
    for i := 0 to 31 do plaintext[i] := Byte($41 + (i mod 26)); // 'A'..'Z'
    for i := 0 to 15 do aad[i] := Byte($30 + (i mod 10)); // '0'..'9'
    
    // Get cipher
    cipher := EVP_aes_256_gcm();
    if cipher = nil then
    begin
      AddResult('AES-256-GCM: Get cipher', False, 'EVP_aes_256_gcm returned nil');
      Exit;
    end;
    WriteLn('  [+] Cipher obtained: AES-256-GCM');
    
    // === ENCRYPTION ===
    ctx := EVP_CIPHER_CTX_new();
    if ctx = nil then
    begin
      AddResult('AES-256-GCM: Encryption context', False, 'Context creation failed');
      Exit;
    end;
    
    try
      // Initialize encryption
      if EVP_EncryptInit_ex(ctx, cipher, nil, nil, nil) <> 1 then
      begin
        AddResult('AES-256-GCM: Encrypt init', False, 'Init failed');
        Exit;
      end;
      
      // Set IV length (GCM mode)
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, 12, nil) <> 1 then
      begin
        AddResult('AES-256-GCM: Set IV length', False, 'IV length set failed');
        Exit;
      end;
      
      // Initialize key and IV
      if EVP_EncryptInit_ex(ctx, nil, nil, @key[0], @iv[0]) <> 1 then
      begin
        AddResult('AES-256-GCM: Set key/IV', False, 'Key/IV set failed');
        Exit;
      end;
      
      // Add AAD (Additional Authenticated Data)
      if EVP_EncryptUpdate(ctx, nil, @len, @aad[0], 16) <> 1 then
      begin
        AddResult('AES-256-GCM: Add AAD', False, 'AAD addition failed');
        Exit;
      end;
      WriteLn('  [+] AAD added: ', BytesToHex(aad, 16));
      
      // Encrypt plaintext
      if EVP_EncryptUpdate(ctx, @ciphertext[0], @len, @plaintext[0], 32) <> 1 then
      begin
        AddResult('AES-256-GCM: Encrypt update', False, 'Encryption failed');
        Exit;
      end;
      ciphertext_len := len;
      
      // Finalize encryption
      if EVP_EncryptFinal_ex(ctx, @ciphertext[ciphertext_len], @len) <> 1 then
      begin
        AddResult('AES-256-GCM: Encrypt final', False, 'Finalization failed');
        Exit;
      end;
      ciphertext_len := ciphertext_len + len;
      
      // Get authentication tag
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16, @tag[0]) <> 1 then
      begin
        AddResult('AES-256-GCM: Get tag', False, 'Tag retrieval failed');
        Exit;
      end;
      
      WriteLn('  [+] Encrypted ', ciphertext_len, ' bytes');
      WriteLn('      Ciphertext: ', BytesToHex(ciphertext, ciphertext_len));
      WriteLn('      Auth Tag:   ', BytesToHex(tag, 16));
      
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
    // === DECRYPTION ===
    ctx := EVP_CIPHER_CTX_new();
    if ctx = nil then
    begin
      AddResult('AES-256-GCM: Decryption context', False, 'Context creation failed');
      Exit;
    end;
    
    try
      // Initialize decryption
      if EVP_DecryptInit_ex(ctx, cipher, nil, nil, nil) <> 1 then
      begin
        AddResult('AES-256-GCM: Decrypt init', False, 'Init failed');
        Exit;
      end;
      
      // Set IV length
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, 12, nil) <> 1 then
      begin
        AddResult('AES-256-GCM: Set IV length (decrypt)', False, 'IV length set failed');
        Exit;
      end;
      
      // Initialize key and IV
      if EVP_DecryptInit_ex(ctx, nil, nil, @key[0], @iv[0]) <> 1 then
      begin
        AddResult('AES-256-GCM: Set key/IV (decrypt)', False, 'Key/IV set failed');
        Exit;
      end;
      
      // Add AAD
      if EVP_DecryptUpdate(ctx, nil, @len, @aad[0], 16) <> 1 then
      begin
        AddResult('AES-256-GCM: Add AAD (decrypt)', False, 'AAD addition failed');
        Exit;
      end;
      
      // Decrypt ciphertext
      if EVP_DecryptUpdate(ctx, @decrypted[0], @len, @ciphertext[0], ciphertext_len) <> 1 then
      begin
        AddResult('AES-256-GCM: Decrypt update', False, 'Decryption failed');
        Exit;
      end;
      decrypted_len := len;
      
      // Set expected tag
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, 16, @tag[0]) <> 1 then
      begin
        AddResult('AES-256-GCM: Set tag', False, 'Tag set failed');
        Exit;
      end;
      
      // Finalize decryption (this verifies the tag)
      if EVP_DecryptFinal_ex(ctx, @decrypted[decrypted_len], @len) <> 1 then
      begin
        AddResult('AES-256-GCM: Authentication', False, 'Tag verification failed');
        Exit;
      end;
      decrypted_len := decrypted_len + len;
      
      WriteLn('  [+] Decrypted ', decrypted_len, ' bytes');
      WriteLn('      Plaintext:  ', BytesToHex(decrypted, decrypted_len));
      WriteLn('  [+] Authentication tag verified!');
      
      // Verify data integrity
      success := True;
      for i := 0 to 31 do
      begin
        if decrypted[i] <> plaintext[i] then
        begin
          success := False;
          Break;
        end;
      end;
      
      if success then
      begin
        WriteLn('  [PASS] Data integrity verified!');
        AddResult('AES-256-GCM: Full cycle', True);
      end
      else
      begin
        WriteLn('  [FAIL] Data mismatch!');
        AddResult('AES-256-GCM: Data integrity', False, 'Decrypted data does not match');
      end;
      
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
  except
    on E: Exception do
      AddResult('AES-256-GCM: Exception', False, E.Message);
  end;
end;

// Test ChaCha20-Poly1305 AEAD encryption
procedure TestChaCha20Poly1305;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  key: array[0..31] of Byte;  // 256-bit key
  iv: array[0..11] of Byte;   // 96-bit IV
  plaintext: array[0..47] of Byte;
  aad: array[0..23] of Byte;
  ciphertext: array[0..63] of Byte;
  tag: array[0..15] of Byte;  // 128-bit tag
  decrypted: array[0..63] of Byte;
  len, ciphertext_len, decrypted_len: Integer;
  i: Integer;
  success: Boolean;
begin
  WriteLn;
  WriteLn('Testing ChaCha20-Poly1305 AEAD...');
  success := False;
  
  try
    // Initialize test data
    for i := 0 to 31 do key[i] := Byte($FF - i);
    for i := 0 to 11 do iv[i] := Byte($AA xor i);
    for i := 0 to 47 do plaintext[i] := Byte($61 + (i mod 26)); // 'a'..'z'
    for i := 0 to 23 do aad[i] := Byte(i * 7 mod 256);
    
    // Get cipher
    cipher := EVP_chacha20_poly1305();
    if cipher = nil then
    begin
      AddResult('ChaCha20-Poly1305: Get cipher', False, 'Cipher not available');
      Exit;
    end;
    WriteLn('  [+] Cipher obtained: ChaCha20-Poly1305');
    
    // === ENCRYPTION ===
    ctx := EVP_CIPHER_CTX_new();
    if ctx = nil then
    begin
      AddResult('ChaCha20-Poly1305: Encryption context', False, 'Context creation failed');
      Exit;
    end;
    
    try
      // Initialize encryption
      if EVP_EncryptInit_ex(ctx, cipher, nil, @key[0], @iv[0]) <> 1 then
      begin
        AddResult('ChaCha20-Poly1305: Encrypt init', False, 'Init failed');
        Exit;
      end;
      
      // Add AAD
      if EVP_EncryptUpdate(ctx, nil, @len, @aad[0], 24) <> 1 then
      begin
        AddResult('ChaCha20-Poly1305: Add AAD', False, 'AAD addition failed');
        Exit;
      end;
      WriteLn('  [+] AAD added: ', BytesToHex(aad, 24));
      
      // Encrypt plaintext
      if EVP_EncryptUpdate(ctx, @ciphertext[0], @len, @plaintext[0], 48) <> 1 then
      begin
        AddResult('ChaCha20-Poly1305: Encrypt update', False, 'Encryption failed');
        Exit;
      end;
      ciphertext_len := len;
      
      // Finalize encryption
      if EVP_EncryptFinal_ex(ctx, @ciphertext[ciphertext_len], @len) <> 1 then
      begin
        AddResult('ChaCha20-Poly1305: Encrypt final', False, 'Finalization failed');
        Exit;
      end;
      ciphertext_len := ciphertext_len + len;
      
      // Get authentication tag
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_GET_TAG, 16, @tag[0]) <> 1 then
      begin
        AddResult('ChaCha20-Poly1305: Get tag', False, 'Tag retrieval failed');
        Exit;
      end;
      
      WriteLn('  [+] Encrypted ', ciphertext_len, ' bytes');
      WriteLn('      Ciphertext: ', BytesToHex(ciphertext, ciphertext_len));
      WriteLn('      Auth Tag:   ', BytesToHex(tag, 16));
      
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
    // === DECRYPTION ===
    ctx := EVP_CIPHER_CTX_new();
    if ctx = nil then
    begin
      AddResult('ChaCha20-Poly1305: Decryption context', False, 'Context creation failed');
      Exit;
    end;
    
    try
      // Initialize decryption
      if EVP_DecryptInit_ex(ctx, cipher, nil, @key[0], @iv[0]) <> 1 then
      begin
        AddResult('ChaCha20-Poly1305: Decrypt init', False, 'Init failed');
        Exit;
      end;
      
      // Add AAD
      if EVP_DecryptUpdate(ctx, nil, @len, @aad[0], 24) <> 1 then
      begin
        AddResult('ChaCha20-Poly1305: Add AAD (decrypt)', False, 'AAD addition failed');
        Exit;
      end;
      
      // Decrypt ciphertext
      if EVP_DecryptUpdate(ctx, @decrypted[0], @len, @ciphertext[0], ciphertext_len) <> 1 then
      begin
        AddResult('ChaCha20-Poly1305: Decrypt update', False, 'Decryption failed');
        Exit;
      end;
      decrypted_len := len;
      
      // Set expected tag
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_TAG, 16, @tag[0]) <> 1 then
      begin
        AddResult('ChaCha20-Poly1305: Set tag', False, 'Tag set failed');
        Exit;
      end;
      
      // Finalize decryption (verifies tag)
      if EVP_DecryptFinal_ex(ctx, @decrypted[decrypted_len], @len) <> 1 then
      begin
        AddResult('ChaCha20-Poly1305: Authentication', False, 'Tag verification failed');
        Exit;
      end;
      decrypted_len := decrypted_len + len;
      
      WriteLn('  [+] Decrypted ', decrypted_len, ' bytes');
      WriteLn('      Plaintext:  ', BytesToHex(decrypted, decrypted_len));
      WriteLn('  [+] Authentication tag verified!');
      
      // Verify data integrity
      success := True;
      for i := 0 to 47 do
      begin
        if decrypted[i] <> plaintext[i] then
        begin
          success := False;
          Break;
        end;
      end;
      
      if success then
      begin
        WriteLn('  [PASS] Data integrity verified!');
        AddResult('ChaCha20-Poly1305: Full cycle', True);
      end
      else
      begin
        WriteLn('  [FAIL] Data mismatch!');
        AddResult('ChaCha20-Poly1305: Data integrity', False, 'Decrypted data does not match');
      end;
      
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
  except
    on E: Exception do
      AddResult('ChaCha20-Poly1305: Exception', False, E.Message);
  end;
end;

// Test tampering detection
procedure TestTamperingDetection;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  key: array[0..31] of Byte;
  iv: array[0..11] of Byte;
  plaintext: array[0..15] of Byte;
  ciphertext: array[0..31] of Byte;
  tag: array[0..15] of Byte;
  decrypted: array[0..31] of Byte;
  len, ciphertext_len: Integer;
  i: Integer;
begin
  WriteLn;
  WriteLn('Testing tampering detection...');
  
  try
    // Initialize test data
    for i := 0 to 31 do key[i] := Byte(i * 3 mod 256);
    for i := 0 to 11 do iv[i] := Byte(i * 5 mod 256);
    for i := 0 to 15 do plaintext[i] := Byte($30 + i);
    
    cipher := EVP_aes_256_gcm();
    if cipher = nil then
    begin
      AddResult('Tampering: Get cipher', False, 'Cipher unavailable');
      Exit;
    end;
    
    // Encrypt
    ctx := EVP_CIPHER_CTX_new();
    if ctx = nil then Exit;
    
    try
      EVP_EncryptInit_ex(ctx, cipher, nil, nil, nil);
      EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, 12, nil);
      EVP_EncryptInit_ex(ctx, nil, nil, @key[0], @iv[0]);
      EVP_EncryptUpdate(ctx, @ciphertext[0], @len, @plaintext[0], 16);
      ciphertext_len := len;
      EVP_EncryptFinal_ex(ctx, @ciphertext[ciphertext_len], @len);
      ciphertext_len := ciphertext_len + len;
      EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16, @tag[0]);
      
      WriteLn('  [+] Original encrypted successfully');
      WriteLn('      Ciphertext: ', BytesToHex(ciphertext, ciphertext_len));
      WriteLn('      Tag:        ', BytesToHex(tag, 16));
      
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
    // Tamper with ciphertext
    ciphertext[0] := ciphertext[0] xor $FF;
    WriteLn('  [+] Tampered with ciphertext (flipped first byte)');
    WriteLn('      Tampered:   ', BytesToHex(ciphertext, ciphertext_len));
    
    // Try to decrypt (should fail authentication)
    ctx := EVP_CIPHER_CTX_new();
    if ctx = nil then Exit;
    
    try
      EVP_DecryptInit_ex(ctx, cipher, nil, nil, nil);
      EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, 12, nil);
      EVP_DecryptInit_ex(ctx, nil, nil, @key[0], @iv[0]);
      EVP_DecryptUpdate(ctx, @decrypted[0], @len, @ciphertext[0], ciphertext_len);
      EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, 16, @tag[0]);
      
      // This should fail
      if EVP_DecryptFinal_ex(ctx, @decrypted[len], @i) = 1 then
      begin
        WriteLn('  [FAIL] Tampering not detected!');
        AddResult('Tampering: Detection', False, 'Tampered data was accepted');
      end
      else
      begin
        WriteLn('  [PASS] Tampering detected successfully!');
        AddResult('Tampering: Detection', True);
      end;
      
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
  except
    on E: Exception do
      AddResult('Tampering: Exception', False, E.Message);
  end;
end;

begin
  TotalTests := 0;
  PassedTests := 0;
  SetLength(Results, 0);
  
  PrintSeparator;
  WriteLn('AEAD Comprehensive Test Suite');
  WriteLn('OpenSSL EVP API - Pascal Binding');
  PrintSeparator;
  
  // Load OpenSSL
  try
    if not LoadOpenSSLLibrary then
    begin
      WriteLn('ERROR: Failed to load OpenSSL library!');
      Halt(1);
    end;
    WriteLn('OpenSSL library loaded successfully');
    if Assigned(OPENSSL_version) then
      WriteLn('Version: ', OPENSSL_version(0))
    else
      WriteLn('Version: Unknown');
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.Message);
      Halt(1);
    end;
  end;
  
  // Run tests
  TestAES256GCM;
  TestChaCha20Poly1305;
  TestTamperingDetection;
  
  // Print summary
  PrintResults;
  
  // Cleanup
  UnloadOpenSSLLibrary;
  
  // Exit with appropriate code
  if PassedTests = TotalTests then
    Halt(0)
  else
    Halt(1);
end.
