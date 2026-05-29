program test_cert_utils_generate_signed_bio_contract;

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

function BuildCAOptions: TCertGenOptions;
begin
  Result := TCertificateUtils.DefaultGenOptions;
  Result.CommonName := 'generate-signed-contract-root.local';
  Result.Organization := 'fafafa.ssl contract';
  Result.IsCA := True;
  Result.ValidDays := 30;
end;

function BuildLeafOptions: TCertGenOptions;
begin
  Result := TCertificateUtils.DefaultGenOptions;
  Result.CommonName := 'generate-signed-contract-leaf.local';
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

procedure AssertGenerateSignedControlledFailure(
  const AName: string;
  const AOptions: TCertGenOptions;
  const ACACertPEM, ACAKeyPEM: string
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
begin
  LRaised := False;
  LControlled := False;
  LDetail := '';
  LCertPEM := '';
  LKeyPEM := '';
  try
    TCertificateUtils.GenerateSigned(AOptions, ACACertPEM, ACAKeyPEM, LCertPEM, LKeyPEM);
  except
    on E: Exception do
    begin
      LRaised := True;
      LControlled := E is ESSLCertError;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should raise', LRaised,
    'expected GenerateSigned(...) to fail');
  AssertTrue(AName + ' should raise controlled ESSLCertError', LControlled, LDetail);

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

procedure TestGenerateSignedShouldFailGracefullyWhenHelpersAreUnavailable;
var
  LCAOptions: TCertGenOptions;
  LLeafOptions: TCertGenOptions;
  LCACertPEM: string;
  LCAKeyPEM: string;
  LOriginalBIONewMemBuf: TBIO_new_mem_buf;
  LOriginalPEMReadX509: TPEM_read_bio_X509;
  LOriginalPEMReadPrivateKey: TPEM_read_bio_PrivateKey;
  LOriginalBIONew: TBIO_new;
  LOriginalBIOSMem: TBIO_s_mem;
  LOriginalBIOFree: TBIO_free;
  LOriginalPEMWriteX509: TPEM_write_bio_X509;
  LOriginalPEMWritePrivateKey: TPEM_write_bio_PrivateKey;
begin
  WriteLn;
  WriteLn('=== Certificate utils signed-generation BIO guard ===');

  if (not Assigned(BIO_new_mem_buf)) or
     (not Assigned(PEM_read_bio_X509)) or
     (not Assigned(PEM_read_bio_PrivateKey)) or
     (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) or
     (not Assigned(BIO_free)) or
     (not Assigned(PEM_write_bio_X509)) or
     (not Assigned(PEM_write_bio_PrivateKey)) then
  begin
    MarkSkip('certificate utils generate-signed bio contract',
      'required baseline OpenSSL PEM/BIO helpers are unavailable');
    Exit;
  end;

  LCAOptions := BuildCAOptions;
  LLeafOptions := BuildLeafOptions;
  WarmupGenerateSignedMaterials(LCACertPEM, LCAKeyPEM);

  LOriginalBIONewMemBuf := BIO_new_mem_buf;
  BIO_new_mem_buf := nil;
  try
    AssertGenerateSignedControlledFailure(
      'GenerateSigned when BIO_new_mem_buf is unavailable',
      LLeafOptions,
      LCACertPEM,
      LCAKeyPEM
    );
  finally
    BIO_new_mem_buf := LOriginalBIONewMemBuf;
  end;

  LOriginalPEMReadX509 := PEM_read_bio_X509;
  PEM_read_bio_X509 := nil;
  try
    AssertGenerateSignedControlledFailure(
      'GenerateSigned when PEM_read_bio_X509 is unavailable',
      LLeafOptions,
      LCACertPEM,
      LCAKeyPEM
    );
  finally
    PEM_read_bio_X509 := LOriginalPEMReadX509;
  end;

  LOriginalPEMReadPrivateKey := PEM_read_bio_PrivateKey;
  PEM_read_bio_PrivateKey := nil;
  try
    AssertGenerateSignedControlledFailure(
      'GenerateSigned when PEM_read_bio_PrivateKey is unavailable',
      LLeafOptions,
      LCACertPEM,
      LCAKeyPEM
    );
  finally
    PEM_read_bio_PrivateKey := LOriginalPEMReadPrivateKey;
  end;

  LOriginalBIONew := BIO_new;
  BIO_new := nil;
  try
    AssertGenerateSignedControlledFailure(
      'GenerateSigned when BIO_new is unavailable',
      LLeafOptions,
      LCACertPEM,
      LCAKeyPEM
    );
  finally
    BIO_new := LOriginalBIONew;
  end;

  LOriginalBIOSMem := BIO_s_mem;
  BIO_s_mem := nil;
  try
    AssertGenerateSignedControlledFailure(
      'GenerateSigned when BIO_s_mem is unavailable',
      LLeafOptions,
      LCACertPEM,
      LCAKeyPEM
    );
  finally
    BIO_s_mem := LOriginalBIOSMem;
  end;

  LOriginalBIOFree := BIO_free;
  BIO_free := nil;
  try
    AssertGenerateSignedControlledFailure(
      'GenerateSigned when BIO_free is unavailable',
      LLeafOptions,
      LCACertPEM,
      LCAKeyPEM
    );
  finally
    BIO_free := LOriginalBIOFree;
  end;

  LOriginalPEMWriteX509 := PEM_write_bio_X509;
  PEM_write_bio_X509 := nil;
  try
    AssertGenerateSignedControlledFailure(
      'GenerateSigned when PEM_write_bio_X509 is unavailable',
      LLeafOptions,
      LCACertPEM,
      LCAKeyPEM
    );
  finally
    PEM_write_bio_X509 := LOriginalPEMWriteX509;
  end;

  LOriginalPEMWritePrivateKey := PEM_write_bio_PrivateKey;
  PEM_write_bio_PrivateKey := nil;
  try
    AssertGenerateSignedControlledFailure(
      'GenerateSigned when PEM_write_bio_PrivateKey is unavailable',
      LLeafOptions,
      LCACertPEM,
      LCAKeyPEM
    );
  finally
    PEM_write_bio_PrivateKey := LOriginalPEMWritePrivateKey;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Utils GenerateSigned BIO Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('certificate utils generate-signed bio contract',
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
      TestGenerateSignedShouldFailGracefullyWhenHelpersAreUnavailable;

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
