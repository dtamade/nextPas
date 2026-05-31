program test_pkcs12_i2d_symbol_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.pkcs,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.evp;

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

procedure FreeFixtureHandles(var AKey: PEVP_PKEY; var ACert: PX509);
begin
  if (AKey <> nil) and Assigned(EVP_PKEY_free) then
    EVP_PKEY_free(AKey);
  if (ACert <> nil) and Assigned(X509_free) then
    X509_free(ACert);
  AKey := nil;
  ACert := nil;
end;

function PrepareFixtureHandles(out AKey: PEVP_PKEY; out ACert: PX509): Boolean;
const
  CertFixture = 'tests/certificate/test_certs/signer_cert.pem';
  KeyFixture = 'tests/certificate/test_certs/signer_key.pem';
begin
  Result := False;
  AKey := nil;
  ACert := nil;

  if not FileExists(CertFixture) or not FileExists(KeyFixture) then
    Exit;

  ACert := LoadCertificateFromPEM(CertFixture);
  AKey := LoadPrivateKeyFromPEM(KeyFixture, '');
  Result := (ACert <> nil) and (AKey <> nil);
end;

procedure TestSavePKCS12ToFileShouldDegradeWhenI2DIsUnavailable;
var
  LOriginalI2DPKCS12Bio: Ti2d_PKCS12_bio;
  LFixtureKey: PEVP_PKEY;
  LFixtureCert: PX509;
  LOutputFile: string;
  LSaveRaised: Boolean;
  LSaveDetail: string;
  LSaveResult: Boolean;
begin
  WriteLn;
  WriteLn('=== PKCS12 i2d symbol guard ===');

  LFixtureKey := nil;
  LFixtureCert := nil;
  if not PrepareFixtureHandles(LFixtureKey, LFixtureCert) then
  begin
    FreeFixtureHandles(LFixtureKey, LFixtureCert);
    MarkSkip('pkcs12 i2d symbol contract', 'failed to load certificate/private-key fixtures');
    Exit;
  end;

  LOriginalI2DPKCS12Bio := i2d_PKCS12_bio;
  LOutputFile := GetTempDir(False) + 'fafafa_pkcs12_i2d_symbol_contract.p12';
  if FileExists(LOutputFile) then
    DeleteFile(LOutputFile);

  LSaveRaised := False;
  LSaveDetail := '';
  LSaveResult := False;

  i2d_PKCS12_bio := nil;
  try
    try
      LSaveResult := SavePKCS12ToFile(LOutputFile, 'testpass', LFixtureKey, LFixtureCert, nil);
    except
      on E: Exception do
      begin
        LSaveRaised := True;
        LSaveDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    i2d_PKCS12_bio := LOriginalI2DPKCS12Bio;
    if FileExists(LOutputFile) then
      DeleteFile(LOutputFile);
    FreeFixtureHandles(LFixtureKey, LFixtureCert);
  end;

  AssertTrue(
    'SavePKCS12ToFile should not raise when i2d_PKCS12_bio is unavailable',
    not LSaveRaised,
    LSaveDetail
  );
  AssertTrue(
    'SavePKCS12ToFile should return False when i2d_PKCS12_bio is unavailable',
    not LSaveResult,
    'expected False PKCS12 save result when i2d_PKCS12_bio is unavailable'
  );
end;

begin
  WriteLn('========================================');
  WriteLn('PKCS12 i2d Symbol Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('pkcs12 i2d symbol contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLBIO;
      LoadOpenSSLX509;
      LoadEVP(GetCryptoLibHandle);
      if not Assigned(BIO_new_file) or
         not Assigned(BIO_free) then
      begin
        MarkSkip('pkcs12 i2d symbol contract', 'BIO file helpers unavailable on this runtime');
      end
      else if not LoadOpenSSLPEM(GetCryptoLibHandle) then
      begin
        MarkSkip('pkcs12 i2d symbol contract', 'PEM module unavailable on this runtime');
      end
      else if not LoadOpenSSLPKCS(GetCryptoLibHandle) then
      begin
        MarkSkip('pkcs12 i2d symbol contract', 'PKCS module unavailable on this runtime');
      end
      else if not Assigned(PKCS12_create) or
              not Assigned(i2d_PKCS12_bio) or
              not Assigned(PKCS12_free) then
      begin
        MarkSkip('pkcs12 i2d symbol contract', 'PKCS12 save helpers unavailable on this runtime');
      end
      else
        TestSavePKCS12ToFileShouldDegradeWhenI2DIsUnavailable;
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
