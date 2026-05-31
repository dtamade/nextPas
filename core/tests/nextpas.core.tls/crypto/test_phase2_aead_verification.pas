program test_phase2_aead_verification;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.evp;

type
  TTestResult = record
    ModeName: string;
    TestName: string;
    Success: Boolean;
    ErrorMsg: string;
  end;

var
  Results: array of TTestResult;
  TotalTests, PassedTests, FailedTests: Integer;

procedure AddResult(const AMode, ATest: string; ASuccess: Boolean; const AError: string = '');
begin
  SetLength(Results, Length(Results) + 1);
  Results[High(Results)].ModeName := AMode;
  Results[High(Results)].TestName := ATest;
  Results[High(Results)].Success := ASuccess;
  Results[High(Results)].ErrorMsg := AError;
  Inc(TotalTests);
  if ASuccess then
    Inc(PassedTests)
  else
    Inc(FailedTests);
end;

function BytesToHex(const Data; Len: Integer): string;
var
  i: Integer;
  p: PByte;
begin
  Result := '';
  p := @Data;
  for i := 0 to Len - 1 do
  begin
    Result := Result + IntToHex(p^, 2);
    Inc(p);
  end;
end;

function BytesEqual(const A, B; Len: Integer): Boolean;
var
  i: Integer;
  pA, pB: PByte;
begin
  pA := @A;
  pB := @B;
  Result := True;
  for i := 0 to Len - 1 do
  begin
    if pA^ <> pB^ then
    begin
      Result := False;
      Exit;
    end;
    Inc(pA);
    Inc(pB);
  end;
end;

procedure PrintSeparator(c: Char = '=');
begin
  WriteLn(StringOfChar(c, 70));
end;

// ============================================================================
// GCM MODE TESTS
// ============================================================================

function TestGCMBasic: Boolean;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  key: array[0..31] of Byte;  // AES-256
  iv: array[0..11] of Byte;   // 96-bit IV
  plaintext: array[0..31] of Byte;
  aad: array[0..15] of Byte;
  ciphertext: array[0..63] of Byte;
  tag: array[0..15] of Byte;
  decrypted: array[0..63] of Byte;
  len, ct_len, pt_len: Integer;
  i: Integer;
