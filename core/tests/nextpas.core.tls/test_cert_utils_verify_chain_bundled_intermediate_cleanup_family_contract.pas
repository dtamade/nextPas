program test_cert_utils_verify_chain_bundled_intermediate_cleanup_family_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.evp;

type
  TPEMReadX509StubMode = (
    prmNone,
    prmDisableX509FreeAfterFirstSuccess
  );

  TBIOSMemStubMode = (
    bsmNone,
    bsmDisableBIONewAfterFirstSuccess
  );

  TPEMWriteX509StubMode = (
    pwmNone,
    pwmDisableX509FreeAfterFirstSuccess
  );

var
  GLib: ISSLLibrary = nil;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;
  GOriginalPEMReadX509: TPEM_read_bio_X509 = nil;
  GOriginalBIONew: TBIO_new = nil;
  GOriginalBIOFree: TBIO_free = nil;
  GOriginalBIOSMem: TBIO_s_mem = nil;
  GOriginalPEMWriteX509: TPEM_write_bio_X509 = nil;
  GPEMReadX509StubMode: TPEMReadX509StubMode = prmNone;
  GBIOSMemStubMode: TBIOSMemStubMode = bsmNone;
  GPEMWriteX509StubMode: TPEMWriteX509StubMode = pwmNone;
  GPEMReadX509CallCount: Integer = 0;
  GBIOSMemCallCount: Integer = 0;
  GPEMWriteX509CallCount: Integer = 0;
  GTrackIntermediateExportBIO: Boolean = False;
  GTrackedIntermediateExportBIO: PBIO = nil;
  GDisableX509FreeAfterTrackedBIOFree: Boolean = False;

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

function BuildRootOptions: TCertGenOptions;
begin
  Result := TCertificateUtils.DefaultGenOptions;
  Result.CommonName := 'verify-chain-cleanup-family-root.local';
  Result.Organization := 'fafafa.ssl contract';
  Result.IsCA := True;
  Result.ValidDays := 30;
end;

function BuildIntermediateOptions: TCertGenOptions;
begin
  Result := TCertificateUtils.DefaultGenOptions;
  Result.CommonName := 'verify-chain-cleanup-family-intermediate.local';
  Result.Organization := 'fafafa.ssl contract';
  Result.IsCA := True;
  Result.ValidDays := 30;
end;

function BuildLeafOptions: TCertGenOptions;
begin
  Result := TCertificateUtils.DefaultGenOptions;
  Result.CommonName := 'verify-chain-cleanup-family-leaf.local';
  Result.Organization := 'fafafa.ssl contract';
  Result.IsCA := False;
  Result.ValidDays := 30;
end;

procedure WriteTextFile(const AFileName, AContent: string);
var
  LText: TStringList;
begin
  ForceDirectories(ExtractFileDir(AFileName));
  LText := TStringList.Create;
  try
    LText.Text := AContent;
    LText.SaveToFile(AFileName);
  finally
    LText.Free;
  end;
end;

procedure WarmupVerifyChainMaterials(
  out ABundlePEM: string;
  out ARootPath: string
);
var
  LRootOptions: TCertGenOptions;
  LIntermediateOptions: TCertGenOptions;
  LLeafOptions: TCertGenOptions;
  LRootCertPEM: string;
  LRootKeyPEM: string;
  LIntermediateCertPEM: string;
  LIntermediateKeyPEM: string;
  LLeafCertPEM: string;
  LLeafKeyPEM: string;
