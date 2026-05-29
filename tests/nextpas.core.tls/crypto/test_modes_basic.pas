program test_modes_basic;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.modes;

function BytesToHex(const data: TBytes): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to Length(data) - 1 do
    Result := Result + IntToHex(data[i], 2);
end;

procedure TestAES_GCM;
var
  key, iv, aad, plaintext, ciphertext, decrypted, tag: TBytes;
begin
  WriteLn('Testing AES-256-GCM...');
  
  // Setup test data
  SetLength(key, 32);  // AES-256
  SetLength(iv, 12);   // Standard GCM IV
  SetLength(aad, 16);  // Additional authenticated data
  SetLength(plaintext, 64);
  
  // Fill with test data
  FillChar(key[0], 32, $42);
  FillChar(iv[0], 12, $43);
  FillChar(aad[0], 16, $44);
  FillChar(plaintext[0], 64, $45);
  
  try
    // Encrypt
    ciphertext := AES_GCM_Encrypt(key, iv, aad, plaintext, tag);
    WriteLn('  Encryption succeeded');
    WriteLn('  Ciphertext length: ', Length(ciphertext));
    WriteLn('  Tag length: ', Length(tag));
    
    // Decrypt
    decrypted := AES_GCM_Decrypt(key, iv, aad, ciphertext, tag);
    WriteLn('  Decryption succeeded');
    
    // Verify
    if Length(decrypted) = Length(plaintext) then
    begin
      if CompareMem(@decrypted[0], @plaintext[0], Length(plaintext)) then
        WriteLn('  [PASS] GCM encrypt/decrypt roundtrip successful')
      else
        WriteLn('  [FAIL] GCM verification failed: data mismatch');
    end
    else
      WriteLn('  [FAIL] GCM verification failed: length mismatch');
      
  except
    on E: Exception do
      WriteLn('  [FAIL] GCM test failed: ', E.Message);
  end;
end;

procedure TestAES_CCM;
var
  key, nonce, aad, plaintext, ciphertext, decrypted, tag: TBytes;
const
  TAG_SIZE = 16;
begin
  WriteLn('Testing AES-256-CCM...');
  
  // Setup test data
  SetLength(key, 32);  // AES-256
  SetLength(nonce, 13); // CCM nonce
  SetLength(aad, 16);
  SetLength(plaintext, 64);
  
  // Fill with test data
  FillChar(key[0], 32, $52);
  FillChar(nonce[0], 13, $53);
  FillChar(aad[0], 16, $54);
  FillChar(plaintext[0], 64, $55);
  
  try
    // Encrypt
    ciphertext := AES_CCM_Encrypt(key, nonce, aad, plaintext, TAG_SIZE, tag);
    WriteLn('  Encryption succeeded');
    WriteLn('  Ciphertext length: ', Length(ciphertext));
    WriteLn('  Tag length: ', Length(tag));
    
    // Decrypt
    decrypted := AES_CCM_Decrypt(key, nonce, aad, ciphertext, tag);
    WriteLn('  Decryption succeeded');
    
    // Verify
    if Length(decrypted) = Length(plaintext) then
    begin
      if CompareMem(@decrypted[0], @plaintext[0], Length(plaintext)) then
        WriteLn('  [PASS] CCM encrypt/decrypt roundtrip successful')
      else
        WriteLn('  [FAIL] CCM verification failed: data mismatch');
    end
    else
      WriteLn('  [FAIL] CCM verification failed: length mismatch');
      
  except
    on E: Exception do
      WriteLn('  [FAIL] CCM test failed: ', E.Message);
  end;
end;

procedure TestAES_XTS;
var
  key1, key2, tweak, plaintext, ciphertext, decrypted: TBytes;
