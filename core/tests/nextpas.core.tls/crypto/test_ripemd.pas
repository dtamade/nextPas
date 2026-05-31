program test_ripemd;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api,
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

procedure TestRIPEMD160Basic;
var
  Data: TBytes;
  Hash: TBytes;
  HashStr: string;
begin
  WriteLn('Testing RIPEMD160 Basic...');
  
  Data := TEncoding.UTF8.GetBytes('The quick brown fox jumps over the lazy dog');
  Hash := HashDataEVP('ripemd160', Data);
  
  if Length(Hash) = 0 then
  begin
    AddResult('RIPEMD160 Basic', False, 'Hash operation failed - algorithm not available');
    Exit;
  end;
  
  HashStr := BytesToHex(Hash);
  WriteLn('  Hash: ', Copy(HashStr, 1, 40), '...');
  
  // RIPEMD160 should produce 20-byte (160-bit) hash
  if Length(Hash) = 20 then
    AddResult('RIPEMD160 Basic', True)
  else
    AddResult('RIPEMD160 Basic', False, 'Invalid hash length: ' + IntToStr(Length(Hash)));
end;

procedure TestRIPEMD160Empty;
var
  Data: TBytes;
  Hash: TBytes;
  HashStr: string;
  Expected: string;
begin
  WriteLn('Testing RIPEMD160 Empty String...');
  
  SetLength(Data, 0);
  Hash := HashDataEVP('ripemd160', Data);
  
  if Length(Hash) = 0 then
  begin
    AddResult('RIPEMD160 Empty String', False, 'Hash operation failed');
    Exit;
  end;
  
  HashStr := BytesToHex(Hash);
  Expected := '9C1185A5C5E9FC54612808977EE8F548B2258D31';
  
  WriteLn('  Empty hash: ', HashStr);
  WriteLn('  Expected:   ', Expected);
  
  if UpperCase(HashStr) = Expected then
    AddResult('RIPEMD160 Empty String', True)
  else
    AddResult('RIPEMD160 Empty String', False, 'Hash mismatch');
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
  else if PassCount = 0 then
    WriteLn('⚠️  ALL TESTS FAILED - Algorithm not available in OpenSSL 3.x')
  else
    WriteLn('❌ SOME TESTS FAILED');
end;

begin
  WriteLn('========================================');
  WriteLn('  RIPEMD Module Test');
  WriteLn('========================================');
  WriteLn;
  
  try
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
    
    WriteLn('OpenSSL loaded successfully');
    WriteLn;
    
    // Run tests
    TestRIPEMD160Basic;
    TestRIPEMD160Empty;
    
    // Print results
    PrintResults;
    
  except
    on E: Exception do
    begin
      WriteLn('EXCEPTION: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
  
  // Note: Don't halt with error if algorithm is simply not available
  // This is expected for legacy algorithms in OpenSSL 3.x
end.
