program test_openssl_md;

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

// Test MD5 hash algorithm
procedure TestMD5;
var
  ctx: MD5_CTX;
  digest: array[0..MD5_DIGEST_LENGTH-1] of Byte;
  testData: AnsiString;
  expected, got: string;
begin
  WriteLn('Testing MD5:');
  
  if not Assigned(MD5_Init) or not Assigned(MD5_Update) or not Assigned(MD5_Final) then
  begin
    WriteLn('  MD5 functions not loaded');
    Exit;
  end;
  
  // Test 1: Empty string
  // MD5("") = d41d8cd98f00b204e9800998ecf8427e
  FillChar(ctx, SizeOf(ctx), 0);
  MD5_Init(@ctx);
  MD5_Final(@digest[0], @ctx);
  expected := 'd41d8cd98f00b204e9800998ecf8427e';
  got := BytesToHex(digest, MD5_DIGEST_LENGTH);
  TestResult('MD5 empty string', got = expected, expected, got);
  
  // Test 2: "abc"
  // MD5("abc") = 900150983cd24fb0d6963f7d28e17f72
  testData := 'abc';
  FillChar(ctx, SizeOf(ctx), 0);
  MD5_Init(@ctx);
  MD5_Update(@ctx, @testData[1], Length(testData));
  MD5_Final(@digest[0], @ctx);
  expected := '900150983cd24fb0d6963f7d28e17f72';
  got := BytesToHex(digest, MD5_DIGEST_LENGTH);
  TestResult('MD5 "abc"', got = expected, expected, got);
  
  // Test 3: "message digest"
  // MD5("message digest") = f96b697d7cb7938d525a2f31aaf161d0
  testData := 'message digest';
  FillChar(ctx, SizeOf(ctx), 0);
  MD5_Init(@ctx);
  MD5_Update(@ctx, @testData[1], Length(testData));
  MD5_Final(@digest[0], @ctx);
  expected := 'f96b697d7cb7938d525a2f31aaf161d0';
  got := BytesToHex(digest, MD5_DIGEST_LENGTH);
  TestResult('MD5 "message digest"', got = expected, expected, got);
  
  // Test 4: One-shot MD5 function
  if Assigned(MD5) then
  begin
    testData := 'hello';
    MD5(@testData[1], Length(testData), @digest[0]);
    expected := '5d41402abc4b2a76b9719d911017c592';
    got := BytesToHex(digest, MD5_DIGEST_LENGTH);
    TestResult('MD5 one-shot "hello"', got = expected, expected, got);
  end;
  
  WriteLn;
end;

// Test MD4 hash algorithm
procedure TestMD4;
var
  ctx: MD4_CTX;
  digest: array[0..MD4_DIGEST_LENGTH-1] of Byte;
  testData: AnsiString;
  expected, got: string;
begin
  WriteLn('Testing MD4:');
  
  if not Assigned(MD4_Init) or not Assigned(MD4_Update) or not Assigned(MD4_Final) then
  begin
    WriteLn('  MD4 functions not loaded');
    Exit;
  end;
  
  // Test 1: Empty string
  // MD4("") = 31d6cfe0d16ae931b73c59d7e0c089c0
  FillChar(ctx, SizeOf(ctx), 0);
  MD4_Init(@ctx);
  MD4_Final(@digest[0], @ctx);
  expected := '31d6cfe0d16ae931b73c59d7e0c089c0';
  got := BytesToHex(digest, MD4_DIGEST_LENGTH);
  TestResult('MD4 empty string', got = expected, expected, got);
  
  // Test 2: "abc"
  // MD4("abc") = a448017aaf21d8525fc10ae87aa6729d
  testData := 'abc';
  FillChar(ctx, SizeOf(ctx), 0);
  MD4_Init(@ctx);
  MD4_Update(@ctx, @testData[1], Length(testData));
  MD4_Final(@digest[0], @ctx);
  expected := 'a448017aaf21d8525fc10ae87aa6729d';
  got := BytesToHex(digest, MD4_DIGEST_LENGTH);
  TestResult('MD4 "abc"', got = expected, expected, got);
  
  // Test 3: "message digest"
  // MD4("message digest") = d9130a8164549fe818874806e1c7014b
  testData := 'message digest';
  FillChar(ctx, SizeOf(ctx), 0);
  MD4_Init(@ctx);
  MD4_Update(@ctx, @testData[1], Length(testData));
  MD4_Final(@digest[0], @ctx);
  expected := 'd9130a8164549fe818874806e1c7014b';
  got := BytesToHex(digest, MD4_DIGEST_LENGTH);
  TestResult('MD4 "message digest"', got = expected, expected, got);
  
  WriteLn;
