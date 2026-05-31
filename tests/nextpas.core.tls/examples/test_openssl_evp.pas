program test_openssl_evp;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.err;

var
  TestsPassed, TestsFailed, TestsSkipped: Integer;
  SkipCapability, SkipOther: Integer;

procedure MarkSkip(const AMessage: string; const ACategory: string = 'other');
begin
  Inc(TestsSkipped);
  if LowerCase(ACategory) = 'capability' then
    Inc(SkipCapability)
  else
    Inc(SkipOther);
  WriteLn('  [SKIP] [', ACategory, '] ', AMessage);
end;

procedure TestDigestMD5;
var
  ctx: PEVP_MD_CTX;
  md: PEVP_MD;
  digest: array[0..31] of Byte;
  digestLen: Cardinal;
  data: AnsiString;
  i: Integer;
  hexDigest: string;
begin
  WriteLn('Testing EVP Digest (MD5)...');
  
  ctx := EVP_MD_CTX_new();
  if ctx = nil then
  begin
    WriteLn('  [FAIL] FAIL: Failed to create MD context');
    Inc(TestsFailed);
    Exit;
  end;
  
  try
    md := EVP_md5();
    if md = nil then
    begin
      WriteLn('  [FAIL] FAIL: Failed to get MD5 algorithm');
      Inc(TestsFailed);
      Exit;
    end;
    
    if EVP_DigestInit_ex(ctx, md, nil) <> 1 then
    begin
      WriteLn('  [FAIL] FAIL: Failed to initialize digest');
      Inc(TestsFailed);
      Exit;
    end;
    
    data := 'The quick brown fox jumps over the lazy dog';
    if EVP_DigestUpdate(ctx, PAnsiChar(data), Length(data)) <> 1 then
    begin
      WriteLn('  [FAIL] FAIL: Failed to update digest');
      Inc(TestsFailed);
      Exit;
    end;
    
    if EVP_DigestFinal_ex(ctx, @digest[0], digestLen) <> 1 then
    begin
      WriteLn('  [FAIL] FAIL: Failed to finalize digest');
      Inc(TestsFailed);
      Exit;
    end;
    
    // Convert to hex
    hexDigest := '';
    for i := 0 to Integer(digestLen) - 1 do
      hexDigest := hexDigest + IntToHex(digest[i], 2);
    
    WriteLn('  MD5 digest: ', LowerCase(hexDigest));
    WriteLn('  Expected:   9e107d9d372bb6826bd81d3542a419d6');
    
    if LowerCase(hexDigest) = '9e107d9d372bb6826bd81d3542a419d6' then
    begin
      WriteLn('  [PASS]');
      Inc(TestsPassed);
    end
    else
    begin
      WriteLn('  [FAIL] Digest mismatch');
      Inc(TestsFailed);
    end;
  finally
    if ctx <> nil then
      EVP_MD_CTX_free(ctx);
  end;
end;

procedure TestDigestSHA256;
var
  ctx: PEVP_MD_CTX;
  md: PEVP_MD;
  digest: array[0..63] of Byte;
  digestLen: Cardinal;
  data: AnsiString;
  i: Integer;
  hexDigest: string;
begin
  WriteLn('Testing EVP Digest (SHA256)...');
  
  ctx := EVP_MD_CTX_new();
  if ctx = nil then
  begin
    WriteLn('  [FAIL] FAIL: Failed to create MD context');
    Inc(TestsFailed);
    Exit;
  end;
  
  try
    md := EVP_sha256();
    if md = nil then
    begin
      WriteLn('  [FAIL] FAIL: Failed to get SHA256 algorithm');
      Inc(TestsFailed);
      Exit;
    end;
    
    if EVP_DigestInit_ex(ctx, md, nil) <> 1 then
    begin
      WriteLn('  [FAIL] FAIL: Failed to initialize digest');
      Inc(TestsFailed);
      Exit;
    end;
    
    data := 'hello world';
    if EVP_DigestUpdate(ctx, PAnsiChar(data), Length(data)) <> 1 then
    begin
      WriteLn('  [FAIL] FAIL: Failed to update digest');
      Inc(TestsFailed);
      Exit;
    end;
    
    if EVP_DigestFinal_ex(ctx, @digest[0], digestLen) <> 1 then
    begin
      WriteLn('  [FAIL] FAIL: Failed to finalize digest');
      Inc(TestsFailed);
      Exit;
    end;
    
    // Convert to hex
    hexDigest := '';
    for i := 0 to Integer(digestLen) - 1 do
      hexDigest := hexDigest + IntToHex(digest[i], 2);
    
    WriteLn('  SHA256 digest: ', LowerCase(hexDigest));
    WriteLn('  Digest length: ', digestLen, ' bytes');
    
    if digestLen = 32 then
    begin
      WriteLn('  [PASS]');
      Inc(TestsPassed);
    end
    else
    begin
      WriteLn('  [FAIL] Wrong digest length');
      Inc(TestsFailed);
    end;
  finally
    EVP_MD_CTX_free(ctx);
  end;
