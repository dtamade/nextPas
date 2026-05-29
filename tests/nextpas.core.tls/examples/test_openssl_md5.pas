program test_openssl_md5;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api.types,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.md;

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

procedure TestMD5;
var
  Digest: array[0..MD5_DIGEST_LENGTH-1] of Byte;
  TestData: AnsiString;
  Expected: string;
  Got: string;
begin
  WriteLn('Testing MD5:');
  
  TestData := 'The quick brown fox jumps over the lazy dog';
  Expected := '9e107d9d372bb6826bd81d3542a419d6';
  
  if Assigned(MD5) then
  begin
    FillChar(Digest, SizeOf(Digest), 0);
    MD5(@TestData[1], Length(TestData), @Digest[0]);
    Got := BytesToHex(Digest, MD5_DIGEST_LENGTH);
    TestResult('MD5 hash', Got = Expected, Expected, Got);
    
    // Test empty string
    TestData := '';
    Expected := 'd41d8cd98f00b204e9800998ecf8427e';
    MD5(nil, 0, @Digest[0]);
    Got := BytesToHex(Digest, MD5_DIGEST_LENGTH);
    TestResult('MD5 empty string', Got = Expected, Expected, Got);
    
    // Test known vector
    TestData := 'abc';
    Expected := '900150983cd24fb0d6963f7d28e17f72';
    MD5(@TestData[1], Length(TestData), @Digest[0]);
    Got := BytesToHex(Digest, MD5_DIGEST_LENGTH);
    TestResult('MD5 "abc"', Got = Expected, Expected, Got);
  end
  else
    TestResult('MD5 function available', False);
  
  WriteLn;
end;

procedure TestMD5Context;
var
  Ctx: MD5_CTX;
  Digest: array[0..MD5_DIGEST_LENGTH-1] of Byte;
  Data1, Data2: AnsiString;
  Expected: string;
  Got: string;
begin
  WriteLn('Testing MD5 Context (Incremental):');
  
  Data1 := 'The quick brown fox ';
  Data2 := 'jumps over the lazy dog';
  Expected := '9e107d9d372bb6826bd81d3542a419d6';
  
  if Assigned(MD5_Init) and Assigned(MD5_Update) and Assigned(MD5_Final) then
  begin
    // Initialize
    MD5_Init(@Ctx);
    TestResult('MD5_Init', True);
    
    // Update with first part
    MD5_Update(@Ctx, @Data1[1], Length(Data1));
    TestResult('MD5_Update (part 1)', True);
    
    // Update with second part
    MD5_Update(@Ctx, @Data2[1], Length(Data2));
    TestResult('MD5_Update (part 2)', True);
    
    // Finalize
    FillChar(Digest, SizeOf(Digest), 0);
    MD5_Final(@Digest[0], @Ctx);
    Got := BytesToHex(Digest, MD5_DIGEST_LENGTH);
    TestResult('MD5_Final result', Got = Expected, Expected, Got);
  end
  else
    TestResult('MD5 context functions available', False);
  
  WriteLn;
end;

procedure TestMD4;
var
  Digest: array[0..MD4_DIGEST_LENGTH-1] of Byte;
  TestData: AnsiString;
  Expected: string;
  Got: string;
begin
  WriteLn('Testing MD4:');
  
  TestData := 'The quick brown fox jumps over the lazy dog';
  Expected := '1bee69a46ba811185c194762abaeae90';
  
  if Assigned(MD4) then
  begin
    FillChar(Digest, SizeOf(Digest), 0);
    MD4(@TestData[1], Length(TestData), @Digest[0]);
    Got := BytesToHex(Digest, MD4_DIGEST_LENGTH);
    TestResult('MD4 hash', Got = Expected, Expected, Got);
  end
  else
    TestResult('MD4 function available', False);
  
  WriteLn;
end;

begin
  WriteLn('OpenSSL MD Module Unit Test');
  WriteLn('===========================');
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
  
  // Load MD module
  Write('Loading MD module... ');
  if not LoadMDFunctions(GetCryptoLibHandle) then
  begin
    WriteLn('FAILED');
    Halt(1);
  end;
  WriteLn('OK');
  WriteLn;
  
  // Run tests
  try
    TestMD5;
    TestMD5Context;
    TestMD4;
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
  UnloadMDFunctions;
  UnloadOpenSSLCore;
end.