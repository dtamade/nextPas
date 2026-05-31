program test_algorithms_batch;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.evp;

type
  TAlgorithmResult = record
    Name: string;
    AlgType: string;  // 'hash' or 'cipher'
    Available: Boolean;
    Tested: Boolean;
    Passed: Boolean;
    Note: string;
  end;

var
  Results: array of TAlgorithmResult;

procedure AddResult(const AName, AAlgType: string; AAvailable, ATested, APassed: Boolean; const ANote: string = '');
begin
  SetLength(Results, Length(Results) + 1);
  Results[High(Results)].Name := AName;
  Results[High(Results)].AlgType := AAlgType;
  Results[High(Results)].Available := AAvailable;
  Results[High(Results)].Tested := ATested;
  Results[High(Results)].Passed := APassed;
  Results[High(Results)].Note := ANote;
end;

function TestHashAlgorithm(const AlgName: string): Boolean;
var
  md: PEVP_MD;
  ctx: PEVP_MD_CTX;
  data: AnsiString;
  hash: array[0..127] of Byte;
  hash_len: Cardinal;
begin
  Result := False;
  
  // Check availability
  md := EVP_get_digestbyname(PAnsiChar(AlgName));
  if md = nil then
    Exit;
    
  // Quick test
  data := 'test';
  ctx := EVP_MD_CTX_new();
  if ctx = nil then Exit;
  
  try
    if EVP_DigestInit_ex(ctx, md, nil) <> 1 then Exit;
    if EVP_DigestUpdate(ctx, PAnsiChar(data), Length(data)) <> 1 then Exit;
    hash_len := 128;
    if EVP_DigestFinal_ex(ctx, @hash[0], hash_len) <> 1 then Exit;
    Result := True;
  finally
    EVP_MD_CTX_free(ctx);
  end;
end;

function TestCipherAlgorithm(const AlgName: string): Boolean;
var
  cipher: PEVP_CIPHER;
  ctx: PEVP_CIPHER_CTX;
  key: array[0..31] of Byte;
  iv: array[0..15] of Byte;
  plaintext: AnsiString;
  encrypted: array[0..127] of Byte;
  enc_len, final_len: Integer;
  i: Integer;
begin
  Result := False;
  
  // Check availability
  cipher := EVP_get_cipherbyname(PAnsiChar(AlgName));
  if cipher = nil then
    Exit;
    
  // Quick test
  for i := 0 to 31 do key[i] := Byte(i);
  for i := 0 to 15 do iv[i] := Byte(i);
  plaintext := 'test data';
  
  ctx := EVP_CIPHER_CTX_new();
  if ctx = nil then Exit;
  
  try
    if EVP_EncryptInit_ex(ctx, cipher, nil, @key[0], @iv[0]) <> 1 then Exit;
    enc_len := 0;
    if EVP_EncryptUpdate(ctx, @encrypted[0], enc_len, @plaintext[1], Length(plaintext)) <> 1 then Exit;
    final_len := 0;
    if EVP_EncryptFinal_ex(ctx, @encrypted[enc_len], final_len) <> 1 then Exit;
    Result := True;
  finally
    EVP_CIPHER_CTX_free(ctx);
  end;
end;

procedure TestHashAlgorithms;
const
  HashAlgorithms: array[0..10] of string = (
    'sha256', 'sha512', 'sha3-256', 'sha3-512',
    'blake2b512', 'blake2s256', 
    'ripemd160', 'whirlpool', 'md5', 'sha1', 'sm3'
  );
var
  i: Integer;
  available, passed: Boolean;
begin
  WriteLn('Testing Hash Algorithms:');
  WriteLn('----------------------------------------');
  
  for i := Low(HashAlgorithms) to High(HashAlgorithms) do
  begin
    Write('  ', HashAlgorithms[i]:20, ' ... ');
    passed := TestHashAlgorithm(HashAlgorithms[i]);
    available := EVP_get_digestbyname(PAnsiChar(HashAlgorithms[i])) <> nil;
    
    if passed then
    begin
      WriteLn('✓ PASS');
      AddResult(HashAlgorithms[i], 'hash', True, True, True);
    end
    else if available then
    begin
      WriteLn('✗ FAIL (available but test failed)');
      AddResult(HashAlgorithms[i], 'hash', True, True, False, 'Test failed');
    end
    else
    begin
      WriteLn('- N/A (not available)');
      AddResult(HashAlgorithms[i], 'hash', False, False, False, 'Not in provider');
    end;
  end;
  WriteLn;
