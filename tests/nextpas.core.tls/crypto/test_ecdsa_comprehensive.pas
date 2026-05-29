program test_ecdsa_comprehensive;

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

  // EC and ECDSA function pointers
  PEC_KEY = Pointer;
  PEC_GROUP = Pointer;
  PEC_POINT = Pointer;
  PECDSA_SIG = Pointer;
  PPECDSA_SIG = ^PECDSA_SIG;
  PEVP_PKEY_CTX = Pointer;
  
  TEC_KEY_new = function: PEC_KEY; cdecl;
  TEC_KEY_free = procedure(key: PEC_KEY); cdecl;
  TEC_KEY_new_by_curve_name = function(nid: Integer): PEC_KEY; cdecl;
  TEC_KEY_generate_key = function(key: PEC_KEY): Integer; cdecl;
  TEC_KEY_check_key = function(const key: PEC_KEY): Integer; cdecl;
  TEC_KEY_get0_group = function(const key: PEC_KEY): PEC_GROUP; cdecl;
  
  TEC_GROUP_get_curve_name = function(const group: PEC_GROUP): Integer; cdecl;
  TEC_GROUP_get_degree = function(const group: PEC_GROUP): Integer; cdecl;
  
  TECDSA_sign = function(type_: Integer; const dgst: PByte; dgstlen: Integer;
    sig: PByte; var siglen: Cardinal; eckey: PEC_KEY): Integer; cdecl;
  TECDSA_verify = function(type_: Integer; const dgst: PByte; dgstlen: Integer;
    const sig: PByte; siglen: Integer; eckey: PEC_KEY): Integer; cdecl;
  TECDSA_size = function(const eckey: PEC_KEY): Integer; cdecl;
  
  TECDSA_SIG_new = function: PECDSA_SIG; cdecl;
  TECDSA_SIG_free = procedure(sig: PECDSA_SIG); cdecl;
  Td2i_ECDSA_SIG = function(sig: PPECDSA_SIG; const pp: PPByte; len: LongInt): PECDSA_SIG; cdecl;
  Ti2d_ECDSA_SIG = function(const sig: PECDSA_SIG; pp: PPByte): Integer; cdecl;
  
  // EVP PKEY functions for EC
  TEVP_PKEY_set1_EC_KEY = function(pkey: PEVP_PKEY; key: PEC_KEY): Integer; cdecl;
  TEVP_PKEY_get0_EC_KEY = function(pkey: PEVP_PKEY): PEC_KEY; cdecl;
  
  TEVP_PKEY_CTX_new = function(pkey: PEVP_PKEY; e: Pointer): PEVP_PKEY_CTX; cdecl;
  TEVP_PKEY_CTX_free = procedure(ctx: PEVP_PKEY_CTX); cdecl;
  TEVP_PKEY_sign_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_sign = function(ctx: PEVP_PKEY_CTX; sig: PByte; var siglen: NativeUInt;
    const tbs: PByte; tbslen: NativeUInt): Integer; cdecl;
  TEVP_PKEY_verify_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_verify = function(ctx: PEVP_PKEY_CTX; const sig: PByte; siglen: NativeUInt;
    const tbs: PByte; tbslen: NativeUInt): Integer; cdecl;
  
  // EVP digest functions
  TEVP_Digest = function(const data: Pointer; count: NativeUInt; md: PByte; 
    var size: Cardinal; const type_: PEVP_MD; impl: PENGINE): Integer; cdecl;
  TEVP_sha256 = function: PEVP_MD; cdecl;
  TEVP_sha384 = function: PEVP_MD; cdecl;
  TEVP_sha512 = function: PEVP_MD; cdecl;
  
  TEVP_PKEY_new = function: PEVP_PKEY; cdecl;
  TEVP_PKEY_free = procedure(pkey: PEVP_PKEY); cdecl;
  
  // OpenSSL initialization
  TOpenSSL_version = function(type_: Integer): PAnsiChar; cdecl;

const
  // EC curve NIDs (Named Identifier)
  NID_X9_62_prime256v1 = 415;  // NIST P-256, secp256r1
  NID_secp384r1 = 715;          // NIST P-384
  NID_secp521r1 = 716;          // NIST P-521
  NID_secp256k1 = 714;          // Bitcoin curve
  
  EVP_PKEY_EC = 408;
  
