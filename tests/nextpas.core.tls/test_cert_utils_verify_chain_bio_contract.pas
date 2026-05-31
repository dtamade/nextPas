program test_cert_utils_verify_chain_bio_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.evp;

type
  TBIONewMemBufStubMode = (
    bmsNone,
    bmsDisableSelfAfterFirstCall,
    bmsDisableBIOFreeAfterSecondCall
  );

var
  GLib: ISSLLibrary = nil;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;
  GOriginalBIONewMemBuf: TBIO_new_mem_buf = nil;
  GOriginalPEMReadX509: TPEM_read_bio_X509 = nil;
  GOriginalBIOFree: TBIO_free = nil;
  GBIONewMemBufStubMode: TBIONewMemBufStubMode = bmsNone;
  GBIONewMemBufCallCount: Integer = 0;
  GDisablePEMReadX509AfterFirstCall: Boolean = False;
  GPEMReadX509CallCount: Integer = 0;

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
  Result.CommonName := 'verify-chain-contract-root.local';
  Result.Organization := 'fafafa.ssl contract';
  Result.IsCA := True;
  Result.ValidDays := 30;
end;

function BuildIntermediateOptions: TCertGenOptions;
begin
  Result := TCertificateUtils.DefaultGenOptions;
  Result.CommonName := 'verify-chain-contract-intermediate.local';
  Result.Organization := 'fafafa.ssl contract';
  Result.IsCA := True;
  Result.ValidDays := 30;
end;

function BuildLeafOptions: TCertGenOptions;
begin
  Result := TCertificateUtils.DefaultGenOptions;
  Result.CommonName := 'verify-chain-contract-leaf.local';
  Result.Organization := 'fafafa.ssl contract';
  Result.IsCA := False;
  Result.ValidDays := 30;
end;

function StubBIONewMemBuf(const buf: Pointer; len: Integer): PBIO; cdecl;
begin
  Inc(GBIONewMemBufCallCount);

  if Assigned(GOriginalBIONewMemBuf) then
    Result := GOriginalBIONewMemBuf(buf, len)
  else
    Result := nil;

  case GBIONewMemBufStubMode of
    bmsDisableSelfAfterFirstCall:
      if GBIONewMemBufCallCount = 1 then
        BIO_new_mem_buf := nil;
    bmsDisableBIOFreeAfterSecondCall:
      if GBIONewMemBufCallCount = 2 then
        BIO_free := nil;
  end;
end;

function StubPEMReadX509(bp: PBIO; x: PPX509; cb: Tpem_password_cb; u: Pointer): PX509; cdecl;
begin
  Inc(GPEMReadX509CallCount);

  if Assigned(GOriginalPEMReadX509) then
    Result := GOriginalPEMReadX509(bp, x, cb, u)
  else
    Result := nil;

  if GDisablePEMReadX509AfterFirstCall and (GPEMReadX509CallCount = 1) then
    PEM_read_bio_X509 := nil;
end;

procedure ResetHelperStubState;
begin
  GBIONewMemBufStubMode := bmsNone;
  GBIONewMemBufCallCount := 0;
  GDisablePEMReadX509AfterFirstCall := False;
  GPEMReadX509CallCount := 0;
end;

procedure RestoreHelperFunctions(
  AOriginalBIONewMemBuf: TBIO_new_mem_buf;
  AOriginalPEMReadX509: TPEM_read_bio_X509;
  AOriginalBIOFree: TBIO_free;
  AOriginalBIONew: TBIO_new;
  AOriginalBIOSMem: TBIO_s_mem;
  AOriginalPEMWriteX509: TPEM_write_bio_X509
);
begin
  BIO_new_mem_buf := AOriginalBIONewMemBuf;
  PEM_read_bio_X509 := AOriginalPEMReadX509;
  BIO_free := AOriginalBIOFree;
  BIO_new := AOriginalBIONew;
  BIO_s_mem := AOriginalBIOSMem;
  PEM_write_bio_X509 := AOriginalPEMWriteX509;
  ResetHelperStubState;
end;

procedure PrepareSecondStageBIONewMemBufFailure(AOriginalBIOFree: TBIO_free);
begin
  ResetHelperStubState;
  BIO_free := AOriginalBIOFree;
  BIO_new_mem_buf := @StubBIONewMemBuf;
  GBIONewMemBufStubMode := bmsDisableSelfAfterFirstCall;
