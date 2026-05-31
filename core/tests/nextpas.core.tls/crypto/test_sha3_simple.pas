program test_sha3_simple;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.evp;

function BytesToHex(const Data: array of Byte; Len: Integer): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to Len - 1 do
    Result := Result + LowerCase(IntToHex(Data[i], 2));
end;

procedure TestSHA3_256_Direct;
var
  ctx: PEVP_MD_CTX;
  md: PEVP_MD;
  data: AnsiString;
  hash: array[0..31] of Byte;
  hash_len: Cardinal;
  expected: string;
begin
  WriteLn('=== Testing SHA3-256 with direct EVP calls ===');
  WriteLn;
  
  data := 'abc';
  expected := '3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532';
  
  // Try EVP_MD_fetch first (OpenSSL 3.x)
  WriteLn('Attempting EVP_MD_fetch for SHA3-256...');
  if Assigned(EVP_MD_fetch) then
  begin
    md := EVP_MD_fetch(nil, 'SHA3-256', nil);
    if md <> nil then
      WriteLn('  SUCCESS: EVP_MD_fetch returned a valid MD pointer')
    else
      WriteLn('  FAILED: EVP_MD_fetch returned nil');
  end
  else
  begin
    WriteLn('  EVP_MD_fetch not available (OpenSSL 1.1.x?)');
    md := nil;
  end;
  
  // Try EVP_get_digestbyname (OpenSSL 1.1.x and 3.x)
  if md = nil then
  begin
    WriteLn;
    WriteLn('Attempting EVP_get_digestbyname for SHA3-256...');
    if Assigned(EVP_get_digestbyname) then
    begin
      md := EVP_get_digestbyname('SHA3-256');
      if md <> nil then
        WriteLn('  SUCCESS: EVP_get_digestbyname returned a valid MD pointer')
      else
        WriteLn('  FAILED: EVP_get_digestbyname returned nil');
    end
    else
      WriteLn('  EVP_get_digestbyname not available');
  end;
  
  if md = nil then
  begin
    WriteLn;
    WriteLn('ERROR: Could not obtain SHA3-256 digest algorithm');
    WriteLn('This indicates SHA3 is not available in your OpenSSL version');
    Exit;
  end;
  
  WriteLn;
  WriteLn('Creating MD context...');
  ctx := EVP_MD_CTX_new();
  if ctx = nil then
  begin
    WriteLn('ERROR: Failed to create MD context');
    if Assigned(EVP_MD_free) then
      EVP_MD_free(md);
    Exit;
  end;
  WriteLn('  SUCCESS: Context created');
  
  try
    WriteLn;
    WriteLn('Initializing digest...');
    if EVP_DigestInit_ex(ctx, md, nil) <> 1 then
    begin
      WriteLn('ERROR: EVP_DigestInit_ex failed');
      Exit;
    end;
    WriteLn('  SUCCESS: Digest initialized');
    
    WriteLn;
    WriteLn('Updating with data: "', data, '"...');
    if EVP_DigestUpdate(ctx, @data[1], Length(data)) <> 1 then
    begin
      WriteLn('ERROR: EVP_DigestUpdate failed');
      Exit;
    end;
    WriteLn('  SUCCESS: Data updated');
    
    WriteLn;
    WriteLn('Finalizing digest...');
    hash_len := 32;
    FillChar(hash, SizeOf(hash), 0);
    if EVP_DigestFinal_ex(ctx, @hash[0], hash_len) <> 1 then
    begin
      WriteLn('ERROR: EVP_DigestFinal_ex failed');
      Exit;
    end;
    WriteLn('  SUCCESS: Digest finalized');
    
    WriteLn;
    WriteLn('Results:');
    WriteLn('  Expected: ', expected);
    WriteLn('  Got:      ', BytesToHex(hash, 32));
    
    if BytesToHex(hash, 32) = expected then
      WriteLn('  ✅ SHA3-256 TEST PASSED')
    else
      WriteLn('  ❌ SHA3-256 TEST FAILED');
      
  finally
    EVP_MD_CTX_free(ctx);
    if Assigned(EVP_MD_free) then
      EVP_MD_free(md);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  SHA3 Simple Diagnostic Test');
  WriteLn('========================================');
  WriteLn;
  
  // Initialize OpenSSL
  if not LoadOpenSSLLibrary then
  begin
    WriteLn('ERROR: Failed to initialize OpenSSL');
    Halt(1);
  end;
  
  WriteLn('OpenSSL loaded successfully');
  WriteLn;
  
  // Load EVP functions
  if not LoadEVP(GetCryptoLibHandle) then
  begin
    WriteLn('ERROR: Failed to load EVP functions');
    UnloadOpenSSLLibrary;
    Halt(1);
  end;
  
  WriteLn('EVP functions loaded successfully');
  WriteLn;
  
  try
    TestSHA3_256_Direct;
  finally
    UnloadOpenSSLLibrary;
  end;
  
  WriteLn;
  WriteLn('Press Enter to exit...');
  ReadLn;
end.
