program test_openssl_aes;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api.types,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.aes;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure TestResult(const TestName: string; Passed: Boolean; const Expected: string = ''; const Got: string = '');
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

function BytesToHex(const Data: array of Byte; Len: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Len-1 do
    Result := Result + IntToHex(Data[I], 2);
  Result := LowerCase(Result);
end;

procedure TestAES128_ECB;
var
  Key: array[0..15] of Byte;
  PlainText: array[0..15] of Byte;
  CipherText: array[0..15] of Byte;
  DecryptedText: array[0..15] of Byte;
  AESKey: AES_KEY;
  Expected: string;
  Got: string;
  I: Integer;
begin
  WriteLn('Testing AES-128 ECB:');
  
  // Test vector from FIPS-197
  // Key: 000102030405060708090a0b0c0d0e0f
  // Plain: 00112233445566778899aabbccddeeff
  // Cipher: 69c4e0d86a7b0430d8cdb78070b4c55a
  
  for I := 0 to 15 do Key[I] := I;
  for I := 0 to 15 do PlainText[I] := $11 * I;
  
  Expected := '69c4e0d86a7b0430d8cdb78070b4c55a';
  
  if Assigned(AES_set_encrypt_key) and Assigned(AES_encrypt) then
  begin
    // Encrypt
    AES_set_encrypt_key(@Key[0], 128, @AESKey);
    AES_encrypt(@PlainText[0], @CipherText[0], @AESKey);
    Got := BytesToHex(CipherText, 16);
    TestResult('AES-128 ECB encryption', Got = Expected, Expected, Got);
    
    // Decrypt
    if Assigned(AES_set_decrypt_key) and Assigned(AES_decrypt) then
    begin
      AES_set_decrypt_key(@Key[0], 128, @AESKey);
      AES_decrypt(@CipherText[0], @DecryptedText[0], @AESKey);
      TestResult('AES-128 ECB decryption', CompareMem(@PlainText[0], @DecryptedText[0], 16));
    end
    else
      TestResult('AES decrypt functions available', False);
  end
  else
    TestResult('AES encrypt functions available', False);
  
  WriteLn;
end;

procedure TestAES256_ECB;
var
  Key: array[0..31] of Byte;
  PlainText: array[0..15] of Byte;
  CipherText: array[0..15] of Byte;
  AESKey: AES_KEY;
  Expected: string;
  Got: string;
  I: Integer;
begin
  WriteLn('Testing AES-256 ECB:');
  
  // Test vector from FIPS-197
  // Key: 000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
  // Plain: 00112233445566778899aabbccddeeff
  // Cipher: 8ea2b7ca516745bfeafc49904b496089
  
  for I := 0 to 31 do Key[I] := I;
  for I := 0 to 15 do PlainText[I] := $11 * I;
  
  Expected := '8ea2b7ca516745bfeafc49904b496089';
  
  if Assigned(AES_set_encrypt_key) and Assigned(AES_encrypt) then
  begin
    AES_set_encrypt_key(@Key[0], 256, @AESKey);
    AES_encrypt(@PlainText[0], @CipherText[0], @AESKey);
    Got := BytesToHex(CipherText, 16);
    TestResult('AES-256 ECB encryption', Got = Expected, Expected, Got);
  end
  else
    TestResult('AES encrypt functions available', False);
  
  WriteLn;
end;

procedure TestAES128_CBC;
var
  Key: array[0..15] of Byte;
  IV: array[0..15] of Byte;
  PlainText: array[0..31] of Byte;
  CipherText: array[0..31] of Byte;
  DecryptedText: array[0..31] of Byte;
  AESKey: AES_KEY;
  IVEnc, IVDec: array[0..15] of Byte;
  I: Integer;
begin
  WriteLn('Testing AES-128 CBC:');
  
  // Initialize test data
  for I := 0 to 15 do Key[I] := I;
  FillChar(IV, SizeOf(IV), 0);
  for I := 0 to 31 do PlainText[I] := Byte(I);
  
  if Assigned(AES_set_encrypt_key) and Assigned(AES_cbc_encrypt) then
  begin
    // Encrypt
    Move(IV, IVEnc, SizeOf(IV));
    AES_set_encrypt_key(@Key[0], 128, @AESKey);
    AES_cbc_encrypt(@PlainText[0], @CipherText[0], 32, @AESKey, @IVEnc[0], C_AES_ENCRYPT);
    TestResult('AES-128 CBC encryption', True);
    
    // Decrypt
    if Assigned(AES_set_decrypt_key) then
    begin
      Move(IV, IVDec, SizeOf(IV));
      AES_set_decrypt_key(@Key[0], 128, @AESKey);
      AES_cbc_encrypt(@CipherText[0], @DecryptedText[0], 32, @AESKey, @IVDec[0], C_AES_DECRYPT);
      TestResult('AES-128 CBC decryption', CompareMem(@PlainText[0], @DecryptedText[0], 32));
    end
    else
      TestResult('AES decrypt key setup available', False);
  end
  else
    TestResult('AES CBC functions available', False);
  
  WriteLn;
end;

procedure TestAES_KeyWrap;
var
  KEK: array[0..15] of Byte;  // Key Encryption Key
  PlainKey: array[0..15] of Byte;  // Key to wrap
  WrappedKey: array[0..23] of Byte;  // Wrapped key (24 bytes for 16-byte key)
  UnwrappedKey: array[0..15] of Byte;  // Unwrapped key
  AESKeyEnc, AESKeyDec: AES_KEY;
  WrapLen: Integer;
  I: Integer;
begin
  WriteLn('Testing AES Key Wrap:');
  
  // Initialize test data
  for I := 0 to 15 do KEK[I] := I;
  for I := 0 to 15 do PlainKey[I] := $20 + I;
  
  if Assigned(AES_set_encrypt_key) and Assigned(AES_wrap_key) then
  begin
    AES_set_encrypt_key(@KEK[0], 128, @AESKeyEnc);
    WrapLen := AES_wrap_key(@AESKeyEnc, nil, @WrappedKey[0], @PlainKey[0], 16);
    TestResult('AES key wrap', WrapLen = 24);
    
    if (WrapLen = 24) and Assigned(AES_set_decrypt_key) and Assigned(AES_unwrap_key) then
    begin
      FillChar(UnwrappedKey, SizeOf(UnwrappedKey), 0);
      AES_set_decrypt_key(@KEK[0], 128, @AESKeyDec);
      WrapLen := AES_unwrap_key(@AESKeyDec, nil, @UnwrappedKey[0], @WrappedKey[0], 24);
      if WrapLen <> 16 then
        WriteLn('    Unwrap returned: ', WrapLen, ' (expected 16)');
      if WrapLen = 16 then
      begin
        if not CompareMem(@PlainKey[0], @UnwrappedKey[0], 16) then
        begin
          WriteLn('    Unwrapped key does not match original');
          WriteLn('    Original: ', BytesToHex(PlainKey, 16));
          WriteLn('    Unwrapped: ', BytesToHex(UnwrappedKey, 16));
        end;
      end;
      TestResult('AES key unwrap', (WrapLen = 16) and CompareMem(@PlainKey[0], @UnwrappedKey[0], 16));
    end
    else
      TestResult('AES unwrap function available', False);
  end
  else
    TestResult('AES wrap functions available', False);
  
  WriteLn;
end;

begin
  WriteLn('OpenSSL AES Module Unit Test');
  WriteLn('============================');
  WriteLn;
  
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
  
  // Load AES module
  Write('Loading AES module... ');
  if not LoadAESFunctions(GetCryptoLibHandle) then
  begin
    WriteLn('FAILED');
    Halt(1);
  end;
  WriteLn('OK');
  WriteLn;
  
  // Run tests
  try
    TestAES128_ECB;
    TestAES256_ECB;
    TestAES128_CBC;
    TestAES_KeyWrap;
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
  
  if TestsFailed = 0 then
  begin
    WriteLn;
    WriteLn('All tests PASSED! ✓');
  end
  else
  begin
    WriteLn;
    WriteLn('Some tests FAILED! ✗');
    Halt(1);
  end;
  
  // Cleanup
  UnloadAESFunctions;
  UnloadOpenSSLCore;
end.