program test_cert_utils_generate_signed_post_success_cleanup_family_contract;

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
    brmDisableLeafX509FreeAfterKeyReadSuccess
  );

  TX509FreeStubMode = (
    xfmNone,
    xfmDisableLeafEVPPKeyFreeAfterLeafCleanup
  );

  TEVPPKeyFreeStubMode = (
    pfmNone,
    pfmDisableCAEVPPKeyFreeAfterLeafKeyCleanup,
    pfmDisableCAX509FreeAfterCAKeyCleanup
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
  GEVPPKeyFreeStubMode: TEVPPKeyFreeStubMode = pfmNone;
  GBIOReadCallCount: Integer = 0;
  GEVPPKeyFreeCallCount: Integer = 0;

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
  Result.CommonName := 'signed-post-success-root.local';
  Result.Organization := 'fafafa.ssl contract';
  Result.IsCA := True;
  Result.ValidDays := 30;
end;

function BuildLeafOptions: TCertGenOptions;
begin
  Result := TCertificateUtils.DefaultGenOptions;
  Result.CommonName := 'signed-post-success-leaf.local';
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
  GEVPPKeyFreeStubMode := pfmNone;
  GBIOReadCallCount := 0;
  GEVPPKeyFreeCallCount := 0;
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

  if (GBIOReadStubMode = brmDisableLeafX509FreeAfterKeyReadSuccess) and (Result > 0) then
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

  if GX509FreeStubMode = xfmDisableLeafEVPPKeyFreeAfterLeafCleanup then
    EVP_PKEY_free := nil;
end;

procedure StubEVPPKeyFree(AKey: PEVP_PKEY); cdecl;
begin
  Inc(GEVPPKeyFreeCallCount);
  if Assigned(GOriginalEVPPKeyFree) then
    GOriginalEVPPKeyFree(AKey);

  case GEVPPKeyFreeStubMode of
    pfmDisableCAEVPPKeyFreeAfterLeafKeyCleanup:
      if GEVPPKeyFreeCallCount = 1 then
        EVP_PKEY_free := nil;
    pfmDisableCAX509FreeAfterCAKeyCleanup:
      if GEVPPKeyFreeCallCount = 2 then
        X509_free := nil;
  end;
end;

procedure PrepareLeafCertificateCleanupLoss;
begin
  ResetStubState;
  X509_free := GOriginalX509Free;
  EVP_PKEY_free := GOriginalEVPPKeyFree;
  BIO_read := @StubBIORead;
  GBIOReadStubMode := brmDisableLeafX509FreeAfterKeyReadSuccess;
end;

procedure PrepareLeafKeyCleanupLoss;
begin
  ResetStubState;
  BIO_read := GOriginalBIORead;
  EVP_PKEY_free := GOriginalEVPPKeyFree;
  X509_free := @StubX509Free;
  GX509FreeStubMode := xfmDisableLeafEVPPKeyFreeAfterLeafCleanup;
end;

procedure PrepareCAKeyCleanupLoss;
begin
  ResetStubState;
  BIO_read := GOriginalBIORead;
  X509_free := GOriginalX509Free;
  EVP_PKEY_free := @StubEVPPKeyFree;
  GEVPPKeyFreeStubMode := pfmDisableCAEVPPKeyFreeAfterLeafKeyCleanup;
end;

procedure PrepareCACertificateCleanupLoss;
begin
  ResetStubState;
  BIO_read := GOriginalBIORead;
  X509_free := GOriginalX509Free;
  EVP_PKEY_free := @StubEVPPKeyFree;
  GEVPPKeyFreeStubMode := pfmDisableCAX509FreeAfterCAKeyCleanup;
end;

procedure AssertGenerateSignedPreservesOutput(
  const AName: string;
  const AOptions: TCertGenOptions;
  const ACACertPEM, ACAKeyPEM: string;
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
begin
  LRaised := False;
  LDetail := '';
  LResult := False;
  LCertPEM := '';
  LKeyPEM := '';
  if Assigned(APrepareScenario) then
    APrepareScenario();
  try
    LResult := TCertificateUtils.GenerateSigned(AOptions, ACACertPEM, ACAKeyPEM, LCertPEM, LKeyPEM);
  except
    on E: Exception do
    begin
      LRaised := True;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' direct should not raise', not LRaised, LDetail);
  AssertTrue(AName + ' direct should return True', LResult,
    'expected GenerateSigned to preserve the successful result');
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
  AssertTrue(AName + ' TryGenerateSigned should return True', LTryResult,
    'expected TryGenerateSigned to preserve the successful result');
  AssertTrue(AName + ' TryGenerateSigned should preserve certificate output',
    LooksLikeCertificatePEM(LCertPEM), 'expected preserved certificate PEM output');
  AssertTrue(AName + ' TryGenerateSigned should preserve key output',
    LooksLikePrivateKeyPEM(LKeyPEM), 'expected preserved private-key PEM output');
end;

procedure TestGenerateSignedPostSuccessCleanupFamily;
var
  LLeafOptions: TCertGenOptions;
  LCACertPEM: string;
  LCAKeyPEM: string;
  LOriginalBIORead: TBIO_read;
  LOriginalX509Free: TX509_free;
  LOriginalEVPPKeyFree: TEVP_PKEY_free;
begin
  WriteLn;
  WriteLn('=== Certificate utils GenerateSigned post-success cleanup family ===');

  if (not Assigned(BIO_read)) or
     (not Assigned(X509_free)) or
     (not Assigned(EVP_PKEY_free)) then
  begin
    MarkSkip('certificate utils GenerateSigned post-success cleanup family contract',
      'required baseline BIO_read/X509_free/EVP_PKEY_free helpers are unavailable');
    Exit;
  end;

  LLeafOptions := BuildLeafOptions;
  WarmupGenerateSignedMaterials(LCACertPEM, LCAKeyPEM);

  LOriginalBIORead := BIO_read;
  LOriginalX509Free := X509_free;
  LOriginalEVPPKeyFree := EVP_PKEY_free;

  GOriginalBIORead := LOriginalBIORead;
  GOriginalX509Free := LOriginalX509Free;
  GOriginalEVPPKeyFree := LOriginalEVPPKeyFree;

  try
    AssertGenerateSignedPreservesOutput(
      'GenerateSigned when leaf X509_free disappears after PEM success',
      LLeafOptions,
      LCACertPEM,
      LCAKeyPEM,
      @PrepareLeafCertificateCleanupLoss
    );

    AssertGenerateSignedPreservesOutput(
      'GenerateSigned when leaf EVP_PKEY_free disappears after leaf cleanup',
      LLeafOptions,
      LCACertPEM,
      LCAKeyPEM,
      @PrepareLeafKeyCleanupLoss
    );

    AssertGenerateSignedPreservesOutput(
      'GenerateSigned when CA EVP_PKEY_free disappears after leaf-key cleanup',
      LLeafOptions,
      LCACertPEM,
      LCAKeyPEM,
      @PrepareCAKeyCleanupLoss
    );

    AssertGenerateSignedPreservesOutput(
      'GenerateSigned when CA X509_free disappears after CA-key cleanup',
      LLeafOptions,
      LCACertPEM,
      LCAKeyPEM,
      @PrepareCACertificateCleanupLoss
    );
  finally
    RestoreHelperFunctions(LOriginalBIORead, LOriginalX509Free, LOriginalEVPPKeyFree);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Utils GenerateSigned Post-Success Cleanup Family Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('certificate utils GenerateSigned post-success cleanup family contract',
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
      TestGenerateSignedPostSuccessCleanupFamily;

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