begin
  Result := False;
  WriteLn('  Testing GCM basic encrypt/decrypt...');
  
  try
    // Initialize test data
    for i := 0 to 31 do key[i] := Byte(i);
    for i := 0 to 11 do iv[i] := Byte(i);
    for i := 0 to 31 do plaintext[i] := Byte($41 + (i mod 26));
    for i := 0 to 15 do aad[i] := Byte($30 + (i mod 10));
    
    // Get cipher
    cipher := EVP_aes_256_gcm();
    if cipher = nil then
    begin
      AddResult('GCM', 'Get cipher', False, 'EVP_aes_256_gcm returned nil');
      Exit;
    end;
    
    // ENCRYPTION
    ctx := EVP_CIPHER_CTX_new();
    if ctx = nil then
    begin
      AddResult('GCM', 'Create encrypt context', False, 'Context creation failed');
      Exit;
    end;
    
    try
      if EVP_EncryptInit_ex(ctx, cipher, nil, nil, nil) <> 1 then
      begin
        AddResult('GCM', 'Init encryption', False);
        Exit;
      end;
      
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, 12, nil) <> 1 then
      begin
        AddResult('GCM', 'Set IV length', False);
        Exit;
      end;
      
      if EVP_EncryptInit_ex(ctx, nil, nil, @key[0], @iv[0]) <> 1 then
      begin
        AddResult('GCM', 'Set key/IV', False);
        Exit;
      end;
      
      if EVP_EncryptUpdate(ctx, nil, len, @aad[0], 16) <> 1 then
      begin
        AddResult('GCM', 'Add AAD', False);
        Exit;
      end;
      
      if EVP_EncryptUpdate(ctx, @ciphertext[0], len, @plaintext[0], 32) <> 1 then
      begin
        AddResult('GCM', 'Encrypt data', False);
        Exit;
      end;
      ct_len := len;
      
      if EVP_EncryptFinal_ex(ctx, @ciphertext[ct_len], len) <> 1 then
      begin
        AddResult('GCM', 'Finalize encrypt', False);
        Exit;
      end;
      ct_len := ct_len + len;
      
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16, @tag[0]) <> 1 then
      begin
        AddResult('GCM', 'Get tag', False);
        Exit;
      end;
      
      WriteLn('    Encrypted: ', ct_len, ' bytes, Tag: ', BytesToHex(tag, 16));
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
    // DECRYPTION
    ctx := EVP_CIPHER_CTX_new();
    if ctx = nil then
    begin
      AddResult('GCM', 'Create decrypt context', False);
      Exit;
    end;
    
    try
      if EVP_DecryptInit_ex(ctx, cipher, nil, nil, nil) <> 1 then
      begin
        AddResult('GCM', 'Init decryption', False);
        Exit;
      end;
      
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, 12, nil) <> 1 then
      begin
        AddResult('GCM', 'Set IV length (decrypt)', False);
        Exit;
      end;
      
      if EVP_DecryptInit_ex(ctx, nil, nil, @key[0], @iv[0]) <> 1 then
      begin
        AddResult('GCM', 'Set key/IV (decrypt)', False);
        Exit;
      end;
      
      if EVP_DecryptUpdate(ctx, nil, len, @aad[0], 16) <> 1 then
      begin
        AddResult('GCM', 'Add AAD (decrypt)', False);
        Exit;
      end;
      
      if EVP_DecryptUpdate(ctx, @decrypted[0], len, @ciphertext[0], ct_len) <> 1 then
      begin
        AddResult('GCM', 'Decrypt data', False);
        Exit;
      end;
      pt_len := len;
      
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, 16, @tag[0]) <> 1 then
      begin
        AddResult('GCM', 'Set tag (decrypt)', False);
        Exit;
      end;
      
      if EVP_DecryptFinal_ex(ctx, @decrypted[pt_len], len) <> 1 then
      begin
        AddResult('GCM', 'Verify tag', False, 'Authentication failed');
        Exit;
      end;
      pt_len := pt_len + len;
      
      if not BytesEqual(plaintext, decrypted, 32) then
      begin
        AddResult('GCM', 'Verify plaintext', False, 'Plaintext mismatch');
        Exit;
      end;
      
      WriteLn('    Decrypted: ', pt_len, ' bytes - VERIFIED');
      AddResult('GCM', 'Basic encrypt/decrypt', True);
      Result := True;
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
  except
    on E: Exception do
      AddResult('GCM', 'Basic test', False, E.Message);
  end;
end;

// ============================================================================
// CCM MODE TESTS
// ============================================================================

function TestCCMBasic: Boolean;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  key: array[0..15] of Byte;  // AES-128
  nonce: array[0..11] of Byte;
  plaintext: array[0..31] of Byte;
  aad: array[0..15] of Byte;
  ciphertext: array[0..63] of Byte;
  tag: array[0..15] of Byte;
  decrypted: array[0..63] of Byte;
  len, ct_len, pt_len: Integer;
  i: Integer;
