program test_cert_utils_generate_signed_pem_export_bio_new_nil_result_family_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.evp;

const
  CERTIFICATE_EXPORT_BIO_NEW_CALL = 1;
  PRIVATE_KEY_EXPORT_BIO_NEW_CALL = 2;

var
  GLib: ISSLLibrary = nil;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;
  GOriginalBIONew: TBIO_new = nil;
  GBIONewCallCount: Integer = 0;
  GTargetBIONewCall: Integer = 0;

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

function BuildCAOptions: TCertGenOptions;
begin
  Result := TCertificateUtils.DefaultGenOptions;
  Result.CommonName := 'signed-pem-export-bio-new-nil-result-root.local';
  Result.Organization := 'fafafa.ssl contract';
  Result.IsCA := True;
  Result.ValidDays := 30;
end;

function BuildLeafOptions: TCertGenOptions;
begin
  Result := TCertificateUtils.DefaultGenOptions;
  Result.CommonName := 'signed-pem-export-bio-new-nil-result-leaf.local';
  Result.Organization := 'fafafa.ssl contract';
  Result.IsCA := False;
  Result.ValidDays := 30;
end;

procedure WarmupGenerateSignedMaterials(
  out ACACertPEM: string;
  out ACAKeyPEM: string
);
var
  LCAOptions: TCertGenOptions;
  LLeafOptions: TCertGenOptions;
  LLeafCertPEM: string;
  LLeafKeyPEM: string;
begin
  LCAOptions := BuildCAOptions;
  if not TCertificateUtils.GenerateSelfSigned(LCAOptions, ACACertPEM, ACAKeyPEM) then
    raise Exception.Create('GenerateSelfSigned warmup returned False');
  if (ACACertPEM = '') or (ACAKeyPEM = '') then
    raise Exception.Create('GenerateSelfSigned warmup returned empty CA material');

  LLeafOptions := BuildLeafOptions;
  if not TCertificateUtils.GenerateSigned(
    LLeafOptions,
    ACACertPEM,
    ACAKeyPEM,
    LLeafCertPEM,
    LLeafKeyPEM
  ) then
    raise Exception.Create('GenerateSigned warmup returned False');
  if (LLeafCertPEM = '') or (LLeafKeyPEM = '') then
    raise Exception.Create('GenerateSigned warmup returned empty leaf material');
end;

function ReturnNilAtSelectedGenerateSignedPEMExportBIOConstructor(const AType: PBIO_METHOD): PBIO; cdecl;
begin
  Inc(GBIONewCallCount);
  if GBIONewCallCount = GTargetBIONewCall then
    Exit(nil);
  Result := GOriginalBIONew(AType);
end;

procedure InstallBIONewNilResultWrapper(const ATargetCall: Integer);
begin
  GBIONewCallCount := 0;
  GTargetBIONewCall := ATargetCall;
  BIO_new := @ReturnNilAtSelectedGenerateSignedPEMExportBIOConstructor;
end;

procedure AssertGenerateSignedConstructorNilResultFailure(
  const AName: string;
  const AOptions: TCertGenOptions;
  const ACACertPEM, ACAKeyPEM: string;
  const ATargetCall: Integer;
  const AExpectedMessage: string
);
var
  LRaised: Boolean;
  LControlled: Boolean;
  LDetail: string;
  LMessage: string;
  LCertPEM: string;
  LKeyPEM: string;
  LTryRaised: Boolean;
  LTryDetail: string;
  LTryResult: Boolean;