begin
  LRootOptions := BuildRootOptions;
  if not TCertificateUtils.GenerateSelfSigned(LRootOptions, LRootCertPEM, LRootKeyPEM) then
    raise Exception.Create('GenerateSelfSigned warmup returned False');
  if (LRootCertPEM = '') or (LRootKeyPEM = '') then
    raise Exception.Create('GenerateSelfSigned warmup returned empty root material');

  ARootPath := 'tmp/cert_utils_verify_chain_bundled_intermediate_cleanup_family_contract/root.crt';
  WriteTextFile(ARootPath, LRootCertPEM);

  LIntermediateOptions := BuildIntermediateOptions;
  if not TCertificateUtils.GenerateSigned(
    LIntermediateOptions,
    LRootCertPEM,
    LRootKeyPEM,
    LIntermediateCertPEM,
    LIntermediateKeyPEM
  ) then
    raise Exception.Create('GenerateSigned warmup returned False for intermediate');
  if (LIntermediateCertPEM = '') or (LIntermediateKeyPEM = '') then
    raise Exception.Create('GenerateSigned warmup returned empty intermediate material');

  LLeafOptions := BuildLeafOptions;
  if not TCertificateUtils.GenerateSigned(
    LLeafOptions,
    LIntermediateCertPEM,
    LIntermediateKeyPEM,
    LLeafCertPEM,
    LLeafKeyPEM
  ) then
    raise Exception.Create('GenerateSigned warmup returned False for leaf');
  if (LLeafCertPEM = '') or (LLeafKeyPEM = '') then
    raise Exception.Create('GenerateSigned warmup returned empty leaf material');

  ABundlePEM := LLeafCertPEM + LineEnding + LIntermediateCertPEM;
  if not TCertificateUtils.VerifyChain(ABundlePEM, ARootPath) then
    raise Exception.Create('VerifyChain warmup returned False for bundled chain');
end;

procedure ResetStubState;
begin
  GPEMReadX509StubMode := prmNone;
  GBIOSMemStubMode := bsmNone;
  GPEMWriteX509StubMode := pwmNone;
  GPEMReadX509CallCount := 0;
  GBIOSMemCallCount := 0;
  GPEMWriteX509CallCount := 0;
  GTrackIntermediateExportBIO := False;
  GTrackedIntermediateExportBIO := nil;
  GDisableX509FreeAfterTrackedBIOFree := False;
end;

procedure RestoreHelperFunctions(
  AOriginalPEMReadX509: TPEM_read_bio_X509;
  AOriginalBIOSMem: TBIO_s_mem;
  AOriginalPEMWriteX509: TPEM_write_bio_X509;
  AOriginalBIONew: TBIO_new;
  AOriginalBIOFree: TBIO_free;
  AOriginalX509Free: TX509_free
);
begin
  PEM_read_bio_X509 := AOriginalPEMReadX509;
  BIO_s_mem := AOriginalBIOSMem;
  PEM_write_bio_X509 := AOriginalPEMWriteX509;
  BIO_new := AOriginalBIONew;
  BIO_free := AOriginalBIOFree;
  X509_free := AOriginalX509Free;
  ResetStubState;
end;

function StubPEMReadX509(bp: PBIO; x: PPX509; cb: Tpem_password_cb; u: Pointer): PX509; cdecl;
begin
  Inc(GPEMReadX509CallCount);

  if Assigned(GOriginalPEMReadX509) then
    Result := GOriginalPEMReadX509(bp, x, cb, u)
  else
    Result := nil;

  if (GPEMReadX509StubMode = prmDisableX509FreeAfterFirstSuccess) and
     (GPEMReadX509CallCount = 1) and (Result <> nil) then
    X509_free := nil;
end;

function StubBIOSMem: PBIO_METHOD; cdecl;
begin
  Inc(GBIOSMemCallCount);

  if Assigned(GOriginalBIOSMem) then
    Result := GOriginalBIOSMem()
  else
    Result := nil;

  if (GBIOSMemStubMode = bsmDisableBIONewAfterFirstSuccess) and
     (GBIOSMemCallCount = 1) and (Result <> nil) then
    BIO_new := nil;
end;

function StubBIONew(const &type: PBIO_METHOD): PBIO; cdecl;
begin
  if Assigned(GOriginalBIONew) then
    Result := GOriginalBIONew(&type)
  else
    Result := nil;

  if GTrackIntermediateExportBIO and (GTrackedIntermediateExportBIO = nil) and (Result <> nil) then
    GTrackedIntermediateExportBIO := Result;
end;

