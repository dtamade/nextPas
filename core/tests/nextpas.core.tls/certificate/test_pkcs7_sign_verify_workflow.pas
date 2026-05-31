program test_pkcs7_sign_verify_workflow;

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
  nextpas.core.tls.openssl.api.pkcs7,
  nextpas.core.tls.openssl.api.consts;

const
  TEST_DATA = 'This is test data for PKCS7 signing and verification workflow.';

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

// Helper function for BIO_reset (it's a macro in C)
function BIO_reset(b: PBIO): clong;
begin
  if Assigned(BIO_ctrl) then
    Result := BIO_ctrl(b, BIO_CTRL_RESET, 0, nil)
  else
    Result := -1;
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

// Test 1: Complete sign and verify workflow
procedure Test_01_SignAndVerify_Workflow;
const
  TEST_NAME = 'PKCS7 sign and verify complete workflow';
var
  bio_in: PBIO;
  bio_out: PBIO;
  p7: PPKCS7;
  verify_result: Integer;
begin
  if (TestCert = nil) or (TestPrivKey = nil) then
  begin
    Fail(TEST_NAME, 'Test cert/key not available');
    Exit;
  end;

  // Create input BIO with test data
  bio_in := BIO_new_mem_buf(PAnsiChar(TEST_DATA), Length(TEST_DATA));
  if bio_in = nil then
  begin
    Fail(TEST_NAME, 'Failed to create input BIO');
    Exit;
  end;

  try
    // Sign the data
    p7 := PKCS7_sign(TestCert, TestPrivKey, nil, bio_in, PKCS7_DETACHED or PKCS7_BINARY);

    if p7 = nil then
    begin
      Fail(TEST_NAME, 'PKCS7_sign failed');
      Exit;
    end;

    try
      WriteLn('[INFO] PKCS7 signature created successfully');

      // Reset input BIO for verification
      BIO_reset(bio_in);

      // Create output BIO for verification
      bio_out := BIO_new(BIO_s_mem());
      if bio_out = nil then
      begin
        Fail(TEST_NAME, 'Failed to create output BIO');
        Exit;
      end;

      try
        // Verify the signature (use PKCS7_NOVERIFY to skip certificate validation)
        verify_result := PKCS7_verify(p7, nil, nil, bio_in, bio_out, PKCS7_DETACHED or PKCS7_BINARY or PKCS7_NOVERIFY);

        if verify_result = 1 then
        begin
          WriteLn('[INFO] PKCS7 signature verified successfully');
          Pass(TEST_NAME);
        end
        else
        begin
          Fail(TEST_NAME, 'PKCS7_verify failed');
        end;
      finally
        BIO_free(bio_out);
      end;
    finally
      PKCS7_free(p7);
    end;
  finally
    BIO_free(bio_in);
  end;
end;

// Test 2: Sign with different flags
procedure Test_02_SignWithDifferentFlags;
const
  TEST_NAME = 'PKCS7 sign with different flags';
var
  bio_in: PBIO;
  p7_detached: PPKCS7;
  p7_attached: PPKCS7;
begin
  if (TestCert = nil) or (TestPrivKey = nil) then
  begin
    Fail(TEST_NAME, 'Test cert/key not available');
    Exit;
  end;

  // Test detached signature
  bio_in := BIO_new_mem_buf(PAnsiChar(TEST_DATA), Length(TEST_DATA));
  if bio_in = nil then
  begin
    Fail(TEST_NAME, 'Failed to create input BIO');
    Exit;
  end;

  try
    p7_detached := PKCS7_sign(TestCert, TestPrivKey, nil, bio_in, PKCS7_DETACHED or PKCS7_BINARY);
    if p7_detached = nil then
    begin
      Fail(TEST_NAME, 'Detached signature failed');
      Exit;
    end;
    PKCS7_free(p7_detached);
    WriteLn('[INFO] Detached signature created');

    // Test attached signature (no PKCS7_DETACHED flag)
    BIO_reset(bio_in);
    p7_attached := PKCS7_sign(TestCert, TestPrivKey, nil, bio_in, PKCS7_BINARY);
    if p7_attached = nil then
    begin
      Fail(TEST_NAME, 'Attached signature failed');
      Exit;
    end;
    PKCS7_free(p7_attached);
    WriteLn('[INFO] Attached signature created');

    Pass(TEST_NAME);
  finally
    BIO_free(bio_in);
  end;
end;

// Test 3: Verify with certificate store
procedure Test_03_VerifyWithCertStore;
const
  TEST_NAME = 'PKCS7 verify with certificate store';
var
  bio_in: PBIO;
  bio_out: PBIO;
  p7: PPKCS7;
  store: PX509_STORE;
  verify_result: Integer;