end;

// Test RIPEMD160 hash algorithm
procedure TestRIPEMD160;
var
  ctx: RIPEMD160_CTX;
  digest: array[0..RIPEMD160_DIGEST_LENGTH-1] of Byte;
  testData: AnsiString;
  expected, got: string;
begin
  WriteLn('Testing RIPEMD160:');
  
  if not Assigned(RIPEMD160_Init) or not Assigned(RIPEMD160_Update) or not Assigned(RIPEMD160_Final) then
  begin
    WriteLn('  RIPEMD160 functions not loaded');
    Exit;
  end;
  
  // Test 1: Empty string
  // RIPEMD160("") = 9c1185a5c5e9fc54612808977ee8f548b2258d31
  FillChar(ctx, SizeOf(ctx), 0);
  RIPEMD160_Init(@ctx);
  RIPEMD160_Final(@digest[0], @ctx);
  expected := '9c1185a5c5e9fc54612808977ee8f548b2258d31';
  got := BytesToHex(digest, RIPEMD160_DIGEST_LENGTH);
  TestResult('RIPEMD160 empty string', got = expected, expected, got);
  
  // Test 2: "abc"
  // RIPEMD160("abc") = 8eb208f7e05d987a9b044a8e98c6b087f15a0bfc
  testData := 'abc';
  FillChar(ctx, SizeOf(ctx), 0);
  RIPEMD160_Init(@ctx);
  RIPEMD160_Update(@ctx, @testData[1], Length(testData));
  RIPEMD160_Final(@digest[0], @ctx);
  expected := '8eb208f7e05d987a9b044a8e98c6b087f15a0bfc';
  got := BytesToHex(digest, RIPEMD160_DIGEST_LENGTH);
  TestResult('RIPEMD160 "abc"', got = expected, expected, got);
  
  // Test 3: "message digest"
  // RIPEMD160("message digest") = 5d0689ef49d2fae572b881b123a85ffa21595f36
  testData := 'message digest';
  FillChar(ctx, SizeOf(ctx), 0);
  RIPEMD160_Init(@ctx);
  RIPEMD160_Update(@ctx, @testData[1], Length(testData));
  RIPEMD160_Final(@digest[0], @ctx);
  expected := '5d0689ef49d2fae572b881b123a85ffa21595f36';
  got := BytesToHex(digest, RIPEMD160_DIGEST_LENGTH);
  TestResult('RIPEMD160 "message digest"', got = expected, expected, got);
  
  WriteLn;
end;

// Test incremental hashing
procedure TestIncrementalHashing;
var
  ctx: MD5_CTX;
  digest: array[0..MD5_DIGEST_LENGTH-1] of Byte;
  part1, part2, part3: AnsiString;
  expected, got: string;
begin
  WriteLn('Testing Incremental Hashing:');
  
  if not Assigned(MD5_Init) or not Assigned(MD5_Update) or not Assigned(MD5_Final) then
  begin
    WriteLn('  MD5 functions not loaded');
    Exit;
  end;
  
  // Test: Hash "abcdefghij" in three parts
  // MD5("abcdefghij") = a925576942e94b2ef57a066101b48876
  part1 := 'abc';
  part2 := 'defg';
  part3 := 'hij';
  
  FillChar(ctx, SizeOf(ctx), 0);
  MD5_Init(@ctx);
  MD5_Update(@ctx, @part1[1], Length(part1));
  MD5_Update(@ctx, @part2[1], Length(part2));
  MD5_Update(@ctx, @part3[1], Length(part3));
  MD5_Final(@digest[0], @ctx);
  
  expected := 'a925576942e94b2ef57a066101b48876';
  got := BytesToHex(digest, MD5_DIGEST_LENGTH);
  TestResult('MD5 incremental "abcdefghij"', got = expected, expected, got);
  
  WriteLn;
