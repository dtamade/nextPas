program test_whirlpool;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.core,
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

function BytesToHex(const Data: array of Byte): string;
var
  I: Integer;
begin
  Result := '';
  for I := Low(Data) to High(Data) do
    Result := Result + IntToHex(Data[I], 2);
end;

function HashDataEVP(const AlgName: string; const Data: TBytes): TBytes;
var
  ctx: PEVP_MD_CTX;
  md: PEVP_MD;
  outlen: Cardinal;
begin
  Result := nil;
  
  // Try fetch first (OpenSSL 3.x)
  if Assigned(EVP_MD_fetch) then
  begin
    md := EVP_MD_fetch(nil, PAnsiChar(AlgName), nil);
    if md = nil then
    begin
      // Fallback to get_digestbyname
      md := EVP_get_digestbyname(PAnsiChar(AlgName));
    end;
  end
  else
  begin
    md := EVP_get_digestbyname(PAnsiChar(AlgName));
  end;
  
  if md = nil then
    Exit;
    
  ctx := EVP_MD_CTX_new();
  if ctx = nil then
  begin
    if Assigned(EVP_MD_fetch) and Assigned(EVP_MD_free) then
      EVP_MD_free(md);
    Exit;
  end;
  
  try
    if EVP_DigestInit_ex(ctx, md, nil) <> 1 then
      Exit;
      
    if Length(Data) > 0 then
      if EVP_DigestUpdate(ctx, @Data[0], Length(Data)) <> 1 then
        Exit;
        
    outlen := EVP_MD_size(md);
    SetLength(Result, outlen);
    
    if EVP_DigestFinal_ex(ctx, @Result[0], outlen) <> 1 then
    begin
      SetLength(Result, 0);
      Exit;
    end;
  finally
    EVP_MD_CTX_free(ctx);
    if Assigned(EVP_MD_fetch) and Assigned(EVP_MD_free) then
      EVP_MD_free(md);
  end;
end;

procedure TestWhirlpoolBasic;
var
  Data: TBytes;
  Hash: TBytes;
  HashStr: string;
begin
  WriteLn('Testing Whirlpool Basic...');
  
  Data := TEncoding.UTF8.GetBytes('The quick brown fox jumps over the lazy dog');
  Hash := HashDataEVP('whirlpool', Data);
  
  if Length(Hash) = 0 then
  begin
    AddResult('Whirlpool Basic', False, 'Hash operation failed');
    Exit;
  end;
  
  HashStr := BytesToHex(Hash);
  WriteLn('  Hash: ', Copy(HashStr, 1, 64), '...');
  
  // Whirlpool should produce 64-byte (512-bit) hash
  if Length(Hash) = 64 then
    AddResult('Whirlpool Basic', True)
  else
    AddResult('Whirlpool Basic', False, 'Invalid hash length: ' + IntToStr(Length(Hash)));
end;

procedure TestWhirlpoolEmpty;
var
  Data: TBytes;
  Hash: TBytes;
  HashStr: string;
  Expected: string;
begin
  WriteLn('Testing Whirlpool Empty String...');
  
  SetLength(Data, 0);
  Hash := HashDataEVP('whirlpool', Data);
  
  if Length(Hash) = 0 then
  begin
    AddResult('Whirlpool Empty String', False, 'Hash operation failed');
    Exit;
  end;
  
  HashStr := BytesToHex(Hash);
  Expected := '19FA61D75522A4669B44E39C1D2E1726C530232130D407F89AFEE0964997F7A73E83BE698B288FEBCF88E3E03C4F0757EA8964E59B63D93708B138CC42A66EB3';
  
  WriteLn('  Empty hash: ', Copy(HashStr, 1, 64), '...');
  WriteLn('  Expected:   ', Copy(Expected, 1, 64), '...');
  
  if UpperCase(HashStr) = Expected then
    AddResult('Whirlpool Empty String', True)
  else
    AddResult('Whirlpool Empty String', False, 'Hash mismatch');
end;

procedure TestWhirlpoolIncremental;
var
  ctx: PEVP_MD_CTX;
  md: PEVP_MD;
  Hash: TBytes;
  HashStr: string;
  outlen: Cardinal;
  Part1, Part2, Part3: TBytes;
begin
  WriteLn('Testing Whirlpool Incremental...');
  
  // Try fetch first
  if Assigned(EVP_MD_fetch) then
    md := EVP_MD_fetch(nil, 'whirlpool', nil)
  else
    md := EVP_get_digestbyname('whirlpool');
    
  if md = nil then
  begin
    AddResult('Whirlpool Incremental', False, 'Algorithm not available');
    Exit;
  end;
  
  ctx := EVP_MD_CTX_new();
  if ctx = nil then
  begin
    if Assigned(EVP_MD_fetch) and Assigned(EVP_MD_free) then
      EVP_MD_free(md);
    AddResult('Whirlpool Incremental', False, 'Context creation failed');
    Exit;
  end;
  
  try
    if EVP_DigestInit_ex(ctx, md, nil) <> 1 then
    begin
      AddResult('Whirlpool Incremental', False, 'Init failed');
      Exit;
    end;
    
    Part1 := TEncoding.UTF8.GetBytes('The quick ');
    Part2 := TEncoding.UTF8.GetBytes('brown fox ');
    Part3 := TEncoding.UTF8.GetBytes('jumps over the lazy dog');
    
    if EVP_DigestUpdate(ctx, @Part1[0], Length(Part1)) <> 1 then
    begin
      AddResult('Whirlpool Incremental', False, 'Update 1 failed');
      Exit;
    end;
    
    if EVP_DigestUpdate(ctx, @Part2[0], Length(Part2)) <> 1 then
    begin
      AddResult('Whirlpool Incremental', False, 'Update 2 failed');
      Exit;
    end;
    
    if EVP_DigestUpdate(ctx, @Part3[0], Length(Part3)) <> 1 then
    begin
      AddResult('Whirlpool Incremental', False, 'Update 3 failed');
      Exit;
    end;
    
    outlen := EVP_MD_size(md);
    SetLength(Hash, outlen);
    
    if EVP_DigestFinal_ex(ctx, @Hash[0], outlen) <> 1 then
    begin
      AddResult('Whirlpool Incremental', False, 'Final failed');
      Exit;
    end;
    
    HashStr := BytesToHex(Hash);
    WriteLn('  Incremental hash: ', Copy(HashStr, 1, 64), '...');
    
    AddResult('Whirlpool Incremental', True);
  finally
    EVP_MD_CTX_free(ctx);
    if Assigned(EVP_MD_fetch) and Assigned(EVP_MD_free) then
      EVP_MD_free(md);
  end;
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
  else
    WriteLn('❌ SOME TESTS FAILED');
end;

begin
  WriteLn('========================================');
  WriteLn('  Whirlpool Module Test');
  WriteLn('========================================');
  WriteLn;
  
  try
    WriteLn('========================================');
    WriteLn('NOTE: Whirlpool requires legacy provider in OpenSSL 3.0');
    WriteLn('      This test may fail if legacy provider is not enabled.');
   WriteLn('      To enable: export OPENSSL_CONF=/path/to/openssl.cnf');
    WriteLn('========================================');
    WriteLn;
    
    // Use modern API loading
    LoadOpenSSLCore();
    
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      WriteLn('ERROR: Failed to load OpenSSL library');
      Halt(1);
    end;
    
    WriteLn('OpenSSL loaded successfully');
    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);
    WriteLn;
    
    // Run tests
    TestWhirlpoolBasic;
    TestWhirlpoolEmpty;
    TestWhirlpoolIncremental;
    
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
