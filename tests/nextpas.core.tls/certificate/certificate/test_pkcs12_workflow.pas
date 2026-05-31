program test_pkcs12_workflow;

{$mode objfpc}{$H+}{$J-}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  SysUtils, ctypes,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.rsa,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.api.asn1,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.stack,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.err,
  nextpas.core.tls.openssl.api.pkcs12,
  nextpas.core.tls.openssl.api.consts;

const
  TEST_PASSWORD = 'test_password_123';
  TEST_FRIENDLY_NAME = 'Test PKCS12 Certificate';

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  TestCert: PX509 = nil;
  TestPrivKey: PEVP_PKEY = nil;

procedure Pass(const TestName: string);
begin
  Inc(TestsPassed);
  WriteLn('[PASS] ', TestName);
end;

procedure Fail(const TestName, Reason: string);
begin
  Inc(TestsFailed);
  WriteLn('[FAIL] ', TestName, ': ', Reason);
end;

procedure TestSection(const Name: string);
begin
  WriteLn;
  WriteLn(StringOfChar('=', 70));
  WriteLn(' ', Name);
  WriteLn(StringOfChar('=', 70));
end;

// Generate test certificate and key
function GenerateTestCertAndKey: Boolean;
var
  pkey: PEVP_PKEY;
  x509: PX509;
  rsa: PRSA;
  name: PX509_NAME;
  bn: PBIGNUM;
  serial: PASN1_INTEGER;
begin
  Result := False;
  TestCert := nil;
  TestPrivKey := nil;

  // Generate RSA key
  pkey := EVP_PKEY_new();
  if pkey = nil then Exit;

  rsa := RSA_new();
  if rsa = nil then
  begin
    EVP_PKEY_free(pkey);
    Exit;
  end;

  bn := BN_new();
  if bn = nil then
  begin
    RSA_free(rsa);
    EVP_PKEY_free(pkey);
    Exit;
  end;

  BN_set_word(bn, RSA_F4);

  if RSA_generate_key_ex(rsa, 2048, bn, nil) <> 1 then
  begin
    BN_free(bn);
    RSA_free(rsa);
    EVP_PKEY_free(pkey);
    Exit;
  end;

  BN_free(bn);

  if EVP_PKEY_assign(pkey, EVP_PKEY_RSA, rsa) <> 1 then
  begin
    RSA_free(rsa);
    EVP_PKEY_free(pkey);
    Exit;
  end;

  // Create certificate
  x509 := X509_new();
  if x509 = nil then
  begin
    EVP_PKEY_free(pkey);
    Exit;
  end;

  // Set version
  X509_set_version(x509, 2);

  // Set serial number
  serial := X509_get_serialNumber(x509);
  ASN1_INTEGER_set(serial, 1);

  // Set validity
  X509_gmtime_adj(X509_get_notBefore(x509), 0);
  X509_gmtime_adj(X509_get_notAfter(x509), 60 * 60 * 24 * 365); // 1 year

  // Set public key
  X509_set_pubkey(x509, pkey);

  // Set subject name
  name := X509_get_subject_name(x509);
  X509_NAME_add_entry_by_txt(name, 'C', MBSTRING_ASC, PByte(PAnsiChar('US')), -1, -1, 0);
  X509_NAME_add_entry_by_txt(name, 'O', MBSTRING_ASC, PByte(PAnsiChar('Test Org')), -1, -1, 0);
  X509_NAME_add_entry_by_txt(name, 'CN', MBSTRING_ASC, PByte(PAnsiChar('Test Certificate')), -1, -1, 0);

  // Set issuer name (self-signed)
  X509_set_issuer_name(x509, name);

  // Sign certificate
  if X509_sign(x509, pkey, EVP_sha256()) = 0 then
  begin
    X509_free(x509);
    EVP_PKEY_free(pkey);
    Exit;
  end;

  TestCert := x509;
  TestPrivKey := pkey;
  Result := True;
end;

procedure FreeTestCertAndKey;
begin
  if TestCert <> nil then
  begin
    X509_free(TestCert);
    TestCert := nil;
  end;

  if TestPrivKey <> nil then
  begin
    EVP_PKEY_free(TestPrivKey);
    TestPrivKey := nil;
  end;
end;

// Test 1: Create and parse PKCS12 workflow
procedure Test_01_CreateAndParse_Workflow;
const
  TEST_NAME = 'PKCS12 create and parse complete workflow';
var
  p12: PPKCS12;
  cert_out: PX509;
  pkey_out: PEVP_PKEY;
  ca_out: PSTACK_OF_X509;
