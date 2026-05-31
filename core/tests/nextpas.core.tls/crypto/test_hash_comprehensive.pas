program test_hash_comprehensive;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils,
  nextpas.core.tls.openssl.api;

type
  TTestResult = record
    Name: string;
    Success: Boolean;
    Skipped: Boolean;
    ErrorMsg: string;
  end;

var
  Results: array of TTestResult;
  TotalTests, PassedTests, SkippedTests: Integer;

procedure AddResult(const AName: string; ASuccess: Boolean; const AError: string = '';
  ASkipped: Boolean = False);
begin
  SetLength(Results, Length(Results) + 1);
  Results[High(Results)].Name := AName;
  Results[High(Results)].Success := ASuccess;
  Results[High(Results)].Skipped := ASkipped;
  Results[High(Results)].ErrorMsg := AError;
  Inc(TotalTests);
  if ASkipped then
    Inc(SkippedTests)
  else if ASuccess then
    Inc(PassedTests);
end;

function BytesToHex(const Data: array of Byte; Len: Integer): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to Len - 1 do
    Result := Result + IntToHex(Data[i], 2);
end;

procedure PrintSeparator;
begin
  WriteLn('========================================');
end;

procedure PrintResults;
var
  i: Integer;
begin
  WriteLn;
  PrintSeparator;
  WriteLn('Test Results Summary');
  PrintSeparator;
  WriteLn;
  
  for i := 0 to High(Results) do
  begin
    if Results[i].Skipped then
    begin
      WriteLn('  [SKIP] ', Results[i].Name);
      if Results[i].ErrorMsg <> '' then
        WriteLn('         Reason: ', Results[i].ErrorMsg);
    end
    else if Results[i].Success then
      WriteLn('  [PASS] ', Results[i].Name)
    else
    begin
      WriteLn('  [FAIL] ', Results[i].Name);
      if Results[i].ErrorMsg <> '' then
        WriteLn('         Error: ', Results[i].ErrorMsg);
    end;
  end;
  
  WriteLn;
  PrintSeparator;
  if (TotalTests - SkippedTests) > 0 then
    WriteLn(Format('Total: %d tests, %d passed, %d failed, %d skipped (%.1f%% executed pass rate)',
      [TotalTests, PassedTests, TotalTests - PassedTests - SkippedTests, SkippedTests,
       (PassedTests / (TotalTests - SkippedTests)) * 100]))
  else
    WriteLn(Format('Total: %d tests, %d passed, %d failed, %d skipped (all skipped)',
      [TotalTests, PassedTests, TotalTests - PassedTests - SkippedTests, SkippedTests]));
  PrintSeparator;
end;

// Generic hash function test
function TestHash(const AlgName: string; md: PEVP_MD; 
  const Input: string; const ExpectedHex: string): Boolean;
var
  ctx: PEVP_MD_CTX;
  digest: array[0..63] of Byte;  // Max 512-bit hash
  digest_len: Cardinal;
  result_hex: string;
begin
  Result := False;
  
  WriteLn;
  WriteLn('Testing ', AlgName, '...');
  
  if md = nil then
  begin
    AddResult(AlgName + ': Get algorithm', False, 'Algorithm not available', True);
    WriteLn('  [SKIP] Algorithm not available');
    Exit;
  end;
  
  ctx := EVP_MD_CTX_new();
  if ctx = nil then
  begin
    AddResult(AlgName + ': Create context', False, 'Context creation failed');
    Exit;
  end;
  
  try
    // Initialize
    if EVP_DigestInit_ex(ctx, md, nil) <> 1 then
    begin
      AddResult(AlgName + ': Init', False, 'Initialization failed');
      Exit;
    end;
    
    // Update with data
    if EVP_DigestUpdate(ctx, PAnsiChar(Input), Length(Input)) <> 1 then
    begin
      AddResult(AlgName + ': Update', False, 'Update failed');
      Exit;
    end;
    
    // Finalize
    if EVP_DigestFinal_ex(ctx, @digest[0], @digest_len) <> 1 then
    begin
      AddResult(AlgName + ': Final', False, 'Finalization failed');
      Exit;
    end;
    
    result_hex := BytesToHex(digest, digest_len);
    WriteLn('  Input:    "', Input, '"');
    WriteLn('  Output:   ', result_hex);
    WriteLn('  Expected: ', ExpectedHex);
    
    if UpperCase(result_hex) = UpperCase(ExpectedHex) then
    begin
      WriteLn('  [PASS] Hash matches!');
      AddResult(AlgName, True);
      Result := True;
    end
    else
    begin
      WriteLn('  [FAIL] Hash mismatch!');
      AddResult(AlgName, False, 'Hash value incorrect');
    end;
    
  finally
    EVP_MD_CTX_free(ctx);
  end;
