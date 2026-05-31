program test_evp_digest;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  SysUtils,
  DynLibs,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.evp;

// Helper function to convert bytes to hex string
function BytesToHex(const AData: PByte; ALen: Integer): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to ALen - 1 do
    Result := Result + IntToHex(PByte(AData + i)^, 2);
end;

// Test MD5 hash
function TestMD5: Boolean;
const
  TestData: AnsiString = 'The quick brown fox jumps over the lazy dog';
  ExpectedMD5 = '9E107D9D372BB6826BD81D3542A419D6';
var
  ctx: PEVP_MD_CTX;
  md: PEVP_MD;
  digest: array[0..63] of Byte;
  digestLen: Cardinal;
  hexResult: string;
begin
  Result := False;
  WriteLn('Testing MD5...');
  
  try
    // Check function availability
    if not Assigned(EVP_md5) then
    begin
      WriteLn('  [-] EVP_md5 not loaded');
      Exit;
    end;
    
    md := EVP_md5();
    if not Assigned(md) then
    begin
      WriteLn('  [-] Failed to get MD5 algorithm');
      Exit;
    end;
    
    ctx := EVP_MD_CTX_new();
    if not Assigned(ctx) then
    begin
      WriteLn('  [-] Failed to create context');
      Exit;
    end;
    
    try
      // Initialize
      if EVP_DigestInit_ex(ctx, md, nil) <> 1 then
      begin
        WriteLn('  [-] Failed to init digest');
        Exit;
      end;
      
      // Update
      if EVP_DigestUpdate(ctx, PAnsiChar(TestData), Length(TestData)) <> 1 then
      begin
        WriteLn('  [-] Failed to update digest');
        Exit;
      end;
      
      // Finalize
      digestLen := 0;
      if EVP_DigestFinal_ex(ctx, @digest[0], digestLen) <> 1 then
      begin
        WriteLn('  [-] Failed to finalize digest');
        Exit;
      end;
      
      // Verify
      hexResult := BytesToHex(@digest[0], digestLen);
      WriteLn('  [+] Hash length: ', digestLen, ' bytes');
      WriteLn('  [+] Hash: ', hexResult);
      
      if hexResult = ExpectedMD5 then
      begin
        WriteLn('  ✅ MD5 Test PASSED');
        Result := True;
      end
      else
      begin
        WriteLn('  ❌ Hash mismatch!');
        WriteLn('      Expected: ', ExpectedMD5);
        WriteLn('      Got:      ', hexResult);
      end;
      
    finally
      EVP_MD_CTX_free(ctx);
    end;
  except
    on E: Exception do
      WriteLn('  ❌ Exception: ', E.Message);
  end;
  WriteLn;
end;

// Test SHA-256 hash
function TestSHA256: Boolean;
const
  TestData: AnsiString = 'The quick brown fox jumps over the lazy dog';
  ExpectedSHA256 = 'D7A8FBB307D7809469CA9ABCB0082E4F8D5651E46D3CDB762D02D0BF37C9E592';
var
  ctx: PEVP_MD_CTX;
  md: PEVP_MD;
  digest: array[0..63] of Byte;
  digestLen: Cardinal;
  hexResult: string;
begin
  Result := False;
  WriteLn('Testing SHA-256...');
  
  try
    if not Assigned(EVP_sha256) then
    begin
      WriteLn('  [-] EVP_sha256 not loaded');
      Exit;
    end;
    
    md := EVP_sha256();
    if not Assigned(md) then
    begin
      WriteLn('  [-] Failed to get SHA-256 algorithm');
      Exit;
    end;
    
    ctx := EVP_MD_CTX_new();
    if not Assigned(ctx) then
    begin
      WriteLn('  [-] Failed to create context');
      Exit;
    end;
    
    try
      if EVP_DigestInit_ex(ctx, md, nil) <> 1 then
      begin
        WriteLn('  [-] Failed to init digest');
        Exit;
      end;
      
      if EVP_DigestUpdate(ctx, PAnsiChar(TestData), Length(TestData)) <> 1 then
      begin
        WriteLn('  [-] Failed to update digest');
        Exit;
      end;
      
      digestLen := 0;
      if EVP_DigestFinal_ex(ctx, @digest[0], digestLen) <> 1 then
      begin
        WriteLn('  [-] Failed to finalize digest');
        Exit;
      end;
      
      hexResult := BytesToHex(@digest[0], digestLen);
      WriteLn('  [+] Hash length: ', digestLen, ' bytes');
      WriteLn('  [+] Hash: ', hexResult);
      
      if hexResult = ExpectedSHA256 then
      begin
        WriteLn('  ✅ SHA-256 Test PASSED');
        Result := True;
      end
      else
      begin
        WriteLn('  ❌ Hash mismatch!');
        WriteLn('      Expected: ', ExpectedSHA256);
        WriteLn('      Got:      ', hexResult);
      end;
      
    finally
      EVP_MD_CTX_free(ctx);
    end;
  except
    on E: Exception do
      WriteLn('  ❌ Exception: ', E.Message);
  end;
  WriteLn;
end;

