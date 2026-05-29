program test_signature_comprehensive;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils,
  nextpas.core.tls.openssl.api;

type
  TTestResult = record
    Name: string;
    Success: Boolean;
    ErrorMsg: string;
  end;

  // RSA and signature function pointers
  PRSA = Pointer;
  PEC_KEY = Pointer;
  PEVP_PKEY_CTX = Pointer;
  
  TRSA_new = function: PRSA; cdecl;
  TRSA_free = procedure(rsa: PRSA); cdecl;
  TRSA_generate_key_ex = function(rsa: PRSA; bits: Integer; e: PBIGNUM; cb: Pointer): Integer; cdecl;
  TRSA_size = function(const rsa: PRSA): Integer; cdecl;
  TRSA_sign = function(type_: Integer; const m: PByte; m_len: Cardinal; 
    sigret: PByte; siglen: PCardinal; rsa: PRSA): Integer; cdecl;
  TRSA_verify = function(type_: Integer; const m: PByte; m_len: Cardinal;
    const sigbuf: PByte; siglen: Cardinal; rsa: PRSA): Integer; cdecl;
    
  TBN_new = function: PBIGNUM; cdecl;
  TBN_free = procedure(a: PBIGNUM); cdecl;
  TBN_set_word = function(a: PBIGNUM; w: LongWord): Integer; cdecl;
  
  TEVP_PKEY_new = function: PEVP_PKEY; cdecl;
  TEVP_PKEY_free = procedure(pkey: PEVP_PKEY); cdecl;
  TEVP_PKEY_assign = function(pkey: PEVP_PKEY; type_: Integer; key: Pointer): Integer; cdecl;
  TEVP_PKEY_CTX_new = function(pkey: PEVP_PKEY; e: Pointer): PEVP_PKEY_CTX; cdecl;
  TEVP_PKEY_CTX_free = procedure(ctx: PEVP_PKEY_CTX); cdecl;
  TEVP_PKEY_sign_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_sign = function(ctx: PEVP_PKEY_CTX; sig: PByte; var siglen: NativeUInt;
    const tbs: PByte; tbslen: NativeUInt): Integer; cdecl;
  TEVP_PKEY_verify_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_verify = function(ctx: PEVP_PKEY_CTX; const sig: PByte; siglen: NativeUInt;
    const tbs: PByte; tbslen: NativeUInt): Integer; cdecl;
  TEVP_PKEY_CTX_set_rsa_padding = function(ctx: PEVP_PKEY_CTX; pad: Integer): Integer; cdecl;
  TEVP_PKEY_CTX_set_signature_md = function(ctx: PEVP_PKEY_CTX; md: PEVP_MD): Integer; cdecl;
  
  // EVP digest functions
  TEVP_Digest = function(const data: Pointer; count: NativeUInt; md: PByte; var size: Cardinal; const type_: PEVP_MD; impl: PENGINE): Integer; cdecl;
  TEVP_sha256 = function: PEVP_MD; cdecl;

const
  EVP_PKEY_RSA = 6;
  EVP_PKEY_EC = 408;
  NID_sha256 = 672;
  RSA_PKCS1_PADDING = 1;
  RSA_PKCS1_PSS_PADDING = 6;

var
  Results: array of TTestResult;
  TotalTests, PassedTests: Integer;
  
  // Function pointers
  RSA_new: TRSA_new;
  RSA_free: TRSA_free;
  RSA_generate_key_ex: TRSA_generate_key_ex;
  RSA_size: TRSA_size;
  RSA_sign: TRSA_sign;
  RSA_verify: TRSA_verify;
  BN_new: TBN_new;
  BN_free: TBN_free;
  BN_set_word: TBN_set_word;
  EVP_PKEY_new: TEVP_PKEY_new;
  EVP_PKEY_free: TEVP_PKEY_free;
  EVP_PKEY_assign: TEVP_PKEY_assign;
  EVP_PKEY_CTX_new: TEVP_PKEY_CTX_new;
  EVP_PKEY_CTX_free: TEVP_PKEY_CTX_free;
  EVP_PKEY_sign_init: TEVP_PKEY_sign_init;
  EVP_PKEY_sign: TEVP_PKEY_sign;
  EVP_PKEY_verify_init: TEVP_PKEY_verify_init;
  EVP_PKEY_verify: TEVP_PKEY_verify;
  EVP_PKEY_CTX_set_rsa_padding: TEVP_PKEY_CTX_set_rsa_padding;
  EVP_PKEY_CTX_set_signature_md: TEVP_PKEY_CTX_set_signature_md;
  EVP_Digest: TEVP_Digest;
  EVP_sha256: TEVP_sha256;

