program test_openssl_ed25519_certificate_algorithm_truth;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.backed,
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

procedure TestGeneratedEd25519CertificateAlgorithmTruth;
var
  LOptions: TCertGenOptions;
  LCertPEM: string;
  LKeyPEM: string;
  LLib: ISSLLibrary;
  LCert: ISSLCertificate;
  LInfo: TSSLCertificateInfo;
  LLoaded: Boolean;
begin
  WriteLn;
  WriteLn('=== OpenSSL Ed25519 certificate algorithm truth ===');

  LOptions := TCertificateUtils.DefaultGenOptions;
  LOptions.KeyType := ktEd25519;
  LOptions.CommonName := 'openssl-ed25519-algorithm-truth.local';
  LOptions.Organization := 'fafafa.ssl';

  try
    AssertTrue('GenerateSelfSigned(Ed25519) should succeed',
      TCertificateUtils.GenerateSelfSigned(LOptions, LCertPEM, LKeyPEM));
  except
    on E: Exception do
    begin
      AssertTrue('GenerateSelfSigned(Ed25519) should succeed', False,
        E.ClassName + ': ' + E.Message);
      Exit;
    end;
  end;

  LLib := CreateOpenSSLLibrary;
  AssertTrue('CreateOpenSSLLibrary returns instance', LLib <> nil);
  if LLib = nil then
    Exit;

  AssertTrue('OpenSSL library initializes', LLib.Initialize, LLib.GetLastErrorString);
  if not LLib.IsInitialized then
    Exit;

  LCert := LLib.CreateCertificate;
  AssertTrue('CreateCertificate returns instance', LCert <> nil);
  if LCert = nil then
    Exit;

  LLoaded := LCert.LoadFromPEM(LCertPEM);
  AssertTrue('Generated Ed25519 PEM loads into OpenSSL certificate', LLoaded);
  if not LLoaded then
    Exit;

  AssertTrue('GetPublicKeyAlgorithm exposes Ed25519 truth',
    SameText(LCert.GetPublicKeyAlgorithm, 'Ed25519'),
    'Actual=' + LCert.GetPublicKeyAlgorithm);
  AssertTrue('GetSignatureAlgorithm exposes Ed25519 truth',
    SameText(LCert.GetSignatureAlgorithm, 'Ed25519'),
    'Actual=' + LCert.GetSignatureAlgorithm);

  LInfo := LCert.GetInfo;
  AssertTrue('GetInfo.PublicKeyAlgorithm exposes Ed25519 truth',
    SameText(LInfo.PublicKeyAlgorithm, 'Ed25519'),
    'Actual=' + LInfo.PublicKeyAlgorithm);
  AssertTrue('GetInfo.SignatureAlgorithm exposes Ed25519 truth',
    SameText(LInfo.SignatureAlgorithm, 'Ed25519'),
    'Actual=' + LInfo.SignatureAlgorithm);
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL Ed25519 Certificate Algorithm Truth');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
      MarkSkip('OpenSSL Ed25519 certificate algorithm truth', 'OpenSSL core unavailable')
    else
    begin
      LoadEVP(GetCryptoLibHandle);
      if not HasEd25519KeygenCapability then
        MarkSkip('OpenSSL Ed25519 certificate algorithm truth',
          'EVP_PKEY Ed25519 keygen symbols unavailable')
      else
        TestGeneratedEd25519CertificateAlgorithmTruth;
    end;
  except
    on E: Exception do
      AssertTrue('Test harness should not raise', False,
        E.ClassName + ': ' + E.Message);
  end;

  WriteLn;
  WriteLn('========================================');
  WriteLn('Summary');
  WriteLn('========================================');
  WriteLn('Total Tests: ', TotalTests);
  WriteLn('Passed: ', PassedTests);
  WriteLn('Failed: ', FailedTests);
  WriteLn('Skipped: ', SkippedTests);

  if FailedTests > 0 then
    Halt(1);
end.