begin
  if (TestCert = nil) or (TestPrivKey = nil) then
  begin
    Fail(TEST_NAME, 'Test cert/key not available');
    Exit;
  end;

  // Create certificate store
  store := X509_STORE_new();
  if store = nil then
  begin
    Fail(TEST_NAME, 'Failed to create certificate store');
    Exit;
  end;

  try
    // Add test certificate to store
    if X509_STORE_add_cert(store, TestCert) <> 1 then
    begin
      Fail(TEST_NAME, 'Failed to add certificate to store');
      Exit;
    end;

    // Create and sign data
    bio_in := BIO_new_mem_buf(PAnsiChar(TEST_DATA), Length(TEST_DATA));
    if bio_in = nil then
    begin
      Fail(TEST_NAME, 'Failed to create input BIO');
      Exit;
    end;

    try
      p7 := PKCS7_sign(TestCert, TestPrivKey, nil, bio_in, PKCS7_DETACHED or PKCS7_BINARY);
      if p7 = nil then
      begin
        Fail(TEST_NAME, 'PKCS7_sign failed');
        Exit;
      end;

      try
        BIO_reset(bio_in);
        bio_out := BIO_new(BIO_s_mem());
        if bio_out = nil then
        begin
          Fail(TEST_NAME, 'Failed to create output BIO');
          Exit;
        end;

        try
          // Verify with certificate store
          verify_result := PKCS7_verify(p7, nil, store, bio_in, bio_out, PKCS7_DETACHED or PKCS7_BINARY);

          if verify_result = 1 then
          begin
            WriteLn('[INFO] Verification with certificate store succeeded');
            Pass(TEST_NAME);
          end
          else
          begin
            Fail(TEST_NAME, 'Verification with certificate store failed');
          end;
        finally
          BIO_free(bio_out);
        end;
      finally
        PKCS7_free(p7);
      end;
    finally
      BIO_free(bio_in);
    end;
  finally
    X509_STORE_free(store);
  end;
end;

// Test 4: Tampered data detection
procedure Test_04_TamperedDataDetection;
const
  TEST_NAME = 'PKCS7 tampered data detection';
  TAMPERED_DATA = 'This is TAMPERED data for PKCS7 signing and verification workflow.';
var
  bio_in: PBIO;
  bio_tampered: PBIO;
  bio_out: PBIO;
  p7: PPKCS7;
  verify_result: Integer;
begin
  if (TestCert = nil) or (TestPrivKey = nil) then
  begin
    Fail(TEST_NAME, 'Test cert/key not available');
    Exit;
  end;

  // Create and sign original data
  bio_in := BIO_new_mem_buf(PAnsiChar(TEST_DATA), Length(TEST_DATA));
  if bio_in = nil then
  begin
    Fail(TEST_NAME, 'Failed to create input BIO');
    Exit;
  end;

  try
    p7 := PKCS7_sign(TestCert, TestPrivKey, nil, bio_in, PKCS7_DETACHED or PKCS7_BINARY);
    if p7 = nil then
    begin
      Fail(TEST_NAME, 'PKCS7_sign failed');
      Exit;
    end;

    try
      // Try to verify with tampered data
      bio_tampered := BIO_new_mem_buf(PAnsiChar(TAMPERED_DATA), Length(TAMPERED_DATA));
      if bio_tampered = nil then
      begin
        Fail(TEST_NAME, 'Failed to create tampered BIO');
        Exit;
      end;

      try
        bio_out := BIO_new(BIO_s_mem());
        if bio_out = nil then
        begin
          Fail(TEST_NAME, 'Failed to create output BIO');
          Exit;
        end;

        try
          // Verification should fail with tampered data
          verify_result := PKCS7_verify(p7, nil, nil, bio_tampered, bio_out, PKCS7_DETACHED or PKCS7_BINARY);

          if verify_result <> 1 then
          begin
            WriteLn('[INFO] Tampered data correctly detected (verification failed as expected)');
            Pass(TEST_NAME);
          end
          else
          begin
            Fail(TEST_NAME, 'Tampered data not detected (verification should have failed)');
          end;
        finally
          BIO_free(bio_out);
        end;
      finally
        BIO_free(bio_tampered);
      end;
    finally
      PKCS7_free(p7);
    end;
  finally
    BIO_free(bio_in);
  end;
end;

procedure RunAllTests;
begin
  WriteLn('================================================================================');
  WriteLn('           PKCS7 Digital Signature Workflow Comprehensive Test');
  WriteLn('================================================================================');
  WriteLn;
  WriteLn('Purpose: Validate complete PKCS7 sign and verify workflow');
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

  if not LoadPKCS7Functions then
  begin
    WriteLn('ERROR: Failed to load PKCS7 functions');
    Halt(1);
  end;

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
      TestSection('Test 1: Complete Sign and Verify Workflow');
      Test_01_SignAndVerify_Workflow;

      TestSection('Test 2: Sign with Different Flags');
      Test_02_SignWithDifferentFlags;

      TestSection('Test 3: Verify with Certificate Store');
      Test_03_VerifyWithCertStore;

      TestSection('Test 4: Tampered Data Detection');
      Test_04_TamperedDataDetection;
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
    WriteLn('PKCS7 digital signature workflow is fully functional:');
    WriteLn('  ✓ Sign and verify workflow');
    WriteLn('  ✓ Different signature flags (detached/attached)');
    WriteLn('  ✓ Certificate store verification');
    WriteLn('  ✓ Tampered data detection');
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
  UnloadPKCS7Functions;
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