procedure LoadSignatureFunctions;
var
  LibHandle: THandle;
begin
  LibHandle := LoadLibrary(CRYPTO_LIB);
  if LibHandle = 0 then
    raise Exception.Create('Failed to load ' + CRYPTO_LIB);
  
  Pointer(RSA_new) := GetProcAddress(LibHandle, 'RSA_new');
  Pointer(RSA_free) := GetProcAddress(LibHandle, 'RSA_free');
  Pointer(RSA_generate_key_ex) := GetProcAddress(LibHandle, 'RSA_generate_key_ex');
  Pointer(RSA_size) := GetProcAddress(LibHandle, 'RSA_size');
  Pointer(RSA_sign) := GetProcAddress(LibHandle, 'RSA_sign');
  Pointer(RSA_verify) := GetProcAddress(LibHandle, 'RSA_verify');
  Pointer(BN_new) := GetProcAddress(LibHandle, 'BN_new');
  Pointer(BN_free) := GetProcAddress(LibHandle, 'BN_free');
  Pointer(BN_set_word) := GetProcAddress(LibHandle, 'BN_set_word');
  Pointer(EVP_PKEY_new) := GetProcAddress(LibHandle, 'EVP_PKEY_new');
  Pointer(EVP_PKEY_free) := GetProcAddress(LibHandle, 'EVP_PKEY_free');
  Pointer(EVP_PKEY_assign) := GetProcAddress(LibHandle, 'EVP_PKEY_assign');
  Pointer(EVP_PKEY_CTX_new) := GetProcAddress(LibHandle, 'EVP_PKEY_CTX_new');
  Pointer(EVP_PKEY_CTX_free) := GetProcAddress(LibHandle, 'EVP_PKEY_CTX_free');
  Pointer(EVP_PKEY_sign_init) := GetProcAddress(LibHandle, 'EVP_PKEY_sign_init');
  Pointer(EVP_PKEY_sign) := GetProcAddress(LibHandle, 'EVP_PKEY_sign');
  Pointer(EVP_PKEY_verify_init) := GetProcAddress(LibHandle, 'EVP_PKEY_verify_init');
  Pointer(EVP_PKEY_verify) := GetProcAddress(LibHandle, 'EVP_PKEY_verify');
  Pointer(EVP_PKEY_CTX_set_rsa_padding) := GetProcAddress(LibHandle, 'EVP_PKEY_CTX_set_rsa_padding');
  Pointer(EVP_PKEY_CTX_set_signature_md) := GetProcAddress(LibHandle, 'EVP_PKEY_CTX_set_signature_md');
  Pointer(EVP_Digest) := GetProcAddress(LibHandle, 'EVP_Digest');
  Pointer(EVP_sha256) := GetProcAddress(LibHandle, 'EVP_sha256');
end;

procedure AddResult(const AName: string; ASuccess: Boolean; const AError: string = '');
begin
  SetLength(Results, Length(Results) + 1);
  Results[High(Results)].Name := AName;
  Results[High(Results)].Success := ASuccess;
  Results[High(Results)].ErrorMsg := AError;
  Inc(TotalTests);
  if ASuccess then
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
    if Results[i].Success then
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
  WriteLn(Format('Total: %d tests, %d passed, %d failed (%.1f%%)',
    [TotalTests, PassedTests, TotalTests - PassedTests,
     (PassedTests / TotalTests) * 100]));
  PrintSeparator;
end;

// Test RSA key generation
procedure TestRSAKeyGeneration;
var
  rsa: PRSA;
  e: PBIGNUM;
  key_size: Integer;
