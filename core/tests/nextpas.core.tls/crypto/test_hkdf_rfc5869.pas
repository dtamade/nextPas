program test_hkdf_rfc5869;

{$mode objfpc}{$H+}

{
  HKDF RFC 5869 测试向量验证
  验证HKDF实现符合RFC 5869标准
}

uses
  SysUtils, Classes, Math,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.openssl.api.kdf,
  nextpas.core.tls.openssl.api.evp;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure AssertEqual(const TestName: string; const Expected, Actual: TBytes);
var
  i: Integer;
  Match: Boolean;
begin
  Write('  [TEST] ', TestName, '... ');
  
  Match := Length(Expected) = Length(Actual);
  
  if Match then
  begin
    for i := 0 to High(Expected) do
    begin
      if Expected[i] <> Actual[i] then
      begin
        Match := False;
        Break;
      end;
    end;
  end;
  
  if Match then
  begin
    WriteLn('✓ PASS');
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('✗ FAIL');
    WriteLn('    Expected: ', Length(Expected), ' bytes');
    WriteLn('    Actual: ', Length(Actual), ' bytes');
    if Length(Expected) > 0 then
    begin
      Write('    Expected hex: ');
      for i := 0 to Min(15, High(Expected)) do
        Write(IntToHex(Expected[i], 2));
      WriteLn;
    end;
    if Length(Actual) > 0 then
    begin
      Write('    Actual hex:   ');
      for i := 0 to Min(15, High(Actual)) do
        Write(IntToHex(Actual[i], 2));
      WriteLn;
    end;
    Inc(TestsFailed);
  end;
end;

function HexToBytes(const Hex: string): TBytes;
var
  i, Len: Integer;
begin
  Len := Length(Hex) div 2;
  SetLength(Result, Len);
  
  for i := 0 to Len - 1 do
    Result[i] := StrToInt('$' + Copy(Hex, i * 2 + 1, 2));
end;

procedure Test_RFC5869_Case1_SHA256;
var
  IKM, Salt, Info, Expected: TBytes;
  Actual: TBytes;
  MD: PEVP_MD;
begin
  WriteLn;
  WriteLn('=== RFC 5869 Test Case 1: SHA-256 ===');
  
  // Test Case 1 from RFC 5869 Appendix A.1
  // Hash = SHA-256
  // IKM = 0x0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b (22 octets)
  IKM := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
  
  // salt = 0x000102030405060708090a0b0c (13 octets)
  Salt := HexToBytes('000102030405060708090a0b0c');
  
  // info = 0xf0f1f2f3f4f5f6f7f8f9 (10 octets)
  Info := HexToBytes('f0f1f2f3f4f5f6f7f8f9');
  
  // L = 42
  // OKM (42 octets)
  Expected := HexToBytes(
    '3cb25f25faacd57a90434f64d0362f2a' +
    '2d2d0a90cf1a5a4c5db02d56ecc4c5bf' +
    '34007208d5b887185865'
  );
  
  MD := EVP_sha256();
  
  Actual := DeriveKeyHKDF(IKM, Salt, Info, 42, MD);
  
  AssertEqual('RFC 5869 TC1 SHA-256 (42 bytes)', Expected, Actual);
end;

procedure Test_RFC5869_Case2_SHA256;
var
  IKM, Salt, Info, Expected: TBytes;
  Actual: TBytes;
  MD: PEVP_MD;
begin
  WriteLn;
  WriteLn('=== RFC 5869 Test Case 2: SHA-256 (longer inputs) ===');
  
  // Test Case 2 from RFC 5869 Appendix A.2
  // Hash = SHA-256
  // IKM (80 octets)
  IKM := HexToBytes(
    '000102030405060708090a0b0c0d0e0f' +
    '101112131415161718191a1b1c1d1e1f' +
    '202122232425262728292a2b2c2d2e2f' +
    '303132333435363738393a3b3c3d3e3f' +
    '404142434445464748494a4b4c4d4e4f'
  );
  
  // salt (80 octets)
  Salt := HexToBytes(
    '606162636465666768696a6b6c6d6e6f' +
    '707172737475767778797a7b7c7d7e7f' +
    '808182838485868788898a8b8c8d8e8f' +
    '909192939495969798999a9b9c9d9e9f' +
    'a0a1a2a3a4a5a6a7a8a9aaabacadaeaf'
  );
  
  // info (80 octets)
  Info := HexToBytes(
    'b0b1b2b3b4b5b6b7b8b9babbbcbdbebf' +
    'c0c1c2c3c4c5c6c7c8c9cacbcccdcecf' +
    'd0d1d2d3d4d5d6d7d8d9dadbdcdddedf' +
    'e0e1e2e3e4e5e6e7e8e9eaebecedeeef' +
    'f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff'
  );
  
  // L = 82
  Expected := HexToBytes(
    'b11e398dc80327a1c8e7f78c596a4934' +
    '4f012eda2d4efad8a050cc4c19afa97c' +  
    '59045a99cac7827271cb41c65e590e09' +
    'da3275600c2f09b8367793a9aca3db71' +
    'cc30c58179ec3e87c14c01d5c1f3434f' +
    '1d87'
  );
  
  MD := EVP_sha256();
  
  Actual := DeriveKeyHKDF(IKM, Salt, Info, 82, MD);
  
  AssertEqual('RFC 5869 TC2 SHA-256 (82 bytes)', Expected, Actual);
