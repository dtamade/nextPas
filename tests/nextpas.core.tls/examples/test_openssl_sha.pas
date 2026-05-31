program test_openssl_sha;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api.types,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.sha;

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

function BytesToHex(const Data: array of Byte): string;
var
  I: Integer;
begin
  Result := '';
  for I := Low(Data) to High(Data) do
    Result := Result + IntToHex(Data[I], 2);
  Result := LowerCase(Result);
end;

procedure TestSHA1;
var
  Digest: array[0..SHA_DIGEST_LENGTH-1] of Byte;
  TestData: AnsiString;
  Expected: string;
  Got: string;
begin
  WriteLn('Testing SHA-1:');
  
  TestData := 'The quick brown fox jumps over the lazy dog';
  Expected := '2fd4e1c67a2d28fced849ee1bb76e7391b93eb12';
  
  if Assigned(SHA1) then
  begin
    SHA1(@TestData[1], Length(TestData), @Digest[0]);
    Got := BytesToHex(Digest);
    TestResult('SHA-1 hash', Got = Expected, Expected, Got);
    
    // Test empty string
    TestData := '';
    Expected := 'da39a3ee5e6b4b0d3255bfef95601890afd80709';
    SHA1(@TestData[1], 0, @Digest[0]);
    Got := BytesToHex(Digest);
    TestResult('SHA-1 empty string', Got = Expected, Expected, Got);
  end
  else
    TestResult('SHA1 function available', False);
  
  WriteLn;
end;

procedure TestSHA256;
var
  Digest: array[0..SHA256_DIGEST_LENGTH-1] of Byte;
  TestData: AnsiString;
  Expected: string;
  Got: string;
begin
  WriteLn('Testing SHA-256:');
  
  TestData := 'The quick brown fox jumps over the lazy dog';
  Expected := 'd7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592';
  
  if Assigned(SHA256) then
  begin
    SHA256(@TestData[1], Length(TestData), @Digest[0]);
    Got := BytesToHex(Digest);
    TestResult('SHA-256 hash', Got = Expected, Expected, Got);
    
    // Test empty string
    TestData := '';
    Expected := 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
    SHA256(@TestData[1], 0, @Digest[0]);
    Got := BytesToHex(Digest);
    TestResult('SHA-256 empty string', Got = Expected, Expected, Got);
  end
  else
    TestResult('SHA256 function available', False);
  
  WriteLn;
end;

procedure TestSHA512;
var
  Digest: array[0..SHA512_DIGEST_LENGTH-1] of Byte;
  TestData: AnsiString;
  Expected: string;
  Got: string;
begin
  WriteLn('Testing SHA-512:');
  
  TestData := 'The quick brown fox jumps over the lazy dog';
  Expected := '07e547d9586f6a73f73fbac0435ed76951218fb7d0c8d788a309d785436bbb642e93a252a954f23912547d1e8a3b5ed6e1bfd7097821233fa0538f3db854fee6';
  
  if Assigned(SHA512) then
  begin
    SHA512(@TestData[1], Length(TestData), @Digest[0]);
    Got := BytesToHex(Digest);
    TestResult('SHA-512 hash', Got = Expected, Expected, Got);
    
    // Test empty string
    TestData := '';
    Expected := 'cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e';
    SHA512(@TestData[1], 0, @Digest[0]);
    Got := BytesToHex(Digest);
    TestResult('SHA-512 empty string', Got = Expected, Expected, Got);
  end
  else
    TestResult('SHA512 function available', False);
  
  WriteLn;
end;

procedure TestSHA384;
var
  Digest: array[0..SHA384_DIGEST_LENGTH-1] of Byte;
  TestData: AnsiString;
  Expected: string;
  Got: string;
begin
  WriteLn('Testing SHA-384:');
  
  TestData := 'The quick brown fox jumps over the lazy dog';
  Expected := 'ca737f1014a48f4c0b6dd43cb177b0afd9e5169367544c494011e3317dbf9a509cb1e5dc1e85a941bbee3d7f2afbc9b1';
  
  if Assigned(SHA384) then
  begin
    SHA384(@TestData[1], Length(TestData), @Digest[0]);
    Got := BytesToHex(Digest);
    TestResult('SHA-384 hash', Got = Expected, Expected, Got);
  end
  else
    TestResult('SHA384 function available', False);
  
  WriteLn;
end;

procedure TestSHA224;
var
  Digest: array[0..SHA224_DIGEST_LENGTH-1] of Byte;
  TestData: AnsiString;
  Expected: string;
  Got: string;
begin
  WriteLn('Testing SHA-224:');
  
  TestData := 'The quick brown fox jumps over the lazy dog';
  Expected := '730e109bd7a8a32b1cb9d9a09aa2325d2430587ddbc0c38bad911525';
  
  if Assigned(SHA224) then
  begin
    SHA224(@TestData[1], Length(TestData), @Digest[0]);
    Got := BytesToHex(Digest);
    TestResult('SHA-224 hash', Got = Expected, Expected, Got);
  end
  else
    TestResult('SHA224 function available', False);
  
  WriteLn;
end;

begin
  WriteLn('OpenSSL SHA Module Unit Test');
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
  
  // Load SHA module
  Write('Loading SHA module... ');
  if not LoadSHAFunctions(GetCryptoLibHandle) then
  begin
    WriteLn('FAILED');
    Halt(1);
  end;
  WriteLn('OK');
  WriteLn;
  
  // Run tests
  try
    TestSHA1;
    TestSHA224;
    TestSHA256;
    TestSHA384;
    TestSHA512;
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
  UnloadOpenSSLCore;
end.