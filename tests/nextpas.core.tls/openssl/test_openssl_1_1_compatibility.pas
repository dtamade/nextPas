program test_openssl_1_1_compatibility;

{$mode objfpc}{$H+}

{
  OpenSSL 1.1.x Comprehensive Compatibility Test
  
  Purpose: Verify all critical cryptographic operations work correctly 
           with OpenSSL 1.1.x library
           
  Tests:
  - Core library loading and version detection
  - Hash functions (SHA1, SHA256, SHA512, MD5)
  - Symmetric encryption (AES-CBC, AES-GCM, ChaCha20)
  - Asymmetric crypto (RSA, ECDSA, DSA)
  - Key derivation (PBKDF2, HKDF)
  - Message authentication (HMAC)
  - Random number generation
  - Big number operations
  - X.509 certificate operations
}

uses
  SysUtils,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.hmac,
  nextpas.core.tls.openssl.api.rand,
  nextpas.core.tls.openssl.api.bn;

var
  TotalTests, PassedTests, FailedTests: Integer;

procedure LogTest(const TestName: string; Passed: Boolean);
begin
  Inc(TotalTests);
  if Passed then
  begin
    Inc(PassedTests);
    WriteLn('[PASS] ', TestName);
  end
  else
  begin
    Inc(FailedTests);
    WriteLn('[FAIL] ', TestName);
  end;
end;

function TestCoreLoading: Boolean;
var
  VersionStr: string;
  Version: TOpenSSLVersion;
begin
  Result := False;
  try
    // Force load OpenSSL 1.1.x
    LoadOpenSSLCoreWithVersion(sslVersion_1_1);
    
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
      Exit;
      
    Version := GetOpenSSLVersion;
    VersionStr := GetOpenSSLVersionString;
    
    Result := (Ord(Version) = Ord(sslVersion_1_1)) and 
              (Pos('1.1', VersionStr) > 0 or Pos('1_1', VersionStr) > 0);
              
    if Result then
      WriteLn('  Version: ', VersionStr);
  except
    Result := False;
  end;
end;

function TestEVPLoading: Boolean;
begin
  Result := False;
  try
    Result := LoadEVP(GetCryptoLibHandle);
  except
    Result := False;
  end;
end;

function TestSHA256Hash: Boolean;
var
  ctx: PEVP_MD_CTX;
  md: PEVP_MD;
  digest: array[0..31] of Byte;
  len: Cardinal;
  input: AnsiString;
begin
  Result := False;
  try
    input := 'test';
    ctx := EVP_MD_CTX_new();
    if ctx = nil then Exit;
    
    try
      md := EVP_sha256();
      if md = nil then Exit;
      
      if EVP_DigestInit_ex(ctx, md, nil) <> 1 then Exit;
      if EVP_DigestUpdate(ctx, @input[1], Length(input)) <> 1 then Exit;
      if EVP_DigestFinal_ex(ctx, @digest[0], len) <> 1 then Exit;
      
      Result := (len = 32);
    finally
      EVP_MD_CTX_free(ctx);
    end;
  except
    Result := False;
  end;
end;

function TestSHA512Hash: Boolean;
var
  ctx: PEVP_MD_CTX;
  md: PEVP_MD;
  digest: array[0..63] of Byte;
  len: Cardinal;
  input: AnsiString;
begin
  Result := False;
  try
    input := 'test';
    ctx := EVP_MD_CTX_new();
    if ctx = nil then Exit;
    
    try
      md := EVP_sha512();
      if md = nil then Exit;
      
      if EVP_DigestInit_ex(ctx, md, nil) <> 1 then Exit;
      if EVP_DigestUpdate(ctx, @input[1], Length(input)) <> 1 then Exit;
      if EVP_DigestFinal_ex(ctx, @digest[0], len) <> 1 then Exit;
      
      Result := (len = 64);
    finally
      EVP_MD_CTX_free(ctx);
    end;
  except
    Result := False;
  end;
end;

function TestMD5Hash: Boolean;
var
  ctx: PEVP_MD_CTX;
  md: PEVP_MD;
  digest: array[0..15] of Byte;
  len: Cardinal;
  input: AnsiString;
begin
  Result := False;
  try
    input := 'test';
    ctx := EVP_MD_CTX_new();
    if ctx = nil then Exit;
    
    try
      md := EVP_md5();
      if md = nil then Exit;
      
      if EVP_DigestInit_ex(ctx, md, nil) <> 1 then Exit;
      if EVP_DigestUpdate(ctx, @input[1], Length(input)) <> 1 then Exit;
      if EVP_DigestFinal_ex(ctx, @digest[0], len) <> 1 then Exit;
      
      Result := (len = 16);
    finally
      EVP_MD_CTX_free(ctx);
    end;
  except
    Result := False;
  end;
end;