end;

// Test streaming/incremental hashing
procedure TestIncrementalHash;
var
  ctx: PEVP_MD_CTX;
  md: PEVP_MD;
  digest: array[0..31] of Byte;
  digest_len: Cardinal;
  result_hex: string;
  expected: string;
begin
  WriteLn;
  WriteLn('Testing incremental hashing (SHA-256)...');
  
  md := EVP_sha256();
  if md = nil then
  begin
    AddResult('Incremental: Get SHA-256', False, 'Algorithm not available');
    Exit;
  end;
  
  ctx := EVP_MD_CTX_new();
  if ctx = nil then
  begin
    AddResult('Incremental: Create context', False, 'Context creation failed');
    Exit;
  end;
  
  try
    // Initialize
    if EVP_DigestInit_ex(ctx, md, nil) <> 1 then
    begin
      AddResult('Incremental: Init', False, 'Initialization failed');
      Exit;
    end;
    
    // Update in chunks
    WriteLn('  [+] Updating with "Hello"');
    if EVP_DigestUpdate(ctx, PAnsiChar('Hello'), 5) <> 1 then
    begin
      AddResult('Incremental: Update 1', False, 'First update failed');
      Exit;
    end;
    
    WriteLn('  [+] Updating with ", "');
    if EVP_DigestUpdate(ctx, PAnsiChar(', '), 2) <> 1 then
    begin
      AddResult('Incremental: Update 2', False, 'Second update failed');
      Exit;
    end;
    
    WriteLn('  [+] Updating with "World!"');
    if EVP_DigestUpdate(ctx, PAnsiChar('World!'), 6) <> 1 then
    begin
      AddResult('Incremental: Update 3', False, 'Third update failed');
      Exit;
    end;
    
    // Finalize
    if EVP_DigestFinal_ex(ctx, @digest[0], @digest_len) <> 1 then
    begin
      AddResult('Incremental: Final', False, 'Finalization failed');
      Exit;
    end;
    
    result_hex := BytesToHex(digest, digest_len);
    // SHA-256("Hello, World!")
    expected := 'DFFD6021BB2BD5B0AF676290809EC3A53191DD81C7F70A4B28688A362182986F';
    
    WriteLn('  Result:   ', result_hex);
    WriteLn('  Expected: ', expected);
    
    if UpperCase(result_hex) = UpperCase(expected) then
    begin
      WriteLn('  [PASS] Incremental hash correct!');
      AddResult('Incremental SHA-256', True);
    end
    else
    begin
      WriteLn('  [FAIL] Incremental hash mismatch!');
      AddResult('Incremental SHA-256', False, 'Hash value incorrect');
    end;
    
  finally
    EVP_MD_CTX_free(ctx);
  end;
end;

// Test empty input
procedure TestEmptyInput;
var
  ctx: PEVP_MD_CTX;
  md: PEVP_MD;
  digest: array[0..31] of Byte;
  digest_len: Cardinal;
  result_hex: string;
  expected: string;
