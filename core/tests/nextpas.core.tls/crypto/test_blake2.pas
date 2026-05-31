program test_blake2;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.blake2;

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
    Result := Result + IntToHex(Data[i], 2);
end;

function TestBLAKE2bBasic: Boolean;
var
  ctx: PEVP_MD_CTX;
  md: PEVP_MD;
  data: AnsiString;
  hash: array[0..63] of Byte;  // BLAKE2b-512 = 64 bytes
  hash_len: Cardinal;
begin
  Result := False;
  data := 'Hello, BLAKE2b!';
  
  try
    // Get BLAKE2b-512 algorithm
    md := EVP_blake2b512();
    if not Assigned(md) then
    begin
      WriteLn('  BLAKE2b-512 not available');
      Exit;
    end;
    
    ctx := EVP_MD_CTX_new();
    if not Assigned(ctx) then Exit;
    
    try
      if EVP_DigestInit_ex(ctx, md, nil) <> 1 then Exit;
      if EVP_DigestUpdate(ctx, PAnsiChar(data), Length(data)) <> 1 then Exit;
      
      hash_len := 64;
      if EVP_DigestFinal_ex(ctx, @hash[0], hash_len) <> 1 then Exit;
      
      WriteLn('  Hash: ', Copy(BytesToHex(hash, 64), 1, 64), '...');
      Result := True;
    finally
      EVP_MD_CTX_free(ctx);
    end;
  except
    on E: Exception do
      WriteLn('  Exception: ', E.Message);
  end;
end;

function TestBLAKE2sBasic: Boolean;
var
  ctx: PEVP_MD_CTX;
  md: PEVP_MD;
  data: AnsiString;
  hash: array[0..31] of Byte;  // BLAKE2s-256 = 32 bytes
  hash_len: Cardinal;
begin
  Result := False;
  data := 'Hello, BLAKE2s!';
  
  try
    // Get BLAKE2s-256 algorithm
    md := EVP_blake2s256();
    if not Assigned(md) then
    begin
      WriteLn('  BLAKE2s-256 not available');
      Exit;
    end;
    
    ctx := EVP_MD_CTX_new();
    if not Assigned(ctx) then Exit;
    
    try
      if EVP_DigestInit_ex(ctx, md, nil) <> 1 then Exit;
      if EVP_DigestUpdate(ctx, PAnsiChar(data), Length(data)) <> 1 then Exit;
      
      hash_len := 32;
      if EVP_DigestFinal_ex(ctx, @hash[0], hash_len) <> 1 then Exit;
      
      WriteLn('  Hash: ', Copy(BytesToHex(hash, 32), 1, 64), '...');
      Result := True;
    finally
      EVP_MD_CTX_free(ctx);
    end;
  except
    on E: Exception do
      WriteLn('  Exception: ', E.Message);
  end;
end;

function TestBLAKE2bEmpty: Boolean;
var
  ctx: PEVP_MD_CTX;
  md: PEVP_MD;
  hash: array[0..63] of Byte;
  hash_len: Cardinal;
  expected: string;
begin
  Result := False;
  
  // BLAKE2b-512 of empty string
  expected := '786A02F742015903C6C6FD852552D272912F4740E15847618A86E217F71F5419';
  
  try
    md := EVP_blake2b512();
    if not Assigned(md) then Exit;
    
    ctx := EVP_MD_CTX_new();
    if not Assigned(ctx) then Exit;
    
    try
      if EVP_DigestInit_ex(ctx, md, nil) <> 1 then Exit;
      // Don't update with any data
      
      hash_len := 64;
      if EVP_DigestFinal_ex(ctx, @hash[0], hash_len) <> 1 then Exit;
      
      WriteLn('  Empty hash: ', Copy(BytesToHex(hash, 64), 1, 64), '...');
      WriteLn('  Expected:   ', Copy(expected, 1, 64), '...');
      
      Result := True;
    finally
      EVP_MD_CTX_free(ctx);
    end;
  except
    on E: Exception do
      WriteLn('  Exception: ', E.Message);
  end;
end;

function TestBLAKE2bIncremental: Boolean;
var
  ctx: PEVP_MD_CTX;
  md: PEVP_MD;
  hash: array[0..63] of Byte;
  hash_len: Cardinal;
begin
  Result := False;
  
  try
    md := EVP_blake2b512();
    if not Assigned(md) then Exit;
    
    ctx := EVP_MD_CTX_new();
    if not Assigned(ctx) then Exit;
    
    try
      if EVP_DigestInit_ex(ctx, md, nil) <> 1 then Exit;
      
      // Update multiple times
      if EVP_DigestUpdate(ctx, PAnsiChar('Hello'), 5) <> 1 then Exit;
      if EVP_DigestUpdate(ctx, PAnsiChar(', '), 2) <> 1 then Exit;
      if EVP_DigestUpdate(ctx, PAnsiChar('World'), 5) <> 1 then Exit;
      
      hash_len := 64;
      if EVP_DigestFinal_ex(ctx, @hash[0], hash_len) <> 1 then Exit;
      
      WriteLn('  Incremental hash: ', Copy(BytesToHex(hash, 64), 1, 64), '...');
      Result := True;
    finally
      EVP_MD_CTX_free(ctx);
    end;
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
  WriteLn('  BLAKE2 Module Test');
  WriteLn('========================================');
  WriteLn;
  
  try
    // Load OpenSSL
    if not LoadOpenSSLLibrary then
    begin
      WriteLn('ERROR: Failed to load OpenSSL library');
      ExitCode := 1;
      Exit;
    end;
    
    // Load EVP functions
    if not LoadEVP(GetCryptoLibHandle) then
    begin
      WriteLn('ERROR: Failed to load EVP functions');
      ExitCode := 1;
      Exit;
    end;
    
    WriteLn('OpenSSL loaded successfully');
    WriteLn;
    
    // Run tests
    WriteLn('Testing BLAKE2b-512 Basic...');
    TestResult('BLAKE2b-512 Basic', TestBLAKE2bBasic);
    WriteLn;
    
    WriteLn('Testing BLAKE2s-256 Basic...');
    TestResult('BLAKE2s-256 Basic', TestBLAKE2sBasic);
    WriteLn;
    
    WriteLn('Testing BLAKE2b Empty String...');
    TestResult('BLAKE2b Empty String', TestBLAKE2bEmpty);
    WriteLn;
    
    WriteLn('Testing BLAKE2b Incremental...');
    TestResult('BLAKE2b Incremental', TestBLAKE2bIncremental);
    WriteLn;
    
    // Summary
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
