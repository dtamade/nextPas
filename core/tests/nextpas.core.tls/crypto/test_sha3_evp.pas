program test_sha3_evp;

{$mode Delphi}{$H+}

uses
  {$IFDEF WINDOWS}Windows,{$ENDIF}
  SysUtils, Dynlibs,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.sha3.evp;

function BytesToHex(const Bytes: TBytes): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(Bytes) do
    Result := Result + LowerCase(IntToHex(Bytes[i], 2));
end;

function StringToBytes(const S: string): TBytes;
var
  i: Integer;
begin
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(S[1], Result[0], Length(S));
end;

procedure TestSHA3_256;
var
  testData: TBytes;
  hash: TBytes;
  expected: string;
begin
  WriteLn('=== Testing SHA3-256 with EVP API ===');
  
  // Test vector from NIST
  testData := StringToBytes('abc');
  expected := '3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532';
  
  hash := SHA3_256Hash_EVP(testData);
  
  WriteLn('Input: "abc"');
  WriteLn('Expected: ', expected);
  WriteLn('Got:      ', BytesToHex(hash));
  
  if BytesToHex(hash) = expected then
    WriteLn('PASS: SHA3-256 test PASSED')
  else
    WriteLn('FAIL: SHA3-256 test FAILED');
  
  WriteLn;
end;

procedure TestSHA3_224;
var
  testData: TBytes;
  hash: TBytes;
  expected: string;
begin
  WriteLn('=== Testing SHA3-224 with EVP API ===');
  
  testData := StringToBytes('abc');
  expected := 'e642824c3f8cf24ad09234ee7d3c766fc9a3a5168d0c94ad73b46fdf';
  
  hash := SHA3_224Hash_EVP(testData);
  
  WriteLn('Input: "abc"');
  WriteLn('Expected: ', expected);
  WriteLn('Got:      ', BytesToHex(hash));
  
  if BytesToHex(hash) = expected then
    WriteLn('PASS: SHA3-224 test PASSED')
  else
    WriteLn('FAIL: SHA3-224 test FAILED');
  
  WriteLn;
end;

procedure TestSHA3_384;
var
  testData: TBytes;
  hash: TBytes;
  expected: string;
begin
  WriteLn('=== Testing SHA3-384 with EVP API ===');
  
  testData := StringToBytes('abc');
  expected := 'ec01498288516fc926459f58e2c6ad8df9b473cb0fc08c2596da7cf0e49be4b298d88cea927ac7f539f1edf228376d25';
  
  hash := SHA3_384Hash_EVP(testData);
  
  WriteLn('Input: "abc"');
  WriteLn('Expected: ', expected);
  WriteLn('Got:      ', BytesToHex(hash));
  
  if BytesToHex(hash) = expected then
    WriteLn('PASS: SHA3-384 test PASSED')
  else
    WriteLn('FAIL: SHA3-384 test FAILED');
  
  WriteLn;
end;

procedure TestSHA3_512;
var
  testData: TBytes;
  hash: TBytes;
  expected: string;
begin
  WriteLn('=== Testing SHA3-512 with EVP API ===');
  
  testData := StringToBytes('abc');
  expected := 'b751850b1a57168a5693cd924b6b096e08f621827444f70d884f5d0240d2712e10e116e9192af3c91a7ec57647e3934057340b4cf408d5a56592f8274eec53f0';
  
  hash := SHA3_512Hash_EVP(testData);
  
  WriteLn('Input: "abc"');
  WriteLn('Expected: ', expected);
  WriteLn('Got:      ', BytesToHex(hash));
  
  if BytesToHex(hash) = expected then
    WriteLn('PASS: SHA3-512 test PASSED')
  else
    WriteLn('FAIL: SHA3-512 test FAILED');
  
  WriteLn;
end;

procedure TestSHAKE128;
var
  testData: TBytes;
  hash: TBytes;
  expected: string;
begin
  WriteLn('=== Testing SHAKE128 with EVP API ===');
  
  testData := StringToBytes('abc');
  // SHAKE128 with 256 bits (32 bytes) output
  expected := '5881092dd818bf5cf8a3ddb793fbcba74097d5c526a6d35f97b83351940f2cc8';
  
  hash := SHAKE128Hash_EVP(testData, 32);
  
  WriteLn('Input: "abc", Output length: 32 bytes');
  WriteLn('Expected: ', expected);
  WriteLn('Got:      ', BytesToHex(hash));
  
  if BytesToHex(hash) = expected then
    WriteLn('PASS: SHAKE128 test PASSED')
  else
    WriteLn('FAIL: SHAKE128 test FAILED');
  
  WriteLn;