begin
  WriteLn;
  WriteLn('Testing RSA key generation...');
  
  rsa := RSA_new();
  if rsa = nil then
  begin
    AddResult('RSA: Key generation', False, 'RSA_new failed');
    Exit;
  end;
  
  try
    e := BN_new();
    if e = nil then
    begin
      AddResult('RSA: Key generation', False, 'BN_new failed');
      Exit;
    end;
    
    try
      // Set public exponent to 65537 (common choice)
      if BN_set_word(e, 65537) <> 1 then
      begin
        AddResult('RSA: Key generation', False, 'BN_set_word failed');
        Exit;
      end;
      
      WriteLn('  Generating 2048-bit RSA key...');
      if RSA_generate_key_ex(rsa, 2048, e, nil) <> 1 then
      begin
        AddResult('RSA: Key generation', False, 'RSA_generate_key_ex failed');
        Exit;
      end;
      
      key_size := RSA_size(rsa);
      WriteLn('  [+] Key generated successfully');
      WriteLn('  [+] Key size: ', key_size, ' bytes (', key_size * 8, ' bits)');
      
      if key_size = 256 then  // 2048 bits / 8 = 256 bytes
      begin
        WriteLn('  [PASS] RSA key generation successful!');
        AddResult('RSA 2048-bit Key Generation', True);
      end
      else
      begin
        WriteLn('  [FAIL] Unexpected key size!');
        AddResult('RSA Key Generation', False, 'Wrong key size');
      end;
      
    finally
      BN_free(e);
    end;
  finally
    RSA_free(rsa);
  end;
end;

// Test RSA sign and verify
procedure TestRSASignVerify;
var
  rsa: PRSA;
  e: PBIGNUM;
  message: AnsiString;
  hash: array[0..31] of Byte;
  hash_len: Cardinal;
  signature: array[0..511] of Byte;
  sig_len: Cardinal;
  i: Integer;
begin
  WriteLn;
  WriteLn('Testing RSA sign and verify...');
  
  message := 'Hello, World! This is a test message for RSA signature.';
  
  // Generate key
  rsa := RSA_new();
  if rsa = nil then
  begin
    AddResult('RSA: Sign/Verify', False, 'RSA_new failed');
    Exit;
  end;
  
  try
    e := BN_new();
    BN_set_word(e, 65537);
    
    WriteLn('  Generating RSA key...');
    if RSA_generate_key_ex(rsa, 2048, e, nil) <> 1 then
    begin
      BN_free(e);
      AddResult('RSA: Sign/Verify', False, 'Key generation failed');
      Exit;
    end;
    BN_free(e);
    
    // Compute SHA-256 hash of message
    WriteLn('  Computing message hash...');
    if EVP_Digest(PAnsiChar(message), Length(message), @hash[0], hash_len, 
       EVP_sha256(), nil) <> 1 then
    begin
      AddResult('RSA: Sign/Verify', False, 'Hash computation failed');
      Exit;
    end;
    
    WriteLn('  Message: "', Copy(message, 1, 30), '..."');
    WriteLn('  Hash:    ', Copy(BytesToHex(hash, hash_len), 1, 32), '...');
    
    // Sign the hash
    WriteLn('  Signing hash...');
    sig_len := SizeOf(signature);
    if RSA_sign(NID_sha256, @hash[0], hash_len, @signature[0], @sig_len, rsa) <> 1 then
    begin
      AddResult('RSA: Sign/Verify', False, 'Signing failed');
      Exit;
    end;
    
    WriteLn('  [+] Signature created (', sig_len, ' bytes)');
    WriteLn('  Signature: ', Copy(BytesToHex(signature, sig_len), 1, 64), '...');
    
    // Verify the signature
    WriteLn('  Verifying signature...');
    if RSA_verify(NID_sha256, @hash[0], hash_len, @signature[0], sig_len, rsa) <> 1 then
    begin
      WriteLn('  [FAIL] Signature verification failed!');
      AddResult('RSA Sign/Verify', False, 'Verification failed');
      Exit;
    end;
    
    WriteLn('  [+] Signature verified successfully!');
    
    // Test with tampered signature (should fail)
    WriteLn('  Testing tampered signature...');
    signature[0] := signature[0] xor $FF;  // Corrupt first byte
    
    if RSA_verify(NID_sha256, @hash[0], hash_len, @signature[0], sig_len, rsa) = 1 then
    begin
      WriteLn('  [FAIL] Tampered signature was accepted!');
      AddResult('RSA Sign/Verify', False, 'Tamper detection failed');
    end
    else
    begin
      WriteLn('  [+] Tampered signature correctly rejected!');
      WriteLn('  [PASS] RSA sign/verify test successful!');
      AddResult('RSA Sign/Verify', True);
    end;
    
  finally
    RSA_free(rsa);
  end;