end;

procedure PrepareSecondStagePEMReadX509Failure;
begin
  ResetHelperStubState;
  PEM_read_bio_X509 := @StubPEMReadX509;
  GDisablePEMReadX509AfterFirstCall := True;
end;

procedure PrepareSecondStageBIOFreeFailure(AOriginalBIOFree: TBIO_free);
begin
  ResetHelperStubState;
  BIO_free := AOriginalBIOFree;
  BIO_new_mem_buf := @StubBIONewMemBuf;
  GBIONewMemBufStubMode := bmsDisableBIOFreeAfterSecondCall;
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

  ARootPath := 'tmp/cert_utils_verify_chain_bio_contract/root.crt';
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

procedure TestVerifyChainShouldFailGracefullyWhenHelpersDisappearDuringIntermediateExtraction;
var
  LBundlePEM: string;
  LRootPath: string;
  LOriginalBIONewMemBuf: TBIO_new_mem_buf;
  LOriginalPEMReadX509: TPEM_read_bio_X509;
  LOriginalBIOFree: TBIO_free;
  LOriginalBIONew: TBIO_new;
  LOriginalBIOSMem: TBIO_s_mem;
  LOriginalPEMWriteX509: TPEM_write_bio_X509;
begin
  WriteLn;
  WriteLn('=== Certificate utils VerifyChain BIO guard ===');

  if (not Assigned(BIO_new_mem_buf)) or
     (not Assigned(PEM_read_bio_X509)) or
     (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) or
     (not Assigned(BIO_free)) or
     (not Assigned(PEM_write_bio_X509)) then
  begin
    MarkSkip('certificate utils verify-chain bio contract',
      'required baseline OpenSSL PEM/BIO helpers are unavailable');
    Exit;
  end;

  WarmupVerifyChainMaterials(LBundlePEM, LRootPath);

  LOriginalBIONewMemBuf := BIO_new_mem_buf;
  LOriginalPEMReadX509 := PEM_read_bio_X509;
  LOriginalBIOFree := BIO_free;
  LOriginalBIONew := BIO_new;
  LOriginalBIOSMem := BIO_s_mem;
  LOriginalPEMWriteX509 := PEM_write_bio_X509;

  GOriginalBIONewMemBuf := LOriginalBIONewMemBuf;
  GOriginalPEMReadX509 := LOriginalPEMReadX509;
  GOriginalBIOFree := LOriginalBIOFree;

  try
    PrepareSecondStageBIONewMemBufFailure(LOriginalBIOFree);
    AssertDirectVerifyChainSafeDegrade(
      'VerifyChain when second-stage BIO_new_mem_buf becomes unavailable',
      LBundlePEM,
      LRootPath
    );
    RestoreHelperFunctions(
      LOriginalBIONewMemBuf,
      LOriginalPEMReadX509,
      LOriginalBIOFree,
      LOriginalBIONew,
      LOriginalBIOSMem,
      LOriginalPEMWriteX509
    );

    PrepareSecondStageBIONewMemBufFailure(LOriginalBIOFree);
    AssertTryVerifyChainSafeDegrade(
      'VerifyChain when second-stage BIO_new_mem_buf becomes unavailable',
      LBundlePEM,
      LRootPath
    );
    RestoreHelperFunctions(
      LOriginalBIONewMemBuf,
      LOriginalPEMReadX509,
      LOriginalBIOFree,
      LOriginalBIONew,
      LOriginalBIOSMem,
      LOriginalPEMWriteX509
    );

    PrepareSecondStagePEMReadX509Failure;
    AssertDirectVerifyChainSafeDegrade(
      'VerifyChain when second-stage PEM_read_bio_X509 becomes unavailable',
      LBundlePEM,
      LRootPath
    );
    RestoreHelperFunctions(
      LOriginalBIONewMemBuf,
      LOriginalPEMReadX509,
      LOriginalBIOFree,
      LOriginalBIONew,
      LOriginalBIOSMem,
      LOriginalPEMWriteX509
    );

    PrepareSecondStagePEMReadX509Failure;
    AssertTryVerifyChainSafeDegrade(
      'VerifyChain when second-stage PEM_read_bio_X509 becomes unavailable',
      LBundlePEM,
      LRootPath
    );
    RestoreHelperFunctions(
      LOriginalBIONewMemBuf,
      LOriginalPEMReadX509,
      LOriginalBIOFree,
      LOriginalBIONew,
      LOriginalBIOSMem,
      LOriginalPEMWriteX509
    );

    PrepareSecondStageBIOFreeFailure(LOriginalBIOFree);
    AssertDirectVerifyChainSafeDegrade(
      'VerifyChain when second-stage BIO_free becomes unavailable',
      LBundlePEM,
      LRootPath
    );
    RestoreHelperFunctions(
      LOriginalBIONewMemBuf,
      LOriginalPEMReadX509,
      LOriginalBIOFree,
      LOriginalBIONew,
      LOriginalBIOSMem,
      LOriginalPEMWriteX509
    );

    PrepareSecondStageBIOFreeFailure(LOriginalBIOFree);
    AssertTryVerifyChainSafeDegrade(
      'VerifyChain when second-stage BIO_free becomes unavailable',
      LBundlePEM,
      LRootPath
    );
    RestoreHelperFunctions(
      LOriginalBIONewMemBuf,
      LOriginalPEMReadX509,
      LOriginalBIOFree,
      LOriginalBIONew,
      LOriginalBIOSMem,
      LOriginalPEMWriteX509
    );

    BIO_new := nil;
    AssertDirectVerifyChainSafeDegrade(
      'VerifyChain when intermediate-export BIO_new is unavailable',
      LBundlePEM,
      LRootPath
    );
    RestoreHelperFunctions(
      LOriginalBIONewMemBuf,
      LOriginalPEMReadX509,
      LOriginalBIOFree,
      LOriginalBIONew,
      LOriginalBIOSMem,
      LOriginalPEMWriteX509
    );

    BIO_new := nil;
    AssertTryVerifyChainSafeDegrade(
      'VerifyChain when intermediate-export BIO_new is unavailable',
      LBundlePEM,
      LRootPath
    );
    RestoreHelperFunctions(
      LOriginalBIONewMemBuf,
      LOriginalPEMReadX509,
      LOriginalBIOFree,
      LOriginalBIONew,
      LOriginalBIOSMem,
      LOriginalPEMWriteX509
    );

    BIO_s_mem := nil;
    AssertDirectVerifyChainSafeDegrade(
      'VerifyChain when intermediate-export BIO_s_mem is unavailable',
      LBundlePEM,
      LRootPath
    );
    RestoreHelperFunctions(
      LOriginalBIONewMemBuf,
      LOriginalPEMReadX509,
      LOriginalBIOFree,
      LOriginalBIONew,
      LOriginalBIOSMem,
      LOriginalPEMWriteX509
    );

    BIO_s_mem := nil;
    AssertTryVerifyChainSafeDegrade(
      'VerifyChain when intermediate-export BIO_s_mem is unavailable',
      LBundlePEM,
      LRootPath
    );
    RestoreHelperFunctions(
      LOriginalBIONewMemBuf,
      LOriginalPEMReadX509,
      LOriginalBIOFree,
      LOriginalBIONew,
      LOriginalBIOSMem,
      LOriginalPEMWriteX509
    );

    PEM_write_bio_X509 := nil;
    AssertDirectVerifyChainSafeDegrade(
      'VerifyChain when intermediate-export PEM_write_bio_X509 is unavailable',
      LBundlePEM,
      LRootPath
    );
    RestoreHelperFunctions(
      LOriginalBIONewMemBuf,
      LOriginalPEMReadX509,
      LOriginalBIOFree,
      LOriginalBIONew,
      LOriginalBIOSMem,
      LOriginalPEMWriteX509
    );

    PEM_write_bio_X509 := nil;
    AssertTryVerifyChainSafeDegrade(
      'VerifyChain when intermediate-export PEM_write_bio_X509 is unavailable',
      LBundlePEM,
      LRootPath
    );
  finally
    RestoreHelperFunctions(
      LOriginalBIONewMemBuf,
      LOriginalPEMReadX509,
      LOriginalBIOFree,
      LOriginalBIONew,
      LOriginalBIOSMem,
      LOriginalPEMWriteX509
    );
    GOriginalBIONewMemBuf := nil;
    GOriginalPEMReadX509 := nil;
    GOriginalBIOFree := nil;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Utils VerifyChain BIO Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('certificate utils verify-chain bio contract',
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
      TestVerifyChainShouldFailGracefullyWhenHelpersDisappearDuringIntermediateExtraction;

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