function StubBIOFree(a: PBIO): Integer; cdecl;
begin
  if Assigned(GOriginalBIOFree) then
    Result := GOriginalBIOFree(a)
  else
    Result := 0;

  if GDisableX509FreeAfterTrackedBIOFree and (a = GTrackedIntermediateExportBIO) then
    X509_free := nil;
end;

function StubPEMWriteX509(bp: PBIO; x: PX509): Integer; cdecl;
begin
  Inc(GPEMWriteX509CallCount);

  if Assigned(GOriginalPEMWriteX509) then
    Result := GOriginalPEMWriteX509(bp, x)
  else
    Result := 0;

  if (GPEMWriteX509StubMode = pwmDisableX509FreeAfterFirstSuccess) and
     (GPEMWriteX509CallCount = 1) and (Result = 1) then
    X509_free := nil;
end;

procedure PrepareSkipLeafCleanupFailure;
begin
  ResetStubState;
  PEM_read_bio_X509 := @StubPEMReadX509;
  GPEMReadX509StubMode := prmDisableX509FreeAfterFirstSuccess;
end;

procedure PrepareIntermediateExportConstructorFailure;
begin
  ResetStubState;
  BIO_s_mem := @StubBIOSMem;
  GBIOSMemStubMode := bsmDisableBIONewAfterFirstSuccess;
end;

procedure PrepareLoopCleanupFailure;
begin
  ResetStubState;
  BIO_new := @StubBIONew;
  BIO_free := @StubBIOFree;
  GTrackIntermediateExportBIO := True;
  GDisableX509FreeAfterTrackedBIOFree := True;
end;

procedure AssertDirectVerifyChainSafeDegrade(
  const AName: string;
  const ABundlePEM: string;
  const ARootPath: string
);
var
  LRaised: Boolean;
  LDetail: string;
  LResult: Boolean;
begin
  LRaised := False;
  LDetail := '';
  LResult := True;
  try
    LResult := TCertificateUtils.VerifyChain(ABundlePEM, ARootPath);
  except
    on E: Exception do
    begin
      LRaised := True;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should not raise', not LRaised, LDetail);
  AssertTrue(AName + ' should return False', not LResult,
    'expected VerifyChain(...) to return False');
end;

procedure AssertTryVerifyChainSafeDegrade(
  const AName: string;
  const ABundlePEM: string;
  const ARootPath: string
);
var
  LRaised: Boolean;
  LDetail: string;
  LTryResult: Boolean;
  LIsValid: Boolean;
begin
  LRaised := False;
  LDetail := '';
  LTryResult := False;
  LIsValid := True;
  try
    LTryResult := TCertificateUtils.TryVerifyChain(ABundlePEM, ARootPath, LIsValid);
  except
    on E: Exception do
    begin
      LRaised := True;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' TryVerifyChain should not raise', not LRaised, LDetail);
  AssertTrue(AName + ' TryVerifyChain should return True', LTryResult,
    'expected TryVerifyChain(...) to surface degraded direct result');
  AssertTrue(AName + ' TryVerifyChain should set AIsValid=False', not LIsValid,
    'expected AIsValid to be False');
end;

procedure TestVerifyChainBundledIntermediateCleanupFamily;
var
  LBundlePEM: string;
  LRootPath: string;
  LOriginalPEMReadX509: TPEM_read_bio_X509;
  LOriginalBIOSMem: TBIO_s_mem;
  LOriginalPEMWriteX509: TPEM_write_bio_X509;
  LOriginalBIONew: TBIO_new;
  LOriginalBIOFree: TBIO_free;
  LOriginalX509Free: TX509_free;