end;

procedure TestCipherAES128CBC;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  key: array[0..15] of Byte;
  iv: array[0..15] of Byte;
  plaintext: AnsiString;
  ciphertext: array[0..255] of Byte;
  decrypted: array[0..255] of Byte;
  outLen, tmpLen: Integer;
  i: Integer;
  decryptedStr: AnsiString;
begin
  WriteLn('Testing EVP Cipher (AES-128-CBC)...');
  
  // Initialize key and IV
  for i := 0 to 15 do
  begin
    key[i] := i;
    iv[i] := i;
  end;
  
  plaintext := 'Hello, OpenSSL!';
  
  // Encryption
  ctx := EVP_CIPHER_CTX_new();
  if ctx = nil then
  begin
    WriteLn('  [FAIL] FAIL: Failed to create cipher context');
    Inc(TestsFailed);
    Exit;
  end;
  
  try
    cipher := EVP_aes_128_cbc();
    if cipher = nil then
    begin
      WriteLn('  [FAIL] FAIL: Failed to get AES-128-CBC cipher');
      Inc(TestsFailed);
      Exit;
    end;
    
    // Encrypt
    if EVP_EncryptInit_ex(ctx, cipher, nil, @key[0], @iv[0]) <> 1 then
    begin
      WriteLn('  [FAIL] FAIL: Failed to initialize encryption');
      Inc(TestsFailed);
      Exit;
    end;
    
    if EVP_EncryptUpdate(ctx, @ciphertext[0], outLen, PByte(PAnsiChar(plaintext)), Length(plaintext)) <> 1 then
    begin
      WriteLn('  [FAIL] FAIL: Failed to encrypt data');
      Inc(TestsFailed);
      Exit;
    end;
    
    if EVP_EncryptFinal_ex(ctx, @ciphertext[outLen], tmpLen) <> 1 then
    begin
      WriteLn('  [FAIL] FAIL: Failed to finalize encryption');
      Inc(TestsFailed);
      Exit;
    end;
    
    outLen := outLen + tmpLen;
    WriteLn('  Encrypted ', Length(plaintext), ' bytes to ', outLen, ' bytes');
    
    EVP_CIPHER_CTX_reset(ctx);
    
    // Decrypt
    if EVP_DecryptInit_ex(ctx, cipher, nil, @key[0], @iv[0]) <> 1 then
    begin
      WriteLn('  [FAIL] FAIL: Failed to initialize decryption');
      Inc(TestsFailed);
      Exit;
    end;
    
    tmpLen := 0;
    if EVP_DecryptUpdate(ctx, @decrypted[0], tmpLen, @ciphertext[0], outLen) <> 1 then
    begin
      WriteLn('  [FAIL] FAIL: Failed to decrypt data');
      Inc(TestsFailed);
      Exit;
    end;
    
    outLen := tmpLen;
    if EVP_DecryptFinal_ex(ctx, @decrypted[outLen], tmpLen) <> 1 then
    begin
      WriteLn('  [FAIL] FAIL: Failed to finalize decryption');
      Inc(TestsFailed);
      Exit;
    end;
    
    outLen := outLen + tmpLen;
    
    SetLength(decryptedStr, outLen);
    Move(decrypted[0], decryptedStr[1], outLen);
    
    WriteLn('  Original:  "', plaintext, '"');
    WriteLn('  Decrypted: "', decryptedStr, '"');
    
    if decryptedStr = plaintext then
    begin
      WriteLn('  [PASS]');
      Inc(TestsPassed);
    end
    else
    begin
      WriteLn('  [FAIL] Decrypted text does not match');
      Inc(TestsFailed);
    end;
  finally
    EVP_CIPHER_CTX_free(ctx);
  end;
end;

procedure TestDigestByName;
var
  md: PEVP_MD;
  size: Integer;
begin
  WriteLn('Testing EVP_get_digestbyname...');
  
  if not Assigned(EVP_get_digestbyname) then
  begin
    MarkSkip('EVP_get_digestbyname not available', 'capability');
    Exit;
  end;
  
  try
    md := EVP_get_digestbyname('SHA256');
  except
    WriteLn('  [FAIL] Exception calling EVP_get_digestbyname');
    Inc(TestsFailed);
    Exit;
  end;
  
  if md = nil then
  begin
    WriteLn('  [FAIL] Failed to get digest by name "SHA256"');
    Inc(TestsFailed);
    Exit;
  end;
  
  size := EVP_MD_get_size(md);
  WriteLn('  SHA256 digest size: ', size, ' bytes');
  
  if size = 32 then
  begin
    WriteLn('  [PASS]');
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('  [FAIL] Wrong digest size');
    Inc(TestsFailed);
  end;