var
  Results: array of TTestResult;
  TotalTests, PassedTests: Integer;
  
  // Function pointers
  EC_KEY_new: TEC_KEY_new;
  EC_KEY_free: TEC_KEY_free;
  EC_KEY_new_by_curve_name: TEC_KEY_new_by_curve_name;
  EC_KEY_generate_key: TEC_KEY_generate_key;
  EC_KEY_check_key: TEC_KEY_check_key;
  EC_KEY_get0_group: TEC_KEY_get0_group;
  EC_GROUP_get_curve_name: TEC_GROUP_get_curve_name;
  EC_GROUP_get_degree: TEC_GROUP_get_degree;
  ECDSA_sign: TECDSA_sign;
  ECDSA_verify: TECDSA_verify;
  ECDSA_size: TECDSA_size;
  ECDSA_SIG_new: TECDSA_SIG_new;
  ECDSA_SIG_free: TECDSA_SIG_free;
  d2i_ECDSA_SIG: Td2i_ECDSA_SIG;
  i2d_ECDSA_SIG: Ti2d_ECDSA_SIG;
  EVP_PKEY_set1_EC_KEY: TEVP_PKEY_set1_EC_KEY;
  EVP_PKEY_get0_EC_KEY: TEVP_PKEY_get0_EC_KEY;
  EVP_PKEY_CTX_new: TEVP_PKEY_CTX_new;
  EVP_PKEY_CTX_free: TEVP_PKEY_CTX_free;
  EVP_PKEY_sign_init: TEVP_PKEY_sign_init;
  EVP_PKEY_sign: TEVP_PKEY_sign;
  EVP_PKEY_verify_init: TEVP_PKEY_verify_init;
  EVP_PKEY_verify: TEVP_PKEY_verify;
  EVP_Digest: TEVP_Digest;
  EVP_sha256: TEVP_sha256;
  EVP_sha384: TEVP_sha384;
  EVP_sha512: TEVP_sha512;
  EVP_PKEY_new: TEVP_PKEY_new;
  EVP_PKEY_free: TEVP_PKEY_free;
  OpenSSL_version: TOpenSSL_version;

function LoadOpenSSL: Boolean;
var
  LibHandle: THandle;
begin
  Result := False;
  LibHandle := LoadLibrary(CRYPTO_LIB);
  if LibHandle = 0 then
    Exit;
  
  Pointer(OpenSSL_version) := GetProcAddress(LibHandle, 'OpenSSL_version');
  Result := Assigned(OpenSSL_version);
end;

procedure LoadECDSAFunctions;
var
  LibHandle: THandle;
begin
  LibHandle := LoadLibrary(CRYPTO_LIB);
  if LibHandle = 0 then
    raise Exception.Create('Failed to load ' + CRYPTO_LIB);
  
  Pointer(EC_KEY_new) := GetProcAddress(LibHandle, 'EC_KEY_new');
  Pointer(EC_KEY_free) := GetProcAddress(LibHandle, 'EC_KEY_free');
  Pointer(EC_KEY_new_by_curve_name) := GetProcAddress(LibHandle, 'EC_KEY_new_by_curve_name');
  Pointer(EC_KEY_generate_key) := GetProcAddress(LibHandle, 'EC_KEY_generate_key');
  Pointer(EC_KEY_check_key) := GetProcAddress(LibHandle, 'EC_KEY_check_key');
  Pointer(EC_KEY_get0_group) := GetProcAddress(LibHandle, 'EC_KEY_get0_group');
  Pointer(EC_GROUP_get_curve_name) := GetProcAddress(LibHandle, 'EC_GROUP_get_curve_name');
  Pointer(EC_GROUP_get_degree) := GetProcAddress(LibHandle, 'EC_GROUP_get_degree');
  Pointer(ECDSA_sign) := GetProcAddress(LibHandle, 'ECDSA_sign');
  Pointer(ECDSA_verify) := GetProcAddress(LibHandle, 'ECDSA_verify');
  Pointer(ECDSA_size) := GetProcAddress(LibHandle, 'ECDSA_size');
  Pointer(ECDSA_SIG_new) := GetProcAddress(LibHandle, 'ECDSA_SIG_new');
  Pointer(ECDSA_SIG_free) := GetProcAddress(LibHandle, 'ECDSA_SIG_free');
  Pointer(d2i_ECDSA_SIG) := GetProcAddress(LibHandle, 'd2i_ECDSA_SIG');
  Pointer(i2d_ECDSA_SIG) := GetProcAddress(LibHandle, 'i2d_ECDSA_SIG');
  Pointer(EVP_PKEY_set1_EC_KEY) := GetProcAddress(LibHandle, 'EVP_PKEY_set1_EC_KEY');
  Pointer(EVP_PKEY_get0_EC_KEY) := GetProcAddress(LibHandle, 'EVP_PKEY_get0_EC_KEY');
  Pointer(EVP_PKEY_CTX_new) := GetProcAddress(LibHandle, 'EVP_PKEY_CTX_new');
  Pointer(EVP_PKEY_CTX_free) := GetProcAddress(LibHandle, 'EVP_PKEY_CTX_free');
  Pointer(EVP_PKEY_sign_init) := GetProcAddress(LibHandle, 'EVP_PKEY_sign_init');
  Pointer(EVP_PKEY_sign) := GetProcAddress(LibHandle, 'EVP_PKEY_sign');
  Pointer(EVP_PKEY_verify_init) := GetProcAddress(LibHandle, 'EVP_PKEY_verify_init');
  Pointer(EVP_PKEY_verify) := GetProcAddress(LibHandle, 'EVP_PKEY_verify');
  Pointer(EVP_Digest) := GetProcAddress(LibHandle, 'EVP_Digest');
  Pointer(EVP_sha256) := GetProcAddress(LibHandle, 'EVP_sha256');
  Pointer(EVP_sha384) := GetProcAddress(LibHandle, 'EVP_sha384');
  Pointer(EVP_sha512) := GetProcAddress(LibHandle, 'EVP_sha512');
  Pointer(EVP_PKEY_new) := GetProcAddress(LibHandle, 'EVP_PKEY_new');
  Pointer(EVP_PKEY_free) := GetProcAddress(LibHandle, 'EVP_PKEY_free');
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

