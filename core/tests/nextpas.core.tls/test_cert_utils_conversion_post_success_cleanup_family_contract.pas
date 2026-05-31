program test_cert_utils_conversion_post_success_cleanup_family_contract;

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
  nextpas.core.tls.openssl.api.pem;

const
  CERT_FIXTURE_PATH = 'tests/certificate/test_certs/signer_cert.pem';

type
  TI2DX509StubMode = (
    ixmNone,
    ixmDisableX509FreeAfterEncodeSuccess
  );

  TX509FreeStubMode = (
    xfmNone,
    xfmDisableBIOFreeAfterCleanup
  );

  TPEMWriteX509StubMode = (
    pwmNone,
    pwmDisableBIOFreeAfterWriteSuccess
  );

  TPrepareScenario = procedure;

var
  GLib: ISSLLibrary = nil;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;
  GOriginalI2DX509: Ti2d_X509 = nil;
  GOriginalX509Free: TX509_free = nil;
  GOriginalBIOFree: TBIO_free = nil;
  GOriginalPEMWriteX509: TPEM_write_bio_X509 = nil;
  GOriginalBIONew: TBIO_new = nil;
  GI2DX509StubMode: TI2DX509StubMode = ixmNone;
  GX509FreeStubMode: TX509FreeStubMode = xfmNone;
  GPEMWriteX509StubMode: TPEMWriteX509StubMode = pwmNone;
  GTrackDERToPEMExportBIO: Boolean = False;
  GTrackedDERToPEMExportBIO: PBIO = nil;
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

function LoadFixturePEM: string;
var
  LText: TStringList;
begin
  LText := TStringList.Create;
  try
    LText.LoadFromFile(CERT_FIXTURE_PATH);
    Result := LText.Text;
  finally
    LText.Free;
  end;
end;

procedure WarmupConversionMaterials(
  out APEMFixture: string;
  out ADERFixture: TBytes;
  out ARoundTripPEM: string
);
begin
  APEMFixture := LoadFixturePEM;
  if APEMFixture = '' then
    raise Exception.Create('certificate fixture is empty');

  ADERFixture := TCertificateUtils.PEMToDER(APEMFixture);
  if Length(ADERFixture) = 0 then
    raise Exception.Create('failed to warm up PEMToDER');

  ARoundTripPEM := TCertificateUtils.DERToPEM(ADERFixture);
  if ARoundTripPEM = '' then
    raise Exception.Create('failed to warm up DERToPEM');
end;

function BytesEqual(const ALeft, ARight: TBytes): Boolean;
var
  I: Integer;
begin
  Result := Length(ALeft) = Length(ARight);
  if not Result then
    Exit;

  for I := 0 to Length(ALeft) - 1 do
    if ALeft[I] <> ARight[I] then
      Exit(False);
end;

procedure ResetStubState;
begin
  GI2DX509StubMode := ixmNone;
  GX509FreeStubMode := xfmNone;
  GPEMWriteX509StubMode := pwmNone;
  GTrackDERToPEMExportBIO := False;
  GTrackedDERToPEMExportBIO := nil;
  GDisableX509FreeAfterTrackedBIOFree := False;
end;

procedure RestoreHelperFunctions(
  AOriginalI2DX509: Ti2d_X509;
  AOriginalX509Free: TX509_free;
  AOriginalBIOFree: TBIO_free;
  AOriginalPEMWriteX509: TPEM_write_bio_X509;
  AOriginalBIONew: TBIO_new
);
begin
  i2d_X509 := AOriginalI2DX509;
  X509_free := AOriginalX509Free;
  BIO_free := AOriginalBIOFree;
  PEM_write_bio_X509 := AOriginalPEMWriteX509;
  BIO_new := AOriginalBIONew;
  ResetStubState;
end;

function StubI2DX509(a: PX509; pp: PPByte): Integer; cdecl;
begin
  if Assigned(GOriginalI2DX509) then
    Result := GOriginalI2DX509(a, pp)
  else
    Result := 0;

  if (GI2DX509StubMode = ixmDisableX509FreeAfterEncodeSuccess) and
     (Result > 0) and (pp <> nil) then
    X509_free := nil;
end;

procedure StubX509Free(a: PX509); cdecl;
begin
  if Assigned(GOriginalX509Free) then
    GOriginalX509Free(a);

  if GX509FreeStubMode = xfmDisableBIOFreeAfterCleanup then
    BIO_free := nil;
end;

function StubPEMWriteX509(bp: PBIO; x: PX509): Integer; cdecl;
begin
  if Assigned(GOriginalPEMWriteX509) then
    Result := GOriginalPEMWriteX509(bp, x)
  else
    Result := 0;

  if (GPEMWriteX509StubMode = pwmDisableBIOFreeAfterWriteSuccess) and
     (Result = 1) then
    BIO_free := nil;
end;

