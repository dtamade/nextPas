program test_cert_utils_ed25519_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.cert.utils;

var
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;

procedure AssertTrue(const AName: string; ACondition: Boolean; const ADetail: string = '');
begin
  Inc(TotalTests);
  if ACondition then
  begin
    Inc(PassedTests);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(FailedTests);
    WriteLn('[FAIL] ', AName);
    if ADetail <> '' then
      WriteLn('       ', ADetail);
  end;
end;

procedure MarkSkip(const AName, AReason: string);
begin
  Inc(TotalTests);
  Inc(SkippedTests);
  WriteLn('[SKIP] [capability] ', AName, ' - ', AReason);
end;

function HasEd25519KeygenCapability: Boolean;
begin
  Result := Assigned(EVP_PKEY_CTX_new_id) and
            Assigned(EVP_PKEY_keygen_init) and
            Assigned(EVP_PKEY_keygen);
end;

procedure TestEd25519SelfSignedContract;
var
  LOptions: TCertGenOptions;
  LCertPEM: string;
  LKeyPEM: string;
  LInfo: TCertInfo;
  LKeyType: string;
  LGenerated: Boolean;
begin
  WriteLn;
  WriteLn('=== Test Ed25519 Self-Signed Contract ===');

  LOptions := TCertificateUtils.DefaultGenOptions;
  LOptions.KeyType := ktEd25519;
  LOptions.CommonName := 'ed25519-selfsigned.example.local';

  LGenerated := False;
  try
    LGenerated := TCertificateUtils.GenerateSelfSigned(LOptions, LCertPEM, LKeyPEM);
    AssertTrue('GenerateSelfSigned(Ed25519) should succeed', LGenerated);
  except
    on E: Exception do
    begin
      AssertTrue('GenerateSelfSigned(Ed25519) should succeed', False,
        E.ClassName + ': ' + E.Message);
      Exit;
    end;
  end;

  AssertTrue('Certificate PEM should contain BEGIN CERTIFICATE',
    Pos('BEGIN CERTIFICATE', LCertPEM) > 0);
  AssertTrue('Private key PEM should contain BEGIN PRIVATE KEY',
    Pos('BEGIN PRIVATE KEY', LKeyPEM) > 0);

  try
    LInfo := TCertificateUtils.GetInfo(LCertPEM);
    try
      LKeyType := LowerCase(LInfo.PublicKeyType);
      AssertTrue('Public key type should contain 25519',
        Pos('25519', LKeyType) > 0,
        'Actual key type: ' + LInfo.PublicKeyType);
      AssertTrue('Serial number should be populated',
        LInfo.SerialNumber <> '',
        'SerialNumber is empty');
      AssertTrue('Signature algorithm should be populated',
        LInfo.SignatureAlgorithm <> '',
        'SignatureAlgorithm is empty');
      AssertTrue('Key usage should be populated',
        LInfo.KeyUsage <> '',
        'KeyUsage is empty');
      AssertTrue('Key usage should include digitalSignature',
        Pos('digitalsignature', LowerCase(LInfo.KeyUsage)) > 0,
        'KeyUsage=' + LInfo.KeyUsage);
      AssertTrue('Self-signed Ed25519 cert should not be CA',
        not LInfo.IsCA,
        'IsCA=' + BoolToStr(LInfo.IsCA, True));
      AssertTrue('Public key bits should be > 0',
        LInfo.PublicKeyBits > 0,
        'PublicKeyBits=' + IntToStr(LInfo.PublicKeyBits));
    finally
      if Assigned(LInfo.SubjectAltNames) then
        LInfo.SubjectAltNames.Free;
    end;
  except
    on E: Exception do
      AssertTrue('GetInfo should parse Ed25519 certificate', False,
        E.ClassName + ': ' + E.Message);
  end;
end;

procedure TestEd25519CASignedLeafContract;
var
  LCAOptions: TCertGenOptions;
  LLeafOptions: TCertGenOptions;
  LCACertPEM, LCAKeyPEM: string;
  LLeafCertPEM, LLeafKeyPEM: string;
  LInfo, LCAInfo: TCertInfo;
  LKeyType: string;
  LGenerated: Boolean;