function GetCurveName(nid: Integer): string;
begin
  case nid of
    NID_X9_62_prime256v1: Result := 'P-256 (secp256r1)';
    NID_secp384r1: Result := 'P-384 (secp384r1)';
    NID_secp521r1: Result := 'P-521 (secp521r1)';
    NID_secp256k1: Result := 'secp256k1 (Bitcoin)';
  else
    Result := 'Unknown curve';
  end;
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

// Test EC key generation
procedure TestECKeyGeneration;
var
  ec_key: PEC_KEY;
  group: PEC_GROUP;
  curve_nid, key_bits: Integer;
begin
  WriteLn;
  WriteLn('Testing EC key generation (P-256)...');
  
  ec_key := EC_KEY_new_by_curve_name(NID_X9_62_prime256v1);
  if ec_key = nil then
  begin
    AddResult('ECDSA: Key generation', False, 'EC_KEY_new_by_curve_name failed');
    Exit;
  end;
  
  try
    WriteLn('  Generating EC key pair...');
    if EC_KEY_generate_key(ec_key) <> 1 then
    begin
      AddResult('ECDSA: Key generation', False, 'EC_KEY_generate_key failed');
      Exit;
    end;
    
    WriteLn('  Validating key...');
    if EC_KEY_check_key(ec_key) <> 1 then
    begin
      AddResult('ECDSA: Key generation', False, 'EC_KEY_check_key failed');
      Exit;
    end;
    
    group := EC_KEY_get0_group(ec_key);
    if group <> nil then
    begin
      curve_nid := EC_GROUP_get_curve_name(group);
      key_bits := EC_GROUP_get_degree(group);
      WriteLn('  [+] Key generated successfully');
      WriteLn('  [+] Curve: ', GetCurveName(curve_nid));
      WriteLn('  [+] Key size: ', key_bits, ' bits');
    end;
    
    WriteLn('  [PASS] EC key generation successful!');
    AddResult('ECDSA P-256 Key Generation', True);
    
  finally
    EC_KEY_free(ec_key);
  end;
end;

// Test ECDSA sign and verify
procedure TestECDSASignVerify;
var
  ec_key: PEC_KEY;
  message: AnsiString;
  hash: array[0..31] of Byte;
  hash_len: Cardinal;
  signature: array[0..255] of Byte;
  sig_len: Cardinal;
  max_sig_len: Integer;
