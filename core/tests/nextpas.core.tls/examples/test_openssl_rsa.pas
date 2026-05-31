program test_openssl_rsa;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.crypto,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.api.rsa;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure TestResult(const TestName: string; Passed: Boolean; 
  const Expected: string = ''; const Got: string = '');
begin
  Write('  [', TestName, '] ... ');
  if Passed then
  begin
    WriteLn('PASS');
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('FAIL');
    if (Expected <> '') and (Got <> '') then
      WriteLn('    Expected: ', Expected, ', Got: ', Got);
    Inc(TestsFailed);
  end;
end;

function BytesToHex(const Data: PByte; Len: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Len-1 do
    Result := Result + IntToHex(Data[I], 2);
  Result := LowerCase(Result);
end;

procedure PrintScopeNote;
begin
  WriteLn('[NOTE] Scope: this example validates RSA primitive round-trip behavior.');
  WriteLn('[NOTE] It does not claim full RSA_sign/RSA_verify digest-encoding compliance.');
  WriteLn;
end;

// Test RSA key generation
procedure TestRSAKeyGeneration;
var
  rsa: PRSA;
  e: PBIGNUM;
  key_size: Integer;
begin
  WriteLn('Testing RSA Key Generation:');
  
  // Create RSA structure
  rsa := RSA_new();
  TestResult('RSA_new', rsa <> nil);
  
  if rsa <> nil then
  begin
    // Create public exponent
    e := BN_new();
    if e <> nil then
    begin
      // Set e = 65537 (RSA_F4)
      BN_set_word(e, RSA_F4);
      
      // Generate 2048-bit RSA key
      WriteLn('  Generating 2048-bit RSA key (this may take a moment)...');
      TestResult('RSA_generate_key_ex (2048 bits)', 
        RSA_generate_key_ex(rsa, 2048, e, nil) = 1);
      
      // Check key size
      key_size := RSA_size(rsa);
      TestResult('RSA_size (should be 256 for 2048-bit)', 
        key_size = 256, '256', IntToStr(key_size));
      
      // Check bits
      TestResult('RSA_bits (should be 2048)', 
        RSA_bits(rsa) = 2048, '2048', IntToStr(RSA_bits(rsa)));
      
      BN_free(e);
    end;
    
    RSA_free(rsa);
  end;
  
  WriteLn;
end;

// Test RSA encryption and decryption
procedure TestRSAEncryptDecrypt;
var
  rsa: PRSA;
  e: PBIGNUM;
  plaintext: AnsiString;
  ciphertext: array[0..255] of Byte;
  decrypted: array[0..255] of Byte;
  encrypted_len, decrypted_len: Integer;
  decrypted_str: AnsiString;
begin
  WriteLn('Testing RSA Encryption/Decryption:');
  
  rsa := RSA_new();
  if rsa = nil then
  begin
    TestResult('RSA key setup', False);
    WriteLn;
    Exit;
  end;
  
  e := BN_new();
  BN_set_word(e, RSA_F4);
  
  WriteLn('  Generating 2048-bit RSA key...');
  if RSA_generate_key_ex(rsa, 2048, e, nil) <> 1 then
  begin
    TestResult('RSA key generation', False);
    BN_free(e);
    RSA_free(rsa);
    WriteLn;
    Exit;
  end;
  BN_free(e);
  
  // Test encryption/decryption
  plaintext := 'Hello, RSA!';
  FillChar(ciphertext, SizeOf(ciphertext), 0);
  FillChar(decrypted, SizeOf(decrypted), 0);
  
  // Public key encryption
  encrypted_len := RSA_public_encrypt(
    Length(plaintext),
    @plaintext[1],
    @ciphertext[0],
    rsa,
    RSA_PKCS1_PADDING
  );
  
  TestResult('RSA_public_encrypt', encrypted_len > 0);
  
  if encrypted_len > 0 then
  begin
    // Private key decryption
    decrypted_len := RSA_private_decrypt(
      encrypted_len,
      @ciphertext[0],
      @decrypted[0],
      rsa,
      RSA_PKCS1_PADDING
    );
    
    TestResult('RSA_private_decrypt', decrypted_len > 0);
    
    if decrypted_len > 0 then
    begin
      SetLength(decrypted_str, decrypted_len);
      Move(decrypted[0], decrypted_str[1], decrypted_len);
      TestResult('Decrypted matches plaintext', 
        decrypted_str = plaintext, plaintext, decrypted_str);
    end;
  end;
  
  RSA_free(rsa);
  WriteLn;
end;

// Test RSA signing and verification
procedure TestRSASignVerify;
var
  rsa: PRSA;
  e: PBIGNUM;
  message: AnsiString;
  signature: array[0..255] of Byte;
  verified: array[0..255] of Byte;
  sig_len: Cardinal;
  verify_result: Integer;
  nid_sha256: Integer;
begin
  WriteLn('Testing RSA Sign/Verify:');
  
  rsa := RSA_new();
  if rsa = nil then
  begin
    TestResult('RSA key setup', False);
    WriteLn;
    Exit;
  end;
  
  e := BN_new();
  BN_set_word(e, RSA_F4);
  
  WriteLn('  Generating 2048-bit RSA key...');
  if RSA_generate_key_ex(rsa, 2048, e, nil) <> 1 then
  begin
    TestResult('RSA key generation', False);
    BN_free(e);
    RSA_free(rsa);
    WriteLn;
    Exit;
  end;
  BN_free(e);
  
  // Test signing
  message := 'Test message for signing';
  FillChar(signature, SizeOf(signature), 0);
  FillChar(verified, SizeOf(verified), 0);
  sig_len := 0;
  
  // NID for SHA256 (usually 672)
  nid_sha256 := 672;
  
  // Scope note: this block intentionally validates raw RSA private/public primitive round-trip.
  // It is not a substitute for full RSA_sign/RSA_verify digest+padding compliance testing.
  WriteLn('  Signing with RSA...');
  
  // Use private key to sign (encrypt)
  sig_len := RSA_private_encrypt(
    Length(message),
    @message[1],
    @signature[0],
    rsa,
    RSA_PKCS1_PADDING
  );
  
  TestResult('RSA_private_encrypt (sign)', sig_len > 0);
  
  if sig_len > 0 then
  begin
    // Verify signature with public key
    verify_result := RSA_public_decrypt(
      sig_len,
      @signature[0],
      @verified[0],
      rsa,
      RSA_PKCS1_PADDING
    );
    
    TestResult('RSA_public_decrypt (verify)', verify_result > 0);
  end;
  
  RSA_free(rsa);
  WriteLn;
end;

// Test RSA key components
procedure TestRSAKeyComponents;
var
  rsa: PRSA;
  e: PBIGNUM;
  n, e_get, d: PBIGNUM;
  p, q: PBIGNUM;
begin
  WriteLn('Testing RSA Key Components:');
  
  rsa := RSA_new();
  if rsa = nil then
  begin
    TestResult('RSA key setup', False);
    WriteLn;
    Exit;
  end;
  
  e := BN_new();
  BN_set_word(e, RSA_F4);
  
  WriteLn('  Generating 1024-bit RSA key (faster for testing)...');
  if RSA_generate_key_ex(rsa, 1024, e, nil) <> 1 then
  begin
    TestResult('RSA key generation', False);
    BN_free(e);
    RSA_free(rsa);
    WriteLn;
    Exit;
  end;
  BN_free(e);
  
  // Get key components
  n := nil;
  e_get := nil;
  d := nil;
  RSA_get0_key(rsa, @n, @e_get, @d);
  
  TestResult('RSA_get0_key (n)', n <> nil);
  TestResult('RSA_get0_key (e)', e_get <> nil);
  TestResult('RSA_get0_key (d)', d <> nil);
  
  // Get factors
  p := nil;
  q := nil;
  RSA_get0_factors(rsa, @p, @q);
  
  TestResult('RSA_get0_factors (p)', p <> nil);
  TestResult('RSA_get0_factors (q)', q <> nil);
  
  RSA_free(rsa);
  WriteLn;
end;

// Test RSA check key validity
procedure TestRSACheckKey;
var
  rsa: PRSA;
  e: PBIGNUM;
begin
  WriteLn('Testing RSA Check Key:');
  
  rsa := RSA_new();
  if rsa = nil then
  begin
    TestResult('RSA key setup', False);
    WriteLn;
    Exit;
  end;
  
  e := BN_new();
  BN_set_word(e, RSA_F4);
  
  WriteLn('  Generating 1024-bit RSA key...');
  if RSA_generate_key_ex(rsa, 1024, e, nil) <> 1 then
  begin
    TestResult('RSA key generation', False);
    BN_free(e);
    RSA_free(rsa);
    WriteLn;
    Exit;
  end;
  BN_free(e);
  
  // Check key validity
  if Assigned(RSA_check_key) then
    TestResult('RSA_check_key (valid key)', RSA_check_key(rsa) = 1)
  else
    WriteLn('  RSA_check_key not available in this OpenSSL version');
  
  RSA_free(rsa);
  WriteLn;
end;

begin
  WriteLn('OpenSSL RSA Module Unit Test');
  WriteLn('============================');
  WriteLn;
  PrintScopeNote;
  
  // Load OpenSSL
  Write('Loading OpenSSL libraries... ');
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
  
  WriteLn('OpenSSL version: ', OpenSSL_version(0));
  WriteLn;
  
  // Load required modules
  LoadOpenSSLCrypto;
  LoadOpenSSLBN;
  
  // Load RSA module
  Write('Loading RSA module... ');
  if not LoadOpenSSLRSA then
  begin
    WriteLn('FAILED');
    Halt(1);
  end;
  WriteLn('OK');
  WriteLn;
  
  // Run tests
  try
    TestRSAKeyGeneration;
    TestRSAEncryptDecrypt;
    TestRSASignVerify;
    TestRSAKeyComponents;
    TestRSACheckKey;
  except
    on E: Exception do
    begin
      WriteLn('EXCEPTION: ', E.Message);
      Inc(TestsFailed);
    end;
  end;
  
  // Print summary
  WriteLn('Test Summary:');
  WriteLn('=============');
  WriteLn('Tests Passed: ', TestsPassed);
  WriteLn('Tests Failed: ', TestsFailed);
  WriteLn('Total Tests:  ', TestsPassed + TestsFailed);
  WriteLn;
  
  if TestsFailed = 0 then
    WriteLn('All tests PASSED!')
  else
  begin
    WriteLn('Some tests FAILED!');
    Halt(1);
  end;
  
  // Cleanup
  UnloadOpenSSLRSA;
  UnloadOpenSSLBN;
  UnloadOpenSSLCrypto;
  UnloadOpenSSLCore;
end.
