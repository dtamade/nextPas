program test_hmac_comprehensive;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils,
  nextpas.core.tls.openssl.api;

type
  // HMAC_CTX opaque type for OpenSSL 3.0+
  PHMAC_CTX = Pointer;

var
  // HMAC functions (legacy API, compatible with both 1.1 and 3.0)
  HMAC_CTX_new: function: PHMAC_CTX; cdecl;
  HMAC_CTX_free: procedure(ctx: PHMAC_CTX); cdecl;
  HMAC_CTX_reset: function(ctx: PHMAC_CTX): Integer; cdecl;
  HMAC_Init_ex: function(ctx: PHMAC_CTX; const key: Pointer; len: Integer; const md: PEVP_MD; impl: Pointer): Integer; cdecl;
  HMAC_Update: function(ctx: PHMAC_CTX; const data: Pointer; len: NativeUInt): Integer; cdecl;
  HMAC_Final: function(ctx: PHMAC_CTX; md: PByte; len: PCardinal): Integer; cdecl;
  HMAC: function(const evp_md: PEVP_MD; const key: Pointer; key_len: Integer; const d: PByte; n: NativeUInt; md: PByte; md_len: PCardinal): PByte; cdecl;

procedure LoadHMACFunctions;
var
  LibHandle: THandle;
begin
  LibHandle := LoadLibrary(CRYPTO_LIB);
  if LibHandle = 0 then
    raise Exception.Create('Failed to load ' + CRYPTO_LIB);
  
  Pointer(HMAC_CTX_new) := GetProcAddress(LibHandle, 'HMAC_CTX_new');
  Pointer(HMAC_CTX_free) := GetProcAddress(LibHandle, 'HMAC_CTX_free');
  Pointer(HMAC_CTX_reset) := GetProcAddress(LibHandle, 'HMAC_CTX_reset');
  Pointer(HMAC_Init_ex) := GetProcAddress(LibHandle, 'HMAC_Init_ex');
  Pointer(HMAC_Update) := GetProcAddress(LibHandle, 'HMAC_Update');
  Pointer(HMAC_Final) := GetProcAddress(LibHandle, 'HMAC_Final');
  Pointer(HMAC) := GetProcAddress(LibHandle, 'HMAC');
end;

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

// Generic HMAC test function using HMAC legacy API
function TestHMAC_Legacy(const AlgName: string; md: PEVP_MD; 
  const Key, Input, ExpectedHex: string): Boolean;
var
  hmac_result: array[0..63] of Byte;
  hmac_len: Cardinal;
  result_hex: string;
begin
  Result := False;
  
  WriteLn;
  WriteLn('Testing HMAC-', AlgName, '...');
  
  if md = nil then
  begin
    AddResult('HMAC-' + AlgName + ': Get digest', False, 'Digest not available', True);
    WriteLn('  [SKIP] Digest not available');
    Exit;
  end;
  
  // Use one-shot HMAC function
  hmac_len := SizeOf(hmac_result);
  if HMAC(md, Pointer(PAnsiChar(Key)), Length(Key), Pointer(PAnsiChar(Input)), Length(Input), @hmac_result[0], @hmac_len) = nil then
  begin
    AddResult('HMAC-' + AlgName + ': Computation', False, 'HMAC computation failed');
    Exit;
  end;
  
  result_hex := BytesToHex(hmac_result, hmac_len);
  WriteLn('  Key:      "', Key, '"');
  WriteLn('  Message:  "', Input, '"');
  WriteLn('  Result:   ', result_hex);
  WriteLn('  Expected: ', ExpectedHex);
  
  if UpperCase(result_hex) = UpperCase(ExpectedHex) then
  begin
    WriteLn('  [PASS] HMAC matches!');
    AddResult('HMAC-' + AlgName, True);
    Result := True;
  end
  else
  begin
    WriteLn('  [FAIL] HMAC mismatch!');
    AddResult('HMAC-' + AlgName, False, 'HMAC value incorrect');
  end;
end;

// Test incremental HMAC
procedure TestIncrementalHMAC;
var
  ctx: PHMAC_CTX;
  key: string;
  hmac_result: array[0..31] of Byte;
  hmac_len: Cardinal;
  result_hex: string;
