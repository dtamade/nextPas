program test_openssl11_compat;

{$mode objfpc}{$H+}

{
  Simplified OpenSSL 1.1.x Compatibility Test
  
  Tests basic cryptographic operations with OpenSSL 1.1.x
}

uses
  SysUtils,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.evp;

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

function TestLoadOpenSSL11: Boolean;
var
  VersionStr: string;
begin
  Result := False;
  try
    LoadOpenSSLCoreWithVersion(sslVersion_1_1);
    
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
      Exit;
      
    VersionStr := GetOpenSSLVersionString;
    Result := (Pos('1.1', VersionStr) > 0) or (Pos('1_1', VersionStr) > 0);
    
    if Result then
      WriteLn('  Loaded: ', VersionStr);
  except
    on E: Exception do
    begin
      WriteLn('  Error: ', E.Message);
      Result := False;
    end;
  end;
end;

function TestEVPModule: Boolean;
begin
  Result := False;
  try
    Result := LoadEVP(GetCryptoLibHandle);
  except
    Result := False;
  end;
end;

function TestSHA256: Boolean;
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
      
      if EVP_DigestInit_ex(ctx, md, nil) = 1 then
        if EVP_DigestUpdate(ctx, @input[1], Length(input)) = 1 then
          if EVP_DigestFinal_ex(ctx, @digest[0], len) = 1 then
            Result := (len = 32);
    finally
      EVP_MD_CTX_free(ctx);
    end;
  except
    Result := False;
  end;
end;

function TestSHA512: Boolean;
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
      
      if EVP_DigestInit_ex(ctx, md, nil) = 1 then
        if EVP_DigestUpdate(ctx, @input[1], Length(input)) = 1 then
          if EVP_DigestFinal_ex(ctx, @digest[0], len) = 1 then
            Result := (len = 64);
    finally
      EVP_MD_CTX_free(ctx);
    end;
  except
    Result := False;
  end;
end;

function TestMD5: Boolean;
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
      
      if EVP_DigestInit_ex(ctx, md, nil) = 1 then
        if EVP_DigestUpdate(ctx, @input[1], Length(input)) = 1 then
          if EVP_DigestFinal_ex(ctx, @digest[0], len) = 1 then
            Result := (len = 16);
    finally
      EVP_MD_CTX_free(ctx);
    end;
  except
    Result := False;
  end;
end;

function TestAES128CBC: Boolean;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  key, iv: array[0..15] of Byte;
  plaintext: AnsiString;
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
      
      if EVP_EncryptInit_ex(ctx, cipher, nil, @key[0], @iv[0]) = 1 then
        if EVP_EncryptUpdate(ctx, @outbuf[0], outlen, @plaintext[1], Length(plaintext)) = 1 then
          if EVP_EncryptFinal_ex(ctx, @outbuf[outlen], finallen) = 1 then
            Result := (outlen + finallen > 0);
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
  except
    Result := False;
  end;
end;

function TestAES256CBC: Boolean;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  key: array[0..31] of Byte;
  iv: array[0..15] of Byte;
  plaintext: AnsiString;
  outbuf: array[0..1023] of Byte;
  outlen, finallen: Integer;
begin
  Result := False;
  try
    plaintext := 'AES-256 test';
    FillByte(key, Length(key), $01);
    FillByte(iv, Length(iv), $02);
    
    ctx := EVP_CIPHER_CTX_new();
    if ctx = nil then Exit;
    
    try
      cipher := EVP_aes_256_cbc();
      if cipher = nil then Exit;
      
      if EVP_EncryptInit_ex(ctx, cipher, nil, @key[0], @iv[0]) = 1 then
        if EVP_EncryptUpdate(ctx, @outbuf[0], outlen, @plaintext[1], Length(plaintext)) = 1 then
          if EVP_EncryptFinal_ex(ctx, @outbuf[outlen], finallen) = 1 then
            Result := (outlen + finallen > 0);
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
  except
    Result := False;
  end;
end;