end;

procedure TestCipherByName;
var
  cipher: PEVP_CIPHER;
  keyLen, blockSize, ivLen: Integer;
begin
  WriteLn('Testing EVP_get_cipherbyname...');
  
  if not Assigned(EVP_get_cipherbyname) then
  begin
    MarkSkip('EVP_get_cipherbyname not available', 'capability');
    Exit;
  end;
  
  try
    cipher := EVP_get_cipherbyname('AES-256-CBC');
  except
    WriteLn('  [FAIL] Exception calling EVP_get_cipherbyname');
    Inc(TestsFailed);
    Exit;
  end;
  
  if cipher = nil then
  begin
    WriteLn('  [FAIL] Failed to get cipher by name "AES-256-CBC"');
    Inc(TestsFailed);
    Exit;
  end;
  
  keyLen := EVP_CIPHER_get_key_length(cipher);
  blockSize := EVP_CIPHER_get_block_size(cipher);
  ivLen := EVP_CIPHER_get_iv_length(cipher);
  
  WriteLn('  AES-256-CBC key length:   ', keyLen, ' bytes');
  WriteLn('  AES-256-CBC block size:   ', blockSize, ' bytes');
  WriteLn('  AES-256-CBC IV length:    ', ivLen, ' bytes');
  
  if (keyLen = 32) and (blockSize = 16) and (ivLen = 16) then
  begin
    WriteLn('  [PASS]');
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('  [FAIL] Wrong cipher parameters');
    Inc(TestsFailed);
  end;
end;

procedure TestMultipleDigests;
var
  md: PEVP_MD;
  size: Integer;
  algName: string;
  success: Boolean;
begin
  WriteLn('Testing multiple digest algorithms...');
  success := True;
  
  // Test SHA1
  md := EVP_sha1();
  if md <> nil then
  begin
    size := EVP_MD_get_size(md);
    WriteLn('  SHA1 size: ', size, ' bytes (expected 20)');
    if size <> 20 then success := False;
  end
  else
    success := False;
  
  // Test SHA384
  md := EVP_sha384();
  if md <> nil then
  begin
    size := EVP_MD_get_size(md);
    WriteLn('  SHA384 size: ', size, ' bytes (expected 48)');
    if size <> 48 then success := False;
  end
  else
    success := False;
  
  // Test SHA512
  md := EVP_sha512();
  if md <> nil then
  begin
    size := EVP_MD_get_size(md);
    WriteLn('  SHA512 size: ', size, ' bytes (expected 64)');
    if size <> 64 then success := False;
  end
  else
    success := False;
  
  if success then
  begin
    WriteLn('  [PASS]');
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('  [FAIL] Some digest algorithms failed');
    Inc(TestsFailed);
  end;
end;

begin
  TestsPassed := 0;
  TestsFailed := 0;
  TestsSkipped := 0;
  SkipCapability := 0;
  SkipOther := 0;
  
  WriteLn('OpenSSL EVP Module Test');
  WriteLn('=======================');
  WriteLn;
  
  // Load OpenSSL
  LoadOpenSSLCore;
  if GetCryptoLibHandle = 0 then
  begin
    WriteLn('ERROR: Failed to load OpenSSL libraries');
    Halt(1);
  end;
  
  WriteLn('OpenSSL version: ', OpenSSL_version(0));
  WriteLn;
  
  // Load EVP module
  if not LoadEVP(GetCryptoLibHandle) then
  begin
    WriteLn('ERROR: Failed to load EVP module');
    UnloadOpenSSLCore;
    Halt(1);
  end;
  
  // Run tests
  TestDigestMD5;
  WriteLn;
  
  TestDigestSHA256;
  WriteLn;
  
  TestCipherAES128CBC;
  WriteLn;
  
  TestDigestByName;
  WriteLn;

  TestCipherByName;
  WriteLn;

  TestMultipleDigests;
  WriteLn;
  
  // Cleanup
  UnloadEVP;
  UnloadOpenSSLCore;
  
  // Summary
  WriteLn('=======================');
  WriteLn(Format('Tests Passed: %d', [TestsPassed]));
  WriteLn(Format('Tests Failed: %d', [TestsFailed]));
  WriteLn(Format('Tests Skipped: %d (capability=%d, other=%d)', [TestsSkipped, SkipCapability, SkipOther]));
  WriteLn(Format('Total Tests:   %d', [TestsPassed + TestsFailed + TestsSkipped]));
  WriteLn;
  
  if TestsFailed > 0 then
  begin
    WriteLn('FAILED: Some tests did not pass');
    Halt(1);
  end
  else
    WriteLn('SUCCESS: All tests passed!');
end.