begin
  Result := False;
  WriteLn('  Testing CCM basic encrypt/decrypt...');
  
  try
    // Initialize test data
    for i := 0 to 15 do key[i] := Byte(i);
    for i := 0 to 11 do nonce[i] := Byte(i);
    for i := 0 to 31 do plaintext[i] := Byte($41 + (i mod 26));
    for i := 0 to 15 do aad[i] := Byte($30 + (i mod 10));
    
    // Get cipher
    cipher := EVP_aes_128_ccm();
    if cipher = nil then
    begin
      AddResult('CCM', 'Get cipher', False, 'EVP_aes_128_ccm returned nil');
      Exit;
    end;
    
    // ENCRYPTION
    ctx := EVP_CIPHER_CTX_new();
    if ctx = nil then
    begin
      AddResult('CCM', 'Create encrypt context', False);
      Exit;
    end;
    
    try
      if EVP_EncryptInit_ex(ctx, cipher, nil, nil, nil) <> 1 then
      begin
        AddResult('CCM', 'Init encryption', False);
        Exit;
      end;
      
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_CCM_SET_IVLEN, 12, nil) <> 1 then
      begin
        AddResult('CCM', 'Set nonce length', False);
        Exit;
      end;
      
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_CCM_SET_TAG, 16, nil) <> 1 then
      begin
        AddResult('CCM', 'Set tag length', False);
        Exit;
      end;
      
      if EVP_EncryptInit_ex(ctx, nil, nil, @key[0], @nonce[0]) <> 1 then
      begin
        AddResult('CCM', 'Set key/nonce', False);
        Exit;
      end;
      
      // Set plaintext length (required for CCM)
      if EVP_EncryptUpdate(ctx, nil, len, nil, 32) <> 1 then
      begin
        AddResult('CCM', 'Set message length', False);
        Exit;
      end;
      
      if EVP_EncryptUpdate(ctx, nil, len, @aad[0], 16) <> 1 then
      begin
        AddResult('CCM', 'Add AAD', False);
        Exit;
      end;
      
      if EVP_EncryptUpdate(ctx, @ciphertext[0], len, @plaintext[0], 32) <> 1 then
      begin
        AddResult('CCM', 'Encrypt data', False);
        Exit;
      end;
      ct_len := len;
      
      if EVP_EncryptFinal_ex(ctx, @ciphertext[ct_len], len) <> 1 then
      begin
        AddResult('CCM', 'Finalize encrypt', False);
        Exit;
      end;
      ct_len := ct_len + len;
      
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_CCM_GET_TAG, 16, @tag[0]) <> 1 then
      begin
        AddResult('CCM', 'Get tag', False);
        Exit;
      end;
      
      WriteLn('    Encrypted: ', ct_len, ' bytes, Tag: ', BytesToHex(tag, 16));
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
    // DECRYPTION
    ctx := EVP_CIPHER_CTX_new();
    if ctx = nil then
    begin
      AddResult('CCM', 'Create decrypt context', False);
      Exit;
    end;
    
    try
      if EVP_DecryptInit_ex(ctx, cipher, nil, nil, nil) <> 1 then
      begin
        AddResult('CCM', 'Init decryption', False);
        Exit;
      end;
      
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_CCM_SET_IVLEN, 12, nil) <> 1 then
      begin
        AddResult('CCM', 'Set nonce length (decrypt)', False);
        Exit;
      end;
      
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_CCM_SET_TAG, 16, @tag[0]) <> 1 then
      begin
        AddResult('CCM', 'Set tag (decrypt)', False);
        Exit;
      end;
      
      if EVP_DecryptInit_ex(ctx, nil, nil, @key[0], @nonce[0]) <> 1 then
      begin
        AddResult('CCM', 'Set key/nonce (decrypt)', False);
        Exit;
      end;
      
      // Set ciphertext length (required for CCM)
      if EVP_DecryptUpdate(ctx, nil, len, nil, ct_len) <> 1 then
      begin
        AddResult('CCM', 'Set message length (decrypt)', False);
        Exit;
      end;
      
      if EVP_DecryptUpdate(ctx, nil, len, @aad[0], 16) <> 1 then
      begin
        AddResult('CCM', 'Add AAD (decrypt)', False);
        Exit;
      end;
      
      if EVP_DecryptUpdate(ctx, @decrypted[0], len, @ciphertext[0], ct_len) <> 1 then
      begin
        AddResult('CCM', 'Decrypt and verify', False, 'Authentication failed');
        Exit;
      end;
      pt_len := len;
      
      if not BytesEqual(plaintext, decrypted, 32) then
      begin
        AddResult('CCM', 'Verify plaintext', False, 'Plaintext mismatch');
        Exit;
      end;
      
      WriteLn('    Decrypted: ', pt_len, ' bytes - VERIFIED');
      AddResult('CCM', 'Basic encrypt/decrypt', True);
      Result := True;
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
  except
    on E: Exception do
      AddResult('CCM', 'Basic test', False, E.Message);
  end;
end;

// ============================================================================
// XTS MODE TESTS
// ============================================================================

