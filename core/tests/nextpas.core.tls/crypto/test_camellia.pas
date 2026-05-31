program test_camellia;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.evp;

var
  TotalTests, PassedTests: Integer;

procedure TestResult(const TestName: string; Success: Boolean; const ErrorMsg: string = '');
begin
  Inc(TotalTests);
  if Success then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(PassedTests);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    if ErrorMsg <> '' then
      WriteLn('       Error: ', ErrorMsg);
  end;
end;

function BytesToHex(const Data: array of Byte; Len: Integer): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to Len - 1 do
    Result := Result + LowerCase(IntToHex(Data[i], 2));
end;

function TestCamellia128_CBC_Encrypt: Boolean;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  key: array[0..15] of Byte;  // 128-bit key
  iv: array[0..15] of Byte;   // 128-bit IV
  plaintext: AnsiString;
  ciphertext: array[0..63] of Byte;
  outlen, tmplen: Integer;
  i: Integer;
begin
  Result := False;
  plaintext := 'Hello, Camellia!';  // 16 bytes
  
  try
    // 初始化密钥和 IV
    for i := 0 to 15 do
    begin
      key[i] := i;
      iv[i] := 15 - i;
    end;
    
    // 获取 Camellia-128-CBC 算法
    cipher := EVP_camellia_128_cbc();
    if not Assigned(cipher) then
    begin
      WriteLn('  Camellia-128-CBC not available');
      Exit;
    end;
    
    ctx := EVP_CIPHER_CTX_new();
    if not Assigned(ctx) then Exit;
    
    try
      // 初始化加密
      if EVP_EncryptInit_ex(ctx, cipher, nil, @key[0], @iv[0]) <> 1 then
      begin
        WriteLn('  EVP_EncryptInit_ex failed');
        Exit;
      end;
      
      // 加密数据
      outlen := 0;
      if EVP_EncryptUpdate(ctx, @ciphertext[0], outlen, @plaintext[1], Length(plaintext)) <> 1 then
      begin
        WriteLn('  EVP_EncryptUpdate failed');
        Exit;
      end;
      
      // 完成加密
      tmplen := 0;
      if EVP_EncryptFinal_ex(ctx, @ciphertext[outlen], tmplen) <> 1 then
      begin
        WriteLn('  EVP_EncryptFinal_ex failed');
        Exit;
      end;
      
      outlen := outlen + tmplen;
      WriteLn('  Encrypted ', Length(plaintext), ' bytes -> ', outlen, ' bytes');
      WriteLn('  Ciphertext: ', Copy(BytesToHex(ciphertext, outlen), 1, 32), '...');
      
      Result := (outlen > 0);
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
  except
    on E: Exception do
      WriteLn('  Exception: ', E.Message);
  end;
end;

function TestCamellia256_CBC_Encrypt: Boolean;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  key: array[0..31] of Byte;  // 256-bit key
  iv: array[0..15] of Byte;   // 128-bit IV
  plaintext: AnsiString;
  ciphertext: array[0..63] of Byte;
  outlen, tmplen: Integer;
  i: Integer;
begin
  Result := False;
  plaintext := 'Camellia-256 test data here!';  // 28 bytes
  
  try
    // 初始化密钥和 IV
    for i := 0 to 31 do
      key[i] := i;
    for i := 0 to 15 do
      iv[i] := 15 - i;
    
    // 获取 Camellia-256-CBC 算法
    cipher := EVP_camellia_256_cbc();
    if not Assigned(cipher) then
    begin
      WriteLn('  Camellia-256-CBC not available');
      Exit;
    end;
    
    ctx := EVP_CIPHER_CTX_new();
    if not Assigned(ctx) then Exit;
    
    try
      // 初始化加密
      if EVP_EncryptInit_ex(ctx, cipher, nil, @key[0], @iv[0]) <> 1 then
      begin
        WriteLn('  EVP_EncryptInit_ex failed');
        Exit;
      end;
      
      // 加密数据
      outlen := 0;
      if EVP_EncryptUpdate(ctx, @ciphertext[0], outlen, @plaintext[1], Length(plaintext)) <> 1 then
      begin
        WriteLn('  EVP_EncryptUpdate failed');
        Exit;
      end;
      
      // 完成加密
      tmplen := 0;
      if EVP_EncryptFinal_ex(ctx, @ciphertext[outlen], tmplen) <> 1 then
      begin
        WriteLn('  EVP_EncryptFinal_ex failed');
        Exit;
      end;
      
      outlen := outlen + tmplen;
      WriteLn('  Encrypted ', Length(plaintext), ' bytes -> ', outlen, ' bytes');
      WriteLn('  Ciphertext: ', Copy(BytesToHex(ciphertext, outlen), 1, 32), '...');
      
      Result := (outlen > 0);
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
  except
    on E: Exception do
      WriteLn('  Exception: ', E.Message);
  end;
end;

function TestCamellia128_ECB: Boolean;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  key: array[0..15] of Byte;
  plaintext: array[0..15] of Byte;  // 单个块
  ciphertext: array[0..31] of Byte;
  outlen, tmplen: Integer;
  i: Integer;
