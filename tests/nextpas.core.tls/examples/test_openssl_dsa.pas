program test_openssl_dsa;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api.types,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.dsa,
  nextpas.core.tls.openssl.api.bn;

var
  TestsPassed, TestsFailed: Integer;

procedure TestDSACreateFree;
var
  dsa: PDSA;
begin
  Write('  [DSA Create/Free] ');
  dsa := DSA_new();
  if not Assigned(dsa) then
    raise Exception.Create('DSA_new failed');
  DSA_free(dsa);
  WriteLn('PASS');
  Inc(TestsPassed);
end;

procedure TestDSAKeyGeneration;
var
  dsa: PDSA;
  ret: Integer;
  pub_key, priv_key: PBIGNUM;
begin
  Write('  [DSA Key Generation] ');
  
  dsa := DSA_new();
  if not Assigned(dsa) then
    raise Exception.Create('DSA_new failed');
  
  try
    // Generate 1024-bit DSA parameters (faster for testing)
    ret := DSA_generate_parameters_ex(dsa, 1024, nil, 0, nil, nil, nil);
    if ret <> 1 then
      raise Exception.CreateFmt('DSA_generate_parameters_ex failed: %d', [ret]);
    
    // Generate key pair
    ret := DSA_generate_key(dsa);
    if ret <> 1 then
      raise Exception.CreateFmt('DSA_generate_key failed: %d', [ret]);
    
    // Verify keys were generated
    DSA_get0_key(dsa, @pub_key, @priv_key);
    if not Assigned(pub_key) then
      raise Exception.Create('Public key not generated');
    if not Assigned(priv_key) then
      raise Exception.Create('Private key not generated');
    
    WriteLn('PASS');
    Inc(TestsPassed);
  finally
    DSA_free(dsa);
  end;
end;

procedure TestDSASignVerify;
var
  dsa: PDSA;
  ret: Integer;
  digest: array[0..19] of Byte;  // SHA-1 digest (20 bytes)
  sig: array[0..255] of Byte;
  siglen: Cardinal;
  i: Integer;
begin
  Write('  [DSA Sign/Verify] ');
  
  dsa := DSA_new();
  if not Assigned(dsa) then
    raise Exception.Create('DSA_new failed');
  
  try
    // Generate parameters and keys
    ret := DSA_generate_parameters_ex(dsa, 1024, nil, 0, nil, nil, nil);
    if ret <> 1 then
      raise Exception.CreateFmt('Parameter generation failed: %d', [ret]);
    
    ret := DSA_generate_key(dsa);
    if ret <> 1 then
      raise Exception.CreateFmt('Key generation failed: %d', [ret]);
    
    // Create a test digest
    for i := 0 to 19 do
      digest[i] := Byte(i);
    
    // Sign the digest
    siglen := 0;
    ret := DSA_sign(0, @digest[0], 20, @sig[0], @siglen, dsa);
    if ret <> 1 then
      raise Exception.CreateFmt('DSA_sign failed: %d', [ret]);
    
    if siglen = 0 then
      raise Exception.Create('Signature length is zero');
    
    // Verify the signature
    ret := DSA_verify(0, @digest[0], 20, @sig[0], siglen, dsa);
    if ret <> 1 then
      raise Exception.CreateFmt('DSA_verify failed: %d', [ret]);
    
    WriteLn('PASS');
    Inc(TestsPassed);
  finally
    DSA_free(dsa);
  end;
end;

procedure TestDSASize;
var
  dsa: PDSA;
  size: Integer;
begin
  Write('  [DSA Size] ');
  
  dsa := DSA_new();
  if not Assigned(dsa) then
    raise Exception.Create('DSA_new failed');
  
  try
    // Generate 1024-bit parameters
    if DSA_generate_parameters_ex(dsa, 1024, nil, 0, nil, nil, nil) <> 1 then
      raise Exception.Create('Parameter generation failed');
    
    size := DSA_size(dsa);
    // For 1024-bit DSA, signature size should be around 46-48 bytes
    if (size < 40) or (size > 60) then
      raise Exception.CreateFmt('Unexpected DSA size: %d', [size]);
    
    WriteLn('PASS');
    Inc(TestsPassed);
  finally
    DSA_free(dsa);
  end;
end;

procedure RunTest(const TestName: string; TestProc: TProcedure);
begin
  try
    TestProc();
  except
    on E: Exception do
    begin
      WriteLn('  [', TestName, '] FAIL: ', E.Message);
      Inc(TestsFailed);
    end;
  end;
end;

begin
  TestsPassed := 0;
  TestsFailed := 0;
  
  WriteLn('OpenSSL DSA (Digital Signature Algorithm) Module Test');
  WriteLn('======================================================');
  WriteLn;
  
  // Load OpenSSL
  Write('Loading OpenSSL... ');
  LoadOpenSSLCore;
  WriteLn('OK');
  
  Write('Loading DSA module... ');
  if not LoadOpenSSLDSA then
  begin
    WriteLn('FAILED');
    WriteLn('Error: Could not load DSA module');
    Halt(1);
  end;
  WriteLn('OK');
  
  WriteLn;
  WriteLn('Running Tests:');
  WriteLn;
  
  // Run tests
  RunTest('DSA Create/Free', @TestDSACreateFree);
  RunTest('DSA Key Generation', @TestDSAKeyGeneration);
  RunTest('DSA Sign/Verify', @TestDSASignVerify);
  RunTest('DSA Size', @TestDSASize);
  
  // Summary
  WriteLn;
  WriteLn('Test Summary:');
  WriteLn('=============');
  WriteLn('Tests Passed: ', TestsPassed);
  WriteLn('Tests Failed: ', TestsFailed);
  WriteLn('Total Tests:  ', TestsPassed + TestsFailed);
  WriteLn;
  
  if TestsFailed = 0 then
  begin
    WriteLn('All tests PASSED!');
    Halt(0);
  end
  else
  begin
    WriteLn('Some tests FAILED!');
    Halt(1);
  end;
end.