end;

// Test EVP high-level signature API
procedure TestEVPSignature;
var
  rsa: PRSA;
  e: PBIGNUM;
  pkey: PEVP_PKEY;
  ctx: PEVP_PKEY_CTX;
  message: AnsiString;
  hash: array[0..31] of Byte;
  hash_len: Cardinal;
  signature: array[0..511] of Byte;
  sig_len: NativeUInt;
begin
  WriteLn;
  WriteLn('Testing EVP high-level signature API...');
  
  message := 'Test message for EVP signature';
  
  // Generate RSA key
  rsa := RSA_new();
  e := BN_new();
  BN_set_word(e, 65537);
  
  WriteLn('  Generating RSA key...');
  if RSA_generate_key_ex(rsa, 2048, e, nil) <> 1 then
  begin
    BN_free(e);
    RSA_free(rsa);
    AddResult('EVP: Signature', False, 'Key generation failed');
    Exit;
  end;
  BN_free(e);
  
  // Create EVP_PKEY
  pkey := EVP_PKEY_new();
  if pkey = nil then
  begin
    RSA_free(rsa);
    AddResult('EVP: Signature', False, 'EVP_PKEY_new failed');
    Exit;
  end;
  
  if EVP_PKEY_assign(pkey, EVP_PKEY_RSA, rsa) <> 1 then
  begin
    RSA_free(rsa);
    EVP_PKEY_free(pkey);
    AddResult('EVP: Signature', False, 'EVP_PKEY_assign failed');
    Exit;
  end;
  
  try
    // Create signing context
    ctx := EVP_PKEY_CTX_new(pkey, nil);
    if ctx = nil then
    begin
      AddResult('EVP: Signature', False, 'EVP_PKEY_CTX_new failed');
      Exit;
    end;
    
    try
      // Hash the message first
      WriteLn('  Hashing message...');
      if EVP_Digest(PAnsiChar(message), Length(message), @hash[0], hash_len,
         EVP_sha256(), nil) <> 1 then
      begin
        AddResult('EVP: Signature', False, 'Hash computation failed');
        Exit;
      end;
      
      // Initialize signing
      WriteLn('  Initializing signature context...');
      if EVP_PKEY_sign_init(ctx) <> 1 then
      begin
        AddResult('EVP: Signature', False, 'EVP_PKEY_sign_init failed');
        Exit;
      end;
      
      // Set padding and hash algorithm
      if Assigned(EVP_PKEY_CTX_set_rsa_padding) then
        EVP_PKEY_CTX_set_rsa_padding(ctx, RSA_PKCS1_PADDING);
        
      if Assigned(EVP_PKEY_CTX_set_signature_md) then
        EVP_PKEY_CTX_set_signature_md(ctx, EVP_sha256());
      
      // Sign the hash
      WriteLn('  Signing hash...');
      sig_len := SizeOf(signature);
      if EVP_PKEY_sign(ctx, @signature[0], sig_len, 
         @hash[0], hash_len) <> 1 then
      begin
        AddResult('EVP: Signature', False, 'EVP_PKEY_sign failed');
        Exit;
      end;
      
      WriteLn('  [+] Signature created (', sig_len, ' bytes)');
      WriteLn('  Signature: ', Copy(BytesToHex(signature, sig_len), 1, 64), '...');
      
    finally
      EVP_PKEY_CTX_free(ctx);
    end;
    
    // Verify signature
    ctx := EVP_PKEY_CTX_new(pkey, nil);
    try
      WriteLn('  Verifying signature...');
      if EVP_PKEY_verify_init(ctx) <> 1 then
      begin
        AddResult('EVP: Signature', False, 'EVP_PKEY_verify_init failed');
        Exit;
      end;
      
      if Assigned(EVP_PKEY_CTX_set_rsa_padding) then
        EVP_PKEY_CTX_set_rsa_padding(ctx, RSA_PKCS1_PADDING);
        
      if Assigned(EVP_PKEY_CTX_set_signature_md) then
        EVP_PKEY_CTX_set_signature_md(ctx, EVP_sha256());
      
      if EVP_PKEY_verify(ctx, @signature[0], sig_len,
         @hash[0], hash_len) <> 1 then
      begin
        WriteLn('  [FAIL] Signature verification failed!');
        AddResult('EVP Signature', False, 'Verification failed');
        Exit;
      end;
      
      WriteLn('  [+] Signature verified successfully!');
      WriteLn('  [PASS] EVP signature API test successful!');
      AddResult('EVP Signature API', True);
      
    finally
      EVP_PKEY_CTX_free(ctx);
    end;
    
  finally
    EVP_PKEY_free(pkey);  // This will also free the RSA key
  end;
