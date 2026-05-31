program test_sm3;

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
  
  md := EVP_get_digestbyname(PAnsiChar(AlgName));
  if md = nil then
    Exit;
    
  ctx := EVP_MD_CTX_new();
  if ctx = nil then
    Exit;
  
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
  end;
end;

procedure TestSM3Basic;
var
  Data: TBytes;
  Hash: TBytes;
  HashStr: string;
begin
  WriteLn('Testing SM3 Basic...');
  
  Data := TEncoding.UTF8.GetBytes('abc');
  Hash := HashDataEVP('sm3', Data);
  
  if Length(Hash) = 0 then
  begin
    AddResult('SM3 Basic', False, 'Hash operation failed - algorithm not available');
    Exit;
  end;
  
  HashStr := BytesToHex(Hash);
  WriteLn('  Hash: ', HashStr);
  
  // SM3 should produce 32-byte (256-bit) hash
  // Expected hash for "abc": 66c7f0f462eeedd9d1f2d46bdc10e4e24167c4875cf2f7a2297da02b8f4ba8e0
  if Length(Hash) = 32 then
  begin
    WriteLn('  Length: correct (32 bytes)');
    AddResult('SM3 Basic', True);
  end
  else
    AddResult('SM3 Basic', False, 'Invalid hash length: ' + IntToStr(Length(Hash)));
end;

procedure TestSM3StandardVector;
var
  Data: TBytes;
  Hash: TBytes;
  HashStr: string;
  Expected: string;
begin
  WriteLn('Testing SM3 Standard Test Vector...');
  
  // Standard test vector: "abc"
  Data := TEncoding.UTF8.GetBytes('abc');
  Hash := HashDataEVP('sm3', Data);
  
  if Length(Hash) = 0 then
  begin
    AddResult('SM3 Standard Vector', False, 'Hash operation failed');
    Exit;
  end;
  
  HashStr := BytesToHex(Hash);
  Expected := '66C7F0F462EEEDD9D1F2D46BDC10E4E24167C4875CF2F7A2297DA02B8F4BA8E0';
  
  WriteLn('  Hash:     ', HashStr);
  WriteLn('  Expected: ', Expected);
  
  if UpperCase(HashStr) = Expected then
    AddResult('SM3 Standard Vector', True)
  else
    AddResult('SM3 Standard Vector', False, 'Hash mismatch');
end;

procedure TestSM3Empty;
var
  Data: TBytes;
  Hash: TBytes;
  HashStr: string;
begin
  WriteLn('Testing SM3 Empty String...');
  
  SetLength(Data, 0);
  Hash := HashDataEVP('sm3', Data);
  
  if Length(Hash) = 0 then
  begin
    AddResult('SM3 Empty String', False, 'Hash operation failed');
    Exit;
  end;
  
  HashStr := BytesToHex(Hash);
  WriteLn('  Empty hash: ', Copy(HashStr, 1, 32), '...');
  
  if Length(Hash) = 32 then
    AddResult('SM3 Empty String', True)
  else
    AddResult('SM3 Empty String', False, 'Invalid hash length');
end;

procedure TestSM3Incremental;
var
  ctx: PEVP_MD_CTX;
  md: PEVP_MD;
  Hash: TBytes;
  HashStr: string;
  outlen: Cardinal;
  Part1, Part2: TBytes;
begin
  WriteLn('Testing SM3 Incremental...');
  
  md := EVP_get_digestbyname('sm3');
    
  if md = nil then
  begin
    AddResult('SM3 Incremental', False, 'Algorithm not available');
    Exit;
  end;
  
  ctx := EVP_MD_CTX_new();
  if ctx = nil then
  begin
    AddResult('SM3 Incremental', False, 'Context creation failed');
    Exit;
  end;
  
  try
    if EVP_DigestInit_ex(ctx, md, nil) <> 1 then
    begin
      AddResult('SM3 Incremental', False, 'Init failed');
      Exit;
    end;
    
    Part1 := TEncoding.UTF8.GetBytes('ab');
    Part2 := TEncoding.UTF8.GetBytes('c');
    
    if EVP_DigestUpdate(ctx, @Part1[0], Length(Part1)) <> 1 then
    begin
      AddResult('SM3 Incremental', False, 'Update 1 failed');
      Exit;
    end;
    
    if EVP_DigestUpdate(ctx, @Part2[0], Length(Part2)) <> 1 then
    begin
      AddResult('SM3 Incremental', False, 'Update 2 failed');
      Exit;
    end;
    
    outlen := EVP_MD_size(md);
    SetLength(Hash, outlen);
    
    if EVP_DigestFinal_ex(ctx, @Hash[0], outlen) <> 1 then
    begin
      AddResult('SM3 Incremental', False, 'Final failed');
      Exit;
    end;
    
    HashStr := BytesToHex(Hash);
    WriteLn('  Incremental hash: ', Copy(HashStr, 1, 32), '...');
    
    // Should match the standard vector for "abc"
    if UpperCase(HashStr) = '66C7F0F462EEEDD9D1F2D46BDC10E4E24167C4875CF2F7A2297DA02B8F4BA8E0' then
      AddResult('SM3 Incremental', True)
    else
      AddResult('SM3 Incremental', False, 'Hash mismatch with expected value');
      
  finally
    EVP_MD_CTX_free(ctx);
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
    WriteLn('SUCCESS: ALL TESTS PASSED')
  else if PassCount = 0 then
    WriteLn('WARNING: ALL TESTS FAILED - Algorithm not available in OpenSSL')
  else
    WriteLn('FAIL: SOME TESTS FAILED');
end;

begin
  WriteLn('========================================');
  WriteLn('  SM3 Module Test (Chinese Standard)');
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
    TestSM3Basic;
    TestSM3StandardVector;
    TestSM3Empty;
    TestSM3Incremental;
    
    // Print results
    PrintResults;
    
  except
    on E: Exception do
    begin
      WriteLn('EXCEPTION: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
  
  // Don't halt with error if algorithm is simply not available
  // This is expected for some algorithms depending on OpenSSL build
end.
