program test_cert_utils_generate_selfsigned_private_key_export_post_success_cleanup_family_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.x509v3,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.evp;

var
  GLib: ISSLLibrary = nil;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;
  GOriginalBIORead: TBIO_read = nil;
  GOriginalBIOFree: TBIO_free = nil;
  GBIOReadCallCount: Integer = 0;

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
  Result.CommonName := 'selfsigned-private-key-export-post-success.local';
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

function LooksLikeCertificatePEM(const AValue: string): Boolean;
begin
  Result := Pos('BEGIN CERTIFICATE', AValue) > 0;
end;

function LooksLikePrivateKeyPEM(const AValue: string): Boolean;
begin
  Result := (Pos('BEGIN ', AValue) > 0) and (Pos('PRIVATE KEY', AValue) > 0);
end;

function DisableBIOFreeAfterSecondBIORead(ABIO: Pointer; AData: Pointer; ADLen: Integer): Integer; cdecl;
begin
  Inc(GBIOReadCallCount);
  Result := GOriginalBIORead(ABIO, AData, ADLen);
  if (GBIOReadCallCount = 2) and (Result > 0) then
    BIO_free := nil;
end;

procedure PrepareLateBIOFreeLoss;
begin
  GBIOReadCallCount := 0;
  BIO_free := GOriginalBIOFree;
  BIO_read := @DisableBIOFreeAfterSecondBIORead;
end;

procedure AssertGenerateSelfSignedPreservesOutput(
  const AName: string;
  const AOptions: TCertGenOptions
);
var
  LRaised: Boolean;
  LDetail: string;
  LResult: Boolean;
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
  LDetail := '';
  LResult := False;
  LCertPEM := '';
  LKeyPEM := '';
  PrepareLateBIOFreeLoss;
  try
    LResult := TCertificateUtils.GenerateSelfSigned(AOptions, LCertPEM, LKeyPEM);
  except
    on E: Exception do
    begin
      LRaised := True;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' direct should not raise', not LRaised, LDetail);
  AssertTrue(AName + ' direct should return True', LResult,
    'expected GenerateSelfSigned to preserve the successful result');
  AssertTrue(AName + ' direct should preserve certificate output',
    LooksLikeCertificatePEM(LCertPEM), 'expected already-materialized certificate PEM output');
  AssertTrue(AName + ' direct should preserve key output',
    LooksLikePrivateKeyPEM(LKeyPEM), 'expected already-materialized private-key PEM output');

  LTryRaised := False;
  LTryDetail := '';
  LTryResult := False;
  LCertPEM := '';
  LKeyPEM := '';
  PrepareLateBIOFreeLoss;
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
  AssertTrue(AName + ' TryGenerateSelfSigned should return True', LTryResult,
    'expected TryGenerateSelfSigned to preserve the successful result');
  AssertTrue(AName + ' TryGenerateSelfSigned should preserve certificate output',
    LooksLikeCertificatePEM(LCertPEM), 'expected preserved certificate PEM output');
  AssertTrue(AName + ' TryGenerateSelfSigned should preserve key output',
    LooksLikePrivateKeyPEM(LKeyPEM), 'expected preserved private-key PEM output');

  LTrySimpleRaised := False;
  LTrySimpleDetail := '';
  LTrySimpleResult := False;
  LCertPEM := '';
  LKeyPEM := '';
  PrepareLateBIOFreeLoss;
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
  AssertTrue(AName + ' TryGenerateSelfSignedSimple should return True', LTrySimpleResult,
    'expected TryGenerateSelfSignedSimple to preserve the successful result');
  AssertTrue(AName + ' TryGenerateSelfSignedSimple should preserve certificate output',
    LooksLikeCertificatePEM(LCertPEM), 'expected preserved certificate PEM output');
  AssertTrue(AName + ' TryGenerateSelfSignedSimple should preserve key output',
    LooksLikePrivateKeyPEM(LKeyPEM), 'expected preserved private-key PEM output');
end;

procedure TestGenerateSelfSignedPrivateKeyExportPostSuccessCleanupFamily;
var
  LOptions: TCertGenOptions;
begin
  WriteLn;
  WriteLn('=== Certificate utils GenerateSelfSigned private-key export post-success cleanup family ===');

  if (not Assigned(BIO_read)) or (not Assigned(BIO_free)) then
  begin
    MarkSkip('certificate utils GenerateSelfSigned private-key export post-success cleanup family contract',
      'required baseline BIO_read/BIO_free helpers are unavailable');
    Exit;
  end;

  LOptions := BuildOptions;
  WarmupGenerateSelfSigned(LOptions);

  GOriginalBIORead := BIO_read;
  GOriginalBIOFree := BIO_free;
  try
    AssertGenerateSelfSignedPreservesOutput(
      'GenerateSelfSigned when BIO_free disappears after private-key PEM success',
      LOptions
    );
  finally
    BIO_read := GOriginalBIORead;
    BIO_free := GOriginalBIOFree;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Utils GenerateSelfSigned Private-Key Export Post-Success Cleanup Family Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('certificate utils GenerateSelfSigned private-key export post-success cleanup family contract',
        'failed to initialize OpenSSL library');

    if SkippedTests = 0 then
    begin
      LoadOpenSSLCore();
      LoadOpenSSLBIO();
      LoadOpenSSLX509();
      LoadX509V3Functions(GetCryptoLibHandle);
      if not LoadOpenSSLPEM(GetCryptoLibHandle) then
        raise Exception.Create('failed to load PEM support');
      if not LoadEVP(GetCryptoLibHandle) then
        raise Exception.Create('failed to load EVP support');
    end;

    if SkippedTests = 0 then
      TestGenerateSelfSignedPrivateKeyExportPostSuccessCleanupFamily;

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
