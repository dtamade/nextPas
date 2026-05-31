program test_blowfish;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.evp;

type
  TTestResult = record
    TestName: string;
    Passed: Boolean;
    ErrorMsg: string;
  end;

var
  Results: array of TTestResult;
  PassCount: Integer = 0;

procedure AddResult(const TestName: string; Passed: Boolean; const ErrorMsg: string = '');
begin
  SetLength(Results, Length(Results) + 1);
  Results[High(Results)].TestName := TestName;
  Results[High(Results)].Passed := Passed;
  Results[High(Results)].ErrorMsg := ErrorMsg;
  if Passed then
    Inc(PassCount);
end;

function BytesToHex(const Data: array of Byte; Len: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Len - 1 do
    Result := Result + IntToHex(Data[I], 2);
end;

function EncryptDecryptTest(const CipherName: string; const PlainText: string): Boolean;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  key: array[0..15] of Byte;
  iv: array[0..7] of Byte;
  plaindata: TBytes;
  encrypted: array[0..255] of Byte;
  decrypted: array[0..255] of Byte;
  enc_len, dec_len, final_len: Integer;
  i: Integer;
begin
  Result := False;
  
  // Initialize key and IV
  for i := 0 to 15 do
    key[i] := Byte(i);
  for i := 0 to 7 do
    iv[i] := Byte(i);
    
  plaindata := TEncoding.UTF8.GetBytes(PlainText);
  
  // Get cipher
  cipher := EVP_get_cipherbyname(PAnsiChar(CipherName));
    
  if cipher = nil then
  begin
    WriteLn('  Cipher not available: ', CipherName);
    Exit;
  end;
  
  // No need to free cipher from EVP_get_cipherbyname
  begin
    // Encrypt
    ctx := EVP_CIPHER_CTX_new();
    if ctx = nil then Exit;
    
    try
      if EVP_EncryptInit_ex(ctx, cipher, nil, @key[0], @iv[0]) <> 1 then
      begin
        WriteLn('  EncryptInit failed');
        Exit;
      end;
      
      enc_len := 0;
      if EVP_EncryptUpdate(ctx, @encrypted[0], enc_len, @plaindata[0], Length(plaindata)) <> 1 then
      begin
        WriteLn('  EncryptUpdate failed');
        Exit;
      end;
      
      final_len := 0;
      if EVP_EncryptFinal_ex(ctx, @encrypted[enc_len], final_len) <> 1 then
      begin
        WriteLn('  EncryptFinal failed');
        Exit;
      end;
      
      enc_len := enc_len + final_len;
      WriteLn('  Encrypted length: ', enc_len, ' bytes');
      WriteLn('  Encrypted: ', Copy(BytesToHex(encrypted, enc_len), 1, 32), '...');
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
    // Decrypt
    ctx := EVP_CIPHER_CTX_new();
    if ctx = nil then Exit;
    
    try
      if EVP_DecryptInit_ex(ctx, cipher, nil, @key[0], @iv[0]) <> 1 then
      begin
        WriteLn('  DecryptInit failed');
        Exit;
      end;
      
      dec_len := 0;
      if EVP_DecryptUpdate(ctx, @decrypted[0], dec_len, @encrypted[0], enc_len) <> 1 then
      begin
        WriteLn('  DecryptUpdate failed');
        Exit;
      end;
      
      final_len := 0;
      if EVP_DecryptFinal_ex(ctx, @decrypted[dec_len], final_len) <> 1 then
      begin
        WriteLn('  DecryptFinal failed');
        Exit;
      end;
      
      dec_len := dec_len + final_len;
      
      // Verify
      if dec_len = Length(plaindata) then
      begin
        Result := CompareMem(@decrypted[0], @plaindata[0], dec_len);
        if Result then
          WriteLn('  ✓ Decryption successful, text matches')
        else
          WriteLn('  ✗ Decryption successful but text mismatch');
      end
      else
        WriteLn('  ✗ Length mismatch: expected ', Length(plaindata), ' got ', dec_len);
        
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
  end;
end;

procedure TestBlowfishCBC;
begin
  WriteLn('Testing Blowfish-CBC...');
  if EncryptDecryptTest('bf-cbc', 'Hello, Blowfish!') then
    AddResult('Blowfish-CBC', True)
  else
    AddResult('Blowfish-CBC', False, 'Encryption/Decryption failed');
end;

procedure TestBlowfishECB;
begin
  WriteLn('Testing Blowfish-ECB...');
  if EncryptDecryptTest('bf-ecb', 'Hello, Blowfish!') then
    AddResult('Blowfish-ECB', True)
  else
    AddResult('Blowfish-ECB', False, 'Encryption/Decryption failed');
end;

procedure TestBlowfishCFB;
begin
  WriteLn('Testing Blowfish-CFB...');
  if EncryptDecryptTest('bf-cfb', 'Hello, Blowfish!') then
    AddResult('Blowfish-CFB', True)
  else
    AddResult('Blowfish-CFB', False, 'Encryption/Decryption failed');
end;

procedure TestBlowfishOFB;
begin
  WriteLn('Testing Blowfish-OFB...');
  if EncryptDecryptTest('bf-ofb', 'Hello, Blowfish!') then
    AddResult('Blowfish-OFB', True)
  else
    AddResult('Blowfish-OFB', False, 'Encryption/Decryption failed');
end;

procedure PrintResults;
var
  I: Integer;
  TotalTests: Integer;
  PassRate: Double;
begin
  WriteLn;
  WriteLn('========================================');
  TotalTests := Length(Results);
  if TotalTests > 0 then
    PassRate := (PassCount / TotalTests) * 100
  else
    PassRate := 0;
    
  WriteLn('Results: ', PassCount, '/', TotalTests, ' tests passed (', 
          FormatFloat('0.0', PassRate), '%)');
  WriteLn('========================================');
  WriteLn;
  
  for I := 0 to High(Results) do
  begin
    if Results[I].Passed then
      WriteLn('[PASS] ', Results[I].TestName)
    else
      WriteLn('[FAIL] ', Results[I].TestName, ': ', Results[I].ErrorMsg);
  end;
  
  WriteLn;
  if PassCount = TotalTests then
    WriteLn('✅ ALL TESTS PASSED')
  else if PassCount = 0 then
    WriteLn('⚠️  ALL TESTS FAILED - Algorithm not available')
  else
    WriteLn('❌ SOME TESTS FAILED');
end;

begin
  WriteLn('========================================');
  WriteLn('  Blowfish Module Test');
  WriteLn('========================================');
  WriteLn;
  
  try
    if not LoadOpenSSLLibrary then
    begin
      WriteLn('ERROR: Failed to load OpenSSL library');
      Halt(1);
    end;
    
    if not LoadEVP(GetCryptoLibHandle) then
    begin
      WriteLn('ERROR: Failed to load EVP functions');
      Halt(1);
    end;
    
    WriteLn('OpenSSL loaded successfully');
    WriteLn;
    
    // Run tests
    TestBlowfishCBC;
    WriteLn;
    TestBlowfishECB;
    WriteLn;
    TestBlowfishCFB;
    WriteLn;
    TestBlowfishOFB;
    
    // Print results
    PrintResults;
    
  except
    on E: Exception do
    begin
      WriteLn('EXCEPTION: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
  
  if PassCount <> Length(Results) then
    Halt(1);
end.