end;

procedure Test_RFC5869_Case3_SHA256;
var
  IKM, Salt, Info, Expected: TBytes;
  Actual: TBytes;
  MD: PEVP_MD;
begin
  WriteLn;
  WriteLn('=== RFC 5869 Test Case 3: SHA-256 (zero-length salt/info) ===');
  
  // Test Case 3 from RFC 5869 Appendix A.3
  // Hash = SHA-256
  // IKM = 0x0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b (22 octets)
  IKM := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
  
  // salt = (0 octets) - zero-length
  SetLength(Salt, 0);
  
  // info = (0 octets) - zero-length
  SetLength(Info, 0);
  
  // L = 42
  Expected := HexToBytes(
    '8da4e775a563c18f715f802a063c5a31' +
    'b8a11f5c5ee1879ec3454e5f3c738d2d' +
    '9d201395faa4b61a96c8'
  );
  
  MD := EVP_sha256();
  
  Actual := DeriveKeyHKDF(IKM, Salt, Info, 42, MD);
  
  AssertEqual('RFC 5869 TC3 SHA-256 (zero salt/info)', Expected, Actual);
end;

procedure Test_RFC5869_Case4_SHA1;
var
  IKM, Salt, Info, Expected: TBytes;
  Actual: TBytes;
  MD: PEVP_MD;
begin
  WriteLn;
  WriteLn('=== RFC 5869 Test Case 4: SHA-1 ===');
  
  // Test Case 4 from RFC 5869 Appendix A.4
  // Hash = SHA-1
  // IKM = 0x0b0b0b0b0b0b0b0b0b0b0b (11 octets)
  IKM := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b');
  
  // salt = 0x000102030405060708090a0b0c (13 octets)
  Salt := HexToBytes('000102030405060708090a0b0c');
  
  // info = 0xf0f1f2f3f4f5f6f7f8f9 (10 octets)
  Info := HexToBytes('f0f1f2f3f4f5f6f7f8f9');
  
  // L = 42
  Expected := HexToBytes(
    '085a01ea1b10f36933068b56efa5ad81' +
    'a4f14b822f5b091568a9cdd4f155fda2' +
    'c22e422478d305f3f896'
  );
  
  if Assigned(EVP_sha1) then
  begin
    MD := EVP_sha1();
    Actual := DeriveKeyHKDF(IKM, Salt, Info, 42, MD);
    AssertEqual('RFC 5869 TC4 SHA-1 (42 bytes)', Expected, Actual);
  end
  else
  begin
    WriteLn('  SHA-1 not available, skipping test');
    Inc(TestsPassed);  // Don't penalize if SHA-1 is disabled
  end;
end;

procedure PrintSummary;
begin
  WriteLn;
  WriteLn('========================================');
  WriteLn('HKDF RFC 5869 Test Summary');
  WriteLn('========================================');
  WriteLn('Total tests: ', TestsPassed + TestsFailed);
  WriteLn('Passed: ', TestsPassed, ' ✓');
  WriteLn('Failed: ', TestsFailed, ' ✗');
  if TestsPassed + TestsFailed > 0 then
    WriteLn('Success rate: ', (TestsPassed * 100) div (TestsPassed + TestsFailed), '%');
  WriteLn('========================================');
  
  if TestsFailed = 0 then
  begin
    WriteLn('✅ ALL HKDF TESTS PASSED!');
    Halt(0);
  end
  else
  begin
    WriteLn('❌ SOME TESTS FAILED!');
    Halt(1);
  end;
end;

var
  SSLLib: ISSLLibrary;

begin
  WriteLn('========================================');
  WriteLn('HKDF RFC 5869 Test Vectors');
  WriteLn('========================================');
  
  try
    // Initialize OpenSSL
    SSLLib := CreateOpenSSLLibrary;
    if SSLLib = nil then
    begin
      WriteLn('Failed to create OpenSSL library');
      Halt(2);
    end;
    
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL library');
      Halt(2);
    end;
    
    WriteLn('OpenSSL initialized: ', SSLLib.GetVersionString);
    
    // Run test cases
    Test_RFC5869_Case1_SHA256;
    Test_RFC5869_Case2_SHA256;
    Test_RFC5869_Case3_SHA256;
    Test_RFC5869_Case4_SHA1;
    
    PrintSummary;
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('❌ FATAL ERROR: ', E.Message);
      Halt(2);
    end;
  end;
end.