end;

// Test multiple algorithms on same data
procedure TestMultipleAlgorithms;
var
  testData: AnsiString;
  md4_digest: array[0..MD4_DIGEST_LENGTH-1] of Byte;
  md5_digest: array[0..MD5_DIGEST_LENGTH-1] of Byte;
  ripemd_digest: array[0..RIPEMD160_DIGEST_LENGTH-1] of Byte;
var
  md4_ctx: PMD4_CTX;
  md5_ctx: PMD5_CTX;
  ripemd_ctx: PRIPEMD160_CTX;
begin
  WriteLn('Testing Multiple Algorithms on Same Data:');
  
  testData := 'The quick brown fox jumps over the lazy dog';
  
  // MD4
  if Assigned(MD4_Init) and Assigned(MD4_Update) and Assigned(MD4_Final) then
  begin
    GetMem(md4_ctx, SizeOf(MD4_CTX));
    try
      FillChar(md4_ctx^, SizeOf(MD4_CTX), 0);
      MD4_Init(md4_ctx);
      MD4_Update(md4_ctx, @testData[1], Length(testData));
      MD4_Final(@md4_digest[0], md4_ctx);
      TestResult('MD4 quick brown fox', Length(BytesToHex(md4_digest, MD4_DIGEST_LENGTH)) = 32);
    finally
      FreeMem(md4_ctx);
    end;
  end;
  
  // MD5
  if Assigned(MD5_Init) and Assigned(MD5_Update) and Assigned(MD5_Final) then
  begin
    GetMem(md5_ctx, SizeOf(MD5_CTX));
    try
      FillChar(md5_ctx^, SizeOf(MD5_CTX), 0);
      MD5_Init(md5_ctx);
      MD5_Update(md5_ctx, @testData[1], Length(testData));
      MD5_Final(@md5_digest[0], md5_ctx);
      // MD5("The quick brown fox jumps over the lazy dog") = 9e107d9d372bb6826bd81d3542a419d6
      TestResult('MD5 quick brown fox', 
        BytesToHex(md5_digest, MD5_DIGEST_LENGTH) = '9e107d9d372bb6826bd81d3542a419d6');
    finally
      FreeMem(md5_ctx);
    end;
  end;
  
  // RIPEMD160
  if Assigned(RIPEMD160_Init) and Assigned(RIPEMD160_Update) and Assigned(RIPEMD160_Final) then
  begin
    GetMem(ripemd_ctx, SizeOf(RIPEMD160_CTX));
    try
      FillChar(ripemd_ctx^, SizeOf(RIPEMD160_CTX), 0);
      RIPEMD160_Init(ripemd_ctx);
      RIPEMD160_Update(ripemd_ctx, @testData[1], Length(testData));
      RIPEMD160_Final(@ripemd_digest[0], ripemd_ctx);
      // RIPEMD160("The quick brown fox jumps over the lazy dog") = 37f332f68db77bd9d7edd4969571ad671cf9dd3b
      TestResult('RIPEMD160 quick brown fox',
        BytesToHex(ripemd_digest, RIPEMD160_DIGEST_LENGTH) = '37f332f68db77bd9d7edd4969571ad671cf9dd3b');
    finally
      FreeMem(ripemd_ctx);
    end;
  end;
  
  WriteLn;
end;

begin
  WriteLn('OpenSSL MD (Message Digest) Module Unit Test');
  WriteLn('=============================================');
  WriteLn;
  
  // Load OpenSSL
  Write('Loading OpenSSL libraries... ');
  try
    LoadOpenSSLCore();
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
    TestMD4;
    TestRIPEMD160;
    TestIncrementalHashing;
    TestMultipleAlgorithms;
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
  UnloadMDFunctions();
  UnloadOpenSSLCore();
end.