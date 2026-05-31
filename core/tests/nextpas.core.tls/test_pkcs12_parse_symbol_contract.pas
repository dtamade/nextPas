program test_pkcs12_parse_symbol_contract;

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

function PrepareValidPKCS12File(const AFileName: string; out AKey: PEVP_PKEY; out ACert: PX509): Boolean;
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
  if (ACert = nil) or (AKey = nil) then
    Exit;

  Result := SavePKCS12ToFile(AFileName, 'testpass', AKey, ACert, nil);
end;

procedure TestLoadPKCS12FromFileShouldDegradeWhenParseIsUnavailable;
var
  LOriginalPKCS12Parse: TPKCS12_parse;
  LTempFile: string;
  LFixtureKey: PEVP_PKEY;
  LFixtureCert: PX509;
  LLoadRaised: Boolean;
  LLoadDetail: string;
  LLoadResult: Boolean;
  LKey: PEVP_PKEY;
  LCert: PX509;
  LCAs: PSTACK_OF_X509;
begin
  WriteLn;
  WriteLn('=== PKCS12 parse symbol guard ===');

  LTempFile := GetTempDir(False) + 'fafafa_pkcs12_parse_symbol_contract.p12';
  LFixtureKey := nil;
  LFixtureCert := nil;
  if not PrepareValidPKCS12File(LTempFile, LFixtureKey, LFixtureCert) then
  begin
    FreeFixtureHandles(LFixtureKey, LFixtureCert);
    MarkSkip('pkcs12 parse symbol contract', 'failed to prepare valid PKCS12 fixture');
    Exit;
  end;

  LOriginalPKCS12Parse := PKCS12_parse;
  LLoadRaised := False;
  LLoadDetail := '';
  LLoadResult := False;
  LKey := nil;
  LCert := nil;
  LCAs := nil;

  PKCS12_parse := nil;
  try
    try
      LLoadResult := LoadPKCS12FromFile(LTempFile, 'testpass', LKey, LCert, LCAs);
    except
      on E: Exception do
      begin
        LLoadRaised := True;
        LLoadDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    PKCS12_parse := LOriginalPKCS12Parse;
    if FileExists(LTempFile) then
      DeleteFile(LTempFile);
    FreeFixtureHandles(LFixtureKey, LFixtureCert);
    if (LKey <> nil) and Assigned(EVP_PKEY_free) then
      EVP_PKEY_free(LKey);
    if (LCert <> nil) and Assigned(X509_free) then
      X509_free(LCert);
  end;

  AssertTrue(
    'LoadPKCS12FromFile should not raise when PKCS12_parse is unavailable',
    not LLoadRaised,
    LLoadDetail
  );
  AssertTrue(
    'LoadPKCS12FromFile should return False when PKCS12_parse is unavailable',
    not LLoadResult,
    'expected False PKCS12 load result when PKCS12_parse is unavailable'
  );
  AssertTrue(
    'LoadPKCS12FromFile should keep outputs nil when PKCS12_parse is unavailable',
    (LKey = nil) and (LCert = nil) and (LCAs = nil),
    'expected nil key/cert/CA outputs when PKCS12_parse is unavailable'
  );
end;

begin
  WriteLn('========================================');
  WriteLn('PKCS12 Parse Symbol Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('pkcs12 parse symbol contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLBIO;
      LoadOpenSSLX509;
      LoadEVP(GetCryptoLibHandle);
      if not Assigned(BIO_new_file) or
         not Assigned(BIO_free) then
      begin
        MarkSkip('pkcs12 parse symbol contract', 'BIO file helpers unavailable on this runtime');
      end
      else if not LoadOpenSSLPEM(GetCryptoLibHandle) then
      begin
        MarkSkip('pkcs12 parse symbol contract', 'PEM module unavailable on this runtime');
      end
      else if not LoadOpenSSLPKCS(GetCryptoLibHandle) then
      begin
        MarkSkip('pkcs12 parse symbol contract', 'PKCS module unavailable on this runtime');
      end
      else if not Assigned(PKCS12_parse) or
              not Assigned(PKCS12_create) or
              not Assigned(i2d_PKCS12_bio) then
      begin
        MarkSkip('pkcs12 parse symbol contract', 'PKCS12 helpers unavailable on this runtime');
      end
      else
        TestLoadPKCS12FromFileShouldDegradeWhenParseIsUnavailable;
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