begin
  if (TestCert = nil) or (TestPrivKey = nil) then
  begin
    Fail(TEST_NAME, 'Test cert/key not available');
    Exit;
  end;

  // Create PKCS12 structure
  p12 := PKCS12_create(
    PAnsiChar(TEST_PASSWORD),
    PAnsiChar(TEST_FRIENDLY_NAME),
    TestPrivKey,
    TestCert,
    nil,  // no CA certificates
    0,    // default encryption
    0,    // default encryption
    0,    // default iteration count
    0,    // default MAC iteration count
    0     // default key type
  );

  if p12 = nil then
  begin
    Fail(TEST_NAME, 'PKCS12_create failed');
    Exit;
  end;

  try
    WriteLn('[INFO] PKCS12 structure created successfully');

    // Parse PKCS12 structure
    cert_out := nil;
    pkey_out := nil;
    ca_out := nil;

    if PKCS12_parse(p12, PAnsiChar(TEST_PASSWORD), pkey_out, cert_out, ca_out) <> 1 then
    begin
      Fail(TEST_NAME, 'PKCS12_parse failed');
      Exit;
    end;

    try
      if (cert_out = nil) or (pkey_out = nil) then
      begin
        Fail(TEST_NAME, 'Parsed certificate or key is nil');
        Exit;
      end;

      WriteLn('[INFO] PKCS12 structure parsed successfully');
      WriteLn('[INFO] Certificate and private key extracted');
      Pass(TEST_NAME);
    finally
      if cert_out <> nil then X509_free(cert_out);
      if pkey_out <> nil then EVP_PKEY_free(pkey_out);
      // Note: ca_out stack cleanup would need sk_X509_pop_free if it was populated
    end;
  finally
    PKCS12_free(p12);
  end;
end;

// Test 2: PKCS12 with different encryption algorithms
procedure Test_02_DifferentEncryption;
const
  TEST_NAME = 'PKCS12 with different encryption algorithms';
var
  p12_default: PPKCS12;
  p12_3des: PPKCS12;
begin
  if (TestCert = nil) or (TestPrivKey = nil) then
  begin
    Fail(TEST_NAME, 'Test cert/key not available');
    Exit;
  end;

  // Test with default encryption
  p12_default := PKCS12_create(
    PAnsiChar(TEST_PASSWORD),
    PAnsiChar('Default Encryption'),
    TestPrivKey,
    TestCert,
    nil, 0, 0, 0, 0, 0
  );

  if p12_default = nil then
  begin
    Fail(TEST_NAME, 'Default encryption failed');
    Exit;
  end;
  PKCS12_free(p12_default);
  WriteLn('[INFO] Default encryption PKCS12 created');

  // Test with 3DES encryption
  p12_3des := PKCS12_create(
    PAnsiChar(TEST_PASSWORD),
    PAnsiChar('3DES Encryption'),
    TestPrivKey,
    TestCert,
    nil,
    NID_pbe_WithSHA1And3_Key_TripleDES_CBC,
    NID_pbe_WithSHA1And3_Key_TripleDES_CBC,
    0, 0, 0
  );

  if p12_3des = nil then
  begin
    Fail(TEST_NAME, '3DES encryption failed');
    Exit;
  end;
  PKCS12_free(p12_3des);
  WriteLn('[INFO] 3DES encryption PKCS12 created');

  Pass(TEST_NAME);
end;

// Test 3: PKCS12 with different iteration counts
procedure Test_03_DifferentIterations;
const
  TEST_NAME = 'PKCS12 with different iteration counts';
var
  p12_default: PPKCS12;
  p12_high: PPKCS12;
begin
  if (TestCert = nil) or (TestPrivKey = nil) then
  begin
    Fail(TEST_NAME, 'Test cert/key not available');
    Exit;
  end;

  // Test with default iteration count
  p12_default := PKCS12_create(
    PAnsiChar(TEST_PASSWORD),
    PAnsiChar('Default Iterations'),
    TestPrivKey,
    TestCert,
    nil, 0, 0,
    0,  // default iteration count
    0,  // default MAC iteration count
    0
  );

  if p12_default = nil then
  begin
    Fail(TEST_NAME, 'Default iteration count failed');
    Exit;
  end;
  PKCS12_free(p12_default);
  WriteLn('[INFO] Default iteration count PKCS12 created');

  // Test with high iteration count (more secure but slower)
  p12_high := PKCS12_create(
    PAnsiChar(TEST_PASSWORD),
    PAnsiChar('High Iterations'),
    TestPrivKey,
    TestCert,
    nil, 0, 0,
    10000,  // high iteration count
    10000,  // high MAC iteration count
    0
  );

  if p12_high = nil then
  begin
    Fail(TEST_NAME, 'High iteration count failed');
    Exit;
  end;
  PKCS12_free(p12_high);
  WriteLn('[INFO] High iteration count PKCS12 created');

  Pass(TEST_NAME);
