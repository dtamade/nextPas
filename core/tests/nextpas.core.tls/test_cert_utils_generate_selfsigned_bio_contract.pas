program test_cert_utils_generate_selfsigned_bio_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.evp;

var
  GLib: ISSLLibrary = nil;
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

function BuildOptions: TCertGenOptions;
begin
  Result := TCertificateUtils.DefaultGenOptions;
  Result.CommonName := 'selfsigned-bio-contract.local';
  Result.Organization := 'fafafa.ssl contract';
  Result.ValidDays := 30;
end;

procedure WarmupGenerateSelfSigned(const AOptions: TCertGenOptions);
var
  LCertPEM: string;
  LKeyPEM: string;
begin
  if not TCertificateUtils.GenerateSelfSigned(AOptions, LCertPEM, LKeyPEM) then
    raise Exception.Create('GenerateSelfSigned warmup returned False');
  if (LCertPEM = '') or (LKeyPEM = '') then
    raise Exception.Create('GenerateSelfSigned warmup returned empty PEM output');
end;

procedure AssertGenerateSelfSignedControlledFailure(
  const AName: string;
  const AOptions: TCertGenOptions
);
var
  LRaised: Boolean;
  LControlled: Boolean;
  LDetail: string;
  LCertPEM: string;
  LKeyPEM: string;
  LTryRaised: Boolean;
  LTryDetail: string;
  LTryResult: Boolean;
  LTrySimpleRaised: Boolean;
  LTrySimpleDetail: string;
  LTrySimpleResult: Boolean;
begin
  LRaised := False;
  LControlled := False;
  LDetail := '';
  LCertPEM := '';
  LKeyPEM := '';
  try
    TCertificateUtils.GenerateSelfSigned(AOptions, LCertPEM, LKeyPEM);
  except
    on E: Exception do
    begin
      LRaised := True;
      LControlled := E is ESSLCertError;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should raise', LRaised,
    'expected GenerateSelfSigned(...) to fail');
  AssertTrue(AName + ' should raise controlled ESSLCertError', LControlled, LDetail);

  LTryRaised := False;
  LTryDetail := '';
  LTryResult := True;
  LCertPEM := 'sentinel-cert';
  LKeyPEM := 'sentinel-key';
  try
    LTryResult := TCertificateUtils.TryGenerateSelfSigned(AOptions, LCertPEM, LKeyPEM);
  except
    on E: Exception do
    begin
      LTryRaised := True;
      LTryDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' TryGenerateSelfSigned should not raise', not LTryRaised, LTryDetail);
  AssertTrue(AName + ' TryGenerateSelfSigned should return False', not LTryResult,
    'expected TryGenerateSelfSigned to return False');
  AssertTrue(AName + ' TryGenerateSelfSigned should clear cert output', LCertPEM = '',
    'expected cleared certificate output');
  AssertTrue(AName + ' TryGenerateSelfSigned should clear key output', LKeyPEM = '',
    'expected cleared key output');

  LTrySimpleRaised := False;
  LTrySimpleDetail := '';
  LTrySimpleResult := True;
  LCertPEM := 'sentinel-cert';
  LKeyPEM := 'sentinel-key';
  try
    LTrySimpleResult := TCertificateUtils.TryGenerateSelfSignedSimple(
      AOptions.CommonName,
      AOptions.Organization,
      AOptions.ValidDays,
      LCertPEM,
      LKeyPEM
    );
  except
    on E: Exception do
    begin
      LTrySimpleRaised := True;
      LTrySimpleDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' TryGenerateSelfSignedSimple should not raise',
    not LTrySimpleRaised, LTrySimpleDetail);
  AssertTrue(AName + ' TryGenerateSelfSignedSimple should return False', not LTrySimpleResult,
    'expected TryGenerateSelfSignedSimple to return False');
  AssertTrue(AName + ' TryGenerateSelfSignedSimple should clear cert output', LCertPEM = '',
    'expected cleared certificate output');
  AssertTrue(AName + ' TryGenerateSelfSignedSimple should clear key output', LKeyPEM = '',
    'expected cleared key output');
end;

procedure TestGenerateSelfSignedShouldFailGracefullyWhenExportHelpersAreUnavailable;
var
  LOptions: TCertGenOptions;
  LOriginalBIONew: TBIO_new;
  LOriginalBIOSMem: TBIO_s_mem;
  LOriginalBIOFree: TBIO_free;
  LOriginalPEMWriteX509: TPEM_write_bio_X509;
  LOriginalPEMWritePrivateKey: TPEM_write_bio_PrivateKey;
begin
  WriteLn;
  WriteLn('=== Certificate utils self-signed export BIO guard ===');

  if (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) or
     (not Assigned(BIO_free)) or
     (not Assigned(PEM_write_bio_X509)) or
     (not Assigned(PEM_write_bio_PrivateKey)) then
  begin
    MarkSkip('certificate utils selfsigned bio contract',
      'required baseline OpenSSL export helpers are unavailable');
    Exit;
  end;

  LOptions := BuildOptions;
  WarmupGenerateSelfSigned(LOptions);

  LOriginalBIONew := BIO_new;
  BIO_new := nil;
  try
    AssertGenerateSelfSignedControlledFailure(
      'GenerateSelfSigned when BIO_new is unavailable',
      LOptions
    );
  finally
    BIO_new := LOriginalBIONew;
  end;

  LOriginalBIOSMem := BIO_s_mem;
  BIO_s_mem := nil;
  try
    AssertGenerateSelfSignedControlledFailure(
      'GenerateSelfSigned when BIO_s_mem is unavailable',
      LOptions
    );
  finally
    BIO_s_mem := LOriginalBIOSMem;
  end;

  LOriginalBIOFree := BIO_free;
  BIO_free := nil;
  try
    AssertGenerateSelfSignedControlledFailure(
      'GenerateSelfSigned when BIO_free is unavailable',
      LOptions
    );
  finally
    BIO_free := LOriginalBIOFree;
  end;

  LOriginalPEMWriteX509 := PEM_write_bio_X509;
  PEM_write_bio_X509 := nil;
  try
    AssertGenerateSelfSignedControlledFailure(
      'GenerateSelfSigned when PEM_write_bio_X509 is unavailable',
      LOptions
    );
  finally
    PEM_write_bio_X509 := LOriginalPEMWriteX509;
  end;

  LOriginalPEMWritePrivateKey := PEM_write_bio_PrivateKey;
  PEM_write_bio_PrivateKey := nil;
  try
    AssertGenerateSelfSignedControlledFailure(
      'GenerateSelfSigned when PEM_write_bio_PrivateKey is unavailable',
      LOptions
    );
  finally
    PEM_write_bio_PrivateKey := LOriginalPEMWritePrivateKey;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Utils GenerateSelfSigned BIO Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('certificate utils selfsigned bio contract',
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
      TestGenerateSelfSignedShouldFailGracefullyWhenExportHelpersAreUnavailable;

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