begin
  InstallBIONewNilResultWrapper(ATargetCall);

  LRaised := False;
  LControlled := False;
  LDetail := '';
  LMessage := '';
  LCertPEM := '';
  LKeyPEM := '';
  try
    TCertificateUtils.GenerateSigned(AOptions, ACACertPEM, ACAKeyPEM, LCertPEM, LKeyPEM);
  except
    on E: Exception do
    begin
      LRaised := True;
      LControlled := E is ESSLCertError;
      LMessage := E.Message;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should raise', LRaised,
    'expected GenerateSigned(...) to fail');
  AssertTrue(AName + ' should raise controlled ESSLCertError', LControlled, LDetail);
  AssertTrue(AName + ' should stop at the BIO_new nil-result boundary',
    LMessage = AExpectedMessage,
    'expected "' + AExpectedMessage + '", got "' + LMessage + '"');

  InstallBIONewNilResultWrapper(ATargetCall);

  LTryRaised := False;
  LTryDetail := '';
  LTryResult := True;
  LCertPEM := 'sentinel-cert';
  LKeyPEM := 'sentinel-key';
  try
    LTryResult := TCertificateUtils.TryGenerateSigned(
      AOptions,
      ACACertPEM,
      ACAKeyPEM,
      LCertPEM,
      LKeyPEM
    );
  except
    on E: Exception do
    begin
      LTryRaised := True;
      LTryDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' TryGenerateSigned should not raise', not LTryRaised, LTryDetail);
  AssertTrue(AName + ' TryGenerateSigned should return False', not LTryResult,
    'expected TryGenerateSigned to return False');
  AssertTrue(AName + ' TryGenerateSigned should clear cert output', LCertPEM = '',
    'expected cleared certificate output');
  AssertTrue(AName + ' TryGenerateSigned should clear key output', LKeyPEM = '',
    'expected cleared key output');
end;

procedure TestGenerateSignedShouldStopAtCertificateExportBIONilResult;
var
  LLeafOptions: TCertGenOptions;
  LCACertPEM: string;
  LCAKeyPEM: string;
begin
  WriteLn;
  WriteLn('=== Certificate utils GenerateSigned certificate PEM export BIO_new nil-result guard ===');

  if not Assigned(BIO_new) then
  begin
    MarkSkip('certificate utils generate-signed certificate PEM export BIO_new nil-result contract',
      'required baseline BIO_new helper is unavailable');
    Exit;
  end;

  LLeafOptions := BuildLeafOptions;
  WarmupGenerateSignedMaterials(LCACertPEM, LCAKeyPEM);

  GOriginalBIONew := BIO_new;
  try
    AssertGenerateSignedConstructorNilResultFailure(
      'GenerateSigned when certificate PEM export BIO_new returns nil',
      LLeafOptions,
      LCACertPEM,
      LCAKeyPEM,
      CERTIFICATE_EXPORT_BIO_NEW_CALL,
      'Failed to create BIO for certificate export'
    );
  finally
    BIO_new := GOriginalBIONew;
  end;
end;

procedure TestGenerateSignedShouldStopAtPrivateKeyExportBIONilResult;
var
  LLeafOptions: TCertGenOptions;
  LCACertPEM: string;
  LCAKeyPEM: string;
begin
  WriteLn;
  WriteLn('=== Certificate utils GenerateSigned private-key PEM export BIO_new nil-result guard ===');

  if not Assigned(BIO_new) then
  begin
    MarkSkip('certificate utils generate-signed private-key PEM export BIO_new nil-result contract',
      'required baseline BIO_new helper is unavailable');
    Exit;
  end;

  LLeafOptions := BuildLeafOptions;
  WarmupGenerateSignedMaterials(LCACertPEM, LCAKeyPEM);

  GOriginalBIONew := BIO_new;
  try
    AssertGenerateSignedConstructorNilResultFailure(
      'GenerateSigned when private-key PEM export BIO_new returns nil',
      LLeafOptions,
      LCACertPEM,
      LCAKeyPEM,
      PRIVATE_KEY_EXPORT_BIO_NEW_CALL,
      'Failed to create BIO for key export'
    );
  finally
    BIO_new := GOriginalBIONew;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Utils GenerateSigned PEM Export BIO_new Nil-Result Family Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('certificate utils generate-signed PEM export BIO_new nil-result family contract',
        'failed to initialize OpenSSL library');

    if SkippedTests = 0 then
    begin
      LoadOpenSSLCore();
      LoadOpenSSLBIO();
      LoadOpenSSLX509();
      if not LoadOpenSSLPEM(GetCryptoLibHandle) then
        raise Exception.Create('failed to load PEM support');
      if not LoadEVP(GetCryptoLibHandle) then
        raise Exception.Create('failed to load EVP support');
    end;

    if SkippedTests = 0 then
    begin
      TestGenerateSignedShouldStopAtCertificateExportBIONilResult;
      TestGenerateSignedShouldStopAtPrivateKeyExportBIONilResult;
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
      WriteLn;
      WriteLn('[FATAL] ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