function StubBIONew(const &type: PBIO_METHOD): PBIO; cdecl;
begin
  if Assigned(GOriginalBIONew) then
    Result := GOriginalBIONew(&type)
  else
    Result := nil;

  if GTrackDERToPEMExportBIO and (GTrackedDERToPEMExportBIO = nil) and (Result <> nil) then
    GTrackedDERToPEMExportBIO := Result;
end;

function StubBIOFree(a: PBIO): Integer; cdecl;
begin
  if Assigned(GOriginalBIOFree) then
    Result := GOriginalBIOFree(a)
  else
    Result := 0;

  if GDisableX509FreeAfterTrackedBIOFree and (a = GTrackedDERToPEMExportBIO) then
    X509_free := nil;
end;

procedure PreparePEMToDERX509CleanupFailure;
begin
  ResetStubState;
  X509_free := GOriginalX509Free;
  BIO_free := GOriginalBIOFree;
  i2d_X509 := @StubI2DX509;
  GI2DX509StubMode := ixmDisableX509FreeAfterEncodeSuccess;
end;

procedure PreparePEMToDERBIOCleanupFailure;
begin
  ResetStubState;
  BIO_free := GOriginalBIOFree;
  X509_free := @StubX509Free;
  GX509FreeStubMode := xfmDisableBIOFreeAfterCleanup;
end;

procedure PrepareDERToPEMBIOCleanupFailure;
begin
  ResetStubState;
  BIO_free := GOriginalBIOFree;
  PEM_write_bio_X509 := @StubPEMWriteX509;
  GPEMWriteX509StubMode := pwmDisableBIOFreeAfterWriteSuccess;
end;

procedure PrepareDERToPEMX509CleanupFailure;
begin
  ResetStubState;
  X509_free := GOriginalX509Free;
  BIO_new := @StubBIONew;
  BIO_free := @StubBIOFree;
  GTrackDERToPEMExportBIO := True;
  GDisableX509FreeAfterTrackedBIOFree := True;
end;

procedure AssertPEMToDERPreservesOutput(
  const AName: string;
  const APEMFixture: string;
  const AExpectedDER: TBytes;
  APrepareScenario: TPrepareScenario
);
var
  LRaised: Boolean;
  LDetail: string;
  LResult: TBytes;
  LTryRaised: Boolean;
  LTryDetail: string;
  LTryResult: Boolean;
  LTryDER: TBytes;
begin
  LRaised := False;
  LDetail := '';
  SetLength(LResult, 0);
  if Assigned(APrepareScenario) then
    APrepareScenario();
  try
    LResult := TCertificateUtils.PEMToDER(APEMFixture);
  except
    on E: Exception do
    begin
      LRaised := True;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  LTryRaised := False;
  LTryDetail := '';
  SetLength(LTryDER, 0);
  if Assigned(APrepareScenario) then
    APrepareScenario();
  try
    LTryResult := TCertificateUtils.TryPEMToDER(APEMFixture, LTryDER);
  except
    on E: Exception do
    begin
      LTryRaised := True;
      LTryDetail := E.ClassName + ': ' + E.Message;
      LTryResult := False;
    end;
  end;

  AssertTrue(AName + ' should not raise', not LRaised, LDetail);
  AssertTrue(AName + ' should preserve DER output', BytesEqual(LResult, AExpectedDER),
    'expected PEMToDER to keep the already-materialized DER output');
  AssertTrue(AName + ' Try wrapper should not raise', not LTryRaised, LTryDetail);
  AssertTrue(AName + ' Try wrapper should return True', LTryResult,
    'expected TryPEMToDER to preserve the successful direct result');
  AssertTrue(AName + ' Try wrapper should preserve DER output', BytesEqual(LTryDER, AExpectedDER),
    'expected TryPEMToDER output to match the preserved DER bytes');
end;

procedure AssertDERToPEMPreservesOutput(
  const AName: string;
  const ADERFixture: TBytes;
  const AExpectedPEM: string;
  APrepareScenario: TPrepareScenario
);
var
  LRaised: Boolean;
  LDetail: string;
  LResult: string;
  LTryRaised: Boolean;
  LTryDetail: string;
  LTryResult: Boolean;
  LTryPEM: string;
