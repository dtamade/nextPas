program test_openssl_dh;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api.types,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.dh,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.api.err;

var
  TestsPassed, TestsFailed: Integer;

procedure TestDHCreateFree;
var
  dh: PDH;
begin
  Write('  [DH Create/Free] ');
  dh := DH_new();
  if not Assigned(dh) then
    raise Exception.Create('DH_new failed');
  DH_free(dh);
  WriteLn('PASS');
  Inc(TestsPassed);
end;

procedure TestDHStandardParams;
var
  dh: PDH;
  bits: Integer;
begin
  Write('  [DH Standard 2048-bit params] ');
  dh := DH_get_2048_256();
  if not Assigned(dh) then
    raise Exception.Create('DH_get_2048_256 failed');
  
  bits := DH_bits(dh);
  if bits <> 2048 then
    raise Exception.CreateFmt('Expected 2048 bits, got %d', [bits]);
  
  DH_free(dh);
  WriteLn('PASS');
  Inc(TestsPassed);
end;

procedure TestDHKeyGeneration;
var
  dh: PDH;
  ret: Integer;
  pub_key, priv_key: PBIGNUM;
begin
  Write('  [DH Key Generation] ');
  
  // Use standard 2048-bit parameters
  dh := DH_get_2048_256();
  if not Assigned(dh) then
    raise Exception.Create('DH_get_2048_256 failed');
  
  try
    // Generate key pair
    ret := DH_generate_key(dh);
    if ret <> 1 then
      raise Exception.CreateFmt('DH_generate_key failed: %d', [ret]);
    
    // Verify keys were generated
    DH_get0_key(dh, @pub_key, @priv_key);
    if not Assigned(pub_key) then
      raise Exception.Create('Public key not generated');
    if not Assigned(priv_key) then
      raise Exception.Create('Private key not generated');
    
    WriteLn('PASS');
    Inc(TestsPassed);
  finally
    DH_free(dh);
  end;
end;

procedure TestDHKeyExchange;
var
  dh1, dh2: PDH;
  pub_key1, pub_key2: PBIGNUM;
  priv_key1, priv_key2: PBIGNUM;
  shared_secret1, shared_secret2: array[0..255] of Byte;
  secret_len1, secret_len2: Integer;
  i: Integer;
  match: Boolean;
begin
  Write('  [DH Key Exchange] ');
  
  // Create first DH instance
  dh1 := DH_get_2048_256();
  if not Assigned(dh1) then
    raise Exception.Create('DH_get_2048_256 (1) failed');
  
  // Create second DH instance
  dh2 := DH_get_2048_256();
  if not Assigned(dh2) then
  begin
    DH_free(dh1);
    raise Exception.Create('DH_get_2048_256 (2) failed');
  end;
  
  try
    // Generate keys for both parties
    if DH_generate_key(dh1) <> 1 then
      raise Exception.Create('DH_generate_key (1) failed');
    if DH_generate_key(dh2) <> 1 then
      raise Exception.Create('DH_generate_key (2) failed');
    
    // Get public keys
    DH_get0_key(dh1, @pub_key1, @priv_key1);
    DH_get0_key(dh2, @pub_key2, @priv_key2);
    
    // Compute shared secrets
    secret_len1 := DH_compute_key(@shared_secret1[0], pub_key2, dh1);
    if secret_len1 < 0 then
      raise Exception.Create('DH_compute_key (1) failed');
    
    secret_len2 := DH_compute_key(@shared_secret2[0], pub_key1, dh2);
    if secret_len2 < 0 then
      raise Exception.Create('DH_compute_key (2) failed');
    
    // Verify shared secrets match
    if secret_len1 <> secret_len2 then
      raise Exception.CreateFmt('Secret length mismatch: %d vs %d', [secret_len1, secret_len2]);
    
    match := True;
    for i := 0 to secret_len1 - 1 do
    begin
      if shared_secret1[i] <> shared_secret2[i] then
      begin
        match := False;
        Break;
      end;
    end;
    
    if not match then
      raise Exception.Create('Shared secrets do not match');
    
    WriteLn('PASS');
    Inc(TestsPassed);
  finally
    DH_free(dh1);
    DH_free(dh2);
  end;
end;

procedure TestDHCheck;
var
  dh: PDH;
  codes: Integer;
  ret: Integer;
begin
  Write('  [DH Parameter Check] ');
  
  dh := DH_get_2048_256();
  if not Assigned(dh) then
    raise Exception.Create('DH_get_2048_256 failed');
  
  try
    codes := 0;
    ret := DH_check(dh, @codes);
    if ret <> 1 then
      raise Exception.CreateFmt('DH_check failed: %d', [ret]);
    
    if codes <> 0 then
      raise Exception.CreateFmt('DH parameters have issues: code %d', [codes]);
    
    WriteLn('PASS');
    Inc(TestsPassed);
  finally
    DH_free(dh);
  end;
end;

procedure TestDHSize;
var
  dh: PDH;
  size: Integer;
begin
  Write('  [DH Size] ');
  
  dh := DH_get_2048_256();
  if not Assigned(dh) then
    raise Exception.Create('DH_get_2048_256 failed');
  
  try
    size := DH_size(dh);
    // 2048 bits = 256 bytes
    if size <> 256 then
      raise Exception.CreateFmt('Expected size 256, got %d', [size]);
    
    WriteLn('PASS');
    Inc(TestsPassed);
  finally
    DH_free(dh);
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
  
  WriteLn('OpenSSL DH (Diffie-Hellman) Module Test');
  WriteLn('========================================');
  WriteLn;
  
  // Load OpenSSL
  Write('Loading OpenSSL... ');
  LoadOpenSSLCore;
  WriteLn('OK');
  
  Write('Loading DH module... ');
  if not LoadOpenSSLDH then
  begin
    WriteLn('FAILED');
    WriteLn('Error: Could not load DH module');
    Halt(1);
  end;
  WriteLn('OK');
  
  WriteLn;
  WriteLn('Running Tests:');
  WriteLn;
  
  // Run tests
  RunTest('DH Create/Free', @TestDHCreateFree);
  RunTest('DH Standard Params', @TestDHStandardParams);
  RunTest('DH Key Generation', @TestDHKeyGeneration);
  RunTest('DH Key Exchange', @TestDHKeyExchange);
  RunTest('DH Check', @TestDHCheck);
  RunTest('DH Size', @TestDHSize);
  
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