begin
  Result := False;
  
  try
    // 初始化密钥和明文
    for i := 0 to 15 do
    begin
      key[i] := i;
      plaintext[i] := $41 + i;  // 'A', 'B', 'C', ...
    end;
    
    cipher := EVP_camellia_128_ecb();
    if not Assigned(cipher) then
    begin
      WriteLn('  Camellia-128-ECB not available');
      Exit;
    end;
    
    ctx := EVP_CIPHER_CTX_new();
    if not Assigned(ctx) then Exit;
    
    try
      if EVP_EncryptInit_ex(ctx, cipher, nil, @key[0], nil) <> 1 then Exit;
      
      outlen := 0;
      if EVP_EncryptUpdate(ctx, @ciphertext[0], outlen, @plaintext[0], 16) <> 1 then Exit;
      
      tmplen := 0;
      if EVP_EncryptFinal_ex(ctx, @ciphertext[outlen], tmplen) <> 1 then Exit;
      
      outlen := outlen + tmplen;
      WriteLn('  ECB encrypted: ', BytesToHex(ciphertext, 16));
      WriteLn('  Output length: ', outlen);
      
      Result := (outlen >= 16);
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
  except
    on E: Exception do
      WriteLn('  Exception: ', E.Message);
  end;
end;

function TestCamellia_EncryptDecrypt: Boolean;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  key: array[0..15] of Byte;
  iv: array[0..15] of Byte;
  plaintext: AnsiString;
  ciphertext: array[0..63] of Byte;
  decrypted: array[0..63] of Byte;
  outlen, tmplen: Integer;
  dec_len: Integer;
  i: Integer;
  match: Boolean;
begin
  Result := False;
  plaintext := 'Round-trip test!';
  
  try
    // 初始化密钥和 IV
    for i := 0 to 15 do
    begin
      key[i] := $AA xor i;
      iv[i] := $55 xor i;
    end;
    
    cipher := EVP_camellia_128_cbc();
    if not Assigned(cipher) then Exit;
    
    // 加密
    ctx := EVP_CIPHER_CTX_new();
    if not Assigned(ctx) then Exit;
    
    try
      if EVP_EncryptInit_ex(ctx, cipher, nil, @key[0], @iv[0]) <> 1 then Exit;
      
      outlen := 0;
      if EVP_EncryptUpdate(ctx, @ciphertext[0], outlen, @plaintext[1], Length(plaintext)) <> 1 then Exit;
      
      tmplen := 0;
      if EVP_EncryptFinal_ex(ctx, @ciphertext[outlen], tmplen) <> 1 then Exit;
      
      outlen := outlen + tmplen;
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
    WriteLn('  Encrypted length: ', outlen);
    
    // 解密
    ctx := EVP_CIPHER_CTX_new();
    if not Assigned(ctx) then Exit;
    
    try
      if EVP_DecryptInit_ex(ctx, cipher, nil, @key[0], @iv[0]) <> 1 then Exit;
      
      dec_len := 0;
      if EVP_DecryptUpdate(ctx, @decrypted[0], dec_len, @ciphertext[0], outlen) <> 1 then Exit;
      
      tmplen := 0;
      if EVP_DecryptFinal_ex(ctx, @decrypted[dec_len], tmplen) <> 1 then Exit;
      
      dec_len := dec_len + tmplen;
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
    WriteLn('  Decrypted length: ', dec_len);
    
    // 验证
    match := (dec_len = Length(plaintext));
    if match then
    begin
      for i := 0 to dec_len - 1 do
      begin
        if decrypted[i] <> Byte(plaintext[i + 1]) then
        begin
          match := False;
          Break;
        end;
      end;
    end;
    
    Result := match;
    
    if match then
      WriteLn('  ✅ Round-trip successful: plaintext matches')
    else
      WriteLn('  ❌ Round-trip failed: plaintext mismatch');
  except
    on E: Exception do
      WriteLn('  Exception: ', E.Message);
  end;
end;

begin
  TotalTests := 0;
  PassedTests := 0;
  
  WriteLn;
  WriteLn('========================================');
  WriteLn('  Camellia Module Test');
  WriteLn('========================================');
  WriteLn;
  
  try
    // 加载 OpenSSL
    if not LoadOpenSSLLibrary then
    begin
      WriteLn('ERROR: Failed to load OpenSSL library');
      ExitCode := 1;
      Exit;
    end;
    
    // 加载 EVP 函数
    if not LoadEVP(GetCryptoLibHandle) then
    begin
      WriteLn('ERROR: Failed to load EVP functions');
      ExitCode := 1;
      Exit;
    end;
    
    WriteLn('OpenSSL loaded successfully');
    WriteLn;
    
    // 运行测试
    WriteLn('Testing Camellia-128-CBC Encryption...');
    TestResult('Camellia-128-CBC Encryption', TestCamellia128_CBC_Encrypt);
    WriteLn;
    
    WriteLn('Testing Camellia-256-CBC Encryption...');
    TestResult('Camellia-256-CBC Encryption', TestCamellia256_CBC_Encrypt);
    WriteLn;
    
    WriteLn('Testing Camellia-128-ECB...');
    TestResult('Camellia-128-ECB', TestCamellia128_ECB);
    WriteLn;
    
    WriteLn('Testing Camellia Encrypt/Decrypt Round-trip...');
    TestResult('Camellia Round-trip', TestCamellia_EncryptDecrypt);
    WriteLn;
    
    // 总结
    WriteLn('========================================');
    WriteLn(Format('Results: %d/%d tests passed (%.1f%%)', 
      [PassedTests, TotalTests, (PassedTests / TotalTests) * 100]));
    WriteLn('========================================');
    WriteLn;
    
    if PassedTests = TotalTests then
    begin
      WriteLn('✅ ALL TESTS PASSED');
      ExitCode := 0;
    end
    else
    begin
      WriteLn('⚠️  SOME TESTS FAILED');
      ExitCode := 1;
    end;
    
  except
    on E: Exception do
    begin
      WriteLn('FATAL ERROR: ', E.Message);
      ExitCode := 2;
    end;
  end;
  
  WriteLn;
end.