begin
  WriteLn('Testing AES-256-XTS...');
  
  // Setup test data
  SetLength(key1, 32);  // First key
  SetLength(key2, 32);  // Second key
  SetLength(tweak, 16); // Tweak (IV)
  SetLength(plaintext, 512); // XTS works with larger blocks
  
  // Fill with test data
  FillChar(key1[0], 32, $62);
  FillChar(key2[0], 32, $63);
  FillChar(tweak[0], 16, $64);
  FillChar(plaintext[0], 512, $65);
  
  try
    // Encrypt
    ciphertext := AES_XTS_Encrypt(key1, key2, tweak, plaintext);
    WriteLn('  Encryption succeeded');
    WriteLn('  Ciphertext length: ', Length(ciphertext));
    
    // Decrypt
    decrypted := AES_XTS_Decrypt(key1, key2, tweak, ciphertext);
    WriteLn('  Decryption succeeded');
    
    // Verify
    if Length(decrypted) = Length(plaintext) then
    begin
      if CompareMem(@decrypted[0], @plaintext[0], Length(plaintext)) then
        WriteLn('  [PASS] XTS encrypt/decrypt roundtrip successful')
      else
        WriteLn('  [FAIL] XTS verification failed: data mismatch');
    end
    else
      WriteLn('  [FAIL] XTS verification failed: length mismatch');
      
  except
    on E: Exception do
      WriteLn('  [FAIL] XTS test failed: ', E.Message);
  end;
end;

procedure TestAES_OCB;
var
  key, nonce, aad, plaintext, ciphertext, decrypted, tag: TBytes;
begin
  WriteLn('Testing AES-256-OCB...');
  
  // Setup test data
  SetLength(key, 32);  // AES-256
  SetLength(nonce, 12); // OCB nonce
  SetLength(aad, 16);
  SetLength(plaintext, 64);
  
  // Fill with test data
  FillChar(key[0], 32, $72);
  FillChar(nonce[0], 12, $73);
  FillChar(aad[0], 16, $74);
  FillChar(plaintext[0], 64, $75);
  
  try
    // Encrypt
    ciphertext := AES_OCB_Encrypt(key, nonce, aad, plaintext, tag);
    WriteLn('  Encryption succeeded');
    WriteLn('  Ciphertext length: ', Length(ciphertext));
    WriteLn('  Tag length: ', Length(tag));
    
    // Decrypt
    decrypted := AES_OCB_Decrypt(key, nonce, aad, ciphertext, tag);
    WriteLn('  Decryption succeeded');
    
    // Verify
    if Length(decrypted) = Length(plaintext) then
    begin
      if CompareMem(@decrypted[0], @plaintext[0], Length(plaintext)) then
        WriteLn('  [PASS] OCB encrypt/decrypt roundtrip successful')
      else
        WriteLn('  [FAIL] OCB verification failed: data mismatch');
    end
    else
      WriteLn('  [FAIL] OCB verification failed: length mismatch');
      
  except
    on E: Exception do
      WriteLn('  [FAIL] OCB test failed: ', E.Message);
  end;
end;

begin
  WriteLn('=== OpenSSL Modes Module Basic Tests ===');
  WriteLn;
  
  try
    // Load OpenSSL library
    if not LoadOpenSSLLibrary then
    begin
      WriteLn('ERROR: Failed to load OpenSSL library');
      Halt(1);
    end;
    
    // Load EVP functions
    if not LoadEVP(GetCryptoLibHandle) then
    begin
      WriteLn('ERROR: Failed to load EVP functions');
      Halt(1);
    end;
    
    WriteLn('OpenSSL Version: ', GetOpenSSLVersion);
    WriteLn;
    
    // Run tests
    TestAES_GCM;
    WriteLn;
    
    TestAES_CCM;
    WriteLn;
    
    TestAES_XTS;
    WriteLn;
    
    TestAES_OCB;
    WriteLn;
    
    WriteLn('=== All tests completed ===');
    
  except
    on E: Exception do
    begin
      WriteLn('FATAL ERROR: ', E.Message);
      Halt(1);
    end;
  end;
end.