end;

procedure TestSHAKE256;
var
  testData: TBytes;
  hash: TBytes;
  expected: string;
begin
  WriteLn('=== Testing SHAKE256 with EVP API ===');
  
  testData := StringToBytes('abc');
  // SHAKE256 with 512 bits (64 bytes) output
  expected := '483366601360a8771c6863080cc4114d8db44530f8f1e1ee4f94ea37e78b5739d5a15bef186a5386c75744c0527e1faa9f8726e462a12a4feb06bd8801e751e4';
  
  hash := SHAKE256Hash_EVP(testData, 64);
  
  WriteLn('Input: "abc", Output length: 64 bytes');
  WriteLn('Expected: ', expected);
  WriteLn('Got:      ', BytesToHex(hash));
  
  if BytesToHex(hash) = expected then
    WriteLn('PASS: SHAKE256 test PASSED')
  else
    WriteLn('FAIL: SHAKE256 test FAILED');
  
  WriteLn;
end;

procedure TestEmptyString;
var
  testData: TBytes;
  hash: TBytes;
  expected: string;
begin
  WriteLn('=== Testing SHA3-256 with empty string ===');
  
  SetLength(testData, 0);
  expected := 'a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a';
  
  hash := SHA3_256Hash_EVP(testData);
  
  WriteLn('Input: (empty)');
  WriteLn('Expected: ', expected);
  WriteLn('Got:      ', BytesToHex(hash));
  
  if BytesToHex(hash) = expected then
    WriteLn('PASS: Empty string test PASSED')
  else
    WriteLn('FAIL: Empty string test FAILED');
  
  WriteLn;
end;

var
  libHandle: TLibHandle;
  dllNames: array[0..3] of string = ('libcrypto-3.dll', 'libcrypto-3-x64.dll', 'libcrypto-1_1-x64.dll', 'libcrypto.dll');
  i: Integer;
  dllName: string;

begin
  WriteLn('SHA3 EVP API Test Suite');
  WriteLn('=======================');
  WriteLn;
  
  // Try to load OpenSSL library with different names
  libHandle := 0;
  dllName := '';
  
  {$IFDEF WINDOWS}
  for i := 0 to High(dllNames) do
  begin
    WriteLn('Trying to load: ', dllNames[i]);
    libHandle := LoadLibrary(dllNames[i]);
    if libHandle <> 0 then
    begin
      dllName := dllNames[i];
      Break;
    end;
  end;
  {$ELSE}
  libHandle := LoadLibrary('libcrypto.so.3');
  dllName := 'libcrypto.so.3';
  if libHandle = 0 then
  begin
    libHandle := LoadLibrary('libcrypto.so');
    dllName := 'libcrypto.so';
  end;
  {$ENDIF}
  
  if libHandle = 0 then
  begin
    WriteLn;
    WriteLn('ERROR: Failed to load OpenSSL library');
    WriteLn('Please ensure OpenSSL is installed and accessible.');
    WriteLn('Tried: ', {$IFDEF WINDOWS}'libcrypto-3.dll, libcrypto-3-x64.dll, libcrypto-1_1-x64.dll, libcrypto.dll'{$ELSE}'libcrypto.so.3, libcrypto.so'{$ENDIF});
    Halt(1);
  end;
  
  try
    WriteLn;
    WriteLn('OpenSSL library loaded successfully: ', dllName);
    WriteLn('Library Handle: 0x', IntToHex(libHandle, 8));
    WriteLn;
    
    // Load EVP functions
    if not LoadEVP(libHandle) then
    begin
      WriteLn('ERROR: Failed to load EVP functions');
      Halt(1);
    end;
    
    WriteLn('EVP functions loaded successfully');
    WriteLn;
    
    // Check if EVP-based SHA3 is available
    if not IsEVPSHA3Available then
    begin
      WriteLn('WARNING: SHA3 is not available via EVP API');
      WriteLn('This may indicate an OpenSSL version issue or missing SHA3 support.');
      WriteLn;
    end
    else
    begin
      WriteLn('PASS: SHA3 is available via EVP API');
      WriteLn;
    end;
    
    // Run tests
    TestSHA3_224;
    TestSHA3_256;
    TestSHA3_384;
    TestSHA3_512;
    TestSHAKE128;
    TestSHAKE256;
    TestEmptyString;
    
    WriteLn('=== Test Summary ===');
    WriteLn('All tests completed. Please check results above.');
    
  finally
    UnloadEVP;
    FreeLibrary(libHandle);
  end;
  
  WriteLn;
  WriteLn('Press Enter to exit...');
  ReadLn;
end.