begin
  WriteLn;
  WriteLn('=== Test RSA-CA signed Ed25519 leaf Contract ===');

  LCAOptions := TCertificateUtils.DefaultGenOptions;
  LCAOptions.KeyType := ktRSA;
  LCAOptions.IsCA := True;
  LCAOptions.CommonName := 'ed25519-ca.example.local';

  try
    AssertTrue('GenerateSelfSigned(RSA CA) should succeed',
      TCertificateUtils.GenerateSelfSigned(LCAOptions, LCACertPEM, LCAKeyPEM));
  except
    on E: Exception do
    begin
      AssertTrue('GenerateSelfSigned(RSA CA) should succeed', False,
        E.ClassName + ': ' + E.Message);
      Exit;
    end;
  end;

  try
    LCAInfo := TCertificateUtils.GetInfo(LCACertPEM);
    try
      AssertTrue('CA cert should be marked IsCA',
        LCAInfo.IsCA,
        'IsCA=' + BoolToStr(LCAInfo.IsCA, True));
      AssertTrue('CA key usage should include keyCertSign',
        Pos('keycertsign', LowerCase(LCAInfo.KeyUsage)) > 0,
        'CA KeyUsage=' + LCAInfo.KeyUsage);
    finally
      if Assigned(LCAInfo.SubjectAltNames) then
        LCAInfo.SubjectAltNames.Free;
    end;
  except
    on E: Exception do
      AssertTrue('GetInfo should parse CA certificate metadata', False,
        E.ClassName + ': ' + E.Message);
  end;

  LLeafOptions := TCertificateUtils.DefaultGenOptions;
  LLeafOptions.KeyType := ktEd25519;
  LLeafOptions.IsCA := False;
  LLeafOptions.CommonName := 'ed25519-leaf.example.local';

  LGenerated := False;
  try
    LGenerated := TCertificateUtils.GenerateSigned(
      LLeafOptions,
      LCACertPEM,
      LCAKeyPEM,
      LLeafCertPEM,
      LLeafKeyPEM
    );
    AssertTrue('GenerateSigned(Ed25519 leaf) should succeed', LGenerated);
  except
    on E: Exception do
    begin
      AssertTrue('GenerateSigned(Ed25519 leaf) should succeed', False,
        E.ClassName + ': ' + E.Message);
      Exit;
    end;
  end;

  AssertTrue('Leaf certificate PEM should contain BEGIN CERTIFICATE',
    Pos('BEGIN CERTIFICATE', LLeafCertPEM) > 0);
  AssertTrue('Leaf private key PEM should contain BEGIN PRIVATE KEY',
    Pos('BEGIN PRIVATE KEY', LLeafKeyPEM) > 0);

  try
    LInfo := TCertificateUtils.GetInfo(LLeafCertPEM);
    try
      LKeyType := LowerCase(LInfo.PublicKeyType);
      AssertTrue('Leaf key type should contain 25519',
        Pos('25519', LKeyType) > 0,
        'Actual key type: ' + LInfo.PublicKeyType);
      AssertTrue('Leaf serial number should be populated',
        LInfo.SerialNumber <> '',
        'SerialNumber is empty');
      AssertTrue('Leaf signature algorithm should be populated',
        LInfo.SignatureAlgorithm <> '',
        'SignatureAlgorithm is empty');
      AssertTrue('Leaf key usage should be populated',
        LInfo.KeyUsage <> '',
        'KeyUsage is empty');
      AssertTrue('Leaf key usage should include digitalSignature',
        Pos('digitalsignature', LowerCase(LInfo.KeyUsage)) > 0,
        'KeyUsage=' + LInfo.KeyUsage);
      AssertTrue('Leaf cert should not be marked IsCA',
        not LInfo.IsCA,
        'IsCA=' + BoolToStr(LInfo.IsCA, True));
      AssertTrue('Leaf public key bits should be > 0',
        LInfo.PublicKeyBits > 0,
        'PublicKeyBits=' + IntToStr(LInfo.PublicKeyBits));
    finally
      if Assigned(LInfo.SubjectAltNames) then
        LInfo.SubjectAltNames.Free;
    end;
  except
    on E: Exception do
      AssertTrue('GetInfo should parse Ed25519 leaf certificate', False,
        E.ClassName + ': ' + E.Message);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Cert Utils Ed25519 Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    AssertTrue('OpenSSL core loaded', TOpenSSLLoader.IsModuleLoaded(osmCore), 'OpenSSL core not loaded');

    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('Ed25519 certificate contracts', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadEVP(GetCryptoLibHandle);
      if not HasEd25519KeygenCapability then
      begin
        MarkSkip('Ed25519 certificate contracts',
          'EVP_PKEY Ed25519 keygen symbols unavailable');
      end
      else
      begin
        TestEd25519SelfSignedContract;
        TestEd25519CASignedLeafContract;
      end;
    end;

    WriteLn;
    WriteLn('========================================');
    WriteLn('Summary');
    WriteLn('========================================');
    WriteLn('Total tests: ', TotalTests);
    WriteLn('Passed: ', PassedTests);
    WriteLn('Failed: ', FailedTests);
    WriteLn('Skipped: ', SkippedTests);

    if FailedTests > 0 then
      Halt(1);
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ', E.ClassName, ': ', E.Message);
      Halt(2);
    end;
  end;
end.