function TestXTSBasic: Boolean;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  key: array[0..31] of Byte;  // AES-128-XTS uses 256-bit key (2x128)
  tweak: array[0..15] of Byte;
  plaintext: array[0..63] of Byte;
  ciphertext: array[0..127] of Byte;
  decrypted: array[0..127] of Byte;
  len, ct_len, pt_len: Integer;
  i: Integer;
begin
  Result := False;
  WriteLn('  Testing XTS basic encrypt/decrypt...');
  
  try
    // Initialize test data
    for i := 0 to 31 do key[i] := Byte(i);
    for i := 0 to 15 do tweak[i] := Byte(i);
    for i := 0 to 63 do plaintext[i] := Byte($41 + (i mod 26));
    
    // Get cipher
    cipher := EVP_aes_128_xts();
    if cipher = nil then
    begin
      AddResult('XTS', 'Get cipher', False, 'EVP_aes_128_xts returned nil');
      Exit;
    end;
    
    // ENCRYPTION
    ctx := EVP_CIPHER_CTX_new();
    if ctx = nil then
    begin
      AddResult('XTS', 'Create encrypt context', False);
      Exit;
    end;
    
    try
      if EVP_EncryptInit_ex(ctx, cipher, nil, @key[0], @tweak[0]) <> 1 then
      begin
        AddResult('XTS', 'Init encryption', False);
        Exit;
      end;
      
      if EVP_EncryptUpdate(ctx, @ciphertext[0], len, @plaintext[0], 64) <> 1 then
      begin
        AddResult('XTS', 'Encrypt data', False);
        Exit;
      end;
      ct_len := len;
      
      if EVP_EncryptFinal_ex(ctx, @ciphertext[ct_len], len) <> 1 then
      begin
        AddResult('XTS', 'Finalize encrypt', False);
        Exit;
      end;
      ct_len := ct_len + len;
      
      WriteLn('    Encrypted: ', ct_len, ' bytes');
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
    // DECRYPTION
    ctx := EVP_CIPHER_CTX_new();
    if ctx = nil then
    begin
      AddResult('XTS', 'Create decrypt context', False);
      Exit;
    end;
    
    try
      if EVP_DecryptInit_ex(ctx, cipher, nil, @key[0], @tweak[0]) <> 1 then
      begin
        AddResult('XTS', 'Init decryption', False);
        Exit;
      end;
      
      if EVP_DecryptUpdate(ctx, @decrypted[0], len, @ciphertext[0], ct_len) <> 1 then
      begin
        AddResult('XTS', 'Decrypt data', False);
        Exit;
      end;
      pt_len := len;
      
      if EVP_DecryptFinal_ex(ctx, @decrypted[pt_len], len) <> 1 then
      begin
        AddResult('XTS', 'Finalize decrypt', False);
        Exit;
      end;
      pt_len := pt_len + len;
      
      if not BytesEqual(plaintext, decrypted, 64) then
      begin
        AddResult('XTS', 'Verify plaintext', False, 'Plaintext mismatch');
        Exit;
      end;
      
      WriteLn('    Decrypted: ', pt_len, ' bytes - VERIFIED');
      AddResult('XTS', 'Basic encrypt/decrypt', True);
      Result := True;
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
  except
    on E: Exception do
      AddResult('XTS', 'Basic test', False, E.Message);
  end;
end;

// ============================================================================
// OCB MODE TESTS
// ============================================================================

function TestOCBBasic: Boolean;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  key: array[0..15] of Byte;  // AES-128
  nonce: array[0..11] of Byte;
  plaintext: array[0..31] of Byte;
  aad: array[0..15] of Byte;
  ciphertext: array[0..63] of Byte;
  tag: array[0..15] of Byte;
  decrypted: array[0..63] of Byte;
  len, ct_len, pt_len: Integer;
  i: Integer;
