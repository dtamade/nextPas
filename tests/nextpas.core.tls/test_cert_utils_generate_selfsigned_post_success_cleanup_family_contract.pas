program test_cert_utils_generate_selfsigned_post_success_cleanup_family_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.x509v3,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.evp;

type
  TBIOReadStubMode = (
    brmNone,
    brmDisableX509FreeAfterKeyReadSuccess
  );

  TX509FreeStubMode = (
    xfmNone,
    xfmDisableEVPPKeyFreeAfterCleanup
  );

  TPrepareScenario = procedure;

var
  GLib: ISSLLibrary = nil;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;
  GOriginalBIORead: TBIO_read = nil;
  GOriginalX509Free: TX509_free = nil;
  GOriginalEVPPKeyFree: TEVP_PKEY_free = nil;
  GBIOReadStubMode: TBIOReadStubMode = brmNone;
  GX509FreeStubMode: TX509FreeStubMode = xfmNone;
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
  Result.CommonName := 'selfsigned-post-success-cleanup.local';
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

procedure ResetStubState;
begin
  GBIOReadStubMode := brmNone;
  GX509FreeStubMode := xfmNone;
  GBIOReadCallCount := 0;
end;

procedure RestoreHelperFunctions(
  AOriginalBIORead: TBIO_read;
  AOriginalX509Free: TX509_free;
  AOriginalEVPPKeyFree: TEVP_PKEY_free
);
begin
  BIO_read := AOriginalBIORead;
  X509_free := AOriginalX509Free;
  EVP_PKEY_free := AOriginalEVPPKeyFree;
  ResetStubState;
end;

function StubBIORead(ABIO: Pointer; AData: Pointer; ADLen: Integer): Integer; cdecl;
begin
  if Assigned(GOriginalBIORead) then
    Result := GOriginalBIORead(ABIO, AData, ADLen)
  else
    Result := 0;

  if (GBIOReadStubMode = brmDisableX509FreeAfterKeyReadSuccess) and (Result > 0) then
  begin
    Inc(GBIOReadCallCount);
    if GBIOReadCallCount = 2 then
      X509_free := nil;
  end;
end;

procedure StubX509Free(x: PX509); cdecl;
begin
  if Assigned(GOriginalX509Free) then
    GOriginalX509Free(x);

  if GX509FreeStubMode = xfmDisableEVPPKeyFreeAfterCleanup then
    EVP_PKEY_free := nil;
end;

procedure PrepareCertificateCleanupLoss;
begin
  ResetStubState;
  X509_free := GOriginalX509Free;
  EVP_PKEY_free := GOriginalEVPPKeyFree;
  BIO_read := @StubBIORead;
  GBIOReadStubMode := brmDisableX509FreeAfterKeyReadSuccess;
end;

procedure PrepareKeyCleanupLoss;
begin
  ResetStubState;
  BIO_read := GOriginalBIORead;
  EVP_PKEY_free := GOriginalEVPPKeyFree;
  X509_free := @StubX509Free;
  GX509FreeStubMode := xfmDisableEVPPKeyFreeAfterCleanup;
end;

procedure AssertGenerateSelfSignedPreservesOutput(
  const AName: string;
  const AOptions: TCertGenOptions;
  APrepareScenario: TPrepareScenario
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
  if Assigned(APrepareScenario) then
    APrepareScenario();
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
  AssertTrue(AName + ' direct should preserve certificate output', LooksLikeCertificatePEM(LCertPEM),
    'expected already-materialized certificate PEM output');
  AssertTrue(AName + ' direct should preserve key output', LooksLikePrivateKeyPEM(LKeyPEM),
    'expected already-materialized private-key PEM output');

  LTryRaised := False;
  LTryDetail := '';
  LTryResult := False;
  LCertPEM := '';
  LKeyPEM := '';
  if Assigned(APrepareScenario) then
    APrepareScenario();
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
  if Assigned(APrepareScenario) then
    APrepareScenario();
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

procedure TestGenerateSelfSignedPostSuccessCleanupFamily;
var
  LOptions: TCertGenOptions;
  LOriginalBIORead: TBIO_read;
  LOriginalX509Free: TX509_free;
  LOriginalEVPPKeyFree: TEVP_PKEY_free;
begin
  WriteLn;
  WriteLn('=== Certificate utils GenerateSelfSigned post-success cleanup family ===');

  if (not Assigned(BIO_read)) or
     (not Assigned(X509_free)) or
     (not Assigned(EVP_PKEY_free)) then
  begin
    MarkSkip('certificate utils GenerateSelfSigned post-success cleanup family contract',
      'required baseline BIO_read/X509_free/EVP_PKEY_free helpers are unavailable');
    Exit;
  end;

  LOptions := BuildOptions;
  WarmupGenerateSelfSigned(LOptions);

  LOriginalBIORead := BIO_read;
  LOriginalX509Free := X509_free;
  LOriginalEVPPKeyFree := EVP_PKEY_free;

  GOriginalBIORead := LOriginalBIORead;
  GOriginalX509Free := LOriginalX509Free;
  GOriginalEVPPKeyFree := LOriginalEVPPKeyFree;

  try
    AssertGenerateSelfSignedPreservesOutput(
      'GenerateSelfSigned when X509_free disappears after PEM success',
      LOptions,
      @PrepareCertificateCleanupLoss
    );

    AssertGenerateSelfSignedPreservesOutput(
      'GenerateSelfSigned when EVP_PKEY_free disappears after certificate cleanup',
      LOptions,
      @PrepareKeyCleanupLoss
    );
  finally
    RestoreHelperFunctions(LOriginalBIORead, LOriginalX509Free, LOriginalEVPPKeyFree);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Utils GenerateSelfSigned Post-Success Cleanup Family Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('certificate utils GenerateSelfSigned post-success cleanup family contract',
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
      TestGenerateSelfSignedPostSuccessCleanupFamily;

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
