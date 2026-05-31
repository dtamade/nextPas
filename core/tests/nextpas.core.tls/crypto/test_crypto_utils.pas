program test_crypto_utils;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.crypto.utils,
  nextpas.core.tls.openssl.api.core;

var
  Total, Passed: Integer;

procedure Test(const Name: string; Success: Boolean; const AExpected, AActual: TBytes);
begin
  Inc(Total);
  if Success then
  begin
    Inc(Passed);
    WriteLn('[PASS] ', Name);
  end
  else
  begin
    WriteLn('[FAIL] ', Name);
    if Length(AExpected) > 0 then
      WriteLn('  Expected: ', TCryptoUtils.BytesToHex(AExpected));
    if Length(AActual) > 0 then
      WriteLn('  Actual:   ', TCryptoUtils.BytesToHex(AActual));
  end;
end;

procedure Test(const Name: string; Success: Boolean);
begin
  Test(Name, Success, nil, nil);
end;

var
  LData, LKey, LIV, LCipher, LDecrypt, LHash: TBytes;
  LHex: string;
begin
  WriteLn('=== Crypto Utils Test ===');
  WriteLn;
  
  LoadOpenSSLCore();
  WriteLn('OpenSSL: ', GetOpenSSLVersionString);
  WriteLn;
  
  Total := 0;
  Passed := 0;
  
  // AES-GCM
  WriteLn('--- AES-GCM ---');
  LData := TEncoding.UTF8.GetBytes('Hello!');
  LKey := TCryptoUtils.GenerateKey(256);
  LIV := TCryptoUtils.GenerateIV(12);
  LCipher := TCryptoUtils.AES_GCM_Encrypt(LData, LKey, LIV);
  LDecrypt := TCryptoUtils.AES_GCM_Decrypt(LCipher, LKey, LIV);
  Test('AES-GCM roundtrip', CompareMem(@LData[0], @LDecrypt[0], Length(LData)), LData, LDecrypt);
  
  // AES-CBC
  WriteLn('--- AES-CBC ---');
  LIV := TCryptoUtils.GenerateIV(16);
  LCipher := TCryptoUtils.AES_CBC_Encrypt(LData, LKey, LIV);
  LDecrypt := TCryptoUtils.AES_CBC_Decrypt(LCipher, LKey, LIV);
  Test('AES-CBC roundtrip', CompareMem(@LData[0], @LDecrypt[0], Length(LData)), LData, LDecrypt);
  
  // SHA-256
  WriteLn('--- SHA-256 ---');
  LHash := TCryptoUtils.SHA256('abc');
  Test('SHA-256 length', Length(LHash) = 32);
  Test('SHA-256 known vector',
    UpperCase(TCryptoUtils.BytesToHex(LHash)) = 
    'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD');
  
  // SHA-512
  WriteLn('--- SHA-512 ---');
  LHash := TCryptoUtils.SHA512('test');
  Test('SHA-512 length', Length(LHash) = 64);
  
  // Random
  WriteLn('--- Random ---');
  Test('SecureRandom 32', Length(TCryptoUtils.SecureRandom(32)) = 32);
  Test('GenerateKey 256', Length(TCryptoUtils.GenerateKey(256)) = 32);
  
  // Hex
  WriteLn('--- Hex ---');
  SetLength(LData, 3);
  LData[0] := $AB; LData[1] := $CD; LData[2] := $EF;
  LHex := TCryptoUtils.BytesToHex(LData);
  Test('BytesToHex', UpperCase(LHex) = 'ABCDEF');
  Test('HexToBytes', Length(TCryptoUtils.HexToBytes(LHex)) = 3);
  
  WriteLn;
  WriteLn('========================================');
  WriteLn('RESULT: ', Passed, '/', Total, ' passed');
  if Passed = Total then
    WriteLn('✓ ALL TESTS PASSED!')
  else
    WriteLn('✗ ', Total - Passed, ' tests failed');
  WriteLn('========================================');
  
  if Passed <> Total then
    Halt(1);
    
  WriteLn;
  WriteLn('Press Enter...');
  ReadLn;
end.