begin
  Result := False;
  WriteLn('  Testing OCB basic encrypt/decrypt...');
  
  try
    // Initialize test data
    for i := 0 to 15 do key[i] := Byte(i);
    for i := 0 to 11 do nonce[i] := Byte(i);
    for i := 0 to 31 do plaintext[i] := Byte($41 + (i mod 26));
    for i := 0 to 15 do aad[i] := Byte($30 + (i mod 10));
    
    // Get cipher - OCB might not be available in all OpenSSL builds
    cipher := EVP_aes_128_ocb();
    if cipher = nil then
    begin
      AddResult('OCB', 'Get cipher', False, 'EVP_aes_128_ocb not available (expected in some builds)');
      WriteLn('    Note: OCB may not be available due to patent restrictions in some OpenSSL builds');
      Exit;
    end;
    
    // ENCRYPTION
    ctx := EVP_CIPHER_CTX_new();
    if ctx = nil then
    begin
      AddResult('OCB', 'Create encrypt context', False);
      Exit;
    end;
    
    try
      if EVP_EncryptInit_ex(ctx, cipher, nil, nil, nil) <> 1 then
      begin
        AddResult('OCB', 'Init encryption', False);
        Exit;
      end;
      
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_IVLEN, 12, nil) <> 1 then
      begin
        AddResult('OCB', 'Set nonce length', False);
        Exit;
      end;
      
      if EVP_EncryptInit_ex(ctx, nil, nil, @key[0], @nonce[0]) <> 1 then
      begin
        AddResult('OCB', 'Set key/nonce', False);
        Exit;
      end;
      
      if EVP_EncryptUpdate(ctx, nil, len, @aad[0], 16) <> 1 then
      begin
        AddResult('OCB', 'Add AAD', False);
        Exit;
      end;
      
      if EVP_EncryptUpdate(ctx, @ciphertext[0], len, @plaintext[0], 32) <> 1 then
      begin
        AddResult('OCB', 'Encrypt data', False);
        Exit;
      end;
      ct_len := len;
      
      if EVP_EncryptFinal_ex(ctx, @ciphertext[ct_len], len) <> 1 then
      begin
        AddResult('OCB', 'Finalize encrypt', False);
        Exit;
      end;
      ct_len := ct_len + len;
      
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_GET_TAG, 16, @tag[0]) <> 1 then
      begin
        AddResult('OCB', 'Get tag', False);
        Exit;
      end;
      
      WriteLn('    Encrypted: ', ct_len, ' bytes, Tag: ', BytesToHex(tag, 16));
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
    // DECRYPTION
    ctx := EVP_CIPHER_CTX_new();
    if ctx = nil then
    begin
      AddResult('OCB', 'Create decrypt context', False);
      Exit;
    end;
    
    try
      if EVP_DecryptInit_ex(ctx, cipher, nil, nil, nil) <> 1 then
      begin
        AddResult('OCB', 'Init decryption', False);
        Exit;
      end;
      
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_IVLEN, 12, nil) <> 1 then
      begin
        AddResult('OCB', 'Set nonce length (decrypt)', False);
        Exit;
      end;
      
      if EVP_DecryptInit_ex(ctx, nil, nil, @key[0], @nonce[0]) <> 1 then
      begin
        AddResult('OCB', 'Set key/nonce (decrypt)', False);
        Exit;
      end;
      
      if EVP_DecryptUpdate(ctx, nil, len, @aad[0], 16) <> 1 then
      begin
        AddResult('OCB', 'Add AAD (decrypt)', False);
        Exit;
      end;
      
      if EVP_DecryptUpdate(ctx, @decrypted[0], len, @ciphertext[0], ct_len) <> 1 then
      begin
        AddResult('OCB', 'Decrypt data', False);
        Exit;
      end;
      pt_len := len;
      
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_TAG, 16, @tag[0]) <> 1 then
      begin
        AddResult('OCB', 'Set tag (decrypt)', False);
        Exit;
      end;
      
      if EVP_DecryptFinal_ex(ctx, @decrypted[pt_len], len) <> 1 then
      begin
        AddResult('OCB', 'Verify tag', False, 'Authentication failed');
        Exit;
      end;
      pt_len := pt_len + len;
      
      if not BytesEqual(plaintext, decrypted, 32) then
      begin
        AddResult('OCB', 'Verify plaintext', False, 'Plaintext mismatch');
        Exit;
      end;
      
      WriteLn('    Decrypted: ', pt_len, ' bytes - VERIFIED');
      AddResult('OCB', 'Basic encrypt/decrypt', True);
      Result := True;
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
  except
    on E: Exception do
      AddResult('OCB', 'Basic test', False, E.Message);
  end;