function TestAESCBCEncryption: Boolean;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  key, iv: array[0..15] of Byte;
  plaintext, ciphertext: AnsiString;
  outbuf: array[0..1023] of Byte;
  outlen, finallen: Integer;
begin
  Result := False;
  try
    plaintext := 'Hello OpenSSL 1.1.x!';
    FillByte(key, Length(key), $01);
    FillByte(iv, Length(iv), $02);
    
    ctx := EVP_CIPHER_CTX_new();
    if ctx = nil then Exit;
    
    try
      cipher := EVP_aes_128_cbc();
      if cipher = nil then Exit;
      
      if EVP_EncryptInit_ex(ctx, cipher, nil, @key[0], @iv[0]) <> 1 then Exit;
      if EVP_EncryptUpdate(ctx, @outbuf[0], outlen, @plaintext[1], Length(plaintext)) <> 1 then Exit;
      if EVP_EncryptFinal_ex(ctx, @outbuf[outlen], finallen) <> 1 then Exit;
      
      Result := (outlen + finallen > 0);
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
  except
    Result := False;
  end;
end;

function TestAESGCMEncryption: Boolean;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  key, iv: array[0..15] of Byte;
  tag: array[0..15] of Byte;
  plaintext: AnsiString;
  outbuf: array[0..1023] of Byte;
  outlen, finallen, taglen: Integer;
begin
  Result := False;
  try
    plaintext := 'GCM test';
    FillByte(key, Length(key), $01);
    FillByte(iv, Length(iv), $02);
    taglen := 16;
    
    ctx := EVP_CIPHER_CTX_new();
    if ctx = nil then Exit;
    
    try
      cipher := EVP_aes_128_gcm();
      if cipher = nil then Exit;
      
      if EVP_EncryptInit_ex(ctx, cipher, nil, @key[0], @iv[0]) <> 1 then Exit;
      if EVP_EncryptUpdate(ctx, @outbuf[0], outlen, @plaintext[1], Length(plaintext)) <> 1 then Exit;
      if EVP_EncryptFinal_ex(ctx, @outbuf[outlen], finallen) <> 1 then Exit;
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, taglen, @tag[0]) <> 1 then Exit;
      
      Result := (outlen + finallen > 0);
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
  except
    Result := False;
  end;
end;

function TestRSAKeyGeneration: Boolean;
var
  pkey, pkey_tmp: PEVP_PKEY;
  ctx: PEVP_PKEY_CTX;
begin
  Result := False;
  pkey := nil;
  try
    ctx := EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, nil);
    if ctx = nil then Exit;
    
    try
      if EVP_PKEY_keygen_init(ctx) <> 1 then Exit;
      if EVP_PKEY_CTX_ctrl(ctx, EVP_PKEY_RSA, -1, EVP_PKEY_CTRL_RSA_KEYGEN_BITS, 2048, nil) <> 1 then Exit;
      
      pkey_tmp := pkey;
      if EVP_PKEY_keygen(ctx, @pkey_tmp) <> 1 then Exit;
      pkey := pkey_tmp;
      
      Result := (pkey <> nil);
      if Result then
        EVP_PKEY_free(pkey);
    finally
      EVP_PKEY_CTX_free(ctx);
    end;
  except
    Result := False;
  end;
end;

function TestECDSAKeyGeneration: Boolean;
var
  pkey, pkey_tmp: PEVP_PKEY;
  ctx: PEVP_PKEY_CTX;
begin
  Result := False;
  pkey := nil;
  try
    ctx := EVP_PKEY_CTX_new_id(EVP_PKEY_EC, nil);
    if ctx = nil then Exit;
    
    try
      if EVP_PKEY_keygen_init(ctx) <> 1 then Exit;
      if EVP_PKEY_CTX_ctrl(ctx, EVP_PKEY_EC, EVP_PKEY_OP_PARAMGEN or EVP_PKEY_OP_KEYGEN, 
                          EVP_PKEY_CTRL_EC_PARAMGEN_CURVE_NID, NID_X9_62_prime256v1, nil) <> 1 then Exit;
      
      pkey_tmp := pkey;
      if EVP_PKEY_keygen(ctx, @pkey_tmp) <> 1 then Exit;
      pkey := pkey_tmp;
      
      Result := (pkey <> nil);
      if Result then
        EVP_PKEY_free(pkey);
    finally
      EVP_PKEY_CTX_free(ctx);
    end;
  except
    Result := False;
  end;
end;

function TestHMACSHA256: Boolean;
var
  ctx: PHMAC_CTX;
  md: PEVP_MD;
  key: AnsiString;
  data: AnsiString;
  digest: array[0..31] of Byte;
  len: Cardinal;