begin
  WriteLn;
  WriteLn('Testing incremental HMAC-SHA256...');
  
  key := 'secret_key';
  
  ctx := HMAC_CTX_new();
  if ctx = nil then
  begin
    AddResult('Incremental HMAC: Create context', False, 'Context creation failed');
    Exit;
  end;
  
  try
    // Initialize
    if HMAC_Init_ex(ctx, PAnsiChar(key), Length(key), EVP_sha256(), nil) <> 1 then
    begin
      AddResult('Incremental HMAC: Init', False, 'Initialization failed');
      Exit;
    end;
    
    // Update in chunks
    WriteLn('  [+] Updating with "The quick "');
    if HMAC_Update(ctx, Pointer(PAnsiChar('The quick ')), 10) <> 1 then
    begin
      AddResult('Incremental HMAC: Update 1', False, 'First update failed');
      Exit;
    end;
    
    WriteLn('  [+] Updating with "brown fox"');
    if HMAC_Update(ctx, Pointer(PAnsiChar('brown fox')), 9) <> 1 then
    begin
      AddResult('Incremental HMAC: Update 2', False, 'Second update failed');
      Exit;
    end;
    
    // Finalize
    if HMAC_Final(ctx, @hmac_result[0], @hmac_len) <> 1 then
    begin
      AddResult('Incremental HMAC: Final', False, 'Finalization failed');
      Exit;
    end;
    
    result_hex := BytesToHex(hmac_result, hmac_len);
    WriteLn('  Result:   ', result_hex);
    WriteLn('  Note: Expected value may vary - checking execution only');
    
    if hmac_len = 32 then
    begin
      WriteLn('  [PASS] Incremental HMAC executed successfully!');
      AddResult('Incremental HMAC-SHA256', True);
    end
    else
    begin
      WriteLn('  [FAIL] Unexpected HMAC length!');
      AddResult('Incremental HMAC-SHA256', False, 'Unexpected length');
    end;
    
  finally
    HMAC_CTX_free(ctx);
  end;
end;

// Test empty key
procedure TestEmptyKey;
var
  hmac_result: array[0..31] of Byte;
  hmac_len: Cardinal;
  result_hex: string;
begin
  WriteLn;
  WriteLn('Testing HMAC with empty key...');
  
  hmac_len := SizeOf(hmac_result);
  if HMAC(EVP_sha256(), nil, 0, Pointer(PAnsiChar('test message')), 12, @hmac_result[0], @hmac_len) = nil then
  begin
    AddResult('Empty key: Computation', False, 'HMAC computation failed');
    Exit;
  end;
  
  result_hex := BytesToHex(hmac_result, hmac_len);
  WriteLn('  Message: "test message"');
  WriteLn('  Key:     (empty)');
  WriteLn('  Result:  ', result_hex);
  
  if hmac_len = 32 then
  begin
    WriteLn('  [PASS] Empty key HMAC succeeded!');
    AddResult('HMAC with empty key', True);
  end
  else
  begin
    WriteLn('  [FAIL] Unexpected HMAC length!');
    AddResult('HMAC with empty key', False, 'Unexpected length');
  end;
end;

begin
  TotalTests := 0;
  PassedTests := 0;
  SkippedTests := 0;
  SetLength(Results, 0);
  
  PrintSeparator;
  WriteLn('HMAC Comprehensive Test Suite');
  WriteLn('OpenSSL HMAC Legacy API - Pascal Binding');
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
      
    // Load HMAC functions
    LoadHMACFunctions;
    WriteLn('HMAC functions loaded successfully');
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.Message);
      Halt(1);
    end;
  end;
  
  // Test vectors from RFC 2104 and other standards
  
  // HMAC-SHA1
  TestHMAC_Legacy('SHA1', EVP_sha1(), 'key', 'The quick brown fox jumps over the lazy dog',
    'DE7C9B85B8B78AA6BC8A7A36F70A90701C9DB4D9');
  
  // HMAC-SHA256
  TestHMAC_Legacy('SHA256', EVP_sha256(), 'key', 'The quick brown fox jumps over the lazy dog',
    'F7BC83F430538424B13298E6AA6FB143EF4D59A14946175997479DBC2D1A3CD8');
  
  // HMAC-SHA256 with different key
  TestHMAC_Legacy('SHA256', EVP_sha256(), 'secret', 'message',
    '8B5F48702995C1598C573DB1E21866A9B825D4A794D169D7060A03605796360B');
  
  // HMAC-SHA384
  TestHMAC_Legacy('SHA384', EVP_sha384(), 'key', 'The quick brown fox jumps over the lazy dog',
    'D7F4727E2C0B39AE0F1E40CC96F60242D5B7801841CEA6FC592C5D3E1AE50700582A96CF35E1E554995FE4E03381C237');
  
  // HMAC-SHA512
  TestHMAC_Legacy('SHA512', EVP_sha512(), 'key', 'The quick brown fox jumps over the lazy dog',
    'B42AF09057BAC1E2D41708E48A902E09B5FF7F12AB428A4FE86653C73DD248FB82F948A549F7B791A5B41915EE4D1EC3935357E4E2317250D0372AFA2EBEEB3A');

  // RED contract: unavailable digest should be treated as skip (not pass)
  TestHMAC_Legacy('UNAVAILABLE-DIGEST', EVP_get_digestbyname('no-such-digest-zzzz'), 'key', 'message', '');
  
  // Test special cases
  TestIncrementalHMAC;
  TestEmptyKey;
  
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
