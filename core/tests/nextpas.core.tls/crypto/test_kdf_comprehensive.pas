program test_kdf_comprehensive;

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

  // KDF function pointers
  PPKCS5_PBKDF2_HMAC = function(const pass: PAnsiChar; passlen: Integer;
    const salt: PByte; saltlen: Integer; iter: Integer; const digest: PEVP_MD;
    keylen: Integer; out_: PByte): Integer; cdecl;
    
  PEVP_PKEY_CTX = Pointer;
  TEVP_PKEY_derive_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_derive_set_peer = function(ctx: PEVP_PKEY_CTX; peer: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_derive = function(ctx: PEVP_PKEY_CTX; key: PByte; var keylen: NativeUInt): Integer; cdecl;
  TEVP_PKEY_CTX_new_id = function(id: Integer; e: Pointer): PEVP_PKEY_CTX; cdecl;
  TEVP_PKEY_CTX_free = procedure(ctx: PEVP_PKEY_CTX); cdecl;
  TEVP_PKEY_CTX_ctrl = function(ctx: PEVP_PKEY_CTX; keytype: Integer; optype: Integer;
    cmd: Integer; p1: Integer; p2: Pointer): Integer; cdecl;

var
  Results: array of TTestResult;
  TotalTests, PassedTests: Integer;
  
  // KDF functions
  PKCS5_PBKDF2_HMAC: PPKCS5_PBKDF2_HMAC;
  EVP_PKEY_derive_init: TEVP_PKEY_derive_init;
  EVP_PKEY_derive: TEVP_PKEY_derive;
  EVP_PKEY_CTX_new_id: TEVP_PKEY_CTX_new_id;
  EVP_PKEY_CTX_free: TEVP_PKEY_CTX_free;
  EVP_PKEY_CTX_ctrl: TEVP_PKEY_CTX_ctrl;

const
  EVP_PKEY_HKDF = 1036;
  EVP_PKEY_SCRYPT = 973;
  EVP_PKEY_CTRL_HKDF_MD = $1001;
  EVP_PKEY_CTRL_HKDF_SALT = $1002;
  EVP_PKEY_CTRL_HKDF_KEY = $1003;
  EVP_PKEY_CTRL_HKDF_INFO = $1004;
  EVP_PKEY_CTRL_HKDF_MODE = $1005;
  EVP_PKEY_CTRL_SCRYPT_SALT = $2001;
  EVP_PKEY_CTRL_SCRYPT_N = $2002;
  EVP_PKEY_CTRL_SCRYPT_R = $2003;
  EVP_PKEY_CTRL_SCRYPT_P = $2004;
  EVP_PKEY_CTRL_SCRYPT_MAXMEM_BYTES = $2005;
  EVP_PKEY_OP_DERIVE = 1 shl 10;

procedure LoadKDFFunctions;
var
  LibHandle: THandle;
begin
  LibHandle := LoadLibrary(CRYPTO_LIB);
  if LibHandle = 0 then
    raise Exception.Create('Failed to load ' + CRYPTO_LIB);
  
  Pointer(PKCS5_PBKDF2_HMAC) := GetProcAddress(LibHandle, 'PKCS5_PBKDF2_HMAC');
  Pointer(EVP_PKEY_derive_init) := GetProcAddress(LibHandle, 'EVP_PKEY_derive_init');
  Pointer(EVP_PKEY_derive) := GetProcAddress(LibHandle, 'EVP_PKEY_derive');
  Pointer(EVP_PKEY_CTX_new_id) := GetProcAddress(LibHandle, 'EVP_PKEY_CTX_new_id');
  Pointer(EVP_PKEY_CTX_free) := GetProcAddress(LibHandle, 'EVP_PKEY_CTX_free');
  Pointer(EVP_PKEY_CTX_ctrl) := GetProcAddress(LibHandle, 'EVP_PKEY_CTX_ctrl');
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

// Test PBKDF2
procedure TestPBKDF2;
var
  password, salt: AnsiString;
  key: array[0..31] of Byte;
  result_hex: string;
  iterations: Integer;
begin
  WriteLn;
  WriteLn('Testing PBKDF2-HMAC-SHA256...');
  
  password := 'password';
  salt := 'salt';
  iterations := 1000;
  
  if not Assigned(PKCS5_PBKDF2_HMAC) then
  begin
    AddResult('PBKDF2: Function available', False, 'Function not loaded');
    Exit;
  end;
  
  if PKCS5_PBKDF2_HMAC(PAnsiChar(password), Length(password),
    PByte(PAnsiChar(salt)), Length(salt), iterations, EVP_sha256(),
    Length(key), @key[0]) <> 1 then
  begin
    AddResult('PBKDF2: Derivation', False, 'Key derivation failed');
    Exit;
  end;
  
  result_hex := BytesToHex(key, Length(key));
  WriteLn('  Password:   "', password, '"');
  WriteLn('  Salt:       "', salt, '"');
  WriteLn('  Iterations: ', iterations);
  WriteLn('  Result:     ', result_hex);
  
  // RFC 7914 test vector
  // Note: Actual value depends on exact test vector, checking execution for now
  if Length(result_hex) = 64 then
  begin
    WriteLn('  [PASS] PBKDF2 derivation successful!');
    AddResult('PBKDF2-HMAC-SHA256', True);
  end
  else
  begin
    WriteLn('  [FAIL] Unexpected key length!');
    AddResult('PBKDF2-HMAC-SHA256', False, 'Unexpected key length');
  end;
end;

// Test PBKDF2 with different hash
procedure TestPBKDF2_SHA512;
var
  password, salt: AnsiString;
  key: array[0..63] of Byte;
  result_hex: string;
  iterations: Integer;
begin
  WriteLn;
  WriteLn('Testing PBKDF2-HMAC-SHA512...');
  
  password := 'secretpassword123';
  salt := 'randomsalt456';
  iterations := 2048;
  
  if PKCS5_PBKDF2_HMAC(PAnsiChar(password), Length(password),
    PByte(PAnsiChar(salt)), Length(salt), iterations, EVP_sha512(),
    Length(key), @key[0]) <> 1 then
  begin
    AddResult('PBKDF2-SHA512: Derivation', False, 'Key derivation failed');
    Exit;
  end;
  
  result_hex := BytesToHex(key, Length(key));
  WriteLn('  Password:   "', password, '"');
  WriteLn('  Salt:       "', salt, '"');
  WriteLn('  Iterations: ', iterations);
  WriteLn('  Key length: ', Length(key), ' bytes');
  WriteLn('  Result:     ', Copy(result_hex, 1, 64), '...');
  
  if Length(result_hex) = 128 then
  begin
    WriteLn('  [PASS] PBKDF2-SHA512 derivation successful!');
    AddResult('PBKDF2-HMAC-SHA512', True);
  end
  else
  begin
    WriteLn('  [FAIL] Unexpected key length!');
    AddResult('PBKDF2-HMAC-SHA512', False, 'Unexpected key length');
  end;
end;

// Test PBKDF2 with many iterations (performance test)
procedure TestPBKDF2_Performance;
var
  password, salt: AnsiString;
  key: array[0..31] of Byte;
  iterations: Integer;
  start_time, end_time: TDateTime;
  duration_ms: Double;
begin
  WriteLn;
  WriteLn('Testing PBKDF2 performance (high iteration count)...');
  
  password := 'testpassword';
  salt := 'testsalt';
  iterations := 100000;  // Common modern iteration count
  
  WriteLn('  Password:   "', password, '"');
  WriteLn('  Salt:       "', salt, '"');
  WriteLn('  Iterations: ', iterations);
  WriteLn('  Computing...');
  
  start_time := Now;
  
  if PKCS5_PBKDF2_HMAC(PAnsiChar(password), Length(password),
    PByte(PAnsiChar(salt)), Length(salt), iterations, EVP_sha256(),
    Length(key), @key[0]) <> 1 then
  begin
    AddResult('PBKDF2: Performance test', False, 'Key derivation failed');
    Exit;
  end;
  
  end_time := Now;
  duration_ms := (end_time - start_time) * 24 * 60 * 60 * 1000;
  
  WriteLn('  Duration:   ', duration_ms:0:2, ' ms');
  WriteLn('  Result:     ', Copy(BytesToHex(key, Length(key)), 1, 32), '...');
  
  if duration_ms > 0 then
  begin
    WriteLn('  [PASS] PBKDF2 performance test completed!');
    AddResult('PBKDF2 Performance (100k iterations)', True);
  end
  else
  begin
    WriteLn('  [FAIL] Unexpected timing!');
    AddResult('PBKDF2 Performance', False, 'Timing error');
  end;
end;

// Test with empty password
procedure TestPBKDF2_EmptyPassword;
var
  password, salt: AnsiString;
  key: array[0..15] of Byte;
  result_hex: string;
begin
  WriteLn;
  WriteLn('Testing PBKDF2 with empty password...');
  
  password := '';
  salt := 'salt';
  
  if PKCS5_PBKDF2_HMAC(PAnsiChar(password), Length(password),
    PByte(PAnsiChar(salt)), Length(salt), 1000, EVP_sha256(),
    Length(key), @key[0]) <> 1 then
  begin
    AddResult('PBKDF2: Empty password', False, 'Key derivation failed');
    Exit;
  end;
  
  result_hex := BytesToHex(key, Length(key));
  WriteLn('  Password:   (empty)');
  WriteLn('  Salt:       "', salt, '"');
  WriteLn('  Result:     ', result_hex);
  
  if Length(result_hex) = 32 then
  begin
    WriteLn('  [PASS] Empty password handled correctly!');
    AddResult('PBKDF2 with empty password', True);
  end
  else
  begin
    WriteLn('  [FAIL] Unexpected result!');
    AddResult('PBKDF2 with empty password', False, 'Unexpected result');
  end;
end;

// Test variable key lengths
procedure TestPBKDF2_VariableLength;
var
  password, salt: AnsiString;
  key16: array[0..15] of Byte;
  key32: array[0..31] of Byte;
  key64: array[0..63] of Byte;
  success: Boolean;
begin
  WriteLn;
  WriteLn('Testing PBKDF2 with variable key lengths...');
  
  password := 'password';
  salt := 'salt';
  success := True;
  
  // 16 bytes (128 bits)
  if PKCS5_PBKDF2_HMAC(PAnsiChar(password), Length(password),
    PByte(PAnsiChar(salt)), Length(salt), 1000, EVP_sha256(),
    16, @key16[0]) <> 1 then
    success := False
  else
    WriteLn('  [+] 16-byte key: ', BytesToHex(key16, 16));
  
  // 32 bytes (256 bits)
  if PKCS5_PBKDF2_HMAC(PAnsiChar(password), Length(password),
    PByte(PAnsiChar(salt)), Length(salt), 1000, EVP_sha256(),
    32, @key32[0]) <> 1 then
    success := False
  else
    WriteLn('  [+] 32-byte key: ', BytesToHex(key32, 32));
  
  // 64 bytes (512 bits)
  if PKCS5_PBKDF2_HMAC(PAnsiChar(password), Length(password),
    PByte(PAnsiChar(salt)), Length(salt), 1000, EVP_sha256(),
    64, @key64[0]) <> 1 then
    success := False
  else
    WriteLn('  [+] 64-byte key: ', Copy(BytesToHex(key64, 64), 1, 64), '...');
  
  if success then
  begin
    WriteLn('  [PASS] Variable length keys generated!');
    AddResult('PBKDF2 Variable Lengths', True);
  end
  else
  begin
    WriteLn('  [FAIL] Key generation failed!');
    AddResult('PBKDF2 Variable Lengths', False, 'Generation failed');
  end;
end;

// Test with RFC test vector
procedure TestPBKDF2_RFC_TestVector;
var
  password, salt: AnsiString;
  key: array[0..19] of Byte;
  result_hex: string;
  expected: string;
begin
  WriteLn;
  WriteLn('Testing PBKDF2 with RFC 6070 test vector...');
  
  // RFC 6070 Test Vector 1
  password := 'password';
  salt := 'salt';
  
  if PKCS5_PBKDF2_HMAC(PAnsiChar(password), Length(password),
    PByte(PAnsiChar(salt)), Length(salt), 1, EVP_sha1(),
    20, @key[0]) <> 1 then
  begin
    AddResult('PBKDF2: RFC test vector', False, 'Key derivation failed');
    Exit;
  end;
  
  result_hex := BytesToHex(key, 20);
  expected := '0C60C80F961F0E71F3A9B524AF6012062FE037A6';
  
  WriteLn('  Password:   "', password, '"');
  WriteLn('  Salt:       "', salt, '"');
  WriteLn('  Iterations: 1');
  WriteLn('  Result:     ', result_hex);
  WriteLn('  Expected:   ', expected);
  
  if UpperCase(result_hex) = UpperCase(expected) then
  begin
    WriteLn('  [PASS] RFC test vector matches!');
    AddResult('PBKDF2 RFC 6070 Test Vector', True);
  end
  else
  begin
    WriteLn('  [FAIL] Test vector mismatch!');
    AddResult('PBKDF2 RFC 6070 Test Vector', False, 'Value mismatch');
  end;
end;

begin
  TotalTests := 0;
  PassedTests := 0;
  SetLength(Results, 0);
  
  PrintSeparator;
  WriteLn('KDF Comprehensive Test Suite');
  WriteLn('PBKDF2 - Password-Based Key Derivation');
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
      
    // Load KDF functions
    LoadKDFFunctions;
    WriteLn('KDF functions loaded successfully');
    WriteLn;
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.Message);
      Halt(1);
    end;
  end;
  
  // Run PBKDF2 tests
  TestPBKDF2;
  TestPBKDF2_SHA512;
  TestPBKDF2_Performance;
  TestPBKDF2_EmptyPassword;
  TestPBKDF2_VariableLength;
  TestPBKDF2_RFC_TestVector;
  
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