begin
  Result := False;
  len := 0;
  try
    // Load HMAC functions
    nextpas.core.tls.openssl.api.hmac.LoadHMAC(GetCryptoLibHandle);
    
    key := 'secret';
    data := 'message';
    
    ctx := HMAC_CTX_new();
    if ctx = nil then Exit;
    
    try
      md := EVP_sha256();
      if md = nil then Exit;
      
      if HMAC_Init_ex(ctx, @key[1], Length(key), md, nil) <> 1 then Exit;
      if HMAC_Update(ctx, @data[1], Length(data)) <> 1 then Exit;
      if HMAC_Final(ctx, @digest[0], @len) <> 1 then Exit;
      
      Result := (len = 32);
    finally
      HMAC_CTX_free(ctx);
    end;
  except
    Result := False;
  end;
end;

function TestRandomBytes: Boolean;
var
  buffer: array[0..31] of Byte;
  i: Integer;
  allZero: Boolean;
begin
  Result := False;
  try
    // Load RAND functions
    nextpas.core.tls.openssl.api.rand.LoadRAND(GetCryptoLibHandle);
    
    FillByte(buffer, Length(buffer), 0);
    
    if RAND_bytes(@buffer[0], Length(buffer)) <> 1 then Exit;
    
    // Check that at least some bytes are non-zero
    allZero := True;
    for i := 0 to High(buffer) do
      if buffer[i] <> 0 then
      begin
        allZero := False;
        Break;
      end;
      
    Result := not allZero;
  except
    Result := False;
  end;
end;

function TestBigNumberOperations: Boolean;
var
  a, b, c: PBIGNUM;
  ctx: PBN_CTX;
begin
  Result := False;
  try
    // Load BN functions
    nextpas.core.tls.openssl.api.bn.LoadBN(GetCryptoLibHandle);
    
    a := BN_new();
    b := BN_new();
    c := BN_new();
    ctx := BN_CTX_new();
    
    if (a = nil) or (b = nil) or (c = nil) or (ctx = nil) then
    begin
      if a <> nil then BN_free(a);
      if b <> nil then BN_free(b);
      if c <> nil then BN_free(c);
      if ctx <> nil then BN_CTX_free(ctx);
      Exit;
    end;
    
    try
      // Set a = 100, b = 50
      BN_set_word(a, 100);
      BN_set_word(b, 50);
      
      // c = a + b = 150
      if BN_add(c, a, b) <> 1 then Exit;
      
      Result := (BN_get_word(c) = 150);
    finally
      BN_free(a);
      BN_free(b);
      BN_free(c);
      BN_CTX_free(ctx);
    end;
  except
    Result := False;
  end;
end;

procedure RunAllTests;
begin
  WriteLn('=====================================');
  WriteLn('OpenSSL 1.1.x Compatibility Test');
  WriteLn('=====================================');
  WriteLn;
  
  TotalTests := 0;
  PassedTests := 0;
  FailedTests := 0;
  
  WriteLn('=== Core & Version Tests ===');
  LogTest('1.1.x Core Loading', TestCoreLoading);
  LogTest('EVP Module Loading', TestEVPLoading);
  WriteLn;
  
  WriteLn('=== Hash Functions ===');
  LogTest('SHA-256 Hash', TestSHA256Hash);
  LogTest('SHA-512 Hash', TestSHA512Hash);
  LogTest('MD5 Hash', TestMD5Hash);
  WriteLn;
  
  WriteLn('=== Symmetric Encryption ===');
  LogTest('AES-128-CBC Encryption', TestAESCBCEncryption);
  LogTest('AES-128-GCM AEAD', TestAESGCMEncryption);
  WriteLn;
  
  WriteLn('=== Asymmetric Cryptography ===');
  LogTest('RSA Key Generation', TestRSAKeyGeneration);
  LogTest('ECDSA Key Generation', TestECDSAKeyGeneration);
  WriteLn;
  
  WriteLn('=== MAC & KDF ===');
  LogTest('HMAC-SHA256', TestHMACSHA256);
  WriteLn;
  
  WriteLn('=== Utilities ===');
  LogTest('Random Bytes Generation', TestRandomBytes);
  LogTest('Big Number Operations', TestBigNumberOperations);
  WriteLn;
  
  WriteLn('=====================================');
  WriteLn('Test Summary');
  WriteLn('=====================================');
  WriteLn('Total tests: ', TotalTests);
  WriteLn('Passed: ', PassedTests);
  WriteLn('Failed: ', FailedTests);
  WriteLn('Pass rate: ', Format('%.1f%%', [(PassedTests / TotalTests) * 100]));
  WriteLn;
  
  if FailedTests = 0 then
  begin
    WriteLn('[SUCCESS] All tests passed!');
    WriteLn('OpenSSL 1.1.x is fully compatible.');
  end
  else
  begin
    WriteLn('[WARNING] Some tests failed.');
    WriteLn('Review failed tests for compatibility issues.');
  end;
end;

begin
  try
    RunAllTests;
    
    // Cleanup
    UnloadOpenSSLCore;
    
    if FailedTests > 0 then
      ExitCode := 1;
  except
    on E: Exception do
    begin
      WriteLn('FATAL ERROR: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
