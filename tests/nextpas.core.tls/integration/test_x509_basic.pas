program test_x509_basic;

{******************************************************************************}
{  X.509 Basic Integration Tests                                               }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils, ctypes, DynLibs,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.crypto,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.rsa,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.asn1,
  nextpas.core.tls.openssl.loader,
  test_openssl_base;

var
  Runner: TSimpleTestRunner;

function CreateTestKey: PEVP_PKEY;
var
  rsa: PRSA;
  exp: PBIGNUM;
  pkey: PEVP_PKEY;
begin
  Result := nil;
  rsa := RSA_new();
  if rsa = nil then Exit;

  exp := BN_new();
  if exp = nil then
  begin
    RSA_free(rsa);
    Exit;
  end;

  try
    if BN_set_word(exp, RSA_F4) = 1 then
    begin
      if RSA_generate_key_ex(rsa, 2048, exp, nil) = 1 then
      begin
        pkey := EVP_PKEY_new();
        if pkey <> nil then
        begin
          if EVP_PKEY_assign(pkey, EVP_PKEY_RSA, rsa) = 1 then
            Result := pkey
          else
            EVP_PKEY_free(pkey);
        end;
      end;
    end;
  finally
    BN_free(exp);
    if Result = nil then
      RSA_free(rsa);
  end;
end;

procedure TestX509Creation;
var
  cert: PX509;
begin
  WriteLn;
  WriteLn('=== X.509 Certificate Creation Tests ===');

  cert := X509_new();
  Runner.Check('Create X.509 certificate', cert <> nil);

  if cert <> nil then
  begin
    Runner.Check('Set certificate version', X509_set_version(cert, 2) = 1,
            'Version 3 (value=2)');
    X509_free(cert);
  end;
end;

procedure TestX509Names;
var
  name: PX509_NAME;
  entry: PX509_NAME_ENTRY;
  entry_count: Integer;
  text: array[0..255] of AnsiChar;
  text_len: Integer;
begin
  WriteLn;
  WriteLn('=== X.509 Name Tests ===');

  name := X509_NAME_new();
  Runner.Check('Create X.509_NAME', name <> nil);

  if name <> nil then
  begin
    Runner.Check('Add Country Name (C)',
            X509_NAME_add_entry_by_txt(name, 'C', MBSTRING_ASC,
                                       PByte(PAnsiChar('US')), 2, -1, 0) = 1);

    Runner.Check('Add Organization (O)',
            X509_NAME_add_entry_by_txt(name, 'O', MBSTRING_ASC,
                                       PByte(PAnsiChar('Test Org')), 8, -1, 0) = 1);

    Runner.Check('Add Common Name (CN)',
            X509_NAME_add_entry_by_txt(name, 'CN', MBSTRING_ASC,
                                       PByte(PAnsiChar('test.example.com')), 16, -1, 0) = 1);

    entry_count := X509_NAME_entry_count(name);
    Runner.Check('Verify entry count', entry_count = 3,
            Format('Expected 3, got %d', [entry_count]));

    entry := X509_NAME_get_entry(name, 2);
    Runner.Check('Get entry by index', entry <> nil, 'Retrieved CN entry');

    text_len := X509_NAME_get_text_by_NID(name, NID_commonName, @text[0], 256);
    Runner.Check('Get CN text by NID', text_len > 0,
            Format('CN text length: %d', [text_len]));

    X509_NAME_free(name);
  end;
end;

procedure TestX509BasicFields;
var
  cert: PX509;
  pkey: PEVP_PKEY;
  name: PX509_NAME;
  serial: PASN1_INTEGER;
  notBefore, notAfter: PASN1_TIME;
  retrieved_name: PX509_NAME;
  oneline: PAnsiChar;
  version: clong;