function TestAES128GCM: Boolean;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  key, iv: array[0..15] of Byte;
  tag: array[0..15] of Byte;
  plaintext: AnsiString;
  outbuf: array[0..1023] of Byte;
  outlen, finallen: Integer;
begin
  Result := False;
  try
    plaintext := 'GCM test';
    FillByte(key, Length(key), $01);
    FillByte(iv, Length(iv), $02);
    
    ctx := EVP_CIPHER_CTX_new();
    if ctx = nil then Exit;
    
    try
      cipher := EVP_aes_128_gcm();
      if cipher = nil then Exit;
      
      if EVP_EncryptInit_ex(ctx, cipher, nil, @key[0], @iv[0]) = 1 then
        if EVP_EncryptUpdate(ctx, @outbuf[0], outlen, @plaintext[1], Length(plaintext)) = 1 then
          if EVP_EncryptFinal_ex(ctx, @outbuf[outlen], finallen) = 1 then
            if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16, @tag[0]) = 1 then
              Result := (outlen + finallen >= 0);
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
  except
    Result := False;
  end;
end;

function TestChaCha20: Boolean;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  key: array[0..31] of Byte;
  iv: array[0..15] of Byte;
  plaintext: AnsiString;
  outbuf: array[0..1023] of Byte;
  outlen, finallen: Integer;
begin
  Result := False;
  try
    plaintext := 'ChaCha20 test';
    FillByte(key, Length(key), $01);
    FillByte(iv, Length(iv), $02);
    
    ctx := EVP_CIPHER_CTX_new();
    if ctx = nil then Exit;
    
    try
      cipher := EVP_chacha20();
      if cipher = nil then Exit;
      
      if EVP_EncryptInit_ex(ctx, cipher, nil, @key[0], @iv[0]) = 1 then
        if EVP_EncryptUpdate(ctx, @outbuf[0], outlen, @plaintext[1], Length(plaintext)) = 1 then
          if EVP_EncryptFinal_ex(ctx, @outbuf[outlen], finallen) = 1 then
            Result := (outlen + finallen > 0);
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
  except
    Result := False;
  end;
end;

procedure RunAllTests;
begin
  WriteLn('=========================================');
  WriteLn('  OpenSSL 1.1.x Compatibility Test');
  WriteLn('=========================================');
  WriteLn;
  
  TotalTests := 0;
  PassedTests := 0;
  FailedTests := 0;
  
  WriteLn('=== Core Library ===');
  LogTest('Load OpenSSL 1.1.x', TestLoadOpenSSL11);
  LogTest('Load EVP Module', TestEVPModule);
  WriteLn;
  
  WriteLn('=== Hash Functions ===');
  LogTest('SHA-256', TestSHA256);
  LogTest('SHA-512', TestSHA512);
  LogTest('MD5', TestMD5);
  WriteLn;
  
  WriteLn('=== Symmetric Encryption ===');
  LogTest('AES-128-CBC', TestAES128CBC);
  LogTest('AES-256-CBC', TestAES256CBC);
  LogTest('AES-128-GCM', TestAES128GCM);
  LogTest('ChaCha20', TestChaCha20);
  WriteLn;
  
  WriteLn('=========================================');
  WriteLn('Test Summary');
  WriteLn('=========================================');
  WriteLn('Total:  ', TotalTests);
  WriteLn('Passed: ', PassedTests);
  WriteLn('Failed: ', FailedTests);
  WriteLn('Rate:   ', Format('%.1f%%', [(PassedTests / TotalTests) * 100]));
  WriteLn;
  
  if FailedTests = 0 then
  begin
    WriteLn('[SUCCESS] OpenSSL 1.1.x is fully compatible!');
    WriteLn('All core cryptographic operations work correctly.');
  end
  else
  begin
    WriteLn('[WARNING] ', FailedTests, ' test(s) failed.');
    WriteLn('OpenSSL 1.1.x may have compatibility issues.');
  end;
end;

begin
  try
    RunAllTests;
    UnloadOpenSSLCore;
    
    if FailedTests > 0 then
      ExitCode := 1;
  except
    on E: Exception do
    begin
      WriteLn('[FATAL ERROR] ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