end;

// Test 4: PKCS12 BIO read/write operations
procedure Test_04_BIO_ReadWrite;
const
  TEST_NAME = 'PKCS12 BIO read/write operations';
var
  p12: PPKCS12;
  bio: PBIO;
  p12_read: PPKCS12;
  cert_out: PX509;
  pkey_out: PEVP_PKEY;
  ca_out: PSTACK_OF_X509;
begin
  if (TestCert = nil) or (TestPrivKey = nil) then
  begin
    Fail(TEST_NAME, 'Test cert/key not available');
    Exit;
  end;

  // Create PKCS12 structure
  p12 := PKCS12_create(
    PAnsiChar(TEST_PASSWORD),
    PAnsiChar(TEST_FRIENDLY_NAME),
    TestPrivKey,
    TestCert,
    nil, 0, 0, 0, 0, 0
  );

  if p12 = nil then
  begin
    Fail(TEST_NAME, 'PKCS12_create failed');
    Exit;
  end;

  try
    // Write to BIO
    bio := BIO_new(BIO_s_mem());
    if bio = nil then
    begin
      Fail(TEST_NAME, 'Failed to create BIO');
      Exit;
    end;

    try
      if i2d_PKCS12_bio(bio, p12) <> 1 then
      begin
        Fail(TEST_NAME, 'Failed to write PKCS12 to BIO');
        Exit;
      end;

      WriteLn('[INFO] PKCS12 written to BIO successfully');

      // Read from BIO
      p12_read := d2i_PKCS12_bio(bio, p12_read);
      if p12_read = nil then
      begin
        Fail(TEST_NAME, 'Failed to read PKCS12 from BIO');
        Exit;
      end;

      try
        WriteLn('[INFO] PKCS12 read from BIO successfully');

        // Verify by parsing
        cert_out := nil;
        pkey_out := nil;
        ca_out := nil;

        if PKCS12_parse(p12_read, PAnsiChar(TEST_PASSWORD), pkey_out, cert_out, ca_out) <> 1 then
        begin
          Fail(TEST_NAME, 'Failed to parse read PKCS12');
          Exit;
        end;

        try
          if (cert_out = nil) or (pkey_out = nil) then
          begin
            Fail(TEST_NAME, 'Parsed certificate or key is nil');
            Exit;
          end;

          WriteLn('[INFO] Read PKCS12 parsed successfully');
          Pass(TEST_NAME);
        finally
          if cert_out <> nil then X509_free(cert_out);
          if pkey_out <> nil then EVP_PKEY_free(pkey_out);
        end;
      finally
        PKCS12_free(p12_read);
      end;
    finally
      BIO_free(bio);
    end;
  finally
    PKCS12_free(p12);
  end;
end;

// Test 5: Wrong password detection
procedure Test_05_WrongPassword;
const
  TEST_NAME = 'PKCS12 wrong password detection';
var
  p12: PPKCS12;
  cert_out: PX509;
  pkey_out: PEVP_PKEY;
  ca_out: PSTACK_OF_X509;
  result: Integer;
begin
  if (TestCert = nil) or (TestPrivKey = nil) then
  begin
    Fail(TEST_NAME, 'Test cert/key not available');
    Exit;
  end;

  // Create PKCS12 structure
  p12 := PKCS12_create(
    PAnsiChar(TEST_PASSWORD),
    PAnsiChar(TEST_FRIENDLY_NAME),
    TestPrivKey,
    TestCert,
    nil, 0, 0, 0, 0, 0
  );

  if p12 = nil then
  begin
    Fail(TEST_NAME, 'PKCS12_create failed');
    Exit;
  end;

  try
    // Try to parse with wrong password
    cert_out := nil;
    pkey_out := nil;
    ca_out := nil;

    result := PKCS12_parse(p12, PAnsiChar('wrong_password'), pkey_out, cert_out, ca_out);

    if result = 1 then
    begin
      // Cleanup if somehow succeeded
      if cert_out <> nil then X509_free(cert_out);
      if pkey_out <> nil then EVP_PKEY_free(pkey_out);
      Fail(TEST_NAME, 'Wrong password not detected (parse succeeded)');
    end
    else
    begin
      WriteLn('[INFO] Wrong password correctly detected (parse failed as expected)');
      Pass(TEST_NAME);
    end;
  finally
    PKCS12_free(p12);
  end;
end;