end;

// ============================================================================
// MAIN PROGRAM
// ============================================================================

procedure PrintHeader;
begin
  WriteLn;
  PrintSeparator('=');
  WriteLn('  PHASE 2: AEAD MODES VERIFICATION FOR OPENSSL 3.x');
  PrintSeparator('=');
  WriteLn;
  WriteLn('This test verifies that all AEAD modes (GCM, CCM, XTS, OCB) work');
  WriteLn('correctly with OpenSSL 3.x using the EVP interface.');
  WriteLn;
  PrintSeparator('-');
end;

procedure PrintOpenSSLVersion;
begin
  WriteLn('OpenSSL Version: Loaded from library');
  PrintSeparator('-');
  WriteLn;
end;

procedure PrintResults;
var
  i: Integer;
  currentMode: string;
begin
  WriteLn;
  PrintSeparator('=');
  WriteLn('  TEST RESULTS SUMMARY');
  PrintSeparator('=');
  WriteLn;
  
  currentMode := '';
  for i := 0 to High(Results) do
  begin
    if Results[i].ModeName <> currentMode then
    begin
      currentMode := Results[i].ModeName;
      WriteLn;
      WriteLn('--- ', currentMode, ' Mode ---');
    end;
    
    if Results[i].Success then
      WriteLn('  [PASS] ', Results[i].TestName)
    else
    begin
      WriteLn('  [FAIL] ', Results[i].TestName);
      if Results[i].ErrorMsg <> '' then
        WriteLn('         Error: ', Results[i].ErrorMsg);
    end;
  end;
  
  WriteLn;
  PrintSeparator('=');
  WriteLn(Format('  Total: %d tests', [TotalTests]));
  WriteLn(Format('  Passed: %d (%.1f%%)', [PassedTests, (PassedTests / TotalTests) * 100]));
  WriteLn(Format('  Failed: %d (%.1f%%)', [FailedTests, (FailedTests / TotalTests) * 100]));
  PrintSeparator('=');
  WriteLn;
  
  if FailedTests = 0 then
  begin
    WriteLn('✅ ALL TESTS PASSED - Phase 2 Complete!');
    WriteLn;
    WriteLn('All AEAD modes are working correctly with OpenSSL 3.x.');
  end
  else
  begin
    WriteLn('⚠️  SOME TESTS FAILED');
    WriteLn;
    WriteLn('Please review the failures above. Some modes (like OCB) may not');
    WriteLn('be available in all OpenSSL builds due to patent restrictions.');
  end;
  
  WriteLn;
end;

begin
  TotalTests := 0;
  PassedTests := 0;
  FailedTests := 0;
  
  try
    PrintHeader;
    
    // Load OpenSSL
    if not LoadOpenSSLLibrary then
    begin
      WriteLn('ERROR: Failed to load OpenSSL library');
      ExitCode := 1;
      Exit;
    end;
    
    PrintOpenSSLVersion;
    
    // Run tests for each AEAD mode
    WriteLn('Running GCM tests...');
    PrintSeparator('-');
    TestGCMBasic;
    WriteLn;
    
    WriteLn('Running CCM tests...');
    PrintSeparator('-');
    TestCCMBasic;
    WriteLn;
    
    WriteLn('Running XTS tests...');
    PrintSeparator('-');
    TestXTSBasic;
    WriteLn;
    
    WriteLn('Running OCB tests...');
    PrintSeparator('-');
    TestOCBBasic;
    WriteLn;
    
    // Print results
    PrintResults;
    
    // Set exit code
    if FailedTests = 0 then
      ExitCode := 0
    else
      ExitCode := 1;
      
  except
    on E: Exception do
    begin
      WriteLn('FATAL ERROR: ', E.Message);
      ExitCode := 2;
    end;
  end;
end.