end;

procedure TestCipherAlgorithms;
const
  CipherAlgorithms: array[0..14] of string = (
    'aes-256-cbc', 'aes-128-gcm', 'camellia-256-cbc',
    'chacha20', 'des-ede3-cbc',
    'bf-cbc', 'cast5-cbc', 'rc2-cbc', 'rc4', 
    'idea-cbc', 'seed-cbc', 'aria-256-cbc',
    'sm4-cbc', 'aes-256-xts', 'chacha20-poly1305'
  );
var
  i: Integer;
  available, passed: Boolean;
begin
  WriteLn('Testing Cipher Algorithms:');
  WriteLn('----------------------------------------');
  
  for i := Low(CipherAlgorithms) to High(CipherAlgorithms) do
  begin
    Write('  ', CipherAlgorithms[i]:20, ' ... ');
    passed := TestCipherAlgorithm(CipherAlgorithms[i]);
    available := EVP_get_cipherbyname(PAnsiChar(CipherAlgorithms[i])) <> nil;
    
    if passed then
    begin
      WriteLn('✓ PASS');
      AddResult(CipherAlgorithms[i], 'cipher', True, True, True);
    end
    else if available then
    begin
      WriteLn('✗ FAIL (available but test failed)');
      AddResult(CipherAlgorithms[i], 'cipher', True, True, False, 'Test failed');
    end
    else
    begin
      WriteLn('- N/A (not available)');
      AddResult(CipherAlgorithms[i], 'cipher', False, False, False, 'Not in provider');
    end;
  end;
  WriteLn;
end;

procedure PrintSummary;
var
  i: Integer;
  TotalHash, TotalCipher: Integer;
  AvailHash, AvailCipher: Integer;
  PassedHash, PassedCipher: Integer;
begin
  TotalHash := 0; TotalCipher := 0;
  AvailHash := 0; AvailCipher := 0;
  PassedHash := 0; PassedCipher := 0;
  
  for i := 0 to High(Results) do
  begin
    if Results[i].AlgType = 'hash' then
    begin
      Inc(TotalHash);
      if Results[i].Available then Inc(AvailHash);
      if Results[i].Passed then Inc(PassedHash);
    end
    else
    begin
      Inc(TotalCipher);
      if Results[i].Available then Inc(AvailCipher);
      if Results[i].Passed then Inc(PassedCipher);
    end;
  end;
  
  WriteLn('========================================');
  WriteLn('SUMMARY');
  WriteLn('========================================');
  WriteLn;
  WriteLn('Hash Algorithms:');
  WriteLn('  Total:     ', TotalHash);
  if TotalHash > 0 then
  begin
    WriteLn('  Available: ', AvailHash, ' (', FormatFloat('0.0', (AvailHash/TotalHash)*100), '%)');
    WriteLn('  Passed:    ', PassedHash, ' (', FormatFloat('0.0', (PassedHash/TotalHash)*100), '%)');
  end
  else
    WriteLn('  (No hash algorithm tests recorded)');
  WriteLn;
  WriteLn('Cipher Algorithms:');
  WriteLn('  Total:     ', TotalCipher);
  if TotalCipher > 0 then
  begin
    WriteLn('  Available: ', AvailCipher, ' (', FormatFloat('0.0', (AvailCipher/TotalCipher)*100), '%)');
    WriteLn('  Passed:    ', PassedCipher, ' (', FormatFloat('0.0', (PassedCipher/TotalCipher)*100), '%)');
  end
  else
    WriteLn('  (No cipher algorithm tests recorded)');
  WriteLn;
  WriteLn('Overall:');
  WriteLn('  Total:     ', TotalHash + TotalCipher);
  WriteLn('  Available: ', AvailHash + AvailCipher);
  WriteLn('  Passed:    ', PassedHash + PassedCipher);
  WriteLn('========================================');
end;

begin
  WriteLn('========================================');
  WriteLn('  Algorithm Availability Batch Test');
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
    TestHashAlgorithms;
    TestCipherAlgorithms;
    
    // Print summary
    PrintSummary;
    
  except
    on E: Exception do
    begin
      WriteLn('EXCEPTION: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