procedure RunAllTests;
begin
  WriteLn('================================================================================');
  WriteLn('           PKCS12 Complete Workflow Comprehensive Test');
  WriteLn('================================================================================');
  WriteLn;
  WriteLn('Purpose: Validate complete PKCS12 create/load/export workflow');
  WriteLn;

  // Initialize OpenSSL
  try
    LoadOpenSSLCore;
  except
    on E: Exception do
    begin
      WriteLn('ERROR: Failed to load OpenSSL core library: ', E.Message);
      Halt(1);
    end;
  end;

  // Load required modules
  LoadOpenSSLBIO;

  if not LoadEVP(GetCryptoLibHandle) then
  begin
    WriteLn('ERROR: Failed to load EVP functions');
    Halt(1);
  end;

  LoadOpenSSLX509;

  if not LoadOpenSSLRSA then
  begin
    WriteLn('ERROR: Failed to load RSA functions');
    Halt(1);
  end;

  if not LoadOpenSSLBN then
  begin
    WriteLn('ERROR: Failed to load BN functions');
    Halt(1);
  end;

  if not LoadOpenSSLASN1(GetCryptoLibHandle) then
  begin
    WriteLn('ERROR: Failed to load ASN1 functions');
    Halt(1);
  end;

  if not LoadOpenSSLPEM(GetCryptoLibHandle) then
  begin
    WriteLn('ERROR: Failed to load PEM functions');
    Halt(1);
  end;

  if not LoadOpenSSLERR then
  begin
    WriteLn('ERROR: Failed to load ERR functions');
    Halt(1);
  end;

  if not LoadStackFunctions then
  begin
    WriteLn('ERROR: Failed to load Stack functions');
    Halt(1);
  end;

  LoadPKCS12Module(GetCryptoLibHandle);

  WriteLn('[OK] All required OpenSSL modules loaded successfully');
  WriteLn;

  // Generate test certificate and key
  TestSection('Test Setup: Generate Certificate and Key');
  WriteLn('[INFO] Generating test certificate and key pair...');
  if GenerateTestCertAndKey then
  begin
    WriteLn('[INFO] Test cert/key generated successfully');
    WriteLn;

    try
      // Run tests
      TestSection('Test 1: Create and Parse Workflow');
      Test_01_CreateAndParse_Workflow;

      TestSection('Test 2: Different Encryption Algorithms');
      Test_02_DifferentEncryption;

      TestSection('Test 3: Different Iteration Counts');
      Test_03_DifferentIterations;

      TestSection('Test 4: BIO Read/Write Operations');
      Test_04_BIO_ReadWrite;

      TestSection('Test 5: Wrong Password Detection');
      Test_05_WrongPassword;
    finally
      FreeTestCertAndKey;
    end;
  end
  else
  begin
    WriteLn('[ERROR] Failed to generate test cert/key');
    Halt(1);
  end;

  // Results
  WriteLn;
  WriteLn('================================================================================');
  WriteLn('                             Test Results Summary');
  WriteLn('================================================================================');
  WriteLn;
  WriteLn(Format('Total Tests:  %d', [TestsPassed + TestsFailed]));
  WriteLn(Format('Passed:       %d', [TestsPassed]));
  WriteLn(Format('Failed:       %d', [TestsFailed]));

  if TestsFailed = 0 then
  begin
    WriteLn;
    WriteLn('Result: ALL TESTS PASSED [OK]');
    WriteLn;
    WriteLn('PKCS12 complete workflow is fully functional:');
    WriteLn('  ✓ Create and parse workflow');
    WriteLn('  ✓ Different encryption algorithms (default, 3DES)');
    WriteLn('  ✓ Different iteration counts (default, high security)');
    WriteLn('  ✓ BIO read/write operations');
    WriteLn('  ✓ Wrong password detection');
    WriteLn;
    WriteLn('================================================================================');
  end
  else
  begin
    WriteLn;
    WriteLn(Format('Result: %d TEST(S) FAILED [FAIL]', [TestsFailed]));
    WriteLn;
    WriteLn('================================================================================');
    Halt(1);
  end;

  // Cleanup
  UnloadPKCS12Module;
  UnloadStackFunctions;
  UnloadOpenSSLERR;
  UnloadOpenSSLPEM;
  UnloadOpenSSLASN1;
  UnloadOpenSSLBN;
  UnloadOpenSSLRSA;
  UnloadOpenSSLX509;
  UnloadEVP;
  UnloadOpenSSLBIO;
  UnloadOpenSSLCore;
end;

begin
  try
    RunAllTests;
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('FATAL ERROR: ', E.Message);
      Halt(1);
    end;
  end;
end.