begin
  WriteLn;
  WriteLn('Testing ECDSA sign and verify...');
  
  message := 'Hello, ECDSA! This is a test message for elliptic curve signature.';
  
  // Generate key
  ec_key := EC_KEY_new_by_curve_name(NID_X9_62_prime256v1);
  if ec_key = nil then
  begin
    AddResult('ECDSA: Sign/Verify', False, 'EC_KEY_new_by_curve_name failed');
    Exit;
  end;
  
  try
    WriteLn('  Generating EC key...');
    if EC_KEY_generate_key(ec_key) <> 1 then
    begin
      AddResult('ECDSA: Sign/Verify', False, 'Key generation failed');
      Exit;
    end;
    
    // Compute SHA-256 hash of message
    WriteLn('  Computing message hash...');
    if EVP_Digest(PAnsiChar(message), Length(message), @hash[0], hash_len,
       EVP_sha256(), nil) <> 1 then
    begin
      AddResult('ECDSA: Sign/Verify', False, 'Hash computation failed');
      Exit;
    end;
    
    WriteLn('  Message: "', Copy(message, 1, 30), '..."');
    WriteLn('  Hash:    ', Copy(BytesToHex(hash, hash_len), 1, 32), '...');
    
    // Sign the hash
    WriteLn('  Signing hash...');
    max_sig_len := ECDSA_size(ec_key);
    sig_len := max_sig_len;
    
    if ECDSA_sign(0, @hash[0], hash_len, @signature[0], sig_len, ec_key) <> 1 then
    begin
      AddResult('ECDSA: Sign/Verify', False, 'Signing failed');
      Exit;
    end;
    
    WriteLn('  [+] Signature created (', sig_len, ' bytes, max: ', max_sig_len, ')');
    WriteLn('  Signature: ', Copy(BytesToHex(signature, sig_len), 1, 64), '...');
    
    // Verify the signature
    WriteLn('  Verifying signature...');
    if ECDSA_verify(0, @hash[0], hash_len, @signature[0], sig_len, ec_key) <> 1 then
    begin
      WriteLn('  [FAIL] Signature verification failed!');
      AddResult('ECDSA Sign/Verify', False, 'Verification failed');
      Exit;
    end;
    
    WriteLn('  [+] Signature verified successfully!');
    
    // Test with tampered signature (should fail)
    WriteLn('  Testing tampered signature...');
    signature[0] := signature[0] xor $FF;  // Corrupt first byte
    
    if ECDSA_verify(0, @hash[0], hash_len, @signature[0], sig_len, ec_key) = 1 then
    begin
      WriteLn('  [FAIL] Tampered signature was accepted!');
      AddResult('ECDSA Sign/Verify', False, 'Tamper detection failed');
    end
    else
    begin
      WriteLn('  [+] Tampered signature correctly rejected!');
      WriteLn('  [PASS] ECDSA sign/verify test successful!');
      AddResult('ECDSA Sign/Verify', True);
    end;
    
  finally
    EC_KEY_free(ec_key);
  end;
end;

// Test EVP high-level ECDSA API
procedure TestEVPECDSA;
var
  ec_key: PEC_KEY;
  pkey: PEVP_PKEY;
  ctx: PEVP_PKEY_CTX;
  message: AnsiString;
  hash: array[0..31] of Byte;
  hash_len: Cardinal;
  signature: array[0..255] of Byte;
  sig_len: NativeUInt;
begin
  WriteLn;
  WriteLn('Testing EVP high-level ECDSA API...');
  
  message := 'Test message for EVP ECDSA signature';
  
  // Generate EC key
  ec_key := EC_KEY_new_by_curve_name(NID_X9_62_prime256v1);
  if ec_key = nil then
  begin
    AddResult('EVP: ECDSA', False, 'EC_KEY_new_by_curve_name failed');
    Exit;
  end;
  
  WriteLn('  Generating EC key...');
  if EC_KEY_generate_key(ec_key) <> 1 then
  begin
    EC_KEY_free(ec_key);
    AddResult('EVP: ECDSA', False, 'Key generation failed');
    Exit;
  end;
  
  // Create EVP_PKEY
  pkey := EVP_PKEY_new();
  if pkey = nil then
  begin
    EC_KEY_free(ec_key);
    AddResult('EVP: ECDSA', False, 'EVP_PKEY_new failed');
    Exit;
  end;
  
  if EVP_PKEY_set1_EC_KEY(pkey, ec_key) <> 1 then
  begin
    EC_KEY_free(ec_key);
    EVP_PKEY_free(pkey);
    AddResult('EVP: ECDSA', False, 'EVP_PKEY_set1_EC_KEY failed');
    Exit;
  end;
  
  // EVP_PKEY_set1_EC_KEY增加了引用计数，所以我们可以安全释放原始的ec_key
  EC_KEY_free(ec_key);
  
  try
    // Hash the message
    WriteLn('  Hashing message...');
    if EVP_Digest(PAnsiChar(message), Length(message), @hash[0], hash_len,
       EVP_sha256(), nil) <> 1 then
    begin
      AddResult('EVP: ECDSA', False, 'Hash computation failed');
      Exit;
    end;
    
    // Create signing context
    ctx := EVP_PKEY_CTX_new(pkey, nil);
    if ctx = nil then
    begin
      AddResult('EVP: ECDSA', False, 'EVP_PKEY_CTX_new failed');
      Exit;
    end;
    
    try
      // Initialize signing
      WriteLn('  Initializing signature context...');
      if EVP_PKEY_sign_init(ctx) <> 1 then
      begin
        AddResult('EVP: ECDSA', False, 'EVP_PKEY_sign_init failed');
        Exit;
      end;
      
      // Sign the hash
      WriteLn('  Signing hash...');
      sig_len := SizeOf(signature);
      if EVP_PKEY_sign(ctx, @signature[0], sig_len, @hash[0], hash_len) <> 1 then
      begin
        AddResult('EVP: ECDSA', False, 'EVP_PKEY_sign failed');
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
        AddResult('EVP: ECDSA', False, 'EVP_PKEY_verify_init failed');
        Exit;
      end;
      
      if EVP_PKEY_verify(ctx, @signature[0], sig_len, @hash[0], hash_len) <> 1 then
      begin
        WriteLn('  [FAIL] Signature verification failed!');
        AddResult('EVP ECDSA', False, 'Verification failed');
        Exit;
      end;
      
      WriteLn('  [+] Signature verified successfully!');
      WriteLn('  [PASS] EVP ECDSA API test successful!');
      AddResult('EVP ECDSA API', True);
      
    finally
      EVP_PKEY_CTX_free(ctx);
    end;
    
  finally
    EVP_PKEY_free(pkey);  // This will also free the EC_KEY
  end;