begin
  LRaised := False;
  LDetail := '';
  LResult := '';
  if Assigned(APrepareScenario) then
    APrepareScenario();
  try
    LResult := TCertificateUtils.DERToPEM(ADERFixture);
  except
    on E: Exception do
    begin
      LRaised := True;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  LTryRaised := False;
  LTryDetail := '';
  LTryPEM := '';
  if Assigned(APrepareScenario) then
    APrepareScenario();
  try
    LTryResult := TCertificateUtils.TryDERToPEM(ADERFixture, LTryPEM);
  except
    on E: Exception do
    begin
      LTryRaised := True;
      LTryDetail := E.ClassName + ': ' + E.Message;
      LTryResult := False;
    end;
  end;

  AssertTrue(AName + ' should not raise', not LRaised, LDetail);
  AssertTrue(AName + ' should preserve PEM output', LResult = AExpectedPEM,
    'expected DERToPEM to keep the already-materialized PEM output');
  AssertTrue(AName + ' Try wrapper should not raise', not LTryRaised, LTryDetail);
  AssertTrue(AName + ' Try wrapper should return True', LTryResult,
    'expected TryDERToPEM to preserve the successful direct result');
  AssertTrue(AName + ' Try wrapper should preserve PEM output', LTryPEM = AExpectedPEM,
    'expected TryDERToPEM output to match the preserved PEM string');
end;

procedure TestConversionPostSuccessCleanupFamily;
var
  LFixturePEM: string;
  LFixtureDER: TBytes;
  LRoundTripPEM: string;
  LOriginalI2DX509: Ti2d_X509;
  LOriginalX509Free: TX509_free;
  LOriginalBIOFree: TBIO_free;
  LOriginalPEMWriteX509: TPEM_write_bio_X509;
  LOriginalBIONew: TBIO_new;
begin
  WriteLn;
  WriteLn('=== Certificate utils conversion post-success cleanup family ===');

  if (not Assigned(i2d_X509)) or
     (not Assigned(X509_free)) or
     (not Assigned(BIO_free)) or
     (not Assigned(PEM_write_bio_X509)) or
     (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) then
  begin
    MarkSkip('certificate utils conversion post-success cleanup family contract',
      'required baseline OpenSSL conversion helpers are unavailable');
    Exit;
  end;

  WarmupConversionMaterials(LFixturePEM, LFixtureDER, LRoundTripPEM);

  LOriginalI2DX509 := i2d_X509;
  LOriginalX509Free := X509_free;
  LOriginalBIOFree := BIO_free;
  LOriginalPEMWriteX509 := PEM_write_bio_X509;
  LOriginalBIONew := BIO_new;

  GOriginalI2DX509 := LOriginalI2DX509;
  GOriginalX509Free := LOriginalX509Free;
  GOriginalBIOFree := LOriginalBIOFree;
  GOriginalPEMWriteX509 := LOriginalPEMWriteX509;
  GOriginalBIONew := LOriginalBIONew;

  try
    AssertPEMToDERPreservesOutput(
      'PEMToDER when X509_free becomes unavailable after encode success',
      LFixturePEM,
      LFixtureDER,
      @PreparePEMToDERX509CleanupFailure
    );
    RestoreHelperFunctions(
      LOriginalI2DX509,
      LOriginalX509Free,
      LOriginalBIOFree,
      LOriginalPEMWriteX509,
      LOriginalBIONew
    );

    AssertPEMToDERPreservesOutput(
      'PEMToDER when BIO_free becomes unavailable after certificate cleanup success',
      LFixturePEM,
      LFixtureDER,
      @PreparePEMToDERBIOCleanupFailure
    );
    RestoreHelperFunctions(
      LOriginalI2DX509,
      LOriginalX509Free,
      LOriginalBIOFree,
      LOriginalPEMWriteX509,
      LOriginalBIONew
    );

    AssertDERToPEMPreservesOutput(
      'DERToPEM when BIO_free becomes unavailable after PEM extraction success',
      LFixtureDER,
      LRoundTripPEM,
      @PrepareDERToPEMBIOCleanupFailure
    );
    RestoreHelperFunctions(
      LOriginalI2DX509,
      LOriginalX509Free,
      LOriginalBIOFree,
      LOriginalPEMWriteX509,
      LOriginalBIONew
    );

    AssertDERToPEMPreservesOutput(
      'DERToPEM when X509_free becomes unavailable after BIO cleanup success',
      LFixtureDER,
      LRoundTripPEM,
      @PrepareDERToPEMX509CleanupFailure
    );
  finally
    RestoreHelperFunctions(
      LOriginalI2DX509,
      LOriginalX509Free,
      LOriginalBIOFree,
      LOriginalPEMWriteX509,
      LOriginalBIONew
    );
    GOriginalI2DX509 := nil;
    GOriginalX509Free := nil;
    GOriginalBIOFree := nil;
    GOriginalPEMWriteX509 := nil;
    GOriginalBIONew := nil;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Utils Conversion Post-Success Cleanup Family Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('certificate utils conversion post-success cleanup family contract',
        'failed to initialize OpenSSL library');

    if SkippedTests = 0 then
    begin
      LoadOpenSSLCore();
      LoadOpenSSLBIO();
      LoadOpenSSLX509();
      if not LoadOpenSSLPEM(GetCryptoLibHandle) then
        raise Exception.Create('failed to load PEM support');
    end;

    if SkippedTests = 0 then
      TestConversionPostSuccessCleanupFamily;

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