// Test SHA-512 hash
function TestSHA512: Boolean;
const
  TestData: AnsiString = 'The quick brown fox jumps over the lazy dog';
  ExpectedSHA512 = '07E547D9586F6A73F73FBAC0435ED76951218FB7D0C8D788A309D785436BBB64' +
                   '2E93A252A954F23912547D1E8A3B5ED6E1BFD7097821233FA0538F3DB854FEE6';
var
  ctx: PEVP_MD_CTX;
  md: PEVP_MD;
  digest: array[0..63] of Byte;
  digestLen: Cardinal;
  hexResult: string;
begin
  Result := False;
  WriteLn('Testing SHA-512...');
  
  try
    if not Assigned(EVP_sha512) then
    begin
      WriteLn('  [-] EVP_sha512 not loaded');
      Exit;
    end;
    
    md := EVP_sha512();
    if not Assigned(md) then
    begin
      WriteLn('  [-] Failed to get SHA-512 algorithm');
      Exit;
    end;
    
    ctx := EVP_MD_CTX_new();
    if not Assigned(ctx) then
    begin
      WriteLn('  [-] Failed to create context');
      Exit;
    end;
    
    try
      if EVP_DigestInit_ex(ctx, md, nil) <> 1 then
      begin
        WriteLn('  [-] Failed to init digest');
        Exit;
      end;
      
      if EVP_DigestUpdate(ctx, PAnsiChar(TestData), Length(TestData)) <> 1 then
      begin
        WriteLn('  [-] Failed to update digest');
        Exit;
      end;
      
      digestLen := 0;
      if EVP_DigestFinal_ex(ctx, @digest[0], digestLen) <> 1 then
      begin
        WriteLn('  [-] Failed to finalize digest');
        Exit;
      end;
      
      hexResult := BytesToHex(@digest[0], digestLen);
      WriteLn('  [+] Hash length: ', digestLen, ' bytes');
      WriteLn('  [+] Hash: ', hexResult);
      
      if hexResult = ExpectedSHA512 then
      begin
        WriteLn('  ✅ SHA-512 Test PASSED');
        Result := True;
      end
      else
      begin
        WriteLn('  ❌ Hash mismatch!');
        WriteLn('      Expected: ', ExpectedSHA512);
        WriteLn('      Got:      ', hexResult);
      end;
      
    finally
      EVP_MD_CTX_free(ctx);
    end;
  except
    on E: Exception do
      WriteLn('  ❌ Exception: ', E.Message);
  end;
  WriteLn;
end;

var
  LCryptoLib: TLibHandle;
  LPassCount, LTotalCount: Integer;
  
begin
  WriteLn('========================================');
  WriteLn('EVP Digest Algorithm Test');
  WriteLn('========================================');
  WriteLn;
  
  // Initialize OpenSSL
  try
    if not LoadOpenSSLLibrary then
      raise Exception.Create('Failed to load OpenSSL library');
  except
    on E: Exception do
    begin
      WriteLn('ERROR: Failed to load OpenSSL!');
      WriteLn('Message: ', E.Message);
      Halt(1);
    end;
  end;
  
  WriteLn('OpenSSL loaded successfully!');
  
  // Load libcrypto for EVP functions
  {$IFDEF MSWINDOWS}
  LCryptoLib := LoadLibrary('libcrypto-3-x64.dll');
  if LCryptoLib = NilHandle then
    LCryptoLib := LoadLibrary('libcrypto-3.dll');
  if LCryptoLib = NilHandle then
    LCryptoLib := LoadLibrary('libcrypto.dll');
  {$ELSE}
  LCryptoLib := LoadLibrary('libcrypto.so.3');
  if LCryptoLib = NilHandle then
    LCryptoLib := LoadLibrary('libcrypto.so');
  {$ENDIF}
  
  if LCryptoLib = NilHandle then
  begin
    WriteLn('ERROR: Failed to load libcrypto!');
    Halt(1);
  end;
  
  WriteLn('libcrypto loaded');
  
  // Load EVP module
  if not LoadEVP(LCryptoLib) then
  begin
    WriteLn('ERROR: Failed to load EVP module!');
    FreeLibrary(LCryptoLib);
    Halt(1);
  end;
  
  WriteLn('EVP module loaded successfully!');
  WriteLn;
  WriteLn('========================================');
  WriteLn;
  
  // Run tests
  LPassCount := 0;
  LTotalCount := 3;
  
  if TestMD5 then Inc(LPassCount);
  if TestSHA256 then Inc(LPassCount);
  if TestSHA512 then Inc(LPassCount);
  
  // Summary
  WriteLn('========================================');
  WriteLn('Test Summary');
  WriteLn('========================================');
  WriteLn('Total tests:  ', LTotalCount);
  WriteLn('Passed:       ', LPassCount, ' ✅');
  WriteLn('Failed:       ', LTotalCount - LPassCount);
  WriteLn('Success rate: ', (LPassCount * 100) div LTotalCount, '%');
  WriteLn('========================================');
  
  if LPassCount = LTotalCount then
  begin
    WriteLn('🎉 All tests PASSED!');
    Halt(0);
  end
  else
  begin
    WriteLn('⚠️  Some tests FAILED!');
    Halt(1);
  end;
end.