end;

// Test different EC curves
procedure TestDifferentCurves;
var
  ec_key: PEC_KEY;
  group: PEC_GROUP;
  curves: array[0..3] of record
    nid: Integer;
    name: string;
  end;
  i, key_bits: Integer;
  start_time, end_time: TDateTime;
  duration_ms: Double;
  all_passed: Boolean;
begin
  WriteLn;
  WriteLn('Testing different EC curves...');
  
  curves[0].nid := NID_X9_62_prime256v1;
  curves[0].name := 'P-256';
  curves[1].nid := NID_secp384r1;
  curves[1].name := 'P-384';
  curves[2].nid := NID_secp521r1;
  curves[2].name := 'P-521';
  curves[3].nid := NID_secp256k1;
  curves[3].name := 'secp256k1';
  
  all_passed := True;
  
  for i := 0 to High(curves) do
  begin
    WriteLn;
    WriteLn('  Testing ', curves[i].name, ' curve...');
    
    ec_key := EC_KEY_new_by_curve_name(curves[i].nid);
    if ec_key = nil then
    begin
      WriteLn('  [FAIL] Could not create key for curve');
      all_passed := False;
      Continue;
    end;
    
    start_time := Now();
    
    if EC_KEY_generate_key(ec_key) <> 1 then
    begin
      WriteLn('  [FAIL] Key generation failed');
      all_passed := False;
      EC_KEY_free(ec_key);
      Continue;
    end;
    
    end_time := Now();
    duration_ms := (end_time - start_time) * 24 * 60 * 60 * 1000;
    
    group := EC_KEY_get0_group(ec_key);
    if group <> nil then
    begin
      key_bits := EC_GROUP_get_degree(group);
      WriteLn('  [+] Generated in ', duration_ms:0:2, ' ms');
      WriteLn('  [+] Key size: ', key_bits, ' bits');
      WriteLn('  [+] Max signature size: ', ECDSA_size(ec_key), ' bytes');
    end;
    
    EC_KEY_free(ec_key);
  end;
  
  if all_passed then
  begin
    WriteLn;
    WriteLn('  [PASS] All EC curves tested successfully!');
    AddResult('ECDSA Multiple Curves', True);
  end
  else
    AddResult('ECDSA Multiple Curves', False, 'Some curves failed');
end;

// Main program
begin
  PrintSeparator;
  WriteLn('ECDSA Comprehensive Test Suite');
  WriteLn('Elliptic Curve Digital Signature Algorithm');
  PrintSeparator;
  
  TotalTests := 0;
  PassedTests := 0;
  
  try
    // Initialize OpenSSL
    if not LoadOpenSSL then
    begin
      WriteLn('ERROR: Failed to load OpenSSL library');
      Exit;
    end;
    
    WriteLn('OpenSSL library loaded successfully');
    WriteLn('Version: ', OpenSSL_version(0));
    
    // Load ECDSA functions
    LoadECDSAFunctions;
    WriteLn('ECDSA functions loaded successfully');
    
    // Run tests
    TestECKeyGeneration;
    TestECDSASignVerify;
    TestEVPECDSA;
    TestDifferentCurves;
    
    // Print results
    PrintResults;
    
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('EXCEPTION: ', E.Message);
      Halt(1);
    end;
  end;
  
  // Exit with appropriate code
  if PassedTests < TotalTests then
    Halt(1);
end.