begin
  WriteLn;
  WriteLn('=== X.509 Basic Fields Tests ===');

  cert := X509_new();
  if cert = nil then
  begin
    Runner.Check('Create certificate for field tests', False);
    Exit;
  end;

  try
    serial := ASN1_INTEGER_new();
    if serial <> nil then
    begin
      ASN1_INTEGER_set(serial, 12345);
      Runner.Check('Set serial number', X509_set_serialNumber(cert, serial) = 1);
      ASN1_INTEGER_free(serial);
    end;

    serial := X509_get_serialNumber(cert);
    Runner.Check('Get serial number',
            (serial <> nil) and (ASN1_INTEGER_get(serial) = 12345),
            Format('Serial: %d', [ASN1_INTEGER_get(serial)]));

    name := X509_NAME_new();
    if name <> nil then
    begin
      X509_NAME_add_entry_by_txt(name, 'CN', MBSTRING_ASC,
                                 PByte(PAnsiChar('Test Subject')), 12, -1, 0);
      Runner.Check('Set subject name', X509_set_subject_name(cert, name) = 1);
      X509_NAME_free(name);
    end;

    name := X509_NAME_new();
    if name <> nil then
    begin
      X509_NAME_add_entry_by_txt(name, 'CN', MBSTRING_ASC,
                                 PByte(PAnsiChar('Test Issuer')), 11, -1, 0);
      Runner.Check('Set issuer name', X509_set_issuer_name(cert, name) = 1);
      X509_NAME_free(name);
    end;

    retrieved_name := X509_get_subject_name(cert);
    Runner.Check('Get subject name', retrieved_name <> nil);
    if retrieved_name <> nil then
    begin
      oneline := X509_NAME_oneline(retrieved_name, nil, 0);
      if oneline <> nil then
      begin
        WriteLn('  Subject: ', oneline);
        CRYPTO_free(oneline, nil, 0);
      end;
    end;

    retrieved_name := X509_get_issuer_name(cert);
    Runner.Check('Get issuer name', retrieved_name <> nil);
    if retrieved_name <> nil then
    begin
      oneline := X509_NAME_oneline(retrieved_name, nil, 0);
      if oneline <> nil then
      begin
        WriteLn('  Issuer: ', oneline);
        CRYPTO_free(oneline, nil, 0);
      end;
    end;

    notBefore := ASN1_TIME_new();
    notAfter := ASN1_TIME_new();
    if (notBefore <> nil) and (notAfter <> nil) then
    begin
      X509_gmtime_adj(notBefore, 0);
      X509_gmtime_adj(notAfter, 365 * 24 * 3600);
      Runner.Check('Set validity period',
              (X509_set1_notBefore(cert, notBefore) = 1) and
              (X509_set1_notAfter(cert, notAfter) = 1),
              'Valid for 1 year from now');
      ASN1_TIME_free(notBefore);
      ASN1_TIME_free(notAfter);
    end;

    pkey := CreateTestKey();
    if pkey <> nil then
    begin
      Runner.Check('Set public key', X509_set_pubkey(cert, pkey) = 1);
      EVP_PKEY_free(pkey);
    end
    else
      Runner.Check('Create test key', False);

    version := X509_get_version(cert);
    Runner.Check('Get certificate version', version = 2,
            Format('Version: %d (X.509 v3)', [version]));

  finally
    X509_free(cert);
  end;
end;

procedure TestX509SelfSignedCert;
var
  cert: PX509;
  pkey: PEVP_PKEY;
  name: PX509_NAME;
  serial: PASN1_INTEGER;
  notBefore, notAfter: PASN1_TIME;
  md: PEVP_MD;
  verify_result: Integer;
begin
  WriteLn;
  WriteLn('=== X.509 Self-Signed Certificate Tests ===');

  pkey := CreateTestKey();
  if pkey = nil then
  begin
    Runner.Check('Create key pair for self-signed cert', False);
    Exit;
  end;

  cert := X509_new();
  if cert = nil then
  begin
    EVP_PKEY_free(pkey);
    Runner.Check('Create certificate for self-signed test', False);
    Exit;
  end;

  try
    X509_set_version(cert, 2);

    serial := ASN1_INTEGER_new();
    ASN1_INTEGER_set(serial, 1);
    X509_set_serialNumber(cert, serial);
    ASN1_INTEGER_free(serial);

    name := X509_NAME_new();
    X509_NAME_add_entry_by_txt(name, 'C', MBSTRING_ASC, PByte(PAnsiChar('US')), 2, -1, 0);
    X509_NAME_add_entry_by_txt(name, 'O', MBSTRING_ASC, PByte(PAnsiChar('Test')), 4, -1, 0);
    X509_NAME_add_entry_by_txt(name, 'CN', MBSTRING_ASC,
                               PByte(PAnsiChar('test.example.com')), 16, -1, 0);

    X509_set_issuer_name(cert, name);
    X509_set_subject_name(cert, name);
    X509_NAME_free(name);

    notBefore := ASN1_TIME_new();
    notAfter := ASN1_TIME_new();
    X509_gmtime_adj(notBefore, 0);
    X509_gmtime_adj(notAfter, 365 * 24 * 3600);
    X509_set1_notBefore(cert, notBefore);
    X509_set1_notAfter(cert, notAfter);
    ASN1_TIME_free(notBefore);
    ASN1_TIME_free(notAfter);

    X509_set_pubkey(cert, pkey);

    md := EVP_sha256();
    Runner.Check('Sign certificate with SHA-256',
            X509_sign(cert, pkey, md) > 0,
            'Self-signed certificate created');

    verify_result := X509_verify(cert, pkey);
    Runner.Check('Verify self-signed certificate', verify_result = 1,
            Format('Verification result: %d', [verify_result]));

    Runner.Check('Check private key matches certificate',
            X509_check_private_key(cert, pkey) = 1,
            'Private key and certificate match');

  finally
    X509_free(cert);
    EVP_PKEY_free(pkey);
  end;
end;

begin
  WriteLn('X.509 Certificate Basic Tests');
  WriteLn('==============================');
  WriteLn;

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore, osmBN, osmRSA, osmEVP, osmX509]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    // Load required modules
    LoadOpenSSLX509;
    LoadOpenSSLASN1(GetCryptoLibHandle);
    LoadEVP(GetCryptoLibHandle);
    LoadOpenSSLRSA;
    LoadOpenSSLBN;
    LoadOpenSSLCrypto;

    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);

    TestX509Creation;
    TestX509Names;
    TestX509BasicFields;
    TestX509SelfSignedCert;

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