begin
  WriteLn;
  WriteLn('Testing empty input (SHA-256)...');
  
  md := EVP_sha256();
  if md = nil then
  begin
    AddResult('Empty input: Get SHA-256', False, 'Algorithm not available');
    Exit;
  end;
  
  ctx := EVP_MD_CTX_new();
  if ctx = nil then
  begin
    AddResult('Empty input: Create context', False, 'Context creation failed');
    Exit;
  end;
  
  try
    if EVP_DigestInit_ex(ctx, md, nil) <> 1 then
    begin
      AddResult('Empty input: Init', False, 'Initialization failed');
      Exit;
    end;
    
    // Don't update - test empty hash
    if EVP_DigestFinal_ex(ctx, @digest[0], @digest_len) <> 1 then
    begin
      AddResult('Empty input: Final', False, 'Finalization failed');
      Exit;
    end;
    
    result_hex := BytesToHex(digest, digest_len);
    // SHA-256("")
    expected := 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855';
    
    WriteLn('  Input:    (empty string)');
    WriteLn('  Result:   ', result_hex);
    WriteLn('  Expected: ', expected);
    
    if UpperCase(result_hex) = UpperCase(expected) then
    begin
      WriteLn('  [PASS] Empty input hash correct!');
      AddResult('Empty SHA-256', True);
    end
    else
    begin
      WriteLn('  [FAIL] Empty input hash mismatch!');
      AddResult('Empty SHA-256', False, 'Hash value incorrect');
    end;
    
  finally
    EVP_MD_CTX_free(ctx);
  end;
end;

begin
  TotalTests := 0;
  PassedTests := 0;
  SkippedTests := 0;
  SetLength(Results, 0);
  
  PrintSeparator;
  WriteLn('Hash Function Comprehensive Test Suite');
  WriteLn('OpenSSL EVP API - Pascal Binding');
  PrintSeparator;
  
  // Load OpenSSL
  try
    if not LoadOpenSSLLibrary then
    begin
      WriteLn('ERROR: Failed to load OpenSSL library!');
      Halt(1);
    end;
    WriteLn('OpenSSL library loaded successfully');
    if Assigned(OPENSSL_version) then
      WriteLn('Version: ', OPENSSL_version(0))
    else
      WriteLn('Version: Unknown');
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.Message);
      Halt(1);
    end;
  end;
  
  // Test vectors from various RFCs and standards
  
  // MD5 (legacy, for compatibility)
  TestHash('MD5', EVP_md5(), 'The quick brown fox jumps over the lazy dog',
    '9E107D9D372BB6826BD81D3542A419D6');
  
  // SHA-1 (legacy, for compatibility)
  TestHash('SHA-1', EVP_sha1(), 'The quick brown fox jumps over the lazy dog',
    '2FD4E1C67A2D28FCED849EE1BB76E7391B93EB12');
  
  // SHA-256
  TestHash('SHA-256', EVP_sha256(), 'Hello, World!',
    'DFFD6021BB2BD5B0AF676290809EC3A53191DD81C7F70A4B28688A362182986F');
  
  TestHash('SHA-256', EVP_sha256(), 'The quick brown fox jumps over the lazy dog',
    'D7A8FBB307D7809469CA9ABCB0082E4F8D5651E46D3CDB762D02D0BF37C9E592');
  
  // SHA-384
  TestHash('SHA-384', EVP_sha384(), 'The quick brown fox jumps over the lazy dog',
    'CA737F1014A48F4C0B6DD43CB177B0AFD9E5169367544C494011E3317DBF9A509CB1E5DC1E85A941BBEE3D7F2AFBC9B1');
  
  // SHA-512
  TestHash('SHA-512', EVP_sha512(), 'The quick brown fox jumps over the lazy dog',
    '07E547D9586F6A73F73FBAC0435ED76951218FB7D0C8D788A309D785436BBB642E93A252A954F23912547D1E8A3B5ED6E1BFD7097821233FA0538F3DB854FEE6');
  
  // SHA-512/256 (truncated SHA-512)
  TestHash('SHA-512/256', EVP_sha512_256(), 'The quick brown fox jumps over the lazy dog',
    'DD9D67B371519C339ED8DBD25AF90E976A1EEEFD4AD3D889005E532FC5BEF04D');

  // RED contract: unavailable algorithm should be treated as skip (not pass)
  TestHash('UNAVAILABLE-ALG', EVP_get_digestbyname('no-such-digest-zzzz'), 'abc', '');
  
  // Test special cases
  TestIncrementalHash;
  TestEmptyInput;
  
  // Print summary
  PrintResults;
  
  // Cleanup
  UnloadOpenSSLLibrary;
  
  // Exit with appropriate code
  if (TotalTests - PassedTests - SkippedTests) = 0 then
    Halt(0)
  else
    Halt(1);
end.