begin
  WriteLn;
  WriteLn('=== Certificate utils VerifyChain bundled intermediate cleanup family ===');

  if (not Assigned(PEM_read_bio_X509)) or
     (not Assigned(BIO_s_mem)) or
     (not Assigned(BIO_new)) or
     (not Assigned(PEM_write_bio_X509)) or
     (not Assigned(X509_free)) then
  begin
    MarkSkip('certificate utils verify-chain bundled intermediate cleanup family contract',
      'required baseline OpenSSL helpers are unavailable');
    Exit;
  end;

  WarmupVerifyChainMaterials(LBundlePEM, LRootPath);

  LOriginalPEMReadX509 := PEM_read_bio_X509;
  LOriginalBIOSMem := BIO_s_mem;
  LOriginalPEMWriteX509 := PEM_write_bio_X509;
  LOriginalBIONew := BIO_new;
  LOriginalBIOFree := BIO_free;
  LOriginalX509Free := X509_free;

  GOriginalPEMReadX509 := LOriginalPEMReadX509;
  GOriginalBIONew := LOriginalBIONew;
  GOriginalBIOFree := LOriginalBIOFree;
  GOriginalBIOSMem := LOriginalBIOSMem;
  GOriginalPEMWriteX509 := LOriginalPEMWriteX509;

  try
    PrepareSkipLeafCleanupFailure;
    AssertDirectVerifyChainSafeDegrade(
      'VerifyChain when bundled skip-leaf X509_free becomes unavailable',
      LBundlePEM,
      LRootPath
    );
    RestoreHelperFunctions(
      LOriginalPEMReadX509,
      LOriginalBIOSMem,
      LOriginalPEMWriteX509,
      LOriginalBIONew,
      LOriginalBIOFree,
      LOriginalX509Free
    );

    PrepareSkipLeafCleanupFailure;
    AssertTryVerifyChainSafeDegrade(
      'VerifyChain when bundled skip-leaf X509_free becomes unavailable',
      LBundlePEM,
      LRootPath
    );
    RestoreHelperFunctions(
      LOriginalPEMReadX509,
      LOriginalBIOSMem,
      LOriginalPEMWriteX509,
      LOriginalBIONew,
      LOriginalBIOFree,
      LOriginalX509Free
    );

    PrepareIntermediateExportConstructorFailure;
    AssertDirectVerifyChainSafeDegrade(
      'VerifyChain when intermediate-export BIO_new becomes unavailable after BIO_s_mem',
      LBundlePEM,
      LRootPath
    );
    RestoreHelperFunctions(
      LOriginalPEMReadX509,
      LOriginalBIOSMem,
      LOriginalPEMWriteX509,
      LOriginalBIONew,
      LOriginalBIOFree,
      LOriginalX509Free
    );

    PrepareIntermediateExportConstructorFailure;
    AssertTryVerifyChainSafeDegrade(
      'VerifyChain when intermediate-export BIO_new becomes unavailable after BIO_s_mem',
      LBundlePEM,
      LRootPath
    );
    RestoreHelperFunctions(
      LOriginalPEMReadX509,
      LOriginalBIOSMem,
      LOriginalPEMWriteX509,
      LOriginalBIONew,
      LOriginalBIOFree,
      LOriginalX509Free
    );

    PrepareLoopCleanupFailure;
    AssertDirectVerifyChainSafeDegrade(
      'VerifyChain when intermediate loop X509_free becomes unavailable after intermediate-export BIO_free',
      LBundlePEM,
      LRootPath
    );
    RestoreHelperFunctions(
      LOriginalPEMReadX509,
      LOriginalBIOSMem,
      LOriginalPEMWriteX509,
      LOriginalBIONew,
      LOriginalBIOFree,
      LOriginalX509Free
    );

    PrepareLoopCleanupFailure;
    AssertTryVerifyChainSafeDegrade(
      'VerifyChain when intermediate loop X509_free becomes unavailable after intermediate-export BIO_free',
      LBundlePEM,
      LRootPath
    );
  finally
    RestoreHelperFunctions(
      LOriginalPEMReadX509,
      LOriginalBIOSMem,
      LOriginalPEMWriteX509,
      LOriginalBIONew,
      LOriginalBIOFree,
      LOriginalX509Free
    );
    GOriginalPEMReadX509 := nil;
    GOriginalBIONew := nil;
    GOriginalBIOFree := nil;
    GOriginalBIOSMem := nil;
    GOriginalPEMWriteX509 := nil;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Utils VerifyChain Bundled Intermediate Cleanup Family Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('certificate utils verify-chain bundled intermediate cleanup family contract',
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
      TestVerifyChainBundledIntermediateCleanupFamily;

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