end;

// Test different key sizes
procedure TestRSAKeySizes;
var
  rsa: PRSA;
  e: PBIGNUM;
  key_sizes: array[0..2] of Integer = (1024, 2048, 4096);
  i, actual_size: Integer;
  start_time, end_time: TDateTime;
  duration_ms: Double;
  all_passed: Boolean;
begin
  WriteLn;
  WriteLn('Testing different RSA key sizes...');
  
  all_passed := True;
  e := BN_new();
  BN_set_word(e, 65537);
  
  try
    for i := 0 to High(key_sizes) do
    begin
      WriteLn;
      WriteLn('  Testing ', key_sizes[i], '-bit key...');
      
      rsa := RSA_new();
      start_time := Now;
      
      if RSA_generate_key_ex(rsa, key_sizes[i], e, nil) <> 1 then
      begin
        WriteLn('  [FAIL] Generation failed');
        all_passed := False;
        RSA_free(rsa);
        Continue;
      end;
      
      end_time := Now;
      duration_ms := (end_time - start_time) * 24 * 60 * 60 * 1000;
      
      actual_size := RSA_size(rsa) * 8;
      WriteLn('  [+] Generated in ', duration_ms:0:2, ' ms');
      WriteLn('  [+] Key size: ', actual_size, ' bits');
      
      if actual_size <> key_sizes[i] then
      begin
        WriteLn('  [FAIL] Size mismatch!');
        all_passed := False;
      end;
      
      RSA_free(rsa);
    end;
    
  finally
    BN_free(e);
  end;
  
  if all_passed then
  begin
    WriteLn;
    WriteLn('  [PASS] All key sizes generated successfully!');
    AddResult('RSA Multiple Key Sizes', True);
  end
  else
  begin
    WriteLn;
    WriteLn('  [FAIL] Some key sizes failed!');
    AddResult('RSA Multiple Key Sizes', False, 'Generation failed for some sizes');
  end;
end;

begin
  TotalTests := 0;
  PassedTests := 0;
  SetLength(Results, 0);
  
  PrintSeparator;
  WriteLn('Digital Signature Comprehensive Test Suite');
  WriteLn('RSA Signature - Sign and Verify');
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
      
    // Load signature functions
    LoadSignatureFunctions;
    WriteLn('Signature functions loaded successfully');
    WriteLn;
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.Message);
      Halt(1);
    end;
  end;
  
  // Run tests
  TestRSAKeyGeneration;
  TestRSASignVerify;
  TestEVPSignature;
  TestRSAKeySizes;
  
  // Print summary
  PrintResults;
  
  // Cleanup
  UnloadOpenSSLLibrary;
  
  // Exit with appropriate code
  if PassedTests = TotalTests then
    Halt(0)
  else
    Halt(1);
end.
